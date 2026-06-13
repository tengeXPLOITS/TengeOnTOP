-- PLS WAIT - Custom script scaffold for place 14212732626
-- Created: scaffold for user's booth claiming code integration

repeat task.wait() until game:IsLoaded()

local PLACE_ID = 14212732626
if tonumber(game.PlaceId) ~= tonumber(PLACE_ID) then
    warn("This script is intended for place id: "..tostring(PLACE_ID).." — aborting.")
    return
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

local SETTINGS = {
    webhookToggle = false,
    webhookUrl = "",
    antiAfk = true,
}

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

local function performHttpRequest(options)
    if syn and syn.request then return syn.request(options) end
    if request then return request(options) end
    if http_request then return http_request(options) end
    -- fallback: try game.HttpGet/HttpPost where appropriate (note: may error if not allowed)
    return nil
end

-- Queue-on-teleport helper (supports common exploit functions)
local function queueOnTeleport(codeString)
    if not codeString or codeString == "" then return false end
    if queue_on_teleport then
        pcall(function() queue_on_teleport(codeString) end)
        return true
    end
    if syn and syn.queue_on_teleport then
        pcall(function() syn.queue_on_teleport(codeString) end)
        return true
    end
    if fluxus and fluxus.queue_on_teleport then
        pcall(function() fluxus.queue_on_teleport(codeString) end)
        return true
    end
    return false
end

-- Simple server hop helper (fetches public servers for same place)
-- Server hop helper; by default finds servers with players in range 19..22
local function serverHopNow(minPlayers, maxPlayers, persistent)
    minPlayers = tonumber(minPlayers) or 19
    maxPlayers = tonumber(maxPlayers) or 22
    persistent = persistent == true

    task.spawn(function()
        while true do
            local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100"):format(tostring(PLACE_ID))
            local res = performHttpRequest({ Url = url, Method = "GET" })
            local found = false
            if res and type(res.Body) == "string" then
                local ok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
                if ok and decoded and type(decoded.data) == "table" then
                    for _, server in ipairs(decoded.data) do
                        local playing = tonumber(server.playing) or 0
                        if server.id and server.id ~= tostring(game.JobId) and playing >= minPlayers and playing <= maxPlayers then
                            -- queue this script to re-run on the destination and pass current settings via _G
                            local ok, cfgJson = pcall(function()
                                return HttpService:JSONEncode({
                                    webhookToggle = SETTINGS.webhookToggle,
                                    webhookUrl = SETTINGS.webhookUrl,
                                    antiAfk = SETTINGS.antiAfk,
                                    serverStayTime = serverStayTime,
                                    persistToggles = SETTINGS.persistToggles,
                                    autoServerHop = autoServerHopEnabled,
                                })
                            end)
                            local qcode = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua"))()'
                            if ok and cfgJson then
                                qcode = ("local _json = %q; _G.__PLS_WAIT_CONFIG = game:GetService('HttpService'):JSONDecode(_json); %s"):format(cfgJson, qcode)
                            end
                            pcall(function() queueOnTeleport(qcode) end)
                            pcall(function()
                                TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer)
                            end)
                            found = true
                            break
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

-- Anti-AFK (VirtualUser) simple option
local antiAfkConn
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
    if antiAfkConn then pcall(function() antiAfkConn:Disconnect() end) antiAfkConn = nil end
    notify("Anti-AFK", "Disabled", 2)
end
if SETTINGS.antiAfk then pcall(enableAntiAfk) end

