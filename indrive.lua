-- Auto RP TRANS GUI - Hummatech Edition (Integrated Quick Invoice)
require 'lib.sampfuncs'
require 'lib.moonloader'
local mimgui = require 'lib.mimgui'
local encoding = require 'lib.encoding'
encoding.default = 'CP1252'
local ffi = require "ffi"
local sampev = require 'lib.sampfuncs.events'

-- =========================================
-- STATE & BUFFER
-- =========================================
local showWindow = mimgui.new.bool(false)
local selectedCategoryIndex = mimgui.new.int(1)

local invState = {
    targetId = -1,
    namaInv = mimgui.new.char[128](''),
    hargaInv = mimgui.new.char[64](''),
    isProcessing = false,
    step = 0
}

local bufNama   = mimgui.new.char[128]('')
local bufJumlah = mimgui.new.char[32]('')
local bufAlasan = mimgui.new.char[256]('')

-- =========================================
-- KONFIGURASI KATEGORI
-- =========================================
local rpCategories = {
    {
        name = 'Pengumuman',
        description = 'Kategori untuk pengumuman terkait status layanan TRANS.',
        rps = {
            {
                name = 'Buka Pelayanan',
                desc = 'Memberikan pengumuman bahwa pelayanan di TRANS telah dibuka.',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS TELAH DIBUKA || SILAKAN ORDER MELALUI HP',
                    '/fa MELAYANI ANTAR JEMPUT - ANTAR MAKANAN - ANTAR TOOLKIT',
                    '/fa TERIMAKASIH'
                }
            },
            {
                name = 'Tutup Pelayanan',
                desc = 'Memberikan pengumuman bahwa pelayanan di TRANS telah ditutup.',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS TELAH DITUTUP || KITA BERTEMU DI LAIN WAKTU',
                    '/fa TERIMAKASIH'
                }
            },
            {
                name = 'Darurat',
                desc = 'Memberikan informasi jika orderan banyak',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa DIINFORMASIKAN KEPADA PEMESAN LAYANAN TRANS',
                    '/fa MOHON BERSABAR JIKA ORDERAN BELUM DITERIMA',
                    '/fa DIKARENAKAN PETUGAS YANG JUMLAHNYA TERBATAS',
                    '/fa SILAHKAN MENUNGGU DI LOKASI PENJEMPUTAN HINGGA MAKS 15 MENIT',
                    '/fa TERIMAKASIH'
                }
            },
            {
                name = 'Tips',
                desc = 'Memberikan informasi Tips kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa SILAHKAN BAGI PARA WARGA MENUNGGU MAKS 15 MENIT',
                    '/fa JIKA DALAM WAKTU TERSEBUT BELUM TIDAK DI LOKASI PENJEMPUTAN',
                    '/fa MAKA PIHAK TRANS BERHAK BLACKLIST PELANGGAN',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
            {
                name = 'Paket',
                desc = 'Memberikan informasi Paket kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa SELAIN ANTAR ANTAR TRANS JUGA MENYEDIAKAN LAYANAN PAKET MENARIK',
                    '/fa SILAHKAN CEK DI WEBSITE KAMI UNTUK INFO LEBIH LANJUT',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
            {
                name = 'Buka Pelayanan (Alternatif)',
                desc = 'Memberikan informasi Buka Pelayanan (Alternatif) kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS TELAH DIBUKA || SILAKAN ORDER MELALUI HP MASING MASING',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
            {
                name = 'Layanan Telah Terbuka',
                desc = 'Memberikan informasi Buka Pelayanan (Alternatif) kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS MASIH DIBUKA || SILAKAN ORDER MELALUI HP MASING MASING',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
            {
                name = 'RECRUITMENT',
                desc = 'Memberikan informasi Buka Pelayanan (Alternatif) kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS MASIH DIBUKA || SILAKAN ORDER MELALUI HP MASING MASING',
                    '/fa RECRUITMENT TRANS JUGA MASIH TERBUKA',
                    '/fa BAGI WARGA YANG INGIN MENJADI ANGGOTA TRANS DAPAT DAFTAR DI WEB #recruitment-trans',
                    '/fa YANG PERLU DIPERSIAPKAN HANYALAH UMUR 15+, KTP DAN MEMILIKI KEAHLIAN BERKENDARA MOBIL',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
        }
    },
    {
        name = 'Warning Customer',
        description = 'Kategori untuk memberikan peringatan/warning kepada customer TRANS.',
        isWarningCategory = true,
        rps = {}
    }
}
-- =========================================
-- UTILITY FUNCTIONS
-- =========================================
function getNearbyPlayers(radius)
    local players = {}
    local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
    for i = 0, 1000 do
        local exists, handle = sampGetCharHandleBySampPlayerId(i)
        if exists then
            local pX, pY, pZ = getCharCoordinates(handle)
            local dist = getDistanceBetweenCoords3d(myX, myY, myZ, pX, pY, pZ)
            if dist <= radius and handle ~= PLAYER_PED then
                table.insert(players, {id = i, name = sampGetPlayerNickname(i), dist = dist})
            end
        end
    end
    return players
end

function executeCommands(commands)
    if not commands then return end
    lua_thread.create(function()
        for _, cmd in ipairs(commands) do
            sampSendChat(cmd)
            wait(math.random(2000, 2500))
        end
    end)
end

-- =========================================
-- SISTEM BLOCKER (ANTI TEMBUS POLICE HELPER)
-- =========================================
addEventHandler('onWindowMessage', function(msg, wparam, lparam)
    if showWindow[0] and mimgui.GetIO().WantCaptureKeyboard then
        if msg == 0x100 or msg == 0x101 or msg == 0x102 then
            consumeWindowMessage(true)
        end
    end
end)

-- =========================================
-- LOGIKA INVOICE OTOMATIS (DIALOG INTERCEPTOR)
-- =========================================
function sampev.onShowDialog(id, style, title, b1, b2, text)
    if invState.isProcessing then
        local titleL = title:lower()
        
        -- Step 1: Menu Utama (Klik Action)
        if invState.step == 1 then
            local lines = {}
            for line in text:gmatch("[^\r\n]+") do table.insert(lines, line:lower()) end
            for i, val in ipairs(lines) do
                if val:find("action") or val:find("interaksi") then
                    lua_thread.create(function() wait(400) sampSendDialogResponse(id, 1, i-1, "") end)
                    invState.step = 2
                    return false
                end
            end
        end

        -- Step 2: Pilih ID Target
        if invState.step == 2 then
            local lines = {}
            for line in text:gmatch("[^\r\n]+") do table.insert(lines, line:lower()) end
            for i, val in ipairs(lines) do
                if val:find("%["..invState.targetId.."%]") or val:find("id "..invState.targetId) then
                    lua_thread.create(function() wait(400) sampSendDialogResponse(id, 1, i-1, "") end)
                    invState.step = 3
                    return false
                end
            end
        end

        -- Step 3: Input Data (Alasan & Harga)
        if style == 1 or style == 3 then
            if titleL:find("alasan") or titleL:find("nama") or titleL:find("invoice") then
                lua_thread.create(function() wait(400) sampSendDialogResponse(id, 1, -1, ffi.string(invState.namaInv)) end)
                return false
            elseif titleL:find("harga") or titleL:find("nominal") or titleL:find("jumlah") then
                lua_thread.create(function()
                    wait(400)
                    sampSendDialogResponse(id, 1, -1, ffi.string(invState.hargaInv))
                    invState.isProcessing = false
                    invState.step = 0
                    sampAddChatMessage("{00FF00}[TRANS] {FFFFFF}Invoice berhasil diproses otomatis.", -1)
                end)
                return false
            end
        end
    end
end

-- =========================================
-- UI MIMGUI
-- =========================================
mimgui.OnInitialize(function()
    local style = mimgui.GetStyle()
    style.WindowRounding = 5.0
    style.FrameRounding = 4.0
    local colors = style.Colors
    colors[mimgui.Col.Text] = mimgui.ImVec4(1.00, 0.95, 0.70, 1.00)
    colors[mimgui.Col.WindowBg] = mimgui.ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[mimgui.Col.Border] = mimgui.ImVec4(1.00, 0.84, 0.00, 0.80)
    colors[mimgui.Col.Button] = mimgui.ImVec4(0.12, 0.10, 0.05, 1.00)
    colors[mimgui.Col.ButtonHovered] = mimgui.ImVec4(1.00, 0.84, 0.00, 0.45)
end)

mimgui.OnFrame(function() return showWindow[0] end, function()
    if not showWindow[0] then sampSetCursorMode(0) end
    sampSetCursorMode(2) -- Kunci kontrol game agar tidak gerak saat ngetik

    mimgui.SetNextWindowSize(mimgui.ImVec2(650, 450), mimgui.Cond.FirstUseEver)
    mimgui.Begin('Auto RP TRANS - Hummatech Edition', showWindow)

    -- Panel Kiri
    mimgui.BeginChild('CategoryList', mimgui.ImVec2(180, 0), true)
    for i, category in ipairs(rpCategories) do
        if mimgui.Selectable(category.name, selectedCategoryIndex[0] == i) then
            selectedCategoryIndex[0] = i
        end
    end
    mimgui.EndChild()

    mimgui.SameLine()

    -- Panel Kanan
    mimgui.BeginChild('RightPanel', mimgui.ImVec2(0, 0), false)
    local cat = rpCategories[selectedCategoryIndex[0]]
    mimgui.Text(cat.name)
    mimgui.Separator()

    if cat.isWarningCategory then
        mimgui.Text('Nama Customer:')
        mimgui.InputText('##NamaCustomer', bufNama, 128)
        mimgui.Text('Jumlah Warning:')
        mimgui.InputText('##JumlahWarning', bufJumlah, 32)
        mimgui.Text('Alasan:')
        mimgui.InputTextMultiline('##Alasan', bufAlasan, 256, mimgui.ImVec2(-1, 60))
        if mimgui.Button('Kirim Warning', mimgui.ImVec2(-1, 32)) then
            local cmds = {'/fa PENGUMUMAN', '/fa CUSTOMER: '..string.upper(ffi.string(bufNama)), '/fa WARNING '..ffi.string(bufJumlah)..' KARENA '..string.upper(ffi.string(bufAlasan)), '/fa TERIMAKASIH'}
            executeCommands(cmds)
            showWindow[0] = false
        end

    elseif cat.isInvoiceCategory then
        mimgui.Text("Daftar Warga Sekitar (15m):")
        mimgui.BeginChild("ListInv", mimgui.ImVec2(0, 120), true)
        local nearby = getNearbyPlayers(15)
        for _, p in ipairs(nearby) do
            if mimgui.Selectable(string.format("[%d] %s (%.1fm)", p.id, p.name, p.dist), invState.targetId == p.id) then
                invState.targetId = p.id
            end
        end
        mimgui.EndChild()

        if invState.targetId ~= -1 then
            mimgui.Spacing()
            mimgui.Text("Invoice untuk ID: " .. invState.targetId)
            mimgui.InputText("Alasan Invoice", invState.namaInv, 128)
            mimgui.InputText("Harga Invoice", invState.hargaInv, 64)
            if mimgui.Button("PROSES INVOICE SEKARANG", mimgui.ImVec2(-1, 35)) then
                invState.isProcessing = true
                invState.step = 1
                setVirtualKeyDown(0x4E, true) -- Tekan N
                lua_thread.create(function() wait(100) setVirtualKeyDown(0x4E, false) end)
                showWindow[0] = false
            end
        end

    else
        for _, rp in ipairs(cat.rps) do
            if mimgui.Button(rp.name, mimgui.ImVec2(-1, 30)) then
                executeCommands(rp.cmds)
                showWindow[0] = false
            end
        end
    end
    mimgui.EndChild()
    mimgui.End()
end)

function main()
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand('td', function() showWindow[0] = not showWindow[0] end)
    
    -- Reset kursor jika klik X
    lua_thread.create(function()
        while true do
            wait(0)
            if not showWindow[0] and isSampCursorActive() then sampSetCursorMode(0) end
        end
    end)
    wait(-1)
end