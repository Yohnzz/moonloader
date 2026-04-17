script_name("Keylogger Detector")
script_author("Yohnzz x ChatGPT")

local suspiciousKeywords = {
    "http.request",
    "socket.http",
    "https://",
    "webhook",
    "sampSendChat",
    "onSendCommand",
    "login",
    "password",
    "nick"
}

local function safeChat(msg, color)
    if isSampAvailable and isSampAvailable() and sampAddChatMessage then
        pcall(sampAddChatMessage, msg, color or -1)
    else
        print((msg or ""):gsub("{......}", ""))
    end
end

function main()
    -- Pesan di Console/CMD
    print("[Keylogger Detector On]")
    print("Author: Yohnzz x ChatGPT")

    while not (isSampAvailable and isSampAvailable()) do
        wait(250) -- tunggu game + SAMP siap
    end

    local path = getWorkingDirectory() .. "\\moonloader\\"

    safeChat("{FFFF00}[Detector] {FFFFFF}Scanning file .lua...", -1)

    local pipe = io.popen('dir "'..path..'" /b 2>NUL')
    if not pipe then
        safeChat("{FF6666}[Detector] Gagal scan folder moonloader.", -1)
        return
    end

    for file in pipe:lines() do
        if file:match("%.lua$") then
            local f = io.open(path .. file, "r")
            if f then
                local content = f:read("*all")
                f:close()

                local found = {}
                for _, keyword in ipairs(suspiciousKeywords) do
                    if content:lower():find(keyword) then
                        table.insert(found, keyword)
                    end
                end

                if #found >= 3 then
                    safeChat("{FFAA00}[Detector] MENCURIGAKAN: " .. file, -1)
                    safeChat("{FFFFAA}[Detector] Keyword: " .. table.concat(found, ", "), -1)
                end
            end
        end
    end
    pipe:close()

    safeChat("{88FF88}[Detector] Scan selesai!", -1)
end
