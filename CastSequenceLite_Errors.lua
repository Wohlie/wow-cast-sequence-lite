local addonName, CSL = ...

CSL.Error = CSL.Error or {}

-- Constants
CSL.Error.DELAY = 0.25 -- Delay in seconds before re-enabling error messages

-- State
CSL.Error.hide = false
CSL.Error.depth = 0
CSL.Error.queue = {}
CSL.Error.originalUIErrorsFrameAddMessage = nil

-- Frame for processing error release queue
CSL.Error.releaseFrame = CSL.Error.releaseFrame or CreateFrame("Frame")

--- Process the error release queue (internal)
-- @param frame The update frame
-- @param elapsed Time elapsed since last update
function CSL.Error.ProcessErrorReleaseQueue(frame, elapsed)
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

--- Begin suppressing UI error messages
function CSL.Error:BeginErrorSuppression()
    self.depth = self.depth + 1
    self.hide = true
end

--- End suppressing UI error messages (with delay)
function CSL.Error:EndErrorSuppression()
    table.insert(self.queue, GetTime() + CSL.Error.DELAY)
    self.releaseFrame:SetScript("OnUpdate", CSL.Error.ProcessErrorReleaseQueue)
end


-- Hook into UIErrorsFrame to suppress messages when needed
if UIErrorsFrame and not CSL.Error.originalUIErrorsFrameAddMessage then
    CSL.Error.originalUIErrorsFrameAddMessage = UIErrorsFrame.AddMessage

    function UIErrorsFrame:AddMessage(message, r, g, b, id, holdTime, ...)
        if CSL.Error.hide then
            return
        end

        return CSL.Error.originalUIErrorsFrameAddMessage(self, message, r, g, b, id, holdTime, ...)
    end
end
