--[[
    DONO GAME - Booth Proximity Prompt Firer & Claimer
    - Finds booths by "plot" parts (primaryparts)
    - Fires proximity prompts to claim booths
    - Teleports to successful claims
]]

print("Dono Booth Claimer - Starting initialization...")

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local HumanoidRootPart = Humanoid and Humanoid.RootPart

if not HumanoidRootPart then return end

-- ===== DATA STRUCTURES =====
local boothCache = {}
local claimStatus = {}
local activeOperations = {}

-- ===== THEME =====
local THEME = {
    bg = Color3.fromRGB(20, 24, 34),
    topBar = Color3.fromRGB(15, 18, 26),
    panel = Color3.fromRGB(28, 33, 48),
    text = Color3.fromRGB(230, 235, 245),
    accentGreen = Color3.fromRGB(76, 200, 120),
    accentRed = Color3.fromRGB(220, 88, 88),
    accentBlue = Color3.fromRGB(100, 150, 255),
    subtle = Color3.fromRGB(140, 150, 170),
}

-- ===== UTILITY FUNCTIONS =====

local function createNotification(title, message, duration)
    local success, err = pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(message),
            Duration = duration or 3,
        })
    end)
end

local function findBoothParts()
    local booths = {}
    
    -- Search for booth parts in workspace
    for _, boothFolder in ipairs(Workspace:GetChildren()) do
        if boothFolder.Name == "booth" and boothFolder:IsA("Folder") then
            -- Find the booth part within this folder
            local boothPart = boothFolder:FindFirstChild("booth")
            if boothPart and boothPart:IsA("BasePart") then
                -- Check if unclaimed (no specific attribute indicating ownership)
                local proximityPrompt = boothFolder:FindFirstChild("ProximityPrompt")
                if proximityPrompt and proximityPrompt:IsA("ProximityPrompt") then
                    if not boothCache[boothFolder] then
                        boothCache[boothFolder] = {
                            boothFolder = boothFolder,
                            boothPart = boothPart,
                            proximityPrompt = proximityPrompt,
                            position = boothPart.Position,
                            promptPosition = proximityPrompt.Parent and proximityPrompt.Parent:IsA("BasePart") and proximityPrompt.Parent.Position or proximityPrompt.Position,
                        }
                    end
                    table.insert(booths, boothCache[boothFolder])
                end
            end
        end
    end
    
    return booths
end

local function findProximityPrompt(booth)
    if not booth or not booth.boothFolder then return nil end
    
    -- Get the ProximityPrompt from the booth folder
    local prompt = booth.boothFolder:FindFirstChild("ProximityPrompt")
    if prompt and prompt:IsA("ProximityPrompt") and prompt.ActionText == "Claim Booth!" then
        return prompt
    end
    
    return nil
end

local function fireProximityPrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").RootPart
    
    if not humanoidRootPart then return false end
    
    -- Ensure we're close to the prompt
    local promptPos = prompt.Parent:IsA("BasePart") and prompt.Parent.Position or prompt.Position
    local distance = (humanoidRootPart.Position - promptPos).Magnitude
    
    if distance > prompt.MaxActivationDistance + 5 then
        return false
    end
    
    -- Fire the proximity prompt
    local success = pcall(function()
        prompt:Fire()
    end)
    
    return success
end

local function teleportToPosition(position, delayBefore)
    delayBefore = tonumber(delayBefore) or 0
    
    if delayBefore > 0 then
        task.wait(delayBefore)
    end
    
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").RootPart
    
    if not humanoidRootPart then return false end
    
    -- Offset position slightly above the booth so we don't clip
    local teleportPos = position + Vector3.new(0, 3, 0)
    
    humanoidRootPart.CFrame = CFrame.new(teleportPos)
    
    return true
end

