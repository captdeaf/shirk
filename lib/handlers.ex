defmodule SHIRKER do
  ### IRC state-changing methods are irc_(...)
  def irc_(_c, _) do
    _c
  end

  def irc(_c, {:connected, server, port}) do
    send_mush _c, "You have connected to #{inspect server} #{inspect port}"
  end
  def irc(_c, :logged_in) do
    send_mush _c, "You are logged in"
  end
  def irc(_c, :disconnected) do
    send_mush _c, "You have been disconnected."
  end
  def irc(_c, {:joined, channel}) do 
    send_mush _c, "You have joined #{channel}"
  end
  def irc(_c, {:joined, channel, user}) do
    send_mush _c, "<#{channel}> #{user} has connected"
  end
  def irc(_c, {:topic_changed, channel, topic}) do
    send_mush _c, "<#{channel}> New topic: #{topic}"
  end
  def irc(_c, {:nick_changed, nick}) do
    send_mush _c, "You are now known as '#{nick}'"
  end
  def irc(_c, {:nick_changed, old_nick, new_nick}) do
    send_mush _c, "#{old_nick} is now known as '#{new_nick}'"
  end
  def irc(_c, {:parted, channel}) do
    send_mush _c, "You have left #{channel}"
  end
  def irc(_c, {:parted, channel, nick}) do
    send_mush _c, "<#{channel}> #{nick} has parted"
  end
  def irc(_c, {:invited, by, channel}) do
    send_mush _c, "You are invited to #{channel} by #{by}"
  end
  def irc(_c, {:kicked, by, channel}) do
    send_mush _c, "You have been kicked from #{channel} by #{by}"
  end
  def irc(_c, {:kicked, nick, by, channel}) do
    send_mush _c, "<#{channel}> #{nick} has been kicked by #{by}"
  end
  def irc(_c, {:received, message, from}) do
    send_mush _c, "#{from} pages: #{message}"
  end
  def irc(_c, {:received, message, from, channel}) do
    send_mush _c, "<#{channel}> #{from} says, \"#{message}\""
  end
  def irc(_c, {:mentioned, message, from, channel}) do
    send_mush _c, "<#{channel}> #{from} says, \"#{message}\""
  end
  def irc(_c, {:me, message, from, channel}) do
    send_mush _c, "<#{channel}> #{from} #{message}"
  end

  def irc(_c, msg) do
    send_mush(_c, "From IRC: #{inspect msg}")
  end

  ### MUSH state-changing methods are mush_(...)
  def mush_(_c, _, _) do
    _c
  end

  # non-state-changing methods: mush(...)
  def mush(_c, "help", _args) do
    MUSOCK.send_file(_c.mush, "help.txt")
  end

  def mush(_c, "@join", _args) do
    IO.puts("JOIN?")
    IO.puts(inspect _args)
    ExIrc.Client.join _c.irc, String.strip(_args)
  end

  def mush(_c, "+s", _args) do
    ExIrc.Client.privmsg _c.irc, :privmsg, "#sillyasdf", _args
  end

  def send_mush(_c, text) do
    MUSOCK.send_line _c.mush, text
  end
end
