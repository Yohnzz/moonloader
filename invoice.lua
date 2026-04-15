-- Auto Trigger Dialog Invoice System dengan Proximity Detection
-- Enhanced version dengan trigger system & kantong detection

script_author("oxmarioid")

local script_version = "1.2"
local script_name = "Auto Invoice Trigger"

local sampev = require 'lib.samp.events'
local ffi = require "ffi"

-- Configuration
local CONFIG = {
    DIALOG_EMS_PANEL = 191,
    DIALOG_INPUT = 455,
    KEYWORD_INVOICE_MANUAL = "invoice manual",
    MAX_PROXIMITY_DISTANCE = 15.0,
    RP_TIMING = {
        PROP_TABLET = 1000,
        TAKE_TABLET = 2500,
        POWER_ON = 4000,
        TYPING = 5500,
        SHOW_FORM = 7000,
        APPROACH_PATIENT = 8500,
        EXPLAIN_INVOICE = 10000,
        INVOICE_DETAILS = 11500,
        POWER_OFF = 13000,
        CLOSE_PROP = 14500
    }
}

-- Invoice Types with Prices
local INVOICE_TYPES = {
    {name = "Revive", code = "REVIVE", price = 6000},
    {name = "Treatment", code = "TREATMENT", price = 5000},
    {name = "Operasi", code = "OP", price = 20000},
    {name = "SKS", code = "SKS", price = 10000},
    {name = "BPJS", code = "BPJS", price = 40000},
    {name = "Farmasi - Paket A", code = "FARMASI_A", price = 6000},
    {name = "Farmasi - Paket B", code = "FARMASI_B", price = 15000},
    {name = "Farmasi - Paket C", code = "FARMASI_C", price = 45000},
}

-- Proximity Detection for Kantong
local proximityDetection = {
    nearbyPlayers = {},
    maxDistance = CONFIG.MAX_PROXIMITY_DISTANCE,
    updateInterval = 500,
    lastUpdate = 0
}

function proximityDetection:update()
    local currentTime = getGameTimer()
    if currentTime - self.lastUpdate < self.updateInterval then return end
    
    self.lastUpdate = currentTime
    self.nearbyPlayers = {}
    
    local myPlayer = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if not myPlayer or myPlayer == -1 then return end
    
    local myPos = getCharCoordinates(PLAYER_PED)
    if not myPos then return end
    
    for i = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(i) and i ~= myPlayer then
            local ped = sampGetCharHandleByPlayerId(i)
            if ped and doesCharExist(ped) then
                local playerPos = getCharCoordinates(ped)
                if playerPos then
                    local distance = math.sqrt(
                        (myPos.x - playerPos.x)^2 + 
                        (myPos.y - playerPos.y)^2 + 
                        (myPos.z - playerPos.z)^2
                    )
                    if distance <= self.maxDistance then
                        table.insert(self.nearbyPlayers, {
                            id = i,
                            name = sampGetPlayerNickname(i),
                            distance = distance,
                            x = playerPos.x,
                            y = playerPos.y,
                            z = playerPos.z
                        })
                    end
                end
            end
        end
    end
    
    table.sort(self.nearbyPlayers, function(a, b) return a.distance < b.distance end)
end

function proximityDetection:getNearest()
    self:update()
    if #self.nearbyPlayers > 0 then
        return self.nearbyPlayers[1]
    end
    return nil
end

function proximityDetection:getAll()
    self:update()
    return self.nearbyPlayers
end

-- ...existing code...
local state = {
    active = true,
    queue = {},
    triggers = {},
    invoiceManualSelected = false,
    selectedTargetId = nil,
    selectedTargetName = nil,
    selectedInvoiceType = nil
}

-- Core Functions
local function sendDelayedCommand(command, delay)
    table.insert(state.queue, {
        cmd = command,
        time = getGameTimer() + (delay or 1000)
    })
end

local function processQueue()
    if #state.queue == 0 then return end
    
    local currentTime = getGameTimer()
    for i = #state.queue, 1, -1 do
        if currentTime >= state.queue[i].time then
            sampSendChat(state.queue[i].cmd)
            table.remove(state.queue, i)
        end
    end
end

