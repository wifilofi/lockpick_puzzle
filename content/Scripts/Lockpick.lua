Properties = {
    -- Safe and lock placement
    lockHeightOffset = 0.05,
    socketRadius = 0.5308,
    socketFaceZ = 0.0521,
    hingeToLock = 1.0852,
    hingeDepth = -0.0137,
    handlePivotX = 2.5766,
    handlePivotZ = -0.0416,
    safeScaleX = 8.8,
    safeScaleY = 6.25,
    safeScaleZ = 6.25,
    lockScaleX = 10.6,
    lockScaleY = 10.6,
    lockScaleZ = 6.25,

    -- Meshes and materials
    cabinetMaterial = "game/Models/Safe/CabinetMetal.material-instance.json",
    hardwareMaterial = "game/Models/Safe/HardwareMetal.material-instance.json",
    dialSatinMaterial = "game/Models/Safe/DialSatin.material-instance.json",
    dialGraphiteMaterial = "game/Models/Safe/DialGraphite.material-instance.json",
    darkMaterial = "game/Materials/Dark.material-instance.json",
    cylinderMesh = "game/Meshes/Cylinder.obj",
    strikeGuideMesh = "game/Models/Safe/StrikeGuide.obj",
    strikeGuideMaterial = "game/Materials/Shock.material-instance.json",
    cabinetMesh = "game/Models/Safe/Cabinet.obj",
    frameMesh = "game/Models/Safe/Frame.obj",
    doorMesh = "game/Models/Safe/Door.obj",
    handleMesh = "game/Models/Safe/Handle.obj",
    dialMesh = "game/Models/Safe/Dial.obj",
    plugMesh = "game/Models/Safe/Plug.obj",
    socketMesh = "game/Models/Safe/Socket.obj",
    livePinMesh = "game/Models/Safe/Pin.obj",
    livePinMaterial = "game/Materials/Live.material-instance.json",
    springMarkerMesh = "engine/primitives/cube/model.obj",

    -- Socket details and markers
    strikeGuideDepthOffset = 0.012,
    strikeGuideScaleX = 1,
    strikeGuideScaleY = 1,
    strikeGuideScaleZ = 1,
    socketInsetZ = 0.045,
    socketInsetScaleX = 0.065,
    socketInsetScaleY = 0.065,
    socketInsetScaleZ = 0.003,
    livePinZ = -0.014,
    linkMarkerScaleX = 0.02,
    linkMarkerScaleY = 0.02,
    linkMarkerScaleZ = 0.016,
    linkMarkerRadius = 0.66,
    linkMarkerDepth = 0.031,
    linkMarkerSpacing = 0.052,
    springMarkerScaleX = 0.12,
    springMarkerScaleY = 0.036,
    springMarkerScaleZ = 0.018,
    springMarkerRadius = 0.37,
    springMarkerDepth = 0.033,

    -- Blue pin bulbs
    bulbPositionZ = 0.19,
    bulbColorR = 0.15,
    bulbColorG = 0.65,
    bulbColorB = 1,
    bulbRange = 0.6,
    bulbIntensity = 4.4,

    -- Safe lighting
    keyLightPositionX = -1.9,
    keyLightPositionY = 2.9,
    keyLightPositionZ = 3.55,
    keyLightColorR = 1,
    keyLightColorG = 0.95,
    keyLightColorB = 0.87,
    keyLightRange = 8.5,
    keyLightIntensity = 4.1,
    fillLightPositionX = 2.75,
    fillLightPositionY = 0.9,
    fillLightPositionZ = 2.65,
    fillLightColorR = 0.74,
    fillLightColorG = 0.85,
    fillLightColorB = 1,
    fillLightRange = 7,
    fillLightIntensity = 1.65,
    dialLightPositionX = -0.72,
    dialLightHeightOffset = 0.62,
    dialLightPositionZ = 1.08,
    dialLightColorR = 0.88,
    dialLightColorG = 0.94,
    dialLightColorB = 1,
    dialLightRange = 2.35,
    dialLightIntensity = 2.2,
    interiorLightPositionX = 0.3,
    interiorLightHeightOffset = 0.65,
    interiorLightPositionZ = -0.75,
    interiorLightColorR = 1,
    interiorLightColorG = 0.76,
    interiorLightColorB = 0.48,
    interiorLightRange = 3,
    interiorLightIntensity = 1.3,
    shockLightPositionZ = 0.85,
    shockLightColorR = 1,
    shockLightColorG = 0.78,
    shockLightColorB = 0.5,
    shockLightRange = 3.9,
    shockLightIntensity = 5.5,

    -- Animation
    shockFlashTime = 0.22,
    handlePullPeak = 0.55,
    handleReleaseEnd = 0.75,
    handleReleaseDuration = 0.2,
    handleYaw = 28,
    handleRoll = -22,
    openDialRotation = 90,
    openHingeYaw = -110,
    strikeGuideShrink = 0.99,
}

