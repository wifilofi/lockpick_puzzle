local RoundState = require("Scripts.Lockpick.RoundStates").Id

local PickHandView = {}
PickHandView.__index = PickHandView

local REST_DISTANCE = 0.67
local SHOCK_BLINK = 0.045
local BURN_RECOIL = 0.26

local function setPose(element, x, y, roll)
    assert(element:SetProperty("transform", ("translate(%.4fvh, %.4fvh) rotate(%.2fdeg)"):format(x, y, roll)))
end

function PickHandView.new(document, camera, contact)
    -- Project the contact on the fixed play camera. Offsets in viewport-height units
    -- keep the tip aligned when the window aspect ratio changes.
    local offset = contact - camera:GetWorldPosition()
    local depth = offset:Dot(camera:Forward())
    assert(depth > 0, "Pick contact is behind the play camera")
    local focalScale = 50 / (depth * math.tan(camera:GetComponent("Camera").fovY / 2))
    local hitY = 50 - offset:Dot(camera:Up()) * focalScale
    return setmetatable({
        hand = assert(document:GetElement("pick-hand-pivot")),
        art = assert(document:GetElement("pick-hand-art")),
        dropped = assert(document:GetElement("falling-pick-pivot")),
        hitX = offset:Dot(camera:Right()) * focalScale,
        hitY = hitY,
        restY = hitY + REST_DISTANCE * focalScale,
    }, PickHandView)
end

function PickHandView:setAppearance(appearance)
    if self.appearance == appearance then return end
    self.appearance = appearance
    assert(self.art:SetClass("zapped", appearance == "zapped"))
    assert(self.art:SetClass("burned", appearance == "burned"))
end

function PickHandView:reset()
    self:setAppearance("normal")
    assert(self.hand:SetClass("hidden", false))
    assert(self.dropped:SetClass("hidden", true))
    setPose(self.hand, self.hitX, self.restY, 0)
end

function PickHandView:update(round, phase, progress, elapsed)
    if phase == RoundState.STRIKE then
        setPose(self.hand, self.hitX, self.restY + (self.hitY - self.restY) * progress, 0)
    elseif phase == RoundState.RECOIL then
        local returned = math.min(progress * 2, 1)
        setPose(self.hand, self.hitX, self.hitY + (self.restY - self.hitY) * returned, 0)
        if progress == 1 and round.pendingResult == "won" then
            assert(self.hand:SetClass("hidden", true))
        end
    elseif phase == RoundState.SHOCK then
        local offsetX = math.sin(elapsed * 149) * 0.37
        local offsetY = math.sin(elapsed * 181) * 0.28
        self:setAppearance(math.floor(elapsed / SHOCK_BLINK) % 2 == 0 and "zapped" or "normal")
        setPose(self.hand, self.hitX + offsetX, self.hitY + offsetY, 0)
    elseif phase == RoundState.DROP then
        self:setAppearance("burned")
        local recoil = 1 - (1 - math.min(elapsed / BURN_RECOIL, 1)) ^ 3
        local handY = self.hitY + (self.restY + 1.39 - self.hitY) * recoil
        setPose(self.hand, self.hitX, handY, 0)
        assert(self.dropped:SetClass("hidden", progress == 1))
        setPose(self.dropped, self.hitX - 15 * progress, self.hitY - 4 * progress + 55 * progress ^ 2, -275 * progress)
        assert(self.dropped:SetProperty("opacity", ("%.4f"):format(1 - progress ^ 2)))
    end
end

return PickHandView
