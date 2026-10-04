-- Server authority for PARABOUND's two dimensional arena combat.
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("PARABOUND"):WaitForChild("Content"))
local Combat = {}; Combat.__index = Combat
local PARRY_TIME, PERFECT_TIME, MISS_RECOVERY = .16, .075, .18
local COYOTE_TIME, JUMP_BUFFER, ACTIVE_TIME = .12, .13, .07
local COSTS = Content.ResonanceCosts or {Light=0,Heavy=10,Dash=8,Arcana1=24}
local RESONANCE_REGEN = Content.ResonanceRegen or 6
-- Mirrors Client.client.luau: launched flight holds speed for LaunchUntil, then air approach() decelerates at 70.
local LAUNCH_HOLD, AIR_DECELERATION, SPEED_MARGIN = .35, 70, 25
local TIMINGS = {
 Longblade={Light=.16,Heavy=.30,LightRecovery=.20,HeavyRecovery=.32,Range=7},
 TwinFangs={Light=.12,Heavy=.24,LightRecovery=.17,HeavyRecovery=.26,Range=6},
 Spear={Light=.20,Heavy=.34,LightRecovery=.23,HeavyRecovery=.34,Range=9},
}
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function finite(x) return type(x)=="number" and x==x and math.abs(x)<math.huge end
local function rootOf(m) return m and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart) end
local function humOf(m) return m and m:FindFirstChildOfClass("Humanoid") end
local function alive(s) return s and not s.Dead and s.Model and s.Model.Parent end
local function valid(t,k) return type(k)=="string" and t[k]~=nil end
function Combat.new(effectCallback,eventCallback)
 return setmetatable({States={},Effect=effectCallback or function() end,Event=eventCallback or function() end,Clock=Workspace:GetServerTimeNow()},Combat)
end
function Combat:_effect(kind,data)
 data=data or {}; local source=data.Model and self.States[data.Model]; if source then data.Facing=source.Facing end
 local ok,err=pcall(self.Effect,kind,data); if not ok then warn("PARABOUND effect:",err) end
end
function Combat:_event(kind,a,b,data)
 local ok,err=pcall(self.Event,kind,a,b,data or {}); if not ok then warn("PARABOUND event:",err) end
end
function Combat:_attr(s)
 local m=s.Model; if not m or not m.Parent then return end
 for _,key in ipairs({"Health","MaxHealth","Guard","Resonance","Overtone","Impact","Stocks","Mode","Weapon","School","Team","Facing","Dead","Airborne","Guarding","JumpCount"}) do if s[key]~=nil then m:SetAttribute(key,s[key]) end end
 for _,key in ipairs({"AttackUntil","AttackStarted","AttackHitAt","TellAt","ParryUntil","StunUntil","DashUntil","LaunchUntil","HitStopUntil","IFrameUntil","SlowUntil","GroundIgnoreUntil","ImpulseSerial"}) do m:SetAttribute(key,s[key] or 0) end
 m:SetAttribute("AttackState",s.AttackState or "")
 local state=s.AttackState or (self.Clock<(s.StunUntil or 0) and "Hurt") or (self.Clock<s.ParryUntil and "Parry") or (s.Guarding and "Guard") or (self.Clock<(s.DashUntil or 0) and "Dash") or ""
 m:SetAttribute("ActionState",state); m:SetAttribute("ActionStart",s.ActionStart or 0)
 m:SetAttribute("ActionHit",s.AttackHitAt or 0); m:SetAttribute("ActionEnd",state=="Hurt" and s.StunUntil or state=="Parry" and s.ParryUntil or s.ActionEnd or 0)
 m:SetAttribute("Shielded",self.Clock<(s.ShieldUntil or 0))
 m:SetAttribute("ExpectedLaunchVelocity",s.ExpectedLaunchVelocity or Vector3.zero)
 m:SetAttribute("ParryCompensatedMs",math.floor((s.ParryCompensated or 0)*1000+.5))
 for _,key in ipairs({"Arcana1","Arcana2","Dash","Parry","Attack"}) do m:SetAttribute("CD_"..key,math.max(0,(s.Cooldowns[key] or 0)-self.Clock)) end
