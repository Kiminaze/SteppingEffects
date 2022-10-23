
local DEBUG = false
local LIGHT_RANGE = 1.5
local EASE_TIME = 800
local STAY_TIME = 0
local EASE_IN_COLOR = { 255, 183, 76 }
local EASE_OUT_COLOR = { 0, 51, 0 }

local DIST_TO_GROUND = 0.15

local models = {
	`prop_plant_01b`,
	`prop_plant_fern_01a`,
	`prop_plant_fern_01b`
}

LocalPlayer.state.StepEffect = false

local leftFootOnGroundLastFrame = {}
local rightFootOnGroundLastFrame = {}

Citizen.CreateThread(function()
	for i, model in ipairs(models) do
		if (not HasModelLoaded(model)) then
			RequestModel(model)
		end
	end

	while (true) do
		Citizen.Wait(50)

		for id, _ in pairs(GlobalState.StepEffectIds) do
			local ped = GetPlayerPed(GetPlayerFromServerId(id))

			if (ped ~= PlayerPedId()) then
				CheckFeetOnGround(ped, id)
			end
		end

		if (LocalPlayer.state.StepEffect) then
			CheckFeetOnGround(PlayerPedId(), -1)
		end
	end
end)

function CheckFeetOnGround(ped, id)
	local leftFootOnGround, position = IsFootOnGround(ped, true)
	if (not leftFootOnGroundLastFrame[id] and leftFootOnGround) then
		-- left foot touch ground
		CreateLocalObjects(ped, models, position)

		leftFootOnGroundLastFrame[id] = true
	elseif (leftFootOnGroundLastFrame[id] and not leftFootOnGround) then
		-- left foot lifted

		leftFootOnGroundLastFrame[id] = false
	end

	local rightFootOnGround, position = IsFootOnGround(ped, false)
	if (not rightFootOnGroundLastFrame[id] and rightFootOnGround) then
		-- right foot touch ground
		CreateLocalObjects(ped, models, position)

		rightFootOnGroundLastFrame[id] = true
	elseif (rightFootOnGroundLastFrame[id] and not rightFootOnGround) then
		-- right foot lifted

		rightFootOnGroundLastFrame[id] = false
	end
end



function CreateLocalObjects(ped, models, position)
	Citizen.CreateThread(function()
		local objects = {}

		-- spawn
		local forward = GetEntityMatrix(ped)
		for i, model in ipairs(models) do
			local pos = position + vector3(GetRandomNumber() * 0.2, GetRandomNumber() * 0.2, -0.8) + forward * 0.3
			local obj = CreateObjectNoOffset(model, pos, false, false)
			FreezeEntityPosition(obj, true)
			SetEntityCollision(obj, false, false)
			SetEntityRotation(obj, GetRandomNumber() * 20.0, GetRandomNumber() * 20.0, GetRandomNumber() * 180.0, 2)

			table.insert(objects, { obj, pos })
		end

		-- ease in
		local timer = GetGameTimer()
		while (GetGameTimer() - timer < EASE_TIME) do
			local mult = (GetGameTimer() - timer) / EASE_TIME

			for j, obj in ipairs(objects) do
				SetEntityCoords(obj[1], obj[2] + vector3(0.0, 0.0, SmoothEaseIn(0.0, 0.6, mult)))
			end

			local r, g, b = ColorTransition(EASE_IN_COLOR, EASE_OUT_COLOR, mult * 0.5)
			DrawLightWithRange(position, r, g, b, LIGHT_RANGE, mult)

			Citizen.Wait(0)
		end

		-- stay
		timer = GetGameTimer()
		while (GetGameTimer() - timer < STAY_TIME) do
			DrawLightWithRange(position, EASE_IN_COLOR[1], EASE_IN_COLOR[2], EASE_IN_COLOR[3], LIGHT_RANGE, 1.0)
		
			Citizen.Wait(0)
		end

		-- ease out
		timer = GetGameTimer()
		while (GetGameTimer() - timer < EASE_TIME) do
			local mult = (GetGameTimer() - timer) / EASE_TIME

			for j, obj in ipairs(objects) do
				SetEntityCoords(obj[1], obj[2] + vector3(0.0, 0.0, SmoothEaseOut(0.0, 0.6, mult)))
			end

			local r, g, b = ColorTransition(EASE_IN_COLOR, EASE_OUT_COLOR, 0.5 + mult * 0.5)
			DrawLightWithRange(position, r, g, b, LIGHT_RANGE, 1.0 - mult)

			Citizen.Wait(0)
		end

		-- delete
		for j, obj in ipairs(objects) do
			DeleteEntity(obj[1])
		end
	end)
