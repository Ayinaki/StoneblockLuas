-- UNIVERSAL WIRELESS VILLAGER CHEST MONITOR (LABEL-BASED)
local CHEST_SIDE = "top" 

-- 1. Read the computer's own in-game label
local VILLAGER_NAME = os.computerLabel()

if not VILLAGER_NAME then
    print("[ERROR] This computer has no label!")
    print("Please run: label set <Name>")
    return
end

-- 2. Dynamically assign channels based on the label name
local CHANNELS_TO_PROTECT = {}
if VILLAGER_NAME == "Archaeologist" then
    CHANNELS_TO_PROTECT = { 101, 102, 103 }
elseif VILLAGER_NAME == "Geologist" then
    CHANNELS_TO_PROTECT = { 104, 105 }
elseif VILLAGER_NAME == "Dimensionalist" then
    CHANNELS_TO_PROTECT = { 106, 107, 108 }
else
    print("[ERROR] Unknown computer label: " .. VILLAGER_NAME)
    return
end

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
print("----------------------------------------")
print(" SYSTEM: SHARED VILLAGER CHEST MONITOR")
print(" DETECTED PROFILE: " .. VILLAGER_NAME)
print(" PROTECTING FREQUENCIES... ")
print("----------------------------------------")

while true do
    if peripheral.isPresent(CHEST_SIDE) then
        local chest = peripheral.wrap(CHEST_SIDE)
        local totalSlots = chest.size()
        local occupiedSlotsList = chest.list()
        
        local filledSlots = 0
        for _ in pairs(occupiedSlotsList) do filledSlots = filledSlots + 1 end
        
        local fullPercent = math.floor((filledSlots / totalSlots) * 100)
        print(string.format("[%s Chest] Space: %d%% occupied", VILLAGER_NAME, fullPercent))
        
        -- Broadcast live metrics string containing the label name and percent
        for _, channel in ipairs(CHANNELS_TO_PROTECT) do
            modem.transmit(channel, channel, "CHEST_STATUS:" .. VILLAGER_NAME .. ":" .. tostring(fullPercent))
        end
        
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
