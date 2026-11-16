---@diagnostic disable: undefined-global

-- Completion Tracker - registers the stats page as a menu component, so a
-- menu node can list "completion_tracker" in its menu_components.

dofile(ModPath .. "lua/completiontrackergui.lua")

Hooks:PostHook(MenuComponentManager, "init", "CompletionTracker_AddComponent", function(self)
    if not self._active_components then
        log("[CompletionTracker] ERROR: _active_components missing")

        return
    end

    self._active_components.completion_tracker = {
        create = callback(self, self, "create_completion_tracker_gui"),
        close = callback(self, self, "close_completion_tracker_gui")
    }
end)

function MenuComponentManager:create_completion_tracker_gui(node)
    self:close_completion_tracker_gui()

    self._completion_tracker_gui = CompletionTrackerGui:new(self._ws, self._fullscreen_ws, node)

    -- Registering is what routes mouse and controller input to the page.
    self:register_component("completion_tracker", self._completion_tracker_gui)
end

function MenuComponentManager:close_completion_tracker_gui()
    if self._completion_tracker_gui then
        self._completion_tracker_gui:close()

        self._completion_tracker_gui = nil

        self:unregister_component("completion_tracker")
    end
end

function MenuComponentManager:completion_tracker_gui()
    return self._completion_tracker_gui
end
