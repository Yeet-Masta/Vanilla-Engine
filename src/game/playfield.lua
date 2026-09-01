-- game/playfield.lua
--
-- One playfield = four lanes of receptors + notes, either player-controlled
-- or auto-played (the opponent).
--
-- Note lifecycle: notes are NEVER removed from their lane array. Each lane
-- keeps a `head` cursor -- everything below it is finished -- and notes that
-- get consumed out of order are flagged `note.consumed`. This keeps every
-- operation O(number of on-screen notes) instead of O(notes in the lane),
-- and it means the arrays stay intact for the restart path in setup.lua.

local playfield = Object:extend()

local WEEKS         = CONSTANTS.WEEKS
local NOTE_LIST     = WEEKS.NOTE_LIST
local ANIM_LIST     = WEEKS.ANIM_LIST
local INPUT_LIST    = WEEKS.INPUT_LIST
local HEALTH        = WEEKS.HEALTH
local PIXELS_PER_MS = WEEKS.PIXELS_PER_MS

-- Sustain segments must be spaced by `SUSTAIN_STEP_REF_MS / speed` (not a
-- flat ms value) so the on-screen pixel gap between segments stays constant
-- regardless of scroll speed:
--   pixelGap = (REF/speed) * PIXELS_PER_MS * speed = REF * PIXELS_PER_MS
-- A flat ms step makes that gap grow with speed instead, which is what makes
-- fast-scroll holds look chopped up rather than a solid bar. To keep speed
-- from also inflating hold health/score (more, smaller segments at higher
-- speed), each segment's health is scaled by its own timespan rather than
-- being a flat per-segment constant -- see HOLD_HEALTH_PER_MS below.
local SUSTAIN_STEP_REF_MS = WEEKS.SUSTAIN_STEP_REF_MS or 71
local SUSTAIN_MIN_LEN = 0.1

-- Health granted per millisecond of hold, applied per segment as
-- HOLD_HEALTH_PER_MS * segmentTimeSpan. At the reference spacing (speed 1)
-- this reproduces the original 0.0125-per-segment value; at any other speed
-- the total health for a full hold still comes out to holdTime worth of gain,
-- unaffected by how many segments that hold happens to be split into.
local HOLD_HEALTH_GAIN = 0.0125
local HOLD_HEALTH_PER_MS = HOLD_HEALTH_GAIN / SUSTAIN_STEP_REF_MS
local MISS_WINDOW_MS   = 200      -- how late a note may be before it's a miss
local ONCOMING_LEAD_MS = 2500     -- how early onNoteOncoming fires
local CULL_PIXELS      = 1200     -- half-height of the "keep updated" band
local CULL_MIN_MS      = 500
local CULL_MAX_MS      = 6000

local floor, abs, max = math.floor, math.abs, math.max

local nextHoldID = 0

local function scrollDirection()
    return settings.downscroll and -1 or 1
end

-- The single source of truth for where a note sits. addNote, update and the
-- restart path in setup.lua all have to agree on this, or notes that are
-- outside the update band render in the wrong place.
function playfield:noteY(lane, time)
    return self.receptorY[lane]
        - PIXELS_PER_MS * (musicTime - time) * weeks.speed * scrollDirection()
end

-- How far ahead/behind (in ms) notes still matter. Derived from scroll speed
-- so a fast chart doesn't walk thousands of off-screen notes every frame.
local function cullWindow()
    local pxPerMs = PIXELS_PER_MS * (weeks.speed or 1)
    if pxPerMs <= 0 then return CULL_MAX_MS end
    local ms = CULL_PIXELS / pxPerMs
    if ms < CULL_MIN_MS then return CULL_MIN_MS end
    if ms > CULL_MAX_MS then return CULL_MAX_MS end
    return ms
end

function playfield:callObjects(eventName, event)
    for _, obj in ipairs(weeks.objects) do
        if obj.call then
            obj:call(eventName, event)
        end
    end
end

function playfield:callEvent(eventName, event)
    weeks.stage:call(eventName, event)
    weeks.song:call(eventName, event)
    self:callObjects(eventName, event)
end

function playfield:playMissAnimation(characterType, animation)
    for _, obj in ipairs(weeks.objects) do
        if obj.characterType == characterType then
            obj:play(animation, true, false)
        end
    end
end

