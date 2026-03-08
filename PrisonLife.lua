local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local backpack = LocalPlayer:WaitForChild("Backpack")

-- Configurações
local Settings = {
    Enabled = true,
    TeamCheck = true,
    WallCheck = true,
    DeathCheck = true,
    ForceFieldCheck = true,
    HitChance = 75,
    MissSpread = 5,
    FOV = 150,
    AimPart = "Head",
    RandomAimParts = false,
    AimPartsList = {"Head", "Torso", "HumanoidRootPart", "LeftArm", "RightArm", "LeftLeg", "RightLeg"},
    ToggleKey = Enum.KeyCode.RightShift,
    ShowFOV = true,
    ShowTargetLine = false,
    ESPEnabled = false,
    ESPFillerTransparency = 0.75,
    ESPOutlineColor = Color3.fromRGB(255, 255, 255),
    ESPDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    RapidFireEnabled = false,
    FastReloadEnabled = false,
    NoClipEnabled = false,
    InvisibilityEnabled = false,
    AutoArrestEnabled = false,
    AntiTaserEnabled = false,
}

local IsMobile = UserInputService.TouchEnabled or UserInputService.GamepadEnabled

local UISettings = {
    Visible = true,
    ToggleUIKey = Enum.KeyCode.Insert,
    CurrentTab = "Main"
}

-- ==================== FUNÇÃO DE TOGGLE DA UI (CORRIGIDA) ====================
local UIComponents = { MainFrame = nil, TabButtons = {}, TabContents = {}, CloseButton = nil, ScreenGui = nil }

local function ToggleUI()
    UISettings.Visible = not UISettings.Visible
    if UIComponents and UIComponents.MainFrame then
        UIComponents.MainFrame.Visible = UISettings.Visible
    end
    if IsMobile and UIComponents and UIComponents.ScreenGui and UIComponents.ScreenGui:FindFirstChild("ToggleUIButton") then
        UIComponents.ScreenGui.ToggleUIButton.Visible = not UISettings.Visible
    end
    -- Garantir que o botão de toggle esteja visível se a UI principal estiver oculta no mobile
    if IsMobile and not UISettings.Visible and UIComponents and UIComponents.ScreenGui and UIComponents.ScreenGui:FindFirstChild("ToggleUIButton") then
        UIComponents.ScreenGui.ToggleUIButton.Visible = true
    end
    Notify("UI", UISettings.Visible and "Mostrada" or "Escondida")
end

-- Coordenadas das armas
local WeaponCoordinates = {
    AK47 = Vector3.new(-931.6133422851562, 94.30853271484375, 2039.3065185546875),
    Shotgun = Vector3.new(-939.02734375, 94.30851745605469, 2039.1881103515625),
    MP5 = Vector3.new(813.7302856445312, 100.79533386230469, 2229.611572265625),
    Sniper = Vector3.new(836.1853637695312, 100.73533630371094, 2229.324951171875),
    M4A1 = Vector3.new(847.6981201171875, 100.79533386230469, 2229.6552734375)
}

-- Variável para salvar posição
local SavedPosition = nil
local SavedCFrame = nil

-- Função auxiliar de notificação
local function Notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3,
        })
    end)
end

-- ==================== FUNÇÕES DE SERIALIZAÇÃO ====================
local function SerializeSettings()
    local serializableSettings = {}
    for k, v in pairs(Settings) do
        if typeof(v) == "Color3" then
            serializableSettings[k] = {R = v.R, G = v.G, B = v.B, Type = "Color3"}
        elseif typeof(v) == "EnumItem" then
            serializableSettings[k] = {Name = v.Name, Type = "EnumItem", EnumType = v.EnumType.Name}
        else
            serializableSettings[k] = v
        end
    end
    return HttpService:JSONEncode(serializableSettings)
end

local function DeserializeSettings(jsonString)
    local success, data = pcall(HttpService.JSONDecode, HttpService, jsonString)
    if not success or not data then return nil end

    local loadedSettings = {}
    for k, v in pairs(data) do
        if type(v) == "table" and v.Type == "Color3" then
            loadedSettings[k] = Color3.new(v.R, v.G, v.B)
        elseif type(v) == "table" and v.Type == "EnumItem" then
            local enumType = Enum[v.EnumType]
            if enumType then
                loadedSettings[k] = enumType[v.Name]
            end
        else
            loadedSettings[k] = v
        end
    end
    return loadedSettings
