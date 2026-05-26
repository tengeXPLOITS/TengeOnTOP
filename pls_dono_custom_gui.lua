--[[
    PLS DONATE - Custom GUI Foundation
]]

repeat
    task.wait()
until game:IsLoaded()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
local DEFAULT_PLS_DONATE_PLACE_ID = 8737602449
local VC_PLS_DONATE_PLACE_ID = 8943844393

local DEFAULT_AUTOEXEC_URL = "https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_dono_custom_gui.lua"

local function buildAutoexecSource(url)
    local resolvedUrl = tostring(url or DEFAULT_AUTOEXEC_URL or "")
    if resolvedUrl == "" then
        resolvedUrl = DEFAULT_AUTOEXEC_URL
    end
    return "loadstring(game:HttpGet(\"" .. resolvedUrl .. "\"))()"
end

if type(SharedEnv.PLS_DONO_AUTOEXEC_URL) ~= "string" or SharedEnv.PLS_DONO_AUTOEXEC_URL == "" then
    SharedEnv.PLS_DONO_AUTOEXEC_URL = DEFAULT_AUTOEXEC_URL
end
SharedEnv.PLS_DONO_AUTOEXEC_SOURCE = buildAutoexecSource(SharedEnv.PLS_DONO_AUTOEXEC_URL)

local notificationTimestamps = {}

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

local function queueScriptOnTeleport()
    local queueOnTeleport = (syn and syn.queue_on_teleport)
        or queue_on_teleport
        or queueonteleport
        or (fluxus and fluxus.queue_on_teleport)
    if not queueOnTeleport then
        return false
    end

    local source = buildAutoexecSource(SharedEnv.PLS_DONO_AUTOEXEC_URL)
    SharedEnv.PLS_DONO_AUTOEXEC_SOURCE = source

    return pcall(function()
        queueOnTeleport(source)
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

local defaults = {
    textUpdateToggle = true,
    textUpdateDelay = 30,
    textColor = "#32CD32",
    goalBox = 5,
    customBoothText = "Please help me reach my goal! Goal: $G",
    goalBarHeaderText = "GOAL $G",
    goalBarColor = "blue",
    fontFace = "SciFi",
    standingPosition = "Front",
    boothPosition = 3,

    webhookToggle = false,
    webhookBox = "",

    autoThanksToggle = false,
    autoThanksPreset = "Custom",
    autoThanksMessage = "Thank you for donating!",

    boothMonitoringToggle = false,
    boothMonitorRadius = 10,

    serverHopToggle = true,
    serverHopDelay = 15,
    antiBotServers = false,
    antiBotThreshold = 17,
    antiBotInterval = 8,
    zeroDonatedBotThreshold = 16,
    modEvader = false,
    minPlayerCount = 23,
    maxPlayerCount = 24,
    AnonymousMode = false,
    vcServerHopToggle = false,
    testDonationAmount = 6,
}

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

    if data.textColor == nil and data.hexBox ~= nil then
        data.textColor = data.hexBox
    end

    local normalizedTextColor = tostring(data.textColor or ""):lower()
    if normalizedTextColor == "grey" or normalizedTextColor == "gray" or normalizedTextColor == "#7a7a7a" then
        data.textColor = "#32CD32"
    end

    local normalizedGoalBarColor = tostring(data.goalBarColor or ""):lower()
    if normalizedGoalBarColor == "grey" or normalizedGoalBarColor == "gray" then
        data.goalBarColor = "blue"
    end

    if data.autoThanksPreset == nil then
        data.autoThanksPreset = "Custom"
    end

    data.hexBox = nil
    return data
end

local function saveSettings()
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
    end)
end


local function loadSettings()
    settings = deepCopy(defaults)

    if not canUseFiles() then
        return
    end

    if not isfile(SETTINGS_FILE) then
        saveSettings()
        return
    end

    local readOk, content = pcall(function()
        return readfile(SETTINGS_FILE)
    end)

    if not readOk or type(content) ~= "string" or content == "" then
        saveSettings()
        return
    end

    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)

    if decodeOk and type(data) == "table" then
        settings = migrateLegacySettings(data)
        mergeDefaults(settings, defaults)
        saveSettings()
        return
    end

    if isfile(SETTINGS_BACKUP_FILE) then
        local backupOk, backupContent = pcall(function()
            return readfile(SETTINGS_BACKUP_FILE)
        end)
        if backupOk and type(backupContent) == "string" and backupContent ~= "" then
            local backupDecodeOk, backupData = pcall(function()
                return HttpService:JSONDecode(backupContent)
            end)
            if backupDecodeOk and type(backupData) == "table" then
                settings = migrateLegacySettings(backupData)
                mergeDefaults(settings, defaults)
                saveSettings()
                return
            end
        end
    end

    settings = deepCopy(defaults)
    saveSettings()
end

loadSettings()
saveSettings()
SharedEnv.plsdonoSettings = settings

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

local serverHopNow
local requestServerHop
local countZeroDonatedPlayers
local updateBoothTextNow

local flaggedBoothTexts = {
    "helicopter",
    "gifting",
    "5x",
    "multiply",
    "multiplying",
    "improving",
    "raising",
    "1R$=",
    "1R",
    "homeless bacon",
    
}

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

