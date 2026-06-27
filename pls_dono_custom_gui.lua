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

local ALLOWED_PLACE_IDS = {
    [137150797605098] = true, -- keeps getting deleted, so we have to allowlist the ID instead of the community
    [8737602449] = true,  -- DEFAULT_PLS_DONATE_PLACE_ID
    [14212732626] = true, -- PLS WAIT (unreleased as of 2024-06)
}

local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
local DEFAULT_PLS_DONATE_PLACE_ID = 8737602449

local DEFAULT_AUTOEXEC_URL = "https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_dono_custom_gui.lua"
if type(SharedEnv.PLS_DONO_AUTOEXEC_URL) ~= "string" or SharedEnv.PLS_DONO_AUTOEXEC_URL == "" then
    SharedEnv.PLS_DONO_AUTOEXEC_URL = DEFAULT_AUTOEXEC_URL
end
if type(SharedEnv.PLS_DONO_AUTOEXEC_SOURCE) ~= "string" or SharedEnv.PLS_DONO_AUTOEXEC_SOURCE == "" then
    SharedEnv.PLS_DONO_AUTOEXEC_SOURCE = "loadstring(game:HttpGet('" .. SharedEnv.PLS_DONO_AUTOEXEC_URL .. "'))()"
end

local TextChatService = game:GetService("TextChatService")
local notificationTimestamps = {}
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

-- resolvePlayerInfoFromText removed: donor prediction now uses getNearestPlayerInfo()

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
        donorInfo = (type(getNearestPlayerInfo) == "function") and getNearestPlayerInfo() or { name = trimText(donorText), displayName = trimText(donorText), userId = 0 },
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

