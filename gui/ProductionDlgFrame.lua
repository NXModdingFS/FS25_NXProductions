local isDbPrintfOn = false

local function dbPrintf(...)
	if isDbPrintfOn then
    	print(string.format(...))
	end
end

ProductionDlgFrame = {}
local DlgFrame_mt = Class(ProductionDlgFrame, MessageDialog)

function ProductionDlgFrame.new(target, custom_mt)
	dbPrintf("ProductionDlgFrame:new()")
	local self = MessageDialog.new(target, custom_mt or DlgFrame_mt)
    self.productions = {}
	self.displayRows = {}  -- Flattened list for display
	self.showInputs = true
	self.showRecipes = false
	self.showFinances = false
	return self
end

function ProductionDlgFrame:onGuiSetupFinished()
	dbPrintf("ProductionDlgFrame:onGuiSetupFinished()")
	ProductionDlgFrame:superClass().onGuiSetupFinished(self)
	self.overviewTable:setDataSource(self)
	self.overviewTable:setDelegate(self)
end

function ProductionDlgFrame:onCreate()
	dbPrintf("ProductionDlgFrame:onCreate()")
	ProductionDlgFrame:superClass().onCreate(self)
end

function ProductionDlgFrame:onOpen()
	dbPrintf("ProductionDlgFrame:onOpen()")
	ProductionDlgFrame:superClass().onOpen(self)

	self:updateToggleButtonText()
	self:updateRecipeButtonText()
	self:loadProductionData()

	self:setSoundSuppressed(true)
    FocusManager:setFocus(self.overviewTable)
    self:setSoundSuppressed(false)
end

function ProductionDlgFrame:loadProductionData()
	self.productions = {}

	if g_currentMission ~= nil and g_currentMission.productionChainManager ~= nil then
		for _, productionPoint in pairs(g_currentMission.productionChainManager.productionPoints) do
			if productionPoint.ownerFarmId == g_currentMission:getFarmId() then
				local prodData = {
					name = productionPoint:getName(),
					inputFillTypes = {},
					outputFillTypes = {},
					recipes = {},
					monthlyIncome = 0,
					monthlyCosts = 0,
					monthlyRevenue = 0,
					productionPoint = productionPoint
				}

				if productionPoint.storage ~= nil then
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
							local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
							local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
							
							local fillTypeData = {
								name = fillTypeName,
								title = fillType.title,
								liters = fillLevel,
								capacity = capacity,
								fillPercent = (fillLevel / capacity) * 100,
								hudOverlayFilename = fillType.hudOverlayFilename
							}

							local isInput = inputFillTypeIndices[fillTypeIndex] == true
							local isOutput = outputFillTypeIndices[fillTypeIndex] == true

							if isInput then
								table.insert(prodData.inputFillTypes, fillTypeData)
							end
							if isOutput then
								table.insert(prodData.outputFillTypes, fillTypeData)
							end
							
							if not isInput and not isOutput then
								table.insert(prodData.outputFillTypes, fillTypeData)
							end
						end
					end
				end

				table.sort(prodData.inputFillTypes, function(a, b)
					return a.title < b.title
				end)
				table.sort(prodData.outputFillTypes, function(a, b)
					return a.title < b.title
				end)

				if productionPoint.productions ~= nil then
					for _, production in pairs(productionPoint.productions) do
						if production.status ~= nil and production.status ~= ProductionPoint.PROD_STATUS.INACTIVE then
							local recipeName = production.name or "Unknown Recipe"
							local isActive = production.status == ProductionPoint.PROD_STATUS.RUNNING
							
							local inputs = {}
							if production.inputs ~= nil then
								for _, input in pairs(production.inputs) do
									local fillType = g_fillTypeManager:getFillTypeByIndex(input.type)
									if fillType then
										table.insert(inputs, {
											title = fillType.title,
											amount = input.amount or 0,
											hudOverlayFilename = fillType.hudOverlayFilename
										})
									end
								end
							end
							
							local outputs = {}
							if production.outputs ~= nil then
								for _, output in pairs(production.outputs) do
									local fillType = g_fillTypeManager:getFillTypeByIndex(output.type)
									if fillType then
										table.insert(outputs, {
											title = fillType.title,
											amount = output.amount or 0,
											hudOverlayFilename = fillType.hudOverlayFilename
										})
									end
								end
							end
							
							table.insert(prodData.recipes, {
								name = recipeName,
								isActive = isActive,
								inputs = inputs,
								outputs = outputs
							})
						end
					end
				end

				-- Calculate financial data
				prodData.monthlyRevenue = 0
				prodData.monthlyCosts = 0
				
				-- Get days per month from game settings
				local daysPerMonth = 1
				if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.timeScale ~= nil then
					daysPerMonth = g_currentMission.missionInfo.timeScale
				end
				
				-- Calculate revenue from outputs based on their sell prices
				for _, fillType in pairs(prodData.outputFillTypes) do
					local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillType.name)
					if fillTypeIndex ~= nil then
						local pricePerLiter = g_currentMission.economyManager:getPricePerLiter(fillTypeIndex)
						if pricePerLiter ~= nil then
							-- Calculate potential revenue if all outputs were sold
							prodData.monthlyRevenue = prodData.monthlyRevenue + (fillType.liters * pricePerLiter)
						end
					end
				end
				
				-- Calculate costs from active recipes
				if productionPoint.productions ~= nil then
					for _, production in pairs(productionPoint.productions) do
						if production.status == ProductionPoint.PROD_STATUS.RUNNING then
							-- Calculate costs per cycle
							local cyclesCostPerHour = 0
							if production.costsPerActiveHour ~= nil then
								cyclesCostPerHour = production.costsPerActiveHour
							end
							prodData.monthlyCosts = prodData.monthlyCosts + (cyclesCostPerHour * 24 * daysPerMonth)
						end
					end
				end
				
				prodData.monthlyIncome = prodData.monthlyRevenue - prodData.monthlyCosts

				table.insert(self.productions, prodData)
			end
		end
	end

	table.sort(self.productions, function(a, b)
		return a.name < b.name
	end)

	-- Build display rows
	self:buildDisplayRows()
	self.overviewTable:reloadData()
