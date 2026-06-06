-- aux_console_rotate_5x3.lua
-- 5x3 retro control console + rotating standby screen
-- switches views every 30 seconds

local mon = peripheral.find("monitor") or term.current()
if mon.setTextScale then mon.setTextScale(0.5) end

local w, h
local tick = 0
local bootClock = os.clock()

local BG = colors.black
local FRAME = colors.gray
local TXT = colors.white
local DIM = colors.lightGray
local RED = colors.red
local ORANGE = colors.orange
local YELLOW = colors.yellow
local GREEN = colors.lime
local CYAN = colors.cyan
local BLUE = colors.lightBlue
local MAG = colors.pink
local WHITE = colors.white

local function refreshSize()
  w, h = mon.getSize()
end

local function fill(x, y, ww, hh, bg)
  mon.setBackgroundColor(bg)
  for yy = y, y + hh - 1 do
    if yy >= 1 and yy <= h then
      mon.setCursorPos(x, yy)
      mon.write(string.rep(" ", math.max(0, math.min(ww, w - x + 1))))
    end
  end
end

local function clip(txt, maxLen)
  txt = tostring(txt or "")
  if maxLen <= 0 then return "" end
  if #txt <= maxLen then return txt end
  if maxLen == 1 then return txt:sub(1, 1) end
  return txt:sub(1, maxLen - 1) .. ">"
end

local function writeAt(x, y, t, fg, bg)
  if y < 1 or y > h or x > w then return end
  t = tostring(t or "")
  if x < 1 then
    t = t:sub(2 - x)
    x = 1
  end
  if #t <= 0 then return end
  mon.setCursorPos(x, y)
  if fg then mon.setTextColor(fg) end
  if bg then mon.setBackgroundColor(bg) end
  mon.write(t:sub(1, math.max(0, w - x + 1)))
end