end

local function SaveSettings()
    local jsonString = SerializeSettings()
    pcall(setclipboard, jsonString)
    Notify("Configurações Salvas", "As configurações foram copiadas para a área de transferência.")
end

local function LoadSettings()
    local success, jsonString = pcall(getclipboard)
    if not success or type(jsonString) ~= "string" or #jsonString < 10 then
        return
    end

    local loadedSettings = DeserializeSettings(jsonString)
    if not loadedSettings then
        Notify("Erro ao Carregar", "Falha ao decodificar as configurações.")
        return
    end

    for k, v in pairs(loadedSettings) do
        if Settings[k] ~= nil then
            Settings[k] = v
        end
    end

    InitializeUI()
    Notify("Configurações Carregadas", "As configurações foram carregadas com sucesso.")
end

-- ==================== ANTI-TASER ====================
local GunRemotes = ReplicatedStorage:WaitForChild("GunRemotes", 10)
local ShootEvent = GunRemotes and GunRemotes:WaitForChild("ShootEvent", 10)
if not ShootEvent then return end

local PlayerTased = ReplicatedStorage:FindFirstChild("GunRemotes") and ReplicatedStorage.GunRemotes:FindFirstChild("PlayerTased")
local OriginalPlayerTased = PlayerTased

local function ToggleAntiTaser(enabled)
    Settings.AntiTaserEnabled = enabled
    if enabled and OriginalPlayerTased and OriginalPlayerTased.Parent then
        local FakePlayerTased = OriginalPlayerTased:Clone()
        FakePlayerTased.Name = OriginalPlayerTased.Name
        FakePlayerTased.Parent = OriginalPlayerTased.Parent
        OriginalPlayerTased:Destroy()
        PlayerTased = FakePlayerTased
    end
end

if Settings.AntiTaserEnabled and OriginalPlayerTased then
    ToggleAntiTaser(true)
end

-- ==================== PARÂMETROS DE WALLCHECK ====================
local WallCheckParams = RaycastParams.new()
WallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
WallCheckParams.IgnoreWater = true
WallCheckParams.RespectCanCollide = false

-- ==================== VARIÁVEIS GLOBAIS ====================
local Visuals = { Gui = nil, Circle = nil, Line = nil }
local IsShooting = false
local LastShot = 0
local CurrentTarget = nil
local LastTargetUpdate = 0
local TARGET_UPDATE_INTERVAL = 0.05

local ESPHighlights = {}
local ESPConnections = {}

local OriginalFireRate = {}
local OriginalReloadTime = {}
local OriginalAutoFire = {}
local RapidFireWatchers = {}
local FastReloadWatchers = {}

-- ==================== MAPEAMENTO DE NOMES DE TECLAS ====================
local KeybindNames = {
    [Enum.KeyCode.Insert] = "INSERT",
    [Enum.KeyCode.Delete] = "DELETE",
    [Enum.KeyCode.Home] = "HOME",
    [Enum.KeyCode.End] = "END",
    [Enum.KeyCode.PageUp] = "PAGE UP",
    [Enum.KeyCode.PageDown] = "PAGE DOWN",
    [Enum.KeyCode.RightShift] = "RIGHT SHIFT",
    [Enum.KeyCode.LeftShift] = "LEFT SHIFT",
    [Enum.KeyCode.RightControl] = "RIGHT CTRL",
    [Enum.KeyCode.LeftControl] = "LEFT CTRL",
    [Enum.KeyCode.RightAlt] = "RIGHT ALT",
    [Enum.KeyCode.LeftAlt] = "LEFT ALT",
    [Enum.KeyCode.Tab] = "TAB",
    [Enum.KeyCode.CapsLock] = "CAPS LOCK",
    [Enum.KeyCode.F1] = "F1",
    [Enum.KeyCode.F2] = "F2",
    [Enum.KeyCode.F3] = "F3",
    [Enum.KeyCode.F4] = "F4",
    [Enum.KeyCode.F5] = "F5",
    [Enum.KeyCode.F6] = "F6",
    [Enum.KeyCode.F7] = "F7",
    [Enum.KeyCode.F8] = "F8",
    [Enum.KeyCode.F9] = "F9",
    [Enum.KeyCode.F10] = "F10",
    [Enum.KeyCode.F11] = "F11",
    [Enum.KeyCode.F12] = "F12",
}

