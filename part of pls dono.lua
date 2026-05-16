-- part of pls dono module
-- This module is intended to be loaded by the main pls dono GUI script.
-- It adds booth monitoring with human-like pathfinding, anti-sit, and social chat.

repeat task.wait() until game:IsLoaded()
local Players = game:GetService('Players')
local PathfindingService = game:GetService('PathfindingService')
local StarterGui = game:GetService('StarterGui')
local RunService = game:GetService('RunService')
local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer

local SharedEnv = (type(getgenv) == 'function' and getgenv()) or _G
local function getSettings()
    return (SharedEnv.plsdonoPartModule and SharedEnv.plsdonoPartModule.settings) or {}
end

local function safeNotify(title, text)
    pcall(function()
        StarterGui:SetCore('SendNotification', {
            Title = tostring(title or 'PLS DONO Part'),
            Text = tostring(text or ''),
            Duration = 4,
        })
    end)
end

local function clamp(value, minValue, maxValue)
    local n = tonumber(value) or minValue
    if n < minValue then
        return minValue
    end
    if n > maxValue then
        return maxValue
    end
    return n
end

local function getHumanoidRootPart(player)
    return player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
end

local function getHumanoid(player)
    return player and player.Character and player.Character:FindFirstChildOfClass('Humanoid')
end

local state = {
    startAnchor = nil,
    lastChatTime = 0,
    recentTargets = {},
    currentPath = nil,
    lastLocalPosition = nil,
    lastLocalState = nil,
}

local function noteTargetChat(player)
    if not player or not player.UserId then
        return
    end
    state.recentTargets[player.UserId] = tick()
end

local function wasTargetRecentlyMessaged(player)
    if not player or not player.UserId then
        return false
    end
    local last = state.recentTargets[player.UserId]
    return last and tick() - last < 120
end

local function isPlayerStandingStill(player)
    local humanoid = getHumanoid(player)
    local root = getHumanoidRootPart(player)
    if not humanoid or not root then
        return false
    end
    local vel = root.Velocity
    return vel.Magnitude < 1.5 or humanoid:GetState() == Enum.HumanoidStateType.Seated
end

local function isValidSocialTarget(player, myRoot)
    if not player or player == LocalPlayer or not player.Character then
        return false
    end

    local root = getHumanoidRootPart(player)
    local humanoid = getHumanoid(player)
    if not root or not humanoid then
        return false
    end

    local stateType = humanoid:GetState()
    if stateType == Enum.HumanoidStateType.Seated or stateType == Enum.HumanoidStateType.PlatformStanding then
        return false
    end

    if wasTargetRecentlyMessaged(player) then
        return false
    end

    local dist = (root.Position - myRoot.Position).Magnitude
    return dist >= 10 and dist <= 32
end

local function getNearbySocialTargets(maxDistance)
    local myRoot = getHumanoidRootPart(LocalPlayer)
    if not myRoot then
        return {}
    end

    local candidates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if isValidSocialTarget(player, myRoot) then
            local root = getHumanoidRootPart(player)
            local dist = (root.Position - myRoot.Position).Magnitude
            if dist <= maxDistance then
                table.insert(candidates, {player = player, dist = dist})
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.dist < b.dist
    end)
    return candidates
end

local function pruneRecentTargets()
    local now = tick()
    for userId, timestamp in pairs(state.recentTargets) do
        if now - timestamp > 180 then
            state.recentTargets[userId] = nil
        end
    end
end

local function shouldTrySocialize()
    return tick() - state.lastChatTime >= 12
end

local function getNearbyBoothPoint(radius)
    if not state.startAnchor then
        local root = getHumanoidRootPart(LocalPlayer)
        if not root then
            return nil
        end
        state.startAnchor = root.Position
    end

    local angle = math.random() * math.pi * 2
    local distance = 5 + math.random() * radius
    local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
    return state.startAnchor + offset
end

local function buildPath(destination)
    if not destination or not LocalPlayer.Character then
        return nil
    end

    local humanoidRoot = getHumanoidRootPart(LocalPlayer)
    if not humanoidRoot then
        return nil
    end

    local path = PathfindingService:CreatePath({
        AgentHeight = 5,
        AgentRadius = 2,
        AgentCanJump = true,
        AgentMaxSlope = 45,
    })

    path:ComputeAsync(humanoidRoot.Position, destination)
    if path.Status == Enum.PathStatus.Success then
        return path
    end
    return nil
end

