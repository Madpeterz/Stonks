-- Stonks Main Module
local api = require("api")
local settings = require("Stonks/settings")
local widgets = require("Stonks/helpers/widgets")
local constants = require("Stonks/constants")
local scanner = require("Stonks/scanner")
local bagoverlay = require("Stonks/helpers/bagoverlay")

local enabledBagOverlay = false

-- Delay between enabling the overlay and the bag scan actually running.
local SCAN_DELAY_MS = 4000

-- Bumped every time a scan is queued. api:DoIn has no cancel handle, so a queued
-- runBagScan checks this against the value it captured and bails if it is stale
-- (the button was toggled again before the delay elapsed).
local scanGeneration = 0

-- Rapid-click discovery: click the toggle button this many times, each within
-- RAPID_CLICK_RESET_MS of the last, to rescan the bag for unknown designs.
local RAPID_CLICKS_REQUIRED = 5
local RAPID_CLICK_RESET_MS = 600
local rapidClickCount = 0
local rapidClickLastMs = nil

-- Bare name passed to CreateImageButton (it prepends folderPath.."images/").
local TEX_UNCHECKED = "controls/main_ui_unchecked.png"
local TEX_CHECKED = "controls/main_ui_checked.png"
-- Full paths for manual SetTexture calls (no prefixing done there).
local TEX_UNCHECKED_PATH = constants.folderPath .. "images/" .. TEX_UNCHECKED
local TEX_CHECKED_PATH = constants.folderPath .. "images/" .. TEX_CHECKED

local Stonks = {
	name = "Stonks",
	author = "Madpeter",
	version = "1.0.0",
	desc = "Its worth 1000g im sure"
}

