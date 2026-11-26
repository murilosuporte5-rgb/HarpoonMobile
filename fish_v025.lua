-- HarpoonMobile v0.25 | manual fishing, minigame-only, read-only depth
-- Baseline: fish_v017.lua. Existing input path; no new runtime bypass.
-- Use only in an authorized runtime. Studio/client compatibility not implied.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
if game.GameId~=10764240948 then
    warn("HM v0.25: universo diferente do esperado")
    return
end
local player=Players.LocalPlayer
if not player then return end
local pg=player:WaitForChild("PlayerGui")
for _,name in ipairs({"HarpoonMobileV2","HarpoonMobileV019","HarpoonMobileV020","HarpoonMobileV021","HarpoonMobileV022","HarpoonMobileV023","HarpoonMobileV024","HarpoonMobileV025"}) do
    local old=pg:FindFirstChild(name)
    if old then
        local stop=old:FindFirstChild("Stop")
        if stop and stop:IsA("BindableEvent") then stop:Fire() else old:Destroy() end
    end
end
local alive,enabled,busy=false,false,false
local releaseActive=nil
local vim
pcall(function() vim=game:GetService("VirtualInputManager") end)
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local gui=make("ScreenGui",pg,{Name="HarpoonMobileV025",ResetOnSpawn=false,DisplayOrder=10000,AutoLocalize=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local stop=make("BindableEvent",gui,{Name="Stop"})
local panel=make("Frame",gui,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,8),Size=UDim2.fromOffset(218,220),BackgroundColor3=Color3.fromRGB(19,24,35),Visible=false})
make("UICorner",panel,{CornerRadius=UDim.new(0,12)})
make("UIStroke",panel,{Color=Color3.fromRGB(71,95,131),Thickness=1})
local floating=make("TextButton",gui,{Name="Floating",Position=UDim2.fromOffset(14,104),Size=UDim2.fromOffset(48,48),BackgroundColor3=Color3.fromRGB(24,35,53),TextColor3=Color3.fromRGB(212,232,255),Text="HM",TextSize=16,Font=Enum.Font.GothamBold,AutoLocalize=false})
make("UICorner",floating,{CornerRadius=UDim.new(1,0)})
make("UIStroke",floating,{Color=Color3.fromRGB(86,156,235),Thickness=2})
local function text(class,y,h,value)
    return make(class,panel,{Position=UDim2.fromOffset(6,y),Size=UDim2.new(1,-12,0,h),BackgroundColor3=Color3.fromRGB(40,45,55),BorderSizePixel=0,TextColor3=Color3.fromRGB(245,245,245),TextSize=12,Font=Enum.Font.Gotham,AutoLocalize=false,TextWrapped=true,Text=value})
