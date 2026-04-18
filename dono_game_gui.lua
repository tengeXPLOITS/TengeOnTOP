-- Simple Donate Game GUI: Spin and Helicopter configs only

if not game then game = workspace and workspace.Parent end
if not game then return end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

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
    if not message or message == "" then return end
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
    spinSpeed = 1,
    helicopterEnabled = false,
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
        existing.AngularVelocity = Vector3.new(0, 0.25 * settings.spinSpeed, 0)
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

-- Sunset Theme UI
local THEME = {
    bg = Color3.fromRGB(139, 69, 19), -- Saddle brown
    tabBg = Color3.fromRGB(205, 92, 92), -- Indian red
    tabActive = Color3.fromRGB(255, 140, 0), -- Dark orange
    button = Color3.fromRGB(255, 69, 0), -- Red orange
    buttonOn = Color3.fromRGB(50, 205, 50), -- Lime green
    text = Color3.fromRGB(255, 255, 255), -- White
    border = Color3.fromRGB(255, 165, 0), -- Orange
}

local gui = Instance.new("ScreenGui")
gui.Name = "SunsetDonateGameGUI"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 300, 0, 200)
main.Position = UDim2.fromOffset(200, 150)
main.BackgroundColor3 = THEME.bg
main.BorderSizePixel = 2
main.BorderColor3 = THEME.border
main.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = THEME.tabBg
title.Text = "DONATE GAME"
title.TextColor3 = THEME.text
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.Parent = main

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -40)
content.Position = UDim2.new(0, 0, 0, 40)
content.BackgroundTransparency = 1
content.Parent = main

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = content

-- Spin Toggle
local spinToggle = Instance.new("TextButton")
spinToggle.Size = UDim2.new(1, -20, 0, 40)
spinToggle.Position = UDim2.new(0, 10, 0, 10)
spinToggle.BackgroundColor3 = settings.spinSet and THEME.buttonOn or THEME.button
spinToggle.Text = "Spin: " .. (settings.spinSet and "ON" or "OFF")
spinToggle.TextColor3 = THEME.text
spinToggle.Font = Enum.Font.SourceSansBold
spinToggle.TextSize = 16
spinToggle.Parent = content

spinToggle.MouseButton1Click:Connect(function()
    settings.spinSet = not settings.spinSet
    spinToggle.Text = "Spin: " .. (settings.spinSet and "ON" or "OFF")
    spinToggle.BackgroundColor3 = settings.spinSet and THEME.buttonOn or THEME.button
    saveSettings()
    applySpinState()
end)

-- Spin Speed Slider
local spinSlider = Instance.new("TextBox")
spinSlider.Size = UDim2.new(1, -20, 0, 30)
spinSlider.Position = UDim2.new(0, 10, 0, 60)
spinSlider.BackgroundColor3 = THEME.button
spinSlider.Text = "Speed: " .. settings.spinSpeed
spinSlider.TextColor3 = THEME.text
spinSlider.Font = Enum.Font.SourceSans
spinSlider.TextSize = 14
spinSlider.Parent = content

spinSlider.FocusLost:Connect(function()
    local num = tonumber(spinSlider.Text:match("%d+"))
    if num then
        settings.spinSpeed = math.max(0.1, math.min(5, num))
        spinSlider.Text = "Speed: " .. settings.spinSpeed
        saveSettings()
        applySpinState()
    else
        spinSlider.Text = "Speed: " .. settings.spinSpeed
    end
end)

-- Helicopter Toggle
local heliToggle = Instance.new("TextButton")
heliToggle.Size = UDim2.new(1, -20, 0, 40)
heliToggle.Position = UDim2.new(0, 10, 0, 100)
heliToggle.BackgroundColor3 = settings.helicopterEnabled and THEME.buttonOn or THEME.button
heliToggle.Text = "Helicopter: " .. (settings.helicopterEnabled and "ON" or "OFF")
heliToggle.TextColor3 = THEME.text
heliToggle.Font = Enum.Font.SourceSansBold
heliToggle.TextSize = 16
heliToggle.Parent = content

heliToggle.MouseButton1Click:Connect(function()
    settings.helicopterEnabled = not settings.helicopterEnabled
    heliToggle.Text = "Helicopter: " .. (settings.helicopterEnabled and "ON" or "OFF")
    heliToggle.BackgroundColor3 = settings.helicopterEnabled and THEME.buttonOn or THEME.button
    saveSettings()
    if settings.helicopterEnabled then
        startHelicopterIdleMode()
    else
        stopHelicopterIdle()
    end
end)

-- Mobile Dragging
local dragging = false
local dragStart = nil
local startPos = nil

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Initialize
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
