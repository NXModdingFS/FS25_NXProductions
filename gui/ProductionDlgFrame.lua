ProductionDlgFrame = {}
local DlgFrame_mt = Class(ProductionDlgFrame, MessageDialog)

function ProductionDlgFrame.new(target, custom_mt)
	local self = MessageDialog.new(target, custom_mt or DlgFrame_mt)
    self.productions = {}
	self.displayRows = {}
	self.showInputs = true
	self.showRecipes = false
	self.showFinances = false
	return self
end

function ProductionDlgFrame:onGuiSetupFinished()
	ProductionDlgFrame:superClass().onGuiSetupFinished(self)
	self.overviewTable:setDataSource(self)
	self.overviewTable:setDelegate(self)
end

function ProductionDlgFrame:onCreate()
	ProductionDlgFrame:superClass().onCreate(self)
end

function ProductionDlgFrame:onOpen()
	ProductionDlgFrame:superClass().onOpen(self)

	self:updateToggleButtonText()
	self:updateRecipeButtonText()
	self:loadProductionData()

	if self.toggleButton ~= nil then
		self.toggleButton:setInputAction(InputAction.MENU_EXTRA_1)
	end
	
	if self.recipeButton ~= nil then
		self.recipeButton:setInputAction(InputAction.MENU_EXTRA_2)
	end
	
	if self.financesButton ~= nil then
		self.financesButton:setInputAction(InputAction.MENU_PAGE_PREV)
	end
	
	if self.exportButton ~= nil then
		self.exportButton:setInputAction(InputAction.MENU_PAGE_NEXT)
	end

	self:setSoundSuppressed(true)
    FocusManager:setFocus(self.overviewTable)
    self:setSoundSuppressed(false)
end

function ProductionDlgFrame:onClickOk()
	return false
end

function ProductionDlgFrame:inputEvent(action, value, eventUsed)

	if eventUsed then
		return eventUsed
	end
	
	if value == 0 then
		return eventUsed
	end
	
	if action == InputAction.MENU_EXTRA_1 then

		self:onClickToggle()
		return true
	elseif action == InputAction.MENU_EXTRA_2 then

		self:onClickRecipes()
		return true
	elseif action == InputAction.MENU_PAGE_PREV then

		self:onClickFinances()
		return true
	elseif action == InputAction.MENU_PAGE_NEXT then

		self:onClickExportCSV()
		return true
	end

	return ProductionDlgFrame:superClass().inputEvent(self, action, value, eventUsed)
end

