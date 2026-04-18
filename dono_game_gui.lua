-- Minimal Donate Game GUI

if not game then return end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- Simple GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DonateGameGUI"
gui.Parent = LocalPlayer.PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 250, 0, 150)
main.Position = UDim2.new(0.5, -125, 0.5, -75)
main.BackgroundColor3 = Color3.new(0.5, 0.2, 0)
main.BorderSizePixel = 2
main.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.new(0.8, 0.3, 0.3)
title.Text = "DONATE GAME"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Parent = main

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -30)
content.Position = UDim2.new(0, 0, 0, 30)
content.BackgroundTransparency = 1
content.Parent = main

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 5)
layout.Parent = content

-- Spin Toggle
local spinBtn = Instance.new("TextButton")
spinBtn.Size = UDim2.new(1, -10, 0, 30)
spinBtn.BackgroundColor3 = Color3.new(1, 0.5, 0)
spinBtn.Text = "Spin: OFF"
spinBtn.TextColor3 = Color3.new(1, 1, 1)
spinBtn.Font = Enum.Font.SourceSansBold
spinBtn.TextSize = 14
spinBtn.Parent = content

local spinOn = false
spinBtn.MouseButton1Click:Connect(function()
    spinOn = not spinOn
    spinBtn.Text = "Spin: " .. (spinOn and "ON" or "OFF")
    spinBtn.BackgroundColor3 = spinOn and Color3.new(0, 1, 0) or Color3.new(1, 0.5, 0)

    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local spin = root:FindFirstChild("Spin")
            if spinOn then
                if not spin then
                    spin = Instance.new("BodyAngularVelocity")
                    spin.Name = "Spin"
                    spin.MaxTorque = Vector3.new(0, 400000, 0)
                    spin.AngularVelocity = Vector3.new(0, 10, 0)
                    spin.Parent = root
                end
            else
                if spin then spin:Destroy() end
            end
        end
    end
end)

-- Helicopter Toggle
local heliBtn = Instance.new("TextButton")
heliBtn.Size = UDim2.new(1, -10, 0, 30)
heliBtn.BackgroundColor3 = Color3.new(1, 0.5, 0)
heliBtn.Text = "Helicopter: OFF"
heliBtn.TextColor3 = Color3.new(1, 1, 1)
heliBtn.Font = Enum.Font.SourceSansBold
heliBtn.TextSize = 14
heliBtn.Parent = content

local heliOn = false
heliBtn.MouseButton1Click:Connect(function()
    heliOn = not heliOn
    heliBtn.Text = "Helicopter: " .. (heliOn and "ON" or "OFF")
    heliBtn.BackgroundColor3 = heliOn and Color3.new(0, 1, 0) or Color3.new(1, 0.5, 0)

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = hum and hum.RootPart
        if root then
            local heli = root:FindFirstChild("Heli")
            if heliOn then
                if not heli then
                    heli = Instance.new("BodyAngularVelocity")
                    heli.Name = "Heli"
                    heli.MaxTorque = Vector3.new(0, 400000, 0)
                    heli.AngularVelocity = Vector3.new(0, 5, 0)
                    heli.Parent = root
                end
                -- Send emote
                local chat = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
                if chat then
                    local say = chat:FindFirstChild("SayMessageRequest")
                    if say then
                        say:FireServer("/e dance2", "All")
                    end
                end
            else
                if heli then heli:Destroy() end
            end
        end
    end
end)

-- Dragging
local dragging = false
local dragStart, startPos

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

return gui
