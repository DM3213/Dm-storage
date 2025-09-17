Config = Config or {}

-- Auto-detect by default; you can force any value: 'QBCore' | 'ESX' | 'Qbox' | 'standalone'
Config.Framework = Config.Framework or 'auto'

-- Inventories: 'ox_inventory' | 'qb' | 'qs' | 'ps' | 'auto'
Config.Inventory  = Config.Inventory or 'auto'

-- Target: 'ox_target' | 'qb-target' | 'auto'
Config.Target     = Config.Target or 'auto'

-- Helpers (client/server)
function Config.DetectFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if GetResourceState('qbx_core') == 'started' then return 'Qbox' end
    if GetResourceState('qb-core')  == 'started' then return 'QBCore' end
    if GetResourceState('es_extended') == 'started' then return 'ESX' end
    return 'standalone'
end

function Config.DetectInventory()
    if Config.Inventory ~= 'auto' then return Config.Inventory end
    if GetResourceState('ox_inventory') == 'started' then return 'ox_inventory' end
    if GetResourceState('qb-inventory') == 'started' then return 'qb' end
    if GetResourceState('qs-inventory') == 'started' then return 'qs' end
    if GetResourceState('ps-inventory') == 'started' then return 'ps' end
    return 'none'
end

function Config.DetectTarget()
    if Config.Target ~= 'auto' then return Config.Target end
    if GetResourceState('ox_target') == 'started' then return 'ox_target' end
    if GetResourceState('qb-target') == 'started' then return 'qb-target' end
    return 'none'
end

