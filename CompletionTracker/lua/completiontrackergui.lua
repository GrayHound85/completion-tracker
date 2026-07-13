MenuComponentCompletionTracker = MenuComponentCompletionTracker or class()


function MenuComponentCompletionTracker:init(ws, fullscreen_ws, node)

    self._ws = ws
    self._fullscreen_ws = fullscreen_ws
    self._node = node


    self._panel = self._ws:panel():panel({
        name = "completion_tracker_panel",
        layer = 1000
    })


    self._text = self._panel:text({
        name = "test_text",
        text = "COMPLETION TRACKER WORKS!",
        font = tweak_data.menu.pd2_large_font,
        font_size = 50,
        color = Color.white,
        align = "center",
        vertical = "center",
        layer = 1001
    })


    self._text:set_center(
        self._panel:w() / 2,
        self._panel:h() / 2
    )


    log("[CompletionTracker] TEXT CREATED")

end



function MenuComponentCompletionTracker:close()

    if alive(self._panel) then
        self._panel:clear()
    end

end