-- If present, destroy LiveDonations object in Workspace to avoid conflicts
if ALLOWED_PLACE_IDS[tonumber(game.PlaceId) or 0] then
    local function createLiveDonationsRemovalNotifier(duration)
        duration = tonumber(duration) or 12
        local ok, res = pcall(function()
            if not GuiParent then return nil end
            local existing = GuiParent:FindFirstChild("PlsDonoLiveDonationRemovalNotification")
            if existing then existing:Destroy() end

            local screen = Instance.new("ScreenGui")
            screen.Name = "PlsDonoLiveDonationRemovalNotification"
            screen.ResetOnSpawn = false
            screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            screen.DisplayOrder = 999
            screen.Parent = GuiParent

            local frame = Instance.new("Frame")
            frame.AnchorPoint = Vector2.new(1, 1)
            frame.Position = UDim2.new(1, -20, 1, -20)
            frame.Size = UDim2.new(0, 380, 0, 64)
            frame.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
            frame.BorderSizePixel = 0
            frame.Parent = screen

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = frame

            local label = Instance.new("TextLabel")
            label.Name = "Msg"
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, -12, 1, 0)
            label.Position = UDim2.new(0, 8, 0, 0)
            label.Text = "Removing Donation board: 0%"
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextScaled = false
            label.TextSize = 16
            label.Font = Enum.Font.GothamSemibold
            label.TextWrapped = true
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = frame

            local function update(percent)
                pcall(function()
                    if not label or not label.Parent then return end
                    label.Text = string.format("Removing Donation board: %d%%", math.clamp(math.floor(percent or 0), 0, 100))
                end)
            end

            local function finish(success)
                pcall(function()
                    if not label or not label.Parent then return end
                    label.Text = success and "Donation board removed. This stabilizes game performance!" or "failed to remove Donation board. If you are in Simply Donate, the removal doesn't work here. You can ignore this message."
                    task.delay(duration, function()
                        pcall(function()
                            if screen and screen.Parent then screen:Destroy() end
                        end)
                    end)
                end)
            end

            return { update = update, finish = finish }
        end)
        if ok then return res end
        return nil
    end

    pcall(function()
        local function tryGetPivotPosition(obj)
            if not obj then
                return nil
            end
            local ok, result = pcall(function()
                if typeof(obj) == "Instance" then
                    if obj:IsA("Model") then
                        if obj.GetPivot then
                            return obj:GetPivot().Position
                        end
                        if obj.PrimaryPart then
                            return obj.PrimaryPart.Position
                        end
                    elseif obj:IsA("BasePart") then
                        return obj.Position
                    end
                end
                return nil
            end)
            if ok then

            
                return result
            end
            return nil
        end

        local parentNames = {"leaderboards", "Leaderboards", "LeaderBoard", "LeaderBoards"}

        local candidates = {}
        -- Find LeaderBoards parents anywhere in Workspace and collect LiveDonations under them
        for _, obj in ipairs(Workspace:GetDescendants()) do
            for _, pname in ipairs(parentNames) do
                if obj.Name == pname then
                    local ld = obj:FindFirstChild("LiveDonations")
                    if ld then table.insert(candidates, ld) end
                    break
                end
            end
        end

        -- Also include any top-level LiveDonations and any LiveDonations found anywhere
        local topLd = Workspace:FindFirstChild("LiveDonations")
        if topLd then table.insert(candidates, topLd) end
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d.Name == "LiveDonations" then
                table.insert(candidates, d)
            end
        end

        -- Collect Bench models under any Benches parent (do not destroy yet)
        local benchCandidates = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Benches" then
                for _, child in ipairs(obj:GetChildren()) do
                    if child and child.Name == "Bench" and type(child.Destroy) == "function" then
                        table.insert(benchCandidates, child)
                    end
                end
            end
        end

        local targetPos = Vector3.new(166.229004, 13.5387201, 424.031067)
        local MATCH_THRESHOLD = 0.5

        -- Combine candidates and benchCandidates into a unique list
        local allMap = {}
        local allTargets = {}
        for _, v in ipairs(candidates) do
            if v and type(v.Destroy) == "function" then
                allMap[v] = true
            end
        end
        for _, v in ipairs(benchCandidates) do
            if v and type(v.Destroy) == "function" then
                allMap[v] = true
            end
        end
        -- Also include any Workspace descendants matching nuisance names
        local nuisanceNames = {
            "livedonationboard", "livedonations", "livedonation", "donationboard", "donations", "global"
        }
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if type(obj.Name) == "string" and type(obj.Destroy) == "function" then
                local lower = tostring(obj.Name):lower()
                for _, n in ipairs(nuisanceNames) do
                    if lower == n then
                        allMap[obj] = true
                        break
                    end
                end
            end
        end
        -- Effect-based model removal disabled per user request (do not mark effect instances for deletion)
        for v, _ in pairs(allMap) do table.insert(allTargets, v) end

        local total = #allTargets
        local removed = false

        local notifier = nil
        local lastPercent = 0
        local deletionDone = false
        -- create notifier after 3 seconds so it pops up later
        task.delay(3, function()
            notifier = createLiveDonationsRemovalNotifier(12)
            if notifier then
                notifier.update(lastPercent)
                if deletionDone then
                    notifier.finish(removed)
                end
            end
        end)

        if total > 0 then
            local idx = 0
            for _, target in ipairs(allTargets) do
                idx = idx + 1
                local destroyed = false
                -- If target looks like LiveDonations, prefer pivot/leaderboard checks
                if tostring(target.Name or ""):lower() == "livedonations" then
                    local pos = tryGetPivotPosition(target)
                    if pos then
                        if (pos - targetPos).Magnitude <= MATCH_THRESHOLD then
                            pcall(function() target:Destroy() end)
                            destroyed = true
                        end
                    else
                        local parent = target.Parent
                        while parent do
                            local pname = tostring(parent.Name or ""):lower()
                            if pname:find("leaderboard", 1, true) then
                                pcall(function() target:Destroy() end)
                                destroyed = true
                                break
                            end
                            parent = parent.Parent
                        end
                    end
                else
                    pcall(function() target:Destroy() end)
                    destroyed = true
                end

                if destroyed then removed = true end

                local percent = math.floor((idx / total) * 100)
                if percent < 1 then percent = 1 end
                lastPercent = percent
                if notifier then
                    notifier.update(percent)
                end
            end
        end

        deletionDone = true
        if notifier then
            notifier.finish(removed)
        end
    end)
