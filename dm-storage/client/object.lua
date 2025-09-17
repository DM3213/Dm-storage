local TARGET = (Config.DetectTarget and Config.DetectTarget()) or 'none'

---@type table<integer, any>
ObjectList = {}

local CurrentModel, CurrentObject, CurrentObjectKey, CurrentObjectName, CurrentSpawnRange, CurrentCoords = nil, nil, nil, nil, nil, nil

local function resolveModel(m)
  local orig = m
  if type(m) == 'string' and tonumber(m) then m = tonumber(m) end
  if type(m) == 'string' then m = joaat(m) end
  if type(m) ~= 'number' then
    if lib and lib.print and lib.print.error then lib.print.error(('model not number: %s (%s)'):format(tostring(orig), type(orig))) end
    return nil
  end
  return m
end

local function RequestSpawnObject(model)
  local hash = resolveModel(model); if not hash then return false end
  RequestModel(hash)
  local waited = 0
  while not HasModelLoaded(hash) do
    Wait(50); waited = waited + 50
    if waited > 10000 then
      if lib and lib.print and lib.print.error then lib.print.error(('Timeout loading model: %s'):format(tostring(model))) end
      return false
    end
  end
  return hash
end

local function CancelPlacement()
  if DoesEntityExist(CurrentObject) then DeleteObject(CurrentObject) end
  CurrentModel, CurrentObject, CurrentObjectKey, CurrentObjectName, CurrentSpawnRange, CurrentCoords = nil, nil, nil, nil, nil, nil
end

local function refreshObjects()
  local ok, inc = pcall(function()
    return lib.callback.await('dm-storage:server:RequestObjects', false)
  end)
  ObjectList = (ok and inc) or {}
end

AddEventHandler('onResourceStart', function(res) if GetCurrentResourceName() == res then refreshObjects() end end)
AddEventHandler('onResourceStop',  function(res)
  if GetCurrentResourceName() ~= res then return end
  for _, v in pairs(ObjectList) do
    if v.IsRendered then
      if v.targetHandle then
        if TARGET == 'ox_target' then pcall(function() exports.ox_target:removeLocalEntity(v.object) end)
        elseif TARGET == 'qb-target' then pcall(function() exports['qb-target']:RemoveTargetEntity(v.object) end) end
        v.targetHandle = nil
      end
      if DoesEntityExist(v.object) then DeleteObject(v.object) end
    end
  end
end)

local fw = Config.DetectFramework()
if fw == 'Qbox' then RegisterNetEvent('QBCore:Client:OnPlayerLoaded', refreshObjects)
elseif fw == 'QBCore' then RegisterNetEvent('QBCore:Client:OnPlayerLoaded', refreshObjects)
else AddEventHandler('esx:onPlayerSpawn', refreshObjects) end

local function StartMoveObject(v)
  if not v or not v.id then return end
  local cfg = Config.Objects[v.type] or {}
  local model = v.model or cfg.model
  local hash = RequestSpawnObject(model); if not hash then return end

  local ox, oy, oz, oh
  if v.IsRendered and v.object and DoesEntityExist(v.object) then
    local oc = GetEntityCoords(v.object)
    ox, oy, oz = oc.x, oc.y, oc.z
    oh = GetEntityHeading(v.object)
    DeleteObject(v.object)
    v.object = nil
    v.IsRendered = nil
  else
    local c = v.coords or vector4(0.0,0.0,0.0,0.0)
    ox, oy, oz, oh = c.x or 0.0, c.y or 0.0, c.z or 0.0, c.w or 0.0
  end

  local ghost = CreateObject(hash, ox, oy, oz, false, false, false)
  SetEntityHeading(ghost, oh or 0.0)
  if not DoesEntityExist(ghost) then if lib and lib.notify then lib.notify({type='error', description='Failed to create preview object'}) end; return end
  SetEntityAlpha(ghost, 150, false)
  SetEntityCollision(ghost, false, false)
  SetModelAsNoLongerNeeded(hash)

  if GetResourceState('object_gizmo') == 'started' then
    exports.object_gizmo:useGizmo(ghost)
    if lib and lib.notify then lib.notify({type='inform', description='Press [E] to confirm position, [Backspace] to cancel'}) end
    while true do
      if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then break end -- E
      if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 202) then DeleteObject(ghost); return end -- Backspace/Esc
      Wait(0)
    end
  else
    PlaceObjectOnGroundProperly(ghost)
    FreezeEntityPosition(ghost, true)
  end

  local c = GetEntityCoords(ghost)
  local h = GetEntityHeading(ghost)
  DeleteObject(ghost)
  v.coords = vector4(c.x, c.y, c.z, h or 0.0)
  TriggerServerEvent('dm-storage:server:MoveObject', v.id, v.coords)
