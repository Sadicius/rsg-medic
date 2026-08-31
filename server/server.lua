local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local medicAlertCooldown = {}

-- validates that `src` is an on-duty medic and is within `maxDistance` units of `target`
local function IsValidMedicAction(src, target, maxDistance)
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(target)

    if not Player or not Patient then return false, nil, nil end
    if Player.PlayerData.job.name ~= Config.JobRequired or not Player.PlayerData.job.onduty then
        return false, Player, Patient
    end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if srcPed == 0 or targetPed == 0 then return false, Player, Patient end

    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if dist > maxDistance then return false, Player, Patient end

    return true, Player, Patient
end

---------------------------------
-- SaltyChat integration
---------------------------------
CreateThread(function()
    if not Config.SaltyChat then return end

    Wait(0)

    if GetResourceState('saltychat') ~= 'started' then
        print('^1[rsg-medic] Config.SaltyChat is enabled, but saltychat is not started. Start saltychat before rsg-medic.^0')
    elseif Config.Debug then
        print('^2[rsg-medic] SaltyChat death voice integration enabled.^0')
    end
end)

RegisterNetEvent('rsg-medic:server:setSaltyChatAlive', function(isAlive)
    if not Config.SaltyChat then return end

    local src = source
    if type(isAlive) ~= 'boolean' then return end

    if GetResourceState('saltychat') ~= 'started' then
        if Config.Debug then
            print('[rsg-medic] SaltyChat integration is enabled, but saltychat is not started')
        end
        return
    end

    exports['saltychat']:SetPlayerAlive(src, isAlive)

    if Config.Debug then
        print(('[rsg-medic] SaltyChat player %s alive state set to %s'):format(src, isAlive))
    end
end)

-----------------------
-- use bandage
-----------------------
RSGCore.Functions.CreateUseableItem('bandage', function(source, item)
    local src = source
    TriggerClientEvent('rsg-medic:client:usebandage', src, item.name)
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

    SendDiscordWebhook('storage', 'Medic Storage Accessed',
        GetWebhookPlayerLabel(Player) .. ' opened the medic storage.',
        { { name = 'Location', value = tostring(location), inline = true } })
end)

----------------------------------
-- Admin Revive Player
----------------------------------
RSGCore.Commands.Add('revive', locale('sv_revive'), {{name = 'id', help = locale('sv_revive_2')}}, false, function(source, args)
    local src = source
    local Executor = RSGCore.Functions.GetPlayer(src)

    if not args[1] then
        TriggerClientEvent('rsg-medic:client:adminRevive', src)
        SendDiscordWebhook('admin', 'Admin Revive',
            (Executor and GetWebhookPlayerLabel(Executor) or ('Server id ' .. src)) .. ' revived themselves.')
        return
    end

    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_no_online'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:adminRevive', Player.PlayerData.source)

    SendDiscordWebhook('admin', 'Admin Revive',
        (Executor and GetWebhookPlayerLabel(Executor) or ('Server id ' .. src)) .. ' revived ' .. GetWebhookPlayerLabel(Player) .. '.')
end, 'admin')

-- Admin Kill Player
RSGCore.Commands.Add('kill', locale('sv_kill'), {{name = 'id', help = locale('sv_kill_id')}}, true, function(source, args)
    local src = source
    local target = tonumber(args[1])
    local Executor = RSGCore.Functions.GetPlayer(src)

    local Player = RSGCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_no_online'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:KillPlayer', Player.PlayerData.source)

    SendDiscordWebhook('admin', 'Admin Kill',
        (Executor and GetWebhookPlayerLabel(Executor) or ('Server id ' .. src)) .. ' killed ' .. GetWebhookPlayerLabel(Player) .. '.')
end, 'admin')

RSGCore.Commands.Add('heal', locale('sv_heal'), {{name = 'id', help = locale('sv_heal_2')}}, false, function(source, args)
    local src = source
    local Executor = RSGCore.Functions.GetPlayer(src)

    if not args[1] then
        TriggerClientEvent('rsg-medic:client:adminHeal', src)
        SendDiscordWebhook('admin', 'Admin Heal',
            (Executor and GetWebhookPlayerLabel(Executor) or ('Server id ' .. src)) .. ' healed themselves.')
        return
    end

    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_no_online'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:adminHeal', Player.PlayerData.source)

    SendDiscordWebhook('admin', 'Admin Heal',
        (Executor and GetWebhookPlayerLabel(Executor) or ('Server id ' .. src)) .. ' healed ' .. GetWebhookPlayerLabel(Player) .. '.')
end, 'admin')

AddEventHandler('playerDropped', function()
    medicAlertCooldown[source] = nil
end)

