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
	self.showInputs = true  -- Toggle state: true = inputs, false = outputs
	self.showRecipes = false  -- Toggle state: false = fill types, true = recipes
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

	-- Update button text based on current mode
	self:updateToggleButtonText()
	self:updateRecipeButtonText()

	-- Fill data structure with production data
	self:loadProductionData()

	self:setSoundSuppressed(true)
    FocusManager:setFocus(self.overviewTable)
    self:setSoundSuppressed(false)
end

function ProductionDlgFrame:loadProductionData()
	self.productions = {}
	local totalMonthlyIncome = 0

	if g_currentMission ~= nil and g_currentMission.productionChainManager ~= nil then
		for _, productionPoint in pairs(g_currentMission.productionChainManager.productionPoints) do
			if productionPoint.ownerFarmId == g_currentMission:getFarmId() then
				local prodData = {
					name = productionPoint:getName(),
					inputFillTypes = {},
					outputFillTypes = {},
					recipes = {},
					monthlyIncome = 0,
					productionPoint = productionPoint
				}

				-- Get fill levels from storage
				if productionPoint.storage ~= nil then
					-- First, build sets of input and output fill type indices from productions
					local inputFillTypeIndices = {}
					local outputFillTypeIndices = {}
					
					if productionPoint.productions ~= nil then
						for _, production in pairs(productionPoint.productions) do
							-- Check inputs
							if production.inputs ~= nil then
								for _, input in pairs(production.inputs) do
									inputFillTypeIndices[input.type] = true
								end
							end
							-- Check outputs
							if production.outputs ~= nil then
								for _, output in pairs(production.outputs) do
									outputFillTypeIndices[output.type] = true
								end
							end
						end
					end
					
					-- Now categorize all storage fill types
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

							-- Determine if this is an input or output based on production recipes
							local isInput = inputFillTypeIndices[fillTypeIndex] == true
							local isOutput = outputFillTypeIndices[fillTypeIndex] == true

							-- Add to appropriate list (some fill types might be both input and output)
							if isInput then
								table.insert(prodData.inputFillTypes, fillTypeData)
							end
							if isOutput then
								table.insert(prodData.outputFillTypes, fillTypeData)
							end
							
							-- If neither input nor output was detected, assume it's an output (fallback)
							if not isInput and not isOutput then
								table.insert(prodData.outputFillTypes, fillTypeData)
							end
						end
					end
				end

				-- Sort fill types by name
				table.sort(prodData.inputFillTypes, function(a, b)
					return a.title < b.title
				end)
				table.sort(prodData.outputFillTypes, function(a, b)
					return a.title < b.title
				end)

				-- Collect active recipes
				if productionPoint.productions ~= nil then
					for _, production in pairs(productionPoint.productions) do
						if production.status ~= nil and production.status ~= ProductionPoint.PROD_STATUS.INACTIVE then
							local recipeName = production.name or "Unknown Recipe"
							local isActive = production.status == ProductionPoint.PROD_STATUS.RUNNING
							
							-- Get inputs for this recipe
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
							
							-- Get outputs for this recipe
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

				-- Calculate monthly income (approximate based on last hour's profit * 24 * 30)
				if productionPoint.lastHourRevenue ~= nil and productionPoint.lastHourCosts ~= nil then
					local hourlyProfit = productionPoint.lastHourRevenue - productionPoint.lastHourCosts
					prodData.monthlyIncome = hourlyProfit * 24 * 30
					totalMonthlyIncome = totalMonthlyIncome + prodData.monthlyIncome
				end

				table.insert(self.productions, prodData)
			end
		end
	end

	-- Sort productions by name
	table.sort(self.productions, function(a, b)
		return a.name < b.name
	end)

	-- Update total income text
	if self.totalIncomeText ~= nil then
		self.totalIncomeText:setText(string.format("$%s", self:formatNumber(math.floor(totalMonthlyIncome))))
	end

	-- Reload table data
	self.overviewTable:reloadData()
end

function ProductionDlgFrame:updateToggleButtonText()
	if self.toggleButton ~= nil then
		if self.showInputs then
			self.toggleButton:setText(g_i18n:getText("ui_productionDlg_btnShowOutputs"))
		else
			self.toggleButton:setText(g_i18n:getText("ui_productionDlg_btnShowInputs"))
		end
	end
	
	-- Update header text
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

function ProductionDlgFrame:onClickRecipes()
	dbPrintf("ProductionDlgFrame:onClickRecipes()")
	self.showRecipes = not self.showRecipes
	self:updateRecipeButtonText()
	
	-- Update visibility of input/output toggle button
	if self.toggleButton ~= nil then
		self.toggleButton:setVisible(not self.showRecipes)
	end
	
	-- Update header visibility
	if self.fillTypeHeader ~= nil then
		if self.showRecipes then
			self.fillTypeHeader:setText(g_i18n:getText("ui_productionDlg_hbRecipes"))
		else
			self:updateToggleButtonText()  -- This updates the header back
		end
	end
	
	self.overviewTable:reloadData()
end

function ProductionDlgFrame:onClickToggle()
	dbPrintf("ProductionDlgFrame:onClickToggle()")
	self.showInputs = not self.showInputs
	self:updateToggleButtonText()
	self.overviewTable:reloadData()
end

function ProductionDlgFrame:getNumberOfItemsInSection(list, section)
    if list == self.overviewTable then
        return #self.productions
    else
        return 0
    end
end

function ProductionDlgFrame:populateCellForItemInSection(list, section, index, cell)
    if list == self.overviewTable then
		local prod = self.productions[index]
		
		if prod == nil then
			return
		end

		-- Show production name
		cell:getAttribute("productionName"):setText(prod.name)
		cell:getAttribute("productionName"):setVisible(true)

		if self.showRecipes then
			-- Show recipes view
			for i = 1, 5 do
				local fillIcon = cell:getAttribute("fillIcon" .. i)
				local fillCapacity = cell:getAttribute("fillCapacity" .. i)

				if i <= #prod.recipes then
					local recipe = prod.recipes[i]
					
					-- Show recipe icon if available (use first output's icon)
					if recipe.outputs and #recipe.outputs > 0 and recipe.outputs[1].hudOverlayFilename then
						fillIcon:setImageFilename(recipe.outputs[1].hudOverlayFilename)
						fillIcon:setVisible(true)
					else
						fillIcon:setVisible(false)
					end
					
					-- Build recipe text
					local statusText = recipe.isActive and "(Active)" or "(Inactive)"
					local recipeText = string.format("%s %s", recipe.name, statusText)
					
					-- Add inputs
					if #recipe.inputs > 0 then
						recipeText = recipeText .. "\n"
						for j, input in ipairs(recipe.inputs) do
							if j > 1 then recipeText = recipeText .. ", " end
							recipeText = recipeText .. string.format("%s", input.title)
						end
					end
					
					-- Add outputs
					if #recipe.outputs > 0 then
						recipeText = recipeText .. " → "
						for j, output in ipairs(recipe.outputs) do
							if j > 1 then recipeText = recipeText .. ", " end
							recipeText = recipeText .. string.format("%s", output.title)
						end
					end
					
					fillCapacity:setText(recipeText)
					fillCapacity:setVisible(true)
				else
					-- Hide unused slots
					fillIcon:setVisible(false)
					fillCapacity:setVisible(false)
				end
			end
		else
			-- Show fill types view (original logic)
			-- Choose which fill types to display based on toggle
			local fillTypes = self.showInputs and prod.inputFillTypes or prod.outputFillTypes

			-- Display fill types horizontally (up to 5 fill types)
			for i = 1, 5 do
				local fillIcon = cell:getAttribute("fillIcon" .. i)
				local fillCapacity = cell:getAttribute("fillCapacity" .. i)

				if i <= #fillTypes then
					local fillType = fillTypes[i]
					
					-- Set fill type icon
					if fillType.hudOverlayFilename ~= nil and fillType.hudOverlayFilename ~= "" then
						fillIcon:setImageFilename(fillType.hudOverlayFilename)
						fillIcon:setVisible(true)
					else
						fillIcon:setVisible(false)
					end

					-- Set capacity info (no fill type name, just data)
					local capacityText = string.format("%s / %s L (%.1f%%)", 
						self:formatNumber(math.floor(fillType.liters)),
						self:formatNumber(math.floor(fillType.capacity)),
						fillType.fillPercent)
					fillCapacity:setText(capacityText)
					fillCapacity:setVisible(true)
				else
					-- Hide unused fill type slots
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
	ProductionDlgFrame:superClass().onClose(self)
end

function ProductionDlgFrame:onClickBack(sender)
	dbPrintf("ProductionDlgFrame:onClickBack()")
	self:close()
end