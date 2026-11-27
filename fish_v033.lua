-- HarpoonMobile v0.33 | Central reel baseline and opt-in normal-control fishing
-- Baseline: fish_v017.lua. Existing input path; no new runtime bypass.
-- Use only in an authorized runtime. Studio/client compatibility not implied.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
if game.GameId~=10764240948 then
    warn("HM v0.33: universo diferente do esperado")
    return
end
local player=Players.LocalPlayer
if not player then return end
local pg=player:WaitForChild("PlayerGui")
for _,name in ipairs({"HarpoonMobileV2","HarpoonMobileV019","HarpoonMobileV020","HarpoonMobileV021","HarpoonMobileV022","HarpoonMobileV023","HarpoonMobileV024","HarpoonMobileV025","HarpoonMobileV026","HarpoonMobileV027","HarpoonMobileV028","HarpoonMobileV029","HarpoonMobileV030","HarpoonMobileV031","HarpoonMobileV032","HarpoonMobileV033"}) do
    local old=pg:FindFirstChild(name)
    if old then
        local stop=old:FindFirstChild("Stop")
        if stop and stop:IsA("BindableEvent") then stop:Fire() else old:Destroy() end
    end
end
local alive,enabled,busy=false,false,false
local exclusiveReel=false
local inputOwner=nil
local reelLockSince=-math.huge
local releaseActive=nil
local vim
pcall(function() vim=game:GetService("VirtualInputManager") end)
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local gui=make("ScreenGui",pg,{Name="HarpoonMobileV033",ResetOnSpawn=false,DisplayOrder=10000,AutoLocalize=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local stop=make("BindableEvent",gui,{Name="Stop"})
local palette={
    bg=Color3.fromRGB(12,20,31),surface=Color3.fromRGB(23,37,51),
    line=Color3.fromRGB(45,70,85),text=Color3.fromRGB(234,245,250),
    muted=Color3.fromRGB(153,181,193),accent=Color3.fromRGB(44,210,186),
    active=Color3.fromRGB(12,95,83),danger=Color3.fromRGB(88,45,50)
}
local panel=make("Frame",gui,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,8),Size=UDim2.fromOffset(242,264),BackgroundColor3=palette.bg,Visible=false})
make("UICorner",panel,{CornerRadius=UDim.new(0,12)})
make("UIStroke",panel,{Color=palette.line,Thickness=1})
local floating=make("TextButton",gui,{Name="Floating",Position=UDim2.fromOffset(14,104),Size=UDim2.fromOffset(48,48),BackgroundColor3=palette.bg,TextColor3=palette.accent,Text="HM",TextSize=16,Font=Enum.Font.GothamBold,AutoLocalize=false})
make("UICorner",floating,{CornerRadius=UDim.new(1,0)})
make("UIStroke",floating,{Color=palette.accent,Thickness=2})
local function text(class,y,h,value)
    return make(class,panel,{Position=UDim2.fromOffset(6,y),Size=UDim2.new(1,-12,0,h),BackgroundColor3=palette.surface,BorderSizePixel=0,TextColor3=palette.text,TextSize=13,Font=Enum.Font.Gotham,AutoLocalize=false,TextWrapped=true,Text=value})
