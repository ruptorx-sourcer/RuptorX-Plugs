Interpreter.register("joke", function(flags)
    print("JOKE: " .. table.concat(flags, " "))
end)
