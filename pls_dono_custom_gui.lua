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
local getNearestPlayerInfo
local observedDonationChatChannels = {}

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

local function normalizePlayerText(value)
    return trimText(value):gsub("^@", ""):lower()
end

local function textMatchesLocalPlayer(value)
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

    return getNearestPlayerInfo()
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
    autoBeg = true,
    begDelay = 300,
    begMessage = {"Grateful for any donation", "Please help me reach my goal!", "Anything helps, thank you!"},

    webhookToggle = false,
    webhookBox = "",
    webhookAfterSH = false,
    pingEveryone = false,
    pingAboveDono = 1000,

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
    helicopterEnabled = false,
    helicopterDieAfterLanding = false,
    testDonationAmount = 6,
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
    data.boothMoveMode = nil
    data.antiLag = nil
    data.catalogEmote = nil
    data.animSpeedSetting = nil
    data.animSpeedMultiplier = nil
    data.animSpeedPerRobux = nil
    data.render = nil
    data.helicopterShowPlatform = nil
    data.helicopterSpeed = nil
    data.spinSpeedMultiplier = nil
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

local restrictedAccessCacheUntil = 0
local restrictedAccessEnabled = false
local LOCK_ICON = utf8.char(0x1F512)

local function hasVerifiedRestrictedFeatureAccess()
    local now = tick()
    if now < restrictedAccessCacheUntil then
        return restrictedAccessEnabled
    end

    restrictedAccessCacheUntil = now + 3

    local chatUiShowsUnlock = false
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, guiObject in ipairs(playerGui:GetDescendants()) do
            if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
                local text = tostring(guiObject.Text or ""):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                if text == "unlock chat" or text:find("you can only view system messages here", 1, true) or text:find("get an age check to chat", 1, true) then
                    chatUiShowsUnlock = true
                    break
                end
            end
        end
    end

    if chatUiShowsUnlock then
        restrictedAccessEnabled = false
        return false
    end

    local chatOk, canChat = pcall(function()
        return TextChatService:CanUserChatAsync(LocalPlayer.UserId)
    end)
    if chatOk then
        restrictedAccessEnabled = canChat == true
        return restrictedAccessEnabled
    end

    -- Fall back to voice eligibility if Roblox doesn't answer the local
    -- text-chat permission check for this session.
    local voiceOk, voiceEnabled = pcall(function()
        return game:GetService("VoiceChatService"):IsVoiceEnabledForUserIdAsync(LocalPlayer.UserId)
    end)

    restrictedAccessEnabled = voiceOk and voiceEnabled == true
    return restrictedAccessEnabled
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
settings.begMessage = normalizeMessageList(settings.begMessage, defaults.begMessage)
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
local hopCooldownSeconds = 4
local lastHopTick = 0
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

local function sendChatMessage(message)
    local text = tostring(message or "")
    if text == "" then
        return
    end

    if not hasVerifiedRestrictedFeatureAccess() then
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

