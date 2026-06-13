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

local function claimEmptyStands()
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

    -- listen for server client notifications indicating a successful claim
    local claimStopFlag = false
    local clientNotif = ReplicatedStorage:FindFirstChild("ClientNotification")
    local clientNotifConn
    if clientNotif and clientNotif:IsA("RemoteEvent") then
        clientNotifConn = clientNotif.OnClientEvent:Connect(function(...)
            local first = select(1, ...)
            if tostring(first) == "Success" then
                claimStopFlag = true
                notify("Booth Claim", "Server reports claim success.", 4)
            end
        end)
    end

    local function tryTriggerNearbyClaimPrompts(pos)
        if not pos then return false end
        local triggered = false
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if not (inst and inst.Parent and inst:IsA("ProximityPrompt")) then continue end
            -- match prompt by name/action/objecttext/parent naming
            local pname = tostring(inst.Parent.Name or ""):lower()
            local action = tostring(inst.Action or ""):lower()
            local name = tostring(inst.Name or ""):lower()
            local objectText = tostring(inst.ObjectText or ""):lower()
            if not (name == "claim" or action:find("claim") or objectText:find("stand") or pname:find("stand")) then
                goto nextprompt
            end

            local pivot = tryGetPivotPosition(inst.Parent) or tryGetPivotPosition(inst)
            if not pivot or (pivot - pos).Magnitude > 8 then goto nextprompt end

            -- perform hold using the prompt's HoldDuration (fallback to 1s)
            local hold = 1
            pcall(function()
                if inst.HoldDuration then hold = tonumber(inst.HoldDuration) or hold end
            end)

            pcall(function()
                if inst.InputHoldBegin and inst.InputHoldEnd then
                    inst:InputHoldBegin()
                    task.wait(math.max(0.05, hold))
                    inst:InputHoldEnd()
                elseif inst.Trigger then
                    inst:Trigger()
                end
            end)

            triggered = true
            task.wait(0.08)
            if claimStopFlag then return true end
            ::nextprompt::
        end
        return triggered
    end

    for idx, stand in ipairs(standsList) do
        if not stand or not stand.Parent then
            -- skip invalid stand
        else
            if stand:FindFirstChild("ButtonPrompt") then
                -- handled via StandButtons; skip
            else
                local ownerObj = stand:FindFirstChild("Wner") or stand:FindFirstChild("Owner")
                local ownerEmpty = true
                if ownerObj and ownerObj:IsA("ObjectValue") then
                    ownerEmpty = (ownerObj.Value == nil)
                end

                if ownerEmpty then
                    local pivot = tryGetPivotPosition(stand)
                    if pivot then
                        moveCharacterToPosition(pivot)
                        task.wait(0.25)
                    end

                    local posForPrompt = pivot
                    if not posForPrompt and LocalPlayer.Character then
                        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        posForPrompt = hrp and hrp.Position
                    end

                    if posForPrompt then
                        local btnCandidate = buttonList[idx]
                        if btnCandidate and btnCandidate.Parent then
                            local claimPrompt = btnCandidate:FindFirstChild("Claim") or btnCandidate:FindFirstChildWhichIsA("ProximityPrompt")
                            if claimPrompt and claimPrompt:IsA("ProximityPrompt") then
                                pcall(function()
                                    if claimPrompt.Trigger then
                                        claimPrompt:Trigger()
                                    else
                                        claimPrompt:InputHoldBegin()
                                        task.wait(0.12)
                                        claimPrompt:InputHoldEnd()
                                    end
                                end)
                                task.wait(0.12)
                            end
                        end
                        if not claimStopFlag then
                            tryTriggerNearbyClaimPrompts(posForPrompt)
                        end
                    end

                    local slot = findSlotFromStand(stand)
                    if not slot then
                        notify("Booth Claim", ("Could not determine slot for %s"):format(tostring(stand.Name or "?")), 4)
                    else
                        -- Prefer direct remote claim (server uses ReplicatedStorage.ClaimStand)
                        local ok, res = pcall(function()
                            return remote:InvokeServer(slot)
                        end)
                        if ok then
                            notify("Booth Claim", ("Invoked ClaimStand for slot %d (response: %s)"):format(slot, tostring(res)), 4)
                            -- stop if server reports success via ClientNotification or truthy response
                            if claimStopFlag or tostring(res) == "Success" or res == true then
                                if clientNotifConn then pcall(function() clientNotifConn:Disconnect() end) end
                                return true
                            end
                            -- continue to next stand (we attempted a claim)
                            return true
                        else
                            notify("Booth Claim", ("Claim remote error for slot %d"):format(slot), 3)
                        end
                    end
                    task.wait(0.6)
                end
            end
        end
    end

    if clientNotifConn then pcall(function() clientNotifConn:Disconnect() end) end
    notify("Booth Claim", "No empty stands claimed.", 4)
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
    if ok and playerGui then
        pcall(function()
            if playerGui:FindFirstChild("PlsWaitGui") then playerGui.PlsWaitGui:Destroy() end

            local screen = Instance.new("ScreenGui")
            screen.Name = "PlsWaitGui"
            screen.ResetOnSpawn = false
            screen.Parent = playerGui

            local frame = Instance.new("Frame")
            frame.Name = "Main"
            frame.Size = UDim2.new(0.92, 0, 0.36, 0)
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Position = UDim2.new(0.5, 0, 0.5, 0)
            frame.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
            frame.BorderSizePixel = 0
            frame.Parent = screen

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 12)
            corner.Parent = frame

            local title = Instance.new("TextLabel")
            title.Name = "Title"
            title.Size = UDim2.new(1, -16, 0, 40)
            title.Position = UDim2.new(0, 8, 0, 8)
            title.BackgroundTransparency = 1
            title.Text = "PLS WAIT"
            title.Font = Enum.Font.GothamBold
            title.TextSize = 18
            title.TextColor3 = Color3.fromRGB(240,240,240)
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.Parent = frame

            local closeBtn = Instance.new("TextButton")
            closeBtn.Name = "Close"
            closeBtn.Size = UDim2.new(0, 36, 0, 28)
            closeBtn.Position = UDim2.new(1, -44, 0, 8)
            closeBtn.Text = "✕"
            closeBtn.Font = Enum.Font.GothamBold
            closeBtn.TextSize = 18
            closeBtn.TextColor3 = Color3.fromRGB(220,220,220)
            closeBtn.BackgroundTransparency = 0.6
            closeBtn.BackgroundColor3 = Color3.fromRGB(60,60,64)
            closeBtn.Parent = frame
            local closeCorner = Instance.new("UICorner")
            closeCorner.CornerRadius = UDim.new(0,6)
            closeCorner.Parent = closeBtn
            closeBtn.MouseButton1Click:Connect(function()
                pcall(function() screen:Destroy() end)
            end)

            local body = Instance.new("Frame")
            body.Name = "Body"
            body.Size = UDim2.new(1, -16, 1, -56)
            body.Position = UDim2.new(0, 8, 0, 48)
            body.BackgroundTransparency = 1
            body.Parent = frame

            local layout = Instance.new("UIListLayout")
            layout.Parent = body
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Padding = UDim.new(0,8)

            local function makeButton(text)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 44)
                btn.BackgroundColor3 = Color3.fromRGB(50,50,54)
                btn.TextColor3 = Color3.fromRGB(240,240,240)
                btn.Font = Enum.Font.GothamSemibold
                btn.TextSize = 16
                btn.Text = text
                btn.AutoButtonColor = true
                local c = Instance.new("UICorner")
                c.CornerRadius = UDim.new(0,8)
                c.Parent = btn
                btn.Parent = body
                return btn
            end

            local claimBtn = makeButton("Claim Booth")
            local serverHopBtn = makeButton("Server Hop")

            local autoClaimBtn = makeButton("Auto‑Claim: Off")
            local antiAfkBtn = makeButton("Anti‑AFK: " .. (SETTINGS.antiAfk and "On" or "Off"))

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

            serverHopBtn.MouseButton1Click:Connect(function()
                task.spawn(function() serverHopNow() end)
            end)

            local autoClaiming = false
            local autoClaimTask = nil
            autoClaimBtn.MouseButton1Click:Connect(function()
                autoClaiming = not autoClaiming
                autoClaimBtn.Text = "Auto‑Claim: " .. (autoClaiming and "On" or "Off")
                if autoClaiming then
                    autoClaimTask = task.spawn(function()
                        while autoClaiming do
                            pcall(function()
                                claimBooth()
                            end)
                            task.wait(2.5)
                        end
                    end)
                else
                    if autoClaimTask then
                        pcall(function() task.cancel(autoClaimTask) end)
                        autoClaimTask = nil
                    end
                end
            end)

            antiAfkBtn.MouseButton1Click:Connect(function()
                SETTINGS.antiAfk = not SETTINGS.antiAfk
                antiAfkBtn.Text = "Anti‑AFK: " .. (SETTINGS.antiAfk and "On" or "Off")
                if SETTINGS.antiAfk then pcall(enableAntiAfk) else pcall(disableAntiAfk) end
            end)

        end)
    end
end

-- Script loaded: use functions directly (not returning a module table)
