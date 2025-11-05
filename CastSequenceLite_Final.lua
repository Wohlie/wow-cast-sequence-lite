-- CastSequenceLite
-- A lightweight, combat-safe cast sequence addon
-- Inspired by GSE but simplified for basic rotations

-- Create addon namespace and configuration
local addonName, CSL = ...
_G["CastSequenceLite"] = CSL

-- Constants
CSL.VERSION = "1.0.0"
CSL.MACRO_PREFIX = "CSL_"
CSL.MACRO_NAME = "CastSeqLite"
CSL.MAX_MACRO_NAME_LENGTH = 16
CSL.MAX_ROTATION_NAME_LENGTH = CSL.MAX_MACRO_NAME_LENGTH - #CSL.MACRO_PREFIX
CSL.MAX_CHARACTER_MACROS = MAX_CHARACTER_MACROS or 18
CSL.MAX_ACCOUNT_MACROS = MAX_ACCOUNT_MACROS or 120

-- Default configuration
CSL.Config = {
    buttonSize = 36,
    initialPosition = { "CENTER", UIParent, "CENTER", 0, 0 },
    showButton = true,
    buttonFrameStrata = "MEDIUM",
    macroIconIndex = 1,
}

-- Default cast command rotations (can be replaced via slash commands)
CSL.DefaultRotations = {
    ["Warrior"] = {
        preCastCommand = "/startattack",
        castCommands = {
            "/cast Sturmangriff",
            "/cast Siegesrausch",
            "/cast Verwunden",
            "/cast Heldenhafter Stoß"
        }
    },
    ["WarriorAoE"] = {
        preCastCommand = "/startattack",
        castCommands = {
            "/cast Donnerknall",
            "/cast Wirbelwind",
            "/cast Spalten"
        }
    }
}

-- Runtime state for all rotations (keyed by rotation name)
CSL.Rotations = {}

CSL.UI = {}

-- Initialize a single rotation from defaults
function CSL:InitializeRotation(rotationName, rotationConfig)
    local rotation = {
        name = rotationName,
        preCastCommand = rotationConfig.preCastCommand,
        castCommands = {},
        currentStep = 1
    }

    -- Copy cast commands
    for i, castCommand in ipairs(rotationConfig.castCommands) do
        table.insert(rotation.castCommands, castCommand)
    end

    -- Precompute spell names (icons resolved via helper cache)
    for _, castCommand in ipairs(rotation.castCommands) do
        CSL.Helpers.GetSpellName(castCommand)
    end

    self.Rotations[rotationName] = rotation
    return rotation
end

-- Delete a rotation
function CSL:DeleteRotation(rotationName)
    local rotation = self.Rotations[rotationName]
    if not rotation then
        return
    end

    -- Delete macro
    local macroName = "CSL_" .. rotationName
    local macroIndex = GetMacroIndexByName(macroName)
    if macroIndex > 0 then
        DeleteMacro(macroIndex)
        print("|cFF00FF00Macro '" .. macroName .. "' deleted!|r")
    end

    -- Hide and cleanup button
    if rotation.button then
        rotation.button:Hide()
        rotation.button:SetParent(nil)
    end

    -- Remove from rotations table
    self.Rotations[rotationName] = nil
end

-- Initialize the addon
function CSL:Initialize()
    -- Initialize all default rotations
    for rotationName, rotationConfig in pairs(self.DefaultRotations) do
        self:InitializeRotation(rotationName, rotationConfig)
    end

    -- Create UI elements and macros for each rotation
    for rotationName, rotation in pairs(self.Rotations) do
        self:CreateButton(rotation)
        self:CreateOrUpdateMacro(rotation)
    end

    -- Register slash commands
    self:RegisterSlashCommands()

    -- Print welcome message
    self:PrintWelcome()
end