local function runBagScan(generation)
	-- Bailed if the overlay was switched off again during the delay, or if a
	-- newer scan has since been queued (superseding this one).
	if not enabledBagOverlay or generation ~= scanGeneration then
		return
	end
	-- Scan bag for items whose itemid is in the stonks.dat dataset.
	local summary = scanner.SummariseBag()
	api.Log:Info("[Stonks] Bag total value " .. tostring(summary.totalValue)
		.. " (" .. tostring(#summary.matches) .. " item(s), top " .. tostring(#summary.top3) .. " logged).")
	bagoverlay.Show()
end

local function ApplyBagOverlay(enabled)
	-- Invalidate any scan still sitting in the queue.
	scanGeneration = scanGeneration + 1
	if enabled then
		local generation = scanGeneration
		api.Log:Info("Bag overlay enabled; scanning in " .. tostring(SCAN_DELAY_MS / 1000) .. "s.")
		api:DoIn(SCAN_DELAY_MS, function() runBagScan(generation) end)
	else
		api.Log:Info("Bag overlay disabled.")
		bagoverlay.Hide()
	end
end

local function toggleUIbutton()
	showUIbutton = settings.Get("showUIbutton")
	showUIbutton = not showUIbutton
	settings.Update("showUIbutton", showUIbutton)
	if settings.Get("showUIbutton") then
		Stonks.windowUIbUTTON:Show(true)
	else
		Stonks.windowUIbUTTON:Show(false)
	end
end
-- Counts consecutive fast clicks on the toggle button; on the Nth, rescans the
-- bag for designs not yet in stonks.dat and adds them.
local function handleRapidClick()
	local now = api.Time:GetUiMsec()
	if rapidClickLastMs == nil or now == nil or (now - rapidClickLastMs) > RAPID_CLICK_RESET_MS then
		rapidClickCount = 0
	end
	rapidClickLastMs = now
	rapidClickCount = rapidClickCount + 1

	if rapidClickCount >= RAPID_CLICKS_REQUIRED then
		rapidClickCount = 0
		local added = scanner.ScanForNewDesigns()
		api.Log:Info("[Stonks] Design rescan added " .. tostring(#added) .. " new item(s).")
		if enabledBagOverlay then
			bagoverlay.Show()
		end
	end
end

local function makeUI()
	Stonks.windowUIbUTTON = api.Interface:CreateEmptyWindow("Stonks")
	Stonks.windowUIbUTTON:AddAnchor("TOPLEFT", "UIParent", settings.Get("OpenButtonX"), settings.Get("OpenButtonY"))
	Stonks.windowUIbUTTON:SetExtent(50*settings.Get("uiDrawScale"),50*settings.Get("uiDrawScale"))
	Stonks.windowUIbUTTON:SetCloseOnEscape(false)
	Stonks.windowUIbUTTON:Show(true)

	-- Real button widget (CreateImageButton returns it and sets button.parent),
	-- so the drag helper can bind to it the same way WorldSatNav does.
	-- Declared before assignment so the onClick closure captures this local.
	local mainUIButton
	mainUIButton = widgets.CreateImageButton(
		"MainUIButton",
		Stonks.windowUIbUTTON,
		TEX_UNCHECKED,
		0, 0,
		50, 50,
		function()
			handleRapidClick()
			enabledBagOverlay = not enabledBagOverlay
			if mainUIButton.imageDrawable ~= nil then
				mainUIButton.imageDrawable:SetTexture(enabledBagOverlay and TEX_CHECKED_PATH or TEX_UNCHECKED_PATH)
			end
			ApplyBagOverlay(enabledBagOverlay)
		end,
		false, nil,
		"Toggle bag overlay",
		"auction")
	Stonks.windowUIbUTTON.mainUIButton = mainUIButton

	-- Hold Shift and drag to reposition; plain click still toggles.
	-- moveTarget resolves to mainUIButton.parent (the window). Saves to OpenButtonX/Y.
	widgets.makeWindowDraggable(mainUIButton, nil, nil, true, true, "OpenButtonX", "OpenButtonY")
end

-- Addon initialization
local function OnLoad()
	api.Log:Info("[" .. Stonks.name .. "] Starting version " .. Stonks.version)
	-- load stonks.dat into memory
	scanner.LoadDataset()
	-- build UI
	makeUI()
	-- attach events
	function Stonks:EventListener(event, ...)
		if(event == "REMOVED_ITEM") then
			if enabledBagOverlay then bagoverlay.Show() end
		elseif(event == "BAG_UPDATE") then
			if enabledBagOverlay then bagoverlay.Show() end
		end
	end
	Stonks.windowUIbUTTON:SetHandler("OnEvent", Stonks.EventListener)
    Stonks.windowUIbUTTON:RegisterEvent("REMOVED_ITEM")
    Stonks.windowUIbUTTON:RegisterEvent("BAG_UPDATE")

	ESCMenu = ESCMenu or {}
	ESCMenu.queue = ESCMenu.queue or {}
	table.insert(ESCMenu.queue, {
		name     = "Stonks",                        -- row label + dedupe key
		callback = function() toggleUIbutton() end,  -- run on click; menu closes itself
		category = "Vocation",                         -- optional: Characters / Combat /
													-- Shop/Quality of Life / Vocation /
													-- System/Addons (default). Prefixes ok.
		icon     = "price",                      -- optional, from the list below
	})

	if settings.Get("showUIbutton") then
		Stonks.windowUIbUTTON:Show(true)
	else
		Stonks.windowUIbUTTON:Show(false)
	end
end

-- Addon cleanup
local function OnUnload()
	-- Unregister hooks
	api.On("UPDATE", function() return end)
	-- Tear down bag slot overlays
	bagoverlay.Destroy()
	-- Unregister events
	if Stonks.windowUIbUTTON ~= nil then
		Stonks.windowUIbUTTON:ReleaseHandler("OnEvent")
		api.Interface:Free(Stonks.windowUIbUTTON)
	end

end

Stonks.OnSettingToggle = nil

Stonks.OnLoad = OnLoad
Stonks.OnUnload = OnUnload

return Stonks