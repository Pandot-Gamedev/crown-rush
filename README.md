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
