shared.Quco = {
    ['script_key'] = "",

    ['Key'] = {
        ['Silent'] = 'Q',
        ['Trigger Bot'] = 'T',
        ['Walk Speed'] = 'V',
        ['Aim Bot'] = 'C',
    },

    ['Target Mode'] = { ['Mode'] = 'Automatic' },
    ['Checks'] = { ['Grabbed'] = true, ['Knocked'] = true },

    ['Target Lines'] = { ['Enabled'] = true, ['Visible'] = true, ['Color'] = Color3.fromRGB(0, 255, 0) },

    ['Whitelisted'] = {
        ['Modifications'] = {
            ['Client Redirection'] = { ['[Double-Barrel SG]'] = true, ['[Revolver]'] = true, ['[TacticalShotgun]'] = true },
            ['Spread Modification'] = { ['[Double-Barrel SG]'] = true, ['[TacticalShotgun]'] = true }
        }
    },

    ['Feature'] = {
        ['Aimbot Assist'] = { ['Enabled'] = true, ['Smoothness'] = 0, ['Hit Part'] = 'HumanoidRootPart', ['Closest Point'] = {['Scale'] = 15}, ['Prediction'] = {['X'] = 0, ['Y'] = 0, ['Z'] = 0} },
        ['Silent'] = { ['Enabled'] = true, ['Hit Part'] = 'Closest Part', ['Nearest Point'] = {['Enabled'] = true, ['Visible'] = true, ['Scale'] = 5, ['Color'] = Color3.fromRGB(255,0,0)}, ['Prediction'] = {['X'] = 0, ['Y'] = 0, ['Z'] = 0} },
        ['Trigger Bot'] = { ['Enabled'] = true, ['Hit Part'] = 'HumanoidRootPart', ['Delay'] = 0, ['Prediction'] = {['X'] = 0, ['Y'] = 0, ['Z'] = 0}, ['Closest Point'] = {['Scale'] = 5} },
        ['Walk Speed'] = { ['Enabled'] = true, ['Speed'] = 300 }
    },

    ['Box'] = {
        ['Mode'] = { ['Trigger Bot'] = '2D', ['Silent'] = '2D', ['Aimbot Assist'] = '2D' },
        ['FOV'] = {
            ['Silent'] = {['X'] = 10, ['Y'] = 10, ['Z'] = 10},
            ['Trigger Bot'] = {['X'] = 10, ['Y'] = 10, ['Z'] = 10},
            ['Aimbot Assist'] = {['X'] = 10, ['Y'] = 10, ['Z'] = 10},
        }
    },

    ['Modifications'] = {
        ['Spread Modification'] = { ['Enabled'] = true, ['[Double-Barrel SG]'] = 0, ['[TacticalShotgun]'] = 0 },
        ['Client Redirection'] = { ['Enabled'] = true }
    },

    ['Visuals'] = { ['ESP'] = { ['Enabled'] = true, ['Color'] = Color3.fromRGB(255, 255, 255), ['Size'] = 2, ['Display'] = "Display" } }
}

local HttpService = game:GetService("HttpService")
local hwid = tostring(game:GetService("RbxAnalyticsService"):GetClientId())
local API_URL = "https://zonal-rejoicing.up.railway.app/validate"

local function ValidateKey()
    local key = shared.Quco['script_key']
    if key == "" then return false end
    local success,res = pcall(function()
        return HttpService:PostAsync(API_URL, HttpService:JSONEncode({key=key,hwid=hwid}),Enum.HttpContentType.ApplicationJson)
    end)
    if not success then return false end
    local data = HttpService:JSONDecode(res)
    return data.success == true
end
if not ValidateKey() then return end

local players, workspace, runservice, userinputservice = game:GetService("Players"), game.Workspace, game:GetService("RunService"), game:GetService("UserInputService")
local localplayer, camera, mouse = players.LocalPlayer, workspace.CurrentCamera, players.LocalPlayer:GetMouse()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.IgnoreWater = true

-- Spread Logic
local currentSpread = {}
for gunName, conf in pairs(shared.Quco.Modifications['Spread Modification']) do
    if type(conf) == "number" then currentSpread[gunName] = conf end
end
function ApplySpread(gunName, direction)
    local spreadVal = currentSpread[gunName] or 0
    local angle = math.rad(math.random(spreadVal * -100, spreadVal * 100) / 100)
    local spreadVector = CFrame.fromAxisAngle(Vector3.new(0,1,0), angle).LookVector
    return (direction + spreadVector).Unit
end

-- Visuals
local line = Drawing.new("Line")
line.Color, line.Thickness, line.Visible = shared.Quco['Target Lines']['Color'], 2, false
local nearestPoint = Drawing.new("Circle")
nearestPoint.Visible = false
nearestPoint.Thickness = 1
nearestPoint.Filled = false
nearestPoint.Radius = shared.Quco.Feature.Silent.NearestPoint.Scale
nearestPoint.Color = shared.Quco.Feature.Silent.NearestPoint.Color

-- Utility functions
local function isValidTarget(player)
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return false end
    if shared.Quco.Checks.Grabbed then
        local grabbed = player.Character:FindFirstChild("Grabbed")
        if grabbed and grabbed.Value then return false end
    end
    if shared.Quco.Checks.Knocked then
        local knocked = player.Character:FindFirstChild("Knocked")
        if knocked and knocked.Value then return false end
    end
    return true
