Config = {}

-- Settings
Config.Debug                    = false
Config.JobRequired              = 'medic'
Config.StorageMaxWeight         = 4000000
Config.StorageMaxSlots          = 48
Config.DeathTimer               = 60 -- 60 = 1 min
Config.WipeInventoryOnRespawn   = false
Config.WipeCashOnRespawn        = false
Config.WipeBloodmoneyOnRespawn  = false
Config.MaxHealth                = 600
Config.MedicReviveTime          = 5000
Config.MedicTreatTime           = 5000
Config.MedicTreatHealth         = 30 -- percentage of max health when player is healed by medic
Config.ReviveHealth             = 20 -- percentage of max health when player revive after pressing [E]
Config.MedicReviveHealth        = 60 -- percentage of max health when player is revived by medic
Config.AddGPSRoute              = true
Config.MedicCallDelay           = 60 -- delay in seconds before calling medic again
Config.BandageTime              = 10000
Config.BandageHealth            = 15 -- percentage of max health when player use bandage
Config.ResetOutlawStatus        = true
Config.SaltyChat = false

-- Blip Settings
Config.Blip =
{
    blipName   = 'Medic', -- Config.Blip.blipName
    blipSprite = 'blip_shop_doctor', -- Config.Blip.blipSprite
    blipScale  = 0.2 -- Config.Blip.blipScale
}

-- Prompt Locations
Config.MedicJobLocations =
{
    {name = 'Valentine Medic', prompt = 'valmedic', coords = vector3(-287.59, 811.28, 119.39 -0.8), showblip = true} -- Valentine
}

-----------------------------------------------------------------------
-- Discord Webhook Logging
-----------------------------------------------------------------------
-- Create webhooks in your Discord channel settings (Integrations > Webhooks)
-- and paste the URLs below. Leave a url as '' (empty string) to disable
-- that specific log category — or set Config.Webhooks.enabled = false to
-- disable the whole system in one go.
Config.Webhooks =
{
    enabled   = true,              -- master on/off switch
    botName   = 'RSG Medic',       -- name shown as the webhook's author
    botAvatar = '',                -- optional avatar image URL, e.g. 'https://i.imgur.com/yourlogo.png'

    -- Discord webhook URLs, one per log category. Point several categories
    -- at the same URL if you only want a single log channel.
    urls =
    {
        death     = '', -- player deaths (killer, weapon, location)
        revive    = '', -- medic revives / heals a patient
        treatment = '', -- medic treats wounds
        duty      = '', -- medic clocks on/off duty
        admin     = '', -- /revive /heal /kill admin commands
        storage   = '', -- medic storage (stash) access
    },

    -- per-category on/off switches (independent of Config.Webhooks.enabled)
    logging =
    {
        death      = true,
        revive     = true,
        treatment  = true,
        duty       = true,
        admin      = true,
        storage    = true,
        bandageUse = false, -- logs every self-applied bandage; off by default, can be spammy
    },

    -- embed side-bar colours (decimal, not hex string)
    colors =
    {
        death     = 0xC0392B, -- red
        revive    = 0x27AE60, -- green
        treatment = 0x2ECC71, -- light green
        duty      = 0x3498DB, -- blue
        admin     = 0xF1C40F, -- yellow
        storage   = 0x9B59B6, -- purple
    },
}

-- Respawn Locations
Config.RespawnLocations =
{
    [1] = {coords = vector4(-242.69, 796.27, 121.16, 110.18)}, -- Valentine
    [2] = {coords = vector4(-733.28, -1242.97, 44.73, 87.64)}, -- Blackwater
    [3] = {coords = vector4(-1801.98, -366.95, 161.66, 236.04)}, -- Strawberry
    [4] = {coords = vector4(-3613.85, -2640.1, -11.73, 47.92)}, -- Armadillo
    [5] = {coords = vector4(-5436.5, -2930.96, 0.69, 182.25)}, -- Tumbleweed
    [6] = {coords = vector4(2725.33, -1067.42, 47.4, 168.42)}, -- Saint Denis
    [7] = {coords = vector4(1291.85, -1236.22, 80.93, 210.67)}, -- Rhodes
    [8] = {coords = vector4(3033.01, 433.82, 63.81, 65.9)}, -- Van Horn
    [9] = {coords = vector4(3016.71, 1345.64, 42.69, 67.85)} -- Annesburg
}
