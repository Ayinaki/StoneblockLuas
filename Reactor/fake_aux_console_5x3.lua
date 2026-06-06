-- fake_aux_console_5x3_v2.lua
-- Decorative retro crowded reactor console for a 5x3 monitor

local mon = peripheral.find("monitor") or term.current()
if mon.setTextScale then mon.setTextScale(0.5) end
term.redirect(mon)

local w, h = term.getSize()
local tick = 0

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

local function fill(x, y, ww, hh, bg)
  term.setBackgroundColor(bg)
  for yy = y, y + hh - 1 do
    if yy >= 1 and yy <= h then
      term.setCursorPos(x, yy)
      term.write(string.rep(" ", ww))
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
  term.setCursorPos(x, y)
  if fg then term.setTextColor(fg) end
  if bg then term.setBackgroundColor(bg) end
  term.write(t:sub(1, math.max(0, w - x + 1)))
end

local function center(y, t, fg, bg)
  t = clip(t, w)
  local x = math.max(1, math.floor((w - #t) / 2) + 1)
  writeAt(x, y, t, fg, bg)
end

local function box(x, y, ww, hh, title)
  if ww < 2 or hh < 2 then return end
  fill(x, y, ww, hh, BG)
  writeAt(x, y, "+" .. string.rep("-", ww - 2) .. "+", FRAME, BG)
  for yy = y + 1, y + hh - 2 do
    writeAt(x, yy, "|", FRAME, BG)
    writeAt(x + ww - 1, yy, "|", FRAME, BG)
  end
  writeAt(x, y + hh - 1, "+" .. string.rep("-", ww - 2) .. "+", FRAME, BG)
  if title then writeAt(x + 2, y, clip(title, ww - 4), TXT, BG) end
end

local function smallLamp(x, y, col, on)
  writeAt(x, y, " ", colors.black, on and col or BG)
end

local function toggleRow(x, y, label, state, accent)
  writeAt(x, y, clip(label, 10), DIM, BG)
  writeAt(x + 11, y, "[", FRAME, BG)
  writeAt(x + 12, y, state and "/" or "\\", state and accent or DIM, BG)
  writeAt(x + 13, y, "]", FRAME, BG)
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
  center(y + math.floor(hh / 2), clip(label, ww), colors.black, nil)
end

local function meter(x, y, ww, label, value, col)
  box(x, y, ww, 6, label)
  local inner = ww - 4
  local needle = math.max(0, math.min(inner - 1, math.floor((inner - 1) * value)))
  writeAt(x + 2, y + 2, string.rep("-", inner), DIM, BG)
  writeAt(x + 2 + needle, y + 2, "^", col, BG)
  writeAt(x + 2, y + 3, "0", DIM, BG)
  writeAt(x + math.floor(ww / 2), y + 3, "5", DIM, BG)
  writeAt(x + ww - 3, y + 3, "9", DIM, BG)
  writeAt(x + 2, y + 4, "LOAD " .. tostring(math.floor(value * 100)) .. "%", TXT, BG)
end

while true do
  w, h = term.getSize()
  tick = tick + 1

  term.setBackgroundColor(BG)
  term.clear()

  fill(1, 1, w, 3, FRAME)
  center(1, "AUXILIARY CONTROL CONSOLE / OVERRIDE DESK", TXT, FRAME)
  writeAt(2, 2, clip("LOCAL BUS READY", 18), GREEN, FRAME)
  local hdr = "RM-B / AUX"
  writeAt(w - #hdr - 1, 2, hdr, TXT, FRAME)

  local meterW = math.floor((w - 8) / 2)
  meter(2, 5, meterW, "REACT LOAD", (math.sin(tick * 0.12) + 1) / 2, CYAN)
  meter(meterW + 4, 5, meterW, "COOL FLOW", (math.cos(tick * 0.10) + 1) / 2, ORANGE)

  local leftW = 22
  local rightW = 22
  local centerX = leftW + 3
  local centerW = w - leftW - rightW - 4

  box(2, 12, leftW, 12, "FIELD TOGGLES")
  box(centerX, 12, centerW, 12, "STATUS LAMPS")
  box(centerX + centerW + 1, 12, rightW, 12, "SAFETY SELECT")

  local leftLabels = {
    "AUX FEED","DAMPER","VENT ISO","PUMP BYP","PURGE","GRID TIE"
  }
  for i = 1, #leftLabels do
    toggleRow(4, 14 + (i - 1) * 2, leftLabels[i], ((tick + i) % 3 ~= 0), CYAN)
  end

  local rightLabels = {
    "ROD HOLD","SHIM EN","ALARM RST","TRIP ARM","SCRUB EN","MAG LOCK"
  }
  for i = 1, #rightLabels do
    toggleRow(centerX + centerW + 3, 14 + (i - 1) * 2, rightLabels[i], ((tick + i) % 4 <= 1), ORANGE)
  end

  local lx = centerX + 3
  local ly = 14
  local lampCols = {CYAN, GREEN, YELLOW, RED, BLUE, MAG}
  local lampNames = {"BUS","AUX","VENT","TRIP","SYNC","ISO"}
  local idx = 1
  for r = 0, 2 do
    for c = 0, 3 do
      if idx <= 6 then
        local x = lx + c * 6
        local y = ly + r * 3
        smallLamp(x, y, lampCols[idx], ((tick + idx + r) % 3 ~= 0))
        writeAt(x + 2, y, lampNames[idx], idx == 4 and RED or DIM, BG)
        idx = idx + 1
      end
    end
  end

  writeAt(centerX + 3, 22, "LAMP BANK C / STATE MATRIX", DIM, BG)

  local lowerY = 25
  box(2, lowerY, w - 2, h - lowerY - 2, "MANUAL PANEL")

  local btnY = lowerY + 2
  tinyButton(4, btnY, 12, "LAMP", BLUE, colors.black)
  tinyButton(18, btnY, 12, "RESET", GREEN, colors.black)
  tinyButton(32, btnY, 12, "FIELD", ORANGE, colors.black)
  tinyButton(46, btnY, 12, "BYPASS", WHITE, colors.black)

  stripedBlock(w - 19, lowerY + 2, 15, 4, "SCRAM")

  local btnY2 = lowerY + 7
  tinyButton(4, btnY2, 10, "PURGE", YELLOW, colors.black)
  tinyButton(16, btnY2, 10, "VENT", CYAN, colors.black)
  tinyButton(28, btnY2, 10, "ACK", MAG, colors.black)
  tinyButton(40, btnY2, 10, "TEST", DIM, colors.black)

  writeAt(4, h - 1, clip("NO FIELD LINK / DECORATIVE AUXILIARY CONSOLE", w - 8), DIM, BG)

  sleep(0.28)
end
