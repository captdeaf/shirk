defmodule Handlers do
  ### IRC state-changing methods are irc_(...)
  # Modifies state: Adds the joined channel to the channel list.
  def irc_(_c, %IrcMessage{cmd: "JOIN", args: [channel], host: _host, nick: nick}) do
    channel = chomp channel
    if nick == _c[:nick] do
      if _c[:channels] do
        %{_c | channels: _c[:channels] ++ [channel]}
      else
        Map.merge _c, %{channels: [channel]}
      end
    else
      _c
    end
  end

  # and catchall.
  def irc_(_c, _) do
    _c
  end

  # Flat-out server messages, including MOTD
  def irc(_c, %IrcMessage{cmd: "NOTICE", args: ["*", msg], ctcp: false, server: srv}) do
    send_mush _c, "#{srv}-> #{msg}"
  end

  def irc(_c, %IrcMessage{cmd: c, args: args, ctcp: false, server: srv}) when is_number(c) do
    send_mush _c, "#{srv}: #{Enum.reduce(Enum.map(tl(args),&to_string/1),&<>/2)}"
  end

  def irc(_c, %IrcMessage{cmd: "MODE", args: [who, mode]}) do
    send_mush _c, "#{who} sets mode #{mode}"
  end

  def irc(_c, %IrcMessage{cmd: "JOIN", args: [channel], host: host, nick: nick, user: user}) do
    channel = chomp channel
    send_mush _c, "<#{channel}> #{nick} has joined (#{user}@#{host})"
  end

  def irc(_c, %IrcMessage{cmd: "PRIVMSG", args: [chan, text], nick: nick}) do
    if chan == _c[:nick] do
      send_mush _c, "#{nick} pages: #{text}"
    else
      send_mush _c, "<#{chan}> #{nick} says, \"#{text}\""
    end
  end

  # Catch-all for the rest.
  def irc(_c, msg) do
    if %{cmd: cmd} = msg do
      send_mush _c, "Unhandled #{cmd}: #{inspect msg}"
    else
      send_mush _c, "Unhandled without a command?"
      send_mush _c, inspect msg
    end
  end

  ### MUSH state-changing methods are mush_(...)
  def mush_(_c, _, _) do
    _c
  end

  # non-state-changing methods: mush(...)
  def mush(_c, "help", _args) do
    MUSOCK.send_file(_c.mush, "help.txt")
  end

  # non-state-changing methods: mush(...)
  def mush(_c, "echo", _args) do
    send_mush _c, inspect _args
  end

  def mush(_c, "@join", _args) do
    IO.puts("JOIN?")
    IO.puts(inspect _args)
    ExIrc.Client.join _c.irc, String.strip(_args)
  end

  def mush(_c, "+s", _args) do
    ExIrc.Client.msg _c.irc, :privmsg, "#sillyasdf", _args
  end

  def mush(_c, cmd, _args) do
    send_mush _c, "Unknown command '#{cmd}'. (Type 'help' for help)"
  end

  def send_mush(_c, text) do
    MUSOCK.send_line _c.mush, text
  end

  def chomp(str) do
    str = String.rstrip str, ?\n
    str = String.rstrip str, ?\r
    str = String.rstrip str, ?\n
    str = String.rstrip str, ?\r
    str
  end
end
