---@diagnostic disable: undefined-global

-- Completion Tracker - adds the "Completion Tracker" button to the main menu
-- and the menu node it opens. The node has no items of its own, it only
-- shows the "completion_tracker" menu component.

local NODE_NAME = "completion_tracker"
local BUTTON_NAME = "completion_tracker_button"

local function create_node(data)
    if data._nodes[NODE_NAME] then
        return true
    end

    -- Borrow the menu scene settings from the achievements page.
    local achievements_node = data._nodes.achievements
    local template = achievements_node and achievements_node._parameters or {}

    local node = CoreMenuNode.MenuNode:new({
        name = NODE_NAME,
        topic_id = "menu_completion_tracker",
        scene_state = template.scene_state,
        sync_state = template.sync_state,
        menu_components = "completion_tracker"
    })

    data._nodes[NODE_NAME] = node

    return true
end

local function add_button(main_node)
    local achievements_index = nil

    for index, item in ipairs(main_node._items) do
        local params = item:parameters()

        if params.name == BUTTON_NAME then
            return
        end

        if params.next_node == "achievements" then
            achievements_index = index
        end
    end

    local item = main_node:create_item(nil, {
        name = BUTTON_NAME,
        text_id = "menu_completion_tracker",
        help_id = "menu_completion_tracker_help",
        next_node = NODE_NAME
    })

    -- Directly under Achievements when that button exists.
    if achievements_index then
        main_node:insert_item(item, achievements_index + 1)
    else
        main_node:add_item(item)
    end
end

Hooks:PostHook(MenuManager, "open_menu", "CompletionTracker_AddMenu", function(self, menu_name)
    if menu_name ~= "menu_main" then
        return
    end

    local menu = self:active_menu()
    local data = menu and menu.logic and menu.logic._data
    local main_node = data and data._nodes and data._nodes.main

    if not main_node then
        return
    end

    if create_node(data) then
        add_button(main_node)
    end
end)
