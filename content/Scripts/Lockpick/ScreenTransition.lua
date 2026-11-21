local ScreenTransition = {}
ScreenTransition.__index = ScreenTransition

local COVER_SECONDS = 0.16
local REVEAL_SECONDS = 0.24

function ScreenTransition.new(document)
    return setmetatable({
        overlay = assert(document:GetElement("screen-fade")),
        phase = "revealing",
        elapsed = 0,
    }, ScreenTransition)
end

function ScreenTransition:isActive()
    return self.phase ~= nil
end

function ScreenTransition:cover(action)
    if self:isActive() then return false end
    self.phase, self.elapsed, self.onCovered = "covering", 0, action
    assert(self.overlay:SetClass("clear", false))
    return true
end

function ScreenTransition:update(dt)
    if not self.phase then return end
    if self.phase == "covered" then
        self.onCovered()
        self.onCovered = nil
        self.phase, self.elapsed = "revealing", 0
        return
    end

    local covering = self.phase == "covering"
    local duration = covering and COVER_SECONDS or REVEAL_SECONDS
    self.elapsed = self.elapsed + dt
    local progress = math.min(self.elapsed / duration, 1)
    local eased = progress * progress * (3 - 2 * progress)
    local opacity = covering and eased or (1 - eased)
    assert(self.overlay:SetProperty("opacity", ("%.4f"):format(opacity)))
    if progress < 1 then return end

    if covering then
        -- Render one fully black frame before resetting the round.
        self.phase = "covered"
    else
        self.phase = nil
        assert(self.overlay:SetClass("clear", true))
    end
end

return ScreenTransition
