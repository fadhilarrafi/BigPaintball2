local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local AIMBOT_FOV = 200
local AIMBOT_DELAY = 0
local PREDICTION_STEPS = 10

local highlights = {}
local validModels = {}

local espEnabled = false
local aimbotEnabled = false
local teleportActive = false  -- Controls teleportation functionality

local screenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
screenGui.Name = "AimbotEspGui"

-- Fluent UI Framework Setup
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Create the window with Fluent UI
local Window = Fluent:CreateWindow({
    Title = "BIG Paintball 2 OP Script",  -- Updated title
    SubTitle = "by piyoscript",  -- Updated subtitle
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Only one tab (Main) now, no Settings tab
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "rocket" })
}

-- Main Tab: Display Instructions
Tabs.Main:AddParagraph({
    Title = "Instructions",
    Content = "Toggle the Aimbot, ESP, and Kill ALL below."
})

-- Create status labels for Aimbot, ESP, and Teleportation
local function createStatusLabel(name, position, text)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Size = UDim2.new(0, 300, 0, 30)
    label.Position = position
    label.BackgroundTransparency = 0.3
    label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    label.BorderSizePixel = 0
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.7
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    label.Text = text
    label.Parent = screenGui
    return label
end

-- Create Labels for the Features
local aimbotLabel = createStatusLabel("AimbotStatus", UDim2.new(0, 10, 0, 10), "Aimbot: OFF")
local espLabel = createStatusLabel("ESPStatus", UDim2.new(0, 10, 0, 50), "ESP: OFF")
local teleportLabel = createStatusLabel("TeleportStatus", UDim2.new(0, 10, 0, 90), "Teleport: OFF")

-- Update GUI labels
local function updateGui()
    aimbotLabel.TextColor3 = aimbotEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    espLabel.TextColor3 = espEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    teleportLabel.TextColor3 = teleportActive and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end

-- Add Toggle for Aimbot in Main Tab
local aimbotToggle = Tabs.Main:AddToggle("AimbotToggle", {
    Title = "Enable Aimbot",
    Default = false,
    Description = "Enable the aimbot functionality."
})

aimbotToggle:OnChanged(function(enabled)
    aimbotEnabled = enabled
    aimbotLabel.Text = "Aimbot: " .. (enabled and "ON" or "OFF")
    updateGui()
end)

-- Add Toggle for ESP in Main Tab
local espToggle = Tabs.Main:AddToggle("ESPToggle", {
    Title = "Enable ESP",
    Default = false,
    Description = "Enable the ESP functionality."
})

espToggle:OnChanged(function(enabled)
    espEnabled = enabled
    espLabel.Text = "ESP: " .. (enabled and "ON" or "OFF")
    updateGui()
    for model, highlight in pairs(highlights) do
        if highlight then
            highlight.Enabled = espEnabled
        end
    end
end)

-- Add Toggle for Teleportation in Main Tab (Kill ALL)
local teleportToggle = Tabs.Main:AddToggle("TeleportToggle", {
    Title = "Enable Kill ALL",
    Default = false,
    Description = "Teleports Players in front of you, Just press shoot ! :D"
})

teleportToggle:OnChanged(function(enabled)
    teleportActive = enabled
    teleportLabel.Text = "Kill ALL: " .. (enabled and "ON" or "OFF")
    updateGui()
end)

-- Function to create highlights for models (for ESP)
local function createHighlightForModel(model)
    if highlights[model] or not espEnabled then return end
    if model and model:FindFirstChild("HumanoidRootPart") then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = model
        highlight.FillTransparency = 0.9
        highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = game.CoreGui
        highlights[model] = highlight
    end
end

-- Function to clean up invalid ESP highlights
local function cleanInvalid()
    for model, highlight in pairs(highlights) do
        if not model or not model:IsDescendantOf(Workspace) or not model:FindFirstChild("HumanoidRootPart") or not espEnabled then
            if highlight then
                highlight:Destroy()
            end
            highlights[model] = nil
            validModels[model] = nil
        end
    end