local antiBotLastScanCount = 0
local antiBotLastNotifyTick = 0
local antiBotLastNotifiedCount = -1
local antiBotPendingConfirmation = false
local antiBotNotifyCooldown = 30
local antiBotConfirmationDelay = 10
local hopCooldownSeconds = 1
local lastHopTick = 0
local nextBoothMonitorRun = 0
local lastAutoThanksMessage = ""
local boothReactionToken = 0
local serverHopIsActive = false
local hopTimerResetTick = tick()
local donatedSinceHopTimerReset = 0
local lastDonationTick = 0
local donationHopBlockSeconds = 3
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

local pendingFarmSummaryHopCount

local BOT_HOP_REASONS = {
    ["bot-detection"] = true,
    ["zero-donated-bot-server"] = true,
}

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

    if not isFresh or not landedOnExpectedServer or not changedServers or not shouldTrackFarmHop(pendingReason) then
        return nil
    end

    farmSessionStats.successfulHops += 1
    if BOT_HOP_REASONS[pendingReason] then
        farmSessionStats.botEvaded += 1
    end
    if pendingReason == "mod-detection" then
        farmSessionStats.modServers += 1
    end

    if farmSessionStats.successfulHops > 0
        and farmSessionStats.successfulHops % 100 == 0
        and farmSessionStats.lastSummaryHopCount < farmSessionStats.successfulHops then
        farmSessionStats.lastSummaryHopCount = farmSessionStats.successfulHops
        return farmSessionStats.successfulHops
    end

    return nil
end

pendingFarmSummaryHopCount = finalizeSuccessfulPendingFarmHop()

local function parseIdFromTemplate(tmpl)
    if not tmpl then
        return nil
    end
    local id = tostring(tmpl):match("(%d+)")
    return id and tonumber(id) or nil
end

local function isTextFlagged(txt)
    if txt == nil then
        return false
    end

    local norm = tostring(txt):lower()

    for _, keyword in ipairs(flaggedBoothTexts) do
        local plain = tostring(keyword):lower()
        if plain ~= "" and norm:find(plain, 1, true) then
            return true
        end
    end

    return false
end

local function hasNamedAncestor(desc, wantedName)
    local current = desc and desc.Parent
    local target = tostring(wantedName or ""):lower()
    while current do
        if tostring(current.Name or ""):lower() == target then
            return true
        end
        current = current.Parent
    end
    return false
end

local function isLikelyBoothSignLabel(label)
    if not label or not label:IsA("TextLabel") then
        return false
    end

    if hasNamedAncestor(label, "Details") then
        return false
    end

    local labelName = tostring(label.Name or ""):lower()
    if labelName:find("owner", 1, true) or labelName:find("raised", 1, true) or labelName:find("goal", 1, true) or labelName:find("donat", 1, true) then
        return false
    end

    return labelName:find("sign", 1, true) or labelName:find("text", 1, true) or labelName:find("message", 1, true)
end

local function getBoothSlotFromDescendant(desc)
    local current = desc
    for _ = 1, 12 do
        if not current then
            break
        end
        local slot = tonumber(tostring(current.Name):match("BoothUI(%d+)"))
        if slot then
            return slot
        end
        current = current.Parent
    end
    return nil
end

