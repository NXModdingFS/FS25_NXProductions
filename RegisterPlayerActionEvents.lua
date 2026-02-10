PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    function(self, controlling)
        if controlling ~= "VEHICLE" or true then
            local triggerUp, triggerDown, triggerAlways, startActive, callbackState, disableConflictingBindings = 
                false, true, false, true, nil, true

            local success, actionEventId, otherEvents = g_inputBinding:registerActionEvent(
                InputAction.SHOW_PRODUCTION_DLG, 
                ProductionOverview, 
                ProductionOverview.ShowProductionDlg, 
                triggerUp, triggerDown, triggerAlways, startActive, callbackState, disableConflictingBindings
            )

            if success then
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
                g_inputBinding:setActionEventTextVisibility(actionEventId, true)
            end    
        end
    end
)