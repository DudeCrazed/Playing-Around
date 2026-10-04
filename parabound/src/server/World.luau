-- Original pixel diorama stages. Collision lives only on the deck and jump shelves.
local Lighting = game:GetService('Lighting')
local World = {}
local arenas = {}
local worldFolder
local rgb = Color3.fromRGB

local function block(parent, name, size, position, color, collidable)
 local p = Instance.new('Part')
 p.Name = name; p.Size = size; p.CFrame = CFrame.new(position); p.Color = color
 p.Material = Enum.Material.SmoothPlastic; p.Anchored = true
 p.CanCollide = collidable == true; p.CanQuery = collidable == true; p.CanTouch = collidable == true
 p.CastShadow = false; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
 p.Parent = parent
 return p
end
local function tile(parent, name, x, y, z, w, h, d, color)
 return block(parent, name, Vector3.new(w,h,d), Vector3.new(x,y,z), color)
end
local function cloud(m,c,x,y,z)
 for i,shape in ipairs({{0,0,11,3},{-7,-1,7,2},{6,1,8,3},{2,3,6,3}}) do
  tile(m,'Cloud tile '..i,c.X+x+shape[1],y+shape[2],c.Z+z,shape[3],shape[4],1,rgb(238,236,217))
 end
end
local function hills(m,c,palette)
 -- Three depths of stepped terrain provide parallax without any foreground scenery.
 for layer=1,3 do
  for i=1,9 do
   local height=8+((i*7+layer*9)%19)
   local x=c.X-80+(i-1)*20
   tile(m,'Ridge layer '..layer,x,height/2-4,c.Z-95+layer*17,22,height,3,palette[layer])
   if i%2==0 then tile(m,'Ridge step '..layer,x+3,height-2,c.Z-95+layer*17,14,4,3,palette[layer]) end
  end
 end
 cloud(m,c,-44,39,-82); cloud(m,c,46,45,-91)
end
local function tree(m,c,x,z,height,leaf,trunk)
 tile(m,'Tree trunk',c.X+x,height/2,c.Z+z,2,height,2,trunk)
 tile(m,'Tree bough',c.X+x-3,height-4,c.Z+z,8,2,2,trunk)
 tile(m,'Tree bough',c.X+x+3,height-1,c.Z+z,8,2,2,trunk)
 for _,s in ipairs({{-4,height,11,5},{4,height+2,12,6},{0,height+6,14,6},{1,height+10,8,3}}) do
  tile(m,'Foliage tile',c.X+x+s[1],s[2],c.Z+z,s[3],s[4],3,leaf)
 end
 tile(m,'Sunlit foliage',c.X+x-2,height+8,c.Z+z+1.55,8,2,.1,leaf:Lerp(rgb(231,225,153),.25))
end
local function deck(m,c,width,grass,stone,earth)
 local main=block(m,'Main deck',Vector3.new(width,2,12),c+Vector3.new(0,-1,0),stone,true)
 main:SetAttribute('DropThrough',false)
 local count=math.ceil(width/4); local tw=width/count
 for i=1,count do
  local x=c.X-width/2+tw*(i-.5)
  tile(m,'Deck cap tile',x,-.15,c.Z+6.03,tw,.3,.12,grass)
  tile(m,'Stone face tile',x,-.8,c.Z+6.02,tw-.06,1,.12,i%3==0 and stone:Lerp(rgb(236,216,171),.15) or stone)
  local deep=2+(i%3)*.7
  tile(m,'Earth strata',x,-2-deep/2,c.Z+5.96,tw-.06,deep,.22,i%2==0 and earth or earth:Lerp(stone,.2))
  if i%3==0 then tile(m,'Stratum seam',x,-2.5,c.Z+6.09,tw-.1,.3,.08,stone:Lerp(earth,.5)) end
 end
 -- A continuous thin cap avoids physical seams in the combat lane.
 tile(m,'Deck top cap',c.X,-.05,c.Z,width,.1,12,grass)
