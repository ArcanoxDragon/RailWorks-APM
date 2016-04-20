local debugFile = io.open( "lua_debug.log", "w+" )
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

function GetControlValue( name )
	return Call( "*:GetControlValue", name, 0 )
end

function SetControlValue( name, value )
	if ( type( value ) == "boolean" ) then
		Call( "*:SetControlValue", name, 0, value and 1 or 0 )
	else
		Call( "*:SetControlValue", name, 0, value )
	end
end

function carPrint( msg )
	debugPrint( "[" .. Call( "*:GetRVNumber" ) .. "] " .. msg )
end

function debugPrint( msg )
	Print( msg )
	debugFile:seek( "end", 0 )
	debugFile:write( msg .. "\n" )
	debugFile:flush()
end

function split(pString, pPattern)
	local Table = {}
	local fpat = "(.-)" .. pPattern
	local last_end = 1
	local s, e, cap = string.find(pString, fpat, 1)
	
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(Table,cap)
		end
		last_end = e+1
		s, e, cap = string.find(pString, fpat, last_end)
	end
	
	if last_end <= string.len(pString) then
		cap = string.sub(pString, last_end)
		table.insert(Table, cap)
	end
	
	return Table
end

function blend( a, b, bias )
	local bA = clamp( bias or 1.0, 0.0, 2.0 )
	local bB = 2.0 - bias
	
	return ( ( a * bA ) + ( b * bB ) ) / 2.0
end

function clamp( x, xMin, xMax )
	return math.min( math.max( x, xMin ), xMax )
end

function round( num, precision )
	local mult = 10 ^ ( precision or 0 )
	return math.floor( num * mult + 0.5 ) / mult
end

function sign( num )
	if ( num > 0 ) then return 1 end
	if ( num < 0 ) then return -1 end
	return 0
end

function mod( a, b )
	return a - math.floor( a / b ) * b
end

function reverseMsgDir( direction )
	if ( direction == 0 ) then return 1 end
	return 0
end

function mapRange( value, sourceMin, sourceMax, destMin, destMax, doClamp )
	local c = doClamp and true or false -- Convert optional into boolean
	local normalized = ( value - sourceMin ) / ( sourceMax - sourceMin )
	
	if c then
		return clamp( normalized * ( destMax - destMin ) + destMin, destMin, destMax )
	else
		return normalized * ( destMax - destMin ) + destMin
	end
end












