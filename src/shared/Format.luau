-- Small helpers for showing numbers and times.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.23K", 5600000 -> "5.6M"
function Format.Number(n)
	n = math.floor(n or 0)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local index = 1
	local value = n
	while math.abs(value) >= 1000 and index < #SUFFIXES do
		value = value / 1000
		index += 1
	end
	local text = string.format("%.2f", value)
	text = text:gsub("0+$", ""):gsub("%.$", "")
	return text .. SUFFIXES[index]
end

-- 3725 -> "1h 2m", 95 -> "1m 35s"
function Format.Duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

-- Damage % color: white, then yellow, orange and red as it climbs
function Format.DamageColor(damage)
	if damage < 50 then
		return Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 230, 80), damage / 50)
	elseif damage < 100 then
		return Color3.fromRGB(255, 230, 80):Lerp(Color3.fromRGB(255, 140, 40), (damage - 50) / 50)
	end
	return Color3.fromRGB(255, 140, 40):Lerp(Color3.fromRGB(230, 30, 30), math.clamp((damage - 100) / 60, 0, 1))
end

-- 75 -> "1:15"
function Format.Clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

return Format
