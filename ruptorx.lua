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
Interpreter.PluginRegistry = {}
Interpreter.InstallOverwrite = false
Interpreter.ShuttingDown = false
Interpreter.PluginMarker = "-- RUPTORX_PLUGIN_MARKER --"

-- Lock file paths
Interpreter.IncrementLock = "ruptorx/increment.lock"
Interpreter.RestartLock = "ruptorx/restart.lock"
Interpreter.ShutdownLock = "ruptorx/shutdown.lock"

-- Increment counter for crash detection
Interpreter.IncrementCounter = 0
Interpreter.IncrementThread = nil

-- Check if we're on mobile
Interpreter.IsMobile = UserInputService.TouchEnabled

-- RootKit API Functions (EXPOSED TO PLUGINS)
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

-- Lock File Management
function Interpreter.startIncrementSystem()
    if Interpreter.IncrementThread then return end
    
    Interpreter.IncrementThread = task.spawn(function()
        while Interpreter.Active do
            if writefile then
                pcall(function()
                    Interpreter.IncrementCounter = Interpreter.IncrementCounter + 1
                    writefile(Interpreter.IncrementLock, tostring(Interpreter.IncrementCounter))
                end)
            end
            wait(2) -- Increment every 2 seconds
        end
    end)
end

function Interpreter.requestRestart()
    if not writefile then return false end
    
    pcall(function()
        writefile(Interpreter.RestartLock, "restart_requested")
    end)
    
    Interpreter.shutdown()
    return true
end

function Interpreter.requestShutdown()
    if not writefile then return false end
    
    pcall(function()
        writefile(Interpreter.ShutdownLock, "shutdown_requested")
    end)
    
    Interpreter.shutdown()
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

-- Plugin Installation System (EMBEDDING)
local function embedPluginIntoMain(pluginName, pluginCode, commandName)
    if not (writefile and readfile and isfile) then
        return false, "File functions not available"
    end
    
    local mainPath = "ruptorx/ruptorx.lua"
    if not isfile(mainPath) then
        return false, "Main script not found"
    end
    
    -- Read main script
    local mainContent = readfile(mainPath)
    
    -- Find marker position
    local markerPos = mainContent:find(Interpreter.PluginMarker)
    if not markerPos then
        return false, "Plugin marker not found in main script"
    end
    
    -- Create safe plugin wrapper
    local safePluginCode = string.format([[
-- PLUGIN: %s (Command: *.%s)
do
    local plugin_success, plugin_error = pcall(function()
        %s
    end)
    if not plugin_success then
        warn("PLUGIN LOAD ERROR [" .. "%s" .. "]: " .. tostring(plugin_error))
    end
end
%s
]], pluginName, commandName:lower(), pluginCode, pluginName, Interpreter.PluginMarker)
    
    -- Insert plugin code before marker
    local newContent = mainContent:sub(1, markerPos - 1) .. safePluginCode .. mainContent:sub(markerPos)
    
    -- Write updated main script
    writefile(mainPath, newContent)
    
    return true, "Plugin embedded successfully"
end

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
            return HttpService:JSONEncode(readfile(registryPath))
        end)
        if success and regData then
            registry = HttpService:JSONDecode(regData) or {}
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
    
    -- Extract command name from register call
    local commandName = pluginCode:match("register%(\"([%w_]+)\"%)")
    if not commandName then
        return false, "Plugin missing valid register call"
    end
    
    -- Save plugin file for backup
    local pluginPath = pluginFolder .. "/" .. pluginName .. ".lua"
    writefile(pluginPath, pluginCode)
    
    -- Embed plugin into main script
    local embedSuccess, embedResult = embedPluginIntoMain(pluginName, pluginCode, commandName)
    if not embedSuccess then
        return false, "Failed to embed plugin: " .. embedResult
    end
    
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
    
    -- Trigger restart
    Interpreter.requestRestart()
    
    Interpreter.InstallOverwrite = false
    return true, "Plugin '" .. pluginName .. "' installed as command '*." .. commandName .. "'. Restarting..."
end

