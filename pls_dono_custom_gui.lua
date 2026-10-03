repeat
    task.wait()
until game:IsLoaded()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
local DEFAULT_PLS_DONATE_PLACE_ID = 8737602449
local VC_PLS_DONATE_PLACE_ID = 8943844393
local EXTRA_PLS_DONATE_PLACE_ID = 127213917680436

local DEFAULT_AUTOEXEC_URL = "https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_dono_custom_gui.lua"
if type(SharedEnv.PLS_DONO_AUTOEXEC_URL) ~= "string" or SharedEnv.PLS_DONO_AUTOEXEC_URL == "" then
    SharedEnv.PLS_DONO_AUTOEXEC_URL = DEFAULT_AUTOEXEC_URL
end
if type(SharedEnv.PLS_DONO_AUTOEXEC_SOURCE) ~= "string" or SharedEnv.PLS_DONO_AUTOEXEC_SOURCE == "" then
    SharedEnv.PLS_DONO_AUTOEXEC_SOURCE = "loadstring(game:HttpGet('" .. SharedEnv.PLS_DONO_AUTOEXEC_URL .. "'))()"
end

local TextChatService = game:GetService("TextChatService")
local CONFIG_MODULE_URL = "https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/config.lua"
local configModuleOk, ConfigModule = pcall(function()
    local source = game:HttpGet(CONFIG_MODULE_URL)
    local chunk, compileError = loadstring(source)
    assert(chunk, compileError)
    local module = chunk()
        assert(type(module) == "table" and type(module.defaults) == "table" and type(module.create) == "function" and type(module.emoteOptions) == "table", "config module has an invalid interface")
    return module
end)
if not configModuleOk then
    warn("Could not load PLS DONATE config module:", ConfigModule)
    return
end

local notificationTimestamps = {}
local avatarThumbnailCache = {}
local getNearestPlayerInfo
local localized

local function notify(title, text, duration, dedupeKey, cooldown)
    local now = tick()
    if dedupeKey and cooldown then
        local last = notificationTimestamps[dedupeKey] or 0
        if now - last < cooldown then
            return
        end
        notificationTimestamps[dedupeKey] = now
    end

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "PLS DONATE"),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 4,
        })
    end)
end

local function trimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeMessageList(value, fallback)
    local normalized = {}
    if type(value) == "table" then
        for _, entry in ipairs(value) do
            local text = trimText(entry)
            if text ~= "" then
                table.insert(normalized, text)
            end
        end
    end

    if #normalized == 0 and type(fallback) == "table" then
        for _, entry in ipairs(fallback) do
            local text = trimText(entry)
            if text ~= "" then
                table.insert(normalized, text)
            end
        end
    end

    return normalized
end

local function cloneRef(v)
    if type(cloneref) == "function" then
        return cloneref(v)
    end
    return v
end

local function resolveGuiParent()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
    if playerGui then
        return playerGui
    end

    local ok, coreGui = pcall(function()
        return cloneRef(game:GetService("CoreGui"))
    end)
    if ok and coreGui then
        return coreGui
    end

    return nil
end

local sendChatMessage
local serverHopNow
local suppressBoothTextAutoApply = (type(SharedEnv.PLS_DONO_BOOTH_TEXT_SUPPRESS) == "boolean" and SharedEnv.PLS_DONO_BOOTH_TEXT_SUPPRESS) or false

local function queueScriptOnTeleport()
    local queueOnTeleport = (syn and syn.queue_on_teleport)
        or queue_on_teleport
        or queueonteleport
        or (fluxus and fluxus.queue_on_teleport)
    if not queueOnTeleport then
        return false
    end

    local restoreState = [[
        local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
        if type(SharedEnv.PLS_DONO_SETTINGS_SNAPSHOT) == "table" then
            SharedEnv.plsdonoSettings = SharedEnv.PLS_DONO_SETTINGS_SNAPSHOT
        end
    ]]

    local primarySource
    if type(SharedEnv.PLS_DONO_AUTOEXEC_SOURCE) == "string" and SharedEnv.PLS_DONO_AUTOEXEC_SOURCE ~= "" then
        primarySource = SharedEnv.PLS_DONO_AUTOEXEC_SOURCE
    elseif type(SharedEnv.PLS_DONO_AUTOEXEC_URL) == "string" and SharedEnv.PLS_DONO_AUTOEXEC_URL ~= "" then
        primarySource = "loadstring(game:HttpGet('" .. SharedEnv.PLS_DONO_AUTOEXEC_URL .. "'))()"
    end

    if primarySource then
        return pcall(function()
            queueOnTeleport(restoreState .. "\n" .. primarySource)
        end)
    end

    return false
end

local function rejoinAfterUserBoothUpdate()
    suppressBoothTextAutoApply = true
    SharedEnv.PLS_DONO_BOOTH_TEXT_SUPPRESS = true
    queueScriptOnTeleport()

    task.delay(5, function()
        if serverHopNow then
            serverHopNow("booth-update", 24, 25, 1)
        end

        pcall(function()
            LocalPlayer:Kick(localized("rejoinMessage"))
        end)
    end)
end

local function cleanupWorkspaceCollisionModels()
    local names = {
        "Bench",
        "WaterFountain",
    }

    local lookup = {}
    for _, name in ipairs(names) do
        lookup[name] = true
    end

    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Model") and lookup[descendant.Name] then
            descendant:Destroy()
        end
    end
end

local function watchWorkspaceCollisionModelCleanup()
    Workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") and (child.Name == "Bench" or child.Name == "WaterFountain") then
            task.delay(0.1, function()
                if child.Parent then
                    child:Destroy()
                end
            end)
        end
    end)
end

local GuiParent = resolveGuiParent()
if not GuiParent then
    return
end

if SharedEnv.PLS_DONO_CUSTOM_GUI_LOADED and GuiParent:FindFirstChild("PlsDonoCustomGui") then
    return
end

-- Recover gracefully if a previous run crashed before creating the UI.
SharedEnv.PLS_DONO_CUSTOM_GUI_LOADED = nil
SharedEnv.PLS_DONO_CUSTOM_GUI_LOADED = true

local SETTINGS_FILE = "plsdono_custom_settings.json"
local SETTINGS_BACKUP_FILE = "plsdono_custom_settings_backup.json"
local LEGACY_SETTINGS_FILE = "plsdonatesettings.txt"
local LEGACY_SETTINGS_BACKUP_FILE = "plsdonatesettingsbackup.txt"

local defaults = ConfigModule.defaults

local boothFontOptions = {"SciFi"}
do
    local ok, enumItems = pcall(function()
        return Enum.Font:GetEnumItems()
    end)
    if ok and type(enumItems) == "table" and #enumItems > 0 then
        boothFontOptions = {}
        for _, fontItem in ipairs(enumItems) do
            table.insert(boothFontOptions, fontItem.Name)
        end
        table.sort(boothFontOptions)
    end
end

local settings = {}

local function deepCopy(tbl)
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            out[k] = deepCopy(v)
        else
            out[k] = v
        end
    end
    return out
end

local function mergeDefaults(target, defs)
    for k, v in pairs(defs) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = deepCopy(v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            mergeDefaults(target[k], v)
        end
    end
end

local function canUseFiles()
    return type(isfile) == "function" and type(readfile) == "function" and type(writefile) == "function"
end

local function migrateLegacySettings(data)
    if type(data) ~= "table" then
        return data
    end

    data.hexBox = nil
    return data
end

local function saveSettings()
    SharedEnv.PLS_DONO_SETTINGS_SNAPSHOT = deepCopy(settings)
    SharedEnv.plsdonoSettings = settings

    if not canUseFiles() then
        return
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(settings)
    end)
    if not ok then
        return
    end

    pcall(function()
        writefile(SETTINGS_FILE, encoded)
        writefile(SETTINGS_BACKUP_FILE, encoded)
        writefile(LEGACY_SETTINGS_FILE, encoded)
        writefile(LEGACY_SETTINGS_BACKUP_FILE, encoded)
    end)
end

local function readSettingsFile(fileName)
    if not canUseFiles() or not isfile(fileName) then
        return nil
    end

    local ok, content = pcall(function()
        return readfile(fileName)
    end)
    if not ok or type(content) ~= "string" or content == "" then
        return nil
    end

    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if not decodeOk or type(data) ~= "table" then
        return nil
    end

    return migrateLegacySettings(data)
end

local function loadSettings()
    settings = deepCopy(defaults)

    if type(SharedEnv.PLS_DONO_SETTINGS_SNAPSHOT) == "table" then
        settings = migrateLegacySettings(deepCopy(SharedEnv.PLS_DONO_SETTINGS_SNAPSHOT))
        mergeDefaults(settings, defaults)
    end

    if not canUseFiles() then
        SharedEnv.PLS_DONO_SETTINGS_SNAPSHOT = deepCopy(settings)
        SharedEnv.plsdonoSettings = settings
        return
    end

    local candidates = {
        SETTINGS_FILE,
        SETTINGS_BACKUP_FILE,
        LEGACY_SETTINGS_FILE,
        LEGACY_SETTINGS_BACKUP_FILE,
    }

    for _, fileName in ipairs(candidates) do
        local data = readSettingsFile(fileName)
        if type(data) == "table" then
            settings = deepCopy(data)
            mergeDefaults(settings, defaults)
            SharedEnv.PLS_DONO_SETTINGS_SNAPSHOT = deepCopy(settings)
            SharedEnv.plsdonoSettings = settings
            saveSettings()
            return
        end
    end

    settings = deepCopy(defaults)
    SharedEnv.PLS_DONO_SETTINGS_SNAPSHOT = deepCopy(settings)
    SharedEnv.plsdonoSettings = settings
    saveSettings()
end

loadSettings()
settings.thanksMessage = normalizeMessageList(settings.thanksMessage, defaults.thanksMessage)
settings.begMessage = normalizeMessageList(settings.begMessage, defaults.begMessage)
SharedEnv.PLS_DONO_SETTINGS_SNAPSHOT = deepCopy(settings)
SharedEnv.plsdonoSettings = settings
saveSettings()

local function humanizeLabel(value)
    local text = tostring(value or "")
    text = text:gsub("(%l)(%u)", "%1 %2")
    text = text:gsub("(%d)(%a)", "%1 %2")
    text = text:gsub("(%a)(%d)", "%1 %2")
    text = text:gsub("^tab%w+", function(part)
        return part:match("^tab(.+)$") or part
    end)
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+", " ")
    if text ~= "" then
        text = text:sub(1, 1):upper() .. text:sub(2)
    end
    return text
end

local labelTextMap = {
    rejoinMessage = "rejoining server, you updated booth text and your buttons were invisible.",
    webhookTitle = "@%s has gotten tipped %dR$ by %s, check your balance! 🎉",
    serverHopTitle = "@%s has serverhopped",
    tabBooth = "Booth",
    tabMain = "Main",
    tabChat = "Chat",
    tabWebhook = "Webhook",
    tabServerHop = "Server Hop",
    boothSection = "Booth Settings",
    mainSection = "Main Settings",
    chatSection = "Chat Settings",
    webhookSection = "Webhook Settings",
    serverSection = "Serverhop Settings",
    textUpdate = "Text Update",
    goalBarColor = "Goal Bar Color",
    goalBarHeader = "Goal Bar Header:",
    goalBarHint = "Use $G here if you want the current goal amount.",
    pasteGoalBar = "Paste Goal Bar",
    customBoothText = "Custom Booth Text:",
    boothTextPlaceholder = "Write the exact booth text here...",
    boothTextTokens = "$C = current | $G = goal | $BAR = goal progress",
    textColors = "Text colors: green, blue, yellow, black, white, red, orange, pink, purple, gray/grey, or #RRGGBB",
    font = "Font",
    update = "Update",
    standingPosition = "Standing Position",
    boothMovementMode = "Booth Move Mode",
    helicopter = "Helicopter On-Donation",
    spin = "1R$= +1 Spin Speed",
        catalogEmote = "Catalog Emote",
        animSpeed = "Anim Speed",
        animSpeedMultiplier = "Anim Speed Multiplier",
        animSpeedPerRobux = "1R$= +1 Anim Speed",
    testDonationAmount = "Test Donation Amount (R$)",
    testDonation = "Test Donation",
    autoThanks = "Auto Thank You",
    thanksDelay = "Thanks Delay (S)",
    thanksMessages = "Thank You Messages",
    autoBeg = "Auto Beg",
    begDelay = "Beg Delay (S)",
    begMessages = "Begging Messages",
    webhookEnabled = "Webhook Enabled",
    webhookUrl = "Webhook URL",
    notifyPerHop = "Notify Per Hop",
    antiAfk = "Anti AFK",
    autoServerHop = "Auto Server Hop",
    serverHopDelay = "Server Hop Delay (Minutes)",
    minPlayers = "Min Players in Server",
    maxPlayers = "Max Players in Server",
    smallServer = "Hop When Server Is Small",
    smallThreshold = "Small Server Threshold",
    plusHop = "Plus Hop",
    plusMemberTarget = "Plus Members Target",
    modEvader = "Mod Evader",
    serverHopNow = "Server Hop Now",
    vcServerHop = "VC Server Hop (All Servers)",
}

