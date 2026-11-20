local GameFlow = require("Scripts.Lockpick.GameFlow")
local LockView = require("Scripts.Lockpick.LockView")
local Hud = require("Scripts.Lockpick.Hud")

local LEVEL = "storage"

local flow, round, view, hud

local function refreshHud()
    hud:update(round, flow:nextLevelId() ~= nil)
end

local function selectCard(slot)
    if round:selectCard(slot) then refreshHud() end
end

local function refreshRound()
    view:restart(round)
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

function OnStart()
    flow = GameFlow.new(LEVEL, Log.info)
    round = flow.round
    view = LockView.new()
    hud = Hud.new(selectCard, restart, retry, advance)
    refreshRound()
    hud:show()
end

function OnUpdate(dt)
    if hud:pollInput() then return end
    if not round:isAnimating() then return end
    local previousStatus, previousAttempts, previousResult = round.status, round.attempts, round.result
    local phase, progress, elapsed = round:update(dt)
    view:update(round, phase, progress, elapsed)
    if round.result ~= previousResult then flow:roundFinished() end
    if round.status ~= previousStatus or round.attempts ~= previousAttempts or round.result ~= previousResult then
        refreshHud()
    end
end
