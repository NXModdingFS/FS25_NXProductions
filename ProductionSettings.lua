ProductionSettings = {}
ProductionSettings.SETTINGS = {}
ProductionSettings.CONTROLS = {}

-- Network Event for Settings Synchronization
ProductionSettingsEvent = {}
ProductionSettingsEvent_mt = Class(ProductionSettingsEvent, Event)
InitEventClass(ProductionSettingsEvent, "ProductionSettingsEvent")

function ProductionSettingsEvent.emptyNew()
    local self = Event.new(ProductionSettingsEvent_mt)
    return self
end

function ProductionSettingsEvent.new(autoManageEnabled)
    local self = ProductionSettingsEvent.emptyNew()
    self.autoManageEnabled = autoManageEnabled
    return self
end

function ProductionSettingsEvent:readStream(streamId, connection)
    self.autoManageEnabled = streamReadBool(streamId)
    self:run(connection)
end

function ProductionSettingsEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.autoManageEnabled)
end

function ProductionSettingsEvent:run(connection)
    if not connection:getIsServer() then
        -- Client receives settings from server
        if ProductionSettings.isChangingSettings then
            ProductionSettings.isChangingSettings = false
            return
        end
        
        ProductionSettings.autoManageEnabled = self.autoManageEnabled
        
        -- Update UI if menu is open
        local menu = g_gui.screenControllers[InGameMenu]
        if menu ~= nil and menu.isOpen then
            for _, control in pairs(ProductionSettings.CONTROLS or {}) do
                if control.id == "autoManageEnabled" then
                    local stateIndex = ProductionSettings.getStateIndex("autoManageEnabled")
                    control:setState(stateIndex)
                end
            end
        end
    else
        -- Server receives settings from client
        ProductionSettings.autoManageEnabled = self.autoManageEnabled
        
        -- Broadcast to all other clients
        ProductionSettings.sendSettingsToClients()
    end
end

-- Auto-manage setting options
ProductionSettings.SETTINGS.autoManageEnabled = {
    ['default'] = 2,  -- Default to OFF (disabled)
    ['values'] = {true, false},
    ['strings'] = {
        g_i18n:getText("production_setting_automanage_on"),
        g_i18n:getText("production_setting_automanage_off")
    }
}

-- Default value (will be loaded from XML)
ProductionSettings.autoManageEnabled = false

-- Send settings to all clients
function ProductionSettings.sendSettingsToClients()
    if g_server ~= nil then
        g_server:broadcastEvent(ProductionSettingsEvent.new(ProductionSettings.autoManageEnabled))
    end
end

-- Send settings to server (from client)
function ProductionSettings.sendSettingsToServer()
    if g_client ~= nil and not g_currentMission:getIsServer() then
        g_client:getServerConnection():sendEvent(ProductionSettingsEvent.new(ProductionSettings.autoManageEnabled))
    end
end

-- Set a value
function ProductionSettings.setValue(id, value)
    ProductionSettings[id] = value
end

-- Get a value
function ProductionSettings.getValue(id)
    return ProductionSettings[id]
end

-- Find the index for a specific value
function ProductionSettings.getStateIndex(id, value)
    local value = value or ProductionSettings.getValue(id)
    local values = ProductionSettings.SETTINGS[id].values
    
    if type(value) == 'boolean' then
        return value and 1 or 2
    end
    
    return ProductionSettings.SETTINGS[id].default
end

-- Controls for settings
ProductionControls = {}

function ProductionControls:onMenuOptionChanged(state, menuOption)
    local id = menuOption.id
    local setting = ProductionSettings.SETTINGS
    local value = setting[id].values[state]
    
    if value ~= nil then
        ProductionSettings.setValue(id, value)
        
        -- Set flag that we're making a change
        ProductionSettings.isChangingSettings = true
        
        -- Save settings
        ProductionSettings.saveSettings()
        
        -- Synchronize based on server role
        if g_currentMission:getIsServer() then
            ProductionSettings.sendSettingsToClients()
        else
            ProductionSettings.sendSettingsToServer()
        end
    end
end

