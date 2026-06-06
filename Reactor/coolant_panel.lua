-- startup.lua
-- 3x3 reactor mimic-flow board
-- Uses updated reactor bridge telemetry

local MODEM_CHANNEL = 42
local SCALE = 0.5

local mon = peripheral.find("monitor") or error("No monitor attached")
local modem = peripheral.find("modem") or error("No modem attached")

mon.setTextScale(SCALE)
local W, H = mon.getSize()

modem.open(MODEM_CHANNEL)

local state = {
    active = false,
    dmg = 0,
    temp = 0,
    heatRate = 0,

    br = 0,
    brMax = 0,
    brPct = 0,

    actualBr = 0,
    actualBrPct = 0,
    throughputPct = 0,

    fuelPct = 0,
    coolPct = 0,

    lastUpdate = 0,
}

local tick = 0

local function toNum(v, d)
    v = tonumber(v)
    if v == nil then return d or 0 end
    return v
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function writeAt(x, y, text, fg, bg)
    if y < 1 or y > H or x > W then return end
    text = tostring(text or "")
    if x < 1 then
        text = text:sub(2 - x)
        x = 1
    end
    if #text <= 0 then return end
    mon.setCursorPos(x, y)
    mon.setTextColor(fg or colors.white)
    mon.setBackgroundColor(bg or colors.black)
    mon.write(text:sub(1, W - x + 1))
end

