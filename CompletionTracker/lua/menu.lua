log("==============================")
log(" COMPLETION TRACKER MENU LOADED")
log("==============================")


local completion_tracker_created = false


Hooks:PostHook(MenuManager, "open_menu", "CompletionTracker_CreateNode", function(self, menu_name)

    if menu_name ~= "menu_main" then
        return
    end


    if completion_tracker_created then
        return
    end


    local menu = self:active_menu()

    if not menu or not menu.logic then
        return
    end


    local data = menu.logic._data

    if not data or not data._nodes then
        return
    end


    local achievements_node = data._nodes.achievements


    if not achievements_node then
        log("[CompletionTracker] achievements node missing")
        return
    end


    log("[CompletionTracker] Cloning achievements node")


    local node = CoreMenuNode.MenuNode:new(
    {
        name = "completion_tracker",

        topic_id = "menu_completion_tracker",

        scene_state = achievements_node._parameters.scene_state,
        sync_state = achievements_node._parameters.sync_state,

        menu_components =
        {
            "completion_tracker"
        }
    })


    node._parameters.menu_components =
    {
        "completion_tracker"
    }


    node._items = {}
    node._legends = {}


    data._nodes.completion_tracker = node


    completion_tracker_created = true


    log("[CompletionTracker] Node created")

end)



Hooks:PostHook(MenuManager, "open_menu", "CompletionTracker_AddButton", function(self, menu_name)

    if menu_name ~= "menu_main" then
        return
    end


    local menu = self:active_menu()

    if not menu or not menu.logic then
        return
    end


    local data = menu.logic._data


    local main_node = data._nodes.main


    if not main_node then
        return
    end



    for _,item in ipairs(main_node._items) do

        if item:parameters().name == "completion_tracker_button" then
            return
        end

    end



    local params = {
        name = "completion_tracker_button",
        text_id = "menu_achievements",
        next_node = "completion_tracker"
    }



    local item = main_node:create_item(nil, params)


    main_node:add_item(item)


    log("[CompletionTracker] Button added")


end)