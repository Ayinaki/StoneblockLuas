-- fake_aux_console_5x3.lua
-- Decorative crowded button/switch console for a 5x3 monitor

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
local DARK = colors.gray

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

local function lamp(x, y, label, col, active)
  local bg = active and col or BG
  writeAt(x, y, "   ", colors.black, bg)
  writeAt(x, y + 1, clip(label, 5), active and col or DIM, BG)
end

local function button(x, y, ww, label, bg, fg)
  fill(x, y, ww, 3, bg)
  writeAt(x, y + 1, clip(label, ww), fg or TXT, bg)
end

local function toggle(x, y, label, state, col)
  writeAt(x, y, clip(label, 10), DIM, BG)
  writeAt(x + 11, y, "[", FRAME, BG)
  writeAt(x + 12, y, state and "/" or "\\", state and col or DIM, BG)
  writeAt(x + 13, y, "]", FRAME, BG)
end

while true do
  w, h = term.getSize()
  tick = tick + 1

  term.setBackgroundColor(BG)
  term.clear()

  fill(1, 1, w, 3, FRAME)
  center(1, "AUXILIARY REACTOR DESK / MANUAL OVERRIDE", TXT, FRAME)
  writeAt(2, 2, clip("CONSOLE BUS  READY", 24), GREEN, FRAME)
  local hdr = "BANK 7 / LOCAL"
  writeAt(w - #hdr - 1, 2, hdr, TXT, FRAME)

  local leftW = math.floor(w * 0.32)
  local rightW = leftW
  local midW = w - leftW - rightW - 4

  box(2, 5, leftW, 16, "SWITCH BANK A")
  box(leftW + 3, 5, midW, 16, "INDICATORS")
  box(leftW + midW + 4, 5, rightW, 16, "SWITCH BANK B")

  local leftLabels = {
    "COOL FEED", "DAMPER", "AUX VENT", "FIELD ISO",
    "PUMP BYP", "PURGE", "BUS TIE", "GRID SEL"
  }

  local rightLabels = {
    "ROD HOLD", "SHIM EN", "LAMP TST", "ALARM RST",
    "TRIP ARM", "DOOR MAG", "VENT FAN", "SCRUB EN"
  }

  for i = 1, #leftLabels do
    local y = 7 + (i - 1) * 2
    local state = ((tick + i) % 3 ~= 0)
    toggle(4, y, leftLabels[i], state, state and CYAN or DIM)
  end

  for i = 1, #rightLabels do
    local y = 7 + (i - 1) * 2
    local state = ((tick + i + 1) % 4 <= 1)
    toggle(leftW + midW + 6, y, rightLabels[i], state, state and ORANGE or DIM)
  end

  local midX = leftW + 5
  lamp(midX, 7,  "BUS",   CYAN,   true)
  lamp(midX + 7, 7,  "AUX",   GREEN,  tick % 2 == 0)
  lamp(midX + 14,7,  "VENT",  YELLOW, true)

  lamp(midX, 11, "ROD",   ORANGE, true)
  lamp(midX + 7,11, "TRIP",  RED,    tick % 4 == 0)
  lamp(midX + 14,11, "SYNC",  GREEN,  true)

  lamp(midX, 15, "SCRB",  BLUE,   true)
  lamp(midX + 7,15, "WARN",  YELLOW, tick % 3 == 0)
  lamp(midX + 14,15, "ISO",   MAG,    tick % 5 == 0)

  writeAt(midX, 19, "LAMP BANK C", TXT, BG)
  writeAt(midX, 20, "STATE MATRIX", DIM, BG)

  local bottomY = 23
  box(2, bottomY, w - 2, h - bottomY - 2, "PUSHBUTTON STRIP")

  local innerY = bottomY + 2
  local gap = 2
  local btnW = math.floor((w - 12) / 5)

  local x1 = 4
  local x2 = x1 + btnW + gap
  local x3 = x2 + btnW + gap
  local x4 = x3 + btnW + gap
  local x5 = x4 + btnW + gap

  button(x1, innerY, btnW, "LAMP TEST", BLUE, colors.black)
  button(x2, innerY, btnW, "RESET", GREEN, colors.black)
  button(x3, innerY, btnW, "FIELD ISO", ORANGE, colors.black)
  button(x4, innerY, btnW, "SCRAM BUS", RED, TXT)
  button(x5, innerY, btnW, "PURGE", YELLOW, colors.black)

  local footer = "NO FIELD LINK / PANEL DECORATIVE"
  writeAt(3, h - 1, clip(footer, w - 4), DIM, BG)

  sleep(0.35)
end
