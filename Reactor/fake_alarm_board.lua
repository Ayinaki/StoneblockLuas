-- fake_alarm_board.lua
local mon = peripheral.find("monitor") or term.current()
if mon.setTextScale then mon.setTextScale(0.5) end
term.redirect(mon)

local w, h = term.getSize()
local tick = 0

local alarms = {
  {tag="RCS PRESS", pr="HI",   state="STBY", color=colors.yellow},
  {tag="LOOP TEMP", pr="MED",  state="NORM", color=colors.orange},
  {tag="GRID SYNC", pr="LOW",  state="OK",   color=colors.lime},
  {tag="TURB VIB",  pr="MED",  state="OK",   color=colors.orange},
  {tag="VENT PATH", pr="HI",   state="OK",   color=colors.red},
  {tag="AUX FEED",  pr="LOW",  state="NORM", color=colors.lightBlue},
  {tag="ROD BANK",  pr="MED",  state="OK",   color=colors.yellow},
  {tag="STACK MON", pr="LOW",  state="OK",   color=colors.green},
}

local feed = {
  "03:14:22  ALARM GROUP B SCAN COMPLETE",
  "03:14:31  ACK RELAY BANK HEARTBEAT OK",
  "03:14:44  MAINT BYPASS CHANNEL SEALED",
  "03:14:58  LAMP TEST BUS IN STANDBY",
  "03:15:07  NORTH PANEL LINK VERIFIED",
  "03:15:12  EVENT BUFFER ROTATED",
  "03:15:28  SHIFT LOG READY",
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
  center(1,"MASTER ALARM ANNUNCIATOR",colors.white,colors.gray)
  writeAt(2,2,"PANEL LINK  ACTIVE",colors.lime,colors.gray)
  writeAt(w-18,2,"SHIFT B / CTRL RM",colors.white,colors.gray)

  box(2,5,w-3,8,"PRIORITY GROUPS")

  local lampY = 7
  local names = {"P1 CRIT","P2 HIGH","P3 MED","P4 LOW","ACK","SHELVED"}
  local cols  = {colors.red,colors.orange,colors.yellow,colors.lightBlue,colors.lime,colors.gray}
  local activeLamp = (tick % 8) + 1

  for i=1,#names do
    local lx = 4 + (i-1) * math.floor((w-8)/6)
    local on = (i == 1 and tick % 2 == 0) or (i == activeLamp and i <= 4)
    writeAt(lx,lampY,"   ",colors.black,on and cols[i] or colors.black)
    writeAt(lx,lampY+1,names[i],on and cols[i] or colors.lightGray,colors.black)
  end

  box(2,14,math.floor(w*0.58),h-18,"ALARM LIST")
  local leftW = math.floor(w*0.58)
  for i=1,8 do
    local a = alarms[((i + tick - 2) % #alarms) + 1]
    local y = 16 + (i-1)*2
    if y < h-5 then
      local flash = (a.pr == "HI" and tick % 2 == 0)
      writeAt(4,y,"  ",colors.black,flash and a.color or colors.gray)
      writeAt(7,y,a.tag,colors.white,colors.black)
      writeAt(leftW-8,y,a.pr,flash and a.color or colors.lightGray,colors.black)
      writeAt(leftW-3,y,a.state,colors.lightGray,colors.black)
    end
  end

  box(leftW+3,14,w-leftW-4,h-18,"EVENT FEED")
  for i=1,7 do
    local idx = ((i + tick - 2) % #feed) + 1
    local y = 16 + (i-1)*2
    if y < h-5 then
      writeAt(leftW+5,y,feed[idx],colors.lightGray,colors.black)
    end
  end

  fill(1,h-2,w,2,colors.gray)
  writeAt(2,h-1,"ALARM ROUTING: ENABLED",colors.white,colors.gray)
  writeAt(w-22,h-1,"AUDIBLE: INHIBITED",colors.orange,colors.gray)

  sleep(0.5)
end
