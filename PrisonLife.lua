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

local function Notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3,
        })
    end)
end

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
    local jsonString = pcall(getclipboard)
    if not jsonString or type(jsonString) ~= "string" or #jsonString < 10 then
        Notify("Erro ao Carregar", "Nenhuma configuração válida encontrada na área de transferência.")
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

local UISettings = {
    Visible = true,
    ToggleUIKey = Enum.KeyCode.Insert,
    CurrentTab = "Main"
}

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

local WallCheckParams = RaycastParams.new()
WallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
WallCheckParams.IgnoreWater = true
WallCheckParams.RespectCanCollide = false

local Visuals = {
    Gui = nil,
    Circle = nil,
    Line = nil
}

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

local UIComponents = {
    MainFrame = nil,
    TabButtons = {},
    TabContents = {},
    CloseButton = nil,
    ScreenGui = nil
}

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

local function CleanupExistingUI()
    local existingCoreGui = CoreGui:FindFirstChild("JGSilentAimUI")
    if existingCoreGui then existingCoreGui:Destroy() end
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local existingPlayerGui = playerGui:FindFirstChild("JGSilentAimUI")
        if existingPlayerGui then existingPlayerGui:Destroy() end
    end
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
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            frame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

local function CreateModernUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "JGSilentAimUI"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    UIComponents.ScreenGui = sg
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 500, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = sg
    UIComponents.MainFrame = mainFrame
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(100, 100, 255)
    mainStroke.Thickness = 2
    mainStroke.Transparency = 0.5
    mainStroke.Parent = mainFrame
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "JG SilentAim v2.0"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header
    UIComponents.CloseButton = closeBtn
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 120, 1, -40)
    sidebar.Position = UDim2.new(0, 0, 0, 40)
    sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 10)
    sidebarCorner.Parent = sidebar
    local tabContainer = Instance.new("ScrollingFrame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, 0, 1, -10)
    tabContainer.Position = UDim2.new(0, 0, 0, 5)
    tabContainer.BackgroundTransparency = 1
    tabContainer.BorderSizePixel = 0
    tabContainer.ScrollBarThickness = 2
    tabContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 255)
    tabContainer.Parent = sidebar
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.Parent = tabContainer
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, -130, 1, -50)
    contentContainer.Position = UDim2.new(0, 125, 0, 45)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = mainFrame
    MakeDraggable(mainFrame, header)
    return sg, mainFrame, tabContainer, contentContainer
end

local function CreateTabButton(parent, name, order)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Tab"
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.LayoutOrder = order
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = btn
    return btn
end

local function CreateTabContent(parent, name)
    local frame = Instance.new("ScrollingFrame")
    frame.Name = name .. "Content"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ScrollBarThickness = 4
    frame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 255)
    frame.Parent = parent
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = frame
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = frame
    return frame
end

local function CreateToggle(parent, text, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 35)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    container.BorderSizePixel = 0
    container.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = container
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 40, 0, 20)
    toggleBtn.Position = UDim2.new(1, -50, 0.5, -10)
    toggleBtn.BackgroundColor3 = defaultValue and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(60, 60, 80)
    toggleBtn.Text = ""
    toggleBtn.Parent = container
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 16, 0, 16)
    circle.Position = defaultValue and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.Parent = toggleBtn
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = circle
    local enabled = defaultValue
    toggleBtn.MouseButton1Click:Connect(function()
        enabled = not enabled
        local targetPos = enabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local targetColor = enabled and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(60, 60, 80)
        TweenService:Create(circle, TweenInfo.new(0.2), {Position = targetPos}):Play()
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        callback(enabled)
    end)
    return container
end

