---------------------------------------
-- Class 377 Script --
---------------------------------------
--
-- ( c ) Railsimulator.com 2012
--

--include=..\..\..\..\Scripts\APM Util.lua

function Initialise( )
-- For AWS self test.
	gAWSReady			= TRUE
	gAWSTesting			= FALSE

-- Stores for checking when values have changed.
	gDriven				= -1
	gHeadlight			= -1
	gTaillight			= -1
	gInitialised		= FALSE

-- TractionRelay
	gTractionRelay		= false
	gLastTractionRelay	= false
	
-- Lead car pinging
	gTrailingCars		= {}

	gPingDelay			= 1.0 -- seconds
	gPingTimeout		= 3.0 -- seconds til a car "disappears"
	gPingMessage		= 4001
	
	gTimeSincePing		= gPingDelay
	gTimeStopped		= 0.0
	
-- Door interlocks
	-- For controlling delayed doors interlocks.
	DOORDELAYTIME		= 6.5 -- seconds.
	gDoorsDelay			= 0.0
	gDoorsLeft			= false
	gDoorsRight			= false
	gDoorsClosing		= false
	gLastDoorsLeft		= false
	gLastDoorsRight		= false
	
-- Misc variables
	gInit				= false

	Call( "BeginUpdate" )
end

-- Message: carNum|leftDoors|rightDoors
function OnCarPing( pingMsg )
	local valTable		= split( pingMsg, "|" )
	
	local carNum		= valTable[ 1 ]
	local doorsLeft		= valTable[ 2 ] and valTable[ 2 ] ~= "0"
	local doorsRight	= valTable[ 3 ] and valTable[ 3 ] ~= "0"
	local doorsClosing	= valTable[ 4 ] and valTable[ 4 ] ~= "0"
	
	gTrailingCars[ carNum ] = {
		carNum			= carNum,
		doorsLeft		= doorsLeft,
		doorsRight		= doorsRight,
		doorsClosing	= doorsClosing,
		sincePing		= 0
	}
end

function UpdateTrailingCars( time )
	for k, v in pairs( gTrailingCars ) do
		if ( gTrailingCars[ k ] ) then
			v.sincePing = v.sincePing + time
			
			if ( v.sincePing >= gPingTimeout ) then
				gTrailingCars[ k ]	= nil
			else
				gDoorsLeft			= gDoorsLeft	or v.doorsLeft
				gDoorsRight			= gDoorsRight	or v.doorsRight
				gDoorsClosing		= gDoorsClosing	or v.doorsClosing
			end
		end
	end
end

function OnCameraLeave()
	-- Reset "trailing cars" as we're no longer the "active cab"
	gTrailingCars = {}
end

function OnCameraEnter( cabEnd, carriage )
	-- Reset door controls as they may switch sides when switching to a car facing the other way
	-- (this will fix the HUD showing both sides open at once)
	SetControlValue( "DoorsLeftGlobal"	, 0 )
	SetControlValue( "DoorsRightGlobal"	, 0 )
	SetControlValue( "DoorsClosing"		, 0 )
	SetControlValue( "DoorsOpen"		, 0 )
end

function SwapMessageDoors( message )
	local t = split( message, "|" )
	
	t[ 2 ], t[ 3 ] = t[ 3 ], t[ 2 ]
	
	return table.concat( t, "|" )
end

function OnConsistMessage( msg, argument, direction )
	local cancel = false
	
	if ( GetControlValue( "Active" ) > 0 ) then
		if ( msg == gPingMessage ) then
			OnCarPing( argument )
			cancel = true
		end
	else
		
	end
	
	if ( GetControlValue( "Active" ) == 1 ) then
		--carPrint( table.concat( { msg, argument, direction }, "; " ) )
	end
	
	if ( msg == gPingMessage and direction == 1 ) then
		--argument = SwapMessageDoors( argument )
	end
	
	if not cancel then
		-- Pass message along in same direction.
		Call( "SendConsistMessage", msg, argument, direction )
	end
end

