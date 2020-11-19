pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- swimsaver
-- caterpillar games

gs = nil

deathChannel = 1

function isTooClose(x, y)
	local minDist = 15
	for swimmer in all(gs.swimmers) do
		if dist(swimmer, {x = x, y = y}) < minDist then
			return true
		end
	end
	return false
end

function getDrownParameters()
	local isLastMan = #gs.swimmers == 1
	local difficulty = gs.duration / 10			-- every 10 seconds bump up difficulty
	local drownV = 0.1 + (difficulty / 10)

	return {
		maxDrowning = flr(difficulty) + 1,
		-- every 8 seconds at level 1
		drownCooldown = 30 / (flr(difficulty) + 5),
		drownV = drownV	
	}
end

function _init()
	gs = {
		isGameOver = false,
		angelSpeed = 40,
		swimmers = {},
		drowned = {},
		savers = {},
		gravity = -10,
		dt = 1/30,
		lastDeathTime = -100,
		-- maxDrowning = 1,
		player = {
			x = 64,
			y = 100,
			angle = 0.25,
			omega = 0.5,
			isHoldingX = false,
			power = 0,
			powerV = 100,
			maxPower = 100
		},
		duration = 0,
		swimmersSaved = 0
		-- startTime = t(),
		-- lastDrownStart = 0
		-- cooldown
	}

	local targetNum = 20

	drownParm = getDrownParameters()

	while #gs.swimmers < targetNum do
		local r = 20 + rnd(70)
		local minAngle = 0.12
		local angle = minAngle + rnd(0.5 - minAngle*2)
		local x = gs.player.x + r * cos(angle)
		local y = gs.player.y + r * sin(angle)

		if not isTooClose(x, y) then
			add(gs.swimmers, makeSwimmer(x, y, drownParm.drownV, false))
		end
	end

	-- for i = 1, 1 do
	-- 	local r = 20 + rnd(70)
	-- 	local minAngle = 0.1
	-- 	local angle = minAngle + rnd(0.5 - minAngle*2)
	-- 	local x = gs.player.x + r * cos(angle)
	-- 	local y = gs.player.y + r * sin(angle)
	-- 	add(gs.swimmers, makeSwimmer(x, y, 0.1, true))
	-- end
end

function updateSavers()
	for saver in all(gs.savers) do
		saver.x += saver.vx * gs.dt
		saver.y += saver.vy * gs.dt
		saver.z += saver.vz * gs.dt

		saver.vz += gs.gravity * gs.dt

	end
end

function checkDeadSavers()
	local newSavers = {}
	for saver in all(gs.savers) do
		if saver.z > 0 then
			add(newSavers, saver)
		else
			spr(2, saver.x, saver.y)
			-- todo make a splash
		end
	end

	gs.savers = newSavers
end

dirs = {
	left = 0,
	right = 1,
	z = 4,
	x = 5
}

