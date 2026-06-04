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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local LogService = game:GetService("LogService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
local DEFAULT_PLS_DONATE_PLACE_ID = 8737602449
local VC_PLS_DONATE_PLACE_ID = 8943844393
local THIRD_PLS_DONATE_PLACE_ID = 84830718490377

local DEFAULT_AUTOEXEC_URL = "https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_dono_custom_gui.lua"
if type(SharedEnv.PLS_DONO_AUTOEXEC_URL) ~= "string" or SharedEnv.PLS_DONO_AUTOEXEC_URL == "" then
    SharedEnv.PLS_DONO_AUTOEXEC_URL = DEFAULT_AUTOEXEC_URL
end
if type(SharedEnv.PLS_DONO_AUTOEXEC_SOURCE) ~= "string" or SharedEnv.PLS_DONO_AUTOEXEC_SOURCE == "" then
    SharedEnv.PLS_DONO_AUTOEXEC_SOURCE = "loadstring(game:HttpGet('" .. SharedEnv.PLS_DONO_AUTOEXEC_URL .. "'))()"
end

local TextChatService = game:GetService("TextChatService")
local notificationTimestamps = {}
local avatarThumbnailCache = {}
local recentDonationLogs = {}
-- removed nearest-player info factor
local observedDonationChatChannels = {}

local function notify(title, text, duration, dedupeKey, cooldown)
    gui.Parent = GuiParent
    local normalized = normalizePlayerText(value)
    if normalized == "" then
        return false
    end

    local localName = normalizePlayerText(LocalPlayer.Name)
    local localDisplayName = normalizePlayerText(LocalPlayer.DisplayName)
    return normalized == localName or normalized == localDisplayName
end

local function resolvePlayerInfoFromText(value)
    local normalized = normalizePlayerText(value)
    if normalized == "" then
        return nil
    end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and normalizePlayerText(pl.Name) == normalized then
            return {
                name = tostring(pl.Name or "Unknown"),
                displayName = tostring(pl.DisplayName or pl.Name or "Unknown"),
                userId = tonumber(pl.UserId) or 0,
            }
        end
    end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and normalizePlayerText(pl.DisplayName) == normalized then
            return {
                name = tostring(pl.Name or "Unknown"),
                displayName = tostring(pl.DisplayName or pl.Name or "Unknown"),
                userId = tonumber(pl.UserId) or 0,
            }
        end
    end

    return {
        name = trimText(value),
        displayName = trimText(value),
        userId = 0,
    }
end

local function pruneRecentDonationLogs(now)
    now = tonumber(now) or tick()
    for index = #recentDonationLogs, 1, -1 do
        local entry = recentDonationLogs[index]
        if not entry or (now - (tonumber(entry.time) or 0)) > 15 then
            table.remove(recentDonationLogs, index)
        end
    end
end

local function recordDonationEvent(donorText, amountValue, recipientText)
    donorText = trimText(donorText)
    recipientText = trimText(recipientText):gsub("[!%.:,;]+$", "")
    local amount = tonumber(amountValue) or 0
    if donorText == "" or recipientText == "" or amount <= 0 then
        return
    end

    if not textMatchesLocalPlayer(recipientText) then
        return
    end

    local now = tick()
    lastDonationTick = now
    pruneRecentDonationLogs(now)
    local normalizedDonor = normalizePlayerText(donorText)
    for _, entry in ipairs(recentDonationLogs) do
        local entryDonor = entry and entry.donorInfo and entry.donorInfo.name or ""
        if entry
            and tonumber(entry.amount) == amount
            and normalizePlayerText(entryDonor) == normalizedDonor
            and (now - (tonumber(entry.time) or 0)) <= 2 then
            return
        end
    end

    table.insert(recentDonationLogs, {
        amount = amount,
        donorInfo = resolvePlayerInfoFromText(donorText),
        time = now,
    })

    while #recentDonationLogs > 20 do
        table.remove(recentDonationLogs, 1)
    end
end

local function parseDonationMessageText(message)
    local cleaned = tostring(message or "")
    if cleaned == "" then
        return nil
    end

    cleaned = cleaned:gsub("<[^>]->", "")
    cleaned = cleaned:gsub("%s+", " ")
    cleaned = trimText(cleaned)

    local donorText, amountText, recipientText = cleaned:match("^%s*(.-)%s+[Tt][Ii][Pp][Pp][Ee][Dd]%s+([%d,]+)%s+[Tt][Oo]%s+(.+)%s*$")
    if donorText and amountText and recipientText then
        return donorText, tonumber((amountText:gsub(",", ""))) or 0, recipientText
    end

    donorText, amountText, recipientText = cleaned:match("^%s*(.-)%s+[Dd][Oo][Nn][Aa][Tt][Ee][Dd]%s*[^%d]*([%d,]+)%s+[Tt][Oo]%s+(.+)%s*$")
    if donorText and amountText and recipientText then
        return donorText, tonumber((amountText:gsub(",", ""))) or 0, recipientText
    end

    return nil
end

-- helper text utilities (moved earlier to avoid nil calls during init)
-- helper definitions moved earlier; later duplicate removed

local function recordDonationLogMessage(message)
    local donorText, amount, recipientText = parseDonationMessageText(message)
    if donorText and amount and recipientText then
        recordDonationEvent(donorText, amount, recipientText)
    end
end

local function consumeRecentDonationDonorInfo(amount)
    pruneRecentDonationLogs()

    local targetAmount = tonumber(amount) or 0
    if targetAmount > 0 then
        for index = 1, #recentDonationLogs do
            local entry = recentDonationLogs[index]
            if entry and tonumber(entry.amount) == targetAmount then
                table.remove(recentDonationLogs, index)
                return entry.donorInfo
            end
        end
    end

    -- nearest-player donor heuristic removed; no fallback donor info
    return nil
end

pcall(function()
    LogService.MessageOut:Connect(function(message)
        recordDonationLogMessage(message)
    end)
end)

local function recordDonationChatMessage(message)
    local text = ""
    local prefixText = ""

    pcall(function()
        text = tostring(message.Text or "")
    end)
    pcall(function()
        prefixText = tostring(message.PrefixText or "")
    end)

    local donorText, amount, recipientText = parseDonationMessageText(text)
    if donorText and amount and recipientText then
        recordDonationEvent(donorText, amount, recipientText)
        return
    end

    if prefixText ~= "" then
        donorText, amount, recipientText = parseDonationMessageText(prefixText .. " " .. text)
        if donorText and amount and recipientText then
            recordDonationEvent(donorText, amount, recipientText)
        end
    end
end

local function watchDonationChatChannel(channel)
    if not channel or observedDonationChatChannels[channel] then
        return
    end

    local isTextChannel = false
    pcall(function()
        isTextChannel = channel:IsA("TextChannel")
    end)
    if not isTextChannel then
        return
    end

    observedDonationChatChannels[channel] = true
    pcall(function()
        channel.MessageReceived:Connect(function(message)
            recordDonationChatMessage(message)
        end)
    end)
end

pcall(function()
    local channels = TextChatService:FindFirstChild("TextChannels") or TextChatService:WaitForChild("TextChannels", 10)
    if not channels then
        return
    end

    for _, channel in ipairs(channels:GetChildren()) do
        watchDonationChatChannel(channel)
    end

    channels.ChildAdded:Connect(function(channel)
        watchDonationChatChannel(channel)
    end)
end)

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

    if type(SharedEnv.PLS_DONO_AUTOEXEC_SOURCE) == "string" and SharedEnv.PLS_DONO_AUTOEXEC_SOURCE ~= "" then
        return pcall(function()
            queueOnTeleport(SharedEnv.PLS_DONO_AUTOEXEC_SOURCE)
        end)
    elseif type(SharedEnv.PLS_DONO_AUTOEXEC_URL) == "string" and SharedEnv.PLS_DONO_AUTOEXEC_URL ~= "" then
        local source = "loadstring(game:HttpGet('" .. SharedEnv.PLS_DONO_AUTOEXEC_URL .. "'))()"
        return pcall(function()
            queueOnTeleport(source)
        end)
    end

    return false
end

local GuiParent = resolveGuiParent()
if not GuiParent then
    return
end

-- Only allow this script to run in the supported places
do
    local allowed = false
    local allowedIds = {DEFAULT_PLS_DONATE_PLACE_ID, VC_PLS_DONATE_PLACE_ID, THIRD_PLS_DONATE_PLACE_ID}
    for _, id in ipairs(allowedIds) do
        if tonumber(game.PlaceId) == tonumber(id) then
            allowed = true
            break
        end
    end
    if not allowed then
        pcall(function()
            StarterGui:SetCore("SendNotification", {Title = "PLS DONATE", Text = "This script only runs in specific places.", Duration = 6})
        end)
        return
    end
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

    autoThanks = true,
    thanksDelay = 3,
    thanksMessage = {"Thank you", "Thankss!", "ty"},
    -- begging feature removed

    webhookToggle = false,
    webhookBox = "",

    -- preserve regular server hopping defaults
    minPlayerCount = 24,
    maxPlayerCount = 26,
    AnonymousMode = false,
    moveMode = "teleport", -- options: "teleport", "walk"
    -- helicopter and spin features removed
}

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

    if data.textColor == nil and data.hexBox ~= nil then
        data.textColor = data.hexBox
    end

    data.hexBox = nil
    return data
