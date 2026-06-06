-- coolant_panel.lua
-- 3x3 placebo coolant routing panel
-- Listens directly for reactor-modem.lua packets:
-- { type = "reactor_data", data = { active=..., dmg=..., temp=..., heatRate=..., brPct=..., fuelPct=..., wastePct=..., coolPct=..., hotPct=... } }

local ok, config = pcall(require, "config")
if not ok or type(config) ~= "table" then config = {} end

local MODEM_CHANNEL = tonumber(config.MODEM_CHANNEL) or 42
local MONITOR_SCALE = tonumber(config.MONITOR_SCALE) or 0.5

local monitor = peripheral.find("monitor") or error("No monitor attached")
local modem = peripheral.find("modem") or error("No modem attached")

monitor.setTextScale(MONITOR_SCALE)
local W, H = monitor.getSize()

local modemSide = peripheral.getName(modem)
modem.open(MODEM_CHANNEL)

local state = {
    active = false,
    dmg = 0,
    temp = 0,
    heatRate = 0,
    brPct = 0,
    fuelPct = 0,
    wastePct = 0,
    coolPct = 0,
    hotPct = 0,
    updatedAt = 0,
}

local tick = 0

local function clamp(v, a, b)
    if v == nil then return a end
    if v < a then return a end
    if v > b then return b end
    return v
end

local function n(v, default)
    v = tonumber(v)
    if v == nil then return default or 0 end
    return v
end

