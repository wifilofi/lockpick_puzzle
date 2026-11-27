local RoundState = require("Scripts.Lockpick.RoundStates").Id
local createViewData = require("Scripts.Lockpick.LockViewData")

local LockView = {}
LockView.__index = LockView

local function v(x, y, z)
    return Vector3.new(x, y, z)
end

local function part(definition, parent, name, position)
    return Scene.Spawn(name or definition.name, {
        parent = parent,
        position = v(table.unpack(position or definition.position)),
        scale = v(table.unpack(definition.scale)),
        components = {
            MeshRenderer = { mesh = definition.mesh, materialInstance = definition.material },
        },
    })
end

local function pointLight(definition, parent, name)
    return Scene.Spawn(name or definition.name, {
        parent = parent,
        position = v(table.unpack(definition.position)),
        components = {
            PointLight = {
                color = v(table.unpack(definition.color)),
                range = definition.range,
                intensity = definition.intensity or 0,
            },
        },
    })
end

local function setLightIntensity(light, intensity)
    light:SetComponent("PointLight", { intensity = intensity })
end

local function smoothstep(value)
    return value * value * (3 - 2 * value)
end

local function handlePull(open, animation)
    if open < animation.handlePullPeak then return smoothstep(open / animation.handlePullPeak) end
    if open < animation.handleReleaseEnd then
        return 1 - smoothstep((open - animation.handlePullPeak) / animation.handleReleaseDuration)
    end
    return 0
end

function LockView.new(settings)
    local data = createViewData(settings)
    local lights = data.lights
    local self = setmetatable({
        data = data, sockets = {}, socketMarkers = {},
        bulbIntensity = { intensity = lights.bulb.activeIntensity },
    }, LockView)
    part(data.cabinet)
    part(data.frame)
    self.hinge = Scene.Spawn("Safe door hinge", { position = v(table.unpack(data.hinge)) })
    part(data.door, self.hinge)
    self.handle = Scene.Spawn("Safe handle pivot", {
        parent = self.hinge,
        position = v(table.unpack(data.handlePivot)),
    })
    part(data.handle, self.handle)

    part(data.dial, self.hinge)
    self.rotor = Scene.Spawn("Lock rotor", { parent = self.hinge, position = v(table.unpack(data.dialMount)) })
    part(data.plug, self.rotor)
    self.marker = part(data.strikeGuide)

    pointLight(lights.key)
    pointLight(lights.fill)
    pointLight(lights.dialAccent)
    self.interiorLight = pointLight(lights.interior)
    self.shockFlash = pointLight(lights.shock)
    return self
end

function LockView:buildSockets(count)
    if #self.sockets == count then return end
    for _, socket in ipairs(self.sockets) do Scene.Destroy(socket.root) end
    self.sockets = {}
    self.displayedOccupancy = nil
    local socketData = self.data.socket
    for index = 1, count do
        local radians = (index - 1) * 2 * math.pi / count
        local x, y = socketData.radius * math.sin(radians), -socketData.radius * math.cos(radians)
        local root = Scene.Spawn("Socket " .. index, { parent = self.rotor, position = v(x, y, 0) })
        root:SetEulerAngles(v(0, 0, math.deg(radians)))
        part(socketData.housing, root)
        part(socketData.inset, root)
        self.sockets[index] = {
            root = root,
            bulb = pointLight(self.data.lights.bulb, root, "Pin bulb " .. index),
        }
    end
end

