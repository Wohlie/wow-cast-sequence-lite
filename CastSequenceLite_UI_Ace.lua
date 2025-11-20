local addonName, CSL = ...

CSL.UIManager = CSL.UIManager or {}

-- Dependencies
local AceGUI = LibStub("AceGUI-3.0")

local ERROR_SOUND_ID = "igQuestFailed"
local ESC_FRAME_NAME = "CSLManagementFrame"

StaticPopupDialogs["CSL_CONFIRM_DELETE"] = {
    text = CSL.L["Are you sure you want to delete the rotation '%s'?"],
    button1 = CSL.L["Yes"],
    button2 = CSL.L["No"],
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

--- Set an error message for a specific editor field
-- @param editorGroup The editor group widget
-- @param field The field name (name, preCast, or commands)
-- @param message The error message to display
function CSL.UIManager:SetEditorError(editorGroup, field, message)
    if not editorGroup then
        return
    end

    local formatted = message or ""
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

--- Clear all error messages in the editor
-- @param editorGroup The editor group widget
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

--- Find next enabled input widget for tab navigation
-- @param inputWidgets Array of input widgets
-- @param currentWidget The current widget
-- @param reverse Whether to navigate backwards (Shift+Tab)
-- @return The next enabled widget, or nil if none found
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

--- Ensure a row frame has the proper backdrop
-- @param rowFrame The row frame to style
function CSL.UIManager:EnsureRowBackdrop(rowFrame)
    if not rowFrame or rowFrame:GetBackdrop() then
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
end

--- Set the active rotation row highlight
-- @param rotationName The name of the active rotation, or nil for none
function CSL.UIManager:SetActiveRotationRow(rotationName)
    local frame = self.ManagementFrame
    if not frame or not frame.rotationRows then
        return
    end

    local colors = CSL.COLORS
    for name, rowData in pairs(frame.rotationRows) do
        local rowFrame = rowData.group and rowData.group.frame
        if rowFrame then
            local isActive = rotationName and name == rotationName
            if isActive then
                -- Only apply backdrop when row is active
                self:EnsureRowBackdrop(rowFrame)
                local bg = colors.ACTIVE_BG
                local border = colors.ACTIVE_BORDER

                rowFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
                rowFrame:SetBackdropBorderColor(border.r, border.g, border.b)
            else
                -- Remove backdrop when row is not active
                rowFrame:SetBackdrop(nil)
            end

            -- Also ensure dragContainer doesn't have a backdrop
            if rowData.dragContainer and rowData.dragContainer.frame then
                rowData.dragContainer.frame:SetBackdrop(nil)
            end
        end
    end
end

--- Create the main rotation management frame
-- @return The management frame widget
function CSL.UIManager:CreateManagementFrame()
    if self.ManagementFrame then
        return self.ManagementFrame
    end

    local ui = CSL.UI
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(CSL.L["CastSequenceLite - Rotation Manager"])
    frame:SetLayout("Fill")
    frame:SetWidth(ui.FRAME_WIDTH)
    frame:SetHeight(ui.FRAME_HEIGHT)

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

    -- Create ESC frame for proper ESC key handling
    local escFrame = self:CreateESCFrame(frame)
    frame.escFrame = escFrame

    -- Create main container and panels
    local mainContainer = self:CreateMainContainer()
    frame:AddChild(mainContainer)

    local leftGroup = self:CreateLeftPanel()
    mainContainer:AddChild(leftGroup)

    local leftScroll = self:CreateLeftScrollPanel()
    leftGroup:AddChild(leftScroll)
    frame.leftScroll = leftScroll

    self:AddNewRotationButton(leftScroll)

    local rightGroup = self:CreateRightPanel()
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

--- Create ESC frame for proper ESC key handling
-- @param frame The main frame
-- @return The ESC frame
function CSL.UIManager:CreateESCFrame(frame)
    local escFrame = _G[ESC_FRAME_NAME]
    if not escFrame then
        escFrame = CreateFrame("Frame", ESC_FRAME_NAME, UIParent)
        escFrame:Hide()
        escFrame:SetFrameStrata("DIALOG")
        escFrame:SetToplevel(true)
        table.insert(UISpecialFrames, ESC_FRAME_NAME)
    end

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

    return escFrame
end

--- Create the main container with horizontal layout
-- @return The main container widget
function CSL.UIManager:CreateMainContainer()
    local mainContainer = AceGUI:Create("SimpleGroup")
    mainContainer:SetFullWidth(true)
    mainContainer:SetFullHeight(true)
    mainContainer:SetLayout("Flow")
    return mainContainer
end

--- Create the left panel for rotation list
-- @return The left panel widget
function CSL.UIManager:CreateLeftPanel()
    local ui = CSL.UI
    local leftGroup = AceGUI:Create("InlineGroup")
    leftGroup:SetTitle(CSL.L["Rotations"])
    leftGroup:SetLayout("Fill")
    leftGroup:SetRelativeWidth(ui.LEFT_PANEL_WIDTH_RATIO)
    leftGroup:SetFullHeight(true)
    return leftGroup
end

--- Create the left scroll panel
-- @return The scroll frame widget
function CSL.UIManager:CreateLeftScrollPanel()
    local leftScroll = AceGUI:Create("ScrollFrame")
    leftScroll:SetLayout("List")
    leftScroll:SetFullWidth(true)
    leftScroll:SetFullHeight(true)
    return leftScroll
end

--- Add the new rotation button to the left panel
-- @param parent The parent widget
function CSL.UIManager:AddNewRotationButton(parent)
    local newBtn = AceGUI:Create("Button")
    newBtn:SetText(CSL.L["+ New Rotation"])
    newBtn:SetFullWidth(true)
    newBtn:SetCallback("OnClick", function()
        CSL.UIManager:ShowRotationEditor(nil)
    end)
    parent:AddChild(newBtn)
end

--- Create the right panel for rotation editor
-- @return The right panel widget
function CSL.UIManager:CreateRightPanel()
    local ui = CSL.UI
    local rightGroup = AceGUI:Create("InlineGroup")
    rightGroup:SetTitle(CSL.L["Rotation Editor"])
    rightGroup:SetLayout("Fill")
    rightGroup:SetFullWidth(true)
    rightGroup:SetRelativeWidth(ui.RIGHT_PANEL_WIDTH_RATIO)
    rightGroup:SetFullHeight(true)
    return rightGroup
end

--- Refresh the rotation list in the left panel
function CSL.UIManager:RefreshRotationList()
    local frame = self.ManagementFrame
    if not frame or not frame.leftScroll then
        return
    end

    -- Clear all backdrops from existing rows before releasing them
    if frame.rotationRows then
        for name, rowData in pairs(frame.rotationRows) do
            if rowData.group and rowData.group.frame then
                rowData.group.frame:SetBackdrop(nil)
            end
            if rowData.dragContainer and rowData.dragContainer.frame then
                rowData.dragContainer.frame:SetBackdrop(nil)
            end
        end
    end

    local leftScroll = frame.leftScroll
    leftScroll:ReleaseChildren()
    frame.rotationRows = {}

    -- Re-add new button
    self:AddNewRotationButton(leftScroll)

    -- Add rotation rows sorted
    local rotationNames = self:GetSortedRotationNames()
    for _, rotationName in ipairs(rotationNames) do
        self:AddRotationListRow(leftScroll, rotationName)
    end

    self:SetActiveRotationRow(frame.activeRotation)
end

--- Get sorted list of rotation names
-- @return Array of rotation names sorted alphabetically
function CSL.UIManager:GetSortedRotationNames()
    local rotationNames = {}
    for rotationName in pairs(CSL.Rotations) do
        table.insert(rotationNames, rotationName)
    end
    table.sort(rotationNames)
    return rotationNames
end

-- Show rotation editor
function CSL.UIManager:ShowRotationEditor(rotationName)
    local frame = self.ManagementFrame
    if not frame or not frame.editorGroup then
        return
    end

    local editorGroup = frame.editorGroup
    editorGroup:ReleaseChildren()

    -- Clean up any existing button group from previous editor session
    if frame.buttonGroup and frame.buttonGroup.frame then
        frame.buttonGroup:ReleaseChildren()
        if frame.buttonGroup.frame:GetParent() then
            frame.buttonGroup.frame:Hide()
            frame.buttonGroup.frame:SetParent(nil)
        end
        AceGUI:Release(frame.buttonGroup)
        frame.buttonGroup = nil
    end

    -- Use Fill layout - we'll manually position buttons over the scroll area
    editorGroup:SetLayout("Fill")

    -- Create inner container for scrollable content (takes full space)
    local editorContainer = AceGUI:Create("SimpleGroup")
    editorContainer:SetLayout("Fill")
    editorContainer:SetFullWidth(true)
    editorContainer:SetFullHeight(true)
    editorGroup:AddChild(editorContainer)

    -- Create button group (fixed at bottom, always visible) - manually positioned
    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetFullWidth(true)
    buttonGroup:SetLayout("Flow")
    buttonGroup:SetHeight(35)  -- Fixed height for buttons
    buttonGroup:SetAutoAdjustHeight(false)  -- Don't auto-adjust, keep fixed height
    -- Don't add to editorGroup - we'll manually position it
    frame.buttonGroup = buttonGroup  -- Store reference for cleanup

    -- Manually position button group at bottom and constrain editorContainer
    local function adjustLayout()
        if editorGroup.content and editorContainer.frame and buttonGroup.frame then
            local contentHeight = editorGroup.content:GetHeight()
            local buttonHeight = 35  -- Fixed button group height

            -- Position button group at bottom of editorGroup content (not as a child)
            buttonGroup.frame:SetParent(editorGroup.content)
            buttonGroup.frame:ClearAllPoints()
            buttonGroup.frame:SetPoint("BOTTOMLEFT", editorGroup.content, "BOTTOMLEFT", 0, 0)
            buttonGroup.frame:SetPoint("BOTTOMRIGHT", editorGroup.content, "BOTTOMRIGHT", 0, 0)
            buttonGroup.frame:SetHeight(buttonHeight)
            buttonGroup.frame:SetFrameLevel(editorGroup.content:GetFrameLevel() + 10)
            buttonGroup.frame:Show()

            -- Also ensure content frame is properly sized
            if buttonGroup.content then
                buttonGroup.content:SetHeight(buttonHeight)
            end

            -- Constrain editorContainer to leave space for buttons
            editorContainer.frame:ClearAllPoints()
            editorContainer.frame:SetPoint("TOPLEFT", editorGroup.content, "TOPLEFT", 0, 0)
            editorContainer.frame:SetPoint("TOPRIGHT", editorGroup.content, "TOPRIGHT", 0, 0)
            editorContainer.frame:SetPoint("BOTTOMLEFT", editorGroup.content, "BOTTOMLEFT", 0, buttonHeight)
            editorContainer.frame:SetPoint("BOTTOMRIGHT", editorGroup.content, "BOTTOMRIGHT", 0, buttonHeight)
        end
    end

    -- Hook into editorGroup content frame resize
    if editorGroup.content then
        editorGroup.content:SetScript("OnSizeChanged", adjustLayout)
    end

    -- Also adjust after layout completes
    local adjustFrame = CreateFrame("Frame")
    adjustFrame:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)  -- Run only once
        adjustLayout()
    end)

    -- Create editor scroll container inside the container
    local editorScroll = AceGUI:Create("ScrollFrame")
    editorScroll:SetLayout("Flow")
    editorScroll:SetFullWidth(true)
    editorScroll:SetFullHeight(true)
    editorContainer:AddChild(editorScroll)

    -- Name input
    local nameInput = AceGUI:Create("EditBox")
    nameInput:SetLabel(CSL.L["Rotation Name:"])
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
    preCastInput:SetLabel(CSL.L["Pre-Cast Commands (optional, one per line):"])
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
    commandsInput:SetLabel(CSL.L["Cast Commands (one per line):"])
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
    resetAfterCombatCheckbox:SetLabel(CSL.L["Reset to first step after combat"])
    resetAfterCombatCheckbox:SetValue(false)
    resetAfterCombatCheckbox:SetFullWidth(true)
    editorScroll:AddChild(resetAfterCombatCheckbox)

    -- Auto select target dropdown
    local autoSelectDropdown = AceGUI:Create("Dropdown")
    autoSelectDropdown:SetLabel(CSL.L["Auto select next target"])
    autoSelectDropdown:SetList({
        ["always"] = CSL.L["Always"],
        ["combat"] = CSL.L["In Combat"],
        ["never"] = CSL.L["Never"]
    })
    autoSelectDropdown:SetValue("combat") -- Default
    autoSelectDropdown:SetFullWidth(true)
    editorScroll:AddChild(autoSelectDropdown)

    local resetSpacer = AceGUI:Create("Label")
    resetSpacer:SetFullWidth(true)
    resetSpacer:SetText(" ")
    editorScroll:AddChild(resetSpacer)

    -- Clear button group before adding buttons (in case of any leftover children)
    buttonGroup:ReleaseChildren()

    -- Save button
    local saveBtn = AceGUI:Create("Button")
    saveBtn:SetText(CSL.L["Save"])
    saveBtn:SetWidth(100)
    saveBtn:SetCallback("OnClick", function()
        CSL.UIManager:SaveRotation(nameInput, preCastInput, commandsInput, resetAfterCombatCheckbox, autoSelectDropdown)
    end)
    buttonGroup:AddChild(saveBtn)

    -- Cancel button
    local cancelBtn = AceGUI:Create("Button")
    cancelBtn:SetText(CSL.L["Cancel"])
    cancelBtn:SetWidth(100)
    cancelBtn:SetCallback("OnClick", function()
        CSL.UIManager:ShowRotationEditor(nil)
    end)
    buttonGroup:AddChild(cancelBtn)

    -- Delete button (only for existing rotations)
    if rotationName then
        local deleteBtn = AceGUI:Create("Button")
        deleteBtn:SetText(CSL.L["Delete"])
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
        resetAfterCombat = resetAfterCombatCheckbox,
        autoSelect = autoSelectDropdown
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
    editorGroup.autoSelectDropdown = autoSelectDropdown
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
        autoSelectDropdown:SetValue(rotation.autoSelectTarget or "combat")
        if editorGroup.buttonContainer then
            self:UpdateButtonPreview(rotationName, editorGroup.buttonContainer)
        end
    else
        nameInput:SetText("")
        nameInput:SetDisabled(false)
        preCastInput:SetText("")
        commandsInput:SetText("")
        resetAfterCombatCheckbox:SetValue(false)
        autoSelectDropdown:SetValue("combat")
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
        local macroIdx = GetMacroIndexByName(rotationName)
        if not macroIdx or macroIdx == 0 then
            CSL:CreateOrUpdateMacro(rotation)
            macroIdx = GetMacroIndexByName(rotationName)
        end

        if macroIdx and macroIdx > 0 then
            PickupMacro(macroIdx)
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(string.format(CSL.L["Drag to place '%s' on your action bar"], rotationName), 1, 1, 1, true)
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
        local macroIdx = GetMacroIndexByName(rotationName)
        if not macroIdx or macroIdx == 0 then
            CSL:CreateOrUpdateMacro(rotation)
            macroIdx = GetMacroIndexByName(rotationName)
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