-- Duty Toggle Logging (client fires this after RSGCore:ToggleDuty resolves)
RegisterNetEvent('rsg-medic:server:LogDutyToggle', function(onDuty)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= Config.JobRequired then return end

    SendDiscordWebhook('duty', 'Medic Duty Changed',
        GetWebhookPlayerLabel(Player) .. ' went **' .. (onDuty and 'on duty' or 'off duty') .. '**.')
end)

-- Death Logging (rsg-medic's own Discord webhook, independent of rsg-log)
RegisterNetEvent('rsg-medic:server:LogDeath', function(killerName, weaponLabel, weaponName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(killerName) ~= 'string' then killerName = 'Unknown' end
    if type(weaponLabel) ~= 'string' then weaponLabel = 'Unknown' end
    if type(weaponName) ~= 'string' then weaponName = 'Unknown' end

    SendDiscordWebhook('death', 'Player Died',
        GetWebhookPlayerLabel(Player) .. ' has died.',
        {
            { name = 'Killed By', value = killerName:sub(1, 100), inline = true },
            { name = 'Weapon', value = ('%s (%s)'):format(weaponLabel:sub(1, 60), weaponName:sub(1, 60)), inline = true },
        })
end)

----------------------
-- EVENTS 
-----------------------
-- Death Actions: Remove Inventory / Cash
RegisterNetEvent('rsg-medic:server:deathactions', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local wiped = {}

    if Config.WipeInventoryOnRespawn then
        Player.Functions.ClearInventory()
        MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_all'), type = 'info', duration = 7000 })
        wiped[#wiped + 1] = 'inventory'
    end

    if Config.WipeCashOnRespawn then
        Player.Functions.SetMoney('cash', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_cash'), type = 'info', duration = 7000 })
        wiped[#wiped + 1] = 'cash'
    end
    if Config.WipeBloodmoneyOnRespawn then
        Player.Functions.SetMoney('bloodmoney', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_bloodmoney'), type = 'info', duration = 7000 })
        wiped[#wiped + 1] = 'bloodmoney'
    end

    if #wiped > 0 then
        SendDiscordWebhook('death', 'Respawn Penalties Applied',
            GetWebhookPlayerLabel(Player) .. ' lost the following on respawn: **' .. table.concat(wiped, ', ') .. '**.')
    end
end)

-- Medic Revive Player
RegisterNetEvent('rsg-medic:server:RevivePlayer', function(playerId)
    local src = source
    playerId = tonumber(playerId)
    if not playerId then return end

    local valid, Player = IsValidMedicAction(src, playerId, 5.0)
    if not Player then return end

    if not valid then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_not_medic'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('firstaid', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['firstaid'], 'remove')
        TriggerClientEvent('rsg-medic:client:playerRevive', playerId)

        local Patient = RSGCore.Functions.GetPlayer(playerId)
        SendDiscordWebhook('revive', 'Player Revived',
            GetWebhookPlayerLabel(Player) .. ' revived ' .. (Patient and GetWebhookPlayerLabel(Patient) or ('server id ' .. playerId)) .. '.')
    end
end)

-- Medic Treat Wounds
RegisterNetEvent('rsg-medic:server:TreatWounds', function(playerId)
    local src = source
    playerId = tonumber(playerId)
    if not playerId then return end

    local valid, Player = IsValidMedicAction(src, playerId, 5.0)
    if not Player then return end

    if not valid then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_not_medic'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('bandage', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['bandage'], 'remove')
        TriggerClientEvent('rsg-medic:client:HealInjuries', playerId)

        local Patient = RSGCore.Functions.GetPlayer(playerId)
        SendDiscordWebhook('treatment', 'Wounds Treated',
            GetWebhookPlayerLabel(Player) .. ' treated the wounds of ' .. (Patient and GetWebhookPlayerLabel(Patient) or ('server id ' .. playerId)) .. '.')
    end
end)

-- Medic Alert
RegisterNetEvent('rsg-medic:server:medicAlert', function(text)
    local src = source

    local now = os.time()
    if medicAlertCooldown[src] and now - medicAlertCooldown[src] < Config.MedicCallDelay then
        return
    end
    medicAlertCooldown[src] = now

    if type(text) ~= 'string' then return end
    text = text:sub(1, 120)

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local players = RSGCore.Functions.GetRSGPlayers()

    for _, v in pairs(players) do
        if v.PlayerData.job.name == Config.JobRequired and v.PlayerData.job.onduty then
            TriggerClientEvent('rsg-medic:client:medicAlert', v.PlayerData.source, coords, text)
        end
    end
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
    if item ~= 'bandage' then return end -- this event is only ever used for bandage consumption
    amount = tonumber(amount) or 1

    if Player.Functions.RemoveItem(item, amount) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)

        if Config.Webhooks and Config.Webhooks.logging and Config.Webhooks.logging.bandageUse then
            SendDiscordWebhook('treatment', 'Bandage Self-Applied',
                GetWebhookPlayerLabel(Player) .. ' used a bandage on themselves.')
        end
    end
end)