function LockView:showSocketMarkers(linkPairs, springs, count)
    if self.linkPairs == linkPairs and self.springs == springs and self.markerSocketCount == count then return end
    for _, marker in ipairs(self.socketMarkers) do Scene.Destroy(marker) end
    self.socketMarkers = {}
    self.linkPairs, self.springs, self.markerSocketCount = linkPairs, springs, count

    local linkMarker = self.data.linkMarker
    for group, pair in ipairs(linkPairs) do
        for _, socket in ipairs(pair) do
            local radians = (socket - 1) * 2 * math.pi / count
            local sine, cosine = math.sin(radians), math.cos(radians)
            for dot = 1, group do
                local offset = (dot - (group + 1) / 2) * linkMarker.spacing
                local position = {
                    linkMarker.radius * sine + offset * cosine,
                    -linkMarker.radius * cosine + offset * sine,
                    linkMarker.depth,
                }
                self.socketMarkers[#self.socketMarkers + 1] = part(
                    linkMarker, self.rotor, ("Link %d socket %d dot %d"):format(group, socket, dot), position)
            end
        end
    end
    local springMarker = self.data.springMarker
    for _, socket in ipairs(springs) do
        local radians = (socket - 1) * 2 * math.pi / count
        local marker = part(springMarker, self.rotor, "Spring socket " .. socket, {
            springMarker.radius * math.sin(radians),
            -springMarker.radius * math.cos(radians),
            springMarker.depth,
        })
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
                socket.pin = part(self.data.socket.livePin, socket.root)
                socket.bulb:SetComponent("PointLight", self.bulbIntensity)
            else
                if socket.pin then
                    Scene.Destroy(socket.pin)
                    socket.pin = nil
                end
                setLightIntensity(socket.bulb, 0)
            end
        end
    end
    self.displayedOccupancy = occupied
end

function LockView:updateBulbs()
    local bulb = self.data.lights.bulb
    if bulb.activeIntensity == 0 then return end

    local pulseCalculated = false
    for _, socket in ipairs(self.sockets) do
        if socket.live then
            if not pulseCalculated then
                local wave = math.sin(Time.SimulationTime() * bulb.pulseAngularSpeed)
                self.bulbIntensity.intensity = bulb.activeIntensity * (1 + bulb.pulseFraction * wave)
                pulseCalculated = true
            end
            socket.bulb:SetComponent("PointLight", self.bulbIntensity)
        end
    end
end

function LockView:setAngle(steps, extraDegrees)
    local degrees = steps * 360 / #self.sockets + (extraDegrees or 0)
    self.rotor:SetEulerAngles(v(0, 0, -degrees))
end

function LockView:pickContact()
    return v(table.unpack(self.data.pickContact))
end

function LockView:setShock(index)
    if self.shockedSocket == index then return end
    self.shockedSocket = index
    setLightIntensity(self.shockFlash, index and self.data.lights.shock.activeIntensity or 0)
end

function LockView:restart(round)
    self:setShock(nil)
    self:buildSockets(round.socketCount)
    self:showSocketMarkers(round.linkPairs, round.springs, round.socketCount)
    self:syncPins(round.occupied)
    self.hinge:SetEulerAngles(v(0, 0, 0))
    self.handle:SetEulerAngles(v(0, 0, 0))
    self.marker:SetScale(v(table.unpack(self.data.strikeGuide.scale)))
    setLightIntensity(self.interiorLight, 0)
    self:setAngle(round.angleTo)
end

function LockView:update(round, phase, progress, elapsed)
    if not phase then return end
    self:syncPins(round.occupied)
    local animation = self.data.animation
    local lights = self.data.lights
    if phase == RoundState.TURN then
        self:setAngle(round.angleFrom + (round.angleTo - round.angleFrom) * (1 - (1 - progress)^3))
    elseif phase == RoundState.STRIKE then
        if progress == 1 and round:currentPhase() == RoundState.SHOCK then self:setShock(round.target) end
    elseif phase == RoundState.SHOCK then
        local flash = math.max(0, 1 - elapsed / animation.shockFlashTime)
        setLightIntensity(self.shockFlash, lights.shock.activeIntensity * flash ^ 2)
        if progress == 1 then self:setShock(nil) end
    elseif phase == RoundState.OPEN then
        local open = 1 - (1 - progress)^3
        local pull = handlePull(open, animation)
        self.handle:SetEulerAngles(v(0, animation.handleYaw * pull, animation.handleRoll * pull))
        self:setAngle(round.angleTo, animation.openDialRotation * open)
        self.hinge:SetEulerAngles(v(0, animation.openHingeYaw * smoothstep(progress), 0))
        setLightIntensity(self.interiorLight, lights.interior.activeIntensity * smoothstep(progress))
        local markerSize = 1 - animation.strikeGuideShrink * open
        local x, y, z = table.unpack(self.data.strikeGuide.scale)
        self.marker:SetScale(v(x * markerSize, y * markerSize, z * markerSize))
    end
end

return LockView