end

-- Anti-Lag feature removed per user request

-- Anti-AFK: prevent idle kick by using VirtualUser on LocalPlayer.Idled
local antiAfkConn = nil
local function enableAntiAfk()
    if antiAfkConn then return true end
    local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
    if not ok or not vu then
        return false
    end
    antiAfkConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new(0,0))
        end)
    end)
    pcall(function() notify("Anti-AFK","Enabled: will prevent idle kick.",3,"anti-afk",1) end)
    return true
end

local function disableAntiAfk()
    if antiAfkConn then
        pcall(function() antiAfkConn:Disconnect() end)
        antiAfkConn = nil
    end
    pcall(function() notify("Anti-AFK","Disabled.",3,"anti-afk",1) end)
end

local SETTINGS_FILE = "plsdono_custom_settings.json"
local SETTINGS_BACKUP_FILE = "plsdono_custom_settings_backup.json"

local defaults = {
    standingPosition = "Front",
    boothPosition = 3,
    moveMode = "Teleport",

    autoThanks = false,
    thanksDelay = 3,
    thanksMessage = {"Thank you", "Thankss!", "ty"},
    autoBeg = false,
    begDelay = 300,
    begMessage = {"Grateful for any donation", "Please help me reach my goal!", "Anything helps, thank you!"},

    webhookToggle = false,
    webhookBox = "",

    serverHopToggle = true,
    serverHopDelay = 15,
    minPlayerCount = 23,
    maxPlayerCount = 24,
    plusHopToggle = false,
    plusHopMinPlayers = 3,
    -- antiLagBeta removed
    antiAfkToggle = false,
    helicopterEnabled = false,
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

local plusHopAttemptCount = 0

local function createPersistentStatusOverlay(textMsg)
    local ok, res = pcall(function()
        if not GuiParent then return nil end
        local existing = GuiParent:FindFirstChild("PlsDonoStatusOverlay")
        if existing then existing:Destroy() end

        local screen = Instance.new("ScreenGui")
        screen.Name = "PlsDonoStatusOverlay"
        screen.ResetOnSpawn = false
        screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screen.DisplayOrder = 1000
        screen.Parent = GuiParent

        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
        frame.Size = UDim2.new(0, 420, 0, 80)
        frame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
        frame.BorderSizePixel = 0
        frame.Parent = screen

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -24, 1, -12)
        label.Position = UDim2.new(0, 12, 0, 6)
        label.Text = tostring(textMsg or "")
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 18
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.Parent = frame

        return screen
    end)
    if ok then return res end
    return nil
end

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
    return normalizedReason ~= "" and normalizedReason ~= "manual-button"
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
-- bot-detection and mod-evader functions removed

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
        local ok, response = pcall(function()
            if HttpService.PostAsync then
                return HttpService:PostAsync(url, payload, Enum.HttpContentType.ApplicationJson, false)
            end
            return nil
        end)
        sent = ok and response ~= nil
    end)

    if not sent then
        pcall(function()
            local response = performHttpRequest({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload,
            })
            sent = response ~= nil
        end)
    end

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

