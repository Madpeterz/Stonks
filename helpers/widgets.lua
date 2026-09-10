local api = require("api")
local constants = require("Stonks/constants")
local settingsModule = require("Stonks/settings")
local log = require("Stonks/helpers/log")

local widgets = {}
local defaultClickSoundKey = "auction_put_up"

function widgets.CreateImageButton(id, parent, texturenormal, offsetX, offsetY, sizeX, sizeY, onClickFunction, hasOnHover, onHoverTexture, onHoverTooltip, clickSoundKey)
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    sizeX = sizeX or 25
    sizeY = sizeY or 25
    offsetX = offsetX * settingsModule.Get("uiDrawScale")
    offsetY = offsetY * settingsModule.Get("uiDrawScale")
    sizeX = sizeX * settingsModule.Get("uiDrawScale")
    sizeY = sizeY * settingsModule.Get("uiDrawScale")

    local texturePathNormal = nil
    local texturePathHover = nil
    if texturenormal ~= nil then
        texturePathNormal = constants.folderPath.."images/" .. texturenormal
    end
    if onHoverTexture ~= nil then
        texturePathHover = constants.folderPath.."images/" .. onHoverTexture
    end


    local button = parent:CreateChildWidget("button", id, 0, true)
    local image = nil
    if texturePathNormal ~= nil then
        image = parent:CreateImageDrawable(id .. "_image", "artwork")
        if image == nil then
            log.DevLog("CreateImageButton: Failed to create image drawable for '"..id.."'.")
            return button
        end
        image:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
        image:SetExtent(sizeX, sizeY)
        image:SetTexture(texturePathNormal)
        image:Show(true)
    else
        log.DevLog("CreateImageButton: No texture provided for '"..id.."'.")
    end
    button:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
    button:SetExtent(sizeX, sizeY)
    button:Show(true)
    button:Enable(true)
    if button.SetSounds ~= nil then
        button:SetSounds(clickSoundKey or defaultClickSoundKey)
    end
    button.parent = parent
    button.imageDrawable = image

    if hasOnHover == true then
        function button:HoverStart()
            local mouseX, mouseY = button:GetEffectiveOffset()
            if onHoverTooltip ~= nil then
                api.Interface:SetTooltipOnPos(onHoverTooltip, button, mouseX + button:GetWidth(), mouseY)
            end
            if texturePathHover ~= nil then
                if image ~= nil then
                    image:SetTexture(texturePathHover)
                end
            end
        end

        function button:HoverEnd()
            if onHoverTooltip ~= nil then
                api.Interface:SetTooltipOnPos("", button, 0, 0)
            end
            if texturePathNormal ~= nil then
                if image ~= nil then
                    image:SetTexture(texturePathNormal)
                end
            end
        end
        button:SetHandler("OnEnter", button.HoverStart)
        button:SetHandler("OnLeave", button.HoverEnd)
    end

    if onClickFunction ~= nil then
        function button:OnClick()
            onClickFunction()
        end
        button:SetHandler("OnClick", button.OnClick)
    end
    return button
end

function widgets.makeWindowDraggable(dragTarget, OnStartCallback, OnEndCallback, MoveEnableWithShift, SavePosition, SavePositionXKey, SavePositionYKey, DisableParentBinding, DisableBlockDragIfNotShift)
    DisableParentBinding = DisableParentBinding or false
    DisableBlockDragIfNotShift = DisableBlockDragIfNotShift or false

    if dragTarget.RegisterForDrag == nil and dragTarget.EnableDrag == nil then
        log.DevLog("makeWindowDraggable: Drag target does not support dragging")
		return
    end

    local moveTarget = dragTarget
    if dragTarget.parent ~= nil and DisableParentBinding == false then
        moveTarget = dragTarget.parent
    end

    if moveTarget.StartMoving == nil or moveTarget.StopMovingOrSizing == nil then
        log.DevLog("makeWindowDraggable: Drag target does not support movement")
        return
    end

	function dragTarget:OnDragStart()
        local moveEnabled = true
        if MoveEnableWithShift then
            moveEnabled = api.Input:IsShiftKeyDown()
        end
		if moveEnabled == false and DisableBlockDragIfNotShift == false then
           	return
		end
        if moveEnabled == true then
            moveTarget:StartMoving()
            api.Cursor:ClearCursor()
            api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
        end
		if OnStartCallback ~= nil then
			OnStartCallback()
		end
    end

    function dragTarget:OnDragStop()
		moveTarget:StopMovingOrSizing()
        api.Cursor:ClearCursor()
        if SavePosition then
			local x, y = moveTarget:GetEffectiveOffset()
            if SavePositionXKey then
                settingsModule.Update(SavePositionXKey, x)
            end
            if SavePositionYKey then
                settingsModule.Update(SavePositionYKey, y)
            end
        end
		if OnEndCallback ~= nil then
			local x, y = moveTarget:GetEffectiveOffset()
			OnEndCallback(x, y)
		end
    end

    dragTarget:SetHandler("OnDragStart", dragTarget.OnDragStart)
    dragTarget:SetHandler("OnDragStop", dragTarget.OnDragStop)
    if dragTarget.RegisterForDrag ~= nil then
        dragTarget:RegisterForDrag("LeftButton")
    end
    if dragTarget.EnableDrag ~= nil then
        dragTarget:EnableDrag(true)
    end
end

return widgets
