# SSH

Crystal bindings to [libssh](https://www.libssh.org/)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     ssh:
       github: 84codes/ssh.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "ssh"

SSH.open("localhost", "root", 22) do |ssh|
  # execute command and collect all output in a string
  output, exit_status = ssh.exec! "echo Hello world"

  # execute a command and do something with the output
  ssh.exec("echo hello world") do |bytes, is_stderr|
    if is_stderr
      STDERR.write bytes
    else
      STDOUT.write bytes
    end
  end

  # More control and can write the the STDIN
  ssh.channel do |ch|
    ch.on_data do |bytes, is_stderr|
      STDOUT.write bytes
    end
    ch.exec("cat")
    ch.puts "hello world"
    ch.wait
    puts "Exited with status: #{ch.exit_status}"
  end
end
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/ssh.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Carl Hörberg](https://github.com/your-github-user) - creator and maintainer
