local Spin = {}

function Spin.create(dependencies)
    assert(type(dependencies) == "table", "spin dependencies are required")
    local LocalPlayer = assert(dependencies.LocalPlayer, "LocalPlayer is required")
    local Workspace = assert(dependencies.Workspace, "Workspace is required")
    local settings = assert(dependencies.settings, "settings table is required")
    local sendChatMessage = assert(dependencies.sendChatMessage, "chat sender is required")
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
    local currentAstronautIdleTrack
    local pendingHelicopterRaisedAmount = 0
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
        local baseYaw = math.atan2(direction.Unit.X, direction.Unit.Z)
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
    end

    local function performHelicopterDonationSequence(raisedAmount)
        pendingHelicopterRaisedAmount += math.max(1, tonumber(raisedAmount) or 1)
        if currentHelicopterSpinTask then return true end

        currentHelicopterSpinTask = task.spawn(function()
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
                    local holdCF = root.CFrame
                    local holdStart = tick()
                    while tick() - holdStart < 0.08 and character.Parent and root.Parent and settings.helicopterEnabled do
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        root.CFrame = holdCF
                        task.wait()
                    end

                    local prepStart = tick()
                    while tick() - prepStart < 0.3 and character.Parent and root.Parent and settings.helicopterEnabled do
                        local t = math.clamp((tick() - prepStart) / 0.3, 0, 1)
                        local easedT = 1 - ((1 - t) * (1 - t))
                        root.CFrame = holdCF:Lerp(prepTargetCF, easedT)
                        body.AngularVelocity = Vector3.new(0, baseIdleSpeed + (1.25 * easedT), 0)
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        task.wait()
                    end
                    root.CFrame = prepTargetCF

                    local startPos = prepTargetCF.Position
                    local yaw = 0
                    local lastFrameTick = tick()
                    for count = 3, 1, -1 do
                        if not settings.helicopterEnabled or not character.Parent or not root.Parent then break end
                        local sent, sendError = sendChatMessage("TAKEOFF IN " .. count .. "...")
                        if not sent then warn("[PLS WAIT] Could not send helicopter countdown:", sendError) end
                        task.wait(0.55)
                    end

                    local spoolStart = tick()
                    while tick() - spoolStart < 1.4 and character.Parent and root.Parent and settings.helicopterEnabled do
                        local now = tick()
                        local dt = now - lastFrameTick
                        lastFrameTick = now
                        local t = math.clamp((now - spoolStart) / 1.4, 0, 1)
                        local spoolFromSpeed = math.max(0.35, baseIdleSpeed * 0.7)
                        local spinSpeed = spoolFromSpeed + ((targetSpinSpeed - spoolFromSpeed) * (t * t * t))
                        yaw += spinSpeed * dt
                        body.AngularVelocity = Vector3.new(0, spinSpeed, 0)
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        applyHelicopterCFrame(root, startPos, yaw, prepTargetCF.LookVector)
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
                    while tick() - ascentStart < 2.1 and character.Parent and root.Parent and settings.helicopterEnabled do
                        local now = tick()
                        local dt = now - lastFrameTick
                        lastFrameTick = now
                        local p = math.clamp((now - ascentStart) / 2.1, 0, 1)
                        local easedUp = p * p
                        finalTargetPos = Vector3.new(startPos.X, startPos.Y + (riseHeight * easedUp), startPos.Z)
                        local spinSpeed = baseIdleSpeed + ((targetSpinSpeed - baseIdleSpeed) * (0.25 + (easedUp * 0.75)))
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
                    local landingStart = tick()
                    local descentOrigin = finalTargetPos
                    while tick() - landingStart < 1.1 and character.Parent and root.Parent and settings.helicopterEnabled do
                        local now = tick()
                        local dt = now - lastFrameTick
                        lastFrameTick = now
                        local p = math.clamp((now - landingStart) / 1.1, 0, 1)
                        local smoothP = p * p * (3 - (2 * p))
                        finalTargetPos = Vector3.new(landingPos.X, descentOrigin.Y + ((landingPos.Y - descentOrigin.Y) * smoothP), landingPos.Z)
                        local spinSpeed = baseIdleSpeed + ((targetSpinSpeed - baseIdleSpeed) * (1 - smoothP))
                        yaw += spinSpeed * dt
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        applyHelicopterCFrame(root, finalTargetPos, yaw, Vector3.new(0, -1, 0))
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
            if settings.helicopterEnabled then
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
        setHelicopterEnabled = setHelicopterEnabled,
        ensureHelicopter = ensureHelicopter,
    }
end

return Spin
