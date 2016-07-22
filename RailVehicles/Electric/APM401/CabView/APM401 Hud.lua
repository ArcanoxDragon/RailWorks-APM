--include=..\..\..\..\Scripts\APM Util.lua

G_BLINK_INTERVAL 		= 0.5	-- Seconds
G_FAST_BLINK_INTERVAL 	= 0.25	-- Seconds

gSetupHUD 			= false

function SetupHUD()
	
	-- Speed warning
	gSpeedWarning 		= false
	gSpeedWarningTimer 	= 0.0
	
	-- Doors
	gDoorsLeft 			= false
	gDoorsRight 		= false
	gDoorsBlink			= true
	gDoorsBlinkTimer	= 0.0
	
	-- Skip stop
	gSkipStopBlink		= true
	gSkipStopBlinkTimer	= 0.0
	
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
	local DoorsLeft  			= GetControlValue( "DoorsLeftGlobal"  		) > 0.5
	local DoorsRight 			= GetControlValue( "DoorsRightGlobal" 		) > 0.5
	local DoorsOpen  			= GetControlValue( "DoorsOpen" 				) > 0.5
	local DoorsClosing			= GetControlValue( "DoorsClosing" 			) > 0.5
	local SkipStop				= GetControlValue( "SkipStop"				) > 0.5
	local SkippingStop			= GetControlValue( "SkippingStop"			) > 0.5
	
	-- Overspeed Warning
	
	if TrainSpeed >= SpeedLimit + 1.0 then
		gSpeedWarningTimer = gSpeedWarningTimer + time
		
		if gSpeedWarningTimer >= G_BLINK_INTERVAL then
			gSpeedWarning = not gSpeedWarning
			gSpeedWarningTimer = 0.0
		end
		
		SetControlValue( "HUD_SpeedWarning", gSpeedWarning and 1 or 0 )
	else
		gSpeedWarning = false
		gSpeedWarningTimer = 0.0
		
		SetControlValue( "HUD_SpeedWarning", 0 )
	end
	
	-- Skip stop
	
	if ( SkipStop ) then
		gSkipStopBlinkTimer = gSkipStopBlinkTimer + time
		
		if ( gSkipStopBlinkTimer >= G_FAST_BLINK_INTERVAL ) then
			gSkipStopBlink		= not gSkipStopBlink
			gSkipStopBlinkTimer	= 0.0
		end
		
		SetControlValue( "HUD_SkipStop", ( SkippingStop and gSkipStopBlink ) and 0 or 1 )
	else
		gSkipStopBlink		= false
		gSkipStopBlinkTimer	= 0.0
		
		SetControlValue( "HUD_SkipStop", 0 )
	end
	
	-- Doors
		
	if DoorsLeft then
		gDoorsLeft  = true
		gDoorsRight = false
	end
	
	if DoorsRight then
		gDoorsRight = true
		gDoorsLeft  = false
	end
	
	if not DoorsOpen then
		gDoorsLeft  = false
		gDoorsRight = false
	end
	
	if DoorsClosing then
		gDoorsBlinkTimer = gDoorsBlinkTimer + time
	
		if ( gDoorsBlinkTimer >= G_BLINK_INTERVAL ) then
			gDoorsBlink = not gDoorsBlink
			gDoorsBlinkTimer = 0.0
		end
	else
		gDoorsBlink = true
	end
	
	SetControlValue( "HUD_DoorsLeft" , ( gDoorsLeft  and gDoorsBlink ) and 1 or 0 )
	SetControlValue( "HUD_DoorsRight", ( gDoorsRight and gDoorsBlink ) and 1 or 0 )
	
	-- Speed Digits
	
	TrainSpeed = math.floor( TrainSpeed + 0.5 ) -- Round at 0.5, not 0.0 (for display)
	
	local Speed_10s = math.min( math.floor( mod( TrainSpeed / 10, 10 ) ), 9 )
	local Speed_1s  = math.min( math.floor( mod( TrainSpeed     , 10 ) ), 9 )
	local Limit_10s = math.min( math.floor( mod( SpeedLimit / 10, 10 ) ), 9 )
	local Limit_1s  = math.min( math.floor( mod( SpeedLimit     , 10 ) ), 9 )
	
	if Speed_10s == 0 then Speed_10s = -1 end -- Hide "0" from 10s place if value is less than 10
	if Limit_10s == 0 then Limit_10s = -1 end
	
	SetControlValue( "HUD_Speed_10", Speed_10s )
	SetControlValue( "HUD_Speed_1" , Speed_1s  )
	SetControlValue( "HUD_Limit_10", Limit_10s )
	SetControlValue( "HUD_Limit_1" , Limit_1s  )
	
end


















