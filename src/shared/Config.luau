-- General game settings. Change numbers here to rebalance the game.

local Config = {}

Config.GameName = "Crown Rush"

-- Saving
Config.DataStoreName = "PlayerData_v1"
Config.GhostStoreName = "Ghosts_v1"
Config.CrownsStoreName = "Crowns_v1"
Config.StarsStoreName = "Stars_v1"
Config.WeeklyCrownsStorePrefix = "WeeklyCrowns_"
Config.CourseTimesStorePrefix = "CourseTimes_" -- + course id, best times in hundredths of a second
Config.DailyTimesStorePrefix = "DailyTimes_" -- + day number
Config.AutosaveSeconds = 120

-- Moving. Everyone runs and jumps the same: nothing sold changes this.
Config.WalkSpeed = 20
Config.JumpHeight = 7.5
Config.DiveSpeed = 52 -- a forward lunge (Q / DIVE button) to reach a ledge or grab a gem
Config.DiveUp = 14
Config.DiveCooldown = 1.2
Config.CoyoteSeconds = 0.12 -- you can still jump this long after running off an edge (helps on phones)

-- Obstacles
Config.HitSpeed = 62 -- how hard spinners, hammers and balls knock you
Config.HitUp = 30
Config.HitStun = 0.55
Config.BounceSpeed = 95 -- bounce pads straight up
Config.RespawnSeconds = 0.6 -- time between falling and appearing at your checkpoint
Config.FallBelow = 28 -- studs under the lowest floor of your section counts as a fall

-- Adventure (solo courses)
Config.SkipAfterFalls = 10 -- falls at one checkpoint before the free skip shows up (no stars for that run)
Config.EmptyCourseSeconds = 30 -- a course nobody is on is taken down after this long
Config.CourseSlots = 16 -- how many courses can be built at once on one server
Config.MinTimeShare = 0.35 -- a finish faster than this share of par is ignored (cheating or a bug)

-- Rewards. Coins only buy cosmetics, so they never help you win.
-- Balance: a perfect first run of a course pays about 155 coins, a replay 10,
-- a tournament 15 to 245. Every coin cosmetic together costs about 22,000
-- coins, so collecting them all takes 20+ hours of play.
Config.CourseRewards = { finish = 10, firstFinish = 40, star = 25, gem = 10 }
Config.CourseXp = { finish = 40, firstFinish = 80, star = 30, gem = 10 }
Config.VipCoinBonus = 0.25
Config.DailyChallengeCoins = 150 -- first finish of the Daily Challenge each day
Config.DailyChallengeXp = 120

-- Tournament pay: everyone who plays gets "play", plus "round" for every round
-- survived, plus "win" for the crown. Same for XP.
Config.TournamentRewards = { play = 15, round = 20, win = 150, playXp = 20, roundXp = 25, winXp = 150 }

-- Daily login reward: DailyRewardBase * streak day (streak capped at 7)
Config.DailyRewardBase = 50
Config.DailyStreakCap = 7

-- Set to true to try the VIP pass for free while testing in Roblox Studio.
-- Has no effect in the live game.
Config.TestPassesInStudio = false

-- Fight rounds (foam hammers push, nobody has health)
Config.BonkRange = 7.5
Config.BonkArc = 110
Config.BonkCooldown = 0.45
Config.BonkImpactDelay = 0.12
Config.BonkDamageMin = 8
Config.BonkDamageMax = 12
Config.MaxDamage = 999
Config.KnockBase = 16
Config.KnockScale = 0.6
Config.KnockUpBase = 22
Config.KnockUpScale = 0.3
Config.StunBase = 0.3
Config.StunScale = 0.005
Config.StunMax = 1.2
Config.KoCreditSeconds = 6

function Config.Knockback(damage)
	return Config.KnockBase + Config.KnockScale * damage, Config.KnockUpBase + Config.KnockUpScale * damage
end

function Config.Stun(damage)
	return math.min(Config.StunMax, Config.StunBase + Config.StunScale * damage)
end

return Config
