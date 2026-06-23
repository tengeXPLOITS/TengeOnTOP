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

SETTINGS = SETTINGS or {}
-- Webhook / donation helpers
SETTINGS.antiAfk = SETTINGS.antiAfk or false
SETTINGS.serverStayTime = SETTINGS.serverStayTime or 30
SETTINGS.persistToggles = SETTINGS.persistToggles or false
-- periodicJump feature removed
SETTINGS.spinOnDonation = false
local touchEnabled = UserInputService and UserInputService.TouchEnabled
SETTINGS.touchPreventAFK = SETTINGS.touchPreventAFK or (touchEnabled and true or false)
SETTINGS.claimEnforceMode = SETTINGS.claimEnforceMode or "teleport"
SETTINGS.emotePlaying = SETTINGS.emotePlaying or false
-- runtime spin state (xspin follows old.lua behavior)
-- spin-on-donation removed (settings disabled)

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

    
local function stopClaimMonitor()
    lastClaimMonitorStop = true
    lastClaimPosition = nil
    lastClaimAwayDir = nil
end
local function startClaimMonitor(stand, pos, awayDir)
    if not stand or not pos then return end
    -- Safely extract a Vector3 position from various accepted pos types
    local okPos, resolvedPos = pcall(function()
        if typeof(pos) == "CFrame" then
            return pos.Position
        elseif typeof(pos) == "Vector3" then
            return pos
        elseif type(pos) == "table" and pos.Position then
            return pos.Position
        end
        return nil
    end)
    if not okPos or not resolvedPos then return end
    lastClaimPosition = resolvedPos
    if typeof(awayDir) == "Vector3" then
        lastClaimAwayDir = awayDir
    end
    lastClaimMonitorStop = false
    task.spawn(function()
        while not lastClaimMonitorStop do
            task.wait(0.8)
            if lastClaimMonitorStop then break end
            -- ensure stand still exists
            if not stand or not stand.Parent then stopClaimMonitor(); break end
            -- check ownership: Owner (ObjectValue) or StringValue
            local ownerObj = stand:FindFirstChild("Owner") or stand:FindFirstChild("Wner")
            local owned = false
            if ownerObj then
                pcall(function()
                    if ownerObj:IsA("ObjectValue") then
                        if ownerObj.Value == LocalPlayer or tostring(ownerObj.Value) == LocalPlayer.Name then owned = true end
                    elseif ownerObj:IsA("StringValue") then
                        if tostring(ownerObj.Value) == LocalPlayer.Name then owned = true end
                    else
                        if tostring(ownerObj.Value) == LocalPlayer.Name then owned = true end
                    end
                end)
            end
            if not owned then
                -- no longer our stand; stop monitoring
                stopClaimMonitor()
                break
            end
            local char = LocalPlayer.Character
            if not char then break end
            local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then break end
            local d = (hrp.Position - lastClaimPosition).Magnitude
            if d >= 12 then
                pcall(function() notify("Claim Monitor", "Moving back to claimed booth...", 2) end)
                local mode = SETTINGS.claimEnforceMode or "teleport"
                if mode == "teleport" then
                    -- strong teleport enforcement (repeated CFrame set + velocity clear)
                    for attempt = 1, 8 do
                        if lastClaimMonitorStop then break end
                        pcall(function()
                            local curChar = LocalPlayer.Character
                            if curChar then
                                local curHrp = curChar:FindFirstChild("HumanoidRootPart") or curChar:FindFirstChild("Torso")
                                if curHrp then
                                    local lookDir = lastClaimAwayDir or Vector3.new(0,0,1)
                                    curHrp.CFrame = CFrame.new(lastClaimPosition + Vector3.new(0,2,0), lastClaimPosition + Vector3.new(0,2,0) + lookDir)
                                    pcall(function() curHrp.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
                                end
                                local curHum = curChar:FindFirstChildOfClass("Humanoid")
                                if curHum then pcall(function() curHum:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
                            end
                        end)
                        task.wait(0.08)
                        local cur = (LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso")))
                        if cur and (cur.Position - lastClaimPosition).Magnitude <= 4 then break end
                    end
                else
                    -- walk mode: MoveTo only
                    for attempt = 1, 12 do
                        if lastClaimMonitorStop then break end
                        pcall(function() hum:MoveTo(lastClaimPosition) end)
                        task.wait(0.18)
                        local cur = (LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso")))
                        if cur and (cur.Position - lastClaimPosition).Magnitude <= 4 then break end
                    end
                end
            end
        end
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
        local amount = tonumber(data and data.amount) or tonumber(tostring(data and data.amount or ""):gsub("[^%d]","")) or 0
        local donorName = tostring((data and data.donorName) or (data and data.from) or "Unknown")
        local donorLabel = donorName
        table.insert(embeds, {
            title = "New Donation Received! ✅",
            color = 0x00FF00,
            fields = {
                { name = "Donor 👤", value = donorLabel, inline = false },
                { name = "Amount 💵", value = tostring(amount), inline = true },
            },
        })
    else
        if kind == "serverhop" then
            local initiator = tostring(data and data.user or "Unknown")
            local players = tostring(data and data.players or "")
            local range = tostring(data and data.range or "any")
            local auto = tostring((data and data.auto) and "Yes" or "No")
            table.insert(embeds, {
                title = "Server Hop Triggered 🔀",
                color = 0x3498DB,
                fields = {
                    { name = "Initiator 👤", value = initiator, inline = false },
                    { name = "Players Online 👥", value = players, inline = true },
                    { name = "Range", value = range, inline = true },
                    { name = "Auto Hop", value = auto, inline = true },
                },
            })
        else
            table.insert(embeds, { title = (kind and tostring(kind) or "event"):upper(), description = HttpService:JSONEncode(data or {}), color = 16753920 })
        end
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
    -- Ensure we don't keep a stale connection: disconnect and clear any existing entry first
    if donationConns["stat_"..uid] then
        pcall(function() donationConns["stat_"..uid]:Disconnect() end)
        donationConns["stat_"..uid] = nil
    end
    if donationConns["ls_child_"..uid] then
        pcall(function() donationConns["ls_child_"..uid]:Disconnect() end)
        donationConns["ls_child_"..uid] = nil
    end
    if donationConns["ls_remove_"..uid] then
        pcall(function() donationConns["ls_remove_"..uid]:Disconnect() end)
        donationConns["ls_remove_"..uid] = nil
    end
    -- helper to parse numeric amount from various formats
    local function parseAmount(v)
        if type(v) == "number" then return math.floor(v) end
        local s = tostring(v or "")
        -- Remove any non-digit or non-minus characters (handles emojis, symbols, commas, parentheses)
        local cleaned = s:gsub("[^%d%-]", "")
        if cleaned == "" then return 0 end
        -- If cleaned contains multiple minus signs or is malformed, fall back to extracting first sequence of digits
        local ok, num = pcall(function() return tonumber(cleaned) end)
        if ok and type(num) == "number" then return math.floor(num) end
        local m = s:match("%-?%d+")
        if m then return tonumber(m) or 0 end
        return 0
    end
    local ls = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 1)
    if not ls then return false end
    local stat = ls:FindFirstChild(donationStatName) or nil
    if not stat then
        for _, c in ipairs(ls:GetChildren()) do
            if c:IsA("IntValue") or c:IsA("NumberValue") or c:IsA("StringValue") then
                local n = parseAmount(c.Value)
                if n and n >= 0 then
                    stat = c
                    break
                end
            end
        end
    end
    if not stat then return false end
    donationTotals[uid] = parseAmount(stat.Value)
    donationConns["stat_"..uid] = stat.Changed:Connect(function()
        local newv = parseAmount(stat.Value)
        local prev = donationTotals[uid] or 0
        if newv ~= prev then
            local delta = newv - prev
            donationTotals[uid] = newv
            if delta > 0 then
                -- Only notify when the local player (script user) receives the donation
                if player == LocalPlayer then
                    -- find nearest other player as donor (best-effort)
                    local function fetchNearestPlayer()
                        local best, bestDist = nil, math.huge
                        local ok, lchar = pcall(function() return LocalPlayer.Character end)
                        if not ok or not lchar then return nil end
                        local lroot = lchar:FindFirstChild("HumanoidRootPart") or lchar:FindFirstChild("Torso")
                        if not lroot then return nil end
                        for _, pl in ipairs(Players:GetPlayers()) do
                            if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                                local pr = pl.Character:FindFirstChild("HumanoidRootPart")
                                local d = (pr.Position - lroot.Position).Magnitude
                                if d < bestDist then bestDist = d; best = pl end
                            end
                        end
                        return best
                    end
                    local donor = fetchNearestPlayer()
                    local donorName = (donor and donor.Name) or "Unknown"
                    local donorId = (donor and donor.UserId) or nil
                    postWebhookEvent("donation", { donorName = donorName, from = donorName, userId = donorId, amount = delta, total = newv })

                    -- (spin-on-donation removed)
                end
            end
        end
    end)
    -- Listen for leaderstats children changes so we can re-hook if the stat object is replaced
    donationConns["ls_child_"..uid] = ls.ChildAdded:Connect(function(child)
        task.wait(0.05)
        tryHookPlayerStat(player)
    end)
    donationConns["ls_remove_"..uid] = ls.ChildRemoved:Connect(function(child)
        task.wait(0.05)
        tryHookPlayerStat(player)
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

-- sendPlainWebhook: post a simple content message to webhook URL (preserves donation embed elsewhere)
local function sendPlainWebhook(msg)
    if not SETTINGS.webhookToggle or not SETTINGS.webhookUrl or SETTINGS.webhookUrl == "" then return end
    local url = tostring(SETTINGS.webhookUrl or "")
    local body = HttpService:JSONEncode({ content = tostring(msg) })
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

-- queueOnTeleport helper (supports executors)
local function queueOnTeleport(codeString)
    if not codeString or codeString == "" then return false end
    -- try common globals/providers
    local ok
    if queue_on_teleport then ok = pcall(function() queue_on_teleport(codeString) end); if ok then return true end end
    if syn and syn.queue_on_teleport then ok = pcall(function() syn.queue_on_teleport(codeString) end); if ok then return true end end
    if fluxus and fluxus.queue_on_teleport then ok = pcall(function() fluxus.queue_on_teleport(codeString) end); if ok then return true end end
    -- some executors expose a different name; attempt invoke via pcall on global
    if _G and _G.queue_on_teleport then ok = pcall(function() _G.queue_on_teleport(codeString) end); if ok then return true end end
    return false
end

-- ensureQueuedScript: try to queue the provided code string; if unsupported, attempt a writefile-based fallback
local function ensureQueuedScript(codeString)
    if not codeString or codeString == "" then return false end
    local queued = false
    pcall(function() queued = queueOnTeleport(codeString) end)
    if queued then return true end

    -- Fallback: if writefile available, write a small bootstrap that will load the remote core on next launch
    local okWrite = false
    pcall(function()
        if writefile then
            writefile("pls_wait_queued.lua", codeString)
            okWrite = true
        elseif syn and syn.write_file then
            syn.write_file("pls_wait_queued.lua", codeString)
            okWrite = true
        end
    end)
    if okWrite then
        -- Try to queue execution using syn.queue_on_teleport pointing to dofile if available
        local okQueueFile = false
        pcall(function()
            if syn and syn.queue_on_teleport then
                syn.queue_on_teleport("dofile('pls_wait_queued.lua')")
                okQueueFile = true
            end
        end)
        if okQueueFile then return true end
        -- notify the user that a fallback file was written but automatic queuing wasn't available
        pcall(function() notify("Persistence", "Wrote pls_wait_queued.lua locally; your executor may not support queue_on_teleport. If teleporting, re-run this file after join.", 8) end)
        return true
    end

    -- final fallback: inform user that automatic persistence isn't available
    pcall(function() notify("Persistence", "queue_on_teleport not supported by your executor; enable persistToggles manually.", 8) end)
    return false
end

-- Single search attempt: returns true if teleport was initiated
local function serverSearchAttempt(minPlayers, maxPlayers, fast)
    -- if nil passed, treat as any player count (no filter)
    if minPlayers then minPlayers = tonumber(minPlayers) end
    if maxPlayers then maxPlayers = tonumber(maxPlayers) end
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100"):format(tostring(PLACE_ID))
    -- retry behavior: fast=true does a single quick attempt, otherwise retry a few times
    local res = nil
    local attempts = fast and 1 or 3
    for i=1,attempts do
        res = performHttpRequest({ Url = url, Method = "GET" })
        if res and type(res.Body) == "string" and res.Body ~= "" then break end
        if not fast then task.wait(0.25) end
    end
    if not (res and type(res.Body) == "string" and res.Body ~= "") then return false end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not (ok and decoded and type(decoded.data) == "table") then return false end
    for _, server in ipairs(decoded.data) do
        local playing = tonumber(server.playing) or 0
        if server.id and tostring(server.id) ~= tostring(game.JobId) then
            if minPlayers and maxPlayers and not (playing >= minPlayers and playing <= maxPlayers) then
                -- skip this server (out of requested range)
            else
            -- queue this script to re-run on the destination and pass current settings via _G
            local ok2, cfgJson = pcall(function()
                return HttpService:JSONEncode({
                    webhookToggle = SETTINGS.webhookToggle,
                    webhookUrl = SETTINGS.webhookUrl,
                    antiAfk = SETTINGS.antiAfk,
                    serverStayTime = SETTINGS.serverStayTime,
                    persistToggles = SETTINGS.persistToggles,
                    emoteId = SETTINGS.emoteId,
                    emotePlaying = SETTINGS.emotePlaying and true or false,
                    autoServerHop = autoServerHopEnabled,
                })
            end)
            local qcore = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua"))()'
            local qcode = qcore
            if ok2 and cfgJson then
                qcode = ("(function() local _json = %q; local ok,cfg = pcall(function() return game:GetService('HttpService'):JSONDecode(_json) end); if ok and type(cfg)=='table' then _G.__PLS_WAIT_CONFIG = cfg end; local f,err = loadstring(game:HttpGet('https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua')); if f then pcall(f) else warn(err) end end)()"):format(cfgJson)
            end
            pcall(function() ensureQueuedScript(qcode) end)
            local ts = game:GetService("TeleportService")
            local okt, terr = pcall(function()
                ts:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer)
            end)
            if okt then
                return true
            else
                local terrs = tostring(terr or "")
                local lterrs = terrs:lower()
                -- Robust detection for "GameFull" / Error 772 / raiseTeleportInitFailedEvent messages
                local isGameFull = false
                if lterrs:find("772") or lterrs:find("error code: 772") then isGameFull = true end
                if lterrs:find("gamefull") or lterrs:find("game full") then isGameFull = true end
                if lterrs:find("requested experience is full") or lterrs:find("requested experience") then isGameFull = true end
                if lterrs:find("raiseteleportinitfail") or lterrs:find("raise teleport") or lterrs:find("raiseteleportinitfailedevent") then isGameFull = true end

                if isGameFull then
                    -- ensure qcode available; queue it again to be safe
                    pcall(function() ensureQueuedScript(qcode) end)
                    -- Kick the player so Roblox will attempt the queued script on rejoin
                    task.spawn(function()
                        task.wait(0.05)
                        pcall(function() LocalPlayer:Kick("finding a suitable server for you") end)
                    end)
                    return false
                end

                if lterrs:find("teleport failed") then
                    -- ignore and continue searching
                else
                    pcall(function() notify("Server Hop", ("Teleport error: %s"):format(terrs), 6) end)
                end
            end
            end
        end
    end
    return false
end

-- Replace older serverHopNow with controller that can run one-shot or persistent
local function serverHopNow(minPlayers, maxPlayers, persistent)
    minPlayers = tonumber(minPlayers) or 19
    maxPlayers = tonumber(maxPlayers) or 22
    persistent = persistent == true
    task.spawn(function()
        local backoff = 0.3
        local maxBackoff = 10
        while true do
            local ok = serverSearchAttempt(minPlayers, maxPlayers)
            if ok then break end
            if not persistent then
                notify("Server Hop", "No suitable servers found.", 4)
                break
            end
            -- safe exponential backoff with jitter to avoid rate limits
            local jitter = math.random() * 0.4
            task.wait(backoff + jitter)
            backoff = math.min(maxBackoff, backoff * 1.5)
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

-- (previously had a helper to show kick modal on teleport failure; removed as unused)

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

local function moveCharacterToPosition(pos, mode, lookDir)
    if not pos then return false end
    local targetVec = nil
    if typeof(pos) == "CFrame" then
        targetVec = pos.Position
    elseif typeof(pos) == "Vector3" then
        targetVec = pos
    elseif type(pos) == "table" and pos.Position then
        targetVec = pos.Position
    else
        return false
    end
    local char = LocalPlayer.Character or (LocalPlayer.CharacterAdded and LocalPlayer.CharacterAdded:Wait())
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    mode = mode or SETTINGS.claimEnforceMode or "teleport"
    if mode == "teleport" then
        pcall(function()
            local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if hrp then
                local dir = (lookDir and (lookDir.Magnitude > 0 and lookDir.Unit) or nil) or Vector3.new(0,0,1)
                hrp.CFrame = CFrame.new(targetVec + Vector3.new(0,2,0), targetVec + Vector3.new(0,2,0) + dir)
                pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
            end
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end)
        return true
    else
        -- Use MoveTo only (walk enforcement)
        -- temporarily hide nearby obstructing parts/models to avoid getting stuck
        local function tempHideNearby(radius)
            local hidden = {}
            local root = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso"))
            if not root then return hidden end
            local origin = root.Position
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.CanCollide and obj.Transparency < 1 then
                    local d = (obj.Position - origin).Magnitude
                    if d <= (radius or 8) then
                        hidden[#hidden+1] = {obj = obj, cancollide = obj.CanCollide, trans = obj.Transparency}
                        pcall(function() obj.CanCollide = false; obj.Transparency = math.min(1, obj.Transparency + 0.6) end)
                    end
                end
            end
            return hidden
        end
        local function restoreHidden(hidden)
            if not hidden then return end
            for _, v in ipairs(hidden) do
                pcall(function()
                    if v.obj and v.obj.Parent then
                        v.obj.CanCollide = v.cancollide
                        v.obj.Transparency = v.trans
                    end
                end)
            end
        end
        local hiddenSaved = nil
        if (SETTINGS.claimEnforceMode or "walk") == "walk" then
            hiddenSaved = tempHideNearby(8)
        end
        local ok, started = pcall(function() return hum:MoveTo(targetVec) end)
        if not ok then return false end
        for i=1,12 do
            task.wait(0.08)
            local curHrp = (LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso")))
            if curHrp and (curHrp.Position - targetVec).Magnitude <= 3 then
                -- ensure facing direction after walking
                if lookDir and lookDir.Magnitude > 0 then
                    pcall(function()
                        curHrp.CFrame = CFrame.new(curHrp.Position, curHrp.Position + lookDir.Unit)
                    end)
                end
                if hiddenSaved then restoreHidden(hiddenSaved) end
                return true
            end
        end
        if hiddenSaved then restoreHidden(hiddenSaved) end
        return false
    end
end

-- Compute a reliable center and principal axis for a stand using its BasePart children
local function getStandCenterAndPrincipalAxis(stand)
    if not stand then return nil, nil end
    local pts = {}
    for _, v in ipairs(stand:GetDescendants()) do
        if v:IsA("BasePart") then
            pts[#pts+1] = v.Position
        end
    end
    if #pts == 0 then return nil, nil end
    local n = #pts
    local mean = Vector3.new(0,0,0)
    for _, p in ipairs(pts) do mean = mean + p end
    mean = mean / n
    -- covariance matrix (3x3)
    local c11,c12,c13,c21,c22,c23,c31,c32,c33 = 0,0,0,0,0,0,0,0,0
    for _, p in ipairs(pts) do
        local d = p - mean
        c11 = c11 + d.X * d.X
        c12 = c12 + d.X * d.Y
        c13 = c13 + d.X * d.Z
        c21 = c21 + d.Y * d.X
        c22 = c22 + d.Y * d.Y
        c23 = c23 + d.Y * d.Z
        c31 = c31 + d.Z * d.X
        c32 = c32 + d.Z * d.Y
        c33 = c33 + d.Z * d.Z
    end
    -- power iteration to approximate principal eigenvector
    local v = Vector3.new(1,0,0)
    for i=1,10 do
        local x = c11 * v.X + c12 * v.Y + c13 * v.Z
        local y = c21 * v.X + c22 * v.Y + c23 * v.Z
        local z = c31 * v.X + c32 * v.Y + c33 * v.Z
        local nv = Vector3.new(x,y,z)
        if nv.Magnitude <= 1e-6 then break end
        v = nv.Unit
    end
    return mean, v
end

-- Compute a placement position in front of a stand and an away direction to face
local function computeStandPlacement(stand, playerPos, distanceAway)
    distanceAway = tonumber(distanceAway) or 4.5
    local pivot = tryGetPivotPosition(stand) or nil
    -- fallback pivot to center/principal axis if missing
    local standCFrame
    pcall(function()
        if type(stand.GetPivot) == "function" then
            standCFrame = stand:GetPivot()
        elseif stand.PrimaryPart then
            standCFrame = stand.PrimaryPart.CFrame
        end
    end)
    local frontDir
    if standCFrame then
        frontDir = standCFrame.LookVector
        if pivot == nil then pivot = standCFrame.Position end
    else
        local center, axis = getStandCenterAndPrincipalAxis(stand)
        if center and axis then
            if pivot == nil then pivot = center end
            frontDir = Vector3.new(axis.X, 0, axis.Z)
            if frontDir.Magnitude <= 1e-6 then frontDir = nil end
        end
    end
    if not pivot then
        -- as last resort search for any part position
        for _, v in ipairs(stand:GetDescendants()) do
            if v:IsA("BasePart") then pivot = v.Position; break end
        end
    end
    if not frontDir then
        if playerPos then
            frontDir = Vector3.new(playerPos.X - pivot.X, 0, playerPos.Z - pivot.Z)
        end
        if not frontDir or frontDir.Magnitude <= 1e-6 then
            frontDir = Vector3.new(0,0,-1)
        end
    end
    frontDir = Vector3.new(frontDir.X, 0, frontDir.Z)
    if frontDir.Magnitude <= 1e-6 then frontDir = Vector3.new(0,0,-1) end
    frontDir = frontDir.Unit
    local basePos = pivot - frontDir * (distanceAway + 1.0) + Vector3.new(0,2,0)
    local awayDir = (basePos - pivot)
    if awayDir.Magnitude <= 1e-6 then awayDir = frontDir end
    return basePos, awayDir.Unit
end

-- Check whether the local player is registered as owner on any stand
local function localPlayerOwnsAnyStand()
    local standsFolder = Workspace:FindFirstChild("Stands")
    if not standsFolder then return false end
    for _, stand in ipairs(standsFolder:GetChildren()) do
        if stand and stand.Parent then
            local ownerObj = stand:FindFirstChild("Wner") or stand:FindFirstChild("Owner")
            if ownerObj then
                if ownerObj:IsA("ObjectValue") and ownerObj.Value == LocalPlayer then
                    return true
                end
                if ownerObj:IsA("StringValue") and tostring(ownerObj.Value) == tostring(LocalPlayer.Name) then
                    return true
                end
                if (ownerObj:IsA("IntValue") or ownerObj:IsA("NumberValue")) and tonumber(ownerObj.Value) == tonumber(LocalPlayer.UserId) then
                    return true
                end
            end
        end
    end
    return false
end

-- Global simple range parser used outside UI
local function parseRangeGlobal(str)
    if not str or type(str) ~= "string" then return nil end
    -- support formats: "MIN-MAX" or a single number meaning 1-MAX
    local a,b = str:match("%s*(%d+)%s*%-%s*(%d+)%s*")
    if a and b then
        local mn = tonumber(a)
        local mx = tonumber(b)
        if not mn or not mx then return nil end
        if mn < 0 then mn = 0 end
        if mx < mn then return nil end
        return mn, mx
    end
    local single = str:match("%s*(%d+)%s*")
    if single then
        local mx = tonumber(single)
        if not mx then return nil end
        if mx < 1 then return nil end
        return 1, mx
    end
    return nil
end

local claimLock = false
local function claimEmptyStands()
    if claimLock then return false end
    claimLock = true
    local function _run()
    -- stop any prior monitor while attempting a new claim
    pcall(function() stopClaimMonitor() end)
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

    -- teleport/move a few studs directly in front of the chosen stand pivot (use stand orientation when available)
    local distanceAway = 4.5 -- studs away from pivot (increase to avoid being too near)
    local basePos, awayDir = computeStandPlacement(target.stand, playerPos, distanceAway)
    local safePos = basePos or (target.pivot + Vector3.new(0, 2, 0))
    local dir = awayDir or (playerPos and (Vector3.new(playerPos.X - target.pivot.X, 0, playerPos.Z - target.pivot.Z).Unit) ) or Vector3.new(0, 0, -1)
    -- move directly in front of the booth (no teleport)
    moveCharacterToPosition(safePos, SETTINGS.claimEnforceMode or "teleport", dir)
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
            -- place character directly in front of the booth and orient them looking away from it
            pcall(function()
                local char = LocalPlayer.Character
                if char and target and target.pivot then
                        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                        if hrp then
                            -- attempt to use stand orientation when available for nicer placement
                            local standCFrame
                            pcall(function()
                                if type(target.stand.GetPivot) == "function" then
                                    standCFrame = target.stand:GetPivot()
                                elseif target.stand.PrimaryPart then
                                    standCFrame = target.stand.PrimaryPart.CFrame
                                end
                            end)
                            local basePos
                            local frontDir
                            if hrp then
                                        local basePos, awayDir = computeStandPlacement(target.stand, playerPos, distanceAway)
                                        if basePos and awayDir then
                                            -- move using configured mode and orient to face away from the booth
                                            pcall(function() moveCharacterToPosition(basePos, SETTINGS.claimEnforceMode or "teleport", awayDir) end)
                                            pcall(function()
                                                notify("Claim Monitor", "Monitoring claimed booth position", 2)
                                                startClaimMonitor(target.stand, basePos, awayDir)
                                            end)
                                        end
                            end
                        end
                end
            end)
            -- after initial success and placement, notify and verify ownership; if not owned, server hop
            pcall(function()
                postWebhookEvent("claim", { slot = slot, result = res })
            end)
            task.wait(0.35)
            local owned = false
            pcall(function() owned = localPlayerOwnsAnyStand() end)
            if not owned then
                local hopRange = tostring(SETTINGS.hopRange or "19-22")
                local mn, mx = parseRangeGlobal(hopRange)
                notify("Booth Claim", "Claim not confirmed; server hopping to find available booth.", 5)
                if mn then
                    serverHopNow(mn, mx, true)
                end
            end
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

-- Ensure we only complete a single successful claim per script load to avoid duplicates
local _CLAIM_HAS_RUN = _CLAIM_HAS_RUN or false
local function claimBooth()
    if _CLAIM_HAS_RUN then return false end
    local ok, res = pcall(claimEmptyStands)
    -- if the claim executed successfully (returned true), mark as run
    if ok and res then
        _CLAIM_HAS_RUN = true
    end
    return ok, res
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
            -- support formats: "MIN-MAX" or a single number meaning 1-MAX
            local a,b = str:match("%s*(%d+)%s*%-%s*(%d+)%s*")
            if a and b then
                local mn = tonumber(a)
                local mx = tonumber(b)
                if not mn or not mx then return nil end
                if mn < 0 then mn = 0 end
                if mx < mn then return nil end
                return mn, mx
            end
            local single = str:match("%s*(%d+)%s*")
            if single then
                local mx = tonumber(single)
                if not mx then return nil end
                if mx < 1 then return nil end
                return 1, mx
            end
            return nil
        end
        local autoServerHopEnabled = false
        local autoServerHopTask = nil
        local manualHopRunning = false
        local manualHopTask = nil
        SETTINGS.persistToggles = SETTINGS.persistToggles or false

        local function SaveSettings()
            local data = {
                    webhookToggle = SETTINGS.webhookToggle,
                    webhookUrl = SETTINGS.webhookUrl,
                    antiAfk = SETTINGS.antiAfk,
                    spinOnDonation = SETTINGS.spinOnDonation,
                    spinDefaultSpeed = SETTINGS.spinDefaultSpeed,
                    spinSpeedMultiplier = SETTINGS.spinSpeedMultiplier,
                    touchPreventAFK = SETTINGS.touchPreventAFK,
                    claimEnforceMode = SETTINGS.claimEnforceMode,
                    hopRange = hopRangeText,
                    serverStayTime = serverStayTime,
                    persistToggles = SETTINGS.persistToggles,
                    emoteId = SETTINGS.emoteId,
                    emotePlaying = SETTINGS.emotePlaying and true or false,
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
            SETTINGS.spinOnDonation = decoded.spinOnDonation or SETTINGS.spinOnDonation
            SETTINGS.spinDefaultSpeed = tonumber(decoded.spinDefaultSpeed) or SETTINGS.spinDefaultSpeed
            SETTINGS.spinSpeedMultiplier = tonumber(decoded.spinSpeedMultiplier) or SETTINGS.spinSpeedMultiplier
            SETTINGS.touchPreventAFK = decoded.touchPreventAFK or SETTINGS.touchPreventAFK
            SETTINGS.claimEnforceMode = decoded.claimEnforceMode or SETTINGS.claimEnforceMode
            hopRangeText = decoded.hopRange or hopRangeText
            serverStayTime = tonumber(decoded.serverStayTime) or serverStayTime
            SETTINGS.persistToggles = decoded.persistToggles or SETTINGS.persistToggles
            SETTINGS.emoteId = decoded.emoteId or SETTINGS.emoteId
            SETTINGS.emotePlaying = decoded.emotePlaying or SETTINGS.emotePlaying
            autoServerHopEnabled = decoded.autoServerHop or autoServerHopEnabled
        end

        pcall(function()
            if type(_G) == "table" and type(_G.__PLS_WAIT_CONFIG) == "table" then
                local cfg = _G.__PLS_WAIT_CONFIG
                SETTINGS.webhookToggle = cfg.webhookToggle or SETTINGS.webhookToggle
                SETTINGS.webhookUrl = cfg.webhookUrl or SETTINGS.webhookUrl
                SETTINGS.antiAfk = cfg.antiAfk or SETTINGS.antiAfk
                SETTINGS.touchPreventAFK = cfg.touchPreventAFK or SETTINGS.touchPreventAFK
                serverStayTime = tonumber(cfg.serverStayTime) or serverStayTime
                SETTINGS.persistToggles = cfg.persistToggles or SETTINGS.persistToggles
                hopRangeText = cfg.hopRange or hopRangeText
                SETTINGS.emoteId = cfg.emoteId or SETTINGS.emoteId
                autoServerHopEnabled = cfg.autoServerHop or autoServerHopEnabled
                -- coerce and apply spin default from queued config (ensure numeric and sane default)
                if cfg.spinDefaultSpeed then
                    SETTINGS.spinDefaultSpeed = tonumber(cfg.spinDefaultSpeed) or SETTINGS.spinDefaultSpeed
                end
                SETTINGS.spinOnDonation = cfg.spinOnDonation or SETTINGS.spinOnDonation
                SETTINGS.spinSpeedMultiplier = tonumber(cfg.spinSpeedMultiplier) or SETTINGS.spinSpeedMultiplier
                _G.__PLS_WAIT_CONFIG = nil
            end
        end)

        pcall(LoadSettings)
        -- Ensure spin default is numeric and apply initial xspin (default to 1)
        SETTINGS.spinDefaultSpeed = tonumber(SETTINGS.spinDefaultSpeed) or 1
        if not SETTINGS.spinDefaultSpeed or SETTINGS.spinDefaultSpeed < 1 then
            SETTINGS.spinDefaultSpeed = 1
        end
        xspin = (tonumber(SETTINGS.spinDefaultSpeed) or 1) * (tonumber(SETTINGS.spinSpeedMultiplier) or 1)
        -- (initialization guard will be checked after SharedEnv is defined)
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

        -- Prevent duplicate UIs across teleports / multiple runs: use a shared env flag
        local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
        -- If the script was already initialized elsewhere, allow re-init (some executors persist getgenv across teleports)
        if SharedEnv.PLS_WAIT_SCRIPT_LOADED then
            -- clear previous marker and allow re-initialization so UI reliably appears after queue_on_teleport
            pcall(function() SharedEnv.PLS_WAIT_SCRIPT_LOADED = nil end)
        end
        SharedEnv.PLS_WAIT_SCRIPT_LOADED = true
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

        -- Mini toggle button for open/close (persistent, outside mainFrame)
        local uiToggle = Instance.new("ImageButton")
        uiToggle.Name = "PlsWaitToggle"
        uiToggle.Size = UDim2.new(0, 56, 0, 56)
        uiToggle.Position = UDim2.new(0, 12, 1, -76)
        uiToggle.AnchorPoint = Vector2.new(0,0)
        uiToggle.BackgroundColor3 = Color3.fromRGB(30,30,30)
        uiToggle.Image = ""
        uiToggle.Parent = screen
        local togCorner = Instance.new("UICorner") togCorner.Parent = uiToggle
        local togLabel = Instance.new("TextLabel")
        togLabel.Text = ""
        togLabel.Size = UDim2.new(1,0,1,0)
        togLabel.BackgroundTransparency = 1
        togLabel.TextTransparency = 1
        togLabel.TextColor3 = Color3.fromRGB(220,220,220)
        togLabel.Font = Enum.Font.GothamBold
        togLabel.TextSize = 14
        togLabel.Parent = uiToggle
        uiToggle.Visible = true

        -- Glassy admin-panel style layout (smaller width for compact UI)
        local MAIN_W, MAIN_H = 620, 420
        local LEFT_W = 200
        local GAP = 16
        local mainFrame = Instance.new("Frame")
        mainFrame.Name = "MainFrame"
        mainFrame.Size = UDim2.new(0, MAIN_W, 0, MAIN_H)
        -- position bottom-left, keep margin and ensure it's visible on mobile
        mainFrame.AnchorPoint = Vector2.new(0, 1)
        mainFrame.Position = UDim2.new(0, 12, 1, -12)
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
        -- Title bar (draggable on PC and mobile) - reduced height to avoid covering UI
        local titleBar = Instance.new("Frame")
        titleBar.Name = "TitleBar"
        titleBar.Size = UDim2.new(1, 0, 0, 28)
        titleBar.Position = UDim2.new(0, 0, 0, 0)
        titleBar.BackgroundColor3 = Color3.fromRGB(50,205,50)
        titleBar.BackgroundTransparency = 0
        titleBar.Parent = mainFrame
        titleBar.Active = true
        titleBar.ZIndex = 50
        local titleLblTop = Instance.new("TextLabel")
        titleLblTop.Size = UDim2.new(1, -48, 0, 28)
        titleLblTop.Position = UDim2.new(0, 12, 0, 0)
        titleLblTop.BackgroundTransparency = 1
        titleLblTop.Text = "Pls Wait 💵"
        titleLblTop.Font = Enum.Font.GothamBold
        titleLblTop.TextSize = 14
        titleLblTop.TextColor3 = Color3.fromRGB(240,240,240)
        titleLblTop.TextXAlignment = Enum.TextXAlignment.Left
        titleLblTop.Parent = titleBar

        -- Add a close/minimize button in the title bar
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 32, 0, 20)
        closeBtn.Position = UDim2.new(1, -44, 0, 4)
        closeBtn.Text = "_"
        closeBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
        closeBtn.TextColor3 = Color3.fromRGB(240,240,240)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 16
        closeBtn.Parent = titleBar
        styleButton(closeBtn)

        -- (dropdown/collapse button removed as it was non-functional)

        -- Dragging logic (mouse + touch)
        do
            local dragging = false
            local dragInput = nil
            local dragStart = nil
            local startPos = nil
            local function update(input)
                local delta = input.Position - dragStart
                local newX = startPos.X.Offset + delta.X
                local newY = startPos.Y.Offset + delta.Y
                mainFrame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
            end
            titleBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragStart = input.Position
                    startPos = mainFrame.Position
                    dragInput = input
                    input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                            dragging = false
                        end
                    end)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if input == dragInput and dragging then
                    pcall(update, input)
                end
            end)
            -- store original mainFrame position for restore animations
            local originalMainPos = mainFrame.Position
            local minimized = false
            local TweenService = game:GetService("TweenService")
            local function minimizeUI()
                if minimized then return end
                minimized = true
                -- fly into toggle button
                local targetPos = uiToggle.Position
                local info = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                pcall(function() TweenService:Create(mainFrame, info, { Position = targetPos, Size = UDim2.new(0,40,0,40) }):Play() end)
                task.delay(0.45, function() mainFrame.Visible = false end)
            end
            local function restoreUI()
                if not minimized then return end
                mainFrame.Visible = true
                local info = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                pcall(function() TweenService:Create(mainFrame, info, { Position = originalMainPos, Size = UDim2.new(0, MAIN_W, 0, MAIN_H) }):Play() end)
                task.delay(0.45, function() minimized = false end)
            end
            closeBtn.MouseButton1Click:Connect(function()
                if minimized then restoreUI() else minimizeUI() end
            end)
            uiToggle.MouseButton1Click:Connect(function()
                if minimized then restoreUI() else minimizeUI() end
            end)
        end
        local mainCorner = Instance.new("UICorner")
        mainCorner.CornerRadius = UDim.new(0,12)
        mainCorner.Parent = mainFrame

        -- Simplified flat background (squiggle layers removed per user request)
        mainFrame.BackgroundTransparency = 0
        mainFrame.BackgroundColor3 = Color3.fromRGB(22,22,22)
        mainFrame.ZIndex = 5

        -- Left menu column
        local leftCol = Instance.new("Frame")
        leftCol.Name = "LeftCol"
        leftCol.Size = UDim2.new(0, LEFT_W, 1, -20)
        -- lower left column so the titlebar doesn't overlap the first button
        leftCol.Position = UDim2.new(0, GAP, 0, 40)
        leftCol.BackgroundTransparency = 1
        leftCol.Parent = mainFrame
        -- old left-column title removed (we use the draggable title bar)

        -- left menu buttons (use UIListLayout for stable layout)
        local leftList = Instance.new("UIListLayout")
        leftList.SortOrder = Enum.SortOrder.LayoutOrder
        leftList.Padding = UDim.new(0, 12)
        leftList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        leftList.VerticalAlignment = Enum.VerticalAlignment.Top
        leftList.Parent = leftCol

        local menu = { {key="Main", icon="📋", text="Overview"}, {key="ServerHop", icon="🔀", text="Server Hop"}, {key="Webhook", icon="🔔", text="Webhook"} }
        local tabButtons = {}
        local tabFrames = {}
        for i, item in ipairs(menu) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -12, 0, 40)
            btn.LayoutOrder = i
            btn.Text = (item.icon .. "  " .. item.text)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 16
            btn.TextColor3 = Color3.fromRGB(220,220,220)
            btn.TextXAlignment = Enum.TextXAlignment.Center
            btn.BackgroundColor3 = Color3.fromRGB(28,28,28)
            btn.AutoButtonColor = false
            local corner = Instance.new("UICorner") corner.Parent = btn
            btn.Parent = leftCol
            tabButtons[item.key] = btn

            local frame = Instance.new("Frame")
            local rightW = MAIN_W - LEFT_W - (GAP * 2)
            frame.Size = UDim2.new(0, rightW, 1, -24)
            -- right-side frames aligned below titlebar
            frame.Position = UDim2.new(0, LEFT_W + GAP, 0, 40)
            frame.BackgroundTransparency = 1
            frame.Visible = (item.key == "Main")
            frame.Parent = mainFrame
            tabFrames[item.key] = frame
        end

        -- close button removed (dropdown provides collapse/close behavior)

        -- (fade-in will be prepared after the UI is fully constructed)
        -- invisible overlay used to capture taps when UI is dimmed (mobile reliable wake)
        local wakeOverlay = Instance.new("TextButton")
        wakeOverlay.Size = UDim2.new(1, 0, 1, 0)
        wakeOverlay.Position = UDim2.new(0, 0, 0, 0)
        wakeOverlay.BackgroundTransparency = 1
        wakeOverlay.AutoButtonColor = false
        wakeOverlay.Visible = false
        wakeOverlay.ZIndex = 1000
        wakeOverlay.Parent = mainFrame

        -- Interaction listener: dimming/inactivity feature removed per user request
        do
            local UIS = game:GetService("UserInputService")
            -- Keep a minimal listener to capture UI interactions if needed later
            UIS.InputBegan:Connect(function(input, processed)
                -- intentionally left blank: inactivity dimming disabled
            end)
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
            local rootFrame = tabFrames.Main
            -- Add a scrollable content area so Overview can fit many controls
            local content = Instance.new("ScrollingFrame")
            content.Name = "OverviewScroll"
            content.Size = UDim2.new(1, -12, 1, -12)
            content.Position = UDim2.new(0, 6, 0, 6)
            content.BackgroundTransparency = 1
            content.ScrollBarThickness = 8
            content.CanvasSize = UDim2.new(0,0,0,800)
            content.Parent = rootFrame
            local frame = content
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
            afkToggle.Position = UDim2.new(0,180,0,10)
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
            -- Claim enforcement mode (Teleport / Walk)
            local enforceLabel = Instance.new("TextLabel")
            enforceLabel.Size = UDim2.new(0,120,0,20)
            enforceLabel.Position = UDim2.new(0,10,0,308)
            enforceLabel.Text = "Enforce Mode"
            enforceLabel.TextColor3 = Color3.new(1,1,1)
            enforceLabel.BackgroundTransparency = 1
            enforceLabel.Parent = frame

            local enforceToggle = Instance.new("TextButton")
            enforceToggle.Size = UDim2.new(0,60,0,20)
            enforceToggle.Position = UDim2.new(0,180,0,308)
            enforceToggle.Text = (SETTINGS.claimEnforceMode == "teleport") and "TELEPORT" or "WALK"
            enforceToggle.BackgroundColor3 = Color3.fromRGB(34,177,76)
            enforceToggle.TextColor3 = Color3.fromRGB(255,255,255)
            local etCorner = Instance.new("UICorner") etCorner.Parent = enforceToggle
            enforceToggle.Parent = frame
            enforceToggle.MouseButton1Click:Connect(function()
                if SETTINGS.claimEnforceMode == "teleport" then
                    SETTINGS.claimEnforceMode = "walk"
                else
                    SETTINGS.claimEnforceMode = "teleport"
                end
                enforceToggle.Text = (SETTINGS.claimEnforceMode == "teleport") and "TELEPORT" or "WALK"
                pcall(SaveSettings)
            end)
            styleButton(enforceToggle)
            -- Emote selector / play (Overview)
            local emoteLabel = Instance.new("TextLabel")
            emoteLabel.Size = UDim2.new(0,120,0,20)
            emoteLabel.Position = UDim2.new(0,10,0,154)
            emoteLabel.Text = "Emote (asset id)"
            emoteLabel.TextColor3 = Color3.new(1,1,1)
            emoteLabel.BackgroundTransparency = 1
            emoteLabel.Parent = frame

            local emoteBox = Instance.new("TextBox")
            emoteBox.Size = UDim2.new(0,160,0,24)
            emoteBox.Position = UDim2.new(0,140,0,154)
            emoteBox.Text = tostring(SETTINGS.emoteId or "")
            emoteBox.PlaceholderText = "9527883498"
            emoteBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
            emoteBox.TextColor3 = Color3.fromRGB(255,255,255)
            local ebCorner = Instance.new("UICorner") ebCorner.Parent = emoteBox
            emoteBox.Parent = frame
            emoteBox.FocusLost:Connect(function()
                SETTINGS.emoteId = tostring(emoteBox.Text or "")
                pcall(SaveSettings)
                if SETTINGS.emoteId and tostring(SETTINGS.emoteId) ~= "" then
                    pcall(function() playEmote(SETTINGS.emoteId) end)
                end
            end)

            local emotePlayBtn = Instance.new("TextButton")
            emotePlayBtn.Size = UDim2.new(0,80,0,24)
            emotePlayBtn.Position = UDim2.new(0,140,0,190)
            emotePlayBtn.Text = "Play"
            emotePlayBtn.BackgroundColor3 = Color3.fromRGB(52,152,219)
            emotePlayBtn.TextColor3 = Color3.fromRGB(255,255,255)
            emotePlayBtn.Parent = frame
            styleButton(emotePlayBtn)

            local emoteStopBtn = Instance.new("TextButton")
            emoteStopBtn.Size = UDim2.new(0,80,0,24)
            emoteStopBtn.Position = UDim2.new(0,228,0,190)
            emoteStopBtn.Text = "Stop"
            emoteStopBtn.BackgroundColor3 = Color3.fromRGB(192,57,43)
            emoteStopBtn.TextColor3 = Color3.fromRGB(255,255,255)
            emoteStopBtn.Parent = frame
            styleButton(emoteStopBtn)

            local presetToggle = Instance.new("TextButton")
            presetToggle.Size = UDim2.new(0,24,0,24)
            presetToggle.Position = UDim2.new(0,304,0,154)
            presetToggle.Text = "▾"
            presetToggle.BackgroundColor3 = Color3.fromRGB(40,40,40)
            presetToggle.TextColor3 = Color3.fromRGB(255,255,255)
            presetToggle.Parent = frame
            styleButton(presetToggle)

            local presetFrame = Instance.new("Frame")
            presetFrame.Position = UDim2.new(0,140,0,184)
            presetFrame.BackgroundTransparency = 0.15
            presetFrame.Visible = false
            presetFrame.Parent = frame
            presetFrame.BorderSizePixel = 0
            local pfCorner = Instance.new("UICorner") pfCorner.Parent = presetFrame

            local presetEmotes = {
                { name = "Annyeong", id = "9527883498" },
                { name = "Side To Side", id = "10714366910" },
                { name = "Twirl", id = "10714293450" },
                { name = "Uprise", id = "10275008655" },
                { name = "Victory", id = "10714171628" },
                { name = "Block Partier", id = "10713988674" },
                { name = "Shy", id = "10714369325" },
            }
            presetFrame.Size = UDim2.new(0,160,0, 28 * #presetEmotes)
            local function closePreset()
                presetFrame.Visible = false
            end
            presetToggle.MouseButton1Click:Connect(function()
                presetFrame.Visible = not presetFrame.Visible
            end)

            for i, p in ipairs(presetEmotes) do
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, -8, 0, 24)
                b.Position = UDim2.new(0, 4, 0, (i-1)*28)
                b.Text = (p.name .. " — " .. tostring(p.id))
                b.BackgroundColor3 = Color3.fromRGB(36,36,36)
                b.TextColor3 = Color3.fromRGB(230,230,230)
                b.Parent = presetFrame
                styleButton(b)
                b.MouseButton1Click:Connect(function()
                    emoteBox.Text = tostring(p.id)
                    SETTINGS.emoteId = tostring(p.id)
                    pcall(SaveSettings)
                    closePreset()
                end)
            end

            -- emote playback helper
            local currentEmoteTrack = nil
            local function stopEmote()
                if currentEmoteTrack then
                    pcall(function() currentEmoteTrack:Stop() end)
                    pcall(function() currentEmoteTrack:Destroy() end)
                    currentEmoteTrack = nil
                end
                SETTINGS.emotePlaying = false
                pcall(SaveSettings)
            end

            local function playEmote(id)
                if not id or tostring(id) == "" then return false end
                local ok, char = pcall(function() return LocalPlayer.Character end)
                if not ok or not char then
                    return false
                end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum then return false end
                -- ensure Animator exists (some rigs may be missing one initially)
                local animator = hum:FindFirstChildOfClass("Animator")
                if not animator then
                    pcall(function()
                        animator = Instance.new("Animator")
                        animator.Parent = hum
                    end)
                end
                pcall(function()
                    if currentEmoteTrack then
                        pcall(function() currentEmoteTrack:Stop() end)
                        pcall(function() currentEmoteTrack:Destroy() end)
                        currentEmoteTrack = nil
                    end
                    local anim = Instance.new("Animation")
                    anim.AnimationId = ("rbxassetid://%s"):format(tostring(id))
                    local track = nil
                    if animator and animator.LoadAnimation then
                        track = animator:LoadAnimation(anim)
                    else
                        track = hum:LoadAnimation(anim)
                    end
                    if track then
                        pcall(function()
                            track.Priority = Enum.AnimationPriority.Action
                            track.Looped = true
                            currentEmoteTrack = track
                            task.wait(0.05)
                            track:Play()
                        end)
                        SETTINGS.emotePlaying = true
                        pcall(SaveSettings)
                    end
                end)
            end
            emotePlayBtn.MouseButton1Click:Connect(function()
                local id = tostring(emoteBox.Text or "")
                if id and id ~= "" then pcall(function() playEmote(id) end) end
            end)
            emoteStopBtn.MouseButton1Click:Connect(function()
                pcall(function() stopEmote() end)
            end)

            -- Auto-play emote toggle
            local autoEmoteLabel = Instance.new("TextLabel")
            autoEmoteLabel.Size = UDim2.new(0,120,0,20)
            autoEmoteLabel.Position = UDim2.new(0,10,0,232)
            autoEmoteLabel.Text = "Auto-Play Emote"
            autoEmoteLabel.BackgroundTransparency = 1
            autoEmoteLabel.TextColor3 = Color3.new(1,1,1)
            autoEmoteLabel.Parent = frame

            local autoEmoteToggle = Instance.new("TextButton")
            autoEmoteToggle.Size = UDim2.new(0,60,0,20)
            autoEmoteToggle.Position = UDim2.new(0,140,0,232)
            autoEmoteToggle.Text = SETTINGS.emotePlaying and "ON" or "OFF"
            autoEmoteToggle.BackgroundColor3 = Color3.fromRGB(34,177,76)
            autoEmoteToggle.TextColor3 = Color3.fromRGB(255,255,255)
            autoEmoteToggle.Parent = frame
            local aec = Instance.new("UICorner") aec.Parent = autoEmoteToggle
            styleButton(autoEmoteToggle)
            autoEmoteToggle.MouseButton1Click:Connect(function()
                SETTINGS.emotePlaying = not SETTINGS.emotePlaying
                autoEmoteToggle.Text = SETTINGS.emotePlaying and "ON" or "OFF"
                pcall(SaveSettings)
                if SETTINGS.emotePlaying and SETTINGS.emoteId and tostring(SETTINGS.emoteId) ~= "" then
                    pcall(function() playEmote(SETTINGS.emoteId) end)
                else
                    pcall(function() stopEmote() end)
                end
            end)
            -- Spin controls removed
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
            rangeLabel.Size = UDim2.new(0,140,0,20)
            rangeLabel.Position = UDim2.new(0,10,0,48)
            rangeLabel.Text = "Hop Range (1-23P)"
            rangeLabel.BackgroundTransparency = 1
            rangeLabel.TextColor3 = Color3.new(1,1,1)
            rangeLabel.Parent = frame

            local rangeBox = Instance.new("TextBox")
            rangeBox.Size = UDim2.new(0,160,0,28)
            rangeBox.Position = UDim2.new(0,140,0,44)
            rangeBox.Text = hopRangeText or "1-23"
            rangeBox.PlaceholderText = "1-23 or 23"
            rangeBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
            rangeBox.TextColor3 = Color3.fromRGB(255,255,255)
            local rbCorner = Instance.new("UICorner")
            rbCorner.Parent = rangeBox
            rangeBox.Parent = frame
            rangeBox.FocusLost:Connect(function()
                local txt = tostring(rangeBox.Text or "")
                local lowered = txt:lower():gsub("%s+", "")
                if lowered == "any" or lowered == "" then
                    hopRangeText = txt
                    pcall(SaveSettings)
                    return
                end
                local mn,mx = parseRange(txt)
                if not mn then
                    notify("Server Hop", "Invalid range format. Use N or MIN-MAX or 'any' e.g. 23 or 11-22", 4)
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
                local txt = (rangeBox and tostring(rangeBox.Text) or hopRangeText) or ""
                local mn, mx = nil, nil
                local lowered = (txt or ""):lower():gsub("%s+", "")
                if lowered == "any" or lowered == "" then
                    mn, mx = nil, nil
                else
                    mn, mx = parseRange(txt)
                    if not mn then
                        notify("Server Hop", "Invalid hop range (use N, MIN-MAX or 'any').", 4)
                        return
                    end
                end
                hopRangeText = txt
                pcall(SaveSettings)
                -- Start aggressive search loop (non-toggle). Button disabled during search.
                pcall(function() hopBtn.Active = false; hopBtn.Text = "Searching..." end)
                manualHopTask = task.spawn(function()
                    while true do
                        local ok = serverSearchAttempt(mn, mx, true)
                        if ok then break end
                        task.wait(0.5)
                    end
                    pcall(function() hopBtn.Active = true; hopBtn.Text = "Server Hop Now" end)
                end)
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
            urlBox.TextXAlignment = Enum.TextXAlignment.Left
            urlBox.ClearTextOnFocus = false
            urlBox.TextWrapped = false
            urlBox.Parent = frame
            urlBox.FocusLost:Connect(function()
                SETTINGS.webhookUrl = tostring(urlBox.Text or "")
                pcall(SaveSettings)
            end)

            -- donation stat name textbox removed per user request
        end

        -- Fade-in removed: UI elements appear immediately (user requested no fade)

        if SETTINGS.webhookToggle then
            startDonationMonitor()
            pcall(function()
                local playersOnline = tostring(#Players:GetPlayers())
                local range = tostring(hopRangeText or "any")
                -- send simple serverhop notifier as requested: @local.user serverhopped
                local uname = tostring(LocalPlayer and LocalPlayer.Name or "Unknown")
                pcall(function() sendPlainWebhook("@"..uname.." serverhopped") end)
            end)
        end
        -- If user requested persistence across hops, ensure queue_on_teleport is set now
        pcall(function()
            if SETTINGS.persistToggles then
                local ok2, cfgJson = pcall(function()
                    return Http:JSONEncode({
                        webhookToggle = SETTINGS.webhookToggle,
                        webhookUrl = SETTINGS.webhookUrl,
                        antiAfk = SETTINGS.antiAfk,
                        serverStayTime = SETTINGS.serverStayTime,
                        persistToggles = SETTINGS.persistToggles,
                        emoteId = SETTINGS.emoteId,
                        emotePlaying = SETTINGS.emotePlaying and true or false,
                        autoServerHop = autoServerHopEnabled,
                    })
                end)
                local qcore = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua"))()'
                local qcode = qcore
                if ok2 and cfgJson then
                    qcode = ("(function() local _json = %q; local ok,cfg = pcall(function() return game:GetService('HttpService'):JSONDecode(_json) end); if ok and type(cfg)=='table' then _G.__PLS_WAIT_CONFIG = cfg end; local f,err = loadstring(game:HttpGet('https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua')); if f then pcall(f) else warn(err) end end)()"):format(cfgJson)
                end
                pcall(function() ensureQueuedScript(qcode) end)
            end
        end)
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
        -- initialize persistent spin if enabled
        if SETTINGS.spinOnDonation then
            xspin = (tonumber(SETTINGS.spinDefaultSpeed) or 1) * (tonumber(SETTINGS.spinSpeedMultiplier) or 1)
            pcall(ensurePersistentSpin)
            LocalPlayer.CharacterAdded:Connect(function()
                task.wait(0.6)
                pcall(function()
                    xspin = tonumber(SETTINGS.spinDefaultSpeed) or 1
                    ensurePersistentSpin()
                end)
            end)
        end
        -- Touch-prevent AFK removed per user request; keep Anti-AFK toggle only
        -- periodic jump feature removed
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