local function CreateSlider(parent, text, min, max, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 50)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    container.BorderSizePixel = 0
    container.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = container
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 0, 25)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 50, 0, 25)
    valueLabel.Position = UDim2.new(1, -60, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultValue)
    valueLabel.TextColor3 = Color3.fromRGB(100, 100, 255)
    valueLabel.TextSize = 14
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container
    local sliderBack = Instance.new("Frame")
    sliderBack.Size = UDim2.new(1, -20, 0, 6)
    sliderBack.Position = UDim2.new(0, 10, 1, -15)
    sliderBack.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sliderBack.BorderSizePixel = 0
    sliderBack.Parent = container
    local sliderBackCorner = Instance.new("UICorner")
    sliderBackCorner.CornerRadius = UDim.new(0, 3)
    sliderBackCorner.Parent = sliderBack
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((defaultValue - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(input) end
    end)
    return container
end

local function CreateDropdown(parent, text, options, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 30)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    container.BorderSizePixel = 0
    container.Parent = parent
    container.ClipsDescendants = false
    container.ZIndex = 1
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = container
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, -10, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
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
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.Text = defaultValue .. " ▼"
    dropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownBtn.TextSize = 12
    dropdownBtn.Font = Enum.Font.Gotham
    dropdownBtn.ZIndex = 2
    dropdownBtn.Parent = container
    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 5)
    dropdownCorner.Parent = dropdownBtn
    local dropdownList = Instance.new("Frame")
    dropdownList.Size = UDim2.new(0, 230, 0, math.min(#options * 25, 150))
    dropdownList.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    dropdownList.BorderSizePixel = 0
    dropdownList.Visible = false
    dropdownList.ZIndex = 100
    dropdownList.Parent = UIComponents.ScreenGui
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 5)
    listCorner.Parent = dropdownList
    local listStroke = Instance.new("UIStroke")
    listStroke.Color = Color3.fromRGB(100, 100, 255)
    listStroke.Thickness = 1
    listStroke.Parent = dropdownList
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 255)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #options * 25)
    scrollFrame.ZIndex = 101
    scrollFrame.Parent = dropdownList
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollFrame
    for i, option in ipairs(options) do
        local optionBtn = Instance.new("TextButton")
        optionBtn.Size = UDim2.new(1, 0, 0, 25)
        optionBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        optionBtn.BorderSizePixel = 0
        optionBtn.Text = option
        optionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        optionBtn.TextSize = 12
        optionBtn.Font = Enum.Font.Gotham
        optionBtn.LayoutOrder = i
        optionBtn.ZIndex = 102
        optionBtn.Parent = scrollFrame
        optionBtn.MouseEnter:Connect(function() optionBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80) end)
        optionBtn.MouseLeave:Connect(function() optionBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55) end)
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
                if mousePos.X < listPos.X or mousePos.X > listPos.X + listSize.X or mousePos.Y < listPos.Y or mousePos.Y > listPos.Y + listSize.Y then
                    if not (mousePos.X >= dropdownBtn.AbsolutePosition.X and mousePos.X <= dropdownBtn.AbsolutePosition.X + dropdownBtn.AbsoluteSize.X and mousePos.Y >= dropdownBtn.AbsolutePosition.Y and mousePos.Y <= dropdownBtn.AbsolutePosition.Y + dropdownBtn.AbsoluteSize.Y) then
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
    container.Size = UDim2.new(1, 0, 0, 30)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    container.BorderSizePixel = 0
    container.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = container
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, -10, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
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
    keybindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    keybindBtn.BorderSizePixel = 0
    keybindBtn.Text = GetKeyName(defaultKey)
    keybindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindBtn.TextSize = 12
    keybindBtn.Font = Enum.Font.GothamBold
    keybindBtn.Parent = container
    local keybindCorner = Instance.new("UICorner")
    keybindCorner.CornerRadius = UDim.new(0, 5)
    keybindCorner.Parent = keybindBtn
    local listening = false
    local connection
    keybindBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        keybindBtn.Text = "..."
        keybindBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
        connection = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local newKey = input.KeyCode
                keybindBtn.Text = GetKeyName(newKey)
                keybindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
                listening = false
                callback(newKey)
                connection:Disconnect()
            end
        end)
    end)
    return container
end

