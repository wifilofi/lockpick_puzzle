local RoundState = require("Scripts.Lockpick.RoundStates").Id

local LockView = {}
LockView.__index = LockView

local FLASH_TIME, FLASH_INTENSITY = 0.22, 5.5
local BULB_INTENSITY = 1.7
local LOCK_Y, SOCKET_RADIUS, PICK_Z = 0.44, 0.97, 0.27
local PICK_CONTACT = LOCK_Y - SOCKET_RADIUS - 0.36
local PICK_REST = PICK_CONTACT - 0.52
local DOOR_X, DOOR_Z = -2.3, -0.55
local CUBE = "engine/primitives/cube/model.obj"
local CYLINDER = "game/Meshes/Cylinder.obj"
local STEEL = "engine/primitives/default.material-instance.json"

local function material(name)
    return "game/Materials/" .. name .. ".material-instance.json"
end

local GALVANIZED_STEEL = material("GalvanizedSteel")
local DARK, RUSTED_STEEL, LIVE, SHOCK = material("Dark"), material("RustedSteel"), material("Live"), material("Shock")
local function v(x, y, z)
    return Vector3.new(x, y, z)
end

local function part(name, mesh, finish, position, scale, parent)
    return Scene.Spawn(name, {
        parent = parent,
        position = position,
        scale = scale,
        components = { MeshRenderer = { mesh = mesh, materialInstance = finish } },
    })
end

local function pointLight(name, position, color, range, parent)
    return Scene.Spawn(name, {
        parent = parent,
        position = position,
        components = { PointLight = { color = color, range = range, intensity = 0 } },
    })
end

local function setLightIntensity(light, intensity)
    light:SetComponent("PointLight", { intensity = intensity })
end

function LockView.new()
    local self = setmetatable({ sockets = {}, linkMarkers = {} }, LockView)
    self.hinge = Scene.Spawn("Door hinge", { position = v(DOOR_X, 0, DOOR_Z) })
    part("Door", CUBE, GALVANIZED_STEEL, v(2.3, 0.1, 0), v(4.6, 4.95, 0.30), self.hinge)
    part("Door trim", CUBE, STEEL, v(2.3, 2.42, 0.03), v(4.63, 0.09, 0.31), self.hinge)
    part("Lock escutcheon", CYLINDER, RUSTED_STEEL, v(2.3, LOCK_Y, 0.32), v(1.49, 1.49, 0.18), self.hinge)
    self.rotor = Scene.Spawn("Lock rotor", { parent = self.hinge, position = v(2.3, LOCK_Y, 0.57) })
    part("Lock plug", CYLINDER, GALVANIZED_STEEL, v(0, 0, 0), v(1.29, 1.29, 0.28), self.rotor)
    part("Keyway", CUBE, DARK, v(0, 0, 0.145), v(0.16, 0.43, 0.045), self.rotor)

    self.marker = part("Contact marker", CUBE, RUSTED_STEEL, v(0, LOCK_Y - 1.28, PICK_Z), v(0.39, 0.082, 0.10))
    self.pick = Scene.Spawn("Pick")
    part("Pick shaft", CUBE, STEEL, v(0, 0.13, 0), v(0.065, 0.46, 0.065), self.pick)
    part("Pick grip", CUBE, RUSTED_STEEL, v(0, -0.19, 0), v(0.145, 0.28, 0.13), self.pick)
    self.shockFlash = pointLight("Shock flash", v(0, LOCK_Y - SOCKET_RADIUS, 0.95), v(1, 0.78, 0.50), 3.9)
    return self
end

function LockView:buildSockets(count)
    if #self.sockets == count then return end
    for _, socket in ipairs(self.sockets) do
        Scene.Destroy(socket.mesh)
        Scene.Destroy(socket.pin)
        Scene.Destroy(socket.bulb)
    end
    self.sockets = {}
    for i = 1, count do
        local radians = (i - 1) * 2 * math.pi / count
        local x = SOCKET_RADIUS * math.sin(radians)
        local y = -SOCKET_RADIUS * math.cos(radians)
        self.sockets[i] = {
            mesh = part("Socket " .. i, CYLINDER, DARK, v(x, y, 0.158), v(0.148, 0.148, 0.045), self.rotor),
            pin = part("Live pin " .. i, CYLINDER, LIVE, v(x, y, 0.147), v(0.095, 0.095, 0.025), self.rotor),
            bulb = pointLight("Pin bulb " .. i, v(x, y, 0.40), v(0.15, 0.65, 1), 0.80, self.rotor),
        }
    end
