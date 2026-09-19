local RSGCore = exports['rsg-core']:GetCoreObject()
local sharedWeapons = exports['rsg-core']:GetWeapons()
local createdEntries = {}
local isLoggedIn = false
local deathSecondsRemaining = 0
local deathTimerStarted = false
local deathactive = false
local mediclocation = nil
local medicsonduty = 0
local healthset = false
local closestRespawn = nil
local medicCalled = false
local Dead = false
local deadcam = nil
local angleY = 0.0
local angleZ = 0.0
local isBusy = false
lib.locale()

---------------------------------------------------------------------
-- death timer
---------------------------------------------------------------------
local deathTimer = function()
    deathSecondsRemaining = Config.DeathTimer
    CreateThread(function()
        while deathSecondsRemaining > 0 do
            Wait(1000)
            deathSecondsRemaining = deathSecondsRemaining - 1
            TriggerEvent("rsg-medic:client:GetMedicsOnDuty")
        end
    end)
end

---------------------------------------------------------------------
-- drawtext for countdown
---------------------------------------------------------------------
local DrawTxt = function(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local string = CreateVarString(10, "LITERAL_STRING", str)

    SetTextFontForCurrentCommand(1) -- Font 1 for appropiate REDM style
    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
    SetTextCentre(centre)

    if enableShadow then
        SetTextDropshadow(1, 0, 0, 0, 255)
    end

    DisplayText(string, x, y)
end

---------------------------------------------------------------------
-- start death cam
---------------------------------------------------------------------
local StartDeathCam = function()
    ClearFocus()

    local coords = GetEntityCoords(cache.ped)
    local fov = GetGameplayCamFov()

    deadcam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords, 0, 0, 0, fov)

    SetCamActive(deadcam, true)
    RenderScriptCams(true, true, 1000, true, false)
end

---------------------------------------------------------------------
-- end death cam
---------------------------------------------------------------------
local EndDeathCam = function()
    ClearFocus()

    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(deadcam, false)
    DestroyAllCams(true)

    deadcam = nil
end

---------------------------------------------------------------------
-- update death cam position
---------------------------------------------------------------------
local ProcessNewPosition = function()
    local mouseX = 0.0
    local mouseY = 0.0

    if IsInputDisabled(0) then
        mouseX = GetDisabledControlNormal(1, 0x6BC904FC) * 8.0
        mouseY = GetDisabledControlNormal(1, 0x84574AE8) * 8.0
    else
        mouseX = GetDisabledControlNormal(1, 0x6BC904FC) * 0.5
        mouseY = GetDisabledControlNormal(1, 0x84574AE8) * 0.5
    end

    angleZ = angleZ - mouseX
    angleY = angleY + mouseY

    if angleY > 89.0 then
        angleY = 89.0
    elseif angleY < -89.0 then
        angleY = -89.0
    end

    local pCoords = GetEntityCoords(cache.ped)

    local behindCam =
    {
        x = pCoords.x + ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * (0.5 + 0.5),
        y = pCoords.y + ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * (0.5 + 0.5),
        z = pCoords.z + ((Sin(angleY))) * (0.5 + 0.5)
    }

    local rayHandle = StartShapeTestRay(pCoords.x, pCoords.y, pCoords.z + 0.5, behindCam.x, behindCam.y, behindCam.z, -1, cache.ped, 0)

    local _, hitBool, hitCoords, _, _ = GetShapeTestResult(rayHandle)

    local maxRadius = 3.5

    if (hitBool and Vdist(pCoords.x, pCoords.y, pCoords.z + 0.0, hitCoords) < 0.5 + 0.5) then
        maxRadius = Vdist(pCoords.x, pCoords.y, pCoords.z + 0.0, hitCoords)
    end

    local offset =
    {
        x = ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * maxRadius,
        y = ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * maxRadius,
        z = ((Sin(angleY))) * maxRadius
    }

    local pos =
    {
        x = pCoords.x + offset.x,
        y = pCoords.y + offset.y,
        z = pCoords.z + offset.z
    }

    return pos
end

