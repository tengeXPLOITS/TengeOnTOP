        -- Build a Koyg-style UI derived from pls_dono_custom_gui; adapt to use SETTINGS
        local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
        do
            -- remove any existing UI
            pcall(function()
                local existing = playerGui:FindFirstChild("PlsWaitUI")
                if existing then pcall(function() existing:Destroy() end) end
                SharedEnv.PLS_WAIT_UI_LOADED = nil
            end)

            local gui = Instance.new("ScreenGui")
            gui.Name = "PlsWaitUI"
            gui.ResetOnSpawn = false
            gui.IgnoreGuiInset = true
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            gui.DisplayOrder = 50
            gui.Parent = playerGui

            local THEME = {
                topBar = Color3.fromRGB(96, 96, 102),
                topBarText = Color3.fromRGB(248, 255, 248),
                panel = Color3.fromRGB(23, 23, 25),
                tabIdle = Color3.fromRGB(72, 72, 76),
                tabActive = Color3.fromRGB(96, 96, 102),
                section = Color3.fromRGB(18, 18, 20),
                control = Color3.fromRGB(31, 31, 34),
                controlText = Color3.fromRGB(238, 238, 238),
                subtleText = Color3.fromRGB(181, 191, 181),
                accent = Color3.fromRGB(145, 145, 150),
                stroke = Color3.fromRGB(66, 66, 71),
            }

            local SHELL_CORNER_RADIUS = 8
            local CONTROL_CORNER_RADIUS = 6
            local GLOW_COLOR = Color3.fromRGB(200, 200, 200)
            local SUBTLE_GLOW_COLOR = Color3.fromRGB(150, 150, 150)
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

            local function styleTextButton(btn, backgroundColor, textColor, textSize, font)
                btn.BackgroundColor3 = backgroundColor or THEME.control
                btn.TextColor3 = textColor or THEME.controlText
                btn.Font = font or Enum.Font.GothamSemibold
                btn.TextSize = textSize or 11
                btn.BorderSizePixel = 0
                btn.AutoButtonColor = false
            end

            local function styleTextBox(box, alignment, multiline)
                box.BackgroundColor3 = THEME.control
                box.TextColor3 = THEME.controlText
                box.PlaceholderColor3 = THEME.subtleText
                box.Font = Enum.Font.GothamSemibold
                box.TextSize = 12
                box.ClearTextOnFocus = false
                box.TextXAlignment = alignment or Enum.TextXAlignment.Center
                box.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
                box.MultiLine = multiline == true
                box.TextWrapped = multiline == true
            end

            local function createStyledButton(parent, text, size, position, backgroundColor, textColor, textSize, font)
                local btn = Instance.new("TextButton")
                btn.Size = size or UDim2.new(0, 104, 0, 23)
                btn.Position = position or UDim2.new(0, 0, 0, 0)
                btn.Text = tostring(text or "")
                styleTextButton(btn, backgroundColor, textColor, textSize, font)
                btn.Parent = parent

                local stroke = Instance.new("UIStroke")
                stroke.Thickness = 1
                stroke.Color = THEME.stroke
                stroke.Parent = btn

                createCorner(btn, CONTROL_CORNER_RADIUS)
                applyTextGlow(btn, GLOW_COLOR, 0.88)
                return btn
            end

            -- mirror settings reference
            local settings = SETTINGS

            local main = Instance.new("Frame")
            main.Name = "Main"
            main.Size = UDim2.new(0, 380, 0, 360)
            main.Position = UDim2.fromOffset(0, 0)
            main.BackgroundColor3 = THEME.panel
            main.BorderSizePixel = 0
            main.Parent = gui
            main.Visible = true

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
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 120, 125)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 100, 104)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 84)),
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
                title.Text = "Pls Wait — Donation Helper"
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
                subtitle.Text = "Pls Wait integration UI"
                subtitle.Parent = topBar
                applyTextGlow(subtitle, SUBTLE_GLOW_COLOR, SUBTLE_GLOW_TRANSPARENCY)
            end

            local minimizeBtn = Instance.new("TextButton")
            minimizeBtn.Name = "Minimize"
            minimizeBtn.Size = UDim2.new(0, 18, 0, 18)
            minimizeBtn.Position = UDim2.new(0, 8, 0.5, -9)
            minimizeBtn.BackgroundColor3 = THEME.control
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
                miniStroke.Color = THEME.stroke
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
                minimizeBtn.BackgroundColor3 = state and THEME.tabActive or THEME.control

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
            local settingHandlers = {}

            local function setTabVisualState(btn, active)
                if not btn then return end
                btn.BackgroundColor3 = active and THEME.tabActive or THEME.tabIdle
                btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 205, 210)
                local activeBar = btn:FindFirstChild("ActiveBar")
                if activeBar then activeBar.Visible = active end
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
                btn.AutomaticSize = Enum.AutomaticSize.None
                btn.Size = UDim2.new(0, 80, 0, 28)
                btn.BackgroundColor3 = THEME.tabIdle
                btn.TextColor3 = Color3.fromRGB(205, 205, 210)
                btn.Font = Enum.Font.GothamSemibold
                btn.TextSize = 12
                btn.Text = tostring(buttonText or name)
                btn.AutoButtonColor = false
                btn.Parent = tabHolder
                applyTextGlow(btn, GLOW_COLOR, 0.86)

                createCorner(btn, 8)

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
                    if activeTab ~= name then btn.BackgroundColor3 = Color3.fromRGB(84, 84, 90) end
                end)

                btn.MouseLeave:Connect(function()
                    if activeTab ~= name then btn.BackgroundColor3 = THEME.tabIdle end
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

                btn.MouseButton1Click:Connect(function() activateTab(name) end)
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

            -- Build the tabs and controls similar to the donor GUI
            local boothTab = createTab("Booth")
            local mainTab = createTab("Main")
            local chatTab = createTab("Chat")
            local webhookTab = createTab("Webhook")
            local serverTab = createTab("Server Hop")

            local boothSection = createSection(boothTab, "Booth Settings")
            createSection(boothTab, "Booth Settings")
            createDropdown = createDropdown or function() end
            -- minimal replication: wire webhook toggle and URL box into SETTINGS
            do
                local webSection = createSection(webhookTab, "Webhook Settings")
                local lblRow = Instance.new("Frame") lblRow.BackgroundTransparency = 1; lblRow.Size = UDim2.new(1,0,0,24); lblRow.Parent = webSection
                local label = Instance.new("TextLabel") label.BackgroundTransparency = 1; label.Size = UDim2.new(0.6,0,1,0); label.Text = "Webhook Enabled"; label.TextColor3 = THEME.controlText; label.Parent = lblRow
                local toggle = createStyledButton(lblRow, SETTINGS.webhookToggle and "ON" or "OFF", UDim2.new(0, 60, 0, 20), UDim2.new(0.6, 8, 0, 0), THEME.accent, THEME.topBarText, 12, Enum.Font.Gotham)
                toggle.MouseButton1Click:Connect(function()
                    SETTINGS.webhookToggle = not SETTINGS.webhookToggle
                    toggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
                    if SETTINGS.webhookToggle then startDonationMonitor() else stopDonationMonitor() end
                    pcall(SaveSettings)
                end)
                local urlBox = Instance.new("TextBox") urlBox.Size = UDim2.new(1, -12, 0, 24); urlBox.Position = UDim2.new(0,0,0,28); urlBox.Text = tostring(SETTINGS.webhookUrl or ""); styleTextBox(urlBox, Enum.TextXAlignment.Left, false); urlBox.Parent = webSection
                urlBox.FocusLost:Connect(function() SETTINGS.webhookUrl = tostring(urlBox.Text or ""); pcall(SaveSettings) end)

                -- Preview area for webhook embed fields
                local previewFrame = Instance.new("Frame")
                previewFrame.Size = UDim2.new(1, 0, 0, 110)
                previewFrame.Position = UDim2.new(0, 0, 0, 60)
                previewFrame.BackgroundColor3 = THEME.section
                previewFrame.BorderSizePixel = 0
                previewFrame.Parent = webSection
                createCorner(previewFrame, CONTROL_CORNER_RADIUS)

                local pfPad = Instance.new("UIPadding") pfPad.PaddingLeft = UDim.new(0,8); pfPad.PaddingTop = UDim.new(0,8); pfPad.Parent = previewFrame

                local donorLbl = Instance.new("TextLabel") donorLbl.Size = UDim2.new(1, -16, 0, 18); donorLbl.Position = UDim2.new(0, 8, 0, 6); donorLbl.BackgroundTransparency = 1; donorLbl.Font = Enum.Font.Gotham; donorLbl.TextSize = 12; donorLbl.TextColor3 = THEME.controlText; donorLbl.TextXAlignment = Enum.TextXAlignment.Left; donorLbl.Text = "Donor: (none)"; donorLbl.Parent = previewFrame
                local recipientLbl = Instance.new("TextLabel") recipientLbl.Size = UDim2.new(1, -16, 0, 18); recipientLbl.Position = UDim2.new(0, 8, 0, 26); recipientLbl.BackgroundTransparency = 1; recipientLbl.Font = Enum.Font.Gotham; recipientLbl.TextSize = 12; recipientLbl.TextColor3 = THEME.controlText; recipientLbl.TextXAlignment = Enum.TextXAlignment.Left; recipientLbl.Text = "Recipient: (you)"; recipientLbl.Parent = previewFrame
                local amountLbl = Instance.new("TextLabel") amountLbl.Size = UDim2.new(1, -16, 0, 18); amountLbl.Position = UDim2.new(0, 8, 0, 46); amountLbl.BackgroundTransparency = 1; amountLbl.Font = Enum.Font.Gotham; amountLbl.TextSize = 12; amountLbl.TextColor3 = THEME.controlText; amountLbl.TextXAlignment = Enum.TextXAlignment.Left; amountLbl.Text = "Amount (received): 0"; amountLbl.Parent = previewFrame
                local taxLbl = Instance.new("TextLabel") taxLbl.Size = UDim2.new(1, -16, 0, 18); taxLbl.Position = UDim2.new(0, 8, 0, 66); taxLbl.BackgroundTransparency = 1; taxLbl.Font = Enum.Font.Gotham; taxLbl.TextSize = 12; taxLbl.TextColor3 = THEME.controlText; taxLbl.TextXAlignment = Enum.TextXAlignment.Left; taxLbl.Text = "Tax applied: 0"; taxLbl.Parent = previewFrame

                local function refreshWebhookPreview()
                    local donorInfo = nil
                    if type(recentDonationLogs) == "table" and #recentDonationLogs > 0 then
                        donorInfo = recentDonationLogs[#recentDonationLogs].donorInfo
                    end
                    donorInfo = donorInfo or (type(getNearestPlayerInfo) == "function" and getNearestPlayerInfo()) or { name = "Unknown", displayName = "Unknown", userId = 0 }
                    local sampleAmount = math.max(1, tonumber(settings.testDonationAmount) or 6)
                    donorLbl.Text = "Donor: " .. (donorInfo.displayName or donorInfo.name or "Unknown")
                    recipientLbl.Text = "Recipient: You"
                    amountLbl.Text = "Amount (received): " .. tostring(sampleAmount)
                    taxLbl.Text = "Tax applied: " .. tostring(math.floor(sampleAmount * 0.6))
                end

                refreshWebhookPreview()

                local btnRow = Instance.new("Frame") btnRow.BackgroundTransparency = 1; btnRow.Size = UDim2.new(1,0,0,28); btnRow.Position = UDim2.new(0,0,0,176); btnRow.Parent = webSection
                local testBtn = createStyledButton(btnRow, "Send Test Webhook", UDim2.new(0, 140, 0, 24), UDim2.new(0, 0, 0, 0), THEME.topBar, THEME.topBarText, 12, Enum.Font.GothamSemibold)
                local refreshBtn = createStyledButton(btnRow, "Refresh Preview", UDim2.new(0, 120, 0, 24), UDim2.new(0, 148, 0, 0), THEME.control, THEME.controlText, 12, Enum.Font.Gotham)

                testBtn.MouseButton1Click:Connect(function()
                    local donorInfo = (type(recentDonationLogs) == "table" and #recentDonationLogs > 0) and recentDonationLogs[#recentDonationLogs].donorInfo or (type(getNearestPlayerInfo) == "function" and getNearestPlayerInfo()) or { name = "Unknown", displayName = "Unknown", userId = 0 }
                    local amount = math.max(1, tonumber(settings.testDonationAmount) or 6)
                    postWebhookEvent("donation", { donorName = donorInfo.name or donorInfo.displayName, amount = amount, taxed = math.floor(amount * 0.6) })
                end)
                refreshBtn.MouseButton1Click:Connect(function() refreshWebhookPreview() end)
            end

            -- Apply saved settings visual state
            activateTab("Main")
            SharedEnv.PLS_WAIT_UI_LOADED = true
        end
        if TextChatService then
            local channels = TextChatService:FindFirstChild("TextChannels") or TextChatService:WaitForChild("TextChannels", 6)
            if channels then
                for _, ch in ipairs(channels:GetChildren()) do
                    pcall(function()
                        if ch and ch.MessageReceived then
                            ch.MessageReceived:Connect(function(message)
                                pcall(function()
                                    local text = tostring((message and message.Text) or "")
                                    recordDonationLogMessage(text)
                                end)
                            end)
                        end
                    end)
                end
                channels.ChildAdded:Connect(function(c)
                    pcall(function()
                        if c and c.MessageReceived then
                            c.MessageReceived:Connect(function(message)
                                pcall(function()
                                    recordDonationLogMessage(tostring((message and message.Text) or ""))
                                end)
                            end)
                        end
                    end)
                end)
            end
        end
    end)

    local function consumeRecentDonationDonorInfo(amount)
        pruneRecentDonationLogs()
        local targetAmount = tonumber(amount) or 0
        if targetAmount > 0 then
            for i = 1, #recentDonationLogs do
                local entry = recentDonationLogs[i]
                if entry and tonumber(entry.amount) == targetAmount then
                    table.remove(recentDonationLogs, i)
                    return entry.donorInfo
                end
            end
        end
        if type(getNearestPlayerInfo) == "function" then return getNearestPlayerInfo() end
        return { name = "Unknown", displayName = "Unknown", userId = 0 }
    end

    -- Provide a nearest-player helper similar to pls_dono_custom_gui
    function getNearestPlayerInfo()
        local myCharacter = LocalPlayer.Character
        local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
        local myRoot = myHumanoid and myHumanoid.RootPart
        if not myRoot then
            return { name = "Unknown", displayName = "Unknown", userId = 0 }
        end
        local nearestPlayer = nil
        local nearestDistance = math.huge
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character then
                local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                local root = hum and hum.RootPart
                if root then
                    local dist = (root.Position - myRoot.Position).Magnitude
                    if dist < nearestDistance then
                        nearestDistance = dist
                        nearestPlayer = pl
                    end
                end
            end
        end
        if nearestPlayer then
            return { name = tostring(nearestPlayer.Name or "Unknown"), displayName = tostring(nearestPlayer.DisplayName or nearestPlayer.Name or "Unknown"), userId = tonumber(nearestPlayer.UserId) or 0 }
        end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                return { name = tostring(pl.Name or "Unknown"), displayName = tostring(pl.DisplayName or pl.Name or "Unknown"), userId = tonumber(pl.UserId) or 0 }
            end
        end
        return { name = "Unknown", displayName = "Unknown", userId = 0 }
    end

-- performHttpRequest helper (syn/request or common aliases)
local function performHttpRequest(options)
    if syn and syn.request then return syn.request(options) end
    if request then return request(options) end
    if http_request then return http_request(options) end
    return nil
end

-- queueOnTeleport helper (supports executors)
local function queueOnTeleport(codeString)
    if not codeString or codeString == "" then return false end
    if queue_on_teleport then pcall(function() queue_on_teleport(codeString) end); return true end
    if syn and syn.queue_on_teleport then pcall(function() syn.queue_on_teleport(codeString) end); return true end
    if fluxus and fluxus.queue_on_teleport then pcall(function() fluxus.queue_on_teleport(codeString) end); return true end
    return false
end

-- Single search attempt: returns true if teleport was initiated
local function serverSearchAttempt(minPlayers, maxPlayers, fast)
    -- if nil passed, treat as any player count (no filter)
    if minPlayers then minPlayers = tonumber(minPlayers) end
    if maxPlayers then maxPlayers = tonumber(maxPlayers) end
    local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100"):format(tostring(PLACE_ID))
    -- retry behavior: fast=true does a single quick attempt, otherwise retry a few times
    local res = nil
    local attempts = fast and 1 or 3
    for i=1,attempts do
        res = performHttpRequest({ Url = url, Method = "GET" })
        if res and type(res.Body) == "string" and res.Body ~= "" then break end
        if not fast then task.wait(0.25) end
    end
    if not (res and type(res.Body) == "string" and res.Body ~= "") then return false end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not (ok and decoded and type(decoded.data) == "table") then return false end
    for _, server in ipairs(decoded.data) do
        local playing = tonumber(server.playing) or 0
        if server.id and tostring(server.id) ~= tostring(game.JobId) then
            if minPlayers and maxPlayers and not (playing >= minPlayers and playing <= maxPlayers) then
                -- skip this server (out of requested range)
            else
            -- queue this script to re-run on the destination and pass current settings via _G
            local ok2, cfgJson = pcall(function()
                return HttpService:JSONEncode({
                    webhookToggle = SETTINGS.webhookToggle,
                    webhookUrl = SETTINGS.webhookUrl,
                    antiAfk = SETTINGS.antiAfk,
                    serverStayTime = SETTINGS.serverStayTime,
                    persistToggles = SETTINGS.persistToggles,
                    emoteId = SETTINGS.emoteId,
                    emotePlaying = SETTINGS.emotePlaying and true or false,
                    autoServerHop = autoServerHopEnabled,
                })
            end)
            local qcore = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua"))()'
            local qcode = qcore
            if ok2 and cfgJson then
                qcode = ("(function() local _json = %q; local ok,cfg = pcall(function() return game:GetService('HttpService'):JSONDecode(_json) end); if ok and type(cfg)=='table' then _G.__PLS_WAIT_CONFIG = cfg end; local f,err = loadstring(game:HttpGet('https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua')); if f then pcall(f) else warn(err) end end)()"):format(cfgJson)
            end
            pcall(function() queueOnTeleport(qcode) end)
            local ts = game:GetService("TeleportService")
            local okt, terr = pcall(function()
                ts:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer)
            end)
            if okt then
                return true
            else
                local terrs = tostring(terr or "")
                local lterrs = terrs:lower()
                -- On GameFull / Error 772 / raiseTeleportInitFailedEvent, queue script and immediately kick (no extra notify)
                if lterrs:find("772") or lterrs:find("error code: 772") or lterrs:find("gamefull") or lterrs:find("requested experience is full") or lterrs:find("raiseteleportinitfailedevent") then
                    -- ensure qcode available; queue it again to be safe
                    pcall(function() queueOnTeleport(qcode) end)
                    task.spawn(function()
                        task.wait(0.05)
                        pcall(function() LocalPlayer:Kick("finding a suitable server for you") end)
                    end)
                    return false
                end
                if lterrs:find("teleport failed") then
                    -- ignore and continue
                else
                    pcall(function() notify("Server Hop", ("Teleport error: %s"):format(terrs), 6) end)
                end
            end
            end
        end
    end
    return false
end

-- Replace older serverHopNow with controller that can run one-shot or persistent
local function serverHopNow(minPlayers, maxPlayers, persistent)
    minPlayers = tonumber(minPlayers) or 19
    maxPlayers = tonumber(maxPlayers) or 22
    persistent = persistent == true
    task.spawn(function()
        local backoff = 0.3
        local maxBackoff = 10
        while true do
            local ok = serverSearchAttempt(minPlayers, maxPlayers)
            if ok then break end
            if not persistent then
                notify("Server Hop", "No suitable servers found.", 4)
                break
            end
            -- safe exponential backoff with jitter to avoid rate limits
            local jitter = math.random() * 0.4
            task.wait(backoff + jitter)
            backoff = math.min(maxBackoff, backoff * 1.5)
        end
    end)
end

local function hookPlayer(player)
    if tryHookPlayerStat(player) then return end
    -- listen for leaderstats being added to this player
    donationConns["child_"..tostring(player.UserId)] = player.ChildAdded:Connect(function(child)
        if donationEnabled and child.Name == "leaderstats" then
            task.wait(0.05)
            tryHookPlayerStat(player)
        end
    end)
end

local function startDonationMonitor()
    if donationEnabled then return end
    donationEnabled = true
    -- Only monitor the local player for donations (Raised changes affecting the script user)
    pcall(function() hookPlayer(LocalPlayer) end)
    -- If leaderstats are added later to the local player, try to hook them
    donationConns["local_child"] = LocalPlayer.ChildAdded:Connect(function(child)
        if donationEnabled and child.Name == "leaderstats" then
            task.wait(0.05)
            tryHookPlayerStat(LocalPlayer)
        end
    end)
end

local function stopDonationMonitor()
    donationEnabled = false
    for k, conn in pairs(donationConns) do
        pcall(function() conn:Disconnect() end)
        donationConns[k] = nil
    end
    donationTotals = {}
end

-- Handle teleport 'server full' error by showing a KICKED modal and kicking the player
local function handleTeleportFullKick(reason)
    -- Use the default Roblox kick screen: just kick the player with the provided reason.
    task.spawn(function()
        task.wait(0.6)
        pcall(function()
            LocalPlayer:Kick(tostring(reason or "finding a suitable server for you"))
        end)
    end)
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

local function moveCharacterToPosition(pos, lookDir)
    if not pos then return false end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") )
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hrp then
        pcall(function()
            local targetPos = pos + Vector3.new(0,2,0)
            if lookDir and typeof(lookDir) == "Vector3" and lookDir.Magnitude > 0 then
                hrp.CFrame = CFrame.new(targetPos, targetPos + lookDir.Unit)
            else
                hrp.CFrame = CFrame.new(targetPos)
            end
        end)
        return true
    elseif hum then
        local ok, _ = pcall(function() hum:MoveTo(pos) end)
        return ok
    end
    return false
end

-- Compute a reliable center and principal axis for a stand using its BasePart children
local function getStandCenterAndPrincipalAxis(stand)
    if not stand then return nil, nil end
    local pts = {}
    for _, v in ipairs(stand:GetDescendants()) do
        if v:IsA("BasePart") then
            pts[#pts+1] = v.Position
        end
    end
    if #pts == 0 then return nil, nil end
    local n = #pts
    local mean = Vector3.new(0,0,0)
    for _, p in ipairs(pts) do mean = mean + p end
    mean = mean / n
    -- covariance matrix (3x3)
    local c11,c12,c13,c21,c22,c23,c31,c32,c33 = 0,0,0,0,0,0,0,0,0
    for _, p in ipairs(pts) do
        local d = p - mean
        c11 = c11 + d.X * d.X
        c12 = c12 + d.X * d.Y
        c13 = c13 + d.X * d.Z
        c21 = c21 + d.Y * d.X
        c22 = c22 + d.Y * d.Y
        c23 = c23 + d.Y * d.Z
        c31 = c31 + d.Z * d.X
        c32 = c32 + d.Z * d.Y
        c33 = c33 + d.Z * d.Z
    end
    -- power iteration to approximate principal eigenvector
    local v = Vector3.new(1,0,0)
    for i=1,10 do
        local x = c11 * v.X + c12 * v.Y + c13 * v.Z
        local y = c21 * v.X + c22 * v.Y + c23 * v.Z
        local z = c31 * v.X + c32 * v.Y + c33 * v.Z
        local nv = Vector3.new(x,y,z)
        if nv.Magnitude <= 1e-6 then break end
        v = nv.Unit
    end
    return mean, v
end

-- Compute a placement position in front of a stand and an away direction to face
local function computeStandPlacement(stand, playerPos, distanceAway)
    distanceAway = tonumber(distanceAway) or 4.5
    local pivot = tryGetPivotPosition(stand) or nil
    -- fallback pivot to center/principal axis if missing
    local standCFrame
    pcall(function()
        if type(stand.GetPivot) == "function" then
            standCFrame = stand:GetPivot()
        elseif stand.PrimaryPart then
            standCFrame = stand.PrimaryPart.CFrame
        end
    end)
    local frontDir
    if standCFrame then
        frontDir = standCFrame.LookVector
        if pivot == nil then pivot = standCFrame.Position end
    else
        local center, axis = getStandCenterAndPrincipalAxis(stand)
        if center and axis then
            if pivot == nil then pivot = center end
            frontDir = Vector3.new(axis.X, 0, axis.Z)
            if frontDir.Magnitude <= 1e-6 then frontDir = nil end
        end
    end
    if not pivot then
        -- as last resort search for any part position
        for _, v in ipairs(stand:GetDescendants()) do
            if v:IsA("BasePart") then pivot = v.Position; break end
        end
    end
    if not frontDir then
        if playerPos then
            frontDir = Vector3.new(playerPos.X - pivot.X, 0, playerPos.Z - pivot.Z)
        end
        if not frontDir or frontDir.Magnitude <= 1e-6 then
            frontDir = Vector3.new(0,0,-1)
        end
    end
    frontDir = Vector3.new(frontDir.X, 0, frontDir.Z)
    if frontDir.Magnitude <= 1e-6 then frontDir = Vector3.new(0,0,-1) end
    frontDir = frontDir.Unit
    local basePos = pivot + frontDir * (distanceAway + 1.0) + Vector3.new(0,2,0)
    local awayDir = (basePos - pivot)
    if awayDir.Magnitude <= 1e-6 then awayDir = frontDir end
    return basePos, awayDir.Unit
end

-- Check whether the local player is registered as owner on any stand
local function localPlayerOwnsAnyStand()
    local standsFolder = Workspace:FindFirstChild("Stands")
    if not standsFolder then return false end
    for _, stand in ipairs(standsFolder:GetChildren()) do
        if stand and stand.Parent then
            local ownerObj = stand:FindFirstChild("Wner") or stand:FindFirstChild("Owner")
            if ownerObj then
                if ownerObj:IsA("ObjectValue") and ownerObj.Value == LocalPlayer then
                    return true
                end
                if ownerObj:IsA("StringValue") and tostring(ownerObj.Value) == tostring(LocalPlayer.Name) then
                    return true
                end
                if (ownerObj:IsA("IntValue") or ownerObj:IsA("NumberValue")) and tonumber(ownerObj.Value) == tonumber(LocalPlayer.UserId) then
                    return true
                end
            end
        end
    end
    return false
end

-- Global simple range parser used outside UI
local function parseRangeGlobal(str)
    if not str or type(str) ~= "string" then return nil end
    -- support formats: "MIN-MAX" or a single number meaning 1-MAX
    local a,b = str:match("%s*(%d+)%s*%-%s*(%d+)%s*")
    if a and b then
        local mn = tonumber(a)
        local mx = tonumber(b)
        if not mn or not mx then return nil end
        if mn < 0 then mn = 0 end
        if mx < mn then return nil end
        return mn, mx
    end
    local single = str:match("%s*(%d+)%s*")
    if single then
        local mx = tonumber(single)
        if not mx then return nil end
        if mx < 1 then return nil end
        return 1, mx
    end
    return nil
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
    local distanceAway = 4.5 -- studs away from pivot (increase to avoid being too near)
    safePos = target.pivot + dir * distanceAway + Vector3.new(0, 2, 0)
    -- move and orient away from the booth before the first claim
    moveCharacterToPosition(safePos, dir)
    task.wait(0.25)
            local remote = ReplicatedStorage:FindFirstChild("ClaimStand") or ReplicatedStorage:WaitForChild("ClaimStand", 5) -- Ensure ClaimStand remote exists
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
            -- place character directly in front of the booth and orient them looking away from it
            pcall(function()
                local char = LocalPlayer.Character
                if char and target and target.pivot then
                        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                        if hrp then
                            -- attempt to use stand orientation when available for nicer placement
                            local standCFrame
                            pcall(function()
                                if type(target.stand.GetPivot) == "function" then
                                    standCFrame = target.stand:GetPivot()
                                elseif target.stand.PrimaryPart then
                                    standCFrame = target.stand.PrimaryPart.CFrame
                                end
                            end)
                            local basePos
                            local frontDir
                            if hrp then
                                local basePos, awayDir = computeStandPlacement(target.stand, playerPos, distanceAway)
                                if basePos and awayDir then
                                    hrp.CFrame = CFrame.new(basePos, basePos + awayDir)
                                end
                            end
                        end
                end
            end)
            -- after initial success and placement, notify and verify ownership; if not owned, server hop
            pcall(function()
                postWebhookEvent("claim", { slot = slot, result = res })
            end)
            task.wait(0.35)
            local owned = false
            pcall(function() owned = localPlayerOwnsAnyStand() end)
            if not owned then
                local hopRange = tostring(SETTINGS.hopRange or "19-22")
                local mn, mx = parseRangeGlobal(hopRange)
                notify("Booth Claim", "Claim not confirmed; server hopping to find available booth.", 5)
                if mn then
                    serverHopNow(mn, mx, true)
                end
            end
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

-- Ensure we only complete a single successful claim per script load to avoid duplicates
local _CLAIM_HAS_RUN = _CLAIM_HAS_RUN or false
local function claimBooth()
    if _CLAIM_HAS_RUN then return false end
    local ok, res = pcall(claimEmptyStands)
    -- if the claim executed successfully (returned true), mark as run
    if ok and res then
        _CLAIM_HAS_RUN = true
    end
    return ok, res
end

-- Koyg-style ScreenGui UI (simple, file-based save/load)
do
    local ok, playerGui = pcall(function()
        return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 6)
    end)
    if not (ok and playerGui) then
        notify("UI", "PlayerGui not available; UI disabled.", 5)
    else
        local Http = HttpService
        local CONFIG_PATH = "pls_wait_config.json"

        local serverStayTime = SETTINGS.serverStayTime or 30
        local hopRangeText = SETTINGS.hopRange or "19-22"
        local function parseRange(str)
            if not str or type(str) ~= "string" then return nil end
            -- support formats: "MIN-MAX" or a single number meaning 1-MAX
            local a,b = str:match("%s*(%d+)%s*%-%s*(%d+)%s*")
            if a and b then
                local mn = tonumber(a)
                local mx = tonumber(b)
                if not mn or not mx then return nil end
                if mn < 0 then mn = 0 end
                if mx < mn then return nil end
                return mn, mx
            end
            local single = str:match("%s*(%d+)%s*")
            if single then
                local mx = tonumber(single)
                if not mx then return nil end
                if mx < 1 then return nil end
                return 1, mx
            end
            return nil
        end
        local autoServerHopEnabled = false
        local autoServerHopTask = nil
        local manualHopRunning = false
        local manualHopTask = nil
        SETTINGS.persistToggles = SETTINGS.persistToggles or false

        local function SaveSettings()
            local data = {
                webhookToggle = SETTINGS.webhookToggle,
                webhookUrl = SETTINGS.webhookUrl,
                antiAfk = SETTINGS.antiAfk,
                hopRange = hopRangeText,
                serverStayTime = serverStayTime,
                persistToggles = SETTINGS.persistToggles,
                emoteId = SETTINGS.emoteId,
                emotePlaying = SETTINGS.emotePlaying and true or false,
                autoServerHop = autoServerHopEnabled,
            }
            SETTINGS.hopRange = hopRangeText
            local ok, encoded = pcall(function() return Http:JSONEncode(data) end)
            if not ok then return end
            pcall(function()
                if writefile then
                    writefile(CONFIG_PATH, encoded)
                elseif syn and syn.write_file then
                    syn.write_file(CONFIG_PATH, encoded)
                end
            end)
        end

        local function LoadSettings()
            local content = nil
            pcall(function()
                if readfile then
                    content = readfile(CONFIG_PATH)
                elseif syn and syn.read_file then
                    content = syn.read_file(CONFIG_PATH)
                end
            end)
            if not content or content == "" then return end
            local ok, decoded = pcall(function() return Http:JSONDecode(content) end)
            if not ok or type(decoded) ~= "table" then return end
            SETTINGS.webhookToggle = decoded.webhookToggle or SETTINGS.webhookToggle
            SETTINGS.webhookUrl = decoded.webhookUrl or SETTINGS.webhookUrl
            SETTINGS.antiAfk = decoded.antiAfk or SETTINGS.antiAfk
            hopRangeText = decoded.hopRange or hopRangeText
            serverStayTime = tonumber(decoded.serverStayTime) or serverStayTime
            SETTINGS.persistToggles = decoded.persistToggles or SETTINGS.persistToggles
            SETTINGS.emoteId = decoded.emoteId or SETTINGS.emoteId
            SETTINGS.emotePlaying = decoded.emotePlaying or SETTINGS.emotePlaying
            autoServerHopEnabled = decoded.autoServerHop or autoServerHopEnabled
        end

        pcall(function()
            if type(_G) == "table" and type(_G.__PLS_WAIT_CONFIG) == "table" then
                local cfg = _G.__PLS_WAIT_CONFIG
                SETTINGS.webhookToggle = cfg.webhookToggle or SETTINGS.webhookToggle
                SETTINGS.webhookUrl = cfg.webhookUrl or SETTINGS.webhookUrl
                SETTINGS.antiAfk = cfg.antiAfk or SETTINGS.antiAfk
                serverStayTime = tonumber(cfg.serverStayTime) or serverStayTime
                SETTINGS.persistToggles = cfg.persistToggles or SETTINGS.persistToggles
                hopRangeText = cfg.hopRange or hopRangeText
                SETTINGS.emoteId = cfg.emoteId or SETTINGS.emoteId
                autoServerHopEnabled = cfg.autoServerHop or autoServerHopEnabled
                _G.__PLS_WAIT_CONFIG = nil
            end
        end)

        pcall(LoadSettings)
        -- Provide a small UI helper used by buttons
        local function styleButton(btn)
            if not btn then return end
            pcall(function()
                btn.AutoButtonColor = false
                local base = btn.BackgroundColor3
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0,8)
                corner.Parent = btn
                local stroke = Instance.new("UIStroke")
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Thickness = 1
                stroke.Color = Color3.fromRGB(30,30,30)
                stroke.Parent = btn
                btn.MouseEnter:Connect(function()
                    pcall(function() btn.BackgroundColor3 = base:Lerp(Color3.fromRGB(255,255,255), 0.04) end)
                end)
                btn.MouseLeave:Connect(function()
                    pcall(function() btn.BackgroundColor3 = base end)
                end)
            end)
        end

        -- Prevent duplicate UIs across teleports / multiple runs: always remove any existing UI
        local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
        pcall(function()
            local existing = playerGui:FindFirstChild("PlsWaitUI")
            if existing then pcall(function() existing:Destroy() end) end
            SharedEnv.PLS_WAIT_UI_LOADED = nil
        end)
        local screen = Instance.new("ScreenGui")
        screen.Name = "PlsWaitUI"
        screen.ResetOnSpawn = false
        screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screen.Parent = playerGui
        SharedEnv.PLS_WAIT_UI_LOADED = true

        -- Glassy admin-panel style layout (smaller width for compact UI)
        local MAIN_W, MAIN_H = 620, 420
        local LEFT_W = 200
        local GAP = 16
        local mainFrame = Instance.new("Frame")
        mainFrame.Name = "MainFrame"
        mainFrame.Size = UDim2.new(0, MAIN_W, 0, MAIN_H)
        -- position bottom-left, keep margin and ensure it's visible on mobile
        mainFrame.AnchorPoint = Vector2.new(0, 1)
        mainFrame.Position = UDim2.new(0, 12, 1, -12)
        mainFrame.BackgroundColor3 = Color3.fromRGB(12,12,12)
        mainFrame.BackgroundTransparency = 0
        mainFrame.Parent = screen
        mainFrame.Active = true
        -- adaptive scale for mobile/PC
        local uiScale = Instance.new("UIScale")
        uiScale.Parent = mainFrame
        pcall(function()
            local cam = workspace and workspace.CurrentCamera
            local vs = (cam and cam.ViewportSize) or Vector2.new(1280,720)
            local scale = math.min(vs.X / 1280, vs.Y / 720)
            scale = math.clamp(scale, 0.7, 1)
            uiScale.Scale = scale
        end)
        -- Title bar (draggable on PC and mobile) - reduced height to avoid covering UI
        local titleBar = Instance.new("Frame")
        titleBar.Name = "TitleBar"
        titleBar.Size = UDim2.new(1, 0, 0, 28)
        titleBar.Position = UDim2.new(0, 0, 0, 0)
        titleBar.BackgroundColor3 = Color3.fromRGB(50,205,50)
        titleBar.BackgroundTransparency = 0
        titleBar.Parent = mainFrame
        titleBar.Active = true
        titleBar.ZIndex = 50
        local titleLblTop = Instance.new("TextLabel")
        titleLblTop.Size = UDim2.new(0.6, -48, 1, 0)
        titleLblTop.Position = UDim2.new(0, 12, 0, 0)
        titleLblTop.BackgroundTransparency = 1
        titleLblTop.Text = "Pls Wait 💵"
        titleLblTop.Font = Enum.Font.GothamBold
        titleLblTop.TextSize = 14
        titleLblTop.TextColor3 = Color3.fromRGB(240,240,240)
        titleLblTop.TextXAlignment = Enum.TextXAlignment.Left
        titleLblTop.Parent = titleBar

        -- small status label on the title bar (right side)
        local statusLbl = Instance.new("TextLabel")
        statusLbl.Size = UDim2.new(0.35, -80, 1, 0)
        statusLbl.Position = UDim2.new(0.6, 12, 0, 0)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Text = "Dropdown"
        statusLbl.Font = Enum.Font.Gotham
        statusLbl.TextSize = 12
        statusLbl.TextColor3 = Color3.fromRGB(240,240,240)
        statusLbl.TextXAlignment = Enum.TextXAlignment.Right
        statusLbl.Parent = titleBar
        statusLbl.ZIndex = 65

        -- Collapse/expand dropdown button on title bar to shorten UI
        local collapseBtn = Instance.new("TextButton")
        collapseBtn.Name = "CollapseBtn"
        collapseBtn.Size = UDim2.new(0, 28, 0, 24)
        collapseBtn.Position = UDim2.new(1, -44, 0, 2)
        collapseBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
        collapseBtn.TextColor3 = Color3.fromRGB(255,255,255)
        collapseBtn.Font = Enum.Font.Gotham
        collapseBtn.TextSize = 18
        collapseBtn.Text = "▾"
        collapseBtn.AutoButtonColor = false
        collapseBtn.Parent = titleBar
        collapseBtn.ZIndex = 68
        styleButton(collapseBtn)

        local collapsed = false
        local prevSize = mainFrame.Size
        local function setCollapsed(v)
            collapsed = v
            if collapsed then
                prevSize = mainFrame.Size
                -- hide all direct children except the titleBar and left menu so buttons stay clickable
                local lc = mainFrame:FindFirstChild("LeftCol")
                for _,c in ipairs(mainFrame:GetChildren()) do
                    if c ~= titleBar and c ~= lc and c.Name ~= "TitleBar" then
                        if pcall(function() return c.Visible end) then
                            pcall(function() c.Visible = false end)
                        end
                    end
                end
                -- keep left menu visible and shrink frame height
                mainFrame.Size = UDim2.new(prevSize.X.Scale, prevSize.X.Offset, 0, 56)
                collapseBtn.Text = "▴"
                statusLbl.Text = "Compact"
            else
                -- restore visibility and size
                for _,c in ipairs(mainFrame:GetChildren()) do
                    if c ~= titleBar and c.Name ~= "TitleBar" then
                        if pcall(function() return c.Visible end) then
                            pcall(function() c.Visible = true end)
                        end
                    end
                end
                mainFrame.Size = prevSize
                collapseBtn.Text = "▾"
                statusLbl.Text = "Dropdown"
            end
        end
        collapseBtn.MouseButton1Click:Connect(function()
            pcall(function() setCollapsed(not collapsed) end)
        end)

        -- Dragging logic (mouse + touch)
        do
            local dragging = false
            local dragInput = nil
            local dragStart = nil
            local startPos = nil
            local function update(input)
                local delta = input.Position - dragStart
                local newX = startPos.X.Offset + delta.X
                local newY = startPos.Y.Offset + delta.Y
                mainFrame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
            end
            titleBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragStart = input.Position
                    startPos = mainFrame.Position
                    dragInput = input
                    input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                            dragging = false
                        end
                    end)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if input == dragInput and dragging then
                    pcall(update, input)
                end
            end)
        end
        local mainCorner = Instance.new("UICorner")
        mainCorner.CornerRadius = UDim.new(0,12)
        mainCorner.Parent = mainFrame
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1,0,1,0)
        bg.Position = UDim2.new(0,0,0,0)
        bg.BackgroundColor3 = Color3.fromRGB(24,24,24)
        bg.BackgroundTransparency = 0.15
        bg.BorderSizePixel = 0
        bg.Parent = mainFrame
        local blurOverlay = Instance.new("UIGradient")
        blurOverlay.Rotation = 90
        blurOverlay.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(25,25,25)), ColorSequenceKeypoint.new(1, Color3.fromRGB(12,12,12))})
        blurOverlay.Parent = bg

        -- Squiggly background effect: single-layer squiggle (avoid heavy shadows)
        do
            local function makeLayer(offsetX, offsetY, sizePad, cornerRadius, c1, c2, rot)
                local f = Instance.new("Frame")
                f.Size = UDim2.new(1, sizePad, 1, sizePad)
                f.Position = UDim2.new(0, offsetX, 0, offsetY)
                f.BackgroundColor3 = Color3.fromRGB(24,24,24)
                f.BorderSizePixel = 0
                f.BackgroundTransparency = 0.12
                f.Parent = mainFrame
                local uc = Instance.new("UICorner") uc.CornerRadius = UDim.new(0, cornerRadius); uc.Parent = f
                local g = Instance.new("UIGradient")
                g.Rotation = rot or 90
                g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2)})
                g.Parent = f
                return f
            end
            makeLayer(-4, -3, 8, 12, Color3.fromRGB(26,26,26), Color3.fromRGB(14,14,14), 88)
        end

        -- Left menu column
        local leftCol = Instance.new("Frame")
        leftCol.Name = "LeftCol"
        leftCol.Size = UDim2.new(0, LEFT_W, 1, -20)
        leftCol.Position = UDim2.new(0, GAP, 0, 12)
        leftCol.BackgroundTransparency = 1
        leftCol.Parent = mainFrame
        -- use UIListLayout for stable button layout (prevents collapse breaking positions)
        local leftList = Instance.new("UIListLayout")
        leftList.SortOrder = Enum.SortOrder.LayoutOrder
        leftList.Padding = UDim.new(0, 12)
        leftList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        leftList.VerticalAlignment = Enum.VerticalAlignment.Top
        leftList.Parent = leftCol

        -- old left-column title removed (we use the draggable title bar)

        -- left menu buttons
        local menu = { {key="Main", icon="📋", text="Overview"}, {key="ServerHop", icon="🔀", text="Server Hop"}, {key="Webhook", icon="🔔", text="Webhook"} }
        local tabButtons = {}
        local tabFrames = {}
        for i, item in ipairs(menu) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.9, 0, 0, 40)
            btn.LayoutOrder = i
            btn.Text = (item.icon .. "  " .. item.text)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 16
            btn.TextColor3 = Color3.fromRGB(220,220,220)
            btn.BackgroundColor3 = Color3.fromRGB(28,28,28)
            btn.AutoButtonColor = false
            btn.ZIndex = 60
            local corner = Instance.new("UICorner") corner.Parent = btn
            btn.Parent = leftCol
            tabButtons[item.key] = btn

            local frame = Instance.new("Frame")
            local rightW = MAIN_W - LEFT_W - (GAP * 2)
            frame.Size = UDim2.new(0, rightW, 1, -24)
            frame.Position = UDim2.new(0, LEFT_W + GAP, 0, 12)
            frame.BackgroundTransparency = 1
            frame.Visible = (item.key == "Main")
            frame.Parent = mainFrame
            tabFrames[item.key] = frame
        end

        -- close button (parented to titleBar so it's always visible)
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 24, 0, 24)
        closeBtn.Position = UDim2.new(1, -28, 0, 2)
        closeBtn.Text = "✕"
        closeBtn.Font = Enum.Font.Gotham
        closeBtn.TextSize = 14
        closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
        local closeCorner = Instance.new("UICorner") closeCorner.Parent = closeBtn
        closeBtn.Parent = titleBar
        closeBtn.ZIndex = 70
        closeBtn.MouseButton1Click:Connect(function()
            pcall(function() screen:Destroy() end)
            SharedEnv.PLS_WAIT_UI_LOADED = nil
        end)

        -- (fade-in will be prepared after the UI is fully constructed)
        -- invisible overlay used to capture taps when UI is dimmed (mobile reliable wake)
        local wakeOverlay = Instance.new("TextButton")
        wakeOverlay.Size = UDim2.new(1, 0, 1, 0)
        wakeOverlay.Position = UDim2.new(0, 0, 0, 0)
        wakeOverlay.BackgroundTransparency = 1
        wakeOverlay.AutoButtonColor = false
        wakeOverlay.Visible = false
        wakeOverlay.ZIndex = 1000
        wakeOverlay.Parent = mainFrame

        -- Interaction listener: dimming/inactivity feature removed per user request
        do
            local UIS = game:GetService("UserInputService")
            -- Keep a minimal listener to capture UI interactions if needed later
            UIS.InputBegan:Connect(function(input, processed)
                -- intentionally left blank: inactivity dimming disabled
            end)
        end

        local function selectTab(name)
            for k,v in pairs(tabFrames) do v.Visible = false end
            tabFrames[name].Visible = true
        end
        for name, btn in pairs(tabButtons) do
            btn.MouseButton1Click:Connect(function() selectTab(name) end)
        end

        -- Main tab
        do
            local frame = tabFrames.Main
            -- Claim button removed (auto-claim runs on load/teleport)

            local afkLabel = Instance.new("TextLabel")
            afkLabel.Size = UDim2.new(0,120,0,20)
            afkLabel.Position = UDim2.new(0,10,0,10)
            afkLabel.Text = "Anti-AFK"
            afkLabel.TextColor3 = Color3.new(1,1,1)
            afkLabel.BackgroundTransparency = 1
            afkLabel.Parent = frame

            local afkToggle = Instance.new("TextButton")
            afkToggle.Size = UDim2.new(0,60,0,20)
            afkToggle.Position = UDim2.new(0,140,0,10)
            afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
            afkToggle.BackgroundColor3 = Color3.fromRGB(34,177,76)
            afkToggle.TextColor3 = Color3.fromRGB(255,255,255)
            local afkCorner = Instance.new("UICorner") afkCorner.Parent = afkToggle
            afkToggle.Parent = frame
            afkToggle.MouseButton1Click:Connect(function()
                SETTINGS.antiAfk = not SETTINGS.antiAfk
                afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
                pcall(SaveSettings)
                if SETTINGS.antiAfk then pcall(enableAntiAfk) else pcall(disableAntiAfk) end
            end)
            styleButton(afkToggle)
            -- Emote selector / play (Overview)
            local emoteLabel = Instance.new("TextLabel")
            emoteLabel.Size = UDim2.new(0,120,0,20)
            emoteLabel.Position = UDim2.new(0,10,0,40)
            emoteLabel.Text = "Emote (asset id)"
            emoteLabel.TextColor3 = Color3.new(1,1,1)
            emoteLabel.BackgroundTransparency = 1
            emoteLabel.Parent = frame

            local emoteBox = Instance.new("TextBox")
            emoteBox.Size = UDim2.new(0,160,0,24)
            emoteBox.Position = UDim2.new(0,140,0,38)
            emoteBox.Text = tostring(SETTINGS.emoteId or "")
            emoteBox.PlaceholderText = "9527883498"
            emoteBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
            emoteBox.TextColor3 = Color3.fromRGB(255,255,255)
            local ebCorner = Instance.new("UICorner") ebCorner.Parent = emoteBox
            emoteBox.Parent = frame
            emoteBox.FocusLost:Connect(function()
                SETTINGS.emoteId = tostring(emoteBox.Text or "")
                pcall(SaveSettings)
                if SETTINGS.emoteId and tostring(SETTINGS.emoteId) ~= "" then
                    pcall(function() playEmote(SETTINGS.emoteId) end)
                end
            end)

            local emotePlayBtn = Instance.new("TextButton")
            emotePlayBtn.Size = UDim2.new(0,80,0,24)
            emotePlayBtn.Position = UDim2.new(0,320,0,38)
            emotePlayBtn.Text = "Play"
            emotePlayBtn.BackgroundColor3 = Color3.fromRGB(52,152,219)
            emotePlayBtn.TextColor3 = Color3.fromRGB(255,255,255)
            emotePlayBtn.Parent = frame
            styleButton(emotePlayBtn)

            local emoteStopBtn = Instance.new("TextButton")
            emoteStopBtn.Size = UDim2.new(0,80,0,24)
            emoteStopBtn.Position = UDim2.new(0,408,0,38)
            emoteStopBtn.Text = "Stop"
            emoteStopBtn.BackgroundColor3 = Color3.fromRGB(192,57,43)
            emoteStopBtn.TextColor3 = Color3.fromRGB(255,255,255)
            emoteStopBtn.Parent = frame
            styleButton(emoteStopBtn)

            local presetToggle = Instance.new("TextButton")
            presetToggle.Size = UDim2.new(0,24,0,24)
            presetToggle.Position = UDim2.new(0,404,0,38)
            presetToggle.Text = "▾"
            presetToggle.BackgroundColor3 = Color3.fromRGB(40,40,40)
            presetToggle.TextColor3 = Color3.fromRGB(255,255,255)
            presetToggle.Parent = frame
            styleButton(presetToggle)

            local presetFrame = Instance.new("Frame")
            presetFrame.Position = UDim2.new(0,140,0,66)
            presetFrame.BackgroundTransparency = 0.15
            presetFrame.Visible = false
            presetFrame.Parent = frame
            local pfCorner = Instance.new("UICorner") pfCorner.Parent = presetFrame

            local presetEmotes = {
                { name = "Annyeong", id = "9527883498" },
                { name = "Side To Side", id = "10714366910" },
                { name = "Twirl", id = "10714293450" },
                { name = "Uprise", id = "10275008655" },
                { name = "Victory", id = "10714171628" },
                { name = "Block Partier", id = "10713988674" },
                { name = "Shy", id = "10714369325" },
            }
            presetFrame.Size = UDim2.new(0,160,0, 28 * #presetEmotes)
            local function closePreset()
                presetFrame.Visible = false
            end
            presetToggle.MouseButton1Click:Connect(function()
                presetFrame.Visible = not presetFrame.Visible
            end)

            for i, p in ipairs(presetEmotes) do
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, -8, 0, 24)
                b.Position = UDim2.new(0, 4, 0, (i-1)*28)
                b.Text = (p.name .. " — " .. tostring(p.id))
                b.BackgroundColor3 = Color3.fromRGB(36,36,36)
                b.TextColor3 = Color3.fromRGB(230,230,230)
                b.Parent = presetFrame
                styleButton(b)
                b.MouseButton1Click:Connect(function()
                    emoteBox.Text = tostring(p.id)
                    SETTINGS.emoteId = tostring(p.id)
                    pcall(SaveSettings)
                    closePreset()
                end)
            end

            -- emote playback helper
            local currentEmoteTrack = nil
            local function stopEmote()
                if currentEmoteTrack then
                    pcall(function() currentEmoteTrack:Stop() end)
                    pcall(function() currentEmoteTrack:Destroy() end)
                    currentEmoteTrack = nil
                end
                SETTINGS.emotePlaying = false
                pcall(SaveSettings)
            end

            local function playEmote(id)
                if not id or tostring(id) == "" then return false end
                local ok, char = pcall(function() return LocalPlayer.Character end)
                if not ok or not char then
                    return false
                end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum then return false end
                -- ensure Animator exists (some rigs may be missing one initially)
                local animator = hum:FindFirstChildOfClass("Animator")
                if not animator then
                    pcall(function()
                        animator = Instance.new("Animator")
                        animator.Parent = hum
                    end)
                end
                pcall(function()
                    if currentEmoteTrack then
                        pcall(function() currentEmoteTrack:Stop() end)
                        pcall(function() currentEmoteTrack:Destroy() end)
                        currentEmoteTrack = nil
                    end
                    local anim = Instance.new("Animation")
                    anim.AnimationId = ("rbxassetid://%s"):format(tostring(id))
                    local track = nil
                    if animator and animator.LoadAnimation then
                        track = animator:LoadAnimation(anim)
                    else
                        track = hum:LoadAnimation(anim)
                    end
                    if track then
                        pcall(function()
                            track.Priority = Enum.AnimationPriority.Action
                            track.Looped = true
                            currentEmoteTrack = track
                            task.wait(0.05)
                            track:Play()
                        end)
                        SETTINGS.emotePlaying = true
                        pcall(SaveSettings)
                    end
                end)
            end
            emotePlayBtn.MouseButton1Click:Connect(function()
                local id = tostring(emoteBox.Text or "")
                if id and id ~= "" then pcall(function() playEmote(id) end) end
            end)
            emoteStopBtn.MouseButton1Click:Connect(function()
                pcall(function() stopEmote() end)
            end)

            -- Auto-play emote on UI/script execution if an emote is selected
            pcall(function()
                if SETTINGS.emoteId and tostring(SETTINGS.emoteId) ~= "" then
                    local function attemptPlay()
                        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if not hum then
                            for i=1,20 do
                                hum = char:FindFirstChildOfClass("Humanoid")
                                if hum then break end
                                task.wait(0.05)
                            end
                        end
                        pcall(function() playEmote(SETTINGS.emoteId) end)
                    end
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                        pcall(attemptPlay)
                    else
                        LocalPlayer.CharacterAdded:Connect(function()
                            task.wait(0.5)
                            pcall(attemptPlay)
                        end)
                    end
                end
            end)
        end

        -- Server-Hop tab
        do
            local frame = tabFrames.ServerHop
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0,200,0,20)
            label.Position = UDim2.new(0,10,0,10)
            label.Text = "Server Stay Time (minutes)"
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.new(1,1,1)
            label.Parent = frame

            local timeBox = Instance.new("TextBox")
            timeBox.Size = UDim2.new(0,100,0,24)
            timeBox.Position = UDim2.new(0,220,0,8)
            timeBox.Text = tostring(serverStayTime)
            timeBox.Parent = frame
            timeBox.FocusLost:Connect(function(enter)
                local n = tonumber(timeBox.Text)
                if n and n >= 1 and n <= 180 then serverStayTime = math.floor(n) end
                timeBox.Text = tostring(serverStayTime)
                if SETTINGS.persistToggles then pcall(SaveSettings) end
            end)

            local rangeLabel = Instance.new("TextLabel")
            rangeLabel.Size = UDim2.new(0,140,0,20)
            rangeLabel.Position = UDim2.new(0,10,0,48)
            rangeLabel.Text = "Hop Range (1-23P)"
            rangeLabel.BackgroundTransparency = 1
            rangeLabel.TextColor3 = Color3.new(1,1,1)
            rangeLabel.Parent = frame

            local rangeBox = Instance.new("TextBox")
            rangeBox.Size = UDim2.new(0,160,0,28)
            rangeBox.Position = UDim2.new(0,140,0,44)
            rangeBox.Text = hopRangeText or "1-23"
            rangeBox.PlaceholderText = "1-23 or 23"
            rangeBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
            rangeBox.TextColor3 = Color3.fromRGB(255,255,255)
            local rbCorner = Instance.new("UICorner")
            rbCorner.Parent = rangeBox
            rangeBox.Parent = frame
            rangeBox.FocusLost:Connect(function()
                local txt = tostring(rangeBox.Text or "")
                local lowered = txt:lower():gsub("%s+", "")
                if lowered == "any" or lowered == "" then
                    hopRangeText = txt
                    pcall(SaveSettings)
                    return
                end
                local mn,mx = parseRange(txt)
                if not mn then
                    notify("Server Hop", "Invalid range format. Use N or MIN-MAX or 'any' e.g. 23 or 11-22", 4)
                    rangeBox.Text = hopRangeText or "19-22"
                    return
                end
                hopRangeText = txt
                pcall(SaveSettings)
            end)

            local hopBtn = Instance.new("TextButton")
            hopBtn.Size = UDim2.new(0,200,0,40)
            hopBtn.Position = UDim2.new(0,10,0,112)
            hopBtn.Text = "Server Hop Now"
            hopBtn.BackgroundColor3 = Color3.fromRGB(34,177,76)
            hopBtn.TextColor3 = Color3.fromRGB(255,255,255)
            local hCorner = Instance.new("UICorner")
            hCorner.Parent = hopBtn
            hopBtn.Parent = frame
            styleButton(hopBtn)
            hopBtn.MouseButton1Click:Connect(function()
                local txt = (rangeBox and tostring(rangeBox.Text) or hopRangeText) or ""
                local mn, mx = nil, nil
                local lowered = (txt or ""):lower():gsub("%s+", "")
                if lowered == "any" or lowered == "" then
                    mn, mx = nil, nil
                else
                    mn, mx = parseRange(txt)
                    if not mn then
                        notify("Server Hop", "Invalid hop range (use N, MIN-MAX or 'any').", 4)
                        return
                    end
                end
                hopRangeText = txt
                pcall(SaveSettings)
                -- Start aggressive search loop (non-toggle). Button disabled during search.
                pcall(function() hopBtn.Active = false; hopBtn.Text = "Searching..." end)
                manualHopTask = task.spawn(function()
                    while true do
                        local ok = serverSearchAttempt(mn, mx, true)
                        if ok then break end
                        task.wait(0.5)
                    end
                    pcall(function() hopBtn.Active = true; hopBtn.Text = "Server Hop Now" end)
                end)
            end)

            local autoLabel = Instance.new("TextLabel")
            autoLabel.Size = UDim2.new(0,120,0,20)
            autoLabel.Position = UDim2.new(0,10,0,160)
            autoLabel.Text = "Auto Server Hop"
            autoLabel.BackgroundTransparency = 1
            autoLabel.TextColor3 = Color3.new(1,1,1)
            autoLabel.Parent = frame

            local autoToggle = Instance.new("TextButton")
            autoToggle.Size = UDim2.new(0,60,0,20)
            autoToggle.Position = UDim2.new(0,140,0,160)
            autoToggle.Text = autoServerHopEnabled and "ON" or "OFF"
            autoToggle.BackgroundColor3 = Color3.fromRGB(34,177,76)
            autoToggle.TextColor3 = Color3.fromRGB(255,255,255)
            local atCorner = Instance.new("UICorner")
            atCorner.Parent = autoToggle
            autoToggle.Parent = frame
            styleButton(autoToggle)
            autoToggle.MouseButton1Click:Connect(function()
                autoServerHopEnabled = not autoServerHopEnabled
                autoToggle.Text = autoServerHopEnabled and "ON" or "OFF"
                pcall(SaveSettings)
                if autoServerHopEnabled and not autoServerHopTask then
                    autoServerHopTask = task.spawn(function()
                        while autoServerHopEnabled do
                            local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                            notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                            task.wait(waitTime)
                                if not autoServerHopEnabled then break end
                                local txt = hopRangeText or "19-22"
                                local mn, mx = parseRange(txt)
                                if mn then serverHopNow(mn, mx, true) end
                        end
                        autoServerHopTask = nil
                    end)
                end
            end)
        end

        -- Settings tab removed per user request

        -- Webhook tab
        do
            local frame = tabFrames.Webhook
            local whLabel = Instance.new("TextLabel")
            whLabel.Size = UDim2.new(0,120,0,20)
            whLabel.Position = UDim2.new(0,10,0,10)
            whLabel.Text = "Webhook Enabled"
            whLabel.BackgroundTransparency = 1
            whLabel.TextColor3 = Color3.new(1,1,1)
            whLabel.Parent = frame

            local whToggle = Instance.new("TextButton")
            whToggle.Size = UDim2.new(0,60,0,20)
            whToggle.Position = UDim2.new(0,140,0,10)
            whToggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
            whToggle.Parent = frame
            whToggle.BackgroundColor3 = Color3.fromRGB(34,177,76)
            styleButton(whToggle)
            whToggle.MouseButton1Click:Connect(function()
                SETTINGS.webhookToggle = not SETTINGS.webhookToggle
                whToggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
                if SETTINGS.webhookToggle then startDonationMonitor() else stopDonationMonitor() end
                pcall(SaveSettings)
            end)

            local urlBox = Instance.new("TextBox")
            urlBox.Size = UDim2.new(1, -20, 0, 24)
            urlBox.Position = UDim2.new(0,10,0,40)
            urlBox.Text = SETTINGS.webhookUrl
            urlBox.PlaceholderText = "https://discord.com/api/webhooks..."
            urlBox.Parent = frame
            urlBox.FocusLost:Connect(function()
                SETTINGS.webhookUrl = tostring(urlBox.Text or "")
                pcall(SaveSettings)
            end)

            -- donation stat name textbox removed per user request
        end

        -- Fade-in removed per user request (UI should appear immediately)

        if SETTINGS.webhookToggle then
            startDonationMonitor()
            pcall(function()
                local playersOnline = tostring(#Players:GetPlayers())
                local range = tostring(hopRangeText or "any")
                postWebhookEvent("serverhop", { user = tostring(LocalPlayer and LocalPlayer.Name or "Unknown"), players = playersOnline, range = range, auto = autoServerHopEnabled })
            end)
        end
        -- If user requested persistence across hops, ensure queue_on_teleport is set now
        pcall(function()
            if SETTINGS.persistToggles then
                local ok2, cfgJson = pcall(function()
                    return Http:JSONEncode({
                        webhookToggle = SETTINGS.webhookToggle,
                        webhookUrl = SETTINGS.webhookUrl,
                        antiAfk = SETTINGS.antiAfk,
                        serverStayTime = SETTINGS.serverStayTime,
                        persistToggles = SETTINGS.persistToggles,
                        emoteId = SETTINGS.emoteId,
                        emotePlaying = SETTINGS.emotePlaying and true or false,
                        autoServerHop = autoServerHopEnabled,
                    })
                end)
                local qcore = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua"))()'
                local qcode = qcore
                if ok2 and cfgJson then
                    qcode = ("(function() local _json = %q; local ok,cfg = pcall(function() return game:GetService('HttpService'):JSONDecode(_json) end); if ok and type(cfg)=='table' then _G.__PLS_WAIT_CONFIG = cfg end; local f,err = loadstring(game:HttpGet('https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/pls_wait.lua')); if f then pcall(f) else warn(err) end end)()"):format(cfgJson)
                end
                pcall(function() queueOnTeleport(qcode) end)
            end
        end)
        -- Ensure claim runs after teleports/character spawn
        pcall(function()
            if LocalPlayer and LocalPlayer.Character then
                pcall(function() claimBooth() end)
            end
            LocalPlayer.CharacterAdded:Connect(function()
                task.wait(1)
                pcall(function() claimBooth() end)
            end)
        end)
        if SETTINGS.antiAfk then pcall(enableAntiAfk) end
        if autoServerHopEnabled and not autoServerHopTask then
            autoServerHopTask = task.spawn(function()
                while autoServerHopEnabled do
                    local waitTime = tonumber(serverStayTime) and (tonumber(serverStayTime) * 60) or 1800
                    notify("Auto Server Hop", ("Next hop in %d minutes"):format(math.floor(waitTime/60)), 5)
                    task.wait(waitTime)
                    local txt = hopRangeText or "19-22"
                    local mn, mx = parseRange(txt)
                    if mn then serverHopNow(mn, mx, true) end
                end
                autoServerHopTask = nil
            end)
        end
    end
end

-- Script loaded: use functions directly (not returning a module table)
-- Auto-run a single claim on script execution
-- Script loaded: use functions directly (not returning a module table)
-- Auto-run handled by UI initialization above (avoid duplicate claims)
