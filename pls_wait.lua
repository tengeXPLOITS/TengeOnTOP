-- PLS WAIT - Custom script scaffold for place 14212732626
-- Created: scaffold for user's booth claiming code integration

repeat task.wait() until game:IsLoaded()

local PLACE_ID = 14212732626
if tonumber(game.PlaceId) ~= tonumber(PLACE_ID) then
    warn("This script is intended for place id: "..tostring(PLACE_ID).." — aborting.")
    return
end

-- Search for suitable servers and teleport there. If `persist` is true, queue the script to run after teleport.
local function serverHopNow(minPlayers, maxPlayers, persist)
    minPlayers = tonumber(minPlayers) or 19
    maxPlayers = tonumber(maxPlayers) or 22
    persist = persist == true
    local placeId = tonumber(PLACE_ID)
    local currentJob = tostring(game.JobId or "")
    local candidates = {}
    local cursor
    repeat
        local url = "https://games.roblox.com/v1/games/"..tostring(placeId).."/servers/Public?sortOrder=Asc&limit=100"
        if cursor then url = url .. "&cursor=" .. tostring(cursor) end
        local ok, res = pcall(function() return HttpService:GetAsync(url, true) end)
        if not ok or not res then break end
        local ok2, data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok2 or type(data) ~= "table" then break end
        for _, s in ipairs(data.data or {}) do
            if s and s.id and s.playing then
                if tostring(s.id) ~= currentJob and tonumber(s.playing) and tonumber(s.playing) >= minPlayers and tonumber(s.playing) <= maxPlayers then
                    table.insert(candidates, s)
                end
            end
        end
        cursor = data.nextPageCursor
    until not cursor

    if #candidates == 0 then
        notify("Server Hop", "No matching servers found.", 5)
        return false
    end

    local target = candidates[math.random(1, #candidates)]

    -- prepare queued code: inject config into _G and then load remote script
    local remoteUrl = "https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua"
    local cfg = {
        webhookToggle = SETTINGS.webhookToggle,
        webhookUrl = SETTINGS.webhookUrl,
        antiAfk = SETTINGS.antiAfk,
        serverStayTime = SETTINGS.serverStayTime or 30,
        persistToggles = SETTINGS.persistToggles,
        autoServerHop = false,
    }
    local okEnc, enc = pcall(function() return HttpService:JSONEncode(cfg) end)
    local codeToQueue
    if persist and okEnc and enc then
        codeToQueue = string.format([[_G.__PLS_WAIT_CONFIG = %s; loadstring(game:HttpGet("%s"))()]], enc, remoteUrl)
    else
        codeToQueue = string.format([[loadstring(game:HttpGet("%s"))()]], remoteUrl)
    end

    pcall(function()
        local queued = queueOnTeleport(codeToQueue)
        if not queued then
            notify("Server Hop", "Queue-on-teleport not available; script may not persist.", 5)
        end
    end)

    notify("Server Hop", ("Teleporting to server %s (%d players)"):format(tostring(target.id), tonumber(target.playing) or 0), 5)
    pcall(function() TeleportService:TeleportToPlaceInstance(placeId, target.id, LocalPlayer) end)
    return true
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- Try to load upstream/main script if available (safe pcall)
pcall(function()
    local ok, _ = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua"))()
    end)
end)

-- Helper to queue a script on teleport (supports common executor APIs)
local function queueOnTeleport(code)
    if not code then return false end
    local ok, res
    if syn and syn.queue_on_teleport then
        ok, res = pcall(function() syn.queue_on_teleport(code) end)
        return ok
    end
    if syn and syn.queue_onteleport then
        ok, res = pcall(function() syn.queue_onteleport(code) end)
        return ok
    end
    if queue_on_teleport then
        ok, res = pcall(function() queue_on_teleport(code) end)
        return ok
    end
    if fluxus and fluxus.queue_on_teleport then
        ok, res = pcall(function() fluxus.queue_on_teleport(code) end)
        return ok
    end
    return false
end

local SETTINGS = {
    webhookToggle = false,
    webhookUrl = "",
    antiAfk = true,
}

local notificationTimestamps = {}
local function notify(title, text, duration, dedupeKey, cooldown)
    local now = tick()
    if dedupeKey and cooldown then
        do
            -- Simple Koyg-like UI implementation using ScreenGui and manual save/load
            local ok, playerGui = pcall(function()
                return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 6)
            end)
            if not (ok and playerGui) then
                notify("UI", "PlayerGui not available; UI disabled.", 5)
            else
                local notificationTimestamps = {}
                local function notify(title, text, duration, dedupeKey, cooldown)
                    local now = tick()
                    if dedupeKey and cooldown then
                        local last = notificationTimestamps[dedupeKey] or 0
                        if now - last < cooldown then return end
                        notificationTimestamps[dedupeKey] = now
                    end
                    pcall(function()
                        StarterGui:SetCore("SendNotification", { Title = tostring(title or "PLS WAIT"), Text = tostring(text or ""), Duration = tonumber(duration) or 4 })
                    end)
                end
                mainFrame.Parent = screen

                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, 0, 0, 30)
                title.BackgroundTransparency = 1
                title.Text = "Pls Wait - Koyg UI"
                title.TextColor3 = Color3.fromRGB(255,255,255)
                title.Parent = mainFrame

                -- Tabs buttons
                local tabs = {"Main","ServerHop","Settings","Webhook"}
                local tabButtons = {}
                local tabFrames = {}
                for i, name in ipairs(tabs) do
                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.new(0, 120, 0, 30)
                    btn.Position = UDim2.new(0, (i-1)*120, 0, 30)
                    btn.Text = name
                    btn.Parent = mainFrame
                    tabButtons[name] = btn

                    local frame = Instance.new("Frame")
                    frame.Size = UDim2.new(1, -10, 1, -70)
                    frame.Position = UDim2.new(0,5,0,70)
                    frame.BackgroundTransparency = 1
                    frame.Visible = (name == "Main")
                    frame.Parent = mainFrame
                    tabFrames[name] = frame
                end

                local function selectTab(name)
                    for k,v in pairs(tabFrames) do v.Visible = false end
                    tabFrames[name].Visible = true
                end
                for name, btn in pairs(tabButtons) do
                    btn.MouseButton1Click:Connect(function() selectTab(name) end)
                end

                -- Main tab controls
                do
                    local frame = tabFrames.Main
                    local claimBtn = Instance.new("TextButton")
                    claimBtn.Size = UDim2.new(0,200,0,40)
                    claimBtn.Position = UDim2.new(0,10,0,10)
                    claimBtn.Text = "Claim Booth"
                    claimBtn.Parent = frame
                    claimBtn.MouseButton1Click:Connect(function()
                        task.spawn(function()
                            notify("Booth", "Attempting claim...", 3)
                            local ok, res = claimBooth()
                            if ok and res then notify("Booth", "Claim attempted (success).", 4) else notify("Booth", "Claim attempt finished or failed.", 4) end
                        end)
                    end)

                    local afkLabel = Instance.new("TextLabel")
                    afkLabel.Size = UDim2.new(0,120,0,20)
                    afkLabel.Position = UDim2.new(0,10,0,60)
                    afkLabel.Text = "Anti-AFK"
                    afkLabel.TextColor3 = Color3.new(1,1,1)
                    afkLabel.BackgroundTransparency = 1
                    afkLabel.Parent = frame

                    local afkToggle = Instance.new("TextButton")
                    afkToggle.Size = UDim2.new(0,60,0,20)
                    afkToggle.Position = UDim2.new(0,140,0,60)
                    afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
                    afkToggle.Parent = frame
                    afkToggle.MouseButton1Click:Connect(function()
                        SETTINGS.antiAfk = not SETTINGS.antiAfk
                        afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
                        if SETTINGS.antiAfk then pcall(enableAntiAfk) else pcall(disableAntiAfk) end
                        if SETTINGS.persistToggles then pcall(SaveSettings) end
                    end)
                end

                -- Server-Hop tab controls
                do
                    local frame = tabFrames.ServerHop
                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(0,200,0,20)
                    label.Position = UDim2.new(0,10,0,10)
                    label.Text = "Server Stay Time (minutes)"
                    label.BackgroundTransparency = 1
                    label.TextColor3 = Color3.new(1,1,1)
                    label.Parent = frame

                    local timeBox = Instance.new("TextBox")
                    timeBox.Size = UDim2.new(0,100,0,24)
                    timeBox.Position = UDim2.new(0,220,0,8)
                    timeBox.Text = tostring(serverStayTime)
                    timeBox.Parent = frame
                    timeBox.FocusLost:Connect(function(enter)
                        local n = tonumber(timeBox.Text)
                        if n and n >= 1 and n <= 180 then serverStayTime = math.floor(n) end
                        timeBox.Text = tostring(serverStayTime)
                        if SETTINGS.persistToggles then pcall(SaveSettings) end
                    end)

                    local hopBtn = Instance.new("TextButton")
                    hopBtn.Size = UDim2.new(0,200,0,40)
                    hopBtn.Position = UDim2.new(0,10,0,50)
                    hopBtn.Text = "Server Hop Now"
                    hopBtn.Parent = frame
                    hopBtn.MouseButton1Click:Connect(function()
                        serverHopNow(19,22,true)
                    end)

                    local autoLabel = Instance.new("TextLabel")
                    autoLabel.Size = UDim2.new(0,120,0,20)
                    autoLabel.Position = UDim2.new(0,10,0,100)
                    autoLabel.Text = "Auto Server Hop"
                    autoLabel.BackgroundTransparency = 1
                    autoLabel.TextColor3 = Color3.new(1,1,1)
                    autoLabel.Parent = frame

                    local autoToggle = Instance.new("TextButton")
                    autoToggle.Size = UDim2.new(0,60,0,20)
                    autoToggle.Position = UDim2.new(0,140,0,100)
                    autoToggle.Text = autoServerHopEnabled and "ON" or "OFF"
                    autoToggle.Parent = frame
                    autoToggle.MouseButton1Click:Connect(function()
                        autoServerHopEnabled = not autoServerHopEnabled
                        autoToggle.Text = autoServerHopEnabled and "ON" or "OFF"
                        if SETTINGS.persistToggles then pcall(SaveSettings) end
                        if autoServerHopEnabled and not autoServerHopTask then
                            autoServerHopTask = task.spawn(function()
                                while autoServerHopEnabled do
                                    local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                                    notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                                    task.wait(waitTime)
                                    if not autoServerHopEnabled then break end
                                    serverHopNow(19,22,true)
                                end
                                autoServerHopTask = nil
                            end)
                        end
                    end)
                end

                -- Settings tab controls
                do
                    local frame = tabFrames.Settings
                    local persistLabel = Instance.new("TextLabel")
                    persistLabel.Size = UDim2.new(0,200,0,20)
                    persistLabel.Position = UDim2.new(0,10,0,10)
                    persistLabel.Text = "Persist Toggles Across Hops"
                    persistLabel.BackgroundTransparency = 1
                    persistLabel.TextColor3 = Color3.new(1,1,1)
                    persistLabel.Parent = frame

                    local persistToggle = Instance.new("TextButton")
                    persistToggle.Size = UDim2.new(0,60,0,20)
                    persistToggle.Position = UDim2.new(0,220,0,10)
                    persistToggle.Text = SETTINGS.persistToggles and "ON" or "OFF"
                    persistToggle.Parent = frame
                    persistToggle.MouseButton1Click:Connect(function()
                        SETTINGS.persistToggles = not SETTINGS.persistToggles
                        persistToggle.Text = SETTINGS.persistToggles and "ON" or "OFF"
                        pcall(SaveSettings)
                    end)
                end

                -- Webhook tab controls
                do
                    local frame = tabFrames.Webhook
                    local whLabel = Instance.new("TextLabel")
                    whLabel.Size = UDim2.new(0,120,0,20)
                    whLabel.Position = UDim2.new(0,10,0,10)
                    whLabel.Text = "Webhook Enabled"
                    whLabel.BackgroundTransparency = 1
                    whLabel.TextColor3 = Color3.new(1,1,1)
                    whLabel.Parent = frame

                    local whToggle = Instance.new("TextButton")
                    whToggle.Size = UDim2.new(0,60,0,20)
                    whToggle.Position = UDim2.new(0,140,0,10)
                    whToggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
                    whToggle.Parent = frame
                    whToggle.MouseButton1Click:Connect(function()
                        SETTINGS.webhookToggle = not SETTINGS.webhookToggle
                        whToggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
                        if SETTINGS.webhookToggle then startDonationMonitor() else stopDonationMonitor() end
                        if SETTINGS.persistToggles then pcall(SaveSettings) end
                    end)

                    local urlBox = Instance.new("TextBox")
                    urlBox.Size = UDim2.new(0,400,0,24)
                    urlBox.Position = UDim2.new(0,10,0,40)
                    urlBox.Text = SETTINGS.webhookUrl
                    urlBox.PlaceholderText = "https://discord.com/api/webhooks/..."
                    urlBox.Parent = frame
                    urlBox.FocusLost:Connect(function()
                        SETTINGS.webhookUrl = tostring(urlBox.Text or "")
                        if SETTINGS.persistToggles then pcall(SaveSettings) end
                    end)

                    local statBox = Instance.new("TextBox")
                    statBox.Size = UDim2.new(0,200,0,24)
                    statBox.Position = UDim2.new(0,10,0,80)
                    statBox.Text = donationStatName
                    statBox.Parent = frame
                    statBox.FocusLost:Connect(function()
                        donationStatName = tostring(statBox.Text or "Raised")
                        if SETTINGS.persistToggles then pcall(SaveSettings) end
                    end)
                end

                -- after building UI, start monitors/tasks according to loaded settings
                if SETTINGS.webhookToggle then startDonationMonitor() end
                if SETTINGS.antiAfk then pcall(enableAntiAfk) end
                if autoServerHopEnabled and not autoServerHopTask then
                    autoServerHopTask = task.spawn(function()
                        while autoServerHopEnabled do
                            local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                            notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                            task.wait(waitTime)
                            serverHopNow(19,22,true)
                        end
                        autoServerHopTask = nil
                    end)
                end
            end
        end
