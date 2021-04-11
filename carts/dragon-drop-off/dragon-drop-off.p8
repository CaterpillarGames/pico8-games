pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
--dragon drop-off                v0.1.0
--by caterpillar games 



gs = nil

isInBrowser = true;

dirs = {
	left = 0,
	right = 1,
	up = 2,
	down = 3,
	z = 4,
	x = 5
}

function _init()
	if isInBrowser then
		poke(0x5f2d, 0x1 + 0x4)
	else
		poke(0x5f2d, 0x1)
	end
	gs = {
		isGameOver = false,
		gameOverResult = nil,
		startTime = t(),
		treeX = 0,
		cloudX = 0,
		getTimeSoFar = function(self)
			return t() - self.startTime
		end,
		getTimeLeft = function(self)
			return 60.5 - self:getTimeSoFar()
			-- return 10 - self:getTimeSoFar()
		end,
		endTime = nil,
		currentAnimation = nil,
		spawnCountDown = 5,
		-- dragonSpawnRate = 1,	-- chance per 1000 per frame to spawn a dragon
		getSpawnRate = function(self)
			-- so will be between 2 and 5
			return self:getTimeSoFar() / 20 + 2
		end,
		dt = 1/30.0,
		plane = {
			pos = vec2(64, 64),
			health = 100,
			animationCounter = 0		-- tODO
		},
		player = {
			springK = 5,
			-- Used when in browser
			x = 64,
			y = 64,

			getPos = function(self)
				if isInBrowser then
					return vec2(
						self.x,
						self.y
						)
				else
					return vec2(
						stat(32),
						stat(33)
						)
				end
			end,
			-- pos = vec2(20, 20),
			isGrasp = false
		},
		dragons = {

		}
	}

	-- add(gs.dragons, spawnDragon())
end

function checkSpawn()
	gs.spawnCountDown -= 1
	if gs.spawnCountDown <= 0 then
		add(gs.dragons, spawnDragon())
		gs.spawnCountDown = 120 / gs:getSpawnRate()
	end
	-- if rnd(100) < gs.dragonSpawnRate then
	-- end

end

function spawnDragon()

	local posY = rnd(120)
	local posX = -20
	if rnd() < 0.5 then
		posX = 20 + 128
	end

	return {
		pos = vec2(posX, posY),
		vel = vec2(0, 0),
		animationCycle = 1,
		animationLength = 3,
		animationSpeed = 10,
		animationCurrent = 0,
		damage = 2,
		attackCooldown = 10,
		attackCountdown = 10,
		spriteStart = 64,
		width = 3,
		flySpeed = 40,
		isGrasped = false,
		canBeDisposed = false,
		canAttack = function(self)
			return self.pos:isWithin(gs.plane.pos, 21) and self.attackCountdown <= 0
		end,
		isGraspable = function(self)
			-- return self.pos:isWithin(gs.player:getPos(), 10)
			return self.pos:squareDist(gs.player:getPos()) < 13
		end
	}
end


metaTable = {
	__add = function(v1, v2)
		return vec2(v1.x + v2.x, v1.y + v2.y)
	end,
	__sub = function(v1, v2)
		return vec2(v1.x - v2.x, v1.y - v2.y)
	end,
	__mul = function(s, v)
		if type(s) == 'table' then
			s,v = v,s
		end

		return vec2(s * v.x, s * v.y)
	end
}

function vec2fromAngle(ang)
	return vec2(cos(ang), sin(ang))
end

