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
    mon.setPaletteColor(colors.black,     0x0D1117)
    mon.setPaletteColor(colors.gray,      0x161B22)
    mon.setPaletteColor(colors.lightGray, 0x21262D)
    mon.setPaletteColor(colors.white,     0xE6EDF3)
    mon.setPaletteColor(colors.cyan,      0x58A6FF)
    mon.setPaletteColor(colors.lime,      0x3FB950)
    mon.setPaletteColor(colors.red,       0xF85149)
    mon.setPaletteColor(colors.orange,    0xD29922)
    mon.setPaletteColor(colors.purple,    0xBC8CFF)
    mon.setPaletteColor(colors.yellow,    0xE3B341)
    mon.setPaletteColor(colors.blue,      0x1F6FEB)
    mon.setPaletteColor(colors.magenta,   0x388BFD)
    mon.setPaletteColor(colors.brown,     0x30363D)
    mon.setPaletteColor(colors.pink,      0x58A6FF)
end

local currentPage = "TREE"
local hitboxes = {}
local todoList = {}
local archiveList = {}
local currentInput = ""
local SAVE_FILE = "/todo_items.txt"

local scrollOffset = 0
local archiveScrollOffset = 0
local selectedPath = nil
local inputTargetPath = nil
local inputMode = "ADD"
local editingPath = nil
local deleteTargetPath = nil
local deleteTargetListName = "ACTIVE"

-- ==========================================
-- DATA STORAGE
-- ==========================================
local function ensureTaskShape(task)
    if type(task) ~= "table" then return nil end

    task.text = tostring(task.text or "Untitled")
    task.done = task.done == true
    task.expanded = task.expanded ~= false

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
        if fixed then
            table.insert(out, fixed)
        end
    end
    return out
end

local function saveTasks()
    local file = fs.open(SAVE_FILE, "w")
    if not file then return end

    local payload = {
        active = todoList,
        archive = archiveList
    }

    file.write(textutils.serialize(payload))
    file.close()
end

local function loadTasks()
    if not fs.exists(SAVE_FILE) then
        todoList = {}
        archiveList = {}
        return
    end

    local file = fs.open(SAVE_FILE, "r")
    if not file then
        todoList = {}
        archiveList = {}
        return
    end

    local raw = file.readAll()
    file.close()

    local data = textutils.unserialize(raw)

    if type(data) == "table" and (data.active or data.archive) then
        todoList = normalizeTaskList(data.active)
        archiveList = normalizeTaskList(data.archive)
    else
        todoList = normalizeTaskList(data)
        archiveList = {}
    end
end

-- ==========================================
-- UI HELPERS
-- ==========================================
local function registerHitbox(x1, x2, y1, y2, callback)
    table.insert(hitboxes, {
        x1 = x1, x2 = x2, y1 = y1, y2 = y2, callback = callback
    })
end

local function fill(x, y, width, height, bg)
    if width == nil or height == nil then return end
    if width < 1 or height < 1 then return end

    mon.setBackgroundColor(bg)
    for i = 0, height - 1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
end

local function writeAt(x, y, text, fg, bg)
    if x == nil or y == nil or text == nil then return end
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
    str = tostring(str or "")
    if not maxLen or maxLen <= 0 then return "" end
    if #str > maxLen then
        if maxLen == 1 then return "~" end
        return str:sub(1, maxLen - 1) .. "~"
    end
    return str
end

local function copyPath(path)
    local newPath = {}
    if path then
        for i, v in ipairs(path) do
            newPath[i] = v
        end
    end
    return newPath
end

local function cloneTask(task)
    local newTask = {
        text = task.text,
        done = task.done,
        expanded = task.expanded,
        subtasks = {}
    }

    for _, child in ipairs(task.subtasks or {}) do
        table.insert(newTask.subtasks, cloneTask(child))
    end

    return newTask
end

