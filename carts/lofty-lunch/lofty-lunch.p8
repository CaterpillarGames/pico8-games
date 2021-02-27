pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--lofty lunch                    v0.1.0
--by caterpillar games 



gs = nil

dirs = {
	left = 0,
	right = 1,
	up = 2,
	down = 3,
	z = 4,
	x = 5
}

function _init(isFreePlay)
	if isFreePlay then
		menuitem(1, 'free play off', function()
			_init()
		end)
	else
		menuitem(1, 'free play on', function()
			_init(true)
		end)
	end


	gs = {
		isGameOver = false,
		startTime = t(),
		dt = 1/30.0,
		endTime = nil,
		currentAnimation = nil,
		player = {
			horizSpeed = 50,
			x = 64,
			y = 110 - 20,	-- Debugging
			spriteNumber = 1
		},
		freeToppings = {},
		toppings = {
		},
		getHighestCap = function(self)
			if #self.toppings == 0 then
				return self.player
			end
			return self.toppings[#self.toppings]
		end,
		spawnCountDown = 0,
		spawnCoolDown =  30 * 1,
		cameraY = 0,
		targetY = 0,
		isFreePlay = isFreePlay
	}

	-- Start with bread already on your plate...
	captureTopping(cloneTemplate(templates[1], gs.player.x, 0, 0, 0), true)

	-- -- -- -- Debugging
	-- for i = 0, 20 do
	-- 	captureTopping(cloneTemplate(templates[1], gs.player.x, 0, 0, 0))
	-- end

end

function startGameOver()
	gs.currentAnimation = cocreate(function()
		-- for i=0, 100 do
		-- 	yield()
		-- end
		sfx(1)
		while gs.cameraY < 0 do
			gs.cameraY += 1
			yield()
		end

		for i=0, 30 do
			yield()
		end

		gs.isGameOver = true
	end)
end

function captureTopping(obj, suppressGameOver)
	local highest = gs:getHighestCap()
	obj.x = highest.x
	obj.y = highest.y - obj.height + 1
	obj.vx = 0
	del(gs.freeToppings, obj)
	add(gs.toppings, obj)

	if not suppressGameOver then
		sfx(0)
	end

	if not suppressGameOver and obj.name == 'bread' and not gs.isFreePlay then
		startGameOver()
	end
end

	-- local y = gs.player.y
	-- 	y -= top.height - 1
function spawnFallers()
	gs.spawnCountDown -= 1
	if gs.spawnCountDown > 0 then
		return
	end
	gs.spawnCountDown = gs.spawnCoolDown

	-- TODO allow more?
	if #gs.freeToppings < 9 then
		local template = choose(templates)
		-- Gotta make bread more common
		if rnd() < 0.1 then
			template = templates[1]
		end
		-- start off with vy = 30
		local initHeight = gs.cameraY - 40

		local topping = cloneTemplate(template, rnd(128 - 15), initHeight, 0, 30, rnd() > 0.5)
		add(gs.freeToppings, topping)
	end
end

function choose(tbl)
	return tbl[flr(rnd(#tbl)) + 1]
end

function cloneTemplate(template, x, y, vx, vy, flipX)
	return {
		name = template.name,
		height = template.height,
		spriteNumber = template.spriteNumber,
		x = x,
		y = y,
		vx = vx,
		vy = vy,
		flipX = flipX
	}
end

templates = {
	{
		name = 'bread',
		height = 3,
		spriteNumber = 33
	},
	{
		name = 'lettuce',
		height = 3,
		spriteNumber = 3
	},
	{
		name = 'tomatoes',
		height = 3,
		spriteNumber = 5
	},
	{
		name = 'cheese',
		height = 3,
		spriteNumber = 7
	},
	{
		name = 'bacon',
		height = 3,
		spriteNumber = 9
	},
	{
		name = 'ham',
		height = 3,
		spriteNumber = 11
	},
	{
		name = 'pickles',
		height = 3,
		spriteNumber = 13
	},
}

function hasAnimation()
	return gs.currentAnimation != nil and costatus(gs.currentAnimation) != 'dead'
end

function acceptInput()
	if (btn(dirs.left)) then
		gs.player.x -= gs.player.horizSpeed * gs.dt
	elseif btn(dirs.right) then
		gs.player.x += gs.player.horizSpeed * gs.dt
	end

	if gs.isFreePlay and btnp(dirs.x) then
		startGameOver()
	end

	-- -- DEBUG!
	-- if btnp(dirs.x) then
	-- 	captureTopping(cloneTemplate(templates[1], gs.player.x, 0, 0, 0))
	-- end
	-- if btnp(dirs.z) then
	-- 	captureTopping(cloneTemplate(templates[2], gs.player.x, 0, 0, 0))
	-- 	captureTopping(cloneTemplate(templates[2], gs.player.x, 0, 0, 0))
	-- 	captureTopping(cloneTemplate(templates[2], gs.player.x, 0, 0, 0))
	-- 	captureTopping(cloneTemplate(templates[2], gs.player.x, 0, 0, 0))
	-- end
end

function _update()
	if gs.isGameOver then
		if gs.endTime == nil then
			gs.endTime = t()
		end
		if btnp(dirs.x) then
			_init(gs.isFreePlay)
		end
		return
	end

	if hasAnimation() then
		local active, exception = coresume(gs.currentAnimation)
			-- assert(false)
		if exception then
			stop(trace(gs.currentAnimation, exception))
		end

		return
	end

	updateFallers()

	acceptInput()

	shiftToppings()

	checkForCaptures()

	spawnFallers()

	updateCamera()
end

function updateCamera()
	local highest = gs:getHighestCap().y
	-- 64 -> 
	-- camera = 0

	if highest - gs.targetY < 64 then
		gs.targetY -= 20
	end	

	if gs.targetY < gs.cameraY then
		gs.cameraY -= gs.dt * 10
	end
end

function updateFallers()
	local newFree = {}
	for faller in all(gs.freeToppings) do
		faller.x += faller.vx * gs.dt
		faller.y += faller.vy * gs.dt
		local screenBottom = gs.cameraY + 150
		if faller.y < screenBottom then
			add(newFree, faller)
		end
	end

	gs.freeToppings = newFree
end

function checkForCaptures()
	local highest = gs:getHighestCap()
	for free in all(gs.freeToppings) do
		local dx = highest.x - free.x
		local dy = highest.y - free.y
		if abs(dx) < 8 and abs(dy) < 4 then
			captureTopping(free)
			return
		end
	end
end

function shiftToppings()
	local previous = gs.player
	for top in all(gs.toppings) do
		top.x -= (top.x - previous.x) / 1.5
		local acc = - (top.x - previous.x)
		top.vx += acc * gs.dt - top.vx * gs.dt
		top.x += top.vx * gs.dt

		previous = top
	end
end

function drawTopping(obj, x, y)
	spr(obj.spriteNumber, x, y, 2, 2, obj.flipX)
end

function drawPlayer()
		-- Draw
	drawTopping(gs.player, gs.player.x, gs.player.y)

	for top in all(gs.toppings) do
		-- print(gs.player.y)
		-- assert(false)
		drawTopping(top, top.x, top.y)
	end
end

function drawFallers()
	for top in all(gs.freeToppings) do
		drawTopping(top, top.x, top.y)
	end
end

function _draw()
	cls(0)
	if gs.isGameOver then
		camera()
		print('\n final sandwich height: \n\n                ' .. #gs.toppings .. '\n\n\n\n\n\n press ❎ to play again', 0, 0, 7)
		return
	end
	camera(0, gs.cameraY)

	drawPlayer()

	drawFallers()
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000b000000000000000022220222000000aa000000aaa77a000000000000000000002222222222000000000000000000000000000
0000000000777777777777000bbbbbb3333b0000022f88822f8222000a07aaaa700700a00888888000008888002eeeeeeeeee200000000003330000000000000
00000000777777777777777703333bb000003bbb02888828888828200a00a7007007aaa082ffff8882888f2f02eeeeeeeeffee2000033303bbb3033000000000
000000007777777777777777bbbb3bbbb3bbb0bb022888f288f828200777a70aaaaaaa00f88288ff2ffff88802eeeeeeeeeeee20003b7b03bb733b3000000000
0000000000777777777777000bbb000bbbbbbb000002222022222200aaaaaaaa00000000880008888888880000222222222220000003330033303bb300000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000044444444444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000004fffffffffffff400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000044fffffffffffff400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000444444444444444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000022222222220000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000002eeeeeeeeee2000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000002eeeeeeeeffee200000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000002eeeeeeeeeeee200000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000222222222220000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088888800000888800000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000082ffff8882888f2f00000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f88288ff2ffff88800000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000880008888888880000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000aa000000aaa77a00000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000a07aaaa700700a00000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00a7007007aaa00000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000777a70aaaaaaa000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaaaaaa000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000008888880000088880000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000082ffff8882888f2f0000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000f88288ff2ffff8880000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000a88888888888888000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000a22888f288f8282000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000aaa222202222220000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000888aaaaaaa87a7770000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000f2f888288aaaaaaaa000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000888ffff2ff88288f0000000000000000000000000000000000000000000
000000000000000000000000000000000000000022222222220000000000000000000338888888883aa880000000000000000000000000000000000000000000
0000000000000000000000000000000000000002eeeeeeeeee20000000000000000003b337bb3ab7b3a000000000000000000000000000000000000000000000
000000000000000000000000000000000000002eeeeeeeeffee200000000000000003bb37333003330a000000000000000000000000000000000000000000000
000000000000000000000000000000000000002eeeeeeeeeeee20000000000000000bbaaaaaaa37a777000000000000000000000000000000000000000000000
000000000000000000000000000000000000000222222222220000000000000000003333bb00aaaaaaaa00000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000bbbb3bbbb3bbb8bb000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000082bbbf88bbbbbbbf0000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000f88288ff2ffff8880000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000088eff888888888000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000042eeeeeeeeeeee2000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000004ff222222222224000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000044fffffffffffff4000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000004444444444444444000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000007777777777777777000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000077777777777700000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000444444444444440000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000004fffffffffffff4000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000044fffffffffffff4000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000004444444444444444000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000100000000009720097200972008720080200802008020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000057500675006750067500775007750087500875009750097500a7500b7500c7500c7500d7500f75010750107501175011750137501375015750177501775019750197501a7501c7501d7502075000700
