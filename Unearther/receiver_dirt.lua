-- DIRT RECEIVER (Channel 101)
-- Drops: Magic Saplings, Pebbles, Seeds

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
modem.open(101)

print("----------------------------------------")
print(" SYSTEM: DIRT RECEIVER ONLINE")
print(" CHANNEL: 101")
print(" LISTENING FOR UNEARTHER SIGNALS...")
print("----------------------------------------")

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if channel == 101 then
        if message == "ON" then
            redstone.setOutput("back", true) -- Change "back" to match your machine face
            print("[STATUS] Dirt Mode: ENABLED")
        elseif message == "OFF" then
            redstone.setOutput("back", false)
            print("[STATUS] Dirt Mode: DISABLED")
        end
    end
end
