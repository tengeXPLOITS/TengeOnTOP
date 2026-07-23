-- PLS WAIT - Custom script scaffold for place 14212732626
-- Created: scaffold for user's booth claiming code integration

repeat task.wait() until game:IsLoaded()

-- Core services (ensure HttpService and httprequest available for community checks)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local GroupService = game:GetService("GroupService")
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- Run only for games associated with this community (X-Stud-os)
local COMMUNITY_ID = 32815300
local PLACE_ID = tonumber(game.PlaceId) or 0

local function IsInCommunity()
    if game.CreatorId == COMMUNITY_ID and game.CreatorType == Enum.CreatorType.Group then
        return true
    end
    local ok, res = pcall(function()
        local url = "https://games.roblox.com/v1/games/multiget-place-details?placeIds=" .. tostring(game.PlaceId)
        local body = nil
        if httprequest then
            local r = httprequest({Url = url, Method = "GET", Headers = { ["User-Agent"] = "Roblox" }})
            body = r and (r.Body or r.body or r.responseBody or r.text)
        else
            body = HttpService:GetAsync(url)
        end
        if body then
            local decoded = HttpService:JSONDecode(body)
            if decoded and decoded[1] and decoded[1].universeId then
                return game.CreatorId == COMMUNITY_ID
            end
        end
        return false
    end)
    return ok and res
end

if not IsInCommunity() then
    warn("❌ This script is restricted to the specified community games only. Aborting.")
    return
end

SETTINGS = SETTINGS or {}
-- Webhook / donation helpers
SETTINGS.antiAfk = SETTINGS.antiAfk or false
SETTINGS.serverStayTime = SETTINGS.serverStayTime or 30
SETTINGS.persistToggles = SETTINGS.persistToggles or false
local touchEnabled = UserInputService and UserInputService.TouchEnabled
SETTINGS.touchPreventAFK = SETTINGS.touchPreventAFK or (touchEnabled and true or false)
SETTINGS.staffHop = SETTINGS.staffHop or false
SETTINGS.spinOnDonation = SETTINGS.spinOnDonation or false
SETTINGS.spinSet = SETTINGS.spinSet or SETTINGS.spinOnDonation or false
SETTINGS.spinSpeedMultiplier = SETTINGS.spinSpeedMultiplier or 1
-- claimEnforceMode option removed; enforcement defaults to teleport
SETTINGS.emotePlaying = SETTINGS.emotePlaying or false
local DEFAULT_BOOTH_TEXT = '<font color="#3afdd6" face="Arial">💸i am satisfied with any amount of R$ you give me (: 💸</font>'
SETTINGS.boothText = SETTINGS.boothText or DEFAULT_BOOTH_TEXT

donationConns = donationConns or {}
donationEnabled = donationEnabled or false
donationTotals = donationTotals or {}
donationStatName = donationStatName or "Raised"

local STAFF_ROLES = { Developer = true, Moderator = true }

local function getPlayerRole(player)
    if not player or not player:IsA("Player") then return nil end
    local ok, role = pcall(function()
        return player:GetRoleInGroup(COMMUNITY_ID)
    end)
    if ok and type(role) == "string" and role ~= "" then
        return role
    end
    return nil
end

local function isStaffRole(role)
    return type(role) == "string" and STAFF_ROLES[role]
end

local function checkServerForStaff()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local role = getPlayerRole(player)
            if isStaffRole(role) then
                return player, role
            end
        end
    end
    return nil, nil
end

local function hopIfStaffPresent()
    if not SETTINGS.staffHop then
        return
    end
    local staffPlayer, staffRole = checkServerForStaff()
    if staffPlayer and staffRole then
        notify("Staff Detected", ("Detected %s (%s) in server; hopping immediately."):format(staffPlayer.Name, staffRole), 5)
        task.spawn(function()
            pcall(function() serverHopNow(nil, nil, true) end)
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    task.wait(1)
    if not SETTINGS.staffHop then
        return
    end
    local role = getPlayerRole(player)
    if isStaffRole(role) then
        hopIfStaffPresent()
    end
end)

task.spawn(function()
    task.wait(2)
    hopIfStaffPresent()
end)

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

-- Community place lookup and basic server-hop helper
local function getCommunityPlaceIds()
    local placeIds = {}
    local seen = {}
    local function addId(id)
        local n = tonumber(id)
        if n and n > 0 and not seen[n] then
            seen[n] = true
            table.insert(placeIds, n)
        end
    end

    addId(game.PlaceId)
    local ok, res = pcall(function()
        local url = ("https://games.roblox.com/v1/groups/%s/games?accessFilter=Public&limit=100"):format(tostring(COMMUNITY_ID))
        if httprequest then
            local r = httprequest({Url = url, Method = "GET", Headers = { ["User-Agent"] = "Roblox" }})
            return r and (r.Body or r.body or r.responseBody or r.text)
        else
            return HttpService:GetAsync(url)
        end
    end)

    if ok and res then
        pcall(function()
            local decoded = HttpService:JSONDecode(res)
            if decoded and decoded.data then
                for _, v in ipairs(decoded.data) do
                    addId(v.id or v.placeId or v.place_id)
                end
            end
        end)
    end

    return placeIds
end

local function fetchServerList(placeId)
    local url = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Desc&limit=100"
    local ok, res = pcall(function()
        if httprequest then
            local r = httprequest({Url = url, Method = "GET", Headers = { ["User-Agent"] = "Roblox" }})
            return r and (r.Body or r.body or r.responseBody or r.text)
        elseif type(HttpService.GetAsync) == "function" then
            return HttpService:GetAsync(url)
        else
            return game:HttpGet(url)
        end
    end)
    if ok and res then
        local decoded = nil
        pcall(function() decoded = HttpService:JSONDecode(res) end)
        return decoded
    end
    return nil
end

