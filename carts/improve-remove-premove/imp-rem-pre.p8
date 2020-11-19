pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

gs = nil

moveImprove = 1
moveRemove = 2
movePremoveImp = 3
movePremoveRem = 4
movePremovePre = 5

movePremoveGen = 6		-- virtual move

moveDesc = {
	'move: improve',
	'move: remove',
	'predict: improve',
	'predict: remove',
	'predict: predict'
}

validMoves = {
	moveImprove,
	moveRemove,
	movePremoveImp,
	movePremoveRem,
	movePremovePre
}

potPlayer = 'pot'
humanPlayer = 'human'
cpuPlayer = 'cpu'
-- if the game ends in a draw
tiedPlayer = 'tie'

menuOptions = {
	{'improve', moveImprove},
	{'remove', moveRemove},
	{'pre-move', movePremoveGen}
}

menuOptions2 = {
	{'improve', movePremoveImp},
	{'remove', movePremoveRem},
	{'pre-move', movePremovePre}
}

function getCurrentOptions(gs)
	if gs.menuSelection.page == 1 then
		return menuOptions
	else
		return menuOptions2
	end
end

function isPremove(move)
	return move > moveRemove
end

function getCpuMove()
	local val = rnd(0.9)
	if val < 0.3 then
		return moveImprove
	elseif val < 0.6 then
		return moveRemove
	else
		val = rnd(0.9)
		if val < 0.3 then
			return movePremoveImp
		elseif val < 0.6 then
			return movePremoveRem
		else
			return movePremovePre
		end
	end
end

