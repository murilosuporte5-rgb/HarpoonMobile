-- HarpoonMobile v0.21 | manual fishing, minigame-only, read-only depth
-- Baseline: fish_v017.lua. Existing input path; no new runtime bypass.
-- Use only in an authorized runtime. Studio/client compatibility not implied.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
if game.GameId~=10764240948 then
    warn("HM v0.21: universo diferente do esperado")
    return
end
local player=Players.LocalPlayer
if not player then return end
local pg=player:WaitForChild("PlayerGui")
for _,name in ipairs({"HarpoonMobileV2","HarpoonMobileV019","HarpoonMobileV020","HarpoonMobileV021"}) do
    local old=pg:FindFirstChild(name)
    if old then
        local stop=old:FindFirstChild("Stop")
        if stop and stop:IsA("BindableEvent") then stop:Fire() else old:Destroy() end
    end
end
local alive,enabled,busy=false,false,false
local vim
pcall(function() vim=game:GetService("VirtualInputManager") end)
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local gui=make("ScreenGui",pg,{Name="HarpoonMobileV021",ResetOnSpawn=false,DisplayOrder=10000,AutoLocalize=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local stop=make("BindableEvent",gui,{Name="Stop"})
local panel=make("Frame",gui,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,8),Size=UDim2.fromOffset(218,156),BackgroundColor3=Color3.fromRGB(19,24,35),Visible=false})
make("UICorner",panel,{CornerRadius=UDim.new(0,12)})
make("UIStroke",panel,{Color=Color3.fromRGB(71,95,131),Thickness=1})
local floating=make("TextButton",gui,{Name="Floating",Position=UDim2.fromOffset(14,104),Size=UDim2.fromOffset(48,48),BackgroundColor3=Color3.fromRGB(24,35,53),TextColor3=Color3.fromRGB(212,232,255),Text="HM",TextSize=16,Font=Enum.Font.GothamBold,AutoLocalize=false})
make("UICorner",floating,{CornerRadius=UDim.new(1,0)})
make("UIStroke",floating,{Color=Color3.fromRGB(86,156,235),Thickness=2})
local function text(class,y,h,value)
    return make(class,panel,{Position=UDim2.fromOffset(6,y),Size=UDim2.new(1,-12,0,h),BackgroundColor3=Color3.fromRGB(40,45,55),BorderSizePixel=0,TextColor3=Color3.fromRGB(245,245,245),TextSize=12,Font=Enum.Font.Gotham,AutoLocalize=false,TextWrapped=true,Text=value})
end
local header=text("TextLabel",6,23,"HARPOON  /  0.21")
header.BackgroundTransparency=1
header.Font=Enum.Font.GothamBold
local toggle=text("TextButton",33,29,"Minigame: OFF")
make("UICorner",toggle,{CornerRadius=UDim.new(0,6)})
local depthLabel=text("TextLabel",66,23,"Prof.: ? | Lim.: ?")
depthLabel.BackgroundTransparency=1
local status=text("TextLabel",92,34,"Pesca manual")
status.BackgroundTransparency=1
local close=text("TextButton",130,20,"Encerrar")
make("UICorner",close,{CornerRadius=UDim.new(0,5)})
local drag=nil
local function showPanel()
    panel.Visible=not panel.Visible