local function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = btn
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(60, 60, 85) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(45, 45, 65) end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function SwitchTab(name)
    for tabName, content in pairs(UIComponents.TabContents) do content.Visible = (tabName == name) end
    for tabName, button in pairs(UIComponents.TabButtons) do
        if tabName == name then
            button.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            button.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            button.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
    UISettings.CurrentTab = name
end

local function ToggleUI()
    UISettings.Visible = not UISettings.Visible
    if UIComponents.ScreenGui then UIComponents.ScreenGui.Enabled = UISettings.Visible end
end

local function ClearESPForPlayer(plr)
    local data = ESPHighlights[plr]
    if data then
        if data.highlight then data.highlight:Destroy() end
        if data.billboard then data.billboard:Destroy() end
        for _, conn in pairs(data.conns) do conn:Disconnect() end
        ESPHighlights[plr] = nil
    end
end

local function ApplyESPToPlayer(plr)
    if plr == LocalPlayer then return end
    ClearESPForPlayer(plr)
    local data = { conns = {} }
    ESPHighlights[plr] = data
    local function attachESP(char)
        if not Settings.ESPEnabled then return end
        if not char then return end
        if data.highlight and data.highlight.Parent then data.highlight:Destroy() end
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
        if data.billboard then data.billboard:Destroy() end
        local head = char:WaitForChild("Head", 5)
        if head then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "JGSilentAim_ESP_Billboard"
            billboard.Adornee = head
            billboard.Size = UDim2.new(0, 200, 0, 50)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = head
            data.billboard = billboard
            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.TextColor3 = teamColor
            textLabel.TextStrokeTransparency = 0
            textLabel.TextSize = 12
            textLabel.Font = Enum.Font.GothamBold
            textLabel.TextYAlignment = Enum.TextXAlignment.Top
            textLabel.Parent = billboard
            local function updateText()
                local inventory = {}
                for _, item in ipairs(char:GetChildren()) do if item:IsA("Tool") then table.insert(inventory, item.Name) end end
                local bp = plr:FindFirstChild("Backpack")
                if bp then for _, item in ipairs(bp:GetChildren()) do table.insert(inventory, item.Name) end end
                local invText = #inventory > 0 and table.concat(inventory, ", ") or "Vazio"
                textLabel.Text = string.format("%s\n[%s]", plr.Name, invText)
            end
            updateText()
            local bp = plr:WaitForChild("Backpack", 5)
            if bp then
                table.insert(data.conns, bp.ChildAdded:Connect(updateText))
                table.insert(data.conns, bp.ChildRemoved:Connect(updateText))
            end
            table.insert(data.conns, char.ChildAdded:Connect(updateText))
            table.insert(data.conns, char.ChildRemoved:Connect(updateText))
        end
    end
    if plr.Character then attachESP(plr.Character) end
    table.insert(data.conns, plr.CharacterAdded:Connect(function(char) task.wait(0.5) attachESP(char) end))
    table.insert(data.conns, plr:GetPropertyChangedSignal("Team"):Connect(function()
        if data.highlight then
            local teamColor = plr.Team and plr.Team.TeamColor.Color or Color3.fromRGB(255, 255, 255)
            data.highlight.FillColor = teamColor
            if data.billboard and data.billboard:FindFirstChildOfClass("TextLabel") then data.billboard:FindFirstChildOfClass("TextLabel").TextColor3 = teamColor end
        end
    end))
end

local function EnableESP()
    if Settings.ESPEnabled then return end
    Settings.ESPEnabled = true
    for _, plr in ipairs(Players:GetPlayers()) do ApplyESPToPlayer(plr) end
    ESPConnections.playerAdded = Players.PlayerAdded:Connect(ApplyESPToPlayer)
    ESPConnections.playerRemoving = Players.PlayerRemoving:Connect(ClearESPForPlayer)
end

