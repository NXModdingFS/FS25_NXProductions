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

function ProductionSettingsEvent.new(settings)
    local self = ProductionSettingsEvent.emptyNew()
    self.autoManageEnabled = settings.autoManageEnabled
    self.hideInactiveProductions = settings.hideInactiveProductions
    self.notifySmartControl = settings.notifySmartControl
    self.notifyLowInputs = settings.notifyLowInputs
    self.notifyHighOutputs = settings.notifyHighOutputs
    self.lowInputThreshold = settings.lowInputThreshold
    self.highOutputThreshold = settings.highOutputThreshold
    self.notificationDuration = settings.notificationDuration
    return self
end

function ProductionSettingsEvent:readStream(streamId, connection)
    self.autoManageEnabled = streamReadBool(streamId)
    self.hideInactiveProductions = streamReadBool(streamId)
    self.notifySmartControl = streamReadBool(streamId)
    self.notifyLowInputs = streamReadBool(streamId)
    self.notifyHighOutputs = streamReadBool(streamId)
    self.lowInputThreshold = streamReadUInt8(streamId)
    self.highOutputThreshold = streamReadUInt8(streamId)
    self.notificationDuration = streamReadUInt16(streamId)
    self:run(connection)
end

function ProductionSettingsEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.autoManageEnabled)
    streamWriteBool(streamId, self.hideInactiveProductions)
    streamWriteBool(streamId, self.notifySmartControl)
    streamWriteBool(streamId, self.notifyLowInputs)
    streamWriteBool(streamId, self.notifyHighOutputs)
    streamWriteUInt8(streamId, self.lowInputThreshold)
    streamWriteUInt8(streamId, self.highOutputThreshold)
    streamWriteUInt16(streamId, self.notificationDuration)
end

function ProductionSettingsEvent:run(connection)
    if not connection:getIsServer() then
        -- Client receives settings from server
        if ProductionSettings.isChangingSettings then
            ProductionSettings.isChangingSettings = false
            return
        end
        
        ProductionSettings.autoManageEnabled = self.autoManageEnabled
        ProductionSettings.hideInactiveProductions = self.hideInactiveProductions
        ProductionSettings.notifySmartControl = self.notifySmartControl
        ProductionSettings.notifyLowInputs = self.notifyLowInputs
        ProductionSettings.notifyHighOutputs = self.notifyHighOutputs
        ProductionSettings.lowInputThreshold = self.lowInputThreshold
        ProductionSettings.highOutputThreshold = self.highOutputThreshold
        ProductionSettings.notificationDuration = self.notificationDuration
        
        -- Update UI if menu is open
        ProductionSettings.updateUIControls()
    else
        -- Server receives settings from client
        ProductionSettings.autoManageEnabled = self.autoManageEnabled
        ProductionSettings.hideInactiveProductions = self.hideInactiveProductions
        ProductionSettings.notifySmartControl = self.notifySmartControl
        ProductionSettings.notifyLowInputs = self.notifyLowInputs
        ProductionSettings.notifyHighOutputs = self.notifyHighOutputs
        ProductionSettings.lowInputThreshold = self.lowInputThreshold
        ProductionSettings.highOutputThreshold = self.highOutputThreshold
        ProductionSettings.notificationDuration = self.notificationDuration
        
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

-- Hide inactive productions setting options
ProductionSettings.SETTINGS.hideInactiveProductions = {
    ['default'] = 2,  -- Default to OFF (show inactive productions)
    ['values'] = {true, false},
    ['strings'] = {
        g_i18n:getText("production_setting_hide_inactive_on"),
        g_i18n:getText("production_setting_hide_inactive_off")
    }
}

-- Notify on smart control actions
ProductionSettings.SETTINGS.notifySmartControl = {
    ['default'] = 2,  -- Default to OFF
    ['values'] = {true, false},
    ['strings'] = {
        g_i18n:getText("production_setting_notify_on"),
        g_i18n:getText("production_setting_notify_off")
    }
}

-- Notify on low input levels
ProductionSettings.SETTINGS.notifyLowInputs = {
    ['default'] = 2,  -- Default to OFF
    ['values'] = {true, false},
    ['strings'] = {
        g_i18n:getText("production_setting_notify_on"),
        g_i18n:getText("production_setting_notify_off")
    }
}

