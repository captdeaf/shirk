defmodule IrcHandler do
  def start_link(parent) do
    :gen_server.start_link(__MODULE__, parent, [])
  end

  def init(arg) do
    IO.puts("Got arg: #{inspect arg}")
    {:ok, arg}
  end

  # Catch all IRC messages and pass it off to the handler.
  def handle_info({:data, msg}, parent) do
    IO.puts("IRC: " <> inspect msg)
    if %{cmd: c} = msg do
      if c =~ ~r/^\d+$/ do
        {cid, []} = :string.to_integer(to_char_list(c))
        msg = %{msg | cmd: cid}
      end
    end
    send parent, {:irc, msg}
    {:noreply, parent}
  end

  # We ignore exirc's own handler calls other than the above.
  def handle_info(_msg, parent) do
    {:noreply, parent}
  end
end