function vec2(x, y)
	local ret = {
		x = x,
		y = y,
		norm = function(self)
			return vec2fromAngle(atan2(self.x, self.y))
		end,
		squareDist = function(self, other)
			return max(abs(self.x - other.x), abs(self.y - other.y))
		end,
		taxiDist = function(self, other)
			return abs(self.x - other.x) + abs(self.y - other.y)
		end,
		-- Beware of using this on vectors that are more than 128 away
		eucDist = function(self, other)
			local dx = self.x - other.x
			local dy = self.y - other.y
			-- return sqrt(dx * dx + dy * dy)
			return approx_magnitude(dx, dy)
		end,
		isWithin = function(self, other, value)
			return self:taxiDist(other) <= value and
				self:eucDist(other) <= value
		end,
		isOnScreen = function(self, extra)
			if extra == nil then extra = 0 end

			return extra <= self.x and self.x <= 128 - extra
				and extra <= self.y and self.y <= 128 - extra
		end,
		length = function(self)
			return self:eucDist(vec2(0, 0))
		end
	}

	setmetatable(ret, metaTable)

	return ret
end

-- https://www.lexaloffle.com/bbs/?tid=36059
function approx_magnitude(a,b)
 local a0,b0=abs(a),abs(b)
 return max(a0,b0)*0.9609+min(a0,b0)*0.3984
end


function hasAnimation()
	return gs.currentAnimation != nil and costatus(gs.currentAnimation) != 'dead'
end

function acceptInput()
	if stat(34) & 0x1 > 0 then
		if not gs.player.isGrasp then
			gs.player.isGrasp = true
			graspStart()
		end
	else
		if gs.player.isGrasp then
			gs.player.isGrasp = false
			graspEnd()
		end
	end
end


function graspStart()
	for drag in all(gs.dragons) do
		if drag:isGraspable() then
			drag.isGrasped = true
			drag.canBeDisposed = true
		end
	end
end

function graspEnd()
	for drag in all(gs.dragons) do
		drag.isGrasped = false
	end
end

function _update()
	if isInBrowser then
		gs.player.x += stat(38) / 3.5
		gs.player.y += stat(39) / 3.5
	end

	if gs.isGameOver then
		if gs.endTime == nil then
			gs.endTime = t()
		end
		if btnp(dirs.x) then
			_init()
		end
		return
	end

	if hasAnimation() then
		local active, exception = coresume(gs.currentAnimation)
		if exception then
			stop(trace(gs.currentAnimation, exception))
		end

		return
	end

	acceptInput()

	updateDragons()

	checkDamage()

	checkSpawn()

	checkTimeout()
end

function checkTimeout()
	if gs:getTimeLeft() < 0 then
		gs.isGameOver = true
		gs.gameOverResult = 'win'
	end
end

function damagePlane(attacker, amount)
	gs.plane.health -= amount
end

function checkDamage()
	for drag in all(gs.dragons) do
		if not drag.isGrasped then
			drag.attackCountdown -= 1
			if drag:canAttack() then
				drag.attackCountdown = drag.attackCooldown
				damagePlane(drag, drag.damage)
			end
		end
	end

	if gs.plane.health < 0 then
		gs.isGameOver = true
		gs.gameOverResult = 'lose'
	end
end

function updateDragons()
	for drag in all(gs.dragons) do
		drag.animationCurrent += 1

		if drag.isGrasped then
			local delta = gs.player:getPos() - drag.pos
			local acc = delta:norm() * gs.player.springK * delta:length()
			drag.vel += acc * gs.dt
			-- local vel = delta:norm() * 10 * sqrt(delta:squareDist(vec2(0,0)))
			-- drag.pos += vel * gs.dt
			-- drag.vel = vel
		else
			local vel = gs.plane.pos - drag.pos
			vel = vel:norm() * drag.flySpeed
			if drag.pos:isWithin(gs.plane.pos, 20) then
				vel = vec2(0, 0)
			end

			local deltaV = vel - drag.vel
			drag.vel += deltaV * gs.dt
			-- drag.vel = vel
		end

		drag.pos += drag.vel * gs.dt

		if drag.canBeDisposed and not drag.pos:isOnScreen(-20) then
			del(gs.dragons, drag)
		end
	end
end

