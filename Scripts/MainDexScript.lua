local env = getgenv and getgenv() or _G
local MainDexScript = {}

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

local SCRIPT_CLASSES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}
local REMOTE_CLASSES = {
	RemoteEvent = true,
	RemoteFunction = true,
	BindableEvent = true,
	BindableFunction = true,
	UnreliableRemoteEvent = true,
}
local SKIP_TOP = {
	CoreGui = true,
	CorePackages = true,
	RobloxReplicatedStorage = true,
	SteamGameClient = true,
	RobloxGui = true,
}
local SCRIPT_EXT = {
	Script = ".server.lua",
	LocalScript = ".client.lua",
	ModuleScript = ".lua",
}
local MAX_TREE_NODES = 40000
local MAX_DEPTH = 16
local MAX_SCRIPT_CHARS = 250000
local YIELD_EVERY = 150

local BASE_CANDIDATES = {
	"/storage/emulated/0/Delta/Scripts/",
	"/sdcard/Delta/Scripts/",
	"Scripts/",
	"./Scripts/",
	"",
}

local function guiRoot()
	return (type(gethui) == "function") and gethui() or game:GetService("CoreGui")
end

local function destroyGui(name)
	pcall(function()
		local old = guiRoot():FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end)
end

local function pal()
	local WB = env.WindowBase
	if WB and type(WB.Palette) == "table" then
		return WB.Palette
	end
	local GC = env.GlobalControler
	if GC and type(GC.ModuleTheme) == "table" then
		return GC.ModuleTheme
	end
	return {
		bg = Color3.fromRGB(15, 19, 29),
		header = Color3.fromRGB(23, 28, 37),
		panel = Color3.fromRGB(23, 28, 37),
		panelAlt = Color3.fromRGB(27, 32, 41),
		line = Color3.fromRGB(58, 73, 75),
		text = Color3.fromRGB(223, 226, 240),
		textDim = Color3.fromRGB(185, 202, 203),
		accent = Color3.fromRGB(0, 242, 254),
		danger = Color3.fromRGB(147, 0, 10),
		dangerText = Color3.fromRGB(255, 180, 171),
		btn = Color3.fromRGB(38, 42, 52),
		accentOn = Color3.fromRGB(0, 55, 58),
	}
end

local function corner(f, r)
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, r)
end

local function strokeBox(f, color, thickness)
	pcall(function()
		local s = Instance.new("UIStroke")
		s.Thickness = thickness or 1
		s.Color = color
		s.Parent = f
	end)
end

local progress = {
	status = nil,
	log = nil,
	fill = nil,
	stage = nil,
	lines = {},
	count = 0,
	last = 0,
}

local function progressRefreshLog()
	if not progress.log then
		return
	end
	pcall(function()
		progress.log.Text = table.concat(progress.lines, "\n")
	end)
end

