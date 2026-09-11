-- Stonks Bag Scanner
-- Loads stonks.dat into memory and scans the player's inventory for items
-- whose itemid is present in that dataset.
local api = require("api")
local constants = require("Stonks/constants")

local scanner = {}

-- Lowercased copy of Constants.buildingNames for case-insensitive substring tests.
local BUILDING_NAMES_LOWER = {}
for _, name in ipairs(constants.buildingNames or {}) do
    BUILDING_NAMES_LOWER[#BUILDING_NAMES_LOWER + 1] = name:lower()
end

-- True if `name` contains any Constants.buildingNames entry as a substring.
local function isBuildingName(name)
    local lower = name:lower()
    for _, needle in ipairs(BUILDING_NAMES_LOWER) do
        if string.find(lower, needle, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local DATA_PATH = "Stonks/stonks.dat"
local INVENTORY_BAG = 1 -- bagType 1 = Inventory
local KEYWORD = "design" -- substring, matched case-insensitively, for discovery scans

-- api.File:Write serialises via pairs(), whose hash-part order is undefined,
-- so named {itemid=.., itemname=.., valueper=..} rows flip field order on
-- every save. Lua's array part is order-preserving, so rows are stored on
-- disk as positional arrays in this order and named in memory everywhere else.
local FIELD_ORDER = { "itemid", "itemname", "valueper" }

-- Named row -> positional array, e.g. {itemid=1, itemname="x", valueper=2} -> {1, "x", 2}.
local function toPositional(row)
    local arr = {}
    for i, field in ipairs(FIELD_ORDER) do
        arr[i] = row[field]
    end
    return arr
end

-- Positional array -> named row, e.g. {1, "x", 2} -> {itemid=1, itemname="x", valueper=2}.
local function toNamed(row)
    local named = {}
    for i, field in ipairs(FIELD_ORDER) do
        named[field] = row[i]
    end
    return named
end

-- In-memory dataset. `rows` is the ordered list as stored in stonks.dat;
-- `byId` maps itemid -> row for fast lookup during a scan.
local dataset = {
    rows = nil,
    byId = nil,
}

-- Pull the item id out of a bag item info table (field name varies by build).
local function itemIdFromInfo(info)
    return info.id or info.itemId or info.itemType or info.type
end

-- Reads stonks.dat from disk and rebuilds the in-memory dataset.
function scanner.LoadDataset()
    local rows = api.File:Read(DATA_PATH)
    if type(rows) ~= "table" then
        rows = {}
    end

    local byId = {}
    for i, raw in ipairs(rows) do
        local row = toNamed(raw)
        if row ~= nil and row.itemid ~= nil then
            row.color = nil -- legacy field, no longer used
            rows[i] = row
            byId[row.itemid] = row
        end
    end

    dataset.rows = rows
    dataset.byId = byId
    api.Log:Info("[Stonks] Loaded " .. tostring(#rows) .. " row(s) from " .. DATA_PATH)
    return dataset
end

-- Returns the in-memory dataset, loading it from disk on first use.
function scanner.GetDataset()
    if dataset.rows == nil then
        scanner.LoadDataset()
    end
    return dataset
end

-- Serialises the in-memory dataset back to stonks.dat.
function scanner.SaveDataset()
    local data = scanner.GetDataset()
    local positional = {}
    for i, row in ipairs(data.rows) do
        positional[i] = toPositional(row)
    end
    api.File:Write(DATA_PATH, positional)
    api.Log:Info("[Stonks] Saved " .. tostring(#data.rows) .. " row(s) to " .. DATA_PATH)
end

-- Scans the bag for items whose name contains KEYWORD and that are not already
-- in the dataset. New ones are appended (valueper 0) and stonks.dat is
-- rewritten. Returns the list of rows that were added.
function scanner.ScanForNewDesigns()
    local data = scanner.GetDataset()
    local added = {}

    local capacity = api.Bag:Capacity() or 0
    for index = 1, capacity do
        local info = api.Bag:GetBagItemInfo(INVENTORY_BAG, index)
        if info ~= nil and type(info.name) == "string" and info.name ~= "" then
            if string.find(info.name:lower(), KEYWORD, 1, true) ~= nil and not isBuildingName(info.name) then
                local itemId = itemIdFromInfo(info)
                if itemId ~= nil and data.byId[itemId] == nil then
                    local row = {
                        itemid = itemId,
                        itemname = info.name,
                        valueper = 0,
                    }
                    data.byId[itemId] = row
                    data.rows[#data.rows + 1] = row
                    added[#added + 1] = row
                    api.Log:Info("[Stonks] New design: '" .. info.name .. "' itemid=" .. tostring(itemId))
                end
            end
        end
    end

    if #added > 0 then
        scanner.SaveDataset()
    end

    return added
end

-- Scans the bag and returns rows from the dataset for every itemid found in it.
-- Each result: { itemid, itemname, count, valueper, value, row }.
-- `count` is summed across every bag slot holding that item;
-- `value` is count * valueper.
function scanner.FindMatchingItems()
    local data = scanner.GetDataset()
    local byId = {}
    local found = {}

    local capacity = api.Bag:Capacity() or 0
    for index = 1, capacity do
        local info = api.Bag:GetBagItemInfo(INVENTORY_BAG, index)
        if info ~= nil then
            local itemId = itemIdFromInfo(info)
            local row = itemId ~= nil and data.byId[itemId] or nil
            if row ~= nil then
                local slotCount = tonumber(info.count) or 1
                local entry = byId[itemId]
                if entry == nil then
                    entry = {
                        itemid = itemId,
                        itemname = info.name or row.itemname,
                        count = 0,
                        valueper = tonumber(row.valueper) or 0,
                        row = row,
                    }
                    byId[itemId] = entry
                    found[#found + 1] = entry
                end
                entry.count = entry.count + slotCount
            end
        end
    end

    for _, entry in ipairs(found) do
        entry.value = entry.count * entry.valueper
    end

    return found
end

-- Scans the bag and returns a summary:
--   { matches, totalValue, top3 }
-- `top3` is the matches sorted by valueper (desc), truncated to 3.
function scanner.SummariseBag()
    local matches = scanner.FindMatchingItems()

    local totalValue = 0
    for _, entry in ipairs(matches) do
        totalValue = totalValue + entry.value
    end

    local ranked = {}
    for _, entry in ipairs(matches) do
        ranked[#ranked + 1] = entry
    end
    table.sort(ranked, function(a, b)
        if a.valueper == b.valueper then
            return a.value > b.value
        end
        return a.valueper > b.valueper
    end)

    local top3 = {}
    for i = 1, math.min(3, #ranked) do
        top3[i] = ranked[i]
    end

    api.Log:Info("[Stonks] Total value: " .. tostring(totalValue)
        .. " across " .. tostring(#matches) .. " item(s)")
    for i, entry in ipairs(top3) do
        api.Log:Info("[Stonks] Top " .. i .. ": " .. tostring(entry.itemname)
            .. " (valueper " .. tostring(entry.valueper) .. ", x" .. tostring(entry.count)
            .. ", value " .. tostring(entry.value) .. ")")
    end

    return {
        matches = matches,
        totalValue = totalValue,
        top3 = top3,
    }
end

return scanner
