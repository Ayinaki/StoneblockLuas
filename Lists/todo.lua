local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then print("Error: No monitor found!") return end

mon.setTextScale(0.5)
mon.clear()

-- ==========================================
-- COLOUR PALETTE
-- ==========================================
if mon.isColor() then
    mon.setPaletteColor(colors.black,     0x0D1117) -- Deep background
    mon.setPaletteColor(colors.gray,      0x161B22) -- Surface / card bg
    mon.setPaletteColor(colors.lightGray, 0x21262D) -- Elevated surface
    mon.setPaletteColor(colors.white,     0xE6EDF3) -- Primary text
    mon.setPaletteColor(colors.cyan,      0x58A6FF) -- Blue accent (add btn, headers)
    mon.setPaletteColor(colors.lime,      0x3FB950) -- Done / confirm green
    mon.setPaletteColor(colors.red,       0xF85149) -- Delete / abort red
    mon.setPaletteColor(colors.orange,    0xD29922) -- Pending / backspace amber
    mon.setPaletteColor(colors.purple,    0xBC8CFF) -- Input cursor accent
    mon.setPaletteColor(colors.yellow,    0xE3B341) -- Highlight / label
    mon.setPaletteColor(colors.blue,      0x1F6FEB) -- Button backgrounds
    mon.setPaletteColor(colors.magenta,   0x388BFD) -- Key hover bg
    mon.setPaletteColor(colors.brown,     0x30363D) -- Key background
    mon.setPaletteColor(colors.pink,      0x58A6FF) -- Key text
end

local currentPage = "LIST"
local hitboxes = {}
local todoList = {}
local currentInput = ""
local SAVE_FILE = "/todo_items.txt"
local scrollOffset = 0

-- ==========================================
-- DATA STORAGE
-- ==========================================
local function saveTasks()
    local file = fs.open(SAVE_FILE, "w")
    for _, task in ipairs(todoList) do
        file.writeLine(task.text .. ":" .. tostring(task.done))
    end
    file.close()
end

local function loadTasks()
    if not fs.exists(SAVE_FILE) then todoList = {} return end
    todoList = {}
    local file = fs.open(SAVE_FILE, "r")
    local line = file.readLine()
    while line do
        local text, done = line:match("^(.*):([^:]+)$")
        if text and done then
            table.insert(todoList, { text = text, done = (done == "true") })
        end
        line = file.readLine()
    end
    file.close()
end

-- ==========================================
-- UI HELPERS
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

local function truncate(str, maxLen)
    if #str > maxLen then return str:sub(1, maxLen - 1) .. "~" end
    return str
end

