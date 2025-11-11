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

    local cache = CSL.Helpers.SpellNameCache
    if not cache[castCommand] then
        cache[castCommand] = CSL.Helpers.ExtractSpellName(castCommand)
    end

    return cache[castCommand]
end

function CSL.Helpers.GetIconForSpell(castCommand)
    if not castCommand then
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