end

local function GetClosestPlayer()
    local closest, dist = nil, math.huge
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localplayer and isValidTarget(player) then
            local hrp = player.Character.HumanoidRootPart
            local pos,onScreen = camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local d = (Vector2.new(pos.X,pos.Y)-Vector2.new(mouse.X,mouse.Y)).Magnitude
                if d < dist then dist=d closest=player end
            end
        end
    end
    return closest
end

local function GetClosestPart(target, mode)
    if not target or not target.Character then return end
    local bodyparts = {"Head","UpperTorso","LowerTorso","HumanoidRootPart","LeftHand","RightHand","LeftLowerArm","RightLowerArm","LeftUpperArm","RightUpperArm","LeftFoot","RightFoot","LeftLowerLeg","RightLowerLeg","LeftUpperLeg","RightUpperLeg"}
    local mousePos = Vector2.new(mouse.X, mouse.Y)
    local closestPart, closestPos, closestDist = nil, nil, math.huge
    local partsToCheck = mode == "Silent" and bodyparts or {shared.Quco.Feature[mode].HitPart}
    local fov = shared.Quco.Box.FOV[mode]

    for _, partName in ipairs(partsToCheck) do
        local part = target.Character:FindFirstChild(partName)
        if part then
            local pos,onScreen = camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dx, dy = math.abs(pos.X-mousePos.X), math.abs(pos.Y-mousePos.Y)
                local valid = dx <= fov.X and dy <= fov.Y
                if valid then
                    local d = (Vector2.new(pos.X,pos.Y)-mousePos).Magnitude
                    if d < closestDist then
                        closestDist = d
                        closestPart = part
                        closestPos = part.Position
                    end
                end
            end
        end
    end

    if closestPart and mode == "Silent" and shared.Quco.Feature.Silent.NearestPoint.Enabled then
        local pos,onScreen = camera:WorldToViewportPoint(closestPos)
        nearestPoint.Position = Vector2.new(pos.X,pos.Y)
        nearestPoint.Visible = onScreen and shared.Quco.Feature.Silent.NearestPoint.Visible
    else
        nearestPoint.Visible = false
    end

    return closestPart, closestPos
end

-- Silent Aim Hook
local mt = getrawmetatable(game)
setreadonly(mt,false)
local oldIndex = mt.__index
mt.__index = newcclosure(function(self,key)
    if self:IsA("Mouse") and key=="Hit" and shared.Quco.Feature.Silent.Enabled then
        local target = GetClosestPlayer()
        if target then
            local part,pos = GetClosestPart(target,"Silent")
            if part and pos then
                rayParams.FilterDescendantsInstances = {localplayer.Character}
                local rayResult = workspace:Raycast(localplayer.Character.HumanoidRootPart.Position,pos-localplayer.Character.HumanoidRootPart.Position,rayParams)
                if rayResult and rayResult.Instance:IsDescendantOf(target.Character) then
                    local pred = Vector3.new(shared.Quco.Feature.Silent.Prediction.X,shared.Quco.Feature.Silent.Prediction.Y,shared.Quco.Feature.Silent.Prediction.Z)
                    return CFrame.new(pos + part.Velocity * pred)
                end
            end
        end
    end
    return oldIndex(self,key)
end)
setreadonly(mt,true)

-- Trigger Bot
runservice.RenderStepped:Connect(function()
    local tb = shared.Quco.Feature["Trigger Bot"]
    if tb.Enabled then
        local target = GetClosestPlayer()
        if target then
            local part,pos = GetClosestPart(target,"Trigger Bot")
            if part and pos then
                local origin = localplayer.Character.HumanoidRootPart.Position
                local ray = workspace:Raycast(origin,pos-origin,rayParams)
                if ray and ray.Instance:IsDescendantOf(target.Character) then
                    if tb.Delay > 0 then task.wait(tb.Delay) end
                    mouse1click()
                end
            end
        end
    end
end)

-- Walk Speed
local toggled, normalSpeed = false, 16
local boostedSpeed = shared.Quco.Feature["Walk Speed"].Speed
userinputservice.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode[shared.Quco.Key["Walk Speed"]] then
        toggled = not toggled
        local char = localplayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = toggled and boostedSpeed or normalSpeed end
        end
    end
end)

-- Target Line & Silent Lock
local LockedTarget = nil
userinputservice.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode[shared.Quco.Key.Silent] then
        if LockedTarget then LockedTarget=nil else LockedTarget=GetClosestPlayer() end
    end
end)

runservice.RenderStepped:Connect(function()
    line.Color = shared.Quco['Target Lines'].Color
    if shared.Quco['Target Lines'].Visible and LockedTarget and LockedTarget.Character and LockedTarget.Character:FindFirstChild("HumanoidRootPart") then
        local pos,onScreen = camera:WorldToViewportPoint(LockedTarget.Character.HumanoidRootPart.Position)
        if onScreen then
            line.Visible = true
            line.From = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
            line.To = Vector2.new(pos.X,pos.Y)
        else
            line.Visible = false
        end
    else
        line.Visible = false
    end
end)
