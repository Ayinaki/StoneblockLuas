local mon = peripheral.find("monitor")
local modem = peripheral.find("modem")

if not mon then print("Error: No monitor!") return end
if not modem then print("Error: No modem!") return end

mon.setTextScale(1)

-- PAGE STATE TRACKING
-- "MAIN" shows the list of machines. A machine name shows that machine's blocks.
local currentPage = "MAIN" 

-- MASTER DATABASE OF ALL UNEARTHER MACHINES
-- You can add infinitely many machines and blocks here without rewriting the UI code!
local network = {
    {
        machineName = "Archaeologist",
        blocks = {
            { name = "Dirt Mode",  channel = 101, active = false, info = "Saplings, Pebbles, Seeds" },
            { name = "Sand Mode",  channel = 102, active = false, info = "Clay, Cu, Ag, Ni, Uranium" },
            { name = "Dust Mode",  channel = 103, active = false, info = "Redstone, Au, Sn, Bonemeal" }
        }
    },
    {
        machineName = "Miner (Future)",
        blocks = {
            { name = "Stone Mode", channel = 104, active = false, info = "Coal, Iron, Diamonds" },
            { name = "Deepslate",  channel = 105, active = false, info = "Redstone, Lapis, Netheite" }
        }
    }
}

-- Bounding box memory for clicking
local hitboxes = {}

local function registerHitbox(x1, x2, y1, y2, callback)
    table.insert(hitboxes, { x1 = x1, x2 = x2, y1 = y1, y2 = y2, callback = callback })
end

-- Draw a custom styled button
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

-- RENDER: THE MAIN MACHINE SELECTION MENU
local function drawMainPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {} -- Reset click areas
    
    local w, _ = mon.getSize()
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(math.floor((w - 18) / 2) + 1, 1)
    mon.write("SELECT AN UNEARTHER")
    
    local currentY = 3
    for _, mach in ipairs(network) do
        local btnWidth = 26
        local startX = math.floor((w - btnWidth) / 2) + 1
        
        drawButton(startX, currentY, btnWidth, 3, mach.machineName, colors.blue, colors.white)
        
        -- Map click to open this specific machine's page
        registerHitbox(startX, startX + btnWidth - 1, currentY, currentY + 2, function()
            currentPage = mach.machineName
        end)
        
        currentY = currentY + 4
    end
end

-- RENDER: A SPECIFIC MACHINE'S CONTROL SUB-MENU
local function drawSubPage(machName)
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    
    local w, _ = mon.getSize()
    
    -- Draw Back Button
    drawButton(2, 1, 6, 1, "< BACK", colors.gray, colors.white)
    registerHitbox(2, 7, 1, 1, function() currentPage = "MAIN" end)
    
    -- Title
    mon.setTextColor(colors.cyan)
    mon.setCursorPos(10, 1)
    mon.write(machName:upper() .. " CONTROLS")
    
    -- Find the machine data block
    local selectedMach = nil
    for _, m in ipairs(network) do
        if m.machineName == machName then selectedMach = m break end
    end
    
    if not selectedMach then return end
    
    -- Draw all the block options for this specific machine
    local currentY = 3
    for _, block in ipairs(selectedMach.blocks) do
        local btnWidth = 14
        local btnColor = block.active and colors.green or colors.red
        
        -- Interactive toggle box
        drawButton(2, currentY, btnWidth, 3, block.name, btnColor, colors.white)
        
        -- Tooltip descriptions on the right showing what it drops!
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.lightGray)
        mon.setCursorPos(18, currentY + 1)
        mon.write(block.info)
        
        -- Register click to fire the wireless modem
        registerHitbox(2, 2 + btnWidth - 1, currentY, currentY + 2, function()
            block.active = not block.active
            local signal = block.active and "ON" or "OFF"
            modem.transmit(block.channel, block.channel, signal)
        end)
        
        currentY = currentY + 4
    end
end

-- Master Master Redraw logic
local function render()
    if currentPage == "MAIN" then
        drawMainPage()
    else
        drawSubPage(currentPage)
    end
end

render()

-- Main Event Click Handler
while true do
    local event, targetDevice, x, y = os.pullEvent("monitor_touch")
    
    if targetDevice == peripheral.getName(mon) then
        -- Run through registered hitboxes on the current active view
        for _, box in ipairs(hitboxes) do
            if x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2 then
                box.callback() -- Execute the menu navigation or wireless toggle
                render() -- Instantly redraw the new visual state
                break
            end
        end
    end
end