---------------------------------------------------------------------
-- process camera controls
---------------------------------------------------------------------
local ProcessCamControls = function()

    local playerCoords = GetEntityCoords(cache.ped)

    -- disable 1st person as the 1st person camera can cause some glitches
    DisableOnFootFirstPersonViewThisUpdate()

    -- calculate new position
    local newPos = ProcessNewPosition()

    -- set coords of cam
    SetCamCoord(deadcam, newPos.x, newPos.y, newPos.z)

    -- set rotation
    PointCamAtCoord(deadcam, playerCoords.x, playerCoords.y, playerCoords.z)
end

---------------------------------------------------------------------
-- dealth log
---------------------------------------------------------------------
local deathLog = function()
    local player = PlayerId()
    local ped = PlayerPedId()
    local killer, killerWeapon = NetworkGetEntityKillerOfPlayer(player)

    if killer == ped or killer == -1 then return end

    local killerId = NetworkGetPlayerIndexFromPed(killer)
    local killerName = GetPlayerName(killerId) .. " ("..GetPlayerServerId(killerId)..")"
    local weaponLabel = 'Unknown'
    local weaponName = 'Unknown'
    local weaponItem = sharedWeapons[killerWeapon]
    if weaponItem then
        weaponLabel = weaponItem.label
        weaponName = weaponItem.name
    end

    local playerid = GetPlayerServerId(player)
    local playername = GetPlayerName(player)
    local msgDiscordA = playername..' ('..playerid..') '.. locale('cl_death_log_title')
    local msgDiscordB = killerName..' '.. locale('cl_death_log_message')..' '..playername.. ' '..locale('cl_death_log_message_b')..' **'..weaponLabel..'** ('..weaponName..')'
    TriggerServerEvent('rsg-log:server:CreateLog', 'death', msgDiscordA, 'red', msgDiscordB)

end

---------------------------------------------------------------------
-- medic call delay
---------------------------------------------------------------------
local MedicCalled = function()
    local delay = Config.MedicCallDelay * 1000
    CreateThread(function()
        while true do
            Wait(delay)
            medicCalled = false
            return
        end
    end)
end

---------------------------------------------------------------------
-- set closest respawn
---------------------------------------------------------------------
local function SetClosestRespawn()
    local pos = GetEntityCoords(cache.ped, true)
    local current = nil
    local dist = nil

    for k, _ in pairs(Config.RespawnLocations) do
        local dest = vector3(Config.RespawnLocations[k].coords.x, Config.RespawnLocations[k].coords.y, Config.RespawnLocations[k].coords.z)
        local dist2 = #(pos - dest)

        if current then
            if dist2 < dist then
                current = k
                dist = dist2
            end
        else
            dist = dist2
            current = k
        end
    end

    if current ~= closestRespawn then
        closestRespawn = current
    end
end