end
function Combat:_weaponVisual(s)
 -- The pixel renderer owns weapon art. Remove geometry left by earlier builds.
 if s.WeaponJoint then s.WeaponJoint:Destroy(); s.WeaponJoint=nil end
 for _,child in ipairs(s.Model:GetChildren()) do if string.sub(child.Name,1,15)=="PARABOUNDWeapon" then child:Destroy() end end
end
function Combat:Register(model,options)
 if not model then return nil end; options=options or {}
 local hum=humOf(model); local maximum=math.max(1,tonumber(options.Health) or (hum and hum.MaxHealth) or 100)
 local s={Model=model,ImpulseSerial=model:GetAttribute("ImpulseSerial") or 0,Player=options.Player,Weapon=valid(Content.Weapons,options.Weapon) and options.Weapon or "Longblade",School=valid(Content.Schools,options.School) and options.School or "Ember",Team=options.Team,Mode=options.Mode or "Crucible",Arena=options.Arena,MaxHealth=maximum,Stocks=tonumber(options.Stocks) or 3,BaseWalkSpeed=hum and hum.WalkSpeed,DashSpeedBonus=options.DashSpeedBonus or 0}
 self.States[model]=s; self:Reset(model); self:_weaponVisual(s); return s
end
function Combat:Get(model) return self.States[model] end
function Combat:SetArena(model,arena) local s=self.States[model]; if not s then return false end; s.Arena=arena; return true end
function Combat:Remove(model) self.States[model]=nil end
function Combat:SetLoadout(model,weapon,school)
 local s=self.States[model]; if not s then return false end
 if valid(Content.Weapons,weapon) then s.Weapon=weapon end; if valid(Content.Schools,school) then s.School=school end
 self:_weaponVisual(s); self:_attr(s); return true
end
function Combat:Reset(model)
 local s=self.States[model]; if not s then return false end
 s.Health,s.Guard,s.Resonance,s.Overtone,s.Impact=s.MaxHealth,100,100,0,0
 s.Dead,s.Guarding,s.WantsGuard,s.Airborne=false,false,false,false
 s.Facing=s.Facing or 1; s.JumpCount,s.Combo,s.LastHit=0,0,0
 s.Cooldowns={}; s.Pending=nil; s.BufferedAction=nil; s.FreezeVelocity=nil; s.FreezeFromLaunch=nil; s.SpeedAllowance=nil; s.SpeedAllowanceAt=nil; s.ExpectedLaunchVelocity=nil; s.LastImpulseVelocity=nil; s.LastImpulseAction=nil; s.LastImpulseAt=nil
 for _,key in ipairs({"BusyUntil","ParryUntil","ParryStarted","ParryRecoverUntil","AttackUntil","AttackStarted","AttackHitAt","TellAt","StunUntil","DashUntil","LaunchUntil","HitStopUntil","IFrameUntil","SlowUntil","JumpBufferedUntil","GroundIgnoreUntil","ActionStart","ActionEnd"}) do s[key]=0 end
 s.ParryResolved=false; s.LastGrounded=-math.huge; s.AttackState=nil; s.ShieldUntil=nil
 local hum=humOf(model); if hum then hum.MaxHealth=s.MaxHealth; hum.Health=s.Health end
 local root=rootOf(model); if root then root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero end
 self:_attr(s); return true
end
function Combat:_setHealth(s,value)
 s.Health=clamp(value,0,s.MaxHealth); local hum=humOf(s.Model); if hum then hum.Health=s.Health end
 if s.Health<=0 and not s.Dead then s.Dead=true; self:_cancel(s); s.Guarding=false; s.WantsGuard=false; self:_event("Death",nil,s.Model,{Mode=s.Mode,Stocks=s.Stocks}); self:_event("KO",nil,s.Model,{Mode=s.Mode,Stocks=s.Stocks}) end
 self:_attr(s)
end
function Combat:_canAct(s) return alive(s) and self.Clock>=s.BusyUntil and self.Clock>=s.StunUntil and self.Clock>=s.HitStopUntil and self.Clock>=s.ParryRecoverUntil end
function Combat:_cooldown(s,key,duration)
 if (s.Cooldowns[key] or 0)>self.Clock then return false end; s.Cooldowns[key]=self.Clock+duration; return true
