local debug = true

--- Object init event.
-- Gets executed when this object is placed.
-- @param virtual if this is a virtual call?
function init(virtual)
	if virtual then return end

	-- 0 left, 1 right, 2 top, 3 bottom
	storage.settings = {}
	if config.getParameter("facing") == nil then
		storage.settings.direction = object.direction() == 1 and 0 or 1
	else
		storage.settings.direction = config.getParameter("facing")
	end
	storage.accumulatedTimer = 0

	object.setInteractive(true)

	message.setHandler("switchDirection", onDirectionSwitch)
end

function containerCallback()
	-- Reject everything here that is not the appropriated upgrade.
	local stackUpgradeItem = world.containerItemAt(entity.id(), 1)
	if stackUpgradeItem ~= nil and stackUpgradeItem["name"] ~= "stackupgrade" then
		if world.containerConsume(entity.id(), stackUpgradeItem) then
			if world.spawnItem(stackUpgradeItem, entity.position()) == nil then
				-- Add the item back in in case it failed to spawn
				world.containerAddItems(entity.id(), stackUpgradeItem)
			end
		end
	end
end

--- Object node connection change event.
-- Gets executed when this object node connections changes
-- Input and Output nodes are connected / disconnected.
function onNodeConnectionChange()
end

--- Object node input change event.
-- Gets executed when the node input changed.
-- @param args a table containing the node and level args["node"], args["level"]
function onInputNodeChange(args)
	if args["level"] then
		local pos = entity.position()
		if storage.settings.direction == 1 then -- right
			pos[1] = pos[1] - 2
		elseif storage.settings.direction == 0 then -- left
			pos[1] = pos[1] + 2
		elseif storage.settings.direction == 2 then -- top
			pos[2] = pos[2] - 2
		elseif storage.settings.direction == 3 then -- bottom
			pos[2] = pos[2] + 2
		end
		tryDroppingBuffer(pos)
	end
end

--- Object update event
-- Gets executed when this object updates.
-- @param dt delta time, time is specified in *.object as scriptDelta (60 = 1 second)
function update(dt)
	syncAnimation()

	storage.accumulatedTimer = storage.accumulatedTimer + 1

	local speed = 2
	local speedUpgradeItem = world.containerItemAt(entity.id(), 1)
	if speedUpgradeItem ~= nil then
		speed = 1
	end

	if storage.accumulatedTimer >= speed then -- Move 1 item each 3 seconds
		local pos = entity.position()
		if storage.settings.direction == 1 then -- right
			pos[1] = pos[1] - 2
		elseif storage.settings.direction == 0 then -- left
			pos[1] = pos[1] + 2
		elseif storage.settings.direction == 2 then -- top
			pos[2] = pos[2] + 2
		elseif storage.settings.direction == 3 then -- bottom
			pos[2] = pos[2] - 2
		end
		tryTakingFirstItem(pos)

		storage.accumulatedTimer = 0
	end
end

-- Custom functions here

function debugOut(str)
	if not debug then return end
	sb.logInfo(str)
end

-- TODO: Maybe add a wrench item?
function onDirectionSwitch(_, _)
	-- 0 left, 1 right, 2 top, 3 bottom
	if storage.settings.direction < 3 then
		storage.settings.direction = storage.settings.direction + 1
	else
		storage.settings.direction = 0
	end
	object.setConfigParameter("facing", storage.settings.direction)

	syncAnimation()
end

function syncAnimation()
	if storage.settings.direction == 1 then
		animator.setAnimationState("switchState", "right")
	elseif storage.settings.direction == 0 then
		animator.setAnimationState("switchState", "left")
	elseif storage.settings.direction == 2 then
		animator.setAnimationState("switchState", "top")
	elseif storage.settings.direction == 3 then
		animator.setAnimationState("switchState", "bottom")
	end
end

-- @return bool true if valid container, false otherwise
function validateContainer(position)
	if not world.tileIsOccupied(position, true) then return false end -- Has a tile at the position

	local entityId = world.objectAt(position)
	if entityId == nil then return false end -- Is there an object?

	local containerSize = world.containerSize(entityId)
	if containerSize == nil then return false end -- Is container

	return true
end

-- Weird hack for JSONArray. Dunno how else I'd get the length
function getJSONLength(items)
	local i = 0
	for key, value in pairs(items) do
		i = i + 1
	end
	return i
end

function getFirstItem(items)
	for key, value in pairs(items) do
		return value
	end
end

function tryTakingFirstItem(position)
	if not validateContainer(position) then debugOut("Invalid container") return false end -- Invalid container

	local entityId = world.objectAt(position)
	
	local allItems = world.containerItems(entityId)
	if getJSONLength(allItems) <= 0 then return false end -- Has items (I dunno why it ever would be < 0 :D)

	local firstItem = getFirstItem(allItems)
	if firstItem == nil then return false end -- Just sanity checking?

	local bufferedItem = world.containerItemAt(entity.id(), 0)
	if bufferedItem ~= nil and firstItem["name"] ~= bufferedItem["name"] then return false end

	local numItemsToSuck = 1
	local stackUpgradeItem = world.containerItemAt(entity.id(), 2)
	if stackUpgradeItem ~= nil then
		numItemsToSuck = 125
	end
	pushItem(firstItem, entityId, entity.id(), numItemsToSuck)
end

--- Pushes an item into a container
-- @param itemToPush The item to push
-- @param fromEntityId The entityId where we take the item from
-- @param toEntityId The entityId where we place the item in
-- @param maxCount OPTIONAL The maximum amount that we should take
-- @return bool true if successful, false otherwise -- TODO
function pushItem(itemToPush, fromEntityId, toEntityId, maxCount)
	if itemToPush == nil or itemToPush["count"] == nil or itemToPush["count"] <= 0 then return end -- Don't push invalid items.

	local fitItem = world.containerItemsCanFit(toEntityId, itemToPush)
	if fitItem == nil or fitItem <= 0 then return false end -- Can the item fit in the container? (I dunno why it ever would be < 0 :D)

	if maxCount ~= nil and type(maxCount) == "number" then
		if fitItem > maxCount then
			fitItem = maxCount
		end
	end
	itemToPush["count"] = fitItem -- Only move how many are fitting in the inventory.

	if world.containerConsume(fromEntityId, itemToPush) then
		world.containerPutItemsAt(toEntityId, itemToPush, 0)
	end
end

function tryDroppingBuffer(pos)
	if world.containerItemAt(entity.id(), 0) == nil then return false end

	local numItemsToDrop = 1
	local stackUpgradeItem = world.containerItemAt(entity.id(), 1)
	if stackUpgradeItem ~= nil then
		numItemsToDrop = 125
	end

	local itemToDrop = world.containerItemAt(entity.id(), 0)
	itemToDrop["count"] = numItemsToDrop
	if world.containerConsume(entity.id(), itemToDrop) then
		world.spawnItem(itemToDrop, pos)
	end
end