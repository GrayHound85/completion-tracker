---@diagnostic disable: undefined-global

-- Completion Tracker - text for the main menu button and the options page.

Hooks:Add("LocalizationManagerPostInit", "CompletionTracker_Localization", function(loc)
    loc:add_localized_strings({
        menu_completion_tracker = "Completion Tracker",
        menu_completion_tracker_help = "See how much of the game you have completed.",

        completion_tracker_options_title = "Completion Tracker",
        completion_tracker_options_desc = "Choose which Completion Tracker additions are shown.",

        completion_tracker_option_show_contract_completion = "Contract broker: completion tools",
        completion_tracker_option_show_contract_completion_desc = "Adds the difficulty selector to the contract broker, turns the names of completed heists green and lets you hide them.",

        completion_tracker_option_show_broker_best = "Contract broker: best difficulty skulls",
        completion_tracker_option_show_broker_best_desc = "Shows skulls on each heist's picture for the hardest difficulty you have completed it on.",

        completion_tracker_option_show_heist_completion = "Crime.net: highlight completed contracts",
        completion_tracker_option_show_heist_completion_desc = "Turns a contract's name green on Crime.net when you have completed that heist on its difficulty or a harder one.",

        completion_tracker_option_show_borders = "Shops: border on items you own",
        completion_tracker_option_show_borders_desc = "Draws a green border around weapons and masks you already own when buying, and around attachments you already have fitted to another weapon.",

        completion_tracker_option_show_icons = "Shops: icon on items you own",
        completion_tracker_option_show_icons_desc = "Adds a small icon to weapons and masks you already own when buying, and to attachments you already have fitted to another weapon.",

        completion_tracker_option_show_new_best_popup = "Heist end: new best difficulty popup",
        completion_tracker_option_show_new_best_popup_desc = "Shows a popup when you finish a heist on a harder difficulty than ever before."
    })
end)
