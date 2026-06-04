-- STANDALONE WIRELESS VILLAGER CHEST MONITOR (UNIVERSAL)
local CONFIG_FILE = "/config.txt"

-- Default settings if config file doesn't exist yet
local VILLAGER_NAME = "Archaeologist"
local CHANNELS_TO_PROTECT = { 101, 102, 103 }
local CHEST_SIDE = "top" 

-- Load custom configuration from local drive if it exists
if fs.exists(CONFIG_FILE) then
    local file = fs.open(CONFIG_FILE, "r")
    VILLAGER_NAME = file.readLine() or VILLAGER_NAME
    
    local channelLine = file.readLine()
    if channelLine then
        CHANNELS_TO_PROTECT = {}
        for channel in string.gmatch(channelLine, "[^, ]+") do
            table.insert(CHANNELS_TO_PROTECT, tonumber(channel))
        end
    end
    file.close()
end

local modem = peripheral.find("modem") or error("No wireless/ender modem found!")
print("----------------------------------------")
print(" SYSTEM: SHARED VILLAGER CHEST MONITOR")
print(" TARGETING: " .. VILLAGER_NAME)
print("----------------------------------------")

while true do
    if peripheral.isPresent(CHEST_SIDE) then
        local chest = peripheral.wrap(CHEST_SIDE)
        local totalSlots = chest.size()
        local occupiedSlotsList = chest.list()
        
        local filledSlots = 0
        for _ in pairs(occupiedSlotsList) do filledSlots = filledSlots + 1 end
        
        local fullPercent = math.floor((filledSlots / totalSlots) * 100)
        print(string.format("Shared Chest Space: %d%% occupied", fullPercent))
        
        -- Send a robust string containing the name AND percentage
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
