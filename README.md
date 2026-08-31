# rsg-medic

A medic/EMS job script for RedM servers running the **RSG-Core** framework. Handles death and respawn flow, a medic duty job with revive and wound-treatment abilities, a first-aid kit and bandage item, medic storage, a "call for help" system for injured players, admin revive/heal/kill commands, and full Discord webhook logging.

## Features

### Death & Respawn
- Configurable death timer with an on-screen countdown and a scripted death camera.
- Players can self-respawn with `[E]` once the timer expires, or call nearby on-duty medics for assistance with `[G]`.
- Optional wipe of inventory, cash, and/or bloodmoney on respawn (each independently toggleable).
- Optional automatic reset of outlaw/wanted status on respawn.
- Death events are logged with the killer's name and weapon.

### Medic Job
- Duty toggle, medical supplies shop access, and medic storage (stash) — all gated behind the configured medic job.
- **Revive**: consumes a first-aid kit, requires the medic to be on duty and within range of the patient (validated server-side).
- **Treat Wounds**: consumes a bandage, heals a configurable percentage of health, also validated server-side for duty status and proximity.
- **Bandage** item: usable by any player (not just medics) to self-heal a configurable amount over a timed progress bar.
- **Call for Medic**: injured players can page all on-duty medics, who get a notification, a GPS route, and a pulsing map blip to the caller's location. Rate-limited both client- and server-side to stop spam.
- Configurable spawn/prompt locations with map blips for each medic station.
- `SaltyChat` integration (optional) to mute/unmute proximity voice while a player is dead.

### Admin Commands
| Command | Description | Permission |
|---|---|---|
| `/revive [id]` | Revive yourself, or a target player if an ID is given | `admin` |
| `/heal [id]` | Fully heal yourself, or a target player if an ID is given | `admin` |
| `/kill <id>` | Kill a target player | `admin` |

### Discord Webhook Logging
A built-in, self-contained Discord logging system — no external logging resource required. Sends rich embeds for:
- Player deaths (killer + weapon)
- Respawn penalties applied (inventory/cash/bloodmoney wipes)
- Medic revives and wound treatments (who treated whom)
- Bandage self-use (off by default — can be noisy)
- Medic duty changes (on/off)
- Admin `/revive`, `/heal`, `/kill` usage
- Medic storage access

Each category has its own webhook URL, its own on/off switch, and its own embed color, so you can route different events to different channels (or one channel for everything) and mute anything you don't care about. Sends are queued and rate-limit-aware, so a burst of events won't get you throttled or dropped by Discord.

### Localization
Ships with 9 languages out of the box: English, German, Greek, Spanish, French, Italian, Polish, Brazilian Portuguese, and Romanian. Add more by dropping a new file in `locales/`.

### Version Checker
Checks your installed version against the latest release on GitHub at resource start and prints a warning to the server console if you're out of date.

## Dependencies

