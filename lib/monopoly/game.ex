defmodule Monopoly.Game do
  use GenServer

  # User Interface

  @base_game_board [
    %{
      name: "Go",
      action: :noop
    },
    %{
      name: "Receive 200",
      action: {:add, 200}
    },
    %{
      name: "Pay 200",
      action: {:subtract, 200}
    },
    %{
      name: "Receive 200",
      action: {:add, 200}
    },
    %{
      name: "Pay 200",
      action: {:subtract, 200}
    },
    %{
      name: "Receive 200",
      action: {:add, 200}
    }
  ]

  def new_game(players) do
    num_players = length(players)

    if num_players > 1 and num_players < 10 do
      GenServer.start_link(__MODULE__, {:new_game, players})
    else
      raise ArgumentError, "Number of players must be greater than 1 and less than 10."
    end
  end

  def roll(pid, player) do
    GenServer.call(pid, {:roll, player})
  end

  def resume_game(_game_id) do
  end

  # Internal Server Interface

  @impl true
  def init({:new_game, player_ids}) do
    players =
      for player_id <- player_ids, into: %{} do
        {
          player_id,
          %{
            money: 1500,
            position: 0
          }
        }
      end

    state = %{
      players: players,
      board: @base_game_board,
      next: {:roll, hd(player_ids)},
      roll_order: player_ids
    }

    {:ok, state}
  end

  def init({:resume_game, game_id}) do
    {:stop, {:bad_game_id, game_id}}
  end

  @impl true
  def handle_call({:roll, player_id}, _from, state) do
    case state.next do
      # If the next action is :roll and the correct player is rolling
      {:roll, ^player_id} ->
        # TODO: roll dice!
        to_move = roll_die()
        new_state = do_roll(state, player_id, to_move)
        {:noreply, new_state}

      _ ->
        {:reply, state, state}
    end
  end

  @impl true
  def handle_cast(:dump_state, state) do
    IO.inspect(state)
    {:noreply, state}
  end

  # Internal Helper Interface
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
  def next_player(players, id) do
    i =
      players
      |> Enum.find_index(&(&1 == id))
      |> Kernel.+(1)
      |> rem(length(players))

    Enum.at(players, i)
  end

  def do_roll(state, player_id, to_move) do
    player_start_of_turn = state.players[player_id]

    # Position Calculation and side effects
    new_position = player_start_of_turn.position + to_move

    {new_position, passed_go} =
      if new_position >= length(state.board) do
        {
          rem(new_position, length(state.board)),
          true
        }
      else
        {
          new_position,
          false
        }
      end

    # Money Calculation
    new_money = player_start_of_turn.money

    new_money =
      if passed_go do
        new_money + 200
      else
        new_money
      end

    new_money =
      case Enum.at(state.board, new_position).action do
        {:add, amount} -> new_money + amount
        {:subtract, amount} -> new_money - amount
        :noop -> new_money
      end

    player_after_move = %{player_start_of_turn | position: new_position, money: new_money}

    players = Map.put(state.players, player_id, player_after_move)

    # Player bankrupt and End Game calculation
    next_roller = next_player(state.roll_order, player_id)
    {next, roll_order} =
      if new_money < 0 do
        roll_order = Enum.filter(state.roll_order, fn id -> id !== player_id end)
        if length(roll_order) <= 1 do
          {
            {:game_over, hd(roll_order)},
            roll_order
          }
        else
          {
            {:roll, next_roller},
            roll_order
          }
        end
      else
        {
          {:roll, next_roller},
          state.roll_order
        }
      end

    %{state | players: players, next: next, roll_order: roll_order}
  end
end