end
function Combat:FacingLocked(s)
 -- Facing is committed through an attack's active frames and while parrying or guarding,
 -- so held movement cannot swing a hitbox behind the attacker or turn a guard away from a threat.
 if not s then return false end
 return (s.Pending~=nil and self.Clock<s.Pending.ActiveUntil) or self.Clock<(s.ParryUntil or 0) or s.WantsGuard==true
end
function Combat:_faceThreat(s)
 local root=rootOf(s.Model); if not root then return end
 local best,bestDistance
 for model,other in pairs(self.States) do
  if other~=s and alive(other) and other.Mode==s.Mode and other.Arena==s.Arena and (not s.Team or not other.Team or other.Team~=s.Team) then
   local r=rootOf(model); local d=r and math.abs(r.Position.X-root.Position.X)
   if d and d<=16 and (not bestDistance or d<bestDistance) then best,bestDistance=r,d end
  end
 end
 if best and bestDistance>.05 then s.Facing=best.Position.X>=root.Position.X and 1 or -1 end
end
function Combat:_facing(s,direction)
 local x=typeof(direction)=="Vector3" and direction.X or direction
 if not finite(x) or math.abs(x)<.05 or self:FacingLocked(s) then return end
 s.Facing=x>=0 and 1 or -1
 -- Facing flips sprite art, while the upright physical collider keeps a fixed orientation.
end
function Combat:_cancel(s)
 s.Pending=nil; s.BufferedAction=nil; s.AttackState=nil; s.AttackUntil=0; s.AttackHitAt=0; s.TellAt=0
 s.ActionStart=self.Clock; s.ActionEnd=self.Clock
end
function Combat:SpeedAllowance(s,at)
 -- Horizontal speed an owner can legitimately still carry from authoritative impulses at server time `at`.
 if not s or not s.SpeedAllowance then return 0 end
 return math.max(0,s.SpeedAllowance-AIR_DECELERATION*math.max(0,(at or self.Clock)-s.SpeedAllowanceAt-LAUNCH_HOLD))
end
function Combat:_impulse(s,velocity,action,resume)
 local root=rootOf(s.Model); if not root then return false end
 s.SpeedAllowance=math.max(self:SpeedAllowance(s,self.Clock),math.abs(velocity.X)+SPEED_MARGIN); s.SpeedAllowanceAt=self.Clock
 if not s.Player then root.AssemblyLinearVelocity=velocity end
 s.ImpulseSerial=math.max(s.ImpulseSerial or 0,s.Model:GetAttribute("ImpulseSerial") or 0)+1
 s.Model:SetAttribute("ImpulseSerial",s.ImpulseSerial)
 s.LastImpulseVelocity=velocity; s.LastImpulseAction=action; s.LastImpulseAt=self.Clock
 -- Only this server constructs impulse packets; the owning client applies each serial once.
 self:_effect("Impulse",{Model=s.Model,Velocity=velocity,Action=action,Serial=s.ImpulseSerial,IssuedAt=self.Clock,Resume=resume or nil,
  JumpCount=s.JumpCount,DashUntil=s.DashUntil,LaunchUntil=s.LaunchUntil,HitStopUntil=s.HitStopUntil,GroundIgnoreUntil=s.GroundIgnoreUntil,ArenaId=s.Model:GetAttribute("ArenaId")})
 return true
end
function Combat:_freeze(s,duration)
 local root=rootOf(s.Model); local starting=root and not s.FreezeVelocity
 if starting then
  -- A just-issued launch has not reached its network owner yet; keep that intended impulse.
  local launch=s.LastImpulseAction=="Launch" and s.LastImpulseAt==self.Clock
  s.FreezeVelocity=launch and s.LastImpulseVelocity or root.AssemblyLinearVelocity
  -- Server-observed owner velocity is stale by replication; only launches are authoritative on restore.
  s.FreezeFromLaunch=launch
 end
 s.HitStopUntil=math.max(s.HitStopUntil,self.Clock+duration)
 if starting then self:_impulse(s,Vector3.zero,"Freeze") end