local function uiBuild(titleText)
	destroyGui("DexRunGui")
	progress.lines = {}
	progress.count = 0
	progress.last = 0
	local P = pal()
	pcall(function()
		local sg = Instance.new("ScreenGui")
		sg.Name = "DexRunGui"
		sg.ResetOnSpawn = false
		sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		sg.Parent = guiRoot()

		local f = Instance.new("Frame")
		f.Size = UDim2.fromOffset(460, 360)
		f.Position = UDim2.new(0.5, -230, 0.5, -180)
		f.BackgroundColor3 = P.bg
		f.BorderSizePixel = 0
		f.Parent = sg
		corner(f, 6)
		strokeBox(f, P.line)

		local header = Instance.new("Frame")
		header.Size = UDim2.new(1, 0, 0, 28)
		header.BackgroundColor3 = P.header
		header.BorderSizePixel = 0
		header.Parent = f
		corner(header, 6)
		local headerFix = Instance.new("Frame")
		headerFix.Size = UDim2.new(1, 0, 0, 8)
		headerFix.Position = UDim2.new(0, 0, 1, -8)
		headerFix.BackgroundColor3 = P.header
		headerFix.BorderSizePixel = 0
		headerFix.Parent = header

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -70, 1, 0)
		title.Position = UDim2.fromOffset(10, 0)
		title.BackgroundTransparency = 1
		title.Text = titleText or "Dex Dumper"
		title.TextColor3 = P.text
		title.Font = Enum.Font.GothamSemibold
		title.TextSize = 12
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = header

		local minBtn = Instance.new("TextButton")
		minBtn.Name = "Min"
		minBtn.Size = UDim2.fromOffset(24, 22)
		minBtn.Position = UDim2.new(1, -56, 0, 3)
		minBtn.BackgroundColor3 = P.btn
		minBtn.BorderSizePixel = 0
		minBtn.AutoButtonColor = true
		minBtn.Text = "—"
		minBtn.TextColor3 = P.textDim
		minBtn.Font = Enum.Font.GothamBold
		minBtn.TextSize = 12
		minBtn.Parent = header
		corner(minBtn, 4)

		local x = Instance.new("TextButton")
		x.Size = UDim2.fromOffset(24, 22)
		x.Position = UDim2.new(1, -28, 0, 3)
		x.BackgroundColor3 = P.btn
		x.BorderSizePixel = 0
		x.AutoButtonColor = true
		x.Text = "✕"
		x.TextColor3 = P.dangerText
		x.Font = Enum.Font.GothamBold
		x.TextSize = 11
		x.Parent = header
		corner(x, 4)
		x.MouseButton1Click:Connect(function()
			destroyGui("DexRunGui")
		end)

		local status = Instance.new("TextLabel")
		status.Name = "Status"
		status.Size = UDim2.new(1, -20, 0, 18)
		status.Position = UDim2.fromOffset(10, 36)
		status.BackgroundTransparency = 1
		status.Text = "..."
		status.TextColor3 = P.accent
		status.Font = Enum.Font.Code
		status.TextSize = 11
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextTruncate = Enum.TextTruncate.AtEnd
		status.Parent = f

		local stage = Instance.new("TextLabel")
		stage.Name = "Stage"
		stage.Size = UDim2.new(1, -20, 0, 14)
		stage.Position = UDim2.fromOffset(10, 54)
		stage.BackgroundTransparency = 1
		stage.Text = ""
		stage.TextColor3 = P.textDim
		stage.Font = Enum.Font.Gotham
		stage.TextSize = 10
		stage.TextXAlignment = Enum.TextXAlignment.Left
		stage.Parent = f

		local logBox = Instance.new("ScrollingFrame")
		logBox.Name = "LogBox"
		logBox.Size = UDim2.new(1, -20, 1, -100)
		logBox.Position = UDim2.fromOffset(10, 74)
		logBox.BackgroundColor3 = P.panel
		logBox.BorderSizePixel = 0
		logBox.ScrollBarThickness = 3
		logBox.ScrollBarImageColor3 = P.line
		logBox.CanvasSize = UDim2.fromOffset(0, 0)
		logBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
		logBox.Parent = f
		corner(logBox, 4)
		strokeBox(logBox, P.line)

		local log = Instance.new("TextLabel")
		log.Name = "Log"
		log.Size = UDim2.new(1, -8, 1, -4)
		log.Position = UDim2.fromOffset(4, 2)
		log.BackgroundTransparency = 1
		log.Text = ""
		log.TextColor3 = P.textDim
		log.Font = Enum.Font.Code
		log.TextSize = 11
		log.TextXAlignment = Enum.TextXAlignment.Left
		log.TextYAlignment = Enum.TextYAlignment.Top
		log.TextWrapped = true
		log.Parent = logBox

		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, -20, 0, 6)
		track.Position = UDim2.new(0, 10, 1, -22)
		track.BackgroundColor3 = P.panelAlt
		track.BorderSizePixel = 0
		track.Parent = f
		corner(track, 99)
		strokeBox(track, P.line)

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = P.accent
		fill.BorderSizePixel = 0
		fill.Parent = track
		corner(fill, 99)

		progress.status = status
		progress.stage = stage
		progress.log = log
		progress.fill = fill

		local minimized = false
		local launch = Instance.new("TextButton")
		launch.Name = "Launch"
		launch.Size = UDim2.fromOffset(32, 32)
		launch.Position = f.Position
		launch.BackgroundColor3 = P.header
		launch.BorderSizePixel = 0
		launch.Text = "DX"
		launch.TextColor3 = P.accent
		launch.Font = Enum.Font.GothamBold
		launch.TextSize = 12
		launch.Visible = false
		launch.Parent = sg
		corner(launch, 6)
		strokeBox(launch, P.accent)

		local function setMinimized(v)
			minimized = v == true
			f.Visible = not minimized
			launch.Visible = minimized
			if minimized then
				launch.Position = f.Position
			end
		end

		minBtn.MouseButton1Click:Connect(function()
			setMinimized(true)
		end)

		launch.MouseButton1Click:Connect(function()
			setMinimized(false)
		end)

		local UIS = game:GetService("UserInputService")
		local dragging = false
		local dragStart = nil
		local startPos = nil

		local function beginDrag(input)
			dragging = true
			dragStart = input.Position
			startPos = f.Position
		end

		header.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				beginDrag(input)
			end
		end)

		launch.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				beginDrag(input)
			end
		end)

		UIS.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - dragStart
				local np = UDim2.new(
					startPos.X.Scale,
					math.clamp(startPos.X.Offset + delta.X, -420, 420),
					startPos.Y.Scale,
					math.clamp(startPos.Y.Offset + delta.Y, -330, 330)
				)
				f.Position = np
				if minimized then
					launch.Position = np
				end
			end
		end)

		UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end)
