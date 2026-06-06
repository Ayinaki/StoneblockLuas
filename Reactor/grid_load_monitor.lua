-- grid_load_monitor.lua
-- 2x2 compact reactor load/status display
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

local function coolColor(v)
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

local function dmgColor(v)
    return pctColor(v)
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
    if state.coolPct < 20 or state.wastePct > 95 or state.hotPct > 95 or state.dmg > 20 then
        return "WARNING", colors.orange
    end
    return "ONLINE", colors.lime
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

local function box(x, y, w, h, title, titleCol)
    fill(x, y, w, h, colors.black)

    writeAt(x, y, "+" .. string.rep("-", math.max(0, w - 2)) .. "+", colors.gray, colors.black)
    for yy = y + 1, y + h - 2 do
        writeAt(x, yy, "|", colors.gray, colors.black)
        writeAt(x + w - 1, yy, "|", colors.gray, colors.black)
    end
    writeAt(x, y + h - 1, "+" .. string.rep("-", math.max(0, w - 2)) .. "+", colors.gray, colors.black)

    if title and w > 4 then
        writeAt(x + 2, y, trim(title, w - 4), titleCol or colors.white, colors.black)
    end
end

local function drawHeader()
    fill(1, 1, W, 3, colors.gray)
    center(1, "GRID LOAD", colors.white, colors.gray)

    local linkTxt, linkCol = linkState()
    writeAt(2, 2, "LINK " .. linkTxt, linkCol, colors.gray)

    local spin = ({"/","-","\\","|"})[(tick % 4) + 1]
    local mode = state.active and "RUN" or "SBY"
    local right = mode .. " " .. spin
    writeAt(W - #right, 2, right, state.active and colors.lime or colors.lightGray, colors.gray)
end

local function drawCenter()
    local label, col = coreState()
    local x = math.floor(W / 2) - 9
    local y = 5
    local w = 18
    local h = 7

    if x < 2 then x = 2 end
    if x + w - 1 > W - 1 then w = W - x end

    box(x, y, w, h, "REACTOR", colors.cyan)
    center(y + 2, trim(label, w - 4), col, colors.black)

    local tempTxt = "T " .. tostring(math.floor(state.temp + 0.5))
    local dmgTxt = "D " .. tostring(math.floor(state.dmg + 0.5)) .. "%"
    writeAt(x + 2, y + 4, trim(tempTxt, w - 4), tempColor(state.temp), colors.black)
    writeAt(x + 2, y + 5, trim(dmgTxt, w - 4), dmgColor(state.dmg), colors.black)
end

local function drawLeft()
    local x = 2
    local topY = 5
    local w = math.max(14, math.floor(W / 2) - 2)

    box(x, topY, w, 7, "BURN", colors.orange)
    writeAt(x + 2, topY + 2, trim(string.format("%3d%%", math.floor(state.brPct + 0.5)), w - 4), pctColor(state.brPct), colors.black)
    bar(x + 2, topY + 4, w - 4, state.brPct, pctColor(state.brPct))

    local botY = 13
    box(x, botY, w, 7, "COOL", colors.cyan)
    writeAt(x + 2, botY + 2, trim(string.format("%3d%%", math.floor(state.coolPct + 0.5)), w - 4), coolColor(state.coolPct), colors.black)
    bar(x + 2, botY + 4, w - 4, state.coolPct, coolColor(state.coolPct))
end

local function drawRight()
    local w = math.max(14, math.floor(W / 2) - 2)
    local x = W - w - 1
    local topY = 5

    box(x, topY, w, 7, "WASTE", colors.yellow)
    writeAt(x + 2, topY + 2, trim(string.format("%3d%%", math.floor(state.wastePct + 0.5)), w - 4), pctColor(state.wastePct), colors.black)
    bar(x + 2, topY + 4, w - 4, state.wastePct, pctColor(state.wastePct))

    local botY = 13
    box(x, botY, w, 7, "HEAT", colors.red)
    writeAt(x + 2, botY + 2, trim(string.format("%3d%%", math.floor(state.hotPct + 0.5)), w - 4), pctColor(state.hotPct), colors.black)
    bar(x + 2, botY + 4, w - 4, state.hotPct, pctColor(state.hotPct))
end

local function drawFooter()
    fill(1, H - 1, W, 2, colors.gray)

    local fuelTxt = "FUEL " .. math.floor(state.fuelPct + 0.5) .. "%"
    local dmgTxt = "DMG " .. math.floor(state.dmg + 0.5) .. "%"
    writeAt(2, H - 1, trim(fuelTxt, math.floor(W / 2) - 2), colors.lime, colors.gray)
    writeAt(2, H, trim(dmgTxt, math.floor(W / 2) - 2), dmgColor(state.dmg), colors.gray)

    local hr = math.floor(state.heatRate + 0.5)
    local temp = math.floor(state.temp + 0.5)
    local right1 = "HR " .. hr
    local right2 = "TMP " .. temp

    writeAt(W - #right1, H - 1, right1, colors.lightBlue, colors.gray)
    writeAt(W - #right2, H, right2, tempColor(state.temp), colors.gray)
end

local function draw()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    drawHeader()
    drawLeft()
    drawRight()
    drawCenter()
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
