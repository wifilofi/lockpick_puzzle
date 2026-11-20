local RoundState = require("Scripts.Lockpick.RoundStates").Id

local LockView = {}
LockView.__index = LockView

local FLASH_TIME, FLASH_INTENSITY = 0.22, 5.5
local BULB_INTENSITY = 1.7
-- Unity stage pixels at the closed door, mapped to SRI's fixed play camera.
local PIXEL = 2 * 7.2 * math.tan(0.72 / 2) / 1080
local LOCK_Y = 0.05 + (540 - 379) * PIXEL
local SOCKET_RADIUS = 180.8 * PIXEL
local HINGE_TO_LOCK = 992 * PIXEL
local FACE_Z = 0.052
local CUBE = "engine/primitives/cube/model.obj"
local CYLINDER = "game/Meshes/Cylinder.obj"
local QUAD = "game/Meshes/LockSprite.obj"
local PLATE = "game/Meshes/LockRing.obj"

local function material(name)
    return "game/Materials/Port/" .. name .. ".material-instance.json"
end

local DARK = "game/Materials/Dark.material-instance.json"
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

local function sprite(name, position, width, height, parent, mesh)
    return part(name, mesh or QUAD, material(name), position, v(width, height, 1), parent)
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

local function smoothstep(value)
    return value * value * (3 - 2 * value)
end

local function handlePull(open)
    if open < 0.55 then return smoothstep(open / 0.55) end
    if open < 0.75 then return 1 - smoothstep((open - 0.55) / 0.20) end
    return 0
end

function LockView.new()
    local self = setmetatable({ sockets = {}, socketMarkers = {} }, LockView)
    local artSize = 756 * 0.8 * PIXEL
    self.hinge = Scene.Spawn("Door hinge", { position = v(-HINGE_TO_LOCK, 0, 0) })
    sprite("Door", v(512 * PIXEL, -101 * PIXEL, 0), 1024 * PIXEL, 1810 * PIXEL, self.hinge)
    self.handle = Scene.Spawn("Handle pivot", {
        parent = self.hinge,
        position = v(HINGE_TO_LOCK + 0.22, LOCK_Y - 0.08, 0.014),
    })
    local handleWidth, handleHeight = 1024 * 0.9384 * PIXEL, 256 * 0.9384 * PIXEL
    sprite("Handle", v(handleWidth * (0.5 - 0.18997), handleHeight * (0.5 - 0.43342), 0),
        handleWidth, handleHeight, self.handle)

    sprite("Lock backing", v(HINGE_TO_LOCK, LOCK_Y, 0.026), artSize, artSize, self.hinge)
    self.rotor = Scene.Spawn("Lock rotor", { parent = self.hinge, position = v(HINGE_TO_LOCK, LOCK_Y, 0.037) })
    sprite("Lock plate", v(0, 0, 0), artSize, artSize, self.rotor, PLATE)
    sprite("Lock plug", v(0, 0, 0.005), artSize, artSize, self.rotor)
    self.marker = sprite("Contact ring", v(0, LOCK_Y - SOCKET_RADIUS, FACE_Z + 0.013), 0.52, 0.52)
    self.shockFlash = pointLight("Shock flash", v(0, LOCK_Y - SOCKET_RADIUS, 0.85), v(1, 0.78, 0.50), 3.9)
    return self
end

function LockView:buildSockets(count)
    if #self.sockets == count then return end
    for _, socket in ipairs(self.sockets) do Scene.Destroy(socket.root) end
    self.sockets = {}
    self.displayedOccupancy = nil
    for index = 1, count do
        local radians = (index - 1) * 2 * math.pi / count
        local x, y = SOCKET_RADIUS * math.sin(radians), -SOCKET_RADIUS * math.cos(radians)
        local root = Scene.Spawn("Socket " .. index, { parent = self.rotor, position = v(x, y, 0.015) })
        sprite("Socket bore", v(0, 0, 0), 0.43, 0.43, root)
        self.sockets[index] = {
            root = root,
            bulb = pointLight("Pin bulb " .. index, v(0, 0, 0.30), v(0.15, 0.65, 1), 0.80, root),
        }
    end
end

