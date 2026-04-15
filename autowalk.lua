script_author("NazarMaou")

local enabled = false
local selectedFile = nil
local coordinates = {}
local waitTime = 8000 -- Default wait time in milliseconds

require "lib.moonloader"
local json = require "dkjson"

local basePath = "/storage/emulated/0/Android/media/ro.alyn_sampmobile.game/monetloader/config/fileautowalk/"

function ensureDirectoryExists(path)
    os.execute("mkdir -p " .. path)
end

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then return end
    sampRegisterChatCommand("autowalk", function()
        if not selectedFile then
            sampAddChatMessage("{FF0000}[NazarMaou] Tidak ada file yang dipilih. Gunakan /selectfile <filename>", 0xFFFF0000)
            return
        end
        if #coordinates == 0 then
            sampAddChatMessage("{FF0000}[NazarMaou] Tidak ada koordinat dalam file yang dipilih.", 0xFFFF0000)
            return
        end
        enabled = not enabled
        sampAddChatMessage(enabled and "{00FF00}[NazarMaou] Autowalk AKTIF" or "{FF0000}[NazarMaou] Autowalk NONAKTIF", enabled and 0xFF00FF00 or 0xFFFF0000)
    end)
    sampRegisterChatCommand("createfile", function(filename)
        ensureDirectoryExists(basePath)
        if not filename:match("%.json$") then
            filename = filename .. ".json"
        end
        local file = io.open(basePath .. filename, "w")
        if file then
            file:write(json.encode({points = {}, waitTime = waitTime}))
            file:close()
            sampAddChatMessage("{00FF00}[NazarMaou] File berhasil dibuat: " .. filename, 0xFF00FF00)
        else
            sampAddChatMessage("{FF0000}[NazarMaou] Gagal membuat file.", 0xFFFF0000)
        end
    end)
    sampRegisterChatCommand("selectfile", function(filename)
        if not filename:match("%.json$") then
            filename = filename .. ".json"
        end
        local file = io.open(basePath .. filename, "r")
        if file then
            local content = file:read("*a")
            local data = json.decode(content)
            coordinates = data.points
            waitTime = data.waitTime or waitTime
            file:close()
            selectedFile = basePath .. filename
            sampAddChatMessage("{00FF00}[NazarMaou] File dipilih: " .. filename, 0xFF00FF00)
        else
            sampAddChatMessage("{FF0000}[NazarMaou] Gagal membuka file.", 0xFFFF0000)
        end
    end)
    sampRegisterChatCommand("remcord", function(index)
        if not selectedFile then
            sampAddChatMessage("{FF0000}[NazarMaou] Tidak ada file yang dipilih. Gunakan /selectfile <filename>", 0xFFFF0000)
            return
        end
        index = tonumber(index)
        if index and coordinates[index] then
            table.remove(coordinates, index)
            local file = io.open(selectedFile, "w")
            if file then
                file:write(json.encode({points = coordinates, waitTime = waitTime}))
                file:close()
                sampAddChatMessage("{00FF00}[NazarMaou] Koordinat dihapus.", 0xFF00FF00)
            else
                sampAddChatMessage("{FF0000}[NazarMaou] Gagal menulis ke file.", 0xFFFF0000)
            end
        else
            sampAddChatMessage("{FF0000}[NazarMaou] Indeks tidak valid.", 0xFFFF0000)
        end
    end)
    sampRegisterChatCommand("setcord", function()
        if not selectedFile then
            sampAddChatMessage("{FF0000}[NazarMaou] Tidak ada file yang dipilih. Gunakan /selectfile <filename>", 0xFFFF0000)
            return
        end
        local posX, posY, posZ = getCharCoordinates(PLAYER_PED)
        table.insert(coordinates, {posX, posY, posZ, 11, -255, true})
        local file = io.open(selectedFile, "w")
        if file then
            file:write(json.encode({points = coordinates, waitTime = waitTime}))
            file:close()
            sampAddChatMessage("{00FF00}[NazarMaou] Koordinat ditambahkan.", 0xFF00FF00)
        else
            sampAddChatMessage("{FF0000}[NazarMaou] Gagal menulis ke file.", 0xFFFF0000)
        end
    end)
    sampRegisterChatCommand("setwait", function(time)
        if not selectedFile then
            sampAddChatMessage("{FF0000}[NazarMaou] Tidak ada file yang dipilih. Gunakan /selectfile <filename>", 0xFFFF0000)
            return
        end
        waitTime = tonumber(time) * 1000 -- Convert to milliseconds
        local file = io.open(selectedFile, "w")
        if file then
            file:write(json.encode({points = coordinates, waitTime = waitTime}))
            file:close()
            sampAddChatMessage("{00FF00}[NazarMaou] Waktu tunggu diatur ke " .. time .. " detik.", 0xFF00FF00)
        else
            sampAddChatMessage("{FF0000}[NazarMaou] Gagal menulis ke file.", 0xFFFF0000)
        end
    end)
    sampRegisterChatCommand("helpcommand", function()
        sampAddChatMessage("{00FFFF}[NazarMaou] Perintah yang tersedia:", 0xFF00FFFF)
        sampAddChatMessage("{00FFFF}/autowalk - Mengaktifkan/mematikan autowalk", 0xFF00FFFF)
        sampAddChatMessage("{00FFFF}/createfile <filename> - Membuat file baru", 0xFF00FFFF)
        sampAddChatMessage("{00FFFF}/selectfile <filename> - Memilih file", 0xFF00FFFF)
        sampAddChatMessage("{00FFFF}/remcord <index> - Menghapus koordinat", 0xFF00FFFF)
        sampAddChatMessage("{00FFFF}/setcord - Menyimpan posisi saat ini sebagai koordinat", 0xFF00FFFF)
        sampAddChatMessage("{00FFFF}/setwait <time> - Mengatur waktu tunggu dalam detik", 0xFF00FFFF)
    end)

    while not isSampAvailable() do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(10) end

    while true do
        wait(0)
        if enabled then
            moveToPoints()
        end
    end
end

function MovePlayer(move_code, isSprint)
    setGameKeyState(1, move_code)  
    if isSprint then
        setGameKeyState(16, 255) 
    else
        setGameKeyState(16, 0) 
    end
end

function BeginToPoint(x, y, z, radius, move_code, isSprint)
    repeat
        local posX, posY, posZ = getCharCoordinates(PLAYER_PED)
        SetAngle(x, y, z)
        MovePlayer(move_code, isSprint)  
        local dist = getDistanceBetweenCoords3d(x, y, z, posX, posY, z)
        wait(0)
    until not enabled or dist < radius
end

function moveToPoints()
    local index = 1  

    while enabled do
        local point = coordinates[index]
        BeginToPoint(point[1], point[2], point[3], 1.0, point[5], point[6])  
        wait(point[4])

        wait(waitTime)  

        if index == #coordinates then
            index = 1
        else
            index = index + 1
        end
    end

    setGameKeyState(14, 1)
    wait(20)
    setGameKeyState(14, 0)
end

function SetAngle(x, y, z)
    local posX, posY, posZ = getCharCoordinates(PLAYER_PED)
    local pX = x - posX
    local pY = y - posY
    local zAngle = getHeadingFromVector2d(pX, pY)

    setCharHeading(PLAYER_PED, zAngle)

    restoreCameraJumpcut()
end