local Config = {
	defaults = {
		textUpdateToggle = true,
		customBoothText = "Please help me reach my goal! || Goal: $G",
		goalBarHeaderText = "GOAL $G",
		goalBarColor = "blue",
		standingPosition = "Front",
		boothMovementMode = "Teleport",
		autoThanks = true,
		thanksDelay = 3,
		thanksMessage = {"Thank you", "Thankss!", "ty"},
		autoBeg = true,
		begDelay = 300,
		begMessage = {"Grateful for any donation", "Please help me reach my goal!", "Anything helps, thank you!"},
		catalogEmote = "Disabled",
		animSpeedSetting = 1,
		animSpeedMultiplier = 1,
		animSpeedPerRobux = false,
		webhookToggle = false,
		webhookBox = "",
		notifyPerHopToggle = false,
		antiAfkToggle = false,
		spinSet = false,
		spinSpeedMultiplier = 0.25,
		serverHopToggle = true,
		serverHopDelay = 15,
		populationHopToggle = false,
		populationHopThreshold = 15,
		plusHopToggle = false,
		plusMemberTarget = 3,
		modEvader = false,
		minPlayerCount = 23,
		maxPlayerCount = 24,
		vcServerHopToggle = false,
		helicopterEnabled = false,
		testDonationAmount = 6,
	},
}

Config.placeProfiles = {
	defaultPlaceId = 8737602449,
	vcPlaceId = 8943844393,
	extraPlaceId = 127213917680436,
	extraBoothPlacement = {
		forwardDistance = 4,
		heightOffset = 2,
	},
}

Config.emoteOptions = {
	"Disabled",
	"sturdy",
	"jumping wave",
	"wake up call-ksi",
	"twice the feels",
	"louder",
	"low cortisol",
	"zesty sturdy",
	"korean greeting",
	"block party",
    "quiet waves",
    "sad",
    "side to side",
    "trackmaker",

}

Config.emotes = {
	["sturdy"] = "102571052202995",
	["jumping wave"] = "10714378156",
	["wake up call-ksi"] = "10714168145",
	["twice the feels"] = "12874447851",
	["louder"] = "10714385204",
	["low cortisol"] = "77387643699357",
	["zesty sturdy"] = "132104757386824",
	["korean greeting"] = "138591721528570",
	["block party"] = "10713988674",
    ["quiet waves"] = "10714390497",
    ["sad"] = "10714392876",
    ["side to side"] = "10714366910",
    ["trackmaker"] = "135924994802775",
}

