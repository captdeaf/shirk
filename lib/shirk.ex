defmodule SHIRK do
  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false])
    IO.puts "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    spawn fn -> MUSOCK.serve(client) end
    loop_acceptor(socket)
  end

  def start(_type, _args) do
    IO.inspect System.argv()
    if length(System.argv) == 1 do
      [portarg] = System.argv
      if {_port, []} = :string.to_integer(to_char_list(portarg)) do
        port = _port
        SHIRK.accept(port)
      else
        IO.puts "Unable to convert port"
      end
    else
      IO.puts "No port given, not running."
    end
    {:ok, :true}
  end
end
