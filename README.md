# Monopoly

A GenServer that implements some moving around a game board with suspending and resuming of games.

## Running
* have elixir and erlang installed
* change `@backup_dir` in `Monopoly.Game` to a location on your computer.
* `iex -S mix`
* `{:ok, pid} = Monopoly.Game.new_game(["bob", "deryl"], 1)`
* `Monopoly.Game.roll(pid, bob)`
* `Monopoly.Game.suspend_game(pid)`
* `Monopoly.Game.resume_game(1)`

