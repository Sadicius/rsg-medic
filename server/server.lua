local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Track skeleton viewers, broadcast injury updates
local skeletonViewers = {}
local function broadcastInjuryUpdate(playerId)
    local Player = RSGCore.Functions.GetPlayer(playerId)
    if not Player then return end
    local injuries = Player.PlayerData.metadata['injuries']
    local charinfo = Player.PlayerData.charinfo
    local patientName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Patient')
    for viewerSrc, targetSrc in pairs(skeletonViewers) do
        if targetSrc == playerId then
            TriggerClientEvent('rsg-medic:client:updateInjuries', viewerSrc, playerId, injuries, patientName)
        end
    end
end

RegisterNetEvent('rsg-medic:server:watchSkeleton', function(targetSrc)
    skeletonViewers[source] = targetSrc
end)
RegisterNetEvent('rsg-medic:server:unwatchSkeleton', function()
    skeletonViewers[source] = nil
end)

------------------------
-- use bandage
-----------------------
RSGCore.Functions.CreateUseableItem('bandage', function(source, item)
    local src = source
    TriggerClientEvent('rsg-medic:client:usebandage', src, item.name)
end)
RSGCore.Functions.CreateUseableItem('fieldbandage', function(source)
    TriggerClientEvent('rsg-medic:client:usefieldbandage', source)
end)
---------------------------------
-- medic storage
---------------------------------
RegisterNetEvent('rsg-medic:server:openstash', function(location)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = { label = locale('sv_medical_storage'), maxweight = Config.StorageMaxWeight, slots = Config.StorageMaxSlots }
    local stashName = 'medic_' .. location
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)

----------------------------------
-- Admin Revive Player
----------------------------------
RSGCore.Commands.Add('revive', locale('sv_revive'), {{name = 'id', help = locale('sv_revive_2')}}, false, function(source, args)
    local src = source

    if not args[1] then
        TriggerClientEvent('rsg-medic:client:adminRevive', src)
        return
    end

    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_no_online'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:adminRevive', Player.PlayerData.source)
end, 'admin')

-- Admin Kill Player
RSGCore.Commands.Add('kill', locale('sv_kill'), {{name = 'id', help = locale('sv_kill_id')}}, true, function(source, args)
    local src = source
    local target = tonumber(args[1])

    local Player = RSGCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_no_online'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:KillPlayer', Player.PlayerData.source)
end, 'admin')

RSGCore.Commands.Add('heal', locale('sv_heal'), {{name = 'id', help = locale('sv_heal_2')}}, false, function(source, args)
    local src = source

    if not args[1] then
        TriggerClientEvent('rsg-medic:client:adminHeal', src)
        return
    end

    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_no_online'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:adminHeal', Player.PlayerData.source)
end, 'admin')

