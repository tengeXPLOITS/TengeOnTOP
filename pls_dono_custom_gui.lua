--[[
    PLS DONATE - Custom GUI Foundation
]]

print("bipv's UI reworked - animosity layout")

repeat
    task.wait()
until game:IsLoaded()

if game.PlaceId ~= 8737602449 and game.PlaceId ~= 8943844393 then
    return
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local LogService = game:GetService("LogService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
local TITLE_CHARACTER_IMAGE_PATH = "C:/Users/HP/Downloads/noFilter.webp"

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
    spinSet = false,
    spinSpeedMultiplier = 1,
    helicopterEnabled = false,
    helicopterSpeed = 1,
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
local hopFileName = "PlsDonateServerHop-Temp"
local visitedServerIds = {}
local hopFileHour = os.date("!*t").hour
local hopRetryConnection
local hopRetryTask
local hopAttemptQueue = {}
local hopAttemptPlaceId
local hopAttemptActive = false

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
                    notify("Bot Detection", ("Confirmed %d suspicious booths (%d total signals, %d zero raised). Hopping..."):format(confirmBoothCount, confirmCount, tonumber(confirmScan.zeroCount) or 0), 5, "bot-hop", 10)
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

local function resolveDonorUserId(donorInfo)
    if type(donorInfo) == "table" then
        local directUserId = tonumber(donorInfo.userId) or 0
        if directUserId > 0 then
            return directUserId
        end
    end

    local donorName = tostring((type(donorInfo) == "table" and donorInfo.name) or donorInfo or "")
    local donorDisplay = tostring((type(donorInfo) == "table" and donorInfo.displayName) or donorName or "")
    local donorNameLower = donorName:lower()
    local donorDisplayLower = donorDisplay:lower()

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local playerName = tostring(pl.Name or ""):lower()
            local playerDisplay = tostring(pl.DisplayName or ""):lower()
            if (donorNameLower ~= "" and donorNameLower ~= "unknown" and playerName == donorNameLower)
                or (donorDisplayLower ~= "" and donorDisplayLower ~= "unknown" and playerDisplay == donorDisplayLower)
                or (donorDisplayLower ~= "" and donorDisplayLower ~= "unknown" and playerName == donorDisplayLower)
                or (donorNameLower ~= "" and donorNameLower ~= "unknown" and playerDisplay == donorNameLower) then
                return tonumber(pl.UserId) or 0
            end
        end
    end

    if donorName ~= "" and donorName ~= "Unknown" then
        local okByName, resolvedByName = pcall(function()
            return Players:GetUserIdFromNameAsync(donorName)
        end)
        if okByName and tonumber(resolvedByName) and tonumber(resolvedByName) > 0 then
            return tonumber(resolvedByName)
        end
    end

    return 0
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

local function getRobloxAvatarOutfitThumbnailUrl(userId, size)
    userId = tonumber(userId) or 0
    if userId <= 0 then
        return nil
    end

    local cacheKey = table.concat({"outfit", tostring(userId), tostring(size or "420x420")}, ":")
    if avatarThumbnailCache[cacheKey] then
        return avatarThumbnailCache[cacheKey]
    end

    local thumbSize = tostring(size or "420x420")
    local endpoint = ("https://thumbnails.roblox.com/v1/users/avatar?userIds=%d&size=%s&format=Png&isCircular=false"):format(
        userId,
        HttpService:UrlEncode(thumbSize)
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

local function resolveLocalImageAsset(path)
    local normalizedPath = tostring(path or ""):gsub("\\", "/")
    if normalizedPath == "" then
        return nil
    end

    local resolvers = {}
    if type(getcustomasset) == "function" then
        table.insert(resolvers, getcustomasset)
    end
    if type(getsynasset) == "function" then
        table.insert(resolvers, getsynasset)
    end
    if syn and type(syn.getcustomasset) == "function" then
        table.insert(resolvers, syn.getcustomasset)
    end

    for _, resolver in ipairs(resolvers) do
        if resolver then
            local ok, asset = pcall(resolver, normalizedPath)
            if ok and type(asset) == "string" and asset ~= "" then
                return asset
            end
        end
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

    local taxed = math.floor((tonumber(amount) or 0) * 0.6)
    local donorUserId = resolveDonorUserId(donorInfo)
    local donorAvatarUrl = getRobloxAvatarThumbnailUrl(donorUserId, "150x150", false)
    local donorOutfitUrl = getRobloxAvatarOutfitThumbnailUrl(donorUserId, "420x420")
    local localAvatarUrl = getRobloxAvatarThumbnailUrl(LocalPlayer.UserId, "150x150", false)
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
    local donorProfileUrl = donorUserId > 0 and ("https://www.roblox.com/users/%d/profile"):format(donorUserId) or nil
    local initialMessage = donorName ~= "Unknown"
        and ("Donation received from %s. Gathering info to show stats..."):format(donorLabel)
        or "Donation received. Gathering info to show stats..."

    postWebhookJson(url, {
        username = "PLS DONATE",
        avatar_url = donorAvatarUrl or localAvatarUrl,
        content = initialMessage,
    })

    task.spawn(function()
        local latestUserId = donorUserId
        local latestAvatarUrl = donorAvatarUrl
        local latestOutfitUrl = donorOutfitUrl

        if latestUserId <= 0 then
            for _ = 1, 4 do
                task.wait(1)
                latestUserId = resolveDonorUserId(donorInfo)
                if latestUserId > 0 then
                    break
                end
            end
        end

        if latestUserId > 0 then
            latestAvatarUrl = latestAvatarUrl or getRobloxAvatarThumbnailUrl(latestUserId, "150x150", false)
            latestOutfitUrl = latestOutfitUrl or getRobloxAvatarOutfitThumbnailUrl(latestUserId, "420x420")
        end

        local embed = {
            color = 0x1E90FF,
            title = "Donation Stats",
            author = {
                name = donorLabel,
                url = latestUserId > 0 and ("https://www.roblox.com/users/%d/profile"):format(latestUserId) or donorProfileUrl,
                icon_url = latestAvatarUrl or localAvatarUrl,
            },
            thumbnail = {
                url = latestOutfitUrl or latestAvatarUrl or localAvatarUrl,
            },
            fields = {
                {name = "Robux Received", value = string.format("%d", tonumber(amount) or 0), inline = true},
                {name = "After Tax", value = string.format("%d", taxed), inline = true},
            },
        }

        postWebhookJson(url, {
            username = "PLS DONATE",
            avatar_url = latestAvatarUrl or localAvatarUrl,
            embeds = {embed},
        })
    end)
end

local function notifyWebhookAfterHop()
    if not settings.webhookAfterSH then
        return
    end

    local url = tostring(settings.webhookBox or ""):match("%S+")
    if not url or url == "" then
        return
    end

    local display = tostring(LocalPlayer.DisplayName or LocalPlayer.Name)
    local user = tostring(LocalPlayer.Name or "")
    local msg
    if display ~= user then
        msg = display .. " (@" .. user .. ") serverhopped"
    else
        msg = "@" .. user .. " serverhopped"
    end

    postWebhookJson(url, {content = msg})
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

serverHopNow = function(targetPlaceId)
    local placeId = targetPlaceId or game.PlaceId
    local cursor = nil
    local candidates = {}
    for _ = 1, 3 do
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true%s"):format(
            tostring(placeId),
            cursor and ("&cursor=" .. HttpService:UrlEncode(cursor)) or ""
        )
        local body = httpGet(url)
        if not body or body == "" then
            break
        end

        local ok, data = pcall(function()
            return HttpService:JSONDecode(body)
        end)
        if not ok or type(data) ~= "table" or type(data.data) ~= "table" then
            break
        end

        for _, server in ipairs(data.data) do
            local id = server.id
            local playing = tonumber(server.playing or 0) or 0
            local maxPlayers = tonumber(server.maxPlayers or 0) or 0
            if id and id ~= game.JobId and maxPlayers > 0 and playing < maxPlayers and not hasVisited(id) then
                local minPlayers = math.max(1, tonumber(settings.minPlayerCount or 23) or 23)
                local maxPlayersCheck = math.max(minPlayers, tonumber(settings.maxPlayerCount or 24) or 24)
                if playing >= minPlayers and playing <= maxPlayersCheck then
                    table.insert(candidates, id)
                end
            end
        end

        cursor = data.nextPageCursor
        if not cursor or #candidates >= 8 then
            break
        end
    end

    if #candidates == 0 then
        notify("Server Hop", "No different server found right now.", 4, "server-hop-fail", 5)
        return false
    end

    for index = #candidates, 2, -1 do
        local swapIndex = math.random(1, index)
        candidates[index], candidates[swapIndex] = candidates[swapIndex], candidates[index]
    end

    hopAttemptPlaceId = placeId
    hopAttemptQueue = candidates
    hopAttemptActive = true

    local function markVisited(jobId)
        table.insert(visitedServerIds, jobId)
        if #visitedServerIds > 220 then
            table.remove(visitedServerIds, 1)
        end
        saveVisitedIds()
    end

    local function attemptNextHop()
        if not hopAttemptActive then
            return false
        end

        while #hopAttemptQueue > 0 do
            local targetJobId = table.remove(hopAttemptQueue, 1)
            if targetJobId and tostring(targetJobId) ~= tostring(game.JobId) then
                markVisited(targetJobId)
                notifyWebhookAfterHop()
                local ok = pcall(function()
                    TeleportService:TeleportToPlaceInstance(hopAttemptPlaceId, targetJobId, LocalPlayer)
                end)
                if ok then
                    return true
                end
            end
        end

        hopAttemptActive = false
        notify("Server Hop", "No different server found right now.", 4, "server-hop-fail", 5)
        return false
    end

    if hopRetryConnection then
        hopRetryConnection:Disconnect()
        hopRetryConnection = nil
    end

    hopRetryConnection = TeleportService.TeleportInitFailed:Connect(function(_, result)
        if not hopAttemptActive then
            return
        end

        if result == Enum.TeleportResult.GameFull or result == Enum.TeleportResult.Failure or result == Enum.TeleportResult.Flooded or result == Enum.TeleportResult.Unauthorized then
            task.delay(0.75, function()
                if hopAttemptActive then
                    attemptNextHop()
                end
            end)
        end
    end)

    if hopRetryTask and coroutine.status(hopRetryTask) ~= "dead" then
        task.cancel(hopRetryTask)
    end

    hopRetryTask = task.spawn(function()
        while hopAttemptActive and #hopAttemptQueue > 0 do
            local started = attemptNextHop()
            if not started then
                break
            end
            task.wait(1.5)
        end
    end)

    return true
end

requestServerHop = function(reason, targetPlaceId)
    local now = tick()
    if now - lastHopTick < hopCooldownSeconds then
        return false
    end
    lastHopTick = now
    return serverHopNow(targetPlaceId)
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

local function getBoothStandingOffset()
    local stand = tostring(settings.standingPosition or "Front")
    if stand == "Left" then
        return -6, 0
    elseif stand == "Right" then
        return 6, 0
    elseif stand == "Behind" then
        return 0, 6
    end
    return 0, -4
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

local function getClaimedBoothTargetCFrame(slot)
    local boothPart = findBoothPartBySlot(slot)
    if not boothPart then
        return nil, "missing-booth-part"
    end

    local sideOffset, forwardOffset = getBoothStandingOffset()
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
    local queueOnTeleport = (syn and syn.queue_on_teleport)
        or queue_on_teleport
        or queueonteleport
        or (fluxus and fluxus.queue_on_teleport)
    if queueOnTeleport then
        if type(SharedEnv.PLS_DONO_AUTOEXEC_SOURCE) == "string" and SharedEnv.PLS_DONO_AUTOEXEC_SOURCE ~= "" then
            pcall(function()
                queueOnTeleport(SharedEnv.PLS_DONO_AUTOEXEC_SOURCE)
            end)
        elseif type(SharedEnv.PLS_DONO_AUTOEXEC_URL) == "string" and SharedEnv.PLS_DONO_AUTOEXEC_URL ~= "" then
            local source = "loadstring(game:HttpGet('" .. SharedEnv.PLS_DONO_AUTOEXEC_URL .. "'))()"
            pcall(function()
                queueOnTeleport(source)
            end)
        end
    end
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
    topBar = Color3.fromRGB(31, 31, 36),
    topBarText = Color3.fromRGB(238, 238, 242),
    panel = Color3.fromRGB(23, 23, 28),
    tabIdle = Color3.fromRGB(37, 37, 42),
    tabActive = Color3.fromRGB(62, 62, 70),
    section = Color3.fromRGB(29, 29, 34),
    control = Color3.fromRGB(35, 35, 40),
    controlText = Color3.fromRGB(227, 227, 232),
    subtleText = Color3.fromRGB(156, 156, 164),
    accent = Color3.fromRGB(98, 98, 110),
    stroke = Color3.fromRGB(58, 58, 66),
}

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 680, 0, 420)
main.Position = UDim2.fromOffset(220, 120)
main.BackgroundColor3 = THEME.panel
main.BorderSizePixel = 0
main.Parent = gui
main.Visible = false

