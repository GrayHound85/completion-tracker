---@diagnostic disable: undefined-global

-- Completion Tracker - Contract Broker
--
-- Colours a heist's name green when it has been completed on the selected
-- difficulty or a harder one, and adds the difficulty selector that chooses
-- which difficulty that is. The last step of the selector is Death Sentence
-- with One Down.

dofile(ModPath .. "lua/config.lua")
CompletionTracker:Load()

local PAD = 10
local ids_left_mouse = Idstring("0")

-- Skull icons in the order the buy contract screen shows them. Normal has
-- no skull, so tier N lights the first N - 1 of these.
local RISK_ICONS = {
    "risk_swat",
    "risk_fbi",
    "risk_death_squad",
    "risk_easy_wish",
    "risk_murder_squad",
    "risk_sm_wish"
}

local function selected_tier()
    return CompletionTracker.settings.broker_difficulty
end

--------------------------------------------------
-- HEIST ITEMS
--------------------------------------------------

-- The heist item does not keep a reference to its name text, so find it by
-- the text it shows and remember it.
local function find_job_name_widget(item)
    if item._ct_job_name and alive(item._ct_job_name) then
        return item._ct_job_name
    end

    if not item._panel or not alive(item._panel) then
        return nil
    end

    local job_tweak = tweak_data.narrative:job_data(item._job_data.job_id)

    if not job_tweak then
        return nil
    end

    local expected_text = managers.localization:to_upper_text(job_tweak.name_id)

    for _, child in ipairs(item._panel:children()) do
        -- Only text objects have set_font_size. Panels also have a "text"
        -- function, but there it creates a new child instead of reading one.
        if alive(child) and child.set_font_size and child:text() == expected_text then
            item._ct_job_name = child

            return child
        end
    end

    return nil
end

local function color_contract_item(item)
    if not CompletionTracker.settings.show_contract_completion then
        return
    end

    if not item or not item._job_data or not item._job_data.job_id then
        return
    end

    local job_name = find_job_name_widget(item)

    if not job_name then
        return
    end

    if CompletionTracker:job_completed_at_or_above(item._job_data.job_id, selected_tier()) then
        job_name:set_color(CompletionTracker.COMPLETED_COLOR)
    else
        -- Put back the colour the game gave it, the selection may have
        -- moved to a difficulty this heist has not been completed on.
        job_name:set_color(item._job_data.enabled and tweak_data.screen_colors.text or tweak_data.screen_colors.important_1)
    end
end

--------------------------------------------------
-- DIFFICULTY SELECTOR
--------------------------------------------------

local function fine_text(text)
    local _, _, w, h = text:text_rect()

    text:set_size(math.ceil(w), math.ceil(h))
    text:set_position(math.round(text:x()), math.round(text:y()))
end

