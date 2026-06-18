hi lol

local gui = Instance.new("ScreenGui")
gui.Name = "PlsDonoCustomGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50
gui.Parent = GuiParent

local THEME = {
    topBar = Color3.fromRGB(28, 164, 52),
    topBarText = Color3.fromRGB(248, 255, 248),
    panel = Color3.fromRGB(23, 23, 25),
    tabIdle = Color3.fromRGB(72, 72, 76),
    tabActive = Color3.fromRGB(96, 96, 102),
    section = Color3.fromRGB(18, 18, 20),
    control = Color3.fromRGB(31, 31, 34),
    controlText = Color3.fromRGB(238, 238, 238),
    subtleText = Color3.fromRGB(181, 191, 181),
    accent = Color3.fromRGB(57, 196, 76),
    stroke = Color3.fromRGB(66, 66, 71),
}

local SHELL_CORNER_RADIUS = 8
local CONTROL_CORNER_RADIUS = 6
local GLOW_COLOR = Color3.fromRGB(168, 255, 183)
local SUBTLE_GLOW_COLOR = Color3.fromRGB(96, 180, 108)
local GLOW_TRANSPARENCY = 0.84
local SUBTLE_GLOW_TRANSPARENCY = 0.9

local function createCorner(target, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or CONTROL_CORNER_RADIUS)
    corner.Parent = target
    return corner
end

local function applyTextGlow(target, color, transparency)
    target.TextStrokeColor3 = color or GLOW_COLOR
    target.TextStrokeTransparency = transparency or GLOW_TRANSPARENCY
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 380, 0, 360)
main.Position = UDim2.fromOffset(0, 0)
main.BackgroundColor3 = THEME.panel
main.BorderSizePixel = 0
main.Parent = gui
main.Visible = false

local TOP_BAR_HEIGHT = 34
local expandedWidth = 380
local expandedHeight = 360

local function getViewportSize()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function getBottomRightPosition(sizeY)
    local viewport = getViewportSize()
    local width = expandedWidth
    local height = tonumber(sizeY) or expandedHeight
    local x = math.max(12, viewport.X - width - 18)
    local y = math.max(12, viewport.Y - height - 18)
    return UDim2.fromOffset(x, y)
end

local function applyResponsiveSize(centerOnApply)
    local viewport = getViewportSize()
    expandedWidth = math.clamp(math.floor(viewport.X - 72), 340, 400)
    expandedHeight = math.clamp(math.floor(viewport.Y - 40), 360, 412)

    if not UserInputService.TouchEnabled then
        expandedWidth = math.max(expandedWidth, 380)
        expandedHeight = math.max(expandedHeight, 360)
    end

    main.Size = UDim2.new(0, expandedWidth, 0, expandedHeight)

    if centerOnApply then
        local centeredX = math.floor((viewport.X - expandedWidth) * 0.5)
        local centeredY = math.floor((viewport.Y - expandedHeight) * 0.5)
        main.Position = UDim2.fromOffset(math.max(0, centeredX), math.max(0, centeredY))
    else
        main.Position = getBottomRightPosition(expandedHeight)
    end
end

applyResponsiveSize(false)

do
    createCorner(main, SHELL_CORNER_RADIUS)

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.stroke
    stroke.Thickness = 1
    stroke.Parent = main

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 34, 36)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(24, 24, 26)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 20)),
    })
    gradient.Parent = main
end

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, TOP_BAR_HEIGHT)
topBar.BackgroundColor3 = THEME.topBar
topBar.BorderSizePixel = 0
topBar.Parent = main

do
    createCorner(topBar, SHELL_CORNER_RADIUS)

    local topGradient = Instance.new("UIGradient")
    topGradient.Rotation = 0
    topGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 196, 71)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(31, 171, 56)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 139, 44)),
    })
    topGradient.Parent = topBar
end

do
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -48, 0, 15)
    title.Position = UDim2.new(0, 32, 0, 2)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = THEME.topBarText
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 13
    title.Text = "PLS DONATE ANIMOSITY"
    title.Parent = topBar
    applyTextGlow(title, GLOW_COLOR, 0.78)

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(1, -48, 0, 11)
    subtitle.Position = UDim2.new(0, 32, 0, 18)
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = THEME.subtleText
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.Text = "developed by mattyB"
    subtitle.Parent = topBar
    applyTextGlow(subtitle, SUBTLE_GLOW_COLOR, SUBTLE_GLOW_TRANSPARENCY)
end

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "Minimize"
minimizeBtn.Size = UDim2.new(0, 18, 0, 18)
minimizeBtn.Position = UDim2.new(0, 8, 0.5, -9)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(24, 132, 41)
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 13
minimizeBtn.Text = "-"
minimizeBtn.AutoButtonColor = true
minimizeBtn.Parent = topBar
applyTextGlow(minimizeBtn, GLOW_COLOR, 0.78)

do
    createCorner(minimizeBtn, CONTROL_CORNER_RADIUS)

    local miniStroke = Instance.new("UIStroke")
    miniStroke.Thickness = 1
    miniStroke.Color = Color3.fromRGB(210, 255, 218)
    miniStroke.Parent = minimizeBtn
end

local body = Instance.new("Frame")
body.Name = "Body"
body.Size = UDim2.new(1, 0, 1, -TOP_BAR_HEIGHT)
body.Position = UDim2.new(0, 0, 0, TOP_BAR_HEIGHT)
body.BackgroundTransparency = 1
body.Parent = main

local tabHolder = Instance.new("ScrollingFrame")
tabHolder.Name = "Tabs"
tabHolder.Size = UDim2.new(1, -12, 0, 28)
tabHolder.Position = UDim2.new(0, 6, 0, 5)
tabHolder.BackgroundColor3 = THEME.section
tabHolder.BorderSizePixel = 0
tabHolder.ScrollBarThickness = 2
tabHolder.ScrollBarImageColor3 = THEME.accent
tabHolder.AutomaticCanvasSize = Enum.AutomaticSize.X
tabHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
tabHolder.ScrollingDirection = Enum.ScrollingDirection.X
tabHolder.Parent = body

do
    createCorner(tabHolder, CONTROL_CORNER_RADIUS)

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Thickness = 1
    tabStroke.Color = THEME.stroke
    tabStroke.Parent = tabHolder
end

do
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.Parent = tabHolder

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, 4)
    tabPad.PaddingBottom = UDim.new(0, 4)
    tabPad.PaddingLeft = UDim.new(0, 6)
    tabPad.PaddingRight = UDim.new(0, 6)
    tabPad.Parent = tabHolder

    local tabUnderline = Instance.new("Frame")
    tabUnderline.Name = "TabUnderline"
    tabUnderline.Size = UDim2.new(1, -12, 0, 1)
    tabUnderline.Position = UDim2.new(0, 6, 0, 35)
    tabUnderline.BackgroundColor3 = THEME.stroke
    tabUnderline.BorderSizePixel = 0
    tabUnderline.Parent = body
end

local pages = Instance.new("Frame")
pages.Name = "Pages"
pages.Size = UDim2.new(1, -12, 1, -43)
pages.Position = UDim2.new(0, 6, 0, 40)
pages.BackgroundTransparency = 1
pages.Parent = body

local function makeDraggable(frame, handle)
    local DRAG_SMOOTH_TIME = 0.06
    local dragging = false
    local dragStart
    local startPos
    local dragTween

    local function update(input)
        local delta = input.Position - dragStart
        local nextPosition = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )

        if dragTween then
            dragTween:Cancel()
        end

        dragTween = TweenService:Create(
            frame,
            TweenInfo.new(DRAG_SMOOTH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = nextPosition}
        )
        dragTween:Play()
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if dragTween then
                        dragTween:Cancel()
                        dragTween = nil
                    end
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            update(input)
        end
    end)
end

makeDraggable(main, topBar)