----------------------
-- EVENTS 
-----------------------
-- Death Actions: Remove Inventory / Cash
RegisterNetEvent('rsg-medic:server:deathactions', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if Config.WipeInventoryOnRespawn then
        Player.Functions.ClearInventory()
        MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_all'), type = 'info', duration = 7000 })
    end

    if Config.WipeCashOnRespawn then
        Player.Functions.SetMoney('cash', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_cash'), type = 'info', duration = 7000 })
    end
    if Config.WipeBloodmoneyOnRespawn then
        Player.Functions.SetMoney('bloodmoney', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_bloodmoney'), type = 'info', duration = 7000 })
    end
end)

-- Medic Revive Player (with injury reset)
RegisterNetEvent('rsg-medic:server:RevivePlayer', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(playerId)

    if not Patient then return end

    if Player.PlayerData.job.name ~= Config.JobRequired then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_not_medic'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('firstaid', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['firstaid'], 'remove')
        TriggerClientEvent('rsg-medic:client:playerRevive', Patient.PlayerData.source)

        -- Reset all injuries on revive
        local injuries = {}
        for i = 1, #Config.InjuryBodyParts do
            injuries[Config.InjuryBodyParts[i].name] = 'healthy'
        end
        Patient.Functions.SetMetaData('injuries', injuries)
        TriggerClientEvent('rsg-medic:client:updateInjuries', Patient.PlayerData.source, Patient.PlayerData.source, injuries, (Patient.PlayerData.charinfo.firstname or 'Unknown') .. ' ' .. (Patient.PlayerData.charinfo.lastname or 'Patient'))
        broadcastInjuryUpdate(Patient.PlayerData.source)
    end
end)

-- Medic Treat Wounds (with injury improvement)
RegisterNetEvent('rsg-medic:server:TreatWounds', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(playerId)

    if not Patient then return end

    if Player.PlayerData.job.name ~= Config.JobRequired then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_not_medic'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('bandage', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['bandage'], 'remove')
        TriggerClientEvent('rsg-medic:client:HealInjuries', Patient.PlayerData.source)

        -- Improve one injury level on treated player
        local injuries = Patient.PlayerData.metadata['injuries']
        if injuries then
            local worstPart = nil
            local worstState = 0
            local order = { healthy = 0, injured = 1, broken = 2, bleeding = 3 }
            for i = 1, #Config.InjuryBodyParts do
                local partName = Config.InjuryBodyParts[i].name
                local state = injuries[partName] or 'healthy'
                if order[state] and order[state] > worstState then
                    worstState = order[state]
                    worstPart = partName
                end
            end
            if worstPart then
                local current = injuries[worstPart]
                if current == 'bleeding' then injuries[worstPart] = 'broken'
                elseif current == 'broken' then injuries[worstPart] = 'injured'
                elseif current == 'injured' then injuries[worstPart] = 'healthy'
                end
                Patient.Functions.SetMetaData('injuries', injuries)
                TriggerClientEvent('rsg-medic:client:updateInjuries', Patient.PlayerData.source, Patient.PlayerData.source, injuries, (Patient.PlayerData.charinfo.firstname or 'Unknown') .. ' ' .. (Patient.PlayerData.charinfo.lastname or 'Patient'))
                broadcastInjuryUpdate(Patient.PlayerData.source)
            end
        end
    end
end)

-- Medic Alert
RegisterNetEvent('rsg-medic:server:medicAlert', function(text)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = RSGCore.Functions.GetRSGPlayers()

    for _, v in pairs(players) do
        if v.PlayerData.job.name == 'medic' and v.PlayerData.job.onduty then
            TriggerClientEvent('rsg-medic:client:medicAlert', v.PlayerData.source, coords, text)
        end
    end
end)
RegisterNetEvent('rsg-medic:server:buyMedicItem', function(itemName, price)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Job check
    if Player.PlayerData.job.name ~= Config.JobRequired then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_not_medic'), type = 'error', duration = 7000 })
        return
    end

    -- Validate item exists in shop config
    local validItem = false
    for i = 1, #Config.MedicShopItems do
        if Config.MedicShopItems[i].name == itemName then
            validItem = true
            price = Config.MedicShopItems[i].price -- use server-side price, never trust client
            break
        end
    end

    if not validItem then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Invalid item', type = 'error', duration = 5000 })
        return
    end

    -- Charge if price > 0
    if price > 0 then
        if Player.PlayerData.money['cash'] < price then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Not enough cash', type = 'error', duration = 5000 })
            return
        end
        Player.Functions.RemoveMoney('cash', price)
    end

    Player.Functions.AddItem(itemName, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], 'add')
end)
--------------------------
-- Medics On-Duty Callback
-------------------------
RSGCore.Functions.CreateCallback('rsg-medic:server:getmedics', function(source, cb)
    local amount = 0
    local players = RSGCore.Functions.GetRSGPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.name == Config.JobRequired and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    cb(amount)
end)

---------------------------------
-- remove item
---------------------------------
RegisterServerEvent('rsg-medic:server:removeitem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
end)

-- Heal one self-injury on bandage/fieldbandage use
RegisterServerEvent('rsg-medic:server:healSelfInjury', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local injuries = Player.PlayerData.metadata['injuries']
    if not injuries then return end

    local order = { healthy = 0, injured = 1, broken = 2, bleeding = 3 }
    local worstPart, worstState = nil, -1
    for i = 1, #Config.InjuryBodyParts do
        local partName = Config.InjuryBodyParts[i].name
        local state = injuries[partName] or 'healthy'
        if (order[state] or 0) > worstState then
            worstState = order[state] or 0
            worstPart = partName
        end
    end

    if worstPart and worstState > 0 then
        local current = injuries[worstPart]
        if current == 'bleeding' then injuries[worstPart] = 'broken'
        elseif current == 'broken' then injuries[worstPart] = 'injured'
        elseif current == 'injured' then injuries[worstPart] = 'healthy'
        end
        Player.Functions.SetMetaData('injuries', injuries)
        TriggerClientEvent('rsg-medic:client:updateInjuries', src, src, injuries, (Player.PlayerData.charinfo.firstname or 'Unknown') .. ' ' .. (Player.PlayerData.charinfo.lastname or 'Patient'))
        broadcastInjuryUpdate(src)
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Injury Improved',
            description = 'Your ' .. worstPart:gsub('_', ' ') .. ' improved to ' .. injuries[worstPart],
            type = 'success',
            duration = 5000,
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'No Injuries',
            description = 'You have no injuries to treat',
            type = 'info',
            duration = 3000,
        })
    end
