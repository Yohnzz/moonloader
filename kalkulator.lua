-- Kalkulator Biaya Medis untuk AutoRP Medis
-- Versi 2.1 - FIXED (no crash, no require json, bool diganti native Lua)
-- Support Windows 10 22H2 + MoonLoader

local ffi = require 'ffi'
local mimgui = require 'lib.mimgui'

-- ═══════════════════════════════════════════════
--  KONFIGURASI PATH
-- ═══════════════════════════════════════════════
local historyFilePath = getWorkingDirectory() .. "\\moonloader\\config\\kalkulator_history.json"

-- ═══════════════════════════════════════════════
--  VARIABEL KALKULATOR
-- ═══════════════════════════════════════════════
local showCalculatorWindow = mimgui.new.bool(false)
local calcDisplay          = mimgui.new.char[256]("0")
local calcPrevious         = 0.0        -- FIX: pakai native Lua, bukan mimgui.new.float
local calcOperation        = ""
local calcNewNumber        = true       -- FIX: pakai native Lua bool, bukan mimgui.new.bool
local calcHistory          = {}
local maxHistory           = 20

-- ═══════════════════════════════════════════════
--  PERSISTENSI HISTORY (baca / tulis manual JSON)
-- ═══════════════════════════════════════════════
local function ensureDir(path)
    os.execute('mkdir "' .. path .. '" 2>NUL')
end

local function saveHistory()
    ensureDir(getWorkingDirectory() .. "\\moonloader\\config")
    local file = io.open(historyFilePath, "w")
    if file then
        local lines = {}
        for _, v in ipairs(calcHistory) do
            local escaped = string.gsub(v, '"', '\\"')
            table.insert(lines, '"' .. escaped .. '"')
        end
        file:write("[\n" .. table.concat(lines, ",\n") .. "\n]")
        file:close()
    end
end

local function loadHistory()
    local file = io.open(historyFilePath, "r")
    if not file then return end
    local content = file:read("*a")
    file:close()
    calcHistory = {}
    for entry in string.gmatch(content, '"(.-)"') do
        entry = string.gsub(entry, '\\"', '"')
        table.insert(calcHistory, entry)
        if #calcHistory >= maxHistory then break end
    end
end

-- ═══════════════════════════════════════════════
--  HELPER
-- ═══════════════════════════════════════════════
local function getDisplay()
    local s = ffi.string(calcDisplay)
    if s == "" then s = "0" end
    return s
end

local function setDisplay(val)
    ffi.copy(calcDisplay, tostring(val))
end

local function round6(n)
    return math.floor(n * 1e6 + 0.5) / 1e6
end

local function formatResult(n)
    local s = tostring(round6(n))
    return s
end

local function addToHistory(expr, result)
    local entry = expr .. " = " .. formatResult(result)
    table.insert(calcHistory, 1, entry)
    if #calcHistory > maxHistory then
        table.remove(calcHistory)
    end
    saveHistory()
end

-- ═══════════════════════════════════════════════
--  OPERASI KALKULATOR
-- ═══════════════════════════════════════════════
local function openCalculator()
    showCalculatorWindow[0] = true
end

local function calculatePercentage()
    local n = tonumber(getDisplay())
    if n then
        setDisplay(formatResult(n / 100))
        calcNewNumber = true
    end
end

local function calculateSquareRoot()
    local n = tonumber(getDisplay())
    if n and n >= 0 then
        local r = round6(math.sqrt(n))
        setDisplay(formatResult(r))
        calcNewNumber = true
        addToHistory("sqrt(" .. n .. ")", r)
    end
end

local function calculateSquare()
    local n = tonumber(getDisplay())
    if n then
        local r = round6(n * n)
        setDisplay(formatResult(r))
        calcNewNumber = true
        addToHistory(n .. "^2", r)
    end
end

local function calculateReciprocal()
    local n = tonumber(getDisplay())
    if n and n ~= 0 then
        local r = round6(1 / n)
        setDisplay(formatResult(r))
        calcNewNumber = true
        addToHistory("1/" .. n, r)
    end
end

local function toggleSign()
    local s = getDisplay()
    if s ~= "0" then
        if string.sub(s, 1, 1) == "-" then
            setDisplay(string.sub(s, 2))
        else
            setDisplay("-" .. s)
        end
    end
end

local function backspace()
    local s = getDisplay()
    if #s > 1 then
        setDisplay(string.sub(s, 1, -2))
    else
        setDisplay("0")
        calcNewNumber = true
    end
end

local function clearEntry()
    setDisplay("0")
    calcNewNumber = true
end

local function clearAll()
    setDisplay("0")
    calcPrevious  = 0.0
    calcOperation = ""
    calcNewNumber = true
