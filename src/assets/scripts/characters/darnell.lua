local sounds = {}
local pendingSoundTimers = {}

function Character:onCreate()
    for _, snd in ipairs({"Darnell_Lighter", "Kick_Can_UP", "Kick_Can_FORWARD"}) do
        sounds[snd] = love.audio.newSource("weekend1/sounds/" .. snd .. ".ogg", "static")
    end

    self:cancelPendingSounds()
end

function Character:onSongRetry()
    self:cancelPendingSounds()
end

function Character:cancelPendingSounds()
    for i = #pendingSoundTimers, 1, -1 do
        Timer.cancel(pendingSoundTimers[i])
        pendingSoundTimers[i] = nil
    end
end

function Character:onNoteHit(event)
    if event.noteType == "weekend-1-lightcan" then
        self.data.holdTimer = 0
        self:playLightCanAnim()
    elseif event.noteType == "weekend-1-kickcan" then
        self.data.holdTimer = 0
        self:playKickCanAnim()
    elseif event.noteType == "weekend-1-kneecan" then
        self.data.holdTimer = 0
        self:playKneeCanAnim()
    end
end

-- The engine's lookahead hook is onNoteOncoming; the old onNoteIncoming name
-- was never dispatched, so none of the can sounds ever played.
function Character:onNoteOncoming(event)
    local msTilStrum = event.data.time - weeks.conductor.musicTime

    if event.noteType == "weekend-1-lightcan" then
        self:scheduleSound("Darnell_Lighter", (msTilStrum - 65) / 1000)
    elseif event.noteType == "weekend-1-kickcan" then
        self:scheduleSound("Kick_Can_UP", (msTilStrum - 50) / 1000)
    elseif event.noteType == "weekend-1-kneecan" then
        self:scheduleSound("Kick_Can_FORWARD", (msTilStrum - 22) / 1000)
    end
end

function Character:playLightCanAnim()
    self.data:play("lightCan", true, false)
end

function Character:playKickCanAnim()
    self.data:play("kickCan", true, false)
end

function Character:playKneeCanAnim()
    self.data:play("kneeCan", true, false)
end

function Character:scheduleSound(name, timeToPlay)
    local sound = sounds[name]
    if not sound then return end

    local handle
    handle = Timer.after(math.max(timeToPlay, 0), function()
        audio.playSound(sound)

        for i, pending in ipairs(pendingSoundTimers) do
            if pending == handle then
                table.remove(pendingSoundTimers, i)
                break
            end
        end
    end)

    table.insert(pendingSoundTimers, handle)
end
