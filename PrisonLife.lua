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
}

local IsMobile = UserInputService.TouchEnabled or UserInputService.GamepadEnabled

local UISettings = {
    Visible = true,
    ToggleUIKey = Enum.KeyCode.Insert,
    CurrentTab = "Main"
}

-- ==================== FUNÇÃO DE TOGGLE DA UI ====================
local UIComponents = { MainFrame = nil, TabButtons = {}, TabContents = {}, CloseButton = nil, ScreenGui = nil }

local function ToggleUI()
    UISettings.Visible = not UISettings.Visible
    if UIComponents and UIComponents.MainFrame then
        UIComponents.MainFrame.Visible = UISettings.Visible
    end
    if IsMobile and UIComponents and UIComponents.ScreenGui and UIComponents.ScreenGui:FindFirstChild("ToggleUIButton") then
        UIComponents.ScreenGui.ToggleUIButton.Visible = not UISettings.Visible
    end
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
    end

    pcall(function()
        sg.Parent = CoreGui
    end)
    if not sg.Parent then
        sg.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    UIComponents.ScreenGui = sg

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    if IsMobile then
        mainFrame.Size = UDim2.new(0.8, 0, 0.7, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    else
        mainFrame.Size = UDim2.new(0, 520, 0, 420)
        mainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
    end
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = not IsMobile
    mainFrame.Parent = sg
    mainFrame.Visible = UISettings.Visible
    UIComponents.MainFrame = mainFrame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25))
    })
    gradient.Rotation = 90
    gradient.Parent = mainFrame

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(120, 120, 255)
    mainStroke.Thickness = 2
    mainStroke.Transparency = 0.3
    mainStroke.Parent = mainFrame

    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6015897843"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.7
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.Parent = mainFrame

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 45)
    header.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header

    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 45, 70)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 50))
    })
    headerGradient.Rotation = 90
    headerGradient.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "JG SilentAim v2.0"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0, 6.5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header
    UIComponents.CloseButton = closeBtn

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn

    -- Abas agora são ScrollingFrame horizontal
    local tabContainer = Instance.new("ScrollingFrame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, -20, 0, 40)
    tabContainer.Position = UDim2.new(0, 10, 0, 55)
    tabContainer.BackgroundTransparency = 1
    tabContainer.BorderSizePixel = 0
    tabContainer.ScrollBarThickness = 4
    tabContainer.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
    tabContainer.CanvasSize = UDim2.new(0, 0, 1, 0) -- Será ajustado automaticamente
    tabContainer.AutomaticCanvasSize = Enum.AutomaticSize.X
    tabContainer.ScrollingDirection = Enum.ScrollingDirection.X
    tabContainer.Parent = mainFrame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.Parent = tabContainer

    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingLeft = UDim.new(0, 5)
    tabPadding.PaddingTop = UDim.new(0, 5)
    tabPadding.Parent = tabContainer

    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, -20, 1, -115)
    contentContainer.Position = UDim2.new(0, 10, 0, 100)
    contentContainer.BackgroundTransparency = 1
    contentContainer.ClipsDescendants = true
    contentContainer.Parent = mainFrame

    return sg, mainFrame, tabContainer, contentContainer
end

-- ==================== COMPONENTES DA UI ====================
local function CreateTabButton(parent, text, order)
    local btn = Instance.new("TextButton")
    btn.Name = text .. "Tab"
    btn.Size = UDim2.new(0, 100, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 14
    btn.Font = Enum.Font.Gotham
    btn.LayoutOrder = order
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(70, 70, 100)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        if UIComponents.TabButtons[text] ~= btn then return end
        local isSelected = (UISettings.CurrentTab == text)
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = isSelected and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(45, 45, 65)}):Play()
    end)

    return btn
end

local function CreateTabContent(parent, name)
    local content = Instance.new("ScrollingFrame")
    content.Name = name .. "Content"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 6
    content.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Visible = false
    content.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = content

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = content

    return content
end

local function CreateToggle(parent, text, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 35)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    container.BorderSizePixel = 0
    container.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 45, 0, 24)
    toggleBtn.Position = UDim2.new(1, -52, 0.5, -12)
    toggleBtn.BackgroundColor3 = defaultValue and Color3.fromRGB(70, 200, 70) or Color3.fromRGB(200, 70, 70)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = defaultValue and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 12
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = container

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = toggleBtn

    local isEnabled = defaultValue
    toggleBtn.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        toggleBtn.Text = isEnabled and "ON" or "OFF"
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = isEnabled and Color3.fromRGB(70, 200, 70) or Color3.fromRGB(200, 70, 70)}):Play()
        callback(isEnabled)
    end)

    return container
end

local function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(55, 55, 80)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(75, 75, 110)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(55, 55, 80)}):Play()
    end)

    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function CreateSlider(parent, text, min, max, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 50)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    container.BorderSizePixel = 0
    container.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 0, 20)
    label.Position = UDim2.new(0, 12, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 50, 0, 20)
    valueLabel.Position = UDim2.new(1, -55, 0, 5)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultValue)
    valueLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
    valueLabel.TextSize = 14
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container

    local sliderBack = Instance.new("Frame")
    sliderBack.Size = UDim2.new(1, -20, 0, 6)
    sliderBack.Position = UDim2.new(0, 10, 1, -15)
    sliderBack.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    sliderBack.BorderSizePixel = 0
    sliderBack.Parent = container

    local sliderBackCorner = Instance.new("UICorner")
    sliderBackCorner.CornerRadius = UDim.new(0, 3)
    sliderBackCorner.Parent = sliderBack

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((defaultValue - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(120, 120, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBack

    local sliderFillCorner = Instance.new("UICorner")
    sliderFillCorner.CornerRadius = UDim.new(0, 3)
    sliderFillCorner.Parent = sliderFill

    local dragging = false

    local function updateSlider(input)
        local relativeX = math.clamp((input.Position.X - sliderBack.AbsolutePosition.X) / sliderBack.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * relativeX)
        sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
        valueLabel.Text = tostring(value)
        callback(value)
    end

    sliderBack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input)
        end
    end)

    sliderBack.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input)
        end
    end)

    return container
end

