--include=../../Scripts/APM Util.lua

PRINT_TIME			= 0.1
OPEN_DELAY			= 1.5
OPEN_TIME			= 14.25
ANIM_TIME			= 2.0
NUM_CHILDREN		= 7

gTimeSincePrint		= 0.0
gTimeSinceStopped	= 0.0
gTimeSinceOpened	= 0.0
gAnimTime			= 0.0

gOccupationTable	= {}
gTrainsInside		= 0
gLastTrainsInside	= 0
gLastConsistSpeed	= 0.0
gTrainStopped		= false
gDoorsOpen			= false
gDoorsDidOpen		= false

function Initialise()
	gOccupationTable[ 0 ] = 0
	gOccupationTable[ 1 ] = 0

	Call( "BeginUpdate" )
end

function UpdateAnimations( animTime )
	Call( "SetTime", "doors", animTime )

	for i = 2, NUM_CHILDREN + 1 do
		Call( "Gate" .. tostring( i ) .. ":SetTime", "doors", animTime )
	end
end

function Update( timeDelta )
	gTimeSincePrint = gTimeSincePrint + timeDelta
	
	if ( gTimeSincePrint >= PRINT_TIME ) then
		gTimeSincePrint = 0.0
		
		-- Print anything here
	end
	
	if	( gLastConsistSpeed < 0.0025 )	then gTrainStopped = true	elseif
		( gLastConsistSpeed > 0.1 )		then gTrainStopped = false	end
	
	if ( gTrainsInside > 0 and gTrainStopped ) then
		if ( not gDoorsDidOpen ) then
			if ( gTimeSinceStopped >= OPEN_DELAY ) then
				if ( not gDoorsOpen ) then
					gDoorsOpen = true
					debugPrint( "Gate opened" )
				end
			else
				gTimeSinceStopped = gTimeSinceStopped + timeDelta
			end
			
			if ( gDoorsOpen ) then
				if ( gTimeSinceOpened >= OPEN_TIME ) then
					gDoorsOpen			= false
					gDoorsDidOpen		= true
					
					debugPrint( "Gate closed" )
				else
					gTimeSinceOpened	= gTimeSinceOpened + timeDelta
				end
			else
				gTimeSinceOpened = 0.0
			end
		end
	else
		gTimeSinceOpened	= 0.0
		gTimeSinceStopped	= 0.0
		
		gDoorsOpen			= false
		gDoorsDidOpen		= false
	end
	
	if ( gDoorsOpen ) then
		if ( gAnimTime < ANIM_TIME ) then
			gAnimTime = math.min( gAnimTime + timeDelta, ANIM_TIME )
		end
	else
		if ( gAnimTime > 0.0 ) then
			gAnimTime = math.max( gAnimTime - timeDelta, 0.0 )
		end
	end
	
	UpdateAnimations( gAnimTime )
end

function OnConsistPass( prevFrontDist, prevBackDist, frontDist, backDist, linkIndex )
	local crossingStart = 0
	local crossingEnd = 0
	
	gLastConsistSpeed	= Call( "GetConsistSpeed" )

	-- if the consist is crossing the signal now
	if ( sign( frontDist ) ~= sign( backDist ) ) then
		-- if the consist was previously before/after siganl then the crossing has just started
		if ( sign( prevFrontDist ) == sign( prevBackDist ) ) then
			crossingStart = 1
		end
	-- otherwise the consist is not crossing the signal now
	else	
		-- the the consist was previously crossing the signal, then it has just finished crossing
		if ( sign( prevFrontDist ) ~= sign( prevBackDist ) ) then
			crossingEnd = 1
		end
	end

	if ( crossingStart == 1 ) then
		gOccupationTable[ linkIndex ] = gOccupationTable[ linkIndex ] + 1
		
		if ( gTrainsInside > 0 ) then gTrainsInside = gTrainsInside - 1 end
	elseif ( crossingEnd == 1 ) then
		if gOccupationTable[ linkIndex ] > 0 then gOccupationTable[ linkIndex ] = gOccupationTable[ linkIndex ] - 1 end
		
		if ( gOccupationTable[ 0 ] == 0 and gOccupationTable[ 1 ] == 0 ) then gTrainsInside = gTrainsInside + 1 end
	end
	
	if ( gTrainsInside ~= gLastTrainsInside ) then
		
	end
	
	gLastTrainsInside = gTrainsInside
end