local minimized = false
local minimizeTween
local function setMinimized(state)
    local MINIMIZE_TWEEN_TIME = 0.2
    if state == minimized and not minimizeTween then
        return
    end

    if minimizeTween then
        minimizeTween:Cancel()
        minimizeTween = nil
    end

    if not state then
        body.Visible = true
    end

    local targetSize = state and UDim2.new(0, expandedWidth, 0, TOP_BAR_HEIGHT) or UDim2.new(0, expandedWidth, 0, expandedHeight)
    minimizeBtn.Text = state and "+" or "-"
    minimizeBtn.BackgroundColor3 = state and Color3.fromRGB(21, 120, 38) or Color3.fromRGB(24, 132, 41)

    minimizeTween = TweenService:Create(
        main,
        TweenInfo.new(MINIMIZE_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = targetSize}
    )
    local tweenRef = minimizeTween

    minimized = state
    minimizeTween:Play()
    minimizeTween.Completed:Connect(function()
        if minimizeTween ~= tweenRef then
            return
        end
        minimizeTween = nil
        body.Visible = not minimized
    end)
end

minimizeBtn.Activated:Connect(function()
    setMinimized(not minimized)
end)

local tabButtons = {}
local tabPages = {}
local activeTab
local settingHandlers

local function setTabVisualState(btn, active)
    if not btn then
        return
    end
    btn.BackgroundColor3 = active and THEME.tabActive or THEME.tabIdle
    btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 205, 210)
    local activeBar = btn:FindFirstChild("ActiveBar")
    if activeBar then
        activeBar.Visible = active
    end
end

local function activateTab(name)
    for tabName, page in pairs(tabPages) do
        local btn = tabButtons[tabName]
        local isActive = tabName == name
        page.Visible = isActive
        setTabVisualState(btn, isActive)
    end
    activeTab = name
end

local function createTab(name, buttonText)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.Size = UDim2.new(0, 120, 0, 28)
    btn.BackgroundColor3 = THEME.tabIdle
    btn.TextColor3 = Color3.fromRGB(205, 205, 210)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.Text = tostring(buttonText or name)
    btn.AutoButtonColor = false
    btn.Parent = tabHolder
    applyTextGlow(btn, GLOW_COLOR, 0.86)

    createCorner(btn, 8)

    local btnPadding = Instance.new("UIPadding")
    btnPadding.PaddingLeft = UDim.new(0, 12)
    btnPadding.PaddingRight = UDim.new(0, 12)
    btnPadding.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = THEME.stroke
    btnStroke.Parent = btn

    local activeBar = Instance.new("Frame")
    activeBar.Name = "ActiveBar"
    activeBar.Size = UDim2.new(1, 0, 0, 3)
    activeBar.Position = UDim2.new(0, 0, 1, -3)
    activeBar.BackgroundColor3 = THEME.accent
    activeBar.BorderSizePixel = 0
    activeBar.Visible = false
    activeBar.Parent = btn

    btn.MouseEnter:Connect(function()
        if activeTab ~= name then
            btn.BackgroundColor3 = Color3.fromRGB(84, 84, 90)
        end
    end)

    btn.MouseLeave:Connect(function()
        if activeTab ~= name then
            btn.BackgroundColor3 = THEME.tabIdle
        end
    end)

    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Visible = false
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundColor3 = THEME.panel
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 5
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Parent = pages

    createCorner(page, CONTROL_CORNER_RADIUS)

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Size = UDim2.new(1, -12, 0, 0)
    content.Position = UDim2.new(0, 6, 0, 6)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.Parent = page

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.Parent = content

    tabButtons[name] = btn
    tabPages[name] = page

    btn.MouseButton1Click:Connect(function()
        activateTab(name)
    end)

    return content
end

local function createSection(parent, titleText)
    local section = Instance.new("Frame")
    section.BackgroundColor3 = THEME.section
    section.BorderSizePixel = 0
    section.Size = UDim2.new(1, 0, 0, 0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.Parent = parent

    createCorner(section, CONTROL_CORNER_RADIUS)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -12, 0, 24)
    titleLabel.Position = UDim2.new(0, 8, 0, 6)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = THEME.subtleText
    titleLabel.Text = titleText
    titleLabel.Parent = section
    applyTextGlow(titleLabel, SUBTLE_GLOW_COLOR, SUBTLE_GLOW_TRANSPARENCY)

    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Position = UDim2.new(0, 8, 0, 34)
    holder.Size = UDim2.new(1, -16, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.Parent = section

    local holderLayout = Instance.new("UIListLayout")
    holderLayout.Padding = UDim.new(0, 6)
    holderLayout.Parent = holder

    return holder
end

local function createLockedTabNotice(parent)
    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = THEME.section
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 54)
    holder.Parent = parent

    createCorner(holder, CONTROL_CORNER_RADIUS)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -20, 1, -20)
    label.Position = UDim2.new(0, 10, 0, 10)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 12
    label.TextWrapped = true
    label.TextColor3 = THEME.subtleText
    label.Text = "verified players can use this."
    label.Parent = holder
    applyTextGlow(label, SUBTLE_GLOW_COLOR, SUBTLE_GLOW_TRANSPARENCY)
end

local function createLockedToggleRow(parent, text)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 42)
    row.Parent = parent

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 24)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = THEME.controlText
    label.Text = LOCK_ICON .. " " .. tostring(text or "")
    label.Parent = row
    applyTextGlow(label, GLOW_COLOR, 0.88)

    local info = Instance.new("TextLabel")
    info.BackgroundTransparency = 1
    info.Size = UDim2.new(1, 0, 0, 16)
    info.Position = UDim2.new(0, 0, 0, 24)
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextColor3 = THEME.subtleText
    info.TextWrapped = true
    info.Text = "verified players can use this."
    info.Parent = row
    applyTextGlow(info, SUBTLE_GLOW_COLOR, SUBTLE_GLOW_TRANSPARENCY)
end

local function createToggle(parent, text, key)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 24)
    row.Parent = parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 18, 0, 18)
    btn.Position = UDim2.new(0, 2, 0.5, -9)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = row

    createCorner(btn, CONTROL_CORNER_RADIUS)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = THEME.stroke
    btnStroke.Parent = btn

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -26, 1, 0)
    label.Position = UDim2.new(0, 26, 0, 0)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = THEME.controlText
    label.Text = text
    label.Parent = row
    applyTextGlow(label, GLOW_COLOR, 0.88)

    local function applyState()
        local enabled = settings[key] == true
        btn.Text = enabled and "x" or ""
        btn.BackgroundColor3 = enabled and THEME.accent or THEME.control
        btn.TextColor3 = enabled and Color3.fromRGB(19, 11, 21) or THEME.controlText
    end

    applyState()

    btn.MouseButton1Click:Connect(function()
        settings[key] = not settings[key]
        applyState()
        saveSettings()
        if settingHandlers[key] then
            pcall(settingHandlers[key], settings[key])
        end
    end)
end

