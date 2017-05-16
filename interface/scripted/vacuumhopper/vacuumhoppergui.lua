function init()
	script.setUpdateDelta(60)
end

function update(dt)
end

function switchDirection()
	world.sendEntityMessage(pane.containerEntityId(), "switchDirection")
end