local StateMachine = require("Scripts.Lockpick.StateMachine")
local GameStates = require("Scripts.Lockpick.GameStates")
local Round = require("Scripts.Lockpick.Round")
local Levels = require("Scripts.Lockpick.Levels")

local GameState = GameStates.Id

local GameFlow = {}
GameFlow.__index = GameFlow

function GameFlow.new(levelId, log)
    local self = setmetatable({ levelId = levelId }, GameFlow)
    local function logGameTransition(previous, state)
        if not log then return end
        local details = state == GameState.RESULTS and " outcome=" .. self.round.result or ""
        log(("[LOCKPICK][GAME] %s -> %s | level=%s%s"):format(previous or "start", state, self.levelId, details))
    end
    local function logRoundTransition(previous, phase)
        if log then
            log(("[LOCKPICK][ROUND] %s -> %s | level=%s"):format(previous or "start", phase, self.levelId))
        end
    end
    self.gameStateMachine = StateMachine.new(GameStates.definitions, self, logGameTransition)
    self.gameStateMachine:transitionTo(GameState.PLAYING)
    self.round = Round.new(Levels.loadLevel(levelId), logRoundTransition)
    return self
end

function GameFlow:restart()
    self.gameStateMachine:transitionTo(GameState.PLAYING)
    self.round:restart(Levels.loadLevel(self.levelId))
end

function GameFlow:retry()
    if self.gameStateMachine.currentState ~= GameState.RESULTS then return false end
    self:restart()
    return true
end

function GameFlow:roundFinished()
    if self.gameStateMachine.currentState ~= GameState.PLAYING or not self.round.result then return false end
    self.gameStateMachine:transitionTo(GameState.RESULTS)
    return true
end

return GameFlow
