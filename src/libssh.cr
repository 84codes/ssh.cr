@[Link("ssh")]
lib LibSSH
  fun ssh_new : LibSSHSession*
  fun ssh_free(session : LibSSHSession*) : Void
  fun ssh_get_error(session : LibSSHSession*) : LibC::Char*
  fun ssh_get_error_code(session : LibSSHSession*) : Error
  fun ssh_get_fd(session : LibSSHSession*) : LibC::Int
  fun ssh_set_fd_toread(session : LibSSHSession*) : Void
  fun ssh_set_fd_towrite(session : LibSSHSession*) : Void
  fun ssh_options_set(session : LibSSHSession*, ssh_option : Options, value : Void*) : LibC::Int
  fun ssh_options_get(session : LibSSHSession*, ssh_option : Options, value : LibC::Char**) : LibC::Int
  fun ssh_options_parse_config(session : LibSSHSession*, filename : LibC::Char*) : LibC::Int
  fun ssh_connect(session : LibSSHSession*) : LibC::Int
  fun ssh_disconnect(session : LibSSHSession*) : LibC::Int
  fun ssh_set_blocking(session : LibSSHSession*, blocking : Bool) : Void
  fun ssh_userauth_publickey_auto(session : LibSSHSession*, username : LibC::Char*, passphrase : LibC::Char*) : AuthError
  fun ssh_userauth_agent(session : LibSSHSession*, username : LibC::Char*) : AuthError
  fun ssh_get_issue_banner(session : LibSSHSession*) : LibC::Char*
  fun ssh_get_openssh_version(session : LibSSHSession*) : LibC::Int
  fun ssh_session_is_known_server(session : LibSSHSession*) : KnownHost
  fun ssh_channel_new(session : LibSSHSession*) : LibSSHChannel*
  fun ssh_channel_open_session(channel : LibSSHChannel*) : LibC::Int
  fun ssh_channel_request_exec(channel : LibSSHChannel*, cmd : LibC::Char*) : LibC::Int
  fun ssh_channel_read(channel : LibSSHChannel*, dest : LibC::Char*, count : UInt32, is_stderr : Bool) : LibC::Int
  fun ssh_channel_read_nonblocking(channel : LibSSHChannel*, dest : LibC::Char*, count : UInt32, is_stderr : Bool) : LibC::Int
  fun ssh_channel_write(channel : LibSSHChannel*, data : LibC::Char*, len : UInt32) : LibC::Int
  fun ssh_channel_is_eof(channel : LibSSHChannel*) : Bool
  fun ssh_channel_send_eof(channel : LibSSHChannel*) : LibC::Int
  fun ssh_channel_close(channel : LibSSHChannel*) : LibC::Int
  fun ssh_channel_free(channel : LibSSHChannel*) : Void
  fun ssh_channel_get_exit_status(channel : LibSSHChannel*) : LibC::Int
  fun ssh_set_channel_callbacks(channel : LibSSHChannel*, cb : ChannelCallbacks*) : LibC::Int
  fun ssh_channel_poll(channel : LibSSHChannel*, is_stderr : Bool) : LibC::Int
  fun ssh_get_poll_flags(session : LibSSHSession*) : LibC::Int
  fun ssh_set_callbacks(session : LibSSHSession*, cb : SSHCallbacks*) : LibC::Int
  fun ssh_string_free_char(s : LibC::Char*) : Void
  fun ssh_blocking_flush(session : LibSSHSession*, timeout : LibC::Int) : LibC::Int
  fun ssh_send_ignore(session : LibSSHSession*, data : LibC::Char*) : LibC::Int

  OK    =    0 # No error
  ERROR =   -1 # Error of some kind
  AGAIN =   -2 # The nonblocking call must be repeated
  EOF   = -127 # We have already a eof

  # Poll flags
  CLOSED        = 0x01 # Socket is closed
  READ_PENDING  = 0x02 # Reading to socket won't block
  CLOSED_ERROR  = 0x04 # Session was closed due to an error
  WRITE_PENDING = 0x08 # Output buffer not empty

  enum KnownHost
    OK        # The server is known and has not changed.
    CHANGED   # The server key has changed. Either you are under attack or the administrator changed the key. You HAVE to warn the user about a possible attack.
    OTHER     # The server gave use a key of a type while we had an other type recorded. It is a possible attack.
    UNKNOWN   # The server is unknown. User should confirm the public key hash is correct.
    NOT_FOUND # The known host file does not exist. The host is thus unknown. File will be created if host key is accepted.
    ERROR     # There had been an error checking the host.
  end

  enum Options
    HOST
    PORT
    PORT_STR
    FD
    USER
    SSH_DIR
    IDENTITY
    ADD_IDENTITY
    KNOWNHOSTS
    TIMEOUT
    TIMEOUT_USEC
    SSH1
    SSH2
    LOG_VERBOSITY
    LOG_VERBOSITY_STR
    CIPHERS_C_S
    CIPHERS_S_C
    COMPRESSION_C_S
    COMPRESSION_S_C
    PROXYCOMMAND
    BINDADDR
    STRICTHOSTKEYCHECK
    COMPRESSION
    COMPRESSION_LEVEL
    KEY_EXCHANGE
    HOSTKEYS
    GSSAPI_SERVER_IDENTITY
    GSSAPI_CLIENT_IDENTITY
    GSSAPI_DELEGATE_CREDENTIALS
    HMAC_C_S
    HMAC_S_C
    PASSWORD_AUTH
    PUBKEY_AUTH
    KBDINT_AUTH
    GSSAPI_AUTH
    GLOBAL_KNOWNHOSTS
    NODELAY
    PUBLICKEY_ACCEPTED_TYPES
    PROCESS_CONFIG
    REKEY_DATA
    REKEY_TIME
    RSA_MIN_SIZE
    IDENTITY_AGENT
  end

  enum Log
    NOLOG     = 0 # No logging at all
    WARNING       # Only warnings
    PROTOCOL      # High level protocol information
    PACKET        # Lower level protocol infomations, packet level
    FUNCTIONS     # Every function path
  end

  enum AuthError
    SUCCESS = 0
    DENIED
    PARTIAL
    INFO
    AGAIN
    ERROR   = -1
  end

  enum Error
    NO_ERROR       = 0
    REQUEST_DENIED
    FATAL
    EINTR
  end

  struct SSHCallbacks
    size : LibC::SizeT
    userdata : Void*
    auth_function : Void*
    log_function : Proc(LibSSHSession*, LibC::Int, LibC::Char*, Void*, Void)
    connect_status_function : Void*
    global_request_function : Void*
    channel_open_request_x11_function : Void*
    channel_open_request_auth_agent_function : Void*
  end

  struct ChannelCallbacks
    size : LibC::SizeT # DON'T SET THIS use ssh_callbacks_init() instead.
    userdata : Void*   # User-provided data. User is free to set anything he wants here
    # This functions will be called when there is data available.
    channel_data_function : Proc(LibSSHSession*, LibSSHChannel*, UInt8*, UInt32, Bool, Void*, LibC::Int)
    # This functions will be called when the channel has received an EOF.
    channel_eof_function : Proc(LibSSHSession*, LibSSHChannel*, Void*, Void)
    # This functions will be called when the channel has been closed by remote
    channel_close_function : Proc(LibSSHSession*, LibSSHChannel*, Void*, Void)
    # This functions will be called when a signal has been received
    channel_signal_function : Void*
    # This functions will be called when an exit status has been received
    channel_exit_status_function : Proc(LibSSHSession*, LibSSHChannel*, LibC::Int, Void*, Void)
    # This functions will be called when an exit signal has been received
    channel_exit_signal_function : Proc(LibSSHSession*, LibSSHChannel*, LibC::Char*, Bool, LibC::Char*, LibC::Char*, Void*, Void)
    # This function will be called when a client requests a PTY
    channel_pty_request_function : Void*
    # This function will be called when a client requests a shell
    channel_shell_request_function : Void*
    # This function will be called when a client requests agent authentication forwarding.
    channel_auth_agent_req_function : Void*
    # This function will be called when a client requests X11 forwarding.
    channel_x11_req_function : Void*
    # This function will be called when a client requests a window change.
    channel_pty_window_change_function : Void*
    # This function will be called when a client requests a command execution.
    channel_exec_request_function : Proc(LibSSHSession*, LibSSHChannel*, LibC::Char*, Void*, Void)
    # This function will be called when a client requests an environment variable to be set.
    channel_env_request_function : Void*
    # This function will be called when a client requests a subsystem (like sftp).
    channel_subsystem_request_function : Void*
    # This function will be called when the channel write is guaranteed not to block.
    channel_write_wontblock_function : Void*
  end
end

@[Extern]
struct LibSSHSession
end

@[Extern]
struct LibSSHChannel
end
