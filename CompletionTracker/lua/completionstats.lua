---@diagnostic disable: undefined-global

-- Completion Tracker - statistics gathering.
--
-- CompletionStats:get_stats(include_all) returns everything the stats page
-- shows. Nothing in here touches the GUI.
--
--   include_all = false  only count content you can get with the DLC you own
--   include_all = true   count everything in the game
--
-- Result:
--   {
--       include_all = bool,
--       overall     = { progress, hours_done, hours_total, play_minutes, lines },
--       categories  = { { id, name, progress, summary, lines, hours_total, hours_done }, ... }
--   }
--
-- "lines" is a display list for the detail panel:
--   { type = "header", text = "..." }
--   { type = "stat",   label = "...", value = "...", progress = 0..1 or nil, list = list or nil }
--   { type = "note",   text = "..." }
--   { type = "spacer" }
--
-- A stat line with a "list" can be opened on the page to see what is still
-- missing: { title = "...", items = { stat lines } }

CompletionStats = CompletionStats or class()

--------------------------------------------------
-- WEIGHTS
--------------------------------------------------
-- The overall percentage is not "items ticked off / items in the game". Every
-- category is converted to an estimate of the hours it takes to finish, so a
-- Death Sentence run is worth far more than buying a pistol and the 1,300
-- achievements cannot swamp everything else. Tune the numbers here.

CompletionStats.HOURS = {
    -- Hours for one heist on each tier, in CompletionTracker.difficulties
    -- order. A heist completed on a harder tier also counts for the easier
    -- ones, so a single DSOD run is worth the sum of the whole row.
    heist_tier = { 0.25, 0.25, 0.3, 0.4, 0.5, 0.6, 0.9, 1.0 },

    -- First climb from level 0 to 100, then each infamy rank.
    first_100_levels = 40,
    infamy_rank = 2.5,

    -- One achievement with no difficulty attached. Achievements tagged with
    -- a difficulty are multiplied by achievement_difficulty below.
    achievement = 0.15,

    weapon = 0.15,
    weapon_mod = 0.08,
    mask = 0.06,
    melee = 0.1,
    throwable = 0.2,
    -- Outfits, gloves, weapon colours and charms. Kept low on purpose, they
    -- mostly arrive as a side effect of achievements and DLC.
    cosmetic = 0.03,
    perk_deck = 5,
    safehouse_tier = 0.75,
    trophy = 0.5
}

-- Infamy ranks beyond this still show on the page but add nothing to the
-- overall percentage. 100 is the last rank with an achievement.
CompletionStats.INFAMY_CAP = 100

-- How many achievements the "closest to unlocking" section shows.
CompletionStats.CLOSEST_ACHIEVEMENTS = 8

-- Multiplier for achievements by the difficulty tag the game gives them.
CompletionStats.ACHIEVEMENT_DIFFICULTY = {
    { tag = "difficulty_death_sentence", name = "Death Sentence", weight = 6 },
    { tag = "difficulty_death_wish",     name = "Death Wish",     weight = 4 },
    { tag = "difficulty_mayhem",         name = "Mayhem",         weight = 3 },
    { tag = "difficulty_overkill",       name = "Overkill",       weight = 2 },
    { tag = "difficulty_very_hard",      name = "Very Hard",      weight = 1.5 },
    { tag = "difficulty_hard",           name = "Hard",           weight = 1.2 },
    { tag = "difficulty_normal",         name = "Normal",         weight = 1 }
}

-- Jobs that are in the job index but are not real contracts.
local EXCLUDED_JOBS = {
    short = true,
    short1 = true,
    short2 = true,
    safehouse = true,
    chill = true,
    chill_combat = true,
    crime_spree = true
}

--------------------------------------------------
-- FORMATTING HELPERS
--------------------------------------------------

local function fmt_int(value)
    local number = math.floor((tonumber(value) or 0) + 0.5)
    local sign = number < 0 and "-" or ""
    local digits = tostring(math.abs(number))
    local out = ""

    -- Very large values come back in exponent form, leave those alone.
    if not string.match(digits, "^%d+$") then
        return sign .. digits
    end

    while string.len(digits) > 3 do
        out = "," .. string.sub(digits, -3) .. out
        digits = string.sub(digits, 1, -4)
    end

    return sign .. digits .. out
end

local function fmt_cash(value)
    return "$" .. fmt_int(value)
end

local function fmt_pct(progress)
    progress = math.max(0, math.min(1, progress or 0))

    -- Never round up to 100% while something is still missing.
    if progress < 1 and progress > 0.999 then
        return "99.9%"
    end

    if progress > 0 and progress < 0.001 then
        return "0.1%"
    end

    return string.format("%.1f%%", progress * 100)
end

local function fmt_hours(hours)
    return fmt_int(hours) .. " h"
end

local function ratio(have, total)
    if not total or total <= 0 then
        return 0
    end

    return math.max(0, math.min(1, have / total))
end

local function count_line(label, have, total, list)
    return {
        type = "stat",
        label = label,
        value = fmt_int(have) .. " / " .. fmt_int(total),
        progress = ratio(have, total),
        list = list
    }
end

local function value_line(label, value)
    return { type = "stat", label = label, value = value }
end

local function header(text)
    return { type = "header", text = text }
end

local function note(text)
    return { type = "note", text = text }
end

local SPACER = { type = "spacer" }

-- Localised name for a tweak data entry, falling back to its id.
local function name_of(item_tweak, id)
    local name_id = item_tweak and item_tweak.name_id

    if not name_id then
        return tostring(id)
    end

    return managers.localization:text(name_id)
end

-- A "what is missing" list for a stat line, or nil when nothing is.
local function missing_list(title, items)
    if not items or #items == 0 then
        return nil
    end

    table.sort(items, function (a, b)
        local a_key = string.lower(a.label or "")
        local b_key = string.lower(b.label or "")

        if a_key ~= b_key then
            return a_key < b_key
        end

        return (a.value or "") < (b.value or "")
    end)

    return { title = title, items = items }
end

local function missing_item(label, value, progress)
    return { type = "stat", label = label, value = value or "", progress = progress }
end

CompletionStats.fmt_int = fmt_int
CompletionStats.fmt_cash = fmt_cash
CompletionStats.fmt_pct = fmt_pct
CompletionStats.fmt_hours = fmt_hours

--------------------------------------------------
-- DLC HELPERS
--------------------------------------------------

