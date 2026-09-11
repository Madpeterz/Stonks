local api = require("api")
local constants = require("Stonks/constants")

local StonksSettings = {}
local addonName = constants.addonName
local getSettings = api.GetSettings
local saveSettings = api.SaveSettings

local settings = nil
local defaultSettings = {
    OpenButtonX = 1499,
    OpenButtonY = 716,
    uiDrawScale = 1.25, -- Scale for UI elements
    showUIbutton = true, -- Show the main UI button
}

local function DevLog(message)
    if constants.DEV_MODE then
        api.Log:Info(message)
    end
end

local function EnsureSettingsLoaded()
    if settings == nil then
        settings = StonksSettings.LoadSettings()
        if settings == nil then
            settings = defaultSettings
        end
    end
    return settings
end

function  StonksSettings.Is(key, value)
    return StonksSettings.Get(key) == value
end

function StonksSettings.KeyExists(key)
    if key == nil then
        DevLog("setting key "..tostring(key).." does not exist")
        return false
    end
    return defaultSettings[key] ~= nil
end

function StonksSettings.Get(key)
    if not StonksSettings.KeyExists(key) then
        return nil
    end
    local loadedSettings = EnsureSettingsLoaded()
    if loadedSettings[key] == nil then
        return defaultSettings[key]
    end
    return loadedSettings[key]
end

function StonksSettings.Update(key, value)
    if not StonksSettings.KeyExists(key) then
        return false
    end
    local loadedSettings = EnsureSettingsLoaded()

    local oldvalue = loadedSettings[key]
    loadedSettings[key] = value
    if oldvalue ~= value then 
        DevLog("Setting updated: "..key.." = "..tostring(value))
        saveSettings(addonName, loadedSettings)
    end
    return true
end

function StonksSettings.LoadSettings()
    local loadedSettings = getSettings(addonName)
    if loadedSettings == nil then
        loadedSettings = {}
    end
    -- loop for set default settings if not exists
    local needsSave = false
    for k, v in pairs(defaultSettings) do
        if loadedSettings[k] == nil then 
            loadedSettings[k] = v 
            needsSave = true
        end
    end
    if needsSave then
        saveSettings(addonName, loadedSettings)
        DevLog("Settings file created with default settings")
    end
    return loadedSettings
end

return StonksSettings