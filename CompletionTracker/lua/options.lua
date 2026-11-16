---@diagnostic disable: undefined-global

-- Completion Tracker - options page under Options > Mod Options, built with
-- the menu helper that ships with SuperBLT. Every entry is an on/off switch
-- for one key in CompletionTracker.settings, and takes effect straight away.

dofile(ModPath .. "lua/config.lua")
CompletionTracker:Load()

local MENU_ID = "completion_tracker_options"
local ITEM_PREFIX = "completion_tracker_option_"

-- In the order they are shown. A string is a gap between groups.
local OPTIONS = {
    "show_contract_completion",
    "show_broker_best",
    "show_heist_completion",
    "gap",
    "show_borders",
    "show_icons",
    "gap",
    "show_new_best_popup"
}

Hooks:Add("MenuManagerInitialize", "CompletionTracker_OptionsCallbacks", function(menu_manager)
    MenuCallbackHandler.completion_tracker_set_option = function(self, item)
        local key = string.sub(item:name(), string.len(ITEM_PREFIX) + 1)

        -- Only keys this mod knows about are ever written.
        if CompletionTracker.defaults[key] == nil then
            return
        end

        CompletionTracker.settings[key] = item:value() == "on"
        CompletionTracker:Save()
    end
end)

Hooks:Add("MenuManagerSetupCustomMenus", "CompletionTracker_OptionsSetup", function(menu_manager, nodes)
    MenuHelper:NewMenu(MENU_ID)
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "CompletionTracker_OptionsPopulate", function(menu_manager, nodes)
    -- The helper sorts by priority, highest first.
    local priority = #OPTIONS

    for index, key in ipairs(OPTIONS) do
        if key == "gap" then
            MenuHelper:AddDivider({
                id = ITEM_PREFIX .. "gap_" .. tostring(index),
                size = 16,
                menu_id = MENU_ID,
                priority = priority
            })
        else
            MenuHelper:AddToggle({
                id = ITEM_PREFIX .. key,
                title = "completion_tracker_option_" .. key,
                desc = "completion_tracker_option_" .. key .. "_desc",
                callback = "completion_tracker_set_option",
                value = CompletionTracker.settings[key] and true or false,
                menu_id = MENU_ID,
                priority = priority
            })
        end

        priority = priority - 1
    end
end)

Hooks:Add("MenuManagerBuildCustomMenus", "CompletionTracker_OptionsBuild", function(menu_manager, nodes)
    nodes[MENU_ID] = MenuHelper:BuildMenu(MENU_ID)

    MenuHelper:AddMenuItem(nodes["blt_options"], MENU_ID, "completion_tracker_options_title", "completion_tracker_options_desc")
end)
