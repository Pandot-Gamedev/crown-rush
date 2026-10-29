-- How every moving obstacle moves. Each moving part carries attributes that
-- describe its motion, and its position is worked out from the server clock.
-- That way every player's computer moves the obstacles itself (perfectly
-- smooth, no lag) and they still all agree, and the server can work out where
-- anything is at any moment (for the bots).
--
-- Attributes on a moving part (tagged "Moving"):
--   Motion  "spin" | "swing" | "rock" | "slide" | "piston" | "ball" | "blink" | "lava"
--   Home    CFrame: the pivot the part moves around (or its rest place)
--   Offset  CFrame: where the part sits relative to the pivot (default: on it)
--   Speed   spin: radians per second (negative = the other way)
--   Amp     swing/rock: radians either side
--   Period  seconds for one full back-and-forth (or one cycle)
--   Phase   seconds added to the clock, so neighbours don't move in step
--   Axis    slide/piston: local direction (Vector3) and Dist: how far
--   Hold    slide: share of each half spent waiting at the ends (0 to 0.45)
--   On      blink: seconds solid in each cycle
--   Travel, Length, Radius   ball: seconds to roll down, lane length, ball radius
--   Low, High, Rise          lava: heights and seconds to climb

local Workspace = game:GetService("Workspace")

local Motion = {}

Motion.Tag = "Moving"
local EPOCH = 1790000000 -- keeps the clock numbers small, for precise maths
local TAU = math.pi * 2

function Motion.Clock()
	return Workspace:GetServerTimeNow() - EPOCH
end

-- Reads a part's motion attributes once into a table
function Motion.Read(part)
	local attributes = part:GetAttributes()
	return {
		kind = attributes.Motion,
		home = attributes.Home or part.CFrame,
		offset = attributes.Offset or CFrame.identity,
		speed = attributes.Speed or 1,
		amp = attributes.Amp or 0.8,
		period = math.max(0.1, attributes.Period or 4),
		phase = attributes.Phase or 0,
		axis = attributes.Axis or Vector3.xAxis,
		dist = attributes.Dist or 10,
		hold = math.clamp(attributes.Hold or 0.2, 0, 0.45),
		on = attributes.On or 2,
		travel = attributes.Travel or 3,
		length = attributes.Length or 40,
		radius = attributes.Radius or 3,
		low = attributes.Low or 0,
		high = attributes.High or 10,
		rise = attributes.Rise or 3,
	}
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Where along a slide (0 = home, 1 = home + axis * dist), with waits at both ends
function Motion.SlideShare(spec, t)
	local u = ((t + spec.phase) / spec.period) % 1
	local half = u < 0.5 and u * 2 or (u - 0.5) * 2
	local hold = spec.hold
	local moving = (half - hold) / (1 - 2 * hold)
	local s = smooth(moving)
	return u < 0.5 and s or 1 - s
end

local function pistonShare(spec, t)
	local u = ((t + spec.phase) / spec.period) % 1
	if u < 0.08 then
		return smooth(u / 0.08) -- punch out fast
	elseif u < 0.35 then
		return 1
	elseif u < 0.65 then
		return 1 - smooth((u - 0.35) / 0.3) -- pull back slowly
	end
	return 0
end

-- Returns cframe, state. state is "solid", "warn" (about to vanish) or "gone".
function Motion.At(spec, t)
	local kind = spec.kind
	if kind == "spin" then
		return spec.home * CFrame.Angles(0, spec.speed * t + spec.phase, 0) * spec.offset, "solid"
	elseif kind == "swing" then
		local angle = spec.amp * math.sin(TAU * (t + spec.phase) / spec.period)
		return spec.home * CFrame.Angles(0, 0, angle) * spec.offset, "solid"
	elseif kind == "rock" then
		local angle = spec.amp * math.sin(TAU * (t + spec.phase) / spec.period)
		return spec.home * CFrame.Angles(angle, 0, 0) * spec.offset, "solid"
	elseif kind == "slide" then
		return spec.home * CFrame.new(spec.axis * spec.dist * Motion.SlideShare(spec, t)) * spec.offset, "solid"
	elseif kind == "piston" then
		return spec.home * CFrame.new(spec.axis * spec.dist * pistonShare(spec, t)) * spec.offset, "solid"
	elseif kind == "ball" then
		local u = (t + spec.phase) % spec.period
		if u > spec.travel then
			return spec.home * CFrame.new(0, -500, 0), "gone"
		end
		local along = spec.length * u / spec.travel
		return spec.home * CFrame.new(0, 0, -along) * CFrame.Angles(-along / spec.radius, 0, 0), "solid"
	elseif kind == "blink" then
		local u = (t + spec.phase) % spec.period
		if u >= spec.on then
			return spec.home, "gone"
		elseif u >= spec.on - 0.7 then
			return spec.home, "warn"
		end
		return spec.home, "solid"
	elseif kind == "lava" then
		local u = (t + spec.phase) % spec.period
		local rise = spec.rise
		local share
		if u < rise then
			share = smooth(u / rise)
		elseif u < spec.period / 2 then
			share = 1
		elseif u < spec.period / 2 + rise then
			share = 1 - smooth((u - spec.period / 2) / rise)
		else
			share = 0
		end
		return spec.home + Vector3.new(0, spec.low + (spec.high - spec.low) * share, 0), "solid"
	end
	return spec.home * spec.offset, "solid"
end

-- How fast a point on the part is moving right now (for knockback direction)
function Motion.VelocityAt(spec, t, worldPoint)
	local a = Motion.At(spec, t)
	local b = Motion.At(spec, t + 0.05)
	local localPoint = a:PointToObjectSpace(worldPoint)
	return (b:PointToWorldSpace(localPoint) - worldPoint) / 0.05
end

return Motion
