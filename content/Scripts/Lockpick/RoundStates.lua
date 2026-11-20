local State = require("Scripts.Lockpick.State")

local Id = {
    READY = "ready",
    TURN = "turn",
    STRIKE = "strike",
    RECOIL = "recoil",
    SHOCK = "shock",
    DROP = "drop",
    OPEN = "open",
    FINISHED = "finished",
}

local definitions = {
    [Id.READY] = State.untimed(),
    [Id.TURN] = State.timed(0.30, function(round) round.phaseMachine:transitionTo(Id.STRIKE) end),
    [Id.STRIKE] = State.timed(0.13, function(round) round:impact() end),
    [Id.RECOIL] = State.timed(0.13, function(round) round:afterRecoil() end),
    [Id.SHOCK] = State.timed(0.42, function(round) round.phaseMachine:transitionTo(Id.DROP) end),
    [Id.DROP] = State.timed(0.35, function(round) round:finish() end),
    [Id.OPEN] = State.timed(0.70, function(round) round:finish() end),
    [Id.FINISHED] = State.untimed(),
}

return { Id = Id, definitions = definitions }
