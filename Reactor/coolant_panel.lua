-- coolant_panel.lua
-- 3x3 placebo coolant routing panel
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

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function toNum(v, d)
    v = tonumber(v)
    if v == nil then return d or 0 end
    return v
end

local function writeAt(x, y, text, fg, bg)
    if y < 1 or y > H or x > W then return end
    text = tostring(text or "")
    if x < 1 then
        text = text:sub(2 - x)
        x = 1
    end
    if #text == 0 then return end
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

local function box(x, y, w, h, fg, bg, title)
    if w < 2 or h < 2 then return end
    local top = "+" .. string.rep("-", w - 2) .. "+"
    local mid = "|" .. string.rep(" ", w - 2) .. "|"
    writeAt(x, y, top, fg, bg)
    for yy = y + 1, y + h - 2 do
        writeAt(x, yy, mid, fg, bg)
    end
    writeAt(x, y + h - 1, top, fg, bg)
    if title and #title < w - 3 then
        writeAt(x + 2, y, title, fg, bg)
    end
end

local function statusInfo()
    if state.temp >= 5000 or state.dmg >= 50 then
        return colors.pink, "EMERG"
    elseif state.active then
        if state.coolPct < 20 or state.wastePct > 99 or state.hotPct > 99 or state.dmg > 20 then
            return colors.orange, "WARN "
        end
        return colors.lime, "FLOW "
    else
        return colors.red, "IDLE "
    end
end

local function pulse(seed, speed)
    return math.floor(((math.sin((tick + seed) / speed) + 1) / 2) * 100)
end

local function pipeH(x1, x2, y, col, active)
    if x2 < x1 then x1, x2 = x2, x1 end
    for x = x1, x2 do
        local ch = "="
        if active and ((x + tick) % 6 == 0) then ch = ">" end
        writeAt(x, y, ch, col, colors.black)
    end
end

local function pipeV(x, y1, y2, col, active)
    if y2 < y1 then y1, y2 = y2, y1 end
    for y = y1, y2 do
        local ch = "|"
        if active and ((y + tick) % 5 == 0) then ch = "v" end
        writeAt(x, y, ch, col, colors.black)
    end
end

local function bar(x, y, w, label, pct, col)
    pct = clamp(toNum(pct, 0), 0, 100)
    local inner = math.max(1, w - 10)
    local fillCount = math.floor(inner * pct / 100)

    writeAt(x, y, string.format("%-7s[", label), colors.lightGray, colors.black)
    writeAt(x + 8, y, string.rep("-", inner) .. "]", colors.gray, colors.black)

    if fillCount > 0 then
        mon.setCursorPos(x + 8, y)
        mon.setBackgroundColor(col)
        mon.write(string.rep(" ", fillCount))
    end

    writeAt(x + 9 + inner, y, string.format("%3d%%", math.floor(pct + 0.5)), colors.white, colors.black)
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

local function drawHeader()
    local col, label = statusInfo()
    fill(1, 1, W, 3, colors.gray)
    center(1, "PRIMARY COOLANT ROUTING", colors.white, colors.gray)
    center(2, "REACTOR LOOP A / PLACEBO PANEL", colors.lightGray, colors.gray)

    writeAt(2, 3, "STATE: " .. label, col, colors.gray)

    local age = os.clock() - state.lastUpdate
    local linkText, linkColor = "NO FEED", colors.red
    if age < 2 then
        linkText, linkColor = "FEED OK", colors.lime
    elseif age < 8 then
        linkText, linkColor = "STALE", colors.orange
    end
    writeAt(W - 11, 3, linkText, linkColor, colors.gray)
end

