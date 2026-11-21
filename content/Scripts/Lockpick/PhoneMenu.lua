local Levels = require("Scripts.Lockpick.Levels")

local PhoneMenu = {}
PhoneMenu.__index = PhoneMenu

local UNFOLD_SECONDS = 0.62
local ZOOM_SECONDS = 0.38
local CLOSE_SECONDS = 0.42
local CLOSED_SECONDS = 0.06

-- Positions are offsets from the gameplay phone's top-left corner.
local GAME = {xvw = 0, xvh = 0, yvh = 0, scale = 1}
local INTRO = {xvw = -50.55, xvh = 29.57, yvh = -33.69, scale = 0.87}
local MENU = {xvw = -50.55, xvh = -10.16, yvh = -41.49, scale = 2.3882}

local function mix(from, to, progress)
    return from + (to - from) * progress
end

local function smoothstep(value)
    return value * value * (3 - 2 * value)
end

local function opacity(element, value)
    assert(element:SetProperty("opacity", ("%.4f"):format(value)))
end

function PhoneMenu:setPose(from, to, progress)
    local xvw = mix(from.xvw, to.xvw, progress)
    local xvh = mix(from.xvh, to.xvh, progress)
    local yvh = mix(from.yvh, to.yvh, progress)
    local scale = mix(from.scale, to.scale, progress)
    -- Resize the layout so the font atlas uses the visible glyph size.
    assert(self.anchor:SetProperty("right", ("%.4fvw"):format(-0.55 - xvw)))
    assert(self.anchor:SetProperty("bottom", ("%.4fvh"):format(-53.18 - yvh)))
    assert(self.zoom:SetProperty("left", ("%.4fvh"):format(xvh)))
    assert(self.zoom:SetProperty("width", ("%.4fvh"):format(52.34 * scale)))
    assert(self.zoom:SetProperty("height", ("%.4fvh"):format(111.49 * scale)))
    assert(self.zoom:SetProperty("font-size", ("%.4fvh"):format(scale)))
end

function PhoneMenu:setHinge(progress)
    local backVisible = progress < 0.5
    if self.backVisible ~= backVisible then
        self.backVisible = backVisible
        assert(self.back:SetClass("hidden", not backVisible))
        assert(self.front:SetClass("hidden", backVisible))
    end
    local height = math.cos(math.pi * (1 - progress))
    assert(self.hinge:SetProperty("transform", ("scaleY(%.5f)"):format(height)))
end

function PhoneMenu.new(document, startLevel)
    local self = setmetatable({
        startLevel = startLevel,
        anchor = assert(document:GetElement("phone-anchor")),
        zoom = assert(document:GetElement("phone-zoom")),
        hinge = assert(document:GetElement("phone-hinge")),
        front = assert(document:GetElement("phone-front")),
        back = assert(document:GetElement("phone-back")),
        backdrop = assert(document:GetElement("title-backdrop")),
        menuScreen = assert(document:GetElement("phone-menu")),
        playScreen = assert(document:GetElement("phone-play")),
        home = assert(document:GetElement("title-menu")),
        levelSelect = assert(document:GetElement("title-level-select")),
        phase = "unfolding",
        elapsed = 0,
    }, PhoneMenu)
    self:setPose(INTRO, INTRO, 0)
    self:setHinge(0)

    local list = assert(document:GetElement("title-level-list"))
    local levels = Levels.menuLevels()
    local buttons = {}
    for index in ipairs(levels) do
        buttons[index] = ('<button id="title-level-%d" class="title-action"></button>'):format(index)
    end
    assert(list:SetInnerRml(table.concat(buttons)))
    for index, level in ipairs(levels) do
        local id = "title-level-" .. index
        assert(assert(document:GetElement(id)):SetText(level.name))
        assert(document:On(id, "click", function() self:play(level.id) end))
    end
    assert(document:On("title-play", "click", function() self:play(Levels.firstId) end))
    assert(document:On("title-choose-level", "click", function()
        if self.phase == "menu" then self:showLevels(true) end
    end))
    assert(document:On("title-back", "click", function()
        if self.phase == "menu" then self:showLevels(false) end
    end))
    assert(document:On("title-exit", "click", function() self:exit() end))
    return self
end

function PhoneMenu:showLevels(visible)
    assert(self.home:SetClass("hidden", visible))
    assert(self.levelSelect:SetClass("hidden", not visible))
end

function PhoneMenu:isPlaying()
    return self.phase == "playing"
end

function PhoneMenu:beginZoom(phase, from, to)
    self.phase, self.elapsed, self.from, self.to = phase, 0, from, to
    assert(self.anchor:SetClass("switching", true))
    assert(self.backdrop:SetClass("hidden", false))
    assert(self.menuScreen:SetClass("hidden", false))
    assert(self.playScreen:SetClass("hidden", from == INTRO or to == INTRO))
    self:drawZoom(0)
end

function PhoneMenu:play(id)
    if self.phase ~= "menu" or not Levels.hasLevel(id) then return end
    self.startLevel(id)
    self:beginZoom("zoomingOut", MENU, GAME)
end

function PhoneMenu:exit()
    if self.phase == "menu" then self:beginZoom("zoomingOut", MENU, INTRO) end
end

function PhoneMenu:show()
    if not self:isPlaying() then return end
    self:showLevels(false)
    self:beginZoom("zoomingIn", GAME, MENU)
end

function PhoneMenu:drawZoom(progress)
    self:setPose(self.from, self.to, progress)
    local menuWeight = self.phase == "zoomingIn" and progress or 1 - progress
    opacity(self.backdrop, (self.from == INTRO or self.to == INTRO) and 1 or menuWeight)
    opacity(self.menuScreen, math.max(0, menuWeight * 2 - 1))
    opacity(self.playScreen, math.max(0, 1 - menuWeight * 2))
end

function PhoneMenu:update(dt)
    if self.phase == "menu" or self.phase == "quitting" or self:isPlaying() then return end
    self.elapsed = self.elapsed + dt
    if self.phase == "unfolding" then
        local progress = math.min(self.elapsed / UNFOLD_SECONDS, 1)
        self:setHinge(smoothstep(progress))
        if progress == 1 then
            assert(self.hinge:SetProperty("transform", "none"))
            self:beginZoom("zoomingIn", INTRO, MENU)
        end
        return
    end
    if self.phase == "closing" then
        local progress = math.min(self.elapsed / CLOSE_SECONDS, 1)
        self:setHinge(1 - smoothstep(progress))
        if progress == 1 then self.phase, self.elapsed = "closed", 0 end
        return
    end
    if self.phase == "closed" then
        if self.elapsed >= CLOSED_SECONDS then
            self.phase = "quitting"
            Game.Quit()
        end
        return
    end

    local progress = math.min(self.elapsed / ZOOM_SECONDS, 1)
    self:drawZoom(smoothstep(progress))
    if progress < 1 then return end
    if self.to == INTRO then
        assert(self.menuScreen:SetClass("hidden", true))
        self.phase, self.elapsed = "closing", 0
        return
    end

    local inMenu = self.phase == "zoomingIn"
    self.phase = inMenu and "menu" or "playing"
    assert(self.anchor:SetClass("switching", false))
    assert(self.menuScreen:SetClass("hidden", not inMenu))
    assert(self.playScreen:SetClass("hidden", inMenu))
    assert(self.backdrop:SetClass("hidden", not inMenu))
end

return PhoneMenu
