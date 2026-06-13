-- PLS WAIT - Custom script scaffold for place 14212732626
-- Created: scaffold for user's booth claiming code integration

repeat task.wait() until game:IsLoaded()

local PLACE_ID = 14212732626
if tonumber(game.PlaceId) ~= tonumber(PLACE_ID) then
    warn("This script is intended for place id: "..tostring(PLACE_ID).." — aborting.")
    return
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local SETTINGS = {
    webhookToggle = false,
    webhookUrl = "",
    antiAfk = true,
}
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
-- Simple local notifier (uses SetCore SendNotification when available)
local function notify(title, text, duration)
    pcall(function()
        local starter = game:GetService("StarterGui")
        starter:SetCore("SendNotification", {Title = tostring(title or "Notice"), Text = tostring(text or ""), Duration = tonumber(duration) or 3})
    end)
end

-- Return a reasonable pivot/position for a stand-like object
local function tryGetPivotPosition(obj)
    if not obj then return nil end
    if typeof(obj) == "Instance" then
        if obj:IsA("BasePart") then return obj.Position end
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        local p = obj:FindFirstChild("Pivot") or obj:FindFirstChild("Center")
        if p and p:IsA("BasePart") then return p.Position end
        -- fallback: first BasePart descendant
        for _, v in ipairs(obj:GetDescendants()) do
            if v:IsA("BasePart") then return v.Position end
        end
    end
    return nil
end

-- Resolve a numeric slot id from a Stand instance using multiple fallbacks
local function findSlotFromStand(stand)
    if not stand then return nil end
    -- try name digits
    local n = tostring(stand.Name or "")
    local m = n:match("(%d+)")
    if m then return tonumber(m) end

    -- try attributes
    if stand.GetAttribute then
        local a = stand:GetAttribute("StandId") or stand:GetAttribute("Stand") or stand:GetAttribute("Slot")
        if a then return tonumber(a) end
    end

    -- try common Int/Number/String children
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

-- Anti-AFK handlers
local _antiAfkConn = nil
local function enableAntiAfk()
    if _antiAfkConn then return end
    local plr = LocalPlayer
    _antiAfkConn = plr.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0,0))
        end)
    end)
end
local function disableAntiAfk()
    if _antiAfkConn then
        pcall(function() _antiAfkConn:Disconnect() end)
        _antiAfkConn = nil
    end
end

-- Simple server hop: fetch public servers and teleport to a different instance
local function serverHopNow()
    local ok, data = pcall(function()
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100"):format(tostring(game.PlaceId))
        local res = HttpService:GetAsync(url)
        return HttpService:JSONDecode(res)
    end)
    if not ok or not data then
        notify("ServerHop", "Failed to fetch server list.", 4)
        return
    end
    for _, s in ipairs(data.data or {}) do
        if s.id and tostring(s.id) ~= tostring(game.JobId) and (not s.playing or not s.maxPlayers or s.playing < s.maxPlayers) then
            pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
            end)
            return
        end
    end
    notify("ServerHop", "No suitable server found.", 4)
