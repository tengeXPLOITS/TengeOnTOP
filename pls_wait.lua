-- PLS WAIT - Custom script scaffold for place 14212732626
-- Created: scaffold for user's booth claiming code integration

repeat task.wait() until game:IsLoaded()

local PLACE_ID = 14212732626
if tonumber(game.PlaceId) ~= tonumber(PLACE_ID) then
    warn("This script is intended for place id: "..tostring(PLACE_ID).." — aborting.")
    return
end

-- Basic service bindings and defaults
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Minimal SETTINGS/defaults used across the script
SETTINGS = SETTINGS or {}
SETTINGS.webhookToggle = SETTINGS.webhookToggle or false
SETTINGS.webhookUrl = SETTINGS.webhookUrl or ""
SETTINGS.antiAfk = SETTINGS.antiAfk or false
SETTINGS.serverStayTime = SETTINGS.serverStayTime or 30
SETTINGS.persistToggles = SETTINGS.persistToggles or false

-- Donation monitoring placeholders
donationConns = donationConns or {}
donationEnabled = donationEnabled or false
donationTotals = donationTotals or {}
donationStatName = donationStatName or "Raised"

local function notify(title, text, duration)
    local ok, playerGui = pcall(function() return LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
    duration = tonumber(duration) or 4
    if ok and playerGui and playerGui:FindFirstChild("PlsWaitUI") then
        local screen = playerGui:FindFirstChild("PlsWaitUI")
        local notif = Instance.new("Frame")
        notif.Size = UDim2.new(0, 320, 0, 64)
        notif.Position = UDim2.new(1, -340, 1, -96)
        notif.AnchorPoint = Vector2.new(0,0)
        notif.BackgroundColor3 = Color3.fromRGB(18,18,18)
        notif.Parent = screen
        local corner = Instance.new("UICorner", notif)
        corner.CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", notif)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(36,36,36)
        local titleLbl = Instance.new("TextLabel", notif)
        titleLbl.Size = UDim2.new(1, -16, 0, 20)
        titleLbl.Position = UDim2.new(0, 8, 0, 6)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = tostring(title or "PLS WAIT")
        titleLbl.TextColor3 = Color3.fromRGB(220,220,220)
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Font = Enum.Font.SourceSansBold
        titleLbl.TextSize = 14
        local body = Instance.new("TextLabel", notif)
        body.Size = UDim2.new(1, -16, 0, 34)
        body.Position = UDim2.new(0, 8, 0, 26)
        body.BackgroundTransparency = 1
        body.Text = tostring(text or "")
        body.TextColor3 = Color3.fromRGB(180,180,180)
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextWrapped = true
        body.Font = Enum.Font.SourceSans
        body.TextSize = 13
        task.spawn(function()
            task.wait(duration)
            pcall(function() notif:Destroy() end)
        end)
        return
    end
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = tostring(title or "PLS WAIT"), Text = tostring(text or ""), Duration = duration })
    end)
end

local antiAfkConn = nil
local function enableAntiAfk()
    if antiAfkConn then return end
    local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
    if not ok or not vu then return end
    antiAfkConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new(0,0))
        end)
    end)
    notify("Anti-AFK", "Enabled", 2)
end
local function disableAntiAfk()
    if antiAfkConn then
        pcall(function() antiAfkConn:Disconnect() end)
        antiAfkConn = nil
    end
    notify("Anti-AFK", "Disabled", 2)
end

-- Webhook / donation helpers
local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G

local function postWebhookEvent(kind, data)
    if not SETTINGS.webhookToggle or not SETTINGS.webhookUrl or SETTINGS.webhookUrl == "" then return end
    local url = tostring(SETTINGS.webhookUrl or "")
    local embeds = {}
    if kind == "donation" then
        local amount = tonumber(data and data.amount) or 0
        local taxed = math.floor((amount or 0) * 0.6)
        local donorName = tostring((data and data.donorName) or (data and data.from) or "Unknown")
        local donorLabel = donorName
        table.insert(embeds, {
            title = "New Donation Received! ✅",
            color = 0x00FF00,
            fields = {
                { name = "Donor 👤", value = donorLabel, inline = false },
                { name = "How much recepient received 💵", value = tostring(amount), inline = true },
                { name = "Tax applied ):", value = tostring(taxed), inline = true },
            },
        })
    else
        table.insert(embeds, { title = (kind and tostring(kind) or "event"):upper(), description = HttpService:JSONEncode(data or {}), color = 16753920 })
    end

    local payload = { username = "PlsWait", embeds = embeds }
    local body = HttpService:JSONEncode(payload)
    pcall(function()
        if syn and syn.request then
            syn.request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif request then
            request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        else
            HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
        end
    end)
