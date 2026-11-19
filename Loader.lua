
-- EVVO.JAILBREAK // REMOTE LOADER
-- OWNED BY EVVO
-- Version 4.0

local BASE_URL =
    "https://raw.githubusercontent.com/evan123456789010/EVVO-JAILBREAK/main/"

local function notify(message)
    print("[EVVO.JAILBREAK] " .. tostring(message))
end

local function loadRemote(path)
    assert(type(game.HttpGet) == "function",
        "HttpGet is unavailable")

    assert(type(loadstring) == "function",
        "loadstring is unavailable")

    local url = BASE_URL .. path

    local success, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        error("Download failed: " .. tostring(source))
    end

    if type(source) ~= "string" or #source == 0 then
        error("Remote script is empty")
    end

    local compiled, compileError = loadstring(source)

    if not compiled then
        error("Compilation failed: " .. tostring(compileError))
    end

    return compiled()
end

notify("Initializing Ultimate V4...")

local success, err = pcall(function()
    loadRemote("main.lua")
end)

if success then
    notify("Loader completed")
else
    warn("[EVVO.JAILBREAK] " .. tostring(err))
end