local function countBotLikeBooths()
    local boothLocation = getBoothLocation()
    local boothUiFolder = boothLocation and boothLocation:FindFirstChild("BoothUI")
    if not boothUiFolder then
        return 0
    end

    local flaggedOwners = {}
    local seenSlots = {}
    for _, obj in ipairs(boothUiFolder:GetDescendants()) do
        if isLikelyBoothSignLabel(obj) then
            local slot = getBoothSlotFromDescendant(obj)
            if slot and not seenSlots[slot] then
                local ownerName = nil
                local boothFrame = boothUiFolder:FindFirstChild("BoothUI" .. tostring(slot))
                if boothFrame and boothFrame:FindFirstChild("Details") and boothFrame.Details:FindFirstChild("Owner") then
                    ownerName = tostring(boothFrame.Details.Owner.Text or "")
                end

                local ownerLower = tostring(ownerName or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
                if ownerLower ~= "" and ownerLower ~= "unclaimed" then
                    local textVal = tostring(obj.Text or "")
                    if isTextFlagged(textVal) then
                        seenSlots[slot] = true
                        table.insert(flaggedOwners, {slot = slot, owner = ownerName})
                    end
                end
            end
        end
    end

    local uniqueSuspiciousSlots = {}
    for _, data in ipairs(flaggedOwners) do
        local ownerSuspicious = false
        local ownerLower = tostring(data.owner or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

        if ownerLower == "" or ownerLower == "unclaimed" then
            ownerSuspicious = true
        else
            local matchedPlayer = nil
            for _, pl in ipairs(Players:GetPlayers()) do
                local n = tostring(pl.Name or ""):lower()
                local d = tostring(pl.DisplayName or ""):lower()
                if n == ownerLower or d == ownerLower then
                    matchedPlayer = pl
                    break
                end
            end

            if not matchedPlayer then
                ownerSuspicious = true
            else
                local okAge, accAge = pcall(function()
                    return matchedPlayer.AccountAge
                end)
                if okAge and type(accAge) == "number" and accAge < 3 then
                    ownerSuspicious = true
                end
            end
        end

        if ownerSuspicious and data.slot then
            uniqueSuspiciousSlots[data.slot] = true
        end
    end

    local count = 0
    for _ in pairs(uniqueSuspiciousSlots) do
        count += 1
    end
    return count
end

local function runBotDetectionScan()
    local boothCount = countBotLikeBooths()
    local zeroCount = countZeroDonatedPlayers()
    local totalCount = boothCount + zeroCount
    antiBotLastScanCount = totalCount
    return {
        boothCount = boothCount,
        zeroCount = zeroCount,
        totalCount = totalCount,
    }
end

local function notifyBotScanResult(scan, manual)
    local count = type(scan) == "table" and tonumber(scan.totalCount) or tonumber(scan) or 0
    local boothCount = type(scan) == "table" and tonumber(scan.boothCount) or count
    local zeroCount = type(scan) == "table" and tonumber(scan.zeroCount) or 0
    local threshold = math.max(1, tonumber(settings.antiBotThreshold) or 6)
    if manual then
        if count > 0 then
            notify("Bot Scan", ("Bot total: %d | Booths: %d | Zero donated: %d"):format(count, boothCount, zeroCount), 5, nil, nil)
        else
            notify("Bot Scan", "No suspicious booths found.", 4, nil, nil)
        end
        antiBotLastNotifiedCount = count
        antiBotLastNotifyTick = tick()
        return
    end

    local now = tick()
    local crossedUp = antiBotLastNotifiedCount < threshold and count >= threshold
    local crossedDown = antiBotLastNotifiedCount >= threshold and count < threshold
    local changed = count ~= antiBotLastNotifiedCount

    if crossedUp then
            notify("Bot Detection", ("High bot signal (%d total: %d booths, %d zero donated). Confirming before hop."):format(count, boothCount, zeroCount), 5, "bot-cross-up", 10)
        antiBotLastNotifyTick = now
    elseif crossedDown then
        notify("Bot Detection", "Bot signal dropped below threshold.", 4, "bot-cross-down", 10)
        antiBotLastNotifyTick = now
    elseif changed and count > 0 and (now - antiBotLastNotifyTick) >= antiBotNotifyCooldown then
            notify("Bot Scan", ("Bot total: %d | Booths: %d | Zero donated: %d"):format(count, boothCount, zeroCount), 4, "bot-periodic", 20)
        antiBotLastNotifyTick = now
    end

    antiBotLastNotifiedCount = count
end

local function shouldHopForBots(scan)
    local boothCount = type(scan) == "table" and tonumber(scan.boothCount) or tonumber(scan) or 0
    local zeroCount = type(scan) == "table" and tonumber(scan.zeroCount) or 0
    local count = type(scan) == "table" and tonumber(scan.totalCount) or boothCount
    local threshold = math.max(1, tonumber(settings.antiBotThreshold) or 6)
    notifyBotScanResult(scan, false)

    if boothCount >= threshold then
        if not antiBotPendingConfirmation then
            antiBotPendingConfirmation = true
            task.spawn(function()
                task.wait(antiBotConfirmationDelay)
                local confirmScan = runBotDetectionScan()
                local confirmCount = tonumber(confirmScan.totalCount) or 0
                local confirmBoothCount = tonumber(confirmScan.boothCount) or 0
                notifyBotScanResult(confirmScan, false)
                if confirmBoothCount >= threshold and settings.antiBotServers then
                    notify("Bot Detection", ("Confirmed %d suspicious booths (%d total signals, %d zero donated). Hopping..."):format(confirmBoothCount, confirmCount, tonumber(confirmScan.zeroCount) or 0), 5, "bot-hop", 10)
                    requestServerHop("bot-detection")
                end
                antiBotPendingConfirmation = false
            end)
        end
        return false
    end
    antiBotPendingConfirmation = false
    return false
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

local function postWebhookJson(url, bodyTable)
    local payload = HttpService:JSONEncode(bodyTable)
    local sent = false
    pcall(function()
        local response = performHttpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload,
        })
        sent = response ~= nil or sent
    end)
    return sent
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

local function sendDonationWebhook()
    if not settings.webhookToggle then
        return
    end

    local url = tostring(settings.webhookBox or ""):match("%S+")
    if not url or url == "" then
        return
    end

    postWebhookJson(url, {
        content = "donation received. Check raised stat in-game, or check transactions/roblox.com 👀",
    })
end

local function getAutoThanksMessages()
    local raw = tostring(settings.autoThanksMessage or "")
    local messages = {}

    for line in raw:gmatch("[^\n]+") do
    end

    if #messages == 0 then
        table.insert(messages, "Thank you for donating!")
    end

    return messages
end