function Config.create(dependencies)
	local Players = game:GetService("Players")
	local LocalPlayer = dependencies.LocalPlayer or Players.LocalPlayer
	local settings = assert(dependencies.settings, "settings table is required")
	local getClaimedBoothSlot = dependencies.getClaimedBoothSlot or function() return nil end
	local getBoothTargetCFrameForStand = assert(dependencies.getBoothTargetCFrameForStand, "booth target helper is required")
	local sendChatMessage = assert(dependencies.sendChatMessage, "chat sender is required")
	local antiAfkConnection
	local currentHelicopterSpinTask
	local currentAstronautIdleTrack
	local currentIdleTask
	local pendingHelicopterRaisedAmount = 0
	local spinVelocityAccumulator = 0

	local function setAntiAfkEnabled(enabled)
		if antiAfkConnection then
			antiAfkConnection:Disconnect()
			antiAfkConnection = nil
		end
		if not enabled then
			return
		end
		local virtualUser = game:GetService("VirtualUser")
		antiAfkConnection = LocalPlayer.Idled:Connect(function()
			pcall(function()
				virtualUser:CaptureController()
				virtualUser:ClickButton2(Vector2.new())
			end)
		end)
	end

	local currentCatalogEmoteTrack
	local donationAnimSpeedBoost = 0

	local function getAppliedAnimSpeed()
		local speed = math.clamp(tonumber(settings.animSpeedSetting) or 1, 1, 100)
		if settings.animSpeedPerRobux then
			speed += math.max(0, tonumber(donationAnimSpeedBoost) or 0)
		end
		return math.clamp(speed, 1, 1000)
	end

	local function applyCurrentAnimSpeed()
		if not currentCatalogEmoteTrack then
			return
		end
		local speed = getAppliedAnimSpeed()
		pcall(function()
			if typeof(currentCatalogEmoteTrack.AdjustSpeed) == "function" then
				currentCatalogEmoteTrack:AdjustSpeed(speed)
			elseif currentCatalogEmoteTrack.PlaybackSpeed ~= nil then
				currentCatalogEmoteTrack.PlaybackSpeed = speed
			end
		end)
	end

	local function resetDonationAnimSpeedBoost()
		donationAnimSpeedBoost = 0
		applyCurrentAnimSpeed()
	end

	local function addDonationAnimSpeed(amount)
		if not settings.animSpeedPerRobux then
			return false
		end

		local multiplier = math.max(0, tonumber(settings.animSpeedMultiplier) or 1)
		local increasedBoost = donationAnimSpeedBoost + (math.max(0, tonumber(amount) or 0) * multiplier)
		local rawBoost = math.floor((increasedBoost * 100) + 0.5) / 100
		local baseSpeed = math.clamp(tonumber(settings.animSpeedSetting) or 1, 1, 100)
		local maxBoost = math.max(0, 1000 - baseSpeed)
		local reachedCap = rawBoost >= maxBoost and maxBoost > 0

		if reachedCap then
			donationAnimSpeedBoost = 0
			settings.animSpeedSetting = 1
		else
			donationAnimSpeedBoost = math.clamp(rawBoost, 0, maxBoost)
		end
		applyCurrentAnimSpeed()
		return reachedCap
	end

			local function stopCatalogEmoteTrack()
				if currentCatalogEmoteTrack then
					pcall(function() currentCatalogEmoteTrack:Stop() end)
					pcall(function() currentCatalogEmoteTrack:Destroy() end)
					currentCatalogEmoteTrack = nil
				end
			end

			local function playCatalogEmoteByName(name)
				local emoteName = tostring(name or "Disabled")
				if emoteName == "Disabled" then
					stopCatalogEmoteTrack()
					return false, "disabled"
				end

				local assetId = Config.emotes[emoteName]
				if not assetId then
					return false, "missing-emote"
				end

				local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					return false, "missing-humanoid"
				end

				local animator = humanoid:FindFirstChildOfClass("Animator")
				if not animator then
					animator = Instance.new("Animator")
					animator.Parent = humanoid
				end

				stopCatalogEmoteTrack()
				local animation = Instance.new("Animation")
				animation.AnimationId = "rbxassetid://" .. assetId
				local loadOk, track = pcall(function()
					return animator:LoadAnimation(animation)
				end)
				animation:Destroy()
				if not loadOk or not track then
					return false, "load-failed"
				end

				currentCatalogEmoteTrack = track
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = true
				local playOk = pcall(function() track:Play() end)
				if not playOk then
					stopCatalogEmoteTrack()
					return false, "play-failed"
				end
				applyCurrentAnimSpeed()

				return true, "playing"
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
		if not humanoid then
			return
		end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		pcall(function()
			for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
				if track ~= currentAstronautIdleTrack then
					track:Stop()
				end
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

	local function stopHelicopterSpin()
		pendingHelicopterRaisedAmount = 0
		if currentHelicopterSpinTask then
			pcall(function() task.cancel(currentHelicopterSpinTask) end)
			currentHelicopterSpinTask = nil
		end
		stopAstronautIdle()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		local heliBody = root and root:FindFirstChild("HL1__HELI")
		if heliBody then
			pcall(function() heliBody:Destroy() end)
		end
	end

	local HELICOPTER_IDLE_SPIN_SPEED = 2.7
	local HELICOPTER_TAKEOFF_SPIN_SPEED = 14
	local SPIN_DONATION_BASE_SPEED = 0.25
	local HELICOPTER_PLAZA_ROUTE = {
		Vector3.new(166.584, 0, 371.398),
		Vector3.new(228.765, 0, 332.55),
		Vector3.new(225.878, 0, 274.96),
		Vector3.new(169.654, 0, 232.826),
		Vector3.new(102.625, 0, 274.941),
		Vector3.new(109.353, 0, 351.28),
		Vector3.new(166.584, 0, 371.399),
	}

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
		local targetHeight = 18 + (math.sqrt(donation) * 7)
		return math.clamp(math.max(minimum, targetHeight), 26, 84)
	end

	local function getHelicopterSpinSpeedForAmount(amount)
		local donation = math.max(1, tonumber(amount) or 1)
		return math.min(48, 20 + (math.sqrt(donation) * 1.5))
	end

	local function applyHelicopterCFrame(root, position, spinYaw, forwardVector)
		if not root or not root.Parent then
			return
		end
		local direction = forwardVector or Vector3.new(0, 0, -1)
		if direction.Magnitude < 0.001 then
			direction = Vector3.new(0, 0, -1)
		end
		local baseYaw = math.atan2(direction.Unit.X, direction.Unit.Z)
		root.CFrame = CFrame.new(position) * CFrame.Angles(0, baseYaw + spinYaw, 0)
	end

	local function stopHelicopterIdleTask()
		if currentIdleTask then
			pcall(function() task.cancel(currentIdleTask) end)
			currentIdleTask = nil
		end
	end

	local function startHelicopterIdleMode()
		if not settings.helicopterEnabled then
			return
		end
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if not root then
			return
		end
		loadAstronautIdle()
		local heliBody = root:FindFirstChild("HL1__HELI")
		if not (heliBody and heliBody:IsA("BodyAngularVelocity")) then
			heliBody = Instance.new("BodyAngularVelocity")
			heliBody.Name = "HL1__HELI"
			heliBody.MaxTorque = Vector3.new(0, math.huge, 0)
			heliBody.Parent = root
		end
		stopHelicopterIdleTask()
		heliBody.AngularVelocity = Vector3.new(0, 0, 0)
		currentIdleTask = task.spawn(function()
			local rampDuration = 0.7
			local rampStart = tick()
			while tick() - rampStart < rampDuration and settings.helicopterEnabled and root.Parent do
				local t = math.clamp((tick() - rampStart) / rampDuration, 0, 1)
				if heliBody and heliBody.Parent then
					heliBody.AngularVelocity = Vector3.new(0, HELICOPTER_IDLE_SPIN_SPEED * (t * t), 0)
				end
				task.wait()
			end
			if heliBody and heliBody.Parent then
				heliBody.AngularVelocity = Vector3.new(0, HELICOPTER_IDLE_SPIN_SPEED, 0)
			end
			while settings.helicopterEnabled and root.Parent do
				if heliBody and heliBody.Parent then
					heliBody.AngularVelocity = Vector3.new(0, HELICOPTER_IDLE_SPIN_SPEED, 0)
				end
				pcall(function()
					root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				end)
				task.wait()
			end
		end)
		pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
	end

			local function performHelicopterBurst(raisedAmount, spinSpeed, spinDuration, burstConfig)
				pendingHelicopterRaisedAmount += math.max(1, tonumber(raisedAmount) or 1)
				if currentHelicopterSpinTask then
					return
				end

				currentHelicopterSpinTask = task.spawn(function()
					local config = type(burstConfig) == "table" and burstConfig or {}
					local function restoreIdleMode()
						if settings.helicopterEnabled and not currentHelicopterSpinTask then
							task.spawn(function()
								task.wait(0.08)
								for _ = 1, 15 do
									if not settings.helicopterEnabled or currentHelicopterSpinTask then
										return
									end
									local character = LocalPlayer.Character
									local humanoid = character and character:FindFirstChildOfClass("Humanoid")
									local root = humanoid and humanoid.RootPart
									if root and root.Parent then
										startHelicopterIdleMode()
										return
									end
									task.wait(0.2)
								end
								if settings.helicopterEnabled and not currentHelicopterSpinTask then
									startHelicopterIdleMode()
								end
							end)
						end
					end

					while pendingHelicopterRaisedAmount > 0 do
						local amount = math.max(1, tonumber(pendingHelicopterRaisedAmount) or 1)
						pendingHelicopterRaisedAmount = 0
						local character = LocalPlayer.Character
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")
						local root = humanoid and humanoid.RootPart
						if not character or not humanoid or not root then
							break
						end

						local ok, err = pcall(function()
							loadAstronautIdle()
							local animateScript = character:FindFirstChild("Animate")
							local animatePrevEnabled
							if animateScript and animateScript:IsA("LocalScript") then
								animatePrevEnabled = animateScript.Enabled
								animateScript.Enabled = false
							end

							local baseIdleSpeed = HELICOPTER_IDLE_SPIN_SPEED
							local targetSpinSpeed = math.max(getHelicopterSpinSpeedForAmount(amount), tonumber(spinSpeed) or 25)
							local minRiseHeight = math.max(0, tonumber(config.minRiseHeight) or 0)
							local riseHeight = getHelicopterRiseHeight(amount, minRiseHeight)
							local registerDelay = math.max(0.03, tonumber(config.registerDelay) or 0.05)
							local prepDuration = math.max(0.04, tonumber(config.prepDuration) or 0.06)
							local groundedSpinDuration = math.max(0.16, tonumber(config.groundedSpinDuration) or math.max(0.22, tonumber(spinDuration) or 0.22))
							local ascentDuration = math.max(0.18, tonumber(config.ascentDuration) or 0.22)
							local landingDuration = math.max(0.35, tonumber(config.landingDuration) or 0.55)
							local flightDuration = getHelicopterFlightDuration(amount)

							stopHelicopterIdleTask()
							local heliBody = root:FindFirstChild("HL1__HELI")
							if not (heliBody and heliBody:IsA("BodyAngularVelocity")) then
								heliBody = Instance.new("BodyAngularVelocity")
								heliBody.Name = "HL1__HELI"
								heliBody.MaxTorque = Vector3.new(0, math.huge, 0)
								heliBody.AngularVelocity = Vector3.new(0, baseIdleSpeed, 0)
								heliBody.Parent = root
							end

							local holdCF = root.CFrame
							local holdStart = tick()
							while tick() - holdStart < registerDelay and character.Parent and root.Parent do
								pcall(function()
									root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
									root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
								end)
								root.CFrame = holdCF
								task.wait()
							end

							local boothSlot = getClaimedBoothSlot()
							local prepTargetCF = boothSlot and getBoothTargetCFrameForStand(boothSlot, "Front") or holdCF
							if prepTargetCF then
								local flatLook = Vector3.new(prepTargetCF.LookVector.X, 0, prepTargetCF.LookVector.Z)
								if flatLook.Magnitude < 0.001 then
									flatLook = Vector3.new(0, 0, -1)
								end
								flatLook = flatLook.Unit
								local groundedPrepPos = Vector3.new(prepTargetCF.Position.X, holdCF.Position.Y, prepTargetCF.Position.Z)
								prepTargetCF = CFrame.new(groundedPrepPos, groundedPrepPos + flatLook)
							end
							local prepStart = tick()
							while tick() - prepStart < prepDuration and character.Parent and root.Parent do
								local t = math.clamp((tick() - prepStart) / prepDuration, 0, 1)
								local easedT = 1 - ((1 - t) * (1 - t))
								root.CFrame = holdCF:Lerp(prepTargetCF, easedT)
								if heliBody and heliBody.Parent then
									heliBody.AngularVelocity = Vector3.new(0, baseIdleSpeed + (1.25 * easedT), 0)
								end
								pcall(function()
									root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
									root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
								end)
								task.wait()
							end
							root.CFrame = prepTargetCF

							local startPos = prepTargetCF.Position
							local yaw = 0
							local lastSpinTick = tick()
							for count = 3, 1, -1 do
								if not settings.helicopterEnabled or not character.Parent or not root.Parent then
									break
								end
								sendChatMessage("TAKEOFF IN " .. count .. "...")
								task.wait(0.55)
							end

							local spoolStart = tick()
							local spoolFromSpeed = math.max(0.35, baseIdleSpeed * 0.7)
							while tick() - spoolStart < groundedSpinDuration and character.Parent and root.Parent do
								local now = tick()
								local dt = now - lastSpinTick
								lastSpinTick = now
								local t = math.clamp((now - spoolStart) / groundedSpinDuration, 0, 1)
								local spoolCurve = t * t * t
								local currentSpinSpeed = spoolFromSpeed + ((targetSpinSpeed - spoolFromSpeed) * spoolCurve)
								yaw += currentSpinSpeed * dt
								if heliBody and heliBody.Parent then
									heliBody.AngularVelocity = Vector3.new(0, currentSpinSpeed, 0)
								end
								pcall(function()
									root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
									root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
								end)
								applyHelicopterCFrame(root, startPos, yaw, prepTargetCF.LookVector)
								task.wait()
							end

							local existingHeli = root:FindFirstChild("HL1__HELI")
							if existingHeli and existingHeli:IsA("BodyAngularVelocity") then
								existingHeli:Destroy()
							end
							local nearestRouteIndex = 1
							local nearestRouteDistance = math.huge
							for index, routePoint in ipairs(HELICOPTER_PLAZA_ROUTE) do
								local delta = Vector3.new(routePoint.X - startPos.X, 0, routePoint.Z - startPos.Z)
								local distance = delta.Magnitude
								if distance < nearestRouteDistance then
									nearestRouteDistance = distance
									nearestRouteIndex = index
								end
							end

							local ascentStart = tick()
							local lastFrameTick = ascentStart
							local finalTargetPos = startPos
							while tick() - ascentStart < ascentDuration and character.Parent and root.Parent do
								local now = tick()
								local dt = now - lastFrameTick
								lastFrameTick = now
								local p = math.clamp((now - ascentStart) / ascentDuration, 0, 1)
								local easedUp = p * p
								finalTargetPos = Vector3.new(startPos.X, startPos.Y + (riseHeight * easedUp), startPos.Z)
								local spinSpeedAtFrame = baseIdleSpeed + ((targetSpinSpeed - baseIdleSpeed) * (0.25 + (easedUp * 0.75)))
								yaw += spinSpeedAtFrame * dt
								pcall(function()
									root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
									root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
								end)
								applyHelicopterCFrame(root, finalTargetPos, yaw, prepTargetCF.LookVector)
								task.wait()
							end

							local routeIndex = nearestRouteIndex
							local routePosition = finalTargetPos
							local routeFlightStart = tick()
							lastFrameTick = routeFlightStart
							local cruiseAnnounced = false
							while tick() - routeFlightStart < flightDuration and character.Parent and root.Parent do
								if pendingHelicopterRaisedAmount > 0 then
									local bonusAmount = math.max(1, tonumber(pendingHelicopterRaisedAmount) or 1)
									pendingHelicopterRaisedAmount = 0
									flightDuration = math.min(130, flightDuration + math.max(8, getHelicopterFlightDuration(bonusAmount) * 0.25))
									targetSpinSpeed = math.max(targetSpinSpeed, getHelicopterSpinSpeedForAmount(bonusAmount))
									riseHeight = math.max(riseHeight, getHelicopterRiseHeight(bonusAmount, minRiseHeight))
								end
								local nextIndex = (routeIndex % #HELICOPTER_PLAZA_ROUTE) + 1
								local nextBase = HELICOPTER_PLAZA_ROUTE[nextIndex]
								local nextPos = Vector3.new(nextBase.X, nextBase.Y + riseHeight, nextBase.Z)
								local segmentDistance = (nextPos - routePosition).Magnitude
								local segmentDuration = math.clamp(segmentDistance / 26, 0.9, 3.4)
								local segmentStart = tick()
								local segmentOrigin = routePosition
								while tick() - segmentStart < segmentDuration and character.Parent and root.Parent and (tick() - routeFlightStart) < flightDuration do
									if pendingHelicopterRaisedAmount > 0 then
										break
									end
									local now = tick()
									local dt = now - lastFrameTick
									lastFrameTick = now
									local p = math.clamp((now - segmentStart) / segmentDuration, 0, 1)
									local smoothP = p * p * (3 - (2 * p))
									local segmentPos = segmentOrigin:Lerp(nextPos, smoothP)
									local bob = math.sin((tick() - routeFlightStart) * 1.4) * 1.2
									finalTargetPos = Vector3.new(segmentPos.X, segmentPos.Y + bob, segmentPos.Z)
									local travelDir = Vector3.new(nextPos.X - segmentOrigin.X, 0, nextPos.Z - segmentOrigin.Z)
									if travelDir.Magnitude < 0.001 then
										travelDir = Vector3.new(0, 0, -1)
									else
										travelDir = travelDir.Unit
									end
									yaw += targetSpinSpeed * dt
									pcall(function()
										root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
										root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
									end)
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

							local boothSlot = getClaimedBoothSlot()
							local landingTargetCF = boothSlot and getBoothTargetCFrameForStand(boothSlot, "Front") or prepTargetCF
							if landingTargetCF then
								local landingPos = landingTargetCF.Position
								local landingStart = tick()
								local descentOrigin = finalTargetPos
								while tick() - landingStart < landingDuration and character.Parent and root.Parent do
									local now = tick()
									local dt = now - lastFrameTick
									lastFrameTick = now
									local p = math.clamp((now - landingStart) / landingDuration, 0, 1)
									local smoothP = p * p * (3 - (2 * p))
									finalTargetPos = Vector3.new(landingPos.X, descentOrigin.Y + ((landingPos.Y - descentOrigin.Y) * smoothP), landingPos.Z)
									local spinSpeedAtFrame = baseIdleSpeed + ((targetSpinSpeed - baseIdleSpeed) * (1 - smoothP))
									yaw += spinSpeedAtFrame * dt
									pcall(function()
										root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
										root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
									end)
									applyHelicopterCFrame(root, finalTargetPos, yaw, Vector3.new(0, -1, 0))
									task.wait()
								end
								root.CFrame = landingTargetCF
							end

							if animateScript and animateScript:IsA("LocalScript") and animatePrevEnabled ~= nil then
								animateScript.Enabled = animatePrevEnabled
							end
						end)
						if not ok then
							warn("Helicopter burst failed:", err)
							pendingHelicopterRaisedAmount = 0
							break
						end
					end

					currentHelicopterSpinTask = nil
					local character = LocalPlayer.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Parent then
						restoreIdleMode()
					end
				end)
			end

			local function performHelicopterDonationSequence(raisedAmount)
				performHelicopterBurst(raisedAmount, HELICOPTER_TAKEOFF_SPIN_SPEED, 1.2, {
					registerDelay = 0.08,
					prepDuration = 0.3,
					groundedSpinDuration = 1.4,
					minRiseHeight = 24,
					ascentDuration = 2.1,
					landingDuration = 1.1,
				})
			end

			local function getCharacterHumanoidRoot()
				local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = humanoid and humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
				return character, humanoid, root
			end

			local function getSpinMover()
				local _, _, root = getCharacterHumanoidRoot()
				if not root then return nil end
				local existing = root:FindFirstChild("Spin")
				return existing and existing:IsA("BodyAngularVelocity") and existing or nil
			end

			local function applySpinState()
				local _, _, root = getCharacterHumanoidRoot()
				if not root then return end
				local existing = root:FindFirstChild("Spin")
				if settings.spinSet then
					if not (existing and existing:IsA("BodyAngularVelocity")) then
						existing = Instance.new("BodyAngularVelocity")
						existing.Name = "Spin"
						existing.MaxTorque = Vector3.new(0, math.huge, 0)
						existing.Parent = root
					end
					local multiplier = math.max(0, tonumber(settings.spinSpeedMultiplier) or 1)
					existing.AngularVelocity = Vector3.new(0, SPIN_DONATION_BASE_SPEED * multiplier, 0)
				else
					spinVelocityAccumulator = 0
					if existing and existing:IsA("BodyAngularVelocity") then
						existing:Destroy()
					end
				end
			end

			local function applySpinDonation(amount)
				if not settings.spinSet then return end
				local spin = getSpinMover()
				if spin then
					local multiplier = math.max(0, tonumber(settings.spinSpeedMultiplier) or 1)
					spinVelocityAccumulator = ((math.max(0, tonumber(amount) or 0) / 3) * multiplier) + spin.AngularVelocity.Y
					spin.AngularVelocity = Vector3.new(0, spinVelocityAccumulator, 0)
				else
					applySpinState()
				end
			end

			return {
				applySpinDonation = applySpinDonation,
				addDonationAnimSpeed = addDonationAnimSpeed,
				applySpinState = applySpinState,
				applyCurrentAnimSpeed = applyCurrentAnimSpeed,
				getSpinMover = getSpinMover,
				isHelicopterBusy = function() return currentHelicopterSpinTask ~= nil end,
				performHelicopterDonationSequence = performHelicopterDonationSequence,
				resetSpinAccumulator = function() spinVelocityAccumulator = 0 end,
						resetDonationAnimSpeedBoost = resetDonationAnimSpeedBoost,
				playCatalogEmoteByName = playCatalogEmoteByName,
				setAntiAfkEnabled = setAntiAfkEnabled,
				stopCatalogEmoteTrack = stopCatalogEmoteTrack,
				startHelicopterIdleMode = startHelicopterIdleMode,
				stopAstronautIdle = stopAstronautIdle,
				stopHelicopterIdleTask = stopHelicopterIdleTask,
				stopHelicopterSpin = stopHelicopterSpin,
			}

end

return Config