local expandedWidth = 680
local expandedHeight = 420

local function getViewportSize()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function applyResponsiveSize(centerOnApply)
    local viewport = getViewportSize()
    expandedWidth = math.clamp(math.floor(viewport.X - 30), 420, 680)
    expandedHeight = math.clamp(math.floor(viewport.Y - 50), 300, 420)

    if not UserInputService.TouchEnabled then
        expandedWidth = math.max(expandedWidth, 500)
        expandedHeight = math.max(expandedHeight, 330)
    end

    main.Size = UDim2.new(0, expandedWidth, 0, expandedHeight)

    if centerOnApply then
        local centeredX = math.floor((viewport.X - expandedWidth) * 0.5)
        local centeredY = math.floor((viewport.Y - expandedHeight) * 0.5)
        main.Position = UDim2.fromOffset(math.max(0, centeredX), math.max(0, centeredY))
    end
end

applyResponsiveSize(true)

do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 11)
    corner.Parent = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.stroke
    stroke.Thickness = 1
    stroke.Parent = main

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 40)),
        ColorSequenceKeypoint.new(0.52, Color3.fromRGB(26, 26, 31)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 22)),
    })
    gradient.Parent = main
end

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 46)
topBar.BackgroundColor3 = THEME.topBar
topBar.BorderSizePixel = 0
topBar.Parent = main