local function escapePattern(str)
    return (str:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local currentHelicopterSpinTask = nil
local currentAstronautIdleTrack = nil
local pendingHelicopterRaisedAmount = 0

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
    end
end

local function stopHelicopterSpin()
    pendingHelicopterRaisedAmount = 0
    if currentHelicopterSpinTask then
        pcall(function()
            task.cancel(currentHelicopterSpinTask)
        end)
        currentHelicopterSpinTask = nil
    end
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

local function triggerLandingExplosion(humanoid)
    if not humanoid or not humanoid.Parent then
        return
    end

    pcall(function()
        humanoid.Health = 0
    end)
end

local currentIdleTask = nil
local HELICOPTER_IDLE_SPIN_SPEED = 2.7
local HELICOPTER_IDLE_PULSE_ACTIVE_DURATION = 0.06
local HELICOPTER_IDLE_PULSE_PAUSE_DURATION = 0.035
local HELICOPTER_IDLE_PULSE_SPEED_MULTIPLIER = 1.6
local HELICOPTER_TAKEOFF_SPIN_SPEED = 14
local SPIN_DONATION_BASE_SPEED = 0.25
local HELICOPTER_PLAZA_ROUTE = {
    Vector3.new(166.584, 0, 371.398),
    Vector3.new(228.765, 0, 332.55),
    Vector3.new(225.878, 0, 274.96),
    Vector3.new(169.654, 0, 232.826),
    Vector3.new(102.625, 0, 274.941),
    Vector3.new(109.353, 0, 351.28),
    Vector3.new(166.584, 0, 371.399),
}

local function getHelicopterFlightDuration(amount)
    local donation = math.max(1, tonumber(amount) or 1)
    if donation >= 100 then
        local clamped = math.min(10000, donation)
        local normalized = math.clamp((math.log10(clamped) - 2) / 2, 0, 1)
        return 52 + (28 * normalized)
    end

    local normalized = math.clamp((donation - 1) / 99, 0, 1)
    return 16 + (36 * (normalized ^ 0.72))
end

local function getHelicopterRiseHeight(amount, minRiseHeight)
    local donation = math.max(1, tonumber(amount) or 1)
    local minimum = math.max(0, tonumber(minRiseHeight) or 0)
    local targetHeight = 22 + (math.sqrt(donation) * 8)
    return math.clamp(math.max(minimum, targetHeight), 28, 105)
end

local function getHelicopterSpinSpeedForAmount(amount)
    local donation = math.max(1, tonumber(amount) or 1)
    return math.min(55, 25 + (math.sqrt(donation) * 1.6))
end

local function getHelicopterIdleAngularVelocity()
    return HELICOPTER_IDLE_SPIN_SPEED
end

local function stopHelicopterIdleTask()
    if currentIdleTask then
        pcall(function() task.cancel(currentIdleTask) end)
        currentIdleTask = nil
    end
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

    -- Ramp BodyAngularVelocity from 0 up to idleSpeed, then switch to a rapid
    -- pulse pattern so the idle looks like a quick spin-pause-spin cycle.
    heliBody.AngularVelocity = Vector3.new(0, 0, 0)
    currentIdleTask = task.spawn(function()
        local rampDuration = 0.7
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

        local pulseSpeed = idleSpeed * HELICOPTER_IDLE_PULSE_SPEED_MULTIPLIER
        while settings.helicopterEnabled and root.Parent do
            if heliBody and heliBody.Parent then
                heliBody.AngularVelocity = Vector3.new(0, pulseSpeed, 0)
            end
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
            task.wait(HELICOPTER_IDLE_PULSE_ACTIVE_DURATION)

            if not settings.helicopterEnabled or not root.Parent then
                break
            end

            if heliBody and heliBody.Parent then
                heliBody.AngularVelocity = Vector3.new(0, 0, 0)
            end
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
            task.wait(HELICOPTER_IDLE_PULSE_PAUSE_DURATION)
        end
    end)

    pcall(function()
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end)
end

local function performHelicopterBurst(raisedAmount, spinSpeed, spinDuration, burstConfig)
    pendingHelicopterRaisedAmount += math.max(1, tonumber(raisedAmount) or 1)
    if currentHelicopterSpinTask then
        return
    end

    currentHelicopterSpinTask = task.spawn(function()
        local burstIndex = 0
        local config = type(burstConfig) == "table" and burstConfig or {}

        local function restoreIdleMode()
            if settings.helicopterEnabled and not currentHelicopterSpinTask then
                task.spawn(function()
                    task.wait(0.08)
                    local started = false
                    for _ = 1, 15 do
                        if not settings.helicopterEnabled or currentHelicopterSpinTask then
                            return
                        end

                        local currentChar = LocalPlayer.Character
                        local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
                        local currentRoot = currentHum and currentHum.RootPart
                        if currentRoot and currentRoot.Parent then
                            startHelicopterIdleMode()
                            started = true
                            break
                        end
                        task.wait(0.2)
                    end

                    if not started and settings.helicopterEnabled and not currentHelicopterSpinTask then
                        startHelicopterIdleMode()
                    end
                end)
            end
        end

        while pendingHelicopterRaisedAmount > 0 do
            burstIndex += 1
            local amount = math.max(1, tonumber(pendingHelicopterRaisedAmount) or 1)
            pendingHelicopterRaisedAmount = 0

            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = hum and hum.RootPart
            if not char or not hum or not root then
                break
            end

            local ok, err = pcall(function()
                loadAstronautIdle()

                local animateScript = char:FindFirstChild("Animate")
                local animatePrevEnabled = nil
                if animateScript and animateScript:IsA("LocalScript") then
                    animatePrevEnabled = animateScript.Enabled
                    animateScript.Enabled = false
                end

                local baseIdleSpeed = getHelicopterIdleAngularVelocity()
                local targetSpinSpeed = math.max(getHelicopterSpinSpeedForAmount(amount), tonumber(spinSpeed) or 25)
                local minRiseHeight = math.max(0, tonumber(config.minRiseHeight) or 0)
                local riseHeight = getHelicopterRiseHeight(amount, minRiseHeight)
                local registerDelay = math.max(0.35, tonumber(config.registerDelay) or 1.8)
                local prepDuration = math.max(0.3, tonumber(config.prepDuration) or 0.75)
                local groundedSpinDuration = math.max(1.2, tonumber(config.groundedSpinDuration) or math.max(2.5, tonumber(spinDuration) or 2.5))
                local ascentDuration = math.max(3, tonumber(config.ascentDuration) or 6.5)
                local landingDuration = math.max(3.5, tonumber(config.landingDuration) or 5.5)
                local flightDuration = getHelicopterFlightDuration(amount)

                stopHelicopterIdleTask()

                local heliBody = root:FindFirstChild("HL1__HELI")
                if not (heliBody and heliBody:IsA("BodyAngularVelocity")) then
                    heliBody = Instance.new("BodyAngularVelocity")
                    heliBody.Name = "HL1__HELI"
                    heliBody.MaxTorque = Vector3.new(0, math.huge, 0)
                    heliBody.AngularVelocity = Vector3.new(0, baseIdleSpeed, 0)
                    heliBody.Parent = root
                end

                local holdCF = root.CFrame
                local holdStart = tick()
                while tick() - holdStart < registerDelay and char.Parent and root.Parent do
                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                    root.CFrame = holdCF
                    task.wait()
                end

                local prepTargetCF = claimedBoothSlot and getBoothTargetCFrameForStand(claimedBoothSlot, "Front") or holdCF
                if prepTargetCF then
                    local flatLook = Vector3.new(prepTargetCF.LookVector.X, 0, prepTargetCF.LookVector.Z)
                    if flatLook.Magnitude < 0.001 then
                        flatLook = Vector3.new(0, 0, -1)
                    end
                    flatLook = flatLook.Unit
                    local groundedPrepPos = Vector3.new(prepTargetCF.Position.X, holdCF.Position.Y, prepTargetCF.Position.Z)
                    prepTargetCF = CFrame.new(groundedPrepPos, groundedPrepPos + flatLook)
                end
                if burstIndex == 1 then
                    sendChatMessage("Preparing for takeoff...")
                else
                    sendChatMessage("Adjusting for departure...")
                end

                local prepStart = tick()
                while tick() - prepStart < prepDuration and char.Parent and root.Parent do
                    local t = math.clamp((tick() - prepStart) / prepDuration, 0, 1)
                    local easedT = 1 - ((1 - t) * (1 - t))
                    root.CFrame = holdCF:Lerp(prepTargetCF, easedT)
                    if heliBody and heliBody.Parent then
                        local prepSpin = baseIdleSpeed + (1.25 * easedT)
                        heliBody.AngularVelocity = Vector3.new(0, prepSpin, 0)
                    end
                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                    task.wait()
                end
                root.CFrame = prepTargetCF

                local startPos = prepTargetCF.Position
                local startRot = prepTargetCF - prepTargetCF.Position
                local yaw = 0
                local lastSpinTick = tick()

                sendChatMessage("Spooling up...")
                local spoolStart = tick()
                local spoolFromSpeed = math.max(0.35, baseIdleSpeed * 0.7)
                while tick() - spoolStart < groundedSpinDuration and char.Parent and root.Parent do
                    local now = tick()
                    local dt = now - lastSpinTick
                    lastSpinTick = now
                    local t = math.clamp((now - spoolStart) / groundedSpinDuration, 0, 1)
                    local spoolCurve = t * t * t
                    local currentSpinSpeed = spoolFromSpeed + ((targetSpinSpeed - spoolFromSpeed) * spoolCurve)
                    yaw += currentSpinSpeed * dt
                    if heliBody and heliBody.Parent then
                        heliBody.AngularVelocity = Vector3.new(0, currentSpinSpeed, 0)
                    end
                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                    root.CFrame = CFrame.new(startPos) * startRot * CFrame.Angles(0, yaw, 0)
                    task.wait()
                end

                local existingHeli = root:FindFirstChild("HL1__HELI")
                if existingHeli and existingHeli:IsA("BodyAngularVelocity") then
                    existingHeli:Destroy()
                end

                local nearestRouteIndex = 1
                local nearestRouteDistance = math.huge
                for index, routePoint in ipairs(HELICOPTER_PLAZA_ROUTE) do
                    local delta = Vector3.new(routePoint.X - startPos.X, 0, routePoint.Z - startPos.Z)
                    local distance = delta.Magnitude
                    if distance < nearestRouteDistance then
                        nearestRouteDistance = distance
                        nearestRouteIndex = index
                    end
                end

                local routeStartBase = HELICOPTER_PLAZA_ROUTE[nearestRouteIndex]
                local routeStartPos = Vector3.new(routeStartBase.X, routeStartBase.Y + riseHeight, routeStartBase.Z)
                local ascentStart = tick()
                local lastFrameTick = ascentStart
                local finalTargetPos = startPos

                while tick() - ascentStart < ascentDuration and char.Parent and root.Parent do
                    local now = tick()
                    local dt = now - lastFrameTick
                    lastFrameTick = now
                    local p = math.clamp((now - ascentStart) / ascentDuration, 0, 1)
                    local easedUp = p * p
                    local sideDrift = math.sin(p * math.pi) * math.min(8, 2 + (amount * 0.08))
                    local travelPos = startPos:Lerp(routeStartPos, easedUp)
                    finalTargetPos = travelPos + Vector3.new(sideDrift, 0, 0)
                    local facingDir = Vector3.new(routeStartPos.X - startPos.X, 0, routeStartPos.Z - startPos.Z)
                    if facingDir.Magnitude < 0.001 then
                        facingDir = Vector3.new(0, 0, -1)
                    else
                        facingDir = facingDir.Unit
                    end
                    local spinSpeedAtFrame = baseIdleSpeed + ((targetSpinSpeed - baseIdleSpeed) * easedUp)
                    yaw += spinSpeedAtFrame * dt
                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                    root.CFrame = CFrame.lookAt(finalTargetPos, finalTargetPos + facingDir) * CFrame.Angles(0, yaw, 0)
                    task.wait()
                end

                local routeIndex = nearestRouteIndex
                local routePosition = finalTargetPos
                local routeFlightStart = tick()
                lastFrameTick = routeFlightStart
                sendChatMessage("Cruising the plaza...")
                while tick() - routeFlightStart < flightDuration and char.Parent and root.Parent do
                    if pendingHelicopterRaisedAmount > 0 then
                        local bonusAmount = math.max(1, tonumber(pendingHelicopterRaisedAmount) or 1)
                        pendingHelicopterRaisedAmount = 0
                        flightDuration = math.min(130, flightDuration + math.max(8, getHelicopterFlightDuration(bonusAmount) * 0.25))
                        targetSpinSpeed = math.max(targetSpinSpeed, getHelicopterSpinSpeedForAmount(bonusAmount))
                        riseHeight = math.max(riseHeight, getHelicopterRiseHeight(bonusAmount, minRiseHeight))
                    end

                    local nextIndex = (routeIndex % #HELICOPTER_PLAZA_ROUTE) + 1
                    local nextBase = HELICOPTER_PLAZA_ROUTE[nextIndex]
                    local nextPos = Vector3.new(nextBase.X, nextBase.Y + riseHeight, nextBase.Z)
                    local segmentDistance = (nextPos - routePosition).Magnitude
                    local segmentDuration = math.clamp(segmentDistance / 18, 3, 6)
                    local segmentStart = tick()
                    local segmentOrigin = routePosition

                    while tick() - segmentStart < segmentDuration and char.Parent and root.Parent and (tick() - routeFlightStart) < flightDuration do
                        if pendingHelicopterRaisedAmount > 0 then
                            break
                        end

                        local now = tick()
                        local dt = now - lastFrameTick
                        lastFrameTick = now
                        local p = math.clamp((now - segmentStart) / segmentDuration, 0, 1)
                        local smoothP = p * p * (3 - (2 * p))
                        local segmentPos = segmentOrigin:Lerp(nextPos, smoothP)
                        local bob = math.sin((tick() - routeFlightStart) * 1.4) * 1.2
                        finalTargetPos = Vector3.new(segmentPos.X, segmentPos.Y + bob, segmentPos.Z)
                        local travelDir = Vector3.new(nextPos.X - segmentOrigin.X, 0, nextPos.Z - segmentOrigin.Z)
                        if travelDir.Magnitude < 0.001 then
                            travelDir = Vector3.new(0, 0, -1)
                        else
                            travelDir = travelDir.Unit
                        end
                        yaw += targetSpinSpeed * dt
                        pcall(function()
                            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end)
                        root.CFrame = CFrame.lookAt(finalTargetPos, finalTargetPos + travelDir) * CFrame.Angles(0, yaw, 0)
                        task.wait()
                    end

                    routePosition = nextPos
                    routeIndex = nextIndex
                end

                local landingTargetCF = claimedBoothSlot and getBoothTargetCFrameForStand(claimedBoothSlot, "Front") or prepTargetCF
                if landingTargetCF then
                    local landingPos = landingTargetCF.Position
                    local landingStart = tick()
                    local descentOrigin = finalTargetPos
                    while tick() - landingStart < landingDuration and char.Parent and root.Parent do
                        local now = tick()
                        local dt = now - lastFrameTick
                        lastFrameTick = now
                        local p = math.clamp((now - landingStart) / landingDuration, 0, 1)
                        local smoothP = p * p * (3 - (2 * p))
                        finalTargetPos = descentOrigin:Lerp(landingPos, smoothP)
                        local travelDir = Vector3.new(landingTargetCF.LookVector.X, 0, landingTargetCF.LookVector.Z)
                        if travelDir.Magnitude < 0.001 then
                            travelDir = Vector3.new(0, 0, -1)
                        else
                            travelDir = travelDir.Unit
                        end
                        local spinSpeedAtFrame = baseIdleSpeed + ((targetSpinSpeed - baseIdleSpeed) * (1 - smoothP))
                        yaw += spinSpeedAtFrame * dt
                        pcall(function()
                            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end)
                        root.CFrame = CFrame.lookAt(finalTargetPos, finalTargetPos + travelDir) * CFrame.Angles(0, yaw, 0)
                        task.wait()
                    end
                    root.CFrame = landingTargetCF
                end

                if animateScript and animateScript:IsA("LocalScript") and animatePrevEnabled ~= nil then
                    animateScript.Enabled = animatePrevEnabled
                end
            end)

            if not ok then
                warn("Helicopter burst failed:", err)
                pendingHelicopterRaisedAmount = 0
                break
            end
        end

        currentHelicopterSpinTask = nil

        local currentChar = LocalPlayer.Character
        local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
        if settings.helicopterDieAfterLanding and currentHum and currentHum.Parent then
            task.delay(0.15, function()
                triggerLandingExplosion(currentHum)
            end)
        else
            restoreIdleMode()
        end
    end)
end

local function performHelicopterDonationSequence(raisedAmount)
    performHelicopterBurst(raisedAmount, HELICOPTER_TAKEOFF_SPIN_SPEED, 3.5, {
        registerDelay = math.random(14, 20) / 10,
        prepDuration = 0.8,
        groundedSpinDuration = 2.8,
        minRiseHeight = 28,
        ascentDuration = 6.5,
        landingDuration = 5.5
    })
end

local function getCharacterHumanoidRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

local function getSpinAngularVelocity()
    return SPIN_DONATION_BASE_SPEED
end

local function getSpinMover()
    local _, _, root = getCharacterHumanoidRoot()
    if not root then
        return nil
    end
    local existing = root:FindFirstChild("Spin")
    if existing and existing:IsA("BodyAngularVelocity") then
        return existing
    end
    return nil
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
    elseif existing and existing:IsA("BodyAngularVelocity") then
        existing:Destroy()
    end
end


settingHandlers = {
    helicopterEnabled = function(value)
        if value then
            startHelicopterIdleMode()
        else
            stopHelicopterIdleTask()
            stopHelicopterSpin()
            stopAstronautIdle()
        end
    end,
    textUpdateToggle = function(value)
        if value and updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    textColor = function(value)
        local normalized = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local lower = normalized:lower()
        local allowedNames = {
            green = true,
            blue = true,
            yellow = true,
            black = true,
            white = true,
            red = true,
            orange = true,
            pink = true,
            purple = true,
            gray = true,
            grey = true,
        }
        if not allowedNames[lower] and not normalized:match("^#%x%x%x%x%x%x$") then
            settings.textColor = defaults.textColor
            saveSettings()
            return
        end
        settings.textColor = allowedNames[lower] and lower or normalized:upper()
        saveSettings()
        if updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    goalBarColor = function(value)
        local lower = tostring(value or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local allowed = {
            green = true,
            blue = true,
            red = true,
            orange = true,
            purple = true,
        }
        settings.goalBarColor = allowed[lower] and lower or defaults.goalBarColor
        saveSettings()
        if updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    goalBox = function()
        if updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    goalBarHeaderText = function()
        saveSettings()
        if updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    fontFace = function(value)
        local fontName = tostring(value or defaults.fontFace)
        if not Enum.Font[fontName] then
            settings.fontFace = defaults.fontFace
            saveSettings()
            return
        end
        if updateBoothTextNow then
            updateBoothTextNow()
        end
    end,
    standingPosition = function(value)
        local positionMap = {
            Front = 3,
            Left = -6,
            Right = 6,
            Behind = -5.5,
        }
        settings.boothPosition = positionMap[tostring(value)] or 3
        saveSettings()
    end,
    spinSet = function()
        applySpinState()
    end,
    serverHopDelay = function(value)
        hopTimerResetTick = tick()
        donatedSinceHopTimerReset = 0
    end,
    minPlayerCount = function(value)
        local minVal = math.max(1, tonumber(value) or 23)
        settings.minPlayerCount = minVal
        if tonumber(settings.maxPlayerCount or 24) < minVal then
            settings.maxPlayerCount = minVal
        end
        saveSettings()
    end,
    maxPlayerCount = function(value)
        local maxVal = math.max(1, tonumber(value) or 24)
        if maxVal < tonumber(settings.minPlayerCount or 23) then
            settings.minPlayerCount = maxVal
        end
        settings.maxPlayerCount = maxVal
        saveSettings()
    end,
    vcServerHopToggle = function(value)
        if value then
            if not hasVerifiedRestrictedFeatureAccess() then
                settings.vcServerHopToggle = false
                saveSettings()
                notify("VC Server Hop", "verified players can use this.", 4, "vc-hop-locked", 2)
                return
            end
            serverHopNow("vc-server-hop-toggle")
        end
    end,
}

local handledClaimSlot
local revealedAfterClaim = false
local function onBoothClaimDetected(slot)
    if not slot then
        return
    end

    claimedBoothSlot = slot
    if handledClaimSlot == slot then
        return
    end

    handledClaimSlot = slot
    moveToClaimedBooth(slot)

    if settings.textUpdateToggle and settings.customBoothText and tostring(settings.customBoothText) ~= "" and updateBoothTextNow then
        task.delay(0.35, function()
            pcall(function()
                updateBoothTextNow()
            end)
        end)
    end

    if not revealedAfterClaim then
        main.Visible = true
        revealedAfterClaim = true
    end

    setMinimized(true)

end

local dropdownCloseFns = {}
local activeDropdown

local function createTextBox(parent, text, key, numeric)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 30)
    row.Parent = parent

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 24)
    box.Position = UDim2.new(0, 0, 0.5, -12)
    box.BackgroundColor3 = THEME.control
    box.TextColor3 = THEME.controlText
    box.PlaceholderColor3 = THEME.subtleText
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Center
    local prefix = text .. ": "
    box.Text = prefix .. tostring(settings[key])
    box.Parent = row
    applyTextGlow(box, GLOW_COLOR, 0.88)

    createCorner(box, CONTROL_CORNER_RADIUS)

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1
    boxStroke.Color = THEME.stroke
    boxStroke.Parent = box

    box.FocusLost:Connect(function(enterPressed)
        local prefPattern = "^" .. escapePattern(prefix)
        if not enterPressed then
            box.Text = prefix .. tostring(settings[key])
            return
        end

        local rawValue = box.Text:gsub(prefPattern, "")
        rawValue = rawValue:gsub("^%s+", ""):gsub("%s+$", "")

        if numeric then
            local n = tonumber(rawValue)
            if n == nil then
                box.Text = prefix .. tostring(settings[key])
                return
            end
            settings[key] = n
        else
            settings[key] = rawValue
        end

        saveSettings()
        if settingHandlers[key] then
            pcall(settingHandlers[key], settings[key])
        end
        box.Text = prefix .. tostring(settings[key])
    end)
end

local function createPlainTextBox(parent, placeholder, key, height, multiline)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    local boxHeight = math.max(38, tonumber(height) or 38)
    row.Size = UDim2.new(1, 0, 0, boxHeight + 6)
    row.Parent = parent

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, boxHeight)
    box.Position = UDim2.new(0, 0, 0, 3)
    box.BackgroundColor3 = THEME.control
    box.TextColor3 = THEME.controlText
    box.PlaceholderColor3 = THEME.subtleText
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    box.MultiLine = multiline == true
    box.TextWrapped = multiline == true
    box.PlaceholderText = placeholder
    box.Text = tostring(settings[key] or "")
    box.Parent = row
    applyTextGlow(box, GLOW_COLOR, 0.88)

    local boxPadding = Instance.new("UIPadding")
    boxPadding.PaddingLeft = UDim.new(0, 8)
    boxPadding.PaddingRight = UDim.new(0, 8)
    boxPadding.Parent = box

    createCorner(box, CONTROL_CORNER_RADIUS)

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1
    boxStroke.Color = THEME.stroke
    boxStroke.Parent = box

    local liveUpdateRevision = 0
    if key == "customBoothText" then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            settings[key] = tostring(box.Text or "")
            liveUpdateRevision += 1
            local revision = liveUpdateRevision

            task.delay(0.35, function()
                if revision ~= liveUpdateRevision then
                    return
                end

                saveSettings()

                if #settings[key] > 221 then
                    return
                end

                if settings.textUpdateToggle and tostring(settings[key]) ~= "" and updateBoothTextNow then
                    pcall(function()
                        updateBoothTextNow()
                    end)
                end
            end)
        end)
    end

    box.FocusLost:Connect(function()
        settings[key] = tostring(box.Text or "")
        saveSettings()
        if settingHandlers[key] then
            pcall(settingHandlers[key], settings[key])
        end
    end)

    return box