end)

-----------------------
-- INJURY SYSTEM
-----------------------

-- Callback: Get player injuries
RSGCore.Functions.CreateCallback('rsg-medic:server:getPlayerInjuries', function(source, cb, targetSrc)
    local Player = RSGCore.Functions.GetPlayer(targetSrc)
    if not Player then cb(nil) return end

    local injuries = Player.PlayerData.metadata['injuries']
    if not injuries then
        injuries = {}
        for i = 1, #Config.InjuryBodyParts do
            injuries[Config.InjuryBodyParts[i].name] = 'healthy'
        end
        Player.Functions.SetMetaData('injuries', injuries)
    end
    local charinfo = Player.PlayerData.charinfo
    local patientName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Patient')
    cb(injuries, patientName)
end)

-- Limit injury notifications to once per 30 seconds per player
local injuryNotifyCooldown = {}
local function canNotifyInjury(src)
    local now = os.time()
    if not injuryNotifyCooldown[src] or now - injuryNotifyCooldown[src] > 30 then
        injuryNotifyCooldown[src] = now
        return true
    end
    return false
end

-- Event: Record weapon hit on a body part
RegisterNetEvent('rsg-medic:server:recordBodyHit', function(bodyPart)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local injuries = Player.PlayerData.metadata['injuries']
    if not injuries then
        injuries = {}
        for i = 1, #Config.InjuryBodyParts do
            injuries[Config.InjuryBodyParts[i].name] = 'healthy'
        end
    end

    local oldState = injuries[bodyPart]
    local newState

    if not oldState or oldState == 'healthy' then
        if math.random() < 0.5 then
            newState = 'injured'
        end
    elseif oldState == 'injured' and math.random() < 0.35 then
        newState = 'broken'
    elseif oldState == 'broken' and math.random() < 0.2 then
        newState = 'bleeding'
    end

    if newState and newState ~= oldState then
        injuries[bodyPart] = newState
        Player.Functions.SetMetaData('injuries', injuries)
        TriggerClientEvent('rsg-medic:client:updateInjuries', src, src, injuries, (Player.PlayerData.charinfo.firstname or 'Unknown') .. ' ' .. (Player.PlayerData.charinfo.lastname or 'Patient'))
        broadcastInjuryUpdate(src)
        if canNotifyInjury(src) then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Injury',
                description = 'Your ' .. bodyPart:gsub('_', ' ') .. ' is now ' .. newState,
                type = 'error',
                duration = 5000,
            })
        end
    end
end)

