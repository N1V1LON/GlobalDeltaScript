local env = getgenv and getgenv() or _G
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local lines = {}
local function log(s)
	lines[#lines + 1] = tostring(s)
	print("[DexDiag] " .. tostring(s))
end

log("rf=" .. type(readfile) .. " wf=" .. type(writefile) .. " mf=" .. type(makefolder))
log("isfile=" .. type(isfile) .. " listfiles=" .. type(listfiles) .. " decompile=" .. type(decompile))

local paths = {
	"/storage/emulated/0/Delta/Scripts/MainDexScript.lua",
	"/sdcard/Delta/Scripts/MainDexScript.lua",
	"Scripts/MainDexScript.lua",
	"./Scripts/MainDexScript.lua",
	"MainDexScript.lua",
}
local found = nil
for _, p in ipairs(paths) do
	local okI, rI = pcall(isfile, p)
	local okR, rR = pcall(readfile, p)
	local len = (type(rR) == "string") and #rR or tostring(rR)
	log("p=" .. p .. " isfile=" .. tostring(okI and rI) .. " read=" .. tostring(okR) .. " len=" .. len)
	if type(rR) == "string" and #rR > 100 then
		found = { path = p, src = rR }
	end
end

local dirs = {
	"/storage/emulated/0/Delta/Scripts",
	"/sdcard/Delta/Scripts",
	"Scripts",
	".",
}
for _, d in ipairs(dirs) do
	local ok, res = pcall(listfiles, d)
	if ok and type(res) == "table" then
		local names = {}
		for i = 1, math.min(#res, 12) do
			names[#names + 1] = tostring(res[i])
		end
		log("list " .. d .. " n=" .. #res .. " :: " .. table.concat(names, ", "))
	end
end

local dumpDirs = {
	"/storage/emulated/0/Delta/Scripts/DexScriptSave",
	"Scripts/DexScriptSave",
	"DexScriptSave",
}
for _, d in ipairs(dumpDirs) do
	local ok, res = pcall(listfiles, d)
	if ok and type(res) == "table" and #res > 0 then
		log("DUMP " .. d .. " n=" .. #res .. " :: " .. table.concat({ unpack(res, 1, math.min(#res, 6)) }, ", "))
	end
end

if found then
	local chunk, err = loadstring(found.src, "=MainDexScript")
	if not chunk then
		log("LOAD ERR: " .. tostring(err))
	else
		local ok, runRes = pcall(chunk)
		log("EXEC ok=" .. tostring(ok) .. " res=" .. tostring(runRes))
	end
else
	log("MainDexScript.lua НЕ найден через readfile")
end

local msg = table.concat(lines, "\n")
local title = "[DexDiag] " .. (#lines) .. " строк"

pcall(function()
	local parent = (type(gethui) == "function") and gethui() or game:GetService("CoreGui")
	local sg = Instance.new("ScreenGui")
	sg.Name = "DexDiagGui"
	sg.ResetOnSpawn = false
	local old = parent:FindFirstChild("DexDiagGui")
	if old then
		old:Destroy()
	end
	sg.Parent = parent

	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(430, 360)
	f.Position = UDim2.new(0.5, -215, 0.5, -180)
	f.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	f.BorderSizePixel = 0
	f.Parent = sg

	local sc = Instance.new("TextLabel")
	sc.Size = UDim2.new(1, -12, 1, -12)
	sc.Position = UDim2.fromOffset(6, 6)
	sc.BackgroundTransparency = 1
	sc.Text = msg
	sc.TextColor3 = Color3.fromRGB(210, 220, 230)
	sc.Font = Enum.Font.Code
	sc.TextSize = 11
	sc.TextXAlignment = Enum.TextXAlignment.Left
	sc.TextYAlignment = Enum.TextYAlignment.Top
	sc.TextWrapped = false
	sc.Parent = f

	local x = Instance.new("TextButton")
	x.Size = UDim2.fromOffset(28, 24)
	x.Position = UDim2.new(1, -30, 0, 4)
	x.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	x.Text = "X"
	x.TextColor3 = Color3.new(1, 1, 1)
	x.Font = Enum.Font.GothamBold
	x.TextSize = 12
	x.Parent = f
	x.MouseButton1Click:Connect(function()
		sg:Destroy()
	end)
end)

error("[DexDiag]\n" .. msg)
