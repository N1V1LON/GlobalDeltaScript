local env = getgenv and getgenv() or _G
if env.BypassLogic then return env.BypassLogic end

local BypassLogic = {}

local Workspace = game:GetService("Workspace")

local SAFE_REGION = "-100000,-100000,-100000,100000,100000,100000"

local safeOn = false
local antiOn = false

local guardPatched = false
local guardTable = nil
local origAllows = nil
local guardWaitTask = nil

local attrConn1 = nil
local attrConn2 = nil
local origAttr = nil

local function findGuardModule()
	local ok, res = pcall(function()
		for _, v in getgc(true) do
			if type(v) == "table"
				and type(rawget(v, "AllowsLocalUse")) == "function"
				and type(rawget(v, "IsInsideSafeZone")) == "function"
			then
				return v
			end
		end
		return nil
	end)
	if ok then
		return res
	end
	return nil
end

local function patchGuard()
	if guardPatched then
		return true
	end
	local t = findGuardModule()
	if not t then
		return false
	end
	guardTable = t
	origAllows = rawget(t, "AllowsLocalUse")
	t.AllowsLocalUse = function(...)
		if safeOn then
			return false
		end
		if origAllows then
			return origAllows(...)
		end
		return false
	end
	guardPatched = true
	return true
end

local function startGuardWait()
	if guardWaitTask or guardPatched then
		return
	end
	guardWaitTask = task.spawn(function()
		while safeOn and not guardPatched do
			if patchGuard() then
				break
			end
			task.wait(1)
		end
		guardWaitTask = nil
	end)
end

local function applyAttrs()
	pcall(function()
		Workspace:SetAttribute("ClientObbyAntiTp", true)
		Workspace:SetAttribute("AnticheatSuspendedRegion", SAFE_REGION)
	end)
end

local function restoreAttrs()
	if not origAttr then
		return
	end
	pcall(function()
		Workspace:SetAttribute("ClientObbyAntiTp", origAttr.on)
		Workspace:SetAttribute("AnticheatSuspendedRegion", origAttr.region)
	end)
	origAttr = nil
end

local function holdAttrs()
	if attrConn1 or attrConn2 then
		return
	end
	attrConn1 = Workspace:GetAttributeChangedSignal("ClientObbyAntiTp"):Connect(function()
		if antiOn and Workspace:GetAttribute("ClientObbyAntiTp") ~= true then
			applyAttrs()
		end
	end)
	attrConn2 = Workspace:GetAttributeChangedSignal("AnticheatSuspendedRegion"):Connect(function()
		if antiOn and Workspace:GetAttribute("AnticheatSuspendedRegion") ~= SAFE_REGION then
			applyAttrs()
		end
	end)
end

local function releaseHold()
	if attrConn1 then
		attrConn1:Disconnect()
		attrConn1 = nil
	end
	if attrConn2 then
		attrConn2:Disconnect()
		attrConn2 = nil
	end
end

function BypassLogic.isSafeZone()
	return safeOn
end

function BypassLogic.isAntiTP()
	return antiOn
end

function BypassLogic.isEnabled()
	return safeOn or antiOn
end

function BypassLogic.getGuardStatus()
	if not safeOn then
		return "off"
	end
	if guardPatched then
		return "patched"
	end
	return "waiting"
end

function BypassLogic.getAttrStatus()
	if not antiOn then
		return false
	end
	local ok, res = pcall(function()
		return Workspace:GetAttribute("ClientObbyAntiTp") == true
			and Workspace:GetAttribute("AnticheatSuspendedRegion") == SAFE_REGION
	end)
	return ok and res == true
end

function BypassLogic.setSafeZone(on)
	on = on == true
	safeOn = on
	if on then
		if not patchGuard() then
			startGuardWait()
		end
	end
	return safeOn
end

function BypassLogic.setAntiTP(on)
	on = on == true
	if on == antiOn then
		return antiOn
	end
	antiOn = on
	if on then
		pcall(function()
			origAttr = {
				on = Workspace:GetAttribute("ClientObbyAntiTp"),
				region = Workspace:GetAttribute("AnticheatSuspendedRegion"),
			}
		end)
		applyAttrs()
		holdAttrs()
	else
		releaseHold()
		restoreAttrs()
	end
	return antiOn
end

function BypassLogic.enable()
	BypassLogic.setSafeZone(true)
	BypassLogic.setAntiTP(true)
	return true
end

function BypassLogic.disable()
	BypassLogic.setSafeZone(false)
	BypassLogic.setAntiTP(false)
	return true
end

function BypassLogic.toggle()
	if BypassLogic.isEnabled() then
		return BypassLogic.disable()
	end
	return BypassLogic.enable()
end

env.BypassLogic = BypassLogic
return BypassLogic
