local env = getgenv and getgenv() or _G
if env.BypassLogic then return env.BypassLogic end

local BypassLogic = {}

local Workspace = game:GetService("Workspace")

local SAFE_REGION = "-100000,-100000,-100000,100000,100000,100000"

local safeOn = false
local antiOn = false

local patched = {}
local guardWaitTask = nil

local attrConn1 = nil
local attrConn2 = nil
local origAttr = nil

local function isGuardTable(v)
	if type(v) ~= "table" then
		return false
	end
	local ok, a, b = pcall(function()
		return rawget(v, "AllowsLocalUse"), rawget(v, "IsInsideSafeZone")
	end)
	return ok and type(a) == "function" and type(b) == "function"
end

local function patchOne(t)
	local current = rawget(t, "AllowsLocalUse")
	if type(current) ~= "function" or current == patched[t] then
		return false
	end
	local orig = current
	local wrapped = function(...)
		if safeOn then
			return false
		end
		if orig then
			return orig(...)
		end
		return false
	end
	local ok = pcall(function()
		t.AllowsLocalUse = wrapped
	end)
	if not ok or rawget(t, "AllowsLocalUse") ~= wrapped then
		return false
	end
	patched[t] = wrapped
	return true
end

local function scanAndPatch()
	local ok = pcall(function()
		for _, v in getgc(true) do
			if isGuardTable(v) then
				patchOne(v)
			end
		end
	end)
	return ok
end

local function patchedCount()
	local n = 0
	for t, fn in pairs(patched) do
		if type(t) == "table" and rawget(t, "AllowsLocalUse") == fn then
			n = n + 1
		end
	end
	return n
end

local function startGuardWait()
	if guardWaitTask then
		return
	end
	guardWaitTask = task.spawn(function()
		while safeOn do
			scanAndPatch()
			task.wait(2)
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
	if patchedCount() > 0 then
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
		scanAndPatch()
		startGuardWait()
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
