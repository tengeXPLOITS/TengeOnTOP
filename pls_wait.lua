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
local COMMUNITY_ID = 16290792
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

local MODULE_BASE_URL = "https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/"

local function loadRemoteModule(fileName)
    local moduleUrl = MODULE_BASE_URL .. fileName
    local source = game:HttpGet(moduleUrl)
    assert(type(source) == "string" and source ~= "", "module source was empty")
    local chunk, compileError = loadstring(source)
    assert(chunk, compileError)
    local module = chunk()
    assert(type(module) == "table", "module must return a table")
    return module
end

local configModuleOk, ConfigModule = pcall(loadRemoteModule, "pls_wait_config.lua")
if not configModuleOk then
    warn("[PLS WAIT] Could not load config module:", ConfigModule)
    return
end
if type(ConfigModule.initializeSettings) ~= "function" or type(ConfigModule.create) ~= "function" then
    warn("[PLS WAIT] Config module has an invalid interface.")
    return
end
print("[PLS WAIT] Config module loaded successfully.")

local spinModuleOk, SpinModule = pcall(loadRemoteModule, "pls_wait_spin.lua")
if not spinModuleOk then
    warn("[PLS WAIT] Could not load spin module:", SpinModule)
    return
end
if type(SpinModule.create) ~= "function" then
    warn("[PLS WAIT] Spin module has an invalid interface.")
    return
end
print("[PLS WAIT] Spin module loaded successfully.")

local uiModuleOk, UIModule = pcall(loadRemoteModule, "pls_wait_ui.lua")
if not uiModuleOk then
    warn("[PLS WAIT] Could not load UI module:", UIModule)
    return
end
if type(UIModule.create) ~= "function" then
    warn("[PLS WAIT] UI module has an invalid interface.")
    return
end
print("[PLS WAIT] UI module loaded successfully.")

SETTINGS = SETTINGS or {}
-- Webhook / donation helpers
local DEFAULT_BOOTH_TEXT = '<font color="#3afdd6" face="Arial">💸i am satisfied with any amount of R$ you give me (: 💸</font>'
local touchEnabled = UserInputService and UserInputService.TouchEnabled
ConfigModule.initializeSettings(SETTINGS, touchEnabled, DEFAULT_BOOTH_TEXT)
local currentDonationStat = nil
local currentDonationUid = nil
local applyDonationSpin
local applyDonationHelicopter
local SpinFeature
local function parseAmount(v)
    if type(v) == "number" then return math.floor(v) end
    local s = tostring(v or "")
    local cleaned = s:gsub("[^%d%-]", "")
    if cleaned == "" then return 0 end
    local ok, num = pcall(function() return tonumber(cleaned) end)
    if ok and type(num) == "number" then return math.floor(num) end
    local m = s:match("%-?%d+")
    if m then return tonumber(m) or 0 end
    return 0
end
-- claimEnforceMode option removed; enforcement defaults to teleport
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
    -- Notifications suppressed per user request
    return
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
            if type(vu.ClickButton2) == "function" then
                vu:ClickButton2(Vector2.new(0,0))
            end
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

local function simulateTouchTapPulse()
    pcall(function()
        local vu = game:GetService("VirtualUser")
        if vu then
            vu:CaptureController()
            if type(vu.ClickButton1) == "function" then
                vu:ClickButton1(Vector2.new(0.5, 0.5))
            elseif type(vu.ClickButton2) == "function" then
                vu:ClickButton2(Vector2.new(0.5, 0.5))
            end
        end
    end)
    pcall(function()
        local camera = workspace.CurrentCamera
        if camera then
            local cframe = camera.CFrame
            camera.CFrame = cframe * CFrame.new(0, 0, 0.0001)
            task.wait(0.05)
            camera.CFrame = cframe
        end
    end)
end

-- Webhook / donation helpers
local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G

local function getLocalUnclaimedRobux()
    if not LocalPlayer then return nil end

    local deadline = os.clock() + 3
    local unclaimedValue
    repeat
        local numbersFolders = {}
        local directNumbers = LocalPlayer:FindFirstChild("Numbers")
        local stats = LocalPlayer:FindFirstChild("stats")
        local statsNumbers = stats and stats:FindFirstChild("Numbers")
        if directNumbers then table.insert(numbersFolders, directNumbers) end
        if statsNumbers and statsNumbers ~= directNumbers then
            table.insert(numbersFolders, statsNumbers)
        end

        for _, numbers in ipairs(numbersFolders) do
            local candidate = numbers:FindFirstChild("UnclaimedRobux")
            if candidate and (candidate:IsA("IntValue") or candidate:IsA("NumberValue")) then
                unclaimedValue = candidate
                break
            end
        end
        if unclaimedValue or os.clock() >= deadline then break end
        task.wait(0.1)
    until false

    if not unclaimedValue then
        warn("[PLS WAIT] Could not find LocalPlayer.Numbers.UnclaimedRobux or LocalPlayer.stats.Numbers.UnclaimedRobux for the donation webhook.")
        return nil
    end

    -- Let the donation's replicated stat update land before reading its current balance.
    task.wait(0.25)
    if not unclaimedValue.Parent then return nil end
    return unclaimedValue.Value