function playfield:new(playable, receptorSprite, targetType)
    self.playable = playable

    self.offsetX = -750
    self.receptors = {}
    self.notes = {}
    self.head = {}
    self.emitHead = {}
    self.droppedHold = {}
    self.receptorY = {}

    self.laneCount = 4
    self.targetType = targetType or CHARACTER_TYPE.BF

    for i = 1, self.laneCount do
        self.notes[i] = {}
        self.head[i] = 1
        self.emitHead[i] = 1
        self.droppedHold[i] = nil

        local receptor = receptorSprite()
        receptor:animate(NOTE_LIST[i])
        receptor.x = 165 * (i - 1) + WEEKS.STRUM_X_OFFSET
        receptor.y = WEEKS.STRUM_Y * scrollDirection()
        receptor.finishedAlpha = 1

        -- Pixel noteskins load with the engine's default (linear) filter, which
        -- smears them once udraw() upscales the tiny 17x17 source frames. All
        -- four arrow directions + the receptor share one "pixel/notes" atlas
        -- image, so forcing nearest here (on the first sprite built from it)
        -- fixes filtering for every note/receptor drawn from that atlas.
        if pixel then
            receptor:setAntialiasing(false)
        end

        self.receptors[i] = receptor
        self.receptorY[i] = receptor.y
    end
end

function playfield:initVwoosh()
    self.vwooshYAmt = 50
    for i = 1, self.laneCount do
        self.receptors[i].alpha = 0
    end
end