local function refresh_selector(gui)
    local selector = gui._ct_selector

    if not selector then
        return
    end

    local colors = tweak_data.screen_colors
    local tier = selected_tier()
    local difficulty = CompletionTracker.difficulties[tier]
    local one_down = difficulty.one_down and true or false
    local lit_color = one_down and colors.one_down or colors.risk
    local name = managers.localization:to_upper_text(difficulty.name_id)

    selector.name:set_font_size(selector.name_font_size)
    selector.name:set_text(name)
    selector.name:set_color(tier > 1 and lit_color or colors.text)
    selector.name:set_w(selector.name_max_w)

    -- Long names in other languages must stay between the arrows.
    local _, _, name_w = selector.name:text_rect()

    if name_w > selector.name_max_w then
        selector.name:set_font_size(selector.name_font_size * selector.name_max_w / name_w)
    end

    selector.one_down:set_visible(one_down)

    for index, skull in ipairs(selector.skulls) do
        -- Skull N belongs to tier N + 1.
        local lit = index < tier

        skull:set_color(lit and lit_color or Color.white)
        skull:set_alpha(lit and 1 or 0.25)
    end

    selector.left:set_alpha(tier > 1 and 1 or 0.3)
    selector.right:set_alpha(tier < #CompletionTracker.difficulties and 1 or 0.3)
end

local function set_tier(gui, tier)
    tier = math.clamp(tier, 1, #CompletionTracker.difficulties)

    if tier == selected_tier() then
        return false
    end

    CompletionTracker.settings.broker_difficulty = tier
    CompletionTracker:Save()

    refresh_selector(gui)

    for _, item in ipairs(gui._heist_items or {}) do
        color_contract_item(item)
    end

    managers.menu:post_event("menu_enter")

    return true
end

local function create_selector(gui)
    if not CompletionTracker.settings.show_contract_completion then
        return
    end

    -- The broker is reused for other lists (Holdout picks its maps with it),
    -- those have no difficulty to choose.
    if gui._job_filter or not gui._panels or not gui._panels.main then
        return
    end

    local main = gui._panels.main
    local colors = tweak_data.screen_colors
    local small_font = tweak_data.menu.pd2_small_font
    local small_size = tweak_data.menu.pd2_small_font_size
    local medium_font = tweak_data.menu.pd2_medium_font
    local medium_size = tweak_data.menu.pd2_medium_font_size

    -- Free space to the right of the heist list. If the list has been moved
    -- over there, use the left side instead.
    local x = main:right() + PAD
    local w = gui._panel:w() - x

    if w < 200 then
        w = main:left() - PAD
        x = 0

        if gui._panels.filters and gui._panels.filters:visible() then
            w = gui._panels.filters:left() - PAD
        end
    end

    if w < 200 then
        return
    end

    w = math.min(w, 280)

    local panel = gui._panel:panel({
        layer = 2,
        x = x,
        y = main:top(),
        w = w,
        h = 150
    })

    panel:rect({ color = Color.black, alpha = 0.3, layer = 0 })
    BoxGuiObject:new(panel, { sides = { 1, 1, 1, 1 } })

    local title = panel:text({
        text = "HIGHLIGHT COMPLETED ON",
        font = small_font,
        font_size = small_size,
        color = colors.text,
        alpha = 0.7,
        layer = 1,
        x = PAD,
        y = PAD
    })

    fine_text(title)

    local arrow_y = title:bottom() + 6
    local left = panel:text({
        text = "<",
        font = medium_font,
        font_size = medium_size,
        color = colors.button_stage_3,
        layer = 1,
        x = PAD,
        y = arrow_y
    })

    fine_text(left)

    local right = panel:text({
        text = ">",
        font = medium_font,
        font_size = medium_size,
        color = colors.button_stage_3,
        layer = 1,
        y = arrow_y
    })

    fine_text(right)
    right:set_right(w - PAD)

    local name_max_w = right:left() - left:right() - PAD
    local name = panel:text({
        text = "",
        font = medium_font,
        font_size = medium_size,
        color = colors.text,
        align = "center",
        vertical = "center",
        layer = 1,
        x = left:right() + PAD / 2,
        y = arrow_y,
        w = name_max_w,
        h = left:h()
    })

    -- Skull row, sized to fit the panel.
    local skull_size = math.floor(math.min(30, (w - PAD * 2) / #RISK_ICONS - 2))
    local skulls_w = #RISK_ICONS * (skull_size + 2) - 2
    local skull_x = math.floor((w - skulls_w) / 2)
    local skull_y = left:bottom() + 8
    local skulls = {}

    for index, icon in ipairs(RISK_ICONS) do
        local texture, rect = tweak_data.hud_icons:get_icon_data(icon)

        skulls[index] = panel:bitmap({
            texture = texture,
            texture_rect = rect,
            layer = 1,
            x = skull_x + (index - 1) * (skull_size + 2),
            y = skull_y,
            w = skull_size,
            h = skull_size
        })
    end

    local one_down = panel:text({
        text = managers.localization:to_upper_text("menu_one_down"),
        font = small_font,
        font_size = small_size,
        color = colors.one_down,
        align = "center",
        layer = 1,
        x = 0,
        y = skull_y + skull_size + 4,
        w = w,
        h = small_size + 2
    })

    panel:set_h(one_down:bottom() + PAD)

    gui._ct_selector = {
        panel = panel,
        left = left,
        right = right,
        name = name,
        name_max_w = name_max_w,
        name_font_size = medium_size,
        skulls = skulls,
        one_down = one_down
    }

    refresh_selector(gui)
end

-- What the mouse is over: "left", "right", a skull's tier, or nil.
local function selector_target(gui, x, y)
    local selector = gui._ct_selector

    if not selector or not alive(selector.panel) or not selector.panel:inside(x, y) then
        return nil
    end

    if selector.left:inside(x, y) then
        return "left"
    end

    if selector.right:inside(x, y) then
        return "right"
    end

    for index, skull in ipairs(selector.skulls) do
        if skull:inside(x, y) then
            -- Clicking the Death Sentence skull again steps on to One Down.
            if index == #selector.skulls and selected_tier() == index + 1 then
                return index + 2
            end

            return index + 1
        end
    end

    return "panel"
end

local function selector_mouse_moved(gui, x, y)
    local selector = gui._ct_selector
    local target = selector_target(gui, x, y)

    if not selector then
        return false
    end

    local colors = tweak_data.screen_colors
    local tier = selected_tier()
    local left_active = target == "left" and tier > 1
    local right_active = target == "right" and tier < #CompletionTracker.difficulties

    selector.left:set_color(left_active and colors.button_stage_2 or colors.button_stage_3)
    selector.right:set_color(right_active and colors.button_stage_2 or colors.button_stage_3)

    local clickable = left_active or right_active or type(target) == "number"

    if clickable and selector.highlighted ~= target then
        managers.menu:post_event("highlight")
    end

    selector.highlighted = clickable and target or nil

    if not target then
        return false
    end

    return true, clickable and "link" or "arrow"
end

local function selector_mouse_clicked(gui, x, y)
    local target = selector_target(gui, x, y)

    if not target then
        return false
    end

    if target == "left" then
        set_tier(gui, selected_tier() - 1)
    elseif target == "right" then
        set_tier(gui, selected_tier() + 1)
    elseif type(target) == "number" then
        set_tier(gui, target)
    end

    -- Clicks anywhere on the selector stop here, so they never fall through
    -- to whatever the broker has underneath.
    return true
end

--------------------------------------------------
-- HOOKS
--------------------------------------------------

if ContractBrokerHeistItem then
    Hooks:PostHook(ContractBrokerHeistItem, "init", "CompletionTracker_ContractBroker_Init", function(self)
        color_contract_item(self)
    end)

    Hooks:PostHook(ContractBrokerHeistItem, "refresh", "CompletionTracker_ContractBroker_Refresh", function(self)
        color_contract_item(self)
    end)
else
    log("[CompletionTracker] ContractBrokerHeistItem missing")
end

-- The mouse handlers return values the menu uses, so they are wrapped
-- rather than post-hooked. The flag stops them being wrapped twice if this
-- file is ever run again against the same class.
if ContractBrokerGui and not ContractBrokerGui._completion_tracker_hooked then
    ContractBrokerGui._completion_tracker_hooked = true

    Hooks:PostHook(ContractBrokerGui, "setup", "CompletionTracker_ContractBroker_Selector", function(self)
        local ok, err = pcall(create_selector, self)

        if not ok then
            log("[CompletionTracker] Could not create the difficulty selector: " .. tostring(err))

            self._ct_selector = nil
        end
    end)

    local orig_mouse_moved = ContractBrokerGui.mouse_moved

    function ContractBrokerGui:mouse_moved(button, x, y)
        local used, pointer = orig_mouse_moved(self, button, x, y)

        if not used then
            local selector_used, selector_pointer = selector_mouse_moved(self, x, y)

            if selector_used then
                return true, selector_pointer
            end
        end

        return used, pointer
    end

    local orig_mouse_clicked = ContractBrokerGui.mouse_clicked

    function ContractBrokerGui:mouse_clicked(o, button, x, y)
        if button == ids_left_mouse and not self._scroll_event and selector_mouse_clicked(self, x, y) then
            return true
        end

        return orig_mouse_clicked(self, o, button, x, y)
    end

    local orig_mouse_wheel_up = ContractBrokerGui.mouse_wheel_up

    function ContractBrokerGui:mouse_wheel_up(x, y)
        if selector_target(self, x, y) then
            set_tier(self, selected_tier() + 1)

            return true
        end

        return orig_mouse_wheel_up(self, x, y)
    end

    local orig_mouse_wheel_down = ContractBrokerGui.mouse_wheel_down

    function ContractBrokerGui:mouse_wheel_down(x, y)
        if selector_target(self, x, y) then
            set_tier(self, selected_tier() - 1)

            return true
        end

        return orig_mouse_wheel_down(self, x, y)
    end

    log("[CompletionTracker] Contract Broker loaded")
elseif not ContractBrokerGui then
    log("[CompletionTracker] ContractBrokerGui missing")
end
