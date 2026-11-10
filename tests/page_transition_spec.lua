local clock=0.1
now=function() return clock end
D={Tab="extraction",DockActive=function() return false end,TransDuration=function() return 2 end}
assert(loadstring(contentReadySource))()
assert(loadstring(transitionActiveSource))()
local renders,closed,hidden,nativeFrames,clicked=0,0,0,0,0
local rect={x=0,y=0,w=100,h=100,action=function() clicked=clicked+1 end}
state={dashboard={navigation=function(owner) owner._empdaExtractionHits={rect};return 100 end,
    render=function() renders=renders+1 end,pages={hide=function() hidden=hidden+1 end,
        close=function() closed=closed+1 end}}}
pack=function(...) return {...} end
unpackArgs=unpack
addExtractionTab=function() return true end
diagnostic=function() end
isInside=function(x,y,r) return r and x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h end
local ui={_pda={phase="ready",bootAt=0},render=function() nativeFrames=nativeFrames+1;return "native" end,
    onMouseDown=function() end,onMouseUp=function() end,onMouseWheel=function() return false end}
local install=assert(loadstring(pageHookSource))()
assert(install(ui,D))
assert(ui:render()=="native" and renders==0 and hidden==1 and closed==0, "boot overlay hides content without discarding page state")
clock=1
ui._pda.trans={t=clock}
ui:render()
assert(renders==0 and nativeFrames==2 and #ui._empdaExtractionHits==0, "native transition renders without early content or hits")
clock=3.1
ui:render()
assert(renders==1 and #ui._empdaExtractionHits==1, "page appears when the native transition ends")
ui:onMouseDown(10,10)
ui._pda.trans={t=clock}
ui:onMouseUp(10,10)
assert(clicked==0, "a transition starting between press and release blocks the action")
ui:onMouseDown(10,10)
ui:onMouseUp(10,10)
assert(clicked==0, "loading never accepts stale page hits")
clock=5.2
ui:render()
ui:onMouseDown(10,10);ui:onMouseUp(10,10)
assert(clicked==1, "actions resume after loading")
D.Tab="dossier"
ui:render()
assert(closed==1, "leaving Extraction closes its pages and controls")
print("PDA transitions: native boot/loading gates, delayed page rendering and stale input protection passed")