localized = function(key, ...)
    local rawKey = tostring(key or "")
    local value = labelTextMap[rawKey]
    if value == nil then
        value = humanizeLabel(rawKey)
        if rawKey:sub(1, 3) == "tab" then
            value = humanizeLabel(rawKey:sub(4))
        end
    end
    if select("#", ...) > 0 then
        return value:format(...)
    end
    return value
end

local boothScanAnchor = Vector3.new(165.161, 0, 311.636)
local claimedBoothSlot
local claimAttemptRunning = false
local findOwnedBoothSlot
local preferredRemoteModule

local function findRemoteModules()
    local modules = {}
    for _, child in ipairs(ReplicatedStorage:GetChildren()) do
        if child:IsA("ModuleScript") and child.Name:find("Remote") then
            local ok, module = pcall(require, child)
            if ok and module and type(module.Event) == "function" then
                table.insert(modules, module)
            end
        end
    end
    return modules
end

local RemoteModules = findRemoteModules()

local function findPreferredRemoteModule()
    for _, module in ipairs(RemoteModules) do
        local ok, remote = pcall(function()
            return module.Event("SetCustomization")
        end)
        if ok and remote and type(remote.FireServer) == "function" then
            return module
        end
    end
    return RemoteModules[1]
end

local function fireSetCustomizationPayload(payload)
    if type(payload) ~= "table" then
        return false
    end

    local tried = false

    if preferredRemoteModule and preferredRemoteModule.Event then
        local ok = pcall(function()
            local event = preferredRemoteModule.Event("SetCustomization")
            if event and type(event.FireServer) == "function" then
                event:FireServer(payload, "booth")
                tried = true
            end
        end)
        if ok and tried then
            return true
        end
    end

    for _, remoteModule in ipairs(RemoteModules or {}) do
        local ok = pcall(function()
            if remoteModule and remoteModule.Event then
                local event = remoteModule.Event("SetCustomization")
                if event and type(event.FireServer) == "function" then
                    event:FireServer(payload, "booth")
                    preferredRemoteModule = remoteModule
                    tried = true
                end
            end
        end)
        if ok and tried then
            return true
        end
    end

    return false
end

preferredRemoteModule = findPreferredRemoteModule()

local function getBoothLocation()
    local worldMapUi = Workspace:FindFirstChild("MapUI")
    if worldMapUi then
        return worldMapUi
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil
    end

    local container = playerGui:FindFirstChild("MapUIContainer")
    if container and container:FindFirstChild("MapUI") then
        return container.MapUI
    end

    return playerGui:FindFirstChild("MapUI")
end

local function boothOwnedByLocalPlayer(ownerText)
    local owner = tostring(ownerText or "")
    return owner:find(LocalPlayer.DisplayName, 1, true) ~= nil or owner:find(LocalPlayer.Name, 1, true) ~= nil
end

local requestServerHop
local updateBoothTextNow

local modUsernames = {
    ["haz3mn"] = true,
    ["zenuux"] = true,
    ["kreekcraft"] = true,
    ["itsmuneeeb"] = true,
    ["p_rrgatory"] = true,
    ["clutchquickly"] = true,
    ["0bid0"] = true,
    ["blastii"] = true,
    ["olix"] = true,
    ["subsical"] = true,
}

local hopCooldownSeconds = 0.35
local lastHopTick = 0
local serverHopIsActive = false
local hopTimerResetTick = tick()
local donatedSinceHopTimerReset = 0
local lastDonationTick = 0
local donationHopBlockSeconds = 1.2
local farmSessionStats = SharedEnv.PLS_DONO_FARM_SESSION
if type(farmSessionStats) ~= "table" or tonumber(farmSessionStats.playerUserId) ~= tonumber(LocalPlayer.UserId) then
    farmSessionStats = {
        playerUserId = tonumber(LocalPlayer.UserId) or 0,
        startedAt = os.time(),
        successfulHops = 0,
        botEvaded = 0,
        modServers = 0,
        lastSummaryHopCount = 0,
    }
    SharedEnv.PLS_DONO_FARM_SESSION = farmSessionStats
end

farmSessionStats.playerUserId = tonumber(LocalPlayer.UserId) or 0
farmSessionStats.startedAt = tonumber(farmSessionStats.startedAt) or os.time()
farmSessionStats.successfulHops = math.max(0, tonumber(farmSessionStats.successfulHops) or 0)
farmSessionStats.botEvaded = math.max(0, tonumber(farmSessionStats.botEvaded) or 0)
farmSessionStats.modServers = math.max(0, tonumber(farmSessionStats.modServers) or 0)
farmSessionStats.lastSummaryHopCount = math.max(0, tonumber(farmSessionStats.lastSummaryHopCount) or 0)

local pendingFarmHopNotification

local function shouldTrackFarmHop(reason)
    local normalizedReason = tostring(reason or "")
    return normalizedReason ~= "" and normalizedReason ~= "manual-button" and normalizedReason ~= "vc-server-hop-toggle"
end

local function markPendingFarmHop(reason, placeId, targetServerId)
    SharedEnv.PLS_DONO_PENDING_HOP = {
        reason = tostring(reason or ""),
        placeId = tonumber(placeId) or 0,
        targetServerId = tostring(targetServerId or ""),
        fromJobId = tostring(game.JobId or ""),
        queuedAt = os.time(),
    }
end

local function finalizeSuccessfulPendingFarmHop()
    local pending = SharedEnv.PLS_DONO_PENDING_HOP
    if type(pending) ~= "table" then
        return nil
    end

    SharedEnv.PLS_DONO_PENDING_HOP = nil

    local pendingReason = tostring(pending.reason or "")
    local targetServerId = tostring(pending.targetServerId or "")
    local fromJobId = tostring(pending.fromJobId or "")
    local queuedAt = tonumber(pending.queuedAt) or 0
    local isFresh = queuedAt <= 0 or (os.time() - queuedAt) <= 900
    local landedOnExpectedServer = targetServerId == "" or targetServerId == tostring(game.JobId or "")
    local changedServers = fromJobId ~= "" and fromJobId ~= tostring(game.JobId or "")

    if not isFresh or not landedOnExpectedServer or not changedServers then
        return nil
    end

    local summaryHopCount
    if shouldTrackFarmHop(pendingReason) then
        farmSessionStats.successfulHops += 1
        if pendingReason == "mod-detection" then
            farmSessionStats.modServers += 1
        end

        if farmSessionStats.successfulHops > 0
            and farmSessionStats.successfulHops % 100 == 0
            and farmSessionStats.lastSummaryHopCount < farmSessionStats.successfulHops then
            farmSessionStats.lastSummaryHopCount = farmSessionStats.successfulHops
            summaryHopCount = farmSessionStats.successfulHops
        end
    end

    return {
        count = farmSessionStats.successfulHops,
        reason = pendingReason,
        summaryCount = summaryHopCount,
    }
end

pendingFarmHopNotification = finalizeSuccessfulPendingFarmHop()

local function parseIdFromTemplate(tmpl)
    if not tmpl then
        return nil
    end
    local id = tostring(tmpl):match("(%d+)")
    return id and tonumber(id) or nil
end

sendChatMessage = function(message)
    local text = tostring(message or "")
    if text == "" then
        return
    end

    local ok, sent = pcall(function()
        if TextChatService then
            local channels = TextChatService:FindFirstChild("TextChannels")
            local general = channels and channels:FindFirstChild("RBXGeneral")
            if general and general.SendAsync then
                general:SendAsync(text)
                return true
            end
        end

        if Players and type(Players.Chat) == "function" then
            Players:Chat(text)
            return true
        end

        return false
    end)

    if ok and sent == true then
        return
    end

    pcall(function()
        if Players and type(Players.Chat) == "function" then
            Players:Chat(text)
        end
    end)
end

local function performHttpRequest(options)
    if syn and syn.request then
        return syn.request(options)
    end
    if request then
        return request(options)
    end
    if http_request then
        return http_request(options)
    end
    return nil
end

local function postWebhookJson(url, payload)
    local webhookUrl = tostring(url or ""):match("%S+")
    if not webhookUrl or webhookUrl == "" then
        return false
    end

    local encodedBody = HttpService:JSONEncode(payload or {})
    local requestOptions = {
        Url = webhookUrl,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "PLS-DONATE/1.0",
        },
        Body = encodedBody,
    }

    local ok, result = pcall(function()
        local httpResult = performHttpRequest(requestOptions)
        if httpResult and type(httpResult.StatusCode) == "number" then
            return httpResult
        end

        if type(game.HttpPost) == "function" then
            game:HttpPost(webhookUrl, encodedBody)
            return { StatusCode = 204 }
        end

        return nil
    end)

    if not ok then
        return false
    end

    if not result then
        return false
    end

    local statusCode = tonumber(result.StatusCode) or tonumber(result.statusCode) or 0
    if statusCode >= 200 and statusCode < 300 then
        return true
    end

    if type(result.Body) == "string" and result.Body ~= "" then
        return true
    end

    return statusCode == 0
end

local function httpGetBody(url)
    local body = nil
    local okRequest = pcall(function()
        local response = performHttpRequest({
            Url = url,
            Method = "GET",
            Headers = { ["Content-Type"] = "application/json" },
        })
        if response and type(response.Body) == "string" and response.Body ~= "" then
            body = response.Body
        end
    end)

    if okRequest and body then
        return body
    end

    local okHttpGet, result = pcall(function()
        return game:HttpGet(url)
    end)
    if okHttpGet and type(result) == "string" and result ~= "" then
        return result
    end

    return nil
end

local function formatFarmDuration(totalSeconds)
    local seconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
    local days = math.floor(seconds / 86400)
    seconds -= days * 86400
    local hours = math.floor(seconds / 3600)
    seconds -= hours * 3600
    local minutes = math.floor(seconds / 60)
    seconds -= minutes * 60

    local parts = {}
    if days > 0 then
        table.insert(parts, ("%dd"):format(days))
    end
    if hours > 0 or #parts > 0 then
        table.insert(parts, ("%dh"):format(hours))
    end
    if minutes > 0 or #parts > 0 then
        table.insert(parts, ("%dm"):format(minutes))
    end
    table.insert(parts, ("%ds"):format(seconds))
    return table.concat(parts, " ")
end


getNearestPlayerInfo = function()
    local myCharacter = LocalPlayer.Character
    local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
    local myRoot = myHumanoid and myHumanoid.RootPart
    if not myRoot then
        return {
            name = "Unknown",
            displayName = "Unknown",
            userId = 0,
        }
    end

    local nearestPlayer = nil
    local nearestDistance = math.huge
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            local root = hum and hum.RootPart
            if root then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < nearestDistance then
                    nearestDistance = dist
                    nearestPlayer = pl
                end
            end
        end
    end

    if nearestPlayer then
        return {
            name = tostring(nearestPlayer.Name or "Unknown"),
            displayName = tostring(nearestPlayer.DisplayName or nearestPlayer.Name or "Unknown"),
            userId = tonumber(nearestPlayer.UserId) or 0,
        }
    end

    -- Fallback: if no one is near, just pick the first other player in the server
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            return {
                name = tostring(pl.Name or "Unknown"),
                displayName = tostring(pl.DisplayName or pl.Name or "Unknown"),
                userId = tonumber(pl.UserId) or 0,
            }
        end
    end

    return {
        name = "Unknown",
        displayName = "Unknown",
        userId = 0,
    }
end

local function getCurrentRaisedAmount()
    local raised = 0
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if not leaderstats then
        return raised
    end

    local valueObj = leaderstats:FindFirstChild("Raised") or leaderstats:FindFirstChild("Donated")
    if valueObj and type(valueObj.Value) == "number" then
        raised = valueObj.Value
    end
    return raised
end

local function findDetectedModPlayer()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local username = tostring(pl.Name or ""):lower()
            if modUsernames[username] then
                return pl
            end
        end
    end

    return nil
end

