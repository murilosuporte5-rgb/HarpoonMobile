local Core=dofile("core.lua")
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error(name..": "..tostring(err),0) end
    passed=passed+1; print("PASS "..name)
end
local function new(opts)
    local events={}; opts=opts or {}; opts.sessionId="test"
    opts.sink=opts.sink or function(e) events[#events+1]=e; return true end
    return Core.new(opts),events
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function fails(a,b,code) eq(a,nil); eq(b,code) end

test("initial unknown",function() local s=new(); eq(s:snapshot().state,"unknown") end)
test("source required",function() local s=new(); local a,b=s:observe("surface",1,"unknown","x"); fails(a,b,"invalid_observation") end)
test("unknown state rejected",function() local s=new(); local a,b=s:observe("invalid",1,"manual","x"); fails(a,b,"invalid_observation") end)
test("observed transition",function() local s=new(); assert(s:observe("surface",1,"manual","Dive visible")); assert(s:observe("underwater",2,"manual","Return visible")); eq(s:snapshot().state,"underwater") end)
test("skipped state recorded as anomaly",function() local s=new(); assert(s:observe("surface",1,"manual","visible")); assert(s:observe("reel",2,"manual","visible")); eq(s:snapshot().counts.anomalies,1) end)
test("request does not alter state",function() local s=new(); assert(s:begin("dive",1)); eq(s:snapshot().state,"unknown") end)
test("request not capture",function() local s=new(); assert(s:begin("shot",1)); eq(s:snapshot().counts.captures,0) end)
test("unknown action rejected",function() local s=new(); local a,b=s:begin("invalid",1); fails(a,b,"invalid_action") end)
test("monotonic clock",function() local s=new(); assert(s:begin("shot",2)); local a,b=s:begin("shot",1); fails(a,b,"invalid_time") end)
test("invalid clock",function() local s=new(); local a,b=s:begin("shot",0/0); fails(a,b,"invalid_time") end)
test("missing outcome evidence",function() local s=new(); local id=s:begin("shot",1); local a,b=s:resolve(id,"confirmed",2,"manual",""); fails(a,b,"missing_evidence") end)
test("confirmation distinct from capture",function() local s=new(); local id=s:begin("reel",1); assert(s:resolve(id,"confirmed",2,"manual","minigame ended")); eq(s:snapshot().counts.confirmed,1); eq(s:snapshot().counts.captures,0) end)
test("explicit capture",function() local s=new(); assert(s:recordCapture(1,"manual","inventory change observed")); eq(s:snapshot().counts.captures,1) end)
test("capture evidence required",function() local s=new(); local a,b=s:recordCapture(1,"manual",""); fails(a,b,"missing_evidence") end)
test("no double resolution",function() local s=new(); local id=s:begin("shot",1); assert(s:resolve(id,"rejected",2,"manual","miss")); local a,b=s:resolve(id,"confirmed",3,"manual","x"); fails(a,b,"unknown_or_resolved_action") end)
test("timeout",function() local s=new({timeout=3}); s:begin("dive",1); eq(s:tick(3),0); eq(s:tick(4),1); eq(s:snapshot().counts.timeout,1) end)
test("late confirmation rejected",function() local s=new({timeout=2}); local id=s:begin("shot",1); local a,b=s:resolve(id,"confirmed",4,"manual","late"); fails(a,b,"expired_action") end)
test("premature timeout rejected",function() local s=new({timeout=2}); local id=s:begin("shot",1); local a,b=s:resolve(id,"timeout",2,"fixture","early"); fails(a,b,"premature_timeout") end)
test("pending limit",function() local s=new({pendingLimit=1}); s:begin("shot",1); local a,b=s:begin("shot",2); fails(a,b,"pending_limit") end)
test("sink refusal atomic",function() local s=new({sink=function() return false end}); local a,b=s:observe("surface",1,"manual","visible"); fails(a,b,"sink_failed"); eq(s:snapshot().state,"unknown"); eq(s:snapshot().sequence,0) end)
test("sink exception atomic",function() local s=new({sink=function() error("disk error") end}); local a,b=s:begin("shot",1); fails(a,b,"sink_failed"); eq(s:snapshot().pending,0) end)
test("sequence ordering",function() local s,e=new(); s:begin("shot",1); s:begin("reel",1); eq(e[1].seq,1); eq(e[2].seq,2) end)
test("close refuses pending",function() local s=new(); s:begin("shot",1); local a,b=s:close(2); fails(a,b,"pending_actions") end)
test("closed session rejects events",function() local s=new(); assert(s:close(1)); local a,b=s:begin("shot",2); fails(a,b,"closed") end)
test("snapshot isolated",function() local s=new(); local v=s:snapshot(); v.counts.captures=100; eq(s:snapshot().counts.captures,0) end)
test("observed v0.11 replay does not invent capture",function() local s=new({timeout=10}); assert(s:observe("surface",970.16,"fixture","DIVE")); s:begin("dive",970.30); assert(s:observe("underwater",973.14,"fixture","RETURN")); assert(s:observe("reel",985.86,"fixture","CLICK")); for i=1,3 do s:begin("reel",986+i/10) end; eq(s:snapshot().counts.requested,4); eq(s:snapshot().counts.captures,0) end)
test("large journal",function() local s,e=new(); for i=1,10000 do assert(s:observe("surface",i,"fixture","snapshot")) end; eq(#e,10000); eq(s:snapshot().sequence,10000) end)
print("TOTAL "..passed.." tests passed")
