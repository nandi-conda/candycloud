--[[
	CANDY CLOUD CLIMB
	An original, kid-friendly obby (obstacle course) for Roblox.

	HOW IT WORKS
	This one Script builds the whole level by itself when you press Play.
	Put it in ServerScriptService. You don't need to build anything by hand.

	THE GAME
	- Climb from the start platform up to the Golden Trophy.
	- Each white platform is a CHECKPOINT. Fall off and you pop back there.
	- Stay away from glowing PINK GOO (the floor far below and the spinning bars).
	- Grab the yellow STARS for points.
	- Reach the trophy to WIN and earn a rainbow trail!

	Want to change things? Look at the CONFIG and COLORS sections below.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------------------------
-- CONFIG: safe and fun to tweak
--------------------------------------------------------------------------------
local CONFIG = {
	GameName = "Candy Cloud Climb",
	StartHeight = 30, -- how high in the sky the course starts
	StarRespawnSeconds = 8, -- how long until a collected star comes back
	BouncePower = 100, -- how hard the green bounce pads launch you
	SpinnerSpeedEasy = 1.4, -- spinning goo bar speed (radians per second)
	SpinnerSpeedHard = 2.0,
	TileReturnSeconds = 2.5, -- how long vanishing tiles stay gone
	WalkSpeed = 20, -- normal walking speed (Roblox default is 16). Running is in Sprint.client.luau
}

--------------------------------------------------------------------------------
-- COLORS
--------------------------------------------------------------------------------
local RAINBOW = {
	Color3.fromRGB(255, 120, 170), -- pink
	Color3.fromRGB(255, 170, 90), -- orange
	Color3.fromRGB(255, 225, 100), -- yellow
	Color3.fromRGB(110, 230, 160), -- mint
	Color3.fromRGB(100, 175, 255), -- blue
	Color3.fromRGB(185, 135, 255), -- purple
}
local GOO_COLOR = Color3.fromRGB(255, 60, 170)
local CHECKPOINT_COLOR = Color3.fromRGB(255, 250, 255)
local STAR_COLOR = Color3.fromRGB(255, 220, 50)
local GOLD = Color3.fromRGB(255, 200, 60)
local BOUNCE_COLOR = Color3.fromRGB(80, 255, 120)

local function rainbow(i: number): Color3
	return RAINBOW[(i - 1) % #RAINBOW + 1]
end

--------------------------------------------------------------------------------
-- CLEAN UP the default template (old baseplate / spawn) and make a world folder
--------------------------------------------------------------------------------
local oldWorld = workspace:FindFirstChild(CONFIG.GameName)
if oldWorld then
	oldWorld:Destroy()
end
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
for _, child in workspace:GetChildren() do
	if child:IsA("SpawnLocation") then
		child:Destroy()
	end
end

local world = Instance.new("Folder")
world.Name = CONFIG.GameName
world.Parent = workspace

-- A bright, dreamy sky
Lighting.ClockTime = 14
Lighting.Brightness = 2.5
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Color = Color3.fromRGB(255, 215, 240)
atmosphere.Decay = Color3.fromRGB(200, 170, 255)
atmosphere.Density = 0.25
atmosphere.Haze = 0.5
atmosphere.Glare = 0
atmosphere.Parent = Lighting

--------------------------------------------------------------------------------
-- BUILDING HELPERS
--------------------------------------------------------------------------------
local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = props.Parent or world
	return part
end

-- Makes a flat platform whose TOP surface is centered at `top`.
local function platform(top: Vector3, size: Vector3, color: Color3, name: string?): Part
	return makePart({
		Name = name or "Platform",
		Size = size,
		CFrame = CFrame.new(top - Vector3.new(0, size.Y / 2, 0)),
		Color = color,
	})
end

-- Makes a round, flat disc (cylinder lying down) with its top at `top`.
local function disc(top: Vector3, diameter: number, thickness: number, color: Color3, name: string?): Part
	return makePart({
		Name = name or "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = CFrame.new(top - Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
	})
end

local function addSign(parent: BasePart, text: string, height: number, color: Color3?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(12, 0, 3, 0) -- measured in studs
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 120
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(120, 40, 120)
	label.Parent = gui
end

--------------------------------------------------------------------------------
-- PLAYER HELPERS
--------------------------------------------------------------------------------
local playerStage: { [Player]: number } = {}
local finishedRun: { [Player]: boolean } = {}
local busy: { [Player]: boolean } = {}
local checkpoints: { [number]: BasePart } = {}

local function playerFromHit(hit: BasePart): (Player?, Model?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return Players:GetPlayerFromCharacter(character), character
end

local function getStat(player: Player, statName: string): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild(statName) :: IntValue?
end

-- Big friendly message at the top of one player's screen
local toastCount: { [Player]: number } = {}
local function toast(player: Player, text: string, color: Color3?)
	local playerGui = player:FindFirstChild("PlayerGui")
	local screen = playerGui and playerGui:FindFirstChild("CloudClimbMessages")
	local label = screen and screen:FindFirstChild("Message") :: TextLabel?
	if not label then
		return
	end
	toastCount[player] = (toastCount[player] or 0) + 1
	local myCount = toastCount[player]
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0
	task.delay(2.5, function()
		if toastCount[player] == myCount then
			label.TextTransparency = 1
			label.TextStrokeTransparency = 1
		end
	end)
end

local function sendToCheckpoint(player: Player)
	local character = player.Character
	local checkpoint = checkpoints[playerStage[player] or 1]
	if character and checkpoint then
		character:PivotTo(checkpoint.CFrame + Vector3.new(0, 5, 0))
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function hitGoo(player: Player)
	if busy[player] then
		return
	end
	busy[player] = true
	toast(player, "Oops! Sticky goo! 💦", GOO_COLOR)
	sendToCheckpoint(player)
	task.delay(1, function()
		busy[player] = nil
	end)
end

-- Anything you call this on becomes "goo": touching it sends you back
local function makeGoo(part: BasePart)
	part.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			hitGoo(player)
		end
	end)
end

local function giveRainbowTrail(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("RainbowTrail") then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1, 0)
	bottom.Parent = root

	local keypoints = {}
	for i, color in RAINBOW do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), color))
	end
	local trail = Instance.new("Trail")
	trail.Name = "RainbowTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.7
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(keypoints)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = root
end

--------------------------------------------------------------------------------
-- STARS (collectibles)
--------------------------------------------------------------------------------
-- Stars sit still on the server. WorldMotion.client.luau makes them bob and spin
-- on each player's screen, which is smooth and costs no network traffic.
local function addStar(position: Vector3)
	local star = makePart({
		Name = "Star",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = position,
		Color = STAR_COLOR,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = STAR_COLOR
	sparkles.Parent = star
	star:SetAttribute("Base", position)
	star:SetAttribute("Phase", math.random() * 6)
	CollectionService:AddTag(star, "CloudStar")

	local collected = false
	star.Touched:Connect(function(hit)
		if collected then
			return
		end
		local player = playerFromHit(hit)
		if not player then
			return
		end
		collected = true
		local starsStat = getStat(player, "Stars")
		if starsStat then
			starsStat.Value += 1
			toast(player, "⭐ Star! You have " .. starsStat.Value, STAR_COLOR)
		end
		star.Transparency = 1
		sparkles.Enabled = false
		task.delay(CONFIG.StarRespawnSeconds, function()
			star.Transparency = 0
			sparkles.Enabled = true
			collected = false
		end)
	end)
end

--------------------------------------------------------------------------------
-- SPINNING GOO BARS
--------------------------------------------------------------------------------
-- The bars are spun by WorldMotion.client.luau on each player's screen (smooth, no lag).
-- Every screen uses the same server clock, so everyone sees the bars in the same place.
-- When a bar hits you, your game tells the server through this RemoteEvent.
local gooHitEvent = Instance.new("RemoteEvent")
gooHitEvent.Name = "CloudClimbGooHit"
gooHitEvent.Parent = ReplicatedStorage

local function addSpinner(center: Vector3, length: number, speed: number, startAngle: number)
	local bar = makePart({
		Name = "SpinningGoo",
		Size = Vector3.new(length, 1, 1),
		CFrame = CFrame.new(center),
		Color = GOO_COLOR,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
	})
	bar:SetAttribute("Pivot", CFrame.new(center))
	bar:SetAttribute("Speed", speed)
	bar:SetAttribute("StartAngle", startAngle)
	CollectionService:AddTag(bar, "CloudSpinner")
	-- a little candy post in the middle so you can see what it spins around
	makePart({
		Name = "SpinnerPost",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 1.2, 1.2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.new(1, 1, 1),
		CanCollide = false,
		CanTouch = false,
	})
end

--------------------------------------------------------------------------------
-- CHECKPOINTS
-- Every builder below gets `edge`: the point on the top surface at the FAR edge
-- of the last platform. It returns the point where the next checkpoint starts.
--------------------------------------------------------------------------------
local function addCheckpoint(nearEdge: Vector3, stage: number): Vector3
	local size = Vector3.new(14, 2, 14)
	local cp = platform(nearEdge + Vector3.new(0, 0, size.Z / 2), size, CHECKPOINT_COLOR, "Checkpoint" .. stage)
	cp.Material = Enum.Material.Neon
	cp.Transparency = 0.15
	checkpoints[stage] = cp
	addSign(cp, "🚩 Checkpoint " .. stage, 5, rainbow(stage))

	cp.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and (playerStage[player] or 1) < stage then
			playerStage[player] = stage
			local stageStat = getStat(player, "Stage")
			if stageStat then
				stageStat.Value = stage
			end
			toast(player, "🚩 Checkpoint " .. stage .. "!", rainbow(stage))
		end
	end)
	return nearEdge + Vector3.new(0, 0, size.Z)
end

--------------------------------------------------------------------------------
-- OBSTACLES
--------------------------------------------------------------------------------

-- Hop across colorful stepping stones that zig-zag left and right.
local function steppingStones(edge: Vector3, count: number, stoneSize: number, gap: number): Vector3
	local top = edge
	for i = 1, count do
		local z = edge.Z + gap + stoneSize / 2 + (i - 1) * (stoneSize + gap)
		local x = if i % 2 == 0 then 3 else -3
		top = Vector3.new(x, edge.Y + i, z)
		platform(top, Vector3.new(stoneSize, 1.5, stoneSize), rainbow(i), "SteppingStone")
		if i % 2 == 1 then
			addStar(top + Vector3.new(0, 3, 0))
		end
	end
	return Vector3.new(0, top.Y, top.Z + stoneSize / 2 + gap)
end

-- A long candy bridge with spinning goo bars. Jump over them!
local function spinnerBridge(edge: Vector3, bars: number, speed: number): Vector3
	local spacing = 18
	local length = spacing * bars + 8
	local bridge = platform(
		edge + Vector3.new(0, 0, 3 + length / 2),
		Vector3.new(10, 1.5, length),
		Color3.fromRGB(190, 230, 255),
		"CandyBridge"
	)
	for i = 1, bars do
		local z = edge.Z + 3 + 4 + (i - 0.5) * spacing
		addSpinner(Vector3.new(0, edge.Y + 1.5, z), 14, speed * (if i % 2 == 0 then -1 else 1), i)
		if i < bars then
			addStar(Vector3.new(0, edge.Y + 3, z + spacing / 2))
		end
	end
	return edge + Vector3.new(0, 0, 3 + length + 4)
end

-- Tiles that fade away a moment after you step on them. Keep moving!
local function vanishingTiles(edge: Vector3, rows: number): Vector3
	local tileSize = 6
	local gap = 1.5
	local lastZ = edge.Z
	for row = 1, rows do
		for col = -1, 1, 2 do
			local z = edge.Z + gap + tileSize / 2 + (row - 1) * (tileSize + gap)
			lastZ = z
			local tile = platform(
				Vector3.new(col * (tileSize / 2 + 0.75), edge.Y, z),
				Vector3.new(tileSize, 1, tileSize),
				rainbow(row + (col + 1) / 2),
				"VanishingTile"
			)
			tile.Transparency = 0.1
			local fading = false
			tile.Touched:Connect(function(hit)
				if fading or not playerFromHit(hit) then
					return
				end
				fading = true
				local fade = TweenService:Create(tile, TweenInfo.new(0.7), { Transparency = 0.85 })
				fade:Play()
				fade.Completed:Wait()
				tile.CanCollide = false
				tile.Transparency = 1
				task.wait(CONFIG.TileReturnSeconds)
				tile.CanCollide = true
				tile.Transparency = 0.1
				fading = false
			end)
		end
		if row % 2 == 0 then
			addStar(Vector3.new(0, edge.Y + 3, lastZ))
		end
	end
	return Vector3.new(0, edge.Y, lastZ + tileSize / 2 + gap)
end

-- Green bounce pads launch you up to higher platforms. Steer forward in the air!
local bounceCooldown: { [Model]: boolean } = {}
local function addBouncePad(top: Vector3)
	local pad = disc(top + Vector3.new(0, 0.6, 0), 6, 0.6, BOUNCE_COLOR, "BouncePad")
	pad.Material = Enum.Material.Neon
	pad.Touched:Connect(function(hit)
		local player, character = playerFromHit(hit)
		if not player or not character or bounceCooldown[character] then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		bounceCooldown[character] = true
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local push = Instance.new("LinearVelocity")
		push.Attachment0 = attachment
		push.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
		push.LineDirection = Vector3.yAxis
		push.LineVelocity = CONFIG.BouncePower
		push.MaxForce = math.huge
		push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.Parent = root
		task.delay(0.15, function()
			push:Destroy()
			attachment:Destroy()
		end)
		task.delay(0.6, function()
			bounceCooldown[character] = nil
		end)
	end)
end

local function bounceClimb(edge: Vector3, levels: number): Vector3
	local top = edge
	for i = 1, levels do
		-- low platform with a pad in the middle
		local low = Vector3.new(0, top.Y, top.Z + 3 + 5)
		platform(low, Vector3.new(10, 1.5, 10), rainbow(i + 2), "BounceBase")
		addBouncePad(low)
		addStar(low + Vector3.new(0, 14, 2))
		-- high platform just ahead
		local high = Vector3.new(0, top.Y + 16, low.Z + 5 + 3 + 6)
		platform(high, Vector3.new(12, 1.5, 12), rainbow(i + 3), "BounceTop")
		top = high + Vector3.new(0, 0, 6)
	end
	return top + Vector3.new(0, 0, 4)
end

-- Thin candy-stripe beams with little rest pads. Walk carefully!
local function tightrope(edge: Vector3): Vector3
	local offsets = {
		Vector3.new(0, 0, 4),
		Vector3.new(0, 0, 20),
		Vector3.new(12, 1, 28),
		Vector3.new(12, 2, 44),
		Vector3.new(0, 3, 52),
		Vector3.new(0, 3, 60),
	}
	local points = {}
	for i, offset in offsets do
		local p = edge + offset
		points[i] = p
		platform(p, Vector3.new(5, 1, 5), rainbow(i), "RestPad")
		if i > 1 and i < #offsets then
			addStar(p + Vector3.new(0, 3, 0))
		end
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2 - Vector3.new(0, 0.5, 0)
		makePart({
			Name = "Tightrope",
			Size = Vector3.new(2, 1, (b - a).Magnitude),
			CFrame = CFrame.lookAt(mid, mid + (b - a)),
			Color = if i % 2 == 0 then Color3.new(1, 1, 1) else RAINBOW[1],
		})
	end
	return points[#points] + Vector3.new(0, 0, 2.5 + 3)
end

-- Spiral cloud stairs winding around a giant candy pole.
local function spiralStairs(edge: Vector3, steps: number, rise: number): Vector3
	local radius = 9
	local center = edge + Vector3.new(0, 0, 3 + 3 + radius)
	makePart({
		Name = "CandyPole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(steps * rise + 8, 4, 4),
		CFrame = CFrame.new(center + Vector3.new(0, (steps * rise) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = RAINBOW[1],
	})
	local last = center
	for i = 0, steps do
		local angle = i * math.rad(30)
		last = center + Vector3.new(math.sin(angle) * radius, i * rise, -math.cos(angle) * radius)
		disc(last, 6, 1, Color3.fromRGB(255, 255, 255), "CloudStep")
		if i % 4 == 2 then
			addStar(last + Vector3.new(0, 3, 0))
		end
	end
	-- `steps` should be a multiple of 6 so the stairs end on the far side
	return Vector3.new(0, last.Y, last.Z + 3 + 3)
end

--------------------------------------------------------------------------------
-- FINISH: golden trophy platform
--------------------------------------------------------------------------------
local function buildFinish(nearEdge: Vector3, stage: number)
	local size = Vector3.new(30, 2, 30)
	local finish = platform(nearEdge + Vector3.new(0, 0, size.Z / 2), size, GOLD, "Finish")
	finish.Material = Enum.Material.Neon
	checkpoints[stage] = finish

	local trophyBase = finish.Position + Vector3.new(0, 1, 6)
	makePart({
		Name = "TrophyCup",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 3, 3),
		CFrame = CFrame.new(trophyBase + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GOLD,
		Material = Enum.Material.Foil,
	})
	local cupTop = makePart({
		Name = "TrophyTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		Position = trophyBase + Vector3.new(0, 8, 0),
		Color = GOLD,
		Material = Enum.Material.Foil,
	})
	addSign(cupTop, "🏆 YOU MADE IT! 🏆", 7, GOLD)

	local confetti = Instance.new("ParticleEmitter")
	confetti.Rate = 0
	confetti.Lifetime = NumberRange.new(2, 4)
	confetti.Speed = NumberRange.new(25, 45)
	confetti.SpreadAngle = Vector2.new(60, 60)
	confetti.Acceleration = Vector3.new(0, -30, 0)
	confetti.Rotation = NumberRange.new(0, 360)
	confetti.RotSpeed = NumberRange.new(-200, 200)
	confetti.Size = NumberSequence.new(0.6)
	local keypoints = {}
	for i, color in RAINBOW do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), color))
	end
	confetti.Color = ColorSequence.new(keypoints)
	confetti.Parent = cupTop

	finish.Touched:Connect(function(hit)
		local player, character = playerFromHit(hit)
		if not player or not character or finishedRun[player] then
			return
		end
		finishedRun[player] = true
		playerStage[player] = stage
		local stageStat = getStat(player, "Stage")
		if stageStat then
			stageStat.Value = stage
		end
		local wins = getStat(player, "Wins")
		if wins then
			wins.Value += 1
		end
		confetti:Emit(150)
		giveRainbowTrail(character)
		toast(player, "🏆 YOU WIN! You earned a rainbow trail! 🌈", GOLD)
	end)

	-- "Play again" pad sends you back to the start
	-- (it sits in the back corner so you don't step on it by accident while arriving)
	local again = disc(finish.Position + Vector3.new(-10, 1, 10), 7, 0.6, BOUNCE_COLOR, "PlayAgainPad")
	again.Material = Enum.Material.Neon
	addSign(again, "🔁 Play again", 4, BOUNCE_COLOR)
	again.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or busy[player] then
			return
		end
		busy[player] = true
		playerStage[player] = 1
		finishedRun[player] = false
		local stageStat = getStat(player, "Stage")
		if stageStat then
			stageStat.Value = 1
		end
		sendToCheckpoint(player)
		toast(player, "Here we go again! 🚀")
		task.delay(1, function()
			busy[player] = nil
		end)
	end)
end

--------------------------------------------------------------------------------
-- BUILD THE WHOLE COURSE
--------------------------------------------------------------------------------
local startTop = Vector3.new(0, CONFIG.StartHeight, 0)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Start"
spawn.Anchored = true
spawn.Size = Vector3.new(20, 2, 20)
spawn.CFrame = CFrame.new(startTop - Vector3.new(0, 1, 0))
spawn.Color = CHECKPOINT_COLOR
spawn.Material = Enum.Material.Neon
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Duration = 0 -- no force field bubble
spawn.Parent = world
checkpoints[1] = spawn
addSign(spawn, "☁️ " .. CONFIG.GameName .. " ☁️\nReach the golden trophy!\nAvoid the pink goo 💗 Grab the stars ⭐", 8, RAINBOW[1])

local edge = startTop + Vector3.new(0, 0, 10)
local stage = 1

local course = {
	function(e)
		return steppingStones(e, 6, 6, 4)
	end,
	function(e)
		return spinnerBridge(e, 2, CONFIG.SpinnerSpeedEasy)
	end,
	function(e)
		return vanishingTiles(e, 6)
	end,
	function(e)
		return bounceClimb(e, 2)
	end,
	function(e)
		return tightrope(e)
	end,
	function(e)
		return spiralStairs(e, 18, 1.5)
	end,
	function(e)
		return steppingStones(e, 7, 4.5, 5.5)
	end,
	function(e)
		return spinnerBridge(e, 3, CONFIG.SpinnerSpeedHard)
	end,
}

for i, buildObstacle in course do
	edge = buildObstacle(edge)
	stage += 1
	if i < #course then
		edge = addCheckpoint(edge, stage)
	else
		buildFinish(edge, stage)
	end
end
local FINAL_STAGE = stage

-- Pink goo far below: fall off and you bounce back to your checkpoint
local goo = makePart({
	Name = "PinkGoo",
	Size = Vector3.new(2048, 2, 2048),
	Position = Vector3.new(0, -1, 300),
	Color = GOO_COLOR,
	Material = Enum.Material.SmoothPlastic,
	Transparency = 0.15,
})
makeGoo(goo)

-- Fluffy decorative clouds (you can't stand on these)
local rng = Random.new(42)
for _ = 1, 45 do
	local center = Vector3.new(rng:NextNumber(-120, 120), rng:NextNumber(6, 22), rng:NextNumber(-60, 520))
	for _ = 1, 3 do
		local d = rng:NextNumber(6, 12)
		makePart({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			Position = center + Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-1, 2), rng:NextNumber(-4, 4)),
			Color = Color3.new(1, 1, 1),
			CanCollide = false,
			CanTouch = false,
			CastShadow = false,
		})
	end
end

--------------------------------------------------------------------------------
-- SPINNING BAR HITS (reported by WorldMotion.client.luau)
--------------------------------------------------------------------------------
gooHitEvent.OnServerEvent:Connect(function(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		hitGoo(player)
	end
end)

--------------------------------------------------------------------------------
-- CHEAT CODE: type "hh 5" (or "/hh 5") in chat to jump to checkpoint 5.
-- Roblox has two chat systems, so we listen three ways: Player.Chatted (old chat),
-- a /hh chat command, and a message from WorldMotion.client.luau (new chat).
--------------------------------------------------------------------------------
local lastCheat: { [Player]: number } = {}
local function onChat(player: Player, message: string)
	local number = string.match(string.lower(message), "^%s*/?hh%s+(%d+)%s*$")
	if not number then
		return
	end
	-- the same message can arrive through more than one route; only act once
	if os.clock() - (lastCheat[player] or 0) < 1 then
		return
	end
	lastCheat[player] = os.clock()
	local target = tonumber(number)
	if not target or target < 1 or target > FINAL_STAGE then
		toast(player, "Pick a checkpoint from 1 to " .. FINAL_STAGE, GOO_COLOR)
		return
	end
	playerStage[player] = target
	finishedRun[player] = false
	local stageStat = getStat(player, "Stage")
	if stageStat then
		stageStat.Value = target
	end
	sendToCheckpoint(player)
	toast(player, if target == FINAL_STAGE then "✨ Cheat! Warped to the trophy ✨" else "✨ Cheat! Warped to checkpoint " .. target .. " ✨", RAINBOW[6])
end

local cheatEvent = Instance.new("RemoteEvent")
cheatEvent.Name = "CloudClimbCheat"
cheatEvent.Parent = ReplicatedStorage
cheatEvent.OnServerEvent:Connect(function(player, message)
	if type(message) == "string" and #message <= 40 then
		onChat(player, message)
	end
end)

local warpCommand = Instance.new("TextChatCommand")
warpCommand.Name = "CloudClimbWarp"
warpCommand.PrimaryAlias = "/hh"
warpCommand.Triggered:Connect(function(source: TextSource, text: string)
	local player = Players:GetPlayerByUserId(source.UserId)
	if player then
		onChat(player, text)
	end
end)
warpCommand.Parent = game:GetService("TextChatService")

--------------------------------------------------------------------------------
-- PLAYERS JOINING
--------------------------------------------------------------------------------
local function setupPlayer(player: Player)
	playerStage[player] = 1
	finishedRun[player] = false

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats" -- this exact name makes the scoreboard appear
	for _, statName in { "Stage", "Stars", "Wins" } do
		local value = Instance.new("IntValue")
		value.Name = statName
		value.Value = if statName == "Stage" then 1 else 0
		value.Parent = stats
	end
	stats.Parent = player

	-- the on-screen message label used by toast()
	local screen = Instance.new("ScreenGui")
	screen.Name = "CloudClimbMessages"
	screen.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.Size = UDim2.fromScale(0.7, 0.09)
	label.Position = UDim2.fromScale(0.15, 0.12)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.TextStrokeColor3 = Color3.fromRGB(90, 30, 90)
	label.Text = ""
	label.Parent = screen
	screen.Parent = player:WaitForChild("PlayerGui")

	player.Chatted:Connect(function(message)
		onChat(player, message)
	end)

	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if not root then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = CONFIG.WalkSpeed
		end
		task.wait(0.1)
		if (playerStage[player] or 1) > 1 then
			sendToCheckpoint(player)
		end
		local wins = getStat(player, "Wins")
		if wins and wins.Value > 0 then
			giveRainbowTrail(character)
		end
	end)

	task.delay(2, function()
		toast(player, "Welcome to " .. CONFIG.GameName .. "! ☁️", RAINBOW[5])
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	playerStage[player] = nil
	finishedRun[player] = nil
	busy[player] = nil
	toastCount[player] = nil
	lastCheat[player] = nil
end)

print(CONFIG.GameName .. " built! Stages: " .. FINAL_STAGE)
