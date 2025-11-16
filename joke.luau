-- RuptorX Joke Plugin - Modified Version
-- This plugin is designed to work with the RuptorX plugin system

-- The plugin system will call this function to register commands
local function initialize()
    -- Register the joke command
    local success = ruptorx.register("joke", function(flags)
        local message = table.concat(flags, " ")
        print("JOKE: " .. message)
    end)

    if success then
        print("JOKE PLUGIN: Successfully loaded! Use *joke <message>")
        return true
    else
        warn("JOKE PLUGIN: Failed to register command")
        return false
    end
end

-- Return the initialization function
return initialize
