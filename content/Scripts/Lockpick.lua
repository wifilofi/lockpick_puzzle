local GameFlow = require("Scripts.Lockpick.GameFlow")
local LockView = require("Scripts.Lockpick.LockView")
local PickHandView = require("Scripts.Lockpick.PickHandView")
local Hud = require("Scripts.Lockpick.Hud")
local PuzzleSolver = require("Scripts.Lockpick.PuzzleSolver")

local flow, round, view, hand, hud
local leaving = false

local function refreshHud()
    hud:update(round, flow:nextLevelId() ~= nil)
end

local function selectCard(key)
    if round:selectKey(key) then refreshHud() end
end

local function refreshRound()
    view:restart(round)
    hand:reset()
    refreshHud()
end

local function restart()
    flow:restart()
    refreshRound()
end

local function retry()
    if flow:retry() then refreshRound() end
end

local function advance()
    if flow:advance() then refreshRound() end
end

local function requestHint()
    if not round:isReady() then return end
    local slot = PuzzleSolver.findWinningCard(
        round.occupied, round.target, round.attempts, round.hand, round.linkPartners, round.springs)
    hud:showHint(round.handSlots[slot])
end

local function undo()
    if flow:undo() then refreshRound() end
end

local function showTitle()
    if leaving then return end
    local ok, detail = Autoloads.SessionNavigation.ShowTitle()
    if ok then
        leaving = true
    else
        Log.warning(detail)
    end
end

function OnStart()
    flow = GameFlow.new(Autoloads.SessionNavigation.StartingLevel(), Log.info)
    round = flow.round
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
    local camera = assert(Scene.FindByName("Play camera"), "Missing play camera")
    hand = PickHandView.new(hud.document, camera, view:pickContact())
    refreshRound()
    hud:show()
end

function OnUpdate(dt)
    if leaving then return end
    if hud:pollInput() then return end
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
