TransportAPI = {}

-- @return entityId/bool entityId if valid container, false otherwise
local function validateContainerAtPos(position)
	if not world.tileIsOccupied(position, true) then return false end -- Has a tile at the position

	local entityId = world.objectAt(position)
	if entityId == nil then return false end -- Is there an object?

	local containerSize = world.containerSize(entityId)
	if containerSize == nil then return false end -- Is container

	return entityId
end

local function getJSONLength(items)
	local i = 0
	for key, value in pairs(items) do
		i = i + 1
	end
	return i
end

local function getFirstItem(items)
	for key, value in pairs(items) do
		return value
	end
	return nil
end

local function hasSlot(slots, slot)
	for key, value in pairs(slots) do
		if value == slot then
			return true
		end
	end
	return false
end

--- Assumes container entityId is a container.
-- @return ItemDescriptor/bool The item that it found, false if there is no item
local function getFirstItemInContainer(containerEntityId)	
	local allItems = world.containerItems(containerEntityId)
	if getJSONLength(allItems) <= 0 then return false end -- Has items (I dunno why it ever would be < 0 :D)

	local firstItem = getFirstItem(allItems)
	if firstItem == nil then return false end -- Just sanity checking?

	return firstItem
end

--- Initialization function for the transport API
-- @param inputLocations A 2-d table of positions (1 = Left, 2 = right, 3 = bottom, 4 = top) can be nil
-- @param outputLocations A 2-d table of positions (1 = Left, 2 = right, 3 = bottom, 4 = top) can be nil
function TransportAPI.init(inputLocations, outputLocations)
	if config.getParameter("facing") == nil then
		object.setConfigParameter("facing", object.direction() == -1 and 1 or 2)
	end	

	object.setConfigParameter("inputLocations", inputLocations)
	object.setConfigParameter("outputLocations", outputLocations)
end

--- Inserts the item in the container that is in the output location
-- Does fit checking. WARNING: Does not remove the item from somewhere!
-- @param outputItem The item that should be inserted into the container
-- @return bool/ItemDescriptor true if successful, false otherwise, ItemDescriptor if there are leftovers
function TransportAPI.outputItem(outputItem, containerEntityId)
	local outputLocations = config.getParameter("outputLocations")

	if outputLocations == nil or #outputLocations < 4 then
		sb.logError("TransportAPI: outputItem called but object (%s) doesn't have outputLocations defined (%s)!", sb.print(object.name()), sb.print(outputLocations))
		return false
	end
	
	local objectPos = object.position()
	local facing = config.getParameter("facing") or 1
	local outputPos = { objectPos[1] + outputLocations[facing][1], objectPos[2] + outputLocations[facing][2]}

	local containerEntityId = validateContainerAtPos(outputPos)
	if not containerEntityId then return false end

	if outputItem == nil or outputItem["count"] == nil or outputItem["count"] <= 0 then return end -- Don't push invalid items.

	local fitItem = world.containerItemsCanFit(containerEntityId, outputItem)
	if fitItem == nil or fitItem <= 0 then return false end -- Can the item fit in the container? (I dunno why it ever would be < 0 :D)
	if fitItem < outputItem["count"] then
		outputItem["count"] = fitItem
	end

	--outputItem["count"] = fitItem -- Only move how many are fitting in the inventory.

	local leftOver = world.containerAddItems(containerEntityId, outputItem)
	if leftOver == nil or leftOver["count"] == 0 then
		return true
	else
		return leftOver
	end
end

