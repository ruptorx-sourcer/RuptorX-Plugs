-- RuptorX Joke Plugin
local success = ruptorx.register("joke", function(flags)
    local message = table.concat(flags, " ")
    print("JOKE: " .. message)
end)

if success then
    print("JOKE PLUGIN: Successfully loaded! Use *joke <message>")
else
    warn("JOKE PLUGIN: Failed to register command")
end
