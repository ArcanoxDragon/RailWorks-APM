local MI_TO_M								= 1609.34 -- Miles to Meters
local M_TO_MI								= 1.0 / MI_TO_M -- Meters to Miles
local SIGNAL_STATE_SPEED					= 20
local SIGNAL_STATE_STATION					= 21
local ATO_TARGET_DECELERATION				= 1.20 -- Meters/second/second
local LOW_SPEED_BRAKE_DECELERATION			= 0.2675 -- Meters/second/second
local LOW_SPEED_BRAKE_APPLY_TIME			= 0.02
local ACCEL_PER_SECOND						= 1.0 / 3.0 -- Units of acceleration per second ( jerk limit, used for extra buffers )
local DEPART_WAIT_TIME						= 2.0
local SIG_DIR_CORRECTION_TIME				= 1.0

atoK_P										= 1.0 / 7.5
atoK_I										= 1.0 / 12.0
atoK_D										= 0.0
atoMIN_ERROR								= -5.0
atoMAX_ERROR								=  5.0
atoSigDirection								= 0
gSignalDirectionTime						= 0
atoOverrunDist								= 0
 sigType,  sigState,  sigDist,  sigAspect	= 0, 0, 0, 0
tSigType, tSigState, tSigDist, tSigAspect	= 0, 0, 0, 0

-- Stats variables
statStopStartingSpeed						= 0
statStopSpeedLimit							= 0
statStopDistance							= 0
statStopTime								= 0

local stopsFile = io.open( "apm_ato_stops.csv", "w" )
stopsFile:write( "startSpeed_MPH,speedLimit_MPH,distance_m,stopTime_s,berthOffset_cm\n" )
stopsFile:flush()

local function logStop( startingSpeed, speedLimit, distance, totalStopTime, berthOffset )
	stopsFile:write( tostring( round( startingSpeed * MPS_TO_MPH, 2 ) ) .. "," )
	stopsFile:write( tostring( round( speedLimit * MPS_TO_MPH, 2 ) ) .. "," )
	stopsFile:write( tostring( round( distance, 2 ) ) .. "," )
	stopsFile:write( tostring( round( totalStopTime, 2 ) ) .. "," )
	stopsFile:write( tostring( round( berthOffset * 100 --[[ m to cm ]], 2 ) ) )
	stopsFile:write( "\n" )
	stopsFile:flush()
end

function getBrakingDistance( vF, vI, a )
	return ( ( vF * vF ) - ( vI * vI ) ) / ( 2 * a )
end

function getStoppingSpeed( vI, a, d )
	return math.sqrt( math.max( ( vI * vI ) + ( 2 * a * d ), 0.0 ) )
end

local gErrorSums = { }
local gLastErrors = { }
local gSettled = { }
local gSettledTime = { }
local gSettleTarget = { }

function resetPid( pidName )
	local pN = pidName or "default"
	gErrorSums[pN] = 0.0
	gLastErrors[pN] = 0.0
	gSettled[pN] = false
	gSettledTime[pN] = 0.0
	gSettleTarget[pN] = 0.0
end

