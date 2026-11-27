local function create(settings)
    -- Lock art and screwdriver contact use the fixed play camera coordinates.
    local pixel = 2 * 7.2 * math.tan(0.72 / 2) / 1080
    local lockY = settings.lockHeightOffset + (540 - 379) * pixel
    local socketRadius = settings.socketRadius
    local socketFaceZ = settings.socketFaceZ
    local hingeToLock = settings.hingeToLock
    local hingeDepth = settings.hingeDepth
    local dialMount = { hingeToLock, 0, -hingeDepth }
    local safeScale = { settings.safeScaleX, settings.safeScaleY, settings.safeScaleZ }
    local lockScale = { settings.lockScaleX, settings.lockScaleY, settings.lockScaleZ }
    local origin = { 0, 0, 0 }

    return {
        hinge = { -hingeToLock, lockY, hingeDepth },
        handlePivot = { settings.handlePivotX, 0, settings.handlePivotZ },
        dialMount = dialMount,
        pickContact = { 0, lockY - socketRadius, socketFaceZ },
        cabinet = {
            name = "Safe Cabinet", mesh = settings.cabinetMesh, material = settings.cabinetMaterial,
            position = { 0, lockY, 0 },
            scale = safeScale,
        },
        frame = {
            name = "Safe Frame", mesh = settings.frameMesh, material = settings.hardwareMaterial,
            position = { 0, lockY, 0 },
            scale = safeScale,
        },
        door = {
            name = "Safe Door", mesh = settings.doorMesh, material = settings.cabinetMaterial,
            position = origin,
            scale = safeScale,
        },
        handle = {
            name = "Safe Handle", mesh = settings.handleMesh, material = settings.hardwareMaterial,
            position = origin,
            scale = safeScale,
        },
        dial = {
            name = "Safe dial", mesh = settings.dialMesh, material = settings.dialSatinMaterial,
            position = dialMount,
            scale = lockScale,
        },
        plug = {
            name = "Lock plug", mesh = settings.plugMesh, material = settings.dialGraphiteMaterial,
            position = origin,
            scale = lockScale,
        },
        strikeGuide = {
            name = "Strike guide", mesh = settings.strikeGuideMesh, material = settings.strikeGuideMaterial,
            position = { 0, lockY - socketRadius, socketFaceZ + settings.strikeGuideDepthOffset },
            scale = { settings.strikeGuideScaleX, settings.strikeGuideScaleY, settings.strikeGuideScaleZ },
        },
        socket = {
            radius = socketRadius,
            housing = {
                name = "Socket housing", mesh = settings.socketMesh, material = settings.dialSatinMaterial,
                position = origin, scale = lockScale,
            },
            inset = {
                name = "Socket inset", mesh = settings.cylinderMesh, material = settings.darkMaterial,
                position = { 0, 0, settings.socketInsetZ },
                scale = { settings.socketInsetScaleX, settings.socketInsetScaleY, settings.socketInsetScaleZ },
            },
            livePin = {
                name = "Live pin", mesh = settings.livePinMesh, material = settings.livePinMaterial,
                position = { 0, 0, settings.livePinZ }, scale = lockScale,
            },
        },
        linkMarker = {
            mesh = settings.cylinderMesh, material = settings.darkMaterial,
            scale = { settings.linkMarkerScaleX, settings.linkMarkerScaleY, settings.linkMarkerScaleZ },
            radius = settings.linkMarkerRadius, depth = settings.linkMarkerDepth, spacing = settings.linkMarkerSpacing,
        },
        springMarker = {
            mesh = settings.springMarkerMesh, material = settings.darkMaterial,
            scale = { settings.springMarkerScaleX, settings.springMarkerScaleY, settings.springMarkerScaleZ },
            radius = settings.springMarkerRadius, depth = settings.springMarkerDepth,
        },
        lights = {
            key = {
                name = "Safe key light",
                position = { settings.keyLightPositionX, settings.keyLightPositionY, settings.keyLightPositionZ },
                color = { settings.keyLightColorR, settings.keyLightColorG, settings.keyLightColorB },
                range = settings.keyLightRange, intensity = settings.keyLightIntensity,
            },
            fill = {
                name = "Safe fill light",
                position = { settings.fillLightPositionX, settings.fillLightPositionY, settings.fillLightPositionZ },
                color = { settings.fillLightColorR, settings.fillLightColorG, settings.fillLightColorB },
                range = settings.fillLightRange, intensity = settings.fillLightIntensity,
            },
            dialAccent = {
                name = "Dial accent light",
                position = { settings.dialLightPositionX, lockY + settings.dialLightHeightOffset, settings.dialLightPositionZ },
                color = { settings.dialLightColorR, settings.dialLightColorG, settings.dialLightColorB },
                range = settings.dialLightRange, intensity = settings.dialLightIntensity,
            },
            interior = {
                name = "Safe interior light",
                position = { settings.interiorLightPositionX, lockY + settings.interiorLightHeightOffset, settings.interiorLightPositionZ },
                color = { settings.interiorLightColorR, settings.interiorLightColorG, settings.interiorLightColorB },
                range = settings.interiorLightRange, activeIntensity = settings.interiorLightIntensity,
            },
            shock = {
                name = "Shock flash",
                position = { 0, lockY - socketRadius, settings.shockLightPositionZ },
                color = { settings.shockLightColorR, settings.shockLightColorG, settings.shockLightColorB },
                range = settings.shockLightRange, activeIntensity = settings.shockLightIntensity,
            },
            bulb = {
                position = { 0, 0, settings.bulbPositionZ },
                color = { settings.bulbColorR, settings.bulbColorG, settings.bulbColorB },
                range = settings.bulbRange, activeIntensity = settings.bulbIntensity,
                pulseAngularSpeed = 2 * math.pi / 6, pulseFraction = 0.6 / 4.4,
            },
        },
        animation = {
            shockFlashTime = settings.shockFlashTime,
            handlePullPeak = settings.handlePullPeak,
            handleReleaseEnd = settings.handleReleaseEnd,
            handleReleaseDuration = settings.handleReleaseDuration,
            handleYaw = settings.handleYaw,
            handleRoll = settings.handleRoll,
            openDialRotation = settings.openDialRotation,
            openHingeYaw = settings.openHingeYaw,
            strikeGuideShrink = settings.strikeGuideShrink,
        },
    }
end

return create
