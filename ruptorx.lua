-- RuptorX Enhanced Chat Interpreter (RootKit Enabled)
local Interpreter = {}

-- Services
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- State variables
Interpreter.Active = true
Interpreter.Noclipping = false
Interpreter.Spinning = false
Interpreter.Locking = false
Interpreter.PTeamLock = false
Interpreter.Following = false
Interpreter.Orbiting = false
Interpreter.Flying = false
Interpreter.Trolling = false
Interpreter.FlingTouch = false
Interpreter.Floating = false
Interpreter.NoStun = false
Interpreter.PHealthActive = false
Interpreter.SpinSpeed = 30
Interpreter.OrbitSpeed = 40
Interpreter.OrbitDistance = 5
Interpreter.FloatHeight = 3
Interpreter.ToDuration = 0.1
Interpreter.CustomWalkSpeed = nil
Interpreter.CustomJumpPower = nil
Interpreter.CustomHealth = nil
Interpreter.FlightBV = nil
Interpreter.FlightBG = nil
Interpreter.SpinAV = nil
Interpreter.FloatBP = nil
Interpreter.LockTarget = nil
Interpreter.LockConnection = nil
Interpreter.PTeamTarget = nil
Interpreter.PTeamConnection = nil
Interpreter.FollowTarget = nil
Interpreter.FollowConnection = nil
Interpreter.OrbitTarget = nil
Interpreter.OrbitConnection = nil
Interpreter.TrollConnection = nil
Interpreter.TrollTargets = {}
Interpreter.TrollTeamFilter = nil
Interpreter.TrollExcludeTeam = nil
Interpreter.FlingTouchConnection = nil
Interpreter.FlingTouchEvents = {}
Interpreter.NoStunConnection = nil
Interpreter.PHealthConnection = nil
Interpreter.RespawnPosition = nil
Interpreter.SpeedLoop = nil

-- RootKit Plugin System
Interpreter.PluginHandlers = {}
Interpreter.PluginStarters = {}
Interpreter.PluginRegistry = {}
Interpreter.InstallOverwrite = false
Interpreter.ShuttingDown = false
Interpreter.PluginMarker = "-- RUPTORX_PLUGIN_MARKER_DO_NOT_MODIFY --"

-- Check if we're on mobile
Interpreter.IsMobile = UserInputService.TouchEnabled

-- RootKit API Functions
function Interpreter.ismobile()
    return Interpreter.IsMobile
end

function Interpreter.register(commandName)
    if Interpreter.PluginHandlers[commandName:lower()] then
        warn("INTERPRETER: Plugin command '" .. commandName .. "' is already registered")
        return false
    end
    
    Interpreter.PluginHandlers[commandName:lower()] = true
    print("INTERPRETER: Plugin registered: " .. commandName)
    return true
end

function Interpreter.checkshutdown()
    return Interpreter.ShuttingDown
end

function Interpreter.functionend()
    return true
end

-- Safe function to get character
function Interpreter.getCharacter()
    local player = Players.LocalPlayer
    if not player then return nil end
    return player.Character
end

-- Safe function to get humanoid
function Interpreter.getHumanoid()
    local character = Interpreter.getCharacter()
    if not character then return nil end
    return character:FindFirstChild("Humanoid")
end

-- Safe function to get root part
function Interpreter.getRootPart()
    local character = Interpreter.getCharacter()
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

-- Send chat message
function Interpreter.sendChatMessage(message)
    local player = Players.LocalPlayer
    if not player then return end
    
    if TextChatService then
        local textChatChannel = TextChatService:FindFirstChild("TextChannels")
        if textChatChannel then
            local generalChannel = textChatChannel:FindFirstChild("RBXGeneral")
            if generalChannel then
                generalChannel:SendAsync(message)
                return
            end
        end
    end
    
    player:Chat(message)
end

-- Plugin Installation System
local function installPluginFromUrl(url, pluginName)
    if not (makefolder and isfolder and writefile and isfile and readfile) then
        return false, "File functions not available"
    end
    
    -- Validate plugin name
    if not pluginName or pluginName == "" then
        return false, "Plugin name cannot be empty"
    end
    
    -- Check if plugin already exists
    local pluginFolder = "ruptorx/plugins"
    local pluginPath = pluginFolder .. "/" .. pluginName .. ".lua"
    local registryPath = "ruptorx/plugin_registry.json"
    
    if not isfolder("ruptorx") then
        makefolder("ruptorx")
    end
    if not isfolder(pluginFolder) then
        makefolder(pluginFolder)
    end
    
    -- Load registry
    local registry = {}
    if isfile(registryPath) then
        local success, regData = pcall(function()
            return HttpService:JSONDecode(readfile(registryPath))
        end)
        if success then
            registry = regData
        end
    end
    
    -- Check for existing plugin
    if registry[pluginName:lower()] and not Interpreter.InstallOverwrite then
        return false, "Plugin '" .. pluginName .. "' already exists. Use *.install overwrite to overwrite."
    end
    
    -- Download plugin
    print("INSTALL: Downloading plugin from " .. url)
    local success, pluginCode = pcall(function()
        return game:HttpGet(url)
    end)
    
    if not success or not pluginCode or pluginCode == "" then
        return false, "Failed to download plugin from URL"
    end
    
    -- Validate plugin code (basic check)
    if not pluginCode:find("register%(\"([%w_]+)\"%)") then
        return false, "Plugin missing register function call"
    end
    
    -- Extract command name from register call
    local commandName = pluginCode:match("register%(\"([%w_]+)\"%)")
    if not commandName then
        return false, "Plugin missing valid register call"
    end
    
    -- Write plugin file
    writefile(pluginPath, pluginCode)
    
    -- Update registry
    registry[pluginName:lower()] = {
        command = commandName:lower(),
        path = pluginPath,
        installed = os.time(),
        url = url
    }
    
    -- Save registry
    pcall(function()
        writefile(registryPath, HttpService:JSONEncode(registry))
    end)
    
    -- Update runtime registry
    Interpreter.PluginStarters[commandName:lower()] = pluginPath
    Interpreter.PluginHandlers[commandName:lower()] = true
    
    -- Inject into main file if possible
    local success, err = pcall(function()
        local mainPath = "ruptorx/ruptorx.lua"
        if isfile(mainPath) then
            local mainContent = readfile(mainPath)
            local markerPos = mainContent:find(Interpreter.PluginMarker)
            
            if markerPos then
                local injectionCode = "\n-- Plugin: " .. pluginName .. " (" .. commandName .. ")\n"
                injectionCode = injectionCode .. "Interpreter.PluginStarters[\"" .. commandName:lower() .. "\"] = \"" .. pluginPath .. "\"\n"
                injectionCode = injectionCode .. "Interpreter.PluginHandlers[\"" .. commandName:lower() .. "\"] = true\n"
                injectionCode = injectionCode .. Interpreter.PluginMarker .. "\n"
                
                local newContent = mainContent:sub(1, markerPos - 1) .. injectionCode .. mainContent:sub(markerPos)
                writefile(mainPath, newContent)
            end
        end
    end)
    
    if not success then
        warn("INSTALL: Failed to inject plugin into main file: " .. tostring(err))
    end
    
    Interpreter.InstallOverwrite = false
    return true, "Plugin '" .. pluginName .. "' installed as command '*." .. commandName .. "'"
