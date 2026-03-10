-- Improved Remote Spy (v3.3 - Robust Drag, Dynamic Detection, Argument Capture Fix)

-- Services
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Player & GUI
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Main GUI
local RemoteSpy = Instance.new("ScreenGui")
RemoteSpy.Name = "ImprovedRemoteSpy_v3_3"
RemoteSpy.ResetOnSpawn = false
RemoteSpy.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
RemoteSpy.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 700, 0, 450)
MainFrame.Position = UDim2.new(0.5, -350, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = Color3.fromRGB(50, 50, 55)
MainFrame.ClipsDescendants = true
MainFrame.Parent = RemoteSpy

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.fromRGB(210, 210, 215)
TitleLabel.Font = Enum.Font.SourceSansSemibold
TitleLabel.TextSize = 18
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Text = "Remote Spy v3.3"
TitleLabel.Parent = TopBar

-- UI Buttons (Minimize, Close)
local MinimizeButton = Instance.new("TextButton")
local CloseButton = Instance.new("TextButton")

for _, btn in ipairs({MinimizeButton, CloseButton}) do
    btn.BackgroundColor3 = TopBar.BackgroundColor3
    btn.TextColor3 = TitleLabel.TextColor3
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 20
    btn.Size = UDim2.new(0, 30, 1, 0)
    btn.Parent = TopBar
end

MinimizeButton.Position = UDim2.new(1, -60, 0, 0)
MinimizeButton.Text = "_"
CloseButton.Position = UDim2.new(1, -30, 0, 0)
CloseButton.Text = "X"

-- Hover Effects
local function setupButtonHover(button, normalColor, hoverColor)
    button.MouseEnter:Connect(function() TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = hoverColor}):Play() end)
    button.MouseLeave:Connect(function() TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = normalColor}):Play() end)
end

setupButtonHover(MinimizeButton, Color3.fromRGB(22, 22, 25), Color3.fromRGB(50, 50, 55))
setupButtonHover(CloseButton, Color3.fromRGB(22, 22, 25), Color3.fromRGB(200, 40, 40))

-- Minimize/Maximize Logic
local isMinimized = false
local originalSize = MainFrame.Size

MinimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 30)}):Play()
        MinimizeButton.Text = "[]"
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = originalSize}):Play()
        MinimizeButton.Text = "_"
    end
end)

CloseButton.MouseButton1Click:Connect(function() RemoteSpy:Destroy() end)

-- Robust Manual Drag System (using RenderStepped)
local dragging = false
local dragStart = Vector2.new(0, 0)
local startPos = UDim2.new(0, 0, 0, 0)
local dragRenderSteppedConnection = nil

local function updateDrag()
    local currentMousePos = UserInputService:GetMouseLocation()
    local delta = currentMousePos - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = UserInputService:GetMouseLocation()
        startPos = MainFrame.Position
        dragRenderSteppedConnection = RunService.RenderStepped:Connect(updateDrag)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and dragging then
        dragging = false
        if dragRenderSteppedConnection then
            dragRenderSteppedConnection:Disconnect()
            dragRenderSteppedConnection = nil
        end
    end
end)

-- Content Frames
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -30)
ContentFrame.Position = UDim2.new(0, 0, 0, 30)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local RemotesFrame = Instance.new("ScrollingFrame")
RemotesFrame.Size = UDim2.new(0.35, 0, 1, 0)
RemotesFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
RemotesFrame.BorderSizePixel = 0
RemotesFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
RemotesFrame.ScrollBarThickness = 6
RemotesFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
RemotesFrame.Parent = ContentFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 3)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = RemotesFrame

local CodeDisplayFrame = Instance.new("Frame")
CodeDisplayFrame.Size = UDim2.new(0.65, 0, 1, 0)
CodeDisplayFrame.Position = UDim2.new(0.35, 0, 0, 0)
CodeDisplayFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
CodeDisplayFrame.BorderSizePixel = 0
CodeDisplayFrame.Parent = ContentFrame

local CodeTextBox = Instance.new("TextBox")
CodeTextBox.Size = UDim2.new(1, -10, 1, -140)
CodeTextBox.Position = UDim2.new(0, 5, 0, 5)
CodeTextBox.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
CodeTextBox.TextColor3 = Color3.fromRGB(220, 220, 225)
CodeTextBox.Font = Enum.Font.Code
CodeTextBox.TextSize = 14
CodeTextBox.MultiLine = true
CodeTextBox.TextWrapped = true
CodeTextBox.TextXAlignment = Enum.TextXAlignment.Left
CodeTextBox.TextYAlignment = Enum.TextYAlignment.Top
CodeTextBox.ClearTextOnFocus = false
CodeTextBox.PlaceholderText = "Aguardando detecção de remotes..."
CodeTextBox.Parent = CodeDisplayFrame

