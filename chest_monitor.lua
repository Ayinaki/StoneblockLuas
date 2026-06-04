-- STANDALONE WIRELESS VILLAGER CHEST MONITOR
-- Tucked directly under the shared output chest for a specific villager

-- CONFIGURATION: List all channels used by this specific villager!
-- This list covers the Archaeologist's Dirt (101), Sand (102), and Dust (103) modes.
local CHANNELS_TO_PROTECT = { 101, 102, 103 }
local CHEST_SIDE = "top" -- Chest is directly on top of this computer

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
print("----------------------------------------")
print(" SYSTEM: SHARED VILLAGER CHEST MONITOR")
print(" MONITORING EVERY 10 SECONDS...")
print("----------------------------------------")

while true do
    if peripheral.isPresent(CHEST_SIDE) then
        local chest = peripheral.wrap(CHEST_SIDE)
        local totalSlots = chest.size()
        local filledSlots = 0
        
        -- Count occupied slots
        for slot = 1, totalSlots do
            if chest.getItem(slot) then
                filledSlots = filledSlots + 1
            end
        end
        
        local fullPercent = math.floor((filledSlots / totalSlots) * 100)
        print(string.format("Shared Chest Space: %d%% occupied", fullPercent))
        
        -- If the shared chest hits critical capacity, blast emergency stops to ALL channels
        if fullPercent >= 95 then
            print("[WARNING] Shared chest full! Sending emergency stops...")
            
            -- Loop through every channel in our protection list and transmit the kill signal
            for _, channel in ipairs(CHANNELS_TO_PROTECT) do
                modem.transmit(channel, channel, "CHEST_FULL")
            end
        end
    else
        print("[ERROR] No chest detected directly on top!")
    end
    
    os.sleep(10) -- Keeps server tick rates perfectly smooth
end
