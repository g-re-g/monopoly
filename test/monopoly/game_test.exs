defmodule Monopoly.GameTest do
  use ExUnit.Case
  doctest Monopoly.Game

  describe "rolling" do
    @state %{
      "next" => ["roll", "bob"],
      "players" => %{
        "bob" => %{"position" => 0, "money" => 1500},
        "deryl" => %{"position" => 0, "money" => 1500}
      },
      "board" => [
        %{"name" => "GO", "action" => "none"},
        %{"name" => "Receive 200", "action" => %{"name" => "add", "amount" => 200}},
        %{"name" => "Pay 200", "action" => %{"name" => "subtract", "amount" => 200}},
        %{"name" => "Receive 200", "action" => %{"name" => "add", "amount" => 200}},
        %{"name" => "Pay 200", "action" => %{"name" => "subtract", "amount" => 200}},
        %{"name" => "Receive 200", "action" => %{"name" => "add", "amount" => 200}}
      ],
      "roll_order" => ["bob", "deryl"]
    }

    test "bob rolls" do
      bob_rolls = Monopoly.Game.do_roll(@state, "bob", 2)
      assert bob_rolls["next"] == ["roll", "deryl"]
      assert bob_rolls["players"]["bob"]["money"] == 1300
      assert bob_rolls["players"]["bob"]["position"] == 2
    end

    test "bob rolling twice does nothing" do
      bob_rolls = Monopoly.Game.do_roll(@state, "bob", 2)
      assert bob_rolls == Monopoly.Game.do_roll(@state, "bob", 2)
    end

    test "bob rolls then deryl rolls" do
      _ = Monopoly.Game.do_roll(@state, "bob", 2)
      deryl_rolls = Monopoly.Game.do_roll(@state, "deryl", 3)

      assert deryl_rolls["next"] == ["roll", "bob"]
      assert deryl_rolls["players"]["deryl"]["money"] == 1700
      assert deryl_rolls["players"]["deryl"]["position"] == 3
    end

    test "landing directly on go causes payment" do
      money_before = @state["players"]["bob"]["money"]
      bob_rolls = Monopoly.Game.do_roll(@state, "bob", length(@state["board"]))
      assert bob_rolls["players"]["bob"]["money"] == money_before + 200
    end

    test "wrapping around go causes payment and square action" do
      money_before = @state["players"]["bob"]["money"]
      bob_rolls = Monopoly.Game.do_roll(@state, "bob", length(@state["board"]) + 1)
      assert bob_rolls["players"]["bob"]["money"] == money_before + 400
    end

    test "game ends if player negative after roll" do
      state = %{
        @state
        | "players" => %{
            "bob" => %{"position" => 0, "money" => 100},
            "deryl" => %{"position" => 0, "money" => 1500}
          }
      }

      bob_rolls = Monopoly.Game.do_roll(state, "bob", 2)
      assert bob_rolls["players"]["bob"]["money"] == -100
      assert bob_rolls["next"] == ["game_over", "deryl"]
      assert bob_rolls["roll_order"] == ["deryl"]
    end
  end
end
