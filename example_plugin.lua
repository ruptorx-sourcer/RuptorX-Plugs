-- Example RuptorX Plugin (FIXED Version)
register("example")

-- Plugin code here
print("Example plugin loaded!")

-- SAFE: Check if flags exists before using it
if flags and type(flags) == "table" then
    print("Flags received:", table.concat(flags, ", "))
else
    print("No flags received or flags is not a table")
end

-- Access RootKit API
if ismobile() then
    print("Running on mobile device")
else
    print("Running on desktop")
end

-- Do plugin work here
for i = 1, 3 do
    print("Plugin working... " .. i)
    wait(1)
    
    if checkshutdown() then
        print("Plugin detected shutdown, cleaning up...")
        break
    end
end

-- Always end with functionend
functionend()
print("Example plugin finished!")
