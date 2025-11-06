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

local function CopyRotationConfig(rotationConfig)
    local copy = {
        preCastCommands = {},
        castCommands = {}
    }

    if rotationConfig and rotationConfig.preCastCommands then
        for _, preCastCommand in ipairs(rotationConfig.preCastCommands) do
            table.insert(copy.preCastCommands, preCastCommand)
        end
    end

    if rotationConfig and rotationConfig.castCommands then
        for _, castCommand in ipairs(rotationConfig.castCommands) do
            table.insert(copy.castCommands, castCommand)
        end
    end

    return copy
end

function CSL:GetDatabase()
    if self.DB then
        return self.DB
    end

    CastSequenceLiteDB = CastSequenceLiteDB or {}
    CastSequenceLiteDB.rotations = CastSequenceLiteDB.rotations or {}
    self.DB = CastSequenceLiteDB
    return self.DB
end

-- Initialize a single rotation from defaults
function CSL:InitializeRotation(rotationName, rotationConfig)
    local rotation = {
        name = rotationName,
        preCastCommands = {},
        castCommands = {},
        currentStep = 1
    }

    -- Copy pre-cast commands
    if rotationConfig.preCastCommands then
        for i, preCastCommand in ipairs(rotationConfig.preCastCommands) do
            table.insert(rotation.preCastCommands, preCastCommand)
        end
    end

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

    local db = self:GetDatabase()
    if db.rotations then
        db.rotations[rotationName] = nil
    end
end

-- Initialize the addon
function CSL:Initialize()
    local db = self:GetDatabase()

    -- Initialize all rotations stored for this character
    for rotationName, rotationConfig in pairs(db.rotations) do
        self:InitializeRotation(rotationName, rotationConfig)
    end

    -- Create UI elements and macros for each rotation
    for rotationName, rotation in pairs(self.Rotations) do
        self:CreateOrUpdateMacro(rotation)
        self:CreateButton(rotation)
    end

    -- Register slash commands
    self:RegisterSlashCommands()

    -- Print welcome message
    self:PrintWelcome()
end

function CSL:SaveRotationConfig(rotationName, rotationConfig)
    local db = self:GetDatabase()
    db.rotations[rotationName] = CopyRotationConfig(rotationConfig)
end

-- Create the main sequence button
function CSL:CreateButton(rotation)
    local buttonName = "CSLButton_" .. rotation.name
    local macroName = "CSL_" .. rotation.name

    -- Create button with secure templates
    local button = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    button:Hide()

    -- Store rotation reference on button
    button.rotationName = rotation.name
    button.macroName = macroName

    -- Set as macro button
    button:SetAttribute("type", "macro")
    button:SetAttribute("step", 1)
    button:SetAttribute("numCastCommands", #rotation.castCommands)

    -- Set initial macrotext
    local initialCastCommand = rotation.castCommands[1]
    local initialMacroText = self:BuildMacroText(rotation, initialCastCommand)
    button:SetAttribute("macrotext", initialMacroText)

    -- Store spell attributes
    self:UpdateButtonAttributes(rotation, button)

    -- Add secure click handler
    self:SetupSecureClickHandler(rotation, button)

    -- Add PostClick handler
    button:SetScript("PostClick", function(self)
        CSL:UpdateMacroSpell(self)
    end)

    -- Store in UI table
    rotation.button = button

    -- Initial rendering
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
        button:SetAttribute("spellName" .. i, CSL.Helpers.GetSpellName(castCommand) or "")
    end
end

-- Set up the secure click handler
function CSL:SetupSecureClickHandler(rotation, button)
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
function CSL:BuildMacroText(rotation)
    -- Extract spell name from "/cast SpellName" for #showtooltip
    local text = "#showtooltip"

    -- Add pre-cast commands if defined
    if rotation.preCastCommands and #rotation.preCastCommands > 0 then
        for _, preCastCommand in ipairs(rotation.preCastCommands) do
            text = text .. "\n" .. preCastCommand
        end
    end

    text = text .. "\n/click CSLButton_" .. rotation.name
    return text
end

-- Get macro text template for secure handler
function CSL:GetMacroTextTemplate(rotation)
    -- Extract spell name from "/cast SpellName" for #showtooltip
    -- Note: In secure code we need to inline the extraction logic
    local template = "#showtooltip"

    -- Add pre-cast commands if defined
    if rotation.preCastCommands and #rotation.preCastCommands > 0 then
        for _, preCastCommand in ipairs(rotation.preCastCommands) do
            template = template .. "\\n" .. preCastCommand
        end
    end

    template = template .. "\\n\" .. castCommand .. \""
    return template
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
        -- SetMacroSpell works even in combat!
        -- Extract spell name from "/cast SpellName"
        local spellName = CSL.Helpers.GetSpellName(currentCastCommand)
        SetMacroSpell(button.macroName, spellName)
    end
end

-- Create or update the macro
function CSL:CreateOrUpdateMacro(rotation)
    local macroName = "CSL_" .. rotation.name
    local macroIndex = GetMacroIndexByName(macroName)
    local macroBody = self:BuildMacroText(rotation)

    if macroIndex == 0 then
        -- Macro doesn't exist, create it
        local _, numCharacterMacros = GetNumMacros()

        if numCharacterMacros < self.MAX_CHARACTER_MACROS then
            -- Create with the first cast command's icon (1 means character-specific macro)
            CreateMacro(macroName, 1, macroBody, 1)
            print("|cFF00FF00Macro '" .. macroName .. "' created!|r")
        else
            print("|cFFFF0000Too many macros! Delete some and /reload|r")
        end
    else
        -- Macro exists, update with current step's commands
        EditMacro(macroIndex, nil, nil, macroBody)
    end

    -- Restore icon from button's current spell state
    if rotation.button then
        self:UpdateMacroSpell(rotation.button)
    end
end

-- Register slash commands
function CSL:RegisterSlashCommands()
    SLASH_CASTSEQLITE1 = "/csl"
    SlashCmdList["CASTSEQLITE"] = function(msg)
        if InCombatLockdown() then
            print("|cFFFF0000Cannot open CastSequenceLite while in combat. Try again after combat.|r")
            return
        end

        -- Show management UI
        CSL.UIManager:ToggleManagementFrame()
    end
end

-- Print welcome message
function CSL:PrintWelcome()
    print("|cFF00FF00" .. addonName .. " v" .. self.VERSION .. " loaded!|r")
    print("|cFFFFFF00Type /csl to open the rotation editor.|r")
end

-- Event frame setup
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CSL:Initialize()
    end
end)