end
local connections={}
local function connect(sig,fn)
    local c=sig:Connect(fn)
    connections[#connections+1]=c
end
local function cleanup(destroy)
    if not alive then return end
    alive=false
    enabled=false
    for _,c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
    if destroy then gui:Destroy() end
end
alive=true
connect(stop.Event,function() cleanup(true) end)
connect(gui.Destroying,function() cleanup(false) end)
connect(close.Activated,function() cleanup(true) end)
connect(floating.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        drag={input=input,start=Vector2.new(input.Position.X,input.Position.Y),base=floating.AbsolutePosition,moved=false}
    end
end)
connect(UIS.InputChanged,function(input)
    if not drag then return end
    if input~=drag.input and not (drag.input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement) then return end
    local delta=Vector2.new(input.Position.X,input.Position.Y)-drag.start
    if delta.Magnitude>6 then drag.moved=true end
    if drag.moved then
        local cam=workspace.CurrentCamera
        if not cam then return end
        local z=floating.AbsoluteSize
        local p=drag.base+delta
        floating.Position=UDim2.fromOffset(math.clamp(p.X,0,math.max(0,cam.ViewportSize.X-z.X)),math.clamp(p.Y,0,math.max(0,cam.ViewportSize.Y-z.Y-40)))
    end
end)
connect(UIS.InputEnded,function(input)
    if drag and input==drag.input then
        local moved=drag.moved
        drag=nil
        if not moved then showPanel() end
    end
end)
local cache=nil
local lastScan=-math.huge
local lastDepth=-math.huge
local lastTap=-math.huge
local touchId=1000
local latched=false
local attempts=0
local sentCount=0
local inputError=nil
local lastObservedInput=UIS:GetLastInputType().Name
local function setStatus(t)
    if alive and status.Text~=t then status.Text=t end
end
connect(toggle.Activated,function()
    enabled=not enabled
    inputError=nil
    cache=nil
    latched=false
    lastScan=-math.huge
    toggle.Text=enabled and "Minigame: ON" or "Minigame: OFF"
    floating.TextColor3=enabled and Color3.fromRGB(111,235,180) or Color3.fromRGB(212,232,255)
    if not enabled then setStatus("Pesca manual") end
end)
local function visible(o)
    if not o or not o.Parent or o:IsDescendantOf(gui) then return false end
    local cam=workspace.CurrentCamera
    if not cam then return false end
    local p,z=o.AbsolutePosition,o.AbsoluteSize
    local left,top=math.max(0,p.X),math.max(0,p.Y)
    local right,bottom=math.min(cam.ViewportSize.X,p.X+z.X),math.min(cam.ViewportSize.Y,p.Y+z.Y)
    local a=o
    while a and a~=pg do
        if a:IsA("GuiObject") and not a.Visible then return false end
        if a:IsA("LayerCollector") and not a.Enabled then return false end
        if a~=o and a:IsA("GuiObject") and a.ClipsDescendants then
            local ap,az=a.AbsolutePosition,a.AbsoluteSize
            left,top=math.max(left,ap.X),math.max(top,ap.Y)
            right,bottom=math.min(right,ap.X+az.X),math.min(bottom,ap.Y+az.Y)
        end
        a=a.Parent
    end
    return a==pg and right>left and bottom>top
end
connect(UIS.LastInputTypeChanged,function(kind)
    lastObservedInput=kind.Name
end)
local function rendered(o)
    local ok,v=pcall(function() return o.ContentText end)
    return string.upper((ok and type(v)=="string" and v~="" and v or o.Text):gsub("<[^>]*>",""):gsub("^%s+",""):gsub("%s+$",""))
end
local function paused()
    return GuiService.MenuIsOpen or UIS:GetFocusedTextBox()~=nil
end
local function shortArc(a,b)
    local span=(b-a)%360
    if span<=180 then return a%360,span end
    return b%360,360-span
end
local function reelParts(label)
    local p=label
    for _=1,5 do
        if not p or p==pg then break end
        local needle=p:FindFirstChild("NeedleRotator",true)
        local cap1=p:FindFirstChild("CapO1",true)
        local cap2=p:FindFirstChild("CapO2",true)
        if needle and cap1 and cap2 and needle:IsA("GuiObject") and cap1:IsA("GuiObject") and cap2:IsA("GuiObject") then
            if visible(needle) and visible(cap1) and visible(cap2) then
                return needle,cap1,cap2
            end
        end
        p=p.Parent
    end
    return nil
end

local function scan()
    local found=nil
    for _,o in ipairs(pg:GetDescendants()) do
        if o.Name=="Key" and (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) then
            local t=rendered(o)
            if t=="CLICK" or t=="TAP" or t=="CLIQUE" or t=="TOQUE" then
                local n,a,b=reelParts(o)
                if n then
                    if found and found.needle~=n then return nil end -- ambiguous visible instances
                    found={label=o,needle=n,a=a,b=b}
                end
            end
        end
    end
    return found
end
local function valid(c)
    if not c or not visible(c.label) or not visible(c.needle) or not visible(c.a) or not visible(c.b) then return false end
    local t=rendered(c.label)
    return t=="CLICK" or t=="TAP" or t=="CLIQUE" or t=="TOQUE"
end
local function depthScan()
    local current,maximum={},{}
    for _,o in ipairs(pg:GetDescendants()) do
        if (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) then
            local t=rendered(o)
            local n=t:match("^DEPTH%s*:%s*([%d.,]+)%s*M$") or t:match("^PROFUNDIDADE%s*:%s*([%d.,]+)%s*M$")
            local m=t:match("^MAX DEPTH%s*:%s*([%d.,]+)%s*M$") or t:match("^PROFUNDIDADE MAXIMA%s*:%s*([%d.,]+)%s*M$")
            if n then current[n]=true end
            if m then maximum[m]=true end
        end
    end
    local function one(values)
        local first=next(values)
        if first and next(values,first)==nil then return first.." m" end
        return "?"
    end
    depthLabel.Text="Prof.: "..one(current).." | Lim.: "..one(maximum)
end
local function pointFor(o)
    local p=o.AbsolutePosition+o.AbsoluteSize/2
    local root=o:FindFirstAncestorWhichIsA("ScreenGui")
    if root and not root.IgnoreGuiInset then p=p+GuiService:GetGuiInset() end
    return p
end
local function covered(p)
    local a,z=panel.AbsolutePosition,panel.AbsoluteSize
    local function inside(v) return p.X>=v.X and p.X<=v.X+z.X and p.Y>=v.Y and p.Y<=v.Y+z.Y end
    if panel.Visible and (inside(a) or inside(a+GuiService:GetGuiInset())) then return true end
    local fp,fz=floating.AbsolutePosition,floating.AbsoluteSize
    return p.X>=fp.X and p.X<=fp.X+fz.X and p.Y>=fp.Y and p.Y<=fp.Y+fz.Y
end
local function dispatch(c)
    if busy or not alive or not enabled or paused() or not valid(c) or not vim then return end
    local p=pointFor(c.label)
    local cam=workspace.CurrentCamera
    if not cam or covered(p) or p.X<8 or p.Y<60 or p.X>cam.ViewportSize.X-8 or p.Y>cam.ViewportSize.Y-8 then return end
    busy=true
    attempts=attempts+1
    local x,y=math.floor(p.X),math.floor(p.Y)
    local mobile=UIS.TouchEnabled
    touchId=touchId+1
    local id=touchId
    local function input(down)
        if mobile then
            -- Internal API availability depends on the current runtime.
            -- Never substitute a mouse event on a touch-capable device.
            vim:SendTouchEvent(id,down and Enum.UserInputState.Begin.Value or Enum.UserInputState.End.Value,x,y)
        else
            vim:SendMouseButtonEvent(x,y,0,down,game,0)
        end
    end
    task.spawn(function()
        local pressed=false
        local ok,err=pcall(function()
            if not alive or not enabled or paused() or not valid(c) then return end
            input(true)
            pressed=true
            task.wait(0.045)
            input(false)
            pressed=false
            sentCount=sentCount+1
        end)
        if pressed then pcall(input,false) end
        busy=false
        if not ok then
            enabled=false
            if alive then
                toggle.Text="Minigame: OFF"
                inputError=tostring(err)
                floating.TextColor3=Color3.fromRGB(255,140,140)
                setStatus((mobile and "Toque: " or "Entrada: ")..inputError:sub(1,85))
                warn("HM v0.21 input: "..tostring(err))
            end
        end
    end)
end
-- Cache the visible minigame parts. Preserve the baseline short-arc timing.
connect(RunService.RenderStepped,function()
    if not alive then return end
    local now=os.clock()
    if now-lastDepth>=1 then lastDepth=now; pcall(depthScan) end
    if not enabled or paused() then cache=nil; latched=false; return end
    if not vim then setStatus("Runtime sem entrada virtual"); return end
    local ok=pcall(function()
        if not valid(cache) then
            cache=nil
            latched=false
            if now-lastScan>=0.12 then lastScan=now; cache=scan() end
        end
        if not cache then setStatus("Aguardando minigame"); return end
        local a,span=shortArc(cache.a.AbsoluteRotation,cache.b.AbsoluteRotation)
        if span<2 or span>178 then setStatus("Arco ambiguo"); return end
        local offset=(cache.needle.AbsoluteRotation-a)%360
        if offset>span then latched=false end
        local margin=math.min(4,span*0.15)
        if not latched and not busy and now-lastTap>=0.16 and offset>=margin and offset<=span-margin then
            latched=true
            lastTap=now
            dispatch(cache)
        end
        if not inputError then setStatus("Entradas: "..sentCount.."/"..attempts.." | "..lastObservedInput) end
    end)
    if not ok then
        enabled=false
        cache=nil
        toggle.Text="Minigame: OFF"
        floating.TextColor3=Color3.fromRGB(255,140,140)
        setStatus("Erro de interface; pausado")
    end
end)
print("HarpoonMobile v0.21 | pesca manual; profundidade somente leitura")