end

local function tryHookPlayerStat(player)
    if not player then return false end
    local uid = tostring(player.UserId)
    if donationConns["stat_"..uid] then return true end
    local ls = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 1)
    if not ls then return false end
    local stat = ls:FindFirstChild(donationStatName) or nil
    if not stat then
        for _, c in ipairs(ls:GetChildren()) do
            if c:IsA("IntValue") or c:IsA("NumberValue") or c:IsA("StringValue") then
                local n = tonumber(tostring(c.Value):gsub("[^%d]",""))
                if n and n > 0 then
                    stat = c
                    break
                end
            end
        end
    end
    if not stat then return false end
    donationTotals[uid] = tonumber(stat.Value) or 0
    donationConns["stat_"..uid] = stat.Changed:Connect(function()
        local newv = tonumber(stat.Value) or tonumber(tostring(stat.Value):gsub("[^%d]","")) or 0
        local prev = donationTotals[uid] or 0
        if newv ~= prev then
            local delta = newv - prev
            donationTotals[uid] = newv
            if delta > 0 then
                -- Only notify when the local player (script user) receives the donation
                if player == LocalPlayer then
                    postWebhookEvent("donation", { from = player.Name, userId = player.UserId, amount = delta, total = newv })
                end
            end
        end
    end)
    return true
end

-- performHttpRequest helper (syn/request or common aliases)
local function performHttpRequest(options)
    if syn and syn.request then return syn.request(options) end
    if request then return request(options) end
    if http_request then return http_request(options) end
    return nil
end

-- queueOnTeleport helper (supports executors)
local function queueOnTeleport(codeString)
    if not codeString or codeString == "" then return false end
    if queue_on_teleport then pcall(function() queue_on_teleport(codeString) end); return true end
    if syn and syn.queue_on_teleport then pcall(function() syn.queue_on_teleport(codeString) end); return true end
    if fluxus and fluxus.queue_on_teleport then pcall(function() fluxus.queue_on_teleport(codeString) end); return true end
    return false
end

-- Replace serverHopNow with working implementation from your other script
local function serverHopNow(minPlayers, maxPlayers, persistent)
    minPlayers = tonumber(minPlayers) or 19
    maxPlayers = tonumber(maxPlayers) or 22
    persistent = persistent == true

    task.spawn(function()
        while true do
            local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100"):format(tostring(PLACE_ID))
            local res = performHttpRequest({ Url = url, Method = "GET" })
            local found = false
            if res and type(res.Body) == "string" and res.Body ~= "" then
                local ok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
                if ok and decoded and type(decoded.data) == "table" then
                    for _, server in ipairs(decoded.data) do
                        local playing = tonumber(server.playing) or 0
                        if server.id and tostring(server.id) ~= tostring(game.JobId) and playing >= minPlayers and playing <= maxPlayers then
                            -- queue this script to re-run on the destination and pass current settings via _G
                            local ok2, cfgJson = pcall(function()
                                return HttpService:JSONEncode({
                                    webhookToggle = SETTINGS.webhookToggle,
                                    webhookUrl = SETTINGS.webhookUrl,
                                    antiAfk = SETTINGS.antiAfk,
                                    serverStayTime = SETTINGS.serverStayTime,
                                    persistToggles = SETTINGS.persistToggles,
                                    autoServerHop = autoServerHopEnabled,
                                })
                            end)
                            local qcode = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua"))()'
                            if ok2 and cfgJson then
                                qcode = ("local _json = %q; _G.__PLS_WAIT_CONFIG = game:GetService('HttpService'):JSONDecode(_json); %s"):format(cfgJson, qcode)
                            end
                            -- try to queue the script for the destination
                            pcall(function() queueOnTeleport(qcode) end)
                            local ts = game:GetService("TeleportService")
                            local okt, terr = pcall(function()
                                ts:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer)
                            end)
                            if okt then
                                found = true
                                break
                            else
                                local terrs = tostring(terr or "")
                                -- ignore server-full teleport error code 772 and continue searching
                                if terrs:find("772") or terrs:lower():find("teleport failed") then
                                    -- try next server
                                else
                                    -- other errors: notify and continue searching
                                    pcall(function() notify("Server Hop", ("Teleport error: %s"):format(terrs), 6) end)
                                end
                            end
                        end
                    end
                end
            end

            if found then break end
            if not persistent then
                notify("Server Hop", "No suitable servers found.", 4)
                break
            end
            task.wait(3)
        end
    end)