function pid( pidName, tD, kP, kI, kD, target, real, minErr, maxErr, buffer, iTarget )
	local pN = pidName or "default"
	local mnErr = minErr or -1
	local mxErr = maxErr or 1
	local buf = buffer or 0.0
	local iT = iTarget or target
	
	local e = math.min( target - real, 0 ) - math.min( real - ( target - buf ), 0 )
	local iE = math.min( iT - real, 0 ) - math.min( real - ( iT - ( buf * 0.75 ) ), 0 )
	
	if ( gErrorSums[pN] == nil or gLastErrors[pN] == nil or gSettled[pN] == nil or gSettleTarget[pN] == nil or gSettledTime[pN] == nil ) then resetPid( pN ) end
	if ( gSettled[pN] ) then
		gErrorSums[pN] = math.max( math.min( gErrorSums[pN] + ( iE * tD ), mxErr ), mnErr )
	else
		gErrorSums[pN] = 0.0
	end
	
	local p = kP * e
	local i = kI * gErrorSums[pN]
	local d = kD * ( e - gLastErrors[pN] ) / tD
	
	if ( math.abs( ( e - gLastErrors[pN] ) / tD ) < 1.0 ) then
		if ( gSettledTime[pN] > 1.0 ) then
			gSettled[pN] = true
		else
			gSettledTime[pN] = gSettledTime[pN] + tD
		end
		gSettleTarget[pN] = target
	else
		gSettledTime[pN] = 0
	end
	
	if ( math.abs( gSettleTarget[pN] - target ) > 0.1 ) then
		gSettled[pN] = false
		gSettledTime[pN] = 0
	end
	
	--debugPrint( "[" .. pN .. "] gES: " .. tostring( gErrorSums[pN] ) .. " gLE: " .. tostring( gLastErrors[pN] ) .. " gS: " .. tostring( gSettled[pN] ) )
	--debugPrint( "[" .. pN .. "] gSTm: " .. tostring( gSettledTime[pN] ) .. " gSTg: " .. tostring( gSettleTarget[pN] ) .. " gED: " .. tostring( ( e - gLastErrors[pN] ) * tD ) )
	
	gLastErrors[pN] = e
	return p + i + d, p, i, d
end

gLastATO 				= 1
gLastATC 				= 0
gLastATOThrottle 		= 0
gLockSkipStop			= 0
atoSigDirection 		= 0
atoStopping 			= 0
atoSkippingStop 		= 0
atoMaxSpeed 			= 100
atoIsStopped 			= 0
atoTimeStopped 			= 0
atoStartingSpeedBuffer 	= 0

