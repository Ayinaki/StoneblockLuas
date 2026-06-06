-- status_pillar.lua
-- 1x3 placebo reactor status pillar
-- Read-only listener for existing reactor-modem.lua packets

local MODEM_CHANNEL = 42
local SCALE = 0.5

local mon = peripheral.find("monitor") or error("No monitor attached")
local modem = peripheral.find("modem") or error("No modem attached")

mon.setTextScale(SCALE)
local W, H = mon.getSize()

modem.open(MODEM_CHANNEL)

local state = {
    active = false,
    brPct = 0,
    fuelPct = 0,
    coolPct = 0,
    wastePct = 0,
    hotPct = 0,
    dmg = 0,
    temp = 0,
    heatRate = 0,
    lastUpdate = 0,
}

local tick = 0

local function toNum(v, d)
    v = tonumber(v)
    if v == nil then return d or 0 end
    return v
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
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

local function padRight(text, width)
    text = tostring(text or "")
    if #text > width then
        return text:sub(1, width)
    end
    return text .. string.rep(" ", width - #text)
end

local function pctColor(v)
    v = clamp(toNum(v, 0), 0, 100)
    if v >= 95 then return colors.red end
    if v >= 75 then return colors.orange end
    if v >= 35 then return colors.yellow end
    return colors.lime
end

local function coolColor(v)
    v = clamp(toNum(v, 0), 0, 100)
    if v < 10 then return colors.red end
    if v < 25 then return colors.orange end
    if v < 50 then return colors.yellow end
    return colors.lime
end

local function tempColor(temp)
    temp = toNum(temp, 0)
    if temp >= 5000 then return colors.red end
    if temp >= 3500 then return colors.orange end
    if temp >= 2000 then return colors.yellow end
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
        return "----", colors.red
    end
    if not state.active then
        return "IDLE", colors.lightGray
    end
    if state.temp >= 5000 or state.dmg >= 50 then
        return "EMRG", colors.red
    end
    if state.coolPct < 20 or state.wastePct > 95 or state.hotPct > 95 or state.dmg > 20 then
        return "WARN", colors.orange
    end
    return "ONLN", colors.lime
end

local function drawLamp(y, label, value, col)
    fill(2, y, W - 2, 2, colors.black)
    writeAt(2, y, padRight(label, math.min(4, W - 2)), colors.lightGray, colors.black)

    local lampChar = " "
    local lampBg = colors.gray
    if value then
        lampBg = col
    end

    if W >= 6 then
        writeAt(W - 3, y, "  ", colors.black, lampBg)
        writeAt(W - 3, y + 1, "  ", colors.black, lampBg)
    else
        writeAt(W, y, " ", colors.black, lampBg)
        writeAt(W, y + 1, " ", colors.black, lampBg)
    end

    if W >= 5 then
        writeAt(2, y + 1, padRight(value and "ON" or "OFF", math.min(4, W - 2)), col, colors.black)
    end
end

local function drawValue(y, label, valueText, col)
    fill(2, y, W - 2, 2, colors.black)
    writeAt(2, y, padRight(label, math.min(4, W - 2)), colors.lightGray, colors.black)
    writeAt(2, y + 1, padRight(valueText, math.min(W - 2, 6)), col, colors.black)
end

local function tinyBar(y, label, pct, col)
    pct = clamp(toNum(pct, 0), 0, 100)
    fill(2, y, W - 2, 2, colors.black)
    writeAt(2, y, padRight(label, math.min(4, W - 2)), colors.lightGray, colors.black)

    if W >= 8 then
        local inner = W - 7
        local fillCount = math.floor(inner * pct / 100)
        writeAt(2, y + 1, "[", colors.gray, colors.black)
        writeAt(3, y + 1, string.rep("-", inner), colors.gray, colors.black)
        writeAt(3 + inner, y + 1, "]", colors.gray, colors.black)
        if fillCount > 0 then
            mon.setCursorPos(3, y + 1)
            mon.setBackgroundColor(col)
            mon.write(string.rep(" ", fillCount))
        end
    else
        writeAt(2, y + 1, string.format("%3d", math.floor(pct + 0.5)), col, colors.black)
    end
end

local function applyPacket(msg)
    if type(msg) ~= "table" then return end
    if msg.type ~= "reactor_data" then return end
    if type(msg.data) ~= "table" then return end

    local d = msg.data
    state.active   = d.active and true or false
    state.brPct    = toNum(d.brPct, 0)
    state.fuelPct  = toNum(d.fuelPct, 0)
    state.coolPct  = toNum(d.coolPct, 0)
    state.wastePct = toNum(d.wastePct, 0)
    state.hotPct   = toNum(d.hotPct, 0)
    state.dmg      = toNum(d.dmg, 0)
    state.temp     = toNum(d.temp, 0)
    state.heatRate = toNum(d.heatRate, 0)
    state.lastUpdate = os.clock()
end

local function draw()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    fill(1, 1, W, 3, colors.gray)
    center(1, "STAT", colors.white, colors.gray)
    center(2, "PILL", colors.white, colors.gray)

    local linkTxt, linkCol = linkState()
    local coreTxt, coreCol = coreState()

    writeAt(2, 3, padRight(linkTxt, math.min(4, W - 1)), linkCol, colors.gray)

    local y = 5

    drawValue(y, "CORE", coreTxt, coreCol)
    y = y + 3

    drawValue(y, "LINK", linkTxt, linkCol)
    y = y + 3

    drawLamp(y, "PUMP", state.active, state.active and colors.cyan or colors.gray)
    y = y + 3

    drawValue(y, "TEMP", tostring(math.floor(state.temp + 0.5)), tempColor(state.temp))
    y = y + 3

    tinyBar(y, "COOL", state.coolPct, coolColor(state.coolPct))
    y = y + 3

    tinyBar(y, "WSTE", state.wastePct, pctColor(state.wastePct))
    y = y + 3

    tinyBar(y, "HOT ", state.hotPct, pctColor(state.hotPct))
    y = y + 3

    tinyBar(y, "BURN", state.brPct, pctColor(state.brPct))
    y = y + 3

    drawValue(y, "DMG", tostring(math.floor(state.dmg + 0.5)), pctColor(state.dmg))
    y = y + 3

    if y <= H - 2 then
        local spin = ({"/","-","\\","|"})[(tick % 4) + 1]
        drawValue(y, "SYNC", spin, colors.lightBlue)
    end

    fill(1, H, W, 1, colors.gray)
    local bottom = state.active and "ON" or "SBY"
    writeAt(2, H, padRight(bottom, math.min(4, W - 1)), state.active and colors.lime or colors.lightGray, colors.gray)
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
