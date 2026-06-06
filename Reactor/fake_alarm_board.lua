-- fake_alarm_board_fixed.lua
local mon = peripheral.find("monitor") or term.current()
if mon.setTextScale then mon.setTextScale(0.5) end
term.redirect(mon)

local w, h = term.getSize()
local tick = 0

local alarms = {
  {tag="RCS PRESS", pr="HI",  state="STBY", color=colors.yellow},
  {tag="LOOP TEMP", pr="MED", state="NORM", color=colors.orange},
  {tag="GRID SYNC", pr="LOW", state="OK",   color=colors.lime},
  {tag="TURB VIB",  pr="MED", state="OK",   color=colors.orange},
  {tag="VENT PATH", pr="HI",  state="OK",   color=colors.red},
  {tag="AUX FEED",  pr="LOW", state="NORM", color=colors.lightBlue},
  {tag="ROD BANK",  pr="MED", state="OK",   color=colors.yellow},
  {tag="STACK MON", pr="LOW", state="OK",   color=colors.green},
}

local feed = {
  "03:14:22 ALARM GRP B SCAN OK",
  "03:14:31 ACK RELAY HEARTBEAT",
  "03:14:44 MAINT BYPASS SEALED",
  "03:14:58 LAMP TEST BUS STBY",
  "03:15:07 NORTH PANEL LINK OK",
  "03:15:12 EVENT BUFFER ROTATE",
  "03:15:28 SHIFT LOG READY",
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
  t = tostring(t or "")
  local x = math.max(1, math.floor((w - #t) / 2) + 1)
  writeAt(x, y, clip(t, w), fg, bg)
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
  center(1, "MASTER ALARM ANNUNCIATOR", colors.white, colors.gray)
  writeAt(2, 2, clip("PANEL LINK  ACTIVE", math.floor(w * 0.35)), colors.lime, colors.gray)
  local hdrRight = "SHIFT B / CTRL RM"
  writeAt(w - #hdrRight - 1, 2, hdrRight, colors.white, colors.gray)

  box(2, 5, w - 3, 8, "PRIORITY GROUPS")

  local lampY = 7
  local lampNames = {"P1","P2","P3","P4","ACK","SHLV"}
  local lampCols = {colors.red, colors.orange, colors.yellow, colors.lightBlue, colors.lime, colors.gray}
  local spacing = math.max(6, math.floor((w - 8) / 6))
  local activeLamp = (tick % 4) + 1

  for i = 1, #lampNames do
    local lx = 4 + (i - 1) * spacing
    if lx + 4 < w - 2 then
      local on = (i == 1 and tick % 2 == 0) or (i == activeLamp and i <= 4)
      writeAt(lx, lampY, "   ", colors.black, on and lampCols[i] or colors.black)
      writeAt(lx, lampY + 1, lampNames[i], on and lampCols[i] or colors.lightGray, colors.black)
    end
  end

  local leftW = math.max(24, math.floor(w * 0.58))
  local rightX = leftW + 3
  local rightW = w - rightX

  box(2, 14, leftW, h - 18, "ALARM LIST")
  box(rightX, 14, rightW, h - 18, "EVENT FEED")

  local listInnerW = leftW - 4
  local tagW = math.max(8, listInnerW - 11)
  local prX = 4 + tagW + 2
  local stX = prX + 5

  for i = 1, 8 do
    local a = alarms[((i + tick - 2) % #alarms) + 1]
    local y = 16 + (i - 1) * 2
    if y < h - 4 then
      local flash = (a.pr == "HI" and tick % 2 == 0)
      writeAt(4, y, "  ", colors.black, flash and a.color or colors.gray)
      writeAt(7, y, clip(a.tag, tagW), colors.white, colors.black)
      writeAt(prX, y, clip(a.pr, 3), flash and a.color or colors.lightGray, colors.black)
      writeAt(stX, y, clip(a.state, 4), colors.lightGray, colors.black)
    end
  end

  local feedInnerW = rightW - 4
  local feedRows = math.max(1, math.floor((h - 22) / 2) + 2)
  for i = 1, feedRows do
    local idx = ((i + tick - 2) % #feed) + 1
    local y = 16 + (i - 1) * 2
    if y < h - 4 then
      writeAt(rightX + 2, y, clip(feed[idx], feedInnerW), colors.lightGray, colors.black)
    end
  end

  fill(1, h - 2, w, 2, colors.gray)
  writeAt(2, h - 1, clip("ALARM ROUTING: ENABLED", math.floor(w * 0.45)), colors.white, colors.gray)
  local footRight = "AUDIBLE: INHIBITED"
  writeAt(w - #footRight - 1, h - 1, footRight, colors.orange, colors.gray)

  sleep(0.5)
end
