-- EVVO.JAILBREAK Ultimate V4.1 - Navigation & Tools Expansion
-- OWNED BY EVVO | Client-side Luau
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local Stats = game:GetService('Stats')
local localPlayer = Players.LocalPlayer
assert(localPlayer, 'LocalPlayer unavailable')
local rootGui = (gethui and gethui()) or game:GetService('CoreGui')
local old = rootGui:FindFirstChild('EVVO_UltimateV4')
if old then old:Destroy() end
if _G.EVVO_V4_CLEANUP then pcall(_G.EVVO_V4_CLEANUP) end
local connections, highlights = {}, {}
local function connect(signal,fn) local c=signal:Connect(fn); table.insert(connections,c); return c end
local state={esp=true,names=true,distance=true,teamFilter=false,walk=false,jump=false,infiniteJump=false,sprint=false,walkSpeed=24,jumpPower=70,espRange=800,opacity=0.45,sprintMultiplier=1.5, boxes=true,health=true,teamColors=true,showPolice=true,showCriminal=true,showPrisoner=true,espRefresh=0.15, radar=true,radarRange=500,radarSize=140,coords=true,alerts=false,alertRange=120,lowGraphics=false,autoJump=false,autoJumpInterval=1.5,autoSprint=false,gravityEnabled=false,gravityValue=196.2,highJump=false, bunnyHop=false, speedHud=true,playerCount=true, showBounty=false, showVelocity=false, outlines=true, rainbow=false, search=""}
local savedPosition
local waypoints={}
local waypointIndex=0
local jumpCount=0
local spectateTarget=nil
local originalCameraSubject=nil
local started=os.clock()
local lastJump=0
local alertAt=0
local originalGravity=workspace.Gravity
local originalHumanoidValues=setmetatable({},{__mode='k'})
local radarDots={}
local lastError='none'
local function safe(fn) local ok,err=pcall(fn); if not ok then lastError=tostring(err);warn('[EVVO]',err) end end
local gui=Instance.new('ScreenGui'); gui.Name='EVVO_UltimateV4'; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=rootGui
local function make(class,props,parent) local o=Instance.new(class); for k,v in pairs(props) do o[k]=v end; o.Parent=parent; return o end
local main=make('Frame',{Size=UDim2.fromOffset(490,385),Position=UDim2.new(0.5,-245,0.5,-192),BackgroundColor3=Color3.fromRGB(13,13,18),BorderSizePixel=0,Active=true},gui)
make('UICorner',{CornerRadius=UDim.new(0,12)},main)
make('UIStroke',{Color=Color3.fromRGB(155,32,47),Thickness=1.5},main)
local header=make('Frame',{Size=UDim2.new(1,0,0,48),BackgroundColor3=Color3.fromRGB(31,14,20),BorderSizePixel=0},main)
make('UICorner',{CornerRadius=UDim.new(0,12)},header)
make('TextLabel',{Text='EVVO.JAILBREAK  //  ULTIMATE V4',TextColor3=Color3.fromRGB(255,235,238),Font=Enum.Font.GothamBold,TextSize=16,BackgroundTransparency=1,Size=UDim2.new(1,-95,1,0),Position=UDim2.fromOffset(14,0),TextXAlignment=Enum.TextXAlignment.Left},header)
local close=make('TextButton',{Text='X',TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=16,Size=UDim2.fromOffset(34,30),Position=UDim2.new(1,-39,0,9),BackgroundColor3=Color3.fromRGB(125,30,44)},header)
make('UICorner',{CornerRadius=UDim.new(0,7)},close)
local tabs=make('Frame',{Size=UDim2.new(0,125,1,-60),Position=UDim2.fromOffset(8,54),BackgroundTransparency=1},main)
local content=make('ScrollingFrame',{Size=UDim2.new(1,-151,1,-69),Position=UDim2.fromOffset(143,57),BackgroundColor3=Color3.fromRGB(21,21,28),BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},main)
make('UICorner',{CornerRadius=UDim.new(0,8)},content)
local layout=make('UIListLayout',{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},content)
make('UIPadding',{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},content)
local function clearContent() for _,v in ipairs(content:GetChildren()) do if v:IsA('GuiObject') then v:Destroy() end end end
local function label(txt) return make('TextLabel',{Text=txt,TextColor3=Color3.fromRGB(210,210,219),Font=Enum.Font.Gotham,TextSize=12,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Size=UDim2.new(1,0,0,30)},content) end
local function button(text,callback)
 local b=make('TextButton',{Text=text,TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamMedium,TextSize=13,BackgroundColor3=Color3.fromRGB(53,32,41),Size=UDim2.new(1,0,0,34)},content)
 make('UICorner',{CornerRadius=UDim.new(0,7)},b)
 connect(b.MouseButton1Click,function() local ok,err=pcall(callback); if not ok then warn('[EVVO] '..tostring(err)) end end)
 return b
