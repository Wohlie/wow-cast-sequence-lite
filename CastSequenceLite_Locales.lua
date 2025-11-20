local addonName, CSL = ...

-- Centralized text definitions
local I18N = {
    ["Macro '%s' deleted!"] = {
        deDE = "Macro '%s' gelöscht!",
    },
    ["Too many macros! Delete some and /reload"] = {
        deDE = "Zu viele Macros! Lösche einige und lade neu (/reload)",
    },
    ["Cannot open during combat"] = {
        deDE = "Kann während des Kampfes nicht geöffnet werden",
    },
    ["CastSequenceLite v%s loaded!|r Type /csl to open"] = {
        deDE = "CastSequenceLite v%s geladen!|r Tippe /csl zum Öffnen",
    },
    ["Are you sure you want to delete the rotation '%s'?"] = {
        deDE = "Bist du sicher, dass du die Rotation '%s' löschen möchtest?",
    },
    ["Yes"] = {
        deDE = "Ja",
    },
    ["No"] = {
        deDE = "Nein",
    },
    ["CastSequenceLite - Rotation Manager"] = {
        deDE = "CastSequenceLite - Rotation Manager",
    },
    ["Rotations"] = {
        deDE = "Rotations",
    },
    ["+ New Rotation"] = {
        deDE = "+ Neue Rotation",
    },
    ["Rotation Editor"] = {
        deDE = "Rotation Editor",
    },
    ["Rotation Name:"] = {
        deDE = "Rotation Name:",
    },
    ["Pre-Cast Commands (optional, one per line):"] = {
        deDE = "Pre-Cast Befehle (optional, einer pro Zeile):",
    },
    ["Cast Commands (one per line):"] = {
        deDE = "Cast Befehle (einer pro Zeile):",
    },
    ["Reset to first step after combat"] = {
        deDE = "Nach dem Kampf auf den ersten Schritt zurücksetzen",
    },
    ["Auto select next target"] = {
        deDE = "Nächstes Ziel automatisch wählen",
    },
    ["Always"] = {
        deDE = "Immer",
    },
    ["In Combat"] = {
        deDE = "Im Kampf",
    },
    ["Never"] = {
        deDE = "Nie",
    },
    ["Save"] = {
        deDE = "Speichern",
    },
    ["Cancel"] = {
        deDE = "Abbrechen",
    },
    ["Delete"] = {
        deDE = "Löschen",
    },
    ["Drag to place '%s' on your action bar"] = {
        deDE = "Ziehen, um '%s' auf deine Aktionsleiste zu platzieren",
    },
    ["Rotation name cannot be empty."] = {
        deDE = "Rotation Name darf nicht leer sein.",
    },
    ["Rotation name can only contain letters, numbers, underscores, and hyphens."] = {
        deDE = "Rotation Name darf nur Buchstaben, Zahlen, Unterstriche und Bindestriche enthalten.",
    },
    ["Rotation name must be %d characters or less."] = {
        deDE = "Rotation Name darf maximal %d Zeichen lang sein.",
    },
    ["Rotation '%s' already exists."] = {
        deDE = "Rotation '%s' existiert bereits.",
    },
    ["Macro '%s' already exists. Delete it manually or choose a different name."] = {
        deDE = "Macro '%s' existiert bereits. Lösche es manuell oder wähle einen anderen Namen.",
    },
    ["At least one cast command is required."] = {
        deDE = "Mindestens ein Cast-Befehl ist erforderlich.",
    },
    ["Cannot save rotations while in combat. Try again after combat."] = {
        deDE = "Rotationen können während des Kampfes nicht gespeichert werden. Versuche es nach dem Kampf erneut.",
    },
    ["Rotation '%s' saved!"] = {
        deDE = "Rotation '%s' gespeichert!",
    },
    ["Cannot delete rotations while in combat. Try again after combat."] = {
        deDE = "Rotationen können während des Kampfes nicht gelöscht werden. Versuche es nach dem Kampf erneut.",
    },
    ["CastSequenceLite hidden during combat. It will return after combat ends."] = {
        deDE = "CastSequenceLite während des Kampfes ausgeblendet. Es wird nach Kampfende wieder angezeigt.",
    },
}

-- Initialize AceLocale
local localeLib = LibStub("AceLocale-3.0", true)
if not localeLib then
    print("|cFFFF0000[CastSequenceLite]|r ERROR: AceLocale-3.0 not available! Localization disabled.")
    CSL.L = {}
    return
end

-- Extract all available locales from I18N structure
local availableLocales = { ["enUS"] = true }  -- Always include enUS as default
for key, translations in pairs(I18N) do
    for localeCode in pairs(translations) do
        availableLocales[localeCode] = true
    end
end

-- Register all locales dynamically with AceLocale
for localeCode in pairs(availableLocales) do
    local isDefault = (localeCode == "enUS")
    local L = localeLib:NewLocale(addonName, localeCode, isDefault)
    if L then
        for key, translations in pairs(I18N) do
            -- For enUS, use the key itself (since enUS entries are removed)
            -- For other locales, use the translation or fall back to the key
            if localeCode == "enUS" then
                L[key] = key
            else
                L[key] = translations[localeCode] or key
            end
        end
    end
end

-- Get the appropriate locale table
CSL.L = localeLib:GetLocale(addonName, true)
