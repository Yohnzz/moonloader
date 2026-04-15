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

function main()
    -- Pesan di Console/CMD
    print("[Keylogger Detector On]")
    print("Author: Yohnzz x ChatGPT")
    
    wait(2000) -- tunggu game load

    local path = getWorkingDirectory() .. "\\moonloader\\"
    
    -- Pesan di Chat SAMP
    sampAddChatMessage("{FFFF00}[Detector] {FFFFFF}Scanning file .lua...", -1)
    
    sampAddChatMessage("[Detector] Scanning file .lua...", -1)

    for file in io.popen('dir "'..path..'" /b'):lines() do
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
                    sampAddChatMessage("⚠️ MENCURIGAKAN: " .. file, -1)
                    sampAddChatMessage("Keyword: " .. table.concat(found, ", "), -1)
                end
            end
        end
    end

    sampAddChatMessage("[Detector] Scan selesai!", -1)
end