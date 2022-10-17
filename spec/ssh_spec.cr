require "./spec_helper"

describe SSH do
  it "works" do
    system "sudo /usr/sbin/sshd -p 2022"
    ssh = SSH.new("localhost", ENV["USER"], 2022)
    output, exit_status = ssh.exec!("echo ERROR >> /dev/stderr && sleep 0.2 && echo STANDARD && exit 2")
    output.should eq "ERROR\nSTANDARD\n"
    exit_status.should eq 2
    ssh.exec("echo hello world") do |bytes, is_stderr|
      String.new(bytes).should eq "hello world\n"
      is_stderr.should be_false
    end
    ssh.channel do |ch|
      data = IO::Memory.new
      ch.on_data do |bytes, _is_stderr|
        data.write bytes
      end
      ch.exec "cat"
      input = IO::Memory.new
      ('a'..'z').each do |chr|
        ch.puts(chr.to_s * 72)
        input.puts(chr.to_s * 72)
      end
      ch.eof!
      ch.wait
      data.to_s.should eq input.to_s
    end
    ssh.close
  ensure
    system "sudo kill #{File.read("/var/run/sshd.pid")}"
  end
end
