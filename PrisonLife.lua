-- Script unificado e limpo: JG SilentAim v2.0
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

-- ==================== CONFIGURAÇÕES ====================
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

local UIComponents = { MainFrame = nil, TabButtons = {}, TabContents = {}, CloseButton = nil, ScreenGui = nil }

-- ==================== FUNÇÕES AUXILIARES ====================
local function Notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3,
        })
    end)
end
_G.Notify = Notify

local function ToggleUI()
    UISettings.Visible = not UISettings.Visible
    if UIComponents.MainFrame then
        UIComponents.MainFrame.Visible = UISettings.Visible
    end
    if IsMobile and UIComponents.ScreenGui and UIComponents.ScreenGui:FindFirstChild("ToggleUIButton") then
        UIComponents.ScreenGui.ToggleUIButton.Visible = not UISettings.Visible
    end
    Notify("UI", UISettings.Visible and "Mostrada" or "Escondida")
end

-- ==================== INVISIBILIDADE ====================
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

local TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function SetInvisibility(enabled)
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not hrp then return end

    if enabled then
        if InvisibilityData.active then return end

        local pos = hrp.Position
        InvisibilityData.originalCF = hrp.CFrame

        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {character}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        local ray = workspace:Raycast(pos, Vector3.new(0, -500, 0), raycastParams)
        InvisibilityData.groundLevel = ray and ray.Position.Y or (pos.Y - 50)

        character.Archivable = true
        local clone = character:Clone()
        character.Archivable = false
        clone.Name = "MainCharacter_Clone"
        
        local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
        local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
        
        if not cloneHRP or not cloneHumanoid then
            if clone then clone:Destroy() end
            return
        end
        
        cloneHRP.CFrame = InvisibilityData.originalCF
        cloneHRP.Anchored = false
        cloneHRP.CanCollide = true

        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0.3
                part.CanCollide = true
            end
        end

        for _, script in ipairs(clone:GetDescendants()) do
            if (script:IsA("Script") or script:IsA("LocalScript")) and script.Name ~= "Animate" then
                script:Destroy()
            end
        end

        clone.Parent = workspace
        InvisibilityData.clone = clone

        InvisibilityData.newY = InvisibilityData.groundLevel - 25
        local targetCF = CFrame.new(pos.X, InvisibilityData.newY, pos.Z)
        
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        
        hrp.Anchored = true
        local entryTween = TweenService:Create(hrp, TWEEN_INFO, {CFrame = targetCF})
        entryTween:Play()

        humanoid.PlatformStand = true
        workspace.CurrentCamera.CameraSubject = cloneHumanoid

        InvisibilityData.connection = RunService.RenderStepped:Connect(function()
            if not InvisibilityData.active or not clone or not hrp then 
                if InvisibilityData.connection then InvisibilityData.connection:Disconnect() end
                return 
            end
            if not clone.Parent then return end
            local moveDirection = humanoid.MoveDirection
            cloneHumanoid:Move(moveDirection, false)
            cloneHumanoid.Jump = humanoid.Jump
            local clonePos = cloneHRP.Position
            hrp.CFrame = CFrame.new(clonePos.X, InvisibilityData.newY, clonePos.Z) * cloneHRP.CFrame.Rotation
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end)

        InvisibilityData.active = true
        Notify("Invisibilidade", "Ativada")
    else
        if InvisibilityData.connection then
            InvisibilityData.connection:Disconnect()
            InvisibilityData.connection = nil
        end
        local finalCFrame = nil
        if InvisibilityData.clone then
            local cloneHRP = InvisibilityData.clone:FindFirstChild("HumanoidRootPart")
            if cloneHRP then finalCFrame = cloneHRP.CFrame end
            InvisibilityData.clone:Destroy()
            InvisibilityData.clone = nil
        end
        if hrp and finalCFrame then
            local exitTween = TweenService:Create(hrp, TWEEN_INFO, {CFrame = finalCFrame})
            exitTween:Play()
            exitTween.Completed:Connect(function()
                hrp.Anchored = false
                humanoid.PlatformStand = false
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end)
        end
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
            workspace.CurrentCamera.CameraSubject = humanoid
        end
        InvisibilityData.active = false
        Notify("Invisibilidade", "Desativada")
    end
end
_G.SetInvisibility = SetInvisibility

-- ==================== SERIALIZAÇÃO ====================
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
            if enumType then loadedSettings[k] = enumType[v.Name] end
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