end

local function progressInit(text)
	uiBuild("Dex Dumper")
	if progress.status then
		pcall(function()
			progress.status.Text = tostring(text or "...")
		end)
	end
end

local function progressSet(text)
	if progress.status then
		pcall(function()
			progress.status.Text = tostring(text)
		end)
	end
end

local function progressLog(line)
	progress.lines[#progress.lines + 1] = tostring(line)
	if #progress.lines > 60 then
		table.remove(progress.lines, 1)
	end
	progressRefreshLog()
end

local function progressStage(text, frac)
	if progress.stage then
		pcall(function()
			progress.stage.Text = tostring(text)
		end)
	end
	if progress.fill and type(frac) == "number" then
		pcall(function()
			progress.fill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
		end)
	end
end

local function yieldTick(force)
	progress.count = progress.count + 1
	local now = os.clock()
	if force or (now - progress.last) >= 0.15 or progress.count % YIELD_EVERY == 0 then
		progress.last = now
		if type(task) == "table" and task.wait then
			task.wait()
		end
	end
end

local function showResult(text)
	local P = pal()
	uiBuild("Dex Dumper — ГОТОВО")
	progressStage("ГОТОВО · 100%", 1)
	if progress.status then
		pcall(function()
			progress.status.Text = "ГОТОВО"
			progress.status.TextColor3 = P.accent
		end)
	end
	if progress.stage then
		pcall(function()
			progress.stage.Text = "Дамп сохранён · можно закрыть ✕"
		end)
	end
	progress.lines = { "ГОТОВО" }
	for line in tostring(text):gmatch("[^\n]+") do
		progress.lines[#progress.lines + 1] = line
	end
	progressRefreshLog()
	pcall(function()
		if progress.fill then
			progress.fill.BackgroundColor3 = P.accent
		end
	end)
end

local function sanitize(s)
	s = tostring(s or "unknown")
	s = s:gsub("[%c\\/:%*%?\"<>|]", "_")
	s = s:gsub("%s+", "_")
	s = s:gsub("_+", "_")
	s = s:gsub("^_", ""):gsub("_$", "")
	if s == "" then
		s = "unknown"
	end
	return s:sub(1, 64)
end

local function scriptFileName(entry)
	local path = entry.path:gsub("[\\/:*?\"<>|]", "_")
	path = path:gsub("%s+", "_")
	path = path:gsub("_+", "_")
	if #path > 160 then
		path = path:sub(#path - 159)
	end
	local ext = SCRIPT_EXT[entry.class] or ".lua"
	return path .. ext
end

local function encodeJSON(v)
	local ok, res = pcall(function()
		return HttpService:JSONEncode(v)
	end)
	if ok and type(res) == "string" and res ~= "" then
		return res
	end
	return nil, (ok and "empty" or tostring(res))
end

local function writeFile(path, content)
	if type(writefile) ~= "function" then
		return false
	end
	local ok = pcall(writefile, path, content)
	return ok == true
end

local function makeDir(path)
	if type(makefolder) ~= "function" then
		return
	end
	pcall(makefolder, path)
end

local function detectBase(report)
	for _, cand in ipairs(BASE_CANDIDATES) do
		yieldTick(true)
		local dir = cand .. "DexScriptSave"
		makeDir(cand)
		makeDir(dir)
		local probe = dir .. "/.probe"
		local wrote = writeFile(probe, "DEXPROBE1")
		local back = nil
		if wrote and type(readfile) == "function" then
			local ok, r = pcall(readfile, probe)
			if ok and type(r) == "string" then
				back = r
			end
		end
		if back == "DEXPROBE1" then
			if type(delfile) == "function" then
				pcall(delfile, probe)
			end
			report[#report + 1] = "base OK: [" .. tostring(cand) .. "]"
			return cand
		end
		report[#report + 1] = "base fail: [" .. tostring(cand) .. "] w=" .. tostring(wrote) .. " r=" .. tostring(back)
	end
	return nil
end

local function fullPath(inst)
	local names = {}
	local cur = inst
	local guard = 0
	while cur and cur ~= game and guard < 48 do
		names[#names + 1] = cur.Name
		cur = cur.Parent
		guard = guard + 1
	end
	local out = {}
	for i = #names, 1, -1 do
		out[#out + 1] = names[i]
	end
	return table.concat(out, ".")
end

local function getPlaceName()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and type(info) == "table" and info.Name then
		return info.Name, info
	end
	return "Unknown", nil
end

local function walkSkip(inst)
	return SKIP_TOP[inst.Name] == true
end

local function collectRemotes(onProgress)
	local list = {}
	local function walk(inst)
		if walkSkip(inst) then
			return
		end
		local cls = inst.ClassName
		if REMOTE_CLASSES[cls] then
			list[#list + 1] = {
				class = cls,
				name = inst.Name,
				path = fullPath(inst),
			}
		end
		yieldTick(false)
		for _, ch in ipairs(inst:GetChildren()) do
			walk(ch)
		end
	end
	walk(game)
	if onProgress then
		onProgress(#list)
	end
	return list
end

local function looksLikeSource(src)
	if type(src) ~= "string" then
		return false
	end
	if #src < 2 then
		return false
	end
	local low = src:lower()
	if low:find("failed to get script bytecode", 1, true) then
		return false
	end
	if low:find("decompilation panicked", 1, true) then
		return false
	end
	if low:find("decompil", 1, true) and #src < 80 then
		return false
	end
	return true
end

local function readSource(inst)
	local ok, src = pcall(function()
		return inst.Source
	end)
	if ok and looksLikeSource(src) then
		if #src > MAX_SCRIPT_CHARS then
			return src:sub(1, MAX_SCRIPT_CHARS) .. "\n-- truncated"
		end
		return src, "Source"
	end

	if type(gethiddenproperty) == "function" then
		local hok, _, hval = pcall(gethiddenproperty, inst, "Source")
		if hok and looksLikeSource(hval) then
			return hval, "hidden"
		end
	end

	if type(getscriptbytecode) == "function" then
		yieldTick(true)
		local bok, bc = pcall(getscriptbytecode, inst)
		if bok and looksLikeSource(bc) then
			return bc, "bytecode"
		end
	end

	if type(decompile) == "function" then
		yieldTick(true)
		local dok, dsrc = pcall(decompile, inst)
		if dok and looksLikeSource(dsrc) then
			if #dsrc > MAX_SCRIPT_CHARS then
				return dsrc:sub(1, MAX_SCRIPT_CHARS) .. "\n-- truncated"
			end
			return dsrc, "decompile"
		end
	end

	return nil, nil
end

local function probeApi()
	local names = {
		"decompile",
		"getscriptbytecode",
		"getscripts",
		"getrunningscripts",
		"gethiddenproperty",
		"getnilinstances",
		"hookmetamethod",
		"getrawmetatable",
		"writefile",
		"readfile",
	}
	local parts = {}
	for _, n in ipairs(names) do
		local t1 = type(_G[n])
		local t2 = type(env[n])
		if t1 ~= "nil" or t2 ~= "nil" then
			parts[#parts + 1] = n .. "=" .. (t1 ~= "nil" and t1 or t2)
		end
	end
	return table.concat(parts, " ")
end

local function collectScripts(dir)
	local list = {}
	local saved = 0
	local function walk(inst)
		if walkSkip(inst) then
			return
		end
		local cls = inst.ClassName
		if SCRIPT_CLASSES[cls] then
			local disabled = false
			if cls ~= "ModuleScript" then
				local ok, d = pcall(function()
					return inst.Disabled
				end)
				if ok then
					disabled = d == true
				end
			end
			local nm = tostring(inst.Name or "?")
			progressSet("scripts: " .. #list .. " | " .. nm)
			local source, via = readSource(inst)
			local entry = {
				class = cls,
				name = inst.Name,
				path = fullPath(inst),
				disabled = disabled,
				hasSource = source ~= nil,
				sourceLen = source and #source or 0,
				via = via,
			}
			if source then
				local file = scriptFileName(entry)
				local okW = pcall(writefile, dir .. "/scripts/" .. file, source)
				if okW then
					saved = saved + 1
					entry.file = file
					if saved <= 3 then
						progressLog("src ok (" .. tostring(via) .. "): " .. nm)
					end
				else
					entry.writeErr = okW ~= true
				end
			elseif not progress._srcLogged then
				progress._srcLogged = true
				progressLog("src FAIL first: " .. tostring(inst.ClassName) .. " " .. nm)
			end
			list[#list + 1] = entry
		end
		yieldTick(false)
		for _, ch in ipairs(inst:GetChildren()) do
			walk(ch)
		end
	end
	walk(game)
	return list, saved
end

local function flatPaths(inst, depth, budget, out, counter)
	if counter.n >= budget or depth > MAX_DEPTH then
		return
	end
	for _, ch in ipairs(inst:GetChildren()) do
		if counter.n >= budget then
			return
		end
		counter.n = counter.n + 1
		out[#out + 1] = ch.ClassName .. "\t" .. fullPath(ch)
		if counter.n % 400 == 0 then
			progressSet("paths: " .. counter.n)
			yieldTick(true)
		end
		flatPaths(ch, depth + 1, budget, out, counter)
	end
end

local function buildTree(inst, depth, budget, counter)
	if counter.n >= budget or depth > MAX_DEPTH then
		return nil
	end
	counter.n = counter.n + 1
	if counter.n % 400 == 0 then
		progressSet("tree: " .. counter.n .. "/" .. budget)
		yieldTick(true)
	end
	local node = {
		n = inst.Name,
		c = inst.ClassName,
	}
	local kids = nil
	for _, ch in ipairs(inst:GetChildren()) do
		if counter.n >= budget then
			break
		end
		local child = buildTree(ch, depth + 1, budget, counter)
		if child then
			kids = kids or {}
			kids[#kids + 1] = child
		end
	end
	if kids then
		node.k = kids
	end
	return node
end

local function serviceOverview()
	local list = {}
	for _, inst in ipairs(game:GetChildren()) do
		yieldTick(true)
		local okN, n = pcall(function()
			return #inst:GetChildren()
		end)
		local okD, d = pcall(function()
			return #inst:GetDescendants()
		end)
		list[#list + 1] = {
			name = inst.Name,
			class = inst.ClassName,
			children = okN and n or 0,
			descendants = okD and d or 0,
		}
	end
	return list
end

local function collectTags()
	local byTag = {}
	local ok, tags = pcall(function()
		return CollectionService:GetAllTags()
	end)
	if not ok or type(tags) ~= "table" then
		return byTag
	end
	for _, tag in ipairs(tags) do
		yieldTick(true)
		local okI, insts = pcall(function()
			return CollectionService:GetTagged(tag)
		end)
		if okI and type(insts) == "table" then
			local paths = {}
			for i = 1, math.min(#insts, 60) do
				paths[#paths + 1] = fullPath(insts[i])
			end
			byTag[tostring(tag)] = {
				count = #insts,
				paths = paths,
			}
		end
	end
	return byTag
end

local function playerSnapshot()
	if not LocalPlayer then
		return {}
	end
	local function kids(inst)
		local names = {}
		if not inst then
			return names
		end
		for _, ch in ipairs(inst:GetChildren()) do
			names[#names + 1] = ch.Name .. "(" .. ch.ClassName .. ")"
		end
		return names
	end
	local ls = LocalPlayer:FindFirstChild("leaderstats")
	local stats = {}
	if ls then
		for _, ch in ipairs(ls:GetChildren()) do
			local v = ""
			pcall(function()
				v = tostring(ch.Value)
			end)
			stats[#stats + 1] = {
				name = ch.Name,
				class = ch.ClassName,
				value = v,
			}
		end
	end
	return {
		userId = LocalPlayer.UserId,
		name = LocalPlayer.Name,
		leaderstats = stats,
		playerGui = kids(LocalPlayer:FindFirstChild("PlayerGui")),
		backpack = kids(LocalPlayer:FindFirstChild("Backpack")),
		char = kids(LocalPlayer.Character),
	}
end

local function writeJSONFile(path, value, fallbackText)
	yieldTick(true)
	local enc, err = encodeJSON(value)
	if enc then
		return writeFile(path, enc), true
	end
	progressLog("json fail: " .. tostring(err))
	if fallbackText then
		return writeFile(path, fallbackText), false
	end
	return writeFile(path, "[]"), false
end

local GUI_PROP_CLASSES = {
	ScreenGui = { "Enabled", "ResetOnSpawn", "ZIndexBehavior", "DisplayOrder", "IgnoreGuiInset", "ClipDescendants" },
	GuiObject = { "Position", "Size", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "Visible", "ZIndex", "LayoutOrder", "Rotation", "Selectable", "ClipsDescendants", "AbsolutePosition", "AbsoluteSize" },
	ImageLabel = { "Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter", "SliceScale", "FlipX", "FlipY" },
	ImageButton = { "Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter", "SliceScale", "AutoButtonColor", "PressedImage", "HoverImage", "DownImage" },
	TextLabel = { "Text", "TextColor3", "TextTransparency", "TextStrokeColor3", "TextStrokeTransparency", "TextSize", "Font", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextScaled", "RichText", "LineHeight", "MaxVisibleGraphemes" },
	TextButton = { "Text", "TextColor3", "TextTransparency", "TextStrokeColor3", "TextStrokeTransparency", "TextSize", "Font", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextScaled", "RichText", "AutoButtonColor", "PressedImage", "HoverImage" },
	TextBox = { "Text", "PlaceholderText", "TextColor3", "PlaceholderColor3", "TextSize", "Font", "ClearTextOnFocus", "MultiLine", "CursorPosition", "TextEditable" },
	Frame = {},
	CanvasGroup = { "GroupTransparency" },
	UICorner = { "CornerRadius" },
	UIStroke = { "Color", "Thickness", "Transparency", "ApplyStrokeMode", "LineJoinMode" },
	UIGradient = { "Color", "Transparency", "Rotation", "Offset", "Enabled" },
	UIScale = { "Scale" },
	UIAspectRatioConstraint = { "AspectRatio", "AspectType", "DominantAxis" },
	UISizeConstraint = { "MinSize", "MaxSize" },
	UIPadding = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" },
	UIListLayout = { "FillDirection", "HorizontalAlignment", "VerticalAlignment", "Padding", "SortOrder", "Wraps" },
	UIGridLayout = { "CellSize", "CellPadding", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "StartCorner" },
	UIPageLayout = { "FillDirection", "Padding", "SortOrder", "GamepadInputMode", "Circular", "WheelInputMode" },
	Folder = {},
}

local function guiPropList(inst)
	local cls = inst.ClassName
	if GUI_PROP_CLASSES[cls] then
		return GUI_PROP_CLASSES[cls]
	end
	for parent, list in pairs(GUI_PROP_CLASSES) do
		if parent ~= "Folder" and parent ~= "Frame" and parent ~= "CanvasGroup" then
			local ok, isA = pcall(function()
				return inst:IsA(parent)
			end)
			if ok and isA then
				return list
			end
		end
	end
	return GUI_PROP_CLASSES.GuiObject
end

local function sanNum(n)
	if type(n) ~= "number" then
		return n
	end
	if n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return n
end

local function serValue(v)
	local t = typeof(v)
	if t == "Color3" then
		return { r = sanNum(v.R), g = sanNum(v.G), b = sanNum(v.B) }
	elseif t == "Vector2" then
		return { x = sanNum(v.X), y = sanNum(v.Y) }
	elseif t == "Vector3" then
		return { x = sanNum(v.X), y = sanNum(v.Y), z = sanNum(v.Z) }
	elseif t == "UDim2" then
		return { x = sanNum(v.X.Scale), y = sanNum(v.Y.Scale), xo = sanNum(v.X.Offset), yo = sanNum(v.Y.Offset) }
	elseif t == "UDim" then
		return { s = sanNum(v.Scale), o = sanNum(v.Offset) }
	elseif t == "Rect" then
		return { minx = sanNum(v.Min.X), miny = sanNum(v.Min.Y), maxx = sanNum(v.Max.X), maxy = sanNum(v.Max.Y) }
	elseif t == "NumberSequence" then
		local pts = {}
		for _, k in ipairs(v.Keypoints) do
			pts[#pts + 1] = { t = sanNum(k.Time), v = sanNum(k.Value), e = sanNum(k.Envelope) }
		end
		return { keypoints = pts }
	elseif t == "ColorSequence" then
		local pts = {}
		for _, k in ipairs(v.Keypoints) do
			pts[#pts + 1] = { t = sanNum(k.Time), r = sanNum(k.Value.R), g = sanNum(k.Value.G), b = sanNum(k.Value.B) }
		end
		return { keypoints = pts }
	elseif t == "EnumItem" then
		return v.EnumType .. "." .. v.Name
	elseif t == "number" then
		return sanNum(v)
	elseif t == "string" or t == "boolean" then
		return v
	elseif t == "table" then
		return v
	end
	return tostring(v)
end

local GUI_MAX_NODES = 20000
local GUI_MAX_DEPTH = 24

local dumpGuiNode

local function buildGuiNode(inst, depth, counter)
	if counter.n >= GUI_MAX_NODES or depth > GUI_MAX_DEPTH then
		return nil
	end
	counter.n = counter.n + 1
	local node = {
		class = inst.ClassName,
		name = tostring(inst.Name or "?"),
	}
	local props = {}
	for _, key in ipairs(guiPropList(inst)) do
		local ok, val = pcall(function()
			return inst[key]
		end)
		if ok and val ~= nil then
			local okSer, ser = pcall(serValue, val)
			if okSer and ser ~= nil then
				props[key] = ser
			end
		end
	end
	local okAttr, attrs = pcall(function()
		return inst:GetAttributes()
	end)
	if okAttr and type(attrs) == "table" then
		local enc = {}
		for k, v in pairs(attrs) do
			local okSer, ser = pcall(serValue, v)
			if okSer and ser ~= nil then
				enc[tostring(k)] = ser
			end
		end
		if next(enc) then
			props.Attributes = enc
		end
	end
	node.props = props
	local children = {}
	local okKids, kids = pcall(function()
		return inst:GetChildren()
	end)
	if okKids and kids then
		for _, ch in ipairs(kids) do
			local childNode = dumpGuiNode(ch, depth + 1, counter)
			if childNode then
				children[#children + 1] = childNode
			end
			if counter.n % 300 == 0 then
				progressSet("gui: " .. counter.n .. " | " .. tostring(ch.Name))
				yieldTick(true)
			end
		end
	end
	if #children > 0 then
		node.children = children
	end
	return node
end

dumpGuiNode = function(inst, depth, counter)
	local ok, node = pcall(buildGuiNode, inst, depth, counter)
	if ok then
		return node
	end
	progressLog("gui err @" .. tostring(inst.Name) .. ": " .. tostring(node))
	return nil
end

local function collectGuiDump()
	local roots = {}
	local counter = { n = 0 }
	local function addRoots(container, label)
		if not container then
			return
		end
		for _, ch in ipairs(container:GetChildren()) do
			if ch:IsA("ScreenGui") or ch:IsA("BillboardGui") or ch:IsA("SurfaceGui") then
				local node = dumpGuiNode(ch, 0, counter)
				if node then
					roots[#roots + 1] = { root = label, node = node }
				end
			end
		end
	end
	local ok1, err1 = pcall(function()
		addRoots(game:GetService("StarterGui"), "StarterGui")
	end)
	if not ok1 then
		progressLog("gui StarterGui err: " .. tostring(err1))
	end
	local ok2, err2 = pcall(function()
		addRoots(LocalPlayer:FindFirstChild("PlayerGui"), "PlayerGui")
	end)
	if not ok2 then
		progressLog("gui PlayerGui err: " .. tostring(err2))
	end
	progressLog("gui roots: " .. #roots .. " nodes: " .. counter.n)
	return roots, counter.n
end

function MainDexScript.run()
	local report = {}
	progressInit("Инициализация...")
	progressStage("1/7 · init", 0.05)
	progressLog("api: " .. probeApi())
	progress._srcLogged = false

	local base = detectBase(report)
	if not base then
		report[#report + 1] = "FAIL: запись не работает"
		showResult(table.concat(report, "\n"))
		return nil
	end
	progressLog(report[#report])

	progressStage("2/7 · place", 0.1)
	progressSet("place info...")
	local placeName, product = getPlaceName()
	yieldTick(true)
	local meta = {
		placeId = game.PlaceId,
		placeName = placeName,
		gameId = game.GameId,
		placeVersion = game.PlaceVersion,
		jobId = game.JobId,
		creatorId = (product and product.Creator and product.Creator.Id) or 0,
		savedAt = os.time(),
		savedAtUtc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}
	local folder = tostring(game.PlaceId) .. "_" .. sanitize(placeName)
	local dir = base .. "DexScriptSave/" .. folder
	makeDir(base .. "DexScriptSave")
	makeDir(dir)
	makeDir(dir .. "/scripts")
	progressLog("dir: " .. dir)

	local t0 = os.clock()

	progressStage("3/7 · remotes", 0.2)
	progressSet("remotes...")
	local remotes = collectRemotes(function(n)
		progressSet("remotes: " .. n)
	end)
	writeJSONFile(dir .. "/remotes.json", remotes)
	progressLog("remotes: " .. #remotes)

	progressStage("4/7 · services", 0.3)
	progressSet("services...")
	local services = serviceOverview()
	writeJSONFile(dir .. "/services.json", services)

	progressStage("5/7 · tree", 0.4)
	progressSet("tree...")
	local counter = { n = 0 }
	local tree = buildTree(game, 0, MAX_TREE_NODES, counter)
	local treeOk = writeJSONFile(dir .. "/tree.json", tree)

	local pathLines = {}
	local pcounter = { n = 0 }
	flatPaths(game, 0, MAX_TREE_NODES, pathLines, pcounter)
	writeFile(dir .. "/tree_paths.txt", table.concat(pathLines, "\n"))
	progressLog("tree: " .. counter.n .. " · paths: " .. #pathLines)

	progressStage("6/7 · scripts", 0.55)
	progressSet("scripts source + write...")
	local scripts, saved = collectScripts(dir)
	local index = scripts
	writeJSONFile(dir .. "/scripts_index.json", index)
	progressLog("scripts: " .. #scripts .. " · saved: " .. saved)

	progressStage("7/7 · tags/gui", 0.8)
	progressSet("tags + player...")
	writeJSONFile(dir .. "/tags.json", collectTags())
	writeJSONFile(dir .. "/player.json", playerSnapshot())

	progressSet("gui dump...")
	local guiRoots, guiNodes = collectGuiDump()
	local guiOk = writeJSONFile(dir .. "/gui.json", guiRoots)
	progressLog("gui: " .. guiNodes .. " nodes · ok=" .. tostring(guiOk))

	local scriptLines = {}
	for _, idx in ipairs(index) do
		scriptLines[#scriptLines + 1] = table.concat({
			idx.class,
			idx.hasSource and "src" or "nosrc",
			tostring(idx.sourceLen),
			idx.file or "-",
			idx.path,
		}, "\t")
	end
	writeFile(dir .. "/scripts_index.tsv", table.concat(scriptLines, "\n"))

	local tookMs = math.floor((os.clock() - t0) * 1000)
	local manifest = {
		version = 1,
		meta = meta,
		dir = dir,
		counts = {
			remotes = #remotes,
			services = #services,
			scripts = #scripts,
			scriptsSaved = saved,
			treeNodes = counter.n,
			pathLines = #pathLines,
			guiNodes = guiNodes,
		},
		limits = {
			maxTreeNodes = MAX_TREE_NODES,
			maxDepth = MAX_DEPTH,
			maxScriptChars = MAX_SCRIPT_CHARS,
		},
		api = {
			writefile = type(writefile) == "function",
			makefolder = type(makefolder) == "function",
			decompile = type(decompile) == "function",
			json = encodeJSON({}) ~= nil,
			treeJson = treeOk,
		},
		tookMs = tookMs,
	}
	writeJSONFile(dir .. "/manifest.json", manifest)

	local summary = {}
	summary[#summary + 1] = "place: " .. tostring(meta.placeId) .. " | " .. placeName
	summary[#summary + 1] = "job: " .. tostring(meta.jobId) .. " | v" .. tostring(meta.placeVersion)
	summary[#summary + 1] = "dir: " .. dir
	summary[#summary + 1] = string.format(
		"counts: remotes=%d services=%d scripts=%d saved=%d tree=%d paths=%d",
		#remotes,
		#services,
		#scripts,
		saved,
		counter.n,
		#pathLines
	)
	summary[#summary + 1] = "took: " .. tookMs .. "ms"
	summary[#summary + 1] = "gui: " .. tostring(guiNodes or 0) .. " nodes · gui.json=" .. tostring(guiOk)
	summary[#summary + 1] = ""
	summary[#summary + 1] = "-- log --"
	for _, line in ipairs(progress.lines) do
		summary[#summary + 1] = line
	end
	summary[#summary + 1] = ""
	summary[#summary + 1] = "-- remotes --"
	for i = 1, math.min(#remotes, 40) do
		summary[#summary + 1] = remotes[i].class .. "\t" .. remotes[i].path
	end
	if #remotes > 40 then
		summary[#summary + 1] = "... +" .. tostring(#remotes - 40) .. " (см. remotes.json)"
	end
	summary[#summary + 1] = ""
	summary[#summary + 1] = "-- scripts (без source) --"
	local nosrc = 0
	for _, idx in ipairs(index) do
		if not idx.hasSource then
			nosrc = nosrc + 1
			if nosrc <= 20 then
				summary[#summary + 1] = idx.class .. "\t" .. idx.path
			end
		end
	end
	if nosrc > 20 then
		summary[#summary + 1] = "... +" .. tostring(nosrc - 20)
	end
	summary[#summary + 1] = ""
	summary[#summary + 1] = "-- services --"
	for _, s in ipairs(services) do
		summary[#summary + 1] = string.format(
			"%s(%s) ch=%d desc=%d",
			s.name,
			s.class,
			s.children,
			s.descendants
		)
	end
	writeFile(dir .. "/summary.txt", table.concat(summary, "\n"))

	local verify = "no"
	if type(isfile) == "function" then
		local okv, iv = pcall(isfile, dir .. "/manifest.json")
		verify = tostring(okv and iv)
	end

	local msg = string.format(
		"[Dex] %s | remotes %d · scripts %d/%d · tree %d · %dms",
		folder,
		#remotes,
		saved,
		#scripts,
		counter.n,
		tookMs
	)
	print(msg)
	report[#report + 1] = msg
	report[#report + 1] = "dir: " .. dir
	report[#report + 1] = "manifest isfile=" .. verify
	report[#report + 1] = "json=" .. tostring(manifest.api.json) .. " treeJson=" .. tostring(treeOk)
	showResult(table.concat(report, "\n"))
	if env.GlobalControler and env.GlobalControler.Log then
		pcall(function()
			env.GlobalControler:Log(msg)
		end)
	end
	return manifest
end

env.MainDexScript = MainDexScript

local function doRun()
	local ok, err = pcall(MainDexScript.run)
	if not ok then
		showResult("ERROR run:\n" .. tostring(err))
	end
end

if type(task) == "table" and type(task.spawn) == "function" then
	task.spawn(doRun)
else
	doRun()
end

return MainDexScript