end

local function createInstallGui()
    local player = Players.LocalPlayer
    if not player then 
        Interpreter.sendChatMessage("INSTALL: No local player found")
        return
    end
    
    -- FIXED: Better PlayerGui detection
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        -- Try alternative methods to find PlayerGui
        playerGui = player:WaitForChild("PlayerGui", 2) -- Wait up to 2 seconds
        if not playerGui then
            Interpreter.sendChatMessage("INSTALL: Cannot create GUI - no PlayerGui found")
            return
        end
    end
    
    -- Clean up existing GUI
    local existingGui = playerGui:FindFirstChild("RuptorXInstallGui")
    if existingGui then
        existingGui:Destroy()
    end
    
    -- Create main frame with FIXED positioning
    local screenGui = Instance.new("ScreenGui")
    local frame = Instance.new("Frame")
    local urlBox = Instance.new("TextBox")
    local nameBox = Instance.new("TextBox")
    local confirmButton = Instance.new("TextButton")
    local cancelButton = Instance.new("TextButton")
    local title = Instance.new("TextLabel")
    local urlLabel = Instance.new("TextLabel")
    local nameLabel = Instance.new("TextLabel")
    local overwriteCheckbox = Instance.new("TextButton")
    local overwriteLabel = Instance.new("TextLabel")
    
    screenGui.Name = "RuptorXInstallGui"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999 -- High display order to ensure it's on top
    
    -- FIXED: Use proper UDim2 for positioning
    frame.Size = UDim2.new(0, 400, 0, 280)
    frame.Position = UDim2.new(0.5, -200, 0.5, -140) -- Proper center positioning
    frame.AnchorPoint = Vector2.new(0.5, 0.5) -- Center anchor
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.BorderColor3 = Color3.fromRGB(80, 80, 80)
    frame.Parent = screenGui
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Add shadow effect
    local shadow = Instance.new("UIStroke")
    shadow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    shadow.Color = Color3.fromRGB(0, 0, 0)
    shadow.Thickness = 3
    shadow.Parent = frame
    
    -- Title
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    title.Text = "RuptorX Plugin Installer"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = frame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title
    
    -- URL Label
    urlLabel.Size = UDim2.new(1, -40, 0, 25)
    urlLabel.Position = UDim2.new(0, 20, 0, 60)
    urlLabel.BackgroundTransparency = 1
    urlLabel.Text = "Plugin URL:"
    urlLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    urlLabel.TextXAlignment = Enum.TextXAlignment.Left
    urlLabel.Font = Enum.Font.Gotham
    urlLabel.TextSize = 14
    urlLabel.Parent = frame
    
    -- URL Box
    urlBox.Size = UDim2.new(1, -40, 0, 35)
    urlBox.Position = UDim2.new(0, 20, 0, 85)
    urlBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    urlBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    urlBox.PlaceholderText = "https://raw.githubusercontent.com/.../plugin.lua"
    urlBox.ClearTextOnFocus = false
    urlBox.Font = Enum.Font.Gotham
    urlBox.TextSize = 14
    urlBox.Parent = frame
    
    local urlBoxCorner = Instance.new("UICorner")
    urlBoxCorner.CornerRadius = UDim.new(0, 4)
    urlBoxCorner.Parent = urlBox
    
    -- Name Label
    nameLabel.Size = UDim2.new(1, -40, 0, 25)
    nameLabel.Position = UDim2.new(0, 20, 0, 130)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "Plugin Name:"
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 14
    nameLabel.Parent = frame
    
    -- Name Box
    nameBox.Size = UDim2.new(1, -40, 0, 35)
    nameBox.Position = UDim2.new(0, 20, 0, 155)
    nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameBox.PlaceholderText = "myplugin"
    nameBox.ClearTextOnFocus = false
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextSize = 14
    nameBox.Parent = frame
    
    local nameBoxCorner = Instance.new("UICorner")
    nameBoxCorner.CornerRadius = UDim.new(0, 4)
    nameBoxCorner.Parent = nameBox
    
    -- Overwrite Section
    overwriteLabel = Instance.new("TextLabel")
    overwriteLabel.Size = UDim2.new(0, 150, 0, 25)
    overwriteLabel.Position = UDim2.new(0, 20, 0, 200)
    overwriteLabel.BackgroundTransparency = 1
    overwriteLabel.Text = "Overwrite Existing:"
    overwriteLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    overwriteLabel.TextXAlignment = Enum.TextXAlignment.Left
    overwriteLabel.Font = Enum.Font.Gotham
    overwriteLabel.TextSize = 14
    overwriteLabel.Parent = frame
    
    overwriteCheckbox = Instance.new("TextButton")
    overwriteCheckbox.Size = UDim2.new(0, 25, 0, 25)
    overwriteCheckbox.Position = UDim2.new(0, 180, 0, 200)
    overwriteCheckbox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    overwriteCheckbox.BorderSizePixel = 0
    overwriteCheckbox.Text = ""
    overwriteCheckbox.AutoButtonColor = false
    overwriteCheckbox.Parent = frame
    
    local checkboxCorner = Instance.new("UICorner")
    checkboxCorner.CornerRadius = UDim.new(0, 4)
    checkboxCorner.Parent = overwriteCheckbox
    
    local overwriteChecked = Instance.new("TextLabel")
    overwriteChecked.Size = UDim2.new(1, 0, 1, 0)
    overwriteChecked.BackgroundTransparency = 1
    overwriteChecked.Text = "✓"
    overwriteChecked.TextColor3 = Color3.fromRGB(0, 255, 0)
    overwriteChecked.TextScaled = true
    overwriteChecked.Visible = false
    overwriteChecked.Parent = overwriteCheckbox
    
    -- Buttons
    confirmButton.Size = UDim2.new(0.45, 0, 0, 40)
    confirmButton.Position = UDim2.new(0.025, 0, 1, -50)
    confirmButton.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    confirmButton.Text = "Install"
    confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmButton.Font = Enum.Font.GothamBold
    confirmButton.TextSize = 16
    confirmButton.Parent = frame
    
    local confirmCorner = Instance.new("UICorner")
    confirmCorner.CornerRadius = UDim.new(0, 6)
    confirmCorner.Parent = confirmButton
    
    cancelButton.Size = UDim2.new(0.45, 0, 0, 40)
    cancelButton.Position = UDim2.new(0.525, 0, 1, -50)
    cancelButton.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
    cancelButton.Text = "Cancel"
    cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelButton.Font = Enum.Font.Gotham
    cancelButton.TextSize = 16
    cancelButton.Parent = frame
    
    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 6)
    cancelCorner.Parent = cancelButton
    
    -- Button functions
    local function cleanup()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end
    
    local function toggleOverwrite()
        Interpreter.InstallOverwrite = not Interpreter.InstallOverwrite
        overwriteChecked.Visible = Interpreter.InstallOverwrite
        overwriteCheckbox.BackgroundColor3 = Interpreter.InstallOverwrite and Color3.fromRGB(0, 80, 0) or Color3.fromRGB(60, 60, 60)
    end
    
    overwriteCheckbox.MouseButton1Click:Connect(toggleOverwrite)
    cancelButton.MouseButton1Click:Connect(cleanup)
    
    confirmButton.MouseButton1Click:Connect(function()
        local url = urlBox.Text
        local name = nameBox.Text
        
        if url == "" or name == "" then
            Interpreter.sendChatMessage("INSTALL: URL and name cannot be empty")
            return
        end
        
        local success, result = installPluginFromUrl(url, name)
        if success then
            Interpreter.sendChatMessage("INSTALL: " .. result)
        else
            Interpreter.sendChatMessage("INSTALL: " .. result)
        end
        
        cleanup()
    end)
    
    -- Enter key to confirm
    urlBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            nameBox:CaptureFocus()
        end
    end)
    
    nameBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            confirmButton.MouseButton1Click:Fire()
        end
    end)
    
    -- Auto-focus URL box
    task.spawn(function()
        task.wait(0.5) -- Wait a bit for GUI to fully load
        if urlBox and urlBox.Parent then
            urlBox:CaptureFocus()
        end
    end)
    
    print("RuptorX: Install GUI created successfully")
