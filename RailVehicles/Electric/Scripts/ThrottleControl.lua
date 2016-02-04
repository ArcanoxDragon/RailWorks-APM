ThrottleControl = {}
ThrottleControl.__index = ThrottleControl

function ThrottleControl.create( jerkLimit, jerkDelta, jerkThreshold )
	local tc = {}
	setmetatable( tc, ThrottleControl )
	
	tc.maxJerkLimit		= jerkLimit
	tc.jerkDelta		= jerkDelta
	tc.jerkThreshold	= jerkThreshold
	tc.jerkLimit		= 0.0
	tc.target			= 0.0
	tc.value			= 0.0
	
	return tc
end

function ThrottleControl:update( interval )
	local delta = self.target - self.value
	
	local targetJerk = 0.0
	if ( delta > 0.01 ) then
		targetJerk =  self.maxJerkLimit
	elseif ( delta < -0.01 ) then
		targetJerk = -self.maxJerkLimit
	else
		self.value = self.target
	end
	
	local jerkDelta = self.jerkDelta * interval
	
	if ( self.jerkLimit < targetJerk - jerkDelta ) then
		self.jerkLimit = self.jerkLimit + jerkDelta
	elseif ( self.jerkLimit > targetJerk + jerkDelta ) then
		self.jerkLimit = self.jerkLimit - jerkDelta
	else
		self.jerkLimit = targetJerk
	end
	
	local jerkLimit = self.jerkLimit * clamp( math.abs( delta ) / self.jerkThreshold, 0.01, 1.0 ) * interval
	
	if ( math.abs( delta ) > jerkLimit ) then
		self.value = clamp( self.value + jerkLimit, -1.0, 1.0 )
	else
		self.value = self.target
	end
	
	SetControlValue( "DebugA", self.jerkLimit )
	SetControlValue( "DebugB", jerkLimit )
	SetControlValue( "DebugC", targetJerk )
end

function ThrottleControl:getProgress()
	return self.changeTime / self.maxTime
end

function ThrottleControl:set( target )
	self.target = target
end