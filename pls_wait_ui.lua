local UI = {}

function UI.create(dependencies)
    assert(type(dependencies) == "table", "UI dependencies are required")
    local LocalPlayer = assert(dependencies.LocalPlayer, "LocalPlayer is required")
    local Players = assert(dependencies.Players, "Players is required")
    local ReplicatedStorage = assert(dependencies.ReplicatedStorage, "ReplicatedStorage is required")
    local HttpService = assert(dependencies.HttpService, "HttpService is required")
    local UserInputService = assert(dependencies.UserInputService, "UserInputService is required")
    local SETTINGS = assert(dependencies.settings, "settings table is required")
    local ConfigModule = assert(dependencies.ConfigModule, "config module is required")
    local SpinFeature = assert(dependencies.SpinFeature, "spin feature is required")
    local DEFAULT_BOOTH_TEXT = assert(dependencies.defaultBoothText, "default booth text is required")
    local notify = assert(dependencies.notify, "notification function is required")
    local parseAmount = assert(dependencies.parseAmount, "amount parser is required")
    local parseRangeGlobal = assert(dependencies.parseRangeGlobal, "range parser is required")
    local claimBooth = assert(dependencies.claimBooth, "booth claim function is required")
    local getCurrentDonationStat = assert(dependencies.getCurrentDonationStat, "donation stat getter is required")
    local disableAntiAfk = assert(dependencies.disableAntiAfk, "anti-AFK disable function is required")
    local enableAntiAfk = assert(dependencies.enableAntiAfk, "anti-AFK enable function is required")
    local ensureQueuedScript = assert(dependencies.ensureQueuedScript, "teleport queue function is required")
    local postWebhookEvent = assert(dependencies.postWebhookEvent, "webhook function is required")
    local resolveDonationDonor = assert(dependencies.resolveDonationDonor, "donor resolver is required")
    local sendPlainWebhook = assert(dependencies.sendPlainWebhook, "plain webhook function is required")
    local serverHopNow = assert(dependencies.serverHopNow, "server-hop function is required")
    local serverSearchAttempt = assert(dependencies.serverSearchAttempt, "server-search function is required")
    local simulateTouchTapPulse = assert(dependencies.simulateTouchTapPulse, "touch pulse function is required")
    local startDonationMonitor = assert(dependencies.startDonationMonitor, "donation monitor starter is required")
    local stopDonationMonitor = assert(dependencies.stopDonationMonitor, "donation monitor stop function is required")

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
            local ConfigStore = ConfigModule.create({
                HttpService = Http,
                settings = SETTINGS,
                path = CONFIG_PATH,
                readFile = readfile or (syn and syn.read_file),
                writeFile = writefile or (syn and syn.write_file),
                isFile = isfile,
                getRuntimeState = function()
                    return {
                        hopRange = hopRangeText,
                        serverStayTime = serverStayTime,
                        autoServerHop = autoServerHopEnabled,
                        goalBarEnabled = SETTINGS.goalBarEnabled,
                        goalBarTarget = SETTINGS.goalBarTarget,
                    }
                end,
                applyRuntimeState = function(decoded)
                    hopRangeText = decoded.hopRange or hopRangeText
                    serverStayTime = tonumber(decoded.serverStayTime) or serverStayTime
                    if decoded.autoServerHop ~= nil then
                        autoServerHopEnabled = decoded.autoServerHop
                    end
                    if decoded.goalBarEnabled ~= nil then SETTINGS.goalBarEnabled = decoded.goalBarEnabled end
                    SETTINGS.goalBarTarget = tonumber(decoded.goalBarTarget) or SETTINGS.goalBarTarget
                end,
            })

            local function SaveSettings()
                SETTINGS.hopRange = hopRangeText
                local saved, saveError = ConfigStore.save()
                if not saved then
                    warn("[PLS WAIT] Could not save settings:", saveError)
                end
            end

            local function LoadSettings()
                local loaded, loadError = ConfigStore.load()
                if loaded then
                    print("[PLS WAIT] Settings loaded successfully from " .. CONFIG_PATH .. ".")
                elseif loadError == "not-found" then
                    print("[PLS WAIT] No saved settings found; using defaults.")
                else
                    warn("[PLS WAIT] Could not load saved settings:", loadError)
                end
            end

            pcall(function()
                if type(_G) == "table" and type(_G.__PLS_WAIT_CONFIG) == "table" then
                    local cfg = _G.__PLS_WAIT_CONFIG
                    if cfg.webhookToggle ~= nil then SETTINGS.webhookToggle = cfg.webhookToggle end
                    SETTINGS.webhookUrl = cfg.webhookUrl or SETTINGS.webhookUrl
                    if cfg.antiAfk ~= nil then SETTINGS.antiAfk = cfg.antiAfk end
                    if cfg.touchPreventAFK ~= nil then SETTINGS.touchPreventAFK = cfg.touchPreventAFK end
                    serverStayTime = tonumber(cfg.serverStayTime) or serverStayTime
                    if cfg.persistToggles ~= nil then SETTINGS.persistToggles = cfg.persistToggles end
                    if cfg.spinSet ~= nil then SETTINGS.spinSet = cfg.spinSet end
                    if cfg.spinOnDonation ~= nil then SETTINGS.spinSet = cfg.spinOnDonation end
                    if cfg.spinSpeedMultiplier ~= nil then SETTINGS.spinSpeedMultiplier = cfg.spinSpeedMultiplier end
                    if cfg.helicopterEnabled ~= nil then SETTINGS.helicopterEnabled = cfg.helicopterEnabled end
                    if cfg.populationHopper ~= nil then SETTINGS.populationHopper = cfg.populationHopper end
                    if cfg.populationThreshold ~= nil then SETTINGS.populationThreshold = cfg.populationThreshold end
                    if cfg.goalBarEnabled ~= nil then SETTINGS.goalBarEnabled = cfg.goalBarEnabled end
                    if cfg.goalBarTarget ~= nil then SETTINGS.goalBarTarget = tonumber(cfg.goalBarTarget) end
                    -- follow-on-donation setting removed from queued config
                    hopRangeText = cfg.hopRange or hopRangeText
                    SETTINGS.emoteId = cfg.emoteId or SETTINGS.emoteId
                    SETTINGS.boothText = cfg.boothText or SETTINGS.boothText
                    if cfg.staffHop ~= nil then SETTINGS.staffHop = cfg.staffHop end
                    if cfg.friendHop ~= nil then SETTINGS.friendHop = cfg.friendHop end
                    if cfg.chatAutoThankYou ~= nil then SETTINGS.chatAutoThankYou = cfg.chatAutoThankYou end
                    if cfg.thankYouMessages ~= nil and type(cfg.thankYouMessages) == "table" then SETTINGS.thankYouMessages = cfg.thankYouMessages end
                    if cfg.autoServerHop ~= nil then autoServerHopEnabled = cfg.autoServerHop end
                    -- legacy spin settings ignored from queued config
                    _G.__PLS_WAIT_CONFIG = nil
                end
            end)

            LoadSettings()
            -- (initialization guard will be checked after SharedEnv is defined)
            local TweenService = game:GetService("TweenService")
            -- Provide a small UI helper used by buttons
            local function styleButton(btn, accentColor)
                if not btn then return end
                pcall(function()
                    btn.AutoButtonColor = false
                    btn.Font = Enum.Font.GothamBold
                    btn.TextSize = math.max(btn.TextSize, 15)
                    local base = btn.BackgroundColor3
                    local accent = accentColor or Color3.fromRGB(92, 255, 172)
                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0,8)
                    corner.Parent = btn
                    local stroke = Instance.new("UIStroke")
                    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    stroke.Thickness = 1
                    stroke.Color = Color3.fromRGB(30,30,30)
                    stroke.Parent = btn
                    -- Simplified tap feedback: subtle tint without bright green overlay
                    btn.MouseButton1Down:Connect(function()
                        pcall(function() btn.BackgroundColor3 = base:Lerp(Color3.fromRGB(255,255,255), 0.04) end)
                    end)
                    btn.MouseButton1Up:Connect(function()
                        pcall(function() btn.BackgroundColor3 = base end)
                    end)
                    btn.MouseEnter:Connect(function()
                        pcall(function() btn.BackgroundColor3 = base:Lerp(Color3.fromRGB(255,255,255), 0.04) end)
                    end)
                    btn.MouseLeave:Connect(function()
                        pcall(function() btn.BackgroundColor3 = base end)
                    end)
                end)
            end

            local function styleFeatureLabel(label)
                label.Font = Enum.Font.GothamMedium
                label.TextSize = 15
                label.TextWrapped = true
                label.TextColor3 = Color3.fromRGB(235, 240, 245)
            end

            local ensureSpinPart = SpinFeature.ensureSpinPart

            -- Prevent duplicate UIs across teleports / multiple runs: use a shared env flag
            local SharedEnv = (type(getgenv) == "function" and getgenv()) or _G
            -- If the script was already initialized elsewhere, allow re-init (some executors persist getgenv across teleports)
            if SharedEnv.PLS_WAIT_SCRIPT_LOADED then
                -- clear previous marker and allow re-initialization so UI reliably appears after queue_on_teleport
                pcall(function() SharedEnv.PLS_WAIT_SCRIPT_LOADED = nil end)
            end
            SharedEnv.PLS_WAIT_SCRIPT_LOADED = true
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

            -- Mini toggle button for open/close (persistent, outside mainFrame)
            local uiToggle = Instance.new("ImageButton")
            uiToggle.Name = "PlsWaitToggle"
            uiToggle.Size = UDim2.new(0, 48, 0, 48)
            uiToggle.Position = UDim2.new(0, 8, 0, 8)
            uiToggle.AnchorPoint = Vector2.new(0,0)
            uiToggle.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
            uiToggle.BackgroundTransparency = 0
            uiToggle.BorderSizePixel = 0
            uiToggle.Image = ""
            uiToggle.Parent = screen
            local togCorner = Instance.new("UICorner")
            togCorner.CornerRadius = UDim.new(0.5, 0)
            togCorner.Parent = uiToggle
            local togGradient = Instance.new("UIGradient")
            togGradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(23, 31, 45)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 61, 119)),
            }
            togGradient.Rotation = 90
            togGradient.Parent = uiToggle
            local togStroke = Instance.new("UIStroke")
            togStroke.Color = Color3.fromRGB(14, 17, 23)
            togStroke.Thickness = 1
            togStroke.Parent = uiToggle
            local togLabel = Instance.new("TextLabel")
            togLabel.Text = "PLS WAIT"
            togLabel.Size = UDim2.new(1, -8, 1, -8)
            togLabel.Position = UDim2.new(0, 4, 0, 4)
            togLabel.BackgroundTransparency = 1
            togLabel.TextColor3 = Color3.fromRGB(242, 242, 242)
            togLabel.Font = Enum.Font.GothamBold
            togLabel.TextScaled = true
            togLabel.TextWrapped = true
            togLabel.TextYAlignment = Enum.TextYAlignment.Center
            togLabel.TextXAlignment = Enum.TextXAlignment.Center
            togLabel.Parent = uiToggle
            uiToggle.Visible = true

            -- Glassy admin-panel style layout (smaller width for compact UI)
            local MAIN_W, MAIN_H = 600, 420
            local LEFT_W = 180
            local GAP = 16
            local mainFrame = Instance.new("Frame")
            mainFrame.Name = "MainFrame"
            mainFrame.Size = UDim2.new(0, MAIN_W, 0, MAIN_H)
            -- position bottom-left, keep margin and ensure it's visible on mobile
            mainFrame.AnchorPoint = Vector2.new(0, 1)
            mainFrame.Position = UDim2.new(0, 12, 1, -12)
            mainFrame.BackgroundColor3 = Color3.fromRGB(24,24,24)
            mainFrame.BackgroundTransparency = 0
            mainFrame.ClipsDescendants = true
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
            -- Title bar (draggable on PC and mobile)
            local titleBar = Instance.new("Frame")
            titleBar.Name = "TitleBar"
            titleBar.Size = UDim2.new(1, 0, 0, 36)
            titleBar.Position = UDim2.new(0, 0, 0, 0)
            titleBar.BackgroundColor3 = Color3.fromRGB(72, 76, 84)
            titleBar.BackgroundTransparency = 0
            titleBar.Parent = mainFrame
            titleBar.Active = true
            titleBar.ZIndex = 50
            local titleGradient = Instance.new("UIGradient")
            titleGradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 96, 104)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 60, 68)),
            }
            titleGradient.Rotation = 90
            titleGradient.Parent = titleBar
            local titleStroke = Instance.new("UIStroke")
            titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            titleStroke.Color = Color3.fromRGB(38, 40, 46)
            titleStroke.Thickness = 1
            titleStroke.Parent = titleBar
            local titleLblTop = Instance.new("TextLabel")
            titleLblTop.Size = UDim2.new(1, -56, 0, 36)
            titleLblTop.Position = UDim2.new(0, 14, 0, 0)
            titleLblTop.BackgroundTransparency = 1
            titleLblTop.Text = "PLS WAIT 🥳 / 📧 p9sn"
            titleLblTop.Font = Enum.Font.GothamBold
            titleLblTop.TextSize = 16
            titleLblTop.TextColor3 = Color3.fromRGB(240,240,240)
            titleLblTop.TextXAlignment = Enum.TextXAlignment.Left
            titleLblTop.Parent = titleBar

            -- Add a close/minimize button in the title bar
            local closeBtn = Instance.new("TextButton")
            closeBtn.Size = UDim2.new(0, 32, 0, 22)
            closeBtn.Position = UDim2.new(1, -44, 0, 7)
            closeBtn.Text = "−"
            closeBtn.BackgroundColor3 = Color3.fromRGB(64, 68, 76)
            closeBtn.TextColor3 = Color3.fromRGB(240,240,240)
            closeBtn.Font = Enum.Font.GothamBold
            closeBtn.TextSize = 16
            closeBtn.Parent = titleBar
            styleButton(closeBtn)

            -- (dropdown/collapse button removed as it was non-functional)

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
                local originalMainPos = mainFrame.Position
                local minimized = false
                local transitioning = false
                local TweenService = game:GetService("TweenService")
                local dockPosition = UDim2.new(0, 8, 0, 56)
                local transitionInfo = TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)

                local function playTransition(isMinimizing)
                    if transitioning or minimized == isMinimizing then return end
                    transitioning = true

                    if isMinimizing then
                        originalMainPos = mainFrame.Position
                    else
                        mainFrame.Visible = true
                        mainFrame.Position = dockPosition
                        mainFrame.Size = UDim2.new(0, 48, 0, 48)
                        mainFrame.BackgroundTransparency = 0.18
                        titleBar.Size = UDim2.new(1, 0, 0, 0)
                        titleBar.BackgroundTransparency = 1
                        titleLblTop.TextTransparency = 1
                        closeBtn.BackgroundTransparency = 1
                        closeBtn.TextTransparency = 1
                    end

                    local frameTween = TweenService:Create(mainFrame, transitionInfo, {
                        Position = isMinimizing and dockPosition or originalMainPos,
                        Size = isMinimizing and UDim2.new(0, 48, 0, 48) or UDim2.new(0, MAIN_W, 0, MAIN_H),
                        BackgroundTransparency = isMinimizing and 0.18 or 0,
                    })
                    TweenService:Create(titleBar, transitionInfo, {
                        Size = isMinimizing and UDim2.new(1, 0, 0, 0) or UDim2.new(1, 0, 0, 36),
                        BackgroundTransparency = isMinimizing and 1 or 0,
                    }):Play()
                    TweenService:Create(titleLblTop, transitionInfo, {
                        TextTransparency = isMinimizing and 1 or 0,
                    }):Play()
                    TweenService:Create(closeBtn, transitionInfo, {
                        BackgroundTransparency = isMinimizing and 1 or 0,
                        TextTransparency = isMinimizing and 1 or 0,
                    }):Play()
                    frameTween:Play()
                    frameTween.Completed:Connect(function(playbackState)
                        if playbackState == Enum.PlaybackState.Completed then
                            minimized = isMinimizing
                            if isMinimizing then
                                mainFrame.Visible = false
                            end
                        end
                        transitioning = false
                    end)
                end

                local function minimizeUI()
                    playTransition(true)
                end

                local function restoreUI()
                    playTransition(false)
                end

                closeBtn.MouseButton1Click:Connect(function()
                    if minimized then restoreUI() else minimizeUI() end
                end)
                uiToggle.MouseButton1Click:Connect(function()
                    if minimized then restoreUI() else minimizeUI() end
                end)
            end
            local mainCorner = Instance.new("UICorner")
            mainCorner.CornerRadius = UDim.new(0,12)
            mainCorner.Parent = mainFrame

            -- Decorative squiggle layers removed per user request

            -- Left menu column
            local leftCol = Instance.new("Frame")
            leftCol.Name = "LeftCol"
            leftCol.Size = UDim2.new(0, LEFT_W, 1, -20)
            -- lower left column so the titlebar doesn't overlap the first button
            leftCol.Position = UDim2.new(0, GAP, 0, 48)
            leftCol.BackgroundTransparency = 1
            leftCol.Parent = mainFrame
            -- old left-column title removed (we use the draggable title bar)

            -- left menu buttons (use UIListLayout for stable layout)
            local leftList = Instance.new("UIListLayout")
            leftList.SortOrder = Enum.SortOrder.LayoutOrder
            leftList.Padding = UDim.new(0, 12)
            leftList.HorizontalAlignment = Enum.HorizontalAlignment.Center
            leftList.VerticalAlignment = Enum.VerticalAlignment.Top
            leftList.Parent = leftCol

            local menu = { {key="Booth", text="Booth"}, {key="Main", text="Main"}, {key="ServerHop", text="Server Hop"}, {key="Webhook", text="Webhook"}, {key="Chat", text="Chat"} }
            local tabButtons = {}
            local tabFrames = {}
            for i, item in ipairs(menu) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -12, 0, 40)
                btn.LayoutOrder = i
                btn.Text = item.text
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 15
                btn.TextColor3 = Color3.fromRGB(220,220,220)
                btn.TextXAlignment = Enum.TextXAlignment.Center
                btn.BackgroundColor3 = Color3.fromRGB(28,28,28)
                btn.AutoButtonColor = false
                local corner = Instance.new("UICorner") corner.Parent = btn
                btn.Parent = leftCol
                styleButton(btn, Color3.fromRGB(78, 214, 120))
                tabButtons[item.key] = btn

                local frame = Instance.new("Frame")
                local rightW = MAIN_W - LEFT_W - (GAP * 2)
                frame.Size = UDim2.new(0, rightW, 1, -24)
                -- right-side frames aligned below titlebar
                frame.Position = UDim2.new(0, LEFT_W + GAP, 0, 48)
                frame.BackgroundTransparency = 1
                frame.Visible = (item.key == "Main")
                frame.Parent = mainFrame
                tabFrames[item.key] = frame
            end

            -- close button removed (dropdown provides collapse/close behavior)

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
                for k, btn in pairs(tabButtons) do
                    local isActive = (k == name)
                    btn.BackgroundColor3 = isActive and Color3.fromRGB(58, 132, 84) or Color3.fromRGB(28,28,28)
                    btn.TextColor3 = isActive and Color3.fromRGB(255,255,255) or Color3.fromRGB(220,220,220)
                    btn.Font = Enum.Font.GothamBold
                    btn.TextSize = 15
                end
                tabFrames[name].Visible = true
            end
            for name, btn in pairs(tabButtons) do
                btn.MouseButton1Click:Connect(function() selectTab(name) end)
            end
            pcall(function() selectTab("Main") end)

            local function updateBoothText(text, quiet)
                local newText = tostring(text or "")
                if newText == "" then
                    notify("Booth Text", "Enter booth text before saving.", 4)
                    return false
                end
                local remote = ReplicatedStorage:FindFirstChild("UpdateStandText") or ReplicatedStorage:WaitForChild("UpdateStandText", 5)
                if not remote then
                    notify("Booth Text", "UpdateStandText remote not found.", 4)
                    return false
                end
                local ok, res = pcall(function()
                    return remote:InvokeServer(newText)
                end)
                if not ok then
                    notify("Booth Text", "Save failed: " .. tostring(res), 5)
                    return false
                end
                if not quiet then
                    notify("Booth Text", "Booth text saved.", 4)
                end
                return true
            end

            local function getLocalRaisedValue()
                local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                local raised = leaderstats and (leaderstats:FindFirstChild("Raised") or leaderstats:FindFirstChild("raised"))
                local donationStat = getCurrentDonationStat()
                if not raised and donationStat and donationStat.Parent then
                    raised = donationStat
                end
                if not raised or raised.Value == nil then
                    return nil
                end
                return parseAmount(raised.Value)
            end

            local function formatCompactGoal(target)
                local divisor, suffix
                if target >= 1000000 then
                    divisor, suffix = 1000000, "M"
                elseif target >= 1000 then
                    divisor, suffix = 1000, "K"
                else
                    return tostring(target)
                end
                local scaled = target / divisor
                if scaled % 1 == 0 then
                    return ("%d%s"):format(scaled, suffix)
                end
                return ("%.1f%s"):format(scaled, suffix)
            end

            local function formatGoalBar(raisedValue, target)
                local barCount = 27
                local progress = math.clamp(raisedValue / target, 0, 1)
                local filledCount = math.floor(progress * barCount)
                return ("<font color='rgb(30,144,255)' face='LuckiestGuy'>GOAL %s</font><br /><stroke thickness='6' color='rgb(0,0,0)'><font size='17' face='GothamBlack'><font color='rgb(0,255,0)'>%s</font><font color='rgb(0,0,0)'>%s</font></font></stroke>"):format(
                    formatCompactGoal(target),
                    string.rep("|", filledCount),
                    string.rep("|", barCount - filledCount)
                )
            end

            local function hasGoalBarTarget()
                local target = tonumber(SETTINGS.goalBarTarget)
                return SETTINGS.goalBarEnabled and target ~= nil and target > 0
            end

            local function formatBoothText(baseText, raisedValue)
                local sections = {}
                local text = tostring(baseText or "")
                local barTarget = hasGoalBarTarget() and tonumber(SETTINGS.goalBarTarget) or nil
                if text ~= "" then table.insert(sections, text) end
                if barTarget and barTarget > 0 then
                    table.insert(sections, formatGoalBar(raisedValue, barTarget))
                end
                return table.concat(sections, "<br />")
            end
            local publishBoothProgress

            -- Booth tab
            do
                local boothFrame = tabFrames.Booth
                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, -20, 0, 28)
                title.Position = UDim2.new(0, 10, 0, 10)
                title.BackgroundTransparency = 1
                title.Text = "Booth"
                title.TextColor3 = Color3.new(1,1,1)
                title.Font = Enum.Font.GothamBold
                title.TextSize = 18
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.Parent = boothFrame

                local textLabel = Instance.new("TextLabel")
                textLabel.Size = UDim2.new(0, 120, 0, 20)
                textLabel.Position = UDim2.new(0, 10, 0, 50)
                textLabel.Text = "Booth Text"
                textLabel.BackgroundTransparency = 1
                textLabel.TextColor3 = Color3.new(1,1,1)
                textLabel.Font = Enum.Font.GothamMedium
                textLabel.TextSize = 15
                textLabel.Parent = boothFrame

                local boothTextBox = Instance.new("TextBox")
                boothTextBox.Size = UDim2.new(1, -20, 0, 90)
                boothTextBox.Position = UDim2.new(0, 10, 0, 74)
                boothTextBox.Text = tostring(SETTINGS.boothText or DEFAULT_BOOTH_TEXT)
                boothTextBox.PlaceholderText = "Enter booth text here..."
                boothTextBox.TextWrapped = true
                boothTextBox.MultiLine = true
                boothTextBox.ClearTextOnFocus = false
                boothTextBox.Font = Enum.Font.GothamMedium
                boothTextBox.TextSize = 18
                boothTextBox.TextXAlignment = Enum.TextXAlignment.Left
                boothTextBox.TextYAlignment = Enum.TextYAlignment.Top
                boothTextBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
                boothTextBox.TextColor3 = Color3.fromRGB(255,255,255)
                local btbCorner = Instance.new("UICorner") btbCorner.Parent = boothTextBox
                boothTextBox.Parent = boothFrame
                boothTextBox.Focused:Connect(function()
                    boothTextBox.TextSize = 20
                end)
                boothTextBox.FocusLost:Connect(function()
                    boothTextBox.TextSize = 18
                end)

                local saveBtn = Instance.new("TextButton")
                saveBtn.Size = UDim2.new(0, 120, 0, 28)
                saveBtn.Position = UDim2.new(0, 10, 0, 176)
                saveBtn.Text = "Save Text"
                saveBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
                saveBtn.TextColor3 = Color3.new(1,1,1)
                saveBtn.Font = Enum.Font.Gotham
                saveBtn.TextSize = 14
                saveBtn.Parent = boothFrame
                styleButton(saveBtn)
                saveBtn.MouseButton1Click:Connect(function()
                    local text = tostring(boothTextBox.Text or "")
                    SETTINGS.boothText = text
                    pcall(SaveSettings)
                    local raisedValue = getLocalRaisedValue()
                    if raisedValue ~= nil and publishBoothProgress then
                        publishBoothProgress(raisedValue)
                    else
                        pcall(updateBoothText, text)
                    end
                end)

                local goalBarLabel = Instance.new("TextLabel")
                goalBarLabel.Size = UDim2.new(1, -20, 0, 20)
                goalBarLabel.Position = UDim2.new(0, 10, 0, 218)
                goalBarLabel.BackgroundTransparency = 1
                goalBarLabel.TextColor3 = Color3.new(1, 1, 1)
                goalBarLabel.Font = Enum.Font.GothamBold
                goalBarLabel.TextSize = 15
                goalBarLabel.TextXAlignment = Enum.TextXAlignment.Left
                goalBarLabel.Text = SETTINGS.goalBarEnabled and "Raised Goal Bar" or "Raised Goal Bar (independent)"
                goalBarLabel.Parent = boothFrame

                local goalBarTargetBox = Instance.new("TextBox")
                goalBarTargetBox.Size = UDim2.new(0, 120, 0, 26)
                goalBarTargetBox.Position = UDim2.new(0, 10, 0, 244)
                goalBarTargetBox.Text = tostring(SETTINGS.goalBarTarget or 40000)
                goalBarTargetBox.PlaceholderText = "e.g. 40000"
                goalBarTargetBox.ClearTextOnFocus = false
                goalBarTargetBox.Font = Enum.Font.GothamMedium
                goalBarTargetBox.TextSize = 16
                goalBarTargetBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                goalBarTargetBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                goalBarTargetBox.Parent = boothFrame
                local goalBarBoxCorner = Instance.new("UICorner")
                goalBarBoxCorner.Parent = goalBarTargetBox

                local setGoalBarButton = Instance.new("TextButton")
                setGoalBarButton.Size = UDim2.new(0, 130, 0, 26)
                setGoalBarButton.Position = UDim2.new(0, 140, 0, 244)
                setGoalBarButton.Text = "Set Bar Goal"
                setGoalBarButton.BackgroundColor3 = Color3.fromRGB(50, 95, 145)
                setGoalBarButton.TextColor3 = Color3.new(1, 1, 1)
                setGoalBarButton.Parent = boothFrame
                styleButton(setGoalBarButton)

                local goalBarToggle = Instance.new("TextButton")
                goalBarToggle.Size = UDim2.new(0, 90, 0, 26)
                goalBarToggle.Position = UDim2.new(0, 280, 0, 244)
                goalBarToggle.Text = SETTINGS.goalBarEnabled and "ON" or "OFF"
                goalBarToggle.BackgroundColor3 = SETTINGS.goalBarEnabled and Color3.fromRGB(46, 128, 76) or Color3.fromRGB(70, 70, 70)
                goalBarToggle.TextColor3 = Color3.new(1, 1, 1)
                goalBarToggle.Parent = boothFrame
                styleButton(goalBarToggle)

                local goalMonitorRunning = false
                local lastGoalRaised = nil

                publishBoothProgress = function(raisedValue)
                    local barTarget = tonumber(SETTINGS.goalBarTarget)
                    local finalText = formatBoothText(SETTINGS.boothText, raisedValue)
                    local updated = updateBoothText(finalText, true)
                    if updated then
                        if hasGoalBarTarget() and barTarget and barTarget > 0 then
                            goalBarLabel.Text = ("Raised Goal Bar — %s / %s"):format(tostring(raisedValue), tostring(barTarget))
                        else
                            goalBarLabel.Text = "Raised Goal Bar (independent)"
                        end
                        lastGoalRaised = raisedValue
                    end
                    return updated
                end

                local function startGoalMonitor()
                    if goalMonitorRunning or not hasGoalBarTarget() then
                        return
                    end
                    goalMonitorRunning = true
                    task.spawn(function()
                        while hasGoalBarTarget() do
                            task.wait(1)
                            local raisedValue = getLocalRaisedValue()
                            if raisedValue ~= nil and raisedValue ~= lastGoalRaised then
                                publishBoothProgress(raisedValue)
                            end
                        end
                        goalMonitorRunning = false
                    end)
                end

                setGoalBarButton.MouseButton1Click:Connect(function()
                    local amount = tonumber(goalBarTargetBox.Text)
                    if not amount or amount <= 0 or amount % 1 ~= 0 then
                        notify("Raised Goal Bar", "Enter a positive whole-number Robux goal.", 5)
                        return
                    end

                    SETTINGS.goalBarTarget = amount
                    goalBarTargetBox.Text = tostring(amount)
                    lastGoalRaised = nil
                    pcall(SaveSettings)
                    local raisedValue = getLocalRaisedValue()
                    if raisedValue ~= nil then
                        publishBoothProgress(raisedValue)
                    end
                    startGoalMonitor()
                end)

                goalBarToggle.MouseButton1Click:Connect(function()
                    SETTINGS.goalBarEnabled = not SETTINGS.goalBarEnabled
                    goalBarToggle.Text = SETTINGS.goalBarEnabled and "ON" or "OFF"
                    goalBarToggle.BackgroundColor3 = SETTINGS.goalBarEnabled and Color3.fromRGB(46, 128, 76) or Color3.fromRGB(70, 70, 70)
                    lastGoalRaised = nil
                    pcall(SaveSettings)
                    local raisedValue = getLocalRaisedValue()
                    if raisedValue ~= nil then
                        publishBoothProgress(raisedValue)
                    end
                    startGoalMonitor()
                end)

                if hasGoalBarTarget() then
                    local raisedValue = getLocalRaisedValue()
                    if raisedValue ~= nil then
                        publishBoothProgress(raisedValue)
                    else
                        goalBarLabel.Text = "Raised Goal Bar — waiting for Raised value..."
                    end
                    startGoalMonitor()
                end
            end

            -- Main tab
            do
                local rootFrame = tabFrames.Main
                -- Add a scrollable content area so Overview can fit many controls
                local content = Instance.new("ScrollingFrame")
                content.Name = "OverviewScroll"
                content.Size = UDim2.new(1, -12, 1, -12)
                content.Position = UDim2.new(0, 6, 0, 6)
                content.BackgroundTransparency = 1
                content.ScrollBarThickness = 8
                content.CanvasSize = UDim2.new(0,0,0,800)
                content.Parent = rootFrame
                local frame = content
                -- Claim button removed (auto-claim runs on load/teleport)

                local afkLabel = Instance.new("TextLabel")
                afkLabel.Size = UDim2.new(0,120,0,20)
                afkLabel.Position = UDim2.new(0,10,0,10)
                afkLabel.Text = "Anti-AFK"
                afkLabel.TextColor3 = Color3.new(1,1,1)
                afkLabel.BackgroundTransparency = 1
                afkLabel.Parent = frame
                styleFeatureLabel(afkLabel)

                local afkToggle = Instance.new("TextButton")
                afkToggle.Size = UDim2.new(0,60,0,24)
                afkToggle.Position = UDim2.new(0,140,0,10)
                afkToggle.Text = SETTINGS.antiAfk and "ON" or "OFF"
                afkToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
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

                local touchLabel = Instance.new("TextLabel")
                touchLabel.Size = UDim2.new(0,120,0,20)
                touchLabel.Position = UDim2.new(0,10,0,42)
                touchLabel.Text = "Touch Prevent AFK"
                touchLabel.BackgroundTransparency = 1
                touchLabel.TextColor3 = Color3.new(1,1,1)
                touchLabel.Parent = frame
                styleFeatureLabel(touchLabel)

                local touchToggle = Instance.new("TextButton")
                touchToggle.Size = UDim2.new(0,60,0,24)
                touchToggle.Position = UDim2.new(0,140,0,42)
                touchToggle.Text = SETTINGS.touchPreventAFK and "ON" or "OFF"
                touchToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
                touchToggle.TextColor3 = Color3.fromRGB(255,255,255)
                local ttCorner = Instance.new("UICorner") ttCorner.Parent = touchToggle
                touchToggle.Parent = frame
                touchToggle.MouseButton1Click:Connect(function()
                    SETTINGS.touchPreventAFK = not SETTINGS.touchPreventAFK
                    touchToggle.Text = SETTINGS.touchPreventAFK and "ON" or "OFF"
                    pcall(SaveSettings)
                    if SETTINGS.touchPreventAFK then
                        pcall(function()
                            local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
                            if ok and vu then
                                pcall(function() vu:CaptureController(); if vu.ClickButton2 then vu:ClickButton2(Vector2.new(0,0)) end end)
                            else
                                local char = LocalPlayer.Character
                                if char then
                                    local hum = char:FindFirstChildOfClass("Humanoid")
                                    if hum then hum.Jump = true end
                                end
                            end
                        end)
                    end
                end)
                styleButton(touchToggle)

                local helicopterLabel = Instance.new("TextLabel")
                helicopterLabel.Size = UDim2.new(0, 120, 0, 20)
                helicopterLabel.Position = UDim2.new(0, 10, 0, 78)
                helicopterLabel.Text = "Helicopter"
                helicopterLabel.BackgroundTransparency = 1
                helicopterLabel.TextColor3 = Color3.new(1, 1, 1)
                helicopterLabel.Parent = frame
                styleFeatureLabel(helicopterLabel)

                local helicopterToggle = Instance.new("TextButton")
                helicopterToggle.Size = UDim2.new(0, 60, 0, 24)
                helicopterToggle.Position = UDim2.new(0, 140, 0, 78)
                helicopterToggle.Text = SETTINGS.helicopterEnabled and "ON" or "OFF"
                helicopterToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                helicopterToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
                helicopterToggle.Parent = frame
                local helicopterCorner = Instance.new("UICorner")
                helicopterCorner.Parent = helicopterToggle
                styleButton(helicopterToggle)

                local helicopterStatus = Instance.new("TextLabel")
                helicopterStatus.Size = UDim2.new(0, 172, 0, 24)
                helicopterStatus.Position = UDim2.new(0, 208, 0, 78)
                helicopterStatus.Text = "DOES NOT WORK RN."
                helicopterStatus.BackgroundTransparency = 1
                helicopterStatus.TextColor3 = Color3.fromRGB(255, 75, 75)
                helicopterStatus.Font = Enum.Font.GothamBold
                helicopterStatus.TextSize = 15
                helicopterStatus.TextXAlignment = Enum.TextXAlignment.Left
                helicopterStatus.Parent = frame
                helicopterToggle.MouseButton1Click:Connect(function()
                    SETTINGS.helicopterEnabled = not SETTINGS.helicopterEnabled
                    helicopterToggle.Text = SETTINGS.helicopterEnabled and "ON" or "OFF"
                    SpinFeature.setHelicopterEnabled(SETTINGS.helicopterEnabled)
                    pcall(SaveSettings)
                    if SETTINGS.helicopterEnabled then
                        startDonationMonitor()
                    elseif not SETTINGS.webhookToggle and not SETTINGS.spinSet then
                        stopDonationMonitor()
                    end
                end)

                -- Emote selector / play (Main)
                local emoteLabel = Instance.new("TextLabel")
                emoteLabel.Size = UDim2.new(0,120,0,20)
                emoteLabel.Position = UDim2.new(0,10,0,112)
                emoteLabel.Text = "Emote (asset id)"
                emoteLabel.TextColor3 = Color3.new(1,1,1)
                emoteLabel.BackgroundTransparency = 1
                emoteLabel.Parent = frame
                styleFeatureLabel(emoteLabel)

                local emoteBox = Instance.new("TextBox")
                emoteBox.Size = UDim2.new(0,160,0,24)
                emoteBox.Position = UDim2.new(0,140,0,112)
                emoteBox.Text = tostring(SETTINGS.emoteId or "")
                emoteBox.PlaceholderText = "9527883498"
                emoteBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
                emoteBox.TextColor3 = Color3.fromRGB(255,255,255)
                emoteBox.Font = Enum.Font.GothamMedium
                emoteBox.TextSize = 16
                local ebCorner = Instance.new("UICorner") ebCorner.Parent = emoteBox
                emoteBox.Parent = frame
                emoteBox.FocusLost:Connect(function()
                    SETTINGS.emoteId = tostring(emoteBox.Text or "")
                    pcall(SaveSettings)
                    if SETTINGS.emoteId and tostring(SETTINGS.emoteId) ~= "" then
                        pcall(function() playEmote(SETTINGS.emoteId) end)
                    end
                end)

                local emotePresetBtn = Instance.new("TextButton")
                emotePresetBtn.Size = UDim2.new(0,70,0,24)
                emotePresetBtn.Position = UDim2.new(0,306,0,112)
                emotePresetBtn.Text = "Presets"
                emotePresetBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
                emotePresetBtn.TextColor3 = Color3.fromRGB(255,255,255)
                emotePresetBtn.Parent = frame
                styleButton(emotePresetBtn)

                local emotePlayBtn = Instance.new("TextButton")
                emotePlayBtn.Size = UDim2.new(0,80,0,24)
                emotePlayBtn.Position = UDim2.new(0,140,0,150)
                emotePlayBtn.Text = "Play"
                emotePlayBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
                emotePlayBtn.TextColor3 = Color3.fromRGB(255,255,255)
                emotePlayBtn.Parent = frame
                styleButton(emotePlayBtn)

                local emoteStopBtn = Instance.new("TextButton")
                emoteStopBtn.Size = UDim2.new(0,80,0,24)
                emoteStopBtn.Position = UDim2.new(0,228,0,150)
                emoteStopBtn.Text = "Stop"
                emoteStopBtn.BackgroundColor3 = Color3.fromRGB(100,40,40)
                emoteStopBtn.TextColor3 = Color3.fromRGB(255,255,255)
                emoteStopBtn.Parent = frame
                styleButton(emoteStopBtn)

                local presetFrame = Instance.new("ScrollingFrame")
                presetFrame.Position = UDim2.new(0,140,0,180)
                presetFrame.Size = UDim2.new(0,160,0,110)
                presetFrame.BackgroundTransparency = 0.15
                presetFrame.Visible = false
                presetFrame.ZIndex = 3
                presetFrame.CanvasSize = UDim2.new(0,0,0,0)
                presetFrame.ScrollBarThickness = 6
                presetFrame.ClipsDescendants = true
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
                    { name = "Helicopter", id = "76510079095692" },
                }
                presetFrame.CanvasSize = UDim2.new(0,0,0,28 * #presetEmotes)
                local function closePreset()
                    presetFrame.Visible = false
                end
                emotePresetBtn.MouseButton1Click:Connect(function()
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

                -- Auto-play emote toggle
                local autoEmoteLabel = Instance.new("TextLabel")
                autoEmoteLabel.Size = UDim2.new(0,120,0,20)
                autoEmoteLabel.Position = UDim2.new(0,10,0,220)
                autoEmoteLabel.Text = "Auto-Play Emote"
                autoEmoteLabel.BackgroundTransparency = 1
                autoEmoteLabel.TextColor3 = Color3.new(1,1,1)
                autoEmoteLabel.Parent = frame
                styleFeatureLabel(autoEmoteLabel)

                local autoEmoteToggle = Instance.new("TextButton")
                autoEmoteToggle.Size = UDim2.new(0,60,0,24)
                autoEmoteToggle.Position = UDim2.new(0,140,0,220)
                autoEmoteToggle.Text = SETTINGS.emotePlaying and "ON" or "OFF"
                autoEmoteToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
                autoEmoteToggle.TextColor3 = Color3.fromRGB(255,255,255)
                autoEmoteToggle.Parent = frame
                local aec = Instance.new("UICorner") aec.Parent = autoEmoteToggle
                styleButton(autoEmoteToggle)

                local spinLabel = Instance.new("TextLabel")
                spinLabel.Size = UDim2.new(0,120,0,20)
                spinLabel.Position = UDim2.new(0,10,0,252)
                spinLabel.Text = "Spin On Donation"
                spinLabel.BackgroundTransparency = 1
                spinLabel.TextColor3 = Color3.new(1,1,1)
                spinLabel.Parent = frame
                styleFeatureLabel(spinLabel)

                local spinToggle = Instance.new("TextButton")
                spinToggle.Size = UDim2.new(0,60,0,24)
                spinToggle.Position = UDim2.new(0,140,0,252)
                spinToggle.Text = SETTINGS.spinSet and "ON" or "OFF"
                spinToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
                spinToggle.TextColor3 = Color3.fromRGB(255,255,255)
                spinToggle.Parent = frame
                local stCorner = Instance.new("UICorner") stCorner.Parent = spinToggle
                styleButton(spinToggle)

                local speedLabel = Instance.new("TextLabel")
                speedLabel.Size = UDim2.new(0,160,0,20)
                speedLabel.Position = UDim2.new(0,10,0,282)
                speedLabel.Text = "Spin Speed Multiplier"
                speedLabel.BackgroundTransparency = 1
                speedLabel.TextColor3 = Color3.new(1,1,1)
                speedLabel.Parent = frame
                styleFeatureLabel(speedLabel)

                local speedBox = Instance.new("TextBox")
                speedBox.Size = UDim2.new(0,80,0,20)
                speedBox.Position = UDim2.new(0,140,0,282)
                speedBox.Text = tostring(SETTINGS.spinSpeedMultiplier or 1)
                speedBox.ClearTextOnFocus = false
                speedBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
                speedBox.TextColor3 = Color3.fromRGB(255,255,255)
                speedBox.Font = Enum.Font.GothamMedium
                speedBox.TextSize = 16
                speedBox.TextXAlignment = Enum.TextXAlignment.Left
                speedBox.Parent = frame

                local sCorner = Instance.new("UICorner") sCorner.Parent = speedBox
                styleButton(speedBox)

                spinToggle.MouseButton1Click:Connect(function()
                    SETTINGS.spinSet = not SETTINGS.spinSet
                    spinToggle.Text = SETTINGS.spinSet and "ON" or "OFF"
                    pcall(SaveSettings)
                    if not SETTINGS.spinSet then
                        local char = LocalPlayer.Character
                        if char then
                            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                            if root then
                                if root:FindFirstChild("Spin") then
                                    root:FindFirstChild("Spin"):Destroy()
                                end
                            end
                        end
                        if not SETTINGS.webhookToggle and not SETTINGS.helicopterEnabled then
                            stopDonationMonitor()
                        end
                    else
                        pcall(function()
                            local char = LocalPlayer.Character
                            if char then
                                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                                if root and not root:FindFirstChild("Spin") then
                                    local spinPart = Instance.new("BodyAngularVelocity")
                                    spinPart.Name = "Spin"
                                    spinPart.MaxTorque = Vector3.new(0, math.huge, 0)
                                    spinPart.Parent = root
                                    spinPart.AngularVelocity = Vector3.new(0, 0.25 * (SETTINGS.spinSpeedMultiplier or 1), 0)
                                end
                            end
                        end)
                        startDonationMonitor()
                    end
                end)

                speedBox.FocusLost:Connect(function(enter)
                    local value = tonumber(speedBox.Text)
                    if value and value > 0 then
                        SETTINGS.spinSpeedMultiplier = value
                        speedBox.Text = tostring(value)
                        pcall(SaveSettings)
                        if SETTINGS.spinSet then
                            local char = LocalPlayer.Character
                            if char then
                                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                                if root then
                                    local spinPart = root:FindFirstChild("Spin")
                                    if spinPart and spinPart:IsA("BodyAngularVelocity") then
                                        spinPart.AngularVelocity = Vector3.new(0, 0.25 * value, 0)
                                    end
                                end
                            end
                        end
                    else
                        speedBox.Text = tostring(SETTINGS.spinSpeedMultiplier or 1)
                    end
                end)

                autoEmoteToggle.MouseButton1Click:Connect(function()
                    SETTINGS.emotePlaying = not SETTINGS.emotePlaying
                    autoEmoteToggle.Text = SETTINGS.emotePlaying and "ON" or "OFF"
                    pcall(SaveSettings)
                    if SETTINGS.emotePlaying and SETTINGS.emoteId and tostring(SETTINGS.emoteId) ~= "" then
                        pcall(function() playEmote(SETTINGS.emoteId) end)
                    else
                        pcall(function() stopEmote() end)
                    end
                end)
                -- Spin and periodic jump features removed from Overview
                SpinFeature.setHelicopterEnabled(SETTINGS.helicopterEnabled)

                -- Auto-play emote on UI/script execution if an emote is selected
                pcall(function()
                    if SETTINGS.emoteId and tostring(SETTINGS.emoteId) ~= "" and SETTINGS.emotePlaying then
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

                        -- (Periodic Jump and Spin controls moved below emote block for consistent layout)
                        if SETTINGS.emotePlaying then
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                                pcall(attemptPlay)
                            else
                                LocalPlayer.CharacterAdded:Connect(function()
                                    task.wait(0.5)
                                    pcall(attemptPlay)
                                end)
                            end
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
                rangeBox.Position = UDim2.new(0,220,0,44)
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
                hopBtn.BackgroundColor3 = Color3.fromRGB(90,90,90)
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

                -- Population Hopper (background monitor)
                local popLabel = Instance.new("TextLabel")
                popLabel.Size = UDim2.new(0,140,0,20)
                popLabel.Position = UDim2.new(0,10,0,228)
                popLabel.Text = "Population Hopper"
                popLabel.BackgroundTransparency = 1
                popLabel.TextColor3 = Color3.new(1,1,1)
                popLabel.Parent = frame

                local popToggle = Instance.new("TextButton")
                popToggle.Size = UDim2.new(0,60,0,20)
                popToggle.Position = UDim2.new(0,220,0,228)
                popToggle.Text = SETTINGS.populationHopper and "ON" or "OFF"
                popToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
                popToggle.TextColor3 = Color3.fromRGB(255,255,255)
                popToggle.Parent = frame
                local popCorner = Instance.new("UICorner") popCorner.Parent = popToggle
                styleButton(popToggle)

                local thresholdLabel = Instance.new("TextLabel")
                thresholdLabel.Size = UDim2.new(0,160,0,20)
                thresholdLabel.Position = UDim2.new(0,10,0,258)
                thresholdLabel.Text = "Hop When Below (players)"
                thresholdLabel.BackgroundTransparency = 1
                thresholdLabel.TextColor3 = Color3.new(1,1,1)
                thresholdLabel.Parent = frame

                local thresholdBox = Instance.new("TextBox")
                thresholdBox.Size = UDim2.new(0,80,0,20)
                thresholdBox.Position = UDim2.new(0,220,0,258)
                thresholdBox.Text = tostring(SETTINGS.populationThreshold or 17)
                thresholdBox.ClearTextOnFocus = false
                thresholdBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
                thresholdBox.TextColor3 = Color3.fromRGB(255,255,255)
                thresholdBox.Parent = frame
                local thrCorner = Instance.new("UICorner") thrCorner.Parent = thresholdBox

                local populationHopperEnabled = SETTINGS.populationHopper or false
                local populationMonitorTask = nil

                local function startPopulationMonitor()
                    if populationMonitorTask then return end
                    populationMonitorTask = task.spawn(function()
                        local lastHop = 0
                        while populationHopperEnabled do
                            local cnt = #Players:GetPlayers()
                            local thr = tonumber(SETTINGS.populationThreshold) or tonumber(thresholdBox.Text) or 17
                            if cnt < thr then
                                local now = os.time()
                                if now - lastHop > 60 then
                                    lastHop = now
                                    -- Use user's hop range preference when searching
                                    local txt = (rangeBox and tostring(rangeBox.Text) or hopRangeText) or ""
                                    local mn, mx = parseRangeGlobal(txt)
                                    pcall(function()
                                        serverSearchAttempt(mn, mx, false)
                                    end)
                                end
                            end
                            task.wait(15)
                        end
                        populationMonitorTask = nil
                    end)
                end

                local function stopPopulationMonitor()
                    populationHopperEnabled = false
                end

                popToggle.MouseButton1Click:Connect(function()
                    populationHopperEnabled = not populationHopperEnabled
                    SETTINGS.populationHopper = populationHopperEnabled
                    popToggle.Text = populationHopperEnabled and "ON" or "OFF"
                    pcall(SaveSettings)
                    if populationHopperEnabled then
                        if not SETTINGS.populationThreshold then SETTINGS.populationThreshold = tonumber(thresholdBox.Text) or 17 end
                        startPopulationMonitor()
                    else
                        stopPopulationMonitor()
                    end
                end)

                thresholdBox.FocusLost:Connect(function(enter)
                    local v = tonumber(thresholdBox.Text)
                    if v and v >= 2 then
                        SETTINGS.populationThreshold = math.floor(v)
                    else
                        thresholdBox.Text = tostring(SETTINGS.populationThreshold or 17)
                    end
                    pcall(SaveSettings)
                end)

                -- Initialize monitor if setting persisted
                if SETTINGS.populationHopper then
                    populationHopperEnabled = true
                    popToggle.Text = "ON"
                    if not SETTINGS.populationThreshold then SETTINGS.populationThreshold = tonumber(thresholdBox.Text) or 17 end
                    startPopulationMonitor()
                end

                local autoLabel = Instance.new("TextLabel")
                autoLabel.Size = UDim2.new(0,120,0,20)
                autoLabel.Position = UDim2.new(0,10,0,160)
                autoLabel.Text = "Auto Server Hop"
                autoLabel.BackgroundTransparency = 1
                autoLabel.TextColor3 = Color3.new(1,1,1)
                autoLabel.Parent = frame
                styleFeatureLabel(autoLabel)

                local autoToggle = Instance.new("TextButton")
                autoToggle.Size = UDim2.new(0,60,0,24)
                autoToggle.Position = UDim2.new(0,140,0,160)
                autoToggle.Text = autoServerHopEnabled and "ON" or "OFF"
                autoToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
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

                local staffLabel = Instance.new("TextLabel")
                staffLabel.Size = UDim2.new(0,120,0,20)
                staffLabel.Position = UDim2.new(0,10,0,194)
                staffLabel.Text = "Staff Hop"
                staffLabel.BackgroundTransparency = 1
                staffLabel.TextColor3 = Color3.new(1,1,1)
                staffLabel.Parent = frame

                local staffToggle = Instance.new("TextButton")
                staffToggle.Size = UDim2.new(0,60,0,20)
                staffToggle.Position = UDim2.new(0,140,0,194)
                staffToggle.Text = SETTINGS.staffHop and "ON" or "OFF"
                staffToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
                staffToggle.TextColor3 = Color3.fromRGB(255,255,255)
                local shCorner = Instance.new("UICorner")
                shCorner.Parent = staffToggle
                staffToggle.Parent = frame
                styleButton(staffToggle)
                staffToggle.MouseButton1Click:Connect(function()
                    SETTINGS.staffHop = not SETTINGS.staffHop
                    staffToggle.Text = SETTINGS.staffHop and "ON" or "OFF"
                    pcall(SaveSettings)
                end)

                local friendHopLabel = Instance.new("TextLabel")
                friendHopLabel.Size = UDim2.new(0,120,0,20)
                friendHopLabel.Position = UDim2.new(0,10,0,292)
                friendHopLabel.Text = "Friend Hop"
                friendHopLabel.BackgroundTransparency = 1
                friendHopLabel.TextColor3 = Color3.new(1,1,1)
                friendHopLabel.Parent = frame

                local friendHopToggle = Instance.new("TextButton")
                friendHopToggle.Size = UDim2.new(0,60,0,20)
                friendHopToggle.Position = UDim2.new(0,140,0,292)
                friendHopToggle.Text = SETTINGS.friendHop and "ON" or "OFF"
                friendHopToggle.BackgroundColor3 = Color3.fromRGB(70,70,70)
                friendHopToggle.TextColor3 = Color3.fromRGB(255,255,255)
                friendHopToggle.Parent = frame
                local friendHopCorner = Instance.new("UICorner")
                friendHopCorner.Parent = friendHopToggle
                styleButton(friendHopToggle)

                local friendHopBusy = false
                local friendChecks = {}
                local function checkFriendAndHop(player)
                    if not SETTINGS.friendHop or not player or player == LocalPlayer then return end
                    local userId = player.UserId
                    if friendChecks[userId] or friendHopBusy then return end
                    friendChecks[userId] = true

                    task.spawn(function()
                        local ok, isFriend = pcall(function()
                            return LocalPlayer:IsFriendsWith(userId)
                        end)
                        friendChecks[userId] = nil

                        if not ok then
                            warn("[PLS WAIT] Could not check friend status for " .. tostring(player.Name) .. ": " .. tostring(isFriend))
                            return
                        end
                        if not isFriend or not SETTINGS.friendHop or friendHopBusy then return end

                        friendHopBusy = true
                        task.spawn(function()
                            local minPlayers, maxPlayers = parseRange(hopRangeText)
                            while SETTINGS.friendHop do
                                local searchOk, hopped = pcall(serverSearchAttempt, minPlayers, maxPlayers, false)
                                if not searchOk then
                                    warn("[PLS WAIT] Friend hop search failed:", hopped)
                                elseif hopped then
                                    break
                                end
                                task.wait(1)
                            end
                            friendHopBusy = false
                        end)
                    end)
                end

                Players.PlayerAdded:Connect(checkFriendAndHop)
                friendHopToggle.MouseButton1Click:Connect(function()
                    SETTINGS.friendHop = not SETTINGS.friendHop
                    friendHopToggle.Text = SETTINGS.friendHop and "ON" or "OFF"
                    pcall(SaveSettings)
                    if SETTINGS.friendHop then
                        for _, player in ipairs(Players:GetPlayers()) do
                            checkFriendAndHop(player)
                        end
                    end
                end)
                if SETTINGS.friendHop then
                    for _, player in ipairs(Players:GetPlayers()) do
                        checkFriendAndHop(player)
                    end
                end
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
                whToggle.BackgroundColor3 = Color3.fromRGB(90,90,90)
                styleButton(whToggle)
                whToggle.MouseButton1Click:Connect(function()
                    SETTINGS.webhookToggle = not SETTINGS.webhookToggle
                    whToggle.Text = SETTINGS.webhookToggle and "ON" or "OFF"
                    if SETTINGS.webhookToggle then
                        startDonationMonitor()
                    elseif not SETTINGS.spinSet and not SETTINGS.helicopterEnabled then
                        stopDonationMonitor()
                    end
                    pcall(SaveSettings)
                end)

                -- follow-on-donation UI removed

                local urlBox = Instance.new("TextBox")
                urlBox.Size = UDim2.new(1, -20, 0, 24)
                urlBox.Position = UDim2.new(0,10,0,72)
                urlBox.Text = tostring(SETTINGS.webhookUrl or "")
                urlBox.PlaceholderText = "https://discord.com/api/webhooks..."
                urlBox.TextXAlignment = Enum.TextXAlignment.Left
                urlBox.ClearTextOnFocus = false
                urlBox.TextWrapped = false
                urlBox.Parent = frame
                urlBox.FocusLost:Connect(function()
                    SETTINGS.webhookUrl = tostring(urlBox.Text or "")
                    pcall(SaveSettings)
                end)

                local donationTestBtn = Instance.new("TextButton")
                donationTestBtn.Size = UDim2.new(0,160,0,24)
                donationTestBtn.Position = UDim2.new(0,10,0,108)
                donationTestBtn.Text = "Test Donation"
                donationTestBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
                donationTestBtn.TextColor3 = Color3.fromRGB(255,255,255)
                donationTestBtn.Parent = frame
                styleButton(donationTestBtn)
                donationTestBtn.MouseButton1Click:Connect(function()
                    local donor, donorName, donorId = nil, nil, nil
                    if type(resolveDonationDonor) == "function" then
                        donor, donorName, donorId = resolveDonationDonor(nil, nil)
                    end
                    if not donor then donor = LocalPlayer; donorName = LocalPlayer and LocalPlayer.Name or "TestDonor"; donorId = LocalPlayer and LocalPlayer.UserId or 0 end
                    local function parseDonationValue(v)
                        if type(v) == "number" then return math.floor(v) end
                        local s = tostring(v or "")
                        local cleaned = s:gsub("[^%d%-]", "")
                        local num = tonumber(cleaned)
                        if num then return math.floor(num) end
                        local m = s:match("%-?%d+")
                        return tonumber(m) or 0
                    end
                    local function formatDonationValue(n)
                        local isNegative = n < 0
                        local absVal = tostring(math.abs(n))
                        local formatted = absVal:reverse():gsub("(%d%d%d)", "%1,"):reverse()
                        if formatted:sub(1,1) == "," then
                            formatted = formatted:sub(2)
                        end
                        if isNegative then formatted = "-" .. formatted end
                        return formatted
                    end
                    local leaderstats = LocalPlayer:FindFirstChild("leaderstats") or LocalPlayer:WaitForChild("leaderstats", 3)
                    local totalValue = 1
                    if leaderstats then
                        local raised = leaderstats:FindFirstChild("Raised") or leaderstats:FindFirstChild("raised")
                        if raised then
                            local current = parseDonationValue(raised.Value)
                            local nextValue = current + 6
                            totalValue = nextValue
                            if raised:IsA("StringValue") then
                                local raw = tostring(raised.Value or "")
                                local prefix = raw:match("^(%D*)") or ""
                                local suffix = raw:match("(%D*)$") or ""
                                raised.Value = prefix .. formatDonationValue(nextValue) .. suffix
                            elseif raised:IsA("IntValue") or raised:IsA("NumberValue") then
                                pcall(function()
                                    raised.Value = nextValue
                                end)
                            else
                                pcall(function()
                                    raised.Value = tostring(nextValue)
                                end)
                            end
                        end
                    end
                    pcall(function()
                        postWebhookEvent("donation", {
                            donorName = donorName,
                            from = donorName,
                            userId = donorId,
                            amount = 6,
                            total = totalValue,
                            test = true,
                        })
                    end)
                    notify("Donation Test", "Test donation event sent.", 4)
                end)

                -- donation stat name textbox removed per user request
            end

            -- Chat tab
            do
                local frame = tabFrames.Chat
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(0,160,0,20)
                label.Position = UDim2.new(0,10,0,10)
                label.Text = "Auto Thank You"
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.new(1,1,1)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 16
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = frame

                local autoLabel = Instance.new("TextLabel")
                autoLabel.Size = UDim2.new(0,120,0,20)
                autoLabel.Position = UDim2.new(0,10,0,44)
                autoLabel.Text = "Enabled"
                autoLabel.BackgroundTransparency = 1
                autoLabel.TextColor3 = Color3.new(1,1,1)
                autoLabel.Parent = frame

                local autoToggle = Instance.new("TextButton")
                autoToggle.Size = UDim2.new(0,60,0,20)
                autoToggle.Position = UDim2.new(0,140,0,44)
                autoToggle.Text = SETTINGS.chatAutoThankYou and "ON" or "OFF"
                autoToggle.BackgroundColor3 = Color3.fromRGB(90,90,90)
                autoToggle.TextColor3 = Color3.fromRGB(255,255,255)
                autoToggle.Parent = frame
                local autoCorner = Instance.new("UICorner") autoCorner.Parent = autoToggle
                styleButton(autoToggle)
                autoToggle.MouseButton1Click:Connect(function()
                    SETTINGS.chatAutoThankYou = not SETTINGS.chatAutoThankYou
                    autoToggle.Text = SETTINGS.chatAutoThankYou and "ON" or "OFF"
                    pcall(SaveSettings)
                end)

                local spinThankYouInfo = Instance.new("TextLabel")
                spinThankYouInfo.Size = UDim2.new(1, -20, 0, 44)
                spinThankYouInfo.Position = UDim2.new(0, 10, 0, 78)
                spinThankYouInfo.Text = "With Spin On Donation enabled, Auto Thank You replaces these messages with: “Spin speed increased by [actual increase].” The amount includes your Spin Speed Multiplier."
                spinThankYouInfo.BackgroundTransparency = 1
                spinThankYouInfo.TextColor3 = Color3.fromRGB(155, 215, 255)
                spinThankYouInfo.Font = Enum.Font.GothamMedium
                spinThankYouInfo.TextSize = 14
                spinThankYouInfo.TextWrapped = true
                spinThankYouInfo.TextXAlignment = Enum.TextXAlignment.Left
                spinThankYouInfo.Parent = frame

                local messageLabel = Instance.new("TextLabel")
                messageLabel.Size = UDim2.new(0,160,0,20)
                messageLabel.Position = UDim2.new(0,10,0,128)
                messageLabel.Text = "Thank You Messages"
                messageLabel.BackgroundTransparency = 1
                messageLabel.TextColor3 = Color3.new(1,1,1)
                messageLabel.Font = Enum.Font.GothamBold
                messageLabel.TextSize = 16
                messageLabel.Parent = frame

                for i = 1, 3 do
                    local msgBox = Instance.new("TextBox")
                    msgBox.Size = UDim2.new(1, -20, 0, 28)
                    msgBox.Position = UDim2.new(0,10,0, 154 + i * 36)
                    msgBox.Text = tostring(SETTINGS.thankYouMessages[i] or "")
                    msgBox.BackgroundColor3 = Color3.fromRGB(60,60,60)
                    msgBox.TextColor3 = Color3.fromRGB(255,255,255)
                    msgBox.ClearTextOnFocus = false
                    msgBox.TextXAlignment = Enum.TextXAlignment.Left
                    msgBox.Font = Enum.Font.GothamMedium
                    msgBox.TextSize = 16
                    msgBox.Parent = frame
                    local msgCorner = Instance.new("UICorner") msgCorner.Parent = msgBox
                    msgBox.FocusLost:Connect(function()
                        SETTINGS.thankYouMessages[i] = tostring(msgBox.Text or "")
                        pcall(SaveSettings)
                    end)
                end
            end

            -- Fade-in removed: UI elements appear immediately (user requested no fade)

            if SETTINGS.webhookToggle or SETTINGS.spinSet or SETTINGS.helicopterEnabled then
                startDonationMonitor()
            end
            if SETTINGS.webhookToggle then
                pcall(function()
                    pcall(function() sendPlainWebhook(("@%s serverhopped"):format(tostring(LocalPlayer and LocalPlayer.Name or "Unknown"))) end)
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
                            friendHop = SETTINGS.friendHop,
                            serverStayTime = SETTINGS.serverStayTime,
                            persistToggles = SETTINGS.persistToggles,
                            spinOnDonation = SETTINGS.spinSet,
                            spinSet = SETTINGS.spinSet,
                            spinSpeedMultiplier = SETTINGS.spinSpeedMultiplier,
                            helicopterEnabled = SETTINGS.helicopterEnabled,
                            populationHopper = SETTINGS.populationHopper,
                            populationThreshold = SETTINGS.populationThreshold,
                            goalBarEnabled = SETTINGS.goalBarEnabled,
                            goalBarTarget = SETTINGS.goalBarTarget,
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
                    pcall(function() ensureQueuedScript(qcode) end)
                end
            end)
            -- Ensure claim runs immediately on UI/script execution and again after respawn
            pcall(function()
                task.spawn(function()
                    for attempt = 1, 15 do
                        if LocalPlayer and LocalPlayer.Character then
                            notify("Booth Claim", "Preparing to claim the next available booth...", 3)
                            pcall(function() claimBooth() end)
                            break
                        end
                        task.wait(0.5)
                    end
                end)

                LocalPlayer.CharacterAdded:Connect(function(character)
                    task.spawn(function()
                        pcall(function() ensureSpinPart(character) end)
                        pcall(function() SpinFeature.ensureHelicopter() end)
                    end)
                    task.wait(1)
                    notify("Booth Claim", "Character respawned; attempting booth claim...", 3)
                    pcall(function() claimBooth() end)
                end)
            end)
            if SETTINGS.spinSet then pcall(ensureSpinPart) end
            if SETTINGS.antiAfk then pcall(enableAntiAfk) end
            -- spin feature removed
            -- Touch-prevent AFK: send a small simulated tap pulse every 2 minutes
            task.spawn(function()
                local interval = 120
                while true do
                    if SETTINGS.touchPreventAFK then
                        simulateTouchTapPulse()
                    end
                    task.wait(interval)
                end
            end)
            -- Periodic jump feature removed
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
        SpinFeature.startBoothReturnMonitor()
    end
end

return UI
