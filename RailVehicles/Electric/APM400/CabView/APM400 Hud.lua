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
	
	-- Overspeed Warning
	
	local ATCRestrictedSpeed = GetControlValue( "ATCRestrictedSpeed" )
	local TrainSpeed = GetControlValue( "SpeedometerMPH" )
	
	if TrainSpeed >= ATCRestrictedSpeed + 1.0 then
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
	
	local DoorsLeft  = GetControlValue( "DoorsOpenCloseLeft"  ) > 0.5
	local DoorsRight = GetControlValue( "DoorsOpenCloseRight" ) > 0.5
	local DoorsOpen  = GetControlValue( "DoorsOpen" ) > 0.5
	
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
	
end


















