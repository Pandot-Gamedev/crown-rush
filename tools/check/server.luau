-- Starts the whole server outside Roblox (with tools/check/mock.luau) to catch
-- errors in start-up code: missing modules, typos, bad requires.
--
-- Usage (needs Lune):  lune run tools/check/server.luau

local process = require("@lune/process")
local task = require("@lune/task")
local Mock = require("./mock")

Mock.Mount(process.cwd)
local game = Mock.game
local server = game:GetService("ServerScriptService").Server
local ok, err = pcall(Mock.require, server)
if not ok then
	print("Server failed to start: " .. tostring(err))
	process.exit(1)
end
task.wait(0.5)
local map = game:GetService("Workspace"):FindFirstChild("Map")
print("Server started. Map parts: " .. (map and #map:GetDescendants() or 0))
process.exit(0)
