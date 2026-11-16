---@diagnostic disable: undefined-global

-- Completion Tracker - shared settings and helpers.
-- This file is dofile'd by every hook script, so everything in here must be
-- safe to run more than once.

CompletionTracker = CompletionTracker or {}

CompletionTracker.defaults = {
    show_icons = false,
    show_borders = true,
    show_heist_completion = true,
    show_contract_completion = true,
    -- Skulls on each contract broker thumbnail for the hardest difficulty
    -- the heist has been completed on.
    show_broker_best = true,
    -- Popup at the end of a heist when it sets a new hardest difficulty.
    show_new_best_popup = true,
    -- Index into CompletionTracker.difficulties used by the contract broker
    -- selector. 8 = Death Sentence with One Down.
    broker_difficulty = 8,
    -- Stats page: false = only count content from DLC you own,
    -- true = count everything in the game.
    stats_all_content = false
}

CompletionTracker.COMPLETED_COLOR = Color(0.3, 1, 0.3)

-- Every difficulty tier the mod knows about, easiest first. The last entry
-- is Death Sentence with the One Down modifier, which the game stores as a
-- separate completion counter rather than as its own difficulty.
CompletionTracker.difficulties = {
    { id = "normal",       name_id = "menu_difficulty_normal",    short = "N" },
    { id = "hard",         name_id = "menu_difficulty_hard",      short = "H" },
    { id = "overkill",     name_id = "menu_difficulty_very_hard", short = "VH" },
    { id = "overkill_145", name_id = "menu_difficulty_overkill",  short = "OVK" },
    { id = "easy_wish",    name_id = "menu_difficulty_easy_wish", short = "MH" },
    { id = "overkill_290", name_id = "menu_difficulty_apocalypse", short = "DW" },
    { id = "sm_wish",      name_id = "menu_difficulty_sm_wish",   short = "DS" },
    { id = "sm_wish",      name_id = "menu_difficulty_sm_wish",   short = "DSOD", one_down = true }
}

local config_path = SavePath .. "completion_tracker_config.json"

function CompletionTracker:Load()
    local data = nil
    local file = io.open(config_path, "r")

    if file then
        local ok, decoded = pcall(json.decode, file:read("*all"))
        file:close()

        if ok and type(decoded) == "table" then
            data = decoded
        end
    end

    self.settings = data or {}

    local changed = false

    -- Apply defaults for missing values
    for k, v in pairs(self.defaults) do
        if self.settings[k] == nil then
            self.settings[k] = v
            changed = true
        end
    end

    -- A hand-edited or corrupt value must not break the broker selector.
    local diff_index = tonumber(self.settings.broker_difficulty)

    if not diff_index or not self.difficulties[diff_index] then
        self.settings.broker_difficulty = self.defaults.broker_difficulty
        changed = true
    else
        self.settings.broker_difficulty = diff_index
    end

    if changed then
        self:Save()
    end
end

function CompletionTracker:Save()
    local file = io.open(config_path, "w")

    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

-- Index of a difficulty id ("overkill_145") in CompletionTracker.difficulties.
function CompletionTracker:difficulty_index(difficulty_id, one_down)
    for index, difficulty in ipairs(self.difficulties) do
        if difficulty.id == difficulty_id and (difficulty.one_down or false) == (one_down or false) then
            return index
        end
    end

    return nil
end

-- Localised, upper case name of a difficulty tier.
function CompletionTracker:difficulty_name(index)
    local difficulty = self.difficulties[index]

    if not difficulty then
        return ""
    end

    local name = managers.localization:to_upper_text(difficulty.name_id)

    if difficulty.one_down then
        name = name .. " - " .. managers.localization:to_upper_text("menu_one_down")
    end

    return name
end

-- Highest tier (index into CompletionTracker.difficulties) the job has been
-- completed on, or 0 if it has never been completed.
function CompletionTracker:highest_completed_tier(job_id)
    for index = #self.difficulties, 1, -1 do
        local difficulty = self.difficulties[index]
        local count = managers.statistics:completed_job(job_id, difficulty.id, difficulty.one_down or false)

        if count and count > 0 then
            return index
        end
    end

    return 0
end

-- True if the job has been completed on the given tier or any harder one.
function CompletionTracker:job_completed_at_or_above(job_id, index)
    if not job_id or not index or not self.difficulties[index] then
        return false
    end

    return self:highest_completed_tier(job_id) >= index
end
