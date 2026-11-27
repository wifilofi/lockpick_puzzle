local CardPanel = {}
CardPanel.__index = CardPanel

local SLOT_COUNT = 9

function CardPanel.new(document, controls, selectCard)
    local self = setmetatable({ keys = {}, controls = controls, selectCard = selectCard }, CardPanel)
    for slot = 1, SLOT_COUNT do
        local id = "card" .. slot
        self.keys[slot] = {
            button = assert(document:GetElement(id)),
            label = assert(document:GetElement("card-value" .. slot)),
        }
        assert(document:On(id, "click", function() selectCard(slot) end))
        assert(document:On(id, "mouseover", function() self.hovered = slot end))
        assert(document:On(id, "mouseout", function()
            if self.hovered == slot then self.hovered = nil end
        end))
        assert(document:On(id, "focus", function() self.focused = slot end))
        assert(document:On(id, "blur", function()
            if self.focused == slot then self.focused = nil end
        end))
        controls:BindAction(id, PhysicalKey["Num" .. slot])
    end
    return self
end

function CardPanel:pollInput()
    for slot = 1, self.count do
        if self.controls:Pressed("card" .. slot) then self.selectCard(slot) end
    end
end

function CardPanel:setHint(slot)
    if self.hintSlot == slot then return end
    if self.hintSlot then assert(self.keys[self.hintSlot].button:SetClass("hinted", false)) end
    if slot then assert(self.keys[slot].button:SetClass("hinted", true)) end
    self.hintSlot = slot
end

function CardPanel:highlightedKey()
    local hovered = self.keys[self.hovered]
    if hovered and hovered.value then return self.hovered end
    local focused = self.keys[self.focused]
    if focused and focused.value then return self.focused end
    return self.hintSlot
end

function CardPanel:clearKeyPreview()
    self.hovered, self.focused = nil, nil
    self:setHint(nil)
end

function CardPanel:update(hand, slots, count)
    self:setHint(nil)
    local values = {}
    for index, slot in ipairs(slots) do values[slot] = hand[index] end
    for slot, key in ipairs(self.keys) do
        if self.count ~= count then
            assert(key.button:SetClass("hidden", slot > count))
        end
        local value = values[slot] or false
        if key.value ~= value then
            key.value = value
            assert(key.button:SetClass("off", value == false))
            local text = value and ("%s%d"):format(value < 0 and "−" or "+", math.abs(value)) or ""
            assert(key.label:SetText(text))
        end
    end
    self.count = count
end

return CardPanel