function drawSingleDragon(drag)
	-- assert(false)
	-- local animationLengthFrames = 
	if drag.animationCurrent >= 
		(drag.animationSpeed * drag.animationLength) then
		drag.animationCurrent = 0
	end
	-- drag.animationCurrent 
	local spriteNumber = drag.spriteStart
		+ (flr(drag.animationCurrent / drag.animationSpeed)) * drag.width

	if (gs.player.isGrasp and drag.isGrasped) or
		(not gs.player.isGrasp and drag:isGraspable()) then
		pal(3, 5)
		-- pal(11, 3)
	end

	local flipX = false
	if drag.vel.x < 0 then
		flipX = true
	end

	spr(spriteNumber, 
			drag.pos.x - drag.width / 2 * 8, 
			drag.pos.y - drag.width / 2 * 8, 
			-- drag.pos.x,
			-- drag.pos.y,
			drag.width, drag.width, flipX)

	pal()
	-- spr(drag)
	-- 	return {
	-- 	pos = vec2(0, 20),
	-- 	animationCycle = 1,
	-- 	animationLength = 2,
	-- 	animationSpeed = 10,
	-- 	animationCurrent = 0,
	-- 	spriteStart = 64,
	-- 	width = 3,
	-- 	flySpeed = 20
	-- }
end

function drawDragons()
	for drag in all(gs.dragons) do
		drawSingleDragon(drag)
	end
end

function drawPlayer()
	local pos = gs.player:getPos()
	local spriteNumber = 1
	if gs.player.isGrasp then
		spriteNumber = 3
	end
	spr(spriteNumber, pos.x - 4, pos.y - 4, 2, 2)
end

function drawPlane()
	local animateOffset = cos(gs.plane.animationCounter / 47.2738) * 2
	spr(5, gs.plane.pos.x - 12, gs.plane.pos.y - 12 + animateOffset, 3, 3)
end

function drawHealthBar()
	local startX = 20
	local endX = 128 - startX
	
	local actualHealthEndX = (endX - startX) * gs.plane.health / 100 + startX

	local y = 110


	-- rect(startX, y, endX, y + 10, 2)
	rectfill(startX + 1, y + 1, actualHealthEndX - 1, y + 10 - 1, 2)
end

function drawGameOver()
	if gs.gameOverResult == 'lose' then
		print('\n the plane was destroyed!\n\n press \151 to play again', 7)
	else
		print('\n you protected the plane!\n\n press \151 to play again', 7)
	end
end

function incrementBackground()
	gs.cloudX -= 3 * gs.dt
	gs.treeX -= 40 * gs.dt
	if gs.cloudX < -7 * 8 then
		gs.cloudX = 0
	end
	if gs.treeX < -7 * 8 then
		gs.treeX = 0
	end

	gs.plane.animationCounter += 0.5
end

function drawBackground()
	for i = -2, 5 do
		spr(9, gs.treeX + i * 7 * 8, 100, 7, 4)
	end

	for i = -2, 2 do
		spr(128, gs.cloudX + i * 7 * 8, 12, 7, 2)
	end
end

function drawCountDown()
	local toDraw = flr(gs:getTimeLeft())
	-- local toDraw = gs:getSpawnRate()
	print(tostr(toDraw), 60, 4, 7)
end