function executeHumanMove(humanMove)
	local cpuMove = getCpuMove()
	-- local cpuMove = validMoves[flr(rnd(#validMoves)) + 1]
	-- TODO randomize
	-- local cpuMove = moveImprove
	-- color(7)
	-- print(humanMove)
	-- assert(false)
	executeMoves(humanMove, cpuMove)
end

function premoveMatches(moveThatIsPremove, otherMove)
	if moveThatIsPremove == movePremoveImp then
		return otherMove == moveImprove
	elseif moveThatIsPremove == movePremoveRem then
		return otherMove == moveRemove
	else
		-- must be movePremovePre
		return isPremove(otherMove)
	end
end

-- function cloneAmounts() 
-- 	return {
-- 		pot = gs.pot,
-- 		human = gs.human,
-- 		cpu = gs.cpu
-- 	}
-- end

-- function applyAmounts(amounts)
-- 	gs.pot = amounts.pot
-- 	gs.human = amounts.human
-- 	gs.cpu = amounts.cpu
-- end

function createTransaction(playerPayer, playerRecipient, amount, moveOwner)
	return {
		payer = playerPayer,
		receiver = playerRecipient,
		amount = amount,
		moveOwner = moveOwner
	}
end

-- payer always gives half away rounded up
function createTransactionCalcAmount(playerPayer, playerRecipient, gs, moveOwner)
	local amount = ceil(gs[playerPayer] / 2)
	return createTransaction(playerPayer, playerRecipient, amount, moveOwner)
end

-- simpleMove must be improve or remove
function createTransactionFromMove(player, simpleMove, moveOwner)
	if simpleMove == moveImprove then
		return createTransactionCalcAmount(player, potPlayer, gs, moveOwner)
	else
		-- must be moveRemove
		return createTransactionCalcAmount(potPlayer, player, gs, moveOwner)
	end
end

function executeTransaction(transaction)
	gs[transaction.payer] -= transaction.amount
	gs[transaction.receiver] += transaction.amount
end	

-- function executeMoves(humanMove, cpuMove)
-- 	local transactions = createTransactionsFromMoves(humanMove, cpuMove)
-- 	for trans in all(transactions) do
-- 		executeTransaction(trans)
-- 	end
-- end

function isOdd(amount)
	return amount % 2 > 0
end

function createTransactionsFromMoves(humanMove, cpuMove)
	local transactions = {}

	if not isPremove(humanMove) and not isPremove(cpuMove) then
		add(transactions, createTransactionFromMove(humanPlayer, humanMove, humanPlayer))
		add(transactions, createTransactionFromMove(cpuPlayer, cpuMove, cpuPlayer))
		if humanMove == moveRemove and cpuMove == moveRemove and isOdd(gs.pot) then
			-- flip a coin to see who gets the extra coin
			transactions[flr(rnd(2)) + 1].amount -= 1
		end
	elseif isPremove(humanMove) and isPremove(cpuMove) then
		if premoveMatches(cpuMove, humanMove) and premoveMatches(humanMove, cpuMove) then
			-- It's a wash TODO do something
			-- sfx(0)
			add(transactions, createTransaction(humanPlayer, cpuPlayer, 0, tiedPlayer))
		elseif premoveMatches(cpuMove, humanMove) then
			-- So cpu was right but human was wrong
			-- Human pays up for being predictable
			add(transactions, createTransactionCalcAmount(humanPlayer, cpuPlayer, gs, cpuPlayer))
			-- Then they pay up again for failing to predict cpu
			-- violating the rule and considering moves to happen in sequence
			local amountLeft = gs.human - transactions[1].amount
			add(transactions, createTransaction(humanPlayer, cpuPlayer, ceil(amountLeft / 2), humanPlayer))

		elseif premoveMatches(humanMove, cpuMove) then
			-- Reverse of above, human was right but cpu wrong
			add(transactions, createTransactionCalcAmount(cpuPlayer, humanPlayer, gs, humanPlayer))
			-- Then they pay up again for failing to predict cpu
			-- add(transactions, createTransactionCalcAmount(cpuPlayer, humanPlayer, gs))

			local amountLeft = gs.cpu - transactions[1].amount
			add(transactions, createTransaction(cpuPlayer, humanPlayer, ceil(amountLeft / 2), cpuPlayer))
		else
			-- both wrong, which could result in a net change
			-- cpu pay up for failing to predict
			add(transactions, createTransactionCalcAmount(cpuPlayer, humanPlayer, gs, cpuPlayer))
			-- human pay up for failing to predict
			add(transactions, createTransactionCalcAmount(humanPlayer, cpuPlayer, gs, humanPlayer))
		end
	elseif isPremove(humanMove) then
		if premoveMatches(humanMove, cpuMove) then
			-- cpu was predictable, so it pays up and its move is nullified
			add(transactions, createTransactionCalcAmount(cpuPlayer, humanPlayer, gs, humanPlayer))
		else
			-- human failed to predict, so it pays up. cpu move still valid
			add(transactions, createTransactionCalcAmount(humanPlayer, cpuPlayer, gs, humanPlayer))
			add(transactions, createTransactionFromMove(cpuPlayer, cpuMove, cpuPlayer))
		end
	else
		-- Must be the cpumove that is the premove

		if premoveMatches(cpuMove, humanMove) then
			-- human was predictable, so it pays up and its move is nullified
			add(transactions, createTransactionCalcAmount(humanPlayer, cpuPlayer, gs, cpuPlayer))
		else
			-- cpu failed to predict, so it pays up. human move still valid
			add(transactions, createTransactionCalcAmount(cpuPlayer, humanPlayer, gs, cpuPlayer))
			add(transactions, createTransactionFromMove(humanPlayer, humanMove, humanPlayer))
		end
	end

	return transactions
end

function _init()
	local startAmount = 64
	gs = {
		pot = startAmount,
		human = startAmount,
		cpu = startAmount,
		menuSelection = {
			page = 1,
			index = 1
		},
		queuedMoveSelection = nil,
		winner = nil,
		updateCo = nil
	}

	-- menuitem(1, )

end


function executeQueuedMove()
	if gs.queuedMoveSelection == nil then
		return
	end

	local humanMove = gs.queuedMoveSelection
	local cpuMove = getCpuMove()
	gs.queuedMoveSelection = nil
	gs.menuSelection.page = 1
	gs.menuSelection.index = 1

	-- executeHumanMove(moveSelection)

	local transactions = createTransactionsFromMoves(humanMove, cpuMove)
	gs.transactions = transactions
	gs.humanMove = humanMove
	gs.cpuMove = cpuMove
	gs.blinkingMoveOwner = humanPlayer
	gs.updateCo = cocreate(executeMoveAnimation)


end


function myYield()
	if not gs.speedUpAnimation then
		yield()
	end
end

alternate = 1
function executeMoveAnimation()

	for trans in all(gs.transactions) do
		-- TODO draw something else?
		gs.currentTrans = trans
		for j = 1, 20 do
			myYield()
		end

		local originalAmount = trans.amount
		for j = 1, 20 do
			myYield()
		end
		for i = 1, originalAmount do
			gs[trans.payer] -= 1
			gs[trans.receiver] += 1
			trans.amount -= 1
			sfx(0)
			alternate = 1 - alternate
			myYield()
		end
		gs.currentTrans = nil
		gs.speedUpAnimation = false
	end
end




counter = 0
function _update()
	counter += 1
	if gs.updateCo != nil and costatus(gs.updateCo) != 'dead' then
		if btnp(dirs.x) then
			-- gs.updateCo = nil
			gs.speedUpAnimation = true
			return
		end
		-- local active, error = coresume(gs.updateCo)
		-- print(error)
		-- assert(false)
		local active, exception = coresume(gs.updateCo)
		if exception then
		  stop(trace(gs.updateCo, exception))
		end

		return
	end

	gs.speedUpAnimation = false

	checkWinCondition()

	acceptInput()

	executeQueuedMove()
	-- counter += 1
	-- if counter == 1 then
	-- 	executeHumanMove(moveImprove)
	-- end
end

function checkWinCondition()
	if gs.winner != nil then
		return
	end
	if gs.pot == 0 then
		if gs.human > gs.cpu then
			gs.winner = humanPlayer
			sfx(1)
		elseif gs.human < gs.cpu then
			gs.winner = cpuPlayer
			sfx(2)
		else
			gs.winner = tiedPlayer
			sfx(3)
		end
	end
end

dirs = {
	left = 0,
	right = 1,
	z = 4,
	x = 5
}

function acceptInput()
	if gs.winner != nil and btnp(dirs.x) then
		_init()
		return
	end

	if btnp(dirs.left) and gs.menuSelection.index > 1 then
		gs.menuSelection.index -= 1
	elseif btnp(dirs.right) and gs.menuSelection.index < 3 then
		gs.menuSelection.index += 1
	elseif btnp(dirs.z) then
		local choice = getCurrentOptions(gs)[gs.menuSelection.index][2]
		if choice == movePremoveGen then
			gs.menuSelection.page = 2
			gs.menuSelection.index = 1
		else
			gs.queuedMoveSelection = choice
		end
	elseif btnp(dirs.x) and gs.menuSelection.page == 2 then
		-- Go back to your first move
		gs.menuSelection.page = 1
		gs.menuSelection.index = 1
	end
end

function drawBoard()
	color(3)
	rectfill(0, 0, 128, 128)


	local centerX = 64
	local centerY = 48
	local ovalWidth = 64
	local ovalHeight = 32

	drawOval(centerX, centerY + 3, ovalWidth, ovalHeight)

	drawOval(centerX, centerY + 55, ovalWidth, ovalHeight)

	drawOval(centerX, centerY - 48, ovalWidth, ovalHeight)

	-- color(10)
	-- print(gs.cpu, centerX - 1, 3)
	-- print(gs.pot, centerX - 1, 49)
	-- print(gs.human, centerX - 1, 96)
	printNumber(gs.cpu .. '', centerX, 3)
	printNumber(gs.pot .. '', centerX, 49)
	printNumber(gs.human .. '', centerX, 96)

	if gs.currentTrans != nil then
		local posY = getYFromPlayer(gs.currentTrans.payer)
		printNumber('-' .. gs.currentTrans.amount, centerX + 43, posY, false)

		local posY = getYFromPlayer(gs.currentTrans.receiver)
		printNumber('+' .. gs.currentTrans.amount, centerX + 43, posY, false)

	end

	if gs.updateCo != nil and costatus(gs.updateCo) != 'dead' then
		local isBlinking = gs.currentTrans != nil and humanPlayer == gs.currentTrans.moveOwner
		drawMove(humanPlayer, gs.humanMove, isBlinking)
		isBlinking = gs.currentTrans != nil and cpuPlayer == gs.currentTrans.moveOwner
		-- isBlinking = true
		drawMove(cpuPlayer, gs.cpuMove, isBlinking)
	end
end

function drawMove(player, move, isBlinking)
	local y = nil
	if player == humanPlayer then
		y = 74
	else
		y = 19
	end
	color(7)
	local width = 70
	local startX = 29
	local height = 10
	local text = moveDesc[move]
	rectfill(startX, y, startX + width, y + height)
	color(0)
	if isBlinking and (flr(counter / 10) % 2) == 1 then 
		rect(startX + 1, y + 1, startX + width - 1, y + height - 1)
	end
	print(text, startX + 3, y + 3)
end

function getYFromPlayer(player)
	if player == humanPlayer then
		return 96
	elseif player == potPlayer then
		return 49
	else
		return 3
	end		
end

function printNumber(amount, centerX, localY, change)
	color(10)
	amount = amount .. ''
	if change then
		centerX = centerX - 1 - (#amount) / 2
	end

	print(amount, centerX, localY)
	-- if amount >= 100 then
	-- 	print(amount, centerX - 5, localY)
	-- elseif amount >= 10 then
	-- 	print(amount, centerX - 3, localY)
	-- else
	-- 	print(amount, centerX - 1, localY)
	-- end
end

function drawOval(centerX, centerY, ovalWidth, ovalHeight)
	color(7)

	ovalfill(centerX - ovalWidth / 2, centerY - ovalHeight / 2, centerX + ovalWidth/ 2, centerY + ovalHeight / 2)

	color(3)
	local ovalThickness = 7
	local ovalThicknessOther = ovalThickness * (ovalHeight / ovalWidth)
	ovalfill(centerX - ovalWidth / 2 + ovalThickness, centerY - ovalHeight / 2 + ovalThicknessOther + 2,
			centerX + ovalWidth / 2 - ovalThickness, centerY + ovalHeight / 2 - ovalThicknessOther - 2)
end



function drawMenu()
	local menuHeight = 25
	color(7)
	rectfill(0, 128 - menuHeight, 128, 128)

	color(0)
	rect(1, 128 - menuHeight + 1, 126, 126)

	local y = 128 - menuHeight/2 +4

	if gs.winner == nil then
		drawMenuOptions(y)
	else
		print('winner: ' .. gs.winner, 6, y - 11)
		print('press ❎ to play again', 6, y - 1)
	end
end

function drawMenuOptions(y)
	local curMenuOpts = nil
	if gs.menuSelection.page == 1 then
		curMenuOpts = menuOptions
	else
		curMenuOpts = menuOptions2
	end

	if gs.menuSelection.page == 1 then
		print("select your move", 6, y - 11)
	else
		print("predict your oppenent's move", 6, y - 11)
	end

	for i = 1, #curMenuOpts do
		local x = 10 + 40 * (i - 1)
		if gs.menuSelection.index == i then
			palt(0, false)
			spr(1, x - 6, y - 1)
		end
		print(curMenuOpts[i][1], x, y)
	end
	palt()
end

function _draw()
	cls()

	drawBoard()
	drawMenu()

	-- color(0)
	-- -- local gs2 = {pot = 3}
	-- -- print(gs2['pot'])
	-- print('human: ' .. gs.human, 0, 10)
	-- print('cpu:   ' .. gs.cpu, 0, 20)
	-- print('pot:   ' .. gs.pot, 0 , 30)
end

__gfx__
00000000777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000770777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700770077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000770007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000770077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700770777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000000300123101231012310133100c3100c3000c3000c3000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000f00000a0500b0500d0500e050120501405016050170501a0501d05020050230502605000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002b050230501e0501c050180501705015050110500e0500c05009050090500050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
001000001d050120501c0500b0501b05007050190500c0501a050110501a050140501a05010050190500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
