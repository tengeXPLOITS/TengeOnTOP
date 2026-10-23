local Spin = {}

function Spin.create(dependencies)
    assert(type(dependencies) == "table", "spin dependencies are required")
    local LocalPlayer = assert(dependencies.LocalPlayer, "LocalPlayer is required")
    local Workspace = assert(dependencies.Workspace, "Workspace is required")
    local settings = assert(dependencies.settings, "settings table is required")
    local sendChatMessage = assert(dependencies.sendChatMessage, "chat sender is required")
    local sendDonationThankYou = dependencies.sendDonationThankYou
    local isStandOwned = assert(dependencies.isStandOwned, "stand ownership helper is required")
    local getStandPosition = assert(dependencies.getStandPosition, "stand-position helper is required")
    local computeStandPlacement = assert(dependencies.computeStandPlacement, "stand-placement helper is required")
    local moveCharacterToPosition = assert(dependencies.moveCharacterToPosition, "character-movement helper is required")
    local notify = assert(dependencies.notify, "notification function is required")

    local returnDistance = 12
    local helicopterIdleSpinSpeed = 2.7
    local helicopterTakeoffSpinSpeed = 14
    local helicopterFlightRoute = {
        CFrame.new(41.104126, 0.146320343, 31.5523529, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268),
        CFrame.new(-46.3318481, 0.146320343, 35.1495514, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        CFrame.new(-106.784424, 0.146320343, 21.7246552, 0.499959469, 0, -0.866048813, 0, 1, 0, 0.866048813, 0, 0.499959469),
        CFrame.new(-96.9567261, 0.146320343, -70.7528076, -0.866007447, 0, -0.500031412, 0, 1, 0, 0.500031412, 0, -0.866007447),
        CFrame.new(-9.13183594, 0.146320343, -74.3499756, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        CFrame.new(50.9318237, 0.146320343, -60.9251099, -0.499959469, 0, 0.866048813, 0, 1, 0, -0.866048813, 0, -0.499959469),
    }
    local currentHelicopterSpinTask
    local currentHelicopterIdleTask
    local currentLapTask
    local currentAstronautIdleTrack
    local pendingHelicopterRaisedAmount = 0
    local pendingLapCount = 0
    local animateScriptToRestore
    local animateScriptWasEnabled

    local function getCharacterHumanoidRoot()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = humanoid and humanoid.RootPart
            or (character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")))
        return character, humanoid, root
    end

    local function getHelicopterTargetCFrame(root)
        local standsFolder = Workspace:FindFirstChild("Stands") or Workspace:FindFirstChild("stands")
        if standsFolder then
            for _, stand in ipairs(standsFolder:GetChildren()) do
                if isStandOwned(stand) then
                    local position, direction = computeStandPlacement(stand, root.Position, 4.5)
                    if position and direction then
                        return CFrame.new(position, position + direction)
                    end
                end
            end
        end
        return root.CFrame
    end

    local function getHelicopterFlightDuration(amount)
        local donation = math.max(1, tonumber(amount) or 1)
        local lapBoost = 1 + math.min(3.5, math.sqrt(donation) * 0.6)
        if donation >= 100 then
            local clamped = math.min(10000, donation)
            local normalized = math.clamp((math.log10(clamped) - 2) / 2, 0, 1)
            return (16 + (18 * normalized)) * lapBoost
        end
        local normalized = math.clamp((donation - 1) / 99, 0, 1)
        return (9 + (14 * (normalized ^ 0.8))) * lapBoost
    end

    local function getHelicopterRiseHeight(amount, minRiseHeight)
        local donation = math.max(1, tonumber(amount) or 1)
        local minimum = math.max(0, tonumber(minRiseHeight) or 0)
        return math.clamp(math.max(minimum, 18 + (math.sqrt(donation) * 7)), 26, 84)
    end

    local function getHelicopterSpinSpeedForAmount(amount)
        return math.min(48, 20 + (math.sqrt(math.max(1, tonumber(amount) or 1)) * 1.5))
    end

    local function applyHelicopterCFrame(root, position, spinYaw, forwardVector)
        if not root or not root.Parent then return end
        local direction = forwardVector or Vector3.new(0, 0, -1)
        if direction.Magnitude < 0.001 then
            direction = Vector3.new(0, 0, -1)
        end
        local baseYaw = math.atan2(-direction.Unit.X, -direction.Unit.Z)
        root.CFrame = CFrame.new(position) * CFrame.Angles(0, baseYaw + spinYaw, 0)
    end

    local function stopAstronautIdle()
        if currentAstronautIdleTrack then
            pcall(function() currentAstronautIdleTrack:Stop() end)
            pcall(function() currentAstronautIdleTrack:Destroy() end)
            currentAstronautIdleTrack = nil
        end
    end

    local function loadAstronautIdle()
        stopAstronautIdle()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        pcall(function()
            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                track:Stop()
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
            pcall(function() track:Play() end)
        end
    end

    local function getHelicopterBody(root)
        local body = root:FindFirstChild("HL1__HELI")
        if not (body and body:IsA("BodyAngularVelocity")) then
            body = Instance.new("BodyAngularVelocity")
            body.Name = "HL1__HELI"
            body.MaxTorque = Vector3.new(0, math.huge, 0)
            body.Parent = root
        end
        return body
    end

    local function stopHelicopterIdleTask()
        if currentHelicopterIdleTask then
            pcall(function() task.cancel(currentHelicopterIdleTask) end)
            currentHelicopterIdleTask = nil
        end
    end

    local function startHelicopterIdleMode()
        if not settings.helicopterEnabled then return false end
        local character, humanoid, root = getCharacterHumanoidRoot()
        if not (character and humanoid and root) then return false end
        loadAstronautIdle()
        local body = getHelicopterBody(root)
        stopHelicopterIdleTask()
        body.AngularVelocity = Vector3.new(0, 0, 0)
        currentHelicopterIdleTask = task.spawn(function()
            local rampDuration = 0.7
            local rampStart = tick()
            while tick() - rampStart < rampDuration and settings.helicopterEnabled and root.Parent do
                local t = math.clamp((tick() - rampStart) / rampDuration, 0, 1)
                if body.Parent then
                    body.AngularVelocity = Vector3.new(0, helicopterIdleSpinSpeed * (t * t), 0)
                end
                task.wait()
            end
            while settings.helicopterEnabled and root.Parent do
                if body.Parent then
                    body.AngularVelocity = Vector3.new(0, helicopterIdleSpinSpeed, 0)
                end
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end)
                task.wait()
            end
        end)
        pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
        return true
    end

    local function waitForHumanoidMove(humanoid, position, timeout, shouldContinue)
        local finished = false
        local reached = false
        local connection
        connection = humanoid.MoveToFinished:Connect(function(didReach)
            finished = true
            reached = didReach
        end)
        local ok = pcall(function() humanoid:MoveTo(position) end)
        if not ok then
            connection:Disconnect()
            return false
        end
        local start = tick()
        while not finished and tick() - start < timeout and (not shouldContinue or shouldContinue()) do
            task.wait()
        end
        connection:Disconnect()
        return finished and reached
    end

    local function startRobuxLapTask()
        if currentLapTask or currentHelicopterSpinTask or not settings.robuxLap or pendingLapCount <= 0 then
            return false
        end

        stopHelicopterIdleTask()
        stopAstronautIdle()
        local _, _, idleRoot = getCharacterHumanoidRoot()
        local idleBody = idleRoot and idleRoot:FindFirstChild("HL1__HELI")
        if idleBody and idleBody:IsA("BodyAngularVelocity") then
            idleBody.AngularVelocity = Vector3.new(0, 0, 0)
        end

        currentLapTask = task.defer(function()
            local activeHumanoid
            local originalWalkSpeed
            local interrupted = false

            while pendingLapCount > 0 and settings.robuxLap and not currentHelicopterSpinTask do
                pendingLapCount -= 1
                local character, humanoid, root = getCharacterHumanoidRoot()
                if not (character and humanoid and root) then
                    interrupted = true
                    pendingLapCount = 0
                    break
                end
                activeHumanoid = humanoid
                if not originalWalkSpeed then originalWalkSpeed = humanoid.WalkSpeed end
                humanoid.WalkSpeed = 50

                local routeY = root.Position.Y
                for waypointIndex = 1, #helicopterFlightRoute + 1 do
                    if not settings.robuxLap or character ~= LocalPlayer.Character or not root.Parent then
                        interrupted = true
                        break
                    end
                    local routeIndex = ((waypointIndex - 1) % #helicopterFlightRoute) + 1
                    local routePosition = helicopterFlightRoute[routeIndex].Position
                    local waypoint = Vector3.new(routePosition.X, routeY, routePosition.Z)
                    local distance = (root.Position - waypoint).Magnitude
                    local timeout = math.clamp((distance / math.max(1, humanoid.WalkSpeed)) + 6, 8, 24)
                    if not waitForHumanoidMove(humanoid, waypoint, timeout, function()
                        return settings.robuxLap and character == LocalPlayer.Character and root.Parent ~= nil
                    end) then
                        interrupted = true
                        break
                    end
                end
                if interrupted then
                    pendingLapCount = 0
                    break
                end
            end

            if not settings.robuxLap then
                pendingLapCount = 0
            end

            local character, humanoid, root = getCharacterHumanoidRoot()
            if character and humanoid and root then
                local standsFolder = Workspace:FindFirstChild("Stands") or Workspace:FindFirstChild("stands")
                if standsFolder then
                    for _, stand in ipairs(standsFolder:GetChildren()) do
                        if isStandOwned(stand) then
                            local returnPosition = computeStandPlacement(stand, root.Position, 4.5)
                            if returnPosition then
                                local distance = (root.Position - returnPosition).Magnitude
                                local timeout = math.clamp((distance / math.max(1, humanoid.WalkSpeed)) + 8, 10, 30)
                                waitForHumanoidMove(humanoid, returnPosition, timeout, function()
                                    return character == LocalPlayer.Character and root.Parent ~= nil
                                end)
                            end
                            break
                        end
                    end
                end
            end

            if activeHumanoid and activeHumanoid.Parent and originalWalkSpeed then
                activeHumanoid.WalkSpeed = originalWalkSpeed
            end
            currentLapTask = nil
            if pendingLapCount > 0 and settings.robuxLap and not currentHelicopterSpinTask then
                task.defer(startRobuxLapTask)
            elseif settings.helicopterEnabled and not currentHelicopterSpinTask then
                task.delay(0.08, startHelicopterIdleMode)
            end
        end)
        return true
    end

    local function restoreAnimateScript()
        if animateScriptToRestore and animateScriptToRestore.Parent and animateScriptWasEnabled ~= nil then
            animateScriptToRestore.Enabled = animateScriptWasEnabled
        end
        animateScriptToRestore = nil
        animateScriptWasEnabled = nil
    end

    local function stopHelicopterSpin()
        pendingHelicopterRaisedAmount = 0
        if currentHelicopterSpinTask then
            pcall(function() task.cancel(currentHelicopterSpinTask) end)
            currentHelicopterSpinTask = nil
        end
        stopHelicopterIdleTask()
        stopAstronautIdle()
        restoreAnimateScript()
        local _, _, root = getCharacterHumanoidRoot()
        local body = root and root:FindFirstChild("HL1__HELI")
        if body then
            body:Destroy()
        end
        if pendingLapCount > 0 and settings.robuxLap then
            task.defer(startRobuxLapTask)
        end
    end

    local function performHelicopterDonationSequence(raisedAmount)
        pendingHelicopterRaisedAmount += math.max(1, tonumber(raisedAmount) or 1)
        if currentHelicopterSpinTask then return true end

        currentHelicopterSpinTask = task.spawn(function()
            while currentLapTask and settings.helicopterEnabled do
                task.wait()
            end
            while pendingHelicopterRaisedAmount > 0 and settings.helicopterEnabled do
                local amount = math.max(1, tonumber(pendingHelicopterRaisedAmount) or 1)
                pendingHelicopterRaisedAmount = 0
                local character, humanoid, root = getCharacterHumanoidRoot()
                if not (character and humanoid and root) then break end
                stopHelicopterIdleTask()

                local ok, err = pcall(function()
                    loadAstronautIdle()
                    local animateScript = character:FindFirstChild("Animate")
                    if animateScript and animateScript:IsA("LocalScript") then
                        animateScriptToRestore = animateScript
                        animateScriptWasEnabled = animateScript.Enabled
                        animateScript.Enabled = false
                    end

                    local targetSpinSpeed = math.max(getHelicopterSpinSpeedForAmount(amount), helicopterTakeoffSpinSpeed)
                    local riseHeight = getHelicopterRiseHeight(amount, 24)
                    local flightDuration = getHelicopterFlightDuration(amount)
                    local prepTargetCF = getHelicopterTargetCFrame(root)
                    local baseIdleSpeed = helicopterIdleSpinSpeed
                    local body = getHelicopterBody(root)
                    body.AngularVelocity = Vector3.new(0, 0, 0)
                    local currentCF = root.CFrame
                    local currentPosition = currentCF.Position
                    local awayDirection = Vector3.new(prepTargetCF.LookVector.X, 0, prepTargetCF.LookVector.Z)
                    if awayDirection.Magnitude < 0.001 then awayDirection = Vector3.new(0, 0, -1) else awayDirection = awayDirection.Unit end
                    local hoverPosition = currentPosition + Vector3.new(0, 1.25, 0)
                    local facingTargetCF = CFrame.lookAt(hoverPosition, hoverPosition + awayDirection)
                    local prepStart = tick()
                    local turnDuration = 0.7
                    while tick() - prepStart < turnDuration and character.Parent and root.Parent and settings.helicopterEnabled do
                        local t = math.clamp((tick() - prepStart) / turnDuration, 0, 1)
                        local easedT = t * t * (3 - (2 * t))
                        root.CFrame = currentCF:Lerp(facingTargetCF, easedT)
                        body.AngularVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        task.wait()
                    end
                    root.CFrame = facingTargetCF

                    local startPos = hoverPosition
                    local yaw = 0
                    local lastFrameTick = tick()
                    if type(sendDonationThankYou) == "function" then
                        sendDonationThankYou(amount)
                    end
                    local countdownDuration = 3
                    local countdownStart = tick()
                    local nextCountdownNumber = 4
                    while tick() - countdownStart < countdownDuration and character.Parent and root.Parent and settings.helicopterEnabled do
                        local now = tick()
                        local elapsed = now - countdownStart
                        local dt = now - lastFrameTick
                        lastFrameTick = now
                        local t = math.clamp(elapsed / countdownDuration, 0, 1)
                        local spinSpeed = 0.45 + ((targetSpinSpeed - 0.45) * (t * t))
                        yaw += spinSpeed * dt
                        body.AngularVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        applyHelicopterCFrame(root, startPos, yaw, prepTargetCF.LookVector)
                        local countdownNumber = math.ceil(countdownDuration - elapsed)
                        if countdownNumber < nextCountdownNumber then
                            nextCountdownNumber = countdownNumber
                            local sent, sendError = sendChatMessage("TAKEOFF IN " .. countdownNumber .. "...")
                            if not sent then warn("[PLS WAIT] Could not send helicopter countdown:", sendError) end
                        end
                        task.wait()
                    end
                    if body.Parent then body:Destroy() end

                    local nearestRouteIndex = 1
                    local nearestRouteDistance = math.huge
                    for index, routePoint in ipairs(helicopterFlightRoute) do
                        local routePosition = routePoint.Position
                        local distance = Vector3.new(routePosition.X - startPos.X, 0, routePosition.Z - startPos.Z).Magnitude
                        if distance < nearestRouteDistance then
                            nearestRouteDistance = distance
                            nearestRouteIndex = index
                        end
                    end

                    local ascentStart = tick()
                    lastFrameTick = ascentStart
                    local finalTargetPos = startPos
                    local ascentTargetPos = startPos + Vector3.new(0, riseHeight, 0)
                    while tick() - ascentStart < 2.1 and character.Parent and root.Parent and settings.helicopterEnabled do
                        local now = tick()
                        local dt = now - lastFrameTick
                        lastFrameTick = now
                        local p = math.clamp((now - ascentStart) / 2.1, 0, 1)
                        local easedUp = 1 - ((1 - p) * (1 - p) * (1 - p))
                        finalTargetPos = startPos:Lerp(ascentTargetPos, easedUp)
                        local spinSpeed = targetSpinSpeed
                        yaw += spinSpeed * dt
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        applyHelicopterCFrame(root, finalTargetPos, yaw, prepTargetCF.LookVector)
                        task.wait()
                    end

                    local routeIndex = nearestRouteIndex
                    local routePosition = finalTargetPos
                    local routeFlightStart = tick()
                    lastFrameTick = routeFlightStart
                    local cruiseAnnounced = false
                    while tick() - routeFlightStart < flightDuration and character.Parent and root.Parent and settings.helicopterEnabled do
                        if pendingHelicopterRaisedAmount > 0 then
                            local bonusAmount = math.max(1, tonumber(pendingHelicopterRaisedAmount) or 1)
                            pendingHelicopterRaisedAmount = 0
                            flightDuration = math.min(130, flightDuration + math.max(8, getHelicopterFlightDuration(bonusAmount) * 0.25))
                            targetSpinSpeed = math.max(targetSpinSpeed, getHelicopterSpinSpeedForAmount(bonusAmount))
                            riseHeight = math.max(riseHeight, getHelicopterRiseHeight(bonusAmount, 24))
                        end
                        local nextIndex = (routeIndex % #helicopterFlightRoute) + 1
                        local nextBase = helicopterFlightRoute[nextIndex]
                        local nextBasePosition = nextBase.Position
                        local nextPos = Vector3.new(nextBasePosition.X, nextBasePosition.Y + riseHeight, nextBasePosition.Z)
                        local segmentDuration = math.clamp((nextPos - routePosition).Magnitude / 26, 0.9, 3.4)
                        local segmentStart = tick()
                        local segmentOrigin = routePosition
                        while tick() - segmentStart < segmentDuration and character.Parent and root.Parent
                            and settings.helicopterEnabled and tick() - routeFlightStart < flightDuration do
                            if pendingHelicopterRaisedAmount > 0 then break end
                            local now = tick()
                            local dt = now - lastFrameTick
                            lastFrameTick = now
                            local p = math.clamp((now - segmentStart) / segmentDuration, 0, 1)
                            local smoothP = p * p * (3 - (2 * p))
                            local segmentPos = segmentOrigin:Lerp(nextPos, smoothP)
                            local bob = math.sin((now - routeFlightStart) * 1.4) * 1.2
                            finalTargetPos = Vector3.new(segmentPos.X, segmentPos.Y + bob, segmentPos.Z)
                            local travelDir = Vector3.new(nextPos.X - segmentOrigin.X, 0, nextPos.Z - segmentOrigin.Z)
                            if travelDir.Magnitude < 0.001 then
                                travelDir = Vector3.new(0, 0, -1)
                            else
                                travelDir = travelDir.Unit
                            end
                            yaw += targetSpinSpeed * dt
                            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                            applyHelicopterCFrame(root, finalTargetPos, yaw, travelDir)
                            task.wait()
                        end
                        routePosition = nextPos
                        routeIndex = nextIndex
                        if not cruiseAnnounced then
                            sendChatMessage("Cruising the plaza...")
                            cruiseAnnounced = true
                        end
                    end

                    local landingTargetCF = getHelicopterTargetCFrame(root)
                    local landingPos = landingTargetCF.Position
                    local returnCruisePos = Vector3.new(
                        landingPos.X,
                        math.max(finalTargetPos.Y, landingPos.Y + math.min(24, riseHeight * 0.55)),
                        landingPos.Z
                    )
                    local returnOrigin = finalTargetPos
                    local returnDistance = (returnCruisePos - returnOrigin).Magnitude
                    local returnDuration = math.clamp(returnDistance / 30, 1.1, 4.2)
                    local returnStart = tick()
                    while tick() - returnStart < returnDuration and character.Parent and root.Parent and settings.helicopterEnabled do
                        local now = tick()
                        local dt = now - lastFrameTick
                        lastFrameTick = now
                        local p = math.clamp((now - returnStart) / returnDuration, 0, 1)
                        local smoothP = p * p * (3 - (2 * p))
                        finalTargetPos = returnOrigin:Lerp(returnCruisePos, smoothP)
                        local travelDir = Vector3.new(returnCruisePos.X - returnOrigin.X, 0, returnCruisePos.Z - returnOrigin.Z)
                        if travelDir.Magnitude < 0.001 then
                            travelDir = landingTargetCF.LookVector
                        else
                            travelDir = travelDir.Unit
                        end
                        yaw += targetSpinSpeed * dt
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        applyHelicopterCFrame(root, finalTargetPos, yaw, travelDir)
                        task.wait()
                    end
                    finalTargetPos = returnCruisePos

                    local landingStart = tick()
                    local descentOrigin = finalTargetPos
                    local landingDuration = 1.8
                    while tick() - landingStart < landingDuration and character.Parent and root.Parent and settings.helicopterEnabled do
                        local now = tick()
                        local dt = now - lastFrameTick
                        lastFrameTick = now
                        local p = math.clamp((now - landingStart) / landingDuration, 0, 1)
                        local smoothP = p * p * (3 - (2 * p))
                        finalTargetPos = descentOrigin:Lerp(landingPos, smoothP)
                        local spinSpeed = targetSpinSpeed + ((baseIdleSpeed - targetSpinSpeed) * smoothP)
                        yaw += spinSpeed * dt
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        applyHelicopterCFrame(root, finalTargetPos, yaw, landingTargetCF.LookVector)
                        task.wait()
                    end
                    if settings.helicopterEnabled and root.Parent then
                        root.CFrame = landingTargetCF
                    end
                    restoreAnimateScript()
                end)
                if not ok then
                    warn("[PLS WAIT] Helicopter burst failed:", err)
                    pendingHelicopterRaisedAmount = 0
                    restoreAnimateScript()
                    break
                end
            end

            currentHelicopterSpinTask = nil
            if pendingLapCount > 0 and settings.robuxLap then
                startRobuxLapTask()
            elseif settings.helicopterEnabled then
                task.delay(0.08, startHelicopterIdleMode)
            end
        end)
        return true
    end

    local function ensureHelicopter()
        if not settings.helicopterEnabled then return false end
        return startHelicopterIdleMode()
    end

    local function setHelicopterEnabled(enabled)
        settings.helicopterEnabled = enabled == true
        if settings.helicopterEnabled then
            return ensureHelicopter()
        end
        stopHelicopterSpin()
        return true
    end

    local function applyDonationHelicopter(delta)
        if not settings.helicopterEnabled or type(delta) ~= "number" or delta <= 0 then return false end
        return performHelicopterDonationSequence(delta)
    end

    local function applyDonationLap(delta)
        if not settings.robuxLap or type(delta) ~= "number" or delta <= 0 then return false end
        pendingLapCount += math.max(1, math.floor(delta))
        if currentHelicopterSpinTask or currentLapTask then return true end
        return startRobuxLapTask()
    end

    local function ensureSpinPart(character)
        if not settings.spinSet then return end
        local char = character or LocalPlayer.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if not root and char == LocalPlayer.Character then
            root = char:WaitForChild("HumanoidRootPart", 10)
            if not root then
                root = char:FindFirstChild("Torso")
            end
        end
        if not settings.spinSet or char ~= LocalPlayer.Character or not root then return end

        if root.AssemblyLinearVelocity then
            root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        end

        local spinPart = root:FindFirstChild("Spin")
        if not (spinPart and spinPart:IsA("BodyAngularVelocity")) then
            spinPart = Instance.new("BodyAngularVelocity")
            spinPart.Name = "Spin"
            spinPart.MaxTorque = Vector3.new(0, math.huge, 0)
            spinPart.Parent = root
        end
        spinPart.AngularVelocity = Vector3.new(0, 0.25 * (settings.spinSpeedMultiplier or 1), 0)
    end

    local function applyDonationSpin(delta)
        if not settings.spinSet or type(delta) ~= "number" or delta <= 0 then return end
        local char = LocalPlayer.Character
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
        if not root then return end

        local spinPart = root:FindFirstChild("Spin")
        if not (spinPart and spinPart:IsA("BodyAngularVelocity")) then
            ensureSpinPart(char)
            spinPart = root:FindFirstChild("Spin")
        end
        if not (spinPart and spinPart:IsA("BodyAngularVelocity")) then return end

        local currentY = tonumber(spinPart.AngularVelocity.Y) or 0
        spinPart.AngularVelocity = Vector3.new(
            0,
            currentY + (delta / 3) * (settings.spinSpeedMultiplier or 1),
            0
        )
        pcall(function()
            notify("Donation Debug", ("spin updated +%d -> %0.2f"):format(delta, spinPart.AngularVelocity.Y), 4)
        end)
    end

    local function startBoothReturnMonitor()
        task.spawn(function()
            while true do
                task.wait(5)
                if settings.spinSet and not currentHelicopterSpinTask then
                    local character = LocalPlayer.Character
                    local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
                    local standsFolder = Workspace:FindFirstChild("Stands") or Workspace:FindFirstChild("stands")
                    if root and standsFolder then
                        for _, stand in ipairs(standsFolder:GetChildren()) do
                            if isStandOwned(stand) then
                                local standPosition = getStandPosition(stand)
                                if standPosition and (root.Position - standPosition).Magnitude > returnDistance then
                                    local returnPosition, awayDirection = computeStandPlacement(stand, root.Position, 4.5)
                                    if returnPosition then
                                        moveCharacterToPosition(returnPosition, "teleport", awayDirection)
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
        end)
    end

    return {
        ensureSpinPart = ensureSpinPart,
        applyDonationSpin = applyDonationSpin,
        startBoothReturnMonitor = startBoothReturnMonitor,
        applyDonationHelicopter = applyDonationHelicopter,
        applyDonationLap = applyDonationLap,
        setHelicopterEnabled = setHelicopterEnabled,
        ensureHelicopter = ensureHelicopter,
    }
end

return Spin