-- True when "dlc" is a DLC you have to buy and you have not bought it.
-- Content unlocked by achievements, events or free updates is also keyed by
-- a "dlc" id in the game data, those never count as missing here.
local dlc_missing_cache = {}

local function paid_dlc_missing(dlc)
    if type(dlc) ~= "string" or dlc == "" or dlc == "normal" or dlc == "infamous" then
        return false
    end

    if dlc_missing_cache[dlc] ~= nil then
        return dlc_missing_cache[dlc]
    end

    local missing = false
    local dlc_tweak = tweak_data.dlc and tweak_data.dlc[dlc]
    local all_dlc_data = Global.dlc_manager and Global.dlc_manager.all_dlc_data
    local dlc_data = all_dlc_data and all_dlc_data[dlc]

    -- Only DLC with a store id can be bought.
    if not (dlc_tweak and dlc_tweak.free) and dlc_data and dlc_data.app_id then
        local ok, unlocked = pcall(function ()
            return managers.dlc:is_dlc_unlocked(dlc)
        end)

        missing = ok and not unlocked
    end

    dlc_missing_cache[dlc] = missing

    return missing
end

-- Same check for an item table that may carry "dlc", "dlcs" and/or
-- "global_value". The item is missing only if every way to own it is.
local function item_dlc_missing(item)
    if not item then
        return false
    end

    local candidates = {}

    if item.dlc then
        table.insert(candidates, item.dlc)
    end

    for _, dlc in ipairs(item.dlcs or {}) do
        table.insert(candidates, dlc)
    end

    if #candidates == 0 and item.global_value then
        table.insert(candidates, item.global_value)
    end

    if #candidates == 0 then
        return false
    end

    for _, dlc in ipairs(candidates) do
        if not paid_dlc_missing(dlc) then
            return false
        end
    end

    return true
end

--------------------------------------------------
-- ENTRY POINT
--------------------------------------------------

function CompletionStats:init()
end

function CompletionStats:get_stats(include_all)
    self._include_all = include_all and true or false

    -- DLC can be bought while the game is running, so ask again each time.
    dlc_missing_cache = {}

    local gatherers = {
        { id = "heists",       name = "HEISTS",             func = "get_heists" },
        { id = "level",        name = "LEVEL & INFAMY",     func = "get_level" },
        { id = "achievements", name = "ACHIEVEMENTS",       func = "get_achievements" },
        { id = "weapons",      name = "WEAPONS",            func = "get_weapons" },
        { id = "weapon_mods",  name = "ATTACHMENTS",        func = "get_weapon_mods" },
        { id = "masks",        name = "MASKS",              func = "get_masks" },
        { id = "gear",         name = "MELEE & THROWABLES", func = "get_gear" },
        { id = "cosmetics",    name = "COSMETICS",          func = "get_cosmetics" },
        { id = "perk_decks",   name = "PERK DECKS",         func = "get_perk_decks" },
        { id = "safehouse",    name = "SAFE HOUSE",         func = "get_safehouse" },
        { id = "trophies",     name = "TROPHIES",           func = "get_trophies" }
    }

    local stats = {
        include_all = self._include_all,
        categories = {}
    }

    -- Shared between categories: what each one still costs.
    self._costs = {
        cash_weapons = 0,
        coins_mods = 0,
        coins_safehouse = 0,
        coins_crew = 0
    }

    -- Weapon charms are found while walking the attachments and shown under
    -- cosmetics.
    self._charms = { total = 0, owned = 0, missing = {} }

    for _, gatherer in ipairs(gatherers) do
        local ok, result = pcall(self[gatherer.func], self)

        if not ok then
            log("[CompletionTracker] Failed to gather '" .. gatherer.id .. "': " .. tostring(result))

            result = {
                failed = true,
                progress = 0,
                summary = "unavailable",
                hours_total = 0,
                hours_done = 0,
                lines = {
                    note("This section could not be read. The game may have changed since this mod was written."),
                    note(tostring(result))
                }
            }
        end

        result.id = gatherer.id
        result.name = gatherer.name

        table.insert(stats.categories, result)
    end

    -- Cash and coins has no percentage of its own, it reports what the other
    -- categories still cost.
    local ok, economy = pcall(self.get_economy, self)

    if not ok then
        log("[CompletionTracker] Failed to gather 'economy': " .. tostring(economy))

        economy = {
            failed = true,
            summary = "unavailable",
            lines = { note("This section could not be read."), note(tostring(economy)) }
        }
    end

    economy.id = "economy"
    economy.name = "CASH & COINS"

    table.insert(stats.categories, economy)

    stats.overall = self:get_overall(stats.categories)

    return stats
end

--------------------------------------------------
-- OVERALL
--------------------------------------------------

function CompletionStats:get_overall(categories)
    local hours_total = 0
    local hours_done = 0

    for _, category in ipairs(categories) do
        hours_total = hours_total + (category.hours_total or 0)
        hours_done = hours_done + (category.hours_done or 0)
    end

    local play_minutes = 0

    pcall(function ()
        play_minutes = managers.statistics:get_play_time() or 0
    end)

    local lines = {
        header("ESTIMATED HOURS OF CONTENT"),
        {
            type = "stat",
            label = "Completed",
            value = fmt_hours(hours_done) .. " / " .. fmt_hours(hours_total),
            progress = ratio(hours_done, hours_total)
        },
        value_line("Remaining", fmt_hours(hours_total - hours_done)),
        value_line("Time played in heists", fmt_hours(play_minutes / 60)),
        SPACER,
        header("WHERE THE HOURS ARE")
    }

    for _, category in ipairs(categories) do
        if (category.hours_total or 0) > 0 then
            table.insert(lines, {
                type = "stat",
                label = category.name,
                value = fmt_hours(category.hours_done) .. " / " .. fmt_hours(category.hours_total),
                progress = ratio(category.hours_done, category.hours_total)
            })
        end
    end

    table.insert(lines, SPACER)
    table.insert(lines, note("The overall percentage weights every category by the hours it takes to finish, so hard things count for more than easy ones. The hour figures are estimates, not measurements."))
    table.insert(lines, note("Infamy counts up to rank " .. tostring(self.INFAMY_CAP) .. "."))

    return {
        progress = ratio(hours_done, hours_total),
        hours_done = hours_done,
        hours_total = hours_total,
        play_minutes = play_minutes,
        summary = fmt_hours(hours_done) .. " / " .. fmt_hours(hours_total),
        lines = lines
    }
end

--------------------------------------------------
-- HEISTS
--------------------------------------------------