local function CreateDropdown(parent, text, options, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 35)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    container.BorderSizePixel = 0
    container.Parent = parent
    container.ClipsDescendants = false
    container.ZIndex = 1

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, -10, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 2
    label.Parent = container

    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Size = UDim2.new(0.5, -20, 0, 25)
    dropdownBtn.Position = UDim2.new(0.5, 5, 0.5, -12.5)
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.Text = defaultValue .. " ▼"
    dropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownBtn.TextSize = 12
    dropdownBtn.Font = Enum.Font.Gotham
    dropdownBtn.ZIndex = 2
    dropdownBtn.Parent = container

    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6)
    dropdownCorner.Parent = dropdownBtn

    local dropdownList = Instance.new("Frame")
    dropdownList.Size = UDim2.new(0, 230, 0, math.min(#options * 25, 150))
    dropdownList.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    dropdownList.BorderSizePixel = 0
    dropdownList.Visible = false
    dropdownList.ZIndex = 100
    dropdownList.Parent = UIComponents.ScreenGui

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 8)
    listCorner.Parent = dropdownList

    local listStroke = Instance.new("UIStroke")
    listStroke.Color = Color3.fromRGB(120, 120, 255)
    listStroke.Thickness = 1
    listStroke.Parent = dropdownList

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #options * 25)
    scrollFrame.ZIndex = 101
    scrollFrame.Parent = dropdownList

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollFrame

    for i, option in ipairs(options) do
        local optionBtn = Instance.new("TextButton")
        optionBtn.Size = UDim2.new(1, 0, 0, 25)
        optionBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
        optionBtn.BorderSizePixel = 0
        optionBtn.Text = option
        optionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        optionBtn.TextSize = 12
        optionBtn.Font = Enum.Font.Gotham
        optionBtn.LayoutOrder = i
        optionBtn.ZIndex = 102
        optionBtn.Parent = scrollFrame

        optionBtn.MouseEnter:Connect(function()
            optionBtn.BackgroundColor3 = Color3.fromRGB(65, 65, 90)
        end)

        optionBtn.MouseLeave:Connect(function()
            optionBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
        end)

        optionBtn.MouseButton1Click:Connect(function()
            dropdownBtn.Text = option .. " ▼"
            dropdownList.Visible = false
            callback(option)
        end)
    end

    dropdownBtn.MouseButton1Click:Connect(function()
        dropdownList.Visible = not dropdownList.Visible
        if dropdownList.Visible then
            local btnPos = dropdownBtn.AbsolutePosition
            local btnSize = dropdownBtn.AbsoluteSize
            dropdownList.Position = UDim2.new(0, btnPos.X, 0, btnPos.Y + btnSize.Y + 2)
        end
    end)

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dropdownList.Visible then
                local mousePos = UserInputService:GetMouseLocation()
                local listPos = dropdownList.AbsolutePosition
                local listSize = dropdownList.AbsoluteSize

                if mousePos.X < listPos.X or mousePos.X > listPos.X + listSize.X or
                   mousePos.Y < listPos.Y or mousePos.Y > listPos.Y + listSize.Y then
                    if not (mousePos.X >= dropdownBtn.AbsolutePosition.X and 
                           mousePos.X <= dropdownBtn.AbsolutePosition.X + dropdownBtn.AbsoluteSize.X and
                           mousePos.Y >= dropdownBtn.AbsolutePosition.Y and 
                           mousePos.Y <= dropdownBtn.AbsolutePosition.Y + dropdownBtn.AbsoluteSize.Y) then
                        dropdownList.Visible = false
                    end
                end
            end
        end
    end)

    return container
end

local function CreateKeybindSelector(parent, text, defaultKey, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 35)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    container.BorderSizePixel = 0
    container.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, -10, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size = UDim2.new(0.5, -20, 0, 25)
    keybindBtn.Position = UDim2.new(0.5, 5, 0.5, -12.5)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
    keybindBtn.BorderSizePixel = 0
    keybindBtn.Text = GetKeyName(defaultKey)
    keybindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindBtn.TextSize = 12
    keybindBtn.Font = Enum.Font.GothamBold
    keybindBtn.Parent = container

    local keybindCorner = Instance.new("UICorner")
    keybindCorner.CornerRadius = UDim.new(0, 6)
    keybindCorner.Parent = keybindBtn

    local listening = false
    local connection

    keybindBtn.MouseButton1Click:Connect(function()
        if listening then return end

        listening = true
        keybindBtn.Text = "..."
        keybindBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 255)

        connection = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local newKey = input.KeyCode
                keybindBtn.Text = GetKeyName(newKey)
                keybindBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
                listening = false
                callback(newKey)
                connection:Disconnect()
            end
        end)
    end)

    return container
end

local function MakeDraggable(frame, dragHandle)
    local dragging = false
    local dragInput, mousePos, framePos

    dragHandle = dragHandle or frame

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            frame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)
end

local function SwitchTab(tabName)
    UISettings.CurrentTab = tabName
    for name, content in pairs(UIComponents.TabContents) do
        content.Visible = false
    end
    if UIComponents.TabContents[tabName] then
        UIComponents.TabContents[tabName].Visible = true
    end
    for name, button in pairs(UIComponents.TabButtons) do
        if name == tabName then
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 255)}):Play()
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 45, 65)}):Play()
            button.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
end

-- ==================== FUNÇÕES DE ESP ====================
local function ClearESPForPlayer(plr)
    local data = ESPHighlights[plr]
    if not data then return end

    if data.highlight and data.highlight.Destroy then
        data.highlight:Destroy()
    end

    if data.conns then
        for _, conn in ipairs(data.conns) do
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end
    end

    ESPHighlights[plr] = nil
end

local function ApplyESPToPlayer(plr)
    if plr == LocalPlayer then return end

    ClearESPForPlayer(plr)

    local data = { conns = {} }
    ESPHighlights[plr] = data

    local function attachHighlight(char)
        if not Settings.ESPEnabled then return end
        if not char then return end

        if data.highlight and data.highlight.Parent then
            data.highlight:Destroy()
        end

        local hl = Instance.new("Highlight")
        hl.Name = "JGSilentAim_ESP_Highlight"
        hl.Adornee = char
        local teamColor = plr.Team and plr.Team.TeamColor.Color or Color3.fromRGB(255, 255, 255)

        hl.FillColor = teamColor
        hl.FillTransparency = Settings.ESPFillerTransparency
        hl.OutlineColor = Settings.ESPOutlineColor
        hl.OutlineTransparency = 0
        hl.DepthMode = Settings.ESPDepthMode
        hl.Parent = char

        data.highlight = hl
    end

    if plr.Character then
        attachHighlight(plr.Character)
    end

    table.insert(data.conns, plr.CharacterAdded:Connect(function(char)
        if data.highlight then
            data.highlight:Destroy()
            data.highlight = nil
        end
        task.wait(0.5)
        attachHighlight(char)
    end))

    table.insert(data.conns, plr:GetPropertyChangedSignal("Team"):Connect(function()
        if data.highlight then
            local teamColor = plr.Team and plr.Team.TeamColor.Color or Color3.fromRGB(255, 255, 255)
            data.highlight.FillColor = teamColor
        end
    end))
