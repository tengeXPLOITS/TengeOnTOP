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

local function getNearbySocialTargets(maxDistance)
    local myRoot = getHumanoidRootPart(LocalPlayer)
    if not myRoot then
        return {}
    end

    local candidates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and getHumanoidRootPart(player) then
            local root = getHumanoidRootPart(player)
            local dist = (root.Position - myRoot.Position).Magnitude
            if dist <= maxDistance and dist >= 8 and not wasTargetRecentlyMessaged(player) and not isPlayerStandingStill(player) then
                table.insert(candidates, {player = player, dist = dist})
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.dist < b.dist
    end)
    return candidates
end

local function computeRandomBoothPoint(radius)
    if not state.startAnchor then
        local root = getHumanoidRootPart(LocalPlayer)
        if not root then
            return nil
        end
        state.startAnchor = root.Position
    end

    local angle = math.random() * math.pi * 2
    local distance = 4 + math.random() * radius
    local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
    return state.startAnchor + offset
end

local function buildPath(destination)
    local humanoid = getHumanoid(LocalPlayer)
    if not humanoid or not destination then
        return nil
    end

    local path = PathfindingService:CreatePath({
        AgentHeight = 5,
        AgentRadius = 2,
        AgentCanJump = true,
        AgentMaxSlope = 45,
    })

    path:ComputeAsync(getHumanoidRootPart(LocalPlayer).Position, destination)
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

local function antiSitCheck()
    local humanoid = getHumanoid(LocalPlayer)
    if not humanoid then
        return
    end

    local stateType = humanoid:GetState()
    if stateType == Enum.HumanoidStateType.Seated or stateType == Enum.HumanoidStateType.PlatformStanding then
        humanoid.Jump = true
    end
end

local function randomSocialMessage()
    local messages = {
        "Hey! If you have a sec, swing by my booth!",
        "Thanks for stopping by — I've got a new booth you might like.",
        "Feel free to check out my booth if you're nearby!",
        "I'm hanging around my booth, come say hi if you can.",
        "If you're exploring, my booth is open and looking good!",
    }
    return messages[math.random(1, #messages)]
end

local function chatSocialMessage()
    if tick() - state.lastChatTime < 20 then
        return
    end
    state.lastChatTime = tick()
    pcall(function()
        Players:Chat(randomSocialMessage())
    end)
end

local function attemptSocializeWithPlayer(player)
    if not player or not player.Character or not getHumanoidRootPart(player) then
        return false
    end

    if wasTargetRecentlyMessaged(player) then
        return false
    end

    local targetRoot = getHumanoidRootPart(player)
    local approachPoint = targetRoot.Position - (targetRoot.CFrame.LookVector * 4)
    if not approachPoint then
        return false
    end

    local path = buildPath(approachPoint)
    if path and followPath(path, 12) then
        noteTargetChat(player)
        chatSocialMessage()
        return true
    end

    return false
end

local function getNextPatrolPoint()
    local settings = getSettings()
    local radius = clamp(settings.boothAskIntervalMax or 12, 8, 18)
    return computeRandomBoothPoint(radius)
end

local function runBoothMonitorLoop()
    while task.wait(1) do
        local settings = getSettings()
        if not settings or not settings.partModuleEnabled then
            task.wait(2)
            goto continue
        end

        antiSitCheck()

        local intervalMin = clamp(settings.boothAskIntervalMin or 10, 5, 120)
        local intervalMax = clamp(settings.boothAskIntervalMax or 20, intervalMin, 180)
        local waitTime = intervalMin + math.random() * (intervalMax - intervalMin)

        if settings.approachPeopleEnabled then
            local nearby = getNearbySocialTargets(24)
            if #nearby > 0 then
                for _, entry in ipairs(nearby) do
                    if attemptSocializeWithPlayer(entry.player) then
                        break
                    end
                end
            end
        end

        if settings.boothMonitoringEnabled then
            local patrolPoint = getNextPatrolPoint()
            if patrolPoint then
                local path = buildPath(patrolPoint)
                if path then
                    followPath(path, 10)
                else
                    moveToPosition(patrolPoint, 8)
                end
            end
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
