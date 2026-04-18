--[[
    DONATE GAME - Custom GUI
    - No third-party UI libraries
    - PC + mobile drag support
    - Minimize/open support
    - Persistent settings with JSON file
]]

repeat
    wait()
until game:IsLoaded()

if game.PlaceId ~= 6652551895 then
    return
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local LogService = game:GetService("LogService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local TextChatService = game:GetService("TextChatService")
local notificationTimestamps = {}
local recentDonationLogs = {}
local getNearestPlayerInfo
local observedDonationChatChannels = {}

pcall(function()
    local voiceService = game:GetService("VoiceChatService")
    local okEnabled, enabled = pcall(function()
        return voiceService:IsVoiceEnabledForUserIdAsync(LocalPlayer.UserId)
    end)
    voiceEnabled = okEnabled and enabled == true
end)

local function notify(title, text, duration, dedupeKey, cooldown)
    local now = tick()
    if dedupeKey and cooldown then
        local last = notificationTimestamps[dedupeKey] or 0
        if now - last < cooldown then
            return
        end
        notificationTimestamps[dedupeKey] = now
    end

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "DONATE GAME"),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 4,
        })
    end)
end

local function trimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeMessageList(value, fallback)
    local normalized = {}
    if type(value) == "table" then
        for _, entry in ipairs(value) do
            local text = trimText(entry)
            if text ~= "" then
                table.insert(normalized, text)
            end
        end
    end

    if #normalized == 0 and type(fallback) == "table" then
        for _, entry in ipairs(fallback) do
            local text = trimText(entry)
            if text ~= "" then
                table.insert(normalized, text)
            end
        end
    end

    return normalized
end

local function normalizePlayerText(value)
    return trimText(value):gsub("^@", ""):lower()
end

local function textMatchesLocalPlayer(value)
    local normalized = normalizePlayerText(value)
    if normalized == "" then
        return false
    end

    local localName = tostring(LocalPlayer.Name or ""):lower()
    local localDisplay = tostring(LocalPlayer.DisplayName or ""):lower()

    return normalized == localName or normalized == localDisplay
end

local function resolvePlayerInfoFromText(value)
    local trimmed = trimText(value)
    if trimmed == "" then
        return nil
    end

    if textMatchesLocalPlayer(trimmed) then
        return {
            name = LocalPlayer.Name,
            displayName = LocalPlayer.DisplayName,
            userId = LocalPlayer.UserId,
        }
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local playerName = tostring(player.Name or ""):lower()
        local playerDisplay = tostring(player.DisplayName or ""):lower()
        local normalized = normalizePlayerText(trimmed)

        if normalized == playerName or normalized == playerDisplay then
            return {
                name = player.Name,
                displayName = player.DisplayName,
                userId = player.UserId,
            }
        end
    end

    return nil
end

local function consumeRecentDonationDonorInfo(amount)
    if not recentDonationLogs or #recentDonationLogs == 0 then
        return getNearestPlayerInfo()
    end

    local bestMatch
    local bestTime = 0

    for _, entry in ipairs(recentDonationLogs) do
        if entry.amount == amount and entry.timestamp > bestTime then
            bestMatch = entry
            bestTime = entry.timestamp
        end
    end

    if bestMatch then
        table.remove(recentDonationLogs, table.find(recentDonationLogs, bestMatch))
        return bestMatch.donorInfo
    end

    return getNearestPlayerInfo()
end

local function markDonationForHopTimer(amount)
    -- Placeholder for hop timer logic if needed
end

local function sendDonationWebhook(amount, donorInfo)
    -- Placeholder for webhook logic if needed
end

