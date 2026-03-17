-- Roblox Script: Part Puller Universal (Corrigido)
-- LocalScript (Colocar dentro de StarterGui ou usar via Executor)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Configurações Iniciais
local isEnabled = false
local pullSpeed = 50
local maxDistance = 300
local updateInterval = 0.05
local lastUpdate = 0
local targetFolder = nil -- Será definido pelo usuário
local folderName = "Blobs" -- Nome padrão da pasta
local pullMode = "folder" -- "folder" ou "all" (tudo ou pasta específica)

-- Criar UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PartPullerUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 300)
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "⚡ Part Puller Universal ⚡"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = MainFrame

-- Botão Minimizar
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 25, 0, 25)
MinBtn.Position = UDim2.new(1, -30, 0, 5)
MinBtn.Text = "−"
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
MinBtn.TextColor3 = Color3.new(1,1,1)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = MainFrame

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 5)
MinCorner.Parent = MinBtn

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame:TweenSize(UDim2.new(0, 280, 0, 40), "Out", "Quad", 0.3, true)
        MinBtn.Text = "+"
    else
        MainFrame:TweenSize(UDim2.new(0, 280, 0, 300), "Out", "Quad", 0.3, true)
        MinBtn.Text = "−"
    end
end)

-- Botão Ativar/Desativar
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 240, 0, 40)
ToggleBtn.Position = UDim2.new(0, 20, 0, 45)
ToggleBtn.Text = "🔴 ATIVAR"
ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleBtn.TextColor3 = Color3.new(1,1,1)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 16
ToggleBtn.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleBtn

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0, 240, 0, 20)
StatusLabel.Position = UDim2.new(0, 20, 0, 90)
StatusLabel.Text = "⏸️ Desativado | Modo: Pasta Específica"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.Parent = MainFrame

-- Seletor de Modo
local ModeLabel = Instance.new("TextLabel")
ModeLabel.Size = UDim2.new(0, 100, 0, 20)
ModeLabel.Position = UDim2.new(0, 20, 0, 115)
ModeLabel.Text = "Modo:"
ModeLabel.TextColor3 = Color3.new(1,1,1)
ModeLabel.BackgroundTransparency = 1
ModeLabel.Font = Enum.Font.GothamBold
ModeLabel.TextSize = 14
ModeLabel.Parent = MainFrame

local ModeBtn = Instance.new("TextButton")
ModeBtn.Size = UDim2.new(0, 120, 0, 25)
ModeBtn.Position = UDim2.new(0, 100, 0, 112)
ModeBtn.Text = "📁 Pasta"
ModeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
ModeBtn.TextColor3 = Color3.new(1,1,1)
ModeBtn.Font = Enum.Font.Gotham
ModeBtn.TextSize = 13
ModeBtn.Parent = MainFrame

local ModeCorner = Instance.new("UICorner")
ModeCorner.CornerRadius = UDim.new(0, 5)
ModeCorner.Parent = ModeBtn

ModeBtn.MouseButton1Click:Connect(function()
    if pullMode == "folder" then
        pullMode = "all"
        ModeBtn.Text = "🌍 Tudo"
        StatusLabel.Text = "⏸️ Desativado | Modo: Todas as Parts"
    else
        pullMode = "folder"
        ModeBtn.Text = "📁 Pasta"
        StatusLabel.Text = "⏸️ Desativado | Modo: Pasta Específica"
    end
end)

-- Nome da Pasta
local FolderLabel = Instance.new("TextLabel")
FolderLabel.Size = UDim2.new(0, 100, 0, 20)
FolderLabel.Position = UDim2.new(0, 20, 0, 145)
FolderLabel.Text = "Pasta:"
FolderLabel.TextColor3 = Color3.new(1,1,1)
FolderLabel.BackgroundTransparency = 1
FolderLabel.Font = Enum.Font.GothamBold
FolderLabel.TextSize = 14
FolderLabel.Parent = MainFrame

