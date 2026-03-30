
CompletionTracker = CompletionTracker or {}

CompletionTracker.defaults = {
    show_icons = false,
    show_borders = true,
    show_heist_completion = true
}

local config_path = SavePath .. "completion_tracker_config.json"

function CompletionTracker:Load()
    local file = io.open(config_path, "r")

    if file then
        local data = json.decode(file:read("*all"))
        file:close()

        self.settings = data or {}
    else
        self.settings = {}
    end

    local changed = false

    -- Apply defaults for missing values
    for k, v in pairs(self.defaults) do
        if self.settings[k] == nil then
            self.settings[k] = v
            changed = true
        end
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