-----------------------------------------------------------------------
-- Discord Webhook Logging System for rsg-medic
--
-- Provides a single global function, SendDiscordWebhook(category, title,
-- description, fields, footerText), that any script in this resource can
-- call to log an event to Discord as a rich embed.
--
-- Sends are queued per-process and drip-fed with a delay between each
-- request so a burst of events (e.g. several deaths at once) can't trip
-- Discord's rate limit; a 429 response is honoured and retried instead
-- of being dropped or spammed.
-----------------------------------------------------------------------

local webhookQueue = {}
local queueRunning = false
local backoffUntil = 0

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function IsCategoryEnabled(category)
    if not Config.Webhooks or not Config.Webhooks.enabled then return false end
    if not Config.Webhooks.logging or Config.Webhooks.logging[category] == false then return false end
    return true
end

local function GetWebhookURL(category)
    local url = Config.Webhooks and Config.Webhooks.urls and Config.Webhooks.urls[category]
    if not url or url == '' then return nil end
    return url
end

local function ISOTimestamp()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

---------------------------------------------------------------------
-- queue processor
---------------------------------------------------------------------
local function ProcessWebhookQueue()
    if queueRunning then return end
    queueRunning = true

    CreateThread(function()
        while #webhookQueue > 0 do
            local now = GetGameTimer()
            if now < backoffUntil then
                Wait(backoffUntil - now)
            end

            local job = table.remove(webhookQueue, 1)
            local requeued = false

            PerformHttpRequest(job.url, function(statusCode, response, headers)
                if statusCode == 429 then
                    local retryAfterMs = 2000
                    if headers and headers['Retry-After'] then
                        retryAfterMs = (tonumber(headers['Retry-After']) or 2) * 1000
                    end
                    backoffUntil = GetGameTimer() + retryAfterMs
                    job.attempts = (job.attempts or 0) + 1
                    if job.attempts <= 5 then
                        table.insert(webhookQueue, 1, job)
                        requeued = true
                    elseif Config.Debug then
                        print('[rsg-medic] Discord webhook dropped after 5 rate-limited attempts')
                    end
                elseif Config.Debug and statusCode ~= 200 and statusCode ~= 204 then
                    print(('[rsg-medic] Discord webhook failed (HTTP %s): %s'):format(statusCode, tostring(response)))
                end
            end, 'POST', json.encode(job.payload), { ['Content-Type'] = 'application/json' })

            if not requeued then
                Wait(750) -- stay comfortably under Discord's per-webhook rate limit (~30/min)
            end
        end

        queueRunning = false
    end)
end

---------------------------------------------------------------------
-- public API
---------------------------------------------------------------------
-- category: one of the keys in Config.Webhooks.urls / .logging / .colors
-- title / description: embed title + body text
-- fields: optional array of { name = '...', value = '...', inline = true/false }
-- footerText: optional footer override
function SendDiscordWebhook(category, title, description, fields, footerText)
    if not IsCategoryEnabled(category) then return end

    local url = GetWebhookURL(category)
    if not url then return end

    local embed = {
        title = title,
        description = description,
        color = (Config.Webhooks.colors and Config.Webhooks.colors[category]) or 0x3498DB,
        fields = fields or {},
        footer = { text = footerText or 'rsg-medic' },
        timestamp = ISOTimestamp(),
    }

    local avatar = Config.Webhooks.botAvatar
    webhookQueue[#webhookQueue + 1] = {
        url = url,
        attempts = 0,
        payload = {
            username = Config.Webhooks.botName or 'RSG Medic',
            avatar_url = (avatar and avatar ~= '') and avatar or nil,
            embeds = { embed },
        },
    }

    ProcessWebhookQueue()
end

-- small helper other files can use to build a consistent "who" field
function GetWebhookPlayerLabel(Player)
    if not Player then return 'Unknown' end
    local charinfo = Player.PlayerData.charinfo
    local name = (charinfo and charinfo.firstname and charinfo.lastname)
        and (charinfo.firstname .. ' ' .. charinfo.lastname)
        or (GetPlayerName(Player.PlayerData.source) or 'Unknown')

    return ('%s (%s) [server id: %s]'):format(name, Player.PlayerData.citizenid, Player.PlayerData.source)
end
