defmodule MUSOCK do
  def serve(client) do
    # Read out the MOTD.
    send_file client, "welcome.txt"

    # Read until login.
    data = wait_login(client, nil)

    send_line client, "Hello #{data.nick}, attempting to connect you to IRC . . ."

    irc = attempt_irc_login client, data

    # At this point, we've successfully connected to IRC. Spawn the reader for
    # the mu* connection then just hop into an event processing loop.
    parent = self()
    spawn_link fn -> loop_events parent, client end

    c = %{irc: irc, mush: client, parent: self()}
    handle_events c

    send_line client, "Goodbye, I hope you enjoyed using SHIRK!"
    close client
  end

  def handle_events(c) do
    receive do
      {:irc, msg} -> SHIRKER.irc(c, msg)
      {:mush, line} -> handle_line c, line
    end
    handle_events c
  end

  def handle_line(c, line) do
    x = Regex.named_captures(~r/^\s*(?<cmd>\S+)\s*(?<arg>.*?)[\r\n]*$/, line)
    SHIRKER.mush(c, x["cmd"], x["arg"])
  end

  def loop_events(parent, client) do
    y = read_line(client)
    send parent, {:mush, y}
    loop_events parent, client
  end

  def close(client) do
    :gen_tcp.close(client)
  end

  def wait_login(client, nil) do
    send_file client, "connect.txt"
    x = read_line(client)
    wait_login client, Regex.named_captures(~r/^\s*connect (?<host>\S+):(?<port>\d+) (?<nick>[^:\s]+)(?::(?<pass>\S+))? (?<user>\S+) (?<name>.*?)\s*$/, x)
  end

  def wait_login(client, opts) when is_map(opts) do
    send_line client, "Hello!"
    {portnum, []} = :string.to_integer(to_char_list(opts["port"]))
    %{
      host: opts["host"],
      port: portnum,
      nick: opts["nick"],
      pass: opts["pass"],
      user: opts["user"],
      name: opts["name"]
    }
  end

  def read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  def send_line(socket, data) do
    :gen_tcp.send(socket, data)
    :gen_tcp.send(socket, "\r\n")
  end

  def send_file(client, path) do
    {:ok, body} = File.read "txt/" <> path
    :gen_tcp.send(client, body)
  end

  def attempt_irc_login(client, opts) do
    send_line client, "Creating irc"
    {:ok, irc} = ExIrc.start_client!()
    send_line client, "Creating handler"
    {:ok, handler} = IrcHandler.start_link(self())

    send_line client, "Adding handler"
    ExIrc.Client.add_handler(irc, handler)

    send_line client, "Connecting to host #{inspect opts.host} via #{inspect opts.port}"
    ExIrc.Client.connect! irc, opts.host, opts.port

    send_line client, "Logging on"
    ExIrc.Client.logon irc, opts.pass, opts.nick, opts.user, opts.name

    send_line client, "Finished with attempt"
  end
end