end

-- FIXED Plugin Execution System
local function executePlugin(pluginName, flags)
    local pluginPath = Interpreter.PluginStarters[pluginName:lower()]
    if not pluginPath or not isfile(pluginPath) then
        return false, "Plugin not found: " .. pluginName
    end
    
    local success, pluginCode = pcall(readfile, pluginPath)
    if not success then
        return false, "Failed to read plugin file: " .. pluginPath
    end
    
    -- Create proper plugin environment with all required globals
    local pluginEnv = {}
    
    -- Copy all standard Lua libraries
    for k, v in pairs(getfenv(0)) do
        pluginEnv[k] = v
    end
    
    -- Add RootKit API with proper references
    pluginEnv.register = function(cmdName)
        return Interpreter.register(cmdName)
    end
    
    pluginEnv.ismobile = function()
        return Interpreter.ismobile()
    end
    
    pluginEnv.checkshutdown = function()
        return Interpreter.checkshutdown()
    end
    
    pluginEnv.functionend = function()
        return Interpreter.functionend()
    end
    
    -- Make flags available as both 'flags' and 'arg'
    pluginEnv.flags = flags or {}
    pluginEnv.arg = flags or {}
    
    -- Create plugin function with proper environment
    local pluginFunc, compileError = loadstring(pluginCode, "Plugin:" .. pluginName)
    if not pluginFunc then
        return false, "Plugin compilation error: " .. tostring(compileError)
    end
    
    -- Set the environment
    setfenv(pluginFunc, pluginEnv)
    
    -- Execute plugin
    local success, runtimeError = pcall(pluginFunc)
    if not success then
        return false, "Plugin runtime error: " .. tostring(runtimeError)
    end
    
    return true, "Plugin executed: " .. pluginName
end

-- Plugin Management Commands
local function listPlugins()
    local registryPath = "ruptorx/plugin_registry.json"
    if not isfile(registryPath) then
        return "No plugins installed"
    end
    
    local success, registry = pcall(function()
        return HttpService:JSONDecode(readfile(registryPath))
    end)
    
    if not success then
        return "Failed to read plugin registry"
    end
    
    local pluginList = {}
    for name, data in pairs(registry) do
        table.insert(pluginList, {
            name = name,
            command = data.command,
            installed = data.installed
        })
    end
    
    if #pluginList == 0 then
        return "No plugins installed"
    end
    
    table.sort(pluginList, function(a, b)
        return a.installed < b.installed
    end)
    
    local result = "Installed Plugins (" .. #pluginList .. "):\n"
    for i, plugin in ipairs(pluginList) do
        result = result .. i .. ". " .. plugin.name .. " (*." .. plugin.command .. ")\n"
    end
    
    return result
end

