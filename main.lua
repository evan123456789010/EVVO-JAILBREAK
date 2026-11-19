--[[
 EVVO HUB // UNIVERSAL EDITION 1.0.0
 OWNED BY EVVO
 Single-file Luau hub, designed for user-hosted GitHub Raw loading.
 Catalog entries are NOT verified game-specific cheats.
 Generic client-side features may be restricted by the Roblox game/server.
 No third-party remote scripts, webhook, telemetry upload, or hidden network requests.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local player = Players.LocalPlayer
assert(player, "EVVO HUB requires a client LocalPlayer")
local pg = player:WaitForChild("PlayerGui", 10)
assert(pg, "EVVO HUB: PlayerGui unavailable")

local BASE = "EVVO_HUB_UNIVERSAL_V1"
local VERSION = "1.0.0"
local CONFIG_PATH = "EVVO_HUB_v1_config.json"
local alive, started = true, os.clock()
local connections, visuals, originals, noClipParts = {}, {}, setmetatable({}, {__mode="k"}), {}
local errors, alerts, waypointObjects, vehicleHighlights = {}, {}, {}, {}
local worldHighlights, worldMatches, lastWorldScan = {}, {}, 0
local spectateTarget = nil
local currentPage, showPage, refreshPage = "Home", nil, nil
local currentGameName, gameLookup = tostring(game.Name), ""
local selectedGame, gameSearch, gameCategory, gamePage = nil, "", "All", 1
local activeKeyCapture, originalGravity = nil, Workspace.Gravity
local savedPosition, waypoints, gui, main, content, restore
local prevHealth, jumpCount, lastAlert = {}, 0, 0
local radarDots, frameAccumulator, frameCount, framesPerSecond = {}, 0, 0, 60
local accent = Color3.fromRGB(234, 53, 76)

local default = {
 theme="Crimson", scale=1, menuKey="RightShift", panicKey="End", visible=true,
 esp=false, espNames=true, espHealth=true, espDistance=true, espTeam=true,
 espBox=true, espCorners=false, espSkeleton=false, espTracers=false, espHead=false,
 espHighlights=true, espChams=false, espVelocity=false, espBounty=false,
 espRainbow=false, espOcclusion=false, espPoliceOnly=false, espEnemyOnly=false,
 espRange=900, espHz=12, espOpacity=0.45, espThickness=2,
 radar=false, radarRange=350, radarSize=145, policeAlerts=false, policeRange=130,
 aim=false, aimFOV=145, aimSmooth=0.18, aimPrediction=0.05,
 aimTarget="Head", aimPriority="Crosshair", aimVisibility=true, aimTeam=true,
 aimShowFOV=true, aimKey="MouseButton2", crosshair=false, crosshairSize=10,
 speed=false, speedValue=24, jump=false, jumpValue=65, sprint=false,
 sprintMult=1.45, infiniteJump=false, autoJump=false, autoJumpSeconds=1.5,
 gravity=false, gravityValue=196.2, fly=false, flySpeed=55, noclip=false,
 vehicleESP=false, vehicleRange=700, vehicleHUD=true,
 worldESP=false, worldKeyword="chest", worldRange=450, worldLimit=40,
 hud=true, fps=true, ping=true, coords=false, playerCount=true,
 showClock=true, lowFX=false, updateHz=30, notifications=true,
 favorites={}, bindings={}, points={}, customNotes={},
}
local state = {}
for k,v in pairs(default) do
 if type(v)=="table" then state[k]={} else state[k]=v end
end
local fsAvailable = type(readfile)=="function" and type(writefile)=="function"
local function log(msg)
 local s = tostring(msg)
 table.insert(errors,1,os.date("%H:%M:%S").." "..s)
 while #errors>30 do table.remove(errors) end
 warn("[EVVO HUB] "..s)
end
local function protected(fn, ...)
 local ok, a, b = pcall(fn, ...)
 if not ok then log(a); return nil end
 return a,b
end
local function connect(signal, fn)
 local c = signal:Connect(function(...)
  if not alive then return end
  local ok, err = pcall(fn, ...)
  if not ok then log(err) end
 end)
 table.insert(connections,c)
 return c
end
local function loadSettings()
 if not fsAvailable then return end
 local ok, text = pcall(readfile, CONFIG_PATH)
 if not ok or type(text)~="string" then return end
 local valid, data = pcall(function() return HttpService:JSONDecode(text) end)
 if not valid or type(data)~="table" then log("Stored config invalid; defaults loaded");return end
 for k, v in pairs(default) do
  if type(data[k])==type(v) then state[k]=data[k] end
 end
end
loadSettings()
local saveVersion = 0
local function saveSettings()
 if not fsAvailable then return false end
 local ok, encoded = pcall(function() return HttpService:JSONEncode(state) end)
 if not ok then log("Could not encode settings");return false end
 local written, err=pcall(writefile, CONFIG_PATH, encoded)
 if not written then log("Could not save settings: "..tostring(err));return false end
 return true
end
local function scheduleSave()
 saveVersion=saveVersion+1
 local this=saveVersion
 task.delay(1, function()
  if alive and this==saveVersion then saveSettings() end
 end)
end
local function setValue(k,v)
 if state[k]==v then return end
 state[k]=v
 scheduleSave()
end

-- Avoid overlap with previous EVVO editions in PlayerGui.
for _,name in ipairs({BASE, "EVVO_UltimateV4", "EVVO_GUI_TEST"}) do
 local old=pg:FindFirstChild(name)
 if old then protected(function() old:Destroy() end) end
end
local env = _G
-- Terminate older EVVO V4 connections before starting the new hub.
if type(_G.EVVO_V4_CLEANUP)=="function" then protected(_G.EVVO_V4_CLEANUP) end
if type(getgenv)=="function" then
 local ok, result=pcall(getgenv)
 if ok and type(result)=="table" then env=result end
end
if type(env.EVVO_HUB_CLEANUP)=="function" then protected(env.EVVO_HUB_CLEANUP) end

local function color(r,g,b) return Color3.fromRGB(r,g,b) end
local C={background=color(9,10,15), panel=color(18,19,27), panel2=color(25,27,37),
 hover=color(37,39,52), sidebar=color(13,14,20), muted=color(139,145,163),
 text=color(245,246,250), green=color(74,210,142), amber=color(255,187,90), border=color(58,60,73)}
local themeMap={Crimson=color(234,53,76), Ruby=color(193,40,56), Violet=color(174,93,255), Cyan=color(41,198,213), Amber=color(242,153,65)}
accent=themeMap[state.theme] or themeMap.Crimson
local function make(class,parent,props)
 local obj=Instance.new(class)
 for k,v in pairs(props or {}) do obj[k]=v end
 obj.Parent=parent
 return obj
end
local function rounded(obj,r)
 make("UICorner",obj,{CornerRadius=UDim.new(0,r or 9)})
 return obj
end
local function stroke(obj, col, thick)
 return make("UIStroke",obj,{Color=col or C.border,Thickness=thick or 1,Transparency=0.12})
end
local function text(parent,txt,size,bold,props)
 local p={Text=tostring(txt or ""),TextColor3=C.text,BackgroundTransparency=1,
 Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextSize=size or 13,
 TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
 Size=UDim2.new(1,0,0,(size or 13)+14),BorderSizePixel=0}
 for k,v in pairs(props or {}) do p[k]=v end
 return make("TextLabel",parent,p)
end
local function addPadding(obj, top, sides)
 make("UIPadding",obj,{PaddingTop=UDim.new(0,top or 8),PaddingBottom=UDim.new(0,top or 8),
 PaddingLeft=UDim.new(0,sides or 10),PaddingRight=UDim.new(0,sides or 10)})
end

-- GUI is parented to PlayerGui (previously confirmed to render in Madium).
gui=make("ScreenGui",pg,{Name=BASE,ResetOnSpawn=false,IgnoreGuiInset=true,
 ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=999,Enabled=true})
local overlay=make("Frame",gui,{Name="VisualLayer",BackgroundTransparency=1,
 Size=UDim2.fromScale(1,1),ZIndex=1,ClipsDescendants=false})
local fovFrame=rounded(make("Frame",overlay,{BackgroundTransparency=1,BorderSizePixel=0,
 AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(290,290),Visible=false,ZIndex=2}),999)
stroke(fovFrame,accent,1)
local crosshairH=make("Frame",overlay,{BackgroundColor3=accent,BorderSizePixel=0,
 AnchorPoint=Vector2.new(.5,.5),Visible=false,ZIndex=3})
local crosshairV=make("Frame",overlay,{BackgroundColor3=accent,BorderSizePixel=0,
 AnchorPoint=Vector2.new(.5,.5),Visible=false,ZIndex=3})
local statusPill=rounded(make("Frame",gui,{BackgroundColor3=C.panel,BorderSizePixel=0,
 Size=UDim2.fromOffset(450,30),Position=UDim2.new(.5,-225,0,10),ZIndex=10}),8)
stroke(statusPill,C.border,1)
local statusText=text(statusPill,"EVVO HUB // Starting",11,true,{Size=UDim2.new(1,-14,1,0),Position=UDim2.fromOffset(7,0),
 TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=11})
local alertToast=rounded(make("Frame",gui,{BackgroundColor3=C.panel,BorderSizePixel=0,
 Size=UDim2.fromOffset(350,38),AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,48),Visible=false,ZIndex=50}),8)
stroke(alertToast,accent,1)
local toastText=text(alertToast,"",12,true,{Size=UDim2.new(1,-16,1,0),Position=UDim2.fromOffset(8,0),ZIndex=51,TextXAlignment=Enum.TextXAlignment.Center})
local toastGeneration=0
local function toast(msg)
 if not state.notifications then return end
 toastGeneration=toastGeneration+1
 local seq=toastGeneration
 toastText.Text=tostring(msg)
 alertToast.Visible=true
 task.delay(3.4,function()
  if alive and seq==toastGeneration then alertToast.Visible=false end
 end)
end

main=rounded(make("Frame",gui,{Name="Main",BackgroundColor3=C.background,BorderSizePixel=0,
 Size=UDim2.fromOffset(790,510),Position=UDim2.new(.5,-395,.5,-255),Active=true,ZIndex=20}),15)
stroke(main,accent,1.4)
local guiScale=make("UIScale",main,{Scale=math.clamp(state.scale,.65,1.3)})
local drop=rounded(make("Frame",main,{BackgroundColor3=C.panel2,BackgroundTransparency=.72,
 BorderSizePixel=0,Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8),ZIndex=19}),13)
-- Header and navigation
local top=make("Frame",main,{BackgroundColor3=C.panel,BorderSizePixel=0,
 Size=UDim2.new(1,0,0,64),ZIndex=22,Active=true})
rounded(top,15)
make("UIGradient",top,{Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,color(35,18,28)),
 ColorSequenceKeypoint.new(.55,C.panel),
 ColorSequenceKeypoint.new(1,C.background)})})
make("Frame",top,{BackgroundColor3=accent,BorderSizePixel=0,
 Position=UDim2.fromOffset(17,18),Size=UDim2.fromOffset(4,28),ZIndex=23})
text(top,"EVVO  //  HUB",21,true,{Position=UDim2.fromOffset(32,5),Size=UDim2.fromOffset(370,35),ZIndex=23})
text(top,"UNIVERSAL EDITION     •     OWNED BY EVVO",10,true,{Position=UDim2.fromOffset(33,35),Size=UDim2.fromOffset(360,20),TextColor3=C.muted,ZIndex=23})
local function headerButton(symbol,x,w,bg)
 local b=rounded(make("TextButton",top,{Text=symbol,Font=Enum.Font.GothamBold,TextSize=16,
 TextColor3=C.text,BackgroundColor3=bg or C.panel2,BorderSizePixel=0,
 Position=UDim2.new(1,x,0,17),Size=UDim2.fromOffset(w or 33,30),ZIndex=24}),7)
 return b
