-- HarpoonMobile v0.2 | mobile dashboard / visible input prototype
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
if not player or game.PlaceId ~= 113384248926706 then
    warn("HarpoonMobile: jogo incompativel")
    return
end
local pg = player:WaitForChild("PlayerGui")
local prior = pg:FindFirstChild("HarpoonMobileV2")
if prior then
    local stop = prior:FindFirstChild("Stop")
    if stop then stop:Fire() else prior:Destroy() end
end
local alive = true
local options = {fish=false, reel=false, dive=false, surface=false, esp=false}
local interval = 0.8
local filter = 1
local modes = {"Todos", "Grandes", "Peixes"}
local keywords = {"fish", "shark", "kraken", "megalodon", "crocodon", "nightcrawler", "hexjaw", "shrimp", "hydra", "ray", "peixe", "tubarao"}
local large = {"shark", "kraken", "megalodon", "crocodon", "nightcrawler", "hexjaw", "hydra"}
local models, highlights, connections = {}, {}, {}
local attempts = 0
local lastShot, lastDive, lastReel, lastSurface = 0, 0, 0, 0
local vim
pcall(function() vim = game:GetService("VirtualInputManager") end)

local function new(class, parent, props)
    local obj = Instance.new(class)
    for k,v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function round(obj, radius)
    new("UICorner", obj, {CornerRadius=UDim.new(0,radius or 8)})
end
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections,c)
    return c
end
local gui = new("ScreenGui",pg,{Name="HarpoonMobileV2",ResetOnSpawn=false,DisplayOrder=100,IgnoreGuiInset=false})
local stop = new("BindableEvent",gui,{Name="Stop"})
local panel = new("Frame",gui,{Size=UDim2.fromOffset(282,310),Position=UDim2.new(0,12,0.5,-155),BackgroundColor3=Color3.fromRGB(17,24,39),BorderSizePixel=0,ClipsDescendants=true,Active=true})
round(panel,12)
local header = new("Frame",panel,{Size=UDim2.new(1,0,0,39),BackgroundColor3=Color3.fromRGB(30,41,59),BorderSizePixel=0,Active=true})
local function label(parent, value, size, pos, textSize)
    return new("TextLabel",parent,{Size=size,Position=pos,Text=value,BackgroundTransparency=1,TextColor3=Color3.fromRGB(238,242,255),Font=Enum.Font.GothamMedium,TextSize=textSize or 13,TextXAlignment=Enum.TextXAlignment.Left})
end
local function btn(parent,value,size,pos)
    local b = new("TextButton",parent,{Size=size,Position=pos,Text=value,BackgroundColor3=Color3.fromRGB(51,65,85),BorderSizePixel=0,TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=12,AutoButtonColor=true})
    round(b,6)
    return b
end
label(header,"  HARPOON MOBILE  /  0.2",UDim2.new(1,-72,1,0),UDim2.fromOffset(0,0),13)
local minimize = btn(header,"-",UDim2.fromOffset(29,29),UDim2.new(1,-64,0,5))
local close = btn(header,"X",UDim2.fromOffset(29,29),UDim2.new(1,-32,0,5))
local body = new("ScrollingFrame",panel,{Position=UDim2.fromOffset(0,39),Size=UDim2.new(1,0,1,-39),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,360)})
local status = label(body,"Inicializando...",UDim2.new(1,-18,0,32),UDim2.fromOffset(10,6),12)
status.TextWrapped=true
local buttons = {}
local function toggle(key,title,y)
    local b = btn(body,title.."  [OFF]",UDim2.new(1,-20,0,30),UDim2.fromOffset(10,y))
    buttons[key] = {button=b,title=title}
    connect(b.Activated,function()
        options[key]=not options[key]
        b.Text=title..(options[key] and "  [ON]" or "  [OFF]")
        b.BackgroundColor3=options[key] and Color3.fromRGB(5,115,84) or Color3.fromRGB(51,65,85)
    end)