---------------------------------------------------------------------
-- prompts and blips
---------------------------------------------------------------------
CreateThread(function()
    for i = 1, #Config.MedicJobLocations do
        local loc = Config.MedicJobLocations[i]

        exports['rsg-core']:createPrompt(loc.prompt, loc.coords, RSGCore.Shared.Keybinds['J'], locale('cl_open') .. loc.name,
        {
            type = 'client',
            event = 'rsg-medic:client:mainmenu',
            args = {loc.prompt, loc.name}
        })

        createdEntries[#createdEntries + 1] = {type = "PROMPT", handle = loc.prompt}

        if loc.showblip then
            local MedicBlip = BlipAddForCoords(1664425300, loc.coords)
            SetBlipSprite(MedicBlip, GetHashKey(Config.Blip.blipSprite), true)
            SetBlipScale(MedicBlip, Config.Blip.blipScale)
            SetBlipName(MedicBlip, Config.Blip.blipName)

            createdEntries[#createdEntries + 1] = {type = "BLIP", handle = MedicBlip}
        end
    end
end)

local function PlayerDeath()
    exports.spawnmanager:setAutoSpawn(false)
    deathTimerStarted = true
    deathTimer()
    deathLog()
    deathactive = true
    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", true)
    LocalPlayer.state:set('isDead', true, true)
    TriggerEvent('rsg-medic:client:DeathCam')
end

CreateThread(function()
    while not LocalPlayer.state['isLoggedIn'] do
        Wait(1000)
    end

    local lastHealth = nil

    while true do
        if not LocalPlayer.state.invincible then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local health = GetEntityHealth(ped)
                if health == 0 and not deathactive then
                    PlayerDeath()
                end
                if lastHealth ~= health then
                    LocalPlayer.state:set('health', health, true)
                    lastHealth = health
                end
            end
        end
        Wait(1000)
    end

end)

---------------------------------------------------------------------
-- player combat log check
---------------------------------------------------------------------
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local health = GetEntityHealth(cache.ped)
    if PlayerData.metadata['isdead'] then
        if health ~= 0 and deathactive == false then
            SetEntityHealth(cache.ped, 0)
            PlayerDeath()
        end
    end

    -- Fetch initial injuries for animation
    Wait(2000)
    RSGCore.Functions.TriggerCallback('rsg-medic:server:getPlayerInjuries', function(injuries)
        if injuries then
        for _, part in ipairs(Config.InjuryBodyParts) do
            local state = injuries[part.name]
            if state ~= 'healthy' then
                _hasSevereInjury = true
                break
            end
            end
        end
    end, cache.serverId)
end)

---------------------------------------------------------------------
-- display respawn message and countdown
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local t = 1000

        if deathactive then
            t = 4

            if deathTimerStarted and deathSecondsRemaining > 0 then
                DrawTxt(locale('cl_respawn') .. deathSecondsRemaining .. locale('cl_seconds'), 0.50, 0.80, 0.5, 0.5, true, 104, 244, 120, 200, true)
            end

            if deathTimerStarted and deathSecondsRemaining == 0 and medicsonduty == 0 then
                DrawTxt(locale('cl_press_respawn'), 0.50, 0.85, 0.5, 0.5, true, 104, 244, 120, 200, true)
            end

            if deathTimerStarted and deathSecondsRemaining < Config.DeathTimer and medicsonduty > 0 and not medicCalled then
                if deathSecondsRemaining == 0 then
                    DrawTxt(locale('cl_press_respawn_b'), 0.50, 0.85, 0.5, 0.5, true, 104, 244, 120, 200, true)
                else
                    DrawTxt(locale('cl_press_assistance'), 0.50, 0.85, 0.5, 0.5, true, 104, 244, 120, 200, true)
                end
            end

            if deathTimerStarted and deathSecondsRemaining == 0 and IsControlPressed(0, RSGCore.Shared.Keybinds['E']) then
                deathTimerStarted = false

                TriggerEvent('rsg-medic:client:revive')
                TriggerServerEvent('rsg-medic:server:deathactions')
                if Config.WipeInventoryOnRespawn then
                    RemoveAllPedWeapons(cache.ped, true)
                    RemoveAllPedAmmo(cache.ped)
                end
            end

            if deathactive and deathTimerStarted and deathSecondsRemaining < Config.DeathTimer and IsControlPressed(0, RSGCore.Shared.Keybinds['G']) and not medicCalled then
                medicCalled = true

                if medicsonduty == 0 then
                    MedicCalled()

                    goto continue
                end

                local text = locale('cl_medical_help')

                TriggerServerEvent('rsg-medic:server:medicAlert', text)

                lib.notify({ title = locale('cl_medical_called'), type = 'success', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })

                MedicCalled()

                ::continue::
            end
        end

        if Config.Debug then
            print('deathTimerStarted: '..tostring(deathTimerStarted))
            print('deathSecondsRemaining: '..tostring(deathSecondsRemaining))
            print('medicsonduty: '..tostring(medicsonduty))
        end

        Wait(t)
    end
end)

-------------------------------------------------------- EVENTS --------------------------------------------------------

---------------------------------------------------------------------
-- medic menu
---------------------------------------------------------------------
---------------------------------------------------------------------
-- medic office NUI (duty / supplies / storage)
---------------------------------------------------------------------
local function GetDutyState()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.job then
        return PlayerData.job.onduty or false
    end
    return false