local FolderInput = Instance.new("TextBox")
FolderInput.Size = UDim2.new(0, 120, 0, 25)
FolderInput.Position = UDim2.new(0, 100, 0, 142)
FolderInput.Text = folderName
FolderInput.PlaceholderText = "Nome da pasta"
FolderInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
FolderInput.TextColor3 = Color3.new(1,1,1)
FolderInput.Font = Enum.Font.Gotham
FolderInput.TextSize = 13
FolderInput.Parent = MainFrame

local FolderCorner = Instance.new("UICorner")
FolderCorner.CornerRadius = UDim.new(0, 5)
FolderCorner.Parent = FolderInput

-- Velocidade
local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0, 100, 0, 20)
SpeedLabel.Position = UDim2.new(0, 20, 0, 175)
SpeedLabel.Text = "Velocidade:"
SpeedLabel.TextColor3 = Color3.new(1,1,1)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Font = Enum.Font.GothamBold
SpeedLabel.TextSize = 14
SpeedLabel.Parent = MainFrame

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(0, 120, 0, 25)
SpeedInput.Position = UDim2.new(0, 100, 0, 172)
SpeedInput.Text = tostring(pullSpeed)
SpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SpeedInput.TextColor3 = Color3.new(1,1,1)
SpeedInput.Font = Enum.Font.Gotham
SpeedInput.TextSize = 13
SpeedInput.Parent = MainFrame

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 5)
SpeedCorner.Parent = SpeedInput

-- Distância Máxima
local DistLabel = Instance.new("TextLabel")
DistLabel.Size = UDim2.new(0, 100, 0, 20)
DistLabel.Position = UDim2.new(0, 20, 0, 205)
DistLabel.Text = "Distância:"
DistLabel.TextColor3 = Color3.new(1,1,1)
DistLabel.BackgroundTransparency = 1
DistLabel.Font = Enum.Font.GothamBold
DistLabel.TextSize = 14
DistLabel.Parent = MainFrame

local DistInput = Instance.new("TextBox")
DistInput.Size = UDim2.new(0, 120, 0, 25)
DistInput.Position = UDim2.new(0, 100, 0, 202)
DistInput.Text = tostring(maxDistance)
DistInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
DistInput.TextColor3 = Color3.new(1,1,1)
DistInput.Font = Enum.Font.Gotham
DistInput.TextSize = 13
DistInput.Parent = MainFrame

local DistCorner = Instance.new("UICorner")
DistCorner.CornerRadius = UDim.new(0, 5)
DistCorner.Parent = DistInput

-- Botão Testar Pasta
local TestBtn = Instance.new("TextButton")
TestBtn.Size = UDim2.new(0, 240, 0, 30)
TestBtn.Position = UDim2.new(0, 20, 0, 235)
TestBtn.Text = "🔍 Testar/Listar Parts"
TestBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 200)
TestBtn.TextColor3 = Color3.new(1,1,1)
TestBtn.Font = Enum.Font.Gotham
TestBtn.TextSize = 13
TestBtn.Parent = MainFrame

local TestCorner = Instance.new("UICorner")
TestCorner.CornerRadius = UDim.new(0, 6)
TestCorner.Parent = TestBtn

-- Botão Deletar
local DeleteBtn = Instance.new("TextButton")
DeleteBtn.Size = UDim2.new(0, 240, 0, 30)
DeleteBtn.Position = UDim2.new(0, 20, 0, 270)
DeleteBtn.Text = "❌ Fechar Script"
DeleteBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
DeleteBtn.TextColor3 = Color3.new(1,1,1)
DeleteBtn.Font = Enum.Font.Gotham
DeleteBtn.TextSize = 13
DeleteBtn.Parent = MainFrame

local DeleteCorner = Instance.new("UICorner")
DeleteCorner.CornerRadius = UDim.new(0, 6)
DeleteCorner.Parent = DeleteBtn

-- Funções de Input
FolderInput.FocusLost:Connect(function()
    folderName = FolderInput.Text
    if folderName == "" then folderName = "Blobs" end
    FolderInput.Text = folderName
end)

