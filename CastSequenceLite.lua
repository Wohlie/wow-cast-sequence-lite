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
CSL.MAX_ROTATION_NAME_LENGTH = CSL.MAX_MACRO_NAME_LENGTH
CSL.MAX_CHARACTER_MACROS = MAX_CHARACTER_MACROS or 18
CSL.MAX_ACCOUNT_MACROS = MAX_ACCOUNT_MACROS or 120

-- UI Constants
CSL.UI = {
    FRAME_WIDTH = 800,
    FRAME_HEIGHT = 600,
    LEFT_PANEL_WIDTH_RATIO = 0.3,
    RIGHT_PANEL_WIDTH_RATIO = 0.7,
    ROW_HEIGHT = 38,
    BUTTON_SIZE = 28,
    PREVIEW_BUTTON_SIZE = 36,
    PRECAST_INPUT_LINES = 5,
    CAST_INPUT_LINES = 7,
    MAX_PRECAST_LETTERS = 255,
}

-- Color Constants
CSL.COLORS = {
    SUCCESS = "|cFF00FF00",
    ERROR = "|cFFFF0000",
    WARNING = "|cFFFFD700",
    ERROR_RGB = { r = 1.0, g = 0.2, b = 0.2 },
    ACTIVE_BG = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 },
    ACTIVE_BORDER = { r = 0.4, g = 0.4, b = 0.4 },
}

CSL.Rotations = {} -- Runtime state for all rotations (keyed by rotation name)
CSL.DB = nil -- Saved variable namespace (per-character database populated at runtime)


--- Get or initialize the addon database
-- @return The database table
function CSL:GetDatabase()
    if not self.DB then
        CastSequenceLiteDB = CastSequenceLiteDB or { rotations = {} }
        CastSequenceLiteDB.rotations = CastSequenceLiteDB.rotations or {}
        self.DB = CastSequenceLiteDB
    end
    return self.DB
end

--- Save rotation configuration to database
-- @param rotationName The name of the rotation
-- @param rotationConfig The rotation configuration to save
function CSL:SaveRotationConfig(rotationName, rotationConfig)
    local db = self:GetDatabase()
    db.rotations[rotationName] = CSL.Helpers.CopyRotationConfig(rotationConfig)
end


--- Find a rotation by name (case-insensitive)
-- @param rotationName The rotation name to search for
-- @return The actual rotation name (with original case) if found, or nil
function CSL:FindRotationCaseInsensitive(rotationName)
    if not rotationName or rotationName == "" then
        return nil
    end

    local lowerName = string.lower(rotationName)
    for existingName, _ in pairs(self.Rotations) do
        if string.lower(existingName) == lowerName then
            return existingName
        end
    end

    return nil
end

--- Initialize a single rotation from configuration
-- @param rotationName The name of the rotation
-- @param rotationConfig The rotation configuration
-- @return The initialized rotation object
function CSL:InitializeRotation(rotationName, rotationConfig)
    local rotation = self.Rotations[rotationName] or {}

    rotation.name = rotationName
    rotation.preCastCommands = rotationConfig.preCastCommands and { unpack(rotationConfig.preCastCommands) } or {}
    rotation.castCommands = { unpack(rotationConfig.castCommands) }
    rotation.currentStep = 1

    -- Migration: Convert resetAfterCombat boolean to string (yes/no)
    if type(rotationConfig.resetAfterCombat) == "boolean" then
        if rotationConfig.resetAfterCombat then
            rotation.resetAfterCombat = "yes"
        else
            rotation.resetAfterCombat = "no"
        end
    else
        rotation.resetAfterCombat = rotationConfig.resetAfterCombat or "no"
    end
    
    -- Migration: Convert old requireTarget boolean to autoSelectTarget
    if rotationConfig.autoSelectTarget then
        rotation.autoSelectTarget = rotationConfig.autoSelectTarget
    elseif rotationConfig.requireTarget ~= nil then
        if rotationConfig.requireTarget then
            rotation.autoSelectTarget = "never"
        else
            rotation.autoSelectTarget = "always"
        end
    else
        rotation.autoSelectTarget = "combat"
    end

    -- Precompute spell names for caching
    for _, castCommand in ipairs(rotation.castCommands) do
        CSL.Helpers.GetSpellName(castCommand)
    end

    self.Rotations[rotationName] = rotation
    return rotation
end

--- Delete a rotation and clean up associated resources
-- @param rotationName The name of the rotation to delete
function CSL:DeleteRotation(rotationName)
    local rotation = self.Rotations[rotationName]
    if not rotation then
        return
    end

    -- Delete macro
    local macroIndex = GetMacroIndexByName(rotationName)
    if macroIndex > 0 then
        DeleteMacro(macroIndex)
        print(CSL.COLORS.SUCCESS .. string.format(CSL.L["Macro '%s' deleted!"], rotationName) .. "|r")
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

--- Initialize the addon
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


