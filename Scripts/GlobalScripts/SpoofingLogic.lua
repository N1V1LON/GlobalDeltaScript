local env = getgenv and getgenv() or _G
if env.SpoofingLogic then return env.SpoofingLogic end

local SpoofingLogic = {}
SpoofingLogic.__index = SpoofingLogic

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local enabled = false
local flags = {
	speed = true,
	jump = true,
	tp = true,
}
local keepTask = nil
local hooksReady = false
local lockUntil = 0
local lockCF = nil
local baseWalk = 16
local baseJump = 50

function SpoofingLogic.getHumanoid()
	local char = LocalPlayer.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

function SpoofingLogic.getRoot()
	local char = LocalPlayer.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

function SpoofingLogic.canRun()
	return SpoofingLogic.getHumanoid() ~= nil
end

function SpoofingLogic.isEnabled()
	return enabled
end

function SpoofingLogic.getFlag(name)
	return flags[name] == true
end

function SpoofingLogic.setFlag(name, value)
	if flags[name] == nil then
		return false
	end
	flags[name] = value == true
	return flags[name]
end

function SpoofingLogic.getFlags()
	return {
		speed = flags.speed,
		jump = flags.jump,
		tp = flags.tp,
	}
end

function SpoofingLogic.noteTeleport()
	if not enabled or not flags.tp then
		return
	end
	local root = SpoofingLogic.getRoot()
	if not root then
		return
	end
	lockCF = root.CFrame
	lockUntil = os.clock() + 1.2
end

local function spoofedBase(value, base)
	if value == nil then
		return base
	end
	if math.abs(value - base) < 0.01 then
		return value
	end
	return base
end

local function onHumanoid(self, key)
	if not enabled or typeof(self) ~= "Instance" then
		return nil
	end
	if key ~= "WalkSpeed" and key ~= "JumpPower" then
		return nil
	end
	local h = SpoofingLogic.getHumanoid()
	if not h or self ~= h then
		return nil
	end
	return key
end

local function installHooks()
	if hooksReady then
		return
	end
	hooksReady = true
	if type(hookmetamethod) ~= "function" then
		return
	end
	pcall(function()
		local oldIndex
		oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
			local field = onHumanoid(self, key)
			if field then
				if field == "WalkSpeed" and flags.speed then
					return spoofedBase(oldIndex(self, key), baseWalk)
				end
				if field == "JumpPower" and flags.jump then
					return spoofedBase(oldIndex(self, key), baseJump)
				end
			end
			return oldIndex(self, key)
		end))
	end)
	pcall(function()
		local oldNew
		oldNew = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
			local field = onHumanoid(self, key)
			if field == "WalkSpeed" and flags.speed then
				if type(value) == "number" and math.abs(value - baseWalk) > 0.01 then
					return oldNew(self, key, baseWalk)
				end
			elseif field == "JumpPower" and flags.jump then
				if type(value) == "number" and math.abs(value - baseJump) > 0.01 then
					return oldNew(self, key, baseJump)
				end
			end
			return oldNew(self, key, value)
		end))
	end)
end

local function noteBase()
	local h = SpoofingLogic.getHumanoid()
	if not h then
		return
	end
	local SL = env.SpeedLogic
	local speedOn = SL and SL.isEnabled and SL.isEnabled()
	if flags.speed and not speedOn then
		local candidate = h.WalkSpeed
		if type(candidate) == "number" and candidate > 1 then
			baseWalk = candidate
		end
	end
	local JL = env.JumpLogic
	local jumpOn = JL and JL.isEnabled and JL.isEnabled()
	if flags.jump and not jumpOn then
		local candidate = h.JumpPower
		if type(candidate) == "number" and candidate > 1 then
			baseJump = candidate
		end
	end
end

local function applySpeed()
	if not flags.speed then
		return
	end
	local SL = env.SpeedLogic
	local h = SpoofingLogic.getHumanoid()
	if not h then
		return
	end
	local base = baseWalk
	if SL and SL.getBaseSpeed then
		base = SL.getBaseSpeed() or base
	end
	if math.abs(h.WalkSpeed - base) > 0.001 then
		h.WalkSpeed = base
	end
end

local function applyJump()
	if not flags.jump then
		return
	end
	local h = SpoofingLogic.getHumanoid()
	if not h then
		return
	end
	if math.abs(h.JumpPower - baseJump) > 0.001 then
		h.JumpPower = baseJump
	end
end

local function applyTp()
	if not flags.tp then
		return
	end
	if os.clock() < lockUntil and lockCF then
		local root = SpoofingLogic.getRoot()
		if root and (root.CFrame.Position - lockCF.Position).Magnitude > 4 then
			root.CFrame = lockCF
		end
	end
end

local function startKeep()
	if keepTask then
		return
	end
	keepTask = task.spawn(function()
		while enabled do
			pcall(noteBase)
			pcall(applySpeed)
			pcall(applyJump)
			pcall(applyTp)
			task.wait(0.08)
		end
		keepTask = nil
	end)
end

local function stopKeep()
	if keepTask then
		task.cancel(keepTask)
		keepTask = nil
	end
	lockUntil = 0
	lockCF = nil
end

function SpoofingLogic.enable()
	if enabled then
		return true
	end
	enabled = true
	installHooks()
	pcall(function()
		noteBase()
		applySpeed()
		applyJump()
	end)
	startKeep()
	return true
end

function SpoofingLogic.disable()
	if not enabled then
		return true
	end
	enabled = false
	stopKeep()
	return true
end

function SpoofingLogic.toggle()
	if enabled then
		return SpoofingLogic.disable()
	end
	return SpoofingLogic.enable()
end

LocalPlayer.CharacterAdded:Connect(function()
	if enabled then
		task.wait(0.15)
		startKeep()
	end
end)

local TP = env.TPLogic
if type(TP) == "table" and type(TP.teleportTo) == "function" and not TP._spoofWrapped then
	local raw = TP.teleportTo
	TP.teleportTo = function(...)
		local ok = raw(...)
		if ok then
			SpoofingLogic.noteTeleport()
		end
		return ok
	end
	TP._spoofWrapped = true
end

env.SpoofingLogic = SpoofingLogic
return SpoofingLogic
