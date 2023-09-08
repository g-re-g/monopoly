# Monopoly

A GenServer that implements some moving around a game board with suspending and resuming of games.

## Running
* have elixir and erlang installed
* change `@backup_dir` in `Monopoly.Game` and `Monopoly.Game.Manager` to a location on your computer.
* `iex -S mix`

Useful commands:

```elixir
{:ok, pid} = Monopoly.Game.Manager.new_game(["bob", "deryl"], 1)
Monopoly.Game.roll(pid, bob)
Monopoly.Game.suspend_game(pid)
{:ok, pid} = Monopoly.Game.Manager.resume_game(1)
Monopoly.Game.Manager.running_games
Monopoly.Game.die(pid)
Monopoly.Game.Manager.running_games
```


