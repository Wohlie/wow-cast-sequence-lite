local addonName, CSL = ...

CSL.Helpers = CSL.Helpers or {}

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