local function getRobloxAvatarThumbnailUrl(userId, size, isCircular)
    userId = tonumber(userId) or 0
    if userId <= 0 then
        return nil
    end

    local cacheKey = table.concat({tostring(userId), tostring(size or "420x420"), tostring(isCircular == true)}, ":")
    if avatarThumbnailCache[cacheKey] then
        return avatarThumbnailCache[cacheKey]
    end

    local thumbSize = tostring(size or "420x420")
    local circleFlag = isCircular == true and "true" or "false"
    local endpoint = ("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=%s&format=Png&isCircular=%s"):format(
        userId,
        HttpService:UrlEncode(thumbSize),
        circleFlag
    )

    local ok, imageUrl = pcall(function()
        local body = httpGetBody(endpoint)
        if type(body) ~= "string" or body == "" then
            return nil
        end

        local decoded = HttpService:JSONDecode(body)
        local items = decoded and decoded.data
        local firstItem = type(items) == "table" and items[1] or nil
        local resolved = firstItem and firstItem.imageUrl
        if type(resolved) == "string" and resolved ~= "" then
            return resolved
        end
        return nil
    end)

    if ok and imageUrl then
        avatarThumbnailCache[cacheKey] = imageUrl
        return imageUrl
    end

    return nil
end

local function sendDonationWebhook(amount, donorInfo)
    if not settings.webhookToggle then
        return false
    end

    local url = tostring(settings.webhookBox or ""):match("%S+")
    if not url or url == "" then
        return false
    end

    local received = math.max(0, tonumber(amount) or 0)
    local taxed = math.floor((tonumber(amount) or 0) * 0.6)
    local donorName = trimText(donorInfo and donorInfo.name) ~= "" and tostring(donorInfo.name) or "Unknown"
    local donorDisplay = trimText(donorInfo and donorInfo.displayName) ~= "" and tostring(donorInfo.displayName) or donorName
    local donorLabel
    if donorName ~= "Unknown" and donorDisplay ~= donorName then
        donorLabel = donorDisplay .. " (@" .. donorName .. ")"
    elseif donorName ~= "Unknown" then
        donorLabel = "@" .. donorName
    else
        donorLabel = donorDisplay
    end

    return postWebhookJson(url, {
        username = "PLS DONATE",
        embeds = {{
            color = 0x2ECC71,
            title = localized(
                "webhookTitle",
                tostring(LocalPlayer.Name or "Unknown"),
                received,
                donorLabel
            ),
            description = string.format(
                "**%d R$** by **%s**\n- After Tax: %d R$\n- Total Raised: %d R$",
                received,
                donorLabel,
                taxed,
                getCurrentRaisedAmount()
            ),
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }},
    })
end

local function sendServerHopWebhook(hopInfo)
    if not settings.notifyPerHopToggle or type(hopInfo) ~= "table" then
        return
    end

    local url = tostring(settings.webhookBox or ""):match("%S+")
    if not url or url == "" then
        return
    end

    local hopCount = tonumber(hopInfo.count) or 0
    local reason = tostring(hopInfo.reason or "")
    local reasonText = reason ~= "" and (" | Reason: **%s**"):format(reason) or ""

    postWebhookJson(url, {
        username = "PLS DONATE",
        embeds = {{
            color = 0x3498DB,
            title = localized("serverHopTitle", tostring(LocalPlayer.Name or "Unknown")),
            description = string.format(
                "Server hops this session: **%d**%s",
                hopCount,
                reasonText
            ),
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }},
    })
end

local function buildPendingHopWebhookInfo(reason)
    local hopCount = math.max(0, tonumber(farmSessionStats.successfulHops) or 0)
    if reason and tostring(reason) ~= "" and tostring(reason) ~= "manual-button" and tostring(reason) ~= "vc-server-hop-toggle" then
        hopCount = hopCount + 1
    end
    return {
        count = hopCount,
        reason = tostring(reason or ""),
    }
end

local function trySendCompletedHopWebhook()
    if not settings.notifyPerHopToggle then
        return false
    end

    local hopReport = finalizeSuccessfulPendingFarmHop()
    if type(hopReport) ~= "table" then
        return false
    end

    local payload = {
        count = tonumber(hopReport.count) or 0,
        reason = tostring(hopReport.reason or ""),
    }

    sendServerHopWebhook(payload)
    return true
end

local function resetHopTimer()
    hopTimerResetTick = tick()
    donatedSinceHopTimerReset = 0
end

local function markDonationForHopTimer(delta)
    hopTimerResetTick = tick()
    donatedSinceHopTimerReset += math.max(0, tonumber(delta) or 0)
end

local function pickRandomMessage(list, fallback)
    if type(list) == "table" and #list > 0 then
        local index = math.random(1, #list)
        return tostring(list[index] or fallback or "")
    end
    return tostring(fallback or "")
end

local function getRaisedStatObject()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats") or LocalPlayer:WaitForChild("leaderstats", 12)
    if not leaderstats then
        return nil
    end
    return leaderstats:FindFirstChild("Raised") or leaderstats:FindFirstChild("Donated") or leaderstats:WaitForChild("Raised", 8)
end

local function formatBoothNumber(n)
    local value = tonumber(n) or 0
    if value == 420 or value == 425 then
        value += 10
    end
    if value >= 10000 then
        return string.format("%.1fk", value / 1000)
    elseif value >= 1000 then
        return string.format("%.2fk", value / 1000)
    end
    return tostring(math.floor(value))
end

local function escapeRichTextText(value)
    local text = tostring(value or "")
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    text = text:gsub('"', "&quot;")
    text = text:gsub("'", "&apos;")
    return text
end

local function getGoalProgressSnapshot()
    local current = tonumber(getCurrentRaisedAmount()) or 0
    local goal = math.max(250, current + 250)
    local safeGoal = math.max(goal, 1)
    local ratio = math.clamp(current / safeGoal, 0, 1)
    return current, goal, ratio
end

local function getNamedTextColorMap()
    return {
        green = Color3.fromRGB(50, 205, 50),
        blue = Color3.fromRGB(30, 144, 255),
        yellow = Color3.fromRGB(255, 215, 0),
        black = Color3.fromRGB(0, 0, 0),
        white = Color3.fromRGB(255, 255, 255),
        red = Color3.fromRGB(255, 69, 69),
        orange = Color3.fromRGB(255, 140, 0),
        pink = Color3.fromRGB(255, 105, 180),
        purple = Color3.fromRGB(170, 102, 255),
        gray = Color3.fromRGB(145, 145, 150),
        grey = Color3.fromRGB(145, 145, 150),
    }
end

local function color3ToRgbText(color)
    local r = math.floor((color.R * 255) + 0.5)
    local g = math.floor((color.G * 255) + 0.5)
    local b = math.floor((color.B * 255) + 0.5)
    return string.format("rgb(%d,%d,%d)", r, g, b)
end

local function getGoalBarColorName()
    local value = tostring(settings.goalBarColor or "blue"):lower()
    local allowed = {
        green = true,
        blue = true,
        red = true,
        orange = true,
        purple = true,
    }
    if allowed[value] then
        return value
    end
    return "blue"
end

local function buildGoalProgressBar()
    local current, goal, ratio = getGoalProgressSnapshot()
    local totalSegments = 21
    local filledSegments = math.clamp(math.floor((ratio * totalSegments) + 0.5), 0, totalSegments)

    if current > 0 and goal > 0 and filledSegments == 0 then
        filledSegments = 1
    end

    local emptySegments = math.max(0, totalSegments - filledSegments)
    local namedColors = getNamedTextColorMap()
    local filledColor = namedColors[getGoalBarColorName()] or namedColors.blue
    return string.format(
        "<font color=\"%s\" size=\"17\">%s</font><font color=\"rgb(70,70,70)\" size=\"17\">%s</font>",
        color3ToRgbText(filledColor),
        string.rep("|", filledSegments),
        string.rep("|", emptySegments)
    )
end

local function buildBoothText()
    local text = tostring(settings.customBoothText or "")
    local current, goal = getGoalProgressSnapshot()

    text = text:gsub("%$C", formatBoothNumber(current))
    text = text:gsub("%$G", formatBoothNumber(goal))
    text = text:gsub("%$BAR", buildGoalProgressBar())
    text = text:gsub("%$JPR", "1")
    return text
end

local function buildGoalBarTemplate()
    local current, goal = getGoalProgressSnapshot()
    local raisedText = string.format("Raised: %s / %s", formatBoothNumber(current), formatBoothNumber(goal))
    local headerText = escapeRichTextText(raisedText)

    return table.concat({
        "<font size=\"22\"><b>",
        headerText,
        "</b></font><br/>",
        "<stroke thickness=\"3\" color=\"rgb(0,0,0)\">",
        "$BAR",
        "</stroke>",
    })
end

local function hexToColor3(hex)
    local namedColors = getNamedTextColorMap()
    local rawValue = tostring(hex or "#32CD32"):gsub("^%s+", ""):gsub("%s+$", "")
    local named = namedColors[rawValue:lower()]
    if named then
        return named
    end

    local value = rawValue:gsub("#", "")
    if #value ~= 6 then
        return Color3.fromRGB(50, 205, 50)
    end

    local r = tonumber(value:sub(1, 2), 16)
    local g = tonumber(value:sub(3, 4), 16)
    local b = tonumber(value:sub(5, 6), 16)
    if not r or not g or not b then
        return Color3.fromRGB(50, 205, 50)
    end
    return Color3.fromRGB(r, g, b)
end

updateBoothTextNow = function(forceApply)
    if not forceApply and suppressBoothTextAutoApply then
        return false, "suppressed"
    end

    local text = buildBoothText()
    if text == "" then
        return false, "empty-text"
    end

    local boothLocation = getBoothLocation()
    local boothUiFolder = boothLocation and boothLocation:FindFirstChild("BoothUI")
    if boothUiFolder and not claimedBoothSlot then
        claimedBoothSlot = findOwnedBoothSlot(boothUiFolder)
    end

    local payload = {
        text = text,
        textFont = Enum.Font.BuilderSansExtraBold,
        richText = true,
        strokeColor = Color3.new(0, 0, 0),
        strokeOpacity = 0,
        textColor = hexToColor3("#32CD32"),
        buttonStrokeColor = Color3.new(0, 0, 0),
        buttonTextColor = Color3.new(1, 1, 1),
        buttonColor = Color3.new(98 / 255, 1, 0),
        buttonHoverColor = Color3.new(98 / 255, 1, 0),
        buttonLayout = "",
    }

    local applied = fireSetCustomizationPayload(payload)

    if boothUiFolder and claimedBoothSlot then
        local boothFrame = boothUiFolder:FindFirstChild("BoothUI" .. tostring(claimedBoothSlot))
        if boothFrame then
            for _, desc in ipairs(boothFrame:GetDescendants()) do
                if desc:IsA("TextLabel") then
                    local nameLower = tostring(desc.Name or ""):lower()
                    if nameLower:find("sign", 1, true) or nameLower:find("text", 1, true) then
                        desc.Text = text
                    end
                end
            end
        end
    end

    return applied, applied and "updated" or "local-preview-only"
end

local function choosePlaceId()
    if game.PlaceId == EXTRA_PLS_DONATE_PLACE_ID then
        return EXTRA_PLS_DONATE_PLACE_ID
    end

    if settings.vcServerHopToggle then
        return VC_PLS_DONATE_PLACE_ID
    end

    return DEFAULT_PLS_DONATE_PLACE_ID
end

local function isFullServerTeleportFailure(message)
    local text = tostring(message or "")
    local lower = text:lower()
    return lower:find("server is full", 1, true)
        or lower:find("error code: 772", 1, true)
        or lower:find("772", 1, true)
        or lower:find("full server", 1, true)
end

local function shouldRetryTeleportFailure(result, errorMessage)
    if result == Enum.TeleportResult.Failure then
        return true
    end
    return isFullServerTeleportFailure(errorMessage)
end

local teleportFailureConnection = nil
if not teleportFailureConnection then
    teleportFailureConnection = TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
        if player ~= LocalPlayer then
            return
        end

        if shouldRetryTeleportFailure(result, errorMessage) then
            serverHopIsActive = false
            task.delay(0.25, function()
                if serverHopNow then
                    serverHopNow("full-server-retry")
                end
            end)
        end
    end)
end

local function getServerPremiumPlayerCount(server)
    if type(server) ~= "table" then
        return 0
    end

    local candidates = {
        server.premiumPlayers,
        server.premium,
        server.plusPlayers,
        server.plusMembers,
        server.premiumMembers,
        server.memberCount,
    }

    for _, value in ipairs(candidates) do
        local count = tonumber(value)
        if count then
            return math.max(0, count)
        end
    end

    return 0
end

