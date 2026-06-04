local mon = peripheral.find("monitor")
local modem = peripheral.find("modem")
local speaker = peripheral.find("speaker")

if not mon then print("Error: No monitor!") return end
if not modem then print("Error: No modem!") return end

mon.setTextScale(1)
mon.clear()

-- MASTER DATABASE
local network = {
    {
        machineName = "Archaeologist",
        themeColor = colors.orange,
        chestPercent = 0, 
        blocks = {
            { name = "Dirt Mode",  channel = 101, active = false, info1 = "Magic Saplings, Pebbles,", info2 = "Seeds" },
            { name = "Sand Mode",  channel = 102, active = false, info1 = "Clay, Copper, Silver,", info2 = "Nickel, Uranium" },
            { name = "Dust Mode",  channel = 103, active = false, info1 = "Redstone, Gold, Tin,",  info2 = "Bonemeal" }
        }
    },
    {
        machineName = "Geologist (WIP)",
        themeColor = colors.gray,
        chestPercent = 0,
        blocks = {
            { name = "Gravel Mode", channel = 104, active = false, info1 = "Coal, Diamond, Emerald, Lapis, Osmium,", info2 = "Iron, Zinc, Lead, Aluminum" },
            { name = "Cobble Mode", channel = 105, active = false, info1 = "Stoneium", info2 = "" }
        }
    },
    {
        machineName = "Dimensional (WIP)",
        themeColor = colors.purple,
        warning = "MANUAL REFILL REQUIRED!",
        chestPercent = 0,
        blocks = {
            { name = "Otherrock",   channel = 106, active = false, info1 = "Replica,", info2 = "Certus Quartz Dust" },
            { name = "Netherrack",  channel = 107, active = false, info1 = "Sulfur, Blaze Powder, Iesnium,", info2 = "Netherite Scrap" },
            { name = "End Stone",   channel = 108, active = false, info1 = "Fluorite, Platinum,", info2 = "Draconium, Dim Shard" }
        }
    }
}

local currentPage = "MAIN" 
local hitboxes = {}
local SAVE_FILE = "/button_states.txt"

-- Open channels
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
            os.sleep(0.12)
            speaker.playNote("bass", 0.8, 8)
            os.sleep(0.12)
            speaker.playNote("bass", 0.8, 12)
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
        mon.setTextColor(colors.green)
        mon.setCursorPos(math.random(1, w), line)
        mon.write(string.char(math.random(33, 126)))
        if line == math.floor(h/2) then
            mon.setCursorPos(math.floor((w - 18)/2), line)
            mon.setBackgroundColor(colors.gray)
            mon.setTextColor(colors.yellow)
            mon.write(" NET-OS BOOTING... ")
            mon.setBackgroundColor(colors.black)
        end
        os.sleep(0.05)
    end
    os.sleep(0.2)
end
-- ==========================================

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
    print("Waking up modems...")
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
                    local signal = active and "ON" or "OFF"
                    modem.transmit(channel, channel, signal)
                end
            end
        end
        line = file.readLine()
    end
    file.close()
end
-- ==========================================

local function registerHitbox(x1, x2, y1, y2, callback)
    table.insert(hitboxes, { x1 = x1, x2 = x2, y1 = y1, y2 = y2, callback = callback })
end