end

local function OpenMedicDutyUI(title)
    local items = {}
    for i = 1, #Config.MedicShopItems do
        local item = Config.MedicShopItems[i]
        items[#items + 1] = { name = item.name, label = item.label, price = item.price }
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showDuty',
        onDuty = GetDutyState(),
        locName = title or mediclocation or 'Medic Office',
        items = items,
    })
end

RegisterNUICallback('dutyToggle', function(_, cb)
    local job = RSGCore.Functions.GetPlayerData().job.name
    if job ~= Config.JobRequired then
        lib.notify({ title = locale('cl_not_medic'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        cb({})
        return
    end

    TriggerServerEvent("RSGCore:ToggleDuty")
    Wait(600)
    SendNUIMessage({ type = 'dutyState', onDuty = GetDutyState() })
    cb({})
end)

RegisterNUICallback('buyMedicItem', function(data, cb)
    local job = RSGCore.Functions.GetPlayerData().job.name
    if job ~= Config.JobRequired then
        cb({})
        return
    end

    TriggerServerEvent('rsg-medic:server:buyMedicItem', data.name, data.price)
    cb({})
end)

RegisterNUICallback('openStorage', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hideDuty' })
    TriggerEvent('rsg-medic:client:storage')
    cb({})
end)

RegisterNUICallback('closeDuty', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

AddEventHandler('rsg-medic:client:mainmenu', function(location, name)
    local job = RSGCore.Functions.GetPlayerData().job.name
    if job ~= Config.JobRequired then
        lib.notify({ title = locale('cl_not_medic'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        return
    end

    mediclocation = location
    OpenMedicDutyUI(name)
end)

AddEventHandler('rsg-medic:client:OpenMedicSupplies', function()
    local job = RSGCore.Functions.GetPlayerData().job.name
    if job ~= Config.JobRequired then return end

    OpenMedicDutyUI()
    SendNUIMessage({ type = 'showDutySupplies' })
end)


---------------------------------------------------------------------
-- death cam
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:DeathCam', function()
    CreateThread(function()
        while true do
            Wait(1000)

            if not Dead and deathactive then
                Dead = true
                StartDeathCam()
            elseif Dead and not deathactive then
                Dead = false
                EndDeathCam()
            end

            if deathSecondsRemaining <= 0 and not deathactive then
                Dead = false
                EndDeathCam()
                return
            end
        end
    end)

    CreateThread(function()
        while true do
            Wait(4)

            if deadcam and Dead then
                ProcessCamControls()
            end

            if deathactive and not deadcam then
                StartDeathCam()
            end

            if deathSecondsRemaining <= 0 and not deathactive then return end
        end
    end)
end)

---------------------------------------------------------------------
-- get medics on-duty
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:GetMedicsOnDuty', function()
    RSGCore.Functions.TriggerCallback('rsg-medic:server:getmedics', function(mediccount)
        medicsonduty = mediccount
    end)
end)
---------------------------------------------------------------------
-- player revive after pressing [E]
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:revive', function()
    SetClosestRespawn()

    if deathactive then
        DoScreenFadeOut(500)

        Wait(1000)

        local respawnPos = Config.RespawnLocations[closestRespawn].coords
        NetworkResurrectLocalPlayer(respawnPos, true, false)
        ClearPedBloodDamage(cache.ped)
        SetAttributeCoreValue(cache.ped, 0, 100) -- SetAttributeCoreValue
        SetAttributeCoreValue(cache.ped, 1, 100) -- SetAttributeCoreValue
        TriggerEvent('hud:client:UpdateNeeds', 100, 100, 100)
        TriggerEvent('hud:client:UpdateStress', 0)

        -- Reset Outlaw Status on respawn
        if Config.ResetOutlawStatus then
            TriggerServerEvent('rsg-prison:server:resetoutlawstatus')
        end

        -- Reset Death Timer
        deathactive = false
        deathTimerStarted = false
        medicCalled = false
        deathSecondsRemaining = 0

        AnimpostfxPlay("Title_Gen_FewHoursLater", 0, false)
        Wait(3000)
        DoScreenFadeIn(2000)
        AnimpostfxPlay("PlayerWakeUpInterrogation", 0, false)
        Wait(19000)

        TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
        LocalPlayer.state:set('isDead', false, true)
        TriggerServerEvent('rsg-medic:server:resetPlayerInjuries')
    end
end)

---------------------------------------------------------------------
-- admin revive
---------------------------------------------------------------------
RegisterNetEvent('rsg-medic:client:adminRevive', function()
    local pos = GetEntityCoords(cache.ped, true)

    DoScreenFadeOut(500)

    Wait(1000)

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(cache.ped), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    SetAttributeCoreValue(cache.ped, 0, 100) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 100) -- SetAttributeCoreValue
    TriggerEvent('hud:client:UpdateNeeds', 100, 100, 100)
    TriggerEvent('hud:client:UpdateStress', 0)

    -- Reset Outlaw Status on respawn
    if Config.ResetOutlawStatus then
        TriggerServerEvent('rsg-prison:server:resetoutlawstatus')
    end

    -- Reset Death Timer
    deathactive = false
    deathTimerStarted = false
    medicCalled = false
    deathSecondsRemaining = 0

    Wait(1500)

    DoScreenFadeIn(1800)

    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
    LocalPlayer.state:set('isDead', false, true)

    TriggerServerEvent('rsg-medic:server:resetPlayerInjuries')
end)

---------------------------------------------------------------------
-- player revive
---------------------------------------------------------------------
RegisterNetEvent('rsg-medic:client:playerRevive', function()
    local pos = GetEntityCoords(cache.ped, true)

    DoScreenFadeOut(500)

    Wait(1000)

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(cache.ped), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    SetAttributeCoreValue(cache.ped, 0, Config.MedicReviveHealth) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 0) -- SetAttributeCoreValue
    LocalPlayer.state:set('health', math.round(Config.MaxHealth * (Config.MedicReviveHealth / 100)), true)

    -- Reset Outlaw Status on respawn
    if Config.ResetOutlawStatus then
        TriggerServerEvent('rsg-prison:server:resetoutlawstatus')
    end

    -- Reset Death Timer
    deathactive = false
    deathTimerStarted = false
    medicCalled = false
    deathSecondsRemaining = 0

    Wait(1500)

    DoScreenFadeIn(1800)

    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
    LocalPlayer.state:set('isDead', false, true)
end)

-- When treated with bandage, fetch updated injuries from server
RegisterNetEvent('rsg-medic:client:HealInjuries', function()
    local Player = RSGCore.Functions.GetPlayerData()
    if Player then
        RSGCore.Functions.TriggerCallback('rsg-medic:server:getPlayerInjuries', function(injuries)
            -- Injuries already updated on server; no local UI update needed
        end, cache.serverId)
    end
end)

---------------------------------------------------------------------
-- admin Heal
---------------------------------------------------------------------
RegisterNetEvent('rsg-medic:client:adminHeal', function()
    local pos = GetEntityCoords(cache.ped, true)
    Wait(1000)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(cache.ped), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    SetAttributeCoreValue(cache.ped, 0, 100) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 100) -- SetAttributeCoreValue
    TriggerEvent('hud:client:UpdateNeeds', 100, 100, 100)
    TriggerEvent('hud:client:UpdateStress', 0)
    LocalPlayer.state:set('health', Config.MaxHealth, true)
    lib.notify({title = 'You have been Healed', duration = 5000, type = 'inform'})
end
)
---------------------------------------------------------------------
-- medic storage
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:storage', function()
    local job = RSGCore.Functions.GetPlayerData().job.name
    local stashloc = mediclocation

    if job ~= Config.JobRequired then return end
    TriggerServerEvent('rsg-medic:server:openstash', stashloc)
end)

