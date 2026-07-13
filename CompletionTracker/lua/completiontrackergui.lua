MenuComponentCompletionTracker = MenuComponentCompletionTracker or class()


function MenuComponentCompletionTracker:init(ws, fullscreen_ws, node)

    log("[CompletionTracker] INSTANCE CREATED")


    self._ws = ws
    self._fullscreen_ws = fullscreen_ws
    self._node = node


    self._panel = self._ws:panel():panel({
        name = "completion_tracker_panel",
        layer = 1000
    })


    log("[CompletionTracker] PANEL SIZE " .. self._panel:w() .. "x" .. self._panel:h())


    self._title = self:create_text(
        self._panel,
        "completion_tracker_title",
        "COMPLETION TRACKER",
        50,
        80
    )


    self._info = self:create_text(
        self._panel,
        "completion_tracker_info",
        "Your heist completion progress will appear here.",
        35,
        200
    )


    log("[CompletionTracker] GUI CREATED")

end



function MenuComponentCompletionTracker:create_text(parent, name, text, size, y)

    local label = parent:text({

        name = name,

        text = text,

        font = tweak_data.menu.pd2_large_font,

        font_size = size,

        color = Color.white,

        align = "center",

        vertical = "center",

        layer = 1001
    })


    label:set_size(
        parent:w(),
        70
    )


    label:set_center_x(
        parent:w() / 2
    )


    label:set_y(y)


    label:set_visible(true)

    label:set_alpha(1)


    return label

end



function MenuComponentCompletionTracker:update_progress(text)

    if alive(self._info) then

        self._info:set_text(text)

    end

end



function MenuComponentCompletionTracker:close()

    log("[CompletionTracker] GUI CLOSE")


    if alive(self._panel) then

        self._panel:clear()

    end

end