local function drawSleekButton(x, y, width, height, text, mainColor, textColor, hasShadow)
    if hasShadow then
        mon.setBackgroundColor(colors.black)
        for i = 1, height do
            mon.setCursorPos(x + 1, y + i)
            mon.write(string.rep(" ", width))
        end
    end
    mon.setBackgroundColor(mainColor)
    mon.setTextColor(textColor)
    for i = 0, height - 1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
    mon.setCursorPos(x + math.floor((width - #text) / 2), y + math.floor(height / 2))
    mon.write(text)
end

local function drawMainPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    local w, h = mon.getSize()
    
    mon.setBackgroundColor(colors.gray)
    mon.setCursorPos(1, 1)
    mon.write(string.rep(" ", w))
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(math.floor((w - 22) / 2) + 1, 1)
    mon.write("« STONEBLOCK NETWORK »")
    
    local currentY = 3
    for _, mach in ipairs(network) do
        local btnWidth = 26
        local startX = math.floor((w - btnWidth) / 2) + 1
        drawSleekButton(startX, currentY, btnWidth, 3, mach.machineName, mach.themeColor, colors.white, true)
        
        registerHitbox(startX, startX + btnWidth - 1, currentY, currentY + 2, function()
            playSound("nav")
            currentPage = mach.machineName
        end)
        currentY = currentY + 4
    end
end

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
    
    mon.setBackgroundColor(selectedMach.themeColor)
    mon.setCursorPos(1, 1)
    mon.write(string.rep(" ", w))
    
    drawSleekButton(1, 1, 8, 1, " [BACK] ", colors.lightGray, colors.black, false)
    registerHitbox(1, 8, 1, 1, function() 
        playSound("nav")
        currentPage = "MAIN" 
    end)
    
    mon.setTextColor(colors.white)
    local titleText = selectedMach.machineName:upper()
    mon.setCursorPos(11, 1)
    mon.write(titleText)
    
    -- Live Chest Capacity Display
    mon.setCursorPos(w - 14, 1)
    local pct = selectedMach.chestPercent
    if pct >= 85 then mon.setTextColor(colors.red)
    elseif pct >= 60 then mon.setTextColor(colors.orange)
    else mon.setTextColor(colors.lime) end
    mon.write(string.format("CHEST: %3d%%", pct))
    
    local currentY = 4
    if selectedMach.warning then
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.red)
        mon.setCursorPos(math.floor((w - #selectedMach.warning) / 2) + 1, 3)
        mon.write("!! " .. selectedMach.warning .. " !!")
        currentY = 4
    end
    
    for _, block in ipairs(selectedMach.blocks) do
        local btnWidth = 14
        local btnColor = block.active and colors.lime or colors.red
        local textColor = block.active and colors.black or colors.white
        
        drawSleekButton(2, currentY, btnWidth, 3, block.name, btnColor, textColor, true)
        mon.setBackgroundColor(colors.black)
        
        if block.active then
            mon.setTextColor(colors.lime)
            mon.setCursorPos(18, currentY)
            mon.write("[ ONLINE ]")
        else
            mon.setTextColor(colors.lightGray)
            mon.setCursorPos(18, currentY)
            mon.write("[ OFFLINE ]")
        end
        
        mon.setTextColor(colors.gray)
        mon.setCursorPos(18, currentY + 1)
        mon.write(block.info1)
        mon.setCursorPos(18, currentY + 2)
        mon.write(block.info2)
        
        registerHitbox(2, 2 + btnWidth - 1, currentY, currentY + 2, function()
            playSound("click")
            if not block.active then
                for _, b in ipairs(selectedMach.blocks) do
                    if b.active then
                        b.active = false
                        modem.transmit(b.channel, b.channel, "OFF")
                    end
                end
                block.active = true
                modem.transmit(block.channel, block.channel, "ON")
            else
                block.active = false
                modem.transmit(block.channel, block.channel, "OFF")
            end
            saveStates()
        end)
        currentY = currentY + 4
    end
end

local function render()
    if currentPage == "MAIN" then drawMainPage() else drawSubPage(currentPage) end
end

-- Initialization
runBootAnimation()
loadStates()
render()

-- ==========================================
-- MAIN SYSTEM EVENT HANDLER
-- ==========================================
while true do
    local event, p1, p2, p3, p4, p5 = os.pullEvent()
    
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
        local listenChannel, senderChannel, message = p1, p2, p3 -- Adjusted event parsing safely
        
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
            
        -- Robust String Parsing for Named Chest Metric Logs
        elseif type(message) == "string" and string.sub(message, 1, 13) == "CHEST_STATUS:" then
            -- Slice out name and percent value
            local parts = {}
            for match in string.gmatch(message, "[^:]+") do
                table.insert(parts, match)
            end
            
            local targetName = parts[2]
            local incomingPct = tonumber(parts[3]) or 0
            
            -- Match directly against the precise machine name string!
            for _, mach in ipairs(network) do
                if mach.machineName == targetName then
                    if mach.chestPercent ~= incomingPct then
                        mach.chestPercent = incomingPct
                        render() -- Instant visual push update!
                    end
                    break
                end
            end
        end
    end
end
