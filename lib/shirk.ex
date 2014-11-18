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
end

# SHIRK.accept(4041)
