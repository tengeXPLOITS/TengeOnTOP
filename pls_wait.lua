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

-- Simple server hop helper (fetches public servers for same place)
local function serverHopNow()
    task.spawn(function()
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100"):format(tostring(PLACE_ID))
        local res = performHttpRequest({ Url = url, Method = "GET" })
        if res and type(res.Body) == "string" then
            local ok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
            if ok and decoded and type(decoded.data) == "table" then
                for _, server in ipairs(decoded.data) do
                    if server.id and server.playing and tonumber(server.playing) > 0 and server.id ~= tostring(game.JobId) then
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer)
                        end)
                        return
                    end
                end
            end
        end
        notify("Server Hop", "No suitable servers found.", 4)
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
local function postWebhookCode(code)
    if not SETTINGS.webhookToggle then return false end
    local url = tostring(SETTINGS.webhookUrl or ""):match("%S+")
    if not url or url == "" then return false end
    pcall(function()
        performHttpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ content = tostring(code) })
        })
    end)
    return true
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
            Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
        }

        local Options = Fluent.Options

        -- persistent toggles for auto-claim
        local autoClaiming = false
        local autoClaimTask = nil

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

        Tabs.Main:AddButton({
            Title = "Server Hop",
            Description = "Teleport to another server for this place",
            Callback = function()
                task.spawn(serverHopNow)
            end
        })

        local AutoToggle = Tabs.Main:AddToggle("AutoClaim", { Title = "Auto-Claim", Default = false })
        AutoToggle:OnChanged(function()
            autoClaiming = Options.AutoClaim.Value
            if autoClaiming then
                autoClaimTask = task.spawn(function()
                    while autoClaiming do
                        local ok, res = claimBooth()
                        if ok and res then
                            autoClaiming = false
                            Options.AutoClaim:SetValue(false)
                            break
                        end
                        task.wait(2.5)
                        if Fluent.Unloaded then break end
                    end
                end)
            else
                if autoClaimTask then
                    pcall(function() task.cancel(autoClaimTask) end)
                    autoClaimTask = nil
                end
            end
        end)

        local AntiAfkToggle = Tabs.Main:AddToggle("AntiAFK", { Title = "Anti-AFK", Default = SETTINGS.antiAfk })
        AntiAfkToggle:OnChanged(function()
            SETTINGS.antiAfk = Options.AntiAFK.Value
            if SETTINGS.antiAfk then pcall(enableAntiAfk) else pcall(disableAntiAfk) end
        end)

        -- Settings
        Tabs.Settings:AddToggle("WebhookEnabled", { Title = "Webhook Enabled", Default = SETTINGS.webhookToggle })
        Tabs.Settings:AddInput("WebhookURL", {
            Title = "Webhook URL",
            Default = SETTINGS.webhookUrl,
            Placeholder = "https://discord.com/api/webhooks/...",
            Callback = function(Value)
                SETTINGS.webhookUrl = tostring(Value or "")
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
    end
end

-- Script loaded: use functions directly (not returning a module table)