local function pickRandomMessage(list, fallback)
    if type(list) ~= "table" or #list == 0 then
        return tostring(fallback or "")
    end
    return tostring(list[math.random(1, #list)] or fallback or "")
end

local function sendChatMessage(message)
    if not message or message == "" then
        return
    end

    pcall(function()
        if TextChatService and TextChatService.ChatInputBarConfiguration then
            local chatInput = TextChatService:FindFirstChildOfClass("ChatInputBar")
            if chatInput then
                chatInput:CaptureFocus()
                chatInput.Text = message
                task.wait()
                chatInput:ReleaseFocus(true)
            end
        else
            ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest"):FireServer(message, "All")
        end
    end)
end

local function canUseFiles()
    local ok = pcall(function()
        return readfile and writefile and isfile
    end)
    return ok
end

local function loadSettings()
    if not canUseFiles() then
        return
    end

    local fileName = "dono_game_settings.json"
    if not isfile(fileName) then
        return
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(fileName))
    end)

    if ok and type(data) == "table" then
        for key, value in pairs(data) do
            if settings[key] ~= nil then
                settings[key] = value
            end
        end
    end
end

local function saveSettings()
    if not canUseFiles() then
        return
    end

    local ok, json = pcall(function()
        return HttpService:JSONEncode(settings)
    end)

    if ok then
        writefile("dono_game_settings.json", json)
    end
end

local settings = {
    spinSet = false,
    spinSpeedMultiplier = 1,
    helicopterEnabled = false,
    antiAfkEnabled = false,
}

loadSettings()

local currentIdleTask = nil
local currentHelicopterSpinTask = nil
local currentAstronautIdleTrack = nil

local function getCharacterHumanoidRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

local function getSpinAngularVelocity()
    return 0.25 * math.max(0, tonumber(settings.spinSpeedMultiplier) or 1)
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

local function startHelicopterIdleMode()
    if not settings.helicopterEnabled then
        return
    end

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not root then return end

    -- Send dance2 emote
    sendChatMessage("/e dance2")

    -- Freeze animations
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

    local idleSpeed = getHelicopterIdleAngularVelocity()
    if currentIdleTask then
        task.cancel(currentIdleTask)
    end

    heliBody.AngularVelocity = Vector3.new(0, idleSpeed, 0)
end

local function stopHelicopterIdle()
    if currentIdleTask then
        task.cancel(currentIdleTask)
        currentIdleTask = nil
    end
    stopAstronautIdle()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").RootPart
        if root then
            local heliBody = root:FindFirstChild("HL1__HELI")
            if heliBody then
                heliBody:Destroy()
            end
        end
    end
end

local function applySpinState()
    local _, _, root = getCharacterHumanoidRoot()
    if not root then
        return
    end

    local existing = root:FindFirstChild("Spin")
    if settings.spinSet then
        if not (existing and existing:IsA("BodyAngularVelocity")) then
            existing = Instance.new("BodyAngularVelocity")
            existing.Name = "Spin"
            existing.MaxTorque = Vector3.new(0, math.huge, 0)
            existing.Parent = root
        end
        existing.AngularVelocity = Vector3.new(0, getSpinAngularVelocity(), 0)
    else
        if existing and existing:IsA("BodyAngularVelocity") then
            existing:Destroy()
        end
    end
end

-- UI Framework from PLS Donate GUI
local THEME = {
    topBar = Color3.fromRGB(20, 20, 60),
    topBarText = Color3.fromRGB(238, 238, 238),
    panel = Color3.fromRGB(10, 10, 30),
    tabIdle = Color3.fromRGB(15, 15, 45),
    tabActive = Color3.fromRGB(30, 30, 80),
    section = Color3.fromRGB(12, 12, 35),
    control = Color3.fromRGB(20, 20, 50),
    controlText = Color3.fromRGB(228, 228, 228),
    subtleText = Color3.fromRGB(156, 156, 200),
    accent = Color3.fromRGB(100, 100, 200),
    stroke = Color3.fromRGB(40, 40, 80),
}

local gui = Instance.new("ScreenGui")
gui.Name = "DonateGameGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 620, 0, 430)
main.Position = UDim2.fromOffset(220, 120)
main.BackgroundColor3 = THEME.panel
main.BorderSizePixel = 0
main.Parent = gui
main.Visible = false

local stroke = Instance.new("UIStroke")
stroke.Color = THEME.stroke
stroke.Thickness = 1
stroke.Parent = main

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = main

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = THEME.topBar
topBar.BorderSizePixel = 0
topBar.Parent = main

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 8)
topBarCorner.Parent = topBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.7, 0, 1, 0)
title.BackgroundTransparency = 1
title.Text = "DONATE GAME GUI"
title.TextColor3 = THEME.topBarText
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 15, 0, 0)
title.Parent = topBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
minimizeBtn.Position = UDim2.new(1, -35, 0, 5)
minimizeBtn.BackgroundColor3 = THEME.topBar
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 14
minimizeBtn.TextColor3 = THEME.topBarText
minimizeBtn.Text = "-"
minimizeBtn.Parent = topBar

local minimized = false
local originalSize = main.Size

local function applyResponsiveSize(isMinimized)
    if isMinimized then
        main.Size = UDim2.new(0, 200, 0, 40)
        for _, child in ipairs(main:GetChildren()) do
            if child ~= topBar and child ~= stroke and child ~= uiCorner then
                child.Visible = false
            end
        end
    else
        main.Size = originalSize
        for _, child in ipairs(main:GetChildren()) do
            child.Visible = true
        end
    end
