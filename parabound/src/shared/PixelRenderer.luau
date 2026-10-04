-- Original pixel artwork, rendered locally over the unchanged physical fighter rigs.
-- No uploaded textures: each sprite is a small palette grid merged into rectangles.
local Players = game:GetService("Players")
local Content = require(script.Parent.Content)
local PixelRenderer = {}
PixelRenderer.__index = PixelRenderer
local P = .18
local TAU = math.pi * 2
local PALETTE = {
	o=Color3.fromRGB(37,50,65), h=Color3.fromRGB(64,61,65), H=Color3.fromRGB(99,82,74),
	s=Color3.fromRGB(224,161,111), S=Color3.fromRGB(249,201,147), e=Color3.fromRGB(244,248,224),
	b=Color3.fromRGB(53,94,137), B=Color3.fromRGB(79,138,177), c=Color3.fromRGB(104,219,214),
	g=Color3.fromRGB(187,142,78), G=Color3.fromRGB(238,199,116), d=Color3.fromRGB(48,64,88),
	D=Color3.fromRGB(74,92,115), k=Color3.fromRGB(70,58,56), K=Color3.fromRGB(116,87,65),
	m=Color3.fromRGB(166,190,202), M=Color3.fromRGB(228,246,241), w=Color3.fromRGB(255,247,205),
}
local ART = {
	head={"..ooooo..", ".ohHHHho.", "ohHHHHHho", "ohhSSSSo.", ".osSSoeSo", ".osSSSSSo", "..osSSoo.", "..oSsoo..", "...oo...."},
	body={"..ooooo..", ".occccCo.", "obBBBBBbo", "obBBGBBbo", "obBBGBBbo", "obBBBBBbo", "obBBBBBbo", "ogggGgggo", ".oddDddo.", "..ooooo.."},
	upperArm={"ooo", "obO", "obO", "obO", "obO", "obO", "ooo"},
	foreArm={"ooo", "oSo", "oSo", "oso", "ogo", "ooo"},
	thigh={"ooo", "oDo", "oDo", "oDo", "odo", "odo", "ooo"},
	shin={"ooo.", "odo.", "odo.", "oko.", "oKoo", "oKKO", "oooo"},
	cape={".oooo", "ocbbo", "obBbo", "obBbo", "obBbo", "obBbo", "obBbo", "obBbo", "obBbo", "obbo.", ".oo.."},
	scarf={"ooooooo", "occcccO", ".ooooo."},
}
-- Uppercase O/C intentionally use the same dark edge / bright scarf ink.
PALETTE.O = PALETTE.o
PALETTE.C = PALETTE.c
local WEAPONS = {
	Longblade={".o.", "oMo", "oMo", "oMo", "oMo", "oMo", "oMo", "oMo", "oMo", "oMo", "oMo", "oMo", "ogo", "GGG", ".g.", ".o."},
	TwinFangs={"..o.", ".oMo", "oMMo", "oMmo", "oMmo", "oMmo", ".ogo", "GGGG", "..go", "..oo"},
	Greatblade={".oo.", "oMMo", "oMMo", "oMmo", "oMmo", "oMmo", "oMmo", "oMmo", "oMmo", "oMmo", "oMmo", "oMmo", "oMmo", ".gg.", "GGGG", ".go.", ".go.", ".oo."},
	Spear={"..o..", ".oMo.", "oMMMo", ".oMo.", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..o.."},
	Gauntlets={".oooo.", "ogGGgo", "ogGGgo", "ogGGgo", ".oggo.", "..oo.."},
	ChainScythe={".oooooo.", "oMMMMMmo", "ooooMMmo", "...oMmo.", "...ogo..", "....g...", "....g...", "....g...", "....g...", "....g...", "....g...", "....g...", "....o..."},
	Arcstaff={".ooo.", "ocwco", "occco", ".ogo.", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..g..", "..o.."},
	Bowblade={"..oo.", ".oMgo", "oM.go", "oM..g", "oM..g", "oM..g", "oM..g", "oM..g", "oM..g", "oM.go", ".oMgo", "..oo."},
}

local function sprite(parent, name, rows, palette)
	local width, height = #rows[1], #rows
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(width*P,height*P,.025)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OriginalPixels"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(width,height)
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.AlwaysOnTop = false
	gui.Parent = part
	local rectangles, previous = {}, {}
	for y,row in ipairs(rows) do
		local current = {}
		local x=1
		while x<=width do
			local ink=row:sub(x,x)
			local finish=x
			while finish<width and row:sub(finish+1,finish+1)==ink do finish+=1 end
			if ink~="." and palette[ink] then
				local key=tostring(x)..":"..tostring(finish)..":"..ink
				local rect=previous[key]
				if rect then rect.h+=1 else
					rect={x=x-1,y=y-1,w=finish-x+1,h=1,color=palette[ink]}
					table.insert(rectangles,rect)
				end
				current[key]=rect
			end
			x=finish+1
		end
		previous=current
	end
	for _,rect in ipairs(rectangles) do
		local frame=Instance.new("Frame")
		frame.Name="Ink"
		frame.BorderSizePixel=0
		frame.BackgroundColor3=rect.color
		frame.Position=UDim2.fromOffset(rect.x,rect.y)
		frame.Size=UDim2.fromOffset(rect.w,rect.h)
		frame.Parent=gui
		rect.frame=frame
	end
	return {part=part,gui=gui,rectangles=rectangles,w=width,h=height}
end

local function mirror(sheet, facing)
	for _,r in ipairs(sheet.rectangles) do
		r.frame.Position=UDim2.fromOffset(facing==1 and r.x or sheet.w-r.x-r.w,r.y)
	end
end
local function tint(sheet, amount)
	for _,r in ipairs(sheet.rectangles) do r.frame.BackgroundColor3=r.color:Lerp(PALETTE.w,amount) end
end
local function attribute(rig, name, default)
	local value=rig.model:GetAttribute(name)
	if value==nil and rig.player then value=rig.player:GetAttribute(name) end
	if value==nil then return default end
	return value
end
local function hideOriginal(rig)
	for _,object in ipairs(rig.model:GetDescendants()) do
		if object:IsA("BasePart") then
			if rig.hidden[object]==nil then rig.hidden[object]=object.LocalTransparencyModifier end
			object.LocalTransparencyModifier=1
		elseif object:IsA("Decal") then
			if rig.hidden[object]==nil then rig.hidden[object]=object.Transparency end
			object.Transparency=1
		end
	end
end
local function dispose(rig)
	for object,value in pairs(rig.hidden) do
		if object.Parent then
			if object:IsA("BasePart") then object.LocalTransparencyModifier=value else object.Transparency=value end
		end
	end
	rig.folder:Destroy()
end

function PixelRenderer.new()
	local folder=Instance.new("Folder")
	folder.Name="PixelFighters"
	folder.Parent=workspace
	return setmetatable({folder=folder,rigs={},scan=0,destroyed=false},PixelRenderer)
end

function PixelRenderer:_create(model, player, root)
	local folder=Instance.new("Folder")
	folder.Name=model.Name.."_Pixels"
	folder.Parent=self.folder
	local colors=table.clone(PALETTE)
	if not player or (Players.LocalPlayer and player~=Players.LocalPlayer) then
		colors.b=Color3.fromRGB(115,52,84)
		colors.B=Color3.fromRGB(185,85,110)
		colors.c=Color3.fromRGB(241,164,133)
		colors.C=colors.c
	end
	local rig={model=model,player=player,root=root,folder=folder,hidden={},sheets={},colors=colors,
		phase=0,idle=0,lastPosition=root.Position,facing=0,pose={},lastHitStop=0,flash=0,trail={},visible=false}
	hideOriginal(rig)
	self.rigs[model]=rig
	return rig
end

function PixelRenderer:_build(rig)
	local folder,colors=rig.folder,rig.colors
	for _,id in ipairs({"cape","scarf","body","head"}) do rig.sheets[id]=sprite(folder,id,ART[id],colors) end
	for _,side in ipairs({"front","back"}) do
		rig.sheets[side.."UpperArm"]=sprite(folder,side.."UpperArm",ART.upperArm,colors)
		rig.sheets[side.."ForeArm"]=sprite(folder,side.."ForeArm",ART.foreArm,colors)
		rig.sheets[side.."Thigh"]=sprite(folder,side.."Thigh",ART.thigh,colors)
		rig.sheets[side.."Shin"]=sprite(folder,side.."Shin",ART.shin,colors)
	end
	rig.sheets.shadow=sprite(folder,"PixelGroundShadow",{"..oooooo..","oooooooooo","..oooooo.."},{o=Color3.fromRGB(38,46,64)})
	for _,r in ipairs(rig.sheets.shadow.rectangles) do r.frame.BackgroundTransparency=.62 end
	rig.trail={}
	for i=1,4 do
		local dot=sprite(folder,"BladeAfterimage"..i,{"cc","cc"},colors)
		dot.gui.Enabled=false
		table.insert(rig.trail,dot)
	end
	rig.built=true
end

local function poseFor(rig, dt, now)
	local root=rig.root
	local delta=root.Position-rig.lastPosition
	rig.lastPosition=root.Position
	local measured=math.abs(delta.X)<8 and delta.X/math.max(dt,.001) or 0
	local vx=math.abs(root.AssemblyLinearVelocity.X)>.1 and root.AssemblyLinearVelocity.X or measured
	local speed=math.clamp(math.abs(vx),0,42)
	if speed<.4 then speed=0 end
	local stopped=attribute(rig,"HitStopUntil",0)>now
	if not stopped then
		rig.phase+=(speed/P)*dt*(TAU/32)
		rig.idle+=dt
	end
	local weight=math.clamp(speed/13,0,1)
	local gait=math.sin(rig.phase)
	local p={lean=.012*math.sin(rig.idle*1.8),bob=.10*math.sin(rig.idle*1.8),
		frontThigh=.62*gait*weight,backThigh=-.62*gait*weight,
		frontShin=.62*gait*weight+math.max(0,-gait)*.8*weight,
		backShin=-.62*gait*weight+math.max(0,gait)*.8*weight,
		frontUpper=.12-.28*gait*weight,frontFore=1.03-.20*gait*weight,
		backUpper=.1+.5*gait*weight,backFore=.25+.4*gait*weight,
		blade=-.95,head=.015*math.sin(rig.idle*2.5),cape=.1+.12*weight}
	if weight>.05 then p.lean=.09*weight; p.bob=math.abs(math.cos(rig.phase))*.45*weight end
	local airborneAttribute=attribute(rig,"Airborne",nil)
	local airborne=airborneAttribute==true
	local hum=rig.model:FindFirstChildOfClass("Humanoid")
	if airborneAttribute==nil and hum and hum.FloorMaterial==Enum.Material.Air then airborne=true end
	if airborne then
		local rising=root.AssemblyLinearVelocity.Y>1
		p.bob=0;p.lean=rising and -.12 or .12
		p.frontThigh=rising and -.8 or -.4;p.frontShin=.6
		p.backThigh=.5;p.backShin=1.25
		p.backUpper=-.6;p.backFore=-.85;p.frontUpper=.2;p.frontFore=.8
		if attribute(rig,"JumpCount",1)>=2 and rising then
			p.frontThigh=-1.15;p.frontShin=.65;p.backThigh=.8;p.backShin=1.6;p.lean=-.24
		end
	end
	local attackUntil=attribute(rig,"AttackUntil",attribute(rig,"ActionEnd",0))
	local state=attribute(rig,"AttackState",attribute(rig,"ActionState",""))
	local localEnd=attribute(rig,"LocalActionUntil",0)
	if localEnd>now then state=attribute(rig,"LocalActionState",state);attackUntil=localEnd end
	local attacking=attackUntil>now and (state=="Light" or state=="Heavy" or state=="Attack" or state=="light" or state=="heavy" or state=="Arcana1")
	local striking=false
	if attacking then
		local started=attribute(rig,"AttackStarted",attribute(rig,"ActionStart",now))
		if localEnd>now then started=attribute(rig,"LocalActionStart",started) end
		local hit=attribute(rig,"AttackHitAt",started+(Content.Weapons[rig.weapon] or Content.Weapons.Longblade).Startup)
		local heavy=state=="Heavy" or state=="heavy"
		if now<hit then
			local pull=math.clamp((now-started)/math.max(.05,hit-started),0,1)
			p.frontUpper=-1.9-pull*.45;p.frontFore=-2.35;p.blade=.65
			p.backUpper=-.5;p.backFore=-1.2;p.lean=-.12-pull*.10
			p.frontThigh=-.2;p.frontShin=.15;p.backThigh=.2;p.backShin=.35
		else
			local swing=math.clamp((now-hit)/.12,0,1)
			p.frontUpper=-2.35+3.55*swing;p.frontFore=-2.35+3.8*swing
			p.blade=.65-2.65*swing;p.lean=.23;p.backUpper=-.65;p.backFore=-.5
			p.frontThigh=-.3;p.frontShin=-.1;p.backThigh=.4;p.backShin=.65
			striking=now-hit<.19
		end
		if heavy then p.lean*=1.3;p.bob=-.4 end
		if state=="Arcana1" then
			p.frontUpper=now<hit and .6 or 1.1;p.frontFore=now<hit and 2.3 or 1.8
			p.blade=-.18;p.backUpper=-.65;p.backFore=-1.3;striking=false
		end
	elseif attribute(rig,"DashUntil",0)>now then
		p.lean=.43;p.bob=-1.1;p.frontThigh=-.95;p.frontShin=.5;p.backThigh=1;p.backShin=1.2
		p.frontUpper=-.55;p.frontFore=-.8;p.backUpper=-.8;p.backFore=-1;p.blade=-.55;p.cape=-.3
	elseif attribute(rig,"Guarding",false) or attribute(rig,"ParryUntil",0)>now then
		p.lean=-.11;p.bob=-.55;p.frontUpper=.9;p.frontFore=2.4;p.blade=-.12
		p.backUpper=.35;p.backFore=1.6;p.frontThigh=-.3;p.frontShin=.25;p.backThigh=.3;p.backShin=.6
	end
	if attribute(rig,"StunUntil",0)>now then
		p.lean=-.30;p.head=.2;p.frontUpper=-.6;p.frontFore=-.4;p.backUpper=-.8;p.blade=-.4
	end
	if attribute(rig,"LaunchUntil",0)>now then p.lean=-.65;p.frontThigh=-.9;p.backThigh=.8 end
	local alpha=1-math.exp(-dt*(attacking and 34 or 19))
	if stopped then alpha=0 end
	for key,value in pairs(p) do
		local old=rig.pose[key]
		rig.pose[key]=old and old+(value-old)*alpha or value
	end
	return rig.pose,striking,airborne
end

function PixelRenderer:_stepRig(rig, dt, now)
	local viewer=Players.LocalPlayer and Players.LocalPlayer.Character
	local arenaId=viewer and viewer:GetAttribute("ArenaId")
	local visible=rig.model==viewer or (arenaId~=nil and rig.model:GetAttribute("ArenaId")==arenaId)
	if visible and not rig.built then self:_build(rig) end
	if visible~=rig.visible then
		rig.visible=visible
		for _,sheet in pairs(rig.sheets) do sheet.gui.Enabled=visible end
		for _,sheet in ipairs(rig.trail) do sheet.gui.Enabled=false end
		rig.lastPosition=rig.root.Position
	end
	if not visible then return end
	local weapon=attribute(rig,"Weapon","Longblade")
	if not Content.Weapons[weapon] then weapon="Longblade" end
	if rig.weapon~=weapon then
		if rig.sheets.weapon then rig.sheets.weapon.part:Destroy() end
		if rig.sheets.secondWeapon then rig.sheets.secondWeapon.part:Destroy();rig.sheets.secondWeapon=nil end
		rig.weapon=weapon
		rig.sheets.weapon=sprite(rig.folder,weapon,WEAPONS[weapon] or WEAPONS.Longblade,rig.colors)
		if weapon=="TwinFangs" or weapon=="Gauntlets" then
			rig.sheets.secondWeapon=sprite(rig.folder,"Offhand"..weapon,WEAPONS[weapon],rig.colors)
		end
		rig.facing=0
	end
	local facing=attribute(rig,"Facing",1)<0 and -1 or 1
	if facing~=rig.facing then
		rig.facing=facing
		for _,sheet in pairs(rig.sheets) do mirror(sheet,facing) end
	end
	local hitStop=attribute(rig,"HitStopUntil",0)
	if hitStop>rig.lastHitStop and hitStop>now then rig.flash=.085 end
	rig.lastHitStop=hitStop
	local wasFlash=rig.flash>0
	rig.flash=math.max(0,rig.flash-dt)
	if wasFlash then
		local brightness=rig.flash/.085*.48
		for id,sheet in pairs(rig.sheets) do if id~="shadow" then tint(sheet,brightness) end end
	end
	local p,striking,airborne=poseFor(rig,dt,now)
	local base=rig.root.Position+Vector3.new(0,-3.2,.22)
	local function put(id,x,y,angle,z)
		local sheet=rig.sheets[id]
		if sheet then sheet.part.CFrame=CFrame.new(base+Vector3.new(x*P*facing,y*P,z))*CFrame.Angles(0,0,angle*facing) end
	end
	local hipY=14+p.bob
	local function bodyPoint(x,y)
		return x*math.cos(p.lean)-y*math.sin(p.lean),hipY+x*math.sin(p.lean)+y*math.cos(p.lean)
	end
	local function bodyPart(id,x,y,angle,z)
		local bx,by=bodyPoint(x,y);put(id,bx,by,p.lean+angle,z)
	end
	local function chain(upper,lower,x,y,a,b,len,lowerLen,z)
		local kneeX=x+math.sin(a)*len
		local kneeY=y-math.cos(a)*len
		put(upper,x+math.sin(a)*len/2,y-math.cos(a)*len/2,a,z)
		put(lower,kneeX+math.sin(b)*lowerLen/2,kneeY-math.cos(b)*lowerLen/2,b,z+.002)
		return kneeX+math.sin(b)*lowerLen,kneeY-math.cos(b)*lowerLen
	end
	chain("backThigh","backShin",-.95,hipY,p.backThigh,p.backShin,7,7,-.09)
	bodyPart("cape",-3.7,4.5,p.cape,-.065)
	local shoulderX,shoulderY=bodyPoint(1.6,9)
	local bx,by=chain("backUpperArm","backForeArm",shoulderX,shoulderY,p.backUpper+p.lean,p.backFore+p.lean,6,5,-.045)
	chain("frontThigh","frontShin",1.25,hipY,p.frontThigh,p.frontShin,7,7,.006)
	bodyPart("body",0,5,0,0)
	bodyPart("scarf",-4.1,9.2,p.cape-.08,.009)
	bodyPart("head",.55,13.65,p.head,.015)
	local fx,fy=chain("frontUpperArm","frontForeArm",shoulderX,shoulderY,p.frontUpper+p.lean,p.frontFore+p.lean,6,5,.04)
	local function weaponAt(id,x,y,angle,z)
		local sheet=rig.sheets[id]
		if not sheet then return end
		local length=sheet.h/2-1
		put(id,x-math.sin(angle)*length,y+math.cos(angle)*length,angle,z)
	end
	weaponAt("weapon",fx,fy,p.blade,.065)
	weaponAt("secondWeapon",bx,by,-.9,-.032)
	local shadow=rig.sheets.shadow
	-- Arena floors are y=0; this stays grounded while a fighter jumps or is launched.
	shadow.part.Size=Vector3.new(P*10*(airborne and .7 or 1),P*3,.025)
	shadow.part.CFrame=CFrame.new(rig.root.Position.X,.035,rig.root.Position.Z+.05)*CFrame.Angles(-math.pi/2,0,0)
	local weaponSheet=rig.sheets.weapon
	local tip=weaponSheet.part.CFrame:PointToWorldSpace(Vector3.new(0,weaponSheet.h*P/2-.1,.03))
	if striking and rig.lastTip then
		for i,dot in ipairs(rig.trail) do
			dot.gui.Enabled=true
			dot.part.CFrame=CFrame.new(tip:Lerp(rig.lastTip,i/5)+Vector3.new(0,0,-.01))
			for _,r in ipairs(dot.rectangles) do r.frame.BackgroundTransparency=.16+i*.15 end
		end
	else for _,dot in ipairs(rig.trail) do dot.gui.Enabled=false end end
	rig.lastTip=tip
end

function PixelRenderer:Step(dt)
	if self.destroyed then return end
	dt=math.clamp(dt,0,.1)
	self.scan-=dt
	if self.scan<=0 then
		self.scan=.2
		local seen={}
		local function consider(model, player)
			if not model then return end
			local root=model:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then return end
			seen[model]=true
			local rig=self.rigs[model]
			if rig and rig.root~=root then dispose(rig);self.rigs[model]=nil;rig=nil end
			if not rig then rig=self:_create(model,player,root) end
			hideOriginal(rig)
		end
		for _,player in ipairs(Players:GetPlayers()) do consider(player.Character,player) end
		local fighters=workspace:FindFirstChild("PARABOUNDFighters")
		if fighters then for _,model in ipairs(fighters:GetChildren()) do if model:IsA("Model") then consider(model,nil) end end end
		for model,rig in pairs(self.rigs) do if not seen[model] then dispose(rig);self.rigs[model]=nil end end
	end
	local now=workspace:GetServerTimeNow()
	for model,rig in pairs(self.rigs) do
		if model.Parent and rig.root.Parent then self:_stepRig(rig,dt,now)
		else dispose(rig);self.rigs[model]=nil end
	end
end

function PixelRenderer:GetStats()
	local fighters,runs,registered=0,0,0
	for _,rig in pairs(self.rigs) do
		registered+=1
		if rig.visible then fighters+=1 end
		for _,sheet in pairs(rig.sheets) do runs+=#sheet.rectangles end
		for _,sheet in ipairs(rig.trail) do runs+=#sheet.rectangles end
	end
	return {Fighters=fighters,SpriteRuns=runs,Registered=registered}
end

function PixelRenderer:Destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,rig in pairs(self.rigs) do dispose(rig) end
	table.clear(self.rigs)
	self.folder:Destroy()
end

return PixelRenderer
