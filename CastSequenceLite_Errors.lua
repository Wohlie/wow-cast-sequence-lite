local addonName, CSL = ...

CSL.Error = CSL.Error or {
    DELAY = 0.25,
    hide = false,
    depth = 0,
    queue = {},
    releaseFrame = nil,
    originalUIErrorsFrameAddMessage = nil
}

CSL.Error.releaseFrame = CSL.Error.releaseFrame or CreateFrame("Frame")

local ProcessErrorReleaseQueue = function(frame, elapsed)
    local queue = CSL.Error.queue
    if #queue == 0 then
        frame:SetScript("OnUpdate", nil)
        return
    end

    local now = GetTime()
    while queue[1] and queue[1] <= now do
        table.remove(queue, 1)

        CSL.Error.depth = CSL.Error.depth - 1
        if CSL.Error.depth <= 0 then
            CSL.Error.depth = 0
            CSL.Error.hide = false
        end
    end
end

function CSL.Error:BeginErrorSuppression()
    self.depth = self.depth + 1
    self.hide = true
end

function CSL.Error:EndErrorSuppression()
    table.insert(self.queue, GetTime() + CSL.Error.DELAY)
    self.releaseFrame:SetScript("OnUpdate", ProcessErrorReleaseQueue)
end

if UIErrorsFrame and not CSL.Error.originalUIErrorsFrameAddMessage then
    CSL.Error.originalUIErrorsFrameAddMessage = UIErrorsFrame.AddMessage
    function UIErrorsFrame:AddMessage(message, r, g, b, id, holdTime, ...)
        if CSL.Error.hide == true then
            return
        end

        return CSL.Error.originalUIErrorsFrameAddMessage(self, message, r, g, b, id, holdTime, ...)
    end
end
