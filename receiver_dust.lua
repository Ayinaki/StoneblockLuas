-- DUST RECEIVER (Channel 103)
-- Drops: Redstone, Gold, Tin, Bonemeal

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
modem.open(103)

print("----------------------------------------")
print(" SYSTEM: DUST RECEIVER ONLINE")
print(" CHANNEL: 103")
print(" LISTENING FOR UNEARTHER SIGNALS...")
print("----------------------------------------")

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if channel == 103 then
        if message == "ON" then
            redstone.setOutput("back", true) -- Change "back" to match your machine face
            print("[STATUS] Dust Mode: ENABLED")
        elseif message == "OFF" then
            redstone.setOutput("back", false)
            print("[STATUS] Dust Mode: DISABLED")
        end
    end
end