end
function Combat:_launch(s,target,attack,scale)
 local ar,tr=rootOf(s.Model),rootOf(target.Model); if not ar or not tr then return end
 local sign=math.abs(tr.Position.X-ar.Position.X)<.01 and s.Facing or math.sign(tr.Position.X-ar.Position.X)
 local impactScale=clamp(1+target.Impact/100,1,2.65)*(scale or 1)
 if target.Mode=="Tutorial" then impactScale*=.15 end
 local velocity=Vector3.new(sign*attack.Knockback*impactScale,math.min(attack.Knockback*.54*impactScale,56),0)
 target.ExpectedLaunchVelocity=velocity
 target.Airborne=true; target.JumpCount=math.max(target.JumpCount,1); target.LaunchUntil=self.Clock+(scale and .16 or .35); target.GroundIgnoreUntil=target.LaunchUntil
 if target.FreezeVelocity then target.FreezeVelocity=velocity; target.FreezeFromLaunch=true else self:_impulse(target,velocity,"Launch") end
end
function Combat:_hit(s,p)
 local root=rootOf(s.Model); if not root then return end
 local attack=p.Attack
 for model,target in pairs(self.States) do
  if s.Pending~=p then break end
  if model~=s.Model and not p.HitTargets[model] and alive(target) and target.Mode==s.Mode and target.Arena==s.Arena and self.Clock>=target.IFrameUntil and (not s.Team or not target.Team or target.Team~=s.Team) then
   local tr=rootOf(model); local delta=tr and tr.Position-root.Position
   if delta and delta.X*s.Facing>=-1 and delta.X*s.Facing<=attack.Range and math.abs(delta.Y)<=(attack.Vertical or 3.5) and math.abs(delta.Z)<=2.5 then
    p.HitTargets[model]=true; p.Hit=true
    local front=(root.Position.X-tr.Position.X)*target.Facing>=-1
    if front and target.ParryUntil>0 and self.Clock<=target.ParryUntil then
     local perfect=self.Clock-target.ParryStarted<=PERFECT_TIME
     target.ParryUntil=0; target.ParryResolved=true; target.ParryRecoverUntil=0; target.BusyUntil=0
     target.Resonance=clamp(target.Resonance+(perfect and 20 or 12),0,100); target.Overtone=clamp(target.Overtone+(perfect and 30 or 15),0,100)
     self:_cancel(s); s.StunUntil=self.Clock+(perfect and .30 or .20); s.BusyUntil=s.StunUntil
     self:_freeze(s,perfect and .065 or .035); self:_freeze(target,perfect and .065 or .035)
     self:_effect(perfect and "PerfectParry" or "ParrySuccess",{Model=target.Model,Target=s.Model,Position=tr.Position})
     self:_event(perfect and "PerfectParry" or "Parry",target.Model,s.Model,{Attack=attack}); self:_attr(target); self:_attr(s)
    elseif front and target.Guarding and target.Guard>0 then
     target.Guard=math.max(0,target.Guard-math.max(10,attack.Damage*(attack.Heavy and 2.8 or 1.8)))
     self:_launch(s,target,attack,.18)
     if target.Guard<=0 then target.Guarding=false; target.WantsGuard=false; self:_cancel(target); target.StunUntil=self.Clock+.65; target.BusyUntil=target.StunUntil; self:_effect("GuardBreak",{Model=model,Position=tr.Position}) end
     self:_freeze(s,.025); self:_freeze(target,.025); self:_effect("Block",{Model=s.Model,Target=model,Position=tr.Position}); self:_attr(target)
    else
     target.Combo=self.Clock-target.LastHit<1.4 and target.Combo+1 or 0; target.LastHit=self.Clock
     local mult=math.max(.6,1-math.max(0,target.Combo-1)*.1); local damage=attack.Damage*mult
     if self.Clock<(target.ShieldUntil or 0) then damage*=.75 end
     if target.Mode=="Crucible" then target.Impact=clamp(target.Impact+damage*1.25,0,200) else self:_setHealth(target,target.Health-damage) end
     if not target.Dead then
      self:_cancel(target); target.Guarding=false; target.WantsGuard=false
      target.StunUntil=self.Clock+clamp((attack.Stun or .18)*mult,.12,.30); target.BusyUntil=target.StunUntil
      self:_launch(s,target,attack); self:_freeze(target,.035)
     end
     self:_freeze(s,.035); s.Resonance=clamp(s.Resonance+3,0,100)
     self:_effect(p.Arcana and "ArcanaHit" or "Hit",{Model=s.Model,Target=model,Position=tr.Position,School=s.School,Weapon=s.Weapon,Damage=damage})
     self:_event("Hit",s.Model,model,{Damage=damage,Combo=target.Combo,Impact=target.Impact,Arcana=p.Arcana}); self:_attr(target)
    end
   end
  end
 end
