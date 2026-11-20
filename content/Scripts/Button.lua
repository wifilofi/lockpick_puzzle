-- Fields and functions belong to this script instance.
-- require is for modules shared throughout the current Play session.
-- local settings = require("shared.settings")

-- Exposed per-object settings, editable in Script > Properties in the Inspector.
-- Use literal strings, numbers or booleans. Read these values inside callbacks.
Properties = {
    -- horseName = "Horse",
    -- speed = 2,
}

elapsed = 0.0

function OnStart()
    -- Initialize this object's behavior.
end

function OnUpdate(deltaSeconds)
    elapsed = elapsed + deltaSeconds
end

function OnDestroy()
    -- Release this object's gameplay resources.
end