local function GetKeyName(keyCode)
    return KeybindNames[keyCode] or keyCode.Name:upper()
end

-- ==================== LIMPEZA DE UI ANTIGA ====================
local function CleanupExistingUI()
    local existingCoreGui = CoreGui:FindFirstChild("JGSilentAimUI")
    if existingCoreGui then existingCoreGui:Destroy() end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local existingPlayerGui = playerGui:FindFirstChild("JGSilentAimUI")
        if existingPlayerGui then existingPlayerGui:Destroy() end
    end
end

-- ==================== CRIAÇÃO DA UI MODERNA ====================
local function CreateModernUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "JGSilentAimUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    if IsMobile then
        UISettings.Visible = false -- Esconder a UI principal no mobile inicialmente

        local toggleButton = Instance.new("TextButton")
        toggleButton.Name = "ToggleUIButton"
        toggleButton.Size = UDim2.new(0, 80, 0, 30)
        toggleButton.Position = UDim2.new(1, -110, 0, 10)
        toggleButton.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleButton.Text = "Toggle UI"
        toggleButton.Font = Enum.Font.Gotham
        toggleButton.TextSize = 12
        toggleButton.Parent = sg
        toggleButton.ZIndex = 100
        toggleButton.Visible = true

        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 40)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25))
        })
        gradient.Rotation = 90
        gradient.Parent = toggleButton

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(120, 120, 255)
        stroke.Thickness = 1
        stroke.Transparency = 0.3
        stroke.Parent = toggleButton

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = toggleButton

        toggleButton.MouseButton1Click:Connect(ToggleUI)
        UIComponents.ScreenGui = sg
    end

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    mainFrame.BorderColor3 = Color3.fromRGB(100, 100, 150)
    mainFrame.BorderSizePixel = 1
    mainFrame.Parent = sg
    mainFrame.Visible = UISettings.Visible
    UIComponents.MainFrame = mainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    titleBar.Parent = mainFrame

    local titleText = Instance.new("TextLabel")
    titleText.Name = "TitleText"
    titleText.Size = UDim2.new(1, -40, 1, 0)
    titleText.Position = UDim2.new(0, 0, 0, 0)
    titleText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    titleText.BackgroundTransparency = 1
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.Text = "JGSilentAim"
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 18
    titleText.TextWrapped = true
    titleText.TextXAlignment = Enum.TextXAlignment.Center
    titleText.TextYAlignment = Enum.TextYAlignment.Center
    titleText.Parent = titleBar

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 1, 0)
    closeButton.Position = UDim2.new(1, -30, 0, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Text = "X"
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 18
    closeButton.Parent = titleBar
    closeButton.MouseButton1Click:Connect(ToggleUI)
    UIComponents.CloseButton = closeButton

    local tabFrame = Instance.new("Frame")
    tabFrame.Name = "TabFrame"
    tabFrame.Size = UDim2.new(1, -20, 0, 30)
    tabFrame.Position = UDim2.new(0, 10, 0, 40)
    tabFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    tabFrame.Parent = mainFrame

    local tabListLayout = Instance.new("UIListLayout")
    tabListLayout.FillDirection = Enum.FillDirection.Horizontal
    tabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabListLayout.Padding = UDim.new(0, 5)
    tabListLayout.Parent = tabFrame

    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -80)
    contentFrame.Position = UDim2.new(0, 10, 0, 75)
    contentFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    contentFrame.Parent = mainFrame

    local contentListLayout = Instance.new("UIListLayout")
    contentListLayout.FillDirection = Enum.FillDirection.Vertical
    contentListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    contentListLayout.Padding = UDim.new(0, 5)
    contentListLayout.Parent = contentFrame

    local function CreateTab(name)
        local tabButton = Instance.new("TextButton")
        tabButton.Name = name .. "Tab"
        tabButton.Size = UDim2.new(0, 60, 1, 0)
        tabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabButton.Text = name
        tabButton.Font = Enum.Font.Gotham
        tabButton.TextSize = 14
        tabButton.Parent = tabFrame
        UIComponents.TabButtons[name] = tabButton

        local tabContent = Instance.new("Frame")
        tabContent.Name = name .. "Content"
        tabContent.Size = UDim2.new(1, 0, 1, 0)
        tabContent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        tabContent.BackgroundTransparency = 1
        tabContent.Parent = contentFrame
        tabContent.Visible = false
        UIComponents.TabContents[name] = tabContent

        local contentListLayout = Instance.new("UIListLayout")
        contentListLayout.FillDirection = Enum.FillDirection.Vertical
        contentListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        contentListLayout.Padding = UDim.new(0, 5)
        contentListLayout.Parent = tabContent

        tabButton.MouseButton1Click:Connect(function()
            for _, btn in pairs(UIComponents.TabButtons) do
                btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
            end
            for _, cont in pairs(UIComponents.TabContents) do
                cont.Visible = false
            end
            tabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
            tabContent.Visible = true
            UISettings.CurrentTab = name
        end)
    end

    CreateTab("Main")
    CreateTab("Weapon")
    CreateTab("Player")
    CreateTab("Teleport")
    CreateTab("Settings")

    -- Selecionar a aba inicial
    if UIComponents.TabButtons[UISettings.CurrentTab] then
        UIComponents.TabButtons[UISettings.CurrentTab].MouseButton1Click:Fire()
    else
        UIComponents.TabButtons["Main"].MouseButton1Click:Fire()
    end

    sg.Parent = CoreGui -- Anexar ao CoreGui para persistência