local function drawCore()
    local top = 5
    local bottom = H - 7
    if bottom < top + 8 then return end

    local coreW, coreH = 18, 7
    local coreX = math.floor((W - coreW) / 2)
    local coreY = top + 4

    local pipeCol = colors.gray
    if state.active then pipeCol = colors.cyan end
    if state.coolPct < 20 or state.dmg > 20 then pipeCol = colors.orange end
    if state.temp >= 5000 or state.dmg >= 50 then pipeCol = colors.red end

    local coreCol = colors.gray
    if state.active then coreCol = colors.lime end
    if state.dmg > 20 then coreCol = colors.orange end
    if state.temp >= 5000 or state.dmg >= 50 then coreCol = colors.red end

    box(coreX, coreY, coreW, coreH, colors.lightBlue, colors.black, "CORE")
    fill(coreX + 5, coreY + 2, coreW - 10, coreH - 4, coreCol)

    if state.active then
        center(coreY + 3, "ACTIVE", colors.black, coreCol)
    else
        center(coreY + 3, "STANDBY", colors.black, coreCol)
    end

    box(3, coreY + 1, 10, 5, colors.cyan, colors.black, "PUMP-A")
    box(W - 12, coreY + 1, 10, 5, colors.cyan, colors.black, "PUMP-B")
    box(coreX - 4, top, 12, 4, colors.lightGray, colors.black, "INLET")
    box(coreX + coreW - 7, bottom - 2, 12, 4, colors.lightGray, colors.black, "OUTLET")

    local cy = coreY + 3
    pipeH(13, coreX - 1, cy, pipeCol, state.active)
    pipeH(coreX + coreW, W - 13, cy, pipeCol, state.active)
    pipeV(coreX + math.floor(coreW / 2), top + 3, coreY - 1, pipeCol, state.active)
    pipeV(coreX + math.floor(coreW / 2), coreY + coreH, bottom - 1, pipeCol, state.active)

    local p1, p2
    if state.active then
        p1 = clamp(math.max(state.coolPct, pulse(0, 6)), 0, 100)
        p2 = clamp(math.max(state.coolPct - 2, pulse(8, 7)), 0, 100)
    else
        p1 = pulse(0, 11) // 6
        p2 = pulse(8, 12) // 6
    end

    writeAt(4, coreY + 3, state.active and "ON " or "SBY", state.active and colors.lime or colors.gray)
    writeAt(W - 10, coreY + 3, state.active and "ON " or "SBY", state.active and colors.lime or colors.gray)

    writeAt(3, coreY + 7, string.format("P-A FLOW  %3d%%", p1), colors.white, colors.black)
    writeAt(W - 16, coreY + 7, string.format("P-B FLOW  %3d%%", p2), colors.white, colors.black)

    local inletPct = state.active and clamp(math.floor(state.coolPct * 0.9 + state.brPct * 0.1), 0, 100) or 0
    local outletPct = state.active and clamp(math.floor(100 - state.wastePct * 0.6), 0, 100) or 0

    writeAt(coreX - 1, top + 4, string.format("IN %3d%%", inletPct), colors.cyan, colors.black)
    writeAt(coreX, bottom, string.format("OUT %3d%%", outletPct), colors.lightBlue, colors.black)
end

local function drawFooter()
    local y = H - 5
    if y < 1 then return end
    fill(1, y, W, 6, colors.black)

    bar(2, y, math.max(18, math.floor(W * 0.48)), "COOL", state.coolPct, colors.cyan)
    bar(math.floor(W * 0.52), y, math.max(18, W - math.floor(W * 0.52) - 1), "WASTE", state.wastePct, colors.brown)

    local heatPct = clamp(math.floor((state.temp / 5000) * 100), 0, 100)
    bar(2, y + 2, math.max(18, math.floor(W * 0.48)), "TEMP", heatPct, colors.orange)
    bar(math.floor(W * 0.52), y + 2, math.max(18, W - math.floor(W * 0.52) - 1), "HOT", state.hotPct, colors.red)

    local line = string.format(
        "BURN:%3d%%  FUEL:%3d%%  DMG:%3d%%  T:%4d",
        math.floor(state.brPct + 0.5),
        math.floor(state.fuelPct + 0.5),
        math.floor(state.dmg + 0.5),
        math.floor(state.temp + 0.5)
    )
    writeAt(2, H, line, colors.lightGray, colors.black)

    local spinner = ({"/","-","\\","|"})[(tick % 4) + 1]
    writeAt(W - 11, H, "FLOW " .. spinner, colors.cyan, colors.black)
end

local function draw()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    drawHeader()
    drawCore()
    drawFooter()
end

while true do
    tick = tick + 1

    local timer = os.startTimer(0.1)
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
