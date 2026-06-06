-- fake_core_map_2x2.lua
-- Decorative 2x2 reactor rod/core map display

local mon = peripheral.find("monitor") or term.current()
if mon.setTextScale then mon.setTextScale(0.5) end
term.redirect(mon)

local w, h = term.getSize()
local tick = 0

local palette = {
  bg = colors.black,
  frame = colors.gray,
  title = colors.white,
  dim = colors.lightGray,
  cyan = colors.cyan,
  green = colors.lime,
  amber = colors.orange,
  red = colors.red,
  mag = colors.magenta,
  idle = colors.gray,
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
  fill(x, y, ww, hh, palette.bg)
  writeAt(x, y, "+" .. string.rep("-", ww - 2) .. "+", palette.frame, palette.bg)
  for yy = y + 1, y + hh - 2 do
    writeAt(x, yy, "|", palette.frame, palette.bg)
    writeAt(x + ww - 1, yy, "|", palette.frame, palette.bg)
  end
  writeAt(x, y + hh - 1, "+" .. string.rep("-", ww - 2) .. "+", palette.frame, palette.bg)
  if title then writeAt(x + 2, y, clip(title, ww - 4), palette.title, palette.bg) end
end

local function dot(x, y, col, blink)
  if x < 1 or x > w or y < 1 or y > h then return end
  local on = true
  if blink then on = (tick % 2 == 0) end
  term.setCursorPos(x, y)
  term.setBackgroundColor(on and col or palette.bg)
  term.write(" ")
end

local function textDot(x, y, col, ch, fg)
  if x < 1 or x > w or y < 1 or y > h then return end
  term.setCursorPos(x, y)
  term.setBackgroundColor(col)
  term.setTextColor(fg or colors.black)
  term.write(ch or " ")
end

local function rodColor(r, c)
  local n = (r * 17 + c * 31 + tick) % 23
  if n == 0 then return palette.red, true
  elseif n <= 2 then return palette.amber, false
  elseif n == 3 then return palette.mag, true
  elseif n <= 6 then return palette.green, false
  else return palette.cyan, false end
end

while true do
  w, h = term.getSize()
  tick = tick + 1

  term.setBackgroundColor(palette.bg)
  term.clear()

  fill(1, 1, w, 3, palette.frame)
  center(1, "CORE MAP / ROD FIELD", palette.title, palette.frame)
  writeAt(2, 2, clip("MODE  DISPLAY", math.floor(w * 0.35)), palette.cyan, palette.frame)
  local hdr = "BANKS A-D"
  writeAt(w - #hdr - 1, 2, hdr, palette.white, palette.frame)

  local mapY = 5
  local mapH = math.max(12, h - 10)
  box(2, mapY, w - 2, mapH, "ACTIVE CORE")

  local innerX = 4
  local innerY = mapY + 2
  local innerW = w - 6
  local innerH = mapH - 4

  local rows = math.min(11, innerH)
  local cols = math.min(15, math.floor(innerW / 2))

  local startX = math.max(4, math.floor((w - (cols * 2 - 1)) / 2))
  local startY = innerY + math.max(0, math.floor((innerH - rows) / 2))

  for r = 1, rows do
    local rowInset
    if r == 1 or r == rows then
      rowInset = 4
    elseif r == 2 or r == rows - 1 then
      rowInset = 3
    elseif r == 3 or r == rows - 2 then
      rowInset = 2
    elseif r == 4 or r == rows - 3 then
      rowInset = 1
    else
      rowInset = 0
    end

    local activeCols = cols - rowInset * 2
    for c = 1, activeCols do
      local gx = startX + rowInset * 2 + (c - 1) * 2
      local gy = startY + (r - 1)

      local col, blink = rodColor(r, c)

      if (r == math.ceil(rows / 2) and c == math.ceil(activeCols / 2)) then
        textDot(gx, gy, palette.idle, "C", colors.white)
      elseif (r + c + tick) % 29 == 0 then
        textDot(gx, gy, palette.idle, "R", colors.white)
      else
        dot(gx, gy, col, blink)
      end
    end
  end

  fill(3, h - 4, w - 4, 1, palette.bg)
  writeAt(3, h - 4, " ", colors.black, palette.cyan)
  writeAt(5, h - 4, "NORM", palette.dim, palette.bg)

  writeAt(11, h - 4, " ", colors.black, palette.green)
  writeAt(13, h - 4, "REG", palette.dim, palette.bg)

  writeAt(18, h - 4, " ", colors.black, palette.amber)
  writeAt(20, h - 4, "WARN", palette.dim, palette.bg)

  writeAt(27, h - 4, " ", colors.black, palette.red)
  writeAt(29, h - 4, "TRIP", palette.dim, palette.bg)

  fill(1, h - 2, w, 2, palette.frame)
  writeAt(2, h - 1, clip("INSERT DEV MAX  03", math.floor(w * 0.45)), palette.white, palette.frame)
  local foot = "CORE STABLE"
  if tick % 8 == 0 then foot = "SCAN UPDATE" end
  writeAt(w - #foot - 1, h - 1, foot, palette.cyan, palette.frame)

  sleep(0.45)
end
