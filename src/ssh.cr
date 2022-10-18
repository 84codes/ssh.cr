require "socket"
require "./libssh"

# SSH client
class SSH
  def initialize(host : String, user : String, port = 22,
                 @socket = TCPSocket.new(host, port))
    fd = @socket.fd
    @session = LibSSH.ssh_new || raise Error.new("Could not create a session")
    LibSSH.ssh_set_blocking(@session, false)
    LibSSH.ssh_options_set(@session, LibSSH::Options::FD, pointerof(fd))
    LibSSH.ssh_options_set(@session, LibSSH::Options::HOST, host)
    LibSSH.ssh_options_set(@session, LibSSH::Options::PORT, pointerof(port))
    LibSSH.ssh_options_set(@session, LibSSH::Options::USER, user)
    connect
    verify_host_key
    authenticate
  end

  def self.open(host, user, port = 22)
    ssh = self.new(host, user, port)
    begin
      yield ssh
    ensure
      ssh.close
    end
  end

  private def connect : Nil
    loop do
      case LibSSH.ssh_connect(@session)
      when LibSSH::OK    then break
      when LibSSH::AGAIN then wait_socket
      when LibSSH::ERROR then raise Error.new("connecting")
      end
    end
  end

  private def authenticate : Nil
    loop do
      case LibSSH.ssh_userauth_agent(@session, nil)
      in LibSSH::AuthError::SUCCESS then break
      in LibSSH::AuthError::DENIED  then raise Error.new("auth denied")
      in LibSSH::AuthError::PARTIAL then raise Error.new("auth partial")
      in LibSSH::AuthError::INFO    then raise Error.new("auth info")
      in LibSSH::AuthError::ERROR   then raise Error.new("auth error")
      in LibSSH::AuthError::AGAIN   then wait_socket
      end
    end
  end

  private def verify_host_key : Nil
    case LibSSH.ssh_session_is_known_server(@session)
    in LibSSH::KnownHost::OK        then return
    in LibSSH::KnownHost::CHANGED   then raise Error.new("Host key has changed")
    in LibSSH::KnownHost::OTHER     then raise Error.new("Host key doesn't match")
    in LibSSH::KnownHost::UNKNOWN   then raise Error.new("Host not in known host file")
    in LibSSH::KnownHost::NOT_FOUND then raise Error.new("Known host file not found")
    in LibSSH::KnownHost::ERROR     then raise Error.new("Error checking host")
    end
  end

  protected def wait_socket
    flags = LibSSH.ssh_get_poll_flags(@session)
    if flags & LibSSH::READ_PENDING != 0
      @socket.wait_readable
      LibSSH.ssh_set_fd_toread(@session)
    end
    if flags & LibSSH::WRITE_PENDING != 0
      @socket.wait_writable
      LibSSH.ssh_set_fd_towrite(@session)
    end
  end

  def close : Nil
    LibSSH.ssh_disconnect(@session)
  end

  # Open a session channel
  def channel
    ch = Channel.new(self)
    begin
      yield ch
    rescue ex : Error
      ssh_error = String.new(LibSSH.ssh_get_error(@session))
      raise Error.new(ssh_error, cause: ex)
    ensure
      ch.close
    end
  end

  # Execute a command on the server
  # Returns the output of stdout and stderr into a single string and the exit status
  def exec!(cmd) : Tuple(String, Int32?)
    io = IO::Memory.new
    exit_status = exec(cmd) do |bytes, _is_stderr|
      io.write bytes
    end
    {io.to_s, exit_status}
  end

  # Execute a command on the server, and retrive the stdout/stderr in the block
  # Returns the exit status of the command
  def exec(cmd, &blk : Bytes, Bool -> Nil) : Int32?
    channel do |ch|
      ch.on_data do |bytes, is_stderr|
        blk.call(bytes, is_stderr)
      end
      ch.exec(cmd)
      ch.wait
      ch.exit_status
    end
  end

  class Channel < IO
    protected def initialize(@ssh : SSH)
      @channel = LibSSH.ssh_channel_new(@ssh.@session) || raise SSH::Error.new("Could not open channel")
      @state = ChannelState.new
      @cb = LibSSH::ChannelCallbacks.new
      @cb.size = sizeof(LibSSH::ChannelCallbacks)
      @cb.userdata = Box.box(@state)
      @cb.channel_data_function =
        ->(_s : LibSSHSession*, _ch : LibSSHChannel*, data : UInt8*, len : UInt32, is_stderr : Bool, userdata : Void*) do
          state = Box(ChannelState).unbox(userdata)
          state.on_data.call Bytes.new(data, len), is_stderr
          len.to_i
        end
      @cb.channel_exit_status_function =
        ->(_s : LibSSHSession*, _ch : LibSSHChannel*, exit_status : Int32, userdata : Void*) do
          state = Box(ChannelState).unbox(userdata)
          state.exit_status = exit_status
        end
      @cb.channel_exit_signal_function =
        ->(_s : LibSSHSession*, _ch : LibSSHChannel*, signal : LibC::Char*, _core : Bool, _errmsg : LibC::Char*, _lang : LibC::Char*, userdata : Void*) do
          state = Box(ChannelState).unbox(userdata)
          state.exit_signal = String.new(signal)
        end
      @cb.channel_close_function =
        ->(_s : LibSSHSession*, _ch : LibSSHChannel*, userdata : Void*) do
          state = Box(ChannelState).unbox(userdata)
          state.closed = true
        end
      set_callbacks
      open_session
    end

    # Wait for the channel to finish executing, issue after `exec`
    def wait : Nil
      loop do
        case LibSSH.ssh_channel_poll(@channel, false)
        when LibSSH::OK    then @ssh.wait_socket
        when LibSSH::AGAIN then @ssh.wait_socket
        when LibSSH::EOF   then break
        when LibSSH::ERROR then raise SSH::Error.new("Could not poll channel")
        end
      end
    end

    def exit_status : Int32?
      if es = @state.exit_status
        return es
      end
      until @state.closed?
        @ssh.wait_socket
        es = LibSSH.ssh_channel_get_exit_status(@channel)
        return es if es >= 0
      end
    end

    def exit_signal : String?
      @state.exit_signal
    end

    def on_data(&blk : Proc(Bytes, Bool, Void))
      @state.on_data = blk
    end

    def exec(cmd : String) : Nil
      loop do
        case LibSSH.ssh_channel_request_exec(@channel, cmd)
        when LibSSH::OK    then break
        when LibSSH::AGAIN then @ssh.wait_socket
        when LibSSH::ERROR then raise SSH::Error.new("Could not exec")
        else                    raise SSH::Error.new("Could not exec")
        end
      end
    end

    @closed = false

    def close : Nil
      return if @closed
      @closed = true
      LibSSH.ssh_channel_free(@channel)
    end

    def finalize
      close
    end

    # Write to the STDIN of the SSH session channel
    def write(slice : Bytes) : Nil
      len = slice.bytesize
      pos = 0
      loop do
        case cnt = LibSSH.ssh_channel_write(@channel, slice.to_unsafe + pos, len - pos)
        when len - pos     then break
        when .positive?    then pos += cnt
        when 0             then @ssh.wait_socket
        when LibSSH::EOF   then raise IO::EOFError.new
        when LibSSH::ERROR then raise SSH::Error.new("Could not write to channel")
        else                    raise SSH::Error.new("Unexpected write return code #{cnt}")
        end
      end
    end

    # Use the `on_data` callback to retrive output from the SSH session
    def read(slice : Bytes) : Int
      raise IO::Error.new("Can't read from SSH channel, use on_data callback")
    end

    # Notify the channel that the STDIN is closed, no more data can be written
    def eof! : Nil
      loop do
        case rc = LibSSH.ssh_channel_send_eof(@channel)
        when LibSSH::OK    then break
        when LibSSH::AGAIN then @ssh.wait_socket
        when LibSSH::ERROR then raise SSH::Error.new("Could not send EOF")
        else                    raise SSH::Error.new("Could not send EOF (#{rc})")
        end
      end
    end

    private def set_callbacks : Nil
      case LibSSH.ssh_set_channel_callbacks(@channel, pointerof(@cb))
      when LibSSH::OK then return
      else                 raise SSH::Error.new("Could not set callbacks")
      end
    end

    private def open_session : Nil
      loop do
        case LibSSH.ssh_channel_open_session(@channel)
        when LibSSH::OK    then break
        when LibSSH::AGAIN then @ssh.wait_socket
        when LibSSH::ERROR then raise SSH::Error.new("Could not open session channel")
        else                    raise SSH::Error.new("Could not open session channel")
        end
      end
    end

    private class ChannelState
      @on_data = Proc(Bytes, Bool, Void).new do |bytes, is_stderr|
        io = is_stderr ? STDERR : STDOUT
        io.write bytes
      end
      property on_data
      property exit_status : Int32?
      property exit_signal : String?
      property? closed = false
    end
  end

  def finalize
    LibSSH.ssh_free(@session)
  end

  class Error < Exception; end
end
