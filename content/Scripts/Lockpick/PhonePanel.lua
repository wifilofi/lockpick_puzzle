local PhonePanel = {}
PhonePanel.__index = PhonePanel

local ACTIONS = {
    { id = "undo", label = "Undo", action = "undo" },
    { id = "hint", label = "Hint", action = "requestHint" },
    { id = "restart", label = "Restart", action = "restart", enabled = true },
    { id = "next-level", label = "Next Level", action = "advance" },
    { id = "phone-home", label = "Title", action = "showTitle" },
}

function PhonePanel.new(document, actions)
    local self = setmetatable({
        label = assert(document:GetElement("phone-label")),
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
    return self
end

function PhonePanel:showLabel()
    local id = self.hovered or self.focused
    local text = id and self.icons[id].label or "Lock controls"
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
    local icon = self.icons[id]
    if icon.enabled then self.actions[icon.action]() end
end

function PhonePanel:setEnabled(id, enabled)
    local icon = self.icons[id]
    if icon.enabled == enabled then return end
    assert(icon.element:SetClass("unavailable", not enabled))
    icon.enabled = enabled
end

function PhonePanel:update(round, canAdvance)
    self:setEnabled("undo", round:canUndo())
    self:setEnabled("hint", round:isReady())
    self:setEnabled("next-level", canAdvance)
    self:setEnabled("phone-home", round.result ~= nil)

    local restart = self.icons.restart
    if round.result then
        restart.label, restart.action = "Retry", "retry"
    else
        restart.label, restart.action = "Restart", "restart"
    end
    self:showLabel()
end

return PhonePanel
