---@diagnostic disable: undefined-global

-- Completion Tracker - the stats page opened from the main menu.
--
-- Layout:
--   left   one row per category, each with a small completion ring
--   right  detail panel for the selected row, with a large ring and a
--          scrolling list of numbers
--   top    toggle between "owned DLC only" and "everything in the game"

dofile(ModPath .. "lua/config.lua")
dofile(ModPath .. "lua/completionstats.lua")

if not CompletionTracker.settings then
    CompletionTracker:Load()
end

CompletionTrackerGui = CompletionTrackerGui or class()

local PAD = 10

-- Both are ring textures the game itself draws with the radial shader.
local RING_SMALL = "guis/textures/pd2/level_ring_small"
local RING_LARGE = "guis/textures/pd2/endscreen/exp_ring"

local OVERALL_ID = "overall"
local ids_left_mouse = Idstring("0")
local ids_cancel = Idstring("cancel")

-- Row selected last time the page was open, kept until the game closes.
local last_selected = OVERALL_ID

--------------------------------------------------
-- SMALL HELPERS
--------------------------------------------------

local FONTS = {
    large = { "pd2_large_font", "pd2_large_font_size", 44 },
    medium = { "pd2_medium_font", "pd2_medium_font_size", 24 },
    small = { "pd2_small_font", "pd2_small_font_size", 20 },
    tiny = { "pd2_tiny_font", "pd2_tiny_font_size", 16 }
}

local function font_of(size)
    local font = FONTS[size] or FONTS.small
    local name = tweak_data.menu[font[1]] or tweak_data.menu.pd2_small_font
    local font_size = tweak_data.menu[font[2]] or font[3]

    return name, font_size
end

-- Shrinks a text object to the size of its text.
local function fine_text(text)
    local _, _, w, h = text:text_rect()

    text:set_size(math.ceil(w), math.ceil(h))
    text:set_position(math.round(text:x()), math.round(text:y()))
end

local function make_text(parent, str, size, color, params)
    local font, font_size = font_of(size)
    local config = {
        text = str,
        font = font,
        font_size = font_size,
        color = color or tweak_data.screen_colors.text,
        align = "left",
        vertical = "top",
        layer = 2
    }

    for key, value in pairs(params or {}) do
        config[key] = value
    end

    local text = parent:text(config)

    if not config.wrap then
        fine_text(text)
    end

    return text
end

-- Counts a ring up from empty when the page opens.
local function animate_ring(o, target)
    local duration = 0.45
    local t = 0

    while t < duration do
        t = t + coroutine.yield()

        local p = math.min(t / duration, 1)

        p = 1 - (1 - p) * (1 - p)

        o:set_color(Color(target * p, 1, 1))
    end

    o:set_color(Color(target, 1, 1))
end

-- A radial completion ring. The game's ring textures are white and the
-- radial shader ignores tinting, so a finished ring is drawn as a plain
-- tinted bitmap instead, which lets it turn green.
local function make_ring(parent, x, y, size, progress, animate)
    local texture = RING_SMALL

    if size > 96 and DB:has(Idstring("texture"), RING_LARGE) then
        texture = RING_LARGE
    end

    progress = math.max(0, math.min(1, progress or 0))

    parent:bitmap({
        texture = texture,
        x = x,
        y = y,
        w = size,
        h = size,
        layer = 1,
        alpha = 0.18,
        color = Color.white
    })

    if progress >= 1 then
        return parent:bitmap({
            texture = texture,
            x = x,
            y = y,
            w = size,
            h = size,
            layer = 2,
            color = CompletionTracker.COMPLETED_COLOR
        })
    end

    local ring = parent:bitmap({
        texture = texture,
        render_template = "VertexColorTexturedRadial",
        blend_mode = "add",
        x = x,
        y = y,
        w = size,
        h = size,
        layer = 2,
        color = Color(animate and 0 or progress, 1, 1)
    })

    if animate and progress > 0 then
        ring:animate(animate_ring, progress)
    end

    return ring
end

--------------------------------------------------
-- SETUP
--------------------------------------------------

