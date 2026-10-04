-- Studio SERVER command-bar suite. Fixtures are isolated from live arenas.
local Combat=require(game.ServerScriptService.PARABOUND.Combat)
local World=require(game.ServerScriptService.PARABOUND.World)
local results,effects,events,impulses={},{},{},{}
local engine=Combat.new(function(k,data) table.insert(effects,k); if k=="Impulse" then table.insert(impulses,data) end end,function(k) table.insert(events,k) end)
local arena={}
local a=World.CreateFighter("QA Attacker",Vector3.new(0,3.2,12000),Color3.new(1,1,1)); a.Parent=workspace
local b=World.CreateFighter("QA Defender",Vector3.new(5,3.2,12000),Color3.new(1,1,1)); b.Parent=workspace
for _,model in ipairs({a,b}) do model.HumanoidRootPart.Anchored=true end
local shelf=Instance.new("Part"); shelf.Name="QA Shelf"; shelf.Anchored=true; shelf.Size=Vector3.new(12,1,8); shelf.Position=Vector3.new(0,4,12000); shelf:SetAttribute("DropThrough",true)
local floor=Instance.new("Part"); floor.Name="QA Floor"; floor.Anchored=true; floor.Size=Vector3.new(30,1,10); floor.Position=Vector3.new(0,0,12000); floor.Parent=workspace
local sa=engine:Register(a,{Mode="Training",Health=500,Team="A",Arena=arena})
local sb=engine:Register(b,{Mode="Training",Health=500,Team="B",Arena=arena})
local function check(name,condition) table.insert(results,{Name=name,Passed=condition}); assert(condition,name) end
local function step(seconds)
 local start=workspace:GetServerTimeNow()
 repeat task.wait(.01); engine:Step(.01) until workspace:GetServerTimeNow()-start>=seconds
end
local function reset()
 engine:Reset(a); engine:Reset(b); engine:SetLoadout(a,"Longblade","Ember")
 a:PivotTo(CFrame.lookAt(Vector3.new(0,3.2,12000),Vector3.new(1,3.2,12000)))
 b:PivotTo(CFrame.lookAt(Vector3.new(5,3.2,12000),Vector3.new(4,3.2,12000)))
 sa.Facing=1; sb.Facing=-1; sa.Mode="Training"; sb.Mode="Training"; sb.Team="B"; sb.Arena=arena
 table.clear(effects); table.clear(events); table.clear(impulses); engine:Step(0)
