---@diagnostic disable: undefined-global
dofile(ModPath .. "config.lua")

-- Completion Tracker - Colors completed heists on Crime.net
local difficulty_order = {
	normal = 1,
	hard = 2,
	overkill = 3,
	overkill_145 = 4,
	easy_wish = 5,
	sm_wish = 6
}

local function completed_at_or_above(job_id, difficulty)
	local target_rank = difficulty_order[difficulty]
	
	if not target_rank then 
		return false 
	end

	for diff, rank in pairs(difficulty_order) do
		if rank >= target_rank then
			local is_completed = managers.statistics:completed_job(job_id, diff)
			-- Check if is_completed is truthy AND not 0
			if is_completed and is_completed ~= 0 then
				return true
			end
		end
	end

	return false
end

local function apply_completion_color(gui_data)
	if not gui_data or not gui_data.job_id or not gui_data.side_panel then
		return
	end

	local completed = completed_at_or_above(gui_data.job_id, gui_data.difficulty)

	if not completed then
		return
	end

	-- Access the job_name element from the side_panel
	local side_panel = gui_data.side_panel
	if side_panel and alive(side_panel) then
		local job_name = side_panel:child("job_name")

		if job_name then
			job_name:set_color(Color(0.3, 1, 0.3)) -- green
		end
	end
end

-- Wait for CrimeNetGui to be defined before hooking
if CrimeNetGui and CRIME_NET_CONFIG.show_completed_heists then
	Hooks:PostHook(CrimeNetGui, "add_preset_job", "CompletionTracker_AddPresetJob", function(self, preset_id, ...)
		local gui_data = self._jobs[preset_id]
		apply_completion_color(gui_data)
	end)

	Hooks:PostHook(CrimeNetGui, "add_server_job", "CompletionTracker_AddServerJob", function(self, data, ...)
		local gui_data = self._jobs[data.id]
		apply_completion_color(gui_data)
	end)
else
	log("[CompletionTracker] WARNING: CrimeNetGui not found yet!")
end