serverHopNow = function(reason, minPlayersOverride, maxPlayersOverride, retryAttempt)
    if serverHopIsActive then
        return true
    end

    serverHopIsActive = true
    task.spawn(function()
        local placeId = choosePlaceId()
        local minPlayers = tonumber(minPlayersOverride) or tonumber(settings.minPlayerCount) or 13
        local maxPlayers = tonumber(maxPlayersOverride) or tonumber(settings.maxPlayerCount) or 24
        local preferredPlusMembers = settings.plusHopToggle and math.max(0, tonumber(settings.plusMemberTarget) or 3) or 0
        local preferPlus = settings.plusHopToggle and preferredPlusMembers > 0
        local retryTimer = (reason == "manual-button" or reason == "auto-timer" or reason == "full-server-retry") and 0.75 or 1.25
        local attempt = tonumber(retryAttempt) or 0
        local rangeDeadline = tick() + 10

        while true do
            attempt += 1
            local req = performHttpRequest({
                Url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"):format(placeId),
                Method = "GET"
            })

            local body = nil
            if req and type(req.Body) == "string" and req.Body ~= "" then
                local ok, decoded = pcall(function()
                    return HttpService:JSONDecode(req.Body)
                end)
                if ok and decoded and type(decoded.data) == "table" then
                    body = decoded
                end
            end

            local servers = {}
            local fallbackServers = {}
            if body and body.data then
                for _, server in pairs(body.data) do
                    local playing = tonumber(server.playing or 0) or 0
                    local maxServerPlayers = tonumber(server.maxPlayers or 0) or 0
                    local premiumPlayers = getServerPremiumPlayerCount(server)
                    local id = tostring(server.id or "")
                    local localIsPremium = LocalPlayer and LocalPlayer.MembershipType == Enum.MembershipType.Premium
                    local effectivePremiumCount = premiumPlayers
                    if localIsPremium then
                        effectivePremiumCount = math.max(0, premiumPlayers - 1)
                    end
                    local isAvailable = id ~= tostring(game.JobId or "") and maxServerPlayers > 0 and playing < maxServerPlayers
                    if isAvailable then
                        table.insert(fallbackServers, server)
                    end

                    local matchesPlayerRange = isAvailable and playing >= minPlayers and playing <= maxPlayers
                    if matchesPlayerRange then
                        if not preferPlus or effectivePremiumCount >= preferredPlusMembers then
                            table.insert(servers, server)
                        end
                    end
                end
            end

            if preferPlus and #servers == 0 then
                preferPlus = false
                servers = {}
            end

            if #servers > 0 then
                local selectedServer = servers[math.random(1, #servers)]
                local selectedServerId = tostring(selectedServer.id or "")
                local serverFullFailure = false
                local failureConnection = TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
                    if player ~= LocalPlayer then
                        return
                    end
                    if tostring(selectedServerId) == tostring(selectedServer.id or "") and shouldRetryTeleportFailure(result, errorMessage) then
                        serverFullFailure = true
                    end
                end)

                queueScriptOnTeleport()
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(placeId, selectedServer.id, LocalPlayer)
                end)

                task.wait(1.2)
                if failureConnection then
                    failureConnection:Disconnect()
                end

                if serverFullFailure then
                    serverHopIsActive = false
                    task.wait(retryTimer)
                    continue
                end

                markPendingFarmHop(reason, placeId, selectedServer.id)
                if reason == "manual-button" and settings.notifyPerHopToggle then
                    sendServerHopWebhook(buildPendingHopWebhookInfo(reason))
                end
                serverHopIsActive = false
                return
            end

            local fallbackServer = nil
            if #fallbackServers > 0 and tick() >= rangeDeadline then
                table.sort(fallbackServers, function(a, b)
                    local ap = tonumber(a.playing or 0) or 0
                    local bp = tonumber(b.playing or 0) or 0
                    return ap > bp
                end)
                fallbackServer = fallbackServers[1]
            end

            if fallbackServer then
                local selectedServerId = tostring(fallbackServer.id or "")
                local serverFullFailure = false
                local failureConnection = TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
                    if player ~= LocalPlayer then
                        return
                    end
                    if tostring(selectedServerId) == tostring(fallbackServer.id or "") and shouldRetryTeleportFailure(result, errorMessage) then
                        serverFullFailure = true
                    end
                end)

                queueScriptOnTeleport()
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(placeId, fallbackServer.id, LocalPlayer)
                end)

                task.wait(1.2)
                if failureConnection then
                    failureConnection:Disconnect()
                end

                if serverFullFailure then
                    serverHopIsActive = false
                    task.wait(retryTimer)
                    continue
                end

                markPendingFarmHop(reason, placeId, fallbackServer.id)
                if reason == "manual-button" and settings.notifyPerHopToggle then
                    sendServerHopWebhook(buildPendingHopWebhookInfo(reason))
                end
                serverHopIsActive = false
                return
            end

            task.wait(retryTimer)
        end
    end)

    return true
end

requestServerHop = function(reason)
    local now = tick()
    local activeCooldown = (reason == "manual-button" or reason == "auto-timer" or reason == "full-server-retry") and 0.2 or hopCooldownSeconds
    if now - lastHopTick < activeCooldown then
        return false
    end
    if now - lastDonationTick < donationHopBlockSeconds then
        return false
    end
    lastHopTick = now
    return serverHopNow(reason)
end

findOwnedBoothSlot = function(boothUiFolder)
    if not boothUiFolder then
        return nil
    end

    for _, uiFrame in ipairs(boothUiFolder:GetChildren()) do
        local details = uiFrame:FindFirstChild("Details")
        local ownerLabel = details and details:FindFirstChild("Owner")
        if ownerLabel and boothOwnedByLocalPlayer(ownerLabel.Text) then
            local boothNum = tonumber(uiFrame.Name:match("%d+"))
            if boothNum then
                return boothNum
            end
        end
    end

    return nil
end

local function collectUnclaimedBooths(boothUiFolder, interactionsFolder)
    local unclaimed = {}
    local anchor2D = Vector3.new(boothScanAnchor.X, 0, boothScanAnchor.Z)

    for _, uiFrame in ipairs(boothUiFolder:GetChildren()) do
        local details = uiFrame:FindFirstChild("Details")
        local ownerLabel = details and details:FindFirstChild("Owner")
        if ownerLabel and tostring(ownerLabel.Text):lower() == "unclaimed" then
            local boothNum = tonumber(uiFrame.Name:match("%d+"))
            if boothNum then
                for _, interact in ipairs(interactionsFolder:GetChildren()) do
                    if interact:GetAttribute("BoothSlot") == boothNum then
                        local pos2D = Vector3.new(interact.Position.X, 0, interact.Position.Z)
                        if (pos2D - anchor2D).Magnitude < 92 then
                            table.insert(unclaimed, boothNum)
                            break
                        end
                    end
                end
            end
        end
    end

    return unclaimed
end

local function findBoothPartBySlot(slot)
    local interactions = Workspace:FindFirstChild("BoothInteractions")
    if not interactions then
        return nil
    end

    for _, part in ipairs(interactions:GetChildren()) do
        if part:GetAttribute("BoothSlot") == slot then
            return part
        end
    end

    return nil
end

local function getBoothTargetCFrameForStand(slot, standOverride)
    local boothPart = findBoothPartBySlot(slot)
    if not boothPart then
        return nil, "missing-booth-part"
    end

    local stand = tostring(standOverride or settings.standingPosition or "Front")
    local sideOffset, forwardOffset
    if stand == "Left" then
        sideOffset, forwardOffset = -6, 0
    elseif stand == "Right" then
        sideOffset, forwardOffset = 6, 0
    elseif stand == "Behind" then
        sideOffset, forwardOffset = 0, 6
    else
        sideOffset, forwardOffset = 0, -4
    end
    local targetPos = boothPart.Position
        + boothPart.CFrame.RightVector * sideOffset
        + boothPart.CFrame.LookVector * forwardOffset
        + Vector3.new(0, 2, 0)
    local awayDir = Vector3.new(targetPos.X - boothPart.Position.X, 0, targetPos.Z - boothPart.Position.Z)
    if awayDir.Magnitude < 0.001 then
        awayDir = Vector3.new(-boothPart.CFrame.LookVector.X, 0, -boothPart.CFrame.LookVector.Z)
    end
    awayDir = awayDir.Unit
    return CFrame.new(targetPos, targetPos + awayDir)
end

local function getClaimedBoothTargetCFrame(slot)
    return getBoothTargetCFrameForStand(slot)
end

local function moveToClaimedBooth(slot)
    local targetCF, err = getClaimedBoothTargetCFrame(slot)
    if not targetCF then
        return false, err or "missing-booth-part"
    end

    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then
        return false, "missing-character"
    end

    humanoid.Sit = false
    humanoid.AutoRotate = true

    local mode = tostring(settings.boothMovementMode or "Teleport")
    if mode == "Walk" then
        local goalPos = targetCF.Position
        local currentPos = hrp.Position
        local distance = (goalPos - currentPos).Magnitude
        if distance <= 2 then
            local lookAt = Vector3.new(goalPos.X, currentPos.Y, goalPos.Z)
            hrp.CFrame = CFrame.new(currentPos, lookAt)
            return true, "walk"
        end

        local lookTarget = Vector3.new(goalPos.X, currentPos.Y, goalPos.Z)
        local direction = (goalPos - currentPos)
        local desiredLook = direction.Magnitude > 0.01 and (currentPos + direction.Unit) or lookTarget
        hrp.CFrame = CFrame.new(currentPos, desiredLook)
        humanoid:MoveTo(goalPos)

        task.spawn(function()
            local deadline = tick() + 2.5
            while tick() < deadline do
                if not hrp or not hrp.Parent or not humanoid or humanoid.Health <= 0 then
                    return
                end
                if humanoid.Sit then
                    humanoid.Sit = false
                end
                local dist = (hrp.Position - goalPos).Magnitude
                if dist <= 1.5 then
                    humanoid:MoveTo(goalPos)
                    return
                end
                humanoid:MoveTo(goalPos)
                task.wait(0.2)
            end
        end)
        return true, "walk"
    end

    hrp.CFrame = targetCF
    task.delay(0.15, function()
        if hrp and hrp.Parent then
            hrp.CFrame = targetCF
        end
    end)
    return true, "teleport"
end

local function claimBoothNow()
    if claimAttemptRunning then
        return false, "claim-in-progress"
    end

    claimAttemptRunning = true

    local success, result, extra = pcall(function()
        if not RemoteModules or #RemoteModules == 0 then
            return false, "missing-remotes"
        end

        local boothLocation = getBoothLocation()
        if not boothLocation then
            return false, "missing-mapui"
        end

        local boothUiFolder = boothLocation:FindFirstChild("BoothUI") or boothLocation:WaitForChild("BoothUI", 5)
        local interactionsFolder = Workspace:FindFirstChild("BoothInteractions") or Workspace:WaitForChild("BoothInteractions", 5)
        if not boothUiFolder or not interactionsFolder then
            return false, "missing-booth-data"
        end

        local alreadyOwned = findOwnedBoothSlot(boothUiFolder)
        if alreadyOwned then
            claimedBoothSlot = alreadyOwned
            return true, alreadyOwned
        end

        local candidates = collectUnclaimedBooths(boothUiFolder, interactionsFolder)
        if #candidates == 0 then
            local ownedAfterScan = findOwnedBoothSlot(boothUiFolder)
            if ownedAfterScan then
                claimedBoothSlot = ownedAfterScan
                return true, ownedAfterScan
            end
            return false, "no-unclaimed-booths"
        end

        for _, slot in ipairs(candidates) do
            for _, remoteModule in ipairs(RemoteModules) do
                pcall(function()
                    remoteModule.Event("ClaimBooth"):InvokeServer(slot)
                end)
            end

            local claimedFrame = boothUiFolder:FindFirstChild("BoothUI" .. slot)
            if claimedFrame and claimedFrame:FindFirstChild("Details") and claimedFrame.Details:FindFirstChild("Owner") then
                if boothOwnedByLocalPlayer(claimedFrame.Details.Owner.Text) then
                    claimedBoothSlot = slot
                    return true, slot
                end
            end

            task.wait(1)

            claimedFrame = boothUiFolder:FindFirstChild("BoothUI" .. slot)
            if claimedFrame and claimedFrame:FindFirstChild("Details") and claimedFrame.Details:FindFirstChild("Owner") then
                if boothOwnedByLocalPlayer(claimedFrame.Details.Owner.Text) then
                    claimedBoothSlot = slot
                    return true, slot
                end
            end
        end

        return false, "claim-failed"
    end)

    claimAttemptRunning = false

    if not success then
        return false, tostring(result)
    end

    return result, extra
end

do
    queueScriptOnTeleport()
end