end

local function CreateToggle(parent, text, initialValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 30, 0, 20)
    toggleButton.Position = UDim2.new(1, -35, 0.5, -10)
    toggleButton.BackgroundColor3 = initialValue and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Text = initialValue and "ON" or "OFF"
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 14
    toggleButton.Parent = frame

    local currentValue = initialValue

    toggleButton.MouseButton1Click:Connect(function()
        currentValue = not currentValue
        toggleButton.BackgroundColor3 = currentValue and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
        toggleButton.Text = currentValue and "ON" or "OFF"
        callback(currentValue)
        Notify(text, currentValue and "Ativado" or "Desativado")
    end)
end

local function CreateSlider(parent, text, initialValue, minValue, maxValue, step, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = text .. ": " .. tostring(initialValue)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local slider = Instance.new("Slider")
    slider.Size = UDim2.new(1, -10, 0, 10)
    slider.Position = UDim2.new(0, 5, 0, 25)
    slider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    slider.BorderColor3 = Color3.fromRGB(100, 100, 150)
    slider.Value = (initialValue - minValue) / (maxValue - minValue)
    slider.Parent = frame

    slider.Changed:Connect(function()
        local newValue = math.floor(minValue + slider.Value * (maxValue - minValue))
        label.Text = text .. ": " .. tostring(newValue)
        callback(newValue)
    end)
end

local function CreateButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 30)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = text
    button.Font = Enum.Font.Gotham
    button.TextSize = 14
    button.Parent = parent

    button.MouseButton1Click:Connect(function()
        callback()
        Notify("Ação", text .. " executada.")
    end)
end

local function CreateKeybindSelector(parent, text, initialKey, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local keyButton = Instance.new("TextButton")
    keyButton.Size = UDim2.new(0, 70, 0, 20)
    keyButton.Position = UDim2.new(1, -75, 0.5, -10)
    keyButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    keyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyButton.Text = GetKeyName(initialKey)
    keyButton.Font = Enum.Font.GothamBold
    keyButton.TextSize = 14
    keyButton.Parent = frame

    local waitingForKey = false

    keyButton.MouseButton1Click:Connect(function()
        if waitingForKey then return end
        waitingForKey = true
        keyButton.Text = "Aguardando..."
        Notify("Keybind", "Pressione uma tecla para definir o atalho.")

        local inputBeganConn
        inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
            if gameProcessedEvent then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                callback(input.KeyCode)
                keyButton.Text = GetKeyName(input.KeyCode)
                waitingForKey = false
                inputBeganConn:Disconnect()
                Notify("Keybind", text .. " definido para " .. GetKeyName(input.KeyCode) .. ".")
            end
        end)
    end)
end

local function InitializeUI()
    CleanupExistingUI()
    CreateModernUI()
end

-- ==================== AIMBOT ====================
local function GetClosestPlayer(fov)
    local closestPlayer = nil
    local shortestDistance = fov
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local charHRP = character.HumanoidRootPart

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            if Settings.TeamCheck and player.Team == LocalPlayer.Team then continue end

            local targetHRP = player.Character.HumanoidRootPart
            local distance = (charHRP.Position - targetHRP.Position).Magnitude

            local screenPoint, onScreen = workspace.CurrentCamera:WorldToScreenPoint(targetHRP.Position)
            if onScreen then
                local viewportSize = workspace.CurrentCamera.ViewportSize
                local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
                local distanceToCenter = (Vector2.new(screenPoint.X, screenPoint.Y) - center).Magnitude

                if distanceToCenter < shortestDistance then
                    shortestDistance = distanceToCenter
                    closestPlayer = player
                end
            end
        end
    end
    return closestPlayer