function TransportAPI.outputContent(slot, maxItemCount)
	local outputLocations = config.getParameter("outputLocations")

	if outputLocations == nil or #outputLocations < 4 then
		sb.logError("TransportAPI: outputContent called but object (%s) doesn't have outputLocations defined (%s)!", sb.print(object.name()), sb.print(outputLocations))
		return false
	end
	
	local objectPos = object.position()
	local facing = config.getParameter("facing") or 1
	local outputPos = { objectPos[1] + outputLocations[facing][1], objectPos[2] + outputLocations[facing][2]}

	local containerEntityId = validateContainerAtPos(outputPos)
	if not containerEntityId then return false end

	local firstItem = nil
	if slot == nil then
		firstItem = getFirstItemInContainer(entity.id())
	else
		firstItem = world.containerItemAt(entity.id(), slot)
	end
	if firstItem == false or firstItem == nil or firstItem["count"] == nil or firstItem["count"] <= 0 then return end -- Don't push invalid items.

	local fitItem = world.containerItemsCanFit(containerEntityId, firstItem)
	if fitItem == nil or fitItem <= 0 then return false end -- Can the item fit in the container? (I dunno why it ever would be < 0 :D)
	if maxItemCount ~= nil and fitItem > maxItemCount then
		fitItem = maxItemCount
	end
	if fitItem < firstItem["count"] then
		firstItem["count"] = fitItem
	end

	local leftOver = world.containerAddItems(containerEntityId, firstItem)
	if leftOver == nil or leftOver["count"] == 0 then
		-- TODO: remove items if consume was unsuccessful
		return world.containerConsume(entity.id(), firstItem)
		--return true
	elseif leftOver["count"] < firstItem["count"] then
		leftOver["count"] = firstItem["count"] - leftOver["count"]
		return world.containerConsume(entity.id(), leftOver)
	else
		return leftOver
	end
end

--- Inserts an item from the container that is in the input location
-- Does fit checking.
-- @param outputItem (OPTIONAL) The item that should be inserted into the container
-- @return bool/ItemDescriptor true if successful, false otherwise, ItemDescriptor if there are leftovers
function TransportAPI.inputItem(slot, maxItemCount)
	local inputLocations = config.getParameter("inputLocations")

	if inputLocations == nil or #inputLocations < 4 then
		sb.logError("TransportAPI: inputItem called but object (%s) doesn't have inputLocations defined (%s)!", sb.print(object.name()), sb.print(inputLocations))
		return false
	end

	local objectPos = object.position()
	local facing = config.getParameter("facing") or 1
	local inputPos = { objectPos[1] + inputLocations[facing][1], objectPos[2] + inputLocations[facing][2]}

	local containerEntityId = validateContainerAtPos(inputPos)
	if not containerEntityId then return false end

	local firstItem = getFirstItemInContainer(containerEntityId)
	if not firstItem then return false end

	if firstItem == nil or firstItem["count"] == nil or firstItem["count"] <= 0 then return end -- Don't push invalid items.

	local fitItem = world.containerItemsCanFit(entity.id(), firstItem)
	if fitItem == nil or fitItem <= 0 then return false end -- Can the item fit in the container? (I dunno why it ever would be < 0 :D)
	if maxItemCount ~= nil and fitItem > maxItemCount then
		fitItem = maxItemCount
	end
	if fitItem < firstItem["count"] then
		firstItem["count"] = fitItem
	end

	local leftOver = nil
	if slot ~= nil then
		local fitWhere = world.containerItemsFitWhere(entity.id(), firstItem) 
		--sb.logInfo("%s", sb.print(fitWhere))
		if fitWhere == nil or not hasSlot(fitWhere["slots"], slot) then return end -- Check if the item fits in target slot.
		fitItem = fitWhere["leftover"]

		leftOver = world.containerPutItemsAt(entity.id(), firstItem, slot)
	else
		leftOver = world.containerAddItems(entity.id(), firstItem)
	end

	if leftOver == nil or leftOver["count"] == 0 then
		-- TODO: remove items if consume was unsuccessful
		return world.containerConsume(containerEntityId, firstItem)
		--return true
	elseif leftOver["count"] <= firstItem["count"] then
		leftOver["count"] = firstItem["count"] - leftOver["count"]
		return world.containerConsume(containerEntityId, leftOver)
	else
		return leftOver
	end
end

function TransportAPI.update(dt)
	local objectPos = object.position()
	local facing = config.getParameter("facing") or 1

	local outputLocations = config.getParameter("outputLocations")
	if outputLocations ~= nil and outputLocations[facing] ~= nil then
		world.debugPoint({ objectPos[1] + outputLocations[facing][1], objectPos[2] + outputLocations[facing][2]}, "#FFFF00")
		world.debugText("Output", { objectPos[1] + outputLocations[facing][1], objectPos[2] + outputLocations[facing][2]}, "#FFFF00")
	end

	local inputLocations = config.getParameter("inputLocations")
	if inputLocations ~= nil and inputLocations[facing] ~= nil  then
		world.debugPoint({ objectPos[1] + inputLocations[facing][1], objectPos[2] + inputLocations[facing][2]}, "#00FF00")
		world.debugText("Input", { objectPos[1] + inputLocations[facing][1], objectPos[2] + inputLocations[facing][2]}, "#00FF00")
	end
end