end

local function trimText(s)
    s = tostring(s or "")
    local ok, out = pcall(function()
        return s:match("^%s*(.-)%s*$") or ""
    end)
    return ok and out or s
end

local function normalizePlayerText(s)
    local t = trimText(s):lower()
    t = t:gsub("%s+", "")
    t = t:gsub("[^%w]", "")
    return t
end

local function textMatchesLocalPlayer(text)
    local n = normalizePlayerText(text)
    if n == "" then
        return false
    end
    return n == normalizePlayerText(LocalPlayer.Name) or n == normalizePlayerText(LocalPlayer.DisplayName)
end

local function normalizeMessageList(value, fallback)
    local out = {}
    if type(value) == "string" then
        for line in value:gmatch("[^\r\n]+") do
            local t = trimText(line)
            if t ~= "" then table.insert(out, t) end
        end
    elseif type(value) == "table" then
        for _, v in ipairs(value) do
            local t = trimText(v)
            if t ~= "" then table.insert(out, t) end
        end
    end

    if #out == 0 then
        if type(fallback) == "table" then
            for _, v in ipairs(fallback) do table.insert(out, tostring(v)) end
        elseif type(fallback) == "string" and trimText(fallback) ~= "" then
            table.insert(out, trimText(fallback))
        end
    end

    return out
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
settings.thanksMessage = normalizeMessageList(settings.thanksMessage, defaults.thanksMessage)
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

