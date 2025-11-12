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

-- Runtime state for all rotations (keyed by rotation name)
CSL.Rotations = {}

-- Saved variable namespace (per-character database populated at runtime)
CSL.DB = nil

-- Simplified rotation config copying
local function CopyRotationConfig(rotationConfig)
    if not rotationConfig then
        return {}
    end

    return {
        preCastCommands = rotationConfig.preCastCommands and { unpack(rotationConfig.preCastCommands) } or {},
        castCommands = rotationConfig.castCommands and { unpack(rotationConfig.castCommands) } or {},
        resetAfterCombat = rotationConfig.resetAfterCombat or false
    }
end

function CSL:GetDatabase()
    if not self.DB then
        CastSequenceLiteDB = CastSequenceLiteDB or { rotations = {} }
        CastSequenceLiteDB.rotations = CastSequenceLiteDB.rotations or {}
        self.DB = CastSequenceLiteDB
    end

    return self.DB
end

-- Initialize a single rotation from defaults
function CSL:InitializeRotation(rotationName, rotationConfig)
    local rotation = {
        name = rotationName,
        preCastCommands = rotationConfig.preCastCommands and { unpack(rotationConfig.preCastCommands) } or {},
        castCommands = { unpack(rotationConfig.castCommands) },
        currentStep = 1,
        resetAfterCombat = rotationConfig.resetAfterCombat or false
    }

    -- Precompute spell names for caching
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

    -- Cleanup button
    if rotation.button then
        rotation.button:Hide()
        rotation.button:SetParent(nil)
    end

    -- Remove from tables
    self.Rotations[rotationName] = nil
    self:GetDatabase().rotations[rotationName] = nil
end

-- Initialize the addon
function CSL:Initialize()
    local db = self:GetDatabase()

    -- Initialize all rotations and create UI elements
    for rotationName, rotationConfig in pairs(db.rotations) do
        local rotation = self:InitializeRotation(rotationName, rotationConfig)
        self:CreateOrUpdateMacro(rotation)
        self:CreateButton(rotation)
    end

    self:RegisterSlashCommands()
    CSL.UIManager:RegisterCombatWatcher()
    self:PrintWelcome()
end

function CSL:SaveRotationConfig(rotationName, rotationConfig)
    local db = self:GetDatabase()
    db.rotations[rotationName] = CopyRotationConfig(rotationConfig)
end

-- Create the main sequence button
function CSL:CreateButton(rotation)
    local macroName = "CSL_" .. rotation.name
    local button = CreateFrame("Button", "CSLButton_" .. rotation.name, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    button:Hide()

    -- Store references
    button.rotationName = rotation.name
    button.macroName = macroName

    -- Configure button
    button:SetAttribute("type", "macro")
    button:SetAttribute("step", 1)
    button:SetAttribute("numCastCommands", #rotation.castCommands)
    button:SetAttribute("macrotext", self:BuildMacroText(rotation))

    -- Setup handlers and attributes
    self:UpdateButtonAttributes(rotation, button)
    self:SetupSecureClickHandler(rotation, button)

    button:SetScript("PostClick", function(self)
        CSL:UpdateMacroSpell(self)
    end)

    rotation.button = button
    CSL:UpdateMacroSpell(button)

    return button
end

-- Update button attributes for current rotation
function CSL:UpdateButtonAttributes(rotation, button)
    if not button then
        return
    end

    button:SetAttribute("numCastCommands", #rotation.castCommands)
    for i, castCommand in ipairs(rotation.castCommands) do
        button:SetAttribute("castCommand" .. i, castCommand)
        button:SetAttribute("spellName" .. i, CSL.Helpers.GetSpellName(castCommand))
    end
end

-- Set up the secure click handler
function CSL:SetupSecureClickHandler(rotation, button)
    if not button then
        return
    end

    local template = self:GetMacroTextTemplate(rotation)
    local secureCode = string.format([[
        local step = self:GetAttribute('step') or 1
        local numCastCommands = self:GetAttribute('numCastCommands') or 1
        
        local castCommand = self:GetAttribute('castCommand' .. step)
        if castCommand then
            self:SetAttribute('macrotext', "%s")
        end
        
        -- Increment step for NEXT click
        step = step + 1
        if step > numCastCommands then
            step = 1
        end
        self:SetAttribute('step', step)
    ]], template)

    button:WrapScript(button, "OnClick", secureCode)
end

-- Build macro text for a spell  
function CSL:BuildMacroText(rotation)
    local text = "#showtooltip"
    for _, preCastCommand in ipairs(rotation.preCastCommands or {}) do
        text = text .. "\n" .. preCastCommand
    end

    return text .. "\n/click CSLButton_" .. rotation.name
end

-- Get macro text template for secure handler
function CSL:GetMacroTextTemplate(rotation)
    local template = "#showtooltip"
    for _, preCastCommand in ipairs(rotation.preCastCommands or {}) do
        template = template .. "\\n" .. preCastCommand
    end

    return template .. "\\n\" .. castCommand .. \""
end

-- Update macro spell icon (combat-safe)
function CSL:UpdateMacroSpell(button)
    if not button or not button.rotationName then
        return
    end

    local rotation = self.Rotations[button.rotationName]
    if not rotation then
        return
    end

    local currentStep = button:GetAttribute("step") or 1
    local currentCastCommand = button:GetAttribute("castCommand" .. currentStep)

    if currentCastCommand then
        SetMacroSpell(button.macroName, CSL.Helpers.GetSpellName(currentCastCommand))
    end
end

-- Create or update the macro
function CSL:CreateOrUpdateMacro(rotation)
    local macroName = "CSL_" .. rotation.name
    local macroIndex = GetMacroIndexByName(macroName)
    local macroBody = self:BuildMacroText(rotation)

    if macroIndex == 0 then
        local _, numCharacterMacros = GetNumMacros()
        if numCharacterMacros < self.MAX_CHARACTER_MACROS then
            CreateMacro(macroName, 1, macroBody, 1)
        else
            print("|cFFFF0000Too many macros! Delete some and /reload|r")
        end
    else
        EditMacro(macroIndex, nil, nil, macroBody)
    end

    if rotation.button then
        self:UpdateMacroSpell(rotation.button)
    end
end

-- Register slash commands
function CSL:RegisterSlashCommands()
    SLASH_CASTSEQLITE1 = "/csl"
    SlashCmdList["CASTSEQLITE"] = function(msg)
        if InCombatLockdown() then
            print("|cFFFF0000Cannot open during combat|r")
            return
        end
        CSL.UIManager:ToggleManagementFrame()
    end
end

-- Print welcome message (only once)
function CSL:PrintWelcome()
    if not self.welcomeShown then
        print("|cFF00FF00CastSequenceLite v" .. self.VERSION .. " loaded!|r Type /csl to open")
        self.welcomeShown = true
    end
end

-- Event frame setup
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CSL:Initialize()
    end
end)