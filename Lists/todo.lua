local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then
    print("Error: No monitor found!")
    return
end

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
    mon.setPaletteColor(colors.cyan,      0x58A6FF) -- Blue accent
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
local currentPath = {}

-- ==========================================
-- DATA STORAGE
-- ==========================================
local function ensureTaskShape(task)
    if type(task) ~= "table" then return nil end
    task.text = tostring(task.text or "Untitled")
    task.done = task.done == true
    if type(task.subtasks) ~= "table" then
        task.subtasks = {}
    end

    for i = #task.subtasks, 1, -1 do
        local fixed = ensureTaskShape(task.subtasks[i])
        if fixed then
            task.subtasks[i] = fixed
        else
            table.remove(task.subtasks, i)
        end
    end

    return task
end

local function normalizeTaskList(list)
    if type(list) ~= "table" then return {} end
    local out = {}
    for _, task in ipairs(list) do
        local fixed = ensureTaskShape(task)
        if fixed then table.insert(out, fixed) end
    end
    return out
end

local function saveTasks()
    local file = fs.open(SAVE_FILE, "w")
    if not file then return end
    file.write(textutils.serialize(todoList))
    file.close()
end

local function loadTasks()
    if not fs.exists(SAVE_FILE) then
        todoList = {}
        return
    end

    local file = fs.open(SAVE_FILE, "r")
    if not file then
        todoList = {}
        return
    end

    local raw = file.readAll()
    file.close()

    local data = textutils.unserialize(raw)
    todoList = normalizeTaskList(data)
end

-- ==========================================
-- HELPERS
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

local function truncate(str, maxLen)
    if maxLen <= 0 then return "" end
    if #str > maxLen then
        return str:sub(1, maxLen - 1) .. "~"
    end
    return str
end

local function getCurrentList()
    local list = todoList
    for _, index in ipairs(currentPath) do
        if not list[index] or type(list[index].subtasks) ~= "table" then
            return todoList
        end
        list = list[index].subtasks
    end
    return list
end

local function getCurrentTask()
    if #currentPath == 0 then return nil end
    local list = todoList
    local task = nil

    for _, index in ipairs(currentPath) do
        task = list[index]
        if not task then return nil end
        list = task.subtasks or {}
    end

    return task
end

local function buildPathLabel()
    if #currentPath == 0 then
        return "ROOT"
    end

    local parts = { "ROOT" }
    local list = todoList
    for _, index in ipairs(currentPath) do
        local task = list[index]
        if not task then break end
        table.insert(parts, task.text)
        list = task.subtasks or {}
    end

    return table.concat(parts, " > ")
end

local function countDoneRecursive(task)
    local total = 1
    local done = task.done and 1 or 0

    for _, child in ipairs(task.subtasks or {}) do
        local childDone, childTotal = countDoneRecursive(child)
        done = done + childDone
        total = total + childTotal
    end

    return done, total
end

local function setTaskDoneRecursive(task, value)
    task.done = value
    for _, child in ipairs(task.subtasks or {}) do
        setTaskDoneRecursive(child, value)
    end
end

local function refreshParentStates(list)
    for _, task in ipairs(list) do
        refreshParentStates(task.subtasks or {})
        if #task.subtasks > 0 then
            local allDone = true
            for _, child in ipairs(task.subtasks) do
                if not child.done then
                    allDone = false
                    break
                end
            end
            task.done = allDone
        end
    end
end

local function getVisibleStats(list)
    local done = 0
    local total = #list
    for _, task in ipairs(list) do
        if task.done then done = done + 1 end
    end
    return done, total
end

local function addTaskToCurrentList(text)
    local list = getCurrentList()
    table.insert(list, {
        text = text,
        done = false,
        subtasks = {}
    })
    refreshParentStates(todoList)
    saveTasks()
end

local function removeTaskAt(list, idx)
    table.remove(list, idx)
    refreshParentStates(todoList)
    saveTasks()
end

local function toggleTaskAt(list, idx)
    local task = list[idx]
    if not task then return end

    local newState = not task.done
    setTaskDoneRecursive(task, newState)
    refreshParentStates(todoList)
    saveTasks()
end

local function openTask(idx)
    table.insert(currentPath, idx)
    scrollOffset = 0
end

