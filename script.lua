local HttpService = gameGetService(HttpService)
local hwid = tostring(gameGetService(RbxAnalyticsService)GetClientId())
local API_URL = https://qocu-production.up.railway.app/validate

local function ValidateKey()
    local key = shared.Quco['script_key']
    if key ==  then return false end

    local ok,res = pcall(function()
        return HttpServicePostAsync(API_URL, HttpServiceJSONEncode({key=key,hwid=hwid}),Enum.HttpContentType.ApplicationJson)
    end)
    if not ok then return false end

    local data = HttpServiceJSONDecode(res)

    if data.blacklisted == true then return false end
    if data.hwid_banned == true then return false end
    if data.success == true then return true end

    return false
end

if not ValidateKey() then return end

local players, workspace, runservice, userinputservice = gameGetService(Players), game.Workspace, gameGetService(RunService), gameGetService(UserInputService)
local localplayer, camera, mouse = players.LocalPlayer, workspace.CurrentCamera, players.LocalPlayerGetMouse()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.IgnoreWater = true

local currentSpread = {}
for gunName, conf in pairs(shared.Quco.Modifications['Spread Modification']) do
    if type(conf) == number then currentSpread[gunName] = conf end
end
function ApplySpread(gunName, direction)
    local spreadVal = currentSpread[gunName] or 0
    local angle = math.rad(math.random(spreadVal  -100, spreadVal  100)  100)
    local spreadVector = CFrame.fromAxisAngle(Vector3.new(0,1,0), angle).LookVector
    return (direction + spreadVector).Unit
end

local line = Drawing.new(Line)
line.Color, line.Thickness, line.Visible = shared.Quco['Target Lines']['Color'], 2, false
local nearestPoint = Drawing.new(Circle)
nearestPoint.Visible, nearestPoint.Thickness, nearestPoint.Filled, nearestPoint.Radius = shared.Quco.Feature.Silent.NearestPoint.Visible, 1, false, shared.Quco.Feature.Silent.NearestPoint.Scale
nearestPoint.Color = Color3.fromRGB(255,0,0)

local function GetClosestPlayer()
    local closest, dist = nil, math.huge
    for _, player in ipairs(playersGetPlayers()) do
        if player ~= localplayer and player.Character and player.CharacterFindFirstChild(HumanoidRootPart) then
            local pos,onScreen = cameraWorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if onScreen then
                local d=(Vector2.new(pos.X,pos.Y)-Vector2.new(mouse.X,mouse.Y)).Magnitude
                if d  dist then dist=d closest=player end
            end
        end
    end
    return closest
end

local function GetClosestPart(target)
    if not target or not target.Character then return end
    local parts={Head,UpperTorso,LowerTorso,HumanoidRootPart,LeftHand,RightHand,LeftLowerArm,RightLowerArm,LeftUpperArm,RightUpperArm,LeftFoot,RightFoot,LeftLowerLeg,RightLowerLeg,LeftUpperLeg,RightUpperLeg}
    local closestPart,closestDist,closestPos=nil,math.huge,nil
    local mousePos=Vector2.new(mouse.X,mouse.Y)
    for _,partName in ipairs(parts) do
        local part=target.CharacterFindFirstChild(partName)
        if part then
            local pos,onScreen=cameraWorldToViewportPoint(part.Position)
            if onScreen then
                local d=(Vector2.new(pos.X,pos.Y)-mousePos).Magnitude
                if dclosestDist then closestDist=d closestPart=part closestPos=part.Position end
            end
        end
    end
    return closestPart,closestPos
end

local mt=getrawmetatable(game)
setreadonly(mt,false)
local oldIndex=mt.__index
mt.__index=newcclosure(function(self,key)
    if selfIsA(Mouse) and key==Hit and shared.Quco.Feature.Silent.Enabled then
        local target=GetClosestPlayer()
        if target then
            local part,pos=GetClosestPart(target)
            if part and pos then
                rayParams.FilterDescendantsInstances={localplayer.Character}
                local origin=localplayer.Character.HumanoidRootPart.Position
                local dir=(pos-origin)
                local rayResult=workspaceRaycast(origin,dir,rayParams)
                if rayResult and rayResult.InstanceIsDescendantOf(target.Character) then
                    local pred=Vector3.new(shared.Quco.Feature.Silent.Prediction.X,shared.Quco.Feature.Silent.Prediction.Y,shared.Quco.Feature.Silent.Prediction.Z)
                    return CFrame.new(pos + part.Velocitypred)
                end
            end
        end
    end
    return oldIndex(self,key)
end)
setreadonly(mt,true)

runservice.RenderSteppedConnect(function()
    local tb=shared.Quco.Feature[Trigger Bot]
    if tb.Enabled then
        local target=GetClosestPlayer()
        if target and target.Character then
            local part,pos=GetClosestPart(target)
            if part and pos then
                rayParams.FilterDescendantsInstances={localplayer.Character}
                local ray=workspaceRaycast(localplayer.Character.HumanoidRootPart.Position,pos-localplayer.Character.HumanoidRootPart.Position,rayParams)
                if ray and ray.InstanceIsDescendantOf(target.Character) then
                    if tb.Delay0 then task.wait(tb.Delay) end
                    mouse1click()
                end
            end
        end
    end
end)

local toggled=false
local normalSpeed=16
local boostedSpeed=shared.Quco.Feature[Walk Speed].Speed
userinputservice.InputBeganConnect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode[shared.Quco.Key[Walk Speed]] then
        toggled=not toggled
        local char=localplayer.Character
        if char then
            local hum=charFindFirstChildOfClass(Humanoid)
            if hum then hum.WalkSpeed=toggled and boostedSpeed or normalSpeed end
        end
    end
end)

local LockedTarget=nil
userinputservice.InputBeganConnect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode[shared.Quco.Key.Silent] then
        if LockedTarget then LockedTarget=nil else LockedTarget=GetClosestPlayer() end
    end
end)

runservice.RenderSteppedConnect(function()
    line.Color=shared.Quco['Target Lines'].Color
    if shared.Quco['Target Lines'].Visible and LockedTarget and LockedTarget.Character and LockedTarget.CharacterFindFirstChild(HumanoidRootPart) then
        local pos,onScreen=cameraWorldToViewportPoint(LockedTarget.Character.HumanoidRootPart.Position)
        if onScreen then
            line.Visible=true
            line.From=Vector2.new(camera.ViewportSize.X2,camera.ViewportSize.Y)
            line.To=Vector2.new(pos.X,pos.Y)
        else line.Visible=false end
    else line.Visible=false end
end)
