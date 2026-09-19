local RSGCore = exports['rsg-core']:GetCoreObject()
local blipEntries = {}
local transG = Config.DeathTimer
lib.locale()

------------------------
--- OX_TARGET SETUP
------------------------

CreateThread(function()
    Wait(5000)

    local ok = pcall(function()
        return exports.ox_target.addGlobalPlayer
    end)
    if not ok then return end

    exports.ox_target:addGlobalPlayer({
        {
            name = 'medic_revive',
            label = locale('cl_reviving'),
            icon = 'fa-solid fa-kit-medical',
            canInteract = function()
                local PlayerData = RSGCore.Functions.GetPlayerData()
                return PlayerData.job and PlayerData.job.name == Config.JobRequired and PlayerData.job.onduty
            end,
            onSelect = function(data)
                local entity = data.entity
                if not IsPedAPlayer(entity) then return end

                local hasItem = RSGCore.Functions.HasItem('firstaid', 1)
                if not hasItem then
                    lib.notify({ title = locale('cl_need_kit'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
                    return
                end

                local playerIndex = NetworkGetPlayerIndexFromPed(entity)
                local serverId = GetPlayerServerId(playerIndex)

                ExecuteCommand('me Reviving')

                lib.progressBar({
                    duration = Config.MedicReviveTime,
                    position = 'bottom',
                    useWhileDead = false,
                    canCancel = false,
                    disableControl = true,
                    disable = { move = true, mouse = false },
                    label = locale('cl_reviving'),
                    anim = {
                        dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
                        clip = 'bandage_fast',
                        flag = 1,
                    },
                })

                TriggerServerEvent('rsg-medic:server:RevivePlayer', serverId)
                transG = 0
            end,
        },
        {
            name = 'medic_treat',
            label = locale('cl_treating'),
            icon = 'fa-solid fa-bandage',
            canInteract = function()
                local PlayerData = RSGCore.Functions.GetPlayerData()
                return PlayerData.job and PlayerData.job.name == Config.JobRequired and PlayerData.job.onduty
            end,
            onSelect = function(data)
                local entity = data.entity
                if not IsPedAPlayer(entity) then return end

                local hasItem = RSGCore.Functions.HasItem('bandage', 1)
                if not hasItem then
                    lib.notify({ title = locale('cl_need_bandage'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
                    return
                end

                local playerIndex = NetworkGetPlayerIndexFromPed(entity)
                local serverId = GetPlayerServerId(playerIndex)

                ExecuteCommand('me Treating Wounds')

                lib.progressBar({
                    duration = Config.MedicTreatTime,
                    position = 'bottom',
                    useWhileDead = false,
                    canCancel = false,
                    disableControl = true,
                    disable = { move = true, mouse = false },
                    label = locale('cl_treating'),
                    anim = {
                        dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
                        clip = 'bandage_fast',
                        flag = 1,
                    },
                })

                TriggerServerEvent('rsg-medic:server:TreatWounds', serverId)
                transG = 0
            end,
        },
        {
            name = 'medic_check',
            label = 'Check Injuries',
            icon = 'fa-solid fa-x-ray',
            canInteract = function()
                local PlayerData = RSGCore.Functions.GetPlayerData()
                return PlayerData.job and PlayerData.job.name == Config.JobRequired and PlayerData.job.onduty
            end,
            onSelect = function(data)
                local entity = data.entity
                if not IsPedAPlayer(entity) then return end

                local playerIndex = NetworkGetPlayerIndexFromPed(entity)
                local serverId = GetPlayerServerId(playerIndex)

                ExecuteCommand('me Examining Patient')

                RSGCore.Functions.TriggerCallback('rsg-medic:server:getPlayerInjuries', function(injuries, patientName)
                    if not injuries then
                        lib.notify({ title = 'Error', description = 'Could not get injury data', type = 'error' })
                        return
                    end
                    SetNuiFocus(true, true)
                    SetNuiFocusKeepInput(false)
                    SendNUIMessage({
                        type = 'showInjuries',
                        injuries = injuries,
                        patientName = patientName or 'Patient',
                    })
                    TriggerServerEvent('rsg-medic:server:watchSkeleton', serverId)
                end, serverId)
                transG = 0
            end,
        },
    }, 2.5)
end)


-----------------------
--- EVENTS
------------------------
-- Toggle On-Duty
AddEventHandler('rsg-medic:client:ToggleDuty', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        local PlayerJob = PlayerData.job

        if PlayerJob.name ~= Config.JobRequired then
            lib.notify({ title = locale('cl_not_medic'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
            return
        end

        TriggerServerEvent("RSGCore:ToggleDuty")
    end)
end)

-- Medic Revive Player (kept as a fallback event – now also driven by ox_target above)
AddEventHandler('rsg-medic:client:RevivePlayer', function()
    local hasItem = RSGCore.Functions.HasItem('firstaid', 1)
    if not hasItem then
        lib.notify({ title = locale('cl_need_kit'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake',  duration = 7000  })
        return
    end

    local players = RSGCore.Functions.GetPlayersFromCoords(nil, 5.0)
    local playerId = -1
    for i = 1, #players do
        if players[i] ~= PlayerId() then
            playerId = players[i]
            break
        end
    end

    if playerId == -1 then
        lib.notify({ title = locale('cl_player_nearby'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        return
    end

    local serverId = GetPlayerServerId(playerId)
    local tped = GetPlayerPed(GetPlayerFromServerId(serverId))

    TaskTurnPedToFaceEntity(cache.ped, tped, -1)
    Wait(3000)
    FreezeEntityPosition(cache.ped, true)
    TaskStartScenarioInPlace(cache.ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)
    Wait(5000)
    ExecuteCommand('me Reviving')

    lib.progressBar({
        duration = Config.MedicReviveTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = { move = true, mouse = false },
        label = locale('cl_reviving'),
    })

    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)
    TriggerServerEvent('rsg-medic:server:RevivePlayer', serverId)
    transG = 0
end)

-- Medic Treat Wounds (kept as a fallback event – now also driven by ox_target above)
AddEventHandler('rsg-medic:client:TreatWounds', function()
    local hasItem = RSGCore.Functions.HasItem('bandage', 1)
    if not hasItem then
        lib.notify({ title = locale('cl_need_bandage'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        return
    end

    local players = RSGCore.Functions.GetPlayersFromCoords(nil, 5.0)
    local playerId = -1
    for i = 1, #players do
        if players[i] ~= PlayerId() then
            playerId = players[i]
            break
        end
    end

    if playerId == -1 then
        lib.notify({ title = locale('cl_player_nearby'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        return
    end

    local serverId = GetPlayerServerId(playerId)
    local tped = GetPlayerPed(GetPlayerFromServerId(serverId))

    TaskTurnPedToFaceEntity(cache.ped, tped, -1)
    Wait(3000)
    FreezeEntityPosition(cache.ped, true)
    TaskStartScenarioInPlace(cache.ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)
    Wait(5000)
    ExecuteCommand('me Treating Wounds')

    lib.progressBar({
        duration = Config.MedicTreatTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = { move = true, mouse = false },
        label = locale('cl_treating'),
    })

    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)
    TriggerServerEvent('rsg-medic:server:TreatWounds', serverId)
    transG = 0
end)

-- Medic Treat Wounds (heal injuries on the patient's client)
RegisterNetEvent('rsg-medic:client:HealInjuries', function()
    SetAttributeCoreValue(cache.ped, 0, GetAttributeCoreValue(cache.ped, 0) + Config.MedicTreatHealth)
    ClearPedBloodDamage(cache.ped)
end)

-- Medic Alert
RegisterNetEvent('rsg-medic:client:medicAlert', function(coords, text)
    lib.notify({ title = locale('cl_info'), description = text, type = 'info', duration = 7000 })

    local blip = BlipAddForCoords(1664425300, coords.x, coords.y, coords.z)
    local blip2 = BlipAddForCoords(1664425300, coords.x, coords.y, coords.z)

    SetBlipSprite(blip, 1109348405)
    SetBlipSprite(blip2, -184692826)
    BlipAddModifier(blip, GetHashKey('BLIP_MODIFIER_AREA_PULSE'))
    BlipAddModifier(blip2, GetHashKey('BLIP_MODIFIER_AREA_PULSE'))
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    SetBlipName(blip, text)
    SetBlipName(blip2, text)

    blipEntries[#blipEntries + 1] = {coords = coords, handle = blip}
    blipEntries[#blipEntries + 1] = {coords = coords, handle = blip2}

    if Config.AddGPSRoute then
        StartGpsMultiRoute(`COLOR_GREEN`, true, true)
        AddPointToGpsMultiRoute(coords)
        SetGpsMultiRouteRender(true)
    end

    CreateThread(function ()
        while transG ~= 0 do
            Wait(180 * 4)

            local pcoord = GetEntityCoords(cache.ped)
            local distance = #(coords - pcoord)
            transG = transG - 1

            if Config.Debug then
                print(locale('cl_player_blip') .. tostring(distance) .. locale('cl_m'))
            end

            if transG <= 0 or distance < 5.0 then
                for i = 1, #blipEntries do
                    local blips = blipEntries[i]
                    local bcoords = blips.coords

                    if coords == bcoords then
                        if Config.Debug then
                            print('')
                            print(locale('cl_blip')..tostring(bcoords))
                            print(locale('cl_blip_remove')..tostring(blipEntries[i].handle))
                            print('')
                        end

                        RemoveBlip(blipEntries[i].handle)
                    end
                end

                transG = Config.DeathTimer

                if Config.AddGPSRoute then
                    ClearGpsMultiRoute(coords)
                end

                return
            end
        end
    end)
end)

-- Cleanup
local resource = GetCurrentResourceName()
AddEventHandler("onResourceStop", function(resourceName)
    if resource ~= resourceName then return end

    ClearGpsMultiRoute(coords)

    for i = 1, #blipEntries do
        if blipEntries[i].handle then
            RemoveBlip(blipEntries[i].handle)
        end
    end
end)