local hopCooldownSeconds = 1
local lastHopTick = 0
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

-- anti-bot and mod-evader logic removed per user request

local function sendChatMessage(message)
    local text = tostring(message or "")
    if text == "" then
        return
    end

    local ok = pcall(function()
        local channels = TextChatService:FindFirstChild("TextChannels")
        local general = channels and channels:FindFirstChild("RBXGeneral")
        if general and general.SendAsync then
            general:SendAsync(text)
            return
        end
        Players:Chat(text)
    end)

    if not ok then
        pcall(function()
            Players:Chat(text)
        end)
    end
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


-- nearest-player lookup removed

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

-- mod detection removed

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
        return
    end

    local url = tostring(settings.webhookBox or ""):match("%S+")
    if not url or url == "" then
        return
    end

    local received = math.max(0, tonumber(amount) or 0)
    local taxed = math.floor((tonumber(amount) or 0) * 0.6)
    local donorLabel = "check roblox.com/transactions"
    postWebhookJson(url, {
        username = "PLS DONATE",
        content = "Donation received - check roblox.com/transactions",
        embeds = {{
            color = 0x1E90FF,
            title = "Donation Stats",
            fields = {
                {name = "Donor", value = donorLabel, inline = false},
                {name = "Robux Received", value = string.format("%d", received), inline = true},
                {name = "After Tax", value = string.format("%d", taxed), inline = true},
            },
        }},
    })
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
    local filledColor = namedColors[getGoalBarColorName()] or namedColors.blue
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
    if UI_VARIANT == "simple" then
        return false, "simple-variant"
    end
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
        buttonColor = Color3.new(98 / 255, 1, 0),
        buttonHoverColor = Color3.new(98 / 255, 1, 0),
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
        return VC_PLS_DONATE_PLACE_ID
    end
    return tonumber(game.PlaceId) or DEFAULT_PLS_DONATE_PLACE_ID
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
                    -- try servers in random order, attempt multiple quick tries for persistence
                    local indices = {}
                    for i = 1, #servers do table.insert(indices, i) end
                    for attempt = 1, math.min(8, #indices) do
                        local idx = table.remove(indices, math.random(1, #indices))
                        local selectedServer = servers[idx]
                        local teleported = false
                        local ok, err = pcall(function()
                            TeleportService:TeleportToPlaceInstance(placeId, selectedServer.id, LocalPlayer)
                        end)
                        if ok then
                            teleported = true
                        else
                            local errStr = tostring(err or "")
                            if not (errStr:find("772") or errStr:lower():find("server is full")) then
                                warn("Teleport failed:", errStr)
                            end
                        end
                        if teleported then
                            markPendingFarmHop(reason, placeId, selectedServer.id)
                            serverHopIsActive = false
                            return
                        end
                        task.wait(0.08)
                    end
                end
            end
            task.wait(0.15)
        end
    end)
    return true
end

requestServerHop = function(reason)
    local now = tick()
    -- allow manual hops to bypass cooldowns for responsiveness
    if tostring(reason or "") ~= "manual-button" then
        if now - lastHopTick < hopCooldownSeconds then
            return false
        end
        if now - lastDonationTick < donationHopBlockSeconds then
            return false
        end
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

    local targetPos = targetCF.Position

    local originalCanCollide = {}
    local function setCharacterCollisions(enabled)
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if enabled then
                    if originalCanCollide[part] ~= nil then
                        part.CanCollide = originalCanCollide[part]
                    end
                else
                    originalCanCollide[part] = part.CanCollide
                    part.CanCollide = false
                end
            end
        end
    end

    local jumpedFromSit = false
    local stateConn
    local function monitorSitting()
        if stateConn then
            stateConn:Disconnect()
            stateConn = nil
        end
        stateConn = humanoid.StateChanged:Connect(function(old, new)
            if new == Enum.HumanoidStateType.Seated then
                humanoid.Jump = true
                jumpedFromSit = true
            end
        end)
    end

    if tostring(settings.moveMode or "teleport") ~= "walk" then
        -- immediate teleport/facing (legacy)
        hrp.CFrame = targetCF
        task.delay(0.15, function()
            if hrp and hrp.Parent then
                hrp.CFrame = targetCF
            end
        end)
        return true, "teleport"
    end

    -- WALK mode: use pathfinding and disable collisions to avoid getting stuck
    setCharacterCollisions(false)
    monitorSitting()

    local pathOk, path = pcall(function()
        local p = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentMaxSlope = 45})
        p:ComputeAsync(hrp.Position, targetPos)
        return p
    end)

    if not pathOk or not path or path.Status ~= Enum.PathStatus.Success then
        -- fallback: teleport if path failed
        if stateConn then stateConn:Disconnect() end
        setCharacterCollisions(true)
        hrp.CFrame = targetCF
        return true, "teleport"
    end

    local waypoints = path:GetWaypoints()
    for _, wp in ipairs(waypoints) do
        if wp.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end
        humanoid:MoveTo(wp.Position)
        local reached = humanoid.MoveToFinished:Wait()
        if not reached then
            -- try short wait and continue; if repeatedly failing, break and teleport
            task.wait(0.4)
        end
        -- auto jump if became seated
        if jumpedFromSit then
            jumpedFromSit = false
            humanoid.Jump = true
        end
    end

    if stateConn then stateConn:Disconnect() end
    setCharacterCollisions(true)
    return true, "walk"
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

