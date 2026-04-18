--[[
    DONATE GAME - Simple GUI
    - Basic red theme
    - Essential features only
]]

if game.PlaceId ~= 6652551895 then
    return
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title or "DONATE GAME"),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 4,
        })
    end)
end

local function sendChatMessage(message)
    if not message or message == "" then
        return
    end
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if TextChatService and TextChatService.ChatInputBarConfiguration then
            local chatInput = TextChatService:FindFirstChildOfClass("ChatInputBar")
            if chatInput then
                chatInput:CaptureFocus()
                chatInput.Text = message
                RunService.Heartbeat:Wait()
                chatInput:ReleaseFocus(true)
            end
        else
            game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents") and game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest"):FireServer(message, "All")
        end
    end)
end

local settings = {
    spinSet = false,
    helicopterEnabled = false,
    antiAfkEnabled = false,
}

local function saveSettings()
    pcall(function()
        writefile("dono_game_settings.json", HttpService:JSONEncode(settings))
    end)
end

local function loadSettings()
    pcall(function()
        local data = readfile("dono_game_settings.json")
        if data then
            settings = HttpService:JSONDecode(data)
        end
    end)
end

loadSettings()

local function getCharacterHumanoidRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

local function applySpinState()
    local _, _, root = getCharacterHumanoidRoot()
    if not root then return end
    local existing = root:FindFirstChild("Spin")
    if settings.spinSet then
        if not (existing and existing:IsA("BodyAngularVelocity")) then
            existing = Instance.new("BodyAngularVelocity")
            existing.Name = "Spin"
            existing.MaxTorque = Vector3.new(0, math.huge, 0)
            existing.Parent = root
        end
        existing.AngularVelocity = Vector3.new(0, 0.25, 0)
    else
        if existing then existing:Destroy() end
    end
end

local function startHelicopterIdleMode()
    if not settings.helicopterEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not root then return end
    sendChatMessage("/e dance2")
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                track:Stop()
            end
            animator:Destroy()
        end
    end
    local heliBody = root:FindFirstChild("HL1__HELI")
    if not (heliBody and heliBody:IsA("BodyAngularVelocity")) then
        heliBody = Instance.new("BodyAngularVelocity")
        heliBody.Name = "HL1__HELI"
        heliBody.MaxTorque = Vector3.new(0, math.huge, 0)
        heliBody.Parent = root
    end
    heliBody.AngularVelocity = Vector3.new(0, 0.5, 0)
end

local function stopHelicopterIdle()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").RootPart
        if root then
            local heliBody = root:FindFirstChild("HL1__HELI")
            if heliBody then heliBody:Destroy() end
        end
    end
end

local function chooseServerId()
    local ok, serverList = pcall(function()
        return TeleportService:GetServerList(6652551895)
    end)
    if not ok or not serverList then return nil end
    local candidates = {}
    local maxPlayers = 0
    local maxServer = nil
    for _, server in ipairs(serverList) do
        local playerCount = server.playing or 0
        if playerCount >= 27 and playerCount <= 30 then
            table.insert(candidates, server.id)
        end
        if playerCount > maxPlayers then
            maxPlayers = playerCount
            maxServer = server.id
        end
    end
    if #candidates > 0 then
        return candidates[math.random(1, #candidates)]
    elseif maxServer then
        return maxServer
    end
    return nil
end

-- Simple Red UI
local gui = Instance.new("ScreenGui")
gui.Name = "SimpleDonateGameGUI"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 300, 0, 250)
main.Position = UDim2.fromOffset(100, 100)
main.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
main.BorderSizePixel = 2
main.BorderColor3 = Color3.fromRGB(150, 0, 0)
main.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
title.Text = "DONATE GAME"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Parent = main

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 5)
layout.Parent = main

local function createToggle(text, key)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = main

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.35, 0, 1, 0)
    button.Position = UDim2.new(0.65, 0, 0, 0)
    button.BackgroundColor3 = settings[key] and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    button.Text = settings[key] and "ON" or "OFF"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 14
    button.Parent = frame

    button.MouseButton1Click:Connect(function()
        settings[key] = not settings[key]
        button.Text = settings[key] and "ON" or "OFF"
        button.BackgroundColor3 = settings[key] and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
        saveSettings()
        if key == "spinSet" then
            applySpinState()
        elseif key == "helicopterEnabled" then
            if settings[key] then
                startHelicopterIdleMode()
            else
                stopHelicopterIdle()
            end
        end
    end)
end

local function createButton(text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 30)
    button.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 14
    button.Parent = main
    button.MouseButton1Click:Connect(callback)
end

createToggle("Spin Speed", "spinSet")
createToggle("Helicopter Mode", "helicopterEnabled")
createToggle("Anti AFK", "antiAfkEnabled")
createButton("Server Hop", function()
    local serverId = chooseServerId()
    if serverId then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(6652551895, serverId, LocalPlayer)
        end)
        notify("Server Hop", "Hopping to server...", 3)
    else
        notify("Server Hop", "No servers found", 3)
    end
end)

-- Dragging
local dragging = false
local dragStart = nil
local startPos = nil

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    RunService.Heartbeat:Wait()
    applySpinState()
    if settings.helicopterEnabled then
        startHelicopterIdleMode()
    end
end)

if LocalPlayer.Character then
    applySpinState()
    if settings.helicopterEnabled then
        startHelicopterIdleMode()
    end
end

return gui
