Config = Config or {}

-- Auto-detect by default; you can force any value: 'QBCore' | 'ESX' | 'Qbox' | 'standalone'
Config.Framework = Config.Framework or 'auto'

-- Inventory: Only ox_inventory is supported
Config.Inventory  = 'ox_inventory'

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
    -- Always use ox_inventory
    return 'ox_inventory'
end

function Config.DetectTarget()
    if Config.Target ~= 'auto' then return Config.Target end
    if GetResourceState('ox_target') == 'started' then return 'ox_target' end
    if GetResourceState('qb-target') == 'started' then return 'qb-target' end
    return 'none'
end