end

local function createDropdown(parent, text, key, options)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 30)
    row.Parent = parent

    local baseHeight = 30
    local optionHeight = 22
    local optionsHeight = (#options * optionHeight) + 6

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.Position = UDim2.new(0, 0, 0.5, -12)
    btn.BackgroundColor3 = THEME.control
    btn.TextColor3 = THEME.controlText
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Parent = row
    applyTextGlow(btn, GLOW_COLOR, 0.88)

    createCorner(btn, CONTROL_CORNER_RADIUS)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = THEME.stroke
    btnStroke.Parent = btn

    local listFrame = Instance.new("Frame")
    listFrame.Visible = false
    listFrame.BackgroundColor3 = THEME.control
    listFrame.BorderSizePixel = 0
    listFrame.Position = UDim2.new(0, 0, 0, baseHeight)
    listFrame.Size = UDim2.new(1, 0, 0, optionsHeight)
    listFrame.ZIndex = 20
    listFrame.Parent = row

    createCorner(listFrame, CONTROL_CORNER_RADIUS)

    local listStroke = Instance.new("UIStroke")
    listStroke.Thickness = 1
    listStroke.Color = THEME.stroke
    listStroke.Parent = listFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = listFrame

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 3)
    listPad.PaddingBottom = UDim.new(0, 3)
    listPad.PaddingLeft = UDim.new(0, 3)
    listPad.PaddingRight = UDim.new(0, 3)
    listPad.Parent = listFrame

    local idx = 1
    for i, v in ipairs(options) do
        if v == settings[key] then
            idx = i
            break
        end
    end

    local function syncText()
        btn.Text = text .. ": [ " .. tostring(options[idx]) .. " ]"
    end
    syncText()

    local expanded = false
    local function setExpanded(open)
        expanded = open
        listFrame.Visible = open
        row.Size = open and UDim2.new(1, 0, 0, baseHeight + optionsHeight + 2) or UDim2.new(1, 0, 0, baseHeight)
        btn.Text = (open and "▼ " or "") .. text .. ": [ " .. tostring(options[idx]) .. " ]"
    end

    dropdownCloseFns[row] = function()
        setExpanded(false)
    end

    for i, v in ipairs(options) do
        local optionBtn = Instance.new("TextButton")
        optionBtn.Size = UDim2.new(1, 0, 0, optionHeight)
        optionBtn.BackgroundColor3 = THEME.section
        optionBtn.TextColor3 = THEME.controlText
        optionBtn.Font = Enum.Font.Gotham
        optionBtn.TextSize = 12
        optionBtn.Text = tostring(v)
        optionBtn.ZIndex = 21
        optionBtn.Parent = listFrame
        applyTextGlow(optionBtn, GLOW_COLOR, 0.9)

        createCorner(optionBtn, CONTROL_CORNER_RADIUS)

        optionBtn.MouseButton1Click:Connect(function()
            idx = i
            settings[key] = options[idx]
            syncText()
            saveSettings()
            if settingHandlers[key] then
                pcall(settingHandlers[key], settings[key])
            end
            setExpanded(false)
            activeDropdown = nil
        end)
    end

    btn.MouseButton1Click:Connect(function()
        if activeDropdown and activeDropdown ~= row and dropdownCloseFns[activeDropdown] then
            dropdownCloseFns[activeDropdown]()
        end

        if expanded then
            setExpanded(false)
            activeDropdown = nil
        else
            setExpanded(true)
            activeDropdown = row
        end
    end)