function CompletionTrackerGui:init(ws, fullscreen_ws, node)
    self._node = node
    self._fullscreen_ws = managers.gui_data:create_fullscreen_16_9_workspace()
    self._ws = managers.gui_data:create_saferect_workspace()

    local layer = tweak_data.gui.MENU_COMPONENT_LAYER or 300

    self._fullscreen_panel = self._fullscreen_ws:panel():panel({ layer = layer })
    self._panel = self._ws:panel():panel({ layer = layer + 1 })

    self._include_all = CompletionTracker.settings.stats_all_content and true or false
    self._selected = last_selected
    self._first_build = true

    self:_create_background()
    self:_rebuild()
end

function CompletionTrackerGui:close()
    if self._ws and alive(self._ws) then
        managers.gui_data:destroy_workspace(self._ws)
    end

    if self._fullscreen_ws and alive(self._fullscreen_ws) then
        managers.gui_data:destroy_workspace(self._fullscreen_ws)
    end

    self._ws = nil
    self._fullscreen_ws = nil
    self._scroll = nil
    self._rows = {}
end

function CompletionTrackerGui:_create_background()
    self._fullscreen_panel:rect({
        alpha = 0.6,
        layer = 1,
        color = Color.black
    })
    self._fullscreen_panel:bitmap({
        texture = "guis/textures/test_blur_df",
        render_template = "VertexColorTexturedBlur3D",
        layer = 0,
        halign = "scale",
        valign = "scale",
        w = self._fullscreen_panel:w(),
        h = self._fullscreen_panel:h()
    })
end

-- Gathers the stats again and redraws the whole page.
function CompletionTrackerGui:_rebuild()
    if self._content and alive(self._content) then
        self._panel:remove(self._content)
    end

    -- Everything below lived inside the old content panel and went with it.
    self._content = self._panel:panel({})
    self._rows = {}
    self._list = nil
    self._detail = nil
    self._scroll = nil
    self._hover = nil
    self._toggle_buttons = {}
    self._back_button = nil
    self._back_highlighted = false

    local ok, stats = pcall(function ()
        return CompletionStats:new():get_stats(self._include_all)
    end)

    if not ok then
        log("[CompletionTracker] Failed to gather stats: " .. tostring(stats))
        self:_create_header()
        make_text(self._content, "The completion stats could not be read.\n" .. tostring(stats), "small", tweak_data.screen_colors.important_1, {
            y = 80,
            w = self._content:w(),
            h = 200,
            wrap = true,
            word_wrap = true
        })

        return
    end

    self._stats = stats

    if not self:_entry(self._selected) then
        self._selected = OVERALL_ID
    end

    self:_create_header()
    self:_create_rows()
    self:_create_detail()

    self._first_build = false
end

-- The overall block or a category, by row id.
function CompletionTrackerGui:_entry(id)
    if not self._stats then
        return nil
    end

    if id == OVERALL_ID then
        return self._stats.overall
    end

    for _, category in ipairs(self._stats.categories) do
        if category.id == id then
            return category
        end
    end

    return nil
end

--------------------------------------------------
-- HEADER: title, content toggle, back button
--------------------------------------------------

function CompletionTrackerGui:_create_header()
    local panel = self._content
    local colors = tweak_data.screen_colors

    local title = make_text(panel, "COMPLETION TRACKER", "large", colors.text)

    self._top = title:bottom() + PAD

    -- Content toggle, built right to left from the top right corner.
    self._toggle_buttons = {}

    local options = {
        { text = "EVERYTHING IN THE GAME", value = true },
        { text = "OWNED DLC ONLY", value = false }
    }
    local right = panel:w()
    local center_y = title:center_y()

    for _, option in ipairs(options) do
        local active = option.value == self._include_all
        local button = make_text(panel, option.text, "small", active and colors.button_stage_2 or colors.button_stage_3, {
            blend_mode = active and "add" or "normal"
        })

        button:set_right(right)
        button:set_center_y(center_y)

        if active then
            local underline = panel:rect({
                h = 2,
                layer = 2,
                color = colors.button_stage_2,
                w = button:w()
            })

            underline:set_left(button:left())
            underline:set_top(button:bottom())
        end

        table.insert(self._toggle_buttons, { text = button, value = option.value, active = active })

        right = button:left() - PAD * 2
    end

    local label = make_text(panel, "COUNT:", "small", colors.text, { alpha = 0.6 })

    label:set_right(right)
    label:set_center_y(center_y)

    -- Back button and hint along the bottom edge.
    if managers.menu:is_pc_controller() then
        self._back_button = make_text(panel, managers.localization:to_upper_text("menu_back"), "medium", colors.button_stage_3)

        self._back_button:set_right(panel:w())
        self._back_button:set_bottom(panel:h())
    else
        self._back_button = nil
    end

    local hint = make_text(panel, "SELECT A CATEGORY FOR THE DETAILS", "tiny", colors.text, { alpha = 0.5 })

    hint:set_left(0)
    hint:set_bottom(panel:h())

    -- Everything else sits between the title and the bottom row.
    local _, bottom_row_h = font_of("medium")

    self._bottom = panel:h() - bottom_row_h - PAD
