local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then print("Error: No monitor found!") return end

mon.setTextScale(1)
mon.clear()

-- ==========================================
-- HIGH-TECH INDUSTRIAL PALETTE
-- ==========================================
if mon.isColor() then
    mon.setPaletteColor(colors.gray,      0x0F172A) -- Deep Charcoal Canvas
    mon.setPaletteColor(colors.lightGray, 0x1E293B) -- Row Background Panel
    mon.setPaletteColor(colors.cyan,      0x0EA5E9) -- Electric Blue Accent
    mon.setPaletteColor(colors.lime,      0x10B981) -- Emerald Green
    mon.setPaletteColor(colors.red,       0xF43F5E) -- Crimson Red
    mon.setPaletteColor(colors.orange,    0xF59E0B) -- Amber Accent
end

local currentPage = "LIST"
local hitboxes = {}
local todoList = {}
local currentInput = ""
local SAVE_FILE = "/todo_items.txt"

-- ==========================================
-- DATA STORAGE ENGINE
-- ==========================================
local function saveTasks()
    local file = fs.open(SAVE_FILE, "w")
    for _, task in ipairs(todoList) do
        file.writeLine(task.text .. ":" .. tostring(task.done))
    end
    file.close()
end

local function loadTasks()
    if not fs.exists(SAVE_FILE) then
        todoList = {}
        return
    end
    todoList = {}
    local file = fs.open(SAVE_FILE, "r")
    local line = file.readLine()
    while line do
        local parts = {}
        for match in string.gmatch(line, "[^:]+") do table.insert(parts, match) end
        if #parts >= 2 then
            table.insert(todoList, { text = parts[1], done = (parts[2] == "true") })
        end
        line = file.readLine()
    end
    file.close()
end

-- ==========================================
-- UI DRAWING HELPERS
-- ==========================================
local function registerHitbox(x1, x2, y1, y2, callback)
    table.insert(hitboxes, { x1 = x1, x2 = x2, y1 = y1, y2 = y2, callback = callback })
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

local function playTone(isAction)
    if not speaker then return end
    pcall(function()
        if isAction then 
            speaker.playNote("chime", 0.9, 12) 
        else 
            speaker.playNote("harp", 0.7, 5) 
        end
    end)
end

