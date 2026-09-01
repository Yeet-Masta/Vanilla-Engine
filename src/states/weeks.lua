-- Gameplay Gamestate: plays through a song (or set of songs) with charts,
-- characters, and a stage. This file only holds the shared state and wires
-- together the pieces implemented in states/weeks/*.lua:
--
--   setup.lua     - enter/load/initUI/setNoteSprites/preloadIcon
--   chart.lua     - generateNotes/getSongID (reading chart+metadata files)
--   countdown.lua - the pre-song 3-2-1-GO countdown
--   events.lua    - processSongEvents (chart-driven camera/etc. events)
--   update.lua    - update/updateUI (the per-frame game loop)
--   scoring.lua   - onNoteRated/onNoteMissed/checkSongOver/endSong/onDeath
--   objects.lua   - add/get/getProps/getCharacter/remove/sort (scene graph)
--   render.lua    - renderStage/drawUI/draw

local weeks = {}

weeks._ratingTimers = {}
weeks.camTween, weeks.bumpTween = nil, nil

weeks._useAltAnims = false

weeks.healthlerp = 1
weeks.dying = false

weeks.noteSprites = nil

weeks.nps = {}
weeks.maxNPS = 0
weeks.ratingTextScale = 1

-- Shared "private" state that used to be file-local upvalues. They're kept
-- as fields (prefixed with `_`) instead, since weeks is a singleton
-- Gamestate and `self` inside its methods is always this same table -- so
-- these are just as private as a local, but reachable from every submodule.
weeks._isResetting = false
weeks._camZoomTween = nil
weeks._countdownFade = {0}
weeks._weekID = ""

weeks.UI_VISIBLE = true

weeks.weekStates = {
	sickCounter = 0,
	goodCounter = 0,
	badCounter = 0,
	shitCounter = 0,
	missCounter = 0,
	maxCombo = 0,
	score = 0
}

weeks.states = {
    sickCounter = 0,
    goodCounter = 0,
    badCounter = 0,
    shitCounter = 0,
    missCounter = 0,
    maxCombo = 0,
    combo = 0,
}
weeks.score = 0

weeks.songEvents = {}

weeks.songs = {}

weeks.smoothReset = true
weeks.currentSongNum = 1
weeks.difficulty = "normal"
weeks.songExt = ""
weeks.audioAppend = ""

quitPressed = false

CAM_LERP_POINT = { x = 0, y = 0 }

weeks.countdownStep = 1

require("states.weeks.setup")(weeks)
require("states.weeks.chart")(weeks)
require("states.weeks.countdown")(weeks)
require("states.weeks.events")(weeks)
require("states.weeks.update")(weeks)
require("states.weeks.scoring")(weeks)
require("states.weeks.objects")(weeks)
require("states.weeks.render")(weeks)

function weeks:debugKeyPressed(k)
end

function weeks:leave()
    if self.inst then self.inst:stop(); self.inst = false end
    if self.voicesBF then self.voicesBF:stop(); self.voicesBF = nil end
    if self.voicesEnemy then self.voicesEnemy:stop(); self.voicesEnemy = nil end

    NoteSplash:clear()
    HoldCover:clear()

    self.timer:clear()
end



return weeks