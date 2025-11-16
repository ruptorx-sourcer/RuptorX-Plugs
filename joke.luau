-- RuptorX Joke Plugin Example
-- Save this as a raw text file and use: .install https://raw.githubusercontent.com/yourname/ruptorx-plugins/main/joke.lua

-- Register the command with RuptorX
local success = ruptorx.register("joke", function(flags)
    local message = table.concat(flags, " ")
    print("JOKE: " .. message)
end)

if success then
    print("JOKE PLUGIN: Successfully loaded! Use *joke <message>")
else
    warn("JOKE PLUGIN: Failed to register command")
end

return "Joke plugin loaded successfully"
