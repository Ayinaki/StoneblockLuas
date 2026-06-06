-- fake_ops_board.lua
local mon = peripheral.find("monitor") or term.current()
if mon.setTextScale then mon.setTextScale(0.5) end
term.redirect(mon)

local w, h = term.getSize()
local tick = 0

local systems = {
  {"TURBINE TRAIN A", "READY", colors.lime},
  {"CONDENSER LOOP",  "STABLE", colors.lightBlue},
  {"AUX COOLING",     "READY", colors.lime},
  {"WASTE HANDLING",  "QUEUE", colors.yellow},
  {"GRID EXPORT",     "HOLD", colors.orange},
  {"VENT SCRUBBER",   "READY", colors.lime},
}

local tasks = {
  "04:00  TURBINE BEARING INSPECTION",
  "04:30  EAST HALL FILTER SWAP",
  "05:15  AUX LOOP CHEM SAMPLE",
  "05:40  NIGHT SHIFT HANDOVER",
  "06:00  EXPORT WINDOW RECHECK",
  "06:30  PANEL LAMP TEST",
}

local crew = {
  "SHIFT LEAD   H. MERCER",
  "REACTOR ENG  T. VALE",
  "GRID COORD   N. HALE",
  "MAINT TECH   E. SATO",
}

local function fill(x,y,ww,hh,bg)
  term.setBackgroundColor(bg)
  for yy=y,y+hh-1 do
    term.setCursorPos(x,yy)
    term.write(string.rep(" ",ww))
  end
end

local function writeAt(x,y,t,fg,bg)
  if y < 1 or y > h then return end
  term.setCursorPos(x,y)
  if fg then term.setTextColor(fg) end
  if bg then term.setBackgroundColor(bg) end
  term.write(t:sub(1, math.max(0, w-x+1)))
end

local function box(x,y,ww,hh,title)
  fill(x,y,ww,hh,colors.black)
  writeAt(x,y,"+"..string.rep("-",ww-2).."+",colors.gray,colors.black)
  for yy=y+1,y+hh-2 do
    writeAt(x,yy,"|",colors.gray,colors.black)
    writeAt(x+ww-1,yy,"|",colors.gray,colors.black)
  end
  writeAt(x,y+hh-1,"+"..string.rep("-",ww-2).."+",colors.gray,colors.black)
  if title then writeAt(x+2,y,title,colors.white,colors.black) end
end

local function center(y,t,fg,bg)
  local x = math.floor((w-#t)/2)+1
  writeAt(x,y,t,fg,bg)
end

while true do
  w,h = term.getSize()
  tick = tick + 1
  term.setBackgroundColor(colors.black)
  term.clear()

  fill(1,1,w,3,colors.gray)
  center(1,"OPERATIONS / MAINTENANCE BOARD",colors.white,colors.gray)
  writeAt(2,2,"PLANT MODE  STEADY STATE",colors.lime,colors.gray)
  writeAt(w-16,2,"REV "..tostring(120+tick),colors.white,colors.gray)

  local leftW = math.floor(w*0.54)
  box(2,5,leftW,11,"SUBSYSTEM READINESS")
  for i=1,#systems do
    local y = 7 + (i-1)
    if y < 15 then
      local s = systems[((i + tick - 2) % #systems) + 1]
      writeAt(4,y,s[1],colors.white,colors.black)
      writeAt(leftW-7,y,s[2],s[3],colors.black)
    end
  end

  box(leftW+3,5,w-leftW-4,11,"CREW / WATCH")
  for i=1,#crew do
    writeAt(leftW+5,7+(i-1)*2,crew[i],colors.lightGray,colors.black)
  end

  box(2,17,w-3,h-20,"SCHEDULED WORK / DISPATCH")
  for i=1,#tasks do
    local idx = ((i + tick - 2) % #tasks) + 1
    local y = 19 + (i-1)*2
    if y < h-4 then
      writeAt(4,y,tasks[idx],colors.white,colors.black)
    end
  end

  fill(1,h-2,w,2,colors.gray)
  writeAt(2,h-1,"EXPORT TARGET  84%    GRID WINDOW  OPEN+12",colors.white,colors.gray)
  writeAt(w-18,h-1,"CREW LOG SYNC OK",colors.lime,colors.gray)

  sleep(0.6)
end