--- Validate rotation name
-- @param rotationName The rotation name to validate
-- @param editorGroup The editor group for error display
-- @param isNewRotation Whether this is a new rotation (for duplicate checking)
-- @return true if valid, false otherwise
function CSL.UIManager:ValidateRotationName(rotationName, editorGroup, isNewRotation)
    if rotationName == "" then
        self:SetEditorError(editorGroup, "name", CSL.L["Rotation name cannot be empty."])
        return false
    end

    -- Check for invalid characters (only a-z, A-Z, 0-9, _, and - are allowed)
    if rotationName:match("[^a-zA-Z0-9_%-]") then
        self:SetEditorError(editorGroup, "name", CSL.L["Rotation name can only contain letters, numbers, underscores, and hyphens."])
        return false
    end

    if #rotationName > CSL.MAX_ROTATION_NAME_LENGTH then
        self:SetEditorError(editorGroup, "name",
                string.format(CSL.L["Rotation name must be %d characters or less."], CSL.MAX_ROTATION_NAME_LENGTH))
        return false
    end

    -- Check for duplicate only when creating new (case-insensitive)
    if isNewRotation then
        local existingRotationName = CSL:FindRotationCaseInsensitive(rotationName)
        if existingRotationName then
            self:SetEditorError(editorGroup, "name",
                    string.format(CSL.L["Rotation '%s' already exists."], existingRotationName))
            return false
        end

        -- Check if a macro with this name already exists (manually created by user)
        local macroIndex = GetMacroIndexByName(rotationName)
        if macroIndex > 0 then
            self:SetEditorError(editorGroup, "name",
                    string.format(CSL.L["Macro '%s' already exists. Delete it manually or choose a different name."], rotationName))
            return false
        end
    end

    return true