local function DisableESP()
    if not Settings.ESPEnabled then return end
    Settings.ESPEnabled = false
    for plr, _ in pairs(ESPHighlights) do ClearESPForPlayer(plr) end
    if ESPConnections.playerAdded then ESPConnections.playerAdded:Disconnect() end
    if ESPConnections.playerRemoving then ESPConnections.playerRemoving:Disconnect() end
end

local function UpdateESPHighlightProperties()
    for plr, data in pairs(ESPHighlights) do
        if data.highlight then
            data.highlight.FillTransparency = Settings.ESPFillerTransparency
            data.highlight.OutlineColor = Settings.ESPOutlineColor
            data.highlight.DepthMode = Settings.ESPDepthMode
        end
    end
end

local function ensureRapidFireWatcher(tool)
    if RapidFireWatchers[tool] then return end
    RapidFireWatchers[tool] = tool:GetAttributeChangedSignal("FireRate"):Connect(function()
        if Settings.RapidFireEnabled then tool:SetAttribute("FireRate", 0) end
    end)
end

local function applyRapidFireToTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    local currentFireRate = tool:GetAttribute("FireRate")
    local currentAutoFire = tool:GetAttribute("AutoFire")
    if currentFireRate ~= nil and OriginalFireRate[tool] == nil then OriginalFireRate[tool] = currentFireRate end
    if currentAutoFire ~= nil and OriginalAutoFire[tool] == nil then OriginalAutoFire[tool] = currentAutoFire end
    if Settings.RapidFireEnabled then
        if currentFireRate ~= nil then tool:SetAttribute("FireRate", 0) end
        if currentAutoFire ~= nil then tool:SetAttribute("AutoFire", true) end
    else
        if OriginalFireRate[tool] ~= nil then tool:SetAttribute("FireRate", OriginalFireRate[tool]) end
        if OriginalAutoFire[tool] ~= nil then tool:SetAttribute("AutoFire", OriginalAutoFire[tool]) end
    end
    ensureRapidFireWatcher(tool)
end

local function scanRapidFire(character)
    character = character or LocalPlayer.Character
    if not character then return end
    for _, t in ipairs(character:GetChildren()) do if t:IsA("Tool") then applyRapidFireToTool(t) end end
    for _, t in ipairs(backpack:GetChildren()) do if t:IsA("Tool") then applyRapidFireToTool(t) end end
end

local function ensureFastReloadWatcher(tool)
    if FastReloadWatchers[tool] then return end
    FastReloadWatchers[tool] = tool:GetAttributeChangedSignal("ReloadTime"):Connect(function()
        if Settings.FastReloadEnabled then tool:SetAttribute("ReloadTime", 0) end
    end)
end

local function applyFastReloadToTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    local current = tool:GetAttribute("ReloadTime")
    if current ~= nil and OriginalReloadTime[tool] == nil then OriginalReloadTime[tool] = current end
    if Settings.FastReloadEnabled then
        if current ~= nil then tool:SetAttribute("ReloadTime", 0) end
    else
        if OriginalReloadTime[tool] ~= nil then tool:SetAttribute("ReloadTime", OriginalReloadTime[tool]) end
    end
    ensureFastReloadWatcher(tool)
end

local function scanFastReload(character)
    character = character or LocalPlayer.Character
    if not character then return end
    for _, t in ipairs(character:GetChildren()) do if t:IsA("Tool") then applyFastReloadToTool(t) end end
    for _, t in ipairs(backpack:GetChildren()) do if t:IsA("Tool") then applyFastReloadToTool(t) end end
end

local function ToggleRapidFire(enabled) Settings.RapidFireEnabled = enabled scanRapidFire() end
local function ToggleFastReload(enabled) Settings.FastReloadEnabled = enabled scanFastReload() end

local function hookCharacterWeaponMods(char)
    if not char then return end
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then task.wait(0.1) applyRapidFireToTool(child) applyFastReloadToTool(child) end
    end)
    scanRapidFire(char)
    scanFastReload(char)
end

