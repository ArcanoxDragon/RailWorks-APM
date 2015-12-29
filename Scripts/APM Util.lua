local debugFile = io.open("lua_debug.log", "w+")
MPS_TO_MPH = 2.23694 -- Meters/Second to Miles/Hour
MPH_TO_MPS = 1.0 / MPS_TO_MPH
MPH_TO_MiPS = 0.000277777778 -- Miles/Hour to Miles/Second
pi = 3.14159265

-- Why RailWorks defined these, I have no clue, but I'm keeping them defined anyways...
TRUE = 1
FALSE = 0

-- Digits constants

PRIMARY_DIGITS = 0
SECONDARY_DIGITS = 1

function GetControlValue(name)
	return Call("*:GetControlValue", name, 0)
end

function SetControlValue(name, value)
	Call("*:SetControlValue", name, 0, value)
end

function debugPrint(msg)
	Print(msg)
	debugFile:seek("end", 0)
	debugFile:write(msg .. "\n")
	debugFile:flush()
end

function clamp(x, xMin, xMax)
	return math.min(math.max(x, xMin), xMax)
end

function round(num, precision)
	local mult = 10 ^ (precision or 0)
	return math.floor(num * mult + 0.5) / mult
end

function sign(num)
	if (num > 0) then return 1 end
	if (num < 0) then return -1 end
	return 0
end

function mod(a, b)
	return a - math.floor(a / b) * b
end

function reverseMsgDir(direction)
	if (direction == 0) then return 1 end
	return 0
end

function mapRange(value, sourceMin, sourceMax, destMin, destMax)
	local normalized = (value - sourceMin) / (sourceMax - sourceMin)
	return normalized * (destMax - destMin) + destMin
end