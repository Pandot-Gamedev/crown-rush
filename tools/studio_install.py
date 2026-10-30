"""Prints a one-line Roblox Studio command that installs the game's scripts
from GitHub into the open place (instead of opening build/CrownRush.rbxlx).

Open a new Baseplate in Studio, paste the line into the command bar (View >
Command Bar) and press Enter. It clears the Workspace, turns streaming off (the
game builds its courses in the sky, so everyone needs them loaded), turns HTTP
on just long enough to download every script at this commit, then turns it off.

Usage: python3 tools/studio_install.py [commit]   (default: the current commit)
"""

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = "Pandot-Gamedev/crown-rush"


def names(folder):
    path = os.path.join(ROOT, "src", folder)
    return " ".join(sorted(f[: -len(".luau")] for f in os.listdir(path) if f.endswith(".luau") and not f.startswith("init.")))


def main():
    commit = sys.argv[1] if len(sys.argv) > 1 else subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    base = f"https://raw.githubusercontent.com/{REPO}/{commit}/src/"
    line = (
        'local H=game:GetService("HttpService") H.HttpEnabled=true workspace.StreamingEnabled=false '
        f'local B="{base}" '
        "for _,c in ipairs(workspace:GetChildren()) do if not c:IsA(\"Camera\") and not c:IsA(\"Terrain\") then c:Destroy() end end "
        "local function mk(k,n,p,f) local o=p:FindFirstChild(n) if o then o:Destroy() end local s=Instance.new(k) s.Name=n if f then s.Source=H:GetAsync(B..f) end s.Parent=p return s end "
        'local sh=mk("Folder","Shared",game.ReplicatedStorage) '
        f'for n in ("{names("shared")}"):gmatch("%S+") do mk("ModuleScript",n,sh,"shared/"..n..".luau") end '
        'local sv=mk("Script","Server",game.ServerScriptService,"server/init.server.luau") '
        f'for n in ("{names("server")}"):gmatch("%S+") do mk("ModuleScript",n,sv,"server/"..n..".luau") end '
        'local cl=mk("LocalScript","Client",game.StarterPlayer.StarterPlayerScripts,"client/init.client.luau") '
        f'for n in ("{names("client")}"):gmatch("%S+") do mk("ModuleScript",n,cl,"client/"..n..".luau") end '
        'H.HttpEnabled=false print("ONLY 1 GETS THE CROWN INSTALLED ' + commit[:7] + '")'
    )
    print(line)


if __name__ == "__main__":
    main()