end

function LockView:showLinks(pairs, count)
    if self.linkPairs == pairs and self.linkSocketCount == count then return end
    for _, marker in ipairs(self.linkMarkers) do Scene.Destroy(marker) end
    self.linkMarkers = {}
    self.linkPairs, self.linkSocketCount = pairs, count

    -- Give the two sockets in each pair the same number of dots.
    for group, pair in ipairs(pairs) do
        for _, socket in ipairs(pair) do
            local radians = (socket - 1) * 2 * math.pi / count
            local sine, cosine = math.sin(radians), math.cos(radians)
            for dot = 1, group do
                local offset = (dot - (group + 1) / 2) * 0.085
                local position = v(0.75 * sine + offset * cosine, -0.75 * cosine + offset * sine, 0.172)
                self.linkMarkers[#self.linkMarkers + 1] = part(
                    ("Link %d socket %d dot %d"):format(group, socket, dot),
                    CYLINDER, DARK, position, v(0.036, 0.036, 0.025), self.rotor)
            end
        end
    end
end

function LockView:setPin(index, live)
    local socket = self.sockets[index]
    if socket.live == live then return end
    socket.live = live
    local p = socket.pin:GetPosition()
    socket.pin:SetPosition(v(p.x, p.y, live and 0.211 or 0.125))
    setLightIntensity(socket.bulb, live and BULB_INTENSITY or 0)
end

function LockView:setAngle(steps)
    self.rotor:SetEulerAngles(v(0, 0, -steps * 360 / #self.sockets))
end

function LockView:setPick(x, y, z, roll)
    self.pick:SetPosition(v(x, y, z))
    self.pick:SetEulerAngles(v(0, 0, roll))
end

function LockView:setShock(index)
    if self.shockedSocket == index then return end
    if self.shockedSocket then
        self.sockets[self.shockedSocket].mesh:SetComponent("MeshRenderer", { materialInstance = DARK })
    end
    self.shockedSocket = index
    self.marker:SetComponent("MeshRenderer", { materialInstance = index and SHOCK or RUSTED_STEEL })
    if index then
        self.sockets[index].mesh:SetComponent("MeshRenderer", { materialInstance = SHOCK })
    end
    setLightIntensity(self.shockFlash, index and FLASH_INTENSITY or 0)
end

function LockView:restart(round)
    self:setShock(nil)
    self:buildSockets(round.socketCount)
    self:showLinks(round.linkPairs, round.socketCount)
    for index, live in ipairs(round.occupied) do self:setPin(index, live) end
    self.hinge:SetEulerAngles(v(0, 0, 0))
    self:setAngle(round.angleTo)
    self:setPick(0, PICK_REST, PICK_Z, 0)
end

function LockView:update(round, phase, progress, elapsed)
    if not phase then return end
    if phase == RoundState.TURN then
        self:setAngle(round.angleFrom + (round.angleTo - round.angleFrom) * (1 - (1 - progress)^3))
    elseif phase == RoundState.STRIKE then
        self:setPick(0, PICK_REST + (PICK_CONTACT - PICK_REST) * progress, PICK_Z, 0)
        if progress == 1 then
            self:setPin(round.target, round.occupied[round.target])
            local partner = round.linkPartners[round.target]
            if partner then self:setPin(partner, round.occupied[partner]) end
            if round:currentPhase() == RoundState.SHOCK then self:setShock(round.target) end
        end
    elseif phase == RoundState.RECOIL then
        self:setPick(0, PICK_CONTACT + (PICK_REST - PICK_CONTACT) * progress, PICK_Z, 0)
    elseif phase == RoundState.SHOCK then
        local flash = math.max(0, 1 - elapsed / FLASH_TIME)
        setLightIntensity(self.shockFlash, FLASH_INTENSITY * flash ^ 2)
        local shake = math.sin(progress * math.pi * 12) * 0.045
        self:setPick(shake, PICK_CONTACT, PICK_Z, shake * 140)
        if progress == 1 then self:setShock(nil) end
    elseif phase == RoundState.DROP then
        self:setPick(0.54 * progress, PICK_CONTACT - 2.8 * progress * progress, PICK_Z, -115 * progress)
    elseif phase == RoundState.OPEN then
        self.hinge:SetEulerAngles(v(0, 72 * (1 - (1 - progress)^3), 0))
    end
end

return LockView