end
local online=text(top,"●  ONLINE",10,true,{Size=UDim2.fromOffset(110,23),
 Position=UDim2.new(1,-198,0,21),TextColor3=C.green,ZIndex=24,TextXAlignment=Enum.TextXAlignment.Right})
local minButton=headerButton("—",-82,31)
local closeButton=headerButton("×",-43,31,color(126,35,50))
restore=rounded(make("TextButton",gui,{Name="Restore",Text="EVVO  HUB  +",
 Font=Enum.Font.GothamBold,TextSize=13,TextColor3=C.text,BackgroundColor3=C.panel,
 BorderSizePixel=0,Position=UDim2.fromOffset(20,95),Size=UDim2.fromOffset(126,40),
 Visible=false,ZIndex=80}),10)
stroke(restore,accent,1.2)
local sidebar=make("ScrollingFrame",main,{BackgroundColor3=C.sidebar,BorderSizePixel=0,
 Position=UDim2.fromOffset(0,64),Size=UDim2.new(0,165,1,-64),CanvasSize=UDim2.fromOffset(0,0),
 AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=2,ScrollBarImageColor3=accent,ZIndex=22})
addPadding(sidebar,12,9)
make("UIListLayout",sidebar,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
local displayTitle=text(main,"OVERVIEW",18,true,{Position=UDim2.fromOffset(183,72),Size=UDim2.new(1,-200,0,30),ZIndex=23})
local displaySubtitle=text(main,"",11,false,{Position=UDim2.fromOffset(183,100),Size=UDim2.new(1,-200,0,22),
 TextColor3=C.muted,ZIndex=23})
content=rounded(make("ScrollingFrame",main,{BackgroundColor3=C.panel,BorderSizePixel=0,
 Position=UDim2.fromOffset(182,133),Size=UDim2.new(1,-198,1,-148),ZIndex=22,
 ScrollBarThickness=3,ScrollBarImageColor3=accent,AutomaticCanvasSize=Enum.AutomaticSize.Y,
 CanvasSize=UDim2.fromOffset(0,0)}),10)
addPadding(content,13,13)
make("UIListLayout",content,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})

local tabNames={"Home","Games","Visuals","Combat","Movement","Vehicles","World","Players","Navigation","Utilities","Settings","Diagnostics","Credits"}
local tabButtons={}
for _,tab in ipairs(tabNames) do
 local b=rounded(make("TextButton",sidebar,{Text="  "..tab,TextColor3=C.muted,
 TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,
 BackgroundColor3=C.sidebar,BorderSizePixel=0,Size=UDim2.new(1,-2,0,35),ZIndex=23}),8)
 tabButtons[tab]=b
 connect(b.MouseButton1Click,function() if showPage then showPage(tab) end end)
end
local sidebarFoot=text(sidebar,"EVVO • v"..VERSION,10,true,{TextColor3=accent,TextXAlignment=Enum.TextXAlignment.Center,
 Size=UDim2.new(1,-2,0,25),ZIndex=23})
local pageConnections={}
local function clearPage()
 for _,c in ipairs(pageConnections) do pcall(function() c:Disconnect() end) end
 pageConnections={}
 for _,o in ipairs(content:GetChildren()) do if o:IsA("GuiObject") then o:Destroy() end end
 content.CanvasPosition=Vector2.new(0,0)
end
local function pageConnect(signal,fn)
 local c=signal:Connect(function(...)
  if not alive then return end
  local ok,err=pcall(fn,...)
  if not ok then log(err) end
 end)
 table.insert(pageConnections,c)
 return c
end
local function section(title,desc)
 local h=make("Frame",content,{BackgroundTransparency=1,Size=UDim2.new(1,-3,0,desc and 47 or 28),ZIndex=23})
 text(h,title:upper(),13,true,{Size=UDim2.new(1,0,0,25),TextColor3=accent,ZIndex=24})
 if desc then text(h,desc,11,false,{Position=UDim2.fromOffset(0,23),Size=UDim2.new(1,0,0,24),TextColor3=C.muted,TextWrapped=true,ZIndex=24}) end
end
local function note(message)
 local h=rounded(make("Frame",content,{BackgroundColor3=C.panel2,BorderSizePixel=0,
 Size=UDim2.new(1,-4,0,52),ZIndex=23}),8)
 text(h,message,11,false,{Position=UDim2.fromOffset(11,3),Size=UDim2.new(1,-22,1,-6),
 TextColor3=C.muted,TextWrapped=true,ZIndex=24})
end
local function makeAction(label,callback,kind)
 local b=rounded(make("TextButton",content,{Text="  "..label,TextColor3=C.text,
 Font=Enum.Font.GothamMedium,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,
 BackgroundColor3=kind=="danger" and color(104,31,43) or C.panel2,
 BorderSizePixel=0,Size=UDim2.new(1,-4,0,35),ZIndex=24}),8)
 pageConnect(b.MouseButton1Click,function() callback() end)
 return b
end
local function makeToggle(label,key,description)
 local h=rounded(make("Frame",content,{BackgroundColor3=C.panel2,BorderSizePixel=0,
 Size=UDim2.new(1,-4,0,description and 55 or 43),ZIndex=23}),8)
 local lbl=text(h,label,12,true,{Position=UDim2.fromOffset(11,description and 4 or 8),
 Size=UDim2.new(1,-106,0,25),ZIndex=24})
 if description then text(h,description,10,false,{Position=UDim2.fromOffset(11,29),
 Size=UDim2.new(1,-109,0,20),TextColor3=C.muted,ZIndex=24}) end
 local b=rounded(make("TextButton",h,{Font=Enum.Font.GothamBold,TextSize=11,
 TextColor3=C.text,BorderSizePixel=0,Position=UDim2.new(1,-77,.5,-13),
 Size=UDim2.fromOffset(66,26),ZIndex=24}),7)
 local function update()
  local on=state[key] == true
  b.Text=on and "ON" or "OFF"
  b.BackgroundColor3=on and accent or C.hover
 end
 pageConnect(b.MouseButton1Click,function()
  setValue(key,not state[key]);update()
  if key=="fly" and not state.fly then -- physics objects removed in the flight loop
  end
 end)
 update()
 return h
end
local function makeSlider(label,key,min,max,step)
 local h=rounded(make("Frame",content,{BackgroundColor3=C.panel2,BorderSizePixel=0,
 Size=UDim2.new(1,-4,0,68),ZIndex=23}),8)
 local l=text(h,"",12,true,{Position=UDim2.fromOffset(11,4),Size=UDim2.new(1,-22,0,26),ZIndex=24})
 local track=rounded(make("Frame",h,{BackgroundColor3=C.hover,BorderSizePixel=0,
 Position=UDim2.fromOffset(12,47),Size=UDim2.new(1,-24,0,9),ZIndex=24,Active=true}),5)
 local fill=rounded(make("Frame",track,{BackgroundColor3=accent,BorderSizePixel=0,
 Size=UDim2.fromScale(.5,1),ZIndex=25}),5)
 local dragging=false
 local function update()
  local v=tonumber(state[key]) or min
  fill.Size=UDim2.fromScale(math.clamp((v-min)/(max-min),0,1),1)
  l.Text=label.."   "..string.format(step<1 and "%.2f" or "%.0f",v)
 end
 local function at(x)
  local ratio=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
  local raw=min+(max-min)*ratio
  local v=math.clamp(math.floor(raw/step+.5)*step,min,max)
  setValue(key, tonumber(string.format("%.3f",v))); update()
 end
 pageConnect(track.InputBegan,function(i)
  if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true;at(i.Position.X) end
 end)
 pageConnect(UIS.InputChanged,function(i)
  if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then at(i.Position.X) end
 end)
 pageConnect(UIS.InputEnded,function(i)
  if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
 end)
 update()
 return h