local UI_VARIANT = (tonumber(game.PlaceId) == tonumber(THIRD_PLS_DONATE_PLACE_ID)) and "simple" or "animosity"

local THEME
if UI_VARIANT == "simple" then
    THEME = {
        topBar = Color3.fromRGB(70, 70, 72),
        topBarText = Color3.fromRGB(240, 240, 240),
        panel = Color3.fromRGB(23, 23, 25),
        tabIdle = Color3.fromRGB(60, 60, 62),
        tabActive = Color3.fromRGB(88, 88, 90),
        section = Color3.fromRGB(18, 18, 20),
        control = Color3.fromRGB(36, 36, 38),
        controlText = Color3.fromRGB(230, 230, 230),
        subtleText = Color3.fromRGB(150, 150, 150),
        accent = Color3.fromRGB(120, 120, 120),
        stroke = Color3.fromRGB(50, 50, 52),
    }
else
    THEME = {
        topBar = Color3.fromRGB(28, 164, 52),
        topBarText = Color3.fromRGB(248, 255, 248),
        panel = Color3.fromRGB(23, 23, 25),
        tabIdle = Color3.fromRGB(72, 72, 76),
        tabActive = Color3.fromRGB(96, 96, 102),
        section = Color3.fromRGB(18, 18, 20),
        control = Color3.fromRGB(31, 31, 34),
        controlText = Color3.fromRGB(238, 238, 238),
        subtleText = Color3.fromRGB(181, 191, 181),
        accent = Color3.fromRGB(57, 196, 76),
        stroke = Color3.fromRGB(66, 66, 71),
    }