function LockView:showSocketMarkers(linkPairs, springs, count)
    if self.linkPairs == linkPairs and self.springs == springs and self.markerSocketCount == count then return end
    for _, marker in ipairs(self.socketMarkers) do Scene.Destroy(marker) end
    self.socketMarkers = {}
    self.linkPairs, self.springs, self.markerSocketCount = linkPairs, springs, count

    for group, pair in ipairs(linkPairs) do
        for _, socket in ipairs(pair) do
            local radians = (socket - 1) * 2 * math.pi / count
            local sine, cosine = math.sin(radians), math.cos(radians)
            for dot = 1, group do
                local offset = (dot - (group + 1) / 2) * 0.085
                local position = v(0.70 * sine + offset * cosine, -0.70 * cosine + offset * sine, 0.022)
                self.socketMarkers[#self.socketMarkers + 1] = part(
                    ("Link %d socket %d dot %d"):format(group, socket, dot),
                    CYLINDER, DARK, position, v(0.036, 0.036, 0.025), self.rotor)
            end
        end
    end
    for _, socket in ipairs(springs) do
        local radians = (socket - 1) * 2 * math.pi / count
        local marker = part("Spring socket " .. socket, CUBE, DARK,
            v(0.56 * math.sin(radians), -0.56 * math.cos(radians), 0.022),
            v(0.20, 0.045, 0.025), self.rotor)
        marker:SetEulerAngles(v(0, 0, math.deg(radians)))
        self.socketMarkers[#self.socketMarkers + 1] = marker
    end
end

function LockView:syncPins(occupied)
    if self.displayedOccupancy == occupied then return end
    for index, live in ipairs(occupied) do
        local socket = self.sockets[index]
        if socket.live ~= live then
            socket.live = live
            if live then
                socket.pin = sprite("Live pin", v(0, 0, 0.004), 0.24, 0.24, socket.root)
            elseif socket.pin then
                Scene.Destroy(socket.pin)
                socket.pin = nil
            end
            setLightIntensity(socket.bulb, live and BULB_INTENSITY or 0)
        end
    end
    self.displayedOccupancy = occupied
end

function LockView:setAngle(steps, extraDegrees)
    local degrees = steps * 360 / #self.sockets + (extraDegrees or 0)
    self.rotor:SetEulerAngles(v(0, 0, -degrees))
    for _, socket in ipairs(self.sockets) do socket.root:SetEulerAngles(v(0, 0, degrees)) end
end

function LockView:pickContact()
    return v(0, LOCK_Y - SOCKET_RADIUS, FACE_Z)
end

function LockView:setShock(index)
    if self.shockedSocket == index then return end
    self.shockedSocket = index
    setLightIntensity(self.shockFlash, index and FLASH_INTENSITY or 0)
end

function LockView:restart(round)
    self:setShock(nil)
    self:buildSockets(round.socketCount)
    self:showSocketMarkers(round.linkPairs, round.springs, round.socketCount)
    self:syncPins(round.occupied)
    self.hinge:SetEulerAngles(v(0, 0, 0))
    self.handle:SetEulerAngles(v(0, 0, 0))
    self.marker:SetScale(v(0.52, 0.52, 1))
    self:setAngle(round.angleTo)
end

function LockView:update(round, phase, progress, elapsed)
    if not phase then return end
    self:syncPins(round.occupied)
    if phase == RoundState.TURN then
        self:setAngle(round.angleFrom + (round.angleTo - round.angleFrom) * (1 - (1 - progress)^3))
    elseif phase == RoundState.STRIKE then
        if progress == 1 and round:currentPhase() == RoundState.SHOCK then self:setShock(round.target) end
    elseif phase == RoundState.SHOCK then
        local flash = math.max(0, 1 - elapsed / FLASH_TIME)
        setLightIntensity(self.shockFlash, FLASH_INTENSITY * flash ^ 2)
        if progress == 1 then self:setShock(nil) end
    elseif phase == RoundState.OPEN then
        local open = 1 - (1 - progress)^3
        local pull = handlePull(open)
        self.handle:SetEulerAngles(v(0, 28 * pull, -22 * pull))
        self:setAngle(round.angleTo, 90 * open)
        self.hinge:SetEulerAngles(v(0, 120 * smoothstep(progress), 0))
        local markerSize = 0.52 * (1 - 0.99 * open)
        self.marker:SetScale(v(markerSize, markerSize, 1))
    end
end

return LockView
