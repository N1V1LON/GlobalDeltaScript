local env = getgenv and getgenv() or _G
if env.BypassWindow then return env.BypassWindow end

local BypassWindow = {}
BypassWindow.GetTable = "Server"
BypassWindow.GetPosition = 3
BypassWindow.Scope = "place"
BypassWindow.Places = { 107778070777162 }
BypassWindow.QuickToggle = true

local function Str(key, fallback)
	local GC = env.GlobalControler
	if GC and GC.Str then
		return GC:Str(key)
	end
	return fallback
end

function BypassWindow.Name()
	return Str("bypassName", "Bypass")
end

function BypassWindow.Desc()
	return Str("bypassDesc", "Обход guard'ов игры")
end

function BypassWindow.IsOn()
	local L = env.BypassLogic
	return L ~= nil and L.isEnabled() == true
end

function BypassWindow.SetOn(state)
	local L = env.BypassLogic
	assert(L, "BypassLogic не загружен")
	if state then
		L.enable()
	else
		L.disable()
	end
	local GC = env.GlobalControler
	if GC and GC.SaveModuleState then
		GC:SaveModuleState("BypassWindow", {
			enabled = state == true,
			safeZone = L.isSafeZone(),
			antiTP = L.isAntiTP(),
		})
	end
	return BypassWindow.IsOn()
end

function BypassWindow.Restore(config)
	config = config or {}
	local L = env.BypassLogic
	if not L then
		return
	end
	if config.safeZone ~= nil or config.antiTP ~= nil then
		if config.safeZone then
			L.setSafeZone(true)
		end
		if config.antiTP then
			L.setAntiTP(true)
		end
	elseif config.enabled then
		L.enable()
	end
end

local window = nil

local function currentPalette()
	local GC = env.GlobalControler
	if GC and type(GC.ModuleTheme) == "table" then
		return GC.ModuleTheme
	end
	local WindowBase = env.WindowBase
	return WindowBase and WindowBase.Palette or nil
end

local function corner(frame, r)
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, r or 4)
end

local function stroke(frame, color)
	pcall(function()
		local s = Instance.new("UIStroke")
		s.Thickness = 1
		s.Color = color
		s.Parent = frame
	end)
end

local function makeToggle(parent, on, onToggle)
	local P = currentPalette() or {}
	local h = 28
	local w = 56

	local btn = Instance.new("TextButton")
	btn.Name = "Toggle"
	btn.Size = UDim2.fromOffset(w, h)
	btn.BackgroundColor3 = on and (P.accent or Color3.fromRGB(0, 242, 254)) or (P.btn or Color3.fromRGB(38, 42, 52))
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Text = ""
	btn.Parent = parent
	corner(btn, 99)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.fromOffset(8, 0)
	label.BackgroundTransparency = 1
	label.Text = on and "ON" or "OFF"
	label.TextColor3 = on and (P.accentOn or Color3.fromRGB(0, 55, 58)) or (P.textDim or Color3.fromRGB(185, 202, 203))
	label.Font = Enum.Font.Code
	label.TextSize = 11
	label.ZIndex = 2
	label.Parent = btn

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(h - 8, h - 8)
	knob.Position = on and UDim2.new(1, -(h - 4), 0, 4) or UDim2.fromOffset(4, 4)
	knob.BackgroundColor3 = on and (P.accentOn or Color3.fromRGB(0, 55, 58)) or (P.textDim or Color3.fromRGB(185, 202, 203))
	knob.BorderSizePixel = 0
	knob.ZIndex = 3
	knob.Parent = btn
	corner(knob, 99)

	local state = on
	local function paint()
		btn.BackgroundColor3 = state and (P.accent or Color3.fromRGB(0, 242, 254)) or (P.btn or Color3.fromRGB(38, 42, 52))
		label.Text = state and "ON" or "OFF"
		label.TextColor3 = state and (P.accentOn or Color3.fromRGB(0, 55, 58)) or (P.textDim or Color3.fromRGB(185, 202, 203))
		knob.Position = state and UDim2.new(1, -(h - 4), 0, 4) or UDim2.fromOffset(4, 4)
	end

	btn.MouseButton1Click:Connect(function()
		state = not state
		paint()
		if onToggle then
			onToggle(state)
		end
	end)

	return {
		get = function() return state end,
		set = function(v)
			state = v
			paint()
		end,
	}