-- The same list the contract broker shows.
function CompletionStats:_job_list()
    local jobs = {}

    for _, job_id in ipairs(tweak_data.narrative:get_jobs_index()) do
        local job_tweak = tweak_data.narrative:job_data(job_id)
        local contact_tweak = job_tweak and tweak_data.narrative.contacts[job_tweak.contact]
        local listed = job_tweak and contact_tweak and not contact_tweak.hidden and not job_tweak.hidden
        listed = listed and not EXCLUDED_JOBS[job_id] and not tweak_data.narrative:is_wrapped_to_job(job_id)

        if listed then
            table.insert(jobs, { job_id = job_id, job_tweak = job_tweak })
        end
    end

    return jobs
end

function CompletionStats:get_heists()
    local tiers = CompletionTracker.difficulties
    local tier_hours = self.HOURS.heist_tier
    local completed = {}
    local missing = {}
    local total = 0
    local never = 0
    local dlc_skipped = 0

    for index = 1, #tiers do
        completed[index] = 0
        missing[index] = {}
    end

    for _, job in ipairs(self:_job_list()) do
        local highest = CompletionTracker:highest_completed_tier(job.job_id)
        local dlc_missing = paid_dlc_missing(job.job_tweak.dlc)

        -- A DLC heist you finished by joining someone still counts.
        if self._include_all or not dlc_missing or highest > 0 then
            total = total + 1

            if highest == 0 then
                never = never + 1
            end

            local name = name_of(job.job_tweak, job.job_id)
            local best = highest == 0 and "Never completed" or "Best: " .. CompletionTracker:difficulty_name(highest)

            for index = 1, #tiers do
                if index <= highest then
                    completed[index] = completed[index] + 1
                else
                    table.insert(missing[index], missing_item(name, best))
                end
            end
        else
            dlc_skipped = dlc_skipped + 1
        end
    end

    local hours_total = 0
    local hours_done = 0
    local lines = { header("COMPLETED ON THIS DIFFICULTY OR HARDER") }

    for index = 1, #tiers do
        local hours = tier_hours[index] or 0
        local name = CompletionTracker:difficulty_name(index)

        hours_total = hours_total + hours * total
        hours_done = hours_done + hours * completed[index]

        table.insert(lines, count_line(name, completed[index], total, missing_list("NOT YET COMPLETED ON " .. name, missing[index])))
    end

    table.insert(lines, SPACER)
    table.insert(lines, header("CONTRACTS"))
    table.insert(lines, value_line("Contracts counted", fmt_int(total)))
    table.insert(lines, value_line("Never completed", fmt_int(never)))

    if not self._include_all and dlc_skipped > 0 then
        table.insert(lines, value_line("Left out, DLC not owned", fmt_int(dlc_skipped)))
    end

    table.insert(lines, SPACER)
    table.insert(lines, note("A heist finished on a harder difficulty also counts for every easier one. The percentage weights harder difficulties more heavily."))

    local top = #tiers

    return {
        progress = ratio(hours_done, hours_total),
        summary = tiers[top].short .. " " .. fmt_int(completed[top]) .. " / " .. fmt_int(total),
        hours_total = hours_total,
        hours_done = hours_done,
        lines = lines
    }
end

--------------------------------------------------
-- LEVEL & INFAMY
--------------------------------------------------

function CompletionStats:get_level()
    local level = managers.experience:current_level() or 0
    local level_cap = managers.experience:level_cap() or 100
    local rank = managers.experience:current_rank() or 0
    local max_rank = tweak_data.infamy and tonumber(tweak_data.infamy.ranks) or self.INFAMY_CAP
    local cap = math.min(self.INFAMY_CAP, max_rank)
    local counted_rank = math.min(rank, cap)

    -- The first climb to 100 is by far the slowest, every rank after that is
    -- another (much faster) climb.
    local first_climb = rank > 0 and 1 or ratio(level, level_cap)
    local rank_progress = counted_rank

    if rank > 0 and rank < cap then
        rank_progress = rank_progress + ratio(level, level_cap)
    end

    rank_progress = math.min(rank_progress, cap)

    local hours_total = self.HOURS.first_100_levels + self.HOURS.infamy_rank * cap
    local hours_done = self.HOURS.first_100_levels * first_climb + self.HOURS.infamy_rank * rank_progress

    local lines = {
        header("REPUTATION"),
        count_line("Level", level, level_cap),
        count_line("Infamy rank, counted to " .. tostring(cap), counted_rank, cap),
        value_line("Infamy rank, actual", fmt_int(rank) .. " / " .. fmt_int(max_rank)),
        SPACER
    }

    if rank > cap then
        table.insert(lines, note("You are past rank " .. tostring(cap) .. ". The extra ranks are shown here but no longer add to the overall percentage."))
    else
        table.insert(lines, note("Ranks beyond " .. tostring(cap) .. " will still be shown here but will not add to the overall percentage."))
    end

    return {
        progress = ratio(hours_done, hours_total),
        summary = "Rank " .. fmt_int(rank) .. ", level " .. fmt_int(level),
        hours_total = hours_total,
        hours_done = hours_done,
        lines = lines
    }
end

--------------------------------------------------
-- ACHIEVEMENTS
--------------------------------------------------