end

minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    minimizeBtn.Text = minimized and "+" or "-"
    applyResponsiveSize(minimized)
end)

local dragging = false
local dragStart = nil
local startPos = nil

local function getViewportSize()
    return Workspace.CurrentCamera.ViewportSize
end

local function updateDrag(input)
    if not dragging then
        return
    end

    local delta = input.Position - dragStart
    main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        updateDrag(input)
    end
end)

local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, 0, 0, 40)
tabContainer.Position = UDim2.new(0, 0, 0, 40)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 0)
tabLayout.Parent = tabContainer

local pageContainer = Instance.new("Frame")
pageContainer.Size = UDim2.new(1, 0, 1, -80)
pageContainer.Position = UDim2.new(0, 0, 0, 80)
pageContainer.BackgroundTransparency = 1
pageContainer.Parent = main

local pages = {}

local function createTab(name)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0.33, 0, 1, 0)
    tabBtn.BackgroundColor3 = THEME.tabIdle
    tabBtn.BorderSizePixel = 0
    tabBtn.Font = Enum.Font.GothamSemibold
    tabBtn.TextSize = 14
    tabBtn.TextColor3 = THEME.controlText
    tabBtn.Text = name
    tabBtn.Parent = tabContainer

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 4)
    tabCorner.Parent = tabBtn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 6
    page.ScrollBarImageColor3 = THEME.accent
    page.Visible = false
    page.Parent = pageContainer

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 10)
    pageLayout.Parent = page

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 10)
    pagePadding.PaddingLeft = UDim.new(0, 10)
    pagePadding.PaddingRight = UDim.new(0, 10)
    pagePadding.PaddingBottom = UDim.new(0, 10)
    pagePadding.Parent = page

    pages[name] = page

    tabBtn.MouseButton1Click:Connect(function()
        for tabName, p in pairs(pages) do
            p.Visible = (tabName == name)
            local btn = tabContainer:FindFirstChild(tabName)
            if btn then
                btn.BackgroundColor3 = (tabName == name) and THEME.tabActive or THEME.tabIdle
                btn.TextColor3 = (tabName == name) and Color3.fromRGB(255, 255, 255) or THEME.controlText
            end
        end
    end)

    return page
end

local function createSection(parent, title)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 0)
    section.BackgroundColor3 = THEME.section
    section.BorderSizePixel = 0
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.Parent = parent

    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 6)
    sectionCorner.Parent = section

    local sectionStroke = Instance.new("UIStroke")
    sectionStroke.Color = THEME.stroke
    sectionStroke.Thickness = 1
    sectionStroke.Parent = section

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 24)
    titleLabel.Position = UDim2.new(0, 10, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = THEME.subtleText
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = section

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 0, 0)
    content.Position = UDim2.new(0, 10, 0, 29)
    content.BackgroundTransparency = 1
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.Parent = section

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.Parent = content

    return content
end

local function createInfoLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = THEME.controlText
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Parent = parent
    return label
end

local function createToggle(parent, text, key)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 34)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = THEME.controlText
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.33, 0, 1, 0)
    button.Position = UDim2.new(0.67, 0, 0, 0)
    button.BackgroundColor3 = THEME.control
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 14
    button.TextColor3 = THEME.controlText
    button.Parent = frame

    local function updateButton()
        button.Text = settings[key] and "ON" or "OFF"
        button.BackgroundColor3 = settings[key] and THEME.accent or THEME.control
    end

    button.MouseButton1Click:Connect(function()
        settings[key] = not settings[key]
        updateButton()
        saveSettings()
        if key == "spinSet" then
            applySpinState()
        elseif key == "helicopterEnabled" then
            if settings[key] then
                startHelicopterIdleMode()
            else
                stopHelicopterIdle()
            end
        elseif key == "antiAfkEnabled" then
            -- Handle anti-AFK toggle if needed
        end
    end)

    updateButton()
    return button
end

local function createTextBox(parent, labelText, key, isNumber)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 60)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = createInfoLabel(frame, labelText)
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 30)
    box.Position = UDim2.new(0, 0, 0, 26)
    box.BackgroundColor3 = THEME.control
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.TextColor3 = THEME.controlText
    box.Text = tostring(settings[key])
    box.PlaceholderText = "Enter a number"
    box.Parent = frame

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box

    box.FocusLost:Connect(function()
        local value = isNumber and tonumber(box.Text) or box.Text
        if value then
            settings[key] = value
            saveSettings()
            if key == "spinSpeedMultiplier" then
                applySpinState()
            end
        else
            box.Text = tostring(settings[key])
        end
    end)

    return box
