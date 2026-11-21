local CardPanel = require("Scripts.Lockpick.CardPanel")
local PhonePanel = require("Scripts.Lockpick.PhonePanel")

local Hud = {}
Hud.__index = Hud

local HUD_STATUS = {
    openingStrike = "Setting the opening pin…",
    choose = "Choose a rotation card. + turns clockwise, - turns counterclockwise.",
    turning = "Turning the lock…",
    occupied = "Socket occupied",
    openingDoor = "Opening the door…",
}

function Hud.new(actions)
    local document = assert(UI.LoadDocument("game/UI/Lockpick.rml"))
    local self = setmetatable({
        document = document,
        keypad = assert(document:GetElement("card-panel")),
        phone = assert(document:GetElement("phone")),
        title = assert(document:GetElement("level")),
        attemptsLabel = assert(document:GetElement("attempts")),
        linkHelp = assert(document:GetElement("link-help")),
        springHelp = assert(document:GetElement("spring-help")),
        message = assert(document:GetElement("message")),
        resultDim = assert(document:GetElement("result-dim")),
        controls = assert(Input.GetContext("Lockpick")),
        actions = actions,
    }, Hud)

    self.cardPanel = CardPanel.new(document, self.controls, actions.selectCard)
    self.phonePanel = PhonePanel.new(document, actions)
    self.controls:BindAction("restart", PhysicalKey.R)
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
    local text = slot and "Try the highlighted key." or "No winning moves left. Use Undo or Restart."
    assert(self.message:SetText(text))
    self.displayedStatus = nil
end

function Hud:update(round, canAdvance)
    if self.displayedName ~= round.name then
        self.displayedName = round.name
        assert(self.title:SetText(round.name))
    end
    local hasLinks = #round.linkPairs > 0
    if self.displayedLinkHelp ~= hasLinks then
        self.displayedLinkHelp = hasLinks
        assert(self.linkHelp:SetClass("hidden", not hasLinks))
    end
    local hasSprings = #round.springs > 0
    if self.displayedSpringHelp ~= hasSprings then
        self.displayedSpringHelp = hasSprings
        assert(self.springHelp:SetClass("hidden", not hasSprings))
    end
    if self.displayedAttempts ~= round.attempts then
        self.displayedAttempts = round.attempts
        assert(self.attemptsLabel:SetText(("%d attempts left"):format(round.attempts)))
    end
    if self.displayedStatus ~= round.status then
        self.displayedStatus = round.status
        assert(self.message:SetText(HUD_STATUS[round.status] or ""))
    end
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
