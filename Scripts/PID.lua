PID = {}
PID.__index = PID

function PID:create( kP, kI, kD, minI, maxI, buffer, dThreshold, resetThreshold )
	local pid 			= {}
	
	pid.kP 			= kP
	pid.kI 			= kI
	pid.kD 			= kD
	pid.minI		= minI 				or -1.0
	pid.maxI		= maxI 				or  1.0
	pid.buffer		= buffer			or  0.0
	pid.dThreshold	= dThreshold		or  1.0
	pid.resetThresh	= resetThreshold	or  2.0
	
	pid.eSum		= 0.0
	pid.lastE		= 0.0
	pid.settled		= false
	pid.value		= 0.0
	pid.p			= 0.0
	pid.i			= 0.0
	pid.d			= 0.0
	
	setmetatable( pid, PID )
	return pid
end

function PID:update( target, actual, interval )
	local e		= math.min( target - actual, 0 ) - math.min( actual - ( target - self.buffer ), 0 )
	local iE	= math.min( target - actual, 0 ) - math.min( actual - ( target - ( self.buffer * 0.75 ) ), 0 )
	local d		= ( e - self.lastE ) / interval
	
	if ( math.abs( d ) < self.dThreshold ) then
		self.settled = true
	else
		self.settled = false
		
		if ( math.abs( d ) >= self.resetThresh ) then
			self.eSum = 0.0
		end
	end
	
	if ( self.settled ) then
		self.eSum = math.max( math.min( self.eSum + ( iE * interval ), self.maxI ), self.minI )
	end
	
	self.p = self.kP * e
	self.i = self.kI * self.eSum
	self.d = self.kD * d

	self.lastE = e
	self.value = self.p + self.i + self.d
end

function PID:reset()
	self.eSum		= 0.0
	self.lastE		= 0.0
	self.settled	= false
	self.setTime	= 0.0
end