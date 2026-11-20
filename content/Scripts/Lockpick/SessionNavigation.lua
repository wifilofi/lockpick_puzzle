local Levels = require("Scripts.Lockpick.Levels")

local startingLevel = Levels.firstId

function StartLevel(id)
    if not Levels.hasLevel(id) then return false, "Unknown Lockpick level: " .. tostring(id) end
    local ok, detail = Scene.OpenLevel("game/scenes/main.scene.json")
    if ok then startingLevel = id end
    return ok, detail
end

function StartingLevel()
    return startingLevel
end

function ShowTitle()
    return Scene.OpenLevel("game/scenes/title.scene.json")
end
