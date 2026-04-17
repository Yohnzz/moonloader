-- ╔══════════════════════════════════════════════════════════╗
-- ║        MOONLOADER SCRIPT MANAGER v1.1 FIXED             ║
-- ║        Reload + Live Error Monitor                      ║
-- ║        By: AutoRP Tools  |  MoonLoader Compatible       ║
-- ╚══════════════════════════════════════════════════════════╝
-- Ketik /smgr untuk membuka panel manager

local ffi    = require 'ffi'
local mimgui = require 'lib.mimgui'
-- FIX: HAPUS "local os = require 'os'" — os adalah global Lua, jangan di-override

-- ═══════════════════════════════════════════════════════════
--  KONSTANTA
-- ═══════════════════════════════════════════════════════════
local SCRIPT_DIR      = getWorkingDirectory() .. "\\moonloader\\"
local LOG_FILE        = getWorkingDirectory() .. "\\moonloader\\moonloader.log"
local MAX_LOG_LINES   = 200
local REFRESH_INTERVAL = 2.0

-- ═══════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════
local showWindow     = mimgui.new.bool(false)
local activeTab      = 1
local scriptList     = {}
local logLines       = {}
local errorLines     = {}
local lastRefresh    = 0
local totalScripts   = 0
local runningScripts = 0
local errorCount     = 0
local searchBuf      = mimgui.new.char[128]("")
local autoRefresh    = mimgui.new.bool(true)
local scrollToBottom = false
local reloadFlash    = {}

local filterError = mimgui.new.bool(true)
local filterWarn  = mimgui.new.bool(true)
local filterInfo  = mimgui.new.bool(false)
local commandsRegistered = false

-- ═══════════════════════════════════════════════════════════
--  UTILITAS FILE
-- ═══════════════════════════════════════════════════════════
local function fileExists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

local function safeChat(message, color)
    if isSampAvailable and isSampAvailable() and sampAddChatMessage then
        pcall(sampAddChatMessage, message, color or -1)
    else
        print(message:gsub("{......}", ""))
    end
end

-- ═══════════════════════════════════════════════════════════
--  SCAN SCRIPT
-- ═══════════════════════════════════════════════════════════
local function scanScripts()
    scriptList     = {}
    totalScripts   = 0
    runningScripts = 0

    local pipe = io.popen('dir /b "' .. SCRIPT_DIR .. '*.lua" 2>NUL')
    if not pipe then return end

    -- FIX: getRunningScripts() tidak ada — gunakan getMoonloaderScriptList() dengan guard
    local runningMap = {}
    local ok, scriptListAPI = pcall(function()
        return getMoonloaderScriptList and getMoonloaderScriptList() or {}
    end)
    if ok and scriptListAPI then
        for _, s in ipairs(scriptListAPI) do
            local n = s.name or s.filename or ""
            n = n:gsub("%.lua$", "")
            runningMap[n] = true
        end
    end

    for line in pipe:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and line ~= "script_manager.lua" then
            local name   = line:gsub("%.lua$", "")
            local loaded = runningMap[name] or false

            table.insert(scriptList, {
                file     = line,
                name     = name,
                loaded   = loaded,
                status   = loaded and "RUNNING" or "LOADED",
                hasError = false,
            })

            totalScripts = totalScripts + 1
            if loaded then runningScripts = runningScripts + 1 end
        end
    end
    pipe:close()

    -- Tandai script yang punya error
    for _, entry in ipairs(errorLines) do
        for _, s in ipairs(scriptList) do
            if string.find(entry.text, s.name, 1, true) then
                s.hasError = true
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════
--  BACA LOG
-- ═══════════════════════════════════════════════════════════
local function parseLogLevel(line)
    local lo = line:lower()
    if lo:find("%[error%]") or lo:find("error") then return "ERROR"
    elseif lo:find("%[warn%]") or lo:find("warning") then return "WARN"
    else return "INFO" end
end

