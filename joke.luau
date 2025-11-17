-- RuptorX TestCmd Plugin
-- This is a test plugin to verify the plugin system works

local success = ruptorx.register("testcmd", function(flags)
    local message = table.concat(flags, " ")
    print("TESTCMD: Plugin system working! Message: " .. message)
end)

if success then
    print("TESTCMD PLUGIN: Successfully loaded! Use *testcmd <message>")
else
    warn("TESTCMD PLUGIN: Failed to register command")
end

return "TestCmd plugin loaded successfully"