end
toggle("fish","Auto Fish / disparo",42)
toggle("reel","Auto Reel / experimental",76)
toggle("dive","Auto Mergulhar",110)
toggle("surface","Auto Retornar",144)
toggle("esp","Fish ESP",178)
local f = btn(body,"Alvo: "..modes[filter],UDim2.new(1,-20,0,30),UDim2.fromOffset(10,212))
connect(f.Activated,function() filter=filter%#modes+1; f.Text="Alvo: "..modes[filter] end)
local minus = btn(body,"-",UDim2.fromOffset(38,29),UDim2.fromOffset(10,247))
local delayText = label(body,"Intervalo: 0.8s",UDim2.new(1,-105,0,29),UDim2.fromOffset(57,247),12)
local plus = btn(body,"+",UDim2.fromOffset(38,29),UDim2.new(1,-48,0,247))
local function change(delta)
    interval=math.clamp(math.floor((interval+delta)*10+0.5)/10,0.4,3)
    delayText.Text=string.format("Intervalo: %.1fs",interval)
end
connect(minus.Activated,function() change(-0.1) end)
connect(plus.Activated,function() change(0.1) end)
local counter=label(body,"Alvos: 0 | Tentativas: 0",UDim2.new(1,-20,0,25),UDim2.fromOffset(10,281),12)
local hint=label(body,"Mergulhe antes de ativar Auto Fish. Reel depende do timing do jogo.",UDim2.new(1,-20,0,42),UDim2.fromOffset(10,306),11)
hint.TextWrapped=true
local mini=false
connect(minimize.Activated,function()
    mini=not mini
    body.Visible=not mini
    panel.Size=UDim2.fromOffset(282,mini and 39 or 310)
    minimize.Text=mini and "+" or "-"
end)
local drag, dragStart, startPos
connect(header.InputBegan,function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=i; dragStart=i.Position; startPos=panel.AbsolutePosition
    end
end)
connect(UIS.InputChanged,function(i)
    if drag and (i==drag or i.UserInputType==Enum.UserInputType.MouseMovement) then
        local d=i.Position-dragStart
        local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,450)
        panel.Position=UDim2.fromOffset(math.clamp(startPos.X+d.X,0,math.max(0,viewport.X-282)),math.clamp(startPos.Y+d.Y,0,math.max(0,viewport.Y-40)))
    end
end)
connect(UIS.InputEnded,function(i) if i==drag then drag=nil end end)

local function contains(name,list)
    for _,word in ipairs(list) do if string.find(name,word,1,true) then return true end end
    return false
end
local function add(obj)
    if obj:IsA("Model") and contains(string.lower(obj.Name),keywords) and not Players:GetPlayerFromCharacter(obj) then models[obj]=true end
end
local function remove(obj)
    models[obj]=nil
    if highlights[obj] then highlights[obj]:Destroy(); highlights[obj]=nil end
end
connect(workspace.DescendantAdded,add)
connect(workspace.DescendantRemoving,remove)
for _,obj in ipairs(workspace:GetDescendants()) do add(obj) end
local function selected(obj)
    local n=string.lower(obj.Name)
    return filter==1 or (filter==2 and contains(n,large)) or (filter==3 and contains(n,{"fish","peixe"}))
end
local function updateEsp()
    for obj in pairs(models) do
        if not obj:IsDescendantOf(workspace) then remove(obj)
        elseif options.esp and selected(obj) then
            if not highlights[obj] then
                highlights[obj]=new("Highlight",gui,{Adornee=obj,FillColor=Color3.fromRGB(0,180,255),FillTransparency=0.7,OutlineColor=Color3.fromRGB(0,190,255)})
            end
        elseif highlights[obj] then highlights[obj]:Destroy(); highlights[obj]=nil end
    end
end
local function visible(obj)
    local p=obj
    while p and p~=pg do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("LayerCollector") and not p.Enabled then return false end
        p=p.Parent
    end
    return p==pg and not obj:IsDescendantOf(gui)
end
local function normalized(s)
    return string.upper((s or ""):gsub("<[^>]*>",""):gsub("^%s+",""):gsub("%s+$",""))