-- Locked achievements that track a count, nearest to done first.
function CompletionStats:_closest_achievements(visual)
    local candidates = {}

    for id, achievement in pairs(managers.achievment.achievments or {}) do
        local data = visual[id]
        local progress = data and data.progress

        if not achievement.awarded and type(progress) == "table" and type(progress.get) == "function" then
            -- These read live game state, one misbehaving counter must not
            -- cost the whole section.
            local ok, current, max = pcall(function ()
                local max_value = type(progress.max) == "function" and progress:max() or progress.max

                return progress.get(), max_value
            end)

            if ok and type(current) == "number" and type(max) == "number" and max > 0 and current > 0 and current < max then
                table.insert(candidates, {
                    id = id,
                    name = name_of(data, id),
                    current = current,
                    max = max,
                    ratio = current / max
                })
            end
        end
    end

    table.sort(candidates, function (a, b)
        if a.ratio ~= b.ratio then
            return a.ratio > b.ratio
        end

        return a.id < b.id
    end)

    local lines = {}

    for index = 1, math.min(self.CLOSEST_ACHIEVEMENTS, #candidates) do
        local candidate = candidates[index]

        table.insert(lines, {
            type = "stat",
            label = candidate.name,
            value = fmt_int(candidate.current) .. " / " .. fmt_int(candidate.max),
            progress = candidate.ratio
        })
    end

    return lines
end

function CompletionStats:get_achievements()
    local visual = tweak_data.achievement and tweak_data.achievement.visual or {}
    local buckets = {}
    local untagged = { name = "No difficulty", weight = 1, total = 0, done = 0 }
    local total = 0
    local done = 0

    for index, difficulty in ipairs(self.ACHIEVEMENT_DIFFICULTY) do
        buckets[index] = { name = difficulty.name, weight = difficulty.weight, total = 0, done = 0 }
    end

    for id, achievement in pairs(managers.achievment.achievments or {}) do
        local bucket = untagged
        local tags = visual[id] and visual[id].tags

        if type(tags) == "table" then
            -- ACHIEVEMENT_DIFFICULTY is ordered hardest first, so an
            -- achievement tagged with several difficulties lands in the
            -- hardest one.
            for index, difficulty in ipairs(self.ACHIEVEMENT_DIFFICULTY) do
                if table.contains(tags, difficulty.tag) then
                    bucket = buckets[index]

                    break
                end
            end
        end

        total = total + 1
        bucket.total = bucket.total + 1

        if achievement.awarded then
            done = done + 1
            bucket.done = bucket.done + 1
        end
    end

    local hours_total = untagged.total * untagged.weight * self.HOURS.achievement
    local hours_done = untagged.done * untagged.weight * self.HOURS.achievement
    local lines = {
        header("ACHIEVEMENTS"),
        count_line("Unlocked", done, total),
        value_line("Remaining", fmt_int(total - done))
    }

    local closest_ok, closest = pcall(self._closest_achievements, self, visual)

    if closest_ok and #closest > 0 then
        table.insert(lines, SPACER)
        table.insert(lines, header("CLOSEST TO UNLOCKING"))

        for _, line in ipairs(closest) do
            table.insert(lines, line)
        end
    end

    table.insert(lines, SPACER)
    table.insert(lines, header("BY DIFFICULTY REQUIRED"))

    -- Easiest first reads better than the hardest-first lookup order.
    for index = #buckets, 1, -1 do
        local bucket = buckets[index]

        hours_total = hours_total + bucket.total * bucket.weight * self.HOURS.achievement
        hours_done = hours_done + bucket.done * bucket.weight * self.HOURS.achievement

        if bucket.total > 0 then
            table.insert(lines, count_line(bucket.name, bucket.done, bucket.total))
        end
    end

    table.insert(lines, count_line(untagged.name, untagged.done, untagged.total))
    table.insert(lines, SPACER)
    table.insert(lines, note("The percentage here is a plain count. In the overall percentage, achievements that need a harder difficulty are worth more."))
    table.insert(lines, note("Achievements are always counted in full, including ones tied to DLC you do not own. For the full list, the game's own Achievements page can be sorted by progress."))

    return {
        progress = ratio(done, total),
        summary = fmt_int(done) .. " / " .. fmt_int(total),
        hours_total = hours_total,
        hours_done = hours_done,
        lines = lines
    }
end

--------------------------------------------------
-- WEAPONS
--------------------------------------------------

-- Set of weapon ids you own at least one of.
function CompletionStats:_owned_weapon_ids()
    local owned = {}

    for _, category in ipairs({ "primaries", "secondaries" }) do
        for _, weapon in pairs(managers.blackmarket:get_crafted_category(category) or {}) do
            if weapon.weapon_id then
                owned[weapon.weapon_id] = true
            end
        end
    end

    return owned
end

-- Mirrors the test the buy menu uses to decide which weapons it lists.
local function weapon_in_buy_menu(category, weapon_tweak)
    local gui_categories = tweak_data.gui and tweak_data.gui.buy_weapon_categories and tweak_data.gui.buy_weapon_categories[category]
    local aliases = tweak_data.gui and tweak_data.gui.buy_weapon_category_aliases or {}

    if not gui_categories or not weapon_tweak.categories then
        return true
    end

    for _, gui_category in ipairs(gui_categories) do
        local match = true

        for i, wanted in ipairs(gui_category) do
            local actual = weapon_tweak.categories[i]

            if wanted ~= (aliases[actual] or actual) then
                match = false

                break
            end
        end

        if match then
            return true
        end
    end

    return false
end

function CompletionStats:get_weapons()
    local owned_ids = self:_owned_weapon_ids()
    local player_level = managers.experience:current_level() or 0
    local groups = {
        primaries = { name = "Primary weapons", list_title = "PRIMARY WEAPONS NOT OWNED", total = 0, owned = 0, cash = 0, buyable = 0, locked = 0, missing = {} },
        secondaries = { name = "Secondary weapons", list_title = "SECONDARY WEAPONS NOT OWNED", total = 0, owned = 0, cash = 0, buyable = 0, locked = 0, missing = {} }
    }
    local dlc_skipped = 0

    for weapon_id, data in pairs(Global.blackmarket_manager.weapons or {}) do
        local weapon_tweak = tweak_data.weapon[weapon_id]
        local category = data.selection_index == 2 and "primaries" or data.selection_index == 1 and "secondaries" or nil
        local group = category and groups[category]

        if group and weapon_tweak and weapon_in_buy_menu(category, weapon_tweak) then
            local owned = owned_ids[weapon_id] or false
            local definition = tweak_data.upgrades.definitions[weapon_id]
            local dlc = definition and definition.dlc or weapon_tweak.global_value
            local dlc_missing = paid_dlc_missing(dlc)
            local hidden = false

            -- The buy menu hides some unavailable promotional weapons.
            if not owned and not data.unlocked and definition and definition.dlc then
                local gv_tweak = tweak_data.lootdrop.global_values[definition.dlc]
                local dlc_unlocked = managers.dlc:is_dlc_unlocked(definition.dlc)

                hidden = not dlc_unlocked and gv_tweak and gv_tweak.hide_unavailable and true or false
            end

            if hidden then
                -- Not obtainable, never counted.
            elseif self._include_all or not dlc_missing or owned then
                group.total = group.total + 1

                if owned then
                    group.owned = group.owned + 1
                else
                    local price = managers.money:get_weapon_price_modified(weapon_id) or 0
                    local status = fmt_cash(price)

                    group.cash = group.cash + price

                    if managers.blackmarket:weapon_unlocked(weapon_id) then
                        group.buyable = group.buyable + 1
                    else
                        group.locked = group.locked + 1

                        if dlc_missing then
                            status = "DLC not owned"
                        elseif (data.level or 0) > player_level then
                            status = "Level " .. tostring(data.level) .. ", " .. status
                        else
                            status = "Locked, " .. status
                        end
                    end

                    table.insert(group.missing, missing_item(name_of(weapon_tweak, weapon_id), status))
                end
            else
                dlc_skipped = dlc_skipped + 1
            end
        end
    end

    local primaries = groups.primaries
    local secondaries = groups.secondaries
    local total = primaries.total + secondaries.total
    local owned = primaries.owned + secondaries.owned
    local cash = primaries.cash + secondaries.cash

    self._costs.cash_weapons = cash

    local lines = { header("OWNED") }

    for _, group in ipairs({ primaries, secondaries }) do
        table.insert(lines, count_line(group.name, group.owned, group.total, missing_list(group.list_title, group.missing)))
    end

    table.insert(lines, count_line("All weapons", owned, total))
    table.insert(lines, SPACER)
    table.insert(lines, header("STILL TO BUY"))
    table.insert(lines, value_line("Can be bought right now", fmt_int(primaries.buyable + secondaries.buyable)))
    table.insert(lines, value_line("Locked by level, skill or DLC", fmt_int(primaries.locked + secondaries.locked)))
    table.insert(lines, value_line("Cash for the missing primaries", fmt_cash(primaries.cash)))
    table.insert(lines, value_line("Cash for the missing secondaries", fmt_cash(secondaries.cash)))
    table.insert(lines, value_line("Cash for all missing weapons", fmt_cash(cash)))

    if not self._include_all and dlc_skipped > 0 then
        table.insert(lines, value_line("Left out, DLC not owned", fmt_int(dlc_skipped)))
    end

    table.insert(lines, SPACER)
    table.insert(lines, note("Prices are what you would pay today, including your skill discounts. Extra weapon slots are not included."))

    return {
        progress = ratio(owned, total),
        summary = fmt_int(owned) .. " / " .. fmt_int(total),
        hours_total = total * self.HOURS.weapon,
        hours_done = owned * self.HOURS.weapon,
        lines = lines
    }
end

--------------------------------------------------
-- WEAPON ATTACHMENTS
--------------------------------------------------

-- Amount of an item in the inventory across every global value.
local function inventory_amount(category, id)
    local amount = 0

    for _, categories in pairs(Global.blackmarket_manager.inventory or {}) do
        local items = categories[category]

        if items and items[id] then
            amount = amount + (tonumber(items[id]) or 0)
        end
    end

    return amount
end

-- part id -> text saying which weapon(s) it fits.
function CompletionStats:_part_users()
    local users = {}

    for weapon_id, data in pairs(Global.blackmarket_manager.weapons or {}) do
        local factory = data.factory_id and tweak_data.weapon.factory[data.factory_id]

        for _, part_id in ipairs(factory and factory.uses_parts or {}) do
            local entry = users[part_id]

            if not entry then
                entry = { count = 0 }
                users[part_id] = entry
            end

            entry.count = entry.count + 1
            entry.weapon_id = weapon_id
        end
    end

    local text = {}

    for part_id, entry in pairs(users) do
        if entry.count == 1 then
            text[part_id] = name_of(tweak_data.weapon[entry.weapon_id], entry.weapon_id)
        else
            text[part_id] = fmt_int(entry.count) .. " weapons"
        end
    end

    return text
end

function CompletionStats:get_weapon_mods()
    local parts = tweak_data.weapon.factory.parts
    local attached = {}

    -- Attachments fitted to a weapon have left the inventory, they still
    -- count as obtained.
    for _, category in ipairs({ "primaries", "secondaries" }) do
        for _, weapon in pairs(managers.blackmarket:get_crafted_category(category) or {}) do
            for _, part_id in ipairs(weapon.blueprint or {}) do
                attached[part_id] = true
            end
        end
    end

    local users_ok, users = pcall(self._part_users, self)

    if not users_ok then
        users = {}
    end

    local drop = { total = 0, owned = 0, missing = {} }
    local unlockable = { total = 0, owned = 0, missing = {} }
    local charms = self._charms
    local coins = 0
    local dlc_skipped = 0
    local coin_price = tweak_data.safehouse.prices.weapon_mod or 0
    local event_coin_price = tweak_data.safehouse.prices.event_weapon_mod or coin_price

    for part_id, mod in pairs(tweak_data.blackmarket.weapon_mods or {}) do
        local part = parts[part_id] or {}
        local obtainable = (mod.pc or mod.pcs or mod.is_a_unlockable) and not mod.unatainable and not mod.inaccessible

        -- "bonus" parts are the stat boosts that come with weapon skins.
        if obtainable and part.type ~= "bonus" then
            local owned = attached[part_id] or inventory_amount("weapon_mods", part_id) > 0
            local dlc_missing = item_dlc_missing(mod)
            local name = name_of(mod.name_id and mod or part, part_id)

            if part.type == "charm" then
                -- Counted under cosmetics.
                if self._include_all or not dlc_missing or owned then
                    charms.total = charms.total + 1

                    if owned then
                        charms.owned = charms.owned + 1
                    else
                        table.insert(charms.missing, missing_item(name))
                    end
                end
            elseif not (self._include_all or not dlc_missing or owned) then
                dlc_skipped = dlc_skipped + 1
            elseif mod.is_a_unlockable then
                unlockable.total = unlockable.total + 1

                if owned then
                    unlockable.owned = unlockable.owned + 1
                else
                    table.insert(unlockable.missing, missing_item(name, users[part_id]))
                end
            else
                drop.total = drop.total + 1

                if owned then
                    drop.owned = drop.owned + 1
                else
                    coins = coins + (part.is_event_mod and event_coin_price or coin_price)

                    table.insert(drop.missing, missing_item(name, users[part_id]))
                end
            end
        end
    end

    local total = drop.total + unlockable.total
    local owned = drop.owned + unlockable.owned

    self._costs.coins_mods = coins

    local lines = {
        header("OBTAINED"),
        count_line("All attachments", owned, total),
        count_line("From card drops or coins", drop.owned, drop.total, missing_list("ATTACHMENTS YOU CAN BUY WITH COINS", drop.missing)),
        count_line("From achievements, DLC and events", unlockable.owned, unlockable.total, missing_list("ATTACHMENTS LOCKED BEHIND AN UNLOCK", unlockable.missing)),
        SPACER,
        header("STILL TO GET"),
        value_line("Can be bought with coins", fmt_int(drop.total - drop.owned)),
        value_line("Continental coins needed", fmt_int(coins)),
        value_line("Need an achievement, DLC or event", fmt_int(unlockable.total - unlockable.owned))
    }

    if not self._include_all and dlc_skipped > 0 then
        table.insert(lines, value_line("Left out, DLC not owned", fmt_int(dlc_skipped)))
    end

    table.insert(lines, SPACER)
    table.insert(lines, note("An attachment counts as obtained if you have one in your inventory or fitted to a weapon. Cash to fit attachments is not included. Weapon charms are under Cosmetics."))

    return {
        progress = ratio(owned, total),
        summary = fmt_int(owned) .. " / " .. fmt_int(total),
        hours_total = total * self.HOURS.weapon_mod,
        hours_done = owned * self.HOURS.weapon_mod,
        lines = lines
    }
end

--------------------------------------------------
-- MASKS
--------------------------------------------------

function CompletionStats:get_masks()
    local crafted = {}

    for _, mask in pairs(managers.blackmarket:get_crafted_category("masks") or {}) do
        if mask.mask_id then
            crafted[mask.mask_id] = true
        end
    end

    local total = 0
    local owned_count = 0
    local in_stash = 0
    local dlc_skipped = 0
    local missing = {}

    for mask_id, mask in pairs(tweak_data.blackmarket.masks or {}) do
        if (mask.pc or mask.pcs) and not mask.inaccessible then
            local stash = inventory_amount("masks", mask_id) > 0
            local owned = crafted[mask_id] or stash

            if mask.hide_unavailable and not owned then
                -- Hidden from the game's own mask list until you have it.
            elseif self._include_all or not item_dlc_missing(mask) or owned then
                total = total + 1

                if owned then
                    owned_count = owned_count + 1
                else
                    table.insert(missing, missing_item(name_of(mask, mask_id)))
                end

                if stash and not crafted[mask_id] then
                    in_stash = in_stash + 1
                end
            else
                dlc_skipped = dlc_skipped + 1
            end
        end
    end

    local lines = {
        header("OBTAINED"),
        count_line("Masks", owned_count, total, missing_list("MASKS NOT YET OBTAINED", missing)),
        value_line("Remaining", fmt_int(total - owned_count)),
        value_line("In your stash, not yet crafted", fmt_int(in_stash))
    }

    if not self._include_all and dlc_skipped > 0 then
        table.insert(lines, value_line("Left out, DLC not owned", fmt_int(dlc_skipped)))
    end

    table.insert(lines, SPACER)
    table.insert(lines, note("A mask counts as obtained if you have crafted it or have one waiting in your stash."))

    return {
        progress = ratio(owned_count, total),
        summary = fmt_int(owned_count) .. " / " .. fmt_int(total),
        hours_total = total * self.HOURS.mask,
        hours_done = owned_count * self.HOURS.mask,
        lines = lines
    }
end

--------------------------------------------------
-- UNLOCK TABLES (melee, throwables, outfits, gloves)
--------------------------------------------------

-- Counts a Global.blackmarket_manager table whose entries carry "unlocked".
-- Returns { total, owned, dlc_skipped, missing }.
function CompletionStats:_count_unlockables(global_items, tweak_items, filter)
    local result = { total = 0, owned = 0, dlc_skipped = 0, missing = {} }

    for id, data in pairs(global_items or {}) do
        local item_tweak = tweak_items and tweak_items[id]

        if item_tweak and (not filter or filter(item_tweak, data)) then
            local owned = data.unlocked and true or false
            local dlc_missing = item_dlc_missing(item_tweak)

            if self._include_all or not dlc_missing or owned then
                result.total = result.total + 1

                if owned then
                    result.owned = result.owned + 1
                else
                    table.insert(result.missing, missing_item(name_of(item_tweak, id), dlc_missing and "DLC not owned" or ""))
                end
            else
                result.dlc_skipped = result.dlc_skipped + 1
            end
        end
    end

    return result
end

--------------------------------------------------
-- MELEE & THROWABLES
--------------------------------------------------

function CompletionStats:get_gear()
    local blackmarket = Global.blackmarket_manager
    local melee = self:_count_unlockables(blackmarket.melee_weapons, tweak_data.blackmarket.melee_weapons)

    -- Perk deck abilities live in the same table as throwables, they are
    -- part of the perk decks rather than something to unlock here.
    local throwables = self:_count_unlockables(blackmarket.grenades, tweak_data.blackmarket.projectiles, function (item_tweak, data)
        return item_tweak.throwable and not data.ability
    end)

    local total = melee.total + throwables.total
    local owned = melee.owned + throwables.owned
    local dlc_skipped = melee.dlc_skipped + throwables.dlc_skipped
    local lines = {
        header("UNLOCKED"),
        count_line("Melee weapons", melee.owned, melee.total, missing_list("MELEE WEAPONS STILL LOCKED", melee.missing)),
        count_line("Throwables", throwables.owned, throwables.total, missing_list("THROWABLES STILL LOCKED", throwables.missing))
    }

    if not self._include_all and dlc_skipped > 0 then
        table.insert(lines, value_line("Left out, DLC not owned", fmt_int(dlc_skipped)))
    end

    return {
        progress = ratio(owned, total),
        summary = fmt_int(owned) .. " / " .. fmt_int(total),
        hours_total = melee.total * self.HOURS.melee + throwables.total * self.HOURS.throwable,
        hours_done = melee.owned * self.HOURS.melee + throwables.owned * self.HOURS.throwable,
        lines = lines
    }
end

--------------------------------------------------
-- COSMETICS
--------------------------------------------------

-- Weapon colours are stored as inventory items rather than unlock flags.
function CompletionStats:_count_weapon_colors()
    local result = { total = 0, owned = 0, dlc_skipped = 0, missing = {} }
    local skins = tweak_data.blackmarket.weapon_skins or {}

    for _, id in ipairs(tweak_data.blackmarket.weapon_colors or {}) do
        local color = skins[id]

        if color then
            local dlc = color.dlc or managers.dlc:global_value_to_dlc(color.global_value)
            local gv_tweak = tweak_data.lootdrop.global_values[color.global_value or dlc or "normal"]
            local owned = inventory_amount("weapon_skins", id) > 0
            local dlc_missing = paid_dlc_missing(dlc)

            if gv_tweak and gv_tweak.hide_unavailable and not owned then
                -- The game hides these until you have them.
            elseif self._include_all or not dlc_missing or owned then
                result.total = result.total + 1

                if owned then
                    result.owned = result.owned + 1
                else
                    table.insert(result.missing, missing_item(name_of(color, id), dlc_missing and "DLC not owned" or ""))
                end
            else
                result.dlc_skipped = result.dlc_skipped + 1
            end
        end
    end

    return result
end

function CompletionStats:get_cosmetics()
    local blackmarket = Global.blackmarket_manager

    -- The default outfit and gloves are always there, they are not something
    -- to collect.
    local function collectable(item_tweak)
        return not item_tweak.unlocked
    end

    local outfits = self:_count_unlockables(blackmarket.player_styles, tweak_data.blackmarket.player_styles, collectable)
    local gloves = self:_count_unlockables(blackmarket.gloves, tweak_data.blackmarket.gloves, collectable)
    local colors = self:_count_weapon_colors()
    local charms = self._charms

    local total = outfits.total + gloves.total + colors.total + charms.total
    local owned = outfits.owned + gloves.owned + colors.owned + charms.owned
    local dlc_skipped = outfits.dlc_skipped + gloves.dlc_skipped + colors.dlc_skipped
    local lines = {
        header("UNLOCKED"),
        count_line("Outfits", outfits.owned, outfits.total, missing_list("OUTFITS STILL LOCKED", outfits.missing)),
        count_line("Gloves", gloves.owned, gloves.total, missing_list("GLOVES STILL LOCKED", gloves.missing)),
        count_line("Weapon colours", colors.owned, colors.total, missing_list("WEAPON COLOURS STILL LOCKED", colors.missing)),
        count_line("Weapon charms", charms.owned, charms.total, missing_list("WEAPON CHARMS STILL LOCKED", charms.missing))
    }

    if not self._include_all and dlc_skipped > 0 then
        table.insert(lines, value_line("Left out, DLC not owned", fmt_int(dlc_skipped)))
    end

    table.insert(lines, SPACER)
    table.insert(lines, note("Weapon skins and armour skins from safes are not counted, those are Steam inventory items rather than something to unlock. Cosmetics carry very little weight in the overall percentage."))

    return {
        progress = ratio(owned, total),
        summary = fmt_int(owned) .. " / " .. fmt_int(total),
        hours_total = total * self.HOURS.cosmetic,
        hours_done = owned * self.HOURS.cosmetic,
        lines = lines
    }
end

--------------------------------------------------
-- PERK DECKS
--------------------------------------------------

function CompletionStats:get_perk_decks()
    local decks = {}
    local deck_count = 0
    local decks_done = 0
    local points_total = 0
    local points_done = 0
    local progress_sum = 0
    local dlc_skipped = 0

    for tree, deck in ipairs(tweak_data.skilltree.specializations or {}) do
        local tier_count = #deck
        local current_tier = math.min(managers.skilltree:get_specialization_value(tree, "tiers", "current_tier") or 0, tier_count)
        local deck_points = 0
        local deck_done = 0

        for tier, tier_data in ipairs(deck) do
            local cost = tier_data.cost or 0

            deck_points = deck_points + cost

            if tier <= current_tier then
                deck_done = deck_done + cost
            end
        end

        -- Points already paid towards the next tier.
        if current_tier < tier_count then
            local ok, partial = pcall(function ()
                return managers.skilltree:get_specialization_value(tree, "tiers", "next_tier_data", "current_points")
            end)

            if ok and type(partial) == "number" then
                deck_done = math.min(deck_done + partial, deck_points)
            end
        end

        if self._include_all or not paid_dlc_missing(deck.dlc) or current_tier > 0 then
            deck_count = deck_count + 1
            points_total = points_total + deck_points
            points_done = points_done + deck_done
            progress_sum = progress_sum + ratio(deck_done, deck_points)

            if current_tier >= tier_count then
                decks_done = decks_done + 1
            end

            table.insert(decks, {
                type = "stat",
                label = deck.name_id and managers.localization:to_upper_text(deck.name_id) or "DECK " .. tostring(tree),
                value = "Tier " .. tostring(current_tier) .. " / " .. tostring(tier_count),
                progress = ratio(deck_done, deck_points)
            })
        else
            dlc_skipped = dlc_skipped + 1
        end
    end

    local lines = {
        header("PERK DECKS"),
        count_line("Decks completed", decks_done, deck_count),
        count_line("Perk points spent", points_done, points_total)
    }

    if not self._include_all and dlc_skipped > 0 then
        table.insert(lines, value_line("Left out, DLC not owned", fmt_int(dlc_skipped)))
    end

    table.insert(lines, SPACER)
    table.insert(lines, header("EACH DECK"))

    for _, line in ipairs(decks) do
        table.insert(lines, line)
    end

    return {
        progress = ratio(points_done, points_total),
        summary = fmt_int(decks_done) .. " / " .. fmt_int(deck_count),
        hours_total = deck_count * self.HOURS.perk_deck,
        hours_done = progress_sum * self.HOURS.perk_deck,
        lines = lines
    }
end

--------------------------------------------------
-- SAFE HOUSE
--------------------------------------------------

function CompletionStats:get_safehouse()
    local prices = tweak_data.safehouse.prices.rooms
    local rooms = Global.custom_safehouse_manager and Global.custom_safehouse_manager.rooms or {}
    local room_tweaks = {}
    local room_count = 0
    local rooms_maxed = 0
    local tiers_total = 0
    local tiers_done = 0
    local coins = 0
    local missing = {}

    for _, room_tweak in ipairs(tweak_data.safehouse.rooms or {}) do
        room_tweaks[room_tweak.room_id] = room_tweak
    end

    for room_id, room in pairs(rooms) do
        local highest = managers.custom_safehouse:get_highest_tier_unlocked(room_id) or room.tier_start or 1
        local tier_max = room.tier_max or #prices
        local tier_start = room.tier_start or 1
        local room_coins = 0

        room_count = room_count + 1
        tiers_total = tiers_total + math.max(0, tier_max - tier_start)
        tiers_done = tiers_done + math.max(0, math.min(highest, tier_max) - tier_start)

        for tier = highest + 1, tier_max do
            room_coins = room_coins + (prices[tier] or 0)
        end

        coins = coins + room_coins

        if highest >= tier_max then
            rooms_maxed = rooms_maxed + 1
        else
            local room_tweak = room_tweaks[room_id]
            local name = room_tweak and managers.localization:text(room_tweak.title_id or room_tweak.name_id or room_id) or tostring(room_id)

            table.insert(missing, missing_item(name, "Tier " .. tostring(highest) .. " / " .. tostring(tier_max) .. ", " .. fmt_int(room_coins) .. " coins"))
        end
    end

    self._costs.coins_safehouse = coins

    local lines = {
        header("ROOMS"),
        count_line("Rooms fully upgraded", rooms_maxed, room_count, missing_list("ROOMS NOT FULLY UPGRADED", missing)),
        count_line("Room upgrades bought", tiers_done, tiers_total),
        SPACER,
        header("STILL TO BUY"),
        value_line("Upgrades remaining", fmt_int(tiers_total - tiers_done)),
        value_line("Continental coins needed", fmt_int(coins))
    }

    return {
        progress = ratio(tiers_done, tiers_total),
        summary = fmt_int(rooms_maxed) .. " / " .. fmt_int(room_count),
        hours_total = tiers_total * self.HOURS.safehouse_tier,
        hours_done = tiers_done * self.HOURS.safehouse_tier,
        lines = lines
    }
end

--------------------------------------------------
-- TROPHIES
--------------------------------------------------

function CompletionStats:get_trophies()
    local total = 0
    local done = 0
    local missing = {}

    for _, trophy in pairs(managers.custom_safehouse:trophies() or {}) do
        -- The game's own trophy list leaves these out.
        if not trophy.hidden_in_list then
            total = total + 1

            if trophy.completed then
                done = done + 1
            else
                local current = 0
                local max = 0

                for _, objective in ipairs(trophy.objectives or {}) do
                    local objective_max = objective.max_progress or 1

                    max = max + objective_max
                    current = current + math.min(objective.completed and objective_max or objective.progress or 0, objective_max)
                end

                -- Secret trophies stay secret until earned.
                local name = trophy.secret and "???" or name_of(trophy, trophy.id)
                local counted = max > 1

                table.insert(missing, missing_item(name, counted and fmt_int(current) .. " / " .. fmt_int(max) or "", counted and ratio(current, max) or nil))
            end
        end
    end

    local lines = {
        header("TROPHIES"),
        count_line("Unlocked", done, total, missing_list("TROPHIES STILL TO EARN", missing)),
        value_line("Remaining", fmt_int(total - done))
    }

    return {
        progress = ratio(done, total),
        summary = fmt_int(done) .. " / " .. fmt_int(total),
        hours_total = total * self.HOURS.trophy,
        hours_done = done * self.HOURS.trophy,
        lines = lines
    }
end

--------------------------------------------------
-- CASH & COINS
--------------------------------------------------

-- Continental coins still needed for crew boosts and abilities.
function CompletionStats:_crew_coins()
    local coins = 0
    local missing = 0
    local total = 0
    local prices = tweak_data.safehouse.prices
    local sources = {
        { items = tweak_data.upgrades.crew_skill_definitions, price = prices.crew_boost or 0 },
        { items = tweak_data.upgrades.crew_ability_definitions, price = prices.crew_ability or 0 }
    }

    for _, source in ipairs(sources) do
        for item, _ in pairs(source.items or {}) do
            total = total + 1

            if not managers.blackmarket:is_crew_item_unlocked(item) then
                missing = missing + 1
                coins = coins + source.price
            end
        end
    end

    return coins, missing, total
end

function CompletionStats:get_economy()
    local cash = managers.money:total() or 0
    local offshore = managers.money:offshore() or 0
    local cash_earned = managers.money:total_collected() or 0
    local cash_spent = managers.money:total_spent() or 0

    -- Coins build up in fractions, the game only ever shows whole ones.
    local coins = math.floor(managers.custom_safehouse:coins() or 0)
    local coins_earned = math.floor(managers.custom_safehouse:total_coins_earned() or 0)
    local coins_spent = math.floor(managers.custom_safehouse:coins_spent() or 0)

    local crew_ok, crew_coins, crew_missing, crew_total = pcall(self._crew_coins, self)

    if not crew_ok then
        crew_coins, crew_missing, crew_total = 0, 0, 0
    end

    self._costs.coins_crew = crew_coins

    local cash_needed = self._costs.cash_weapons
    local coins_needed = self._costs.coins_mods + self._costs.coins_safehouse + self._costs.coins_crew

    local lines = {
        header("CASH"),
        value_line("Spending cash", fmt_cash(cash)),
        value_line("Offshore account", fmt_cash(offshore)),
        value_line("Earned in total", fmt_cash(cash_earned)),
        value_line("Spent in total", fmt_cash(cash_spent)),
        SPACER,
        header("CASH STILL NEEDED"),
        value_line("Every missing weapon", fmt_cash(cash_needed)),
        {
            type = "stat",
            label = "Covered by your spending cash",
            value = fmt_pct(cash_needed > 0 and ratio(cash, cash_needed) or 1),
            progress = cash_needed > 0 and ratio(cash, cash_needed) or 1
        },
        value_line("Still short by", fmt_cash(math.max(0, cash_needed - cash))),
        SPACER,
        header("CONTINENTAL COINS"),
        value_line("Coins", fmt_int(coins)),
        value_line("Earned in total", fmt_int(coins_earned)),
        value_line("Spent in total", fmt_int(coins_spent)),
        SPACER,
        header("COINS STILL NEEDED"),
        value_line("Every missing attachment", fmt_int(self._costs.coins_mods)),
        value_line("Every safe house upgrade", fmt_int(self._costs.coins_safehouse))
    }

    if crew_total > 0 then
        table.insert(lines, value_line("Crew boosts and abilities, " .. fmt_int(crew_missing) .. " missing", fmt_int(crew_coins)))
    end

    table.insert(lines, value_line("Total", fmt_int(coins_needed)))
    table.insert(lines, {
        type = "stat",
        label = "Covered by your coins",
        value = fmt_pct(coins_needed > 0 and ratio(coins, coins_needed) or 1),
        progress = coins_needed > 0 and ratio(coins, coins_needed) or 1
    })
    table.insert(lines, value_line("Still short by", fmt_int(math.max(0, coins_needed - coins))))
    table.insert(lines, SPACER)
    table.insert(lines, note("Cash needed covers buying every weapon you do not own. Coins needed covers every attachment that can be bought with coins, every safe house upgrade and every crew boost and ability."))

    return {
        summary = fmt_cash(cash),
        lines = lines
    }
end
