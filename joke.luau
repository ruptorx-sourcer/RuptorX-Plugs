-- Plugins just call register() directly
register("joke", function(flags)
    local message = table.concat(flags, " ")
    print("JOKE: " .. message)
end)

print("Joke plugin loaded successfully!")