end

--------------------------------------------------
-- LEFT: category rows
--------------------------------------------------

function CompletionTrackerGui:_create_rows()
    local panel = self._content
    local colors = tweak_data.screen_colors
    local stats = self._stats
    local fmt_pct = CompletionStats.fmt_pct

    local list_w = math.floor(panel:w() * 0.38)
    local list_h = self._bottom - self._top
    local list = panel:panel({
        x = 0,
        y = self._top,
        w = list_w,
        h = list_h
    })

    self._list = list

    -- Overall card
    local card_h = 100
    local card = list:panel({ x = 0, y = 0, w = list_w, h = card_h })

    card:rect({ color = Color.black, alpha = 0.4, layer = 0 })
    BoxGuiObject:new(card, { sides = { 1, 1, 1, 1 } })

    local card_bg = card:rect({
        blend_mode = "add",
        layer = 1,
        visible = false,
        color = colors.button_stage_3
    })
    local ring_size = card_h - 16

    make_ring(card, 8, 8, ring_size, stats.overall.progress, self._first_build)

    local text_x = ring_size + 8 + PAD * 1.5
    local card_title = make_text(card, "OVERALL COMPLETION", "small", colors.text, { x = text_x, y = 8 })
    local card_pct = make_text(card, fmt_pct(stats.overall.progress), "large", colors.text, { x = text_x })
    local card_hours = make_text(card, stats.overall.summary .. " OF CONTENT, ESTIMATED", "tiny", colors.text, { x = text_x, alpha = 0.6 })

    card_hours:set_bottom(card_h - 8)
    card_pct:set_center_y((card_title:bottom() + card_hours:top()) / 2)

    table.insert(self._rows, {
        id = OVERALL_ID,
        panel = card,
        bg = card_bg,
        name = card_title
    })

    -- One row per category
    local categories = stats.categories
    local rows_top = card_h + PAD
    local row_h = math.floor(math.min(44, (list_h - rows_top) / math.max(1, #categories)))

    for index, category in ipairs(categories) do
        local row = list:panel({
            x = 0,
            y = rows_top + (index - 1) * row_h,
            w = list_w,
            h = row_h
        })
        local bg = row:rect({
            blend_mode = "add",
            layer = 0,
            visible = false,
            color = colors.button_stage_3
        })

        row:rect({
            h = 1,
            y = row_h - 1,
            layer = 1,
            alpha = 0.1,
            color = Color.white
        })

        local small_ring = row_h - 10
        local has_progress = category.progress ~= nil

        if has_progress then
            make_ring(row, 6, 5, small_ring, category.progress, false)
        else
            local symbol = make_text(row, "$", "medium", colors.text, { alpha = 0.7 })

            symbol:set_center(6 + small_ring / 2, row_h / 2)
        end

        local name = make_text(row, category.name, "small", colors.text, { x = small_ring + 6 + PAD })

        name:set_center_y(row_h / 2)

        local right = list_w - 8

        if has_progress then
            local done = category.progress >= 1
            local pct = make_text(row, fmt_pct(category.progress), "small", done and CompletionTracker.COMPLETED_COLOR or colors.text)

            pct:set_right(right)
            pct:set_center_y(row_h / 2)

            right = list_w - 8 - 68
        end

        if category.summary then
            local summary = make_text(row, category.summary, "tiny", colors.text, { alpha = 0.6 })

            summary:set_right(right)
            summary:set_center_y(row_h / 2)

            -- Not enough room next to a long name, the number matters more.
            if summary:left() < name:right() + PAD then
                summary:set_visible(false)
            end
        end

        table.insert(self._rows, {
            id = category.id,
            panel = row,
            bg = bg,
            name = name
        })
    end

    self:_refresh_rows()
end

function CompletionTrackerGui:_refresh_rows()
    local colors = tweak_data.screen_colors

    for _, row in ipairs(self._rows) do
        local selected = row.id == self._selected
        local hovered = row.id == self._hover

        row.bg:set_visible(selected or hovered)
        row.bg:set_alpha(selected and 0.4 or 0.15)
        row.name:set_color(selected and colors.button_stage_2 or colors.text)
    end
end

function CompletionTrackerGui:_select(id, silent)
    if id == self._selected or not self:_entry(id) then
        return
    end

    self._selected = id
    last_selected = id

    self:_refresh_rows()
    self:_create_detail()

    if not silent then
        managers.menu:post_event("menu_enter")
    end
end

--------------------------------------------------
-- RIGHT: detail panel
--------------------------------------------------

function CompletionTrackerGui:_create_detail()
    local panel = self._content
    local colors = tweak_data.screen_colors
    local entry = self:_entry(self._selected)

    if self._detail and alive(self._detail) then
        panel:remove(self._detail)
    end

    self._scroll = nil

    if not entry then
        return
    end

    local x = self._list:right() + PAD * 2
    local detail = panel:panel({
        x = x,
        y = self._top,
        w = panel:w() - x,
        h = self._bottom - self._top
    })

    self._detail = detail

    detail:rect({ color = Color.black, alpha = 0.4, layer = 0 })
    BoxGuiObject:new(detail, { sides = { 1, 1, 1, 1 } })

    -- Header: large ring with the percentage inside, title beside it.
    local header_h = 148
    local has_progress = entry.progress ~= nil
    local text_x = PAD * 2

    if has_progress then
        local ring_size = header_h - PAD * 2

        make_ring(detail, PAD, PAD, ring_size, entry.progress, true)

        local done = entry.progress >= 1
        local pct = make_text(detail, CompletionStats.fmt_pct(entry.progress), "medium", done and CompletionTracker.COMPLETED_COLOR or colors.text)

        pct:set_center(PAD + ring_size / 2, PAD + ring_size / 2)

        text_x = PAD + ring_size + PAD * 2
    end

    local is_overall = self._selected == OVERALL_ID
    local title = make_text(detail, is_overall and "OVERALL COMPLETION" or entry.name, "large", colors.text, {
        x = text_x,
        y = PAD + 8
    })

    -- Long names must not run out of the panel.
    local max_w = detail:w() - text_x - PAD

    if title:w() > max_w then
        title:set_font_size(title:font_size() * max_w / title:w())
        fine_text(title)
    end

    local sub_y = title:bottom() + 2

    if entry.summary then
        local summary = make_text(detail, entry.summary, "medium", colors.button_stage_2, {
            x = text_x,
            y = sub_y,
            blend_mode = "add"
        })

        sub_y = summary:bottom() + 2
    end

    local caption = nil

    if is_overall then
        caption = self._include_all and "Counting everything in the game" or "Counting content from DLC you own"
    elseif entry.failed then
        caption = "This section could not be read"
    elseif (entry.hours_total or 0) > 0 then
        local share = self._stats.overall.hours_total > 0 and entry.hours_total / self._stats.overall.hours_total or 0

        caption = "Worth " .. CompletionStats.fmt_hours(entry.hours_total) .. " of the overall estimate, " .. CompletionStats.fmt_pct(share)
    else
        caption = "Not part of the overall percentage"
    end

    make_text(detail, caption, "tiny", colors.text, { x = text_x, y = sub_y, alpha = 0.6 })

    detail:rect({
        h = 1,
        x = PAD,
        y = header_h,
        w = detail:w() - PAD * 2,
        layer = 1,
        alpha = 0.25,
        color = Color.white
    })

    -- Scrolling list of numbers
    self._scroll = ScrollablePanel:new(detail, "completion_tracker_detail", {
        x = 0,
        y = header_h + 2,
        w = detail:w(),
        h = detail:h() - header_h - 4,
        padding = PAD,
        layer = 1
    })

    self:_fill_lines(entry.lines or {})

    -- Twice on purpose, the first pass decides whether a scroll bar is
    -- needed and the second sizes the canvas for it (the contract broker
    -- does the same).
    self._scroll:update_canvas_size()
    self._scroll:update_canvas_size()
end

function CompletionTrackerGui:_fill_lines(lines)
    local colors = tweak_data.screen_colors
    local canvas = self._scroll:canvas()

    -- Always lay out for the width that is left once a scroll bar shows,
    -- otherwise right aligned numbers end up underneath it.
    local w = self._scroll:canvas_scroll_width()
    local pct_w = 64
    local y = 0

    for _, line in ipairs(lines) do
        if line.type == "header" then
            if y > 0 then
                y = y + 4
            end

            local text = make_text(canvas, line.text, "small", colors.button_stage_2, {
                x = 0,
                y = y,
                blend_mode = "add"
            })

            y = text:bottom() + 2

            canvas:rect({
                x = 0,
                y = y,
                w = w,
                h = 1,
                alpha = 0.3,
                color = colors.button_stage_2
            })

            y = y + 6
        elseif line.type == "stat" then
            local has_progress = line.progress ~= nil
            local done = has_progress and line.progress >= 1
            local value_color = done and CompletionTracker.COMPLETED_COLOR or colors.text
            local label = make_text(canvas, line.label or "", "small", colors.text, { x = 0, y = y, alpha = 0.85 })
            local value_right = w
            local show_pct = has_progress and not string.find(line.value or "", "%%", 1)

            if show_pct then
                local pct = make_text(canvas, CompletionStats.fmt_pct(line.progress), "small", value_color, { y = y })

                pct:set_right(w)

                value_right = w - pct_w - PAD
            end

            local value = make_text(canvas, line.value or "", "small", value_color, { y = y })

            value:set_right(value_right)

            y = label:bottom()

            if has_progress then
                y = y + 1

                canvas:rect({
                    x = 0,
                    y = y,
                    w = w,
                    h = 4,
                    alpha = 0.12,
                    color = Color.white
                })

                if line.progress > 0 then
                    canvas:rect({
                        x = 0,
                        y = y,
                        w = math.max(2, math.floor(w * math.min(1, line.progress))),
                        h = 4,
                        layer = 1,
                        color = done and CompletionTracker.COMPLETED_COLOR or colors.button_stage_2
                    })
                end

                y = y + 4 + 7
            else
                y = y + 3
            end
        elseif line.type == "note" then
            local text = make_text(canvas, line.text or "", "tiny", colors.text, {
                x = 0,
                y = y,
                w = w,
                h = 400,
                alpha = 0.55,
                wrap = true,
                word_wrap = true
            })
            local _, _, _, text_h = text:text_rect()

            text:set_h(math.ceil(text_h))

            y = text:bottom() + 6
        else
            y = y + 10
        end
    end

    -- Keeps the last line clear of the bottom edge.
    canvas:panel({ x = 0, y = y, w = 1, h = PAD })
end

--------------------------------------------------
-- CONTENT TOGGLE
--------------------------------------------------

function CompletionTrackerGui:_set_include_all(include_all)
    if include_all == self._include_all then
        return
    end

    self._include_all = include_all

    CompletionTracker.settings.stats_all_content = include_all
    CompletionTracker:Save()

    managers.menu:post_event("menu_enter")
    self:_rebuild()
end

--------------------------------------------------
-- INPUT
--------------------------------------------------

function CompletionTrackerGui:input_focus()
    return 1
end

function CompletionTrackerGui:_row_at(x, y)
    if not self._list or not alive(self._list) or not self._list:inside(x, y) then
        return nil
    end

    for _, row in ipairs(self._rows) do
        if row.panel:inside(x, y) then
            return row
        end
    end

    return nil
end

function CompletionTrackerGui:mouse_moved(o, x, y)
    if not self._content or not alive(self._content) then
        return
    end

    local colors = tweak_data.screen_colors
    local used = false
    local pointer = nil

    if self._scroll then
        local scroll_used, scroll_pointer = self._scroll:mouse_moved(o, x, y)

        if scroll_used then
            used = true
            pointer = scroll_pointer
        end
    end

    local row = not used and self:_row_at(x, y) or nil
    local hover = row and row.id or nil

    if hover ~= self._hover then
        self._hover = hover

        self:_refresh_rows()

        if hover and hover ~= self._selected then
            managers.menu:post_event("highlight")
        end
    end

    if row then
        used = true
        pointer = row.id ~= self._selected and "link" or "arrow"
    end

    for _, button in ipairs(self._toggle_buttons or {}) do
        if not button.active then
            local inside = not used and button.text:inside(x, y)

            if inside then
                used = true
                pointer = "link"

                if not button.highlighted then
                    button.highlighted = true

                    button.text:set_color(colors.button_stage_2)
                    managers.menu:post_event("highlight")
                end
            elseif button.highlighted then
                button.highlighted = false

                button.text:set_color(colors.button_stage_3)
            end
        end
    end

    if self._back_button and alive(self._back_button) then
        if not used and self._back_button:inside(x, y) then
            used = true
            pointer = "link"

            if not self._back_highlighted then
                self._back_highlighted = true

                self._back_button:set_color(colors.button_stage_2)
                self._back_button:set_blend_mode("add")
                managers.menu:post_event("highlight")
            end
        elseif self._back_highlighted then
            self._back_highlighted = false

            self._back_button:set_color(colors.button_stage_3)
            self._back_button:set_blend_mode("normal")
        end
    end

    if used then
        return true, pointer
    end
end

function CompletionTrackerGui:mouse_pressed(button, x, y)
    if self._scroll and self._scroll:mouse_pressed(button, x, y) then
        self._scroll_event = true

        return true
    end
end

function CompletionTrackerGui:mouse_released(o, button, x, y)
    if self._scroll and self._scroll:mouse_released(button, x, y) then
        self._scroll_event = true

        return true
    end
end

function CompletionTrackerGui:mouse_clicked(o, button, x, y)
    -- A click that ends a scroll bar drag is not a click on what is under it.
    if self._scroll_event then
        self._scroll_event = nil

        return
    end

    if button ~= ids_left_mouse or not self._content or not alive(self._content) then
        return
    end

    if self._scroll and self._scroll:mouse_clicked(o, button, x, y) then
        return true
    end

    local row = self:_row_at(x, y)

    if row then
        self:_select(row.id)

        return true
    end

    for _, toggle in ipairs(self._toggle_buttons or {}) do
        if toggle.text:inside(x, y) then
            self:_set_include_all(toggle.value)

            return true
        end
    end

    if self._back_button and alive(self._back_button) and self._back_button:inside(x, y) then
        managers.menu:back(true)

        return true
    end
end

function CompletionTrackerGui:mouse_wheel_up(x, y)
    if self._scroll then
        return self._scroll:scroll(x, y, 1)
    end
end

function CompletionTrackerGui:mouse_wheel_down(x, y)
    if self._scroll then
        return self._scroll:scroll(x, y, -1)
    end
end

-- Keyboard and controller: up and down walk the category list.
function CompletionTrackerGui:_move_selection(direction)
    local current = 1

    for index, row in ipairs(self._rows) do
        if row.id == self._selected then
            current = index

            break
        end
    end

    local target = self._rows[math.clamp(current + direction, 1, #self._rows)]

    if target then
        self:_select(target.id)
    end

    return true
end

function CompletionTrackerGui:move_up()
    return self:_move_selection(-1)
end

function CompletionTrackerGui:move_down()
    return self:_move_selection(1)
end

function CompletionTrackerGui:update(t, dt)
    -- Right stick scrolls the detail panel on a controller.
    if not self._scroll then
        return
    end

    local _, axis_y = managers.menu_component:get_right_controller_axis()

    if axis_y and axis_y ~= 0 then
        self._scroll:perform_scroll(math.abs(axis_y * 500 * dt), math.sign(axis_y))
    end
end

function CompletionTrackerGui:back_pressed()
    managers.menu:back(true)
end

function CompletionTrackerGui:special_btn_pressed(button)
    if button == ids_cancel then
        managers.menu:back(true)
    end
end
