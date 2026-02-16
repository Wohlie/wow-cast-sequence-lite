local _, CSL = ...

CSL.CombatQueue = {}

local queue = {}

--- Add a callback to run immediately, or after combat ends if in lockdown.
-- If a callback with the same key already exists in the queue, it is replaced.
-- @param key   Unique string key to prevent duplicate entries
-- @param fn    Function to call
function CSL.CombatQueue:Add(key, fn)
    if InCombatLockdown() then
        queue[key] = fn
    else
        fn()
    end
end

--- Run and clear all queued callbacks. Call this on PLAYER_REGEN_ENABLED.
function CSL.CombatQueue:Flush()
    for key, fn in pairs(queue) do
        queue[key] = nil
        fn()
    end
end