local function chooseAutoThanksMessage()
    local messages = getAutoThanksMessages()
    if #messages == 1 then
        return messages[1]
    end

    local candidate = messages[math.random(1, #messages)]
    local attempts = 0
    while candidate == lastAutoThanksMessage and attempts < 8 do
        candidate = messages[math.random(1, #messages)]
        attempts += 1
    end

    lastAutoThanksMessage = candidate
    return candidate
end

local function sendAutoThanksMessage()
    if not settings.autoThanksToggle then
        return false
    end

    local message = chooseAutoThanksMessage()
    local sent = false

    pcall(function()
        local channel = TextChatService and TextChatService.TextChannels and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel and channel.SendAsync then
            channel:SendAsync(message)
            sent = true
        end
    end)

    if sent then
        return true
    end

    pcall(function()
        local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        local sayMessageRequest = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
        if sayMessageRequest and sayMessageRequest.FireServer then
            sayMessageRequest:FireServer(message, "All")
            sent = true
        end
    end)

    return sent
end

local function resetHopTimer()
    hopTimerResetTick = tick()
    donatedSinceHopTimerReset = 0
end

local function markDonationForHopTimer(delta)
    hopTimerResetTick = tick()
    donatedSinceHopTimerReset += math.max(0, tonumber(delta) or 0)
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
    local goal = math.max(0, tonumber(settings.goalBox) or 0)
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
    local filledColor = namedColors[getGoalBarColorName()] or namedColors.grey
    return string.format(
        "<font color=\"%s\" size=\"17\">%s</font><font color=\"rgb(70,70,70)\" size=\"17\">%s</font>",
        color3ToRgbText(filledColor),
        string.rep("|", filledSegments),
        string.rep("|", emptySegments)
    )
end

countZeroDonatedPlayers = function()
    local count = 0
    for _, pl in ipairs(Players:GetPlayers()) do
        local ls = pl:FindFirstChild("leaderstats")
        local donatedObj = ls and ls:FindFirstChild("Donated")
        local donated = tonumber(donatedObj and donatedObj.Value) or 0
        if donated <= 0 then
            count += 1
        end
    end
    return count
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
    local headerText = escapeRichTextText(settings.goalBarHeaderText or "GOAL $G")

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

updateBoothTextNow = function()
    local text = buildBoothText()
    if text == "" then
        return false, "empty-text"
    end

    local boothLocation = getBoothLocation()
    local boothUiFolder = boothLocation and boothLocation:FindFirstChild("BoothUI")
    if boothUiFolder and not claimedBoothSlot then
        claimedBoothSlot = findOwnedBoothSlot(boothUiFolder)
    end

    local fontName = tostring(settings.fontFace or "SciFi")
    local chosenFont = Enum.Font[fontName] or Enum.Font.SciFi
    local payload = {
        text = text,
        textFont = chosenFont,
        richText = true,
        strokeColor = Color3.new(0, 0, 0),
        strokeOpacity = 0,
        textColor = hexToColor3(settings.textColor),
        buttonStrokeColor = Color3.new(0, 0, 0),
        buttonTextColor = Color3.new(1, 1, 1),
        buttonColor = Color3.fromRGB(92, 92, 98),
        buttonHoverColor = Color3.fromRGB(110, 110, 116),
        buttonLayout = "",
    }

    local applied = false

    -- old.lua-first path: SetCustomization on a validated remotes module
    if preferredRemoteModule then
        local ok = pcall(function()
            preferredRemoteModule.Event("SetCustomization"):FireServer(payload, "booth")
        end)
        if ok then
            applied = true
        end
    end

    if not applied then
        for _, remoteModule in ipairs(RemoteModules) do
            local ok = pcall(function()
                remoteModule.Event("SetCustomization"):FireServer(payload, "booth")
            end)
            if ok then
                preferredRemoteModule = remoteModule
                applied = true
                break
            end
        end
    end

    local remoteEventNames = {
        "SetBoothText",
        "UpdateBooth",
        "EditBooth",
        "ChangeBoothText",
    }

    if not applied then
        for _, remoteModule in ipairs(RemoteModules) do
            for _, eventName in ipairs(remoteEventNames) do
                local ok1, result1 = pcall(function()
                    return remoteModule.Event(eventName):InvokeServer(text)
                end)
                if ok1 and result1 == true then
                    applied = true
                    break
                end

                if claimedBoothSlot then
                    local ok2, result2 = pcall(function()
                        return remoteModule.Event(eventName):InvokeServer(claimedBoothSlot, text)
                    end)
                    if ok2 and result2 == true then
                        applied = true
                        break
                    end
                end
            end
            if applied then
                break
            end
        end
    end

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
    if settings.vcServerHopToggle then
        return 8943844393
    else
        return 8737602449
    end
end

serverHopNow = function(reason)
    if serverHopIsActive then
        return true
    end

    serverHopIsActive = true
    task.spawn(function()
        while true do
            local placeId = choosePlaceId()
            local minPlayers = tonumber(settings.minPlayerCount) or 23
            local maxPlayers = tonumber(settings.maxPlayerCount) or 24

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

            if body then
                local servers = {}
                for _, server in ipairs(body.data) do
                    local playing = tonumber(server.playing or 0) or 0
                    if server.id ~= game.JobId and playing >= minPlayers and playing <= maxPlayers then
                        table.insert(servers, server)
                    end
                end

                if #servers > 0 then
                    local selectedServer = servers[math.random(1, #servers)]
                    local teleported = false
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, selectedServer.id, LocalPlayer)
                        teleported = true
                    end)

                    if teleported then
                        markPendingFarmHop(reason, placeId, selectedServer.id)
                        serverHopIsActive = false
                        return
                    end
                end
            end

            task.wait(0.35)
        end
    end)
    return true
end

requestServerHop = function(reason)
    local now = tick()
    if now - lastHopTick < hopCooldownSeconds then
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

local function pathfindToPosition(targetPosition, walkSpeed, goalTolerance)
    local character, humanoid, root = getCharacterHumanoidRoot()
    if not humanoid or not root then
        return false, "missing-character"
    end

    local tolerance = tonumber(goalTolerance) or 2.5
    if (root.Position - targetPosition).Magnitude <= tolerance then
        return true, "already-there"
    end

    humanoid.WalkSpeed = tonumber(walkSpeed) or 6

    local path = PathfindingService:CreatePath({
        AgentRadius = 2.2,
        AgentHeight = 5,
        AgentCanJump = true,
    })

    local computeOk, computeStatus = pcall(function()
        return path:ComputeAsync(root.Position, targetPosition)
    end)

    if not computeOk or path.Status ~= Enum.PathStatus.Success then
        humanoid:MoveTo(targetPosition)
        return true, "fallback-move"
    end

    local waypoints = path:GetWaypoints()
    for _, waypoint in ipairs(waypoints) do
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        humanoid:MoveTo(waypoint.Position)
        local startedAt = tick()
        while tick() - startedAt < 2.4 do
            task.wait(0.05)
            if (root.Position - waypoint.Position).Magnitude <= 2.2 then
                break
            end
        end

        if (root.Position - targetPosition).Magnitude <= tolerance then
            return true, "arrived"
        end
    end

    humanoid:MoveTo(targetPosition)
    return true, "path-complete"
end

local function moveToClaimedBooth(slot)
    local targetCF, err = getClaimedBoothTargetCFrame(slot)
    if not targetCF then
        return false, err or "missing-booth-part"
    end

    return pathfindToPosition(targetCF.Position, 6, 2.2)
end

local function getBoothMonitoringTarget(slot)
    local boothPart = findBoothPartBySlot(slot)
    if not boothPart then
        return nil
    end

    local radius = math.clamp(math.floor(tonumber(settings.boothMonitorRadius) or 10), 9, 12)
    local angle = math.random() * math.pi * 2
    local offsetDistance = radius + (math.random() * 1.5)
    local targetPosition = boothPart.Position + Vector3.new(math.cos(angle) * offsetDistance, 0, math.sin(angle) * offsetDistance)
    targetPosition = Vector3.new(targetPosition.X, boothPart.Position.Y + 1.25, targetPosition.Z)
    return targetPosition
end

local function navigateToBoothMonitoringPoint(targetPosition)
    return pathfindToPosition(targetPosition, 6, 2.4)
end

local function ensureBoothMonitoringSlot()
    local boothLocation = getBoothLocation()
    local boothUiFolder = boothLocation and boothLocation:FindFirstChild("BoothUI")
    local ownedSlot = boothUiFolder and findOwnedBoothSlot(boothUiFolder)
    if ownedSlot then
        claimedBoothSlot = ownedSlot
        return ownedSlot
    end

    local claimed, info = claimBoothNow()
    if claimed then
        onBoothClaimDetected(info)
        return info
    end

    return nil
end

local function performBoothMonitoringCycle(slot)
    local targetPosition = getBoothMonitoringTarget(slot)
    if not targetPosition then
        return false, "missing-target"
    end

    return navigateToBoothMonitoringPoint(targetPosition)
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
    local existing = GuiParent:FindFirstChild("PlsDonoCustomGui")
    if existing then
        existing:Destroy()
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
    topBar = Color3.fromRGB(33, 33, 35),
    topBarText = Color3.fromRGB(246, 246, 248),
    panel = Color3.fromRGB(20, 20, 22),
    tabIdle = Color3.fromRGB(48, 48, 52),
    tabActive = Color3.fromRGB(66, 66, 72),
    section = Color3.fromRGB(28, 28, 31),
    control = Color3.fromRGB(39, 39, 44),
    controlText = Color3.fromRGB(236, 236, 240),
    subtleText = Color3.fromRGB(176, 176, 182),
    accent = Color3.fromRGB(108, 108, 116),
    stroke = Color3.fromRGB(72, 72, 78),
}

local SHELL_CORNER_RADIUS = 8
local CONTROL_CORNER_RADIUS = 6
local GLOW_COLOR = Color3.fromRGB(180, 180, 186)
local SUBTLE_GLOW_COLOR = Color3.fromRGB(118, 118, 126)
local GLOW_TRANSPARENCY = 0.82
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
    btn.Font = font or Enum.Font.GothamSemibold
    btn.TextSize = textSize or 11
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
end

local function styleTextBox(box, alignment, multiline)
    box.BackgroundColor3 = THEME.control
    box.TextColor3 = THEME.controlText
    box.PlaceholderColor3 = THEME.subtleText
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
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
    applyTextGlow(btn, GLOW_COLOR, 0.88)
    return btn
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 380, 0, 360)
main.Position = UDim2.fromOffset(0, 0)
main.BackgroundColor3 = THEME.panel
main.BorderSizePixel = 0
main.Parent = gui
main.Visible = true

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
    stroke.Color = THEME.stroke
    stroke.Thickness = 1
    stroke.Parent = main

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 34, 36)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(24, 24, 26)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 20)),
    })
    gradient.Parent = main