-- Action Buttons (Layout corrigido)
local ActionButtonsFrame = Instance.new("Frame")
ActionButtonsFrame.Size = UDim2.new(1, -10, 0, 120)
ActionButtonsFrame.Position = UDim2.new(0, 5, 1, -125)
ActionButtonsFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
ActionButtonsFrame.BorderSizePixel = 0
ActionButtonsFrame.Parent = CodeDisplayFrame

-- Layout dos botões em grid
local ButtonGrid = Instance.new("UIGridLayout")
ButtonGrid.FillDirection = Enum.FillDirection.Horizontal
ButtonGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
ButtonGrid.VerticalAlignment = Enum.VerticalAlignment.Center
ButtonGrid.CellSize = UDim2.new(0, 130, 0, 35)
ButtonGrid.CellPadding = UDim2.new(0, 8, 0, 8)
ButtonGrid.FillDirectionMaxCells = 3
ButtonGrid.Parent = ActionButtonsFrame

-- Criar botões com tamanhos uniformes
local CopyButton = Instance.new("TextButton")
local FireButton = Instance.new("TextButton")
local BlacklistButton = Instance.new("TextButton")
local ClearButton = Instance.new("TextButton")
local ClearBlacklistButton = Instance.new("TextButton")

local buttons = {CopyButton, FireButton, BlacklistButton, ClearButton, ClearBlacklistButton}
for _, btn in ipairs(buttons) do
    btn.TextColor3 = Color3.fromRGB(230, 230, 235)
    btn.Font = Enum.Font.SourceSansSemibold
    btn.TextSize = 14
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = ActionButtonsFrame
end

CopyButton.Text = "Copiar"
CopyButton.BackgroundColor3 = Color3.fromRGB(80, 100, 160)

FireButton.Text = "Disparar"
FireButton.BackgroundColor3 = Color3.fromRGB(80, 140, 100)

BlacklistButton.Text = "Blacklist"
BlacklistButton.BackgroundColor3 = Color3.fromRGB(160, 60, 60)

ClearButton.Text = "Limpar"
ClearButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)

ClearBlacklistButton.Text = "Limpar Blacklist"
ClearBlacklistButton.BackgroundColor3 = Color3.fromRGB(60, 60, 120)

-- Hover Effects
setupButtonHover(CopyButton, Color3.fromRGB(80, 100, 160), Color3.fromRGB(100, 120, 180))
setupButtonHover(FireButton, Color3.fromRGB(80, 140, 100), Color3.fromRGB(100, 160, 120))
setupButtonHover(BlacklistButton, Color3.fromRGB(160, 60, 60), Color3.fromRGB(180, 80, 80))
setupButtonHover(ClearButton, Color3.fromRGB(100, 100, 100), Color3.fromRGB(120, 120, 120))
setupButtonHover(ClearBlacklistButton, Color3.fromRGB(60, 60, 120), Color3.fromRGB(80, 80, 140))

-- Core Logic
local SpiedRemotes = {}
local SelectedRemote = nil
local BlacklistedRemotes = {}

local function getPathToInstance(instance)
    local path = {}
    local current = instance
    while current and current ~= game do
        table.insert(path, 1, current.Name)
        current = current.Parent
    end
    return "game." .. table.concat(path, ".")
end

local function formatValue(value, indentLevel)
    indentLevel = indentLevel or 1
    local indent = string.rep("  ", indentLevel)

    if typeof(value) == "string" then
        return string.format("%q", value)
    elseif typeof(value) == "number" or typeof(value) == "boolean" then
        return tostring(value)
    elseif typeof(value) == "Instance" then
        return getPathToInstance(value)
    elseif typeof(value) == "table" then
        -- Handle tables recursively for better formatting
        local str = "{\n"
        for k, v in pairs(value) do
            str = str .. indent .. "  " .. string.format("[%s] = %s,\n", formatValue(k, indentLevel + 1), formatValue(v, indentLevel + 1))
        end
        return str .. indent .. "}"
    else
        return tostring(value)
    end
end

local function updateCodeDisplay(remoteData)
    local formattedArgs = {}
    for i, arg in ipairs(remoteData.Args) do
        table.insert(formattedArgs, string.format("  [%d] = %s", i, formatValue(arg)))
    end
    local argsString = table.concat(formattedArgs, ",\n")

    local code
    if remoteData.Type == "RemoteEvent" then
        code = string.format("local args = {\n%s\n}\n%s:FireServer(unpack(args))", argsString, remoteData.Path)
    else
        code = string.format("local args = {\n%s\n}\nlocal result = %s:InvokeServer(unpack(args))\nprint(\"Result:\", result)", argsString, remoteData.Path)
    end
    CodeTextBox.Text = code
    SelectedRemote = remoteData