local function followPath(path, timeout)
    if not path or not LocalPlayer.Character then
        return false
    end

    local points = path:GetWaypoints()
    local humanoid = getHumanoid(LocalPlayer)
    if not humanoid then
        return false
    end

    local deadline = tick() + (timeout or 12)
    for _, waypoint in ipairs(points) do
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        humanoid:MoveTo(waypoint.Position)
        local reached = false
        local connection
        connection = humanoid.MoveToFinished:Connect(function(success)
            reached = success
        end)

        while tick() < deadline and not reached do
            task.wait(0.1)
        end

        if connection then
            connection:Disconnect()
        end

        if not reached then
            return false
        end
    end

    return true
end

local function moveToPosition(position, timeout)
    if not position or not LocalPlayer.Character then
        return false
    end

    local humanoid = getHumanoid(LocalPlayer)
    if not humanoid then
        return false
    end

    local target = Vector3.new(position.X, position.Y, position.Z)
    local reached = false
    local connection = humanoid.MoveToFinished:Connect(function(success)
        reached = success
    end)

    humanoid:MoveTo(target)
    local deadline = tick() + (timeout or 12)
    while tick() < deadline and not reached do
        task.wait(0.1)
    end

    if connection then
        connection:Disconnect()
    end

    return reached
end

local function isInBoothZone()
    if not state.startAnchor or not LocalPlayer.Character then
        return false
    end
    local root = getHumanoidRootPart(LocalPlayer)
    if not root then
        return false
    end
    return (root.Position - state.startAnchor).Magnitude <= 20
end

local function randomSocialMessage(target)
    local display = tostring((target and target.DisplayName) or (target and target.Name) or "there")
    local messages = {
        "Hey " .. display .. ", my booth is nearby if you want to check it out!",
        "Hi " .. display .. ", I'm pacing around my booth if you want to stop by.",
        "If you're free, " .. display .. ", come over — my booth is open.",
        "My booth is looking good today, " .. display .. ". Come take a look when you can.",
        "I'm over by my booth, " .. display .. ". Feel free to drop by!",
    }
    return messages[math.random(1, #messages)]
end

local function chatSocialMessage(target)
    if tick() - state.lastChatTime < 20 then
        return
    end
    state.lastChatTime = tick()
    pcall(function()
        Players:Chat(randomSocialMessage(target))
    end)
end

local function buildApproachPoint(player)
    local root = getHumanoidRootPart(player)
    if not root then
        return nil
    end

    local direction = root.CFrame.LookVector
    local offset = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1))
    return root.Position - direction * 4 + offset
end

local function attemptSocializeWithPlayer(player)
    if not player or not player.Character or not getHumanoidRootPart(player) then
        return false
    end

    if wasTargetRecentlyMessaged(player) then
        return false
    end

    local approachPoint = buildApproachPoint(player)
    if not approachPoint then
        return false
    end

    local path = buildPath(approachPoint)
    local arrived = false
    if path and followPath(path, 14) then
        arrived = true
    else
        arrived = moveToPosition(approachPoint, 12)
    end

    if not arrived then
        return false
    end

    task.wait(0.8 + math.random() * 1.2)
    noteTargetChat(player)
    chatSocialMessage(player)
    return true
end

local function getPatrolPoint()
    local settings = getSettings()
    local radius = clamp(settings.boothAskIntervalMax or 12, 8, 18)
    return getNearbyBoothPoint(radius)
end

local function runBoothPatrol()
    local targetPoint = getPatrolPoint()
    if not targetPoint then
        return
    end

    local path = buildPath(targetPoint)
    if path and followPath(path, 12) then
        task.wait(1 + math.random() * 1.4)
        return
    end

    moveToPosition(targetPoint, 10)
end

local function runBoothMonitorLoop()
    while task.wait(1) do
        local settings = getSettings()
        if not settings or not settings.partModuleEnabled then
            task.wait(2)
            goto continue
        end

        antiSitCheck()
        pruneRecentTargets()

        local intervalMin = clamp(settings.boothAskIntervalMin or 10, 5, 120)
        local intervalMax = clamp(settings.boothAskIntervalMax or 20, intervalMin, 180)
        local waitTime = intervalMin + math.random() * (intervalMax - intervalMin)

        if settings.approachPeopleEnabled and shouldTrySocialize() then
            local nearby = getNearbySocialTargets(28)
            local attempts = clamp(settings.approachAttempts or 1, 1, 4)
            local used = 0
            for _, entry in ipairs(nearby) do
                if used >= attempts then
                    break
                end
                if attemptSocializeWithPlayer(entry.player) then
                    break
                end
                used = used + 1
            end
        end

        if settings.boothMonitoringEnabled and isInBoothZone() then
            runBoothPatrol()
        end

        if not settings.boothMonitoringEnabled and not settings.approachPeopleEnabled then
            task.wait(2)
        end

        task.wait(waitTime)
        ::continue::
    end
end

safeNotify('Part Module', 'Loaded successfully. Booth patrol and social behavior is active when enabled.')
task.spawn(runBoothMonitorLoop)
