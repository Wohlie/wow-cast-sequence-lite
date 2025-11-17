local addonName, CSL = ...

CSL.UIManager = CSL.UIManager or {}

local AceGUI = LibStub("AceGUI-3.0")

local ERROR_SOUND_ID = "igQuestFailed"

-- Define confirmation dialog for deletion
StaticPopupDialogs["CSL_CONFIRM_DELETE"] = {
    text = "Are you sure you want to delete the rotation '%s'?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        local rotationName = data or (self and self.data)
        if not rotationName then
            return
        end

        CSL:DeleteRotation(rotationName)
        CSL.UIManager:RefreshRotationList()
        CSL.UIManager:ShowRotationEditor(nil)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function CSL.UIManager:SetEditorError(editorGroup, field, message)
    if not editorGroup then
        return
    end

    local formatted = message and message or ""
    local fieldMap = {
        name = "nameErrorLabel",
        preCast = "preCastErrorLabel",
        commands = "commandsErrorLabel"
    }

    local errorLabel = fieldMap[field] and editorGroup[fieldMap[field]]
    if errorLabel then
        local shouldPlaySound = not editorGroup._errorSoundPlayed and formatted ~= ""
        if shouldPlaySound then
            PlaySound(ERROR_SOUND_ID)
            editorGroup._errorSoundPlayed = true
        end
        errorLabel:SetText(formatted)
    end
end

function CSL.UIManager:ClearEditorErrors(editorGroup)
    if not editorGroup then
        return
    end

    local errorLabels = { "nameErrorLabel", "commandsErrorLabel", "preCastErrorLabel" }
    for _, label in ipairs(errorLabels) do
        if editorGroup[label] then
            editorGroup[label]:SetText("")
        end
    end

    editorGroup._errorSoundPlayed = nil
end

-- Helper to find next enabled input widget for tab navigation
function CSL.UIManager:GetNextEnabledInput(inputWidgets, currentWidget, reverse)
    local currentIndex
    for i, widget in ipairs(inputWidgets) do
        if widget == currentWidget then
            currentIndex = i
            break
        end
    end

    if not currentIndex then
        return nil
    end

    local step = reverse and -1 or 1
    local count = #inputWidgets

    for i = 1, count do
        local nextIndex = ((currentIndex - 1 + i * step) % count) + 1
        local nextWidget = inputWidgets[nextIndex]
        if nextWidget and not nextWidget.disabled then
            return nextWidget
        end
    end
    return nil
end

function CSL.UIManager:EnsureRowBackdrop(rowFrame)
    if not rowFrame or rowFrame._cslHasBackdrop then
        return
    end

    rowFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    rowFrame:SetBackdropColor(0, 0, 0, 0)
    rowFrame:SetBackdropBorderColor(0, 0, 0, 0)
    rowFrame._cslHasBackdrop = true
end

function CSL.UIManager:SetActiveRotationRow(rotationName)
    local frame = self.ManagementFrame
    if not frame or not frame.rotationRows then
        return
    end

    for name, rowData in pairs(frame.rotationRows) do
        local rowFrame = rowData.group and rowData.group.frame
        if rowFrame then
            self:EnsureRowBackdrop(rowFrame)
            local isActive = rotationName and name == rotationName
            rowFrame:SetBackdropColor(isActive and 0.1 or 0, isActive and 0.1 or 0, isActive and 0.1 or 0, isActive and 0.5 or 0)
            rowFrame:SetBackdropBorderColor(isActive and 0.4 or 0, isActive and 0.4 or 0, isActive and 0.4 or 0)
        end
    end
end

-- Create the main rotation management frame
function CSL.UIManager:CreateManagementFrame()
    if self.ManagementFrame then
        return self.ManagementFrame
    end

    -- Main frame
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("CastSequenceLite - Rotation Manager")
    frame:SetLayout("Fill")
    frame:SetWidth(700)
    frame:SetHeight(500)
    if frame.frame then
        frame.frame:SetFrameStrata("DIALOG")
        frame.frame:SetToplevel(true)
    end
    frame:SetCallback("OnClose", function(widget)
        widget:Hide()
        if widget.escFrame and widget.escFrame:IsShown() then
            widget.escFrame:Hide()
        end
    end)

    -- Proxy frame to integrate with UISpecialFrames (ESC handling)
    local escFrameName = "CSLManagementFrame"
    local escFrame = _G[escFrameName]
    if not escFrame then
        escFrame = CreateFrame("Frame", escFrameName, UIParent)
        escFrame:Hide()
        escFrame:SetFrameStrata("DIALOG")
        escFrame:SetToplevel(true)
        table.insert(UISpecialFrames, escFrameName)
    end

    frame.escFrame = escFrame

    escFrame:SetScript("OnShow", function()
        if not frame.frame:IsShown() then
            frame:Show()
        end
    end)

    escFrame:SetScript("OnHide", function()
        if frame.frame:IsShown() then
            frame:Hide()
        end
    end)

    -- Main container with horizontal layout
    local mainContainer = AceGUI:Create("SimpleGroup")
    mainContainer:SetFullWidth(true)
    mainContainer:SetFullHeight(true)
    mainContainer:SetLayout("Flow")
    frame:AddChild(mainContainer)

    -- Left panel: Rotation list (200px wide)
    local leftGroup = AceGUI:Create("InlineGroup")
    leftGroup:SetTitle("Rotations")
    leftGroup:SetLayout("Fill")
    leftGroup:SetWidth(200)
    leftGroup:SetRelativeWidth(0.3)
    leftGroup:SetFullHeight(true)
    mainContainer:AddChild(leftGroup)

    local leftScroll = AceGUI:Create("ScrollFrame")
    leftScroll:SetLayout("List")
    leftScroll:SetFullWidth(true)
    leftScroll:SetFullHeight(true)
    leftGroup:AddChild(leftScroll)

    frame.leftScroll = leftScroll

    -- New rotation button
    local newBtn = AceGUI:Create("Button")
    newBtn:SetText("+ New Rotation")
    newBtn:SetFullWidth(true)
    newBtn:SetCallback("OnClick", function()
        CSL.UIManager:ShowRotationEditor(nil)
    end)
    leftScroll:AddChild(newBtn)

    -- Right panel: Editor
    local rightGroup = AceGUI:Create("InlineGroup")
    rightGroup:SetTitle("Rotation Editor")
    rightGroup:SetLayout("Fill")
    rightGroup:SetFullWidth(true)
    rightGroup:SetRelativeWidth(0.7)
    rightGroup:SetFullHeight(true)
    mainContainer:AddChild(rightGroup)

    frame.editorGroup = rightGroup
    frame.rotationRows = {}
    frame.activeRotation = nil
    rightGroup:SetCallback("OnShow", function()
        local editorGroup = frame.editorGroup
        if editorGroup and editorGroup.nameInput and editorGroup.nameInput.SetFocus then
            editorGroup.nameInput:SetFocus()
        end
    end)

    self.ManagementFrame = frame
    self:RefreshRotationList()
    self:RegisterCombatWatcher()

    frame.frame:Hide()
    return frame
end

-- Refresh the rotation list  
function CSL.UIManager:RefreshRotationList()
    local frame = self.ManagementFrame
    if not frame or not frame.leftScroll then
        return
    end

    local leftScroll = frame.leftScroll
    leftScroll:ReleaseChildren()
    frame.rotationRows = {}

    -- Re-add new button
    local newBtn = AceGUI:Create("Button")
    newBtn:SetText("+ New Rotation")
    newBtn:SetFullWidth(true)
    newBtn:SetCallback("OnClick", function()
        CSL.UIManager:ShowRotationEditor(nil)
    end)
    leftScroll:AddChild(newBtn)

    -- Add rotation rows sorted
    local rotationNames = {}
    for rotationName in pairs(CSL.Rotations) do
        table.insert(rotationNames, rotationName)
    end
    table.sort(rotationNames)

    for _, rotationName in ipairs(rotationNames) do
        self:AddRotationListRow(leftScroll, rotationName)
    end

    self:SetActiveRotationRow(frame.activeRotation)
end

-- Show rotation editor
function CSL.UIManager:ShowRotationEditor(rotationName)
    local frame = self.ManagementFrame
    if not frame or not frame.editorGroup then
        return
    end

    local editorGroup = frame.editorGroup
    editorGroup:ReleaseChildren()

    -- Create editor scroll container
    local editorScroll = AceGUI:Create("ScrollFrame")
    editorScroll:SetLayout("Flow")
    editorScroll:SetFullWidth(true)
    editorScroll:SetFullHeight(true)
    editorGroup:AddChild(editorScroll)
    editorGroup:DoLayout()

    -- Name input
    local nameInput = AceGUI:Create("EditBox")
    nameInput:SetLabel("Rotation Name:")
    nameInput:SetFullWidth(true)
    nameInput:SetMaxLetters(CSL.MAX_ROTATION_NAME_LENGTH)
    nameInput:DisableButton(true)
    editorScroll:AddChild(nameInput)

    local nameErrorLabel = AceGUI:Create("Label")
    nameErrorLabel:SetFullWidth(true)
    nameErrorLabel:SetColor(1, 0.2, 0.2)
    nameErrorLabel:SetText("")
    editorScroll:AddChild(nameErrorLabel)

    local nameErrorSpacer = AceGUI:Create("Label")
    nameErrorSpacer:SetFullWidth(true)
    nameErrorSpacer:SetText(" ")
    editorScroll:AddChild(nameErrorSpacer)

    -- PreCast input (multi-line editor, 50% height of cast commands)
    local preCastInput = AceGUI:Create("MultiLineEditBox")
    preCastInput:SetLabel("Pre-Cast Commands (optional, one per line):")
    preCastInput:SetFullWidth(true)
    preCastInput:SetNumLines(5)
    preCastInput:SetMaxLetters(255)
    preCastInput:DisableButton(true)
    editorScroll:AddChild(preCastInput)

    local preCastErrorLabel = AceGUI:Create("Label")
    preCastErrorLabel:SetFullWidth(true)
    preCastErrorLabel:SetColor(1, 0.2, 0.2)
    preCastErrorLabel:SetText("")
    editorScroll:AddChild(preCastErrorLabel)

    local preCastSpacer = AceGUI:Create("Label")
    preCastSpacer:SetFullWidth(true)
    preCastSpacer:SetText(" ")
    editorScroll:AddChild(preCastSpacer)

    -- Cast sequence input
    local commandsInput = AceGUI:Create("MultiLineEditBox")
    commandsInput:SetLabel("Cast Commands (one per line):")
    commandsInput:SetFullWidth(true)
    commandsInput:SetNumLines(7)
    commandsInput:SetMaxLetters(0)
    commandsInput:DisableButton(true)
    editorScroll:AddChild(commandsInput)

    local commandsErrorLabel = AceGUI:Create("Label")
    commandsErrorLabel:SetFullWidth(true)
    commandsErrorLabel:SetColor(1, 0.2, 0.2)
    commandsErrorLabel:SetText("")
    editorScroll:AddChild(commandsErrorLabel)

    local commandsErrorSpacer = AceGUI:Create("Label")
    commandsErrorSpacer:SetFullWidth(true)
    commandsErrorSpacer:SetText(" ")
    editorScroll:AddChild(commandsErrorSpacer)

    -- Reset after combat checkbox
    local resetAfterCombatCheckbox = AceGUI:Create("CheckBox")
    resetAfterCombatCheckbox:SetLabel("Reset to first step after combat")
    resetAfterCombatCheckbox:SetValue(false)
    resetAfterCombatCheckbox:SetFullWidth(true)
    editorScroll:AddChild(resetAfterCombatCheckbox)

    local resetSpacer = AceGUI:Create("Label")
    resetSpacer:SetFullWidth(true)
    resetSpacer:SetText(" ")
    editorScroll:AddChild(resetSpacer)

    -- Button group
    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetFullWidth(true)
    buttonGroup:SetLayout("Flow")
    editorScroll:AddChild(buttonGroup)

    -- Save button
    local saveBtn = AceGUI:Create("Button")
    saveBtn:SetText("Save")
    saveBtn:SetWidth(100)
    saveBtn:SetCallback("OnClick", function()
        CSL.UIManager:SaveRotation(nameInput, preCastInput, commandsInput, resetAfterCombatCheckbox)
    end)
    buttonGroup:AddChild(saveBtn)

    -- Cancel button
    local cancelBtn = AceGUI:Create("Button")
    cancelBtn:SetText("Cancel")
    cancelBtn:SetWidth(100)
    cancelBtn:SetCallback("OnClick", function()
        CSL.UIManager:ShowRotationEditor(nil)
    end)
    buttonGroup:AddChild(cancelBtn)

    -- Delete button (only for existing rotations)
    if rotationName then
        local deleteBtn = AceGUI:Create("Button")
        deleteBtn:SetText("Delete")
        deleteBtn:SetWidth(100)
        deleteBtn:SetCallback("OnClick", function()
            CSL.UIManager:DeleteRotation()
        end)
        buttonGroup:AddChild(deleteBtn)
    end

    -- Store references
    editorGroup.inputs = {
        name = nameInput,
        preCast = preCastInput,
        commands = commandsInput,
        resetAfterCombat = resetAfterCombatCheckbox
    }
    editorGroup.errorLabels = {
        name = nameErrorLabel,
        preCast = preCastErrorLabel,
        commands = commandsErrorLabel
    }
    editorGroup.currentRotation = rotationName
    -- Compatibility references
    editorGroup.nameInput = nameInput
    editorGroup.preCastInput = preCastInput
    editorGroup.commandsInput = commandsInput
    editorGroup.resetAfterCombatCheckbox = resetAfterCombatCheckbox
    editorGroup.nameErrorLabel = nameErrorLabel
    editorGroup.preCastErrorLabel = preCastErrorLabel
    editorGroup.commandsErrorLabel = commandsErrorLabel

    -- Setup tab navigation (Tab = forward, Shift+Tab = backward)
    local inputWidgets = { nameInput, preCastInput, commandsInput }

    for _, widget in ipairs(inputWidgets) do
        local editBox = widget.editbox or widget.editBox
        if editBox then
            editBox:SetScript("OnTabPressed", function()
                local nextWidget = self:GetNextEnabledInput(inputWidgets, widget, IsShiftKeyDown())
                if nextWidget then
                    local nextEditBox = nextWidget.editbox or nextWidget.editBox
                    if nextEditBox then
                        nextEditBox:SetFocus()
                        -- Place cursor at end of text
                        local text = nextEditBox:GetText() or ""
                        nextEditBox:SetCursorPosition(#text)
                    end
                end
            end)
        end
    end

    self:ClearEditorErrors(editorGroup)
    frame.activeRotation = rotationName
    self:SetActiveRotationRow(rotationName)

    -- Populate data
    local rotation = rotationName and CSL.Rotations[rotationName]
    if rotation then
        nameInput:SetText(rotationName)
        nameInput:SetDisabled(true)
        preCastInput:SetText(rotation.preCastCommands and table.concat(rotation.preCastCommands, "\n") or "")
        commandsInput:SetText(table.concat(rotation.castCommands, "\n"))
        resetAfterCombatCheckbox:SetValue(rotation.resetAfterCombat or false)
        if editorGroup.buttonContainer then
            self:UpdateButtonPreview(rotationName, editorGroup.buttonContainer)
        end
    else
        nameInput:SetText("")
        nameInput:SetDisabled(false)
        preCastInput:SetText("")
        commandsInput:SetText("")
        resetAfterCombatCheckbox:SetValue(false)
        editorGroup.buttonContainer = nil
    end

    frame:DoLayout()

    -- Set focus to first enabled input field
    for _, widget in ipairs(inputWidgets) do
        if not widget.disabled then
            local editBox = widget.editbox or widget.editBox
            if editBox then
                editBox:SetFocus()
                -- Place cursor at end of text
                local text = editBox:GetText() or ""
                editBox:SetCursorPosition(#text)
                break
            end
        end
    end
end

function CSL.UIManager:AddRotationListRow(parent, rotationName)
    local rowGroup = AceGUI:Create("SimpleGroup")
    rowGroup:SetFullWidth(true)
    rowGroup:SetLayout("Flow")
    rowGroup:SetHeight(38)
    parent:AddChild(rowGroup)

    local openBtn = AceGUI:Create("Button")
    openBtn:SetText(rotationName)
    openBtn:SetRelativeWidth(0.7)
    openBtn:SetHeight(28)
    openBtn:SetCallback("OnClick", function()
        self:ShowRotationEditor(rotationName)
    end)
    rowGroup:AddChild(openBtn)

    local dragContainer = AceGUI:Create("SimpleGroup")
    dragContainer:SetRelativeWidth(0.3)
    dragContainer:SetLayout("Fill")
    dragContainer:SetHeight(38)
    rowGroup:AddChild(dragContainer)

    self:CreateRotationListDragButton(rotationName, dragContainer)

    local containerFrame = dragContainer.frame
    if containerFrame and not containerFrame._cslHooked then
        containerFrame._cslHooked = true
        containerFrame:HookScript("OnHide", function(frame)
            local widget = frame.obj
            if widget and widget.dragButton then
                widget.dragButton:Hide()
            end
        end)
    end

    dragContainer.dragButtonHost = dragContainer

    local frame = self.ManagementFrame
    if frame and frame.rotationRows then
        frame.rotationRows[rotationName] = {
            group = rowGroup,
            openBtn = openBtn,
            dragContainer = dragContainer,
        }
    end
end

function CSL.UIManager:CreateRotationListDragButton(rotationName, container)
    if not container or not container.frame then
        return
    end

    local rotation = CSL.Rotations[rotationName]
    if not rotation then
        return
    end

    CSL:CreateOrUpdateMacro(rotation)

    if container.dragButton then
        container.dragButton:Hide()
        container.dragButton:SetParent(nil)
        container.dragButton = nil
    end

    local button = CreateFrame("Button", nil, container.frame)
    button:SetSize(28, 28)
    button:SetPoint("RIGHT", container.frame, "RIGHT", -4, 0)
    button:EnableMouse(true)

    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local iconTexture = rotation.castCommands[1] and CSL.Helpers.GetIconForSpell(rotation.castCommands[1]) or CSL.Helpers.DEFAULT_ICON
    icon:SetTexture(iconTexture)
    button.icon = icon

    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        local macroName = "CSL_" .. rotationName
        local macroIdx = GetMacroIndexByName(macroName)
        if not macroIdx or macroIdx == 0 then
            CSL:CreateOrUpdateMacro(rotation)
            macroIdx = GetMacroIndexByName(macroName)
        end

        if macroIdx and macroIdx > 0 then
            PickupMacro(macroIdx)
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag to place '" .. rotationName .. "' on your action bar", 1, 1, 1, true)
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    container.dragButton = button
end

-- Update button preview
function CSL.UIManager:UpdateButtonPreview(rotationName, container)
    if not container then
        return
    end

    local rotation = CSL.Rotations[rotationName]
    if not rotation then
        return
    end

    CSL:CreateOrUpdateMacro(rotation)

    local previewParent = container.content
    previewParent:SetHeight(60)

    if container.previewButton then
        container.previewButton:Hide()
        container.previewButton:SetParent(nil)
        container.previewButton = nil
    end

    local button = CreateFrame("Button", nil, previewParent)
    container.previewButton = button
    button:SetSize(36, 36)
    button:SetPoint("LEFT")
    button:EnableMouse(true)

    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(button)
    button.icon = icon

    local iconTexture = rotation.castCommands[1] and CSL.Helpers.GetIconForSpell(rotation.castCommands[1]) or CSL.Helpers.DEFAULT_ICON
    button.icon:SetTexture(iconTexture)

    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        local macroName = "CSL_" .. rotationName
        local macroIdx = GetMacroIndexByName(macroName)
        if not macroIdx or macroIdx == 0 then
            CSL:CreateOrUpdateMacro(rotation)
            macroIdx = GetMacroIndexByName(macroName)
        end

        if macroIdx and macroIdx > 0 then
            PickupMacro(macroIdx)
        end

        local managementFrame = CSL.UIManager.ManagementFrame
        if managementFrame and managementFrame.frame then
            managementFrame.frame:EnableMouse(false)
        end
    end)

    button:Show()
end

-- Save rotation
function CSL.UIManager:SaveRotation(nameInput, preCastInput, commandsInput, resetAfterCombatCheckbox)
    if InCombatLockdown() then
        print("|cFFFF0000Cannot save rotations while in combat. Try again after combat.|r")
        return
    end

    self:RegisterCombatWatcher()

    local rotationName = nameInput:GetText():trim()
    local editorGroup = self.ManagementFrame.editorGroup
    self:ClearEditorErrors(editorGroup)

    -- Validate name
    if rotationName == "" then
        self:SetEditorError(editorGroup, "name", "Rotation name cannot be empty.")
        return
    end

    if #rotationName > CSL.MAX_ROTATION_NAME_LENGTH then
        self:SetEditorError(editorGroup, "name", "Rotation name must be " .. CSL.MAX_ROTATION_NAME_LENGTH .. " characters or less.")
        return
    end

    -- Check for duplicate only when creating new
    if not editorGroup.currentRotation and CSL.Rotations[rotationName] then
        self:SetEditorError(editorGroup, "name", "Rotation '" .. rotationName .. "' already exists.")
        return
    end

    -- Parse commands more efficiently
    local function parseCommands(text)
        local commands = {}
        for line in (text or ""):gmatch("[^\r\n]+") do
            local trimmed = line:trim()
            if trimmed ~= "" then
                table.insert(commands, trimmed)
            end
        end
        return commands
    end

    local preCastCommands = parseCommands(preCastInput:GetText())
    local castCommands = parseCommands(commandsInput:GetText())
    if #castCommands == 0 then
        self:SetEditorError(editorGroup, "commands", "At least one cast command is required.")
        return
    end

    local rotationConfig = {
        preCastCommands = #preCastCommands > 0 and preCastCommands or nil,
        castCommands = castCommands,
        resetAfterCombat = resetAfterCombatCheckbox:GetValue()
    }

    -- Initialize or update rotation
    local rotation = CSL:InitializeRotation(rotationName, rotationConfig)
    CSL:SaveRotationConfig(rotationName, rotationConfig)

    if not rotation.button then
        CSL:CreateButton(rotation)
    else
        CSL:UpdateButtonAttributes(rotation, rotation.button)
    end

    CSL:CreateOrUpdateMacro(rotation)

    print("|cFF00FF00Rotation '" .. rotationName .. "' saved!|r")

    self:RefreshRotationList()

    -- Update editor to show the saved rotation with button preview
    self:ShowRotationEditor(rotationName)
end

-- Delete rotation
function CSL.UIManager:DeleteRotation()
    if InCombatLockdown() then
        print("|cFFFF0000Cannot delete rotations while in combat. Try again after combat.|r")
        return
    end

    local frame = self.ManagementFrame
    if not frame or not frame.editorGroup then
        return
    end

    local rotationName = frame.editorGroup.currentRotation
    StaticPopup_Show("CSL_CONFIRM_DELETE", rotationName, nil, rotationName)
end

function CSL.UIManager:RegisterCombatWatcher()
    if self._combatWatcher then
        return
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            CSL.UIManager:OnCombatStart()
        else
            CSL.UIManager:OnCombatEnd()
        end
    end)

    self._combatWatcher = watcher
end

function CSL.UIManager:OnCombatStart()
    local frame = self.ManagementFrame
    if not frame or not frame.frame or not frame.frame:IsShown() then
        return
    end

    frame._restoreAfterCombat = true
    if frame.escFrame and frame.escFrame:IsShown() then
        frame.escFrame:Hide()
    end
    frame:Hide()
    print("|cFFFFD700CastSequenceLite hidden during combat. It will return after combat ends.|r")
end

function CSL.UIManager:OnCombatEnd()
    -- Reset rotation steps for rotations with resetAfterCombat enabled
    for _, rotation in pairs(CSL.Rotations) do
        if rotation.resetAfterCombat and rotation.button then
            rotation.button:SetAttribute("step", 1)
            -- Update macro for next click
            CSL:CreateOrUpdateMacro(rotation)
        end
    end

    local frame = self.ManagementFrame
    if not frame or not frame._restoreAfterCombat then
        return
    end

    frame._restoreAfterCombat = nil
    frame:Show()
    if frame.escFrame then
        frame.escFrame:Show()
    end

    self:RefreshRotationList()
    if frame.activeRotation then
        self:SetActiveRotationRow(frame.activeRotation)
    end
end

-- Toggle management frame
function CSL.UIManager:ToggleManagementFrame()
    local frame = self:CreateManagementFrame()
    if frame.frame:IsShown() then
        frame:Hide()
        if frame.escFrame and frame.escFrame:IsShown() then
            frame.escFrame:Hide()
        end
        return
    end

    self:RefreshRotationList()
    if frame.escFrame then
        frame.escFrame:Show()
    end
    frame:Show()

    -- Always default to the new rotation form when opening the manager
    self:ShowRotationEditor(nil)
end
