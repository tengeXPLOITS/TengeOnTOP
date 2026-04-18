-- Donate Game GUI similar to pls dono custom GUI

if not game then return end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
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

local settings = {
    spinSet = false,
    spinSpeed = 1,
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

    -- Play astronaut animation
    if hum then
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://10921034824" -- Astronaut animation
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
main.Size = UDim2.new(0, 400, 0, 300)
main.Position = UDim2.fromOffset(200, 150)
main.BackgroundColor3 = THEME.bg
main.BorderSizePixel = 2
main.BorderColor3 = THEME.border
main.Parent = gui

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = THEME.tabBg
titleBar.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "DONATE GAME"
title.TextColor3 = THEME.text
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 1, -4)
closeBtn.Position = UDim2.new(1, -45, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
closeBtn.Text = "X"
closeBtn.TextColor3 = THEME.text
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 18
closeBtn.Parent = titleBar

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 100, 0, 30)
openBtn.Position = UDim2.new(0, 20, 0, 20)
openBtn.BackgroundColor3 = THEME.tabBg
openBtn.Text = "Open Donate"
openBtn.TextColor3 = THEME.text
openBtn.Font = Enum.Font.SourceSansBold
openBtn.TextSize = 16
openBtn.Visible = false
openBtn.Parent = gui

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    openBtn.Visible = true
end)

openBtn.MouseButton1Click:Connect(function()
    main.Visible = true
    openBtn.Visible = false
end)

local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, 0, 0, 40)
tabContainer.Position = UDim2.new(0, 0, 0, 40)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabContainer

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -80)
content.Position = UDim2.new(0, 0, 0, 80)
content.BackgroundTransparency = 1
content.Parent = main

local pages = {}

local function createTab(name)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0.5, 0, 1, 0)
    tabBtn.BackgroundColor3 = THEME.tabBg
    tabBtn.Text = name
    tabBtn.TextColor3 = THEME.text
    tabBtn.Font = Enum.Font.SourceSansBold
    tabBtn.TextSize = 16
    tabBtn.Parent = tabContainer

    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = content

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 10)
    pageLayout.Parent = page

    pages[name] = page

    tabBtn.MouseButton1Click:Connect(function()
        for n, p in pairs(pages) do
            p.Visible = (n == name)
            local btn = tabContainer:FindFirstChild(n)
            if btn then
                btn.BackgroundColor3 = (n == name) and THEME.tabActive or THEME.tabBg
            end
        end
    end)

    return page
end

local mainTab = createTab("Main")
local serverTab = createTab("Server")

-- Main Tab
local spinToggle = Instance.new("TextButton")
spinToggle.Size = UDim2.new(1, -20, 0, 40)
spinToggle.Position = UDim2.new(0, 10, 0, 10)
spinToggle.BackgroundColor3 = settings.spinSet and THEME.buttonOn or THEME.button
spinToggle.Text = "Spin: " .. (settings.spinSet and "ON" or "OFF")
spinToggle.TextColor3 = THEME.text
spinToggle.Font = Enum.Font.SourceSansBold
spinToggle.TextSize = 16
spinToggle.Parent = mainTab

spinToggle.MouseButton1Click:Connect(function()
    settings.spinSet = not settings.spinSet
    spinToggle.Text = "Spin: " .. (settings.spinSet and "ON" or "OFF")
    spinToggle.BackgroundColor3 = settings.spinSet and THEME.buttonOn or THEME.button
    saveSettings()
    applySpinState()
end)

local spinSlider = Instance.new("TextBox")
spinSlider.Size = UDim2.new(1, -20, 0, 30)
spinSlider.Position = UDim2.new(0, 10, 0, 60)
spinSlider.BackgroundColor3 = THEME.button
spinSlider.Text = "Speed: " .. settings.spinSpeed
spinSlider.TextColor3 = THEME.text
spinSlider.Font = Enum.Font.SourceSans
spinSlider.TextSize = 14
spinSlider.Parent = mainTab

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

local heliToggle = Instance.new("TextButton")
heliToggle.Size = UDim2.new(1, -20, 0, 40)
heliToggle.Position = UDim2.new(0, 10, 0, 100)
heliToggle.BackgroundColor3 = settings.helicopterEnabled and THEME.buttonOn or THEME.button
heliToggle.Text = "Helicopter: " .. (settings.helicopterEnabled and "ON" or "OFF")
heliToggle.TextColor3 = THEME.text
heliToggle.Font = Enum.Font.SourceSansBold
heliToggle.TextSize = 16
heliToggle.Parent = mainTab

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

-- Server Tab
local afkToggle = Instance.new("TextButton")
afkToggle.Size = UDim2.new(1, -20, 0, 40)
afkToggle.Position = UDim2.new(0, 10, 0, 10)
afkToggle.BackgroundColor3 = settings.antiAfkEnabled and THEME.buttonOn or THEME.button
afkToggle.Text = "Anti AFK: " .. (settings.antiAfkEnabled and "ON" or "OFF")
afkToggle.TextColor3 = THEME.text
afkToggle.Font = Enum.Font.SourceSansBold
afkToggle.TextSize = 16
afkToggle.Parent = serverTab

afkToggle.MouseButton1Click:Connect(function()
    settings.antiAfkEnabled = not settings.antiAfkEnabled
    afkToggle.Text = "Anti AFK: " .. (settings.antiAfkEnabled and "ON" or "OFF")
    afkToggle.BackgroundColor3 = settings.antiAfkEnabled and THEME.buttonOn or THEME.button
    saveSettings()
end)

local hopButton = Instance.new("TextButton")
hopButton.Size = UDim2.new(1, -20, 0, 40)
hopButton.Position = UDim2.new(0, 10, 0, 60)
hopButton.BackgroundColor3 = THEME.button
hopButton.Text = "Server Hop"
hopButton.TextColor3 = THEME.text
hopButton.Font = Enum.Font.SourceSansBold
hopButton.TextSize = 16
hopButton.Parent = serverTab

hopButton.MouseButton1Click:Connect(function()
    local serverId = chooseServerId()
    if serverId then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(6652551895, serverId, LocalPlayer)
        end)
        notify("Server Hop", "Hopping...", 3)
    else
        notify("Server Hop", "No servers found", 3)
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
pages["Main"].Visible = true
tabContainer:FindFirstChild("Main").BackgroundColor3 = THEME.tabActive

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
