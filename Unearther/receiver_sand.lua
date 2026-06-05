-- SAND RECEIVER (Channel 102)
-- Drops: Clay, Copper, Silver, Nickel, Uranium

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
modem.open(102)

print("----------------------------------------")
print(" SYSTEM: SAND RECEIVER ONLINE")
print(" CHANNEL: 102")
print(" LISTENING FOR UNEARTHER SIGNALS...")
print("----------------------------------------")

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if channel == 102 then
        if message == "ON" then
            redstone.setOutput("back", true) -- Change "back" to match your machine face
            print("[STATUS] Sand Mode: ENABLED")
        elseif message == "OFF" then
            redstone.setOutput("back", false)
            print("[STATUS] Sand Mode: DISABLED")
        end
    end
end
