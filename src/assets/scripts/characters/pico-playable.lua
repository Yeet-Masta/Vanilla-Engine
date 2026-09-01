local deathSpriteNene, deathSpriteRetry
local picoDeathExplosion
local singed
local picoFlickerTimers = {}

local sounds = {}

function Character:onCreate()
    gameoverSubstate.musicSuffix = "-pico"
    gameoverSubstate.blueBallSuffix = "-pico"

    local imagesToCache = {
        "shared:characters/Pico_Death_Retry",
        "shared:characters/NeneKnifeToss",
        "weekend1:characters/picoExplosionDeath/spritemap1",
        "weekend1:PicoBullet"
    }

    for _, imgPath in ipairs(imagesToCache) do
        local path = EXTEND_LIBRARY(imgPath)
        if imgPath:startsWith("weekend1:") and weeks._weekID ~= "weekend1" then
            goto continue
        end

        graphics.cache[path] = love.graphics.newImage(path .. CURRENT_IMAGE_FORMAT)

        ::continue::
    end

    if weeks._weekID == "weekend1" then
        for _, snd in ipairs({"singed_loop", "Gun_Prep", "Pico_Bonk", "shot1", "shot2", "shot3", "shot4"}) do
            sounds[snd] = love.audio.newSource("weekend1/sounds/" .. snd .. ".ogg", "static")
        end

        -- Pre-warm the explosion atlas so its symbol/registration data is
        -- parsed and cached now, not on the first actual death (which was
        -- causing the sprite to be invisible/mispositioned only the first time).
        local warmupExplosionAtlas = graphics.newTextureAtlas()
        warmupExplosionAtlas:load("weekend1/images/characters/picoExplosionDeath")
    end
end

function Character:postCreate()
    self.data.x = self.data.x + 15
    self.data.y = self.data.y + 30
end

function Character:play(name, forced, loop)
    if name == "burpShit" or name == "burpSmile" or name == "burpSmileLong" then
        if voicesBF then
            voicesBF:setVolume(1)
        end
    end

    if name == "firstDeath" then
        if gameoverSubstate.blueBallSuffix == "-pico-explode" then
            self:doExplosionDeath()
        else
            self:createDeathSprites()

            gameoverSubstate:add(deathSpriteRetry)
            gameoverSubstate:add(deathSpriteNene)
            deathSpriteNene:play("throw")
        end
    elseif name == "deathConfirm" then
        if picoDeathExplosion ~= nil then
            self:doExplosionConfirm()
        else
            deathSpriteRetry:play("confirm")
            deathSpriteRetry.x = deathSpriteRetry.x - 250
            deathSpriteRetry.y = deathSpriteRetry.y - 200

            return
        end
    end

    self.data:play(name, forced, loop)
end

function Character:createDeathSprites()
    deathSpriteRetry = graphics.newSparrowAtlas()
    deathSpriteRetry:load(EXTEND_LIBRARY("shared:characters/Pico_Death_Retry", false))
    if self.shader then
        deathSpriteRetry.shader = self.shader
    end
    deathSpriteRetry:addAnimByPrefix("idle", "Retry Text Loop0", 24, true)
    deathSpriteRetry:addAnimByPrefix("confirm", "Retry Text Confirm0", 24, false)

    deathSpriteRetry.x = self.data.x + 100
    deathSpriteRetry.y = self.data.y + 100

    deathSpriteRetry.zIndex = self.data.zIndex + 5
    deathSpriteRetry.visible = false

    deathSpriteNene = graphics.newSparrowAtlas()
    local gf = girlfriend
    deathSpriteNene:load(EXTEND_LIBRARY("shared:characters/NeneKnifeToss", false))
    deathSpriteNene.x = gf.x - 50
    deathSpriteNene.y = gf.y - 180
    deathSpriteNene.zIndex = self.data.zIndex - 5
    deathSpriteNene:addAnimByPrefix("throw", "knife toss0", 24, false)
    deathSpriteNene.visible = true
    deathSpriteNene.onAnimationFinished:connect(function(name)
        deathSpriteNene.visible = false
    end)
end

function Character:onSongRetry()
    gameoverSubstate.musicSuffix = "-pico"
    gameoverSubstate.blueBallSuffix = "-pico"

    picoDeathExplosion = nil
    if singed then
        singed:stop()
    end
    self:cancelMissFlicker()
end

local function randomFloat(min, max)
    return min + love.math.random() * (max - min)
end

function Character:onNoteHit(event)
    if event.noteType == "hey" then
        self.data.holdTimer = 0
        self:play("hey", true, false)
    elseif event.noteType == "cheer" then
        self.data.holdTimer = 0
        self:play("cheer", true, false)
    elseif event.noteType == "censor" then
        self.data.holdTimer = 0
        self.data:play(CONSTANTS.WEEKS.ANIM_LIST[event.direction] .. "-censor", true, false)
        return
    elseif event.noteType == "weekend-1-cockgun" then
        self.data.holdTimer = 0
        self:playCockGunAnim()
    elseif event.noteType == "weekend-1-firegun" then
        self.data.holdTimer = 0
        self:playFireGunAnim()
    end