local GameFlow = require("Scripts.Lockpick.GameFlow")
local LockView = require("Scripts.Lockpick.LockView")
local PickHandView = require("Scripts.Lockpick.PickHandView")
local Hud = require("Scripts.Lockpick.Hud")
local PuzzleSolver = require("Scripts.Lockpick.PuzzleSolver")
local ScreenTransition = require("Scripts.Lockpick.ScreenTransition")
local PhoneMenu = require("Scripts.Lockpick.PhoneMenu")

local flow, round, view, hand, hud, transition, menu

local function canPlay()
    return menu:isPlaying() and not transition:isActive()
end

local function refreshHud()
    hud:update(round, flow:nextLevelId() ~= nil)
end

local function selectCard(key)
    if not canPlay() then return end
    if round:selectKey(key) then refreshHud() end
end

local function refreshRound()
    view:restart(round)
    hand:reset()
    refreshHud()
end

local function restart()
    if not canPlay() then return end
    flow:restart()
    refreshRound()
end

local function retry()
    if not canPlay() then return end
    transition:cover(function()
        if flow:retry() then refreshRound() end
    end)
end

local function advance()
    if not canPlay() then return end
    transition:cover(function()
        if not flow:advance() then return end
        refreshRound()
        hud:queueEntrance()
    end)
end

local function requestHint()
    if not canPlay() then return end
    if not round:isReady() then return end
    local slot = PuzzleSolver.findWinningCard(
        round.occupied, round.target, round.attempts, round.hand, round.linkPartners, round.springs)
    hud:showHint(round.handSlots[slot])
end

local function undo()
    if not canPlay() then return end
    if flow:undo() then refreshRound() end
end

local function showTitle()
    if canPlay() then menu:show() end
end

local function startLevel(id)
    flow = GameFlow.new(id, Log.info)
    round = flow.round
    refreshRound()
    hud:queueEntrance(true)
end

function OnStart()
    view = LockView.new(Properties)
    hud = Hud.new({
        selectCard = selectCard,
        restart = restart,
        retry = retry,
        advance = advance,
        requestHint = requestHint,
        undo = undo,
        showTitle = showTitle,
    })
    transition = ScreenTransition.new(hud.document)
    local camera = assert(Scene.FindByName("Play camera"), "Missing play camera")
    hand = PickHandView.new(hud.document, camera, view:pickContact())
    menu = PhoneMenu.new(hud.document, startLevel)
    hud:show()
end

function OnUpdate(dt)
    hud:updateFps()
    transition:update(dt)
    menu:update(dt)
    hud:updateEntrance()
    view:updateBulbs()
    if not menu:isPlaying() then return end
    if not transition:isActive() and hud:pollInput() then return end
    if not round:isAnimating() then return end
    local previousStatus, previousAttempts, previousResult = round.status, round.attempts, round.result
    local phase, progress, elapsed = round:update(dt)
    view:update(round, phase, progress, elapsed)
    hand:update(round, phase, progress, elapsed)
    if round.result ~= previousResult then flow:roundFinished() end
    if round.status ~= previousStatus or round.attempts ~= previousAttempts or round.result ~= previousResult then
        refreshHud()
    end
end