-- Notify on high output levels
ProductionSettings.SETTINGS.notifyHighOutputs = {
    ['default'] = 2,  -- Default to OFF
    ['values'] = {true, false},
    ['strings'] = {
        g_i18n:getText("production_setting_notify_on"),
        g_i18n:getText("production_setting_notify_off")
    }
}

-- Low input threshold percentage
ProductionSettings.SETTINGS.lowInputThreshold = {
    ['default'] = 3,  -- Default to 20%
    ['values'] = {10, 15, 20, 25, 30},
    ['strings'] = {"10%", "15%", "20%", "25%", "30%"}
}

-- High output threshold percentage
ProductionSettings.SETTINGS.highOutputThreshold = {
    ['default'] = 3,  -- Default to 80%
    ['values'] = {70, 75, 80, 85, 90},
    ['strings'] = {"70%", "75%", "80%", "85%", "90%"}
}

-- Notification display duration (in milliseconds)
ProductionSettings.SETTINGS.notificationDuration = {
    ['default'] = 3,  -- Default to 5000ms (5 seconds)
    ['values'] = {3000, 4000, 5000, 6000, 8000, 10000},
    ['strings'] = {
        g_i18n:getText("production_setting_duration_3s"),
        g_i18n:getText("production_setting_duration_4s"),
        g_i18n:getText("production_setting_duration_5s"),
        g_i18n:getText("production_setting_duration_6s"),
        g_i18n:getText("production_setting_duration_8s"),
        g_i18n:getText("production_setting_duration_10s")
    }
}

-- Default values (will be loaded from XML)
ProductionSettings.autoManageEnabled = false
ProductionSettings.hideInactiveProductions = false
ProductionSettings.notifySmartControl = false
ProductionSettings.notifyLowInputs = false
ProductionSettings.notifyHighOutputs = false
ProductionSettings.lowInputThreshold = 20
ProductionSettings.highOutputThreshold = 80
ProductionSettings.notificationDuration = 5000

-- Send settings to all clients
function ProductionSettings.sendSettingsToClients()
    if g_server ~= nil then
        g_server:broadcastEvent(ProductionSettingsEvent.new({
            autoManageEnabled = ProductionSettings.autoManageEnabled,
            hideInactiveProductions = ProductionSettings.hideInactiveProductions,
            notifySmartControl = ProductionSettings.notifySmartControl,
            notifyLowInputs = ProductionSettings.notifyLowInputs,
            notifyHighOutputs = ProductionSettings.notifyHighOutputs,
            lowInputThreshold = ProductionSettings.lowInputThreshold,
            highOutputThreshold = ProductionSettings.highOutputThreshold,
            notificationDuration = ProductionSettings.notificationDuration
        }))
    end
end

-- Send settings to server (from client)
function ProductionSettings.sendSettingsToServer()
    if g_client ~= nil and not g_currentMission:getIsServer() then
        g_client:getServerConnection():sendEvent(ProductionSettingsEvent.new({
            autoManageEnabled = ProductionSettings.autoManageEnabled,
            hideInactiveProductions = ProductionSettings.hideInactiveProductions,
            notifySmartControl = ProductionSettings.notifySmartControl,
            notifyLowInputs = ProductionSettings.notifyLowInputs,
            notifyHighOutputs = ProductionSettings.notifyHighOutputs,
            lowInputThreshold = ProductionSettings.lowInputThreshold,
            highOutputThreshold = ProductionSettings.highOutputThreshold,
            notificationDuration = ProductionSettings.notificationDuration
        }))
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
    
    -- Handle numeric values (thresholds, durations)
    if type(value) == 'number' then
        for i, v in ipairs(values) do
            if v == value then
                return i
            end
        end
    end
    
    return ProductionSettings.SETTINGS[id].default
end

