local env = getgenv and getgenv() or _G
local EXPECT_PLACE = 107778070777162

local findings = {}
local function add(cap, val, status)
	findings[#findings + 1] = { cap = cap, val = tostring(val), status = status }
end

local function try(fn, def)
	local ok, res = pcall(fn)
	if ok and res ~= nil then
		return res
	end
	return def
end

local G = getgenv and getgenv() or _G
G.BypassDiagLog = G.BypassDiagLog or {}
local events = G.BypassDiagLog
local flushQueued = false

local function flush()
	local lines = {}
	for _, e in ipairs(events) do
		lines[#lines + 1] = e
	end
	lines[#lines + 1] = "--- FINDINGS ---"
	for _, f in ipairs(findings) do
		lines[#lines + 1] = f.cap .. " = " .. f.val
	end
	local ok, err = pcall(writefile, "BypassDiagLog.txt", table.concat(lines, "\n"))
	if not ok then
		warn("[BypassDiag] log write failed: " .. tostring(err))
	end
end

local function log(s)
	events[#events + 1] = os.date("%H:%M:%S") .. "  " .. s
	if not flushQueued then
		flushQueued = true
		task.delay(0.4, function()
			flushQueued = false
			flush()
		end)
	end
end

log("=== BypassDiag start PlaceId=" .. tostring(game.PlaceId) .. " GameId=" .. tostring(game.GameId) .. " ===")

local function capturePrint(tag, ...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local line = table.concat(parts, " ")
	if line:find("ObbyAntiTP", 1, true) or line:find("KILL", 1, true) then
		G.BypassDiagCapN = (G.BypassDiagCapN or 0) + 1
		if line:find("flag #", 1, true) then
			G.BypassDiagFlagN = (G.BypassDiagFlagN or 0) + 1
			G.BypassDiagLagWin = os.clock()
		end
		log(tag .. line)
	end
end

if not G.BypassDiagHooked then
	G.BypassDiagHooked = true
	pcall(function()
		local oldPrint
		oldPrint = hookfunction(print, function(...)
			capturePrint("[print] ", ...)
			if oldPrint then
				return oldPrint(...)
			end
		end)
	end)
	pcall(function()
		local oldWarn
		oldWarn = hookfunction(warn, function(...)
			capturePrint("[warn] ", ...)
			if oldWarn then
				return oldWarn(...)
			end
		end)
	end)
end

local GC = env.GlobalControler
local L = env.BypassLogic
local W = env.BypassWindow

add("PlaceId", tostring(game.PlaceId) .. (tonumber(game.PlaceId) == EXPECT_PLACE and "  OK" or "  != " .. EXPECT_PLACE), tonumber(game.PlaceId) == EXPECT_PLACE)
add("GameId", tostring(game.GameId))
add("GC", GC and (tostring(GC.VERSION) .. "  running=" .. tostring(GC.Running)) or "НЕТ", GC ~= nil)
add("Base", GC and tostring(GC.Base) or "-")

local inMod, inSkip, skipPath = false, false, ""
if GC then
	for _, e in ipairs(GC.Modules or {}) do
		if e.name == "BypassWindow" then
			inMod = true
		end
	end
	for _, e in ipairs(GC.Skipped or {}) do
		if e.name == "BypassWindow" then
			inSkip = true
			skipPath = tostring(e.path)
		end
	end
end
add("BypassWindow в Modules", tostring(inMod), inMod)
if inSkip then
	add("BypassWindow в Skipped", skipPath, false)
end
add("env.BypassWindow", W and "есть" or "NIL", W ~= nil)
add("env.BypassLogic", L and "есть" or "NIL", L ~= nil)

if GC then
	add("Errors BypassWindow", tostring(GC.Errors and GC.Errors["BypassWindow"] or "-"), not (GC.Errors and GC.Errors["BypassWindow"]))
	add("Errors BypassLogic", tostring(GC.Errors and GC.Errors["BypassLogic"] or "-"), not (GC.Errors and GC.Errors["BypassLogic"]))
end

local wmod = W
if not wmod and GC then
	for _, e in ipairs(GC.Skipped or {}) do
		if e.name == "BypassWindow" then
			wmod = e.mod
		end
	end
end

local scope, places, allows = "?", "?", "?"
if GC and type(wmod) == "table" then
	scope = try(function()
		return GC:ResolveScope("BypassWindow", wmod)
	end, "?")
	places = try(function()
		local p = GC:ResolvePlaces("BypassWindow", wmod)
		if type(p) == "table" then
			return "{" .. table.concat(p, ",") .. "}"
		end
		return tostring(p)
	end, "?")
	allows = tostring(try(function()
		return GC:ScopeAllows("BypassWindow", wmod)
	end, "?"))
end
add("ResolveScope", scope, scope == "place")
add("ResolvePlaces", places)
add("ScopeAllows", allows, allows == "true")

local cm = GC and GC.Config and GC.Config.modules and GC.Config.modules.BypassWindow
if type(cm) == "table" then
	local bits = {}
	for _, k in ipairs({ "scope", "places", "enabled", "safeZone", "antiTP" }) do
		if cm[k] ~= nil then
			bits[#bits + 1] = k .. "=" .. tostring(cm[k] and (type(cm[k]) == "table" and table.concat(cm[k], ",") or cm[k]) or "false")
		end
	end
	add("Config.modules.BypassWindow", #bits > 0 and table.concat(bits, " ") or "{}")
else
	add("Config.modules.BypassWindow", "нет записи")
end

local function stateRow()
	local LL = env.BypassLogic
	if not LL then
		return "нет логики", false
	end
	return ("enabled=%s safe=%s anti=%s guard=%s attr=%s revive=%s"):format(
		tostring(LL.isEnabled()),
		tostring(LL.isSafeZone()),
		tostring(LL.isAntiTP()),
		tostring(LL.getGuardStatus()),
		tostring(LL.getAttrStatus()),
		LL.isRevive and tostring(LL.isRevive()) or "n/a"
	), LL.isSafeZone() == true
end

local v, s = stateRow()
add("Состояние", v, s)

add("Атрибут ClientObbyAntiTp", tostring(try(function()
	return game:GetService("Workspace"):GetAttribute("ClientObbyAntiTp")
end, "nil")), try(function()
	return game:GetService("Workspace"):GetAttribute("ClientObbyAntiTp") == true
end, false))
add("Атрибут SuspendedRegion", tostring(try(function()
	return game:GetService("Workspace"):GetAttribute("AnticheatSuspendedRegion")
end, "nil")), try(function()
	return game:GetService("Workspace"):GetAttribute("AnticheatSuspendedRegion") == "-100000,-100000,-100000,100000,100000,100000"
end, false))

local function scanGuard()
	local found, patchedN = 0, 0
	local LL = env.BypassLogic
	try(function()
		for _, g in getgc(true) do
			if type(g) == "table" then
				local a = rawget(g, "AllowsLocalUse")
				local b = rawget(g, "IsInsideSafeZone")
				if type(a) == "function" and type(b) == "function" then
					found = found + 1
					local ours = false
					if LL and type(LL.isOurs) == "function" then
						ours = LL.isOurs(g) == true
					end
					if not ours and debug and debug.getupvalue then
						local i = 1
						while true do
							local name = debug.getupvalue(a, i)
							if not name then
								break
							end
							if name == "safeOn" then
								ours = true
							end
							i = i + 1
						end
					end
					if ours then
						patchedN = patchedN + 1
					end
				end
			end
		end
	end)
	return found, patchedN
end

local gf, gp = scanGuard()
add("Guard-таблиц в GC", gf, gf > 0)
add("Из них патченных нами", gp, gp > 0)

local expectAuto = (scope == "place" and allows == "true")
add("Ожидался автобуст на старте", tostring(expectAuto), expectAuto)

local function killOld(parent)
	pcall(function()
		local old = parent:FindFirstChild("BypassDiag")
		if old then
			old:Destroy()
		end
	end)
end
pcall(function()
	killOld(game:GetService("CoreGui"))
end)
pcall(function()
	killOld(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
end)

local gui = Instance.new("ScreenGui")
gui.Name = "BypassDiag"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
pcall(function()
	gui.Parent = game:GetService("CoreGui")
end)
if not gui.Parent then
	gui.Parent = env.PlayerGui or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local cam = workspace.CurrentCamera
local vs = try(function()
	return cam.ViewportSize
end, Vector2.new(800, 600))
local winW = math.min(560, vs.X - 16)
local winH = math.min(620, vs.Y - 16)

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(winW, winH)
frame.AnchorPoint = Vector2.new(0, 0)
frame.Position = UDim2.fromOffset(math.max(4, (vs.X - winW) / 2), math.max(4, (vs.Y - winH) / 2))

local function clampFrame()
	local sz = frame.AbsoluteSize
	local x = math.clamp(frame.Position.X.Offset, 4, math.max(4, vs.X - sz.X - 4))
	local y = math.clamp(frame.Position.Y.Offset, 4, math.max(4, vs.Y - sz.Y - 4))
	frame.Position = UDim2.fromOffset(x, y)
end

local function refit()
	pcall(function()
		vs = cam.ViewportSize
	end)
	winW = math.min(560, vs.X - 16)
	winH = math.min(620, vs.Y - 16)
	frame.Size = UDim2.fromOffset(winW, winH)
	clampFrame()
end
if cam then
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
end
task.defer(clampFrame)
frame.BackgroundColor3 = Color3.fromRGB(15, 19, 29)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local bar = Instance.new("TextButton")
bar.Name = "Bar"
bar.Size = UDim2.new(1, 0, 0, 28)
bar.BackgroundTransparency = 1
bar.AutoButtonColor = false
bar.Text = ""
bar.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "BypassDiag  ·  " .. tostring(GC and GC.VERSION or "GC нет")
title.TextColor3 = Color3.fromRGB(0, 242, 254)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextTruncate = Enum.TextTruncate.AtEnd
title.Parent = bar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(24, 22)
minBtn.Position = UDim2.new(1, -54, 0.5, -11)
minBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 52)
minBtn.BorderSizePixel = 0
minBtn.Text = "–"
minBtn.TextColor3 = Color3.fromRGB(223, 226, 240)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 14
minBtn.Parent = bar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(24, 22)
closeBtn.Position = UDim2.new(1, -26, 0.5, -11)
closeBtn.BackgroundColor3 = Color3.fromRGB(147, 0, 10)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Parent = bar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -100)
scroll.Position = UDim2.fromOffset(10, 32)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local function row(parent, cap, val, status, i)
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, -4, 0, 22)
	r.BackgroundColor3 = Color3.fromRGB(23, 28, 37)
	r.BorderSizePixel = 0
	r.LayoutOrder = i
	r.Parent = parent
	Instance.new("UICorner", r).CornerRadius = UDim.new(0, 4)

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0.42, 0, 1, 0)
	l.Position = UDim2.fromOffset(8, 0)
	l.BackgroundTransparency = 1
	l.Text = cap
	l.TextColor3 = Color3.fromRGB(185, 202, 203)
	l.Font = Enum.Font.Gotham
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = r

	local v2 = Instance.new("TextLabel")
	v2.Size = UDim2.new(0.58, -12, 1, 0)
	v2.Position = UDim2.new(0.42, 4, 0, 0)
	v2.BackgroundTransparency = 1
	v2.Text = val
	v2.TextColor3 = status == true and Color3.fromRGB(52, 211, 153)
		or status == false and Color3.fromRGB(251, 113, 133)
		or Color3.fromRGB(223, 226, 240)
	v2.Font = Enum.Font.Code
	v2.TextSize = 11
	v2.TextXAlignment = Enum.TextXAlignment.Left
	v2.TextTruncate = Enum.TextTruncate.AtEnd
	v2.Parent = r
	return r
end

local function liveVal(cap)
	local G2 = getgenv and getgenv() or _G
	if cap == "Ревайв-счётчики" then
		return "revives=" .. tostring(G2.BLRevives or 0) .. " suppressed-Dead=" .. tostring(G2.BLDeadSuppressed or 0), (G2.BLRevives or 0) > 0
	elseif cap == "Лагбэк-блок" then
		return "PivotTo блок.: " .. tostring(G2.BypassDiagPivotBlocked or 0) .. " · flag: " .. tostring(G2.BypassDiagFlagN or 0), (G2.BypassDiagPivotBlocked or 0) > 0
	elseif cap == "HP-блок" then
		return "hp≤0 записей блок.: " .. tostring(G2.BLHpBlocked or 0) .. " · TakeDamage: " .. tostring(G2.BLTakeDmgBlocked or 0) .. " · hp-писец: " .. tostring(G2.BypassDiagHpWrite or 0), (G2.BLHpBlocked or 0) > 0
	end
	return nil
end

local function render()
	for _, f in ipairs(findings) do
		local v, s = liveVal(f.cap)
		if v then
			f.val = v
			if s ~= nil then
				f.status = s
			end
		end
	end
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, f in ipairs(findings) do
		row(scroll, f.cap, f.val, f.status, i)
	end
	pcall(flush)
end
render()

local deathN = 0
local function hookDeath(char)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not hum or hum:GetAttribute("DiagHooked") then
		return
	end
	hum:SetAttribute("DiagHooked", true)
	local hpHist = {}
	pcall(function()
		hum.StateChanged:Connect(function(_, ns)
			if ns == Enum.HumanoidStateType.Dead then
				log("STATE Died #" .. deathN)
			end
		end)
	end)
	hum.HealthChanged:Connect(function(h)
		hpHist[#hpHist + 1] = string.format("%.1fs hp=%.0f", os.clock(), h)
		if #hpHist > 14 then
			table.remove(hpHist, 1)
		end
		if h > 0 then
			return
		end
		deathN = deathN + 1
		local noisy = (deathN == 1) or (deathN % 10 == 1)
		if not noisy then
			log("DEATH #" .. deathN .. " hp=0")
			return
		end
		local wsa, wsr
		pcall(function()
			wsa = game:GetService("Workspace"):GetAttribute("ClientObbyAntiTp")
			wsr = game:GetService("Workspace"):GetAttribute("AnticheatSuspendedRegion")
		end)
		local LL = env.BypassLogic
		local info = ("hp=0 · anti=%s guard=%s attr=%s region=%s"):format(
			LL and tostring(LL.isAntiTP()) or "n/a",
			LL and tostring(LL.getGuardStatus()) or "n/a",
			tostring(wsa),
			tostring(wsr)
		)
		findings[#findings + 1] = { cap = "Смерть #" .. deathN .. " " .. os.date("%H:%M:%S"), val = info, status = false }
		warn("[BypassDiag] DEATH #" .. deathN .. " " .. info)
		log("DEATH #" .. deathN .. " " .. info)
		log("HP-ряд #" .. deathN .. ": " .. table.concat(hpHist, " → "))
		if G.BypassDiagREBuf and #G.BypassDiagREBuf > 0 then
			local from = math.max(1, #G.BypassDiagREBuf - 29)
			local slice = {}
			for i = from, #G.BypassDiagREBuf do
				slice[#slice + 1] = G.BypassDiagREBuf[i]
			end
			log("REM-BUF@death" .. deathN .. ": " .. table.concat(slice, " || "))
		end
		if debug and debug.traceback then
			local tb = try(function()
				return debug.traceback("", 2)
			end, nil)
			if tb and #tb > 5 then
				findings[#findings + 1] = { cap = "  traceback", val = (tb:gsub("\n", " | ")):sub(1, 200), status = nil }
				warn("[BypassDiag] TB #" .. deathN .. ": " .. tb)
			end
		end
		render()
	end)
end
pcall(function()
	local LP = game:GetService("Players").LocalPlayer
	LP.CharacterAdded:Connect(hookDeath)
	if LP.Character then
		hookDeath(LP.Character)
	end
end)

if not G.BypassDiagRemotes then
	G.BypassDiagRemotes = true
	local ok, err = pcall(function()
		local RS = game:GetService("ReplicatedStorage")
		local Remotes = require(RS:WaitForChild("Shared"):WaitForChild("Remotes", 10))
		local tapped = 0
		local seen = {}
		G.BypassDiagREBuf = G.BypassDiagREBuf or {}
		local buf = G.BypassDiagREBuf
		local IMPORTANT = { "kill", "punish", "damage", "death", "correct", "reconcile", "flag", "moderat", "ban", "locate", "teleport", "lag", "reloc", "refresh", "speed", "position" }
		local function push(path, name, s)
			local key = path .. "." .. name
			buf[#buf + 1] = os.date("%H:%M:%S") .. " " .. key .. ": " .. s
			if #buf > 60 then
				table.remove(buf, 1)
			end
			local low = name:lower()
			for _, w in ipairs(IMPORTANT) do
				if low:find(w, 1, true) then
					log("REMOTE-ВАЖНЫЙ " .. key .. ": " .. s)
					return
				end
			end
		end
		local function tapOne(path, name, r)
			if typeof(r) ~= "Instance" or not r:IsA("RemoteEvent") or seen[r] then
				return
			end
			seen[r] = true
			r.OnClientEvent:Connect(function(...)
				local parts = {}
				for i = 1, select("#", ...) do
					parts[i] = tostring((select(i, ...)))
				end
				local s = table.concat(parts, " ")
				if #s > 160 then
					s = s:sub(1, 160) .. "..."
				end
				push(path, name, s)
			end)
			tapped = tapped + 1
		end
		local function walk(node, path, depth)
			if depth > 4 then
				return
			end
			if typeof(node) == "Instance" then
				if node:IsA("RemoteEvent") then
					tapOne(path, node.Name, node)
				else
					for _, ch in ipairs(node:GetChildren()) do
						walk(ch, path .. "." .. ch.Name, depth + 1)
					end
				end
			elseif type(node) == "table" then
				if seen[node] then
					return
				end
				seen[node] = true
				for k, v in pairs(node) do
					if type(k) == "string" or type(k) == "number" then
						walk(v, path .. "." .. tostring(k), depth + 1)
					end
				end
			end
		end
		walk(Remotes, "Remotes", 0)
		add("Remote-тапы", tostring(tapped) .. " RE (буфер 60)", tapped > 0)
	end)
	if not ok then
		add("Remote-тапы", "ошибка: " .. tostring(err), false)
	end
else
	add("Remote-тапы", "уже были с прошлого запуска", true)
end

if not G.BypassDiagNC and hookmetamethod and getnamecallmethod then
	local ok = pcall(function()
		local last = G.BypassDiagAttrSeen or {}
		G.BypassDiagAttrSeen = last
		local WS = game:GetService("Workspace")
		local function watch(nm)
			return nm == "ClientObbyAntiTp"
				or nm == "AnticheatSuspendedRegion"
				or nm == "ClientObbyAntiTpDebug"
		end
		local old
		old = hookmetamethod(game, "__namecall", function(self, ...)
			local m = getnamecallmethod()
			if m == "GetAttribute" then
				local r = old(self, ...)
				local nm = ...
				if self == WS and type(nm) == "string" and watch(nm) then
					local sv = tostring(r)
					if last[nm] ~= sv then
						last[nm] = sv
						log("ATTR read " .. nm .. " → " .. sv)
					end
				end
				return r
			elseif m == "SetAttribute" then
				local nm, val = ...
				if self == WS and type(nm) == "string" and watch(nm) then
					last[nm] = tostring(val)
					local tb = ""
					if debug and debug.traceback then
						tb = (debug.traceback("", 2):gsub("\n", " | ")):sub(1, 170)
					end
					log(("ATTR write %s=%s :: %s"):format(nm, tostring(val), tb))
				end
				return old(self, ...)
			elseif m == "ChangeState" then
				local st = ...
				if st == Enum.HumanoidStateType.Dead and typeof(self) == "Instance" and self:IsA("Humanoid") then
					local LP = game:GetService("Players").LocalPlayer
					if LP and LP.Character and self:IsDescendantOf(LP.Character) then
						local now = os.clock()
						if not G.BypassDiagCSLast or now - G.BypassDiagCSLast > 2 then
							G.BypassDiagCSLast = now
							G.BypassDiagCSN = (G.BypassDiagCSN or 0) + 1
							local tb = ""
							if debug and debug.traceback then
								tb = (debug.traceback("", 2):gsub("\n", " | ")):sub(1, 240)
							end
							log("ChangeState(Dead) #" .. G.BypassDiagCSN .. " :: " .. tb)
						end
					end
				end
				return old(self, ...)
			elseif m == "PivotTo" then
				local win = G.BypassDiagLagWin
				if win and os.clock() - win < 0.45 and typeof(self) == "Instance" then
					local LP = game:GetService("Players").LocalPlayer
					local ch = LP and LP.Character
					if ch and self == ch then
						G.BypassDiagLagWin = nil
						G.BypassDiagPivotBlocked = (G.BypassDiagPivotBlocked or 0) + 1
						log("LAG-BLOCK PivotTo #" .. G.BypassDiagPivotBlocked .. " (ObbyAntiTP lagback пойман)")
						return nil
					end
				end
				return old(self, ...)
			end
			return old(self, ...)
		end)
	end)
	if ok then
		G.BypassDiagNC = true
		add("namecall-тап", "ok", true)
	else
		add("namecall-тап", "hookfailed", false)
	end
elseif G.BypassDiagNC then
	add("namecall-тап", "уже был с прошлого запуска", true)
else
	add("namecall-тап", "hookmetamethod нет", false)
end

if not G.BypassDiagNI and hookmetamethod then
	local ok = pcall(function()
		local lastLog = 0
		local oldni
		oldni = hookmetamethod(game, "__newindex", function(self, k, v)
			if k == "Health" and typeof(self) == "Instance" and self:IsA("Humanoid") then
				local LP = game:GetService("Players").LocalPlayer
				if LP and LP.Character and self:IsDescendantOf(LP.Character) and type(v) == "number" and v <= 0 then
					G.BypassDiagHpWrite = (G.BypassDiagHpWrite or 0) + 1
					local now = os.clock()
					if now - lastLog > 1.5 then
						lastLog = now
						local tb = ""
						if debug and debug.traceback then
							tb = (debug.traceback("", 2):gsub("\n", " | ")):sub(1, 260)
						end
						log(("HP-WRITE v=%s #%d :: %s"):format(tostring(v), G.BypassDiagHpWrite, tb))
					end
				end
			end
			return oldni(self, k, v)
		end)
	end)
	if ok then
		G.BypassDiagNI = true
		add("HP-write-тап", "ok", true)
	else
		add("HP-write-тап", "hookfailed", false)
	end
elseif G.BypassDiagNI then
	add("HP-write-тап", "уже был с прошлого запуска", true)
else
	add("HP-write-тап", "hookmetamethod нет", false)
end

task.spawn(function()
	local hit = nil
	local matches = {}
	local function consider(m, src)
		local ok, full = pcall(function()
			return m:GetFullName()
		end)
		full = ok and full or "?"
		local n = tostring(m.Name):lower()
		log(("CONTENT-кандидат [%s]: %s (%s)"):format(src, full, tostring(m.ClassName)))
		matches[#matches + 1] = { m = m, exact = n == "contentcatalog", ugi = full:find("UGI", 1, true) ~= nil }
	end
	pcall(function()
		if type(getloadedmodules) == "function" then
			for _, m in ipairs(getloadedmodules()) do
				local n = tostring(m.Name):lower()
				if n:find("contentcatalog", 1, true) or n:find("ugi", 1, true) or n:find("catalog", 1, true) then
					consider(m, "modules")
				end
			end
		else
			log("getloadedmodules недоступен")
		end
	end)
	pcall(function()
		if type(getscripts) == "function" then
			for _, s in ipairs(getscripts()) do
				local n = tostring(s.Name):lower()
				if n:find("contentcatalog", 1, true) or n:find("ugi", 1, true) then
					consider(s, "scripts")
				end
			end
		else
			log("getscripts недоступен")
		end
	end)
	table.sort(matches, function(a, b)
		if a.exact ~= b.exact then
			return a.exact
		end
		if a.ugi ~= b.ugi then
			return a.ugi
		end
		return false
	end)
	if #matches > 0 then
		hit = matches[1].m
	end
	pcall(function()
		if not hit then
			for _, d in ipairs(game:GetService("ReplicatedFirst"):GetDescendants()) do
				if d.Name == "ContentCatalog" then
					hit = d
					break
				end
			end
		end
	end)
	if hit then
		local path = try(function()
			return hit:GetFullName()
		end, tostring(hit.Name)) .. " (" .. hit.ClassName .. ")"
		log("ContentCatalog (выбран): " .. path)
		pcall(function()
			if type(getscriptbytecode) == "function" then
				local ok2, bc = pcall(getscriptbytecode, hit)
				if ok2 and type(bc) == "string" then
					log("ContentCatalog bytecode: " .. #bc .. " байт")
					pcall(function()
						writefile("ContentCatalog_bc.bin", bc)
						log("bytecode → Workspace/ContentCatalog_bc.bin")
					end)
				else
					log("bytecode ответ: " .. tostring(bc):sub(1, 120))
				end
			end
		end)
		pcall(function()
			if type(decompile) == "function" then
				local ok3, src = pcall(decompile, hit)
				if ok3 and type(src) == "string" and #src > 40 then
					writefile("ContentCatalog_decomp.lua", src)
					log("ContentCatalog decompiled → Workspace/ContentCatalog_decomp.lua (" .. #src .. " символов)")
				else
					log("decompile ответ: " .. tostring(src):sub(1, 120))
				end
			else
				log("decompile() в Delta нет")
			end
		end)
		add("ContentCatalog", path, true)
	else
		log("ContentCatalog не найден ни в modules, ни в scripts, ни в дереве")
		add("ContentCatalog", "не найден", false)
	end
	local G2 = getgenv and getgenv() or _G
	add("Ревайв-счётчики", "revives=" .. tostring(G2.BLRevives or 0) .. " suppressed-Dead=" .. tostring(G2.BLDeadSuppressed or 0))
	add("Лагбэк-блок", "PivotTo блок.: " .. tostring(G2.BypassDiagPivotBlocked or 0) .. " · flag: " .. tostring(G2.BypassDiagFlagN or 0), (G2.BypassDiagPivotBlocked or 0) > 0)
	add("HP-блок", "hp≤0 записей блок.: " .. tostring(G2.BLHpBlocked or 0) .. " · TakeDamage: " .. tostring(G2.BLTakeDmgBlocked or 0), (G2.BLHpBlocked or 0) > 0)
	render()
end)
render()

task.spawn(function()
	pcall(function()
		game:GetService("Workspace"):SetAttribute("ClientObbyAntiTpDebug", true)
	end)
	if G.BypassDiagAB then
		return
	end
	G.BypassDiagAB = true
	local WS = game:GetService("Workspace")
	local SAFE = "-100000,-100000,-100000,100000,100000,100000"
	local function pulse()
		pcall(function()
			WS:SetAttribute("AnticheatSuspendedRegion", "1,1,1,2,2,2")
		end)
		task.wait(0)
		pcall(function()
			WS:SetAttribute("AnticheatSuspendedRegion", SAFE)
		end)
		task.wait(0.2)
	end
	local function capN()
		return G.BypassDiagCapN or 0
	end
	pcall(function()
		WS:SetAttribute("ClientObbyAntiTpDebug", true)
	end)
	local n0 = capN()
	pulse()
	local gotTrue = capN() - n0
	pcall(function()
		WS:SetAttribute("ClientObbyAntiTpDebug", false)
	end)
	local n1 = capN()
	pulse()
	local gotFalse = capN() - n1
	local verdict
	if gotTrue > 0 then
		verdict = "включается Debug=true"
		pcall(function()
			WS:SetAttribute("ClientObbyAntiTpDebug", true)
		end)
	elseif gotFalse > 0 then
		verdict = "печатает всегда (Debug мешает)"
		pcall(function()
			WS:SetAttribute("ClientObbyAntiTpDebug", false)
		end)
	else
		verdict = "НЕ ПЕЧАТАЕТ (Start не отработал?)"
		pcall(function()
			WS:SetAttribute("ClientObbyAntiTpDebug", true)
		end)
	end
	local msg = ("Debug=true→%d, Debug=false→%d · %s"):format(gotTrue, gotFalse, verdict)
	log("print-test: " .. msg)
	findings[#findings + 1] = { cap = "ObbyAntiTP print-test", val = msg, status = gotTrue + gotFalse > 0 }
	findings[#findings + 1] = {
		cap = "Атрибут ClientObbyAntiTpDebug",
		val = tostring(try(function()
			return WS:GetAttribute("ClientObbyAntiTpDebug")
		end, "nil")),
		status = nil,
	}
	render()
end)

local btnRow = Instance.new("Frame")
btnRow.Size = UDim2.new(1, -20, 0, 28)
btnRow.Position = UDim2.new(0, 10, 1, -60)
btnRow.BackgroundTransparency = 1
btnRow.Parent = frame

local btnRow2 = Instance.new("Frame")
btnRow2.Size = UDim2.new(1, -20, 0, 28)
btnRow2.Position = UDim2.new(0, 10, 1, -32)
btnRow2.BackgroundTransparency = 1
btnRow2.Parent = frame

local bubble

local function mkbtn(text, x, w, parent, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, 26)
	b.Position = UDim2.fromOffset(x, 0)
	b.BackgroundColor3 = Color3.fromRGB(38, 42, 52)
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = Color3.fromRGB(223, 226, 240)
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 11
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
	b.MouseButton1Click:Connect(cb)
	return b
end

mkbtn("Включить Bypass", 0, 130, btnRow, function()
	local msg = "?"
	local LL = env.BypassLogic
	local WW = env.BypassWindow
	if LL then
		local ok, err = pcall(LL.enable)
		msg = ok and ("включено guard=" .. tostring(LL.getGuardStatus())) or ("ошибка: " .. tostring(err))
	elseif WW and type(WW.SetOn) == "function" then
		local ok, err = pcall(WW.SetOn, true)
		msg = ok and "SetOn(true)" or ("ошибка: " .. tostring(err))
	else
		msg = "нет BypassLogic/BypassWindow"
	end
	findings[#findings + 1] = { cap = "Пробное включение", val = msg, status = msg:sub(1, 3) ~= "оши" }
	log("enable: " .. msg)
	local v2, s2 = stateRow()
	findings[#findings + 1] = { cap = "Состояние после", val = v2, status = s2 }
	local f2, p2 = scanGuard()
	findings[#findings + 1] = { cap = "Guard после", val = f2 .. " найдено / " .. p2 .. " патч", status = p2 > 0 }
	render()
end)

mkbtn("Обновить", 136, 90, btnRow, function()
	GC = env.GlobalControler
	L = env.BypassLogic
	W = env.BypassWindow
	findings[#findings + 1] = { cap = "GC (повторно)", val = GC and (tostring(GC.VERSION) .. "  running=" .. tostring(GC.Running)) or "НЕТ", status = GC ~= nil }
	findings[#findings + 1] = { cap = "env.BypassLogic (повторно)", val = L and "есть" or "NIL", status = L ~= nil }
	findings[#findings + 1] = { cap = "env.BypassWindow (повторно)", val = W and "есть" or "NIL", status = W ~= nil }
	title.Text = "BypassDiag  ·  " .. tostring(GC and GC.VERSION or "GC нет")
	local v2, s2 = stateRow()
	findings[#findings + 1] = { cap = "Состояние (повторно)", val = v2, status = s2 }
	local f2, p2 = scanGuard()
	findings[#findings + 1] = { cap = "Guard (повторно)", val = f2 .. " найдено / " .. p2 .. " патч", status = p2 > 0 }
	render()
end)

mkbtn("Свернуть", 232, 84, btnRow, function()
	frame.Visible = false
	bubble.Visible = true
end)

mkbtn("ТП: attr=false", 0, 100, btnRow2, function()
	G.BypassDiagAttrLock = true
	pcall(function()
		game:GetService("Workspace"):SetAttribute("ClientObbyAntiTp", false)
	end)
	local v = tostring(game:GetService("Workspace"):GetAttribute("ClientObbyAntiTp"))
	findings[#findings + 1] = {
		cap = "Эксперимент attr=false",
		val = "attr=" .. v .. " guard=LOCK → жми «Авто-тест»",
		status = nil,
	}
	log("EXPERIMENT: attr=false lock=true → " .. v)
	render()
end)

mkbtn("ТП: attr=true", 104, 92, btnRow2, function()
	G.BypassDiagAttrLock = false
	pcall(function()
		game:GetService("Workspace"):SetAttribute("ClientObbyAntiTp", true)
	end)
	local v = tostring(game:GetService("Workspace"):GetAttribute("ClientObbyAntiTp"))
	findings[#findings + 1] = {
		cap = "Эксперимент attr=true",
		val = "attr=" .. v .. " guard=UNLOCK (по умолчанию)",
		status = true,
	}
	log("EXPERIMENT: attr=true lock=false → " .. v)
	render()
end)

local function runAutoTest()
	if G.BypassDiagAT then
		findings[#findings + 1] = { cap = "Авто-тест", val = "уже идёт", status = nil }
		render()
		return
	end
	G.BypassDiagAT = true
	G.BypassDiagATdone = true
	task.spawn(function()
		local WS = game:GetService("Workspace")
		local function sim()
			local char = game:GetService("Players").LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then
				return false, "нет HumanoidRootPart"
			end
			hrp.CFrame = hrp.CFrame * CFrame.new(200, 0, 0)
			return true
		end
		local function flagN()
			return G.BypassDiagFlagN or 0
		end
		G.BypassDiagAttrLock = true
		pcall(function()
			WS:SetAttribute("ClientObbyAntiTp", false)
		end)
		log("AUTO-TEST: фаза A attr=false")
		local a0 = flagN()
		local okA, errA = sim()
		task.wait(1.5)
		local a1 = flagN() - a0
		G.BypassDiagAttrLock = false
		pcall(function()
			WS:SetAttribute("ClientObbyAntiTp", true)
		end)
		log("AUTO-TEST: фаза B attr=true")
		local b0 = flagN()
		local okB, errB = sim()
		task.wait(1.5)
		local b1 = flagN() - b0
		local verdict
		if a1 == 0 and b1 > 0 then
			verdict = "attr=false ВЫКЛЮЧАЕТ чек → оставляю false"
			G.BypassDiagAttrLock = true
			pcall(function()
				WS:SetAttribute("ClientObbyAntiTp", false)
			end)
		elseif a1 > 0 and b1 > 0 then
			verdict = "чек работает при обоих → атрибут не влияет"
		elseif a1 == 0 and b1 == 0 then
			verdict = "флагов нет вообще"
		else
			verdict = "неожиданно: проверь Debug-атрибут"
		end
		local msg = ("flag: attr=false→%d, attr=true→%d · %s"):format(a1, b1, verdict)
		log("AUTO-TEST: " .. msg)
		findings[#findings + 1] = { cap = "Авто-тест чека", val = msg, status = a1 == 0 }
		findings[#findings + 1] = {
			cap = "Симуляции TP",
			val = (okA and "A ok" or ("A: " .. tostring(errA))) .. " / " .. (okB and "B ok" or ("B: " .. tostring(errB))),
			status = okA and okB,
		}
		G.BypassDiagAT = false
		render()
	end)
end

mkbtn("Авто-тест", 200, 96, btnRow2, function()
	runAutoTest()
end)

local LLr = env.BypassLogic
local rtxt = "Ревайв: ?"
if LLr and LLr.isRevive then
	rtxt = LLr.isRevive() and "Ревайв: ON" or "Ревайв: OFF"
end
local reviveBtn = mkbtn(rtxt, 300, 76, btnRow2, function()
	local LL = env.BypassLogic
	if not LL or not LL.setRevive then
		findings[#findings + 1] = { cap = "Ревайв", val = "нет BypassLogic", status = false }
		render()
		return
	end
	local nv = not LL.isRevive()
	LL.setRevive(nv)
	reviveBtn.Text = nv and "Ревайв: ON" or "Ревайв: OFF"
	findings[#findings + 1] = { cap = "Ревайв", val = tostring(nv), status = nv }
	log("EXPERIMENT: revive=" .. tostring(nv))
	render()
end)

closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

bubble = Instance.new("TextButton")
bubble.Name = "BypassDiag"
bubble.Size = UDim2.fromOffset(52, 32)
bubble.Position = UDim2.new(0, 10, 0, 10)
bubble.BackgroundColor3 = Color3.fromRGB(15, 19, 29)
bubble.BorderSizePixel = 0
bubble.Text = "Diag"
bubble.TextColor3 = Color3.fromRGB(0, 242, 254)
bubble.Font = Enum.Font.GothamBold
bubble.TextSize = 12
bubble.Visible = false
bubble.Parent = gui
Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 6)
bubble.MouseButton1Click:Connect(function()
	frame.Visible = true
	bubble.Visible = false
end)
minBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
	bubble.Visible = true
end)

local UIS = game:GetService("UserInputService")
local dragging = false
local grab = nil
bar.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	dragging = true
	local abs = frame.AbsolutePosition
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(abs.X, abs.Y)
	grab = Vector2.new(input.Position.X, input.Position.Y) - abs
end)
UIS.InputChanged:Connect(function(input)
	if not dragging then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local sz = frame.AbsoluteSize
	local x = math.clamp(input.Position.X - grab.X, 4, math.max(4, vs.X - sz.X - 4))
	local y = math.clamp(input.Position.Y - grab.Y, 4, math.max(4, vs.Y - sz.Y - 4))
	frame.Position = UDim2.fromOffset(x, y)
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

task.spawn(function()
	task.wait(5)
	if not G.BypassDiagATdone and not G.BypassDiagAT then
		log("AUTO-TEST: автозапуск через 5с после старта")
		runAutoTest()
	end
end)

for _, f in ipairs(findings) do
	warn("[BypassDiag] " .. f.cap .. " = " .. f.val)
end