end

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, TOP_BAR_HEIGHT)
topBar.BackgroundColor3 = THEME.topBar
topBar.BorderSizePixel = 0
topBar.Parent = main

do
    createCorner(topBar, SHELL_CORNER_RADIUS)

    local topGradient = Instance.new("UIGradient")
    topGradient.Rotation = 0
    topGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(57, 57, 62)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(43, 43, 47)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 34, 38)),
    })
    topGradient.Parent = topBar
end

do
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -48, 0, 15)
    title.Position = UDim2.new(0, 32, 0, 2)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = THEME.topBarText
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 13
    title.Text = "Pls Donate Animosity- Humanized Version"
    title.Parent = topBar
    applyTextGlow(title, GLOW_COLOR, 0.78)

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(1, -48, 0, 11)
    subtitle.Position = UDim2.new(0, 32, 0, 18)
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = THEME.subtleText
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.Text = "developed by mattyB"
    subtitle.Parent = topBar
    applyTextGlow(subtitle, SUBTLE_GLOW_COLOR, SUBTLE_GLOW_TRANSPARENCY)
end

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "Minimize"
minimizeBtn.Size = UDim2.new(0, 18, 0, 18)
minimizeBtn.Position = UDim2.new(0, 8, 0.5, -9)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 98)
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 13
minimizeBtn.Text = "-"
minimizeBtn.AutoButtonColor = true
minimizeBtn.Parent = topBar
applyTextGlow(minimizeBtn, GLOW_COLOR, 0.78)

