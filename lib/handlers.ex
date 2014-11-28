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

  def irc_(_c, %IrcMessage{cmd: "PART", args: [channel], host: _host, nick: nick}) do
    channel = chomp channel
    if nick == _c[:nick] do
      if _c[:channels] do
        nc = Enum.filter(_c[:channels], fn x -> x != channel end)
        %{_c | channels: nc}
      else
        _c
      end
    else
      _c
    end
  end

  # Catch and update when _I_ change my nick.
  def irc_(_c, %IrcMessage{cmd: "NICK", args: [newnick], nick: oldnick}) do
    if oldnick == _c.nick do
      %{_c | nick: newnick}
    else
      _c
    end
  end

  # Update when server first contacts me (I may be different nick'd)
  def irc_(_c, %IrcMessage{cmd: 1, args: [nick, _]}) do
    if _c[:nick] do
      %{_c | nick: nick}
    else
      Map.merge _c, %{nick: nick}
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
  def mush_(_c, _p) do
    _c
  end

  # non-state-changing methods: mush(...)
  def cmd_help(_c, _p) do
    MUSOCK.send_file(_c.mush, "help.txt")
  end

  def cmd_at_c(_c, _p) do
    send_mush _c, inspect(_c)
  end

  def cmd_at_nick(_c, _p) do
    ExIrc.Client.nick _c.irc, String.strip(_p.args)
  end

  def cmd_at_join(_c, _p) do
    ExIrc.Client.join _c.irc, String.strip(_p.args)
  end

  def cmd_at_part(_c, _p) do
    ExIrc.Client.part _c.irc, String.strip(_p.args)
  end

  def mush(_c, _p) do
    exports = Enum.map(Handlers.module_info[:exports], fn {x,_} -> x end)
    cmd = "cmd_" <> fix_cmd(_p.cmd)
    r = Enum.filter(exports, fn(x) -> String.starts_with?(to_string(x), cmd) end)
    command = cond do
    length(r)< 1 ->
      :mush_other
    length(r)== 1 ->
      hd r
    length(r)> 1 ->
      # Put an exact match first, if possible.
      hd(Enum.filter(r, fn(x) -> to_string(x) == cmd end) ++ r)
    end
    apply(Handlers, command, [_c, _p])
  end

  def fix_cmd(cmd) do
    Regex.replace(~r/@/, cmd, "at_")
  end

  def mush_other(_c, _p) do
    if String.starts_with? _p.cmd, "+" do
      cname = String.slice _p.cmd, 1..-1
      chans = get_channel _c, cname

      ircchan = cond do
      length(chans) < 1 ->
        ""
      length(chans) == 1 ->
        hd chans
      length(chans) > 1 ->
        # Put an exact match first, if possible.
        hd(Enum.filter(chans, fn(x) -> x == cname end) ++ chans)
      end

      if ircchan != "" do
        line = _p.args
        if String.starts_with? line, ":" do
          pose = String.slice(line, 1..-1)
          ExIrc.Client.me _c.irc, ircchan, pose
          send_mush _c, "<#{ircchan}> #{_c.nick} #{pose}"
        else
          ExIrc.Client.msg _c.irc, :privmsg, ircchan, _p.args
          send_mush _c, "<#{ircchan}> #{_c.nick} says, \"#{_p.args}\""
        end
      end
    else
      send_mush _c, "Unknown command '#{_p.cmd}'. (Type 'help' for help)"
    end
  end

  def get_channel(_c, cname) do
    if _c[:channels] do
      Enum.filter _c.channels, fn x -> String.starts_with? x, cname end
    else
      []
    end
  end

  ### Sending messages
  def send_mush(_c, text) do
    MUSOCK.send_line _c.mush, text
  end

  ### Utility Functions
  def chomp(str) do
    str = String.rstrip str, ?\n
    str = String.rstrip str, ?\r
    str = String.rstrip str, ?\n
    str = String.rstrip str, ?\r
    str
  end
end