end
local header=text("TextLabel",6,23,"HARPOON  /  0.25")
header.BackgroundTransparency=1
header.Font=Enum.Font.GothamBold
local toggle=text("TextButton",33,29,"Minigame: OFF")
make("UICorner",toggle,{CornerRadius=UDim.new(0,6)})
local modeButton=text("TextButton",65,28,"Modo: Normal")
make("UICorner",modeButton,{CornerRadius=UDim.new(0,6)})
local depthLabel=text("TextLabel",96,23,"Prof.: ? | Lim.: ?")
depthLabel.BackgroundTransparency=1
local status=text("TextLabel",120,39,"Pesca manual")
status.BackgroundTransparency=1
local auditButton=text("TextButton",161,25,"Auditoria")
make("UICorner",auditButton,{CornerRadius=UDim.new(0,5)})
local close=text("TextButton",190,24,"Encerrar")
make("UICorner",close,{CornerRadius=UDim.new(0,5)})
local auditPanel=make("Frame",gui,{Name="Audit",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.84,0.84),BackgroundColor3=Color3.fromRGB(19,24,35),Visible=false,ZIndex=10})
make("UISizeConstraint",auditPanel,{MaxSize=Vector2.new(420,540)})
make("UICorner",auditPanel,{CornerRadius=UDim.new(0,12)})
local auditScroll=make("ScrollingFrame",auditPanel,{Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,1,-16),CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=11})
make("UIListLayout",auditScroll,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
local auditOrder=0
local function auditControl(class,value,height)
    auditOrder=auditOrder+1
    local o=make(class,auditScroll,{Name="Audit"..auditOrder,LayoutOrder=auditOrder,Size=UDim2.new(1,-6,0,height),BackgroundColor3=Color3.fromRGB(40,45,55),TextColor3=Color3.fromRGB(245,245,245),TextSize=13,Font=Enum.Font.Gotham,TextWrapped=true,Text=value,ZIndex=12,AutoLocalize=false})
    make("UICorner",o,{CornerRadius=UDim.new(0,5)})
    return o
end
local auditHeading=auditControl("TextLabel","AUDITORIA | observacoes manuais",28)
local scenarioButton=auditControl("TextButton","Cenario: captura valida",30)
local snapBefore=auditControl("TextButton","Registrar HUD antes",30)
local beforeBox=auditControl("TextBox","",34)
beforeBox.PlaceholderText="Inventario antes (opcional: inteiro)"
beforeBox.ClearTextOnFocus=false
local snapAfter=auditControl("TextButton","Registrar HUD depois",30)
local afterBox=auditControl("TextBox","",34)
afterBox.PlaceholderText="Inventario depois (opcional: inteiro)"
afterBox.ClearTextOnFocus=false
local verdictButton=auditControl("TextButton","Resultado: inconclusivo",30)
local noteBox=auditControl("TextBox","",50)
noteBox.PlaceholderText="Evidencia observada / condicoes"
noteBox.ClearTextOnFocus=false
noteBox.MultiLine=true
local saveAudit=auditControl("TextButton","Salvar observacao",30)
local auditStatus=auditControl("TextLabel","Sem registros. HUD nao prova estado do servidor.",40)
local reportBox=auditControl("TextBox","",130)
reportBox.ClearTextOnFocus=false
reportBox.MultiLine=true
reportBox.TextEditable=false
reportBox.TextXAlignment=Enum.TextXAlignment.Left
reportBox.TextYAlignment=Enum.TextYAlignment.Top
local closeAudit=auditControl("TextButton","Voltar ao jogo",34)
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
connect(closeAudit.Activated,function() auditPanel.Visible=false end)
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
local modeIndex=1
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
    inputError=nil
    blockedReason=nil
    cache=nil
    latched=false
    roundArc=nil
    candidateArc=nil
    resetMotion()
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
-- Read-only observations of visible inventory labels, not server state.
local scenarios={"Captura valida","Captura incompleta","Cancelamento","Recompensa unica","Profundidade","Alcance","Troca de mundo"}
local scenarioIndex=1
local verdicts={"inconclusivo","aprovado observado","falha observada"}
local verdictIndex=1
local records={}
local beforeSnapshot=nil
local afterSnapshot=nil
local HttpService=game:GetService("HttpService")
local function snapshot()
    local rows={}
    for _,o in ipairs(pg:GetDescendants()) do
        if (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) then
            local t=rendered(o)
            if t:find("BOLSA",1,true) or t:find("BAG",1,true) or t:find("INVENTARIO",1,true) or t:find("INVENTORY",1,true) then
                rows[#rows+1]={name=o.Name,text=o.Text}
            end
        end
    end
    return {time=os.time(),placeId=game.PlaceId,labels=rows,depth=depthLabel.Text,mode=modes[modeIndex].name,inputsStarted=stats[modeIndex].began,inputsEnded=stats[modeIndex].ended}
end
local function count(text)
    if text:match("^%s*$") then return nil,true end
    local n=tonumber(text)
    return n,n~=nil and n==n and n>=0 and n<math.huge and n%1==0
end
connect(scenarioButton.Activated,function()
    scenarioIndex=scenarioIndex%#scenarios+1
    scenarioButton.Text="Cenario: "..scenarios[scenarioIndex]
    beforeSnapshot=nil; afterSnapshot=nil
    beforeBox.Text=""; afterBox.Text=""; noteBox.Text=""
    verdictIndex=1; verdictButton.Text="Resultado: "..verdicts[1]
end)
connect(snapBefore.Activated,function()
    beforeSnapshot=snapshot()
    auditStatus.Text="Antes: "..#beforeSnapshot.labels.." rotulos do HUD. Anote a contagem se conhecida."
end)
connect(snapAfter.Activated,function()
    afterSnapshot=snapshot()
    auditStatus.Text="Depois: "..#afterSnapshot.labels.." rotulos do HUD. Anote a contagem se conhecida."
end)
connect(verdictButton.Activated,function()
    verdictIndex=verdictIndex%#verdicts+1
    verdictButton.Text="Resultado: "..verdicts[verdictIndex]
end)
connect(saveAudit.Activated,function()
    local a,okA=count(beforeBox.Text)
    local b,okB=count(afterBox.Text)
    if not okA or not okB then auditStatus.Text="Contagens devem ser inteiros nao negativos."; return end
    if not beforeSnapshot or not afterSnapshot then auditStatus.Text="Registre os dois momentos antes de salvar."; return end
    if afterSnapshot.time<beforeSnapshot.time then auditStatus.Text="Ordem dos registros invalida."; return end
    if verdictIndex~=1 and not noteBox.Text:match("%S") then auditStatus.Text="Descreva a evidencia do resultado."; return end
    if #records>=100 then auditStatus.Text="Limite de 100 registros. Copie o JSON antes de encerrar."; return end
    local rec={scenario=scenarios[scenarioIndex],before=beforeSnapshot,after=afterSnapshot,manualBefore=a,manualAfter=b,manualDelta=a~=nil and b~=nil and (b-a) or nil,manualVerdict=verdicts[verdictIndex],note=noteBox.Text,serverVerified=false}
    records[#records+1]=rec
    local ok,encoded=pcall(function() return HttpService:JSONEncode({schema=1,version="0.25",source="manual_and_visible_hud",records=records}) end)
    if ok then reportBox.Text=encoded else auditStatus.Text="Falha no JSON; observacao retida."; return end
    auditStatus.Text=#records.." registros. Resultado manual, sem confirmacao do servidor."
    beforeSnapshot=nil; afterSnapshot=nil
    beforeBox.Text=""; afterBox.Text=""; noteBox.Text=""
    verdictIndex=1; verdictButton.Text="Resultado: "..verdicts[1]
end)
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
            warn("HM v0.25 input: "..inputError)
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
print("HarpoonMobile v0.25 | auditoria observacional; sem bypass ou confirmacao do servidor")
