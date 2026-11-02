--[[
	WORLD MOTION for Candy Cloud Climb
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	Spins the pink goo bars and makes the stars bob, right on your own screen.
	Doing this here (instead of on the server) keeps the game smooth: the server
	no longer has to send every tiny movement to every player 60 times a second.
	All players use the server's clock, so the bars line up for everyone.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gooHitEvent = ReplicatedStorage:WaitForChild("CloudClimbGooHit") :: RemoteEvent

local TWO_PI = math.pi * 2

-- Keep a list of tagged parts. Parts can stream in and out as you move, so we
-- listen for them being added and removed.
local function track(tag: string): { [BasePart]: boolean }
	local set: { [BasePart]: boolean } = {}
	for _, part in CollectionService:GetTagged(tag) do
		set[part] = true
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
		set[part] = true
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
		set[part] = nil
	end)
	return set
end

local spinners = track("CloudSpinner")
local stars = track("CloudStar")
local lastHit = 0

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	for bar in spinners do
		local pivot = bar:GetAttribute("Pivot")
		local speed = bar:GetAttribute("Speed")
		local startAngle = bar:GetAttribute("StartAngle")
		if typeof(pivot) == "CFrame" and type(speed) == "number" and type(startAngle) == "number" then
			local angle = (startAngle + speed * now) % TWO_PI
			local cf = pivot * CFrame.Angles(0, angle, 0)
			bar.CFrame = cf

			-- Did the bar hit me? Check where I am compared to the bar.
			if root and now - lastHit > 1 then
				local rel = cf:PointToObjectSpace(root.Position)
				local touchingAlong = math.abs(rel.X) < bar.Size.X / 2 + 0.5
				local touchingAcross = math.abs(rel.Z) < 1.5
				local touchingHeight = rel.Y > -3 and rel.Y < 3.6 -- jump high enough and your feet clear it
				if touchingAlong and touchingAcross and touchingHeight then
					lastHit = now
					gooHitEvent:FireServer()
				end
			end
		end
	end

	for star in stars do
		local base = star:GetAttribute("Base")
		local phase = star:GetAttribute("Phase")
		if typeof(base) == "Vector3" and type(phase) == "number" then
			local t = now % math.pi -- the motion repeats every pi seconds, so this stays smooth
			star.CFrame = CFrame.new(base + Vector3.new(0, math.sin(t * 2 + phase) * 0.6, 0)) * CFrame.Angles(0, t * 2, 0)
		end
	end
end)