end
local header=text("TextLabel",6,24,"HARPOON MOBILE   /   0.33")
header.BackgroundTransparency=1
header.Font=Enum.Font.GothamBold
header.TextColor3=palette.accent
local toggle=text("TextButton",36,32,"Minigame: OFF")
make("UICorner",toggle,{CornerRadius=UDim.new(0,6)})
local modeButton=text("TextButton",73,27,"Modo: Central")
make("UICorner",modeButton,{CornerRadius=UDim.new(0,6)})
local depthLabel=text("TextLabel",104,20,"Prof.: ? | Lim.: ?")
depthLabel.BackgroundTransparency=1
depthLabel.TextColor3=palette.muted
local status=text("TextLabel",126,32,"Pesca manual")
status.BackgroundTransparency=1
local farmLive=text("TextLabel",161,39,"Pesca: manual")
farmLive.BackgroundTransparency=1
farmLive.TextColor3=palette.muted
farmLive.TextSize=11
local auditButton=text("TextButton",203,28,"CONTROLES  /  FILTROS")
make("UICorner",auditButton,{CornerRadius=UDim.new(0,5)})
local close=text("TextButton",235,23,"Encerrar sessao")
close.BackgroundColor3=palette.danger
make("UICorner",close,{CornerRadius=UDim.new(0,5)})
local auditPanel=make("Frame",gui,{Name="Audit",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.84,0.84),BackgroundColor3=palette.bg,Visible=false,ZIndex=10})
make("UISizeConstraint",auditPanel,{MaxSize=Vector2.new(420,540)})
make("UICorner",auditPanel,{CornerRadius=UDim.new(0,14)})
make("UIStroke",auditPanel,{Color=palette.line,Thickness=1})
local auditScroll=make("ScrollingFrame",auditPanel,{Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,1,-16),CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=11})
make("UIListLayout",auditScroll,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
local auditOrder=0
local function auditControl(class,value,height)
    auditOrder=auditOrder+1
    local o=make(class,auditScroll,{Name="Audit"..auditOrder,LayoutOrder=auditOrder,Size=UDim2.new(1,-6,0,height),BackgroundColor3=palette.surface,TextColor3=palette.text,TextSize=13,BorderSizePixel=0,Font=Enum.Font.Gotham,TextWrapped=true,Text=value,ZIndex=12,AutoLocalize=false})
    make("UICorner",o,{CornerRadius=UDim.new(0,5)})
    return o
end
local auditHeading=auditControl("TextLabel","HARPOON  /  CONTROLES",32)
auditHeading.TextColor3=palette.accent
auditHeading.Font=Enum.Font.GothamBold
auditHeading.BackgroundTransparency=1
local exclusiveButton=auditControl("TextButton","Central: prioridade automatica",32)
local farmToggle=auditControl("TextButton","Auto pesca: OFF",30)
local aimToggle=auditControl("TextButton","Auto mira: OFF",30)
local cycleToggle=auditControl("TextButton","Auto mergulho/retorno: OFF",30)
local moveToggle=auditControl("TextButton","Movimento: Manual",30)
local sortToggle=auditControl("TextButton","Prioridade: Mais profundo (Y)",30)
local function field(hint)
    local o=auditControl("TextBox","",32)
    o.PlaceholderText=hint
    o.ClearTextOnFocus=false
    return o
end
local filtersHeading=auditControl("TextLabel","01  /  FILTROS DE ALVO",24)
filtersHeading.TextColor3=palette.accent
filtersHeading.BackgroundTransparency=1
local speciesBox=field("Especie (opcional)")
local rarityBox=field("Raridade: comum, raro, mitico...")
local minBox=field("Peso bruto minimo (ex. 10K)")
local maxBox=field("Peso bruto maximo")
local incomeBox=field("Renda / s minima (campo confirmado)")
local applyFilters=auditControl("TextButton","APLICAR FILTROS",34)
local clearFilters=auditControl("TextButton","LIMPAR FILTROS / TESTE DE PESO",30)
applyFilters.BackgroundColor3=palette.active
local catalogHeading=auditControl("TextLabel","02  /  CATALOGO OPCIONAL",24)
catalogHeading.TextColor3=palette.accent
catalogHeading.BackgroundTransparency=1
local communityToggle=auditControl("TextButton","Catalogo comunitario: OFF",30)
local catalogSpecies=field("Catalogo: nome exato do modelo")
local catalogRarity=field("Raridade observada no indice")
local saveCatalog=auditControl("TextButton","Registrar raridade observada",30)
local catalogStatus=auditControl("TextLabel","Catalogo local da sessao. Nao e garantia de raridade futura.",42)
local diagHeading=auditControl("TextLabel","03  /  DIAGNOSTICO",24)
diagHeading.TextColor3=palette.accent
diagHeading.BackgroundTransparency=1
local auditStatus=auditControl("TextLabel","Filtros vazios = todos. Dados desconhecidos nao satisfazem filtros.",48)
local farmInfo=auditControl("TextLabel","Aguardando observacoes",130)
local closeAudit=auditControl("TextButton","VOLTAR AO JOGO",36)
closeAudit.BackgroundColor3=palette.active
local function paint(b,on) b.BackgroundColor3=on and palette.active or palette.surface end
local function closeSettings()
    auditPanel.Visible=false
    panel.Visible=false
end
local drag=nil
local function showPanel()
    if auditPanel.Visible then auditPanel.Visible=false; panel.Visible=false; return end
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
    if releaseActive then releaseActive() end
    for _,c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
    if destroy then gui:Destroy() end
end
alive=true
connect(stop.Event,function() cleanup(true) end)
connect(gui.Destroying,function() cleanup(false) end)
connect(close.Activated,function() cleanup(true) end)
connect(auditButton.Activated,function()
    if releaseActive then releaseActive() end
    auditPanel.Visible=true
    panel.Visible=false
end)
connect(closeAudit.Activated,closeSettings)
connect(exclusiveButton.Activated,function()
    exclusiveReel=not exclusiveReel
    exclusiveButton.Text=exclusiveReel and "Central: exclusivo" or "Central: prioridade automatica"
    paint(exclusiveButton,exclusiveReel)
end)
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
local lastTap=-math.huge
local touchId=1000
local latched=false
local roundArc=nil
local candidateArc=nil
local roundChanges=0
local attempts=0
local sentCount=0
local inputError=nil
local blockedReason=nil
local lastObservedInput=UIS:GetLastInputType().Name
local modes={
    {name="Normal",cooldown=0.16,hold=0.045},
    {name="Rapido",cooldown=0.08,hold=0.025},
    {name="Central",cooldown=0.16,hold=0.045},
    {name="Adaptativo",cooldown=0.12,hold=0.035}
}
local modeIndex=3
local stats={}
for i=1,#modes do stats[i]={began=0,ended=0} end
local motion=nil
local function resetMotion()
    motion=nil
end
local function setStatus(t)
    if alive and status.Text~=t then status.Text=t end
end
connect(modeButton.Activated,function()
    if busy then setStatus("Aguarde o fim do toque"); return end
    modeIndex=modeIndex%#modes+1
    modeButton.Text="Modo: "..modes[modeIndex].name
    cache=nil
    latched=false
    roundArc=nil
    candidateArc=nil
    lastScan=-math.huge
    blockedReason=nil
    resetMotion()
    local st=stats[modeIndex]
    setStatus("Toques: "..st.ended.."/"..st.began)
end)
connect(toggle.Activated,function()
    enabled=not enabled
    if enabled and exclusiveReel and inputOwner=="farm" and releaseActive then releaseActive() end
    inputError=nil
    blockedReason=nil
    cache=nil
    latched=false
    roundArc=nil
    candidateArc=nil
    resetMotion()
    lastScan=-math.huge
    toggle.Text=enabled and "Minigame: ON" or "Minigame: OFF"
    paint(toggle,enabled)
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
    return auditPanel.Visible or GuiService.MenuIsOpen or UIS:GetFocusedTextBox()~=nil
end
local function shortArc(a,b)
    local span=(b-a)%360
    if span<=180 then return a%360,span end
    return b%360,360-span
end
local function angularDistance(a,b)
    return math.abs((a-b+180)%360-180)
end
local function arcChanged(x,a,span)
    return x and (angularDistance(x.a,a)>3 or math.abs(x.span-span)>3)
end
-- Distinct experimental timing strategies. None bypasses game validation.
local function signedDelta(a,b)
    return (a-b+180)%360-180
end
local function sampleMotion(c,now)
    local angle=c.needle.AbsoluteRotation%360
    if motion and motion.needle==c.needle then
        local dt=now-motion.t
        if dt>0 and dt<=0.1 then
            local v=signedDelta(angle,motion.angle)/dt
            if math.abs(v)<=1800 then
                local consistent=motion.velocity==nil or math.abs(v-motion.velocity)<=math.max(80,math.abs(motion.velocity)*0.5)
                motion={needle=c.needle,t=now,angle=angle,velocity=consistent and (motion.velocity and (0.6*motion.velocity+0.4*v) or v) or nil}
                return
            end
        end
    end
    motion={needle=c.needle,t=now,angle=angle}
end
local function timingDecision(index,span,offset,velocity,hold)
    local margin=math.min(4,span*0.15)
    if index==2 then
        margin=math.min(1,span*0.05)
    elseif index==3 then
        return offset>=span*0.35 and offset<=span*0.65
    elseif index==4 and velocity then
        -- Prefer a point that remains inside during both input phases.
        local endOffset=offset+velocity*hold
        local endMargin=math.min(2,span*0.10)
        return offset>=endMargin and offset<=span-endMargin
            and endOffset>=endMargin and endOffset<=span-endMargin
    end
    return offset>=margin and offset<=span-margin
end
local function window(c)
    local a,span=shortArc(c.a.AbsoluteRotation,c.b.AbsoluteRotation)
    if span<2 or span>178 then return nil end
    local offset=(c.needle.AbsoluteRotation-a)%360
    local velocity=motion and motion.needle==c.needle and motion.velocity or nil
    return a,span,offset,timingDecision(modeIndex,span,offset,velocity,modes[modeIndex].hold)
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
-- Observed model fields, not server-authoritative values.
local farmOn,aimOn,cycleOn=false,false,false
local movement=1
local moveNames={"Manual","Subir","Descer","Auto: fundo primeiro"}
local sortIndex=4
local sortNames={"Centro","Maior peso","Maior renda (campo)","Mais profundo (Y)"}
local filters={}
connect(clearFilters.Activated,function()
    filters={}
    speciesBox.Text=""; rarityBox.Text=""; minBox.Text=""; maxBox.Text=""; incomeBox.Text=""
    sortIndex=2
    sortToggle.Text="Prioridade: "..sortNames[sortIndex]
    auditStatus.Text="Filtros limpos. Prioridade: maior peso bruto."
end)
local trim=function(v) return v:match("^%s*(.-)%s*$") end
local function normalize(v)
    local t=tostring(v or ""):gsub("<[^>]*>","")
    for a,b in pairs({["Á"]="a",["á"]="a",["Ã"]="a",["ã"]="a",["Â"]="a",["â"]="a",["É"]="e",["é"]="e",["Ê"]="e",["ê"]="e",["Í"]="i",["í"]="i",["Ó"]="o",["ó"]="o",["Ô"]="o",["ô"]="o",["Ú"]="u",["ú"]="u",["Ç"]="c",["ç"]="c"}) do
        t=t:gsub(a,b)
    end
    return string.lower(trim(t))
end
local function speciesKey(v)
    return (normalize(v):gsub("[%s_%-]",""))
end
local rarityAliases={
    common="common",comum="common",
    uncommon="uncommon",incomum="uncommon",
    rare="rare",raro="rare",rara="rare",
    epic="epic",epico="epic",epica="epic",
    legendary="legendary",lendario="legendary",lendaria="legendary",
    mythic="mythic",mythical="mythic",mitico="mythic",mitica="mythic",
    exotic="exotic",exotico="exotic",exotica="exotic",
    secret="secret",secreto="secret",secreta="secret"
}
local function rarityValue(v)
    return rarityAliases[normalize(v)]
end
-- Public catch examples, not authoritative species definitions.
-- https://allthings.how/harpoon-a-fish-roblox-full-guide-how-the-dive-feed-and-sink-loop-works/
local communityRarity={swordfish="uncommon",lionfish="uncommon",mosasaurus="legendary",demonpliosaur="exotic",riftmawmanatee="legendary"}
local manualRarity={}
local communityOn=false
connect(communityToggle.Activated,function()
    communityOn=not communityOn
    communityToggle.Text="Catalogo comunitario: "..(communityOn and "ON (estimativa)" or "OFF")
    paint(communityToggle,communityOn)
end)
connect(saveCatalog.Activated,function()
    local key=speciesKey(catalogSpecies.Text)
    local rarity=rarityValue(catalogRarity.Text)
    if key=="" or not rarity then
        catalogStatus.Text="Informe nome exato e uma raridade reconhecida."
        return
    end
    if manualRarity[key] and manualRarity[key]~=rarity then
        manualRarity[key]="conflict"
        catalogStatus.Text="Observacoes conflitantes: "..key..". Sem classificacao."
        return
    end
    manualRarity[key]=rarity
    catalogStatus.Text="Observacao registrada: "..key.." / "..rarity
end)
local function numberInput(raw)
    local t=string.upper(trim(raw))
    if t=="" then return nil,true end
    local digits,suffix=t:match("^(%d+[.,]?%d*)%s*([KMBT]?)$")
    if not digits or (suffix=="" and digits:match("[.,]%d%d%d$")) then return nil,false end
    local n=tonumber((digits:gsub(",",".")))
    if n then n=n*({[""]=1,K=1e3,M=1e6,B=1e9,T=1e12})[suffix] end
    return n,n~=nil and n>=0 and n<math.huge and n==n
end
connect(applyFilters.Activated,function()
    local lo,ok1=numberInput(minBox.Text)
    local hi,ok2=numberInput(maxBox.Text)
    local inc,ok3=numberInput(incomeBox.Text)
    if not ok1 or not ok2 or not ok3 or (lo and hi and lo>hi) then
        auditStatus.Text="Limites invalidos. Use 10000, 10K ou 1.5M."
        return
    end
    local rawRarity=normalize(rarityBox.Text)
    local wanted=nil
    if rawRarity~="" and rawRarity~="todos" and rawRarity~="todas" and rawRarity~="all" then
        wanted=rarityValue(rawRarity)
        if not wanted then auditStatus.Text="Raridade invalida: comum, incomum, raro, epico, lendario, mitico, exotico, secreto."; return end
    end
    filters={species=speciesKey(speciesBox.Text),rarity=wanted,lo=lo,hi=hi,income=inc}
    auditStatus.Text="Filtros aplicados. Peso em unidade bruta do modelo."
end)
connect(farmToggle.Activated,function()
    farmOn=not farmOn
    if farmOn and movement==1 then movement=4; moveToggle.Text="Movimento: "..moveNames[movement] end
    farmToggle.Text="Auto pesca: "..(farmOn and "ON" or "OFF")
    paint(farmToggle,farmOn)
end)
connect(aimToggle.Activated,function()
    aimOn=not aimOn
    aimToggle.Text="Auto mira: "..(aimOn and "ON" or "OFF")
    paint(aimToggle,aimOn)
end)
connect(cycleToggle.Activated,function()
    cycleOn=not cycleOn
    cycleToggle.Text="Auto mergulho/retorno: "..(cycleOn and "ON" or "OFF")
    paint(cycleToggle,cycleOn)
end)
connect(moveToggle.Activated,function()
    movement=movement%#moveNames+1
    moveToggle.Text="Movimento: "..moveNames[movement]
end)
connect(sortToggle.Activated,function()
    sortIndex=sortIndex%#sortNames+1
    sortToggle.Text="Prioridade: "..sortNames[sortIndex]
end)
local fieldNames={
    weight={weight=true,weightkg=true,peso=true,fishweight=true,mass=true},
    rarity={rarity=true,tier=true,raridade=true,fishrarity=true},
    income={incomepersecond=true,moneypersecond=true,cashpersecond=true,earningspersecond=true,revenuepersecond=true}
}
local function observedField(obj,keys)
    local nodes={obj}
    for _,name in ipairs({"Stats","Data","Configuration"}) do
        local n=obj:FindFirstChild(name)
        if n then nodes[#nodes+1]=n end
    end
    for _,node in ipairs(nodes) do
        for k,v in pairs(node:GetAttributes()) do
            if keys[speciesKey(k)] and (type(v)=="string" or type(v)=="number") then return v,k end
        end
        for _,c in ipairs(node:GetChildren()) do
            if keys[speciesKey(c.Name)] and (c:IsA("NumberValue") or c:IsA("IntValue") or c:IsA("StringValue")) then return c.Value,c.Name end
        end
    end
end
local function finiteNumber(v)
    local n=type(v)=="number" and v or (type(v)=="string" and tonumber(v) or nil)
    if n and n>=0 and n<math.huge and n==n then return n end
end
local function labelVisibleInModel(o,obj)
    local p=o
    while p and p~=obj do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("LayerCollector") and not p.Enabled then return false end
        if p:IsA("Model") then return false end -- never use nested model labels
        p=p.Parent
    end
    return p==obj
end
local function associatedRarity(obj)
    local raw=observedField(obj,fieldNames.rarity)
    local direct=rarityValue(raw)
    if direct then return direct,"attribute" end
    -- Only an exact rarity label on a BillboardGui belonging to this model.
    local found=nil
    for _,o in ipairs(obj:GetDescendants()) do
        if o:IsA("TextLabel") and labelVisibleInModel(o,obj) then
            local guiOwner=o:FindFirstAncestorWhichIsA("BillboardGui")
            if guiOwner and guiOwner:IsDescendantOf(obj) then
                local adornee=guiOwner.Adornee
                if not adornee or adornee==obj or adornee:IsDescendantOf(obj) then
                    local rawText=normalize(o.Text):gsub("^rarity%s*:%s*",""):gsub("^raridade%s*:%s*","")
                    local value=rarityValue(rawText)
                    if value then
                        if found and found~=value then return nil,"conflict" end
                        found=value
                    end
                end
            end
        end
    end
    if found then return found,"billboard" end
    local key=speciesKey(obj.Name)
    if manualRarity[key]=="conflict" then return nil,"conflict" end
    if manualRarity[key] then return manualRarity[key],"manual observation" end
    if communityOn and communityRarity[key] then return communityRarity[key],"community estimate" end
    return nil,"unknown"
end
-- A rate label must belong to this model and explicitly say income per second.
-- Never associate global aquarium totals or unrelated interface cards.
local function associatedIncome(obj)
    local direct=finiteNumber(observedField(obj,fieldNames.income))
    if direct~=nil then return direct,"attribute" end
    local found=nil
    for _,o in ipairs(obj:GetDescendants()) do
        if o:IsA("TextLabel") and labelVisibleInModel(o,obj) then
            local owner=o:FindFirstAncestorWhichIsA("BillboardGui")
            if owner and owner:IsDescendantOf(obj) and (not owner.Adornee or owner.Adornee==obj or owner.Adornee:IsDescendantOf(obj)) then
                local t=normalize(o.Text)
                local body=t:match("^income%s*:%s*(.-)%s*/%s*sec$") or t:match("^income%s*:%s*(.-)%s*/%s*s$")
                    or t:match("^renda%s*:%s*(.-)%s*/%s*s$") or t:match("^renda%s*:%s*(.-)%s*/%s*seg$")
                if body then
                    local clean=body:gsub("^%s*%$%s*","")
                    local n,ok=numberInput(clean)
                    if ok and n~=nil then
                        if found~=nil and found~=n then return nil,"conflict" end
                        found=n
                    end
                end
            end
        end
    end
    if found~=nil then return found,"billboard" end
    return nil,"unknown"
end
local fishNames={"fish","shark","kraken","megalodon","crocodon","nightcrawler","hexjaw","shrimp","hydra","ray","peixe","tubarao"}
local models={}
local function modelAdd(o)
    if not o:IsA("Model") or o.Name=="FishRoll" or Players:GetPlayerFromCharacter(o) then return end
    local fishRoot=workspace:FindFirstChild("Fish")
    if fishRoot then
        if o.Parent==fishRoot then models[o]=true end
        return
    end
    local name=string.lower(o.Name)
    for _,term in ipairs(fishNames) do
        if name:find(term,1,true) then models[o]=true; return end
    end
end
connect(workspace.DescendantAdded,modelAdd)
connect(workspace.DescendantRemoving,function(o) models[o]=nil end)
task.spawn(function()
    for _,o in ipairs(workspace:GetDescendants()) do
        if not alive then return end
        modelAdd(o)
    end
end)
local function chooseFish(blockedUp,blockedDown)
    local cam=workspace.CurrentCamera
    if not cam then return nil,0,0,0,0,0,{attribute=0,billboard=0,["manual observation"]=0,["community estimate"]=0} end
    local best,score
    local visibleMatches=0
    local recognized,knownRarity,knownIncome,matched=0,0,0,0
    local raritySources={attribute=0,billboard=0,["manual observation"]=0,["community estimate"]=0}
    for o in pairs(models) do
        if o:IsDescendantOf(workspace) and (o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart",true)) then
            local w=finiteNumber(observedField(o,fieldNames.weight))
            -- Weight evidence is required to reduce false model matches.
            if w~=nil then
                recognized=recognized+1
                local rarity,raritySource=associatedRarity(o)
                local income,incomeSource=associatedIncome(o)
                if rarity then knownRarity=knownRarity+1; raritySources[raritySource]=raritySources[raritySource]+1 end
                if income~=nil then knownIncome=knownIncome+1 end
                local name=speciesKey(o.Name)
                local f=filters
                if (not f.species or f.species=="" or name:find(f.species,1,true))
                    and (not f.rarity or f.rarity=="" or rarity==f.rarity)
                    and (not f.lo or w>=f.lo) and (not f.hi or w<=f.hi)
                    and (not f.income or (income~=nil and income>=f.income))
                    and (sortIndex~=3 or income~=nil) then
                    local cf=o:GetBoundingBox()
                    local p,on=cam:WorldToViewportPoint(cf.Position)
                    local inView=on and p.Z>0
                    matched=matched+1
                    if inView then visibleMatches=visibleMatches+1 end
                    -- Y is a world-space estimate, not the game's displayed depth.
                    -- Keep off-screen candidates only for the automatic vertical search.
                    local dy=cf.Position.Y-cam.CFrame.Position.Y
                    local navAllowed=movement==4 and p.Z>0 and p.X>=0 and p.X<=cam.ViewportSize.X and math.abs(dy)>5
                        and not (dy<0 and blockedDown) and not (dy>0 and blockedUp)
                    if inView or navAllowed then
                        local d=(cf.Position-cam.CFrame.Position).Magnitude
                        local rank
                        if sortIndex==2 then rank=-w
                        elseif sortIndex==3 then rank=-income
                        elseif sortIndex==4 then rank=cf.Position.Y
                        else rank=inView and (Vector2.new(p.X,p.Y)-cam.ViewportSize/2).Magnitude or d+10000 end
                        -- Prefer descending over ascending within the selected priority.
                        local direction=dy>5 and 1 or 0
                        local better=not best
                        if best then
                            if inView~=best.inView then better=inView
                            elseif movement==4 and direction~=best.direction then better=direction<best.direction
                            elseif rank~=score then better=rank<score
                            else better=d<best.distance end
                        end
                        if better then
                            best={object=o,name=o.Name,weight=w,rarity=rarity,raritySource=raritySource,income=income,incomeSource=incomeSource,inView=inView,dy=dy,direction=direction,distance=d}
                            score=rank
                        end
                    end
                end
            end
        end
    end
    return best,recognized,knownRarity,knownIncome,matched,visibleMatches,raritySources
end
local function scanControls()
    local c={full=false,underwater=false}
    local cam=workspace.CurrentCamera
    -- These two exact visible paths were observed in the supplied v0.31 report.
    local diveGui=pg:FindFirstChild("DiveGui")
    if diveGui then
        local dive=diveGui:FindFirstChild("Dive")
        local leave=diveGui:FindFirstChild("Leave")
        if dive and dive:IsA("GuiButton") and visible(dive) then c.surface=true; c.dive=dive end
        if leave and leave:IsA("GuiButton") and visible(leave) then c.returnSeen=true; c.back=leave; c.knownLeave=true end
    end
    for _,o in ipairs(pg:GetDescendants()) do
        if (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) then
            local t=string.upper(normalize(rendered(o))):gsub("%s+"," ")
            local b=o:IsA("GuiButton") and o or o:FindFirstAncestorWhichIsA("GuiButton") or o
            if t=="MERGULHAR" or t=="DIVE" or t=="DIVE IN" then c.surface=true; c.dive=c.dive or b
            elseif t=="VOLTAR" or t=="RETURN" or t=="RETORNAR" then c.returnSeen=true; c.back=c.back or b
            elseif t=="SUBIR" or t=="ASCEND" then c.upSeen=true; c.up=b
            elseif t=="DESCER" or t=="DESCEND" then c.downSeen=true; c.down=b
            elseif t:find("BOLSA CHEIA",1,true) or t:find("BAG FULL",1,true) then c.full=true
            elseif t:find("SPACE TO RETURN",1,true) or t:find("PARA VOLTAR",1,true) then c.returnSeen=true end
        end
    end
    c.cameraScriptable=cam~=nil and cam.CameraType==Enum.CameraType.Scriptable
    c.underwater=not c.surface and cam~=nil and (c.knownLeave or c.full or (c.upSeen and c.downSeen) or (c.returnSeen and c.cameraScriptable))
    return c
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
-- Separate fishing/movement dispatch. Does not change the reel timing code.
local function normalTap(p,hold)
    if enabled and exclusiveReel then return false,"Central exclusivo ativo" end
    if valid(cache) or scan()~=nil then return false,"Minigame tem prioridade" end
    if not alive or paused() or busy or not vim or covered(p) then return false,"Entrada ocupada ou coberta" end
    local cam=workspace.CurrentCamera
    if not cam or p.X<8 or p.Y<8 or p.X>cam.ViewportSize.X-8 or p.Y>cam.ViewportSize.Y-8 then return false,"Fora da tela" end
    busy=true
    inputOwner="farm"
    touchId=touchId+1
    local id,x,y=touchId,math.floor(p.X),math.floor(p.Y)
    local mobile=UIS.TouchEnabled
    local function input(down)
        if mobile then
            vim:SendTouchEvent(id,down and Enum.UserInputState.Begin.Value or Enum.UserInputState.End.Value,x,y)
        else
            vim:SendMouseButtonEvent(x,y,0,down,game,0)
        end
    end
    local ok,err=pcall(input,true)
    if not ok then busy=false; inputOwner=nil; return false,tostring(err) end
    local done=false
    local function release()
        if done then return end
        done=true
        local released=pcall(input,false)
        if not released then released=pcall(input,false) end
        busy=false
        inputOwner=nil
        releaseActive=nil
        if not released then
            farmOn=false; cycleOn=false; movement=1; aimOn=false
            if alive then
                farmToggle.Text="Auto pesca: OFF"; aimToggle.Text="Auto mira: OFF"
                cycleToggle.Text="Auto mergulho/retorno: OFF"; moveToggle.Text="Movimento: Manual"
            end
        end
    end
    releaseActive=release
    task.delay(hold or 0.045,release)
    return true,"Entrada enviada; captura nao confirmada"
end
local function dispatch(c)
    if busy or not alive or not enabled or paused() or not valid(c) or not vim then
        return false,"Entrada indisponivel"
    end
    local p=pointFor(c.label)
    local cam=workspace.CurrentCamera
    if not cam then return false,"Camera indisponivel" end
    if covered(p) then return false,"Mova o menu HM" end
    if p.X<8 or p.Y<60 or p.X>cam.ViewportSize.X-8 or p.Y>cam.ViewportSize.Y-8 then return false,"Alvo fora da area" end
    busy=true
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
    local function fail(err)
        enabled=false
        if alive then
            toggle.Text="Minigame: OFF"
            inputError=tostring(err)
            floating.TextColor3=Color3.fromRGB(255,140,140)
            setStatus((mobile and "Toque: " or "Entrada: ")..inputError:sub(1,85))
            warn("HM v0.33 input: "..inputError)
        end
    end
    -- Revalidate the window at the dispatch boundary.
    if not alive or not enabled or paused() or not valid(c) then
        busy=false
        return false,"Rodada alterada"
    end
    local _,_,_,inside=window(c)
    if not inside then
        busy=false
        return false,"Janela alterada"
    end
    local ok,err=pcall(input,true)
    if not ok then
        busy=false
        fail(err)
        return false,"Entrada falhou"
    end
    attempts=attempts+1
    local st=stats[modeIndex]
    local hold=modes[modeIndex].hold
    st.began=st.began+1
    local released=false
    local function release()
        if released then return end
        released=true
        local success,why=pcall(input,false)
        if not success then success,why=pcall(input,false) end
        if success then sentCount=sentCount+1; st.ended=st.ended+1 else fail(why) end
        busy=false
        releaseActive=nil
    end
    releaseActive=release
    task.delay(hold,release)
    return true
end
-- Cache the visible minigame parts. Preserve the baseline short-arc timing.
connect(RunService.RenderStepped,function()
    if not alive then return end
    local now=os.clock()
    if not enabled or paused() then cache=nil; latched=false; roundArc=nil; candidateArc=nil; resetMotion(); return end
    if not vim then setStatus("Runtime sem entrada virtual"); return end
    local ok=pcall(function()
        if not valid(cache) then
            cache=nil
            latched=false
            roundArc=nil
            candidateArc=nil
            resetMotion()
            if now-lastScan>=0.12 then lastScan=now; cache=scan() end
        end
        if not cache then setStatus("Aguardando minigame"); return end
        reelLockSince=now
        if inputOwner=="farm" and releaseActive then releaseActive() end
        sampleMotion(cache,now)
        local a,span,offset,inside=window(cache)
        if not a then setStatus("Arco ambiguo"); return end
        if not roundArc then
            roundArc={a=a,span=span}
        elseif arcChanged(roundArc,a,span) then
            if candidateArc and not arcChanged(candidateArc,a,span) then
                roundArc={a=a,span=span}
                candidateArc=nil
                latched=false
                roundChanges=roundChanges+1
                resetMotion()
                local _,_,_,fresh=window(cache)
                inside=fresh
            else
                candidateArc={a=a,span=span}
                return -- require two consistent samples
            end
        else
            candidateArc=nil
        end
        if offset>span then latched=false end
        if not latched and not busy and now-lastTap>=modes[modeIndex].cooldown and inside then
            local accepted,reason=dispatch(cache)
            if accepted then
                latched=true
                lastTap=now
                blockedReason=nil
            else
                blockedReason=reason
            end
        end
        if not inputError then
            local st=stats[modeIndex]
            setStatus(blockedReason or ("Toques: "..st.ended.."/"..st.began.." | Arcos: "..roundChanges))
        end
    end)
    if not ok then
        enabled=false
        cache=nil
        toggle.Text="Minigame: OFF"
        floating.TextColor3=Color3.fromRGB(255,140,140)
        setStatus("Erro de interface; pausado")
    end
end)
-- Depth is noncritical display work. Only refresh while the panel is open.
task.spawn(function()
    while alive and gui.Parent do
        if panel.Visible then
            local ok=pcall(depthScan)
            if not ok then depthLabel.Text="Prof.: ? | Lim.: ?" end
        end
        task.wait(1)
    end
end)
-- Farm loop isolated from the Central reel path.
local fullLatch=false
local lastAction=-math.huge
local lastMovement=-math.huge
local targetModel=nil
local shots=0
local shotPending=nil
local shotTransitions=0
local shotTimeouts=0
local consecutiveTimeouts=0
local retryAfter=0
local aimErrorDegrees=nil
local aimRequested=0
local aimObserved=0
local farmMessage="Pesca manual"
local stateName="aguardando HUD"
local lastUiRefresh=-math.huge
local function setFarmMessage(msg)
    farmMessage=msg
    if alive then farmLive.Text="Pesca: "..stateName.."\n"..msg end
end
local verticalProbe=nil
local stalled={up=0,down=0}
local blockedUntil={up=0,down=0}
local function resetVertical()
    verticalProbe=nil
    stalled.up=0; stalled.down=0
    blockedUntil.up=0; blockedUntil.down=0
end
local function observeVertical(now)
    if not verticalProbe or now-verticalProbe.time<0.8 then return end
    local probe=verticalProbe
    verticalProbe=nil
    local cam=workspace.CurrentCamera
    if not cam then return end
    local dy=cam.CFrame.Position.Y-probe.y
    local direction=probe.direction
    local progressed=direction=="down" and dy< -0.1 or direction=="up" and dy>0.1
    if progressed then
        stalled[direction]=0
    else
        stalled[direction]=stalled[direction]+1
        if stalled[direction]>=3 then
            blockedUntil[direction]=now+4
            stalled[direction]=0
        end
    end
end
local function moveNormally(c,direction,now)
    if verticalProbe or now-lastMovement<0.8 then return false,"Aguardando movimento" end
    if now<blockedUntil[direction] then return false,"Sem deslocamento observado; pausa" end
    local b
    if direction=="up" then b=c.up else b=c.down end
    if not b or not visible(b) then
        blockedUntil[direction]=now+2
        return false,"Controle de movimento nao disponivel"
    end
    local cam=workspace.CurrentCamera
    if not cam then return false,"Camera indisponivel" end
    lastMovement=now
    local y=cam.CFrame.Position.Y
    local sent,msg=normalTap(pointFor(b),0.25)
    if sent then verticalProbe={direction=direction,y=y,time=now} end
    return sent,msg
end
task.spawn(function()
    while alive and gui.Parent do
        if (farmOn or aimOn or cycleOn or movement==2 or movement==3 or auditPanel.Visible) and not busy then
            local ok,err=pcall(function()
                local now=os.clock()
                if enabled and exclusiveReel then
                    if inputOwner=="farm" and releaseActive then releaseActive() end
                    verticalProbe=nil
                    setFarmMessage("Central exclusivo: outros modulos suspensos")
                    return
                end
                local c=scanControls()
                stateName=c.surface and "superficie" or c.full and "bolsa cheia" or c.underwater and "submerso" or "estado desconhecido"
                if c.surface then fullLatch=false; resetVertical(); shotPending=nil; consecutiveTimeouts=0 end
                if c.full then fullLatch=true end
                local reelVisible=valid(cache) or scan()~=nil
                if reelVisible then
                    reelLockSince=now
                    if shotPending then shotTransitions=shotTransitions+1; shotPending=nil; consecutiveTimeouts=0 end
                    if inputOwner=="farm" and releaseActive then releaseActive() end
                    verticalProbe=nil; setFarmMessage("Minigame ativo; prioridade Central"); return
                end
                if now-reelLockSince<0.25 then return end
                if shotPending and now-shotPending>=2 then
                    shotPending=nil; shotTimeouts=shotTimeouts+1; consecutiveTimeouts=consecutiveTimeouts+1
                    if consecutiveTimeouts>=3 then retryAfter=now+5; consecutiveTimeouts=0 end
                end
                observeVertical(now)
                local target,n,r,i,m,v,sources=chooseFish(now<blockedUntil.up,now<blockedUntil.down)
                targetModel=target
                if auditPanel.Visible then
                    farmInfo.Text=string.format("Modelos %d | Raridade %d | Renda %d\nRaridade: direta %d | manual %d | estimada %d\nCompativeis %d | Tela %d | Toques %d\nAlvo: %s\n%s",n,r,i,sources.attribute+sources.billboard,sources["manual observation"],sources["community estimate"],m,v,shots,target and (target.name.." / "..target.raritySource.." / renda: "..target.incomeSource) or "-",farmMessage)
                    return
                end
                if paused() or reelVisible then verticalProbe=nil; return end
                if cycleOn and now-lastAction>=3 then
                    local b=c.surface and c.dive or (fullLatch and c.underwater and c.back)
                    if b and visible(b) then
                        lastAction=now
                        local sent,msg=normalTap(pointFor(b),0.045)
                        farmMessage=msg
                        return
                    end
                end
                if not c.underwater or fullLatch then
                    setFarmMessage(fullLatch and "Bolsa cheia; aguardando retorno" or c.surface and "Na superficie; mergulhe" or "Sem evidencia de mergulho")
                    return
                end
                if shotPending then setFarmMessage("Aguardando resposta visual do disparo"); return end
                if movement==2 or movement==3 then
                    local sent,msg=moveNormally(c,movement==2 and "up" or "down",now)
                    farmMessage=msg
                    if sent then return end
                elseif movement==4 and farmOn then
                    local needsRarity=filters.rarity and filters.rarity~=""
                    local needsIncome=filters.income~=nil or sortIndex==3
                    if not target and ((needsRarity and r==0) or (needsIncome and i==0)) then
                        setFarmMessage("Filtro sem dados de raridade/renda")
                        return
                    end
                    local dir
                    if target then
                        if target.inView then dir=nil
                        elseif target.dy < -5 then dir="down"
                        elseif target.dy > 5 then dir="up" end
                    else
                        -- No verified match: descend first, retry upward only when descent stalls.
                        dir=now<blockedUntil.down and "up" or "down"
                    end
                    if dir then
                        local sent,msg=moveNormally(c,dir,now)
                        farmMessage=(dir=="down" and "Descendo: " or "Subindo: ")..msg
                        -- Do not fire while repositioning toward a different level.
                        if sent or msg=="Aguardando movimento" or not target or not target.inView then return end
                    else
                        resetVertical()
                    end
                else
                    resetVertical()
                end
                if not target or not target.object:IsDescendantOf(workspace) then
                    setFarmMessage(n==0 and "Nenhum modelo com peso identificado" or m==0 and "Nenhum peixe passou nos filtros" or "Alvo indisponivel na tela")
                    return
                end
                local cam=workspace.CurrentCamera
                if not cam then return end
                local cf=target.object:GetBoundingBox()
                local dir=cf.Position-cam.CFrame.Position
                if dir.Magnitude<0.5 then return end
                if aimOn then
                    aimErrorDegrees=math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(dir.Unit),-1,1)))
                    if aimErrorDegrees>3 then
                        aimRequested=aimRequested+1
                        cam.CFrame=CFrame.lookAt(cam.CFrame.Position,cf.Position)
                        setFarmMessage(string.format("Mira solicitada: %.1f graus antes do ajuste",aimErrorDegrees))
                        return -- require a later observation, not our own CFrame write
                    end
                    aimObserved=aimObserved+1
                    setFarmMessage(string.format("Alinhamento observado: %.1f graus",aimErrorDegrees))
                end
                if farmOn and now<retryAfter then setFarmMessage("Sem resposta visual; pausa de disparos"); return end
                if farmOn and now-lastAction>=0.65 then
                    local p,on=cam:WorldToViewportPoint(cf.Position)
                    if on and p.Z>0 then
                        lastAction=now
                        local sent,msg=normalTap(Vector2.new(p.X,p.Y),0.045)
                        farmMessage=msg
                        if sent then shots=shots+1; shotPending=now end
                    end
                end
            end)
            if not ok then
                farmOn=false; aimOn=false; cycleOn=false; movement=1
                farmToggle.Text="Auto pesca: OFF"; aimToggle.Text="Auto mira: OFF"
                cycleToggle.Text="Auto mergulho/retorno: OFF"; moveToggle.Text="Movimento: Manual"
                setFarmMessage("Falha: "..tostring(err):sub(1,100))
                warn("HM farm: "..tostring(err))
            end
        end
        if alive then
            if not (farmOn or aimOn or cycleOn or movement==2 or movement==3) then
                farmLive.Text="Pesca manual / controles desativados"
            else
                farmLive.Text="Pesca: "..stateName.."\n"..farmMessage
            end
            paint(farmToggle,farmOn); paint(aimToggle,aimOn); paint(cycleToggle,cycleOn); paint(toggle,enabled)
        end
        task.wait(0.25)
    end
end)
-- Independent, read-only diagnostic collector. No new input or server requests.
do
    local HS=game:GetService("HttpService")
    local heading=auditControl("TextLabel","04  /  COLETA AUTOMATICA",26)
    heading.TextColor3=palette.accent
    heading.BackgroundTransparency=1
    local collectButton=auditControl("TextButton","Coleta automatica: ON (fora do Central)",32)
    paint(collectButton,true)
    local snapshotButton=auditControl("TextButton","ATUALIZAR DADOS",32)
    local exportButton=auditControl("TextButton","GERAR RELATORIO JSON",32)
    local compactButton=auditControl("TextButton","RESUMO CURTO (1 pagina)",32)
    local summary=auditControl("TextLabel","Aguardando primeira leitura...",65)
    local prevButton=auditControl("TextButton","Pagina anterior",28)
    local nextButton=auditControl("TextButton","Proxima pagina",28)
    local pageLabel=auditControl("TextLabel","Relatorio ainda nao gerado",24)
    pageLabel.BackgroundTransparency=1
    local output=auditControl("TextBox","",180)
    output.ClearTextOnFocus=false
    output.MultiLine=true
    output.TextEditable=false
    output.TextXAlignment=Enum.TextXAlignment.Left
    output.TextYAlignment=Enum.TextYAlignment.Top
    output.TextSize=11
    closeAudit.LayoutOrder=auditOrder+1
    local automatic=true
    local requested=true
    local collecting=false
    local latest=nil
    local history={}
    local previous=setmetatable({},{__mode="k"})
    local pages={}
    local page=1
    local sampleCount=0
    local lastError=nil
    local function vector(v)
        return {x=v.X,y=v.Y,z=v.Z}
    end
    local function scalar(v)
        if type(v)=="number" and v==v and math.abs(v)<math.huge then return v end
        if type(v)=="string" then return v end
        if type(v)=="boolean" then return v end
        if typeof(v)=="Vector3" then return vector(v) end
        if typeof(v)=="Color3" then return {r=v.R,g=v.G,b=v.B} end
    end
    local function addFields(node,rows)
        for k,v in pairs(node:GetAttributes()) do
            local value=scalar(v)
            if value~=nil then rows[#rows+1]={path=node:GetFullName(),kind="attribute",key=k,value=value} end
        end
        for _,c in ipairs(node:GetChildren()) do
            if c:IsA("NumberValue") or c:IsA("IntValue") or c:IsA("StringValue") or c:IsA("BoolValue") or c:IsA("Vector3Value") then
                local value=scalar(c.Value)
                if value~=nil then rows[#rows+1]={path=c:GetFullName(),kind="value",key=c.Name,value=value} end
            end
        end
    end
    local function fishRecord(o,cam,now)
        if not o:IsDescendantOf(workspace) then return nil end
        local w,wKey=observedField(o,fieldNames.weight)
        local weight=finiteNumber(w)
        if weight==nil then return nil end
        if not (o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart",true)) then return nil end
        local cf,sz=o:GetBoundingBox()
        local pos=cf.Position
        local point,on=cam:WorldToViewportPoint(pos)
        local rr,rs=associatedRarity(o)
        local inc,isrc=associatedIncome(o)
        local fields={}
        addFields(o,fields)
        for _,name in ipairs({"Stats","Data","Configuration"}) do
            local node=o:FindFirstChild(name)
            if node then addFields(node,fields) end
        end
        local old=previous[o]
        local velocity=nil
        if old and now>old.time then velocity=vector((pos-old.pos)/(now-old.time)) end
        previous[o]={time=now,pos=pos}
        return {species=o.Name,path=o:GetFullName(),weightRaw=weight,weightKey=wKey,
            weightUnit="unverified",size=scalar(o:GetAttribute("Size")),bounds=vector(sz),
            position=vector(pos),cameraDistance=(pos-cam.CFrame.Position).Magnitude,
            relativeY=pos.Y-cam.CFrame.Position.Y,projected=vector(point),onScreen=on and point.Z>0,
            velocityEstimate=velocity,rarity=rr,raritySource=rs,incomePerSecond=inc,
            incomeSource=isrc,fields=fields}
    end
    local function hudEvidence()
        local rows={}
        for _,o in ipairs(pg:GetDescendants()) do
            if (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) then
                local t=normalize(o.Text)
                local key=speciesKey(o.Name)
                local relevant=t:find("bolsa",1,true) or t:find("bag",1,true) or t:find("profund",1,true)
                    or t:find("depth",1,true) or t:find("voltar",1,true) or t:find("return",1,true)
                    or t:find("mergulhar",1,true) or t:find("dive",1,true) or t=="subir" or t=="descer"
                    or t=="ascend" or t=="descend" or t:find("captur",1,true) or t:find("caught",1,true)
                    or t:find("renda",1,true) or t:find("income",1,true) or t:find("/s",1,true)
                    or t:find("/sec",1,true) or t:find(" kg",1,true) or rarityValue(t)~=nil
                    or key=="rate" or key=="amount" or key=="rarity" or key=="weight"
                    or key=="depth" or key=="fishname"
                if relevant then
                    rows[#rows+1]={path=o:GetFullName(),parent=o.Parent and o.Parent:GetFullName(),
                        name=o.Name,class=o.ClassName,text=o.Text,
                        x=o.AbsolutePosition.X,y=o.AbsolutePosition.Y,w=o.AbsoluteSize.X,h=o.AbsoluteSize.Y}
                end
            end
        end
        return rows
    end
    local function controlInfo(o)
        if not o then return nil end
        return {path=o:GetFullName(),class=o.ClassName,x=o.AbsolutePosition.X,y=o.AbsolutePosition.Y,
            w=o.AbsoluteSize.X,h=o.AbsoluteSize.Y}
    end
    local function collect()
        local cam=workspace.CurrentCamera
        if not cam then return nil,"Camera indisponivel" end
        if enabled and exclusiveReel then return nil,"Central exclusivo; coleta adiada" end
        if busy or valid(cache) or scan()~=nil or os.clock()-reelLockSince<0.25 then return nil,"Minigame ativo; coleta adiada" end
        local now=os.clock()
        local c=scanControls()
        local hud=hudEvidence()
        local rows={}
        local coverage={weight=0,rarity=0,income=0,visible=0,rarityDirect=0}
        local list={}
        for o in pairs(models) do list[#list+1]=o end
        for index,o in ipairs(list) do
            if not alive then return nil,"Sessao encerrada" end
            if index%16==0 then
                task.wait()
                if enabled and exclusiveReel then return nil,"Central exclusivo; coleta adiada" end
                if busy or valid(cache) or scan()~=nil then return nil,"Minigame ativo; coleta adiada" end
            end
            local ok,row=pcall(fishRecord,o,cam,os.clock())
            if ok and row then
                rows[#rows+1]=row
                coverage.weight=coverage.weight+1
                if row.rarity then coverage.rarity=coverage.rarity+1 end
                if row.raritySource=="attribute" or row.raritySource=="billboard" then coverage.rarityDirect=coverage.rarityDirect+1 end
                if row.incomePerSecond~=nil then coverage.income=coverage.income+1 end
                if row.onScreen then coverage.visible=coverage.visible+1 end
            end
        end
        if not alive or workspace.CurrentCamera~=cam then return nil,"Camera mudou durante leitura" end
        local target=targetModel
        return {started=now,finished=os.clock(),placeId=game.PlaceId,gameId=game.GameId,
            state=stateName,controlEvidence={surface=c.surface==true,underwater=c.underwater==true,
                full=c.full==true,returnSeen=c.returnSeen==true,upSeen=c.upSeen==true,downSeen=c.downSeen==true,
                dive=controlInfo(c.dive),back=controlInfo(c.back),up=controlInfo(c.up),down=controlInfo(c.down)},
            camera={type=cam.CameraType.Name,position=vector(cam.CFrame.Position),look=vector(cam.CFrame.LookVector),
                viewport={x=cam.ViewportSize.X,y=cam.ViewportSize.Y}},
            input={touch=UIS.TouchEnabled,last=lastObservedInput,virtualAvailable=vim~=nil},
            options={farm=farmOn,aim=aimOn,cycle=cycleOn,movement=moveNames[movement],sort=sortNames[sortIndex]},
            filter=filters,selected=target and target.name or nil,reason=farmMessage,
            sentShots=shots,reelInputs=sentCount,coverage=coverage,fish=rows,hud=hud,
            depthDisplay=depthLabel.Text,serverCaptureVerified=false}
    end
    local function showPage()
        pageLabel.Text=string.format("JSON | pagina %d/%d",page,#pages)
        output.Text=pages[page] or ""
    end
    connect(collectButton.Activated,function()
        automatic=not automatic
        collectButton.Text="Coleta automatica: "..(automatic and "ON (fora do Central)" or "OFF")
        paint(collectButton,automatic)
    end)
    connect(snapshotButton.Activated,function() requested=true; summary.Text="Leitura solicitada..." end)
    connect(prevButton.Activated,function() if page>1 then page=page-1; showPage() end end)
    connect(nextButton.Activated,function() if page<#pages then page=page+1; showPage() end end)
    connect(compactButton.Activated,function()
        local recent={}
        for i=math.max(1,#history-5),#history do recent[#recent+1]=history[i] end
        local brief=nil
        if latest then
            brief={state=latest.state,reason=latest.reason,coverage=latest.coverage,
                options=latest.options,filter=latest.filter,selected=latest.selected,
                controls=latest.controlEvidence,depth=latest.depthDisplay,cameraType=latest.camera.type}
        end
        local ok,json=pcall(function()
            return HS:JSONEncode({version="0.33",schema="compact1",sampleCount=sampleCount,
                central={enabled=enabled,exclusive=exclusiveReel,mode=modes[modeIndex].name,
                    begun=stats[modeIndex].began,ended=stats[modeIndex].ended,
                    blockedReason=blockedReason,inputError=inputError,roundChanges=roundChanges},
                farm={shots=shots,shotTransitions=shotTransitions,shotTimeouts=shotTimeouts,aimRequested=aimRequested,aimObserved=aimObserved,aimErrorDegrees=aimErrorDegrees,reason=farmMessage,state=stateName,inputOwner=inputOwner,
                    enabled=farmOn,aim=aimOn,cycle=cycleOn,movement=moveNames[movement]},
                lastError=lastError,latest=brief,history=recent,serverCaptureVerified=false})
        end)
        if not ok then summary.Text="Erro no resumo: "..tostring(json); return end
        pages={json}; page=1; showPage()
        summary.Text="Resumo curto pronto. Copie somente esta pagina."
    end)
    connect(exportButton.Activated,function()
        if not latest then summary.Text="Aguardando uma leitura completa."; return end
        local ok,json=pcall(function()
            return HS:JSONEncode({version="0.33",schema=1,source="client_observation",
                note="No server validation. HUD rows are not joined to individual fish.",
                sampleCount=sampleCount,lastError=lastError,latest=latest,history=history})
        end)
        if not ok then summary.Text="Erro ao gerar JSON: "..tostring(json); return end
        pages={}; page=1
        local first=1
        while first<=#json do
            local last=math.min(#json,first+7999)
            while last<#json and json:byte(last+1)>=128 and json:byte(last+1)<192 do last=last-1 end
            pages[#pages+1]=json:sub(first,last)
            first=last+1
        end
        showPage()
        summary.Text="JSON pronto. Copie as paginas em ordem, sem acrescentar separadores."
    end)
    task.spawn(function()
        local last=-math.huge
        while alive and gui.Parent do
            local now=os.clock()
            if not collecting and (requested or (automatic and now-last>=5)) and now-last>=1 then
                if not busy and not valid(cache) and now-reelLockSince>=0.25 and not (enabled and exclusiveReel) then
                    collecting=true
                    last=now
                    local ok,result,why=pcall(collect)
                    collecting=false
                    if not alive then break end
                    if ok and result then
                        requested=false
                        latest=result
                        sampleCount=sampleCount+1
                        local cov=result.coverage
                        history[#history+1]={t=result.finished,state=result.state,reason=result.reason,position=result.camera.position,
                            coverage=cov,selected=result.selected,sentShots=result.sentShots,reelInputs=result.reelInputs,
                            controlEvidence=result.controlEvidence}
                        if #history>120 then table.remove(history,1) end
                        summary.Text=string.format("Leituras %d | Peixes %d | Raridade %d | Renda %d\nHUD %d rotulos | Estado: %s",sampleCount,cov.weight,cov.rarity,cov.income,#result.hud,result.state)
                    else
                        lastError=ok and why or tostring(result)
                        summary.Text="Coleta: "..tostring(lastError)
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end
print("HarpoonMobile v0.33 | prioridade Central, estado observado e disparo com espera de resposta")
