-- startup.lua
-- 3x3 clean single-line reactor mimic board
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

local function lamp(x, y, on, onCol)
    writeAt(x, y, " ", colors.black, on and (onCol or colors.lime) or colors.gray)
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
    center(1, "REACTOR SINGLE LINE", colors.white, colors.gray)

    local linkTxt, linkCol = linkState()
    writeAt(2, 2, "LINK " .. linkTxt, linkCol, colors.gray)

    local st, stCol = coreState()
    local spin = ({"/","-","\\","|"})[(tick % 4) + 1]
    local txt = trim(st .. " " .. spin, 16)
    writeAt(W - #txt, 2, txt, stCol, colors.gray)
end

local function drawCoreBox(cx, cy)
    local lines = {
        "+-----------+",
        "| FISSION   |",
        "| REACTOR   |",
        "+-----------+",
    }
    for i = 1, #lines do
        center(cy + i - 1, lines[i], colors.cyan, colors.black)
    end
end

local function drawProcess()
    local cx = math.floor(W / 2)
    local cy = math.floor(H / 2) - 3
    local leftStart = 7
    local rightEnd = W - 6
    local coreLeft = cx - 6
    local coreRight = cx + 6
    local lineY = cy + 1

    writeAt(3, lineY - 2, "FUEL", colors.orange, colors.black)
    writeAt(3, lineY - 1, "SUPPLY", colors.orange, colors.black)
    lamp(5, lineY, state.fuelPct > 10, reserveColor(state.fuelPct))
    writeAt(3, lineY + 2, trim("F " .. math.floor(state.fuelPct + 0.5) .. "%", 8), reserveColor(state.fuelPct), colors.black)

    writeAt(W - 8, lineY - 2, "COOL", colors.cyan, colors.black)
    writeAt(W - 9, lineY - 1, "RETURN", colors.cyan, colors.black)
    lamp(W - 5, lineY, state.coolPct > 20, reserveColor(state.coolPct))
    writeAt(W - 9, lineY + 2, trim("C " .. math.floor(state.coolPct + 0.5) .. "%", 8), reserveColor(state.coolPct), colors.black)

    for x = leftStart, coreLeft - 2 do
        writeAt(x, lineY, "=", colors.orange, colors.black)
    end
    writeAt(coreLeft - 1, lineY, ">", colors.orange, colors.black)

    for x = coreRight + 1, rightEnd - 2 do
        writeAt(x, lineY, "=", colors.red, colors.black)
    end
    writeAt(rightEnd - 1, lineY, ">", colors.red, colors.black)

    drawCoreBox(cx, cy)

    local pulse = state.active and ((tick % 6) < 3)
    if pulse then
        lamp(math.floor((leftStart + coreLeft) / 2), lineY, true, colors.orange)
        lamp(math.floor((coreRight + rightEnd) / 2), lineY, true, colors.red)
    else
        lamp(math.floor((leftStart + coreLeft) / 2), lineY, false, colors.orange)
        lamp(math.floor((coreRight + rightEnd) / 2), lineY, false, colors.red)
    end

    center(lineY + 4, trim(coreState(), 18), select(2, coreState()), colors.black)
    center(lineY + 6, trim("SET " .. string.format("%.2f", state.br) .. "   ACT " .. string.format("%.2f", state.actualBr), 28), colors.white, colors.black)
    center(lineY + 7, trim("LOAD " .. math.floor(state.throughputPct + 0.5) .. "%   FLOW " .. math.floor(state.heatRate + 0.5), 28), colors.lightBlue, colors.black)
    center(lineY + 8, trim("TEMP " .. math.floor(state.temp + 0.5) .. "   DMG " .. math.floor(state.dmg + 0.5) .. "%", 28), tempColor(state.temp), colors.black)
end

local function drawAlarmStrip()
    local y = H - 3
    fill(1, y, W, 3, colors.gray)

    local alarms = {
        {"TEMP", state.temp >= 5000, colors.red},
        {"COOL", state.coolPct < 20, colors.orange},
        {"FUEL", state.fuelPct < 10, colors.yellow},
        {"DMG", state.dmg > 20, colors.red},
        {"LOAD", state.active and state.throughputPct < 85, colors.orange},
        {"LINK", (os.clock() - state.lastUpdate) > 8, colors.red},
    }

    local x = 2
    for i = 1, #alarms do
        local a = alarms[i]
        lamp(x, y + 1, a[2], a[3])
        writeAt(x + 2, y + 1, a[1], a[2] and a[3] or colors.white, colors.gray)
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
    drawProcess()
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
