local env = getgenv and getgenv() or _G
if env.JumpLogic then return env.JumpLogic end

local JumpLogic = {}
JumpLogic.__index = JumpLogic

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local enabled = false
local power = 50
local jumpConn = nil
local stepConn = nil
local originalPower = nil
local boostUntil = 0

function JumpLogic.getCharacter()
	return LocalPlayer.Character
end

function JumpLogic.getHumanoid()
	local char = JumpLogic.getCharacter()
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

function JumpLogic.getRoot()
	local char = JumpLogic.getCharacter()
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

function JumpLogic.canRun()
	return JumpLogic.getHumanoid() ~= nil and JumpLogic.getRoot() ~= nil
end

function JumpLogic.isEnabled()
	return enabled
end

function JumpLogic.getPower()
	return power
end

local function restoreJumpPower()
	local h = JumpLogic.getHumanoid()
	if not h then return end
	local base = originalPower or 50
	if math.abs(h.JumpPower - base) > 0.001 then
		h.JumpPower = base
	end
end

local function holdJump()
	local h = JumpLogic.getHumanoid()
	local root = JumpLogic.getRoot()
	if not h or not root then
		return
	end
	if originalPower == nil then
		originalPower = h.JumpPower
	end
	restoreJumpPower()
	local vel = root.AssemblyLinearVelocity
	if vel.Y < power then
		root.AssemblyLinearVelocity = Vector3.new(vel.X, power, vel.Z)
	end
end

local function onJumpRequest()
	if not enabled then return end
	local h = JumpLogic.getHumanoid()
	local root = JumpLogic.getRoot()
	if not h or not root then return end
	if originalPower == nil then
		originalPower = h.JumpPower
	end
	restoreJumpPower()
	h:ChangeState(Enum.HumanoidStateType.Jumping)
	boostUntil = os.clock() + 0.25
	holdJump()
end

local function stopStep()
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
end

local function startStep()
	if stepConn then return end
	stepConn = RunService.Stepped:Connect(function()
		if not enabled then
			return
		end
		if os.clock() >= boostUntil then
			return
		end
		pcall(function()
			restoreJumpPower()
			holdJump()
		end)
	end)
end

function JumpLogic.enable()
	if enabled then return true end
	enabled = true
	local h = JumpLogic.getHumanoid()
	if h and originalPower == nil then
		originalPower = h.JumpPower
	end
	restoreJumpPower()
	if not jumpConn then
		jumpConn = UserInputService.JumpRequest:Connect(onJumpRequest)
	end
	startStep()
	return true
end

function JumpLogic.disable()
	if not enabled then return true end
	enabled = false
	boostUntil = 0
	stopStep()
	if jumpConn then
		jumpConn:Disconnect()
		jumpConn = nil
	end
	restoreJumpPower()
	return true
end

function JumpLogic.toggle()
	if enabled then
		return JumpLogic.disable()
	end
	return JumpLogic.enable()
end

function JumpLogic.setPower(value)
	power = math.max(20, math.floor((tonumber(value) or 50) + 0.5))
	return power
end

LocalPlayer.CharacterAdded:Connect(function()
	if enabled then
		task.wait(0.15)
		local h = JumpLogic.getHumanoid()
		if h and originalPower == nil then
			originalPower = h.JumpPower
		end
		restoreJumpPower()
		if not jumpConn then
			jumpConn = UserInputService.JumpRequest:Connect(onJumpRequest)
		end
		startStep()
	end
end)

env.JumpLogic = JumpLogic
return JumpLogic
