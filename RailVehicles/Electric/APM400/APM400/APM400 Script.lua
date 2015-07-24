---------------------------------------
-- Class 377 Script --
---------------------------------------
--
-- (c) Railsimulator.com 2012
--

--include=..\..\..\..\Scripts\APM Util.lua

function Initialise()
-- For AWS self test.
	gAWSReady = TRUE
	gAWSTesting = FALSE

-- Stores for checking when values have changed.
	gDriven = -1
	gHeadlight = -1
	gTaillight = -1
	gInitialised = FALSE
	
-- Misc variables
	gInit = false

	Call( "BeginUpdate" )
end

function GetControlValue(name)
	return Call("*:GetControlValue", name, 0)
end

function SetControlValue(name, value)
	Call("*:SetControlValue", name, 0, value)
end

function Update(time)
	local trainSpeed = Call("GetSpeed") * MPS_TO_MPH
	local accel = Call("GetAcceleration") * MPS_TO_MPH
	local reverser = GetControlValue("Reverser")
	
	if (not gInit) then
		gInit = true
	end

	--if ( Call( "GetIsPlayer" ) == 1 ) then

	if ( GetControlValue( "Active" ) == 1 ) then
		
		Headlights = GetControlValue( "Headlights" )
		if (Headlights > 0.5) then
			Call( "HeadlightL:Activate", 1 )
			Call( "HeadlightR:Activate", 1 )
		else
			Call( "HeadlightL:Activate", 0 )
			Call( "HeadlightR:Activate", 0 )
		end
		
		local cabSpeed = clamp(math.floor(math.abs(trainSpeed)), 0, 72)
		SetControlValue("CabSpeedIndicator", cabSpeed)
	else
		Call( "HeadlightL:Activate", 0 )
		Call( "HeadlightR:Activate", 0 )
	end

	if gInitialised == FALSE then
		gInitialised = TRUE
	end

	-- Check if player is driving this engine.

	if ( Call( "GetIsEngineWithKey" ) == 1 ) then
		if gDriven ~= 1 then
			gDriven = 1
			SetControlValue( "Active", 1 )
		end
	else
		if gDriven ~= 0 then
			gDriven = 0
			SetControlValue( "Active", 0 )
			SetControlValue( "ATOActive", 0 )
		end
	end
	--end
	
	-- Direction
	local realAccel = GetControlValue("Acceleration")
	if (math.abs(trainSpeed) > 0.01 and math.abs(realAccel) > 0.1 and math.abs(accel) > 0.1) then
		if (sign(accel) == sign(realAccel)) then
			gLastDir = -1
		else
			gLastDir = 1
		end
		if (GetControlValue("Active") > 0) then
			SetControlValue("Direction", sign(trainSpeed))
		end
	end
	
	SetControlValue("Speed2", round(trainSpeed, 2))
	
	-- Headlights
	if (GetControlValue("IsEndCar") > 0 and GetControlValue("Active") > 0 and GetControlValue("Headlights") > 0) then
		Call("*:ActivateNode", "headlights", 1)
	else
		Call("*:ActivateNode", "headlights", 0)
	end
end

function OnConsistMessage ( msg, argument, direction )
	local cancel = false
	
	-- If this is not the driven vehicle then update the passed-down controls with values from the master engine
	if (GetControlValue("Active") == 0) then
	
	else
		
	end
	
	if not cancel then
		-- Pass message along in same direction.
		Call( "SendConsistMessage", msg, argument, direction )
	end
end

function OnCustomSignalMessage(argument)
	for msg, arg in string.gfind(tostring(argument), "([^=\n]+)=([^=\n]+)") do
		if (tonumber(msg) == MSG_ATO_SPEED_LIMIT) then
			local speedLimit = tonumber(arg)
			if (speedLimit) then
				SetControlValue("ATOSpeedLimit", speedLimit)
			end
		end
	end
	
end

function OnControlValueChange( name, index, value )
	if Call( "*:ControlExists", name, index ) then
		Call( "*:SetControlValue", name, index, value )
	end
end