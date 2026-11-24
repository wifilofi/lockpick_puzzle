local RoundState = require("Scripts.Lockpick.RoundStates").Id

local LockView = {}
LockView.__index = LockView

local FLASH_TIME, FLASH_INTENSITY = 0.22, 5.5
local BULB_INTENSITY = 2.2
local INTERIOR_INTENSITY = 1.3
-- Lock art and screwdriver contact use the fixed play camera coordinates.
local PIXEL = 2 * 7.2 * math.tan(0.72 / 2) / 1080
local LOCK_Y = 0.05 + (540 - 379) * PIXEL
-- Measured from the authored socket ring after fitting the dial to the safe.
local SOCKET_RADIUS = 0.5308
local SOCKET_FACE_Z = 0.0521
-- The mesh pivots match the FBX. These offsets mount the playable dial on its door.
local SAFE_PATH = "game/Models/Safe/"
local HINGE_TO_LOCK = 1.0852
local HINGE_DEPTH = -0.0137
local HANDLE_OFFSET_X = 2.5766
local HANDLE_OFFSET_Z = -0.0416
local CUBE = "engine/primitives/cube/model.obj"
local CYLINDER = "game/Meshes/Cylinder.obj"
local DARK = "game/Materials/Dark.material-instance.json"
local LIVE = "game/Materials/Live.material-instance.json"
local GUIDE = "game/Materials/Shock.material-instance.json"
local DIAL_SATIN = SAFE_PATH .. "DialSatin.material-instance.json"
local DIAL_GRAPHITE = SAFE_PATH .. "DialGraphite.material-instance.json"
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

local function safePart(name, finish, position, parent)
    return part("Safe " .. name, SAFE_PATH .. name .. ".obj", SAFE_PATH .. finish .. ".material-instance.json",
        position, v(8.8, 6.25, 6.25), parent)
end

local function lockPart(name, mesh, finish, position, parent)
    return part(name, SAFE_PATH .. mesh .. ".obj", finish, position, v(10.6, 10.6, 6.25), parent)
end

local function pointLight(name, position, color, range, parent, intensity)
    return Scene.Spawn(name, {
        parent = parent,
        position = position,
        components = { PointLight = { color = color, range = range, intensity = intensity or 0 } },
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
    safePart("Cabinet", "CabinetMetal", v(0, LOCK_Y, 0))
    safePart("Frame", "HardwareMetal", v(0, LOCK_Y, 0))
    self.hinge = Scene.Spawn("Safe door hinge", { position = v(-HINGE_TO_LOCK, LOCK_Y, HINGE_DEPTH) })
    safePart("Door", "CabinetMetal", v(0, 0, 0), self.hinge)
    self.handle = Scene.Spawn("Safe handle pivot", {
        parent = self.hinge,
        position = v(HANDLE_OFFSET_X, 0, HANDLE_OFFSET_Z),
    })
    safePart("Handle", "HardwareMetal", v(0, 0, 0), self.handle)

    local mount = v(HINGE_TO_LOCK, 0, -HINGE_DEPTH)
    lockPart("Safe dial", "Dial", DIAL_SATIN, mount, self.hinge)
    self.rotor = Scene.Spawn("Lock rotor", { parent = self.hinge, position = mount })
    lockPart("Lock plug", "Plug", DIAL_GRAPHITE, v(0, 0, 0), self.rotor)
    self.marker = part("Strike guide", SAFE_PATH .. "StrikeGuide.obj", GUIDE,
        v(0, LOCK_Y - SOCKET_RADIUS, SOCKET_FACE_Z + 0.012), v(1, 1, 1))

    pointLight("Safe key light", v(-1.9, 2.9, 3.55), v(1, 0.95, 0.87), 8.5, nil, 4.1)
    pointLight("Safe fill light", v(2.75, 0.9, 2.65), v(0.74, 0.85, 1), 7, nil, 1.65)
    pointLight("Dial accent light", v(-0.72, LOCK_Y + 0.62, 1.08), v(0.88, 0.94, 1), 2.35, nil, 2.2)
    self.interiorLight = pointLight("Safe interior light", v(0.30, LOCK_Y + 0.65, -0.75), v(1, 0.76, 0.48), 3.0)
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
        local root = Scene.Spawn("Socket " .. index, { parent = self.rotor, position = v(x, y, 0) })
        root:SetEulerAngles(v(0, 0, math.deg(radians)))
        lockPart("Socket housing", "Socket", DIAL_SATIN, v(0, 0, 0), root)
        part("Socket inset", CYLINDER, DARK, v(0, 0, 0.045), v(0.065, 0.065, 0.003), root)
        self.sockets[index] = {
            root = root,
            bulb = pointLight("Pin bulb " .. index, v(0, 0, 0.19), v(0.15, 0.65, 1), 0.47, root),
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
                local offset = (dot - (group + 1) / 2) * 0.052
                local position = v(0.66 * sine + offset * cosine, -0.66 * cosine + offset * sine, 0.031)
                self.socketMarkers[#self.socketMarkers + 1] = part(
                    ("Link %d socket %d dot %d"):format(group, socket, dot),
                    CYLINDER, DARK, position, v(0.020, 0.020, 0.016), self.rotor)
            end
        end
    end
    for _, socket in ipairs(springs) do
        local radians = (socket - 1) * 2 * math.pi / count
        local marker = part("Spring socket " .. socket, CUBE, DARK,
            v(0.37 * math.sin(radians), -0.37 * math.cos(radians), 0.033),
            v(0.12, 0.036, 0.018), self.rotor)
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
                socket.pin = lockPart("Live pin", "Pin", LIVE, v(0, 0, -0.014), socket.root)
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
end

function LockView:pickContact()
    return v(0, LOCK_Y - SOCKET_RADIUS, SOCKET_FACE_Z)
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
    self.marker:SetScale(v(1, 1, 1))
    setLightIntensity(self.interiorLight, 0)
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
        self.hinge:SetEulerAngles(v(0, -110 * smoothstep(progress), 0))
        setLightIntensity(self.interiorLight, INTERIOR_INTENSITY * smoothstep(progress))
        local markerSize = 1 - 0.99 * open
        self.marker:SetScale(v(markerSize, markerSize, markerSize))
    end
end

return LockView
