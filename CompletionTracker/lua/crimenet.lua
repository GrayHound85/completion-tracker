---@diagnostic disable: undefined-global

-- Completion Tracker - Colors completed heists on Crime.net

dofile(ModPath .. "lua/config.lua")
CompletionTracker:Load()

local function apply_completion_color(gui_data)
	if not gui_data or not gui_data.job_id or not gui_data.side_panel then
		return
	end

	-- Crime.net contracts never carry the One Down tier, so the plain
	-- difficulty index is enough here.
	local tier = CompletionTracker:difficulty_index(gui_data.difficulty, false)

	if not CompletionTracker:job_completed_at_or_above(gui_data.job_id, tier) then
		return
	end

	-- Access the job_name element from the side_panel
	local side_panel = gui_data.side_panel

	if side_panel and alive(side_panel) then
		local job_name = side_panel:child("job_name")

		if job_name then
			job_name:set_color(CompletionTracker.COMPLETED_COLOR)
		end
	end
end

-- Wait for CrimeNetGui to be defined before hooking
if CrimeNetGui and CompletionTracker.settings.show_heist_completion then
	Hooks:PostHook(CrimeNetGui, "add_preset_job", "CompletionTracker_AddPresetJob", function(self, preset_id, ...)
		local gui_data = self._jobs[preset_id]
		apply_completion_color(gui_data)
	end)

	Hooks:PostHook(CrimeNetGui, "add_server_job", "CompletionTracker_AddServerJob", function(self, data, ...)
		local gui_data = self._jobs[data.id]
		apply_completion_color(gui_data)
	end)
elseif not CrimeNetGui then
	log("[CompletionTracker] WARNING: CrimeNetGui not found yet!")
end
