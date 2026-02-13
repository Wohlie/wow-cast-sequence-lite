local _, CSL = ...

CSL.Migrations = {}

--- Current format version of the database schema.
CSL.Migrations.CURRENT_FORMAT_VERSION = 1

--- Ordered list of migrations.
-- Each entry has:
--   toVersion (number) - the version this migration upgrades TO
--   migrate   (function(db)) - the migration function receiving the database
local migrations = {
    {
        toVersion = 1,
        migrate = function(db)
            -- Migration 0 -> 1: Establish the formatVersion field.
            -- No structural changes to rotations at this point.
            db.formatVersion = 1
        end,
    },
}

--- Run all pending migrations on the database.
-- Reads db.formatVersion (defaults to 0 if absent) and applies every
-- migration whose toVersion is greater than the current version, in order.
-- @param db The CastSequenceLiteDB table
function CSL.Migrations:Run(db)
    local currentVersion = db.formatVersion or 0

    for _, migration in ipairs(migrations) do
        if migration.toVersion > currentVersion then
            migration.migrate(db)
            currentVersion = migration.toVersion
        end
    end

    db.formatVersion = self.CURRENT_FORMAT_VERSION
end
