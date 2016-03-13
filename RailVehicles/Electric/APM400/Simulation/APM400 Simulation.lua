--include=..\..\Scripts\ATC.lua
--include=..\..\Scripts\ATO.lua
--include=..\CabView\APM400 Hud.lua
--include=..\..\..\..\Scripts\APM Util.lua
--include=..\..\Scripts\ThrottleControl.lua


------------------------------------------------------------
-- Simulation file for the APM 400
------------------------------------------------------------
--
-- (c) briman0094 2015
--
------------------------------------------------------------
function Setup()
	
-- For throttle/brake control.

	gLastDoorsOpen 				= 0
	gSetReg 					= 0
	gSetDynamic 				= 0
	gSetBrake 					= 0
	gLastSpeed 					= 0
	gTimeDelta 					= 0
	gCurrent 					= 0
	gLastReverser 				= 0

	tReg 						= 0
	tBrake 						= 0

	REG_DELTA 					= 0.7
	BRK_DELTA 					= 0.45

	MAX_ACCELERATION 			= 1.0
	MIN_ACCELERATION 			= 0.125
	MAX_BRAKING 				= 1.0
	MIN_BRAKING 				= 0.2
	JERK_LIMIT 					= 1.0 / 1.75
	JERK_DELTA 					= JERK_LIMIT * 3.0
	JERK_THRESHOLD 				= 1.0 / 2.5
	MAX_SERVICE_BRAKE 			= 1.0
	MIN_SERVICE_BRAKE 			= 0.0
	ACCEL_CORRECTION_THRESHOLD	= 0.1
	ACCEL_CORRECTION_DELAY 		= 1.5
	ACCEL_CORRECTION_RATE 		= 0.25
	
-- Propulsion system variables
	realAccel 					= 0.0
	gAccel 						= 0.0
	tAccel 						= 0.0
	tTAccel 					= 0.0
	tThrottle 					= 0.0
	dDyn 						= 0.0
	dReg 						= 0.0
	dBrk 						= 0.0
	dAccel 						= 0.0
	MAX_BRAKE 					= 1.0
	gThrottleTime 				= 0.0
	gAvgAccel 					= 0.0
	gAvgAccelTime 				= 0.0
	gBrakeRelease 				= 0.0
	gTakeoffTime				= 0.0
	brkAdjust 					= 0.0
	gLastJerkLimit 				= 0.0
	gPosAccelTime 				= 0.0
	gNegAccelTime 				= 0.0
	gMinAccelAdjust 			= 0.0
	gMinBrakeAdjust 			= 0.0
	gRollback					= false
	
-- Throttle Control
	gThrottleControl = ThrottleControl.create( JERK_LIMIT, JERK_DELTA, JERK_THRESHOLD )

-- For controlling delayed doors interlocks.
	DOORDELAYTIME = 9.5 -- seconds.
	gDoorsDelay = DOORDELAYTIME
end

------------------------------------------------------------
-- Update
------------------------------------------------------------
-- Called every frame to update the simulation
------------------------------------------------------------
-- Parameters:
--	interval = time since last update
------------------------------------------------------------

