-- Example RuptorX Plugin
register("example")

print("=== EXAMPLE PLUGIN LOADED ===")
print("Mobile device:", ismobile())

-- Plugin logic
if flags and #flags > 0 then
    print("Flags received:")
    for i, flag in ipairs(flags) do
        print("  " .. i .. ": " .. flag)
    end
else
    print("No flags provided")
end

-- Simulate work
for i = 1, 3 do
    print("Working... " .. i)
    wait(1)
    if checkshutdown() then
        print("Shutdown detected, stopping...")
        break
    end
end

print("=== PLUGIN FINISHED ===")
functionend()
