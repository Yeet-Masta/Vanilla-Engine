local healthbar = Object:extend()

local scoreDisplays = {}

function healthbar:new(p1, p2)
    if #scoreDisplays == 0 then
        local list = love.filesystem.getDirectoryItems("game/scoredisplays")
        --table.insert(scoreDisplays, love.filesystem.load())
        for i, name in ipairs(list) do
            scoreDisplays[name] = love.filesystem.load("game/scoredisplays/" .. name)()
        end
    end
    self.p1Colors = {0, 1, 0}
    self.p2Colors = {1, 0, 0}

    local p1IconId = p1 or (weeks.enemy and weeks.enemy.healthIcon) or "dad"
    local p2IconId = p2 or (weeks.boyfriend and weeks.boyfriend.healthIcon) or "boyfriend"

    self.p1Icon = weeks:preloadIcon(p1IconId, p1IconId, (weeks.enemy and weeks.enemy.healthIconScale) or 1, weeks.enemy and weeks.enemy.healthIconIsPixel)
    self.p2Icon = weeks:preloadIcon(p2IconId, p2IconId, (weeks.boyfriend and weeks.boyfriend.healthIconScale) or 1, weeks.boyfriend and weeks.boyfriend.healthIconIsPixel)

    if settings.colouredHealthbar then
        self.p1Colors = self.p1Icon.useMostCommonColor
        self.p2Colors = self.p2Icon.useMostCommonColor
    end

    self.p1Icon.sizeX, self.p1Icon.sizeY = 1.5, 1.5
    self.p2Icon.sizeX, self.p2Icon.sizeY = -1.5, 1.5

    self.width = 1000
    self.height = 25

    self.x = -(self.width / 2)
    self.y = not settings.downscroll and 350 or -400

    self.p1Icon.y = self.y
    self.p2Icon.y = self.y
end

function healthbar:update(dt)
    self.p1Icon.x = self.x + self.width - 75 - weeks.healthLerp * (self.width/2)
    self.p2Icon.x = self.x + self.width + 75 - weeks.healthLerp * (self.width/2)

    if weeks.conductor.onBeat then
        self.p1Icon.sizeX, self.p1Icon.sizeY = 1.75, 1.75
        self.p2Icon.sizeX, self.p2Icon.sizeY = -1.75, 1.75
    end

    self.p1Icon.sizeX, self.p1Icon.sizeY = util.coolLerp(self.p1Icon.sizeX, 1.5, 0.1), self.p1Icon.sizeX
	self.p2Icon.sizeX, self.p2Icon.sizeY = util.coolLerp(self.p2Icon.sizeX, -1.5, 0.1), -self.p2Icon.sizeX
end

function healthbar:draw(hudfade)
    love.graphics.push()
        love.graphics.translate(1280/2, 720/2)
        love.graphics.scale(0.7, 0.7)
        love.graphics.scale(uiCam.zoom, uiCam.zoom)
        love.graphics.translate(uiCam.x, uiCam.y)
        graphics.setColor(1, 1, 1, hudfade)

        graphics.setColor(self.p2Colors[1], self.p2Colors[2], self.p2Colors[3], hudfade)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
        graphics.setColor(self.p1Colors[1], self.p1Colors[2], self.p1Colors[3], hudfade)
        love.graphics.rectangle("fill", -self.x, self.y, -weeks.healthLerp * (self.width/2), self.height)
        graphics.setColor(0, 0, 0, hudfade)
        love.graphics.setLineWidth(8)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
        love.graphics.setLineWidth(1)
        graphics.setColor(1, 1, 1, hudfade)

        self.p1Icon:draw()
        self.p2Icon:draw()

        self:drawScoringText(hudfade)
    love.graphics.pop()
end

function healthbar:drawScoringText(visibility)
    visibility = visibility or 1

    local text = scoring.generateScoringText(weeks)

    local colourOutline = {0, 0, 0, visibility}
    local colourInline = {1, 1, 1, visibility}

    local offsetX, offsetY = -100, 50
    local x = self.x + offsetX
    local y = self.y + offsetY
    local format = "center"

    local mode = settings.scoringType

    if mode == "VSlice" then
        x = 300 + offsetX
        y = 400 + offsetY
        if settings.downscroll then
            y = y - 750 - 50
        else
            y = y - 60
        end
        format = "left"
    elseif mode == "Minimal" then
        x = x - 35
    end

    local ratingTextScale = weeks.ratingTextScale or 1

    local lastFont = love.graphics.getFont()
    love.graphics.push()
        if mode == "Psych" then
            love.graphics.setFont(psychScoringFont)
            love.graphics.translate(
                -(psychScoringFont:getWidth(text) * (ratingTextScale - 1)) / 2,
                -(psychScoringFont:getHeight(text) * (ratingTextScale - 1))
            )
        else
            love.graphics.setFont(scoringFont)
        end
        uitextfColored(text, x, y, 1300, format, colourOutline, colourInline, 0, ratingTextScale, ratingTextScale)
    love.graphics.pop()
    love.graphics.setFont(lastFont)
end

return healthbar