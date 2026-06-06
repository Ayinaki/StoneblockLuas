-- fake_waveform_analyzer_5x3.lua
-- Decorative wide waveform / harmonic analyzer screen

local mon = peripheral.find("monitor") or term.current()
if mon.setTextScale then mon.setTextScale(0.5) end
term.redirect(mon)

local w, h = term.getSize()
local tick = 0

local BG = colors.black
local FRAME = colors.red
local DIM = colors.gray
local TXT = colors.white
local TRACE1 = colors.red
local TRACE2 = colors.orange
local TRACE3 = colors.pink

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

local function plotPoint(x, y, col)
  if x < 1 or x > w or y < 1 or y > h then return end
  term.setCursorPos(x, y)
  term.setBackgroundColor(col)
  term.write(" ")
end

while true do
  w, h = term.getSize()
  tick = tick + 1

  term.setBackgroundColor(BG)
  term.clear()

  fill(1, 1, w, h, BG)

  box(2, 2, w - 2, 3, "FLUX HARMONIC ANALYZER :: LIVE")
  writeAt(w - 9, 3, "S-" .. tostring(100 + tick), DIM, BG)

  local graphX = 5
  local graphY = 7
  local graphW = w - 8
  local graphH = math.max(12, h - 18)

  box(graphX, graphY, graphW, graphH, nil)

  local midY = graphY + math.floor(graphH / 2)
  local left = graphX + 2
  local right = graphX + graphW - 3
  local top = graphY + 2
  local bottom = graphY + graphH - 3

  for x = left, right do
    if x % 6 == 0 then
      for y = top, bottom do
        if y >= 1 and y <= h then
          writeAt(x, y, ".", DIM, BG)
        end
      end
    end
  end

  for y = top, bottom do
    if y % 4 == 0 then
      writeAt(left, y, string.rep(".", math.max(1, right - left + 1)), DIM, BG)
    end
  end

  for x = left, right do
    local t1 = (x - left) / 4 + tick * 0.22
    local t2 = (x - left) / 5 + tick * 0.18
    local t3 = (x - left) / 6 + tick * 0.16

    local y1 = midY + math.floor(math.sin(t1) * 2 + math.sin(t1 * 0.35) * 2)
    local y2 = midY + math.floor(math.cos(t2) * 3)
    local y3 = midY + math.floor(math.sin(t3 * 1.4 + 1.3) * 2)

    plotPoint(x, y1, TRACE1)
    plotPoint(x, y2, TRACE2)
    plotPoint(x, y3, TRACE3)
  end

  local markerX = left + math.floor((right - left) * 0.48)
  for y = top, bottom do
    if y % 2 == 0 then
      writeAt(markerX, y, "|", TXT, BG)
      writeAt(markerX + 3, y, "|", DIM, BG)
    end
  end

  local panelY = graphY + graphH + 2
  local panelH = 6
  local gap = 2
  local panelW = math.floor((w - 6 - gap * 2) / 3)

  local p1x = 2
  local p2x = p1x + panelW + gap
  local p3x = p2x + panelW + gap

  box(p1x, panelY, panelW, panelH, "CH-1 PRIMARY")
  box(p2x, panelY, panelW, panelH, "CH-2 REACT")
  box(p3x, panelY, panelW, panelH, "CH-3 HARMONIC")

  local f1 = 191.26 + math.sin(tick * 0.17) * 1.3
  local f2 = 328.38 + math.cos(tick * 0.12) * 2.1
  local f3 = 515.30 + math.sin(tick * 0.09) * 1.7

  writeAt(p1x + 2, panelY + 2, clip(string.format("%.2f MHZ", f1), panelW - 4), TXT, BG)
  writeAt(p2x + 2, panelY + 2, clip(string.format("%.2f MHZ", f2), panelW - 4), TXT, BG)
  writeAt(p3x + 2, panelY + 2, clip(string.format("%.2f MHZ", f3), panelW - 4), TXT, BG)

  for i = 0, panelW - 5 do
    local x1 = p1x + 2 + i
    local x2 = p2x + 2 + i
    local x3 = p3x + 2 + i

    local y1 = panelY + 4 + math.floor(math.sin(i / 3 + tick * 0.3) * 1)
    local y2 = panelY + 4 + math.floor(math.cos(i / 2 + tick * 0.25) * 1)
    local y3 = panelY + 4 + math.floor(math.sin(i / 2.7 + tick * 0.18) * 1)

    plotPoint(x1, y1, TRACE1)
    plotPoint(x2, y2, TRACE3)
    plotPoint(x3, y3, TRACE2)
  end

  sleep(0.12)
end
