Config = {}

-- Settings
Config.Debug                    = false
Config.JobRequired              = 'medic'
Config.StorageMaxWeight         = 4000000
Config.StorageMaxSlots          = 48
Config.DeathTimer               = 300 -- 300 = 5 mins / testing 60 = 1 min
Config.WipeInventoryOnRespawn   = false
Config.WipeCashOnRespawn        = false
Config.WipeBloodmoneyOnRespawn  = false
Config.MaxHealth                = 600
Config.MedicReviveTime          = 5000
Config.MedicTreatTime           = 5000
Config.MedicTreatHealth         = 30 -- percetnate of max health when player is healed by medic
Config.ReviveHealth             = 20 -- percentage of max health when player revive after pressing [E]
Config.MedicReviveHealth        = 60 -- percentage of max health when player is revived by medic
Config.AddGPSRoute              = true
Config.MedicCallDelay           = 60 -- delay in seconds before calling medic again
Config.BandageTime              = 10000
Config.BandageHealth            = 15 -- percetnate of max health when player use bandage
Config.ResetOutlawStatus        = true
Config.InjuryDamageThreshold    = 20 -- minimum health lost before injury can trigger

-- Blip Settings
Config.Blip =
{
    blipName   = 'Medic', -- Config.Blip.blipName
    blipSprite = 'blip_shop_doctor', -- Config.Blip.blipSprite
    blipScale  = 0.2 -- Config.Blip.blipScale
}
Config.MedicShopItems = {
    { name = 'bandage',      label = 'Bandage',       price = 0 },
    { name = 'firstaid',     label = 'First Aid Kit', price = 0 },
    { name = 'fieldbandage', label = 'Field Bandage', price = 0 },
}
-- Prompt Locations
Config.MedicJobLocations =
{
    {name = 'Valentine Medic', prompt = 'valmedic', coords = vector3(-287.59, 811.28, 119.39 -0.8), showblip = true} -- Valentine
}

-- Respawn Locations
Config.RespawnLocations =
{
    [1] = {coords = vector4(-242.69, 796.27, 121.16, 110.18)}, -- Valentine
    [2] = {coords = vector4(-733.28, -1242.97, 44.73, 87.64)}, -- Blackwater
    [3] = {coords = vector4(-1801.98, -366.95, 161.66, 236.04)}, -- Strawberry
    [4] = {coords = vector4(-3613.85, -2640.1, -11.73, 47.92)}, -- Armadillo
    [5] = {coords = vector4(-5436.5, -2930.96, 0.69, 182.25)}, -- Tumbleweed
    [6] = {coords = vector4(2725.33, -1067.42, 47.4, 168.42)}, -- Staint Denis
    [7] = {coords = vector4(1291.85, -1236.22, 80.93, 210.67)}, -- Rhodes
    [8] = {coords = vector4(3033.01, 433.82, 63.81, 65.9)}, -- Van Horn
    [9] = {coords = vector4(3016.71, 1345.64, 42.69, 67.85)} -- Annesburg
}

-- Injury System
Config.InjuryBodyParts = {
    { name = 'head',       label = 'Head' },
    { name = 'torso',      label = 'Torso' },
    { name = 'left_arm',   label = 'Left Arm' },
    { name = 'right_arm',  label = 'Right Arm' },
    { name = 'left_leg',   label = 'Left Leg' },
    { name = 'right_leg',  label = 'Right Leg' },
}

Config.InjuryStates = {
    healthy  = { label = 'Healthy' },
    injured  = { label = 'Injured' },
    broken   = { label = 'Broken' },
    bleeding = { label = 'Bleeding' },
}

-- RedM bone indices -> body part name mapping
Config.BoneToBodyPart = {
    [0] = 'head', [1] = 'head',
    [2] = 'torso', [3] = 'torso', [4] = 'torso', [5] = 'torso',
    [6] = 'torso', [7] = 'torso', [8] = 'torso',
    [9] = 'right_arm', [10] = 'right_arm', [11] = 'right_arm',
    [12] = 'left_arm', [13] = 'left_arm', [14] = 'left_arm',
    [15] = 'right_leg', [16] = 'right_leg',
    [17] = 'left_leg', [18] = 'left_leg',
}
