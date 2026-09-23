local env = getgenv and getgenv() or _G
if env.SpeedLogic then return env.SpeedLogic end

local SpeedLogic = {}
SpeedLogic.__index = SpeedLogic

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

SpeedLogic.BASE_SPEED = 16

local originalSpeed = nil
local desiredSpeed = nil
local stepConn = nil
local att = nil
local linVel = nil

function SpeedLogic.getCharacter()
	return LocalPlayer.Character
end

function SpeedLogic.getHumanoid()
	local char = SpeedLogic.getCharacter()
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

function SpeedLogic.getRoot()
	local char = SpeedLogic.getCharacter()
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

function SpeedLogic.canRun()
	return SpeedLogic.getHumanoid() ~= nil and SpeedLogic.getRoot() ~= nil
end

function SpeedLogic.getCurrentSpeed()
	if desiredSpeed then
		return desiredSpeed
	end
	local h = SpeedLogic.getHumanoid()
	return h and h.WalkSpeed or 0
end

local function destroyDrive()
	if linVel then
		pcall(function()
			linVel.Enabled = false
			linVel:Destroy()
		end)
		linVel = nil
	end
	if att then
		pcall(function()
			att:Destroy()
		end)
		att = nil
	end
end

local function ensureDrive()
	local root = SpeedLogic.getRoot()
	if not root then
		destroyDrive()
		return nil, nil
	end
	if linVel and linVel.Parent == root and att and att.Parent == root then
		return linVel, att
	end
	destroyDrive()
	att = root:FindFirstChild("GCSpeedAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "GCSpeedAtt"
		att.Parent = root
	end
	linVel = root:FindFirstChild("GCSpeedLV")
	if not linVel then
		linVel = Instance.new("LinearVelocity")
		linVel.Name = "GCSpeedLV"
		linVel.Attachment0 = att
		linVel.RelativeTo = Enum.ActuatorRelativeTo.World
		linVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		linVel.VectorVelocity = Vector3.zero
		linVel.MaxForce = Vector3.new(0, 0, 0)
		linVel.Enabled = true
		linVel.Parent = root
	end
	return linVel, att
end

local function restoreWalkSpeed()
	local h = SpeedLogic.getHumanoid()
	if not h then return end
	local base = originalSpeed or SpeedLogic.BASE_SPEED
	if math.abs(h.WalkSpeed - base) > 0.001 then
		h.WalkSpeed = base
	end
end

local function tickSpeed()
	local h = SpeedLogic.getHumanoid()
	local root = SpeedLogic.getRoot()
	if not h or not root then
		destroyDrive()
		return
	end
	if originalSpeed == nil then
		originalSpeed = h.WalkSpeed
	end
	restoreWalkSpeed()
	local lv = ensureDrive()
	if not lv then
		return
	end
	local moving = desiredSpeed ~= nil and h.MoveDirection.Magnitude > 0.01
	if moving then
		local dir = h.MoveDirection.Unit
		lv.VectorVelocity = dir * desiredSpeed
		lv.MaxForce = Vector3.new(1e5, 0, 1e5)
		lv.Enabled = true
	else
		lv.VectorVelocity = Vector3.zero
		lv.MaxForce = Vector3.new(0, 0, 0)
	end
end

local function stopLoop()
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
	destroyDrive()
	restoreWalkSpeed()
end

local function startLoop()
	if stepConn then return end
	stepConn = RunService.Stepped:Connect(function()
		if not desiredSpeed then
			return
		end
		pcall(tickSpeed)
	end)
end

function SpeedLogic.setSpeed(value)
	value = tonumber(value) or SpeedLogic.BASE_SPEED
	if value <= SpeedLogic.BASE_SPEED then
		return SpeedLogic.resetSpeed()
	end
	local h = SpeedLogic.getHumanoid()
	if h and originalSpeed == nil then
		originalSpeed = h.WalkSpeed
	end
	desiredSpeed = value
	restoreWalkSpeed()
	startLoop()
	pcall(tickSpeed)
	return true
end

function SpeedLogic.resetSpeed()
	desiredSpeed = nil
	stopLoop()
	return true
end

function SpeedLogic.getBaseSpeed()
	return originalSpeed or SpeedLogic.BASE_SPEED
end

function SpeedLogic.isEnabled()
	return desiredSpeed ~= nil
end

function SpeedLogic.getDesired()
	return desiredSpeed
end

LocalPlayer.CharacterAdded:Connect(function()
	att = nil
	linVel = nil
	if desiredSpeed then
		task.wait(0.15)
		startLoop()
		pcall(tickSpeed)
	end
end)

env.SpeedLogic = SpeedLogic
return SpeedLogic
