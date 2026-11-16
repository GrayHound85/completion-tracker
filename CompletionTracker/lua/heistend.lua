---@diagnostic disable: undefined-global

-- Completion Tracker - popup when a heist is finished on a harder difficulty
-- than ever before. It uses the same popup the game shows for achievements.
--
-- The game records the completion inside StatisticsManager:stop_session, so
-- the best difficulty is read just before and just after that call.

dofile(ModPath .. "lua/config.lua")
CompletionTracker:Load()

Hooks:PreHook(StatisticsManager, "stop_session", "CompletionTracker_BestBefore", function(self, data)
    self._ct_best_before = nil

    if not CompletionTracker.settings.show_new_best_popup then
        return
    end

    -- Only the final day of a successful job records a completion.
    if not self._session_started or not data or data.type ~= "victory" then
        return
    end

    local ok, err = pcall(function ()
        local job_id = managers.job:current_job_id()

        if job_id and managers.job:on_last_stage() then
            self._ct_best_before = {
                job_id = job_id,
                tier = CompletionTracker:highest_completed_tier(job_id)
            }
        end
    end)

    if not ok then
        log("[CompletionTracker] Could not read the best difficulty before the heist ended: " .. tostring(err))
    end
end)

Hooks:PostHook(StatisticsManager, "stop_session", "CompletionTracker_BestAfter", function(self)
    local before = self._ct_best_before

    self._ct_best_before = nil

    if not before then
        return
    end

    local ok, err = pcall(function ()
        local best = CompletionTracker:highest_completed_tier(before.job_id)

        -- Joining a heist part way through does not count as a completion,
        -- so nothing changes and nothing is shown.
        if best <= before.tier or not managers.hud then
            return
        end

        local job_tweak = tweak_data.narrative:job_data(before.job_id)
        local job_name = job_tweak and managers.localization:to_upper_text(job_tweak.name_id) or string.upper(tostring(before.job_id))
        local title = before.tier == 0 and "FIRST COMPLETION" or "NEW BEST DIFFICULTY"

        managers.hud:custom_ingame_popup_text(title, job_name .. "\n" .. CompletionTracker:difficulty_name(best), nil)
    end)

    if not ok then
        log("[CompletionTracker] Could not show the new best difficulty popup: " .. tostring(err))
    end
end)
