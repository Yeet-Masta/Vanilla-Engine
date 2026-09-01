local gunCocked = false
local gunCockedTimer = nil
local spawnedCans = {}

local spraycan = require("assets.scripts.props.spraycan")

-- Matches the reference stage: the can is kicked up from the pile and arcs in
-- from its right-hand side.
local CAN_SPAWN_OFFSET = {530, -240}

local STATE_WAITING = 1
local STATE_ARCING = 2
local STATE_SHOT = 3
local STATE_IMPACTED = 4

function Song:onCreate()
    gunCocked = false
    if gunCockedTimer then
        Timer.cancel(gunCockedTimer)
        gunCockedTimer = nil
    end
    self:clearCans()
    self:resetStageColor()
end

function Song:onSongRetry()
    self:onCreate()
end

function Song:clearCans()
    for i = #spawnedCans, 1, -1 do
        remove(spawnedCans[i])
        spawnedCans[i] = nil
    end
end

function Song:onNoteHit(event)
    if event.noteType == "weekend-1-lightcan" then
    elseif event.noteType == "weekend-1-kickcan" then
        self:spawnCan()
    elseif event.noteType == "weekend-1-kneecan" then
    elseif event.noteType == "weekend-1-cockgun" then
        gunCocked = true
        if gunCockedTimer then Timer.cancel(gunCockedTimer) end
        gunCockedTimer = Timer.after(1, function()
            gunCocked = false
            gunCockedTimer = nil
        end)
    elseif event.noteType == "weekend-1-firegun"
        or event.noteType == "weekend-1-firegun-hip"
        or event.noteType == "weekend-1-firegun-far" then
        if gunCocked then
            self:shootNextCan()
        end
    end
end

function Song:spawnCan()
    local sprayCanPile = get("spraycanPile")
    if not sprayCanPile then return end

    local newCan = spraycan(
        sprayCanPile.x + CAN_SPAWN_OFFSET[1],
        sprayCanPile.y + CAN_SPAWN_OFFSET[2]
    )
    -- Draw above the pile so the arc and the explosion aren't hidden by it.
    newCan.zIndex = sprayCanPile.zIndex + 1

    add(newCan)
    weeks:sort()
    table.insert(spawnedCans, newCan)

    -- Without this the can never leaves frame 0 of its atlas.
    newCan:playCanStart()
end

function Song:getNextCanWithState(desiredState)
    for i = 1, #spawnedCans do
        local can = spawnedCans[i]

        if can.currentState == desiredState then
            return can
        end
    end
end

local globalColor = {1, 1, 1}
local blackout = false

function Song:resetStageColor()
    globalColor[1], globalColor[2], globalColor[3] = 1, 1, 1

    if blackout then
        -- Characters are skipped by the per-frame colour pass, so the ones the
        -- blackout dimmed have to be put back by hand or they stay black.
        blackout = false
        for _, prop in ipairs(weeks:getProps()) do
            if prop.characterType and prop.color then
                prop.color[1], prop.color[2], prop.color[3] = 1, 1, 1
            end
        end
    end
end

function Song:darkenStageProps()
    globalColor[1] = 17/255
    globalColor[2] = 17/255
    globalColor[3] = 17/255

    Timer.after(1/24, function()
        globalColor[1] = 34/255
        globalColor[2] = 34/255
        globalColor[3] = 34/255

        Timer.tween(1.4, globalColor, {1, 1, 1}, "linear")
    end)
end

function Song:blackenStageProps()
    blackout = true
    globalColor[1] = 0
    globalColor[2] = 0
    globalColor[3] = 0

    Timer.after(1, function()
        self:resetStageColor()
    end)
end

-- Characters keep their own colour during the muzzle-flash darkening. The
-- blackout on death is the exception: everything goes dark except Pico, so he
-- reads as a silhouette.
function Song:isDarkenable(prop)
    if table.includes(spawnedCans, prop) then return false end

    if prop.characterType then
        return blackout and prop.characterType ~= CHARACTER_TYPE.BF
    end

    return true
end

function Song:onUpdate(dt)
    for _, prop in ipairs(weeks:getProps()) do
        if self:isDarkenable(prop) then
            prop.color = prop.color or {1, 1, 1}
            prop.color[1] = globalColor[1]
            prop.color[2] = globalColor[2]
            prop.color[3] = globalColor[3]
        end
    end
end

local canVibrationPreset = {
    period = 0.1,
    duration = 0.1,
    amplitude = 1,
    sharpness = 1
}

function Song:shootNextCan()
    local can = self:getNextCanWithState(STATE_ARCING)

    if can then
        can:playCanShot()

        Timer.after(1/24, function()
            self:darkenStageProps()

            hapticUtil:vibrateByPreset(canVibrationPreset)
        end)
    end
end

function Song:missNextCan()
    local can = self:getNextCanWithState(STATE_ARCING)
    if can then
        can.currentState = STATE_IMPACTED
    end
end

function Song:onNoteMiss(event)
    if event.noteType == "weekend-1-cockgun" then
        event.healthChange = 0
    elseif event.noteType == "weekend-1-firegun"
        or event.noteType == "weekend-1-firegun-hip"
        or event.noteType == "weekend-1-firegun-far" then
        gunCocked = false
        -- The can itself deals the damage in takeCanDamage(), so the note must
        -- not also charge the usual miss penalty.
        event.healthChange = 0
        self:missNextCan()
        self:takeCanDamage()
    end
end

local HEALTH_LOSS = 0.25 * 2

function Song:takeCanDamage()
    weeks.health = weeks.health - HEALTH_LOSS

    if weeks.health <= 0 then
        gameoverSubstate.musicSuffix = "-pico-explode"
        gameoverSubstate.blueBallSuffix = "-pico-explode"

        self:blackenStageProps()
    else
        hapticUtil:vibrateByPreset(canVibrationPreset)
        Timer.after(0.45, function()
            hapticUtil:vibrateByPreset(canVibrationPreset)
        end)
    end
end