end

local function hookPlayer(player)
    if tryHookPlayerStat(player) then return end
    -- listen for leaderstats being added to this player
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
    -- Only monitor the local player for donations (Raised changes affecting the script user)
    pcall(function() hookPlayer(LocalPlayer) end)
    -- If leaderstats are added later to the local player, try to hook them
    donationConns["local_child"] = LocalPlayer.ChildAdded:Connect(function(child)
        if donationEnabled and child.Name == "leaderstats" then
            task.wait(0.05)
            tryHookPlayerStat(LocalPlayer)
        end
    end)
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
            -- try to make character look away from the booth after claiming
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if hrp and target and target.pivot then
                        local awayPoint = (hrp.Position * 2) - target.pivot
                        hrp.CFrame = CFrame.new(hrp.Position, awayPoint)
                    end
                end
            end)
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
        local hopRangeText = SETTINGS.hopRange or "19-22"
        local function parseRange(str)
            if not str or type(str) ~= "string" then return nil end
            local a,b = str:match("%s*(%d+)%s*%-%s*(%d+)%s*")
            if not a or not b then return nil end
            local mn = tonumber(a)
            local mx = tonumber(b)
            if not mn or not mx then return nil end
            if mn < 0 then mn = 0 end
            if mx < mn then return nil end
            return mn, mx
        end
        local autoServerHopEnabled = false
        local autoServerHopTask = nil
        SETTINGS.persistToggles = SETTINGS.persistToggles or false

        local function SaveSettings()
            local data = {
                webhookToggle = SETTINGS.webhookToggle,
                webhookUrl = SETTINGS.webhookUrl,
                antiAfk = SETTINGS.antiAfk,
                hopRange = hopRangeText,
                serverStayTime = serverStayTime,
                persistToggles = SETTINGS.persistToggles,
                autoServerHop = autoServerHopEnabled,
            }
            SETTINGS.hopRange = hopRangeText
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
            hopRangeText = decoded.hopRange or hopRangeText
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
                hopRangeText = cfg.hopRange or hopRangeText
                autoServerHopEnabled = cfg.autoServerHop or autoServerHopEnabled
                _G.__PLS_WAIT_CONFIG = nil
            end
        end)

        pcall(LoadSettings)
        -- Provide a small UI helper used by buttons
        local function styleButton(btn)
            if not btn then return end
            pcall(function()
                btn.AutoButtonColor = false
                local base = btn.BackgroundColor3
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0,8)
                corner.Parent = btn
                local stroke = Instance.new("UIStroke")
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Thickness = 1
                stroke.Color = Color3.fromRGB(30,30,30)
                stroke.Parent = btn
                btn.MouseEnter:Connect(function()
                    pcall(function() btn.BackgroundColor3 = base:Lerp(Color3.fromRGB(255,255,255), 0.04) end)
                end)
                btn.MouseLeave:Connect(function()
                    pcall(function() btn.BackgroundColor3 = base end)
                end)
            end)
        end

        -- Prevent duplicate UIs across teleports / multiple runs: always remove any existing UI
        local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
        pcall(function()
            local existing = playerGui:FindFirstChild("PlsWaitUI")
            if existing then pcall(function() existing:Destroy() end) end
            SharedEnv.PLS_WAIT_UI_LOADED = nil
        end)
        local screen = Instance.new("ScreenGui")
        screen.Name = "PlsWaitUI"
        screen.ResetOnSpawn = false
        screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screen.Parent = playerGui
        SharedEnv.PLS_WAIT_UI_LOADED = true

        -- Glassy admin-panel style layout
        local mainFrame = Instance.new("Frame")
        mainFrame.Name = "MainFrame"
        mainFrame.Size = UDim2.new(0, 720, 0, 420)
        mainFrame.Position = UDim2.new(0.5, -360, 0.5, -210)
        mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        mainFrame.BackgroundColor3 = Color3.fromRGB(12,12,12)
        mainFrame.BackgroundTransparency = 0
        mainFrame.Parent = screen
        mainFrame.Active = true
        -- adaptive scale for mobile/PC
        local uiScale = Instance.new("UIScale")
        uiScale.Parent = mainFrame
        pcall(function()
            local cam = workspace and workspace.CurrentCamera
            local vs = (cam and cam.ViewportSize) or Vector2.new(1280,720)
            local scale = math.min(vs.X / 1280, vs.Y / 720)
            scale = math.clamp(scale, 0.7, 1)
            uiScale.Scale = scale
        end)
        local mainCorner = Instance.new("UICorner")
        mainCorner.CornerRadius = UDim.new(0,12)
        mainCorner.Parent = mainFrame
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1,0,1,0)
        bg.Position = UDim2.new(0,0,0,0)
        bg.BackgroundColor3 = Color3.fromRGB(24,24,24)
        bg.BackgroundTransparency = 0.15
        bg.BorderSizePixel = 0
        bg.Parent = mainFrame
        local blurOverlay = Instance.new("UIGradient")
        blurOverlay.Rotation = 90
        blurOverlay.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(25,25,25)), ColorSequenceKeypoint.new(1, Color3.fromRGB(12,12,12))})
        blurOverlay.Parent = bg

        -- Left menu column
        local leftCol = Instance.new("Frame")
        leftCol.Name = "LeftCol"
        leftCol.Size = UDim2.new(0, 220, 1, -20)
        leftCol.Position = UDim2.new(0, 12, 0, 12)
        leftCol.BackgroundTransparency = 1
        leftCol.Parent = mainFrame

        local avatar = Instance.new("ImageLabel")
        avatar.Name = "Avatar"
        avatar.Size = UDim2.new(0, 72, 0, 72)
        avatar.Position = UDim2.new(0, 12, 0, 12)
        avatar.BackgroundColor3 = Color3.fromRGB(18,18,18)
        avatar.Image = ""
        avatar.Parent = leftCol
        local avatarCorner = Instance.new("UICorner") avatarCorner.CornerRadius = UDim.new(1,0); avatarCorner.Parent = avatar

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -24, 0, 24)
        nameLbl.Position = UDim2.new(0, 96, 0, 20)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = (LocalPlayer.DisplayName ~= "" and LocalPlayer.DisplayName) or LocalPlayer.Name
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 18
        nameLbl.TextColor3 = Color3.fromRGB(240,240,240)
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = leftCol

        -- left menu buttons
        local menu = { {key="Main", icon="📋", text="Overview"}, {key="ServerHop", icon="🔀", text="Server Hop"}, {key="Webhook", icon="🔔", text="Webhook"} }
        local tabButtons = {}
        local tabFrames = {}
        for i, item in ipairs(menu) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -12, 0, 40)
            btn.Position = UDim2.new(0, 6, 0, 100 + (i-1)*52)
            btn.Text = (item.icon .. "  " .. item.text)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 16
            btn.TextColor3 = Color3.fromRGB(220,220,220)
            btn.BackgroundColor3 = Color3.fromRGB(28,28,28)
            btn.AutoButtonColor = false
            local corner = Instance.new("UICorner") corner.Parent = btn
            btn.Parent = leftCol
            tabButtons[item.key] = btn

            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, -252, 1, -24)
            frame.Position = UDim2.new(0, 236, 0, 12)
            frame.BackgroundTransparency = 1
            frame.Visible = (item.key == "Main")
            frame.Parent = mainFrame
            tabFrames[item.key] = frame
        end

        -- close button
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 28, 0, 28)
        closeBtn.Position = UDim2.new(1, -40, 0, 12)
        closeBtn.Text = "✕"
        closeBtn.Font = Enum.Font.Gotham
        closeBtn.TextSize = 16
        closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
        local closeCorner = Instance.new("UICorner") closeCorner.Parent = closeBtn
        closeBtn.Parent = mainFrame
        closeBtn.MouseButton1Click:Connect(function()
            pcall(function() screen:Destroy() end)
            SharedEnv.PLS_WAIT_UI_LOADED = nil
        end)

        -- Prepare fade-in: collect default transparency targets and set current to invisible
        local fadeTargets = {}
        local function collectTargets(inst)
            for _, child in ipairs(inst:GetChildren()) do
                collectTargets(child)
            end
            if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
                local prev = inst.TextTransparency or 0
                fadeTargets[inst] = { kind = "text", target = prev }
                inst.TextTransparency = 1
            elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
                local prev = inst.ImageTransparency or 0
                fadeTargets[inst] = { kind = "image", target = prev }
                inst.ImageTransparency = 1
            elseif inst:IsA("Frame") then
                local prev = inst.BackgroundTransparency or 0
                fadeTargets[inst] = { kind = "bg", target = prev }
                inst.BackgroundTransparency = 1
            end
        end
        collectTargets(mainFrame)

        -- fade in after 5 seconds
        task.spawn(function()
            task.wait(5)
            local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            for inst, meta in pairs(fadeTargets) do
                pcall(function()
                    if meta.kind == "text" then
                        TweenService:Create(inst, tweenInfo, { TextTransparency = meta.target }):Play()
                    elseif meta.kind == "image" then
                        TweenService:Create(inst, tweenInfo, { ImageTransparency = meta.target }):Play()
                    elseif meta.kind == "bg" then
                        TweenService:Create(inst, tweenInfo, { BackgroundTransparency = meta.target }):Play()
                    end
                end)
            end
        end)

        -- Make the UI draggable (supports touch and mouse)
        do
            local UIS = game:GetService("UserInputService")
            local dragging = false
            local dragInput = nil
            local dragStart = Vector2.new()
            local startPos = UDim2.new()

            -- Fallback global handlers (keeps existing behavior)
            UIS.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if input.Target and (input.Target == mainFrame or input.Target:IsDescendantOf(mainFrame)) then
                        dragging = true
                        dragInput = input
                        dragStart = input.Position
                        startPos = mainFrame.Position
                    end
                end
            end)

            UIS.InputChanged:Connect(function(input)
                if dragging and input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - dragStart
                    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)

            UIS.InputEnded:Connect(function(input)
                if input == dragInput then
                    dragging = false
                    dragInput = nil
                end
            end)

            -- No separate title handlers; mainFrame and its descendants handle drag input
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
            -- Claim button removed (auto-claim runs on load/teleport)

            local afkLabel = Instance.new("TextLabel")
            afkLabel.Size = UDim2.new(0,120,0,20)
            afkLabel.Position = UDim2.new(0,10,0,10)
            afkLabel.Text = "Anti-AFK"
            afkLabel.TextColor3 = Color3.new(1,1,1)
            afkLabel.BackgroundTransparency = 1
            afkLabel.Parent = frame

            local afkToggle = Instance.new("TextButton")
            afkToggle.Size = UDim2.new(0,60,0,20)
            afkToggle.Position = UDim2.new(0,140,0,10)
            afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
            afkToggle.BackgroundColor3 = Color3.fromRGB(34,177,76)
            afkToggle.TextColor3 = Color3.fromRGB(255,255,255)
            local afkCorner = Instance.new("UICorner") afkCorner.Parent = afkToggle
            afkToggle.Parent = frame
            afkToggle.MouseButton1Click:Connect(function()
                SETTINGS.antiAfk = not SETTINGS.antiAfk
                afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
                pcall(SaveSettings)
                if SETTINGS.antiAfk then pcall(enableAntiAfk) else pcall(disableAntiAfk) end
            end)
            styleButton(afkToggle)
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

            local rangeLabel = Instance.new("TextLabel")
            rangeLabel.Size = UDim2.new(0,120,0,20)
            rangeLabel.Position = UDim2.new(0,10,0,48)
            rangeLabel.Text = "Hop Range (min-max)"
            rangeLabel.BackgroundTransparency = 1
            rangeLabel.TextColor3 = Color3.new(1,1,1)
            rangeLabel.Parent = frame

            local rangeBox = Instance.new("TextBox")
            rangeBox.Size = UDim2.new(0,160,0,28)
            rangeBox.Position = UDim2.new(0,140,0,44)
            rangeBox.Text = hopRangeText or "19-22"
            rangeBox.PlaceholderText = "11-22"
            rangeBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
            rangeBox.TextColor3 = Color3.fromRGB(255,255,255)
            local rbCorner = Instance.new("UICorner")
            rbCorner.Parent = rangeBox
            rangeBox.Parent = frame
            rangeBox.FocusLost:Connect(function()
                local txt = tostring(rangeBox.Text or "")
                local mn,mx = parseRange(txt)
                if not mn then
                    notify("Server Hop", "Invalid range format. Use MIN-MAX e.g. 11-22", 4)
                    rangeBox.Text = hopRangeText or "19-22"
                    return
                end
                hopRangeText = txt
                pcall(SaveSettings)
            end)

            local hopBtn = Instance.new("TextButton")
            hopBtn.Size = UDim2.new(0,200,0,40)
            hopBtn.Position = UDim2.new(0,10,0,112)
            hopBtn.Text = "Server Hop Now"
            hopBtn.BackgroundColor3 = Color3.fromRGB(34,177,76)
            hopBtn.TextColor3 = Color3.fromRGB(255,255,255)
            local hCorner = Instance.new("UICorner")
            hCorner.Parent = hopBtn
            hopBtn.Parent = frame
            styleButton(hopBtn)
            hopBtn.MouseButton1Click:Connect(function()
                local txt = (rangeBox and tostring(rangeBox.Text) or hopRangeText) or "19-22"
                local mn, mx = parseRange(txt)
                if not mn then
                    notify("Server Hop", "Invalid hop range (use MIN-MAX).", 4)
                    return
                end
                hopRangeText = txt
                pcall(SaveSettings)
                serverHopNow(mn, mx, true)
            end)

            local autoLabel = Instance.new("TextLabel")
            autoLabel.Size = UDim2.new(0,120,0,20)
            autoLabel.Position = UDim2.new(0,10,0,160)
            autoLabel.Text = "Auto Server Hop"
            autoLabel.BackgroundTransparency = 1
            autoLabel.TextColor3 = Color3.new(1,1,1)
            autoLabel.Parent = frame

            local autoToggle = Instance.new("TextButton")
            autoToggle.Size = UDim2.new(0,60,0,20)
            autoToggle.Position = UDim2.new(0,140,0,160)
            autoToggle.Text = autoServerHopEnabled and "ON" or "OFF"
            autoToggle.BackgroundColor3 = Color3.fromRGB(34,177,76)
            autoToggle.TextColor3 = Color3.fromRGB(255,255,255)
            local atCorner = Instance.new("UICorner")
            atCorner.Parent = autoToggle
            autoToggle.Parent = frame
            styleButton(autoToggle)
            autoToggle.MouseButton1Click:Connect(function()
                autoServerHopEnabled = not autoServerHopEnabled
                autoToggle.Text = autoServerHopEnabled and "ON" or "OFF"
                pcall(SaveSettings)
                if autoServerHopEnabled and not autoServerHopTask then
                    autoServerHopTask = task.spawn(function()
                        while autoServerHopEnabled do
                            local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                            notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                            task.wait(waitTime)
                                if not autoServerHopEnabled then break end
                                local txt = hopRangeText or "19-22"
                                local mn, mx = parseRange(txt)
                                if mn then serverHopNow(mn, mx, true) end
                        end
                        autoServerHopTask = nil
                    end)
                end
            end)
        end

        -- Settings tab removed per user request

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
            whToggle.BackgroundColor3 = Color3.fromRGB(34,177,76)
            styleButton(whToggle)
            whToggle.MouseButton1Click:Connect(function()
                SETTINGS.webhookToggle = not SETTINGS.webhookToggle
                whToggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
                if SETTINGS.webhookToggle then startDonationMonitor() else stopDonationMonitor() end
                pcall(SaveSettings)
            end)

            local urlBox = Instance.new("TextBox")
            urlBox.Size = UDim2.new(1, -20, 0, 24)
            urlBox.Position = UDim2.new(0,10,0,40)
            urlBox.Text = SETTINGS.webhookUrl
            urlBox.PlaceholderText = "https://discord.com/api/webhooks..."
            urlBox.Parent = frame
            urlBox.FocusLost:Connect(function()
                SETTINGS.webhookUrl = tostring(urlBox.Text or "")
                pcall(SaveSettings)
            end)

            -- donation stat name textbox removed per user request
        end

        if SETTINGS.webhookToggle then startDonationMonitor() end
        -- Ensure claim runs after teleports/character spawn
        pcall(function()
            if LocalPlayer and LocalPlayer.Character then
                pcall(function() claimBooth() end)
            end
            LocalPlayer.CharacterAdded:Connect(function()
                task.wait(1)
                pcall(function() claimBooth() end)
            end)
        end)
        if SETTINGS.antiAfk then pcall(enableAntiAfk) end
        if autoServerHopEnabled and not autoServerHopTask then
            autoServerHopTask = task.spawn(function()
                while autoServerHopEnabled do
                    local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                    notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                    task.wait(waitTime)
                    local txt = hopRangeText or "19-22"
                    local mn, mx = parseRange(txt)
                    if mn then serverHopNow(mn, mx, true) end
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
