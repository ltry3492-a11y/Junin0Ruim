-- Improved Remote Spy

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local RemoteSpy = Instance.new("ScreenGui")
RemoteSpy.Name = "ImprovedRemoteSpy"
RemoteSpy.ResetOnSpawn = false
RemoteSpy.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
RemoteSpy.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Draggable = true -- Roblox built-in draggable property
MainFrame.Parent = RemoteSpy

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 25)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 5, 0, 0)
TitleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 18
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Text = "Improved Remote Spy"
TitleLabel.Parent = TopBar

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 25, 1, 0)
CloseButton.Position = UDim2.new(1, -25, 0, 0)
CloseButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.TextSize = 18
CloseButton.Text = "X"
CloseButton.Parent = TopBar

CloseButton.MouseEnter:Connect(function()
    TweenService:Create(CloseButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(200, 0, 0)}):Play()
end)

CloseButton.MouseLeave:Connect(function()
    TweenService:Create(CloseButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
end)

CloseButton.MouseButton1Click:Connect(function()
    RemoteSpy:Destroy()
end)

-- Remotes List Frame
local RemotesFrame = Instance.new("Frame")
RemotesFrame.Size = UDim2.new(0.3, 0, 1, -25) -- 30% width, full height minus top bar
RemotesFrame.Position = UDim2.new(0, 0, 0, 25)
RemotesFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
RemotesFrame.BorderSizePixel = 0
RemotesFrame.Parent = MainFrame

local RemotesScrollingFrame = Instance.new("ScrollingFrame")
RemotesScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
RemotesScrollingFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
RemotesScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be updated dynamically
RemotesScrollingFrame.ScrollBarThickness = 8
RemotesScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
RemotesScrollingFrame.Parent = RemotesFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.Parent = RemotesScrollingFrame

-- Code Display Frame
local CodeDisplayFrame = Instance.new("Frame")
CodeDisplayFrame.Size = UDim2.new(0.7, 0, 1, -25) -- 70% width, full height minus top bar
CodeDisplayFrame.Position = UDim2.new(0.3, 0, 0, 25)
CodeDisplayFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
CodeDisplayFrame.BorderSizePixel = 0
CodeDisplayFrame.Parent = MainFrame

local CodeTextBox = Instance.new("TextBox")
CodeTextBox.Size = UDim2.new(1, -10, 0.7, -10)
CodeTextBox.Position = UDim2.new(0, 5, 0, 5)
CodeTextBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
CodeTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
CodeTextBox.Font = Enum.Font.Code
CodeTextBox.TextSize = 14
CodeTextBox.MultiLine = true
CodeTextBox.TextWrapped = true
CodeTextBox.TextXAlignment = Enum.TextXAlignment.Left
CodeTextBox.TextYAlignment = Enum.TextYAlignment.Top
CodeTextBox.ClearTextOnFocus = false
CodeTextBox.PlaceholderText = "Selecione um remote para ver o código."
CodeTextBox.Parent = CodeDisplayFrame

-- Action Buttons Frame
local ActionButtonsFrame = Instance.new("Frame")
ActionButtonsFrame.Size = UDim2.new(1, 0, 0.3, 0)
ActionButtonsFrame.Position = UDim2.new(0, 0, 0.7, 0)
ActionButtonsFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
ActionButtonsFrame.BorderSizePixel = 0
ActionButtonsFrame.Parent = CodeDisplayFrame

local CopyButton = Instance.new("TextButton")
CopyButton.Size = UDim2.new(0.23, 0, 0.4, 0)
CopyButton.Position = UDim2.new(0.02, 0, 0.1, 0)
CopyButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
CopyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyButton.Font = Enum.Font.SourceSansBold
CopyButton.TextSize = 16
CopyButton.Text = "Copiar Código"
CopyButton.Parent = ActionButtonsFrame

local FireButton = Instance.new("TextButton")
FireButton.Size = UDim2.new(0.23, 0, 0.4, 0)
FireButton.Position = UDim2.new(0.26, 0, 0.1, 0)
FireButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
FireButton.TextColor3 = Color3.fromRGB(255, 255, 255)
FireButton.Font = Enum.Font.SourceSansBold
FireButton.TextSize = 16
FireButton.Text = "Disparar/Invocar"
FireButton.Parent = ActionButtonsFrame

local BlacklistButton = Instance.new("TextButton")
BlacklistButton.Size = UDim2.new(0.23, 0, 0.4, 0)
BlacklistButton.Position = UDim2.new(0.50, 0, 0.1, 0)
BlacklistButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50) -- Reddish for blacklist
BlacklistButton.TextColor3 = Color3.fromRGB(255, 255, 255)
BlacklistButton.Font = Enum.Font.SourceSansBold
BlacklistButton.TextSize = 16
BlacklistButton.Text = "Blacklist"
BlacklistButton.Parent = ActionButtonsFrame

local ClearButton = Instance.new("TextButton")
ClearButton.Size = UDim2.new(0.23, 0, 0.4, 0)
ClearButton.Position = UDim2.new(0.74, 0, 0.1, 0)
ClearButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
ClearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearButton.Font = Enum.Font.SourceSansBold
ClearButton.TextSize = 16
ClearButton.Text = "Limpar Saída"
ClearButton.Parent = ActionButtonsFrame