end

function ProductionDlgFrame:buildDisplayRows()
	self.displayRows = {}
	
	for _, prod in ipairs(self.productions) do
		local fillTypes
		
		if self.showFinances then
			-- For finances view, we just show one row per production
			table.insert(self.displayRows, {
				production = prod,
				rowType = "finance",
				fillTypes = {},
				startIndex = 1,
				endIndex = 0
			})
		else
			fillTypes = self.showInputs and prod.inputFillTypes or prod.outputFillTypes
			
			if self.showRecipes then
				fillTypes = prod.recipes
			end
			
			-- Row 1: Items 1-5 (always add)
			table.insert(self.displayRows, {
				production = prod,
				rowType = "row1",
				fillTypes = fillTypes,
				startIndex = 1,
				endIndex = 5
			})
			
			-- Row 2: Items 6-10 (only if more than 5 items)
			if #fillTypes > 5 then
				table.insert(self.displayRows, {
					production = prod,
					rowType = "row2",
					fillTypes = fillTypes,
					startIndex = 6,
					endIndex = 10
				})
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
	dbPrintf("ProductionDlgFrame:onClickFinances()")
	self.showFinances = not self.showFinances
	
	-- Update finances button text
	if self.financesButton ~= nil then
		if self.showFinances then
			self.financesButton:setText(g_i18n:getText("ui_productionDlg_btnHideFinances"))
		else
			self.financesButton:setText(g_i18n:getText("ui_productionDlg_btnShowFinances"))
		end
	end
	
	-- Hide/show other buttons
	if self.toggleButton ~= nil then
		self.toggleButton:setVisible(not self.showFinances)
	end
	if self.recipeButton ~= nil then
		self.recipeButton:setVisible(not self.showFinances)
	end
	
	-- Toggle between header views
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
	dbPrintf("ProductionDlgFrame:onClickRecipes()")
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
	dbPrintf("ProductionDlgFrame:onClickToggle()")
	self.showInputs = not self.showInputs
	self:updateToggleButtonText()
	self:buildDisplayRows()
	self.overviewTable:reloadData()
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

		-- Finance view - ONLY PLACE WITH COLORS
		if row.rowType == "finance" then
			cell:getAttribute("productionName"):setText(prod.name)
			cell:getAttribute("productionName"):setVisible(true)
			
			-- Display financial data in the fill type columns (just values, no labels)
			local revenueText = string.format("$%s/mo", self:formatNumber(math.floor(prod.monthlyRevenue)))
			local costsText = string.format("$%s/mo", self:formatNumber(math.floor(prod.monthlyCosts)))
			local profitText = string.format("$%s/mo", self:formatNumber(math.floor(prod.monthlyIncome)))
			
			cell:getAttribute("fillIcon1"):setVisible(false)
			cell:getAttribute("fillCapacity1"):setText(revenueText)
			cell:getAttribute("fillCapacity1"):setTextColor(1, 1, 1, 1)  -- White for revenue
			cell:getAttribute("fillCapacity1"):setVisible(true)
			
			cell:getAttribute("fillIcon2"):setVisible(false)
			cell:getAttribute("fillCapacity2"):setText(costsText)
			cell:getAttribute("fillCapacity2"):setTextColor(1, 0, 0, 1)  -- Red for costs
			cell:getAttribute("fillCapacity2"):setVisible(true)
			
			cell:getAttribute("fillIcon3"):setVisible(false)
			cell:getAttribute("fillCapacity3"):setText(profitText)
			-- Set color based on profit/loss
			if prod.monthlyIncome >= 0 then
				cell:getAttribute("fillCapacity3"):setTextColor(0, 1, 0, 1)  -- Green for positive profit
			else
				cell:getAttribute("fillCapacity3"):setTextColor(1, 0, 0, 1)  -- Red for negative profit (loss)
			end
			cell:getAttribute("fillCapacity3"):setVisible(true)
			
			-- Hide remaining columns
			for i = 4, 10 do
				cell:getAttribute("fillIcon" .. i):setVisible(false)
				cell:getAttribute("fillCapacity" .. i):setVisible(false)
			end
			
			return
		end

		-- Show production name only on first row
		if row.rowType == "row1" then
			cell:getAttribute("productionName"):setText(prod.name)
			cell:getAttribute("productionName"):setVisible(true)
		else
			cell:getAttribute("productionName"):setText("")
			cell:getAttribute("productionName"):setVisible(false)
		end

		-- Display 5 items per row
		for i = 1, 5 do
			local fillIcon = cell:getAttribute("fillIcon" .. i)
			local fillCapacity = cell:getAttribute("fillCapacity" .. i)
			local dataIndex = row.startIndex + (i - 1)

			if dataIndex <= #fillTypes then
				local fillType = fillTypes[dataIndex]
				
				-- Reset text color to default white for non-finance views
				fillCapacity:setTextColor(1, 1, 1, 1)
				
				if self.showRecipes then
					-- Recipe display
					if fillType.outputs and #fillType.outputs > 0 and fillType.outputs[1].hudOverlayFilename then
						fillIcon:setImageFilename(fillType.outputs[1].hudOverlayFilename)
						fillIcon:setVisible(true)
					else
						fillIcon:setVisible(false)
					end
					
					-- Just show recipe name and status (no inputs/outputs)
					local statusText = fillType.isActive and "(Active)" or "(Inactive)"
					local recipeText = string.format("%s %s", fillType.name, statusText)
					
					fillCapacity:setText(recipeText)
					fillCapacity:setVisible(true)
				else
					-- Fill type display
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
		
		-- Handle bottom row items (6-10) for non-finance views
		if not self.showFinances then
			for i = 6, 10 do
				local fillIcon = cell:getAttribute("fillIcon" .. i)
				local fillCapacity = cell:getAttribute("fillCapacity" .. i)
				local dataIndex = row.startIndex + (i - 1)

				if dataIndex <= #fillTypes and row.rowType == "row2" then
					local fillType = fillTypes[dataIndex]
					
					-- Reset text color to default white
					fillCapacity:setTextColor(1, 1, 1, 1)
					
					if self.showRecipes then
						if fillType.outputs and #fillType.outputs > 0 and fillType.outputs[1].hudOverlayFilename then
							fillIcon:setImageFilename(fillType.outputs[1].hudOverlayFilename)
							fillIcon:setVisible(true)
						else
							fillIcon:setVisible(false)
						end
						
						local statusText = fillType.isActive and "(Active)" or "(Inactive)"
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
	dbPrintf("ProductionDlgFrame:onClose()")
	self.productions = {}
	self.displayRows = {}
	ProductionDlgFrame:superClass().onClose(self)
end

function ProductionDlgFrame:onClickBack(sender)
	dbPrintf("ProductionDlgFrame:onClickBack()")
	self:close()
end