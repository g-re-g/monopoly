defmodule Monopoly.Game.Manager do
  @moduledoc """
  A tiny version of (not)monopoly that you can suspend and resume.
  """
  use GenServer
  require Logger

  @backup_dir "/Users/greg/Scratch/monopoly/game_backups"

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(games) do
    Logger.info("Game Manager starting.")
    {:ok, games}
  end

  @doc """
  Start a new game for a set of players.
  Fails to start if:
    - The number of players is invalid
  """
  def new_game(players, game_id) do
    GenServer.call(__MODULE__, {:new_game, players, game_id})
  end

  @doc """
  Resume a game by ID.
  Fails to start if:
    - The backup doesn't exist
    - The backup has been corrupted
  """
  def resume_game(game_id) do
    GenServer.call(__MODULE__, {:resume_game, game_id})
  end

  @doc """
  Show what games are running
  """
  def running_games() do
    GenServer.call(__MODULE__, :running_games)
  end

  @doc """
    Get a game pid by id
  """
  def get_game(game_id) do
    GenServer.call(__MODULE__, {:get_game, game_id})
  end

  #
  # Server Interface
  #
  @impl true
  def handle_call({:new_game, players, game_id}, _from, state) do
    cond do
      File.exists?("#{@backup_dir}/#{game_id}.json") ||
          Enum.any?(state, fn {_, {id, _}} -> id == game_id end) ->
        {:reply, {:error, "Game already exists with id: #{game_id}"}, state}

      true ->
        num_players = length(players)

        if num_players > 1 and num_players < 10 do
          # Start the game
          {:ok, pid} =
            GenServer.start(Monopoly.Game, {:new_game, game_id, players})

          # Monitor the game
          ref = Process.monitor(pid)
          state = Map.put(state, ref, {game_id, pid})
          {:reply, {:ok, pid}, state}
        else
          {:reply, {:error, "Number of players must be greater than 1 and less than 10."}, state}
        end
    end
  end

  @impl true
  def handle_call({:resume_game, game_id}, _from, state) do
    cond do
      Enum.any?(state, fn {_, {id, _}} -> id == game_id end) ->
        {:reply, {:error, "Game already exists with id: #{game_id}"}, state}

      true ->
        with json <- File.read!("#{@backup_dir}/#{game_id}.json"),
             game_state <- Jason.decode!(json) do
          {:ok, pid} =
            GenServer.start(Monopoly.Game, {:resume_game, game_id, game_state})

          # Monitor the game
          ref = Process.monitor(pid)
          state = Map.put(state, ref, {game_id, pid})
          {:reply, {:ok, pid}, state}
        end
    end
  end

  @impl true
  def handle_call(:running_games, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:get_game, game_id}, _from, state) do
    pid =
      Enum.find_value(state, fn
        {_, {id, pid}} when id == game_id -> pid
        _ -> false
      end)

    if pid do
      {:reply, {:ok, pid}, state}
    else
      {:reply, :error, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, :normal}, state) do
    # If the down reason is :normal, don't restart
    {{game_id, _}, new_state} = Map.pop(state, ref)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    {{game_id, _}, new_state} = Map.pop(state, ref)
    Logger.info("Game went down with id: #{game_id}, for reason: #{inspect(reason)}")

    if game_id do
      {:reply, {:ok, _}, new_state} = handle_call({:resume_game, game_id}, nil, new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unexpected message in #{__MODULE__}: #{inspect(msg)}")
    {:noreply, state}
  end
end
