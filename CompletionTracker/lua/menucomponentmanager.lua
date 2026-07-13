Hooks:PostHook(MenuComponentManager, "init", "CompletionTracker_AddComponent", function(self)

    log("==============================")
    log("[CompletionTracker] MenuComponentManager init hook")
    log("==============================")


    if not self._active_components then
        log("[CompletionTracker] ERROR: _active_components does not exist")
        return
    end


    self._active_components.completion_tracker = {
        create = callback(self, self, "create_completion_tracker_gui"),
        close = callback(self, self, "close_completion_tracker_gui")
    }


    log("[CompletionTracker] Added completion_tracker component")

end)

function MenuComponentManager:create_completion_tracker_gui()

    log("[CompletionTracker] Creating GUI")


    if self._completion_tracker_gui then
        return
    end


    self._completion_tracker_gui = MenuComponentCompletionTracker:new(
        self._ws,
        self._fullscreen_ws,
        nil
    )

end



function MenuComponentManager:close_completion_tracker_gui()

    log("[CompletionTracker] Closing GUI")


    if self._completion_tracker_gui then
        self._completion_tracker_gui:close()
        self._completion_tracker_gui = nil
    end

end