end

local function postWebhookEvent(kind, data)
    if not SETTINGS.webhookToggle or not SETTINGS.webhookUrl or SETTINGS.webhookUrl == "" then return end
    local url = tostring(SETTINGS.webhookUrl or "")
    local embeds = {}
    if kind == "donation" then
        local amount = tonumber(data and data.amount) or tonumber(tostring(data and data.amount or ""):gsub("[^%d]","")) or 0
        local pending = math.floor(amount * 0.6)
        local unclaimedRobux = "Unavailable"
        local unclaimedValue = getLocalUnclaimedRobux()
        if unclaimedValue ~= nil then
            unclaimedRobux = tostring(unclaimedValue)
        end
        -- Determine donor by nearest player to the local player (best-effort)
        local donorName = "Unknown"
        local donorId = nil
        pcall(function()
            local ok, lchar = pcall(function() return LocalPlayer and LocalPlayer.Character end)
            if ok and lchar then
                local lroot = lchar:FindFirstChild("HumanoidRootPart") or lchar:FindFirstChild("Torso")
                if lroot then
                    local best, bestDist = nil, math.huge
                    for _, pl in ipairs(Players:GetPlayers()) do
                        if pl and pl ~= LocalPlayer and pl.Character then
                            local pr = pl.Character:FindFirstChild("HumanoidRootPart") or pl.Character:FindFirstChild("Torso")
                            if pr then
                                local d = (pr.Position - lroot.Position).Magnitude
                                if d < bestDist then bestDist = d; best = pl end
                            end
                        end
                    end
                    if best then donorName = tostring(best.Name or "Unknown"); donorId = best.UserId end
                end
            end
        end)
        -- fallback to provided data if nearest not found
        if (not donorName or donorName == "Unknown") and data and (data.donorName or data.from) then
            donorName = tostring(data.donorName or data.from)
        end
        local fields = {
            { name = "Donor", value = donorName, inline = false },
            { name = "Amount Given", value = tostring(amount), inline = true },
            { name = "Pending R$ (60%)", value = tostring(pending), inline = true },
            { name = "Unclaimed Robux", value = unclaimedRobux, inline = true },
        }
        table.insert(embeds, {
            title = "YOU RECEIVED A DONATION 💰",
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

local function getRandomThankYouMessage()
    local msgs = SETTINGS.thankYouMessages
    if type(msgs) ~= "table" or #msgs == 0 then
        return "thanks!"
    end
    local valid = {}
    for _, item in ipairs(msgs) do
        local text = tostring(item or "")
        if text ~= "" then
            table.insert(valid, text)
        end
    end
    if #valid == 0 then return "thanks!" end
    local choice = valid[math.random(1, #valid)]
    return tostring(choice or "thanks!")
end

local function sendChatMessage(msg)
    local text = tostring(msg or "")
    if text == "" then return false, "The thank-you message is empty." end

    local chatService = game:GetService("TextChatService")
    if chatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local textChannels = chatService:FindFirstChild("TextChannels")
        local channel = textChannels and textChannels:FindFirstChild("RBXGeneral")
        if not (channel and channel:IsA("TextChannel")) and textChannels then
            channel = textChannels:FindFirstChildWhichIsA("TextChannel")
        end
        if not channel then
            return false, "No sendable TextChatService channel was found."
        end

        local ok, err = pcall(function()
            channel:SendAsync(text)
        end)
        if ok then return true end
        return false, tostring(err)
    end

    local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    local sayMessage = events and events:FindFirstChild("SayMessageRequest")
    if sayMessage and sayMessage:IsA("RemoteEvent") then
        local ok, err = pcall(function()
            sayMessage:FireServer(text, "All")
        end)
        if ok then return true end
        return false, tostring(err)
    end

    if LocalPlayer then
        local ok, err = pcall(function()
            LocalPlayer:Chat(text)
        end)
        if ok then return true end
        return false, tostring(err)
    end
    return false, "The local player is unavailable."
end

local function sendThankYouMessage(delta)
    if not SETTINGS.chatAutoThankYou then return end
    local msg = getRandomThankYouMessage()
    if msg == "" then return end
    if type(delta) ~= "number" then delta = 0 end
    if delta <= 0 then return end
    task.delay(0.8, function()
        local sent, err = sendChatMessage(msg)
        if not sent then
            notify("Auto Thank You", "Could not send chat message: " .. tostring(err), 5)
        end
    end)
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
    currentDonationStat = stat
    currentDonationUid = uid
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
                    if applyDonationHelicopter then
                        applyDonationHelicopter(delta)
                    end
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
                                    sendThankYouMessage(delta)
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
                    friendHop = SETTINGS.friendHop,
                    serverStayTime = SETTINGS.serverStayTime,
                    persistToggles = SETTINGS.persistToggles,
                        populationHopper = SETTINGS.populationHopper,
                        populationThreshold = SETTINGS.populationThreshold,
                        boothGoalAmount = SETTINGS.boothGoalAmount,
                        boothGoalTarget = SETTINGS.boothGoalTarget,
                        goalBarEnabled = SETTINGS.goalBarEnabled,
                        goalBarTarget = SETTINGS.goalBarTarget,
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
    donationConns["poll"] = game:GetService("RunService").Heartbeat:Connect(function()
        if not donationEnabled or not currentDonationStat or not currentDonationUid then return end
        local uid = currentDonationUid
        local newv = parseAmount(currentDonationStat.Value)
        local prev = donationTotals[uid] or 0
        if newv ~= prev then
            local delta = newv - prev
            donationTotals[uid] = newv
            if delta > 0 then
                if applyDonationHelicopter then
                    applyDonationHelicopter(delta)
                end
                if LocalPlayer == LocalPlayer then
                    pcall(function()
                        notify("Donation Debug", ("poll detected stat changed %d -> %d (delta %d)"):format(prev, newv, delta), 4)
                    end)
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
                sendThankYouMessage(delta)
                applyDonationSpin(delta)
            end
        end
    end)
    pcall(function() notify("Donation Debug", "donation monitor started", 4) end)
end

local function stopDonationMonitor()
    donationEnabled = false
    for k, conn in pairs(donationConns) do
        pcall(function() conn:Disconnect() end)
        donationConns[k] = nil
    end
    donationTotals = {}
    currentDonationStat = nil
    currentDonationUid = nil
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
        local ownerId = tonumber(ownerObj.Value)
        return ownerId ~= nil and ownerId ~= 0
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

local function standOwnedByLocalPlayer(stand)
    if not stand or not stand.Parent then return false end
    local ownerObj = stand:FindFirstChild("Wner") or stand:FindFirstChild("Owner")
    if not ownerObj then return false end
    if ownerObj:IsA("ObjectValue") then
        local ownerValue = ownerObj.Value
        if ownerValue == LocalPlayer then return true end
        if ownerValue and typeof(ownerValue) == "Instance" then
            return tostring(ownerValue.Name) == tostring(LocalPlayer.Name)
        end
        return false
    end
    if ownerObj:IsA("StringValue") then
        local ownerName = tostring(ownerObj.Value or "")
        return ownerName ~= "" and string.lower(ownerName) == string.lower(tostring(LocalPlayer.Name or ""))
    end
    if ownerObj:IsA("IntValue") or ownerObj:IsA("NumberValue") then
        return tonumber(ownerObj.Value) == tonumber(LocalPlayer.UserId)
    end
    return false
end

-- Check whether the local player is registered as owner on any stand
local function localPlayerOwnsAnyStand()
    local standsFolder = Workspace:FindFirstChild("Stands")
    if not standsFolder then return false end
    for _, stand in ipairs(standsFolder:GetChildren()) do
        if standOwnedByLocalPlayer(stand) then
            return true
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

    if playerPos then
        table.sort(candidates, function(a, b)
            return (a.pivot - playerPos).Magnitude < (b.pivot - playerPos).Magnitude
        end)
    end

    local function isAvailable(target)
        return target.stand.Parent == standsFolder
            and getStandId(target.stand) == target.slot
            and not isStandClaimed(target.stand)
    end

    local function isOwnedByLocalPlayer(target)
        local deadline = os.clock() + 2
        repeat
            if standOwnedByLocalPlayer(target.stand) then
                return true
            end
            if isStandClaimed(target.stand) then
                return false
            end
            task.wait(0.1)
        until os.clock() >= deadline
        return standOwnedByLocalPlayer(target.stand)
    end

    local initialCFrame = hrp and hrp.CFrame
    for _, target in ipairs(candidates) do
        local slot = target.slot
        if isAvailable(target) then
            local distanceAway = 4.5
            local basePos, awayDir = computeStandPlacement(target.stand, playerPos, distanceAway)
            local safePos = basePos or (target.pivot + Vector3.new(0, 2, 0))
            local dir = awayDir or Vector3.new(0, 0, -1)
            notify("Booth Claim", ("Claiming booth %d now"):format(slot), 3)
            moveCharacterToPosition(safePos, "teleport", dir)
            task.wait(0.25)

            -- The replicated owner can change after candidate selection or while moving.
            if isAvailable(target) then
                local promptOk, promptError = pcall(tryFireClaimPrompt, target.stand)
                if not promptOk then
                    warn("[PLS WAIT] Could not trigger stand claim prompt:", promptError)
                end

                local claimOk, claimResult = true, true
                if not standOwnedByLocalPlayer(target.stand) and isAvailable(target) then
                    claimOk, claimResult = pcall(function()
                        return remote:InvokeServer(slot)
                    end)
                end

                if claimOk and isOwnedByLocalPlayer(target) then
                    pcall(function()
                        postWebhookEvent("claim", { slot = slot, result = claimResult })
                    end)
                    local finalPos, finalDir = computeStandPlacement(target.stand, playerPos, distanceAway)
                    if finalPos and finalDir then
                        moveCharacterToPosition(finalPos, "teleport", finalDir)
                    end
                    notify("Booth Claim", ("Stand ownership verified for %s on slot %d"):format(tostring(LocalPlayer.Name), slot), 3)
                    return true
                end

                if not claimOk then
                    warn(("[PLS WAIT] ClaimStand failed for slot %d: %s"):format(slot, tostring(claimResult)))
                end
            end
        end
    end

    if initialCFrame and LocalPlayer.Character then
        local currentRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso")
        if currentRoot then
            currentRoot.CFrame = initialCFrame
        end
    end
    notify("Booth Claim", "Could not confirm an available stand; no booth was claimed.", 4)
    return false
    end
    local ok, res = pcall(_run)
    claimLock = false
    if ok then return res end
    warn("[PLS WAIT] Booth claim flow failed:", res)
    return false
end

local function claimBooth()
    local ok, res = pcall(claimEmptyStands)
    return ok, res
end

local spinFeatureOk, spinFeatureOrError = pcall(function()
    return SpinModule.create({
        LocalPlayer = LocalPlayer,
        Workspace = Workspace,
        TweenService = TweenService,
        settings = SETTINGS,
        sendChatMessage = sendChatMessage,
        isStandOwned = standOwnedByLocalPlayer,
        getStandPosition = tryGetPivotPosition,
        computeStandPlacement = computeStandPlacement,
        moveCharacterToPosition = moveCharacterToPosition,
        notify = notify,
    })
end)
if not spinFeatureOk then
    warn("[PLS WAIT] Could not initialize spin module:", spinFeatureOrError)
    return
end
SpinFeature = spinFeatureOrError
applyDonationSpin = SpinFeature.applyDonationSpin
if type(applyDonationSpin) ~= "function" or type(SpinFeature.ensureSpinPart) ~= "function"
    or type(SpinFeature.startBoothReturnMonitor) ~= "function"
    or type(SpinFeature.applyDonationHelicopter) ~= "function"
    or type(SpinFeature.setHelicopterEnabled) ~= "function"
    or type(SpinFeature.ensureHelicopter) ~= "function" then
    warn("[PLS WAIT] Spin module is missing required feature methods.")
    return
end
applyDonationHelicopter = SpinFeature.applyDonationHelicopter

local uiInitialized, uiError = pcall(function()
    UIModule.create({
        LocalPlayer = LocalPlayer,
        Players = Players,
        ReplicatedStorage = ReplicatedStorage,
        HttpService = HttpService,
        UserInputService = UserInputService,
        settings = SETTINGS,
        ConfigModule = ConfigModule,
        SpinFeature = SpinFeature,
        defaultBoothText = DEFAULT_BOOTH_TEXT,
        notify = notify,
        parseAmount = parseAmount,
        parseRangeGlobal = parseRangeGlobal,
        claimBooth = claimBooth,
        getCurrentDonationStat = function() return currentDonationStat end,
        disableAntiAfk = disableAntiAfk,
        enableAntiAfk = enableAntiAfk,
        ensureQueuedScript = ensureQueuedScript,
        postWebhookEvent = postWebhookEvent,
        resolveDonationDonor = resolveDonationDonor,
        sendPlainWebhook = sendPlainWebhook,
        serverHopNow = serverHopNow,
        serverSearchAttempt = serverSearchAttempt,
        simulateTouchTapPulse = simulateTouchTapPulse,
        startDonationMonitor = startDonationMonitor,
        stopDonationMonitor = stopDonationMonitor,
    })
end)
if not uiInitialized then
    warn("[PLS WAIT] Could not initialize UI module:", uiError)
end
