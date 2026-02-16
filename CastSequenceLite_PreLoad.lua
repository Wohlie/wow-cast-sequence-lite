-- Must load BEFORE Ace3 libraries in the .toc
local _, _, _, tocVersion = GetBuildInfo()

-- PlaySound began supporting numeric IDs globally in 7.3.0, along with the SOUNDKIT global.
-- On legacy clients, SOUNDKIT does not exist and PlaySound strictly takes strings.
if not SOUNDKIT then
    local soundKitMap = {
        [799] = "gsTitleOptionExit",
        [841] = "igCharacterInfoTab",
        [847] = "igQuestFailed",
        [852] = "igMainMenuOption",
        [856] = "igMainMenuOptionCheckBoxOn",
        [857] = "igMainMenuOptionCheckBoxOff",
        [882] = "igPlayerInviteDecline",
    }

    local originalPlaySound = PlaySound
    PlaySound = function(soundID, ...)
        if type(soundID) == "number" then
            local name = soundKitMap[soundID]
            if name then
                return originalPlaySound(name, ...)
            end

            print(string.format("|cFFFF0000CastSequenceLite: Missing sound mapping for ID %d|r", soundID))
        end

        return originalPlaySound(soundID, ...)
    end
end

-- CreateMacro legacy clients expects a numeric icon index (e.g. 1 for the question mark).
-- Modern clients (Retail, Classic Era, Cata Classic) expect a texture string (e.g. "INV_Misc_QuestionMark") or a FileDataID.
-- Wrap it globally so our addon can always safely pass a string icon name.
-- Using WOW_PROJECT_ID as it exists on all modern clients (including 1.15.x and 4.4.x).
if not WOW_PROJECT_ID then
    local macroIconMap = {
        ["INV_Misc_QuestionMark"] = 1,
    }

    local originalCreateMacro = CreateMacro
    CreateMacro = function(name, icon, body, perCharacter)
        if type(icon) == "string" then
            local newIcon = macroIconMap[icon]
            if newIcon then
                icon = newIcon
            end
        end

        return originalCreateMacro(name, icon, body, perCharacter)
    end
end

-- Texture and color API shims.
-- SetColorTexture was added in 7.0; on legacy clients SetTexture(r,g,b,a) is equivalent.
-- Newer Ace3 uses numeric file IDs in SetTexture() which some clients don't support.
-- We hook SetTexture to convert known IDs to string paths (safe on all clients).
do
    local t = UIParent:CreateTexture()
    local mt = getmetatable(t).__index

    -- However, modern Classic Era (115xx) has both SetColorTexture AND WOW_PROJECT_ID.
    -- Retail/Legion+ has tocVersion >= 70000.
    local nativelySupportsTextureID = (tocVersion >= 70000) or (WOW_PROJECT_ID ~= nil)
    if not nativelySupportsTextureID then
        -- Polyfill for legacy clients
        mt.SetColorTexture = mt.SetTexture

        local textureFileMap = {
            [130751] = "Interface\\Buttons\\UI-CheckBox-Check",
            [130753] = "Interface\\Buttons\\UI-CheckBox-Highlight",
            [130755] = "Interface\\Buttons\\UI-CheckBox-Up",
            [130843] = "Interface\\Buttons\\UI-RadioButton",
            [130939] = "Interface\\ChatFrame\\ChatFrameColorSwatch",
            [130940] = "Interface\\ChatFrame\\ChatFrameExpandArrow",
            [131080] = "Interface\\DialogFrame\\UI-DialogBox-Header",
            [136580] = "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight",
            [136810] = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
            [137056] = "Interface\\Tooltips\\UI-Tooltip-Background",
            [137057] = "Interface\\Tooltips\\UI-Tooltip-Border",
            [188523] = "Tileset\\Generic\\Checkers",
            [251963] = "Interface\\PaperDollInfoFrame\\UI-GearManager-Border",
            [251966] = "Interface\\PaperDollInfoFrame\\UI-GearManager-Title-Background",
        }

        -- Legacy Client Only: Use hooksecurefunc to avoid tainting convert numbers back to strings
        local converting = false
        hooksecurefunc(mt, "SetTexture", function(self, texture, ...)
            if converting then
                return
            end

            if type(texture) == "number" then
                local path = textureFileMap[texture]
                if path then
                    converting = true
                    self:SetTexture(path, ...)
                    converting = false
                    return
                end

                if texture > 100 then
                    print(string.format("|cFFFF0000CastSequenceLite: Missing texture mapping for ID %d|r", texture))
                end
            end
        end)
    end
end