end

local function addRemoteToUI(remoteName, args, remoteType, remotePath)
    if BlacklistedRemotes[remoteName] then return end

    local remoteData = SpiedRemotes[remoteName]
    if remoteData then
        -- Update existing remote's arguments if it's already in the list
        remoteData.Args = args
        if SelectedRemote and SelectedRemote.Name == remoteName then
            updateCodeDisplay(remoteData)
        end
        return
    end

    remoteData = {Name = remoteName, Args = args, Type = remoteType, Path = remotePath}
    SpiedRemotes[remoteName] = remoteData

    local RemoteButton = Instance.new("TextButton")
    RemoteButton.Name = remoteName
    RemoteButton.Size = UDim2.new(1, -6, 0, 25)
    RemoteButton.Position = UDim2.new(0, 3, 0, 0)
    RemoteButton.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    RemoteButton.TextColor3 = Color3.fromRGB(200, 200, 205)
    RemoteButton.Font = Enum.Font.SourceSans
    RemoteButton.TextSize = 14
    RemoteButton.TextXAlignment = Enum.TextXAlignment.Left
    RemoteButton.Text = "  " .. remoteName .. " (" .. remoteType .. ")"
    RemoteButton.Parent = RemotesFrame
    setupButtonHover(RemoteButton, RemoteButton.BackgroundColor3, Color3.fromRGB(65, 65, 70))

    remoteData.Button = RemoteButton

    RemoteButton.MouseButton1Click:Connect(function()
        updateCodeDisplay(remoteData)
    end)

    RemotesFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
end

-- The __namecall Hook
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- Only process if it's a FireServer or InvokeServer call and not from the executor itself
    if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
        local remoteType = (method == "FireServer") and "RemoteEvent" or "RemoteFunction"
        if not BlacklistedRemotes[self.Name] then
            -- Use task.spawn to avoid any potential yield issues with the game's thread
            -- This ensures the UI update doesn't block the game's remote call
            task.spawn(addRemoteToUI, self.Name, args, remoteType, getPathToInstance(self))
        end
    end
    return oldNamecall(self, ...)
end)

warn("Remote Spy v3.3: Hooked and ready. List will populate as remotes are called.")

-- Button Actions Logic
CopyButton.MouseButton1Click:Connect(function()
    if SelectedRemote then
        if setclipboard then
            setclipboard(CodeTextBox.Text)
            warn("Code copied to clipboard!")
        else
            warn("Seu executor não suporta a função de clipboard. Copie manualmente o código: " .. CodeTextBox.Text)
        end
    else
        warn("Nenhum remote selecionado para copiar o código.")
    end
end)

FireButton.MouseButton1Click:Connect(function()
    if SelectedRemote then
        local remote = game:FindFirstChild(SelectedRemote.Path:gsub("game.", ""), true)
        if remote then
            if SelectedRemote.Type == "RemoteEvent" then
                remote:FireServer(unpack(SelectedRemote.Args))
                warn("RemoteEvent disparado: " .. SelectedRemote.Name)
            else
                local result = remote:InvokeServer(unpack(SelectedRemote.Args))
                warn("RemoteFunction invocado: " .. SelectedRemote.Name .. ", Resultado: " .. tostring(result))
            end
        else
            warn("Instância do remote não encontrada: " .. SelectedRemote.Path)
        end
    else
        warn("Nenhum remote selecionado para disparar/invocar.")
    end
end)

BlacklistButton.MouseButton1Click:Connect(function()
    if SelectedRemote then
        local remoteName = SelectedRemote.Name
        BlacklistedRemotes[remoteName] = true
        if SpiedRemotes[remoteName] then
            SpiedRemotes[remoteName].Button:Destroy()
            SpiedRemotes[remoteName] = nil
        end
        SelectedRemote = nil
        CodeTextBox.Text = ""
        RemotesFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
        warn("Remote \'" .. remoteName .. "\' adicionado à blacklist.")
    else
        warn("Nenhum remote selecionado para adicionar à blacklist.")
    end
end)

ClearButton.MouseButton1Click:Connect(function()
    for _, data in pairs(SpiedRemotes) do
        if data.Button then data.Button:Destroy() end
    end
    SpiedRemotes = {}
    SelectedRemote = nil
    CodeTextBox.Text = ""
    RemotesFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    warn("Lista de remotes limpa.")
end)

ClearBlacklistButton.MouseButton1Click:Connect(function()
    BlacklistedRemotes = {}
    warn("Blacklist limpa. Todos os remotes serão detectados novamente ao serem chamados.")
end)
