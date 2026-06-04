-- DIMENSIONALIST RECEIVER: OTHERROCK (Channel 106)
local MY_CHANNEL = 106

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
modem.open(MY_CHANNEL)

print("Otherrock Receiver Active. Safeguarded monitoring online...")

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if channel == MY_CHANNEL then
        if message == "ON" then
            redstone.setOutput("back", true)
            print("[STATUS] Unearther Active: Otherrock Mode")
        elseif message == "OFF" then
            redstone.setOutput("back", false)
            print("[STATUS] Unearther Idle")
        elseif message == "CHEST_FULL" then
            redstone.setOutput("back", false)
            print("[ALERT] Dimensionalist shared chest is FULL! Automatically halting.")
        end
    end
end