end

local function GetTargetPart(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return nil end
    local targetChar = targetPlayer.Character

    if Settings.RandomAimParts then
        local availableParts = {}
        for _, partName in ipairs(Settings.AimPartsList) do
            local part = targetChar:FindFirstChild(partName)
            if part then
                table.insert(availableParts, part)
            end
        end
        if #availableParts > 0 then
            return availableParts[math.random(1, #availableParts)]
        end
    else
        return targetChar:FindFirstChild(Settings.AimPart)
    end
    return nil
end

local function IsTargetVisible(targetPart, charHRP)
    if not targetPart or not charHRP then return false end
    local raycastResult = workspace:Raycast(charHRP.Position, (targetPart.Position - charHRP.Position).Unit * (charHRP.Position - targetPart.Position).Magnitude, WallCheckParams)
    return not raycastResult or raycastResult.Instance == targetPart or targetPart:IsDescendantOf(raycastResult.Instance)
end

local function AimAtTarget(targetPart)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local charHRP = character.HumanoidRootPart

    local camera = workspace.CurrentCamera
    if not camera then return end

    local targetPosition = targetPart.Position
    local direction = (targetPosition - camera.CFrame.Position).Unit
    local newCFrame = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + direction)

    camera.CFrame = newCFrame
end

local function UpdateAimbot()
    if not Settings.Enabled then
        CurrentTarget = nil
        return
    end

    local currentTime = tick()
    if currentTime - LastTargetUpdate > TARGET_UPDATE_INTERVAL then
        CurrentTarget = GetClosestPlayer(Settings.FOV)
        LastTargetUpdate = currentTime
    end

    if CurrentTarget then
        local targetPart = GetTargetPart(CurrentTarget)
        if targetPart and IsTargetVisible(targetPart, LocalPlayer.Character.HumanoidRootPart) then
            AimAtTarget(targetPart)
        else
            CurrentTarget = nil
        end
    end
end

RunService.RenderStepped:Connect(UpdateAimbot)

-- ==================== RAPID FIRE ====================
local function applyRapidFireToTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    local remote = tool:FindFirstChildOfClass("RemoteFunction") or tool:FindFirstChildOfClass("RemoteEvent")
    if not remote then return end

    if not OriginalFireRate[tool.Name] then
        OriginalFireRate[tool.Name] = tool:GetAttribute("FireRate") or 0.1 -- Default if not found
    end

    if Settings.RapidFireEnabled then
        tool:SetAttribute("FireRate", 0.01) -- Muito rápido
    else
        tool:SetAttribute("FireRate", OriginalFireRate[tool.Name])
    end
end

local function ToggleRapidFire(enabled)
    Settings.RapidFireEnabled = enabled
    local char = LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            applyRapidFireToTool(child)
        end
    end
    for _, tool in ipairs(backpack:GetChildren()) do
        applyRapidFireToTool(tool)
    end
end

local function scanRapidFire(char)
    if not char then return end
    if RapidFireWatchers[char] then return end

    RapidFireWatchers[char] = char.ChildAdded:Connect(function(child)
        task.wait(0.1)
        applyRapidFireToTool(child)
    end)
    for _, child in ipairs(char:GetChildren()) do
        applyRapidFireToTool(child)
    end
end

-- ==================== FAST RELOAD ====================
local function applyFastReloadToTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    local remote = tool:FindFirstChildOfClass("RemoteFunction") or tool:FindFirstChildOfClass("RemoteEvent")
    if not remote then return end

    if not OriginalReloadTime[tool.Name] then
        OriginalReloadTime[tool.Name] = tool:GetAttribute("ReloadTime") or 1 -- Default if not found
    end

    if Settings.FastReloadEnabled then
        tool:SetAttribute("ReloadTime", 0.01) -- Muito rápido
    else
        tool:SetAttribute("ReloadTime", OriginalReloadTime[tool.Name])
    end
end

local function ToggleFastReload(enabled)
    Settings.FastReloadEnabled = enabled
    local char = LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            applyFastReloadToTool(child)
        end
    end
    for _, tool in ipairs(backpack:GetChildren()) do
        applyFastReloadToTool(tool)
    end
end

local function scanFastReload(char)
    if not char then return end
    if FastReloadWatchers[char] then return end

    FastReloadWatchers[char] = char.ChildAdded:Connect(function(child)
        task.wait(0.1)
        applyFastReloadToTool(child)
    end)
    for _, child in ipairs(char:GetChildren()) do
        applyFastReloadToTool(child)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    for _, child in ipairs(char:GetChildren()) do
        task.wait(0.1)
        applyRapidFireToTool(child)
        applyFastReloadToTool(child)
    end
    scanRapidFire(char)
    scanFastReload(char)
end)

-- ==================== NOCLIP ====================
local NoClipConnection
local NoClipOriginalCollision = {}
local function SetNoClip(enabled)
    Settings.NoClipEnabled = enabled
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if enabled then
        -- Desconectar a conexão anterior se existir
        if NoClipConnection and NoClipConnection.Connected then
            NoClipConnection:Disconnect()
        end

        -- Armazenar o estado original de CanCollide e desativar colisões
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                NoClipOriginalCollision[part] = part.CanCollide
                part.CanCollide = false
            end
        end
        -- Garantir que o HumanoidRootPart também tenha a colisão desativada
        if char.HumanoidRootPart then
            NoClipOriginalCollision[char.HumanoidRootPart] = char.HumanoidRootPart.CanCollide
            char.HumanoidRootPart.CanCollide = false
        end

        -- Desativar gravidade e colisões do Humanoid para evitar interações indesejadas
        humanoid.PlatformStand = true
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0

        -- Conectar a um loop para manter as colisões desativadas (pode ser necessário para anti-cheats)
        NoClipConnection = RunService.Stepped:Connect(function()
            if not Settings.NoClipEnabled or not LocalPlayer.Character then
                -- Se o noclip for desativado ou o personagem não existir, desconectar
                if NoClipConnection and NoClipConnection.Connected then
                    NoClipConnection:Disconnect()
                end
                return
            end
            local currentCharacter = LocalPlayer.Character
            for _, part in ipairs(currentCharacter:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
            if currentCharacter.HumanoidRootPart and currentCharacter.HumanoidRootPart.CanCollide then
                currentCharacter.HumanoidRootPart.CanCollide = false
            end
            -- Manter o PlatformStand e velocidades zeradas
            if humanoid.PlatformStand == false then humanoid.PlatformStand = true end
            if humanoid.WalkSpeed ~= 0 then humanoid.WalkSpeed = 0 end
            if humanoid.JumpPower ~= 0 then humanoid.JumpPower = 0 end
        end)

        Notify("Noclip", "Ativado. Você pode atravessar paredes.")
    else
        -- Restaurar colisões originais
        for part, originalState in pairs(NoClipOriginalCollision) do
            if part and part.Parent then -- Verificar se a parte ainda existe
                part.CanCollide = originalState
            end
        end
        table.clear(NoClipOriginalCollision)

        -- Restaurar estado original do Humanoid
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 16 -- Valor padrão do Roblox
        humanoid.JumpPower = 50 -- Valor padrão do Roblox

        if NoClipConnection and NoClipConnection.Connected then
            NoClipConnection:Disconnect()
        end
        Notify("Noclip", "Desativado.")
    end
end

-- ==================== INVISIBILIDADE ====================
local InvisibilityOriginalPosition = nil
local InvisibilityOriginalWalkSpeed = nil
local InvisibilityOriginalJumpPower = nil
local InvisibilityOriginalPlatformStand = nil

local function SetInvisibility(enabled)
    Settings.InvisibilityEnabled = enabled
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if enabled then
        -- Salvar estado original
        InvisibilityOriginalPosition = hrp.CFrame
        InvisibilityOriginalWalkSpeed = humanoid.WalkSpeed
        InvisibilityOriginalJumpPower = humanoid.JumpPower
        InvisibilityOriginalPlatformStand = humanoid.PlatformStand

        -- Mover o personagem para baixo do mapa
        hrp.CFrame = hrp.CFrame * CFrame.new(0, -1000, 0) -- Move 1000 studs para baixo

        -- Desativar movimento e colisões para evitar que o personagem volte ou interaja
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.PlatformStand = true -- Impede que o personagem caia ou seja afetado pela gravidade

        -- Manter o nome visível (geralmente é o padrão, mas podemos garantir)
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
        humanoid.NameDisplayDistance = 1000 -- Distância alta para garantir visibilidade
        humanoid.HealthDisplayDistance = 1000 -- Distância alta para garantir visibilidade

        Notify("Invisibilidade", "Ativada. Seu corpo está abaixo do mapa.")
    else
        -- Restaurar estado original
        if InvisibilityOriginalPosition then
            hrp.CFrame = InvisibilityOriginalPosition
        end
        if InvisibilityOriginalWalkSpeed then
            humanoid.WalkSpeed = InvisibilityOriginalWalkSpeed
        else
            humanoid.WalkSpeed = 16 -- Valor padrão do Roblox
        end
        if InvisibilityOriginalJumpPower then
            humanoid.JumpPower = InvisibilityOriginalJumpPower
        else
            humanoid.JumpPower = 50 -- Valor padrão do Roblox
        end
        if InvisibilityOriginalPlatformStand ~= nil then
            humanoid.PlatformStand = InvisibilityOriginalPlatformStand
        else
            humanoid.PlatformStand = false
        end

        -- Restaurar configurações de exibição de nome/saúde
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Enemy
        humanoid.NameDisplayDistance = 100 -- Valor padrão
        humanoid.HealthDisplayDistance = 100 -- Valor padrão

        Notify("Invisibilidade", "Desativada. Seu corpo retornou.")
    end
end

-- ==================== AUTO ARREST ====================
local ArrestPlayer = ReplicatedStorage:WaitForChild("Remotes", 10) and ReplicatedStorage.Remotes:WaitForChild("ArrestPlayer", 10)
local ARREST_COOLDOWN = 1
local LastArrestAttempt = {}
local AutoArrestConnection = nil

local function AutoArrestLoop()
    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local targetHRP = player.Character.HumanoidRootPart
            local distance = (hrp.Position - targetHRP.Position).Magnitude

            if distance < 10 and (not LastArrestAttempt[player.UserId] or tick() - LastArrestAttempt[player.UserId] > ARREST_COOLDOWN) then
                if ArrestPlayer then
                    ArrestPlayer:FireServer(player.Character)
                    LastArrestAttempt[player.UserId] = tick()
                    Notify("Auto Arrest", "Tentando prender " .. player.Name .. ".")
                end
            end
        end
    end
end

local function ToggleAutoArrest(enabled)
    Settings.AutoArrestEnabled = enabled
    if enabled then
        if not AutoArrestConnection then
            AutoArrestConnection = RunService.Heartbeat:Connect(AutoArrestLoop)
        end
        Notify("Auto Arrest", "Ativado.")
    else
        if AutoArrestConnection then
            AutoArrestConnection:Disconnect()
            AutoArrestConnection = nil
        end
        Notify("Auto Arrest", "Desativado.")
    end
end

-- ==================== ESP ====================
local function CreateESPHighlight(targetChar)
    local highlight = Instance.new("Highlight")
    highlight.Adornee = targetChar
    highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Cor padrão, pode ser configurável
    highlight.OutlineColor = Settings.ESPOutlineColor
    highlight.FillTransparency = Settings.ESPFillerTransparency
    highlight.DepthMode = Settings.ESPDepthMode
    highlight.Parent = targetChar -- Anexar ao personagem para que seja destruído com ele
    ESPHighlights[targetChar] = highlight
end

local function RemoveESPHighlight(targetChar)
    if ESPHighlights[targetChar] then
        ESPHighlights[targetChar]:Destroy()
        ESPHighlights[targetChar] = nil
    end
end

local function UpdateESPHighlightProperties()
    for char, highlight in pairs(ESPHighlights) do
        if highlight and highlight.Parent then
            highlight.OutlineColor = Settings.ESPOutlineColor
            highlight.FillTransparency = Settings.ESPFillerTransparency
            highlight.DepthMode = Settings.ESPDepthMode
        end
    end
end

local function UpdateESP()
    if not Settings.ESPEnabled then
        for char, _ in pairs(ESPHighlights) do
            RemoveESPHighlight(char)
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 then
            if not ESPHighlights[player.Character] then
                CreateESPHighlight(player.Character)
            end
        else
            RemoveESPHighlight(player.Character)
        end
    end

    -- Remover highlights de personagens que não existem mais
    for char, _ in pairs(ESPHighlights) do
        if not char.Parent or not char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
            RemoveESPHighlight(char)
        end
    end
end

local function ToggleESP(enabled)
    Settings.ESPEnabled = enabled
    if enabled then
        -- Conectar eventos para atualizar ESP
        if not ESPConnections.PlayerAdded then
            ESPConnections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
                player.CharacterAdded:Connect(function(char)
                    task.wait(0.5) -- Dar um tempo para o personagem carregar
                    if Settings.ESPEnabled then
                        CreateESPHighlight(char)
                    end
                end)
            end)
        end
        if not ESPConnections.PlayerRemoving then
            ESPConnections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
                if player.Character then
                    RemoveESPHighlight(player.Character)
                end
            end)
        end
        if not ESPConnections.CharacterRemoving then
            ESPConnections.CharacterRemoving = LocalPlayer.CharacterRemoving:Connect(function(char)
                RemoveESPHighlight(char)
            end)
        end
        if not ESPConnections.Heartbeat then
            ESPConnections.Heartbeat = RunService.Heartbeat:Connect(UpdateESP)
        end
        UpdateESP()
        Notify("ESP", "Ativado.")
    else
        -- Desconectar eventos e remover todos os highlights
        for _, conn in pairs(ESPConnections) do
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end
        table.clear(ESPConnections)
        for char, _ in pairs(ESPHighlights) do
            RemoveESPHighlight(char)
        end
        Notify("ESP", "Desativado.")
    end