local function attemptBoothClaim(booth)
    if not booth or claimStatus[booth] == "claimed" then
        return false
    end
    
    local prompt = findProximityPrompt(booth)
    if not prompt then
        createNotification("Booth Claimer", "Proximity prompt not found!", 2)
        return false
    end
    
    -- Get the prompt's position (from its parent if it's a part, or direct position)
    local promptPos = prompt.Parent and prompt.Parent:IsA("BasePart") and prompt.Parent.Position or prompt.Position
    
    -- Step 1: Teleport to the proximity prompt
    createNotification("Booth Claimer", "Teleporting to prompt...", 1)
    teleportToPosition(promptPos, 0)
    task.wait(0.3)
    
    -- Step 2: Fire the proximity prompt
    createNotification("Booth Claimer", "Firing Claim Booth prompt...", 1)
    local fired = fireProximityPrompt(prompt)
    
    if not fired then
        createNotification("Booth Claimer", "Failed to fire prompt!", 2)
        return false
    end
    
    task.wait(1)
    
    -- Step 3: Mark as claimed
    createNotification("Booth Claimer", "✓ Booth claimed successfully!", 2)
    claimStatus[booth] = "claimed"
    
    return true
end

-- ===== UI CREATION =====

local function createUI()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DonoBoothClaimerUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 100
    screenGui.Parent = playerGui
    
    -- Determine if mobile based on viewport size
    local camera = workspace.CurrentCamera
    local viewportSize = camera.ViewportSize
    local isMobile = viewportSize.X < 800 or UserInputService.TouchEnabled
    
    -- Responsive sizing
    local panelWidth = isMobile and math.min(380, viewportSize.X - 10) or 380
    local panelHeight = isMobile and 500 or 480
    local startX = isMobile and 5 or 20
    local startY = isMobile and 5 or 20
    
    -- Main Panel
    local mainPanel = Instance.new("Frame")
    mainPanel.Name = "MainPanel"
    mainPanel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
    mainPanel.Position = UDim2.fromOffset(startX, startY)
    mainPanel.BackgroundColor3 = THEME.bg
    mainPanel.BorderSizePixel = 0
    mainPanel.Parent = screenGui
    
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = mainPanel
    
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = THEME.accentBlue
    panelStroke.Thickness = 2
    panelStroke.Parent = mainPanel
    
    -- Top Bar
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 40)
    topBar.BackgroundColor3 = THEME.topBar
    topBar.BorderSizePixel = 0
    topBar.Parent = mainPanel
    
    local topBarCorner = Instance.new("UICorner")
    topBarCorner.CornerRadius = UDim.new(0, 12)
    topBarCorner.Parent = topBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 1, 0)
    titleLabel.Position = UDim2.fromOffset(10, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = THEME.text
    titleLabel.TextSize = isMobile and 14 or 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = "🎁 Booth Claimer"
    titleLabel.Parent = topBar
    
    -- Content Area
    local contentArea = Instance.new("ScrollingFrame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -16, 1, -60)
    contentArea.Position = UDim2.fromOffset(8, 48)
    contentArea.BackgroundColor3 = THEME.panel
    contentArea.BorderSizePixel = 0
    contentArea.ScrollBarThickness = 4
    contentArea.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentArea.Parent = mainPanel
    
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 8)
    contentCorner.Parent = contentArea
    
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = contentArea
    
    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingTop = UDim.new(0, 8)
    contentPadding.PaddingBottom = UDim.new(0, 8)
    contentPadding.PaddingLeft = UDim.new(0, 8)
    contentPadding.PaddingRight = UDim.new(0, 8)
    contentPadding.Parent = contentArea
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 40)
    statusLabel.BackgroundColor3 = THEME.accentBlue
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = "Status: Scanning for booths..."
    statusLabel.TextWrapped = true
    statusLabel.Parent = contentArea
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusLabel
    
    -- Booth List Frame
    local boothListFrame = Instance.new("Frame")
    boothListFrame.Size = UDim2.new(1, 0, 0, 0)
    boothListFrame.BackgroundTransparency = 1
    boothListFrame.AutomaticSize = Enum.AutomaticSize.Y
    boothListFrame.Parent = contentArea
    
    local boothListLayout = Instance.new("UIListLayout")
    boothListLayout.Padding = UDim.new(0, 6)
    boothListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    boothListLayout.Parent = boothListFrame
    
    -- Button Container
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, -16, 0, isMobile and 70 or 50)
    buttonContainer.Position = UDim2.fromOffset(8, isMobile and -78 or -58)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = mainPanel
    
    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    buttonLayout.Padding = UDim.new(0, 6)
    buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
    buttonLayout.Parent = buttonContainer
    
    -- Scan Button
    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = isMobile and UDim2.new(1, 0, 0, 32) or UDim2.new(0.5, -3, 1, 0)
    scanBtn.BackgroundColor3 = THEME.accentGreen
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.TextSize = 12
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.Text = "📍 Scan Booths"
    scanBtn.Parent = buttonContainer
    
    local scanBtnCorner = Instance.new("UICorner")
    scanBtnCorner.CornerRadius = UDim.new(0, 6)
    scanBtnCorner.Parent = scanBtn
    
    -- Claim All Button
    local claimAllBtn = Instance.new("TextButton")
    claimAllBtn.Size = isMobile and UDim2.new(1, 0, 0, 32) or UDim2.new(0.5, -3, 1, 0)
    claimAllBtn.BackgroundColor3 = THEME.accentRed
    claimAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimAllBtn.TextSize = 12
    claimAllBtn.Font = Enum.Font.GothamBold
    claimAllBtn.Text = "🎯 Claim All"
    claimAllBtn.Parent = buttonContainer
    
    local claimAllBtnCorner = Instance.new("UICorner")
    claimAllBtnCorner.CornerRadius = UDim.new(0, 6)
    claimAllBtnCorner.Parent = claimAllBtn
    
    -- ===== BUTTON LOGIC =====
    
    local function refreshBoothList()
        -- Clear previous booths
        for _, child in ipairs(boothListFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        local booths = findBoothParts()
        
        if #booths == 0 then
            statusLabel.Text = "❌ No unclaimed booths found"
            statusLabel.BackgroundColor3 = THEME.accentRed
            return
        end
        
        statusLabel.Text = ("✓ Found %d unclaimed booth(s)"):format(#booths)
        statusLabel.BackgroundColor3 = THEME.accentGreen
        
        for i, booth in ipairs(booths) do
            local boothCard = Instance.new("Frame")
            boothCard.Size = UDim2.new(1, 0, 0, isMobile and 60 or 50)
            boothCard.BackgroundColor3 = THEME.panel
            boothCard.BorderSizePixel = 1
            boothCard.BorderColor3 = THEME.subtle
            boothCard.Parent = boothListFrame
            
            local boothCardCorner = Instance.new("UICorner")
            boothCardCorner.CornerRadius = UDim.new(0, 6)
            boothCardCorner.Parent = boothCard
            
            -- Booth info
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Size = UDim2.new(1, -70, 0, isMobile and 22 or 20)
            infoLabel.Position = UDim2.fromOffset(8, isMobile and 6 or 4)
            infoLabel.BackgroundTransparency = 1
            infoLabel.TextColor3 = THEME.text
            infoLabel.TextSize = isMobile and 12 or 11
            infoLabel.Font = Enum.Font.GothamSemibold
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            infoLabel.Text = ("Booth #%d - %s"):format(i, booth.boothFolder.Name)
            infoLabel.Parent = boothCard
            
            -- Position info
            local posLabel = Instance.new("TextLabel")
            posLabel.Size = UDim2.new(1, -70, 0, isMobile and 20 or 16)
            posLabel.Position = UDim2.fromOffset(8, isMobile and 28 or 24)
            posLabel.BackgroundTransparency = 1
            posLabel.TextColor3 = THEME.subtle
            posLabel.TextSize = isMobile and 10 or 9
            posLabel.Font = Enum.Font.Gotham
            posLabel.TextXAlignment = Enum.TextXAlignment.Left
            posLabel.Text = ("Part: %.0f, %.0f, %.0f"):format(booth.position.X, booth.position.Y, booth.position.Z)
            posLabel.Parent = boothCard
            
            -- Status indicator
            local statusDot = Instance.new("TextLabel")
            statusDot.Size = UDim2.new(0, 60, 1, 0)
            statusDot.Position = UDim2.new(1, -68, 0, 0)
            statusDot.BackgroundTransparency = 1
            statusDot.TextColor3 = claimStatus[booth] == "claimed" and THEME.accentGreen or THEME.subtle
            statusDot.TextSize = isMobile and 10 or 11
            statusDot.Font = Enum.Font.GothamSemibold
            statusDot.TextXAlignment = Enum.TextXAlignment.Right
            statusDot.Text = claimStatus[booth] == "claimed" and "✓ CLAIMED" or "○ UNCLAIMED"
            statusDot.Parent = boothCard
        end
    end
    
    scanBtn.MouseButton1Click:Connect(function()
        refreshBoothList()
        createNotification("Booth Claimer", "Booth list refreshed!", 2)
    end)
    
    -- Add mobile feedback to buttons
    if isMobile then
        local function addButtonFeedback(btn)
            local originalColor = btn.BackgroundColor3
            btn.MouseEnter:Connect(function()
                btn.BackgroundTransparency = 0.1
            end)
            btn.MouseLeave:Connect(function()
                btn.BackgroundTransparency = 0
            end)
        end
        addButtonFeedback(scanBtn)
        addButtonFeedback(claimAllBtn)
    end
    
    claimAllBtn.MouseButton1Click:Connect(function()
        local booths = findBoothParts()
        if #booths == 0 then
            createNotification("Booth Claimer", "No booths found!", 2)
            return
        end
        
        createNotification("Booth Claimer", ("Claiming %d booth(s)..."):format(#booths), 3)
        
        for i, booth in ipairs(booths) do
            if claimStatus[booth] ~= "claimed" then
                attemptBoothClaim(booth)
                task.wait(2) -- Wait between claims
            end
        end
        
        createNotification("Booth Claimer", "All booths processed!", 3)
        refreshBoothList()
    end)
    
    -- Initial scan
    task.delay(0.5, refreshBoothList)
    
    -- Auto-update list every 5 seconds
    task.spawn(function()
        while task.wait(5) do
            if mainPanel.Parent then
                refreshBoothList()
            end
        end
    end)
    
    -- Handle viewport changes (rotation, resize)
    RunService.RenderStepped:Connect(function()
        local currentViewportSize = workspace.CurrentCamera.ViewportSize
        
        -- Clamp position to stay within bounds
        local maxX = currentViewportSize.X - 50
        local maxY = currentViewportSize.Y - 30
        
        local pos = mainPanel.Position
        local clampedX = math.clamp(pos.X.Offset, -mainPanel.AbsoluteSize.X + 50, maxX)
        local clampedY = math.clamp(pos.Y.Offset, 0, maxY)
        
        if math.abs(clampedX - pos.X.Offset) > 1 or math.abs(clampedY - pos.Y.Offset) > 1 then
            mainPanel.Position = UDim2.new(pos.X.Scale, clampedX, pos.Y.Scale, clampedY)
        end
    end)
    
    -- Make UI draggable (both mouse and touch)
    local dragging = false
    local dragStart
    local startPos
    local touchConnection
    
    local function startDrag(inputPos)
        dragging = true
        dragStart = inputPos
        startPos = mainPanel.Position
    end
    
    local function updateDrag(inputPos)
        if not dragging or not dragStart or not startPos then return end
        
        local delta = inputPos - dragStart
        local newX = math.clamp(startPos.X.Offset + delta.X, -mainPanel.AbsoluteSize.X + 50, viewportSize.X - 50)
        local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, viewportSize.Y - 30)
        mainPanel.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
    end
    
    local function endDrag()
        dragging = false
        dragStart = nil
    end
    
    -- Mouse input
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            startDrag(input.Position)
        end
    end)
    
    topBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            endDrag()
        end
    end)
    
    -- Touch input
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input.Position)
        end
    end)
    
    topBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
    
    -- Input changed (mouse movement and touch movement)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input.Position)
        end
    end)
    
    return screenGui
end

-- ===== INITIALIZATION =====

createUI()
createNotification("Booth Claimer", "UI loaded! Click 'Scan Booths' to start.", 3)

print("Dono Booth Claimer - Ready!")
)