-- GUI Installer
local function createInstallGui()
    local player = Players.LocalPlayer
    if not player then return end
    
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        playerGui = player:WaitForChild("PlayerGui", 2)
        if not playerGui then return end
    end
    
    -- Clean up existing GUI
    local existingGui = playerGui:FindFirstChild("RuptorXInstallGui")
    if existingGui then
        existingGui:Destroy()
    end
    
    -- Create main frame
    local screenGui = Instance.new("ScreenGui")
    local frame = Instance.new("Frame")
    local urlBox = Instance.new("TextBox")
    local nameBox = Instance.new("TextBox")
    local confirmButton = Instance.new("TextButton")
    local cancelButton = Instance.new("TextButton")
    local title = Instance.new("TextLabel")
    local urlLabel = Instance.new("TextLabel")
    local nameLabel = Instance.new("TextLabel")
    
    screenGui.Name = "RuptorXInstallGui"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false
    
    frame.Size = UDim2.new(0, 400, 0, 250)
    frame.Position = UDim2.new(0.5, -200, 0.5, -125)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local shadow = Instance.new("UIStroke")
    shadow.Color = Color3.fromRGB(0, 0, 0)
    shadow.Thickness = 3
    shadow.Parent = frame
    
    -- Title
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    title.Text = "RuptorX Plugin Installer"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    
    -- URL Label
    urlLabel.Size = UDim2.new(1, -40, 0, 20)
    urlLabel.Position = UDim2.new(0, 20, 0, 50)
    urlLabel.BackgroundTransparency = 1
    urlLabel.Text = "Plugin URL:"
    urlLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    urlLabel.TextXAlignment = Enum.TextXAlignment.Left
    urlLabel.Font = Enum.Font.Gotham
    urlLabel.Parent = frame
    
    -- URL Box
    urlBox.Size = UDim2.new(1, -40, 0, 35)
    urlBox.Position = UDim2.new(0, 20, 0, 70)
    urlBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    urlBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    urlBox.PlaceholderText = "https://raw.githubusercontent.com/.../plugin.lua"
    urlBox.ClearTextOnFocus = false
    urlBox.Font = Enum.Font.Gotham
    urlBox.TextSize = 14
    urlBox.Parent = frame
    
    -- Name Label
    nameLabel.Size = UDim2.new(1, -40, 0, 20)
    nameLabel.Position = UDim2.new(0, 20, 0, 115)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "Plugin Name:"
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Parent = frame
    
    -- Name Box
    nameBox.Size = UDim2.new(1, -40, 0, 35)
    nameBox.Position = UDim2.new(0, 20, 0, 135)
    nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameBox.PlaceholderText = "myplugin"
    nameBox.ClearTextOnFocus = false
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextSize = 14
    nameBox.Parent = frame
    
    -- Buttons
    confirmButton.Size = UDim2.new(0.45, 0, 0, 40)
    confirmButton.Position = UDim2.new(0.025, 0, 1, -50)
    confirmButton.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    confirmButton.Text = "Install"
    confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmButton.Font = Enum.Font.GothamBold
    confirmButton.TextSize = 16
    confirmButton.Parent = frame
    
    cancelButton.Size = UDim2.new(0.45, 0, 0, 40)
    cancelButton.Position = UDim2.new(0.525, 0, 1, -50)
    cancelButton.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
    cancelButton.Text = "Cancel"
    cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelButton.Font = Enum.Font.Gotham
    cancelButton.TextSize = 16
    cancelButton.Parent = frame
    
    -- Button functions
    local function cleanup()
        screenGui:Destroy()
    end
    
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
    
    -- Enter key support
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
    
    -- Auto-focus
    task.spawn(function()
        wait(0.5)
        urlBox:CaptureFocus()
    end)
end

-- Built-in handlers (ALL ORIGINAL FEATURES)
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
            createInstallGui()
        elseif flags[1]:lower() == "overwrite" then
            Interpreter.InstallOverwrite = true
            print("INSTALL: Overwrite mode enabled for next installation")
        elseif flags[1]:lower() == "list" then
            local count = 0
            for cmd, _ in pairs(Interpreter.PluginHandlers) do
                print("Plugin: *." .. cmd)
                count = count + 1
            end
            print("Total plugins: " .. count)
        elseif flags[1]:lower() == "restart" then
            Interpreter.requestRestart()
        elseif flags[1]:lower() == "shutdown" then
            Interpreter.requestShutdown()
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

-- ALL ORIGINAL SYSTEMS (Health, Speed, Noclip, etc.)

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

-- Updated command processor
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
        -- Plugin commands are now embedded and execute directly
        if Interpreter.PluginHandlers[handlerName] then
            warn("PLUGIN: Plugin command '" .. handlerName .. "' is registered but not embedded properly")
            return false
        else
            warn("Interpreter: Handler not found: " .. handlerName)
            return false
        end
    end
end

-- Updated shutdown with lock file cleanup
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
    
    if Interpreter.IncrementThread then
        Interpreter.IncrementThread = nil
    end
    
    -- Clean up increment lock
    if delfile and isfile(Interpreter.IncrementLock) then
        pcall(delfile, Interpreter.IncrementLock)
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
local function loadEmbeddedPlugins()
    -- Plugins are now embedded in the main script and load automatically
    local count = 0
    for cmd, _ in pairs(Interpreter.PluginHandlers) do
        print("ROOTKIT: Loaded plugin - *." .. cmd)
        count = count + 1
    end
    if count > 0 then
        print("ROOTKIT: " .. count .. " plugins loaded from embedded code")
    end
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
        -- Start increment system for crash detection
        Interpreter.startIncrementSystem()
        
        -- Load embedded plugins report
        loadEmbeddedPlugins()
        
        Interpreter.ChatConnection = player.Chatted:Connect(function(message)
            if message:sub(1, 1) == "*" then
                Interpreter.processCommand(message)
            end
        end)
        
        task.wait(1)
        Interpreter.sendChatMessage("RuptorX RootKit Enabled - Complete System Active")
        
        print("RuptorX RootKit: Chat listener activated")
        print("RuptorX RootKit: Embedded plugin system ready")
        print("RuptorX RootKit: All original features available")
        print("RuptorX RootKit: Lock file system active")
    else
        warn("RuptorX RootKit: Player not found")
    end
    
    return Interpreter
end

return Interpreter

-- RUPTORX_PLUGIN_MARKER --
