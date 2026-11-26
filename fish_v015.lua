-- HarpoonMobile v0.15 | mobile tabs and structured diagnostics
-- Data schema references: MaximumADHD/Roblox-Client-Tracker, rojo-rbx/rbx-dom,
-- Roblox/luau-tag-utils (public API conventions). No third-party code loaded.
-- Architecture references: Iris (UI state), RbxUtil/Trove (lifecycle),
-- littensy/fishing-minigame (separate components). Original implementation.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
-- Inline independent telemetry core from v013-lab/lab/core.lua.
local lab=(function()
-- Harpoon Lab / telemetry core. Pure Lua/Luau-compatible subset.
-- No Roblox APIs, input injection, network access or remote loader.
local Core = {}
local Session = {}
Session.__index = Session
local states = {unknown=true, surface=true, underwater=true, reel=true, full=true}
local transitions = {
    unknown={surface=true,underwater=true,reel=true,full=true},
    surface={unknown=true,underwater=true},
    underwater={unknown=true,surface=true,reel=true,full=true},
    reel={unknown=true,underwater=true,full=true},
    full={unknown=true,surface=true,underwater=true}
}
local sources = {manual=true, fixture=true, authorized_adapter=true,client_observation=true,timer=true}
local outcomes = {confirmed=true, rejected=true, timeout=true, cancelled=true}
local actions = {dive=true, shot=true, reel=true, return_to_surface=true, move=true, feed=true}
local function validTime(t)
    return type(t)=="number" and t>=0 and t==t and t<math.huge
end
local function nonempty(s)
    return type(s)=="string" and s:match("%S")~=nil
end
local function evidence(source, detail)
    return sources[source]==true and nonempty(detail)
end
local function copy(t)
    local result={}
    for k,v in pairs(t) do result[k]=v end
    return result
end

function Core.new(opts)
    assert(type(opts)=="table" and type(opts.sink)=="function", "sink required")
    assert(nonempty(opts.sessionId), "sessionId required")
    local timeout=opts.timeout or 5
    assert(validTime(timeout) and timeout>0, "invalid timeout")
    local limit=opts.pendingLimit or 64
    assert(validTime(limit) and limit>=1 and limit%1==0, "invalid pending limit")
    return setmetatable({id=opts.sessionId,sink=opts.sink,timeout=timeout,
        pendingLimit=limit,state="unknown",pending={},pendingCount=0,
        lastTime=0,seq=0,nextAction=0,closed=false,
        counts={observations=0,anomalies=0,requested=0,confirmed=0,rejected=0,timeout=0,cancelled=0,captures=0}},Session)
end

-- Commit the event before committing any state mutation. A failed sink returns
-- an explicit error so a caller can retry rather than silently lose a log.
function Session:_emit(kind,t,data)
    if self.closed then return nil,"closed" end
    if not validTime(t) or t<self.lastTime then return nil,"invalid_time" end
    local event=copy(data or {})
    event.kind=kind; event.time=t; event.seq=self.seq+1; event.sessionId=self.id
    local ok,accepted=pcall(self.sink,event)
    if not ok or accepted~=true then return nil,"sink_failed" end
    self.seq=self.seq+1; self.lastTime=t
    return true
end

function Session:observe(state,t,source,detail)
    if not states[state] or not evidence(source,detail) then return nil,"invalid_observation" end
    local anomaly=state~=self.state and not transitions[self.state][state]
    local ok,err=self:_emit("observation",t,{previous=self.state,state=state,source=source,detail=detail,anomaly=anomaly})
    if not ok then return nil,err end
    self.state=state; self.counts.observations=self.counts.observations+1
    if anomaly then self.counts.anomalies=self.counts.anomalies+1 end
    return true
end

-- A requested action is a telemetry record only; this function executes no input.
function Session:begin(action,t)
    if not actions[action] then return nil,"invalid_action" end
    if self.pendingCount>=self.pendingLimit then return nil,"pending_limit" end
    local id=self.nextAction+1
    local ok,err=self:_emit("request",t,{action=action,actionId=id,state=self.state})
    if not ok then return nil,err end
    self.nextAction=id
    self.pending[id]={action=action,deadline=t+self.timeout}
    self.pendingCount=self.pendingCount+1; self.counts.requested=self.counts.requested+1
    return id
end

function Session:resolve(id,outcome,t,source,detail)
    local item=self.pending[id]
    if not item then return nil,"unknown_or_resolved_action" end
    if not outcomes[outcome] then return nil,"invalid_outcome" end
    if not evidence(source,detail) then return nil,"missing_evidence" end
    if not validTime(t) or t<self.lastTime then return nil,"invalid_time" end
    if outcome=="timeout" and t<item.deadline then return nil,"premature_timeout" end
    if outcome=="confirmed" and t>item.deadline then return nil,"expired_action" end
    local ok,err=self:_emit("outcome",t,{actionId=id,action=item.action,outcome=outcome,source=source,detail=detail})
    if not ok then return nil,err end
    self.pending[id]=nil; self.pendingCount=self.pendingCount-1
    self.counts[outcome]=self.counts[outcome]+1
    -- A confirmed shot or minigame is NOT automatically a capture.
    return true
end

function Session:recordCapture(t,source,detail)
    if not evidence(source,detail) then return nil,"missing_evidence" end
    local ok,err=self:_emit("capture",t,{source=source,detail=detail,verified=true})
    if not ok then return nil,err end
    self.counts.captures=self.counts.captures+1
    return true
end

function Session:tick(t)
    if self.closed then return nil,"closed" end
    if not validTime(t) or t<self.lastTime then return nil,"invalid_time" end
    local ids={}
    for id,item in pairs(self.pending) do if t>=item.deadline then ids[#ids+1]=id end end
    table.sort(ids)
    local completed=0
    for _,id in ipairs(ids) do
        local ok,err=self:resolve(id,"timeout",t,"timer","Deadline elapsed without outcome")
        if not ok then return nil,err end
        completed=completed+1
    end
    self.lastTime=t
    return completed
end

function Session:snapshot()
    return {sessionId=self.id,state=self.state,sequence=self.seq,pending=self.pendingCount,
        counts=copy(self.counts),closed=self.closed,lastTime=self.lastTime}
end

function Session:close(t)
    if self.closed then return true end
    if self.pendingCount~=0 then return nil,"pending_actions" end
    local ok,err=self:_emit("close",t,{})
    if not ok then return nil,err end
    self.closed=true
    return true
end

return Core

end)()
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
local journal={events={},first=1,count=0,dropped=0,capacity=2048,errors=0}
journal.session=lab.new({
    sessionId=HttpService:GenerateGUID(false),
    timeout=8,pendingLimit=64,
    sink=function(event)
        local j=journal
        if j.count<j.capacity then
            local index=(j.first+j.count-1)%j.capacity+1
            j.events[index]=event
            j.count=j.count+1
        else
            j.events[j.first]=event
            j.first=j.first%j.capacity+1
            j.dropped=j.dropped+1
        end
        return true
    end
})
function journal:call(method,...)
    local ok,result,err=pcall(self.session[method],self.session,...)
    if not ok or result==nil then self.errors=self.errors+1; self.lastError=tostring(ok and err or result) end
    return ok and result or nil
end
function journal:record(action,sent,detail)
    local now=os.clock()
    local id=self:call("begin",action,now)
    if id and not sent then
        self:call("resolve",id,"rejected",now,"client_observation",tostring(detail or "input not sent"))
    end
    -- Submitted input stays unconfirmed until separate outcome evidence exists.
end
function journal:export()
    local ordered={}
    for i=0,self.count-1 do
        ordered[#ordered+1]=self.events[(self.first+i-1)%self.capacity+1]
    end
    return {session=self.session:snapshot(),events=ordered,dropped=self.dropped,capacity=self.capacity,
        errors=self.errors,lastError=self.lastError,confirmedCaptureAvailable=false}
end
local options = {fish=false, reel=false, dive=false, surface=false, esp=false, aim=false, down=false, up=false, feed=false}
local interval = 0.35
local speciesFilter = ""
local currentState = "unknown"
local lastConfirmedUnderwater=-math.huge
local lastReelSeen=-math.huge
local reelAttempts=0
local reelLastDecision="nenhuma"
local reelNeedle=nil
local reelLatched=false
local reelLastTap=-math.huge
local mouseBusy=false
local lastAimDecision="nenhuma"
local aimFrames=0
local keyBusy=false
local shotBlocked="nenhuma tentativa"
local diveAttempts=0
local diveTransitions=0
local mutationFilter=""
local minIncome=nil
local incomeKeys={"incomepersecond","moneypersecond","cashpersecond","earningspersecond","revenuepersecond"}
local lastDiveRequest=-math.huge
local reelEvidence={}
local lastReelSample=-math.huge
local lastAimSample=-math.huge
local aimSamples={}
local lastTargetReason="nenhum alvo avaliado"
local selectedCount,visibleCount=0,0
local pauseReason="inicializando"
local runtimeErrors=0
local lastRuntimeError="nenhum"
local lastErrorAt=-math.huge
local stateHistory={}
local selectionRevision=0
local previousRevision=-1
local lockedTarget = nil
local aimError = math.huge
local aimBinding = "HarpoonMobileAimV015"
local controlCache = {}
local lastMove,lastFeed = 0,0
local lastScan = 0
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
local function readIncome(obj)
    local value,key=readField(obj,incomeKeys)
    local n=weightNumber(value)
    if n and n==n and n>=0 and n<math.huge then return n,key end
    return nil,nil
end
-- User-entered filter numbers. Do not change the parser for observed model data.
local function parseFilterNumber(raw)
    local t=string.upper(raw:match("^%s*(.-)%s*$"))
    if t=="" then return nil,nil end
    local digits,suffix=t:match("^(%d+[.,]?%d*)%s*([KMBT]?)$")
    if not digits then return nil,"Use 10000, 10K ou 1.5M" end
    if suffix=="" and digits:match("[.,]%d%d%d$") then
        return nil,"Separador ambiguo: use numero sem separador"
    end
    local value=tonumber((digits:gsub(",",".")))
    local mult=({[""]=1,K=1e3,M=1e6,B=1e9,T=1e12})[suffix]
    if not value or not mult or value*mult>=math.huge then return nil,"Valor invalido" end
    return value*mult,nil
end
local filter = 1
local modes = {"Todos", "Grandes", "Peixes", "Maior peso", "Maior tamanho", "Maior renda (campo)"}
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
    local corner=obj:FindFirstChildOfClass("UICorner") or new("UICorner",obj)
    corner.CornerRadius=UDim.new(0,radius or 8)
end
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections,c)
    return c
end
local gui = new("ScreenGui",pg,{Name="HarpoonMobileV2",ResetOnSpawn=false,DisplayOrder=10000,IgnoreGuiInset=false,AutoLocalize=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
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
label(header,"  HARPOON MOBILE  /  0.15",UDim2.new(1,-72,1,0),UDim2.fromOffset(0,0),13)
local minimize = btn(header,"-",UDim2.fromOffset(29,29),UDim2.new(1,-64,0,5))
local close = btn(header,"X",UDim2.fromOffset(29,29),UDim2.new(1,-32,0,5))
local body = new("ScrollingFrame",panel,{Position=UDim2.fromOffset(0,73),Size=UDim2.new(1,0,1,-73),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,730)})
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
connect(f.Activated,function() filter=filter%#modes+1; f.Text="Alvo: "..modes[filter]; selectionRevision=selectionRevision+1 end)
local minus = btn(body,"-",UDim2.fromOffset(38,29),UDim2.fromOffset(10,247))
local delayText = label(body,"Intervalo: 0.35s",UDim2.new(1,-105,0,29),UDim2.fromOffset(57,247),12)
local plus = btn(body,"+",UDim2.fromOffset(38,29),UDim2.new(1,-48,0,247))
local function change(delta)
    interval=math.clamp(math.floor((interval+delta)*20+0.5)/20,0.2,3)
    delayText.Text=string.format("Intervalo: %.2fs",interval)
end
connect(minus.Activated,function() change(-0.1) end)
connect(plus.Activated,function() change(0.1) end)
local counter=label(body,"Alvos: 0 | Tentativas: 0",UDim2.new(1,-20,0,25),UDim2.fromOffset(10,281),12)
local hint=label(body,"Painel aberto nao pausa. Toques sobre painel e campos de texto continuam protegidos.",UDim2.new(1,-20,0,42),UDim2.fromOffset(10,306),11)
hint.TextWrapped=true
local floating = btn(gui,"HM",UDim2.fromOffset(58,58),UDim2.new(1,-10,0.5,0))
floating.AnchorPoint=Vector2.new(0,0)
floating.Position=UDim2.new(1,-68,0.5,-29)
round(floating,29)
floating.BackgroundColor3=Color3.fromRGB(0,112,210)
floating.TextSize=18
floating.ZIndex=100
local function setPanel(open)
    panel.Visible=open
    floating.Text=open and "HM -" or "HM +"
end
setPanel(false)
local floatInput,floatStart,floatOrigin,floatMoved
connect(floating.InputBegan,function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
        floatInput=i; floatStart=Vector2.new(i.Position.X,i.Position.Y)
        floatOrigin=floating.AbsolutePosition-gui.AbsolutePosition
        floatMoved=false
    end
end)
connect(UIS.InputChanged,function(i)
    if not floatInput or (i~=floatInput and i.UserInputType~=Enum.UserInputType.MouseMovement) then return end
    local delta=Vector2.new(i.Position.X,i.Position.Y)-floatStart
    if delta.Magnitude>8 then floatMoved=true end
    if floatMoved then
        local sz=gui.AbsoluteSize
        floating.Position=UDim2.fromOffset(math.clamp(floatOrigin.X+delta.X,0,math.max(0,sz.X-58)),math.clamp(floatOrigin.Y+delta.Y,0,math.max(0,sz.Y-58)))
    end
end)
connect(UIS.InputEnded,function(i)
    if i==floatInput then floatInput=nil end
end)
connect(floating.Activated,function()
    if not floatMoved then setPanel(not panel.Visible) end
    floatMoved=false
end)
connect(minimize.Activated,function() setPanel(false) end)
local rarityInput=new("TextBox",body,{Size=UDim2.new(1,-20,0,30),Position=UDim2.fromOffset(10,350),Text="",PlaceholderText="Raridade exata (vazio = todas)",ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(51,65,85),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(190,205,220),Font=Enum.Font.Gotham,TextSize=12})
round(rarityInput,6)
connect(rarityInput.FocusLost,function() rarityFilter=rarityInput.Text:match("^%s*(.-)%s*$"); if rarityFilter=="" then rarityFilter="Todos" end; selectionRevision=selectionRevision+1 end)
local function weightBox(x,placeholder)
    local b=new("TextBox",body,{Size=UDim2.new(0.5,-15,0,30),Position=UDim2.fromOffset(x,386),Text="",PlaceholderText=placeholder,ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(51,65,85),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(190,205,220),Font=Enum.Font.Gotham,TextSize=12})
    round(b,6)
    return b
end
local low,high=weightBox(10,"Peso minimo"),weightBox(143,"Peso maximo")
-- Validate numeric fields as a single transaction below, after creating the page.
local speciesInput=new("TextBox",body,{Size=UDim2.new(1,-20,0,30),Position=UDim2.fromOffset(10,423),Text="",PlaceholderText="Especie (ex.: MidnightShark)",ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(51,65,85),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(190,205,220),Font=Enum.Font.Gotham,TextSize=12})
round(speciesInput,6)
connect(speciesInput.FocusLost,function() speciesFilter=string.lower(speciesInput.Text:match("^%s*(.-)%s*$")); selectionRevision=selectionRevision+1 end)
toggle("aim","Acompanhar mira",459)
toggle("down","Descer (limites normais)",493)
toggle("up","Subir (limites normais)",527)
toggle("feed","Auto Feed (menu aberto)",561)
local diagnostic=btn(body,"GERAR DIAGNOSTICO",UDim2.new(1,-20,0,34),UDim2.fromOffset(10,599))
local pause=btn(body,"PAUSAR TODOS",UDim2.new(1,-20,0,34),UDim2.fromOffset(10,640))
connect(pause.Activated,function()
    for k,v in pairs(buttons) do
        options[k]=false
        v.button.Text=v.title.."  [OFF]"
        v.button.BackgroundColor3=Color3.fromRGB(51,65,85)
    end
end)
-- Arrange the existing controls into pages. No gameplay logic is changed.
local tabbar=new("Frame",panel,{Position=UDim2.fromOffset(0,39),Size=UDim2.new(1,0,0,34),BackgroundColor3=Color3.fromRGB(15,23,42),BorderSizePixel=0})
local pages={Controle=body}
local function page(name)
    local p=new("ScrollingFrame",panel,{Name=name,Position=UDim2.fromOffset(0,73),Size=UDim2.new(1,0,1,-73),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,0),Visible=false})
    pages[name]=p
    return p
end
local filtersPage=page("Filtros")
local dataPage=page("Dados")
local function move(o,parent,y)
    local x=o.Position.X
    o.Parent=parent
    o.Position=UDim2.new(x.Scale,x.Offset,0,y)
end
local order={"fish","reel","dive","surface","esp","aim","down","up","feed"}
for i,k in ipairs(order) do move(buttons[k].button,body,42+(i-1)*34) end
move(minus,body,352); move(plus,body,352); move(delayText,body,352)
move(counter,body,390); move(hint,body,419); move(pause,body,470)
body.CanvasSize=UDim2.fromOffset(0,515)
local filterInfo=label(filtersPage,"Peso bruto. Use 10K, 1.5M. Renda e raridade exigem dados conhecidos.",UDim2.new(1,-20,0,45),UDim2.fromOffset(10,5),12)
filterInfo.TextWrapped=true
move(f,filtersPage,56); move(speciesInput,filtersPage,94); move(rarityInput,filtersPage,132)
move(low,filtersPage,170); move(high,filtersPage,170)
local mutationInput=new("TextBox",filtersPage,{Size=UDim2.new(1,-20,0,30),Position=UDim2.fromOffset(10,208),Text="",PlaceholderText="Mutacao (ex.: Silver)",ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(51,65,85),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(190,205,220),Font=Enum.Font.Gotham,TextSize=12})
round(mutationInput,6)
connect(mutationInput.FocusLost,function()
    mutationFilter=string.lower(mutationInput.Text:match("^%s*(.-)%s*$"))
    selectionRevision=selectionRevision+1
end)
local incomeInput=new("TextBox",filtersPage,{Size=UDim2.new(1,-20,0,30),Position=UDim2.fromOffset(10,246),Text="",PlaceholderText="Renda/s minima (se conhecida)",ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(51,65,85),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(190,205,220),Font=Enum.Font.Gotham,TextSize=12})
round(incomeInput,6)
local filterStatus=label(filtersPage,"Edite e aplique os limites numericos.",UDim2.new(1,-20,0,68),UDim2.fromOffset(10,326),12)
filterStatus.TextWrapped=true
local function applyNumbers()
    local lo,e1=parseFilterNumber(low.Text)
    local hi,e2=parseFilterNumber(high.Text)
    local inc,e3=parseFilterNumber(incomeInput.Text)
    local err=e1 or e2 or e3
    if not err and lo and hi and lo>hi then err="Minimo maior que maximo" end
    if err then
        filterStatus.Text="Nao aplicado: "..err..". Limites anteriores preservados."
        filterStatus.TextColor3=Color3.fromRGB(255,174,128)
        return false
    end
    minWeight,maxWeight,minIncome=lo,hi,inc
    selectionRevision=selectionRevision+1
    filterStatus.Text="Aplicado: peso bruto "..tostring(lo or "livre").." a "..tostring(hi or "livre").." | renda/s "..tostring(inc or "livre")
    filterStatus.TextColor3=Color3.fromRGB(170,240,205)
    return true
end
local applyFilters=btn(filtersPage,"APLICAR LIMITES",UDim2.new(1,-20,0,34),UDim2.fromOffset(10,402))
connect(applyFilters.Activated,applyNumbers)
local coverageBtn=btn(filtersPage,"VER COBERTURA DOS DADOS",UDim2.new(1,-20,0,34),UDim2.fromOffset(10,444))
connect(coverageBtn.Activated,function()
    local count,weight,rarity,income=0,0,0,0
    for obj in pairs(models) do
        if obj:IsDescendantOf(workspace) then
            count=count+1
            if weightNumber(readField(obj,weightKeys))~=nil then weight=weight+1 end
            if readField(obj,rarityKeys)~=nil then rarity=rarity+1 end
            if readIncome(obj)~=nil then income=income+1 end
        end
    end
    filterStatus.Text=string.format("Modelos: %d | peso: %d | raridade: %d | renda/s: %d. Dados ausentes nao sao zero.",count,weight,rarity,income)
    filterStatus.TextColor3=Color3.fromRGB(238,242,255)
end)
local clearFilters=btn(filtersPage,"LIMPAR FILTROS",UDim2.new(1,-20,0,34),UDim2.fromOffset(10,284))
connect(clearFilters.Activated,function()
    filter=1; f.Text="Alvo: "..modes[filter]
    speciesFilter=""; speciesInput.Text=""
    rarityFilter="Todos"; rarityInput.Text=""
    minWeight=nil; maxWeight=nil; low.Text=""; high.Text=""
    mutationFilter=""; mutationInput.Text=""; minIncome=nil; incomeInput.Text=""
    filterStatus.Text="Filtros redefinidos."
    filterStatus.TextColor3=Color3.fromRGB(238,242,255)
    selectionRevision=selectionRevision+1
end)
filtersPage.CanvasSize=UDim2.fromOffset(0,486)
local dataInfo=label(dataPage,"Relatorio da sessao: estados, erros, pesos e atributos observados.",UDim2.new(1,-20,0,54),UDim2.fromOffset(10,5),12)
dataInfo.TextWrapped=true
dataInfo.Text="TXT resumido ou JSON com observacoes e historico estruturado da sessao."
move(diagnostic,dataPage,67)
local endButton=btn(dataPage,"ENCERRAR PAINEL E LIMPAR",UDim2.new(1,-20,0,34),UDim2.fromOffset(10,110))
connect(endButton.Activated,function() stop:Fire() end)
local manualCaptures=new("TextBox",dataPage,{Size=UDim2.new(1,-20,0,32),Position=UDim2.fromOffset(10,153),Text="",PlaceholderText="Capturas observadas por voce (opcional)",ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(51,65,85),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(190,205,220),Font=Enum.Font.Gotham,TextSize=12})
round(manualCaptures,6)
dataPage.CanvasSize=UDim2.fromOffset(0,200)
local tabButtons={}
local function showTab(name)
    for n,p in pairs(pages) do p.Visible=(n==name) end
    for n,b in pairs(tabButtons) do b.BackgroundColor3=n==name and Color3.fromRGB(0,112,210) or Color3.fromRGB(51,65,85) end
end
for i,name in ipairs({"Controle","Filtros","Dados"}) do
    local b=btn(tabbar,name,UDim2.new(1/3,-6,0,28),UDim2.new((i-1)/3,3,0,3))
    tabButtons[name]=b
    connect(b.Activated,function() showTab(name) end)
end
showTab("Controle")
local diagFrame=new("Frame",gui,{Size=UDim2.new(0.85,0,0.8,0),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.fromRGB(15,23,42),Visible=false,ZIndex=20})
round(diagFrame,10)
local diagClose=btn(diagFrame,"Fechar",UDim2.fromOffset(70,32),UDim2.new(1,-78,0,6))
local copyBtn=btn(diagFrame,"COPIAR",UDim2.fromOffset(80,32),UDim2.new(1,-166,0,6))
local formatBtn=btn(diagFrame,"JSON",UDim2.fromOffset(58,32),UDim2.new(1,-232,0,6))
formatBtn.ZIndex=22
local reportText,reportJson="", ""
local jsonMode=false
copyBtn.ZIndex=22
diagClose.ZIndex=22
label(diagFrame,"  Diagnostico (dados visiveis)",UDim2.new(1,-240,0,38),UDim2.fromOffset(0,0),13).ZIndex=21
local diagScroll=new("ScrollingFrame",diagFrame,{Position=UDim2.fromOffset(8,45),Size=UDim2.new(1,-16,1,-53),CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ScrollBarThickness=5,ZIndex=21})
local diagText=new("TextBox",diagScroll,{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,MultiLine=true,TextWrapped=true,TextEditable=true,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text="",TextSize=12,Font=Enum.Font.Code,BackgroundColor3=Color3.fromRGB(30,41,59),TextColor3=Color3.new(1,1,1),ZIndex=22})
connect(diagClose.Activated,function() diagFrame.Visible=false end)
connect(formatBtn.Activated,function()
    jsonMode=not jsonMode
    diagText.Text=jsonMode and reportJson or reportText
    formatBtn.Text=jsonMode and "TXT" or "JSON"
end)
connect(copyBtn.Activated,function()
    local ok=false
    if type(setclipboard)=="function" then
        ok=pcall(setclipboard,diagText.Text)
    elseif type(toclipboard)=="function" then
        ok=pcall(toclipboard,diagText.Text)
    end
    if ok then copyBtn.Text="COPIADO" else
        copyBtn.Text="SELECIONAR"
        diagText:CaptureFocus()
        pcall(function() diagText.CursorPosition=#diagText.Text+1; diagText.SelectionStart=1 end)
    end
    task.delay(2,function() if copyBtn.Parent then copyBtn.Text="COPIAR" end end)
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
    if obj:IsA("Model") and obj.Name~="FishRoll" and contains(string.lower(obj.Name),keywords) and not Players:GetPlayerFromCharacter(obj) then models[obj]=true end
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
    local categoryOK=filter==1 or filter>=4 or (filter==2 and contains(n,large)) or (filter==3 and contains(n,{"fish","peixe"}))
    if not categoryOK then return false end
    if speciesFilter~="" and not string.find(n,speciesFilter,1,true) then return false end
    if mutationFilter~="" and string.lower(tostring(obj:GetAttribute("Mutation") or ""))~=mutationFilter then return false end
    if minIncome or filter==6 then
        local income=readIncome(obj)
        if income==nil or (minIncome and income<minIncome) then return false end
    end
    if rarityFilter~="Todos" then
        local rarity=readField(obj,rarityKeys)
        if rarity==nil or string.lower(tostring(rarity))~=string.lower(rarityFilter) then return false end
    end
    if minWeight and maxWeight and minWeight>maxWeight then return false end
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
    local t=(s or ""):gsub("<[^>]*>",""):gsub("^%s+",""):gsub("%s+$","")
    for a,b in pairs({["Ç"]="C",["ç"]="c",["Ã"]="A",["ã"]="a",["Á"]="A",["á"]="a",["É"]="E",["é"]="e",["Ê"]="E",["ê"]="e",["Í"]="I",["í"]="i",["Ó"]="O",["ó"]="o",["Ú"]="U",["ú"]="u"}) do
        t=t:gsub(a,b)
    end
    return string.upper(t):gsub("%s+"," ")
end
local function renderedText(o)
    local ok,value=pcall(function() return o.ContentText end)
    return ok and type(value)=="string" and value~="" and value or o.Text
end
local function controls()
    local found={texts={},buttons={},evidence={},returnText=false,underwater=false,full=false,up=false,down=false,diveText=false}
    local cam=workspace.CurrentCamera
    local viewport=cam and cam.ViewportSize or Vector2.new(800,450)
    local function onScreen(o)
        local p,z=o.AbsolutePosition,o.AbsoluteSize
        return p.X+z.X>0 and p.Y+z.Y>0 and p.X<viewport.X and p.Y<viewport.Y
    end
    local function buttonFor(o)
        if o:IsA("GuiButton") then return o end
        return o:FindFirstAncestorWhichIsA("GuiButton")
    end
    for _,o in ipairs(pg:GetDescendants()) do
        if (o:IsA("TextButton") or o:IsA("TextLabel")) and visible(o) and onScreen(o) and o.AbsoluteSize.X>3 and o.AbsoluteSize.Y>3 then
            local t=normalized(renderedText(o))
            local b=buttonFor(o)
            local function evidence(key)
                found.evidence[key]=t.." | "..o.Name
            end
            if t=="DIVE" or t=="MERGULHAR" or t=="DIVE IN" then if b then found.dive=b else found.dive=o end; found.diveText=true; evidence("dive")
            elseif (t=="CLICK" or t=="CLIQUE" or t=="TAP" or t=="TOQUE") and (o.Name=="Key" or b) then found.reel=b or o; found.reelLabel=o; evidence("reel")
            elseif t=="RETURN" or t=="VOLTAR" or t=="RETORNAR" then found.returnButton=b or o; found.returnText=true; evidence("return")
            elseif t=="SPACE" or t=="ESPACO" then found.spaceText=true; evidence("space")
            elseif string.find(t,"SPACE TO RETURN",1,true) or string.find(t,"ESPACO PARA VOLTAR",1,true) or string.find(t,"PRESS SPACE TO RETURN",1,true) then found.returnText=true; evidence("returnPrompt")
            elseif t=="SUBIR" or t=="ASCEND" then found.up=true; evidence("up")
            elseif t=="DESCER" or t=="DESCEND" then found.down=true; evidence("down")
            elseif string.find(t,"BOLSA CHEIA",1,true) or string.find(t,"BAG FULL",1,true) then found.full=true; evidence("full")
            elseif t=="FEED" or t=="ALIMENTAR" then if b then found.feed=b; evidence("feed") end
            end
        end
    end
    found.cameraScriptable=cam~=nil and cam.CameraType==Enum.CameraType.Scriptable
    found.underwater=not found.diveText and (found.full or (found.up and found.down) or (found.returnText and found.cameraScriptable))
    return found
end
local function center(o)
    local p=o.AbsolutePosition+o.AbsoluteSize/2
    local root=o:FindFirstAncestorWhichIsA("ScreenGui")
    if root and not root.IgnoreGuiInset then
        local inset=GuiService:GetGuiInset()
        return p+inset
    end
    return p
end
local lastInput="nenhum teste"
local eventLog={}
local inputLogLimit=500
local function log(message)
    table.insert(eventLog,string.format("%.2f %s",os.clock(),message))
    if #eventLog>inputLogLimit then table.remove(eventLog,1) end
end
local function recordError(err)
    runtimeErrors=runtimeErrors+1
    local message=tostring(err):sub(1,400)
    local now=os.clock()
    if message~=lastRuntimeError or now-lastErrorAt>3 then
        log("erro: "..message); lastErrorAt=now
    end
    lastRuntimeError=message
end
local function tap(point)
    if not alive then return false,"Painel encerrado" end
    if not vim then lastInput="Entrada virtual indisponivel"; log(lastInput); return false,lastInput end
    if diagFrame.Visible or GuiService.MenuIsOpen or UIS:GetFocusedTextBox() then lastInput="Entrada pausada: menu/diagnostico/teclado"; return false,lastInput end
    local inset=GuiService:GetGuiInset()
    local function covered(obj)
        local p,sz=obj.AbsolutePosition,obj.AbsoluteSize
        local function inRect(a) return point.X>=a.X and point.X<=a.X+sz.X and point.Y>=a.Y and point.Y<=a.Y+sz.Y end
        return inRect(p) or inRect(p+inset)
    end
    if panel.Visible and covered(panel) then return false,"Alvo coberto pelo dashboard" end
    local cam=workspace.CurrentCamera
    if not cam then return false,"Camera indisponivel" end
    if point.X<8 or point.X>cam.ViewportSize.X-8 or point.Y<60 or point.Y>cam.ViewportSize.Y-8 then return false,"Coordenada fora da area permitida" end
    if covered(floating) then return false,"Botao HM sobre a entrada" end
    if mouseBusy or keyBusy then return false,"Entrada ocupada" end
    mouseBusy=true
    local x,y=math.floor(point.X),math.floor(point.Y)
    local pressed=false
    local ok,err=pcall(function()
        vim:SendMouseButtonEvent(x,y,0,true,game,0)
        pressed=true
        task.wait(0.045)
        vim:SendMouseButtonEvent(x,y,0,false,game,0)
        pressed=false
    end)
    if pressed then pcall(function() vim:SendMouseButtonEvent(x,y,0,false,game,0) end) end
    mouseBusy=false
    lastInput=ok and "Toque enviado (captura nao confirmada)" or tostring(err):sub(1,220)
    log(string.format("input (%d,%d): %s",math.floor(point.X),math.floor(point.Y),lastInput))
    return ok,ok and "Toque enviado" or "Entrada bloqueada: veja diagnostico"
end
local function keyPress(key,hold)
    if keyBusy or mouseBusy or not alive then return false end
    if not vim or GuiService.MenuIsOpen or diagFrame.Visible or UIS:GetFocusedTextBox() then lastInput="Tecla bloqueada: entrada indisponivel ou menu aberto"; log(lastInput); return false end
    keyBusy=true
    local ok,err=pcall(function()
        vim:SendKeyEvent(true,key,false,game)
        task.wait(hold or 0.08)
        vim:SendKeyEvent(false,key,false,game)
    end)
    if not ok then pcall(function() vim:SendKeyEvent(false,key,false,game) end) end
    keyBusy=false
    lastInput="tecla "..key.Name..": "..(ok and "enviada" or tostring(err))
    log(lastInput)
    return ok
end
local function target()
    selectedCount,visibleCount=0,0
    local cam=workspace.CurrentCamera
    if not cam then return nil end
    local mid=cam.ViewportSize/2
    local best,score
    for obj in pairs(models) do
        if selected(obj) and obj:IsDescendantOf(workspace) then
            selectedCount=selectedCount+1
            local part=obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true)
            if part then
                local cf,size=obj:GetBoundingBox()
                local p,on=cam:WorldToViewportPoint(cf.Position)
                if on and p.Z>0 then
                    visibleCount=visibleCount+1
                    local v=Vector2.new(p.X,p.Y)
                    local n=(v-mid).Magnitude
                    local w=weightNumber(readField(obj,weightKeys))
                    if filter==4 then
                        n=w and -w or math.huge
                    elseif filter==5 then
                        local sz=obj:GetAttribute("Size")
                        n=type(sz)=="number" and -sz or math.huge
                    elseif filter==6 then
                        local income=readIncome(obj)
                        n=income and -income or math.huge
                    end
                    if n<math.huge and (not score or n<score) then
                        best={point=v,name=obj.Name,weight=w,depth=p.Z,object=obj}; score=n
                    end
                end
            end
        end
    end
    lastTargetReason=best and ("alvo="..best.name.." peso="..tostring(best.weight)) or string.format("sem alvo: %d filtrados, %d na tela",selectedCount,visibleCount)
    return best
end
local function cleanup(skipDestroy)
    if not alive then return end
    alive=false
    -- Do not mark pending requests as successful on shutdown.
    local t=os.clock()
    for id in pairs(journal.session.pending) do journal:call("resolve",id,"cancelled",t,"client_observation","Sessao encerrada") end
    journal:call("close",t)
    pcall(function() RunService:UnbindFromRenderStep(aimBinding) end)
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    for _,h in pairs(highlights) do pcall(function() h:Destroy() end) end
    table.clear(highlights)
    table.clear(models)
    if not skipDestroy then gui:Destroy() end
end
connect(stop.Event,function() cleanup(false) end)
connect(gui.Destroying,function() cleanup(true) end)
connect(close.Activated,function() setPanel(false) end)
connect(RunService.RenderStepped,function(dt)
    local ok,err=xpcall(function()
    aimError=math.huge
    if not alive or not options.aim then return end
    aimFrames=aimFrames+1
    if currentState~="underwater" or diagFrame.Visible or GuiService.MenuIsOpen or UIS:GetFocusedTextBox() then lastAimDecision="pausada: "..currentState; return end
    local cam=workspace.CurrentCamera
    local obj=lockedTarget and lockedTarget.object
    if not cam or not obj or not obj:IsDescendantOf(workspace) or not selected(obj) then lastAimDecision="sem alvo valido"; return end
    local ok,cf=pcall(function() return obj:GetBoundingBox() end)
    if not ok then lastAimDecision="bounding box indisponivel"; return end
    local direction=cf.Position-cam.CFrame.Position
    if direction.Magnitude<0.5 then return end
    local before=math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(direction.Unit),-1,1)))
    local goal=CFrame.lookAt(cam.CFrame.Position,cf.Position)
    cam.CFrame=goal
    aimError=math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(direction.Unit),-1,1)))
    lastAimDecision=string.format("%s | antes=%.2f depois=%.2f",obj.Name,before,aimError)
    if os.clock()-lastAimSample>=0.5 then
        lastAimSample=os.clock()
        table.insert(aimSamples,string.format("%.2f | %s | antes=%.2f depois=%.2f",lastAimSample,obj.Name,before,aimError))
        if #aimSamples>30 then table.remove(aimSamples,1) end
    end
    end,function(e) return tostring(e) end)
    if not ok and alive then aimError=math.huge; recordError(err) end