do
    createCorner(minimizeBtn, CONTROL_CORNER_RADIUS)

    local miniStroke = Instance.new("UIStroke")
    miniStroke.Thickness = 1
    miniStroke.Color = Color3.fromRGB(140, 140, 146)
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
tabHolder.Size = UDim2.new(1, -12, 0, 28)
tabHolder.Position = UDim2.new(0, 6, 0, 5)
tabHolder.BackgroundColor3 = THEME.section
tabHolder.BorderSizePixel = 0
tabHolder.ScrollBarThickness = 2
tabHolder.ScrollBarImageColor3 = THEME.accent
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
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.Parent = tabHolder

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, 4)
    tabPad.PaddingBottom = UDim.new(0, 4)
    tabPad.PaddingLeft = UDim.new(0, 6)
    tabPad.PaddingRight = UDim.new(0, 6)
    tabPad.Parent = tabHolder

    local tabUnderline = Instance.new("Frame")
    tabUnderline.Name = "TabUnderline"
    tabUnderline.Size = UDim2.new(1, -12, 0, 1)
    tabUnderline.Position = UDim2.new(0, 6, 0, 35)
    tabUnderline.BackgroundColor3 = THEME.stroke
    tabUnderline.BorderSizePixel = 0
    tabUnderline.Parent = body
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
    minimizeBtn.Text = state and "+" or "-"
    minimizeBtn.BackgroundColor3 = state and Color3.fromRGB(74, 74, 80) or Color3.fromRGB(90, 90, 98)

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

local function setTabVisualState(btn, active)
    if not btn then
        return
    end
    btn.BackgroundColor3 = active and THEME.tabActive or THEME.tabIdle
    btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 205, 210)
    local activeBar = btn:FindFirstChild("ActiveBar")
    if activeBar then
        activeBar.Visible = active
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
    btn.Size = UDim2.new(0, 130, 0, 28)
    btn.BackgroundColor3 = THEME.tabIdle
    btn.TextColor3 = Color3.fromRGB(205, 205, 210)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.Text = tostring(buttonText or name)
    btn.AutoButtonColor = false
    btn.Parent = tabHolder
    applyTextGlow(btn, GLOW_COLOR, 0.86)

    createCorner(btn, 8)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = THEME.stroke
    btnStroke.Parent = btn

    local activeBar = Instance.new("Frame")
    activeBar.Name = "ActiveBar"
    activeBar.Size = UDim2.new(1, 0, 0, 3)
    activeBar.Position = UDim2.new(0, 0, 1, -3)
    activeBar.BackgroundColor3 = THEME.accent
    activeBar.BorderSizePixel = 0
    activeBar.Visible = false
    activeBar.Parent = btn

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
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 12
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
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
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
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = THEME.controlText
    label.Text = text
    label.Parent = row
    applyTextGlow(label, GLOW_COLOR, 0.88)

    local function applyState()
        local enabled = settings[key] == true
        btn.Text = enabled and "x" or ""
        btn.BackgroundColor3 = enabled and THEME.accent or THEME.control
        btn.TextColor3 = enabled and Color3.fromRGB(19, 11, 21) or THEME.controlText
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

local function getCharacterHumanoidRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end


settingHandlers = {
    textUpdateToggle = function(value)
        if value and updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    boothMonitoringToggle = function(value)
        boothReactionToken += 1
        if value and claimedBoothSlot then
            handledClaimSlot = nil
            onBoothClaimDetected(claimedBoothSlot)
        end
    end,
    textColor = function(value)
        local normalized = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local lower = normalized:lower()
        local allowedNames = {
            green = true,
            blue = true,
            yellow = true,
            black = true,
            white = true,
            red = true,
            orange = true,
            pink = true,
            purple = true,
            gray = true,
            grey = true,
        }
        if not allowedNames[lower] and not normalized:match("^#%x%x%x%x%x%x$") then
            settings.textColor = defaults.textColor
            saveSettings()
            return
        end
        settings.textColor = allowedNames[lower] and lower or normalized:upper()
        saveSettings()
        if updateBoothTextNow then
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
        if updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    goalBox = function()
        if updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    goalBarHeaderText = function()
        saveSettings()
        if updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    fontFace = function(value)
        local fontName = tostring(value or defaults.fontFace)
        if not Enum.Font[fontName] then
            settings.fontFace = defaults.fontFace
            saveSettings()
            return
        end
        if updateBoothTextNow then
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
    boothMonitorRadius = function(value)
        local radiusValue = math.clamp(math.floor(tonumber(value) or tonumber(defaults.boothMonitorRadius) or 10), 9, 12)
        settings.boothMonitorRadius = radiusValue
        saveSettings()
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
    vcServerHopToggle = function(value)
        if value then
            serverHopNow("vc-server-hop-toggle")
        end
    end,
}

local handledClaimSlot
local revealedAfterClaim = false

local function scheduleBoothClaimReaction(slot)
    if not slot then
        return
    end

    boothReactionToken += 1
    local token = boothReactionToken
    local delaySeconds = math.random(10, 15)

    task.delay(delaySeconds, function()
        if token ~= boothReactionToken then
            return
        end

        if not settings.boothMonitoringToggle then
            return
        end

        if claimedBoothSlot ~= slot then
            return
        end

        handledClaimSlot = slot
        moveToClaimedBooth(slot)
    end)
end

