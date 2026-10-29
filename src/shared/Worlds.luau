-- The five Adventure worlds. Stars from courses unlock the next world.
-- Colours here dress every course and tournament round in that world's look.

local Worlds = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Worlds.List = {
	{
		id = "candy",
		name = "Candy Clouds",
		stars = 0,
		blurb = "Pastel sky islands. Spinners, bounce pads and moving platforms.",
		floor = { rgb(255, 170, 210), rgb(255, 240, 245) },
		edge = rgb(255, 105, 170),
		mover = rgb(120, 210, 255),
		hazard = rgb(255, 70, 90),
		accent = rgb(255, 220, 90),
		deco = rgb(170, 120, 255),
		material = Enum.Material.SmoothPlastic,
		sky = { top = rgb(150, 200, 255), fog = rgb(255, 215, 235), ambient = rgb(170, 160, 190) },
		gravity = nil,
	},
	{
		id = "jungle",
		name = "Jungle Ruins",
		stars = 10,
		blurb = "Old temples and vines. Swinging hammers, rolling boulders and ziplines.",
		floor = { rgb(150, 140, 115), rgb(120, 160, 90) },
		edge = rgb(90, 75, 60),
		mover = rgb(190, 140, 80),
		hazard = rgb(200, 90, 50),
		accent = rgb(250, 200, 80),
		deco = rgb(60, 140, 70),
		material = Enum.Material.Slate,
		sky = { top = rgb(140, 200, 170), fog = rgb(170, 210, 160), ambient = rgb(120, 150, 110) },
		gravity = nil,
	},
	{
		id = "frost",
		name = "Frost Peak",
		stars = 25,
		blurb = "Ice and snow. Wind gusts, falling tiles and slippery slides.",
		floor = { rgb(235, 245, 255), rgb(175, 220, 250) },
		edge = rgb(110, 170, 220),
		mover = rgb(150, 200, 255),
		hazard = rgb(60, 110, 200),
		accent = rgb(255, 255, 255),
		deco = rgb(200, 235, 255),
		material = Enum.Material.Snow,
		sky = { top = rgb(190, 220, 245), fog = rgb(225, 240, 255), ambient = rgb(170, 185, 210) },
		gravity = nil,
	},
	{
		id = "lava",
		name = "Lava Factory",
		stars = 40,
		blurb = "Pipes and conveyor belts. Rising lava, pistons and laser gates.",
		floor = { rgb(95, 95, 105), rgb(70, 70, 80) },
		edge = rgb(255, 150, 40),
		mover = rgb(250, 190, 60),
		hazard = rgb(255, 80, 30),
		accent = rgb(255, 210, 60),
		deco = rgb(60, 60, 70),
		material = Enum.Material.DiamondPlate,
		sky = { top = rgb(90, 50, 40), fog = rgb(120, 60, 40), ambient = rgb(150, 100, 80) },
		gravity = nil,
	},
	{
		id = "space",
		name = "Star Station",
		stars = 60,
		blurb = "Low gravity in space. Spinning discs, fake doors and big jumps.",
		floor = { rgb(70, 60, 120), rgb(45, 40, 85) },
		edge = rgb(90, 255, 230),
		mover = rgb(180, 120, 255),
		hazard = rgb(255, 60, 180),
		accent = rgb(90, 255, 230),
		deco = rgb(30, 25, 60),
		material = Enum.Material.Metal,
		sky = { top = rgb(20, 15, 45), fog = rgb(40, 30, 80), ambient = rgb(120, 110, 170) },
		gravity = 120, -- players jump higher and float longer here
	},
}

Worlds.ById = {}
for index, world in ipairs(Worlds.List) do
	world.index = index
	Worlds.ById[world.id] = world
end

-- The world after this one, or nil for the last
function Worlds.Next(worldId)
	local world = Worlds.ById[worldId]
	return world and Worlds.List[world.index + 1] or nil
end

return Worlds