end

local function hookPlayer(player)
    if tryHookPlayerStat(player) then return end
    -- listen for leaderstats being added
    donationConns["child_"..tostring(player.UserId)] = player.ChildAdded:Connect(function(child)
        if donationEnabled and child.Name == "leaderstats" then
            task.wait(0.05)
            tryHookPlayerStat(player)
        end
    end)
end

local function startDonationMonitor()
    if donationEnabled then return end
    donationEnabled = true
    for _, p in pairs(Players:GetPlayers()) do
        hookPlayer(p)
    end
    donationConns["playerAdded"] = Players.PlayerAdded:Connect(function(p) hookPlayer(p) end)
end

local function stopDonationMonitor()
    donationEnabled = false
    for k, conn in pairs(donationConns) do
        pcall(function() conn:Disconnect() end)
        donationConns[k] = nil
    end
    donationTotals = {}
end

-- BOOTH CLAIMING: paste or require your booth claiming code here and call it
-- Example placeholder function:
-- Try to get a useful pivot/position for a Model or BasePart
local function tryGetPivotPosition(obj)
    if not obj then return nil end
    local ok, res = pcall(function()
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
    if ok then return res end
    return nil
end

local function findSlotFromStand(stand)
    if not stand then return nil end
    -- try extract number from name
    local n = tostring(stand.Name or ""):match("(%d+)")
    if n then return tonumber(n) end
    -- try attributes (some maps store StandId as an Attribute)
    if stand.GetAttribute then
        local aid = stand:GetAttribute("StandId") or stand:GetAttribute("standId") or stand:GetAttribute("Slot") or stand:GetAttribute("slot")
        if aid and tonumber(aid) then return tonumber(aid) end
    end
    -- try common IntValue children
    local candidates = {"Slot","StandId","Index","Id","BoothSlot","Number"}
    for _, cname in ipairs(candidates) do
        local child = stand:FindFirstChild(cname)
        if child and (child:IsA("IntValue") or child:IsA("NumberValue")) then
            return tonumber(child.Value) or nil
        end
        if child and child:IsA("StringValue") then
            local v = tostring(child.Value or ""):match("(%d+)")
            if v then return tonumber(v) end
        end
    end
    return nil
end

local function moveCharacterToPosition(pos)
    if not pos then return false end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") )
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hrp then
        pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0,2,0)) end)
        return true
    elseif hum then
        local ok, _ = pcall(function() hum:MoveTo(pos) end)
        return ok
    end
    return false