local ClearBlacklistButton = Instance.new("TextButton")
ClearBlacklistButton.Size = UDim2.new(0.48, 0, 0.4, 0)
ClearBlacklistButton.Position = UDim2.new(0.02, 0, 0.55, 0)
ClearBlacklistButton.BackgroundColor3 = Color3.fromRGB(50, 50, 150) -- Bluish for clear blacklist
ClearBlacklistButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearBlacklistButton.Font = Enum.Font.SourceSansBold
ClearBlacklistButton.TextSize = 16
ClearBlacklistButton.Text = "Limpar Blacklist"
ClearBlacklistButton.Parent = ActionButtonsFrame

-- Global table to store spied remotes and their arguments
local SpiedRemotes = {}
local SelectedRemote = nil
local BlacklistedRemotes = {}

-- Helper function to get the full path of an instance
local function getPathToInstance(instance)
    local path = {}
    local current = instance
    while current and current ~= game do
        table.insert(path, 1, current.Name)
        current = current.Parent
    end
    return table.concat(path, ".")
end

-- Helper function to format values for display and code generation
local function formatValue(value)
    if typeof(value) == "string" then
        return string.format("%q", value)
    elseif typeof(value) == "number" then
        return tostring(value)
    elseif typeof(value) == "boolean" then
        return value and "true" or "false"
    elseif typeof(value) == "Instance" then
        return getPathToInstance(value)
    elseif typeof(value) == "table" then
        -- Simple table formatting for now, can be improved
        local formattedTable = "{"
        local first = true
        for k, v in pairs(value) do
            if not first then formattedTable = formattedTable .. ", " end
            formattedTable = formattedTable .. string.format("[%s] = %s", formatValue(k), formatValue(v))
            first = false
        end
        formattedTable = formattedTable .. "}"
        return formattedTable
    else
        return tostring(value)
    end
end

-- Function to update the code display
local function updateCodeDisplay(remoteName, args, remoteType)
    local formattedArgs = {}
    for i, arg in ipairs(args) do
        table.insert(formattedArgs, string.format("    [%d] = %s", i, formatValue(arg)))
    end
    local argsString = table.concat(formattedArgs, ",\n")

    local remotePath = SpiedRemotes[remoteName].Path
    local code = ""
    if remoteType == "RemoteEvent" then
        code = string.format("local args = {\n%s\n}\n%s:FireServer(unpack(args))", argsString, remotePath)
    elseif remoteType == "RemoteFunction" then
        code = string.format("local args = {\n%s\n}\nlocal result = %s:InvokeServer(unpack(args))\nprint(\"InvokeServer Result:\", result)", argsString, remotePath)
    end
    CodeTextBox.Text = code
    SelectedRemote = {Name = remoteName, Args = args, Type = remoteType, Path = remotePath}
end

-- Function to add a spied remote to the UI list
local function addRemoteToUI(remoteName, args, remoteType, remotePath)
    if BlacklistedRemotes[remoteName] then return end -- Do not add if blacklisted

    if SpiedRemotes[remoteName] then
        -- Update existing remote's arguments
        SpiedRemotes[remoteName].Args = args
        SpiedRemotes[remoteName].Type = remoteType
        SpiedRemotes[remoteName].Path = remotePath
        if SelectedRemote and SelectedRemote.Name == remoteName then
            updateCodeDisplay(remoteName, args, remoteType)
        end
        return
    end

    SpiedRemotes[remoteName] = {Args = args, Type = remoteType, Path = remotePath, Button = nil}

    local RemoteButton = Instance.new("TextButton")
    RemoteButton.Name = remoteName
    RemoteButton.Size = UDim2.new(1, 0, 0, 25)
    RemoteButton.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
    RemoteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RemoteButton.Font = Enum.Font.SourceSans
    RemoteButton.TextSize = 14
    RemoteButton.TextXAlignment = Enum.TextXAlignment.Left
    RemoteButton.Text = remoteName .. " (" .. remoteType .. ")"
    RemoteButton.Parent = RemotesScrollingFrame

    RemoteButton.MouseButton1Click:Connect(function()
        updateCodeDisplay(remoteName, args, remoteType)
    end)

    SpiedRemotes[remoteName].Button = RemoteButton

    -- Adjust CanvasSize
    local contentHeight = UIListLayout.AbsoluteContentSize.Y
    RemotesScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
end

-- Metatable hooking for RemoteEvent:FireServer and RemoteFunction:InvokeServer
local oldFireServer = nil
local oldInvokeServer = nil

