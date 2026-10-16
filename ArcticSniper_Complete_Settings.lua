--[[
ARCTIC SNIPER — COMPLETE SETTINGS BUILD
UI build with announcement-text parsing, configurable piece buffer, status cards, and demo-only redeem preview.
Does not read live game events, redeem codes, or send Discord messages.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
if not player then return end
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("ArcticSniperV2")
if old then old:Destroy() end

-- FROST PALETTE ONLY: layout and component sizing are preserved.
local C = {
 BG=Color3.fromRGB(5,10,18), PANEL=Color3.fromRGB(11,20,32),
 ROW=Color3.fromRGB(17,32,48), HOVER=Color3.fromRGB(25,46,65),
 RED=Color3.fromRGB(105,205,255), DARK=Color3.fromRGB(31,91,128),
 PINK=Color3.fromRGB(190,237,255), WHITE=Color3.fromRGB(242,250,255),
 MUTED=Color3.fromRGB(139,170,192), GREEN=Color3.fromRGB(126,238,205),
 BORDER=Color3.fromRGB(55,108,139)
}
local logs, pages, nav = {}, {}, {}
local prefs = {scan=true, spam=false, feed=false, notifications=true, auto=3}
local codePieces = {}
local lastPieceAt = 0
local IDLE_RESET_SECONDS = 4

local function make(class, props, parent)
 local o=Instance.new(class)
 for k,v in pairs(props or {}) do o[k]=v end
 o.Parent=parent
 return o
end
local function corner(o,r) make("UICorner",{CornerRadius=UDim.new(0,r or 9)},o) end
local function stroke(o,c,t) make("UIStroke",{Color=c or C.BORDER,Thickness=t or 1,Transparency=0.15},o) end
local function label(parent,txt,size,pos,fs,color,center)
 return make("TextLabel",{BackgroundTransparency=1,Text=txt or "",Size=size,Position=pos,
  Font=Enum.Font.Gotham,TextSize=fs or 11,TextColor3=color or C.WHITE,
  TextXAlignment=center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
  TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true},parent)
end
local function button(parent,txt,size,pos,fn,bg)
 local b=make("TextButton",{Size=size,Position=pos,BackgroundColor3=bg or C.ROW,
  BorderSizePixel=0,Text=txt,TextColor3=C.WHITE,TextSize=11,
  Font=Enum.Font.GothamSemibold,AutoButtonColor=false},parent)
 corner(b,8); stroke(b)
 b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=C.HOVER}):Play() end)
 b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=bg or C.ROW}):Play() end)
 b.Activated:Connect(function() if fn then fn() end end)
 return b
end
local function textbox(parent,placeholder,size,pos)
 local b=make("TextBox",{Size=size,Position=pos,BackgroundColor3=C.BG,BorderSizePixel=0,
  Text="",PlaceholderText=placeholder,PlaceholderColor3=C.MUTED,TextColor3=C.WHITE,
  TextSize=12,Font=Enum.Font.Gotham,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left},parent)
 corner(b,8); stroke(b)
 make("UIPadding",{PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,7)},b)
 return b
end

