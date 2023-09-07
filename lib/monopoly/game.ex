defmodule Monopoly.Game do
  @moduledoc """
  A tiny version of (not)monopoly that you can suspend and resume.
  """
  use GenServer
  require Logger

  @backup_dir "/Users/greg/Scratch/monopoly/game_backups"

  #
  # User Interface
  #

  @doc """
  Start a new game for a set of players.
  Fails to start if:
    - The number of players is invalid
  """
  def new_game(players, game_id) do
    num_players = length(players)
    if File.exists?("#{@backup_dir}/#{game_id}.json") do
      raise ArgumentError, "Game already exists with id: #{game_id}"
    end

    if num_players > 1 and num_players < 10 do
      process_name = {:via, Registry, {Monopoly.Game.Registry, game_id}}
      GenServer.start_link(__MODULE__, {:new_game, game_id, players}, name: process_name)
    else
      raise ArgumentError, "Number of players must be greater than 1 and less than 10."
    end
  end

  @doc """
  Resume a game by ID.
  Fails to start if:
    - The backup doesn't exist
    - The backup has been corrupted
  """
  def resume_game(game_id) do
    with json <- File.read!("#{@backup_dir}/#{game_id}.json"),
         state <- Jason.decode!(json) do
      process_name = {:via, Registry, {Monopoly.Game.Registry, game_id}}
      GenServer.start_link(__MODULE__, {:resume_game, game_id, state}, name: process_name)
    end
  end

  @doc """
  Susped a game.
  Wait for the current action to end and stop the server.
  Exit signals wait in the same queue as other messages which means
  this doesn't cause an immediate shutdown. It waits for other messages to be
  processed before terminate/2 is reached.
  """
  def suspend_game(pid) do
    GenServer.stop(pid, :normal)
  end

  @doc """
  Send a roll command for a user to a game.
  Will only actually roll if the user is allowed to.
  """
  def roll(pid, player) do
    GenServer.call(pid, {"roll", player})
  end

  #
  # Internal Server Interface
  #

  @base_game_board [
    %{
      "name" => "Go",
      "action" => "none"
    },
    %{
      "name" => "Receive 200",
      "action" => %{"name" => "add", "amount" => 200}
    },
    %{
      "name" => "Pay 200",
      "action" => %{"name" => "subtract", "amount" => 200}
    },
    %{
      "name" => "Receive 200",
      "action" => %{"name" => "add", "amount" => 200}
    },
    %{
      "name" => "Pay 200",
      "action" => %{"name" => "subtract", "amount" => 200}
    },
    %{
      "name" => "Receive 200",
      "action" => %{"name" => "add", "amount" => 200}
    }
  ]

  @impl true
  def init({:new_game, game_id, player_ids}) do
    players =
      for player_id <- player_ids, into: %{} do
        {
          player_id,
          %{
            "money" => 1500,
            "position" => 0
          }
        }
      end

    state = %{
      "id" => game_id,
      "players" => players,
      "board" => @base_game_board,
      "next" => ["roll", hd(player_ids)],
      "roll_order" => player_ids
    }

    Logger.info("Starting new game with id: #{game_id}")
    {:ok, state}
  end

  def init({:resume_game, game_id, state}) do
    Logger.info("Resuming game with id: #{game_id}")
    {:ok, Map.put(state, "id", game_id)}
  end

  def init(args) do
    {:stop, {:bad_arguments, args}}
  end

  @impl true
  def handle_call({"roll", player_id}, _from, state) do
    case state["next"] do
      # If the next "action" is "roll" and the correct player is rolling
      ["roll", ^player_id] ->
        # TODO: roll dice!
        to_move = roll_die()
        new_state = do_roll(state, player_id, to_move)
        save_game(new_state)
        {:reply, new_state, new_state}

      _ ->
        {:reply, state, state}
    end
  end

  @impl true
  def handle_call(:dump_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def terminate(:normal, state) do
    Logger.info("Suspending game with id: #{inspect(state["id"])}")
    :ok
  end

  #
  # Internal Helper Interface
  #

  defp roll_die() do
    :rand.uniform(6)
  end

  @doc ~S"""
  ## Examples
      iex> players = ["a", "b", "c"]
      iex> Monopoly.Game.next_player(players, "a")
      "b"
      iex> Monopoly.Game.next_player(players, "b")
      "c"
      iex> Monopoly.Game.next_player(players, "c")
      "a"
  """
  def next_player(roll_order, id) do
    i =
      roll_order
      |> Enum.find_index(&(&1 == id))
      |> Kernel.+(1)
      |> rem(length(roll_order))

    Enum.at(roll_order, i)
  end

  def do_roll(state, player_id, to_move) do
    player_start_of_turn = state["players"][player_id]

    # Position Calculation and side effects
    new_position = player_start_of_turn["position"] + to_move

    {new_position, passed_go} =
      if new_position >= length(state["board"]) do
        {
          rem(new_position, length(state["board"])),
          true
        }
      else
        {
          new_position,
          false
        }
      end

    # Money Calculation
    new_money = player_start_of_turn["money"]

    new_money =
      if passed_go do
        new_money + 200
      else
        new_money
      end

    new_money =
      case Enum.at(state["board"], new_position)["action"] do
        %{"name" => "add", "amount" => amount} -> new_money + amount
        %{"name" => "subtract", "amount" => amount} -> new_money - amount
        "none" -> new_money
      end

    player_after_move = %{player_start_of_turn | "position" => new_position, "money" => new_money}

    players = Map.put(state["players"], player_id, player_after_move)

    # Player bankrupt and End Game calculation
    next_roller = next_player(state["roll_order"], player_id)

    {next, roll_order} =
      if new_money < 0 do
        roll_order = Enum.filter(state["roll_order"], fn id -> id !== player_id end)

        if length(roll_order) <= 1 do
          {
            ["game_over", hd(roll_order)],
            roll_order
          }
        else
          {
            ["roll", next_roller],
            roll_order
          }
        end
      else
        {
          ["roll", next_roller],
          state["roll_order"]
        }
      end

    %{state | "players" => players, "next" => next, "roll_order" => roll_order}
  end

  def save_game(state) do
    id = state["id"]

    contents =
      Map.drop(state, ["id"])
      |> Jason.encode!()

    File.write("#{@backup_dir}/#{id}.json", contents)
  end
end