end

local function EnableESP()
    if Settings.ESPEnabled then return end
    Settings.ESPEnabled = true

    for _, plr in ipairs(Players:GetPlayers()) do
        ApplyESPToPlayer(plr)
    end

    if ESPConnections.playerAdded and ESPConnections.playerAdded.Connected then
        ESPConnections.playerAdded:Disconnect()
    end
    ESPConnections.playerAdded = Players.PlayerAdded:Connect(function(plr)
        ApplyESPToPlayer(plr)
    end)

    if ESPConnections.playerRemoving and ESPConnections.playerRemoving.Connected then
        ESPConnections.playerRemoving:Disconnect()
    end
    ESPConnections.playerRemoving = Players.PlayerRemoving:Connect(function(plr)
        ClearESPForPlayer(plr)
    end)
end

local function DisableESP()
    if not Settings.ESPEnabled then return end
    Settings.ESPEnabled = false

    for plr, _ in pairs(ESPHighlights) do
        ClearESPForPlayer(plr)
    end

    if ESPConnections.playerAdded and ESPConnections.playerAdded.Connected then
        ESPConnections.playerAdded:Disconnect()
    end
    if ESPConnections.playerRemoving and ESPConnections.playerRemoving.Connected then
        ESPConnections.playerRemoving:Disconnect()
    end

    ESPConnections.playerAdded = nil
    ESPConnections.playerRemoving = nil
end

local function UpdateESPHighlightProperties()
    for plr, data in pairs(ESPHighlights) do
        if data.highlight then
            local teamColor = plr.Team and plr.Team.TeamColor.Color or Color3.fromRGB(255, 255, 255)

            data.highlight.FillColor = teamColor
            data.highlight.FillTransparency = Settings.ESPFillerTransparency
            data.highlight.OutlineColor = Settings.ESPOutlineColor
            data.highlight.DepthMode = Settings.ESPDepthMode
        end
    end
end

-- ==================== FUNÇÕES DE RAPID FIRE E FAST RELOAD ====================
local function ensureRapidFireWatcher(tool)
    if RapidFireWatchers[tool] then return end
    RapidFireWatchers[tool] = tool:GetAttributeChangedSignal("FireRate"):Connect(function()
        if Settings.RapidFireEnabled then
            tool:SetAttribute("FireRate", 0)
        end
    end)
    tool:GetAttributeChangedSignal("AutoFire"):Connect(function()
        if Settings.RapidFireEnabled then
            tool:SetAttribute("AutoFire", true)
        end
    end)
end

local function applyRapidFireToTool(tool)
    if not tool or not tool:IsA("Tool") then return end

    local currentFireRate = tool:GetAttribute("FireRate")
    local currentAutoFire = tool:GetAttribute("AutoFire")

    if currentFireRate ~= nil and OriginalFireRate[tool] == nil then
        OriginalFireRate[tool] = currentFireRate
    end
    if currentAutoFire ~= nil and OriginalAutoFire[tool] == nil then
        OriginalAutoFire[tool] = currentAutoFire
    end

    if Settings.RapidFireEnabled then
        if currentFireRate ~= nil then tool:SetAttribute("FireRate", 0) end
        if currentAutoFire ~= nil then tool:SetAttribute("AutoFire", true) end
    else
        if OriginalFireRate[tool] ~= nil then
            tool:SetAttribute("FireRate", OriginalFireRate[tool])
        end
        if OriginalAutoFire[tool] ~= nil then
            tool:SetAttribute("AutoFire", OriginalAutoFire[tool])
        end
    end

    ensureRapidFireWatcher(tool)
end

local function scanRapidFire(character)
    character = character or LocalPlayer.Character
    if not character then return end

    for _, t in ipairs(character:GetChildren()) do
        if t:IsA("Tool") then
            applyRapidFireToTool(t)
        end
    end
    for _, t in ipairs(backpack:GetChildren()) do
        if t:IsA("Tool") then
            applyRapidFireToTool(t)
        end
    end
end

local function ensureFastReloadWatcher(tool)
    if FastReloadWatchers[tool] then return end
    FastReloadWatchers[tool] = tool:GetAttributeChangedSignal("ReloadTime"):Connect(function()
        if Settings.FastReloadEnabled then
            tool:SetAttribute("ReloadTime", 0)
        end
    end)
end

local function applyFastReloadToTool(tool)
    if not tool or not tool:IsA("Tool") then return end

    local current = tool:GetAttribute("ReloadTime")
    if current ~= nil and OriginalReloadTime[tool] == nil then
        OriginalReloadTime[tool] = current
    end

    if Settings.FastReloadEnabled then
        if current ~= nil then tool:SetAttribute("ReloadTime", 0) end
    else
        if OriginalReloadTime[tool] ~= nil then
            tool:SetAttribute("ReloadTime", OriginalReloadTime[tool])
        end
    end

    ensureFastReloadWatcher(tool)
end

local function scanFastReload(character)
    character = character or LocalPlayer.Character
    if not character then return end

    for _, t in ipairs(character:GetChildren()) do
        if t:IsA("Tool") then
            applyFastReloadToTool(t)
        end
    end
    for _, t in ipairs(backpack:GetChildren()) do
        if t:IsA("Tool") then
            applyFastReloadToTool(t)
        end
    end
end

local function ToggleRapidFire(enabled)
    Settings.RapidFireEnabled = enabled
    scanRapidFire()
end

local function ToggleFastReload(enabled)
    Settings.FastReloadEnabled = enabled
    scanFastReload()
end

local function hookCharacterWeaponMods(char)
    if not char then return end
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.1)
            applyRapidFireToTool(child)
            applyFastReloadToTool(child)
        end
    end)
    scanRapidFire(char)
    scanFastReload(char)
end

-- ==================== NOCLIP CORRIGIDO ====================
local NoClipConnection = nil