end

function IsFootOnGround(ped, isLeft)
	local position = GetWorldPositionOfEntityBone(ped, GetPedBoneIndex(ped, isLeft and 14201 or 52301))

	local found, groundZ, normal = GetGroundZFor_3dCoord(position.x, position.y, position.z)
	if (not found or math.abs(groundZ - position.z) > DIST_TO_GROUND) then
		return false, position
	end

	return true, position
end

function GetRandomNumber()
	return math.random() * 2.0 - 1.0
end

function SmoothEaseIn(a, b, t)
	return a + math.sin(t * 1.57) * (b - a)
end

function SmoothEaseOut(a, b, t)
	return a + math.cos(t * 1.57) * (b - a)
end

function ColorTransition(a, b, t)
	return 
		math.floor(a[1] + t * (b[1] - a[1])),
		math.floor(a[2] + t * (b[2] - a[2])),
		math.floor(a[3] + t * (b[3] - a[3]))
end



if (DEBUG) then
	local VECTOR_ONE = vector3(1.0, 1.0, 1.0)

	Citizen.CreateThread(function()
		while (true) do
			Citizen.Wait(0)

			for i, obj in ipairs(GetObjectsInRadius(GetEntityCoords(PlayerPedId()), 10.0)) do
				DrawDebugLines(obj)
			end

			for i, id in ipairs(GetActivePlayers()) do
				DrawDebugMarker(GetPlayerPed(id))
			end
		end
	end)

	function DrawDebugMarker(ped)
		local onGround, position = IsFootOnGround(ped, true)
		DrawMarker(
			28, 
			position, VECTOR_ONE * 0, VECTOR_ONE * 0, VECTOR_ONE * 0.2, 
			onGround and 0 or 255, onGround and 255 or 0, 0, 100, 
			false, false, 2
		)

		onGround, position = IsFootOnGround(ped, false)
		DrawMarker(
			28, 
			position, VECTOR_ONE * 0, VECTOR_ONE * 0, VECTOR_ONE * 0.2, 
			onGround and 0 or 255, onGround and 255 or 0, 0, 100, 
			false, false, 2
		)
	end

	function DrawDebugLines(entity)
		local min, max = GetModelDimensions(GetEntityModel(entity))
		local position = GetEntityCoords(entity)

		local points = {
			LocalToWorld(entity, min),
			LocalToWorld(entity, vector3(max.x, min.y, min.z)),
			LocalToWorld(entity, vector3(max.x, max.y, min.z)),
			LocalToWorld(entity, vector3(min.x, max.y, min.z)),
			LocalToWorld(entity, max),
			LocalToWorld(entity, vector3(min.x, max.y, max.z)),
			LocalToWorld(entity, vector3(min.x, min.y, max.z)),
			LocalToWorld(entity, vector3(max.x, min.y, max.z)),
		}

		DrawLine(points[1], points[2], 255, 255, 255, 255)
		DrawLine(points[2], points[3], 255, 255, 255, 255)
		DrawLine(points[3], points[4], 255, 255, 255, 255)
		DrawLine(points[4], points[1], 255, 255, 255, 255)

		DrawLine(points[5], points[6], 255, 255, 255, 255)
		DrawLine(points[6], points[7], 255, 255, 255, 255)
		DrawLine(points[7], points[8], 255, 255, 255, 255)
		DrawLine(points[8], points[5], 255, 255, 255, 255)

		DrawLine(points[1], points[7], 255, 255, 255, 255)
		DrawLine(points[2], points[8], 255, 255, 255, 255)
		DrawLine(points[3], points[5], 255, 255, 255, 255)
		DrawLine(points[4], points[6], 255, 255, 255, 255)
	end

	function LocalToWorld(entity, localPosition)
		return GetOffsetFromEntityInWorldCoords(entity, localPosition)
	end

	function IsModelInList(model)
		for i, m in ipairs(models) do
			if (model == m) then
				return true
			end
		end

		return false
	end

	function GetObjectsInRadius(position, radius)
		local objects = {}

		for i, obj in ipairs(GetGamePool("CObject")) do
			if (IsModelInList(GetEntityModel(obj)) and #(GetEntityCoords(obj) - position) <= radius) then
				table.insert(objects, obj)
			end
		end

		return objects
	end
end