-- ==================== COMPONENTES DA UI ====================
local function GetKeyName(keyCode)
    local KeybindNames = {
        [Enum.KeyCode.Insert] = "INSERT", [Enum.KeyCode.Delete] = "DELETE", [Enum.KeyCode.Home] = "HOME",
        [Enum.KeyCode.End] = "END", [Enum.KeyCode.PageUp] = "PAGE UP", [Enum.KeyCode.PageDown] = "PAGE DOWN",
        [Enum.KeyCode.RightShift] = "RIGHT SHIFT", [Enum.KeyCode.LeftShift] = "LEFT SHIFT",
        [Enum.KeyCode.RightControl] = "RIGHT CTRL", [Enum.KeyCode.LeftControl] = "LEFT CTRL",
        [Enum.KeyCode.RightAlt] = "RIGHT ALT", [Enum.KeyCode.LeftAlt] = "LEFT ALT",
        [Enum.KeyCode.Tab] = "TAB", [Enum.KeyCode.CapsLock] = "CAPS LOCK",
    }
    return KeybindNames[keyCode] or keyCode.Name:upper()
end

local function MakeDraggable(frame, dragHandle)
    local dragging, dragInput, mousePos, framePos
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
    layout.Padding = UDim.new(0, 8)
    layout.Parent = content
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 5)
    padding.Parent = content
    return content
end

local function CreateToggle(parent, text, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 35)
    container.BackgroundTransparency = 1
    container.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 50, 0, 25)
    toggleBtn.Position = UDim2.new(1, -55, 0.5, -12.5)
    toggleBtn.BackgroundColor3 = defaultValue and Color3.fromRGB(70, 200, 70) or Color3.fromRGB(200, 70, 70)
    toggleBtn.Text = defaultValue and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = container
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = toggleBtn
    local isEnabled = defaultValue
    toggleBtn.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        toggleBtn.Text = isEnabled and "ON" or "OFF"
        toggleBtn.BackgroundColor3 = isEnabled and Color3.fromRGB(70, 200, 70) or Color3.fromRGB(200, 70, 70)
        callback(isEnabled)
    end)
    return container
end

local function CreateModernUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "JGSilentAimUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if IsMobile then
        local toggleButton = Instance.new("TextButton")
        toggleButton.Name = "ToggleUIButton"
        toggleButton.Size = UDim2.new(0, 80, 0, 30)
        toggleButton.Position = UDim2.new(1, -110, 0, 10)
        toggleButton.Text = "Toggle UI"
        toggleButton.Parent = sg
        toggleButton.MouseButton1Click:Connect(ToggleUI)
    end
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    UIComponents.ScreenGui = sg
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 520, 0, 420)
    mainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.Parent = sg
    mainFrame.Visible = UISettings.Visible
    UIComponents.MainFrame = mainFrame
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 45)
    header.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    header.Parent = mainFrame
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0, 6.5)
    closeBtn.Text = "✕"
    closeBtn.Parent = header
    UIComponents.CloseButton = closeBtn
    local tabContainer = Instance.new("ScrollingFrame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, -20, 0, 40)
    tabContainer.Position = UDim2.new(0, 10, 0, 55)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = mainFrame
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, -20, 1, -115)
    contentContainer.Position = UDim2.new(0, 10, 0, 100)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = mainFrame
    return sg, mainFrame, tabContainer, contentContainer
end

local function SwitchTab(tabName)
    UISettings.CurrentTab = tabName
    for name, content in pairs(UIComponents.TabContents) do
        content.Visible = (name == tabName)
    end
end

local function InitializeUI()
    local sg, mainFrame, tabContainer, contentContainer = CreateModernUI()
    local tabs = {"Main", "Aim", "Visuals", "ESP", "Weapon", "Player", "Teleport", "Settings"}
    for i, name in ipairs(tabs) do
        local btn = CreateTabButton(tabContainer, name, i)
        UIComponents.TabButtons[name] = btn
        local content = CreateTabContent(contentContainer, name)
        UIComponents.TabContents[name] = content
        btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
    end
    -- Aba Player
    local playerContent = UIComponents.TabContents["Player"]
    CreateToggle(playerContent, "Invisibility", Settings.InvisibilityEnabled, function(s) 
        Settings.InvisibilityEnabled = s
        _G.SetInvisibility(Settings.InvisibilityEnabled) 
    end)
    if UIComponents.CloseButton then
        UIComponents.CloseButton.MouseButton1Click:Connect(ToggleUI)
    end
    MakeDraggable(mainFrame, mainFrame:FindFirstChild("Header"))
    SwitchTab("Main")
end

-- ==================== INICIALIZAÇÃO FINAL ====================
InitializeUI()
Notify("JG SilentAim", "Carregado com sucesso!")