local function goBack()
    if #currentPath > 0 then
        table.remove(currentPath, #currentPath)
        scrollOffset = 0
    end
end

-- ==========================================
-- MAIN LIST VIEW
-- ==========================================
local function drawListPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}

    local w, h = mon.getSize()
    local currentList = getCurrentList()

    -- Header
    fill(1, 1, w, 3, colors.gray)

    local title = (#currentPath == 0) and "TODO LIST" or "SUBTASKS"
    writeAt(2, 1, title, colors.cyan, colors.gray)

    local pathLabel = truncate(buildPathLabel(), w - 4)
    writeAt(2, 2, pathLabel, colors.yellow, colors.gray)

    local doneCount, totalCount = getVisibleStats(currentList)
    local countStr = doneCount .. "/" .. totalCount .. " done"
    writeAt(2, 3, truncate(countStr, math.floor(w / 2)), colors.orange, colors.gray)

    -- Buttons
    local addLabel = "+ Add"
    local openRootLabel = (#currentPath > 0) and "< Back" or nil

    local rightX = w - #addLabel - 2
    writeAt(rightX, 1, " " .. addLabel .. " ", colors.black, colors.cyan)
    registerHitbox(rightX, rightX + #addLabel + 1, 1, 1, function()
        playTone(true)
        currentInput = ""
        currentPage = "KEYBOARD"
    end)

    if openRootLabel then
        writeAt(w - #openRootLabel - 3, 2, " " .. openRootLabel .. " ", colors.white, colors.red)
        registerHitbox(w - #openRootLabel - 3, w - 1, 2, 2, function()
            playTone(true)
            goBack()
        end)
    end

    -- Divider
    fill(1, 4, w, 1, colors.lightGray)
    writeAt(2, 4, string.rep("-", math.max(1, w - 2)), colors.gray, colors.lightGray)

    -- Empty state
    if #currentList == 0 then
        local msg1 = (#currentPath == 0) and "Nothing here yet!" or "No subtasks yet!"
        local msg2 = (#currentPath == 0) and "Tap '+ Add' to create a task" or "Tap '+ Add' to create a subtask"
        writeAt(math.floor((w - #msg1) / 2) + 1, 7, msg1, colors.lightGray, colors.black)
        writeAt(math.floor((w - #msg2) / 2) + 1, 8, msg2, colors.gray, colors.black)
        return
    end

    -- Scroll
    local listStartY = 5
    local listH = h - listStartY
    local maxScroll = math.max(0, #currentList - listH)
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

    -- Rows
    for i = 1 + scrollOffset, math.min(#currentList, listH + scrollOffset) do
        local task = currentList[i]
        local rowY = listStartY + (i - 1 - scrollOffset)
        local rowBg = (i % 2 == 0) and colors.gray or colors.black
        fill(1, rowY, w, 1, rowBg)

        -- Checkbox
        local cbSymbol = task.done and "[v]" or "[ ]"
        local cbColor = task.done and colors.lime or colors.red
        writeAt(2, rowY, cbSymbol, cbColor, rowBg)

        local idx = i
        registerHitbox(2, 4, rowY, rowY, function()
            playTone(false)
            toggleTaskAt(currentList, idx)
        end)

        -- Child marker
        local childCount = #(task.subtasks or {})
        local childLabel = childCount > 0 and ("{" .. childCount .. "}") or ""
        local childLabelW = #childLabel

        -- Delete button
        local delText = " Del "
        local delX = w - #delText - 1
        writeAt(delX, rowY, delText, colors.white, colors.red)
        registerHitbox(delX, delX + #delText - 1, rowY, rowY, function()
            playTone(true)
            removeTaskAt(currentList, idx)
            scrollOffset = math.min(scrollOffset, math.max(0, #currentList - listH))
        end)

        -- Open button
        local openText = " > "
        local openX = delX - #openText - 1
        writeAt(openX, rowY, openText, colors.black, colors.cyan)
        registerHitbox(openX, openX + #openText - 1, rowY, rowY, function()
            playTone(true)
            openTask(idx)
        end)

        -- Text
        local textFg = task.done and colors.white or colors.white
        if childCount > 0 then
            writeAt(6, rowY, childLabel, colors.yellow, rowBg)
        end

        local textStart = 6 + childLabelW + (childCount > 0 and 1 or 0)
        local maxTextW = openX - textStart - 1
        local label = truncate(task.text, maxTextW)
        writeAt(textStart, rowY, label, textFg, rowBg)
    end
end

-- ==========================================
-- KEYBOARD VIEW
-- ==========================================
local function drawKeyboardPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}

    local w, h = mon.getSize()

    fill(1, 1, w, 3, colors.gray)
    writeAt(2, 1, (#currentPath == 0) and "New task:" or "New subtask:", colors.orange, colors.gray)
    writeAt(2, 2, truncate(buildPathLabel(), w - 4), colors.yellow, colors.gray)

    local displayInput = currentInput
    if #displayInput > w - 6 then
        displayInput = ".." .. displayInput:sub(-(w - 8))
    end
    writeAt(2, 3, displayInput .. "_", colors.white, colors.gray)

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
    if kbStartY < 5 then kbStartY = 5 end

    for rIdx, row in ipairs(rows) do
        local startX = kbStartX
        local rowY = kbStartY + (rIdx - 1) * (kh + 1)

        for _, key in ipairs(row) do
            local label = (key == " ") and "SPC" or key
            fill(startX, rowY, kw, kh, colors.lightGray)
            local lx = startX + math.floor((kw - #label) / 2)
            writeAt(lx, rowY, label, colors.white, colors.lightGray)

            local capturedKey = key
            registerHitbox(startX, startX + kw - 1, rowY, rowY + kh - 1, function()
                playTone(false)
                if #currentInput < 60 then
                    currentInput = currentInput .. capturedKey
                end
            end)

            startX = startX + kw + 1
        end
    end

    local bY = h

    -- Backspace
    fill(2, bY, 5, 1, colors.orange)
    writeAt(3, bY, "<-", colors.black, colors.orange)
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
        currentInput = ""
    end)

    -- Add
    local addLabel = "ADD"
    local addX = w - #addLabel - 3
    fill(addX - 1, bY, #addLabel + 2, 1, colors.lime)
    writeAt(addX, bY, addLabel, colors.black, colors.lime)
    registerHitbox(addX - 1, addX + #addLabel, bY, bY, function()
        local trimmed = currentInput:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" then
            playTone(true)
            addTaskToCurrentList(trimmed)
            currentInput = ""
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
refreshParentStates(todoList)
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
