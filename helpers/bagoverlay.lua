-- Stonks Bag Overlay
-- Draws a coloured box at the bottom of each bag slot that holds a dataset item,
-- mirroring how WorldSatNav's treasuremaps feature labels bag slots.
local api = require("api")
local constants = require("Stonks/constants")
local scanner = require("Stonks/scanner")

local bagoverlay = {}

-- Height of the coloured strip, in pixels, and its fill opacity (0..1).
local BOX_HEIGHT = 4
local BOX_ALPHA = 0.55

-- color code (from a dataset row's `color` field) -> {r, g, b}, 0..1 floats.
-- Alpha is applied uniformly via BOX_ALPHA.
local COLORS = {
    [0]  = { 0.10, 0.80, 0.20 }, -- green
    [1]  = { 0.20, 0.45, 1.00 }, -- blue
    [2]  = { 1.00, 0.45, 0.80 }, -- pink
    [3]  = { 1.00, 0.60, 0.00 }, -- orange
    [4]  = { 1.00, 0.35, 0.10 }, -- orangy red
    [5]  = { 0.90, 0.12, 0.12 }, -- red
    [6]  = { 1.00, 0.55, 0.20 }, -- yellowy red
    [7]  = { 0.45, 0.80, 1.00 }, -- sky blue
    [8]  = { 1.00, 0.84, 0.00 }, -- gold
    [9]  = { 0.50, 0.00, 0.00 }, -- dark red
    [10] = { 0.40, 0.30, 0.90 }, -- purple blue
}
local DEFAULT_COLOR = { 0.60, 0.60, 0.60 }

-- slotIndex -> overlay widget, reused across shows.
local boxes = {}

local function colorForCode(code)
    local rgb = COLORS[tonumber(code) or -1] or DEFAULT_COLOR
    return rgb[1], rgb[2], rgb[3], BOX_ALPHA
end

local function itemIdFromInfo(info)
    return info.id or info.itemId or info.itemType or info.type
end

local function getBox(slotIndex, slotBtn)
    if boxes[slotIndex] ~= nil then
        return boxes[slotIndex]
    end
    local box = slotBtn:CreateChildWidget("label", "stonksColorBox_" .. slotIndex, 0, true)
    box:SetExtent(slotBtn:GetWidth(), BOX_HEIGHT)
    box.bg = box:CreateColorDrawable(0, 0, 0, 0, "overlay")
    box.bg:AddAnchor("TOPLEFT", box, 0, 0)
    box.bg:AddAnchor("BOTTOMRIGHT", box, 0, 0)
    boxes[slotIndex] = box
    return box
end

-- Hide every overlay box.
function bagoverlay.Hide()
    for _, box in pairs(boxes) do
        if box:IsVisible() == true then
            box:Show(false)
        end
    end
end

-- Free every overlay widget and drop the cache. Call from the addon's OnUnload.
function bagoverlay.Destroy()
    for slotIndex, box in pairs(boxes) do
        box:Show(false)
        api.Interface:Free(box)
        boxes[slotIndex] = nil
    end
end

-- Redraw: show a coloured box on each bag slot holding a dataset item, hide the rest.
function bagoverlay.Show()
    local bagFrame = ADDON:GetContent(UIC.BAG)
    if not bagFrame or not bagFrame.slots or not bagFrame.slots.btns then
        return
    end

    local byId = scanner.GetDataset().byId or {}
    local used = {}

    for slotIndex, slotBtn in pairs(bagFrame.slots.btns) do
        local info = slotBtn:GetInfo()
        local itemId = info ~= nil and itemIdFromInfo(info) or nil
        local row = itemId ~= nil and byId[itemId] or nil
        if row ~= nil then
            local box = getBox(slotIndex, slotBtn)
            box:RemoveAllAnchors()
            box:AddAnchor("BOTTOM", slotBtn, 0, constants.overlay.heightOffset)
            box.bg:SetColor(colorForCode(row.color))
            box:Show(true)
            used[slotIndex] = true
        end
    end

    for slotIndex, box in pairs(boxes) do
        if used[slotIndex] ~= true then
            box:Show(false)
        end
    end
end

return bagoverlay
