-- Donate Game personal GUI starter script
-- This file is meant to run in the Donate Game place (6652551895).
-- If you want this to auto-run after teleport, use your exploit's queue_on_teleport feature
-- or load this script manually in the new game.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local settings = {
    spinSet = false,
    spinSpeedMultiplier = 1,
    helicopterEnabled = false,
}

local currentAstronautIdleTrack = nil
local currentIdleTask = nil
local currentHelicopterSpinTask = nil

local function getCharacterHumanoidRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

local function getSpinAngularVelocity()
    return 0.25 * math.max(0, tonumber(settings.spinSpeedMultiplier) or 1)
end

local previousAnimateState = nil

local function setCharacterFreeze(enabled)
    local char, humanoid, root = getCharacterHumanoidRoot()
    if not char or not humanoid or not root then
        return
    end

    local animateScript = char:FindFirstChild("Animate")
    if animateScript and animateScript:IsA("LocalScript") then
        if enabled then
            previousAnimateState = animateScript.Enabled
            animateScript.Enabled = false
        elseif previousAnimateState ~= nil then
            animateScript.Enabled = previousAnimateState
            previousAnimateState = nil
        end
    end

    pcall(function()
        for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
            track:Stop()
        end
    end)

    pcall(function()
        humanoid.PlatformStand = enabled
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)
end

local function applySpinState()
    local _, _, root = getCharacterHumanoidRoot()
    if not root then
        return
    end

    local existing = root:FindFirstChild("Spin")
    if settings.spinSet then
        setCharacterFreeze(true)
        if not (existing and existing:IsA("BodyAngularVelocity")) then
            existing = Instance.new("BodyAngularVelocity")
            existing.Name = "Spin"
            existing.MaxTorque = Vector3.new(0, math.huge, 0)
            existing.Parent = root
        end
        existing.AngularVelocity = Vector3.new(0, getSpinAngularVelocity(), 0)
    else
        setCharacterFreeze(false)
        if existing and existing:IsA("BodyAngularVelocity") then
            existing:Destroy()
        end
    end
end

local function applyAstronautArmSpread(char)
    if not char then
        return
    end

    local function setShoulder(name, transform)
        local motor = char:FindFirstChild(name, true)
        if motor and motor:IsA("Motor6D") then
            pcall(function()
                motor.Transform = transform
            end)
        end
    end

    local spreadOffset = 0.25
    local angle = math.rad(35)
    setShoulder("LeftShoulder", CFrame.new(-spreadOffset, 0, 0) * CFrame.Angles(0, 0, angle))
    setShoulder("Left Shoulder", CFrame.new(-spreadOffset, 0, 0) * CFrame.Angles(0, 0, angle))
    setShoulder("RightShoulder", CFrame.new(spreadOffset, 0, 0) * CFrame.Angles(0, 0, -angle))
    setShoulder("Right Shoulder", CFrame.new(spreadOffset, 0, 0) * CFrame.Angles(0, 0, -angle))
end

local function resetAstronautArmSpread(char)
    if not char then
        return
    end

    local function resetShoulder(name)
        local motor = char:FindFirstChild(name, true)
        if motor and motor:IsA("Motor6D") then
            pcall(function()
                motor.Transform = CFrame.new()
            end)
        end
    end

    resetShoulder("LeftShoulder")
    resetShoulder("Left Shoulder")
    resetShoulder("RightShoulder")
    resetShoulder("Right Shoulder")
end

local function loadAstronautIdle()
    stopAstronautIdle()
    local pl = Players.LocalPlayer
    if not pl then
        return
    end
    local char = pl.Character
    if not char then
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    pcall(function()
        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            if track ~= currentAstronautIdleTrack then
                track:Stop()
            end
        end
    end)
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://10921034824"
    local ok, track = pcall(function()
        return animator:LoadAnimation(animation)
    end)
    animation:Destroy()
    if ok and track then
        currentAstronautIdleTrack = track
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = true
        pcall(function()
            track:Play()
        end)
        applyAstronautArmSpread(char)
    end
end

local function stopAstronautIdle()
    if currentAstronautIdleTrack then
        pcall(function()
            currentAstronautIdleTrack:Stop()
        end)
        pcall(function()
            currentAstronautIdleTrack:Destroy()
        end)
        currentAstronautIdleTrack = nil
    end
    resetAstronautArmSpread(Players.LocalPlayer and Players.LocalPlayer.Character)
end

local function getHelicopterIdleAngularVelocity()
    return 0.5
end

local function startHelicopterIdleMode()
    if not settings.helicopterEnabled then
        return
    end

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not root then return end

    loadAstronautIdle()

    local heliBody = root:FindFirstChild("HL1__HELI")
    if not (heliBody and heliBody:IsA("BodyAngularVelocity")) then
        heliBody = Instance.new("BodyAngularVelocity")
        heliBody.Name = "HL1__HELI"
        heliBody.MaxTorque = Vector3.new(0, math.huge, 0)
        heliBody.Parent = root
    end

    local idleSpeed = getHelicopterIdleAngularVelocity()
    stopHelicopterIdleTask()

    -- Ramp BodyAngularVelocity from 0 up to idleSpeed faster than old.lua (2s vs 6s)
    heliBody.AngularVelocity = Vector3.new(0, 0, 0)
    currentIdleTask = task.spawn(function()
        -- Ramp up phase
        local rampDuration = 2
        local rampStart = tick()
        while tick() - rampStart < rampDuration and settings.helicopterEnabled and root.Parent do
            local t = math.clamp((tick() - rampStart) / rampDuration, 0, 1)
            local ramped = idleSpeed * (t * t) -- quad-in ramp
            if heliBody and heliBody.Parent then
                heliBody.AngularVelocity = Vector3.new(0, ramped, 0)
            end
            task.wait()
        end
        if heliBody and heliBody.Parent then
            heliBody.AngularVelocity = Vector3.new(0, idleSpeed, 0)
        end

        -- Continuous idle spin with no pause
        while settings.helicopterEnabled and root.Parent do
            if heliBody and heliBody.Parent then
                heliBody.AngularVelocity = Vector3.new(0, idleSpeed, 0)
            end
            task.wait(0.1)
        end
    end)

    pcall(function()
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end)
end

