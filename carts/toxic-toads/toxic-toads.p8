pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
--toxic toads                    v0.1.0
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

gameOverWin = 'win'
gameOverLose = 'lose'

function _init()
	gs = {
		isGameOver = false,
		gameOverState = nil,
		startTime = t(),
		endTime = nil,
		currentAnimation = nil,
		frogs = {},
		poisonChain = {},
		dim = 8,
		cursor = vec2(4, 7),
		boundaryCursor = vec2(4, 7),
		getSelected = function(self)
			for frog in all(self.frogs) do
				if frog:isHighlighted() then
					return frog
				end
			end
		end,
		getFrogAt = function(self, pos, overrideBoundary)
			for frog in all(self.frogs) do
				if frog.pos == pos and (overrideBoundary or not frog:isBoundary()) then
					return frog
				end
			end
		end,
		checkSuccess = function(self)
			for frog in all(gs.frogs) do
				if not frog:isBoundary() and
				 not frog.isPoisoned then
					return false
				end
			end
			return true
		end
	}

	populateFrogs()
	-- gs.frogs[29].isHighlighted = true
end

function winPuzzle()
	sfx(1)
	-- Create animation???
	gs.currentAnimation = cocreate(function()
		for i = 1, 10 do
			yield()
		end
		gs.isGameOver = true
		gs.gameOverState = 'win'
	end)
end

function failPuzzle()
	gs.currentAnimation = cocreate(function()
		sfx(0)

		-- for frog in all(gs.poisonChain) do
		for i = #gs.poisonChain, 1, -1 do
			local frog = gs.poisonChain[i]
			if not frog:isBoundary() then
				frog.isPoisoned = false
			end
			yield()
			yield()
			yield()
		end
		gs.poisonChain = {}
	end)

end

function populateFrogs()
	for x = 0, gs.dim-1 do
		for y = 0, gs.dim-1 do
			local pos = vec2(x,y)
			if pos == vec2(3, 2) or
				pos == vec2(5, 3) or
				pos == vec2(6, 1) then
					-- Nothing				
			else
				if isBoundary(pos) then
					local facing = 0
					if pos.x == 0 then
						facing = 2 -- right
					elseif pos.x == gs.dim-1 then
						facing = 0 --left
					elseif pos.y == 0 then
						facing = 3
					elseif pos.y == gs.dim-1 then
						facing = 1
					end

					add(gs.frogs, makeFrog(
						x,
						y,
						facing,
						true
						))
				else
					add(gs.frogs, makeFrog(
						x,
						y,
						rnd({0, 1, 2, 3})
						))
				end
			end
		end
	end
end

function getFacingOffset(facing)
	if facing == 0 then
		return vec2(-1, 0)
	elseif facing == 1 then
		return vec2(0, -1)
	elseif facing == 2 then
		return vec2(1, 0)
	else
		return vec2(0, 1)
	end
end

function isBoundary(v)
	return v.x == 0 or v.x == gs.dim -1
				or v.y == 0 or v.y == gs.dim -1
end

function makeFrog(x, y, facing, isPoisoned)
	return {
		isBoundary = function(self)
			return isBoundary(self.pos)
		end,
		getUpperLeft = function(self)
			local offset = vec2(0, 0)
			return self.pos * 16 + offset
		end,
		pos = vec2(x, y),
		-- Note, this does not follow dirs convention
		facing = facing,
		isPoisoned = isPoisoned, --rnd() < 0.5,
		isHighlighted = function(self)
			return self.pos == gs.cursor
		end,
		getFacing = function(self)
			return self.pos + getFacingOffset(self.facing)
		end,
	}
end

function rndrange(_min, _max)
	local diff = _max - _min
	return _min + diff * rnd()
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
	end,
	__div = function(v, s)
		return vec2(v.x / s, v.y / s)
	end,
	__eq = function(v1, v2)
		return v1.x == v2.x and v1.y == v2.y
	end
}