local function center(y, text, fg, bg)
    local x = math.max(1, math.floor((W - #text) / 2) + 1)
    writeAt(x, y, text, fg, bg)
end

local function fill(x, y, w, h, bg)
    mon.setBackgroundColor(bg or colors.black)
    for yy = y, y + h - 1 do
        if yy >= 1 and yy <= H then
            mon.setCursorPos(math.max(1, x), yy)
            local drawW = math.max(0, math.min(w, W - x + 1))
            if drawW > 0 then
                mon.write(string.rep(" ", drawW))
            end
        end
    end
end

local function trim(text, w)
    text = tostring(text or "")
    if #text <= w then return text end
    if w <= 1 then return text:sub(1, w) end
    return text:sub(1, w - 1) .. ">"
end

local function pctColor(v)
    v = clamp(toNum(v, 0), 0, 100)
    if v >= 95 then return colors.red end
    if v >= 80 then return colors.orange end
    if v >= 50 then return colors.yellow end
    return colors.lime
end

local function reserveColor(v)
    v = clamp(toNum(v, 0), 0, 100)
    if v < 10 then return colors.red end
    if v < 25 then return colors.orange end
    if v < 50 then return colors.yellow end
    return colors.lime
end

local function tempColor(v)
    v = toNum(v, 0)
    if v >= 5000 then return colors.red end
    if v >= 3500 then return colors.orange end
    if v >= 2000 then return colors.yellow end
    return colors.lime
end

local function linkState()
    local age = os.clock() - state.lastUpdate
    if age < 2 then
        return "LIVE", colors.lime
    elseif age < 8 then
        return "STAL", colors.orange
    else
        return "DOWN", colors.red
    end
end

local function coreState()
    if os.clock() - state.lastUpdate > 8 then
        return "LINK LOST", colors.red
    end
    if not state.active then
        return "STANDBY", colors.lightGray
    end
    if state.temp >= 5000 or state.dmg >= 50 then
        return "CRITICAL", colors.red
    end
    if state.coolPct < 20 or state.fuelPct < 10 or state.throughputPct < 85 or state.dmg > 20 then
        return "WARNING", colors.orange
    end
    return "ONLINE", colors.lime
end

local function lamp(x, y, on, onCol, offCol)
    local bg = on and (onCol or colors.lime) or (offCol or colors.gray)
    writeAt(x, y, " ", colors.black, bg)
end

local function hLine(x1, x2, y, text, col)
    if x2 < x1 then return end
    for x = x1, x2 do
        writeAt(x, y, "-", col or colors.gray, colors.black)
    end
    if text and #text > 0 then
        local tx = math.max(x1, math.floor((x1 + x2 - #text) / 2))
        writeAt(tx, y, text, col or colors.gray, colors.black)
    end
end

local function vLine(x, y1, y2, col)
    if y2 < y1 then return end
    for y = y1, y2 do
        writeAt(x, y, "|", col or colors.gray, colors.black)
    end
end

local function applyPacket(msg)
    if type(msg) ~= "table" then return end
    if msg.type ~= "reactor_data" then return end
    if type(msg.data) ~= "table" then return end

    local d = msg.data

    state.active = d.active and true or false
    state.dmg = toNum(d.dmg, 0)
    state.temp = toNum(d.temp, 0)
    state.heatRate = toNum(d.heatRate, 0)

    state.br = toNum(d.br, 0)
    state.brMax = toNum(d.brMax, 0)
    state.brPct = toNum(d.brPct, 0)

    state.actualBr = toNum(d.actualBr, state.br)
    state.actualBrPct = toNum(d.actualBrPct, state.brPct)

    if d.throughputPct ~= nil then
        state.throughputPct = toNum(d.throughputPct, 0)
    else
        if state.br > 0 then
            state.throughputPct = clamp((state.actualBr / state.br) * 100, 0, 100)
        else
            state.throughputPct = 0
        end
    end

    state.fuelPct = toNum(d.fuelPct, 0)
    state.coolPct = toNum(d.coolPct, 0)

    state.lastUpdate = os.clock()
end

local function drawHeader()
    fill(1, 1, W, 3, colors.gray)
    center(1, "REACTOR MIMIC BOARD", colors.white, colors.gray)

    local linkTxt, linkCol = linkState()
    writeAt(2, 2, "LINK " .. linkTxt, linkCol, colors.gray)

    local modeTxt, modeCol = coreState()
    local spin = ({"/","-","\\","|"})[(tick % 4) + 1]
    local right = trim(modeTxt .. " " .. spin, 16)
    writeAt(W - #right, 2, right, modeCol, colors.gray)
end

local function drawDiagram()
    local top = 6
    local midY = 12
    local leftX = 8
    local coreX = math.floor(W / 2)
    local rightX = W - 9

    writeAt(leftX - 3, top,  "FUEL", colors.orange, colors.black)
    writeAt(leftX - 4, top+1,"INLET", colors.orange, colors.black)
    lamp(leftX - 1, top + 3, state.fuelPct > 10, reserveColor(state.fuelPct), colors.gray)
    writeAt(leftX - 4, top + 5, trim(math.floor(state.fuelPct + 0.5) .. "%", 6), reserveColor(state.fuelPct), colors.black)

    hLine(leftX + 1, coreX - 8, midY, "FUEL FEED", colors.orange)
    writeAt(coreX - 8, midY, ">", colors.orange, colors.black)

    local coreLabel, coreCol = coreState()
    writeAt(coreX - 5, midY - 3, "+---------+", colors.cyan, colors.black)
    writeAt(coreX - 5, midY - 2, "|REACTOR  |", colors.cyan, colors.black)
    writeAt(coreX - 5, midY - 1, "|  CORE   |", colors.cyan, colors.black)
    writeAt(coreX - 5, midY,     "+---------+", colors.cyan, colors.black)
    center(midY + 2, trim(coreLabel, 12), coreCol, colors.black)

    writeAt(coreX - 4, midY + 4, trim("TMP " .. math.floor(state.temp + 0.5), 10), tempColor(state.temp), colors.black)
    writeAt(coreX - 4, midY + 5, trim("DMG " .. math.floor(state.dmg + 0.5) .. "%", 10), pctColor(state.dmg), colors.black)

    hLine(coreX + 7, rightX - 2, midY, "HOT LOOP", colors.red)
    writeAt(rightX - 2, midY, ">", colors.red, colors.black)

    writeAt(rightX - 3, top,  "COOL", colors.cyan, colors.black)
    writeAt(rightX - 4, top+1,"LOOP", colors.cyan, colors.black)
    lamp(rightX + 1, top + 3, state.coolPct > 20, reserveColor(state.coolPct), colors.gray)
    writeAt(rightX - 4, top + 5, trim(math.floor(state.coolPct + 0.5) .. "%", 6), reserveColor(state.coolPct), colors.black)

    writeAt(rightX - 5, midY + 2, "TURB", colors.lightBlue, colors.black)
    writeAt(rightX - 5, midY + 3, "SINK", colors.lightBlue, colors.black)

    local returnY = midY + 7
    hLine(rightX - 2, coreX + 7, returnY, "COOL RETURN", colors.cyan)
    writeAt(coreX + 7, returnY, "<", colors.cyan, colors.black)

    local flowActive = state.active and state.throughputPct > 0
    local pulse = (tick % 6) < 3

    if flowActive and pulse then
        lamp(math.floor((leftX + coreX) / 2), midY, true, colors.orange, colors.gray)
        lamp(math.floor((coreX + rightX) / 2), midY, true, colors.red, colors.gray)
        lamp(math.floor((coreX + rightX) / 2), returnY, true, colors.cyan, colors.gray)
    else
        lamp(math.floor((leftX + coreX) / 2), midY, false, colors.orange, colors.gray)
        lamp(math.floor((coreX + rightX) / 2), midY, false, colors.red, colors.gray)
        lamp(math.floor((coreX + rightX) / 2), returnY, false, colors.cyan, colors.gray)
    end
end

local function drawSideStats()
    local y = H - 8

    writeAt(3, y,     "SET", colors.orange, colors.black)
    writeAt(3, y + 1, trim(string.format("%.2f", state.br), 8), colors.white, colors.black)
    writeAt(3, y + 2, "ACT", colors.yellow, colors.black)
    writeAt(3, y + 3, trim(string.format("%.2f", state.actualBr), 8), colors.white, colors.black)

    local tx = W - 11
    writeAt(tx, y,     "LOAD", colors.red, colors.black)
    writeAt(tx, y + 1, trim(math.floor(state.throughputPct + 0.5) .. "%", 8), pctColor(state.throughputPct), colors.black)
    writeAt(tx, y + 2, "FLOW", colors.lightBlue, colors.black)
    writeAt(tx, y + 3, trim(tostring(math.floor(state.heatRate + 0.5)), 8), colors.lightBlue, colors.black)
end

local function drawAlarmStrip()
    local y = H - 3
    fill(1, y, W, 3, colors.gray)

    local a1 = state.temp >= 5000
    local a2 = state.coolPct < 20
    local a3 = state.fuelPct < 10
    local a4 = state.dmg > 20
    local a5 = state.throughputPct < 85 and state.active
    local a6 = (os.clock() - state.lastUpdate) > 8

    local alarms = {
        {"TEMP", a1, colors.red},
        {"COOL", a2, colors.orange},
        {"FUEL", a3, colors.yellow},
        {"DMG",  a4, colors.red},
        {"LOAD", a5, colors.orange},
        {"LINK", a6, colors.red},
    }

    local x = 2
    for i = 1, #alarms do
        local name, on, col = alarms[i][1], alarms[i][2], alarms[i][3]
        lamp(x, y + 1, on, col, colors.black)
        writeAt(x + 2, y + 1, name, on and col or colors.white, colors.gray)
        x = x + 8
        if x > W - 6 then break end
    end

    local summary = "TMP " .. math.floor(state.temp + 0.5) ..
                    "  COOL " .. math.floor(state.coolPct + 0.5) .. "%" ..
                    "  FUEL " .. math.floor(state.fuelPct + 0.5) .. "%" ..
                    "  THR " .. math.floor(state.throughputPct + 0.5) .. "%"
    writeAt(2, y + 2, trim(summary, W - 2), colors.lightGray, colors.gray)
end

local function draw()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    drawHeader()
    drawDiagram()
    drawSideStats()
    drawAlarmStrip()
end

while true do
    tick = tick + 1

    local timer = os.startTimer(0.15)
    while true do
        local ev, a, b, c, d, e = os.pullEvent()
        if ev == "modem_message" then
            local side, ch, replyCh, msg, dist = a, b, c, d, e
            if ch == MODEM_CHANNEL then
                applyPacket(msg)
            end
        elseif ev == "timer" and a == timer then
            break
        end
    end

    draw()
end
