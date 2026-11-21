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
    view = LockView.new()
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
    transition:update(dt)
    menu:update(dt)
    hud:updateEntrance()
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