local function center(y, t, fg, bg)
  t = clip(t, w)
  local x = math.max(1, math.floor((w - #t) / 2) + 1)
  writeAt(x, y, t, fg, bg)
end

local function box(x, y, ww, hh, title)
  if ww < 2 or hh < 2 then return end
  writeAt(x, y, "+" .. string.rep(ww - 2 >= 0 and (ww - 2) or 0, "-") .. "+", FRAME, BG)
  for yy = y + 1, y + hh - 2 do
    writeAt(x, yy, "|", FRAME, BG)
    writeAt(x + ww - 1, yy, "|", FRAME, BG)
  end
  writeAt(x, y + hh - 1, "+" .. string.rep(ww - 2 >= 0 and (ww - 2) or 0, "-") .. "+", FRAME, BG)
  if title then writeAt(x + 2, y, clip(title, ww - 4), TXT, BG) end
end

local function meter(x, y, ww, label, value, col)
  value = math.max(0, math.min(1, value))
  box(x, y, ww, 6, label)
  local inner = ww - 4
  local needle = math.max(0, math.min(inner - 1, math.floor((inner - 1) * value)))
  writeAt(x + 2, y + 2, string.rep("-", inner), DIM, BG)
  writeAt(x + 2 + needle, y + 2, "^", col, BG)
  writeAt(x + 2, y + 3, "0", DIM, BG)
  writeAt(x + math.floor(ww / 2), y + 3, "5", DIM, BG)
  writeAt(x + ww - 3, y + 3, "9", DIM, BG)
  writeAt(x + 2, y + 4, clip("LOAD " .. tostring(math.floor(value * 100)) .. "%", ww - 4), TXT, BG)
end

local function smallLamp(x, y, col, on, label)
  writeAt(x, y, " ", colors.black, on and col or BG)
  writeAt(x + 2, y, clip(label, 4), on and (label == "TRIP" and RED or TXT) or DIM, BG)
end

local function toggleRow(x, y, label, state, accent)
  writeAt(x, y, clip(label, 8), DIM, BG)
  writeAt(x + 9, y, "[", FRAME, BG)
  writeAt(x + 10, y, state and "/" or "\\", state and accent or DIM, BG)
  writeAt(x + 11, y, "]", FRAME, BG)
end

local function tinyButton(x, y, ww, label, bg, fg)
  fill(x, y, ww, 2, bg)
  writeAt(x + 1, y, clip(label, ww - 2), fg or TXT, bg)
end

local function stripedBlock(x, y, ww, hh, label)
  for yy = 0, hh - 1 do
    for xx = 0, ww - 1 do
      local c = ((xx + yy + tick) % 4 < 2) and RED or YELLOW
      writeAt(x + xx, y + yy, " ", nil, c)
    end
  end
  local tx = x + math.max(0, math.floor((ww - #label) / 2))
  local ty = y + math.floor(hh / 2)
  writeAt(tx, ty, clip(label, ww), colors.black, nil)
end

local function fmtTime()
  return textutils.formatTime(os.time(), false)
end

local function uptimeText()
  local s = math.floor(os.clock() - bootClock)
  local hh = math.floor(s / 3600)
  local mm = math.floor((s % 3600) / 60)
  local ss = s % 60
  return string.format("%02d:%02d:%02d", hh, mm, ss)
end

local function drawConsole()
  mon.setBackgroundColor(BG)
  mon.clear()

  fill(1, 1, w, 3, FRAME)
  center(1, "AUXILIARY CONTROL CONSOLE / OVERRIDE DESK", TXT, FRAME)
  writeAt(2, 2, clip("LOCAL BUS READY", 16), GREEN, FRAME)
  local hdr = "RM-B / AUX"
  writeAt(w - #hdr - 1, 2, hdr, TXT, FRAME)

  local meterW = math.floor((w - 8) / 2)
  meter(2, 5, meterW, "REACT LOAD", (math.sin(tick * 0.12) + 1) / 2, CYAN)
  meter(meterW + 4, 5, meterW, "COOL FLOW", (math.cos(tick * 0.10) + 1) / 2, ORANGE)

  local leftW = 20
  local rightW = 20
  local centerX = leftW + 3
  local centerW = w - leftW - rightW - 4

  box(2, 12, leftW, 12, "FIELD TOG")
  box(centerX, 12, centerW, 12, "STATUS")
  box(centerX + centerW + 1, 12, rightW, 12, "SAFETY")

  local leftLabels = {"AUX FEED","DAMPER","VENT ISO","PUMP BYP","PURGE"}
  for i = 1, #leftLabels do
    toggleRow(4, 14 + (i - 1) * 2, leftLabels[i], ((tick + i) % 3 ~= 0), CYAN)
  end

  local rightLabels = {"ROD HOLD","SHIM EN","ALM RST","TRIP ARM","SCRUB EN"}
  for i = 1, #rightLabels do
    toggleRow(centerX + centerW + 3, 14 + (i - 1) * 2, rightLabels[i], ((tick + i) % 4 <= 1), ORANGE)
  end

  local lx = centerX + 3
  smallLamp(lx,      14, CYAN,   true,              "BUS")
  smallLamp(lx + 8,  14, GREEN,  tick % 2 == 0,     "AUX")
  smallLamp(lx + 16, 14, YELLOW, true,              "VENT")
  smallLamp(lx + 25, 14, RED,    tick % 4 == 0,     "TRIP")
  smallLamp(lx + 3,  18, BLUE,   true,              "SYNC")
  smallLamp(lx + 13, 18, MAG,    tick % 5 ~= 0,     "ISO")

  writeAt(centerX + 3, 22, clip("BANK C / MATRIX", centerW - 4), DIM, BG)

  local lowerY = 25
  box(2, lowerY, w - 2, h - lowerY - 2, "MANUAL PANEL")

  local btnY = lowerY + 2
  tinyButton(4,  btnY, 12, "LAMP",   BLUE,   colors.black)
  tinyButton(18, btnY, 12, "RESET",  GREEN,  colors.black)
  tinyButton(32, btnY, 12, "FIELD",  ORANGE, colors.black)
  tinyButton(46, btnY, 12, "BYPASS", WHITE,  colors.black)

  stripedBlock(w - 19, lowerY + 2, 15, 4, "SCRAM")

  local btnY2 = lowerY + 7
  tinyButton(4,  btnY2, 10, "PURGE", YELLOW, colors.black)
  tinyButton(16, btnY2, 10, "VENT",  CYAN,   colors.black)
  tinyButton(28, btnY2, 10, "ACK",   MAG,    colors.black)
  tinyButton(40, btnY2, 10, "TEST",  DIM,    colors.black)

  writeAt(4, h - 1, clip("NO FIELD LINK / AUXILIARY CONSOLE", w - 8), DIM, BG)
end

local function drawStandby()
  mon.setBackgroundColor(BG)
  mon.clear()

  fill(1, 1, w, 3, FRAME)
  center(1, "AUXILIARY CONSOLE / STATUS VIEW", TXT, FRAME)
  writeAt(2, 2, clip("SYSTEM STABLE", 16), GREEN, FRAME)
  local hdr = "AUTO CYCLE"
  writeAt(w - #hdr - 1, 2, hdr, TXT, FRAME)

  local t = fmtTime()
  local day = "DAY " .. tostring(os.day())

  box(3, 6, w - 4, 11, "STANDBY")
  center(9, t, CYAN, BG)
  center(11, day, DIM, BG)

  local leftW = math.floor((w - 6) / 2)
  local rightX = leftW + 4

  box(2, 19, leftW, 10, "PLANT STATS")
  writeAt(4, 21, "REACT " .. tostring(math.floor(((math.sin(tick * 0.08)+1)/2)*100)) .. "%", TXT, BG)
  writeAt(4, 23, "COOL  " .. tostring(math.floor(((math.cos(tick * 0.06)+1)/2)*100)) .. "%", TXT, BG)
  writeAt(4, 25, "VENT  " .. tostring(math.floor(((math.sin(tick * 0.05)+1)/2)*100)) .. "%", TXT, BG)
  writeAt(4, 27, "UP    " .. uptimeText(), DIM, BG)

  box(rightX, 19, w - rightX - 1, 10, "GRID STATE")
  writeAt(rightX + 2, 21, "BUS A  READY", GREEN, BG)
  writeAt(rightX + 2, 23, "BUS B  READY", GREEN, BG)
  writeAt(rightX + 2, 25, "AUX C  STBY ", YELLOW, BG)
  writeAt(rightX + 2, 27, "SYNC   LOCK ", CYAN, BG)

  box(2, 31, w - 2, h - 32, "CHANNELS")
  local baseX = 4
  for i = 0, math.min(5, math.floor((w - 8) / 12)) do
    local pct = math.floor(((math.sin(tick * 0.12 + i) + 1) / 2) * 100)
    writeAt(baseX + i * 12, 33, "CH" .. tostring(i + 1), DIM, BG)
    writeAt(baseX + i * 12, 34, tostring(pct) .. "%", TXT, BG)
  end
end

while true do
  refreshSize()
  tick = tick + 1

  local phase = math.floor((os.clock() - bootClock) / 30) % 2
  if phase == 0 then
    drawConsole()
  else
    drawStandby()
  end

  sleep(0.25)
end