function _draw()
	cls(1) -- todo 12
	if gs.isGameOver then
		drawGameOver()
		return
	end

	drawBackground()
	
	drawPlane()
	drawDragons()
	drawPlayer()

	drawHealthBar()

	drawCountDown()

	incrementBackground()
	-- print(#gs.dragons, 0, 0)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000001111111100000000330000000000000000000000000000003330000003000000
00000000000000000000000000000000000000000000000000000000000000001111111100000000330000000000003300303000000330003330000003330300
00700700006666600000000000000000000000000000000000000000000000001111111100000003303000000000000300303000000330003330000003333300
00077000006767666000000000000000000000000055000000000000000000001111111100000303003033000030000330333000030330003330000033303300
00077000666767676000000000666660000000000055500000000000000000001111111100000333003033000330000333333000033033003330000033303300
00700700676767676000000000676766600000000056550000000000000000001111111100003330033333000330033033333000033033333333000333303330
00000000676777776000000066676767600000000056650000000000000000001111111100003330033330303330033003333000033033333333000333333330
00000000677777776000000067676767600000000056650000000000000000001111111100030333033030303030033033333300303033330333003033333330
00000000677777776000000067777777600000000056655555555555555550001111111100033333033333333033333330333300303033300333303033303033
00000000667777766000000066777776600000000556666666666666666655001111111100033333303333030033303333333033303333303333330033303033
00000000066666660000000006666666000000000556666666666666666655001111111100330333333333030033303333333303303333303033330333333033
00000000000000000000000000000000000000000566666666666666666650001111111133003303333303030033333333030300330333003003330333330003
00000000000000000000000000000000000000000566666666666666655550001111111133333333333303330033030033303333030333000303333333330033
00000000000000000000000000000000000000000566665555555555550000001111111133333330333333300033330033300033333333000303330030333330
00000000000000000000000000000000000000000555550000000000000000001111111130333330303330330333030003300003333333033303330033033030
00000000000000000000000000000000000000000000000000000000000000001111111130300300303300033333030003330033303333033330033003330030
11111111000000000000000000000000000000000000000000000000000000001111111100000303330300033333003033030030303003033330303003330030
11111111000000000000000000000000000000000000000000000000000000001111111100000303330300033303303333303303333003033330303033330300
11111111000000000000000000000000000000000000000000000000000000001111111100003033303300033303033330333303330033033330300333333300
11111111000000000000000000000000000000000000000000000000000000001111111100003333003033333033003330333333330033303330333333303300
11111111000000000000000000000000000000000000000000000000000000001111111100003333003033330333003333333333330033303333300033303300
11111111000000000000000000000000000000000000000000000000000000001111111100003330033333330330333333333033333333333333000333303330
11111111000000000000000000000000000000000000000000000000000000001111111100003330033333303330033303333303333033333333000333333330
11111111000000000000000000000000000000000000000000000000000000001111111100033333033303303030033333330303303033030333003033333330
00000000000000000000000000000000000000001111111111111111111111110000000000033333033303333033333033333303303033300333303033303033
00000000000000000000000000000000000000001111111111111111111111110000000000033333303303030033303033333033303333003333330033303033
00000000000000000000000000000000000000001111111111111111111111110000000000330333333303030033300333333333303330003033330333333033
00000000000000000000000000000000000000001111111111111111111111110000000033003303303303030033000333033300300333003003330333330003
00000000000000000000000000000000000000001111111111111111111111110000000033333333333303330033000033003333000333000303333333330003
00000000000000000000000000000000000000001111111111111111111111110000000033333330033330000033000033000033003330000303330030030000
00000000000000000000000000000000000000001111111111111111111111110000000030333330003330000033000003000003003330000303330030030000
00000000000000000000000000000000000000001111111111111111111111110000000030300000003300000033000000000000003330000330003003330000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000077000000000000000000000000000000000000000000000
00000000003300000000000000000000000000000000000000000000000000000000000000000007777700000000000000000000000000000000000000000000
0000000bbbb330000000000000000000000000000000000000000000000000000000000000000077777770000077000000000000000000000000000000000000
0000033bbbbb30000000000000000000000000000000000000000000000000000000000000000077666677770777700070000000000000000000000000000000
000bbb33bbbb30000033000000000000000000000033000000000000000000000033000000000776677777770777707777000000000000000000000000000000
033bbbbb33bbb3000333000000000000000000000333000000000000000000000333000000000776777777777777777777600000000000000000000000000000
00333bbbb3bbb30033a33300000000000000000033a33300000000000000000033a3330000000776777777777777777777600000000000000007770777700000
000033bbbb3bb3003babb30000000000000bb3003babb30000000000000000003babb30000077777777777777777777777600000000000000007766777770000
0000033bbb3bb303bbbb330000000000bb3bb303bbbb33000000000000000003bbbb330000777777777777777777777777000000000000000007767776660000
0000003bbb3bb303bbbb33000000003bbb3bb303bbbb33000000000000000003bbbb330000777777777777777666777660000000000000000076777770000000
00000003b3333333bbb3300000000003b3333333bbb330000000000003333333bbb3300000767667777777770000777000000000000000000006667000000000
0000003333bbbbbbbb3300000000003333bbbbbbbb3300000000003333bb3bb3bb33000000066677077777700000000000000000000000000000000000000000
0033333bbbbbbbbbb33000000033333bbbbbbbbbb33000000033333bb3bb3bb33330000000000000000000000000000000000000000000000000000000000000
333bbbbbbbbbbbbb33030000333bbbbbbbbbbbbb33030000333bbbbbb3bb3bbb3303000000000000000000000000000000000000000000000000000000000000
0333333333bbbbb3330033000333333333bbbbb333003300033333333bbb3bbb3300330000000000000000000000000000000000000000000000000000000000
0000033303333333003003000000033303333333003003000000033bbbbb3bbb3030030000000000000000000000000000000000000000000000000011111111
00000003003000000003030000000003003000000003030000000033bbbb3bbb3003030000000000000000000000000000000000000000000000000011111111
0000000300300000000300000000000300300000000300000000000300bb3bbb3003000000000000000000000000000000000000000000000000000011111111
00000003003000000003000000000003003000000003000000000003003330000003000000550000000000000000000000550000000000000000000011111111
00000033033000000000000000000033033000000000000000000033033000000000000000555000000000000000000000555000000000000000000011111111
00000000000000000000000000000000000000000000000000000000000000000000000000565500000000000000000000565500000000000000000011111111
00000000000000000000000000000000000000000000000000000000000000000000000000566500000000000000000000566500000000000000000011111111
00000000000000000000000000000000000000000000000000000000000000000000000000566500000000000000000000566500000000000000000011111111
11111111111111111111111111111111111111111111111111111111111111111111111100566555555555555555500000566555555555555555500011111111
11111111111111111111111111111111111111111111111111111111111111111111111105566666666666666666550005566666666666666666550011111111
11111111111111111111111111111111111111111111111111111111111111111111111105566666666666666666550005566666666666666666550011111111
11111111111111111111111111111111111111111111111111111111111111111111111105666666666666666666500005666666666666666666500011111111
11111111111111111111111111111111111111111111111111111111111111111111111105666666666666666555500005666666666666666555500011111111
11111111111111111111111111111111111111111111111111111111111111111111111105666655555555555500000005666655555555555500000011111111
11111111111111111111111111111111111111111111111111111111111111111111111105555500000000000000000005555500000000000000000011111111
11111111111111111111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000011111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
00000000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
00000007777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
00000077777770000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
00000077666677770777700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
00000776677777770777707777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
00000776777777777777777777600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111
00000776777777777777777777600000000000000007770777700000000000000000000000000000000000000000000000000000000000000000000011111111
00077777777777777777777777600000000000000007766777770000000000000000000011111111111111111111111111111111111111111111111100000000
00777777777777777777777777000000000000000007767776660000000000000000000011111111111111111111111111111111111111111111111100000000
00777777777777777666777660000000000000000076777770000000000000000000000011111111111111111111111111111111111111111111111100000000
00767667777777770000777000000000000000000006667000000000000000000000000011111111111111111111111111111111111111111111111100000000
00066677077777700000000000000000000000000000000000000000000000000000000011111111111111111111111111111111111111111111111100000000
00000000000000000000000000000000000000000000000000000000000000000000000011111111111111111111111111111111111111111111111100000000
00000000000000000000000000000000000000000000000000000000000000000000000011111111111111111111111111111111111111111111111100000000
00000000000000000000000000000000000000000000000000000000000000000000000011111111111111111111111111111111111111111111111100000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00550000000000000000000000550000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00555000000000000000000000555000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00565500000000000000000000565500000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00566500000000000000000000566500000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00566500000000000000000000566500000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00566555555555555555500000566555555555555555500011111111000000000000000000000000000000000000000000000000000000000000000000000000
05566666666666666666550005566666666666666666550011111111000000000000000000000000000000000000000000000000000000000000000000000000
05566666666666666666550005566666666666666666550011111111000000000000000000000000000000000000000000000000000000000000000000000000
05666666666666666666500005666666666666666666500011111111000000000000000000000000000000000000000000000000000000000000000000000000
05666666666666666555500005666666666666666555500011111111000000000000000000000000000000000000000000000000000000000000000000000000
05666655555555555500000005666655555555555500000011111111000000000000000000000000000000000000000000000000000000000000000000000000
05555500000000000000000005555500000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111177717171111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111171117171111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111177717771111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111711171111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111177711171111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111117711111111111111111111111111111111111111111111111111111177111111111111111111111111
11111111111111111111111111111111111111111111777771111111111111111111111111111111111111111111111111117777711111111111111111111111
71111111111111111111111111111111111111111117777777111117711111111111111111111111111111111111111111177777771111177111111111111111
77111711111111111111111111111111111111111117766667777177771117111111111111111111111111111111111111177666677771777711171111111111
77177771111111111111111111111111111111111177667777777177771777711111111111111111111111111111111111776677777771777717777111111111
77777776111111111111111111111111111111111177677777777777777777761111111111111111111111111111111111776777777777777777777611111111
77777776111111111111111177717777111111111177677777777777777777761111111111111111777177771111111111776777777777777777777611111111
77777776111111111111111177667777711111117777777777777777777777761111111111111111776677777111111177777777777777777777777611111111
77777771111111111111111177677766611111177777777777777777777777711111111111111111776777666111111777777777777777777777777111111111
67776611111111111111111767777711111111177777777777777766677766111111111111111117677777111111111777777777777777666777661111111111
17771111111111111111111166671111111111176766777777777111177711111111111111111111666711111111111767667777777771111777111111111111
11111111111111111111111111111111111111116667717777771111111111111111111111111111111111111111111166677173377711111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133bbbb11111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113bbbbb33111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133111113bbbb33bbb1111111111111111
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113331113bbb33bbbbb3311111111111111
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111333a33113bbb3bbbb333111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113bbab3113bb3bbbb3311111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133bbbb313bb3bbb33111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133bbbb313bb3bbb31111111111111111111
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133bbb3333333b311111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133bbbbbbbb33331111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133bbbbbbbbbb33333111111111111111
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113133bbbbbbbbbbbbb3331111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113311333bbbbb33333333311111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131131133333331333111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131311111111311311111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111311111111311311111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111311111111311311111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111331331111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113311111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133bbbb11111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113bbbbb33111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111133111113bbbb33bbb1111111111111111111
111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111113331113bbb33bbbbb3311111111111111111
111111111111111111111111111111111111111111111111111111551111111111111111111111111111111111333a33113bbb3bbbb333111111111111111111
1111111111111111111111111111111111111111111111111111115551111111111111111111111111111111113bbab3113bb3bbbb3311111111111111111111
11111111111111111111111111111111111111111111111111111156551111111111111111111111111111111133bbbb313bb3bbb33111111111111111111111
11111111111111111111111111111111111111111111111111111156651111111111111111111111111111111133bbbb313bb3bbb31111111111111111111111
111111111111111111111111111111111111111111111111111111566511111111111111111111111111111111133bbb3333333b311111111111111111111111
1111111111111111331111111111111111111111111111111111115665555555555555555111111111666661111133bbbbbbbb33331111111111111111111111
1111111111111bbbb331111111111111111111111111111111111556666666666666666655111111116767666111133bbbbbbbbbb33333111111111111111111
1111111111133bbbbb311111111111111111111111111111111115566666666666666666551111116667676761113133bbbbbbbbbbbbb3331111111111111111
111111111bbb33bbbb3111113311111111111111111111111111156666666666666666665111111167676767613311333bbbbb33333333311111111111111111
111111133bbbbb33bbb3111333111111111111111111111111111566666666666666655551111111676777776131131133333331333111111111111111111111
11111111333bbbb3bbb31133a3331111111111111111111111111566665555555555551111111111677777776131311111111311311111111111111111111111
111111111133bbbb3bb3113babb31111111111111111111111111555551111111111111111111111677777776111311111111311311111111111111111111111
1111111111133bbb3bb313bbbb331111111111111111111111111111111111111111111111111111667777766111311111111311311111111111111111111111
1111111111113bbb3bb313bbbb331111111111111111111111111111111111111111111111111111166666661111111111111331331111111111111111111111
11111111111113b3333333bbb3311111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111113333bbbbbbbb33111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111133333bbbbbbbbbb331111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111333bbbbbbbbbbbbb3313111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111333333333bbbbb33311331111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111333133333331131131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111113113111111113131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111113113111111113111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111113113111111113111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111133133111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111333111111311111111111111331111111111111111111111111111113331111113111111111111113311111111111111111111111111111
31131311111133111333111111333131111111111331111111111113311313111111331113331111113331311111111113311111111111133113131111113311
31131311111133111333111111333331111111113313111111111111311313111111331113331111113333311111111133131111111111113113131111113311
33133311113133111333111113331331111111313113133111131111331333111131331113331111133313311111113131131331111311113313331111313311
33333311113313311333111113331331111111333113133111331111333333111133133113331111133313311111113331131331113311113333331111331331
13333311113313333333311133331333111113331133333111331133133333111133133333333111333313331111133311333331113311331333331111331333
11333311113313333333311133333333111113331133331313331133113333111133133333333111333333331111133311333313133311331133331111331333
13333331131313333133311313333333111131333133131313131133133333311313133331333113133333331111313331331313131311331333333113131333
33133331131313331133331313331313311133333133333333133333331333311313133311333313133313133111333331333333331333333313333113131333
33333313331333331333333113331313311133333313333131133313333333133313333313333331133313133111333333133331311333133333331333133333
33333331331333331313333133333313311331333333333131133313333333313313333313133331333333133113313333333331311333133333333133133333
33313131133133311311322222222222222222222222222222222222222222222222222222222222222222222222222222222222222233333331313113313331
13331333313133311131322222222222222222222222222222222222222222222222222222222222222222222222222222222222222231311333133331313331
13331113333333311131322222222222222222222222222222222222222222222222222222222222222222222222222222222222222233311333111333333331
11331111333333313331322222222222222222222222222222222222222222222222222222222222222222222222222222222222222231311133111133333331
11333113331333313333122222222222222222222222222222222222222222222222222222222222222222222222222222222222222231311133311333133331
13313113131311313333122222222222222222222222222222222222222222222222222222222222222222222222222222222222222231131331311313131131
33331331333311313333122222222222222222222222222222222222222222222222222222222222222222222222222222222222222233133333133133331131
33133331333113313333122222222222222222222222222222222222222222222222222222222222222222222222222222222222222231333313333133311331
33133333333113331333122222222222222222222222222222222222222222222222222222222222222222222222222222222222222231133313333333311333
33333333333113331333331113331331111113333113133331333113333333333331133313333311133313311111133331131333313331133333333333311333
33333313333333333333311133331333111113331133333331331333333333133333333333333111333313331111133311333333313313333333331333333333
31333331333313333333311133333333111113331133333313331133313333313333133333333111333333331111133311333333133311333133333133331333
33333131331313313133311313333333111133333133313313131133333331313313133131333113133333331111333331333133131311333333313133131331
13333331331313331133331313331313311133333133313333133333133333313313133311333313133313133111333331333133331333331333333133131333
13333313331333311333333113331313311133333313313131133313133333133313333113333331133313133111333333133131311333131333331333133331
33333333331333111313333133333313311331333333313131133311333333333313331113133331333333133113313333333131311333113333333333133311
33313331131133311311333133333111333113313313313131133111333133311311333113113331333331113331133133133131311331113331333113113331
