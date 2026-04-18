-- Refined Donate Game GUI

if not game then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- Sunset Theme
local THEME = {
    bg = Color3.fromRGB(139, 69, 19),
    title = Color3.fromRGB(205, 92, 92),
    button = Color3.fromRGB(255, 69, 0),
    buttonOn = Color3.fromRGB(50, 205, 50),
    text = Color3.new(1, 1, 1)
}

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DonateGameGUI"
gui.Parent = LocalPlayer.PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 300, 0, 200)
main.Position = UDim2.new(0.5, -150, 0.5, -100)
main.BackgroundColor3 = THEME.bg
main.BorderSizePixel = 2
main.BorderColor3 = THEME.title
main.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = THEME.title
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
layout.Padding = UDim.new(0, 5)
layout.Parent = content

-- Spin Toggle
local spinBtn = Instance.new("TextButton")
spinBtn.Size = UDim2.new(1, -10, 0, 35)
spinBtn.BackgroundColor3 = THEME.button
spinBtn.Text = "Spin: OFF"
spinBtn.TextColor3 = THEME.text
spinBtn.Font = Enum.Font.SourceSansBold
spinBtn.TextSize = 16
spinBtn.Parent = content

local spinOn = false
local spinSpeed = 1

spinBtn.MouseButton1Click:Connect(function()
    spinOn = not spinOn
    spinBtn.Text = "Spin: " .. (spinOn and "ON" or "OFF")
    spinBtn.BackgroundColor3 = spinOn and THEME.buttonOn or THEME.button
    applySpin()
end)

-- Spin Speed Slider
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -10, 0, 25)
speedLabel.BackgroundColor3 = THEME.button
speedLabel.Text = "Speed: " .. spinSpeed
speedLabel.TextColor3 = THEME.text
speedLabel.Font = Enum.Font.SourceSans
speedLabel.TextSize = 14
speedLabel.Parent = content

local speedSlider = Instance.new("TextBox")
speedSlider.Size = UDim2.new(1, -10, 0, 25)
speedSlider.BackgroundColor3 = THEME.button
speedSlider.Text = tostring(spinSpeed)
speedSlider.TextColor3 = THEME.text
speedSlider.Font = Enum.Font.SourceSans
speedSlider.TextSize = 14
speedSlider.Parent = content

speedSlider.FocusLost:Connect(function()
    local num = tonumber(speedSlider.Text)
    if num then
        spinSpeed = math.max(0.1, math.min(10, num))
        speedLabel.Text = "Speed: " .. spinSpeed
        speedSlider.Text = tostring(spinSpeed)
        if spinOn then applySpin() end
    else
        speedSlider.Text = tostring(spinSpeed)
    end
end)

function applySpin()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local spin = root:FindFirstChild("Spin")
            if spinOn then
                if not spin then
                    spin = Instance.new("BodyAngularVelocity")
                    spin.Name = "Spin"
                    spin.MaxTorque = Vector3.new(0, 400000, 0)
                    spin.Parent = root
                end
                spin.AngularVelocity = Vector3.new(0, spinSpeed, 0)
            else
                if spin then spin:Destroy() end
            end
        end
    end
end

-- Helicopter Toggle
local heliBtn = Instance.new("TextButton")
heliBtn.Size = UDim2.new(1, -10, 0, 35)
heliBtn.BackgroundColor3 = THEME.button
heliBtn.Text = "Helicopter: OFF"
heliBtn.TextColor3 = THEME.text
heliBtn.Font = Enum.Font.SourceSansBold
heliBtn.TextSize = 16
heliBtn.Parent = content

local heliOn = false

heliBtn.MouseButton1Click:Connect(function()
    heliOn = not heliOn
    heliBtn.Text = "Helicopter: " .. (heliOn and "ON" or "OFF")
    heliBtn.BackgroundColor3 = heliOn and THEME.buttonOn or THEME.button
    if heliOn then
        startHelicopterIdle()
    else
        stopHelicopterIdle()
    end
end)

function startHelicopterIdle()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not root then return end

    -- Play helicopter idle animation
    if hum then
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://10921034824" -- Helicopter idle animation
        local track = hum:LoadAnimation(anim)
        track:Play()
    end

    -- Freeze animations
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                if track.Animation.AnimationId ~= "rbxassetid://10921034824" then
                    track:Stop()
                end
            end
            animator:Destroy()
        end
    end

    -- Apply helicopter spin
    local heli = root:FindFirstChild("Heli")
    if not heli then
        heli = Instance.new("BodyAngularVelocity")
        heli.Name = "Heli"
        heli.MaxTorque = Vector3.new(0, 400000, 0)
        heli.AngularVelocity = Vector3.new(0, 5, 0)
        heli.Parent = root
    end
end

function stopHelicopterIdle()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").RootPart
        if root then
            local heli = root:FindFirstChild("Heli")
            if heli then heli:Destroy() end
        end
    end
end

-- Dragging (Mouse and Touch)
local dragging = false
local dragStart, startPos

local function startDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end

local function updateDrag(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end

local function endDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end

title.InputBegan:Connect(startDrag)
title.InputChanged:Connect(updateDrag)
title.InputEnded:Connect(endDrag)

-- Character respawn handling
LocalPlayer.CharacterAdded:Connect(function()
    RunService.Heartbeat:Wait()
    if spinOn then applySpin() end
    if heliOn then startHelicopterIdle() end
end)

if LocalPlayer.Character then
    if spinOn then applySpin() end
    if heliOn then startHelicopterIdle() end
end

return gui