--- Create the main sequence button for a rotation
-- @param rotation The rotation object
-- @return The created button frame
function CSL:CreateButton(rotation)
    local buttonName = "CSLButton_" .. rotation.name
    local button = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    button:Hide()

    -- Store references
    button.rotationName = rotation.name
    button.macroName = rotation.name

    -- Configure button attributes
    button:SetAttribute("type", "macro")
    button:SetAttribute("step", 1)
    button:SetAttribute("numCastCommands", #rotation.castCommands)
    button:SetAttribute("macrotext", self:BuildMacroText(rotation))

    -- Setup handlers and attributes
    self:UpdateButtonAttributes(rotation, button)
    self:SetupSecureClickHandler(rotation, button)
    self:SetupButtonScripts(button)

    rotation.button = button
    self:UpdateMacroSpell(button)

    return button
end

--- Setup button click scripts for error suppression
-- @param button The button frame
function CSL:SetupButtonScripts(button)
    -- Suppress UI errors during rotation clicks only
    button:SetScript("PreClick", function()
        CSL.Error:BeginErrorSuppression()
    end)

    button:SetScript("PostClick", function(self)
        CSL:UpdateMacroSpell(self)
        CSL.Error:EndErrorSuppression()
    end)
end

--- Update button attributes for current rotation
-- @param rotation The rotation object
-- @param button The button frame to update
function CSL:UpdateButtonAttributes(rotation, button)
    if not button then
        return
    end

    local newCount = #rotation.castCommands
    local previousCount = button:GetAttribute("numCastCommands") or 0

    -- Update cast command count
    button:SetAttribute("numCastCommands", newCount)

    -- Set cast commands and spell names
    for i, castCommand in ipairs(rotation.castCommands) do
        button:SetAttribute("castCommand" .. i, castCommand)
        button:SetAttribute("spellName" .. i, CSL.Helpers.GetSpellName(castCommand))
    end

    -- Set pre-cast text and options
    local preCastText = ""
    if rotation.preCastCommands and #rotation.preCastCommands > 0 then
        preCastText = table.concat(rotation.preCastCommands, "\n")
    end
    button:SetAttribute("preCastText", preCastText)
    button:SetAttribute("autoSelectTarget", rotation.autoSelectTarget)

    -- Clean up old attributes if count decreased
    if previousCount > newCount then
        for i = newCount + 1, previousCount do
            button:SetAttribute("castCommand" .. i, nil)
            button:SetAttribute("spellName" .. i, nil)
        end
    end

    -- Reset step if it's out of bounds
    local currentStep = button:GetAttribute("step") or 1
    if currentStep > newCount then
        button:SetAttribute("step", 1)
    end
end

--- Set up the secure click handler for rotation cycling
-- @param rotation The rotation object
-- @param button The button frame
function CSL:SetupSecureClickHandler(rotation, button)
    if not button then
        return
    end

    local secureCode = [[
        local step = self:GetAttribute('step') or 1
        local numCastCommands = self:GetAttribute('numCastCommands') or 1
        local autoSelectTarget = self:GetAttribute('autoSelectTarget')

        -- Handle auto selection logic
        local shouldExecute = true
        
        if autoSelectTarget == "never" then
             if SecureCmdOptionParse("[@target,exists] 1; 0") == "0" then shouldExecute = false end
        elseif autoSelectTarget == "combat" or autoSelectTarget == nil then
             if SecureCmdOptionParse("[combat] 1; [@target,exists] 1; 0") == "0" then shouldExecute = false end
        end

        if not shouldExecute then
             self:SetAttribute('macrotext', "")
             return
        end
        
        -- Find the next valid cast command (skipping failed conditionals)
        local foundValidCommand = false
        local startStep = step
        
        for i = 1, numCastCommands do
            local castCommand = self:GetAttribute('castCommand' .. step)
            
            -- Check if the command's conditionals pass
            -- We append " 1; 0" to the command to turn it into a boolean check for SecureCmdOptionParse
            -- But SecureCmdOptionParse parses the whole command line. 
            -- If castCommand is "/cast [combat] Spell", parsing it directly returns "Spell" if true, or nil if false.
            
            if castCommand then
                local targetCmd = castCommand:gsub("^/cast%s*", ""):gsub("^/use%s*", "")
                local parsed = SecureCmdOptionParse(targetCmd)
                
                if parsed then
                    -- Conditionals passed! Use this command.
                    foundValidCommand = true
                    
                    local preCastText = self:GetAttribute('preCastText')
                    local text = "#showtooltip"
                    
                    -- Auto-clear dead targets if auto-selection is allowed
                    if autoSelectTarget == "always" or (autoSelectTarget == "combat" and SecureCmdOptionParse("[combat] 1; 0") == "1") then
                         text = text .. "\n/cleartarget [dead]"
                    end

                    if preCastText and preCastText ~= "" then
                        text = text .. "\n" .. preCastText
                    end
                    text = text .. "\n" .. castCommand
                    self:SetAttribute('macrotext', text)
                    
                    -- Prepare step for NEXT click
                    step = step + 1
                    if step > numCastCommands then step = 1 end
                    self:SetAttribute('step', step)
                    break
                end
            end
            
            -- Move to next step to check
            step = step + 1
            if step > numCastCommands then step = 1 end
        end
        
        -- If we looped through everything and found nothing valid, do nothing (or reset)
        if not foundValidCommand then
            self:SetAttribute('macrotext', "")
            -- We don't update 'step' here so we retry from the same spot next time, 
            -- or we could reset to 1. Leaving it at the last checked step is usually safe.
            -- However, to avoid getting stuck if the user changes context, let's reset to startStep
            self:SetAttribute('step', startStep)
        end
    ]]

    button:WrapScript(button, "OnClick", secureCode)
end

--- Build macro text that clicks the secure button
-- @param rotation The rotation object
-- @return The macro text string
function CSL:BuildMacroText(rotation)
    return "#showtooltip\n/click CSLButton_" .. rotation.name
end

--- Get macro text template for secure handler
-- @param rotation The rotation object
-- @return The macro text template string
function CSL:GetMacroTextTemplate(rotation)
    local template = "#showtooltip"
    for _, preCastCommand in ipairs(rotation.preCastCommands or {}) do
        template = template .. "\\n" .. preCastCommand
    end
    return template .. "\\n\" .. castCommand .. \""
end

--- Update macro spell icon (combat-safe)
-- @param button The button frame
function CSL:UpdateMacroSpell(button)
    if not button or not button.rotationName then
        return
    end

    local rotation = self.Rotations[button.rotationName]
    if not rotation then
        return
    end

    local currentStep = button:GetAttribute("step") or 1
    local numCastCommands = button:GetAttribute("numCastCommands") or #rotation.castCommands

    -- Find the next valid cast command (simulating the secure handler logic)
    local validCastCommand = nil
    local step = currentStep

    for i = 1, numCastCommands do
        local castCommand = button:GetAttribute("castCommand" .. step)

        if castCommand then
            -- Strip /cast or /use to get just the conditionals and spell
            local targetCmd = castCommand:gsub("^/cast%s*", ""):gsub("^/use%s*", "")
            -- Check if the command's conditionals pass
            if SecureCmdOptionParse(targetCmd) then
                validCastCommand = castCommand
                break
            end
        end

        -- Move to next step
        step = step + 1
        if step > numCastCommands then
            step = 1
        end
    end

    -- If no valid command found (loop failed), fallback to current step
    if not validCastCommand then
        validCastCommand = button:GetAttribute("castCommand" .. currentStep)
    end

    if validCastCommand then
        local spellName = CSL.Helpers.GetSpellName(validCastCommand)
        SetMacroSpell(button.macroName, spellName)
    end
end

--- Create or update the macro for a rotation
-- @param rotation The rotation object
function CSL:CreateOrUpdateMacro(rotation)
    local macroIndex = GetMacroIndexByName(rotation.name)
    local macroBody = self:BuildMacroText(rotation)

    if macroIndex == 0 then
        -- Create new macro
        local _, numCharacterMacros = GetNumMacros()
        if numCharacterMacros < self.MAX_CHARACTER_MACROS then
            CreateMacro(rotation.name, 1, macroBody, 1)
        else
            print(CSL.COLORS.ERROR .. CSL.L["Too many macros! Delete some and /reload"] .. "|r")
        end
    else
        -- Update existing macro
        EditMacro(macroIndex, nil, nil, macroBody)
    end

    -- Update macro spell icon
    if rotation.button then
        self:UpdateMacroSpell(rotation.button)
    end
end

--- Register slash commands
function CSL:RegisterSlashCommands()
    SLASH_CASTSEQLITE1 = "/csl"
    SlashCmdList["CASTSEQLITE"] = function(msg)
        if InCombatLockdown() then
            print(CSL.COLORS.ERROR .. CSL.L["Cannot open during combat"] .. "|r")
            return
        end
        CSL.UIManager:ToggleManagementFrame()
    end
end

--- Print welcome message (only once)
function CSL:PrintWelcome()
    if not self.welcomeShown then
        print(CSL.COLORS.SUCCESS .. string.format(CSL.L["CastSequenceLite v%s loaded!|r Type /csl to open"], self.VERSION))
        self.welcomeShown = true
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Enter combat
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Leave combat
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CSL:Initialize()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- Reset rotations if leaving combat
        if event == "PLAYER_REGEN_ENABLED" then
            for _, rotation in pairs(CSL.Rotations) do
                if rotation.resetAfterCombat == "yes" and rotation.button then
                    rotation.button:SetAttribute("step", 1)
                end
            end
        end

        -- Update all macro icons when combat state changes
        if CSL.Rotations then
            for _, rotation in pairs(CSL.Rotations) do
                if rotation.button then
                    CSL:UpdateMacroSpell(rotation.button)
                end
            end
        end
    end
end)