local NoClipConnection
local function SetNoClip(enabled)
    if enabled then
        if NoClipConnection then NoClipConnection:Disconnect() end
        NoClipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide and part.Name ~= "HumanoidRootPart" then part.CanCollide = false end end end
        end)
    else
        if NoClipConnection then NoClipConnection:Disconnect() end
    end
end

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

local function TeleportToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if targetHRP then Teleport(targetHRP.Position + Vector3.new(0, 5, 0)) end
end

local function TeleportToCriminalBase() Teleport(Vector3.new(-959.8, 94.1, 2071.3)) end
local function TeleportToPrison() Teleport(Vector3.new(726.4, 122.0, 2586.0)) end

local WeaponCoords = {
    AK47 = Vector3.new(-931.6133422851562, 94.30853271484375, 2039.3065185546875),
    Shotgun = Vector3.new(-939.02734375, 94.30851745605469, 2039.1881103515625),
    MP5 = Vector3.new(813.7302856445312, 100.79533386230469, 2229.611572265625),
    Sniper = Vector3.new(836.1853637695312, 100.73533630371094, 2229.324951171875),
    M4A1 = Vector3.new(847.6981201171875, 100.79533386230469, 2229.6552734375)
}

local function GetWeaponAndReturn(weaponName)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local oldPos = hrp.Position
    Teleport(WeaponCoords[weaponName])
    task.wait(0.5)
    Teleport(oldPos)
end

local PortalCooldown = false
local function CreatePortalSystem()
    local posPrison = Vector3.new(847.6981201171875, 100.79533386230469, 2229.6552734375)
    local posCrimBase = Vector3.new(-966.4553833007812, 94.12886047363281, 2080.625)
    local function createPart(pos, name, targetPos)
        local part = Instance.new("Part")
        part.Name = name
        part.Position = pos
        part.Size = Vector3.new(5, 8, 1)
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 0.5
        part.Color = Color3.fromRGB(100, 100, 255)
        part.Material = Enum.Material.Neon
        part.Parent = game.Workspace
        local selection = Instance.new("SelectionBox")
        selection.Adornee = part
        selection.Color3 = Color3.fromRGB(255, 255, 255)
        selection.Parent = part
        part.Touched:Connect(function(hit)
            if PortalCooldown then return end
            local char = hit.Parent
            if char and char == LocalPlayer.Character then
                PortalCooldown = true
                Teleport(targetPos + Vector3.new(0, 2, 0))
                Notify("Portal", "Teleportado!")
                task.wait(3)
                PortalCooldown = false
            end
        end)
        return part
    end
    local oldP1 = game.Workspace:FindFirstChild("Portal_Prisao")
    local oldP2 = game.Workspace:FindFirstChild("Portal_BaseCrim")
    if oldP1 then oldP1:Destroy() end
    if oldP2 then oldP2:Destroy() end
    createPart(posPrison, "Portal_Prisao", posCrimBase)
    createPart(posCrimBase, "Portal_BaseCrim", posPrison)
    Notify("Portais Criados", "Portais ativos na Prisão e Base Criminosa.")
end

local ArrestPlayer = ReplicatedStorage:WaitForChild("Remotes", 10) and ReplicatedStorage.Remotes:WaitForChild("ArrestPlayer", 10)
local ARREST_COOLDOWN = 1
local LastArrestAttempt = {}
local AutoArrestConnection = nil

local function AutoArrestLoop()
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not humanoidRootPart or humanoid.Health <= 0 then return end
    local currentTime = tick()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetCharacter = player.Character
            local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
            local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
            if targetHumanoid and targetHRP and targetHumanoid.Health > 0 then
                local distance = (humanoidRootPart.Position - targetHRP.Position).magnitude
                if LocalPlayer.Team and LocalPlayer.Team.Name == "Guards" then
                    if player.Team and (player.Team.Name == "Criminals" or player.Team.Name == "Inmates") then
                        if distance <= 15 then
                            if ArrestPlayer and (not LastArrestAttempt[player] or (currentTime - LastArrestAttempt[player]) > ARREST_COOLDOWN) then
                                pcall(function() ArrestPlayer:InvokeServer(player) end)
                                LastArrestAttempt[player] = currentTime
                            end
                        end
                    end
                end
            end
        end
    end