end
function Combat:_beginAttack(s,attack,name,startup,recovery,arcana)
 local hitAt=self.Clock+startup; local ending=hitAt+ACTIVE_TIME+recovery
 s.Pending={Started=self.Clock,TellAt=hitAt-.08,HitAt=hitAt,ActiveUntil=hitAt+ACTIVE_TIME,Attack=attack,Name=name,Arcana=arcana,HitTargets={},Told=false}
 s.AttackState=name; s.AttackStarted=self.Clock; s.AttackHitAt=hitAt; s.TellAt=hitAt-.08; s.AttackUntil=ending
 s.ActionStart=self.Clock; s.ActionEnd=ending; s.BusyUntil=ending; s.Cooldowns.Attack=ending
 s.Guarding=false; s.WantsGuard=false; self:_attr(s)
end
function Combat:_ground(s)
 local root=rootOf(s.Model); if not root then return nil end
 local exclude={}; for model in pairs(self.States) do table.insert(exclude,model) end
 -- Permanent one-way NC.Enabled is owner-local; only transient drop exceptions are authoritative here.
 for _,node in ipairs(s.Model:GetDescendants()) do
  if node:IsA("NoCollisionConstraint") and node.Enabled and node.Part1 and not (node.Parent and node.Parent.Name=="OneWayPlatforms") then table.insert(exclude,node.Part1) end
 end
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.IgnoreWater=true; params.RespectCanCollide=true
 local feet=root.Position.Y-root.Size.Y*.5; local rising=root.AssemblyLinearVelocity.Y>1
 for _=1,4 do
  params.FilterDescendantsInstances=exclude
  local floor=Workspace:Raycast(root.Position,Vector3.new(0,-3.5,0),params)
  if not floor then return nil end
  local part=floor.Instance
  -- Independently mirror the collision rule; owner-local NC.Enabled may not replicate.
  if part:GetAttribute("DropThrough") and (rising or feet<part.Position.Y+part.Size.Y*.5-.12) then
   table.insert(exclude,part)
  else return floor end
 end
 return nil
end
function Combat:_jump(s)
 local root=rootOf(s.Model); if not root then return false end
 s.JumpCount+=1; s.Airborne=true; s.JumpBufferedUntil=0; s.GroundIgnoreUntil=self.Clock+.12; s.LastGrounded=-math.huge
 self:_impulse(s,Vector3.new(root.AssemblyLinearVelocity.X,44,0),"Jump")
 self:_event("Jump",s.Model,nil,{JumpCount=s.JumpCount}); self:_attr(s); return true