end
local function shelf(m,c,x,y,width,cap,face)
 local p=block(m,'Jump platform',Vector3.new(width,.7,8),c+Vector3.new(x,y-.35,0),face,true)
 p:SetAttribute('DropThrough',true)
 tile(m,'Platform grass cap',c.X+x,y-.04,c.Z,width,.08,8,cap)
 for i=-1,1 do tile(m,'Platform face tile',c.X+x+i*width/3,y-.39,c.Z+4.02,width/3-.1,.5,.1,face:Lerp(cap,(i+1)*.06)) end
end
local function bell(m,c,x,z,scale)
 local wood=rgb(111,92,70); local cap=rgb(211,182,108); local bronze=rgb(189,140,78)
 for _,side in ipairs({-1,1}) do
  tile(m,'Bellcourt pier',c.X+x+side*7*scale,8*scale,c.Z+z,2*scale,16*scale,2,wood)
  tile(m,'Pier stone foot',c.X+x+side*7*scale,1,c.Z+z,4*scale,2,3,rgb(145,155,144))
 end
 tile(m,'Bellcourt lintel',c.X+x,16*scale,c.Z+z,18*scale,2*scale,3,cap)
 tile(m,'Bell hanger',c.X+x,13.5*scale,c.Z+z,1,3*scale,1,wood)
 tile(m,'Bell crown',c.X+x,12*scale,c.Z+z,3*scale,2*scale,2,bronze)
 tile(m,'Bell body',c.X+x,10.5*scale,c.Z+z,4*scale,2*scale,2,bronze)
 tile(m,'Bell lip',c.X+x,9.3*scale,c.Z+z,6*scale,.6*scale,2,cap)
 tile(m,'Bell clapper',c.X+x,8.5*scale,c.Z+z,.6,1.2,1,wood)
end
local function modePrompt(m,c,x,mode,text)
 local marker=tile(m,'ModePrompt',c.X+x,.25,c.Z,2,.5,2,rgb(186,173,115))
 local p=Instance.new('ProximityPrompt'); p.Name='ModePrompt'; p.ActionText=text; p.ObjectText=mode
 p.KeyboardKeyCode=Enum.KeyCode.C;p.GamepadKeyCode=Enum.KeyCode.ButtonR1;p.HoldDuration=.15; p.MaxActivationDistance=9; p.RequiresLineOfSight=false
 p:SetAttribute('Mode',mode); p:SetAttribute('Index',1); p.Parent=marker
end
local function register(kind,index,name,c,width,platformY,palette)
 local m=Instance.new('Model'); m.Name=kind..' '..index..' - '..name; m.Parent=worldFolder
 m:SetAttribute('Kind',kind); m:SetAttribute('Index',index); m:SetAttribute('LaneZ',c.Z)
 deck(m,c,width,palette.cap,palette.stone,palette.earth)
 shelf(m,c,-18,platformY,14,palette.cap,palette.stone)
 shelf(m,c,18,platformY,14,palette.cap,palette.stone)
 local entry={Model=m,Center=c,Spawn=c+Vector3.new(0,3.3,0),MinX=c.X-width/2,MaxX=c.X+width/2,
  FloorY=0,LaneZ=c.Z,Name=name,MapIndex=index,CameraY=8}
 arenas[kind..':'..index]=entry
 return entry