do
    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 11)
    topCorner.Parent = topBar

    local topGradient = Instance.new("UIGradient")
    topGradient.Rotation = 0
    topGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 45, 50)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(35, 35, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 28, 32)),
    })
    topGradient.Parent = topBar
end

do
    local titleImage = Instance.new("ImageLabel")
    titleImage.Name = "TitleArtwork"
    titleImage.BackgroundTransparency = 1
    titleImage.Size = UDim2.new(0, 28, 0, 28)
    titleImage.Position = UDim2.new(0, 10, 0.5, -14)
    titleImage.ScaleType = Enum.ScaleType.Fit
    titleImage.Parent = topBar

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -130, 0, 20)
    title.Position = UDim2.new(0, 46, 0, 5)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = THEME.topBarText
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.Text = "Pls Donate Animosity"
    title.Parent = topBar

    local subtitle = Instance.new("TextButton")
    subtitle.Name = "Subtitle"
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(1, -130, 0, 16)
    subtitle.Position = UDim2.new(0, 46, 0, 23)
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = THEME.subtleText
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 11
    subtitle.Text = "developed by @buriedinplainview"
    subtitle.Parent = topBar
    
    subtitle.MouseButton1Click:Connect(function()
        setclipboard("https://www.roblox.com/users/1230653127/profile")
        notify("Creator Profile", "Profile URL copied to clipboard!", 3, "creator-profile-copy", 1)
    end)
    
    subtitle.MouseEnter:Connect(function()
        subtitle.TextColor3 = Color3.fromRGB(98, 98, 110)
    end)
    
    subtitle.MouseLeave:Connect(function()
        subtitle.TextColor3 = THEME.subtleText
    end)
    
    subtitle.AutoButtonColor = false

    task.spawn(function()
        local creatorHeadshot = getRobloxAvatarThumbnailUrl(1230653127, "150x150", true)
        if creatorHeadshot then
            titleImage.Image = creatorHeadshot
        end
    end)
end

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "Minimize"
minimizeBtn.Size = UDim2.new(0, 26, 0, 20)
minimizeBtn.Position = UDim2.new(1, -33, 0.5, -10)
minimizeBtn.BackgroundColor3 = THEME.topBar
minimizeBtn.TextColor3 = THEME.topBarText
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 14
minimizeBtn.Text = "-"
minimizeBtn.AutoButtonColor = true
minimizeBtn.Parent = topBar

do
    local miniCorner = Instance.new("UICorner")
    miniCorner.CornerRadius = UDim.new(0, 5)
    miniCorner.Parent = minimizeBtn
end

local body = Instance.new("Frame")
body.Name = "Body"
body.Size = UDim2.new(1, 0, 1, -46)
body.Position = UDim2.new(0, 0, 0, 46)
body.BackgroundTransparency = 1
body.Parent = main

