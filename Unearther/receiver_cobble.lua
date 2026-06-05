-- GEOLOGIST RECEIVER: COBBLE MODE (Channel 105)
local MY_CHANNEL = 105

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
modem.open(MY_CHANNEL)

print("----------------------------------------")
print(" SYSTEM: GEOLOGIST RECEIVER")
print(" MODE: COBBLE CONTROL (CH 105)")
print("----------------------------------------")

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if channel == MY_CHANNEL then
        if message == "ON" then
            redstone.setOutput("back", true) -- Adjust to the face touching your machine
            print("[STATUS] Unearther Active: Cobble Mode")
        elseif message == "OFF" then
            redstone.setOutput("back", false)
            print("[STATUS] Unearther Idle")
        elseif message == "CHEST_FULL" then
            redstone.setOutput("back", false)
            print("[ALERT] Geologist shared chest is FULL! Automatically halting.")
        end
    end
end
