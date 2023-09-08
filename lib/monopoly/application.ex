defmodule Monopoly.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Start the game registry
    children = [
      Monopoly.Game.Manager
      # {Registry, keys: :unique, name: Monopoly.Game.Registry}
      # Starts a worker by calling: Monopoly.Worker.start_link(arg)
      # {Monopoly.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Monopoly.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
