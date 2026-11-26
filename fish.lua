-- HarpoonMobile v0.3 | persistent mobile menu and client-visible diagnostics
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
if not player then
    warn("HarpoonMobile: LocalPlayer indisponivel")
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
local rarityFilter = "Todos"
local minWeight, maxWeight = nil, nil
local rarityKeys = {"rarity","tier","raridade","fishrarity"}
local weightKeys = {"weight","weightkg","peso","fishweight","mass"}
local function readField(obj, keys)
    for _,node in pairs({obj, obj:FindFirstChild("Stats"), obj:FindFirstChild("Data"), obj:FindFirstChild("Configuration")}) do
        if node then
            for k,v in pairs(node:GetAttributes()) do
                if table.find(keys,string.lower(k)) and (type(v)=="string" or type(v)=="number") then return v,k end
            end
            for _,child in ipairs(node:GetChildren()) do
                if table.find(keys,string.lower(child.Name)) and (child:IsA("StringValue") or child:IsA("NumberValue") or child:IsA("IntValue")) then return child.Value,child.Name end
            end
        end
    end
    return nil
end
local function weightNumber(v)
    if type(v)=="number" then return v end
    if type(v)~="string" then return nil end
    return tonumber((v:gsub(",","."):match("^%s*([%d%.]+)%s*$") or ""))