end

function Character:onNoteMiss(event)
    if event.noteType == "weekend-1-cockgun" then
    elseif event.noteType == "weekend-1-firegun" then
        self:playCanExplodeAnim()
    end
end

function Character:playCanExplodeAnim()
    self.data:play("shootMISS")
    audio.playSound(sounds["Pico_Bonk"])
end

function Character:playCockGunAnim()
    self.data:play("cock", true, false)
    audio.playSound(sounds["Gun_Prep"])
end

function Character:playFireGunAnim()
    self.data:play("shoot", true, false)
    audio.playSound(sounds["shot" .. love.math.random(1, 4)])
end

function Character:onAnimationFrame(name, frameNumber, _)
    if name == "firstDeath" and frameNumber == 36 then
        if deathSpriteRetry ~= nil then
            deathSpriteRetry:play("idle", true, true)
            deathSpriteRetry:updateHitbox()
            deathSpriteRetry.visible = true

            deathSpriteRetry.x = self.data.x + 170
            deathSpriteRetry.y = self.data.y - 105
        end

        gameoverSubstate:startDeathMusic(1, false)
        boyfriend:play("deathLoop", true, true)
    end

    if name == "firstDeath" and frameNumber == 21 then
        hapticUtil:vibrate(0, 0.1, 0.1, 1)
    end

    if name == "deathLoop" and ((frameNumber - 1) % 2 == 0) then
        local randomAmplitude = randomFloat(0.1, 0.5)
        local randomDuration = randomFloat(0.1, 0.3)
        hapticUtil:vibrate(0, randomDuration, randomAmplitude)
    end
end

function Character:onAnimationFinished(name)
    if name == "shootMISS" and weeks:getHealth() > 0 and not self.data.isDead then
        self:startMissFlicker()
    end
end

-- Pico flickers after eating a can: 30 flips at 1/30s, then 30 more at 1/60s.
function Character:startMissFlicker()
    self:cancelMissFlicker()

    local function flip()
        self.data.visible = not self.data.visible
    end

    table.insert(picoFlickerTimers, Timer.every(1 / 30, flip, 30))
    table.insert(picoFlickerTimers, Timer.after(30 / 30, function()
        self.data.visible = true
        table.insert(picoFlickerTimers, Timer.every(1 / 60, flip, 30))
        table.insert(picoFlickerTimers, Timer.after(30 / 60, function()
            self.data.visible = true
        end))
    end))
end

-- Every handle has to be tracked: a death landing mid-flicker would otherwise
-- leave a pending timer to flip Pico back into view over the explosion.
function Character:cancelMissFlicker()
    for i = #picoFlickerTimers, 1, -1 do
        Timer.cancel(picoFlickerTimers[i])
        picoFlickerTimers[i] = nil
    end
    self.data.visible = true
end

function Character:doExplosionDeath()
    self:cancelMissFlicker()
    hapticUtil:vibrate(0, 0.5)

    Timer.after(1.85, function()
        hapticUtil:vibrate(0, 0.1, 0.1, 1)
    end)

    picoDeathExplosion = graphics.newTextureAtlas()
    picoDeathExplosion:load("weekend1/images/characters/picoExplosionDeath")
    picoDeathExplosion.x = self.data.x - 250
    picoDeathExplosion.y = self.data.y - 250
    picoDeathExplosion.zIndex = 1000
    picoDeathExplosion.onAnimationFinished:connect(function(n)
        self:onExplosionFinishAnim(n)
    end)
    picoDeathExplosion.visible = true
    self.data.visible = false

    gameoverSubstate:add(picoDeathExplosion)
    gameoverSubstate:sort()

    Timer.after(3, function()
        self:afterPicoDeathExplosionIntro()
    end)

    picoDeathExplosion:play("intro", true, false)
end

function Character:afterPicoDeathExplosionIntro(tmr)
    gameoverSubstate:startDeathMusic(1, false)

    singed = singed or love.audio.newSource("weekend1/sounds/singed_loop.ogg", "static")
    singed:setLooping(true)
    singed:play()
end

function Character:doExplosionConfirm()
    picoDeathExplosion:play("Confirm")
    if singed then
        singed:stop()
        singed = nil
    end
end

function Character:onExplosionFinishAnim(label)
    if label == "intro" then
        picoDeathExplosion:play("Loop Start", true, true)
    end
end

function Character:getDeathQuote()
    local dadID = weeks.enemy and weeks.enemy._data and weeks.enemy.id or "dad"

    if dadID == "tankman" then
        return "week7/sounds/jeffGameover-pico/jeffGameover-" .. love.math.random(1, 10) .. ".ogg"
    else
        return nil
    end
end