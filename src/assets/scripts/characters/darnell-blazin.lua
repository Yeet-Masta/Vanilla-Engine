function Character:onCreate()
    self.data.danceEvery = 0
    self.data:play("idle", true)

    gameoverSubstate.musicSuffix = "-pico"
    gameoverSubstate.blueBallSuffix = "-pico-gutpunch"
end

local cantUppercut = false

local function randomBool(chance)
    return love.math.random() * 100 < chance
end

function Character:onNoteHit(event)
    self.data.holdTimer = 0

    -- A landed opponent note means Darnell connected, which the fight reads as
    -- Pico eating it -- same reaction path as a miss.
    if event.mustHit == false then
        return self:onNoteMiss(event)
    end

    if not event.noteType or not event.noteType:startsWith("weekend-1-") then return end

    -- If Pico scrapes a note in at low health, Darnell may duck under the punch
    -- and wind up an uppercut instead.
    local shouldDoUppercutPrep = self:wasNoteHitPoorly(event) and self:isPlayerLowHealth() and randomBool(30)

    if shouldDoUppercutPrep then
        self:playUppercutPrepAnim()
        return
    end

    if cantUppercut then
        self:playPunchHighAnim()
        cantUppercut = false
        return
    end

    if event.noteType == "weekend-1-punchlow" then
        self:playHitLowAnim()
    elseif event.noteType == "weekend-1-punchlowblocked" then
        self:playBlockAnim()
    elseif event.noteType == "weekend-1-punchlowdodged" then
        self:playDodgeAnim()
    elseif event.noteType == "weekend-1-punchlowspin" then
        self:playHitSpinAnim()
    elseif event.noteType == "weekend-1-punchhigh" then
        self:playHitHighAnim()
    elseif event.noteType == "weekend-1-punchhighblocked" then
        self:playBlockAnim()
    elseif event.noteType == "weekend-1-punchhighdodged" then
        self:playDodgeAnim()
    elseif event.noteType == "weekend-1-punchhighspin" then
        self:playHitSpinAnim()
    elseif event.noteType == "weekend-1-blockhigh" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-blocklow" then
        self:playPunchLowAnim()
    elseif event.noteType == "weekend-1-blockspin" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-dodgehigh" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-dodgelow" then
        self:playPunchLowAnim()
    elseif event.noteType == "weekend-1-dodgespin" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-hithigh" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-hitlow" then
        self:playPunchLowAnim()
    elseif event.noteType == "weekend-1-hitspin" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-picouppercutprep" then
    elseif event.noteType == "weekend-1-picouppercut" then
        self:playUppercutHitAnim()
    elseif event.noteType == "weekend-1-darnelluppercutprep" then
        self:playUppercutPrepAnim()
    elseif event.noteType == "weekend-1-darnelluppercut" then
        self:playUppercutAnim()
    elseif event.noteType == "weekend-1-idle" then
        self:playIdleAnim()
    elseif event.noteType == "weekend-1-fakeout" then
        self:playCringeAnim()
    elseif event.noteType == "weekend-1-taunt" then
        self:playPissedConditionalAnim()
    elseif event.noteType == "weekend-1-tauntforce" then
        self:playPissedAnim()
    elseif event.noteType == "weekend-1-reversefakeout" then
        self:playFakeoutAnim()
    end

    cantUppercut = false
end

function Character:play(name, force, loop)
    if name == "firstDeath" then
        Timer.after(1.25, function() self:afterPicoDeathGutPunchIntro() end)

        Timer.after(0.5, function()
            hapticUtil:vibrate(0, 0.1, 0.1, 1)

            Timer.after(0.6, function()
                hapticUtil:vibrate(0, 0.1, 0.1, 1)
            end)
        end)
    end

    self.data:play(name, force, loop)
end

function Character:afterPicoDeathGutPunchIntro()
    gameoverSubstate:startDeathMusic(1, false)
    self.data:play("deathLoop", true)
end

function Character:onNoteMiss(event)
    self.data.holdTimer = 0

    -- Darnell wound up an uppercut last note and Pico whiffed. Finish him.
    if self:getCurrentAnim() == "uppercutPrep" then
        self:playUppercutAnim()
        return
    end

    if self:willMissBeLethal(event) then
        self:playPunchLowAnim()
        return
    end

    if cantUppercut then
        self:playPunchHighAnim()
        return
    end

    if event.noteType == "weekend-1-punchlow" or event.noteType == "weekend-1-punchlowblocked" or event.noteType == "weekend-1-punchlowdodged" or event.noteType == "weekend-1-punchlowspin" then
        self:playPunchLowAnim()
    elseif event.noteType == "weekend-1-punchhigh" or event.noteType == "weekend-1-punchhighblocked" or event.noteType == "weekend-1-punchhighdodged" or event.noteType == "weekend-1-punchhighspin" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-blockhigh" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-blocklow" then
        self:playPunchLowAnim()
    elseif event.noteType == "weekend-1-blockspin" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-dodgehigh" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-dodgelow" then
        self:playPunchLowAnim()
    elseif event.noteType == "weekend-1-dodgespin" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-hithigh" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-hitlow" then
        self:playPunchLowAnim()
    elseif event.noteType == "weekend-1-hitspin" then
        self:playPunchHighAnim()
    elseif event.noteType == "weekend-1-picouppercutprep" then
        self:playHitHighAnim()
        cantUppercut = true
    elseif event.noteType == "weekend-1-picouppercut" then
        self:playDodgeAnim()
    elseif event.noteType == "weekend-1-darnelluppercutprep" then
        self:playUppercutPrepAnim()
    elseif event.noteType == "weekend-1-darnelluppercut" then
        self:playUppercutAnim()
    elseif event.noteType == "weekend-1-idle" then
        self:playIdleAnim()
    elseif event.noteType == "weekend-1-fakeout" then
        self:playCringeAnim()
    elseif event.noteType == "weekend-1-taunt" then
        self:playPissedConditionalAnim()
    elseif event.noteType == "weekend-1-tauntforce" then
        self:playPissedAnim()
    elseif event.noteType == "weekend-1-reversefakeout" then
        self:playFakeoutAnim()
    end
