local RoundState = require("Scripts.Lockpick.RoundStates").Id
local createViewData = require("Scripts.Lockpick.LockViewData")

local LockView = {}
LockView.__index = LockView

local ELECTRICITY_SEED_COUNT = 1024 -- Must match LivePinSteel.hlsl.
local LIVE_PIN_MATERIAL_PATH = "game/materials/live.material-instance.json"
local LIVE_PIN_MATERIAL_ID = "8d332de4-ad89-4c1e-943b-13a5724f90e1"

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

local function scenePart(id, name)
    return assert(Scene.FindById(id), "Missing safe scene object: " .. name)
end

local function setRotationOffset(part, restRotation, pitch, yaw, roll)
    local offset = Quaternion.Euler(math.rad(pitch), math.rad(yaw), math.rad(roll))
    part:SetRotation(restRotation * offset)
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

local function setRingCenter(values, center, halfSize)
    values[1], values[2], values[3], values[4] = center.x, center.y, center.z, halfSize
end

local function addStrikeGuidePass(view)
    local pipeline = Render.LoadPipeline("game/shaders/strikeguidering.pipeline.json")
    local centers = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
    local buffer = Render.CreateConstantBuffer {
        shader = pipeline.vertexShader,
        name = "StrikeGuideRings",
        values = { CentersAndSize = centers },
    }
    local previewDepth = (view.rotor:GetWorldPosition() - view.marker:GetWorldPosition()):Dot(view.rotor:Forward())

    Render.AddProceduralPass {
        name = "Strike guide rings",
        execute = function(ctx)
            if not view.guideVisible then return end

            local halfSize = 0.205 * math.abs(view.marker:GetWorldScale().x)
            setRingCenter(centers[1], view.marker:GetWorldPosition(), halfSize)
            local preview = view.previewSocket
            if preview then
                local center = preview:GetWorldPosition() - preview:Forward() * previewDepth
                setRingCenter(centers[2], center, halfSize)
            end

            buffer:Set("CentersAndSize", centers)
            ctx:SetPipeline(pipeline)
            ctx:BindConstantBuffer(5, buffer)
            ctx:DrawProcedural(6, preview and 2 or 1)
        end,
    }
end

function LockView.new(settings)
    local data = createViewData(settings)
    local lights = data.lights
    local safe = scenePart("8f4ec3d8-7351-4f23-9d86-6058e9dc5528", "Safe")
    local liveMaterial = settings.livePinMaterial:lower()
    local self = setmetatable({
        data = data, sockets = {}, socketMarkers = {},
        bulbIntensity = { intensity = lights.bulb.activeIntensity },
        animateElectricity = liveMaterial == LIVE_PIN_MATERIAL_PATH or liveMaterial == LIVE_PIN_MATERIAL_ID,
        electricityFrame = 0,
        electricityPatch = {},
        hinge = scenePart("4b061fff-550a-4821-be98-39736f371f2e", "Safe door hinge"),
        handle = scenePart("72211fb9-ebf6-4661-b0c8-82da46c169a7", "Safe handle pivot"),
        rotor = scenePart("3eeff9be-e73c-4a2e-a604-072501e80d11", "Lock rotor"),
        marker = scenePart("ebc93e98-da34-44dd-be86-759b1f73efc3", "Strike guide"),
        contact = scenePart("c924aee5-301d-4e22-8503-6d0bf4467a8b", "Pick contact"),
    }, LockView)
    self.hingeRestRotation = self.hinge:GetRotation()
    self.handleRestRotation = self.handle:GetRotation()
    self.rotorRestRotation = self.rotor:GetRotation()
    self.markerRestScale = self.marker:GetScale()
    addStrikeGuidePass(self)

    pointLight(lights.key)
    pointLight(lights.fill)
    pointLight(lights.dialAccent, safe)
    self.interiorLight = pointLight(lights.interior, safe)
    self.shockFlash = pointLight(lights.shock, safe)
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
                    socket.pinShininess = nil
                end
                setLightIntensity(socket.bulb, 0)
            end
        end
    end
    self.displayedOccupancy = occupied
end

function LockView:updateElectricity()
    if not self.animateElectricity then return end

    self.electricityFrame = (self.electricityFrame + 1) % (2 * ELECTRICITY_SEED_COUNT)
    if self.electricityFrame % 2 ~= 0 then return end

    local step = self.electricityFrame // 2
    local patch = self.electricityPatch
    for index, socket in ipairs(self.sockets) do
        local pin = socket.pin
        if pin then
            if not socket.pinShininess then
                -- The material can still be loading when a pin first appears.
                local ready, material = pcall(pin.GetMaterialParameters, pin)
                if ready and material then
                    socket.pinShininess = math.floor(material.shininess)
                end
            end
            if socket.pinShininess then
                -- The shader decodes the seed from the fractional part and uses the whole part for gloss.
                local seed = (step + (index - 1) * 73) % ELECTRICITY_SEED_COUNT
                patch.shininess = socket.pinShininess + seed / ELECTRICITY_SEED_COUNT
                pin:SetMaterialParameters(patch)
            end
        end
    end
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
    setRotationOffset(self.rotor, self.rotorRestRotation, 0, 0, -degrees)
end

function LockView:pickContact()
    return self.contact:GetWorldPosition()
end

function LockView:setGuidePreview(socketIndex)
    self.previewSocket = socketIndex and self.sockets[socketIndex].root or nil
end

function LockView:hideGuide()
    self.guideVisible = false
    self.previewSocket = nil
end

function LockView:setShock(index)
    if self.shockedSocket == index then return end
    self.shockedSocket = index
    setLightIntensity(self.shockFlash, index and self.data.lights.shock.activeIntensity or 0)
end

function LockView:restart(round)
    self:setShock(nil)
    self.guideVisible = true
    self.previewSocket = nil
    self:buildSockets(round.socketCount)
    self:showSocketMarkers(round.linkPairs, round.springs, round.socketCount)
    self:syncPins(round.occupied)
    self.hinge:SetRotation(self.hingeRestRotation)
    self.handle:SetRotation(self.handleRestRotation)
    self.marker:SetScale(self.markerRestScale)
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
        setRotationOffset(self.handle, self.handleRestRotation, 0, animation.handleYaw * pull, animation.handleRoll * pull)
        self:setAngle(round.angleTo, animation.openDialRotation * open)
        setRotationOffset(self.hinge, self.hingeRestRotation, 0, animation.openHingeYaw * smoothstep(progress), 0)
        setLightIntensity(self.interiorLight, lights.interior.activeIntensity * smoothstep(progress))
        local markerSize = 1 - animation.strikeGuideShrink * open
        local scale = self.markerRestScale
        self.marker:SetScale(v(scale.x * markerSize, scale.y * markerSize, scale.z * markerSize))
    end
end

return LockView