local function onBoothClaimDetected(slot)
    if not slot then
        return
    end

    claimedBoothSlot = slot
    if handledClaimSlot == slot and not settings.boothMonitoringToggle then
        return
    end

    handledClaimSlot = slot

    if settings.boothMonitoringToggle then
        scheduleBoothClaimReaction(slot)
    else
        moveToClaimedBooth(slot)
    end

    if settings.textUpdateToggle and settings.customBoothText and tostring(settings.customBoothText) ~= "" and updateBoothTextNow then
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

                if settings.textUpdateToggle and tostring(settings[key]) ~= "" and updateBoothTextNow then
                    pcall(function()
                        updateBoothTextNow()
                    end)
                end
            end)
        end)
    end

    box.FocusLost:Connect(function()
        settings[key] = tostring(box.Text or "")
        if key == "autoThanksMessage" then
            settings.autoThanksPreset = "Custom"
            saveSettings()
            return
        end
        saveSettings()
        if settingHandlers[key] then
            pcall(settingHandlers[key], settings[key])
        end
    end)

    return box
end

local function createDropdown(parent, text, key, options, onSelect)
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
            if type(onSelect) == "function" then
                pcall(onSelect, settings[key])
            end
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
    local boothTab = createTab("Booth")
    local characterTab = createTab("Character Settings")
    local webhookTab = createTab("Webhook")
    local serverTab = createTab("Server Hop")

    local boothSection = createSection(boothTab, "Booth Settings")
    createToggle(boothSection, "Text Update", "textUpdateToggle")
    createTextBox(boothSection, "Text Update Delay (S)", "textUpdateDelay", true)
    createTextBox(boothSection, "Robux Goal", "goalBox", true)
    createDropdown(boothSection, "Goal Bar Color", "goalBarColor", {"green", "blue", "red", "orange", "purple"})
    local boothTextBox
    createInfoLabel(boothSection, "Goal Bar Header:")
    local goalBarHeaderBox = createPlainTextBox(boothSection, "GOAL $G", "goalBarHeaderText", 38, false)
    createInfoLabel(boothSection, "Use $G here if you want the current goal amount.")
    createButton(boothSection, "Paste Goal Bar", function()
        settings.goalBarHeaderText = tostring(goalBarHeaderBox.Text or settings.goalBarHeaderText or "GOAL $G")
        local nextText = buildGoalBarTemplate()
        if #nextText > 221 then
            notify("Goal Bar", "Goal bar template is too long for the booth.", 4, "goal-bar-limit", 1)
            return
        end
        settings.customBoothText = nextText
        saveSettings()
        local ok, mode = updateBoothTextNow()
        if ok then
            boothTextBox.Text = nextText
            notify("Goal Bar", "Goal bar pasted onto the booth.", 4, "goal-bar-ok", 1)
        elseif mode == "local-preview-only" then
            boothTextBox.Text = nextText
            notify("Goal Bar", "Preview updated, waiting for remote confirmation.", 4, "goal-bar-preview", 2)
        else
            notify("Goal Bar", "Could not paste the goal bar yet.", 4, "goal-bar-fail", 2)
        end
    end)
    createInfoLabel(boothSection, "Custom Booth Text:")
    boothTextBox = createPlainTextBox(boothSection, "Write the exact booth text here...", "customBoothText", 56, true)
    createInfoLabel(boothSection, "$C = current | $G = goal | $BAR = goal progress")
    createButton(boothSection, "Update", function()
        local nextText = tostring(boothTextBox.Text or "")
        if #nextText > 221 then
            boothTextBox.Text = "Character limit reached"
            notify("Booth Text", "Character limit reached.", 4, "booth-text-limit", 1)
            return
        end

        settings.customBoothText = nextText
        saveSettings()
        local ok, mode = updateBoothTextNow()
        if ok then
            notify("Booth Text", "Booth text updated.", 4, "booth-text-ok", 1)
        elseif mode == "local-preview-only" then
            notify("Booth Text", "Preview updated, waiting for remote confirmation.", 4, "booth-text-preview", 2)
        else
            notify("Booth Text", "Could not update booth text yet.", 4, "booth-text-fail", 2)
        end
    end)

    do
        local characterSection = createSection(characterTab, "Character Settings")
        createTextBox(characterSection, "Test $", "testDonationAmount", true)
        createButton(characterSection, "Test", function()
            local stat = getRaisedStatObject()
            local amount = math.max(1, tonumber(settings.testDonationAmount) or 6)
            if stat and type(stat.Value) == "number" then
                stat.Value += amount
                notify("Test Donation", ("Simulated +%d R$ donation."):format(amount), 3, "test-dono", 1)
            else
                notify("Test Donation", "Raised stat not found.", 3, "test-dono-missing", 1)
            end
        end)

        local boothMonitoringSection = createSection(characterTab, "Booth Monitoring")
        createToggle(boothMonitoringSection, "Enable Booth Monitoring", "boothMonitoringToggle")
        createTextBox(boothMonitoringSection, "Monitor Radius (9-12)", "boothMonitorRadius", true)
        createInfoLabel(boothMonitoringSection, "The bot will walk around your booth slowly and re-check every 30-70 seconds.")
        createToggle(boothMonitoringSection, "Auto Thanks", "autoThanksToggle")
        createInfoLabel(boothMonitoringSection, "Use one thank-you message per line. Blank lines are ignored.")
        createPlainTextBox(boothMonitoringSection, "Thank you for donating!\nThanks so much for the donation!", "autoThanksMessage", 90, true)
    end

    do
        local webhookSection = createSection(webhookTab, "Webhook Settings")
        createToggle(webhookSection, "Webhook Enabled", "webhookToggle")
        createTextBox(webhookSection, "Webhook URL", "webhookBox", false)
        -- Donation Notifier feature only - other webhook options removed per user request
    end

    do
        local serverSection = createSection(serverTab, "Serverhop Settings")
        createToggle(serverSection, "Auto Server Hop", "serverHopToggle")
        createTextBox(serverSection, "Server Hop Delay (Minutes)", "serverHopDelay", true)
        createTextBox(serverSection, "Min Players in Server", "minPlayerCount", true)
        createTextBox(serverSection, "Max Players in Server", "maxPlayerCount", true)
        createToggle(serverSection, "Anti Bot Booths [BETA]", "antiBotServers")
        createTextBox(serverSection, "Bot Booth Threshold", "antiBotThreshold", true)
        createTextBox(serverSection, "Bot Scan Interval (S)", "antiBotInterval", true)
        createTextBox(serverSection, "Zero Donated Bot Threshold", "zeroDonatedBotThreshold", true)
        createToggle(serverSection, "Mod Evader", "modEvader")
        createButton(serverSection, "Scan Bot Booths Now", function()
            local scan = runBotDetectionScan()
            notifyBotScanResult(scan, true)
        end)
        createButton(serverSection, "Server Hop Now", function()
            requestServerHop("manual-button")
        end)

        -- VC Server Hop
        createToggle(serverSection, "VC Server Hop (All Servers)", "vcServerHopToggle")
    end