---------------------------------------------------------------------
-- kill player
---------------------------------------------------------------------
RegisterNetEvent('rsg-medic:client:KillPlayer')
AddEventHandler('rsg-medic:client:KillPlayer', function()
    SetEntityHealth(cache.ped, 0)
    TriggerServerEvent('RSGCore:Server:SetMetaData', 'isdead', true)
    LocalPlayer.state:set('isDead', true, true)
end)

---------------------------------------------------------------------
-- use bandage
---------------------------------------------------------------------
RegisterNetEvent('rsg-medic:client:usebandage', function()
    if isBusy then return end
    local hasItem = RSGCore.Functions.HasItem('bandage', 1)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not PlayerData.metadata['isdead'] and not PlayerData.metadata['ishandcuffed'] and not IsPedOnMount(cache.ped) then
        if hasItem then
            isBusy = true
            LocalPlayer.state:set('inv_busy', true, true)
            SetCurrentPedWeapon(cache.ped, GetHashKey('weapon_unarmed'))

            lib.progressBar({
                duration = Config.BandageTime,
                position = 'bottom',
                useWhileDead = false,
                canCancel = false,
                disableControl = true,
                disable = {
                    move = true,
                    mouse = true,
                },
                anim = {
                    dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
                    clip = 'bandage_fast',
                    flag = 1,
                },
                label = locale('cl_progress'),
            })

            local currenthealth = GetEntityHealth(cache.ped)
            local newhealth = lib.math.clamp(math.round(currenthealth + (600 * (Config.BandageHealth / 100))), 0, 600)
            SetEntityHealth(cache.ped, newhealth)

            TriggerServerEvent('rsg-medic:server:removeitem', 'bandage', 1)
            TriggerServerEvent('rsg-medic:server:healSelfInjury')
            LocalPlayer.state:set('inv_busy', false, true)
            isBusy = false
        else
            lib.notify({ title = locale('cl_error'), description = locale('cl_error_b'), type = 'error', duration = 5000 })
        end
    else
        lib.notify({ title = locale('cl_error'), description = locale('cl_error_c'), type = 'error', duration = 5000 })
    end
end)
RegisterNetEvent('rsg-medic:client:usefieldbandage', function()
    if isBusy then return end
    local hasItem = RSGCore.Functions.HasItem('fieldbandage', 1)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not PlayerData.metadata['isdead'] and not PlayerData.metadata['ishandcuffed'] and not IsPedOnMount(cache.ped) then
        if hasItem then
            isBusy = true
            LocalPlayer.state:set('inv_busy', true, true)
            SetCurrentPedWeapon(cache.ped, GetHashKey('weapon_unarmed'))

            lib.progressBar({
                duration = Config.BandageTime,
                position = 'bottom',
                useWhileDead = false,
                canCancel = false,
                disableControl = true,
                disable = {
                    move = true,
                    mouse = true,
                },
                anim = {
                    dict = 'mini_games@story@mob4@heal_jules@bandage@arthur',
                    clip = 'bandage_fast',
                    flag = 1,
                },
                label = locale('cl_progress'),
            })

            local currenthealth = GetEntityHealth(cache.ped)
            local newhealth = lib.math.clamp(math.round(currenthealth + (600 * (Config.BandageHealth / 100))), 0, 600)
            SetEntityHealth(cache.ped, newhealth)

            TriggerServerEvent('rsg-medic:server:removeitem', 'fieldbandage', 1)
            TriggerServerEvent('rsg-medic:server:healSelfInjury')
            LocalPlayer.state:set('inv_busy', false, true)
            isBusy = false
        else
            lib.notify({ title = locale('cl_error'), description = locale('cl_error_b'), type = 'error', duration = 5000 })
        end
    else
        lib.notify({ title = locale('cl_error'), description = locale('cl_error_c'), type = 'error', duration = 5000 })
    end
end)
---------------------------------------------------------------------
-- INJURY SYSTEM
---------------------------------------------------------------------