end

-- ==================== TELEPORT ====================
local function SaveCurrentPosition()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        SavedCFrame = char.HumanoidRootPart.CFrame
        Notify("Teleport", "Posição atual salva.")
    else
        Notify("Teleport", "Erro: Personagem ou HumanoidRootPart não encontrado.")
    end
end

local function ReturnToSavedPosition()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and SavedCFrame then
        char.HumanoidRootPart.CFrame = SavedCFrame
        Notify("Teleport", "Retornando à posição salva.")
    else
        Notify("Teleport", "Erro: Nenhuma posição salva ou personagem não encontrado.")
    end
end

local function TeleportToWeapon(weaponName, position)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(position)
        Notify("Teleport", "Teleportado para " .. weaponName .. ".")
    else
        Notify("Teleport", "Erro: Personagem ou HumanoidRootPart não encontrado.")
    end
end

local function CreatePortal()
    Notify("Portal", "Funcionalidade de portal não implementada.")
end

-- ==================== INICIALIZAÇÃO ====================
InitializeUI()

-- Conectar o toggle da UI à tecla Insert
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == UISettings.ToggleUIKey then
        ToggleUI()
    end
end)

-- Conectar o toggle do Aimbot à tecla definida nas configurações
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == Settings.ToggleKey then
        Settings.Enabled = not Settings.Enabled
        Notify("Aimbot", Settings.Enabled and "Ativado" or "Desativado")
    end