end

--- Validate cast commands
-- @param castCommands Array of cast commands
-- @param editorGroup The editor group for error display
-- @return true if valid, false otherwise
function CSL.UIManager:ValidateCastCommands(castCommands, editorGroup)
    if #castCommands == 0 then
        self:SetEditorError(editorGroup, "commands", CSL.L["At least one cast command is required."])
        return false
    end
    return true
end

--- Save rotation from editor inputs
-- @param nameInput The name input widget
-- @param preCastInput The pre-cast commands input widget
-- @param commandsInput The cast commands input widget
-- @param resetAfterCombatCheckbox The reset checkbox widget
-- @param autoSelectDropdown The auto select dropdown widget
function CSL.UIManager:SaveRotation(nameInput, preCastInput, commandsInput, resetAfterCombatCheckbox, autoSelectDropdown)
    if InCombatLockdown() then
        print(CSL.COLORS.ERROR .. CSL.L["Cannot save rotations while in combat. Try again after combat."] .. "|r")
        return
    end

    self:RegisterCombatWatcher()

    local rotationName = nameInput:GetText():trim()
    local editorGroup = self.ManagementFrame.editorGroup
    self:ClearEditorErrors(editorGroup)

    -- Validate inputs
    local isNewRotation = not editorGroup.currentRotation
    if not self:ValidateRotationName(rotationName, editorGroup, isNewRotation) then
        return
    end

    local preCastCommands = CSL.Helpers.ParseCommands(preCastInput:GetText())
    local castCommands = CSL.Helpers.ParseCommands(commandsInput:GetText())

    if not self:ValidateCastCommands(castCommands, editorGroup) then
        return
    end

    -- Build rotation configuration
    local rotationConfig = {
        preCastCommands = #preCastCommands > 0 and preCastCommands or nil,
        castCommands = castCommands,
        resetAfterCombat = resetAfterCombatCheckbox:GetValue(),
        autoSelectTarget = autoSelectDropdown:GetValue()
    }

    -- Initialize or update rotation
    local rotation = CSL:InitializeRotation(rotationName, rotationConfig)
    CSL:SaveRotationConfig(rotationName, rotationConfig)

    -- Create or update button
    if not rotation.button then
        CSL:CreateButton(rotation)
    else
        CSL:UpdateButtonAttributes(rotation, rotation.button)
    end

    CSL:CreateOrUpdateMacro(rotation)

    print(CSL.COLORS.SUCCESS .. string.format(CSL.L["Rotation '%s' saved!"], rotationName) .. "|r")

    self:RefreshRotationList()
    self:ShowRotationEditor(rotationName)
end

--- Delete rotation (shows confirmation dialog)
function CSL.UIManager:DeleteRotation()
    if InCombatLockdown() then
        print(CSL.COLORS.ERROR .. CSL.L["Cannot delete rotations while in combat. Try again after combat."] .. "|r")
        return
    end

    local frame = self.ManagementFrame
    if not frame or not frame.editorGroup then
        return
    end

    local rotationName = frame.editorGroup.currentRotation
    if rotationName then
        StaticPopup_Show("CSL_CONFIRM_DELETE", rotationName, nil, rotationName)
    end
end

--- Register combat event watcher
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

--- Handle combat start - hide UI and mark for restoration
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
    print(CSL.COLORS.WARNING .. CSL.L["CastSequenceLite hidden during combat. It will return after combat ends."] .. "|r")
end

--- Handle combat end - reset rotations and restore UI if needed
function CSL.UIManager:OnCombatEnd()
    -- Rotations are reset automatically by the event handler in CastSequenceLite.lua

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

--- Toggle the management frame visibility
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