local function getRobloxAvatarThumbnailUrl(userId)
    local numericUserId = tonumber(userId)
    if not numericUserId or numericUserId <= 0 then
        return nil
    end

    local ok, thumbnailUrl = pcall(function()
        if Players.GetUserThumbnailAsync then
            local success, url = pcall(function()
                return Players:GetUserThumbnailAsync(numericUserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
            end)
            if success and type(url) == "string" and url ~= "" then
                return url
            end
        end

        return ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png"):format(numericUserId)
    end)

    if ok and type(thumbnailUrl) == "string" and thumbnailUrl ~= "" then
        return thumbnailUrl
    end

    return nil
end

local function sendDonationWebhook(amount, donorInfo)
    if not settings then
        return
    end

    local url = tostring(settings.webhookBox or ""):match("%S+")
    if not url or url == "" then
        return
    end

    if not settings.webhookToggle and not url then
        return
    end

    local received = math.max(0, tonumber(amount) or 0)
    local actualReceived = math.floor(received * 0.6)
    local receivedLabel = "How much you actually received"
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

    local recipientDisplay = trimText(LocalPlayer.DisplayName) ~= "" and tostring(LocalPlayer.DisplayName) or tostring(LocalPlayer.Name or "Unknown")
    local donorUserId = tonumber(donorInfo and donorInfo.userId) or 0
    local donorAvatar = donorUserId > 0 and getRobloxAvatarThumbnailUrl(donorUserId) or nil

    postWebhookJson(url, {
        username = "webhook by K_0YG...",
        embeds = {{
            color = 0x1B5E20,
            title = ("@%s just got donated! 🤑"):format(recipientDisplay),
            description = ("**%d R$** by **%s**\n• %s: %d R$\n• UR raised amount: %d R$"):format(received, donorLabel, receivedLabel, actualReceived, math.max(0, tonumber(getCurrentRaisedAmount()) or 0)),
            thumbnail = donorAvatar and {url = donorAvatar, proxy_url = donorAvatar} or nil,
            author = donorAvatar and {name = donorLabel, icon_url = donorAvatar} or nil,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }},
    })
end

local function pickRandomMessage(list, fallback)
    if type(list) == "table" and #list > 0 then
        local index = math.random(1, #list)
        return tostring(list[index] or fallback or "")
    end
    return tostring(fallback or "")
end

local hopCooldownSeconds = 1
local lastHopTick = 0
local serverHopIsActive = false
local hopTimerResetTick = tick()
local donatedSinceHopTimerReset = 0
local lastDonationTick = 0
local donationHopBlockSeconds = 3
local plusHopAttemptCount = 0

local function choosePlaceId()
    local cur = tonumber(game.PlaceId) or 0
    if ALLOWED_PLACE_IDS[cur] then
        return cur
    end

    local allowedList = {}
    for k, v in pairs(ALLOWED_PLACE_IDS) do
        if v then table.insert(allowedList, tonumber(k) or k) end
    end
    if #allowedList > 0 then
        return allowedList[math.random(1, #allowedList)]
    end

    return DEFAULT_PLS_DONATE_PLACE_ID
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

            local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"):format(tostring(placeId))
            local req = performHttpRequest({
                Url = url,
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

            if not req then
                pcall(function()
                    createPersistentStatusOverlay("Server hop HTTP request failed for place: " .. tostring(placeId))
                end)
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
    if tostring(reason or "") == "plus-hop" then
        plusHopAttemptCount = (plusHopAttemptCount or 0) + 1
        if plusHopAttemptCount > 5 then
            pcall(function()
                createPersistentStatusOverlay("searching for PLUS servers, pls wait!")
            end)
            pcall(function()
                notify("Plus Hop", "searching for PLUS servers, pls wait!", 6, "plus-hop-kick", 10)
            end)
            return false
        end
    end

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

task.spawn(function()
    task.wait(1.5)
    if not settings or not settings.plusHopToggle then
        return
    end
    local pid = tonumber(game.PlaceId) or 0
    if not ALLOWED_PLACE_IDS[pid] then
        return
    end

    local required = tonumber(settings.plusHopMinPlayers) or 3
    local plusCount = 0
    for _, pl in ipairs(Players:GetPlayers()) do
        local ok, isPremium = pcall(function()
            return pl.MembershipType == Enum.MembershipType.Premium
        end)
        if ok and isPremium then
            plusCount = plusCount + 1
        end
    end

    if plusCount >= required then
        plusHopAttemptCount = 0
        return
    end

    notify("Plus Hop", ("Found %d Plus users; require %d — hopping"):format(plusCount, required), 6, "plus-hop", 10)
    pcall(function()
        requestServerHop("plus-hop")
    end)
end)

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

-- Booth text / goal-bar helpers removed (booth apply feature disabled)

-- `updateBoothTextNow` removed: booth apply functionality disabled by design

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

    -- Support walk move mode: attempt to walk to the booth instead of teleporting
    local moveMode = tostring(settings.moveMode or "Teleport")
    if moveMode:lower() == "walk" then
        local targetPos = targetCF.Position
        -- Use Humanoid:MoveTo if available
        local moved = false
        local ok, moveErr = pcall(function()
            humanoid:MoveTo(targetPos)
        end)

        if ok then
            local start = tick()
            while tick() - start < 8 do
                if not hrp or not hrp.Parent then break end
                local dist = (hrp.Position - targetPos).Magnitude
                if dist <= 3 then
                    moved = true
                    break
                end
                task.wait(0.2)
            end
        end

        -- Ensure facing regardless of movement result
        applyFacing()
        return true, moved and "walk" or "teleport-fallback"
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

local gui = Instance.new("ScreenGui")
gui.Name = "PlsDonoCustomGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50
gui.Parent = GuiParent

-- custom FontFace usage removed; GUI will use Enum.Font settings only

local THEME = {
    topBar = Color3.fromRGB(96, 96, 102),
    topBarText = Color3.fromRGB(248, 255, 248),
    panel = Color3.fromRGB(23, 23, 25),
    tabIdle = Color3.fromRGB(72, 72, 76),
    tabActive = Color3.fromRGB(96, 96, 102),
    section = Color3.fromRGB(18, 18, 20),
    control = Color3.fromRGB(31, 31, 34),
    controlText = Color3.fromRGB(238, 238, 238),
    subtleText = Color3.fromRGB(181, 191, 181),
    accent = Color3.fromRGB(145, 145, 150),
    stroke = Color3.fromRGB(66, 66, 71),
}

local SHELL_CORNER_RADIUS = 8
local CONTROL_CORNER_RADIUS = 6
local GLOW_COLOR = Color3.fromRGB(200, 200, 200)
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
    btn.Font = font or Enum.Font.GothamSemibold
    btn.TextSize = textSize or 11
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
end

local function styleTextBox(box, alignment, multiline)
    box.BackgroundColor3 = THEME.control
    box.TextColor3 = THEME.controlText
    box.PlaceholderColor3 = THEME.subtleText
    box.Font = Enum.Font.GothamSemibold
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
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 120, 125)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 100, 104)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 84)),
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
    title.Text = "Donation Game Utility (Public)"
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
    subtitle.Text = "if u still use this, i hate u"
    subtitle.Parent = topBar
    applyTextGlow(subtitle, SUBTLE_GLOW_COLOR, SUBTLE_GLOW_TRANSPARENCY)
end

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "Minimize"
minimizeBtn.Size = UDim2.new(0, 18, 0, 18)
minimizeBtn.Position = UDim2.new(0, 8, 0.5, -9)
minimizeBtn.BackgroundColor3 = THEME.control
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
    miniStroke.Color = THEME.stroke
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
    minimizeBtn.BackgroundColor3 = state and THEME.tabActive or THEME.control

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
local HELICOPTER_IDLE_SPIN_SPEED = 2.4
local HELICOPTER_SPIN_SPEED_PER_RUBUX = 0.025
local HELICOPTER_MAX_SPIN_SPEED = 8
local SPIN_DONATION_BASE_SPEED = 0.25

local function getHelicopterFlightDuration(amount)
    local donation = math.max(1, tonumber(amount) or 1)
    return math.clamp(0.55 + (math.sqrt(donation) * 0.06), 0.7, 1.9)
end

local function getHelicopterRiseHeight(amount, minRiseHeight)
    local donation = math.max(1, tonumber(amount) or 1)
    local minimum = math.max(0, tonumber(minRiseHeight) or 0)
    return math.clamp(math.max(minimum, 8 + (math.sqrt(donation) * 2.4)), 8, 28)
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

    stopHelicopterIdleTask()
    heliBody.AngularVelocity = Vector3.new(0, HELICOPTER_IDLE_SPIN_SPEED, 0)
    currentIdleTask = task.spawn(function()
        while settings.helicopterEnabled and root.Parent do
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
            task.wait(0.05)
        end
    end)
end

local function getOrCreateHelicopterMarker()
    local marker = workspace:FindFirstChild("_HIGHLIGHT.CF")
    if marker and marker:IsA("BasePart") then
        return marker
    end

    marker = Instance.new("Part")
    marker.Name = "_HIGHLIGHT.CF"
    marker.Size = Vector3.new(20, 2, 20)
    marker.Transparency = 1
    marker.CanCollide = false
    marker.Anchored = true
    marker.Parent = workspace
    return marker
end

local function performHelicopterBurst(raisedAmount)
    pendingHelicopterRaisedAmount += math.max(1, tonumber(raisedAmount) or 1)
    if currentHelicopterSpinTask then
        return
    end

    currentHelicopterSpinTask = task.spawn(function()
        while pendingHelicopterRaisedAmount > 0 do
            local amount = math.max(1, tonumber(pendingHelicopterRaisedAmount) or 1)
            pendingHelicopterRaisedAmount = 0

            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = hum and hum.RootPart
            if not char or not hum or not root then
                break
            end

            local ok, err = pcall(function()
                stopHelicopterIdleTask()
                stopAstronautIdle()

                local heliBody = root:FindFirstChild("HL1__HELI")
                if not (heliBody and heliBody:IsA("BodyAngularVelocity")) then
                    heliBody = Instance.new("BodyAngularVelocity")
                    heliBody.Name = "HL1__HELI"
                    heliBody.MaxTorque = Vector3.new(0, math.huge, 0)
                    heliBody.Parent = root
                end

                local marker = getOrCreateHelicopterMarker()
                local riseHeight = getHelicopterRiseHeight(amount, 8)
                local movementDuration = math.clamp(1.2 + (amount * 0.02), 1.2, 2.2)
                local settleDuration = math.clamp(0.9 + (amount * 0.01), 0.9, 1.5)
                local spinSpeed = math.clamp(HELICOPTER_IDLE_SPIN_SPEED + (amount * HELICOPTER_SPIN_SPEED_PER_RUBUX), HELICOPTER_IDLE_SPIN_SPEED, HELICOPTER_MAX_SPIN_SPEED)

                marker.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0))
                heliBody.AngularVelocity = Vector3.new(0, spinSpeed, 0)

                pcall(function()
                    sendChatMessage("Enabling engines...")
                    Players:Chat("/e dance2")
                end)

                task.wait(3)

                local fastSpinTween = TweenService:Create(
                    heliBody,
                    TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
                    { AngularVelocity = Vector3.new(0, math.clamp(spinSpeed + 16, HELICOPTER_IDLE_SPIN_SPEED, 28), 0) }
                )
                fastSpinTween:Play()
                task.wait(0.9)

                pcall(function()
                    sendChatMessage("TAKEOFF IN 3")
                end)
                task.wait(1)
                pcall(function()
                    sendChatMessage("2")
                end)
                task.wait(1)
                pcall(function()
                    sendChatMessage("1")
                end)
                task.wait(1)

                local startPos = marker.Position
                local riseTween = TweenService:Create(
                    marker,
                    TweenInfo.new(movementDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { CFrame = CFrame.new(startPos + Vector3.new(0, riseHeight, 0)) }
                )
                local settleTween = TweenService:Create(
                    marker,
                    TweenInfo.new(settleDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    { CFrame = CFrame.new(startPos) }
                )

                riseTween:Play()
                task.wait(movementDuration)
                settleTween:Play()

                local slowSpinTween = TweenService:Create(
                    heliBody,
                    TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
                    { AngularVelocity = Vector3.new(0, HELICOPTER_IDLE_SPIN_SPEED, 0) }
                )
                slowSpinTween:Play()
                task.wait(0.8)

                pcall(function()
                    Players:Chat("/e wave")
                end)
            end)

            if not ok then
                warn("Helicopter burst failed:", err)
                pendingHelicopterRaisedAmount = 0
                break
            end
        end

        currentHelicopterSpinTask = nil
        if LocalPlayer.Character and settings.helicopterEnabled then
            startHelicopterIdleMode()
        end
    end)
end

local function performHelicopterDonationSequence(raisedAmount)
    performHelicopterBurst(raisedAmount)
end

local function getCharacterHumanoidRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

local function getSpinAngularVelocity()
    return SPIN_DONATION_BASE_SPEED
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
    -- antiLagBeta handler removed
    antiAfkToggle = function(value)
        if value then
            pcall(function() enableAntiAfk() end)
        else
            pcall(function() disableAntiAfk() end)
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

    -- manual update only; do not auto-update booth text on claim

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

                -- manual update only; user must press the Update button to apply booth text
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
    editor.Font = Enum.Font.Code
    -- FontFace support removed; keep Enum.Font
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
    -- FontFace support removed; keep Enum.Font
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
    local mainTab = createTab("Main")
    local chatTab = createTab("Chat")
    local webhookTab = createTab("Webhook")
    local serverTab = createTab("Server Hop")

    local boothSection = createSection(boothTab, "Booth Settings")
    createInfoLabel(boothSection, "Booth text features (goal bar, text, fonts) removed due to Roblox update; only standing position and move mode remain.")
    createDropdown(boothSection, "Standing Position", "standingPosition", {"Front", "Left", "Right", "Behind"})
    createDropdown(boothSection, "Booth Move Mode", "moveMode", {"Teleport", "Walk"})

    do
        local mainSection = createSection(mainTab, "Main Settings")
        createToggle(mainSection, "Helicopter On-Donation", "helicopterEnabled")
        createToggle(mainSection, "1R$= +1 Spin Speed", "spinSet")
        -- Anti-Lag removed per user request
        createToggle(mainSection, "Anti-AFK", "antiAfkToggle")
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
    -- Donation Notifier feature only - other webhook options removed per user request
end

do
    local serverSection = createSection(serverTab, "Serverhop Settings")
    createToggle(serverSection, "Auto Server Hop", "serverHopToggle")
    createTextBox(serverSection, "Server Hop Delay (Minutes)", "serverHopDelay", true)
    createTextBox(serverSection, "Min Players in Server", "minPlayerCount", true)
    createTextBox(serverSection, "Max Players in Server", "maxPlayerCount", true)
    -- Plus-hop: hop away from servers with few Premium (Plus) users
    createToggle(serverSection, "Plus Hop (Prefer Plus)", "plusHopToggle")
    createTextBox(serverSection, "Min Plus Players", "plusHopMinPlayers", true)
    createInfoLabel(serverSection, "try not to use in Simply Donate")
    -- Anti-bot and mod-evader controls removed
    createButton(serverSection, "Server Hop Now", function()
        requestServerHop("manual-button")
    end)
end

end

buildSettingsTabs()

-- Apply saved setting handlers so toggles like Anti-Lag reapply on load
if settingHandlers then
    for key, handler in pairs(settingHandlers) do
        pcall(function()
            handler(settings[key])
        end)
    end
end

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

-- population hopper, anti-bot scans, and mod-evader loops removed

task.spawn(function()
    local lastTextUpdate = 0
    while task.wait(1) do
        if false then
            -- text update delay loop disabled; updates happen on events now
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

        if settings.spinSet then
            local spin = getSpinMover()
            if spin then
                local averageDelta = delta / 3
                local nextVelocity = averageDelta + spin.AngularVelocity.Y
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

if LocalPlayer.Character then
    if settings.helicopterEnabled then
        task.delay(1.5, startHelicopterIdleMode)
    end
end

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
                    hopTimerResetTick = tick()
                    donatedSinceHopTimerReset = 0
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
        if settings.spinSet and claimedBoothSlot and not currentHelicopterSpinTask then
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

-- FontFace automatic application removed; UI uses Enum.Font values

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
