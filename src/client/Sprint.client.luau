--[[
	RUNNING for Candy Cloud Climb
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	- Computer: hold Shift to run.
	- Phone / tablet: tap the "Run" button to switch running on and off.
	- Controller: click the left stick to switch running on and off.
]]

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local WALK_SPEED = 20 -- normal speed (Roblox's default is 16)
local RUN_SPEED = 32 -- speed while running
local NORMAL_FOV = 70
local RUN_FOV = 82 -- the camera widens a little when you run, so it feels fast

local player = Players.LocalPlayer
local running = false

local function apply()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if running then RUN_SPEED else WALK_SPEED
	end
	local camera = workspace.CurrentCamera
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.25), { FieldOfView = if running then RUN_FOV else NORMAL_FOV })
			:Play()
	end
	local button = ContextActionService:GetButton("Run")
	if button then
		button.ImageColor3 = if running then Color3.fromRGB(110, 230, 160) else Color3.new(1, 1, 1)
	end
end

local function onRun(_actionName: string, state: Enum.UserInputState, input: InputObject)
	local isToggle = input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.ButtonL3
	if isToggle then
		if state == Enum.UserInputState.Begin then
			running = not running
			apply()
		end
	else
		-- keyboard: run while Shift is held down
		running = state == Enum.UserInputState.Begin
		apply()
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("Run", onRun, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("Run", "Run")
ContextActionService:SetPosition("Run", UDim2.new(1, -150, 1, -150))

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid")
	apply()
end)
if player.Character then
	apply()
end
