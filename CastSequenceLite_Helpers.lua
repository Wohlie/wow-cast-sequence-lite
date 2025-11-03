local addonName, CSL = ...

CSL.Helpers = {
    SpellNameCache = {},
    IconCache = {},
    DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
}

function CSL.Helpers.ExtractSpellName(castCommand)
    if not castCommand then
        return ""
    end

    -- Remove /cast or /use command prefix
    local withoutCommand = castCommand:gsub("^%s*/[cC][aA][sS][tT]%s+", "")
    withoutCommand = withoutCommand:gsub("^%s*/[uU][sS][eE]%s+", "")

    -- Remove all conditional brackets [...]
    local withoutConditions = withoutCommand:gsub("%b[]", "")

    -- Trim leading/trailing whitespace
    local spellName = withoutConditions:match("^%s*(.-)%s*$")

    return spellName or ""
end

function CSL.Helpers.GetSpellName(castCommand)
    if not castCommand then
        return ""
    end

    local cachedName = CSL.Helpers.SpellNameCache[castCommand]
    if cachedName ~= nil then
        return cachedName
    end

    local spellName = CSL.Helpers.ExtractSpellName(castCommand)
    CSL.Helpers.SpellNameCache[castCommand] = spellName
    return spellName
end

function CSL.Helpers.GetIconForSpell(castCommand)
    local fallback = CSL.Helpers.DEFAULT_ICON

    if not castCommand then
        return fallback
    end

    local cachedIcon = CSL.Helpers.IconCache[castCommand]
    if cachedIcon ~= nil then
        return cachedIcon
    end

    local spellName = CSL.Helpers.GetSpellName(castCommand)
    if spellName == "" then
        CSL.Helpers.IconCache[castCommand] = fallback
        return fallback
    end

    local _, _, iconTexture = GetSpellInfo(spellName)
    if iconTexture then
        CSL.Helpers.IconCache[castCommand] = iconTexture
        return iconTexture
    end

    CSL.Helpers.IconCache[castCommand] = fallback
    return fallback
end