local function SetNoClip(enabled)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if enabled then
        if NoClipConnection and NoClipConnection.Connected then
            NoClipConnection:Disconnect()
        end

        humanoid:ChangeState(Enum.HumanoidStateType.Flying)

        NoClipConnection = RunService.Stepped:Connect(function()
            if not Settings.NoClipEnabled or not LocalPlayer.Character then
                if NoClipConnection and NoClipConnection.Connected then
                    NoClipConnection:Disconnect()
                end
                return
            end
            local char = LocalPlayer.Character
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum:GetState() ~= Enum.HumanoidStateType.Flying then
                hum:ChangeState(Enum.HumanoidStateType.Flying)
            end
        end)

        Notify("NoClip", "Ativado – você atravessa paredes.")
    else
        if NoClipConnection and NoClipConnection.Connected then
            NoClipConnection:Disconnect()
        end
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        Notify("NoClip", "Desativado.")
    end
end

-- ==================== INVISIBILIDADE FINAL (CORREÇÃO DE TELEPORTE E VOID) ====================
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local InvisibilityData = {
    originalCF = nil,
    groundLevel = nil,
    realChar = nil,
    realHRP = nil,
    clone = nil,
    connection = nil,
    active = false,
    newY = 0
}

local function SetInvisibility(enabled)
    local character = LocalPlayer.Character
    if not character then 
        Notify("Erro", "Personagem não encontrado")
        return 
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not hrp then 
        Notify("Erro", "Humanoid ou HRP não encontrado")
        return 
    end

    if enabled then
        if InvisibilityData.active then return end

        -- Salva posição original
        local pos = hrp.Position
        InvisibilityData.originalCF = hrp.CFrame

        -- Encontra a altura do chão abaixo do personagem
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {character}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        local ray = workspace:Raycast(pos, Vector3.new(0, -500, 0), raycastParams)

        if ray then
            InvisibilityData.groundLevel = ray.Position.Y
        else
            InvisibilityData.groundLevel = pos.Y - 50 -- fallback
        end

        -- Cria um clone COMPLETO do personagem na superfície
        character.Archivable = true
        local clone = character:Clone()
        character.Archivable = false
        clone.Name = "MainCharacter_Clone"
        
        local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
        local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
        
        if not cloneHRP or not cloneHumanoid then
            Notify("Erro", "Falha ao criar clone funcional")
            if clone then clone:Destroy() end
            return
        end
        
        cloneHRP.CFrame = InvisibilityData.originalCF
        cloneHRP.Anchored = false
        cloneHRP.CanCollide = true

        -- Estética do clone
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0.3
                part.CanCollide = true
            end
        end

        -- Remove scripts para evitar bugs
        for _, script in ipairs(clone:GetDescendants()) do
            if script:IsA("Script") or script:IsA("LocalScript") then
                script:Destroy()
            end
        end

        clone.Parent = workspace
        InvisibilityData.clone = clone

        -- Move o corpo REAL para o subsolo (não muito fundo para evitar o void)
        InvisibilityData.newY = InvisibilityData.groundLevel - 15
        hrp.CFrame = CFrame.new(pos.X, InvisibilityData.newY, pos.Z)

        -- Desativa colisão do corpo real
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end

        -- Configura o Humanoid do corpo real para ser o "motor"
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        
        -- PREVENÇÃO DE MORTE NO VOID: Ancorar o HRP real quando não estiver se movendo
        -- ou garantir que ele não caia mais do que o necessário.
        hrp.Anchored = false -- Começa solto para o motor funcionar

        -- Foca a câmera no clone
        workspace.CurrentCamera.CameraSubject = cloneHumanoid

        -- Loop de sincronização
        InvisibilityData.connection = RunService.RenderStepped:Connect(function()
            if not InvisibilityData.active or not clone or not hrp then 
                if InvisibilityData.connection then InvisibilityData.connection:Disconnect() end
                return 
            end

            if not clone.Parent then return end

            -- 1. Sincroniza o movimento: O clone imita a direção que o jogador está tentando ir
            local moveDirection = humanoid.MoveDirection
            cloneHumanoid:Move(moveDirection, false)
            
            -- 2. Sincroniza o pulo
            cloneHumanoid.Jump = humanoid.Jump

            -- 3. O corpo real segue o clone no subsolo
            local clonePos = cloneHRP.Position
            -- Mantemos o corpo real SEMPRE na mesma altura Y para evitar cair no void
            hrp.CFrame = CFrame.new(clonePos.X, InvisibilityData.newY, clonePos.Z) * (cloneHRP.CFrame.Rotation)

            -- Mantém colisão desativada no real
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)

        InvisibilityData.realChar = character
        InvisibilityData.realHRP = hrp
        InvisibilityData.active = true
        
        Notify("Invisibilidade", "Ativada - Movimento sincronizado e proteção contra void.")
    else
        -- DESATIVAÇÃO (CORREÇÃO DE TELEPORTE)
        if InvisibilityData.connection then
            InvisibilityData.connection:Disconnect()
            InvisibilityData.connection = nil
        end

        local finalCFrame = nil
        if InvisibilityData.clone then
            local cloneHRP = InvisibilityData.clone:FindFirstChild("HumanoidRootPart")
            if cloneHRP then
                -- SALVA A POSIÇÃO ATUAL DO CLONE PARA O TELEPORTE FINAL
                finalCFrame = cloneHRP.CFrame
            end
            InvisibilityData.clone:Destroy()
            InvisibilityData.clone = nil
        end

        if character then
            character.Archivable = false
        end

        -- Restaura corpo real NA POSIÇÃO ONDE O CLONE ESTAVA
        if hrp then
            if finalCFrame then
                hrp.CFrame = finalCFrame
            elseif InvisibilityData.originalCF then
                hrp.CFrame = InvisibilityData.originalCF
            end
            
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end

        -- Restaura Humanoid e Câmera
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
            workspace.CurrentCamera.CameraSubject = humanoid
        end

        InvisibilityData.active = false
        Notify("Invisibilidade", "Desativada - Você permaneceu na posição atual.")
    end
end

-- Limpeza ao trocar de personagem
LocalPlayer.CharacterAdded:Connect(function(newChar)
    if InvisibilityData.active then
        SetInvisibility(false)
    end
end)

-- ==================== FUNÇÕES DE TELEPORTE ====================
local function Teleport(position)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CanCollide = false
        hrp.CFrame = CFrame.new(position)
        task.wait(0.1)
        hrp.CanCollide = true
    end
end

local function SaveCurrentPosition()
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    SavedPosition = hrp.Position
    SavedCFrame = hrp.CFrame
    Notify("Posição salva", "Local atual guardado.")
    return true
end

local function HasGamepass(weaponName)
    return true
end

local function TeleportToWeapon(weaponName, coords)
    if not HasGamepass(weaponName) then
        Notify("Aviso", "Você não possui a gamepass para " .. weaponName)
        return
    end
    if not SavedPosition then
        SaveCurrentPosition()
    end
    Teleport(coords)
    Notify("Teleporte", "Teleportado para " .. weaponName)