end

local function optRow(parent, y, titleText, statusText, getter, setter, P)
	local row = Instance.new("Frame")
	row.Name = "OptRow"
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Position = UDim2.fromOffset(0, y)
	row.BackgroundColor3 = P.panelAlt or Color3.fromRGB(27, 32, 41)
	row.BorderSizePixel = 0
	row.Parent = parent
	corner(row, 4)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -70, 0, 14)
	lbl.Position = UDim2.fromOffset(10, 6)
	lbl.BackgroundTransparency = 1
	lbl.Text = titleText
	lbl.TextColor3 = P.text or Color3.fromRGB(223, 226, 240)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local st = Instance.new("TextLabel")
	st.Name = "Status"
	st.Size = UDim2.new(1, -70, 0, 12)
	st.Position = UDim2.fromOffset(10, 22)
	st.BackgroundTransparency = 1
	st.Text = statusText or ""
	st.TextColor3 = P.textDim or Color3.fromRGB(185, 202, 203)
	st.Font = Enum.Font.Gotham
	st.TextSize = 9
	st.TextXAlignment = Enum.TextXAlignment.Left
	st.Parent = row

	local t = makeToggle(row, getter(), function(on)
		setter(on)
	end)
	local tBtn = row:FindFirstChild("Toggle")
	if tBtn then
		tBtn.Position = UDim2.new(1, -66, 0.5, -14)
	end
	return { toggle = t, status = st }
end

