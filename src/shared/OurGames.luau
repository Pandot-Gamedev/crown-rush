-- Our games and our Roblox community. This file is the same in all four games,
-- so a change here should be copied to the other three repos.
--
-- The "Free Gift" menu lists the other games (with a Play button that takes
-- you straight there). Each game gives a free, looks-only welcome gift to
-- players who arrive from one of the others. Nothing here changes how well
-- anyone plays.
--
-- CommunityId: our Roblox community's (group's) id, from its page address:
--   roblox.com/communities/<id>/... . 0 = we don't have one (making one costs
--   100 Robux): the menu shows no Join button. Members get the same gift.

local OurGames = {}

OurGames.CommunityId = 0
OurGames.CommunityName = "Pandot Games"

-- Shown on each game's card. universeId is the experience id (the icon comes
-- from it), placeId is where the Play button sends you.
OurGames.List = {
	{
		id = "fish",
		name = "Hook a Mythic Fish!",
		blurb = "Cast, reel and fill your fish book. Can you hook a Mythic?",
		universeId = 10773137504,
		placeId = 139801344157792,
	},
	{
		id = "dig",
		name = "Dig Up a Legendary!",
		blurb = "Dig for treasure in 5 zones and fill your collection.",
		universeId = 10773541582,
		placeId = 83829887315860,
	},
	{
		id = "bonk",
		name = "Bonk Your Friends Off!",
		blurb = "Foam hammer brawls for 2 to 4. Knock everyone off the arena.",
		universeId = 10773598334,
		placeId = 73590219706077,
	},
	{
		id = "crown",
		name = "Only 1 Gets the Crown!",
		blurb = "12 players, crazy obby rounds, one crown. Can you win it?",
		universeId = 10773678497,
		placeId = 134072645580262,
	},
}

OurGames.ById = {}
for _, entry in ipairs(OurGames.List) do
	OurGames.ById[entry.id] = entry
end

function OurGames.Icon(entry)
	return string.format("rbxthumb://type=GameIcon&id=%d&w=150&h=150", entry.universeId)
end

function OurGames.CommunityIcon()
	return string.format("rbxthumb://type=GroupIcon&id=%d&w=150&h=150", OurGames.CommunityId)
end

-- The other games, for the game with this id
function OurGames.Others(thisId)
	local list = {}
	for _, entry in ipairs(OurGames.List) do
		if entry.id ~= thisId then
			table.insert(list, entry)
		end
	end
	return list
end

return OurGames
