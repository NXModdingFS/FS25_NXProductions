local isDbPrintfOn = false

local function dbPrintf(...)
    if isDbPrintfOn then
        print(string.format(...))
    end
end

dbPrintf("FS25_ProductionOverview: register global player action events")

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
                dbPrintf("FS25_ProductionOverview - Register key (controlling=%s, action=%s, actionId=%s)", 
                    controlling, InputAction.SHOW_PRODUCTION_DLG, actionEventId)
            else
                dbPrintf("FS25_ProductionOverview - Failed to register key (controlling=%s, action=%s, actionId=%s)", 
                    controlling, InputAction.SHOW_PRODUCTION_DLG, actionEventId)
            end    
        end
    end
)