# Completion Tracker

A PAYDAY 2 mod for completionists. It shows what you have done, what you still have to do, and how far through the game you are, without changing how the game plays.

It needs [SuperBLT](https://superblt.znix.xyz/) and nothing else.

## What it adds

### Completion Tracker page

A new button on the main menu, under Achievements.

- An overall completion percentage, weighted by how long things take. A heist on Death Sentence counts for far more than buying a pistol.
- A completion ring and count for each category: heists, level and infamy, achievements, weapons, attachments, masks, melee and throwables, cosmetics, perk decks, safe house, trophies, and cash and coins.
- Click a category for the detail. Blue lines open a list of exactly what is missing.
- A toggle between counting only content from DLC you own and counting everything in the game.

### Contract broker

- A difficulty selector next to the heist list. Heists turn green if you have completed them on that difficulty or a harder one. The last step is Death Sentence with One Down.
- Skulls on each heist picture for the hardest difficulty you have completed it on.
- A "hide completed" tick box.

### Crime.net

- A contract's name turns green if you have completed that heist on its difficulty or a harder one.

### Shops

- Weapons and masks you already own are marked when buying.
- Attachments that show as out of stock but are fitted to another of your weapons are marked too.

### End of heist

- A popup when you complete a heist for the first time, or on a harder difficulty than before.

## Options

Options > Mod Options > Completion Tracker. Every addition has its own on/off switch, and changes apply straight away.

Settings are saved in `mods/saves/completion_tracker_config.json` and survive updates.

## Installing

1. Install [SuperBLT](https://superblt.znix.xyz/).
2. Download the zip from the [latest release](https://github.com/GrayHound85/completion-tracker/releases/latest).
3. Extract it into the `mods` folder of your PAYDAY 2 install, so you end up with `mods/CompletionTracker/mod.txt`.

After that the mod updates itself. When a new version is out, the game's mod manager offers the download.

## Patch notes

- [2.0.x](patch_notes/2.0.x_PATCH_NOTES.md)
- [1.1.x](patch_notes/1.1.x_PATCH_NOTES.md)

## Development notes

The mod is the `CompletionTracker` folder. Everything else in this repository (patch notes, `meta.json`, workshop images) is for publishing and is not shipped.

| File | What it does |
| --- | --- |
| `lua/config.lua` | Settings, and the shared difficulty helpers every other file uses |
| `lua/completionstats.lua` | Gathers every number on the page. The hour weights for the overall percentage are in `CompletionStats.HOURS` at the top |
| `lua/completiontrackergui.lua` | The page itself |
| `lua/menu.lua`, `lua/menucomponentmanager.lua` | Main menu button and page registration |
| `lua/contractbroker.lua` | Broker selector, skulls and hide completed |
| `lua/crimenet.lua` | Crime.net highlight |
| `lua/blackmarket.lua` | Owned markers in the shops |
| `lua/heistend.lua` | End of heist popup |
| `lua/options.lua`, `lua/localization.lua` | Options page and its text |

### Releasing

1. Set the new version in `CompletionTracker/mod.txt` and in `meta.json`, and point `download_url` and `patchnotes_url` in `meta.json` at the new release.
2. Zip the `CompletionTracker` folder so that the folder itself is the top level of the zip. Use forward slashes and plain deflate. Zips made by older versions of PowerShell's `Compress-Archive` use backslashes and SuperBLT cannot unpack them.
3. Create a GitHub release tagged with the version number and attach the zip.
4. Push `meta.json` to `main`. SuperBLT reads it from there and offers the update to anyone whose installed version is different.

Useful game functions:

- `managers.blackmarket:weapon_unlocked(weapon_id)` - whether a weapon can be used
- `managers.blackmarket:get_crafted_category(category)` - owned weapons or masks
- `managers.statistics:completed_job(job_id, difficulty, require_one_down)` - completion count for a heist
- `BlackMarketGuiSlotItem._mini_panel` - the panel mini icons are drawn in
