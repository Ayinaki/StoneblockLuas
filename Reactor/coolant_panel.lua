-- startup.lua
-- 3x3 master reactor overview
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

local function center(y, text, fg, bg)
    local x = math.max(1, math.floor((W - #text) / 2) + 1)
    writeAt(x, y, text, fg, bg)
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

local function box(x, y, w, h, title, titleCol)
    if w < 4 or h < 3 then return end

    writeAt(x, y, "+" .. string.rep("-", w - 2) .. "+", colors.gray, colors.black)
    for yy = y + 1, y + h - 2 do
        writeAt(x, yy, "|", colors.gray, colors.black)
        fill(x + 1, yy, w - 2, 1, colors.black)
        writeAt(x + w - 1, yy, "|", colors.gray, colors.black)
    end
    writeAt(x, y + h - 1, "+" .. string.rep("-", w - 2) .. "+", colors.gray, colors.black)

    if title and w > 4 then
        writeAt(x + 2, y, trim(title, w - 4), titleCol or colors.white, colors.black)
    end
end

local function bar(x, y, w, pct, col)
    pct = clamp(toNum(pct, 0), 0, 100)
    if w < 3 then return end

    writeAt(x, y, "[" .. string.rep("-", w - 2) .. "]", colors.gray, colors.black)
    local inner = w - 2
    local fillCount = math.floor(inner * pct / 100 + 0.5)

    if fillCount > 0 then
        mon.setCursorPos(x + 1, y)
        mon.setBackgroundColor(col)
        mon.write(string.rep(" ", fillCount))
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
    center(1, "MASTER REACTOR OVERVIEW", colors.white, colors.gray)

    local linkTxt, linkCol = linkState()
    writeAt(2, 2, "LINK " .. linkTxt, linkCol, colors.gray)

    local spin = ({"/","-","\\","|"})[(tick % 4) + 1]
    local mode = state.active and "RUN" or "SBY"
    local right = mode .. " " .. spin
    writeAt(W - #right, 2, right, state.active and colors.lime or colors.lightGray, colors.gray)
end

local function drawTopRow()
    local y = 5
    local gap = 1
    local boxW = math.floor((W - 4) / 3)
    local x1 = 2
    local x2 = x1 + boxW + gap
    local x3 = x2 + boxW + gap

    box(x1, y, boxW, 7, "SET BURN", colors.orange)
    writeAt(x1 + 2, y + 2, trim(string.format("%.2f mB/t", state.br), boxW - 4), pctColor(state.brPct), colors.black)
    writeAt(x1 + 2, y + 3, trim("MAX " .. math.floor(state.brMax + 0.5), boxW - 4), colors.white, colors.black)
    bar(x1 + 2, y + 5, boxW - 4, state.brPct, pctColor(state.brPct))

    box(x2, y, boxW, 7, "ACT BURN", colors.yellow)
    writeAt(x2 + 2, y + 2, trim(string.format("%.2f mB/t", state.actualBr), boxW - 4), pctColor(state.actualBrPct), colors.black)
    writeAt(x2 + 2, y + 3, trim("MAX " .. math.floor(state.actualBrPct + 0.5) .. "%", boxW - 4), colors.white, colors.black)
    bar(x2 + 2, y + 5, boxW - 4, state.actualBrPct, pctColor(state.actualBrPct))

    box(x3, y, boxW, 7, "THROUGHPUT", colors.red)
    writeAt(x3 + 2, y + 2, trim(math.floor(state.throughputPct + 0.5) .. "%", boxW - 4), pctColor(state.throughputPct), colors.black)
    writeAt(x3 + 2, y + 3, trim("SET MATCH", boxW - 4), colors.white, colors.black)
    bar(x3 + 2, y + 5, boxW - 4, state.throughputPct, pctColor(state.throughputPct))
end

local function drawMiddle()
    local y = 13

    local leftW = math.floor(W * 0.3)
    local centerW = math.floor(W * 0.36)
    local rightW = W - leftW - centerW - 4

    local x1 = 2
    local x2 = x1 + leftW + 1
    local x3 = x2 + centerW + 1

    box(x1, y, leftW, 8, "FLOW", colors.cyan)
    writeAt(x1 + 2, y + 2, trim("HEAT RATE", leftW - 4), colors.lightBlue, colors.black)
    writeAt(x1 + 2, y + 3, trim(tostring(math.floor(state.heatRate + 0.5)), leftW - 4), colors.lightBlue, colors.black)
    writeAt(x1 + 2, y + 5, trim("TMP " .. math.floor(state.temp + 0.5), leftW - 4), tempColor(state.temp), colors.black)
    writeAt(x1 + 2, y + 6, trim("DMG " .. math.floor(state.dmg + 0.5) .. "%", leftW - 4), pctColor(state.dmg), colors.black)

    box(x2, y, centerW, 8, "CORE STATUS", colors.cyan)
    local label, col = coreState()
    center(y + 2, trim(label, centerW - 4), col, colors.black)
    center(y + 4, trim("TEMP " .. math.floor(state.temp + 0.5), centerW - 4), tempColor(state.temp), colors.black)
    center(y + 5, trim("LOAD " .. math.floor(state.throughputPct + 0.5) .. "%", centerW - 4), pctColor(state.throughputPct), colors.black)

    box(x3, y, rightW, 8, "RESERVES", colors.cyan)
    writeAt(x3 + 2, y + 2, trim("COOL " .. math.floor(state.coolPct + 0.5) .. "%", rightW - 4), reserveColor(state.coolPct), colors.black)
    writeAt(x3 + 2, y + 3, trim("FUEL " .. math.floor(state.fuelPct + 0.5) .. "%", rightW - 4), reserveColor(state.fuelPct), colors.black)
    bar(x3 + 2, y + 5, rightW - 4, state.coolPct, reserveColor(state.coolPct))
    bar(x3 + 2, y + 6, rightW - 4, state.fuelPct, reserveColor(state.fuelPct))
end

local function drawFooter()
    local y = H - 4
    box(2, y, W - 2, 4, "STATUS LINE", colors.gray)

    local line1 = "BURN " .. string.format("%.2f", state.br) .. " / ACT " .. string.format("%.2f", state.actualBr)
    local line2 = "THR " .. math.floor(state.throughputPct + 0.5) .. "% | COOL " .. math.floor(state.coolPct + 0.5) .. "% | FUEL " .. math.floor(state.fuelPct + 0.5) .. "%"

    writeAt(4, y + 1, trim(line1, W - 6), colors.white, colors.black)
    writeAt(4, y + 2, trim(line2, W - 6), colors.lightGray, colors.black)
end

local function draw()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    drawHeader()
    drawTopRow()
    drawMiddle()
    drawFooter()
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
