local mon = peripheral.find("monitor")
local modem = peripheral.find("modem")
local speaker = peripheral.find("speaker")

if not mon then print("Error: No monitor!") return end
if not modem then print("Error: No modem!") return end

mon.setTextScale(1)
mon.clear()

-- ==========================================
-- PALETTE
-- ==========================================
if mon.isColor() then
    mon.setPaletteColor(colors.orange,    0xD97706)
    mon.setPaletteColor(colors.gray,      0x4B5563)
    mon.setPaletteColor(colors.purple,    0x7C3AED)
    mon.setPaletteColor(colors.lightGray, 0x9CA3AF)
    mon.setPaletteColor(colors.red,       0xEF4444)
    mon.setPaletteColor(colors.lime,      0x10B981)
    mon.setPaletteColor(colors.cyan,      0x06B6D4)
    mon.setPaletteColor(colors.yellow,    0xFBBF24)
end

-- MASTER DATABASE
local network = {
    {
        machineName = "Archaeologist",
        themeColor = colors.orange,
        icon = "\4",
        chestPercent = 0,
        blocks = {
            { name = "Dirt Mode",  channel = 101, active = false, info1 = "Magic Saplings, Pebbles,", info2 = "Seeds" },
            { name = "Sand Mode",  channel = 102, active = false, info1 = "Clay, Copper, Silver,",    info2 = "Nickel, Uranium" },
            { name = "Dust Mode",  channel = 103, active = false, info1 = "Redstone, Gold, Tin,",     info2 = "Bonemeal" }
        }
    },
    {
        machineName = "Geologist",
        themeColor = colors.gray,
        icon = "\5",
        warning = "SOULSAND REQUIRES MANUAL INPUT!",
        chestPercent = 0,
        blocks = {
            { name = "Gravel Mode",   channel = 104, active = false, info1 = "Coal, Diamond, Emerald, Lapis,", info2 = "Iron, Zinc, Lead, Aluminum" },
            { name = "Cobble Mode",   channel = 105, active = false, info1 = "Stoneium",                       info2 = "" },
            { name = "SoulSand Mode", channel = 106, active = false, info1 = "Nether Quartz, Black Quartz,",   info2 = "Glowstone Dust" }
        }
    },
    {
        machineName = "Dimensionalist",
        themeColor = colors.purple,
        icon = "\7",
        warning = "MANUAL REFILL REQUIRED!",
        chestPercent = 0,
        blocks = {
            { name = "Otherrock",  channel = 107, active = false, info1 = "Replica,",                    info2 = "Certus Quartz Dust" },
            { name = "Netherrack", channel = 108, active = false, info1 = "Sulfur, Blaze Powder, Iesnium,", info2 = "Netherite Scrap" },
            { name = "End Stone",  channel = 109, active = false, info1 = "Fluorite, Platinum,",         info2 = "Draconium, Dim Shard" }
        }
    }
}

local currentPage = "MAIN"
local hitboxes = {}
local SAVE_FILE = "/button_states.txt"

for _, mach in ipairs(network) do
    for _, block in ipairs(mach.blocks) do
        modem.open(block.channel)
    end
end

-- ==========================================
-- AUDIO ENGINE
-- ==========================================
local function playSound(soundType)
    if not speaker then return end
    pcall(function()
        if soundType == "click" then
            speaker.playNote("harp", 1.0, 12)
        elseif soundType == "nav" then
            speaker.playNote("chime", 0.7, 10)
        elseif soundType == "boot" then
            speaker.playNote("bass", 0.8, 4)
            os.sleep(0.1)
            speaker.playNote("bass", 0.8, 9)
            os.sleep(0.1)
            speaker.playNote("bass", 0.8, 14)
        elseif soundType == "warning" then
            for i = 1, 3 do
                speaker.playNote("pling", 1.0, 1)
                os.sleep(0.05)
            end
        end
    end)
end