local tabHolder = Instance.new("ScrollingFrame")
tabHolder.Name = "Tabs"
tabHolder.Size = UDim2.new(0, 42, 1, -10)
tabHolder.Position = UDim2.new(0, 60, 0, 5)
tabHolder.BackgroundColor3 = THEME.section
tabHolder.BorderSizePixel = 0
tabHolder.ScrollBarThickness = 0
tabHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
tabHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
tabHolder.ScrollingDirection = Enum.ScrollingDirection.Y
tabHolder.Parent = body

do
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 8)
    tabCorner.Parent = tabHolder

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Thickness = 1
    tabStroke.Color = THEME.stroke
    tabStroke.Parent = tabHolder
end

do
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Vertical
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.Parent = tabHolder

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, 6)
    tabPad.PaddingBottom = UDim.new(0, 6)
    tabPad.Parent = tabHolder

    local tabUnderline = Instance.new("Frame")
    tabUnderline.Name = "TabUnderline"
    tabUnderline.Size = UDim2.new(0, 1, 1, -10)
    tabUnderline.Position = UDim2.new(0, 114, 0, 5)
    tabUnderline.BackgroundColor3 = THEME.accent
    tabUnderline.BorderSizePixel = 0
    tabUnderline.Parent = body
end

local pages = Instance.new("Frame")
pages.Name = "Pages"
pages.Size = UDim2.new(1, -120, 1, -64)
pages.Position = UDim2.new(0, 120, 0, 5)
pages.BackgroundTransparency = 1
pages.Parent = body

local userProfileFrame = Instance.new("Frame")
userProfileFrame.Name = "UserProfileFrame"
userProfileFrame.Size = UDim2.new(0, 50, 1, -10)
userProfileFrame.Position = UDim2.new(0, 5, 0, 5)
userProfileFrame.BackgroundColor3 = THEME.section
userProfileFrame.BorderSizePixel = 0
userProfileFrame.Parent = body

do
    local profileCorner = Instance.new("UICorner")
    profileCorner.CornerRadius = UDim.new(0, 8)
    profileCorner.Parent = userProfileFrame

    local profileStroke = Instance.new("UIStroke")
    profileStroke.Thickness = 1
    profileStroke.Color = THEME.stroke
    profileStroke.Parent = userProfileFrame

    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.BackgroundColor3 = THEME.control
    avatar.BorderSizePixel = 0
    avatar.Size = UDim2.new(0, 40, 0, 40)
    avatar.Position = UDim2.new(0.5, -20, 0, 5)
    avatar.Parent = userProfileFrame

    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(1, 0)
    avatarCorner.Parent = avatar

    local displayLabel = Instance.new("TextLabel")
    displayLabel.BackgroundTransparency = 1
    displayLabel.Size = UDim2.new(1, 0, 0, 16)
    displayLabel.Position = UDim2.new(0, 0, 0, 50)
    displayLabel.TextXAlignment = Enum.TextXAlignment.Center
    displayLabel.TextColor3 = THEME.controlText
    displayLabel.Font = Enum.Font.GothamSemibold
    displayLabel.TextSize = 10
    displayLabel.Text = tostring(LocalPlayer.DisplayName or LocalPlayer.Name or "Player")
    displayLabel.Parent = userProfileFrame

    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Size = UDim2.new(1, 0, 0, 14)
    usernameLabel.Position = UDim2.new(0, 0, 0, 66)
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.TextColor3 = THEME.subtleText
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextSize = 9
    usernameLabel.Text = "@" .. tostring(LocalPlayer.Name or "player")
    usernameLabel.Parent = userProfileFrame

    task.spawn(function()
        local headshot = getRobloxAvatarThumbnailUrl(LocalPlayer.UserId, "150x150", true)
        if headshot then
            avatar.Image = headshot
        end
    end)
end

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
    local MINIMIZE_TWEEN_TIME = 0.16
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

    local targetSize = state and UDim2.new(0, expandedWidth, 0, 46) or UDim2.new(0, expandedWidth, 0, expandedHeight)
    minimizeBtn.Text = state and "+" or "-"
    minimizeBtn.BackgroundColor3 = THEME.topBar

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

local function activateTab(name)
    for tabName, page in pairs(tabPages) do
        local btn = tabButtons[tabName]
        local isActive = tabName == name
        page.Visible = isActive
        if btn then
            btn.BackgroundColor3 = isActive and THEME.tabActive or THEME.tabIdle
            btn.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or THEME.controlText
        end
    end
    activeTab = name
end

local function createTab(name)
    local compactLabels = {
        Booth = "B",
        Main = "M",
        Chat = "C",
        Webhook = "W",
        Server = "S",
    }
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Size = UDim2.new(1, -8, 0, 34)
    btn.BackgroundColor3 = THEME.tabIdle
    btn.TextColor3 = THEME.controlText
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.Text = compactLabels[name] or name:sub(1, 1):upper()
    btn.Parent = tabHolder

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

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

    local pageCorner = Instance.new("UICorner")
    pageCorner.CornerRadius = UDim.new(0, 8)
    pageCorner.Parent = page

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

    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(0, 8)
    corner2.Parent = section

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

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

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

local currentHelicopterSpinTask = nil
local currentAstronautIdleTrack = nil
local pendingHelicopterRaisedAmount = 0

local function stopAstronautIdle()
    if currentAstronautIdleTrack then
        pcall(function()
            currentAstronautIdleTrack:Stop()
        end)
        pcall(function()
            currentAstronautIdleTrack:Destroy()
        end)
        currentAstronautIdleTrack = nil
    end
end

