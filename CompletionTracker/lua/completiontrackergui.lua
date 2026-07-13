log("==============================")
log(" COMPLETION TRACKER COMPONENT DEBUG")
log("==============================")


Hooks:PostHook(MenuComponentManager, "set_active_components", "CompletionTracker_DebugComponents", function(self, components, node)

    log("==============================")
    log("SET ACTIVE COMPONENTS DEBUG")
    log("==============================")


    if components then

        for i,component in ipairs(components) do

            log("REQUESTED COMPONENT: "..tostring(component))

        end

    end


    log("------------------------------")


    if self._active_components then

        log("ACTIVE COMPONENT TABLE EXISTS")


        for k,v in pairs(self._active_components) do

            log("ACTIVE KEY: "..tostring(k))
            log("ACTIVE VALUE: "..tostring(v))

        end


    else

        log("NO _active_components TABLE")

    end


    log("==============================")


end)