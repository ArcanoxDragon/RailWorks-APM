--include=..\..\Scripts\ATC.lua
--include=..\..\Scripts\ATO.lua
--include=..\..\..\..\Scripts\APM Util.lua

------------------------------------------------------------
-- Simulation file for the APM 400
------------------------------------------------------------
--
-- (c) briman0094 2015
--
------------------------------------------------------------

function Setup()

-- For throttle/brake control.

	gLastDoorsOpen = 0
	gSetReg = 0
	gSetDynamic = 0
	gSetBrake = 0
	gLastSpeed = 0
	gTimeDelta = 0
	gCurrent = 0
	gLastReverser = 0
	
	tReg = 0
	tBrake = 0
	
	REG_DELTA = 0.7
	BRK_DELTA = 0.45
	
	MAX_ACCELERATION = 1.0
	MIN_ACCELERATION = 0.125
	MAX_BRAKING = 1.0
	MIN_BRAKING = 0.2
	JERK_LIMIT = 0.75
	MAX_SERVICE_BRAKE = 1.0
	MIN_SERVICE_BRAKE = 0.0
	
-- Propulsion system variables
	realAccel = 0.0
	tAccel = 0.0
	tTAccel = 0.0
	tThrottle = 0.0
	dDyn = 0.0
	dReg = 0.0
	dBrk = 0.0
	dAccel = 0.0
	MAX_BRAKE = 1.0
	gThrottleTime = 0.0
	gAvgAccel = 0.0
	gAvgAccelTime = 0.0
	gBrakeRelease = 0.0
	brkAdjust = 0.0
	gLastJerkLimit = 0

-- For controlling delayed doors interlocks.
	DOORDELAYTIME = 2.5 -- seconds.
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