end
local function controls()
    local found={}
    for _,o in ipairs(pg:GetDescendants()) do
        if (o:IsA("TextButton") or o:IsA("TextLabel")) and visible(o) and o.AbsoluteSize.X>3 and o.AbsoluteSize.Y>3 then
            local t=normalized(o.Text)
            if t=="DIVE" or t=="MERGULHAR" then found.dive=o
            elseif t=="CLICK" or t=="CLIQUE" or t=="TAP" or t=="TOQUE" then found.reel=o
            elseif t=="RETURN" or t=="RETORNAR" or t=="VOLTAR" or t=="SURFACE" or t=="SUBIR" then found.surface=o end
        end
    end
    return found
end
local function center(o)
    local p=o.AbsolutePosition+o.AbsoluteSize/2
    local sg=o:FindFirstAncestorWhichIsA("ScreenGui")
    if sg and not sg.IgnoreGuiInset then local inset=GuiService:GetGuiInset(); p=p+inset end
    return p
end
local function tap(point)
    if not vim then return false,"Entrada virtual indisponivel" end
    local p=panel.AbsolutePosition
    local inset=GuiService:GetGuiInset()
    p=p+inset
    local s=panel.AbsoluteSize
    if point.X>=p.X and point.X<=p.X+s.X and point.Y>=p.Y and point.Y<=p.Y+s.Y then return false,"Mova o painel para liberar o alvo" end
    local ok,err=pcall(function()
        vim:SendMouseButtonEvent(math.floor(point.X),math.floor(point.Y),0,true,game,0)
        vim:SendMouseButtonEvent(math.floor(point.X),math.floor(point.Y),0,false,game,0)
    end)
    return ok,ok and "Toque enviado" or "Entrada virtual bloqueada"
end
local function target()
    local cam=workspace.CurrentCamera
    if not cam then return nil end
    local mid=cam.ViewportSize/2
    local best,score
    for obj in pairs(models) do
        if selected(obj) and obj:IsDescendantOf(workspace) then
            local part=obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true)
            if part then
                local p,on=cam:WorldToViewportPoint(part.Position)
                if on and p.Z>0 then
                    local v=Vector2.new(p.X,p.Y)
                    local n=(v-mid).Magnitude
                    if not score or n<score then best={point=v,name=obj.Name}; score=n end
                end
            end
        end
    end
    return best
end
local function cleanup()
    if not alive then return end
    alive=false
    for _,c in ipairs(connections) do c:Disconnect() end
    for _,h in pairs(highlights) do h:Destroy() end
    gui:Destroy()
end
connect(stop.Event,cleanup)
connect(close.Activated,cleanup)
task.spawn(function()
    while alive and gui.Parent do
        updateEsp()
        local n=0
        for _ in pairs(models) do n=n+1 end
        counter.Text=string.format("Alvos: %d | Tentativas: %d",n,attempts)
        if options.fish or options.reel or options.dive or options.surface then
            local c=controls()
            local now=os.clock()
            local ok,msg
            if c.dive then
                status.Text="Superficie: aguardando mergulho"
                if options.dive and now-lastDive>3 then
                    lastDive=now; ok,msg=tap(center(c.dive))
                    status.Text=ok and "Mergulho solicitado" or msg
                end
            elseif c.reel then
                status.Text="Minigame de recolhimento"
                if options.reel and now-lastReel>=interval then
                    lastReel=now; ok,msg=tap(center(c.reel))
                    status.Text=ok and "Reel: tentativa de toque" or msg
                end
            elseif c.surface and options.surface then
                if now-lastSurface>3 then
                    lastSurface=now; ok,msg=tap(center(c.surface))
                    status.Text=ok and "Retorno solicitado" or msg
                end
            elseif options.fish and now-lastShot>=interval then
                lastShot=now
                local t=target()
                if t then
                    ok,msg=tap(t.point)
                    if ok then attempts=attempts+1 end
                    status.Text=ok and ("Disparo: "..t.name) or msg
                else status.Text="Nenhum alvo visivel identificado" end
            end
        else status.Text="Pronto. Ative os modulos desejados." end
        task.wait(0.25)
    end
end)
print("HarpoonMobile v0.2 carregado")