do
    for _, existing in ipairs(GuiParent:GetChildren()) do
        if existing:IsA("ScreenGui") and existing.Name == "PlsDonoCustomGui" then
            existing:Destroy()
        end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "PlsDonoCustomGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50
gui.Parent = GuiParent

local THEME = {
    topBar = Color3.fromRGB(46, 173, 83),
    topBarText = Color3.fromRGB(255, 247, 235),
    panel = Color3.fromRGB(28, 29, 33),
    tabIdle = Color3.fromRGB(52, 55, 60),
    tabActive = Color3.fromRGB(70, 74, 81),
    section = Color3.fromRGB(31, 33, 37),
    control = Color3.fromRGB(41, 44, 50),
    controlText = Color3.fromRGB(236, 236, 239),
    subtleText = Color3.fromRGB(180, 181, 187),
    accent = Color3.fromRGB(84, 191, 108),
    stroke = Color3.fromRGB(76, 80, 86),
}

local UI_FONT = Enum.Font.Gotham
local UI_FONT_BOLD = Enum.Font.GothamBlack

local SHELL_CORNER_RADIUS = 10
local CONTROL_CORNER_RADIUS = 6
local GLOW_COLOR = Color3.fromRGB(210, 210, 210)
local SUBTLE_GLOW_COLOR = Color3.fromRGB(150, 150, 150)
local GLOW_TRANSPARENCY = 0.84
local SUBTLE_GLOW_TRANSPARENCY = 0.9

local function createCorner(target, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or CONTROL_CORNER_RADIUS)
    corner.Parent = target
    return corner
end

local function applyTextGlow(target, color, transparency)
    target.TextStrokeColor3 = color or GLOW_COLOR
    target.TextStrokeTransparency = transparency or GLOW_TRANSPARENCY
end

local function styleTextButton(btn, backgroundColor, textColor, textSize, font)
    btn.BackgroundColor3 = backgroundColor or THEME.control
    btn.TextColor3 = textColor or THEME.controlText
    btn.Font = font or UI_FONT_BOLD
    btn.TextSize = textSize or 11
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.BackgroundTransparency = 0
end

local function styleTextBox(box, alignment, multiline)
    box.BackgroundColor3 = THEME.control
    box.TextColor3 = THEME.controlText
    box.PlaceholderColor3 = THEME.subtleText
    box.Font = UI_FONT
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.TextXAlignment = alignment or Enum.TextXAlignment.Center
    box.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    box.MultiLine = multiline == true
    box.TextWrapped = multiline == true
end

local function createStyledButton(parent, text, size, position, backgroundColor, textColor, textSize, font)
    local btn = Instance.new("TextButton")
    btn.Size = size or UDim2.new(0, 104, 0, 23)
    btn.Position = position or UDim2.new(0, 0, 0, 0)
    btn.Text = tostring(text or "")
    styleTextButton(btn, backgroundColor, textColor, textSize, font)
    btn.Parent = parent

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = THEME.stroke
    stroke.Parent = btn

    createCorner(btn, CONTROL_CORNER_RADIUS)
    applyTextGlow(btn, GLOW_COLOR, 0.9)
    return btn
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 380, 0, 360)
main.Position = UDim2.fromOffset(0, 0)
main.BackgroundColor3 = Color3.fromRGB(164, 93, 39)
main.BorderSizePixel = 0
main.Parent = gui
main.Visible = false

local TOP_BAR_HEIGHT = 34
local expandedWidth = 380
local expandedHeight = 360

local function getViewportSize()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function getBottomRightPosition(sizeY)
    local viewport = getViewportSize()
    local width = expandedWidth
    local height = tonumber(sizeY) or expandedHeight
    local x = math.max(12, viewport.X - width - 18)
    local y = math.max(12, viewport.Y - height - 18)
    return UDim2.fromOffset(x, y)
end

local function applyResponsiveSize(centerOnApply)
    local viewport = getViewportSize()
    expandedWidth = math.clamp(math.floor(viewport.X - 72), 340, 400)
    expandedHeight = math.clamp(math.floor(viewport.Y - 40), 360, 412)

    if not UserInputService.TouchEnabled then
        expandedWidth = math.max(expandedWidth, 380)
        expandedHeight = math.max(expandedHeight, 360)
    end

    main.Size = UDim2.new(0, expandedWidth, 0, expandedHeight)

    if centerOnApply then
        local centeredX = math.floor((viewport.X - expandedWidth) * 0.5)
        local centeredY = math.floor((viewport.Y - expandedHeight) * 0.5)
        main.Position = UDim2.fromOffset(math.max(0, centeredX), math.max(0, centeredY))
    else
        main.Position = getBottomRightPosition(expandedHeight)
    end
end

applyResponsiveSize(false)

do
    createCorner(main, SHELL_CORNER_RADIUS)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 210, 145)
    stroke.Thickness = 0
    stroke.Parent = main

    main.BackgroundColor3 = Color3.fromRGB(67, 180, 96)
end

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, TOP_BAR_HEIGHT)
topBar.BackgroundColor3 = THEME.topBar
topBar.BorderSizePixel = 0
topBar.Parent = main

do
    createCorner(topBar, SHELL_CORNER_RADIUS)
    topBar.BackgroundColor3 = Color3.fromRGB(38, 160, 73)
end

do
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -48, 0, 15)
    title.Position = UDim2.new(0, 32, 0, 2)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = THEME.topBarText
    title.Font = UI_FONT_BOLD
    title.TextSize = 15
    title.Text = "PLS DONATE 🥳 | brought back"
    title.Parent = topBar
    applyTextGlow(title, GLOW_COLOR, 0.78)

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(1, -48, 0, 11)
    subtitle.Position = UDim2.new(0, 32, 0, 18)
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    subtitle.Font = UI_FONT
    subtitle.TextSize = 11
    subtitle.Text = "new features, anyone?"
    subtitle.Parent = topBar
    applyTextGlow(subtitle, Color3.fromRGB(255, 255, 255), 0.7)
end

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "Minimize"
minimizeBtn.Size = UDim2.new(0, 18, 0, 18)
minimizeBtn.Position = UDim2.new(0, 8, 0.5, -9)
minimizeBtn.BackgroundTransparency = 1
minimizeBtn.BorderSizePixel = 0
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = UI_FONT_BOLD
minimizeBtn.TextSize = 15
minimizeBtn.Text = "▼"
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = topBar
applyTextGlow(minimizeBtn, GLOW_COLOR, 0.78)

do
    local miniStroke = Instance.new("UIStroke")
    miniStroke.Thickness = 0
    miniStroke.Color = Color3.fromRGB(170, 176, 183)
    miniStroke.Parent = minimizeBtn
end

local body = Instance.new("Frame")
body.Name = "Body"
body.Size = UDim2.new(1, 0, 1, -TOP_BAR_HEIGHT)
body.Position = UDim2.new(0, 0, 0, TOP_BAR_HEIGHT)
body.BackgroundTransparency = 1
body.Parent = main

local tabHolder = Instance.new("ScrollingFrame")
tabHolder.Name = "Tabs"
tabHolder.Size = UDim2.new(1, -12, 0, 34)
tabHolder.Position = UDim2.new(0, 6, 0, 5)
tabHolder.BackgroundColor3 = THEME.section
tabHolder.BorderSizePixel = 0
tabHolder.ScrollBarThickness = 2
tabHolder.ScrollBarImageColor3 = THEME.stroke
tabHolder.ScrollBarImageTransparency = 0.15
tabHolder.AutomaticCanvasSize = Enum.AutomaticSize.X
tabHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
tabHolder.ScrollingDirection = Enum.ScrollingDirection.X
tabHolder.Parent = body

do
    createCorner(tabHolder, CONTROL_CORNER_RADIUS)

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Thickness = 1
    tabStroke.Color = THEME.stroke
    tabStroke.Parent = tabHolder
end

do
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 3)
    tabLayout.Parent = tabHolder

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, 4)
    tabPad.PaddingBottom = UDim.new(0, 4)
    tabPad.PaddingLeft = UDim.new(0, 6)
    tabPad.PaddingRight = UDim.new(0, 6)
    tabPad.Parent = tabHolder
end

local pages = Instance.new("Frame")
pages.Name = "Pages"
pages.Size = UDim2.new(1, -12, 1, -43)
pages.Position = UDim2.new(0, 6, 0, 40)
pages.BackgroundTransparency = 1
pages.Parent = body

local function makeDraggable(frame, handle)
    local DRAG_SMOOTH_TIME = 0.06
    local dragging = false
    local dragStart
    local startPos
    local dragTween

    local function update(input)
        local delta = input.Position - dragStart
        local nextPosition = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )

        if dragTween then
            dragTween:Cancel()
        end

        dragTween = TweenService:Create(
            frame,
            TweenInfo.new(DRAG_SMOOTH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = nextPosition}
        )
        dragTween:Play()
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if dragTween then
                        dragTween:Cancel()
                        dragTween = nil
                    end
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            update(input)
        end
    end)
end

makeDraggable(main, topBar)

local minimized = false
local minimizeTween
local function setMinimized(state)
    local MINIMIZE_TWEEN_TIME = 0.2
    if state == minimized and not minimizeTween then
        return
    end

    if minimizeTween then
        minimizeTween:Cancel()
        minimizeTween = nil
    end

    if not state then
        body.Visible = true
    end

    local targetSize = state and UDim2.new(0, expandedWidth, 0, TOP_BAR_HEIGHT) or UDim2.new(0, expandedWidth, 0, expandedHeight)
    minimizeBtn.Text = state and "▲" or "▼"
    minimizeBtn.BackgroundTransparency = 1
    minimizeBtn.BorderSizePixel = 0

    minimizeTween = TweenService:Create(
        main,
        TweenInfo.new(MINIMIZE_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = targetSize}
    )
    local tweenRef = minimizeTween

    minimized = state
    minimizeTween:Play()
    minimizeTween.Completed:Connect(function()
        if minimizeTween ~= tweenRef then
            return
        end
        minimizeTween = nil
        body.Visible = not minimized
    end)
end

minimizeBtn.Activated:Connect(function()
    setMinimized(not minimized)
end)

local tabButtons = {}
local tabPages = {}
local activeTab
local settingHandlers
local animSpeedSliderUpdate

local function setTabVisualState(btn, active)
    if not btn then
        return
    end

    btn.BackgroundColor3 = active and Color3.fromRGB(72, 75, 81) or THEME.tabIdle
    btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(214, 214, 218)
    btn.Font = UI_FONT_BOLD
    btn.TextTransparency = active and 0 or 0.04
    btn.Position = UDim2.new(btn.Position.X.Scale, btn.Position.X.Offset, btn.Position.Y.Scale, active and 3 or 0)
    btn.Size = UDim2.new(0, 96, 0, active and 25 or 30)

    local pressedInset = btn:FindFirstChild("PressedInset")
    if pressedInset then
        pressedInset.BackgroundTransparency = active and 0.7 or 1
    end

    local activeBar = btn:FindFirstChild("ActiveBar")
    if activeBar then
        activeBar.Visible = false
    end
end

local function activateTab(name)
    for tabName, page in pairs(tabPages) do
        local btn = tabButtons[tabName]
        local isActive = tabName == name
        page.Visible = isActive
        setTabVisualState(btn, isActive)
    end
    activeTab = name
end

local function createTab(name, buttonText)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.AutomaticSize = Enum.AutomaticSize.None
    btn.Size = UDim2.new(0, 96, 0, 30)
    btn.BackgroundColor3 = THEME.tabIdle
    btn.TextColor3 = Color3.fromRGB(214, 214, 218)
    btn.Font = UI_FONT_BOLD
    btn.TextSize = 13
    btn.Text = tostring(buttonText or name)
    btn.AutoButtonColor = false
    btn.Parent = tabHolder
    applyTextGlow(btn, GLOW_COLOR, 0.88)

    createCorner(btn, 4)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = Color3.fromRGB(94, 98, 104)
    btnStroke.Parent = btn

    local activeBar = Instance.new("Frame")
    activeBar.Name = "ActiveBar"
    activeBar.Size = UDim2.new(1, -16, 0, 0)
    activeBar.Position = UDim2.new(0, 8, 0, 0)
    activeBar.BackgroundColor3 = Color3.fromRGB(255, 175, 92)
    activeBar.BorderSizePixel = 0
    activeBar.Visible = false
    activeBar.Parent = btn

    local pressedInset = Instance.new("Frame")
    pressedInset.Name = "PressedInset"
    pressedInset.Size = UDim2.new(1, 0, 1, 0)
    pressedInset.Position = UDim2.new(0, 0, 0, 0)
    pressedInset.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    pressedInset.BackgroundTransparency = 1
    pressedInset.BorderSizePixel = 0
    pressedInset.ZIndex = 0
    pressedInset.Parent = btn

    btn.MouseEnter:Connect(function()
        if activeTab ~= name then
            btn.BackgroundColor3 = Color3.fromRGB(84, 84, 90)
        end
    end)

    btn.MouseLeave:Connect(function()
        if activeTab ~= name then
            btn.BackgroundColor3 = THEME.tabIdle
        end
    end)

    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Visible = false
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundColor3 = THEME.panel
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 5
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Parent = pages

    createCorner(page, CONTROL_CORNER_RADIUS)

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Size = UDim2.new(1, -12, 0, 0)
    content.Position = UDim2.new(0, 6, 0, 6)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.Parent = page

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.Parent = content

    tabButtons[name] = btn
    tabPages[name] = page

    btn.MouseButton1Click:Connect(function()
        activateTab(name)
    end)

    return content