end

-- Loop through the models and add highlights if needed
task.spawn(function()
    while true do
        for _, model in pairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model ~= LocalPlayer.Character and model:FindFirstChild("HumanoidRootPart") then
                if not validModels[model] then
                    validModels[model] = true
                    createHighlightForModel(model)
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Aimbot logic to get nearest target and aim at it
local function getNearestTarget()
    local closestModel = nil
    local shortestDistance = AIMBOT_FOV
    local mouseLocation = UserInputService:GetMouseLocation()

    for model in pairs(validModels) do
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp then
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local velocity = hrp.Velocity
                local moveDirection = velocity.Magnitude > 0 and velocity.Unit or Vector3.zero
                local predictedPosition = hrp.Position

                for _ = 1, PREDICTION_STEPS do
                    predictedPosition = predictedPosition + moveDirection * AIMBOT_DELAY
                end

                predictedPosition += hrp.CFrame.LookVector * 5

                local predictedScreenPos, onScreenPredicted = Camera:WorldToViewportPoint(predictedPosition)
                if onScreenPredicted then
                    local dist = (Vector2.new(predictedScreenPos.X, predictedScreenPos.Y) - Vector2.new(mouseLocation.X, mouseLocation.Y)).Magnitude
                    if dist < shortestDistance then
                        shortestDistance = dist
                        closestModel = model
                    end
                end
            end
        end
    end
    return closestModel
end

-- Function to activate aimbot (lock camera on target)
RunService.RenderStepped:Connect(function()
    cleanInvalid()
    if aimbotEnabled and (UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then
        local target = getNearestTarget()
        if target and target:FindFirstChild("HumanoidRootPart") then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.HumanoidRootPart.Position)
        end
    end
end)

-- Teleportation Logic to move entities and players
local function teleportEntitiesToPosition(cframe, targetTeam)
    local targetPosition = cframe * CFrame.new(0, 0, -15)

    -- Teleport entities
    for , entity in ipairs(Workspace.THINGS._ENTITIES:GetChildren()) do
        if entity:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = entity.HumanoidRootPart
            humanoidRootPart.CanCollide = false
            humanoidRootPart.Anchored = true
            humanoidRootPart.CFrame = targetPosition
        elseif entity:FindFirstChild("Hitbox") then
            local entityDir = entity:GetAttribute("Directory")
            if not (entityDir == "White" and entity:GetAttribute("OwnerUID") == LocalPlayer.UserId) and 
               (not targetTeam or entityDir ~= targetTeam.Name) then
                entity.Hitbox.CanCollide = false
                entity.Hitbox.Anchored = true
                entity.Hitbox.CFrame = targetPosition * CFrame.new(math.random(-5, 5), 0, math.random(-5, 5))
            end
        end
    end

    -- Teleport players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not targetTeam or targetTeam.Name ~= player.Team.Name then
                if not player.Character:FindFirstChild("ForceField") then
                    local humanoidRootPart = player.Character.HumanoidRootPart
                    humanoidRootPart.CanCollide = false
                    humanoidRootPart.Anchored = true
                    humanoidRootPart.CFrame = targetPosition * CFrame.new(math.random(-5, 5), 0, math.random(-5, 5))
                end
            end
        end
    end
end

while wait(0.1) do
    if teleportActive then
        -- Teleport when toggle is active
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local cframe = LocalPlayer.Character.HumanoidRootPart.CFrame
            local playerTeam = LocalPlayer.Team
            teleportEntitiesToPosition(cframe, playerTeam)
        end
    end
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/Settings")
InterfaceManager:BuildInterfaceSection(Tabs.Main)  -- Use Main Tab only now
SaveManager:BuildConfigSection(Tabs.Main)

-- Load Settings and Interface
Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

-- Debug messages for script lifecycle
print("Fluent UI Script Loaded!")