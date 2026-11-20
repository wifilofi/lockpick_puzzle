local CARD_SLOTS = 3

local Hud = {}
Hud.__index = Hud

local HUD_STATUS = {
    openingStrike = "Setting the opening pin…",
    choose = "Choose a rotation card. + turns clockwise.",
    turning = "Turning the lock…",
    occupied = "Socket occupied",
    openingDoor = "Opening the door…",
}

local HUD_RESULTS = {
    won = "Door opened",
    lost = "Shock! That socket was occupied.",
}

function Hud.new(selectCard, restart, retry)
    local document = assert(UI.LoadDocument("game/UI/Lockpick.rml"))
    local self = setmetatable({
        document = document,
        title = assert(document:GetElement("level")),
        attemptsLabel = assert(document:GetElement("attempts")),
        message = assert(document:GetElement("message")),
        result = assert(document:GetElement("result")),
        resultText = assert(document:GetElement("outcome")),
        cardButtons = {},
        visibleCards = {},
        controls = assert(Input.GetContext("Lockpick")),
        selectCard = selectCard,
        restart = restart,
    }, Hud)

    for slot = 1, CARD_SLOTS do
        local id = "card" .. slot
        self.cardButtons[slot] = assert(document:GetElement(id))
        assert(document:On(id, "click", function() selectCard(slot) end))
        self.controls:BindAction(id, PhysicalKey["Num" .. slot])
    end
    assert(document:On("restart", "click", restart))
    assert(document:On("replay", "click", retry))
    self.controls:BindAction("restart", PhysicalKey.R)
    return self
end

function Hud:show()
    assert(self.document:Show("interactive"))
end

function Hud:pollInput()
    if self.controls:Pressed("restart") then
        self.restart()
        return true
    end
    for slot = 1, CARD_SLOTS do
        if self.controls:Pressed("card" .. slot) then self.selectCard(slot) end
    end
    return false
end

function Hud:update(round)
    if self.displayedName ~= round.name then
        self.displayedName = round.name
        assert(self.title:SetText(round.name))
    end
    if self.displayedAttempts ~= round.attempts then
        self.displayedAttempts = round.attempts
        assert(self.attemptsLabel:SetText(("%d attempts left"):format(round.attempts)))
    end
    if self.displayedStatus ~= round.status then
        self.displayedStatus = round.status
        assert(self.message:SetText(HUD_STATUS[round.status] or ""))
    end
    local outcome = HUD_RESULTS[round.result] or ""
    if self.displayedOutcome ~= outcome then
        self.displayedOutcome = outcome
        assert(self.resultText:SetText(outcome))
        assert(self.result:SetClass("hidden", outcome == ""))
    end
    for slot, button in ipairs(self.cardButtons) do
        local turns = round.hand[slot]
        local visible = turns or false
        if self.visibleCards[slot] ~= visible then
            self.visibleCards[slot] = visible
            assert(button:SetClass("hidden", not turns))
            if turns then
                assert(button:SetText(("[%d] %s%d"):format(slot, turns > 0 and "+" or "", turns)))
            end
        end
    end
end

return Hud