-- Load settings from XML file
function ProductionSettings.loadSettings()
    local xmlFilePath = Utils.getFilename("modSettings/ProductionSettings.xml", getUserProfileAppPath())
    
    if not fileExists(xmlFilePath) then
        return
    end
    
    local xmlFile = loadXMLFile("ProductionXML", xmlFilePath)
    if xmlFile == 0 then
        return
    end
    
    local autoManageEnabled = getXMLBool(xmlFile, "production.settings#autoManageEnabled")
    if autoManageEnabled ~= nil then
        ProductionSettings.setValue("autoManageEnabled", autoManageEnabled)
    end
    
    delete(xmlFile)
end

-- Save settings to XML file
function ProductionSettings.saveSettings()
    local xmlFilePath = Utils.getFilename("modSettings/ProductionSettings.xml", getUserProfileAppPath())
    local xmlFile = nil
    
    createFolder(getUserProfileAppPath() .. "modSettings/")
    
    if fileExists(xmlFilePath) then
        xmlFile = loadXMLFile("ProductionXML", xmlFilePath)
    else
        xmlFile = createXMLFile("ProductionXML", xmlFilePath, "production")
    end
    
    if xmlFile == 0 then
        print("ProductionSettings: Error opening XML file.")
        return
    end
    
    setXMLBool(xmlFile, "production.settings#autoManageEnabled", ProductionSettings.autoManageEnabled)
    
    saveXMLFile(xmlFile)
    delete(xmlFile)
end

-- Helper function for FocusManager
local function updateFocusIds(element)
    if not element then
        return
    end
    element.focusId = FocusManager:serveAutoFocusId()
    for _, child in pairs(element.elements or {}) do
        updateFocusIds(child)
    end
end

-- Inject settings into InGame menu
function ProductionSettings.injectMenu()
    local inGameMenu = g_gui.screenControllers[InGameMenu]
    if not inGameMenu then
        print("ProductionSettings: InGameMenu not found!")
        return
    end
    
    local settingsPage = inGameMenu.pageSettings
    if not settingsPage then
        print("ProductionSettings: Settings-Page not found!")
        return
    end
    
    local layoutToUse = settingsPage.gameSettingsLayout
    if not layoutToUse then
        print("ProductionSettings: gameSettingsLayout not found!")
        return
    end
    
    -- Create section header
    local sectionTitle = nil
    for _, elem in ipairs(layoutToUse.elements) do
        if elem.name == "sectionHeader" then
            sectionTitle = elem:clone(layoutToUse)
            break
        end
    end
    
    if sectionTitle then
        sectionTitle:setText(g_i18n:getText("production_menu_section_title"))
    else
        sectionTitle = TextElement.new()
        sectionTitle:applyProfile("fs25_settingsSectionHeader", true)
        sectionTitle:setText(g_i18n:getText("production_menu_section_title"))
        sectionTitle.name = "sectionHeader"
        layoutToUse:addElement(sectionTitle)
    end
    
    sectionTitle.focusId = FocusManager:serveAutoFocusId()
    table.insert(settingsPage.controlsList, sectionTitle)
    ProductionSettings.CONTROLS["sectionHeader"] = sectionTitle
    
    -- Create auto-manage setting
    local originalBox = settingsPage.multiVolumeVoiceBox
    if not originalBox then
        print("ProductionSettings: multiVolumeVoiceBox not found!")
        return
    end
    
    local autoManageBox = originalBox:clone(layoutToUse)
    autoManageBox.id = "autoManageEnabledBox"
    
    local autoManageOption = autoManageBox.elements[1]
    autoManageOption.id = "autoManageEnabled"
    autoManageOption.target = ProductionControls
    
    autoManageOption:setCallback("onClickCallback", "onMenuOptionChanged")
    autoManageOption:setDisabled(false)
    
    local toolTip = autoManageOption.elements[1]
    toolTip:setText(g_i18n:getText("production_menu_automanage_tooltip"))
    autoManageBox.elements[2]:setText(g_i18n:getText("production_menu_automanage"))
    
    autoManageOption:setTexts(ProductionSettings.SETTINGS.autoManageEnabled.strings)
    
    local autoManageStateIndex = ProductionSettings.getStateIndex("autoManageEnabled")
    autoManageOption:setState(autoManageStateIndex)
    
    ProductionSettings.CONTROLS["autoManageEnabled"] = autoManageOption
    
    updateFocusIds(autoManageBox)
    table.insert(settingsPage.controlsList, autoManageBox)
    
    layoutToUse:invalidateLayout()
end

-- Initialize when game is loaded
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function()
    ProductionSettings.loadSettings()
    ProductionSettings.injectMenu()
end)