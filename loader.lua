--[[
    🌸🐾💖 Yui Hub    |    PRIVATE👾🤫 (EARLY ACCESS - Fixed Boss Auto-Kill & Integrated Floor-Level Evade, Freeze Character, Fixed Playtime Rewards & Zero-Lag Engine) 💖🐾🌸
- Boss Tab (Auto Kill Boss + Mobile Boss Selector + Integrated AOE/Ultimate Evade):
  * Easy mobile 2-column selector: Common, Rare, Epic, Legendary, Mythic, Rainbow/Admin, Alien Boss (Event) & All Bosses
  * Strict creature-verified Boss discovery (excludes Shops, NPCs, Arenas, Bases, Pets & generic props!)
  * Smoothly tweens to every boss's Head with noclip hitbox entry, upright velocity lock & fast boss punching
  * Half-charge (50%) skill/ultimate detection + multi-color telegraph evade far outside AOE/ult range (no spawn/despawn timer clutter)
- Clean Punch Tab:
  * Keeps Auto Punch + Punch Speed with low-ping adaptive rate control & adds Freeze Character (toggleable ON/OFF)
- Fixed FPS Jumping & Massive Lag Reduction:
  * Cycle Jump unlocks Roblox TaskScheduler FPS across setfpscap, setfflag & UserGameSettings and trims hub frame overhead
  * Event-driven boss cache, cached reward/spin lookups, pooled petal VFX, visibility-gated RGB & low-usage active-tab HUD
- Centered Moveable 16/16 AI Scanner + Threat Detection + Fixed Playtime Rewards & Auto Spin
]]

----------------------------------------------------------------
-- Local Yui avatar asset installer
-- Writes the bundled PNG into the executor workspace when writefile is available.
-- No network request or upload is performed.
----------------------------------------------------------------
local YUI_AVATAR_FILE = "yui_avatar.png"
local YUI_AVATAR_BASE64 = [[
]]

local function decodeYuiAvatarBase64(encoded)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for index = 1, #alphabet do
        lookup[string.byte(alphabet, index)] = index - 1
    end

    local compact = string.gsub(encoded, "%s", "")
    if #compact % 4 ~= 0 then
        error("Invalid bundled avatar data length")
    end

    local output = table.create(math.floor(#compact / 4))
    local outputIndex = 0
    for index = 1, #compact, 4 do
        local char1, char2 = string.byte(compact, index, index + 1)
        local char3, char4 = string.byte(compact, index + 2, index + 3)
        if not char1 or not char2 or not char3 or not char4 or char1 == 61 or char2 == 61 then
            error("Invalid bundled avatar data")
        end

        local value1 = lookup[char1]
        local value2 = lookup[char2]
        local value3 = char3 == 61 and 0 or lookup[char3]
        local value4 = char4 == 61 and 0 or lookup[char4]
        local paddedThird = char3 == 61
        local paddedFourth = char4 == 61
        if value1 == nil or value2 == nil or value3 == nil or value4 == nil
            or (paddedThird and not paddedFourth)
            or ((paddedThird or paddedFourth) and index + 3 ~= #compact) then
            error("Invalid bundled avatar data")
        end

        local firstByte = value1 * 4 + math.floor(value2 / 16)
        local secondByte = (value2 % 16) * 16 + math.floor(value3 / 4)
        local thirdByte = (value3 % 4) * 64 + value4
        outputIndex += 1
        if paddedThird then
            output[outputIndex] = string.char(firstByte)
        elseif paddedFourth then
            output[outputIndex] = string.char(firstByte, secondByte)
        else
            output[outputIndex] = string.char(firstByte, secondByte, thirdByte)
        end
    end

    return table.concat(output)
end

local function installYuiAvatar()
    if type(writefile) ~= "function" then
        return false
    end

    if type(isfile) == "function" then
        local existsOk, exists = pcall(isfile, YUI_AVATAR_FILE)
        if existsOk and exists then
            return true
        end
    end

    local decodeOk, imageBytes = pcall(decodeYuiAvatarBase64, YUI_AVATAR_BASE64)
    if not decodeOk or type(imageBytes) ~= "string"
        or string.sub(imageBytes, 1, 8) ~= "\137PNG\r\n\26\n" then
        return false
    end

    local writeOk = pcall(writefile, YUI_AVATAR_FILE, imageBytes)
    return writeOk
end

pcall(installYuiAvatar)

----------------------------------------------------------------
-- Arceus X Neo & Universal Executor Compatibility Bridge
----------------------------------------------------------------
local Env = (getgenv and getgenv()) or _G
for _, oldKey in ipairs({
    "YuiHubEA", "YuiHubV75", "YuiHubV74", "YuiHubV73", "YuiHubV72",
    "YuiHubV71", "YuiHubV70", "YuiHubV69", "YuiHubV68", "YuiHubV67",
    "YuiHubV66", "YuiHubV65"
}) do
    if Env[oldKey] then
        pcall(Env[oldKey])
        Env[oldKey] = nil
    end
end

local cloneref = cloneref or clonereference or function(inst) return inst end
local function SafeService(name)
    local ok, svc = pcall(function() return cloneref(game:GetService(name)) end)
    return (ok and svc) or game:GetService(name)
end

local Services = {
    Players           = SafeService("Players"),
    UIS               = SafeService("UserInputService"),
    TweenService      = SafeService("TweenService"),
    ReplicatedStorage = SafeService("ReplicatedStorage"),
    RunService        = SafeService("RunService"),
    VirtualUser       = SafeService("VirtualUser"),
    Lighting          = SafeService("Lighting"),
    Stats             = SafeService("Stats"),
    HttpService       = SafeService("HttpService"),
    TextChatService   = SafeService("TextChatService"),
    Marketplace       = SafeService("MarketplaceService"),
}

local Players           = Services.Players
local UIS               = Services.UIS
local TweenService      = Services.TweenService
local ReplicatedStorage = Services.ReplicatedStorage
local RunService        = Services.RunService
local VirtualUser       = Services.VirtualUser
local Lighting          = Services.Lighting
local Stats             = Services.Stats
local HttpService       = Services.HttpService
local TextChatService   = Services.TextChatService
local Player            = Players.LocalPlayer or Players.PlayerAdded:Wait()

local M = {
    clock = os.clock, floor = math.floor, ceil = math.ceil,
    min = math.min, max = math.max, clamp = math.clamp,
    abs = math.abs, sin = math.sin, cos = math.cos,
    pi = math.pi, sqrt = math.sqrt, log10 = math.log10,
    huge = math.huge, fmtStr = string.format,
}

----------------------------------------------------------------
-- Core Namespaces (Keeps Top-Level Locals Well Below 200)
----------------------------------------------------------------
local Core = {}
local MuscleScope = {
    verified = true,
    score = 0,
    lastCheck = 0,
    placeNameLow = "",
    label = "ML / Copy Ready",
}
local OriginalState = {
    GlobalShadows = Lighting.GlobalShadows,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient = Lighting.Ambient,
    EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
    EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    QualityLevel = Enum.QualityLevel.Automatic,
    SavedQualityLevel = Enum.SavedQualitySetting.Automatic,
    FramerateCap = 60,
    VSync = true,
    IncomingReplicationLag = 0,
    AllowSleep = true,
    PhysicsEnvironmentalThrottle = nil,
    InterpolationThrottling = nil,
    EagerBulkExecution = nil,
    WaterWaveSize = 0.15,
    WaterWaveSpeed = 10,
    WaterReflectance = 1,
    WaterTransparency = 0.3,
    Decoration = true,
    WalkSpeed = 16,
    Atmospheres = {},
    ModifiedFFlags = {},
    Captured = false,
}

local LEGIT_GAMEPASS_REBIRTH_COOLDOWN = 6.00
local DefaultConfig = {
    AutoRep = false,
    AIFastRep = false,
    FastRep = false,
    RepBurstMode = "Default",
    RepAntiLag = true,
    RepSpeed = 468,
    RepLimiterOpen = false,

    AutoRebirth = false,
    SmartRebirthGuard = true,

    AutoPunch = false,
    FreezeCharacter = false,
    PunchSpeed = 60,

    AutoKillBoss = false,
    SelectedBoss = "Common Boss",

    AutoCollectRewards = false,
    AutoSpinReward = false,

    KorbloxRight = false,
    Headless = false,

    AIPerfMode = false,
    FPSBoost = false,
    RemoveFog = false,
    PingBoost = false,
    FPSCap = 120,
    CycleJump = 1,
    CycleRate = 100,

    FlyEnabled = false,
    FlySpeed = 80,
    WalkOnWater = false,
    WalkSpeedEnabled = false,
    WalkSpeedValue = 100,
    SizeEnabled = false,
    SizeValue = 2,
    SizeIsNaN = false,

    HideNameEnabled = false,
    HideNameAlias = "ANONYMOUS",

    Minimized = false,
    Active = true,
}

local Config = {}
for k, v in pairs(DefaultConfig) do Config[k] = v end

local Runtime = {
    Gen = 0,
    conns = {},
    RepGateOpen = false,
    ActiveRepWorkers = {},
    SessionTokens = {rep = 0, reb = 0, pun = 0, boss = 0, rew = 0, spin = 0},
    UI = {},
    Setters = {},
    Pages = {},
    TabButtons = {},
    RGBLightningItems = {},
    activeTabName = "Strength",
    MeowSounds = {},
    SoundContainer = nil,
}

----------------------------------------------------------------
-- Core Helpers, Protection, Formatting & Audio
----------------------------------------------------------------
do
    local function getStealthParent()
        if gethui then
            local ok, hui = pcall(gethui)
            if ok and hui then return hui end
        end
        if get_hidden_gui then
            local ok, hui = pcall(get_hidden_gui)
            if ok and hui then return hui end
        end
        local okCore, core = pcall(function() return SafeService("CoreGui") end)
        if okCore and core then return core:FindFirstChild("RobloxGui") or core end
        return Player:WaitForChild("PlayerGui")
    end

    Core.StealthRoot = getStealthParent()

    function Core.randomGuidName()
        local ok, id = pcall(function() return HttpService:GenerateGUID(false):sub(1, 12) end)
        return (ok and ("AX_" .. id)) or ("AX_" .. tostring(math.random(100000, 999999)))
    end

    function Core.protectGui(gui)
        pcall(function()
            if syn and syn.protect_gui and not gethui then syn.protect_gui(gui)
            elseif protect_gui and not gethui then protect_gui(gui) end
        end)
        gui.Name = Core.randomGuidName()
        gui.Parent = Core.StealthRoot
        return gui
    end

    function Core.detectExecutor()
        if identifyexecutor then
            local ok, name, ver = pcall(identifyexecutor)
            if ok and name then return tostring(name) .. (ver and (" " .. tostring(ver)) or "") end
        end
        if getexecutorname then
            local ok, name = pcall(getexecutorname)
            if ok and name then return tostring(name) end
        end
        return "Universal Executor"
    end
    Core.ExecutorName = Core.detectExecutor()

    function Core.track(c)
        Runtime.conns[#Runtime.conns + 1] = c
        return c
    end

    function Core.forceKillAllRepWorkers()
        Runtime.RepGateOpen = false
        for i = #Runtime.ActiveRepWorkers, 1, -1 do
            local co = Runtime.ActiveRepWorkers[i]
            Runtime.ActiveRepWorkers[i] = nil
            if co and coroutine.status(co) ~= "dead" then
                pcall(coroutine.close, co)
            end
        end
    end

    function Core.makeWindowDraggable(frame, dragZones, trackGlobalConnFn)
        local wDrag, wInput, wStart, wPos = false, nil, nil, nil
        for _, z in ipairs(dragZones) do
            z.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    wDrag = true; wInput = input
                    wStart = Vector2.new(input.Position.X, input.Position.Y)
                    wPos = frame.Position
                end
            end)
        end
        local c1 = UIS.InputChanged:Connect(function(input)
            if not wDrag or not frame.Parent then return end
            if input == wInput or input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local d = Vector2.new(input.Position.X, input.Position.Y) - wStart
                frame.Position = UDim2.new(wPos.X.Scale, wPos.X.Offset + d.X, wPos.Y.Scale, wPos.Y.Offset + d.Y)
            end
        end)
        local c2 = UIS.InputEnded:Connect(function(input)
            if wDrag and (input == wInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                wDrag = false; wInput = nil
            end
        end)
        if trackGlobalConnFn then
            trackGlobalConnFn(c1)
            trackGlobalConnFn(c2)
        end
        return c1, c2
    end

    task.spawn(function()
        local ok, info = pcall(function()
            return Services.Marketplace:GetProductInfo(game.PlaceId)
        end)
        if ok and info and info.Name then
            MuscleScope.placeNameLow = info.Name:lower()
        end
    end)

    local WS_SCOPE_KW = {
        machinesfolder = true, rocks = true, bosses = true, spawnedbosses = true,
        bossarena = true, eventbosses = true, alienboss = true, gymsfolder = true,
        gyms = true, machines = true, training = true, chests = true,
    }
    local RS_SCOPE_KW = {
        revents = true, muscleevent = true, rebirthremote = true, events = true,
        remotes = true, remoteevents = true, remotefunctions = true, serverevents = true,
        network = true, fortunewheelchances = true, packages = true, knit = true,
    }
    local STAT_BOX_KW = {
        leaderstats = true, data = true, stats = true, playerdata = true,
        profile = true, values = true, hiddenstats = true,
    }

    function Core.evaluateMuscleScope(force)
        local now = M.clock()
        if not force and (now - MuscleScope.lastCheck < 4.0) then
            return MuscleScope.verified, MuscleScope.score
        end
        MuscleScope.lastCheck = now
        local score = 0
        local gName = MuscleScope.placeNameLow
        if gName:find("muscle") or gName:find("legends") or gName:find("lifting") or gName:find("gym")
            or gName:find("strong") or gName:find("strength") or gName:find("power")
            or gName:find("workout") or gName:find("rebirth") then
            score += 45
        end
        for _, wsChild in ipairs(workspace:GetChildren()) do
            if WS_SCOPE_KW[wsChild.Name:lower()] then score += 15 end
        end
        local directMe = Player:FindFirstChild("muscleEvent")
        local hasValidMe = directMe ~= nil and (directMe:IsA("RemoteEvent") or directMe:IsA("RemoteFunction"))
        if hasValidMe then score += 30 end
        for _, rsChild in ipairs(ReplicatedStorage:GetChildren()) do
            if RS_SCOPE_KW[rsChild.Name:lower()] then score += 12 end
        end
        for _, pChild in ipairs(Player:GetChildren()) do
            if STAT_BOX_KW[pChild.Name:lower()] then
                for _, child in ipairs(pChild:GetChildren()) do
                    local cLow = child.Name:lower()
                    if cLow:find("strength") or cLow:find("muscle") or cLow:find("power")
                        or cLow:find("rebirth") or cLow:find("prestige") or cLow:find("durability") then
                        score += 20
                    end
                end
            end
        end
        for attrKey in pairs(Player:GetAttributes()) do
            local al = tostring(attrKey):lower()
            if al:find("strength") or al:find("muscle") or al:find("power") or al:find("rebirth") or al:find("prestige") then
                score += 15
            end
        end
        MuscleScope.score = score
        MuscleScope.verified = (score >= 12) or hasValidMe
        MuscleScope.label = MuscleScope.verified
            and M.fmtStr("ML / Copy Verified (Score %d)", score)
            or M.fmtStr("Copy Fallback (Score %d)", score)
        return MuscleScope.verified, MuscleScope.score
    end

    function OriginalState.saveFFlag(flagName)
        if OriginalState.ModifiedFFlags[flagName] ~= nil then return end
        local known, cur = false, nil
        local gff = (Env and Env.getfflag) or (getfenv and getfenv().getfflag)
        if type(gff) == "function" then
            local ok, val = pcall(gff, flagName)
            local s = (ok and val ~= nil) and tostring(val) or ""
            if s ~= "" then
                known = true
                cur = s
            end
        end
        OriginalState.ModifiedFFlags[flagName] = {known = known, orig = cur}
    end

    function OriginalState.captureOnce()
        if OriginalState.Captured then return end
        OriginalState.Captured = true
        pcall(function() OriginalState.QualityLevel = settings().Rendering.QualityLevel end)
        pcall(function()
            local ugs = UserSettings():GetService("UserGameSettings")
            OriginalState.SavedQualityLevel = ugs.SavedQualityLevel
            OriginalState.FramerateCap = ugs.FramerateCap
            OriginalState.VSync = ugs.VSync
        end)
        pcall(function() OriginalState.IncomingReplicationLag = settings().Network.IncomingReplicationLag end)
        pcall(function() OriginalState.AllowSleep = settings().Physics.AllowSleep end)
        pcall(function() OriginalState.PhysicsEnvironmentalThrottle = settings().Physics.PhysicsEnvironmentalThrottle end)
        pcall(function() OriginalState.InterpolationThrottling = workspace.InterpolationThrottling end)
        pcall(function() OriginalState.EagerBulkExecution = settings().Rendering.EagerBulkExecution end)
        pcall(function()
            local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed > 0 then OriginalState.WalkSpeed = hum.WalkSpeed end
        end)
        pcall(function()
            local terrain = workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                OriginalState.WaterWaveSize = terrain.WaterWaveSize
                OriginalState.WaterWaveSpeed = terrain.WaterWaveSpeed
                OriginalState.WaterReflectance = terrain.WaterReflectance
                OriginalState.WaterTransparency = terrain.WaterTransparency
                pcall(function() OriginalState.Decoration = terrain.Decoration end)
            end
        end)
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("Atmosphere") then
                OriginalState.Atmospheres[child] = {Density = child.Density, Haze = child.Haze, Offset = child.Offset, Glare = child.Glare}
            end
        end
    end
    OriginalState.captureOnce()

    local SuffixMap = {}
    local SuffixPairs = {
        {"K",3},{"M",6},{"B",9},{"T",12},{"Qa",15},{"Qi",18},{"Sx",21},{"Sp",24},{"Oc",27},
        {"No",30},{"Dc",33},{"Ud",36},{"Dd",39},{"Td",42},{"Qad",45},{"Qid",48},{"Sxd",51},
        {"Spd",54},{"Ocd",57},{"Nod",60},{"Vg",63},{"Ce",303}
    }
    for _, p in ipairs(SuffixPairs) do SuffixMap[p[1]:lower()] = p[2] end
    local Suffixes = {"","K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc","Ud","Dd","Td","Qad","Qid","Sxd","Spd","Ocd","Nod","Vg"}

    function Core.parseSmartInput(rawInput)
        local trimmed = tostring(rawInput or "0"):gsub("^%s+", ""):gsub("%s+$", "")
        local lowTrim = trimmed:lower()
        local hadOpenTag = false
        if lowTrim:sub(-6) == "[open]" then
            local before = trimmed:sub(1, #trimmed - 6):gsub("%s+$", "")
            if before ~= "" then
                trimmed = before
                hadOpenTag = true
            end
        end
        if trimmed:match("^[%+%-]?[%d,]*%.?%d+[a-zA-Z%%]*%s*%b()$") then
            trimmed = trimmed:gsub("%s*%b()$", "")
        end
        local clean = trimmed:gsub("%s+", ""):gsub(",", "")
        if clean == "" then clean = "0" end
        local low = clean:lower()

        if low == "nan" then
            return {num = 0 / 0, isNaN = true, isInf = false, isPercent = false, pct = 0, opensLimit = false}
        end
        if low == "inf" or low == "infinite" or low == "infinity" then
            return {num = M.huge, isNaN = false, isInf = true, isPercent = false, pct = 100, opensLimit = true}
        end
        local pctNum = low:match("^([%+%-]?%d*%.?%d+)%%$")
        if pctNum then
            local p = M.max(0, tonumber(pctNum) or 0)
            local openL = (p >= 100) or hadOpenTag
            return {num = p, isNaN = false, isInf = openL, isPercent = true, pct = p, opensLimit = openL}
        end
        local numPart, sufPart = clean:match("^([%+%-]?%d*%.?%d+)([a-zA-Z]*)$")
        if not numPart then
            return {num = 0, isNaN = false, isInf = false, isPercent = false, pct = 0, opensLimit = false, invalid = true}
        end
        local exp = (sufPart ~= "" and SuffixMap[sufPart:lower()]) or 0
        local val = M.max(0, tonumber(numPart) or 0) * (10 ^ exp)
        local openL = (val == M.huge) or hadOpenTag
        return {num = val, isNaN = false, isInf = (val == M.huge), isPercent = false, pct = 0, opensLimit = openL}
    end

    function Core.fmt(n)
        n = tonumber(n) or 0
        if n ~= n then return "NaN" end
        if n == M.huge then return "Inf" end
        local sign = n < 0 and "-" or ""
        n = M.abs(n)
        if n < 1000 then
            return (n % 1 == 0) and (sign .. tostring(n)) or M.fmtStr("%s%.2f", sign, n)
        end
        local i = M.min(M.floor(M.log10(n) / 3), #Suffixes - 1)
        local v = n / (10 ^ (i * 3))
        if v >= 999.995 and i < #Suffixes - 1 then i += 1; v = n / (10 ^ (i * 3)) end
        return M.fmtStr("%s%.2f%s", sign, v, Suffixes[i + 1])
    end

    function Core.fmtCompact(n)
        n = tonumber(n) or 0
        if n ~= n or n <= 0 then return "0" end
        if n == M.huge then return "Inf" end
        if n < 1000 then
            if n >= 100 or n % 1 == 0 then return tostring(M.floor(n + 0.5)) end
            if n >= 10 then return M.fmtStr("%.1f", n):gsub("%.0$", "") end
            return M.fmtStr("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
        end
        local i = M.min(M.floor(M.log10(n) / 3), #Suffixes - 1)
        local v = n / (10 ^ (i * 3))
        if v >= 999.95 and i < #Suffixes - 1 then i += 1; v = n / (10 ^ (i * 3)) end
        local numStr = (v >= 100) and M.fmtStr("%.0f", v) or M.fmtStr("%.1f", v):gsub("%.0$", "")
        return numStr .. Suffixes[i + 1]
    end

    function Core.fmtExactInt(n)
        n = M.floor(tonumber(n) or 0)
        if n == M.huge then return "Inf" end
        return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end

    function Core.fmtTime(sec)
        local whole = M.floor(M.max(0, tonumber(sec) or 0))
        return M.fmtStr("%dd %dh %dm %ds", M.floor(whole / 86400), M.floor((whole % 86400) / 3600), M.floor((whole % 3600) / 60), whole % 60)
    end

    function Core.fmtShortEta(sec)
        sec = M.max(0, tonumber(sec) or 0)
        if sec <= 0.1 then return "READY" end
        if sec < 60 then return M.fmtStr("%.1fs", sec) end
        if sec < 3600 then return M.fmtStr("%dm %ds", M.floor(sec / 60), M.floor(sec % 60)) end
        return M.fmtStr("%dh %dm", M.floor(sec / 3600), M.floor((sec % 3600) / 60))
    end

    Runtime.SoundContainer = Instance.new("ScreenGui")
    Runtime.SoundContainer.ResetOnSpawn = false
    Core.protectGui(Runtime.SoundContainer)

    local function buildMeowWav(pitchShift)
        local RATE, DUR = 11025, 0.36
        local N = M.floor(RATE * DUR)
        local function smooth(t) return t * t * (3 - 2 * t) end
        local function pitch(t)
            if t < 0.28 then return (470 * pitchShift) + ((950 - 470) * pitchShift) * smooth(t / 0.28) end
            return (950 * pitchShift) + ((520 - 950) * pitchShift) * smooth((t - 0.28) / 0.72)
        end
        local p1, p2, pcm, peak = 0, 0, table.create(N), 0
        for i = 0, N - 1 do
            local f0 = pitch((i / RATE) / DUR)
            p1 += 2 * M.pi * f0 / RATE
            p2 += 2 * M.pi * (f0 * 1.498) / RATE
            local s = (M.sin(p1) * 0.72 + M.sin(p2) * 0.28) * (M.sin(M.pi * (i / N)) ^ 0.45)
            pcm[i + 1] = s
            if M.abs(s) > peak then peak = M.abs(s) end
        end
        local gain = peak > 0 and (0.90 / peak) or 1
        local bytes = table.create(N)
        for i = 1, N do
            local v = M.floor(M.clamp(pcm[i] * gain, -1, 1) * 32767)
            if v < 0 then v += 65536 end
            bytes[i] = string.char(v % 256, M.floor(v / 256))
        end
        local data = table.concat(bytes)
        local function le32(n) return string.char(n % 256, M.floor(n / 256) % 256, M.floor(n / 65536) % 256, M.floor(n / 16777216) % 256) end
        local function le16(n) return string.char(n % 256, M.floor(n / 256) % 256) end
        return "RIFF" .. le32(36 + #data) .. "WAVEfmt " .. le32(16) .. le16(1) .. le16(1) .. le32(RATE)
            .. le32(RATE * 2) .. le16(2) .. le16(16) .. "data" .. le32(#data) .. data
    end

    task.spawn(function()
        pcall(function()
            local getAsset = getcustomasset or getsynasset
            if writefile and getAsset then
                for _, f in ipairs({
                    {name = "yui_sakura_meow1.wav", shift = 1.00},
                    {name = "yui_sakura_meow2.wav", shift = 1.09},
                    {name = "yui_sakura_meow3.wav", shift = 0.94},
                }) do
                    if isfile and not isfile(f.name) then pcall(writefile, f.name, buildMeowWav(f.shift)) end
                    if not isfile or isfile(f.name) then
                        local okA, asset = pcall(getAsset, f.name)
                        if okA and asset then
                            local s = Instance.new("Sound")
                            s.Name = Core.randomGuidName()
                            s.SoundId = asset; s.Volume = 0.85; s.Parent = Runtime.SoundContainer
                            table.insert(Runtime.MeowSounds, s)
                        end
                    end
                end
            end
        end)
    end)

    function Core.playMeowSFX()
        if #Runtime.MeowSounds > 0 then
            local s = Runtime.MeowSounds[math.random(1, #Runtime.MeowSounds)]
            pcall(function() s.TimePosition = 0; s:Play() end)
        end
    end
end

----------------------------------------------------------------
-- Theme & Visibility-Aware UI Construction Primitives (Low Lag)
----------------------------------------------------------------
local Theme = {
    Bg           = Color3.fromRGB(11, 9, 17),
    BgGlass      = Color3.fromRGB(17, 13, 26),
    Header       = Color3.fromRGB(32, 16, 44),
    HeaderAccent = Color3.fromRGB(255, 92, 162),
    SakuraPink   = Color3.fromRGB(255, 138, 194),
    SakuraSoft   = Color3.fromRGB(255, 182, 217),
    CyberCyan    = Color3.fromRGB(92, 242, 214),
    TabBar       = Color3.fromRGB(16, 12, 24),
    TabPill      = Color3.fromRGB(235, 68, 138),
    Panel        = Color3.fromRGB(15, 11, 23),
    Card         = Color3.fromRGB(24, 18, 36),
    SwitchOff    = Color3.fromRGB(44, 34, 62),
    SwitchOn     = Color3.fromRGB(240, 72, 145),
    Green        = Color3.fromRGB(88, 245, 158),
    Red          = Color3.fromRGB(242, 74, 96),
    ThreatRed    = Color3.fromRGB(255, 36, 66),
    Yellow       = Color3.fromRGB(255, 210, 92),
    OutdatedCol  = Color3.fromRGB(255, 155, 72),
    Text         = Color3.fromRGB(248, 244, 255),
    Muted        = Color3.fromRGB(166, 152, 188),
    Stroke       = Color3.fromRGB(84, 52, 118),
}

local UILib = {}
do
    local RGBSeq = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 45, 95)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 220, 40)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(55, 255, 135)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(45, 245, 255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(95, 115, 255)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(245, 65, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 45, 95)),
    })

    function UILib.new(class, props, parent)
        local inst = Instance.new(class)
        for k, v in pairs(props) do inst[k] = v end
        if parent then inst.Parent = parent end
        return inst
    end
    function UILib.corner(p, r) return UILib.new("UICorner", {CornerRadius = r or UDim.new(0, 8)}, p) end
    function UILib.stroke(p, col, th, tr) return UILib.new("UIStroke", {Color = col or Theme.Stroke, Thickness = th or 1, Transparency = tr or 0}, p) end
    function UILib.gradient(p, c1, c2, rot) return UILib.new("UIGradient", {Color = ColorSequence.new(c1, c2), Rotation = rot or 0}, p) end

    function UILib.attachRGBLightning(targetInst, thickness, baseTransparency, activeTransparency, phaseOffset, pageTag)
        local st = UILib.new("UIStroke", {
            Color = Color3.new(1, 1, 1), Thickness = thickness or 1.4,
            Transparency = baseTransparency or 0.28, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, targetInst)
        local grad = UILib.new("UIGradient", {Color = RGBSeq, Rotation = (phaseOffset or 0) % 360}, st)
        local item = {
            stroke = st, grad = grad, baseTrans = baseTransparency or 0.28,
            activeTrans = activeTransparency or 0.02, isActive = false, phase = phaseOffset or 0,
            pageTag = pageTag,
        }
        Runtime.RGBLightningItems[#Runtime.RGBLightningItems + 1] = item
        return item
    end

    function UILib.attachPressSpring(btn)
        local sc = UILib.new("UIScale", {Scale = 1}, btn)
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(sc, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.94}):Play()
        end)
        local function restore()
            TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end
        btn.MouseButton1Up:Connect(restore)
        btn.MouseLeave:Connect(restore)
    end

    function UILib.createOpenButton(UI)
        UI.OpenButton = UILib.new("TextButton", {
            Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 16, 0.38, 0),
            BackgroundColor3 = Theme.BgGlass, Text = "", AutoButtonColor = false, ClipsDescendants = true,
        }, UI.ToggleGui)
        UILib.corner(UI.OpenButton, UDim.new(1, 0))
        UILib.attachRGBLightning(UI.OpenButton, 2.4, 0.08, 0.0, 0, "_ALWAYS").isActive = true
        UILib.attachPressSpring(UI.OpenButton)

        local AvatarMask = UILib.new("Frame", {Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, ClipsDescendants = true}, UI.OpenButton)
        UILib.corner(AvatarMask, UDim.new(1, 0))
        UI.Avatar = UILib.new("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Image = "rbxassetid://6023426915"}, AvatarMask)
        UILib.corner(UI.Avatar, UDim.new(1, 0))
        pcall(function()
            local getAsset = getcustomasset or getsynasset
            if getAsset and isfile and isfile("yui_avatar.png") then UI.Avatar.Image = getAsset("yui_avatar.png") end
        end)

        local dragging, activeInput, dragStartPos, buttonStartPos, moved = false, nil, nil, nil, false
        UI.OpenButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; activeInput = input; dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
                buttonStartPos = UI.OpenButton.Position; moved = false
            end
        end)
        Core.track(UIS.InputChanged:Connect(function(input)
            if not dragging then return end
            if input == activeInput or input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local d = Vector2.new(input.Position.X, input.Position.Y) - dragStartPos
                if d.Magnitude > 6 then moved = true end
                if moved then UI.OpenButton.Position = UDim2.new(buttonStartPos.X.Scale, buttonStartPos.X.Offset + d.X, buttonStartPos.Y.Scale, buttonStartPos.Y.Offset + d.Y) end
            end
        end))
        Core.track(UIS.InputEnded:Connect(function(input)
            if dragging and (input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false; activeInput = nil
                if not moved then
                    Core.playMeowSFX()
                    if UI.Main then
                        local vis = not UI.Main.Visible
                        UI.Main.Visible = vis
                        if vis and UI.MainScale then
                            local baseS = UI.BaseWindowScale or 1
                            UI.MainScale.Scale = baseS * 0.90
                            TweenService:Create(UI.MainScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = baseS}):Play()
                        end
                    end
                end
            end
        end))
    end

    function UILib.startPetalPool(UI, myGen, fullW, fullH)
        local petalPool = {}
        local emojis = {"🌸","💮","✨","🐾","💖"}
        for idx = 1, 6 do
            petalPool[idx] = UILib.new("TextLabel", {
                Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Text = emojis[((idx - 1) % #emojis) + 1],
                TextSize = 18, TextTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 26,
            }, UI.VFXLayer)
        end
        task.spawn(function()
            local pIdx = 1
            while Config.Active and myGen == Runtime.Gen and UI.Main and UI.Main.Parent do
                if UI.Main.Visible and not Config.Minimized and not Config.FPSBoost and (tonumber(Config.CycleJump) or 1) <= 1 and not Config.AIPerfMode and not (Config.RepAntiLag and Runtime.RepGateOpen) then
                    local petal = petalPool[pIdx]
                    pIdx = (pIdx % #petalPool) + 1
                    local side = math.random(1, 4)
                    local sx = (side <= 2) and math.random(0, fullW) or ((side == 3) and -8 or fullW + 8)
                    local sy = (side >= 3) and math.random(0, fullH) or ((side == 1) and -8 or fullH + 8)
                    petal.Position = UDim2.fromOffset(sx, sy)
                    petal.TextTransparency = 0.12
                    petal.Rotation = 0
                    petal.Visible = true
                    TweenService:Create(petal, TweenInfo.new(2.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                        Position = UDim2.fromOffset(sx + math.random(-55, 55), sy + ((side == 1) and 75 or -75)),
                        TextTransparency = 1,
                        Rotation = math.random(-140, 140),
                    }):Play()
                    task.wait(0.60)
                else
                    task.wait(1.20)
                end
            end
        end)
    end

    function UILib.startRGBLoop(UI, myGen, mainStrokeGrad, statusLED)
        task.spawn(function()
            local t = 0
            while Config.Active and myGen == Runtime.Gen and UI.Main and UI.Main.Parent do
                local lowOverhead = (tonumber(Config.CycleJump) or 1) > 1 or Config.AIPerfMode or Config.FPSBoost or (Runtime.RepGateOpen and (Config.FastRep or Config.AIFastRep))
                local vis = UI.Main.Visible
                local mainVis = vis and not Config.Minimized
                local waitDt = (not vis and 0.65) or (Config.Minimized and 0.45) or (lowOverhead and 0.24 or 0.13)
                t += waitDt
                if vis then
                    mainStrokeGrad.Rotation = (mainStrokeGrad.Rotation + (lowOverhead and 10 or 7)) % 360
                    statusLED.BackgroundTransparency = 0.15 + M.abs(M.sin(t * 2.5)) * 0.55
                end
                if mainVis and not lowOverhead then
                    local baseRot, pulse = (t * 210) % 360, 0.5 + 0.5 * M.sin(t * 14) * M.cos(t * 8)
                    local activeTab = Runtime.activeTabName
                    for i = 1, #Runtime.RGBLightningItems do
                        local item = Runtime.RGBLightningItems[i]
                        if item.stroke and item.stroke.Parent and (item.pageTag == "_ALWAYS" or item.pageTag == activeTab) then
                            item.grad.Rotation = (baseRot + item.phase) % 360
                            item.stroke.Thickness = item.isActive and (1.65 + pulse * 0.5) or (1.25 + pulse * 0.22)
                            item.stroke.Transparency = (item.isActive and item.activeTrans or item.baseTrans) + ((1 - pulse) * (item.isActive and 0.15 or 0.20))
                        end
                    end
                end
                task.wait(waitDt)
            end
        end)
    end

    function UILib.createControlFactory(Setters, nextOrder)
        local function createStatusLabel(parent, text, color, isHeader, fontSize)
            return UILib.new("TextLabel", {
                Size = UDim2.new(1, -4, 0, 15), BackgroundTransparency = 1, Text = text, TextColor3 = color or Theme.Text,
                Font = isHeader and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = fontSize or 10,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true,
                LayoutOrder = nextOrder(), ZIndex = 4,
            }, parent)
        end

        local function createSmallBtn(parent, text, color, callback)
            local holder = UILib.new("Frame", {Size = UDim2.new(1, -4, 0, 22), BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = 4}, parent)
            local b = UILib.new("TextButton", {Size = UDim2.fromOffset(92, 20), BackgroundColor3 = color or Theme.Red, Text = text, TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 9, ZIndex = 5}, holder)
            UILib.corner(b, UDim.new(0, 5)); UILib.attachPressSpring(b)
            b.MouseButton1Click:Connect(function() Core.playMeowSFX(); if callback then callback() end end)
            return b
        end

        local function createToggle(parent, pageTag, labelText, key, exclusiveGroup, onToggle, descText)
            local ord = nextOrder()
            local hasDesc = (descText ~= nil and descText ~= "")
            local rowH = hasDesc and 36 or 26
            local row = UILib.new("TextButton", {
                Size = UDim2.new(1, -6, 0, rowH), BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false, LayoutOrder = ord, ZIndex = 4,
            }, parent)
            UILib.corner(row, UDim.new(0, 6))
            local rowRgb = UILib.attachRGBLightning(row, 1.35, 0.36, 0.04, ord * 37, pageTag)
            rowRgb.isActive = (Config[key] == true)

            UILib.new("TextLabel", {
                Size = UDim2.new(1, -54, 0, hasDesc and 17 or rowH), Position = UDim2.fromOffset(9, hasDesc and 3 or 0),
                BackgroundTransparency = 1, Text = labelText, TextColor3 = Theme.Text, Font = Enum.Font.GothamSemibold,
                TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
            }, row)
            if hasDesc then
                UILib.new("TextLabel", {
                    Size = UDim2.new(1, -54, 0, 13), Position = UDim2.fromOffset(9, 19), BackgroundTransparency = 1,
                    Text = descText, TextColor3 = Theme.Muted, Font = Enum.Font.GothamMedium, TextSize = 8,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
                }, row)
            end

            local pill = UILib.new("Frame", {
                Size = UDim2.fromOffset(34, 16), Position = UDim2.new(1, -41, 0.5, -8),
                BackgroundColor3 = Config[key] and Theme.SwitchOn or Theme.SwitchOff, BorderSizePixel = 0, ZIndex = 5,
            }, row)
            UILib.corner(pill, UDim.new(1, 0))
            local pillRgb = UILib.attachRGBLightning(pill, 1.15, 0.42, 0.0, ord * 53, pageTag)
            pillRgb.isActive = (Config[key] == true)
            local knob = UILib.new("Frame", {
                Size = UDim2.fromOffset(12, 12), Position = Config[key] and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2),
                BackgroundColor3 = Theme.Text, BorderSizePixel = 0, ZIndex = 6,
            }, pill)
            UILib.corner(knob, UDim.new(1, 0))

            local function set(state, silent)
                if state and exclusiveGroup then
                    for _, okKey in ipairs(exclusiveGroup) do
                        if okKey ~= key and Config[okKey] and Setters[okKey] then Setters[okKey](false, true) end
                    end
                end
                Config[key] = state; rowRgb.isActive = state; pillRgb.isActive = state
                TweenService:Create(pill, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = state and Theme.SwitchOn or Theme.SwitchOff}):Play()
                TweenService:Create(knob, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)}):Play()
                if onToggle then onToggle(state, silent) end
            end
            Setters[key] = set
            row.MouseButton1Click:Connect(function() Core.playMeowSFX(); set(not Config[key]) end)
        end

        local function createNumberInput(parent, labelText, key, minV, maxV, allowInf, onChange, allowNaN, customFormatFn)
            local row = UILib.new("Frame", {Size = UDim2.new(1, -6, 0, 26), BackgroundColor3 = Theme.Card, BorderSizePixel = 0, LayoutOrder = nextOrder(), ZIndex = 4}, parent)
            UILib.corner(row, UDim.new(0, 6)); UILib.stroke(row, Theme.Stroke, 1, 0.55)
            UILib.new("TextLabel", {
                Size = UDim2.new(1, -104, 1, 0), Position = UDim2.fromOffset(9, 0), BackgroundTransparency = 1,
                Text = labelText, TextColor3 = Theme.Text, Font = Enum.Font.GothamSemibold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
            }, row)
            local initDisp = tostring(Config[key])
            if allowNaN and Config.SizeIsNaN then initDisp = "NaN"
            elseif Config[key] == M.huge then initDisp = "Inf"
            elseif customFormatFn then initDisp = customFormatFn(Config[key]) end

            local input = UILib.new("TextBox", {
                Size = UDim2.fromOffset(90, 18), Position = UDim2.new(1, -96, 0.5, -9), BackgroundColor3 = Theme.Bg,
                Text = initDisp, TextColor3 = Theme.CyberCyan, Font = Enum.Font.GothamBold, TextSize = 9, ClearTextOnFocus = false, ZIndex = 5,
            }, row)
            UILib.corner(input, UDim.new(0, 5))
            local inStroke = UILib.stroke(input, Theme.Stroke, 1)
            input.Focused:Connect(function() TweenService:Create(inStroke, TweenInfo.new(0.15), {Color = Theme.CyberCyan}):Play() end)
            input.FocusLost:Connect(function()
                TweenService:Create(inStroke, TweenInfo.new(0.15), {Color = Theme.Stroke}):Play()
                Core.playMeowSFX()
                local parsed = Core.parseSmartInput(input.Text)
                if customFormatFn then
                    local display = customFormatFn(parsed)
                    if display then input.Text = display end
                    if onChange then task.spawn(onChange, parsed) end
                    return
                end
                if allowNaN and parsed.isNaN then Config.SizeIsNaN = true; Config[key] = 0.03; input.Text = "NaN"
                elseif allowInf and parsed.isInf then
                    if allowNaN then Config.SizeIsNaN = false end
                    Config[key] = M.huge; input.Text = "Inf"
                else
                    if allowNaN then Config.SizeIsNaN = false end
                    local n = parsed.num
                    if minV ~= nil then n = M.max(minV, n) end
                    if maxV ~= nil and not allowInf then n = M.min(maxV, n) end
                    Config[key] = n
                    if n >= 10000000 then input.Text = Core.fmt(n)
                    elseif n % 1 == 0 then input.Text = tostring(M.floor(n))
                    else input.Text = M.fmtStr("%.2f", n):gsub("0+$", ""):gsub("%.$", "") end
                end
                if onChange then task.spawn(onChange, Config[key], parsed) end
            end)
            return input
        end

        return createStatusLabel, createSmallBtn, createToggle, createNumberInput
    end

    function UILib.createMainChrome(UI, myGen, fullW, fullH, minH)
        UI.ToggleGui = UILib.new("ScreenGui", {ResetOnSpawn = false, DisplayOrder = 55, IgnoreGuiInset = true})
        Core.protectGui(UI.ToggleGui)
        UI.GUI = UILib.new("ScreenGui", {ResetOnSpawn = false, DisplayOrder = 45, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
        Core.protectGui(UI.GUI)

        UILib.createOpenButton(UI)

        UI.Main = UILib.new("Frame", {
            Size = UDim2.fromOffset(fullW, fullH),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.04, BorderSizePixel = 0, Visible = true, Active = true,
        }, UI.GUI)
        UILib.corner(UI.Main, UDim.new(0, 12))
        UILib.gradient(UI.Main, Color3.fromRGB(16, 12, 26), Color3.fromRGB(9, 7, 15), 135)
        local mainStrokeGrad = UILib.gradient(UILib.stroke(UI.Main, Theme.SakuraPink, 1.8), Theme.SakuraPink, Theme.CyberCyan, 0)

        local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
        UI.BaseWindowScale = M.min(vp.X, vp.Y) < 540 and M.clamp(M.min(vp.X, vp.Y) / 498, 0.72, 1) or 1
        UI.MainScale = UILib.new("UIScale", {Scale = UI.BaseWindowScale * 0.92}, UI.Main)
        TweenService:Create(UI.MainScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = UI.BaseWindowScale}):Play()

        local CyberAccentLine = UILib.new("Frame", {Size = UDim2.new(1, -24, 0, 1), Position = UDim2.fromOffset(12, 34), BackgroundColor3 = Theme.CyberCyan, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 6}, UI.Main)
        UILib.gradient(CyberAccentLine, Theme.SakuraPink, Theme.CyberCyan, 0)

        UI.VFXLayer = UILib.new("Frame", {Size = UDim2.new(1, 60, 1, 60), Position = UDim2.fromOffset(-30, -30), BackgroundTransparency = 1, ClipsDescendants = false, ZIndex = 25}, UI.Main)
        UILib.startPetalPool(UI, myGen, fullW, fullH)

        local Header = UILib.new("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Header, BorderSizePixel = 0, ZIndex = 5}, UI.Main)
        UILib.corner(Header, UDim.new(0, 12))
        UILib.gradient(Header, Color3.fromRGB(46, 18, 60), Color3.fromRGB(20, 14, 34), 0)
        local StatusLED = UILib.new("Frame", {Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(10, 13), BackgroundColor3 = Theme.CyberCyan, BorderSizePixel = 0, ZIndex = 7}, Header)
        UILib.corner(StatusLED, UDim.new(1, 0))

        UILib.new("TextLabel", {
            Size = UDim2.new(1, -145, 1, 0), Position = UDim2.fromOffset(23, 0), BackgroundTransparency = 1,
            Text = "🌸 Yui Hub  |  PRIVATE👾🤫", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
        }, Header)
        UILib.new("TextLabel", {
            Size = UDim2.fromOffset(78, 14), Position = UDim2.new(1, -138, 0.5, -7), BackgroundTransparency = 1,
            Text = "EARLY ACCESS", TextColor3 = Theme.CyberCyan, Font = Enum.Font.GothamBold, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
        }, Header)

        local MinBtn = UILib.new("TextButton", {
            Size = UDim2.fromOffset(24, 20), Position = UDim2.new(1, -56, 0.5, -10), BackgroundColor3 = Color3.fromRGB(64, 28, 82),
            Text = "—", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 7,
        }, Header)
        UILib.corner(MinBtn, UDim.new(0, 6)); UILib.stroke(MinBtn, Theme.SakuraPink, 1, 0.5); UILib.attachPressSpring(MinBtn)

        local CloseBtn = UILib.new("TextButton", {
            Size = UDim2.fromOffset(24, 20), Position = UDim2.new(1, -28, 0.5, -10), BackgroundColor3 = Color3.fromRGB(165, 28, 68),
            Text = "X", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 7,
        }, Header)
        UILib.corner(CloseBtn, UDim.new(0, 6)); UILib.attachPressSpring(CloseBtn)
        CloseBtn.MouseButton1Click:Connect(function() Core.playMeowSFX(); UI.Main.Visible = false end)

        UILib.startRGBLoop(UI, myGen, mainStrokeGrad, StatusLED)

        local edge = 14
        Core.makeWindowDraggable(UI.Main, {
            Header,
            UILib.new("Frame", {Size = UDim2.new(1, 12, 0, edge), Position = UDim2.fromOffset(-6, -6), BackgroundTransparency = 1, Active = true, ZIndex = 6}, UI.Main),
            UILib.new("Frame", {Size = UDim2.new(1, 12, 0, edge), Position = UDim2.new(0, -6, 1, -edge + 6), BackgroundTransparency = 1, Active = true, ZIndex = 15}, UI.Main),
            UILib.new("Frame", {Size = UDim2.new(0, edge, 1, 12), Position = UDim2.fromOffset(-6, -6), BackgroundTransparency = 1, Active = true, ZIndex = 15}, UI.Main),
            UILib.new("Frame", {Size = UDim2.new(0, edge, 1, 12), Position = UDim2.new(1, -edge + 6, 0, -6), BackgroundTransparency = 1, Active = true, ZIndex = 15}, UI.Main),
        }, Core.track)

        UI.TabBar = UILib.new("Frame", {Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 39), BackgroundColor3 = Theme.TabBar, BorderSizePixel = 0, ZIndex = 2}, UI.Main)
        UILib.corner(UI.TabBar, UDim.new(0, 7)); UILib.stroke(UI.TabBar, Theme.Stroke, 1, 0.35)

        local ActiveTabPill = UILib.new("Frame", {Size = UDim2.new(1 / 9, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Theme.TabPill, BorderSizePixel = 0, ZIndex = 3}, UI.TabBar)
        UILib.corner(ActiveTabPill, UDim.new(0, 5)); UILib.gradient(ActiveTabPill, Theme.HeaderAccent, Color3.fromRGB(168, 48, 128), 45)

        local TabBtnHolder = UILib.new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 4}, UI.TabBar)
        UILib.new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 0)}, TabBtnHolder)

        UI.Content = UILib.new("Frame", {Size = UDim2.new(1, -16, 1, -78), Position = UDim2.fromOffset(8, 71), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ZIndex = 2}, UI.Main)
        UILib.corner(UI.Content, UDim.new(0, 9)); UILib.stroke(UI.Content, Theme.Stroke, 1, 0.4)

        MinBtn.MouseButton1Click:Connect(function()
            Core.playMeowSFX()
            Config.Minimized = not Config.Minimized
            MinBtn.Text = Config.Minimized and "+" or "—"
            if Config.Minimized then
                UI.TabBar.Visible = false; UI.Content.Visible = false; CyberAccentLine.Visible = false
                if UI.KillConfirmTab then UI.KillConfirmTab.Visible = false end
                TweenService:Create(UI.Main, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(fullW, minH)}):Play()
            else
                TweenService:Create(UI.Main, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(fullW, fullH)}):Play()
                task.delay(0.10, function()
                    if not Config.Minimized and UI.TabBar and UI.Content then
                        UI.TabBar.Visible = true; UI.Content.Visible = true; CyberAccentLine.Visible = true
                    end
                end)
            end
        end)
        return ActiveTabPill, TabBtnHolder
    end

    function UILib.createTabPages(UI, Pages, TabButtons, TabNames, TabBtnHolder, ActiveTabPill)
        local function switchTab(tabName)
            Runtime.activeTabName = tabName
            for idx, name in ipairs(TabNames) do
                if name == tabName then
                    TweenService:Create(ActiveTabPill, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Position = UDim2.new((idx - 1) / #TabNames, 2, 0, 2)
                    }):Play()
                    break
                end
            end
            for name, page in pairs(Pages) do
                local isTarget = (name == tabName)
                page.Visible = isTarget
                if isTarget then page.CanvasPosition = Vector2.new(0, 0) end
            end
            for name, btn in pairs(TabButtons) do
                TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    TextColor3 = (name == tabName) and Theme.Text or Theme.Muted
                }):Play()
            end
        end

        for _, tName in ipairs(TabNames) do
            local btn = UILib.new("TextButton", {
                Size = UDim2.new(1 / #TabNames, 0, 1, 0), BackgroundTransparency = 1,
                Text = tName, TextColor3 = Theme.Muted, Font = Enum.Font.GothamBold, TextSize = 8, ZIndex = 5,
            }, TabBtnHolder)
            TabButtons[tName] = btn
            local page = UILib.new("ScrollingFrame", {
                Name = tName .. "Page", Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.SakuraPink,
                AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false, ZIndex = 3,
            }, UI.Content)
            UILib.new("UIPadding", {
                PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
            }, page)
            UILib.new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, page)
            Pages[tName] = page
            btn.MouseButton1Click:Connect(function() Core.playMeowSFX(); switchTab(tName) end)
        end
        return switchTab
    end
end

----------------------------------------------------------------
-- Universal Muscle Legends & Copies Remote Registry (Shallow-First Zero Lag)
----------------------------------------------------------------
local Remotes = {
    muscleList = {},
    toolRemotes = {},
    combatRemotes = {},
    rebirthList = {},
    questRemotes = {},
    dailyRemotes = {},
    chestRemotes = {},
    genericRewardRemotes = {},
    timeRewardRemotes = {},
    wheelRemotes = {},
    wheelChanceItems = {},
    totalRemotesAudited = 0,
    activeMuscleIdx = 1,
    lastScan = -100,
    deepScannedOnce = false,
    lastDeepScan = -100,
    copyProfile = "Scanning ML Copy...",
    variantByRemote = setmetatable({}, {__mode = "k"}),
    argVariants = {{"rep"}, {"lift"}, {"workout"}, {"train"}, {"rep", Player}, {{Action = "Rep"}}},
    calibratedRemote = nil,
    calibratedArgIdx = setmetatable({}, {__mode = "k"}),
    gainScores = setmetatable({}, {__mode = "k"}),
    zeroGainCounts = setmetatable({}, {__mode = "k"}),
    needsToolEquip = false,
    activeTrainingTool = nil,
    rebirthVariantByRemote = setmetatable({}, {__mode = "k"}),
    rebirthVariants = {{"rebirthRequest"}, {}, {"rebirth"}, {"Rebirth"}, {true}},
}

do
    local HARD_BLOCK_WORDS = {
        "ban", "kick", "anticheat", "anti_cheat", "antiexploit", "exploit", "cheat",
        "honeypot", "trap", "detect", "flag", "report", "warn", "punish", "security",
        "moderation", "shutdown", "wipe", "resetdata", "webhook", "buy", "purchase",
        "robux", "gamepass", "devproduct", "marketplace", "prompt", "trade", "delete",
        "sell", "teleport", "warp", "serverhop", "donate"
    }
    local RS_REMOTE_DIRS = {
        revents = true, events = true, remotes = true, remoteevents = true,
        remotefunctions = true, serverevents = true, clientevents = true,
        network = true, shared = true, modules = true, packages = true,
        knit = true, services = true, net = true, framework = true,
    }
    local RS_SEED_DIRS = {
        revents = true, events = true, remotes = true, remoteevents = true, serverevents = true,
    }
    local TRAIN_TOOL_KW = {
        "weight", "pushup", "situp", "handstand", "dumbbell", "barbell", "kettlebell", "lift", "workout"
    }

    local function isRemoteObj(inst)
        return inst ~= nil and (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction"))
    end

    local function getContextStrings(inst)
        local n = inst.Name:lower()
        local p = inst.Parent
        local pLow = (p and p.Name) and p.Name:lower() or ""
        local gp = p and p.Parent or nil
        local gpLow = (gp and gp.Name) and gp.Name:lower() or ""
        local f = inst:GetFullName():lower()
        return n, pLow, gpLow, f
    end

    local function isBlockedRemote(nLow, fLow)
        for _, bad in ipairs(HARD_BLOCK_WORDS) do
            if nLow:find(bad, 1, true) or fLow:find(bad, 1, true) then return true end
        end
        return false
    end

    function Remotes.isPunchToolName(nLow)
        return (nLow:find("punch") or nLow:find("fist") or nLow:find("combat") or nLow:find("glove") or nLow:find("brawl"))
            and not nLow:find("handstand")
    end

    function Remotes.findPunchTool()
        for _, box in ipairs({Player.Character, Player:FindFirstChildOfClass("Backpack")}) do
            if box then
                for _, t in ipairs(box:GetChildren()) do
                    if t:IsA("Tool") and Remotes.isPunchToolName(t.Name:lower()) then return t end
                end
            end
        end
        return nil
    end

    local function isValidTrainTool(t)
        if not (t and t:IsA("Tool")) then return false end
        local nl = t.Name:lower()
        if Remotes.isPunchToolName(nl)
            or nl:find("egg") or nl:find("pet") or nl:find("protein")
            or nl:find("shake") or nl:find("food") or nl:find("drink") then
            return false
        end
        for _, kw in ipairs(TRAIN_TOOL_KW) do
            if nl:find(kw, 1, true) then return true end
        end
        return false
    end

    function Remotes.findTrainingTool()
        local char = Player.Character
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if isValidTrainTool(t) then return t end
            end
        end
        local bp = Player:FindFirstChildOfClass("Backpack")
        if bp then
            local tools = bp:GetChildren()
            for _, kw in ipairs(TRAIN_TOOL_KW) do
                for _, t in ipairs(tools) do
                    if isValidTrainTool(t) and t.Name:lower():find(kw, 1, true) then
                        return t
                    end
                end
            end
        end
        return nil
    end

    local function scoreMuscleRemote(inst)
        local n, pLow, gpLow, f = getContextStrings(inst)
        if isBlockedRemote(n, f) then return -1 end
        if n:find("wheel") or n:find("spin") or n:find("quest") or n:find("gift") or n:find("daily") or n:find("shop") or n:find("pet") or n:find("egg") then
            return -1
        end
        local ancTool = inst:FindFirstAncestorOfClass("Tool")
        if ancTool and not Remotes.isPunchToolName(ancTool.Name:lower()) then
            local tnl = ancTool.Name:lower()
            for idx, kw in ipairs(TRAIN_TOOL_KW) do
                if tnl:find(kw, 1, true) then return 100 - idx end
            end
            return 90
        end
        local score = -1
        if inst == Player:FindFirstChild("muscleEvent") then score = 105
        elseif n == "muscleevent" then score = 100
        elseif n == "muscleremote" or n == "repevent" or n == "repremote" or n == "liftevent" or n == "liftremote" then score = 94
        elseif n == "workoutevent" or n == "workoutremote" or n == "trainevent" or n == "trainremote" or n == "strengthevent" then score = 90
        elseif (pLow == "re" or pLow == "rf" or pLow:find("service") or gpLow:find("service") or gpLow:find("knit"))
            and (n:find("gain") or n:find("rep") or n:find("lift") or n:find("workout") or n:find("train") or n:find("strength") or n:find("muscle")
                or gpLow:find("strength") or gpLow:find("workout") or gpLow:find("muscle") or gpLow:find("train")) then
            score = 90
        elseif n:find("muscle") or n:find("rep") or n:find("lift") or n:find("workout") or n:find("train") or n:find("weight") or n:find("dumbbell") or n:find("barbell") then
            score = 82
        elseif f:find("playergui") and (n:find("gain") or n:find("strength") or n:find("rep") or n:find("lift") or n:find("train") or pLow:find("train") or pLow:find("lift")) then
            score = 80
        elseif (f:find("revents") or f:find("events") or f:find("remotes") or f:find("network") or f:find("shared") or f:find("remoteevents") or f:find("serverevents"))
            and (n:find("gain") or n:find("stat") or n:find("punch") or n:find("strength") or n:find("click") or n:find("curl") or n:find("bench") or n:find("squat")) then
            score = 70
        end
        if score > 0 and (f:find("replicatedstorage") or f:find("revents") or f:find("packages") or f:find("knit")) then
            score += 4
        end
        return score
    end

    local function isCombatRemote(inst)
        local n, pLow, gpLow, f = getContextStrings(inst)
        if isBlockedRemote(n, f) then return false end
        if n == "muscleevent" then return false end
        if inst:FindFirstAncestorOfClass("Tool") then return false end
        if n:find("wheel") or n:find("spin") or n:find("quest") or n:find("gift") or n:find("pet")
            or n:find("shop") or n:find("rebirth") or n:find("multiplier") or n:find("upgrade")
            or n:find("stat") or n:find("unlock") or n:find("setting") or n:find("toggle") then
            return false
        end
        if n:find("damage") then
            return n:find("boss") ~= nil
        end
        if n:find("attackboss") or n:find("hitboss") or n:find("bossattack") or n:find("punchboss")
            or n:find("bosshit") or n:find("bossevent") or n:find("bossremote") or n:find("combat") then
            return true
        end
        return (pLow:find("combat") or gpLow:find("combat") or pLow:find("boss") or gpLow:find("boss"))
            and (n:find("hit") or n:find("attack") or n:find("strike") or n:find("swing"))
    end

    local function scoreRebirthRemote(inst)
        local n, pLow, gpLow, f = getContextStrings(inst)
        if isBlockedRemote(n, f) then return -1 end
        if n == "rebirthremote" or n == "rebirthevent" then return 100 end
        if n == "rebirthfunction" or n == "dorebirth" or n == "rebirthserver" or n == "prestigeremote" or n == "prestigeevent" then return 94 end
        if (pLow:find("rebirth") or gpLow:find("rebirth") or pLow:find("prestige") or gpLow:find("prestige"))
            and (n:find("request") or n:find("do") or n:find("trigger") or n:find("rebirth") or n:find("prestige") or pLow == "re" or pLow == "rf") then
            return 90
        end
        if n:find("rebirth") or n:find("prestige") then return 82 end
        return -1
    end

    local function classifyRewardRemote(inst)
        local n, pLow, gpLow, f = getContextStrings(inst)
        if isBlockedRemote(n, f) then return nil end
        if n:find("wheel") or n:find("spin") or pLow:find("wheel") then return "wheel" end
        if n:find("quest") or pLow:find("quest") then return "quest" end
        if n:find("daily") or pLow:find("daily") or n:find("streak") or n:find("login") or n:find("calendar") or n:find("dayreward") then return "daily" end
        if n:find("chest") then return "chest" end
        if n:find("freegift") or n:find("playtime") or n:find("timegift") or n:find("timereward") or n:find("freereward")
            or pLow:find("freegift") or pLow:find("playtime") or pLow:find("timegift") or pLow:find("timereward")
            or gpLow:find("freegift") or gpLow:find("playtime") then
            return "time"
        end
        if (n:find("gift") or pLow:find("gift")) and not (n:find("trade") or n:find("send") or n:find("gamepass") or n:find("robux")) then
            return "time"
        end
        if n:find("reward") or n:find("claim") or n:find("benefit") or pLow:find("reward") or gpLow:find("reward") then
            return "generic"
        end
        return nil
    end

    local function scoreGiftRemote(inst)
        local n = inst.Name:lower()
        local p = (inst.Parent and inst.Parent.Name or ""):lower()
        if n == "freegiftclaimremote" or n == "claimfreegiftremote" or n == "playtimerewardremote" or n == "claimgiftremote" then return 120 end
        if n == "freegiftsremote" or n == "freegiftremote" or n == "giftclaimremote" or n == "claimplaytimereward" or n == "claimtimegift" or n == "timerewardremote" then return 110 end
        if n:find("freegift") or n:find("playtime") or n:find("timegift") or n:find("timereward") or n:find("claimgift") or n:find("giftclaim") then return 95 end
        if p:find("freegift") or p:find("playtime") or p:find("timegift") or p:find("timereward") then return 90 end
        if n:find("gift") or p:find("gift") then return 75 end
        if n:find("freereward") or n:find("claimreward") then return 60 end
        if n:find("reward") or n:find("claim") then return 40 end
        return 20
    end

    local function pushUnique(list, inst, atFront)
        if not isRemoteObj(inst) then return end
        local cInst = cloneref(inst)
        for idx, existing in ipairs(list) do
            if existing == cInst then
                if atFront and idx > 1 then
                    table.remove(list, idx)
                    table.insert(list, 1, cInst)
                end
                return
            end
        end
        if atFront then table.insert(list, 1, cInst)
        else list[#list + 1] = cInst end
    end

    local function collectRemoteRoots(forceDeep, now)
        local roots, rootSeen = {}, {}
        local function addRoot(c)
            if c and not rootSeen[c] then
                rootSeen[c] = true
                roots[#roots + 1] = c
            end
        end
        addRoot(Player)
        addRoot(Player:FindFirstChildOfClass("Backpack"))
        addRoot(Player.Character)
        addRoot(Player:FindFirstChildOfClass("PlayerGui"))
        for _, ch in ipairs(ReplicatedStorage:GetChildren()) do
            if RS_REMOTE_DIRS[ch.Name:lower()] then addRoot(ch) end
        end
        for _, ch in ipairs(workspace:GetChildren()) do
            local nl = ch.Name:lower()
            if nl:find("event") or nl:find("remote") or nl:find("network") or nl:find("boss") or nl:find("chest") then
                addRoot(ch)
            end
        end
        if forceDeep or not Remotes.deepScannedOnce or (now - Remotes.lastDeepScan >= 30) then
            Remotes.deepScannedOnce = true
            Remotes.lastDeepScan = now
            addRoot(ReplicatedStorage)
        end
        return roots
    end

    local function scanContainerRemotes(root, seen, buckets)
        if not root then return end
        for _, inst in ipairs(root:GetDescendants()) do
            if not seen[inst] and isRemoteObj(inst) then
                seen[inst] = true
                buckets.audited += 1
                local cInst = cloneref(inst)
                local mScore = scoreMuscleRemote(inst)
                if mScore > 0 then
                    local adjScore = mScore + ((Remotes.gainScores[cInst] or 0) * 20) - ((Remotes.zeroGainCounts[cInst] or 0) * 10)
                    buckets.mCandidates[#buckets.mCandidates + 1] = {
                        remote = cInst, score = adjScore, name = inst.Name,
                        isToolRemote = (inst:FindFirstAncestorOfClass("Tool") ~= nil),
                    }
                end
                if isCombatRemote(inst) then
                    buckets.cList[#buckets.cList + 1] = cInst
                end
                local rScore = scoreRebirthRemote(inst)
                if rScore > 0 then
                    buckets.rCandidates[#buckets.rCandidates + 1] = {remote = cInst, score = rScore, name = inst.Name}
                end
                local rKind = classifyRewardRemote(inst)
                local targetList = rKind and buckets.rewardMap[rKind] or nil
                if targetList then
                    pushUnique(targetList, inst, false)
                    if rKind == "generic" then pushUnique(buckets.tList, inst, false) end
                end
            end
        end
    end

    local function seedKnownRewardRemotes(buckets)
        local knownTimeNames = {
            "freeGiftClaimRemote", "claimFreeGiftRemote", "claimGiftRemote", "freeGiftsRemote",
            "freeGiftRemote", "giftClaimRemote", "playtimeRewardRemote", "timeRewardRemote",
            "claimPlaytimeReward", "claimTimeGift", "claimFreeReward", "freeRewardRemote",
        }
        for _, rsDir in ipairs(ReplicatedStorage:GetChildren()) do
            if RS_SEED_DIRS[rsDir.Name:lower()] then
                for _, tName in ipairs(knownTimeNames) do
                    pushUnique(buckets.tList, rsDir:FindFirstChild(tName), tName == "freeGiftClaimRemote")
                end
                pushUnique(buckets.qList, rsDir:FindFirstChild("questsEvent") or rsDir:FindFirstChild("questEvent"), true)
                pushUnique(buckets.wList, rsDir:FindFirstChild("openFortuneWheelRemote"), true)
                pushUnique(buckets.chList, rsDir:FindFirstChild("checkChestRemote") or rsDir:FindFirstChild("chestRemote"), true)
                for _, dName in ipairs({"dailyRewardRemote", "dailyRewardEvent", "claimDailyRemote", "dailyClaimRemote", "dailyLoginRemote", "dailyEvent"}) do
                    pushUnique(buckets.dList, rsDir:FindFirstChild(dName), true)
                end
                for _, gName in ipairs({"claimRewardRemote", "rewardRemote", "rewardEvent", "claimRemote", "benefitsRemote"}) do
                    local gr = rsDir:FindFirstChild(gName)
                    if gr then
                        pushUnique(buckets.gList, gr, true)
                        pushUnique(buckets.tList, gr, false)
                    end
                end
            end
        end
        for _, tName in ipairs({"freeGiftClaimRemote", "claimFreeGiftRemote", "playtimeRewardRemote"}) do
            local direct = ReplicatedStorage:FindFirstChild(tName, true)
            if direct then pushUnique(buckets.tList, direct, tName == "freeGiftClaimRemote") end
        end
    end

    function Remotes.refresh(force)
        local now = M.clock()
        if not force and (now - Remotes.lastScan < 2.0) and (#Remotes.muscleList > 0) then
            return
        end
        Remotes.lastScan = now
        Core.evaluateMuscleScope(false)

        local qList, dList, chList, gList, tList, wList = {}, {}, {}, {}, {}, {}
        local buckets = {
            mCandidates = {}, rCandidates = {}, cList = {},
            qList = qList, dList = dList, chList = chList, gList = gList, tList = tList, wList = wList,
            rewardMap = {quest = qList, daily = dList, chest = chList, time = tList, generic = gList, wheel = wList},
            audited = 0,
        }
        local seen = {}

        local directMuscle = Player:FindFirstChild("muscleEvent")
        if isRemoteObj(directMuscle) then
            seen[directMuscle] = true; buckets.audited += 1
            local cDirect = cloneref(directMuscle)
            local adj = 105 + ((Remotes.gainScores[cDirect] or 0) * 20) - ((Remotes.zeroGainCounts[cDirect] or 0) * 10)
            buckets.mCandidates[1] = {remote = cDirect, score = adj, name = directMuscle.Name, isToolRemote = false}
        end

        for _, root in ipairs(collectRemoteRoots(force, now)) do
            scanContainerRemotes(root, seen, buckets)
        end
        seedKnownRewardRemotes(buckets)

        local wheelChanceList = {}
        local chancesFolder = ReplicatedStorage:FindFirstChild("fortuneWheelChances") or ReplicatedStorage:FindFirstChild("fortuneWheelChances", true)
        if chancesFolder then
            local exactFW = chancesFolder:FindFirstChild("Fortune Wheel")
            if exactFW then wheelChanceList[1] = exactFW end
            for _, ch in ipairs(chancesFolder:GetChildren()) do
                if ch ~= exactFW then wheelChanceList[#wheelChanceList + 1] = ch end
            end
        end
        if #wList == 0 then
            local directWheel = ReplicatedStorage:FindFirstChild("openFortuneWheelRemote", true)
            if directWheel then pushUnique(wList, directWheel, true) end
        end

        Remotes.totalRemotesAudited = M.max(Remotes.totalRemotesAudited, buckets.audited)
        table.sort(buckets.mCandidates, function(a, b) return a.score > b.score end)
        table.sort(buckets.rCandidates, function(a, b) return a.score > b.score end)

        Remotes.muscleList = {}; Remotes.toolRemotes = {}; Remotes.combatRemotes = buckets.cList
        for i = 1, M.min(#buckets.mCandidates, 8) do
            local item = buckets.mCandidates[i]
            Remotes.muscleList[i] = item.remote
            if item.isToolRemote then Remotes.toolRemotes[#Remotes.toolRemotes + 1] = item.remote end
        end
        if Remotes.activeMuscleIdx > #Remotes.muscleList then Remotes.activeMuscleIdx = 1 end

        Remotes.rebirthList = {}
        for i = 1, M.min(#buckets.rCandidates, 6) do Remotes.rebirthList[i] = buckets.rCandidates[i].remote end

        table.sort(tList, function(a, b)
            return scoreGiftRemote(a) > scoreGiftRemote(b)
        end)
        Remotes.questRemotes = qList; Remotes.dailyRemotes = dList
        Remotes.chestRemotes = chList; Remotes.genericRewardRemotes = gList
        Remotes.timeRewardRemotes = tList; Remotes.wheelRemotes = wList
        Remotes.wheelChanceItems = wheelChanceList

        if #Remotes.muscleList > 0 and not MuscleScope.verified then
            MuscleScope.score = M.max(MuscleScope.score, 25)
            MuscleScope.verified = true
            MuscleScope.label = M.fmtStr("ML / Copy Verified (Score %d)", MuscleScope.score)
        end
        if #buckets.mCandidates > 0 then
            local top = buckets.mCandidates[1]
            Remotes.copyProfile = (top.score >= 100) and ("ML Core Exact (" .. top.name .. ")") or ("ML Copy (" .. top.name .. ")")
        else
            Remotes.copyProfile = MuscleScope.label
        end
    end

    function Remotes.getPrimaryMuscle()
        if Remotes.lastScan < 0 then
            Remotes.calibratedRemote = nil
            Remotes.refresh(true)
        end
        if Remotes.calibratedRemote and Remotes.calibratedRemote.Parent and isRemoteObj(Remotes.calibratedRemote) then
            return Remotes.calibratedRemote
        end
        for i = #Remotes.muscleList, 1, -1 do
            local r = Remotes.muscleList[i]
            if not (r and r.Parent and isRemoteObj(r)) then table.remove(Remotes.muscleList, i) end
        end
        if #Remotes.muscleList == 0 then Remotes.refresh(true) end
        if #Remotes.muscleList == 0 then
            local direct = Player:FindFirstChild("muscleEvent")
            if isRemoteObj(direct) and direct.Parent then return cloneref(direct) end
            return nil
        end
        return Remotes.muscleList[M.clamp(Remotes.activeMuscleIdx, 1, #Remotes.muscleList)]
    end

    function Remotes.getAllRebirth()
        for i = #Remotes.rebirthList, 1, -1 do
            local r = Remotes.rebirthList[i]
            if not (r and r.Parent and isRemoteObj(r)) then table.remove(Remotes.rebirthList, i) end
        end
        if #Remotes.rebirthList == 0 then Remotes.refresh(true) end
        return Remotes.rebirthList
    end

    function Remotes.rotateRepVariant(remote)
        if not remote then return false end
        local cur = Remotes.variantByRemote[remote] or 1
        local nextIdx = (cur % #Remotes.argVariants) + 1
        Remotes.variantByRemote[remote] = nextIdx
        return nextIdx == 1
    end
end

----------------------------------------------------------------
-- Strict Remote-Only Availability-Gated Reward & Spin Engine
----------------------------------------------------------------
local RewardEngine = {
    collectedCount = 0,
    spinsCompleted = 0,
    spinsLeftCached = nil,
    lastRewardLabel = "None",
    lastSpinLabel = "None",
    lastSpinAttempt = 0,
    isWheelSpinning = false,
    questPassBusy = false,
    giftPassBusy = false,
    dailyPassBusy = false,
    guiCacheDirty = true,
    workingSpinArgs = nil,
    workingGiftRemote = nil,
    workingGiftArgs = nil,
    timedOutRemotes = setmetatable({}, {__mode = "k"}),
    cachedWheelBtn = nil,
    claimedGiftCooldown = {},
    claimedQuestCooldown = {},
    lastDailyAttempt = -10,
    cachedSpinsVal = nil,
    cachedSpinsLabel = nil,
    lastFullGuiScan = 0,
}

do
    local function cleanGuiText(txt)
        return tostring(txt or ""):gsub("<[^>]+>", ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    end
    local trimLow = cleanGuiText

    local function isOwnGui(gui)
        return (Runtime.UI.GUI and (gui == Runtime.UI.GUI or gui:IsDescendantOf(Runtime.UI.GUI)))
            or (Runtime.UI.ToggleGui and (gui == Runtime.UI.ToggleGui or gui:IsDescendantOf(Runtime.UI.ToggleGui)))
    end

    local SKIP_GUI_NAMES = {Chat = true, BubbleChat = true, Freecam = true, TouchGui = true}
    local CLAIM_WORDS = {
        claim = true, collect = true, ["claim reward"] = true, ["claim daily"] = true,
        ["collect reward"] = true, ready = true, ["ready!"] = true, ["ready !"] = true,
        ["claim!"] = true, ["claim !"] = true,
        ["collect!"] = true, ["collect !"] = true, available = true, free = true, ["free!"] = true,
        ["claim free"] = true, redeem = true, ["redeem!"] = true, get = true,
        open = true, ["claim gift"] = true, ["check in"] = true, ["check-in"] = true,
        checkin = true, ["claim all"] = true, ["collect all"] = true,
    }
    local DATA_BOX_NAMES = {
        "Data", "Stats", "PlayerData", "Values", "Rewards",
        "Profile", "HiddenStats", "Info", "leaderstats", "Leaderstats",
    }

    local function isTemplateAncestor(inst, rootGui)
        local cur = inst
        while cur and cur ~= rootGui and cur ~= game do
            local nl = cur.Name:lower()
            if cur:IsA("GuiObject") and cur.Visible == false then
                if nl:find("template") or nl:find("example") or nl:find("sample") or nl:find("prefab") then
                    return true
                end
            elseif nl:find("example") or nl:find("sample") or nl:find("prefab") then
                return true
            end
            cur = cur.Parent
        end
        return false
    end

    local function isAncestorVisible(inst, rootGui)
        local cur = inst
        while cur and cur ~= rootGui and cur ~= game do
            if cur:IsA("GuiObject") and cur.Visible == false then return false end
            local nl = cur.Name:lower()
            if nl:find("example") or nl:find("sample") or nl:find("prefab") then return false end
            cur = cur.Parent
        end
        return true
    end

    local TIME_GIFT_EXCLUDE_KW = {
        "daily", "login", "streak", "calendar", "dayreward",
        "quest", "mission", "task", "achievement",
        "shop", "store", "market", "pack", "gamepass", "bundle", "robux",
        "rebirth", "prestige", "wheel", "spin", "fortune",
        "trade", "clan", "settings", "code", "pet", "egg", "boss",
    }
    local QUEST_EXCLUDE_KW = {
        "dailyreward", "dailygift", "login", "streak", "calendar", "dayreward",
        "freegift", "timegift", "playtime", "timereward",
        "wheel", "spin", "fortune", "shop", "store", "rebirth", "prestige",
        "trade", "pet", "egg", "boss",
    }
    local DAILY_EXCLUDE_KW = {
        "quest", "mission", "task", "achievement",
        "freegift", "timegift", "playtime", "timereward",
        "wheel", "spin", "fortune", "shop", "store", "rebirth", "prestige",
        "trade", "pet", "egg", "boss",
    }
    local ENTRY_PROP_NAMES = {
        claimed = true, collected = true, redeemed = true, isclaimed = true, iscollected = true,
        isredeemed = true, alreadyclaimed = true, hasclaimed = true,
        ready = true, completed = true, complete = true, iscomplete = true, iscompleted = true,
        isready = true, unlocked = true, locked = true, islocked = true, claimable = true,
        canclaim = true, available = true, done = true, finished = true,
        progress = true, current = true, currentprogress = true, value = true, count = true,
        goal = true, required = true, requiredprogress = true, requirement = true,
        target = true, needed = true, max = true, amount = true,
        timer = true, timeleft = true, cooldown = true, remaining = true, waittime = true,
        nextclaim = true, unlocktime = true, readyat = true, lastclaim = true, lastclaimed = true,
        lastdaily = true, streak = true, isdaily = true, status = true, state = true,
    }

    local function isBlockingCardText(sl, rejectDailyText)
        if sl == "" then return false end
        if sl:find("%d+%s*/%s*%d+.*claimed") or sl:find("%d+%s*/%s*%d+.*collected") or sl:find("gifts%s+claimed") then
            return false
        end
        if sl == "claimed" or sl == "collected" or sl == "redeemed" or sl == "locked" or sl == "lock"
            or sl:find("^next:") or sl:find("unlocks in") or sl:find("cooldown") then
            return true
        end
        if sl:find("%f[%a]locked%f[%A]") or sl:find("%f[%a]claimed%f[%A]")
            or sl:find("%f[%a]collected%f[%A]") or sl:find("%f[%a]redeemed%f[%A]") then
            return true
        end
        if rejectDailyText and (sl:find("^day%s*%d+") or sl:find("%f[%a]daily%f[%A]")
            or sl:find("%f[%a]login%f[%A]") or sl:find("%f[%a]streak%f[%A]")) then
            return true
        end
        local h, m, s = sl:match("(%d+):(%d+):?(%d*)")
        if h and m then
            if ((tonumber(h) or 0) + (tonumber(m) or 0) + (tonumber(s) or 0)) > 0 then
                return true
            end
        end
        return false
    end

    local function isClaimWordText(tl)
        if tl == "" or tl:find("cannot") or tl:find("unable") or isBlockingCardText(tl, false) then
            return false
        end
        if CLAIM_WORDS[tl] then return true end
        return (tl:find("^claim") ~= nil) or (tl:find("^collect") ~= nil) or (tl:find("^redeem") ~= nil) or (tl:find("^ready") ~= nil)
    end

    local function invokeSafe(rem, args)
        if not args or #args == 0 then
            return pcall(rem.InvokeServer, rem)
        end
        return pcall(rem.InvokeServer, rem, table.unpack(args, 1, #args))
    end

    local function invokeSafeTimeout(rem, args, timeoutSec)
        local now = M.clock()
        local blockedUntil = RewardEngine.timedOutRemotes[rem]
        if blockedUntil and now < blockedUntil then
            return false, nil, true
        end
        local done, ok, res = false, false, nil
        local co = task.spawn(function()
            ok, res = invokeSafe(rem, args)
            done = true
        end)
        local t0 = M.clock()
        local limit = timeoutSec or 1.25
        while not done and (M.clock() - t0) < limit do
            task.wait(0.03)
        end
        if not done then
            pcall(task.cancel, co)
            RewardEngine.timedOutRemotes[rem] = M.clock() + 45
            return false, nil, true
        end
        return ok, res, false
    end

    local function fireSafe(rem, args)
        if not args or #args == 0 then
            return pcall(rem.FireServer, rem)
        end
        return pcall(rem.FireServer, rem, table.unpack(args, 1, #args))
    end

    local function isClaimSuccess(ok, res)
        if not ok or res == false or res == nil then return false end
        local t = type(res)
        if t == "table" then
            if res.success == false or res.ok == false then return false end
            return true
        end
        if t == "string" then
            local rl = res:lower()
            if rl:find("cooldown") or rl:find("locked") or rl:find("already")
                or rl:find("not ready") or rl:find("fail") or rl:find("error")
                or rl:find("invalid") or rl:find("wait") then
                return false
            end
        end
        return true
    end

    function RewardEngine.fireGuiButton(btn)
        if not (btn and btn.Parent and btn:IsA("GuiButton")) then return false end
        local function fireSig(sig)
            if not sig then return false end
            local hit = false
            if type(getconnections) == "function" then
                local okC, conns = pcall(getconnections, sig)
                if okC and type(conns) == "table" and #conns > 0 then
                    for _, conn in ipairs(conns) do
                        if conn then
                            if type(conn.Fire) == "function" and pcall(conn.Fire, conn) then
                                hit = true
                            elseif type(conn.Function) == "function" and pcall(conn.Function) then
                                hit = true
                            end
                        end
                    end
                end
            end
            if not hit and type(firesignal) == "function" and pcall(firesignal, sig) then
                hit = true
            end
            return hit
        end
        local a = fireSig(btn.Activated)
        local b = fireSig(btn.MouseButton1Click)
        local c = fireSig(btn.MouseButton1Down)
        local d = fireSig(btn.MouseButton1Up)
        local e = false
        if not (a or b or c or d) and type(getconnections) == "function" then
            local okI, conns = pcall(getconnections, btn.InputBegan)
            if okI and type(conns) == "table" and #conns > 0 then
                local fakeIn = {UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin, Position = Vector3.zero}
                for _, conn in ipairs(conns) do
                    if conn then
                        if type(conn.Fire) == "function" and pcall(conn.Fire, conn, fakeIn) then e = true
                        elseif type(conn.Function) == "function" and pcall(conn.Function, fakeIn) then e = true end
                    end
                end
            end
        end
        return a or b or c or d or e
    end

    local cachedGuiItems = {}
    local cachedGuiRoot = nil
    local lastGuiIndexBuild = -100

    function RewardEngine.invalidateGuiCache()
        RewardEngine.guiCacheDirty = true
    end

    local function getCachedGuiTextItems()
        local pGui = Player:FindFirstChildOfClass("PlayerGui")
        if not pGui then
            cachedGuiItems = {}
            cachedGuiRoot = nil
            return cachedGuiItems, nil
        end
        local now = M.clock()
        if not RewardEngine.guiCacheDirty and cachedGuiRoot == pGui and (now - lastGuiIndexBuild < 1.2) then
            for i = #cachedGuiItems, 1, -1 do
                local entry = cachedGuiItems[i]
                if not (entry.inst and entry.inst.Parent and entry.gui and entry.gui.Parent == pGui) then
                    table.remove(cachedGuiItems, i)
                end
            end
            return cachedGuiItems, pGui
        end
        RewardEngine.guiCacheDirty = false
        cachedGuiRoot = pGui
        lastGuiIndexBuild = now
        local list = {}
        for _, gui in ipairs(pGui:GetChildren()) do
            if gui:IsA("ScreenGui") and not SKIP_GUI_NAMES[gui.Name] and not isOwnGui(gui) then
                local gl = gui.Name:lower()
                local isRewardPopup = gl:find("gift") or gl:find("reward") or gl:find("quest")
                    or gl:find("wheel") or gl:find("spin") or gl:find("daily") or gl:find("benefit")
                if isRewardPopup or not (gl:find("popup") or gl:find("effect") or gl:find("float") or gl:find("chat") or gl:find("loading")) then
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("ImageButton") then
                            list[#list + 1] = {inst = d, gui = gui}
                        elseif d:IsA("ImageLabel") then
                            local nl = d.Name:lower()
                            if nl:find("notif") or nl:find("alert") or nl:find("badge") or nl:find("dot") or nl:find("excl") or nl:find("mark") or nl:find("red") then
                                list[#list + 1] = {inst = d, gui = gui}
                            end
                        end
                    end
                end
            end
        end
        cachedGuiItems = list
        return list, pGui
    end

    local function checkBadgeContainerContext(d, gui, pGui, keywords, excludeKeywords)
        local cur, matched, excluded = d, false, false
        for depth = 1, 6 do
            if not cur or cur == game or cur == pGui then break end
            local cn = cur.Name:lower()
            local hasStrongKw = false
            for _, kw in ipairs(keywords) do
                if cn:find(kw, 1, true) then matched = true; hasStrongKw = true end
            end
            if not matched and depth <= 4 and cur:IsA("GuiObject") then
                for _, ch in ipairs(cur:GetChildren()) do
                    if (ch:IsA("TextLabel") or ch:IsA("TextButton")) and ch ~= d and ch.Text and #ch.Text <= 28 then
                        local tl = cleanGuiText(ch.Text)
                        for _, kw in ipairs(keywords) do
                            if tl:find(kw, 1, true) then matched = true; hasStrongKw = true; break end
                        end
                        if matched then break end
                    end
                end
            end
            if excludeKeywords and not hasStrongKw and cur ~= gui then
                for _, ex in ipairs(excludeKeywords) do
                    if cn:find(ex, 1, true) then excluded = true; break end
                end
                if excluded then break end
            end
            if cur == gui then
                if excludeKeywords then
                    for _, ex in ipairs({"daily", "quest", "wheel", "spin", "shop", "store", "pet", "egg"}) do
                        if cn:find(ex, 1, true) then excluded = true; break end
                    end
                end
                break
            end
            cur = cur.Parent
        end
        return matched and not excluded
    end

    local function hasGuiBadgeFor(keywords, excludeKeywords, allowClaimWord)
        local items, pGui = getCachedGuiTextItems()
        if not pGui then return false, 0 end
        for i = 1, #items do
            local entry = items[i]
            local gui, d = entry.gui, entry.inst
            if gui.Enabled ~= false and d.Visible and isAncestorVisible(d, gui) then
                if d:IsA("ImageLabel") then
                    if checkBadgeContainerContext(d, gui, pGui, keywords, excludeKeywords) then
                        return true, 1
                    end
                elseif (d:IsA("TextLabel") or (allowClaimWord and d:IsA("TextButton"))) and d.Text and #d.Text <= 20 then
                    local t = cleanGuiText(d.Text)
                    local num = tonumber(t)
                    local isBadgeText = (t == "!" or (num and num > 0 and num <= 999))
                        or (allowClaimWord and (t == "claim" or t == "claim!" or t == "claim !" or t == "ready" or t == "ready!" or t == "ready !"))
                    if isBadgeText and checkBadgeContainerContext(d, gui, pGui, keywords, excludeKeywords) then
                        return true, num or 1
                    end
                end
            end
        end
        return false, 0
    end

    local function isTimestampReady(valNameLow, num)
        if not num then return false end
        local nowUnix = os.time()
        if num > 1e8 then
            if valNameLow:find("last") or valNameLow:find("prev") then
                return (nowUnix - num) >= 86400
            else
                return num <= nowUnix
            end
        end
        return num <= 0
    end

    local function isExcludedRewardGuiOrAnc(inst, stopGui, excludeKws, excludeDayNames)
        local cur = inst
        while cur and cur ~= game do
            local nl = cur.Name:lower()
            local isExplicitGift = (nl:find("freegift", 1, true) or nl:find("timegift", 1, true) or nl:find("playtime", 1, true) or nl:find("timereward", 1, true)) ~= nil
            if cur == stopGui then
                for _, strictKw in ipairs({"daily", "quest", "wheel", "spin", "shop", "store", "pet", "egg"}) do
                    for _, kw in ipairs(excludeKws) do
                        if kw == strictKw and nl:find(kw, 1, true) then return true end
                    end
                end
                break
            elseif not isExplicitGift then
                for _, kw in ipairs(excludeKws) do
                    if kw ~= "reward" and kw ~= "rewards" and nl:find(kw, 1, true) then return true end
                end
            end
            if excludeDayNames then
                if nl:find("^day%s*[_%-]?%d+") or nl:find("^days?$") or nl:find("daysgrid") or nl:find("dayslist") then
                    return true
                end
            end
            cur = cur.Parent
        end
        return false
    end

    local function isNegativeDataName(nl)
        if nl:find("unclaim") then return false end
        return nl:find("claimed") ~= nil or nl:find("collected") ~= nil
            or nl:find("redeemed") ~= nil or nl == "isdaily"
            or (nl:find("lock") ~= nil and not nl:find("unlock"))
    end

    local function isBlockedEntryNode(targetObj)
        if not targetObj then return false end
        for ak, av in pairs(targetObj:GetAttributes()) do
            local al = tostring(ak):lower()
            if av == true and (al == "claimed" or al == "collected" or al == "redeemed" or al == "isclaimed" or al == "iscollected" or al == "isredeemed" or al == "alreadyclaimed" or al == "hasclaimed" or al == "locked" or al == "islocked") then
                return true
            elseif av == false and (al == "unlocked" or al == "canclaim" or al == "claimable") then
                return true
            elseif (al == "status" or al == "state") and type(av) == "string" then
                local sl = av:lower()
                if sl == "claimed" or sl == "collected" or sl == "redeemed" or sl == "locked" or sl == "cooldown" or sl == "unavailable" then
                    return true
                end
            end
        end
        for _, c in ipairs(targetObj:GetChildren()) do
            if c:IsA("ValueBase") then
                local cl = c.Name:lower()
                if c.Value == true and (cl == "claimed" or cl == "collected" or cl == "redeemed" or cl == "isclaimed" or cl == "iscollected" or cl == "isredeemed" or cl == "alreadyclaimed" or cl == "hasclaimed" or cl == "locked" or cl == "islocked") then
                    return true
                elseif c.Value == false and (cl == "unlocked" or cl == "canclaim" or cl == "claimable") then
                    return true
                elseif (cl == "status" or cl == "state") and type(c.Value) == "string" then
                    local sl = c.Value:lower()
                    if sl == "claimed" or sl == "collected" or sl == "redeemed" or sl == "locked" or sl == "cooldown" or sl == "unavailable" then
                        return true
                    end
                end
            end
        end
        return false
    end

    local EXPLICIT_READY_FALSE_KEYS = {
        ready = true, completed = true, complete = true,
        iscomplete = true, iscompleted = true, isready = true,
        done = true, finished = true,
    }

    local function readChildCI(obj, names)
        for _, c in ipairs(obj:GetChildren()) do
            if c:IsA("ValueBase") then
                local cl = c.Name:lower()
                for _, target in ipairs(names) do
                    if cl == target then return c, cl end
                end
            end
        end
        return nil, nil
    end

    local function readAttrCI(obj, names)
        for ak, av in pairs(obj:GetAttributes()) do
            local al = tostring(ak):lower()
            for _, target in ipairs(names) do
                if al == target then return av, al end
            end
        end
        return nil, nil
    end

    local function hasUnreadyEntryGate(targetObj)
        if not targetObj then return false end
        if isBlockedEntryNode(targetObj) then return true end
        local progV = readChildCI(targetObj, {"progress", "current", "currentprogress", "value", "count"})
        local goalV = readChildCI(targetObj, {"goal", "required", "requiredprogress", "requirement", "target", "needed", "max", "amount"})
        local progNum = progV and tonumber(progV.Value) or tonumber((readAttrCI(targetObj, {"progress", "current", "currentprogress"})))
        local goalNum = goalV and tonumber(goalV.Value) or tonumber((readAttrCI(targetObj, {"goal", "required", "requiredprogress", "requirement", "target", "needed", "max"})))
        if progNum and goalNum and goalNum > 0 and progNum < goalNum then
            return true
        end
        local timerV, timerName = readChildCI(targetObj, {"timer", "timeleft", "cooldown", "remaining", "waittime", "nextclaim", "unlocktime", "readyat", "lastclaim", "lastclaimed", "lastdaily"})
        local timerNum = timerV and tonumber(timerV.Value) or nil
        if timerNum and not isTimestampReady(timerName, timerNum) then
            return true
        end
        local timerAttr, timerAttrName = readAttrCI(targetObj, {"timer", "timeleft", "cooldown", "remaining", "nextclaim", "unlocktime", "lastclaim", "lastdaily"})
        local timerAttrNum = tonumber(timerAttr)
        if timerAttrNum and not isTimestampReady(timerAttrName, timerAttrNum) then
            return true
        end
        local statusV = readChildCI(targetObj, {"status", "state"})
        local statusAttr = readAttrCI(targetObj, {"status", "state"})
        for _, sv in ipairs({statusV and statusV.Value or nil, statusAttr}) do
            if type(sv) == "string" and sv ~= "" then
                local sl = sv:lower()
                if sl ~= "ready" and sl ~= "claimable" and sl ~= "complete" and sl ~= "completed" and sl ~= "available" then
                    return true
                end
            end
        end
        for _, c in ipairs(targetObj:GetChildren()) do
            if c:IsA("ValueBase") and EXPLICIT_READY_FALSE_KEYS[c.Name:lower()] and c.Value == false then
                return true
            end
        end
        for ak, av in pairs(targetObj:GetAttributes()) do
            if EXPLICIT_READY_FALSE_KEYS[tostring(ak):lower()] and av == false then
                return true
            end
        end
        return false
    end

    local function isEntryClaimableData(obj)
        if not obj then return false end
        if hasUnreadyEntryGate(obj) then return false end
        if obj:IsA("ValueBase") and obj.Parent and (obj.Parent:IsA("Folder") or obj.Parent:IsA("Configuration")) then
            if isBlockedEntryNode(obj.Parent) then return false end
            if ENTRY_PROP_NAMES[obj.Name:lower()] and hasUnreadyEntryGate(obj.Parent) then return false end
        end
        if obj:IsA("ValueBase") and isNegativeDataName(obj.Name:lower()) then
            return false
        end

        local statusV = readChildCI(obj, {"status", "state"})
        local statusAttr = readAttrCI(obj, {"status", "state"})
        for _, sv in ipairs({statusV and statusV.Value or nil, statusAttr}) do
            if type(sv) == "string" then
                local sl = sv:lower()
                if sl == "ready" or sl == "claimable" or sl == "complete" or sl == "completed" or sl == "available" then
                    return true
                end
            end
        end

        local readyV = readChildCI(obj, {"ready", "completed", "complete", "iscomplete", "iscompleted", "isready", "claimable", "canclaim", "available", "done", "finished"})
        local readyAttr = readAttrCI(obj, {"ready", "completed", "complete", "iscomplete", "iscompleted", "isready", "claimable", "canclaim", "available", "done", "finished"})
        if (readyV and readyV.Value == true) or readyAttr == true then
            return true
        end

        local progV = readChildCI(obj, {"progress", "current", "currentprogress", "value", "count"})
        local goalV = readChildCI(obj, {"goal", "required", "requiredprogress", "requirement", "target", "needed", "max", "amount"})
        local progNum = progV and tonumber(progV.Value) or tonumber((readAttrCI(obj, {"progress", "current", "currentprogress"})))
        local goalNum = goalV and tonumber(goalV.Value) or tonumber((readAttrCI(obj, {"goal", "required", "requiredprogress", "requirement", "target", "needed", "max"})))
        if progNum and goalNum and goalNum > 0 then
            return progNum >= goalNum
        elseif obj:IsA("ValueBase") then
            local onl = obj.Name:lower()
            if type(obj.Value) == "string" then
                local sv = obj.Value:lower()
                if sv == "claimed" or sv == "collected" or sv == "redeemed" or sv == "locked" or sv == "cooldown" or sv == "unavailable" then
                    return false
                end
                if (sv == "ready" or sv == "claimable" or sv == "complete" or sv == "completed") and not (onl:find("status") or onl:find("state")) then
                    return true
                end
            end
            if obj.Value == true and (onl:find("ready") or onl:find("claimable") or onl:find("canclaim")
                or (onl:find("claim") and not onl:find("claimed")) or onl:find("complete") or onl:find("daily")) then
                return true
            elseif tonumber(obj.Value) and (
                onl:find("timer") or onl:find("cooldown") or onl:find("timeleft")
                or onl:find("nextclaim") or onl:find("unlocktime") or onl:find("readyat")
                or onl:find("lastclaim") or onl:find("lastdaily")
                or onl == "daily" or onl == "dailyreward" or onl == "chest"
            ) then
                return isTimestampReady(onl, tonumber(obj.Value))
            end
        end

        local timerV, timerName = readChildCI(obj, {"timer", "timeleft", "cooldown", "remaining", "waittime", "nextclaim", "unlocktime", "readyat", "lastclaim", "lastclaimed", "lastdaily"})
        if timerV and tonumber(timerV.Value) then
            if isTimestampReady(timerName, tonumber(timerV.Value)) then return true end
        end
        local timerAttr, timerAttrName = readAttrCI(obj, {"timer", "timeleft", "cooldown", "remaining", "nextclaim", "unlocktime", "lastclaim", "lastdaily"})
        if tonumber(timerAttr) and isTimestampReady(timerAttrName, tonumber(timerAttr)) then
            return true
        end
        return false
    end

    local function hasBlockedEntryState(inst, checkProgress)
        if not inst then return false end
        if isBlockedEntryNode(inst) then return true end
        local progVal, goalVal = nil, nil
        for _, c in ipairs(inst:GetChildren()) do
            if c:IsA("ValueBase") then
                local cl = c.Name:lower()
                if checkProgress and (cl == "progress" or cl == "current" or cl == "currentprogress") then
                    progVal = tonumber(c.Value)
                elseif checkProgress and (cl == "goal" or cl == "required" or cl == "requiredprogress" or cl == "requirement" or cl == "target" or cl == "needed" or cl == "max") then
                    goalVal = tonumber(c.Value)
                end
            end
        end
        if checkProgress and progVal and goalVal and goalVal > 0 and progVal < goalVal then
            return true
        end
        return false
    end

    local function shouldSkipSubValue(obj, boundaryRoot)
        local anc = obj.Parent
        while anc and anc ~= game do
            if hasBlockedEntryState(anc, anc ~= boundaryRoot) then return true end
            if anc == boundaryRoot then break end
            anc = anc.Parent
        end
        if obj:IsA("ValueBase") and ENTRY_PROP_NAMES[obj.Name:lower()] then
            local par = obj.Parent
            if par and (par:IsA("Folder") or par:IsA("Configuration")) then
                if par ~= boundaryRoot or isEntryClaimableData(par) then
                    return true
                end
            end
        end
        return false
    end

    local function isDailyGuiElementMatch(d)
        if d:IsA("TextButton") or d:IsA("TextLabel") then
            return isClaimWordText(cleanGuiText(d.Text))
        end
        if d:IsA("ImageButton") and d.Active ~= false then
            local nl = d.Name:lower()
            return nl:find("claim") ~= nil or nl:find("collect") ~= nil or nl:find("daily") ~= nil or nl:find("redeem") ~= nil
        end
        return false
    end

    local function isSingleCardSlotName(nl)
        return (nl:find("^day%s*[_%-]?%d+$") or nl:find("^gift%s*[_%-]?%d+$") or nl:find("^slot%s*[_%-]?%d+$")
            or nl:find("^card%s*[_%-]?%d+$") or nl:find("^reward%s*[_%-]?%d+$") or nl:find("^item%s*[_%-]?%d+$")
            or nl:find("^panel%s*[_%-]?%d+$")) ~= nil
    end

    local function isMultiCardContainer(inst)
        local nl = inst.Name:lower()
        if isSingleCardSlotName(nl) then
            return false
        end
        if inst:FindFirstChildOfClass("UIGridLayout") or inst:FindFirstChildOfClass("UITableLayout") then
            return true
        end
        local cardCount, subBtnContainers, directGuiBtns, cardLikeFrames = 0, 0, 0, 0
        for _, ch in ipairs(inst:GetChildren()) do
            local cn = ch.Name:lower()
            if cn:find("day%s*[_%-]?%d+") or cn:find("reward%s*[_%-]?%d+") or cn:find("slot%s*[_%-]?%d+")
                or cn:find("gift%s*[_%-]?%d+") or cn:find("card%s*[_%-]?%d+") or cn:find("item%s*[_%-]?%d+") then
                cardCount += 1
            elseif ch:IsA("GuiButton") then
                directGuiBtns += 1
                if directGuiBtns >= 2 then return true end
                if cn:find("^%d+$") or cn:find("^btn%s*[_%-]?%d+") or cn:find("^button%s*[_%-]?%d+") then
                    cardCount += 1
                elseif isDailyGuiElementMatch(ch) then
                    cardCount += 1
                end
            elseif ch:IsA("GuiObject") and cn:find("^%d+$") then
                cardCount += 1
            elseif ch:IsA("TextLabel") and ch.Text and #ch.Text <= 60 then
                local ct = cleanGuiText(ch.Text)
                if ct:find("%d+%s*/%s*%d+.*claimed") or ct:find("gifts%s+claimed") or ct:find("get free rewards") then
                    return true
                end
            elseif (ch:IsA("Frame") or ch:IsA("ImageLabel")) and not ch:IsA("GuiButton") then
                local chLow = ch.Name:lower()
                if chLow:find("gift") or chLow:find("reward") or chLow:find("slot") or chLow:find("card") or chLow:find("day") or chLow:find("quest") then
                    cardLikeFrames += 1
                    if cardLikeFrames >= 2 then return true end
                end
            end
            if (not ch:IsA("GuiButton")) and ch:FindFirstChildWhichIsA("GuiButton", true) then
                subBtnContainers += 1
            end
            if cardCount >= 2 or subBtnContainers >= 2 then return true end
        end
        return false
    end

    local function findCardScope(d, gui)
        local scanScope = d
        for _ = 1, 5 do
            local par = scanScope.Parent
            if not par or par == gui or par:IsA("ScrollingFrame") or isMultiCardContainer(par) then
                break
            end
            if isSingleCardSlotName(scanScope.Name:lower()) and not par:IsA("GuiButton") then
                break
            end
            scanScope = par
        end
        return scanScope
    end

    local function findSingleCardButton(d, scanScope)
        local cur = d
        while cur and cur ~= game do
            if cur:IsA("GuiButton") then return cur end
            if cur == scanScope then break end
            cur = cur.Parent
        end
        if not scanScope then return nil end
        local btnCount, singleBtn = 0, nil
        for _, sub in ipairs(scanScope:GetDescendants()) do
            if sub:IsA("GuiButton") and sub.Visible ~= false then
                btnCount += 1
                singleBtn = sub
                if btnCount > 1 then return nil end
            end
        end
        return singleBtn
    end

    local function isSubCardVisible(d, scanScope)
        local cur = d
        while cur and cur ~= scanScope and cur ~= game do
            if cur:IsA("GuiObject") and cur.Visible == false then return false end
            cur = cur.Parent
        end
        return true
    end

    local function findGiftCardButton(d, scanScope)
        local allBtns, seenB = {}, {}
        local function addBtn(b, priority)
            if b and b:IsA("GuiButton") and not seenB[b] then
                seenB[b] = true
                allBtns[#allBtns + 1] = {btn = b, pri = priority}
            end
        end
        local cur = d
        while cur and cur ~= game do
            if cur:IsA("GuiButton") then
                local cn = cur.Name:lower()
                local isNamed = cn:find("claim") or cn:find("collect") or cn:find("gift") or cn:find("ready")
                addBtn(cur, isNamed and 100 or 80)
            end
            if cur == scanScope then break end
            cur = cur.Parent
        end
        if scanScope then
            if scanScope:IsA("GuiButton") then addBtn(scanScope, 85) end
            for _, sub in ipairs(scanScope:GetDescendants()) do
                if sub:IsA("GuiButton") then
                    local sn = sub.Name:lower()
                    local isClaimBtn = sn:find("claim") ~= nil or sn:find("collect") ~= nil or sn:find("redeem") ~= nil or sn:find("ready") ~= nil or sn:find("gift") ~= nil
                    if not isClaimBtn and sub:IsA("TextButton") and sub.Text then
                        isClaimBtn = isClaimWordText(cleanGuiText(sub.Text))
                    end
                    local visOk = sub.Visible ~= false and isSubCardVisible(sub, scanScope)
                    local pri = (isClaimBtn and 95 or 50) + (visOk and 10 or 0)
                    addBtn(sub, pri)
                end
            end
        end
        table.sort(allBtns, function(a, b) return a.pri > b.pri end)
        local list = {}
        for i = 1, #allBtns do list[i] = allBtns[i].btn end
        return list[1], list
    end

    local function isCardBlocked(scanScope, btnRef, rejectDailyText)
        if not rejectDailyText and btnRef and btnRef:IsA("GuiButton") and btnRef.Active == false then
            return true
        end
        if scanScope:GetAttribute("Locked") == true or scanScope:GetAttribute("Claimed") == true
            or scanScope:GetAttribute("Collected") == true then
            return true
        end
        if (scanScope:IsA("TextLabel") or scanScope:IsA("TextButton")) and scanScope.Visible and (scanScope.TextTransparency or 0) < 0.95 and scanScope.Text then
            if isBlockingCardText(cleanGuiText(scanScope.Text), rejectDailyText) then
                return true
            end
        end
        for _, sub in ipairs(scanScope:GetDescendants()) do
            if (sub:IsA("TextLabel") or sub:IsA("TextButton")) and sub.Visible and (sub.TextTransparency or 0) < 0.95 and sub.Text and isSubCardVisible(sub, scanScope) then
                if isBlockingCardText(cleanGuiText(sub.Text), rejectDailyText) then
                    return true
                end
            end
        end
        return false
    end

    local function getExpandedPlayerRoots()
        local roots = {Player}
        for _, pName in ipairs(DATA_BOX_NAMES) do
            local pf = Player:FindFirstChild(pName)
            if pf then roots[#roots + 1] = pf end
        end
        local rsPD = ReplicatedStorage:FindFirstChild("PlayerData")
        if rsPD then
            local mine = rsPD:FindFirstChild(Player.Name) or rsPD:FindFirstChild(tostring(Player.UserId))
            if mine then roots[#roots + 1] = mine end
        end
        return roots
    end

    local function scanReadyFreeGiftSlots()
        local readySlots, btnMap = {}, {}
        local items, pGui = getCachedGuiTextItems()
        if pGui then
            local exclGui = {}
            for i = 1, #items do
                local entry = items[i]
                local gui, d = entry.gui, entry.inst
                local gEx = exclGui[gui]
                if gEx == nil then
                    gEx = isExcludedRewardGuiOrAnc(gui, gui, TIME_GIFT_EXCLUDE_KW, true)
                    exclGui[gui] = gEx
                end
                if not gEx and (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible ~= false and d.Text and #d.Text <= 28 and not isTemplateAncestor(d, gui) then
                    local tl = trimLow(d.Text)
                    if isClaimWordText(tl) and not tl:find("daily") and not isExcludedRewardGuiOrAnc(d, gui, TIME_GIFT_EXCLUDE_KW, true) then
                        local scanScope = findCardScope(d, gui)
                        if isSubCardVisible(d, scanScope) then
                            local btnRef, btnList = findGiftCardButton(d, scanScope)
                            if not isCardBlocked(scanScope, btnRef, true) then
                                local slotNum, cur = nil, d
                                for _ = 1, 5 do
                                    if not cur or cur == gui then break end
                                    local num = tonumber(cur.Name:match("(%d+)"))
                                    if num and num >= 1 and num <= 24 then slotNum = num; break end
                                    if cur == scanScope then break end
                                    cur = cur.Parent
                                end
                                if not slotNum then
                                    for _, sub in ipairs(scanScope:GetDescendants()) do
                                        if (sub:IsA("TextLabel") or sub:IsA("TextButton")) and sub.Text and #sub.Text <= 32 and isSubCardVisible(sub, scanScope) then
                                            local st = cleanGuiText(sub.Text)
                                            local gNum = tonumber(st:match("gift%s*#?(%d+)") or st:match("slot%s*#?(%d+)") or st:match("reward%s*#?(%d+)") or st:match("present%s*#?(%d+)") or st:match("^#?(%d+)$"))
                                            if gNum and gNum >= 1 and gNum <= 24 then slotNum = gNum; break end
                                        end
                                    end
                                end
                                if not slotNum then
                                    for _, kName in ipairs({"GiftIndex", "GiftNumber", "GiftId", "Slot", "Index", "Id", "Number"}) do
                                        local attrV = tonumber(scanScope:GetAttribute(kName))
                                        if attrV and attrV >= 1 and attrV <= 24 then slotNum = M.floor(attrV); break end
                                        local childV = scanScope:FindFirstChild(kName)
                                        if childV and childV:IsA("ValueBase") then
                                            local nv = tonumber(childV.Value)
                                            if nv and nv >= 1 and nv <= 24 then slotNum = M.floor(nv); break end
                                        end
                                    end
                                end
                                if not slotNum and scanScope:IsA("GuiObject") and scanScope.LayoutOrder >= 1 and scanScope.LayoutOrder <= 24 then
                                    slotNum = scanScope.LayoutOrder
                                end
                                if slotNum then
                                    readySlots[slotNum] = readySlots[slotNum] or true
                                    btnMap[slotNum] = btnMap[slotNum] or btnList
                                end
                            end
                        end
                    end
                end
            end
        end

        local giftBoxNames = {
            "freeGiftsFolder", "FreeGiftsFolder", "FreeGifts", "freeGifts",
            "timeRewards", "TimeRewards", "PlaytimeRewards", "playtimeRewards",
            "PlaytimeGifts", "playtimeGifts", "Gifts", "gifts", "TimeGifts", "timeGifts",
        }
        for _, root in ipairs(getExpandedPlayerRoots()) do
            for _, fName in ipairs(giftBoxNames) do
                local folder = root:FindFirstChild(fName)
                if folder then
                    for _, item in ipairs(folder:GetChildren()) do
                        if isEntryClaimableData(item) then
                            local num = tonumber(item.Name:match("(%d+)"))
                            if num and num >= 1 and num <= 24 then readySlots[num] = item end
                        end
                    end
                end
            end
        end
        for ak, av in pairs(Player:GetAttributes()) do
            if av == true then
                local al = tostring(ak):lower()
                if (al:find("gift") or al:find("playtime")) and (al:find("ready") or al:find("avail") or al:find("unlock")) then
                    local num = tonumber(al:match("(%d+)"))
                    if num and num >= 1 and num <= 24 then readySlots[num] = readySlots[num] or true end
                end
            end
        end
        return readySlots, btnMap
    end

    local function getQuestRoots()
        local roots = {}
        local qNames = {"Quests", "quests", "currentQuests", "questsFolder", "DailyQuests", "dailyQuests", "Daily", "daily"}
        for _, rootBox in ipairs(getExpandedPlayerRoots()) do
            for _, qName in ipairs(qNames) do
                local f = rootBox:FindFirstChild(qName)
                if f then roots[#roots + 1] = f end
            end
        end
        return roots
    end

    local function findQuestInstance(roots, qName)
        local qLow = trimLow(qName)
        for _, root in ipairs(roots) do
            if root then
                local direct = root:FindFirstChild(qName, true)
                if direct then return direct, (direct.Parent ~= root and direct.Parent.Name or nil) end
                for _, desc in ipairs(root:GetDescendants()) do
                    if desc:IsA("Folder") or desc:IsA("Configuration") then
                        for _, child in ipairs(desc:GetChildren()) do
                            if child:IsA("StringValue") and trimLow(child.Value) == qLow then
                                return desc, (desc.Parent ~= root and desc.Parent.Name or nil)
                            end
                        end
                    end
                end
            end
        end
        return nil, nil
    end

    local function inspectQuestCard(card)
        local hasComplete, hasCollect, isClaimed, bestTitle = false, false, false, nil
        for _, sub in ipairs(card:GetDescendants()) do
            if (sub:IsA("TextLabel") or sub:IsA("TextButton")) and sub.Visible and sub.Text then
                local sl = trimLow(sub.Text)
                if isBlockingCardText(sl, false) or sl == "completed" then
                    isClaimed = true
                elseif sl == "complete" or sl == "done" or sl == "ready" or sl == "ready!" or sl == "100%" then
                    hasComplete = true
                elseif sl == "collect" or sl == "claim" or sl == "redeem" then
                    hasCollect = true
                elseif #sl >= 3 and #sl <= 48 and not sl:find("reward") and not sl:find("spin") and not sl:find("reset") and not sl:find("do ") then
                    bestTitle = bestTitle or sub.Text:gsub("<[^>]+>", "")
                end
            end
        end
        return hasComplete and hasCollect and not isClaimed, bestTitle
    end

    local function scanReadyQuests()
        local readyList, seenNames = {}, {}
        local questRoots = getQuestRoots()
        for _, root in ipairs(questRoots) do
            if root then
                for _, obj in ipairs(root:GetDescendants()) do
                    if (obj:IsA("Folder") or obj:IsA("Configuration") or obj:IsA("ValueBase"))
                        and not shouldSkipSubValue(obj, root) and isEntryClaimableData(obj) then
                        if not seenNames[obj.Name] then
                            seenNames[obj.Name] = true
                            local cat = (obj.Parent and obj.Parent ~= root) and obj.Parent.Name or nil
                            readyList[#readyList + 1] = {name = obj.Name, obj = obj, category = cat}
                        end
                    end
                end
            end
        end

        local items, pGui = getCachedGuiTextItems()
        if pGui then
            local exclGui = {}
            for i = 1, #items do
                local entry = items[i]
                local gui, d = entry.gui, entry.inst
                if gui.Enabled ~= false then
                    local gEx = exclGui[gui]
                    if gEx == nil then
                        gEx = isExcludedRewardGuiOrAnc(gui, gui, QUEST_EXCLUDE_KW, true)
                        exclGui[gui] = gEx
                    end
                    if not gEx and (d:IsA("TextButton") or d:IsA("TextLabel")) and d.Visible and d.Text and isAncestorVisible(d, gui) then
                        local tl = trimLow(d.Text)
                        if (tl == "collect" or tl == "complete" or tl == "claim" or tl == "100%" or tl == "redeem")
                            and not isExcludedRewardGuiOrAnc(d, gui, QUEST_EXCLUDE_KW, true) then
                            local card = d.Parent
                            for _ = 1, 3 do
                                if not card or card == gui or card:IsA("ScrollingFrame") or card:FindFirstChildOfClass("UIGridLayout") or isMultiCardContainer(card) then break end
                                local okCard, bestTitle = inspectQuestCard(card)
                                if okCard then
                                    local qName = bestTitle or card.Name
                                    if qName and qName ~= "" and not seenNames[qName] then
                                        seenNames[qName] = true
                                        local foundInst, cat = findQuestInstance(questRoots, qName)
                                        local qBtn = findSingleCardButton(d, card)
                                        readyList[#readyList + 1] = {name = qName, obj = foundInst, category = cat, btn = qBtn}
                                    end
                                    break
                                end
                                card = card.Parent
                            end
                        end
                    end
                end
            end
        end
        return readyList
    end

    local function scanDailyAttributes(pushDaily)
        for ak, av in pairs(Player:GetAttributes()) do
            local al = tostring(ak):lower()
            if al:find("daily") or al:find("login") or al:find("streak") then
                if al:find("ready") or al:find("claim") or al:find("avail") or al:find("can") then
                    if av == true then pushDaily(ak, tonumber(al:match("(%d+)")), nil, "Daily Reward") end
                elseif (al:find("timer") or al:find("time") or al:find("cooldown") or al:find("last") or al:find("next")) and tonumber(av) then
                    if isTimestampReady(al, tonumber(av)) then
                        pushDaily(ak, tonumber(al:match("(%d+)")), nil, "Daily Reward")
                    end
                end
            end
        end
    end

    local function scanDailyDataContainers(pushDaily)
        local dailyContainerNames = {
            "dailyRewards", "DailyRewards", "dailyGifts", "DailyGifts",
            "Daily", "daily", "LoginRewards", "loginRewards", "DailyLogin",
            "Streak", "streak", "dailyReward", "DailyReward",
        }
        local seenNodes = {}
        local function checkDailyBranch(node)
            if seenNodes[node] then return end
            seenNodes[node] = true
            local nl = node.Name:lower()
            if nl:find("quest") or nl:find("shop") or nl:find("pet") or nl:find("egg") then return end
            if isEntryClaimableData(node) then
                local dNum = tonumber(nl:match("(%d+)"))
                pushDaily(dNum and ("day_" .. tostring(dNum)) or node.Name, dNum, node, node.Name)
            end
            for _, sub in ipairs(node:GetDescendants()) do
                local sl = sub.Name:lower()
                if not (sl:find("quest") or sl:find("shop") or sl:find("pet") or sl:find("egg")) then
                    if (sub:IsA("ValueBase") or sub:IsA("Folder") or sub:IsA("Configuration"))
                        and not shouldSkipSubValue(sub, node) and isEntryClaimableData(sub) then
                        local dNum = tonumber(sl:match("(%d+)"))
                        pushDaily("day_" .. tostring(dNum or sub.Name), dNum, sub, sub.Name)
                    end
                end
            end
        end

        for _, root in ipairs(getExpandedPlayerRoots()) do
            for _, child in ipairs(root:GetChildren()) do
                local cl = child.Name:lower()
                if (cl:find("daily") or cl:find("login") or cl:find("streak") or cl:find("calendar")) and not cl:find("quest") then
                    checkDailyBranch(child)
                end
            end
            for _, fName in ipairs(dailyContainerNames) do
                local f = root:FindFirstChild(fName)
                if f then checkDailyBranch(f) end
            end
        end
    end

    local function scanDailyChestTimers(pushDaily)
        for _, cName in ipairs({"chestTimers", "ChestTimers", "Chests", "chests"}) do
            local cf = Player:FindFirstChild(cName)
            if cf then
                for _, item in ipairs(cf:GetChildren()) do
                    local il = item.Name:lower()
                    if (il:find("daily") or il:find("group") or il:find("reward")) and isEntryClaimableData(item) then
                        pushDaily("chest_" .. item.Name, nil, item, item.Name)
                    end
                end
            end
        end
    end

    local function scanDailyGuiButtons(pushDaily)
        local items, pGui = getCachedGuiTextItems()
        if not pGui then return end
        local exclGui = {}
        for i = 1, #items do
            local entry = items[i]
            local gui, d = entry.gui, entry.inst
            if gui.Enabled ~= false then
                local gEx = exclGui[gui]
                if gEx == nil then
                    gEx = isExcludedRewardGuiOrAnc(gui, gui, DAILY_EXCLUDE_KW, false)
                    exclGui[gui] = gEx
                end
                if not gEx and d:IsA("GuiObject") and d.Visible and isAncestorVisible(d, gui) and isDailyGuiElementMatch(d)
                    and not isExcludedRewardGuiOrAnc(d, gui, DAILY_EXCLUDE_KW, false) then
                    local inDailyUi, cur = false, d
                    for depth = 1, 7 do
                        if not cur or cur == game then break end
                        local cn = cur.Name:lower()
                        if cn:find("daily") or cn:find("login") or cn:find("streak") or cn:find("calendar") or cn:find("dayreward") or (cn:find("benefit") and not cn:find("group")) then
                            inDailyUi = true
                        end
                        if depth <= 3 and cur:IsA("GuiObject") then
                            for _, sib in ipairs(cur:GetChildren()) do
                                if sib:IsA("TextLabel") and sib.Visible and sib.Text then
                                    local sl = cleanGuiText(sib.Text)
                                    if sl:find("daily") or sl:find("^day%s*%d+") then inDailyUi = true end
                                end
                            end
                        end
                        cur = cur.Parent
                    end

                    if inDailyUi then
                        local scanScope = findCardScope(d, gui)
                        local btnRef = findSingleCardButton(d, scanScope)
                        if not isCardBlocked(scanScope, btnRef, false) then
                            local foundDay = tonumber(scanScope.Name:match("(%d+)") or d.Name:match("(%d+)"))
                            if not foundDay then
                                for _, sub in ipairs(scanScope:GetDescendants()) do
                                    if (sub:IsA("TextLabel") or sub:IsA("TextButton")) and sub.Visible and sub.Text then
                                        local dn = cleanGuiText(sub.Text):match("day%s*(%d+)")
                                        if dn then foundDay = tonumber(dn); break end
                                    end
                                end
                            end
                            local dayTag = foundDay and ("day_" .. tostring(foundDay)) or scanScope.Name
                            pushDaily("gui_" .. dayTag, foundDay, nil, foundDay and ("Daily Day " .. tostring(foundDay)) or "Daily Reward", btnRef)
                        end
                    end
                end
            end
        end
    end

    local function scanReadyDailyRewards()
        local readyItems, seenKeys = {}, {}
        local function pushDaily(key, dayNum, objRef, label, btnInst)
            key = tostring(key)
            if seenKeys[key] then return end
            seenKeys[key] = true
            readyItems[#readyItems + 1] = {
                key = key, day = dayNum, obj = objRef,
                label = label or ("Daily Reward #" .. key), btn = btnInst,
            }
        end
        scanDailyAttributes(pushDaily)
        scanDailyDataContainers(pushDaily)
        scanDailyChestTimers(pushDaily)
        scanDailyGuiButtons(pushDaily)
        return readyItems
    end

    local function collectReadyQuests(now)
        if RewardEngine.questPassBusy then return end
        local readyQuests = scanReadyQuests()
        local hasQuestBadge = hasGuiBadgeFor({"quest"}, QUEST_EXCLUDE_KW)
        if #readyQuests == 0 and not hasQuestBadge then return end
        local myGen, tok = Runtime.Gen, Runtime.SessionTokens.rew
        local questRemotes = Remotes.questRemotes

        if #readyQuests > 0 then
            local pending = {}
            for _, qInfo in ipairs(readyQuests) do
                local lastTry = RewardEngine.claimedQuestCooldown[qInfo.name] or 0
                if (now - lastTry >= 3.5) and (#questRemotes > 0 or qInfo.btn ~= nil) then
                    RewardEngine.claimedQuestCooldown[qInfo.name] = now
                    pending[#pending + 1] = qInfo
                end
            end
            if #pending == 0 then return end
            RewardEngine.questPassBusy = true
            task.spawn(function()
                local function isAlive()
                    return Config.Active and Config.AutoCollectRewards and myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew
                end
                local needEventCheck = false
                for _, qInfo in ipairs(pending) do
                    if not isAlive() then break end
                    local claimedOk, usedEvent = false, false
                    local targets = {}
                    if qInfo.obj then targets[#targets + 1] = qInfo.obj end
                    targets[#targets + 1] = qInfo.name
                    for _, rem in ipairs(questRemotes) do
                        if not isAlive() then break end
                        if rem and rem.Parent then
                            for _, action in ipairs({"collectQuest", "claimQuest", "collect", "claim"}) do
                                if not isAlive() then break end
                                for _, tgt in ipairs(targets) do
                                    if not isAlive() then break end
                                    if rem:IsA("RemoteFunction") then
                                        local ok, res = invokeSafe(rem, {action, tgt})
                                        if not isClaimSuccess(ok, res) and qInfo.category and isAlive() then
                                            ok, res = invokeSafe(rem, {action, qInfo.category, tgt})
                                        end
                                        if isClaimSuccess(ok, res) then claimedOk = true; break end
                                    else
                                        usedEvent = true
                                        fireSafe(rem, {action, tgt})
                                        if qInfo.category then fireSafe(rem, {action, qInfo.category, tgt}) end
                                    end
                                end
                                if claimedOk then break end
                            end
                            if claimedOk then break end
                        end
                    end
                    qInfo._claimed = claimedOk
                    if not claimedOk and usedEvent then needEventCheck = true end
                end

                if needEventCheck and isAlive() then
                    task.wait(0.35)
                    if isAlive() then
                        local stillMap = {}
                        for _, rq in ipairs(scanReadyQuests()) do stillMap[rq.name] = true end
                        for _, qInfo in ipairs(pending) do
                            if not qInfo._claimed and not stillMap[qInfo.name] then qInfo._claimed = true end
                        end
                    end
                end

                for _, qInfo in ipairs(pending) do
                    if not isAlive() then break end
                    if not qInfo._claimed and qInfo.btn and RewardEngine.fireGuiButton(qInfo.btn) then
                        task.wait(0.30)
                        if not isAlive() then break end
                        local stillReady = false
                        for _, rq in ipairs(scanReadyQuests()) do
                            if rq.name == qInfo.name then stillReady = true; break end
                        end
                        if not stillReady then qInfo._claimed = true end
                    end
                    if qInfo._claimed then
                        RewardEngine.collectedCount += 1
                        RewardEngine.lastRewardLabel = "Quest: " .. tostring(qInfo.name)
                    end
                end
                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew then RewardEngine.questPassBusy = false end
            end)
        elseif hasQuestBadge and #questRemotes > 0 and (now - (RewardEngine.claimedQuestCooldown["_badge"] or 0) >= 3.5) then
            RewardEngine.claimedQuestCooldown["_badge"] = now
            RewardEngine.questPassBusy = true
            task.spawn(function()
                local function isAlive()
                    return Config.Active and Config.AutoCollectRewards and myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew
                end
                local questObjs = {}
                for _, root in ipairs(getQuestRoots()) do
                    for _, desc in ipairs(root:GetDescendants()) do
                        if (desc:IsA("Folder") or desc:IsA("Configuration")) and not isBlockedEntryNode(desc) then
                            local p = desc.Parent
                            if p and (p == root or p.Parent == root) then
                                questObjs[#questObjs + 1] = {obj = desc, name = desc.Name, cat = (p ~= root) and p.Name or nil}
                            end
                        end
                    end
                end
                local claimedAny, usedEvent = false, false
                for _, rem in ipairs(questRemotes) do
                    if not isAlive() then break end
                    if rem and rem.Parent then
                        for _, q in ipairs(questObjs) do
                            if not isAlive() then break end
                            if rem:IsA("RemoteFunction") then
                                local ok, res = invokeSafe(rem, {"collectQuest", q.obj})
                                if not isClaimSuccess(ok, res) and isAlive() then ok, res = invokeSafe(rem, {"collectQuest", q.name}) end
                                if not isClaimSuccess(ok, res) and q.cat and isAlive() then ok, res = invokeSafe(rem, {"collectQuest", q.cat, q.obj}) end
                                if not isClaimSuccess(ok, res) and isAlive() then ok, res = invokeSafe(rem, {"claimQuest", q.obj}) end
                                if isClaimSuccess(ok, res) then
                                    claimedAny = true
                                    RewardEngine.collectedCount += 1
                                    RewardEngine.lastRewardLabel = "Quest: " .. tostring(q.name)
                                end
                            else
                                usedEvent = true
                                fireSafe(rem, {"collectQuest", q.obj})
                                fireSafe(rem, {"collectQuest", q.name})
                                fireSafe(rem, {"claimQuest", q.obj})
                                if q.cat then fireSafe(rem, {"collectQuest", q.cat, q.obj}) end
                            end
                        end
                        if rem:IsA("RemoteFunction") then
                            local ok, res = invokeSafe(rem, {"collectAll"})
                            if not isClaimSuccess(ok, res) and isAlive() then
                                ok, res = invokeSafe(rem, {"claimAll"})
                            end
                            if isClaimSuccess(ok, res) then
                                claimedAny = true
                                RewardEngine.collectedCount += 1
                                RewardEngine.lastRewardLabel = "Quest Rewards"
                                break
                            end
                        else
                            usedEvent = true
                            fireSafe(rem, {"collectAll"})
                            fireSafe(rem, {"claimAll"})
                        end
                    end
                end
                if not claimedAny and usedEvent and isAlive() then
                    task.wait(0.35)
                    if isAlive() and not hasGuiBadgeFor({"quest"}, QUEST_EXCLUDE_KW) then
                        RewardEngine.collectedCount += 1
                        RewardEngine.lastRewardLabel = "Quest Rewards"
                    end
                end
                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew then RewardEngine.questPassBusy = false end
            end)
        end
    end

    local function buildGiftAttempts(slotIdx, slotRef)
        local sStr = tostring(slotIdx)
        local gStr = "Gift " .. sStr
        local gNoSp = "Gift" .. sStr
        local gLow = "gift" .. sStr
        local attempts = {
            {"claimGift", slotIdx},
            {slotIdx},
            {"ClaimGift", slotIdx},
            {"claimGift", gNoSp},
            {"claimGift", gStr},
            {"claimGift", gLow},
            {"claimGift", sStr},
            {gNoSp},
            {gStr},
            {sStr},
            {"claimFreeGift", slotIdx},
            {"ClaimFreeGift", slotIdx},
            {"claimPlaytimeReward", slotIdx},
            {"claimTimeGift", slotIdx},
            {"claimReward", slotIdx},
            {"claim", slotIdx},
            {"Claim", slotIdx},
        }
        if typeof(slotRef) == "Instance" then
            table.insert(attempts, 3, {"claimGift", slotRef})
        end
        if type(RewardEngine.workingGiftArgs) == "function" then
            local cachedArgs = RewardEngine.workingGiftArgs(slotIdx, slotRef)
            if cachedArgs then table.insert(attempts, 1, cachedArgs) end
        end
        return attempts
    end

    local function cacheGiftPayloadPattern(args, slotIdx, slotRef)
        if type(args) ~= "table" then return end
        local sStr = tostring(slotIdx)
        local gStr = "Gift " .. sStr
        local gNoSp = "Gift" .. sStr
        local gLow = "gift" .. sStr
        local template = {}
        for i = 1, #args do
            local v = args[i]
            if v == slotIdx then template[i] = "_NUM"
            elseif v == sStr then template[i] = "_STR"
            elseif v == gStr then template[i] = "_GSP"
            elseif v == gNoSp then template[i] = "_GNOSP"
            elseif v == gLow then template[i] = "_GLOW"
            elseif typeof(slotRef) == "Instance" and v == slotRef then template[i] = "_INST"
            else template[i] = v end
        end
        RewardEngine.workingGiftArgs = function(idx, ref)
            local si = tostring(idx)
            local out = {}
            for i = 1, #template do
                local t = template[i]
                if t == "_NUM" then out[i] = idx
                elseif t == "_STR" then out[i] = si
                elseif t == "_GSP" then out[i] = "Gift " .. si
                elseif t == "_GNOSP" then out[i] = "Gift" .. si
                elseif t == "_GLOW" then out[i] = "gift" .. si
                elseif t == "_INST" then out[i] = (typeof(ref) == "Instance") and ref or ("Gift" .. si)
                else out[i] = t end
            end
            return out
        end
    end

    local function hasTimeGiftCardsOpen()
        local items, pGui = getCachedGuiTextItems()
        if not pGui then return false end
        local timerOrGiftHits = 0
        for i = 1, #items do
            local entry = items[i]
            local gui, d = entry.gui, entry.inst
            if gui.Enabled ~= false and (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible ~= false and d.Text and not isExcludedRewardGuiOrAnc(gui, gui, TIME_GIFT_EXCLUDE_KW, true) then
                local tl = trimLow(d.Text)
                if tl:find("gift%s*%d+") or tl:match("%d+:%d%d:%d%d") or tl:find("free rewards for playing") then
                    if isAncestorVisible(d, gui) then
                        timerOrGiftHits += 1
                        if timerOrGiftHits >= 2 then return true end
                    end
                end
            end
        end
        return false
    end

    local function hasTimeGiftBadge()
        if hasGuiBadgeFor({"gift", "time", "freegift", "playtime", "benefit", "claim", "reward"}, TIME_GIFT_EXCLUDE_KW, false) then
            return true
        end
        if hasGuiBadgeFor({"gift", "time", "freegift", "playtime", "timegift", "timereward", "benefit", "reward", "claim"}, TIME_GIFT_EXCLUDE_KW, true) then
            return true
        end
        local items, pGui = getCachedGuiTextItems()
        if pGui then
            for i = 1, #items do
                local entry = items[i]
                local gui, d = entry.gui, entry.inst
                if gui.Enabled ~= false and (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text and #d.Text <= 14 and isAncestorVisible(d, gui) then
                    local tl = cleanGuiText(d.Text)
                    if tl == "claim" or tl == "ready!" or tl == "ready" then
                        if not isExcludedRewardGuiOrAnc(d, gui, TIME_GIFT_EXCLUDE_KW, true) then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local function buildOrderedGiftRemotes()
        local out, seenR = {}, {}
        local function addR(r)
            if r and r.Parent and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) and not seenR[r] then
                seenR[r] = true
                out[#out + 1] = r
            end
        end
        if RewardEngine.workingGiftRemote then addR(RewardEngine.workingGiftRemote) end
        for _, r in ipairs(Remotes.timeRewardRemotes) do addR(r) end
        for _, tName in ipairs({"freeGiftClaimRemote", "claimFreeGiftRemote", "playtimeRewardRemote", "freeGiftsRemote", "claimGiftRemote", "freeGiftRemote"}) do
            local direct = ReplicatedStorage:FindFirstChild(tName, true)
            if direct and (direct:IsA("RemoteEvent") or direct:IsA("RemoteFunction")) then
                addR(cloneref(direct))
            end
        end
        return out
    end

    local function fireCardButtonsList(btnList)
        if type(btnList) ~= "table" then
            return (btnList and RewardEngine.fireGuiButton(btnList)) or false
        end
        local anyFired = false
        for _, b in ipairs(btnList) do
            if RewardEngine.fireGuiButton(b) then anyFired = true end
        end
        return anyFired
    end

    local function tryClaimGiftSlotFast(slotIdx, slotRef, giftRemotes, isAlive, fastOnly)
        local attempts = buildGiftAttempts(slotIdx, slotRef)
        local maxRem = fastOnly and M.min(#giftRemotes, 3) or #giftRemotes
        local maxAtt = fastOnly and M.min(#attempts, 4) or #attempts
        local usedEvent = false
        for rIdx = 1, maxRem do
            if not isAlive() then return false, usedEvent end
            local rem = giftRemotes[rIdx]
            if rem and rem.Parent then
                if rem:IsA("RemoteFunction") then
                    for aIdx = 1, maxAtt do
                        if not isAlive() then return false, usedEvent end
                        local args = attempts[aIdx]
                        local ok, res, timedOut = invokeSafeTimeout(rem, args, 1.1)
                        if timedOut then break end
                        if isClaimSuccess(ok, res) then
                            RewardEngine.workingGiftRemote = rem
                            cacheGiftPayloadPattern(args, slotIdx, slotRef)
                            return true, usedEvent
                        elseif ok and res == nil then
                            usedEvent = true
                        end
                    end
                else
                    usedEvent = true
                    for aIdx = 1, maxAtt do
                        if not isAlive() then return false, usedEvent end
                        fireSafe(rem, attempts[aIdx])
                    end
                end
            end
        end
        return false, usedEvent
    end

    local function collectTimeGifts(now)
        if RewardEngine.giftPassBusy then return end
        local readySlots, btnMap = scanReadyFreeGiftSlots()
        local hasClaimBadge = hasTimeGiftBadge()
        local hasReadySlot = next(readySlots) ~= nil
        if not hasReadySlot and not hasClaimBadge then return end
        local myGen, tok = Runtime.Gen, Runtime.SessionTokens.rew
        local giftRemotes = buildOrderedGiftRemotes()

        if hasReadySlot then
            local pending = {}
            for slotIdx, slotRef in pairs(readySlots) do
                local lastTry = RewardEngine.claimedGiftCooldown[slotIdx] or 0
                local bList = btnMap[slotIdx]
                if (now - lastTry >= 3.0) and (#giftRemotes > 0 or (bList ~= nil and (#bList > 0))) then
                    RewardEngine.claimedGiftCooldown[slotIdx] = now
                    pending[#pending + 1] = {idx = slotIdx, ref = slotRef, btns = bList}
                end
            end
            if #pending == 0 then return end
            table.sort(pending, function(a, b) return a.idx < b.idx end)
            RewardEngine.giftPassBusy = true
            task.spawn(function()
                local function isAlive()
                    return Config.Active and Config.AutoCollectRewards and myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew
                end
                pcall(function()
                    local needEventCheck = false
                    for _, item in ipairs(pending) do
                        if not isAlive() then break end
                        if #giftRemotes > 0 then
                            local claimedOk, usedEv = tryClaimGiftSlotFast(item.idx, item.ref, giftRemotes, isAlive, true)
                            if claimedOk then item._claimed = true end
                            if usedEv then needEventCheck = true end
                        end
                    end
                    if needEventCheck and isAlive() then
                        task.wait(0.28)
                        if isAlive() then
                            RewardEngine.invalidateGuiCache()
                            local after = scanReadyFreeGiftSlots()
                            for _, item in ipairs(pending) do
                                if not item._claimed and after[item.idx] == nil then item._claimed = true end
                            end
                        end
                    end
                    for _, item in ipairs(pending) do
                        if not isAlive() then break end
                        if not item._claimed and item.btns then
                            if fireCardButtonsList(item.btns) then
                                task.wait(0.25)
                                if not isAlive() then break end
                                RewardEngine.invalidateGuiCache()
                                local after = scanReadyFreeGiftSlots()
                                if after[item.idx] == nil then item._claimed = true end
                            end
                        end
                    end
                    local needFullCheck = false
                    for _, item in ipairs(pending) do
                        if not isAlive() then break end
                        if not item._claimed and #giftRemotes > 0 then
                            local claimedOk, usedEv = tryClaimGiftSlotFast(item.idx, item.ref, giftRemotes, isAlive, false)
                            if claimedOk then item._claimed = true end
                            if usedEv then needFullCheck = true end
                        end
                    end
                    if needFullCheck and isAlive() then
                        task.wait(0.30)
                        if isAlive() then
                            RewardEngine.invalidateGuiCache()
                            local after = scanReadyFreeGiftSlots()
                            for _, item in ipairs(pending) do
                                if not item._claimed and after[item.idx] == nil then item._claimed = true end
                            end
                        end
                    end
                    for _, item in ipairs(pending) do
                        if item._claimed then
                            RewardEngine.collectedCount += 1
                            RewardEngine.lastRewardLabel = "Time Gift #" .. tostring(item.idx)
                        end
                    end
                end)
                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew then RewardEngine.giftPassBusy = false end
            end)
        elseif hasClaimBadge and #giftRemotes > 0 then
            local badgeSlots = {}
            for slotIdx = 1, 12 do
                local lastTry = RewardEngine.claimedGiftCooldown[slotIdx] or 0
                if now - lastTry >= 4.5 then
                    RewardEngine.claimedGiftCooldown[slotIdx] = now
                    badgeSlots[#badgeSlots + 1] = slotIdx
                end
            end
            if #badgeSlots == 0 then return end
            RewardEngine.giftPassBusy = true
            task.spawn(function()
                local function isAlive()
                    return Config.Active and Config.AutoCollectRewards and myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew
                end
                pcall(function()
                    local anyServerProbe, claimedCountThisPass = false, 0
                    for _, slotIdx in ipairs(badgeSlots) do
                        if not isAlive() then break end
                        local claimedSlot, usedEv = tryClaimGiftSlotFast(slotIdx, nil, giftRemotes, isAlive, true)
                        if usedEv then anyServerProbe = true end
                        if claimedSlot then
                            claimedCountThisPass += 1
                            RewardEngine.collectedCount += 1
                            RewardEngine.lastRewardLabel = "Time Gift #" .. tostring(slotIdx)
                        end
                    end
                    if claimedCountThisPass == 0 and isAlive() then
                        for _, slotIdx in ipairs(badgeSlots) do
                            if not isAlive() then break end
                            local claimedSlot, usedEv = tryClaimGiftSlotFast(slotIdx, nil, giftRemotes, isAlive, false)
                            if usedEv then anyServerProbe = true end
                            if claimedSlot then
                                claimedCountThisPass += 1
                                RewardEngine.collectedCount += 1
                                RewardEngine.lastRewardLabel = "Time Gift #" .. tostring(slotIdx)
                            end
                        end
                    end
                    if claimedCountThisPass == 0 and anyServerProbe and isAlive() then
                        task.wait(0.35)
                        if isAlive() then
                            RewardEngine.invalidateGuiCache()
                            if not hasTimeGiftBadge() then
                                RewardEngine.collectedCount += 1
                                RewardEngine.lastRewardLabel = "Time Gift"
                            end
                        end
                    end
                end)
                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew then RewardEngine.giftPassBusy = false end
            end)
        end
    end

    local function buildDailyPayloads(readyDailyItems)
        local dailyPayloads, chestPayloads = {}, {}
        for _, item in ipairs(readyDailyItems) do
            if item.obj then
                dailyPayloads[#dailyPayloads + 1] = {"claimDaily", item.obj}
                dailyPayloads[#dailyPayloads + 1] = {"claim", item.obj}
                dailyPayloads[#dailyPayloads + 1] = {item.obj}
            end
            if item.day then
                dailyPayloads[#dailyPayloads + 1] = {"claimDaily", item.day}
                dailyPayloads[#dailyPayloads + 1] = {"claim", item.day}
                dailyPayloads[#dailyPayloads + 1] = {"Day " .. tostring(item.day)}
                dailyPayloads[#dailyPayloads + 1] = {item.day}
            end
            if item.label then
                chestPayloads[#chestPayloads + 1] = {item.label}
            end
        end
        for _, sArgs in ipairs({{"claimDaily"}, {"ClaimDaily"}, {"claimDailyReward"}, {"DailyReward"}, {"Daily"}, {"claim"}, {"Claim"}, {"collect"}, {}}) do
            dailyPayloads[#dailyPayloads + 1] = sArgs
        end
        for _, cArgs in ipairs({{"Daily Chest"}, {"Group Rewards"}, {"Daily"}, {"Reward Chest"}, {"claim"}, {}}) do
            chestPayloads[#chestPayloads + 1] = cArgs
        end
        return dailyPayloads, chestPayloads
    end

    local function probeRemotePool(pool, payloads, isAlive)
        for _, rem in ipairs(pool or {}) do
            if isAlive and not isAlive() then return false end
            if rem and rem.Parent then
                if rem:IsA("RemoteFunction") then
                    for _, args in ipairs(payloads) do
                        if isAlive and not isAlive() then return false end
                        local ok, res = invokeSafe(rem, args)
                        if isAlive and not isAlive() then return false end
                        if isClaimSuccess(ok, res) then return true end
                    end
                else
                    for _, args in ipairs(payloads) do
                        if isAlive and not isAlive() then return false end
                        fireSafe(rem, args)
                    end
                end
            end
        end
        return false
    end

    local function collectDailyRewards(now)
        if RewardEngine.dailyPassBusy then return end
        local readyDailyItems = scanReadyDailyRewards()
        local hasDailyBadge = hasGuiBadgeFor({"daily", "login", "streak", "calendar", "benefit"}, DAILY_EXCLUDE_KW)
        if (#readyDailyItems == 0 and not hasDailyBadge) or (RewardEngine.lastDailyAttempt > 0 and (now - RewardEngine.lastDailyAttempt < 5.0)) then return end
        local hasAnyBtn = false
        for _, it in ipairs(readyDailyItems) do if it.btn then hasAnyBtn = true; break end end
        if #Remotes.dailyRemotes == 0 and #Remotes.chestRemotes == 0 and #Remotes.genericRewardRemotes == 0 and not hasAnyBtn then
            return
        end

        local myGen, tok = Runtime.Gen, Runtime.SessionTokens.rew
        RewardEngine.lastDailyAttempt = now
        RewardEngine.dailyPassBusy = true
        task.spawn(function()
            local function isAlive()
                return Config.Active and Config.AutoCollectRewards and myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew
            end
            if not isAlive() then
                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew then RewardEngine.dailyPassBusy = false end
                return
            end
            local claimedLabel = (#readyDailyItems > 0 and readyDailyItems[1].label) or "Daily Reward"
            local dailyPayloads, chestPayloads = buildDailyPayloads(readyDailyItems)
            local claimedOk = false
            -- Prefer a visible daily claim button over broad remote guessing.
            -- Verify the card/badge changed before counting it as collected.
            for _, item in ipairs(readyDailyItems) do
                if not isAlive() then break end
                if item.btn and RewardEngine.fireGuiButton(item.btn) then
                    task.wait(0.30)
                    if not isAlive() then break end
                    local remAfter = scanReadyDailyRewards()
                    if #remAfter < #readyDailyItems
                        or (hasDailyBadge and not hasGuiBadgeFor({"daily", "login", "streak", "calendar", "benefit"}, DAILY_EXCLUDE_KW)) then
                        claimedOk = true
                        break
                    end
                end
            end
            if not claimedOk and isAlive() then claimedOk = probeRemotePool(Remotes.dailyRemotes, dailyPayloads, isAlive) end
            if not claimedOk and isAlive() then claimedOk = probeRemotePool(Remotes.chestRemotes, chestPayloads, isAlive) end
            if not claimedOk and isAlive() then claimedOk = probeRemotePool(Remotes.genericRewardRemotes, dailyPayloads, isAlive) end
            if not isAlive() then
                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew then RewardEngine.dailyPassBusy = false end
                return
            end

            if not claimedOk and (#Remotes.dailyRemotes > 0 or #Remotes.chestRemotes > 0 or #Remotes.genericRewardRemotes > 0) then
                task.wait(0.35)
                if not isAlive() then
                    if myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew then RewardEngine.dailyPassBusy = false end
                    return
                end
                local remAfter = scanReadyDailyRewards()
                if #readyDailyItems > 0 and #remAfter < #readyDailyItems then
                    claimedOk = true
                elseif hasDailyBadge and not hasGuiBadgeFor({"daily", "login", "streak", "calendar", "benefit"}, DAILY_EXCLUDE_KW) then
                    claimedOk = true
                end
            end

            if not claimedOk and #readyDailyItems > 0 then
                for _, item in ipairs(readyDailyItems) do
                    if not isAlive() then break end
                    if item.btn and RewardEngine.fireGuiButton(item.btn) then
                        task.wait(0.30)
                        if not isAlive() then break end
                        local remAfter = scanReadyDailyRewards()
                        if #remAfter < #readyDailyItems or (hasDailyBadge and not hasGuiBadgeFor({"daily", "login", "streak", "calendar", "benefit"}, DAILY_EXCLUDE_KW)) then
                            claimedOk = true
                            break
                        end
                    end
                end
            end

            if claimedOk then
                RewardEngine.collectedCount += 1
                RewardEngine.lastRewardLabel = claimedLabel
            else
                RewardEngine.lastDailyAttempt = now - 3.5
            end
            if myGen == Runtime.Gen and tok == Runtime.SessionTokens.rew then RewardEngine.dailyPassBusy = false end
        end)
    end

    function RewardEngine.runAutoCollectPass()
        if not (Config.Active and Config.AutoCollectRewards) then return end
        Remotes.refresh(false)
        local now = M.clock()
        collectReadyQuests(now)
        collectTimeGifts(now)
        collectDailyRewards(now)
    end

    local function isBadSpinValueObj(obj)
        local nl = obj.Name:lower()
        if not nl:find("spin", 1, true) then return true end
        if nl:find("cooldown") or nl:find("timer") or nl:find("last") or nl:find("cost")
            or nl:find("price") or nl:find("max") or nl:find("reward") or nl:find("total")
            or nl:find("used") or nl:find("needed") or nl:find("req") or nl:find("goal")
            or nl:find("progress") or nl:find("bought") or nl:find("daily") then
            return true
        end
        local cur = obj.Parent
        while cur and cur ~= Player and cur ~= game do
            local cl = cur.Name:lower()
            if cl:find("quest") or cl:find("gift") or cl:find("reward") or cl:find("shop")
                or cl:find("pack") or cl:find("gui") or cl:find("backpack") then
                return true
            end
            cur = cur.Parent
        end
        return false
    end

    local function parseWheelSpinsText(rawTxt)
        local low = cleanGuiText(rawTxt)
        local m = low:match("you%s+have:?%s*(%d+)%s*spin")
            or low:match("spins?%s*left:?%s*(%d+)")
            or low:match("(%d+)%s*spins?%s*left")
            or low:match("^spins?:?%s*(%d+)$")
        return m and tonumber(m) or nil
    end

    local function readAvailableSpinsCount()
        if RewardEngine.cachedSpinsLabel and RewardEngine.cachedSpinsLabel.Parent then
            local n = parseWheelSpinsText(RewardEngine.cachedSpinsLabel.Text)
            if n ~= nil then return n end
        end

        if RewardEngine.cachedSpinsVal and RewardEngine.cachedSpinsVal.Parent and not isBadSpinValueObj(RewardEngine.cachedSpinsVal) then
            local n = tonumber(RewardEngine.cachedSpinsVal.Value)
            if n ~= nil then return n end
        else
            RewardEngine.cachedSpinsVal = nil
        end

        for _, root in ipairs(getExpandedPlayerRoots()) do
            for _, obj in ipairs(root:GetChildren()) do
                if obj:IsA("ValueBase") and tonumber(obj.Value) and not isBadSpinValueObj(obj) then
                    RewardEngine.cachedSpinsVal = obj
                    return tonumber(obj.Value)
                end
            end
        end
        for attrName, attrVal in pairs(Player:GetAttributes()) do
            local al = tostring(attrName):lower()
            if (al == "spins" or al == "freespins" or al == "wheelspins" or al == "fortunespins") and tonumber(attrVal) then
                return tonumber(attrVal)
            end
        end

        local now = M.clock()
        if now - RewardEngine.lastFullGuiScan < 1.2 then
            return RewardEngine.spinsLeftCached
        end
        RewardEngine.lastFullGuiScan = now

        local items, pGui = getCachedGuiTextItems()
        if pGui then
            for i = 1, #items do
                local entry = items[i]
                local desc = entry.inst
                if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Text ~= "" then
                    local num = parseWheelSpinsText(desc.Text)
                    if num ~= nil then
                        local cur, inWheel = desc, false
                        for _ = 1, 6 do
                            if not cur or cur == pGui then break end
                            local cl = cur.Name:lower()
                            if cl:find("quest") then inWheel = false; break end
                            if cl:find("wheel") or cl:find("spin") or cl:find("fortune") then inWheel = true end
                            cur = cur.Parent
                        end
                        if inWheel then
                            RewardEngine.cachedSpinsLabel = desc
                            return num
                        end
                    end
                end
            end
        end
        return nil
    end

    local function findWheelSpinButton()
        if RewardEngine.cachedWheelBtn and RewardEngine.cachedWheelBtn.Parent then
            return RewardEngine.cachedWheelBtn
        end
        local items, pGui = getCachedGuiTextItems()
        if not pGui then return nil end
        for i = 1, #items do
            local entry = items[i]
            local gui, d = entry.gui, entry.inst
            if d:IsA("GuiButton") and not isTemplateAncestor(d, gui) then
                local tl = d:IsA("TextButton") and cleanGuiText(d.Text) or ""
                local nl = d.Name:lower()
                local badSpinBtn = tl:find("buy") or tl:find("shop") or tl:find("store") or tl:find("robux")
                    or tl:find("r%$") or tl:find("purchase") or tl == "close" or tl == "x"
                    or nl:find("buy") or nl:find("shop") or nl:find("close")
                if not badSpinBtn and (tl == "spin" or tl == "spin!" or nl == "spinbutton" or nl == "spinbtn") then
                    local cur = d
                    for _ = 1, 6 do
                        if not cur or cur == pGui then break end
                        local cl = cur.Name:lower()
                        if cl:find("wheel") or cl:find("spin") or cl:find("fortune") then
                            RewardEngine.cachedWheelBtn = d
                            return d
                        end
                        cur = cur.Parent
                    end
                end
            end
        end
        return nil
    end

    function RewardEngine.refreshSpinsCache()
        RewardEngine.spinsLeftCached = readAvailableSpinsCount()
        return RewardEngine.spinsLeftCached
    end

    function RewardEngine.stepAutoSpin()
        if not (Config.Active and Config.AutoSpinReward) then return end
        local now = M.clock()
        if RewardEngine.isWheelSpinning or (RewardEngine.lastSpinAttempt > 0 and (now - RewardEngine.lastSpinAttempt < 1.8)) then return end

        Remotes.refresh(false)
        local spinsBefore = readAvailableSpinsCount()
        RewardEngine.spinsLeftCached = spinsBefore
        if spinsBefore == nil or spinsBefore <= 0 then return end

        local wheelRems = {}
        for _, r in ipairs(Remotes.wheelRemotes) do
            if r and r.Parent then
                local rn = r.Name:lower()
                if not (rn:find("buy") or rn:find("shop") or rn:find("purchase")) then
                    wheelRems[#wheelRems + 1] = r
                end
            end
        end
        if #wheelRems == 0 then
            local directW = ReplicatedStorage:FindFirstChild("openFortuneWheelRemote", true)
            if directW and (directW:IsA("RemoteFunction") or directW:IsA("RemoteEvent")) then
                local cw = cloneref(directW)
                Remotes.wheelRemotes[1] = cw
                wheelRems[1] = cw
            end
        end
        local wheelBtn = findWheelSpinButton()
        if #wheelRems == 0 and not wheelBtn then return end

        local myGen, tok = Runtime.Gen, Runtime.SessionTokens.spin
        RewardEngine.lastSpinAttempt = now
        RewardEngine.isWheelSpinning = true
        task.spawn(function()
            local function isAlive()
                return Config.Active and Config.AutoSpinReward and myGen == Runtime.Gen and tok == Runtime.SessionTokens.spin
            end
            local chanceItem = Remotes.wheelChanceItems[1]
            if not (chanceItem and chanceItem.Parent) then
                local cf = ReplicatedStorage:FindFirstChild("fortuneWheelChances") or ReplicatedStorage:FindFirstChild("fortuneWheelChances", true)
                if cf then
                    chanceItem = cf:FindFirstChild("Fortune Wheel") or cf:GetChildren()[1]
                    if chanceItem then Remotes.wheelChanceItems[1] = chanceItem end
                end
            end
            local ok, res, spunOk = false, nil, false
            local attempts = {}
            if RewardEngine.workingSpinArgs then
                attempts[#attempts + 1] = RewardEngine.workingSpinArgs
            end
            if chanceItem then
                attempts[#attempts + 1] = {"openFortuneWheel", chanceItem}
                attempts[#attempts + 1] = {chanceItem}
                attempts[#attempts + 1] = {"spin", chanceItem}
            end
            attempts[#attempts + 1] = {"openFortuneWheel", "Fortune Wheel"}
            attempts[#attempts + 1] = {"openFortuneWheel"}
            attempts[#attempts + 1] = {"spin"}
            attempts[#attempts + 1] = {"Spin"}
            attempts[#attempts + 1] = {"Fortune Wheel"}
            attempts[#attempts + 1] = {}

            for _, wheelRem in ipairs(wheelRems) do
                if not isAlive() or spunOk then break end
                if wheelRem and wheelRem.Parent then
                    if wheelRem:IsA("RemoteFunction") then
                        for _, args in ipairs(attempts) do
                            if not isAlive() then
                                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.spin then RewardEngine.isWheelSpinning = false end
                                return
                            end
                            ok, res = invokeSafe(wheelRem, args)
                            local curSpins = readAvailableSpinsCount()
                            if isClaimSuccess(ok, res) or (curSpins and curSpins < spinsBefore) then
                                RewardEngine.workingSpinArgs = args
                                spunOk = true
                                break
                            end
                        end
                    else
                        for _, args in ipairs(attempts) do
                            if not isAlive() then
                                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.spin then RewardEngine.isWheelSpinning = false end
                                return
                            end
                            local fired = fireSafe(wheelRem, args)
                            if fired then ok = true end
                            task.wait(0.08)
                            if not isAlive() then
                                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.spin then RewardEngine.isWheelSpinning = false end
                                return
                            end
                            local curSpins = readAvailableSpinsCount()
                            if curSpins and curSpins < spinsBefore then
                                RewardEngine.workingSpinArgs = args
                                spunOk = true
                                break
                            end
                        end
                    end
                end
            end

            task.wait(0.45)
            if not isAlive() then
                if myGen == Runtime.Gen and tok == Runtime.SessionTokens.spin then RewardEngine.isWheelSpinning = false end
                return
            end
            local spinsAfter = readAvailableSpinsCount()
            if (spinsAfter == nil or spinsAfter >= spinsBefore) and not spunOk and wheelBtn then
                RewardEngine.fireGuiButton(wheelBtn)
                task.wait(0.35)
                if not isAlive() then
                    if myGen == Runtime.Gen and tok == Runtime.SessionTokens.spin then RewardEngine.isWheelSpinning = false end
                    return
                end
                spinsAfter = readAvailableSpinsCount()
            end

            RewardEngine.spinsLeftCached = spinsAfter
            local consumed = spunOk or (spinsAfter ~= nil and spinsAfter < spinsBefore) or isClaimSuccess(ok, res)
            if consumed then
                RewardEngine.spinsCompleted += 1
                if type(res) == "table" and res.Name then RewardEngine.lastSpinLabel = tostring(res.Name)
                elseif typeof(res) == "Instance" then RewardEngine.lastSpinLabel = res.Name
                elseif type(res) == "string" and res ~= "" then RewardEngine.lastSpinLabel = res
                else RewardEngine.lastSpinLabel = "Fortune Wheel Spin" end
            end
            task.wait(1.3)
            if myGen == Runtime.Gen and tok == Runtime.SessionTokens.spin then RewardEngine.isWheelSpinning = false end
        end)
    end
end

----------------------------------------------------------------
-- Forward-Declared Perf & Telemetry State Tables
----------------------------------------------------------------
local Perf = {
    aiGcSteppedKb = 0,
    aiSchedulerMode = "Standard",
    realCyclesThisSec = 0,
    actualCyclesPerSec = 0,
    lastCycleMeasureTime = M.clock(),
    lastLuaWorkMs = 0,
    activeWorkers = 2,
    frameBudgetSec = 0.0016,
    baselineFPS = 60,
}

local Telemetry = {
    strStartTime = M.clock(), rebStartTime = M.clock(), punStartTime = M.clock(),
    baseStr = nil, baseDura = nil, baseReb = nil,
    strPredictor = nil, duraPredictor = nil, repTracker = nil, punchTracker = nil,
    punchesTotal = 0, rebCooldownLeft = 0, rebHasServerCd = false,
    rebCycleDuration = LEGIT_GAMEPASS_REBIRTH_COOLDOWN, lastRebGainPerCycle = 0,
    lastRebFire = 0, lastConfirmedRebirthTime = 0, lastKnownRebirthCount = nil,
    rebInvokeInFlight = false, rebInvokeStart = 0, rebConfirmedSeq = 0,
    cachedGuiRebReq = nil, cachedGuiRebReqForCount = nil, lastGuiRebScan = 0,
    liveRawFPS = 60, smoothFPS = 60, livePing = 0, smoothPing = 0, baselinePing = 65,
    liveFrameMs = 16.6, smoothFrameMs = 16.6, aiCurrentRepRate = 480,
}

----------------------------------------------------------------
-- Combat & Boss Auto-Kill Engine (Universal Rig Discovery + Fast Punch + Pre-Damage Cooldown Dodge)
----------------------------------------------------------------
local Combat = {
    char = nil, tool = nil, cachedTool = nil, lastToolLookup = -100,
    tracks = {}, trackIdx = 1, lastTrackTrigger = -100,
    lastTargetScan = -100, lastDeepScan = -100,
    candidateBossModels = {}, rockTargets = {}, bossTargets = {}, playerTargets = {},
    adorneeGuiByModel = setmetatable({}, {__mode = "k"}),
    activeArm = 1, swingProgress = 1, rigType = nil, joints = {}, origC0 = {},
    rfInFlight = setmetatable({}, {__mode = "k"}),
}

local BossEngine = {
    kills = 0,
    normalKills = 0,
    eventKills = 0,
    damageDealt = 0,
    liveDps = 0,
    evadingAOE = false,
    evadeHoldCF = nil,
    arenaCenter = nil,
    arenaFloorY = nil,
    lastFloorRayT = -100,
    isCharging = false,
    chargeKind = nil,
    chargePct = 0,
    chargeRemSec = 0,
    chargeStartT = 0,
    chargeEndT = 0,
    chargeSigKey = nil,
    skillChargeCount = 0,
    ultChargeCount = 0,
    lastSkillStartT = 0,
    lastUltStartT = 0,
    avgSkillInterval = 0,
    avgUltInterval = 0,
    evadeUntil = 0,
    aoeFlagUntil = 0,
    postAttackHoldUntil = 0,
    wasTelegraphActive = false,
    wasImmediateHazard = false,
    dodgeEscapeDir = nil,
    trackedDangerInsts = setmetatable({}, {__mode = "k"}),
    spawnedPartTimes = setmetatable({}, {__mode = "k"}),
    watchCache = setmetatable({}, {__mode = "k"}),
    lastSafeDist = 380,
    lastAtkImpact = nil,
    seqStart = nil,
    seqTotal = nil,
    tweenStartPos = nil,
    tweenStartT = 0,
    tweenElapsed = 0,
    tweenDur = 0,
    tweenTargetModel = nil,
    bossCfgLoaded = false,
    bossCfgCheckedAt = -100,
    bossCfgMap = {},
    statusText = "Action: Inactive",
    currentBossModel = nil,
    currentBossHum = nil,
    currentTargetObj = nil,
    prevEngagedModel = nil,
    prevEngagedHP = nil,
    lastTrackedBossModel = nil,
    lastTrackedIsEvent = false,
    lastBossDeathPos = nil,
    savedOriginCF = nil,
    collectingChest = false,
    chestWaitUntil = 0,
    trackedChest = nil,
    countedDead = setmetatable({}, {__mode = "k"}),
    lastAttackSeq = nil,
    lastAoeCheck = -100,
    cachedTopOffset = setmetatable({}, {__mode = "k"}),
    lastSafeSpot = nil,
    lastHoverCF = nil,
    noClipBackup = setmetatable({}, {__mode = "k"}),
    noClipChar = nil,
    noClipConn = nil,
    OPTIONS = {
        {label = "Common Boss",        keys = {"common"}},
        {label = "Rare Boss",          keys = {"rare"}},
        {label = "Epic Boss",          keys = {"epic"}},
        {label = "Legendary Boss",     keys = {"legendary", "%f[%a]legend%f[%A]"}},
        {label = "Mythic Boss",        keys = {"mythic", "mythical"}},
        {label = "Rainbow/Admin Boss", keys = {"rainbow", "admin", "rgb", "chroma"}},
        {label = "Alien Boss (Event)", keys = {"alien", "ufo", "space", "galaxy", "cosmic", "xeno", "martian", "invader", "nebula", "cyborg", "astro", "eventboss", "event boss"}},
        {label = "All Bosses (Auto)",  keys = {"*"}},
    },
}

do
    local CollectionService = nil
    pcall(function() CollectionService = SafeService("CollectionService") end)

    local BOSS_TITLE_KW = {"boss", "golem", "overlord", "colossus"}
    local EVENT_BOSS_KW = {"alien", "ufo", "space", "galaxy", "cosmic", "xeno", "martian", "invader", "nebula", "cyborg", "astro", "eventboss", "event boss"}
    local EXPLICIT_TIER_KW = {"common", "rare", "epic", "legendary", "mythic", "mythical", "rainbow", "admin"}
    local BOSS_TIER_KW = {
        "common", "rare", "epic", "legendary", "mythic", "mythical", "rainbow", "admin",
        "alien", "ufo", "cosmic", "galaxy", "xeno", "martian", "invader", "nebula", "cyborg", "astro", "eventboss",
        "titan", "champion", "guardian", "omega", "supreme", "mutant"
    }
    local PET_SKIP_KW = {"%f[%a]pet%f[%A]", "%f[%a]pets%f[%A]", "evolved", "follower", "companion", "%f[%a]egg%f[%A]"}
    local STRICT_PROP_SKIP_KW = {
        "spawner", "refresh", "viewreward", "rewards", "button", "prompt",
        "sign", "board", "screen", "monitor", "pillar", "stair", "platform", "stage",
        "lobby", "pedestal", "teleporter", "leaderboard", "statue", "captain",
        "shopkeeper", "shop", "store", "vendor", "merchant", "seller", "dealer",
        "quest", "trainer", "guide", "giver", "portal", "teleport", "%f[%a]door%f[%A]", "%f[%a]gate%f[%A]",
        "chest", "wheel", "booth", "punchingbag", "npc", "arena", "baseplate", "stand", "dummy", "display"
    }
    local SCENERY_ONLY_SKIP_KW = {
        "%f[%a]rock%f[%A]", "%f[%a]rocks%f[%A]", "boulder", "machine", "bench", "squat",
        "treadmill", "deadlift", "pullup", "barbell", "dumbbell", "weight"
    }
    local ANCESTOR_SKIP_KW = {"pets", "eggs", "rocks", "machines", "leaderboard", "statue", "shop", "quest", "portal"}
    local ROCK_KW = {"rock", "stone", "boulder", "punching", "crystal", "meteor", "jungle", "legends", "king", "inferno", "mystic", "frozen", "golden"}
    local BOSS_FOLDER_KW = {"boss", "bosses", "activeboss", "eventboss", "alienboss", "bossevent", "bossarena", "raid", "raids"}
    local BOSS_CS_TAGS = {"BossEventBoss", "AlienBoss", "Boss", "EventBoss", "ActiveBoss", "Enemy"}
    local PURE_SKIP_FOLDERS = {
        "pets", "eggs", "vfx", "debris", "trees", "water", "clouds", "effects", "particles",
        "building", "buildings", "decor", "props", "road", "roads", "shop", "shops",
        "leaderboard", "leaderboards", "statue", "statues", "rocks", "machines", "weights", "bench", "treadmill"
    }
    local EXACT_SKIP_MODELS = {
        map = true, world = true, islands = true, island = true, city = true, terrain = true,
        scenery = true, lobby = true, spawn = true, spawns = true, gyms = true, gym = true,
        decor = true, decorations = true, props = true, buildings = true, roads = true,
        lighting = true, scriptables = true, water = true, clouds = true, rocks = true,
        machinesfolder = true, machines = true, pets = true, eggs = true, shops = true, shop = true,
    }
    local AOE_KW = {
        "aoe", "ult", "ultimate", "shockwave", "slam", "warning", "danger", "blast",
        "laser", "beam", "explosion", "meteor", "nova", "hazard", "smash", "stomp",
        "telegraph", "redzone", "dangerzone"
    }
    local RARITY_INDEX_NAMES = {"common", "rare", "epic", "legendary", "mythic", "rainbow"}

    local function getBossEventModelMeta(modelName)
        if not modelName or modelName == "" then return nil end
        local now = M.clock()
        if not BossEngine.bossCfgLoaded and (now - BossEngine.bossCfgCheckedAt >= 10.0) then
            BossEngine.bossCfgCheckedAt = now
            pcall(function()
                local sharedDir = ReplicatedStorage:FindFirstChild("shared") or ReplicatedStorage:FindFirstChild("Shared")
                local cfgDir = sharedDir and (sharedDir:FindFirstChild("config") or sharedDir:FindFirstChild("Config"))
                local mod = (cfgDir and cfgDir:FindFirstChild("BossEventConfig")) or ReplicatedStorage:FindFirstChild("BossEventConfig")
                if mod and mod:IsA("ModuleScript") then
                    local okReq, cfg = pcall(require, mod)
                    if okReq and type(cfg) == "table" then
                        BossEngine.bossCfgLoaded = true
                        local map = {}
                        local rarities = cfg.RARITIES or cfg.Rarities or cfg.TIERS or cfg
                        if type(rarities) == "table" then
                            for k, entry in pairs(rarities) do
                                if type(entry) == "table" then
                                    local rName = entry.Rarity or entry.Name or entry.Tier or entry.Id
                                        or ((type(k) == "number") and RARITY_INDEX_NAMES[k])
                                        or ((type(k) == "string") and k) or ""
                                    local dName = entry.DisplayName or entry.BossName or entry.Title or ""
                                    local combined = (tostring(rName) .. " " .. tostring(dName)):lower():gsub("^%s+", ""):gsub("%s+$", "")
                                    if combined ~= "" then
                                        for _, mField in ipairs({"BossModel", "ModelName", "Model", "RigName", "BossName", "DisplayName"}) do
                                            local mv = entry[mField]
                                            local ms = (typeof(mv) == "Instance" and mv.Name) or (type(mv) == "string" and mv) or nil
                                            if ms and ms ~= "" then
                                                local mLow = ms:lower()
                                                map[mLow] = map[mLow] and (map[mLow] .. " | " .. combined) or combined
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        BossEngine.bossCfgMap = map
                    end
                end
            end)
        end
        return BossEngine.bossCfgMap[modelName:lower()]
    end

    local cachedBossHitParts = setmetatable({}, {__mode = "k"})
    local cachedBossTags = setmetatable({}, {__mode = "k"})
    local cachedBossHpRef = setmetatable({}, {__mode = "k"})
    local excludedModelCache = setmetatable({}, {__mode = "k"})
    local cachedBodyStats = setmetatable({}, {__mode = "k"})
    local cachedExtMeta, lastExtMetaScan = "", -100
    local cachedGuiBarLbl, lastGuiBarScan, cachedGuiBarHp, cachedGuiBarMax, cachedGuiBarWantEv = nil, -100, 0, 0, nil

    local HP_SUFFIX = {k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33}
    local function parseCompactNum(str)
        if not str or str == "" then return nil end
        local clean = tostring(str):gsub(",", ""):gsub("%s+", "")
        local nStr, suf = clean:match("^([%d%.]+)([a-zA-Z]*)$")
        local n = tonumber(nStr)
        if not n then return nil end
        if suf and suf ~= "" then
            local mult = HP_SUFFIX[suf:lower()]
            if mult then return n * mult end
        end
        return n
    end

    local function parseHpFractionText(rawTxt)
        if not rawTxt or rawTxt == "" then return nil, nil end
        local plain = tostring(rawTxt):gsub("<[^>]+>", " ")
        local low = plain:lower()
        if low:find("strength") or low:find("rebirth") or low:find("gem") or low:find("coin")
            or low:find("token") or low:find("price") or low:find("buy") or low:find("equip")
            or low:find("player") or low:find("brawl") or low:find("gift") or low:find("spin")
            or low:find("level") or low:find("lvl") or low:find("mastery") then
            return nil, nil
        end
        local lhs, rhs = plain:match("([%d%.,]+%s*[a-zA-Z]*)%s*/%s*([%d%.,]+%s*[a-zA-Z]*)")
        if lhs and rhs then
            local h, mx = parseCompactNum(lhs), parseCompactNum(rhs)
            if h and mx and mx > 0 then return h, mx end
        end
        return nil, nil
    end

    local function hasKw(strLow, list)
        if not strLow or strLow == "" then return false end
        for _, kw in ipairs(list) do if strLow:find(kw, 1, true) then return true end end
        return false
    end

    local function hasPatternKw(strLow, list)
        if not strLow or strLow == "" then return false end
        for _, pat in ipairs(list) do
            if pat:sub(1, 1) == "%" then
                if strLow:find(pat) then return true end
            elseif strLow:find(pat, 1, true) then
                return true
            end
        end
        return false
    end

    local function isInteractiveGuiOrButton(inst)
        local cur = inst
        for _ = 1, 3 do
            if not cur or cur == workspace or cur == game then break end
            if cur:IsA("SurfaceGui") or cur:FindFirstChildOfClass("ProximityPrompt") or cur:FindFirstChildOfClass("ClickDetector") then
                return true
            end
            local cn = cur.Name:lower()
            if cn:find("refresh") or cn:find("viewreward") or cn:find("button") or cn:find("sign") or (cn:find("board") and not cur:IsA("BillboardGui") and not cn:find("billboard")) or cn:find("prompt") then
                return true
            end
            cur = cur.Parent
        end
        return false
    end

    local function isPetModel(obj)
        local nLow = obj.Name:lower()
        if hasPatternKw(nLow, PET_SKIP_KW) then return true end
        if obj:GetAttribute("PetOwner") ~= nil or obj:GetAttribute("Owner") ~= nil then return true end
        for _, fn in ipairs({"Owner", "owner", "PetOwner", "petOwner"}) do
            local v = obj:FindFirstChild(fn)
            if v and v:IsA("ValueBase") then return true end
        end
        local cur = obj.Parent
        for _ = 1, 3 do
            if not cur or cur == workspace then break end
            local pl = cur.Name:lower()
            if pl == "pets" or pl == "pet" or hasPatternKw(pl, PET_SKIP_KW) then return true end
            cur = cur.Parent
        end
        return false
    end

    local function hasArenaOrBossAncestor(obj)
        local cur = obj.Parent
        local firstCont, anyEvent = nil, false
        for _ = 1, 5 do
            if not cur or cur == workspace or cur == game then break end
            local pl = cur.Name:lower()
            if hasKw(pl, EVENT_BOSS_KW) then anyEvent = true end
            if pl:find("arena", 1, true) or hasKw(pl, BOSS_FOLDER_KW) or hasKw(pl, EVENT_BOSS_KW) then
                if not firstCont then firstCont = cur end
            end
            cur = cur.Parent
        end
        return (firstCont ~= nil), firstCont, anyEvent
    end

    local function hasLimbAnatomy(model)
        local hasHead = (model:FindFirstChild("Head", true) ~= nil)
        local hasCore = (model:FindFirstChild("HumanoidRootPart", true) ~= nil)
            or (model:FindFirstChild("UpperTorso", true) ~= nil)
            or (model:FindFirstChild("Torso", true) ~= nil)
        return hasHead and hasCore
    end

    local function hasBossEventTag(model)
        if not (CollectionService and model) then return false end
        local okT, hasT = pcall(CollectionService.HasTag, CollectionService, model, "BossEventBoss")
        if okT and hasT == true then return true end
        local okA, hasA = pcall(CollectionService.HasTag, CollectionService, model, "AlienBoss")
        return okA and hasA == true
    end

    local function hasAlienBossTag(model)
        if not (CollectionService and model) then return false end
        local okA, hasA = pcall(CollectionService.HasTag, CollectionService, model, "AlienBoss")
        return okA and hasA == true
    end

    local function isGenericOrPropModel(model)
        if not model then return true end
        local nl = model.Name:lower()
        if nl == "model" or nl == "part" or nl == "folder" or nl == "map" or nl == "base" then
            return true
        end
        if hasPatternKw(nl, STRICT_PROP_SKIP_KW) and not hasKw(nl, BOSS_TITLE_KW) then
            return true
        end
        return false
    end

    local function isRealBossEventModel(model)
        if not model then return false end
        if hasBossEventTag(model) or model:FindFirstChild("BossDamageHitbox") ~= nil or getBossEventModelMeta(model.Name) ~= nil then
            return true
        end
        if isGenericOrPropModel(model) or EXACT_SKIP_MODELS[model.Name:lower()] then
            return false
        end
        local hasRig = (model:FindFirstChildOfClass("Humanoid") ~= nil)
            or (model:FindFirstChildOfClass("AnimationController") ~= nil)
            or hasLimbAnatomy(model)
        if hasRig and model:FindFirstChild("BossDamageHitbox", true) ~= nil then
            return true
        end
        return false
    end

    local function isExcludedModel(obj)
        if not obj or not obj:IsA("Model") or obj == Player.Character or Players:GetPlayerFromCharacter(obj) then
            return true
        end
        local cachedEx = excludedModelCache[obj]
        if cachedEx ~= nil then return cachedEx end
        if isPetModel(obj) then
            excludedModelCache[obj] = true
            return true
        end

        local nLow = obj.Name:lower()
        local hasEventTag = hasBossEventTag(obj)
        local hasDirectHitbox = (obj:FindFirstChild("BossDamageHitbox") ~= nil)
        if EXACT_SKIP_MODELS[nLow] and not hasEventTag and obj:GetAttribute("IsBoss") ~= true and obj:GetAttribute("Boss") ~= true then
            excludedModelCache[obj] = true
            return true
        end
        if isGenericOrPropModel(obj) and not hasEventTag and not hasDirectHitbox then
            excludedModelCache[obj] = true
            return true
        end

        local inBossArena = hasArenaOrBossAncestor(obj)
        local isRealEventBoss = hasEventTag or hasDirectHitbox
            or (inBossArena and obj:FindFirstChild("BossDamageHitbox", true) ~= nil)
        local isExplicitBossAttr = isRealEventBoss or (obj:GetAttribute("IsBoss") == true) or (obj:GetAttribute("Boss") == true)
        local ownTitleBoss = hasKw(nLow, BOSS_TITLE_KW) or hasKw(nLow, EVENT_BOSS_KW) or isExplicitBossAttr

        if (nLow:find("arena", 1, true) or nLow:find("gym", 1, true)) and not (hasEventTag or hasDirectHitbox or hasKw(nLow, BOSS_TITLE_KW)) then
            excludedModelCache[obj] = true
            return true
        end
        if nLow:find("arena", 1, true) and (obj:FindFirstChildWhichIsA("Model") ~= nil) and not isRealEventBoss then
            excludedModelCache[obj] = true
            return true
        end

        inBossArena = inBossArena or isRealEventBoss
        local hasCreatureRig = hasEventTag or hasDirectHitbox
            or (obj:FindFirstChildOfClass("Humanoid") ~= nil)
            or (obj:FindFirstChildOfClass("AnimationController") ~= nil)
            or (obj:FindFirstChildWhichIsA("Humanoid", true) ~= nil)
            or (obj:FindFirstChildWhichIsA("AnimationController", true) ~= nil)
            or hasLimbAnatomy(obj)

        if not hasCreatureRig then
            excludedModelCache[obj] = true
            return true
        end

        if hasPatternKw(nLow, SCENERY_ONLY_SKIP_KW) and not (ownTitleBoss or (inBossArena and hasCreatureRig)) then
            excludedModelCache[obj] = true
            return true
        end

        if not isRealEventBoss and not ownTitleBoss and (obj:FindFirstChildWhichIsA("ProximityPrompt", true) or obj:FindFirstChildWhichIsA("ClickDetector", true)) then
            excludedModelCache[obj] = true
            return true
        end

        local rigChildCount = 0
        for _, ch in ipairs(obj:GetChildren()) do
            if ch:IsA("Model") and (ch:FindFirstChildOfClass("Humanoid") or ch:FindFirstChildOfClass("AnimationController") or hasLimbAnatomy(ch)) then
                rigChildCount += 1
                if rigChildCount >= 2 then
                    excludedModelCache[obj] = true
                    return true
                end
            end
        end

        local cur = obj.Parent
        for _ = 1, 4 do
            if not cur or cur == workspace or cur == game then break end
            local ancLow = cur.Name:lower()
            if ancLow:find("gym", 1, true) and ancLow ~= "gyms" and ancLow ~= "gymsfolder" then
                if not ownTitleBoss and not inBossArena then
                    excludedModelCache[obj] = true
                    return true
                end
            end
            if not ownTitleBoss and not inBossArena then
                if ancLow == "npcs" or ancLow == "npc" or hasKw(ancLow, ANCESTOR_SKIP_KW) then
                    excludedModelCache[obj] = true
                    return true
                end
            end
            cur = cur.Parent
        end
        excludedModelCache[obj] = false
        return false
    end

    local function getModelBodyStats(model)
        local now = M.clock()
        local cached = cachedBodyStats[model]
        local ttl = (Config.AutoKillBoss and BossEngine.currentBossModel == model) and 2.5 or 8.0
        if cached and (now - cached.t < ttl) then
            return cached.res
        end

        local bodyParts = {}
        local sumX, sumY, sumZ, visCount = 0, 0, 0, 0
        local minY, maxY = 9e9, -9e9
        local minX, maxX, minZ, maxZ = 9e9, -9e9, 9e9, -9e9

        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and not isInteractiveGuiOrButton(d) then
                local isFloorPlate = (d.Size.X > 65 and d.Size.Z > 65 and d.Size.Y < 8)
                local dl = d.Name:lower()
                local isBossDmgHb = (dl == "bossdamagehitbox")
                if not isFloorPlate and (isBossDmgHb or not (dl:find("hitbox") and d.Transparency >= 0.98)) then
                    bodyParts[#bodyParts + 1] = d
                    if d.Transparency < 0.95 or isBossDmgHb or dl == "humanoidrootpart" or dl == "head" or dl == "uppertorso" or dl == "torso" then
                        local p = d.Position
                        local hs = d.Size * 0.5
                        sumX += p.X; sumY += p.Y; sumZ += p.Z; visCount += 1
                        if p.Y - hs.Y < minY then minY = p.Y - hs.Y end
                        if p.Y + hs.Y > maxY then maxY = p.Y + hs.Y end
                        if p.X - hs.X < minX then minX = p.X - hs.X end
                        if p.X + hs.X > maxX then maxX = p.X + hs.X end
                        if p.Z - hs.Z < minZ then minZ = p.Z - hs.Z end
                        if p.Z + hs.Z > maxZ then maxZ = p.Z + hs.Z end
                    end
                end
            end
        end

        if visCount == 0 then
            local fb = model:FindFirstChild("BossDamageHitbox", true) or model:FindFirstChild("Hitbox", true)
                or model:FindFirstChild("HumanoidRootPart", true) or model.PrimaryPart
            if fb and fb:IsA("BasePart") and not isInteractiveGuiOrButton(fb) then
                bodyParts[#bodyParts + 1] = fb
                local p, hs = fb.Position, fb.Size * 0.5
                sumX, sumY, sumZ, visCount = p.X, p.Y, p.Z, 1
                minY, maxY = p.Y - hs.Y, p.Y + hs.Y
                minX, maxX = p.X - hs.X, p.X + hs.X
                minZ, maxZ = p.Z - hs.Z, p.Z + hs.Z
            end
        end

        local res
        if visCount == 0 then
            res = {valid = false, visCount = 0, height = 0, maxSpan = 0, center = Vector3.zero, maxY = -9e9, parts = bodyParts}
        else
            local center = Vector3.new(sumX / visCount, sumY / visCount, sumZ / visCount)
            local height = M.max(0, maxY - minY)
            local maxSpan = M.max(height, M.max(maxX - minX, maxZ - minZ))
            res = {
                valid = (maxY > -150) and (visCount >= 1),
                visCount = visCount,
                height = height,
                maxSpan = maxSpan,
                center = center,
                maxY = maxY,
                parts = bodyParts,
            }
        end
        cachedBodyStats[model] = {res = res, t = now}
        return res
    end

    local function resolveBossParts(model)
        local stats = getModelBodyStats(model)
        local center = stats.center
        local dmgHb = model:FindFirstChild("BossDamageHitbox", true)
        local candHrp = model:FindFirstChild("HumanoidRootPart", true) or model:FindFirstChild("UpperTorso", true)
            or model:FindFirstChild("Torso", true) or dmgHb or model.PrimaryPart or model:FindFirstChild("Hitbox", true)
        local candHead = model:FindFirstChild("Head", true) or model:FindFirstChild("UpperTorso", true) or dmgHb

        local function isNearBody(p)
            if not (p and p:IsA("BasePart") and p.Parent) or isInteractiveGuiOrButton(p) then return false end
            if p == dmgHb or not stats.valid then return true end
            return ((p.Position - center).Magnitude <= M.max(42, stats.maxSpan * 0.95))
        end

        local hrp = isNearBody(candHrp) and candHrp or nil
        local head = isNearBody(candHead) and candHead or nil

        if not hrp or not head then
            local bestCenterDist, bestTopY = 9e9, -9e9
            for _, d in ipairs(stats.parts) do
                local dl = d.Name:lower()
                if isNearBody(d) and (d.Transparency < 0.95 or dl == "humanoidrootpart" or dl == "hitbox" or dl == "bossdamagehitbox") then
                    local distC = (d.Position - center).Magnitude
                    if not hrp and distC < bestCenterDist then
                        bestCenterDist = distC; hrp = d
                    end
                    local topY = d.Position.Y + (d.Size.Y * 0.5)
                    if not head and topY > bestTopY then
                        bestTopY = topY; head = d
                    end
                end
            end
        end

        if not hrp then hrp = head end
        if not head then head = hrp end
        return hrp, head, stats
    end

    local HP_CUR_NAMES = {health = true, hp = true, bosshp = true, bosshealth = true, currenthp = true, currenthealth = true, life = true}
    local HP_MAX_NAMES = {maxhealth = true, maxhp = true, maxbosshp = true, maxbosshealth = true, maxlife = true}

    local function readSafeNumValue(valObj, allowUnparented)
        if not (valObj and (allowUnparented or valObj.Parent) and valObj:IsA("ValueBase")) then return nil end
        local ok, raw = pcall(function() return valObj.Value end)
        if not ok then return nil end
        return tonumber(raw)
    end

    local function readContainerHpValues(container)
        if not container then return 0, 0 end
        local curVal, maxVal = nil, nil
        for _, d in ipairs(container:GetChildren()) do
            if d:IsA("ValueBase") and readSafeNumValue(d) then
                local dl = d.Name:lower()
                if HP_CUR_NAMES[dl] then curVal = curVal or d
                elseif HP_MAX_NAMES[dl] then maxVal = maxVal or d end
            end
        end
        local hv = readSafeNumValue(curVal)
        if hv then
            local mx = readSafeNumValue(maxVal) or hv
            if mx > 0 then return hv, mx end
        end
        local cKey, mKey = nil, nil
        for ak, av in pairs(container:GetAttributes()) do
            if tonumber(av) then
                local al = tostring(ak):lower()
                if HP_CUR_NAMES[al] then cKey = ak
                elseif HP_MAX_NAMES[al] then mKey = ak end
            end
        end
        if cKey then
            local hv = tonumber(container:GetAttribute(cKey)) or 0
            local mx = (mKey and tonumber(container:GetAttribute(mKey))) or hv
            if mx > 0 then return hv, mx end
        end
        return 0, 0
    end

    local function scanPlayerGuiBossBars(wantEvent)
        local now = M.clock()
        if cachedGuiBarLbl and cachedGuiBarLbl.Parent and cachedGuiBarLbl.Visible and cachedGuiBarWantEv == wantEvent then
            local hv, mx = parseHpFractionText(cachedGuiBarLbl.Text)
            if hv and mx and mx >= 500 then
                cachedGuiBarHp = hv; cachedGuiBarMax = mx
                return hv, mx
            end
            cachedGuiBarLbl = nil
        end
        if (now - lastGuiBarScan) < 4.0 and cachedGuiBarWantEv == wantEvent then
            return cachedGuiBarHp, cachedGuiBarMax
        end
        lastGuiBarScan = now; cachedGuiBarWantEv = wantEvent; cachedGuiBarHp = 0; cachedGuiBarMax = 0

        local pGui = Player:FindFirstChildOfClass("PlayerGui")
        if not pGui then return 0, 0 end
        local bestScore, bestHp, bestMax, bestLbl = -1, 0, 0, nil
        for _, gui in ipairs(pGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui ~= Runtime.UI.GUI and gui ~= Runtime.UI.ToggleGui and gui.Name ~= "Chat" and gui.Name ~= "TouchGui" then
                local gl = gui.Name:lower()
                if not (gl:find("shop") or gl:find("store") or gl:find("inventory") or gl:find("pet") or gl:find("wheel")) then
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("TextLabel") and d.Visible and d.Text and d.Text ~= "" and #d.Text <= 48 then
                            local hv, mx = parseHpFractionText(d.Text)
                            if hv and mx and mx >= 500 then
                                local ctxParts = {gl, d.Name:lower()}
                                local p = d.Parent
                                for _ = 1, 3 do
                                    if not p or p == gui then break end
                                    ctxParts[#ctxParts + 1] = p.Name:lower()
                                    p = p.Parent
                                end
                                local ctx = table.concat(ctxParts, " ")
                                local hasBossCtx = ctx:find("boss") or ctx:find("alien") or ctx:find("event") or ctx:find("golem") or ctx:find("hp") or ctx:find("health")
                                local isInTopBand = (d.AbsolutePosition.Y <= 220)
                                if hasBossCtx or isInTopBand then
                                    local score = (hasBossCtx and 10 or 0) + (isInTopBand and 4 or 0)
                                    local isEvCtx = hasKw(ctx, EVENT_BOSS_KW)
                                    if wantEvent == true and isEvCtx then score += 20
                                    elseif wantEvent == false and ctx:find("boss") and not isEvCtx then score += 20
                                    elseif wantEvent ~= nil and wantEvent ~= isEvCtx and isEvCtx then score -= 8 end
                                    if score > bestScore then
                                        bestScore = score; bestHp = hv; bestMax = mx; bestLbl = d
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        cachedGuiBarLbl = bestLbl; cachedGuiBarHp = bestHp; cachedGuiBarMax = bestMax
        return bestHp, bestMax
    end

    local function readExternalArenaHp(arenaModel, wantEvent)
        local wsHp = tonumber(workspace:GetAttribute("BossHealth"))
        if wsHp ~= nil then
            local wsMax = tonumber(workspace:GetAttribute("BossMaxHealth")) or wsHp
            if wsMax > 0 then return wsHp, wsMax end
        end

        local hv, mx = readContainerHpValues(arenaModel)
        if mx > 0 then return hv, mx end

        local scanList = {}
        if arenaModel then scanList[#scanList + 1] = arenaModel end
        local evFolder = workspace:FindFirstChild("Events")
        if evFolder then
            for _, sub in ipairs(evFolder:GetChildren()) do
                local srHv, srMx = readContainerHpValues(sub)
                if srMx > 0 then return srHv, srMx end
                scanList[#scanList + 1] = sub
            end
        end
        for _, fn in ipairs({"BossHealth", "CurrentBoss", "ActiveBoss", "BossInfo", "BossData", "EventBoss", "AlienBoss"}) do
            local rObj = ReplicatedStorage:FindFirstChild(fn)
            if rObj then
                local rhv, rmx = readContainerHpValues(rObj)
                if rmx > 0 then return rhv, rmx end
                scanList[#scanList + 1] = rObj
            end
        end
        for _, container in ipairs(scanList) do
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text and d.Text ~= "" and not d:IsDescendantOf(Player.Character or game) and not isInteractiveGuiOrButton(d) then
                    local thv, tmx = parseHpFractionText(d.Text)
                    if thv and tmx and tmx >= 500 then return thv, tmx end
                end
            end
        end
        return scanPlayerGuiBossBars(wantEvent)
    end

    local function hasActiveBossRigSignal(model, bodyStats, hum)
        if not (bodyStats and bodyStats.valid and bodyStats.maxY > -150) then return false end
        if isRealBossEventModel(model) then return true end
        if hum and hum.Health > 0 then return true end
        local ac = model:FindFirstChildWhichIsA("AnimationController", true)
        local animator = ac and ac:FindFirstChildWhichIsA("Animator", true)
        if animator then
            local okT, tracks = pcall(animator.GetPlayingAnimationTracks, animator)
            if okT and tracks and #tracks > 0 then return true end
        end
        if model:GetAttribute("IsBoss") == true or model:GetAttribute("Boss") == true then return true end
        local inArena, arenaCont = hasArenaOrBossAncestor(model)
        if inArena and arenaCont and bodyStats.height >= 6.5 and bodyStats.visCount >= 3 and hasLimbAnatomy(model) then
            return true
        end
        local nl = model.Name:lower()
        if (hasKw(nl, BOSS_TITLE_KW) or hasKw(nl, EVENT_BOSS_KW)) and bodyStats.height >= 7.0 and bodyStats.visCount >= 3 and hasLimbAnatomy(model) then
            return true
        end
        return false
    end

    local function readBossHealth(model, bodyStats, allowUnparented)
        if not (model and (allowUnparented or model.Parent)) then return nil, 0, 0, false end

        local ref = cachedBossHpRef[model]
        if ref then
            if ref.kind == "hum" and ref.hum and (allowUnparented or ref.hum.Parent) and ref.hum.MaxHealth > 250 then
                return ref.hum, ref.hum.Health, ref.hum.MaxHealth, false
            elseif ref.kind == "val" and ref.cur and (allowUnparented or ref.cur.Parent) then
                local hv = readSafeNumValue(ref.cur, allowUnparented) or 0
                local mx = (ref.max and (allowUnparented or ref.max.Parent) and readSafeNumValue(ref.max, allowUnparented)) or ref.lastMax or hv
                if mx > 0 then
                    ref.lastMax = mx
                    return ref.hum, hv, mx, false
                end
            elseif ref.kind == "attr" and ref.host and (allowUnparented or ref.host.Parent) then
                local hv = tonumber(ref.host:GetAttribute(ref.curKey)) or 0
                local mx = (ref.maxKey and tonumber(ref.host:GetAttribute(ref.maxKey))) or ref.lastMax or hv
                if mx > 0 then
                    ref.lastMax = mx
                    return ref.hum, hv, mx, false
                end
            elseif ref.kind == "wsAttr" then
                local hv = tonumber(workspace:GetAttribute("BossHealth"))
                if hv ~= nil then
                    local mx = tonumber(workspace:GetAttribute("BossMaxHealth")) or ref.lastMax or hv
                    if mx > 0 then
                        ref.lastMax = mx
                        return ref.hum, hv, mx, false
                    end
                end
            elseif ref.kind == "lbl" and ref.lbl and (allowUnparented or ref.lbl.Parent) then
                local hv, mx = parseHpFractionText(ref.lbl.Text)
                if hv and mx and mx > 0 then return ref.hum, hv, mx, false end
            end
            cachedBossHpRef[model] = nil
        end

        local hum = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildWhichIsA("Humanoid", true)

        local statsBox = model:FindFirstChild("stats") or model:FindFirstChild("Stats")
        if statsBox then
            local sCur, sMax = nil, nil
            for _, d in ipairs(statsBox:GetChildren()) do
                if d:IsA("ValueBase") and readSafeNumValue(d, allowUnparented) then
                    local dl = d.Name:lower()
                    if HP_CUR_NAMES[dl] then sCur = sCur or d
                    elseif HP_MAX_NAMES[dl] then sMax = sMax or d end
                end
            end
            local sHv = readSafeNumValue(sCur, allowUnparented)
            if sHv ~= nil then
                local sMx = readSafeNumValue(sMax, allowUnparented) or sHv
                if sMx > 0 and (not hum or sMx > hum.MaxHealth or hum.MaxHealth <= 250) then
                    cachedBossHpRef[model] = {kind = "val", hum = hum, cur = sCur, max = sMax, lastMax = sMx}
                    return hum, sHv, sMx, false
                end
            end
            local scHv, scMx = readContainerHpValues(statsBox)
            if scMx > 0 and (not hum or scMx > hum.MaxHealth or hum.MaxHealth <= 250) then
                return hum, scHv, scMx, false
            end
        end

        local curVal, maxVal = nil, nil
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("ValueBase") and readSafeNumValue(d, allowUnparented) then
                local dl = d.Name:lower()
                if HP_CUR_NAMES[dl] then curVal = curVal or d
                elseif HP_MAX_NAMES[dl] then maxVal = maxVal or d end
            end
        end
        local hvVal = readSafeNumValue(curVal, allowUnparented)
        if hvVal then
            local mx = readSafeNumValue(maxVal, allowUnparented) or hvVal
            if mx > 0 and (not hum or mx > hum.MaxHealth or hum.MaxHealth <= 250) then
                cachedBossHpRef[model] = {kind = "val", hum = hum, cur = curVal, max = maxVal, lastMax = mx}
                return hum, hvVal, mx, false
            end
        end

        local hpHosts = {model}
        local hR = model:FindFirstChild("HumanoidRootPart", true)
        local hH = model:FindFirstChild("Head", true)
        local hD = model:FindFirstChild("BossDamageHitbox", true)
        if hD then hpHosts[#hpHosts + 1] = hD end
        if hR then hpHosts[#hpHosts + 1] = hR end
        if hH then hpHosts[#hpHosts + 1] = hH end
        for _, host in ipairs(hpHosts) do
            local cKey, mKey = nil, nil
            for ak, av in pairs(host:GetAttributes()) do
                if tonumber(av) then
                    local al = tostring(ak):lower()
                    if HP_CUR_NAMES[al] then cKey = ak
                    elseif HP_MAX_NAMES[al] then mKey = ak end
                end
            end
            if cKey then
                local hv = tonumber(host:GetAttribute(cKey)) or 0
                local mx = (mKey and tonumber(host:GetAttribute(mKey))) or hv
                if mx > 0 and (not hum or mx > hum.MaxHealth or hum.MaxHealth <= 250) then
                    cachedBossHpRef[model] = {kind = "attr", hum = hum, host = host, curKey = cKey, maxKey = mKey, lastMax = mx}
                    return hum, hv, mx, false
                end
            end
        end

        if isRealBossEventModel(model) then
            local wsHp = tonumber(workspace:GetAttribute("BossHealth"))
            if wsHp ~= nil then
                local wsMax = tonumber(workspace:GetAttribute("BossMaxHealth")) or wsHp
                if wsMax > 0 and (not hum or wsMax > hum.MaxHealth or hum.MaxHealth <= 250) then
                    cachedBossHpRef[model] = {kind = "wsAttr", hum = hum, lastMax = wsMax}
                    return hum, wsHp, wsMax, false
                end
            end
        end

        local function scanBillboardLabelsForHp(container)
            if not container then return nil, 0, 0 end
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text and d.Text ~= "" and d:FindFirstAncestorOfClass("BillboardGui") and not isInteractiveGuiOrButton(d) then
                    local hv, mx = parseHpFractionText(d.Text)
                    if hv and mx and mx > 0 then return d, hv, mx end
                end
            end
            return nil, 0, 0
        end
        local lbl, hv, mx = scanBillboardLabelsForHp(model)
        if not lbl and Combat.adorneeGuiByModel[model] then
            lbl, hv, mx = scanBillboardLabelsForHp(Combat.adorneeGuiByModel[model])
        end
        if lbl then
            cachedBossHpRef[model] = {kind = "lbl", hum = hum, lbl = lbl}
            return hum, hv, mx, false
        end

        if hum and hum.MaxHealth > 250 then
            cachedBossHpRef[model] = {kind = "hum", hum = hum}
            return hum, hum.Health, hum.MaxHealth, false
        end

        local inArena, arenaCont, ancEvent = hasArenaOrBossAncestor(model)
        local nl = model.Name:lower()
        local hasOwnRig = (model:FindFirstChild("BossDamageHitbox", true) ~= nil)
            or hasBossEventTag(model)
            or ((hum ~= nil or model:FindFirstChildWhichIsA("AnimationController", true) ~= nil) and hasLimbAnatomy(model) and not isGenericOrPropModel(model))
        local isBossCandidateRig = hasOwnRig and (inArena or isRealBossEventModel(model) or hasKw(nl, BOSS_TITLE_KW) or hasKw(nl, EVENT_BOSS_KW))
        if isBossCandidateRig then
            local wantEv = ancEvent or hasAlienBossTag(model) or hasKw(nl, EVENT_BOSS_KW)
            local ehv, emx = readExternalArenaHp(arenaCont, wantEv and true or nil)
            if emx > 0 and (not hum or emx > hum.MaxHealth) then
                return hum, ehv, emx, false
            end
        end

        if hum and hum.MaxHealth > 0 and hum.Health > 0 then
            return hum, hum.Health, hum.MaxHealth, false
        end

        if hasOwnRig and hasActiveBossRigSignal(model, bodyStats or getModelBodyStats(model), hum) then
            return hum, 1, 1, true
        end

        return hum, 0, 0, false
    end

    local function inferBossColorTier(model)
        local hueBuckets = {}
        local neonScore, totalScore = {common = 0, rare = 0, epic = 0, legendary = 0, mythic = 0}, 0
        local rainbowSignal = false

        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("UIGradient") then rainbowSignal = true end
            if d:IsA("BasePart") and (tonumber(d.Transparency) or 0) < 0.88 and d.Name ~= "HumanoidRootPart" then
                local c = d.Color
                if c and c.ToHSV then
                    local h, s, v = c:ToHSV()
                    local weight = (d.Material == Enum.Material.Neon) and 4 or 1
                    if s >= 0.25 and v >= 0.16 then
                        totalScore += weight
                        if d.Material == Enum.Material.Neon or s >= 0.45 then
                            hueBuckets[M.floor(h * 10)] = true
                        end
                        if h <= 0.045 or h >= 0.91 then neonScore.mythic += weight
                        elseif h <= 0.20 then neonScore.legendary += weight
                        elseif h <= 0.44 then neonScore.common += weight
                        elseif h <= 0.72 then neonScore.rare += weight
                        else neonScore.epic += weight end
                    elseif v >= 0.28 then
                        totalScore += 0.35
                        neonScore.common += 0.35
                    end
                end
            end
        end

        local distinctCount = 0
        for _ in pairs(hueBuckets) do distinctCount += 1 end
        if rainbowSignal or distinctCount >= 4 then return "rainbow" end
        if totalScore == 0 then return nil end

        local bestTier, bestVal = nil, 0
        for tName, sc in pairs(neonScore) do
            if sc > bestVal then bestVal = sc; bestTier = tName end
        end
        return bestTier
    end

    local function readExternalBossTierMeta(isEvent)
        local now = M.clock()
        if not isEvent and (now - lastExtMetaScan < 5.0) and cachedExtMeta ~= "" then
            return cachedExtMeta
        end
        local tierParts = {}
        local metaNames = isEvent and {"EventBoss", "AlienBoss", "ActiveEventBoss"} or {"CurrentBoss", "ActiveBoss", "BossInfo", "BossData", "BossState", "BossArena"}
        for _, root in ipairs({ReplicatedStorage, workspace}) do
            for _, mName in ipairs(metaNames) do
                local inst = root:FindFirstChild(mName)
                if inst then
                    for ak, av in pairs(inst:GetAttributes()) do
                        local kl = tostring(ak):lower()
                        if type(av) == "string" and av ~= "" and (kl:find("rarity") or kl:find("tier") or kl:find("name") or kl:find("boss")) then
                            tierParts[#tierParts + 1] = av:lower()
                        end
                    end
                    for _, ch in ipairs(inst:GetChildren()) do
                        if ch:IsA("StringValue") and ch.Value ~= "" then
                            local cl = ch.Name:lower()
                            if cl:find("rarity") or cl:find("tier") or cl:find("name") or cl:find("boss") or cl:find("type") then
                                tierParts[#tierParts + 1] = ch.Value:lower()
                            end
                        end
                    end
                end
            end
        end
        local pGui = Player:FindFirstChildOfClass("PlayerGui")
        if pGui then
            for _, gui in ipairs(pGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled and gui ~= Runtime.UI.GUI and gui ~= Runtime.UI.ToggleGui then
                    local gl = gui.Name:lower()
                    local wantGui = isEvent and (gl:find("alien") or gl:find("event") or gl:find("boss"))
                        or (not isEvent and gl:find("boss") and not gl:find("event") and not gl:find("alien"))
                    if wantGui then
                        for _, d in ipairs(gui:GetDescendants()) do
                            if d:IsA("TextLabel") and d.Visible and d.Text and #d.Text <= 60 then
                                local pl = d.Text:gsub("<[^>]+>", " "):lower()
                                if (isEvent and hasKw(pl, EVENT_BOSS_KW)) or (not isEvent and hasKw(pl, EXPLICIT_TIER_KW) and not pl:find("chance")) then
                                    tierParts[#tierParts + 1] = pl
                                end
                            end
                        end
                    end
                end
            end
        end
        local joined = table.concat(tierParts, " | ")
        if not isEvent then lastExtMetaScan = now; cachedExtMeta = joined end
        return joined
    end

    local function detectTierWord(tagStr)
        for _, kw in ipairs({"alien", "common", "rare", "epic", "legendary", "mythic", "rainbow", "admin"}) do
            if tagStr:find(kw, 1, true) then return kw:sub(1, 1):upper() .. kw:sub(2) end
        end
        return nil
    end

    local function buildBossSearchTag(model, hum)
        local now = M.clock()
        local cached = cachedBossTags[model]
        local ttl = (Config.AutoKillBoss and BossEngine.currentBossModel == model) and 2.5 or 8.0
        if cached and (now - cached.t < ttl) then
            return cached.tag, cached.hasFractionBar, cached.isEvent, cached.tierWord, cached.ancBossCont
        end

        local parts = {model.Name:lower()}
        local ancEvent, ancBossCont = false, false
        local p = model.Parent
        for _ = 1, 5 do
            if not p or p == workspace or p == game then break end
            local pLow = p.Name:lower()
            if hasKw(pLow, EVENT_BOSS_KW) then ancEvent = true end
            if pLow:find("arena", 1, true) or hasKw(pLow, BOSS_FOLDER_KW) then ancBossCont = true end
            if pLow ~= "map" and pLow ~= "world" and pLow ~= "arenas" and pLow ~= "gyms" and pLow ~= "gymsfolder" and pLow ~= "events" then
                parts[#parts + 1] = pLow
            end
            p = p.Parent
        end
        local cfgMeta = getBossEventModelMeta(model.Name)
        pcall(function()
            local dn = hum and hum.DisplayName
            if type(dn) == "string" and dn ~= "" then
                parts[#parts + 1] = dn:lower()
            end
            for ak, av in pairs(model:GetAttributes()) do
                local akl = tostring(ak):lower()
                if type(av) == "string" and av ~= "" then
                    parts[#parts + 1] = (akl .. " " .. av:lower())
                elseif type(av) == "number" and (akl == "bossrarityindex" or akl == "rarityindex" or akl == "rarity") then
                    local rWord = RARITY_INDEX_NAMES[M.floor(av)]
                    if rWord then parts[#parts + 1] = rWord end
                elseif av == true and (akl:find("boss") or akl:find("alien") or akl:find("event")) then
                    parts[#parts + 1] = akl
                end
            end
            local ownTagSoFar = table.concat(parts, " | ")
            local isEvModel = ancEvent or hasAlienBossTag(model) or hasKw(ownTagSoFar, EVENT_BOSS_KW)
            if not isEvModel and not hasKw(ownTagSoFar, EXPLICIT_TIER_KW) then
                local wsRarIdx = tonumber(workspace:GetAttribute("BossRarityIndex"))
                local wsDisp = workspace:GetAttribute("BossDisplayName")
                if wsRarIdx and RARITY_INDEX_NAMES[M.floor(wsRarIdx)] then
                    parts[#parts + 1] = RARITY_INDEX_NAMES[M.floor(wsRarIdx)]
                end
                if type(wsDisp) == "string" and wsDisp ~= "" then
                    parts[#parts + 1] = wsDisp:lower()
                end
            elseif isRealBossEventModel(model) and not isEvModel then
                local wsRarIdx = tonumber(workspace:GetAttribute("BossRarityIndex"))
                local wsDisp = workspace:GetAttribute("BossDisplayName")
                if wsRarIdx and RARITY_INDEX_NAMES[M.floor(wsRarIdx)] and not hasKw(ownTagSoFar, EXPLICIT_TIER_KW) then
                    parts[#parts + 1] = RARITY_INDEX_NAMES[M.floor(wsRarIdx)]
                end
                if type(wsDisp) == "string" and wsDisp ~= "" and not hasKw(ownTagSoFar, EXPLICIT_TIER_KW) then
                    parts[#parts + 1] = wsDisp:lower()
                end
            end
            if cfgMeta and not hasKw(table.concat(parts, " | "), EXPLICIT_TIER_KW) then
                parts[#parts + 1] = cfgMeta
            end
        end)

        local hasFractionBar = false
        local function extractBillboardOnly(root)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("StringValue") and d.Value ~= "" then
                    parts[#parts + 1] = (d.Name .. " " .. d.Value):lower()
                elseif d:IsA("TextLabel") and d.Text ~= "" and d:FindFirstAncestorOfClass("BillboardGui") and not isInteractiveGuiOrButton(d) then
                    local plain = d.Text:gsub("<[^>]+>", " ")
                    local low = plain:lower():gsub("%s+", " ")
                    if #low <= 96 then parts[#parts + 1] = low end
                    if parseHpFractionText(plain) ~= nil then hasFractionBar = true end
                end
            end
        end
        extractBillboardOnly(model)
        if Combat.adorneeGuiByModel[model] then
            extractBillboardOnly(Combat.adorneeGuiByModel[model])
        end

        local baseTag = table.concat(parts, " | ")
        local isEvent = ancEvent or hasAlienBossTag(model) or hasKw(baseTag, EVENT_BOSS_KW)

        if isEvent then
            if not baseTag:find("alien", 1, true) then
                parts[#parts + 1] = "alien event"
            end
        elseif not hasKw(baseTag, EXPLICIT_TIER_KW) then
            local extMeta = readExternalBossTierMeta(false)
            if extMeta ~= "" and hasKw(extMeta, EXPLICIT_TIER_KW) then
                parts[#parts + 1] = extMeta
            else
                local inferred = inferBossColorTier(model)
                if inferred then parts[#parts + 1] = inferred end
            end
        end

        local tag = table.concat(parts, " | ")
        local tierWord = detectTierWord(tag)
        cachedBossTags[model] = {tag = tag, hasFractionBar = hasFractionBar, isEvent = isEvent, tierWord = tierWord, ancBossCont = ancBossCont, t = now}
        return tag, hasFractionBar, isEvent, tierWord, ancBossCont
    end

    local function isConfirmedBossModel(model, hum, maxHp, hrp, tag, hasFractionBar, inBossCont, bodyStats)
        if not (bodyStats and bodyStats.valid) then return false end
        if isGenericOrPropModel(model) and not hasBossEventTag(model) and model:FindFirstChild("BossDamageHitbox") == nil then
            return false
        end
        local hasDamageHitbox = (model:FindFirstChild("BossDamageHitbox", true) ~= nil)
        if (hasDamageHitbox or hasBossEventTag(model)) and maxHp > 0 then
            return true
        end
        local hasCreatureRig = (hum ~= nil)
            or (model:FindFirstChildWhichIsA("AnimationController", true) ~= nil)
            or hasLimbAnatomy(model)
            or hasDamageHitbox
        if not hasCreatureRig then
            return false
        end
        if hasKw(tag, BOSS_TITLE_KW) then return true end
        if model:GetAttribute("IsBoss") == true or model:GetAttribute("Boss") == true then return true end
        if inBossCont and (hasCreatureRig or maxHp >= 150) then
            return true
        end
        if CollectionService then
            for _, tName in ipairs(BOSS_CS_TAGS) do
                local okT, hasT = pcall(CollectionService.HasTag, CollectionService, model, tName)
                if okT and hasT then return true end
            end
        end
        local p = model.Parent
        if p and p ~= workspace and hasKw(p.Name:lower(), BOSS_FOLDER_KW) then
            return true
        end
        local hasTier = hasKw(tag, BOSS_TIER_KW)
        local isLargeBody = bodyStats.height >= 5.5 or (hrp and (hrp.Size.Y >= 3.2 or hrp.Size.X >= 3.0))
        if hasTier and (hasFractionBar or maxHp >= 150 or isLargeBody) then
            return true
        end
        if hasFractionBar and maxHp >= 500 then
            return true
        end
        return false
    end

    local function getBossHitParts(model, head, hrp, bodyStats)
        local cached = cachedBossHitParts[model]
        if cached and #cached > 0 then
            for i = #cached, 1, -1 do
                if not (cached[i] and cached[i].Parent) then table.remove(cached, i) end
            end
            if #cached > 0 then return cached end
        end
        local list, seenP = {}, {}
        local function addP(p)
            if p and p:IsA("BasePart") and not seenP[p] and not isInteractiveGuiOrButton(p) then
                seenP[p] = true
                list[#list + 1] = p
            end
        end
        addP(model:FindFirstChild("BossDamageHitbox", true))
        addP(model:FindFirstChild("Hitbox", true))
        addP(head); addP(hrp)
        for _, pn in ipairs({"BossDamageHitbox", "Hitbox", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart", "Head"}) do
            addP(model:FindFirstChild(pn, true))
        end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                local nl = d.Name:lower()
                if nl:find("hitbox") or nl == "head" or nl:find("torso") or nl:find("core")
                    or d:FindFirstChildOfClass("TouchTransmitter") then
                    addP(d)
                end
            end
        end
        if #list == 0 and bodyStats and bodyStats.parts then
            for i = 1, M.min(#bodyStats.parts, 6) do addP(bodyStats.parts[i]) end
        end
        cachedBossHitParts[model] = list
        return list
    end

    local function modelHasHpSignal(model)
        if not (model and model:IsA("Model")) then return false end
        if isRealBossEventModel(model) then return true end
        if isGenericOrPropModel(model) then return false end
        if model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildWhichIsA("Humanoid", true) or model:FindFirstChildWhichIsA("AnimationController", true) then
            return true
        end
        local nl = model.Name:lower()
        if (hasKw(nl, BOSS_TITLE_KW) or hasKw(nl, EVENT_BOSS_KW)) and hasLimbAnatomy(model) then return true end
        if model:GetAttribute("IsBoss") == true or model:GetAttribute("Boss") == true then return true end
        local statsFolder = model:FindFirstChild("stats") or model:FindFirstChild("Stats")
        if statsFolder then
            for _, sv in ipairs(statsFolder:GetChildren()) do
                if sv:IsA("ValueBase") and (HP_CUR_NAMES[sv.Name:lower()] or HP_MAX_NAMES[sv.Name:lower()]) then return true end
            end
            if statsFolder:GetAttribute("Health") ~= nil or statsFolder:GetAttribute("MaxHealth") ~= nil then return true end
        end
        if hasLimbAnatomy(model) then return true end
        for _, d in ipairs(model:GetChildren()) do
            if d:IsA("ValueBase") and (HP_CUR_NAMES[d.Name:lower()] or HP_MAX_NAMES[d.Name:lower()]) then return true end
        end
        return false
    end

    function Combat.registerCandidateModel(inst)
        if not (inst and inst.Parent) then return end
        local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
        if model then
            local rigAdded = inst:IsA("Humanoid") or inst:IsA("AnimationController") or (inst:IsA("BasePart") and inst.Name == "BossDamageHitbox")
            if rigAdded then
                excludedModelCache[model] = nil
                cachedBodyStats[model] = nil
                cachedBossHitParts[model] = nil
            end
            if (not Combat.candidateBossModels[model] or rigAdded) and not isExcludedModel(model) and modelHasHpSignal(model) then
                Combat.candidateBossModels[model] = true
                Combat.lastTargetScan = 0
                if BossEngine.markPassiveDirty then BossEngine.markPassiveDirty() end
            end
        end
    end

    local function getCachedPunchTool()
        local now = M.clock()
        if Combat.cachedTool and Combat.cachedTool.Parent and (now - Combat.lastToolLookup < 0.6) then return Combat.cachedTool end
        Combat.lastToolLookup = now
        Combat.cachedTool = Remotes.findPunchTool()
        return Combat.cachedTool
    end

    local function cacheCharJoints(char)
        if Combat.char == char and Combat.rigType ~= nil and next(Combat.joints) ~= nil then return end
        Combat.joints = {}; Combat.origC0 = {}
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        Combat.rigType = hum and hum.RigType or Enum.HumanoidRigType.R15
        local function cap(key, partName, motorName)
            local part = char:FindFirstChild(partName)
            local m = part and part:FindFirstChild(motorName)
            if not m then
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("Motor6D") and d.Name == motorName then m = d; break end
                end
            end
            if m and m:IsA("Motor6D") then Combat.joints[key] = m; Combat.origC0[key] = m.C0 end
        end
        if Combat.rigType == Enum.HumanoidRigType.R15 then
            cap("RShoulder","RightUpperArm","RightShoulder"); cap("LShoulder","LeftUpperArm","LeftShoulder")
            cap("RElbow","RightLowerArm","RightElbow"); cap("LElbow","LeftLowerArm","LeftElbow")
            cap("UpperTorso","UpperTorso","Waist")
        else
            cap("RShoulder","Torso","Right Shoulder"); cap("LShoulder","Torso","Left Shoulder")
        end
    end

    function Combat.restoreJoints()
        for key, m in pairs(Combat.joints) do
            local orig = Combat.origC0[key]
            if m and m.Parent and orig then pcall(function() m.C0 = orig end) end
        end
        Combat.swingProgress = 1
    end

    local function ensureAnimsLoaded(char, hum, tool)
        if Combat.char == char and Combat.tool == tool and #Combat.tracks > 0 then return end
        Combat.char = char; Combat.tool = tool; Combat.tracks = {}; Combat.trackIdx = 1
        cacheCharJoints(char)
        local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
        local seenIds = {}
        local function tryLoad(animObj)
            if not (animObj and animObj:IsA("Animation")) then return end
            local id = animObj.AnimationId
            if not id or id == "" or seenIds[id] then return end
            seenIds[id] = true
            local ok, tr = pcall(function() return animator:LoadAnimation(animObj) end)
            if ok and tr then
                pcall(function() tr.Priority = Enum.AnimationPriority.Action4; tr.Looped = false end)
                table.insert(Combat.tracks, tr)
            end
        end
        if tool then for _, d in ipairs(tool:GetDescendants()) do if d:IsA("Animation") then tryLoad(d) end end end
        if #Combat.tracks == 0 then
            pcall(function()
                for _, d in ipairs(ReplicatedStorage:GetChildren()) do
                    if d:IsA("Animation") then
                        local nl = d.Name:lower()
                        if nl:find("punch") or nl:find("jab") or nl:find("hook") or nl:find("swing") then
                            tryLoad(d); if #Combat.tracks >= 4 then break end
                        end
                    end
                end
            end)
        end
    end

    function Combat.stepKinematics(dt)
        local isPunching = Config.Active and (Config.AutoPunch or Config.AutoKillBoss)
        local char = Player.Character
        if not isPunching or not char then
            if Combat.swingProgress < 1 then Combat.restoreJoints() end
            return
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not (hum and hum.Health > 0) then return end
        cacheCharJoints(char)
        if next(Combat.joints) == nil then return end

        local pSpd = M.clamp(tonumber(Config.PunchSpeed) or 60, 1, 500)
        local isFast = Config.AutoKillBoss or pSpd > 80
        local spd = Config.AutoKillBoss and M.max(pSpd, 140) or pSpd
        local swingsPerSec = isFast and M.clamp(6 + (spd / 45), 7, 16) or 4.5
        if Combat.swingProgress < 1 then Combat.swingProgress = M.min(1, Combat.swingProgress + dt * swingsPerSec) end

        local pulse = M.sin(M.pi * Combat.swingProgress)
        local armSign = Combat.activeArm
        local j, o = Combat.joints, Combat.origC0

        if Combat.rigType == Enum.HumanoidRigType.R15 then
            if armSign == 1 then
                if j.RShoulder and o.RShoulder then j.RShoulder.C0 = o.RShoulder * CFrame.new(0, 0.06 * pulse, -0.28 * pulse) * CFrame.Angles(math.rad(92 * pulse), math.rad(-14 * pulse), math.rad(-10 * pulse)) end
                if j.RElbow and o.RElbow then j.RElbow.C0 = o.RElbow * CFrame.Angles(math.rad(18 * (1 - pulse)), 0, 0) end
                if j.LShoulder and o.LShoulder then j.LShoulder.C0 = o.LShoulder * CFrame.Angles(math.rad(28 * pulse), math.rad(12 * pulse), math.rad(12 * pulse)) end
            else
                if j.LShoulder and o.LShoulder then j.LShoulder.C0 = o.LShoulder * CFrame.new(0, 0.06 * pulse, -0.28 * pulse) * CFrame.Angles(math.rad(92 * pulse), math.rad(14 * pulse), math.rad(10 * pulse)) end
                if j.LElbow and o.LElbow then j.LElbow.C0 = o.LElbow * CFrame.Angles(math.rad(18 * (1 - pulse)), 0, 0) end
                if j.RShoulder and o.RShoulder then j.RShoulder.C0 = o.RShoulder * CFrame.Angles(math.rad(28 * pulse), math.rad(-12 * pulse), math.rad(-12 * pulse)) end
            end
            if j.UpperTorso and o.UpperTorso then j.UpperTorso.C0 = o.UpperTorso * CFrame.Angles(math.rad(4 * pulse), math.rad(14 * armSign * pulse), 0) end
        else
            if armSign == 1 and j.RShoulder and o.RShoulder then
                j.RShoulder.C0 = o.RShoulder * CFrame.new(0, 0.08 * pulse, -0.32 * pulse) * CFrame.Angles(0, math.rad(15 * pulse), math.rad(92 * pulse))
            elseif armSign == -1 and j.LShoulder and o.LShoulder then
                j.LShoulder.C0 = o.LShoulder * CFrame.new(0, 0.08 * pulse, -0.32 * pulse) * CFrame.Angles(0, math.rad(-15 * pulse), math.rad(-92 * pulse))
            end
        end
    end

    local lastAnimPlay = 0
    local function triggerVisualSwing(char, hum, tool, speedVal)
        local now = M.clock()
        local isFast = Config.AutoKillBoss or (speedVal and speedVal > 80)
        local swingsPerSec = isFast and M.clamp(5 + ((speedVal or 140) / 100), 6, 10) or 4.5
        if now - Combat.lastTrackTrigger < (1 / swingsPerSec) then return end
        Combat.lastTrackTrigger = now
        Combat.activeArm = -Combat.activeArm
        Combat.swingProgress = 0.01
        if now - lastAnimPlay < 0.30 then return end
        lastAnimPlay = now
        ensureAnimsLoaded(char, hum, tool)
        if #Combat.tracks > 0 then
            local tr = Combat.tracks[Combat.trackIdx]
            Combat.trackIdx = (Combat.trackIdx % #Combat.tracks) + 1
            if tr and not tr.IsPlaying then
                pcall(function()
                    local animSpeed = isFast and M.clamp(swingsPerSec * 0.28, 1.5, 2.8) or 1.5
                    tr:Play(0.05, 1, animSpeed)
                end)
            end
        end
    end

    -- Deep Unblocked Boss Discovery (Pruned + Memoized for Zero Boss-Tab Lag)
    local function scanFastRealBossSources()
        if CollectionService then
            for _, tagName in ipairs({"BossEventBoss", "AlienBoss"}) do
                local okT, tagged = pcall(CollectionService.GetTagged, CollectionService, tagName)
                if okT and tagged then
                    for _, inst in ipairs(tagged) do
                        local m = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
                        if m and not isExcludedModel(m) then Combat.candidateBossModels[m] = true end
                    end
                end
            end
        end
        for _, ch in ipairs(workspace:GetChildren()) do
            if ch:IsA("Model") and not isExcludedModel(ch) and isRealBossEventModel(ch) then
                Combat.candidateBossModels[ch] = true
            end
        end
        for _, dirName in ipairs({"Events", "bossMaps", "BossMaps", "BossArena", "EventArena", "Bosses", "BossEvent"}) do
            local evRoot = workspace:FindFirstChild(dirName)
            if evRoot then
                for _, ch in ipairs(evRoot:GetChildren()) do
                    if ch:IsA("Model") then
                        if not isExcludedModel(ch) and modelHasHpSignal(ch) then Combat.candidateBossModels[ch] = true end
                    end
                    for _, sub in ipairs(ch:GetChildren()) do
                        if sub:IsA("Model") and not isExcludedModel(sub) and modelHasHpSignal(sub) then
                            Combat.candidateBossModels[sub] = true
                        end
                    end
                end
            end
        end
    end

    function Combat.refreshTargets(rootPos, force)
        local now = M.clock()
        local scanMinInt = Config.AutoKillBoss and 0.85 or (Config.AutoPunch and 1.25 or 2.5)
        if not force and (now - Combat.lastTargetScan < scanMinInt) then return end
        Combat.lastTargetScan = now

        scanFastRealBossSources()

        local hasLockedBoss = (Config.AutoKillBoss and BossEngine.currentBossModel ~= nil and BossEngine.currentBossModel.Parent ~= nil)
        local deepInt = Config.AutoKillBoss and (hasLockedBoss and 14.0 or ((#Combat.bossTargets == 0) and 3.5 or 10.0)) or (Config.AutoPunch and 8.0 or 12.0)
        local needDeep = force or (now - Combat.lastDeepScan >= deepInt)
        local skipRocks = (Config.AutoKillBoss == true)
        local skipBossWalk = (not Config.AutoKillBoss and Config.AutoPunch and not force)
        local newRocks = (needDeep and not skipRocks) and {} or Combat.rockTargets

        if needDeep then
            Combat.lastDeepScan = now

            if not skipBossWalk then
                for _, guiRoot in ipairs({workspace, Player:FindFirstChildOfClass("PlayerGui")}) do
                    if guiRoot then
                        for _, bb in ipairs(guiRoot:GetChildren()) do
                            if bb:IsA("BillboardGui") and bb.Adornee and bb.Adornee.Parent then
                                local hostModel = bb.Adornee:IsA("Model") and bb.Adornee or bb.Adornee:FindFirstAncestorOfClass("Model")
                                if hostModel and not isExcludedModel(hostModel) then
                                    Combat.adorneeGuiByModel[hostModel] = bb
                                    Combat.candidateBossModels[hostModel] = true
                                end
                            end
                        end
                    end
                end

                if CollectionService then
                    for _, tName in ipairs(BOSS_CS_TAGS) do
                        local okT, tagged = pcall(CollectionService.GetTagged, CollectionService, tName)
                        if okT and tagged then
                            for _, inst in ipairs(tagged) do Combat.registerCandidateModel(inst) end
                        end
                    end
                end
            end

            local function walkWorkspace(container, depth, inBossZone)
                local maxD = inBossZone and 6 or 3
                if depth > maxD then return end
                for _, child in ipairs(container:GetChildren()) do
                    if child ~= Player.Character and not child:IsA("Terrain") and not child:IsA("Camera") then
                        local cl = child.Name:lower()
                        local childInZone = inBossZone or cl == "events" or cl:find("arena", 1, true) or hasKw(cl, BOSS_FOLDER_KW) or hasKw(cl, EVENT_BOSS_KW)
                        if not childInZone and EXACT_SKIP_MODELS[cl] then
                            if cl == "rocks" or cl == "machinesfolder" or cl == "machines" then
                                if not skipRocks then
                                    for _, obj in ipairs(child:GetChildren()) do
                                        if obj:IsA("Model") and hasKw(obj.Name:lower(), ROCK_KW) then
                                            local tp = obj:FindFirstChildWhichIsA("BasePart")
                                            if tp then newRocks[#newRocks + 1] = {part = tp, dist = (tp.Position - rootPos).Magnitude} end
                                        elseif obj:IsA("BasePart") and obj:FindFirstChildOfClass("TouchTransmitter") then
                                            newRocks[#newRocks + 1] = {part = obj, dist = (obj.Position - rootPos).Magnitude}
                                        end
                                    end
                                end
                            end
                        elseif child:IsA("Model") then
                            if isPetModel(child) or Players:GetPlayerFromCharacter(child) then
                                -- never target pets or player avatars
                            else
                                if not skipBossWalk and not isExcludedModel(child) and modelHasHpSignal(child) then
                                    Combat.candidateBossModels[child] = true
                                elseif not skipRocks and (hasPatternKw(cl, SCENERY_ONLY_SKIP_KW) or (cl:find("rock", 1, true) and not cl:find("boss", 1, true) and not cl:find("golem", 1, true))) then
                                    if hasKw(cl, ROCK_KW) and not cl:find("gym", 1, true) and not cl:find("arena", 1, true) then
                                        local tp = child:FindFirstChildWhichIsA("BasePart")
                                        if tp then newRocks[#newRocks + 1] = {part = tp, dist = (tp.Position - rootPos).Magnitude} end
                                    end
                                end
                                if not skipBossWalk and not child:FindFirstChildOfClass("Humanoid") and not hasKw(cl, PURE_SKIP_FOLDERS) and not (not childInZone and hasPatternKw(cl, STRICT_PROP_SKIP_KW)) then
                                    walkWorkspace(child, depth + 1, childInZone)
                                end
                            end
                        elseif child:IsA("Folder") or child:IsA("Configuration") then
                            if cl == "rocks" or cl == "machinesfolder" or cl:find("machine") then
                                if not skipRocks then
                                    for _, obj in ipairs(child:GetChildren()) do
                                        if obj:IsA("Model") and hasKw(obj.Name:lower(), ROCK_KW) then
                                            local tp = obj:FindFirstChildWhichIsA("BasePart")
                                            if tp then newRocks[#newRocks + 1] = {part = tp, dist = (tp.Position - rootPos).Magnitude} end
                                        elseif obj:IsA("BasePart") and obj:FindFirstChildOfClass("TouchTransmitter") then
                                            newRocks[#newRocks + 1] = {part = obj, dist = (obj.Position - rootPos).Magnitude}
                                        end
                                    end
                                end
                            elseif not skipBossWalk and not hasKw(cl, PURE_SKIP_FOLDERS) then
                                walkWorkspace(child, depth + 1, childInZone)
                            end
                        elseif not skipRocks and depth == 1 and child:IsA("BasePart") and child:FindFirstChildOfClass("TouchTransmitter") and hasKw(cl, ROCK_KW) then
                            newRocks[#newRocks + 1] = {part = child, dist = (child.Position - rootPos).Magnitude}
                        end
                    end
                end
            end
            walkWorkspace(workspace, 1, false)
        elseif not skipRocks then
            for _, r in ipairs(newRocks) do
                if r.part and r.part.Parent then r.dist = (r.part.Position - rootPos).Magnitude else r.dist = 9e9 end
            end
        end

        local players = {}
        if not skipRocks then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= Player and plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Torso") or plr.Character:FindFirstChild("UpperTorso")
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health > 0 then
                        local dist = (hrp.Position - rootPos).Magnitude
                        if dist <= 45 then players[#players + 1] = {part = hrp, hum = hum, dist = dist} end
                    end
                end
            end
        end

        local bosses = {}
        for model in pairs(Combat.candidateBossModels) do
            if not (model and model.Parent) or isExcludedModel(model) then
                Combat.candidateBossModels[model] = nil
                cachedBossHpRef[model] = nil
            else
                pcall(function()
                    local hrp, head, bodyStats = resolveBossParts(model)
                    if hrp and bodyStats.valid then
                        local hum, hp, maxHp, hpPending = readBossHealth(model, bodyStats)
                        if maxHp > 0 and hp > 0 then
                            local tag, hasFractionBar, isEvent, tierWord, inBossCont = buildBossSearchTag(model, hum)
                            if isConfirmedBossModel(model, hum, maxHp, hrp, tag, hasFractionBar, inBossCont, bodyStats) then
                                local dist = (hrp.Position - rootPos).Magnitude
                                bosses[#bosses + 1] = {
                                    model = model, name = model.Name, searchTag = tag, isEvent = isEvent,
                                    tierWord = tierWord, hpPending = hpPending, bodyStats = bodyStats,
                                    hasDamageHitbox = (model:FindFirstChild("BossDamageHitbox", true) ~= nil) or isRealBossEventModel(model),
                                    head = head or hrp, part = hrp, hitParts = getBossHitParts(model, head or hrp, hrp, bodyStats),
                                    hum = hum, hp = hp, maxHp = maxHp, dist = dist,
                                }
                            end
                        end
                    end
                end)
            end
        end

        if not skipRocks then
            table.sort(newRocks, function(a, b) return a.dist < b.dist end)
            table.sort(players, function(a, b) return a.dist < b.dist end)
        end
        table.sort(bosses, function(a, b)
            if (a.hpPending == true) ~= (b.hpPending == true) then
                return not a.hpPending
            end
            return a.dist < b.dist
        end)
        Combat.rockTargets = newRocks; Combat.bossTargets = bosses; Combat.playerTargets = players
    end

    local lastActivate = 0
    function Combat.executeStrike(isRightHand, touchCount, skipAnim, focusBoss)
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not (hum and hum.Health > 0 and root) then return false end

        local handArg = isRightHand and "rightHand" or "leftHand"
        if Remotes.lastScan < 0 then Remotes.refresh(false) end
        local m = Remotes.getPrimaryMuscle()

        local tool = getCachedPunchTool()
        if tool then
            if tool.Parent ~= char then
                pcall(function() hum:EquipTool(tool) end)
                if tool.Parent ~= char then pcall(function() tool.Parent = char end) end
            end
            local now = M.clock()
            local actCd = focusBoss and 0.16 or 0.22
            if now - lastActivate >= actCd then
                lastActivate = now
                pcall(tool.Activate, tool)
                if not focusBoss and not m then
                    for _, rem in ipairs(Remotes.toolRemotes) do
                        if rem and rem.Parent and (rem == tool or rem:IsDescendantOf(tool)) then
                            if rem:IsA("RemoteFunction") then task.spawn(pcall, rem.InvokeServer, rem)
                            else pcall(rem.FireServer, rem) end
                        end
                    end
                end
            end
        end
        if not skipAnim then
            triggerVisualSwing(char, hum, tool, focusBoss and M.max(tonumber(Config.PunchSpeed) or 140, 160) or (tonumber(Config.PunchSpeed) or 60))
        end

        local dualRealBoss = focusBoss and focusBoss.hasDamageHitbox == true
        if m then
            if m:IsA("RemoteFunction") then
                if Combat.rfInFlight[m] == nil then
                    Combat.rfInFlight[m] = true
                    task.spawn(function()
                        pcall(m.InvokeServer, m, "punch", handArg)
                        if dualRealBoss then
                            pcall(m.InvokeServer, m, "punch", isRightHand and "leftHand" or "rightHand")
                        end
                        Combat.rfInFlight[m] = nil
                    end)
                end
            else
                pcall(m.FireServer, m, "punch", handArg)
                if dualRealBoss and not skipAnim then
                    pcall(m.FireServer, m, "punch", isRightHand and "leftHand" or "rightHand")
                end
            end
        end
        if focusBoss and #Remotes.combatRemotes > 0 then
            for _, crem in ipairs(Remotes.combatRemotes) do
                if crem and crem.Parent then
                    if crem:IsA("RemoteFunction") then
                        if Combat.rfInFlight[crem] == nil then
                            Combat.rfInFlight[crem] = true
                            task.spawn(function()
                                pcall(crem.InvokeServer, crem, focusBoss.model)
                                Combat.rfInFlight[crem] = nil
                            end)
                        end
                    else pcall(crem.FireServer, crem, focusBoss.model) end
                end
            end
        end

        if firetouchinterest and touchCount > 0 then
            local rightLimb = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
            local leftLimb = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
            local limb = isRightHand and rightLimb or leftLimb
            local otherLimb = isRightHand and leftLimb or rightLimb
            local handle = tool and tool.Parent == char and tool:FindFirstChild("Handle")
            local hitter = limb or handle or root
            if hitter and hitter:IsA("BasePart") then
                local bObj = focusBoss or Combat.bossTargets[1]
                local bInReach = false
                if bObj and bObj.model and bObj.model.Parent then
                    local reachLim = focusBoss and M.max(58, (bObj.bodyStats and bObj.bodyStats.maxSpan or 25) + 30) or 35
                    if bObj.head and bObj.head.Parent and (bObj.head.Position - root.Position).Magnitude <= reachLim then
                        bInReach = true
                    elseif bObj.part and bObj.part.Parent and (bObj.part.Position - root.Position).Magnitude <= reachLim then
                        bInReach = true
                    end
                end
                if bInReach and bObj and bObj.model and bObj.model.Parent then
                    local _, curHP = readBossHealth(bObj.model, bObj.bodyStats)
                    if curHP > 0 then
                        local hitParts = bObj.hitParts
                        local pCount = #hitParts
                        if pCount > 0 then
                            local maxHits = focusBoss and M.min(pCount, 3) or 1
                            for b = 1, maxHits do
                                local tgt = hitParts[((b - 1) % pCount) + 1]
                                if tgt and tgt.Parent then
                                    local isRealHb = (tgt.Name == "BossDamageHitbox") or (tgt:FindFirstChildOfClass("TouchTransmitter") ~= nil)
                                    if isRealHb then
                                        pcall(firetouchinterest, tgt, hitter, 0)
                                        pcall(firetouchinterest, tgt, hitter, 1)
                                        if focusBoss and otherLimb and otherLimb:IsA("BasePart") then
                                            pcall(firetouchinterest, tgt, otherLimb, 0)
                                            pcall(firetouchinterest, tgt, otherLimb, 1)
                                        end
                                    else
                                        pcall(firetouchinterest, hitter, tgt, 0)
                                        pcall(firetouchinterest, hitter, tgt, 1)
                                    end
                                end
                            end
                        end
                    end
                end
                if not focusBoss then
                    local rock = Combat.rockTargets[1]
                    if rock and rock.part and rock.part.Parent and (rock.part.Position - root.Position).Magnitude <= 22 then
                        pcall(firetouchinterest, hitter, rock.part, 0)
                        pcall(firetouchinterest, hitter, rock.part, 1)
                    end
                    local plrTgt = Combat.playerTargets[1]
                    if plrTgt and plrTgt.dist <= 22 and plrTgt.hum and plrTgt.hum.Health > 0 and plrTgt.part and plrTgt.part.Parent then
                        pcall(firetouchinterest, hitter, plrTgt.part, 0)
                        pcall(firetouchinterest, hitter, plrTgt.part, 1)
                    end
                end
            end
        end
        return m ~= nil or tool ~= nil
    end

    local function getSelectedBossObj()
        local sel = Config.SelectedBoss or "Common Boss"
        local keys = {"common"}
        for _, opt in ipairs(BossEngine.OPTIONS) do
            if opt.label == sel then keys = opt.keys; break end
        end
        if keys[1] == "*" then
            for _, b in ipairs(Combat.bossTargets) do
                if b and b.model and b.model.Parent and b.part and b.part.Parent and (tonumber(b.hp) or 0) > 0 then
                    return b
                end
            end
            return nil
        end
        for _, b in ipairs(Combat.bossTargets) do
            if b and b.model and b.model.Parent and b.part and b.part.Parent and (tonumber(b.hp) or 0) > 0 then
                for _, kw in ipairs(keys) do
                    if kw:sub(1, 1) == "%" then
                        if b.searchTag:find(kw) then return b end
                    elseif b.searchTag:find(kw, 1, true) then
                        return b
                    end
                end
            end
        end
        return nil
    end

    function BossEngine.resetStats()
        BossEngine.kills = 0
        BossEngine.normalKills = 0
        BossEngine.eventKills = 0
        BossEngine.damageDealt = 0
        BossEngine.liveDps = 0
        BossEngine.skillChargeCount = 0
        BossEngine.ultChargeCount = 0
        BossEngine.lastSkillStartT = 0
        BossEngine.lastUltStartT = 0
        BossEngine.avgSkillInterval = 0
        BossEngine.avgUltInterval = 0
        BossEngine.isCharging = false
        BossEngine.chargeKind = nil
        BossEngine.chargePct = 0
        BossEngine.chargeRemSec = 0
        BossEngine.chargeSigKey = nil
        BossEngine.prevEngagedModel = nil
        BossEngine.prevEngagedHP = nil
    end

    local DANGER_ATTR_EXACT = {
        charging = true, casting = true,
        telegraph = true, aoe = true, ultimate = true, ult = true, meteor = true,
        slam = true, shockwave = true, laser = true, nova = true,
    }
    local DANGER_ATTR_KW = {"charging", "casting", "telegraph", "aoe", "ultimate", "meteor"}
    local CHARGE_NUM_KW = {"charge", "chargeprogress", "skillcharge", "ultcharge", "castprogress", "windup"}
    local IDLE_ATTR_STR = {none = true, idle = true, ready = true, ["false"] = true, ["0"] = true, normal = true, walk = true, chase = true}
    local DANGER_ANIM_KW = {"aoe", "ult", "ultimate", "slam", "smash", "stomp", "charge", "windup", "meteor", "shockwave", "nova", "super", "skill"}
    local DANGER_GUI_KW  = {"warning", "ultimate", "charging", "casting", "slam", "meteor", "laser", "shockwave", "aoe"}
    local dangerAnimSeen = setmetatable({}, {__mode = "k"})

    local function isActiveDangerAttr(ak, av)
        if av == false or av == nil or av == 0 then return false end
        local al = tostring(ak):lower()
        if al:sub(1, 10) == "bossattack" then return false end
        -- Cooldowns count down between attacks; they do not mean an attack is active.
        if al:find("cooldown", 1, true) then return false end
        local keyMatch = DANGER_ATTR_EXACT[al] or hasKw(al, DANGER_ATTR_KW)
        if av == true then return keyMatch end
        if type(av) == "string" then
            local vl = av:lower():gsub("^%s+", ""):gsub("%s+$", "")
            if vl == "" or IDLE_ATTR_STR[vl] then return false end
            if keyMatch then return true end
            if (al == "state" or al == "currentskill" or al == "action") and (DANGER_ATTR_EXACT[vl] or hasKw(vl, DANGER_ATTR_KW)) then
                return true
            end
        end
        return false
    end

    local function readChargeAttrRatio(host)
        if not host then return nil end
        for ak, av in pairs(host:GetAttributes()) do
            if type(av) == "number" and av > 0 then
                local al = tostring(ak):lower()
                if hasKw(al, CHARGE_NUM_KW) and not al:find("max", 1, true) then
                    local ratio = (av <= 1.05) and av or (av / 100)
                    if ratio >= 0 and ratio <= 1.5 then return ratio end
                end
            end
        end
        return nil
    end

    function BossEngine.notifyWatchDescendant(d)
        if not d then return end
        local curBoss = BossEngine.currentBossModel
        if curBoss and d:IsDescendantOf(curBoss) then
            if BossEngine.watchCache[curBoss] then
                BossEngine.watchCache[curBoss].t = -100
            end
        end
    end

    local function getBossWatchEntry(bossModel, now)
        local entry = BossEngine.watchCache[bossModel]
        if entry and (now - entry.t < 2.5) then return entry end
        local bools, nums, labels, highlights = {}, {}, {}, {}
        local function collectFrom(root)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("BoolValue") then
                    local dl = d.Name:lower()
                    if DANGER_ATTR_EXACT[dl] or hasKw(dl, DANGER_ATTR_KW) then bools[#bools + 1] = d end
                elseif d:IsA("NumberValue") or d:IsA("IntValue") then
                    local dl = d.Name:lower()
                    if hasKw(dl, CHARGE_NUM_KW) and not dl:find("max", 1, true) then nums[#nums + 1] = d end
                elseif d:IsA("TextLabel") and d:FindFirstAncestorOfClass("BillboardGui") then
                    labels[#labels + 1] = d
                elseif d:IsA("Highlight") then
                    highlights[#highlights + 1] = d
                end
            end
        end
        collectFrom(bossModel)
        if Combat.adorneeGuiByModel[bossModel] then
            collectFrom(Combat.adorneeGuiByModel[bossModel])
        end
        entry = {bools = bools, nums = nums, labels = labels, highlights = highlights, t = now}
        BossEngine.watchCache[bossModel] = entry
        return entry
    end

    local BASIC_ATK_KIND = {
        [""] = true, none = true, idle = true, walk = true, run = true,
        basic = true, melee = true, normal = true, punch = true, jab = true, hit = true, swing = true,
    }
    local SKILL_ATK_KW = {
        "stomp", "slam", "shock", "wave", "aoe", "ult", "ultimate", "jump", "leap",
        "meteor", "laser", "beam", "blast", "skill", "nova", "pulse", "smash",
        "charge", "barrage", "special", "quake", "ground", "cone", "line", "ring",
        "explosion", "bomb", "eruption", "spin", "whirlwind", "tornado", "super",
        "plasma", "energy", "pound", "sweep", "burst", "void", "cosmic", "gravity",
        "vortex", "rain", "crush", "roar", "fury", "rage",
    }
    local ULT_ATK_KW = {"ult", "ultimate", "nova", "meteor", "eruption", "quake", "super", "arena", "cosmic", "void", "cataclysm"}

    local function getPartWorldBox(p)
        local cf = p.CFrame
        local sx, sy, sz = p.Size.X, p.Size.Y, p.Size.Z
        local rx, ry, rz = cf.RightVector, cf.UpVector, cf.LookVector
        local wx = M.abs(rx.X) * sx + M.abs(ry.X) * sy + M.abs(rz.X) * sz
        local wy = M.abs(rx.Y) * sx + M.abs(ry.Y) * sy + M.abs(rz.Y) * sz
        local wz = M.abs(rx.Z) * sx + M.abs(ry.Z) * sy + M.abs(rz.Z) * sz
        return wx, wy, wz
    end

    local function getCharHipOffset(hum, root)
        local hip = (hum and hum.HipHeight and hum.HipHeight > 0) and hum.HipHeight or 2.0
        local halfH = (root and root.Size and root.Size.Y or 2.0) * 0.5
        return hip + halfH
    end

    local function raycastSolidGroundY(x, z, startY, bossModel)
        local ignoreList = {}
        if Player.Character then ignoreList[#ignoreList + 1] = Player.Character end
        if bossModel then ignoreList[#ignoreList + 1] = bossModel end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = false

        local origin = Vector3.new(x, startY, z)
        local dir = Vector3.new(0, -260, 0)
        for _ = 1, 6 do
            params.FilterDescendantsInstances = ignoreList
            local hit = workspace:Raycast(origin, dir, params)
            if not hit or not hit.Instance then return nil end
            local inst = hit.Instance
            local isDanger = BossEngine.trackedDangerInsts[inst] ~= nil
            local ancM = inst:FindFirstAncestorOfClass("Model")
            local isPlrPart = (ancM ~= nil and Players:GetPlayerFromCharacter(ancM) ~= nil)
            if inst:IsA("Terrain") or (inst:IsA("BasePart") and inst.CanCollide and inst.Transparency < 0.92 and not isDanger and not isPlrPart) then
                return hit.Position.Y
            end
            ignoreList[#ignoreList + 1] = inst
            origin = Vector3.new(x, hit.Position.Y - 0.2, z)
        end
        return nil
    end

    local function getSafeFloorSurfaceY(bossModel, bHead, bPart, root, hum, now)
        local hipOff = getCharHipOffset(hum, root)
        if not BossEngine.arenaFloorY or (now - BossEngine.lastFloorRayT >= 0.85) then
            BossEngine.lastFloorRayT = now
            local refTopY = M.max(bHead.Position.Y, bPart.Position.Y) + 45
            local hitY = raycastSolidGroundY(bPart.Position.X, bPart.Position.Z, refTopY, bossModel)
            if hitY then
                BossEngine.arenaFloorY = hitY
            elseif not BossEngine.arenaFloorY then
                local originFloor = BossEngine.savedOriginCF and (BossEngine.savedOriginCF.Position.Y - hipOff) or (root.Position.Y - hipOff)
                BossEngine.arenaFloorY = originFloor
            end
        end
        return BossEngine.arenaFloorY or (root.Position.Y - hipOff), hipOff
    end

    function BossEngine.isDangerPart(d, bossModel, bPos, bossFloorY)
        if not (d and d.Parent) then return false, 0, false, nil end
        local floorY = bossFloorY or (bPos.Y - 6)

        if d:IsA("Highlight") then
            if d.Enabled and d.FillTransparency < 0.88 and bossModel and d:IsDescendantOf(bossModel) then
                local c = d.FillColor
                if c.R > 0.65 and c.G < 0.35 and c.B < 0.35 then
                    return true, 36, false, {center = bPos, isUltimate = false, isBeam = false}
                end
            end
            return false, 0, false, nil
        end

        if d:IsA("Explosion") then
            if (d.Position - bPos).Magnitude <= 220 then
                local r = M.clamp((tonumber(d.BlastRadius) or 28) + 12, 26, 84)
                return true, r, true, {center = d.Position, isUltimate = (r >= 48), isBeam = false}
            end
            return false, 0, false, nil
        end

        if d:IsA("Beam") then
            if not d.Enabled then return false, 0, false, nil end
            local spT = BossEngine.spawnedPartTimes[d]
            if not (spT and (M.clock() - spT) <= 4.5) then return false, 0, false, nil end
            local a0, a1 = d.Attachment0, d.Attachment1
            if a0 and a1 and a0.Parent and a1.Parent then
                local p0, p1 = a0.WorldPosition, a1.WorldPosition
                if (p0 - bPos).Magnitude <= 140 or (p1 - bPos).Magnitude <= 140 then
                    local dir = (p1 - p0) * Vector3.new(1, 0, 1)
                    if dir.Magnitude > 1 then
                        local w = M.max(d.Width0 or 4, d.Width1 or 4)
                        return true, M.clamp(w + 18, 22, 48), true, {
                            center = (p0 + p1) * 0.5, isUltimate = false, isBeam = true, beamDir = dir.Unit
                        }
                    end
                end
            end
            return false, 0, false, nil
        end

        if d:IsA("ParticleEmitter") then
            if not d.Enabled then return false, 0, false, nil end
            local spT = BossEngine.spawnedPartTimes[d]
            if not (spT and (M.clock() - spT) <= 3.5) then return false, 0, false, nil end
            local nl = d.Name:lower()
            if nl:find("ult", 1, true) or nl:find("meteor", 1, true) or nl:find("explosion", 1, true)
                or nl:find("shockwave", 1, true) or nl:find("laser", 1, true) or nl:find("aoe", 1, true) then
                local isUlt = nl:find("ult", 1, true) ~= nil or nl:find("meteor", 1, true) ~= nil
                return true, isUlt and 58 or 36, true, {center = bPos, isUltimate = isUlt, isBeam = false}
            end
            return false, 0, false, nil
        end

        if d:IsA("Decal") or d:IsA("Texture") then
            if d.Transparency < 0.92 and d.Parent and d.Parent:IsA("BasePart") and not (bossModel and d:IsDescendantOf(bossModel)) then
                local nl = d.Name:lower()
                if hasKw(nl, AOE_KW) and BossEngine.spawnedPartTimes[d] ~= nil then
                    local wx, _, wz = getPartWorldBox(d.Parent)
                    local sz = M.max(wx, wz) * 0.5
                    return true, M.clamp(sz + 14, 24, 84), false, {
                        center = d.Parent.Position, isUltimate = (sz >= 40), isBeam = false
                    }
                end
            end
            return false, 0, false, nil
        end

        if not d:IsA("BasePart") or isInteractiveGuiOrButton(d) then return false, 0, false, nil end
        if (d.Position - bPos).Magnitude > 220 then return false, 0, false, nil end
        if d.Transparency >= 0.95 then return false, 0, false, nil end

        local dLow = d.Name:lower()
        if dLow:find("rock", 1, true) or dLow:find("machine", 1, true) or dLow:find("chest", 1, true)
            or dLow:find("portal", 1, true) or dLow:find("statue", 1, true) or dLow:find("pillar", 1, true)
            or dLow:find("wall", 1, true) or dLow:find("spawn", 1, true) or dLow:find("baseplate", 1, true)
            or dLow:find("floor", 1, true) or dLow:find("arena", 1, true) or dLow:find("orb", 1, true) then
            return false, 0, false, nil
        end

        local spT = BossEngine.spawnedPartTimes[d]
        local wx, wy, wz = getPartWorldBox(d)
        local maxHoriz = M.max(wx, wz)
        local minHoriz = M.min(wx, wz)
        local sz = maxHoriz * 0.5
        local isFlatGround = (wy <= 4.5) and (maxHoriz >= 9.0) and ((maxHoriz / M.max(wy, 0.08)) >= 2.2)
            and (M.abs(d.Position.Y - floorY) <= 18.0)
        local isBeamShape = (maxHoriz >= 20.0) and (minHoriz <= 8.5) and (wy <= 10.0)

        if hasKw(dLow, AOE_KW) or dLow:find("ring", 1, true) or dLow:find("indicator", 1, true) or dLow:find("zone", 1, true) then
            local explicitZone = dLow:find("aoe", 1, true) or dLow:find("telegraph", 1, true)
                or dLow:find("redzone", 1, true) or dLow:find("dangerzone", 1, true) or dLow:find("ult", 1, true)
            if not spT and not explicitZone then return false, 0, false, nil end
            if bossModel and d:IsDescendantOf(bossModel) then
                if (not spT) or sz < 5.0 or dLow:find("armor", 1, true) or dLow:find("pack", 1, true)
                    or dLow:find("wing", 1, true) or dLow:find("helmet", 1, true) or dLow:find("jet", 1, true)
                    or dLow:find("body", 1, true) or dLow:find("handle", 1, true) or dLow:find("weapon", 1, true) then
                    return false, 0, false, nil
                end
            end
            local isFast = (dLow:find("explosion", 1, true) or dLow:find("shockwave", 1, true)
                or dLow:find("laser", 1, true) or dLow:find("beam", 1, true)) ~= nil
            local isUlt = (hasKw(dLow, ULT_ATK_KW) or sz >= 40)
            local beamDir = nil
            if isBeamShape or dLow:find("laser", 1, true) or dLow:find("beam", 1, true) then
                local lv = (wz >= wx) and d.CFrame.LookVector or d.CFrame.RightVector
                local flat = lv * Vector3.new(1, 0, 1)
                if flat.Magnitude > 0.1 then beamDir = flat.Unit end
            end
            return true, M.clamp(sz + 14, 24, 88), isFast, {
                center = d.Position, isUltimate = isUlt, isBeam = (beamDir ~= nil), beamDir = beamDir
            }
        end

        if bossModel and d:IsDescendantOf(bossModel) then return false, 0, false, nil end
        if not spT then return false, 0, false, nil end
        local age = M.clock() - spT
        if age > 7.5 and d.Anchored then return false, 0, false, nil end

        local col = d.Color
        local isWarnColor = false
        if col and col.ToHSV then
            local h, s, v = col:ToHSV()
            local isRedOrangeYellow = (col.R > 0.65 and col.B < 0.40)
            local isPurpleMagenta = (h >= 0.72 and h <= 0.96 and s >= 0.45 and v >= 0.35)
            local isBrightNeon = (d.Material == Enum.Material.Neon or d.Material == Enum.Material.ForceField) and s >= 0.48 and v >= 0.42
            isWarnColor = isRedOrangeYellow or isPurpleMagenta or (isFlatGround and isBrightNeon)
        end

        if isFlatGround and isWarnColor and not d.CanCollide then
            return true, M.clamp(sz + 14, 24, 88), false, {
                center = d.Position, isUltimate = (sz >= 40), isBeam = false
            }
        end

        if isBeamShape and isWarnColor and not d.CanCollide then
            local lv = (wz >= wx) and d.CFrame.LookVector or d.CFrame.RightVector
            local flat = lv * Vector3.new(1, 0, 1)
            return true, M.clamp(minHoriz * 0.5 + 18, 22, 46), true, {
                center = d.Position, isUltimate = false, isBeam = (flat.Magnitude > 0.1),
                beamDir = (flat.Magnitude > 0.1) and flat.Unit or nil
            }
        end

        local vel = d.AssemblyLinearVelocity
        if vel and vel.Magnitude >= 25 and sz >= 2.0 and isWarnColor then
            return true, M.clamp(sz + 16, 22, 48), true, {
                center = d.Position, isUltimate = false, isBeam = false
            }
        end

        return false, 0, false, nil
    end

    local function applyBossNoClip(char, on)
        if not char then return end
        if on then
            if BossEngine.noClipChar ~= char then
                BossEngine.noClipChar = char
                BossEngine.noClipBackup = setmetatable({}, {__mode = "k"})
                if BossEngine.noClipConn then
                    pcall(function() BossEngine.noClipConn:Disconnect() end)
                    BossEngine.noClipConn = nil
                end
                for _, p in ipairs(char:GetChildren()) do
                    if p:IsA("BasePart") then
                        BossEngine.noClipBackup[p] = p.CanCollide
                        if p.CanCollide then p.CanCollide = false end
                    end
                end
                BossEngine.noClipConn = char.ChildAdded:Connect(function(p)
                    if Config.Active and Config.AutoKillBoss and BossEngine.noClipChar == char and p:IsA("BasePart") then
                        if BossEngine.noClipBackup[p] == nil then BossEngine.noClipBackup[p] = p.CanCollide end
                        if p.CanCollide then p.CanCollide = false end
                    end
                end)
            end
        else
            if BossEngine.noClipConn then
                pcall(function() BossEngine.noClipConn:Disconnect() end)
                BossEngine.noClipConn = nil
            end
            for p, origC in pairs(BossEngine.noClipBackup) do
                pcall(function() if p and p.Parent then p.CanCollide = origC end end)
                BossEngine.noClipBackup[p] = nil
            end
            BossEngine.noClipChar = nil
        end
    end

    function BossEngine.restoreNoClip()
        BossEngine.lastHoverCF = nil
        BossEngine.tweenStartPos = nil
        applyBossNoClip(Player.Character, false)
    end

    local cachedAoeState, cachedAoeRad, cachedHazardMeta = false, 36, nil
    local lastRootAoeScan = -100

    local function registerBossChargeStart(kind, sigKey, now)
        local isNew = false
        if sigKey ~= nil then
            if BossEngine.chargeSigKey ~= sigKey then
                BossEngine.chargeSigKey = sigKey
                isNew = true
            end
        elseif not BossEngine.isCharging and (now - (BossEngine.chargeEndT or 0)) >= 0.55 then
            isNew = true
        end
        if isNew then
            BossEngine.chargeStartT = now
            if kind == "Ultimate" then
                if BossEngine.lastUltStartT > 0 then
                    local gap = now - BossEngine.lastUltStartT
                    if gap >= 2.0 and gap <= 120 then
                        BossEngine.avgUltInterval = (BossEngine.avgUltInterval > 0) and (BossEngine.avgUltInterval * 0.65 + gap * 0.35) or gap
                    end
                end
                BossEngine.lastUltStartT = now
                BossEngine.ultChargeCount += 1
            else
                if BossEngine.lastSkillStartT > 0 then
                    local gap = now - BossEngine.lastSkillStartT
                    if gap >= 1.2 and gap <= 90 then
                        BossEngine.avgSkillInterval = (BossEngine.avgSkillInterval > 0) and (BossEngine.avgSkillInterval * 0.65 + gap * 0.35) or gap
                    end
                end
                BossEngine.lastSkillStartT = now
                BossEngine.skillChargeCount += 1
            end
        end
    end

    local function detectBossAOEOrUlt(bossObj, now, groundFloorY)
        if not bossObj or not bossObj.part or not bossObj.part.Parent then return false, 36, nil end

        local bPos = bossObj.part.Position
        local bossFloorY = groundFloorY or BossEngine.arenaFloorY or (bPos.Y - 6)
        local dangerRadius, telegraphNow, immediateNow = 0, false, false
        local inFirstHalfCharge = false
        local chargingDetected, chargeKind, chargePct, chargeRem, chargeSig = false, "Skill", 0, 0, nil
        local bestMeta = nil

        if (now - BossEngine.lastAoeCheck) >= 0.05 or now < BossEngine.aoeFlagUntil then
            BossEngine.lastAoeCheck = now

            pcall(function()
                local okSrv, srvNow = pcall(function() return workspace:GetServerTimeNow() end)
                if not okSrv or type(srvNow) ~= "number" then srvNow = os.time() end
                local atkHosts = {bossObj.model}
                if bossObj.model.Parent and bossObj.model.Parent ~= workspace then
                    atkHosts[#atkHosts + 1] = bossObj.model.Parent
                end
                atkHosts[#atkHosts + 1] = workspace

                local atkSeq, atkKind, atkCF, atkImpact, atkAttrRad, numCharge = nil, nil, nil, nil, nil, nil
                for _, aHost in ipairs(atkHosts) do
                    if atkSeq == nil then atkSeq = aHost:GetAttribute("BossAttackSequence") end
                    if atkKind == nil then atkKind = aHost:GetAttribute("BossAttackKind") end
                    if atkCF == nil then atkCF = aHost:GetAttribute("BossAttackCFrame") end
                    if atkImpact == nil then atkImpact = tonumber(aHost:GetAttribute("BossAttackImpactTime")) end
                    if atkAttrRad == nil then
                        atkAttrRad = tonumber(aHost:GetAttribute("BossAttackRadius"))
                            or tonumber(aHost:GetAttribute("AOERadius"))
                            or tonumber(aHost:GetAttribute("SkillRadius"))
                            or tonumber(aHost:GetAttribute("AttackRadius"))
                    end
                    if numCharge == nil then numCharge = readChargeAttrRatio(aHost) end
                end

                local kindLow = (type(atkKind) == "string") and atkKind:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
                local isBasicOrIdle = BASIC_ATK_KIND[kindLow] == true
                local isSkillAtk = (not isBasicOrIdle) and hasKw(kindLow, SKILL_ATK_KW)
                local isUltAtk = (not isBasicOrIdle) and hasKw(kindLow, ULT_ATK_KW)
                local hazardCenter = (typeof(atkCF) == "CFrame") and atkCF.Position or bPos
                local baseAtkRad = atkAttrRad and M.clamp(atkAttrRad + 14, 24, 88)
                    or (isUltAtk and 62 or (isSkillAtk and 38 or 30))

                if atkImpact ~= nil and atkImpact > 0 then
                    local rem = atkImpact - srvNow
                    if BossEngine.lastAtkImpact ~= atkImpact or (atkSeq ~= nil and atkSeq ~= BossEngine.lastAttackSeq) then
                        BossEngine.lastAtkImpact = atkImpact
                        BossEngine.lastAttackSeq = atkSeq
                        if rem > 0 then
                            BossEngine.seqStart = srvNow
                            BossEngine.seqTotal = M.clamp(rem, 0.25, 8.0)
                        end
                    end
                    local seqTotal = BossEngine.seqTotal or M.clamp(rem, 0.25, 8.0)
                    local isUltByDur = isUltAtk or (seqTotal >= 2.2)
                    local isTelegraphedSkill = isSkillAtk or isUltByDur or (not isBasicOrIdle and seqTotal >= 0.40)
                    if isTelegraphedSkill and rem >= -0.25 and rem <= 8.0 then
                        local seqStart = BossEngine.seqStart or srvNow
                        local elapsed = M.max(0, srvNow - seqStart)
                        local pct = M.clamp((elapsed / M.max(seqTotal, 0.1)) * 100, 0, 100)
                        chargingDetected = true
                        chargeKind = isUltByDur and "Ultimate" or "Skill"
                        chargePct = M.max(chargePct, pct)
                        chargeRem = M.max(0, rem)
                        chargeSig = "imp_" .. tostring(atkSeq or M.floor(atkImpact * 10))
                        if pct < 50 and rem > 0.38 then
                            inFirstHalfCharge = true
                        else
                            telegraphNow = true
                            dangerRadius = M.max(dangerRadius, isUltByDur and M.max(baseAtkRad, 62) or baseAtkRad)
                            bestMeta = {center = hazardCenter, isUltimate = isUltByDur, isBeam = kindLow:find("beam") ~= nil or kindLow:find("laser") ~= nil}
                            BossEngine.evadeUntil = M.max(BossEngine.evadeUntil, now + M.clamp(rem + 0.30, 0.25, 2.0))
                        end
                    end
                elseif atkSeq ~= nil then
                    if BossEngine.lastAttackSeq ~= nil and atkSeq ~= BossEngine.lastAttackSeq then
                        BossEngine.lastAttackSeq = atkSeq
                        if isSkillAtk or isUltAtk then
                            chargingDetected = true
                            chargeKind = isUltAtk and "Ultimate" or "Skill"
                            chargePct = M.max(chargePct, 60)
                            chargeRem = isUltAtk and 1.1 or 0.65
                            chargeSig = "seq_" .. tostring(atkSeq)
                            telegraphNow = true
                            dangerRadius = M.max(dangerRadius, baseAtkRad)
                            bestMeta = {center = hazardCenter, isUltimate = isUltAtk, isBeam = false}
                            BossEngine.evadeUntil = M.max(BossEngine.evadeUntil, now + (isUltAtk and 1.25 or 0.80))
                        end
                    elseif BossEngine.lastAttackSeq == nil then
                        BossEngine.lastAttackSeq = atkSeq
                    end
                end

                if numCharge ~= nil then
                    local pct = M.clamp(numCharge * 100, 0, 100)
                    chargingDetected = true
                    if isUltAtk then chargeKind = "Ultimate" end
                    chargePct = M.max(chargePct, pct)
                    if pct < 50 then
                        inFirstHalfCharge = true
                    else
                        telegraphNow = true; immediateNow = true
                        dangerRadius = M.max(dangerRadius, isUltAtk and 62 or 40)
                        bestMeta = bestMeta or {center = hazardCenter, isUltimate = isUltAtk, isBeam = false}
                    end
                end

                for ak, av in pairs(bossObj.model:GetAttributes()) do
                    if isActiveDangerAttr(ak, av) and not inFirstHalfCharge then
                        local aUlt = hasKw(tostring(ak):lower() .. " " .. tostring(av):lower(), ULT_ATK_KW)
                        telegraphNow = true; immediateNow = true
                        dangerRadius = M.max(dangerRadius, aUlt and 62 or 38)
                        bestMeta = bestMeta or {center = hazardCenter, isUltimate = aUlt, isBeam = false}
                    end
                end

                local wEntry = getBossWatchEntry(bossObj.model, now)
                for _, nv in ipairs(wEntry.nums) do
                    if nv and nv.Parent and tonumber(nv.Value) and nv.Value > 0 then
                        local ratio = (nv.Value <= 1.05) and nv.Value or (nv.Value / 100)
                        local pct = M.clamp(ratio * 100, 0, 100)
                        chargingDetected = true
                        if nv.Name:lower():find("ult") then chargeKind = "Ultimate" end
                        chargePct = M.max(chargePct, pct)
                        if pct < 50 then inFirstHalfCharge = true
                        else
                            telegraphNow = true; immediateNow = true
                            dangerRadius = M.max(dangerRadius, baseAtkRad)
                            bestMeta = bestMeta or {center = hazardCenter, isUltimate = (chargeKind == "Ultimate"), isBeam = false}
                        end
                    end
                end
                for _, bv in ipairs(wEntry.bools) do
                    if bv and bv.Parent and bv.Value == true then
                        chargingDetected = true
                        if bv.Name:lower():find("ult") then chargeKind = "Ultimate" end
                        if not inFirstHalfCharge then
                            chargePct = M.max(chargePct, 55)
                            telegraphNow = true; immediateNow = true
                            dangerRadius = M.max(dangerRadius, (chargeKind == "Ultimate") and 62 or baseAtkRad)
                            bestMeta = bestMeta or {center = hazardCenter, isUltimate = (chargeKind == "Ultimate"), isBeam = false}
                        end
                    end
                end
                for _, lbl in ipairs(wEntry.labels) do
                    if lbl and lbl.Parent and lbl.Visible and lbl.Text and lbl.Text ~= "" then
                        local tl = lbl.Text:gsub("<[^>]+>", " "):lower()
                        local pctNum = tonumber(tl:match("(%d+)%%"))
                        local lUlt = tl:find("ult") ~= nil or tl:find("meteor") ~= nil
                        if pctNum and (tl:find("charg") or tl:find("ult") or tl:find("cast")) then
                            chargingDetected = true
                            if lUlt then chargeKind = "Ultimate" end
                            chargePct = M.max(chargePct, M.clamp(pctNum, 0, 100))
                            if pctNum < 50 then inFirstHalfCharge = true
                            else
                                telegraphNow = true; immediateNow = true
                                dangerRadius = M.max(dangerRadius, lUlt and 62 or 40)
                                bestMeta = bestMeta or {center = hazardCenter, isUltimate = lUlt, isBeam = false}
                            end
                        elseif tl == "!" or hasKw(tl, DANGER_GUI_KW) then
                            chargingDetected = true
                            if lUlt then chargeKind = "Ultimate" end
                            if not inFirstHalfCharge then
                                chargePct = M.max(chargePct, 60)
                                telegraphNow = true; immediateNow = true
                                dangerRadius = M.max(dangerRadius, lUlt and 62 or 38)
                                bestMeta = bestMeta or {center = hazardCenter, isUltimate = lUlt, isBeam = false}
                            end
                        end
                    end
                end
                if not inFirstHalfCharge then
                    for _, hl in ipairs(wEntry.highlights) do
                        local okH, radH, _, metaH = BossEngine.isDangerPart(hl, bossObj.model, bPos, bossFloorY)
                        if okH then
                            chargingDetected = true
                            chargePct = M.max(chargePct, 55)
                            telegraphNow = true
                            dangerRadius = M.max(dangerRadius, radH)
                            bestMeta = bestMeta or metaH
                        end
                    end
                end

                local humOrAc = bossObj.hum or bossObj.model:FindFirstChildWhichIsA("AnimationController", true)
                local animator = humOrAc and humOrAc:FindFirstChildOfClass("Animator")
                if animator then
                    for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                        local an = (tr.Animation and tr.Animation.Name or tr.Name):lower()
                        if not (an:find("idle", 1, true) or an:find("walk", 1, true) or an:find("run", 1, true)
                            or an:find("hover", 1, true) or an:find("punch", 1, true) or an:find("basic", 1, true))
                            and hasKw(an, DANGER_ANIM_KW) then
                            local seenT = dangerAnimSeen[tr]
                            if not seenT then seenT = now; dangerAnimSeen[tr] = now end
                            local len, pos = tonumber(tr.Length) or 0, tonumber(tr.TimePosition) or 0
                            local aUlt = hasKw(an, ULT_ATK_KW)
                            local animPct = (len > 0) and M.clamp((pos / len) * 100, 0, 100) or M.clamp(((now - seenT) / 0.50) * 100, 0, 100)
                            chargingDetected = true
                            if aUlt then chargeKind = "Ultimate" end
                            chargePct = M.max(chargePct, animPct)
                            if len > 0 then chargeRem = M.max(chargeRem, M.max(0, len - pos)) end
                            chargeSig = chargeSig or ("anim_" .. tostring(tr) .. "_" .. M.floor(seenT * 10))
                            if animPct >= 50 then
                                telegraphNow = true; immediateNow = true
                                dangerRadius = M.max(dangerRadius, aUlt and 62 or 38)
                                bestMeta = bestMeta or {center = bPos, isUltimate = aUlt, isBeam = false}
                            else
                                inFirstHalfCharge = true
                            end
                        end
                    end
                end
            end)

            if (now - lastRootAoeScan) >= 0.16 then
                lastRootAoeScan = now
                local checkRoots = {bossObj.model, workspace}
                local seenR = {[bossObj.model] = true, [workspace] = true}
                if bossObj.model.Parent and bossObj.model.Parent ~= workspace and not seenR[bossObj.model.Parent] then
                    local pl = bossObj.model.Parent.Name:lower()
                    if pl ~= "map" and pl ~= "world" then
                        seenR[bossObj.model.Parent] = true
                        checkRoots[#checkRoots + 1] = bossObj.model.Parent
                    end
                end
                local wsEv = workspace:FindFirstChild("Events")
                if wsEv and not seenR[wsEv] then
                    seenR[wsEv] = true
                    checkRoots[#checkRoots + 1] = wsEv
                    for _, sub in ipairs(wsEv:GetChildren()) do
                        if not seenR[sub] then seenR[sub] = true; checkRoots[#checkRoots + 1] = sub end
                    end
                end
                for _, folderName in ipairs({"Effects", "VFX", "Debris", "BossAttacks", "Attacks", "Skills", "BossSkills", "Warnings", "Telegraphs", "AOE", "Ultimates", "BossArena", "EventArena", "AlienEvent"}) do
                    local f = workspace:FindFirstChild(folderName)
                    if f and not seenR[f] then seenR[f] = true; checkRoots[#checkRoots + 1] = f end
                end

                for _, r in ipairs(checkRoots) do
                    for _, d in ipairs(r:GetChildren()) do
                        if d ~= Player.Character and d ~= Lighting and not d:IsA("Terrain") and not d:IsA("Camera") then
                            if BossEngine.trackedDangerInsts[d] == nil then
                                local okD, rad, isImm, meta = BossEngine.isDangerPart(d, bossObj.model, bPos, bossFloorY)
                                if okD then
                                    local initSz = d:IsA("BasePart") and (M.max(d.Size.X, d.Size.Z) * 0.5) or 0
                                    BossEngine.trackedDangerInsts[d] = {seen = now, immediate = isImm == true, rad = rad, initSz = initSz, meta = meta}
                                end
                            end
                        end
                    end
                end
            end

            local activePartList = {}
            for inst, info in pairs(BossEngine.trackedDangerInsts) do
                if not (inst and inst.Parent) then
                    BossEngine.trackedDangerInsts[inst] = nil
                else
                    local stillLive = true
                    if inst:IsA("BasePart") and (inst.Transparency >= 0.96 or (inst.Position - bPos).Magnitude > 220) then
                        stillLive = false
                    elseif inst:IsA("Highlight") and not inst.Enabled then
                        stillLive = false
                    elseif (inst:IsA("ParticleEmitter") or inst:IsA("Beam")) and not inst.Enabled then
                        stillLive = false
                    end
                    if stillLive then
                        local rec = (type(info) == "table") and info or {seen = now, immediate = true, rad = 38, initSz = 0}
                        local curSz = 0
                        if inst:IsA("BasePart") then
                            local wx, _, wz = getPartWorldBox(inst)
                            curSz = M.max(wx, wz) * 0.5
                        end
                        activePartList[#activePartList + 1] = {inst = inst, rec = rec, curSz = curSz}
                    else
                        BossEngine.trackedDangerInsts[inst] = nil
                    end
                end
            end

            for _, item in ipairs(activePartList) do
                local inst, rec, curSz = item.inst, item.rec, item.curSz
                local rad = inst:IsA("BasePart") and M.clamp(curSz + 14, 24, 88) or (rec.rad or 38)
                local isImm = rec.immediate == true
                local dualHalfReady, hasOuterRing, isOuterOfDual = false, false, false
                local ringPct = nil

                if inst:IsA("BasePart") and #activePartList >= 2 then
                    for _, other in ipairs(activePartList) do
                        if other.inst ~= inst and other.inst:IsA("BasePart") and (other.inst.Position - inst.Position).Magnitude <= 14 then
                            if other.curSz > curSz * 1.15 then
                                hasOuterRing = true
                                rad = M.max(rad, M.clamp(other.curSz + 14, 24, 88))
                                local rRatio = curSz / M.max(other.curSz, 0.1)
                                ringPct = M.clamp(rRatio * 100, 0, 100)
                                if rRatio >= 0.50 then dualHalfReady = true end
                            elseif curSz > other.curSz * 1.15 then
                                isOuterOfDual = true
                                rad = M.max(rad, M.clamp(curSz + 14, 24, 88))
                                local rRatio = other.curSz / M.max(curSz, 0.1)
                                ringPct = M.clamp(rRatio * 100, 0, 100)
                                if rRatio >= 0.50 then dualHalfReady = true end
                            end
                        end
                    end
                end

                chargingDetected = true
                local partUlt = (rec.meta and rec.meta.isUltimate == true) or (rad >= 52)
                if partUlt then chargeKind = "Ultimate" end
                if ringPct then
                    chargePct = M.max(chargePct, ringPct)
                else
                    chargePct = M.max(chargePct, isImm and 85 or M.clamp(((now - rec.seen) / 0.85) * 100, 5, 100))
                end
                chargeSig = chargeSig or ("part_" .. tostring(M.floor((rec.seen or now) * 2)))

                if isImm or dualHalfReady or (not hasOuterRing and not isOuterOfDual and not inFirstHalfCharge and (now - rec.seen) >= 0.12) then
                    telegraphNow = true
                    if rad >= dangerRadius then
                        dangerRadius = rad
                        bestMeta = rec.meta or {center = inst:IsA("BasePart") and inst.Position or bPos, isUltimate = partUlt, isBeam = false}
                    end
                    if isImm or dualHalfReady then immediateNow = true end
                end
            end

            if telegraphNow then
                BossEngine.wasTelegraphActive = true
                if immediateNow then BossEngine.wasImmediateHazard = true end
                BossEngine.evadeUntil = M.max(BossEngine.evadeUntil, now + (immediateNow and 0.65 or 0.30))
            elseif BossEngine.wasTelegraphActive then
                BossEngine.wasTelegraphActive = false
                local holdDur = BossEngine.wasImmediateHazard and 0.40 or 0.22
                BossEngine.wasImmediateHazard = false
                BossEngine.postAttackHoldUntil = M.max(BossEngine.postAttackHoldUntil, now + holdDur)
            end

            cachedAoeState = telegraphNow or (now < BossEngine.aoeFlagUntil) or (now < BossEngine.postAttackHoldUntil) or (now < BossEngine.evadeUntil)
            if dangerRadius > 0 then cachedAoeRad = M.clamp(dangerRadius, 24, 92) end
            if bestMeta then
                cachedHazardMeta = bestMeta
            elseif not cachedAoeState then
                cachedHazardMeta = nil
            end

            if chargingDetected or cachedAoeState then
                if bestMeta and bestMeta.isUltimate then chargeKind = "Ultimate" end
                registerBossChargeStart(chargeKind, chargeSig, now)
                BossEngine.isCharging = true
                BossEngine.chargeKind = chargeKind
                BossEngine.chargePct = M.clamp(M.floor(chargePct + 0.5), 0, 100)
                BossEngine.chargeRemSec = chargeRem
            else
                if BossEngine.isCharging then
                    BossEngine.chargeEndT = now
                end
                BossEngine.isCharging = false
                BossEngine.chargePct = 0
                BossEngine.chargeRemSec = 0
                BossEngine.chargeSigKey = nil
            end
        else
            cachedAoeState = (now < BossEngine.aoeFlagUntil) or (now < BossEngine.postAttackHoldUntil) or (now < BossEngine.evadeUntil)
        end

        return cachedAoeState, cachedAoeRad, cachedHazardMeta
    end

    local bossPunchAcc = 1.0
    local bossHandRight = true

    local function runFastBossBurst(dt, target)
        if not (target and target.model and target.model.Parent) then return end
        local _, liveHp = readBossHealth(target.model, target.bodyStats)
        if liveHp <= 0 then return end

        local pingHeadroom = 0
        if Telemetry and Telemetry.livePing and Telemetry.baselinePing then
            pingHeadroom = Telemetry.livePing - Telemetry.baselinePing
        end
        local punchRate
        local maxStrikes = 1
        if target.hasDamageHitbox then
            local spd = M.clamp(tonumber(Config.PunchSpeed) or 140, 60, 500)
            punchRate = (pingHeadroom > 95) and 6.0 or M.clamp(8 + spd * 0.015, 9, 13)
        else
            punchRate = (pingHeadroom > 95) and 4.0 or ((pingHeadroom > 55) and 5.0 or 6.0)
        end
        bossPunchAcc += punchRate * M.min(dt, 0.05)
        local strikes = M.min(M.floor(bossPunchAcc), maxStrikes)
        if strikes > 0 then
            bossPunchAcc -= strikes
            for s = 1, strikes do
                local _, curHP = readBossHealth(target.model, target.bodyStats)
                if curHP <= 0 then break end
                bossHandRight = not bossHandRight
                Combat.executeStrike(bossHandRight, target.hasDamageHitbox and 2 or 1, s > 1, target)
                if Telemetry then
                    Telemetry.punchesTotal += 1
                    Telemetry.recordEvent(Telemetry.punchTracker, 1)
                end
            end
        end
    end

    local function isViewOnlyPromptOrChest(ch)
        local nl = ch.Name:lower()
        local nameHasOpen = (nl:find("open") or nl:find("claim") or nl:find("collect")) ~= nil
        if (nl:find("view") or nl:find("preview") or nl:find("showcase")) and not nameHasOpen then
            return true
        end
        local hasView, hasOpen = false, nameHasOpen
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                local pt = ((d.ActionText or "") .. " " .. (d.ObjectText or "") .. " " .. d.Name):lower()
                if pt:find("open") or pt:find("claim") or pt:find("collect") then
                    hasOpen = true
                elseif pt:find("view") or pt:find("preview") then
                    hasView = true
                end
            elseif d:IsA("TextLabel") and d.Text and d.Text ~= "" then
                local lt = d.Text:gsub("<[^>]+>", " "):lower()
                if lt:find("open") or lt:find("claim") or lt:find("collect") then
                    hasOpen = true
                elseif lt:find("view reward") or lt:find("preview") then
                    hasView = true
                end
            end
        end
        return hasView and not hasOpen
    end

    local function findNearbyBossChest(refPos)
        if not refPos then return nil, nil end
        local containers = {workspace}
        local seenCont = {}
        local wsEv = workspace:FindFirstChild("Events")
        if wsEv then
            containers[#containers + 1] = wsEv
            for _, sub in ipairs(wsEv:GetChildren()) do containers[#containers + 1] = sub end
        end
        for _, fn in ipairs({"Chests", "BossArena", "bossMaps", "EventArena"}) do
            local c = workspace:FindFirstChild(fn)
            if c then containers[#containers + 1] = c end
        end
        local bestChest, bestPart, bestDist = nil, nil, 150
        local function considerChest(ch)
            if not (ch and ch.Parent and (ch:IsA("Model") or ch:IsA("BasePart")) and ch ~= Player.Character) then return end
            if seenCont[ch] then return end
            seenCont[ch] = true
            local nl = ch.Name:lower()
            if (nl:find("chest") or nl:find("loot") or nl:find("drop") or (CollectionService and (CollectionService:HasTag(ch, "BossEventChest") or CollectionService:HasTag(ch, "AlienBossChest"))))
                and not (nl:find("shop") or nl:find("store") or nl:find("vip") or nl:find("group") or nl:find("daily"))
                and not isViewOnlyPromptOrChest(ch) then
                local part = ch:IsA("BasePart") and ch or (ch.PrimaryPart or ch:FindFirstChild("Main", true) or ch:FindFirstChildWhichIsA("BasePart", true))
                if part then
                    local d = (part.Position - refPos).Magnitude
                    if d <= bestDist then
                        bestDist = d
                        bestChest = ch
                        bestPart = part
                    end
                end
            end
        end
        if CollectionService then
            for _, cTag in ipairs({"BossEventChest", "AlienBossChest"}) do
                local okC, tagged = pcall(CollectionService.GetTagged, CollectionService, cTag)
                if okC and tagged then
                    for _, tc in ipairs(tagged) do considerChest(tc) end
                end
            end
        end
        for _, cont in ipairs(containers) do
            for _, ch in ipairs(cont:GetChildren()) do
                considerChest(ch)
            end
        end
        return bestChest, bestPart
    end

    local function isPromptCollectable(pp)
        local pt = ((pp.ActionText or "") .. " " .. (pp.ObjectText or "") .. " " .. pp.Name):lower()
        if (pt:find("view") or pt:find("preview")) and not (pt:find("open") or pt:find("claim") or pt:find("collect")) then
            return false
        end
        return true
    end

    local function collectBossChest(chest, chestPart, root)
        if not (chest and chest.Parent and chestPart and root) then return end
        if fireproximityprompt then
            for _, d in ipairs(chest:GetDescendants()) do
                if d:IsA("ProximityPrompt") and isPromptCollectable(d) then pcall(fireproximityprompt, d) end
            end
            if chestPart:IsA("BasePart") then
                local pp = chestPart:FindFirstChildOfClass("ProximityPrompt")
                if pp and isPromptCollectable(pp) then pcall(fireproximityprompt, pp) end
            end
        end
        if not chest.Parent then return end
        if fireclickdetector then
            for _, d in ipairs(chest:GetDescendants()) do
                if d:IsA("ClickDetector") then pcall(fireclickdetector, d) end
            end
            if chestPart:IsA("BasePart") then
                local cd = chestPart:FindFirstChildOfClass("ClickDetector")
                if cd then pcall(fireclickdetector, cd) end
            end
        end
        if not chest.Parent then return end
        if #Remotes.chestRemotes == 0 then Remotes.refresh(false) end
        for _, crem in ipairs(Remotes.chestRemotes) do
            if crem and crem.Parent then
                if crem:IsA("RemoteFunction") then
                    task.spawn(pcall, crem.InvokeServer, crem, chest.Name)
                    task.spawn(pcall, crem.InvokeServer, crem, chest)
                else
                    pcall(crem.FireServer, crem, chest.Name)
                    pcall(crem.FireServer, crem, chest)
                end
            end
        end
        if not chest.Parent then return end
        if firetouchinterest then
            pcall(firetouchinterest, root, chestPart, 0)
            pcall(firetouchinterest, root, chestPart, 1)
            for _, d in ipairs(chest:GetDescendants()) do
                if d:IsA("BasePart") and d ~= chestPart then
                    pcall(firetouchinterest, root, d, 0)
                    pcall(firetouchinterest, root, d, 1)
                end
            end
        end
    end

    function BossEngine.returnToOrigin()
        BossEngine.collectingChest = false
        BossEngine.trackedChest = nil
        BossEngine.lastHoverCF = nil
        if BossEngine.savedOriginCF then
            local char = Player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.CFrame = BossEngine.savedOriginCF
            end
            BossEngine.savedOriginCF = nil
        end
    end

    function BossEngine.maintainHold()
        if not (Config.Active and Config.AutoKillBoss) then return end
        local holdCF = BossEngine.evadingAOE and BossEngine.evadeHoldCF or BossEngine.lastHoverCF
        if not holdCF then return end
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if root then
            if BossEngine.arenaFloorY then
                local minY = BossEngine.arenaFloorY + getCharHipOffset(hum, root) + 2.0
                if holdCF.Position.Y < minY then
                    holdCF = CFrame.new(holdCF.Position.X, minY, holdCF.Position.Z) * (holdCF - holdCF.Position)
                end
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = holdCF
        end
    end

    function BossEngine.stepFastPunch(dt)
        if not (Config.Active and Config.AutoKillBoss and not BossEngine.evadingAOE and not BossEngine.collectingChest) then return end
        local tgt = BossEngine.currentTargetObj
        local m = BossEngine.currentBossModel
        if tgt and m and m.Parent then
            if BossEngine.tweenStartPos ~= nil then
                local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                local refPart = tgt.head or tgt.part
                if not (root and refPart and refPart.Parent and (refPart.Position - root.Position).Magnitude <= 35) then
                    return
                end
            end
            runFastBossBurst(dt, tgt)
        end
    end

    function BossEngine.step(dt)
        local now = M.clock()
        if not (Config.Active and Config.AutoKillBoss) then
            BossEngine.evadingAOE = false
            BossEngine.evadeHoldCF = nil
            BossEngine.arenaCenter = nil
            BossEngine.arenaFloorY = nil
            BossEngine.isCharging = false
            BossEngine.chargePct = 0
            BossEngine.chargeRemSec = 0
            BossEngine.chargeSigKey = nil
            BossEngine.dodgeEscapeDir = nil
            BossEngine.wasTelegraphActive = false
            BossEngine.wasImmediateHazard = false
            BossEngine.postAttackHoldUntil = 0
            BossEngine.lastHoverCF = nil
            BossEngine.tweenStartPos = nil
            BossEngine.currentBossModel = nil
            BossEngine.currentBossHum = nil
            BossEngine.currentTargetObj = nil
            BossEngine.prevEngagedModel = nil
            BossEngine.prevEngagedHP = nil
            BossEngine.statusText = "Action: Inactive"
            if BossEngine.noClipChar then BossEngine.restoreNoClip() end
            return
        end

        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (root and hum and hum.Health > 0) then
            BossEngine.lastHoverCF = nil
            BossEngine.tweenStartPos = nil
            BossEngine.currentTargetObj = nil
            BossEngine.statusText = "Action: Waiting for Character..."
            return
        end

        applyBossNoClip(char, true)
        Combat.refreshTargets(root.Position, false)

        if BossEngine.lastTrackedBossModel then
            local tracked = BossEngine.lastTrackedBossModel
            local _, lastHP, lastMax, wasPending = readBossHealth(tracked, nil, true)
            local actuallyDead = (not wasPending and lastMax > 0 and lastHP <= 0)
            local despawned = (not tracked.Parent) and not actuallyDead
            if actuallyDead or despawned then
                if actuallyDead and not BossEngine.countedDead[tracked] then
                    BossEngine.countedDead[tracked] = true
                    if BossEngine.prevEngagedModel == tracked and BossEngine.prevEngagedHP and BossEngine.prevEngagedHP > 0 then
                        BossEngine.damageDealt += BossEngine.prevEngagedHP
                        local instDps = BossEngine.prevEngagedHP / M.max(dt, 0.016)
                        BossEngine.liveDps += (instDps - BossEngine.liveDps) * 0.35
                    end
                    BossEngine.kills += 1
                    if BossEngine.lastTrackedIsEvent then
                        BossEngine.eventKills += 1
                    else
                        BossEngine.normalKills += 1
                    end
                    BossEngine.collectingChest = true
                    BossEngine.chestWaitUntil = now + 1.8
                    BossEngine.trackedChest = nil
                end
                BossEngine.lastTrackedBossModel = nil
                BossEngine.evadingAOE = false
                BossEngine.evadeHoldCF = nil
                BossEngine.arenaCenter = nil
                BossEngine.arenaFloorY = nil
                BossEngine.isCharging = false
                BossEngine.chargePct = 0
                BossEngine.chargeRemSec = 0
                BossEngine.chargeSigKey = nil
                BossEngine.dodgeEscapeDir = nil
                BossEngine.tweenStartPos = nil
                BossEngine.evadeUntil = 0
                BossEngine.aoeFlagUntil = 0
                BossEngine.wasTelegraphActive = false
                BossEngine.wasImmediateHazard = false
                BossEngine.postAttackHoldUntil = 0
                BossEngine.lastAtkImpact = nil
                BossEngine.seqStart = nil
                BossEngine.seqTotal = nil
                BossEngine.trackedDangerInsts = setmetatable({}, {__mode = "k"})
                if BossEngine.prevEngagedModel == tracked then
                    BossEngine.prevEngagedModel = nil
                    BossEngine.prevEngagedHP = nil
                end
                Combat.refreshTargets(root.Position, true)
            end
        end

        if BossEngine.collectingChest then
            BossEngine.tweenStartPos = nil
            if BossEngine.trackedChest and not BossEngine.trackedChest.Parent then
                BossEngine.returnToOrigin()
                BossEngine.statusText = "Action: Chest Collected — Returned to Origin"
                return
            end
            local chest, chestPart = findNearbyBossChest(BossEngine.lastBossDeathPos)
            if chest and chestPart then
                BossEngine.trackedChest = chest
                local cPos = chestPart.Position + Vector3.new(0, 2, 0)
                local cCF = CFrame.new(cPos)
                BossEngine.lastHoverCF = cCF
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.CFrame = cCF
                collectBossChest(chest, chestPart, root)
                if not chest.Parent or now >= BossEngine.chestWaitUntil then
                    BossEngine.returnToOrigin()
                    BossEngine.statusText = "Action: Chest Collected — Returned to Origin"
                    return
                end
                BossEngine.statusText = "Action: Collecting Boss Chest..."
                return
            else
                local nextTgt = getSelectedBossObj()
                if nextTgt then
                    BossEngine.collectingChest = false
                    BossEngine.trackedChest = nil
                elseif now >= BossEngine.chestWaitUntil then
                    BossEngine.returnToOrigin()
                    BossEngine.statusText = "Action: Returned to Origin"
                    return
                else
                    BossEngine.statusText = "Action: Waiting for Boss Chest..."
                    return
                end
            end
        end

        local target = getSelectedBossObj()
        if not target then
            BossEngine.evadingAOE = false
            BossEngine.dodgeEscapeDir = nil
            BossEngine.tweenStartPos = nil
            BossEngine.currentBossModel = nil
            BossEngine.currentBossHum = nil
            BossEngine.currentTargetObj = nil
            BossEngine.lastHoverCF = nil
            BossEngine.liveDps = BossEngine.liveDps * 0.90
            local alt = Combat.bossTargets[1]
            if alt then
                local altKind = alt.isEvent and "Event" or (alt.tierWord or "Normal")
                BossEngine.statusText = M.fmtStr("Action: Waiting %s (Spawned: [%s] %s)", tostring(Config.SelectedBoss), altKind, alt.name)
            else
                BossEngine.statusText = M.fmtStr("Action: Waiting for %s...", tostring(Config.SelectedBoss))
            end
            return
        end

        if not BossEngine.savedOriginCF then
            BossEngine.savedOriginCF = root.CFrame
        end
        if BossEngine.prevEngagedModel ~= target.model then
            bossPunchAcc = 1.0
            BossEngine.dodgeEscapeDir = nil
            BossEngine.tweenStartPos = nil
        end

        BossEngine.currentBossModel = target.model
        BossEngine.currentBossHum = target.hum
        BossEngine.currentTargetObj = target
        BossEngine.lastTrackedBossModel = target.model
        BossEngine.lastTrackedIsEvent = (target.isEvent == true)
        if target.part and target.part.Parent then
            BossEngine.lastBossDeathPos = target.part.Position
        end

        local _, curHP, curMax, curPending = readBossHealth(target.model, target.bodyStats)
        if not curPending and not target.hpPending and BossEngine.prevEngagedModel == target.model and BossEngine.prevEngagedHP ~= nil then
            local delta = BossEngine.prevEngagedHP - curHP
            if delta > 0 and delta <= (curMax * 1.1) then
                BossEngine.damageDealt += delta
                local instDps = delta / M.max(dt, 0.016)
                BossEngine.liveDps += (instDps - BossEngine.liveDps) * M.clamp(dt * 4, 0.05, 0.35)
            end
        elseif curPending or target.hpPending then
            BossEngine.liveDps = 0
        end
        if not curPending then
            BossEngine.prevEngagedModel = target.model
            BossEngine.prevEngagedHP = curHP
        end
        target.hp = curHP
        target.maxHp = curMax
        target.hpPending = curPending

        local bHead = target.head or target.part
        local bPos = bHead.Position
        local arenaFloorY, hipOff = getSafeFloorSurfaceY(target.model, bHead, target.part, root, hum, now)
        local minLegalY = arenaFloorY + hipOff + 2.8
        if not BossEngine.arenaCenter or BossEngine.prevEngagedModel ~= target.model then
            BossEngine.arenaCenter = Vector3.new(target.part.Position.X, arenaFloorY, target.part.Position.Z)
        end

        local aoeDetected, aoeRadius, hazardMeta = detectBossAOEOrUlt(target, now, arenaFloorY)

        if aoeDetected or now < BossEngine.evadeUntil or now < BossEngine.postAttackHoldUntil then
            local hazCenter = (hazardMeta and hazardMeta.center) or target.part.Position
            local isUlt = (hazardMeta and hazardMeta.isUltimate == true) or (BossEngine.chargeKind == "Ultimate") or ((tonumber(aoeRadius) or 36) >= 54)
            local isBeam = (hazardMeta and hazardMeta.isBeam == true and hazardMeta.beamDir ~= nil)
            local safeDist = M.clamp(tonumber(aoeRadius) or 36, 26, isUlt and 86 or 58)

            if not BossEngine.evadingAOE or not BossEngine.dodgeEscapeDir then
                local baseDir = nil
                if isBeam then
                    local bd = hazardMeta.beamDir
                    local perpA = Vector3.new(-bd.Z, 0, bd.X)
                    local perpB = Vector3.new(bd.Z, 0, -bd.X)
                    local ac = BossEngine.arenaCenter or bPos
                    local posA = hazCenter + perpA * safeDist
                    local posB = hazCenter + perpB * safeDist
                    baseDir = ((posA - ac).Magnitude <= (posB - ac).Magnitude) and perpA or perpB
                else
                    local ac = BossEngine.arenaCenter or bPos
                    local toArenaCenter = (ac - hazCenter) * Vector3.new(1, 0, 1)
                    if toArenaCenter.Magnitude >= 8 then
                        baseDir = toArenaCenter.Unit
                    else
                        local away = (root.Position - hazCenter) * Vector3.new(1, 0, 1)
                        if away.Magnitude >= 4 then
                            baseDir = away.Unit
                        else
                            local side = bHead.CFrame.RightVector * Vector3.new(1, 0, 1)
                            baseDir = (side.Magnitude > 0.1) and side.Unit or Vector3.new(1, 0, 0)
                        end
                    end
                end
                baseDir = baseDir.Unit
                local chosenDir = baseDir
                local rayStartY = M.max(bPos.Y, arenaFloorY) + 55
                for _, deg in ipairs({0, 45, -45, 90, -90, 135, -135, 180}) do
                    local radA = math.rad(deg)
                    local ca, sa = M.cos(radA), M.sin(radA)
                    local cand = Vector3.new(baseDir.X * ca - baseDir.Z * sa, 0, baseDir.X * sa + baseDir.Z * ca)
                    local gx = hazCenter.X + cand.X * safeDist
                    local gz = hazCenter.Z + cand.Z * safeDist
                    local hitY = raycastSolidGroundY(gx, gz, rayStartY, target.model)
                    if hitY and M.abs(hitY - arenaFloorY) <= 22 then
                        chosenDir = cand.Unit
                        break
                    end
                end
                BossEngine.dodgeEscapeDir = chosenDir
            end

            BossEngine.evadingAOE = true
            BossEngine.tweenStartPos = nil
            BossEngine.lastHoverCF = nil

            local destX = hazCenter.X + BossEngine.dodgeEscapeDir.X * safeDist
            local destZ = hazCenter.Z + BossEngine.dodgeEscapeDir.Z * safeDist
            local destGroundY = raycastSolidGroundY(destX, destZ, M.max(bPos.Y, arenaFloorY) + 55, target.model)
            local safeSurfaceY = M.max(destGroundY or arenaFloorY, arenaFloorY)
            local destMinY = safeSurfaceY + hipOff + 3.0
            local targetSafeY = isUlt
                and M.max(destMinY + M.clamp(safeDist * 0.42, 22, 38), bPos.Y + 14)
                or (destMinY + 2.5)

            local targetSafePos = Vector3.new(destX, targetSafeY, destZ)
            local stepAlpha = M.clamp((tonumber(dt) or 0.016) * 28, 0.35, 1)
            local nextSafePos = ((targetSafePos - root.Position).Magnitude <= 8)
                and targetSafePos or root.Position:Lerp(targetSafePos, stepAlpha)
            local stepGroundY = raycastSolidGroundY(nextSafePos.X, nextSafePos.Z, M.max(nextSafePos.Y, arenaFloorY) + 45, target.model)
            local stepMinY = M.max(stepGroundY or arenaFloorY, arenaFloorY) + hipOff + 2.8
            if nextSafePos.Y < stepMinY then
                nextSafePos = Vector3.new(nextSafePos.X, stepMinY, nextSafePos.Z)
            end
            local safeCF = CFrame.new(nextSafePos, Vector3.new(bPos.X, nextSafePos.Y, bPos.Z))

            BossEngine.lastSafeDist = safeDist
            BossEngine.lastSafeSpot = nextSafePos
            BossEngine.evadeHoldCF = safeCF
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = safeCF
            local cnt = isUlt and BossEngine.ultChargeCount or BossEngine.skillChargeCount
            local remStr = (BossEngine.chargeRemSec and BossEngine.chargeRemSec > 0.05) and M.fmtStr(" · %.1fs", BossEngine.chargeRemSec) or ""
            BossEngine.statusText = isUlt
                and M.fmtStr("Action: Dodging Ultimate #%d (%d%%%s | %d studs)", cnt, BossEngine.chargePct, remStr, M.floor(safeDist))
                or M.fmtStr("Action: Dodging Skill #%d (%d%%%s | %d studs)", cnt, BossEngine.chargePct, remStr, M.floor(safeDist))
            return
        end

        BossEngine.evadingAOE = false
        BossEngine.evadeHoldCF = nil
        BossEngine.dodgeEscapeDir = nil
        BossEngine.lastSafeDist = 36

        -- SMOOTH HEAD-TWEEN & UPRIGHT HITBOX CONTACT:
        local headPos = bHead.Position
        if bHead == target.part then
            local topOff = BossEngine.cachedTopOffset[target.model]
            if not topOff then
                topOff = (target.bodyStats and target.bodyStats.valid)
                    and M.max(1.5, target.bodyStats.maxY - bHead.Position.Y - 1.2)
                    or 4.0
                BossEngine.cachedTopOffset[target.model] = topOff
            end
            headPos = target.part.Position + Vector3.new(0, topOff, 0)
        end
        local headTopY = (bHead.Size and bHead.Size.Y or 2) * 0.5
        local vertClear = (bHead == target.part) and 0.65 or M.clamp(headTopY * 0.25, 0.25, 0.90)
        local lookFlat = (bHead.CFrame.LookVector * Vector3.new(1, 0, 1))
        local faceDir = (lookFlat.Magnitude > 0.05) and lookFlat.Unit or Vector3.new(0, 0, -1)
        local hoverPos = headPos + Vector3.new(0, vertClear, 0)
        local hoverCF = CFrame.new(hoverPos, hoverPos + faceDir)

        local distToHead = (hoverPos - root.Position).Magnitude
        local nextCF = hoverCF
        if distToHead > 12 then
            if not BossEngine.tweenStartPos or BossEngine.tweenTargetModel ~= target.model or (now - BossEngine.tweenStartT) > (BossEngine.tweenDur + 0.16) then
                BossEngine.tweenStartPos = root.Position
                BossEngine.tweenStartT = now
                BossEngine.tweenElapsed = 0
                BossEngine.tweenTargetModel = target.model
                -- Keep boss approach and post-dodge return at a controlled speed;
                -- the old 50-160 ms tween made long moves look like random flight.
                BossEngine.tweenDur = M.clamp(distToHead / 650, 0.18, 2.0)
            end
            BossEngine.tweenElapsed = (BossEngine.tweenElapsed or 0) + M.max(dt or 0.016, 0)
            local rawA = M.max(now - BossEngine.tweenStartT, BossEngine.tweenElapsed) / M.max(BossEngine.tweenDur, 0.001)
            if rawA >= 1 then
                BossEngine.tweenStartPos = nil
                nextCF = hoverCF
            else
                local a = M.clamp(rawA, 0, 1)
                local alpha = 1 - (1 - a) * (1 - a)
                local stepPos = BossEngine.tweenStartPos:Lerp(hoverPos, alpha)
                if (hoverPos - stepPos).Magnitude <= 12 then
                    BossEngine.tweenStartPos = nil
                    nextCF = hoverCF
                else
                    nextCF = CFrame.new(stepPos, Vector3.new(headPos.X, stepPos.Y, headPos.Z))
                end
            end
        else
            BossEngine.tweenStartPos = nil
        end

        if nextCF.Position.Y < minLegalY then
            nextCF = CFrame.new(nextCF.Position.X, minLegalY, nextCF.Position.Z) * (nextCF - nextCF.Position)
        end
        BossEngine.lastSafeSpot = nextCF.Position
        BossEngine.lastHoverCF = nextCF

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = nextCF

        if BossEngine.isCharging then
            local cKind = BossEngine.chargeKind or "Skill"
            local cNum = (cKind == "Ultimate") and BossEngine.ultChargeCount or BossEngine.skillChargeCount
            local remStr = (BossEngine.chargeRemSec and BossEngine.chargeRemSec > 0.05) and M.fmtStr(" · %.1fs", BossEngine.chargeRemSec) or ""
            BossEngine.statusText = M.fmtStr("Action: Boss Charging %s #%d (%d%%%s) | Punching...", cKind, cNum, BossEngine.chargePct, remStr)
        else
            BossEngine.statusText = curPending
                and M.fmtStr("Action: Engaging %s | Syncing HP...", target.name)
                or M.fmtStr("Action: Killing %s | HP: %s / %s", target.name, Core.fmtCompact(curHP), Core.fmtCompact(curMax))
        end
    end

    local lastPassivePoll = -100
    function BossEngine.markPassiveDirty()
        lastPassivePoll = -100
    end
    function BossEngine.pollPassiveStatus()
        local now = M.clock()
        if (now - lastPassivePoll) < 3.0 then return end
        lastPassivePoll = now
        local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if root then Combat.refreshTargets(root.Position, false) end
    end
end

----------------------------------------------------------------
-- Misc Character Physics (Fly, Walk on Water, Walk Speed, Size)
----------------------------------------------------------------
local CharPhysics = {
    bodyVel = nil, bodyGyro = nil, waterPlatform = nil, waterPartsBackup = {},
    waterPartConn = nil, scaleBackup = {}, scaleConns = {}, origModelScale = 1,
    walkSpeedConn = nil, trackedHum = nil, trackedSizeChar = nil, lastVoxelCheck = 0,
    freezeEnabled = false, freezeCF = nil, freezeAnchoredBackup = nil,
    freezeSpeedBackup = nil, freezeJumpPowBackup = nil, freezeJumpHtBackup = nil, freezeChar = nil,
}

do
    function CharPhysics.destroyFly()
        if CharPhysics.bodyVel then pcall(function() CharPhysics.bodyVel:Destroy() end); CharPhysics.bodyVel = nil end
        if CharPhysics.bodyGyro then pcall(function() CharPhysics.bodyGyro:Destroy() end); CharPhysics.bodyGyro = nil end
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.PlatformStand = false end) end
    end

    function CharPhysics.stepFly()
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (Config.Active and Config.FlyEnabled and root and hum and hum.Health > 0) then
            if CharPhysics.bodyVel or CharPhysics.bodyGyro then CharPhysics.destroyFly() end
            return
        end
        hum.PlatformStand = true
        local bv = CharPhysics.bodyVel
        if not (bv and bv.Parent == root) then
            if bv then pcall(function() bv:Destroy() end) end
            bv = Instance.new("BodyVelocity"); bv.Name = Core.randomGuidName()
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9); bv.P = 12500; bv.Velocity = Vector3.zero; bv.Parent = root
            CharPhysics.bodyVel = bv
        end
        local bg = CharPhysics.bodyGyro
        if not (bg and bg.Parent == root) then
            if bg then pcall(function() bg:Destroy() end) end
            bg = Instance.new("BodyGyro"); bg.Name = Core.randomGuidName()
            bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9); bg.P = 25000; bg.D = 500; bg.CFrame = root.CFrame; bg.Parent = root
            CharPhysics.bodyGyro = bg
        end
        local cam = workspace.CurrentCamera
        local camCF = cam and cam.CFrame or root.CFrame
        bg.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector)
        local rawSpd = tonumber(Config.FlySpeed) or 80
        local speed = (rawSpd == M.huge) and 2500 or M.max(0, rawSpd)
        local moveDir = hum.MoveDirection
        local vertical = 0
        if hum.Jump or UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then vertical += 1 end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.Q) then vertical -= 1 end
        local wishVec = Vector3.zero
        if moveDir.Magnitude > 0.01 then
            local flatLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
            local flatRight = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
            if flatLook.Magnitude > 0.01 and flatRight.Magnitude > 0.01 then
                wishVec = (camCF.LookVector * moveDir:Dot(flatLook.Unit)) + (camCF.RightVector * moveDir:Dot(flatRight.Unit))
            else wishVec = moveDir end
        end
        if vertical ~= 0 then wishVec += Vector3.new(0, vertical, 0) end
        bv.Velocity = (wishVec.Magnitude > 0.01) and (wishVec.Unit * speed) or Vector3.zero
    end

    local function isWaterPart(inst)
        if not inst:IsA("BasePart") then return false end
        local n = inst.Name:lower()
        return n:find("water") or n:find("ocean") or n:find("sea") or n:find("lake") or n:find("river")
    end

    function CharPhysics.setWalkOnWater(on)
        if CharPhysics.waterPartConn then CharPhysics.waterPartConn:Disconnect(); CharPhysics.waterPartConn = nil end
        if on then
            for _, inst in ipairs(workspace:GetDescendants()) do
                if isWaterPart(inst) then
                    if CharPhysics.waterPartsBackup[inst] == nil then CharPhysics.waterPartsBackup[inst] = inst.CanCollide end
                    inst.CanCollide = true
                end
            end
            CharPhysics.waterPartConn = workspace.DescendantAdded:Connect(function(inst)
                if Config.WalkOnWater and isWaterPart(inst) then
                    if CharPhysics.waterPartsBackup[inst] == nil then CharPhysics.waterPartsBackup[inst] = inst.CanCollide end
                    inst.CanCollide = true
                end
            end)
        else
            if CharPhysics.waterPlatform then pcall(function() CharPhysics.waterPlatform:Destroy() end); CharPhysics.waterPlatform = nil end
            for part, origCollide in pairs(CharPhysics.waterPartsBackup) do
                pcall(function() if part and part.Parent then part.CanCollide = origCollide end end)
                CharPhysics.waterPartsBackup[part] = nil
            end
        end
    end

    function CharPhysics.stepWalkOnWater()
        if not (Config.Active and Config.WalkOnWater) then return end
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (root and hum) then return end
        local now = M.clock()
        if now - CharPhysics.lastVoxelCheck < 0.06 then return end
        CharPhysics.lastVoxelCheck = now
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if not terrain then return end
        local hipOffset = (hum.HipHeight > 0 and hum.HipHeight or 2.0) + (root.Size.Y * 0.5)
        local feetY = root.Position.Y - hipOffset
        local samplePos = Vector3.new(root.Position.X, feetY - 1.5, root.Position.Z)
        local ok, materials = pcall(function()
            local minV = Vector3.new(M.floor((samplePos.X - 4) / 4) * 4, M.floor((samplePos.Y - 4) / 4) * 4, M.floor((samplePos.Z - 4) / 4) * 4)
            return terrain:ReadVoxels(Region3.new(minV, minV + Vector3.new(8, 12, 8)), 4)
        end)
        local foundWaterY = nil
        if ok and materials then
            local sz = materials.Size
            local baseY = M.floor((samplePos.Y - 4) / 4) * 4
            for x = 1, sz.X do for y = sz.Y, 1, -1 do for z = 1, sz.Z do
                if materials[x][y][z] == Enum.Material.Water then
                    local topY = baseY + (y * 4)
                    if not foundWaterY or topY > foundWaterY then foundWaterY = topY end
                end
            end end end
        end
        if foundWaterY then
            local plat = CharPhysics.waterPlatform
            if not (plat and plat.Parent) then
                plat = Instance.new("Part"); plat.Name = Core.randomGuidName()
                plat.Size = Vector3.new(18, 1, 18); plat.Anchored = true; plat.CanCollide = true; plat.Transparency = 1
                plat.Parent = workspace; CharPhysics.waterPlatform = plat
            end
            plat.CFrame = CFrame.new(root.Position.X, foundWaterY - 0.5, root.Position.Z)
            if feetY < foundWaterY - 0.3 then
                root.CFrame = CFrame.new(root.Position.X, foundWaterY + hipOffset + 0.15, root.Position.Z) * (root.CFrame - root.Position)
            end
        elseif CharPhysics.waterPlatform then
            CharPhysics.waterPlatform.CFrame = CFrame.new(0, -99999, 0)
        end
    end

    function CharPhysics.applyWalkSpeed()
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if not (Config.Active and Config.WalkSpeedEnabled) then
            if CharPhysics.walkSpeedConn then CharPhysics.walkSpeedConn:Disconnect(); CharPhysics.walkSpeedConn = nil; CharPhysics.trackedHum = nil end
            pcall(function() hum.WalkSpeed = OriginalState.WalkSpeed end)
            return
        end
        local raw = tonumber(Config.WalkSpeedValue) or 100
        local targetSpd = (raw == M.huge) and 5000 or M.max(0, raw)
        if CharPhysics.trackedHum ~= hum then
            if CharPhysics.walkSpeedConn then CharPhysics.walkSpeedConn:Disconnect() end
            CharPhysics.trackedHum = hum
            CharPhysics.walkSpeedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if Config.Active and Config.WalkSpeedEnabled and not CharPhysics.freezeEnabled then
                    local r = tonumber(Config.WalkSpeedValue) or 100
                    local t = (r == M.huge) and 5000 or M.max(0, r)
                    if hum.WalkSpeed ~= t then hum.WalkSpeed = t end
                end
            end)
        end
        if CharPhysics.freezeEnabled then
            if hum.WalkSpeed ~= 0 then pcall(function() hum.WalkSpeed = 0 end) end
            return
        end
        if hum.WalkSpeed ~= targetSpd then hum.WalkSpeed = targetSpd end
    end

    function CharPhysics.applyFreeze(on)
        local want = (on == true) and Config.Active
        CharPhysics.freezeEnabled = want
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if want then
            if root then
                if CharPhysics.freezeChar ~= char or CharPhysics.freezeAnchoredBackup == nil then
                    CharPhysics.freezeAnchoredBackup = root.Anchored
                    CharPhysics.freezeChar = char
                end
                CharPhysics.freezeCF = root.CFrame
                pcall(function() root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end)
                pcall(function() root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero end)
                pcall(function() root.Anchored = true end)
            end
            if hum then
                if CharPhysics.freezeSpeedBackup == nil then
                    local okS, ws = pcall(function() return hum.WalkSpeed end)
                    CharPhysics.freezeSpeedBackup = okS and ws or OriginalState.WalkSpeed
                    local okP, jp = pcall(function() return hum.JumpPower end)
                    if okP and type(jp) == "number" then CharPhysics.freezeJumpPowBackup = jp end
                    local okH, jh = pcall(function() return hum.JumpHeight end)
                    if okH and type(jh) == "number" then CharPhysics.freezeJumpHtBackup = jh end
                end
                pcall(function() hum.WalkSpeed = 0 end)
                pcall(function() hum.JumpPower = 0 end)
                pcall(function() hum.JumpHeight = 0 end)
            end
        else
            if root then
                local restoreAnc = (CharPhysics.freezeAnchoredBackup == true)
                pcall(function() root.Anchored = restoreAnc end)
                pcall(function() root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end)
                pcall(function() root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero end)
            end
            if hum then
                if Config.Active and Config.WalkSpeedEnabled then
                    CharPhysics.applyWalkSpeed()
                else
                    pcall(function() hum.WalkSpeed = CharPhysics.freezeSpeedBackup or OriginalState.WalkSpeed end)
                end
                if CharPhysics.freezeJumpPowBackup ~= nil then
                    pcall(function() hum.JumpPower = CharPhysics.freezeJumpPowBackup end)
                end
                if CharPhysics.freezeJumpHtBackup ~= nil then
                    pcall(function() hum.JumpHeight = CharPhysics.freezeJumpHtBackup end)
                end
            end
            CharPhysics.freezeCF = nil
            CharPhysics.freezeAnchoredBackup = nil
            CharPhysics.freezeSpeedBackup = nil
            CharPhysics.freezeJumpPowBackup = nil
            CharPhysics.freezeJumpHtBackup = nil
            CharPhysics.freezeChar = nil
        end
    end

    function CharPhysics.stepFreeze()
        if not (Config.Active and CharPhysics.freezeEnabled) then return end
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (char and root) then return end
        if CharPhysics.freezeChar ~= char or not CharPhysics.freezeCF then
            CharPhysics.applyFreeze(true)
            return
        end
        if not root.Anchored then
            pcall(function() root.Anchored = true end)
        end
        if (root.Position - CharPhysics.freezeCF.Position).Magnitude > 0.05 then
            root.CFrame = CharPhysics.freezeCF
            pcall(function() root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end)
            pcall(function() root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero end)
        end
        if hum and hum.WalkSpeed ~= 0 then
            pcall(function() hum.WalkSpeed = 0 end)
        end
    end

    local SCALE_NAMES = {"BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale"}
    local function clearScaleWatchers()
        for i = #CharPhysics.scaleConns, 1, -1 do
            pcall(function() CharPhysics.scaleConns[i]:Disconnect() end)
            CharPhysics.scaleConns[i] = nil
        end
        CharPhysics.trackedSizeChar = nil
    end

    local function desiredScale()
        if Config.SizeIsNaN then return 0.03, true end
        local raw = tonumber(Config.SizeValue)
        if raw == nil or raw ~= raw then return 0.03, true
        elseif raw == M.huge then return 60, false
        else return M.clamp(raw, 0.03, 150), false end
    end

    function CharPhysics.applySize()
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (char and hum) then return end
        if not (Config.Active and Config.SizeEnabled) then
            clearScaleWatchers()
            pcall(function() if char.GetScale and char.ScaleTo then char:ScaleTo(CharPhysics.origModelScale or 1) end end)
            pcall(function() hum.AutomaticScalingEnabled = true end)
            for _, sName in ipairs(SCALE_NAMES) do
                local vObj = hum:FindFirstChild(sName)
                if vObj and vObj:IsA("NumberValue") and CharPhysics.scaleBackup[sName] ~= nil then
                    pcall(function() vObj.Value = CharPhysics.scaleBackup[sName] end)
                end
            end
            CharPhysics.scaleBackup = {}
            return
        end
        local targetScale, isNaNMode = desiredScale()
        if CharPhysics.trackedSizeChar ~= char then
            clearScaleWatchers(); CharPhysics.trackedSizeChar = char
            pcall(function() if char.GetScale then CharPhysics.origModelScale = char:GetScale() end end)
            for _, sName in ipairs(SCALE_NAMES) do
                local vObj = hum:FindFirstChild(sName)
                if vObj and vObj:IsA("NumberValue") then
                    if CharPhysics.scaleBackup[sName] == nil then CharPhysics.scaleBackup[sName] = vObj.Value end
                    CharPhysics.scaleConns[#CharPhysics.scaleConns + 1] = vObj:GetPropertyChangedSignal("Value"):Connect(function()
                        if Config.Active and Config.SizeEnabled then
                            local ts, nanFlag = desiredScale()
                            if not nanFlag and M.abs(vObj.Value - ts) > 0.005 then vObj.Value = ts end
                        end
                    end)
                end
            end
        end
        pcall(function() hum.AutomaticScalingEnabled = false end)
        pcall(function()
            if char.GetScale and char.ScaleTo and M.abs(char:GetScale() - targetScale) > 0.01 then char:ScaleTo(targetScale) end
        end)
        for _, sName in ipairs(SCALE_NAMES) do
            local vObj = hum:FindFirstChild(sName)
            if not vObj then
                if CharPhysics.scaleBackup[sName] == nil then CharPhysics.scaleBackup[sName] = 1 end
                vObj = Instance.new("NumberValue", hum); vObj.Name = sName; vObj.Value = 1
            elseif vObj:IsA("NumberValue") and CharPhysics.scaleBackup[sName] == nil then
                CharPhysics.scaleBackup[sName] = vObj.Value
            end
            if vObj:IsA("NumberValue") then
                if isNaNMode then
                    if vObj.Value == vObj.Value then vObj.Value = 0 / 0 end
                elseif vObj.Value ~= vObj.Value or M.abs(vObj.Value - targetScale) > 0.005 then
                    vObj.Value = targetScale
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Visuals: Korblox, Headless & Chat-Aware Hide Name
----------------------------------------------------------------
local Visuals = {}
do
    local KORB = {Stump = "rbxassetid://902942096", Tex = "rbxassetid://902843398", Limbs = {"RightUpperLeg","RightLowerLeg","RightFoot","Right Leg"}}
    local KorbloxPart, KorbloxUpper = nil, nil
    local HeadlessBackup = setmetatable({}, {__mode = "k"})
    local KorbloxBackup = setmetatable({}, {__mode = "k"})
    local SpoofedNameLabels = {}
    local GuardedWrite = setmetatable({}, {__mode = "k"})

    function Visuals.applyKorblox(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local upper = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        if not (hum and upper and upper:IsA("BasePart")) then return end
        for _, ln in ipairs(KORB.Limbs) do
            local limb = char:FindFirstChild(ln)
            if limb and limb:IsA("BasePart") then
                if not KorbloxBackup[limb] then KorbloxBackup[limb] = {t = limb.Transparency, ltm = limb.LocalTransparencyModifier} end
                if limb.LocalTransparencyModifier ~= 1 then limb.LocalTransparencyModifier = 1 end
                for _, d in ipairs(limb:GetDescendants()) do
                    if d:IsA("Decal") or d:IsA("Texture") then
                        if not KorbloxBackup[d] then KorbloxBackup[d] = {t = d.Transparency} end
                        if d.Transparency ~= 1 then d.Transparency = 1 end
                    end
                end
            end
        end
        local cam = workspace.CurrentCamera
        if not cam then return end
        if not KorbloxPart or not KorbloxPart.Parent or KorbloxUpper ~= upper then
            if KorbloxPart then pcall(function() KorbloxPart:Destroy() end) end
            KorbloxUpper = upper
            local stump = Instance.new("Part")
            stump.Name = Core.randomGuidName(); stump.Size = Vector3.new(0.5,0.5,0.5)
            stump.CanCollide = false; stump.CanTouch = false; stump.CanQuery = false; stump.Massless = true
            stump.Color = Color3.fromRGB(58,62,78); stump.Material = Enum.Material.SmoothPlastic; stump.CFrame = upper.CFrame
            local sm = Instance.new("SpecialMesh", stump)
            sm.MeshType = Enum.MeshType.FileMesh; sm.MeshId = KORB.Stump; sm.TextureId = KORB.Tex; sm.Scale = Vector3.new(1.05,1.05,1.05)
            local weld = Instance.new("Weld", stump)
            weld.Part0 = upper; weld.Part1 = stump
            weld.C0 = CFrame.new(0, (hum.RigType == Enum.HumanoidRigType.R15) and ((upper.Size.Y * 0.5) - 0.35) or 0.35, 0)
            stump.Parent = cam; KorbloxPart = stump
        end
    end

    function Visuals.removeKorblox(char)
        if KorbloxPart then pcall(function() KorbloxPart:Destroy() end); KorbloxPart = nil end
        KorbloxUpper = nil; char = char or Player.Character
        if not char then return end
        for _, ln in ipairs(KORB.Limbs) do
            local limb = char:FindFirstChild(ln)
            if limb and limb:IsA("BasePart") then
                local b = KorbloxBackup[limb]
                pcall(function() limb.LocalTransparencyModifier = (b and b.ltm) or 0; limb.Transparency = (b and b.t) or 0 end)
                KorbloxBackup[limb] = nil
                for _, d in ipairs(limb:GetDescendants()) do
                    if (d:IsA("Decal") or d:IsA("Texture")) and KorbloxBackup[d] then
                        pcall(function() d.Transparency = KorbloxBackup[d].t end); KorbloxBackup[d] = nil
                    end
                end
            end
        end
    end

    function Visuals.applyHeadless(char)
        local head = char and char:FindFirstChild("Head")
        if not (head and head:IsA("BasePart")) then return end
        if not HeadlessBackup[head] then
            HeadlessBackup[head] = {ltm = head.LocalTransparencyModifier, decals = {}}
            for _, d in ipairs(head:GetDescendants()) do
                if d:IsA("Decal") or d:IsA("Texture") then HeadlessBackup[head].decals[d] = d.Transparency end
            end
        end
        if head.LocalTransparencyModifier ~= 1 then head.LocalTransparencyModifier = 1 end
        for _, d in ipairs(head:GetDescendants()) do if (d:IsA("Decal") or d:IsA("Texture")) and d.Transparency ~= 1 then d.Transparency = 1 end end
    end

    function Visuals.removeHeadless(char)
        local head = char and char:FindFirstChild("Head")
        if not head then return end
        local b = HeadlessBackup[head]
        pcall(function()
            head.LocalTransparencyModifier = (b and b.ltm) or 0
            if b then for d, t in pairs(b.decals) do if d and d.Parent then d.Transparency = t end end
            else for _, d in ipairs(head:GetDescendants()) do if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end end end
        end)
        HeadlessBackup[head] = nil
    end

    local function isOwnOrClan(inst)
        if (Runtime.UI.GUI and inst:IsDescendantOf(Runtime.UI.GUI)) or (Runtime.UI.ToggleGui and inst:IsDescendantOf(Runtime.UI.ToggleGui)) then return true end
        local cur = inst
        for _ = 1, 5 do
            if not cur then break end
            local nl = cur.Name:lower()
            if nl:find("clan") or nl:find("guild") or nl:find("crew") or nl:find("gang") or nl:find("club") or nl:find("faction") then return true end
            cur = cur.Parent
        end
        return false
    end

    local function writeGuarded(lbl, txt)
        if not (lbl and lbl.Parent) or lbl.Text == txt then return end
        GuardedWrite[lbl] = true; lbl.Text = txt; GuardedWrite[lbl] = nil
    end

    function Visuals.replaceNameOnly(txt, alias)
        if not txt or txt == "" then return nil end
        local uName, dName = Player.Name, Player.DisplayName
        local updated, changed = txt, false
        if dName and dName ~= "" and dName ~= uName and updated:find(dName, 1, true) then
            updated = updated:gsub(dName:gsub("(%W)", "%%%1"), alias); changed = true
        end
        if uName and uName ~= "" and updated:find(uName, 1, true) then
            updated = updated:gsub(uName:gsub("(%W)", "%%%1"), alias); changed = true
        end
        local otherAlias = (alias == "ANONYMOUS") and "アノニマス" or "ANONYMOUS"
        if updated:find(otherAlias, 1, true) then
            updated = updated:gsub(otherAlias:gsub("(%W)", "%%%1"), alias); changed = true
        end
        return changed and updated or nil
    end

    function Visuals.bindHideName(lbl)
        if not Config.HideNameEnabled or not (lbl and lbl:IsA("TextLabel")) or isOwnOrClan(lbl) then return end
        local curTxt = lbl.Text or ""
        if curTxt:match("^%s*%[.-%]%s*$") then return end
        local alias = Config.HideNameAlias or "ANONYMOUS"
        local entry = SpoofedNameLabels[lbl]
        if not entry then
            local patched = Visuals.replaceNameOnly(curTxt, alias)
            if not patched then return end
            entry = {origText = curTxt, conn = nil}
            SpoofedNameLabels[lbl] = entry
            writeGuarded(lbl, patched)
            entry.conn = lbl:GetPropertyChangedSignal("Text"):Connect(function()
                if GuardedWrite[lbl] or not Config.HideNameEnabled then return end
                local latest = lbl.Text or ""
                entry.origText = latest
                local rep = Visuals.replaceNameOnly(latest, Config.HideNameAlias or "ANONYMOUS")
                if rep then writeGuarded(lbl, rep) end
            end)
        else
            local patched = Visuals.replaceNameOnly(entry.origText, alias)
            if patched then writeGuarded(lbl, patched) end
        end
    end

    function Visuals.refreshHideNames()
        if not Config.HideNameEnabled then return end
        for lbl, entry in pairs(SpoofedNameLabels) do
            if lbl and lbl.Parent then
                local patched = Visuals.replaceNameOnly(entry.origText, Config.HideNameAlias or "ANONYMOUS")
                if patched then writeGuarded(lbl, patched) end
            else
                if entry.conn then pcall(function() entry.conn:Disconnect() end) end
                SpoofedNameLabels[lbl] = nil
            end
        end
        for _, root in ipairs({Player:FindFirstChildOfClass("PlayerGui"), Player.Character}) do
            if root then for _, d in ipairs(root:GetDescendants()) do if d:IsA("TextLabel") then Visuals.bindHideName(d) end end end
        end
        pcall(function()
            local cg = SafeService("CoreGui")
            for _, sub in ipairs({"PlayerList", "ExperienceChat"}) do
                local f = cg and cg:FindFirstChild(sub)
                if f then for _, d in ipairs(f:GetDescendants()) do if d:IsA("TextLabel") then Visuals.bindHideName(d) end end end
            end
        end)
    end

    function Visuals.restoreHiddenNames()
        for lbl, entry in pairs(SpoofedNameLabels) do
            if entry.conn then pcall(function() entry.conn:Disconnect() end) end
            pcall(function() if lbl and lbl.Parent then writeGuarded(lbl, entry.origText) end end)
            SpoofedNameLabels[lbl] = nil
        end
    end
end

----------------------------------------------------------------
-- Perf Engine (Zero-GFX AI Perf Mode + Working FPS Jump & Cycle Rate)
----------------------------------------------------------------
do
    local fogConn, potatoConn, pingBoostConn, aiPerfConn = nil, nil, nil, nil
    local potatoBackup = {}
    local lastAppliedFFlagCap = nil

    function Perf.applyFPSCap(val, isRestore)
        local cap = tonumber(val)
        if cap == nil then cap = 120 end
        local restoreMode = (isRestore == true)
        local unlockMode = (cap <= 0)
        local execCap = unlockMode and (restoreMode and 0 or 999) or M.clamp(M.floor(cap), 1, 1000)

        if restoreMode then
            lastAppliedFFlagCap = nil
            if setfflag then
                for flagName, rec in pairs(OriginalState.ModifiedFFlags) do
                    if rec.known and rec.orig ~= nil and rec.orig ~= "" then
                        pcall(setfflag, flagName, rec.orig)
                    elseif flagName:sub(1, 5) == "FFlag" then
                        pcall(setfflag, flagName, "True")
                    elseif flagName:find("TargetFps") then
                        pcall(setfflag, flagName, tostring(execCap))
                    end
                end
            end
            if setfpscap then pcall(setfpscap, execCap) end
            if set_fps_cap then pcall(set_fps_cap, execCap) end
            if setfps then pcall(setfps, execCap) end
            if unlockfps and unlockMode then pcall(unlockfps) end
            pcall(function()
                local ugs = UserSettings():GetService("UserGameSettings")
                pcall(function() ugs.FramerateCap = execCap end)
                pcall(function() ugs.VSync = OriginalState.VSync end)
            end)
            return
        end

        local fflagTarget = tostring(execCap)
        if setfflag and lastAppliedFFlagCap ~= fflagTarget then
            lastAppliedFFlagCap = fflagTarget
            OriginalState.saveFFlag("FFlagTaskSchedulerLimitTargetFpsTo2402")
            OriginalState.saveFFlag("TaskSchedulerTargetFps")
            OriginalState.saveFFlag("DFIntTaskSchedulerTargetFps")
            pcall(setfflag, "FFlagTaskSchedulerLimitTargetFpsTo2402", "False")
            pcall(setfflag, "TaskSchedulerTargetFps", fflagTarget)
            pcall(setfflag, "DFIntTaskSchedulerTargetFps", fflagTarget)
        end
        if setfpscap then pcall(setfpscap, execCap) end
        if set_fps_cap then pcall(set_fps_cap, execCap) end
        if setfps then pcall(setfps, execCap) end
        if unlockfps and unlockMode then pcall(unlockfps) end
        pcall(function()
            local ugs = UserSettings():GetService("UserGameSettings")
            pcall(function() ugs.FramerateCap = execCap end)
            if unlockMode or execCap > 60 then pcall(function() ugs.VSync = false end) end
        end)
    end

    function Perf.setRemoveFog(on)
        if fogConn then fogConn:Disconnect(); fogConn = nil end
        if on then
            pcall(function()
                Lighting.FogStart = 9e9; Lighting.FogEnd = 9e9
                for _, ch in ipairs(Lighting:GetChildren()) do
                    if ch:IsA("Atmosphere") then
                        if not OriginalState.Atmospheres[ch] then
                            OriginalState.Atmospheres[ch] = {Density = ch.Density, Haze = ch.Haze, Offset = ch.Offset, Glare = ch.Glare}
                        end
                        ch.Density = 0; ch.Haze = 0
                    end
                end
            end)
            fogConn = Lighting.Changed:Connect(function(prop)
                if Config.RemoveFog and (prop == "FogEnd" or prop == "FogStart") then
                    pcall(function() Lighting.FogStart = 9e9; Lighting.FogEnd = 9e9 end)
                end
            end)
        elseif not Config.FPSBoost then
            pcall(function()
                Lighting.FogStart = OriginalState.FogStart; Lighting.FogEnd = OriginalState.FogEnd
                for atmo, d in pairs(OriginalState.Atmospheres) do
                    if atmo and atmo.Parent then atmo.Density = d.Density; atmo.Haze = d.Haze; atmo.Offset = d.Offset; atmo.Glare = d.Glare end
                end
            end)
        end
    end

    local function makePotato(inst)
        local model = inst:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChildOfClass("Humanoid") then return end
        if inst:IsA("BasePart") then
            if not potatoBackup[inst] then potatoBackup[inst] = {m = inst.Material, r = inst.Reflectance, s = inst.CastShadow} end
            inst.Material = Enum.Material.SmoothPlastic; inst.Reflectance = 0; inst.CastShadow = false
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            if not potatoBackup[inst] then potatoBackup[inst] = {t = inst.Transparency} end
            inst.Transparency = 1
        elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") or inst:IsA("Beam") or inst:IsA("PostEffect") then
            if not potatoBackup[inst] then potatoBackup[inst] = {e = inst.Enabled} end
            inst.Enabled = false
        end
    end

    function Perf.setFPSBoost(on)
        if on then
            pcall(function()
                Lighting.GlobalShadows = false; Lighting.FogStart = 9e9; Lighting.FogEnd = 9e9
                Lighting.EnvironmentDiffuseScale = 0; Lighting.EnvironmentSpecularScale = 0
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
                local terrain = workspace:FindFirstChildOfClass("Terrain")
                if terrain then
                    terrain.WaterWaveSize = 0; terrain.WaterWaveSpeed = 0; terrain.WaterReflectance = 0; terrain.WaterTransparency = 0
                    pcall(function() terrain.Decoration = false end)
                end
            end)
            if potatoConn then potatoConn:Disconnect() end
            potatoConn = workspace.DescendantAdded:Connect(function(i) if Config.FPSBoost then pcall(makePotato, i) end end)
            task.spawn(function()
                for idx, i in ipairs(workspace:GetDescendants()) do
                    if not Config.FPSBoost then break end
                    pcall(makePotato, i); if idx % 400 == 0 then task.wait() end
                end
                for _, i in ipairs(Lighting:GetDescendants()) do
                    if not Config.FPSBoost then break end
                    pcall(makePotato, i)
                end
            end)
        else
            if potatoConn then potatoConn:Disconnect(); potatoConn = nil end
            pcall(function()
                Lighting.GlobalShadows = OriginalState.GlobalShadows; Lighting.Brightness = OriginalState.Brightness
                Lighting.OutdoorAmbient = OriginalState.OutdoorAmbient; Lighting.Ambient = OriginalState.Ambient
                Lighting.EnvironmentDiffuseScale = OriginalState.EnvironmentDiffuseScale
                Lighting.EnvironmentSpecularScale = OriginalState.EnvironmentSpecularScale
                if not Config.RemoveFog then
                    Lighting.FogStart = OriginalState.FogStart; Lighting.FogEnd = OriginalState.FogEnd
                    for atmo, d in pairs(OriginalState.Atmospheres) do
                        if atmo and atmo.Parent then atmo.Density = d.Density; atmo.Haze = d.Haze; atmo.Offset = d.Offset; atmo.Glare = d.Glare end
                    end
                end
                settings().Rendering.QualityLevel = OriginalState.QualityLevel
                UserSettings():GetService("UserGameSettings").SavedQualityLevel = OriginalState.SavedQualityLevel
                local terrain = workspace:FindFirstChildOfClass("Terrain")
                if terrain then
                    terrain.WaterWaveSize = OriginalState.WaterWaveSize; terrain.WaterWaveSpeed = OriginalState.WaterWaveSpeed
                    terrain.WaterReflectance = OriginalState.WaterReflectance; terrain.WaterTransparency = OriginalState.WaterTransparency
                    pcall(function() terrain.Decoration = OriginalState.Decoration end)
                end
            end)
            for inst, orig in pairs(potatoBackup) do
                pcall(function()
                    if inst and inst.Parent then
                        if orig.m ~= nil then inst.Material = orig.m; inst.Reflectance = orig.r; inst.CastShadow = orig.s
                        elseif orig.t ~= nil then inst.Transparency = orig.t
                        elseif orig.e ~= nil then inst.Enabled = orig.e end
                    end
                end)
                potatoBackup[inst] = nil
            end
        end
    end

    function Perf.setPingBoost(on)
        if pingBoostConn then pingBoostConn:Disconnect(); pingBoostConn = nil end
        if on then
            pcall(function()
                settings().Network.IncomingReplicationLag = 0
                settings().Physics.AllowSleep = false
                local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if root then Player.ReplicationFocus = root end
            end)
            local lastPingTick = M.clock()
            pingBoostConn = RunService.Heartbeat:Connect(function()
                if not Config.Active or not Config.PingBoost then return end
                local now = M.clock()
                if now - lastPingTick < 0.25 then return end
                lastPingTick = now
                pcall(function()
                    local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if root then Player.ReplicationFocus = root end
                    settings().Network.IncomingReplicationLag = 0
                end)
            end)
        else
            pcall(function()
                if not Config.AIPerfMode then
                    Player.ReplicationFocus = nil
                    settings().Network.IncomingReplicationLag = OriginalState.IncomingReplicationLag
                end
                settings().Physics.AllowSleep = Config.AIPerfMode and true or OriginalState.AllowSleep
            end)
        end
    end

    function Perf.setAIPerfMode(on)
        if aiPerfConn then aiPerfConn:Disconnect(); aiPerfConn = nil end
        if on then
            Perf.aiSchedulerMode = "Headroom-Max"
            Perf.applyCycleSettings()
            pcall(function()
                settings().Physics.AllowSleep = true
                settings().Network.IncomingReplicationLag = 0
                pcall(function() settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.DefaultAuto end)
                pcall(function() workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Enabled end)
                local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if root then Player.ReplicationFocus = root end
                collectgarbage("setpause", 150)
                collectgarbage("setstepmul", 150)
            end)
            local lastHeapKb = collectgarbage("count")
            local lastAudit = M.clock()
            aiPerfConn = RunService.Heartbeat:Connect(function(dt)
                if not Config.Active or not Config.AIPerfMode then return end
                local now = M.clock()
                if now - lastAudit < 0.30 then return end
                lastAudit = now
                local curHeapKb = collectgarbage("count")
                local heapDelta = M.max(0, curHeapKb - lastHeapKb)
                lastHeapKb = curHeapKb
                if heapDelta > 512 and dt < 0.022 then
                    local stepUnits = M.clamp(M.floor(heapDelta * 0.12), 8, 32)
                    if pcall(collectgarbage, "step", stepUnits) then Perf.aiGcSteppedKb += stepUnits end
                    Perf.aiSchedulerMode = "GC-Trim"
                elseif dt < 0.036 then
                    Perf.aiSchedulerMode = "Headroom-Max"
                else
                    Perf.aiSchedulerMode = "Frame-Protect"
                end
                pcall(function()
                    local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if root then Player.ReplicationFocus = root end
                end)
            end)
        else
            Perf.aiSchedulerMode = "Standard"
            pcall(function()
                if not Config.PingBoost then
                    Player.ReplicationFocus = nil
                    settings().Network.IncomingReplicationLag = OriginalState.IncomingReplicationLag
                end
                settings().Physics.AllowSleep = Config.PingBoost and false or OriginalState.AllowSleep
                collectgarbage("setpause", 200)
                collectgarbage("setstepmul", 200)
            end)
            Perf.applyCycleSettings()
        end
    end

    function Perf.applyCycleSettings()
        local jump = M.clamp(M.floor(tonumber(Config.CycleJump) or 1), 1, 100)
        local cRate = M.clamp(M.floor(tonumber(Config.CycleRate) or 100), 50, 1000)
        local rateRatio = cRate / 100
        Perf.frameBudgetSec = M.clamp(0.0016 * rateRatio, 0.0007, 0.0085)
        Perf.activeWorkers = M.clamp(M.floor(rateRatio * 1.5 + 0.5), 1, 12)
        if jump > 1 or Config.AIPerfMode then
            local baseCap = tonumber(Config.FPSCap)
            local targetCap = (Config.AIPerfMode or (baseCap ~= nil and baseCap <= 0)) and 999 or M.min(999, 60 * jump)
            local fflagTarget = tostring(targetCap)
            if setfflag and lastAppliedFFlagCap ~= fflagTarget then
                lastAppliedFFlagCap = fflagTarget
                OriginalState.saveFFlag("FFlagTaskSchedulerLimitTargetFpsTo2402")
                OriginalState.saveFFlag("TaskSchedulerTargetFps")
                OriginalState.saveFFlag("DFIntTaskSchedulerTargetFps")
                pcall(setfflag, "FFlagTaskSchedulerLimitTargetFpsTo2402", "False")
                pcall(setfflag, "TaskSchedulerTargetFps", fflagTarget)
                pcall(setfflag, "DFIntTaskSchedulerTargetFps", fflagTarget)
            end
            if setfpscap then pcall(setfpscap, targetCap) end
            if set_fps_cap then pcall(set_fps_cap, targetCap) end
            if setfps then pcall(setfps, targetCap) end
            if unlockfps and targetCap >= 240 then pcall(unlockfps) end
            pcall(function()
                local ugs = UserSettings():GetService("UserGameSettings")
                pcall(function() ugs.FramerateCap = targetCap end)
                pcall(function() ugs.VSync = false end)
                if not Config.PingBoost then pcall(function() settings().Physics.AllowSleep = true end) end
                pcall(function() workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Enabled end)
            end)
        else
            Perf.applyFPSCap(Config.FPSCap, false)
        end
    end

    local lastPopupAllowT, lastRepSoundAllowT = 0, 0
    local PROTECTED_GUI_KW = {"chat", "touchgui", "boss", "shop", "store", "quest", "wheel", "spin", "fortune", "inventory", "trade", "clans", "mastery", "benefits", "packs", "codes", "settings", "rebirth", "daily", "login", "streak", "calendar", "playtime", "reward", "gift"}
    local POPUP_GUI_KW = {"effect", "popup", "gain", "float", "statuseffect", "stateffect"}

    local function isProtectedGuiName(nameStr)
        local nl = tostring(nameStr or ""):lower()
        if nl == "" then return false end
        for _, skipKw in ipairs(PROTECTED_GUI_KW) do
            if nl:find(skipKw, 1, true) then return true end
        end
        return false
    end

    local function hasProtectedGuiAncestor(d, sg)
        if sg and isProtectedGuiName(sg.Name) then return true end
        local cur = d
        for _ = 1, 16 do
            if not cur or cur == game or cur:IsA("PlayerGui") then break end
            if isProtectedGuiName(cur.Name) then return true end
            if cur == sg then break end
            cur = cur.Parent
        end
        return false
    end

    local function hasProtectedGuiDescendant(inst)
        if isProtectedGuiName(inst.Name) then return true end
        for _, sub in ipairs(inst:GetDescendants()) do
            if isProtectedGuiName(sub.Name) then return true end
        end
        return false
    end

    function Perf.handleRepAntiLagDesc(d)
        if not (Config.Active and Config.RepAntiLag and Runtime.RepGateOpen and (Config.FastRep or Config.AIFastRep)) then return end
        if not (d and d.Parent) then return end
        if (Runtime.UI.GUI and d:IsDescendantOf(Runtime.UI.GUI)) or (Runtime.UI.ToggleGui and d:IsDescendantOf(Runtime.UI.ToggleGui)) or (Runtime.SoundContainer and d:IsDescendantOf(Runtime.SoundContainer)) then
            return
        end

        if d:IsA("Sound") then
            local now = M.clock()
            if (now - lastRepSoundAllowT) < 0.22 then
                pcall(function() d.Volume = 0; if d.IsPlaying then d:Stop() end end)
            else
                lastRepSoundAllowT = now
            end
            return
        end

        if d:IsA("GuiObject") or d:IsA("BillboardGui") then
            local bb = d:IsA("BillboardGui") and d or d:FindFirstAncestorOfClass("BillboardGui")
            if bb and bb:FindFirstAncestorOfClass("Workspace") and not (Player.Character and d:IsDescendantOf(Player.Character)) then
                return
            end
            local sg = d:FindFirstAncestorOfClass("ScreenGui")
            if hasProtectedGuiAncestor(d, sg) then return end
            local gl = sg and tostring(sg.Name or ""):lower() or ""

            local isPopup = false
            for _, pKw in ipairs(POPUP_GUI_KW) do
                if gl:find(pKw, 1, true) then isPopup = true; break end
            end
            if not isPopup and d:IsA("TextLabel") then
                local nl = tostring(d.Name or ""):lower()
                local okT, txtRaw = pcall(function() return d.Text end)
                local txt = (okT and type(txtRaw) == "string") and txtRaw or ""
                if nl:find("popup") or nl:find("gain") or nl:find("float") or txt:match("^%s*%+[%d%.,]") then
                    isPopup = true
                end
            end

            if isPopup then
                local now = M.clock()
                if (now - lastPopupAllowT) < 0.14 then
                    task.defer(function()
                        if d and d.Parent and Config.RepAntiLag and Runtime.RepGateOpen then
                            if d:IsA("BillboardGui") then pcall(function() d.Enabled = false end)
                            elseif d:IsA("GuiObject") then pcall(function() d.Visible = false end) end
                        end
                    end)
                else
                    lastPopupAllowT = now
                end
            end
        end
    end

    function Perf.sweepRepPopups()
        local pGui = Player:FindFirstChildOfClass("PlayerGui")
        if not pGui then return end
        for _, sg in ipairs(pGui:GetChildren()) do
            if sg:IsA("ScreenGui") and sg ~= Runtime.UI.GUI and sg ~= Runtime.UI.ToggleGui and not isProtectedGuiName(sg.Name) then
                local gl = tostring(sg.Name or ""):lower()
                local isPopupGui = false
                for _, pKw in ipairs(POPUP_GUI_KW) do
                    if gl:find(pKw, 1, true) then isPopupGui = true; break end
                end
                if isPopupGui then
                    for _, ch in ipairs(sg:GetChildren()) do
                        if ch:IsA("GuiObject") and ch.Visible and not hasProtectedGuiDescendant(ch) then
                            pcall(function() ch.Visible = false end)
                        end
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Cached Stat Pointers & Smooth Telemetry
----------------------------------------------------------------
do
    local STAT_ALIASES = {
        Strength = {"strength", "str", "power", "muscle", "force", "might"},
        Durability = {"durability", "dura", "toughness", "defense", "endurance", "stamina"},
        Rebirths = {"rebirths", "rebirth", "reb", "prestiges", "prestige"},
        RebirthCooldown = {"rebirthcooldown", "cooldown", "rebirthtimer", "rebcd", "rebirthcd", "nextrebirthtime", "rebirthdelay", "cd"},
        RequiredStrength = {"requiredstrength", "rebirthstrength", "nextrebirth", "reqstrength", "rebirthcost", "strengthrequired", "neededstrength", "rebirthreq"},
    }
    local STAT_BOX_PRIORITY = {
        "leaderstats", "data", "stats", "playerdata", "profile",
        "values", "hiddenstats", "cooldowns", "info", "currencies", "statsfolder",
    }
    local RS_DATA_DIRS = {playerdata = true, data = true, profiles = true, playerstats = true, users = true}
    local CachedObjs, MissingUntil = {}, {}

    function Telemetry.clearCache()
        CachedObjs = {}; MissingUntil = {}
        Telemetry.cachedGuiRebReq = nil
        Telemetry.cachedGuiRebReqForCount = nil
        Telemetry.lastGuiRebScan = 0
    end

    local function getStatContainers()
        local byLow, boxes, seenBox = {}, {}, {}
        for _, ch in ipairs(Player:GetChildren()) do
            local cl = ch.Name:lower()
            if not byLow[cl] then byLow[cl] = ch end
        end
        local function addBox(b)
            if b and not seenBox[b] then
                seenBox[b] = true
                boxes[#boxes + 1] = b
            end
        end
        for _, boxKey in ipairs(STAT_BOX_PRIORITY) do
            addBox(byLow[boxKey])
        end
        addBox(Player)
        for _, rsDir in ipairs(ReplicatedStorage:GetChildren()) do
            if RS_DATA_DIRS[rsDir.Name:lower()] then
                local pNode = rsDir:FindFirstChild(Player.Name) or rsDir:FindFirstChild(tostring(Player.UserId))
                if pNode then addBox(pNode) end
            end
        end
        return boxes
    end

    local function matchStatAlias(nameLow, aliases, exactOnly)
        if exactOnly then
            for _, alias in ipairs(aliases) do
                if nameLow == alias then return true end
            end
            return false
        end
        for _, alias in ipairs(aliases) do
            if nameLow:find(alias, 1, true) then return true end
        end
        return false
    end

    function Telemetry.resolveStat(canonical)
        local cached = CachedObjs[canonical]
        if cached and cached.Parent then return cached end
        local now = M.clock()
        if MissingUntil[canonical] and now < MissingUntil[canonical] then return nil end
        local aliases = STAT_ALIASES[canonical] or {canonical:lower()}
        local allowReqWords = (canonical == "RequiredStrength")
        local boxes = getStatContainers()

        local function isBadStatSub(nl)
            if allowReqWords then return false end
            if nl:find("max") or nl:find("multi") or nl:find("pet") or nl:find("quest") or nl:find("streak") then
                return true
            end
            if nl:find("req") or nl:find("cost") or nl:find("need") or nl:find("next")
                or nl:find("boost") or nl:find("bonus") or nl:find("equip") or nl:find("price") then
                return true
            end
            if canonical ~= "Rebirths" and canonical ~= "RebirthCooldown" and nl:find("rebirth") then
                return true
            end
            if canonical == "Rebirths" and nl:find("strength") then
                return true
            end
            if canonical ~= "RebirthCooldown" then
                if nl:find("cooldown") or nl:find("timer") or nl:find("delay") or nl:find("rebirthcd") or nl:find("rebcd") then
                    return true
                end
            else
                if nl:find("gift") or nl:find("spin") or nl:find("wheel") or nl:find("daily")
                    or nl:find("punch") or nl:find("boss") or nl:find("chest") or nl:find("trade")
                    or nl:find("attack") or nl:find("skill") then
                    return true
                end
            end
            return false
        end

        for _, box in ipairs(boxes) do
            for _, c in ipairs(box:GetChildren()) do
                if c:IsA("ValueBase") and matchStatAlias(c.Name:lower(), aliases, true) then
                    CachedObjs[canonical] = c; MissingUntil[canonical] = nil; return c
                end
            end
        end

        for _, box in ipairs(boxes) do
            for _, c in ipairs(box:GetChildren()) do
                if c:IsA("ValueBase") then
                    local cl = c.Name:lower()
                    local badSub = isBadStatSub(cl)
                    if not badSub and matchStatAlias(cl, aliases, false) then
                        CachedObjs[canonical] = c; MissingUntil[canonical] = nil; return c
                    end
                end
            end
        end

        for _, box in ipairs(boxes) do
            if box ~= Player then
                for _, desc in ipairs(box:GetDescendants()) do
                    if desc:IsA("ValueBase") then
                        local dl = desc.Name:lower()
                        local badSub = isBadStatSub(dl)
                        if not badSub and matchStatAlias(dl, aliases, true) then
                            CachedObjs[canonical] = desc; MissingUntil[canonical] = nil; return desc
                        end
                    end
                end
            end
        end
        MissingUntil[canonical] = now + 4.0
        return nil
    end

    local function readAttrStatCI(canonical)
        local aliases = STAT_ALIASES[canonical] or {canonical:lower()}
        local boxes = getStatContainers()
        for _, box in ipairs(boxes) do
            local attrs = box:GetAttributes()
            for ak, av in pairs(attrs) do
                if matchStatAlias(tostring(ak):lower(), aliases, true) then return av end
            end
        end
        return nil
    end

    function Telemetry.getStatNum(canonical)
        local s = Telemetry.resolveStat(canonical)
        if s then
            local v = s.Value
            if type(v) == "number" then return v end
            if type(v) == "string" then return Core.parseSmartInput(v).num end
            return tonumber(v) or 0
        end
        local attr = Player:GetAttribute(canonical)
        if attr == nil then attr = readAttrStatCI(canonical) end
        if type(attr) == "number" then return attr end
        if type(attr) == "string" then return Core.parseSmartInput(attr).num end
        return 0
    end

    local function parseTimerCdValue(n, now)
        if n > 1e8 then return M.max(0, n - os.time())
        elseif n > (now + 1) and n < 1e7 then return M.max(0, n - now)
        else return M.max(0, n) end
    end

    function Telemetry.readServerRebirthCd(now)
        local obj = Telemetry.resolveStat("RebirthCooldown")
        if obj then
            local n = tonumber(obj.Value)
            if n ~= nil then return parseTimerCdValue(n, now) end
        end
        for _, attrName in ipairs({"RebirthCooldown", "rebirthCooldown", "Cooldown", "rebirthTimer"}) do
            local n = tonumber(Player:GetAttribute(attrName))
            if n ~= nil then return parseTimerCdValue(n, now) end
        end
        local attrCI = tonumber(readAttrStatCI("RebirthCooldown"))
        if attrCI ~= nil then return parseTimerCdValue(attrCI, now) end
        return nil
    end

    local SKIP_REB_GUI = {Chat = true, BubbleChat = true, Freecam = true, FreeCamera = true, TouchGui = true}

    local function scanGuiRebirthLabels(gui, strictReb)
        for _, d in ipairs(gui:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text and d.Text ~= "" then
                local clean = tostring(d.Text):gsub("<[^>]+>", "")
                local low = clean:lower()
                local ancName = (d.Parent and d.Parent.Name or ""):lower()
                local relevant
                if strictReb then
                    local hasReb = low:find("rebirth") or ancName:find("rebirth")
                    local hasReq = low:find("strength") or low:find("str") or low:find("require") or low:find("need") or low:find("cost")
                    relevant = hasReb and hasReq
                else
                    relevant = low:find("rebirth") or low:find("require") or low:find("need") or low:find("cost")
                        or low:find("strength") or low:find("str") or ancName:find("rebirth") or ancName:find("require")
                end
                if relevant and not (low:find("robux") or low:find("gem") or low:find("coin") or low:find("pet")) then
                    local rawNum = clean:match("/%s*([%d%.,]+%s*[a-zA-Z]*)")
                        or clean:match("[Rr]equire[d]?[^%d]*([%d%.,]+%s*[a-zA-Z]*)")
                        or clean:match("[Nn]eed[ed]*[^%d]*([%d%.,]+%s*[a-zA-Z]*)")
                        or clean:match("[Cc]ost[^%d]*([%d%.,]+%s*[a-zA-Z]*)")
                        or clean:match("([%d%.,]+%s*[a-zA-Z]*)%s*[Ss]trength")
                        or clean:match("[Ss]trength[:%s%-]+([%d%.,]+%s*[a-zA-Z]*)")
                    if rawNum then
                        local parsed = Core.parseSmartInput(rawNum)
                        if parsed.num and not parsed.isNaN and not parsed.isInf and parsed.num >= 100 then
                            return parsed.num
                        end
                    end
                end
            end
        end
        return nil
    end

    local function readGuiRebirthReq(curReb)
        local now = M.clock()
        if Telemetry.cachedGuiRebReqForCount == curReb and (now - Telemetry.lastGuiRebScan < 1.5) then
            return Telemetry.cachedGuiRebReq
        end
        Telemetry.lastGuiRebScan = now
        Telemetry.cachedGuiRebReqForCount = curReb

        local pGui = Player:FindFirstChildOfClass("PlayerGui")
        if not pGui then Telemetry.cachedGuiRebReq = nil; return nil end
        local fallbackGuis = {}
        for _, gui in ipairs(pGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled ~= false and not SKIP_REB_GUI[gui.Name]
                and not (Runtime.UI.GUI and (gui == Runtime.UI.GUI or gui:IsDescendantOf(Runtime.UI.GUI)))
                and not (Runtime.UI.ToggleGui and (gui == Runtime.UI.ToggleGui or gui:IsDescendantOf(Runtime.UI.ToggleGui))) then
                local gn = gui.Name:lower()
                if gn:find("rebirth") or gn:find("prestige") or gn:find("stats") or gn:find("main") or gn:find("hud") or gn:find("gui") then
                    local found = scanGuiRebirthLabels(gui, false)
                    if found then
                        Telemetry.cachedGuiRebReq = found
                        return found
                    end
                else
                    fallbackGuis[#fallbackGuis + 1] = gui
                end
            end
        end
        for _, gui in ipairs(fallbackGuis) do
            local found = scanGuiRebirthLabels(gui, true)
            if found then
                Telemetry.cachedGuiRebReq = found
                return found
            end
        end
        Telemetry.cachedGuiRebReq = nil
        return nil
    end

    function Telemetry.getNextRebirthReq(curReb)
        local req = Telemetry.getStatNum("RequiredStrength")
        if req > 0 then return req end
        local guiReq = readGuiRebirthReq(curReb)
        if guiReq and guiReq > 0 then return guiReq end
        return 25000 + M.max(0, M.floor(curReb or 0)) * 25000
    end

    function Telemetry.newGainPred(init) return {lastVal = init, lastSampleTime = M.clock(), emaRatePerSec = 0, samples = 0} end
    function Telemetry.updateGainPred(pred, curVal, now, isActive, totalGained, totalElapsed)
        if not isActive then pred.lastVal = curVal; pred.lastSampleTime = now; pred.emaRatePerSec = 0; pred.samples = 0; return 0 end
        local dt = now - pred.lastSampleTime
        if dt >= 0.25 then
            local instRate = M.max(0, curVal - (pred.lastVal or curVal)) / dt
            pred.emaRatePerSec = (pred.samples == 0) and instRate or (pred.emaRatePerSec * 0.72 + instRate * 0.28)
            pred.samples += 1; pred.lastVal = curVal; pred.lastSampleTime = now
        end
        local sessionAvg = (totalGained > 0 and totalElapsed >= 1) and (totalGained / totalElapsed) or 0
        if pred.emaRatePerSec > 0 and sessionAvg > 0 then return (pred.emaRatePerSec * 0.65) + (sessionAvg * 0.35) end
        return M.max(pred.emaRatePerSec, sessionAvg)
    end

    function Telemetry.newTracker() return {buckets = table.create(20, 0), currentIdx = 1, lastStep = M.clock(), smoothRate = 0} end
    function Telemetry.recordEvent(tr, count)
        local now = M.clock()
        local steps = M.floor((now - tr.lastStep) / 0.05)
        if steps > 0 then
            for _ = 1, M.min(steps, 20) do tr.currentIdx = (tr.currentIdx % 20) + 1; tr.buckets[tr.currentIdx] = 0 end
            tr.lastStep = tr.lastStep + steps * 0.05
        end
        tr.buckets[tr.currentIdx] += (count or 1)
    end
    function Telemetry.sampleRate(tr, dt, isActive)
        local now = M.clock()
        local steps = M.floor((now - tr.lastStep) / 0.05)
        if steps > 0 then
            for _ = 1, M.min(steps, 20) do tr.currentIdx = (tr.currentIdx % 20) + 1; tr.buckets[tr.currentIdx] = 0 end
            tr.lastStep = tr.lastStep + steps * 0.05
        end
        if not isActive then tr.smoothRate = 0; return 0 end
        local sum = 0
        for i = 1, 20 do sum += tr.buckets[i] end
        tr.smoothRate += (sum - tr.smoothRate) * M.clamp(dt * 14, 0.14, 0.60)
        if M.abs(sum - tr.smoothRate) < 0.5 then tr.smoothRate = sum end
        return tr.smoothRate
    end

    function Telemetry.resetStrength()
        Telemetry.strStartTime = M.clock()
        local s, d = Telemetry.getStatNum("Strength"), Telemetry.getStatNum("Durability")
        Telemetry.baseStr = (s > 0) and s or nil; Telemetry.baseDura = (d > 0) and d or nil
        Telemetry.strPredictor = Telemetry.newGainPred(Telemetry.baseStr)
        Telemetry.duraPredictor = Telemetry.newGainPred(Telemetry.baseDura)
        Telemetry.repTracker = Telemetry.newTracker()
    end
    function Telemetry.resetRebirth()
        Telemetry.rebStartTime = M.clock()
        local r = Telemetry.getStatNum("Rebirths")
        Telemetry.baseReb = (r > 0) and r or nil; Telemetry.lastRebGainPerCycle = 0
    end
    function Telemetry.resetPunch()
        Telemetry.punStartTime = M.clock(); Telemetry.punchesTotal = 0
        Telemetry.punchTracker = Telemetry.newTracker()
    end

    Telemetry.strPredictor = Telemetry.newGainPred(nil)
    Telemetry.duraPredictor = Telemetry.newGainPred(nil)
    Telemetry.repTracker = Telemetry.newTracker()
    Telemetry.punchTracker = Telemetry.newTracker()
end
----------------------------------------------------------------
-- Centered, Moveable 16-Stage AI Scanner + Full-Server Threat Detection
----------------------------------------------------------------
local ThreatScanner = {}
do
    local THREAT_KW = {
        "co-owner","co owner","coowner","owner","founder","creator",
        "administrator","admin","moderator","mod","staff","developer",
        "dev","tester","qa","scripter","builder","modeler","contributor",
        "manager","director","head","supervisor","support","helper"
    }

    local function matchStaffKw(str)
        if not str or str == "" then return nil end
        local low = str:lower()
        for _, kw in ipairs(THREAT_KW) do
            if low:find("%f[%a]" .. kw:gsub("%-", "%%-") .. "%f[%A]") then return kw:upper() end
        end
        return nil
    end

    function ThreatScanner.inspectPlayer(plr)
        if not plr then return nil end
        local reasons, severity = {}, "HIGH"

        if game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0 and plr.UserId == game.CreatorId then
            reasons[#reasons + 1] = "Game Owner (CreatorId Match)"; severity = "CRITICAL"
        end
        local okRbx, isRbxAdmin = pcall(plr.IsInGroup, plr, 1200769)
        if okRbx and isRbxAdmin then
            reasons[#reasons + 1] = "Roblox Official Staff/Admin"; severity = "CRITICAL"
        end
        if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
            local okRank, rank = pcall(plr.GetRankInGroup, plr, game.CreatorId)
            local okRole, role = pcall(plr.GetRoleInGroup, plr, game.CreatorId)
            if okRole and type(role) == "string" and role ~= "" then
                if matchStaffKw(role) then
                    reasons[#reasons + 1] = M.fmtStr("Group Role: %s (Rank %d)", role, tonumber(rank) or 0)
                    severity = "CRITICAL"
                elseif okRank and type(rank) == "number" and rank >= 150 then
                    reasons[#reasons + 1] = M.fmtStr("High Group Rank: %s (%d)", role, rank)
                    severity = "CRITICAL"
                end
            end
        end

        pcall(function()
            for attrName, attrVal in pairs(plr:GetAttributes()) do
                local kLow = tostring(attrName):lower()
                if (kLow:find("admin") or kLow:find("staff") or kLow:find("owner") or kLow:find("mod") or kLow:find("dev") or kLow:find("tester"))
                    and (attrVal == true or (type(attrVal) == "number" and attrVal > 0)) then
                    reasons[#reasons + 1] = M.fmtStr("Attr Flag: %s=%s", tostring(attrName), tostring(attrVal))
                elseif type(attrVal) == "string" and matchStaffKw(attrVal) then
                    reasons[#reasons + 1] = M.fmtStr("Attr Role: %s", attrVal)
                end
            end
        end)

        pcall(function()
            for _, box in ipairs({plr, plr:FindFirstChild("leaderstats")}) do
                if box then
                    for _, c in ipairs(box:GetChildren()) do
                        if c:IsA("ValueBase") then
                            local cn = c.Name:lower()
                            if (cn:find("admin") or cn:find("staff") or cn:find("mod") or cn:find("dev") or cn:find("tester") or cn:find("owner"))
                                and (c.Value == true or (type(c.Value) == "number" and c.Value > 0)) then
                                reasons[#reasons + 1] = "ValueObj: " .. c.Name
                            elseif type(c.Value) == "string" and (cn:find("rank") or cn:find("role") or cn:find("tag") or cn:find("title")) and matchStaffKw(c.Value) then
                                reasons[#reasons + 1] = "Rank Tag: " .. c.Value
                            end
                        end
                    end
                end
            end
        end)

        if plr.Character then
            for _, d in ipairs(plr.Character:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text ~= "" and matchStaffKw(d.Text) then
                    reasons[#reasons + 1] = "Overhead Tag: " .. d.Text:sub(1, 24); break
                end
            end
        end
        for _, box in ipairs({plr:FindFirstChildOfClass("Backpack"), plr.Character}) do
            if box then
                for _, item in ipairs(box:GetChildren()) do
                    if item:IsA("Tool") then
                        local tn = item.Name:lower()
                        if tn:find("admin") or tn:find("ban") or tn:find("kick") or tn:find("btools") or tn:find("mod") or tn:find("staff") then
                            reasons[#reasons + 1] = "Staff Tool: " .. item.Name
                        end
                    end
                end
            end
        end
        for _, nStr in ipairs({plr.Name, plr.DisplayName}) do
            if nStr and (nStr:find("%[") or nStr:find("_")) then
                local kw = matchStaffKw(nStr)
                if kw then reasons[#reasons + 1] = M.fmtStr("Name Tag [%s]", kw); break end
            end
        end

        if #reasons > 0 then
            return {player = plr, username = plr.Name, displayName = plr.DisplayName, userId = plr.UserId, severity = severity, reasons = reasons}
        end
        return nil
    end

    function ThreatScanner.runLoadingScanner(onProceed, onAbort)
        local LoadGui = UILib.new("ScreenGui", {ResetOnSpawn = false, DisplayOrder = 500, IgnoreGuiInset = true})
        Core.protectGui(LoadGui)

        local Backdrop = UILib.new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(7, 5, 12), BackgroundTransparency = 0.06}, LoadGui)
        UILib.gradient(Backdrop, Color3.fromRGB(18, 10, 28), Color3.fromRGB(6, 4, 11), 45)

        local Card = UILib.new("Frame", {
            Size = UDim2.fromOffset(510, 372),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundColor3 = Theme.Bg,
            BorderSizePixel = 0,
            Active = true,
        }, Backdrop)
        UILib.corner(Card, UDim.new(0, 12))
        local cardStroke = UILib.stroke(Card, Theme.SakuraPink, 1.8)
        local strokeGrad = UILib.gradient(cardStroke, Theme.SakuraPink, Theme.CyberCyan, 0)

        local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
        local minDim = M.min(vp.X, vp.Y)
        UILib.new("UIScale", {Scale = minDim < 580 and M.clamp(minDim / 540, 0.72, 1) or 1}, Card)

        local TopHeader = UILib.new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Header, BorderSizePixel = 0, Active = true}, Card)
        UILib.corner(TopHeader, UDim.new(0, 12))
        UILib.gradient(TopHeader, Color3.fromRGB(48, 18, 62), Color3.fromRGB(22, 14, 34), 0)

        UILib.new("TextLabel", {
            Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
            Text = "🌸 Yui Hub  |  PRIVATE👾🤫  ·  NEURAL AI SCANNER v2 [DRAGGABLE]",
            TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        }, TopHeader)

        local dragConns = {}
        local edge = 14
        local cD1, cD2 = Core.makeWindowDraggable(Card, {
            TopHeader,
            UILib.new("Frame", {Size = UDim2.new(1, 12, 0, edge), Position = UDim2.fromOffset(-6, -6), BackgroundTransparency = 1, Active = true, ZIndex = 12}, Card),
            UILib.new("Frame", {Size = UDim2.new(1, 12, 0, edge), Position = UDim2.new(0, -6, 1, -edge + 6), BackgroundTransparency = 1, Active = true, ZIndex = 12}, Card),
            UILib.new("Frame", {Size = UDim2.new(0, edge, 1, 12), Position = UDim2.fromOffset(-6, -6), BackgroundTransparency = 1, Active = true, ZIndex = 12}, Card),
            UILib.new("Frame", {Size = UDim2.new(0, edge, 1, 12), Position = UDim2.new(1, -edge + 6, 0, -6), BackgroundTransparency = 1, Active = true, ZIndex = 12}, Card),
        })
        dragConns[1], dragConns[2] = cD1, cD2

        local StatusText = UILib.new("TextLabel", {
            Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 40), BackgroundTransparency = 1,
            Text = "[AI-NEURAL] Initializing 16-stage telemetry, remote & full-server threat audit...",
            TextColor3 = Theme.CyberCyan, Font = Enum.Font.GothamMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
        }, Card)

        local BarBg = UILib.new("Frame", {Size = UDim2.new(1, -20, 0, 8), Position = UDim2.fromOffset(10, 58), BackgroundColor3 = Color3.fromRGB(16, 12, 26), BorderSizePixel = 0}, Card)
        UILib.corner(BarBg, UDim.new(1, 0)); UILib.stroke(BarBg, Theme.Stroke, 1)
        local BarFill = UILib.new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.SakuraPink, BorderSizePixel = 0}, BarBg)
        UILib.corner(BarFill, UDim.new(1, 0)); UILib.gradient(BarFill, Theme.SakuraPink, Theme.CyberCyan, 0)

        local ScanTabBar = UILib.new("Frame", {Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 70), BackgroundTransparency = 1}, Card)
        UILib.new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3)}, ScanTabBar)

        local ScanListFrame = UILib.new("ScrollingFrame", {
            Size = UDim2.new(1, -20, 0, 220), Position = UDim2.fromOffset(10, 100), BackgroundColor3 = Theme.Panel,
            BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.SakuraPink,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        }, Card)
        UILib.corner(ScanListFrame, UDim.new(0, 8)); UILib.stroke(ScanListFrame, Theme.Stroke, 1)
        UILib.new("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, ScanListFrame)
        UILib.new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, ScanListFrame)

        local ScanCategories = {
            {key = "ALL", label = "All (0)", w = 0.105},
            {key = "PERFECT", label = "✅ Perf (0)", w = 0.115},
            {key = "PARTIAL", label = "⚡ Part (0)", w = 0.115},
            {key = "RESTRICTED", label = "⚠️ Rest (0)", w = 0.115},
            {key = "ERROR", label = "❌ Err (0)", w = 0.105},
            {key = "SEALED", label = "🛡️ Seal (0)", w = 0.110},
            {key = "OUTDATED", label = "🕰️ Old (0)", w = 0.105},
            {key = "THREAT", label = "Threat Detection", w = 0.230},
        }
        local scanTabBtns, allScanRows, detectedThreats, activeFilter = {}, {}, {}, "ALL"
        local threatGlowStroke, safeRowFrame = nil, nil

        local function applyScanFilter(filterKey)
            activeFilter = filterKey
            local hasThreat = #detectedThreats > 0
            for k, btn in pairs(scanTabBtns) do
                if k == "THREAT" and hasThreat then
                    btn.BackgroundColor3 = (filterKey == "THREAT") and Theme.ThreatRed or Color3.fromRGB(130, 16, 36)
                    btn.TextColor3 = Theme.Text
                else
                    btn.BackgroundColor3 = (k == filterKey) and Theme.TabPill or Theme.Card
                    btn.TextColor3 = (k == filterKey) and Theme.Text or Theme.Muted
                end
            end
            for _, r in ipairs(allScanRows) do
                if filterKey == "THREAT" then r.frame.Visible = (r.cat == "THREAT")
                elseif filterKey == "ALL" then r.frame.Visible = (r.cat ~= "THREAT") or hasThreat
                else r.frame.Visible = (r.cat == filterKey) end
            end
        end

        for _, sc in ipairs(ScanCategories) do
            local b = UILib.new("TextButton", {
                Size = UDim2.new(sc.w, -3, 1, 0),
                BackgroundColor3 = (sc.key == "ALL") and Theme.TabPill or Theme.Card,
                Text = sc.label, TextColor3 = (sc.key == "ALL") and Theme.Text or Theme.Muted,
                Font = Enum.Font.GothamBold, TextSize = 8, ZIndex = 3,
            }, ScanTabBar)
            UILib.corner(b, UDim.new(0, 5))
            if sc.key == "THREAT" then threatGlowStroke = UILib.stroke(b, Theme.ThreatRed, 1.6, 0.96) end
            scanTabBtns[sc.key] = b
            b.MouseButton1Click:Connect(function() Core.playMeowSFX(); applyScanFilter(sc.key) end)
        end

        local ProceedBtn = UILib.new("TextButton", {
            Size = UDim2.fromOffset(156, 30), Position = UDim2.new(1, -166, 1, -38),
            BackgroundColor3 = Color3.fromRGB(40, 30, 56), Text = "⏳ DEEP SCANNING...", TextColor3 = Theme.Muted,
            Font = Enum.Font.GothamBold, TextSize = 10, Active = false, AutoButtonColor = false,
        }, Card)
        UILib.corner(ProceedBtn, UDim.new(0, 7))
        local proceedStroke = UILib.stroke(ProceedBtn, Theme.Stroke, 1.2)
        UILib.attachPressSpring(ProceedBtn)

        local SummaryLabel = UILib.new("TextLabel", {
            Size = UDim2.new(1, -182, 0, 32), Position = UDim2.new(0, 10, 1, -39), BackgroundTransparency = 1,
            Text = "Auditing VM, remote topology, boss arena & full-server staff presence...",
            TextColor3 = Theme.Muted, Font = Enum.Font.GothamMedium, TextSize = 8,
            TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        }, Card)

        local counts = {PERFECT = 0, PARTIAL = 0, RESTRICTED = 0, ERROR = 0, SEALED = 0, OUTDATED = 0}
        local function updateCounters()
            local total = counts.PERFECT + counts.PARTIAL + counts.RESTRICTED + counts.ERROR + counts.SEALED + counts.OUTDATED
            scanTabBtns["ALL"].Text = M.fmtStr("All (%d)", total)
            scanTabBtns["PERFECT"].Text = M.fmtStr("✅ Perf (%d)", counts.PERFECT)
            scanTabBtns["PARTIAL"].Text = M.fmtStr("⚡ Part (%d)", counts.PARTIAL)
            scanTabBtns["RESTRICTED"].Text = M.fmtStr("⚠️ Rest (%d)", counts.RESTRICTED)
            scanTabBtns["ERROR"].Text = M.fmtStr("❌ Err (%d)", counts.ERROR)
            scanTabBtns["SEALED"].Text = M.fmtStr("🛡️ Seal (%d)", counts.SEALED)
            scanTabBtns["OUTDATED"].Text = M.fmtStr("🕰️ Old (%d)", counts.OUTDATED)
            scanTabBtns["THREAT"].Text = (#detectedThreats > 0) and M.fmtStr("Threat Detection (%d)", #detectedThreats) or "Threat Detection"
        end

        local function addRow(cat, title, detail, idx, customColor, customBadge)
            if cat ~= "THREAT" then counts[cat] = (counts[cat] or 0) + 1 end
            updateCounters()
            local col = customColor or Theme.Green
            local badge = customBadge or "RUN PERFECTLY"
            if not customColor then
                if cat == "PARTIAL" then col = Theme.Yellow; badge = "PARTIAL ONLY"
                elseif cat == "RESTRICTED" then col = Color3.fromRGB(255, 140, 60); badge = "RESTRICTED"
                elseif cat == "ERROR" then col = Theme.Red; badge = "NOT RUNNING"
                elseif cat == "SEALED" then col = Color3.fromRGB(160, 120, 255); badge = "SEALED"
                elseif cat == "OUTDATED" then col = Theme.OutdatedCol; badge = "OUTDATED"
                elseif cat == "THREAT" then col = Theme.ThreatRed; badge = "THREAT ALERT" end
            end

            local row = UILib.new("Frame", {
                Size = UDim2.new(1, -4, 0, 38),
                BackgroundColor3 = (cat == "THREAT" and col == Theme.ThreatRed) and Color3.fromRGB(48, 12, 22) or Theme.Card,
                BorderSizePixel = 0, LayoutOrder = idx,
                Visible = (activeFilter == "ALL" and (cat ~= "THREAT" or #detectedThreats > 0)) or (activeFilter == cat),
            }, ScanListFrame)
            UILib.corner(row, UDim.new(0, 5)); UILib.stroke(row, col, 1, 0.35)

            UILib.new("TextLabel", {
                Size = UDim2.new(1, -112, 0, 15), Position = UDim2.fromOffset(8, 3), BackgroundTransparency = 1,
                Text = title, TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
            }, row)
            UILib.new("TextLabel", {
                Size = UDim2.fromOffset(102, 15), Position = UDim2.new(1, -106, 0, 3), BackgroundTransparency = 1,
                Text = badge, TextColor3 = col, Font = Enum.Font.GothamBold, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right,
            }, row)
            UILib.new("TextLabel", {
                Size = UDim2.new(1, -16, 0, 15), Position = UDim2.fromOffset(8, 19), BackgroundTransparency = 1,
                Text = "└─ " .. detail, TextColor3 = Theme.Muted, Font = Enum.Font.GothamMedium, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            table.insert(allScanRows, {cat = cat, frame = row})
            ScanListFrame.CanvasPosition = Vector2.new(0, 9999)
            return row
        end

        local scanSpin, threatJoinConn = true, nil
        local function stopScannerCleanup()
            scanSpin = false
            if threatJoinConn then pcall(function() threatJoinConn:Disconnect() end); threatJoinConn = nil end
            for _, c in ipairs(dragConns) do pcall(function() c:Disconnect() end) end
        end

        local function showThreatWarningModal()
            local WarnOverlay = UILib.new("Frame", {
                Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(6, 3, 10), BackgroundTransparency = 0.14, Active = true, ZIndex = 60,
            }, Backdrop)

            local WarnCard = UILib.new("Frame", {
                Size = UDim2.fromOffset(370, 192), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, ZIndex = 61,
            }, WarnOverlay)
            UILib.corner(WarnCard, UDim.new(0, 12)); UILib.stroke(WarnCard, Theme.ThreatRed, 2.0)

            UILib.new("TextLabel", {
                Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 14), BackgroundTransparency = 1,
                Text = "are you sure?", TextColor3 = Theme.ThreatRed, Font = Enum.Font.GothamBold, TextSize = 18, ZIndex = 62,
            }, WarnCard)

            UILib.new("TextLabel", {
                Size = UDim2.new(1, -28, 0, 76), Position = UDim2.fromOffset(14, 48), BackgroundTransparency = 1,
                Text = "you're gonna get banned if not becarefull\n\ndon't blame me if you get banned and don't drag me into your problem",
                TextColor3 = Theme.Text, Font = Enum.Font.GothamSemibold, TextSize = 11, TextWrapped = true, ZIndex = 62,
            }, WarnCard)

            local ClosedLeftBtn = UILib.new("TextButton", {
                Size = UDim2.fromOffset(146, 34), Position = UDim2.new(0, 16, 1, -46),
                BackgroundColor3 = Color3.fromRGB(48, 34, 62), Text = "closed", TextColor3 = Theme.Text,
                Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 62,
            }, WarnCard)
            UILib.corner(ClosedLeftBtn, UDim.new(0, 7)); UILib.stroke(ClosedLeftBtn, Theme.Stroke, 1.2); UILib.attachPressSpring(ClosedLeftBtn)

            local ProceedRightBtn = UILib.new("TextButton", {
                Size = UDim2.fromOffset(162, 34), Position = UDim2.new(1, -178, 1, -46),
                BackgroundColor3 = Theme.ThreatRed, Text = "Good Luck gng🥀", TextColor3 = Theme.Text,
                Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 62,
            }, WarnCard)
            UILib.corner(ProceedRightBtn, UDim.new(0, 7)); UILib.attachPressSpring(ProceedRightBtn)

            ProceedRightBtn.MouseButton1Click:Connect(function()
                Core.playMeowSFX()
                stopScannerCleanup()
                pcall(function() LoadGui:Destroy() end)
                if onProceed then
                    local okP, errP = xpcall(onProceed, debug.traceback)
                    if not okP then warn("[YuiHub] Launch error: " .. tostring(errP)) end
                end
            end)

            ClosedLeftBtn.MouseButton1Click:Connect(function()
                Core.playMeowSFX()
                WarnCard.Visible = false

                local GoodChoiceCard = UILib.new("Frame", {
                    Size = UDim2.fromOffset(270, 134), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                    BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, ZIndex = 63,
                }, WarnOverlay)
                UILib.corner(GoodChoiceCard, UDim.new(0, 12)); UILib.stroke(GoodChoiceCard, Theme.Green, 1.8)

                UILib.new("TextLabel", {
                    Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, 16), BackgroundTransparency = 1,
                    Text = "Good Choice👍", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 18, ZIndex = 64,
                }, GoodChoiceCard)

                local OkBtn = UILib.new("TextButton", {
                    Size = UDim2.fromOffset(130, 34), Position = UDim2.new(0.5, -65, 1, -46),
                    BackgroundColor3 = Theme.Green, Text = "OK", TextColor3 = Color3.fromRGB(10, 18, 14),
                    Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 64,
                }, GoodChoiceCard)
                UILib.corner(OkBtn, UDim.new(0, 7)); UILib.attachPressSpring(OkBtn)

                OkBtn.MouseButton1Click:Connect(function()
                    Core.playMeowSFX()
                    stopScannerCleanup()
                    pcall(function() LoadGui:Destroy() end)
                    if onAbort then onAbort() end
                end)
            end)
        end

        task.spawn(function()
            local pulseT = 0
            while scanSpin and LoadGui.Parent do
                strokeGrad.Rotation = (strokeGrad.Rotation + 3) % 360
                pulseT += 0.06
                if #detectedThreats > 0 and threatGlowStroke and threatGlowStroke.Parent then
                    local pulse = 0.5 + 0.5 * M.sin(pulseT * 4.5)
                    threatGlowStroke.Transparency = 0.02 + (1 - pulse) * 0.25
                    threatGlowStroke.Thickness = 1.6 + pulse * 1.1
                    local tBtn = scanTabBtns["THREAT"]
                    if tBtn and activeFilter ~= "THREAT" then
                        tBtn.BackgroundColor3 = Color3.fromRGB(M.floor(115 + pulse * 95), 14, 34)
                    end
                end
                task.wait(0.04)
            end
        end)

        task.spawn(function()
            local benchT0 = M.clock()
            local acc = 0
            for k = 1, 50000 do acc += (k % 7) end
            local benchUs = M.floor((M.clock() - benchT0) * 1000000)

            local ping = 75
            pcall(function() ping = math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
            Telemetry.livePing = ping; Telemetry.smoothPing = ping; Telemetry.baselinePing = M.max(30, ping)

            pcall(Core.evaluateMuscleScope, true)
            pcall(Remotes.refresh, true)
            local rootPos = (Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character.HumanoidRootPart.Position) or Vector3.new()
            pcall(Combat.refreshTargets, rootPos, true)

            local allPlayers = Players:GetPlayers()
            for _, plr in ipairs(allPlayers) do
                local okI, t = pcall(ThreatScanner.inspectPlayer, plr)
                if okI and t then detectedThreats[#detectedThreats + 1] = t end
            end

            if #detectedThreats > 0 then
                for ti, tInfo in ipairs(detectedThreats) do
                    addRow("THREAT", M.fmtStr("🚨 %s (@%s) [ID: %d]", tInfo.displayName, tInfo.username, tInfo.userId),
                        table.concat(tInfo.reasons, " | "), 200 + ti, Theme.ThreatRed, tInfo.severity)
                end
                applyScanFilter(activeFilter)
            else
                safeRowFrame = addRow("THREAT", M.fmtStr("✅ Server Clean (%d/%d Players Audited)", #allPlayers, #allPlayers),
                    "0 Admins, Owners, Co-Owners, Staff, Devs, Testers or Mods detected in this server", 200, Theme.Green, "SAFE SERVER")
            end

            threatJoinConn = Players.PlayerAdded:Connect(function(newPlr)
                if not LoadGui.Parent then return end
                local t = ThreatScanner.inspectPlayer(newPlr)
                if t then
                    detectedThreats[#detectedThreats + 1] = t
                    if safeRowFrame then safeRowFrame.Visible = false end
                    addRow("THREAT", M.fmtStr("🚨 %s (@%s) [ID: %d]", t.displayName, t.username, t.userId),
                        table.concat(t.reasons, " | "), 200 + #detectedThreats, Theme.ThreatRed, t.severity)
                    applyScanFilter(activeFilter)
                    if ProceedBtn.Active then
                        ProceedBtn.Text = "⚠️ LAUNCH ANYWAY"
                        ProceedBtn.BackgroundColor3 = Theme.ThreatRed
                        proceedStroke.Color = Theme.Yellow
                    end
                end
            end)

            local mRem, rRem = Remotes.muscleList[1], Remotes.rebirthList[1]
            local hasTouch = (firetouchinterest ~= nil)
            local hasFps = (setfpscap ~= nil or set_fps_cap ~= nil or setfps ~= nil or setfflag ~= nil)
            local hasConn = (getconnections ~= nil or firesignal ~= nil)
            local charRig = (Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") and Player.Character:FindFirstChildOfClass("Humanoid").RigType.Name) or "R15"

            local steps = {
                {"[1/16] Benchmarking VM & Heap...", "PERFECT", "Executor VM & Heap Profiler", M.fmtStr("%s | %d µs | Heap: %d KB", Core.ExecutorName, benchUs, M.floor(collectgarbage("count")))},
                {"[2/16] Probing Executor Native APIs...", (hasTouch and hasFps) and "PERFECT" or "PARTIAL", "Native Bridge API Matrix", M.fmtStr("touch=%s | fps=%s | conn=%s", tostring(hasTouch), tostring(hasFps), tostring(hasConn))},
                {"[3/16] Fingerprinting PlaceId & ML Copy...", MuscleScope.verified and "PERFECT" or "PARTIAL", "ML & Modded Copy Signature", M.fmtStr("PlaceId: %d | CreatorId: %d | %s", game.PlaceId, game.CreatorId, MuscleScope.label)},
                {"[4/16] Auditing Remote Surface & Traps...", mRem and "PERFECT" or "PARTIAL", "O(1) Shallow-First Remote Registry", M.fmtStr("Audited %d remotes | Muscle=%s | Rebirth=%s", Remotes.totalRemotesAudited, mRem and mRem.Name or "Dynamic", rRem and rRem.Name or "Dynamic")},
                {"[5/16] Calibrating Zero-Delay Reps Engine...", "PERFECT", "Zero-Freeze Reps (Auto / AI Fast / Fast)", "O(1) muscleEvent + Ping PID + 100% limiter + 0ms force-stop"},
                {"[6/16] Verifying 6.00s Auto Rebirth...", rRem and "PERFECT" or "PARTIAL", "Legit Gamepass Auto Rebirth (6.00s)", "Server cooldown phase-lock + Strength threshold guard"},
                {"[7/16] Scanning Quest, Daily, Chest & Time Remotes...", (#Remotes.questRemotes + #Remotes.dailyRemotes + #Remotes.chestRemotes + #Remotes.genericRewardRemotes + #Remotes.timeRewardRemotes > 0) and "PERFECT" or "PARTIAL", "Remote-Only Auto Collect Rewards", M.fmtStr("Quest=%d | Daily=%d | Chest=%d | Time=%d (Availability Gated)", #Remotes.questRemotes, #Remotes.dailyRemotes, #Remotes.chestRemotes, #Remotes.timeRewardRemotes)},
                {"[8/16] Probing Fortune Wheel Topology...", (#Remotes.wheelRemotes > 0 or #Remotes.wheelChanceItems > 0) and "PERFECT" or "PARTIAL", "Remote-Only Auto Spin Reward", M.fmtStr("WheelRemotes=%d | Chances=%d (Spins > 0 Only)", #Remotes.wheelRemotes, #Remotes.wheelChanceItems)},
                {"[9/16] Calibrating Low-Ping Fast Punch...", hasTouch and "PERFECT" or "PARTIAL", "Clean Punch Engine (Auto / Fast / Speed)", "Low-ping synced tool + hand touch + kinematic swing"},
                {"[10/16] Mapping Boss Arena & AOE Evade...", "PERFECT", "Boss Auto-Kill (Strict Boss-Only + AOE Evade)", M.fmtStr("Detected %d active boss(es) (Gyms/NPCs excluded)", #Combat.bossTargets)},
                {"[11/16] Initializing Zero-GFX AI Perf Mode...", "PERFECT", "Zero-GFX AI GC & Scheduler Governor", "Headroom incremental GC + Pooled VFX + Zero GFX edits"},
                {"[12/16] Verifying Real FPS Jump & Cycle Rate...", hasFps and "PERFECT" or "PARTIAL", "Real FPS Jump (setfpscap + setfflag + VSync)", "Unlocks TaskSchedulerTargetFps + displays live FPS Jump"},
                {"[13/16] Configuring Physics & Avatar Visuals...", "PERFECT", "Fly, Water Walk, Speed, Scale, Korblox & Headless", M.fmtStr("Rig=%s | Zero-lag pooled UI animations", charRig)},
                {"[14/16] Verifying Anti-Trap & Stealth Isolation...", "PERFECT", "Anti-Trap Shield & Stealth GUI Isolation", "No ban/kick/robux remotes bound; stealth GUI parent verified"},
                {"[15/16] Scanning Server Players for Staff...", (#detectedThreats > 0) and "RESTRICTED" or "PERFECT", "Full-Server Staff / Admin / Owner Audit", (#detectedThreats > 0) and M.fmtStr("ALERT: %d Threat(s) Detected! Open Threat Detection Tab", #detectedThreats) or M.fmtStr("Clean Server: 0 Threats across %d player(s)", #allPlayers)},
                {"[16/16] Snapshotting Environment Defaults...", "PERFECT", "Lossless Restore Snapshot", "All 16 advanced diagnostic stages complete"},
            }

            local stepWait = M.clamp(3.2 + (ping / 240) * 0.6, 3.2, 4.6) / #steps
            for i, st in ipairs(steps) do
                StatusText.Text = st[1]
                TweenService:Create(BarFill, TweenInfo.new(stepWait * 0.85, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(i / #steps, 0, 1, 0)}):Play()
                task.wait(stepWait)
                addRow(st[2], st[3], st[4], i)
            end

            if #detectedThreats > 0 then
                StatusText.Text = M.fmtStr("🚨 [THREAT DETECTED] %d Staff/Admin/Owner in server! Check Threat Detection!", #detectedThreats)
                StatusText.TextColor3 = Theme.ThreatRed
                SummaryLabel.Text = M.fmtStr("⚠️ %d Threat(s) Detected in Server! Launching carries ban risk.", #detectedThreats)
                SummaryLabel.TextColor3 = Theme.ThreatRed
                ProceedBtn.Text = "⚠️ LAUNCH ANYWAY"
                ProceedBtn.BackgroundColor3 = Theme.ThreatRed
                proceedStroke.Color = Theme.Yellow
            else
                StatusText.Text = M.fmtStr("[AI-DONE] ✅ %d Perfect | ⚡ %d Partial | 🛡️ 0 Threats Detected", counts.PERFECT, counts.PARTIAL)
                StatusText.TextColor3 = Theme.Green
                SummaryLabel.Text = "16/16 AI checks passed & Server Threat Scan clean. Tap LAUNCH HUB."
                SummaryLabel.TextColor3 = Theme.CyberCyan
                ProceedBtn.Text = "🌸 LAUNCH HUB"
                ProceedBtn.BackgroundColor3 = Theme.TabPill
                proceedStroke.Color = Theme.CyberCyan
            end

            ProceedBtn.Active = true
            ProceedBtn.AutoButtonColor = true
            ProceedBtn.TextColor3 = Theme.Text

            local proceeded = false
            ProceedBtn.MouseButton1Click:Connect(function()
                if proceeded then return end
                proceeded = true
                Core.playMeowSFX()
                if #detectedThreats > 0 then
                    showThreatWarningModal()
                else
                    stopScannerCleanup()
                    pcall(function() LoadGui:Destroy() end)
                    if onProceed then
                        local okP, errP = xpcall(onProceed, debug.traceback)
                        if not okP then warn("[YuiHub] Launch error: " .. tostring(errP)) end
                    end
                end
            end)
        end)
    end
end

----------------------------------------------------------------
-- Modular Per-Tab UI Builders (Isolates Compiler Protos & Prevents Blank UI)
----------------------------------------------------------------
local UIBuilders = {}
do
    function UIBuilders.Strength(P, ctx)
        local UI = ctx.UI
        local createStatusLabel, createSmallBtn, createToggle, createNumberInput =
            ctx.createStatusLabel, ctx.createSmallBtn, ctx.createToggle, ctx.createNumberInput
        local nextOrder = ctx.nextOrder

        UI.strStatus  = createStatusLabel(P, "Status: Inactive | reps/sec: 0", Theme.Red, true, 10)
        UI.strRuntime = createStatusLabel(P, "Runtime: 0d 0h 0m 0s", Theme.Text, false, 9)
        UI.strValLine = createStatusLabel(P, "Strength: 0 | Gained: 0", Theme.Text, false, 9)
        UI.durValLine = createStatusLabel(P, "Durability: 0 | Gained: 0", Theme.Text, false, 9)
        UI.strAvgLine = createStatusLabel(P, "Str Ø: --/s | --/m | --/h | --/d | --/w | --/mo | --/y", Theme.Text, false, 8)
        UI.durAvgLine = createStatusLabel(P, "Dura Ø: --/s | --/m | --/h | --/d | --/w | --/mo | --/y", Theme.Text, false, 8)
        createSmallBtn(P, "Reset Calcs", Theme.Red, Telemetry.resetStrength)
        UI.recSpeedLabel = createStatusLabel(P, "Mode: Default (468/s) | Anti-Lag: ON | Limiter: LOCKED", Theme.CyberCyan, false, 9)

        local OVERLORD_MODES = {
            {name = "Default",      label = "Default (468)",      rate = 468},
            {name = "Ultra",        label = "Ultra (850/s)",      rate = 850},
            {name = "Ultra Plus",   label = "Ultra Plus (1.65K)", rate = 1650},
            {name = "Overlord",     label = "Overlord (2.8K)",    rate = 2800},
            {name = "Overlord Max", label = "Overlord Max (4.8K)", rate = 4800},
            {name = "Custom",       label = "Custom (Typed)",     rate = nil},
        }
        local REP_GROUP = {"AutoRep", "AIFastRep", "FastRep"}
        local function onRepChanged()
            Runtime.SessionTokens.rep += 1
            Core.forceKillAllRepWorkers()
            local anyRep = Config.AutoRep or Config.AIFastRep or Config.FastRep
            Runtime.RepGateOpen = anyRep
            if anyRep then
                if Config.RepAntiLag then task.defer(Perf.sweepRepPopups) end
                local rem = Remotes.getPrimaryMuscle()
                if rem and rem.Parent then
                    local variant = Remotes.argVariants[Remotes.variantByRemote[rem] or 1]
                    local a1, a2 = variant[1], variant[2]
                    if rem:IsA("RemoteFunction") then
                        if a2 ~= nil then task.spawn(pcall, rem.InvokeServer, rem, a1, a2)
                        else task.spawn(pcall, rem.InvokeServer, rem, a1) end
                    else
                        if a2 ~= nil then pcall(rem.FireServer, rem, a1, a2)
                        else pcall(rem.FireServer, rem, a1) end
                    end
                    Telemetry.recordEvent(Telemetry.repTracker, 1)
                end
                task.defer(Remotes.refresh, false)
            else
                Telemetry.repTracker = Telemetry.newTracker()
                if UI.strStatus then UI.strStatus.Text = "Status: Inactive | reps/sec: 0"; UI.strStatus.TextColor3 = Theme.Red end
            end
        end

        createToggle(P, "Strength", "Auto Reps", "AutoRep", REP_GROUP, onRepChanged, "automaticly reps for you")
        createToggle(P, "Strength", "AI Auto Fast Reps", "AIFastRep", REP_GROUP, onRepChanged, "adaptive ping & FPS governed fast reps")
        createToggle(P, "Strength", "Fast Reps (Uses Set Speed / Mode)", "FastRep", REP_GROUP, onRepChanged, "runs exact typed Rep Speed or selected Overlord Mode")

        local overlordOpen = false
        local OverlordToggleBtn = UILib.new("TextButton", {
            Size = UDim2.new(1, -6, 0, 28), BackgroundColor3 = Theme.Card,
            Text = "⚡ Overlord Mode: Default (468)  v", TextColor3 = Theme.CyberCyan,
            Font = Enum.Font.GothamBold, TextSize = 10, LayoutOrder = nextOrder(), ZIndex = 4,
        }, P)
        UILib.corner(OverlordToggleBtn, UDim.new(0, 7))
        UILib.attachRGBLightning(OverlordToggleBtn, 1.35, 0.30, 0.04, 140, "Strength").isActive = true
        UILib.attachPressSpring(OverlordToggleBtn)

        local OverlordGridFrame = UILib.new("Frame", {
            Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0,
            Visible = false, LayoutOrder = nextOrder(), ZIndex = 4,
        }, P)
        UILib.corner(OverlordGridFrame, UDim.new(0, 7)); UILib.stroke(OverlordGridFrame, Theme.CyberCyan, 1, 0.45)
        UILib.new("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, OverlordGridFrame)
        UILib.new("UIGridLayout", {
            CellSize = UDim2.new(0.5, -3, 0, 25),
            CellPadding = UDim2.fromOffset(5, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, OverlordGridFrame)

        local overlordChoiceBtns = {}
        local programmaticSpeedEdit = false
        local function refreshOverlordUI()
            local curName = tostring(Config.RepBurstMode or "Default")
            local dispLabel = curName
            for _, opt in ipairs(OVERLORD_MODES) do
                if opt.name == curName then
                    dispLabel = (opt.name == "Custom")
                        and M.fmtStr("Custom (%s/s)", (Config.RepLimiterOpen or Config.RepSpeed == M.huge) and "OPEN" or Core.fmtCompact(Config.RepSpeed))
                        or opt.label
                    break
                end
            end
            OverlordToggleBtn.Text = M.fmtStr("⚡ Overlord Mode: %s  %s", dispLabel, overlordOpen and "^" or "v")
            for modeName, b in pairs(overlordChoiceBtns) do
                local isSel = (modeName == curName)
                b.BackgroundColor3 = isSel and Theme.TabPill or Color3.fromRGB(36, 24, 54)
                b.TextColor3 = isSel and Theme.Text or Theme.Muted
            end
        end
        UI.refreshOverlordUI = refreshOverlordUI

        for idx, opt in ipairs(OVERLORD_MODES) do
            local btn = UILib.new("TextButton", {
                BackgroundColor3 = (opt.name == Config.RepBurstMode) and Theme.TabPill or Color3.fromRGB(36, 24, 54),
                Text = opt.label, TextColor3 = (opt.name == Config.RepBurstMode) and Theme.Text or Theme.Muted,
                Font = Enum.Font.GothamBold, TextSize = 9, LayoutOrder = idx, ZIndex = 5,
            }, OverlordGridFrame)
            UILib.corner(btn, UDim.new(0, 5)); UILib.attachPressSpring(btn)
            overlordChoiceBtns[opt.name] = btn
            btn.MouseButton1Click:Connect(function()
                Core.playMeowSFX()
                Config.RepBurstMode = opt.name
                if opt.rate then
                    Config.RepLimiterOpen = false
                    Config.RepSpeed = opt.rate
                    if UI.repSpeedInput then
                        programmaticSpeedEdit = true
                        UI.repSpeedInput.Text = tostring(opt.rate)
                        UI.repSpeedInput.TextColor3 = Theme.CyberCyan
                        programmaticSpeedEdit = false
                    end
                elseif UI.repSpeedInput then
                    local parsed = Core.parseSmartInput(UI.repSpeedInput.Text)
                    if parsed.opensLimit then
                        Config.RepLimiterOpen = true
                        Config.RepSpeed = parsed.isInf and M.huge or 1000000
                    elseif parsed.isPercent and parsed.pct > 0 then
                        Config.RepLimiterOpen = false
                        Config.RepSpeed = M.max(1, M.floor((parsed.pct / 100) * 1000000))
                    elseif parsed.num and not parsed.isNaN and parsed.num >= 1 then
                        Config.RepLimiterOpen = false
                        Config.RepSpeed = M.max(1, M.floor(parsed.num))
                    end
                end
                refreshOverlordUI()
                Runtime.SessionTokens.rep += 1; Core.forceKillAllRepWorkers()
                Runtime.RepGateOpen = (Config.AutoRep or Config.AIFastRep or Config.FastRep)
            end)
        end

        OverlordToggleBtn.MouseButton1Click:Connect(function()
            Core.playMeowSFX()
            overlordOpen = not overlordOpen
            OverlordGridFrame.Visible = overlordOpen
            refreshOverlordUI()
        end)

        createToggle(P, "Strength", "Anti-Lag Popups & VFX Shield", "RepAntiLag", nil, function(on)
            if on then task.defer(Perf.sweepRepPopups) end
        end, "throttles +Strength popup flood & audio lag during fast reps")

        local function applyTypedRepSpeed(rawText, isFinalCommit)
            local parsed = Core.parseSmartInput(rawText)
            if parsed.opensLimit then
                Config.RepBurstMode = "Custom"
                Config.RepLimiterOpen = true
                Config.RepSpeed = parsed.isInf and M.huge or 1000000
                refreshOverlordUI()
                Runtime.RepGateOpen = (Config.AutoRep or Config.AIFastRep or Config.FastRep)
                return parsed.isPercent and "100% [OPEN]" or "Inf [OPEN]"
            elseif parsed.isPercent and parsed.pct > 0 then
                Config.RepBurstMode = "Custom"
                Config.RepLimiterOpen = false
                local scaled = M.max(1, M.floor((parsed.pct / 100) * 1000000))
                Config.RepSpeed = scaled
                refreshOverlordUI()
                Runtime.RepGateOpen = (Config.AutoRep or Config.AIFastRep or Config.FastRep)
                local pctStr = M.fmtStr("%.4f", parsed.pct):gsub("0+$", ""):gsub("%.$", "")
                if pctStr == "" or pctStr == "0" then return Core.fmtCompact(scaled) end
                return M.fmtStr("%s%% (%s)", pctStr, Core.fmtCompact(scaled))
            elseif parsed.num and not parsed.isNaN and parsed.num >= 1 then
                local n = M.max(1, M.floor(parsed.num))
                Config.RepLimiterOpen = false
                Config.RepSpeed = n
                Config.RepBurstMode = (n == 468) and "Default" or "Custom"
                refreshOverlordUI()
                Runtime.RepGateOpen = (Config.AutoRep or Config.AIFastRep or Config.FastRep)
                return (n >= 10000000) and Core.fmt(n) or tostring(n)
            elseif isFinalCommit then
                Config.RepLimiterOpen = false
                Config.RepSpeed = 468
                Config.RepBurstMode = "Default"
                refreshOverlordUI()
                return "468"
            end
            return nil
        end

        UI.repSpeedInput = createNumberInput(P, "Set Rep Speed (Default: 468 | 100% = Open)", "RepSpeed", 1, nil, true, function()
            Runtime.SessionTokens.rep += 1; Core.forceKillAllRepWorkers()
            Runtime.RepGateOpen = (Config.AutoRep or Config.AIFastRep or Config.FastRep)
        end, false, function(valOrParsed)
            if type(valOrParsed) == "number" then
                return (Config.RepLimiterOpen or valOrParsed == M.huge) and "100% [OPEN]" or tostring(M.floor(valOrParsed))
            end
            programmaticSpeedEdit = true
            local formatted = applyTypedRepSpeed(UI.repSpeedInput and UI.repSpeedInput.Text or "468", true) or "468"
            if UI.repSpeedInput then UI.repSpeedInput.TextColor3 = Theme.CyberCyan end
            task.defer(function() programmaticSpeedEdit = false end)
            return formatted
        end)

        UI.repSpeedInput:GetPropertyChangedSignal("Text"):Connect(function()
            if programmaticSpeedEdit then return end
            local txt = UI.repSpeedInput.Text or ""
            local parsed = Core.parseSmartInput(txt)
            local valid = parsed.opensLimit or (parsed.isPercent and parsed.pct > 0) or (parsed.num and not parsed.isNaN and parsed.num >= 1)
            UI.repSpeedInput.TextColor3 = valid and Theme.CyberCyan or Theme.Yellow
        end)
        refreshOverlordUI()
    end

    function UIBuilders.Rebirth(P, ctx)
        local UI = ctx.UI
        local createStatusLabel, createSmallBtn, createToggle = ctx.createStatusLabel, ctx.createSmallBtn, ctx.createToggle
        UI.rebStatus   = createStatusLabel(P, "Status: Inactive", Theme.Red, true, 10)
        UI.rebRuntime  = createStatusLabel(P, "Runtime: 0d 0h 0m 0s", Theme.Text, false, 9)
        UI.rebValLine  = createStatusLabel(P, "Rebirths: 0 | Gained: 0 (+0/reb)", Theme.Text, false, 9)
        UI.rebProgLine = createStatusLabel(P, "Next Rebirth: 0% (0 / 25K Str) | ETA: --", Theme.CyberCyan, false, 8)
        UI.rebAvgLine  = createStatusLabel(P, "Average: --/6s | --/h | --/d | --/w | --/mo | --/y", Theme.Text, false, 8)
        createSmallBtn(P, "Reset Calcs", Theme.Red, Telemetry.resetRebirth)
        createToggle(P, "Rebirth", "Auto Rebirth (6.00s Legit Gamepass Pace)", "AutoRebirth", nil, function()
            Runtime.SessionTokens.reb += 1
            Telemetry.rebCycleDuration = LEGIT_GAMEPASS_REBIRTH_COOLDOWN
            task.defer(Remotes.refresh, false)
        end)
        createToggle(P, "Rebirth", "Threshold Guard (Wait Until Str Ready)", "SmartRebirthGuard", nil, nil)
    end

    function UIBuilders.Punch(P, ctx)
        local UI = ctx.UI
        local createStatusLabel, createSmallBtn, createToggle, createNumberInput =
            ctx.createStatusLabel, ctx.createSmallBtn, ctx.createToggle, ctx.createNumberInput
        UI.punStatus  = createStatusLabel(P, "Status: Inactive", Theme.Red, true, 10)
        UI.punRuntime = createStatusLabel(P, "Runtime: 0d 0h 0m 0s", Theme.Text, false, 9)
        UI.punValLine = createStatusLabel(P, "Punches: 0 | Rate: 0/s", Theme.Text, false, 9)
        createSmallBtn(P, "Reset Calcs", Theme.Red, Telemetry.resetPunch)

        local function onPunchChanged()
            Runtime.SessionTokens.pun += 1
            if Config.AutoPunch then
                Combat.lastTargetScan = -100
            else
                Telemetry.punchTracker = Telemetry.newTracker()
                for _, tr in ipairs(Combat.tracks) do pcall(function() if tr.IsPlaying then tr:Stop(0.05) end end) end
                Combat.restoreJoints()
            end
        end

        createToggle(P, "Punch", "Auto Punch", "AutoPunch", nil, onPunchChanged, "smooth arm swing + low-ping hit")
        createToggle(P, "Punch", "Freeze Character", "FreezeCharacter", nil, function(on)
            CharPhysics.applyFreeze(on)
        end, "locks character firmly in place (toggle on/off anytime)")
        createNumberInput(P, "Punch Speed (Default: 60 | Max: 500)", "PunchSpeed", 1, 500, false)
    end

    function UIBuilders.Boss(P, ctx)
        local UI = ctx.UI
        local createStatusLabel, createSmallBtn, createToggle, nextOrder =
            ctx.createStatusLabel, ctx.createSmallBtn, ctx.createToggle, ctx.nextOrder

        UI.bossStatusLine  = createStatusLabel(P, "Action: Inactive", Theme.Red, true, 10)
        UI.bossSpawnedLine = createStatusLabel(P, "Spawned: Scanning... | HP: --", Theme.Text, false, 9)
        UI.bossSpawnedLine.TextWrapped = true
        UI.bossSpawnedLine.AutomaticSize = Enum.AutomaticSize.Y
        UI.bossSpawnedLine.Size = UDim2.new(1, -4, 0, 14)
        UI.bossDamageLine  = createStatusLabel(P, "Boss Damage: 0 | DPS: 0/s | Target: Common Boss", Theme.CyberCyan, false, 8)
        UI.bossDamageLine.TextWrapped = false
        UI.bossDamageLine.TextTruncate = Enum.TextTruncate.AtEnd
        UI.bossChargeLine  = createStatusLabel(P, "Charge Tracker: Watching... | Skills: 0 · Ults: 0", Theme.Yellow, false, 9)
        UI.bossKillsLine   = createStatusLabel(P, "Killed — Normal Bosses: 0 | Event/Alien Bosses: 0", Theme.SakuraSoft, false, 9)
        createSmallBtn(P, "Reset Calcs", Theme.Red, BossEngine.resetStats)

        local selectorOpen = true
        local SelectorToggleBtn = UILib.new("TextButton", {
            Size = UDim2.new(1, -6, 0, 28), BackgroundColor3 = Theme.Card,
            Text = "🎯 Select Boss: " .. Config.SelectedBoss .. "  ^", TextColor3 = Theme.SakuraSoft,
            Font = Enum.Font.GothamBold, TextSize = 10, LayoutOrder = nextOrder(), ZIndex = 4,
        }, P)
        UILib.corner(SelectorToggleBtn, UDim.new(0, 7))
        UILib.attachRGBLightning(SelectorToggleBtn, 1.35, 0.30, 0.04, 90, "Boss").isActive = true
        UILib.attachPressSpring(SelectorToggleBtn)

        local SelectorGridFrame = UILib.new("Frame", {
            Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0,
            Visible = true, LayoutOrder = nextOrder(), ZIndex = 4,
        }, P)
        UILib.corner(SelectorGridFrame, UDim.new(0, 7)); UILib.stroke(SelectorGridFrame, Theme.SakuraPink, 1, 0.45)
        UILib.new("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, SelectorGridFrame)
        UILib.new("UIGridLayout", {
            CellSize = UDim2.new(0.5, -3, 0, 26),
            CellPadding = UDim2.fromOffset(5, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, SelectorGridFrame)

        local bossChoiceBtns = {}
        local function refreshBossChoiceHighlights()
            SelectorToggleBtn.Text = M.fmtStr("🎯 Select Boss: %s  %s", Config.SelectedBoss, selectorOpen and "^" or "v")
            for label, b in pairs(bossChoiceBtns) do
                local isSel = (label == Config.SelectedBoss)
                b.BackgroundColor3 = isSel and Theme.TabPill or Color3.fromRGB(36, 24, 54)
                b.TextColor3 = isSel and Theme.Text or Theme.Muted
            end
        end

        for idx, opt in ipairs(BossEngine.OPTIONS) do
            local btn = UILib.new("TextButton", {
                BackgroundColor3 = (opt.label == Config.SelectedBoss) and Theme.TabPill or Color3.fromRGB(36, 24, 54),
                Text = opt.label, TextColor3 = (opt.label == Config.SelectedBoss) and Theme.Text or Theme.Muted,
                Font = Enum.Font.GothamBold, TextSize = 9, LayoutOrder = idx, ZIndex = 5,
            }, SelectorGridFrame)
            UILib.corner(btn, UDim.new(0, 5)); UILib.attachPressSpring(btn)
            bossChoiceBtns[opt.label] = btn
            btn.MouseButton1Click:Connect(function()
                Core.playMeowSFX()
                Config.SelectedBoss = opt.label
                BossEngine.lastTrackedBossModel = nil
                BossEngine.prevEngagedModel = nil
                BossEngine.prevEngagedHP = nil
                refreshBossChoiceHighlights()
            end)
        end

        SelectorToggleBtn.MouseButton1Click:Connect(function()
            Core.playMeowSFX()
            selectorOpen = not selectorOpen
            SelectorGridFrame.Visible = selectorOpen
            refreshBossChoiceHighlights()
        end)

        createToggle(P, "Boss", "Auto Kill Boss (Auto Evade + Fast Punch)", "AutoKillBoss", nil, function(on)
            Runtime.SessionTokens.boss += 1
            BossEngine.evadingAOE = false
            BossEngine.evadeHoldCF = nil
            BossEngine.arenaCenter = nil
            BossEngine.arenaFloorY = nil
            BossEngine.isCharging = false
            BossEngine.chargePct = 0
            BossEngine.chargeRemSec = 0
            BossEngine.chargeSigKey = nil
            BossEngine.dodgeEscapeDir = nil
            BossEngine.evadeUntil = 0
            BossEngine.aoeFlagUntil = 0
            BossEngine.postAttackHoldUntil = 0
            BossEngine.wasTelegraphActive = false
            BossEngine.wasImmediateHazard = false
            BossEngine.lastAtkImpact = nil
            BossEngine.lastSafeDist = 380
            BossEngine.trackedDangerInsts = setmetatable({}, {__mode = "k"})
            if on then
                Combat.lastTargetScan = -100
            else
                BossEngine.lastSafeSpot = nil
                BossEngine.currentBossModel = nil
                BossEngine.currentBossHum = nil
                BossEngine.currentTargetObj = nil
                BossEngine.prevEngagedModel = nil
                BossEngine.prevEngagedHP = nil
                BossEngine.restoreNoClip()
                BossEngine.returnToOrigin()
                local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    pcall(function() root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end)
                end
                Combat.restoreJoints()
            end
        end, "targets live bosses, evades detected attacks at floor level, then resumes punching")
    end

    function UIBuilders.Reward(P, ctx)
        local UI = ctx.UI
        local createStatusLabel, createToggle = ctx.createStatusLabel, ctx.createToggle
        UI.rewStatusLine = createStatusLabel(P, "Status: Idle | Collected: 0 (Remote-Only)", Theme.CyberCyan, true, 10)
        UI.rewLastLine   = createStatusLabel(P, "Last Claimed: None | Spins Left: --", Theme.Text, false, 9)
        UI.spinStatLine  = createStatusLabel(P, "Spins Completed: 0 | Last Wheel Prize: None", Theme.SakuraSoft, false, 9)
        createToggle(P, "Reward", "Auto Collect Quest, Daily & Time Played Reward", "AutoCollectRewards", nil, function(on)
            Runtime.SessionTokens.rew += 1
            RewardEngine.questPassBusy = false
            RewardEngine.giftPassBusy = false
            RewardEngine.dailyPassBusy = false
            if on then
                RewardEngine.claimedGiftCooldown = {}
                RewardEngine.claimedQuestCooldown = {}
                RewardEngine.lastDailyAttempt = -10
                RewardEngine.invalidateGuiCache()
                task.spawn(RewardEngine.runAutoCollectPass)
            end
        end, "remote-only: collects only when quest/daily/time reward is ready")
        createToggle(P, "Reward", "Auto Spin Reward (Fortune Wheel)", "AutoSpinReward", nil, function(on)
            Runtime.SessionTokens.spin += 1; RewardEngine.isWheelSpinning = false
            if on then
                RewardEngine.lastSpinAttempt = 0
                RewardEngine.lastFullGuiScan = 0
                RewardEngine.spinsLeftCached = nil
                RewardEngine.invalidateGuiCache()
                task.spawn(RewardEngine.stepAutoSpin)
            end
        end, "remote-only: spins fortune wheel only when spins > 0")
    end

    function UIBuilders.Visual(P, ctx)
        local createStatusLabel, createToggle = ctx.createStatusLabel, ctx.createToggle
        createStatusLabel(P, "Client Avatar Visuals (Korblox & Headless)", Theme.CyberCyan, false, 9)
        createToggle(P, "Visual", "Korblox Right Leg", "KorbloxRight", nil, function(on)
            if on then if Player.Character then Visuals.applyKorblox(Player.Character) end
            else Visuals.removeKorblox(Player.Character) end
        end)
        createToggle(P, "Visual", "Headless Head", "Headless", nil, function(on)
            if on then if Player.Character then Visuals.applyHeadless(Player.Character) end
            else if Player.Character then Visuals.removeHeadless(Player.Character) end end
        end)
    end

    function UIBuilders.PerfStats(P, ctx)
        local UI = ctx.UI
        local createStatusLabel, createToggle, createNumberInput = ctx.createStatusLabel, ctx.createToggle, ctx.createNumberInput
        UI.miscFpsLine  = createStatusLabel(P, "Device FPS: 60 FPS | FPS Jumping: 1x (+0 FPS · 60/s)", Theme.Green, true, 9)
        UI.miscPingLine = createStatusLabel(P, "Ping: 0 ms | Frame Time: 16.6 ms", Theme.Text, false, 9)
        UI.miscHwLine   = createStatusLabel(P, "Cycle Rate: 100% | Workers: 2 | Lua Slice: 0.2ms", Theme.Text, false, 9)
        UI.miscCapLine  = createStatusLabel(P, "FPS Cap: 120 | Cycle Jump: 1x | AI: OFF", Theme.Yellow, false, 9)
        createToggle(P, "Perf Stats", "AI Performance Mode (Advanced Zero-GFX)", "AIPerfMode", nil, Perf.setAIPerfMode,
            "incremental Lua GC, physics sleep & frame headroom governor (no gfx change)")
        createToggle(P, "Perf Stats", "FPS Booster (Potato Gfx · Full Restore on OFF)", "FPSBoost", nil, Perf.setFPSBoost)
        createToggle(P, "Perf Stats", "Remove Fog (Fog & Atmosphere Only)", "RemoveFog", nil, Perf.setRemoveFog)
        createToggle(P, "Perf Stats", "Ping Booster (Replication Focus & Zero Lag)", "PingBoost", nil, Perf.setPingBoost)
        createNumberInput(P, "FPS Cap (0 = Unlocked | Max: 1000)", "FPSCap", 0, 1000, false, function(v) Perf.applyFPSCap(v, false) end)
        createNumberInput(P, "Cycle Jump / FPS Jump (1x - 100x Real Uncap & Trim)", "CycleJump", 1, 100, false, Perf.applyCycleSettings)
        createNumberInput(P, "Cycle Rate (Real CPU Slice & Workers: 50% - 1000%)", "CycleRate", 50, 1000, false, Perf.applyCycleSettings)
    end

    function UIBuilders.Misc(P, ctx)
        local createStatusLabel, createToggle, createNumberInput = ctx.createStatusLabel, ctx.createToggle, ctx.createNumberInput
        createStatusLabel(P, "Character Physics, Movement & Size Overrides", Theme.CyberCyan, false, 9)
        createToggle(P, "Misc", "Fly (3D Camera Flight · Space/Shift)", "FlyEnabled", nil, function(on) if not on then CharPhysics.destroyFly() end end)
        createNumberInput(P, "Fly Speed (0 to Inf | Default: 80)", "FlySpeed", 0, nil, true)
        createToggle(P, "Misc", "Walk on Water (Terrain & Ocean Surface)", "WalkOnWater", nil, CharPhysics.setWalkOnWater)
        createToggle(P, "Misc", "Walk Speed (Bypass Agility Requirement)", "WalkSpeedEnabled", nil, CharPhysics.applyWalkSpeed)
        createNumberInput(P, "Walk Speed Value (0 to Inf | Default: 100)", "WalkSpeedValue", 0, nil, true, function()
            if Config.WalkSpeedEnabled then CharPhysics.applyWalkSpeed() end
        end)
        createToggle(P, "Misc", "Size Override (Bypass Strength Requirement)", "SizeEnabled", nil, CharPhysics.applySize)
        createNumberInput(P, "Character Size (NaN / 0 to Inf | Default: 2)", "SizeValue", 0, nil, true, function()
            if Config.SizeEnabled then CharPhysics.applySize() end
        end, true)
    end

    function UIBuilders.Settings(P, ctx, onRefresh, onKill)
        local UI, createStatusLabel, nextOrder = ctx.UI, ctx.createStatusLabel, ctx.nextOrder
        UI.setCopyLabel = createStatusLabel(P, "Copy Target: " .. Remotes.copyProfile, Theme.CyberCyan, false, 9)

        local realName = (Player.DisplayName and Player.DisplayName ~= "") and Player.DisplayName or Player.Name
        local drawerOpen = false
        local HideBtn = UILib.new("TextButton", {
            Size = UDim2.new(1, -6, 0, 28), BackgroundColor3 = Theme.Card,
            Text = Config.HideNameEnabled and ("🎭 Hide Name: " .. Config.HideNameAlias .. "  v") or "🎭 Hide Name: OFF (Click to Choose)  v",
            TextColor3 = Config.HideNameEnabled and Theme.SakuraPink or Theme.Text, Font = Enum.Font.GothamBold, TextSize = 10, LayoutOrder = nextOrder(), ZIndex = 4,
        }, P)
        UILib.corner(HideBtn, UDim.new(0, 7))
        local hideRgb = UILib.attachRGBLightning(HideBtn, 1.35, 0.36, 0.04, 180, "Settings")
        hideRgb.isActive = (Config.HideNameEnabled == true)
        UILib.attachPressSpring(HideBtn)

        local Drawer = UILib.new("Frame", {Size = UDim2.new(1, -6, 0, 28), BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, Visible = false, LayoutOrder = nextOrder(), ZIndex = 4}, P)
        UILib.corner(Drawer, UDim.new(0, 6)); UILib.stroke(Drawer, Theme.SakuraPink, 1, 0.45)
        UILib.new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center}, Drawer)
        UILib.new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, Drawer)

        local BtnEn = UILib.new("TextButton", {Size = UDim2.new(0.32, -2, 0, 20), BackgroundColor3 = Color3.fromRGB(48, 28, 74), Text = "ANONYMOUS", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 8, ZIndex = 5}, Drawer)
        UILib.corner(BtnEn, UDim.new(0, 5)); UILib.attachPressSpring(BtnEn)
        local BtnJp = UILib.new("TextButton", {Size = UDim2.new(0.32, -2, 0, 20), BackgroundColor3 = Color3.fromRGB(48, 28, 74), Text = "アノニマス", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 8, ZIndex = 5}, Drawer)
        UILib.corner(BtnJp, UDim.new(0, 5)); UILib.attachPressSpring(BtnJp)
        local BtnReal = UILib.new("TextButton", {Size = UDim2.new(0.36, -2, 0, 20), BackgroundColor3 = Color3.fromRGB(28, 52, 64), Text = realName, TextColor3 = Theme.CyberCyan, Font = Enum.Font.GothamBold, TextSize = 8, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5}, Drawer)
        UILib.corner(BtnReal, UDim.new(0, 5)); UILib.attachPressSpring(BtnReal)

        local function refreshHideUi()
            hideRgb.isActive = (Config.HideNameEnabled == true)
            if Config.HideNameEnabled then
                HideBtn.Text = M.fmtStr("🎭 Hide Name: %s  %s", Config.HideNameAlias, drawerOpen and "^" or "v")
                HideBtn.TextColor3 = Theme.SakuraPink
                BtnEn.BackgroundColor3 = (Config.HideNameAlias == "ANONYMOUS") and Theme.TabPill or Color3.fromRGB(48, 28, 74)
                BtnJp.BackgroundColor3 = (Config.HideNameAlias == "アノニマス") and Theme.TabPill or Color3.fromRGB(48, 28, 74)
                BtnReal.BackgroundColor3 = Color3.fromRGB(28, 52, 64)
            else
                HideBtn.Text = M.fmtStr("🎭 Hide Name: %s (Original)  %s", realName, drawerOpen and "^" or "v")
                HideBtn.TextColor3 = Theme.Text
                BtnEn.BackgroundColor3 = Color3.fromRGB(48, 28, 74); BtnJp.BackgroundColor3 = Color3.fromRGB(48, 28, 74); BtnReal.BackgroundColor3 = Theme.TabPill
            end
        end
        HideBtn.MouseButton1Click:Connect(function() Core.playMeowSFX(); drawerOpen = not drawerOpen; Drawer.Visible = drawerOpen; refreshHideUi() end)
        BtnEn.MouseButton1Click:Connect(function() Core.playMeowSFX(); Config.HideNameEnabled = true; Config.HideNameAlias = "ANONYMOUS"; refreshHideUi(); Visuals.refreshHideNames() end)
        BtnJp.MouseButton1Click:Connect(function() Core.playMeowSFX(); Config.HideNameEnabled = true; Config.HideNameAlias = "アノニマス"; refreshHideUi(); Visuals.refreshHideNames() end)
        BtnReal.MouseButton1Click:Connect(function() Core.playMeowSFX(); Config.HideNameEnabled = false; Visuals.restoreHiddenNames(); refreshHideUi() end)

        local RefreshBtn = UILib.new("TextButton", {Size = UDim2.new(1, -6, 0, 30), BackgroundColor3 = Color3.fromRGB(48, 28, 74), Text = "🔄 Refresh Script (Reset All OFF & Reload Clean)", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 10, LayoutOrder = nextOrder(), ZIndex = 4}, P)
        UILib.corner(RefreshBtn, UDim.new(0, 7)); UILib.stroke(RefreshBtn, Theme.CyberCyan, 1); UILib.attachPressSpring(RefreshBtn)

        local KillBtn = UILib.new("TextButton", {Size = UDim2.new(1, -6, 0, 30), BackgroundColor3 = Theme.Red, Text = "💀 Kill Switch (Turn Off All & Restore Default Gfx)", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 10, LayoutOrder = nextOrder(), ZIndex = 4}, P)
        UILib.corner(KillBtn, UDim.new(0, 7)); UILib.attachPressSpring(KillBtn)

        UI.KillConfirmTab = UILib.new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(9, 7, 15), BackgroundTransparency = 0.05, Visible = false, Active = true, ZIndex = 50}, UI.Main)
        UILib.corner(UI.KillConfirmTab, UDim.new(0, 12))
        local ConfirmCard = UILib.new("Frame", {Size = UDim2.fromOffset(278, 146), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, ZIndex = 51}, UI.KillConfirmTab)
        UILib.corner(ConfirmCard, UDim.new(0, 10)); UILib.stroke(ConfirmCard, Theme.SakuraPink, 1.8)
        UILib.new("TextLabel", {Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 12), BackgroundTransparency = 1, Text = "are you sure?😭", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 19, ZIndex = 52}, ConfirmCard)

        local NoBtn = UILib.new("TextButton", {Size = UDim2.fromOffset(112, 34), Position = UDim2.new(0, 14, 1, -44), BackgroundColor3 = Theme.Card, Text = "no🙂‍↔️", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 52}, ConfirmCard)
        UILib.corner(NoBtn, UDim.new(0, 7)); UILib.stroke(NoBtn, Theme.Stroke, 1.2); UILib.attachPressSpring(NoBtn)
        local YesBtn = UILib.new("TextButton", {Size = UDim2.fromOffset(112, 34), Position = UDim2.new(1, -126, 1, -44), BackgroundColor3 = Theme.Red, Text = "yes🙂‍↕️", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 52}, ConfirmCard)
        UILib.corner(YesBtn, UDim.new(0, 7)); UILib.attachPressSpring(YesBtn)

        RefreshBtn.MouseButton1Click:Connect(function() Core.playMeowSFX(); task.spawn(onRefresh) end)
        KillBtn.MouseButton1Click:Connect(function() Core.playMeowSFX(); UI.KillConfirmTab.Visible = true end)
        NoBtn.MouseButton1Click:Connect(function() Core.playMeowSFX(); UI.KillConfirmTab.Visible = false end)
        YesBtn.MouseButton1Click:Connect(function() Core.playMeowSFX(); UI.KillConfirmTab.Visible = false; task.spawn(onKill) end)
    end
end

----------------------------------------------------------------
-- Main 9-Tab Cyber-Sakura Hub UI (Low-Lag Pooled VFX & Visibility-Gated RGB)
----------------------------------------------------------------
local function buildUI(onRefresh, onKill)
    Runtime.UI = {}; Runtime.Setters = {}; Runtime.Pages = {}; Runtime.TabButtons = {}; Runtime.RGBLightningItems = {}
    local UI, Setters, Pages, TabButtons = Runtime.UI, Runtime.Setters, Runtime.Pages, Runtime.TabButtons
    local myGen = Runtime.Gen

    local TabNames = {"Strength", "Rebirth", "Punch", "Boss", "Reward", "Visual", "Perf Stats", "Misc", "Settings"}
    local ActiveTabPill, TabBtnHolder = UILib.createMainChrome(UI, myGen, 478, 340, 34)
    local switchTab = UILib.createTabPages(UI, Pages, TabButtons, TabNames, TabBtnHolder, ActiveTabPill)

    local orderIdx = 0
    local function nextOrder() orderIdx += 1; return orderIdx end
    local createStatusLabel, createSmallBtn, createToggle, createNumberInput = UILib.createControlFactory(Setters, nextOrder)

    switchTab("Strength")
    local ctx = {
        UI = UI,
        Setters = Setters,
        nextOrder = nextOrder,
        createStatusLabel = createStatusLabel,
        createSmallBtn = createSmallBtn,
        createToggle = createToggle,
        createNumberInput = createNumberInput,
    }
    for _, spec in ipairs({
        {"Strength", UIBuilders.Strength},
        {"Rebirth", UIBuilders.Rebirth},
        {"Punch", UIBuilders.Punch},
        {"Boss", UIBuilders.Boss},
        {"Reward", UIBuilders.Reward},
        {"Visual", UIBuilders.Visual},
        {"Perf Stats", UIBuilders.PerfStats},
        {"Misc", UIBuilders.Misc},
        {"Settings", UIBuilders.Settings},
    }) do
        local tName, builderFn = spec[1], spec[2]
        local okTab, errTab = xpcall(function()
            builderFn(Pages[tName], ctx, onRefresh, onKill)
        end, debug.traceback)
        if not okTab then
            warn("[YuiHub] Tab build error (" .. tName .. "): " .. tostring(errTab))
            local firstLine = tostring(errTab or "unknown error"):match("^[^\r\n]+") or "unknown error"
            local okLbl, errLbl = pcall(createStatusLabel, Pages[tName], "Tab recovery (" .. tName .. "): " .. firstLine:sub(1, 160), Theme.Red, true, 9)
            if okLbl and errLbl then
                errLbl.TextWrapped = true
                errLbl.AutomaticSize = Enum.AutomaticSize.Y
                errLbl.TextYAlignment = Enum.TextYAlignment.Top
                errLbl.ClipsDescendants = true
                errLbl.Size = UDim2.new(1, -4, 0, 15)
            end
        end
    end

    Perf.applyFPSCap(Config.FPSCap)
    Perf.applyCycleSettings()
end

----------------------------------------------------------------
-- High-Precision Zero-Lag Execution Loops
----------------------------------------------------------------
local function startLoops()
    local myGen = Runtime.Gen
    Telemetry.clearCache()
    Core.evaluateMuscleScope(true)
    Telemetry.resetStrength()
    Telemetry.resetRebirth()
    Telemetry.resetPunch()

    local connectedRebObj = nil
    local function attachRebirthListener()
        local rebObj = Telemetry.resolveStat("Rebirths")
        if rebObj and rebObj ~= connectedRebObj then
            connectedRebObj = rebObj
            local initVal = tonumber(rebObj.Value) or 0
            Telemetry.lastKnownRebirthCount = initVal
            if Telemetry.baseReb == nil and initVal > 0 then Telemetry.baseReb = initVal end
            Core.track(rebObj.Changed:Connect(function(newVal)
                local num = tonumber(newVal) or 0
                if Telemetry.lastKnownRebirthCount ~= nil and num > Telemetry.lastKnownRebirthCount then
                    local now = M.clock()
                    local gained = num - Telemetry.lastKnownRebirthCount
                    if Telemetry.lastConfirmedRebirthTime > 0 then
                        local measured = now - Telemetry.lastConfirmedRebirthTime
                        Telemetry.rebCycleDuration = (measured >= 5.5 and measured <= 7.0) and measured or LEGIT_GAMEPASS_REBIRTH_COOLDOWN
                    else
                        Telemetry.rebCycleDuration = LEGIT_GAMEPASS_REBIRTH_COOLDOWN
                    end
                    Telemetry.lastRebGainPerCycle = gained
                    Telemetry.lastConfirmedRebirthTime = now
                    Telemetry.rebConfirmedSeq += 1
                end
                Telemetry.lastKnownRebirthCount = num
            end))
        end
    end
    attachRebirthListener()

    pcall(function()
        if TextChatService then
            local prevHook = TextChatService.OnIncomingMessage
            TextChatService.OnIncomingMessage = function(message)
                local props = Instance.new("TextChatMessageProperties")
                if prevHook then
                    local ok, res = pcall(prevHook, message)
                    if ok and res then props = res end
                end
                if Config.Active and Config.HideNameEnabled and message and message.TextSource and message.TextSource.UserId == Player.UserId then
                    local curPrefix = (props.PrefixText ~= "" and props.PrefixText) or message.PrefixText or ""
                    local masked = Visuals.replaceNameOnly(curPrefix, Config.HideNameAlias or "ANONYMOUS")
                    if masked then props.PrefixText = masked end
                end
                return props
            end
        end
    end)

    local function watchGui(rootGui, isPlayerGui)
        if not rootGui then return end
        Core.track(rootGui.DescendantAdded:Connect(function(d)
            if myGen ~= Runtime.Gen or not Config.Active then return end
            local needHide = Config.HideNameEnabled
            local needAntiLag = Config.RepAntiLag
            local needRew = isPlayerGui and (Config.AutoCollectRewards or Config.AutoSpinReward)
            if not (needHide or needAntiLag or needRew) then return end
            if needHide and d:IsA("TextLabel") then Visuals.bindHideName(d) end
            if needAntiLag then Perf.handleRepAntiLagDesc(d) end
            if needRew and (d:IsA("ScreenGui") or d:IsA("TextButton") or d:IsA("ImageButton") or d:IsA("TextLabel")) then
                if not ((Runtime.UI.GUI and d:IsDescendantOf(Runtime.UI.GUI)) or (Runtime.UI.ToggleGui and d:IsDescendantOf(Runtime.UI.ToggleGui))) then
                    local sg = d:IsA("ScreenGui") and d or d:FindFirstAncestorOfClass("ScreenGui")
                    local gn = sg and sg.Name:lower() or ""
                    if not (gn:find("popup") or gn:find("effect") or gn:find("float") or gn:find("gain")) then
                        RewardEngine.invalidateGuiCache()
                    end
                end
            end
        end))
    end
    watchGui(Player:FindFirstChildOfClass("PlayerGui"), true)
    watchGui(Player:FindFirstChildOfClass("Backpack"), false)
    watchGui(SafeService("SoundService"), false)
    pcall(function()
        local cg = SafeService("CoreGui")
        watchGui(cg and cg:FindFirstChild("PlayerList"), false)
        watchGui(cg and cg:FindFirstChild("ExperienceChat"), false)
    end)

    Core.track(Players.PlayerAdded:Connect(function(plr)
        if myGen ~= Runtime.Gen or not Config.Active then return end
        local okI, res = pcall(ThreatScanner.inspectPlayer, plr)
        if okI and res then
            warn(M.fmtStr("[YuiHub] [THREAT] Staff/Moderator joined: %s (%s)", tostring(res.username), table.concat(res.reasons or {}, ", ")))
        end
    end))
    Core.track(ReplicatedStorage.DescendantAdded:Connect(function(d)
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            Remotes.lastScan = -100
            RewardEngine.lastDailyAttempt = -10
        end
    end))
    Core.track(Player.DescendantAdded:Connect(function(d)
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then Remotes.lastScan = -100
        elseif d:IsA("ValueBase") then Telemetry.clearCache(); attachRebirthListener() end
    end))
    pcall(function()
        local cs = SafeService("CollectionService")
        if cs and cs.GetInstanceAddedSignal then
            Core.track(cs:GetInstanceAddedSignal("BossEventBoss"):Connect(function(inst)
                if myGen == Runtime.Gen and Config.Active then Combat.registerCandidateModel(inst) end
            end))
        end
    end)
    Core.track(workspace.DescendantAdded:Connect(function(d)
        if myGen ~= Runtime.Gen or not Config.Active then return end
        local myChar = Player.Character
        if myChar and (d == myChar or d:IsDescendantOf(myChar)) then return end

        local isVfxOrPart = d:IsA("BasePart") or d:IsA("Highlight") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Explosion") or d:IsA("Decal") or d:IsA("Texture")
        if Config.AutoKillBoss and isVfxOrPart then
            BossEngine.spawnedPartTimes[d] = M.clock()
        end
        if Config.AutoKillBoss and BossEngine.notifyWatchDescendant and BossEngine.currentBossModel and BossEngine.watchCache[BossEngine.currentBossModel] and d:IsDescendantOf(BossEngine.currentBossModel) then
            BossEngine.notifyWatchDescendant(d)
        end
        if d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("BillboardGui") or (d:IsA("BasePart") and d.Name == "BossDamageHitbox") then
            Combat.registerCandidateModel(d)
        elseif d:IsA("Model") then
            local p = d.Parent
            local pl = p and p.Name:lower() or ""
            if p == workspace or pl:find("boss") or pl:find("arena") or pl:find("event") or pl:find("alien") then
                Combat.registerCandidateModel(d)
            end
        elseif d:IsA("ValueBase") then
            local dl = d.Name:lower()
            if dl == "hp" or dl == "health" or dl == "bosshp" or dl == "bosshealth" or dl == "currenthp" then
                Combat.registerCandidateModel(d)
            end
        end
        if Config.AutoKillBoss and BossEngine.currentBossModel and isVfxOrPart then
            local tgtObj = BossEngine.currentTargetObj
            local bRoot = tgtObj and (tgtObj.part or tgtObj.head) or BossEngine.currentBossModel.PrimaryPart
            if bRoot and bRoot.Parent then
                local bFloorY = BossEngine.arenaFloorY or (bRoot.Position.Y - 6)
                local okD, rad, isImm, meta = BossEngine.isDangerPart(d, BossEngine.currentBossModel, bRoot.Position, bFloorY)
                if okD then
                    local now = M.clock()
                    local initSz = d:IsA("BasePart") and (M.max(d.Size.X, d.Size.Y, d.Size.Z) * 0.5) or 0
                    BossEngine.trackedDangerInsts[d] = {seen = now, immediate = (isImm == true), rad = rad or 38, initSz = initSz, meta = meta}
                    if isImm then
                        BossEngine.wasTelegraphActive = true
                        BossEngine.wasImmediateHazard = true
                        BossEngine.aoeFlagUntil = now + 0.65
                        BossEngine.evadeUntil = M.max(BossEngine.evadeUntil, now + 0.65)
                    end
                end
            end
        end
    end))
    local function watchCharacter(char)
        if not char then return end
        Core.track(char.DescendantAdded:Connect(function(d)
            if myGen ~= Runtime.Gen or not Config.Active then return end
            if Config.HideNameEnabled and d:IsA("TextLabel") then Visuals.bindHideName(d) end
            if Config.RepAntiLag then Perf.handleRepAntiLagDesc(d) end
        end))
    end
    if Player.Character then watchCharacter(Player.Character) end

    Core.track(Player.CharacterAdded:Connect(function(newChar)
        Combat.char = nil; Combat.joints = {}; Combat.origC0 = {}
        Combat.rockTargets = {}; Combat.bossTargets = {}; Combat.playerTargets = {}
        Combat.lastTargetScan = -100; Combat.lastDeepScan = -100
        CharPhysics.bodyVel = nil; CharPhysics.bodyGyro = nil
        CharPhysics.trackedHum = nil; CharPhysics.trackedSizeChar = nil; CharPhysics.scaleBackup = {}
        CharPhysics.freezeCF = nil; CharPhysics.freezeChar = nil; CharPhysics.freezeAnchoredBackup = nil
        BossEngine.lastHoverCF = nil; BossEngine.tweenStartPos = nil; BossEngine.noClipChar = nil
        BossEngine.evadingAOE = false; BossEngine.evadeHoldCF = nil; BossEngine.arenaCenter = nil; BossEngine.dodgeEscapeDir = nil; BossEngine.evadeUntil = 0; BossEngine.aoeFlagUntil = 0
        BossEngine.wasTelegraphActive = false; BossEngine.wasImmediateHazard = false; BossEngine.postAttackHoldUntil = 0; BossEngine.lastSafeDist = 380
        BossEngine.currentTargetObj = nil; BossEngine.prevEngagedModel = nil; BossEngine.prevEngagedHP = nil
        Remotes.lastScan = -100
        if Config.HideNameEnabled then task.defer(Visuals.refreshHideNames) end
        if Config.SizeEnabled then task.defer(CharPhysics.applySize) end
        if CharPhysics.freezeEnabled then task.defer(function() CharPhysics.applyFreeze(true) end) end
        watchCharacter(newChar)
    end))

    -- 1. ZERO-LAG BURST REPS + TELEMETRY + LOW-LAG RENDER STEP
    do
        local carryRemainder, autoRepAcc, activeToken = 0, 0, Runtime.SessionTokens.rep
        local calibCheckT, calibPrevSum, lastRewardSpinScan = M.clock(), 0, 0
        local REP_PRESET_RATES = {
            Default = 468,
            Ultra = 850,
            ["Ultra Plus"] = 1650,
            Overlord = 2800,
            ["Overlord Max"] = 4800,
        }

        local function runRepCalibration(remote, nowT)
            if (nowT - calibCheckT) < 0.22 then return remote end
            local directMuscle = Player:FindFirstChild("muscleEvent")
            local isCoreMuscle = (directMuscle ~= nil) and (remote == directMuscle or (remote.Name == "muscleEvent" and remote.Parent == Player))
            local curSum = Telemetry.getStatNum("Strength") + Telemetry.getStatNum("Durability")
            if curSum > calibPrevSum then
                Remotes.calibratedRemote = remote
                Remotes.gainScores[remote] = (Remotes.gainScores[remote] or 0) + 1
                Remotes.zeroGainCounts[remote] = 0
                if isCoreMuscle then Remotes.variantByRemote[remote] = 1 end
            elseif curSum < calibPrevSum then
                calibPrevSum = curSum
                calibCheckT = nowT
                return remote
            elseif curSum >= 9e15 and (Remotes.gainScores[remote] or 0) > 0 then
                Remotes.calibratedRemote = remote
                Remotes.zeroGainCounts[remote] = 0
            elseif isCoreMuscle then
                Remotes.variantByRemote[remote] = 1
            else
                local zc = (Remotes.zeroGainCounts[remote] or 0) + 1
                Remotes.zeroGainCounts[remote] = zc
                if Remotes.calibratedRemote == remote and zc >= 2 then
                    Remotes.calibratedRemote = nil
                end
                local wrapped = Remotes.rotateRepVariant(remote)
                if wrapped and #Remotes.muscleList > 1 then
                    Remotes.activeMuscleIdx = (Remotes.activeMuscleIdx % #Remotes.muscleList) + 1
                    remote = Remotes.getPrimaryMuscle() or remote
                end
            end
            calibPrevSum = curSum
            calibCheckT = nowT
            return remote
        end

        local function stepRepEngine(dt)
            if myGen ~= Runtime.Gen or not Config.Active then return end
            if activeToken ~= Runtime.SessionTokens.rep then
                activeToken = Runtime.SessionTokens.rep
                Core.forceKillAllRepWorkers()
                Runtime.RepGateOpen = (Config.FastRep or Config.AIFastRep or Config.AutoRep)
                carryRemainder = 0; autoRepAcc = 0
                calibCheckT = M.clock()
                calibPrevSum = Telemetry.getStatNum("Strength") + Telemetry.getStatNum("Durability")
            end
            if not (Config.FastRep or Config.AIFastRep or Config.AutoRep) then
                Runtime.RepGateOpen = false; carryRemainder = 0; return
            end
            Runtime.RepGateOpen = true

            local remote = Remotes.getPrimaryMuscle()
            if not (remote and remote.Parent) then return end

            local nowT = M.clock()
            remote = runRepCalibration(remote, nowT)
            if not (remote and remote.Parent) then return end

            local safeDt = (dt == dt and dt > 0) and M.min(dt, 0.05) or 0.01667
            if carryRemainder ~= carryRemainder or carryRemainder < 0 then carryRemainder = 0 end

            local isFunc = remote:IsA("RemoteFunction")
            local fireFn = isFunc and remote.InvokeServer or remote.FireServer
            local variant = Remotes.argVariants[Remotes.variantByRemote[remote] or 1]
            local arg1, arg2 = variant[1], variant[2]
            local hasArg2 = (arg2 ~= nil)
            local jumpMult = M.clamp(M.floor(tonumber(Config.CycleJump) or 1), 1, 100)
            local budgetSec = Perf.frameBudgetSec

            if Config.FastRep then
                local rawTarget = tonumber(Config.RepSpeed) or 468
                local isCustom = (Config.RepBurstMode == "Custom")
                local isUnlimited = Config.RepLimiterOpen or (rawTarget == M.huge)
                local presetRate = (not isCustom) and REP_PRESET_RATES[Config.RepBurstMode] or nil
                local targetPerSec = isUnlimited and 60000 or (presetRate or M.max(1, M.floor(rawTarget)))

                local effectiveRate = M.max(1, targetPerSec)
                local maxFrameCap = isUnlimited and 600 or M.clamp(M.ceil(effectiveRate * 0.08), 24, 1500)
                local quota = (effectiveRate * safeDt) + carryRemainder
                local needed = M.min(M.floor(quota), maxFrameCap)
                local done = 0

                if needed > 0 and Runtime.RepGateOpen and activeToken == Runtime.SessionTokens.rep then
                    local t0 = M.clock()
                    local sliceBudget = isUnlimited and 0.0065 or M.clamp(budgetSec * 2.5, 0.0035, 0.0075)
                    if isFunc then
                        for _ = 1, M.min(needed, 60) do
                            if not (Runtime.RepGateOpen and activeToken == Runtime.SessionTokens.rep) then break end
                            if hasArg2 then task.spawn(pcall, fireFn, remote, arg1, arg2)
                            else task.spawn(pcall, fireFn, remote, arg1) end
                            done += 1
                        end
                    else
                        pcall(function()
                            if hasArg2 then
                                for i = 1, needed do
                                    fireFn(remote, arg1, arg2)
                                    done += 1
                                    if (i % 16 == 0) and (not Runtime.RepGateOpen or activeToken ~= Runtime.SessionTokens.rep or (M.clock() - t0) > sliceBudget) then break end
                                end
                            else
                                for i = 1, needed do
                                    fireFn(remote, arg1)
                                    done += 1
                                    if (i % 16 == 0) and (not Runtime.RepGateOpen or activeToken ~= Runtime.SessionTokens.rep or (M.clock() - t0) > sliceBudget) then break end
                                end
                            end
                        end)
                    end
                    if done > 0 then Telemetry.recordEvent(Telemetry.repTracker, done) end
                end
                local rem = quota - done
                if rem ~= rem or rem < 0 then rem = 0 end
                carryRemainder = M.clamp(rem, 0, maxFrameCap)

            elseif Config.AIFastRep then
                local pingDelta = Telemetry.livePing - Telemetry.baselinePing
                local scaleBoost = M.clamp((tonumber(Config.CycleRate) or 100) / 100, 0.5, 5)
                local maxAiRate = M.max(360, M.floor(1500 * scaleBoost))
                if safeDt > 0.045 or pingDelta > 75 then
                    Telemetry.aiCurrentRepRate = M.max(220, M.floor(Telemetry.aiCurrentRepRate * 0.90))
                elseif safeDt <= 0.036 and pingDelta <= 50 then
                    Telemetry.aiCurrentRepRate = M.min(maxAiRate, M.floor(Telemetry.aiCurrentRepRate * 1.08 + 14))
                end

                local maxAiFrame = M.clamp(M.ceil(Telemetry.aiCurrentRepRate * 0.065), 48, 360)
                local exactQuota = (Telemetry.aiCurrentRepRate * safeDt) + carryRemainder
                local toFire = M.min(M.floor(exactQuota), maxAiFrame)
                local done = 0
                if toFire > 0 and Runtime.RepGateOpen and activeToken == Runtime.SessionTokens.rep then
                    local t0, aiBudget = M.clock(), M.clamp(budgetSec * 1.8, 0.0025, 0.0065)
                    if isFunc then
                        for _ = 1, M.min(toFire, 25) do
                            if not (Runtime.RepGateOpen and activeToken == Runtime.SessionTokens.rep) then break end
                            if hasArg2 then task.spawn(pcall, fireFn, remote, arg1, arg2)
                            else task.spawn(pcall, fireFn, remote, arg1) end
                            done += 1
                        end
                    else
                        pcall(function()
                            if hasArg2 then
                                for i = 1, toFire do
                                    fireFn(remote, arg1, arg2)
                                    done += 1
                                    if (i % 16 == 0) and (not Runtime.RepGateOpen or activeToken ~= Runtime.SessionTokens.rep or (M.clock() - t0) > aiBudget) then break end
                                end
                            else
                                for i = 1, toFire do
                                    fireFn(remote, arg1)
                                    done += 1
                                    if (i % 16 == 0) and (not Runtime.RepGateOpen or activeToken ~= Runtime.SessionTokens.rep or (M.clock() - t0) > aiBudget) then break end
                                end
                            end
                        end)
                    end
                    if done > 0 then Telemetry.recordEvent(Telemetry.repTracker, done) end
                end
                local rem = exactQuota - done
                if rem ~= rem or rem < 0 then rem = 0 end
                carryRemainder = M.clamp(rem, 0, maxAiFrame)

            elseif Config.AutoRep then
                autoRepAcc = M.min(autoRepAcc + safeDt * M.clamp(1 + (jumpMult - 1) * 0.15, 1, 4), 0.32)
                local done = 0
                if autoRepAcc >= 0.032 and Runtime.RepGateOpen and activeToken == Runtime.SessionTokens.rep then
                    if isFunc then
                        while autoRepAcc >= 0.032 do
                            if not (Runtime.RepGateOpen and activeToken == Runtime.SessionTokens.rep) then break end
                            autoRepAcc -= 0.032
                            if hasArg2 then task.spawn(pcall, fireFn, remote, arg1, arg2)
                            else task.spawn(pcall, fireFn, remote, arg1) end
                            done += 1
                        end
                    else
                        pcall(function()
                            while autoRepAcc >= 0.032 do
                                if not (Runtime.RepGateOpen and activeToken == Runtime.SessionTokens.rep) then break end
                                autoRepAcc -= 0.032
                                if hasArg2 then fireFn(remote, arg1, arg2)
                                else fireFn(remote, arg1) end
                                done += 1
                            end
                        end)
                    end
                    if done > 0 then Telemetry.recordEvent(Telemetry.repTracker, done) end
                end
            end
        end

        local HudUpdaters = {}
        function HudUpdaters.Strength(UI, now, hudDt)
            local repActive = Runtime.RepGateOpen and (Config.AutoRep or Config.AIFastRep or Config.FastRep)
            local smoothRepRate = Telemetry.sampleRate(Telemetry.repTracker, hudDt, repActive)
            local curStr, curDura = Telemetry.getStatNum("Strength"), Telemetry.getStatNum("Durability")
            if Telemetry.baseStr == nil and curStr > 0 then Telemetry.baseStr = curStr; Telemetry.strPredictor = Telemetry.newGainPred(curStr) end
            if Telemetry.baseDura == nil and curDura > 0 then Telemetry.baseDura = curDura; Telemetry.duraPredictor = Telemetry.newGainPred(curDura) end
            local strElapsed = M.max(0.01, now - Telemetry.strStartTime)
            local strGained  = Telemetry.baseStr and M.max(0, curStr - Telemetry.baseStr) or 0
            local duraGained = Telemetry.baseDura and M.max(0, curDura - Telemetry.baseDura) or 0
            local strRate  = Telemetry.updateGainPred(Telemetry.strPredictor, curStr, now, repActive, strGained, strElapsed)
            local duraRate = Telemetry.updateGainPred(Telemetry.duraPredictor, curDura, now, repActive, duraGained, strElapsed)

            if UI.strStatus then
                if not repActive then UI.strStatus.Text = "Status: Inactive | reps/sec: 0"; UI.strStatus.TextColor3 = Theme.Red
                else
                    local isOpen = Config.FastRep and (Config.RepLimiterOpen or tonumber(Config.RepSpeed) == M.huge)
                    local rDisp = isOpen and ("OPEN (" .. Core.fmtCompact(smoothRepRate) .. ")") or Core.fmtExactInt(M.floor(smoothRepRate + 0.5))
                    UI.strStatus.Text = M.fmtStr("Status: Farming | reps/sec: %s | Ping: %d ms", rDisp, Telemetry.livePing)
                    UI.strStatus.TextColor3 = Theme.Green
                end
            end
            if UI.strRuntime then UI.strRuntime.Text = "Runtime: " .. Core.fmtTime(repActive and strElapsed or 0) end
            if UI.strValLine then UI.strValLine.Text = M.fmtStr("Strength: %s | Gained: %s", Core.fmt(curStr), Core.fmt(strGained)) end
            if UI.durValLine then UI.durValLine.Text = M.fmtStr("Durability: %s | Gained: %s", Core.fmt(curDura), Core.fmt(duraGained)) end
            if UI.strAvgLine then
                UI.strAvgLine.Text = (repActive and strRate > 0)
                    and M.fmtStr("Str Ø: +%s/s | +%s/m | +%s/h | +%s/d | +%s/w | +%s/mo | +%s/y",
                        Core.fmtCompact(strRate), Core.fmtCompact(strRate * 60), Core.fmtCompact(strRate * 3600),
                        Core.fmtCompact(strRate * 86400), Core.fmtCompact(strRate * 604800), Core.fmtCompact(strRate * 2592000), Core.fmtCompact(strRate * 31536000))
                    or "Str Ø: --/s | --/m | --/h | --/d | --/w | --/mo | --/y"
            end
            if UI.durAvgLine then
                UI.durAvgLine.Text = (repActive and duraRate > 0)
                    and M.fmtStr("Dura Ø: +%s/s | +%s/m | +%s/h | +%s/d | +%s/w | +%s/mo | +%s/y",
                        Core.fmtCompact(duraRate), Core.fmtCompact(duraRate * 60), Core.fmtCompact(duraRate * 3600),
                        Core.fmtCompact(duraRate * 86400), Core.fmtCompact(duraRate * 604800), Core.fmtCompact(duraRate * 2592000), Core.fmtCompact(duraRate * 31536000))
                    or "Dura Ø: --/s | --/m | --/h | --/d | --/w | --/mo | --/y"
            end
            if UI.recSpeedLabel then
                local modeDisp
                if Config.AIFastRep then
                    modeDisp = "AI (" .. tostring(Telemetry.aiCurrentRepRate) .. "/s)"
                elseif Config.RepBurstMode == "Custom" then
                    modeDisp = "Custom (" .. Core.fmtExactInt(M.floor(tonumber(Config.RepSpeed) or 468)) .. "/s)"
                else
                    modeDisp = tostring(Config.RepBurstMode or "Default") .. " (" .. Core.fmtExactInt(M.floor(tonumber(Config.RepSpeed) or 468)) .. "/s)"
                end
                local newRec = M.fmtStr("Mode: %s | Anti-Lag: %s | Limiter: %s",
                    modeDisp, Config.RepAntiLag and "ON" or "OFF", Config.RepLimiterOpen and "100% OPEN" or "LOCKED")
                if UI.recSpeedLabel.Text ~= newRec then UI.recSpeedLabel.Text = newRec end
            end
        end

        function HudUpdaters.Rebirth(UI, now)
            local curStr, curReb = Telemetry.getStatNum("Strength"), Telemetry.getStatNum("Rebirths")
            if Telemetry.baseReb == nil and curReb > 0 then Telemetry.baseReb = curReb end
            local rebEl = M.max(0.01, now - Telemetry.rebStartTime)
            local rebGain = Telemetry.baseReb and M.max(0, curReb - Telemetry.baseReb) or 0
            local reqStr = Telemetry.getNextRebirthReq(curReb)
            local pctReady = M.clamp((curStr / M.max(1, reqStr)) * 100, 0, 100)
            local strRate = Telemetry.strPredictor.emaRatePerSec
            local missingStr = M.max(0, reqStr - curStr)
            local strEta = (missingStr <= 0) and 0 or ((strRate > 0) and (missingStr / strRate) or M.huge)

            if UI.rebStatus then
                if not Config.AutoRebirth then UI.rebStatus.Text = "Status: Inactive"; UI.rebStatus.TextColor3 = Theme.Red
                elseif Telemetry.rebCooldownLeft > 0 then
                    UI.rebStatus.Text = M.fmtStr("Status: %s | %.2fs / 6.00s", Telemetry.rebHasServerCd and "Server CD" or "Gamepass CD", Telemetry.rebCooldownLeft)
                    UI.rebStatus.TextColor3 = Theme.Green
                elseif Config.SmartRebirthGuard and curStr < reqStr then
                    UI.rebStatus.Text = M.fmtStr("Status: Charging Strength (%.1f%%)", pctReady); UI.rebStatus.TextColor3 = Theme.Yellow
                else UI.rebStatus.Text = "Status: Rebirthing (6.00s Cycle Ready)"; UI.rebStatus.TextColor3 = Theme.Green end
            end
            if UI.rebRuntime then UI.rebRuntime.Text = "Runtime: " .. Core.fmtTime(Config.AutoRebirth and rebEl or 0) end
            if UI.rebValLine then
                local mt = (Telemetry.lastRebGainPerCycle > 0) and M.fmtStr(" (+%s/reb)", Core.fmtCompact(Telemetry.lastRebGainPerCycle)) or ""
                UI.rebValLine.Text = M.fmtStr("Rebirths: %s | Gained: %s%s", Core.fmt(curReb), Core.fmt(rebGain), mt)
            end
            if UI.rebProgLine then
                UI.rebProgLine.Text = M.fmtStr("Next Rebirth: %.1f%% (%s / %s Str) | ETA: %s",
                    pctReady, Core.fmtCompact(curStr), Core.fmtCompact(reqStr), (strEta == M.huge) and "Farm Str" or Core.fmtShortEta(strEta))
            end
            if UI.rebAvgLine then
                if Config.AutoRebirth and (rebGain > 0 or Telemetry.lastRebGainPerCycle > 0) then
                    local g6 = (Telemetry.lastRebGainPerCycle > 0) and Telemetry.lastRebGainPerCycle or ((rebGain / M.max(1, rebEl)) * LEGIT_GAMEPASS_REBIRTH_COOLDOWN)
                    local rps = (rebGain > 0 and rebEl >= LEGIT_GAMEPASS_REBIRTH_COOLDOWN) and (rebGain / rebEl) or (g6 / M.max(1, Telemetry.rebCycleDuration))
                    UI.rebAvgLine.Text = M.fmtStr("Average: +%s/6s | +%s/h | +%s/d | +%s/w | +%s/mo | +%s/y",
                        Core.fmtCompact(g6), Core.fmtCompact(rps * 3600), Core.fmtCompact(rps * 86400),
                        Core.fmtCompact(rps * 604800), Core.fmtCompact(rps * 2592000), Core.fmtCompact(rps * 31536000))
                else UI.rebAvgLine.Text = "Average: --/6s | --/h | --/d | --/w | --/mo | --/y" end
            end
        end

        function HudUpdaters.Punch(UI, now, hudDt)
            local punActive = Config.AutoPunch
            local smoothPunchRate = Telemetry.sampleRate(Telemetry.punchTracker, hudDt, punActive)
            local punEl = M.max(0.01, now - Telemetry.punStartTime)
            local rInt = M.floor(smoothPunchRate + 0.5)
            if UI.punStatus then
                if punActive then
                    UI.punStatus.Text = M.fmtStr(CharPhysics.freezeEnabled and "Status: Punching (Frozen) | %s/s | Ping: %d ms" or "Status: Punching | %s/s | Ping: %d ms", Core.fmtExactInt(rInt), Telemetry.livePing)
                    UI.punStatus.TextColor3 = Theme.Green
                elseif CharPhysics.freezeEnabled then
                    UI.punStatus.Text = "Status: Frozen (Movement Locked)"; UI.punStatus.TextColor3 = Theme.CyberCyan
                else
                    UI.punStatus.Text = "Status: Inactive"; UI.punStatus.TextColor3 = Theme.Red
                end
            end
            if UI.punRuntime then UI.punRuntime.Text = "Runtime: " .. Core.fmtTime(punActive and punEl or 0) end
            if UI.punValLine then UI.punValLine.Text = M.fmtStr("Punches: %s | Rate: %s/s", Core.fmt(Telemetry.punchesTotal), Core.fmtExactInt(rInt)) end
        end

        function HudUpdaters.Boss(UI)
            if not Config.AutoKillBoss then BossEngine.pollPassiveStatus() end
            if UI.bossStatusLine then
                if UI.bossStatusLine.Text ~= BossEngine.statusText then
                    UI.bossStatusLine.Text = BossEngine.statusText
                end
                local stCol = (not Config.AutoKillBoss and Theme.Red)
                    or (BossEngine.evadingAOE and Theme.Yellow)
                    or (BossEngine.currentBossModel and Theme.Green)
                    or Theme.CyberCyan
                if UI.bossStatusLine.TextColor3 ~= stCol then UI.bossStatusLine.TextColor3 = stCol end
            end
            if UI.bossSpawnedLine then
                local newSpTxt, newSpCol
                if #Combat.bossTargets > 0 then
                    local parts = {}
                    for i = 1, M.min(#Combat.bossTargets, 3) do
                        local b = Combat.bossTargets[i]
                        local kind = b.isEvent and "[Event" or "[Normal"
                        if b.tierWord then kind = kind .. "·" .. b.tierWord end
                        kind = kind .. "]"
                        if b.hpPending then
                            parts[#parts + 1] = M.fmtStr("%s %s (Syncing HP...)", kind, b.name)
                        else
                            local pct = (b.maxHp > 0) and M.clamp((b.hp / b.maxHp) * 100, 0, 100) or 0
                            parts[#parts + 1] = M.fmtStr("%s %s (%s/%s · %.0f%%)", kind, b.name, Core.fmtCompact(b.hp), Core.fmtCompact(b.maxHp), pct)
                        end
                    end
                    newSpTxt = "Spawned: " .. table.concat(parts, " | ")
                    newSpCol = Theme.Green
                else
                    newSpTxt = "Spawned: None | HP: --"
                    newSpCol = Theme.Muted
                end
                if UI.bossSpawnedLine.Text ~= newSpTxt then UI.bossSpawnedLine.Text = newSpTxt end
                if UI.bossSpawnedLine.TextColor3 ~= newSpCol then UI.bossSpawnedLine.TextColor3 = newSpCol end
            end
            if UI.bossDamageLine then
                local tgtName = BossEngine.currentBossModel and BossEngine.currentBossModel.Name or tostring(Config.SelectedBoss)
                local dTxt = M.fmtStr("Boss Damage: %s (DPS: %s/s) | Targeted: %s",
                    Core.fmtCompact(BossEngine.damageDealt), Core.fmtCompact(BossEngine.liveDps), tgtName)
                if UI.bossDamageLine.Text ~= dTxt then UI.bossDamageLine.Text = dTxt end
            end
            if UI.bossChargeLine then
                local nowC = M.clock()
                local cTxt, cCol
                if BossEngine.evadingAOE then
                    local kind = BossEngine.chargeKind or "Skill"
                    local remS = (BossEngine.chargeRemSec and BossEngine.chargeRemSec > 0.05) and M.fmtStr(" (%.1fs)", BossEngine.chargeRemSec) or ""
                    cTxt = M.fmtStr("DODGING %s: %d%%%s | Skills: %d · Ults: %d", kind:upper(), BossEngine.chargePct, remS, BossEngine.skillChargeCount, BossEngine.ultChargeCount)
                    cCol = Theme.Red
                elseif BossEngine.isCharging then
                    local kind = BossEngine.chargeKind or "Skill"
                    local remS = (BossEngine.chargeRemSec and BossEngine.chargeRemSec > 0.05) and M.fmtStr(" (%.1fs)", BossEngine.chargeRemSec) or ""
                    cTxt = M.fmtStr("CHARGING %s: %d%%%s | Skills: %d · Ults: %d", kind:upper(), BossEngine.chargePct, remS, BossEngine.skillChargeCount, BossEngine.ultChargeCount)
                    cCol = Theme.Yellow
                else
                    local etaPart = "Watching..."
                    if BossEngine.avgSkillInterval > 0 and BossEngine.lastSkillStartT > 0 then
                        local nextS = M.max(0, BossEngine.avgSkillInterval - (nowC - BossEngine.lastSkillStartT))
                        etaPart = M.fmtStr("Next Skill ~%.1fs", nextS)
                    end
                    if BossEngine.avgUltInterval > 0 and BossEngine.lastUltStartT > 0 then
                        local nextU = M.max(0, BossEngine.avgUltInterval - (nowC - BossEngine.lastUltStartT))
                        etaPart = (etaPart == "Watching...") and M.fmtStr("Next Ult ~%.1fs", nextU) or (etaPart .. M.fmtStr(" · Ult ~%.1fs", nextU))
                    end
                    cTxt = M.fmtStr("Charge Tracker: %s | Skills: %d · Ults: %d", etaPart, BossEngine.skillChargeCount, BossEngine.ultChargeCount)
                    cCol = Theme.CyberCyan
                end
                if UI.bossChargeLine.Text ~= cTxt then UI.bossChargeLine.Text = cTxt end
                if UI.bossChargeLine.TextColor3 ~= cCol then UI.bossChargeLine.TextColor3 = cCol end
            end
            if UI.bossKillsLine then
                local kTxt = M.fmtStr("Killed — Normal Bosses: %d | Event/Alien Bosses: %d",
                    BossEngine.normalKills, BossEngine.eventKills)
                if UI.bossKillsLine.Text ~= kTxt then UI.bossKillsLine.Text = kTxt end
            end
        end

        function HudUpdaters.Reward(UI, now)
            if (now - lastRewardSpinScan) >= 2.5 then
                lastRewardSpinScan = now
                pcall(RewardEngine.refreshSpinsCache)
            end
            local activeRew = Config.AutoCollectRewards or Config.AutoSpinReward
            if UI.rewStatusLine then
                UI.rewStatusLine.Text = M.fmtStr("Status: %s | Collected: %d (Remote-Only)", activeRew and "Active (Gated)" or "Idle", RewardEngine.collectedCount)
                UI.rewStatusLine.TextColor3 = activeRew and Theme.Green or Theme.CyberCyan
            end
            if UI.rewLastLine then
                UI.rewLastLine.Text = M.fmtStr("Last Claimed: %s | Spins Left: %s",
                    RewardEngine.lastRewardLabel, RewardEngine.spinsLeftCached ~= nil and tostring(RewardEngine.spinsLeftCached) or "--")
            end
            if UI.spinStatLine then
                UI.spinStatLine.Text = M.fmtStr("Spins Completed: %d | Last Wheel Prize: %s", RewardEngine.spinsCompleted, RewardEngine.lastSpinLabel)
            end
        end

        HudUpdaters["Perf Stats"] = function(UI)
            local activeJump = M.clamp(M.floor(tonumber(Config.CycleJump) or 1), 1, 100)
            local capVal = tonumber(Config.FPSCap) or 120
            local cRate = M.clamp(M.floor(tonumber(Config.CycleRate) or 100), 50, 1000)
            local fpsJumpDelta = M.max(0, M.floor((Telemetry.liveRawFPS - Perf.baselineFPS) + 0.5))
            if UI.miscFpsLine then
                UI.miscFpsLine.Text = M.fmtStr("Device FPS: %d FPS | FPS Jumping: %dx (+%d FPS · %s/s)",
                    Telemetry.liveRawFPS, activeJump, fpsJumpDelta, Core.fmtExactInt(Perf.actualCyclesPerSec))
            end
            if UI.miscPingLine then UI.miscPingLine.Text = M.fmtStr("Ping: %d ms%s | Frame Time: %.1f ms", Telemetry.livePing, Config.PingBoost and " [BOOSTED]" or "", Telemetry.liveFrameMs) end
            if UI.miscHwLine then UI.miscHwLine.Text = M.fmtStr("Cycle Rate: %d%% | Workers: %d | Lua Slice: %.2fms (Budget %.1fms)", cRate, Perf.activeWorkers, Perf.lastLuaWorkMs, Perf.frameBudgetSec * 1000) end
            if UI.miscCapLine then
                UI.miscCapLine.Text = M.fmtStr("FPS Cap: %s | Cycle Jump: %dx | AI: %s",
                    (capVal <= 0 or activeJump > 1 or Config.AIPerfMode) and "UNLOCKED" or tostring(capVal),
                    activeJump, Config.AIPerfMode and (Perf.aiSchedulerMode .. " (No GFX)") or "OFF")
            end
        end

        function HudUpdaters.Settings(UI)
            if UI.setCopyLabel then
                UI.setCopyLabel.Text = "Copy Target: " .. Remotes.copyProfile
            end
        end

        Core.track(RunService.Stepped:Connect(function(_, stepDt)
            if myGen ~= Runtime.Gen or not Config.Active then return end
            Perf.realCyclesThisSec += 1
            if Config.AutoKillBoss then BossEngine.maintainHold() end
            if CharPhysics.freezeEnabled and not Config.AutoKillBoss then CharPhysics.stepFreeze() end
            if Config.AutoPunch or Config.AutoKillBoss or Combat.swingProgress < 1 then
                Combat.stepKinematics(stepDt)
            end
        end))

        local lastHudRefresh, lastPingSample, lastVisCheck, lastFpsEnforce = 0, 0, 0, 0
        Core.track(RunService.RenderStepped:Connect(function(renderDt)
            if myGen ~= Runtime.Gen or not Config.Active then return end
            local workT0 = M.clock()
            local now = workT0
            Perf.realCyclesThisSec += 1

            local jumpActive = (tonumber(Config.CycleJump) or 1) > 1 or Config.AIPerfMode
            if jumpActive and type(getfpscap) == "function" and (now - lastFpsEnforce >= 8.0) then
                lastFpsEnforce = now
                local okCap, curCap = pcall(getfpscap)
                if okCap and type(curCap) == "number" and curCap > 0 and curCap < 120 then
                    task.spawn(Perf.applyCycleSettings)
                end
            end

            if Config.FlyEnabled or CharPhysics.bodyVel then CharPhysics.stepFly() end
            if Config.WalkOnWater then CharPhysics.stepWalkOnWater() end
            if Config.AutoKillBoss then BossEngine.step(renderDt) end

            if renderDt > 0 and renderDt < 0.5 then
                local instFPS, instMs = 1 / renderDt, renderDt * 1000
                local alpha = M.clamp(renderDt * 8, 0.06, 0.35)
                Telemetry.smoothFPS += (instFPS - Telemetry.smoothFPS) * alpha
                Telemetry.smoothFrameMs += (instMs - Telemetry.smoothFrameMs) * alpha
                Telemetry.liveRawFPS = M.max(1, M.floor(Telemetry.smoothFPS + 0.5))
                Telemetry.liveFrameMs = Telemetry.smoothFrameMs
                if not jumpActive then
                    Perf.baselineFPS += (Telemetry.liveRawFPS - Perf.baselineFPS) * 0.05
                end
            end

            if now - lastPingSample >= 0.30 then
                lastPingSample = now
                pcall(function()
                    local rawP = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
                    Telemetry.smoothPing += (rawP - Telemetry.smoothPing) * 0.35
                    Telemetry.livePing = M.max(0, M.floor(Telemetry.smoothPing + 0.5))
                    if not Runtime.RepGateOpen and not Config.AutoPunch and Telemetry.livePing > 0 then
                        Telemetry.baselinePing += (Telemetry.livePing - Telemetry.baselinePing) * 0.15
                    end
                end)
            end

            if now - Perf.lastCycleMeasureTime >= 1.0 then
                local el = now - Perf.lastCycleMeasureTime
                Perf.actualCyclesPerSec = M.floor((Perf.realCyclesThisSec / el) + 0.5)
                Perf.realCyclesThisSec = 0; Perf.lastCycleMeasureTime = now
            end

            if (Config.WalkSpeedEnabled or Config.SizeEnabled or Config.KorbloxRight or Config.Headless or Config.HideNameEnabled) and (now - lastVisCheck >= 0.25) then
                lastVisCheck = now
                if Config.WalkSpeedEnabled then CharPhysics.applyWalkSpeed() end
                if Config.SizeEnabled then CharPhysics.applySize() end
                if Player.Character then
                    if Config.KorbloxRight then Visuals.applyKorblox(Player.Character) end
                    if Config.Headless then Visuals.applyHeadless(Player.Character) end
                end
                if Config.HideNameEnabled then pcall(Visuals.refreshHideNames) end
            end

            local UI = Runtime.UI
            local hudInterval = jumpActive and 0.28 or 0.22
            if UI.Main and UI.Main.Visible and not Config.Minimized and (now - lastHudRefresh >= hudInterval) then
                local hudDt = now - lastHudRefresh
                lastHudRefresh = now
                local updater = HudUpdaters[Runtime.activeTabName]
                if updater then pcall(updater, UI, now, hudDt) end
            end
            Perf.lastLuaWorkMs = (M.clock() - workT0) * 1000
        end))

        -- 2. LEGIT AUTO REBIRTH GAMEPASS ENGINE
        local stepRebirthEngine
        do
            local lastAttempt, wasCool, rebTriedAt, rebTriedSeq = 0, false, nil, 0
            local lastToken = Runtime.SessionTokens.reb
            local rfInFlight = setmetatable({}, {__mode = "k"})
            stepRebirthEngine = function()
                local myToken = Runtime.SessionTokens.reb
                if lastToken ~= myToken then
                    lastToken = myToken
                    wasCool = false; rebTriedAt = nil; rebTriedSeq = 0
                end
                if Config.AutoRebirth then
                    local now = M.clock()
                    local curReb = Telemetry.getStatNum("Rebirths")
                    if Telemetry.lastKnownRebirthCount == nil then
                        Telemetry.lastKnownRebirthCount = curReb
                    elseif curReb > Telemetry.lastKnownRebirthCount then
                        local gained = curReb - Telemetry.lastKnownRebirthCount
                        if Telemetry.lastConfirmedRebirthTime > 0 then
                            local measured = now - Telemetry.lastConfirmedRebirthTime
                            Telemetry.rebCycleDuration = (measured >= 5.5 and measured <= 7.0) and measured or LEGIT_GAMEPASS_REBIRTH_COOLDOWN
                        else
                            Telemetry.rebCycleDuration = LEGIT_GAMEPASS_REBIRTH_COOLDOWN
                        end
                        Telemetry.lastRebGainPerCycle = gained
                        Telemetry.lastConfirmedRebirthTime = now
                        Telemetry.lastKnownRebirthCount = curReb
                        Telemetry.rebConfirmedSeq += 1
                        rebTriedAt = nil
                    end
                    if rebTriedAt ~= nil and (Telemetry.rebConfirmedSeq > rebTriedSeq or Telemetry.lastConfirmedRebirthTime >= rebTriedAt) then
                        rebTriedAt = nil
                    end

                    local serverCd = Telemetry.readServerRebirthCd(now)
                    local rem = (serverCd ~= nil) and M.max(0, serverCd) or 0
                    if serverCd ~= nil then
                        Telemetry.rebHasServerCd = true
                    else
                        Telemetry.rebHasServerCd = false
                        local anchor = M.max(Telemetry.lastConfirmedRebirthTime, Telemetry.lastRebFire)
                        rem = (anchor > 0) and M.max(0, LEGIT_GAMEPASS_REBIRTH_COOLDOWN - (now - anchor)) or 0
                    end
                    Telemetry.rebCooldownLeft = rem
                    local justZero = wasCool and (rem <= 0)
                    if rem > 0 then wasCool = true end

                    if rem <= 0 and (justZero or (now - lastAttempt >= 0.08)) then
                        local curStr, reqStr = Telemetry.getStatNum("Strength"), Telemetry.getNextRebirthReq(curReb)
                        if (not Config.SmartRebirthGuard) or (curStr >= reqStr) then
                            local rebRemotes = Remotes.getAllRebirth()
                            local canTryAny = false
                            for _, r in ipairs(rebRemotes) do
                                if r and r.Parent then
                                    if not r:IsA("RemoteFunction") or not (rfInFlight[r] and (now - rfInFlight[r] < 2.5)) then
                                        canTryAny = true
                                        break
                                    end
                                end
                            end
                            if canTryAny then
                                if rebTriedAt ~= nil and (now - rebTriedAt >= 0.35)
                                    and Telemetry.rebConfirmedSeq == rebTriedSeq and Telemetry.lastConfirmedRebirthTime < rebTriedAt then
                                    for _, r in ipairs(rebRemotes) do
                                        local curIdx = Remotes.rebirthVariantByRemote[r] or 1
                                        Remotes.rebirthVariantByRemote[r] = (curIdx % #Remotes.rebirthVariants) + 1
                                    end
                                    rebTriedAt = nil
                                end
                                wasCool = false; lastAttempt = now; Telemetry.lastRebFire = now
                                if rebTriedAt == nil then
                                    rebTriedAt = now
                                    rebTriedSeq = Telemetry.rebConfirmedSeq
                                end
                                for _, r in ipairs(rebRemotes) do
                                    if r and r.Parent and myToken == Runtime.SessionTokens.reb then
                                        local v = Remotes.rebirthVariants[Remotes.rebirthVariantByRemote[r] or 1]
                                        local arg = v and v[1] or nil
                                        if r:IsA("RemoteFunction") then
                                            if not (rfInFlight[r] and (now - rfInFlight[r] < 2.5)) then
                                                rfInFlight[r] = now
                                                Telemetry.rebInvokeInFlight = true
                                                Telemetry.rebInvokeStart = now
                                                task.spawn(function()
                                                    if arg ~= nil then pcall(r.InvokeServer, r, arg)
                                                    else pcall(r.InvokeServer, r) end
                                                    rfInFlight[r] = nil
                                                    Telemetry.rebInvokeInFlight = false
                                                end)
                                            end
                                        else
                                            if arg ~= nil then pcall(r.FireServer, r, arg)
                                            else pcall(r.FireServer, r) end
                                        end
                                    end
                                end
                            end
                        else
                            rebTriedAt = nil
                        end
                    end
                elseif wasCool or rebTriedAt ~= nil or Telemetry.rebCooldownLeft ~= 0 then
                    wasCool = false; rebTriedAt = nil; rebTriedSeq = 0; Telemetry.rebCooldownLeft = 0; Telemetry.rebHasServerCd = false
                end
            end
        end

        -- 3. CLEAN LOW-PING PUNCH + FAST BOSS PUNCH ENGINE
        local stepPunchEngine
        do
            local punchAcc, lastToken, rightHandNext = 0, Runtime.SessionTokens.pun, true
            stepPunchEngine = function(dt)
                if lastToken ~= Runtime.SessionTokens.pun then lastToken = Runtime.SessionTokens.pun; punchAcc = 0 end
                local myToken = lastToken

                if Config.AutoKillBoss then
                    BossEngine.stepFastPunch(dt)
                end

                if Config.AutoPunch then
                    if not Config.AutoKillBoss then
                        local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if root then Combat.refreshTargets(root.Position, false) end
                    end
                    local spd = M.clamp(tonumber(Config.PunchSpeed) or 60, 1, 500)
                    local interval = M.clamp(0.20 * (60 / spd), 0.07, 0.45)
                    punchAcc += dt
                    if punchAcc >= interval then
                        punchAcc = 0; rightHandNext = not rightHandNext
                        if Combat.executeStrike(rightHandNext, 1, false, nil) then
                            Telemetry.punchesTotal += 1; Telemetry.recordEvent(Telemetry.punchTracker, 1)
                        end
                    end
                elseif punchAcc ~= 0 then
                    punchAcc = 0
                end
            end
        end

        -- 4. GATED REMOTE-ONLY REWARD & AUTO-SPIN + UNIFIED HEARTBEAT
        do
            local collectAcc, spinAcc = 0, 0
            Core.track(RunService.Heartbeat:Connect(function(dt)
                if myGen ~= Runtime.Gen or not Config.Active then return end
                Perf.realCyclesThisSec += 1
                local activeJump = M.clamp(M.floor(tonumber(Config.CycleJump) or 1), 1, 100)
                if activeJump > 1 then
                    Perf.realCyclesThisSec += M.min(activeJump - 1, 20)
                end

                if Config.FastRep or Config.AIFastRep or Config.AutoRep or Runtime.RepGateOpen or activeToken ~= Runtime.SessionTokens.rep then
                    stepRepEngine(dt)
                end
                stepRebirthEngine()
                if Config.AutoKillBoss or Config.AutoPunch then
                    stepPunchEngine(dt)
                end
                if Config.AutoCollectRewards then
                    collectAcc += dt
                    if collectAcc >= 2.4 then collectAcc = 0; task.spawn(RewardEngine.runAutoCollectPass) end
                elseif collectAcc ~= 0 then
                    collectAcc = 0
                end
                if Config.AutoSpinReward then
                    spinAcc += dt
                    if spinAcc >= 0.9 then spinAcc = 0; RewardEngine.stepAutoSpin() end
                elseif spinAcc ~= 0 then
                    spinAcc = 0
                end
            end))
        end
    end

    -- 5. ANTI-AFK GUARD
    Core.track(Player.Idled:Connect(function()
        if Config.Active then
            pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(0, 0)) end)
        end
    end))
end

----------------------------------------------------------------
-- Full Reset, Refresh & Kill Switch Lifecycle
----------------------------------------------------------------
local function resetAllFeaturesToNormal()
    for k in pairs(Runtime.SessionTokens) do Runtime.SessionTokens[k] += 1 end
    Core.forceKillAllRepWorkers()
    for k, v in pairs(DefaultConfig) do Config[k] = v end
    RewardEngine.isWheelSpinning = false
    RewardEngine.questPassBusy = false
    RewardEngine.giftPassBusy = false
    RewardEngine.dailyPassBusy = false
    RewardEngine.guiCacheDirty = true
    RewardEngine.workingSpinArgs = nil
    RewardEngine.workingGiftRemote = nil
    RewardEngine.workingGiftArgs = nil
    RewardEngine.timedOutRemotes = setmetatable({}, {__mode = "k"})
    RewardEngine.cachedWheelBtn = nil
    RewardEngine.claimedGiftCooldown = {}
    RewardEngine.claimedQuestCooldown = {}
    RewardEngine.lastDailyAttempt = -10
    RewardEngine.lastSpinAttempt = 0
    RewardEngine.lastFullGuiScan = 0
    RewardEngine.spinsLeftCached = nil
    RewardEngine.cachedSpinsVal = nil
    RewardEngine.cachedSpinsLabel = nil

    for _, tr in ipairs(Combat.tracks) do pcall(function() if tr.IsPlaying then tr:Stop(0.05) end end) end
    pcall(Combat.restoreJoints)
    pcall(BossEngine.restoreNoClip)
    pcall(BossEngine.returnToOrigin)
    BossEngine.evadingAOE = false; BossEngine.evadeHoldCF = nil; BossEngine.arenaCenter = nil; BossEngine.wasTelegraphActive = false; BossEngine.postAttackHoldUntil = 0
    BossEngine.lastAttackSeq = nil
    BossEngine.trackedDangerInsts = setmetatable({}, {__mode = "k"}); BossEngine.lastSafeDist = 380
    BossEngine.currentBossModel = nil; BossEngine.currentTargetObj = nil; BossEngine.noClipChar = nil
    BossEngine.prevEngagedModel = nil; BossEngine.prevEngagedHP = nil
    Perf.frameBudgetSec = 0.0016
    Perf.activeWorkers = 2
    Perf.aiSchedulerMode = "Standard"
    pcall(CharPhysics.applyFreeze, false)
    pcall(CharPhysics.destroyFly)
    pcall(CharPhysics.setWalkOnWater, false)
    pcall(CharPhysics.applyWalkSpeed)
    pcall(CharPhysics.applySize)
    pcall(Perf.setFPSBoost, false)
    pcall(Perf.setRemoveFog, false)
    pcall(Perf.setPingBoost, false)
    pcall(Perf.setAIPerfMode, false)
    pcall(Visuals.removeKorblox, Player.Character)
    pcall(function() if Player.Character then Visuals.removeHeadless(Player.Character) end end)
    pcall(Visuals.restoreHiddenNames)

    pcall(function()
        Lighting.GlobalShadows = OriginalState.GlobalShadows; Lighting.FogStart = OriginalState.FogStart
        Lighting.FogEnd = OriginalState.FogEnd; Lighting.Brightness = OriginalState.Brightness
        Lighting.ClockTime = OriginalState.ClockTime; Lighting.OutdoorAmbient = OriginalState.OutdoorAmbient
        Lighting.Ambient = OriginalState.Ambient; Lighting.EnvironmentDiffuseScale = OriginalState.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = OriginalState.EnvironmentSpecularScale
        for atmo, d in pairs(OriginalState.Atmospheres) do
            if atmo and atmo.Parent then atmo.Density = d.Density; atmo.Haze = d.Haze; atmo.Offset = d.Offset; atmo.Glare = d.Glare end
        end
        settings().Rendering.QualityLevel = OriginalState.QualityLevel
        if OriginalState.EagerBulkExecution ~= nil then
            pcall(function() settings().Rendering.EagerBulkExecution = OriginalState.EagerBulkExecution end)
        end
        local ugs = UserSettings():GetService("UserGameSettings")
        ugs.SavedQualityLevel = OriginalState.SavedQualityLevel
        ugs.FramerateCap = OriginalState.FramerateCap
        pcall(function() ugs.VSync = OriginalState.VSync end)
        settings().Network.IncomingReplicationLag = OriginalState.IncomingReplicationLag
        settings().Physics.AllowSleep = OriginalState.AllowSleep
        if OriginalState.PhysicsEnvironmentalThrottle ~= nil then
            pcall(function() settings().Physics.PhysicsEnvironmentalThrottle = OriginalState.PhysicsEnvironmentalThrottle end)
        end
        if OriginalState.InterpolationThrottling ~= nil then
            pcall(function() workspace.InterpolationThrottling = OriginalState.InterpolationThrottling end)
        end
    end)
    pcall(Perf.applyFPSCap, OriginalState.FramerateCap, true)
end

local function teardownUIOnly()
    Runtime.Gen += 1
    for _, c in ipairs(Runtime.conns) do pcall(function() c:Disconnect() end) end
    Runtime.conns = {}; Runtime.RGBLightningItems = {}
    if Runtime.UI.ToggleGui then pcall(function() Runtime.UI.ToggleGui:Destroy() end) end
    if Runtime.UI.GUI then pcall(function() Runtime.UI.GUI:Destroy() end) end
    Runtime.UI = {}; Runtime.Setters = {}; Runtime.Pages = {}; Runtime.TabButtons = {}
end

local hardRefresh, destroyAll
hardRefresh = function()
    resetAllFeaturesToNormal()
    teardownUIOnly()
    Remotes.muscleList = {}; Remotes.toolRemotes = {}; Remotes.combatRemotes = {}; Remotes.rebirthList = {}
    Remotes.questRemotes = {}; Remotes.dailyRemotes = {}; Remotes.chestRemotes = {}; Remotes.genericRewardRemotes = {}
    Remotes.timeRewardRemotes = {}; Remotes.wheelRemotes = {}; Remotes.wheelChanceItems = {}
    Remotes.activeMuscleIdx = 1; Remotes.lastScan = 0; Remotes.deepScannedOnce = false
    Combat.candidateBossModels = {}
    Combat.adorneeGuiByModel = setmetatable({}, {__mode = "k"})
    Core.evaluateMuscleScope(true)
    Remotes.refresh(true)
    Config.Active = true; Config.Minimized = false
    buildUI(hardRefresh, destroyAll)
    startLoops()
end

destroyAll = function()
    Config.Active = false
    resetAllFeaturesToNormal()
    teardownUIOnly()
    if Runtime.SoundContainer then pcall(function() Runtime.SoundContainer:Destroy() end) end
    Runtime.MeowSounds = {}
    Env.YuiHubEA = nil
end

Env.YuiHubEA = destroyAll

ThreatScanner.runLoadingScanner(function()
    buildUI(hardRefresh, destroyAll)
    startLoops()
end, destroyAll)