local function readLog()
    logLines   = {}
    errorLines = {}
    errorCount = 0

    if not fileExists(LOG_FILE) then
        table.insert(logLines, { text = "File log tidak ditemukan: " .. LOG_FILE, level = "WARN" })
        return
    end

    local file = io.open(LOG_FILE, "r")
    if not file then return end

    local allLines = {}
    for line in file:lines() do
        table.insert(allLines, line)
    end
    file:close()

    local startIdx = math.max(1, #allLines - MAX_LOG_LINES + 1)
    for i = startIdx, #allLines do
        local line  = allLines[i]
        local level = parseLogLevel(line)
        table.insert(logLines, { text = line, level = level })
        if level == "ERROR" then
            table.insert(errorLines, { text = line, level = "ERROR" })
            errorCount = errorCount + 1
        end
    end

    scrollToBottom = true
end

-- ═══════════════════════════════════════════════════════════
--  RELOAD SATU SCRIPT
-- ═══════════════════════════════════════════════════════════
local function reloadScript(scriptEntry)
    local path = SCRIPT_DIR .. scriptEntry.file
    if not fileExists(path) then return end

    -- Cari skrip yang sedang berjalan berdasarkan nama filenya
    local targetScript = script.find(scriptEntry.file)
    
    if targetScript then
        targetScript:unload() -- Matikan skrip yang lama
        wait(100) -- Beri jeda sebentar agar proses unload selesai
    end

    -- Jalankan kembali
    local ok = loadLuaScript(scriptEntry.file)

    if not ok then
        safeChat("{FF4444}[ScriptMgr] Gagal memuat: " .. scriptEntry.name, -1)
    else
        reloadFlash[scriptEntry.name] = 1.5
        safeChat("{00FF88}[ScriptMgr] Berhasil Restart: " .. scriptEntry.name, -1)
    end

    scanScripts()
end

-- ═══════════════════════════════════════════════════════════
--  RELOAD SEMUA SCRIPT
-- ═══════════════════════════════════════════════════════════
local function reloadAllScripts()
    safeChat("{FFFF00}[ScriptMgr] Merestart semua skrip...", -1)
    
    for _, entry in ipairs(scriptList) do
        -- Jangan matikan Script Manager ini sendiri agar panel tidak hilang
        if entry.file ~= "script_manager.lua" and entry.file ~= thisScript().filename then
            local target = script.find(entry.file)
            if target then target:unload() end
            
            wait(50) -- Jeda antar reload agar tidak lag/crash
            loadLuaScript(entry.file)
            reloadFlash[entry.name] = 2.0
        end
    end
    
    wait(500)
    scanScripts()
    readLog()
    safeChat("{00FF00}[ScriptMgr] Semua skrip telah direstart!", -1)
end

-- ═══════════════════════════════════════════════════════════
--  HAPUS LOG
-- ═══════════════════════════════════════════════════════════
local function clearLog()
    local file = io.open(LOG_FILE, "w")
    if file then
        file:write("-- Log dibersihkan oleh ScriptManager: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        file:close()
    end
    readLog()
end

-- ═══════════════════════════════════════════════════════════
--  WARNA PALETTE
-- ═══════════════════════════════════════════════════════════
local function C(r,g,b,a) return mimgui.ImVec4(r,g,b,a or 1.0) end

local COL = {
    bg          = C(0.07, 0.08, 0.10),
    bgPanel     = C(0.10, 0.11, 0.14),
    border      = C(0.20, 0.22, 0.28),
    titleBg     = C(0.05, 0.06, 0.08),
    green       = C(0.20, 0.85, 0.45),
    red         = C(0.95, 0.28, 0.28),
    yellow      = C(0.95, 0.80, 0.20),
    blue        = C(0.30, 0.65, 1.00),
    gray        = C(0.45, 0.48, 0.55),
    white       = C(0.92, 0.93, 0.95),
    btnReload   = C(0.12, 0.55, 0.30),
    btnReloadH  = C(0.16, 0.70, 0.38),
    btnReloadA  = C(0.09, 0.42, 0.22),
    btnAll      = C(0.15, 0.42, 0.72),
    btnAllH     = C(0.20, 0.55, 0.90),
    btnAllA     = C(0.10, 0.30, 0.55),
    btnDanger   = C(0.60, 0.12, 0.12),
    btnDangerH  = C(0.80, 0.16, 0.16),
    btnDangerA  = C(0.45, 0.08, 0.08),
    btnGray     = C(0.17, 0.18, 0.22),
    btnGrayH    = C(0.24, 0.25, 0.30),
    btnGrayA    = C(0.12, 0.13, 0.16),
}

local function pushBtn(bg, hov, act, txt)
    mimgui.PushStyleColor(mimgui.Col.Button,        bg)
    mimgui.PushStyleColor(mimgui.Col.ButtonHovered, hov)
    mimgui.PushStyleColor(mimgui.Col.ButtonActive,  act)
    mimgui.PushStyleColor(mimgui.Col.Text,          txt or COL.white)
end
local function popBtn() mimgui.PopStyleColor(4) end

local function pushText(col) mimgui.PushStyleColor(mimgui.Col.Text, col) end
local function popText()     mimgui.PopStyleColor() end

local function tabButton(label, idx, w)
    local isActive = (activeTab == idx)
    if isActive then
        pushBtn(COL.blue, COL.blue, COL.blue, COL.bg)
    else
        pushBtn(COL.btnGray, COL.btnGrayH, COL.btnGrayA, COL.gray)
    end
    if mimgui.Button(label, mimgui.ImVec2(w or 100, 28)) then
        activeTab = idx
    end
    popBtn()
end

-- ═══════════════════════════════════════════════════════════
--  RENDER
-- ═══════════════════════════════════════════════════════════
mimgui.OnFrame(function() return showWindow[0] end, function()

    -- Update flash timers
    for k, v in pairs(reloadFlash) do
        reloadFlash[k] = v - 0.016
        if reloadFlash[k] <= 0 then reloadFlash[k] = nil end
    end

    -- Auto-refresh
    if autoRefresh[0] then
        local now = os.clock()
        if now - lastRefresh >= REFRESH_INTERVAL then
            lastRefresh = now
            readLog()
            scanScripts()
        end
    end

    mimgui.SetNextWindowSize(mimgui.ImVec2(620, 520), mimgui.Cond.FirstUseEver)
    mimgui.SetNextWindowBgAlpha(0.97)

    mimgui.PushStyleColor(mimgui.Col.WindowBg,     COL.bg)
    mimgui.PushStyleColor(mimgui.Col.TitleBgActive, COL.titleBg)
    mimgui.PushStyleColor(mimgui.Col.Border,        COL.border)
    mimgui.PushStyleColor(mimgui.Col.FrameBg,       COL.bgPanel)
    mimgui.PushStyleColor(mimgui.Col.ScrollbarBg,   COL.bg)
    mimgui.PushStyleColor(mimgui.Col.ScrollbarGrab, COL.border)
    mimgui.PushStyleColor(mimgui.Col.Separator,     COL.border)
    mimgui.PushStyleVar(mimgui.StyleVar.WindowRounding, 8.0)
    mimgui.PushStyleVar(mimgui.StyleVar.FrameRounding,  5.0)
    mimgui.PushStyleVar(mimgui.StyleVar.ItemSpacing,    mimgui.ImVec2(6, 5))

    mimgui.Begin('  MOONLOADER SCRIPT MANAGER', showWindow,
        mimgui.WindowFlags.NoCollapse)

    -- ── Header ringkasan ──
    pushText(COL.gray)  ; mimgui.Text("Scripts:") ; popText()
    mimgui.SameLine(0,4)
    pushText(COL.white) ; mimgui.Text(tostring(totalScripts)) ; popText()
    mimgui.SameLine(0,14)
    pushText(COL.gray)  ; mimgui.Text("Running:") ; popText()
    mimgui.SameLine(0,4)
    pushText(COL.green) ; mimgui.Text(tostring(runningScripts)) ; popText()
    mimgui.SameLine(0,14)
    pushText(COL.gray)  ; mimgui.Text("Errors:") ; popText()
    mimgui.SameLine(0,4)
    pushText(errorCount > 0 and COL.red or COL.green)
    mimgui.Text(tostring(errorCount))
    popText()

    mimgui.SameLine(0, 16)
    pushBtn(COL.btnAll, COL.btnAllH, COL.btnAllA)
    if mimgui.Button('Reload Semua', mimgui.ImVec2(0, 24)) then
        lua_thread.create(reloadAllScripts)
    end
    popBtn()
    mimgui.SameLine(0, 4)
    pushBtn(COL.btnGray, COL.btnGrayH, COL.btnGrayA, COL.gray)
    if mimgui.Button('Refresh', mimgui.ImVec2(0, 24)) then
        scanScripts()
        readLog()
    end
    popBtn()

    mimgui.Separator()
    mimgui.Spacing()

    -- ── Tab bar ──
    local winW = mimgui.GetContentRegionAvail().x
    local tabW = (winW - 12) / 3
    tabButton('Scripts (' .. totalScripts .. ')', 1, tabW)
    mimgui.SameLine(0, 6)
    tabButton('Monitor', 2, tabW)
    mimgui.SameLine(0, 6)
    tabButton('Log', 3, tabW)

    mimgui.Spacing()
    mimgui.Separator()
    mimgui.Spacing()

    -- ════════════════════════════════════════════
    --  TAB 1 — SCRIPTS
    -- ════════════════════════════════════════════
    if activeTab == 1 then

        mimgui.PushStyleColor(mimgui.Col.FrameBg, COL.bgPanel)
        mimgui.PushItemWidth(-1)
        mimgui.InputText('##search', searchBuf, 0)
        mimgui.PopItemWidth()
        mimgui.PopStyleColor()

        local searchStr = ffi.string(searchBuf):lower()
        mimgui.Spacing()

        mimgui.BeginChild('##scriptlist', mimgui.ImVec2(-1, -1), false, 0)

        if #scriptList == 0 then
            pushText(COL.gray)
            mimgui.Text("  Tidak ada script ditemukan di: " .. SCRIPT_DIR)
            popText()
        end

        for _, entry in ipairs(scriptList) do
            if searchStr == "" or string.find(entry.name:lower(), searchStr, 1, true) then

                local flashActive = reloadFlash[entry.name] and reloadFlash[entry.name] > 0

                -- Row background
                local rowBg
                if flashActive then
                    local alpha = math.min(1.0, reloadFlash[entry.name])
                    rowBg = C(0.10, 0.40, 0.20, alpha * 0.6)
                elseif entry.hasError then
                    rowBg = C(0.30, 0.05, 0.05, 0.5)
                else
                    rowBg = COL.bgPanel
                end

                mimgui.PushStyleColor(mimgui.Col.ChildBg, rowBg)
                mimgui.BeginChild('##row_' .. entry.name, mimgui.ImVec2(-1, 36), false, 0)

                -- Dot status
                mimgui.SetCursorPosY(mimgui.GetCursorPosY() + 9)
                if entry.hasError then
                    pushText(COL.red)   ; mimgui.Text(" o") ; popText()
                elseif entry.loaded then
                    pushText(COL.green) ; mimgui.Text(" o") ; popText()
                else
                    pushText(COL.gray)  ; mimgui.Text(" o") ; popText()
                end
                mimgui.SameLine(0, 6)

                -- Nama script
                mimgui.SetCursorPosY(mimgui.GetCursorPosY() + 8)
                pushText(entry.hasError and COL.red or COL.white)
                mimgui.Text(entry.name)
                popText()

                -- Badge status
                mimgui.SameLine(0, 8)
                mimgui.SetCursorPosY(mimgui.GetCursorPosY() + 8)
                if entry.hasError then
                    pushText(COL.red)   ; mimgui.Text("[ERROR]")    ; popText()
                elseif flashActive then
                    pushText(COL.green) ; mimgui.Text("[RELOADED]") ; popText()
                end

                -- Tombol Reload kanan
                local contentW = mimgui.GetContentRegionAvail().x
                mimgui.SameLine(contentW - 58)
                mimgui.SetCursorPosY(mimgui.GetCursorPosY() + 5)
                pushBtn(COL.btnReload, COL.btnReloadH, COL.btnReloadA)
                if mimgui.Button('Reload##' .. entry.name, mimgui.ImVec2(56, 24)) then
                    local e = entry
                    lua_thread.create(function() reloadScript(e) end)
                end
                popBtn()

                mimgui.EndChild()
                mimgui.PopStyleColor()
                mimgui.Spacing()
            end
        end

        mimgui.EndChild()
    end

    -- ════════════════════════════════════════════
    --  TAB 2 — MONITOR
    -- FIX: Hapus SetWindowFontScale() yang tidak ada di mimgui MoonLoader
    -- ════════════════════════════════════════════
    if activeTab == 2 then

        local cardW = (mimgui.GetContentRegionAvail().x - 12) / 3

        -- Card: Total
        mimgui.PushStyleColor(mimgui.Col.ChildBg, C(0.12, 0.13, 0.17))
        mimgui.BeginChild('##card1', mimgui.ImVec2(cardW, 60), true, 0)
        pushText(COL.gray)  ; mimgui.Text("TOTAL SCRIPTS") ; popText()
        pushText(COL.blue)  ; mimgui.Text(tostring(totalScripts)) ; popText()
        mimgui.EndChild()
        mimgui.PopStyleColor()
        mimgui.SameLine(0, 6)

        -- Card: Running
        mimgui.PushStyleColor(mimgui.Col.ChildBg, C(0.08, 0.18, 0.12))
        mimgui.BeginChild('##card2', mimgui.ImVec2(cardW, 60), true, 0)
        pushText(COL.gray)  ; mimgui.Text("RUNNING") ; popText()
        pushText(COL.green) ; mimgui.Text(tostring(runningScripts)) ; popText()
        mimgui.EndChild()
        mimgui.PopStyleColor()
        mimgui.SameLine(0, 6)

        -- Card: Errors
        local cardErrBg = errorCount > 0 and C(0.22, 0.08, 0.08) or C(0.08, 0.18, 0.12)
        mimgui.PushStyleColor(mimgui.Col.ChildBg, cardErrBg)
        mimgui.BeginChild('##card3', mimgui.ImVec2(cardW, 60), true, 0)
        pushText(COL.gray) ; mimgui.Text("ERRORS") ; popText()
        pushText(errorCount > 0 and COL.red or COL.green)
        mimgui.Text(tostring(errorCount))
        popText()
        mimgui.EndChild()
        mimgui.PopStyleColor()

        mimgui.Spacing()
        mimgui.Separator()
        mimgui.Spacing()

        pushText(COL.red) ; mimgui.Text("ERROR & WARNING LIST") ; popText()
        mimgui.Spacing()

        mimgui.BeginChild('##errors', mimgui.ImVec2(-1, -1), false, 0)
        if #errorLines == 0 then
            pushText(COL.green)
            mimgui.Text("  Tidak ada error terdeteksi!")
            popText()
        else
            for _, entry in ipairs(errorLines) do
                pushText(COL.red)
                mimgui.TextWrapped(entry.text)
                popText()
                mimgui.Separator()
            end
        end
        mimgui.EndChild()
    end

    -- ════════════════════════════════════════════
    --  TAB 3 — LOG
    -- ════════════════════════════════════════════
    if activeTab == 3 then

        mimgui.Text("Filter: ")
        mimgui.SameLine()
        mimgui.PushStyleColor(mimgui.Col.Text, COL.red)
        mimgui.Checkbox('ERROR##fe', filterError)
        mimgui.PopStyleColor()
        mimgui.SameLine(0, 10)
        mimgui.PushStyleColor(mimgui.Col.Text, COL.yellow)
        mimgui.Checkbox('WARN##fw', filterWarn)
        mimgui.PopStyleColor()
        mimgui.SameLine(0, 10)
        mimgui.PushStyleColor(mimgui.Col.Text, COL.gray)
        mimgui.Checkbox('INFO##fi', filterInfo)
        mimgui.PopStyleColor()
        mimgui.SameLine(0, 16)
        mimgui.Checkbox('Auto-Refresh', autoRefresh)
        mimgui.SameLine(0, 10)
        pushBtn(COL.btnDanger, COL.btnDangerH, COL.btnDangerA)
        if mimgui.Button('Hapus Log', mimgui.ImVec2(0, 22)) then
            clearLog()
        end
        popBtn()

        mimgui.Spacing()
        mimgui.Separator()
        mimgui.Spacing()

        mimgui.BeginChild('##logview', mimgui.ImVec2(-1, -1), false, 0)

        for _, entry in ipairs(logLines) do
            local show = false
            if entry.level == "ERROR" and filterError[0] then show = true end
            if entry.level == "WARN"  and filterWarn[0]  then show = true end
            if entry.level == "INFO"  and filterInfo[0]  then show = true end

            if show then
                if     entry.level == "ERROR" then pushText(COL.red)
                elseif entry.level == "WARN"  then pushText(COL.yellow)
                else                               pushText(COL.gray) end
                mimgui.TextWrapped(entry.text)
                popText()
            end
        end

        if scrollToBottom then
            mimgui.SetScrollHereY(1.0)
            scrollToBottom = false
        end

        mimgui.EndChild()
    end

    mimgui.End()

    mimgui.PopStyleVar(3)
    mimgui.PopStyleColor(7)
end)

-- ═══════════════════════════════════════════════════════════
--  COMMAND CHAT
-- ═══════════════════════════════════════════════════════════
local function registerCommands()
    if commandsRegistered then return end
    if not (isSampAvailable and isSampAvailable()) then return end

    sampRegisterChatCommand('smgr', function()
        if not showWindow[0] then
            scanScripts()
            readLog()
        end
        showWindow[0] = not showWindow[0]
    end)

    sampRegisterChatCommand('sreload', function(args)
        if args and args ~= "" then
            local target = args:match("^%s*(.-)%s*$")
            if not target:find("%.lua$") then target = target .. ".lua" end
            lua_thread.create(function()
                local ok, err = pcall(loadLuaScript, target)
                if ok then
                    safeChat("{00FF88}[ScriptMgr] Reload OK: " .. target, -1)
                else
                    safeChat("{FF4444}[ScriptMgr] Gagal: " .. tostring(err), -1)
                end
            end)
        else
            safeChat("{AAAAAA}[ScriptMgr] Usage: /sreload <namafile.lua>", -1)
            safeChat("{AAAAAA}[ScriptMgr] Buka panel: /smgr", -1)
        end
    end)

    commandsRegistered = true
end

-- ═══════════════════════════════════════════════════════════
--  INIT
-- ═══════════════════════════════════════════════════════════
function main()
    while not (isSampAvailable and isSampAvailable()) do
        wait(250)
    end

    registerCommands()
    scanScripts()
    readLog()
    print("[ScriptMgr] Script Manager v1.1 FIXED dimuat!")
    print("[ScriptMgr] /smgr = buka panel | /sreload <file> = reload cepat")
    safeChat("{00AAFF}[ScriptMgr] Script Manager aktif — ketik {FFFFFF}/smgr{00AAFF} untuk buka panel", -1)

    while true do
        wait(0)
        if autoRefresh[0] and (os.clock() - lastRefresh >= REFRESH_INTERVAL) then
            readLog()
            scanScripts()
            lastRefresh = os.clock()
        end
    end
end