end)

-- Inicializar estados baseados nas configurações salvas
if Settings.NoClipEnabled then
    SetNoClip(true)
end
if Settings.InvisibilityEnabled then
    SetInvisibility(true)
end
if Settings.RapidFireEnabled then
    ToggleRapidFire(true)
end
if Settings.FastReloadEnabled then
    ToggleFastReload(true)
end
if Settings.AutoArrestEnabled then
    ToggleAutoArrest(true)
end
if Settings.ESPEnabled then
    ToggleESP(true)
end

-- ==================== UI DE DEBUG (OPCIONAL) ====================
-- Esta seção pode ser removida em um script final
local debugGui = Instance.new("ScreenGui")
debugGui.Name = "DebugUI"
debugGui.Parent = CoreGui

local debugText = Instance.new("TextLabel")
debugText.Size = UDim2.new(0, 200, 0, 50)
debugText.Position = UDim2.new(0, 10, 0, 10)
debugText.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
debugText.BackgroundTransparency = 0.5
debugText.TextColor3 = Color3.fromRGB(255, 255, 255)
debugText.Text = "Debug Info"
debugText.Parent = debugGui

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        debugText.Text = "Pos: " .. tostring(math.floor(char.HumanoidRootPart.Position.X)) .. ", " .. tostring(math.floor(char.HumanoidRootPart.Position.Y)) .. ", " .. tostring(math.floor(char.HumanoidRootPart.Position.Z))
    else
        debugText.Text = "No Character"
    end
end)