-- Execute invoice dengan tipe dan detail
local function executeInvoiceWithType(targetId, targetName, invoiceType)
    if not invoiceType then
        sampAddChatMessage(string.format("[%s] {FF0000}Pilih tipe invoice terlebih dahulu!", script_name), -1)
        return
    end
    
    local timing = CONFIG.RP_TIMING
    local invoiceName = string.format("%s %s", invoiceType.code, targetName:upper())
    
    sampAddChatMessage(string.format("[%s] {00FF00}Mulai invoice: %s | Harga: Rp %d", script_name, invoiceName, invoiceType.price), 0xFFFF00)
    
    -- Tablet prop sequence
    sendDelayedCommand("/eprop tablet", timing.PROP_TABLET)
    sendDelayedCommand("/me mengambil tablet dari tas tactical", timing.TAKE_TABLET)
    sendDelayedCommand("/me menyalakan layar tablet", timing.POWER_ON)
    sendDelayedCommand("/me mengetik data invoice di layar tablet", timing.TYPING)
    
    -- Show invoice details
    sendDelayedCommand("/do Layar tablet menampilkan: " .. invoiceName, timing.SHOW_FORM)
    sendDelayedCommand("/me menghampiri pasien sambil menunjukkan tablet", timing.APPROACH_PATIENT)
    sendDelayedCommand("/me Berikut invoice untuk " .. invoiceType.name:lower() .. " sebesar Rp " .. invoiceType.price, timing.EXPLAIN_INVOICE)
    sendDelayedCommand("/do Invoice atas nama: " .. invoiceName, timing.INVOICE_DETAILS)
    
    -- Cleanup
    sendDelayedCommand("/me mematikan layar tablet dan menyimpannya", timing.POWER_OFF)
    sendDelayedCommand("/e x", timing.CLOSE_PROP)
    
    sampAddChatMessage(string.format("[%s] {00FF00}Invoice sequence selesai!", script_name), 0x00FF00)
end

local function executeInvoiceRP()
    local timing = CONFIG.RP_TIMING
    
    sampAddChatMessage(string.format("[%s] Starting invoice RP sequence...", script_name), 0xFFFF00)
    
    -- Tablet prop sequence
    sendDelayedCommand("/eprop tablet", timing.PROP_TABLET)
    sendDelayedCommand("/me mengambil tablet dari tas tactical", timing.TAKE_TABLET)
    sendDelayedCommand("/me menyalakan layar tablet", timing.POWER_ON)
    sendDelayedCommand("/me mengetik data di layar tablet", timing.TYPING)
    
    -- Patient interaction
    sendDelayedCommand("/do Layar tablet menampilkan form invoice digital", timing.SHOW_FORM)
    sendDelayedCommand("/me menghampiri pasien sambil menunjukkan tablet", timing.APPROACH_PATIENT)
    sendDelayedCommand("/me Berikut invoice untuk treatment yang kami berikan", timing.EXPLAIN_INVOICE)
    sendDelayedCommand("/do Invoice berisi detail biaya treatment dan obat-obatan", timing.INVOICE_DETAILS)
    
    -- Cleanup
    sendDelayedCommand("/me mematikan layar tablet dan menyimpannya", timing.POWER_OFF)
    sendDelayedCommand("/e x", timing.CLOSE_PROP)
    
    sampAddChatMessage(string.format("[%s] Invoice RP sequence completed", script_name), 0x00FF00)
end

-- Trigger Management
local function setupTriggers()
    state.triggers = {
        {
            id = CONFIG.DIALOG_EMS_PANEL,
            keywords = {CONFIG.KEYWORD_INVOICE_MANUAL},
            callback = function()
                state.invoiceManualSelected = true
                sampAddChatMessage(string.format("[%s] Invoice manual detected, waiting for input dialog...", script_name), 0xFFFF00)
            end
        }
    }
    
    sampAddChatMessage(string.format("[%s] Triggers configured successfully", script_name), 0xFFFFFF)
end

local function handleDialogTrigger(dialogId, text)
    for _, trigger in ipairs(state.triggers) do
        if trigger.id == dialogId then
            local textLower = text:lower()
            for _, keyword in ipairs(trigger.keywords) do
                if textLower:find(keyword) then
                    trigger.callback()
                    return true
                end
            end
        end
    end
    return false
end

local function handleInvoiceInputDialog(dialogId, title)
    if not state.invoiceManualSelected then return false end
    if dialogId ~= CONFIG.DIALOG_INPUT then return false end
    if not title:find("Invoice") then return false end
    
    executeInvoiceRP()
    state.invoiceManualSelected = false
    return true
end

-- Event Handlers
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if not state.active then return end
    
    -- Handle EMS panel trigger
    if handleDialogTrigger(dialogId, text) then
        return
    end
    
    -- Handle invoice input dialog
    if handleInvoiceInputDialog(dialogId, title) then
        return
    end
    
    -- Reset state on unrelated dialogs
    if dialogId ~= CONFIG.DIALOG_EMS_PANEL and dialogId ~= CONFIG.DIALOG_INPUT then
        state.invoiceManualSelected = false
    end
end

