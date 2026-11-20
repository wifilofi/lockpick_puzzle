local CardPanel = require("Scripts.Lockpick.CardPanel")

local Hud = {}
Hud.__index = Hud

local HUD_STATUS = {
    openingStrike = "Setting the opening pin…",
    choose = "Choose a rotation card. + turns clockwise, - turns counterclockwise.",
    turning = "Turning the lock…",
    occupied = "Socket occupied",
    openingDoor = "Opening the door…",
}

local HUD_RESULTS = {
    won = "Door opened",
    lost = "Shock! That socket was occupied.",
}

function Hud.new(actions)
    local document = assert(UI.LoadDocument("game/UI/Lockpick.rml"))
    local self = setmetatable({
        document = document,
        title = assert(document:GetElement("level")),
        attemptsLabel = assert(document:GetElement("attempts")),
        linkHelp = assert(document:GetElement("link-help")),
        springHelp = assert(document:GetElement("spring-help")),
        message = assert(document:GetElement("message")),
        hintButton = assert(document:GetElement("hint")),
        undoButton = assert(document:GetElement("undo")),
        result = assert(document:GetElement("result")),
        resultText = assert(document:GetElement("outcome")),
        nextLevelButton = assert(document:GetElement("next-level")),
        controls = assert(Input.GetContext("Lockpick")),
        actions = actions,
    }, Hud)

    self.cardPanel = CardPanel.new(document, self.controls, actions.selectCard)
    assert(document:On("restart", "click", actions.restart))
    assert(document:On("replay", "click", actions.retry))
    assert(document:On("next-level", "click", actions.advance))
    assert(document:On("hint", "click", actions.requestHint))
    assert(document:On("undo", "click", actions.undo))
    self.controls:BindAction("restart", PhysicalKey.R)
    return self
end

function Hud:show()
    assert(self.document:Show("interactive"))
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
    local canHint = round:isReady()
    if self.displayedHintAvailable ~= canHint then
        self.displayedHintAvailable = canHint
        assert(self.hintButton:SetClass("hidden", not canHint))
    end
    local canUndo = round:canUndo()
    if self.displayedUndoAvailable ~= canUndo then
        self.displayedUndoAvailable = canUndo
        assert(self.undoButton:SetClass("hidden", not canUndo))
    end
    local outcome = HUD_RESULTS[round.result] or ""
    if self.displayedOutcome ~= outcome then
        self.displayedOutcome = outcome
        assert(self.resultText:SetText(outcome))
        assert(self.result:SetClass("hidden", outcome == ""))
    end
    if self.displayedNextLevel ~= canAdvance then
        self.displayedNextLevel = canAdvance
        assert(self.nextLevelButton:SetClass("hidden", not canAdvance))
    end
    self.cardPanel:update(round.hand, round.handSlots, round.cardCount)
end

return Hud