end

buildSettingsTabs()

task.spawn(function()
    task.wait(2)
    local claimed, info = claimBoothNow()
    if claimed then
        onBoothClaimDetected(info)
    end
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
    while task.wait(1) do
        if not settings.boothMonitoringToggle then
            task.wait(0.1)
        else
            local boothLocation = getBoothLocation()
            local boothUiFolder = boothLocation and boothLocation:FindFirstChild("BoothUI")
            local ownedSlot = boothUiFolder and findOwnedBoothSlot(boothUiFolder)
            if not ownedSlot then
                claimedBoothSlot = nil
            else
                claimedBoothSlot = ownedSlot
                if tick() >= nextBoothMonitorRun then
                    nextBoothMonitorRun = tick() + math.random(30, 70)
                    task.spawn(function()
                        pcall(function()
                            performBoothMonitoringCycle(ownedSlot)
                        end)
                    end)
                end
            end
        end
    end
end)

task.spawn(function()
    local lastHopTick = 0
    while task.wait(1) do
        if settings.antiBotServers then
            local interval = math.max(2, tonumber(settings.antiBotInterval) or 8)
            task.wait(interval)

            local scan = runBotDetectionScan()
            local zeroThreshold = math.max(1, tonumber(settings.zeroDonatedBotThreshold) or 16)
            local boothThreshold = math.max(1, tonumber(settings.antiBotThreshold) or 6)
            local zeroCount = tonumber(scan.zeroCount) or 0
            if zeroCount > zeroThreshold and (tick() - lastHopTick) > 8 then
                lastHopTick = tick()
                notify("Bot Detection", ("Zero donated check tripped: %d > %d | Booths: %d | Total: %d. Hopping..."):format(zeroCount, zeroThreshold, tonumber(scan.boothCount) or 0, tonumber(scan.totalCount) or 0), 5, "zero-donated-hop", 10)
                requestServerHop("zero-donated-bot-server")
            elseif (tonumber(scan.boothCount) or 0) >= boothThreshold and (tick() - lastHopTick) > 8 then
                lastHopTick = tick()
                shouldHopForBots(scan)
            end
        end
    end
end)

task.spawn(function()
    local lastPopulationHopTick = 0
    while task.wait(1) do
        task.wait(9)
        local playerCount = #Players:GetPlayers()
        local threshold = 15
        if playerCount < threshold and (tick() - lastPopulationHopTick) > 10 then
            lastPopulationHopTick = tick()
            notify("Server Hop", ("Server has %d players (below %d). Hopping..."):format(playerCount, threshold), 5, "population-hop", 6)
            requestServerHop("population-hop")
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

task.spawn(function()
    local lastTextUpdate = 0
    while task.wait(1) do
        if settings.textUpdateToggle then
            local delaySeconds = math.max(3, tonumber(settings.textUpdateDelay) or 30)
            if tick() - lastTextUpdate >= delaySeconds then
                lastTextUpdate = tick()
                local ok = updateBoothTextNow()
                if not ok then
                    local boothLocation = getBoothLocation()
                    local boothUiFolder = boothLocation and boothLocation:FindFirstChild("BoothUI")
                    if boothUiFolder then
                        local owned = findOwnedBoothSlot(boothUiFolder)
                        if owned then
                            claimedBoothSlot = owned
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    local raisedObj = getRaisedStatObject()
    if not raisedObj then
        return
    end

    local lastRaised = tonumber(raisedObj.Value) or 0

    raisedObj.Changed:Connect(function()
        local current = tonumber(raisedObj.Value) or 0
        local delta = current - lastRaised
        if delta <= 0 then
            lastRaised = current
            return
        end

        lastRaised = current
        markDonationForHopTimer(delta)
        notify("Donation Received", "donation received. Check raised stat in-game, or check transactions/roblox.com 👀", 4, "donation-received", 5)
        sendDonationWebhook()
        sendAutoThanksMessage()
    end)
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1.5, function()
        if claimedBoothSlot then
            moveToClaimedBooth(claimedBoothSlot)
        end
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

activateTab("Character Settings")

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