local function drawButton(x, y, width, height, text, mainColor, textColor)
    fill(x, y, width, height, mainColor)
    local tx = x + math.max(0, math.floor((width - #text) / 2))
    local ty = y + math.floor(height / 2)
    writeAt(tx, ty, text, textColor, mainColor)
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.white)
end

-- ==========================================
-- MAIN VIEW: STREAMLINED TASK BOARD
-- ==========================================
local function drawListPage()
    mon.setBackgroundColor(colors.gray)
    mon.clear()
    hitboxes = {}
    local w, h = mon.getSize()

    -- Clean Single-Row Header Bar
    fill(1, 1, w, 1, colors.lightGray)
    writeAt(2, 1, "LIST", colors.cyan, colors.lightGray)

    -- Sized Down Add Task Button (Single Row)
    local abw = 10
    local abx = w - abw - 1
    drawButton(abx, 1, abw, 1, "[+ TASK]", colors.cyan, colors.gray)
    registerHitbox(abx, abx + abw - 1, 1, 1, function()
        playTone(true)
        currentInput = ""
        currentPage = "KEYBOARD"
    end)

    -- Empty State Notice
    if #todoList == 0 then
        writeAt(math.floor((w - 18) / 2) + 1, 5, "NO ACTIVE PROTOCOLS", colors.lightGray, colors.gray)
        writeAt(math.floor((w - 24) / 2) + 1, 6, "TAP [+ TASK] TO INITIALIZE", colors.gray, colors.gray)
        return
    end

    -- Item Rendering Loop
    local startY = 3
    for i, task in ipairs(todoList) do
        if startY + 1 > h then break end

        fill(2, startY, w - 2, 1, colors.lightGray)

        -- Checkbox
        local cbText = task.done and " [X] " or " [ ] "
        local cbColor = task.done and colors.lime or colors.red
        local cbTextColor = task.done and colors.gray or colors.white
        drawButton(3, startY, 5, 1, cbText, cbColor, cbTextColor)
        
        local idx = i
        registerHitbox(3, 7, startY, startY, function()
            playTone(false)
            todoList[idx].done = not todoList[idx].done
            saveTasks()
        end)

        -- Label
        local textFg = task.done and colors.orange or colors.white
        writeAt(10, startY, string.sub(task.text, 1, w - 20), textFg, colors.lightGray)

        -- Clear Button
        local delX = w - 8
        drawButton(delX, startY, 7, 1, "CLEAR", colors.red, colors.white)
        registerHitbox(delX, delX + 6, startY, startY, function()
            playTone(true)
            table.remove(todoList, idx)
            saveTasks()
        end)

        startY = startY + 2
    end
end

-- ==========================================
-- REPROPORTIONED KEYBOARD OVERLAY
-- ==========================================
local function drawKeyboardPage()
    mon.setBackgroundColor(colors.gray)
    mon.clear()
    hitboxes = {}
    local w, h = mon.getSize()

    -- Simplified Header Bar Config
    fill(1, 1, w, 2, colors.lightGray)
    writeAt(2, 1, "NAME OF TASK/ITEM:", colors.orange, colors.lightGray)
    writeAt(2, 2, ">> " .. currentInput .. "_", colors.white, colors.lightGray)

    local rows = {
        { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
        { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" },
        { "A", "S", "D", "F", "G", "H", "J", "K", "L", "-" },
        { "Z", "X", "C", "V", "B", "N", "M", ",", ".", " " }
    }

    -- Proportional Sizing Variables for 3x3 Monitors
    local kw = 4 -- Expanded key text scale boundary widths
    local kh = 2
    local startY = 4

    for rIdx, row in ipairs(rows) do
        -- Dynamically offset layout horizontally to stretch edge-to-edge seamlessly
        local startX = math.floor((w - (#row * (kw + 1))) / 2) + 1
        for _, key in ipairs(row) do
            local label = key == " " and "SPC" or key
            
            fill(startX, startY, kw, kh, colors.lightGray)
            writeAt(startX + math.floor((kw - #label)/2), startY + 1, label, colors.white, colors.lightGray)

            local capturedKey = key
            registerHitbox(startX, startX + kw - 1, startY, startY + kh - 1, function()
                playTone(false)
                if #currentInput < w - 20 then
                    currentInput = currentInput .. capturedKey
                end
            end)
            startX = startX + kw + 1
        end
        startY = startY + kh + 1 -- Shrunk inner padding down to 1 row
    end

    local btnY = h - 2
    
    -- Balanced Bottom Operations Buttons Alignment
    drawButton(3, btnY, 8, 2, "[<-]", colors.orange, colors.gray)
    registerHitbox(3, 10, btnY, btnY + 1, function()
        playTone(false)
        currentInput = string.sub(currentInput, 1, #currentInput - 1)
    end)

    drawButton(13, btnY, 10, 2, "ABORT", colors.red, colors.white)
    registerHitbox(13, 22, btnY, btnY + 1, function()
        playTone(true)
        currentPage = "LIST"
    end)

    local svX = w - 13
    drawButton(svX, btnY, 11, 2, "COMMIT", colors.lime, colors.gray)
    registerHitbox(svX, svX + 10, btnY, btnY + 1, function()
        if currentInput ~= "" then
            playTone(true)
            table.insert(todoList, { text = currentInput, done = false })
            saveTasks()
            currentPage = "LIST"
        end
    end)
end

local function render()
    if currentPage == "LIST" then drawMainPage = drawListPage drawListPage() else drawKeyboardPage() end
end

-- ==========================================
-- INITIALIZER
-- ==========================================
loadTasks()
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