local function runBootAnimation()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local w, h = mon.getSize()
    playSound("boot")
    for line = 1, h do
        mon.setTextColor(colors.lime)
        mon.setCursorPos(math.random(1, w), line)
        mon.write("#")
        if line == math.floor(h / 2) then
            local msg = " FACTORY OS v2.0 "
            local mx = math.max(1, math.floor((w - #msg) / 2) + 1)
            mon.setCursorPos(mx, line)
            mon.setBackgroundColor(colors.lime)
            mon.setTextColor(colors.black)
            mon.write(msg)
            mon.setBackgroundColor(colors.black)
        end
        os.sleep(0.04)
    end
    os.sleep(0.1)
end

-- ==========================================
-- PERSISTENCE ENGINE
-- ==========================================
local function saveStates()
    local file = fs.open(SAVE_FILE, "w")
    for _, mach in ipairs(network) do
        for _, block in ipairs(mach.blocks) do
            file.writeLine(block.channel .. ":" .. tostring(block.active))
        end
    end
    file.close()
end

local function loadStates()
    if not fs.exists(SAVE_FILE) then return end
    print("Syncing network modems...")
    os.sleep(1)
    local file = fs.open(SAVE_FILE, "r")
    local line = file.readLine()
    while line do
        local parts = {}
        for match in string.gmatch(line, "[^:]+") do table.insert(parts, match) end
        local channel = tonumber(parts[1])
        local active = (parts[2] == "true")
        for _, mach in ipairs(network) do
            for _, block in ipairs(mach.blocks) do
                if block.channel == channel then
                    block.active = active
                    modem.transmit(channel, channel, active and "ON" or "OFF")
                end
            end
        end
        line = file.readLine()
    end
    file.close()
end

-- ==========================================
-- DRAWING HELPERS
-- ==========================================
local function registerHitbox(x1, x2, y1, y2, callback)
    table.insert(hitboxes, { x1=x1, x2=x2, y1=y1, y2=y2, callback=callback })
end

local function fill(x, y, width, height, bg)
    mon.setBackgroundColor(bg)
    for i = 0, height - 1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
end

local function writeAt(x, y, text, fg, bg)
    mon.setCursorPos(x, y)
    if bg then mon.setBackgroundColor(bg) end
    if fg then mon.setTextColor(fg) end
    mon.write(text)
end

local function drawButton(x, y, width, height, text, mainColor, textColor, hasShadow)
    if hasShadow then
        fill(x + 1, y + 1, width, height, colors.black)
    end
    fill(x, y, width, height, mainColor)
    local tx = x + math.max(0, math.floor((width - #text) / 2))
    local ty = y + math.floor(height / 2)
    writeAt(tx, ty, text, textColor, mainColor)
    -- restore
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
end

-- Solid colour-block progress bar — no special characters
local function drawProgressBar(x, y, width, percent)
    local filled = math.floor((percent / 100) * width)
    local empty  = width - filled
    local barColor
    if percent >= 85 then barColor = colors.red
    elseif percent >= 60 then barColor = colors.orange
    else barColor = colors.lime end

    mon.setCursorPos(x, y)
    mon.setBackgroundColor(barColor)
    mon.setTextColor(colors.black)
    if filled > 0 then mon.write(string.rep(" ", filled)) end
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.white)
    if empty > 0 then mon.write(string.rep(" ", empty)) end
    -- percent label
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(barColor)
    mon.write(" " .. tostring(math.floor(percent)) .. "%")
    -- restore
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
end

-- ==========================================
-- MAIN PAGE
-- ==========================================
local function drawMainPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    local w, h = mon.getSize()

    -- Two-tone header: dark side strips + bright centre title
    fill(1, 1, w, 2, colors.gray)
    local title = "FACTORY NETWORK"
    local tx = math.max(1, math.floor((w - #title) / 2) + 1)
    -- accent bar on row 1
    fill(1, 1, w, 1, colors.lightGray)
    writeAt(tx - 2, 1, "\x10 " .. title .. " \x11", colors.black, colors.lightGray)
    -- subtitle bar on row 2
    writeAt(math.max(1, math.floor((w - 18) / 2) + 1), 2, "UNEARTHING CONTROL", colors.gray, colors.black)

    local currentY = 4
    for i, mach in ipairs(network) do
        local btnWidth = math.min(26, w - 2)
        local startX = math.max(1, math.floor((w - btnWidth) / 2) + 1)

        drawButton(startX, currentY, btnWidth, 3, (mach.icon or "\7") .. " " .. mach.machineName:upper(), mach.themeColor, colors.white, true)

        -- connector dot between buttons
        if i < #network then
            writeAt(math.floor(w / 2), currentY + 3, "+", colors.lightGray, colors.black)
        end

        local capturedMach = mach
        registerHitbox(startX, startX + btnWidth - 1, currentY, currentY + 2, function()
            playSound("nav")
            currentPage = capturedMach.machineName
        end)
        currentY = currentY + 4
    end
end

-- ==========================================
-- SUB PAGE
-- ==========================================
local function drawSubPage(machName)
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    local w, h = mon.getSize()

    local selectedMach = nil
    for _, m in ipairs(network) do
        if m.machineName == machName then selectedMach = m break end
    end
    if not selectedMach then return end

    local tc = selectedMach.themeColor

    -- Header: full-width theme colour bar
    fill(1, 1, w, 1, tc)

    -- BACK button
    drawButton(1, 1, 6, 1, "BACK", colors.lightGray, colors.black, false)
    registerHitbox(1, 6, 1, 1, function()
        playSound("nav")
        currentPage = "MAIN"
    end)

    -- Title
    mon.setBackgroundColor(tc)
    mon.setTextColor(colors.white)
    local controlTitle = (selectedMach.icon or "\7") .. " " .. selectedMach.machineName:upper() .. " CONTROL"
    writeAt(8, 1, controlTitle, colors.white, tc)

    -- Progress bar (right side, safe positioning)
    local barWidth = 7
    local barX = w - barWidth - 4
    if barX > 8 + #controlTitle + 1 then
        drawProgressBar(barX, 1, barWidth, selectedMach.chestPercent)
    end

    -- Thin accent divider under header
    fill(1, 2, w, 1, colors.black)
    mon.setBackgroundColor(tc)
    mon.setTextColor(colors.black)
    mon.setCursorPos(1, 2)
    mon.write(string.rep("\140", w))  -- \140 = horizontal line char in CC font
    mon.setBackgroundColor(colors.black)

    local currentY = 4
    if selectedMach.warning then
        -- Warning banner with background highlight
        fill(1, 3, w, 1, colors.red)
        local warnText = "\7 " .. selectedMach.warning .. " \7"
        local wx = math.max(1, math.floor((w - #warnText) / 2) + 1)
        writeAt(wx, 3, warnText, colors.white, colors.red)
        mon.setBackgroundColor(colors.black)
        currentY = 5
    end

    for _, block in ipairs(selectedMach.blocks) do
        local btnColor     = block.active and colors.lime or colors.red
        local btnTextColor = block.active and colors.black or colors.white
        local statusIcon   = block.active and "\4" or "\7"
        local displayLabel = statusIcon .. " " .. (block.active and "ACTIVE" or "OFFLINE")

        drawButton(2, currentY, 14, 3, displayLabel, btnColor, btnTextColor, true)

        -- Coloured left gutter strip for info section
        fill(17, currentY, 1, 3, tc)

        -- Info text
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(tc)
        writeAt(19, currentY, block.name:upper(), tc, colors.black)
        mon.setTextColor(colors.lightGray)
        writeAt(19, currentY + 1, block.info1, colors.lightGray, colors.black)
        writeAt(19, currentY + 2, block.info2, colors.lightGray, colors.black)

        -- Capture for closure
        local capturedBlock = block
        local capturedMach  = selectedMach
        registerHitbox(2, 15, currentY, currentY + 2, function()
            playSound("click")
            if not capturedBlock.active then
                for _, b in ipairs(capturedMach.blocks) do
                    if b.active then
                        b.active = false
                        modem.transmit(b.channel, b.channel, "OFF")
                    end
                end
                capturedBlock.active = true
                modem.transmit(capturedBlock.channel, capturedBlock.channel, "ON")
            else
                capturedBlock.active = false
                modem.transmit(capturedBlock.channel, capturedBlock.channel, "OFF")
            end
            saveStates()
        end)
        currentY = currentY + 4
    end
end

local function render()
    if currentPage == "MAIN" then drawMainPage() else drawSubPage(currentPage) end
end

-- Init
runBootAnimation()
loadStates()
render()

-- ==========================================
-- MAIN EVENT LOOP
-- ==========================================
while true do
    local event, p1, p2, p3, p4 = os.pullEvent()

    if event == "monitor_touch" and p1 == peripheral.getName(mon) then
        local x, y = p2, p3
        for _, box in ipairs(hitboxes) do
            if x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2 then
                box.callback()
                render()
                break
            end
        end

    elseif event == "modem_message" then
        local listenChannel = p2
        local message = p4

        if message == "CHEST_FULL" then
            for _, mach in ipairs(network) do
                for _, block in ipairs(mach.blocks) do
                    if block.channel == listenChannel and block.active then
                        block.active = false
                        mach.chestPercent = 100
                        playSound("warning")
                        saveStates()
                        render()
                    end
                end
            end

        elseif type(message) == "string" and string.sub(message, 1, 13) == "CHEST_STATUS:" then
            local parts = {}
            for match in string.gmatch(message, "[^:]+") do table.insert(parts, match) end
            local targetName  = parts[2]
            local incomingPct = tonumber(parts[3]) or 0
            for _, mach in ipairs(network) do
                if mach.machineName == targetName then
                    if mach.chestPercent ~= incomingPct then
                        mach.chestPercent = incomingPct
                        render()
                    end
                    break
                end
            end
        end
    end
end
