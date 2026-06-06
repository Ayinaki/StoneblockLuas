-- fake_ops_board_fixed.lua
local mon = peripheral.find("monitor") or term.current()
if mon.setTextScale then mon.setTextScale(0.5) end
term.redirect(mon)

local w, h = term.getSize()
local tick = 0

local systems = {
  {"TURB TRAIN A", "READY",  colors.lime},
  {"COND LOOP",    "STABLE", colors.lightBlue},
  {"AUX COOLING",  "READY",  colors.lime},
  {"WASTE HDLG",   "QUEUE",  colors.yellow},
  {"GRID EXPORT",  "HOLD",   colors.orange},
  {"VENT SCRUB",   "READY",  colors.lime},
}

local tasks = {
  "04:00 TURB BEARING INSP",
  "04:30 EAST HALL FILTER",
  "05:15 AUX LOOP SAMPLE",
  "05:40 NIGHT HANDOVER",
  "06:00 EXPORT RECHECK",
  "06:30 PANEL LAMP TEST",
}

local crew = {
  "SHIFT LEAD  H. MERCER",
  "REACTOR ENG T. VALE",
  "GRID COORD  N. HALE",
  "MAINT TECH  E. SATO",
}

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
  fill(x, y, ww, hh, colors.black)
  writeAt(x, y, "+" .. string.rep("-", ww - 2) .. "+", colors.gray, colors.black)
  for yy = y + 1, y + hh - 2 do
    writeAt(x, yy, "|", colors.gray, colors.black)
    writeAt(x + ww - 1, yy, "|", colors.gray, colors.black)
  end
  writeAt(x, y + hh - 1, "+" .. string.rep("-", ww - 2) .. "+", colors.gray, colors.black)
  if title then writeAt(x + 2, y, clip(title, ww - 4), colors.white, colors.black) end
end

while true do
  w, h = term.getSize()
  tick = tick + 1

  term.setBackgroundColor(colors.black)
  term.clear()

  fill(1, 1, w, 3, colors.gray)
  center(1, "OPERATIONS / MAINTENANCE BOARD", colors.white, colors.gray)
  writeAt(2, 2, clip("PLANT MODE  STEADY STATE", math.floor(w * 0.45)), colors.lime, colors.gray)
  local revText = "REV " .. tostring(120 + tick)
  writeAt(w - #revText - 2, 2, revText, colors.white, colors.gray)

  local leftW = math.max(24, math.floor(w * 0.54))
  local rightX = leftW + 3
  local rightW = w - rightX

  box(2, 5, leftW, 11, "SUBSYSTEM READINESS")
  box(rightX, 5, rightW, 11, "CREW / WATCH")

  local sysNameW = math.max(8, leftW - 14)
  local sysStateX = 4 + sysNameW + 2

  for i = 1, #systems do
    local y = 7 + (i - 1)
    if y < 15 then
      local s = systems[((i + tick - 2) % #systems) + 1]
      writeAt(4, y, clip(s[1], sysNameW), colors.white, colors.black)
      writeAt(sysStateX, y, clip(s[2], 6), s[3], colors.black)
    end
  end

  local crewInnerW = rightW - 4
  for i = 1, #crew do
    local y = 7 + (i - 1) * 2
    if y < 15 then
      writeAt(rightX + 2, y, clip(crew[i], crewInnerW), colors.lightGray, colors.black)
    end
  end

  box(2, 17, w - 3, h - 20, "SCHEDULED WORK / DISPATCH")
  local taskInnerW = w - 7
  for i = 1, #tasks do
    local idx = ((i + tick - 2) % #tasks) + 1
    local y = 19 + (i - 1) * 2
    if y < h - 4 then
      writeAt(4, y, clip(tasks[idx], taskInnerW), colors.white, colors.black)
    end
  end

  fill(1, h - 2, w, 2, colors.gray)

  local leftFooter = "EXPORT 84%"
  local midFooter = "GRID WIN OPEN+12"
  local rightFooter = "CREW LOG OK"

  writeAt(2, h - 1, leftFooter, colors.white, colors.gray)
  center(h - 1, midFooter, colors.white, colors.gray)
  writeAt(w - #rightFooter - 1, h - 1, rightFooter, colors.lime, colors.gray)

  sleep(0.6)
end
