local dbPrintfOn = false

local function dbPrintf(...)
	if dbPrintfOn then
    	print(string.format(...))
	end
end

local function dbPrintHeader(funcName)
	if dbPrintfOn then
		if g_currentMission ~= nil and g_currentMission.missionDynamicInfo ~= nil then
			print(string.format("Call %s: isServer()=%s | isClient()=%s | farmId=%s", 
				funcName, tostring(g_currentMission:getIsServer()), 
				tostring(g_currentMission:getIsClient()), 
				tostring(g_currentMission:getFarmId())))
		else
			print(string.format("Call %s: g_currentMission=%s", funcName, tostring(g_currentMission)))
		end
	end
end

ProductionOverview = {}


ProductionOverview.dir = g_currentModDirectory
ProductionOverview.modName = g_currentModName
ProductionOverview.dlg = nil

source(ProductionOverview.dir .. "gui/ProductionDlgFrame.lua")

function ProductionOverview:loadMap(name)
    dbPrintHeader("ProductionOverview:loadMap()")
end

function ProductionOverview:ShowProductionDlg(actionName, keyStatus, arg3, arg4, arg5)
	dbPrintHeader("ProductionOverview:ShowProductionDlg()")

	ProductionOverview.dlg = nil
	g_gui:loadProfiles(ProductionOverview.dir .. "gui/guiProfiles.xml")
	local productionDlgFrame = ProductionDlgFrame.new(g_i18n)
	g_gui:loadGui(ProductionOverview.dir .. "gui/ProductionDlgFrame.xml", "ProductionDlgFrame", productionDlgFrame)
	ProductionOverview.dlg = g_gui:showDialog("ProductionDlgFrame")
end

function ProductionOverview:onLoad(savegame) end
function ProductionOverview:onUpdate(dt) end
function ProductionOverview:deleteMap() end
function ProductionOverview:keyEvent(unicode, sym, modifier, isDown) end
function ProductionOverview:mouseEvent(posX, posY, isDown, isUp, button) end

addModEventListener(ProductionOverview)