function Update(interval)
	local rInterval = round(interval, 5)
	--gTimeDelta = gTimeDelta + rInterval
	gTimeDelta = interval

	if Call( "*:GetControlValue", "Active", 0 ) == 1 then -- This is lead engine.

		if Call( "IsExpertMode" ) == TRUE then -- Expert mode only.

			CombinedLever = Call( "*:GetControlValue", "ThrottleAndBrake", 0 )
			ReverserLever = Call( "*:GetControlValue", "Reverser", 0 )
			TrackBrake = Call( "*:GetControlValue", "TrackBrake", 0 )
			DoorsOpen = Call( "*:GetControlValue", "DoorsOpenCloseRight", 0 ) + Call( "*:GetControlValue", "DoorsOpenCloseLeft", 0 )
			PantoValue = Call( "*:GetControlValue", "PantographControl", 0 )
			ThirdRailValue = Call( "*:GetControlValue", "ThirdRail", 0 )
			TrainSpeed = Call( "*:GetControlValue", "SpeedometerMPH", 0 )
			BrakeCylBAR = Call( "*:GetControlValue", "TrainBrakeCylinderPressureBAR", 0 )
			IsEndCar = Call( "*:GetControlValue", "IsEndCar", 0 ) > 0
			ATOEnabled = (Call( "*:GetControlValue", "ATOEnabled", 0 ) or -1) > 0.5
			ATOThrottle = (Call( "*:GetControlValue", "ATOThrottle", 0 ) or -1)
			
			-- Headlights
			
			if (Call("*:GetControlValue", "Active", 0) > 0.5) then
				if (math.abs(ReverserLever) > 0.8) then
					Call("*:SetControlValue", "Headlights", 0, 1)
				elseif (math.abs(ReverserLever) < 0.2) then
					Call("*:SetControlValue", "Headlights", 0, 0)
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
			Call( "*:SetControlValue", "DoorsOpen", 0, math.min(DoorsOpen, 1) )
		
			-- Begin propulsion system
			realAccel = (TrainSpeed - gLastSpeed) / gTimeDelta
			gAvgAccel = gAvgAccel + (TrainSpeed - gLastSpeed)
			gAvgAccelTime = gAvgAccelTime + gTimeDelta
			-- Average out acceleration
			if (gAvgAccelTime >= 1/15) then
				Call( "*:SetControlValue", "Acceleration", 0, round(gAvgAccel / gAvgAccelTime, 2) )
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
			if (math.abs(tThrottle) < 0.1 and not ATOEnabled) then
				tThrottle = 0.0
			end
			
			if (ATOEnabled) then
				if (tThrottle >= 0.001) then -- Accelerating; bind range to [ MIN_ACCELERATION, MAX_ACCELERATION ]
					tTAccel = mapRange(tThrottle, 0.0, 1.0, 0.0, MAX_ACCELERATION)
				elseif (tThrottle <= -0.001) then -- Braking; bind range to [ MIN_BRAKING, MAX_BRAKING ]
					tTAccel = -mapRange(-tThrottle, 0.0, 1.0, 0.0, MAX_BRAKING)
				else
					tTAccel = 0.0
				end
			else
				if (tThrottle >= 0.1) then -- Accelerating; bind range to [ MIN_ACCELERATION, MAX_ACCELERATION ]
					tTAccel = mapRange(tThrottle, 0.1, 0.9, MIN_ACCELERATION, MAX_ACCELERATION)
				elseif (tThrottle <= -0.1) then -- Braking; bind range to [ MIN_BRAKING, MAX_BRAKING ]
					tTAccel = -mapRange(-tThrottle, 0.1, 0.9, MIN_BRAKING, MAX_BRAKING)
				else
					tTAccel = 0.0
				end
			end
			
			-- If requesting acceleration and stopped, release brakes instantly
			if (tTAccel >= 0 and math.abs(TrainSpeed) < 0.1) then
				tAccel = math.max(tAccel, 0.0)
			end
			
			tJerkLimit = JERK_LIMIT * gTimeDelta
			
			if (tAccel < tTAccel - tJerkLimit) then
				tAccel = tAccel + tJerkLimit
			elseif (tAccel > tTAccel + tJerkLimit) then
				tAccel = tAccel - tJerkLimit
			else
				tAccel = tTAccel
			end
			
			-- Parked or track brake engaged
			if (math.abs(ReverserLever) < 0.9 or TrackBrake > 0) then
				Call( "*:SetControlValue", "Regulator", 0, 0.0 )
				Call( "*:SetControlValue", "TrainBrakeControl", 0, 1.0 )
				
				if (TrackBrake > 0) then
					Call( "*:SetControlValue", "Sander", 0, 1 )
					Call( "*:SetControlValue", "HandBrake", 0, 1 )
					tAccel = math.min(tAccel, 0.0)
				else
					Call( "*:SetControlValue", "Sander", 0, 0 )
					Call( "*:SetControlValue", "HandBrake", 0, 0 )
				end
				gSetReg = 0.0
				gSetDynamic = 0.0
				gSetBrake = 0.0
				if (math.abs(ReverserLever) < 0.9) then
					Call( "*:SetControlValue", "ThrottleAndBrake", 0, -1.0 )
				end
			else
				Call( "*:SetControlValue", "Sander", 0, 0 )
				Call( "*:SetControlValue", "HandBrake", 0, 0 )
				
				if (math.abs(tAccel) > 0.05) then
					local tAccelSign = sign(tAccel)
					if (tAccelSign ~= gLastAccelSign) then
						gThrottleTime = 0.0
					end
					gLastAccelSign = tAccelSign
				end
				
				if (BrakeCylBAR > 0.005 and tAccel > 0) then
					gThrottleTime = 0.0
				end
				
				if (gThrottleTime < 0.125) then
					gThrottleTime = gThrottleTime + gTimeDelta
					tAccel = 0.01 * gLastAccelSign
					gLastJerkLimit = 0
				end
				
				if (DoorsOpen == TRUE) then
					gSetReg = 0.0
					gSetDynamic = 0.0
					gSetBrake = 0.95
					brkAdjust = MAX_CORRECTION
				else
					if (math.abs(tAccel) < 0.01) then
						gSetReg = 0.0
						gSetDynamic = 0.0
						gSetBrake = 0.0
					else
						gSetReg = clamp(tAccel, 0.0, 1.0)
						gSetBrake = clamp(-tAccel, 0.0, 1.0)
					end
				end
				
				local finalRegulator = gSetReg
				
				Call( "*:SetControlValue", "TAccel", 0, tAccel)
				Call( "*:SetControlValue", "Regulator", 0, finalRegulator)
				Call( "*:SetControlValue", "DynamicBrake", 0, 0.0 )
				Call( "*:SetControlValue", "TrainBrakeControl", 0, gSetBrake )
				Call( "*:SetControlValue", "TrueThrottle", 0, tThrottle )
			end

			-- End propulsion system
			
			-- Begin ATC system
			
			if UpdateATC then
				UpdateATC(gTimeDelta)
			end
			
			if UpdateATO then
				UpdateATO(gTimeDelta)
			end
			
			-- End ATC system

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