end

local function ToggleAutoArrest(enabled)
    Settings.AutoArrestEnabled = enabled
    if enabled then
        if not AutoArrestConnection then AutoArrestConnection = RunService.Stepped:Connect(AutoArrestLoop) end
    else
        if AutoArrestConnection then AutoArrestConnection:Disconnect() AutoArrestConnection = nil end
    end
end

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
        tabBtn.MouseButton1Click:Connect(function() SwitchTab(tab.name) end)
    end
    
    local mainContent = UIComponents.TabContents["Main"]
    CreateToggle(mainContent, "Aimbot Enabled", Settings.Enabled, function(v) Settings.Enabled = v end)
    CreateToggle(mainContent, "Team Check", Settings.TeamCheck, function(v) Settings.TeamCheck = v end)
    CreateToggle(mainContent, "Wall Check", Settings.WallCheck, function(v) Settings.WallCheck = v end)
    CreateToggle(mainContent, "Death Check", Settings.DeathCheck, function(v) Settings.DeathCheck = v end)
    CreateToggle(mainContent, "ForceField Check", Settings.ForceFieldCheck, function(v) Settings.ForceFieldCheck = v end)
    
    local aimContent = UIComponents.TabContents["Aim"]
    CreateSlider(aimContent, "Hit Chance (%)", 0, 100, Settings.HitChance, function(v) Settings.HitChance = v end)
    CreateSlider(aimContent, "Miss Spread", 0, 20, Settings.MissSpread, function(v) Settings.MissSpread = v end)
    CreateSlider(aimContent, "FOV Radius", 50, 500, Settings.FOV, function(v) Settings.FOV = v end)
    CreateDropdown(aimContent, "Aim Part", Settings.AimPartsList, Settings.AimPart, function(v) Settings.AimPart = v end)
    CreateToggle(aimContent, "Random Aim Parts", Settings.RandomAimParts, function(v) Settings.RandomAimParts = v end)
    
    local visualsContent = UIComponents.TabContents["Visuals"]
    CreateToggle(visualsContent, "Show FOV Circle", Settings.ShowFOV, function(v) Settings.ShowFOV = v end)
    CreateToggle(visualsContent, "Show Target Line", Settings.ShowTargetLine, function(v) Settings.ShowTargetLine = v end)
    
    local espContent = UIComponents.TabContents["ESP"]
    CreateToggle(espContent, "ESP Enabled", Settings.ESPEnabled, function(v) if v then EnableESP() else DisableESP() end end)
    CreateSlider(espContent, "Fill Transparency", 0, 100, Settings.ESPFillerTransparency * 100, function(v) Settings.ESPFillerTransparency = v / 100 UpdateESPHighlightProperties() end)
    CreateDropdown(espContent, "Depth Mode", {"AlwaysOnTop", "Occluded"}, Settings.ESPDepthMode.Name, function(v) Settings.ESPDepthMode = Enum.HighlightDepthMode[v] UpdateESPHighlightProperties() end)
    
    local weaponContent = UIComponents.TabContents["Weapon"]
    CreateToggle(weaponContent, "Rapid Fire", Settings.RapidFireEnabled, ToggleRapidFire)
    CreateToggle(weaponContent, "Fast Reload", Settings.FastReloadEnabled, ToggleFastReload)
    
    local playerContent = UIComponents.TabContents["Player"]
    CreateToggle(playerContent, "NoClip", Settings.NoClipEnabled, function(v) Settings.NoClipEnabled = v SetNoClip(v) end)
    CreateToggle(playerContent, "Auto Arrest", Settings.AutoArrestEnabled, ToggleAutoArrest)
    CreateToggle(playerContent, "Anti-Taser", Settings.AntiTaserEnabled, ToggleAntiTaser)
    
    local teleportContent = UIComponents.TabContents["Teleport"]
    CreateButton(teleportContent, "TP para Base Criminosos", TeleportToCriminalBase)
    CreateButton(teleportContent, "TP para Prisão", TeleportToPrison)
    CreateButton(teleportContent, "Portal Base Criminosos (Criar)", CreatePortalSystem)
    local weaponTitle = Instance.new("TextLabel")
    weaponTitle.Size = UDim2.new(1, 0, 0, 25)
    weaponTitle.BackgroundTransparency = 1
    weaponTitle.Text = "--- Pegar Armas (TP & Voltar) ---"
    weaponTitle.TextColor3 = Color3.fromRGB(150, 150, 255)
    weaponTitle.Font = Enum.Font.GothamBold
    weaponTitle.Parent = teleportContent
    CreateButton(teleportContent, "Pegar AK-47", function() GetWeaponAndReturn("AK47") end)
    CreateButton(teleportContent, "Pegar Shotgun", function() GetWeaponAndReturn("Shotgun") end)
    CreateButton(teleportContent, "Pegar MP5", function() GetWeaponAndReturn("MP5") end)
    CreateButton(teleportContent, "Pegar Sniper (Gamepass)", function() GetWeaponAndReturn("Sniper") end)
    CreateButton(teleportContent, "Pegar M4A1 (Gamepass)", function() GetWeaponAndReturn("M4A1") end)
    
    local settingsContent = UIComponents.TabContents["Settings"]
    CreateKeybindSelector(settingsContent, "Menu Key", UISettings.ToggleUIKey, function(v) UISettings.ToggleUIKey = v end)
    CreateKeybindSelector(settingsContent, "Aimbot Toggle Key", Settings.ToggleKey, function(v) Settings.ToggleKey = v end)
    CreateButton(settingsContent, "Save Settings", SaveSettings)
    CreateButton(settingsContent, "Load Settings", LoadSettings)
    
    SwitchTab("Main")
