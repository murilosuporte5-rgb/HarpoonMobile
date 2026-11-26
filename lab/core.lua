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
local sources = {manual=true, fixture=true, authorized_adapter=true}
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
        local ok,err=self:resolve(id,"timeout",t,"fixture","Deadline elapsed without outcome")
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
