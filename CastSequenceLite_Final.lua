-- CastSequenceLite
-- A lightweight, combat-safe cast sequence addon
-- Inspired by GSE but simplified for basic rotations

-- Create addon namespace and configuration
local addonName, CSL = ...
_G["CastSequenceLite"] = CSL

-- Constants
CSL.VERSION = "1.0.0"
CSL.MACRO_NAME = "CastSeqLite"
CSL.MAX_CHARACTER_MACROS = MAX_CHARACTER_MACROS or 18
CSL.MAX_ACCOUNT_MACROS = MAX_ACCOUNT_MACROS or 120

-- Default configuration
CSL.Config = {
    buttonSize = 36,
    initialPosition = { "CENTER", UIParent, "CENTER", 0, 0 },
    showButton = true,
    defaultIcon = "Interface\\Icons\\INV_Misc_QuestionMark",
    buttonFrameStrata = "MEDIUM",
}

-- Default cast command rotation (can be replaced via slash commands)
CSL.DefaultRotation = {
    preCastCommand = "/startattack", -- Command executed before each spell cast
    castCommands = {
        "/cast Sturmangriff",
        "/cast Siegesrausch",
        "/cast Verwunden",
        "/cast Heldenhafter Stoß"
    }
}

-- Active rotation
CSL.ActiveRotation = {
    preCastCommand = nil,
    castCommands = {},
    icons = {},
    spellNames = {}
}

-- Store addon frame elements
CSL.UI = {}

-- Cache and return the spell name extracted from a cast command
function CSL:GetSpellName(castCommand)
    if not castCommand then
        return ""
    end

    local cachedName = self.ActiveRotation.spellNames[castCommand]
    if cachedName ~= nil then
        return cachedName
    end

    local spellName = CSL.Helpers.ExtractSpellName(castCommand)
    self.ActiveRotation.spellNames[castCommand] = spellName
    return spellName
end

-- Resolve an icon texture for the given cast command
function CSL:GetIconForSpell(castCommand)
    local spellName = self:GetSpellName(castCommand)
    if spellName == "" then
        return self.Config.defaultIcon
    end

    local _, _, iconTexture = GetSpellInfo(spellName)
    if iconTexture then
        return iconTexture
    end

    return self.Config.defaultIcon
end

-- Ensure an icon is cached for the spell command and return it
function CSL:EnsureIcon(castCommand)
    if not castCommand then
        return self.Config.defaultIcon
    end

    local icon = self.ActiveRotation.icons[castCommand]
    if not icon then
        icon = self:GetIconForSpell(castCommand)
        self.ActiveRotation.icons[castCommand] = icon
    end

    return icon
end

-- Initialize the addon
function CSL:Initialize()
    -- Copy default rotation to active rotation
    for i, castCommand in ipairs(self.DefaultRotation.castCommands) do
        table.insert(self.ActiveRotation.castCommands, castCommand)
    end

    for _, castCommand in ipairs(self.ActiveRotation.castCommands) do
        self:EnsureIcon(castCommand)
    end

    -- Copy preCastCommand if defined
    if self.DefaultRotation.preCastCommand then
        self.ActiveRotation.preCastCommand = self.DefaultRotation.preCastCommand
    end

    -- Create UI elements
    self:CreateButton()

    -- Create macro
    self:CreateOrUpdateMacro()

    -- Register slash commands
    self:RegisterSlashCommands()

    -- Print welcome message
    self:PrintWelcome()
end