function ProductionDlgFrame:loadProductionData()
	self.productions = {}

	if g_currentMission ~= nil and g_currentMission.productionChainManager ~= nil then
		for _, productionPoint in pairs(g_currentMission.productionChainManager.productionPoints) do
			if productionPoint.ownerFarmId == g_currentMission:getFarmId() then

				local hasActiveProduction = true
				if ProductionSettings and ProductionSettings.hideInactiveProductions then
					hasActiveProduction = false
					if productionPoint.productions ~= nil then
						for _, production in pairs(productionPoint.productions) do
							if production.status ~= ProductionPoint.PROD_STATUS.INACTIVE then
								hasActiveProduction = true
								break
							end
						end
					end
				end

				if hasActiveProduction then
		
					local modeIndicator = ""
					if productionPoint.sharedThroughputCapacity ~= nil then
			
						modeIndicator = productionPoint.sharedThroughputCapacity and " (S)" or " (P)"
					end
					
					local prodData = {
						name = productionPoint:getName() .. modeIndicator,
						inputFillTypes = {},
						outputFillTypes = {},
						recipes = {},
						monthlyIncome = 0,
						monthlyCosts = 0,
						monthlyRevenue = 0,
						dailyUpkeep = 0,
						productionPoint = productionPoint
					}

					if productionPoint.storage ~= nil and productionPoint.storage.fillTypes ~= nil then
						local inputFillTypeIndices = {}
						local outputFillTypeIndices = {}

						if productionPoint.productions ~= nil then
							for _, production in pairs(productionPoint.productions) do
								if production.inputs ~= nil then
									for _, input in pairs(production.inputs) do
										inputFillTypeIndices[input.type] = true
									end
								end
								if production.outputs ~= nil then
									for _, output in pairs(production.outputs) do
										outputFillTypeIndices[output.type] = true
									end
								end
							end
						end

						for fillTypeIndex, _ in pairs(productionPoint.storage.fillTypes) do
							local fillLevel = productionPoint.storage:getFillLevel(fillTypeIndex)
							local capacity = productionPoint.storage:getCapacity(fillTypeIndex)

							if capacity > 0 then
								local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
								if fillType ~= nil then
									local data = {
										name = fillType.name,
										title = fillType.title,
										liters = fillLevel,
										capacity = capacity,
										fillPercent = (fillLevel / capacity) * 100,
										hudOverlayFilename = fillType.hudOverlayFilename
									}

									if inputFillTypeIndices[fillTypeIndex] then
										table.insert(prodData.inputFillTypes, data)
									else
										table.insert(prodData.outputFillTypes, data)
									end
								end
							end
						end
					end

					table.sort(prodData.inputFillTypes, function(a, b) return a.title < b.title end)
					table.sort(prodData.outputFillTypes, function(a, b) return a.title < b.title end)

			
					if productionPoint.productions ~= nil then
						for _, production in pairs(productionPoint.productions) do
				
							local cleanName = production.name or "Unknown Recipe"
							cleanName = cleanName:gsub("%s*%b()%s*", "")  
							
							table.insert(prodData.recipes, {
								name = cleanName,
								isActive = production.status == ProductionPoint.PROD_STATUS.RUNNING,
								status = production.status,
								inputs = production.inputs or {},
								outputs = production.outputs or {}
							})
						end
					end

					local daysPerMonth = g_currentMission.missionInfo.timeScale or 1

					for _, ft in pairs(prodData.outputFillTypes) do
						local idx = g_fillTypeManager:getFillTypeIndexByName(ft.name)
						if idx then
							local price = g_currentMission.economyManager:getPricePerLiter(idx)
							if price then
								prodData.monthlyRevenue = prodData.monthlyRevenue + (ft.liters * price)
							end
						end
					end

					if productionPoint.owningPlaceable then
						local upkeep = productionPoint.owningPlaceable:getDailyUpkeep()
						if upkeep and upkeep > 0 then
							prodData.dailyUpkeep = upkeep
							prodData.monthlyCosts = prodData.monthlyCosts + (upkeep * daysPerMonth)
						end
					end

					if productionPoint.costsPerActiveHour ~= nil then
						prodData.monthlyCosts = prodData.monthlyCosts +
							(productionPoint.costsPerActiveHour * 24 * daysPerMonth)
					end

					if productionPoint.productions ~= nil then
						for _, production in pairs(productionPoint.productions) do
							if production.status == ProductionPoint.PROD_STATUS.RUNNING then
								if production.costsPerActiveHour ~= nil then
									prodData.monthlyCosts = prodData.monthlyCosts +
										(production.costsPerActiveHour * 24 * daysPerMonth)
								end
							end
						end
					end

					prodData.monthlyIncome = prodData.monthlyRevenue - prodData.monthlyCosts
					table.insert(self.productions, prodData)
				end
			end
		end
	end

	table.sort(self.productions, function(a, b) return a.name < b.name end)
	self:buildDisplayRows()
	self.overviewTable:reloadData()
end