end

local antiSitConnection

local function setAntiSitEnabled(enabled)
    if antiSitConnection then
        antiSitConnection:Disconnect()
        antiSitConnection = nil
    end

    if not enabled then
        return
    end

    antiSitConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = true
            if humanoid.Sit then
                humanoid.Sit = false
            end
        end
    end)
end

setAntiSitEnabled(true)

local function createSection(parent, titleText)
    local section = Instance.new("Frame")
    section.BackgroundColor3 = THEME.section
    section.BorderSizePixel = 0
    section.Size = UDim2.new(1, 0, 0, 0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.Parent = parent

    createCorner(section, CONTROL_CORNER_RADIUS)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -12, 0, 24)
    titleLabel.Position = UDim2.new(0, 8, 0, 6)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = UI_FONT_BOLD
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = THEME.subtleText
    titleLabel.Text = titleText
    titleLabel.Parent = section
    applyTextGlow(titleLabel, SUBTLE_GLOW_COLOR, SUBTLE_GLOW_TRANSPARENCY)

    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Position = UDim2.new(0, 8, 0, 34)
    holder.Size = UDim2.new(1, -16, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.Parent = section

    local holderLayout = Instance.new("UIListLayout")
    holderLayout.Padding = UDim.new(0, 6)
    holderLayout.Parent = holder

    return holder
end


local function createToggle(parent, text, key)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 24)
    row.Parent = parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 18, 0, 18)
    btn.Position = UDim2.new(0, 2, 0.5, -9)
    btn.Font = UI_FONT_BOLD
    btn.TextSize = 12
    btn.Parent = row

    createCorner(btn, CONTROL_CORNER_RADIUS)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = THEME.stroke
    btnStroke.Parent = btn

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -26, 1, 0)
    label.Position = UDim2.new(0, 26, 0, 0)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = UI_FONT
    label.TextSize = 13
    label.TextColor3 = THEME.controlText
    label.Text = text
    label.Parent = row
    applyTextGlow(label, GLOW_COLOR, 0.88)

    local function applyState()
        local enabled = settings[key] == true
        btn.Text = enabled and "✓" or ""
        btn.BackgroundColor3 = enabled and Color3.fromRGB(92, 96, 102) or THEME.control
        btn.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or THEME.controlText
    end

    applyState()

    btn.MouseButton1Click:Connect(function()
        settings[key] = not settings[key]
        applyState()
        saveSettings()
        if settingHandlers[key] then
            pcall(settingHandlers[key], settings[key])
        end
    end)
end

local function escapePattern(str)
    return (str:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local featuresOk, features = pcall(function()
    return ConfigModule.create({
        LocalPlayer = LocalPlayer,
        settings = settings,
        getClaimedBoothSlot = function()
            return claimedBoothSlot
        end,
        getBoothTargetCFrameForStand = getBoothTargetCFrameForStand,
        sendChatMessage = sendChatMessage,
    })
end)
if not featuresOk then
    warn("[PLS DONATE] Config module feature initialization failed:", features)
    return
end

local requiredFeatureMethods = {
    "applySpinDonation",
    "addDonationAnimSpeed",
    "applyCurrentAnimSpeed",
    "applySpinState",
    "isHelicopterBusy",
    "performHelicopterDonationSequence",
    "resetSpinAccumulator",
    "resetDonationAnimSpeedBoost",
    "setAntiAfkEnabled",
        "playCatalogEmoteByName",
    "startHelicopterIdleMode",
    "stopAstronautIdle",
        "stopCatalogEmoteTrack",
    "stopHelicopterIdleTask",
    "stopHelicopterSpin",
}
for _, methodName in ipairs(requiredFeatureMethods) do
    if type(features) ~= "table" or type(features[methodName]) ~= "function" then
        warn("[PLS DONATE] Config module is missing feature method:", methodName)
        return
    end
end

print("[PLS DONATE] Config module connected successfully.")

local function getCharacterHumanoidRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

local function applyGoalBarTemplateIfActive()
    local currentText = tostring(settings.customBoothText or "")
    if currentText == "" or currentText:find("%$BAR") ~= nil or currentText:find("GOAL") ~= nil or currentText:find("goal") ~= nil then
        local generated = buildGoalBarTemplate()
        if generated ~= currentText then
            settings.customBoothText = generated
            saveSettings()
            return true
        end
    end
    return false
end

local function restoreRuntimeSettings()
    if type(settingHandlers) ~= "table" then
        return
    end

    for key, value in pairs(settings) do
        local handler = settingHandlers[key]
        if type(handler) == "function" then
            pcall(handler, value)
        end
    end
end

settingHandlers = {
    helicopterEnabled = function(value)
        if value then
            features.startHelicopterIdleMode()
        else
            features.stopHelicopterIdleTask()
            features.stopHelicopterSpin()
            features.stopAstronautIdle()
        end
    end,
    antiAfkToggle = function(value)
        features.setAntiAfkEnabled(value == true)
    end,
    catalogEmote = function(value)
        local played, status = features.playCatalogEmoteByName(value)
        if not played and status ~= "disabled" then
            warn("[PLS DONATE] Could not play catalog emote:", status)
        end
    end,
    animSpeedSetting = function()
        features.applyCurrentAnimSpeed()
    end,
    animSpeedMultiplier = function(value)
        settings.animSpeedMultiplier = math.max(0, tonumber(value) or 1)
        saveSettings()
        features.applyCurrentAnimSpeed()
    end,
    animSpeedPerRobux = function(value)
        settings.animSpeedPerRobux = value == true
        if settings.animSpeedPerRobux then
            features.applyCurrentAnimSpeed()
        else
            features.resetDonationAnimSpeedBoost()
        end
        saveSettings()
    end,
    textUpdateToggle = function(value)
        if value and updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    goalBarColor = function(value)
        local lower = tostring(value or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local allowed = {
            green = true,
            blue = true,
            red = true,
            orange = true,
            purple = true,
        }
        settings.goalBarColor = allowed[lower] and lower or defaults.goalBarColor
        saveSettings()
        if applyGoalBarTemplateIfActive() and updateBoothTextNow then
            updateBoothTextNow()
        elseif updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    goalBarHeaderText = function()
        saveSettings()
        if applyGoalBarTemplateIfActive() and updateBoothTextNow then
            updateBoothTextNow()
        elseif updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    standingPosition = function(value)
        local positionMap = {
            Front = 3,
            Left = -6,
            Right = 6,
            Behind = -5.5,
        }
        settings.boothPosition = positionMap[tostring(value)] or 3
        saveSettings()
    end,
    boothMovementMode = function(value)
        local mode = tostring(value or "Teleport")
        if mode ~= "Walk" then
            mode = "Teleport"
        end
        settings.boothMovementMode = mode
        saveSettings()
    end,
    spinSet = function()
        if not settings.spinSet then
            features.resetSpinAccumulator()
        end
        features.applySpinState()
    end,
    serverHopDelay = function(value)
        hopTimerResetTick = tick()
        donatedSinceHopTimerReset = 0
    end,
    minPlayerCount = function(value)
        local minVal = math.max(1, tonumber(value) or 23)
        settings.minPlayerCount = minVal
        if tonumber(settings.maxPlayerCount or 24) < minVal then
            settings.maxPlayerCount = minVal
        end
        saveSettings()
    end,
    maxPlayerCount = function(value)
        local maxVal = math.max(1, tonumber(value) or 24)
        if maxVal < tonumber(settings.minPlayerCount or 23) then
            settings.minPlayerCount = maxVal
        end
        settings.maxPlayerCount = maxVal
        saveSettings()
    end,
    plusMemberTarget = function(value)
        settings.plusMemberTarget = math.max(0, tonumber(value) or 3)
        saveSettings()
    end,
    plusHopToggle = function(value)
        settings.plusHopToggle = value == true
        saveSettings()
    end,
    vcServerHopToggle = function(value)
        if value then
            serverHopNow("vc-server-hop-toggle")
        end
    end,
}

local handledClaimSlot
local revealedAfterClaim = false
local function onBoothClaimDetected(slot)
    if not slot then
        return
    end

    claimedBoothSlot = slot
    if handledClaimSlot == slot then
        return
    end

    handledClaimSlot = slot
    moveToClaimedBooth(slot)

    if not suppressBoothTextAutoApply and settings.textUpdateToggle and settings.customBoothText and tostring(settings.customBoothText) ~= "" and updateBoothTextNow then
        task.delay(0.35, function()
            pcall(function()
                updateBoothTextNow()
            end)
        end)
    end

end

local dropdownCloseFns = {}
local activeDropdown

local function createTextBox(parent, text, key, numeric)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 30)
    row.Parent = parent

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 24)
    box.Position = UDim2.new(0, 0, 0.5, -12)
    styleTextBox(box, Enum.TextXAlignment.Center, false)
    local prefix = text .. ": "
    box.Text = prefix .. tostring(settings[key])
    box.Parent = row
    applyTextGlow(box, GLOW_COLOR, 0.88)

    createCorner(box, CONTROL_CORNER_RADIUS)

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1
    boxStroke.Color = THEME.stroke
    boxStroke.Parent = box

    box.FocusLost:Connect(function(enterPressed)
        local prefPattern = "^" .. escapePattern(prefix)
        if not enterPressed then
            box.Text = prefix .. tostring(settings[key])
            return
        end

        local rawValue = box.Text:gsub(prefPattern, "")
        rawValue = rawValue:gsub("^%s+", ""):gsub("%s+$", "")

        if numeric then
            local n = tonumber(rawValue)
            if n == nil then
                box.Text = prefix .. tostring(settings[key])
                return
            end
            settings[key] = n
        else
            settings[key] = rawValue
        end

        saveSettings()
        if settingHandlers[key] then
            pcall(settingHandlers[key], settings[key])
        end
        box.Text = prefix .. tostring(settings[key])
    end)
end

local function createPlainTextBox(parent, placeholder, key, height, multiline)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    local boxHeight = math.max(38, tonumber(height) or 38)
    row.Size = UDim2.new(1, 0, 0, boxHeight + 6)
    row.Parent = parent

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, boxHeight)
    box.Position = UDim2.new(0, 0, 0, 3)
    styleTextBox(box, Enum.TextXAlignment.Left, multiline)
    box.PlaceholderText = placeholder
    box.Text = tostring(settings[key] or "")
    box.Parent = row
    applyTextGlow(box, GLOW_COLOR, 0.88)

    local boxPadding = Instance.new("UIPadding")
    boxPadding.PaddingLeft = UDim.new(0, 8)
    boxPadding.PaddingRight = UDim.new(0, 8)
    boxPadding.Parent = box

    createCorner(box, CONTROL_CORNER_RADIUS)

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1
    boxStroke.Color = THEME.stroke
    boxStroke.Parent = box

    local liveUpdateRevision = 0
    if key == "customBoothText" then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            settings[key] = tostring(box.Text or "")
            liveUpdateRevision += 1
            local revision = liveUpdateRevision

            task.delay(0.35, function()
                if revision ~= liveUpdateRevision then
                    return
                end

                saveSettings()

                if #settings[key] > 221 then
                    return
                end

                if not suppressBoothTextAutoApply and settings.textUpdateToggle and tostring(settings[key]) ~= "" and updateBoothTextNow then
                    pcall(function()
                        updateBoothTextNow()
                    end)
                end
            end)
        end)
    end

    box.FocusLost:Connect(function()
        settings[key] = tostring(box.Text or "")
        saveSettings()
        if settingHandlers[key] then
            pcall(settingHandlers[key], settings[key])
        end
    end)

    return box
end

