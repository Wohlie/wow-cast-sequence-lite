local _, CSL = ...

CSL.Compat = {}

-- Detect client build number (e.g. 30300 for legacy client, 80000+ for BfA, 100000+ for Dragonflight)
local _, _, _, tocVersion = GetBuildInfo()
CSL.Compat.TocVersion = tocVersion or 0

-- Feature Flags based on TOC Version and Engine Features
CSL.Compat.IsModern = (WOW_PROJECT_ID ~= nil) -- WOW_PROJECT_ID is only defined in retail/classic clients (e.g. Classic Era, BCC, legacy client, etc.), distinguishing them from true legacy clients
CSL.Compat.hasKeyDownSupport = (GetCVar("ActionButtonUseKeyDown") ~= nil) -- Client supports cast-on-key-down/up toggle
CSL.Compat.IsClickRestricted = CSL.Compat.IsModern -- All official clients (Classic Era, Retail, etc.) restrict /click in macros

--- Check if the client requires BackdropTemplate mixin (Shadowlands 9.0+)
-- @return true if BackdropTemplateMixin exists
function CSL.Compat.NeedsBackdropTemplate()
    return BackdropTemplateMixin ~= nil
end

-- ---------------------------------------------------------------------------
-- Spell API Wrappers
-- ---------------------------------------------------------------------------
if C_Spell and C_Spell.GetSpellInfo then
    -- Modern client
    function CSL.Compat.GetSpellIcon(spellName)
        local info = C_Spell.GetSpellInfo(spellName)
        return info and info.iconID
    end

    function CSL.Compat.IsSpellUsable(spellName)
        local usable, notEnoughPower = C_Spell.IsSpellUsable(spellName)
        return usable, notEnoughPower
    end

    function CSL.Compat.GetSpellCooldown(spellName)
        local cd = C_Spell.GetSpellCooldown(spellName)
        if cd then
            return cd.startTime, cd.duration
        end
        return 0, 0
    end
else
    -- Legacy client
    function CSL.Compat.GetSpellIcon(spellName)
        local _, _, icon = GetSpellInfo(spellName)
        return icon
    end

    function CSL.Compat.IsSpellUsable(spellName)
        return IsUsableSpell(spellName)
    end

    function CSL.Compat.GetSpellCooldown(spellName)
        return GetSpellCooldown(spellName)
    end
end

-- ---------------------------------------------------------------------------
-- Backdrop Wrapper
-- ---------------------------------------------------------------------------

--- Create a frame with optional BackdropTemplate support for 9.0+ clients
-- @param frameType The frame type (e.g. "Frame")
-- @param name Optional global name
-- @param parent Parent frame
-- @param additionalTemplate Optional extra template to inherit
-- @return The created frame
function CSL.Compat.CreateBackdropFrame(frameType, name, parent, additionalTemplate)
    local template = additionalTemplate or ""
    if CSL.Compat.NeedsBackdropTemplate() then
        if template ~= "" then
            template = template .. ",BackdropTemplate"
        else
            template = "BackdropTemplate"
        end
    end

    if template == "" then
        template = nil
    end

    return CreateFrame(frameType, name, parent, template)
end