local function loadAstronautIdle()
    stopAstronautIdle()
    local pl = Players.LocalPlayer
    if not pl then
        return
    end
    local char = pl.Character
    if not char then
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    pcall(function()
        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            if track ~= currentAstronautIdleTrack then
                track:Stop()
            end
        end
    end)
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://10921034824"
    local ok, track = pcall(function()
        return animator:LoadAnimation(animation)
    end)
    animation:Destroy()
    if ok and track then
        currentAstronautIdleTrack = track
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = true
        pcall(function()
            track:Play()
        end)
    end
end

local function stopHelicopterSpin()
    pendingHelicopterRaisedAmount = 0
    if currentHelicopterSpinTask then
        pcall(function()
            task.cancel(currentHelicopterSpinTask)
        end)
        currentHelicopterSpinTask = nil
    end
    stopAstronautIdle()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").RootPart
        if root then
            local heliBody = root:FindFirstChild("HL1__HELI")
            if heliBody then
                pcall(function()
                    heliBody:Destroy()
                end)
            end
        end
    end
end

local function triggerLandingExplosion(humanoid)
    if not humanoid or not humanoid.Parent then
        return
    end

    pcall(function()
        humanoid.Health = 0
    end)
end

local currentIdleTask = nil

local function getHelicopterIdleAngularVelocity()
    local speedScale = math.max(0.5, tonumber(settings.helicopterSpeed) or 1)
    return math.max(2, 4 * speedScale)
end

local function stopHelicopterIdleTask()
    if currentIdleTask then
        pcall(function() task.cancel(currentIdleTask) end)
        currentIdleTask = nil
    end
end

local function startHelicopterIdleMode()
    if not settings.helicopterEnabled then
        return
    end

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not root then return end

    loadAstronautIdle()

    local heliBody = root:FindFirstChild("HL1__HELI")
    if not (heliBody and heliBody:IsA("BodyAngularVelocity")) then
        heliBody = Instance.new("BodyAngularVelocity")
        heliBody.Name = "HL1__HELI"
        heliBody.MaxTorque = Vector3.new(0, math.huge, 0)
        heliBody.Parent = root
    end

    local idleSpeed = getHelicopterIdleAngularVelocity()
    stopHelicopterIdleTask()

    -- Ramp BodyAngularVelocity from 0 up to idleSpeed faster than old.lua (2s vs 6s)
    heliBody.AngularVelocity = Vector3.new(0, 0, 0)
    currentIdleTask = task.spawn(function()
        -- Ramp up phase
        local rampDuration = 2
        local rampStart = tick()
        while tick() - rampStart < rampDuration and settings.helicopterEnabled and root.Parent do
            local t = math.clamp((tick() - rampStart) / rampDuration, 0, 1)
            local ramped = idleSpeed * (t * t) -- quad-in ramp
            if heliBody and heliBody.Parent then
                heliBody.AngularVelocity = Vector3.new(0, ramped, 0)
            end
            task.wait()
        end
        if heliBody and heliBody.Parent then
            heliBody.AngularVelocity = Vector3.new(0, idleSpeed, 0)
        end

        while settings.helicopterEnabled and root.Parent do
            if heliBody and heliBody.Parent then
                heliBody.AngularVelocity = Vector3.new(0, idleSpeed, 0)
            end
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
            task.wait(0.08)
        end
    end)

    pcall(function()
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end)
end