-- Event: Apply random death injuries
RegisterNetEvent('rsg-medic:server:applyDeathInjuries', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local injuries = {}
    local injuredParts = {}
    for i = 1, #Config.InjuryBodyParts do
        local part = Config.InjuryBodyParts[i]
        local rand = math.random()
        if rand < 0.15 then
            injuries[part.name] = 'bleeding'
            injuredParts[#injuredParts+1] = part.name:gsub('_', ' ') .. ' (bleeding)'
        elseif rand < 0.4 then
            injuries[part.name] = 'broken'
            injuredParts[#injuredParts+1] = part.name:gsub('_', ' ') .. ' (broken)'
        elseif rand < 0.7 then
            injuries[part.name] = 'injured'
            injuredParts[#injuredParts+1] = part.name:gsub('_', ' ') .. ' (injured)'
        else
            injuries[part.name] = 'healthy'
        end
    end
    Player.Functions.SetMetaData('injuries', injuries)
    TriggerClientEvent('rsg-medic:client:updateInjuries', src, src, injuries, (Player.PlayerData.charinfo.firstname or 'Unknown') .. ' ' .. (Player.PlayerData.charinfo.lastname or 'Patient'))
    broadcastInjuryUpdate(src)

    if #injuredParts > 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'You have sustained injuries',
            description = table.concat(injuredParts, ', '),
            type = 'error',
            duration = 7000,
        })
    end
end)

-- Event: Reset injuries to healthy
RegisterNetEvent('rsg-medic:server:resetPlayerInjuries', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local injuries = {}
    for i = 1, #Config.InjuryBodyParts do
        injuries[Config.InjuryBodyParts[i].name] = 'healthy'
    end
    Player.Functions.SetMetaData('injuries', injuries)
    TriggerClientEvent('rsg-medic:client:updateInjuries', src, src, injuries, (Player.PlayerData.charinfo.firstname or 'Unknown') .. ' ' .. (Player.PlayerData.charinfo.lastname or 'Patient'))
    broadcastInjuryUpdate(src)
end)

-- Event: Open skeleton for specific player (admin test)
RegisterNetEvent('rsg-medic:server:openSkeletonAdmin', function(targetSrc)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(targetSrc)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Player not found', type = 'error' })
        return
    end

    local injuries = Player.PlayerData.metadata['injuries']
    if not injuries then
        injuries = {}
        for i = 1, #Config.InjuryBodyParts do
            injuries[Config.InjuryBodyParts[i].name] = 'healthy'
        end
        Player.Functions.SetMetaData('injuries', injuries)
    end

    TriggerClientEvent('rsg-medic:client:openSkeletonNUI', src, injuries, (Player.PlayerData.charinfo.firstname or 'Unknown') .. ' ' .. (Player.PlayerData.charinfo.lastname or 'Patient'), targetSrc)
end)

-----------------------
-- TEST COMMANDS
-----------------------
RSGCore.Commands.Add('setinjury', 'Set a player\'s injury (Admin Test)', {
    { name = 'bodypart', help = 'head/torso/left_arm/right_arm/left_leg/right_leg/all' },
    { name = 'state', help = 'healthy/injured/broken/bleeding' },
    { name = 'id', help = 'Player ID (optional)' },
}, false, function(source, args)
    local src = source
    local target = src
    if args[3] then
        local Target = RSGCore.Functions.GetPlayer(tonumber(args[3]))
        if Target then target = Target.PlayerData.source end
    end

    local Player = RSGCore.Functions.GetPlayer(target)
    if not Player then return end

    local injuries = Player.PlayerData.metadata['injuries']
    if not injuries then
        injuries = {}
        for i = 1, #Config.InjuryBodyParts do
            injuries[Config.InjuryBodyParts[i].name] = 'healthy'
        end
    end

    local bodyPart = args[1]
    local state = args[2] or 'healthy'

    if bodyPart == 'all' then
        for i = 1, #Config.InjuryBodyParts do
            injuries[Config.InjuryBodyParts[i].name] = state
        end
    else
        injuries[bodyPart] = state
    end

    Player.Functions.SetMetaData('injuries', injuries)
    broadcastInjuryUpdate(target or src)
    TriggerClientEvent('ox_lib:notify', src, { title = 'Injury Set', description = bodyPart .. ' -> ' .. state, type = 'success' })
end, 'admin')

RSGCore.Commands.Add('checkskeleton', 'Open skeleton UI for a player (Admin Test)', {
    { name = 'id', help = 'Player ID' },
}, false, function(source, args)
    local src = source
    local target = tonumber(args[1])
    if not target then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Usage: /checkskeleton [id]', type = 'error' })
        return
    end

    local Player = RSGCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Player not found', type = 'error' })
        return
    end

    local injuries = Player.PlayerData.metadata['injuries']
    if not injuries then
        injuries = {}
        for i = 1, #Config.InjuryBodyParts do
            injuries[Config.InjuryBodyParts[i].name] = 'healthy'
        end
        Player.Functions.SetMetaData('injuries', injuries)
    end

    TriggerClientEvent('rsg-medic:client:openSkeletonNUI', src, injuries, (Player.PlayerData.charinfo.firstname or 'Unknown') .. ' ' .. (Player.PlayerData.charinfo.lastname or 'Patient'), target)
end, 'admin')