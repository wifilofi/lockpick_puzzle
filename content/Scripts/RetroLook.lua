Properties = {
    enabled = true,
    affectUI = true,
    lookEnabled = true,
    brightness = 1.0,
    contrast = 1.0,
    grainAmount = 0.0,
    grainSize = 1.0,
    grainSmoothness = 0.0,
    -- lcdBefore = 0.055,
    -- lcdAfter = 0.025,
    -- hueWobble = 0.0,
    posterizeStrength = 1.0,
    posterizeLevels = 17,
    posterizeLift = 0.29,
    -- tintEnabled = false,
    -- tintRed = 1.0,
    -- tintGreen = 1.0,
    -- tintBlue = 1.0,
    bleedEnabled = false,
    bleedAmount = 0.292,
    bleedMode = 0,
    bleedMask = "",
    bleedMaskUseAlpha = false,
    bleedCustomCurve = "",
    -- sharpenStrength = 0.0,
    -- glowEnabled = false,
    -- glowAmount = 1.0,
    -- glowThreshold = 0.65,
    -- glowRadius = 4.0,
    -- staticAmount = 0.0
}

local function clamp(value, minimum, maximum)
    return math.min(maximum, math.max(minimum, value))
end

local function addPosterizePass(settings, stage)
    if not settings.lookEnabled then return end

    local brightness = math.max(0.0, settings.brightness)
    local contrast = math.max(0.0, settings.contrast)
    local grainAmount = clamp(settings.grainAmount, 0.0, 1.0)
    local strength = clamp(settings.posterizeStrength, 0.0, 1.0)
    if strength == 0.0 and brightness == 1.0 and contrast == 1.0 and grainAmount == 0.0 then return end

    local shader = Render.LoadShader("game/shaders/retroposterize.postprocess.json")
    local grainFrame = 0
    local buffer = Render.CreateConstantBuffer {
        shader = shader,
        name = "PosterizeParams",
        values = {
            Brightness = brightness,
            Contrast = contrast,
            GrainAmount = grainAmount,
            GrainInverseSize = 1.0 / math.max(1.0, settings.grainSize),
            GrainSmoothness = clamp(settings.grainSmoothness, 0.0, 1.0),
            GrainFrame = grainFrame,
            -- LcdBefore = clamp(settings.lcdBefore, 0.0, 1.0),
            -- LcdAfter = clamp(settings.lcdAfter, 0.0, 1.0),
            -- HueWobble = clamp(settings.hueWobble, 0.0, 0.1),
            PosterizeStrength = strength,
            PosterizeSteps = math.floor(clamp(settings.posterizeLevels, 2, 256) + 0.5) - 1,
            PosterizeLift = math.max(0.05, settings.posterizeLift),
            -- TintEnabled = settings.tintEnabled and 1.0 or 0.0,
            -- Tint = {
            --     clamp(settings.tintRed, 0.0, 2.0),
            --     clamp(settings.tintGreen, 0.0, 2.0),
            --     clamp(settings.tintBlue, 0.0, 2.0)
            -- },
            -- SharpenStrength = clamp(settings.sharpenStrength, 0.0, 5.0),
            -- GlowAmount = settings.glowEnabled and clamp(settings.glowAmount, 0.0, 2.0) or 0.0,
            -- GlowThreshold = clamp(settings.glowThreshold, 0.0, 0.99),
            -- GlowRadius = clamp(settings.glowRadius, 1.0, 24.0),
            -- StaticAmount = clamp(settings.staticAmount, 0.0, 1.0)
        }
    }

    Render.AddFullscreenPass {
        name = "Retro Posterize",
        stage = stage,
        order = 0,
        execute = function(ctx, frame)
            if grainAmount > 0.0 then
                grainFrame = (grainFrame + 1) % 2147483648
                buffer:Set("GrainFrame", grainFrame)
            end
            ctx:SetPixelShader(shader)
            ctx:SetRenderTarget(frame.outputColor)
            ctx:BindTexture(0, frame.inputColor)
            ctx:BindConstantBuffer(5, buffer)
            ctx:DrawFullscreen()
        end
    }
end

local function addBleedPass(settings, stage)
    local amount = clamp(settings.bleedAmount, 0.0, 1.0)
    if not settings.bleedEnabled or amount == 0.0 then return end

    local shader = Render.LoadShader("game/shaders/retrolook.postprocess.json")
    local white = "engine/primitives/white/texture.png"
    local useMask = settings.bleedMask ~= ""
    local mode = math.floor(clamp(settings.bleedMode, 0, 3) + 0.5)
    local useCustomCurve = mode == 3 and settings.bleedCustomCurve ~= ""
    local mask = Render.LoadTexture(useMask and settings.bleedMask or white)
    local curve = Render.LoadTexture(useCustomCurve and settings.bleedCustomCurve or white)
    local buffer = Render.CreateConstantBuffer {
        shader = shader,
        name = "BleedParams",
        values = {
            BleedAmount = amount,
            BleedMode = mode,
            BleedMaskChannel = useMask and (settings.bleedMaskUseAlpha and 2 or 1) or 0,
        }
    }
    Render.AddFullscreenPass {
        name = "Retro Bleed",
        stage = stage,
        order = 1,
        execute = function(ctx, frame)
            ctx:SetPixelShader(shader)
            ctx:SetRenderTarget(frame.outputColor)
            ctx:BindTexture(0, frame.inputColor)
            ctx:BindTexture(1, mask)
            ctx:BindTexture(2, curve)
            ctx:BindConstantBuffer(6, buffer)
            ctx:DrawFullscreen()
        end
    }
end

function OnStart()
    local settings = Properties
    if not settings.enabled then return end

    local stage = settings.affectUI and Render.Stage.AfterUI or Render.Stage.AfterTonemap
    addPosterizePass(settings, stage)
    addBleedPass(settings, stage)
end