function UpdateATO( interval )
	-- Original plan was to allocate these *outside* the function for performance reasons
	-- But Lua is stupid so that's not going to happen
	local atoActive, atoThrottle, targetSpeed, trackSpeed, trainSpeed, doorsLeft, doorsRight, trueThrottle, distCorrection, spdBuffer, trainSpeedMPH
	local t, p, i, d
	
	local TrackBrake = Call( "*:GetControlValue", "TrackBrake", 0 )
	if TrackBrake and TrackBrake > 0.5 then
		Call( "*:SetControlValue", "ATOEnabled", 0, -1 )
	end

	if Call( "*:ControlExists", "ATOEnabled", 0 ) < 0.5 then -- Don't update if we don't have ATO installed on the vehicle
		return
	end
	-- Begin Automatic Train Operation ( ATO )
	atoActive = Call( "*:GetControlValue", "ATOEnabled", 0 )
	atoThrottle = Call( "*:GetControlValue", "ATOThrottle", 0 )
	if ( atoActive > 0.0 ) then
		if ( gLastATO < 0.0 ) then
			gLastATC = Call( "*:GetControlValue", "ATCEnabled", 0 )
		end
		
		Call( "*:SetControlValue", "Headlights", 0, 1 )
		Call( "*:SetControlValue", "ATCEnabled", 0, 1 )
		Call( "*:SetControlValue", "Reverser", 0, 1 )
		Call( "*:LockControl", "ThrottleAndBrake", 0, 1 )
		Call( "*:LockControl", "Reverser", 0, 1 )
		
		trainSpeed = Call( "*:GetSpeed" )
		trainSpeedMPH = trainSpeed * MPS_TO_MPH
		doors = Call( "*:GetControlValue", "DoorsOpen", 0 ) > 0.1
		trueThrottle = Call( "*:GetControlValue", "TrueThrottle", 0 )
		skipStop = Call( "*:GetControlValue", "SkipStop", 0 ) > 0
		
		ATCRestrictedSpeed = Call( "*:GetControlValue", "ATCRestrictedSpeed", 0 )
		targetSpeed = ATCRestrictedSpeed * MPH_TO_MPS
		
		spdBuffer = math.max( getBrakingDistance( 0.0, targetSpeed, -ATO_TARGET_DECELERATION ), 0 )
		
		accelBuff = ( ( trueThrottle - ( -1 ) ) / ACCEL_PER_SECOND ) -- Estimated time to reach full brakes from current throttle
		accelBuff = accelBuff * trainSpeed -- Estimated meters covered in the time taken to reach full brakes
		
		spdBuffer = spdBuffer + accelBuff -- Accomodate for jerk limit
		
		tSigType, tSigState, tSigDist, tSigAspect = Call( "*:GetNextRestrictiveSignal", atoSigDirection )
		
		if ( tSigAspect == SIGNAL_STATE_STATION ) then
			sigType, sigState, sigDist, sigAspect = tSigType, tSigState, tSigDist, tSigAspect
		else
			sigType, sigState, sigAspect = tSigType, tSigState, tSigAspect
		end
				
		sigDistDelta = ( tSigDist - gLastSigDist ) / interval
		if ( sigDistDelta > 0.5 ) then
			gSignalDirectionTime = gSignalDirectionTime + interval
		else
			gSignalDirectionTime = 0
		end
		
		if ( gSignalDirectionTime >= SIG_DIR_CORRECTION_TIME ) then
			gSignalDirectionTime = 0
			
			if ( atoSigDirection == 0 ) then
				atoSigDirection = 1
			else
				atoSigDirection = 0
			end
		end
		
		searchDist = tSigDist + 0.1
		searchCount = 0
		while ( searchDist < spdBuffer and sigAspect ~= SIGNAL_STATE_STATION and searchCount < 20 ) do
			tSigType, tSigState, tSigDist, tSigAspect = Call( "*:GetNextRestrictiveSignal", atoSigDirection, searchDist )
			if ( tSigAspect == SIGNAL_STATE_STATION ) then
				sigType, sigState, sigDist, sigAspect = tSigType, tSigState, tSigDist, tSigAspect
			end
			searchCount = searchCount + 1
			searchDist = tSigDist + 0.1
		end
		
		Call( "*:SetControlValue", "SpeedBuffer", 0, spdBuffer )
		
		if ( sigAspect == SIGNAL_STATE_STATION ) then
			if ( trainSpeedMPH > 10.0 and sigDist <= spdBuffer and sigDist >= 15 --[[ we don't want to stop at stations we're too close to ]] and sigDist < gLastSigDist ) then
				if ( skipStop ) then
					atoSkippingStop = 1
					gLockSkipStop = 1
					statStopDistance = sigDist
				else
					if ( atoStopping < 0.5 ) then
						statStopStartingSpeed = trainSpeed
						statStopSpeedLimit = targetSpeed
						statStopDistance = sigDist
						atoStartingSpeedBuffer = spdBuffer
						statStopTime = 0
						atoOverrunDist = 0
						atoStopping = 1
					end
				end
			end
		end
		
		gLastSigDist = tSigDist
		
		SetControlValue( "db_SigAspect", tSigAspect )
		SetControlValue( "db_SigDist"  , tSigDist   )
		SetControlValue( "db_SpdBuffer", spdBuffer  )
		
		if ( atoStopping > 0.5 or ( doors and trainSpeedMPH < 0.1 ) ) then
			local distBuffer = 1.25
			statStopTime = statStopTime + interval
			atoStopping = 1
			
			--local fullBrakesStopDist = trainSpeed * ( trainSpeed / LOW_SPEED_BRAKE_DECELERATION + LOW_SPEED_BRAKE_APPLY_TIME )
			
			if ( ( sigDist < 0.28 or trainSpeed < 0.01 or atoIsStopped > 0.5 ) and atoOverrunDist < 5.0 ) then
				targetSpeed = 0.0
				
				if ( atoIsStopped < 0.5 ) then 
					atoIsStopped = 1.0
				end
				
				if ( trainSpeed <= 0.025 ) then
					if ( atoIsStopped < 1.5 ) then
						targetSpeed = 0.0
						atoIsStopped = 2.0
					end
					
					if ( doors and atoIsStopped < 3.0 ) then
						SetControlValue( "DepartingStation", 0 )
						atoIsStopped = 3.0
					end
					
					if ( atoIsStopped > 2.5 ) then
						if ( not doors ) then
							atoTimeStopped = atoTimeStopped + interval
							
							if ( atoTimeStopped >= DEPART_WAIT_TIME ) then
								--Call( "*:SetControlValue", "LoadCargo", 0, 0 )
								atoStopping = 0
								atoIsStopped = 0
								atoTimeStopped = 0.0
								
								-- logStop( startingSpeed, speedLimit, distance, totalStopTime, distanceFromMarker )
								local berthOffset
								if ( atoOverrunDist > 0 ) then
									berthOffset = -atoOverrunDist
								else
									berthOffset = sigDist
								end
								logStop( statStopStartingSpeed, statStopSpeedLimit, statStopDistance, statStopTime, berthOffset )
								
								statStopStartingSpeed = 0
								statStopSpeedLimit = 0
								statStopDistance = 0
								statStopTime = 0
								atoOverrunDist = 0
							else
								SetControlValue( "DepartingStation", 1 )
							end
						else
							atoTimeStopped = 0.0
						end
					end
				end
			else
				local minStopSpeed = mapRange( sigDist, 2.5, 0.45, 2.0, 0.5, true ) * MPH_TO_MPS
				targetSpeed = math.min( ATCRestrictedSpeed * MPH_TO_MPS, math.max( getStoppingSpeed( targetSpeed, -ATO_TARGET_DECELERATION, spdBuffer - ( sigDist - distBuffer ) ), minStopSpeed ) )
			end
			
			if ( sigAspect ~= SIGNAL_STATE_STATION or tSigDist > statStopDistance + 15 and atoIsStopped < 2.5 ) then -- Lost station marker; possibly overshot
				atoOverrunDist = atoOverrunDist + ( trainSpeed * interval )
				targetSpeed = 0.0
				
				if ( atoOverrunDist > 5.0 ) then -- overshot station by 5.0 meters -- something went wrong; cancel stop
					debugPrint( "Overran too much (" .. tostring( atoOverrunDist ) .. " m); cancelling stop" )
				
					atoIsStopped = 0
					atoStopping = 0
					atoTimeStopped = 0
				end
			end
		else
			if ( sigAspect ~= SIGNAL_STATE_STATION or tSigDist > statStopDistance + 2 ) then
				atoSkippingStop = 0
				gLockSkipStop = 0
			end
		
			if ( trainSpeedMPH > 2.0 ) then
				SetControlValue( "DepartingStation", 0 )
				atoOverrunDist = 0
				atoIsStopped = 0
				atoTimeStopped = 0
			end
		end
		
		targetSpeed = math.floor( targetSpeed * MPS_TO_MPH * 10 ) / 10 -- Round down to nearest 0.1
		pidTargetSpeed = targetSpeed
		Call( "*:SetControlValue", "ATOTargetSpeed", 0, targetSpeed )
		Call( "*:SetControlValue", "ATOOverrun", 0, round( atoOverrunDist * 100.0, 2 ) )
		if ( targetSpeed < 0.1 ) then
			if ( GetControlValue( "DepartingStation" ) > 0 ) then
				atoThrottle = 0.0
			else
				atoThrottle = -1.0
			end
		else
			-- pid( tD, kP, kI, kD, e, minErr, maxErr )
			if ( atoStopping > 0 ) then
				atoK_P = 1.0 / mapRange( trainSpeedMPH, 5.0, 2.0, 2.0, 0.5, true )
			else
				atoK_P = 1.0 / 6.0
			end
			
			-- Prevents I buildup while brakes are releasing, etc
			if ( trainSpeedMPH < 7.0 and ( atoStopping > 0 or atoThrottle > 0 ) ) then resetPid( "ato" ) end
			
			--t, p, i, d = pid( "ato", interval, atoK_P, atoK_I, atoK_D, targetSpeed, trainSpeedMPH, -5.0, 5.0, 2.0, pidTargetSpeed )
			t, p, i, d = pid( "ato", interval, atoK_P, atoK_I, atoK_D, targetSpeed, trainSpeedMPH, -5.0, 5.0 )
			--atoThrottle = clamp( t, -1.0 - ( 1/8 ), 1.0 + ( 1/8 ) )
			atoThrottle = clamp( t, -1.0, 1.0 )
			
			if ( atoStopping > 0 and trainSpeedMPH < 7.0 and atoThrottle > -0.1 ) then
				atoThrottle = math.min( atoThrottle, mapRange( trainSpeedMPH, 5.0, 2.0, 0.0, -0.1, true ) )
			end
			
			Call( "*:SetControlValue", "PID_Settled", 0, gSettled["ato"] and 1 or 0 )
			Call( "*:SetControlValue", "PID_P", 0, p )
			Call( "*:SetControlValue", "PID_I", 0, i )
			Call( "*:SetControlValue", "PID_D", 0, d )
		end
		
		if ( Call( "*:GetControlValue", "ATCBrakeApplication", 0 ) > 0.5 ) then -- ATO got overridden by ATC ( not likely in production but needs to be handled )
			atoThrottle = -1
		end
		
		--[[if ( ATCRestrictedSpeed <= 0.1 and trainSpeed <= 0.01 ) then
			Call( "*:SetControlValue", "Headlights", 0, 0 )
			Call( "*:SetControlValue", "Reverser", 0, 0 ) -- Park train
			Call( "*:SetControlValue", "DestinationSign", 0, 1 ) -- "Not In Service"
		end]]
		
		Call( "*:SetControlValue", "ThrottleAndBrake", 0, ( Call( "*:GetControlValue", "ATOThrottle", 0 ) + 1 ) / 2 )
		Call( "*:SetControlValue", "ApproachingStation", 0, ( atoStopping > 0 and trainSpeedMPH > 2.0 ) and 1 or 0 )
		Call( "*:LockControl", "ApproachingStation", 1 )
		Call( "*:LockControl", "DepartingStation", 1 )
		Call( "*:LockControl", "SkipStop", gLockSkipStop )
	else
		if ( gLastATO > 0.0 ) then
			Call( "*:SetControlValue", "ThrottleAndBrake", 0, 0 )
			Call( "*:SetControlValue", "ApproachingStation", 0, 0 )
			Call( "*:SetControlValue", "DepartingStation", 0, 0 )
			Call( "*:SetControlValue", "SkipStop", 0, 0 )
			Call( "*:LockControl", "ApproachingStation", 0 )
			Call( "*:LockControl", "DepartingStation", 0 )
			Call( "*:LockControl", "SkipStop", 1 )
			Call( "*:SetControlValue", "ATCEnabled", 0, gLastATC )
			Call( "*:SetControlValue", "CancelJerkLimit", 0, 0 )
			Call( "*:LockControl", "ThrottleAndBrake", 0, 0 )
			Call( "*:LockControl", "Reverser", 0, 0 )
			atoThrottle = 0.0
			atoStopping = 0
			atoSkippingStop = 0
			atoIsStopped = 0
			gLockSkipStop = 0
			atoTimeStopped = 0.0
			resetPid( "ato" )
		end
	end
	
	--[[atoThrottle = atoThrottle * ( 1 + ( 1/8 ) )
	
	if ( atoThrottle >= gLastATOThrottle + ( 1/8 ) ) then
		gLastATOThrottle = atoThrottle - ( 1/8 )
	elseif ( atoThrottle <= gLastATOThrottle - ( 1/8 ) ) then
		gLastATOThrottle = atoThrottle + ( 1/8 )
	end
	
	gLastATOThrottle = clamp( gLastATOThrottle, -1.0, 1.0 )
	
	Call( "*:SetControlValue", "ATOThrottle", 0, math.floor( ( math.abs( gLastATOThrottle ) * 10 ) + 0.5 ) / 10 * sign( gLastATOThrottle ) )]]
	
	gLastATOThrottle = atoThrottle
	Call( "*:SetControlValue", "ATOThrottle", 0, atoThrottle )
	
	gLastATO = atoActive
end