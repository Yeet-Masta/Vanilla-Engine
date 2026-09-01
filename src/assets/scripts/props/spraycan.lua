local spraycan = Object:extend()

local STATE_WAITING = 1
local STATE_ARCING = 2
local STATE_SHOT = 3
local STATE_IMPACTED = 4

-- The atlas' main timeline carries three labelled runs ("Can Start" 0-18,
-- "Hit Pico" 19-25, "Can Shot" 26-42). They have to be registered as real
-- animations: AnimateAtlas:play() only searches its animation list, so playing
-- a bare frame label silently did nothing and the can sat frozen on frame 0.
local CAN_ANIMATIONS = {
    {name = "Can Start", label = "Can Start"},
    {name = "Hit Pico",  label = "Hit Pico"},
    {name = "Can Shot",  label = "Can Shot"},
}

-- Offsets of the explosion relative to the can's own origin.
local EXPLOSION_OFFSET = {-25, -450}

function spraycan:new(x, y)
    self.sprite = graphics.newTextureAtlas()
    self.assetPath = "weekend1/images/spraycanAtlas"

    self.sprite:load(self.assetPath)

    for _, anim in ipairs(CAN_ANIMATIONS) do
        self.sprite:addAnimByFrameLabel(anim.name, anim.label, 24, false)
    end

    self.sprite:updateHitbox()

    self.sprite.onAnimationFinished:connect(function(name)
        if name == "Can Start" then
            self:playHitPico()
        elseif name == "Can Shot" then
            self.canVisible = false
            self.currentState = STATE_WAITING
        elseif name == "Hit Pico" then
            self:playHitExplosion()
            self.canVisible = false
            self.currentState = STATE_WAITING
        end
    end)

    self.explosion = graphics.newSparrowAtlas()
    self.explosion:load(EXTEND_LIBRARY("weekend1:spraypaintExplosionEZ"))
    self.explosion:addAnimByPrefix("idle", "explosion round 1 short0", 24, false)
    self.explosion.visible = false
    self.explosion.onAnimationFinished:connect(function()
        self.explosion.visible = false
    end)

    self.x = x or 0
    self.y = y or 0
    self.sprite.x = self.x
    self.sprite.y = self.y
    self.scroll = {x = 1, y = 1}
    self.offsets = {0, 0}
    self.angle = 0
    self.visible = true

    -- The can only becomes visible once Darnell actually kicks it up.
    self.canVisible = false
    self.currentState = STATE_WAITING
end

function spraycan:update(dt)
    self.sprite.x = self.x + self.offsets[1]
    self.sprite.y = self.y + self.offsets[2]
    self.sprite.flipX = self.flipX
    self.sprite.flipY = self.flipY
    self.sprite.angle = self.angle
    self.sprite.scroll = self.scroll
    self.sprite.visible = self.visible and self.canVisible

    self.explosion.x = self.x + self.offsets[1] + EXPLOSION_OFFSET[1]
    self.explosion.y = self.y + self.offsets[2] + EXPLOSION_OFFSET[2]
    self.explosion.scroll = self.scroll

    self.sprite:update(dt)
    self.explosion:update(dt)
end

function spraycan:draw(camera)
    if not self.visible then return end
    if self.canVisible then
        self.sprite:draw(camera)
    end
    if self.explosion.visible then
        self.explosion:draw(camera)
    end
end

function spraycan:playHitExplosion()
    self.explosion.visible = true
    self.explosion:play("idle", true, false)
end

function spraycan:playCanStart()
    self.canVisible = true
    self.currentState = STATE_ARCING
    self.sprite:play("Can Start", true, false)
end

function spraycan:playCanShot()
    self.canVisible = true
    self.currentState = STATE_SHOT
    self.sprite:play("Can Shot", true, false)
end

function spraycan:playHitPico()
    self.currentState = STATE_IMPACTED
    self.sprite:play("Hit Pico", true, false)
end

return spraycan