-- Map RedM bone index to body part name
local function GetBodyPartFromBone(boneIndex)
    return Config.BoneToBodyPart[boneIndex]
end

-- Track weapon damage hits on body parts
local _lastHealth = Config.MaxHealth
local _lastPed = nil
CreateThread(function()
    while true do
        Wait(250)
        if LocalPlayer.state['isLoggedIn'] and not deathactive then
            local ped = cache.ped
            if ped ~= _lastPed then
                _lastPed = ped
                _lastHealth = GetEntityHealth(ped)
            end
            local health = GetEntityHealth(ped)
            if health < Config.MaxHealth and health > 0 then
                if _lastHealth and (_lastHealth - health) >= Config.InjuryDamageThreshold then
                    -- Significant damage detected, assign random body part hit
                    local parts = Config.InjuryBodyParts
                    local part = parts[math.random(#parts)]
                    TriggerServerEvent('rsg-medic:server:recordBodyHit', part.name)
                end
                _lastHealth = health
            end
        end
    end
end)

-- On death, apply random injuries
local originalPlayerDeath = PlayerDeath
PlayerDeath = function()
    TriggerServerEvent('rsg-medic:server:applyDeathInjuries')
    originalPlayerDeath()
end

-- Open skeleton NUI
RegisterNetEvent('rsg-medic:client:openSkeletonNUI', function(injuries, patientName, targetSrc)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        type = 'showInjuries',
        injuries = injuries,
        patientName = patientName or 'Patient',
    })
    if targetSrc then
        TriggerServerEvent('rsg-medic:server:watchSkeleton', targetSrc)
    end
end)

