local RSGCore = exports['rsg-core']:GetCoreObject()
local sharedWeapons = exports['rsg-core']:GetWeapons()
lib.locale()
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

    local groundZ = coords.z
    local success, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, false)

    if success then
        groundZ = z
    end
    local camZ = math.max(coords.z + 1.0, groundZ + 1.0)

    deadcam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords.x, coords.y, camZ, 0.0, 0.0, 0.0, fov)
    SetCamActive(deadcam, true)
    RenderScriptCams(true, true, 1000, true, false)
end

---------------------------------------------------------------------
-- end death cam
---------------------------------------------------------------------
local EndDeathCam = function()
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
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
    local behindCam = {
        x = pCoords.x + ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * (0.5 + 0.5),
        y = pCoords.y + ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * (0.5 + 0.5),
        z = pCoords.z + ((Sin(angleY))) * (0.5 + 0.5)
    }

    local rayHandle = StartShapeTestRay(pCoords.x, pCoords.y, pCoords.z + 0.5, behindCam.x, behindCam.y, behindCam.z, -1, cache.ped, 0)
    local _, hitBool, hitCoords, _, _ = GetShapeTestResult(rayHandle)
    local maxRadius = 2.5

    if (hitBool and Vdist(pCoords.x, pCoords.y, pCoords.z + 0.0, hitCoords) < 0.5 + 0.5) then
        maxRadius = Vdist(pCoords.x, pCoords.y, pCoords.z + 0.0, hitCoords)
    end

    local offset = {
        x = ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * maxRadius,
        y = ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * maxRadius,
        z = ((Sin(angleY))) * maxRadius
    }

    local pos = { x = pCoords.x + offset.x, y = pCoords.y + offset.y, z = pCoords.z + offset.z }
    return pos
end

---------------------------------------------------------------------
-- process camera controls
---------------------------------------------------------------------
local ProcessCamControls = function()
    local playerCoords = GetEntityCoords(cache.ped)
    DisableOnFootFirstPersonViewThisUpdate()    -- disable 1st person as the 1st person camera can cause some glitches
    local newPos = ProcessNewPosition()    -- calculate new position
    if deadcam then
        SetCamCoord(deadcam, newPos.x, newPos.y, newPos.z)    -- set coords of cam
        PointCamAtCoord(deadcam, playerCoords.x, playerCoords.y, playerCoords.z)    -- set rotation
    end
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
    local weaponItem = sharedWeapons[killerWeapon] or {}
    if weaponItem then
        weaponLabel = weaponItem.label
        weaponName = weaponItem.name
    end

    local playerid = GetPlayerServerId(player)
    local playername = GetPlayerName(player)
    local msgDiscordA = playername..' ('..playerid..') '.. locale('cl_death_log_title')
    local msgDiscordB = string.format("%s %s %s %s **%s** (%s)", killerName, locale('cl_death_log_message'), playername, locale('cl_death_log_message_b'), weaponLabel, weaponName)
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
            SetBlipSprite(MedicBlip, joaat(Config.Blip.blipSprite), true)
            SetBlipScale(MedicBlip, Config.Blip.blipScale)
            SetBlipName(MedicBlip, Config.Blip.blipName)

            createdEntries[#createdEntries + 1] = {type = "BLIP", handle = MedicBlip}
        end
    end
end)