end

-- healthChange is already negative on a miss, so this has to be added, not
-- subtracted -- subtracting it made the check read "health + penalty".
function Character:willMissBeLethal(event)
    return weeks:getHealth() + (event.healthChange or 0) <= 0
end

function Character:onNoteGhostMiss(event)
    if self:willMissBeLethal(event) then
        -- Land the punch that finishes Pico off.
        self:playPunchLowAnim()
    elseif randomBool(50) then
        -- Pico flails; Darnell alternates dodging and blocking.
        self:playDodgeAnim()
    else
        self:playBlockAnim()
    end
end

function Character:onSongRetry()
    cantUppercut = false
    self:playIdleAnim()

    gameoverSubstate.musicSuffix = "-pico"
    gameoverSubstate.blueBallSuffix = "-pico-gutpunch"
end

function Character:getPico()
    return weeks.boyfriend
end

function Character:getCurrentAnim()
    local curAnim = self.data.sprite and self.data.sprite.curAnim
    return curAnim and curAnim.name or ""
end

function Character:moveToBack()
    local pico = self:getPico()
    self.data.zIndex = 2000
    if pico then pico.zIndex = 3000 end
    weeks:sort()
end

function Character:moveToFront()
    local pico = self:getPico()
    self.data.zIndex = 3000
    if pico then pico.zIndex = 2000 end
    weeks:sort()
end

function Character:isDarnellPreppingUppercut()
    return self:getCurrentAnim() == "uppercutPrep"
end

function Character:isDarnellInUppercut()
    local anim = self:getCurrentAnim()
    return anim == "uppercut" or anim == "uppercut-hold"
end

function Character:wasNoteHitPoorly(event)
    return event.judgement == "bad" or event.judgement == "shit"
end

function Character:isPlayerLowHealth()
    return weeks:getHealth() <= 0.3 * 2
end

local alternate = false

function Character:doAlternate()
    alternate = not alternate
    return alternate and "1" or "2"
end

function Character:playBlockAnim()
    self.data:play("block", true)
    weeks:getCamera():shake(0.002, 0.1)
    self:moveToBack()
end

function Character:playCringeAnim()
    self.data:play("cringe", true)
    self:moveToBack()
end

function Character:playDodgeAnim()
    self.data:play("dodge", true)
    self:moveToBack()
end

function Character:playIdleAnim()
    self.data:play("idle")
    self:moveToBack()
end

function Character:playFakeoutAnim()
    self.data:play("fakeout", true)
    self:moveToBack()
end

function Character:playUppercutPrepAnim()
    self.data:play("uppercutPrep", true)
    self:moveToFront()
end

function Character:playUppercutAnim(hit)
    self.data:play("uppercut", true)
    if hit then
        weeks:getCamera():shake(0.005, 0.25)
    end
    self:moveToFront()
end

function Character:playUppercutHitAnim()
    self.data:play("uppercutHit", true)
    weeks:getCamera():shake(0.005, 0.25)
    self:moveToBack()
end

function Character:playHitHighAnim()
    self.data:play("hitHigh", true)
    weeks:getCamera():shake(0.0025, 0.15)
    self:moveToBack()
end

function Character:playHitLowAnim()
    self.data:play("hitLow", true)
    weeks:getCamera():shake(0.0025, 0.15)
    self:moveToBack()
end

function Character:playHitSpinAnim()
    self.data:play("hitSpin", true, false)
    weeks:getCamera():shake(0.0025, 0.15)
    self:moveToBack()
end

function Character:playPunchHighAnim()
    local postfix = self:doAlternate()
    self.data:play("punchHigh" .. postfix, true)
    self:moveToFront()
end

function Character:playPunchLowAnim()
    local postfix = self:doAlternate()
    self.data:play("punchLow" .. postfix, true)
    self:moveToFront()
end

function Character:playPissedConditionalAnim()
    if self:getCurrentAnim() == "cringe" then
        self:playPissedAnim()
    else
        self:playIdleAnim()
    end
end

function Character:playPissedAnim()
    self.data:play("pissed", true)
    self:moveToBack()
end
