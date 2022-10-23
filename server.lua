
local COMMAND_NAME = "stepeffect"

GlobalState.StepEffectIds = {}

RegisterCommand(COMMAND_NAME, function(src, args, raw)
	ToggleEffect(src)
end, false)

function ToggleEffect(playerId)
	local ids = GlobalState.StepEffectIds
	if (ids[playerId]) then
		ids[playerId] = nil
	else
		ids[playerId] = true
	end
	GlobalState.StepEffectIds = ids

	Player(playerId).state.StepEffect = not Player(playerId).state.StepEffect
end

AddEventHandler("playerDropped", function(reason)
	local ids = GlobalState.StepEffectIds
	ids[source] = nil
	GlobalState.StepEffectIds = ids
end)
