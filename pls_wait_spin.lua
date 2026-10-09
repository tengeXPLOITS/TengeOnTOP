local Spin = {}

function Spin.create(dependencies)
    assert(type(dependencies) == "table", "spin dependencies are required")
    local LocalPlayer = assert(dependencies.LocalPlayer, "LocalPlayer is required")
    local Workspace = assert(dependencies.Workspace, "Workspace is required")
    local settings = assert(dependencies.settings, "settings table is required")
    local isStandOwned = assert(dependencies.isStandOwned, "stand ownership helper is required")
    local getStandPosition = assert(dependencies.getStandPosition, "stand-position helper is required")
    local computeStandPlacement = assert(dependencies.computeStandPlacement, "stand-placement helper is required")
    local moveCharacterToPosition = assert(dependencies.moveCharacterToPosition, "character-movement helper is required")
    local notify = assert(dependencies.notify, "notification function is required")

    local returnDistance = 12

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
    }
end

return Spin