local function stopHelicopterIdleTask()
    if currentIdleTask then
        pcall(function()
            task.cancel(currentIdleTask)
        end)
        currentIdleTask = nil
    end
end

local function stopHelicopterIdle()
    stopHelicopterIdleTask()
    stopAstronautIdle()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").RootPart
        if root then
            local heliBody = root:FindFirstChild("HL1__HELI")
            if heliBody then
                pcall(function()
                    heliBody:Destroy()
                end)
            end
        end
    end
end

local function createTextLabel(parent, text, size)
    local label = Instance.new("TextLabel")
    label.Size = size or UDim2.new(1, 0, 0, 24)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.Text = text
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function createButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = Color3.fromRGB(80, 25, 25)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 14
    button.TextColor3 = Color3.fromRGB(255, 220, 220)
    button.Text = text
    button.Parent = parent
    button.MouseButton1Click:Connect(callback)
    return button
end

local function createLabel(parent, text)
    local label = createTextLabel(parent, text)
    label.TextSize = 14
    return label
end

local function createToggle(parent, text, key)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 34)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = createLabel(frame, text)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Size = UDim2.new(0.65, 0, 1, 0)

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.33, 0, 1, 0)
    button.Position = UDim2.new(0.67, 0, 0, 0)
    button.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 14
    button.TextColor3 = Color3.fromRGB(255, 220, 220)
    button.Parent = frame

    local function updateButton()
        button.Text = settings[key] and "ON" or "OFF"
        button.BackgroundColor3 = settings[key] and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(60, 20, 20)
    end

    button.MouseButton1Click:Connect(function()
        settings[key] = not settings[key]
        updateButton()
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

    updateButton()
    return button
end

local function createTextBox(parent, labelText, key)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 60)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = createLabel(frame, labelText)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Size = UDim2.new(1, 0, 0, 0)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 30)
    box.Position = UDim2.new(0, 0, 0, 26)
    box.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.TextColor3 = Color3.fromRGB(255, 220, 220)
    box.Text = tostring(settings[key])
    box.PlaceholderText = "Enter a number"
    box.Parent = frame

    box.FocusLost:Connect(function()
        local value = tonumber(box.Text)
        if value then
            settings[key] = value
            applySpinState()
        else
            box.Text = tostring(settings[key])
        end
    end)

    return box
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DonateGameGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 380, 0, 380)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
mainFrame.BorderSizePixel = 0
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 12)
uiCorner.Parent = mainFrame

local titleLabel = createTextLabel(mainFrame, "Donate Game Personal GUI", UDim2.new(1, 0, 0, 40))
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 0.2
titleLabel.BackgroundColor3 = Color3.fromRGB(50, 15, 15)

local description = createTextLabel(mainFrame, "Use this panel to add Donate Game helpers, shortcuts, and custom behavior for the second game.", UDim2.new(1, -20, 0, 40))
description.Position = UDim2.new(0, 10, 0, 46)

description.TextSize = 14

description.TextColor3 = Color3.fromRGB(220, 220, 220)

local sectionLabel = createTextLabel(mainFrame, "Spin Config", UDim2.new(1, 0, 0, 24))
sectionLabel.Position = UDim2.new(0, 10, 0, 100)
sectionLabel.Font = Enum.Font.GothamBold
sectionLabel.TextSize = 16

local configContainer = Instance.new("Frame")
configContainer.Size = UDim2.new(1, -20, 0, 180)
configContainer.Position = UDim2.new(0, 10, 0, 130)
configContainer.BackgroundTransparency = 1
configContainer.Parent = mainFrame

local configLayout = Instance.new("UIListLayout")
configLayout.SortOrder = Enum.SortOrder.LayoutOrder
configLayout.Padding = UDim.new(0, 8)
configLayout.Parent = configContainer

createToggle(configContainer, "1R$= +1 Spin Speed", "spinSet")
createTextBox(configContainer, "Spin Speed Multiplier", "spinSpeedMultiplier")
createToggle(configContainer, "Helicopter Idle Mode", "helicopterEnabled")

local applyButton = createButton(configContainer, "Apply Spin Config", applySpinState)
applyButton.Size = UDim2.new(1, 0, 0, 34)

local closeButton = createButton(mainFrame, "Close GUI", function()
    screenGui:Destroy()
end)
closeButton.Position = UDim2.new(0, 10, 0, 332)

local hintLabel = createTextLabel(mainFrame, "Tip: Set spin/helicopter config and apply it to your character.", UDim2.new(1, -20, 0, 24))
hintLabel.Position = UDim2.new(0, 10, 0, 368)
hintLabel.TextColor3 = Color3.fromRGB(200, 150, 150)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
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

return screenGui