end

local function StartPackObject(v)
  if not v or not v.id then return end
  TriggerServerEvent('dm-storage:server:PackUpObject', v.id)
end

local function OpenStorage(v)
  if not v or not v.id then return end
  TriggerServerEvent('dm-storage:server:OpenStorage', v.id)
end

local function attachTargets(object, v)
  if TARGET == 'ox_target' then
    exports.ox_target:addLocalEntity(object, {
      { label = 'Open Storage', icon = 'fa-solid fa-box-archive', onSelect = function() OpenStorage(v) end },
      { label = 'Manage Access', icon = 'fa-solid fa-user-group', onSelect = function() TriggerEvent('dm-storage:client:OpenAccessUI', v.id) end },
      { label = 'Move', icon = 'fa-solid fa-up-down-left-right', onSelect = function() StartMoveObject(v) end },
      { label = 'Pack Up', icon = 'fa-solid fa-box', onSelect = function() StartPackObject(v) end },
    })
    v.targetHandle = true
  elseif TARGET == 'qb-target' then
    exports['qb-target']:AddTargetEntity(object, { options = {
      { label = 'Open Storage', icon = 'fa-solid fa-box-archive', action = function() OpenStorage(v) end },
      { label = 'Manage Access', icon = 'fa-solid fa-user-group', action = function() TriggerEvent('dm-storage:client:OpenAccessUI', v.id) end },
      { label = 'Move', icon = 'fa-solid fa-up-down-left-right', action = function() StartMoveObject(v) end },
      { label = 'Pack Up', icon = 'fa-solid fa-box', action = function() StartPackObject(v) end },
    }, distance = 2.5 })
    v.targetHandle = true
  end
end

CreateThread(function()
  while true do
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    for _, v in pairs(ObjectList) do
      local objCoords = v.coords
      local cfg = Config.Objects[v.type] or {}
      local spawnRange = tonumber(cfg.spawnRange or 50) or 50.0
      local dist = #(playerCoords - vector3(objCoords.x, objCoords.y, objCoords.z))

      if dist < spawnRange and not v.IsRendered then
        local hash = RequestSpawnObject(v.model or cfg.model)
        if hash then
          local object = CreateObject(hash, objCoords.x, objCoords.y, objCoords.z, false, false, false)
          SetEntityHeading(object, objCoords.w or 0.0)
          SetEntityAlpha(object, 0, false)
          PlaceObjectOnGroundProperly(object)
          FreezeEntityPosition(object, true)

          v.IsRendered = true
          v.object = object

          for i = 0, 255, 51 do Wait(50) SetEntityAlpha(object, i, false) end

          attachTargets(object, v)
        end
      elseif dist >= spawnRange and v.IsRendered then
        if v.targetHandle then
          if TARGET == 'ox_target' then
            pcall(function() exports.ox_target:removeLocalEntity(v.object) end)
          elseif TARGET == 'qb-target' then
            pcall(function() exports['qb-target']:RemoveTargetEntity(v.object) end)
          end
          v.targetHandle = nil
        end
        if DoesEntityExist(v.object) then
          for i = 255, 0, -51 do Wait(50) SetEntityAlpha(v.object, i, false) end
          DeleteObject(v.object)
        end
        v.object, v.IsRendered = nil, nil
      end
    end

    Wait(1000)
  end
end)

RegisterNetEvent('dm-storage:client:OpenAccessUI', function(objectId)
  local data = lib.callback.await('dm-storage:server:GetAccess', false, objectId)
  if not data then return end
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'access:open', payload = { objectId = objectId, owner = data.owner, list = data.list } })
end)

RegisterNUICallback('storage:access:get', function(data, cb)
  local objectId = data and data.objectId
  local res = lib.callback.await('dm-storage:server:GetAccess', false, objectId)
  cb(res or { owner = '', list = {} })
end)

RegisterNUICallback('storage:access:add', function(data, cb)
  local objectId, target = data and data.objectId, data and data.target
  if not objectId or not target then return cb(0) end
  TriggerServerEvent('dm-storage:server:AddAccess', objectId, target)
  SetTimeout(150, function()
    local res = lib.callback.await('dm-storage:server:GetAccess', false, objectId)
    SendNUIMessage({ action = 'access:update', payload = res })
  end)
  cb(1)
end)

RegisterNUICallback('storage:access:remove', function(data, cb)
  local objectId, cid = data and data.objectId, data and data.cid
  if not objectId or not cid then return cb(0) end
  TriggerServerEvent('dm-storage:server:RemoveAccess', objectId, cid)
  SetTimeout(150, function()
    local res = lib.callback.await('dm-storage:server:GetAccess', false, objectId)
    SendNUIMessage({ action = 'access:update', payload = res })
  end)
  cb(1)
end)

