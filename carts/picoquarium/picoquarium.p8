pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

-- make 64x64!
poke(0x5f2c,3)

bgn = 0

fishsm1 = {"(><"}
fishsm1_c = {"ghh"}
fishsm2 = {"<><"}
fishsm2_c = {"ggg"}
snail = {"@"}
snail_c = {"g"}
urchin = {"**"}
urchin_c = {"gg"}
fishmed = {

	"  __",
	"\\~>.\\",
 "/`-~'"
}

--  __
--\~>.\			-- todo make a flounder
--/`-~'

fishmed_c = {
	"  gg",
	"hgijg",
	"hgggg"
}

fishmed2 = {
	" __",
	"/.<\\/",
	"`--'`"
}
--  __
-- /.<`/
-- `--'`
fishmed2_c = {
	" gg",
	"gjigh",
	"ggggh"
}

angel = {
	"  \\ ",
	"><)>",
	"  / "
}

--  \
--><)>
--  /

angel_c = {
	"  g",
	"hiji",
	"  g"
}

--   _
-- ><_>
--   '

--   __
-- \/ o\
-- /\__/

--  __
-- /o \/
-- \__/\



fishbig = {
	"     .:/      ",
 	"  ,,///;,  ,//",
	" o:::::;;;/// ",
	">:::::::;;\\\\\\ ",
	" ``\\\\\\\\\\'' `:\\"
}
--     .:/
--  ,,///;,  ,//
-- 0:::::;; ///
-->:::::::;;\\\
-- ``\\\\\'' `:\
fishbig_c = {
	"     ggg      ",
	"  hhggggh  iii",
	" 7hhhhhhhhiii ",
	"khhhhhhhhhiii ",
	" hhlllllhh iii"
}

--
-- /
--<
-- \
-- ``


kelp = {
	"( ",
	" )",
	"( ",
	" )",
	"( ",
	" )",
	"( ",
	" )",
	"( ",
}

kelp2 = {
	" )",
	"( ",
	" )",
	"( ",
	" )",
	"( ",
	" )",
	"( ",
	" )",
}

kelp_c = "3"


mirmap = {
 ["<"] = ">",
 [">"] = "<",
 ["("] = ")",
 [")"] = "(",
 ["/"] = "\\",
 ["\\"] = "/",
 ["'"] = "`",
 ["`"] = "'",
 [","] = "."			-- best we can do..
}
-- printf = printfish
-- todo rename fish param
function printf(fish,fish_c,x,y,col_trans,mirror)
	--col_trans={a=1}
	for i,line in pairs(fish) do
		y_d = (i + y) * 6
		line_c = fish_c[i]
		for j = 1,#line do
			x_d = (j + x) * 4

			char = sub(line,j,j)
			col = sub(line_c,j,j)
			if col_trans != nil and 
					col_trans[col] != nil then
				col = col_trans[col]
			end
			
			if mirror then
				char = mirmap[char] or char
				x_d = (#line - j + 1 + x) * 4
			end
			
			if char != " " then
				rectfill(x_d,y_d,x_d+3,y_d+5,bgn)
				print(char, x_d, y_d, col)
			end
		end
	end
end

x = 10
y = 0

fishes = {}
maxfish = 6

function rand_colors(colmap)
	col_trans = {
		["0"]=0,
		["1"]=1,
		["2"]=2,
		["3"]=3,
		["4"]=4,
		["5"]=5,
		["6"]=6,
		["7"]=7,
		["8"]=8,
		["9"]=9,
		a=10,
		b=11,
		c=12,
		d=13,
		e=14,
		f=15
	}
	
	for i,str in pairs(colmap) do
		for j = 1,#str do
			col = sub(str,j,j)
			
			if col_trans[col] == nil then
				col_trans[col] = 1 + flr(rnd(15))
			end
		end
	end
	
	return col_trans
end

function create_frame(
		template, 
		colors,
		dur)
	-- if we have a single color
	-- create a map to cover template
	if type(colors) == "string" then
		col = colors
		colors = {}
		for i,row in pairs(template) do
			colors[i] = ""
			for _=1,#row do
				colors[i] = colors[i] .. col
			end
		end
	end
	
	dur = dur or 1
	
	return {
		dur = dur,
		template = template,
		colors = colors
	}
end

function popfish()
	local rand = rnd()
	mirror = rnd() < 0.5
	--print(rand)
	--er()
	if rand < 0.15 then
		return newfishbasic(
			fishmed2,
			fishmed2_c,
			-0.3
		)
	elseif rand < 0.3 then
		return newfishbasic(
			fishmed,
			fishmed_c,
			0.3
		)
	elseif rand < 0.55 then
		return newfishbasic(
			fishsm1,
			fishsm1_c,
			mirror and 0.3 or -0.3,
			mirror
		)
	elseif rand < 0.70 then
		return newfishbasic(
			fishsm2,
			fishsm2_c,
			mirror and 0.3 or -0.3,
			mirror
		)
	elseif rand < 0.87 then
		return newfishbasic(
			angel,
			angel_c,
			mirror and -0.6 or 0.6,
			mirror
		)
	elseif rand < 0.89 then
		return newfishbasic(
			snail,
			snail_c,
			mirror and -0.03 or 0.03,
			mirror,
			8,
			true
		)
	elseif rand < 0.9 then
		return newfishbasic(
			urchin,
			urchin_c,
			mirror and -0.01 or 0.01,
			mirror,
			8,
			true
		)
--	elseif rand < 0.9 then
--		return newfishbasic(
--			{
--				"
--			}
--		)
	else
		return newfishbasic(
			fishbig,
			fishbig_c,
			mirror and 0.3 or -0.3, ---0.3,
			mirror
		)
	end
end

function newfishbasic(
	template,
	template_c,
	--speed,
	-- +1 for left, -1 for right
	direction,
	mirror,
	ypos,				-- override
	isboring		-- For snails and urchins
)
	local frames = {
		create_frame(template,template_c)
	}
	local col_map = rand_colors(template_c)
	local x0 = 5 - 20 * sgn(direction)
	local y0 = rnd(10 - #template)
	local vx = (rnd() + 1/5) * direction
	local ret = newfish(
		frames,
		col_map,
		{x0,ypos or y0},
		{vx,0}
	)
	ret.mirror = mirror
	ret.isboring = isboring
	return ret
end


function newfish(
		frames,
		col_map,
		pos,
		vel)
	
	-- detect a table 
	-- of {"a"} vs {a=10}
	if type(col_map) == "string"
			or col_map[1] != nil then
		col_map = rand_colors(col_map)
	end
	
	if type(pos) != "function" then
		local pos0 = pos
		function pos(t)

			--if true then return {0,0} end
			return {pos0[1] + t*vel[1],
											pos0[2] + t*vel[2]}
		end
	end
		return {
			frames = frames,
			col_map = col_map,
			getpos = pos,
			frame_index = 1,
			frame_ticks = 0,
			mirror = false,
			fish_ticks = 0
		}

end

function _init()
	-- randomize kelp
	
	-- keep track of where the 
	-- kelp is to avoid clumping
	local valid = {}
	for i = 1,14 do
		valid[i] = i
	end
	
	local posarr = {}
	for _ = -1, rnd(4) do
		local x = flr(rnd(16))
		if valid[x] != nil then
			posarr[#posarr+1] = x
			valid[x] = nil
			valid[x+1] = nil
			valid[x-1] = nil
		end
	end
	
	for _,x in pairs(posarr) do
		local dur = rnd(20) + 20
		local frames = {
			create_frame(
				kelp,
				kelp_c,
				dur
			),
			create_frame(
				kelp2,
				kelp_c,
				dur
			)
		}
		local pos = {
			x,
			8 - rnd(6)
		}
		fishes[#fishes+1] = newfish(
			frames,
			{["a"]=3},--kelp_c,
		 pos,
			{0,0}
		)
		if rnd() > 0.5 then
			fishes[#fishes].mirror = true
		end
	end
	
	maxfish += #fishes
	
--
--	
--	fishes[#fishes+1] = newfish(
--		frames,
--		{["a"]=3},--kelp_c,
--		
----		function(t)
----			fishes[2].mirror = not fishes[2].mirror
----			return {0,0}
----		end
--		{8,0},
--		{0,0}
--	)
if true then return end
	frames = {
		create_frame(
			fishbig,
			fishbig_c
		)
	}
	
	col_map = rand_colors(
		fishbig_c
	)
	
	fishes[#fishes+1] = newfish(
		frames,
		col_map,
		{10, 3},
		{-0.1, 0}
	)
	fishes[#fishes].mirror = true

--		print(fishes[1].mirror)
--	print(fishes[2].mirror)
--	print(fishes[3].mirror)
	
	if true then return end

	
	fishes[#fishes+1] = {
		template = kelp,
		colors = kelp_c
	}
	
	
	fishes[#fishes+1] = {
		template = fishmed,
		colors = fishmed_c,
		col_trans = 
			rand_colors(fishmed_c),
		pos = {0,4},
		vel = {0.1, 0}
	}
end

ticks = 0
function _update()
	ticks += 1
	for _, fish in pairs(fishes) do
		fish.frame_ticks += 1
		fish.fish_ticks += 1
		if fish.frame_ticks >
			 fish.frames[fish.frame_index].dur
			then
				fish.frame_index += 1
				if fish.frame_index > #fish.frames then
					fish.frame_index = 1
				end
				fish.frame_ticks = 0
		end
	end
	
	oldfish = fishes
	fishes = {}
	for _, fish in pairs(oldfish) do
		local x = fish.getpos(fish.fish_ticks)[1]
		if -20 < x and x < 30 then
			fishes[#fishes+1] = fish
		end 
	end
	
	-- con't count the boring ones...
	local fishcount = 0
	for fish in all(fishes) do
		if not fish.isboring then
			fishcount += 1
		end
	end

	if fishcount < maxfish then
		fishes[#fishes+1] = popfish()
	end
end

function _draw()
	cls()
	for _,fish in pairs(fishes) do
		pos = fish.getpos(fish.fish_ticks)
		
		printf(
			fish.frames[fish.frame_index].template,
			fish.frames[fish.frame_index].colors,
			flr(pos[1]),
			flr(pos[2]),
			fish.col_map,
			fish.mirror
		)
	end
	--ocean floor
	rectfill(0,60,100,100,bgn)
	print("-----------------",0,60,9)

end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
