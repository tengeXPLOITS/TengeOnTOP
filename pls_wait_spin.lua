local Spin = {}

function Spin.create(dependencies)
    assert(type(dependencies) == "table", "spin dependencies are required")
    local LocalPlayer = assert(dependencies.LocalPlayer, "LocalPlayer is required")
    local Workspace = assert(dependencies.Workspace, "Workspace is required")
    local TweenService = assert(dependencies.TweenService, "TweenService is required")
    local settings = assert(dependencies.settings, "settings table is required")
    local sendChatMessage = assert(dependencies.sendChatMessage, "chat sender is required")
    local isStandOwned = assert(dependencies.isStandOwned, "stand ownership helper is required")
    local getStandPosition = assert(dependencies.getStandPosition, "stand-position helper is required")
    local computeStandPlacement = assert(dependencies.computeStandPlacement, "stand-placement helper is required")
    local moveCharacterToPosition = assert(dependencies.moveCharacterToPosition, "character-movement helper is required")
    local notify = assert(dependencies.notify, "notification function is required")

    local returnDistance = 12
    local helicopterPlatform
    local helicopterRotor
    local helicopterRoot
    local helicopterTweens = {}
    local helicopterGeneration = 0
    local pendingHelicopterRaise = 0
    local helicopterAnimationRunning = false

    local function stopHelicopter()
        helicopterGeneration += 1
        pendingHelicopterRaise = 0
        for _, tween in ipairs(helicopterTweens) do
            tween:Cancel()
        end
        table.clear(helicopterTweens)
        if helicopterRotor then helicopterRotor:Destroy() end
        if helicopterPlatform then helicopterPlatform:Destroy() end
        helicopterRotor = nil
        helicopterPlatform = nil
        helicopterRoot = nil
    end

    local function ensureHelicopter()
        if not settings.helicopterEnabled then
            stopHelicopter()
            return false
        end

        local character = LocalPlayer.Character
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
        if not root then return false end
        if helicopterRoot == root and helicopterPlatform and helicopterPlatform.Parent
            and helicopterRotor and helicopterRotor.Parent then
            return true
        end

        stopHelicopter()
        helicopterGeneration += 1
        helicopterRoot = root

        local rotor = Instance.new("BodyAngularVelocity")
        rotor.Name = "DonationHelicopterRotor"
        rotor.MaxTorque = Vector3.new(0, math.huge, 0)
        rotor.AngularVelocity = Vector3.new(0, 1, 0)
        rotor.Parent = root
        helicopterRotor = rotor

        local platform = Instance.new("Part")
        platform.Name = "DonationHelicopterPlatform"
        platform.Size = Vector3.new(20, 2, 20)
        platform.Anchored = true
        platform.CanCollide = true
        platform.CanTouch = false
        platform.CanQuery = false
        platform.Material = Enum.Material.Neon
        platform.Color = Color3.fromRGB(92, 255, 172)
        platform.Transparency = 0.3
        platform.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0))
        platform.Parent = Workspace
        helicopterPlatform = platform
        return true
    end

    local function setHelicopterEnabled(enabled)
        settings.helicopterEnabled = enabled == true
        if settings.helicopterEnabled then
            ensureHelicopter()
        else
            stopHelicopter()
        end
    end

    local function applyDonationHelicopter(delta)
        if not settings.helicopterEnabled or type(delta) ~= "number" or delta <= 0 then return false end
        print(("[PLS WAIT] Helicopter sequence triggered by Raised increase (+%.2f)."):format(delta))
        pendingHelicopterRaise += delta
        if helicopterAnimationRunning then return true end
        helicopterAnimationRunning = true

        task.spawn(function()
            local ok, err = pcall(function()
                local function isCurrent(generation)
                    return settings.helicopterEnabled and helicopterGeneration == generation
                end

                local function waitWhileEnabled(duration, generation)
                    local deadline = os.clock() + duration
                    while isCurrent(generation) and os.clock() < deadline do
                        task.wait(math.min(0.1, deadline - os.clock()))
                    end
                    return isCurrent(generation)
                end

                local function announce(message)
                    local sent, sendError = sendChatMessage(message)
                    if not sent then
                        warn("[PLS WAIT] Could not send helicopter countdown message:", sendError)
                    end
                end

                while settings.helicopterEnabled and pendingHelicopterRaise > 0 do
                    local raised = pendingHelicopterRaise
                    pendingHelicopterRaise = 0
                    local ready = ensureHelicopter()
                    local readyDeadline = os.clock() + 10
                    while not ready and settings.helicopterEnabled and os.clock() < readyDeadline do
                        task.wait(0.1)
                        ready = ensureHelicopter()
                    end
                    if not ready then
                        warn("[PLS WAIT] Helicopter sequence could not start: character root part was unavailable.")
                        break
                    end

                    local generation = helicopterGeneration
                    local platform = helicopterPlatform
                    local rotor = helicopterRotor
                    if not (platform and rotor) then
                        warn("[PLS WAIT] Helicopter sequence could not start: platform or rotor is missing.")
                        break
                    end

                    local character = LocalPlayer.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
                    if not (humanoid and root) then
                        warn("[PLS WAIT] Helicopter sequence could not start: character or humanoid is unavailable.")
                        break
                    end
                    platform.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0))
                    print("[PLS WAIT] Helicopter engine start; countdown begins after rotor spin-up.")
                    announce("Enabling engines...")
                    local emoteSent, emoteError = sendChatMessage("/e dance2")
                    if not emoteSent then
                        warn("[PLS WAIT] Could not start helicopter emote:", emoteError)
                    end
                    if not waitWhileEnabled(3, generation) then break end

                    local spinUp = TweenService:Create(rotor, TweenInfo.new(6, Enum.EasingStyle.Linear), {
                        AngularVelocity = Vector3.new(0, 25, 0),
                    })
                    helicopterTweens = { spinUp }
                    spinUp:Play()
                    if not waitWhileEnabled(4, generation) then break end

                    print("[PLS WAIT] Helicopter countdown started.")
                    announce("TAKEOFF IN 3")
                    if not waitWhileEnabled(1, generation) then break end
                    announce("2")
                    if not waitWhileEnabled(1, generation) then break end
                    announce("1")
                    if not waitWhileEnabled(1, generation) then break end
                    if not (platform.Parent and rotor.Parent) then break end

                    local baseCFrame = platform.CFrame
                    local liftHeight = raised * 5
                    print(("[PLS WAIT] Helicopter lift started: Raised delta %.2f, height %.2f studs."):format(raised, liftHeight))
                    local rise = TweenService:Create(platform, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        CFrame = baseCFrame + Vector3.new(0, liftHeight, 0),
                    })
                    helicopterTweens = { rise }
                    rise:Play()
                    local riseState = rise.Completed:Wait()
                    if riseState ~= Enum.PlaybackState.Completed or not isCurrent(generation)
                        or not (platform.Parent and rotor.Parent) then
                        break
                    end

                    local descend = TweenService:Create(platform, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        CFrame = baseCFrame,
                    })
                    local slowDown = TweenService:Create(rotor, TweenInfo.new(6, Enum.EasingStyle.Linear), {
                        AngularVelocity = Vector3.new(0, 1, 0),
                    })
                    helicopterTweens = { descend, slowDown }
                    descend:Play()
                    slowDown:Play()
                    local descendState = descend.Completed:Wait()
                    if descendState ~= Enum.PlaybackState.Completed or not isCurrent(generation) then
                        break
                    end

                    table.clear(helicopterTweens)
                    if humanoid and character == LocalPlayer.Character then
                        local emoteSent, emoteError = sendChatMessage("/e wave")
                        if not emoteSent then
                            warn("[PLS WAIT] Could not send helicopter landing emote:", emoteError)
                        end
                    end
                end
            end)
            if not ok then
                warn("[PLS WAIT] Helicopter sequence failed:", err)
            end
            table.clear(helicopterTweens)
            helicopterAnimationRunning = false
            if settings.helicopterEnabled and pendingHelicopterRaise > 0 then
                local queuedRaise = pendingHelicopterRaise
                pendingHelicopterRaise = 0
                applyDonationHelicopter(queuedRaise)
            end
        end)
        return true
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
                if settings.spinSet then
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