-- Command Handlers
local function toggleSystem()
    state.active = not state.active
    local status = state.active and "{00FF00}Aktif" or "{FF0000}Nonaktif"
    sampAddChatMessage(string.format("[%s] System %s", script_name, status), -1)
end

-- Show nearby players in chat
local function showNearbyPlayers()
    proximityDetection:update()
    local nearbyList = proximityDetection:getAll()
    
    if #nearbyList == 0 then
        sampAddChatMessage(string.format("[%s] Tidak ada pemain terdekat dalam jarak %.1f meter", script_name, CONFIG.MAX_PROXIMITY_DISTANCE), 0xFFFF00)
        return
    end
    
    sampAddChatMessage(string.format("[%s] =================================", script_name), 0x00FF00)
    sampAddChatMessage(string.format("[%s] Pemain Terdekat dalam jarak %.1f meter:", script_name, CONFIG.MAX_PROXIMITY_DISTANCE), 0x00FF00)
    for idx, player in ipairs(nearbyList) do
        sampAddChatMessage(string.format("[%s] %d. %s (ID: %d) - %.2f meter", script_name, idx, player.name, player.id, player.distance), 0xFFFFFF)
    end
    sampAddChatMessage(string.format("[%s] =================================", script_name), 0x00FF00)
end

-- Show invoice types and select
local function showInvoiceMenu(targetId, targetName)
    if not targetName then
        sampAddChatMessage(string.format("[%s] {FF0000}Error: Target tidak valid!", script_name), -1)
        return
    end
    
    sampAddChatMessage(string.format("[%s] ======= INVOICE MENU (%s) =======", script_name, targetName), 0x00FF00)
    sampAddChatMessage(string.format("[%s] Pilih tipe invoice dengan command:", script_name), 0xFFFFFF)
    
    for idx, invoiceType in ipairs(INVOICE_TYPES) do
        sampAddChatMessage(string.format("[%s] /invoice %d - %s (Rp %d)", script_name, idx, invoiceType.name, invoiceType.price), 0xFFFFFF)
    end
    
    sampAddChatMessage(string.format("[%s] ===================================", script_name), 0x00FF00)
    
    state.selectedTargetId = targetId
    state.selectedTargetName = targetName
end

-- Select specific invoice
local function selectInvoice(invoiceIndex)
    if not state.selectedTargetId or not state.selectedTargetName then
        sampAddChatMessage(string.format("[%s] {FF0000}Error: Belum memilih target!", script_name), -1)
        return
    end
    
    local invoiceType = INVOICE_TYPES[invoiceIndex]
    if not invoiceType then
        sampAddChatMessage(string.format("[%s] {FF0000}Error: Tipe invoice tidak valid!", script_name), -1)
        return
    end
    
    state.selectedInvoiceType = invoiceType
    executeInvoiceWithType(state.selectedTargetId, state.selectedTargetName, invoiceType)
end

-- Command untuk buka invoice menu dengan ID
local function openInvoiceMenu(targetId)
    local targetId = tonumber(targetId)
    if not targetId then
        sampAddChatMessage(string.format("[%s] {FF0000}Gunakan: /invoicemenu [ID]", script_name), -1)
        return
    end
    
    if not sampIsPlayerConnected(targetId) then
        sampAddChatMessage(string.format("[%s] {FF0000}Player ID %d tidak tersambung!", script_name, targetId), -1)
        return
    end
    
    local targetName = sampGetPlayerNickname(targetId)
    showInvoiceMenu(targetId, targetName)
end

-- Initialization
function main()
    repeat wait(0) until isSampAvailable()
    
    -- Welcome messages
    sampAddChatMessage(string.format("[%s v%s] Loaded successfully!", script_name, script_version), 0x00FF00)
    sampAddChatMessage(string.format("[%s] Use /invoicetoggle to enable/disable", script_name), 0xFFFFFF)
    sampAddChatMessage(string.format("[%s] Use /kantong to show nearby players", script_name), 0xFFFFFF)
    sampAddChatMessage(string.format("[%s] Use /invoicemenu [ID] to open invoice menu", script_name), 0xFFFFFF)
    sampAddChatMessage(string.format("[%s] Use /invoice [1-8] to select invoice type", script_name), 0xFFFFFF)
    
    -- Register commands
    sampRegisterChatCommand("invoicetoggle", toggleSystem)
    sampRegisterChatCommand("kantong", showNearbyPlayers)
    sampRegisterChatCommand("invoicemenu", function(arg) openInvoiceMenu(arg) end)
    sampRegisterChatCommand("invoice", function(arg) selectInvoice(tonumber(arg)) end)
    
    -- Setup system
    setupTriggers()
    
    -- Main loop
    while true do
        wait(50)
        processQueue()
    end
end