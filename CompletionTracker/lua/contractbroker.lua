-- Completion Tracker - Contract Broker
---@diagnostic disable: undefined-global

dofile(ModPath .. "lua/config.lua")
CompletionTracker:Load()


-- Completion Check
local function completed_at_dsod(job_id)

    local completed = managers.statistics:completed_job(
        job_id,
        "sm_wish",
        true
    )

    return completed and completed > 0
end



-- UI
local function set_job_name_color(job_name)

    if job_name and alive(job_name) then
        job_name:set_color(Color(0.3, 1, 0.3))
    end

end


local function find_job_name_widget(item)

    if not item or not item._panel or not alive(item._panel) then
        return nil
    end

    local job_data = item._job_data

    if not job_data or not job_data.job_id then
        return nil
    end

    local job_tweak = tweak_data.narrative:job_data(job_data.job_id)

    if not job_tweak then
        return nil
    end

    local expected_text = managers.localization:to_upper_text(job_tweak.name_id)

    if not expected_text then
        return nil
    end

    for _, child in ipairs(item._panel:children()) do
        if child and alive(child)
            and child.text
            and child.set_color
            and type(child.text) == "function"
            then

            local text = child:text()

            if text == expected_text then
                return child
            end
        end
    end


    return nil
end


local function color_contract_item(item)
    if not CompletionTracker.settings.show_contract_completion then
        return
    end

    if not item._job_data or not item._job_data.job_id then
        return
    end

    if completed_at_dsod(item._job_data.job_id) then
        local job_name = find_job_name_widget(item)

        if job_name then
            set_job_name_color(job_name)
        end
    end
end



-- Hooks
if ContractBrokerHeistItem then
    Hooks:PostHook(
        ContractBrokerHeistItem,
        "init",
        "CompletionTracker_ContractBroker_Init",
        function(self)
            color_contract_item(self)
        end
    )
    Hooks:PostHook(
        ContractBrokerHeistItem,
        "refresh",
        "CompletionTracker_ContractBroker_Refresh",
        function(self)
            color_contract_item(self)
        end
    )

    log("[CompletionTracker] Contract Broker loaded")
else
    log("[CompletionTracker] ContractBrokerHeistItem missing")

end