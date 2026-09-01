-- modules/game/Cover.lua
--
-- Hold covers (a.k.a. hold splashes): the sparkle that sits on a receptor for
-- as long as a sustain is being held. Each lane direction has its own
-- standalone atlas (holdCoverBlue/Green/Purple/Red, straight from the real
-- V-Slice source), each with three phases:
--
--   "start"  one frame, the pop-in
--   "hold"   the looping body, held for the length of the sustain
--   "end"    the release burst
--
-- Covers are owned per player (1 = boyfriend, 2 = enemy) and re-read their
-- receptor's position every frame, so they stay glued to the arrows through
-- downscroll, the vwoosh-in and anything a stage script does to a receptor.
--
-- Positions come from the playfield rather than globals: receptor.x is local
-- to the playfield's draw translate, so the on-screen x is
-- `receptor.x + playfield.offsetX` -- the same convention playfield:spawnSplash
-- uses for note splashes.

local cover = {}

local NOTE_LIST = CONSTANTS.WEEKS.NOTE_LIST

-- Nudge from the receptor's origin to the cover's. Each atlas lays its frames
-- out on a 300x400 canvas that isn't centred on the arrow, so this lines the
-- sparkle up with the middle of the receptor.
local OFFSET_X = -5
local OFFSET_Y = 35

-- Direction -> which standalone atlas/sprite file to use.
local DIR_TO_COLOR = {
    left = "Purple",
    down = "Blue",
    up = "Green",
    right = "Red",
}

cover.covers = {}
cover.images = {}
cover.sprLoaders = {}
cover.enabled = false

-- There is no pixel-art hold cover atlas (only pixelSplashes for tap notes),
-- and the HD one reads badly over 17x17 pixel arrows, so pixel stages go
-- without. Flip this if a pixel atlas ever gets added.
local function supported()
    return not pixel
end

local function playfieldFor(plr)
    if not weeks then return nil end
    if plr == 1 then return weeks.boyfriendPlayfield end
    return weeks.enemyPlayfield
end

function cover:get(lane, plr)
    if not self.enabled then return nil end
    local side = self.covers[plr]
    if not side then return nil end
    return side[lane]
end

function cover:reposition(lane, plr)
    local c = self:get(lane, plr)
    if not c then return end

    local field = playfieldFor(plr)
    if not field then return end

    local receptor = field.receptors[lane]
    if not receptor then return end

    c.x = receptor.x + field.offsetX + OFFSET_X
    c.y = receptor.y + OFFSET_Y
    -- Follow the receptor's fade so covers don't pop in over arrows that are
    -- still vwooshing on at the start of a song.
    c.alpha = receptor.alpha or 1
end

function cover:setup()
    self.covers = {}
    self.images = {}
    self.sprLoaders = {}
    self.enabled = supported()

    if not self.enabled then
        return
    end

    for _, color in pairs(DIR_TO_COLOR) do
        if not self.images[color] then
            self.images[color] = love.graphics.newImage(graphics.imagePath("holdCover" .. color))
            -- Each sprites/holdCover<Color>.lua file references
            -- HoldCover.image<Color> as its texture, so that global has to be
            -- in place before the loader chunk runs.
            self["image" .. color] = self.images[color]
            self.sprLoaders[color] = love.filesystem.load("sprites/holdCover" .. color .. ".lua")
        end
    end

    for plr = 1, 2 do
        self.covers[plr] = {}
        for lane = 1, 4 do
            local dir = NOTE_LIST[lane]
            local color = dir and DIR_TO_COLOR[dir]
            if color then
                local c = self.sprLoaders[color]()
                c.visible = false
                c.hiding = false
                c.holding = false
                -- The converted holdCover atlases pack frames with zero gutter
                -- (verified: adjacent SubTextures share edges exactly), so the
                -- default linear filter bleeds neighbouring frames' pixels in
                -- at every crop edge, showing up as a faint box around the
                -- sparkle. Nearest filtering avoids sampling across the seam.
                c:setAntialiasing(false)
                self.covers[plr][lane] = c
                self:reposition(lane, plr)
            end
        end
    end
end

function cover:update(dt)
    if not self.enabled then return end

    for plr = 1, 2 do
        for lane = 1, 4 do
            local c = self.covers[plr][lane]
            if c and c.visible then
                self:reposition(lane, plr)
                c:update(dt)
            end
        end
    end
end

-- True while the release burst is playing. Kept returning `hiding` because
-- that is what the old call sites (stage scripts) already expect.
function cover:getVisibility(lane, plr)
    local c = self:get(lane, plr)
    return c and c.hiding or false
end

function cover:isHolding(lane, plr)
    local c = self:get(lane, plr)
    return c and c.holding or false
end

-- Start (or restart) a cover. Idempotent: calling it every frame of a hold,
-- which is what the sustain loop does, leaves the looping body alone.
function cover:show(lane, plr)
    local c = self:get(lane, plr)
    if not c then return end
    if c.visible and not c.hiding then return end

    c.hiding = false
    c.holding = true
    c.visible = true
    self:reposition(lane, plr)

    c:animate("start", false, function()
        c:animate("hold", true)
    end)
end

-- Natural end of a hold: play the release burst, then disappear.
function cover:hide(lane, plr)
    local c = self:get(lane, plr)
    if not c then return end
    if not c.visible or c.hiding then return end

    c.hiding = true
    c.holding = false

    c:animate("end", false, function()
        c.visible = false
        c.hiding = false
    end)
end

-- Dropped hold (let go early, or the sustain was missed): the cover vanishes
-- outright, no release burst. A burst already in flight is left to finish so
-- releasing on the last segment still pops.
function cover:stop(lane, plr)
    local c = self:get(lane, plr)
    if not c then return end
    if c.hiding then return end

    c.visible = false
    c.holding = false
    c:animate("none", false)
end

function cover:stopAll()
    if not self.enabled then return end

    for plr = 1, 2 do
        for lane = 1, 4 do
            local c = self.covers[plr][lane]
            if c then
                c.visible = false
                c.hiding = false
                c.holding = false
                c:animate("none", false)
            end
        end
    end
end

function cover:draw()
    if not self.enabled then return end

    for plr = 1, 2 do
        for lane = 1, 4 do
            local c = self.covers[plr][lane]
            if c and c.visible then
                c:draw()
            end
        end
    end
end

function cover:clear()
    self.covers = {}
    self.images = {}
    self.sprLoaders = {}
    for _, color in pairs(DIR_TO_COLOR) do
        self["image" .. color] = nil
    end
    self.enabled = false
end

return cover
