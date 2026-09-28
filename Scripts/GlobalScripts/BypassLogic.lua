local env = getgenv and getgenv() or _G
if env.BypassLogic then return env.BypassLogic end

local BypassLogic = {}

local Workspace = game:GetService("Workspace")

local SAFE_REGION = "-100000,-100000,-100000,100000,100000,100000"

local safeOn = false
local antiOn = false

local reviveOn = true
local reviveCharConn = nil
local reviveCount = 0
local reviveWindow = 0

local LP = game:GetService("Players").LocalPlayer

local patched = {}
local guardWaitTask = nil

local attrConn1 = nil
local attrConn2 = nil
local origAttr = nil

local function hookRevive(char)
	if not (reviveOn and antiOn) then
		return
	end
	pcall(function()
		local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
		if not hum or hum:GetAttribute("BLReviveHooked") then
			return
		end
		hum:SetAttribute("BLReviveHooked", true)
		local last = hum.Health
		hum.HealthChanged:Connect(function(h)
			if h > 0 then
				last = h
				return
			end
			if not (reviveOn and antiOn) then
				return
			end
			local now = os.clock()
			if now - reviveWindow > 10 then
				reviveWindow = now
				reviveCount = 0
			end
			reviveCount = reviveCount + 1
			if reviveCount > 500 then
				return
			end
			local G = getgenv and getgenv() or _G
			G.BLRevives = (G.BLRevives or 0) + 1
			pcall(function()
				local back = (last and last > 0) and last or math.max(hum.MaxHealth, 100)
				hum.Health = back
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end)
	end)
end

local function startRevive()
	if reviveCharConn then
		return
	end
	pcall(function()
		reviveCharConn = LP.CharacterAdded:Connect(hookRevive)
		if LP.Character then
			task.spawn(hookRevive, LP.Character)
		end
	end)
end

local function stopRevive()
	if reviveCharConn then
		reviveCharConn:Disconnect()
		reviveCharConn = nil
	end
end

local function oursHumanoid(self)
	if typeof(self) ~= "Instance" or not self:IsA("Humanoid") then
		return false
	end
	local ok, ours = pcall(function()
		return LP.Character ~= nil and self:IsDescendantOf(LP.Character)
	end)
	return ok and ours == true
end

local function ensureNCHook()
	local G = getgenv and getgenv() or _G
	if not (hookmetamethod and getnamecallmethod) then
		return
	end
	if not G.BypassLogicNC then
		G.BypassLogicNC = true
		pcall(function()
			local old
			old = hookmetamethod(game, "__namecall", function(self, ...)
				local m = getnamecallmethod()
				if m == "ChangeState" then
					local st = ...
					if reviveOn and antiOn and st == Enum.HumanoidStateType.Dead and oursHumanoid(self) then
						G.BLDeadSuppressed = (G.BLDeadSuppressed or 0) + 1
						return nil
					end
				elseif m == "TakeDamage" then
					if reviveOn and antiOn and oursHumanoid(self) then
						G.BLTakeDmgBlocked = (G.BLTakeDmgBlocked or 0) + 1
						return nil
					end
				end
				return old(self, ...)
			end)
		end)
	end
	if not G.BypassLogicNI then
		G.BypassLogicNI = true
		pcall(function()
			local oldni
			oldni = hookmetamethod(game, "__newindex", function(self, k, v)
				if k == "Health" and reviveOn and antiOn and oursHumanoid(self) and type(v) == "number" and v <= 0 then
					G.BLHpBlocked = (G.BLHpBlocked or 0) + 1
					return nil
				end
				return oldni(self, k, v)
			end)
		end)
	end
end

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
		local G = getgenv and getgenv() or _G
		if G.BypassDiagAttrLock then
			return
		end
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

function BypassLogic.isOurs(t)
	if type(t) ~= "table" then
		return false
	end
	return patched[t] ~= nil and patched[t] == rawget(t, "AllowsLocalUse")
end

function BypassLogic.getPatchedCount()
	return patchedCount()
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
		ensureNCHook()
		startRevive()
	else
		releaseHold()
		restoreAttrs()
		stopRevive()
	end
	return antiOn
end

function BypassLogic.setRevive(on)
	reviveOn = on == true
	if reviveOn and antiOn then
		startRevive()
	elseif not reviveOn then
		stopRevive()
	end
	return reviveOn
end

function BypassLogic.isRevive()
	return reviveOn
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
