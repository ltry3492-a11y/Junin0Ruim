-- Roblox Script: Blob Puller with UI
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
local pullSpeed = 50 -- Velocidade padrão
local blobFolder = workspace:FindFirstChild("Blobs")

-- Criar UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BlobPullerUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 250, 0, 200)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "Blob Puller"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.Parent = MainFrame

-- Botão Minimizar
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 20, 0, 20)
MinBtn.Position = UDim2.new(1, -25, 0, 5)
MinBtn.Text = "-"
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
MinBtn.TextColor3 = Color3.new(1,1,1)
MinBtn.Parent = MainFrame

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame:TweenSize(UDim2.new(0, 250, 0, 30), "Out", "Quad", 0.3, true)
        MinBtn.Text = "+"
    else
        MainFrame:TweenSize(UDim2.new(0, 250, 0, 200), "Out", "Quad", 0.3, true)
        MinBtn.Text = "-"
    end
end)

-- Botão Ativar/Desativar
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 200, 0, 35)
ToggleBtn.Position = UDim2.new(0, 25, 0, 40)
ToggleBtn.Text = "Ativar"
ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleBtn.TextColor3 = Color3.new(1,1,1)
ToggleBtn.Font = Enum.Font.Gotham
ToggleBtn.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.Parent = ToggleBtn

ToggleBtn.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    if isEnabled then
        ToggleBtn.Text = "Desativar"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    else
        ToggleBtn.Text = "Ativar"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
end)

-- Ajuste de Velocidade
local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0, 200, 0, 20)
SpeedLabel.Position = UDim2.new(0, 25, 0, 85)
SpeedLabel.Text = "Velocidade: " .. pullSpeed
SpeedLabel.TextColor3 = Color3.new(1,1,1)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Parent = MainFrame

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(0, 200, 0, 30)
SpeedInput.Position = UDim2.new(0, 25, 0, 105)
SpeedInput.Text = tostring(pullSpeed)
SpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SpeedInput.TextColor3 = Color3.new(1,1,1)
SpeedInput.Parent = MainFrame

SpeedInput.FocusLost:Connect(function()
    local val = tonumber(SpeedInput.Text)
    if val then
        pullSpeed = val
        SpeedLabel.Text = "Velocidade: " .. pullSpeed
    else
        SpeedInput.Text = tostring(pullSpeed)
    end
end)

-- Botão Deletar Script
local DeleteBtn = Instance.new("TextButton")
DeleteBtn.Size = UDim2.new(0, 200, 0, 35)
DeleteBtn.Position = UDim2.new(0, 25, 0, 150)
DeleteBtn.Text = "Deletar & Parar"
DeleteBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
DeleteBtn.TextColor3 = Color3.new(1,1,1)
DeleteBtn.Parent = MainFrame

DeleteBtn.MouseButton1Click:Connect(function()
    isEnabled = false
    ScreenGui:Destroy()
end)

-- Lógica de Puxar
RunService.Heartbeat:Connect(function(dt)
    if not isEnabled then return end
    
    blobFolder = workspace:FindFirstChild("Blobs")
    if not blobFolder then return end
    
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local blobs = blobFolder:GetChildren()
    
    -- Filtrar apenas parts com nomes numéricos e ordenar decrescente
    local sortedBlobs = {}
    for _, b in ipairs(blobs) do
        if b:IsA("BasePart") and tonumber(b.Name) then
            table.insert(sortedBlobs, b)
        end
    end
    
    table.sort(sortedBlobs, function(a, b)
        return tonumber(a.Name) > tonumber(b.Name)
    end)

    -- Puxar as parts
    for _, blob in ipairs(sortedBlobs) do
        local direction = (root.Position - blob.Position).Unit
        local distance = (root.Position - blob.Position).Magnitude
        
        if distance > 2 then
            blob.CanCollide = false
            blob.Anchored = false
            blob.Velocity = direction * pullSpeed
        end
    end
end)