-- Webhook helper (minimal)
local function postWebhookEvent(eventType, data)
    if not SETTINGS.webhookToggle then return false end
    local url = tostring(SETTINGS.webhookUrl or ""):match("%S+")
    if not url or url == "" then return false end
    local payload = { username = "PLS WAIT", embeds = {} }
    local embed = { title = "", description = "", color = 0x00FF00, fields = {} }
    if eventType == "claim" then
        embed.title = "Booth Claimed"
        embed.description = tostring(data.result or "")
        table.insert(embed.fields, { name = "Slot", value = tostring(data.slot or "?"), inline = true })
        table.insert(embed.fields, { name = "Place", value = tostring(PLACE_ID), inline = true })
    elseif eventType == "serverhop" then
        embed.title = "Server Hop"
        embed.description = tostring(data.info or "")
    elseif eventType == "donation" then
        embed.title = "Donation"
        embed.description = (tostring(data.player or "") .. " donated " .. tostring(data.amount or "?") )
        table.insert(embed.fields, { name = "Total", value = tostring(data.total or "?"), inline = true })
    else
        embed.title = tostring(eventType)
        embed.description = tostring(data.info or "")
    end
    payload.embeds[1] = embed
    pcall(function()
        performHttpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    return true
end

-- Utility: trim whitespace
local function trimText(s)
    if not s then return "" end
    return tostring(s):gsub("^%s+",""):gsub("%s+$","")
end

-- POST raw JSON to webhook URL
local function postWebhookJson(url, payload)
    if not url or url == "" then return false end
    pcall(function()
        performHttpRequest({
            Url = tostring(url),
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    return true
end

-- Donation webhook in Koyg format
local function sendDonationWebhook(amount, donorInfo)
    if not SETTINGS.webhookToggle then
        return
    end

    local url = tostring(SETTINGS.webhookUrl or ""):match("%S+")
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
        username = "webhook by K_0YG...",
        embeds = {{
            color = 0xFFAA00,
            title = "New Donation Received! ✅",
            fields = {
                {name = "Donor 👤", value = donorLabel, inline = false},
                {name = "How much recepient received 💵", value = string.format("%d", received), inline = true},
                {name = "Tax applied ):", value = string.format("%d", taxed), inline = true},
            },
        }},
    })
end

-- Donation notifier: watch players' leaderstats for a 'Raised' (or configured) value
local donationStatName = "Raised"
local donationEnabled = false
local donationConns = {}
local donationTotals = {}

local function onStatChanged(player, stat)
    local new = tonumber(stat.Value) or 0
    local uid = tostring(player.UserId)
    local prev = donationTotals[uid] or 0
    if new > prev then
        local delta = new - prev
        -- send donation-formatted webhook
        pcall(function()
            sendDonationWebhook(delta, { name = player.Name, displayName = player.DisplayName })
        end)
    end
    donationTotals[uid] = new
end

local function tryHookPlayerStat(player)
    if not player then return end
    -- init previous value
    donationTotals[tostring(player.UserId)] = donationTotals[tostring(player.UserId)] or 0
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local stat = ls:FindFirstChild(donationStatName)
        if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue") or stat:IsA("StringValue")) then
            donationTotals[tostring(player.UserId)] = tonumber(stat.Value) or 0
            donationConns["stat_"..tostring(player.UserId)] = stat.Changed:Connect(function() onStatChanged(player, stat) end)
            return true
        end
    end
    return false
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

-- Create a centered, mobile-friendly GUI
do
    local ok, playerGui = pcall(function()
        return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 6)
    end)
    if not (ok and playerGui) then
        notify("Fluent UI", "PlayerGui not available; falling back to existing UI.", 5)
    else
        local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
        local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

        local Window = Fluent:CreateWindow({
            Title = "Pls Wait",
            SubTitle = "Booth Claimer",
            TabWidth = 160,
            Size = UDim2.fromOffset(520, 420),
            Acrylic = true,
            Theme = "Dark",
            MinimizeKey = Enum.KeyCode.LeftControl
        })

        local Tabs = {
            Main = Window:AddTab({ Title = "Main", Icon = "" }),
            ServerHop = Window:AddTab({ Title = "Server-Hop", Icon = "server" }),
            Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
            Webhook = Window:AddTab({ Title = "Webhook", Icon = "link" })
        }

        local Options = Fluent.Options

        -- server-hop / persistence defaults (serverStayTime is in minutes)
        local serverStayTime = SETTINGS.serverStayTime or 30
        local autoServerHopEnabled = false
        local autoServerHopTask = nil
        SETTINGS.persistToggles = SETTINGS.persistToggles or false

        -- Main tab controls
        Tabs.Main:AddButton({
            Title = "Claim Booth",
            Description = "Attempt to claim nearest empty booth",
            Callback = function()
                task.spawn(function()
                    notify("Booth", "Attempting claim...", 3)
                    local ok, res = claimBooth()
                    if ok and res then
                        notify("Booth", "Claim attempted (success).", 4)
                    else
                        notify("Booth", "Claim attempt finished or failed.", 4)
                    end
                end)
            end
        })

        -- Main tab only keeps the Claim button and Anti-AFK toggle
        local AntiAfkToggle = Tabs.Main:AddToggle("AntiAFK", { Title = "Anti-AFK", Default = SETTINGS.antiAfk })
        AntiAfkToggle:OnChanged(function()
            SETTINGS.antiAfk = Options.AntiAFK.Value
            if SETTINGS.antiAfk then pcall(enableAntiAfk) else pcall(disableAntiAfk) end
        end)

        -- Server-Hop tab: slider for how long to stay before hopping and button
        Tabs.ServerHop:AddSlider("ServerStayTime", {
            Title = "Server Stay Time (minutes)",
            Default = serverStayTime,
            Min = 1,
            Max = 180,
            Rounding = 0,
            Callback = function(Value)
                serverStayTime = tonumber(Value) or serverStayTime
            end
        })

        Tabs.ServerHop:AddButton({
            Title = "Server Hop Now",
            Description = "Search for servers and teleport (19-22 players)",
            Callback = function()
                task.spawn(function()
                    serverHopNow(19, 22, true)
                end)
            end
        })

        local AutoServerHopToggle = Tabs.ServerHop:AddToggle("AutoServerHop", { Title = "Auto Server Hop", Default = false })
        AutoServerHopToggle:OnChanged(function()
            autoServerHopEnabled = Options.AutoServerHop and Options.AutoServerHop.Value or false
            if autoServerHopEnabled then
                -- start background task
                if autoServerHopTask then return end
                autoServerHopTask = task.spawn(function()
                    while autoServerHopEnabled do
                        local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                        notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                        task.wait(waitTime)
                        if not autoServerHopEnabled then break end
                        serverHopNow(19, 22, true)
                    end
                    autoServerHopTask = nil
                end)
            else
                -- stopping
                autoServerHopEnabled = false
                if autoServerHopTask then
                    autoServerHopTask = nil
                end
            end
        end)

        -- Settings tab: persistence controls and miscellaneous options
        Tabs.Settings:AddToggle("PersistToggles", { Title = "Persist Toggles Across Hops", Default = SETTINGS.persistToggles })
        Tabs.Settings:AddInput("MiscNote", { Title = "Notes (not saved)", Default = "Toggle persistence controls whether toggle states persist across teleports.", Callback = function() end })

        -- Webhook tab: moved webhook controls here
        local WebhookToggle = Tabs.Webhook:AddToggle("WebhookEnabled", { Title = "Webhook Enabled", Default = SETTINGS.webhookToggle })
        WebhookToggle:OnChanged(function()
            SETTINGS.webhookToggle = Options.WebhookEnabled.Value
            if SETTINGS.webhookToggle then
                startDonationMonitor()
            else
                stopDonationMonitor()
            end
        end)
        Tabs.Webhook:AddInput("WebhookURL", {
            Title = "Webhook URL",
            Default = SETTINGS.webhookUrl,
            Placeholder = "https://discord.com/api/webhooks...",
            Callback = function(Value)
                SETTINGS.webhookUrl = tostring(Value or "")
            end
        })
        Tabs.Webhook:AddInput("DonationStatName", {
            Title = "Donation Stat Name",
            Default = donationStatName,
            Placeholder = "Raised",
            Callback = function(Value)
                donationStatName = tostring(Value or "Raised")
            end
        })

        -- Hand the library over to our managers
        SaveManager:SetLibrary(Fluent)
        InterfaceManager:SetLibrary(Fluent)
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({})
        InterfaceManager:SetFolder("PlsWait")
        SaveManager:SetFolder("PlsWait/specific-game")
        InterfaceManager:BuildInterfaceSection(Tabs.Settings)
        SaveManager:BuildConfigSection(Tabs.Settings)

        Window:SelectTab(1)

        Fluent:Notify({
            Title = "Pls Wait",
            Content = "Fluent UI loaded.",
            Duration = 6
        })

        -- Load autoload config if any
        pcall(function() SaveManager:LoadAutoloadConfig() end)

        -- If a queued teleport inserted a config into _G, apply it now so settings persist across hops
        pcall(function()
            if type(_G) == "table" and type(_G.__PLS_WAIT_CONFIG) == "table" then
                local cfg = _G.__PLS_WAIT_CONFIG
                if cfg.webhookToggle ~= nil then SETTINGS.webhookToggle = cfg.webhookToggle end
                if cfg.webhookUrl ~= nil then SETTINGS.webhookUrl = cfg.webhookUrl end
                if cfg.antiAfk ~= nil then SETTINGS.antiAfk = cfg.antiAfk end
                if cfg.serverStayTime ~= nil then serverStayTime = tonumber(cfg.serverStayTime) or serverStayTime end
                if cfg.persistToggles ~= nil then SETTINGS.persistToggles = cfg.persistToggles end
                if cfg.autoServerHop ~= nil then autoServerHopEnabled = cfg.autoServerHop end
                -- clear it so it doesn't affect future runs
                _G.__PLS_WAIT_CONFIG = nil
            end
        end)

        -- After loading saved config, handle whether toggles should persist across teleports
        pcall(function()
            local persist = SETTINGS.persistToggles
            if Options and Options.PersistToggles and Options.PersistToggles.Value ~= nil then
                persist = Options.PersistToggles.Value
            end

            if not persist then
                -- prevent toggles from being saved going forward and reset toggles to defaults
                SaveManager:SetIgnoreIndexes({ "AntiAFK", "WebhookEnabled", "AutoServerHop" })
                if Options and Options.AntiAFK and Options.AntiAFK.SetValue then
                    Options.AntiAFK:SetValue(SETTINGS.antiAfk)
                end
                if Options and Options.WebhookEnabled and Options.WebhookEnabled.SetValue then
                    Options.WebhookEnabled:SetValue(SETTINGS.webhookToggle)
                end
                if Options and Options.AutoServerHop and Options.AutoServerHop.SetValue then
                    Options.AutoServerHop:SetValue(autoServerHopEnabled)
                end
            else
                SaveManager:SetIgnoreIndexes({})
            end

            -- initialize server stay time from options if present
            if Options and Options.ServerStayTime and Options.ServerStayTime.Value then
                serverStayTime = tonumber(Options.ServerStayTime.Value) or serverStayTime
            end

            -- If webhook was enabled via saved config or Options, start donation monitor
            local enabled = SETTINGS.webhookToggle
            if Options and Options.WebhookEnabled and Options.WebhookEnabled.Value ~= nil then
                enabled = enabled or Options.WebhookEnabled.Value
            end
            if enabled then startDonationMonitor() end

            -- If AutoServerHop was requested via saved config, kick off the task
            if autoServerHopEnabled then
                if Options and Options.AutoServerHop and Options.AutoServerHop.SetValue then
                    Options.AutoServerHop:SetValue(true)
                end
                -- start the background loop
                if not autoServerHopTask then
                    autoServerHopTask = task.spawn(function()
                        while (Options and Options.AutoServerHop and Options.AutoServerHop.Value) or autoServerHopEnabled do
                            local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                            notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                            task.wait(waitTime)
                            serverHopNow(19, 22, true)
                        end
                        autoServerHopTask = nil
                    end)
                end
            end
        end)
    end
end

-- Script loaded: use functions directly (not returning a module table)
-- Auto-run a single claim on script execution
task.spawn(function()
    task.wait(1)
    pcall(function() claimBooth() end)
end)