local function clear(bg)
    monitor.setBackgroundColor(bg or colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

local function writeAt(x, y, text, fg, bg)
    if y < 1 or y > H or x > W then return end
    text = tostring(text or "")
    if x < 1 then
        text = text:sub(2 - x)
        x = 1
    end
    if #text <= 0 then return end
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(bg or colors.black)
    monitor.setTextColor(fg or colors.white)
    monitor.write(text:sub(1, W - x + 1))
end

local function center(y, text, fg, bg)
    text = tostring(text or "")
    local x = math.max(1, math.floor((W - #text) / 2) + 1)
    writeAt(x, y, text, fg, bg)
end

local function fill(x, y, w, h, bg)
    if w <= 0 or h <= 0 then return end
    monitor.setBackgroundColor(bg or colors.black)
    for yy = y, y + h - 1 do
        if yy >= 1 and yy <= H then
            monitor.setCursorPos(math.max(1, x), yy)
            local drawW = math.max(0, math.min(w, W - x + 1))
            if drawW > 0 then
                monitor.write(string.rep(" ", drawW))
            end
        end
    end
end

local function box(x, y, w, h, fg, bg, title)
    if w < 2 or h < 2 then return end
    local top = "+" .. string.rep("-", math.max(0, w - 2)) .. "+"
    local mid = "|" .. string.rep(" ", math.max(0, w - 2)) .. "|"
    writeAt(x, y, top, fg, bg)
    for yy = y + 1, y + h - 2 do
        writeAt(x, yy, mid, fg, bg)
    end
    writeAt(x, y + h - 1, top, fg, bg)
    if title and #title < (w - 3) then
        writeAt(x + 2, y, title, fg, bg)
    end
end

local function statusInfo()
    if state.temp >= 5000 or state.dmg >= 50 then
        return colors.pink, "EMERG"
    elseif state.active then
        if state.coolPct < 20 or state.wastePct > 99 or state.dmg > 20 or state.hotPct > 99 then
            return colors.orange, "WARN "
        end
        return colors.lime, "NOMNL"
    else
        return colors.red, "OFFLN"
    end
end

local function pulseValue(seed, slow)
    local v = (math.sin((tick + seed) / slow) + 1) / 2
    return math.floor(v * 100)
end

local function drawPipeH(x1, x2, y, col, active, dir)
    if x2 < x1 then x1, x2 = x2, x1 end
    for x = x1, x2 do
        local ch = "="
        if active then
            if dir == "right" and ((x + tick) % 6 == 0) then ch = ">" end
            if dir == "left" and ((x + tick) % 6 == 0) then ch = "<" end
        end
        writeAt(x, y, ch, col, colors.black)
    end
end

local function drawPipeV(x, y1, y2, col, active)
    if y2 < y1 then y1, y2 = y2, y1 end
    for y = y1, y2 do
        local ch = "|"
        if active and ((y + tick) % 5 == 0) then ch = "v" end
        writeAt(x, y, ch, col, colors.black)
    end
end

local function drawBar(x, y, w, label, pct, barColor)
    pct = clamp(n(pct, 0), 0, 100)
    local inner = math.max(1, w - 10)
    local fillCount = math.floor(inner * pct / 100)
    writeAt(x, y, string.format("%-7s[", label), colors.lightGray, colors.black)
    writeAt(x + 8, y, string.rep("-", inner) .. "]", colors.gray, colors.black)
    if fillCount > 0 then
        monitor.setCursorPos(x + 8, y)
        monitor.setBackgroundColor(barColor)
        monitor.write(string.rep(" ", fillCount))
    end
    writeAt(x + 9 + inner, y, string.format("%3d%%", math.floor(pct + 0.5)), colors.white, colors.black)
end

local function drawHeader()
    local col, txt = statusInfo()
    fill(1, 1, W, 3, colors.gray)
    center(1, "PRIMARY COOLANT ROUTING", colors.white, colors.gray)
    center(2, "MIMIC PANEL // LOOP A-B", colors.lightGray, colors.gray)
    writeAt(2, 3, "STATE: " .. txt, col, colors.gray)

    local age = os.clock() - state.updatedAt
    local linkText, linkColor = "LINK LOST", colors.red
    if age < 3 then
        linkText, linkColor = "LINK LIVE", colors.lime
    elseif age < 8 then
        linkText, linkColor = "LINK STALE", colors.orange
    end
    writeAt(W - 13, 3, linkText, linkColor, colors.gray)
end

local function drawCoreArea()
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

    box(coreX, coreY, coreW, coreH, colors.lightBlue, colors.black, "REACTOR CORE")
    fill(coreX + 5, coreY + 2, coreW - 10, coreH - 4, coreCol)
    center(coreY + 3, state.active and "ACTIVE CORE" or "STANDBY", colors.black, coreCol)

    box(3, coreY + 1, 10, 5, colors.cyan, colors.black, "PUMP-A")
    box(W - 12, coreY + 1, 10, 5, colors.cyan, colors.black, "PUMP-B")
    box(coreX - 4, top, 12, 4, colors.lightGray, colors.black, "INLET VALVE")
    box(coreX + coreW - 7, bottom - 2, 12, 4, colors.lightGray, colors.black, "OUTLET VALVE")

    local cy = coreY + 3
    drawPipeH(13, coreX - 1, cy, pipeCol, state.active, "right")
    drawPipeH(coreX + coreW, W - 13, cy, pipeCol, state.active, "right")
    drawPipeV(coreX + math.floor(coreW / 2), top + 3, coreY - 1, pipeCol, state.active)
    drawPipeV(coreX + math.floor(coreW / 2), coreY + coreH, bottom - 1, pipeCol, state.active)

    local p1 = state.active and math.max(state.coolPct, pulseValue(0, 6)) or math.floor(pulseValue(0, 10) * 0.25)
    local p2 = state.active and math.max(state.coolPct - 2, pulseValue(8, 7)) or math.floor(pulseValue(8, 12) * 0.25)
    p1 = clamp(p1, 0, 100)
    p2 = clamp(p2, 0, 100)

    writeAt(4, coreY + 3, state.active and "ON " or "SBY", state.active and colors.lime or colors.gray)
    writeAt(W - 10, coreY + 3, state.active and "ON " or "SBY", state.active and colors.lime or colors.gray)

    writeAt(3, coreY + 7, string.format("P-A FLOW  %3d%%", p1), colors.white, colors.black)
    writeAt(W - 16, coreY + 7, string.format("P-B FLOW  %3d%%", p2), colors.white, colors.black)

    local inletPct = clamp(math.floor((state.coolPct * 0.9) + (state.brPct * 0.1)), 0, 100)
    local outletPct = clamp(math.floor(100 - state.wastePct * 0.6), 0, 100)

    writeAt(coreX - 1, top + 4, string.format("INLET %3d%%", inletPct), colors.cyan, colors.black)
    writeAt(coreX, bottom, string.format("OUT %3d%%", outletPct), colors.lightBlue, colors.black)
end

local function drawFooter()
    local y = H - 5
    if y < 1 then return end
    fill(1, y, W, 6, colors.black)

    drawBar(2, y, math.max(18, math.floor(W * 0.48)), "COOL", state.coolPct, colors.cyan)
    drawBar(math.floor(W * 0.52), y, math.max(18, W - math.floor(W * 0.52) - 1), "WASTE", state.wastePct, colors.brown)

    drawBar(2, y + 2, math.max(18, math.floor(W * 0.48)), "HEAT", math.min(100, state.temp / 50), colors.orange)
    drawBar(math.floor(W * 0.52), y + 2, math.max(18, W - math.floor(W * 0.52) - 1), "DMG", state.dmg, colors.red)

    local line = string.format("TMP:%4dF  BURN:%3d%%  FUEL:%3d%%  HOT:%3d%%",
        math.floor(n(state.temp, 0) + 0.5),
        math.floor(n(state.brPct, 0) + 0.5),
        math.floor(n(state.fuelPct, 0) + 0.5),
        math.floor(n(state.hotPct, 0) + 0.5)
    )
    writeAt(2, H, line, colors.lightGray, colors.black)

    local spinner = ({"/", "-", "\\", "|"})[(tick % 4) + 1]
    writeAt(W - 11, H, "FLOW " .. spinner, colors.cyan, colors.black)
end

local function draw()
    clear(colors.black)
    drawHeader()
    drawCoreArea()
    drawFooter()
end

local function applyPacket(msg)
    if type(msg) ~= "table" then return end
    if msg.type ~= "reactor_data" or type(msg.data) ~= "table" then return end

    local d = msg.data
    state.active   = d.active and true or false
    state.dmg      = n(d.dmg, 0)
    state.temp     = n(d.temp, 0)
    state.heatRate = n(d.heatRate, 0)
    state.brPct    = n(d.brPct, 0)
    state.fuelPct  = n(d.fuelPct, 0)
    state.wastePct = n(d.wastePct, 0)
    state.coolPct  = n(d.coolPct, 0)
    state.hotPct   = n(d.hotPct, 0)
    state.updatedAt = os.clock()
end

local function fakeIdle()
    if os.clock() - state.updatedAt > 8 then
        state.active = (tick % 30) < 18
        state.temp = 900 + pulseValue(1, 8) * 20
        state.coolPct = pulseValue(2, 10)
        state.wastePct = math.floor(pulseValue(4, 13) * 0.45)
        state.dmg = math.floor(pulseValue(7, 16) * 0.08)
        state.brPct = pulseValue(9, 11)
        state.fuelPct = 60 + math.floor(pulseValue(3, 14) * 0.35)
        state.hotPct = math.floor(pulseValue(6, 9) * 0.7)
    end
end

while true do
    tick = tick + 1

    while true do
        local event, side, channel, replyChannel, msg, distance = os.pullEventTimeout and os.pullEventTimeout(0.05, "modem_message") or nil
        if event == nil then break end
        if channel == MODEM_CHANNEL then
            applyPacket(msg)
        end
    end

    fakeIdle()
    draw()
    sleep(0.15)
end
