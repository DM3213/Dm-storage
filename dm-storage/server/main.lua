local FRAMEWORK = Config.DetectFramework()
local INVENTORY = Config.DetectInventory()

local QBCore = (FRAMEWORK == 'QBCore' or FRAMEWORK == 'Qbox') and rawget(_G, 'QBCore') or nil
local ESX    = (FRAMEWORK == 'ESX') and rawget(_G, 'ESX') or nil

---@type table<integer, {id:number, model:string|number, coords:vector4, type:'small'|'medium'|'large', name:string, owner:string}>
local ServerObjects = {}

local RegisteredStashes = {}

local PendingPlacement = {}

 
local function ensureOptions(obj)
    obj.options = obj.options or {}
    obj.options.access = obj.options.access or {}
end

local function persistOptions(obj)
    if not obj or not obj.id then return end
    MySQL.query.await('UPDATE Dm_storage SET options = ? WHERE id = ?', { json.encode(obj.options or {}), obj.id })
end

local function Notify(src, msg, type)
    type = type or 'inform'
    if GetResourceState('ox_lib') == 'started' then
        TriggerClientEvent('ox_lib:notify', src, { description = msg, type = type })
    else
        TriggerClientEvent('chat:addMessage', src, { args = { '^3Storage', msg } })
    end
end

local function GetPlayer(src)
    if FRAMEWORK == 'QBCore' then
        return QBCore and QBCore.Functions.GetPlayer(src) or nil
    elseif FRAMEWORK == 'Qbox' then
        return exports.qbx_core:GetPlayer(src)
    elseif FRAMEWORK == 'ESX' then
        return ESX and ESX.GetPlayerFromId(src) or nil
    end
    return nil
end

local function GetPlayerCID(src)
    if FRAMEWORK == 'QBCore' or FRAMEWORK == 'Qbox' then
        local p = GetPlayer(src)
        return p and p.PlayerData and (p.PlayerData.citizenid or p.PlayerData.license) or ('cid:'..src)
    elseif FRAMEWORK == 'ESX' then
        local xP = GetPlayer(src)
        return (xP and xP.identifier) or ('cid:'..src)
    end
    local lic = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, 'license') or nil
    return lic or ('cid:'..src)
end

local function toPascal(s) s = s:gsub('^%l', string.upper); return s:gsub('_(%l)', function(c) return c:upper() end) end

CreateThread(function()
    local results = MySQL.query.await('SELECT * FROM Dm_storage', {})
    for _, v in pairs(results or {}) do
        local row = {
            id = v.id,
            model = v.model,
            coords = json.decode(v.coords),
            type = v.type,
            name = v.name or '',
            owner = v.owner,
            options = json.decode(v.options or '{}') or {},
        }
        ensureOptions(row)
        ServerObjects[row.id] = row
    end
end)

lib.callback.register('dm-storage:server:RequestObjects', function(_) return ServerObjects end)

RegisterNetEvent('dm-storage:server:CreateNewObject', function(model, coords, objecttype, options, objectname)
    local src = source
    if not (model and coords and objecttype) then return end
    if not Config.Objects[objecttype] then return end

    local data = MySQL.query.await([[INSERT INTO Dm_storage (model, coords, type, options, name, owner)
        VALUES (?, ?, ?, ?, ?, ?) ]],
        { model, json.encode(coords), objecttype, json.encode(options or {}), objectname or '', GetPlayerCID(src) })
    if not data or not data.insertId then return end

    local row = { id = data.insertId, model = model, coords = coords, type = objecttype, name = objectname or '', owner = GetPlayerCID(src), options = options or {} }
    ensureOptions(row)
    persistOptions(row)
    ServerObjects[row.id] = row
    TriggerClientEvent('dm-storage:client:AddObject', -1, row)

    PendingPlacement[src] = nil
end)

RegisterNetEvent('dm-storage:server:DeleteObject', function(objectid, ownerCidFromClient)
    local src = source
    if not objectid or objectid <= 0 then return end
    local obj = ServerObjects[objectid]; if not obj then return end

    local allowed = (GetPlayerCID(src) == ownerCidFromClient)
    local p = GetPlayer(src)
    if p and p.PlayerData and p.PlayerData.job and p.PlayerData.job.name == 'police' then allowed = true end
    if not allowed then return end

    MySQL.query.await('DELETE FROM Dm_storage WHERE id = ?', {objectid})
    ServerObjects[objectid] = nil
    TriggerClientEvent('dm-storage:client:receiveObjectDelete', -1, objectid)

    local cfg = Config.Objects[obj.type]
    if cfg and cfg.item and GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:AddItem(src, cfg.item, 1)
        Notify(src, ("You packed up the %s."):format(cfg.label or obj.type), 'inform')
    end
end)

RegisterNetEvent('dm-storage:server:MoveObject', function(objectId, coords)
    local src = source
    local obj = ServerObjects[objectId]; if not obj then return end
    local allowed = (GetPlayerCID(src) == obj.owner)
    local p = GetPlayer(src)
    if p and p.PlayerData and p.PlayerData.job and p.PlayerData.job.name == 'police' then allowed = true end
    if not allowed then return end

    obj.coords = coords
    MySQL.query.await('UPDATE Dm_storage SET coords=? WHERE id=?', { json.encode(coords), objectId })
    TriggerClientEvent('dm-storage:client:ObjectMoved', -1, objectId, coords)
end)