local function performHelicopterBurst(raisedAmount, spinSpeed, spinDuration)
    pendingHelicopterRaisedAmount += math.max(1, tonumber(raisedAmount) or 1)
    if currentHelicopterSpinTask then
        return
    end

    currentHelicopterSpinTask = task.spawn(function()
        local burstIndex = 0

        local function restoreIdleMode()
            if settings.helicopterEnabled and not currentHelicopterSpinTask then
                task.spawn(function()
                    task.wait(0.08)
                    local started = false
                    for _ = 1, 15 do
                        if not settings.helicopterEnabled or currentHelicopterSpinTask then
                            return
                        end

                        local currentChar = LocalPlayer.Character
                        local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
                        local currentRoot = currentHum and currentHum.RootPart
                        if currentRoot and currentRoot.Parent then
                            startHelicopterIdleMode()
                            started = true
                            break
                        end
                        task.wait(0.2)
                    end

                    if not started and settings.helicopterEnabled and not currentHelicopterSpinTask then
                        startHelicopterIdleMode()
                    end
                end)
            end
        end

        while pendingHelicopterRaisedAmount > 0 do
            burstIndex += 1
            local amount = math.max(1, tonumber(pendingHelicopterRaisedAmount) or 1)
            pendingHelicopterRaisedAmount = 0

            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = hum and hum.RootPart
            if not char or not hum or not root then
                break
            end

            local ok, err = pcall(function()
                loadAstronautIdle()

                local animateScript = char:FindFirstChild("Animate")
                local animatePrevEnabled = nil
                if animateScript and animateScript:IsA("LocalScript") then
                    animatePrevEnabled = animateScript.Enabled
                    animateScript.Enabled = false
                end

                local baseIdleSpeed = getHelicopterIdleAngularVelocity()
                local spinMultiplier = math.max(0, tonumber(settings.spinSpeedMultiplier) or 1)
                local donationSpinBoost = (amount / 3) * spinMultiplier
                local targetSpinSpeed = math.max(baseIdleSpeed, tonumber(spinSpeed) or baseIdleSpeed) + donationSpinBoost
                
                -- Improved height scaling for stability with large donations
                -- Uses logarithmic scaling to handle 1-10000 R$ smoothly
                local heightFactor = math.log(math.max(1, amount)) / math.log(100)
                local riseHeight = math.max(8, math.min(120, 15 + (heightFactor * 35)))
                
                local riseDuration = 6
                local fallDuration = 8
                local totalDuration = riseDuration + fallDuration

                stopHelicopterIdleTask()

                local heliBody = root:FindFirstChild("HL1__HELI")
                if not (heliBody and heliBody:IsA("BodyAngularVelocity")) then
                    heliBody = Instance.new("BodyAngularVelocity")
                    heliBody.Name = "HL1__HELI"
                    heliBody.MaxTorque = Vector3.new(0, math.huge, 0)
                    heliBody.AngularVelocity = Vector3.new(0, getHelicopterIdleAngularVelocity(), 0)
                    heliBody.Parent = root
                end

                if burstIndex == 1 then
                    sendChatMessage("Enabling engines...")
                else
                    sendChatMessage("Boosting flight...")
                end

                task.spawn(function()
                    local rampStart = tick()
                    local rampDuration = math.max(1.2, tonumber(spinDuration) or 1.8)
                    local fromSpeed = heliBody.AngularVelocity.Y
                    local toSpeed = math.max(baseIdleSpeed + 2, targetSpinSpeed)
                    while tick() - rampStart < rampDuration and heliBody and heliBody.Parent do
                        local t = math.clamp((tick() - rampStart) / rampDuration, 0, 1)
                        heliBody.AngularVelocity = Vector3.new(0, fromSpeed + (toSpeed - fromSpeed) * t, 0)
                        task.wait()
                    end
                    if heliBody and heliBody.Parent then
                        heliBody.AngularVelocity = Vector3.new(0, toSpeed, 0)
                    end
                end)

                if burstIndex == 1 then
                    task.wait(3)
                    sendChatMessage("TAKE OFF IN 3")
                    task.wait(1)
                    sendChatMessage("2")
                    task.wait(1)
                    sendChatMessage("1")
                    task.wait(1)
                else
                    task.wait(0.35)
                end

                local startPos = root.Position
                local startRot = root.CFrame - root.CFrame.Position
                local yaw = 0
                local currentSpinSpeed = targetSpinSpeed

                local existingHeli = root:FindFirstChild("HL1__HELI")
                if existingHeli and existingHeli:IsA("BodyAngularVelocity") then
                    yaw = existingHeli.AngularVelocity.Y * 0.016
                    existingHeli:Destroy()
                end

                local startTick = tick()
                while tick() - startTick < totalDuration and char.Parent and root.Parent do
                    local elapsed = tick() - startTick
                    local yOffset
                    local spinSpeedAtFrame = currentSpinSpeed

                    if elapsed < riseDuration then
                        -- Rise phase with quadratic easing
                        local p = math.clamp(elapsed / riseDuration, 0, 1)
                        yOffset = riseHeight * (p * p)
                    else
                        -- Fall phase with smooth deceleration
                        local p = math.clamp((elapsed - riseDuration) / fallDuration, 0, 1)
                        local inv = 1 - p
                        yOffset = riseHeight * (inv * inv)
                        
                        -- Smooth spin speed deceleration during landing
                        spinSpeedAtFrame = currentSpinSpeed * (inv * inv)
                    end

                    yaw += spinSpeedAtFrame
                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)

                    local targetPos = Vector3.new(startPos.X, startPos.Y + yOffset, startPos.Z)
                    root.CFrame = CFrame.new(targetPos) * (startRot * CFrame.Angles(0, yaw, 0))
                    task.wait()
                end

                if char.Parent and root.Parent then
                    root.CFrame = CFrame.new(startPos) * (startRot * CFrame.Angles(0, yaw, 0))
                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                end

                if animateScript and animateScript:IsA("LocalScript") and animatePrevEnabled ~= nil then
                    animateScript.Enabled = animatePrevEnabled
                end
            end)

            if not ok then
                warn("Helicopter burst failed:", err)
                pendingHelicopterRaisedAmount = 0
                break
            end
        end

        currentHelicopterSpinTask = nil

        local currentChar = LocalPlayer.Character
        local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
        if settings.helicopterDieAfterLanding and currentHum and currentHum.Parent then
            task.delay(0.15, function()
                triggerLandingExplosion(currentHum)
            end)
        else
            restoreIdleMode()
        end
    end)
end

local function performHelicopterSpin(spinDuration, spinSpeed)
    performHelicopterBurst(1, spinSpeed, spinDuration)
end

local function performHelicopterDonationSequence(raisedAmount)
    local speedScale = math.max(0.5, tonumber(settings.helicopterSpeed) or 1)
    local spinSpeed = 0.55 * speedScale
    performHelicopterBurst(raisedAmount, spinSpeed, 1.8)
end

local function getCharacterHumanoidRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

local function getSpinAngularVelocity()
    return 0.25 * math.max(0, tonumber(settings.spinSpeedMultiplier) or 1)
end

local function getSpinMover()
    local _, _, root = getCharacterHumanoidRoot()
    if not root then
        return nil
    end
    local existing = root:FindFirstChild("Spin")
    if existing and existing:IsA("BodyAngularVelocity") then
        return existing
    end
    return nil
end

local function applySpinState()
    local _, _, root = getCharacterHumanoidRoot()
    if not root then
        return
    end

    local existing = root:FindFirstChild("Spin")
    if settings.spinSet then
        if not (existing and existing:IsA("BodyAngularVelocity")) then
            existing = Instance.new("BodyAngularVelocity")
            existing.Name = "Spin"
            existing.MaxTorque = Vector3.new(0, math.huge, 0)
            existing.Parent = root
        end
        existing.AngularVelocity = Vector3.new(0, getSpinAngularVelocity(), 0)
    elseif existing and existing:IsA("BodyAngularVelocity") then
        existing:Destroy()
    end
end


