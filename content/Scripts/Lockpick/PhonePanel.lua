local PhonePanel = {}
PhonePanel.__index = PhonePanel

local RESULT_LABELS = {
    lost = "TROUBLE",
    won = "OPEN",
}

local ACTIONS = {
    { id = "undo", label = "Undo", action = "undo" },
    { id = "hint", label = "Hint", action = "requestHint" },
    { id = "restart", label = "Restart", action = "restart", enabled = true },
    { id = "next-level", label = "Next Level", action = "advance" },
    { id = "phone-home", label = "Menu", action = "showTitle" },
}

function PhonePanel.new(document, actions)
    local self = setmetatable({
        label = assert(document:GetElement("phone-label")),
        screen = assert(document:GetElement("phone-screen")),
        flash = assert(document:GetElement("phone-result-flash")),
        icons = {},
        actions = actions,
    }, PhonePanel)
    for _, definition in ipairs(ACTIONS) do
        local id = definition.id
        self.icons[id] = {
            element = assert(document:GetElement(id)),
            label = definition.label,
            action = definition.action,
            enabled = definition.enabled or false,
        }
        assert(document:On(id, "click", function() self:activate(id) end))
        assert(document:On(id, "mouseover", function() self:setPointed("hovered", id) end))
        assert(document:On(id, "mouseout", function() self:clearPointed("hovered", id) end))
        assert(document:On(id, "focus", function() self:setPointed("focused", id) end))
        assert(document:On(id, "blur", function() self:clearPointed("focused", id) end))
    end
    assert(document:On("phone-result-flash", "animationend", function() self:finishBlink() end))
    return self
end

function PhonePanel:showLabel()
    if self.blinking then return end
    local id = self.hovered or self.focused
    local text = RESULT_LABELS[self.result] or (id and self.icons[id].label) or "Lock controls"
    if self.displayedLabel == text then return end
    assert(self.label:SetText(text))
    self.displayedLabel = text
end

function PhonePanel:setPointed(source, id)
    self[source] = id
    self:showLabel()
end

function PhonePanel:clearPointed(source, id)
    if self[source] == id then self:setPointed(source, nil) end
end

function PhonePanel:activate(id)
    if self.blinking then return end
    local icon = self.icons[id]
    if icon.enabled then self.actions[icon.action]() end
end

function PhonePanel:setEnabled(id, enabled)
    local icon = self.icons[id]
    if icon.enabled == enabled then return end
    assert(icon.element:SetClass("unavailable", not enabled))
    icon.enabled = enabled
end

function PhonePanel:finishBlink()
    if not self.blinking then return end
    self.blinking = false
    assert(self.flash:SetClass("blinking", false))
    assert(self.screen:SetClass("result-pending", false))
    assert(self.screen:SetClass("result-visible", true))
    assert(self.screen:SetClass("victory", self.result == "won"))
    self:setEnabled("next-level", self.canAdvance)
    self:setEnabled("phone-home", true)
    self:showLabel()
end

function PhonePanel:update(round, canAdvance)
    self.canAdvance = canAdvance
    if self.result ~= round.result then
        self.result = round.result
        self.blinking = self.result ~= nil
        self.hovered, self.focused = nil, nil
        assert(self.screen:SetClass("result-visible", false))
        assert(self.screen:SetClass("victory", false))
        assert(self.screen:SetClass("result-pending", self.blinking))
        assert(self.flash:SetClass("blinking", self.blinking))
    end

    self:setEnabled("undo", round:canUndo())
    self:setEnabled("hint", round:isReady())
    self:setEnabled("next-level", not self.blinking and canAdvance)
    self:setEnabled("phone-home", not self.blinking)
    self.icons.restart.action = self.result and "retry" or "restart"
    self:showLabel()
end

return PhonePanel