local function notifyWebhookAfterHop(reason)
    if not settings.webhookAfterSH then
        return
    end

    local url = tostring(settings.webhookBox or ""):match("%S+")
    if not url or url == "" then
        notify("Webhook", "Webhook After Serverhop is on, but no webhook URL is set.", 4, "serverhop-webhook-missing-url", 10)
        return
    end

    local display = tostring(LocalPlayer.DisplayName or LocalPlayer.Name or "Unknown")
    local user = tostring(LocalPlayer.Name or "Unknown")
    local hopReason = trimText(reason)
    local msg
    if display ~= user then
        msg = ("%s (@%s) serverhopped"):format(display, user)
    else
        msg = ("@%s serverhopped"):format(user)
    end
    if hopReason ~= "" then
        msg = ("%s [%s]"):format(msg, hopReason)
    end

    local sent = postWebhookJson(url, {content = msg})
    if sent then
        notify("Webhook", "Server hop webhook sent.", 3, "serverhop-webhook-sent", 3)
    else
        notify("Webhook", "Server hop webhook failed to send.", 4, "serverhop-webhook-failed", 6)
    end
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
        return
    end

    local url = tostring(settings.webhookBox or ""):match("%S+")
    if not url or url == "" then
        return
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
    postWebhookJson(url, {
        username = "PLS DONATE",
        content = ("Donation received from %s"):format(donorLabel),
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

    if settings.pingEveryone and received >= math.max(0, tonumber(settings.pingAboveDono) or 1000) then
        postWebhookJson(url, {content = "@everyone"})
    end
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
    if hasVerifiedRestrictedFeatureAccess() and settings.vcServerHopToggle then
        return 8943844393
    else
        return 8737602449
    end
end

serverHopNow = function(reason)
    local placeId = choosePlaceId()
    local req = performHttpRequest({
        Url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"):format(placeId),
        Method = "GET"
    })
    
    if not req or not req.Body then
        notify("Server Hop", "Failed to fetch servers.", 4, "server-hop-fail", 5)
        return false
    end

    local ok, body = pcall(function()
        return HttpService:JSONDecode(req.Body)
    end)

    if not ok or not body or not body.data then
        notify("Server Hop", "Failed to parse servers.", 4, "server-hop-fail", 5)
        return false
    end

    local minPlayers = math.max(1, tonumber(settings.minPlayerCount) or 23)
    local maxPlayers = math.max(minPlayers, tonumber(settings.maxPlayerCount) or minPlayers)

    local servers = {}
    for _, server in ipairs(body.data) do
        local playing = tonumber(server.playing or 0) or 0
        if server.id ~= game.JobId and playing >= minPlayers and playing <= maxPlayers then
            table.insert(servers, server)
        end
    end

    if #servers == 0 then
        notify("Server Hop", "No different server found right now.", 4, "server-hop-fail", 5)
        return false
    end

    local selectedServer = servers[math.random(1, #servers)]
    local teleported = false
    pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, selectedServer.id, LocalPlayer)
        teleported = true
    end)

    if teleported then
        markPendingFarmHop(reason, placeId, selectedServer.id)
        notifyWebhookAfterHop(reason)
    end

    return teleported
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

    local function applyFacing()
        hrp.CFrame = targetCF
        task.delay(0.15, function()
            if hrp and hrp.Parent then
                hrp.CFrame = targetCF
            end
        end)
    end

    applyFacing()
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
    local existing = GuiParent:FindFirstChild("PlsDonoCustomGui")
    if existing then
        existing:Destroy()
    end
end

local UI_MODULE_FILE = "mattys_ui.lua"
local UI_SOURCE_URL = "https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/part%20of%20pls%20dono.lua"

local function loadUiSource()
    if type(isfile) == "function" and type(readfile) == "function" and isfile(UI_MODULE_FILE) then
        local ok, source = pcall(readfile, UI_MODULE_FILE)
        if ok and type(source) == "string" and source ~= "" then
            return source
        end
    end

    local ok, source = pcall(function()
        return game:HttpGet(UI_SOURCE_URL, true)
    end)
    if ok and type(source) == "string" and source ~= "" then
        return source
    end

    notify("UI Load Failed", "Unable to load UI source.", 6, "ui-load-fail")
    return nil
end

local function executeUiSource(source)
    if type(source) ~= "string" or source == "" then
        return nil
    end

    local chunk, err = loadstring(source)
    if not chunk then
        notify("UI Compile Failed", tostring(err), 8, "ui-compile-fail")
        return nil
    end

    local env = setmetatable({
        LocalPlayer = LocalPlayer,
        GuiParent = GuiParent,
        settings = settings,
        SharedEnv = SharedEnv,
        Players = Players,
        HttpService = HttpService,
        UserInputService = UserInputService,
        TeleportService = TeleportService,
        RunService = RunService,
        TweenService = TweenService,
        ReplicatedStorage = ReplicatedStorage,
        Workspace = Workspace,
        StarterGui = StarterGui,
        LogService = LogService,
        task = task,
        notify = notify,
        sendChatMessage = sendChatMessage,
        getCharacterHumanoidRoot = getCharacterHumanoidRoot,
        getViewportSize = getViewportSize,
        getBottomRightPosition = getBottomRightPosition,
        applyResponsiveSize = applyResponsiveSize,
        cloneRef = cloneRef,
        formatFarmDuration = formatFarmDuration,
        math = math,
        string = string,
        table = table,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        tostring = tostring,
        tonumber = tonumber,
        type = type,
        pcall = pcall,
        xpcall = xpcall,
        warn = warn,
        error = error,
    }, { __index = _G })

    if type(setfenv) == "function" then
        setfenv(chunk, env)
    else
        local previousGlobals = {}
        for key, value in pairs(env) do
            previousGlobals[key] = _G[key]
            _G[key] = value
        end
        local ok2, result = pcall(chunk)
        for key, value in pairs(previousGlobals) do
            _G[key] = value
        end

        if not ok2 then
            notify("UI Init Failed", tostring(result), 8, "ui-init-fail")
            return nil
        end
        return result
    end

    local ok2, result = pcall(chunk)
    if not ok2 then
        notify("UI Init Failed", tostring(result), 8, "ui-init-fail")
        return nil
    end

    return result
end

local source = loadUiSource()
local ui = executeUiSource(source)