end

local function createMessageDropdown(parent, text, key, fallback)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 30)
    row.Parent = parent

    local baseHeight = 30
    local contentHeight = 216

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.Position = UDim2.new(0, 0, 0.5, -12)
    btn.BackgroundColor3 = THEME.control
    btn.TextColor3 = THEME.controlText
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Text = text
    btn.Parent = row
    applyTextGlow(btn, GLOW_COLOR, 0.88)

    createCorner(btn, CONTROL_CORNER_RADIUS)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = THEME.stroke
    btnStroke.Parent = btn

    local content = Instance.new("Frame")
    content.Visible = false
    content.BackgroundColor3 = THEME.control
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0, 0, 0, baseHeight)
    content.Size = UDim2.new(1, 0, 0, contentHeight)
    content.Parent = row

    createCorner(content, CONTROL_CORNER_RADIUS)

    local contentStroke = Instance.new("UIStroke")
    contentStroke.Thickness = 1
    contentStroke.Color = THEME.stroke
    contentStroke.Parent = content

    local contentPad = Instance.new("UIPadding")
    contentPad.PaddingTop = UDim.new(0, 6)
    contentPad.PaddingBottom = UDim.new(0, 6)
    contentPad.PaddingLeft = UDim.new(0, 6)
    contentPad.PaddingRight = UDim.new(0, 6)
    contentPad.Parent = content

    local editor = Instance.new("TextBox")
    editor.Size = UDim2.new(1, 0, 0, 140)
    editor.BackgroundColor3 = THEME.section
    editor.TextColor3 = THEME.controlText
    editor.PlaceholderColor3 = THEME.subtleText
    editor.Font = Enum.Font.Gotham
    editor.TextSize = 12
    editor.ClearTextOnFocus = false
    editor.TextXAlignment = Enum.TextXAlignment.Left
    editor.TextYAlignment = Enum.TextYAlignment.Top
    editor.MultiLine = true
    editor.TextWrapped = false
    editor.PlaceholderText = "One message per line (no limit)"
    editor.Parent = content
    applyTextGlow(editor, GLOW_COLOR, 0.9)

    local editorPad = Instance.new("UIPadding")
    editorPad.PaddingTop = UDim.new(0, 6)
    editorPad.PaddingBottom = UDim.new(0, 6)
    editorPad.PaddingLeft = UDim.new(0, 8)
    editorPad.PaddingRight = UDim.new(0, 8)
    editorPad.Parent = editor

    createCorner(editor, CONTROL_CORNER_RADIUS)

    local editorStroke = Instance.new("UIStroke")
    editorStroke.Thickness = 1
    editorStroke.Color = THEME.stroke
    editorStroke.Parent = editor

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0.5, -3, 0, 24)
    saveBtn.Position = UDim2.new(0, 0, 0, 146)
    saveBtn.BackgroundColor3 = THEME.topBar
    saveBtn.TextColor3 = THEME.topBarText
    saveBtn.Font = Enum.Font.GothamSemibold
    saveBtn.TextSize = 11
    saveBtn.Text = "Save"
    saveBtn.Parent = content
    applyTextGlow(saveBtn, GLOW_COLOR, 0.84)

    createCorner(saveBtn, CONTROL_CORNER_RADIUS)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0.5, -3, 0, 24)
    closeBtn.Position = UDim2.new(0.5, 3, 0, 146)
    closeBtn.BackgroundColor3 = THEME.section
    closeBtn.TextColor3 = THEME.controlText
    closeBtn.Font = Enum.Font.GothamSemibold
    closeBtn.TextSize = 11
    closeBtn.Text = "Close"
    closeBtn.Parent = content
    applyTextGlow(closeBtn, GLOW_COLOR, 0.88)

    createCorner(closeBtn, CONTROL_CORNER_RADIUS)

    local nextLineBtn = Instance.new("TextButton")
    nextLineBtn.Size = UDim2.new(1, 0, 0, 24)
    nextLineBtn.Position = UDim2.new(0, 0, 0, 174)
    nextLineBtn.BackgroundColor3 = THEME.control
    nextLineBtn.TextColor3 = THEME.controlText
    nextLineBtn.Font = Enum.Font.GothamSemibold
    nextLineBtn.TextSize = 11
    nextLineBtn.Text = "Skip To Next Line"
    nextLineBtn.Parent = content
    applyTextGlow(nextLineBtn, GLOW_COLOR, 0.88)

    createCorner(nextLineBtn, CONTROL_CORNER_RADIUS)

    local currentList = normalizeMessageList(settings[key], defaults[key])
    settings[key] = currentList
    editor.Text = table.concat(currentList, "\n")

    local expanded = false
    local function setExpanded(open)
        expanded = open
        content.Visible = open
        row.Size = open and UDim2.new(1, 0, 0, baseHeight + contentHeight + 2) or UDim2.new(1, 0, 0, baseHeight)
        btn.Text = (open and "▼ " or "") .. text
    end

    dropdownCloseFns[row] = function()
        setExpanded(false)
    end

    saveBtn.MouseButton1Click:Connect(function()
        local parsed = {}
        for line in tostring(editor.Text or ""):gmatch("[^\r\n]+") do
            local message = trimText(line)
            if message ~= "" then
                table.insert(parsed, message)
            end
        end

        settings[key] = normalizeMessageList(parsed, {fallback})
        editor.Text = table.concat(settings[key], "\n")
        saveSettings()
        notify("Chat Messages", text .. " saved.", 3, "chat-message-save-" .. key, 0.5)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        setExpanded(false)
        activeDropdown = nil
    end)

    nextLineBtn.MouseButton1Click:Connect(function()
        editor.Text = tostring(editor.Text or "") .. "\n"
        pcall(function()
            editor:CaptureFocus()
            editor.CursorPosition = #editor.Text + 1
        end)
    end)

    btn.MouseButton1Click:Connect(function()
        if activeDropdown and activeDropdown ~= row and dropdownCloseFns[activeDropdown] then
            dropdownCloseFns[activeDropdown]()
        end

        if expanded then
            setExpanded(false)
            activeDropdown = nil
        else
            setExpanded(true)
            activeDropdown = row
        end
    end)