function Update( time )
	local trainSpeed	= Call				( "GetSpeed"			) * MPS_TO_MPH
	local accel			= Call				( "GetAcceleration"		) * MPS_TO_MPH
	local reverser		= GetControlValue	( "Reverser"			)
	local atoEnabled	= GetControlValue	( "ATOEnabled"			) > 0.5
	local ammeter		= GetControlValue	( "Ammeter"				)
	local throttle
	local leftDoors		= GetControlValue	( "DoorsOpenCloseLeft"	) > 0.5
	local rightDoors	= GetControlValue	( "DoorsOpenCloseRight"	) > 0.5
	local doors			= leftDoors or rightDoors
	gDoorsLeft			= leftDoors
	gDoorsRight			= rightDoors
	gDoorsClosing		= false
	
	if ( GetControlValue( "Active" ) == 1 ) then
		UpdateTrailingCars( time )
	end
	
	-- Doors
	
	if ( doors ) then
		gDoorsDelay = DOORDELAYTIME
		
		gLastDoorsLeft	= gDoorsLeft
		gLastDoorsRight	= gDoorsRight
	else
		if ( gDoorsDelay > 0.0 ) then
			gDoorsDelay		= gDoorsDelay - time
			gDoorsLeft		= gLastDoorsLeft
			gDoorsRight		= gLastDoorsRight
			gDoorsClosing	= true
		else
			if ( gLastDoorsLeft or gLastDoorsRight ) then
				gLastDoorsLeft	= false
				gLastDoorsRight	= false
			end
		end
	end
	
	-- End doors
		
	-- Cross-car pinging
	
	gTimeSincePing = gTimeSincePing + time
	
	if ( gTimeSincePing >= gPingDelay and GetControlValue( "Active" ) == 0 ) then
		gTimeSincePing = 0.0
		
		local pingMessageF = Call( "*:GetRVNumber" ) .. "|" .. ( gDoorsRight	and "1" or "0" ) .. "|" .. ( gDoorsLeft		and "1" or "0" ) .. "|" .. ( gDoorsClosing and "1" or "0" )
		local pingMessageB = Call( "*:GetRVNumber" ) .. "|" .. ( gDoorsLeft		and "1" or "0" ) .. "|" .. ( gDoorsRight	and "1" or "0" ) .. "|" .. ( gDoorsClosing and "1" or "0" )
		Call( "SendConsistMessage", gPingMessage, pingMessageB, 0 )
		Call( "SendConsistMessage", gPingMessage, pingMessageF, 1 )
	end
		
	-- End cross-car pinging
	
	if ( atoEnabled ) then
		throttle = GetControlValue( "ATOThrottle" )
	else
		throttle = GetControlValue( "ThrottleAndBrake" ) * 2.0 - 1.0
	end
	
	if ( not gInit ) then
		gInit = true
	end

	--if ( Call( "GetIsPlayer" ) == 1 ) then

	if ( GetControlValue( "Active" ) == 1 ) then
		
		Headlights = GetControlValue( "Headlights" )
		if ( Headlights > 0.5 ) then
			Call( "HeadlightL:Activate", 1 )
			Call( "HeadlightR:Activate", 1 )
		else
			Call( "HeadlightL:Activate", 0 )
			Call( "HeadlightR:Activate", 0 )
		end
		
		local cabSpeed = clamp( math.floor( math.abs( trainSpeed ) ), 0, 72 )
		SetControlValue( "CabSpeedIndicator", cabSpeed )
		
		SetControlValue( "DoorsOpen"		, ( gDoorsLeft or gDoorsRight ) and 1 or 0 )
		SetControlValue( "DoorsLeftGlobal"	, gDoorsLeft	and 1 or 0 )
		SetControlValue( "DoorsRightGlobal"	, gDoorsRight	and 1 or 0 )
		SetControlValue( "DoorsClosing"		, gDoorsClosing and 1 or 0 )
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
	local realAccel = GetControlValue( "Acceleration" )
	if ( math.abs( trainSpeed ) > 0.01 and math.abs( realAccel ) > 0.1 and math.abs( accel ) > 0.1 ) then
		if ( sign( accel ) == sign( realAccel ) ) then
			gLastDir = -1
		else
			gLastDir = 1
		end
		if ( GetControlValue( "Active" ) > 0 ) then
			SetControlValue( "Direction", sign( trainSpeed ) )
		end
	end
	
	SetControlValue( "Speed2", round( trainSpeed, 2 ) )
	
	-- Headlights
	if ( GetControlValue( "IsEndCar" ) > 0 and GetControlValue( "Active" ) > 0 and GetControlValue( "Headlights" ) > 0 ) then
		Call( "*:ActivateNode", "headlights", 1 )
	else
		Call( "*:ActivateNode", "headlights", 0 )
	end
	
	-- Count stopping time
	if ( trainSpeed < 0.005 ) then
		gTimeStopped = gTimeStopped + time
	else
		gTimeStopped = 0.0
	end
	
	-- Traction relay
	if ( ammeter > 0.01 ) then
		gTractionRelay = true
	elseif ( gTimeStopped > 0.5 ) then
		gTractionRelay = false
	end
	
	if ( gTractionRelay ~= gLastTractionRelay ) then
		SetControlValue( "TractionRelay", gTractionRelay )
	end
	
	gLastTractionRelay = gTractionRelay
end

function OnCustomSignalMessage( argument )
	for msg, arg in string.gfind( tostring( argument ), "([^=\n]+)=([^=\n]+)" ) do
		if ( tonumber( msg ) == MSG_ATO_SPEED_LIMIT ) then
			local speedLimit = tonumber( arg )
			if ( speedLimit ) then
				SetControlValue( "ATOSpeedLimit", speedLimit )
			end
		elseif ( tonumber( msg ) == MSG_BERTH_STATUS ) then
			local berthed = tonumber( arg ) > 0
			
			SetControlValue( "Berthed", berthed and 1 or 0 )
		end
	end
	
end

function OnControlValueChange( name, index, value )
	if Call( "*:ControlExists", name, index ) then
		Call( "*:SetControlValue", name, index, value )
	end
end