end
do
    local ok, playerGui = pcall(function()
        return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 6)
    end)
    if not ok or not playerGui then return end

    pcall(function()
        if playerGui:FindFirstChild("PlsWaitGui") then playerGui.PlsWaitGui:Destroy() end

        local screen = Instance.new("ScreenGui")
        screen.Name = "PlsWaitGui"
        screen.ResetOnSpawn = false
        screen.Parent = playerGui

        local main = Instance.new("Frame")
        main.Name = "Main"
        main.Size = UDim2.new(0, 540, 0, 360)
        main.Position = UDim2.new(0.5, -270, 0.5, -180)
        main.BackgroundColor3 = Color3.fromRGB(28,28,30)
        main.BorderSizePixel = 0
        main.Parent = screen
        local mcorner = Instance.new("UICorner") mcorner.CornerRadius = UDim.new(0,12) mcorner.Parent = main

        local sidebar = Instance.new("Frame")
        sidebar.Size = UDim2.new(0, 140, 1, 0)
        sidebar.Position = UDim2.new(0,0,0,0)
        sidebar.BackgroundTransparency = 1
        sidebar.Parent = main

        local function makeTabButton(text, y)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -16, 0, 48)
            b.Position = UDim2.new(0,8,0,y)
            b.BackgroundColor3 = Color3.fromRGB(40,40,44)
            b.TextColor3 = Color3.fromRGB(240,240,240)
            b.Font = Enum.Font.GothamSemibold
            b.TextSize = 16
            b.Text = text
            b.AutoButtonColor = true
            local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,8) c.Parent = b
            b.Parent = main
            return b
        end

        local tabBooth = makeTabButton("Booth", 12)
        local tabServer = makeTabButton("ServerHop", 72)
        local tabMain = makeTabButton("Main", 132)

        local content = Instance.new("Frame")
        content.Size = UDim2.new(1, -160, 1, -24)
        content.Position = UDim2.new(0,150,0,12)
        content.BackgroundTransparency = 1
        content.Parent = main

        local function makeContentFrame()
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1,0,1,0)
            f.BackgroundTransparency = 1
            f.Parent = content
            f.Visible = false
            return f
        end

        local frameBooth = makeContentFrame()
        local frameServer = makeContentFrame()
        local frameMain = makeContentFrame()
        frameBooth.Visible = true

        -- Booth tab
        local claimBtn = Instance.new("TextButton")
        claimBtn.Size = UDim2.new(1, 0, 0, 48)
        claimBtn.Position = UDim2.new(0, 0, 0, 0)
        claimBtn.BackgroundColor3 = Color3.fromRGB(50,50,54)
        claimBtn.TextColor3 = Color3.fromRGB(240,240,240)
        claimBtn.Font = Enum.Font.GothamSemibold
        claimBtn.TextSize = 16
        claimBtn.Text = "Claim Booth"
        claimBtn.Parent = frameBooth
        local cbcorner = Instance.new("UICorner") cbcorner.CornerRadius = UDim.new(0,8) cbcorner.Parent = claimBtn
        claimBtn.MouseButton1Click:Connect(function()
            task.spawn(function()
                notify("Booth", "Attempting claim...", 3)
                local ok, res = claimBooth()
                if ok and res then
                    notify("Booth", "Claim attempted (success).", 4)
                else
                    notify("Booth", "Claim attempt finished or failed.", 4)
                end
            end)
        end)

        local antiAfkBtn = Instance.new("TextButton")
        antiAfkBtn.Size = UDim2.new(1, 0, 0, 40)
        antiAfkBtn.Position = UDim2.new(0, 0, 0, 64)
        antiAfkBtn.BackgroundColor3 = Color3.fromRGB(50,50,54)
        antiAfkBtn.TextColor3 = Color3.fromRGB(240,240,240)
        antiAfkBtn.Font = Enum.Font.GothamSemibold
        antiAfkBtn.TextSize = 14
        antiAfkBtn.Text = "Anti‑AFK: " .. (SETTINGS.antiAfk and "On" or "Off")
        antiAfkBtn.Parent = frameBooth
        local aa = Instance.new("UICorner") aa.CornerRadius = UDim.new(0,8) aa.Parent = antiAfkBtn
        antiAfkBtn.MouseButton1Click:Connect(function()
            SETTINGS.antiAfk = not SETTINGS.antiAfk
            antiAfkBtn.Text = "Anti‑AFK: " .. (SETTINGS.antiAfk and "On" or "Off")
            if SETTINGS.antiAfk then pcall(enableAntiAfk) else pcall(disableAntiAfk) end
        end)

        -- ServerHop tab
        local serverHopBtn = Instance.new("TextButton")
        serverHopBtn.Size = UDim2.new(1, 0, 0, 48)
        serverHopBtn.Position = UDim2.new(0, 0, 0, 0)
        serverHopBtn.BackgroundColor3 = Color3.fromRGB(50,50,54)
        serverHopBtn.TextColor3 = Color3.fromRGB(240,240,240)
        serverHopBtn.Font = Enum.Font.GothamSemibold
        serverHopBtn.TextSize = 16
        serverHopBtn.Text = "Server Hop"
        serverHopBtn.Parent = frameServer
        local shc = Instance.new("UICorner") shc.CornerRadius = UDim.new(0,8) shc.Parent = serverHopBtn
        serverHopBtn.MouseButton1Click:Connect(function() task.spawn(serverHopNow) end)

        -- Main tab (webhook toggle + info)
        local webhookBtn = Instance.new("TextButton")
        webhookBtn.Size = UDim2.new(1, 0, 0, 40)
        webhookBtn.Position = UDim2.new(0, 0, 0, 0)
        webhookBtn.BackgroundColor3 = Color3.fromRGB(50,50,54)
        webhookBtn.TextColor3 = Color3.fromRGB(240,240,240)
        webhookBtn.Font = Enum.Font.GothamSemibold
        webhookBtn.TextSize = 14
        webhookBtn.Text = "Webhook: Off"
        webhookBtn.Parent = frameMain
        local wc = Instance.new("UICorner") wc.CornerRadius = UDim.new(0,8) wc.Parent = webhookBtn
        webhookBtn.MouseButton1Click:Connect(function()
            SETTINGS.webhookToggle = not SETTINGS.webhookToggle
            webhookBtn.Text = "Webhook: " .. (SETTINGS.webhookToggle and "On" or "Off")
        end)

        -- Tab switching
        local function showTab(t)
            frameBooth.Visible = (t == "Booth")
            frameServer.Visible = (t == "Server")
            frameMain.Visible = (t == "Main")
        end
        tabBooth.MouseButton1Click:Connect(function() showTab("Booth") end)
        tabServer.MouseButton1Click:Connect(function() showTab("Server") end)
        tabMain.MouseButton1Click:Connect(function() showTab("Main") end)

        -- Close / toggle visibility via RightControl
        local visible = true
        local function setVisible(v)
            visible = v
            main.Visible = v
        end
        setVisible(true)
        local UserInput = game:GetService("UserInputService")
        UserInput.InputBegan:Connect(function(input, g)
            if g then return end
            if input.KeyCode == Enum.KeyCode.RightControl then
                setVisible(not visible)
            end
        end)

        -- small close button
        local closeSmall = Instance.new("TextButton")
        closeSmall.Size = UDim2.new(0, 28, 0, 28)
        closeSmall.Position = UDim2.new(1, -36, 0, 8)
        closeSmall.Text = "✕"
        closeSmall.BackgroundColor3 = Color3.fromRGB(60,60,64)
        closeSmall.TextColor3 = Color3.fromRGB(220,220,220)
        closeSmall.Font = Enum.Font.GothamBold
        closeSmall.TextSize = 16
        closeSmall.Parent = main
        local csc = Instance.new("UICorner") csc.CornerRadius = UDim.new(0,6) csc.Parent = closeSmall
        closeSmall.MouseButton1Click:Connect(function() setVisible(false) end)

    end)

    -- fire a single booth claim on script execute
    task.spawn(function() pcall(claimBooth) end)
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
-- Script loaded: use functions directly (not returning a module table)