local gui=make("ScreenGui",{Name="ArcticSniperV2",ResetOnSpawn=false,IgnoreGuiInset=true,
 DisplayOrder=999,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
local main=make("Frame",{Name="Main",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
 Size=UDim2.fromOffset(580,470),BackgroundColor3=C.BG,BorderSizePixel=0,Active=true},gui)
corner(main,15); stroke(main,C.BORDER,1.3)
local scale=make("UIScale",{Scale=1},main)
local function resize()
 local cam=workspace.CurrentCamera
 if cam then local v=cam.ViewportSize; scale.Scale=math.clamp(math.min((v.X-20)/580,(v.Y-24)/470,1),.5,1) end
end
resize()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end

local header=make("Frame",{Name="Header",Size=UDim2.new(1,0,0,62),BackgroundColor3=C.PANEL,
 BorderSizePixel=0,Active=true},main)
corner(header,15)
make("Frame",{Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,1,-16),BackgroundColor3=C.PANEL,BorderSizePixel=0},header)
local logo=make("Frame",{Size=UDim2.fromOffset(36,36),Position=UDim2.fromOffset(13,12),BackgroundColor3=C.DARK,BorderSizePixel=0},header)
corner(logo,10); stroke(logo,C.RED)
label(logo,"A",UDim2.fromScale(1,1),UDim2.new(),19,C.PINK,true)
label(header,"ARCTIC SNIPER",UDim2.new(0,190,0,22),UDim2.fromOffset(59,8),15,C.WHITE)
label(header,"V2  /  FROST EDITION",UDim2.new(0,190,0,16),UDim2.fromOffset(60,30),9,C.MUTED)
local dot=make("Frame",{Size=UDim2.fromOffset(7,7),Position=UDim2.new(1,-177,0,27),BackgroundColor3=C.GREEN,BorderSizePixel=0},header)
corner(dot,9)
label(header,"DEMO MODE",UDim2.fromOffset(70,18),UDim2.new(1,-165,0,21),9,C.MUTED)
local mini
button(header,"—",UDim2.fromOffset(29,28),UDim2.new(1,-69,0,17),function() main.Visible=false; if mini then mini.Visible=true end end,C.ROW)
local close=button(header,"×",UDim2.fromOffset(29,28),UDim2.new(1,-35,0,17),function() gui:Destroy() end,C.DARK)
close.TextSize=17; close.TextColor3=C.PINK

-- Drag the header with a finger on mobile; mouse dragging is also supported.
do
 local dragging=false; local startPoint; local startPos; local kind
 header.InputBegan:Connect(function(i)
  if i.UserInputType==Enum.UserInputType.Touch then
   dragging=true; kind="touch"; startPoint=i.Position; startPos=main.Position
  elseif i.UserInputType==Enum.UserInputType.MouseButton1 then
   dragging=true; kind="mouse"; startPoint=i.Position; startPos=main.Position
  end
 end)
 UIS.InputChanged:Connect(function(i)
  if not dragging then return end
  local moved=(kind=="touch" and i.UserInputType==Enum.UserInputType.Touch)
   or (kind=="mouse" and i.UserInputType==Enum.UserInputType.MouseMovement)
  if moved then
   local d=i.Position-startPoint
   main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
  end
 end)
 UIS.InputEnded:Connect(function(i)
  if (kind=="touch" and i.UserInputType==Enum.UserInputType.Touch)
   or (kind=="mouse" and i.UserInputType==Enum.UserInputType.MouseButton1) then dragging=false; kind=nil end
 end)
end
mini=button(gui,"❄  AS",UDim2.fromOffset(76,38),UDim2.new(0,14,.5,-19),function() main.Visible=true; mini.Visible=false end,C.PANEL)
mini.Visible=false; stroke(mini,C.RED)

local sidebar=make("Frame",{Name="Sidebar",Size=UDim2.new(0,124,1,-74),Position=UDim2.fromOffset(9,67),
 BackgroundColor3=C.PANEL,BorderSizePixel=0},main)
corner(sidebar,11)
label(sidebar,"NAVIGATION",UDim2.new(1,-18,0,22),UDim2.fromOffset(10,7),8,C.MUTED)
local content=make("Frame",{Name="Content",Size=UDim2.new(1,-149,1,-74),Position=UDim2.fromOffset(137,67),BackgroundTransparency=1},main)
local names={"Home","Scanner","Redeemer","Brainrots","Discord","Settings","Activity Log"}

local function log(msg)
 table.insert(logs,1,os.date("%H:%M:%S").." • "..msg)
 if #logs>60 then table.remove(logs) end
 local p=pages["Activity Log"]; local list=p and p:FindFirstChild("LogList")
 if list then
  for _,ch in ipairs(list:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
  for i=1,math.min(#logs,14) do label(list,logs[i],UDim2.new(1,-12,0,23),UDim2.fromOffset(6,(i-1)*26),9,C.MUTED) end
  list.CanvasSize=UDim2.new(0,0,0,math.min(#logs,14)*26)
 end
end
local function page(name)
 local p=make("ScrollingFrame",{Name=name.."Page",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
  BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.RED,CanvasSize=UDim2.new(),
  AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false},content)
 make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},p)
 make("UIPadding",{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,5)},p)
 pages[name]=p; return p
end
local function card(parent,title,desc,h)
 local f=make("Frame",{Size=UDim2.new(1,-3,0,h or 78),BackgroundColor3=C.PANEL,BorderSizePixel=0},parent)
 corner(f,10); stroke(f)
 label(f,title,UDim2.new(1,-20,0,21),UDim2.fromOffset(10,6),11,C.WHITE)
 if desc then label(f,desc,UDim2.new(1,-20,0,h-34),UDim2.fromOffset(10,28),9,C.MUTED) end
 return f
end
local function toggle(parent,title,sub,initial,fn)
 local r=make("Frame",{Size=UDim2.new(1,-3,0,48),BackgroundColor3=C.ROW,BorderSizePixel=0},parent)
 corner(r,9); stroke(r)
 label(r,title,UDim2.new(1,-82,0,19),UDim2.fromOffset(10,5),10,C.WHITE)
 if sub then label(r,sub,UDim2.new(1,-82,0,14),UDim2.fromOffset(10,25),8,C.MUTED) end
 local on=initial==true
 local track=make("TextButton",{Size=UDim2.fromOffset(43,23),Position=UDim2.new(1,-53,.5,-11),
  BackgroundColor3=on and C.RED or C.PANEL,BorderSizePixel=0,Text="",AutoButtonColor=false},r)
 corner(track,20)
 local knob=make("Frame",{Size=UDim2.fromOffset(15,15),Position=on and UDim2.new(1,-19,.5,-7) or UDim2.fromOffset(4,4),
  BackgroundColor3=C.WHITE,BorderSizePixel=0},track); corner(knob,10)
 track.Activated:Connect(function()
  on=not on; track.BackgroundColor3=on and C.RED or C.PANEL
  TweenService:Create(knob,TweenInfo.new(.12),{Position=on and UDim2.new(1,-19,.5,-7) or UDim2.fromOffset(4,4)}):Play()
  if fn then fn(on) end
 end)
 return r
end
local function stepper(parent,title,sub,values,index,fn)
 local r=make("Frame",{Size=UDim2.new(1,-3,0,49),BackgroundColor3=C.ROW,BorderSizePixel=0},parent)
 corner(r,9); stroke(r)
 label(r,title,UDim2.new(.44,0,0,18),UDim2.fromOffset(10,5),10,C.WHITE)
 if sub then label(r,sub,UDim2.new(.44,0,0,13),UDim2.fromOffset(10,25),8,C.MUTED) end
 index=math.clamp(index or 1,1,#values)
 local controls=make("Frame",{Size=UDim2.new(.52,-4,0,29),Position=UDim2.new(.47,0,.5,-14),BackgroundColor3=C.PANEL,BorderSizePixel=0},r)
 corner(controls,7)
 local value=label(controls,tostring(values[index]),UDim2.new(1,-54,1,0),UDim2.fromOffset(27,0),10,C.WHITE,true)
 local function set(i) index=math.clamp(i,1,#values); value.Text=tostring(values[index]); if fn then fn(values[index]) end end
 button(controls,"−",UDim2.fromOffset(23,23),UDim2.fromOffset(3,3),function() set(index-1) end,C.DARK)
 button(controls,"+",UDim2.fromOffset(23,23),UDim2.new(1,-26,0,3),function() set(index+1) end,C.RED)
end
local function show(name)
 for n,p in pairs(pages) do p.Visible=n==name end
 for n,b in pairs(nav) do b.BackgroundColor3=n==name and C.DARK or C.PANEL; b.TextColor3=n==name and C.PINK or C.MUTED end
end
for i,n in ipairs(names) do
 local b=button(sidebar,n,UDim2.new(1,-12,0,32),UDim2.fromOffset(6,34+(i-1)*36),function() show(n) end,C.PANEL)
 b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="  "..n; b.TextSize=9; b.TextColor3=C.MUTED; nav[n]=b
end
label(sidebar,"ARCTIC • V2",UDim2.new(1,-16,0,18),UDim2.new(0,8,1,-26),8,C.MUTED)

do
 local p=page("Home")
 local w=card(p,"WELCOME TO ARCTIC","Compact mobile UI • icy blue theme.",83)
 label(w,"●  SYSTEM READY",UDim2.new(1,-20,0,16),UDim2.new(0,10,1,-21),9,C.GREEN)
 local s=card(p,"QUICK STATUS",nil,66)
 label(s,"Scanner: DEMO",UDim2.new(.5,-10,0,20),UDim2.fromOffset(10,30),9,C.PINK)
 label(s,"Feed: TEST MODE",UDim2.new(.5,-10,0,20),UDim2.new(.5,0,0,30),9,C.PINK)
 local q=card(p,"QUICK OPEN",nil,63)
 button(q,"SCANNER",UDim2.new(.48,-4,0,26),UDim2.fromOffset(9,30),function() show("Scanner") end,C.DARK)
 button(q,"SPAWN FEED",UDim2.new(.48,-4,0,26),UDim2.new(.52,0,0,30),function() show("Brainrots") end,C.DARK)
 card(p,"ABOUT","Arctic Sniper • code-piece buffer and settings demo. Live game access is not included.",59)
end
do
 local p=page("Scanner"); card(p,"ANNOUNCEMENT SCANNER","Paste announcement text from a source you are authorized to access; code phrases are parsed locally.",67)
 local box=textbox(p,"Paste announcement text...",UDim2.new(1,-3,0,38),UDim2.new()); box.LayoutOrder=2
 local r=card(p,"SCAN RESULT",nil,74); r.LayoutOrder=3
 local status=label(r,"Waiting for a test scan.",UDim2.new(1,-18,0,20),UDim2.fromOffset(9,27),9,C.MUTED)
 button(r,"PROCESS TEXT",UDim2.fromOffset(104,25),UDim2.new(1,-114,1,-31),function()
  local raw=box.Text
  if raw=="" then status.Text="Paste announcement text first."; status.TextColor3=C.PINK; log("Scanner input empty"); return end
  if not prefs.scan then status.Text="Turn Scan announcements ON first."; status.TextColor3=C.PINK; return end
  local piece=extractPiece(raw)
  if not piece then status.Text="No supported code phrase found."; status.TextColor3=C.MUTED; log("No code piece found in supplied text"); return end
  local now=os.clock()
  if now-lastPieceAt>IDLE_RESET_SECONDS then table.clear(codePieces) end
  lastPieceAt=now
  if prefs.spam then
   table.insert(codePieces,piece)
   status.Text="SPAMMING • piece detected: "..piece
   piecesStatus.Text="SPAMMING • piece queued for preview: "..piece
   log("Spam mode detected piece (no redemption sent)")
  else
   table.insert(codePieces,piece)
   status.Text="Target locked • piece detected: "..piece
   piecesStatus.Text="TARGET LOCKED • collecting pieces"
   log("Code piece added to local buffer")
  end
  piecesValue.Text="Pieces: "..#codePieces.." / "..prefs.auto
  if #codePieces>=prefs.auto then
   piecesStatus.Text="SNIPED CODE • threshold reached (preview only)"
   piecesStatus.TextColor3=C.GREEN
   log("Auto-submit threshold reached; no code was redeemed")
   table.clear(codePieces); piecesValue.Text="Pieces: 0 / "..prefs.auto
  end
 end,C.RED)
 toggle(p,"Scan announcements","Processes text entered below",prefs.scan,function(v) prefs.scan=v; log("Scan preference "..(v and "enabled" or "disabled")) end)
 local piecesCard=card(p,"CODE PIECES • TARGET LOCK",nil,100); piecesCard.LayoutOrder=4
 local piecesStatus=label(piecesCard,"Waiting for announcement text.",UDim2.new(1,-18,0,22),UDim2.fromOffset(9,29),9,C.MUTED)
 local piecesValue=label(piecesCard,"Pieces: 0 / "..prefs.auto,UDim2.new(1,-18,0,18),UDim2.fromOffset(9,53),9,C.PINK)
 local function clearPieces(reason)
  table.clear(codePieces); piecesValue.Text="Pieces: 0 / "..prefs.auto
  piecesStatus.Text=reason or "Buffer cleared."; piecesStatus.TextColor3=C.MUTED
 end
 local function extractPiece(text)
  local low=string.lower(text)
  local piece=string.match(text,"[Cc][Oo][Dd][Ee]%s*[:=]%s*([%w_%-]+)")
  if not piece and (string.find(low,"use code",1,true) or string.find(low,"the code is",1,true)) then
   piece=string.match(text,"[Uu][Ss][Ee]%s+[Cc][Oo][Dd][Ee]%s+([%w_%-]+)") or string.match(text,"[Tt][Hh][Ee]%s+[Cc][Oo][Dd][Ee]%s+[Ii][Ss]%s+([%w_%-]+)")
  end
  return piece
 end
 button(piecesCard,"CLEAR BOX",UDim2.fromOffset(82,24),UDim2.new(1,-91,1,-31),function() box.Text=""; clearPieces("Input and buffer cleared."); log("Code piece buffer cleared") end,C.DARK)
 -- The scanner processes only text explicitly supplied by the user. It does not read game UI.
 local originalTest = nil

end
do
 local p=page("Redeemer"); card(p,"CODE PREVIEW","Checks text format only; does not redeem anything.",67)
 local box=textbox(p,"Enter a code...",UDim2.new(1,-3,0,38),UDim2.new()); box.LayoutOrder=2
 local r=card(p,"RESULT",nil,74); r.LayoutOrder=3
 local status=label(r,"No code checked yet.",UDim2.new(1,-18,0,20),UDim2.fromOffset(9,27),9,C.MUTED)
 button(r,"CHECK",UDim2.fromOffset(72,25),UDim2.new(1,-82,1,-31),function()
  local v=string.gsub(box.Text,"^%s*(.-)%s*$","%1")
  if v=="" then status.Text="Enter a code first."; status.TextColor3=C.PINK
  elseif #v>64 then status.Text="Code is too long."; status.TextColor3=C.PINK
  elseif string.find(v,"%s") then status.Text="Code contains spaces."; status.TextColor3=C.PINK
  else status.Text="Format looks valid: "..v; status.TextColor3=C.GREEN end
  log("Code format preview checked")
 end,C.RED)
 toggle(p,"Spam redeem","Immediate piece-detection preview; no redeem call",prefs.spam,function(v) prefs.spam=v; piecesStatus.Text=v and "SPAMMING • preview mode" or "Normal scan mode"; log("Spam redeem preference changed") end)
 stepper(p,"Auto-submit value","Piece threshold (1–5)",{1,2,3,4,5},3,function(v) prefs.auto=v; piecesValue.Text="Pieces: "..#codePieces.." / "..prefs.auto; log("Auto-submit threshold set to "..v) end)
end
do
 local p=page("Brainrots"); card(p,"SPAWN FEED","Tap to create a sample notification.",67)
 local r=card(p,"LATEST EVENT",nil,83)
 local status=label(r,"Waiting for a test event.",UDim2.new(1,-18,0,20),UDim2.fromOffset(9,27),9,C.MUTED)
 button(r,"TEST SPAWN",UDim2.fromOffset(100,25),UDim2.new(1,-110,1,-31),function() status.Text="TEST • Sample Brainrot appeared"; status.TextColor3=C.GREEN; log("Sample spawn event created") end,C.RED)
 toggle(p,"Spawn notifications","Demo preference only",prefs.feed,function(v) prefs.feed=v; log("Spawn feed preference changed") end)
 card(p,"LIVE DETECTION","This UI does not inspect live game internals.",57)
end
do
 local p=page("Discord"); card(p,"MESSAGE PREVIEW","Preview text for your own authorized bot/backend.",67)
 local box=textbox(p,"Type sample notification...",UDim2.new(1,-3,0,38),UDim2.new()); box.LayoutOrder=2
 local r=card(p,"PREVIEW",nil,88); r.LayoutOrder=3
 local status=label(r,"No message created.",UDim2.new(1,-18,0,30),UDim2.fromOffset(9,27),9,C.MUTED)
 button(r,"PREVIEW",UDim2.fromOffset(78,25),UDim2.new(1,-88,1,-31),function()
  status.Text="❄ ARCTIC SNIPER • "..(box.Text~="" and box.Text or "Sample notification")
  status.TextColor3=C.PINK; log("Message preview created")
 end,C.RED)
 card(p,"CONNECTION","Preview only; no Discord message or webhook is sent.",57)
end
do
 local p=page("Settings"); card(p,"PERSONALIZATION","Settings for this interface session.",61)
 toggle(p,"Notifications","UI preference only",prefs.notifications,function(v) prefs.notifications=v; log("Notification preference changed") end)
 stepper(p,"Panel scale","Display setting",{70,80,90,100},4,function(v) scale.Scale=math.min(v/100,1); log("Panel scale set to "..v.."%") end)
 card(p,"WINDOW CONTROLS","Drag the top bar to move the panel. Minimize to show the AS reopen button.",65)
end
do
 local p=page("Activity Log")
 local f=card(p,"ACTIVITY LOG",nil,330)
 local list=make("ScrollingFrame",{Name="LogList",Size=UDim2.new(1,-18,1,-70),Position=UDim2.fromOffset(9,30),
  BackgroundColor3=C.BG,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.RED,CanvasSize=UDim2.new()},f)
 corner(list,8)
 button(f,"CLEAR LOG",UDim2.fromOffset(86,25),UDim2.new(1,-96,1,-31),function()
  table.clear(logs); for _,ch in ipairs(list:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end; list.CanvasSize=UDim2.new()
 end,C.DARK)
end

task.spawn(function()
 while gui.Parent do
  local flake=make("TextLabel",{BackgroundTransparency=1,Text="✦",TextColor3=C.PINK,TextTransparency=.65,
   TextSize=math.random(8,14),Font=Enum.Font.Gotham,Size=UDim2.fromOffset(18,18),
   Position=UDim2.new(math.random(5,95)/100,0,-.05,0),ZIndex=10},main)
  local tw=TweenService:Create(flake,TweenInfo.new(math.random(5,8),Enum.EasingStyle.Linear),{
   Position=UDim2.new(flake.Position.X.Scale+math.random(-6,6)/100,0,1.08,0),TextTransparency=1})
  tw:Play(); tw.Completed:Connect(function() if flake.Parent then flake:Destroy() end end)
  task.wait(.4)
 end
end)
log("Arctic Sniper V2 UI loaded")
show("Home")