function ProductionDlgFrame:buildDisplayRows()
    self.displayRows = {}

    for _, prod in ipairs(self.productions) do
        if self.showFinances then
            table.insert(self.displayRows, {
                production = prod,
                rowType = "finance",
                fillTypes = {},
                startIndex = 1,
                endIndex = 0
            })
        else
            local fillTypes = self.showInputs and prod.inputFillTypes or prod.outputFillTypes
            if self.showRecipes then
                fillTypes = prod.recipes
            end

            local index = 1
            while index <= #fillTypes do
                local endIndex = math.min(index + 4, #fillTypes)

                table.insert(self.displayRows, {
                    production = prod,
                    rowType = index == 1 and "row1" or "rowN",
                    fillTypes = fillTypes,
                    startIndex = index,
                    endIndex = endIndex
                })

                index = endIndex + 1
            end
        end
    end
end


function ProductionDlgFrame:updateToggleButtonText()
	if self.toggleButton ~= nil then
		if self.showInputs then
			self.toggleButton:setText(g_i18n:getText("ui_productionDlg_btnShowOutputs"))
		else
			self.toggleButton:setText(g_i18n:getText("ui_productionDlg_btnShowInputs"))
		end
	end
	
	if self.fillTypeHeader ~= nil then
		if self.showInputs then
			self.fillTypeHeader:setText(g_i18n:getText("ui_productionDlg_hbInputs"))
		else
			self.fillTypeHeader:setText(g_i18n:getText("ui_productionDlg_hbOutputs"))
		end
	end
end

function ProductionDlgFrame:updateRecipeButtonText()
	if self.recipeButton ~= nil then
		if self.showRecipes then
			self.recipeButton:setText(g_i18n:getText("ui_productionDlg_btnShowFillTypes"))
		else
			self.recipeButton:setText(g_i18n:getText("ui_productionDlg_btnShowRecipes"))
		end
	end
end

function ProductionDlgFrame:onClickFinances()
	self.showFinances = not self.showFinances
	
	if self.financesButton ~= nil then
		if self.showFinances then
			self.financesButton:setText(g_i18n:getText("ui_productionDlg_btnHideFinances"))
		else
			self.financesButton:setText(g_i18n:getText("ui_productionDlg_btnShowFinances"))
		end
	end
	
	if self.toggleButton ~= nil then
		self.toggleButton:setVisible(not self.showFinances)
	end
	if self.recipeButton ~= nil then
		self.recipeButton:setVisible(not self.showFinances)
	end
	
	if self.tableHeaderBox ~= nil then
		self.tableHeaderBox:setVisible(not self.showFinances)
	end
	if self.financeHeaderBox ~= nil then
		self.financeHeaderBox:setVisible(self.showFinances)
	end
	
	self:buildDisplayRows()
	self.overviewTable:reloadData()
end

function ProductionDlgFrame:onClickRecipes()
	self.showRecipes = not self.showRecipes
	self:updateRecipeButtonText()
	
	if self.toggleButton ~= nil then
		self.toggleButton:setVisible(not self.showRecipes)
	end
	
	if self.fillTypeHeader ~= nil then
		if self.showRecipes then
			self.fillTypeHeader:setText(g_i18n:getText("ui_productionDlg_hbRecipes"))
		else
			self:updateToggleButtonText()
		end
	end
	
	self:buildDisplayRows()
	self.overviewTable:reloadData()
end

function ProductionDlgFrame:onClickToggle()
	self.showInputs = not self.showInputs
	self:updateToggleButtonText()
	self:buildDisplayRows()
	self.overviewTable:reloadData()
end

function ProductionDlgFrame:onClickExportCSV()

	if #self.productions == 0 then
		InfoDialog.show("No production data to export")
		return
	end
	
	local env = g_currentMission.environment
	local savegameName = g_currentMission.missionInfo.savegameDirectory or "Unknown"
	
	savegameName = savegameName:match("([^/\\]+)$") or savegameName
	
	savegameName = savegameName:gsub("savegame(%d)$", "savegame0%1")
	
	local year = env.currentYear or 1
	
	local period = env.currentPeriod or 1
	local monthMap = {3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2}
	local monthNumber = monthMap[period] or 1
	
	local dayNumber = env.currentDayInPeriod or 1
	
	local filename = string.format(
		"ProductionExport_%s_Y%02d_M%02d_D%02d.csv",
		savegameName,
		year,
		monthNumber,
		dayNumber
	)

	local modsDir = getUserProfileAppPath() .. "modSettings"
	local exportDir = modsDir .. "/FS25_NXProductionsDump"

	createFolder(exportDir)
	
	local filepath = exportDir .. "/" .. filename
	
	local testFile = io.open(filepath, "r")
	if testFile then
		testFile:close()
		local file = io.open(filepath, "w")
		if file == nil then
			InfoDialog.show("Export Failed: File is open in another program")
			return
		end
		file:close()
	end
	
	local file = io.open(filepath, "w")
	if file == nil then
		InfoDialog.show("Export Failed")
		return
	end

	local currencySymbol = g_i18n:getCurrencySymbol(true)
	
	file:write("\239\187\191")

	file:write(string.format('"Production Name","Status","Type","Fill Type","Amount (L)","Capacity (L)","Fill %%","Daily Upkeep (%s)","Monthly Revenue (%s)","Monthly Costs (%s)","Net Profit (%s)"\n', currencySymbol, currencySymbol, currencySymbol, currencySymbol))

	for _, prod in ipairs(self.productions) do

		local activeCount = 0
		local totalCount = #prod.recipes
		for _, recipe in ipairs(prod.recipes) do
			if recipe.status == ProductionPoint.PROD_STATUS.RUNNING then
				activeCount = activeCount + 1
			end
		end
		local statusText = string.format("Active %d/%d", activeCount, totalCount)

		for _, fillType in ipairs(prod.inputFillTypes) do
			file:write(string.format('"%s","%s","Input","%s","%d","%d","%.2f","","","",""\n',
				prod.name or "",
				statusText,
				fillType.title or "",
				math.floor(fillType.liters),
				math.floor(fillType.capacity),
				fillType.fillPercent
			))
		end

		for _, fillType in ipairs(prod.outputFillTypes) do
			file:write(string.format('"%s","%s","Output","%s","%d","%d","%.2f","","","",""\n',
				prod.name or "",
				statusText,
				fillType.title or "",
				math.floor(fillType.liters),
				math.floor(fillType.capacity),
				fillType.fillPercent
			))
		end

		file:write(string.format('"%s","%s","Finance Summary","","","","","%.2f","%d","%d","%d"\n',
			prod.name or "",
			statusText,
			prod.dailyUpkeep,
			math.floor(prod.monthlyRevenue),
			math.floor(prod.monthlyCosts),
			math.floor(prod.monthlyIncome)
		))

		file:write("\n")
	end

	file:close()
	
	InfoDialog.show(string.format("Export Successful!\n\nExported to:\n%s", filename))
end

function ProductionDlgFrame:getNumberOfItemsInSection(list, section)
	if list == self.overviewTable then
		return #self.displayRows
	else
		return 0
	end
end

function ProductionDlgFrame:populateCellForItemInSection(list, section, index, cell)
    if list == self.overviewTable then
		local row = self.displayRows[index]
		
		if row == nil then
			return
		end

		local prod = row.production
		local fillTypes = row.fillTypes

		local currencySymbol = g_i18n:getCurrencySymbol(true)

		if row.rowType == "finance" then
			cell:getAttribute("productionName"):setText(prod.name)
			cell:getAttribute("productionName"):setVisible(true)
			
			local revenueText = string.format("%s%s/mo", currencySymbol, self:formatNumber(math.floor(prod.monthlyRevenue)))
			local costsText = string.format("%s%s/mo", currencySymbol, self:formatNumber(math.floor(prod.monthlyCosts)))
			local profitText = string.format("%s%s/mo", currencySymbol, self:formatNumber(math.floor(prod.monthlyIncome)))
			
			cell:getAttribute("fillIcon1"):setVisible(false)
			cell:getAttribute("fillCapacity1"):setText(revenueText)
			cell:getAttribute("fillCapacity1"):setTextColor(1, 1, 1, 1)  
			cell:getAttribute("fillCapacity1"):setVisible(true)
			
			cell:getAttribute("fillIcon2"):setVisible(false)
			cell:getAttribute("fillCapacity2"):setText(costsText)
			cell:getAttribute("fillCapacity2"):setTextColor(1, 0, 0, 1)  
			cell:getAttribute("fillCapacity2"):setVisible(true)
			
			cell:getAttribute("fillIcon3"):setVisible(false)
			cell:getAttribute("fillCapacity3"):setText(profitText)
			if prod.monthlyIncome >= 0 then
				cell:getAttribute("fillCapacity3"):setTextColor(0, 1, 0, 1)  
			else
				cell:getAttribute("fillCapacity3"):setTextColor(1, 0, 0, 1)  
			end
			cell:getAttribute("fillCapacity3"):setVisible(true)
			
			for i = 4, 10 do
				cell:getAttribute("fillIcon" .. i):setVisible(false)
				cell:getAttribute("fillCapacity" .. i):setVisible(false)
			end
			
			return
		end


		if row.rowType == "row1" then
			cell:getAttribute("productionName"):setText(prod.name)
			cell:getAttribute("productionName"):setVisible(true)
		else
			cell:getAttribute("productionName"):setText("")
			cell:getAttribute("productionName"):setVisible(false)
		end


		for i = 1, 5 do
			local fillIcon = cell:getAttribute("fillIcon" .. i)
			local fillCapacity = cell:getAttribute("fillCapacity" .. i)
			local dataIndex = row.startIndex + (i - 1)

			if dataIndex <= #fillTypes then
				local fillType = fillTypes[dataIndex]
				
				fillCapacity:setTextColor(1, 1, 1, 1)
				
				if self.showRecipes then
					local iconFilename = nil
					if fillType.outputs and #fillType.outputs > 0 then
						local outputType = fillType.outputs[1].type
						if outputType then
							local outputFillType = g_fillTypeManager:getFillTypeByIndex(outputType)
							if outputFillType then
								iconFilename = outputFillType.hudOverlayFilename
							end
						end
					end
					
					if iconFilename and iconFilename ~= "" then
						fillIcon:setImageFilename(iconFilename)
						fillIcon:setVisible(true)
					else
						fillIcon:setVisible(false)
					end
					
					local statusText
					if fillType.status == ProductionPoint.PROD_STATUS.RUNNING then
						statusText = "(Active)"
					else
						statusText = "(Inactive)"
					end
					
					local recipeText = string.format("%s %s", fillType.name, statusText)
					fillCapacity:setText(recipeText)
					fillCapacity:setVisible(true)
				else
				
					if fillType.hudOverlayFilename ~= nil and fillType.hudOverlayFilename ~= "" then
						fillIcon:setImageFilename(fillType.hudOverlayFilename)
						fillIcon:setVisible(true)
					else
						fillIcon:setVisible(false)
					end

					local capacityText = string.format("%s / %s L", 
						self:formatNumber(math.floor(fillType.liters)),
						self:formatNumber(math.floor(fillType.capacity)))
					fillCapacity:setText(capacityText)
					fillCapacity:setVisible(true)
				end
			else
				fillIcon:setVisible(false)
				fillCapacity:setVisible(false)
			end
		end
		
		if not self.showFinances then
			for i = 6, 10 do
				local fillIcon = cell:getAttribute("fillIcon" .. i)
				local fillCapacity = cell:getAttribute("fillCapacity" .. i)
				local dataIndex = row.startIndex + (i - 1)

				if dataIndex <= #fillTypes and row.rowType == "row2" then
					local fillType = fillTypes[dataIndex]
		
					fillCapacity:setTextColor(1, 1, 1, 1)
					
					if self.showRecipes then
					
						local iconFilename = nil
						if fillType.outputs and #fillType.outputs > 0 then
							local outputType = fillType.outputs[1].type
							if outputType then
								local outputFillType = g_fillTypeManager:getFillTypeByIndex(outputType)
								if outputFillType then
									iconFilename = outputFillType.hudOverlayFilename
								end
							end
						end
						
						if iconFilename and iconFilename ~= "" then
							fillIcon:setImageFilename(iconFilename)
							fillIcon:setVisible(true)
						else
							fillIcon:setVisible(false)
						end
						
						local statusText
						if fillType.status == ProductionPoint.PROD_STATUS.RUNNING then
							statusText = "(Active)"
						else
							statusText = "(Inactive)"
						end
						
						local recipeText = string.format("%s %s", fillType.name, statusText)
						fillCapacity:setText(recipeText)
						fillCapacity:setVisible(true)
					else
						if fillType.hudOverlayFilename ~= nil and fillType.hudOverlayFilename ~= "" then
							fillIcon:setImageFilename(fillType.hudOverlayFilename)
							fillIcon:setVisible(true)
						else
							fillIcon:setVisible(false)
						end

						local capacityText = string.format("%s / %s L", 
							self:formatNumber(math.floor(fillType.liters)),
							self:formatNumber(math.floor(fillType.capacity)))
						fillCapacity:setText(capacityText)
						fillCapacity:setVisible(true)
					end
				else
					fillIcon:setVisible(false)
					fillCapacity:setVisible(false)
				end
			end
		end
    end
end

function ProductionDlgFrame:formatNumber(num)
    local formatted = tostring(num)
    local k
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

function ProductionDlgFrame:onClose()
	self.productions = {}
	self.displayRows = {}
	ProductionDlgFrame:superClass().onClose(self)
end

function ProductionDlgFrame:onClickBack(sender)
	self:close()
end