function playfield:addNote(d, sprite)
    local lane = d.d % 4 + 1
    local time = d.t
    local holdTime = d.l or 0
    local kind = d.k or "normal"

    local speed = weeks.speed
    if not speed or speed <= 0 then speed = 1 end

    nextHoldID = nextHoldID + 1
    local holdID = nextHoldID

    local o = sprite()

    o.x = self.receptors[lane].x
    o.y = self:noteY(lane, time)
    o.col = lane
    o.time = time
    o.ver = kind
    o:animate("on")
    o.hitNote = true
    o.healthGainMult = 1
    o.healthLossMult = 1
    o.causesMiss = false
    o.emitted = false
    o.consumed = false
    o.isSustain = false
    o.holdID = holdID

    self.notes[lane][#self.notes[lane] + 1] = o

    if holdTime > SUSTAIN_MIN_LEN then
        local step = SUSTAIN_STEP_REF_MS / speed
        local segmentHealth = HOLD_HEALTH_PER_MS * step

        for k = step, holdTime, step do
            local hn = sprite()

            hn.col = lane
            hn.x = self.receptors[lane].x
            hn.time = time + k
            hn.y = self:noteY(lane, hn.time)
            hn.ver = kind
            hn:animate("hold")

            hn.healthGainMult = o.healthGainMult
            hn.healthLossMult = o.healthLossMult
            hn.causesMiss = o.causesMiss
            hn.hitNote = o.hitNote
            hn.emitted = false
            hn.consumed = false
            hn.isSustain = true
            hn.holdID = holdID
            hn.holdHealth = segmentHealth

            self.notes[lane][#self.notes[lane] + 1] = hn
        end

        local endNote = self.notes[lane][#self.notes[lane]]
        if endNote ~= o then
            endNote:animate("end")
            endNote.flipY = settings.downscroll
        end
    end
end

-- Sorts each lane and clears all per-attempt note state. Called after building
-- a chart and again on restart (setup.lua reuses the same note objects), so
-- this is the one place that has to reset `consumed` / `emitted` / cursors.
function playfield:sortNotes()
    local byTime = function(a, b) return a.time < b.time end

    for lane = 1, self.laneCount do
        local notes = self.notes[lane]

        table.sort(notes, byTime)

        for i = 1, #notes do
            local note = notes[i]
            note.consumed = false
            note.emitted = false
            note.didHit = false
            note.y = self:noteY(lane, note.time)
        end

        self.head[lane] = 1
        self.emitHead[lane] = 1
        self.droppedHold[lane] = nil
    end
end

function playfield:getNoteY(time)
    return PIXELS_PER_MS * (musicTime - time) * weeks.speed * scrollDirection()
end

-- Marks a note done and pulls the lane cursor forward over anything finished.
function playfield:consume(lane, index)
    self.notes[lane][index].consumed = true

    local notes = self.notes[lane]
    local head = self.head[lane]
    local count = #notes

    while head <= count and notes[head].consumed do
        head = head + 1
    end

    self.head[lane] = head
    if self.emitHead[lane] < head then
        self.emitHead[lane] = head
    end
end

function playfield:judgeNote(msOffset)
    local thres = WEEKS.JUDGE_THRES[settings.judgePreset]

    if msOffset <= thres.SICK_THRES then
        return "sick"
    elseif msOffset <= thres.GOOD_THRES then
        return "good"
    elseif msOffset <= thres.BAD_THRES then
        return "bad"
    else
        return "shit"
    end
end

function playfield:scoreNote(msOffset)
    local minScore = WEEKS.MIN_SCORE
    local range = WEEKS.MAX_SCORE - minScore
    local score = minScore
        + range / (1 + math.exp(WEEKS.SCORING_SLOPE * (msOffset - WEEKS.SCORING_OFFSET)))

    return floor(score + 0.5)
end

function playfield:healthForHit(note, ratingAnim, isSustain)
    if isSustain then
        return (note.holdHealth or HOLD_HEALTH_GAIN) * weeks.healthGainMult * note.healthGainMult
    end
    return (HEALTH.BONUS[ratingAnim:upper()] or 0)
        * weeks.healthGainMult * note.healthGainMult
end

function playfield:spawnSplash(lane, receptor)
    if not NoteSplash.spr then
        NoteSplash:setup()
    end
    if not NoteSplash.spr then return end

    NoteSplash:new({
        anim    = NOTE_LIST[lane] .. tostring(love.math.random(1, 2)),
        posX    = receptor.x + self.offsetX,
        posY    = receptor.y,
        alpha   = receptor.alpha,
        visible = receptor.visible,
    }, lane)
end

function playfield:onNoteHit(lane, note, receptor, ratingAnim, character)
    local isSustain = note.isSustain
    local healthChange = self:healthForHit(note, ratingAnim, isSustain)

    receptor:animate(NOTE_LIST[lane] .. " confirm", false)

    if character then
        character.lastHit = musicTime
    end

    -- Ask scripts first. A cancelled hit must not award health, which is what
    -- the old ordering did (health was applied before this check).
    if Gamestate.onNoteHit(character, note.ver, ratingAnim, lane) ~= nil then
        return false
    end

    local event = eventCreator:noteHit(note.ver, lane, note, healthChange, ratingAnim)
    event.mustHit = true

    for _, obj in ipairs(weeks.objects) do
        if obj.characterType == self.targetType then
            obj:play(ANIM_LIST[lane], true, false)
            obj.holdTimer = 0
        end
    end

    -- Every object hears about the hit, not just the singer, and filters on
    -- event.mustHit/characterType itself -- same as the enemy path below.
    -- Blazin' needs this: Darnell reacts to the notes *Pico* hits.
    self:callEvent("onNoteHit", event)

    if event.cancelled then return false end

    weeks.health = weeks.health + (event.healthChange or healthChange)
    return true
end

function playfield:onEnemyNoteHit(lane, note, receptor)
    local isSustain = note.isSustain

    -- Play the enemy's default animation first, THEN fire onNoteHit. A note
    -- script (e.g. a duet song where a "mom" note should override the dad
    -- sprite with an alt animation) calls obj:play(..., true, false) itself
    -- in response to this hook and depends on running last -- if this
    -- function's own obj:play ran after the hook instead, it would
    -- immediately stomp the script's override back to the default anim.
    for _, obj in ipairs(weeks.objects) do
        if obj.characterType == self.targetType then
            obj:play(ANIM_LIST[lane], not isSustain, false)
            obj.holdTimer = 0
            obj.lastHit = musicTime
        end
    end

    Gamestate.onNoteHit(enemy, note.ver, "EnemyHit", lane)

    local event = eventCreator:noteHit(note.ver, lane, note, 0, "EnemyHit")
    event.mustHit = false
    self:callEvent("onNoteHit", event)

    if not isSustain and not event.cancelled then
        self:spawnSplash(lane, receptor)
    end
end

-- `announce` is false for sustain segments after the first one in a dropped
-- hold, so letting go of a 2s hold is one miss instead of ~28.
function playfield:missNote(lane, note, announce)
    if weeks.voicesBF then
        weeks.voicesBF:setVolume(0)
    end

    if not announce then
        return
    end

    local healthChange = -HEALTH.MISS_PENALTY * weeks.healthLossMult * note.healthLossMult
    local event = eventCreator:noteMiss(note.ver, lane, nil, healthChange)

    self:playMissAnimation(self.targetType, ANIM_LIST[lane] .. "miss")
    self:callEvent("onNoteMiss", event)

    if event.cancelled then return end

    weeks.health = weeks.health + (event.healthChange or healthChange)

    if note.isSustain then
        Gamestate.onNoteMiss(weeks.boyfriend, note.ver, "BoyfriendMiss", lane)
    else
        weeks:onNoteMissed()
    end
end

function playfield:ghostMiss(lane)
    audio.playSound(weeks.sounds.miss[love.math.random(3)])
    self:playMissAnimation(self.targetType, ANIM_LIST[lane] .. "miss")

    weeks.score = max(0, weeks.score - 10)

    local healthChange = -(HEALTH.GHOST_MISS_PENALTY or HEALTH.MISS_PENALTY)
        * (weeks.healthLossMult or 1)

    -- Scripts get a say here too: Blazin' leans on this to make Darnell/Pico
    -- react to wild presses, not just to notes that actually existed.
    local event = eventCreator:noteMiss(nil, lane, nil, healthChange)
    self:callEvent("onNoteGhostMiss", event)

    if event.cancelled then return end

    weeks.health = weeks.health + (event.healthChange or healthChange)

    weeks:onNoteMissed()
end

function playfield:processNoteMisses(lane)
    local notes = self.notes[lane]
    local count = #notes
    local deadline = musicTime - MISS_WINDOW_MS

    local i = self.head[lane]

    while i <= count do
        local note = notes[i]

        if note.consumed then
            i = i + 1
        elseif note.time > deadline then
            break
        else
            -- Only the first segment of a dropped hold gets announced.
            local announce = true
            if note.isSustain and self.droppedHold[lane] == note.holdID then
                announce = false
            end
            if note.isSustain then
                self.droppedHold[lane] = note.holdID
                HoldCover:stop(lane, 1)
            end

            self:missNote(lane, note, announce)
            self:consume(lane, i)
            i = i + 1
        end
    end
end

function playfield:processInput(lane, receptor)
    local inputKey = INPUT_LIST[lane]
    local noteName = NOTE_LIST[lane]
    local notes = self.notes[lane]
    local count = #notes

    if input:pressed(inputKey) then
        local missWindow = WEEKS.JUDGE_THRES[settings.judgePreset].MISS_THRES

        receptor:animate(noteName .. " press", false)

        local hitIndex, hitNote

        -- Notes are time-sorted, so the first hittable tap wins and anything
        -- past the window ends the scan. The old loop walked the whole lane.
        for i = self.head[lane], count do
            local note = notes[i]
            local offset = note.time - musicTime

            if offset > missWindow then
                break
            end

            if not note.consumed and not note.isSustain and not note.didHit then
                hitIndex, hitNote = i, note
                break
            end
        end

        if hitNote then
            local offset = abs(hitNote.time - musicTime)
            local ratingAnim = self:judgeNote(offset)

            hitNote.didHit = true

            if hitNote.causesMiss then
                -- Hurt notes and friends: hitting them is the failure case.
                self:consume(lane, hitIndex)
                self:missNote(lane, hitNote, true)
            else
                if weeks.voicesBF then weeks.voicesBF:setVolume(1) end
                if weeks.boyfriend then weeks.boyfriend.lastHit = musicTime end

                local accepted = self:onNoteHit(lane, hitNote, receptor, ratingAnim, weeks.boyfriend)

                self:consume(lane, hitIndex)

                if accepted then
                    scoring.registerHit(weeks)
                    weeks.score = weeks.score + self:scoreNote(offset)
                    weeks:onNoteRated(ratingAnim)

                    if settings.scoringType == "Psych" then
                        weeks.ratingTextScale = 1.075
                    end

                    if ratingAnim == "sick" then
                        self:spawnSplash(lane, receptor)
                    end
                end
            end
        elseif not settings.ghostTapping then
            self:ghostMiss(lane)
        end
    end

    -- Holding through sustain segments.
    if input:down(inputKey) then
        local i = self.head[lane]

        while i <= count do
            local note = notes[i]

            if note.consumed then
                i = i + 1
            elseif note.time > musicTime then
                break
            elseif not note.isSustain then
                break -- an un-hit tap blocks the sustains behind it
            else
                if weeks.voicesBF then weeks.voicesBF:setVolume(1) end
                if weeks.boyfriend then weeks.boyfriend.lastHit = musicTime end

                receptor:animate(noteName .. " confirm", false)
                weeks.health = weeks.health
                    + (note.holdHealth or HOLD_HEALTH_GAIN) * weeks.healthGainMult * note.healthGainMult

                if note:getAnimName() == "end" then
                    HoldCover:hide(lane, 1)
                else
                    HoldCover:show(lane, 1)
                end

                self.droppedHold[lane] = nil
                self:consume(lane, i)
                i = i + 1
            end
        end
    end

    if input:released(inputKey) then
        receptor:animate(noteName, false)
        HoldCover:stop(lane, 1)
    end
end

function playfield:processAutomatic(lane, receptor)
    local noteName = NOTE_LIST[lane]
    local notes = self.notes[lane]
    local count = #notes

    local played = false
    local i = self.head[lane]

    -- A `while` loop, not a single note per frame: a frame spike used to make
    -- the opponent fall permanently behind the chart.
    while i <= count do
        local note = notes[i]

        if note.consumed then
            i = i + 1
        elseif note.time > musicTime then
            break
        else
            receptor:animate(noteName .. " confirm", false)
            self:onEnemyNoteHit(lane, note, receptor)

            if note.isSustain then
                if note:getAnimName() == "end" then
                    HoldCover:hide(lane, 2)
                else
                    HoldCover:show(lane, 2)
                end
            end

            self:consume(lane, i)
            played = true
            i = i + 1
        end
    end

    if not played and not receptor:isAnimated() then
        receptor:animate(noteName, false)
    end
end

function playfield:update(dt)
    local currentTime = musicTime
    local window = cullWindow()
    local minTime = currentTime - window
    local maxTime = currentTime + window
    local emitLimit = currentTime + ONCOMING_LEAD_MS

    local scroll = PIXELS_PER_MS * weeks.speed * scrollDirection()

    self.visibleWindow = window

    for lane = 1, self.laneCount do
        local receptor = self.receptors[lane]
        local notes = self.notes[lane]
        local count = #notes
        local receptorY = self.receptorY[lane]

        receptor:update(dt)

        -- Reposition everything that could be on screen.
        for i = self.head[lane], count do
            local note = notes[i]

            if note.time > maxTime then break end

            if not note.consumed and note.time >= minTime then
                note.y = receptorY - scroll * (currentTime - note.time)
            end
        end

        -- onNoteOncoming, driven by its own forward-only cursor so each note
        -- fires exactly once and we never rescan the lane.
        local emitHead = self.emitHead[lane]
        while emitHead <= count do
            local note = notes[emitHead]

            if note.time > emitLimit then break end

            if not note.emitted then
                note.emitted = true
                self:callEvent("onNoteOncoming",
                    eventCreator:onNoteOncoming(note.ver, note.col, note))
            end

            emitHead = emitHead + 1
        end
        self.emitHead[lane] = emitHead

        if self.playable then
            -- Cutscenes hold the song at a standstill; without this, keys
            -- pressed during one rack up ghost misses.
            if weeks.isInCutscene then goto continue end

            self:processNoteMisses(lane)
            self:processInput(lane, receptor)
        else
            self:processAutomatic(lane, receptor)
        end

        ::continue::
    end
end

function playfield:draw()
    local window = self.visibleWindow or cullWindow()
    local minTime = musicTime - window
    local maxTime = musicTime + window

    -- Pixel noteskins ship as tiny (17x17) source frames, so they need the
    -- extra udraw() upscale that the rest of the pixel-mode UI (countdown,
    -- rating, NoteSplash -- see render.lua) already applies. Without it they
    -- render at native size, which reads as "the notes are too small".
    local usePixelScale = pixel and not settings.pixelPerfect

    love.graphics.push()
        love.graphics.translate(self.offsetX, 0)

        for i = 1, self.laneCount do
            if usePixelScale then
                self.receptors[i]:udraw(8, 8)
            else
                self.receptors[i]:draw()
            end
        end

        -- Lane by lane, far notes first so near notes land on top. Lanes never
        -- overlap horizontally, so no cross-lane sort is needed -- this drops
        -- a per-frame table allocation, a closure and an O(n log n) sort.
        for lane = 1, self.laneCount do
            local notes = self.notes[lane]
            local count = #notes
            local head = self.head[lane]

            local last = head - 1
            for i = head, count do
                if notes[i].time > maxTime then break end
                last = i
            end

            for i = last, head, -1 do
                local note = notes[i]
                if not note.consumed and note.time >= minTime then
                    if usePixelScale then
                        note:udraw(8, 8)
                    else
                        note:draw()
                    end
                end
            end
        end
    love.graphics.pop()
end

return playfield
