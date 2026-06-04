-- STANDALONE WIRELESS VILLAGER CHEST MONITOR
local CHANNELS_TO_PROTECT = { 101, 102, 103 }
local CHEST_SIDE = "top" 

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
print("----------------------------------------")
print(" SYSTEM: SHARED VILLAGER CHEST MONITOR")
print(" LIVE METRICS BROADCASTING ACTIVE")
print("----------------------------------------")

while true do
    if peripheral.isPresent(CHEST_SIDE) then
        local chest = peripheral.wrap(CHEST_SIDE)
        local totalSlots = chest.size()
        local occupiedSlotsList = chest.list()
        
        local filledSlots = 0
        for _ in pairs(occupiedSlotsList) do
            filledSlots = filledSlots + 1
        end
        
        local fullPercent = math.floor((filledSlots / totalSlots) * 100)
        print(string.format("Shared Chest Space: %d%% occupied", fullPercent))
        
        -- Broadcast live metrics string to the main station on the active frequencies
        for _, channel in ipairs(CHANNELS_TO_PROTECT) do
            modem.transmit(channel, channel, "CHEST_STATUS:" .. tostring(fullPercent))
        end
        
        -- Trigger emergency kill safeguards if full
        if fullPercent >= 95 then
            print("[WARNING] Shared chest full! Sending emergency stops...")
            for _, channel in ipairs(CHANNELS_TO_PROTECT) do
                modem.transmit(channel, channel, "CHEST_FULL")
            end
        end
    else
        print("[ERROR] No chest detected directly on top!")
    end
    
    os.sleep(10)
end