end

local function CreateVisuals()
    local sg = Instance.new("ScreenGui")
    sg.Name = "JGSilentAimVisuals"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
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

local TracerPool = { bullets = {}, tasers = {}, maxPoolSize = 20 }
local function GetPooledPart(pool, createFunc)
    for i, part in ipairs(pool) do if not part.Parent then return table.remove(pool, i) end end
    return createFunc()
end
local function ReturnToPool(pool, part)
    part.Parent = nil
    if #pool < TracerPool.maxPoolSize then table.insert(pool, part) else part:Destroy() end
end
local function CreateBaseBulletPart()
    local bullet = Instance.new("Part")
    bullet.Anchored = true
    bullet.CanCollide = false
    bullet.Material = Enum.Material.Neon
    bullet.BrickColor = BrickColor.Yellow()
    Instance.new("BlockMesh", bullet).Scale = Vector3.new(0.5, 0.5, 1)
    return bullet
end
local function CreateBaseTaserPart()
    local bullet = Instance.new("Part")
    bullet.Anchored = true
    bullet.CanCollide = false
    bullet.Material = Enum.Material.Neon
    bullet.BrickColor = BrickColor.new("Cyan")
    Instance.new("BlockMesh", bullet).Scale = Vector3.new(0.8, 0.8, 1)
    return bullet
end

local function GetBodyPart(character, partName)
    if not character then return nil end
    local directPart = character:FindFirstChild(partName)
    if directPart then return directPart end
    local mappings = { ["Torso"] = {"Torso", "UpperTorso", "LowerTorso"}, ["LeftArm"] = {"Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand"}, ["RightArm"] = {"Right Arm", "RightUpperArm", "RightLowerArm", "RightHand"}, ["LeftLeg"] = {"Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"}, ["RightLeg"] = {"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"} }
    local m = mappings[partName]
    if m then for _, name in ipairs(m) do local p = character:FindFirstChild(name) if p then return p end end end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
end

