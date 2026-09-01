local hasHidden = false

function Song:onCreate()
    -- File-locals survive a retry, so they have to be cleared here or the
    -- strumline layout is only applied on the very first attempt.
    hasHidden = false
end

function Song:onSongRetry()
    hasHidden = false
end

function Song:onUpdate(dt)
    if hasHidden then return end

    local enemyPlayfield = weeks.enemyPlayfield
    local boyfriendPlayfield = weeks.boyfriendPlayfield
    if not enemyPlayfield or not boyfriendPlayfield then return end

    self:hideOpponentStrumline(enemyPlayfield)
    self:centerPlayerStrumline(boyfriendPlayfield)
    hasHidden = true
end

function Song:hideOpponentStrumline(enemyPlayfield)
    for i = 1, enemyPlayfield.laneCount do
        enemyPlayfield.receptors[i].visible = false
    end
end

function Song:centerPlayerStrumline(boyfriendPlayfield)
    -- Matches the -410 + 165*i absolute layout middlescroll used before the
    -- playfield refactor, expressed as an offsetX against the new lane-relative
    -- receptor.x (165*(i-1), STRUM_X_OFFSET 0): 165*(i-1) + offsetX == -410 + 165*i
    -- solves to offsetX = -245.
    boyfriendPlayfield.offsetX = -245
end