end

local SHELL_CORNER_RADIUS = 8
local CONTROL_CORNER_RADIUS = 6
local GLOW_COLOR, SUBTLE_GLOW_COLOR, GLOW_TRANSPARENCY, SUBTLE_GLOW_TRANSPARENCY
if UI_VARIANT == "simple" then
    GLOW_COLOR = Color3.fromRGB(220, 220, 220)
    SUBTLE_GLOW_COLOR = Color3.fromRGB(160, 160, 160)
    GLOW_TRANSPARENCY = 0.95
    SUBTLE_GLOW_TRANSPARENCY = 0.97
else
    GLOW_COLOR = Color3.fromRGB(168, 255, 183)
    SUBTLE_GLOW_COLOR = Color3.fromRGB(96, 180, 108)
    GLOW_TRANSPARENCY = 0.84
    SUBTLE_GLOW_TRANSPARENCY = 0.9
end

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

-- Loading overlay to delay UI appearance after exec/teleport
local loadingOverlay = Instance.new("Frame")
loadingOverlay.Name = "LoadingOverlay"
loadingOverlay.Size = UDim2.new(1, 0, 1, 0)
loadingOverlay.Position = UDim2.new(0, 0, 0, 0)
loadingOverlay.BackgroundColor3 = THEME.panel
loadingOverlay.BackgroundTransparency = 1
loadingOverlay.BorderSizePixel = 0
loadingOverlay.Parent = main

local loadLabel = Instance.new("TextLabel")
loadLabel.Size = UDim2.new(1, -20, 0, 40)
loadLabel.Position = UDim2.new(0, 10, 0, (TOP_BAR_HEIGHT / 2) - 10)
loadLabel.BackgroundTransparency = 1
loadLabel.Font = Enum.Font.GothamBold
loadLabel.TextSize = 16
loadLabel.TextColor3 = THEME.topBarText
loadLabel.Text = "loading"
loadLabel.TextXAlignment = Enum.TextXAlignment.Center
loadLabel.TextTransparency = 1
loadLabel.Parent = loadingOverlay

local loadingActive = true
task.spawn(function()
    -- initial delay (wait up to 2s for title to be created), then fade in
    local waited = 0
    while waited < 2 and not title do
        task.wait(0.05)
        waited = waited + 0.05
    end
    task.wait(math.max(0, 2 - waited))
    pcall(function()
        if title and originalTitleText then
            title.Text = "loading"
        end
        local tween = TweenService:Create(loadingOverlay, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {BackgroundTransparency = 0})
        tween:Play()
        TweenService:Create(loadLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
    end)

    local dots = 0
    local start = tick()
    -- title pulsing tween
    task.spawn(function()
        while loadingActive do
            local ok, shouldBreak = pcall(function()
                if title then
                    local t1 = TweenService:Create(title, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0.7})
                    local t2 = TweenService:Create(title, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0})
                    t1:Play(); t1.Completed:Wait()
                    if not loadingActive then return true end
                    t2:Play(); t2.Completed:Wait()
                else
                    task.wait(0.8)
                end
                return false
            end)
            if ok and shouldBreak then break end
        end
    end)

    while loadingActive do
        dots = dots % 3 + 1
        loadLabel.Text = "loading" .. string.rep(".", dots)
        task.wait(0.45)
    end
    -- fade out will be handled by hideLoadingOverlay
end)

local function hideLoadingOverlay()
    if loadingOverlay and loadingOverlay.Parent then
        loadingActive = false
        pcall(function()
            local outTween = TweenService:Create(loadingOverlay, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
            local textOut = TweenService:Create(loadLabel, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {TextTransparency = 1})
            outTween:Play(); textOut:Play()
            outTween.Completed:Wait()
            if title and originalTitleText then
                title.Text = originalTitleText
            end
            loadingOverlay:Destroy()
        end)
    end
end

-- auto-hide after short delay if not already hidden
task.spawn(function()
    task.wait(20)
    if loadingOverlay and loadingOverlay.Parent then
        hideLoadingOverlay()
    end
end)

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

local title, originalTitleText

do
    createCorner(topBar, SHELL_CORNER_RADIUS)

    local topGradient = Instance.new("UIGradient")
    topGradient.Rotation = 0
    topGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.topBar),
        ColorSequenceKeypoint.new(0.5, THEME.topBar),
        ColorSequenceKeypoint.new(1, THEME.topBar),
    })
    topGradient.Parent = topBar