end
function World.Build()
 -- Destroy every owned folder, including duplicates left by previous Studio runs.
 for _,child in ipairs(workspace:GetChildren()) do
  if child.Name=='PARABOUNDWorld' or child:GetAttribute('PARABOUNDWorld')==true then child:Destroy() end
 end
 arenas={}; worldFolder=Instance.new('Folder'); worldFolder.Name='PARABOUNDWorld'
 worldFolder:SetAttribute('PARABOUNDWorld',true); worldFolder.Parent=workspace
 Lighting.ClockTime=15.8; Lighting.Brightness=2.2
 Lighting.Ambient=rgb(119,125,132); Lighting.OutdoorAmbient=rgb(143,150,159)
 Lighting.FogColor=rgb(192,213,219); Lighting.FogStart=500; Lighting.FogEnd=3000
 local atmosphere=Lighting:FindFirstChild('ParaboundAtmosphere') or Lighting:FindFirstChildOfClass('Atmosphere')
 if not atmosphere then atmosphere=Instance.new('Atmosphere'); atmosphere.Name='ParaboundAtmosphere'; atmosphere.Parent=Lighting end
 atmosphere.Name='ParaboundAtmosphere'; atmosphere.Density=.08; atmosphere.Offset=.15; atmosphere.Color=rgb(217,226,228)
 atmosphere.Decay=rgb(157,179,191); atmosphere.Glare=0; atmosphere.Haze=.35
 local bloom=Lighting:FindFirstChild('ParaboundBloom') or Instance.new('BloomEffect')
 bloom.Name='ParaboundBloom'; bloom.Intensity=.05; bloom.Size=12; bloom.Threshold=1.8; bloom.Parent=Lighting
 local correction=Lighting:FindFirstChild('ParaboundColor') or Instance.new('ColorCorrectionEffect')
 correction.Name='ParaboundColor'; correction.Brightness=.01; correction.Contrast=.03; correction.Saturation=.02
 correction.TintColor=rgb(255,249,237); correction.Parent=Lighting
 local green={cap=rgb(137,171,95),stone=rgb(151,157,144),earth=rgb(122,99,74)}
 local tutorial=register('Tutorial',1,'Stillpoint Courtyard',Vector3.zero,84,7,green)
 arenas['Hub:1']=tutorial; arenas['Training:1']=tutorial
 local tm=tutorial.Model; local tc=tutorial.Center
 hills(tm,tc,{rgb(184,209,190),rgb(151,186,156),rgb(113,151,113)})
 tree(tm,tc,-33,-24,14,rgb(146,181,107),rgb(127,100,72))
 tree(tm,tc,34,-28,18,rgb(122,165,104),rgb(127,100,72))
 bell(tm,tc,0,-31,.8)
 for _,x in ipairs({-24,-8,8,24}) do tile(tm,'Tutorial station',x,.08,4,2,.16,1,rgb(218,204,149)) end
 local court=register('Crucible',1,'Terrace Bellcourt',Vector3.new(0,0,400),84,8,green)
 hills(court.Model,court.Center,{rgb(181,208,196),rgb(152,185,161),rgb(113,155,120)})
 bell(court.Model,court.Center,0,-29,1.25)
 for _,x in ipairs({-38,38}) do
  tree(court.Model,court.Center,x,-23,14,rgb(166,185,107),rgb(124,101,77))
  for j=1,3 do tile(court.Model,'Terraced garden wall',x,-1+j*2,400-35-j*3,18-j*3,2,3,rgb(151+j*6,161+j*5,144+j*5)) end
 end
 local forest=register('Crucible',2,'Scarwood Crossing',Vector3.new(0,0,800),80,10,
  {cap=rgb(108,157,127),stone=rgb(136,151,145),earth=rgb(97,103,81)})
 hills(forest.Model,forest.Center,{rgb(179,207,215),rgb(135,181,181),rgb(92,144,143)})
 for i,x in ipairs({-46,-29,-8,17,39}) do
  tree(forest.Model,forest.Center,x,-26-(i%2)*9,12+(i%3)*4,
   i%2==0 and rgb(120,173,155) or rgb(147,185,142),rgb(116,104,87))
 end
 -- One broken aqueduct with open arches, entirely behind the lane.
 for _,x in ipairs({-28,0,28}) do
  tile(forest.Model,'Aqueduct pier',x,5,759,3,10,3,rgb(150,173,166))
  tile(forest.Model,'Aqueduct cap',x,10,759,12,2,3,rgb(187,197,176))
 end
 local forge=register('Crucible',3,'Emberforge Bridge',Vector3.new(0,0,1200),88,9,
  {cap=rgb(194,158,112),stone=rgb(153,137,121),earth=rgb(112,93,83)})
 hills(forge.Model,forge.Center,{rgb(221,204,178),rgb(202,177,147),rgb(174,150,127)})
 for i,x in ipairs({-37,-15,15,37}) do
  local h=15+(i%2)*6
  tile(forge.Model,'Brick forge stack',x,h/2,1169,7,h,4,rgb(152,111,84))
  tile(forge.Model,'Stack stone crown',x,h,1169,9,2,5,rgb(187,161,123))
  tile(forge.Model,'Furnace inset',x,3,1171.1,3,4,.2,rgb(222,142,71))
  tile(forge.Model,'Warm furnace center',x,2.7,1171.22,1.5,2.5,.1,rgb(250,194,104))
  for y=6,h-2,4 do tile(forge.Model,'Stack mortar line',x,y,1171.05,7,.2,.1,rgb(178,136,102)) end
 end
 tile(forge.Model,'Forge roof beam',0,12,1166,65,2,4,rgb(129,100,80))
 for _,x in ipairs({-30,30}) do tile(forge.Model,'Background bridge support',x,-6,1182,5,12,3,rgb(170,143,110)) end
 return worldFolder