function Update( gTimeDelta )

	if Call( "*:GetControlValue", "Active", 0 ) == 1 then -- This is lead engine.

		if Call( "IsExpertMode" ) == TRUE then -- Expert mode only.

			CombinedLever = Call( "*:GetControlValue", "ThrottleAndBrake", 0 )
			ReverserLever = Call( "*:GetControlValue", "Reverser", 0 )
			TrackBrake = Call( "*:GetControlValue", "TrackBrake", 0 )
			DoorsOpen = Call( "*:GetControlValue", "DoorsOpenCloseRight", 0 ) + Call( "*:GetControlValue", "DoorsOpenCloseLeft", 0 )
			PantoValue = Call( "*:GetControlValue", "PantographControl", 0 )
			ThirdRailValue = Call( "*:GetControlValue", "ThirdRail", 0 )
			TrainSpeed = Call( "*:GetControlValue", "SpeedometerMPH", 0 )
			AbsSpeed = math.abs( TrainSpeed )
			BrakeCylBAR = Call( "*:GetControlValue", "TrainBrakeCylinderPressureBAR", 0 )
			IsEndCar = Call( "*:GetControlValue", "IsEndCar", 0 ) > 0
			ATOEnabled = ( Call( "*:GetControlValue", "ATOEnabled", 0 ) or -1 ) > 0.5
			ATOThrottle = ( Call( "*:GetControlValue", "ATOThrottle", 0 ) or -1 )
			Ammeter = Call( "*:GetControlValue", "Ammeter", 0 )
			
			-- Headlights
			
			if ( Call( "*:GetControlValue", "Active", 0 ) > 0.5 ) then
				if ( math.abs( ReverserLever ) > 0.8 ) then
					Call( "*:SetControlValue", "Headlights", 0, 1 )
				elseif ( math.abs( ReverserLever ) < 0.2 ) then
					Call( "*:SetControlValue", "Headlights", 0, 0 )
				end
			end
			
			-- Make script think doors are still open while the animation is finishing
			if ( gLastDoorsOpen == TRUE ) and ( DoorsOpen == FALSE ) then
				gDoorsDelay = gDoorsDelay - gTimeDelta
				if gDoorsDelay < 0 then
					gDoorsDelay = DOORDELAYTIME
				else
					DoorsOpen = TRUE
				end
			end
			Call( "*:SetControlValue", "DoorsOpen", 0, math.min( DoorsOpen, 1 ) )
		
			-- Begin propulsion system
			realAccel = ( TrainSpeed - gLastSpeed ) / gTimeDelta
			gAvgAccel = gAvgAccel + ( TrainSpeed - gLastSpeed )
			gAvgAccelTime = gAvgAccelTime + gTimeDelta
			-- Average out acceleration
			if ( gAvgAccelTime >= 1/15 ) then
				gAccel = round( gAvgAccel / gAvgAccelTime, 2 )
				Call( "*:SetControlValue", "Acceleration", 0, gAccel )
				gAvgAccelTime = 0.0
				gAvgAccel = 0.0
			end
			
			gCurrent = Call( "*:GetControlValue", "Ammeter", 0 )
			
			-- Set throttle based on ATO or not
			if ATOEnabled then
				tThrottle = ATOThrottle
				Call( "*:SetControlValue", "ThrottleLever", 0, 0 )
			else
				tThrottle = CombinedLever * 2.0 - 1.0
				Call( "*:SetControlValue", "ThrottleLever", 0, CombinedLever )
			end
			
			-- Round throttle to 0 if it's below 10% power/brake; widens "coast" gap
			if ( math.abs( tThrottle ) < 0.1 and not ATOEnabled ) then
				tThrottle = 0.0
			end
			
			if ( ATOEnabled ) then
				if ( tThrottle >= 0.001 ) then -- Accelerating; bind range to [ MIN_ACCELERATION, MAX_ACCELERATION ]
					tTAccel = mapRange( tThrottle, 0.0, 1.0, 0.0, MAX_ACCELERATION )
				elseif ( tThrottle <= -0.001 ) then -- Braking; bind range to [ MIN_BRAKING, MAX_BRAKING ]
					tTAccel = -mapRange( -tThrottle, 0.0, 1.0, 0.0, MAX_BRAKING )
				else
					tTAccel = 0.0
				end
			else
				if ( tThrottle >= 0.1 ) then -- Accelerating; bind range to [ MIN_ACCELERATION, MAX_ACCELERATION ]
					tTAccel = mapRange( tThrottle, 0.1, 0.9, MIN_ACCELERATION, MAX_ACCELERATION )
				elseif ( tThrottle <= -0.1 ) then -- Braking; bind range to [ MIN_BRAKING, MAX_BRAKING ]
					tTAccel = -mapRange( -tThrottle, 0.1, 0.9, MIN_BRAKING, MAX_BRAKING )
				else
					tTAccel = 0.0
				end
			end
			
			-- If requesting acceleration and stopped, release brakes instantly
			if ( tTAccel >= 0 and AbsSpeed < 0.1 ) then
				tAccel = math.max( tAccel, 0.0 )
			end
			
			-- Reduce jerk while train comes to a complete stop
			if ( AbsSpeed < 6.5 ) then
				local maxBrake = clamp( mapRange( AbsSpeed, 6.5, 1.0, 1.0, 0.325 ), gMinBrakeAdjust, 1.0 )
				tTAccel = math.max( tTAccel, -maxBrake )
			end
			
			if ( tTAccel < 0 and AbsSpeed < 3.0 ) then
				if ( gAccel > -ACCEL_CORRECTION_THRESHOLD ) then
					gNegAccelTime = gNegAccelTime + gTimeDelta
				end
			else
				gNegAccelTime = 0
			end
			
			if ( gNegAccelTime > ACCEL_CORRECTION_DELAY ) then
				gMinBrakeAdjust = gMinBrakeAdjust + ( ACCEL_CORRECTION_RATE * gTimeDelta )
			else
				gMinBrakeAdjust = 0.0
			end
			
			gMinBrakeAdjust = clamp( gMinBrakeAdjust, 0.2, 1.0 )
			
			-- Parked or track brake engaged
			if ( math.abs( ReverserLever ) < 0.9 or TrackBrake > 0 ) then
				Call( "*:SetControlValue", "Regulator", 0, 0.0 )
				Call( "*:SetControlValue", "TrainBrakeControl", 0, 1.0 )
				Call( "*:SetControlValue", "DynamicBrake", 0, 1.0 )
				
				if ( TrackBrake > 0 ) then
					Call( "*:SetControlValue", "Sander", 0, 1 )
					Call( "*:SetControlValue", "HandBrake", 0, 1 )
					tAccel = math.min( tAccel, 0.0 )
				else
					Call( "*:SetControlValue", "Sander", 0, 0 )
					Call( "*:SetControlValue", "HandBrake", 0, 0 )
				end
				
				gSetReg = 0.0
				gSetDynamic = 0.0
				gSetBrake = 0.0
				tTAccel = -1.0
				gThrottleControl.value = -1.0
				
				if ( math.abs( ReverserLever ) < 0.9 ) then
					Call( "*:SetControlValue", "ThrottleAndBrake", 0, -1.0 )
				end
			else
				Call( "*:SetControlValue", "Sander", 0, 0 )
				Call( "*:SetControlValue", "HandBrake", 0, 0 )
				
				if ( DoorsOpen == TRUE ) then
					gSetReg = 0.0
					gSetDynamic = 0.0
					gSetBrake = 0.95
					tTAccel = -1.0
					gThrottleControl.value = -1.0
					brkAdjust = MAX_CORRECTION
				else
					if ( math.abs( tAccel ) < 0.01 ) then
						gSetReg = 0.0
						gSetDynamic = 0.0
						gSetBrake = 0.0
					else
						gSetReg = clamp( tAccel, 0.0, 1.0 )
						gSetBrake = clamp( -tAccel, 0.0, 1.0 )
					end
				end
				
				gThrottleControl:update( gTimeDelta )
				
				if ( tTAccel > 0.0 and ( BrakeCylBAR > 0.001 and not gRollback ) ) then
					tTAccel = 0.0
					
					if ( AbsSpeed < 0.1 ) then
						gTakeoffTime = 0.5
					end
				end
				
				if ( gTakeoffTime > 0.0 ) then
					gThrottleControl.value = 0.0
					gTakeoffTime = math.max( gTakeoffTime - gTimeDelta, 0.0 )
				end
				
				gThrottleControl:set( tTAccel )
				
				gSetReg			= clamp(  gThrottleControl.value, 0.0, 1.0 )
				gSetBrake		= clamp( -gThrottleControl.value, 0.0, 1.0 )
				
				speedSign = sign( TrainSpeed )
				speed2Sign = sign( GetControlValue( "Speed2" ) ) * ReverserLever
				
				if ( speedSign ~= speed2Sign ) then
					if ( AbsSpeed > 1.0 or gRollback ) then
						gRollback = true
						gSetBrake = 1.0 -- Prevent rollback
					end
				else
					if ( AbsSpeed > 0.1 ) then
						gRollback = false
					end
				end
				
				Call( "*:SetControlValue", "TAccel", 0, tAccel)
				Call( "*:SetControlValue", "Regulator", 0, gSetReg)
				Call( "*:SetControlValue", "DynamicBrake", 0, gSetBrake )
				Call( "*:SetControlValue", "TrainBrakeControl", 0, gSetBrake )
				Call( "*:SetControlValue", "TrueThrottle", 0, gThrottleControl.value )
			end

			-- End propulsion system
			
			-- Begin ATC system
			
			if UpdateATC then
				UpdateATC( gTimeDelta )
			end
			
			if UpdateATO then
				UpdateATO( gTimeDelta )
			end
			
			-- End ATC system
			
			-- Begin HUD
			
			if UpdateHUD then
				UpdateHUD( gTimeDelta )
			end
			
			-- End HUD

			if ( DoorsOpen ~= FALSE ) then
				Call( "*:SetControlValue", "Regulator", 0, 0 )
			end

			gLastDoorsOpen = DoorsOpen
			gLastSpeed = TrainSpeed
			gTimeDelta = 0
		end
	else -- trail engine.
	
	end
end