end

local function applyOperation(prevVal, op, curVal)
    if op == "+" then return prevVal + curVal
    elseif op == "-" then return prevVal - curVal
    elseif op == "*" then return prevVal * curVal
    elseif op == "/" then
        if curVal ~= 0 then return prevVal / curVal else return 0 end
    end
    return curVal
end

local function pressOperator(op)
    local cur    = string.gsub(getDisplay(), ",", ".")
    local curVal = tonumber(cur) or 0

    if calcOperation ~= "" then
        local result = round6(applyOperation(calcPrevious, calcOperation, curVal))
        setDisplay(formatResult(result))
        calcPrevious = result
    else
        calcPrevious = curVal
    end
    calcOperation = op
    calcNewNumber = true
end

local function pressEquals()
    if calcOperation == "" then return end
    local cur    = string.gsub(getDisplay(), ",", ".")
    local curVal = tonumber(cur) or 0
    local expr   = formatResult(calcPrevious) .. " " .. calcOperation .. " " .. formatResult(curVal)
    local result = round6(applyOperation(calcPrevious, calcOperation, curVal))
    setDisplay(formatResult(result))
    addToHistory(expr, result)
    calcPrevious  = 0.0
    calcOperation = ""
    calcNewNumber = true
end

local function pressNumber(num)
    local cur = getDisplay()
    if calcNewNumber then
        setDisplay(num)
        calcNewNumber = false
    else
        if cur == "0" then
            setDisplay(num)
        else
            setDisplay(cur .. num)
        end
    end
end

local function pressDot()
    local cur = getDisplay()
    if calcNewNumber then
        setDisplay("0.")
        calcNewNumber = false
    elseif not string.find(cur, "%.") then
        setDisplay(cur .. ".")
    end
end