local function createDropdown(parent, text, key, options)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 30)
    row.Parent = parent

    local baseHeight = 30
    local optionHeight = 22
    local optionsHeight = (#options * optionHeight) + 6

    local btn = createStyledButton(row, nil, UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0.5, -12), THEME.control, THEME.controlText, 12, Enum.Font.Gotham)

    local listFrame = Instance.new("Frame")
    listFrame.Visible = false
    listFrame.BackgroundColor3 = THEME.control
    listFrame.BorderSizePixel = 0
    listFrame.Position = UDim2.new(0, 0, 0, baseHeight)
    listFrame.Size = UDim2.new(1, 0, 0, optionsHeight)
    listFrame.ZIndex = 20
    listFrame.Parent = row

    createCorner(listFrame, CONTROL_CORNER_RADIUS)

    local listStroke = Instance.new("UIStroke")
    listStroke.Thickness = 1
    listStroke.Color = THEME.stroke
    listStroke.Parent = listFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = listFrame

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 3)
    listPad.PaddingBottom = UDim.new(0, 3)
    listPad.PaddingLeft = UDim.new(0, 3)
    listPad.PaddingRight = UDim.new(0, 3)
    listPad.Parent = listFrame

    local idx = 1
    for i, v in ipairs(options) do
        if v == settings[key] then
            idx = i
            break
        end
    end

    local function syncText()
        btn.Text = text .. ": [ " .. tostring(options[idx]) .. " ]"
    end
    syncText()

    local expanded = false
    local function setExpanded(open)
        expanded = open
        listFrame.Visible = open
        row.Size = open and UDim2.new(1, 0, 0, baseHeight + optionsHeight + 2) or UDim2.new(1, 0, 0, baseHeight)
        btn.Text = (open and "▼ " or "") .. text .. ": [ " .. tostring(options[idx]) .. " ]"
    end

    dropdownCloseFns[row] = function()
        setExpanded(false)
    end

    for i, v in ipairs(options) do
        local optionBtn = createStyledButton(listFrame, tostring(v), UDim2.new(1, 0, 0, optionHeight), nil, THEME.section, THEME.controlText, 12, Enum.Font.Gotham)
        optionBtn.ZIndex = 21

        optionBtn.MouseButton1Click:Connect(function()
            idx = i
            settings[key] = options[idx]
            syncText()
            saveSettings()
            if settingHandlers[key] then
                pcall(settingHandlers[key], settings[key])
            end
            setExpanded(false)
            activeDropdown = nil
        end)
    end

    btn.MouseButton1Click:Connect(function()
        if activeDropdown and activeDropdown ~= row and dropdownCloseFns[activeDropdown] then
            dropdownCloseFns[activeDropdown]()
        end

        if expanded then
            setExpanded(false)
            activeDropdown = nil
        else
            setExpanded(true)
            activeDropdown = row
        end
    end)
end

local function createMessageDropdown(parent, text, key, fallback)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 30)
    row.Parent = parent

    local baseHeight = 30
    local contentHeight = 216

    local btn = createStyledButton(row, text, UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0.5, -12), THEME.control, THEME.controlText, 12, Enum.Font.Gotham)

    local content = Instance.new("Frame")
    content.Visible = false
    content.BackgroundColor3 = THEME.control
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0, 0, 0, baseHeight)
    content.Size = UDim2.new(1, 0, 0, contentHeight)
    content.Parent = row

    createCorner(content, CONTROL_CORNER_RADIUS)

    local contentStroke = Instance.new("UIStroke")
    contentStroke.Thickness = 1
    contentStroke.Color = THEME.stroke
    contentStroke.Parent = content

    local contentPad = Instance.new("UIPadding")
    contentPad.PaddingTop = UDim.new(0, 6)
    contentPad.PaddingBottom = UDim.new(0, 6)
    contentPad.PaddingLeft = UDim.new(0, 6)
    contentPad.PaddingRight = UDim.new(0, 6)
    contentPad.Parent = content

    local editor = Instance.new("TextBox")
    editor.Size = UDim2.new(1, 0, 0, 140)
    editor.BackgroundColor3 = THEME.section
    editor.TextColor3 = THEME.controlText
    editor.PlaceholderColor3 = THEME.subtleText
    editor.Font = Enum.Font.Gotham
    editor.TextSize = 12
    editor.ClearTextOnFocus = false
    editor.TextXAlignment = Enum.TextXAlignment.Left
    editor.TextYAlignment = Enum.TextYAlignment.Top
    editor.MultiLine = true
    editor.TextWrapped = false
    editor.PlaceholderText = "One message per line (no limit)"
    editor.Parent = content
    applyTextGlow(editor, GLOW_COLOR, 0.9)

    local editorPad = Instance.new("UIPadding")
    editorPad.PaddingTop = UDim.new(0, 6)
    editorPad.PaddingBottom = UDim.new(0, 6)
    editorPad.PaddingLeft = UDim.new(0, 8)
    editorPad.PaddingRight = UDim.new(0, 8)
    editorPad.Parent = editor

    createCorner(editor, CONTROL_CORNER_RADIUS)

    local editorStroke = Instance.new("UIStroke")
    editorStroke.Thickness = 1
    editorStroke.Color = THEME.stroke
    editorStroke.Parent = editor

    local saveBtn = createStyledButton(content, "Save", UDim2.new(0.5, -3, 0, 24), UDim2.new(0, 0, 0, 146), THEME.topBar, THEME.topBarText, 11, Enum.Font.GothamSemibold)
    local closeBtn = createStyledButton(content, "Close", UDim2.new(0.5, -3, 0, 24), UDim2.new(0.5, 3, 0, 146), THEME.section, THEME.controlText, 11, Enum.Font.GothamSemibold)
    local nextLineBtn = createStyledButton(content, "Skip To Next Line", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 174), THEME.control, THEME.controlText, 11, Enum.Font.GothamSemibold)

    local currentList = normalizeMessageList(settings[key], defaults[key])
    settings[key] = currentList
    editor.Text = table.concat(currentList, "\n")

    local expanded = false
    local function setExpanded(open)
        expanded = open
        content.Visible = open
        row.Size = open and UDim2.new(1, 0, 0, baseHeight + contentHeight + 2) or UDim2.new(1, 0, 0, baseHeight)
        btn.Text = (open and "▼ " or "") .. text
    end

    dropdownCloseFns[row] = function()
        setExpanded(false)
    end

    saveBtn.MouseButton1Click:Connect(function()
        local parsed = {}
        for line in tostring(editor.Text or ""):gmatch("[^\r\n]+") do
            local message = trimText(line)
            if message ~= "" then
                table.insert(parsed, message)
            end
        end

        settings[key] = normalizeMessageList(parsed, {fallback})
        editor.Text = table.concat(settings[key], "\n")
        saveSettings()
        notify("Chat Messages", text .. " saved.", 3, "chat-message-save-" .. key, 0.5)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        setExpanded(false)
        activeDropdown = nil
    end)

    nextLineBtn.MouseButton1Click:Connect(function()
        editor.Text = tostring(editor.Text or "") .. "\n"
        pcall(function()
            editor:CaptureFocus()
            editor.CursorPosition = #editor.Text + 1
        end)
    end)

    btn.MouseButton1Click:Connect(function()
        if activeDropdown and activeDropdown ~= row and dropdownCloseFns[activeDropdown] then
            dropdownCloseFns[activeDropdown]()
        end

        if expanded then
            setExpanded(false)
            activeDropdown = nil
        else
            setExpanded(true)
            activeDropdown = row
        end
    end)
end

local function createButton(parent, text, callback)
    local btn = createStyledButton(parent, text, UDim2.new(0, 104, 0, 23), nil, THEME.topBar, THEME.topBarText, 11, Enum.Font.GothamSemibold)

    btn.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            warn("Button callback error:", err)
        end
    end)
end

local function createSlider(parent, text, key, minVal, maxVal)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 44)
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = THEME.controlText
    lbl.Parent = row
    applyTextGlow(lbl, GLOW_COLOR, 0.88)

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0, 26)
    track.BackgroundColor3 = THEME.control
    track.BorderSizePixel = 0
    track.Parent = row

    createCorner(track, CONTROL_CORNER_RADIUS)

    local trackStroke = Instance.new("UIStroke")
    trackStroke.Thickness = 1
    trackStroke.Color = THEME.stroke
    trackStroke.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = THEME.accent
    fill.BorderSizePixel = 0
    fill.Parent = track

    createCorner(fill, CONTROL_CORNER_RADIUS)

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.BackgroundColor3 = THEME.accent
    thumb.BorderSizePixel = 0
    thumb.Position = UDim2.new(0, 0, 0.5, 0)
    thumb.ZIndex = 5
    thumb.Parent = track

    createCorner(thumb, 2)

    local function updateVisuals(val)
        val = math.clamp(tonumber(val) or minVal, minVal, maxVal)
        local ratio = (val - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
        local rounded = math.floor((val * 100) + 0.5) / 100
        local displayValue = rounded == math.floor(rounded) and tostring(math.floor(rounded)) or string.format("%.2f", rounded):gsub("0+$", ""):gsub("%.$", "")
        lbl.Text = text .. ": " .. displayValue
    end

    local currentValue = math.clamp(tonumber(settings[key]) or minVal, minVal, maxVal)
    updateVisuals(currentValue)

    local dragging = false

    local function setFromAbsoluteX(absX)
        local trackAbsPos = track.AbsolutePosition
        local trackAbsSize = track.AbsoluteSize
        if trackAbsSize.X <= 0 then return end
        local ratio = math.clamp((absX - trackAbsPos.X) / trackAbsSize.X, 0, 1)
        local newVal = math.clamp(math.floor(minVal + ratio * (maxVal - minVal) + 0.5), minVal, maxVal)
        if newVal ~= settings[key] then
            settings[key] = newVal
            updateVisuals(newVal)
            saveSettings()
            if settingHandlers and settingHandlers[key] then
                pcall(settingHandlers[key], settings[key])
            end
        end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromAbsoluteX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            setFromAbsoluteX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return updateVisuals
end

local function createInfoLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 16)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = THEME.subtleText
    label.TextWrapped = true
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Text = tostring(text)
    label.Parent = parent
    return label
end

