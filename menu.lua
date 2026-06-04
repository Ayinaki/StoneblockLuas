local mon = peripheral.find("monitor")
local modem = peripheral.find("modem")

if not mon then print("Error: No monitor!") return end
if not modem then print("Error: No modem!") return end

mon.setTextScale(1)
mon.clear()

-- MASTER DATABASE WITH COLOR THEMES
local network = {
    {
        machineName = "Archaeologist",
        themeColor = colors.orange,
        blocks = {
            { name = "Dirt Mode",  channel = 101, active = false, info1 = "Magic Saplings, Pebbles,", info2 = "Seeds" },
            { name = "Sand Mode",  channel = 102, active = false, info1 = "Clay, Copper, Silver,", info2 = "Nickel, Uranium" },
            { name = "Dust Mode",  channel = 103, active = false, info1 = "Redstone, Gold, Tin,",  info2 = "Bonemeal" }
        }
    },
    {
        machineName = "Geologist (WIP)",
        themeColor = colors.gray,
        blocks = {
            { name = "Gravel Mode", channel = 104, active = false, info1 = "Coal, Diamond, Emerald, Lapis, Osmium,", info2 = "Iron, Zinc, Lead, Aluminum" },
            { name = "Cobble Mode", channel = 105, active = false, info1 = "Stoneium", info2 = "" }
        }
    },
    {
        machineName = "Dimensional (WIP)",
        themeColor = colors.purple,
        warning = "MANUAL REFILL REQUIRED!",
        blocks = {
            { name = "Otherrock",   channel = 106, active = false, info1 = "Replica,", info2 = "Certus Quartz Dust" },
            { name = "Netherrack",  channel = 107, active = false, info1 = "Sulfur, Blaze Powder, Iesnium,", info2 = "Netherite Scrap" },
            { name = "End Stone",   channel = 108, active = false, info1 = "Fluorite, Platinum,", info2 = "Draconium, Dim Shard" }
        }
    }
}

local currentPage = "MAIN" 
local hitboxes = {}

-- ==========================================
-- PERSISTENCE ENGINE
-- ==========================================
local SAVE_FILE = "/button_states.txt"

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
    os.sleep(2) 
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

-- ADVANCED DRAWING HELPER: Draws buttons with drop shadows
local function drawSleekButton(x, y, width, height, text, mainColor, textColor, hasShadow)
    if hasShadow then
        -- Draw black/dark shadow offset down and right
        mon.setBackgroundColor(colors.black)
        for i = 1, height do
            mon.setCursorPos(x + 1, y + i)
            mon.write(string.rep(" ", width))
        end
    end

    -- Draw Main Button Face
    mon.setBackgroundColor(mainColor)
    mon.setTextColor(textColor)
    for i = 0, height - 1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
    
    -- Center Text Vertically and Horizontally
    mon.setCursorPos(x + math.floor((width - #text) / 2), y + math.floor(height / 2))
    mon.write(text)
end

-- RENDER: MAIN PAGE
local function drawMainPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    
    local w, h = mon.getSize()
    
    -- Header Bar
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
        
        -- Use the machine's custom theme color for its main menu button
        drawSleekButton(startX, currentY, btnWidth, 3, mach.machineName, mach.themeColor, colors.white, true)
        
        registerHitbox(startX, startX + btnWidth - 1, currentY, currentY + 2, function()
            currentPage = mach.machineName
        end)
        
        currentY = currentY + 4
    end
end

-- RENDER: SUB PAGES
local function drawSubPage(machName)
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    
    local w, h = mon.getSize()
    
    -- Find the active machine dataset
    local selectedMach = nil
    for _, m in ipairs(network) do
        if m.machineName == machName then selectedMach = m break end
    end
    if not selectedMach then return end
    
    -- High Tech Header Bar styled in the machine's theme color
    mon.setBackgroundColor(selectedMach.themeColor)
    mon.setCursorPos(1, 1)
    mon.write(string.rep(" ", w))
    
    -- Back Button inside Header
    drawSleekButton(1, 1, 8, 1, " [BACK] ", colors.lightGray, colors.black, false)
    registerHitbox(1, 8, 1, 1, function() currentPage = "MAIN" end)
    
    -- Title Text centered in header bar
    mon.setTextColor(colors.white)
    local titleText = selectedMach.machineName:upper() .. " SYSTEM"
    mon.setCursorPos(math.floor((w - #titleText) / 2) + 4, 1)
    mon.write(titleText)
    
    -- If it requires manual refills, show a flashing-style notice banner
    local currentY = 3
    if selectedMach.warning then
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.red)
        mon.setCursorPos(math.floor((w - #selectedMach.warning) / 2) + 1, 3)
        mon.write("!! " .. selectedMach.warning .. " !!")
        currentY = 4
    end
    
    -- Draw Sub-buttons
    for _, block in ipairs(selectedMach.blocks) do
        local btnWidth = 14
        -- Premium neon-tinted active/inactive colors instead of raw green/red
        local btnColor = block.active and colors.lime or colors.red
        local textColor = block.active and colors.black or colors.white
        
        drawSleekButton(2, currentY, btnWidth, 3, block.name, btnColor, textColor, true)
        
        -- Text Display Area (Sleeker spacing & formatting)
        mon.setBackgroundColor(colors.black)
        
        -- Clean Digital Readout Status String
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
            block.active = not block.active
            local signal = block.active and "ON" or "OFF"
            modem.transmit(block.channel, block.channel, signal)
            saveStates()
        end)
        
        currentY = currentY + 4
    end
end

local function render()
    if currentPage == "MAIN" then
        drawMainPage()
    else
        drawSubPage(currentPage)
    end
end

loadStates()
render()

while true do
    local event, targetDevice, x, y = os.pullEvent("monitor_touch")
    
    if targetDevice == peripheral.getName(mon) then
        for _, box in ipairs(hitboxes) do
            if x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2 then
                box.callback()
                render()
                break
            end
        end
    end
end
