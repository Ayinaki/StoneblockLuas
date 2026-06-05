local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then print("Error: No monitor found!") return end

mon.setTextScale(1)
mon.clear()

-- ==========================================
-- THEME & PALETTE INITIALIZATION
-- ==========================================
if mon.isColor() then
    mon.setPaletteColor(colors.gray,      0x1F2937) -- Dark Charcoal Canvas
    mon.setPaletteColor(colors.lightGray, 0x4B5563) -- Slate Row Strips
    mon.setPaletteColor(colors.cyan,      0x06B6D4) -- Neon Add Button Accent
    mon.setPaletteColor(colors.lime,      0x10B981) -- Cyber Emerald Green
    mon.setPaletteColor(colors.red,       0xEF4444) -- Crimson Alert Red
end

local currentPage = "LIST" -- "LIST" or "KEYBOARD"
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
        -- Default startup sample items if no file exists yet
        todoList = {
            { text = "Refill Soulsand input bin", done = false },
            { text = "Expand Geologist chest space", done = true },
        }
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
-- UI DRAWING GENERATORS
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

-- Audio clicker chimes
local function playTone(isAction)
    if not speaker then return end
    pcall(function()
        if isAction then 
            speaker.playNote("chime", 0.9, 12) 
        else 
            speaker.playNote("harp", 0.7, 5) 
        end
    end) -- FIXED: Safely closed the pcall function block here
end

local function drawButton(x, y, width, height, text, mainColor, textColor)
    fill(x, y, width, height, mainColor)
    local tx = x + math.max(0, math.floor((width - #text) / 2))
    local ty = y + math.floor(height / 2)
    writeAt(tx, ty, text, textColor, mainColor)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
end

-- ==========================================
-- MAIN VIEW: TRACKING LIST
-- ==========================================
local function drawListPage()
    mon.setBackgroundColor(colors.gray)
    mon.clear()
    hitboxes = {}
    local w, h = mon.getSize()

    -- Header bar panel
    fill(1, 1, w, 2, colors.lightGray)
    writeAt(2, 1, "FACTORY TASK LIST", colors.white, colors.lightGray)
    writeAt(2, 2, "STATUS & PLANNED LOGS", colors.black, colors.lightGray)

    -- Sizable Top-Right [+] ADD button
    local abw = 5
    local abx = w - abw - 1
    fill(abx, 1, abw, 2, colors.cyan)
    writeAt(abx + 1, 1, "[ + ]", colors.white, colors.cyan)
    writeAt(abx + 1, 2, " ADD ", colors.white, colors.cyan)
    
    registerHitbox(abx, abx + abw - 1, 1, 2, function()
        playTone(true)
        currentInput = ""
        currentPage = "KEYBOARD"
    end)

    -- Item List Loop Rendering
    local startY = 4
    for i, task in ipairs(todoList) do
        if startY + 2 > h then break end -- Scroll guard

        -- 1. Checkbox Box Button
        local cbColor = task.done and colors.lime or colors.red
        local cbText  = task.done and "[X]" or "[ ]"
        fill(2, startY, 5, 2, cbColor)
        writeAt(3, startY, cbText, task.done and colors.black or colors.white, cbColor)
        
        local idx = i
        registerHitbox(2, 6, startY, startY + 1, function()
            playTone(false)
            todoList[idx].done = not todoList[idx].done
            saveTasks()
        end)

        -- 2. Text Description Card Label
        local txtBg = task.done and colors.lightGray or colors.black
        local txtFg = task.done and colors.gray or colors.white
        fill(8, startY, w - 14, 2, txtBg)
        writeAt(10, startY, string.sub(task.text, 1, w - 16), txtFg, txtBg)

        -- 3. Inline Trash Delete Button [!]
        local delX = w - 5
        fill(delX, startY, 4, 2, colors.red)
        writeAt(delX + 1, startY, "[!]", colors.white, colors.red)
        writeAt(delX + 1, startY + 1, "DEL", colors.white, colors.red)
        
        registerHitbox(delX, delX + 3, startY, startY + 1, function()
            playTone(true)
            table.remove(todoList, idx)
            saveTasks()
        end)

        startY = startY + 3
    end
end

-- ==========================================
-- SUB VIEW: ON-SCREEN OS KEYBOARD OVERLAY
-- ==========================================
local function drawKeyboardPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    local w, h = mon.getSize()

    -- Live Input Value Bar
    fill(1, 1, w, 2, colors.gray)
    writeAt(2, 1, "ENTER TASK NAME:", colors.yellow, colors.gray)
    writeAt(2, 2, "> " .. currentInput .. "_", colors.white, colors.gray)

    -- Keyboard Layout Mapping rows
    local rows = {
        { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
        { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" },
        { "A", "S", "D", "F", "G", "H", "J", "K", "L", "-" },
        { "Z", "X", "C", "V", "B", "N", "M", ",", ".", " " }
    }

    local kw = 3 -- Individual key block width scale
    local kh = 2 -- Individual key block height scale
    local startY = 4

    for rIdx, row in ipairs(rows) do
        local startX = math.floor((w - (#row * (kw + 1))) / 2) + 1
        for _, key in ipairs(row) do
            local label = key == " " and "SPC" or key
            
            fill(startX, startY, kw, kh, colors.lightGray)
            writeAt(startX + math.floor((kw - #label)/2), startY, label, colors.white, colors.lightGray)

            local capturedKey = key
            registerHitbox(startX, startX + kw - 1, startY, startY + kh - 1, function()
                playTone(false)
                if #currentInput < w - 16 then
                    currentInput = currentInput .. capturedKey
                end
            end)
            startX = startX + kw + 1
        end
        startY = startY + kh + 1
    end

    -- Bottom Master Utility Controls Array
    local btnY = h - 2
    
    -- Backspace Left Arrow
    drawButton(2, btnY, 6, 2, "[<-]", colors.orange, colors.white)
    registerHitbox(2, 7, btnY, btnY + 1, function()
        playTone(false)
        currentInput = string.sub(currentInput, 1, #currentInput - 1)
    end)

    -- Cancel Operational Reset
    drawButton(9, btnY, 8, 2, "CANCEL", colors.red, colors.white)
    registerHitbox(9, 16, btnY, btnY + 1, function()
        playTone(true)
        currentPage = "LIST"
    end)

    -- Save/Confirm Target Item Commit
    local svX = w - 9
    drawButton(svX, btnY, 8, 2, "SAVE", colors.lime, colors.black)
    registerHitbox(svX, svX + 7, btnY, btnY + 1, function()
        if currentInput ~= "" then
            playTone(true)
            table.insert(todoList, { text = currentInput, done = false })
            saveTasks()
            currentPage = "LIST"
        end
    end)
end

local function render()
    if currentPage == "LIST" then drawListPage() else drawKeyboardPage() end
end

-- ==========================================
-- PROCESS EXECUTION SYSTEM INITIALIZER
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