local function hookRemotes()
    local RemoteEventMetatable = getrawmetatable(game:GetService("ReplicatedStorage").RemoteEvent)
    local RemoteFunctionMetatable = getrawmetatable(game:GetService("ReplicatedStorage").RemoteFunction)

    if not RemoteEventMetatable or not RemoteFunctionMetatable then
        warn("Could not get metatables for RemoteEvent or RemoteFunction.")
        return
    end

    oldFireServer = RemoteEventMetatable.FireServer
    RemoteEventMetatable.FireServer = newcclosure(function(self, ...)
        if not BlacklistedRemotes[self.Name] then
            local args = {...}
            addRemoteToUI(self.Name, args, "RemoteEvent", getPathToInstance(self))
        end
        return oldFireServer(self, unpack(args))
    end)

    oldInvokeServer = RemoteFunctionMetatable.InvokeServer
    RemoteFunctionMetatable.InvokeServer = newcclosure(function(self, ...)
        if not BlacklistedRemotes[self.Name] then
            local args = {...}
            addRemoteToUI(self.Name, args, "RemoteFunction", getPathToInstance(self))
        end
        return oldInvokeServer(self, unpack(args))
    end)

    warn("RemoteEvent and RemoteFunction metatables hooked.")
end

-- Initial hook attempt
-- This might need to be called after some remotes are already created, or continuously monitored.
-- For simplicity, we'll try to hook early.

-- Connect to DescendantAdded for ReplicatedStorage to catch new remotes
ReplicatedStorage.DescendantAdded:Connect(function(descendant)
    if (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) and not BlacklistedRemotes[descendant.Name] then
        -- Add to UI, but actual spying happens via metatable hook
        -- This ensures the remote name appears in the list even if not yet fired/invoked
        addRemoteToUI(descendant.Name, {}, descendant:IsA("RemoteEvent") and "RemoteEvent" or "RemoteFunction", getPathToInstance(descendant))
    end
end)

-- Populate initial remotes
for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
    if (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) and not BlacklistedRemotes[descendant.Name] then
        addRemoteToUI(descendant.Name, {}, descendant:IsA("RemoteEvent") and "RemoteEvent" or "RemoteFunction", getPathToInstance(descendant))
    end
end

-- Hook the metatables after initial setup
hookRemotes()

-- Button Actions
CopyButton.MouseButton1Click:Connect(function()
    if SelectedRemote and setclipboard then
        setclipboard(CodeTextBox.Text)
        warn("Code copied to clipboard!")
    elseif not setclipboard then
        warn("Your executor does not support clipboard functionality.")
    else
        warn("No remote selected to copy code.")
    end
end)

FireButton.MouseButton1Click:Connect(function()
    if SelectedRemote then
        local remotePath = SelectedRemote.Path
        local remoteType = SelectedRemote.Type
        local args = SelectedRemote.Args -- For now, use the spied args. Future improvement: allow editing.

        local success, err = pcall(function()
            local remote = game:FindFirstChild(remotePath:gsub("game.", ""), true)
            if remote then
                if remoteType == "RemoteEvent" then
                    remote:FireServer(unpack(args))
                    warn("RemoteEvent fired: " .. remote.Name)
                elseif remoteType == "RemoteFunction" then
                    local result = remote:InvokeServer(unpack(args))
                    warn("RemoteFunction invoked: " .. remote.Name .. ", Result: " .. tostring(result))
                end
            else
                warn("Remote instance not found: " .. remotePath)
            end
        end)

        if not success then
            warn("Error firing/invoking remote: " .. tostring(err))
        end
    else
        warn("No remote selected to fire/invoke.")
    end
end)

BlacklistButton.MouseButton1Click:Connect(function()
    if SelectedRemote then
        local remoteName = SelectedRemote.Name
        BlacklistedRemotes[remoteName] = true
        if SpiedRemotes[remoteName] and SpiedRemotes[remoteName].Button then
            SpiedRemotes[remoteName].Button:Destroy()
            SpiedRemotes[remoteName] = nil
        end
        SelectedRemote = nil
        CodeTextBox.Text = ""
        warn("Remote '" .. remoteName .. "' added to blacklist.")
        -- Adjust CanvasSize after removing button
        local contentHeight = UIListLayout.AbsoluteContentSize.Y
        RemotesScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
    else
        warn("No remote selected to blacklist.")
    end
end)

ClearBlacklistButton.MouseButton1Click:Connect(function()
    BlacklistedRemotes = {}
    warn("Blacklist cleared. Re-populating remotes...")

    -- Clear current UI list
    for _, child in ipairs(RemotesScrollingFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    SpiedRemotes = {}
    SelectedRemote = nil
    CodeTextBox.Text = ""

    -- Re-populate remotes from ReplicatedStorage (and other relevant services if needed)
    for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
        if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
            addRemoteToUI(descendant.Name, {}, descendant:IsA("RemoteEvent") and "RemoteEvent" or "RemoteFunction", getPathToInstance(descendant))
        end
    end
    -- Adjust CanvasSize after re-populating
    local contentHeight = UIListLayout.AbsoluteContentSize.Y
    RemotesScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
end)

ClearButton.MouseButton1Click:Connect(function()
    for _, child in ipairs(RemotesScrollingFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    SpiedRemotes = {}
    SelectedRemote = nil
    CodeTextBox.Text = ""
    RemotesScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    warn("Remote list cleared.")
end)

-- Initial UI setup and logic
warn("Improved Remote Spy loaded.")
