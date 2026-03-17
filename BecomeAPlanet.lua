-- Roblox Script: Blob Puller with UI (Versão Otimizada)
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
local maxDistance = 200 -- Distância máxima para puxar
local updateInterval = 0.1 -- Intervalo de atualização em segundos
local lastUpdate = 0

-- Criar UI (mesmo código anterior até a lógica de puxar)
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
    if val and val > 0 then
        pullSpeed = math.min(val, 500) -- Limite máximo de velocidade
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

-- Lógica de Puxar OTIMIZADA
RunService.Heartbeat:Connect(function(dt)
    if not isEnabled then return end
    
    -- Controle de intervalo para não processar todos os frames
    lastUpdate = lastUpdate + dt
    if lastUpdate < updateInterval then return end
    lastUpdate = 0
    
    -- Verificações seguras
    local currentBlobFolder = workspace:FindFirstChild("Blobs")
    if not currentBlobFolder then return end
    
    local currentCharacter = player.Character
    if not currentCharacter then return end
    local currentRoot = currentCharacter:FindFirstChild("HumanoidRootPart")
    if not currentRoot then return end
    
    -- Cache da posição do root
    local rootPos = currentRoot.Position
    
    -- Pegar blobs válidos e dentro do alcance
    local validBlobs = {}
    local blobCount = 0
    
    for _, blob in ipairs(currentBlobFolder:GetChildren()) do
        if blob:IsA("BasePart") and tonumber(blob.Name) then
            local distance = (rootPos - blob.Position).Magnitude
            -- Só processar blobs dentro do alcance máximo
            if distance <= maxDistance then
                blobCount = blobCount + 1
                validBlobs[blobCount] = blob
            end
        end
    end
    
    -- Se não há blobs válidos, não processa
    if blobCount == 0 then return end
    
    -- Processar apenas um número limitado de blobs por vez para evitar travamentos
    local maxBlobsPerFrame = 10
    local processedCount = 0
    
    for i = 1, math.min(blobCount, maxBlobsPerFrame) do
        local blob = validBlobs[i]
        if blob and blob.Parent then -- Verifica se ainda existe
            local direction = (rootPos - blob.Position).Unit
            local distance = (rootPos - blob.Position).Magnitude
            
            if distance > 2 then
                -- Aplicar força gradual em vez de velocidade direta
                pcall(function()
                    blob.CanCollide = false
                    blob.Anchored = false
                    
                    -- Aplicar velocidade com limite
                    local newVelocity = direction * pullSpeed
                    blob.Velocity = newVelocity
                    
                    -- Opcional: Aplicar força adicional para movimento mais suave
                    local force = Instance.new("BodyVelocity")
                    force.MaxForce = Vector3.new(4000, 4000, 4000)
                    force.Velocity = newVelocity
                    force.Parent = blob
                    
                    -- Remover força após um tempo para não acumular
                    task.delay(0.5, function()
                        if force and force.Parent then
                            force:Destroy()
                        end
                    end)
                end)
            end
        end
        processedCount = processedCount + 1
    end
end)

-- Limpeza automática quando o personagem morre
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    rootPart = character:WaitForChild("HumanoidRootPart")
end)

print("Blob Puller UI carregado com sucesso!")