end
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
local gui = new("ScreenGui",pg,{Name="HarpoonMobileV2",ResetOnSpawn=false,DisplayOrder=10000,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
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
label(header,"  HARPOON MOBILE  /  0.3",UDim2.new(1,-72,1,0),UDim2.fromOffset(0,0),13)
local minimize = btn(header,"-",UDim2.fromOffset(29,29),UDim2.new(1,-64,0,5))
local close = btn(header,"X",UDim2.fromOffset(29,29),UDim2.new(1,-32,0,5))
local body = new("ScrollingFrame",panel,{Position=UDim2.fromOffset(0,39),Size=UDim2.new(1,0,1,-39),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,490)})
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
local floating = btn(gui,"HM",UDim2.fromOffset(58,58),UDim2.new(1,-10,0.5,0))
floating.AnchorPoint=Vector2.new(1,0.5)
floating.BackgroundColor3=Color3.fromRGB(0,112,210)
floating.TextSize=18
floating.ZIndex=100
local function setPanel(open)
    panel.Visible=open
    floating.Text=open and "HM -" or "HM +"
end
setPanel(false)
connect(floating.Activated,function() setPanel(not panel.Visible) end)
connect(minimize.Activated,function() setPanel(false) end)
local rarityInput=new("TextBox",body,{Size=UDim2.new(1,-20,0,30),Position=UDim2.fromOffset(10,350),Text="",PlaceholderText="Raridade exata (vazio = todas)",ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(51,65,85),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(190,205,220),Font=Enum.Font.Gotham,TextSize=12})
round(rarityInput,6)
connect(rarityInput.FocusLost,function() rarityFilter=rarityInput.Text:match("^%s*(.-)%s*$"); if rarityFilter=="" then rarityFilter="Todos" end end)
local function weightBox(x,placeholder)
    local b=new("TextBox",body,{Size=UDim2.new(0.5,-15,0,30),Position=UDim2.fromOffset(x,386),Text="",PlaceholderText=placeholder,ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(51,65,85),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(190,205,220),Font=Enum.Font.Gotham,TextSize=12})
    round(b,6)
    return b
end
local low,high=weightBox(10,"Peso minimo"),weightBox(143,"Peso maximo")
local function readWeights()
    minWeight=weightNumber(low.Text)
    maxWeight=weightNumber(high.Text)
end
connect(low.FocusLost,readWeights)
connect(high.FocusLost,readWeights)
local diagnostic=btn(body,"GERAR DIAGNOSTICO",UDim2.new(1,-20,0,34),UDim2.fromOffset(10,424))
local diagFrame=new("Frame",gui,{Size=UDim2.new(0.85,0,0.8,0),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.fromRGB(15,23,42),Visible=false,ZIndex=20})
round(diagFrame,10)
local diagClose=btn(diagFrame,"Fechar",UDim2.fromOffset(80,32),UDim2.new(1,-90,0,6))
diagClose.ZIndex=22
label(diagFrame,"  Diagnostico (dados visiveis)",UDim2.new(1,-95,0,38),UDim2.fromOffset(0,0),13).ZIndex=21
local diagScroll=new("ScrollingFrame",diagFrame,{Position=UDim2.fromOffset(8,45),Size=UDim2.new(1,-16,1,-53),CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ScrollBarThickness=5,ZIndex=21})
local diagText=new("TextBox",diagScroll,{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,MultiLine=true,TextWrapped=true,TextEditable=true,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text="",TextSize=12,Font=Enum.Font.Code,BackgroundColor3=Color3.fromRGB(30,41,59),TextColor3=Color3.new(1,1,1),ZIndex=22})
connect(diagClose.Activated,function() diagFrame.Visible=false end)
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
    local categoryOK=filter==1 or (filter==2 and contains(n,large)) or (filter==3 and contains(n,{"fish","peixe"}))
    if not categoryOK then return false end
    if rarityFilter~="Todos" then
        local rarity=readField(obj,rarityKeys)
        if rarity==nil or string.lower(tostring(rarity))~=string.lower(rarityFilter) then return false end
    end
    if minWeight or maxWeight then
        local w=weightNumber(readField(obj,weightKeys))
        if not w or (minWeight and w<minWeight) or (maxWeight and w>maxWeight) then return false end
    end
    return true
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
local lastInput="nenhum teste"
local function tap(point)
    if not vim then lastInput="Entrada virtual indisponivel"; return false,lastInput end
    if diagFrame.Visible then return false,"Feche o diagnostico" end
    local p=panel.AbsolutePosition
    local inset=GuiService:GetGuiInset()
    p=p+inset
    local s=panel.AbsoluteSize
    if panel.Visible and point.X>=p.X and point.X<=p.X+s.X and point.Y>=p.Y and point.Y<=p.Y+s.Y then return false,"Feche o painel para liberar o alvo" end
    local ok,err=pcall(function()
        vim:SendMouseButtonEvent(math.floor(point.X),math.floor(point.Y),0,true,game,0)
        vim:SendMouseButtonEvent(math.floor(point.X),math.floor(point.Y),0,false,game,0)
    end)
    lastInput=ok and "Toque enviado (captura nao confirmada)" or tostring(err):sub(1,220)
    return ok,ok and "Toque enviado" or "Entrada bloqueada: veja diagnostico"
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
connect(close.Activated,function() setPanel(false) end)
connect(diagnostic.Activated,function()
    local lines={"HarpoonMobile v0.3", "PlaceId: "..tostring(game.PlaceId), "GameId: "..tostring(game.GameId), "Entrada virtual: "..lastInput, "Tentativas: "..tostring(attempts), "=== Modelos reconhecidos ==="}
    local count=0
    for obj in pairs(models) do
        if count>=60 then break end
        local rarity,rkey=readField(obj,rarityKeys)
        local weight,wkey=readField(obj,weightKeys)
        count=count+1
        table.insert(lines,string.format("%s | raridade=%s [%s] | peso=%s [%s]",obj.Name,tostring(rarity or "?"),tostring(rkey or "-"),tostring(weight or "?"),tostring(wkey or "-")))
    end
    table.insert(lines,"=== Textos de pesca visiveis ===")
    local seen={}
    local total=0
    for _,o in ipairs(pg:GetDescendants()) do
        if total>=60 then break end
        if (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) then
            local t=normalized(o.Text)
            if contains(string.lower(t),{"fish","peixe","mergul","dive","reel","clique","toque","tap","rarity","raridade","weight","peso","kg","harpoon","arpao","captur","recolh"}) and not seen[t] then
                seen[t]=true; total=total+1; table.insert(lines,t:sub(1,100))
            end
        end
    end
    diagText.Text=table.concat(lines,"\n")
    diagFrame.Visible=true
    setPanel(false)
end)
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
print("HarpoonMobile v0.3 carregado | PlaceId: "..tostring(game.PlaceId))