end
local ok,err=pcall(function()
 for _,entry in ipairs({{"Longblade",.16,.30},{"TwinFangs",.12,.24},{"Spear",.20,.34}}) do
  for _,action in ipairs({"Light","Heavy"}) do
   reset(); engine:SetLoadout(a,entry[1],"Ember")
   check(entry[1].." "..action.." accepted",engine:Intent(a,action,{Damage=1e9}))
   local expected=action=="Light" and entry[2] or entry[3]
   check(entry[1].." "..action.." exact startup",math.abs(sa.AttackHitAt-sa.AttackStarted-expected)<.001)
   check("Animation timing published",a:GetAttribute("ActionHit")==sa.AttackHitAt and a:GetAttribute("TellAt")==sa.TellAt)
   step(expected+.025)
   check(entry[1].." bounded server damage",sb.Health<500 and sb.Health>460)
   local health=sb.Health; step(.08); check("Active window cannot hit a target twice",sb.Health==health)
   check("Commitment tell emitted",table.find(effects,"Startup")~=nil)
  end
 end
 reset(); engine:Intent(a,"Light",{}); step(.12); engine:Intent(b,"Parry",{}); step(.10)
 check("Perfect parry negates damage",sb.Health==500)
 check("Perfect parry distinct event",table.find(events,"PerfectParry")~=nil)
 check("Parry cancels attacker pending",sa.Pending==nil and sa.StunUntil>engine.Clock)
 reset(); engine:Intent(a,"Light",{}); step(.05); engine:Intent(b,"Parry",{}); step(.17)
 check("Normal parry negates damage",sb.Health==500)
 check("Normal parry distinct event",table.find(events,"Parry")~=nil)
 reset(); check("Guard start costs meter",engine:Intent(b,"Guard",{}) and sb.Guard==90)
 check("Guard input does not recharge parry",engine:Intent(b,"Guard",{}) and sb.Guard==90)
 step(.18); check("Missed parry recovery",not sb.Guarding and sb.BusyUntil>engine.Clock)
 step(.20); check("Holding guard follows miss recovery",sb.Guarding)
 engine:Intent(a,"Heavy",{}); step(.40); check("Guard absorbs damage and loses meter",sb.Health==500 and sb.Guard<90)
 engine:Intent(b,"GuardEnd",{}); check("Guard release immediate",not sb.Guarding and not sb.WantsGuard and b:GetAttribute("Guarding")==false)
 reset(); engine:Intent(b,"Parry",{}); engine:Intent(b,"GuardEnd",{})
 check("Tap release retains initial parry window",sb.ParryUntil>engine.Clock and not sb.WantsGuard and not sb.Guarding)
 check("Parry spam rejected",engine:Intent(b,"Parry",{})==false)
 reset(); engine:Intent(a,"Light",{}); step(.12); engine:Intent(b,"Parry",{}); local tappedUntil=sb.ParryUntil
 engine:Intent(b,"GuardEnd",{}); check("Tap preserves exact window deadline",sb.ParryUntil==tappedUntil)
 step(.10); check("Released tap parry succeeds",sb.Health==500 and table.find(events,"PerfectParry")~=nil)
 check("Successful released tap does not start held guard",not sb.WantsGuard and not sb.Guarding)
 reset(); engine:Intent(a,"Light",{}); check("Pre-tell feint accepted",engine:Intent(a,"Feint",{})); step(.25); check("Feint prevents damage",sb.Health==500)
 reset(); engine:Intent(a,"Light",{}); step(.10); check("Post-tell feint rejected",engine:Intent(a,"Feint",{})==false)
 reset(); engine:Intent(a,"Light",{}); step(.35)
 local before=sa.Resonance; local started=sa.AttackStarted
 check("Recovery input buffered",engine:Intent(a,"Heavy",{})); check("Buffer defers resource charge",sa.Resonance==before)
 step(.13); check("Buffered action starts next attack",sa.AttackState=="Heavy" and sa.AttackStarted>started)
 reset(); sb.Arena={}; engine:Intent(a,"Light",{}); step(.25); check("Arena isolation",sb.Health==500)
 reset(); sb.Team="A"; engine:Intent(a,"Light",{}); step(.25); check("Friendly fire prevented",sb.Health==500)
 reset(); b:PivotTo(CFrame.new(5,8.3,12000)); engine:Intent(a,"Light",{}); step(.25); check("Vertical hurtbox bounded",sb.Health==500)
 reset(); engine:Intent(a,"Heavy",{}); step(.06); engine:Intent(b,"Light",{}); sb.Facing=-1; step(.20)
 check("Being struck cancels pending heavy",sa.Pending==nil and sa.AttackState==nil)
 reset(); check("Dash accepted",engine:Intent(a,"Dash",{}))
 check("Dash and immunity timing",sa.DashUntil-engine.Clock<=.161 and sa.IFrameUntil-engine.Clock<=.101)
 check("Movement remains accepted during lock",engine:Intent(a,"Move",{direction=-1}) and sa.Facing==-1)
 reset(); check("First jump accepted",engine:Intent(a,"Jump",{})); check("Second jump accepted",engine:Intent(a,"Jump",{}));
 floor.Parent=nil; check("Third jump rejected",engine:Intent(a,"Jump",{})==false); floor.Parent=workspace
 check("Jump count published",a:GetAttribute("JumpCount")==2)
 check("Ground immunity published",a:GetAttribute("GroundIgnoreUntil")==sa.GroundIgnoreUntil)
 check("Jump authority packet",#impulses==2 and impulses[1].Action=="Jump" and impulses[1].Model==a and impulses[1].Velocity.Y==44)
 check("Impulse serial increases",impulses[2].Serial>impulses[1].Serial and impulses[2].JumpCount==2)
 local priorSerial=impulses[2].Serial; reset(); engine:Intent(a,"Dash",{})
 check("Impulse serial survives reset",impulses[1].Serial>priorSerial and impulses[1].Action=="Dash" and math.abs(impulses[1].Velocity.X)==44)
 reset(); a.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(12,18,0)
 engine:_freeze(sa,.035); local freeze=impulses[1]; engine:_freeze(sa,.065)
 check("Freeze packet once",#impulses==1 and freeze.Action=="Freeze" and freeze.Velocity.Magnitude==0 and freeze.HitStopUntil>freeze.IssuedAt)
 sa.Player={}; a.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(2,4,8); engine:Step(0)
 check("Step does not overwrite player velocity",a.HumanoidRootPart.AssemblyLinearVelocity==Vector3.new(2,4,8)); sa.Player=nil
 step(.08); check("Restore packet preserves pre-freeze velocity",impulses[#impulses].Action=="Restore" and impulses[#impulses].Velocity==Vector3.new(12,18,0))
 reset(); engine:_freeze(sb,.04); local frozenSerial=sb.ImpulseSerial
 engine:_launch(sa,sb,{Knockback=28})
 check("Launch during freeze queues velocity",sb.ImpulseSerial==frozenSerial and sb.FreezeVelocity.X==28)
 step(.06); check("Queued launch restored authoritatively",impulses[#impulses].Action=="Restore" and impulses[#impulses].Model==b and impulses[#impulses].Velocity.X==28)
 reset(); sa.Player={}; a.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(3,0,0)
 engine:_impulse(sa,Vector3.new(0,44,0),"Jump")
 check("Owner impulse does not raw-write velocity",a.HumanoidRootPart.AssemblyLinearVelocity==Vector3.new(3,0,0))
 engine:_launch(sb,sa,{Knockback=28}); engine:_freeze(sa,.035)
 check("Owner launch survives immediate hit stop",sa.FreezeVelocity.X==-28 and sa.FreezeVelocity.Y>0)
 local ownerSerial=sa.ImpulseSerial; sa.Player=nil
 sa=engine:Register(a,{Mode="Training",Health=500,Team="A",Arena=arena}); engine:_impulse(sa,Vector3.zero,"Restore")
 check("Impulse serial survives same-model registration",sa.ImpulseSerial>ownerSerial)
 reset(); shelf.Parent=workspace; local originalSize=a.HumanoidRootPart.Size; a.HumanoidRootPart.Size=Vector3.new(1.6,6.4,.9)
 a:PivotTo(CFrame.new(0,7,12000)); a.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
 check("Shelf below collider feet cannot ground",engine:_ground(sa)==nil)
 a:PivotTo(CFrame.new(0,7.7,12000)); a.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(0,20,0)
 check("Rising fighter ignores one-way shelf",engine:_ground(sa)==nil)
 a.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(0,-2,0)
 check("Descending fighter grounds on shelf",engine:_ground(sa).Instance==shelf)
 local exception=Instance.new("NoCollisionConstraint"); exception.Part0=a.HumanoidRootPart; exception.Part1=shelf; exception.Enabled=true; exception.Parent=a
 check("Active drop collision exception excludes shelf",engine:_ground(sa)==nil)
 exception.Enabled=false; check("Disabled collision exception permits landing",engine:_ground(sa).Instance==shelf)
 exception:Destroy()
 local oneWay=Instance.new("Folder"); oneWay.Name="OneWayPlatforms"; oneWay.Parent=a
 local permanent=Instance.new("NoCollisionConstraint"); permanent.Part0=a.HumanoidRootPart; permanent.Part1=shelf; permanent.Enabled=true; permanent.Parent=oneWay
 check("Stale permanent NC permits descending shelf ground",engine:_ground(sa).Instance==shelf)
 oneWay:Destroy(); shelf.Parent=nil; a.HumanoidRootPart.Size=originalSize
 reset(); check("Ordinary floor drop rejected",engine:Intent(a,"Drop",{})==false)
 floor:SetAttribute("DropThrough",true); check("Designated floor drop accepted",engine:Intent(a,"Drop",{})); check("Drop cooldown",engine:Intent(a,"Drop",{})==false)
 reset(); engine:Intent(a,"Arcana1",{}); check("Arcana resource cost",sa.Resonance==76); check("Arcana cooldown",engine:Intent(a,"Arcana1",{})==false)
 check("Removed ability rejects",engine:Intent(a,"Arcana2",{})==false and engine:Intent(a,"Overtone",{})==false)
 check("Client damage intent rejects",engine:Intent(a,"DamageTarget",{Damage=1e9})==false)
 reset(); engine:Intent(b,"Parry",{timestamp=workspace:GetServerTimeNow()-10}); check("Compensation capped",sb.ParryCompensated<=.08)
 reset(); sa.Mode="Crucible"; sb.Mode="Crucible"; engine:Intent(a,"Light",{}); step(.25)
 check("PvP damage raises impact rather than HP",sb.Health==500 and sb.Impact>0)
 check("Stocks remain match-controller owned",sb.Stocks==3)
 -- Phase 1 cloud fixes (also covered offline by tests/offline/combat_spec.luau).
 reset(); sa.Resonance=0; check("Light is never resource-gated",engine:Intent(a,"Light",{}))
 reset(); engine:Intent(a,"Light",{direction=Vector3.new(1,0,0)}); engine:Intent(a,"Move",{direction=-1})
 check("Attack facing committed through active frames",sa.Facing==1); step(.25); check("Reverse input cannot swing hitbox behind",sb.Health<500)
 reset(); sb.Facing=1; engine:Intent(a,"Light",{}); step(.05); engine:Intent(b,"Parry",{direction=1}); engine:Intent(b,"GuardEnd",{}); step(.25)
 check("Retreating parry faces threat and negates",sb.Health==500 and sb.Facing==-1)
 reset(); a.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(12,18,0); engine:_freeze(sa,.035); step(.08)
 check("Self freeze restore marked Resume",impulses[#impulses].Action=="Restore" and impulses[#impulses].Resume==true)
end)
engine:Remove(a); engine:Remove(b); a:Destroy(); b:Destroy(); floor:Destroy(); shelf:Destroy()
if not ok then error(err) end
return results