-- ═══════════════════════════════════════════════
--  GUI  ─ Modern Dark Theme
-- ═══════════════════════════════════════════════
mimgui.OnFrame(function() return showCalculatorWindow[0] end, function()

    mimgui.SetNextWindowSize(mimgui.ImVec2(340, 580), mimgui.Cond.FirstUseEver)
    mimgui.SetNextWindowBgAlpha(0.97)

    local C = {
        winBg       = mimgui.ImVec4(0.12, 0.12, 0.14, 1.0),
        displayBg   = mimgui.ImVec4(0.08, 0.08, 0.10, 1.0),
        displayText = mimgui.ImVec4(1.00, 1.00, 1.00, 1.0),
        numBtn      = mimgui.ImVec4(0.20, 0.20, 0.23, 1.0),
        numHov      = mimgui.ImVec4(0.28, 0.28, 0.32, 1.0),
        numAct      = mimgui.ImVec4(0.35, 0.35, 0.40, 1.0),
        opBtn       = mimgui.ImVec4(0.16, 0.38, 0.62, 1.0),
        opHov       = mimgui.ImVec4(0.20, 0.48, 0.76, 1.0),
        opAct       = mimgui.ImVec4(0.14, 0.30, 0.52, 1.0),
        eqBtn       = mimgui.ImVec4(0.18, 0.52, 0.90, 1.0),
        eqHov       = mimgui.ImVec4(0.24, 0.62, 1.00, 1.0),
        eqAct       = mimgui.ImVec4(0.14, 0.42, 0.78, 1.0),
        specBtn     = mimgui.ImVec4(0.17, 0.17, 0.20, 1.0),
        specHov     = mimgui.ImVec4(0.24, 0.24, 0.28, 1.0),
        specAct     = mimgui.ImVec4(0.30, 0.30, 0.35, 1.0),
        clrBtn      = mimgui.ImVec4(0.55, 0.15, 0.15, 1.0),
        clrHov      = mimgui.ImVec4(0.70, 0.20, 0.20, 1.0),
        clrAct      = mimgui.ImVec4(0.45, 0.10, 0.10, 1.0),
        textWhite   = mimgui.ImVec4(1.00, 1.00, 1.00, 1.0),
        textGray    = mimgui.ImVec4(0.55, 0.55, 0.60, 1.0),
        histText    = mimgui.ImVec4(0.70, 0.85, 1.00, 1.0),
    }

    mimgui.PushStyleColor(mimgui.Col.WindowBg,      C.winBg)
    mimgui.PushStyleColor(mimgui.Col.TitleBgActive, mimgui.ImVec4(0.10, 0.10, 0.13, 1.0))
    mimgui.PushStyleColor(mimgui.Col.Border,        mimgui.ImVec4(0.30, 0.30, 0.35, 1.0))
    mimgui.PushStyleVar(mimgui.StyleVar.WindowRounding, 8.0)
    mimgui.PushStyleVar(mimgui.StyleVar.FrameRounding,  6.0)
    mimgui.PushStyleVar(mimgui.StyleVar.ItemSpacing,    mimgui.ImVec2(5, 5))

    mimgui.Begin('Kalkulator Medis', showCalculatorWindow,
        mimgui.WindowFlags.NoCollapse + mimgui.WindowFlags.NoResize)

    local BW = 72
    local BH = 48
    local SP = 5

    -- ── Display ──
    mimgui.PushStyleColor(mimgui.Col.FrameBg, C.displayBg)
    mimgui.PushStyleColor(mimgui.Col.Text,    C.displayText)
    mimgui.PushItemWidth(-1)
    mimgui.InputText('##display', calcDisplay, mimgui.InputTextFlags.ReadOnly)
    mimgui.PopItemWidth()
    mimgui.PopStyleColor(2)

    if calcOperation ~= "" then
        mimgui.PushStyleColor(mimgui.Col.Text, C.textGray)
        mimgui.Text("  " .. formatResult(calcPrevious) .. " " .. calcOperation)
        mimgui.PopStyleColor()
    else
        mimgui.Spacing()
    end

    mimgui.Separator()
    mimgui.Spacing()

    -- ── Helper Button Functions ──
    local function btnNum(label, w, h)
        w = w or BW; h = h or BH
        mimgui.PushStyleColor(mimgui.Col.Button,        C.numBtn)
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, C.numHov)
        mimgui.PushStyleColor(mimgui.Col.ButtonActive,  C.numAct)
        mimgui.PushStyleColor(mimgui.Col.Text,          C.textWhite)
        local clicked = mimgui.Button(label, mimgui.ImVec2(w, h))
        mimgui.PopStyleColor(4)
        return clicked
    end

    local function btnOp(label, w, h)
        w = w or BW; h = h or BH
        mimgui.PushStyleColor(mimgui.Col.Button,        C.opBtn)
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, C.opHov)
        mimgui.PushStyleColor(mimgui.Col.ButtonActive,  C.opAct)
        mimgui.PushStyleColor(mimgui.Col.Text,          C.textWhite)
        local clicked = mimgui.Button(label, mimgui.ImVec2(w, h))
        mimgui.PopStyleColor(4)
        return clicked
    end

    local function btnSpec(label, w, h)
        w = w or BW; h = h or BH
        mimgui.PushStyleColor(mimgui.Col.Button,        C.specBtn)
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, C.specHov)
        mimgui.PushStyleColor(mimgui.Col.ButtonActive,  C.specAct)
        mimgui.PushStyleColor(mimgui.Col.Text,          C.textGray)
        local clicked = mimgui.Button(label, mimgui.ImVec2(w, h))
        mimgui.PopStyleColor(4)
        return clicked
    end

    local function btnClr(label, w, h)
        w = w or BW; h = h or BH
        mimgui.PushStyleColor(mimgui.Col.Button,        C.clrBtn)
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, C.clrHov)
        mimgui.PushStyleColor(mimgui.Col.ButtonActive,  C.clrAct)
        mimgui.PushStyleColor(mimgui.Col.Text,          C.textWhite)
        local clicked = mimgui.Button(label, mimgui.ImVec2(w, h))
        mimgui.PopStyleColor(4)
        return clicked
    end

    local function btnEq(label, w, h)
        w = w or BW; h = h or BH
        mimgui.PushStyleColor(mimgui.Col.Button,        C.eqBtn)
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, C.eqHov)
        mimgui.PushStyleColor(mimgui.Col.ButtonActive,  C.eqAct)
        mimgui.PushStyleColor(mimgui.Col.Text,          C.textWhite)
        local clicked = mimgui.Button(label, mimgui.ImVec2(w, h))
        mimgui.PopStyleColor(4)
        return clicked
    end

    -- ── BARIS 1: Fungsi Ilmiah ──
    if btnSpec('sqrt', BW, BH) then calculateSquareRoot() end
    mimgui.SameLine(0, SP)
    if btnSpec('x^2',  BW, BH) then calculateSquare() end
    mimgui.SameLine(0, SP)
    if btnSpec('1/x',  BW, BH) then calculateReciprocal() end
    mimgui.SameLine(0, SP)
    if btnSpec('%',    BW, BH) then calculatePercentage() end

    -- ── BARIS 2: CE  C  +-  <- ──
    if btnClr('CE', BW, BH) then clearEntry() end
    mimgui.SameLine(0, SP)
    if btnClr('C',  BW, BH) then clearAll() end
    mimgui.SameLine(0, SP)
    if btnSpec('+-', BW, BH) then toggleSign() end
    mimgui.SameLine(0, SP)
    if btnSpec('<-', BW, BH) then backspace() end

    mimgui.Spacing()

    -- ── BARIS 3: 7  8  9  / ──
    if btnNum('7') then pressNumber('7') end ; mimgui.SameLine(0, SP)
    if btnNum('8') then pressNumber('8') end ; mimgui.SameLine(0, SP)
    if btnNum('9') then pressNumber('9') end ; mimgui.SameLine(0, SP)
    if btnOp('/') then pressOperator('/') end

    -- ── BARIS 4: 4  5  6  * ──
    if btnNum('4') then pressNumber('4') end ; mimgui.SameLine(0, SP)
    if btnNum('5') then pressNumber('5') end ; mimgui.SameLine(0, SP)
    if btnNum('6') then pressNumber('6') end ; mimgui.SameLine(0, SP)
    if btnOp('*') then pressOperator('*') end

    -- ── BARIS 5: 1  2  3  - ──
    if btnNum('1') then pressNumber('1') end ; mimgui.SameLine(0, SP)
    if btnNum('2') then pressNumber('2') end ; mimgui.SameLine(0, SP)
    if btnNum('3') then pressNumber('3') end ; mimgui.SameLine(0, SP)
    if btnOp('-') then pressOperator('-') end

    -- ── BARIS 6: 00  0  .  + ──
    if btnNum('00', BW, BH) then
        pressNumber('0')
        pressNumber('0')
    end
    mimgui.SameLine(0, SP)
    if btnNum('0', BW, BH) then pressNumber('0') end
    mimgui.SameLine(0, SP)
    if btnNum('.', BW, BH) then pressDot() end
    mimgui.SameLine(0, SP)
    if btnOp('+') then pressOperator('+') end

    -- ── BARIS 7: = (full width) ──
    mimgui.Spacing()
    if btnEq('=', -1, BH) then pressEquals() end

    -- ── PANEL RIWAYAT ──
    mimgui.Spacing()
    mimgui.Separator()
    mimgui.Spacing()

    mimgui.PushStyleColor(mimgui.Col.Text, C.textGray)
    mimgui.Text("RIWAYAT  (" .. #calcHistory .. "/" .. maxHistory .. ")")
    mimgui.PopStyleColor()

    if #calcHistory == 0 then
        mimgui.PushStyleColor(mimgui.Col.Text, C.textGray)
        mimgui.Text("  Belum ada riwayat.")
        mimgui.PopStyleColor()
    else
        mimgui.BeginChild('##history', mimgui.ImVec2(-1, 90), false, 0)
        for i = 1, math.min(#calcHistory, maxHistory) do
            mimgui.PushStyleColor(mimgui.Col.Text, C.histText)
            mimgui.Text(calcHistory[i])
            mimgui.PopStyleColor()
        end
        mimgui.EndChild()

        mimgui.Spacing()
        if btnClr('Hapus Riwayat', -1, 28) then
            calcHistory = {}
            saveHistory()
        end
    end

    -- ── Tombol Tutup ──
    mimgui.Spacing()
    mimgui.Separator()
    mimgui.Spacing()
    if btnSpec('Tutup  [X]', -1, 28) then
        showCalculatorWindow[0] = false
    end

    mimgui.End()

    mimgui.PopStyleVar(3)
    mimgui.PopStyleColor(3)
end)

-- ═══════════════════════════════════════════════
--  COMMAND CHAT
-- ═══════════════════════════════════════════════
sampRegisterChatCommand('pkalkulator', function()
    openCalculator()
end)

-- ═══════════════════════════════════════════════
--  INIT & MAIN LOOP
-- ═══════════════════════════════════════════════
function main()
    -- Pastikan SAMP sudah dimuat sebelum mendaftarkan command
    while not isSampAvailable() do wait(100) end
    
    loadHistory()

    sampRegisterChatCommand('pkalkulator', function()
        showCalculatorWindow[0] = not showCalculatorWindow[0] -- Toggle (buka/tutup)
        if showCalculatorWindow[0] then
            -- Menampilkan kursor saat GUI terbuka
            sampSetCursorMode(3)
        end
    end)

    print("[AutoRP Medis] Kalkulator Biaya Medis v2.1 dimuat!")
    print("[AutoRP Medis] Gunakan /pkalkulator untuk membuka kalkulator")

    -- WAJIB: Loop utama agar skrip tidak mati
    while true do
        wait(0)
        
        -- Otomatis sembunyikan kursor jika window ditutup lewat tombol [X]
        if not showCalculatorWindow[0] and isCursorActive() then
            sampSetCursorMode(0)
        end
    end
end