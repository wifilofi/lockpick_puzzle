local State = require("Scripts.Lockpick.State")

local Id = {
    PLAYING = "playing",
    RESULTS = "results",
}

local definitions = {
    [Id.PLAYING] = State.untimed(),
    [Id.RESULTS] = State.untimed(),
}

return { Id = Id, definitions = definitions }
