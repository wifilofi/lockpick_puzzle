local Levels = require("Scripts.Lockpick.Levels")
local ScreenTransition = require("Scripts.Lockpick.ScreenTransition")

local document, menu, levelSelect, errorLabel, phone, transition

local function showLevels(visible)
    assert(menu:SetClass("hidden", visible))
    assert(levelSelect:SetClass("hidden", not visible))
    assert(errorLabel:SetText(""))
end

local function startLevel(id)
    if transition:cover(function()
        local ok, detail = Autoloads.SessionNavigation.StartLevel(id)
        if ok then return true end
        assert(phone:SetClass("departing", false))
        assert(errorLabel:SetText("Could not open the level."))
        Log.warning(detail)
        return false
    end) then
        assert(phone:SetClass("departing", true))
    end
end

function OnStart()
    document = assert(UI.LoadDocument("game/UI/Title.rml"))
    transition = ScreenTransition.new(document)
    phone = assert(document:GetElement("phone"))
    menu = assert(document:GetElement("title-menu"))
    levelSelect = assert(document:GetElement("title-level-select"))
    errorLabel = assert(document:GetElement("title-error"))
    local list = assert(document:GetElement("title-level-list"))
    local levels = Levels.menuLevels()
    local buttons = {}
    for index in ipairs(levels) do
        buttons[index] = ('<button id="title-level-%d" class="title-action"></button>'):format(index)
    end
    assert(list:SetInnerRml(table.concat(buttons)))
    for index, level in ipairs(levels) do
        local id = "title-level-" .. index
        assert(assert(document:GetElement(id)):SetText(level.name))
        assert(document:On(id, "click", function() startLevel(level.id) end))
    end
    assert(document:On("title-play", "click", function() startLevel(Levels.firstId) end))
    assert(document:On("title-choose-level", "click", function()
        if not transition:isActive() then showLevels(true) end
    end))
    assert(document:On("title-back", "click", function()
        if not transition:isActive() then showLevels(false) end
    end))
    assert(document:On("title-exit", "click", function()
        if not transition:isActive() then Game.Quit() end
    end))
    showLevels(false)
    assert(document:Show("interactive"))
    Log.info("[LOCKPICK][TITLE] ready")
end

function OnUpdate(dt)
    transition:update(dt)
end
