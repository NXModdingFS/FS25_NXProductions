ProductionAutoManager = {}

local DEBUG = false
local function dprint(...) if DEBUG then print("[ProductionAutoManager]", ...) end end

-- Check interval in milliseconds (check every 5 seconds)
ProductionAutoManager.CHECK_INTERVAL = 5000
ProductionAutoManager.lastCheckTime = 0

function ProductionAutoManager:loadMap(name)
    dprint("ProductionAutoManager initialized")
end

function ProductionAutoManager:update(dt)
    -- Only run on server
    if g_server == nil then
        return
    end
    
    -- Check if auto-management is enabled
    if not ProductionSettings or not ProductionSettings.autoManageEnabled then
        return
    end
    
    -- Check at intervals
    ProductionAutoManager.lastCheckTime = ProductionAutoManager.lastCheckTime + dt
    
    if ProductionAutoManager.lastCheckTime < ProductionAutoManager.CHECK_INTERVAL then
        return
    end
    
    ProductionAutoManager.lastCheckTime = 0
    ProductionAutoManager:checkAllProductions()
end

function ProductionAutoManager:checkAllProductions()
    if g_currentMission == nil or g_currentMission.productionChainManager == nil then
        return
    end
    
    for _, productionPoint in pairs(g_currentMission.productionChainManager.productionPoints) do
        self:manageProduction(productionPoint)
    end
end

function ProductionAutoManager:manageProduction(productionPoint)
    if productionPoint.storage == nil or productionPoint.productions == nil then
        return
    end
    
    for _, production in pairs(productionPoint.productions) do
        -- Skip inactive productions (not configured)
        if production.status == ProductionPoint.PROD_STATUS.INACTIVE then
            goto continue
        end
        
        local shouldActivate = self:shouldActivateProduction(productionPoint, production)
        local isRunning = production.status == ProductionPoint.PROD_STATUS.RUNNING
        
        if shouldActivate and not isRunning then
            -- Activate production
            dprint(string.format("Activating production '%s' at '%s'", 
                production.name or "Unknown", 
                productionPoint:getName()))
            productionPoint:setProductionState(production.id, ProductionPoint.PROD_STATUS.RUNNING)
            
        elseif not shouldActivate and isRunning then
            -- Deactivate production
            dprint(string.format("Deactivating production '%s' at '%s'", 
                production.name or "Unknown", 
                productionPoint:getName()))
            productionPoint:setProductionState(production.id, ProductionPoint.PROD_STATUS.MISSING_INPUTS)
        end
        
        ::continue::
    end
end

function ProductionAutoManager:shouldActivateProduction(productionPoint, production)
    local storage = productionPoint.storage
    
    -- Check if all outputs have capacity
    if production.outputs ~= nil then
        for _, output in pairs(production.outputs) do
            local fillLevel = storage:getFillLevel(output.type)
            local capacity = storage:getCapacity(output.type)
            
            if capacity > 0 then
                local fillPercent = (fillLevel / capacity) * 100
                
                -- If any output is at or above 95% capacity, deactivate
                if fillPercent >= 95 then
                    dprint(string.format("Output '%s' is full (%.1f%%), deactivating", 
                        g_fillTypeManager:getFillTypeNameByIndex(output.type), 
                        fillPercent))
                    return false
                end
            end
        end
    end
    
    -- Check if all inputs are available
    if production.inputs ~= nil then
        for _, input in pairs(production.inputs) do
            local fillLevel = storage:getFillLevel(input.type)
            
            -- If any input is below the required amount, don't activate
            if fillLevel < input.amount then
                dprint(string.format("Input '%s' insufficient (%.1f / %.1f), not activating", 
                    g_fillTypeManager:getFillTypeNameByIndex(input.type), 
                    fillLevel, 
                    input.amount))
                return false
            end
        end
    end
    
    -- All conditions met: outputs have space and inputs are available
    return true
end

function ProductionAutoManager:deleteMap()
    dprint("ProductionAutoManager cleaned up")
end

addModEventListener(ProductionAutoManager)