-- NUI close callback
RegisterNUICallback('closeSkeleton', function(_, cb)
    TriggerServerEvent('rsg-medic:server:unwatchSkeleton')
    SetNuiFocus(false, false)
    cb({})
end)

---------------------------------------------------------------------
-- INJURY ANIMATION
---------------------------------------------------------------------
-- Track worst injury state for animation
local _hasSevereInjury = false
local _localInjuries = nil
local _injuredMeThread = nil

-- Real-time injury update: forwards NUI and tracks severe injury for animation
RegisterNetEvent('rsg-medic:client:updateInjuries', function(targetSrc, injuries, patientName)
    if targetSrc == cache.serverId then
        local severe = false
        for _, part in ipairs(Config.InjuryBodyParts) do
            local state = injuries[part.name]
            if state ~= 'healthy' then severe = true break end
        end
        _hasSevereInjury = severe
        _localInjuries = injuries
        LocalPlayer.state:set('isInjured', severe, true)

        if severe then
            if not _injuredMeThread then
                _injuredMeThread = true
                CreateThread(function()
                    while _hasSevereInjury do
                        ExecuteCommand('me INJURED')
                        Wait(3000)
                    end
                    _injuredMeThread = nil
                end)
            end
        end
    else
        SendNUIMessage({
            type = 'showInjuries',
            injuries = injuries,
            patientName = patientName or 'Patient',
        })
    end
end)

-- Walk styles / animations used when injured
CreateThread(function()
    while true do
        Wait(2000)
        if LocalPlayer.state['isLoggedIn'] and not deathactive and not isBusy then
            local hasInjury = false
            local injuries = _localInjuries
            if not injuries then
                local data = RSGCore.Functions.GetPlayerData()
                if data and data.metadata and data.metadata['injuries'] then
                    injuries = data.metadata['injuries']
                end
            end
            if injuries then
                for _, part in ipairs(Config.InjuryBodyParts) do
                    if injuries[part.name] ~= 'healthy' then
                        hasInjury = true
                        break
                    end
                end
            end

            if hasInjury then
                Citizen.InvokeNative(0x406CCF555B04FAD3, PlayerPedId(), 1, 0.85)
            else
                Citizen.InvokeNative(0x406CCF555B04FAD3, PlayerPedId(), 1, 0.0)
            end
        end
    end
end)

-------------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    DestroyAllCams(true)

    for i = 1, #createdEntries do
        if createdEntries[i].type == "BLIP" then
            if createdEntries[i].handle then
                RemoveBlip(createdEntries[i].handle)
            end
        end

        if createdEntries[i].type == "PROMPT" then
            if createdEntries[i].handle then
                exports['rsg-core']:deletePrompt(createdEntries[i].handle)
            end
        end
    end
end)