end

local function createButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 104, 0, 23)
    btn.BackgroundColor3 = THEME.topBar
    btn.TextColor3 = THEME.topBarText
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.Text = text
    btn.Parent = parent
    applyTextGlow(btn, GLOW_COLOR, 0.84)

    createCorner(btn, CONTROL_CORNER_RADIUS)

    btn.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            warn("Button callback error:", err)
        end
    end)
end

local function createSlider(parent, text, key, minVal, maxVal)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 44)
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = THEME.controlText
    lbl.Parent = row
    applyTextGlow(lbl, GLOW_COLOR, 0.88)

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0, 26)
    track.BackgroundColor3 = THEME.control
    track.BorderSizePixel = 0
    track.Parent = row

    createCorner(track, CONTROL_CORNER_RADIUS)

    local trackStroke = Instance.new("UIStroke")
    trackStroke.Thickness = 1
    trackStroke.Color = THEME.stroke
    trackStroke.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = THEME.accent
    fill.BorderSizePixel = 0
    fill.Parent = track

    createCorner(fill, CONTROL_CORNER_RADIUS)

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.BackgroundColor3 = THEME.accent
    thumb.BorderSizePixel = 0
    thumb.Position = UDim2.new(0, 0, 0.5, 0)
    thumb.ZIndex = 5
    thumb.Parent = track

    createCorner(thumb, 2)

    local function updateVisuals(val)
        val = math.clamp(tonumber(val) or minVal, minVal, maxVal)
        local ratio = (val - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
        local rounded = math.floor((val * 100) + 0.5) / 100
        local displayValue = rounded == math.floor(rounded) and tostring(math.floor(rounded)) or string.format("%.2f", rounded):gsub("0+$", ""):gsub("%.$", "")
        lbl.Text = text .. ": " .. displayValue
    end

    local currentValue = math.clamp(tonumber(settings[key]) or minVal, minVal, maxVal)
    updateVisuals(currentValue)

    local dragging = false

    local function setFromAbsoluteX(absX)
        local trackAbsPos = track.AbsolutePosition
        local trackAbsSize = track.AbsoluteSize
        if trackAbsSize.X <= 0 then return end
        local ratio = math.clamp((absX - trackAbsPos.X) / trackAbsSize.X, 0, 1)
        local newVal = math.clamp(math.floor(minVal + ratio * (maxVal - minVal) + 0.5), minVal, maxVal)
        if newVal ~= settings[key] then
            settings[key] = newVal
            updateVisuals(newVal)
            saveSettings()
            if settingHandlers and settingHandlers[key] then
                pcall(settingHandlers[key], settings[key])
            end
        end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromAbsoluteX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            setFromAbsoluteX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return updateVisuals
end

local function createInfoLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 16)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = THEME.subtleText
    label.TextWrapped = true
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Text = tostring(text)
    label.Parent = parent
    return label
