-- alarm_terminal.lua
-- 1x3 placebo alarm/event terminal
-- Read-only listener for existing reactor-modem.lua packets

local MODEM_CHANNEL = 42
local SCALE = 0.5
local MAX_LOG = 18

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

local lastState = nil
local tick = 0
local log = {}

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

local function shortTime()
    local t = textutils.formatTime(os.time(), true)
    return t or "00:00"
end

local function trim(text, w)
    if #text <= w then return text end
    if w <= 1 then return text:sub(1, w) end
    return text:sub(1, w - 1) .. ">"
end

local function pushLog(level, text)
    local entry = {
        time = shortTime(),
        level = level,
        text = text,
    }
    table.insert(log, 1, entry)
    while #log > MAX_LOG do
        table.remove(log)
    end
end

local function levelColor(level)
    if level == "CRT" then return colors.red end
    if level == "WRN" then return colors.orange end
    if level == "ACK" then return colors.lime end
    if level == "INF" then return colors.lightBlue end
    return colors.white
end

local function currentStateLabel()
    if os.clock() - state.lastUpdate > 8 then
        return "LINK LOST", colors.red
    end
    if state.temp >= 5000 or state.dmg >= 50 then
        return "CRITICAL", colors.red
    end
    if state.active then
        if state.coolPct < 20 or state.wastePct > 95 or state.hotPct > 95 or state.dmg > 20 then
            return "WARNING", colors.orange
        end
        return "ONLINE", colors.lime
    end
    return "STANDBY", colors.lightGray
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

local function checkTransitions()
    if not lastState then
        lastState = {
            active = state.active,
            brPct = state.brPct,
            fuelPct = state.fuelPct,
            coolPct = state.coolPct,
            wastePct = state.wastePct,
            hotPct = state.hotPct,
            dmg = state.dmg,
            temp = state.temp,
            heatRate = state.heatRate,
        }
        pushLog("INF", "ALARM PANEL ONLINE")
        pushLog("INF", "MODEM LINK ESTABLISHED")
        return
    end

    if lastState.active ~= state.active then
        if state.active then
            pushLog("ACK", "CORE START COMMAND SEEN")
            pushLog("INF", "PRIMARY LOOP TRANSITION")
        else
            pushLog("WRN", "CORE ENTERED STANDBY")
            pushLog("INF", "POST-RUN COOLDOWN ROUTINE")
        end
    end

    if lastState.coolPct >= 20 and state.coolPct < 20 then
        pushLog("WRN", "COOLANT BELOW 20 PERCENT")
    end
    if lastState.coolPct >= 10 and state.coolPct < 10 then
        pushLog("CRT", "COOLANT BELOW 10 PERCENT")
    end

    if lastState.wastePct <= 80 and state.wastePct > 80 then
        pushLog("WRN", "WASTE BUFFER ABOVE 80")
    end
    if lastState.wastePct <= 95 and state.wastePct > 95 then
        pushLog("CRT", "WASTE BUFFER CRITICAL")
    end

    if lastState.hotPct <= 85 and state.hotPct > 85 then
        pushLog("WRN", "HOT LOOP LOAD HIGH")
    end
    if lastState.hotPct <= 95 and state.hotPct > 95 then
        pushLog("CRT", "HOT LOOP SATURATION")
    end

    if lastState.dmg <= 5 and state.dmg > 5 then
        pushLog("WRN", "CASING WEAR DETECTED")
    end
    if lastState.dmg <= 20 and state.dmg > 20 then
        pushLog("CRT", "STRUCTURAL DAMAGE RISING")
    end

    if lastState.temp <= 2500 and state.temp > 2500 then
        pushLog("WRN", "CORE TEMP ABOVE 2500")
    end
    if lastState.temp <= 4000 and state.temp > 4000 then
        pushLog("CRT", "CORE TEMP ABOVE 4000")
    end

    if math.abs(state.brPct - lastState.brPct) >= 15 then
        if state.brPct > lastState.brPct then
            pushLog("INF", "BURN RATE INCREASED")
        else
            pushLog("INF", "BURN RATE REDUCED")
        end
    end

    lastState.active = state.active
    lastState.brPct = state.brPct
    lastState.fuelPct = state.fuelPct
    lastState.coolPct = state.coolPct
    lastState.wastePct = state.wastePct
    lastState.hotPct = state.hotPct
    lastState.dmg = state.dmg
    lastState.temp = state.temp
    lastState.heatRate = state.heatRate
end

local function ambientLog()
    if tick % 20 ~= 0 then return end

    if os.clock() - state.lastUpdate > 8 then
        pushLog("WRN", "NO TELEMETRY FROM BRIDGE")
        return
    end

    if not state.active then
        local msgs = {
            "CORE IN STANDBY",
            "PUMP BANK A IDLE",
            "POST-RUN CHECK NOMINAL",
            "HEAT SINKS IN PASSIVE MODE",
            "GRID LOAD ROUTED AWAY",
            "ROUTING PANEL AWAITING LOAD",
        }
        pushLog("INF", msgs[(tick / 20) % #msgs + 1])
    else
        local msgs = {
            "LOOP A FLOW STABLE",
            "PUMP BANK B RESPONDING",
            "THERMAL GRADIENT NORMAL",
            "STEAM LEG PRESSURE STABLE",
            "CORE FEED WITHIN RANGE",
            "EVENT BUFFER FLUSHED",
        }
        pushLog("INF", msgs[(tick / 20) % #msgs + 1])
    end
end

local function drawHeader()
    fill(1, 1, W, 4, colors.gray)
    center(1, "ALARM", colors.white, colors.gray)
    center(2, "EVENT", colors.white, colors.gray)
    center(3, "TERM", colors.white, colors.gray)

    local label, col = currentStateLabel()
    writeAt(2, 4, trim(label, W - 2), col, colors.gray)
end

local function drawBody()
    local startY = 6
    local rows = H - 7
    if rows < 1 then return end

    for i = 1, rows do
        local y = startY + i - 1
        local entry = log[i]
        if entry then
            local col = levelColor(entry.level)
            local prefix = entry.level .. " " .. entry.time
            writeAt(1, y, trim(prefix, W), col, colors.black)
            if y + 1 <= H - 1 then
                writeAt(1, y + 1, trim(entry.text, W), colors.white, colors.black)
            end
            i = i + 1
        else
            writeAt(1, y, string.rep(".", math.min(W, 6)), colors.gray, colors.black)
        end
    end
end

local function drawFooter()
    fill(1, H, W, 1, colors.gray)
    local spinner = ({"/","-","\\","|"})[(tick % 4) + 1]
    local age = os.clock() - state.lastUpdate
    local link = age < 2 and "LIVE" or (age < 8 and "STAL" or "DOWN")
    local txt = spinner .. " " .. link
    writeAt(2, H, trim(txt, W - 1), colors.lightBlue, colors.gray)
end

local function draw()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    drawHeader()
    drawBody()
    drawFooter()
end

pushLog("INF", "BOOT SEQUENCE START")
pushLog("INF", "EVENT CACHE READY")

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

    checkTransitions()
    ambientLog()
    draw()
end
