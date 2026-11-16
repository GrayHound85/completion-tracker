---@diagnostic disable: undefined-global

-- Completion Tracker - text for the main menu button.

Hooks:Add("LocalizationManagerPostInit", "CompletionTracker_Localization", function(loc)
    loc:add_localized_strings({
        menu_completion_tracker = "Completion Tracker",
        menu_completion_tracker_help = "See how much of the game you have completed."
    })
end)