end
function World.GetArena(kind,index)
 return arenas[tostring(kind)..':'..tostring(index or 1)]
end

-- An invisible physical carrier for client-rendered sprites. Position is the root position.
function World.CreateFighter(name,position,color,scale)
 scale=scale or 1; color=color or rgb(150,164,178)
 local m=Instance.new('Model'); m.Name=name
 local root=Instance.new('Part'); root.Name='HumanoidRootPart'; root.Size=Vector3.new(2,2,1)
 root.CFrame=CFrame.new(position); root.Transparency=1; root.Anchored=false; root.CanCollide=true
 root.CanQuery=true; root.CastShadow=false; root.Massless=false; root.Parent=m
 for _,s in ipairs({{'Torso',Vector3.new(2,2,1),Vector3.zero},{'Head',Vector3.new(1.5,1.5,1),Vector3.new(0,1.75,0)},
  {'Left Arm',Vector3.new(1,2,1),Vector3.new(-1.5,0,0)},{'Right Arm',Vector3.new(1,2,1),Vector3.new(1.5,0,0)},
  {'Left Leg',Vector3.new(1,2,1),Vector3.new(-.5,-2,0)},{'Right Leg',Vector3.new(1,2,1),Vector3.new(.5,-2,0)}}) do
  local p=Instance.new('Part'); p.Name=s[1]; p.Size=s[2]*scale; p.CFrame=root.CFrame*CFrame.new(s[3]*scale)
  p.Color=color; p.Transparency=1; p.Anchored=false; p.CanCollide=false; p.CanQuery=false
  p.CanTouch=false; p.Massless=true; p.CastShadow=false; p.Parent=m
  local joint=Instance.new('Motor6D'); joint.Name=s[1]=='Torso' and 'RootJoint' or s[1]..'Joint'
  joint.Part0=root; joint.Part1=p; joint.C0=CFrame.new(s[3]*scale); joint.Parent=root
 end
 local hum=Instance.new('Humanoid'); hum.Name='Humanoid'; hum.HipHeight=2; hum.AutoRotate=false
 hum.RequiresNeck=false; hum.BreakJointsOnDeath=false; hum.WalkSpeed=14; hum.MaxHealth=100; hum.Health=100
 hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None; hum.Parent=m
 m.PrimaryPart=root
 -- Network ownership can only be set after the model enters Workspace.
 local function ownServer()
  if m:IsDescendantOf(workspace) then
   pcall(function() root:SetNetworkOwner(nil) end)
  end
 end
 m.AncestryChanged:Connect(ownServer)
 ownServer()
 return m
end
return World