-- Create the main sequence button
function CSL:CreateButton(rotation)
    local buttonName = "CSLButton_" .. rotation.name
    local macroName = "CSL_" .. rotation.name

    -- Create button with secure templates
    local btn = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    btn:SetSize(self.Config.buttonSize, self.Config.buttonSize)
    btn:SetPoint(unpack(self.Config.initialPosition))
    btn:SetFrameStrata(self.Config.buttonFrameStrata)

    -- Store rotation reference on button
    btn.rotationName = rotation.name
    btn.macroName = macroName

    -- Make button draggable
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        local macroIdx = GetMacroIndexByName(self.macroName)
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
    icon:SetTexture(CSL.Helpers.DEFAULT_ICON)
    btn.icon = icon

    -- Set as macro button
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("step", 1)
    btn:SetAttribute("numCastCommands", #rotation.castCommands)

    -- Set initial macrotext
    local initialCastCommand = rotation.castCommands[1]
    local initialMacroText = self:BuildMacroText(rotation, initialCastCommand)
    btn:SetAttribute("macrotext", initialMacroText)

    -- Store spell and icon attributes
    self:UpdateButtonAttributes(rotation, btn)

    -- Add secure click handler
    self:SetupSecureClickHandler(rotation, btn)

    -- Add PostClick handler
    btn:SetScript("PostClick", function(self)
        CSL:UpdateButtonIcon(self)
        CSL:UpdateMacroSpell(self)
    end)

    -- Set initial icon
    if #rotation.castCommands > 0 then
        local initialCastCommand = rotation.castCommands[1]
        icon:SetTexture(CSL.Helpers.GetIconForSpell(initialCastCommand))
    end

    -- Add button visuals
    btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    -- Store in UI table
    rotation.button = btn

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
function CSL:UpdateButtonAttributes(rotation, btn)
    local button = btn
    if not button then
        return
    end

    button:SetAttribute("numCastCommands", #rotation.castCommands)

    for i, castCommand in ipairs(rotation.castCommands) do
        local icon = CSL.Helpers.GetIconForSpell(castCommand)
        button:SetAttribute("castCommand" .. i, castCommand)
        button:SetAttribute("spellName" .. i, CSL.Helpers.GetSpellName(castCommand) or "")
        button:SetAttribute("icon" .. i, icon)
    end
end

-- Set up the secure click handler
function CSL:SetupSecureClickHandler(rotation, btn)
    local button = btn
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
            self:SetAttribute('macrotext', "]] .. self:GetMacroTextTemplate(rotation) .. [[")
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
function CSL:BuildMacroText(rotation, castCommand)
    -- Extract spell name from "/cast SpellName" for #showtooltip
    local spellName = CSL.Helpers.GetSpellName(castCommand)
    local text = "#showtooltip " .. spellName

    -- Add pre-cast command if defined
    if rotation.preCastCommand and rotation.preCastCommand ~= "" then
        text = text .. "\n" .. rotation.preCastCommand
    end

    text = text .. "\n" .. castCommand
    return text
end

-- Get macro text template for secure handler
function CSL:GetMacroTextTemplate(rotation)
    -- Extract spell name from "/cast SpellName" for #showtooltip
    -- Note: In secure code we need to inline the extraction logic
    local template = "#showtooltip \" .. spellName .. \""

    -- Add pre-cast command if defined
    if rotation.preCastCommand and rotation.preCastCommand ~= "" then
        template = template .. "\\n" .. rotation.preCastCommand
    end

    template = template .. "\\n\" .. castCommand .. \""
    return template
end

-- Update button icon
function CSL:UpdateButtonIcon(button)
    local btn = button
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
    local btn = button
    if not btn or not btn.rotationName then
        return
    end

    local rotation = self.Rotations[btn.rotationName]
    if not rotation then
        return
    end

    local currentStep = btn:GetAttribute("step") or 1
    local currentCastCommand = btn:GetAttribute("castCommand" .. currentStep)

    if currentCastCommand then
        -- SetMacroSpell works even in combat!
        -- Extract spell name from "/cast SpellName"
        local spellName = CSL.Helpers.GetSpellName(currentCastCommand)
        SetMacroSpell(btn.macroName, spellName)
    end
end

-- Create or update the macro
function CSL:CreateOrUpdateMacro(rotation)
    local macroName = "CSL_" .. rotation.name
    local buttonName = "CSLButton_" .. rotation.name
    local macroIndex = GetMacroIndexByName(macroName)
    local macroIconIndex = self.Config.macroIconIndex or 1
    local macroBody = "#showtooltip\n/click " .. buttonName

    if macroIndex == 0 then
        -- Macro doesn't exist, create it
        local numAccountMacros, numCharacterMacros = GetNumMacros()

        if numCharacterMacros < self.MAX_CHARACTER_MACROS then
            -- Create with the first cast command's icon (1 means character-specific macro)
            CreateMacro(macroName, macroIconIndex, macroBody, 1)
            print("|cFF00FF00Macro '" .. macroName .. "' created!|r")
        else
            print("|cFFFF0000Too many macros! Delete some and /reload|r")
        end
    else
        -- Macro exists, update it with current icon
        EditMacro(macroIndex, nil, macroIconIndex, macroBody)
    end
end

-- Register slash commands
function CSL:RegisterSlashCommands()
    SLASH_CASTSEQLITE1 = "/csl"
    SLASH_CASTSEQLITE2 = "/castseqlite"

    SlashCmdList["CASTSEQLITE"] = function(msg)
        local cmd, arg = strsplit(" ", msg, 2)
        cmd = cmd:lower()

        if cmd == "" or cmd == "ui" then
            if InCombatLockdown() then
                print("|cFFFF0000Cannot open CastSequenceLite while in combat. Try again after combat.|r")
                return
            end
            -- Show management UI
            CSL.UIManager:ToggleManagementFrame()
        elseif cmd == "macro" then
            -- Show macro frame
            if not MacroFrame or not MacroFrame:IsShown() then
                ShowMacroFrame()
            end
            print("|cFF00FF00Drag 'CSL_<RotationName>' macros to your action bar!|r")
        elseif cmd == "show" then
            self.Config.showButton = true
            for rotationName, rotation in pairs(self.Rotations) do
                if rotation.button then
                    rotation.button:Show()
                end
            end
            print("|cFF00FF00All buttons shown|r")
        elseif cmd == "hide" then
            self.Config.showButton = false
            for rotationName, rotation in pairs(self.Rotations) do
                if rotation.button then
                    rotation.button:Hide()
                end
            end
            print("|cFF00FF00All buttons hidden|r")
        elseif cmd == "help" then
            self:PrintHelp()
        end
    end
end

-- Print help information
function CSL:PrintHelp()
    print("|cFF00FF00CastSequenceLite v" .. self.VERSION .. " commands:|r")
    print("|cFFFFFF00/csl|r - Open rotation management UI")
    print("|cFFFFFF00/csl ui|r - Open rotation management UI")
    print("|cFFFFFF00/csl macro|r - Open macro frame")
    print("|cFFFFFF00/csl show|r - Show button")
    print("|cFFFFFF00/csl hide|r - Hide button")
    print("|cFFFFFF00/csl help|r - Show this help")
end

-- Print welcome message
function CSL:PrintWelcome()
    print("|cFF00FF00" .. addonName .. " v" .. self.VERSION .. " loaded!|r")
    print("|cFFFFD700Available rotations:|r")

    for rotationName, rotation in pairs(self.Rotations) do
        print("|cFFFFD700  " .. rotationName .. ":|r")
        for i, castCommand in ipairs(rotation.castCommands) do
            print("|cFFFFD700    " .. i .. ". " .. castCommand .. "|r")
        end
    end

    print("|cFFFFFF00Type /csl for options or /macro to open macro UI|r")
    print("|cFFFFFF00Find 'CSL_<RotationName>' macros and drag them to your action bar!|r")
    print("|cFF00FF00The macro icons will change with each spell in rotation!|r")
end

-- Event frame setup
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CSL:Initialize()
    end
end)