local function GetTargetPart(character)
    if not character then return nil end
    local partName = Settings.RandomAimParts and Settings.AimPartsList[math.random(1, #Settings.AimPartsList)] or Settings.AimPart
    return GetBodyPart(character, partName)
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
    if Settings.Enabled and CurrentTarget and CurrentTarget.Character then
        local targetPart = GetTargetPart(CurrentTarget.Character)
        if targetPart then
            if math.random(1, 100) <= Settings.HitChance then hitPos = targetPart.Position hitPart = targetPart
            else hitPos = targetPart.Position + Vector3.new(math.random(-1,1), math.random(-1,1), math.random(-1,1)) * Settings.MissSpread end
        end
    end
    if not hitPos then
        local mousePos = UserInputService:GetMouseLocation()
        local camera = workspace.CurrentCamera
        local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * 1000)
        hitPos = result and result.Position or ray.Origin + (ray.Direction * 1000)
    end
    gun:SetAttribute("Local_IsShooting", true)
    local muzzle = gun:FindFirstChild("Muzzle")
    local visualStart = muzzle and muzzle.Position or myHead.Position
    local projectileCount = gun:GetAttribute("ProjectileCount") or 1
    local bullets = table.create(projectileCount)
    for i = 1, projectileCount do bullets[i] = { myHead.Position, hitPos, hitPart } end
    LastShot = now
    ShootEvent:FireServer(bullets)
    local newAmmo = ammo - 1
    gun:SetAttribute("Local_CurrentAmmo", newAmmo)
    return true
end

local function HandleAction(actionName, inputState, inputObject)
    if actionName == "SilentAimShoot" then
        if inputState == Enum.UserInputState.Begin then
            local gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if gun and gun:GetAttribute("ToolType") == "Gun" then
                if not gun:GetAttribute("AutoFire") then FireSilentAim(gun) else IsShooting = true end
                return Enum.ContextActionResult.Sink
            end
        elseif inputState == Enum.UserInputState.End then IsShooting = false return Enum.ContextActionResult.Sink end
    end
    return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority("SilentAimShoot", HandleAction, false, 3000, Enum.UserInputType.MouseButton1)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == UISettings.ToggleUIKey then ToggleUI() end
    if input.KeyCode == Settings.ToggleKey then Settings.Enabled = not Settings.Enabled Notify("Aimbot", Settings.Enabled and "ON" or "OFF") end
end)

RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    if Visuals.Circle then
        Visuals.Circle.Visible = Settings.ShowFOV and Settings.Enabled
        if Visuals.Circle.Visible then
            Visuals.Circle.Size = UDim2.new(0, Settings.FOV * 2, 0, Settings.FOV * 2)
            Visuals.Circle.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
        end
    end
    if Settings.Enabled and (tick() - LastTargetUpdate) >= TARGET_UPDATE_INTERVAL then
        LastTargetUpdate = tick()
        local camera = workspace.CurrentCamera
        local closest, minDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
                if not Settings.TeamCheck or plr.Team ~= LocalPlayer.Team then
                    local targetPart = GetTargetPart(plr.Character)
                    if targetPart then
                        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if dist < minDist and dist <= Settings.FOV then minDist = dist closest = plr end
                        end
                    end
                end
            end
        end
        CurrentTarget = closest
    end
end)

RunService.Heartbeat:Connect(function()
    if IsShooting then
        local gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if gun and gun:GetAttribute("ToolType") == "Gun" and gun:GetAttribute("AutoFire") then FireSilentAim(gun) end
    end
end)

LocalPlayer.CharacterAdded:Connect(hookCharacterWeaponMods)
if LocalPlayer.Character then hookCharacterWeaponMods(LocalPlayer.Character) end
backpack.ChildAdded:Connect(function(child) if child:IsA("Tool") then task.wait(0.1) applyRapidFireToTool(child) applyFastReloadToTool(child) end end)

CleanupExistingUI()
CreateVisuals()
InitializeUI()
Notify("JG SilentAim", "Script Restaurado e Atualizado! Pressione INSERT.")