end

do
    title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -48, 0, 15)
    title.Position = UDim2.new(0, 32, 0, 2)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = THEME.topBarText
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 13
    title.Text = (UI_VARIANT == "simple") and "Simply Donate! 💵" or "PLS DONATE ANIMOSITY"
    originalTitleText = title.Text
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
if UI_VARIANT == "simple" then
    minimizeBtn.BackgroundColor3 = THEME.control
    minimizeBtn.TextColor3 = THEME.controlText
else
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(24, 132, 41)
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end
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
    miniStroke.Color = UI_VARIANT == "simple" and THEME.stroke or Color3.fromRGB(210, 255, 218)
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
    if UI_VARIANT == "simple" then
        minimizeBtn.BackgroundColor3 = THEME.control
        minimizeBtn.TextColor3 = THEME.controlText
    else
        minimizeBtn.BackgroundColor3 = state and Color3.fromRGB(21, 120, 38) or Color3.fromRGB(24, 132, 41)
        minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

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
    btn.Size = UDim2.new(0, 80, 0, 28)
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

-- helicopter and spin features removed


settingHandlers = {
    textUpdateToggle = function(value)
        if value and updateBoothTextNow then
            updateBoothTextNow()
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
    -- spin feature removed
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
local function onBoothClaimDetected(slot)
    if not slot then
        return
    end

    claimedBoothSlot = slot
    if handledClaimSlot == slot then
        return
    end

    handledClaimSlot = slot
    local ok, mode = moveToClaimedBooth(slot)
    if ok then
        pcall(hideLoadingOverlay)
    end

    -- Do NOT perform any booth text updates in the simple UI variant
    if UI_VARIANT ~= "simple" and settings.textUpdateToggle and settings.customBoothText and tostring(settings.customBoothText) ~= "" and updateBoothTextNow then
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

    -- compact '+' toggle removed from dropdowns; only title bar/minimize uses a small button

    local function onToggle()
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
    end

    btn.MouseButton1Click:Connect(onToggle)
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

    local function onToggleMsg()
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
    end
    btn.MouseButton1Click:Connect(onToggleMsg)
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
    local chatTab = createTab("Chat")
    local webhookTab = createTab("Webhook")
    local serverTab = createTab("Server Hop")

    local boothSection = createSection(boothTab, "Booth Settings")
    if UI_VARIANT ~= "simple" then
        createToggle(boothSection, "Text Update", "textUpdateToggle")
        createTextBox(boothSection, "Text Update Delay (S)", "textUpdateDelay", true)
        createTextBox(boothSection, "Text Color", "textColor", false)
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
        createInfoLabel(boothSection, "Text colors: green, blue, yellow, black, white, red, orange, pink, purple, gray/grey, or #RRGGBB")
        createDropdown(boothSection, "Font", "fontFace", boothFontOptions)
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
    end
    createDropdown(boothSection, "Standing Position", "standingPosition", {"Front", "Left", "Right", "Behind"})
    createDropdown(boothSection, "Move Mode", "moveMode", {"teleport", "walk"})

    -- test donation feature removed

    do
        local chatSection = createSection(chatTab, "Chat Settings")
        createToggle(chatSection, "Auto Thank You", "autoThanks")
        createTextBox(chatSection, "Thanks Delay (S)", "thanksDelay", true)
        createMessageDropdown(chatSection, "Thank You Messages", "thanksMessage", "Thank you")
        -- begging feature removed
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

-- spin feature removed

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

-- anti-bot periodic scanning removed

-- population-based hopping removed

-- mod-evader periodic loop removed

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

        -- spin and helicopter features removed

        sendDonationWebhook(delta, consumeRecentDonationDonorInfo(delta))

        if settings.autoThanks then
            task.spawn(function()
                task.wait(math.max(0, tonumber(settings.thanksDelay) or 0))
                sendChatMessage(pickRandomMessage(settings.thanksMessage, "Thank you"))
            end)
        end
    end)
end)

-- helicopter feature removed

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1.5, function()
        local character = LocalPlayer.Character
        if character then
            task.spawn(function()
            end)
        end
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

-- begging feature removed

-- spin feature removed

activateTab("Booth")

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