-- ==========================================
-- MAIN LIST VIEW
-- ==========================================
local function drawListPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    local w, h = mon.getSize()

    -- ── Header bar ──────────────────────────────────────────
    fill(1, 1, w, 2, colors.gray)
    writeAt(2, 1, "TODO LIST", colors.cyan, colors.gray)

    local total = #todoList
    local done  = 0
    for _, t in ipairs(todoList) do
        if t.done then done = done + 1 end
    end
    local countStr = done .. "/" .. total .. " done"
    writeAt(2, 2, countStr, colors.orange, colors.gray)

    local addLabel = "+ Add"
    local ax = w - #addLabel - 2
    writeAt(ax, 1, " " .. addLabel .. " ", colors.black, colors.cyan)
    registerHitbox(ax, ax + #addLabel + 1, 1, 1, function()
        playTone(true)
        currentInput = ""
        scrollOffset = 0
        currentPage = "KEYBOARD"
    end)

    fill(1, 3, w, 1, colors.lightGray)
    writeAt(2, 3, string.rep("-", w - 2), colors.gray, colors.lightGray)

    -- ── Empty state ──────────────────────────────────────────
    if #todoList == 0 then
        local msg1 = "Nothing here yet!"
        local msg2 = "Tap '+ Add' to create a task"
        writeAt(math.floor((w - #msg1) / 2) + 1, 6, msg1, colors.lightGray, colors.black)
        writeAt(math.floor((w - #msg2) / 2) + 1, 7, msg2, colors.gray, colors.black)
        return
    end

    -- ── Scroll arrows ───────────────────────────────────────
    local listStartY = 4
    local listH = h - listStartY
    local maxScroll = math.max(0, #todoList - listH)
    scrollOffset = math.min(scrollOffset, maxScroll)

    if scrollOffset > 0 then
        writeAt(w, listStartY, "^", colors.cyan, colors.black)
        registerHitbox(w, w, listStartY, listStartY, function()
            scrollOffset = math.max(0, scrollOffset - 1)
        end)
    end

    if scrollOffset < maxScroll then
        writeAt(w, h, "v", colors.cyan, colors.black)
        registerHitbox(w, w, h, h, function()
            scrollOffset = math.min(maxScroll, scrollOffset + 1)
        end)
    end

    -- ── Items ────────────────────────────────────────────────
    for i = 1 + scrollOffset, math.min(#todoList, listH + scrollOffset) do
        local task = todoList[i]
        local rowY = listStartY + (i - 1 - scrollOffset)

        local rowBg = (i % 2 == 0) and colors.gray or colors.black
        fill(1, rowY, w, 1, rowBg)

        local cbSymbol = task.done and "[v]" or "[ ]"
        local cbColor = task.done and colors.lime or colors.red
        writeAt(2, rowY, cbSymbol, cbColor, rowBg)

        local idx = i
        registerHitbox(2, 4, rowY, rowY, function()
            playTone(false)
            todoList[idx].done = not todoList[idx].done
            saveTasks()
        end)

        local maxTextW = w - 14
        local label = truncate(task.text, maxTextW)

        if task.done then
            writeAt(7, rowY, label, colors.lightGray, rowBg)
        else
            writeAt(7, rowY, label, colors.white, rowBg)
        end

        local delX = w - 5
        writeAt(delX, rowY, " Del ", colors.white, colors.red)
        registerHitbox(delX, delX + 4, rowY, rowY, function()
            playTone(true)
            table.remove(todoList, idx)
            saveTasks()
            scrollOffset = math.min(scrollOffset, math.max(0, #todoList - listH))
        end)
    end
end

-- ==========================================
-- COMPACT KEYBOARD VIEW
-- ==========================================
local function drawKeyboardPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}
    local w, h = mon.getSize()

    -- ── Input bar ────────────────────────────────────────────
    fill(1, 1, w, 2, colors.gray)
    writeAt(2, 1, "New task:", colors.orange, colors.gray)

    local displayInput = currentInput
    if #displayInput > w - 6 then
        displayInput = ".." .. displayInput:sub(-(w - 8))
    end
    writeAt(2, 2, displayInput .. "_", colors.white, colors.gray)

    -- ── Keyboard layout ──────────────────────────────────────
    local kw = 3
    local kh = 1

    local rows = {
        { "1","2","3","4","5","6","7","8","9","0" },
        { "Q","W","E","R","T","Y","U","I","O","P" },
        { "A","S","D","F","G","H","J","K","L","-" },
        { "Z","X","C","V","B","N","M",",","."," " }
    }

    local numCols = 10
    local totalKbW = numCols * kw + (numCols - 1)
    local kbStartX = math.floor((w - totalKbW) / 2) + 1

    local actionRowY = h - 1
    local kbStartY = actionRowY - (#rows * (kh + 1))
    if kbStartY < 4 then kbStartY = 4 end

    for rIdx, row in ipairs(rows) do
        local startX = kbStartX
        local rowY = kbStartY + (rIdx - 1) * (kh + 1)

        for _, key in ipairs(row) do
            local label = key == " " and "SPC" or key

            fill(startX, rowY, kw, kh, colors.lightGray)
            local lx = startX + math.floor((kw - #label) / 2)
            writeAt(lx, rowY, label, colors.white, colors.lightGray)

            local capturedKey = key
            registerHitbox(startX, startX + kw - 1, rowY, rowY + kh - 1, function()
                playTone(false)
                if #currentInput < 40 then
                    currentInput = currentInput .. capturedKey
                end
            end)

            startX = startX + kw + 1
        end
    end

    -- ── Action buttons ───────────────────────────────────────
    local bY = h

    -- Backspace
    local bsLabel = "<-"
    fill(2, bY, 5, 1, colors.orange)
    writeAt(3, bY, bsLabel, colors.black, colors.orange)
    registerHitbox(2, 6, bY, bY, function()
        playTone(false)
        currentInput = currentInput:sub(1, -2)
    end)

    -- Cancel
    local canLabel = "CANCEL"
    local canX = math.floor(w / 2) - math.floor(#canLabel / 2)
    fill(canX - 1, bY, #canLabel + 2, 1, colors.red)
    writeAt(canX, bY, canLabel, colors.white, colors.red)
    registerHitbox(canX - 1, canX + #canLabel, bY, bY, function()
        playTone(true)
        currentPage = "LIST"
    end)

    -- Add / Commit
    local addLabel = "ADD"
    local addX = w - #addLabel - 3
    fill(addX - 1, bY, #addLabel + 2, 1, colors.lime)
    writeAt(addX, bY, addLabel, colors.black, colors.lime)
    registerHitbox(addX - 1, addX + #addLabel, bY, bY, function()
        if currentInput ~= "" then
            playTone(true)
            table.insert(todoList, { text = currentInput, done = false })
            saveTasks()
            currentPage = "LIST"
        end
    end)
end

-- ==========================================
-- RENDER
-- ==========================================
local function render()
    if currentPage == "LIST" then
        drawListPage()
    else
        drawKeyboardPage()
    end
end

-- ==========================================
-- INIT
-- ==========================================
loadTasks()
render()

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    if side == peripheral.getName(mon) then
        for _, box in ipairs(hitboxes) do
            if x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2 then
                box.callback()
                render()
                break
            end
        end
    end
end