RegisterNetEvent('dm-storage:server:PackUpObject', function(objectId)
    local src = source
    local obj = ServerObjects[objectId]; if not obj then return end
    local allowed = (GetPlayerCID(src) == obj.owner)
    local p = GetPlayer(src)
    if p and p.PlayerData and p.PlayerData.job and p.PlayerData.job.name == 'police' then allowed = true end
    if not allowed then return end

    MySQL.query.await('DELETE FROM Dm_storage WHERE id = ?', {objectId})
    ServerObjects[objectId] = nil
    TriggerClientEvent('dm-storage:client:receiveObjectDelete', -1, objectId)

    local cfg = Config.Objects[obj.type]
    if cfg and cfg.item and GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:AddItem(src, cfg.item, 1)
        Notify(src, ("You packed up the %s."):format(cfg.label or obj.type), 'inform')
    end
end)

local function ensureStash(id, label, slots, weight)
    if RegisteredStashes[id] then return end
    exports.ox_inventory:RegisterStash(id, label, slots, weight, false)
    RegisteredStashes[id] = true
end

local function isAllowedToOpen(src, obj)
    if not obj then return false end
    local cid = GetPlayerCID(src)
    if cid == obj.owner then return true end
    ensureOptions(obj)
    return obj.options.access and obj.options.access[cid] == true
end

RegisterNetEvent('dm-storage:server:OpenStorage', function(objectId)
    local src = source
    local obj = ServerObjects[objectId]; if not obj then return end
    local cfg = Config.Objects[obj.type] or {}
    if GetResourceState('ox_inventory') ~= 'started' then return Notify(src, 'Inventory not found', 'error') end

    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return end
    local pc = GetEntityCoords(ped)
    local oc = obj.coords; local dist = #(pc - vector3(oc.x, oc.y, oc.z))
    if dist > 5.0 then return end

    local stashId = (Config.Storage and Config.Storage.StashPrefix or 'storage_') .. tostring(objectId)
    local label = (cfg.label or 'Storage') .. ' #' .. tostring(objectId)
    local slots = tonumber(cfg.slots or 20) or 20
    local weight= tonumber(cfg.weight or 1000) or 1000

    local coords3 = vector3(obj.coords.x, obj.coords.y, obj.coords.z)
    exports.ox_inventory:RegisterStash(stashId, label, slots, weight, obj.owner, nil, coords3)
    RegisteredStashes[stashId] = true

    if not isAllowedToOpen(src, obj) then return Notify(src, 'You do not have access to this storage.', 'error') end

    exports.ox_inventory:forceOpenInventory(src, 'stash', { id = stashId })
end)

local function registerUseExport(itemName, objectKey)
    local exportName = 'use' .. toPascal(itemName)
    exports(exportName, function(event, item, inventory, slot, data)
        if event == 'usingItem' then
            local src = (inventory and inventory.id) or source
            PendingPlacement[src] = objectKey
            TriggerClientEvent('dm-storage:client:PlaceObject', src, objectKey)
        end
    end)
end

for key, cfg in pairs(Config.Objects or {}) do
    if cfg.item then registerUseExport(cfg.item, key) end
end

lib.callback.register('dm-storage:server:GetAccess', function(src, objectId)
    local obj = ServerObjects[objectId]; if not obj then return nil end
    local list = {}
    ensureOptions(obj)
    for cid, allowed in pairs(obj.options.access or {}) do
        if allowed then list[#list+1] = cid end
    end
    table.sort(list)
    return { owner = obj.owner, list = list }
end)

RegisterNetEvent('dm-storage:server:RefundPlacementItem', function(objectKey)
    local src = source
    if type(objectKey) ~= 'string' then return end
    if PendingPlacement[src] ~= objectKey then return end
    local cfg = Config.Objects[objectKey]
    if not cfg or not cfg.item then PendingPlacement[src] = nil; return end
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:AddItem(src, cfg.item, 1)
        Notify(src, ("Placement cancelled. %s returned to your inventory."):format(cfg.label or objectKey), 'inform')
    end
    PendingPlacement[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    if src then PendingPlacement[src] = nil end
end)

RegisterNetEvent('dm-storage:server:AddAccess', function(objectId, target)
    local src = source
    local obj = ServerObjects[objectId]; if not obj then return end
    if GetPlayerCID(src) ~= obj.owner then return end
    ensureOptions(obj)
    local cid
    if type(target) == 'number' then
        cid = GetPlayerCID(target)
    elseif type(target) == 'string' then
        if tonumber(target) then cid = GetPlayerCID(tonumber(target)) else cid = target end
    end
    if not cid or cid == obj.owner then return end
    obj.options.access[cid] = true
    persistOptions(obj)
    Notify(src, ('Access granted to %s.'):format(cid), 'success')
end)

RegisterNetEvent('dm-storage:server:RemoveAccess', function(objectId, targetCid)
    local src = source
    local obj = ServerObjects[objectId]; if not obj then return end
    if GetPlayerCID(src) ~= obj.owner then return end
    ensureOptions(obj)
    if type(targetCid) ~= 'string' then return end
    obj.options.access[targetCid] = nil
    persistOptions(obj)
    Notify(src, ('Access removed for %s.'):format(targetCid), 'inform')
end)