local function pathEquals(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function getTaskByPath(path, listRoot)
    if type(path) ~= "table" then return nil end

    local list = listRoot or todoList
    local task = nil

    for _, index in ipairs(path) do
        task = list[index]
        if not task then return nil end
        list = task.subtasks or {}
    end

    return task
end

local function getListAndIndexByPath(path, listRoot)
    local root = listRoot or todoList

    if type(path) ~= "table" or #path == 0 then
        return root, nil
    end

    local list = root
    for i = 1, #path - 1 do
        local task = list[path[i]]
        if not task then return nil, nil end
        list = task.subtasks or {}
    end

    return list, path[#path]
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

local function countVisibleDone(list)
    local done, total = 0, 0

    local function walk(tasks)
        for _, task in ipairs(tasks) do
            total = total + 1
            if task.done then done = done + 1 end
            if task.expanded and task.subtasks and #task.subtasks > 0 then
                walk(task.subtasks)
            end
        end
    end

    walk(list)
    return done, total
end

local function countBranchProgress(task)
    if not task.subtasks or #task.subtasks == 0 then
        return task.done and 1 or 0, 1
    end

    local done, total = 0, 0
    for _, child in ipairs(task.subtasks) do
        local childDone, childTotal = countBranchProgress(child)
        done = done + childDone
        total = total + childTotal
    end
    return done, total
end

local function countBranchSize(task)
    local total = 1
    for _, child in ipairs(task.subtasks or {}) do
        total = total + countBranchSize(child)
    end
    return total
end

local function flattenVisibleTree(tasks, depth, prefixFlags, out, parentPath)
    out = out or {}
    depth = depth or 0
    prefixFlags = prefixFlags or {}
    parentPath = parentPath or {}

    for i, task in ipairs(tasks) do
        local path = copyPath(parentPath)
        table.insert(path, i)

        local isLast = (i == #tasks)
        table.insert(out, {
            task = task,
            depth = depth,
            path = path,
            prefixFlags = copyPath(prefixFlags),
            isLast = isLast
        })

        if task.expanded and task.subtasks and #task.subtasks > 0 then
            local childPrefixFlags = copyPath(prefixFlags)
            table.insert(childPrefixFlags, not isLast)
            flattenVisibleTree(task.subtasks, depth + 1, childPrefixFlags, out, path)
        end
    end

    return out
end

local function buildTreePrefix(row)
    local depth = row.depth or 0
    if depth <= 0 then return "" end

    local parts = {}
    for i = 1, depth - 1 do
        if row.prefixFlags and row.prefixFlags[i] then
            table.insert(parts, "| ")
        else
            table.insert(parts, "  ")
        end
    end

    if row.isLast then
        table.insert(parts, "\\-")
    else
        table.insert(parts, "+-")
    end

    return table.concat(parts)
end

local function ensureSelectionIsValid()
    if selectedPath and not getTaskByPath(selectedPath, todoList) then
        selectedPath = nil
    end
    if inputTargetPath and not getTaskByPath(inputTargetPath, todoList) then
        inputTargetPath = nil
    end
    if editingPath and not getTaskByPath(editingPath, todoList) then
        editingPath = nil
    end
    if deleteTargetPath then
        local root = (deleteTargetListName == "ARCHIVE") and archiveList or todoList
        if not getTaskByPath(deleteTargetPath, root) then
            deleteTargetPath = nil
            deleteTargetListName = "ACTIVE"
        end
    end
end

local function addTask(text)
    local newTask = {
        text = text,
        done = false,
        expanded = true,
        subtasks = {}
    }

    if inputTargetPath then
        local parent = getTaskByPath(inputTargetPath, todoList)
        if parent then
            parent.expanded = true
            table.insert(parent.subtasks, newTask)
        else
            table.insert(todoList, newTask)
        end
    else
        table.insert(todoList, newTask)
    end

    refreshParentStates(todoList)
    saveTasks()
end

local function editTask(path, newText)
    local task = getTaskByPath(path, todoList)
    if not task then return end
    task.text = newText
    saveTasks()
end

local function removeTask(path, listRoot)
    local root = listRoot or todoList
    local list, idx = getListAndIndexByPath(path, root)

    if list and idx and list[idx] then
        table.remove(list, idx)
        if root == todoList then
            refreshParentStates(todoList)
        else
            refreshParentStates(archiveList)
        end
        saveTasks()
    end

    if root == todoList and selectedPath and pathEquals(selectedPath, path) then
        selectedPath = nil
    end
end

local function toggleDone(path)
    local task = getTaskByPath(path, todoList)
    if not task then return end

    setTaskDoneRecursive(task, not task.done)
    refreshParentStates(todoList)
    saveTasks()
end

local function toggleExpanded(path)
    local task = getTaskByPath(path, todoList)
    if not task then return end

    if task.subtasks and #task.subtasks > 0 then
        task.expanded = not task.expanded
        saveTasks()
    end
end

local function startAddMode()
    currentInput = ""
    inputTargetPath = selectedPath and copyPath(selectedPath) or nil
    editingPath = nil
    inputMode = "ADD"
    currentPage = "KEYBOARD"
end

local function startEditMode(path)
    local task = getTaskByPath(path, todoList)
    if not task then return end
    currentInput = task.text
    editingPath = copyPath(path)
    inputTargetPath = nil
    inputMode = "EDIT"
    currentPage = "KEYBOARD"
end

local function startDeleteConfirm(path, listName)
    deleteTargetPath = copyPath(path)
    deleteTargetListName = listName or "ACTIVE"
    currentPage = "DELETE_CONFIRM"
end

local function archiveCompletedBranches()
    local kept = {}
    local moved = 0

    for _, task in ipairs(todoList) do
        if task.done then
            table.insert(archiveList, cloneTask(task))
            moved = moved + 1
        else
            table.insert(kept, task)
        end
    end

    todoList = kept
    refreshParentStates(todoList)
    saveTasks()

    if moved > 0 and selectedPath then
        selectedPath = nil
    end
end

-- ==========================================
-- GUIDE PAGE
-- ==========================================
local function drawGuidePage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}

    local w, h = mon.getSize()

    fill(1, 1, w, 2, colors.gray)
    writeAt(2, 1, "GUIDE", colors.cyan, colors.gray)
    writeAt(2, 2, "How to use the task tree", colors.yellow, colors.gray)

    local backLabel = " BACK "
    local backX = w - #backLabel - 1
    writeAt(backX, 1, backLabel, colors.white, colors.red)
    registerHitbox(backX, backX + #backLabel - 1, 1, 1, function()
        playTone(true)
        currentPage = "TREE"
    end)

    local lines = {
        "1. Tap a task once to select it.",
        "2. Tap the same task again to",
        "   expand or collapse subtasks.",
        "3. Tap [ ] or [v] to toggle a",
        "   task and its whole branch.",
        "4. Parent tasks show [done/total].",
        "5. Tap Edit to rename a task.",
        "6. Tap Del to open confirm delete.",
        "7. Archive Done moves finished top",
        "   level branches into archive.",
        "8. Archive rows can also be deleted."
    }

    local startY = 4
    for i, line in ipairs(lines) do
        local y = startY + i - 1
        if y <= h then
            writeAt(2, y, truncate(line, w - 3), colors.white, colors.black)
        end
    end

    if h >= 15 then
        writeAt(2, h - 1, "Tip: select a parent before adding.", colors.orange, colors.black)
    end
end

-- ==========================================
-- ARCHIVE PAGE
-- ==========================================
local function drawArchivePage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}

    local w, h = mon.getSize()
    local rows = flattenVisibleTree(archiveList, 0, {}, {}, {})

    fill(1, 1, w, 2, colors.gray)
    writeAt(2, 1, "ARCHIVE", colors.cyan, colors.gray)
    writeAt(2, 2, #archiveList .. " archived branches", colors.orange, colors.gray)

    local backLabel = " BACK "
    local backX = w - #backLabel - 1
    writeAt(backX, 1, backLabel, colors.white, colors.red)
    registerHitbox(backX, backX + #backLabel - 1, 1, 1, function()
        playTone(true)
        currentPage = "TREE"
    end)

    local listStartY = 4
    local listH = h - listStartY
    if listH < 1 then listH = 1 end

    if #rows == 0 then
        writeAt(2, 5, "No archived branches yet.", colors.lightGray, colors.black)
        return
    end

    local maxScroll = math.max(0, #rows - listH)
    archiveScrollOffset = math.min(archiveScrollOffset, maxScroll)

    if archiveScrollOffset > 0 then
        writeAt(w, listStartY, "^", colors.cyan, colors.black)
        registerHitbox(w, w, listStartY, listStartY, function()
            archiveScrollOffset = math.max(0, archiveScrollOffset - 1)
        end)
    end

    if archiveScrollOffset < maxScroll then
        writeAt(w, h, "v", colors.cyan, colors.black)
        registerHitbox(w, w, h, h, function()
            archiveScrollOffset = math.min(maxScroll, archiveScrollOffset + 1)
        end)
    end

    for visibleIndex = 1 + archiveScrollOffset, math.min(#rows, listH + archiveScrollOffset) do
        local row = rows[visibleIndex]
        local task = row.task
        local y = listStartY + (visibleIndex - 1 - archiveScrollOffset)

        local rowBg = ((visibleIndex % 2) == 0) and colors.gray or colors.black
        fill(1, y, w, 1, rowBg)

        local delText = " Del "
        local delX = w - #delText - 1
        writeAt(delX, y, delText, colors.white, colors.red)

        local pathCopy1 = copyPath(row.path)
        registerHitbox(delX, delX + #delText - 1, y, y, function()
            playTone(true)
            startDeleteConfirm(pathCopy1, "ARCHIVE")
        end)

        local treePrefix = buildTreePrefix(row)
        local marker = " "
        if task.subtasks and #task.subtasks > 0 then
            marker = task.expanded and "-" or "+"
        end

        local doneCount, totalCount = countBranchProgress(task)
        local suffix = ""
        if task.subtasks and #task.subtasks > 0 then
            suffix = " [" .. doneCount .. "/" .. totalCount .. "]"
        end

        writeAt(2, y, truncate(treePrefix .. marker .. " " .. task.text .. suffix, delX - 3), colors.lightGray, rowBg)
    end
end

-- ==========================================
-- DELETE CONFIRM
-- ==========================================
local function drawDeleteConfirmPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}

    local w, h = mon.getSize()
    local root = (deleteTargetListName == "ARCHIVE") and archiveList or todoList
    local task = getTaskByPath(deleteTargetPath, root)

    fill(1, 1, w, 3, colors.red)
    writeAt(2, 1, "CONFIRM DELETE", colors.white, colors.red)

    if not task then
        writeAt(2, 2, "Task not found.", colors.white, colors.red)
        local backLabel = " BACK "
        local backX = w - #backLabel - 1
        writeAt(backX, 1, backLabel, colors.white, colors.gray)
        registerHitbox(backX, backX + #backLabel - 1, 1, 1, function()
            currentPage = (deleteTargetListName == "ARCHIVE") and "ARCHIVE" or "TREE"
            deleteTargetPath = nil
            deleteTargetListName = "ACTIVE"
        end)
        return
    end

    writeAt(2, 2, truncate(task.text, w - 4), colors.white, colors.red)

    local sourceText = (deleteTargetListName == "ARCHIVE") and "From: Archive" or "From: Active list"
    writeAt(2, 3, truncate(sourceText .. " | Branch size: " .. countBranchSize(task), w - 4), colors.white, colors.red)

    local msg1 = "This will remove the selected task"
    local msg2 = "and all of its subtasks."
    writeAt(2, 6, truncate(msg1, w - 3), colors.lightGray, colors.black)
    writeAt(2, 7, truncate(msg2, w - 3), colors.lightGray, colors.black)

    local cancelLabel = " CANCEL "
    local deleteLabel = " DELETE "
    local cancelX = math.floor(w / 2) - #cancelLabel - 2
    local deleteX = math.floor(w / 2) + 2
    local by = math.min(h, 10)

    writeAt(cancelX, by, cancelLabel, colors.white, colors.gray)
    registerHitbox(cancelX, cancelX + #cancelLabel - 1, by, by, function()
        playTone(false)
        deleteTargetPath = nil
        local nextPage = (deleteTargetListName == "ARCHIVE") and "ARCHIVE" or "TREE"
        deleteTargetListName = "ACTIVE"
        currentPage = nextPage
    end)

    writeAt(deleteX, by, deleteLabel, colors.white, colors.red)
    registerHitbox(deleteX, deleteX + #deleteLabel - 1, by, by, function()
        playTone(true)
        if deleteTargetPath then
            if deleteTargetListName == "ARCHIVE" then
                removeTask(deleteTargetPath, archiveList)
            else
                removeTask(deleteTargetPath, todoList)
            end
        end
        local nextPage = (deleteTargetListName == "ARCHIVE") and "ARCHIVE" or "TREE"
        deleteTargetPath = nil
        deleteTargetListName = "ACTIVE"
        currentPage = nextPage
    end)
end

-- ==========================================
-- TREE VIEW
-- ==========================================
local function drawTreePage()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    hitboxes = {}

    ensureSelectionIsValid()

    local w, h = mon.getSize()
    local rows = flattenVisibleTree(todoList, 0, {}, {}, {})
    local doneCount, totalCount = countVisibleDone(todoList)

    fill(1, 1, w, 3, colors.gray)
    writeAt(2, 1, "TODO TREE", colors.cyan, colors.gray)
    writeAt(2, 2, doneCount .. "/" .. totalCount .. " visible done", colors.orange, colors.gray)

    local targetLabel
    if selectedPath then
        local t = getTaskByPath(selectedPath, todoList)
        targetLabel = t and ("Selected: " .. t.text) or "Selected: ROOT"
    else
        targetLabel = "Selected: ROOT"
    end
    writeAt(2, 3, truncate(targetLabel, w - 4), colors.yellow, colors.gray)

    local addLabel = "+ Add"
    local addX = w - #addLabel - 2
    writeAt(addX, 1, " " .. addLabel .. " ", colors.black, colors.cyan)
    registerHitbox(addX, addX + #addLabel + 1, 1, 1, function()
        playTone(true)
        startAddMode()
    end)

    fill(1, 4, w, 1, colors.lightGray)
    writeAt(2, 4, string.rep("-", math.max(1, w - 2)), colors.gray, colors.lightGray)

    local footerReserved = 1
    local listStartY = 5
    local listH = h - listStartY - footerReserved
    if listH < 1 then listH = 1 end

    if #rows == 0 then
        local msg1 = "Nothing here yet!"
        local msg2 = "Tap '+ Add' to create a root task"
        writeAt(math.floor((w - #msg1) / 2) + 1, 7, msg1, colors.lightGray, colors.black)
        writeAt(math.floor((w - #msg2) / 2) + 1, 8, msg2, colors.gray, colors.black)
    else
        local maxScroll = math.max(0, #rows - listH)
        scrollOffset = math.min(scrollOffset, maxScroll)

        if scrollOffset > 0 then
            writeAt(w, listStartY, "^", colors.cyan, colors.black)
            registerHitbox(w, w, listStartY, listStartY, function()
                scrollOffset = math.max(0, scrollOffset - 1)
            end)
        end

        if scrollOffset < maxScroll then
            writeAt(w, h - 1, "v", colors.cyan, colors.black)
            registerHitbox(w, w, h - 1, h - 1, function()
                scrollOffset = math.min(maxScroll, scrollOffset + 1)
            end)
        end

        for visibleIndex = 1 + scrollOffset, math.min(#rows, listH + scrollOffset) do
            local row = rows[visibleIndex]
            local task = row.task
            local y = listStartY + (visibleIndex - 1 - scrollOffset)

            local isSelected = false
            if selectedPath and pathEquals(selectedPath, row.path) then
                isSelected = true
            end

            local rowBg
            if isSelected then
                rowBg = colors.lightGray
            elseif (visibleIndex % 2) == 0 then
                rowBg = colors.gray
            else
                rowBg = colors.black
            end

            fill(1, y, w, 1, rowBg)

            local cbText = task.done and "[v]" or "[ ]"
            local cbColor = task.done and colors.lime or colors.red
            writeAt(2, y, cbText, cbColor, rowBg)

            local pathCopy1 = copyPath(row.path)
            registerHitbox(2, 4, y, y, function()
                playTone(false)
                toggleDone(pathCopy1)
            end)

            local delText = " Del "
            local delX = w - #delText - 1
            writeAt(delX, y, delText, colors.white, colors.red)

            local pathCopy2 = copyPath(row.path)
            registerHitbox(delX, delX + #delText - 1, y, y, function()
                playTone(true)
                startDeleteConfirm(pathCopy2, "ACTIVE")
            end)

            local editText = " Edit "
            local editX = delX - #editText - 1
            writeAt(editX, y, editText, colors.black, colors.orange)

            local pathCopy4 = copyPath(row.path)
            registerHitbox(editX, editX + #editText - 1, y, y, function()
                playTone(true)
                startEditMode(pathCopy4)
            end)

            local treePrefix = buildTreePrefix(row)
            local marker = " "
            if task.subtasks and #task.subtasks > 0 then
                marker = task.expanded and "-" or "+"
            end

            local doneBranch, totalBranch = countBranchProgress(task)
            local suffix = ""
            if task.subtasks and #task.subtasks > 0 then
                suffix = " [" .. doneBranch .. "/" .. totalBranch .. "]"
            end

            local lineStart = 6
            local treeText = treePrefix .. marker .. " "
            local maxTextW = editX - lineStart - 1
            if maxTextW < 1 then maxTextW = 1 end

            local label = truncate(treeText .. task.text .. suffix, maxTextW)

            local textColor = colors.white
            if isSelected then
                textColor = colors.yellow
            end

            writeAt(lineStart, y, label, textColor, rowBg)

            local pathCopy3 = copyPath(row.path)
            registerHitbox(lineStart, editX - 1, y, y, function()
                playTone(false)
                if selectedPath and pathEquals(selectedPath, pathCopy3) then
                    toggleExpanded(pathCopy3)
                else
                    selectedPath = pathCopy3
                end
            end)
        end
    end

    local guideLabel = " GUIDE "
    local archiveLabel = " ARCH "
    local archiveDoneLabel = " ARCHIVE DONE "

    writeAt(2, h, guideLabel, colors.black, colors.orange)
    registerHitbox(2, 2 + #guideLabel - 1, h, h, function()
        playTone(true)
        currentPage = "GUIDE"
    end)

    local archX = 2 + #guideLabel + 1
    writeAt(archX, h, archiveLabel, colors.white, colors.blue)
    registerHitbox(archX, archX + #archiveLabel - 1, h, h, function()
        playTone(true)
        archiveScrollOffset = 0
        currentPage = "ARCHIVE"
    end)

    local archiveDoneX = w - #archiveDoneLabel - 1
    writeAt(archiveDoneX, h, archiveDoneLabel, colors.black, colors.lime)
    registerHitbox(archiveDoneX, archiveDoneX + #archiveDoneLabel - 1, h, h, function()
        playTone(true)
        archiveCompletedBranches()
    end)
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

    if inputMode == "EDIT" then
        writeAt(2, 1, "Edit task:", colors.orange, colors.gray)
    else
        writeAt(2, 1, "New task:", colors.orange, colors.gray)
    end

    local targetName = "ROOT"
    if inputMode == "EDIT" then
        local t = getTaskByPath(editingPath, todoList)
        if t then targetName = t.text end
        writeAt(2, 2, truncate("Editing: " .. targetName, w - 4), colors.yellow, colors.gray)
    else
        if inputTargetPath then
            local parent = getTaskByPath(inputTargetPath, todoList)
            if parent then targetName = parent.text end
        end
        writeAt(2, 2, truncate("Parent: " .. targetName, w - 4), colors.yellow, colors.gray)
    end

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

    fill(2, bY, 5, 1, colors.orange)
    writeAt(3, bY, "<-", colors.black, colors.orange)
    registerHitbox(2, 6, bY, bY, function()
        playTone(false)
        currentInput = currentInput:sub(1, -2)
    end)

    if inputMode == "ADD" then
        local rootLabel = "ROOT"
        local rootX = math.floor(w / 2) - 10
        fill(rootX - 1, bY, #rootLabel + 2, 1, colors.blue)
        writeAt(rootX, bY, rootLabel, colors.white, colors.blue)
        registerHitbox(rootX - 1, rootX + #rootLabel, bY, bY, function()
            playTone(false)
            inputTargetPath = nil
        end)
    end

    local canLabel = "CANCEL"
    local canX = math.floor(w / 2) - math.floor(#canLabel / 2)
    fill(canX - 1, bY, #canLabel + 2, 1, colors.red)
    writeAt(canX, bY, canLabel, colors.white, colors.red)
    registerHitbox(canX - 1, canX + #canLabel, bY, bY, function()
        playTone(true)
        currentInput = ""
        inputMode = "ADD"
        editingPath = nil
        currentPage = "TREE"
    end)

    local actionLabel = (inputMode == "EDIT") and "SAVE" or "ADD"
    local actionX = w - #actionLabel - 3
    fill(actionX - 1, bY, #actionLabel + 2, 1, colors.lime)
    writeAt(actionX, bY, actionLabel, colors.black, colors.lime)
    registerHitbox(actionX - 1, actionX + #actionLabel, bY, bY, function()
        local trimmed = currentInput:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" then
            playTone(true)
            if inputMode == "EDIT" then
                editTask(editingPath, trimmed)
            else
                addTask(trimmed)
            end
            currentInput = ""
            inputMode = "ADD"
            editingPath = nil
            currentPage = "TREE"
        end
    end)
end

-- ==========================================
-- RENDER
-- ==========================================
local function render()
    if currentPage == "TREE" then
        drawTreePage()
    elseif currentPage == "GUIDE" then
        drawGuidePage()
    elseif currentPage == "ARCHIVE" then
        drawArchivePage()
    elseif currentPage == "DELETE_CONFIRM" then
        drawDeleteConfirmPage()
    else
        drawKeyboardPage()
    end
end

-- ==========================================
-- INIT
-- ==========================================
loadTasks()
refreshParentStates(todoList)
refreshParentStates(archiveList)
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