- [`rsg-core`](https://github.com/Rexshack-RedM) — the RSG-Core framework
- [`rsg-bossmenu`](https://github.com/Rexshack-RedM) — used for job management
- [`ox_lib`](https://github.com/overextended/ox_lib) — notifications, context menus, progress bars, locales
- [`oxmysql`](https://github.com/overextended/oxmysql) — database access
- [`rsg-inventory`](https://github.com/Rexshack-RedM) — item boxes and stash storage
- A framework `spawnmanager` export (`exports.spawnmanager:setAutoSpawn`) available on your server

Make sure all of the above are installed and started **before** `rsg-medic` in your `server.cfg`.

## Installation

1. Download or clone this resource into your server's `resources` directory as `rsg-medic`.
2. Add it to your `server.cfg`, after its dependencies:
   ```cfg
   ensure rsg-core
   ensure rsg-bossmenu
   ensure ox_lib
   ensure oxmysql
   ensure rsg-inventory
   ensure rsg-medic
   ```
3. Make sure your `rsg-core` items table includes `firstaid` and `bandage` items (these are the items this script uses; add them if they don't already exist).
4. Make sure the `medic` job exists in your `rsg-core` jobs config (or change `Config.JobRequired` to match your existing job name — see below).
5. Restart your server, or run `refresh` + `ensure rsg-medic` from the server console.

## Configuration

All settings live in `config.lua`.

### General Settings

| Setting | Default | Description |
|---|---|---|
| `Config.Debug` | `false` | Prints extra diagnostic info to the server/client console. |
| `Config.JobRequired` | `'medic'` | The job name that grants access to medic duty, revive, treat wounds, and storage. |
| `Config.StorageMaxWeight` | `4000000` | Max weight (in grams) of the medic storage stash. |
| `Config.StorageMaxSlots` | `48` | Max slot count of the medic storage stash. |
| `Config.DeathTimer` | `300` | Seconds a player must wait before they can respawn themselves. |
| `Config.WipeInventoryOnRespawn` | `false` | Clear the player's inventory on respawn. |
| `Config.WipeCashOnRespawn` | `false` | Zero out the player's cash on respawn. |
| `Config.WipeBloodmoneyOnRespawn` | `false` | Zero out the player's bloodmoney on respawn. |
| `Config.MaxHealth` | `600` | The engine's max health value, used for health percentage calculations. |
| `Config.MedicReviveTime` | `5000` | Progress-bar duration (ms) for a medic reviving a patient. |
| `Config.MedicTreatTime` | `5000` | Progress-bar duration (ms) for a medic treating wounds. |
| `Config.MedicTreatHealth` | `30` | Percentage of max health restored when a medic treats a patient's wounds. |
| `Config.ReviveHealth` | `20` | Percentage of max health a player has after self-respawning. |
| `Config.MedicReviveHealth` | `60` | Percentage of max health a player has after being revived by a medic. |
| `Config.AddGPSRoute` | `true` | Draw a GPS route to a medic-call location for responding medics. |
| `Config.MedicCallDelay` | `60` | Cooldown (seconds) before a player can call for a medic again. |
| `Config.BandageTime` | `10000` | Progress-bar duration (ms) for self-applying a bandage. |
| `Config.BandageHealth` | `15` | Percentage of max health restored by a bandage. |
| `Config.ResetOutlawStatus` | `true` | Reset outlaw/wanted status on respawn (requires `rsg-prison`). |
| `Config.SaltyChat` | `false` | Enable SaltyChat proximity-voice integration on death/revive. |

### Blip Settings

```lua
Config.Blip = {
    blipName   = 'Medic',
    blipSprite = 'blip_shop_doctor',
    blipScale  = 0.2
}
```
Controls the appearance of the map blip shown at each medic station (when `showblip = true` for that location).

### Medic Job Locations

```lua
Config.MedicJobLocations = {
    { name = 'Valentine Medic', prompt = 'valmedic', coords = vector3(x, y, z), showblip = true },
    -- add more stations here
}
```
Each entry creates an interaction prompt (and optionally a blip) at the given coordinates that opens the medic duty menu.

### Respawn Locations

```lua
Config.RespawnLocations = {
    [1] = { coords = vector4(x, y, z, heading) },
    -- ...
}
```
A pool of respawn points. On death, the game picks the closest one to where the player died.

### Discord Webhooks (`Config.Webhooks`)

```lua
Config.Webhooks = {
    enabled   = true,
    botName   = 'RSG Medic',
    botAvatar = '',

    urls = {
        death     = '',
        revive    = '',
        treatment = '',
        duty      = '',
        admin     = '',
        storage   = '',
    },

    logging = {
        death      = true,
        revive     = true,
        treatment  = true,
        duty       = true,
        admin      = true,
        storage    = true,
        bandageUse = false,
    },

    colors = {
        death     = 0xC0392B,
        revive    = 0x27AE60,
        treatment = 0x2ECC71,
        duty      = 0x3498DB,
        admin     = 0xF1C40F,
        storage   = 0x9B59B6,
    },
}
```

To set it up:

1. In your Discord server, go to **Channel Settings → Integrations → Webhooks → New Webhook** for each channel you want logs in.
2. Copy each webhook's URL into the matching field in `Config.Webhooks.urls`. Point multiple categories at the same URL if you want everything in one channel.
3. Leave a URL as `''` to disable that category entirely — or set `Config.Webhooks.enabled = false` to turn off all logging at once.
4. Use `Config.Webhooks.logging.<category> = false` for finer-grained control without clearing the URL (handy for temporarily muting a category).
5. `botName` and `botAvatar` control how the webhook posts appear in Discord; leave `botAvatar` blank to use Discord's default.

Webhook sends are queued and rate-limit aware, so nothing needs to be tuned further — just fill in the URLs and go.

## Locales

Locale files live in `locales/<code>.json`. The active language is controlled by your `ox_lib`/RSG-Core locale setting, not by this resource directly. To add a new language, copy `locales/en.json`, translate the values (keep the keys exactly as-is), and save it as `locales/<your-code>.json`.

## Support / Updates

This resource checks `https://raw.githubusercontent.com/Rexshack-RedM/rsg-versioncheckers/main/rsg-medic/version.txt` on startup and will print an outdated warning to console if a newer version is available. Grab updates from the [Rexshack-RedM GitHub](https://github.com/Rexshack-RedM).

## License

See [`LICENSE`](./LICENSE) for details.