end

local function ReturnToSavedPosition()
    if SavedPosition then
        Teleport(SavedPosition)
        Notify("Voltou", "Retornou à posição salva.")
    else
        Notify("Erro", "Nenhuma posição salva.")
    end
end

-- ==================== SISTEMA DE PORTAL ====================
local PortalParts = {}
local PortalCooldown = {}
local PLAYER_PORTAL_COOLDOWN = 2
local lastPlayerPortalTime = 0

local function CreatePortal()
    for _, part in ipairs(PortalParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end

    PortalParts = {}
    PortalCooldown = {}

    local posPrisao = Vector3.new(997.28, 100.39, 2329.03)
    local posBase = Vector3.new(-966.4554, 94.1289, 2080.625)

    local function createPortalPart(position, targetPosition, color, name, rotationY)
        local part = Instance.new("Part")
        part.Name = "Portal_" .. name
        part.Size = Vector3.new(5,10,1)
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 0.3
        part.BrickColor = BrickColor.new(color)
        part.Material = Enum.Material.Neon
        part.Parent = workspace

        local rotation = CFrame.Angles(0, math.rad(rotationY), 0)
        local offset = CFrame.new(0,0,-0.6)
        part.CFrame = CFrame.new(position) * rotation * offset

        local highlight = Instance.new("Highlight")
        highlight.Adornee = part
        highlight.FillColor = (color == "Bright blue") and Color3.fromRGB(0,100,255) or Color3.fromRGB(255,0,0)
        highlight.FillTransparency = 0.2
        highlight.OutlineTransparency = 1
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = part

        PortalCooldown[part] = 0

        part.Touched:Connect(function(hit)
            if not hit.Parent then return end
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if player == LocalPlayer then
                local now = tick()
                if now - lastPlayerPortalTime < PLAYER_PORTAL_COOLDOWN then return end
                if now - (PortalCooldown[part] or 0) < 3 then return end

                lastPlayerPortalTime = now
                PortalCooldown[part] = now

                task.wait(0.5)

                if part and part.Parent then
                    Teleport(targetPosition)
                    Notify("Portal", "Teleportado para " .. (name == "Prisao" and "Base dos Criminosos" or "Prisão"))
                end
            end
        end)

        return part
    end

    local partPrisao = createPortalPart(posPrisao, posBase, "Bright blue", "Prisao", 90)
    local partBase = createPortalPart(posBase, posPrisao, "Bright red", "Base", 180)

    PortalParts = {partPrisao, partBase}
    Notify("Portal criado", "Use os portais para teleportar.")
end

-- ==================== INICIALIZAÇÃO DA UI ====================
local function InitializeUI()
    local screenGui, mainFrame, tabContainer, contentContainer = CreateModernUI()     
    local tabs = {
        {name = "Main", order = 1},
        {name = "Aim", order = 2},
        {name = "Visuals", order = 3},
        {name = "ESP", order = 4},
        {name = "Weapon", order = 5},
        {name = "Player", order = 6},
        {name = "Teleport", order = 7},
        {name = "Settings", order = 8},
    }

    for _, tab in ipairs(tabs) do
        local tabBtn = CreateTabButton(tabContainer, tab.name, tab.order)
        UIComponents.TabButtons[tab.name] = tabBtn

        local tabContent = CreateTabContent(contentContainer, tab.name)
        UIComponents.TabContents[tab.name] = tabContent

        tabBtn.MouseButton1Click:Connect(function()
            SwitchTab(tab.name)
        end)
    end

    -- Aba Main
    local mainContent = UIComponents.TabContents["Main"]
    CreateToggle(mainContent, "Aimbot Enabled", Settings.Enabled, function(v) Settings.Enabled = v end)
    CreateToggle(mainContent, "Team Check", Settings.TeamCheck, function(v) Settings.TeamCheck = v end)
    CreateToggle(mainContent, "Wall Check", Settings.WallCheck, function(v) Settings.WallCheck = v end)
    CreateToggle(mainContent, "Death Check", Settings.DeathCheck, function(v) Settings.DeathCheck = v end)
    CreateToggle(mainContent, "ForceField Check", Settings.ForceFieldCheck, function(v) Settings.ForceFieldCheck = v end)

    -- Aba Aim
    local aimContent = UIComponents.TabContents["Aim"]
    CreateSlider(aimContent, "Hit Chance (%)", 0, 100, Settings.HitChance, function(v) Settings.HitChance = v end)
    CreateSlider(aimContent, "Miss Spread", 0, 20, Settings.MissSpread, function(v) Settings.MissSpread = v end)
    CreateSlider(aimContent, "FOV Radius", 50, 500, Settings.FOV, function(v) Settings.FOV = v end)
    CreateDropdown(aimContent, "Aim Part", Settings.AimPartsList, Settings.AimPart, function(v) Settings.AimPart = v end)
    CreateToggle(aimContent, "Random Aim Parts", Settings.RandomAimParts, function(v) Settings.RandomAimParts = v end)

    -- Aba Visuals
    local visualsContent = UIComponents.TabContents["Visuals"]
    CreateToggle(visualsContent, "Show FOV Circle", Settings.ShowFOV, function(v) Settings.ShowFOV = v end)
    CreateToggle(visualsContent, "Show Target Line", Settings.ShowTargetLine, function(v) Settings.ShowTargetLine = v end)

    -- Aba ESP
    local espContent = UIComponents.TabContents["ESP"]
    CreateToggle(espContent, "ESP Enabled", Settings.ESPEnabled, function(v)
        if v then EnableESP() else DisableESP() end
    end)
    CreateSlider(espContent, "Fill Transparency", 0, 100, Settings.ESPFillerTransparency * 100, function(v)
        Settings.ESPFillerTransparency = v / 100
        UpdateESPHighlightProperties()
    end)
    CreateDropdown(espContent, "Depth Mode", {"AlwaysOnTop", "Occluded"}, Settings.ESPDepthMode.Name, function(v)
        Settings.ESPDepthMode = Enum.HighlightDepthMode[v]
        UpdateESPHighlightProperties()
    end)

    -- Aba Weapon
    local weaponContent = UIComponents.TabContents["Weapon"]
    CreateToggle(weaponContent, "Rapid Fire", Settings.RapidFireEnabled, ToggleRapidFire)
    CreateToggle(weaponContent, "Fast Reload", Settings.FastReloadEnabled, ToggleFastReload)

    -- Aba Player
    local playerContent = UIComponents.TabContents["Player"]
    CreateToggle(playerContent, "NoClip", Settings.NoClipEnabled, function(s) Settings.NoClipEnabled = s; SetNoClip(s) end)
    CreateToggle(playerContent, "Invisibility", Settings.InvisibilityEnabled, function(s) Settings.InvisibilityEnabled = s; SetInvisibility(s) end)

    -- Aba Teleport
    local teleportContent = UIComponents.TabContents["Teleport"]
    CreateButton(teleportContent, "Salvar Posição Atual", SaveCurrentPosition)
    CreateButton(teleportContent, "TP para AK47", function() TeleportToWeapon("AK47", WeaponCoordinates.AK47) end)
    CreateButton(teleportContent, "TP para Shotgun", function() TeleportToWeapon("Shotgun", WeaponCoordinates.Shotgun) end)
    CreateButton(teleportContent, "TP para MP5", function() TeleportToWeapon("MP5", WeaponCoordinates.MP5) end)
    CreateButton(teleportContent, "TP para Sniper", function() TeleportToWeapon("Sniper", WeaponCoordinates.Sniper) end)
    CreateButton(teleportContent, "TP para M4A1", function() TeleportToWeapon("M4A1", WeaponCoordinates.M4A1) end)
    CreateButton(teleportContent, "Voltar à Posição Salva", ReturnToSavedPosition)
    CreateButton(teleportContent, "Criar Portal (Base Criminosos ↔ Prisão)", CreatePortal)

    -- Aba Settings
    local settingsContent = UIComponents.TabContents["Settings"]
    CreateKeybindSelector(settingsContent, "Toggle UI", UISettings.ToggleUIKey, function(k) UISettings.ToggleUIKey = k end)
    CreateKeybindSelector(settingsContent, "Toggle Aimbot", Settings.ToggleKey, function(k) Settings.ToggleKey = k end)
    CreateButton(settingsContent, "Salvar Configurações", SaveSettings)
    CreateButton(settingsContent, "Carregar Configurações", LoadSettings)

    -- Tornar arrastável
    MakeDraggable(mainFrame, mainFrame:FindFirstChild("Header"))

    -- Fechar
    UIComponents.CloseButton.MouseButton1Click:Connect(ToggleUI)

    SwitchTab("Main")
    return screenGui
end

-- ==================== CRIAÇÃO DOS VISUAIS (FOV e Linha) ====================
local function CreateVisuals()
    local sg = Instance.new("ScreenGui")
    sg.Name = "JGSilentAimVisuals"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true

    pcall(function()
        sg.Parent = CoreGui
    end)
    if not sg.Parent then
        sg.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    Visuals.Gui = sg

    local circleFrame = Instance.new("Frame")
    circleFrame.Name = "FOVCircle"
    circleFrame.BackgroundTransparency = 1
    circleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    circleFrame.Visible = false
    circleFrame.Parent = sg

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = circleFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circleFrame

    Visuals.Circle = circleFrame

    local lineFrame = Instance.new("Frame")
    lineFrame.Name = "TargetLine"
    lineFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    lineFrame.BorderSizePixel = 0
    lineFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    lineFrame.Visible = false
    lineFrame.Parent = sg
    Visuals.Line = lineFrame
end

-- ==================== FUNÇÕES DE TRAÇADORES ====================
local TracerPool = {
    bullets = {},
    tasers = {},
    maxPoolSize = 20
}

local function GetPooledPart(pool, createFunc)
    for i, part in ipairs(pool) do
        if not part.Parent then
            return table.remove(pool, i)
        end
    end
    if #pool < TracerPool.maxPoolSize then
        return createFunc()
    end
    return createFunc()
end

local function ReturnToPool(pool, part)
    part.Parent = nil
    if #pool < TracerPool.maxPoolSize then
        table.insert(pool, part)
    else
        part:Destroy()
    end
end

local function CreateBaseBulletPart()
    local bullet = Instance.new("Part")
    bullet.Name = "PooledBullet"
    bullet.Anchored = true
    bullet.CanCollide = false
    bullet.CastShadow = false
    bullet.Material = Enum.Material.Neon
    bullet.BrickColor = BrickColor.Yellow()

    local mesh = Instance.new("BlockMesh", bullet)
    mesh.Scale = Vector3.new(0.5, 0.5, 1)

    return bullet
end

local function CreateBaseTaserPart()
    local bullet = Instance.new("Part")
    bullet.Name = "PooledTaser"
    bullet.Anchored = true
    bullet.CanCollide = false
    bullet.CastShadow = false
    bullet.Material = Enum.Material.Neon
    bullet.BrickColor = BrickColor.new("Cyan")

    local mesh = Instance.new("BlockMesh", bullet)
    mesh.Scale = Vector3.new(0.8, 0.8, 1)

    return bullet
end

for i = 1, 5 do
    table.insert(TracerPool.bullets, CreateBaseBulletPart())
    table.insert(TracerPool.tasers, CreateBaseTaserPart())
end

-- ==================== MAPEAMENTO DE PARTES DO CORPO ====================
local PartMappings = {
    ["Torso"] = {"Torso", "UpperTorso", "LowerTorso"},
    ["LeftArm"] = {"Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand"},
    ["RightArm"] = {"Right Arm", "RightUpperArm", "RightLowerArm", "RightHand"},
    ["LeftLeg"] = {"Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
    ["RightLeg"] = {"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
}

local function GetBodyPart(character, partName)
    if not character then return nil end

    local directPart = character:FindFirstChild(partName)
    if directPart then return directPart end

    local mappings = PartMappings[partName]
    if mappings then
        for _, name in ipairs(mappings) do
            local part = character:FindFirstChild(name)
            if part then return part end
        end
    end

    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
end

local function GetTargetPart(character)
    if not character then return nil end
    local partName
    if Settings.RandomAimParts then
        local partsList = Settings.AimPartsList
        partName = (partsList and #partsList > 0) and partsList[math.random(1, #partsList)] or "Head"
    else
        partName = Settings.AimPart
    end
    return GetBodyPart(character, partName)
end

local function GetMissPosition(targetPos)
    local x = math.random(-100, 100)
    local y = math.random(-100, 100)
    local z = math.random(-100, 100)
    local mag = math.sqrt(x*x + y*y + z*z)
    if mag > 0 then
        x, y, z = x/mag, y/mag, z/mag
    end
    return targetPos + Vector3.new(x * Settings.MissSpread, y * Settings.MissSpread, z * Settings.MissSpread)
end

-- ==================== SONS E TRAÇADORES ====================
local ActiveSounds = {}
local function PlayGunSound(gun)
    if not gun then return end
    local handle = gun:FindFirstChild("Handle")
    if not handle then return end

    local shootSound = handle:FindFirstChild("ShootSound")
    if shootSound then
        local soundKey = gun:GetFullName() .. "_shoot"
        local sound = ActiveSounds[soundKey]

        if not sound or not sound.Parent then
            sound = shootSound:Clone()
            sound.Parent = handle
            ActiveSounds[soundKey] = sound
        end

        sound:Play()
    end
end

local function CreateProjectileTracer(startPos, endPos, gun)
    local distance = (endPos - startPos).Magnitude
    local isTaser = gun:GetAttribute("Projectile") == "Taser"

    local bullet 
    if isTaser then
        bullet = GetPooledPart(TracerPool.tasers, CreateBaseTaserPart)
    else
        bullet = GetPooledPart(TracerPool.bullets, CreateBaseBulletPart)
    end

    bullet.Transparency = 0.5
    bullet.Size = Vector3.new(0.2, 0.2, distance)
    bullet.CFrame = CFrame.new(endPos, startPos) * CFrame.new(0, 0, -distance / 2)
    bullet.Parent = workspace

    local tweenInfo = TweenInfo.new(isTaser and 0.8 or 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local fade = TweenService:Create(bullet, tweenInfo, { Transparency = 1 })

    fade:Play()
    fade.Completed:Once(function()
        if isTaser then
            ReturnToPool(TracerPool.tasers, bullet)
        else
            ReturnToPool(TracerPool.bullets, bullet)
        end
    end)
end

-- ==================== VERIFICAÇÕES DE ALVO ====================
local function IsPlayerDead(plr)
    if not plr or not plr.Character then return true end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return not hum or hum.Health <= 0
end

local function HasForceField(plr)
    if not plr or not plr.Character then return false end
    return plr.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function IsWallBetween(startPos, endPos, targetCharacter)
    local myChar = LocalPlayer.Character
    if not myChar then return true end

    WallCheckParams.FilterDescendantsInstances = { myChar }
    local direction = endPos - startPos
    local distance = direction.Magnitude
    local result = workspace:Raycast(startPos, direction.Unit * distance, WallCheckParams)

    if not result then return false end

    local hitPart = result.Instance
    if targetCharacter and hitPart:IsDescendantOf(targetCharacter) then return false end

    if hitPart.Transparency >= 0.8 or not hitPart.CanCollide then
        return false 
    end
    return true
end

local function IsValidTargetQuick(plr)
    if not plr or plr == LocalPlayer or not plr.Character then return false end
    if not GetTargetPart(plr.Character) then return false end
    if Settings.DeathCheck and IsPlayerDead(plr) then return false end
    if Settings.ForceFieldCheck and HasForceField(plr) then return false end
    if Settings.TeamCheck and plr.Team == LocalPlayer.Team then return false end
    return true
end

local function IsValidTargetFull(plr)
    if not IsValidTargetQuick(plr) then return false end

    if Settings.WallCheck then
        local myChar = LocalPlayer.Character
        local myHead = myChar and myChar:FindFirstChild("Head")
        local targetPart = GetTargetPart(plr.Character)
        if myHead and targetPart then
            if IsWallBetween(myHead.Position, targetPart.Position, plr.Character) then 
                return false 
            end
        end
    end
    return true
end

local function RollHitChance()
    if Settings.HitChance >= 100 then return true end
    if Settings.HitChance <= 0 then return false end
    return math.random(1, 100) <= Settings.HitChance
end

-- ==================== SELEÇÃO DE ALVO ====================
local function GetClosestTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local mousePos = UserInputService:GetMouseLocation()
    local candidates = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if IsValidTargetQuick(plr) then
            local targetPart = GetTargetPart(plr.Character)
            if targetPart then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < Settings.FOV then
                        table.insert(candidates, {player = plr, distance = dist})
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b) return a.distance < b.distance end)

    for _, candidate in ipairs(candidates) do
        if IsValidTargetFull(candidate.player) then
            return candidate.player
        end
    end

    return nil
end

-- ==================== FUNÇÕES DE ARMA ====================
local function GetEquippedGun()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("ToolType") == "Gun" then
            return tool
        end
    end
    return nil
end

local CachedBulletsLabel = nil
local function UpdateAmmoGUI(ammo, maxAmmo)
    pcall(function()
        if not CachedBulletsLabel or not CachedBulletsLabel.Parent then
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if not playerGui then return end
            local home = playerGui:FindFirstChild("Home")
            if not home then return end
            local hud = home:FindFirstChild("hud")
            if not hud then return end
            local gunFrame = hud:FindFirstChild("BottomRightFrame") and hud.BottomRightFrame:FindFirstChild("GunFrame")
            if not gunFrame then return end
            CachedBulletsLabel = gunFrame:FindFirstChild("BulletsLabel")
        end

        if CachedBulletsLabel then
            CachedBulletsLabel.Text = ammo .. "/" .. maxAmmo
        end
    end)
end

-- ==================== OBTÉM O REMOTE DA ARMA ====================
local function GetShootRemote(tool)
    -- Procura por um RemoteEvent ou RemoteFunction dentro da ferramenta
    return tool:FindFirstChild("ShootEvent") or tool:FindFirstChild("Shoot") or tool:FindFirstChild("Remote") or tool:FindFirstChildOfClass("RemoteEvent") or tool:FindFirstChildOfClass("RemoteFunction")
end

-- ==================== DISPARO SILENCIOSO CORRIGIDO ====================
local GunRemotes = ReplicatedStorage:FindFirstChild("GunRemotes")
local ShootEvent = GunRemotes and GunRemotes:FindFirstChild("ShootEvent")
if not ShootEvent then
    warn("ShootEvent global não encontrado. Usando remote da arma.")
end

local function FireSilentAim(gun)
    local ammo = gun:GetAttribute("Local_CurrentAmmo") or 0
    if ammo <= 0 then return false end

    local fireRate = gun:GetAttribute("FireRate") or 0.12
    local now = tick()
    if now - LastShot < fireRate then return false end

    local char = LocalPlayer.Character
    local myHead = char and char:FindFirstChild("Head")
    if not myHead then return false end

    local hitPos, hitPart

    if Settings.Enabled and CurrentTarget and CurrentTarget.Character and IsValidTargetFull(CurrentTarget) then
        local targetPart = GetTargetPart(CurrentTarget.Character)
        if targetPart then
            if RollHitChance() then
                hitPos = targetPart.Position
                hitPart = targetPart
            else
                hitPos = GetMissPosition(targetPart.Position)
                hitPart = nil
            end
        end
    end

    if not hitPos then
        local mousePos = UserInputService:GetMouseLocation()
        local camera = workspace.CurrentCamera
        local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

        WallCheckParams.FilterDescendantsInstances = {char}
        local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, WallCheckParams)

        if result then
            hitPos = result.Position
            hitPart = result.Instance
        else
            hitPos = ray.Origin + (ray.Direction * 1000)
        end
    end

    gun:SetAttribute("Local_IsShooting", true)

    local muzzle = gun:FindFirstChild("Muzzle")
    local visualStart = muzzle and muzzle.Position or myHead.Position

    local projectileCount = gun:GetAttribute("ProjectileCount") or 1
    local bullets = table.create(projectileCount)
    for i = 1, projectileCount do
        bullets[i] = { myHead.Position, hitPos, hitPart }
    end

    LastShot = now
    PlayGunSound(gun)

    for i = 1, projectileCount do
        local ox = math.random(-10, 10) / 100
        local oy = math.random(-10, 10) / 100
        local oz = math.random(-10, 10) / 100
        CreateProjectileTracer(visualStart, hitPos + Vector3.new(ox, oy, oz), gun)
    end

    -- Tenta usar o remote da própria arma primeiro
    local remote = GetShootRemote(gun)
    if not remote then
        remote = ShootEvent -- fallback global
    end

    if remote then
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(bullets)
        else
            remote:FireServer(bullets)
        end
    else
        warn("Nenhum remote de tiro encontrado para a arma.")
        return false
    end

    local newAmmo = ammo - 1
    gun:SetAttribute("Local_CurrentAmmo", newAmmo)
    UpdateAmmoGUI(newAmmo, gun:GetAttribute("MaxAmmo") or 0)

    return true
end

-- ==================== CONTEXTO DE AÇÃO (CLIQUE) ====================
local function HandleAction(actionName, inputState, inputObject)
    if actionName == "SilentAimShoot" then
        if inputState == Enum.UserInputState.Begin then
            local gun = GetEquippedGun()
            if not gun then 
                return Enum.ContextActionResult.Pass 
            end

            if not gun:GetAttribute("AutoFire") then
                IsShooting = true
                FireSilentAim(gun)
                IsShooting = false
            else
                IsShooting = true
            end

            return Enum.ContextActionResult.Sink
        elseif inputState == Enum.UserInputState.End then
            IsShooting = false
            return Enum.ContextActionResult.Sink
        end
    end
    return Enum.ContextActionResult.Pass
end

pcall(function()
    if IsMobile then
        ContextActionService:BindActionAtPriority("SilentAimShoot", HandleAction, false, 3000, Enum.UserInputType.Touch)
    else
        ContextActionService:BindActionAtPriority("SilentAimShoot", HandleAction, false, 3000, Enum.UserInputType.MouseButton1)
    end
end)

if IsMobile then
    UISettings.Visible = false
end

-- ==================== INPUT DE TECLADO ====================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not IsMobile and input.KeyCode == UISettings.ToggleUIKey then
        ToggleUI()
    end

    if input.KeyCode == Settings.ToggleKey then
        Settings.Enabled = not Settings.Enabled
        Notify("JG SilentAim", "Aimbot: " .. (Settings.Enabled and "ON" or "OFF"))
    end
end)

-- ==================== RENDER STEP ====================
RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()

    if Visuals.Circle then
        Visuals.Circle.Visible = Settings.ShowFOV and Settings.Enabled
        if Visuals.Circle.Visible then
            Visuals.Circle.Size = UDim2.new(0, Settings.FOV * 2, 0, Settings.FOV * 2)
            if IsMobile then
                Visuals.Circle.Position = UDim2.new(0.5, 0, 0.5, 0)
            else
                Visuals.Circle.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
            end
        end
    end

    local now = tick()
    if Settings.Enabled and (now - LastTargetUpdate) >= TARGET_UPDATE_INTERVAL then
        LastTargetUpdate = now
        CurrentTarget = GetClosestTarget()
    elseif not Settings.Enabled then
        CurrentTarget = nil
    end

    if Visuals.Line then
        local shouldShow = Settings.ShowTargetLine and Settings.Enabled and CurrentTarget and CurrentTarget.Character
        Visuals.Line.Visible = shouldShow

        if shouldShow then
            local targetPart = GetTargetPart(CurrentTarget.Character)
            if targetPart then
                local camera = workspace.CurrentCamera
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)

                if onScreen then
                    local startPos = mousePos
                    local endPos = Vector2.new(screenPos.X, screenPos.Y)
                    local distance = (endPos - startPos).Magnitude
                    local center = (startPos + endPos) / 2
                    local rotation = math.atan2(endPos.Y - startPos.Y, endPos.X - startPos.X)

                    Visuals.Line.Size = UDim2.new(0, distance, 0, 2)
                    Visuals.Line.Position = UDim2.new(0, center.X, 0, center.Y)
                    Visuals.Line.Rotation = math.deg(rotation)
                else
                    Visuals.Line.Visible = false
                end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not IsShooting then return end
    local gun = GetEquippedGun()
    if gun and gun:GetAttribute("AutoFire") then
        FireSilentAim(gun)
    end
end)

-- ==================== EVENTOS DE PERSONAGEM ====================
LocalPlayer.CharacterAdded:Connect(function()
    CachedBulletsLabel = nil
    CurrentTarget = nil
    IsShooting = false

    for key, sound in pairs(ActiveSounds) do
        if sound and sound.Parent then
            sound:Destroy()
        end
    end
    table.clear(ActiveSounds)
end)

LocalPlayer.CharacterAdded:Connect(hookCharacterWeaponMods)
if LocalPlayer.Character then hookCharacterWeaponMods(LocalPlayer.Character) end

backpack.ChildAdded:Connect(function(child)
    if child:IsA("Tool") then
        task.wait(0.1)
        applyRapidFireToTool(child)
        applyFastReloadToTool(child)
    end
end)

-- ==================== INICIALIZAÇÃO FINAL ====================
CleanupExistingUI()
CreateVisuals()
LoadSettings()
InitializeUI()

if IsMobile then
    Notify("JG SilentAim v2.0", "Carregado! Use o botão 'Toggle UI' para abrir/fechar a UI.")
else
    Notify("JG SilentAim v2.0", "Carregado! Pressione " .. GetKeyName(UISettings.ToggleUIKey) .. " para abrir/fechar a UI.")
end