function BypassWindow.Open(config)
	config = config or {}
	if window then
		if window._destroyed then
			window = nil
		else
			window:Destroy()
			window = nil
			return
		end
	end

	local WindowBase = env.WindowBase
	local L = env.BypassLogic
	assert(WindowBase, "WindowBase не загружен")
	assert(L, "BypassLogic не загружен")

	local P = currentPalette() or WindowBase.Palette
	local base = WindowBase.new("Bypass", BypassWindow.Name(), 300, 160)
	window = base
	local content = base.Content
	local PAD = 6

	local stateLabel
	local toggle
	local bigState
	local rowSafe
	local rowAnti

	local function saveState()
		local GC = env.GlobalControler
		if GC and GC.SaveModuleState then
			GC:SaveModuleState("BypassWindow", {
				enabled = L.isEnabled(),
				safeZone = L.isSafeZone(),
				antiTP = L.isAntiTP(),
			})
		end
	end

	local function refreshStatus()
		if bigState then
			local on = L.isEnabled()
			bigState.Text = on and "ON" or "OFF"
			bigState.TextColor3 = on and (P.accent or Color3.fromRGB(0, 242, 254)) or P.textDim
		end
		if stateLabel then
			if L.isEnabled() then
				stateLabel.Text = "ON  ·  guard bypass активен"
				stateLabel.TextColor3 = P.accent or Color3.fromRGB(0, 242, 254)
			else
				stateLabel.Text = "OFF  ·  стоковый режим"
				stateLabel.TextColor3 = P.textDim
			end
		end
		if rowSafe then
			rowSafe.toggle.set(L.isSafeZone())
			local gs = L.getGuardStatus()
			if gs == "patched" then
				rowSafe.status.Text = Str("bypassPatched", "патч установлен")
				rowSafe.status.TextColor3 = P.accent or Color3.fromRGB(0, 242, 254)
			elseif gs == "waiting" then
				rowSafe.status.Text = Str("bypassWaiting", "поиск guard-модуля...")
				rowSafe.status.TextColor3 = Color3.fromRGB(250, 204, 21)
			else
				rowSafe.status.Text = Str("bypassOff", "выключен")
				rowSafe.status.TextColor3 = P.textDim
			end
		end
		if rowAnti then
			rowAnti.toggle.set(L.isAntiTP())
			if L.isAntiTP() then
				if L.getAttrStatus() then
					rowAnti.status.Text = Str("bypassAttrs", "атрибуты выставлены")
					rowAnti.status.TextColor3 = P.accent or Color3.fromRGB(0, 242, 254)
				else
					rowAnti.status.Text = Str("bypassAttrsLost", "атрибуты сброшены, удержание...")
					rowAnti.status.TextColor3 = Color3.fromRGB(250, 204, 21)
				end
			else
				rowAnti.status.Text = Str("bypassOff", "выключен")
				rowAnti.status.TextColor3 = P.textDim
			end
		end
	end

	local function saveRefresh()
		saveState()
		refreshStatus()
	end

	local card = Instance.new("Frame")
	card.Name = "StateCard"
	card.Size = UDim2.new(1, 0, 0, 64)
	card.Position = UDim2.fromOffset(0, PAD)
	card.BackgroundColor3 = P.panel or Color3.fromRGB(23, 28, 37)
	card.BorderSizePixel = 0
	card.Parent = content
	corner(card, 4)
	stroke(card, P.line or Color3.fromRGB(58, 73, 75))

	local cardLbl = Instance.new("TextLabel")
	cardLbl.Size = UDim2.new(1, -80, 0, 12)
	cardLbl.Position = UDim2.fromOffset(10, 10)
	cardLbl.BackgroundTransparency = 1
	cardLbl.Text = BypassWindow.Desc()
	cardLbl.TextColor3 = P.textDim or Color3.fromRGB(185, 202, 203)
	cardLbl.Font = Enum.Font.Gotham
	cardLbl.TextSize = 11
	cardLbl.TextXAlignment = Enum.TextXAlignment.Left
	cardLbl.Parent = card

	bigState = Instance.new("TextLabel")
	bigState.Name = "Big"
	bigState.Size = UDim2.new(1, -80, 0, 28)
	bigState.Position = UDim2.fromOffset(10, 26)
	bigState.BackgroundTransparency = 1
	bigState.Text = "OFF"
	bigState.TextColor3 = P.textDim
	bigState.Font = Enum.Font.Code
	bigState.TextSize = 24
	bigState.TextXAlignment = Enum.TextXAlignment.Left
	bigState.Parent = card

	toggle = makeToggle(card, L.isEnabled(), function(state)
		if state then
			L.enable()
		else
			L.disable()
		end
		saveRefresh()
	end)
	local tBtn = card:FindFirstChild("Toggle")
	if tBtn then
		tBtn.Size = UDim2.fromOffset(56, 28)
		tBtn.Position = UDim2.new(1, -66, 0.5, -14)
	end

	local y = PAD + 64 + 8
	rowSafe = optRow(content, y,
		Str("bypassSafe", "Безопасная зона (safe zone)"),
		Str("bypassOff", "выключен"),
		L.isSafeZone,
		function(v)
			L.setSafeZone(v)
			saveRefresh()
		end,
		P)
	y = y + 44
	rowAnti = optRow(content, y,
		Str("bypassAntiTP", "Анти-ТП обби (ObbyAntiTP)"),
		Str("bypassOff", "выключен"),
		L.isAntiTP,
		function(v)
			L.setAntiTP(v)
			saveRefresh()
		end,
		P)
	y = y + 44

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Position = UDim2.fromOffset(0, y + 4)
	hint.Size = UDim2.new(1, 0, 0, 26)
	hint.BackgroundTransparency = 1
	hint.Text = Str("bypassHint", "Safe zone — предметы в безопасной зоне.\nАнти-ТП — снять kill при телепорте в обби.")
	hint.TextColor3 = P.textDim
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 10
	hint.TextWrapped = true
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = content
	y = y + 4 + 26 + 6

	stateLabel = Instance.new("TextLabel")
	stateLabel.Name = "State"
	stateLabel.Position = UDim2.fromOffset(0, y)
	stateLabel.Size = UDim2.new(1, 0, 0, 14)
	stateLabel.BackgroundTransparency = 1
	stateLabel.Text = "OFF"
	stateLabel.TextColor3 = P.textDim
	stateLabel.Font = Enum.Font.Code
	stateLabel.TextSize = 10
	stateLabel.TextXAlignment = Enum.TextXAlignment.Left
	stateLabel.Parent = content
	y = y + 14 + PAD

	base:setSize(300, 28 + y)
	refreshStatus()
	task.spawn(function()
		while window == base and not base._destroyed do
			refreshStatus()
			task.wait(0.5)
		end
	end)

	base.OnClosed = function()
		window = nil
	end
end

env.BypassWindow = BypassWindow
return BypassWindow