function vec2fromAngle(ang)
	return vec2(cos(ang), sin(ang))
end

function vec2(x, y)
	local ret = {
		x = x,
		y = y,
		clone = function(self)
			return vec2(self.x, self.y)
		end,
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
		end,
		angle = function(self)
			return atan2(self.x, self.y)
		end
	}

	setmetatable(ret, metaTable)

	return ret
end


function hasAnimation()
	return gs.currentAnimation != nil and costatus(gs.currentAnimation) != 'dead'
end

function cursorIsValid(cursor)
	if 0 <= cursor.x and cursor.x < gs.dim and
		0 <= cursor.y and cursor.y < gs.dim then
			-- TODO also check vacant spots
			-- ...maybe not necessary
		if not isBoundary(cursor) then
			return true
		else
			return (gs.cursor == gs.boundaryCursor)
				or (cursor == gs.boundaryCursor)
		end
	end
	return false
end
-- function modularAdd(x, )
function acceptInput()
	local cursor = gs.cursor:clone()
	if btnp(dirs.left) then
		cursor.x -= 1
	elseif btnp(dirs.right) then
		cursor.x += 1
	elseif btnp(dirs.up) then
		cursor.y -= 1
	elseif btnp(dirs.down) then
		cursor.y += 1
	end
	if cursorIsValid(cursor) then
		if gs.cursor == gs.boundaryCursor and isBoundary(cursor) then
			gs.boundaryCursor = cursor
		end
		gs.cursor = cursor
	end

	local selectedFrog = gs:getSelected()
	if selectedFrog != nil then
		if selectedFrog:isBoundary() then
			if btnp(dirs.x) then
				createAnimation(selectedFrog)
			end
		else
			if btnp(dirs.z) then
				-- TODO get rid of this
				selectedFrog.facing = (selectedFrog.facing - 1) % 4
			elseif btnp(dirs.x) then
				selectedFrog.facing = (selectedFrog.facing + 1) % 4
			end
		end
	end
end

function createAnimation(frog)
	gs.currentAnimation = cocreate(function()

		-- local upperLeft = frog:getUpperLeft()
		-- Tongue
		local spriteNumber = 72 + frog.facing * 2
		for i = 1, 14, 3 do
			local upperLeft = frog:getUpperLeft() + getFacingOffset(frog.facing) * i
			spr(spriteNumber, upperLeft.x, upperLeft.y, 2, 2)
			drawFrog(frog)
		drawCursor()
			yield()
		end

		local otherFrog = gs:getFrogAt(frog:getFacing())

		local isFailed = false
		-- Check failure here
		if otherFrog == nil then
			isFailed = true
 		elseif otherFrog.isPoisoned then
 			isFailed = true
 		else
			otherFrog.isPoisoned = true
			add(gs.poisonChain, otherFrog)
		end

		for i = 14, 1, -3 do
			local upperLeft = frog:getUpperLeft() + getFacingOffset(frog.facing) * i
			spr(spriteNumber, upperLeft.x, upperLeft.y, 2, 2)
			drawFrog(frog)
		drawCursor()
			yield()
		end



		if isFailed then
			failPuzzle()
			return
		elseif gs:checkSuccess() then
			winPuzzle()
			return
		end



		createAnimation(otherFrog)
    end)
end

function _update()
	if gs.isGameOver then
		if gs.endTime == nil then
			gs.endTime = t()
		end
		-- Restart
		if btnp(dirs.x) then
			_init()
		end
		return
	end

	if hasAnimation() then
		-- local active, exception = coresume(gs.currentAnimation)
		-- if exception then
		-- 	stop(trace(gs.currentAnimation, exception))
		-- end

		return
	end

	acceptInput()

end

function drawGameOverWin()
	print('')
	print(' you won!')
	print('')
	print(' press ❎ to play again')
end

function drawGameOverLose()

end