function acceptInput()
	if btn(dirs.left) then
		gs.player.angle += gs.player.omega * gs.dt
	end
	if btn(dirs.right) then
		gs.player.angle -= gs.player.omega * gs.dt
	end
	if btn(dirs.z) then
		gs.player.isHoldingX = true
		gs.player.power = min(gs.player.maxPower, gs.player.power + gs.player.powerV * gs.dt)
	else
		if gs.player.isHoldingX then
			gs.player.isHoldingX = false
			gs.savers[#gs.savers + 1] = 
				makeSaver(gs.player.x, gs.player.y, gs.player.angle, 0, gs.player.power)
		end
		gs.player.power = 0
	end
end

-- function getDuration()
-- 	return t() - gs.startTime
-- end
function countDrowning()
	local ret = 0
	for swimmer in all(gs.swimmers) do
		if swimmer.isDrowning then
			ret += 1
		end
	end
	return ret
end



function getNonDrowning()
	local ret = {}
	for swimmer in all(gs.swimmers) do
		if not swimmer.isDrowning then
			ret[#ret + 1] = swimmer
		end
	end
	return ret
end

function updateSwimmers()	

	local drownParam = getDrownParameters()
	local curDrowning = countDrowning()

	for swimmer in all(gs.swimmers) do
		if swimmer.isDrowning then
			swimmer.drownstate += swimmer.drownV * gs.dt
		end
	end

	if curDrowning < drownParam.maxDrowning then
		local victims = getNonDrowning()
		if #victims > 0 then
			local ind = flr(rnd(#victims)) + 1
			victims[ind].isDrowning = true
			victims[ind].drownV = drownParam.drownV
		end
	end

end

function checkDeadSwimmers()
	local newSwimmers = {}
	for swimmer in all(gs.swimmers) do
		if swimmer.drownstate < #drownstateColors + 1 then
			add(newSwimmers, swimmer)
		else
			-- TODO draw death animation
			add(gs.drowned, swimmer)
			if gs.duration - gs.lastDeathTime > 2.5 then
				music(0, 0, deathChannel)
				gs.lastDeathTime = gs.duration
			end
			-- end
		end
	end
	gs.swimmers = newSwimmers
end

function checkAngels()
	local newDrowned = {}
	for drowned in all(gs.drowned) do
		if drowned.y > -20 then
			add(newDrowned, drowned)
		end
	end

	return newDrowned
end

function updateAngels()
	for angel in all(gs.drowned) do
		angel.y -= gs.angelSpeed * gs.dt
	end
end

function gameOverUpdate()
	if btnp(dirs.x) then
		_init()
	end
end

function _update()

	if gs.isGameOver then
		gameOverUpdate()
		return
	end

	gs.duration += gs.dt


	acceptInput()

	updateSwimmers()

	updateAngels()

	updateSavers()

	checkCollisions()

	checkDeadSavers()

	checkDeadSwimmers()

	checkAngels()

	checkGameOver()
end

function checkGameOver()
	if #gs.swimmers == 0 then
		gs.isGameOver = true
	end
end

swimmerZ = 0.5

function dist(entity1, entity2)
	return abs(entity1.x - entity2.x) + abs(entity1.y - entity2.y)
end

function isCollide(swimmer, saver)
	-- local dist = abs(swimmer.x - saver.x) + abs(swimmer.y - saver.y)

	-- print(dist)
	-- return dist < 12
	local thisDist = dist(swimmer, saver)
	return thisDist < 16
end

function saveSwimmer(swimmer)
	swimmer.isDrowning = false
	swimmer.drownstate = 1
	gs.swimmersSaved += 1
end

function checkCollisions()
	for saver in all(gs.savers) do
		if saver.z < swimmerZ then
			for swimmer in all(gs.swimmers) do
				if swimmer.isDrowning and isCollide(saver, swimmer) then
					saveSwimmer(swimmer)
				end
			end
		end
	end
end

function drawBackground()
	rectfill(0, 0, 128, 128, 1)
end

function makeSwimmer(x, y, drownV, isDrowning)
	return {
		x = x,
		y = y,
		drownstate = 1,
		drownV = drownV,
		isDrowning = isDrowning,
		lastStartedDrowning = nil
	}
end

drownstateColors = {
	3,
	10,
	9,
	8
}

function drawAngels()
	for angel in all(gs.drowned) do
		pal(6, 7)
		local spriteNum = 33
		if flr(gs.duration * 3) % 2 == 0 then
			spriteNum = 35
		end
		spr(spriteNum, angel.x - 8, angel.y - 4, 2, 2)
	end
end

function drawSwimmers()
	for swimmer in all(gs.swimmers) do
		if swimmer.isDrowning then
			pal(6, drownstateColors[flr(swimmer.drownstate)])
		else
			pal(6, 11)
		end

		spr(1, swimmer.x - 8, swimmer.y - 4, 2, 2)
	end
	pal()
end

saverChannel = 2

-- power indicates initial velocity
function makeSaver(x, y, angleXY, angleZenith, power)
	sfx(1, saverChannel)
	-- TODO angleZenith
	return {
		x = x,
		y = y,
		z = 10,
		vx = power * cos(angleXY),
		vy = power * sin(angleXY),
		vz = 0,
		radius = 8,
		radiusInner = 4
	}
end

function drawSavers()
	for saver in all(gs.savers) do
		local mul = (saver.z + 10) / 10

		color(7)
		for i = mul*saver.radiusInner, mul*saver.radius, 0.1 do
			-- print(i)
			for xoff = 0, 1 do
				for yoff = 0, 1 do
					oval(saver.x - i + xoff, saver.y - i + yoff, saver.x + i + xoff, saver.y + i + yoff, 7)
				end
			end
		end
		-- assert(false)

		-- ovalfill(
		-- 	saver.x - mul*saver.radius, 
		-- 	saver.y - mul*saver.radius,
		-- 	saver.x + mul*saver.radius, 
		-- 	saver.y + mul*saver.radius,
		-- 	7)

		-- ovalfill(
		-- 	saver.x - mul*saver.radiusInner, 
		-- 	saver.y - mul*saver.radiusInner,
		-- 	saver.x + mul*saver.radiusInner, 
		-- 	saver.y + mul*saver.radiusInner,
		-- 	1)

		-- pset(saver.x, saver.y, 7)
	end
end


function drawArrow()
	color(12)
	local x = gs.player.x
	local y = gs.player.y --+ 12		-- draw arrow a little further back from actual player
	local length = 10 + gs.player.power / 5

	local endX = x + length * cos(gs.player.angle)
	local endY = y + length * sin(gs.player.angle)

	line(x, y, endX, endY)

	local arrowTipAngle = 0.1
	local tipLength = length / 2.5

	x = endX + tipLength * cos(gs.player.angle - 0.5 - arrowTipAngle)
	y = endY + tipLength * sin(gs.player.angle - 0.5 - arrowTipAngle)
	line(x, y, endX, endY)

	x = endX + tipLength * cos(gs.player.angle - 0.5 + arrowTipAngle)
	y = endY + tipLength * sin(gs.player.angle - 0.5 + arrowTipAngle)
	line(x, y, endX, endY)
end

function drawScore()
	print('lives saved: ' .. gs.swimmersSaved, 5, 110)
end

function drawGameOver()
	color(7)
	print('game over')
	print('lives saved: ' .. gs.swimmersSaved)
	print('time survived: ' .. flr(gs.duration) .. ' seconds')
	print('')
	print('press ❎ to play again')
end

function _draw()
	cls()
	if gs.isGameOver then
		drawGameOver()
		return
	end

	drawBackground()
	drawSwimmers()

	drawAngels()
	-- color(0)
	-- print(gs.player.power)
	drawSavers()

	drawArrow()

	drawScore()
end

__gfx__
00000000000000066000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000006666000000000000000c70070c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070000000066660000000000000000c000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000066000000000000000000c0c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000000066666600000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070000006066660600000000000000c000cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060666606000000000000000ccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060666606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000066000000000000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000600600000000000060060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000066000000000000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000066000000000000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066600666600666000000066660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000660666606600000060066660060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060066006000000606006600606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000006666660000006000666666000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060666606000000006066660600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060666606000000006066660600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060666606000000006066660600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000666600000000000066660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000600600000000000060060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000600600000000000060060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000600600000000000060060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
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
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111bb1111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111bbbb111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111bbbb111111111111111111111111111111111111111
1111111111111111111111111111111111111111bb11111111111111111111111111111111111111111111bb1111111111111111111111111111111111111111
111111111111111111111111881111111111111bbbb11111111111111111111111111111111111111111bbbbbb11111111111111111111111111111111111111
111111111111111111111118888111111111111bbbb1111111111111111111111111111111111111111b1bbbb1b1111111111111111111111111111111111111
1111111111111111111111188881111111111111bb11111111111111111111111111111111111111111b1bbbb1b1111111111111111111111111111111111111
11111111111111111111111188111111111111bbbbbb111111111111111111111111111111111111111b1bbbb1b1111111111111111111111111111111111111
1111111111111111111111888888111111111b1bbbb1b11111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111118188881811111111b1bbbb1b11111111111111111111111111881111111111111111111111111111111111111111111111111111111
1111177111111111111118188881811111111b1bbbb1b11111111111111111111111118888111111111111111111111111111111111111111111111111111111
11117117111111199111181888818111bb1111111111111111111111111111111111118888111111111111111111111111111111111111111111111111111111
1111177111111199991111111111111bbbb111111111111111111111111111111111111881111111111111111111111111111111111111111111111111111111
1111111111111199991111111111111bbbb111111111111111111111111111111111188888811111111111111111111111111111111111111111111111111111
11111771111111199111111111111111bb1111111111111111111111111111111111818888181111111111111111111111111111111111111111111111111111
111177771111199999911111111111bbbbbb11111111111111111111111111111111818888181111111111111111111111111111111111111111111111111111
17117777117191999919111111111b1bbbb1b1111111111111111111111111111111818888181111111111111111111111111111111111111111111111111111
71711771171791999919111111111b1bbbb1b111111111111111111111111111bb11111111111111111111111111111111111111111111111111111111111111
11177777711171999919111111111b1bbbb1b11111111111111111111111111bbbb1111111111111111111111111111111111111111111111111111111111111
117177771711111111111111111111111111111111111111111111111111111bbbb1111111111111111111111111111111111111111111111111111111111111
1171777717111111111111111111111111111111111111111111111111111111bb11111111111111111111111111111111111111111111111111111111111111
11717777171111111111111111111111111111111111111111111111111111bbbbbb111111111111111111111111111111111111111111111111111111111111
1111777711111111111111111111111111111111111111111111111111111b1bbbb1b1111111111111bb11111111111111111111111111111111111111111111
1111711711111111111111111111111111111111111111111111111111111b1bbbb1b111111111111bbbb1111111111111111111111111111111111111111111
1111711711111111111111111111111111111111111111111111111111111b1bbbb1b111111111111bbbb1111111111111111111111111111111111111111111
1111711711111111111111111111111111111111111111111111111111111111111111111111111111bb11111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111bbbbbb111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111b1bbbb1b11111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111b1bbbb1b11111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111b1bbbb1b11111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111177777777711111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111177777777777777711111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111777777777777777771111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111117777777777777777777111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111177777777777777777777711111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111777777777777777777777771111119911111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111117777777777777777777777777111199991111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111177777777777777777777777777711199991111111111111111111111111111
1111111111111bb11111111111111111111111111111111111111111111111111177777777777777777777777777711119911111111111111111111111111111
111111111111bbbb1111111111111111111111991111111111111111111111111177777777777b11177777777777711999999111111111111111111111111111
111111111111bbbb111111111111111111111999911111111111111111111111177777777777bb11111777777777779199991911111111111111111111111111
1111111111111bb111111111111111111111199991111111111111111111111117777777777bb111111177777777779199991911111111111111111111111111
11111111111bbbbbb1111111111111111111119911111111111111111111111117777777777bbbb1111177777777779199991911111111111111111111111111
1111111111b1bbbb1b11111111111111111199999911111111111111111111111777777777bbbb1b111117777777771111111111111111111111111111111111
1111111111b1bbbb1b11111111111111111919999191111111111111111111111777777777bbbb1b111117777777771111111111111111111111111111111111
1111111111b1bbbb1b11111111111111111919999191111111111111111111111777777777bbbb1b111117777777771111111111111111111111111111111111
11111111111111111111111111111111111919999191111111111111111111111777777777111111111117777777771111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111bb1777777777711111111177777777771111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111bbbb777777777711111111177777777771111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111bbbb177777777771111111777777777713111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111bb1177777777777111177777777777713111111111111111111111111111111111
11111111111111111111111111111111aa11111111111111111111111111bbbbbb77777777777777777777777777713111111111111111111111111111111111
1111111111111111111111111111111aaaa111111111111111111111111b1bbbb1b7777777777777777777777777111111111111111111111111111111111111
1111111111111111111111111111111aaaa111111111111111111111111b1bbbb1b1777777777777777777777771111111111111111111111111111111111111
11111111111111111111111111111111aa1111111111111111111111111b1bbbb1b1177777777777777777777711111111111111111111111111111111111111
111111111111111111111111111111aaaaaa11111111111111111111111111111111117777777777777777777111111111111111111111111111111111111111
11111111111111111111111111111a1aaaa1a1111111111111111111111111111111111777777777777777771111111111111111111111111111111111111111
11111111111111111111111111111a1aaaa1a1111111111111111111111111111111111177777777777777711111111111111111111111111111111111111111
11111111111111111111111111111a1aaaa1a1111111111111111111bb1111111111111111177777777711111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111bbbb111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111bbbb111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111bb1111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111111111bbbbbb11111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111b1bbbb1b1111111111bb1111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111b1bbbb1b111111111bbbb111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111b1bbbb1b111111111bbbb111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111bb1111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111133111111111111111111bbbbbb11111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111133331111111111111111b1bbbb1b1111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111133331111111111111111b1bbbb1b1111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111113311111111117777777777bbb1b1111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111333333111117777777777777771111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111113133331311777777777777777777711111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111113133331317777777777777777777777111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111113133331377777777777777777777777711111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111777777777777777777777777771111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111117777777777777777777777777777111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111177777777777777777777777777777711111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111177777777777777777777777777777711111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111777777777777777777777777777777771111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111177777777777777111c777777777777771111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111777777777777111ccc117777777777771111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111177777777777711cc1c1c11777777777777111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111177777777777111111c1c11177777777777111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111177777777777111111c1c11177777777777111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111177777777771111111c1111117777777777111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111117777777777111111c11111117777777777111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111117777777777111111c11111117777777777111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111117777777777111111c11111117777777777111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111777777777771111c111111177777777777111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111777777777771111c111111177777777777111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111777777777771111111111777777777771111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111777777777777111111117777777777771111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111777777777777771111777777777777771111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111177777777777777777777777777777711111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111177777777777777777777777777777711111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111117777777777777777777777777777111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111777777777777777777777777771111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111777777777777777777777777771111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111177777777777777777777777711111111111111111111111111111111111111111111111111
11111c111ccc1c1c1ccc11cc111111cc1ccc1c1c1ccc1cc1111111117c7c77777777777777771111111111111111111111111111111111111111111111111111
11111c1111c11c1c1c111c1111111c111c1c1c1c1c111c1c11c111111c7c77777777777777711111111111111111111111111111111111111111111111111111
11111c1111c11c1c1cc11ccc11111ccc1ccc1c1c1cc11c1c111111111ccc77777777777771111111111111111111111111111111111111111111111111111111
11111c1111c11ccc1c11111c1111111c1c1c1ccc1c111c1c11c11111111c11777777771111111111111111111111111111111111111111111111111111111111
11111ccc1ccc11c11ccc1cc111111cc11c1c11c11ccc1ccc11111111111c11111111111111111111111111111111111111111111111111111111111111111111
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

__sfx__
010c000018430000000000018430000000000018430000001843000000124001b430104001a430134001a43018400184300040018430004001743000000184300000000000000000000000000000000000000000
000400001075011750127501275012750127500f7500c7500875005750057501e0001c0001b0001a0001900019000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001365012650126501265012650136501365013650136501365013650006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
__music__
00 00424344

