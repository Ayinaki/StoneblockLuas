local mon = peripheral.find("monitor")
local modem = peripheral.find("modem")

if not mon then print("Error: No monitor!") return end
if not modem then print("Error: No modem!") return end

mon.setTextScale(1)
mon.clear()

-- MASTER DATABASE
local network = {
    {
        machineName = "Archaeologist",
        blocks = {
            { name = "Dirt Mode",  channel = 101, active = false, info1 = "Magic Saplings, Pebbles,", info2 = "Seeds" },
            { name = "Sand Mode",  channel = 102, active = false, info1 = "Clay, Copper, Silver,", info2 = "Nickel, Uranium" },
            { name = "Dust Mode",  channel = 103, active = false, info1 = "Redstone, Gold, Tin,",  info2 = "Bonemeal" }
        }
    },
    {
        machineName = "Miner (Future)",
        blocks = {
            { name = "Stone Mode", channel = 104, active = false, info1 = "Coal, Iron, Diamonds", info2 = "" },
            { name = "Deepslate",  channel = 105, active = false, info1 = "Redstone, Lapis,",      info2 = "Netherite" }
        }
    }
}

local currentPage = "MAIN" 
local hitboxes = {}

-- ==========================================
-- FIXED PERSISTENCE ENGINE (With Absolute Paths)
-- ==========================================
local SAVE_FILE = "/button_states.txt" -- Added forward slash to force root directory

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
    if not fs.exists(SAVE_FILE) then 
        print("No save file found yet. Creating fresh states.")
        return 
    end
    
    -- Give modems 2 seconds to connect to the network before blasting signals
    print("Waking up modems...")
    os.sleep(2) 
    
    local file = fs.open(SAVE_FILE, "r")
    local line = file.readLine()
    
    while line do
        local parts = {}
        for match in string.gmatch(line, "[^:]+") do
            table.insert(parts, match)
        end
        
        local channel = tonumber(parts[1])
        local active = (parts[2] == "true")
        
        for _, mach in ipairs(network) do
            for _, block in ipairs(mach.blocks) do
                if block.channel == channel then
                    block.active = active
                    local signal = active and "ON" or "OFF"
                    modem.transmit(channel, channel, signal)
                    print("Restored channel " .. channel .. " to " .. tostring(active))
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

local function drawButton(x, y, width, height, text, bgCol, textCol)
    mon.setBackgroundColor(bgCol)
    mon.setTextColor(textCol)
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
    
    local w, _ = mon.getSize()
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(math.floor((w - 18) / 2) + 1, 1)
    mon.write("SELECT AN UNEARTHER")
    
    local currentY = 3
    for _, mach in ipairs(network) do
        local btnWidth = 26
        local startX = math.floor((w - btnWidth) / 2) + 1
        
        drawButton(startX, currentY, btnWidth, 3, mach.machineName, colors.blue, colors.white)
        registerHitbox(startX, startX + btnWidth - 1, currentY, currentY + 2, function()
            currentPage = mach.machineName
        end)
        
        currentY = currentY + 4
    end
end

local function drawSubPage(machName)
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    
    local w, _ = mon.getSize()
    
    drawButton(2, 1, 6, 1, "< BACK", colors.gray, colors.white)
    registerHitbox(2, 7, 1, 1, function() currentPage = "MAIN" end)
    
    mon.setTextColor(colors.cyan)
    mon.setCursorPos(10, 1)
    mon.write(machName:upper() .. " CONTROLS")
    
    local selectedMach = nil
    for _, m in ipairs(network) do
        if m.machineName == machName then selectedMach = m break end
    end
    
    if not selectedMach then return end
    
    local currentY = 3
    for _, block in ipairs(selectedMach.blocks) do
        local btnWidth = 14
        local btnColor = block.active and colors.green or colors.red
        
        drawButton(2, currentY, btnWidth, 3, block.name, btnColor, colors.white)
        
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.lightGray)
        mon.setCursorPos(18, currentY + 0)
        mon.write(block.info1)
        mon.setCursorPos(18, currentY + 1)
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

-- LOAD AND TRANSMIT BACKED UP SIGNALS
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
