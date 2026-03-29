---@diagnostic disable: undefined-global

log("[CompletionTracker] CrimeNet script loaded")

--- Tracking which heists you have already completed at current difficulty or higher.
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
	log("[CompletionTracker] completed_at_or_above - job_id:", job_id, "difficulty:", difficulty, "target_rank:", target_rank)
	
	if not target_rank then 
		log("[CompletionTracker] Difficulty not found in difficulty_order!")
		return false 
	end

	log("[CompletionTracker] Checking difficulties >= rank", target_rank)
	for diff, rank in pairs(difficulty_order) do
		log("[CompletionTracker]   diff:", diff, "rank:", rank, "target:", target_rank, "check?:", rank >= target_rank)
		if rank >= target_rank then
			local is_completed = managers.statistics:completed_job(job_id, diff)
			log("[CompletionTracker]     -> managers.statistics:completed_job(", job_id, ",", diff, ") =", is_completed, "type:", type(is_completed))
			-- Check if is_completed is truthy AND not 0 (since 0 is truthy in Lua but means not completed)
			if is_completed and is_completed ~= 0 then
				log("[CompletionTracker] FOUND COMPLETION at", diff, "- returning TRUE")
				return true
			end
		end
	end

	log("[CompletionTracker] No completion found - returning FALSE")
	return false
end

local function apply_completion_color(gui_data)
	if not gui_data or not gui_data.job_id or not gui_data.side_panel then
		return
	end

	log("[CompletionTracker] Checking job_id:", gui_data.job_id, "difficulty:", gui_data.difficulty, "difficulty_id:", gui_data.difficulty_id)

	local completed = completed_at_or_above(gui_data.job_id, gui_data.difficulty)
	
	log("[CompletionTracker] Completion result:", completed)

	if not completed then
		return
	end

	-- Access the job_name element from the side_panel
	local side_panel = gui_data.side_panel
	if side_panel and alive(side_panel) then
		local job_name = side_panel:child("job_name")

		if job_name then
			log("[CompletionTracker] Coloring job:", gui_data.job_id, "green")
			job_name:set_color(Color(0.3, 1, 0.3)) -- green
		end
	end
end

-- Wait for CrimeNetGui to be defined before hooking
if CrimeNetGui then
	log("[CompletionTracker] CrimeNetGui found, registering hooks")
	
	-- Hook add_preset_job
	Hooks:PostHook(CrimeNetGui, "add_preset_job", "CompletionTracker_AddPresetJob", function(self, preset_id, ...)
	    log("[CompletionTracker] add_preset_job fired")
		local gui_data = self._jobs[preset_id]
		apply_completion_color(gui_data)
	end)

	-- Hook add_server_job
	Hooks:PostHook(CrimeNetGui, "add_server_job", "CompletionTracker_AddServerJob", function(self, data, ...)
	    log("[CompletionTracker] add_server_job fired")
		local gui_data = self._jobs[data.id]
		apply_completion_color(gui_data)
	end)
else
	log("[CompletionTracker] WARNING: CrimeNetGui not found yet!")
end