end

local function createButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = THEME.control
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 14
    button.TextColor3 = THEME.controlText
    button.Text = text
    button.Parent = parent

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = button

    button.MouseButton1Click:Connect(callback)
    return button
end

local function chooseServerId()
    local placeId = 6652551895
    local ok, serverList = pcall(function()
        return TeleportService:GetServerList(placeId)
    end)
    if not ok or not serverList then
        return nil
    end

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
    else
        return nil
    end
end

local mainTab = createTab("Main")
local otherTab = createTab("Other")
local serverTab = createTab("Server")

do
    local mainSection = createSection(mainTab, "Main Settings")
    createToggle(mainSection, "1R$ = +1 Spin Speed", "spinSet")
    createTextBox(mainSection, "Spin Speed Multiplier", "spinSpeedMultiplier", true)
    createToggle(mainSection, "Helicopter Idle Mode", "helicopterEnabled")
end

do
    local otherSection = createSection(otherTab, "Other Settings")
    createInfoLabel(otherSection, "Donate Game: teleport to the donate server for testing.")
    createButton(otherSection, "Go to Donate Game", function()
        local serverId = chooseServerId()
        if serverId then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(6652551895, serverId, LocalPlayer)
            end)
        else
            notify("Teleport", "No suitable servers found.", 5)
        end
    end)
    createInfoLabel(otherSection, "Create your own booth and sell your gamepasses to start making Robux in Donate Game 💸 or donate to others and spread your wealth! 🤑💰")
    createInfoLabel(otherSection, "💰Start with no robux and earn more!")
    createInfoLabel(otherSection, "🔥 Any gamepasses you have on sale will be automatically added to your booth!")
    createInfoLabel(otherSection, "💎Earn gems by playing and buy cosmetics!")
    createInfoLabel(otherSection, "✨Unlock new skins, props and emotes!")
    createInfoLabel(otherSection, "👍 Like and favourite the game for updates!")
    createInfoLabel(otherSection, "Development team: Royale Games.")
end

do
    local serverSection = createSection(serverTab, "Server Settings")
    createToggle(serverSection, "Anti AFK Server", "antiAfkEnabled")
    createButton(serverSection, "Server Hop Now", function()
        local serverId = chooseServerId()
        if serverId then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(6652551895, serverId, LocalPlayer)
            end)
        else
            notify("Server Hop", "No suitable servers found.", 5)
        end
    end)
end

activateTab("Main")

local function playOpenFade(root)
    local targets = {root}
    for _, obj in ipairs(root:GetDescendants()) do
        table.insert(targets, obj)
    end

    local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, obj in ipairs(targets) do
        local goal = {}
        local hasGoal = false

        if obj:IsA("Frame") or obj:IsA("ScrollingFrame") or obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local originalBg = obj.BackgroundTransparency
            obj.BackgroundTransparency = 1
            goal.BackgroundTransparency = originalBg
            hasGoal = true
        end

        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local originalText = obj.TextTransparency
            obj.TextTransparency = 1
            goal.TextTransparency = originalText
            hasGoal = true
        end

        if obj:IsA("UIStroke") then
            local originalStroke = obj.Transparency
            obj.Transparency = 1
            goal.Transparency = originalStroke
            hasGoal = true
        end

        if hasGoal then
            TweenService:Create(obj, tweenInfo, goal):Play()
        end
    end
end

main.Visible = true
playOpenFade(main)

-- Anti-AFK Logic
local playerPositions = {}
local lastCheck = tick()

spawn(function()
    while wait(10) do  -- Check every 10 seconds
        if not settings.antiAfkEnabled then
            continue
        end

        local currentTime = tick()
        local immobileCount = 0

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local currentPos = root.Position
                    local lastPos = playerPositions[player.UserId]

                    if lastPos then
                        local distance = (currentPos - lastPos).Magnitude
                        if distance < 1 then  -- Consider immobile if moved less than 1 stud
                            immobileCount = immobileCount + 1
                        end
                    end

                    playerPositions[player.UserId] = currentPos
                end
            end
        end

        if immobileCount > 16 then
            notify("Anti AFK", ("Detected %d immobile players. Server hopping..."):format(immobileCount), 5, "anti-afk-hop", 10)
            local serverId = chooseServerId()
            if serverId then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(6652551895, serverId, LocalPlayer)
                end)
            else
                notify("Anti AFK", "No suitable servers found for hopping.", 5)
            end
        end

        lastCheck = currentTime
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    wait(1)
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
