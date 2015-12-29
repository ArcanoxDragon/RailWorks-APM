--include=..\..\..\..\Scripts\APM Util.lua

G_SPEED_WARNING_INTERVAL = 0.5 -- Seconds

gSetupHUD = false

function SetupHUD()
	
	-- Speed warning
	gSpeedWarning 		= false
	gSpeedWarningTimer 	= 0.0
	
	-- Doors
	
	gDoorsLeft 			= false
	gDoorsRight 		= false
	
	-- End
	
	gSetupHUD = true
	
end

function UpdateHUD(time)

	-- Setup
	if not gSetupHUD then
		SetupHUD()
	end
	
	-- Variables
	
	local SpeedLimit		 	= GetControlValue( "ATCRestrictedSpeed" 	)
	local TrainSpeed 			= GetControlValue( "SpeedometerMPH" 		)
	local DoorsLeft  			= GetControlValue( "DoorsOpenCloseLeft"  	) > 0.5
	local DoorsRight 			= GetControlValue( "DoorsOpenCloseRight" 	) > 0.5
	local DoorsOpen  			= GetControlValue( "DoorsOpen" 				) > 0.5
	
	-- Overspeed Warning
	
	if TrainSpeed >= SpeedLimit + 1.0 then
		gSpeedWarningTimer = gSpeedWarningTimer + time
		
		if gSpeedWarningTimer >= G_SPEED_WARNING_INTERVAL then
			gSpeedWarning = not gSpeedWarning
			gSpeedWarningTimer = 0.0
		end
		
		SetControlValue( "HUD_SpeedWarning", gSpeedWarning and 1 or 0 )
	else
		gSpeedWarning = false
		gSpeedWarningTimer = 0.0
		
		SetControlValue( "HUD_SpeedWarning", 0 )
	end
	
	-- Doors
		
	if DoorsLeft then
		gDoorsLeft  = true
	end
	
	if DoorsRight then
		gDoorsRight = true
	end
	
	if not DoorsOpen then
		gDoorsLeft  = false
		gDoorsRight = false
	end
	
	SetControlValue( "HUD_DoorsLeft" , gDoorsLeft  and 1 or 0 )
	SetControlValue( "HUD_DoorsRight", gDoorsRight and 1 or 0 )
	
	-- Speed Digits
	
	TrainSpeed = math.floor( TrainSpeed + 0.5 ) -- Round at 0.5, not 0.0 (for display)
	
	local Speed_10s = math.floor( mod( TrainSpeed / 10, 10 ) )
	local Speed_1s  = math.floor( mod( TrainSpeed     , 10 ) )
	local Limit_10s = math.floor( mod( SpeedLimit / 10, 10 ) )
	local Limit_1s  = math.floor( mod( SpeedLimit     , 10 ) )
	
	if Speed_10s == 0 then Speed_10s = -1 end -- Hide "0" from 10s place if value is less than 10
	if Limit_10s == 0 then Limit_10s = -1 end
	
	SetControlValue( "HUD_Speed_10", Speed_10s )
	SetControlValue( "HUD_Speed_1" , Speed_1s  )
	SetControlValue( "HUD_Limit_10", Limit_10s )
	SetControlValue( "HUD_Limit_1" , Limit_1s  )
	
end


