local function serverHopNow(minPlayers, maxPlayers)
    minPlayers = tonumber(minPlayers) or 0
    maxPlayers = tonumber(maxPlayers) or 0

    local placeIds = getCommunityPlaceIds()
    if not placeIds or #placeIds == 0 then
        notify("No community place IDs found for hop.")
        return false
    end

    for _, placeId in ipairs(placeIds) do
        local list = fetchServerList(placeId)
        if list and type(list.data) == "table" then
            local candidates = {}
            for _, s in ipairs(list.data) do
                local playing = tonumber(s.playing or 0) or 0
                if tostring(s.id) ~= tostring(game.JobId) then
                    if (minPlayers <= 0 or playing >= minPlayers) and (maxPlayers <= 0 or playing <= maxPlayers) then
                        table.insert(candidates, s)
                    end
                end
            end
            if #candidates > 0 then
                local target = candidates[math.random(1, #candidates)]
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(placeId, target.id, LocalPlayer)
                end)
                return true
            end
        end
        task.wait(0.2)
    end

    notify("No matching servers found for community hop.")
    return false
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
        local pending = math.floor(amount * 0.6)
        local fields = {
            { name = "Donor", value = donorName, inline = false },
            { name = "Amount", value = tostring(amount), inline = true },
            { name = "Pending (60%)", value = tostring(pending), inline = true },
        }
        table.insert(embeds, {
            title = "Donation Received",
            color = 0x00FF00,
            fields = fields,
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
        if performHttpRequest then
            performHttpRequest({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif syn and syn.request then
            syn.request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif request then
            request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif http_request then
            http_request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        else
            HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
        end
    end)
end

local function applyDonationSpin(delta)
    if not SETTINGS.spinSet or type(delta) ~= "number" or delta <= 0 then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return end
    local spinPart = root:FindFirstChild("Spin")
    if not spinPart or not spinPart:IsA("BodyAngularVelocity") then
        spinPart = Instance.new("BodyAngularVelocity")
        spinPart.Name = "Spin"
        spinPart.MaxTorque = Vector3.new(0, math.huge, 0)
        spinPart.Parent = root
        spinPart.AngularVelocity = Vector3.new(0, 0.25 * (SETTINGS.spinSpeedMultiplier or 1), 0)
    end
    if spinPart and spinPart:IsA("BodyAngularVelocity") then
        local currentY = tonumber(spinPart.AngularVelocity.Y) or 0
        local averageDelta = delta / 3
        spinPart.AngularVelocity = Vector3.new(0, currentY + averageDelta * (SETTINGS.spinSpeedMultiplier or 1), 0)
        pcall(function()
            notify("Donation Debug", ("spin updated +%d -> %0.2f"):format(delta, spinPart.AngularVelocity.Y), 4)
        end)
    end
end

local function sendPlainWebhook(msg)
    if not SETTINGS.webhookToggle or not SETTINGS.webhookUrl or SETTINGS.webhookUrl == "" then return end
    local url = tostring(SETTINGS.webhookUrl or "")
    local payload = HttpService:JSONEncode({ content = tostring(msg or "") })
    pcall(function()
        if performHttpRequest then
            performHttpRequest({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
        elseif syn and syn.request then
            syn.request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
        elseif request then
            request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
        elseif http_request then
            http_request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
        else
            HttpService:PostAsync(url, payload, Enum.HttpContentType.ApplicationJson)
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
    if not ls then
        if player == LocalPlayer then pcall(function() notify("Donation Debug", "leaderstats not found for local player", 5) end) end
        return false
    end
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
    if not stat then
        if player == LocalPlayer then pcall(function() notify("Donation Debug", "no valid donation stat found", 5) end) end
        return false
    end
    if player == LocalPlayer then
        pcall(function()
            notify("Donation Debug", ("hooked %s (%s) = %d"):format(tostring(stat.Name), tostring(stat.ClassName), parseAmount(stat.Value)), 5)
        end)
    end
    donationTotals[uid] = parseAmount(stat.Value)
    donationConns["stat_"..uid] = stat.Changed:Connect(function()
        local newv = parseAmount(stat.Value)
        local prev = donationTotals[uid] or 0
        if player == LocalPlayer and newv ~= prev then
            pcall(function()
                notify("Donation Debug", ("stat changed %d -> %d (delta %d)"):format(prev, newv, newv - prev), 4)
            end)
        end
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
                                    local donor, donorName, donorId = nil, nil, nil
                                    if type(resolveDonationDonor) == "function" then
                                        donor, donorName, donorId = resolveDonationDonor(nil, nil)
                                    end
                                    if not donor then
                                        donor = LocalPlayer
                                        donorName = (LocalPlayer and LocalPlayer.Name) or "Unknown"
                                        donorId = (LocalPlayer and LocalPlayer.UserId) or nil
                                    end
                                    local pending = math.floor(delta * 0.6)
                                    postWebhookEvent("donation", {
                                        donorName = donorName,
                                        from = donorName,
                                        userId = donorId,
                                        amount = delta,
                                        total = newv,
                                        pending = pending,
                                    })
                                    notify("Donation", ("%d received from %s. Pending: %d"):format(delta, donorName, pending), 5)
                                    applyDonationSpin(delta)
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

local function getUserIdFromUsername(username)
    local name = tostring(username or "")
    if name == "" then return nil end
    local ok, response = pcall(function()
        return HttpService:RequestAsync({
            Url = "https://users.roblox.com/v1/usernames/users",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ usernames = { name }, excludeBannedUsers = true }),
        })
    end)
    if not ok or not response or not response.Success or not response.Body then return nil end
    local okBody, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
    if not okBody or type(data) ~= "table" or type(data.data) ~= "table" then return nil end
    if data.data[1] and data.data[1].id then return tonumber(data.data[1].id) end
    return nil
end

local function resolveDonationDonor(donorOverrideId, donorOverrideName)
    -- Prefer explicit overrides passed to the function; otherwise return nearest player to local player
    local overrideId = tonumber(donorOverrideId)
    if overrideId and overrideId > 0 then
        local player = Players:GetPlayerByUserId(overrideId)
        if player then
            return player, player.Name, player.UserId
        end
        return nil, nil, overrideId
    end
    local overrideName = tostring(donorOverrideName or "")
    if overrideName ~= "" then
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl and pl.Name == overrideName then
                return pl, pl.Name, pl.UserId
            end
        end
        local resolvedId = getUserIdFromUsername(overrideName)
        if resolvedId and resolvedId > 0 then
            return nil, overrideName, resolvedId
        end
    end

    local ok, lchar = pcall(function() return LocalPlayer.Character end)
    if not ok or not lchar then return nil, nil, nil end
    local lroot = lchar:FindFirstChild("HumanoidRootPart") or lchar:FindFirstChild("Torso")
    if not lroot then return nil, nil, nil end

    local best, bestDist = nil, math.huge
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl and pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
            local pr = pl.Character:FindFirstChild("HumanoidRootPart")
            local d = (pr.Position - lroot.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = pl
            end
        end
    end

    if best then
        return best, best.Name, best.UserId
    end
    return nil, nil, nil
end

-- Follow-on-donation feature removed per user request

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

local function getAttributeValue(obj, names)
    if not obj or not obj.GetAttribute then return nil end
    for _, name in ipairs(names or {}) do
        local val = obj:GetAttribute(name)
        if val ~= nil then
            return val
        end
    end
    if obj.GetAttributes then
        local attrs = obj:GetAttributes()
        local lowered = {}
        for _, name in ipairs(names or {}) do
            lowered[string.lower(name)] = true
        end
        for attrName, attrVal in pairs(attrs) do
            if lowered[string.lower(tostring(attrName))] then
                return attrVal
            end
        end
    end
    return nil
end

local function getStandId(stand)
    if not stand then return nil end
    local id = getAttributeValue(stand, {"StandId", "standId", "standid", "Slot", "slot"})
    if id and tonumber(id) then return tonumber(id) end
    local n = tostring(stand.Name or ""):match("(%d+)")
    if n then return tonumber(n) end
    return nil
end

local function isStandClaimed(stand)
    if not stand then return true end
    local ownerObj = stand:FindFirstChild("Wner") or stand:FindFirstChild("Owner")
    if not ownerObj then return false end
    if ownerObj:IsA("ObjectValue") then
        return ownerObj.Value ~= nil
    end
    if ownerObj:IsA("StringValue") then
        return tostring(ownerObj.Value or "") ~= ""
    end
    if ownerObj:IsA("IntValue") or ownerObj:IsA("NumberValue") then
        return tonumber(ownerObj.Value) ~= nil
    end
    return true
end

local function findStandById(standId)
    local standsFolder = Workspace:FindFirstChild("Stands") or Workspace:FindFirstChild("stands")
    if not standsFolder then return nil end
    for _, stand in ipairs(standsFolder:GetChildren()) do
        if stand and getStandId(stand) == standId then
            return stand
        end
    end
    return nil
end

local function findClaimPromptForStand(stand)
    if not stand then return nil end
    local standButtons = Workspace:FindFirstChild("StandButtons") or Workspace:FindFirstChild("standbuttons")
    if not standButtons then return nil end

    local targetId = getStandId(stand)
    if not targetId then return nil end

    for _, child in ipairs(standButtons:GetChildren()) do
        if child and tostring(child.Name or ""):lower() == "buttonprompt" then
            local childId = getAttributeValue(child, {"StandId", "standId", "standid"})
            if childId and tonumber(childId) and tonumber(childId) == targetId then
                local prompt = child:FindFirstChild("Claim") or child:FindFirstChildWhichIsA("ProximityPrompt") or child:FindFirstChildOfClass("ProximityPrompt")
                if prompt and prompt:IsA("ProximityPrompt") then
                    return prompt
                end
            end
        end
    end

    for _, child in ipairs(standButtons:GetDescendants()) do
        if child and child:IsA("ProximityPrompt") then
            local parent = child.Parent
            if parent and tostring(parent.Name or ""):lower() == "buttonprompt" then
                local parentId = getAttributeValue(parent, {"StandId", "standId", "standid"})
                if parentId and tonumber(parentId) and tonumber(parentId) == targetId then
                    return child
                end
            end
        end
    end

    return nil
end

local function tryFireClaimPrompt(stand)
    local prompt = findClaimPromptForStand(stand)
    if not prompt then return false end
    local ok = pcall(function()
        if prompt.Enabled ~= nil then
            prompt.Enabled = true
        end
        if prompt.InputHoldBegin then
            prompt:InputHoldBegin()
            task.wait(0.08)
            prompt:InputHoldEnd()
            return true
        end
        if prompt.Trigger then
            prompt:Trigger(LocalPlayer)
            return true
        end
        return false
    end)
    return ok and true or false
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
    mode = mode or "teleport"
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
                return true
            end
        end
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

local function performDonationSpin()
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not hrp then return false end
    task.spawn(function()
        local steps = 14
        local origin = hrp.Position
        for i = 1, steps do
            local angle = (i / steps) * math.pi * 2
            pcall(function()
                local look = Vector3.new(math.cos(angle), 0, math.sin(angle))
                hrp.CFrame = CFrame.new(origin, origin + look)
                if hrp.AssemblyLinearVelocity then
                    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                end
            end)
            task.wait(0.06)
        end
    end)
    return true
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

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local playerPos = hrp and hrp.Position

    local candidates = {}
    for _, stand in ipairs(standsList) do
        if stand and stand.Parent then
            local slot = getStandId(stand)
            local ownerEmpty = not isStandClaimed(stand)
            if slot and ownerEmpty then
                local pivot = tryGetPivotPosition(stand)
                if pivot then
                    candidates[#candidates+1] = { stand = stand, pivot = pivot, slot = slot }
                end
            end
        end
    end

    if #candidates == 0 then
        notify("Booth Claim", "No empty stands available.", 4)
        return false
    end

    table.sort(candidates, function(a,b)
        if not playerPos then return true end
        return (a.pivot - playerPos).Magnitude < (b.pivot - playerPos).Magnitude
    end)

    local target = candidates[1]
    if not target or not target.stand then
        notify("Booth Claim", "No valid stand target.", 3)
        return false
    end

    local slot = target.slot or getStandId(target.stand)
    local distanceAway = 4.5
    local basePos, awayDir = computeStandPlacement(target.stand, playerPos, distanceAway)
    local safePos = basePos or (target.pivot + Vector3.new(0, 2, 0))
    local dir = awayDir or (playerPos and (Vector3.new(playerPos.X - target.pivot.X, 0, playerPos.Z - target.pivot.Z).Unit) ) or Vector3.new(0, 0, -1)
    notify("Booth Claim", ("Claiming booth %d now"):format(slot), 3)
    moveCharacterToPosition(safePos, "teleport", dir)
    task.wait(0.25)

    if not slot then
        notify("Booth Claim", ("Could not determine slot for %s"):format(tostring(target.stand.Name or "?")), 4)
        return false
    end

    pcall(function()
        local promptTriggered = tryFireClaimPrompt(target.stand)
        if promptTriggered then
            notify("Booth Claim", ("Moved to booth %d and triggered its Claim prompt"):format(slot), 3)
        else
            notify("Booth Claim", ("Moved to booth %d; prompt not found, using fallback claim"):format(slot), 3)
        end
    end)

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
                                            pcall(function() moveCharacterToPosition(basePos, "teleport", awayDir) end)
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

local function claimBooth()
    local ok, res = pcall(claimEmptyStands)
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
                touchPreventAFK = SETTINGS.touchPreventAFK,
                hopRange = hopRangeText,
                serverStayTime = serverStayTime,
                persistToggles = SETTINGS.persistToggles,
                spinOnDonation = SETTINGS.spinSet,
                spinSet = SETTINGS.spinSet,
                spinSpeedMultiplier = SETTINGS.spinSpeedMultiplier,
                -- follow-on-donation removed
                emoteId = SETTINGS.emoteId,
                boothText = SETTINGS.boothText,
                staffHop = SETTINGS.staffHop,
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
            if decoded.webhookToggle ~= nil then SETTINGS.webhookToggle = decoded.webhookToggle end
            SETTINGS.webhookUrl = decoded.webhookUrl or SETTINGS.webhookUrl
            if decoded.antiAfk ~= nil then SETTINGS.antiAfk = decoded.antiAfk end
            -- legacy spin/periodic settings removed
            if decoded.touchPreventAFK ~= nil then SETTINGS.touchPreventAFK = decoded.touchPreventAFK end
            -- enforce mode option removed; always use teleport
            hopRangeText = decoded.hopRange or hopRangeText
            serverStayTime = tonumber(decoded.serverStayTime) or serverStayTime
            if decoded.persistToggles ~= nil then SETTINGS.persistToggles = decoded.persistToggles end
            if decoded.spinSet ~= nil then SETTINGS.spinSet = decoded.spinSet end
            if decoded.spinOnDonation ~= nil then SETTINGS.spinSet = decoded.spinOnDonation end
            if decoded.spinSpeedMultiplier ~= nil then SETTINGS.spinSpeedMultiplier = decoded.spinSpeedMultiplier end
            -- follow-on-donation setting removed
            SETTINGS.emoteId = decoded.emoteId or SETTINGS.emoteId
            SETTINGS.boothText = decoded.boothText or SETTINGS.boothText
            if decoded.staffHop ~= nil then SETTINGS.staffHop = decoded.staffHop end
            if decoded.emotePlaying ~= nil then SETTINGS.emotePlaying = decoded.emotePlaying end
            if decoded.autoServerHop ~= nil then autoServerHopEnabled = decoded.autoServerHop end
        end

        pcall(function()
            if type(_G) == "table" and type(_G.__PLS_WAIT_CONFIG) == "table" then
                local cfg = _G.__PLS_WAIT_CONFIG
                if cfg.webhookToggle ~= nil then SETTINGS.webhookToggle = cfg.webhookToggle end
                SETTINGS.webhookUrl = cfg.webhookUrl or SETTINGS.webhookUrl
                if cfg.antiAfk ~= nil then SETTINGS.antiAfk = cfg.antiAfk end
                if cfg.touchPreventAFK ~= nil then SETTINGS.touchPreventAFK = cfg.touchPreventAFK end
                serverStayTime = tonumber(cfg.serverStayTime) or serverStayTime
                if cfg.persistToggles ~= nil then SETTINGS.persistToggles = cfg.persistToggles end
                if cfg.spinSet ~= nil then SETTINGS.spinSet = cfg.spinSet end
                if cfg.spinOnDonation ~= nil then SETTINGS.spinSet = cfg.spinOnDonation end
                if cfg.spinSpeedMultiplier ~= nil then SETTINGS.spinSpeedMultiplier = cfg.spinSpeedMultiplier end
                -- follow-on-donation setting removed from queued config
                hopRangeText = cfg.hopRange or hopRangeText
                SETTINGS.emoteId = cfg.emoteId or SETTINGS.emoteId
                SETTINGS.boothText = cfg.boothText or SETTINGS.boothText
                if cfg.staffHop ~= nil then SETTINGS.staffHop = cfg.staffHop end
                if cfg.autoServerHop ~= nil then autoServerHopEnabled = cfg.autoServerHop end
                -- legacy spin settings ignored from queued config
                _G.__PLS_WAIT_CONFIG = nil
            end
        end)

        pcall(LoadSettings)
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

        local function ensureSpinPart()
            if not SETTINGS.spinSet then return end
            local char = LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if not root then return end
            local spinPart = root:FindFirstChild("Spin")
            if spinPart and spinPart:IsA("BodyAngularVelocity") then
                spinPart.AngularVelocity = Vector3.new(0, 0.25 * (SETTINGS.spinSpeedMultiplier or 1), 0)
                return
            end
            spinPart = Instance.new("BodyAngularVelocity")
            spinPart.Name = "Spin"
            spinPart.MaxTorque = Vector3.new(0, math.huge, 0)
            spinPart.Parent = root
            spinPart.AngularVelocity = Vector3.new(0, 0.25 * (SETTINGS.spinSpeedMultiplier or 1), 0)
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
        uiToggle.Size = UDim2.new(0, 48, 0, 48)
        uiToggle.Position = UDim2.new(0, 8, 0, 8)
        uiToggle.AnchorPoint = Vector2.new(0,0)
        uiToggle.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
        uiToggle.BackgroundTransparency = 0
        uiToggle.BorderSizePixel = 0
        uiToggle.Image = ""
        uiToggle.Parent = screen
        local togCorner = Instance.new("UICorner")
        togCorner.CornerRadius = UDim.new(0.5, 0)
        togCorner.Parent = uiToggle
        local togGradient = Instance.new("UIGradient")
        togGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(23, 31, 45)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 61, 119)),
        }
        togGradient.Rotation = 90
        togGradient.Parent = uiToggle
        local togStroke = Instance.new("UIStroke")
        togStroke.Color = Color3.fromRGB(14, 17, 23)
        togStroke.Thickness = 1
        togStroke.Parent = uiToggle
        local togLabel = Instance.new("TextLabel")
        togLabel.Text = "PLS WAIT"
        togLabel.Size = UDim2.new(1, -8, 1, -8)
        togLabel.Position = UDim2.new(0, 4, 0, 4)
        togLabel.BackgroundTransparency = 1
        togLabel.TextColor3 = Color3.fromRGB(242, 242, 242)
        togLabel.Font = Enum.Font.GothamBold
        togLabel.TextScaled = true
        togLabel.TextWrapped = true
        togLabel.TextYAlignment = Enum.TextYAlignment.Center
        togLabel.TextXAlignment = Enum.TextXAlignment.Center
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
        mainFrame.BackgroundColor3 = Color3.fromRGB(24,24,24)
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
        titleBar.BackgroundColor3 = Color3.fromRGB(70,70,70)
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
        closeBtn.Text = "X"
        closeBtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
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

        -- Decorative squiggle layers removed per user request

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

        local menu = { {key="Booth", text="Booth"}, {key="Main", text="Main"}, {key="ServerHop", text="Server Hop"}, {key="Webhook", text="Webhook"} }
        local tabButtons = {}
        local tabFrames = {}
        for i, item in ipairs(menu) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -12, 0, 40)
            btn.LayoutOrder = i
            btn.Text = item.text
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

        local function updateBoothText(text)
            local newText = tostring(text or "")
            if newText == "" then
                notify("Booth Text", "Enter booth text before saving.", 4)
                return false
            end
            local remote = ReplicatedStorage:FindFirstChild("UpdateStandText") or ReplicatedStorage:WaitForChild("UpdateStandText", 5)
            if not remote then
                notify("Booth Text", "UpdateStandText remote not found.", 4)
                return false
            end
            local ok, res = pcall(function()
                return remote:InvokeServer(newText)
            end)
            if not ok then
                notify("Booth Text", "Save failed: " .. tostring(res), 5)
                return false
            end
            notify("Booth Text", "Booth text saved.", 4)
            return true
        end

        -- Booth tab
        do
            local boothFrame = tabFrames.Booth
            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, -20, 0, 28)
            title.Position = UDim2.new(0, 10, 0, 10)
            title.BackgroundTransparency = 1
            title.Text = "Booth"
            title.TextColor3 = Color3.new(1,1,1)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 16
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.Parent = boothFrame

            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.new(0, 120, 0, 20)
            textLabel.Position = UDim2.new(0, 10, 0, 50)
            textLabel.Text = "Booth Text"
            textLabel.BackgroundTransparency = 1
            textLabel.TextColor3 = Color3.new(1,1,1)
            textLabel.Parent = boothFrame

            local boothTextBox = Instance.new("TextBox")
            boothTextBox.Size = UDim2.new(1, -20, 0, 90)
            boothTextBox.Position = UDim2.new(0, 10, 0, 74)
            boothTextBox.Text = tostring(SETTINGS.boothText or DEFAULT_BOOTH_TEXT)
            boothTextBox.PlaceholderText = "Enter booth text here..."
            boothTextBox.TextWrapped = true
            boothTextBox.MultiLine = true
            boothTextBox.ClearTextOnFocus = false
            boothTextBox.TextXAlignment = Enum.TextXAlignment.Left
            boothTextBox.TextYAlignment = Enum.TextYAlignment.Top
            boothTextBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
            boothTextBox.TextColor3 = Color3.fromRGB(255,255,255)
            local btbCorner = Instance.new("UICorner") btbCorner.Parent = boothTextBox
            boothTextBox.Parent = boothFrame

            local saveBtn = Instance.new("TextButton")
            saveBtn.Size = UDim2.new(0, 120, 0, 28)
            saveBtn.Position = UDim2.new(0, 10, 0, 176)
            saveBtn.Text = "Save Text"
            saveBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
            saveBtn.TextColor3 = Color3.new(1,1,1)
            saveBtn.Font = Enum.Font.Gotham
            saveBtn.TextSize = 14
            saveBtn.Parent = boothFrame
            styleButton(saveBtn)
            saveBtn.MouseButton1Click:Connect(function()
                local text = tostring(boothTextBox.Text or "")
                SETTINGS.boothText = text
                pcall(SaveSettings)
                pcall(updateBoothText, text)
            end)
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
            afkToggle.Position = UDim2.new(0,150,0,10)
            afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
            afkToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
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

            local touchLabel = Instance.new("TextLabel")
            touchLabel.Size = UDim2.new(0,120,0,20)
            touchLabel.Position = UDim2.new(0,10,0,42)
            touchLabel.Text = "Touch Prevent AFK"
            touchLabel.BackgroundTransparency = 1
            touchLabel.TextColor3 = Color3.new(1,1,1)
            touchLabel.Parent = frame

            local touchToggle = Instance.new("TextButton")
            touchToggle.Size = UDim2.new(0,60,0,20)
            touchToggle.Position = UDim2.new(0,150,0,42)
            touchToggle.Text = SETTINGS.touchPreventAFK and "ON" or "OFF"
            touchToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
            touchToggle.TextColor3 = Color3.fromRGB(255,255,255)
            local ttCorner = Instance.new("UICorner") ttCorner.Parent = touchToggle
            touchToggle.Parent = frame
            touchToggle.MouseButton1Click:Connect(function()
                SETTINGS.touchPreventAFK = not SETTINGS.touchPreventAFK
                touchToggle.Text = SETTINGS.touchPreventAFK and "ON" or "OFF"
                pcall(SaveSettings)
                if SETTINGS.touchPreventAFK then
                    pcall(function()
                        local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
                        if ok and vu then
                            pcall(function() vu:CaptureController(); if vu.ClickButton2 then vu:ClickButton2(Vector2.new(0,0)) end end)
                        else
                            local char = LocalPlayer.Character
                            if char then
                                local hum = char:FindFirstChildOfClass("Humanoid")
                                if hum then hum.Jump = true end
                            end
                        end
                    end)
                end
            end)
            styleButton(touchToggle)

            -- Emote selector / play (Main)
            local emoteLabel = Instance.new("TextLabel")
            emoteLabel.Size = UDim2.new(0,120,0,20)
            emoteLabel.Position = UDim2.new(0,10,0,112)
            emoteLabel.Text = "Emote (asset id)"
            emoteLabel.TextColor3 = Color3.new(1,1,1)
            emoteLabel.BackgroundTransparency = 1
            emoteLabel.Parent = frame

            local emoteBox = Instance.new("TextBox")
            emoteBox.Size = UDim2.new(0,160,0,24)
            emoteBox.Position = UDim2.new(0,140,0,112)
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

            local emotePresetBtn = Instance.new("TextButton")
            emotePresetBtn.Size = UDim2.new(0,70,0,24)
            emotePresetBtn.Position = UDim2.new(0,306,0,112)
            emotePresetBtn.Text = "Presets"
            emotePresetBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
            emotePresetBtn.TextColor3 = Color3.fromRGB(255,255,255)
            emotePresetBtn.Parent = frame
            styleButton(emotePresetBtn)

            local emotePlayBtn = Instance.new("TextButton")
            emotePlayBtn.Size = UDim2.new(0,80,0,24)
            emotePlayBtn.Position = UDim2.new(0,140,0,150)
            emotePlayBtn.Text = "Play"
            emotePlayBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
            emotePlayBtn.TextColor3 = Color3.fromRGB(255,255,255)
            emotePlayBtn.Parent = frame
            styleButton(emotePlayBtn)

            local emoteStopBtn = Instance.new("TextButton")
            emoteStopBtn.Size = UDim2.new(0,80,0,24)
            emoteStopBtn.Position = UDim2.new(0,228,0,150)
            emoteStopBtn.Text = "Stop"
            emoteStopBtn.BackgroundColor3 = Color3.fromRGB(100,40,40)
            emoteStopBtn.TextColor3 = Color3.fromRGB(255,255,255)
            emoteStopBtn.Parent = frame
            styleButton(emoteStopBtn)

            local presetFrame = Instance.new("ScrollingFrame")
            presetFrame.Position = UDim2.new(0,140,0,180)
            presetFrame.Size = UDim2.new(0,160,0,110)
            presetFrame.BackgroundTransparency = 0.15
            presetFrame.Visible = false
            presetFrame.ZIndex = 3
            presetFrame.CanvasSize = UDim2.new(0,0,0,0)
            presetFrame.ScrollBarThickness = 6
            presetFrame.ClipsDescendants = true
            presetFrame.Parent = frame
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
            presetFrame.CanvasSize = UDim2.new(0,0,0,28 * #presetEmotes)
            local function closePreset()
                presetFrame.Visible = false
            end
            emotePresetBtn.MouseButton1Click:Connect(function()
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
            autoEmoteLabel.Position = UDim2.new(0,10,0,220)
            autoEmoteLabel.Text = "Auto-Play Emote"
            autoEmoteLabel.BackgroundTransparency = 1
            autoEmoteLabel.TextColor3 = Color3.new(1,1,1)
            autoEmoteLabel.Parent = frame

            local autoEmoteToggle = Instance.new("TextButton")
            autoEmoteToggle.Size = UDim2.new(0,60,0,20)
            autoEmoteToggle.Position = UDim2.new(0,140,0,220)
            autoEmoteToggle.Text = SETTINGS.emotePlaying and "ON" or "OFF"
            autoEmoteToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
            autoEmoteToggle.TextColor3 = Color3.fromRGB(255,255,255)
            autoEmoteToggle.Parent = frame
            local aec = Instance.new("UICorner") aec.Parent = autoEmoteToggle
            styleButton(autoEmoteToggle)

            local spinLabel = Instance.new("TextLabel")
            spinLabel.Size = UDim2.new(0,120,0,20)
            spinLabel.Position = UDim2.new(0,10,0,252)
            spinLabel.Text = "Spin On Donation"
            spinLabel.BackgroundTransparency = 1
            spinLabel.TextColor3 = Color3.new(1,1,1)
            spinLabel.Parent = frame

            local spinToggle = Instance.new("TextButton")
            spinToggle.Size = UDim2.new(0,60,0,20)
            spinToggle.Position = UDim2.new(0,140,0,252)
            spinToggle.Text = SETTINGS.spinSet and "ON" or "OFF"
            spinToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
            spinToggle.TextColor3 = Color3.fromRGB(255,255,255)
            spinToggle.Parent = frame
            local stCorner = Instance.new("UICorner") stCorner.Parent = spinToggle
            styleButton(spinToggle)

            local speedLabel = Instance.new("TextLabel")
            speedLabel.Size = UDim2.new(0,160,0,20)
            speedLabel.Position = UDim2.new(0,10,0,282)
            speedLabel.Text = "Spin Speed Multiplier"
            speedLabel.BackgroundTransparency = 1
            speedLabel.TextColor3 = Color3.new(1,1,1)
            speedLabel.Parent = frame

            local speedBox = Instance.new("TextBox")
            speedBox.Size = UDim2.new(0,80,0,20)
            speedBox.Position = UDim2.new(0,140,0,282)
            speedBox.Text = tostring(SETTINGS.spinSpeedMultiplier or 1)
            speedBox.ClearTextOnFocus = false
            speedBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
            speedBox.TextColor3 = Color3.fromRGB(255,255,255)
            speedBox.TextXAlignment = Enum.TextXAlignment.Left
            speedBox.Parent = frame

            local sCorner = Instance.new("UICorner") sCorner.Parent = speedBox
            styleButton(speedBox)

            spinToggle.MouseButton1Click:Connect(function()
                SETTINGS.spinSet = not SETTINGS.spinSet
                spinToggle.Text = SETTINGS.spinSet and "ON" or "OFF"
                pcall(SaveSettings)
                if not SETTINGS.spinSet then
                    local char = LocalPlayer.Character
                    if char then
                        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                        if root and root:FindFirstChild("Spin") then
                            root:FindFirstChild("Spin"):Destroy()
                        end
                    end
                    if not SETTINGS.webhookToggle then
                        stopDonationMonitor()
                    end
                else
                    pcall(function()
                        local char = LocalPlayer.Character
                        if char then
                            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                            if root and not root:FindFirstChild("Spin") then
                                local spinPart = Instance.new("BodyAngularVelocity")
                                spinPart.Name = "Spin"
                                spinPart.MaxTorque = Vector3.new(0, math.huge, 0)
                                spinPart.Parent = root
                                spinPart.AngularVelocity = Vector3.new(0, 0.25 * (SETTINGS.spinSpeedMultiplier or 1), 0)
                            end
                        end
                    end)
                    startDonationMonitor()
                end
            end)

            speedBox.FocusLost:Connect(function(enter)
                local value = tonumber(speedBox.Text)
                if value and value > 0 then
                    SETTINGS.spinSpeedMultiplier = value
                    speedBox.Text = tostring(value)
                    pcall(SaveSettings)
                    if SETTINGS.spinSet then
                        local char = LocalPlayer.Character
                        if char then
                            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                            if root then
                                local spinPart = root:FindFirstChild("Spin")
                                if spinPart and spinPart:IsA("BodyAngularVelocity") then
                                    spinPart.AngularVelocity = Vector3.new(0, 0.25 * value, 0)
                                end
                            end
                        end
                    end
                else
                    speedBox.Text = tostring(SETTINGS.spinSpeedMultiplier or 1)
                end
            end)

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
            -- Spin and periodic jump features removed from Overview

            -- Auto-play emote on UI/script execution if an emote is selected
            pcall(function()
                if SETTINGS.emoteId and tostring(SETTINGS.emoteId) ~= "" and SETTINGS.emotePlaying then
                    local function attemptPlay()
                        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if not hum then
                            for i=1,20 do
                                hum = char:FindFirstChildOfClass("Humanoid")
                                if hum then break end
                                task.wait(0.05)
                            end
                        end
                        pcall(function() playEmote(SETTINGS.emoteId) end)
                    end

                    -- (Periodic Jump and Spin controls moved below emote block for consistent layout)
                    if SETTINGS.emotePlaying then
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                            pcall(attemptPlay)
                        else
                            LocalPlayer.CharacterAdded:Connect(function()
                                task.wait(0.5)
                                pcall(attemptPlay)
                            end)
                        end
                    end
                end
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
            hopBtn.BackgroundColor3 = Color3.fromRGB(90,90,90)
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
            autoToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
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

            local staffLabel = Instance.new("TextLabel")
            staffLabel.Size = UDim2.new(0,120,0,20)
            staffLabel.Position = UDim2.new(0,10,0,194)
            staffLabel.Text = "Staff Hop"
            staffLabel.BackgroundTransparency = 1
            staffLabel.TextColor3 = Color3.new(1,1,1)
            staffLabel.Parent = frame

            local staffToggle = Instance.new("TextButton")
            staffToggle.Size = UDim2.new(0,60,0,20)
            staffToggle.Position = UDim2.new(0,140,0,194)
            staffToggle.Text = SETTINGS.staffHop and "ON" or "OFF"
            staffToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
            staffToggle.TextColor3 = Color3.fromRGB(255,255,255)
            local shCorner = Instance.new("UICorner")
            shCorner.Parent = staffToggle
            staffToggle.Parent = frame
            styleButton(staffToggle)
            staffToggle.MouseButton1Click:Connect(function()
                SETTINGS.staffHop = not SETTINGS.staffHop
                staffToggle.Text = SETTINGS.staffHop and "ON" or "OFF"
                pcall(SaveSettings)
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
            whToggle.BackgroundColor3 = Color3.fromRGB(90,90,90)
            styleButton(whToggle)
            whToggle.MouseButton1Click:Connect(function()
                SETTINGS.webhookToggle = not SETTINGS.webhookToggle
                whToggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
                if SETTINGS.webhookToggle then startDonationMonitor() else stopDonationMonitor() end
                pcall(SaveSettings)
            end)

            -- follow-on-donation UI removed

            local urlBox = Instance.new("TextBox")
            urlBox.Size = UDim2.new(1, -20, 0, 24)
            urlBox.Position = UDim2.new(0,10,0,72)
            urlBox.Text = tostring(SETTINGS.webhookUrl or "")
            urlBox.PlaceholderText = "https://discord.com/api/webhooks..."
            urlBox.TextXAlignment = Enum.TextXAlignment.Left
            urlBox.ClearTextOnFocus = false
            urlBox.TextWrapped = false
            urlBox.Parent = frame
            urlBox.FocusLost:Connect(function()
                SETTINGS.webhookUrl = tostring(urlBox.Text or "")
                pcall(SaveSettings)
            end)

            local donationTestBtn = Instance.new("TextButton")
            donationTestBtn.Size = UDim2.new(0,160,0,24)
            donationTestBtn.Position = UDim2.new(0,10,0,108)
            donationTestBtn.Text = "Test Donation"
            donationTestBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
            donationTestBtn.TextColor3 = Color3.fromRGB(255,255,255)
            donationTestBtn.Parent = frame
            styleButton(donationTestBtn)
            donationTestBtn.MouseButton1Click:Connect(function()
                local donor, donorName, donorId = nil, nil, nil
                if type(resolveDonationDonor) == "function" then
                    donor, donorName, donorId = resolveDonationDonor(nil, nil)
                end
                if not donor then donor = LocalPlayer; donorName = LocalPlayer and LocalPlayer.Name or "TestDonor"; donorId = LocalPlayer and LocalPlayer.UserId or 0 end
                local function parseDonationValue(v)
                    if type(v) == "number" then return math.floor(v) end
                    local s = tostring(v or "")
                    local cleaned = s:gsub("[^%d%-]", "")
                    local num = tonumber(cleaned)
                    if num then return math.floor(num) end
                    local m = s:match("%-?%d+")
                    return tonumber(m) or 0
                end
                local function formatDonationValue(n)
                    local isNegative = n < 0
                    local absVal = tostring(math.abs(n))
                    local formatted = absVal:reverse():gsub("(%d%d%d)", "%1,"):reverse()
                    if formatted:sub(1,1) == "," then
                        formatted = formatted:sub(2)
                    end
                    if isNegative then formatted = "-" .. formatted end
                    return formatted
                end
                local leaderstats = LocalPlayer:FindFirstChild("leaderstats") or LocalPlayer:WaitForChild("leaderstats", 3)
                local totalValue = 1
                if leaderstats then
                    local raised = leaderstats:FindFirstChild("Raised") or leaderstats:FindFirstChild("raised")
                    if raised then
                        local current = parseDonationValue(raised.Value)
                        local nextValue = current + 6
                        totalValue = nextValue
                        if raised:IsA("StringValue") then
                            local raw = tostring(raised.Value or "")
                            local prefix = raw:match("^(%D*)") or ""
                            local suffix = raw:match("(%D*)$") or ""
                            raised.Value = prefix .. formatDonationValue(nextValue) .. suffix
                        elseif raised:IsA("IntValue") or raised:IsA("NumberValue") then
                            pcall(function()
                                raised.Value = nextValue
                            end)
                        else
                            pcall(function()
                                raised.Value = tostring(nextValue)
                            end)
                        end
                    end
                end
                pcall(function()
                    postWebhookEvent("donation", {
                        donorName = donorName,
                        from = donorName,
                        userId = donorId,
                        amount = 6,
                        total = totalValue,
                        test = true,
                    })
                end)
                notify("Donation Test", "Test donation event sent.", 4)
            end)

            -- donation stat name textbox removed per user request
        end

        -- Fade-in removed: UI elements appear immediately (user requested no fade)

        if SETTINGS.webhookToggle or SETTINGS.spinSet then
            startDonationMonitor()
        end
        if SETTINGS.webhookToggle then
            pcall(function()
                pcall(function() sendPlainWebhook(("@%s serverhopped"):format(tostring(LocalPlayer and LocalPlayer.Name or "Unknown"))) end)
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
                        spinOnDonation = SETTINGS.spinSet,
                        spinSet = SETTINGS.spinSet,
                        spinSpeedMultiplier = SETTINGS.spinSpeedMultiplier,
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
        -- Ensure claim runs immediately on UI/script execution and again after respawn
        pcall(function()
            task.spawn(function()
                for attempt = 1, 15 do
                    if LocalPlayer and LocalPlayer.Character then
                        notify("Booth Claim", "Preparing to claim the next available booth...", 3)
                        pcall(function() claimBooth() end)
                        break
                    end
                    task.wait(0.5)
                end
            end)

            LocalPlayer.CharacterAdded:Connect(function()
                task.wait(0.5)
                pcall(function() ensureSpinPart() end)
                task.wait(1)
                notify("Booth Claim", "Character respawned; attempting booth claim...", 3)
                pcall(function() claimBooth() end)
            end)
        end)
        if SETTINGS.spinSet then pcall(ensureSpinPart) end
        if SETTINGS.antiAfk then pcall(enableAntiAfk) end
        -- spin feature removed
        -- Touch-prevent AFK: camera wiggle every 3 minutes
        task.spawn(function()
            local RunService = game:GetService("RunService")
            local camera = workspace.CurrentCamera
            local interval = 180
            local lastTick = tick()
            RunService.RenderStepped:Connect(function()
                if not SETTINGS.touchPreventAFK then
                    return
                end
                local now = tick()
                if now - lastTick >= interval then
                    lastTick = now
                    local currentCFrame = camera.CFrame
                    camera.CFrame = currentCFrame * CFrame.Angles(0, 0.001, 0)
                    task.wait(0.05)
                    camera.CFrame = currentCFrame
                end
            end)
            while true do
                task.wait(1)
                if not SETTINGS.touchPreventAFK then
                    task.wait(1)
                end
            end
        end)
        -- Periodic jump feature removed
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
-- Script loaded: use functions directly (not returning a module table)
-- Auto-run handled by UI initialization above (avoid duplicate claims)