end
local function makeChoice(label,key,choices)
 local a=rounded(make("TextButton",content,{Text="",TextColor3=C.text,Font=Enum.Font.GothamMedium,
 TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,BackgroundColor3=C.panel2,
 BorderSizePixel=0,Size=UDim2.new(1,-4,0,35),ZIndex=24}),8)
 local function update() a.Text="  "..label.."    »    "..tostring(state[key]) end
 pageConnect(a.MouseButton1Click,function()
  local idx=table.find(choices,state[key]) or 0
  setValue(key,choices[(idx%#choices)+1]);update()
 end)
 update()
end
local function keyButton(label,key)
 makeAction(label.." : "..tostring(state[key]).." (click to rebind)",function()
  activeKeyCapture=key;toast("Press a key for "..label)
 end)
end
local function makeTextInput(placeholder,initial,cb)
 local t=rounded(make("TextBox",content,{Text=initial or "",PlaceholderText=placeholder,
 PlaceholderColor3=C.muted,Font=Enum.Font.Gotham,TextSize=13,TextColor3=C.text,
 ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,BackgroundColor3=C.panel2,
 BorderSizePixel=0,Size=UDim2.new(1,-4,0,36),ZIndex=24}),8)
 pageConnect(t:GetPropertyChangedSignal("Text"),function() cb(t.Text,false) end)
 pageConnect(t.FocusLost,function(enter) cb(t.Text,enter) end)
 return t
end
local function safeRoot(who)
 local ch=who and who.Character
 return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function myHumanoid()
 local c=player.Character
 return c and c:FindFirstChildOfClass("Humanoid")
end
local function mySeat()
 local h=myHumanoid()
 return h and h.SeatPart and h.SeatPart:IsA("VehicleSeat") and h.SeatPart or nil
end

-- Catalog: candidates for search/favorites, not a promise of a game-specific exploit.
local rawCategories = {
 {"Trending", [[Blox Fruits|Brookhaven RP|Adopt Me!|Murder Mystery 2|RIVALS|Jailbreak|Steal a Brainrot|Steal An Egg|Grow a Garden|99 Nights in the Forest|DOORS|Forsaken|Dandy's World|Dress to Impress|Fisch|Blade Ball|BedWars|Tower of Hell|The Strongest Battlegrounds|Jujutsu Shenanigans|Piggy|Evade|Catalog Avatar Creator|PLS DONATE|Survive Your Ideas|Throw Food For Animals|Dragon Adventures|Sonic Speed Simulator|Steal An Egg and Collect Rare Pets]]},
 {"Anime & Combat", [[Anime Vanguards|Anime Defenders|Anime Adventures|Anime Last Stand|Anime Fighters Simulator|Anime Dimensions|Anime Champions Simulator|Anime Battle Arena|Anime Fighting Simulator|Anime Fighting Simulator X|Anime Souls Simulator|Anime World Tower Defense|Anime Crossover Defense|Anime Reborn|Anime Rangers X|Anime Card Battle|Anime Fantasy|Grand Piece Online|King Legacy|Fruit Battlegrounds|A One Piece Game|Legacy Piece|Demonfall|Project Slayers|Slayer Tycoon|Attack on Titan Revolution|Untitled Boxing Game|Hajime no Ippo|Jujutsu Infinite|Jujutsu Zero|Heroes Battlegrounds|Sorcerer Battlegrounds|Combat Warriors|Ability Wars|Ability Arena|Your Bizarre Adventure|World Zero|Shindo Life|Dueling Grounds|Slap Battles|The Strongest Battlegrounds|Jujutsu Shenanigans|Blox Fruits|Legends Rewritten|Ro-Ghoul|Dragon Ball Rage|Dragon Ball Z Final Stand|Demon Slayer RPG 2|Peroxide|Type Soul|Project Mugetsu|Shinobi Life 2]]},
 {"Shooter & PvP", [[Arsenal|Phantom Forces|Bad Business|Frontlines|RIVALS|Counter Blox|BIG Paintball|BIG Paintball 2|Energy Assault|Deadline|Blackhawk Rescue Mission 5|Apocalypse Rising 2|War Tycoon|Base Wars|Military Tycoon|Mini War|Hypershot|Sniper Arena|SNIPER DUELS|KNIFE DUELS|Gunfight Arena|Gun Testing|Da Hood|Hood Modded|Criminality|The Wild West|BlockSpin|Murder Mystery DUELS|Flee the Facility|Prison Life|Jailbreak|Cops and Robbers|Blade Ball|Death Ball|Dodgeball Legends|Weaponry|Project Lazarus|Zombie Uprising|Zombie Attack|Zombie Rush|Aftermath|The Final Stand 2|Rolling Thunder|Operation Scorpion|Polybattle|The Battle Bricks|Critical Strike|Super Doomspire|Doomspire Brickbattle]]},
 {"Simulator & Pets", [[Pet Simulator X|Pet Simulator 99|Pet Simulator 2|Pet Simulator|Bee Swarm Simulator|Bubble Gum Simulator|Bubble Gum Simulator INFINITY|Saber Simulator|Muscle Legends|Muscle Simulator|Strongman Simulator|Weight Lifting Simulator|Speed Simulator|Speed Run Simulator|Sonic Speed Simulator|Clicker Simulator|Mining Simulator|Mining Simulator 2|Fishing Simulator|Fisch|Deep Fishing|Pet Catchers|Collect All Pets|Creatures of Sonaria|Dinosaur Simulator|Dragon Adventures|Horse Life|Ride A Pet|Pets Universe|Grow a Garden|Garden Tower Defense|Sol's RNG|Aura Craft|Anime Dice|Dungeon Quest|Dungeon Quest Reborn|Treasure Quest|Arm Wrestle Simulator|Toilet Tower Defense|Clicking Legends|Punch Simulator|Eating Simulator|Tapping Legends X|Destruction Simulator|Unboxing Simulator|Magnet Simulator|Ninja Legends|Ninja Legends 2|Saber Simulator|My Wood Farm|Grow a Zoo|Build a Zoo|Steal a Brainrot|Steal An Egg]]},
 {"Tycoon & Building", [[Lumber Tycoon 2|Retail Tycoon|Retail Tycoon 2|Restaurant Tycoon|Restaurant Tycoon 2|Restaurant Tycoon 3|Theme Park Tycoon 2|Water Park World|My Restaurant|My Supermarket|My Prison|My Zoo|My Movie|Build A Boat For Treasure|Plane Crazy|Build the Pyramid|Build a Boss|Build and Kill Zombies|Military Tycoon|War Tycoon|Car Dealership Tycoon|Airport Tycoon|Factory Simulator|Oil Warfare Tycoon|Pet Store Tycoon|2 Player Raid Tycoon|Clone Tycoon 2|Super Hero Tycoon|Wizard Tycoon|Tropical Resort Tycoon|Mega Mansion Tycoon|Bank Tycoon|City Tycoon|Mall Tycoon|House Tycoon|Game Store Tycoon|Computer Tycoon|My Wood Farm|Miner's Haven|Refinery Caves|Oaklands|Make a Cake|Build A Hideout|Build a Bridge|Build a Raft|Build a City|Space Mining Tycoon|Deep Space Tycoon|Theme Park Tycoon|Billionaire Simulator|Mega Fun Tycoon]]},
 {"Driving & Racing", [[Driving Empire|Vehicle Legends|Greenville|Southwest Florida|Ultimate Driving|Car Crushers 2|Car Dealership Tycoon|Midnight Racing Tokyo|Project Trackday|Drive World|Drive City|Taxi Boss|Emergency Response Liberty County|Pilot Training Flight Simulator|Aeronautica|Plane Crazy|Ghost Driver|American Plains Mudding|Southern Mudding|Project Bikelife|WideOpen|Twisted|Dream Car Collection|Mini Race|Race Horses|Offroad Outlaws|Motorcycle Mayhem|Speed Race|Sonic Speed Simulator|Super Car Obby|Formula Racing|Vehicle Simulator|Driving Simulator|Ultimate Driving|Drift Paradise|Project Drift|Race Clicker|Speedway Racing|Grandma's Favorite Car Game|The Long Drive|The Road|The Ride|SharkBite 2|SharkBite|Boat Ride Into a Better Life]]},
 {"Sports", [[Basketball Legends|Basketball Zero|Hoopz|Hoop Central 6|Hoop Central|Practical Basketball|Basketball Stars|Football Fusion 2|Football Fusion 3|NFL Universe Football|Realistic Street Soccer|Blue Lock Rivals|Azure Latch|Illegal Soccer|Super League Soccer|Soccer Legends|That Freekick Challenge|Volleyball Legends|Racket Rivals|Tennis Zero|Tennis Champions|Realistic Golf|Flag Football|Ragdoll Football|Boxing Beta|Untitled Boxing Game|Blade Ball|Death Ball|Dodgeball Legends|Golf Frenzy|Ski Race|Super Golf|Super Striker League|TPS Street Soccer|Goal Kick Simulator|Football Legends|Gym League|Super Power Training Simulator|Boxing League|Ultimate Football|Field Trip Z]]},
 {"Horror & Survival", [[DOORS|Pressure|The Mimic|Apeirophobia|Rainbow Friends|Rainbow Friends Chapter 2|Piggy|Piggy Book 2|Flee the Facility|Evade|Nico's Nextbots|Dandy's World|99 Nights in the Forest|Dead Rails|3008|The Rake Remastered|The Intruder|Identity Fraud|Specter|Specter 2|Paranormica|The Maze|The Backrooms|Residence Massacre|Forgotten Memories|The Night Shift Experience|Short Creepy Stories|The Asylum|The True Backrooms|Alone in a Dark House|The Exit 8|Anomaly Detected|The CAT|Scream And Run|SCP Roleplay|Survive the Killer|Survive the Disasters 2|Survive the Disasters|Survive the Night|The Survival Game|Natural Disaster Survival|Build to Survive|Break In|Break In 2|Camping|Camping 2|Hotel|Mansion|Field Trip Z|The Haunted Imperial Hotel|It Lurks|The Long Drive|Isle|The Lost Rooms|The Elevator]]},
 {"Roleplay & Social", [[Brookhaven RP|Adopt Me!|Welcome to Bloxburg|Berry Avenue|Livetopia|RoCitizens|MeepCity|Club Roblox|Royale High|Dress to Impress|Catalog Avatar Creator|Roblox High School|Roblox High School 2|Work at a Pizza Place|Maple Hospital|Hospital Roleplay|Emergency Response Liberty County|Greenville|Southwest Florida|Clear Skies Over Milwaukee|Bayside High School|Gacha Online|Dreamville RP|Dubai RP|Baddies|Rate My Avatar|Mic Up|Neighbors|PLS DONATE|Booth Game|Social Experiment|Flex Your Account Age|My Avatar|LifeTogether RP|Club Iris|Redcliff City RP|Kavra's Kingdom|Royale High Campus 3|The Plaza|Robloxian High School|Restaurant Roleplay|Pizza Place|Welcome to Farmtown|Sunshine Islands|Bloxy Bingo]]},
 {"Obby & Parkour", [[Tower of Hell|Tower of Misery|Juke's Towers of Hell|Mega Fun Obby|Easy Obby|Impossible Obby|Speed Run 4|Speed Run 5|Parkour|Parkour Reborn|Obby But You're on a Bike|Obby Creator|Bike of Hell|Barry's Prison Run|Escape Running Head|Escape School Obby|Escape the Dentist|Escape the Hospital|Escape the Carnival|Super Checkpoint|Flood Escape 2|Flood Escape Classic|Grapple Cart Obby|Natural Disaster Survival|The Floor Is Lava|Color Block|Color or Die|Deathrun|Longest Answer Wins|Find the Markers|Find the Chomiks|Find the Noobies|Find the Button|Guess the Drawing|Finish the Word|Speed Draw|Tower of Jump|Tower of Difficulty Chart|Steep Steps|Cart Ride Into Rdite|Cart Ride Around Nothing|Bike of Hell|Obby for Bike|Easy Parkour Obby|Mega Easy Obby|Escape Evil Grandpa|Escape The Backrooms Obby|Slide Down a Hill|Sled Simulator]]},
 {"Strategy & Defense", [[Tower Defense Simulator|Tower Battles|Tower Heroes|Tower Blitz|Tower Defense X|Tower Defense Shinobi|Anime Vanguards|Anime Defenders|Anime Last Stand|Anime Adventures|Anime World Tower Defense|Anime Crossover Defense|Anime Reborn|Ultimate Tower Defense|All Star Tower Defense|All Star Tower Defense X|Toilet Tower Defense|Skibidi Tower Defense|Garden Tower Defense|Tower Defense Tycoon|Defend the Statue|Command An Army|Conquer The World WW2|Rise of Nations|The Conquerors 3|Noobs in Combat|Trenches|Napoleonic Wars|Entry Point|Decaying Winter|The Battle Bricks|TDS Legacy|Toy Soldiers|Tower Galactica|Zombie Defense Tycoon|Zombie Tower Defense|Multicrew Tank Combat|Strategy Game|War Nations|Risk Universalis|Base Battles]]},
 {"Classic & Misc", [[Natural Disaster Survival|Work at a Pizza Place|Epic Minigames|Super Bomb Survival|Hide and Seek Extreme|Hide and Seek Transform|The Normal Elevator|The Crazy Elevator|The Elevator|Funky Friday|Friday Night Bloxxin|RoBeats|Roblox Talent Show|Build A Boat For Treasure|Make a Cake|Cook Burgers|Generic Roleplay Gaem|Regretevator|Untitled Tag Game|Item Asylum|Randomizer|Slap Battles|Ability Wars|Make a Wish|Innovation Inc Spaceship|Innovation Inc Thermal Power Plant|Roblox Deathrun|Crossroads|Doomspire Brickbattle|Super Doomspire|Sword Fights on the Heights|Epic Minigames|Roblox Titanic|Flood Escape 2|Roblox Uno|Roblox Chess|Roblox Battles|SharkBite|SharkBite 2|The Crusher|Plates of Fate|Plates of Fate Remastered|Outlaster|Total Roblox Drama|Survivor|Squid Game|Red Light Green Light|The Trials|Draw and Donate|Guess the Logo|Guess the Character|Guess the Anime|Trivia Roblox]]},
}
local catalog, catalogIndex, categoryNames = {}, {}, {"All"}
for _,row in ipairs(rawCategories) do
 local category, packed = row[1],row[2]
 table.insert(categoryNames,category)
 for name in string.gmatch(packed,"[^|]+") do
  local key=string.lower(name)
  if not catalogIndex[key] then
   local entry={name=name,category=category,key=key}
   table.insert(catalog,entry)
   catalogIndex[key]=entry
  end
 end
end
table.sort(catalog,function(a,b) return a.name:lower()<b.name:lower() end)
local function matchingGames()
 local items={}
 local q=string.lower(gameSearch)
 for _,entry in ipairs(catalog) do
  if (gameCategory=="All" or entry.category==gameCategory)
   and (q=="" or string.find(entry.key,q,1,true)) then
   table.insert(items,entry)
  end
 end
 return items
end

-- Universal visuals. No dependency on external Drawing API.
local function teamColor(p)
 if state.espRainbow then
  return Color3.fromHSV((os.clock()*.12)%1,.85,1)
 end
 local tn=p.Team and p.Team.Name:lower() or ""
 if tn:find("police",1,true) then return color(68,144,255) end
 if tn:find("criminal",1,true) then return color(255,99,97) end
 if tn:find("prison",1,true) then return color(246,177,68) end
 return (state.espTeam and p.TeamColor.Color) or accent
end
local function shouldShow(p)
 if p==player then return false end
 local root=safeRoot(p)
 local me=safeRoot(player)
 if not root or not me then return false end
 local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then return false end
 if (root.Position-me.Position).Magnitude>state.espRange then return false end
 if state.espEnemyOnly and player.Team and p.Team==player.Team then return false end
 if state.espPoliceOnly then
  local n=p.Team and p.Team.Name:lower() or ""
  if not n:find("police",1,true) then return false end
 end
 return true
end
local function lineElement(parent, z)
 return make("Frame",parent,{BackgroundColor3=accent,BorderSizePixel=0,
 AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(0,0),Visible=false,ZIndex=z or 4})
end
local function setLine(obj,a,b,thick,col)
 if not obj then return end
 local delta=b-a
 obj.Size=UDim2.fromOffset(math.max(delta.Magnitude,1),thick)
 obj.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
 obj.Rotation=math.deg(math.atan2(delta.Y,delta.X))
 obj.BackgroundColor3=col
 obj.Visible=true
end
local function clearVisual(p)
 local o=visuals[p]
 if not o then return end
 for _,v in pairs(o.items) do
  if typeof(v)=="Instance" then protected(function() v:Destroy() end)
  elseif type(v)=="table" then
   for _,child in pairs(v) do if typeof(child)=="Instance" then protected(function() child:Destroy() end) end end
  end
 end
 if o.highlight then protected(function() o.highlight:Destroy() end) end
 if o.billboard then protected(function() o.billboard:Destroy() end) end
 visuals[p]=nil
end
local function newVisual(p)
 clearVisual(p)
 local ch=p.Character
 if not ch then return end
 local o={items={},character=ch}
 local box=make("Frame",overlay,{BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=4})
 local bs=stroke(box,accent,2)
 local bb=rounded(make("TextLabel",overlay,{BackgroundColor3=C.background,BackgroundTransparency=.2,
 BorderSizePixel=0,Text="",TextSize=11,Font=Enum.Font.GothamBold,TextColor3=C.text,
 Size=UDim2.fromOffset(150,37),Visible=false,TextWrapped=true,ZIndex=5}),6)
 local head=rounded(make("Frame",overlay,{BackgroundColor3=accent,BorderSizePixel=0,
 AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(7,7),Visible=false,ZIndex=5}),99)
 o.items={box=box,bs=bs,label=bb,head=head,tracer=lineElement(overlay,4)}
 o.items.skeleton={}
 for i=1,11 do table.insert(o.items.skeleton,lineElement(overlay,4)) end
 local hi=make("Highlight",ch,{Name="EVVO_HUB_Highlight",Adornee=ch,
 FillColor=accent,OutlineColor=accent,FillTransparency=state.espOpacity,
 OutlineTransparency=.1,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,Enabled=false})
 o.highlight=hi
 visuals[p]=o
 return o
end
local skeletonPairs={
 {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
 {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
 {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
 {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"}
}
local r6Pairs={
 {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
 {"Torso","Left Leg"},{"Torso","Right Leg"}
}
local function visibleRay(p, target)
 local me=safeRoot(player)
 if not me then return false end
 local ray=target-me.Position
 if ray.Magnitude<.01 then return true end
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={player.Character}
 local hit=Workspace:Raycast(me.Position,ray,params)
 return not hit or (hit.Instance and hit.Instance:IsDescendantOf(p.Character))
end
local function updateESP()
 local cam=Workspace.CurrentCamera
 if not cam then return end
 if not state.esp then
  for p in pairs(visuals) do clearVisual(p) end
  return
 end
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=player then
   if not shouldShow(p) then clearVisual(p)
   else
    local root=safeRoot(p)
    local o=visuals[p]
    if not o or o.character~=p.Character then o=newVisual(p) end
    if o and root then
     local col=teamColor(p)
     local me=safeRoot(player)
     local distance=me and (root.Position-me.Position).Magnitude or 0
     local humanoid=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
     local hl=o.highlight
     hl.Enabled=state.espHighlights or state.espChams
     hl.FillTransparency=state.espChams and math.min(state.espOpacity,.45) or 1
     hl.OutlineTransparency=state.espHighlights and 0 or 1
     hl.FillColor=col;hl.OutlineColor=col
     if state.espOcclusion then
      hl.DepthMode=Enum.HighlightDepthMode.Occluded
     else hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop end
     local h=root.Position+Vector3.new(0,3.4,0)
     local b=root.Position-Vector3.new(0,3.5,0)
     local top,onTop=cam:WorldToViewportPoint(h)
     local bottom,onBottom=cam:WorldToViewportPoint(b)
     local center,onScreen=cam:WorldToViewportPoint(root.Position)
     local box=o.items.box
     local lb=o.items.label
     local hd=o.items.head
     local tracer=o.items.tracer
     local skeleton=o.items.skeleton
     if onScreen and onTop and onBottom and center.Z>0 then
      local height=math.max(8,math.abs(bottom.Y-top.Y))
      local width=height*.48
      local bx=center.X-width/2
      local by=top.Y
      box.Visible=state.espBox or state.espCorners
      box.Position=UDim2.fromOffset(bx,by)
      box.Size=UDim2.fromOffset(width,height)
      o.items.bs.Color=col
      o.items.bs.Thickness=state.espThickness
      if state.espCorners then
       o.items.bs.Transparency=1
       -- Corner styling uses the 2D box with transparency and four small corner marks.
       if not o.items.corners then
        o.items.corners={}
        for i=1,8 do table.insert(o.items.corners,lineElement(overlay,5)) end
       end
       local a,bw,bh=Vector2.new(bx,by),width,height
       local len=math.max(5,math.min(width*.25,14))
       local coords={
        {a,a+Vector2.new(len,0)},{a,a+Vector2.new(0,len)},
        {a+Vector2.new(bw,0),a+Vector2.new(bw-len,0)},
        {a+Vector2.new(bw,0),a+Vector2.new(bw,len)},
        {a+Vector2.new(0,bh),a+Vector2.new(len,bh)},
        {a+Vector2.new(0,bh),a+Vector2.new(0,bh-len)},
        {a+Vector2.new(bw,bh),a+Vector2.new(bw-len,bh)},
        {a+Vector2.new(bw,bh),a+Vector2.new(bw,bh-len)} }
       for i,part in ipairs(o.items.corners) do
        local co=coords[i]
        if state.espCorners and co then setLine(part,co[1],co[2],state.espThickness,col) else part.Visible=false end
       end
      else
       o.items.bs.Transparency=0
       if o.items.corners then for _,part in ipairs(o.items.corners) do part.Visible=false end end
      end
      local parts={}
      if state.espNames then table.insert(parts,p.DisplayName) end
      if state.espDistance then table.insert(parts,tostring(math.floor(distance)).." studs") end
      if state.espHealth and humanoid then table.insert(parts,math.floor(humanoid.Health).." HP") end
      if state.espVelocity then table.insert(parts,math.floor(root.AssemblyLinearVelocity.Magnitude).." spd") end
      if state.espBounty then
       local v=p:GetAttribute("Bounty")
       if v~=nil then table.insert(parts,"$"..tostring(v)) end
      end
      lb.Text=table.concat(parts,"  •  ")
      lb.TextColor3=col
      lb.Visible=#parts>0
      lb.Position=UDim2.fromOffset(math.floor(center.X-75),math.max(0,by-41))
      hd.Visible=state.espHead
      hd.Position=UDim2.fromOffset(top.X,top.Y+13)
      hd.BackgroundColor3=col
      if state.espTracers then
       local viewport=cam.ViewportSize
       setLine(tracer,Vector2.new(viewport.X*.5,viewport.Y*.95),Vector2.new(center.X,bottom.Y),state.espThickness,col)
      else tracer.Visible=false end
      local sk=state.espSkeleton and (p.Character:FindFirstChild("UpperTorso") and skeletonPairs or r6Pairs) or {}
      for i,ln in ipairs(skeleton) do
       local pair=sk[i]
       if pair then
        local pa=p.Character:FindFirstChild(pair[1])
        local pb=p.Character:FindFirstChild(pair[2])
        if pa and pb then
         local va,oa=cam:WorldToViewportPoint(pa.Position)
         local vb,ob=cam:WorldToViewportPoint(pb.Position)
         if oa and ob then setLine(ln,Vector2.new(va.X,va.Y),Vector2.new(vb.X,vb.Y),state.espThickness,col)
         else ln.Visible=false end
        else ln.Visible=false end
       else ln.Visible=false end
      end
     else
      box.Visible=false;lb.Visible=false;hd.Visible=false;tracer.Visible=false
      if o.items.corners then for _,part in ipairs(o.items.corners) do part.Visible=false end end
      for _,ln in ipairs(skeleton) do ln.Visible=false end
     end
    end
   end
  end
 end
end

local radarPanel=rounded(make("Frame",gui,{BackgroundColor3=C.panel,BorderSizePixel=0,
 Size=UDim2.fromOffset(state.radarSize+18,state.radarSize+40),Position=UDim2.new(1,-(state.radarSize+35),0,110),
 ZIndex=7,Visible=false}),9)
stroke(radarPanel,accent,1)
local radarTitle=text(radarPanel,"RADAR  •  NORTH ↑",10,true,{Position=UDim2.fromOffset(9,5),Size=UDim2.new(1,-15,0,22),ZIndex=8})
local radarArea=rounded(make("Frame",radarPanel,{BackgroundColor3=C.background,BorderSizePixel=0,
 Position=UDim2.fromOffset(9,27),Size=UDim2.new(1,-18,1,-36),ZIndex=8,ClipsDescendants=true}),8)
local centerDot=rounded(make("Frame",radarArea,{BackgroundColor3=C.text,BorderSizePixel=0,
 AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(7,7),ZIndex=10}),99)
local function updateRadar()
 radarPanel.Visible=state.radar
 if not state.radar then
  for _,d in pairs(radarDots) do d.Visible=false end
  return
 end
 local side=state.radarSize
 radarPanel.Size=UDim2.fromOffset(side+18,side+40)
 radarPanel.Position=UDim2.new(1,-(side+35),0,110)
 local me=safeRoot(player)
 if not me then return end
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=player then
   local root=safeRoot(p)
   local dot=radarDots[p]
   if not dot then
    dot=rounded(make("Frame",radarArea,{BackgroundColor3=accent,BorderSizePixel=0,
     AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(6,6),ZIndex=9}),99)
    radarDots[p]=dot
   end
   if root then
    local relative=root.Position-me.Position
    if relative.Magnitude<=state.radarRange then
     local ratio=(side-18)/math.max(1,state.radarRange)*.5
     dot.Position=UDim2.new(.5,relative.X*ratio,.5,relative.Z*ratio)
     dot.BackgroundColor3=teamColor(p)
     dot.Visible=true
    else dot.Visible=false end
   else dot.Visible=false end
  end
 end
end

-- Optional camera aim assistance: hold RMB; client camera only, no weapon hook.
local function findAimTarget()
 local cam=Workspace.CurrentCamera
 if not cam then return nil end
 local center=cam.ViewportSize*.5
 local candidate, score=nil,math.huge
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=player and p.Character and safeRoot(p) then
   local hum=p.Character:FindFirstChildOfClass("Humanoid")
   local target=p.Character:FindFirstChild(state.aimTarget) or safeRoot(p)
   if hum and hum.Health>0 and target then
    if not (state.aimTeam and player.Team and p.Team==player.Team) then
     local point,onScreen=cam:WorldToViewportPoint(target.Position)
     local dist=(Vector2.new(point.X,point.Y)-center).Magnitude
     if onScreen and point.Z>0 and dist<=state.aimFOV then
      local los=(not state.aimVisibility) or visibleRay(p,target.Position)
      if los then
       local s=state.aimPriority=="Distance" and (safeRoot(p).Position-(safeRoot(player) and safeRoot(player).Position or cam.CFrame.Position)).Magnitude or dist
       if s<score then candidate=target;score=s end
      end
     end
    end
   end
  end
 end
 return candidate
end

-- Character movement (best-effort; server/anti-cheat can override).
local flyVelocity,flyGyro, originalPlatformStand
local function stopFly()
 if flyVelocity then protected(function() flyVelocity:Destroy() end);flyVelocity=nil end
 if flyGyro then protected(function() flyGyro:Destroy() end);flyGyro=nil end
 local hum=myHumanoid()
 if hum and originalPlatformStand~=nil then hum.PlatformStand=originalPlatformStand end
 originalPlatformStand=nil
end
local function updateFly()
 local root=safeRoot(player)
 local hum=myHumanoid()
 if not state.fly or not root or not hum then stopFly();return end
 if not flyVelocity or flyVelocity.Parent~=root then
  stopFly()
  originalPlatformStand=hum.PlatformStand
  hum.PlatformStand=true
  flyVelocity=make("BodyVelocity",root,{Name="EVVO_HUB_Flight",MaxForce=Vector3.new(1e6,1e6,1e6),P=14000,Velocity=Vector3.zero})
  flyGyro=make("BodyGyro",root,{Name="EVVO_HUB_Orientation",MaxTorque=Vector3.new(1e6,1e6,1e6),P=7000,CFrame=root.CFrame})
 end
 local cam=Workspace.CurrentCamera
 if not cam then return end
 local v=Vector3.zero
 if UIS:IsKeyDown(Enum.KeyCode.W) then v=v+cam.CFrame.LookVector end
 if UIS:IsKeyDown(Enum.KeyCode.S) then v=v-cam.CFrame.LookVector end
 if UIS:IsKeyDown(Enum.KeyCode.A) then v=v-cam.CFrame.RightVector end
 if UIS:IsKeyDown(Enum.KeyCode.D) then v=v+cam.CFrame.RightVector end
 if UIS:IsKeyDown(Enum.KeyCode.Space) then v=v+Vector3.yAxis end
 if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then v=v-Vector3.yAxis end
 if v.Magnitude>.001 then v=v.Unit end
 flyVelocity.Velocity=v*state.flySpeed
 flyGyro.CFrame=cam.CFrame
end
local function setNoclip()
 if state.noclip then
  local ch=player.Character
  if not ch then return end
  for _,obj in ipairs(ch:GetDescendants()) do
   if obj:IsA("BasePart") and obj.CanCollide then
    if noClipParts[obj]==nil then noClipParts[obj]=true end
    obj.CanCollide=false
   end
  end
 else
  for part,was in pairs(noClipParts) do
   if part and part.Parent then protected(function() part.CanCollide=was end) end
   noClipParts[part]=nil
  end
 end
end
local function restoreHumanoid()
 for hum, old in pairs(originals) do
  if hum and hum.Parent then protected(function()
   hum.WalkSpeed=old.walk;hum.JumpPower=old.jump;hum.UseJumpPower=old.usePower
  end) end
 end
end

-- Vehicle markers use generic VehicleSeat discovery. Name/availability vary by experience.
local cachedVehicles,lastVehicleScan={},0
local function refreshVehicles()
 if os.clock()-lastVehicleScan<9 then return end
 lastVehicleScan=os.clock()
 cachedVehicles={}
 local count=0
 for _,v in ipairs(Workspace:GetDescendants()) do
  count=count+1
  if count>4500 or #cachedVehicles>=75 then break end
  if v:IsA("VehicleSeat") and v.Parent then
   local model=v:FindFirstAncestorOfClass("Model") or v.Parent
   table.insert(cachedVehicles,{seat=v,model=model})
  end
 end
end
local function updateVehicleESP()
 if not state.vehicleESP then
  for model,hi in pairs(vehicleHighlights) do hi:Destroy();vehicleHighlights[model]=nil end
  return
 end
 refreshVehicles()
 local me=safeRoot(player)
 for _,v in ipairs(cachedVehicles) do
  local model=v.model
  local pos=v.seat.Position
  local qualifies=me and (me.Position-pos).Magnitude<=state.vehicleRange
  if qualifies and model and model.Parent and model:IsA("Model") then
   local hi=vehicleHighlights[model]
   if not hi then
    hi=make("Highlight",model,{Name="EVVO_VehicleHighlight",Adornee=model,
     FillColor=color(255,184,91),OutlineColor=color(255,184,91),
     FillTransparency=1,OutlineTransparency=.2,
     DepthMode=Enum.HighlightDepthMode.Occluded})
    vehicleHighlights[model]=hi
   end
   hi.Enabled=true
  end
 end
 for model,hi in pairs(vehicleHighlights) do
  local ok= false
  for _,v in ipairs(cachedVehicles) do if v.model==model then ok=true;break end end
  if not ok or not model.Parent or (me and model:GetPivot().Position-me.Position).Magnitude>state.vehicleRange then
   hi:Destroy();vehicleHighlights[model]=nil
  end
 end
end

local pages={}
local function setTabActive(tab)
 for name,b in pairs(tabButtons) do
  b.BackgroundColor3=name==tab and C.panel2 or C.sidebar
  b.TextColor3=name==tab and accent or C.muted
 end
end
local function subsectionButton(title,desc,action)
 local row=rounded(make("Frame",content,{BackgroundColor3=C.panel2,BorderSizePixel=0,
 Size=UDim2.new(1,-4,0,57),ZIndex=24}),8)
 text(row,title,12,true,{Position=UDim2.fromOffset(11,4),Size=UDim2.new(1,-120,0,22),ZIndex=25})
 text(row,desc,10,false,{Position=UDim2.fromOffset(11,29),Size=UDim2.new(1,-112,0,20),TextColor3=C.muted,ZIndex=25})
 local b=rounded(make("TextButton",row,{Text="OPEN",BackgroundColor3=accent,BorderSizePixel=0,
 TextColor3=C.text,Font=Enum.Font.GothamBold,TextSize=11,
 Position=UDim2.new(1,-95,.5,-15),Size=UDim2.fromOffset(82,30),ZIndex=26}),7)
 pageConnect(b.MouseButton1Click,action)
 return row
end
-- Generic, name-based world scanner. Highlights matching *visible names*, not hidden loot.
local function clearWorld()
 for obj,hi in pairs(worldHighlights) do
  pcall(function() hi:Destroy() end)
  worldHighlights[obj]=nil
 end
 worldMatches={}
end
local function scanWorld()
 clearWorld()
 lastWorldScan=os.clock()
 if not state.worldESP then return end
 local keyword=string.lower(tostring(state.worldKeyword or ""))
 if #keyword<2 then return end
 local me=safeRoot(player)
 if not me then return end
 local seen=0
 for _,obj in ipairs(Workspace:GetDescendants()) do
  seen=seen+1
  if seen>8500 or #worldMatches>=state.worldLimit then break end
  if (obj:IsA("Model") or obj:IsA("BasePart")) and obj.Parent then
   if string.find(string.lower(obj.Name),keyword,1,true) then
    local insideCharacter=false
    for _,p in ipairs(Players:GetPlayers()) do
     if p.Character and obj:IsDescendantOf(p.Character) then insideCharacter=true;break end
    end
    if not insideCharacter then
     local pos
     if obj:IsA("BasePart") then pos=obj.Position
     else
      local ok, value=pcall(function() return obj:GetPivot().Position end)
      if ok then pos=value end
     end
     if pos and (pos-me.Position).Magnitude<=state.worldRange then
      local hi=make("Highlight",obj,{Name="EVVO_WorldMarker",Adornee=obj,
       FillColor=color(248,185,77),OutlineColor=color(248,185,77),
       FillTransparency=.92,OutlineTransparency=.2,
       DepthMode=Enum.HighlightDepthMode.Occluded})
      worldHighlights[obj]=hi
      table.insert(worldMatches,{name=obj.Name,distance=math.floor((pos-me.Position).Magnitude)})
     end
    end
   end
  end
 end
end
local function stopSpectate()
 spectateTarget=nil
 local cam=Workspace.CurrentCamera
 if cam then
  local hum=myHumanoid()
  if hum then cam.CameraSubject=hum end
 end
end
local function startSpectate(p)
 local cam=Workspace.CurrentCamera
 local hum=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if cam and hum then
  spectateTarget=p
  cam.CameraSubject=hum
  toast("Spectating "..p.Name)
 else toast("Player has no loaded character") end
end

local function profilesSnapshot()
 local ignore={favorites=true,bindings=true,points=true,customNotes=true}
 local snap={}
 for key,value in pairs(default) do
  if not ignore[key] and type(value)~="table" then snap[key]=state[key] end
 end
 return snap
end
local function applySnapshot(snap)
 for key,v in pairs(snap) do
  if default[key]~=nil and type(v)==type(default[key]) and type(v)~="table" then
   state[key]=v
  end
 end
 if state.theme then accent=themeMap[state.theme] or accent end
 guiScale.Scale=math.clamp(tonumber(state.scale) or 1,.65,1.3)
 scheduleSave()
end
local function refreshTheme()
 accent=themeMap[state.theme] or themeMap.Crimson
 if gui then
  for _,obj in ipairs({fovFrame,crosshairH,crosshairV,sidebarFoot,radarTitle}) do
   if obj and obj:IsA("TextLabel") then obj.TextColor3=accent
   elseif obj and obj:IsA("Frame") and obj~=fovFrame then obj.BackgroundColor3=accent end
  end
  local mainSt=main:FindFirstChildOfClass("UIStroke")
  if mainSt then mainSt.Color=accent end
  local fovStroke=fovFrame:FindFirstChildOfClass("UIStroke")
  if fovStroke then fovStroke.Color=accent end
 end
 setTabActive(currentPage)
end

pages.Home=function()
 section("Welcome to EVVO HUB","Search hundreds of game names; universal client tools are separate from game-specific support.")
 note("Current place: "..tostring(game.PlaceId).."   |   Universe: "..tostring(game.GameId).."\nGame: "..tostring(currentGameName))
 local statBar=make("Frame",content,{BackgroundTransparency=1,Size=UDim2.new(1,-4,0,59),ZIndex=23})
 for i,card in ipairs({{tostring(#catalog),"GAMES"},{tostring(#Players:GetPlayers()),"PLAYERS"},{"13","PANELS"}}) do
  local tile=rounded(make("Frame",statBar,{BackgroundColor3=C.panel2,BorderSizePixel=0,
   Position=UDim2.new((i-1)/3,(i-1)*2,0,0),Size=UDim2.new(.31,0,1,0),ZIndex=24}),9)
  text(tile,card[1],19,true,{Position=UDim2.fromOffset(12,4),Size=UDim2.new(1,-20,0,29),TextColor3=accent,ZIndex=25})
  text(tile,card[2],10,true,{Position=UDim2.fromOffset(12,34),Size=UDim2.new(1,-20,0,17),TextColor3=C.muted,ZIndex=25})
 end
 subsectionButton("GAME DIRECTORY",tostring(#catalog).." distinct names • searchable • favorites",function() showPage("Games") end)
 subsectionButton("VISUAL ENGINE","3D highlights, 2D boxes, skeleton, radar and overlays",function() showPage("Visuals") end)
 subsectionButton("MOVEMENT LAB","Speed, jump, flight, noclip and saved positions",function() showPage("Movement") end)
 subsectionButton("WORLD SCANNER","Configurable keyword-based object markers",function() showPage("World") end)
 subsectionButton("DIAGNOSTICS","Check executor APIs and export error logs",function() showPage("Diagnostics") end)
 section("Quick start")
 makeToggle("Enable player ESP","esp","Client-only highlights and optional overlays")
 makeToggle("Show mini radar","radar")
 makeToggle("Performance HUD","hud")
 makeAction("Save all settings",function() toast(saveSettings() and "Settings saved" or "Session settings only") end)
 note("Scripts are not downloaded from unknown script websites. The hub ships with auditable built-in modules. Catalog ≠ game exploit support.")
end

pages.Games=function()
 section("Universal game catalog","Select and favorite games. A catalog listing is not a promise of a functioning game-specific cheat.")
 local match=state.bindings[tostring(game.PlaceId)] or state.bindings["u:"..tostring(game.GameId)]
 note("Detected: "..currentGameName.."   |   Bound entry: "..tostring(match or "None").."\nPlace ID: "..game.PlaceId)
 local chosen=text(content,"Selected: "..(selectedGame and selectedGame.name or "none"),13,true,
  {TextColor3=accent,Size=UDim2.new(1,-4,0,30)})
 local searchBox=makeTextInput("Search titles (e.g. Blox Fruits, Jailbreak)...",gameSearch,function(input)
  gameSearch=input
  gamePage=1
  if refreshPage then refreshPage() end
 end)
 local filterButton=makeAction("Category: "..gameCategory.."   (click to cycle)",function()
  local i=table.find(categoryNames,gameCategory) or 0
  gameCategory=categoryNames[(i%#categoryNames)+1]
  gamePage=1
  filterButton.Text="  Category: "..gameCategory.."   (click to cycle)"
  if refreshPage then refreshPage() end
 end)
 local gameRows=make("Frame",content,{BackgroundTransparency=1,Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=23})
 make("UIListLayout",gameRows,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
 local pageInfo=text(content,"",11,false,{TextColor3=C.muted,Size=UDim2.new(1,-4,0,24)})
 local function renderRows()
  for _,g in ipairs(gameRows:GetChildren()) do if g:IsA("GuiObject") then g:Destroy() end end
  local result=matchingGames()
  local totalPages=math.max(1,math.ceil(#result/8))
  gamePage=math.clamp(gamePage,1,totalPages)
  pageInfo.Text=string.format("%d results  •  Page %d / %d",#result,gamePage,totalPages)
  chosen.Text="SELECTED   »   "..(selectedGame and selectedGame.name or "None")
  for index=(gamePage-1)*8+1,math.min(gamePage*8,#result) do
   local g=result[index]
   local row=rounded(make("Frame",gameRows,{BackgroundColor3=C.panel2,BorderSizePixel=0,
    Size=UDim2.new(1,0,0,49),ZIndex=24}),8)
   text(row,g.name,12,true,{Position=UDim2.fromOffset(10,3),Size=UDim2.new(1,-175,0,22),ZIndex=25})
   text(row,g.category.."  •  Catalog only",10,false,{Position=UDim2.fromOffset(10,25),
    Size=UDim2.new(1,-174,0,19),TextColor3=C.muted,ZIndex=25})
   local sel=rounded(make("TextButton",row,{Text="SELECT",Font=Enum.Font.GothamBold,TextSize=10,
    TextColor3=C.text,BackgroundColor3=C.hover,BorderSizePixel=0,
    Position=UDim2.new(1,-134,.5,-13),Size=UDim2.fromOffset(76,27),ZIndex=25}),6)
   local star=rounded(make("TextButton",row,{Text=state.favorites[g.name] and "★" or "☆",Font=Enum.Font.GothamBold,
    TextSize=20,TextColor3=state.favorites[g.name] and C.amber or C.muted,BackgroundColor3=C.hover,
    BorderSizePixel=0,Position=UDim2.new(1,-49,.5,-13),Size=UDim2.fromOffset(37,27),ZIndex=25}),6)
   -- Row controls are destroyed alongside their row, disconnecting their own signals.
   sel.MouseButton1Click:Connect(function()
    selectedGame=g
    chosen.Text="SELECTED   »   "..g.name
    toast("Selected "..g.name.." (catalog only)")
   end)
   star.MouseButton1Click:Connect(function()
    state.favorites[g.name]=not state.favorites[g.name] or nil
    star.Text=state.favorites[g.name] and "★" or "☆"
    star.TextColor3=state.favorites[g.name] and C.amber or C.muted
    scheduleSave()
   end)
  end
 end
 refreshPage=renderRows
 renderRows()
 local pager=make("Frame",content,{BackgroundTransparency=1,Size=UDim2.new(1,-4,0,36),ZIndex=23})
 local prev=rounded(make("TextButton",pager,{Text="◀ PREVIOUS",Font=Enum.Font.GothamBold,TextSize=11,
  TextColor3=C.text,BackgroundColor3=C.hover,BorderSizePixel=0,Size=UDim2.new(.48,0,1,0),ZIndex=24}),7)
 local nextBtn=rounded(make("TextButton",pager,{Text="NEXT ▶",Font=Enum.Font.GothamBold,TextSize=11,
  TextColor3=C.text,BackgroundColor3=C.hover,BorderSizePixel=0,
  Position=UDim2.new(.52,0,0,0),Size=UDim2.new(.48,0,1,0),ZIndex=24}),7)
 pageConnect(prev.MouseButton1Click,function() gamePage=math.max(1,gamePage-1);renderRows() end)
 pageConnect(nextBtn.MouseButton1Click,function() gamePage=gamePage+1;renderRows() end)
 makeAction("Bind SELECTED game to current Place ID",function()
  if not selectedGame then toast("Select a game first");return end
  state.bindings[tostring(game.PlaceId)]=selectedGame.name
  if game.GameId~=0 then state.bindings["u:"..tostring(game.GameId)]=selectedGame.name end
  scheduleSave();toast("Bound this place to "..selectedGame.name)
 end)
 makeAction("Show favorite games",function()
  local n=0
  for _ in pairs(state.favorites) do n=n+1 end
  toast(tostring(n).." favorites stored")
  local parts={}
  for nme in pairs(state.favorites) do table.insert(parts,nme) end
  table.sort(parts)
  print("[EVVO HUB] Favorite games: "..table.concat(parts,", "))
 end)
end

pages.Visuals=function()
 section("Player visual engine","All render overlays are local. Enable only what your device handles comfortably.")
 makeToggle("Master ESP","esp","Required for player overlay features")
 makeToggle("3D outlines / highlights","espHighlights")
 makeToggle("Filled chams","espChams")
 makeToggle("2D boxes","espBox")
 makeToggle("Corner boxes","espCorners")
 makeToggle("Skeleton links","espSkeleton")
 makeToggle("Screen tracers","espTracers")
 makeToggle("Head markers","espHead")
 makeToggle("Player display names","espNames")
 makeToggle("Distance labels","espDistance")
 makeToggle("Health labels","espHealth")
 makeToggle("Velocity labels","espVelocity")
 makeToggle("Bounty attribute labels","espBounty","Only displays if a game exposes Bounty as an attribute")
 makeToggle("Use team colors","espTeam")
 makeToggle("Rainbow coloring","espRainbow")
 makeToggle("Occluded highlights","espOcclusion","Makes highlights obey world depth")
 makeToggle("Only show other teams","espEnemyOnly")
 makeToggle("Police-only filter","espPoliceOnly")
 makeSlider("ESP max distance (studs)","espRange",100,2500,50)
 makeSlider("ESP refresh (Hz)","espHz",3,30,1)
 makeSlider("Highlight opacity control","espOpacity",.1,.9,.05)
 makeSlider("ESP line thickness","espThickness",1,5,1)
 section("Radar & alerts")
 makeToggle("2D top-down radar","radar")
 makeSlider("Radar range","radarRange",50,1200,25)
 makeSlider("Radar size","radarSize",95,260,5)
 makeToggle("Police proximity alerts","policeAlerts")
 makeSlider("Police warning distance","policeRange",30,500,10)
 note("ESP refresh uses reusable UI objects and basic distance filtering. Large servers or anti-cheat restrictions may still affect performance.")
end

pages.Combat=function()
 section("Camera & aiming","Camera-based aim assistance only. No server weapon hooks, guaranteed hits, or fabricated silent-aim claims.")
 makeToggle("Aim assist (hold RMB)","aim","Changes local camera orientation; depends on game's camera")
 makeToggle("Show aim FOV circle","aimShowFOV")
 makeToggle("Line-of-sight verification","aimVisibility")
 makeToggle("Ignore teammates","aimTeam")
 makeChoice("Target body part","aimTarget",{"Head","HumanoidRootPart"})
 makeChoice("Target priority","aimPriority",{"Crosshair","Distance"})
 makeSlider("Aim FOV radius (px)","aimFOV",40,400,5)
 makeSlider("Aim smoothing (0.03-0.8)","aimSmooth",.03,.8,.01)
 makeSlider("Velocity prediction (seconds)","aimPrediction",0,.25,.01)
 section("Crosshair")
 makeToggle("Custom center crosshair","crosshair")
 makeSlider("Crosshair size","crosshairSize",4,28,1)
 note("Game-specific recoil, ammo, rapid-fire, triggerbot and hit manipulation are intentionally not labeled working. They require verified weapon integration for each experience.")
end

pages.Movement=function()
 section("Player motion","The game server may override character properties and movement.")
 makeToggle("Custom WalkSpeed","speed")
 makeSlider("WalkSpeed","speedValue",16,180,1)
 makeToggle("Custom JumpPower","jump")
 makeSlider("JumpPower","jumpValue",50,220,5)
 makeToggle("Sprint while holding LeftShift","sprint")
 makeSlider("Sprint multiplier","sprintMult",1.1,3,.05)
 makeToggle("Infinite jump","infiniteJump")
 makeToggle("Auto jump","autoJump")
 makeSlider("Auto jump every (seconds)","autoJumpSeconds",.3,5,.1)
 makeToggle("Custom gravity","gravity")
 makeSlider("World gravity","gravityValue",25,250,5)
 makeToggle("Flight mode (WASD/Space/Ctrl)","fly")
 makeSlider("Flight speed","flySpeed",10,250,5)
 makeToggle("Noclip collisions","noclip")
 section("Movement presets")
 makeAction("Normal movement",function()
  state.speed=false;state.jump=false;state.sprint=false;state.fly=false;state.noclip=false
  state.gravity=false;state.infiniteJump=false;state.autoJump=false
  stopFly();setNoclip();restoreHumanoid();Workspace.Gravity=originalGravity
  scheduleSave();showPage("Movement");toast("Movement restored")
 end)
 makeAction("Agile preset (speed + jump)",function()
  state.speed=true;state.jump=true;state.speedValue=28;state.jumpValue=75
  scheduleSave();showPage("Movement")
 end)
 note("Use the panic key or X to disable everything and attempt to restore modified character settings.")
end

pages.Vehicles=function()
 section("Vehicle tools","Generic VehicleSeat data; custom game vehicles may not use VehicleSeat.")
 makeToggle("Vehicle ESP highlights","vehicleESP")
 makeSlider("Vehicle detection range","vehicleRange",100,2000,50)
 makeToggle("Vehicle speed HUD","vehicleHUD")
 makeAction("Rescan vehicle seats",function() lastVehicleScan=0;refreshVehicles();toast(#cachedVehicles.." seats found") end)
 makeAction("Print nearby vehicle information",function()
  refreshVehicles()
  local me=safeRoot(player)
  for _,v in ipairs(cachedVehicles) do
   if v.seat.Parent then
    local distance=me and math.floor((me.Position-v.seat.Position).Magnitude) or -1
    print("[EVVO VEHICLE]",v.model.Name,"distance",distance,"driver",v.seat.Occupant and v.seat.Occupant.Parent.Name or "none")
   end
  end
 end)
 note("Vehicle acceleration, flying physics, garage purchasing, and teleporting are game-controlled. This module provides tracking and telemetry instead of fake vehicle modification switches.")
end

pages.World=function()
 section("World object scanner","Client-side, keyword-based highlights. Results require exposed Workspace names and streaming visibility.")
 makeToggle("Enable name-based world ESP","worldESP")
 makeSlider("World scan distance","worldRange",50,1800,25)
 makeSlider("Maximum scan results","worldLimit",5,80,5)
 makeTextInput("Object name keyword, e.g. chest",state.worldKeyword,function(value,submit)
  state.worldKeyword=value
  scheduleSave()
  if submit then scanWorld();toast("Scanned for: "..value) end
 end)
 makeAction("Scan world now",function()
  scanWorld();toast("Found "..#worldMatches.." matching objects")
  print("[EVVO WORLD] Query: "..state.worldKeyword)
  for _,entry in ipairs(worldMatches) do print(entry.name,entry.distance.." studs") end
 end)
 makeAction("Clear world markers",function()
  state.worldESP=false;clearWorld();scheduleSave();showPage("World")
 end)
 note("This does not bypass StreamingEnabled, reveal server-hidden objects, or auto-collect items. Large maps are scanned with a hard object cap.")
end

pages.Players=function()
 section("Player directory & spectate","Spectate live characters using the local camera. No private player information is collected.")
 local all=Players:GetPlayers()
 table.sort(all,function(a,b) return a.Name:lower()<b.Name:lower() end)
 note(""..#all.." players in this server   •   Spectating: "..(spectateTarget and spectateTarget.Name or "Self"))
 makeAction("Return camera to your character",function() stopSpectate();showPage("Players") end)
 for _,p in ipairs(all) do
  if p~=player then
   local t=p
   local row=rounded(make("Frame",content,{BackgroundColor3=C.panel2,BorderSizePixel=0,
    Size=UDim2.new(1,-4,0,42),ZIndex=24}),8)
   text(row,t.DisplayName.." (@"..t.Name..")",11,true,{Position=UDim2.fromOffset(10,0),
    Size=UDim2.new(1,-120,1,0),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=25})
   local b=rounded(make("TextButton",row,{Text="SPECTATE",TextColor3=C.text,
    Font=Enum.Font.GothamBold,TextSize=10,BackgroundColor3=C.hover,BorderSizePixel=0,
    Position=UDim2.new(1,-100,.5,-13),Size=UDim2.fromOffset(89,27),ZIndex=25}),6)
   pageConnect(b.MouseButton1Click,function() startSpectate(t) end)
  end
 end
end

local function addWaypointMarker(point)
 if not point or not point.xyz then return end
 local vec=Vector3.new(point.xyz[1],point.xyz[2],point.xyz[3])
 local marker=make("Part",Workspace,{Name="EVVO_Waypoint_"..point.name,Anchored=true,
  CanCollide=false,CanTouch=false,CanQuery=false,Size=Vector3.new(.4,.4,.4),
  Position=vec+Vector3.new(0,4,0),Transparency=1})
 local bb=make("BillboardGui",marker,{Adornee=marker,AlwaysOnTop=true,MaxDistance=1400,
  Size=UDim2.fromOffset(180,33),StudsOffset=Vector3.new(0,2,0)})
 local title=rounded(make("TextLabel",bb,{Text="◆  "..point.name,Font=Enum.Font.GothamBold,TextSize=12,
  TextColor3=accent,BackgroundColor3=C.background,BackgroundTransparency=.15,
  Size=UDim2.fromScale(1,1),BorderSizePixel=0}),7)
 table.insert(waypointObjects,marker)
end
local function rebuildWaypointMarkers()
 for _,part in ipairs(waypointObjects) do if part.Parent then part:Destroy() end end
 waypointObjects={}
 for _,p in ipairs(state.points) do addWaypointMarker(p) end
end
pages.Navigation=function()
 section("Waypoints & positions","Save local coordinates; optional client-side repositioning may be corrected by the server.")
 makeAction("Save current location",function()
  local root=safeRoot(player)
  if not root then toast("Character not found");return end
  local xyz=root.Position
  savedPosition=root.CFrame
  local name="Location "..tostring(#state.points+1)
  table.insert(state.points,{name=name,xyz={math.floor(xyz.X),math.floor(xyz.Y),math.floor(xyz.Z)}})
  rebuildWaypointMarkers();scheduleSave();showPage("Navigation");toast("Saved "..name)
 end)
 makeAction("Return to last saved position",function()
  local root=safeRoot(player)
  if root and savedPosition then root.CFrame=savedPosition;toast("Return attempted")
  else toast("Save a position first") end
 end)
 if #state.points==0 then note("No waypoints saved yet.") end
 for idx,point in ipairs(state.points) do
  local p=point
  local i=idx
  if type(p)=="table" and type(p.xyz)=="table" and #p.xyz==3 then
   local coords=table.concat(p.xyz,", ")
   makeAction(p.name.."   |   "..coords.."   [GO]",function()
    local root=safeRoot(player)
    if root then root.CFrame=CFrame.new(p.xyz[1],p.xyz[2]+3,p.xyz[3]);toast("Attempted waypoint travel") end
   end)
   makeAction("Remove "..p.name,function()
    table.remove(state.points,i)
    rebuildWaypointMarkers();scheduleSave();showPage("Navigation")
   end,"danger")
  end
 end
 if #state.points>0 then
  makeAction("Copy waypoints as JSON",function()
   local s=HttpService:JSONEncode(state.points)
   if type(setclipboard)=="function" then protected(setclipboard,s);toast("Waypoints copied")
   else print("[EVVO WAYPOINTS] "..s);toast("Printed waypoints to console") end
  end)
 end
 section("Navigation details")
 note("Saved waypoint markers are created locally and do not alter server game objects. Use vehicle/robbery routes only when their actual world positions are available.")
end

pages.Utilities=function()
 section("Performance & overlays")
 makeToggle("Status HUD","hud")
 makeToggle("FPS indicator","fps")
 makeToggle("Ping indicator","ping")
 makeToggle("Player count","playerCount")
 makeToggle("Coordinate indicator","coords")
 makeToggle("Session uptime","showClock")
 makeSlider("General update rate (Hz)","updateHz",5,60,1)
 makeToggle("Reduced local effects","lowFX","Disables optional 2D extras when rendering")
 section("Universal utilities")
 makeAction("Print live session report",function()
  print("[EVVO SESSION]",currentGameName,game.PlaceId,game.GameId,"players",#Players:GetPlayers(),
    "time",math.floor(os.clock()-started),"errors",#errors)
  toast("Report sent to output console")
 end)
 makeAction("Copy current game identification",function()
  local s="Game: "..currentGameName.." | Place ID: "..game.PlaceId.." | Universe ID: "..game.GameId
  if type(setclipboard)=="function" then protected(setclipboard,s);toast("Game ID copied")
  else print(s);toast("Printed to output console") end
 end)
 makeAction("Save current feature profile",function()
  local id="u:"..tostring(game.GameId)
  state.customNotes[id]=profilesSnapshot()
  scheduleSave();toast("Saved profile for this universe")
 end)
 makeAction("Load profile for this universe",function()
  local snap=state.customNotes["u:"..tostring(game.GameId)]
  if type(snap)=="table" then applySnapshot(snap);toast("Loaded universe profile");showPage("Utilities")
  else toast("No saved universe profile") end
 end)
 makeAction("Balanced performance preset",function()
  state.espHz=10;state.updateHz=20;state.espSkeleton=false;state.espTracers=false
  state.lowFX=true;scheduleSave();showPage("Utilities");toast("Balanced preset applied")
 end)
end

pages.Settings=function()
 section("Appearance","EVVO's default theme is deep black with crimson-red accents.")
 makeChoice("Accent theme","theme",{"Crimson","Ruby","Violet","Cyan","Amber"})
 makeSlider("Interface scale","scale",.7,1.3,.05)
 makeToggle("Show toast notifications","notifications")
 section("Hotkeys")
 keyButton("Show / hide menu","menuKey")
 keyButton("Emergency shutdown","panicKey")
 makeAction("Save settings now",function() toast(saveSettings() and "Settings saved on disk" or "File API unavailable — session only") end)
 makeAction("Export config to clipboard",function()
  local ok,s=pcall(function() return HttpService:JSONEncode(state) end)
  if not ok then toast("Export failed");return end
  if type(setclipboard)=="function" then protected(setclipboard,s);toast("JSON copied to clipboard")
  else print("[EVVO CONFIG] "..s);toast("Printed JSON to console") end
 end)
 makeAction("Restore default feature values",function()
  local savedFav=state.favorites;local savedPoints=state.points;local savedBindings=state.bindings
  for k,v in pairs(default) do state[k]=type(v)=="table" and {} or v end
  state.favorites=savedFav;state.points=savedPoints;state.bindings=savedBindings
  stopFly();setNoclip();restoreHumanoid();Workspace.Gravity=originalGravity
  scheduleSave();showPage("Settings");toast("Restored feature defaults")
 end,"danger")
 note("Settings persist to "..CONFIG_PATH.." only when Madium provides readfile/writefile. Otherwise, preferences remain in memory during the session.")
end

pages.Diagnostics=function()
 section("Compatibility report","No unsupported functionality is silently reported as working.")
 local function supported(name,yes)
  local label=(yes and "✓ " or "× ")..name.." : "..(yes and "available" or "unavailable")
  local o=text(content,label,12,true,{TextColor3=yes and C.green or C.amber,Size=UDim2.new(1,-4,0,24)})
 end
 supported("PlayerGui",pg~=nil)
 supported("loadstring",type(loadstring)=="function")
 supported("game:HttpGet",type(game.HttpGet)=="function")
 supported("Drawing.new",type(Drawing)=="table" and type(Drawing.new)=="function")
 supported("gethui",type(gethui)=="function")
 supported("readfile",type(readfile)=="function")
 supported("writefile",type(writefile)=="function")
 supported("setclipboard",type(setclipboard)=="function")
 supported("mouse1click",type(mouse1click)=="function")
 supported("Local camera",Workspace.CurrentCamera~=nil)
 section("Module status")
 note("Built-in: UI, catalog, favorites, profiles, ESP, 2D radar, camera aim, movement, vehicle telemetry, world scanner, spectate, waypoints, diagnostics.\nNOT INCLUDED: verified game-specific exploit adapters, cash duplication, remote robbery scripts, weapon hooks.")
 makeAction("Run GUI smoke test",function()
  local valid=gui.Parent==pg and main.Parent==gui and content.Parent==main
  toast(valid and "GUI structure OK" or "GUI hierarchy failed")
  print("[EVVO GUI CHECK]",valid,gui:GetFullName())
 end)
 makeAction("Print last 30 errors",function()
  print("[EVVO ERROR LOG]\n"..table.concat(errors,"\n"))
  toast("Errors printed to output")
 end)
 makeAction("Copy error report",function()
  local value="EVVO HUB v"..VERSION.."\nPlace: "..game.PlaceId.."\n"..table.concat(errors,"\n")
  if type(setclipboard)=="function" then protected(setclipboard,value);toast("Report copied")
  else print(value);toast("Report printed to console") end
 end)
 note("Execution in Madium is not tested by the builder. These diagnostics expose API availability, not proof that games allow each function.")
end

pages.Credits=function()
 section("EVVO HUB","UNIVERSAL EDITION // VERSION "..VERSION)
 note("╔  EVVO.JAILBREAK\n╠  PROJECT: EVVO HUB\n╠  DEVELOPER: EVVO\n╚  OWNED BY EVVO")
 note("Source architecture: standalone single-file Luau. GUI and game tools use Roblox client APIs. No external UI library or downloaded third-party exploits.")
 note("Game names are used as searchable discovery labels. Inclusion does not claim ownership, endorsement, live verification, or a working per-game cheat.")
 makeAction("Open game directory",function() showPage("Games") end)
 makeAction("Show version in console",function() print("[EVVO HUB] v"..VERSION.." // OWNED BY EVVO") end)
end

showPage=function(name)
 if not alive then return end
 if type(pages[name])~="function" then name="Home" end
 currentPage=name
 refreshPage=nil
 clearPage()
 setTabActive(name)
 displayTitle.Text=string.upper(name)
 displaySubtitle.Text=({Home="COMMAND CENTER / ONLINE", Games="SEARCH • FAVORITES • PLACE BINDINGS",
  Visuals="PLAYER OVERLAYS • RADAR • FILTERS",Combat="CAMERA CONTROL • FOV • CROSSHAIR",
  Movement="MOBILITY • FLIGHT • HOTKEYS",Vehicles="SEAT DISCOVERY • VEHICLE TRACKING",
  World="KEYWORD SEARCH • LOCAL OBJECT MARKERS",Players="PLAYER LIST • CAMERA SPECTATE",
  Navigation="WAYPOINTS • LOCAL MARKERS",Utilities="PROFILES • TELEMETRY • PERFORMANCE",
  Settings="THEME • KEYBINDS • EXPORT",Diagnostics="API CAPABILITIES • ERROR LOG",
  Credits="EVVO // OWNED BY EVVO"})[name] or "EVVO HUB"
 protected(pages[name])
end

-- Make the GUI draggable with mouse or touch.
do
 local dragging=false
 local origin,base
 connect(top.InputBegan,function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
   dragging=true;origin=input.Position;base=main.Position
  end
 end)
 connect(UIS.InputChanged,function(input)
  if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
   local delta=input.Position-origin
   main.Position=UDim2.new(base.X.Scale,base.X.Offset+delta.X/math.max(guiScale.Scale,.1),
    base.Y.Scale,base.Y.Offset+delta.Y/math.max(guiScale.Scale,.1))
  end
 end)
 connect(UIS.InputEnded,function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
 end)
end
local function setVisible(open)
 if not alive then return end
 main.Visible=open
 restore.Visible=not open
 state.visible=open
end
connect(minButton.MouseButton1Click,function() setVisible(false) end)
connect(restore.MouseButton1Click,function() setVisible(true) end)

-- Input and runtime scheduling.
connect(UIS.InputBegan,function(input,processed)
 if activeKeyCapture and input.UserInputType==Enum.UserInputType.Keyboard then
  local name=input.KeyCode.Name
  if name==state.menuKey or name==state.panicKey then
   toast("That key is already in use")
  else
   setValue(activeKeyCapture,name)
   toast("Bound "..name)
  end
  activeKeyCapture=nil
  if currentPage=="Settings" then showPage("Settings") end
  return
 end
 if processed then return end
 if input.UserInputType==Enum.UserInputType.Keyboard then
  if input.KeyCode.Name==state.menuKey then setVisible(not main.Visible) end
  if input.KeyCode.Name==state.panicKey and type(env.EVVO_HUB_CLEANUP)=="function" then env.EVVO_HUB_CLEANUP() end
 end
end)
connect(UIS.JumpRequest,function()
 jumpCount=jumpCount+1
 if state.infiniteJump then
  local h=myHumanoid()
  if h and h.Health>0 then h:ChangeState(Enum.HumanoidStateType.Jumping) end
 end
end)
connect(Players.PlayerRemoving,function(p)
 clearVisual(p)
 if radarDots[p] then radarDots[p]:Destroy();radarDots[p]=nil end
end)

local engineElapsed, hudElapsed, physicsElapsed, autoJumpAt = 0,0,0,0
local worldElapsed=0
local lastTheme=state.theme
local function updateHud(dt)
 frameAccumulator=frameAccumulator+dt
 frameCount=frameCount+1
 if frameAccumulator>=.65 then
  framesPerSecond=math.floor(frameCount/frameAccumulator+.5)
  frameCount=0;frameAccumulator=0
 end
 hudElapsed=hudElapsed+dt
 if hudElapsed<.55 then return end
 hudElapsed=0
 if state.hud then
  local chunks={"EVVO HUB"}
  if state.fps then table.insert(chunks,tostring(framesPerSecond).." FPS") end
  if state.ping then
   local ok,v=pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString() end)
   if ok and v then table.insert(chunks,tostring(v)) end
  end
  if state.playerCount then table.insert(chunks,tostring(#Players:GetPlayers()).." players") end
  if state.showClock then table.insert(chunks,tostring(math.floor(os.clock()-started)).."s") end
  if state.coords then
   local root=safeRoot(player)
   if root then
    local p=root.Position
    table.insert(chunks,string.format("XYZ %.0f / %.0f / %.0f",p.X,p.Y,p.Z))
   end
  end
  local seat=mySeat()
  if state.vehicleHUD and seat then
   table.insert(chunks,string.format("VEHICLE %.0f studs/s",seat.AssemblyLinearVelocity.Magnitude))
  end
  statusText.Text=table.concat(chunks,"    •    ")
  statusPill.Visible=true
 else statusPill.Visible=false end
 if state.policeAlerts and os.clock()-lastAlert>8 then
  local me=safeRoot(player)
  if me then
   local closest,dist=nil,math.huge
   for _,p in ipairs(Players:GetPlayers()) do
    if p~=player and p.Team and p.Team.Name:lower():find("police",1,true) then
     local r=safeRoot(p)
     if r then
      local d=(r.Position-me.Position).Magnitude
      if d<dist then dist=d;closest=p end
     end
    end
   end
   if closest and dist<state.policeRange then
    lastAlert=os.clock()
    toast("Police nearby: "..closest.Name.." ("..math.floor(dist).." studs)")
   end
  end
 end
 if lastTheme~=state.theme then lastTheme=state.theme;refreshTheme();if currentPage=="Settings" then showPage("Settings") end end
 guiScale.Scale=math.clamp(tonumber(state.scale) or 1,.7,1.3)
end
local function updateMovement(dt)
 physicsElapsed=physicsElapsed+dt
 if physicsElapsed>=.25 then
  physicsElapsed=0
  local hum=myHumanoid()
  if hum and hum.Health>0 then
   if not originals[hum] then
    originals[hum]={walk=hum.WalkSpeed,jump=hum.JumpPower,usePower=hum.UseJumpPower}
   end
   local base=originals[hum]
   if state.speed or state.sprint then
    local w=state.speed and state.speedValue or base.walk
    local boosted=state.sprint and UIS:IsKeyDown(Enum.KeyCode.LeftShift)
    hum.WalkSpeed=w*(boosted and state.sprintMult or 1)
   elseif math.abs(hum.WalkSpeed-base.walk)>.001 then hum.WalkSpeed=base.walk end
   if state.jump then
    hum.UseJumpPower=true
    hum.JumpPower=state.jumpValue
   elseif hum.JumpPower~=base.jump then
    hum.JumpPower=base.jump
    hum.UseJumpPower=base.usePower
   end
   if state.autoJump and hum.FloorMaterial~=Enum.Material.Air and os.clock()-autoJumpAt>=state.autoJumpSeconds then
    autoJumpAt=os.clock()
    hum.Jump=true
   end
  end
  if state.gravity then Workspace.Gravity=state.gravityValue
  elseif Workspace.Gravity==state.gravityValue then Workspace.Gravity=originalGravity end
 end
 if state.fly then updateFly() elseif flyVelocity then stopFly() end
 if state.noclip then setNoclip() elseif next(noClipParts) then setNoclip() end
end
connect(RunService.Heartbeat,function(dt)
 updateHud(dt)
 updateMovement(dt)
 worldElapsed=worldElapsed+dt
 if worldElapsed>=2 then
  worldElapsed=0
  if state.worldESP then
   if os.clock()-lastWorldScan>12 then scanWorld() end
  elseif next(worldHighlights) then clearWorld() end
 end
end)
local overlayElapsed=0
connect(RunService.RenderStepped,function(dt)
 local cam=Workspace.CurrentCamera
 if not cam then return end
 local viewport=cam.ViewportSize
 fovFrame.Visible=state.aimShowFOV and not state.lowFX
 fovFrame.Size=UDim2.fromOffset(state.aimFOV*2,state.aimFOV*2)
 fovFrame.Position=UDim2.fromOffset(viewport.X/2,viewport.Y/2)
 crosshairH.Visible=state.crosshair
 crosshairV.Visible=state.crosshair
 crosshairH.Position=UDim2.fromOffset(viewport.X/2,viewport.Y/2)
 crosshairV.Position=UDim2.fromOffset(viewport.X/2,viewport.Y/2)
 crosshairH.Size=UDim2.fromOffset(state.crosshairSize*2,2)
 crosshairV.Size=UDim2.fromOffset(2,state.crosshairSize*2)
 if state.aim and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
  local target=findAimTarget()
  if target then
   local pos=target.Position + target.AssemblyLinearVelocity*state.aimPrediction
   cam.CFrame=cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position,pos),math.clamp(state.aimSmooth,0,1))
  end
 end
 overlayElapsed=overlayElapsed+dt
 if overlayElapsed>=1/math.max(3,state.espHz) then
  overlayElapsed=0
  updateESP()
  updateRadar()
  updateVehicleESP()
 end
end)

-- Restore all modified state and disconnect all owned events on shutdown.
local function cleanup()
 if not alive then return end
 alive=false
 pcall(saveSettings)
 stopFly()
 pcall(stopSpectate)
 pcall(clearWorld)
 for part,was in pairs(noClipParts) do
  if part and part.Parent then pcall(function() part.CanCollide=was end) end
 end
 noClipParts={}
 pcall(restoreHumanoid)
 if state.gravity then pcall(function() Workspace.Gravity=originalGravity end) end
 for p in pairs(visuals) do clearVisual(p) end
 for p,d in pairs(radarDots) do pcall(function() d:Destroy() end);radarDots[p]=nil end
 for m,hi in pairs(vehicleHighlights) do pcall(function() hi:Destroy() end);vehicleHighlights[m]=nil end
 for _,obj in ipairs(waypointObjects) do pcall(function() obj:Destroy() end) end
 for _,c in ipairs(pageConnections) do pcall(function() c:Disconnect() end) end
 for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
 if gui and gui.Parent then gui:Destroy() end
 if env.EVVO_HUB_CLEANUP==cleanup then env.EVVO_HUB_CLEANUP=nil end
 print("[EVVO HUB] All local modules stopped; GUI closed.")
end
env.EVVO_HUB_CLEANUP=cleanup
connect(closeButton.MouseButton1Click,cleanup)

-- Startup is intentionally GUI-first; remote metadata is fetched only in a protected task.
protected(function()
 rebuildWaypointMarkers()
 showPage("Home")
 refreshTheme()
 print("[EVVO HUB] v"..VERSION.." ONLINE // OWNED BY EVVO")
 print("[EVVO HUB] Catalog:",#catalog,"names;",#categoryNames-1,"categories")
 print("[EVVO HUB] PlayerGui:",gui:GetFullName())
 toast("EVVO HUB ONLINE // "..#catalog.." games indexed")
end)
task.spawn(function()
 local ok, info=pcall(function()
  return MarketplaceService:GetProductInfo(game.PlaceId)
 end)
 if ok and type(info)=="table" and type(info.Name)=="string" then
  currentGameName=info.Name
  local bound=state.bindings[tostring(game.PlaceId)] or state.bindings["u:"..tostring(game.GameId)]
  if not bound and catalogIndex[info.Name:lower()] then gameLookup=info.Name end
  if alive and currentPage=="Home" then showPage("Home") end
 end
end)
