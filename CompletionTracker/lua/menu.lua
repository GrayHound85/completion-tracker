
log("==============================")
log(" COMPLETION TRACKER MENU TEST")
log("==============================")


local completion_tracker_created = false

MenuComponentManager.COMPONENTS = MenuComponentManager.COMPONENTS or {}

MenuComponentManager.COMPONENTS.completion_tracker = function(self)
    
    log("CREATING COMPLETION TRACKER COMPONENT")

end


Hooks:PostHook(MenuManager, "open_menu", "CompletionTracker_CreateNode", function(self, menu_name)

    if menu_name ~= "menu_main" then
        return
    end


    local menu = self:active_menu()

    if not menu then
        return
    end


    local data = menu.logic._data

    if not data or not data._nodes then
        return
    end


    if completion_tracker_created then
        return
    end


    log("CREATING COMPLETION TRACKER NODE")


    local node = CoreMenuNode.MenuNode:new(
    {
        name = "completion_tracker",
        topic_id = "menu_completion_tracker",

        no_menu_wrapper = true,
        no_item_parent = true,

        scene_state = "crew_management",
        sync_state = "skilltree",

        menu_components = {
            "achievement_list"
        }
    }
    )

    node._parameters.menu_components = {
        "achievement_list"
    }


    node._items = {}
    node._legends = {}


    data._nodes.completion_tracker = node


    completion_tracker_created = true


    log("COMPLETION TRACKER NODE CREATED")


end)



Hooks:PostHook(MenuManager, "open_menu", "CompletionTracker_AddButton", function(self, menu_name)

    if menu_name ~= "menu_main" then
        return
    end


    local menu = self:active_menu()

    if not menu then
        return
    end


    local data = menu.logic._data

    local main_node = data._nodes.main

    if not main_node then
        return
    end


    for _, item in ipairs(main_node._items) do

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


    log("COMPLETION TRACKER BUTTON ADDED")


end)