end
function Combat:Intent(model,action,payload)
 local s=self.States[model]; if not alive(s) then return false end
 self.Clock=Workspace:GetServerTimeNow(); payload=type(payload)=="table" and payload or {}
 if action=="Move" then
  self:_facing(s,payload.direction or payload.x); self:_attr(s); return true
 elseif action=="GuardEnd" then
  s.WantsGuard=false; s.Guarding=false
  -- Releasing stops the held guard, while a tap keeps its initial counter window.
  self:_attr(s); return true
 end
 if payload.direction~=nil and action~="Parry" and action~="Guard" then self:_facing(s,payload.direction) end
 if action=="Parry" or action=="Guard" then
  if s.WantsGuard then return action=="Guard" end
  if not self:_canAct(s) or s.Guard<10 or not self:_cooldown(s,"Parry",.38) then return false end
  local age=finite(payload.timestamp) and clamp(self.Clock-payload.timestamp,0,.08) or 0
  self:_faceThreat(s)
  s.Guard-=10; s.ParryCompensated=age; s.ParryStarted=self.Clock-age; s.ParryUntil=self.Clock+PARRY_TIME-age
  s.ParryResolved=false; s.ParryRecoverUntil=s.ParryUntil+MISS_RECOVERY; s.WantsGuard=true; s.Guarding=false; s.BusyUntil=s.ParryUntil
  s.ActionStart=self.Clock; s.ActionEnd=s.ParryRecoverUntil
  self:_effect("Parry",{Model=model,Position=rootOf(model) and rootOf(model).Position}); self:_attr(s); return true
 elseif action=="Feint" then
  if s.Pending and self.Clock<s.Pending.TellAt then self:_cancel(s); s.BusyUntil=self.Clock+.08; s.Cooldowns.Attack=s.BusyUntil; self:_effect("Feint",{Model=model}); self:_attr(s); return true end; return false
 elseif action=="Dash" then
  if not self:_canAct(s) or s.Resonance<COSTS.Dash or not self:_cooldown(s,"Dash",.65) then return false end
  local root=rootOf(model); if not root then return false end
  s.Resonance-=COSTS.Dash; s.DashUntil=self.Clock+.16; s.IFrameUntil=self.Clock+.10; s.ActionStart=self.Clock; s.ActionEnd=s.DashUntil
  self:_impulse(s,Vector3.new(s.Facing*44,root.AssemblyLinearVelocity.Y,0),"Dash")
  self:_effect("Dash",{Model=model}); self:_attr(s); return true
 elseif action=="Jump" then
  if s.Airborne and s.JumpCount>=2 then
   local root=rootOf(model); local landing=root and self.Clock>=s.GroundIgnoreUntil and root.AssemblyLinearVelocity.Y<=1.5 and self:_ground(s)
   -- Still rejected now, but buffered so a press just before the server sees the landing is not lost.
   if not landing then s.JumpBufferedUntil=self.Clock+JUMP_BUFFER; return false end
  end
  s.JumpBufferedUntil=self.Clock+JUMP_BUFFER
  if self:_canAct(s) then
   if not s.Airborne or self.Clock-s.LastGrounded<=COYOTE_TIME then s.JumpCount=0; return self:_jump(s)
   elseif s.JumpCount<2 then return self:_jump(s) end
  end; return true
 elseif action=="Drop" or action=="DropThrough" then
  if not self:_canAct(s) or (s.Cooldowns.Drop or 0)>self.Clock then return false end
  local root=rootOf(model); local floor=self:_ground(s)
  if not root or not floor or not floor.Instance:GetAttribute("DropThrough") then return false end
  self:_cooldown(s,"Drop",.4)
  for _,part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then local nc=Instance.new("NoCollisionConstraint"); nc.Part0=part; nc.Part1=floor.Instance; nc.Parent=model; Debris:AddItem(nc,.35) end end
  s.Airborne=true; s.JumpCount=math.max(1,s.JumpCount); s.GroundIgnoreUntil=self.Clock+.35; s.LastGrounded=-math.huge
  self:_impulse(s,Vector3.new(root.AssemblyLinearVelocity.X,-18,0),"Drop"); self:_attr(s); return true
 elseif action=="FastFall" then
  local root=rootOf(model); if self:_canAct(s) and root and s.Airborne then self:_impulse(s,Vector3.new(root.AssemblyLinearVelocity.X,-65,0),"FastFall"); return true end; return false
 elseif action=="Light" or action=="Heavy" then
  if not self:_canAct(s) then
   if s.AttackState and self.Clock>=s.AttackHitAt+ACTIVE_TIME and s.AttackUntil-self.Clock<=.10 and self.Clock>=s.StunUntil then s.BufferedAction=action; return true end
   return false
  end
  local w=Content.Weapons[s.Weapon]; local t=TIMINGS[s.Weapon] or {Light=w.Startup,Heavy=w.Startup*1.4,LightRecovery=w.Recovery,HeavyRecovery=w.Recovery*1.3,Range=math.min(w.Range,9)}
  local heavy=action=="Heavy"; local cost=COSTS[action] or 0
  if s.Resonance<cost or (s.Cooldowns.Attack or 0)>self.Clock then return false end
  s.Resonance-=cost
  self:_beginAttack(s,{Damage=w.Damage*(heavy and 1.5 or 1),Range=t.Range,Knockback=w.Knockback*(heavy and 1.4 or 1),Stun=heavy and .27 or .18,Heavy=heavy,Vertical=s.Airborne and 4.5 or 3.5},action,t[action],t[action.."Recovery"]); return true
 elseif action=="Arcana1" then
  if not self:_canAct(s) or s.Resonance<COSTS.Arcana1 or not self:_cooldown(s,"Arcana1",5) then return false end
  s.Resonance-=COSTS.Arcana1
  self:_beginAttack(s,{Damage=13,Range=12,Knockback=24,Stun=.20,Vertical=3.5},action,.32,.30,true)
  self:_effect("Arcana",{Model=model,Position=rootOf(model) and rootOf(model).Position,School=s.School,Ability=Content.Schools[s.School].Abilities[1],Radius=3}); return true
 end
 return false