SpeedInput.FocusLost:Connect(function()
    local val = tonumber(SpeedInput.Text)
    if val and val > 0 then
        pullSpeed = math.min(val, 1000)
        SpeedInput.Text = tostring(pullSpeed)
    else
        SpeedInput.Text = tostring(pullSpeed)
    end
end)

DistInput.FocusLost:Connect(function()
    local val = tonumber(DistInput.Text)
    if val and val > 0 then
        maxDistance = math.min(val, 1000)
        DistInput.Text = tostring(maxDistance)
    else
        DistInput.Text = tostring(maxDistance)
    end
end)

-- Função de Teste
TestBtn.MouseButton1Click:Connect(function()
    local count = 0
    local folder = workspace:FindFirstChild(folderName)
    
    if folder then
        for _, obj in ipairs(folder:GetChildren()) do
            if obj:IsA("BasePart") then
                count = count + 1
            end
        end
        StatusLabel.Text = "📊 Encontradas: " .. count .. " parts em '" .. folderName .. "'"
    else
        StatusLabel.Text = "❌ Pasta '" .. folderName .. "' não encontrada!"
    end
    
    -- Mudar cor temporariamente
    TestBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    task.wait(0.3)
    TestBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 200)
end)

-- Toggle Button
ToggleBtn.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    if isEnabled then
        ToggleBtn.Text = "🟢 DESATIVAR"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        StatusLabel.Text = "▶️ Ativado | " .. (pullMode == "folder" and "Pasta: "..folderName or "Todas Parts")
    else
        ToggleBtn.Text = "🔴 ATIVAR"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        StatusLabel.Text = "⏸️ Desativado | " .. (pullMode == "folder" and "Modo: Pasta" or "Modo: Todas Parts")
    end
end)

DeleteBtn.MouseButton1Click:Connect(function()
    isEnabled = false
    ScreenGui:Destroy()
end)

-- Lógica Principal OTIMIZADA
RunService.Heartbeat:Connect(function(dt)
    if not isEnabled then return end
    
    lastUpdate = lastUpdate + dt
    if lastUpdate < updateInterval then return end
    lastUpdate = 0
    
    -- Verificações
    local currentCharacter = player.Character
    if not currentCharacter then return end
    local currentRoot = currentCharacter:FindFirstChild("HumanoidRootPart")
    if not currentRoot then return end
    
    local rootPos = currentRoot.Position
    local partsToPull = {}
    
    -- Coletar parts baseado no modo
    if pullMode == "folder" then
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
                    local dist = (rootPos - obj.Position).Magnitude
                    if dist <= maxDistance and dist > 2 then
                        table.insert(partsToPull, obj)
                    end
                end
            end
        end
    else
        -- Modo "tudo" - pegar todas as parts soltas no workspace
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Parent ~= currentCharacter and obj.Name ~= "HumanoidRootPart" then
                if not obj.Anchored and obj:IsDescendantOf(workspace) then
                    local dist = (rootPos - obj.Position).Magnitude
                    if dist <= maxDistance and dist > 2 then
                        table.insert(partsToPull, obj)
                    end
                end
            end
        end
    end
    
    -- Aplicar força/puxar
    for i = 1, math.min(#partsToPull, 15) do
        local part = partsToPull[i]
        if part and part.Parent then
            pcall(function()
                local direction = (rootPos - part.Position).Unit
                part.CanCollide = false
                part.Anchored = false
                
                -- Aplicar velocidade suave
                local velocity = part.Velocity
                local targetVelocity = direction * pullSpeed
                part.Velocity = velocity:Lerp(targetVelocity, 0.3)
            end)
        end
    end
end)

-- Atualizar quando personagem renascer
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    rootPart = character:WaitForChild("HumanoidRootPart")
    wait(1)
    StatusLabel.Text = "🔄 Personagem atualizado!"
end)

print("✅ Part Puller Universal carregado! Use a interface para configurar.")