-- Create the main sequence button
function CSL:CreateButton()
    -- Create button with secure templates
    local btn = CreateFrame("Button", "CSLButton", UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    btn:SetSize(self.Config.buttonSize, self.Config.buttonSize)
    btn:SetPoint(unpack(self.Config.initialPosition))
    btn:SetFrameStrata(self.Config.buttonFrameStrata)

    -- Make button draggable
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        local macroIdx = GetMacroIndexByName(CSL.MACRO_NAME)
        if macroIdx and macroIdx > 0 then
            PickupMacro(macroIdx)
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        ClearCursor()
    end)

    -- Create icon texture
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(btn)
    icon:SetTexture(self.Config.defaultIcon)
    btn.icon = icon

    -- Set as macro button
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("step", 1)
    btn:SetAttribute("numCastCommands", #self.ActiveRotation.castCommands)

    -- Set initial macrotext
    local initialCastCommand = self.ActiveRotation.castCommands[1]
    local initialMacroText = self:BuildMacroText(initialCastCommand)
    btn:SetAttribute("macrotext", initialMacroText)

    -- Store spell and icon attributes
    self:UpdateButtonAttributes(btn)

    -- Add secure click handler
    self:SetupSecureClickHandler(btn)

    -- Add PostClick handler
    btn:SetScript("PostClick", function(self)
        CSL:UpdateButtonIcon(self)
        CSL:UpdateMacroSpell(self)
    end)

    -- Set initial icon
    if #self.ActiveRotation.castCommands > 0 then
        local initialCastCommand = self.ActiveRotation.castCommands[1]
        icon:SetTexture(self:EnsureIcon(initialCastCommand))
    end

    -- Add button visuals
    btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    -- Store in UI table
    self.UI.Button = btn

    -- Initial rendering
    CSL:UpdateButtonIcon(btn)
    CSL:UpdateMacroSpell(btn)

    -- Show/hide based on config
    if not self.Config.showButton then
        btn:Hide()
    end

    return btn
end

-- Update button attributes for current rotation
function CSL:UpdateButtonAttributes(btn)
    local button = btn or self.UI.Button
    if not button then
        return
    end

    button:SetAttribute("numCastCommands", #self.ActiveRotation.castCommands)

    for i, castCommand in ipairs(self.ActiveRotation.castCommands) do
        local icon = self:EnsureIcon(castCommand)
        button:SetAttribute("castCommand" .. i, castCommand)
        button:SetAttribute("spellName" .. i, self:GetSpellName(castCommand) or "")
        button:SetAttribute("icon" .. i, icon)
    end
end

-- Set up the secure click handler
function CSL:SetupSecureClickHandler(btn)
    local button = btn or self.UI.Button
    if not button then
        return
    end

    local secureCode = [[
        local step = self:GetAttribute('step') or 1
        local numCastCommands = self:GetAttribute('numCastCommands') or 1

        -- Get cast command for THIS click
        local castCommand = self:GetAttribute('castCommand' .. step)
        if castCommand then
            local spellName = self:GetAttribute('spellName' .. step) or ""
            self:SetAttribute('macrotext', "]] .. self:GetMacroTextTemplate() .. [[")
        end

        -- Increment step for NEXT click
        step = step + 1
        if step > numCastCommands then
            step = 1
        end
        self:SetAttribute('step', step)
    ]]

    button:WrapScript(button, "OnClick", secureCode)
end

-- Build macro text for a spell
function CSL:BuildMacroText(castCommand)
    -- Extract spell name from "/cast SpellName" for #showtooltip
    local spellName = self:GetSpellName(castCommand)
    local text = "#showtooltip " .. spellName

    -- Add pre-cast command if defined
    if self.ActiveRotation.preCastCommand and self.ActiveRotation.preCastCommand ~= "" then
        text = text .. "\n" .. self.ActiveRotation.preCastCommand
    end

    text = text .. "\n" .. castCommand
    return text
end

-- Get macro text template for secure handler
function CSL:GetMacroTextTemplate()
    -- Extract spell name from "/cast SpellName" for #showtooltip
    -- Note: In secure code we need to inline the extraction logic
    local template = "#showtooltip \" .. spellName .. \""

    -- Add pre-cast command if defined
    if self.ActiveRotation.preCastCommand and self.ActiveRotation.preCastCommand ~= "" then
        template = template .. "\\n" .. self.ActiveRotation.preCastCommand
    end

    template = template .. "\\n\" .. castCommand .. \""
    return template
end

-- Update button icon
function CSL:UpdateButtonIcon(button)
    local btn = button or self.UI.Button
    if not btn or not btn.icon then
        return
    end

    local nextStep = btn:GetAttribute("step") or 1
    local nextIcon = btn:GetAttribute("icon" .. nextStep)

    if nextIcon then
        btn.icon:SetTexture(nextIcon)
    end
end

-- Update macro spell icon (combat-safe)
function CSL:UpdateMacroSpell(button)
    local btn = button or self.UI.Button
    if not btn then
        return
    end

    local currentStep = btn:GetAttribute("step") or 1
    local currentCastCommand = btn:GetAttribute("castCommand" .. currentStep)

    if currentCastCommand then
        -- SetMacroSpell works even in combat!
        -- Extract spell name from "/cast SpellName"
        local spellName = self:GetSpellName(currentCastCommand)
        SetMacroSpell(self.MACRO_NAME, spellName)
    end
end

-- Create or update the macro
function CSL:CreateOrUpdateMacro()
    local macroIndex = GetMacroIndexByName(self.MACRO_NAME)
    local firstCastCommand = #self.ActiveRotation.castCommands > 0 and self.ActiveRotation.castCommands[1] or nil
    local iconToUse = firstCastCommand and self:EnsureIcon(firstCastCommand) or self.Config.defaultIcon
    local macroBody = "#showtooltip\n/click CSLButton"

    if macroIndex == 0 then
        -- Macro doesn't exist, create it
        local numAccountMacros, numCharacterMacros = GetNumMacros()

        if numCharacterMacros < self.MAX_CHARACTER_MACROS then
            -- Create with the first cast command's icon (1 means character-specific macro)
            CreateMacro(self.MACRO_NAME, iconToUse, macroBody, 1)
            print("|cFF00FF00Macro '" .. self.MACRO_NAME .. "' created!|r")
        else
            print("|cFFFF0000Too many macros! Delete some and /reload|r")
        end
    else
        -- Macro exists, update it with current icon
        EditMacro(macroIndex, nil, iconToUse, macroBody)
    end
end

-- Register slash commands
function CSL:RegisterSlashCommands()
    SLASH_CASTSEQLITE1 = "/csl"
    SLASH_CASTSEQLITE2 = "/castseqlite"

    SlashCmdList["CASTSEQLITE"] = function(msg)
        local cmd, arg = strsplit(" ", msg, 2)
        cmd = cmd:lower()

        if cmd == "macro" or cmd == "" then
            -- Show macro frame and select our macro
            if not MacroFrame or not MacroFrame:IsShown() then
                ShowMacroFrame()
            end

            local macroIdx = GetMacroIndexByName(self.MACRO_NAME)
            if macroIdx > 0 then
                -- Try to select the macro
                if MacroFrame and MacroFrame.MacroSelector then
                    MacroFrame.MacroSelector:SelectMacro(macroIdx)
                end
                print("|cFF00FF00Drag 'CastSeqLite' macro to your action bar!|r")
            end
        elseif cmd == "show" then
            self.Config.showButton = true
            if self.UI.Button then
                self.UI.Button:Show()
            end
            print("|cFF00FF00Button shown|r")
        elseif cmd == "hide" then
            self.Config.showButton = false
            if self.UI.Button then
                self.UI.Button:Hide()
            end
            print("|cFF00FF00Button hidden|r")
        elseif cmd == "help" then
            self:PrintHelp()
        end
    end
end

-- Print help information
function CSL:PrintHelp()
    print("|cFF00FF00CastSequenceLite v" .. self.VERSION .. " commands:|r")
    print("|cFFFFFF00/csl|r - Open macro UI")
    print("|cFFFFFF00/csl show|r - Show button")
    print("|cFFFFFF00/csl hide|r - Hide button")
    print("|cFFFFFF00/csl help|r - Show this help")
end

-- Print welcome message
function CSL:PrintWelcome()
    print("|cFF00FF00" .. addonName .. " v" .. self.VERSION .. " loaded!|r")
    print("|cFFFFD700Current rotation:|r")

    for i, castCommand in ipairs(self.ActiveRotation.castCommands) do
        print("|cFFFFD700  " .. i .. ". " .. castCommand .. "|r")
    end

    print("|cFFFFFF00Type /csl for options or /macro to open macro UI|r")
    print("|cFFFFFF00Find '" .. self.MACRO_NAME .. "' macro and drag it to your action bar!|r")
    print("|cFF00FF00The macro icon will change with each spell in rotation!|r")
end

-- Event frame setup
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CSL:Initialize()
    end
end)