function drawFrog(frog, drawHighlight, drawBoundary)
	local spriteNumber = 64
	if frog.isPoisoned then
		spriteNumber = 96
	end
	spriteNumber += frog.facing * 2

	if frog:isBoundary() and not drawBoundary then
		return
	end

	local upperLeft = frog:getUpperLeft()
	palt(0, false)
	palt(15, true)
	spr(spriteNumber, 
		upperLeft.x,
		upperLeft.y,
		2, 
		2
		)
	palt()
	-- if frog:isHighlighted() and drawHighlight then
	-- 	upperLeft -= vec2(1,1)
	-- 	rect(upperLeft.x, upperLeft.y,
	-- 		upperLeft.x + 16, upperLeft.y + 16, 7)
	-- end
end

function drawFrogs()
	for frog in all(gs.frogs) do
		drawFrog(frog, true)
	end
end

-- function doDrawHighlight()
-- 	-- makeFrog()
-- end

function drawCursor()
	local upperLeft = gs.cursor * 16
	rect(upperLeft.x, upperLeft.y, upperLeft.x+16, upperLeft.y +16, 7)

	local frog = gs:getFrogAt(gs.boundaryCursor, true)
	if frog != nil then
		drawFrog(frog, nil, true)
	end
end

function _draw()
	cls(1)
	if gs.isGameOver then
		if gs.gameOverState == gameOverWin then
			drawGameOverWin()
		else
			drawGameOverLose()
		end
		return
	end

	drawFrogs()

	-- doDrawHighlight()
	drawCursor()


	if hasAnimation() then
		local active, exception = coresume(gs.currentAnimation)
		if exception then
			stop(trace(gs.currentAnimation, exception))
		end

		return
	end

	-- Draw
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000003330000330000000bbbbbbbb0000000bbb00000bb000000bbb00000bb00000000000000000000000000000000000000000000000000000000000
0070070000033b330033330000bbbbbbbbbbbb00000bbbb333bbbb00000bbbb882bbbb0000000000000000000000000000000000000000000000000000000000
0007700000033b33303133000bbb33333333bbb000b33b33333b330000b6cb88882bc1000000000ee00000000000000000000000000000000000000000000000
0007700000333133331133300bbb3333333333bb00b33333333333b000bcce888888c1b00000000ee00000000000000000000000000000000000000000000000
0070070000333113331b333000bb3333333333bb0bb33300300333b00bb6c8008008c1b0000000eeee0000000000000000000000000000000000000000000000
000000000033331333bb3330000bbb53333335bb0bbb337037033bb00bbbe87087082bb0000000eeee0000000000000000000000000000000000000000000000
000000000033333333b333300000b335333353bb0bbb333333333bb00bbb888888882bb0000000eeee0000000000000000000000000000000000000000000000
000000000033331331133330000bb333333333bb0bbb333333333bb00bbbe88888888bb00000000ee00000000000000000000000000000000000000000000000
00000000003333133133330000bbb553333355bb0bbb533333335bb00bbb588888825bb00000000ee00000000000000000000000000000000000000000000000
0000000000333313333333000bbbb335333533bb0bbb353333353bb00bbbc5e88825cbb00000000ee00000000000000000000000000000000000000000000000
0000000000033313333333000bbbb33333333bb00bbb335333533bb00bbbcc58885ccbb00000000ee00000000000000000000000000000000000000000000000
0000000000003313333330000bbbbb3333333b0000bb333333333b0000bb6ccc8ccc1b000000000ee00000000000000000000000000000000000000000000000
00000000000003b333330000000bbbb3333bb000000bb3333333bb00000bb6cc8cc1bb000000000ee00000000000000000000000000000000000000000000000
00000000000000000000000000000bbbbbbb00000000bbbbbbbbb0000000bbbbbbbbb0000000000ee00000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000bbbbbbb000000000bbbbbbb00000000000ee00000000000000000000000000000000000000000000000
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
ffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbfffff0000000000000000000000000000000000000000000000000000000ee0000000
ffffbbbbbbbbfffffffbbbfffffbbfffffffbbbbbbbffffffffbbbbbbbbbffff0000000000000000000000000000000000000000000000000000000ee0000000
ffb333bbbbbbbbfffffbbbb333bbbbfffffbbbbbbbbbbfffffbb3333333bbfff0000000000000000000000000000000000000000000000000000000ee0000000
fbb3333335333bbfffb33b33333b33ffffbbbbbbbb333bbfffb333333333bbff00000000000000000000000ee000000000000000000000000000000ee0000000
fbbb3333335333bbffb33333333333bffbb3335333333bbffbb335333533bbbf00000000000000000000000ee000000000000000000000000000000ee0000000
ffb33003333533bbfbb33300300333bfbb3335333333bbbffbb353333353bbbf0000000000000000000000eeee00000000000000000000000000000ee0000000
ff333073333333bbfbbb337037033bbfbb33533337033bfffbb533333335bbbf00000eee00000000000000eeee00000000000000eee000000000000ee0000000
ff333333333333bbfbbb333333333bbfbb333333300333fffbb333333333bbbf000eeeeeeeeeeeee000000eeee000000eeeeeeeeeeeee0000000000ee0000000
ff333003333333bbfbbb333333333bbfbb333333333333fffbb333333333bbbf000eeeeeeeeeeeee0000000ee0000000eeeeeeeeeeeee000000000eeee000000
ffb33073333533bbfbbb533333335bbfbb333333370333fffbb330730733bbbf00000eee000000000000000ee000000000000000eee00000000000eeee000000
fbbb3333335333bbfbbb353333353bbfbb33533330033bfffb33300300333bbf00000000000000000000000ee00000000000000000000000000000eeee000000
fbb3333335333bbffbbb335333533bbfbb3335333333bbbffb33333333333bff00000000000000000000000ee000000000000000000000000000000ee0000000
fbb333bbbbbbbbffffbb333333333bfffbb3335333333bbfff33b33333b33bff00000000000000000000000ee000000000000000000000000000000ee0000000
fffbbbbbbbbbbffffffbb3333333bbffffbbbbbbbb333bffffbbbb333bbbbfff00000000000000000000000ee000000000000000000000000000000000000000
fffffbbbbbbbffffffffbbbbbbbbbfffffffbbbbbbbbfffffffbbfffffbbbfff00000000000000000000000ee000000000000000000000000000000000000000
fffffffffffffffffffffbbbbbbbffffffffffffffffffffffffffffffffffff00000000000000000000000ee000000000000000000000000000000000000000
ffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbfffff0000000000000000000000000000000000000000000000000000000000000000
ffffbbbbbbbbfffffffbbbfffffbbfffffffbbbbbbbffffffffbbbbbbbbbffff0000000000000000000000000000000000000000000000000000000000000000
ffbcccbbbbbbbbfffffbbbb888bbbbfffffbbbbbbbbbbfffffbbccc8cccbbfff0000000000000000000000000000000000000000000000000000000000000000
fbbccc8885cccbbfffbccb88888bccffffbbbbbbbbcccbbfffbcccc8ccccbbff0000000000000000000000000000000000000000000000000000000000000000
fbbb8888885cccbbffbcc8888888ccbffbbccc5888cccbbffbbcc58885ccbbbf0000000000000000000000000000000000000000000000000000000000000000
ffb880088885ccbbfbbcc8008008ccbfbbccc5888888bbbffbbc5888885cbbbf0000000000000000000000000000000000000000000000000000000000000000
ff8880788888ccbbfbbb887087088bbfbbcc588887088bfffbb588888885bbbf0000000000000000000000000000000000000000000000000000000000000000
ff888888888888bbfbbb888888888bbfbbcc8888800888fffbb888888888bbbf0000000000000000000000000000000000000000000000000000000000000000
ff8880088888ccbbfbbb888888888bbfbb888888888888fffbb888888888bbbf0000000000000000000000000000000000000000000000000000000000000000
ffb880788885ccbbfbbb588888885bbfbbcc8888870888fffbb880780788bbbf0000000000000000000000000000000000000000000000000000000000000000
fbbb8888885cccbbfbbbc5888885cbbfbbcc588880088bfffbcc8008008ccbbf0000000000000000000000000000000000000000000000000000000000000000
fbbccc8885cccbbffbbbcc58885ccbbfbbccc5888888bbbffbcc8888888ccbff0000000000000000000000000000000000000000000000000000000000000000
fbbcccbbbbbbbbffffbbcccc8ccccbfffbbccc5888cccbbfffccb88888bccbff0000000000000000000000000000000000000000000000000000000000000000
fffbbbbbbbbbbffffffbbccc8cccbbffffbbbbbbbbcccbffffbbbb888bbbbfff0000000000000000000000000000000000000000000000000000000000000000
fffffbbbbbbbffffffffbbbbbbbbbfffffffbbbbbbbbfffffffbbfffffbbbfff0000000000000000000000000000000000000000000000000000000000000000
fffffffffffffffffffffbbbbbbbffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
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
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111bbbbbbb111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111bbb11111bb1111111bbbbbbbb1111111bbbbbbbbb11111111bbbbbbbb1111111bbb11111bb11111111111111111111111111111111111
1111111111111111111bbbb333bbbb1111b333bbbbbbbb1111bb3333333bb11111b333bbbbbbbb11111bbbb333bbbb1111111111111111111111111111111111
111111111111111111b33b33333b33111bb3333335333bb111b333333333bb111bb3333335333bb111b33b33333b331111111111111111111111111111111111
111111111111111111b33333333333b11bbb3333335333bb1bb335333533bbb11bbb3333335333bb11b33333333333b111111111111111111111111111111111
11111111111111111bb33300300333b111b33003333533bb1bb353333353bbb111b33003333533bb1bb33300300333b111111111111111111111111111111111
11111111111111111bbb337037033bb111333073333333bb1bb533333335bbb111333073333333bb1bbb337037033bb111111111111111111111111111111111
11111111111111111bbb333333333bb111333333333333bb1bb333333333bbb111333333333333bb1bbb333333333bb111111111111111111111111111111111
11111111111111111bbb333333333bb111333003333333bb1bb333333333bbb111333003333333bb1bbb333333333bb111111111111111111111111111111111
11111111111111111bbb533333335bb111b33073333533bb1bb330730733bbb111b33073333533bb1bbb533333335bb111111111111111111111111111111111
11111111111111111bbb353333353bb11bbb3333335333bb1b33300300333bb11bbb3333335333bb1bbb353333353bb111111111111111111111111111111111
11111111111111111bbb335333533bb11bb3333335333bb11b33333333333b111bb3333335333bb11bbb335333533bb111111111111111111111111111111111
111111111111111111bb333333333b111bb333bbbbbbbb111133b33333b33b111bb333bbbbbbbb1111bb333333333b1111111111111111111111111111111111
1111111111111111111bb3333333bb11111bbbbbbbbbb11111bbbb333bbbb111111bbbbbbbbbb111111bb3333333bb1111111111111111111111111111111111
11111111111111111111bbbbbbbbb11111111bbbbbbb1111111bb11111bbb11111111bbbbbbb11111111bbbbbbbbb11111111111111111111111111111111111
111111111111111111111bbbbbbb111111111111111111111111111111111111111111111111111111111bbbbbbb111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111bbbbbbb111111111111111111111
11111111111111111111bbbbbbb111111111bbbbbbb1111111111111111111111111bbbbbbbb1111111bbb11111bb111111bbbbbbbbb11111111111111111111
1111111111111111111bbbbbbbbbb111111bbbbbbbbbb111111111111111111111b333bbbbbbbb11111bbbb333bbbb1111bb3333333bb1111111111111111111
111111111111111111bbbbbbbb333bb111bbbbbbbb333bb111111111111111111bb3333335333bb111b33b33333b331111b333333333bb111111111111111111
11111111111111111bb3335333333bb11bb3335333333bb111111111111111111bbb3333335333bb11b33333333333b11bb335333533bbb11111111111111111
1111111111111111bb3335333333bbb1bb3335333333bbb1111111111111111111b33003333533bb1bb33300300333b11bb353333353bbb11111111111111111
1111111111111111bb33533337033b11bb33533337033b11111111111111111111333073333333bb1bbb337037033bb11bb533333335bbb11111111111111111
1111111111111111bb33333330033311bb33333330033311111111111111111111333333333333bb1bbb333333333bb11bb333333333bbb11111111111111111
1111111111111111bb33333333333311bb33333333333311111111111111111111333003333333bb1bbb333333333bb11bb333333333bbb11111111111111111
1111111111111111bb33333337033311bb33333337033311111111111111111111b33073333533bb1bbb533333335bb11bb330730733bbb11111111111111111
1111111111111111bb33533330033b11bb33533330033b1111111111111111111bbb3333335333bb1bbb353333353bb11b33300300333bb11111111111111111
1111111111111111bb3335333333bbb1bb3335333333bbb111111111111111111bb3333335333bb11bbb335333533bb11b33333333333b111111111111111111
11111111111111111bb3335333333bb11bb3335333333bb111111111111111111bb333bbbbbbbb1111bb333333333b111133b33333b33b111111111111111111
111111111111111111bbbbbbbb333b1111bbbbbbbb333b111111111111111111111bbbbbbbbbb111111bb3333333bb1111bbbb333bbbb1111111111111111111
11111111111111111111bbbbbbbb11111111bbbbbbbb1111111111111111111111111bbbbbbb11111111bbbbbbbbb111111bb11111bbb1111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111bbbbbbb111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111bbbbbbb11111111111111111111111111111111111111111111111111111
11111111111111111111bbbbbbb111111111bbbbbbbb11111111bbbbbbb11111111bbbbbbbbb111111111111111111111111bbbbbbb111111111111111111111
1111111111111111111bbbbbbbbbb11111b333bbbbbbbb11111bbbbbbbbbb11111bb3333333bb1111111111111111111111bbbbbbbbbb1111111111111111111
111111111111111111bbbbbbbb333bb11bb3333335333bb111bbbbbbbb333bb111b333333333bb11111111111111111111bbbbbbbb333bb11111111111111111
11111111111111111bb3335333333bb11bbb3333335333bb1bb3335333333bb11bb335333533bbb111111111111111111bb3335333333bb11111111111111111
1111111111111111bb3335333333bbb111b33003333533bbbb3335333333bbb11bb353333353bbb11111111111111111bb3335333333bbb11111111111111111
1111111111111111bb33533337033b1111333073333333bbbb33533337033b111bb533333335bbb11111111111111111bb33533337033b111111111111111111
1111111111111111bb3333333003331111333333333333bbbb333333300333111bb333333333bbb11111111111111111bb333333300333111111111111111111
1111111111111111bb3333333333331111333003333333bbbb333333333333111bb333333333bbb11111111111111111bb333333333333111111111111111111
1111111111111111bb3333333703331111b33073333533bbbb333333370333111bb330730733bbb11111111111111111bb333333370333111111111111111111
1111111111111111bb33533330033b111bbb3333335333bbbb33533330033b111b33300300333bb11111111111111111bb33533330033b111111111111111111
1111111111111111bb3335333333bbb11bb3333335333bb1bb3335333333bbb11b33333333333b111111111111111111bb3335333333bbb11111111111111111
11111111111111111bb3335333333bb11bb333bbbbbbbb111bb3335333333bb11133b33333b33b1111111111111111111bb3335333333bb11111111111111111
111111111111111111bbbbbbbb333b11111bbbbbbbbbb11111bbbbbbbb333b1111bbbb333bbbb111111111111111111111bbbbbbbb333b111111111111111111
11111111111111111111bbbbbbbb111111111bbbbbbb11111111bbbbbbbb1111111bb11111bbb11111111111111111111111bbbbbbbb11111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111bbbbbbb1111111111111111111111111bbbbbbb111111111111111111111
1111bbbbbbb111111111bbbbbbbb1111111bbb11111bb1111111bbbbbbbb1111111bbbbbbbbb11111111bbbbbbb11111111bbbbbbbbb11111111111111111111
111bbbbbbbbbb11111b333bbbbbbbb11111bbbb333bbbb1111b333bbbbbbbb1111bb3333333bb111111bbbbbbbbbb11111bb3333333bb1111111111111111111
11bbbbbbbbcccbb11bb3333335333bb111b33b33333b33111bb3333335333bb111b333333333bb1111bbbbbbbb333bb111b333333333bb111111111111111111
1bbccc5888cccbb11bbb3333335333bb11b33333333333b11bbb3333335333bb1bb335333533bbb11bb3335333333bb11bb335333533bbb11111111111111111
bbccc5888888bbb111b33003333533bb1bb33300300333b111b33003333533bb1bb353333353bbb1bb3335333333bbb11bb353333353bbb11111111111111111
bbcc588887088b1111333073333333bb1bbb337037033bb111333073333333bb1bb533333335bbb1bb33533337033b111bb533333335bbb11111111111111111
bbcc88888008881111333333333333bb1bbb333333333bb111333333333333bb1bb333333333bbb1bb333333300333111bb333333333bbb11111111111111111
bb8888888888881111333003333333bb1bbb333333333bb111333003333333bb1bb333333333bbb1bb333333333333111bb333333333bbb11111111111111111
bbcc88888708881111b33073333533bb1bbb533333335bb111b33073333533bb1bb330730733bbb1bb333333370333111bb330730733bbb11111111111111111
bbcc588880088b111bbb3333335333bb1bbb353333353bb11bbb3333335333bb1b33300300333bb1bb33533330033b111b33300300333bb11111111111111111
bbccc5888888bbb11bb3333335333bb11bbb335333533bb11bb3333335333bb11b33333333333b11bb3335333333bbb11b33333333333b111111111111111111
1bbccc5888cccbb11bb333bbbbbbbb1111bb333333333b111bb333bbbbbbbb111133b33333b33b111bb3335333333bb11133b33333b33b111111111111111111
11bbbbbbbbcccb11111bbbbbbbbbb111111bb3333333bb11111bbbbbbbbbb11111bbbb333bbbb11111bbbbbbbb333b1111bbbb333bbbb1111111111111111111
1111bbbbbbbb111111111bbbbbbb11111111bbbbbbbbb11111111bbbbbbb1111111bb11111bbb1111111bbbbbbbb1111111bb11111bbb1111111111111111111
1111111111111111111111111111111111111bbbbbbb111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111777777777777777771111111111111111111bbbbbbb111111111bbbbbbb111111111111111111111
11111111111111111111bbbbbbbb11111111bbbbbbb11111711bbb11111bb1117111bbbbbbbb1111111bbbbbbbbb1111111bbbbbbbbb11111111111111111111
111111111111111111b333bbbbbbbb11111bbbbbbbbbb111711bbbb333bbbb1171b333bbbbbbbb1111bb3333333bb11111bb3333333bb1111111111111111111
11111111111111111bb3333335333bb111bbbbbbbb333bb171b33b33333b33117bb3333335333bb111b333333333bb1111b333333333bb111111111111111111
11111111111111111bbb3333335333bb1bb3335333333bb171b33333333333b17bbb3333335333bb1bb335333533bbb11bb335333533bbb11111111111111111
111111111111111111b33003333533bbbb3335333333bbb17bb33300300333b171b33003333533bb1bb353333353bbb11bb353333353bbb11111111111111111
111111111111111111333073333333bbbb33533337033b117bbb337037033bb171333073333333bb1bb533333335bbb11bb533333335bbb11111111111111111
111111111111111111333333333333bbbb333333300333117bbb333333333bb171333333333333bb1bb333333333bbb11bb333333333bbb11111111111111111
111111111111111111333003333333bbbb333333333333117bbb333333333bb171333003333333bb1bb333333333bbb11bb333333333bbb11111111111111111
111111111111111111b33073333533bbbb333333370333117bbb533333335bb171b33073333533bb1bb330730733bbb11bb330730733bbb11111111111111111
11111111111111111bbb3333335333bbbb33533330033b117bbb353333353bb17bbb3333335333bb1b33300300333bb11b33300300333bb11111111111111111
11111111111111111bb3333335333bb1bb3335333333bbb17bbb335333533bb17bb3333335333bb11b33333333333b111b33333333333b111111111111111111
11111111111111111bb333bbbbbbbb111bb3335333333bb171bb333333333b117bb333bbbbbbbb111133b33333b33b111133b33333b33b111111111111111111
1111111111111111111bbbbbbbbbb11111bbbbbbbb333b11711bb3333333bb11711bbbbbbbbbb11111bbbb333bbbb11111bbbb333bbbb1111111111111111111
111111111111111111111bbbbbbb11111111bbbbbbbb11117111bbbbbbbbb11171111bbbbbbb1111111bb11111bbb111111bb11111bbb1111111111111111111
11111111111111111111111111111111111111111111111171111bbbbbbb11117111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111777777777777777771111111111111111111bbbbbbb111111111bbbbbbb111111111111111111111
11111111111111111111bbbbbbb111111111bbbbbbb11111111bbbbbbbbb11111111bbbbbbb11111111bbbbbbbbb1111111bbbbbbbbb11111111111111111111
1111111111111111111bbbbbbbbbb111111bbbbbbbbbb11111bb3333333bb111111bbbbbbbbbb11111bb3333333bb11111bb3333333bb1111111111111111111
111111111111111111bbbbbbbb333bb111bbbbbbbb333bb111b333333333bb1111bbbbbbbb333bb111b333333333bb1111b333333333bb111111111111111111
11111111111111111bb3335333333bb11bb3335333333bb11bb335333533bbb11bb3335333333bb11bb335333533bbb11bb335333533bbb11111111111111111
1111111111111111bb3335333333bbb1bb3335333333bbb11bb353333353bbb1bb3335333333bbb11bb353333353bbb11bb353333353bbb11111111111111111
1111111111111111bb33533337033b11bb33533337033b111bb533333335bbb1bb33533337033b111bb533333335bbb11bb533333335bbb11111111111111111
1111111111111111bb33333330033311bb333333300333111bb333333333bbb1bb333333300333111bb333333333bbb11bb333333333bbb11111111111111111
1111111111111111bb33333333333311bb333333333333111bb333333333bbb1bb333333333333111bb333333333bbb11bb333333333bbb11111111111111111
1111111111111111bb33333337033311bb333333370333111bb330730733bbb1bb333333370333111bb330730733bbb11bb330730733bbb11111111111111111
1111111111111111bb33533330033b11bb33533330033b111b33300300333bb1bb33533330033b111b33300300333bb11b33300300333bb11111111111111111
1111111111111111bb3335333333bbb1bb3335333333bbb11b33333333333b11bb3335333333bbb11b33333333333b111b33333333333b111111111111111111
11111111111111111bb3335333333bb11bb3335333333bb11133b33333b33b111bb3335333333bb11133b33333b33b111133b33333b33b111111111111111111
111111111111111111bbbbbbbb333b1111bbbbbbbb333b1111bbbb333bbbb11111bbbbbbbb333b1111bbbb333bbbb11111bbbb333bbbb1111111111111111111
11111111111111111111bbbbbbbb11111111bbbbbbbb1111111bb11111bbb1111111bbbbbbbb1111111bb11111bbb111111bb11111bbb1111111111111111111
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

__sfx__
000500002060024450210501e0401902016030130200f0200d0501160000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
0003000009450084500845007450074500745007450084500a4500d4501045013450184501f450194500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
