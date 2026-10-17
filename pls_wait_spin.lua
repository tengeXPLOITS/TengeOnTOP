local Spin = {}

function Spin.create(dependencies)
    assert(type(dependencies) == "table", "spin dependencies are required")
    local LocalPlayer = assert(dependencies.LocalPlayer, "LocalPlayer is required")
    local Workspace = assert(dependencies.Workspace, "Workspace is required")
    local TweenService = assert(dependencies.TweenService, "TweenService is required")
    local settings = assert(dependencies.settings, "settings table is required")
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
        platform.Size = Vector3.new(12, 1, 12)
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
        if not settings.helicopterEnabled or type(delta) ~= "number" or delta <= 0 then return end
        pendingHelicopterRaise += delta
        if helicopterAnimationRunning then return end
        helicopterAnimationRunning = true

        task.spawn(function()
            while settings.helicopterEnabled and pendingHelicopterRaise > 0 do
                local raised = pendingHelicopterRaise
                pendingHelicopterRaise = 0
                if not ensureHelicopter() then break end

                local generation = helicopterGeneration
                local platform = helicopterPlatform
                local rotor = helicopterRotor
                local root = helicopterRoot
                if not (platform and rotor and root) then break end

                local baseCFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0))
                platform.CFrame = baseCFrame
                local liftHeight = math.clamp(raised * 2, 3, 24)
                local rise = TweenService:Create(platform, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    CFrame = baseCFrame + Vector3.new(0, liftHeight, 0),
                })
                local speedUp = TweenService:Create(rotor, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    AngularVelocity = Vector3.new(0, 25, 0),
                })
                helicopterTweens = { rise, speedUp }
                rise:Play()
                speedUp:Play()
                rise.Completed:Wait()

                if settings.helicopterEnabled and generation == helicopterGeneration
                    and platform.Parent and rotor.Parent then
                    local descend = TweenService:Create(platform, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                        CFrame = baseCFrame,
                    })
                    local slowDown = TweenService:Create(rotor, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        AngularVelocity = Vector3.new(0, 1, 0),
                    })
                    helicopterTweens = { descend, slowDown }
                    descend:Play()
                    slowDown:Play()
                    descend.Completed:Wait()
                end

                if generation == helicopterGeneration then
                    table.clear(helicopterTweens)
                end
            end
            helicopterAnimationRunning = false
        end)
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