-- Built-in handlers
Interpreter.Handlers = {
    print = function(flags)
        local message = table.concat(flags, " ")
        print("PRINT: " .. message)
    end,
    
    count = function(flags)
        print("Flag count: " .. #flags)
        for i, flag in ipairs(flags) do
            print(i .. ": " .. flag)
        end
    end,
    
    install = function(flags)
        if #flags == 0 then
            warn("INSTALL: Please specify a URL or 'gui'")
            return
        end
    
        if flags[1]:lower() == "gui" then
            print("RuptorX: Opening install GUI...")
            createInstallGui()
        elseif flags[1]:lower() == "overwrite" then
            Interpreter.InstallOverwrite = true
            print("INSTALL: Overwrite mode enabled for next installation")
        elseif flags[1]:lower() == "list" then
            local pluginList = listPlugins()
            print("PLUGIN LIST:\n" .. pluginList)
        else
            local url = flags[1]
            local pluginName = flags[2] or "unnamed_plugin"
        
            local success, result = installPluginFromUrl(url, pluginName)
            if success then
                print("INSTALL: " .. result)
            else
                warn("INSTALL: " .. result)
            end
        end
    end,
    
    team = function(flags)
        if #flags == 0 then
            warn("TEAM: Please specify a team name")
            return
        end
        
        local teamName = flags[1]
        local foundTeam = nil
        
        for _, team in ipairs(Teams:GetTeams()) do
            if team.Name:lower() == teamName:lower() then
                foundTeam = team
                break
            end
        end
        
        if foundTeam then
            local player = Players.LocalPlayer
            if player then
                player.Team = foundTeam
                print("TEAM: Switched to " .. foundTeam.Name)
            end
        else
            warn("TEAM: Team '" .. teamName .. "' not found")
        end
    end,
    
    pteam = function(flags)
        if #flags == 0 then
            warn("PTEAM: Please specify a team name")
            return
        end
        
        local teamName = flags[1]
        local foundTeam = nil
        
        for _, team in ipairs(Teams:GetTeams()) do
            if team.Name:lower() == teamName:lower() then
                foundTeam = team
                break
            end
        end
        
        if foundTeam then
            Interpreter.startPTeam(foundTeam)
        else
            warn("PTEAM: Team '" .. teamName .. "' not found")
        end
    end,
    
    uteam = function(flags)
        Interpreter.stopPTeam()
    end,
    
    health = function(flags)
        if #flags == 0 then
            local humanoid = Interpreter.getHumanoid()
            if humanoid then
                print("HEALTH: Current health is " .. humanoid.Health)
            end
            return
        end
        
        local newHealth = tonumber(flags[1])
        if not newHealth then
            warn("HEALTH: Please provide a valid number")
            return
        end
        
        local humanoid = Interpreter.getHumanoid()
        if humanoid then
            humanoid.Health = newHealth
            print("HEALTH: Set health to " .. newHealth)
        else
            warn("HEALTH: Character or humanoid not found")
        end
    end,
    
    phealth = function(flags)
        if #flags == 0 then
            warn("PHEALTH: Please specify a health value")
            return
        end
        
        local newHealth = tonumber(flags[1])
        if not newHealth then
            warn("PHEALTH: Please provide a valid number")
            return
        end
        
        Interpreter.CustomHealth = newHealth
        Interpreter.startPHealth()
        print("PHEALTH: Persistent health set to " .. newHealth)
    end,
    
    nostun = function(flags)
        local state = flags[1] and flags[1]:lower() or "toggle"
        
        if state == "on" or state == "true" or (state == "toggle" and not Interpreter.NoStun) then
            Interpreter.startNoStun()
        else
            Interpreter.stopNoStun()
        end
    end,
    
    reset = function(flags)
        Interpreter.quickReset()
    end,
    
    unfly = function(flags)
        Interpreter.stopAllFlying()
    end,
    
    noclip = function(flags)
        local state = flags[1] and flags[1]:lower() or "toggle"
        
        if state == "on" or state == "true" or (state == "toggle" and not Interpreter.Noclipping) then
            Interpreter.startNoclip()
        else
            Interpreter.stopNoclip()
        end
    end,
    
    to = function(flags)
        if #flags == 0 then
            warn("TO: Please specify a player name")
            return
        end
        
        local targetName = flags[1]
        local targetPlayer = nil
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer and 
               (player.Name:lower():find(targetName:lower()) or 
                player.DisplayName:lower():find(targetName:lower())) then
                targetPlayer = player
                break
            end
        end
        
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            Interpreter.startTo(targetPlayer)
        else
            warn("TO: Player '" .. targetName .. "' not found or doesn't have a character")
        end
    end,
    
    spin = function(flags)
        local state = flags[1] and flags[1]:lower() or "toggle"
        local speed = tonumber(flags[2]) or Interpreter.SpinSpeed
        
        if speed and speed > 0 then
            Interpreter.SpinSpeed = speed
        end
        
        if state == "on" or state == "true" or (state == "toggle" and not Interpreter.Spinning) then
            Interpreter.startSpin()
        else
            Interpreter.stopSpin()
        end
    end,
    
    speed = function(flags)
        if #flags == 0 then
            local humanoid = Interpreter.getHumanoid()
            if humanoid then
                print("SPEED: Current walkspeed is " .. humanoid.WalkSpeed)
            end
            return
        end
        
        local newSpeed = tonumber(flags[1])
        if not newSpeed then
            warn("SPEED: Please provide a valid number")
            return
        end
        
        Interpreter.CustomWalkSpeed = newSpeed
        Interpreter.applySpeedAndJump()
        print("SPEED: Set walkspeed to " .. newSpeed)
    end,
    
    jump = function(flags)
        if #flags == 0 then
            local humanoid = Interpreter.getHumanoid()
            if humanoid then
                print("JUMP: Current jump power is " .. humanoid.JumpPower)
            end
            return
        end
        
        local newJump = tonumber(flags[1])
        if not newJump then
            warn("JUMP: Please provide a valid number")
            return
        end
        
        Interpreter.CustomJumpPower = newJump
        Interpreter.applySpeedAndJump()
        print("JUMP: Set jump power to " .. newJump)
    end,
    
    dance = function(flags)
        local player = Players.LocalPlayer
        if player then
            local dances = {"dance1", "dance2", "dance3"}
            local randomDance = dances[math.random(1, #dances)]
            
            player:Chat("/e " .. randomDance)
            print("DANCE: Performing " .. randomDance)
        end
    end,
    
    lockto = function(flags)
        if #flags == 0 then
            warn("LOCKTO: Please specify a player name")
            return
        end
        
        local targetName = flags[1]
        local targetPlayer = nil
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer and 
               (player.Name:lower():find(targetName:lower()) or 
                player.DisplayName:lower():find(targetName:lower())) then
                targetPlayer = player
                break
            end
        end
        
        if targetPlayer then
            Interpreter.startLockTo(targetPlayer)
        else
            warn("LOCKTO: Player '" .. targetName .. "' not found")
        end
    end,
    
    unlock = function(flags)
        Interpreter.stopLockTo()
    end,
    
    follow = function(flags)
        if #flags == 0 then
            warn("FOLLOW: Please specify a player name")
            return
        end
        
        local targetName = flags[1]
        local targetPlayer = nil
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer and 
               (player.Name:lower():find(targetName:lower()) or 
                player.DisplayName:lower():find(targetName:lower())) then
                targetPlayer = player
                break
            end
        end
        
        if targetPlayer then
            Interpreter.startFollow(targetPlayer)
        else
            warn("FOLLOW: Player '" .. targetName .. "' not found")
        end
    end,
    
    sflw = function(flags)
        Interpreter.stopFollow()
    end,
    
    orbit = function(flags)
        if #flags == 0 then
            warn("ORBIT: Please specify a player name")
            return
        end
        
        local targetName = flags[1]
        local speed = tonumber(flags[2]) or Interpreter.OrbitSpeed
        
        local targetPlayer = nil
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer and 
               (player.Name:lower():find(targetName:lower()) or 
                player.DisplayName:lower():find(targetName:lower())) then
                targetPlayer = player
                break
            end
        end
        
        if targetPlayer then
            Interpreter.startOrbit(targetPlayer, speed)
        else
            warn("ORBIT: Player '" .. targetName .. "' not found")
        end
    end,
    
    sorbit = function(flags)
        Interpreter.stopOrbit()
    end,
    
    troll = function(flags)
        local teamFilter = nil
        local excludeTeam = nil
        
        for i = 1, #flags do
            if flags[i]:lower() == "ex" and i + 1 <= #flags then
                excludeTeam = flags[i + 1]
            elseif flags[i]:lower() == "sp" and i + 1 <= #flags then
                teamFilter = flags[i + 1]
            end
        end
        
        Interpreter.startTroll(teamFilter, excludeTeam)
    end,
    
    stoptroll = function(flags)
        Interpreter.stopTroll()
    end,
    
    flingtouch = function(flags)
        Interpreter.startFlingTouch()
    end,
    
    sft = function(flags)
        Interpreter.stopFlingTouch()
    end,
    
    float = function(flags)
        if #flags == 0 then
            warn("FLOAT: Please specify a height in studs")
            return
        end
        
        local height = tonumber(flags[1])
        if not height then
            warn("FLOAT: Please provide a valid number")
            return
        end
        
        Interpreter.startFloat(height)
    end,
    
    sfloat = function(flags)
        Interpreter.stopFloat()
    end,
    
    shutdown = function(flags)
        Interpreter.shutdown()
    end
}

-- Quick Reset system
function Interpreter.quickReset()
    local character = Interpreter.getCharacter()
    local rootPart = Interpreter.getRootPart()
    
    if not character or not rootPart then return end
    
    Interpreter.RespawnPosition = rootPart.Position
    
    local humanoid = Interpreter.getHumanoid()
    if humanoid then
        humanoid.Health = 0
    end
    
    print("RESET: Quick reset initiated")
end

-- Persistent Health system
function Interpreter.startPHealth()
    if Interpreter.PHealthActive then return end
    
    Interpreter.PHealthActive = true
    
    Interpreter.PHealthConnection = task.spawn(function()
        while Interpreter.Active and Interpreter.PHealthActive do
            local humanoid = Interpreter.getHumanoid()
            if humanoid and Interpreter.CustomHealth then
                humanoid.Health = Interpreter.CustomHealth
            end
            task.wait(0.1)
        end
    end)
    
    print("PHEALTH: Persistent health activated")
end

function Interpreter.stopPHealth()
    if not Interpreter.PHealthActive then return end
    
    Interpreter.PHealthActive = false
    Interpreter.PHealthConnection = nil
    Interpreter.CustomHealth = nil
    print("PHEALTH: Persistent health deactivated")
end

-- No Stun system
function Interpreter.startNoStun()
    if Interpreter.NoStun then return end
    
    Interpreter.NoStun = true
    
    Interpreter.NoStunConnection = RunService.Heartbeat:Connect(function()
        if not Interpreter.Active or not Interpreter.NoStun then
            Interpreter.stopNoStun()
            return
        end
        
        local humanoid = Interpreter.getHumanoid()
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.Sit = false
            local rootPart = Interpreter.getRootPart()
            if rootPart then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 0, rootPart.Velocity.Z)
            end
        end
    end)
    
    print("NOSTUN: No stun activated")
end

function Interpreter.stopNoStun()
    if not Interpreter.NoStun then return end
    
    if Interpreter.NoStunConnection then
        Interpreter.NoStunConnection:Disconnect()
        Interpreter.NoStunConnection = nil
    end
    
    Interpreter.NoStun = false
    print("NOSTUN: No stun deactivated")
end

-- Float system
function Interpreter.startFloat(height)
    if Interpreter.Floating then
        Interpreter.stopFloat()
    end
    
    Interpreter.FloatHeight = height or 5
    Interpreter.Floating = true
    
    local rootPart = Interpreter.getRootPart()
    if not rootPart then return end
    
    local bp = Instance.new("BodyPosition")
    bp.Position = rootPart.Position + Vector3.new(0, Interpreter.FloatHeight, 0)
    bp.MaxForce = Vector3.new(0, 40000, 0)
    bp.Parent = rootPart
    
    Interpreter.FloatBP = bp
    
    Interpreter.FloatConnection = RunService.Heartbeat:Connect(function()
        if not Interpreter.Active or not Interpreter.Floating or not Interpreter.FloatBP then
            Interpreter.stopFloat()
            return
        end
        
        local root = Interpreter.getRootPart()
        if not root then return end
        
        local rayOrigin = root.Position
        local rayDirection = Vector3.new(0, -50, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {Interpreter.getCharacter()}
        
        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        
        if raycastResult then
            Interpreter.FloatBP.Position = raycastResult.Position + Vector3.new(0, Interpreter.FloatHeight, 0)
        else
            Interpreter.FloatBP.Position = Vector3.new(root.Position.X, root.Position.Y, root.Position.Z)
        end
    end)
    
    print("FLOAT: Floating at " .. Interpreter.FloatHeight .. " studs above ground")
end

function Interpreter.stopFloat()
    if not Interpreter.Floating then return end
    
    if Interpreter.FloatConnection then
        Interpreter.FloatConnection:Disconnect()
        Interpreter.FloatConnection = nil
    end
    
    if Interpreter.FloatBP then
        Interpreter.FloatBP:Destroy()
        Interpreter.FloatBP = nil
    end
    
    Interpreter.Floating = false
    print("FLOAT: Floating deactivated")
end

-- Fling Touch system
function Interpreter.startFlingTouch()
    if Interpreter.FlingTouch then return end
    
    Interpreter.FlingTouch = true
    
    local function setupFlingForCharacter(char)
        if not char then return end
        
        Interpreter.stopFlingTouch(true)
        
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                local connection = part.Touched:Connect(function(hit)
                    if not Interpreter.Active or not Interpreter.FlingTouch then return end
                    
                    local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
                    if hitPlayer and hitPlayer ~= Players.LocalPlayer then
                        local hitRoot = hit.Parent:FindFirstChild("HumanoidRootPart")
                        if hitRoot then
                            local currentVel = hitRoot.Velocity
                            hitRoot.Velocity = currentVel * 10000 + Vector3.new(0, 10000, 0)
                        end
                    end
                end)
                table.insert(Interpreter.FlingTouchEvents, connection)
            end
        end
    end
    
    local currentChar = Interpreter.getCharacter()
    if currentChar then
        setupFlingForCharacter(currentChar)
    end
    
    Interpreter.FlingTouchConnection = Players.LocalPlayer.CharacterAdded:Connect(function(char)
        if Interpreter.FlingTouch then
            setupFlingForCharacter(char)
        end
    end)
    
    print("FLINGTOUCH: Fling touch activated")
end

function Interpreter.stopFlingTouch(softStop)
    if not softStop then
        if not Interpreter.FlingTouch then return end
        
        if Interpreter.FlingTouchConnection then
            Interpreter.FlingTouchConnection:Disconnect()
            Interpreter.FlingTouchConnection = nil
        end
        Interpreter.FlingTouch = false
        print("FLINGTOUCH: Fling touch deactivated")
    end
    
    for _, event in ipairs(Interpreter.FlingTouchEvents) do
        event:Disconnect()
    end
    Interpreter.FlingTouchEvents = {}
end

-- Troll system
function Interpreter.startTroll(teamFilter, excludeTeam)
    if Interpreter.Trolling then
        Interpreter.stopTroll()
    end
    
    Interpreter.Trolling = true
    Interpreter.TrollTeamFilter = teamFilter
    Interpreter.TrollExcludeTeam = excludeTeam
    
    Interpreter.TrollConnection = task.spawn(function()
        while Interpreter.Active and Interpreter.Trolling do
            Interpreter.TrollTargets = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= Players.LocalPlayer then
                    local includePlayer = true
                    if Interpreter.TrollTeamFilter and player.Team then
                        includePlayer = player.Team.Name:lower() == Interpreter.TrollTeamFilter:lower()
                    end
                    if Interpreter.TrollExcludeTeam and player.Team then
                        includePlayer = player.Team.Name:lower() ~= Interpreter.TrollExcludeTeam:lower()
                    end
                    
                    if includePlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        table.insert(Interpreter.TrollTargets, player)
                    end
                end
            end
            
            if #Interpreter.TrollTargets > 0 then
                local randomTarget = Interpreter.TrollTargets[math.random(1, #Interpreter.TrollTargets)]
                local rootPart = Interpreter.getRootPart()
                
                if rootPart and randomTarget.Character and randomTarget.Character.HumanoidRootPart then
                    rootPart.CFrame = randomTarget.Character.HumanoidRootPart.CFrame
                end
            end
            
            task.wait(0.1)
        end
    end)
    
    local filterText = ""
    if teamFilter then filterText = " (team: " .. teamFilter .. ")"
    elseif excludeTeam then filterText = " (exclude: " .. excludeTeam .. ")" end
    
    print("TROLL: Trolling activated" .. filterText)
end

function Interpreter.stopTroll()
    if not Interpreter.Trolling then return end
    
    Interpreter.Trolling = false
    Interpreter.TrollConnection = nil
    
    Interpreter.TrollTeamFilter = nil
    Interpreter.TrollExcludeTeam = nil
    Interpreter.TrollTargets = {}
    print("TROLL: Trolling deactivated")
end

-- To command
function Interpreter.startTo(targetPlayer)
    local char = Interpreter.getCharacter()
    local rootPart = Interpreter.getRootPart()
    
    if not char or not rootPart then return end
    
    task.spawn(function()
        local startTime = tick()
        while Interpreter.Active and tick() - startTime < Interpreter.ToDuration do
            if targetPlayer.Character and targetPlayer.Character.HumanoidRootPart then
                local root = Interpreter.getRootPart()
                if root then
                    root.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
                end
            else
                break
            end
            RunService.Heartbeat:Wait()
        end
    end)
    
    print("TO: Teleporting to " .. targetPlayer.Name .. " for " .. Interpreter.ToDuration .. " seconds")
end

-- Orbit system
function Interpreter.startOrbit(targetPlayer, speed)
    if Interpreter.Orbiting then
        Interpreter.stopOrbit()
    end
    
    Interpreter.OrbitTarget = targetPlayer
    Interpreter.OrbitSpeed = speed or 10
    Interpreter.Orbiting = true
    
    local orbitAngle = 0
    
    Interpreter.OrbitConnection = RunService.Heartbeat:Connect(function()
        if not Interpreter.Active or not Interpreter.Orbiting or not Interpreter.OrbitTarget then
            Interpreter.stopOrbit()
            return
        end
        
        local localRoot = Interpreter.getRootPart()
        local targetChar = Interpreter.OrbitTarget.Character
        
        if not localRoot then return end
        
        if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then
            print("ORBIT: Target character not found, stopping orbit")
            Interpreter.stopOrbit()
            return
        end
        
        local targetRoot = targetChar.HumanoidRootPart
        orbitAngle = orbitAngle + Interpreter.OrbitSpeed * 0.01
        
        local x = math.cos(orbitAngle) * Interpreter.OrbitDistance
        local z = math.sin(orbitAngle) * Interpreter.OrbitDistance
        
        local orbitPosition = targetRoot.Position + Vector3.new(x, 2, z)
        
        localRoot.CFrame = CFrame.lookAt(orbitPosition, targetRoot.Position)
    end)
    
    print("ORBIT: Orbiting " .. targetPlayer.Name .. " at speed " .. Interpreter.OrbitSpeed)
end

function Interpreter.stopOrbit()
    if not Interpreter.Orbiting then return end
    
    if Interpreter.OrbitConnection then
        Interpreter.OrbitConnection:Disconnect()
        Interpreter.OrbitConnection = nil
    end
    
    Interpreter.OrbitTarget = nil
    Interpreter.Orbiting = false
    print("ORBIT: Stopped orbiting")
end

-- Follow system
function Interpreter.startFollow(targetPlayer)
    if Interpreter.Following then
        Interpreter.stopFollow()
    end
    
    Interpreter.FollowTarget = targetPlayer
    Interpreter.Following = true
    
    Interpreter.FollowConnection = RunService.Heartbeat:Connect(function()
        if not Interpreter.Active or not Interpreter.Following or not Interpreter.FollowTarget then
            Interpreter.stopFollow()
            return
        end
        
        local localRoot = Interpreter.getRootPart()
        local targetChar = Interpreter.FollowTarget.Character
        
        if not localRoot then return end
        
        if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then
            print("FOLLOW: Target character not found, stopping follow")
            Interpreter.stopFollow()
            return
        end
        
        local targetRoot = targetChar.HumanoidRootPart
        localRoot.CFrame = targetRoot.CFrame
    end)
    
    print("FOLLOW: Following " .. targetPlayer.Name)
end

function Interpreter.stopFollow()
    if not Interpreter.Following then return end
    
    if Interpreter.FollowConnection then
        Interpreter.FollowConnection:Disconnect()
        Interpreter.FollowConnection = nil
    end
    
    Interpreter.FollowTarget = nil
    Interpreter.Following = false
    print("FOLLOW: Stopped following")
end

-- Persistent Team system
function Interpreter.startPTeam(team)
    if Interpreter.PTeamLock then
        Interpreter.stopPTeam()
    end
    
    Interpreter.PTeamTarget = team
    Interpreter.PTeamLock = true
    
    Interpreter.PTeamConnection = task.spawn(function()
        while Interpreter.Active and Interpreter.PTeamLock do
            local player = Players.LocalPlayer
            if player and player.Team ~= Interpreter.PTeamTarget then
                player.Team = Interpreter.PTeamTarget
            end
            task.wait(0.5)
        end
    end)
    
    print("PTEAM: Locked to " .. team.Name .. " team")
end

function Interpreter.stopPTeam()
    if not Interpreter.PTeamLock then return end
    
    Interpreter.PTeamLock = false
    Interpreter.PTeamConnection = nil
    
    Interpreter.PTeamTarget = nil
    print("PTEAM: Team lock disabled")
end

-- LockTo system
function Interpreter.startLockTo(targetPlayer)
    if Interpreter.Locking then
        Interpreter.stopLockTo()
    end
    
    Interpreter.LockTarget = targetPlayer
    Interpreter.Locking = true
    
    Interpreter.LockConnection = RunService.Heartbeat:Connect(function()
        if not Interpreter.Active or not Interpreter.Locking or not Interpreter.LockTarget then
            Interpreter.stopLockTo()
            return
        end
        
        local localRoot = Interpreter.getRootPart()
        local targetChar = Interpreter.LockTarget.Character
        
        if not localRoot then return end
        
        if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then
            print("LOCKTO: Target character not found, stopping lock")
            Interpreter.stopLockTo()
            return
        end
        
        local targetRoot = targetChar.HumanoidRootPart
        
        local direction = (targetRoot.Position - localRoot.Position).Unit
        if direction.Magnitude > 0 then
            localRoot.CFrame = CFrame.lookAt(localRoot.Position, localRoot.Position + Vector3.new(direction.X, 0, direction.Z))
        end
    end)
    
    print("LOCKTO: Locked to " .. targetPlayer.Name)
end

function Interpreter.stopLockTo()
    if not Interpreter.Locking then return end
    
    if Interpreter.LockConnection then
        Interpreter.LockConnection:Disconnect()
        Interpreter.LockConnection = nil
    end
    
    Interpreter.LockTarget = nil
    Interpreter.Locking = false
    print("LOCKTO: Unlocked")
end

-- Apply speed and jump to current character
function Interpreter.applySpeedAndJump()
    local humanoid = Interpreter.getHumanoid()
    if humanoid then
        if Interpreter.CustomWalkSpeed then
            humanoid.WalkSpeed = Interpreter.CustomWalkSpeed
        end
        
        if Interpreter.CustomJumpPower then
            humanoid.JumpPower = Interpreter.CustomJumpPower
        end
    end
end

-- Stop all flying systems
function Interpreter.stopAllFlying()
    local humanoid = Interpreter.getHumanoid()
    if humanoid then
        humanoid.PlatformStand = false
    end
    
    if Interpreter.FlightConnection then
        Interpreter.FlightConnection:Disconnect()
        Interpreter.FlightConnection = nil
    end
    
    if Interpreter.FlightBV then
        Interpreter.FlightBV:Destroy()
        Interpreter.FlightBV = nil
    end
    
    if Interpreter.FlightBG then
        Interpreter.FlightBG:Destroy()
        Interpreter.FlightBG = nil
    end
    
    Interpreter.Flying = false
    print("UNFLY: All flying systems disabled")
end

-- Simple Noclip system
function Interpreter.startNoclip()
    if Interpreter.Noclipping then return end
    Interpreter.Noclipping = true
    
    local function noclipCharacter(char)
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
    
    local character = Interpreter.getCharacter()
    if character then
        noclipCharacter(character)
    end
    
    print("NOCLIP: Noclip enabled")
end

function Interpreter.stopNoclip()
    if not Interpreter.Noclipping then return end
    Interpreter.Noclipping = false
    
    local character = Interpreter.getCharacter()
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
    
    print("NOCLIP: Noclip disabled")
end

-- Spinning system
function Interpreter.startSpin()
    local rootPart = Interpreter.getRootPart()
    if not rootPart then return end
    
    if Interpreter.Spinning and Interpreter.SpinAV then
        Interpreter.SpinAV.AngularVelocity = Vector3.new(0, Interpreter.SpinSpeed, 0)
        print("SPIN: Updated spin speed to " .. Interpreter.SpinSpeed)
        return
    end
    
    local av = Instance.new("BodyAngularVelocity")
    av.AngularVelocity = Vector3.new(0, Interpreter.SpinSpeed, 0)
    av.MaxTorque = Vector3.new(0, math.huge, 0)
    av.Parent = rootPart
    
    Interpreter.SpinAV = av
    Interpreter.Spinning = true
    
    print("SPIN: Spinning enabled at speed " .. Interpreter.SpinSpeed)
end

function Interpreter.stopSpin()
    if not Interpreter.Spinning then return end
    
    Interpreter.Spinning = false
    
    if Interpreter.SpinAV then
        Interpreter.SpinAV:Destroy()
        Interpreter.SpinAV = nil
    end
    
    print("SPIN: Spinning disabled")
end

-- Updated command processor with plugin support
function Interpreter.processCommand(commandString)
    if not Interpreter.Active then
        warn("Interpreter: System is shut down")
        return false
    end
    
    local commandWithoutPrefix = commandString:sub(2)
    
    local parts = {}
    for part in commandWithoutPrefix:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then
        warn("Interpreter: No command specified")
        return false
    end
    
    local handlerName = parts[1]:lower()
    local handler = Interpreter.Handlers[handlerName]
    
    if handler then
        local flags = {}
        for i = 2, #parts do
            table.insert(flags, parts[i])
        end
        
        local success, result = pcall(handler, flags)
        
        if not success then
            warn("Interpreter: Handler error: " .. tostring(result))
            return false
        end
        
        return true
    else
        -- Check if it's a plugin command
        if Interpreter.PluginHandlers[handlerName] then
            local flags = {}
            for i = 2, #parts do
                table.insert(flags, parts[i])
            end
            
            local success, result = executePlugin(handlerName, flags)
            if not success then
                warn("PLUGIN: " .. result)
                return false
            end
            
            return true
        else
            warn("Interpreter: Handler not found: " .. handlerName)
            return false
        end
    end
end

-- Updated shutdown with plugin notification
function Interpreter.shutdown()
    if not Interpreter.Active then return end
    
    print("RuptorX: Shutting down...")
    
    -- Notify plugins of shutdown
    Interpreter.ShuttingDown = true
    wait(1)
    
    Interpreter.Active = false
    
    -- Stop all active systems
    Interpreter.stopAllFlying()
    Interpreter.stopNoclip()
    Interpreter.stopSpin()
    Interpreter.stopLockTo()
    Interpreter.stopPTeam()
    Interpreter.stopFollow()
    Interpreter.stopOrbit()
    Interpreter.stopTroll()
    Interpreter.stopFlingTouch()
    Interpreter.stopFloat()
    Interpreter.stopNoStun()
    Interpreter.stopPHealth()
    
    if Interpreter.ChatConnection then
        Interpreter.ChatConnection:Disconnect()
        Interpreter.ChatConnection = nil
    end
    
    if Interpreter.SpeedLoop then
        Interpreter.SpeedLoop = nil
    end
    
    Interpreter.CustomWalkSpeed = nil
    Interpreter.CustomJumpPower = nil
    Interpreter.CustomHealth = nil
    
    local humanoid = Interpreter.getHumanoid()
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end
    
    print("RuptorX: Shutdown complete")
    Interpreter.sendChatMessage("RuptorX has been shut down.")
end

-- Load existing plugins on startup
local function loadExistingPlugins()
    if not (isfolder and isfile and readfile) then return end
    
    local registryPath = "ruptorx/plugin_registry.json"
    if not isfile(registryPath) then return end
    
    local success, registry = pcall(function()
        return HttpService:JSONDecode(readfile(registryPath))
    end)
    
    if not success then return end
    
    for pluginName, pluginData in pairs(registry) do
        if isfile(pluginData.path) then
            Interpreter.PluginStarters[pluginData.command] = pluginData.path
            Interpreter.PluginHandlers[pluginData.command] = true
        end
    end
    
    print("ROOTKIT: Loaded " .. #Interpreter.PluginStarters .. " plugins from registry")
end

-- Loop to maintain speed and jump settings
Interpreter.SpeedLoop = task.spawn(function()
    while Interpreter.Active do
        pcall(function()
            Interpreter.applySpeedAndJump()
        end)
        task.wait(0.5)
    end
end)

-- Cleanup on character reset
Players.LocalPlayer.CharacterAdded:Connect(function(character)
    if not Interpreter.Active then return end
    
    Interpreter.Flying = false
    Interpreter.Spinning = false
    
    if Interpreter.FlightBV then Interpreter.FlightBV:Destroy() end
    if Interpreter.FlightBG then Interpreter.FlightBG:Destroy() end
    if Interpreter.SpinAV then Interpreter.SpinAV:Destroy() end
    
    if Interpreter.RespawnPosition then
        task.spawn(function()
            local rootPart = character:WaitForChild("HumanoidRootPart")
            task.wait()
            rootPart.CFrame = CFrame.new(Interpreter.RespawnPosition)
            Interpreter.RespawnPosition = nil
            print("RESET: Teleported to saved position")
        end)
    end
    
    task.wait(0.1)
    
    if Interpreter.Noclipping then
        Interpreter.startNoclip()
    end
    
    Interpreter.applySpeedAndJump()
end)

-- Initialize chat listener
function Interpreter.init()
    local player = Players.LocalPlayer
    
    if player then
        -- Load any existing plugins
        loadExistingPlugins()
        
        Interpreter.ChatConnection = player.Chatted:Connect(function(message)
            if message:sub(1, 1) == "*" then
                Interpreter.processCommand(message)
            end
        end)
        
        task.wait(1)
        Interpreter.sendChatMessage("RuptorX RootKit Enabled - Plugin System Active")
        
        print("RuptorX RootKit: Chat listener activated")
        print("RuptorX RootKit: Plugin system ready - use *.install gui")
        print("RuptorX RootKit: Built-in commands available")
        print("RuptorX RootKit: " .. #Interpreter.PluginStarters .. " plugins loaded")
    else
        warn("RuptorX RootKit: Player not found")
    end
    
    return Interpreter
end

-- RUPTORX_PLUGIN_MARKER_DO_NOT_MODIFY --
return Interpreter