settingHandlers = {
    helicopterEnabled = function(value)
        if value then
            startHelicopterIdleMode()
        else
            stopHelicopterIdleTask()
            stopHelicopterSpin()
            stopAstronautIdle()
        end
    end,
    helicopterSpeed = function(value)
        local parsed = math.max(0.5, tonumber(value) or 1)
        settings.helicopterSpeed = parsed
        if settings.helicopterEnabled and not currentHelicopterSpinTask then
            stopHelicopterIdleTask()
            startHelicopterIdleMode()
        end
    end,
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
    spinSet = function()
        applySpinState()
    end,
    spinSpeedMultiplier = function()
        local spin = getSpinMover()
        if spin then
            spin.AngularVelocity = Vector3.new(0, getSpinAngularVelocity(), 0)
        end
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
            requestServerHop("vc-hop", 8943844393)
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

    if settings.textUpdateToggle and settings.customBoothText and tostring(settings.customBoothText) ~= "" and updateBoothTextNow then
        task.delay(0.35, function()
            pcall(function()
                updateBoothTextNow()
            end)
        end)
    end

    if not revealedAfterClaim then
        main.Visible = true
        revealedAfterClaim = true
    end

    setMinimized(false)

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
    box.BackgroundColor3 = THEME.control
    box.TextColor3 = THEME.controlText
    box.PlaceholderColor3 = THEME.subtleText
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Center
    local prefix = text .. ": "
    box.Text = prefix .. tostring(settings[key])
    box.Parent = row

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box

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
    box.BackgroundColor3 = THEME.control
    box.TextColor3 = THEME.controlText
    box.PlaceholderColor3 = THEME.subtleText
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    box.MultiLine = multiline == true
    box.TextWrapped = multiline == true
    box.PlaceholderText = placeholder
    box.Text = tostring(settings[key] or "")
    box.Parent = row

    local boxPadding = Instance.new("UIPadding")
    boxPadding.PaddingLeft = UDim.new(0, 8)
    boxPadding.PaddingRight = UDim.new(0, 8)
    boxPadding.Parent = box

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box

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

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.Position = UDim2.new(0, 0, 0.5, -12)
    btn.BackgroundColor3 = THEME.control
    btn.TextColor3 = THEME.controlText
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = THEME.stroke
    btnStroke.Parent = btn

    local listFrame = Instance.new("Frame")
    listFrame.Visible = false
    listFrame.BackgroundColor3 = THEME.control
    listFrame.BorderSizePixel = 0
    listFrame.Position = UDim2.new(0, 0, 0, baseHeight)
    listFrame.Size = UDim2.new(1, 0, 0, optionsHeight)
    listFrame.ZIndex = 20
    listFrame.Parent = row

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 4)
    listCorner.Parent = listFrame

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
        local optionBtn = Instance.new("TextButton")
        optionBtn.Size = UDim2.new(1, 0, 0, optionHeight)
        optionBtn.BackgroundColor3 = THEME.section
        optionBtn.TextColor3 = THEME.controlText
        optionBtn.Font = Enum.Font.Gotham
        optionBtn.TextSize = 12
        optionBtn.Text = tostring(v)
        optionBtn.ZIndex = 21
        optionBtn.Parent = listFrame

        local optionCorner = Instance.new("UICorner")
        optionCorner.CornerRadius = UDim.new(0, 4)
        optionCorner.Parent = optionBtn

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

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.Position = UDim2.new(0, 0, 0.5, -12)
    btn.BackgroundColor3 = THEME.control
    btn.TextColor3 = THEME.controlText
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Text = text
    btn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = THEME.stroke
    btnStroke.Parent = btn

    local content = Instance.new("Frame")
    content.Visible = false
    content.BackgroundColor3 = THEME.control
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0, 0, 0, baseHeight)
    content.Size = UDim2.new(1, 0, 0, contentHeight)
    content.Parent = row

    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 4)
    contentCorner.Parent = content

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

    local editorPad = Instance.new("UIPadding")
    editorPad.PaddingTop = UDim.new(0, 6)
    editorPad.PaddingBottom = UDim.new(0, 6)
    editorPad.PaddingLeft = UDim.new(0, 8)
    editorPad.PaddingRight = UDim.new(0, 8)
    editorPad.Parent = editor

    local editorCorner = Instance.new("UICorner")
    editorCorner.CornerRadius = UDim.new(0, 4)
    editorCorner.Parent = editor

    local editorStroke = Instance.new("UIStroke")
    editorStroke.Thickness = 1
    editorStroke.Color = THEME.stroke
    editorStroke.Parent = editor

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0.5, -3, 0, 24)
    saveBtn.Position = UDim2.new(0, 0, 0, 146)
    saveBtn.BackgroundColor3 = THEME.topBar
    saveBtn.TextColor3 = THEME.topBarText
    saveBtn.Font = Enum.Font.GothamSemibold
    saveBtn.TextSize = 11
    saveBtn.Text = "Save"
    saveBtn.Parent = content

    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 4)
    saveCorner.Parent = saveBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0.5, -3, 0, 24)
    closeBtn.Position = UDim2.new(0.5, 3, 0, 146)
    closeBtn.BackgroundColor3 = THEME.section
    closeBtn.TextColor3 = THEME.controlText
    closeBtn.Font = Enum.Font.GothamSemibold
    closeBtn.TextSize = 11
    closeBtn.Text = "Close"
    closeBtn.Parent = content

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn

    local nextLineBtn = Instance.new("TextButton")
    nextLineBtn.Size = UDim2.new(1, 0, 0, 24)
    nextLineBtn.Position = UDim2.new(0, 0, 0, 174)
    nextLineBtn.BackgroundColor3 = THEME.control
    nextLineBtn.TextColor3 = THEME.controlText
    nextLineBtn.Font = Enum.Font.GothamSemibold
    nextLineBtn.TextSize = 11
    nextLineBtn.Text = "Skip To Next Line"
    nextLineBtn.Parent = content

    local nextLineCorner = Instance.new("UICorner")
    nextLineCorner.CornerRadius = UDim.new(0, 4)
    nextLineCorner.Parent = nextLineBtn

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
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 104, 0, 23)
    btn.BackgroundColor3 = THEME.topBar
    btn.TextColor3 = THEME.topBarText
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.Text = text
    btn.Parent = parent

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

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

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0, 26)
    track.BackgroundColor3 = THEME.control
    track.BorderSizePixel = 0
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 4)
    trackCorner.Parent = track

    local trackStroke = Instance.new("UIStroke")
    trackStroke.Thickness = 1
    trackStroke.Color = THEME.stroke
    trackStroke.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = THEME.accent
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fill

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.BackgroundColor3 = THEME.accent
    thumb.BorderSizePixel = 0
    thumb.Position = UDim2.new(0, 0, 0.5, 0)
    thumb.ZIndex = 5
    thumb.Parent = track

    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(1, 0)
    thumbCorner.Parent = thumb

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
    local mainTab = createTab("Main")
    local chatTab = createTab("Chat")
    local webhookTab = createTab("Webhook")
    local serverTab = createTab("Server")

    local boothSection = createSection(boothTab, "Booth Settings")
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
    createDropdown(boothSection, "Standing Position", "standingPosition", {"Front", "Left", "Right", "Behind"})

    do
        local mainSection = createSection(mainTab, "Main Settings")
        createToggle(mainSection, "Helicopter On-Donation", "helicopterEnabled")
        createTextBox(mainSection, "Helicopter Spin Speed", "helicopterSpeed", true)
        createToggle(mainSection, "Die After Landing", "helicopterDieAfterLanding")
        createToggle(mainSection, "1R$= +1 Spin Speed", "spinSet")
        createTextBox(mainSection, "Spin Speed Multiplier", "spinSpeedMultiplier", true)
        createTextBox(mainSection, "Test Donation Amount (R$)", "testDonationAmount", true)
        createButton(mainSection, "Test Donation", function()
            local stat = getRaisedStatObject()
            local amount = math.max(1, tonumber(settings.testDonationAmount) or 6)
            if stat and type(stat.Value) == "number" then
                stat.Value += amount
                notify("Test Donation", ("Simulated +%d R$ donation."):format(amount), 3, "test-dono", 1)
            else
                notify("Test Donation", "Raised stat not found.", 3, "test-dono-missing", 1)
            end
        end)
    end

    do
        local chatSection = createSection(chatTab, "Chat Settings")
        createToggle(chatSection, "Auto Thank You", "autoThanks")
        createTextBox(chatSection, "Thanks Delay (S)", "thanksDelay", true)
        createMessageDropdown(chatSection, "Thank You Messages", "thanksMessage", "Thank you")
        createToggle(chatSection, "Auto Beg", "autoBeg")
        createTextBox(chatSection, "Beg Delay (S)", "begDelay", true)
        createMessageDropdown(chatSection, "Begging Messages", "begMessage", "Please donate")
    end

    do
    local webhookSection = createSection(webhookTab, "Webhook Settings")
    createToggle(webhookSection, "Webhook Enabled", "webhookToggle")
    createTextBox(webhookSection, "Webhook URL", "webhookBox", false)
    createToggle(webhookSection, "Webhook After Serverhop", "webhookAfterSH")
    createToggle(webhookSection, "Ping Everyone", "pingEveryone")
    createTextBox(webhookSection, "Ping Above Donation", "pingAboveDono", true)
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
    local vcService = game:GetService("VoiceChatService")
    local vcEnabled = pcall(function() return vcService:IsVoiceEnabledForUserIdAsync(LocalPlayer.UserId) end)
    if vcEnabled then
        createToggle(serverSection, "VC Server Hop (All Servers)", "vcServerHopToggle")
    end
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