end

local function buildSettingsTabs()
    local hasRestrictedAccess = hasVerifiedRestrictedFeatureAccess()

    local boothTab = createTab("Booth")
    local mainTab = createTab("Main")
    local chatTab = createTab("Chat")
    local webhookTab = createTab("Webhook")
    local serverTab = createTab("Server Hop")

    local boothSection = createSection(boothTab, "Booth Settings")
    createToggle(boothSection, "Text Update", "textUpdateToggle")
    createTextBox(boothSection, "Text Update Delay (S)", "textUpdateDelay", true)
    createTextBox(boothSection, "Text Color", "textColor", false)
    createTextBox(boothSection, "Robux Goal", "goalBox", true)
    createDropdown(boothSection, "Goal Bar Color", "goalBarColor", {"green", "blue", "red", "orange", "purple"})
    local boothTextBox
    createInfoLabel(boothSection, "Goal Bar Header:")
    local goalBarHeaderBox = createPlainTextBox(boothSection, "GOAL $G", "goalBarHeaderText", 38, false)
    createInfoLabel(boothSection, "Use $G here if you want the current goal amount.")
    createButton(boothSection, "Paste Goal Bar", function()
        settings.goalBarHeaderText = tostring(goalBarHeaderBox.Text or settings.goalBarHeaderText or "GOAL $G")
        local nextText = buildGoalBarTemplate()
        if #nextText > 221 then
            notify("Goal Bar", "Goal bar template is too long for the booth.", 4, "goal-bar-limit", 1)
            return
        end
        settings.customBoothText = nextText
        saveSettings()
        local ok, mode = updateBoothTextNow()
        if ok then
            boothTextBox.Text = nextText
            notify("Goal Bar", "Goal bar pasted onto the booth.", 4, "goal-bar-ok", 1)
        elseif mode == "local-preview-only" then
            boothTextBox.Text = nextText
            notify("Goal Bar", "Preview updated, waiting for remote confirmation.", 4, "goal-bar-preview", 2)
        else
            notify("Goal Bar", "Could not paste the goal bar yet.", 4, "goal-bar-fail", 2)
        end
    end)
    createInfoLabel(boothSection, "Custom Booth Text:")
    boothTextBox = createPlainTextBox(boothSection, "Write the exact booth text here...", "customBoothText", 56, true)
    createInfoLabel(boothSection, "$C = current | $G = goal | $BAR = goal progress")
    createInfoLabel(boothSection, "Text colors: green, blue, yellow, black, white, red, orange, pink, purple, gray/grey, or #RRGGBB")
    createDropdown(boothSection, "Font", "fontFace", boothFontOptions)
    createButton(boothSection, "Update", function()
        local nextText = tostring(boothTextBox.Text or "")
        if #nextText > 221 then
            boothTextBox.Text = "Character limit reached"
            notify("Booth Text", "Character limit reached.", 4, "booth-text-limit", 1)
            return
        end

        settings.customBoothText = nextText
        saveSettings()
        local ok, mode = updateBoothTextNow()
        if ok then
            notify("Booth Text", "Booth text updated.", 4, "booth-text-ok", 1)
        elseif mode == "local-preview-only" then
            notify("Booth Text", "Preview updated, waiting for remote confirmation.", 4, "booth-text-preview", 2)
        else
            notify("Booth Text", "Could not update booth text yet.", 4, "booth-text-fail", 2)
        end
    end)
    createDropdown(boothSection, "Standing Position", "standingPosition", {"Front", "Left", "Right", "Behind"})

    do
        local mainSection = createSection(mainTab, "Main Settings")
        createToggle(mainSection, "Helicopter On-Donation", "helicopterEnabled")
        createToggle(mainSection, "Die After Landing", "helicopterDieAfterLanding")
        createToggle(mainSection, "1R$= +1 Spin Speed", "spinSet")
        createTextBox(mainSection, "Test Donation Amount (R$)", "testDonationAmount", true)
        createButton(mainSection, "Test Donation", function()
            local stat = getRaisedStatObject()
            local amount = math.max(1, tonumber(settings.testDonationAmount) or 6)
            if stat and type(stat.Value) == "number" then
                stat.Value += amount
                notify("Test Donation", ("Simulated +%d R$ donation."):format(amount), 3, "test-dono", 1)
            else
                notify("Test Donation", "Raised stat not found.", 3, "test-dono-missing", 1)
            end
        end)
    end

    do
        if hasRestrictedAccess then
            local chatSection = createSection(chatTab, "Chat Settings")
            createToggle(chatSection, "Auto Thank You", "autoThanks")
            createTextBox(chatSection, "Thanks Delay (S)", "thanksDelay", true)
            createMessageDropdown(chatSection, "Thank You Messages", "thanksMessage", "Thank you")
            createToggle(chatSection, "Auto Beg", "autoBeg")
            createTextBox(chatSection, "Beg Delay (S)", "begDelay", true)
            createMessageDropdown(chatSection, "Begging Messages", "begMessage", "Please donate")
        else
            createLockedTabNotice(chatTab)
        end
    end

do
    local webhookSection = createSection(webhookTab, "Webhook Settings")
    createToggle(webhookSection, "Webhook Enabled", "webhookToggle")
    createTextBox(webhookSection, "Webhook URL", "webhookBox", false)
    -- Donation Notifier feature only - other webhook options removed per user request
end

do
    local serverSection = createSection(serverTab, "Serverhop Settings")
    createToggle(serverSection, "Auto Server Hop", "serverHopToggle")
    createTextBox(serverSection, "Server Hop Delay (Minutes)", "serverHopDelay", true)
    createTextBox(serverSection, "Min Players in Server", "minPlayerCount", true)
    createTextBox(serverSection, "Max Players in Server", "maxPlayerCount", true)
    createToggle(serverSection, "Anti Bot Booths [BETA]", "antiBotServers")
    createTextBox(serverSection, "Bot Booth Threshold", "antiBotThreshold", true)
    createTextBox(serverSection, "Bot Scan Interval (S)", "antiBotInterval", true)
    createTextBox(serverSection, "Zero Donated Bot Threshold", "zeroDonatedBotThreshold", true)
    createToggle(serverSection, "Mod Evader", "modEvader")
    createButton(serverSection, "Scan Bot Booths Now", function()
        local scan = runBotDetectionScan()
        notifyBotScanResult(scan, true)
    end)
    createButton(serverSection, "Server Hop Now", function()
        requestServerHop("manual-button")
    end)

    -- VC Server Hop
    if hasRestrictedAccess then
        createToggle(serverSection, "VC Server Hop (All Servers)", "vcServerHopToggle")
    else
        createLockedToggleRow(serverSection, "VC Server Hop (All Servers)")
    end
