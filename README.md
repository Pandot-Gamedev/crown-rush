# Crown Rush

A Roblox obstacle course game. Play Adventure courses on your own (five worlds,
stars for finishing, beating par and finding 3 hidden gems), or jump into a
tournament: several rounds of races, survival, fights, objectives and team
games until one player takes the crown. Everything sold is looks only.

## Layout

- `src/shared` goes to ReplicatedStorage.Shared: game data (courses, worlds,
  cosmetics, quests) and code both sides use (obstacle motion).
- `src/server` goes to ServerScriptService.Server: the services.
- `src/client` goes to StarterPlayer.StarterPlayerScripts.Client: controls,
  obstacle movement on your screen, menus.

## Trying it in Roblox Studio

- `python3 tools/studio_install.py` prints one line for the Studio command bar
  that installs this commit's scripts into an empty Baseplate, or
- `python3 tools/build_place.py` writes `build/CrownRush.rbxlx` to open in Studio.

Test helpers (Studio only) are listed at the bottom of `src/server/init.server.luau`.

## Adding a course

Courses are lists of obstacle pieces in `src/shared/Courses.luau`. The pieces
are built by `src/server/Kit.luau`; a course is built in the sky when someone
plays it.

## Checks (run before every push)

These need [Lune](https://lune-org.github.io/docs) and run the real game code
outside Roblox with a small stand-in for Roblox (`tools/check/mock.luau`):

- `lune run tools/check/courses.luau` builds every course and proves the
  finish and all gems can be reached from the start and every checkpoint.
- `lune run tools/check/server.luau` starts the whole server.
- `lune run tools/check/play.luau` plays the first world and the Daily
  Challenge with a pretend player and checks the save.
- `lune run tools/check/tournament.luau` plays a whole tournament: two pretend
  players and 10 bots, every round to the crown. Force the first rounds with
  `ROUNDS=door_dash,tile_fall,sweeper`.