task.defer(function()
    if settings.spinSet then
        applySpinState()
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

        if settings.spinSet then
            local spin = getSpinMover()
            if spin then
                local multiplier = math.max(0, tonumber(settings.spinSpeedMultiplier) or 1)
                local averageDelta = delta / 3
                local nextVelocity = (averageDelta * multiplier) + spin.AngularVelocity.Y
                spin.AngularVelocity = Vector3.new(0, nextVelocity, 0)
            else
                applySpinState()
            end
        end

        if settings.helicopterEnabled then
            performHelicopterDonationSequence(delta)
        end

        sendDonationWebhook(delta, consumeRecentDonationDonorInfo(delta))

        if settings.autoThanks then
            task.spawn(function()
                task.wait(math.max(0, tonumber(settings.thanksDelay) or 0))
                sendChatMessage(pickRandomMessage(settings.thanksMessage, "Thank you"))
            end)
        end
    end)
end)

local antiSitConnections = {}

local function clearAntiSitConnections()
    for _, connection in ipairs(antiSitConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    table.clear(antiSitConnections)
end

local function enableAntiSit(character)
    clearAntiSitConnections()

    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    humanoid.Sit = false

    table.insert(antiSitConnections, humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
        if humanoid.Sit then
            humanoid.Sit = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end))

    table.insert(antiSitConnections, humanoid.Seated:Connect(function(isSeated)
        if isSeated then
            humanoid.Sit = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end))
end

if LocalPlayer.Character then
    enableAntiSit(LocalPlayer.Character)
    if settings.helicopterEnabled then
        task.delay(1.5, startHelicopterIdleMode)
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1.5, function()
        local character = LocalPlayer.Character
        if character then
            enableAntiSit(character)
        end
        if claimedBoothSlot then
            moveToClaimedBooth(claimedBoothSlot)
        end
        stopAstronautIdle()
        stopHelicopterIdleTask()
        stopHelicopterSpin()
        if settings.helicopterEnabled then
            startHelicopterIdleMode()
        end
        if settings.spinSet then
            applySpinState()
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
        if settings.spinSet and claimedBoothSlot then
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

activateTab("Main")
setMinimized(true)

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
        if not minimized then
            applyResponsiveSize(false)
        end
    end
end)
