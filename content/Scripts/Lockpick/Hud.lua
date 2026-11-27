local CardPanel = require("Scripts.Lockpick.CardPanel")
local PhonePanel = require("Scripts.Lockpick.PhonePanel")

local Hud = {}
Hud.__index = Hud

function Hud.new(actions)
    local document = assert(UI.LoadDocument("game/UI/Lockpick.rml"))
    local self = setmetatable({
        document = document,
        keypad = assert(document:GetElement("card-panel")),
        phone = assert(document:GetElement("phone")),
        resultDim = assert(document:GetElement("result-dim")),
        fpsLabel = assert(document:GetElement("fps-counter")),
        fpsVisible = false,
        fpsFrames = 0,
        fpsElapsed = 0,
        controls = assert(Input.GetContext("Lockpick")),
        actions = actions,
    }, Hud)

    self.cardPanel = CardPanel.new(document, self.controls, actions.selectCard)
    self.phonePanel = PhonePanel.new(document, actions)
    self.controls:BindAction("restart", PhysicalKey.R)
    self.controls:BindAction("toggle-fps", PhysicalKey.Tab)
    return self
end

function Hud:show()
    assert(self.document:Show("interactive"))
end

function Hud:queueEntrance(keypadOnly)
    self.entrancePanels = keypadOnly and {self.keypad} or {self.keypad, self.phone}
    for _, panel in ipairs(self.entrancePanels) do
        assert(panel:SetClass("entering", false))
        assert(panel:SetClass("below-screen", true))
    end
    -- Let RmlUi apply the offscreen state before restarting the animation.
    self.entranceFrames = 2
end

function Hud:updateEntrance()
    if not self.entranceFrames then return end
    self.entranceFrames = self.entranceFrames - 1
    if self.entranceFrames > 0 then return end

    self.entranceFrames = nil
    for _, panel in ipairs(self.entrancePanels) do
        assert(panel:SetClass("below-screen", false))
        assert(panel:SetClass("entering", true))
    end
end

function Hud:updateFps()
    if self.controls:Pressed("toggle-fps") then
        self.fpsVisible = not self.fpsVisible
        self.fpsFrames = 0
        self.fpsElapsed = 0
        assert(self.fpsLabel:SetClass("hidden", not self.fpsVisible))
        if self.fpsVisible then assert(self.fpsLabel:SetText("FPS ...")) end
    end
    if not self.fpsVisible then return end

    local frameTime = Time.RealDelta()
    if frameTime <= 0 then return end
    self.fpsFrames = self.fpsFrames + 1
    self.fpsElapsed = self.fpsElapsed + frameTime
    if self.fpsElapsed >= 0.25 then
        assert(self.fpsLabel:SetText(("%.0f FPS"):format(self.fpsFrames / self.fpsElapsed)))
        self.fpsFrames = 0
        self.fpsElapsed = 0
    end
end

function Hud:pollInput()
    if self.controls:Pressed("restart") then
        self.actions.restart()
        return true
    end
    self.cardPanel:pollInput()
    return false
end

function Hud:showHint(slot)
    self.cardPanel:setHint(slot)
end

function Hud:highlightedKey()
    return self.cardPanel:highlightedKey()
end

function Hud:clearKeyPreview()
    self.cardPanel:clearKeyPreview()
end

function Hud:update(round, canAdvance)
    if self.outcome ~= round.result then
        local wasWon = self.outcome == "won"
        local won = round.result == "won"
        self.outcome = round.result
        assert(self.resultDim:SetClass("dimmed", self.outcome ~= nil))
        if won then
            assert(self.keypad:SetClass("entering", false))
            assert(self.keypad:SetClass("retracted", true))
        elseif wasWon then
            self:queueEntrance(true)
            assert(self.keypad:SetClass("retracted", false))
        end
    end
    self.phonePanel:update(round, canAdvance)
    self.cardPanel:update(round.hand, round.handSlots, round.cardCount)
end

return Hud