local function buildSettingsTabs()
    local boothTab = createTab("Booth", localized("tabBooth"))
    local mainTab = createTab("Main", localized("tabMain"))
    local chatTab = createTab("Chat", localized("tabChat"))
    local webhookTab = createTab("Webhook", localized("tabWebhook"))
    local serverTab = createTab("Server Hop", localized("tabServerHop"))

    local boothSection = createSection(boothTab, localized("boothSection"))
    createToggle(boothSection, localized("textUpdate"), "textUpdateToggle")
    createDropdown(boothSection, localized("goalBarColor"), "goalBarColor", {"green", "blue", "red", "orange", "purple"})
    local boothTextBox
    createInfoLabel(boothSection, localized("goalBarHeader"))
    local goalBarHeaderBox = createPlainTextBox(boothSection, "GOAL $G", "goalBarHeaderText", 38, false)
    createInfoLabel(boothSection, localized("goalBarHint"))
    createButton(boothSection, localized("pasteGoalBar"), function()
        settings.goalBarHeaderText = tostring(goalBarHeaderBox.Text or settings.goalBarHeaderText or "GOAL $G")
        local nextText = buildGoalBarTemplate()
        if #nextText > 221 then
            notify("Goal Bar", "Goal bar template is too long for the booth.", 4, "goal-bar-limit", 1)
            return
        end
        settings.customBoothText = nextText
        saveSettings()
        suppressBoothTextAutoApply = false
        SharedEnv.PLS_DONO_BOOTH_TEXT_SUPPRESS = false
        local ok, mode = updateBoothTextNow(true)
        if ok then
            boothTextBox.Text = nextText
            notify("Goal Bar", "Goal bar pasted onto the booth.", 4, "goal-bar-ok", 1)
        elseif mode == "local-preview-only" then
            boothTextBox.Text = nextText
            notify("Goal Bar", "Preview updated, waiting for remote confirmation.", 4, "goal-bar-preview", 2)
        else
            notify("Goal Bar", "Could not paste the goal bar yet.", 4, "goal-bar-fail", 2)
        end
        task.defer(rejoinAfterUserBoothUpdate)
    end)
    createInfoLabel(boothSection, localized("customBoothText"))
    boothTextBox = createPlainTextBox(boothSection, localized("boothTextPlaceholder"), "customBoothText", 56, true)
    createInfoLabel(boothSection, localized("boothTextTokens"))
    createInfoLabel(boothSection, localized("textColors"))
    createButton(boothSection, localized("update"), function()
        local nextText = tostring(boothTextBox.Text or "")
        if #nextText > 221 then
            boothTextBox.Text = "Character limit reached"
            notify("Booth Text", "Character limit reached.", 4, "booth-text-limit", 1)
            return
        end

        settings.customBoothText = nextText
        saveSettings()
        suppressBoothTextAutoApply = false
        SharedEnv.PLS_DONO_BOOTH_TEXT_SUPPRESS = false
        local ok, mode = updateBoothTextNow(true)
        if ok then
            notify("Booth Text", "Booth text updated.", 4, "booth-text-ok", 1)
        elseif mode == "local-preview-only" then
            notify("Booth Text", "Preview updated, waiting for remote confirmation.", 4, "booth-text-preview", 2)
        else
            notify("Booth Text", "Could not update booth text yet.", 4, "booth-text-fail", 2)
        end
        task.defer(rejoinAfterUserBoothUpdate)
    end)
    createDropdown(boothSection, localized("standingPosition"), "standingPosition", {"Front", "Left", "Right", "Behind"})
    createDropdown(boothSection, localized("boothMovementMode"), "boothMovementMode", {"Teleport", "Walk"})

    do
        local mainSection = createSection(mainTab, localized("mainSection"))
        createToggle(mainSection, localized("helicopter"), "helicopterEnabled")
        createToggle(mainSection, localized("spin"), "spinSet")
        createToggle(mainSection, localized("antiAfk"), "antiAfkToggle")
        createDropdown(mainSection, localized("catalogEmote"), "catalogEmote", ConfigModule.emoteOptions)
        animSpeedSliderUpdate = createSlider(mainSection, localized("animSpeed"), "animSpeedSetting", 1, 100)
        createTextBox(mainSection, localized("animSpeedMultiplier"), "animSpeedMultiplier", true)
        createToggle(mainSection, localized("animSpeedPerRobux"), "animSpeedPerRobux")
        createTextBox(mainSection, localized("testDonationAmount"), "testDonationAmount", true)
        createButton(mainSection, localized("testDonation"), function()
            local stat = getRaisedStatObject()
            local amount = math.max(1, tonumber(settings.testDonationAmount) or 6)
            if stat and type(stat.Value) == "number" then
                local before = stat.Value
                stat.Value += amount
                if settings.webhookToggle then
                    sendDonationWebhook(amount, getNearestPlayerInfo())
                end
                notify("Test Donation", ("Simulated +%d R$ donation."):format(amount), 3, "test-dono", 1)
                features.applySpinDonation(amount)
                if settings.helicopterEnabled then
                    features.performHelicopterDonationSequence(amount)
                end
            else
                notify("Test Donation", "Raised stat not found.", 3, "test-dono-missing", 1)
            end
        end)
    end

    do
        local chatSection = createSection(chatTab, localized("chatSection"))
        createToggle(chatSection, localized("autoThanks"), "autoThanks")
        createTextBox(chatSection, localized("thanksDelay"), "thanksDelay", true)
        createMessageDropdown(chatSection, localized("thanksMessages"), "thanksMessage", "Thank you")
        createToggle(chatSection, localized("autoBeg"), "autoBeg")
        createTextBox(chatSection, localized("begDelay"), "begDelay", true)
        createMessageDropdown(chatSection, localized("begMessages"), "begMessage", "Please donate")
    end

do
    local webhookSection = createSection(webhookTab, localized("webhookSection"))
    createToggle(webhookSection, localized("webhookEnabled"), "webhookToggle")
    createTextBox(webhookSection, localized("webhookUrl"), "webhookBox", false)
    createToggle(webhookSection, localized("notifyPerHop"), "notifyPerHopToggle")
end

do
    local serverSection = createSection(serverTab, localized("serverSection"))
    createToggle(serverSection, localized("autoServerHop"), "serverHopToggle")
    createTextBox(serverSection, localized("serverHopDelay"), "serverHopDelay", true)
    createTextBox(serverSection, localized("minPlayers"), "minPlayerCount", true)
    createTextBox(serverSection, localized("maxPlayers"), "maxPlayerCount", true)
    createToggle(serverSection, localized("smallServer"), "populationHopToggle")
    createTextBox(serverSection, localized("smallThreshold"), "populationHopThreshold", true)
    createToggle(serverSection, localized("plusHop"), "plusHopToggle")
    createTextBox(serverSection, localized("plusMemberTarget"), "plusMemberTarget", true)
    createToggle(serverSection, localized("modEvader"), "modEvader")
    createButton(serverSection, localized("serverHopNow"), function()
        requestServerHop("manual-button")
    end)

    -- VC Server Hop
    createToggle(serverSection, localized("vcServerHop"), "vcServerHopToggle")
end

end

cleanupWorkspaceCollisionModels()
watchWorkspaceCollisionModelCleanup()

buildSettingsTabs()
activateTab("Booth")
main.Visible = true

task.spawn(function()
    task.wait(2)
    local claimed, info = claimBoothNow()
    if claimed then
        onBoothClaimDetected(info)
    end
end)

task.defer(function()
    restoreRuntimeSettings()
end)

task.spawn(function()
    while task.wait(0.8) do
        local boothLocation = getBoothLocation()
        local boothUiFolder = boothLocation and boothLocation:FindFirstChild("BoothUI")
        local ownedSlot = boothUiFolder and findOwnedBoothSlot(boothUiFolder)
        if ownedSlot then
            onBoothClaimDetected(ownedSlot)
        end
    end
end)

task.spawn(function()
    local lastPopulationHopTick = 0
    while task.wait(1) do
        if settings.populationHopToggle then
            local threshold = math.max(1, tonumber(settings.populationHopThreshold) or 15)
            local playerCount = #Players:GetPlayers()
            if playerCount < threshold and (tick() - lastPopulationHopTick) > 10 then
                lastPopulationHopTick = tick()
                notify("Server Hop", ("Server has %d players (below %d). Hopping..."):format(playerCount, threshold), 5, "population-hop", 6)
                requestServerHop("population-hop")
            end
        else
            lastPopulationHopTick = tick()
        end
    end
end)

task.spawn(function()
    local lastModHopTick = 0
    while task.wait(1) do
        if settings.modEvader then
            task.wait(3)
            local detectedPlayer = findDetectedModPlayer()
            if detectedPlayer and (tick() - lastModHopTick) > 8 then
                local displayName = tostring(detectedPlayer.DisplayName or detectedPlayer.Name or "Unknown")
                local username = tostring(detectedPlayer.Name or "Unknown")
                if requestServerHop("mod-detection") then
                    lastModHopTick = tick()
                    notify("Mod Evader", ("Flagged user detected: %s (@%s). Hopping..."):format(displayName, username), 5, "mod-evader-hop", 8)
                end
            end
        end
    end
end)

local activeDonationListener = nil
local activeDonationVfxListener = nil
local lastDonationSignature = ""
local lastDonationHandledAt = 0

local function handleDonationDelta(delta, donorInfo)
    local amount = math.max(0, tonumber(delta) or 0)
    if amount <= 0 then
        return
    end

    local donorName = tostring((donorInfo and donorInfo.name) or (donorInfo and donorInfo.displayName) or LocalPlayer.Name or "Unknown")
    local now = tick()
    local signature = donorName .. ":" .. tostring(amount)
    if signature == lastDonationSignature and now - lastDonationHandledAt < 1 then
        return
    end
    lastDonationSignature = signature
    lastDonationHandledAt = now

    lastDonationTick = tick()
    markDonationForHopTimer(amount)

    if features.addDonationAnimSpeed(amount) then
        if animSpeedSliderUpdate then
            animSpeedSliderUpdate(settings.animSpeedSetting)
        end
        saveSettings()
        notify("Anim Speed", "Anim speed reset to 1 after reaching the cap.", 4, "anim-speed-reset", 2)
    end

    features.applySpinDonation(amount)

    if settings.helicopterEnabled then
        features.performHelicopterDonationSequence(amount)
    end

    if settings.webhookToggle then
        sendDonationWebhook(amount, donorInfo or getNearestPlayerInfo())
    end

    if settings.autoThanks then
        sendChatMessage(math.random(1, 2) == 1 and "/e wave" or "/e laugh")
        task.spawn(function()
            task.wait(math.max(4, tonumber(settings.thanksDelay) or 0))
            local thankYouText = pickRandomMessage(settings.thanksMessage, "Thank you")
            if thankYouText ~= "" then
                sendChatMessage(thankYouText)
            else
                sendChatMessage("Thank you")
            end
        end)
    end
end

local function bindDonationListener()
    local raisedObj = getRaisedStatObject()
    if not raisedObj then
        return
    end

    if activeDonationListener and activeDonationListener.Parent == raisedObj then
        return
    end

    if activeDonationListener then
        activeDonationListener:Disconnect()
        activeDonationListener = nil
    end

    local lastRaised = tonumber(raisedObj.Value) or 0
    activeDonationListener = raisedObj.Changed:Connect(function()
        local current = tonumber(raisedObj.Value) or 0
        local delta = current - lastRaised
        lastRaised = current
        if delta > 0 then
            handleDonationDelta(delta, getNearestPlayerInfo())
        end
    end)

    local vfxContainer = ReplicatedStorage:FindFirstChild("VFXObjects")
    local vfxEvent = vfxContainer and vfxContainer:FindFirstChild("CreateVfx")
    if activeDonationVfxListener then
        activeDonationVfxListener:Disconnect()
        activeDonationVfxListener = nil
    end

    if vfxEvent and vfxEvent.OnClientEvent then
        activeDonationVfxListener = vfxEvent.OnClientEvent:Connect(function(...)
            local args = { ... }
            if type(args[1]) ~= "string" or args[1] ~= "GiveCurrency" then
                return
            end

            local targetCharacter = args[3]
            if targetCharacter ~= LocalPlayer.Character and targetCharacter ~= (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then
                return
            end

            local donationAmount = tonumber(args[4]) or tonumber(args[5]) or 0
            if donationAmount <= 0 then
                return
            end

            handleDonationDelta(donationAmount, getNearestPlayerInfo())
        end)
    end
end

task.spawn(function()
    bindDonationListener()
    while task.wait(1.25) do
        if getRaisedStatObject() then
            bindDonationListener()
        end
    end
end)

if LocalPlayer.Character then
    if settings.helicopterEnabled then
        task.delay(1.5, features.startHelicopterIdleMode)
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1.5, function()
        local character = LocalPlayer.Character
        if character then
        end
        if claimedBoothSlot then
            moveToClaimedBooth(claimedBoothSlot)
        end
        features.stopAstronautIdle()
        features.stopHelicopterIdleTask()
        features.stopHelicopterSpin()
        restoreRuntimeSettings()
        bindDonationListener()
    end)
end)

task.spawn(function()
    while task.wait(1) do
        if settings.serverHopToggle then
            local delayMinutes = math.max(1, tonumber(settings.serverHopDelay) or 15)
            if tick() - hopTimerResetTick >= (delayMinutes * 60) then
                if requestServerHop("auto-timer") then
                    resetHopTimer()
                end
            end
        else
            hopTimerResetTick = tick()
        end
    end
end)

task.spawn(function()
    local lastBegTick = 0
    while task.wait(1) do
        if settings.autoBeg then
            local delaySeconds = math.max(3, tonumber(settings.begDelay) or 300)
            if tick() - lastBegTick >= delaySeconds then
                lastBegTick = tick()
                sendChatMessage(pickRandomMessage(settings.begMessage, "Please donate"))
            end
        else
            lastBegTick = tick()
        end
    end
end)

task.spawn(function()
    while task.wait(0.4) do
        if settings.spinSet and claimedBoothSlot and not features.isHelicopterBusy() then
            local _, _, root = getCharacterHumanoidRoot()
            local targetCF = getClaimedBoothTargetCFrame(claimedBoothSlot)
            if root and targetCF then
                local distance = (root.Position - targetCF.Position).Magnitude
                if distance > 12 then
                    root.CFrame = targetCF
                    task.delay(0.1, function()
                        if root and root.Parent and settings.spinSet then
                            root.CFrame = targetCF
                        end
                    end)
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    local viewport = getViewportSize()
    local pos = main.Position
    local rightMargin = 20
    local bottomMargin = 20
    local x = math.clamp(pos.X.Offset, -main.AbsoluteSize.X + 120, viewport.X - rightMargin)
    local y = math.clamp(pos.Y.Offset, 0, viewport.Y - bottomMargin)
    main.Position = UDim2.new(pos.X.Scale, x, pos.Y.Scale, y)
end)

lastViewport = getViewportSize()
RunService.Heartbeat:Connect(function()
    local viewport = getViewportSize()
    if viewport ~= lastViewport then
        lastViewport = viewport
        if minimized then
            main.Position = getBottomRightPosition(46)
        else
            applyResponsiveSize(false)
        end
    end
end)
