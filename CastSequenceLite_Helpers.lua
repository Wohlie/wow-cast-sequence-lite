local addonName, CSL = ...


CSL.Helpers = CSL.Helpers or {}

-- Constants
CSL.Helpers.DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Caches
CSL.Helpers.SpellNameCache = CSL.Helpers.SpellNameCache or {}
CSL.Helpers.IconCache = CSL.Helpers.IconCache or {}

--- Extract spell name from a cast command string
-- Removes /cast or /use prefixes and conditional brackets
-- @param castCommand The cast command string (e.g., "/cast Spell Name")
-- @return The extracted spell name, or empty string if invalid
function CSL.Helpers.ExtractSpellName(castCommand)
    if not castCommand or castCommand == "" then
        return ""
    end

    -- Remove /cast or /use command prefix (case-insensitive)
    local withoutCommand = castCommand:gsub("^%s*/[cC][aA][sS][tT]%s+", "")
    withoutCommand = withoutCommand:gsub("^%s*/[uU][sS][eE]%s+", "")

    -- Remove all conditional brackets [...]
    local withoutConditions = withoutCommand:gsub("%b[]", "")

    -- Trim leading/trailing whitespace
    local spellName = withoutConditions:match("^%s*(.-)%s*$")

    return spellName or ""
end

--- Get spell name from cast command (cached)
-- @param castCommand The cast command string
-- @return The spell name, or empty string if invalid
function CSL.Helpers.GetSpellName(castCommand)
    if not castCommand or castCommand == "" then
        return ""
    end

    local cache = CSL.Helpers.SpellNameCache
    if not cache[castCommand] then
        cache[castCommand] = CSL.Helpers.ExtractSpellName(castCommand)
    end

    return cache[castCommand]
end


--- Get icon texture for a spell (cached)
-- @param castCommand The cast command string
-- @return The icon texture path, or default icon if not found
function CSL.Helpers.GetIconForSpell(castCommand)
    if not castCommand or castCommand == "" then
        return CSL.Helpers.DEFAULT_ICON
    end

    local cache = CSL.Helpers.IconCache
    if not cache[castCommand] then
        local spellName = CSL.Helpers.GetSpellName(castCommand)
        local _, _, iconTexture = GetSpellInfo(spellName)
        cache[castCommand] = iconTexture or CSL.Helpers.DEFAULT_ICON
    end

    return cache[castCommand]
end

--- Parse commands from multi-line text
-- @param text The text to parse
-- @return Array of non-empty trimmed command lines
function CSL.Helpers.ParseCommands(text)
    local commands = {}
    for line in (text or ""):gmatch("[^\r\n]+") do
        local trimmed = line:trim()
        if trimmed ~= "" then
            table.insert(commands, trimmed)
        end
    end
    return commands
end

--- Deep copy rotation configuration for saving
-- @param rotationConfig The rotation configuration to copy
-- @return A new table with copied rotation configuration
function CSL.Helpers.CopyRotationConfig(rotationConfig)
    if not rotationConfig then
        return {}
    end

    return {
        preCastCommands = rotationConfig.preCastCommands and { unpack(rotationConfig.preCastCommands) } or {},
        castCommands = rotationConfig.castCommands and { unpack(rotationConfig.castCommands) } or {},
        resetAfterCombat = rotationConfig.resetAfterCombat or false
    }
end