---------------------------------------------------------------------
-- player death loop
---------------------------------------------------------------------
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state['isLoggedIn']
    while true do
        local health = GetEntityHealth(cache.ped)
        local sleep = 1000
        if health == 0 and deathactive == false and not LocalPlayer.state.invincible then
            sleep = 0
            exports.spawnmanager:setAutoSpawn(false)
            deathTimerStarted = true
            deathTimer()
            deathLog()
            deathactive = true
            SetEntityHealth(cache.ped, 0)
            TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", true)
            LocalPlayer.state:set('isDead', true, true)
            TriggerEvent('rsg-medic:client:DeathCam')
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- player update health loop
---------------------------------------------------------------------
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state['isLoggedIn']
    while true do
        local sleep = 1000
        if not LocalPlayer.state.invincible then
            local health = GetEntityHealth(cache.ped)
            if LocalPlayer.state.health ~= health then
                sleep = 0
                LocalPlayer.state:set('health', health, true)
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- display respawn message and countdown
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local t = 1000

        if deathactive then
            t = 4
            -- local coord = GetEntityCoords(cache.ped)
            -- local coord = 'bottom-center'

            if deathTimerStarted then
                if deathSecondsRemaining > 0 then
                    DrawTxt( locale('cl_respawn') .. deathSecondsRemaining .. locale('cl_seconds'), 0.50, 0.80, 0.5, 0.5, true, 139, 0,   0,   200, true )

                    if not medicCalled then
                        if medicsonduty > 0 then
                            DrawTxt( locale('cl_press_assistance'), 0.50, 0.85, 0.5, 0.5, true, 255, 215,   0, 200, true )
                        elseif Config.doctorAi then
                            DrawTxt( locale('cl_press_assistance'), 0.50, 0.85, 0.5, 0.5, true, 218, 165,  32, 200, true )
                        end
                    end
                elseif deathSecondsRemaining == 0 and not medicCalled then
                    if medicsonduty == 0 then
                        if Config.doctorAi then
                            DrawTxt( locale('cl_press_respawn_b'), 0.50, 0.85, 0.5, 0.5, true, 218, 165,  32, 200, true )
                        else
                            DrawTxt( locale('cl_press_respawn'), 0.50, 0.85, 0.5, 0.5, true, 255, 215,   0, 200, true )
                        end
                    else
                        DrawTxt( locale('cl_press_respawn_b'), 0.50, 0.85, 0.5, 0.5, true, 255, 215,   0, 200, true )
                    end
                end
            end

            if deathTimerStarted and deathSecondsRemaining == 0 and IsControlPressed(0, RSGCore.Shared.Keybinds['E']) then
                deathTimerStarted = false

                -- lib.hideTextUI()
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
                    if Config.doctorAi then
                        ExecuteCommand('helpdoctor')
                        lib.notify({ title = locale('cl_medical_called'), type = 'success', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
                    end
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
AddEventHandler('rsg-medic:client:mainmenu', function(location, name)
    local job = RSGCore.Functions.GetPlayerData().job.name
    if job ~= Config.JobRequired then
        lib.notify({ title = locale('cl_not_medic'), type = 'error', icon = 'fa-solid fa-kit-medical', iconAnimation = 'shake', duration = 7000 })
        return
    end

    mediclocation = location

    lib.registerContext({
        id = "medic_mainmenu",
        title = name,
        options = {
             {   title = locale('cl_employees'),
                icon = 'fa-solid fa-list',
                description = locale('cl_employees_b'),
                event = 'rsg-bossmenu:client:mainmenu',
                isBoss = true
            },
            {   title = locale('cl_duty'),
                icon = 'fa-solid fa-shield-heart',
                event = 'rsg-medic:client:ToggleDuty',
                arrow = true
            },
            {   title = locale('cl_medical_supplies'),
                icon = 'fa-solid fa-pills',
                event = 'rsg-medic:client:OpenMedicSupplies',
                arrow = true
            },
            {   title = locale('cl_medical_storage'),
                icon = 'fa-solid fa-box-open',
                event = 'rsg-medic:client:storage',
                arrow = true
            },
        }
    })
    lib.showContext("medic_mainmenu")
end)

---------------------------------------------------------------------
-- medic supplies
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:OpenMedicSupplies', function()
    local job = RSGCore.Functions.GetPlayerData().job.name
    if job ~= Config.JobRequired then return end
    TriggerServerEvent('rsg-shops:server:openstore', 'medic', 'medic', locale('cl_medical_supplies'))
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
            Wait(200)

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

-- Player Revive After Pressing [E]
AddEventHandler('rsg-medic:client:revive', function()
    SetClosestRespawn()

    if deathactive then
        DoScreenFadeOut(500)

        Wait(1000)

        local respawnPos = Config.RespawnLocations[closestRespawn].coords
        NetworkResurrectLocalPlayer(respawnPos, true, false)
        SetEntityInvincible(cache.ped, false)
        ClearPedBloodDamage(cache.ped)
        SetAttributeCoreValue(cache.ped, 0, Config.ReviveHealth)
        SetAttributeCoreValue(cache.ped, 1, 0)
        LocalPlayer.state:set('health', math.round(Config.MaxHealth * (Config.ReviveHealth / 100)), true)

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
    end
end)

---------------------------------------------------------------------
-- admin revive
---------------------------------------------------------------------
-- Admin Revive
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

    lib.hideTextUI()
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

    lib.hideTextUI()
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
    lib.notify({title = locale('cl_medical_health'), duration = 5000, type = 'inform'})
end)

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
end)

---------------------------------------------------------------------
-- use bandage
---------------------------------------------------------------------
RegisterNetEvent('rsg-medic:client:usebandage', function()
    if isBusy then return end
    local hasItem = RSGCore.Functions.HasItem('bandage', 1)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not PlayerData.metadata['isdead'] and not PlayerData.metadata['ishandcuffed'] then
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

    -- lib.hideTextUI()

    createdEntries = {}
    deathSecondsRemaining = 0
    deathTimerStarted = false
    deathactive = false
    medicsonduty = 0
    medicCalled = false
    Dead = false
    deadcam = nil
    LocalPlayer.state:set('inv_busy', false, true)
    isBusy = false
end)