end

end

buildSettingsTabs()

task.spawn(function()
    task.wait(2)
    local claimed, info = claimBoothNow()
    if claimed then
        onBoothClaimDetected(info)
    end
end)

task.defer(function()
    if settings.spinSet then
        applySpinState()
    end
end)

task.spawn(function()
    while task.wait(0.8) do
        local boothLocation = getBoothLocation()
        local boothUiFolder = boothLocation and boothLocation:FindFirstChild("BoothUI")
        local ownedSlot = boothUiFolder and findOwnedBoothSlot(boothUiFolder)
        if ownedSlot then
            onBoothClaimDetected(ownedSlot)
        end
    end
end)

task.spawn(function()
    local lastHopTick = 0
    while task.wait(1) do
        if settings.antiBotServers then
            local interval = math.max(2, tonumber(settings.antiBotInterval) or 8)
            task.wait(interval)

            local scan = runBotDetectionScan()
            local zeroThreshold = math.max(1, tonumber(settings.zeroDonatedBotThreshold) or 16)
            local boothThreshold = math.max(1, tonumber(settings.antiBotThreshold) or 6)
            local zeroCount = tonumber(scan.zeroCount) or 0
            if zeroCount > zeroThreshold and (tick() - lastHopTick) > 8 then
                lastHopTick = tick()
                notify("Bot Detection", ("Zero donated check tripped: %d > %d | Booths: %d | Total: %d. Hopping..."):format(zeroCount, zeroThreshold, tonumber(scan.boothCount) or 0, tonumber(scan.totalCount) or 0), 5, "zero-donated-hop", 10)
                requestServerHop("zero-donated-bot-server")
            elseif (tonumber(scan.boothCount) or 0) >= boothThreshold and (tick() - lastHopTick) > 8 then
                lastHopTick = tick()
                shouldHopForBots(scan)
            end
        end
    end
end)

task.spawn(function()
    local lastPopulationHopTick = 0
    while task.wait(1) do
        task.wait(9)
        local playerCount = #Players:GetPlayers()
        local threshold = 15
        if playerCount < threshold and (tick() - lastPopulationHopTick) > 10 then
            lastPopulationHopTick = tick()
            notify("Server Hop", ("Server has %d players (below %d). Hopping..."):format(playerCount, threshold), 5, "population-hop", 6)
            requestServerHop("population-hop")
        end
    end
end)

task.spawn(function()
    local lastModHopTick = 0
    while task.wait(1) do
        if settings.modEvader then
            task.wait(3)
            local detectedPlayer = findDetectedModPlayer()
            if detectedPlayer and (tick() - lastModHopTick) > 8 then
                local displayName = tostring(detectedPlayer.DisplayName or detectedPlayer.Name or "Unknown")
                local username = tostring(detectedPlayer.Name or "Unknown")
                if requestServerHop("mod-detection") then
                    lastModHopTick = tick()
                    notify("Mod Evader", ("Flagged user detected: %s (@%s). Hopping..."):format(displayName, username), 5, "mod-evader-hop", 8)
                end
            end
        end
    end
end)

task.spawn(function()
    local lastTextUpdate = 0
    while task.wait(1) do
        if settings.textUpdateToggle then
            local delaySeconds = math.max(3, tonumber(settings.textUpdateDelay) or 30)
            if tick() - lastTextUpdate >= delaySeconds then
                lastTextUpdate = tick()
                local ok = updateBoothTextNow()
                if not ok then
                    local boothLocation = getBoothLocation()
                    local boothUiFolder = boothLocation and boothLocation:FindFirstChild("BoothUI")
                    if boothUiFolder then
                        local owned = findOwnedBoothSlot(boothUiFolder)
                        if owned then
                            claimedBoothSlot = owned
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    local raisedObj = getRaisedStatObject()
    if not raisedObj then
        return
    end

    local lastRaised = tonumber(raisedObj.Value) or 0

    raisedObj.Changed:Connect(function()
        local current = tonumber(raisedObj.Value) or 0
        local delta = current - lastRaised
        if delta <= 0 then
            lastRaised = current
            return
        end

        lastRaised = current
        markDonationForHopTimer(delta)

        if settings.spinSet then
            local spin = getSpinMover()
            if spin then
                local averageDelta = delta / 3
                local nextVelocity = averageDelta + spin.AngularVelocity.Y
                spin.AngularVelocity = Vector3.new(0, nextVelocity, 0)
            else
                applySpinState()
            end
        end

        if settings.helicopterEnabled then
            performHelicopterDonationSequence(delta)
        end

        sendDonationWebhook(delta, consumeRecentDonationDonorInfo(delta))

        if settings.autoThanks then
            task.spawn(function()
                task.wait(math.max(0, tonumber(settings.thanksDelay) or 0))
                sendChatMessage(pickRandomMessage(settings.thanksMessage, "Thank you"))
            end)
        end
    end)
end)

if LocalPlayer.Character then
    if settings.helicopterEnabled then
        task.delay(1.5, startHelicopterIdleMode)
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1.5, function()
        local character = LocalPlayer.Character
        if character then
            task.spawn(function()
            end)
        end
        if claimedBoothSlot then
            moveToClaimedBooth(claimedBoothSlot)
        end
        stopAstronautIdle()
        stopHelicopterIdleTask()
        stopHelicopterSpin()
        if settings.helicopterEnabled then
            startHelicopterIdleMode()
        end
        if settings.spinSet then
            applySpinState()
        end
    end)
end)

task.spawn(function()
    while task.wait(1) do
        if settings.serverHopToggle then
            local delayMinutes = math.max(1, tonumber(settings.serverHopDelay) or 15)
            if tick() - hopTimerResetTick >= (delayMinutes * 60) then
                if requestServerHop("auto-timer") then
                    resetHopTimer()
                end
            end
        else
            hopTimerResetTick = tick()
        end
    end
end)

task.spawn(function()
    local lastBegTick = 0
    while task.wait(1) do
        if settings.autoBeg then
            local delaySeconds = math.max(3, tonumber(settings.begDelay) or 300)
            if tick() - lastBegTick >= delaySeconds then
                lastBegTick = tick()
                sendChatMessage(pickRandomMessage(settings.begMessage, "Please donate"))
            end
        else
            lastBegTick = tick()
        end
    end
end)

task.spawn(function()
    while task.wait(0.4) do
        if settings.spinSet and claimedBoothSlot and not currentHelicopterSpinTask then
            local _, _, root = getCharacterHumanoidRoot()
            local targetCF = getClaimedBoothTargetCFrame(claimedBoothSlot)
            if root and targetCF then
                local distance = (root.Position - targetCF.Position).Magnitude
                if distance > 12 then
                    root.CFrame = targetCF
                    task.delay(0.1, function()
                        if root and root.Parent and settings.spinSet then
                            root.CFrame = targetCF
                        end
                    end)
                end
            end
        end
    end
end)

activateTab("Main")
setMinimized(true)

RunService.RenderStepped:Connect(function()
    local viewport = getViewportSize()
    local pos = main.Position
    local rightMargin = 20
    local bottomMargin = 20
    local x = math.clamp(pos.X.Offset, -main.AbsoluteSize.X + 120, viewport.X - rightMargin)
    local y = math.clamp(pos.Y.Offset, 0, viewport.Y - bottomMargin)
    main.Position = UDim2.new(pos.X.Scale, x, pos.Y.Scale, y)
end)

lastViewport = getViewportSize()
RunService.Heartbeat:Connect(function()
    local viewport = getViewportSize()
    if viewport ~= lastViewport then
        lastViewport = viewport
        if minimized then
            main.Position = getBottomRightPosition(46)
        else
            applyResponsiveSize(false)
        end
    end
end)

return gui
