defmodule IrcHandler do
  def start_link(parent) do
    :gen_server.start_link(__MODULE__, parent, [])
  end

  def init(arg) do
    IO.puts("Got arg: #{inspect arg}")
    {:ok, arg}
  end

  # Catch-all for messages you don't care about
  def handle_info(msg, parent) do
    send parent, {:irc, msg}
    {:noreply, parent}
  end
end