-- Update UI controls when settings change
function ProductionSettings.updateUIControls()
    local menu = g_gui.screenControllers[InGameMenu]
    if menu ~= nil and menu.isOpen then
        for _, control in pairs(ProductionSettings.CONTROLS or {}) do
            if control.id and ProductionSettings.SETTINGS[control.id] then
                local stateIndex = ProductionSettings.getStateIndex(control.id)
                control:setState(stateIndex)
            end
        end
    end
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
    
    local hideInactiveProductions = getXMLBool(xmlFile, "production.settings#hideInactiveProductions")
    if hideInactiveProductions ~= nil then
        ProductionSettings.setValue("hideInactiveProductions", hideInactiveProductions)
    end
    
    local notifySmartControl = getXMLBool(xmlFile, "production.settings#notifySmartControl")
    if notifySmartControl ~= nil then
        ProductionSettings.setValue("notifySmartControl", notifySmartControl)
    end
    
    local notifyLowInputs = getXMLBool(xmlFile, "production.settings#notifyLowInputs")
    if notifyLowInputs ~= nil then
        ProductionSettings.setValue("notifyLowInputs", notifyLowInputs)
    end
    
    local notifyHighOutputs = getXMLBool(xmlFile, "production.settings#notifyHighOutputs")
    if notifyHighOutputs ~= nil then
        ProductionSettings.setValue("notifyHighOutputs", notifyHighOutputs)
    end
    
    local lowInputThreshold = getXMLInt(xmlFile, "production.settings#lowInputThreshold")
    if lowInputThreshold ~= nil then
        ProductionSettings.setValue("lowInputThreshold", lowInputThreshold)
    end
    
    local highOutputThreshold = getXMLInt(xmlFile, "production.settings#highOutputThreshold")
    if highOutputThreshold ~= nil then
        ProductionSettings.setValue("highOutputThreshold", highOutputThreshold)
    end
    
    local notificationDuration = getXMLInt(xmlFile, "production.settings#notificationDuration")
    if notificationDuration ~= nil then
        ProductionSettings.setValue("notificationDuration", notificationDuration)
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
    setXMLBool(xmlFile, "production.settings#hideInactiveProductions", ProductionSettings.hideInactiveProductions)
    setXMLBool(xmlFile, "production.settings#notifySmartControl", ProductionSettings.notifySmartControl)
    setXMLBool(xmlFile, "production.settings#notifyLowInputs", ProductionSettings.notifyLowInputs)
    setXMLBool(xmlFile, "production.settings#notifyHighOutputs", ProductionSettings.notifyHighOutputs)
    setXMLInt(xmlFile, "production.settings#lowInputThreshold", ProductionSettings.lowInputThreshold)
    setXMLInt(xmlFile, "production.settings#highOutputThreshold", ProductionSettings.highOutputThreshold)
    setXMLInt(xmlFile, "production.settings#notificationDuration", ProductionSettings.notificationDuration)
    
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
    
    local originalBox = settingsPage.multiVolumeVoiceBox
    if not originalBox then
        print("ProductionSettings: multiVolumeVoiceBox not found!")
        return
    end
    
    -- Helper function to create a setting option
    local function createSettingOption(id, titleKey, tooltipKey)
        local box = originalBox:clone(layoutToUse)
        box.id = id .. "Box"
        
        local option = box.elements[1]
        option.id = id
        option.target = ProductionControls
        
        option:setCallback("onClickCallback", "onMenuOptionChanged")
        option:setDisabled(false)
        
        local toolTip = option.elements[1]
        toolTip:setText(g_i18n:getText(tooltipKey))
        box.elements[2]:setText(g_i18n:getText(titleKey))
        
        option:setTexts(ProductionSettings.SETTINGS[id].strings)
        
        local stateIndex = ProductionSettings.getStateIndex(id)
        option:setState(stateIndex)
        
        ProductionSettings.CONTROLS[id] = option
        
        updateFocusIds(box)
        table.insert(settingsPage.controlsList, box)
    end
    
    -- Create all settings
    createSettingOption("autoManageEnabled", "production_menu_automanage", "production_menu_automanage_tooltip")
    createSettingOption("hideInactiveProductions", "production_menu_hide_inactive", "production_menu_hide_inactive_tooltip")
    createSettingOption("notifySmartControl", "production_menu_notify_smart_control", "production_menu_notify_smart_control_tooltip")
    createSettingOption("notifyLowInputs", "production_menu_notify_low_inputs", "production_menu_notify_low_inputs_tooltip")
    createSettingOption("notifyHighOutputs", "production_menu_notify_high_outputs", "production_menu_notify_high_outputs_tooltip")
    createSettingOption("lowInputThreshold", "production_menu_low_input_threshold", "production_menu_low_input_threshold_tooltip")
    createSettingOption("highOutputThreshold", "production_menu_high_output_threshold", "production_menu_high_output_threshold_tooltip")
    createSettingOption("notificationDuration", "production_menu_notification_duration", "production_menu_notification_duration_tooltip")
    
    layoutToUse:invalidateLayout()
end

-- Initialize when game is loaded
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function()
    ProductionSettings.loadSettings()
    ProductionSettings.injectMenu()
end)