end

local claimLock = false
local function claimEmptyStands()
    if claimLock then return false end
    claimLock = true
    local function _run()
    local standsFolder = Workspace:FindFirstChild("Stands") or Workspace:WaitForChild("Stands", 5)
    if not standsFolder then
        notify("Booth Claim", "No Stands folder found.", 4)
        return false
    end

    local remote = ReplicatedStorage:FindFirstChild("ClaimStand") or ReplicatedStorage:WaitForChild("ClaimStand", 5)
    if not remote then
        notify("Booth Claim", "ClaimStand remote not found.", 4)
        return false
    end

    local standsList = standsFolder:GetChildren()
    local standButtons = Workspace:FindFirstChild("StandButtons")
    local buttonList = standButtons and standButtons:GetChildren() or {}

    -- Find nearest empty stand to player and attempt a single claim (do NOT rely on ClientNotification)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local playerPos = hrp and hrp.Position

    local candidates = {}
    for _, stand in ipairs(standsList) do
        if stand and stand.Parent and not stand:FindFirstChild("ButtonPrompt") then
            local ownerObj = stand:FindFirstChild("Wner") or stand:FindFirstChild("Owner")
            local ownerEmpty = true
            if ownerObj and ownerObj:IsA("ObjectValue") then
                ownerEmpty = (ownerObj.Value == nil)
            end
            if ownerEmpty then
                local pivot = tryGetPivotPosition(stand)
                if pivot then
                    candidates[#candidates+1] = { stand = stand, pivot = pivot }
                end
            end
        end
    end

    if #candidates == 0 then
        notify("Booth Claim", "No empty stands available.", 4)
        return false
    end

    -- choose nearest to player (or first if player position unknown)
    table.sort(candidates, function(a,b)
        if not playerPos then return true end
        return (a.pivot - playerPos).Magnitude < (b.pivot - playerPos).Magnitude
    end)

    local target = candidates[1]
    if not target or not target.stand then
        notify("Booth Claim", "No valid stand target.", 3)
        return false
    end

    -- teleport/move a few studs outside the chosen stand pivot (avoid getting stuck inside)
    local safePos = target.pivot
    local dir
    if playerPos then
        dir = Vector3.new(playerPos.X - target.pivot.X, 0, playerPos.Z - target.pivot.Z)
    end
    if not dir or dir.Magnitude < 0.5 then
        dir = Vector3.new(0, 0, -1)
    end
    dir = dir.Unit
    local distanceAway = 3 -- studs away from pivot
    safePos = target.pivot + dir * distanceAway + Vector3.new(0, 2, 0)
    moveCharacterToPosition(safePos)
    task.wait(0.25)

    -- resolve slot id and invoke ClaimStand with the exact args/unpack pattern
    local slot = findSlotFromStand(target.stand)
    if not slot then
        notify("Booth Claim", ("Could not determine slot for %s"):format(tostring(target.stand.Name or "?")), 4)
        return false
    end

    local args = { slot }
    local ok, res = pcall(function()
        return ReplicatedStorage:WaitForChild("ClaimStand"):InvokeServer(unpack(args))
    end)
    if ok then
        notify("Booth Claim", ("Invoked ClaimStand for slot %d (response: %s)"):format(slot, tostring(res)), 4)
        if tostring(res) == "Success" or res == true then
            pcall(function()
                postWebhookEvent("claim", { slot = slot, result = res })
            end)
            return true
        end
        return false
    else
        notify("Booth Claim", ("Claim remote error for slot %d"):format(slot), 3)
        return false
    end
    end
    local ok, res = pcall(_run)
    claimLock = false
    if ok then return res end
    return false
end

local function claimBooth()
    return pcall(claimEmptyStands)
end

-- Koyg-style ScreenGui UI (simple, file-based save/load)
do
    local ok, playerGui = pcall(function()
        return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 6)
    end)
    if not (ok and playerGui) then
        notify("UI", "PlayerGui not available; UI disabled.", 5)
    else
        local Http = HttpService
        local CONFIG_PATH = "pls_wait_config.json"

        local serverStayTime = SETTINGS.serverStayTime or 30
        local autoServerHopEnabled = false
        local autoServerHopTask = nil
        SETTINGS.persistToggles = SETTINGS.persistToggles or false

        local function SaveSettings()
            local data = {
                webhookToggle = SETTINGS.webhookToggle,
                webhookUrl = SETTINGS.webhookUrl,
                antiAfk = SETTINGS.antiAfk,
                serverStayTime = serverStayTime,
                persistToggles = SETTINGS.persistToggles,
                autoServerHop = autoServerHopEnabled,
            }
            local ok, encoded = pcall(function() return Http:JSONEncode(data) end)
            if not ok then return end
            pcall(function()
                if writefile then
                    writefile(CONFIG_PATH, encoded)
                elseif syn and syn.write_file then
                    syn.write_file(CONFIG_PATH, encoded)
                end
            end)
        end

        local function LoadSettings()
            local content = nil
            pcall(function()
                if readfile then
                    content = readfile(CONFIG_PATH)
                elseif syn and syn.read_file then
                    content = syn.read_file(CONFIG_PATH)
                end
            end)
            if not content or content == "" then return end
            local ok, decoded = pcall(function() return Http:JSONDecode(content) end)
            if not ok or type(decoded) ~= "table" then return end
            SETTINGS.webhookToggle = decoded.webhookToggle or SETTINGS.webhookToggle
            SETTINGS.webhookUrl = decoded.webhookUrl or SETTINGS.webhookUrl
            SETTINGS.antiAfk = decoded.antiAfk or SETTINGS.antiAfk
            serverStayTime = tonumber(decoded.serverStayTime) or serverStayTime
            SETTINGS.persistToggles = decoded.persistToggles or SETTINGS.persistToggles
            autoServerHopEnabled = decoded.autoServerHop or autoServerHopEnabled
        end

        pcall(function()
            if type(_G) == "table" and type(_G.__PLS_WAIT_CONFIG) == "table" then
                local cfg = _G.__PLS_WAIT_CONFIG
                SETTINGS.webhookToggle = cfg.webhookToggle or SETTINGS.webhookToggle
                SETTINGS.webhookUrl = cfg.webhookUrl or SETTINGS.webhookUrl
                SETTINGS.antiAfk = cfg.antiAfk or SETTINGS.antiAfk
                serverStayTime = tonumber(cfg.serverStayTime) or serverStayTime
                SETTINGS.persistToggles = cfg.persistToggles or SETTINGS.persistToggles
                autoServerHopEnabled = cfg.autoServerHop or autoServerHopEnabled
                _G.__PLS_WAIT_CONFIG = nil
            end
        end)

        pcall(LoadSettings)

        local screen = Instance.new("ScreenGui")
        screen.Name = "PlsWaitUI"
        screen.ResetOnSpawn = false
        screen.Parent = playerGui

        local mainFrame = Instance.new("Frame")
        mainFrame.Name = "MainFrame"
        mainFrame.Size = UDim2.new(0, 520, 0, 420)
        mainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
        mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        mainFrame.Parent = screen

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 30)
        title.BackgroundTransparency = 1
        title.Text = "Pls Wait - Koyg UI"
        title.TextColor3 = Color3.fromRGB(255,255,255)
        title.Parent = mainFrame

        local tabs = {"Main","ServerHop","Settings","Webhook"}
        local tabButtons = {}
        local tabFrames = {}
        for i, name in ipairs(tabs) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 120, 0, 30)
            btn.Position = UDim2.new(0, (i-1)*120, 0, 30)
            btn.Text = name
            btn.Parent = mainFrame
            tabButtons[name] = btn

            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, -10, 1, -70)
            frame.Position = UDim2.new(0,5,0,70)
            frame.BackgroundTransparency = 1
            frame.Visible = (name == "Main")
            frame.Parent = mainFrame
            tabFrames[name] = frame
        end

        local function selectTab(name)
            for k,v in pairs(tabFrames) do v.Visible = false end
            tabFrames[name].Visible = true
        end
        for name, btn in pairs(tabButtons) do
            btn.MouseButton1Click:Connect(function() selectTab(name) end)
        end

        -- Main tab
        do
            local frame = tabFrames.Main
            local claimBtn = Instance.new("TextButton")
            claimBtn.Size = UDim2.new(0,200,0,40)
            claimBtn.Position = UDim2.new(0,10,0,10)
            claimBtn.Text = "Claim Booth"
            claimBtn.Parent = frame
            claimBtn.MouseButton1Click:Connect(function()
                task.spawn(function()
                    notify("Booth", "Attempting claim...", 3)
                    local ok, res = claimBooth()
                    if ok and res then notify("Booth", "Claim attempted (success).", 4) else notify("Booth", "Claim attempt finished or failed.", 4) end
                end)
            end)

            local afkLabel = Instance.new("TextLabel")
            afkLabel.Size = UDim2.new(0,120,0,20)
            afkLabel.Position = UDim2.new(0,10,0,60)
            afkLabel.Text = "Anti-AFK"
            afkLabel.TextColor3 = Color3.new(1,1,1)
            afkLabel.BackgroundTransparency = 1
            afkLabel.Parent = frame

            local afkToggle = Instance.new("TextButton")
            afkToggle.Size = UDim2.new(0,60,0,20)
            afkToggle.Position = UDim2.new(0,140,0,60)
            afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
            afkToggle.Parent = frame
            afkToggle.MouseButton1Click:Connect(function()
                SETTINGS.antiAfk = not SETTINGS.antiAfk
                afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
                if SETTINGS.antiAfk then pcall(enableAntiAfk) else pcall(disableAntiAfk) end
                if SETTINGS.persistToggles then pcall(SaveSettings) end
            end)
        end

        -- Server-Hop tab
        do
            local frame = tabFrames.ServerHop
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0,200,0,20)
            label.Position = UDim2.new(0,10,0,10)
            label.Text = "Server Stay Time (minutes)"
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.new(1,1,1)
            label.Parent = frame

            local timeBox = Instance.new("TextBox")
            timeBox.Size = UDim2.new(0,100,0,24)
            timeBox.Position = UDim2.new(0,220,0,8)
            timeBox.Text = tostring(serverStayTime)
            timeBox.Parent = frame
            timeBox.FocusLost:Connect(function(enter)
                local n = tonumber(timeBox.Text)
                if n and n >= 1 and n <= 180 then serverStayTime = math.floor(n) end
                timeBox.Text = tostring(serverStayTime)
                if SETTINGS.persistToggles then pcall(SaveSettings) end
            end)

            local hopBtn = Instance.new("TextButton")
            hopBtn.Size = UDim2.new(0,200,0,40)
            hopBtn.Position = UDim2.new(0,10,0,50)
            hopBtn.Text = "Server Hop Now"
            hopBtn.Parent = frame
            hopBtn.MouseButton1Click:Connect(function()
                serverHopNow(19,22,true)
            end)

            local autoLabel = Instance.new("TextLabel")
            autoLabel.Size = UDim2.new(0,120,0,20)
            autoLabel.Position = UDim2.new(0,10,0,100)
            autoLabel.Text = "Auto Server Hop"
            autoLabel.BackgroundTransparency = 1
            autoLabel.TextColor3 = Color3.new(1,1,1)
            autoLabel.Parent = frame

            local autoToggle = Instance.new("TextButton")
            autoToggle.Size = UDim2.new(0,60,0,20)
            autoToggle.Position = UDim2.new(0,140,0,100)
            autoToggle.Text = autoServerHopEnabled and "ON" or "OFF"
            autoToggle.Parent = frame
            autoToggle.MouseButton1Click:Connect(function()
                autoServerHopEnabled = not autoServerHopEnabled
                autoToggle.Text = autoServerHopEnabled and "ON" or "OFF"
                if SETTINGS.persistToggles then pcall(SaveSettings) end
                if autoServerHopEnabled and not autoServerHopTask then
                    autoServerHopTask = task.spawn(function()
                        while autoServerHopEnabled do
                            local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                            notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                            task.wait(waitTime)
                            if not autoServerHopEnabled then break end
                            serverHopNow(19,22,true)
                        end
                        autoServerHopTask = nil
                    end)
                end
            end)
        end

        -- Settings tab
        do
            local frame = tabFrames.Settings
            local persistLabel = Instance.new("TextLabel")
            persistLabel.Size = UDim2.new(0,200,0,20)
            persistLabel.Position = UDim2.new(0,10,0,10)
            persistLabel.Text = "Persist Toggles Across Hops"
            persistLabel.BackgroundTransparency = 1
            persistLabel.TextColor3 = Color3.new(1,1,1)
            persistLabel.Parent = frame

            local persistToggle = Instance.new("TextButton")
            persistToggle.Size = UDim2.new(0,60,0,20)
            persistToggle.Position = UDim2.new(0,220,0,10)
            persistToggle.Text = SETTINGS.persistToggles and "ON" or "OFF"
            persistToggle.Parent = frame
            persistToggle.MouseButton1Click:Connect(function()
                SETTINGS.persistToggles = not SETTINGS.persistToggles
                persistToggle.Text = SETTINGS.persistToggles and "ON" or "OFF"
                pcall(SaveSettings)
            end)
        end

        -- Webhook tab
        do
            local frame = tabFrames.Webhook
            local whLabel = Instance.new("TextLabel")
            whLabel.Size = UDim2.new(0,120,0,20)
            whLabel.Position = UDim2.new(0,10,0,10)
            whLabel.Text = "Webhook Enabled"
            whLabel.BackgroundTransparency = 1
            whLabel.TextColor3 = Color3.new(1,1,1)
            whLabel.Parent = frame

            local whToggle = Instance.new("TextButton")
            whToggle.Size = UDim2.new(0,60,0,20)
            whToggle.Position = UDim2.new(0,140,0,10)
            whToggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
            whToggle.Parent = frame
            whToggle.MouseButton1Click:Connect(function()
                SETTINGS.webhookToggle = not SETTINGS.webhookToggle
                whToggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
                if SETTINGS.webhookToggle then startDonationMonitor() else stopDonationMonitor() end
                if SETTINGS.persistToggles then pcall(SaveSettings) end
            end)

            local urlBox = Instance.new("TextBox")
            urlBox.Size = UDim2.new(0,400,0,24)
            urlBox.Position = UDim2.new(0,10,0,40)
            urlBox.Text = SETTINGS.webhookUrl
            urlBox.PlaceholderText = "https://discord.com/api/webhooks..."
            urlBox.Parent = frame
            urlBox.FocusLost:Connect(function()
                SETTINGS.webhookUrl = tostring(urlBox.Text or "")
                if SETTINGS.persistToggles then pcall(SaveSettings) end
            end)

            local statBox = Instance.new("TextBox")
            statBox.Size = UDim2.new(0,200,0,24)
            statBox.Position = UDim2.new(0,10,0,80)
            statBox.Text = donationStatName
            statBox.Parent = frame
            statBox.FocusLost:Connect(function()
                donationStatName = tostring(statBox.Text or "Raised")
                if SETTINGS.persistToggles then pcall(SaveSettings) end
            end)
        end

        if SETTINGS.webhookToggle then startDonationMonitor() end
        if SETTINGS.antiAfk then pcall(enableAntiAfk) end
        if autoServerHopEnabled and not autoServerHopTask then
            autoServerHopTask = task.spawn(function()
                while autoServerHopEnabled do
                    local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                    notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                    task.wait(waitTime)
                    serverHopNow(19,22,true)
                end
                autoServerHopTask = nil
            end)
        end
    end
end

-- Script loaded: use functions directly (not returning a module table)
-- Auto-run a single claim on script execution
task.spawn(function()
    task.wait(1)
    pcall(function() claimBooth() end)
end)