end)
-- Report only the text already presented to the player. Bounds are a
-- conservative approximation: visual occlusion by another GUI is not tested.
local function reportHud()
    local cam=workspace.CurrentCamera
    local result={rates={},labels={},outsideRateCount=0,unparsedRateCount=0,
        truncated=false,visibility="viewport and clipping bounds; occlusion not checked"}
    if not cam then return result end
    local function intersects(o)
        local p,z=o.AbsolutePosition,o.AbsoluteSize
        local left,top=math.max(0,p.X),math.max(0,p.Y)
        local right,bottom=math.min(cam.ViewportSize.X,p.X+z.X),math.min(cam.ViewportSize.Y,p.Y+z.Y)
        local a=o.Parent
        while a and a~=pg do
            if a:IsA("GuiObject") and a.ClipsDescendants then
                local ap,az=a.AbsolutePosition,a.AbsoluteSize
                left=math.max(left,ap.X); top=math.max(top,ap.Y)
                right=math.min(right,ap.X+az.X); bottom=math.min(bottom,ap.Y+az.Y)
            end
            a=a.Parent
        end
        return right>left and bottom>top
    end
    local function rate(t)
        local digits,suffix,unit=t:match("^%$%s*(%d+[.,]?%d*)%s*([KMBT]?)%s*/%s*([A-Z]+)$")
        if not digits then return nil end
        if suffix=="" and digits:match(",%d%d%d$") then return nil end
        local n=tonumber((digits:gsub(",",".")))
        local multiplier=({[""]=1,K=1000,M=1000000,B=1000000000,T=1000000000000})[suffix]
        local seconds=({S=1,SEC=1,SEG=1,MIN=60,M=60})[unit]
        if not n or not multiplier or not seconds then return nil end
        local value=n*multiplier/seconds
        if value~=value or value==math.huge then return nil end
        return value
    end
    local known={
        ["COMUM"]=true,["COMMON"]=true,["MERGULHAR"]=true,["DIVE"]=true,
        ["SUBIR"]=true,["DESCER"]=true,["ASCEND"]=true,["DESCEND"]=true,
        ["ALIMENTAR PEIXES"]=true,["ALIMENTAR"]=true,["FEED"]=true,
        ["CRESCER"]=true,["CRESCER AGORA"]=true,
        ["EQUIPAR MELHORES"]=true,["EQUIPAR MELHORES $/S BASE"]=true,
        ["APERTA ESPACO PARA VOLTAR"]=true,["APERTE ESPACO PARA VOLTAR"]=true,
        ["PRESS SPACE TO RETURN"]=true
    }
    for _,o in ipairs(pg:GetDescendants()) do
        if (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) then
            local t=normalized(renderedText(o))
            local isRate=t:match("^%$") and t:find("/",1,true)
            local isLabel=known[t] or t:match("^%d+/%d+$") or
                (o.Name=="Weight" and t:match("KG$")) or t:match("^%d+/%d+ ATIVOS$")
            if isRate or isLabel then
                if intersects(o) then
                    if #result.rates+#result.labels>=250 then
                        result.truncated=true
                    elseif isRate then
                        local value=rate(t)
                        if value~=nil then
                            result.rates[#result.rates+1]={display=t,perSecond=value,label=o.Name,association="unknown"}
                        else result.unparsedRateCount=result.unparsedRateCount+1 end
                    else result.labels[#result.labels+1]={display=t,label=o.Name} end
                elseif isRate then result.outsideRateCount=result.outsideRateCount+1 end
            end
        end
    end
    table.sort(result.rates,function(a,b) return a.perSecond>b.perSecond end)
    return result
end
local function summarizeJournal(audit)
    local summary={}
    for _,event in ipairs(audit.events) do
        if event.action and (event.kind=="request" or event.kind=="outcome") then
            local row=summary[event.action] or {requested=0,rejected=0,unverified=0,confirmed=0,cancelled=0}
            summary[event.action]=row
            if event.kind=="request" then row.requested=row.requested+1
            elseif event.outcome=="timeout" then row.unverified=row.unverified+1
            elseif row[event.outcome]~=nil then row[event.outcome]=row[event.outcome]+1 end
        end
    end
    return summary
end
local function buildDiagnostic()
    local audit=journal:export()
    local hud=reportHud()
    local perAction=summarizeJournal(audit)
    local entered=manualCaptures.Text:match("^%s*(%d+)%s*$")
    local reportedCaptures=entered and tonumber(entered) or nil
    if reportedCaptures and (reportedCaptures>1000000000 or reportedCaptures<0) then reportedCaptures=nil end
    local lines={"HarpoonMobile v0.15", "PlaceId: "..tostring(game.PlaceId), "GameId: "..tostring(game.GameId), "Estado: "..currentState, "Pausa anterior: "..pauseReason, "Entrada virtual: "..lastInput, "Tentativas: "..tostring(attempts)}
    local activeOptions={}
    for k,v in pairs(options) do if v then table.insert(activeOptions,k) end end
    table.sort(activeOptions)
    table.insert(lines,"Modulos ativos: "..table.concat(activeOptions,","))
    table.insert(lines,"=== Sessao e evidencias ===")
    table.insert(lines,"Sessao: "..audit.session.sessionId)
    table.insert(lines,string.format("Solicitacoes: %d | rejeitadas: %d | expiradas: %d | pendentes: %d",audit.session.counts.requested,audit.session.counts.rejected,audit.session.counts.timeout,audit.session.pending))
    table.insert(lines,"Capturas confirmadas automaticamente: indisponivel (sem evidencia independente)")
    table.insert(lines,"Capturas informadas manualmente: "..tostring(reportedCaptures or "nao informado"))
    table.insert(lines,"Expiradas = resultado nao confirmado, nao prova de falha.")
    table.insert(lines,"=== Resumo de acoes no buffer ===")
    local names={}
    for name in pairs(perAction) do names[#names+1]=name end
    table.sort(names)
    for _,name in ipairs(names) do
        local a=perAction[name]
        table.insert(lines,string.format("%s: solicitadas=%d rejeitadas=%d sem confirmacao=%d confirmadas=%d canceladas=%d",name,a.requested,a.rejected,a.unverified,a.confirmed,a.cancelled))
    end
    table.insert(lines,"=== Informacoes exibidas no HUD ===")
    table.insert(lines,"Valores economicos sem associacao confirmada a peixe individual")
    for _,v in ipairs(hud.rates) do table.insert(lines,v.display.." | "..v.label.." | por segundo="..tostring(v.perSecond)) end
    for _,v in ipairs(hud.labels) do table.insert(lines,v.display.." | "..v.label) end
    table.insert(lines,"Valores fora da tela excluidos: "..hud.outsideRateCount.." | nao interpretados: "..hud.unparsedRateCount)
    table.insert(lines,string.format("Eventos estruturados: %d | descartados do buffer: %d | erros de registro: %d",#audit.events,audit.dropped,audit.errors))
    table.insert(lines,string.format("Erros de runtime: %d | ultimo: %s",runtimeErrors,lastRuntimeError))
    table.insert(lines,string.format("Filtros: especie=%s raridade=%s min=%s max=%s modo=%s intervalo=%.2f",speciesFilter,rarityFilter,tostring(minWeight),tostring(maxWeight),modes[filter],interval))
    table.insert(lines,"Entrada virtual disponivel: "..tostring(vim~=nil))
    table.insert(lines,"Selecao: "..lastTargetReason)
    table.insert(lines,"Ultima decisao de mira: "..lastAimDecision.." | frames: "..aimFrames)
    table.insert(lines,"Disparo: "..shotBlocked)
    table.insert(lines,"Mergulho: "..diveAttempts.." tentativas | "..diveTransitions.." transicoes observadas")
    table.insert(lines,"Filtros adicionais: mutacao="..mutationFilter.." renda minima="..tostring(minIncome))
    table.insert(lines,"Tentativas reel: "..tostring(reelAttempts).." | ultima: "..reelLastDecision)
    table.insert(lines,"=== Amostras de mira ===")
    for _,v in ipairs(aimSamples) do table.insert(lines,v) end
    table.insert(lines,"=== Amostras do minigame (somente interface visivel) ===")
    for _,v in ipairs(reelEvidence) do table.insert(lines,v) end
    table.insert(lines,"TouchEnabled: "..tostring(UIS.TouchEnabled).." | KeyboardEnabled: "..tostring(UIS.KeyboardEnabled))
    local c=controls()
    for _,k in ipairs({"underwater","cameraScriptable","full","returnText","returnButton","spaceText","up","down","diveText","dive","reel","feed"}) do
        local x=c[k]
        table.insert(lines,k..": "..(typeof(x)=="Instance" and (x.Name.." ["..x.ClassName.."]") or tostring(x)))
    end
    for k,v in pairs(c.evidence or {}) do table.insert(lines,"evidencia "..k..": "..v) end
    local cam=workspace.CurrentCamera
    if cam then table.insert(lines,"Viewport: "..tostring(cam.ViewportSize).." | camera: "..tostring(cam.CameraType)) end
    local groups={}
    local records={}
    local coverage={models=0,weight=0,size=0,mutation=0,rarity=0,archetype=0,invalidWeight=0,incomePerSecond=0}
    for obj in pairs(models) do
        if obj:IsDescendantOf(workspace) then
            local name=obj.Name
            local g=groups[name] or {count=0,weights={},rarities={},attributes={},mutations={},knownSizeCount=0,knownRarityCount=0,knownMutationCount=0}
            groups[name]=g
            g.count=g.count+1
            local w=weightNumber(readField(obj,weightKeys))
            local rare=readField(obj,rarityKeys)
            local attrs=obj:GetAttributes()
            local size=attrs.Size
            local mutation=attrs.Mutation
            local archetype=attrs.Archetype
            local function validNumber(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
            coverage.models=coverage.models+1
            if validNumber(w) and w>=0 then
                table.insert(g.weights,w)
                coverage.weight=coverage.weight+1
            else
                if w~=nil then coverage.invalidWeight=coverage.invalidWeight+1 end
                w=nil
            end
            if type(rare)=="string" and rare~="" or validNumber(rare) then
                g.rarities[tostring(rare)]=true
                g.knownRarityCount=g.knownRarityCount+1
                coverage.rarity=coverage.rarity+1
            else rare=nil end
            if validNumber(size) and size>=0 then
                coverage.size=coverage.size+1
                g.knownSizeCount=g.knownSizeCount+1
            else size=nil end
            if type(mutation)=="string" and mutation~="" then
                coverage.mutation=coverage.mutation+1
                g.knownMutationCount=g.knownMutationCount+1
                g.mutations[mutation]=true
            else mutation=nil end
            if type(archetype)=="string" and archetype~="" then
                coverage.archetype=coverage.archetype+1
            else archetype=nil end
            local income,incomeField=readIncome(obj)
            if income~=nil then coverage.incomePerSecond=coverage.incomePerSecond+1 end
            table.insert(records,{species=name,weight=w,size=size,mutation=mutation,rarity=rare,archetype=archetype,incomePerSecond=income,incomeField=incomeField})
            for k,v in pairs(obj:GetAttributes()) do
                if table.find(rarityKeys,string.lower(k)) or table.find(weightKeys,string.lower(k)) then g.attributes[k]=typeof(v) end
            end
        end
    end
    table.sort(records,function(a,b)
        if a.species~=b.species then return a.species<b.species end
        if (a.weight or -1)~=(b.weight or -1) then return (a.weight or -1)<(b.weight or -1) end
        return (a.mutation or "")<(b.mutation or "")
    end)
    table.insert(lines,"=== Cobertura dos dados ===")
    for _,k in ipairs({"models","weight","size","mutation","rarity","archetype","invalidWeight","incomePerSecond"}) do
        table.insert(lines,k..": "..tostring(coverage[k]).." / "..tostring(coverage.models))
    end
    local speciesRows={}
    local sorted={}
    for name in pairs(groups) do table.insert(sorted,name) end
    table.sort(sorted)
    table.insert(lines,"=== Todas as especies reconhecidas (resumo de pesos) ===")
    for _,name in ipairs(sorted) do
        local g=groups[name]
        table.sort(g.weights)
        local rarities={}
        for v in pairs(g.rarities) do table.insert(rarities,v) end
        table.sort(rarities)
        local mutations={}
        for v in pairs(g.mutations) do table.insert(mutations,v) end
        table.sort(mutations)
        table.insert(speciesRows,{name=name,count=g.count,knownWeightCount=#g.weights,minWeight=g.weights[1],maxWeight=g.weights[#g.weights],rarities=rarities,mutations=mutations,knownRarityCount=g.knownRarityCount,knownMutationCount=g.knownMutationCount,knownSizeCount=g.knownSizeCount})
        table.insert(lines,string.format("%s | qtd=%d | peso min=%s max=%s | raridades=%s",name,g.count,tostring(g.weights[1] or "?"),tostring(g.weights[#g.weights] or "?"),#rarities>0 and table.concat(rarities,",") or "?"))
    end
    table.insert(lines,"=== Metadados de pesca encontrados ===")
    local metadata={}
    for obj in pairs(models) do
        if obj:IsDescendantOf(workspace) then
            local attrs={}
            for k,v in pairs(obj:GetAttributes()) do
                local key=string.lower(k)
                if contains(key,{"fish","weight","rarity","tier","species","mutation","size","level","depth","scale","type","income","earnings","money","cash","revenue"}) and (type(v)=="number" or type(v)=="boolean" or type(v)=="string") then
                    table.insert(attrs,k.."="..tostring(v):sub(1,60))
                end
            end
            table.sort(attrs)
            local summary=obj.Name.." | "..table.concat(attrs,"; ")
            if #attrs>0 then metadata[summary]=true end
        end
    end
    local metaKeys={}
    for v in pairs(metadata) do table.insert(metaKeys,v) end
    table.sort(metaKeys)
    for i=1,math.min(#metaKeys,40) do table.insert(lines,metaKeys[i]) end
    if #metaKeys>40 then table.insert(lines,"Amostra de metadados: 40 registros de "..#metaKeys..". Resumo de especies completo acima.") end
    table.insert(lines,"=== Textos de interface (podem estar fora da tela; nao usar como evidencia de visibilidade) ===")
    local seen={}
    local total=0
    for _,o in ipairs(pg:GetDescendants()) do
        if total>=250 then break end
        if (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) and o.AbsoluteSize.X>2 and o.AbsoluteSize.Y>2 then
            local t=normalized(renderedText(o))
            if contains(string.lower(t),{"fish","peixe","mergul","dive","reel","clique","toque","tap","rarity","raridade","weight","peso","kg","harpoon","arpao","captur","recolh","bolsa","bag","espaco","space","subir","descer","ascend","descend","feed","aliment","evol","eat","comer","depth","profund","mukbang","return","voltar","$/s","/sec","/min","/s","income","earn","renda","dinheiro","cash","money"}) and not seen[t.."|"..o.Name] then
                seen[t.."|"..o.Name]=true; total=total+1
                local raw=tostring(o.Text):sub(1,120)
                table.insert(lines,string.format("%s | raw=%s | %s | %s | pos=%s size=%s",t:sub(1,120),raw,o.Name,o.ClassName,tostring(o.AbsolutePosition),tostring(o.AbsoluteSize)))
            end
        end
    end
    table.insert(lines,"=== Historico de estados ===")
    for _,v in ipairs(stateHistory) do table.insert(lines,v) end
    table.insert(lines,"=== Historico recente de entrada ===")
    for _,v in ipairs(eventLog) do table.insert(lines,v) end
    reportText=table.concat(lines,"\n")
    local data={
        schemaVersion=4,version="0.15",placeId=game.PlaceId,universeId=game.GameId,
        state=currentState,pauseReason=pauseReason,attempts=attempts,lastInput=lastInput,telemetry=audit,hud=hud,actionSummary=perAction,reportedCaptures=reportedCaptures,reportedCapturesSource=reportedCaptures and "manual" or nil,
        reelAttempts=reelAttempts,reelLastDecision=reelLastDecision,lastAimDecision=lastAimDecision,aimFrames=aimFrames,shotBlocked=shotBlocked,diveAttempts=diveAttempts,diveTransitions=diveTransitions,
        runtimeErrors=runtimeErrors,lastRuntimeError=lastRuntimeError,
        activeOptions=activeOptions,
        filters={species=speciesFilter,rarity=rarityFilter,minWeight=minWeight,maxWeight=maxWeight,mode=modes[filter],interval=interval,mutation=mutationFilter,minIncome=minIncome},
        species=speciesRows,coverage=coverage,observations={},metadataSample={},stateHistory=stateHistory,events=eventLog,
        observedControls=c.evidence or {},rawWeightUnit="unverified",incomeFieldsVerified=false,observationCount=#records,observationLimit=1000,observationsTruncated=#records>1000,source="previously observed client metadata; not a server or memory dump"
    }
    for i=1,math.min(#metaKeys,40) do table.insert(data.metadataSample,metaKeys[i]) end
    for i=1,math.min(#records,1000) do table.insert(data.observations,records[i]) end
    local encoded,json=pcall(function() return HttpService:JSONEncode(data) end)
    reportJson=encoded and json or ("JSON indisponivel: "..tostring(json))
    jsonMode=false
    formatBtn.Text="JSON"
    diagText.Text=reportText
    diagFrame.Visible=true
    setPanel(false)
end
connect(diagnostic.Activated,function()
    local ok,err=pcall(buildDiagnostic)
    if not ok then
        recordError(err)
        reportText="Falha ao gerar relatorio: "..tostring(err)
        reportJson=""
        diagText.Text=reportText
        diagFrame.Visible=true
        setPanel(false)
    end
end)
-- Angle helper: select the shorter arc between the two visible boundaries.
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
-- Keep this callback independent from the 150 ms UI scan. It uses only
-- the existing rendered elements and the standard input path.
local reelConn
reelConn=RunService.RenderStepped:Connect(function()
    if not alive or not options.reel or currentState~="reel" or diagFrame.Visible or GuiService.MenuIsOpen or UIS:GetFocusedTextBox() then
        reelNeedle=nil; reelLatched=false; return
    end
    local ok,err=pcall(function()
        local label=controlCache.reelLabel
        if not label or not label.Parent or not visible(label) then
            reelLastDecision="aguardando interface do minigame"; return
        end
        local needle,cap1,cap2=reelParts(label)
        if not needle then reelLastDecision="limites visuais nao encontrados"; return end
        if needle~=reelNeedle then reelNeedle=needle; reelLatched=false end
        local a,span=shortArc(cap1.AbsoluteRotation,cap2.AbsoluteRotation)
        if span<2 or span>178 then reelLastDecision="arco ambiguo"; return end
        local offset=(needle.AbsoluteRotation-a)%360
        local inside=offset>=0 and offset<=span
        reelLastDecision=string.format("angulo=%.1f arco=%.1f+%.1f dentro=%s",needle.AbsoluteRotation,a,span,tostring(inside))
        if not inside then reelLatched=false; return end
        local margin=math.min(4,span*0.15)
        if reelLatched or mouseBusy or os.clock()-reelLastTap<0.16 or offset<margin or offset>span-margin then return end
        reelLatched=true
        reelLastTap=os.clock()
        local point=center(label)
        task.spawn(function()
            if not alive or not options.reel or currentState~="reel" or not visible(label) then return end
            local sent,msg=tap(point)
            journal:record("reel",sent,msg)
            if sent then reelAttempts=reelAttempts+1 end
            log("reel tentativa: "..tostring(sent).." | "..tostring(msg))
        end)
    end)
    if not ok then recordError(err) end
end)
table.insert(connections,reelConn)

task.spawn(function()
    local lastEspUpdate=-math.huge
    local lastTarget=-math.huge
    local previousState=""
    while alive and gui.Parent do
        local ok,err=xpcall(function()
        local now=os.clock()
        journal:call("tick",now)
        if now-lastEspUpdate>=0.5 then updateEsp(); lastEspUpdate=now end
        if now-lastScan>=0.15 then controlCache=controls(); lastScan=now end
        local c=controlCache
        if c.underwater then lastConfirmedUnderwater=now end
        if c.diveText or not c.cameraScriptable then lastConfirmedUnderwater=-math.huge end
        local recentlyUnderwater=c.cameraScriptable and not c.diveText and now-lastConfirmedUnderwater<0.8
        if c.reel and c.cameraScriptable and not c.diveText then lastReelSeen=now end
        if c.diveText or not c.cameraScriptable then lastReelSeen=-math.huge end
        local reelActive=c.cameraScriptable and not c.diveText and (c.reel~=nil or now-lastReelSeen<0.25)
        currentState=game.PlaceId~=113384248926706 and "unknown" or c.full and "full" or c.diveText and "surface" or reelActive and "reel" or (c.underwater or recentlyUnderwater) and "underwater" or c.feed and "surface" or "unknown"
        if currentState=="reel" and c.reelLabel and now-lastReelSample>=0.35 then
            lastReelSample=now
            local rows={}
            local parent=c.reelLabel.Parent
            if parent and parent.Parent and parent.Parent:IsA("GuiObject") then parent=parent.Parent end
            if parent then
                for _,o in ipairs(parent:GetDescendants()) do
                    if #rows>=18 then break end
                    if o:IsA("GuiObject") and visible(o) and o.AbsoluteSize.X>2 and o.AbsoluteSize.Y>2 then
                        table.insert(rows,string.format("%s:%s rot=%.1f pos=%s size=%s",o.Name,o.ClassName,o.AbsoluteRotation,tostring(o.AbsolutePosition),tostring(o.AbsoluteSize)))
                    end
                end
            end
            table.insert(reelEvidence,string.format("%.2f | %s",now,table.concat(rows,"; ")))
            if #reelEvidence>20 then table.remove(reelEvidence,1) end
        end
        pauseReason=diagFrame.Visible and "diagnostico aberto" or GuiService.MenuIsOpen and "menu Roblox aberto" or UIS:GetFocusedTextBox() and "teclado aberto" or currentState=="unknown" and "estado nao reconhecido" or "nenhuma"
        if previousState~=currentState then
            if currentState=="underwater" and now-lastDiveRequest<8 then diveTransitions=diveTransitions+1; lastDiveRequest=-math.huge; log("mergulho: transicao observada apos tentativa; origem nao confirmada") end
            log("estado: "..currentState); previousState=currentState
            local tags={}
            for k,v in pairs(c.evidence or {}) do table.insert(tags,k.."="..v) end
            table.sort(tags)
            journal:call("observe",currentState,os.clock(),"client_observation",#tags>0 and table.concat(tags,"; ") or "Estado inferido; sem texto correspondente")
            table.insert(stateHistory,string.format("%.2f %s | %s",now,currentState,table.concat(tags,"; ")))
            if #stateHistory>200 then table.remove(stateHistory,1) end
            lockedTarget=nil
        end
        if selectionRevision~=previousRevision then lockedTarget=nil; previousRevision=selectionRevision end
        local n=0
        for _ in pairs(models) do n=n+1 end
        counter.Text=string.format("Alvos: %d | Disparos: %d",n,attempts)
        if not panel.Visible then floating.Text=currentState=="underwater" and "HM\nAGUA" or currentState=="full" and "HM\nCHEIO" or currentState=="surface" and "HM\nTERRA" or currentState=="reel" and "HM\nREEL" or "HM\n?" end
        if diagFrame.Visible or GuiService.MenuIsOpen or UIS:GetFocusedTextBox() then
            status.Text="Pausado: "..pauseReason
            lockedTarget=nil
        elseif currentState=="full" then
            status.Text="Bolsa cheia: pare de atirar"
            lockedTarget=nil
            if options.surface and now-lastSurface>=3 then
                lastSurface=now
                local sent,msg
                if c.returnButton and visible(c.returnButton) and c.returnButton:IsA("GuiButton") then sent,msg=tap(center(c.returnButton)) else sent=keyPress(Enum.KeyCode.Space) end
                journal:record("return_to_surface",sent,msg)
            end
        elseif currentState=="reel" then
            status.Text="Recolhimento experimental"
            lockedTarget=nil
            if options.reel then
                status.Text="Minigame: "..reelLastDecision
            end
        elseif currentState=="surface" then
            status.Text="Superficie confirmada"
            lockedTarget=nil
            if options.feed and c.feed and visible(c.feed) and now-lastFeed>3 then
                lastFeed=now; local sent,msg=tap(center(c.feed)); journal:record("feed",sent,msg); log("feed: tentativa de botao visivel")
            elseif options.dive and c.dive and visible(c.dive) and now-lastDive>3 then
                lastDive=now; lastDiveRequest=now; diveAttempts=diveAttempts+1
                local ok,msg=tap(center(c.dive)); journal:record("dive",ok,msg); log("dive: "..c.dive.Name.." ["..c.dive.ClassName.."] | "..tostring(ok).." | "..tostring(msg))
            end
        elseif currentState=="underwater" then
            status.Text="Submerso"
            if options.up~=options.down and now-lastMove>0.85 and not keyBusy and not mouseBusy and not (lockedTarget and options.fish) then
                lastMove=now
                local moveKey=options.up and Enum.KeyCode.E or Enum.KeyCode.Q
                task.spawn(function() if alive and currentState=="underwater" then local sent=keyPress(moveKey,0.45); journal:record("move",sent) end end)
            elseif options.surface and not options.fish and now-lastSurface>=3 then
                lastSurface=now; local sent=keyPress(Enum.KeyCode.Space); journal:record("return_to_surface",sent)
            end
            if options.fish or options.aim then
                if not lockedTarget or not lockedTarget.object:IsDescendantOf(workspace) or not selected(lockedTarget.object) or (not options.aim and now-lastTarget>=0.2) then
                    lockedTarget=target(); lastTarget=now
                end
                if lockedTarget then
                    local cam=workspace.CurrentCamera
                    local box=lockedTarget.object:GetBoundingBox()
                    local pos=box.Position
                    local point,on=cam:WorldToViewportPoint(pos)
                    if options.aim then
                        status.Text=string.format("Mira: %s | %.1f graus",lockedTarget.name,aimError)
                    end
                    if options.fish then
                        shotBlocked=not on and "alvo fora da tela" or point.Z<=0 and "alvo atras da camera" or (options.aim and aimError>3) and "aguardando alinhamento" or (keyBusy or mouseBusy) and "entrada ocupada" or "pronto"
                        if now-lastShot>=interval and on and point.Z>0 and (not options.aim or aimError<=3) and not keyBusy and not mouseBusy then
                            lastShot=now
                            local p=options.aim and cam.ViewportSize/2 or Vector2.new(point.X,point.Y)
                            local ok,msg=tap(p)
                            journal:record("shot",ok,msg)
                            if ok then attempts=attempts+1 end
                            shotBlocked=msg
                            status.Text=ok and ("Disparo: "..lockedTarget.name) or msg
                        end
                    end
                    if not on and now-lastTarget>1.5 then lockedTarget=nil end
                else status.Text=lastTargetReason; shotBlocked=lastTargetReason end
            else lockedTarget=nil end
        else
            lockedTarget=nil
            status.Text="Estado desconhecido: entrada pausada"
        end
        end,function(e) return tostring(e) end)
        if not ok and alive then
            recordError(err)
            lockedTarget=nil
            status.Text="Erro recuperavel: veja diagnostico"
            task.wait(0.5)
        end
        task.wait(0.08)
    end
end)
print("HarpoonMobile v0.15 carregado | PlaceId: "..tostring(game.PlaceId))
