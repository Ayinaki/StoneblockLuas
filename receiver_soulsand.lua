-- GEOLOGIST RECEIVER: SOUL SAND MODE (Channel 106)
local MY_CHANNEL = 106

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
modem.open(MY_CHANNEL)

print("----------------------------------------")
print(" SYSTEM: GEOLOGIST RECEIVER")
print(" MODE: SOUL SAND CONTROL (CH 106)")
print("----------------------------------------")

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if channel == MY_CHANNEL then
        if message == "ON" then
            redstone.setOutput("back", true) -- Adjust "back" to whichever side faces your machine input
            print("[STATUS] Unearther Active: Soul Sand Mode")
        elseif message == "OFF" then
            redstone.setOutput("back", false)
            print("[STATUS] Unearther Idle")
        elseif message == "CHEST_FULL" then
            redstone.setOutput("back", false)
            print("[ALERT] Geologist shared chest is FULL! Automatically halting.")
        end
    end
end