RegisterNUICallback('storage:access:close', function(_, cb)
  SetNuiFocus(false, false)
  cb(1)
end)

RegisterNetEvent('dm-storage:client:FullSync', function(objects)
  ObjectList = objects or {}
end)

RegisterNetEvent('dm-storage:client:AddObject', function(object)
  if object and object.id then ObjectList[object.id] = object end
end)

RegisterNetEvent('dm-storage:client:receiveObjectDelete', function(id)
  local v = ObjectList[id]; if not v then return end
  if v.IsRendered then
    if v.targetHandle then
      if TARGET == 'ox_target' then pcall(function() exports.ox_target:removeLocalEntity(v.object) end)
      elseif TARGET == 'qb-target' then pcall(function() exports['qb-target']:RemoveTargetEntity(v.object) end) end
      v.targetHandle = nil
    end
    if DoesEntityExist(v.object) then
      for i = 255, 0, -51 do Wait(50) SetEntityAlpha(v.object, i, false) end
      DeleteObject(v.object)
    end
  end
  ObjectList[id] = nil
end)

RegisterNetEvent('dm-storage:client:ObjectMoved', function(id, coords)
  local v = ObjectList and ObjectList[id]
  if not v then return end
  v.coords = coords
  if v.IsRendered and v.object and DoesEntityExist(v.object) then
    FreezeEntityPosition(v.object, false)
    SetEntityCoordsNoOffset(v.object, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(v.object, coords.w or 0.0)
    PlaceObjectOnGroundProperly(v.object)
    FreezeEntityPosition(v.object, true)
  end
end)

RegisterNetEvent('dm-storage:client:PlaceObject', function(objectKey)
  local cfg = Config.Objects[objectKey]
  if not cfg then if lib and lib.notify then lib.notify({type='error', description='Invalid storage type'}) end; return end
  local model = cfg.model
  local hash = RequestSpawnObject(model); if not hash then return end

  CurrentModel, CurrentObjectKey, CurrentObjectName, CurrentSpawnRange = model, objectKey, (cfg.label or objectKey), cfg.spawnRange
  local ped = PlayerPedId()
  local offset = GetEntityCoords(ped) + GetEntityForwardVector(ped) * 3.0
  CurrentObject = CreateObject(hash, offset.x, offset.y, offset.z, false, false, false)
  if not DoesEntityExist(CurrentObject) then
    if lib and lib.notify then lib.notify({type='error', description='Failed to create preview object'}) end
    if CurrentObjectKey then TriggerServerEvent('dm-storage:server:RefundPlacementItem', CurrentObjectKey) end
    return CancelPlacement()
  end

  SetEntityAlpha(CurrentObject, 150, false)
  SetEntityCollision(CurrentObject, false, false)
  SetModelAsNoLongerNeeded(hash)

  if GetResourceState('object_gizmo') == 'started' then
    exports.object_gizmo:useGizmo(CurrentObject)
    if lib and lib.notify then lib.notify({type='inform', description='Press [E] to confirm position, [Backspace] to cancel'}) end
    while true do
      if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then break end -- E
      if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 202) then
        DeleteObject(CurrentObject)
        if CurrentObjectKey then TriggerServerEvent('dm-storage:server:RefundPlacementItem', CurrentObjectKey) end
        return CancelPlacement()
      end
      Wait(0)
    end
    CurrentCoords = GetEntityCoords(CurrentObject)
    local heading = GetEntityHeading(CurrentObject)
    DeleteObject(CurrentObject)
    TriggerServerEvent('dm-storage:server:CreateNewObject', CurrentModel, vector4(CurrentCoords.x, CurrentCoords.y, CurrentCoords.z, heading or 0.0), CurrentObjectKey, { SpawnRange = CurrentSpawnRange }, CurrentObjectName)
    CancelPlacement()
  else
    PlaceObjectOnGroundProperly(CurrentObject)
    FreezeEntityPosition(CurrentObject, true)
    CurrentCoords = GetEntityCoords(CurrentObject)
    local heading = GetEntityHeading(CurrentObject)
    DeleteObject(CurrentObject)
    TriggerServerEvent('dm-storage:server:CreateNewObject', CurrentModel, vector4(CurrentCoords.x, CurrentCoords.y, CurrentCoords.z, heading or 0.0), CurrentObjectKey, { SpawnRange = CurrentSpawnRange }, CurrentObjectName)
    CancelPlacement()
  end
end)