end
function Combat:Step(dt)
 dt=clamp(tonumber(dt) or 0,0,.1); self.Clock=Workspace:GetServerTimeNow()
 for _,s in pairs(self.States) do
  if alive(s) then
   s.Resonance=clamp(s.Resonance+dt*RESONANCE_REGEN,0,100)
   if s.ParryUntil>0 and self.Clock>=s.ParryUntil then s.ParryUntil=0; if not s.ParryResolved then s.BusyUntil=math.max(s.BusyUntil,s.ParryRecoverUntil) end end
   s.Guarding=s.WantsGuard and s.Guard>0 and s.ParryUntil==0 and self.Clock>=s.BusyUntil and self.Clock>=s.StunUntil
   s.Guard=clamp(s.Guard+dt*(s.Guarding and -7 or 10),0,100)
   if s.Guard<=0 then s.Guarding=false; s.WantsGuard=false end
   local p=s.Pending
   if p then
    if self.Clock<s.StunUntil then self:_cancel(s)
    else
     if not p.Told and self.Clock>=p.TellAt then p.Told=true; self:_effect("Startup",{Model=s.Model,Position=rootOf(s.Model) and rootOf(s.Model).Position,Attack=p.Name,Duration=.08,School=s.School,Weapon=s.Weapon}) end
     -- Sample each heartbeat during the active window, including its first elapsed frame.
     if self.Clock>=p.HitAt and (self.Clock<=p.ActiveUntil or not p.Sampled) then p.Sampled=true; self:_hit(s,p) end
     if s.Pending==p and self.Clock>=p.ActiveUntil then s.Pending=nil end
    end
   end
   if s.AttackState and self.Clock>=s.AttackUntil then s.AttackState=nil end
   if s.BufferedAction and self:_canAct(s) then local buffered=s.BufferedAction; s.BufferedAction=nil; self:Intent(s.Model,buffered,{}) end
   local root=rootOf(s.Model)
   if root then
    if self.Clock<s.HitStopUntil then
     -- Player-owned assemblies freeze locally from the packet/attribute; NPCs simulate here.
     if not s.Player then root.AssemblyLinearVelocity=Vector3.zero end
    elseif s.FreezeVelocity then
     local velocity,resume=s.FreezeVelocity,not s.FreezeFromLaunch; s.FreezeVelocity=nil; s.FreezeFromLaunch=nil; self:_impulse(s,velocity,"Restore",resume)
    end
    local floor=self:_ground(s)
    local grounded=floor~=nil and self.Clock>=s.GroundIgnoreUntil and root.AssemblyLinearVelocity.Y<=1.5 and self.Clock>=s.HitStopUntil
    if grounded then s.Airborne=false; s.JumpCount=0; s.LastGrounded=self.Clock
    elseif not s.Airborne then s.Airborne=true; s.JumpCount=math.max(1,s.JumpCount) end
    if s.JumpBufferedUntil>self.Clock and (grounded or self.Clock-s.LastGrounded<=COYOTE_TIME) and self:_canAct(s) then s.JumpCount=0; self:_jump(s) end
   end
   if s.Mode=="Crucible" and s.Impact>0 and not s.Airborne then s.Impact=math.max(0,s.Impact-dt*1.1) end
   self:_attr(s)
  end
 end
end
return Combat
