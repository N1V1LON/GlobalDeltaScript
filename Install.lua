-- GlobalDeltaScript / GlobalControler — установка одной строкой (Delta, Roblox)
-- Не хранит личные данные в GitHub: Config/Profiles пишутся только writefile на устройство.

local SOURCES = {
	"https://raw.githubusercontent.com/N1V1LON/GlobalDeltaScript/main/Scripts/GlobalControler.lua",
	"https://cdn.jsdelivr.net/gh/N1V1LON/GlobalDeltaScript@main/Scripts/GlobalControler.lua",
}

local function withCacheBust(url)
	local t = tostring(math.floor(os.time()))
	return url .. (url:find("?", 1, true) and "&" or "?") .. "t=" .. t
end

local function httpGet(url)
	if type(game) == "table" and type(game.HttpGet) == "function" then
		local ok, res = pcall(game.HttpGet, game, url)
		if ok and type(res) == "string" and res ~= "" then
			return res
		end
	end
	if type(request) == "function" then
		local ok, res = pcall(request, { Url = url, Method = "GET" })
		if ok and type(res) == "table" and type(res.Body) == "string" and res.Body ~= "" then
			return res.Body
		end
	end
	return nil
end

local src
for _, base in ipairs(SOURCES) do
	src = httpGet(withCacheBust(base)) or httpGet(base)
	if src then
		break
	end
end
if not src then
	error("[Install] не удалось скачать GlobalControler.lua")
end

local chunk, err = loadstring(src, "=GlobalControler")
if not chunk then
	error("[Install] loadstring: " .. tostring(err))
end

local ok, res = pcall(chunk)
if not ok then
	error("[Install] init: " .. tostring(res))
end

return res
