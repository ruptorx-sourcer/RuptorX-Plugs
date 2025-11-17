-- Example RuptorX Plugin
register("example")

-- Plugin code here
print("Example plugin loaded!")
print("Flags received:", table.concat(flags, ", "))

-- Access RootKit API
if ismobile() then
    print("Running on mobile device")
else
    print("Running on desktop")
end

-- Do plugin work here
for i = 1, 5 do
    print("Plugin working... " .. i)
    wait(1)
    
    if checkshutdown() then
        print("Plugin detected shutdown, cleaning up...")
        break
    end
end

-- Always end with functionend
functionend()