end
local function toggle(title,key)
 local b=button('',function() state[key]=not state[key]; end)
 local function update() b.Text=title..': '..(state[key] and 'ON' or 'OFF'); b.BackgroundColor3=state[key] and Color3.fromRGB(118,28,44) or Color3.fromRGB(53,32,41) end
 connect(b.MouseButton1Click,update); update()
end
local function slider(title,key,low,high,step)
 local wrap=make('Frame',{BackgroundTransparency=1,Size=UDim2.new(1,0,0,54)},content)
 local valueLabel=make('TextLabel',{BackgroundTransparency=1,TextColor3=Color3.fromRGB(230,230,235),Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,22)},wrap)
 local track=make('Frame',{BackgroundColor3=Color3.fromRGB(63,63,70),BorderSizePixel=0,Size=UDim2.new(1,-8,0,10),Position=UDim2.fromOffset(4,32)},wrap)
 make('UICorner',{CornerRadius=UDim.new(1,0)},track)
 local fill=make('Frame',{BackgroundColor3=Color3.fromRGB(223,48,68),BorderSizePixel=0,Size=UDim2.fromScale(0,1)},track)
 make('UICorner',{CornerRadius=UDim.new(1,0)},fill)
 local dragging=false
 local function refresh() local ratio=math.clamp((state[key]-low)/(high-low),0,1); fill.Size=UDim2.fromScale(ratio,1); valueLabel.Text=title..': '..tostring(state[key]) end
 local function setAt(x) local fraction=math.clamp((x-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1); state[key]=math.clamp(math.floor((low+(high-low)*fraction)/step+0.5)*step,low,high); refresh() end
 connect(track.InputBegan,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true; setAt(input.Position.X) end end)
 connect(UIS.InputChanged,function(input) if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then setAt(input.Position.X) end end)
 connect(UIS.InputEnded,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
 refresh()
end
local pages={}
local function section(text) label('── '..text..' ──') end
pages.ESP=function()
 label('Client-side player highlights. Visible range and filters are adjustable.')
 toggle('Enable ESP','esp'); toggle('Player names','names'); toggle('Distance labels','distance'); toggle('Health text','health'); toggle('Box highlights','boxes'); toggle('Outlines','outlines'); toggle('Rainbow highlights','rainbow'); toggle('Show bounty attribute','showBounty'); toggle('Show velocity','showVelocity'); toggle('Exclude same team','teamFilter'); section('Teams'); toggle('Show police','showPolice');toggle('Show criminals','showCriminal');toggle('Show prisoners','showPrisoner');toggle('Use team colors','teamColors');section('Rendering'); slider('ESP range','espRange',100,3000,50); slider('Highlight transparency','opacity',0,1,0.05);slider('Refresh seconds','espRefresh',0.05,0.5,0.05)
end
pages.Movement=function()
 label('Movement properties may be overridden by the game server.')
 toggle('WalkSpeed override','walk'); slider('WalkSpeed','walkSpeed',16,150,1)
 toggle('JumpPower override','jump'); slider('JumpPower','jumpPower',50,200,5)
 toggle('Infinite jump','infiniteJump'); toggle('Sprint (hold LeftShift)','sprint');toggle('Automatic sprint','autoSprint');toggle('Auto jump','autoJump');slider('Auto jump interval','autoJumpInterval',0.3,4,0.1);toggle('Gravity override','gravityEnabled');slider('Gravity','gravityValue',25,250,5);slider('Sprint multiplier','sprintMultiplier',1,3,0.1)
 button('Save current position',function() local ch=localPlayer.Character; local r=ch and ch:FindFirstChild('HumanoidRootPart'); if r then savedPosition=r.CFrame end end)
 button('Return to saved position',function() local ch=localPlayer.Character; local r=ch and ch:FindFirstChild('HumanoidRootPart'); if r and savedPosition then r.CFrame=savedPosition end end)
end
pages.Diagnostics=function()
 label('EVVO.JAILBREAK // OWNED BY EVVO')
 label('loadstring: '..type(loadstring)..' | HttpGet: '..type(game.HttpGet))
 label('Drawing API: '..type(Drawing)..' | File API: '..type(writefile))
 local fps=label('FPS: measuring...')
 local last=os.clock(); local frames=0
 local c; c=connect(RunService.RenderStepped,function() if not fps.Parent then c:Disconnect();return end; frames=frames+1; local now=os.clock(); if now-last>=1 then fps.Text='FPS: '..math.floor(frames/(now-last)+0.5); frames=0;last=now end end)
 button('Print diagnostics',function() print('[EVVO] Players:',#Players:GetPlayers(),'GUI:',gui.Parent,'ESP:',state.esp) end)
end
pages.About=function() label('EVVO.JAILBREAK ULTIMATE V4 — Phase 1'); label('Developer: EVVO | OWNED BY EVVO'); label('Features are client-side and not verified in Madium.'); button('Disable all features',function() for _,k in ipairs({'esp','walk','jump','infiniteJump','sprint'}) do state[k]=false end end) end

-- Additional modules: these rely only on documented Roblox client objects.
local radarGui=make('Frame',{Name='Radar',Size=UDim2.fromOffset(160,180),Position=UDim2.new(1,-178,0,20),BackgroundColor3=Color3.fromRGB(15,15,21),BorderSizePixel=0,Visible=false},gui)
make('UICorner',{CornerRadius=UDim.new(0,10)},radarGui)
make('UIStroke',{Color=Color3.fromRGB(155,32,47),Thickness=1},radarGui)
make('TextLabel',{Text='EVVO // PLAYER RADAR',Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.fromRGB(240,90,105),BackgroundTransparency=1,Size=UDim2.new(1,0,0,24)},radarGui)
local radarField=make('Frame',{Size=UDim2.fromOffset(140,140),Position=UDim2.fromOffset(10,29),BackgroundColor3=Color3.fromRGB(30,30,40),BorderSizePixel=0,ClipsDescendants=true},radarGui)
make('UICorner',{CornerRadius=UDim.new(1,0)},radarField)
make('Frame',{Size=UDim2.fromOffset(5,5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},radarField)
local statusGui=make('TextLabel',{Name='StatusHUD',Size=UDim2.fromOffset(360,45),Position=UDim2.new(0,12,1,-58),BackgroundColor3=Color3.fromRGB(18,18,24),BackgroundTransparency=0.12,TextColor3=Color3.fromRGB(255,210,215),TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Text=' EVVO // starting...',Visible=true},gui)
make('UICorner',{CornerRadius=UDim.new(0,8)},statusGui)
local function updateRadar()
 radarGui.Visible=state.radar
 if not state.radar then return end
 local root=localPlayer.Character and localPlayer.Character:FindFirstChild('HumanoidRootPart')
 if not root then return end
 local cf=root.CFrame
 local seen={}
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=localPlayer then
   local other=p.Character and p.Character:FindFirstChild('HumanoidRootPart')
   if other then
    local relative=cf:PointToObjectSpace(other.Position)
    local x=math.clamp(relative.X/state.radarRange,-1,1)
    local y=math.clamp(relative.Z/state.radarRange,-1,1)
    if relative.Magnitude<=state.radarRange then
     local dot=radarDots[p]
     if not dot then dot=make('Frame',{Size=UDim2.fromOffset(6,6),BorderSizePixel=0},radarField);make('UICorner',{CornerRadius=UDim.new(1,0)},dot);radarDots[p]=dot end
     dot.Position=UDim2.new(0.5,x*65-3,0.5,y*65-3)
     dot.BackgroundColor3=p.TeamColor.Color
     dot.Visible=true;seen[p]=true
    end
   end
  end
 end
 for p,dot in pairs(radarDots) do if not seen[p] then dot:Destroy();radarDots[p]=nil end end
end
pages.Radar=function()
 label('Player radar uses relative character positions; no map data required.')
 toggle('Enable radar','radar');slider('Radar range','radarRange',100,2000,50)
 toggle('Coordinates HUD','coords');toggle('Movement HUD','speedHud');toggle('Player count HUD','playerCount')
 toggle('Police proximity alerts (console)','alerts');slider('Alert range','alertRange',30,500,10)
end
pages.Players=function()
 section('Live player directory')
 local list=Players:GetPlayers()
 table.sort(list,function(a,b) return a.Name<b.Name end)
 for _,p in ipairs(list) do
  local team=p.Team and p.Team.Name or 'No team'
  local text=p.DisplayName..' (@'..p.Name..') | '..team
  button(text,function() local char=p.Character;local root=char and char:FindFirstChild('HumanoidRootPart'); if root then print('[EVVO] '..p.Name..' @ '..tostring(root.Position)) end end)
 end
end
pages.World=function()
 label('Client-side world controls. Game-specific robbery state is not available from standard APIs.')
 toggle('Low graphics mode','lowGraphics')
 button('Print position to console',function() local r=localPlayer.Character and localPlayer.Character:FindFirstChild('HumanoidRootPart');if r then print('[EVVO] Position',r.Position) end end)
 button('Print workspace model names (first 30)',function() local n=0;for _,v in ipairs(workspace:GetChildren()) do if v:IsA('Model') then print('[EVVO] Model:',v.Name);n=n+1;if n>=30 then break end end end end)
 button('Restore gravity',function() state.gravityEnabled=false;workspace.Gravity=originalGravity end)
end
pages.Settings=function()
 section('Status and controls')
 label('RightShift: show/hide menu. End: emergency disable.')
 button('Reset numeric settings',function() state.walkSpeed=24;state.jumpPower=70;state.espRange=800;state.opacity=0.45;state.radarRange=500;state.sprintMultiplier=1.5;state.gravityValue=originalGravity;show('Settings') end)
 button('Print configuration to console',function() for k,v in pairs(state) do print('[EVVO CONFIG]',k,v) end end)
 button('Disable movement overrides',function() state.walk=false;state.jump=false;state.autoSprint=false;state.autoJump=false;state.infiniteJump=false;state.gravityEnabled=false;workspace.Gravity=originalGravity end)
 button('Show last error',function() print('[EVVO LAST ERROR]',lastError) end)
end

-- V4.1 extensions: standard client-side utilities, no game-specific remotes.
local function rootOf(p)
 local ch=p and p.Character
 return ch and ch:FindFirstChild('HumanoidRootPart')
end
local function cameraReset()
 spectateTarget=nil
 local camera=workspace.CurrentCamera
 local hum=localPlayer.Character and localPlayer.Character:FindFirstChildOfClass('Humanoid')
 if camera and hum then camera.CameraSubject=hum end
end
pages.Navigation=function()
 section('Personal waypoints')
 label('Save your current position and select saved coordinates. No automatic teleport is performed.')
 button('Save current waypoint',function()
  local root=rootOf(localPlayer)
  if not root then warn('[EVVO] Character root unavailable');return end
  waypointIndex=waypointIndex+1
  table.insert(waypoints,{name='Waypoint '..waypointIndex,pos=root.Position})
  print('[EVVO] Saved waypoint',waypointIndex)
 end)
 button('List waypoints in console',function()
  for i,w in ipairs(waypoints) do print('[EVVO WAYPOINT]',i,w.name,w.pos) end
 end)
 button('Remove most recent waypoint',function() table.remove(waypoints) end)
 local root=rootOf(localPlayer)
 if root then
  for i,w in ipairs(waypoints) do
   local d=math.floor((root.Position-w.pos).Magnitude)
   button(w.name..' | '..d..' studs',function()
    print('[EVVO] '..w.name..' at '..tostring(w.pos))
   end)
  end
 end
end
pages.Spectate=function()
 section('Camera spectate')
 label('Choose a player to follow with your camera. Reset to return to your character.')
 button('Return camera to yourself',cameraReset)
 local list=Players:GetPlayers()
 table.sort(list,function(a,b) return a.Name<b.Name end)
 for _,p in ipairs(list) do
  if p~=localPlayer then
   button('Watch '..p.DisplayName,function()
    local hum=p.Character and p.Character:FindFirstChildOfClass('Humanoid')
    if not hum then warn('[EVVO] Target has no humanoid');return end
    local camera=workspace.CurrentCamera
    if camera then camera.CameraSubject=hum;spectateTarget=p end
   end)
  end
 end
end
pages.Telemetry=function()
 section('Session telemetry')
 label('Session uptime: '..math.floor(os.clock()-started)..' seconds')
 label('Players: '..#Players:GetPlayers())
 label('Jump requests: '..jumpCount)
 local r=rootOf(localPlayer)
 if r then
  label(string.format('Position: %.1f / %.1f / %.1f',r.Position.X,r.Position.Y,r.Position.Z))
  label(string.format('Horizontal speed: %.1f studs/s',Vector3.new(r.AssemblyLinearVelocity.X,0,r.AssemblyLinearVelocity.Z).Magnitude))
  label(string.format('Vertical speed: %.1f studs/s',r.AssemblyLinearVelocity.Y))
  local look=r.CFrame.LookVector
  label(string.format('Heading: %.0f degrees', (math.deg(math.atan2(-look.X,-look.Z))+360)%360))
 end
 local ok,ping=pcall(function() return Stats.Network.ServerStatsItem['Data Ping']:GetValueString() end)
 if ok then label('Ping: '..tostring(ping)) end
 button('Refresh telemetry',function() show('Telemetry') end)
 button('Print compatibility report',function()
  print('[EVVO] loadstring:',type(loadstring),'HttpGet:',type(game.HttpGet),'Drawing:',type(Drawing),'writefile:',type(writefile))
 end)
end
pages.Profiles=function()
 section('Local settings profiles')
 label('Export current settings if your executor supports writefile. No automatic loading of untrusted files.')
 button('Export configuration to file',function()
  if type(writefile)~='function' then warn('[EVVO] writefile unavailable');return end
  local serializable={}
  for k,v in pairs(state) do if type(v)=='boolean' or type(v)=='number' or type(v)=='string' then serializable[k]=v end end
  local json=game:GetService('HttpService'):JSONEncode(serializable)
  local ok,err=pcall(function() writefile('EVVO_V4_config.json',json) end)
  if ok then print('[EVVO] Configuration exported') else warn('[EVVO]',err) end
 end)
 button('Import configuration from file',function()
  if type(readfile)~='function' then warn('[EVVO] readfile unavailable');return end
  local ok,result=pcall(function() return game:GetService('HttpService'):JSONDecode(readfile('EVVO_V4_config.json')) end)
  if not ok or type(result)~='table' then warn('[EVVO] Invalid config:',result);return end
  local applied=0
  for k,v in pairs(result) do
   if state[k]~=nil and type(state[k])==type(v) then
    if type(v)~='number' or (v==v and math.abs(v)<1000000) then state[k]=v;applied=applied+1 end
   end
  end
  print('[EVVO] Imported '..applied..' settings')
 end)
end
local active='ESP'
local function show(name) active=name;clearContent();pages[name]() end
local tabLayout=make('UIListLayout',{Padding=UDim.new(0,8)},tabs)
for _,name in ipairs({'ESP','Movement','Radar','Players','Navigation','Spectate','Telemetry','Profiles','World','Settings','Diagnostics','About'}) do
 local b=make('TextButton',{Text=name,Size=UDim2.new(1,0,0,37),BackgroundColor3=Color3.fromRGB(64,25,35),TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=13},tabs)
 make('UICorner',{CornerRadius=UDim.new(0,7)},b)
 connect(b.MouseButton1Click,function() show(name) end)
end
local dragging=false;local dragStart;local startPosition
connect(header.InputBegan,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;dragStart=input.Position;startPosition=main.Position end end)
connect(UIS.InputChanged,function(input) if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then local d=input.Position-dragStart;main.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+d.X,startPosition.Y.Scale,startPosition.Y.Offset+d.Y) end end)
connect(UIS.InputEnded,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
local function clearHighlight(player) local h=highlights[player];if h then h:Destroy();highlights[player]=nil end end
local function updateESP()
 local myRoot=localPlayer.Character and localPlayer.Character:FindFirstChild('HumanoidRootPart')
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=localPlayer then
   local ch=p.Character;local root=ch and ch:FindFirstChild('HumanoidRootPart')
   local teamName=(p.Team and p.Team.Name or ''):lower()
   local allowed=(teamName:find('police') and state.showPolice) or ((teamName:find('criminal') or teamName:find('outlaw')) and state.showCriminal) or ((teamName:find('prison') or teamName:find('inmate')) and state.showPrisoner) or (not teamName:find('police') and not teamName:find('criminal') and not teamName:find('outlaw') and not teamName:find('prison') and not teamName:find('inmate'))
   local valid=allowed and state.esp and myRoot and root and (myRoot.Position-root.Position).Magnitude<=state.espRange and (not state.teamFilter or p.Team~=localPlayer.Team)
   if valid then
    local h=highlights[p]
    if not h or h.Parent~=ch then clearHighlight(p);h=Instance.new('Highlight');h.Name='EVVO_Highlight';h.Adornee=ch;h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;h.Parent=ch;highlights[p]=h end
    h.Enabled=state.boxes;h.FillColor=state.rainbow and Color3.fromHSV((os.clock()%6)/6,0.85,1) or (state.teamColors and p.TeamColor.Color or Color3.fromRGB(230,50,70));h.OutlineColor=Color3.fromRGB(255,255,255);h.OutlineTransparency=state.outlines and 0 or 1;h.FillTransparency=state.opacity
    local head=ch:FindFirstChild('Head')
    if head then
     local billboard=head:FindFirstChild('EVVO_Label')
     if not billboard then billboard=Instance.new('BillboardGui');billboard.Name='EVVO_Label';billboard.Size=UDim2.fromOffset(200,35);billboard.StudsOffset=Vector3.new(0,2.5,0);billboard.AlwaysOnTop=true;billboard.Parent=head;local text=Instance.new('TextLabel');text.Name='Text';text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.TextStrokeTransparency=0.35;text.TextColor3=Color3.new(1,1,1);text.Font=Enum.Font.GothamBold;text.TextSize=12;text.Parent=billboard end
     billboard.Enabled=state.names or state.distance
     local bits={};if state.names then table.insert(bits,p.DisplayName) end;if state.distance then table.insert(bits,math.floor((myRoot.Position-root.Position).Magnitude)..' studs') end
     local hum=ch:FindFirstChildOfClass('Humanoid');if state.health and hum then table.insert(bits,math.floor(hum.Health)..' HP') end
     if state.showVelocity then table.insert(bits,math.floor(root.AssemblyLinearVelocity.Magnitude)..' spd') end
     if state.showBounty then local bounty=p:GetAttribute('Bounty');if bounty~=nil then table.insert(bits,'$'..tostring(bounty)) end end
     billboard.Text.Text=table.concat(bits,' | ')
    end
   else clearHighlight(p);if ch and ch:FindFirstChild('Head') then local bb=ch.Head:FindFirstChild('EVVO_Label');if bb then bb:Destroy() end end end
  end
 end
end
local elapsed=0
connect(RunService.Heartbeat,function(dt)
 elapsed=elapsed+dt;if elapsed>=state.espRefresh then elapsed=0;safe(updateESP);safe(updateRadar) end
 local ch=localPlayer.Character;local hum=ch and ch:FindFirstChildOfClass('Humanoid')
 if hum then
  if not originalHumanoidValues[hum] then originalHumanoidValues[hum]={walk=hum.WalkSpeed,jump=hum.JumpPower} end
  if state.walk or state.autoSprint then hum.WalkSpeed=(state.walk and state.walkSpeed or originalHumanoidValues[hum].walk)*( (state.autoSprint or (state.sprint and UIS:IsKeyDown(Enum.KeyCode.LeftShift))) and state.sprintMultiplier or 1) end
  if state.jump then hum.UseJumpPower=true;hum.JumpPower=state.jumpPower end
  if state.autoJump and os.clock()-lastJump>state.autoJumpInterval and hum.FloorMaterial~=Enum.Material.Air then lastJump=os.clock();hum.Jump=true end
 end
end)
connect(RunService.Heartbeat,function() if state.gravityEnabled then workspace.Gravity=state.gravityValue end end)
local hudTimer=0
connect(RunService.Heartbeat,function(dt)
 hudTimer=hudTimer+dt;if hudTimer<0.5 then return end;hudTimer=0.0
 local root=localPlayer.Character and localPlayer.Character:FindFirstChild('HumanoidRootPart')
 local bits={' EVVO'}
 if state.speedHud and root then table.insert(bits,math.floor(root.AssemblyLinearVelocity.Magnitude)..' studs/s') end
 if state.playerCount then table.insert(bits,#Players:GetPlayers()..' players') end
 if state.coords and root then local p=root.Position;table.insert(bits,string.format('XYZ %.0f %.0f %.0f',p.X,p.Y,p.Z)) end
 statusGui.Text=table.concat(bits,' | ')
 if state.alerts and root and os.clock()-alertAt>8 then for _,p in ipairs(Players:GetPlayers()) do if p~=localPlayer and p.Team and p.Team.Name:lower():find('police') then local r=p.Character and p.Character:FindFirstChild('HumanoidRootPart');if r and (r.Position-root.Position).Magnitude<=state.alertRange then alertAt=os.clock();warn('[EVVO] Police nearby: '..p.Name);break end end end end
end)
connect(UIS.InputBegan,function(input,processed) if processed then return end;if input.KeyCode==Enum.KeyCode.RightShift then main.Visible=not main.Visible elseif input.KeyCode==Enum.KeyCode.End then if _G.EVVO_V4_CLEANUP then _G.EVVO_V4_CLEANUP() end end end)
connect(UIS.JumpRequest,function() jumpCount=jumpCount+1;if state.infiniteJump then local hum=localPlayer.Character and localPlayer.Character:FindFirstChildOfClass('Humanoid');if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
local function cleanup()
 cameraReset()
 state.esp=false
 workspace.Gravity=originalGravity
 for hum,original in pairs(originalHumanoidValues) do if hum.Parent then pcall(function() hum.WalkSpeed=original.walk;hum.JumpPower=original.jump end) end end
 for p in pairs(highlights) do clearHighlight(p) end
 for _,p in ipairs(Players:GetPlayers()) do local ch=p.Character;local head=ch and ch:FindFirstChild('Head');local bb=head and head:FindFirstChild('EVVO_Label');if bb then bb:Destroy() end end
 for _,dot in pairs(radarDots) do dot:Destroy() end
 for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
 if gui.Parent then gui:Destroy() end
 _G.EVVO_V4_CLEANUP=nil
end
_G.EVVO_V4_CLEANUP=cleanup
connect(close.MouseButton1Click,cleanup)
show('ESP')
print('[EVVO.JAILBREAK] Ultimate V4.1 Navigation and Tools loaded')
