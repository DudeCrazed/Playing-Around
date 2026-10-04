-- PARABOUND • focused pixel platform duels. Server owns combat and match results.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Physics=game:GetService('PhysicsService')
local Http=game:GetService('HttpService')
local World=require(script.Parent.World)
local Combat=require(script.Parent.Combat)
local Package=RS:WaitForChild('PARABOUND')
local C=require(Package.Content)
local Net=Package.Net
local profiles,sessions,rooms,bots,queue,traffic={},{},{},{},{},{}
local engine
local clock=function() return workspace:GetServerTimeNow() end
local function root(m) return m and m:FindFirstChild('HumanoidRootPart') end
local function send(p,k,d) if p and p.Parent==Players then Net.State:FireClient(p,k,d) end end
local function notice(p,text) send(p,'Notice',{Text=text}) end
local function snapshot(p) local d=profiles[p];if d then send(p,'Snapshot',{Weapon=d.Weapon,Settings=d.Settings,Rating=d.Rating,TutorialComplete=d.TutorialComplete,Wins=d.Wins,Losses=d.Losses}) end end
local lessons={
 {Title='Find your footing',Text='Move left and right with A / D or the left stick. Travel twelve studs.',Target=12},
 {Title='Take the high route',Text='Jump, then jump again before landing. Space / A gives you a double jump.',Target=2},
 {Title='Break the distance',Text='Dash twice with Q / B. Dash has a short recovery; keep your spacing.',Target=2},
 {Title='Make contact',Text='Hit the sparring echo three times. J / X is light; K / Y is heavy.',Target=3},
 {Title='Answer the silver glint',Text='Watch the sword wind up. Tap F / LT just before contact. Hold it to guard.',Target=1},
 {Title='Perfect the countertone',Text='Parry closer to the impact for a perfect answer. Gold sparks confirm it.',Target=1},
}
local function tutorialState(p)
 local d=profiles[p];local s=sessions[p];if not d or not s or s.Mode~='Tutorial' then return end
 local lesson=lessons[d.Step]
 send(p,'Tutorial',{Step=d.Step,Title=lesson and lesson.Title or 'You are ready for the Crucible',Text=lesson and lesson.Text or 'Read the windup, vary your timing, and keep your recovery. Find a real duel or test yourself against an explicit practice bot.',Progress=d.Progress,Target=lesson and lesson.Target or 1,Complete=d.Step>6})
end
local function tutorialProgress(p,kind,amount)
 local d=profiles[p];local s=sessions[p];if not d or not s or s.Mode~='Tutorial' or d.Step>6 then return end
 local expected=({'Move','Jump','Dash','Hit','Parry','PerfectParry'})[d.Step]
 if kind=='PerfectParry' then d.PerfectSeen=true end
 if kind~=expected and not (d.Step==5 and kind=='PerfectParry') then return end
 if d.Step==2 then local st=engine:Get(p.Character);d.Progress=math.max(d.Progress,st and st.JumpCount or 0) else d.Progress=math.min(lessons[d.Step].Target,d.Progress+(amount or 1)) end
 if d.Progress>=lessons[d.Step].Target then
  d.Step+=1;d.Progress=0
  if d.Step==6 and d.PerfectSeen then d.Step=7 end
  if d.Step>6 then d.TutorialComplete=true;notice(p,'Tutorial complete. Your next opponent can be a real player.');snapshot(p) end
  local r=root(p.Character);local b=s.Bot and root(s.Bot)
  if r and b and d.Step>=4 then s.Bot:PivotTo(CFrame.new(math.clamp(r.Position.X+5,s.Arena.MinX+5,s.Arena.MaxX-5),3.3,s.Arena.LaneZ));b.AssemblyLinearVelocity=Vector3.zero end
 end
 tutorialState(p)
end
local function configure(m,p,lane)
 local r=root(m);local h=m and m:FindFirstChildOfClass('Humanoid');if not r or not h then return false end
 r.Size=Vector3.new(1.6,6.4,.9);r.Anchored=false;r.CanCollide=true;r.Massless=false
 r.CustomPhysicalProperties=PhysicalProperties.new(1,.15,0,1,1)
 local attachment=r:FindFirstChild('PlanarUprightAttachment') or Instance.new('Attachment');attachment.Name='PlanarUprightAttachment';attachment.Parent=r
 local upright=r:FindFirstChild('PlanarUpright') or Instance.new('AlignOrientation');upright.Name='PlanarUpright';upright.Mode=Enum.OrientationAlignmentMode.OneAttachment;upright.Attachment0=attachment;upright.CFrame=CFrame.identity;upright.MaxTorque=1e9;upright.Responsiveness=200;upright.RigidityEnabled=true;upright.Parent=r
 local plane=r:FindFirstChild('CombatLane') or Instance.new('AlignPosition');plane.Name='CombatLane';plane.Mode=Enum.PositionAlignmentMode.OneAttachment;plane.Attachment0=attachment;plane.Position=Vector3.new(0,0,lane or 0);plane.ForceLimitMode=Enum.ForceLimitMode.PerAxis;plane.MaxAxesForce=Vector3.new(0,0,1e7);plane.ApplyAtCenterOfMass=true;plane.Responsiveness=200;plane.RigidityEnabled=false;plane.Parent=r
 for _,v in ipairs(m:GetDescendants()) do
  if v:IsA('BasePart') then v.CollisionGroup='Countertones';v.CanTouch=false;if v~=r then v.CanCollide=false;v.Massless=true end
  elseif v:IsA('Decal') then v.Transparency=1 end
 end
 h.EvaluateStateMachine=false;h.PlatformStand=true;h.WalkSpeed=0;h.AutoRotate=false;h.HipHeight=0;h.UseJumpPower=true;h.JumpPower=0;h.BreakJointsOnDeath=false;h.RequiresNeck=false;h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
 h:SetStateEnabled(Enum.HumanoidStateType.Jumping,false);h:ChangeState(Enum.HumanoidStateType.Physics)
 pcall(function() r:SetNetworkOwner(p) end)
 return true
end
local function arenaState(p,s)
 send(p,'Mode',{Mode=s.Mode,Name=s.Arena.Name,Center=s.Arena.Center,MinX=s.Arena.MinX,MaxX=s.Arena.MaxX,LaneZ=s.Arena.LaneZ,FloorY=s.Arena.FloorY,MapIndex=s.Map,MatchStartsAt=s.StartsAt,MatchEndsAt=s.EndsAt,Objective=s.Mode=='Tutorial' and 'Learn the rhythm. Your progress is kept during this server session.' or 'Three stocks. Ring out your opponent.'})
end
local function destroyBot(s)
 if s.Bot then engine:Remove(s.Bot);bots[s.Bot]=nil;if s.Bot.Parent then s.Bot:Destroy() end;s.Bot=nil end
end
local function newRoom(mode,map,key)
 local a=World.GetArena(mode=='Crucible' and 'Crucible' or 'Tutorial',mode=='Crucible' and map or 1)
 local s={Id=Http:GenerateGUID(false),Key=key,Mode=mode,Map=map,Arena=a,Members={},Finished=false}
 rooms[key]=s;return s
end
local finish,leave,enterTutorial,startMatch
local function setupPlatforms(m,s)
 local previous=m:FindFirstChild('OneWayPlatforms');if previous then previous:Destroy() end
 local f=Instance.new('Folder');f.Name='OneWayPlatforms';f.Parent=m
 for _,part in ipairs(s.Arena.Model:GetDescendants()) do
  if part:IsA('BasePart') and part:GetAttribute('DropThrough') then
   local n=Instance.new('NoCollisionConstraint');n.Name='PassFromBelow';n.Part0=root(m);n.Part1=part;n.Enabled=true;n.Parent=f
  end
 end
end
local function updatePlatforms(m)
 local r=root(m);local f=m and m:FindFirstChild('OneWayPlatforms');if not r or not f then return end
 local feet=r.Position.Y-r.Size.Y*.5
 for _,n in ipairs(f:GetChildren()) do local p=n.Part1;if p then n.Enabled=feet<p.Position.Y+p.Size.Y*.5-.12 or r.AssemblyLinearVelocity.Y>1 end end
end
local function resetFighter(p,s,x)
 local m=p.Character;local r=root(m);if not r or not profiles[p] or not configure(m,p,s.Arena.LaneZ) then return end
 engine:Remove(m)
 local st=engine:Register(m,{Player=p,Weapon=profiles[p].Weapon,School='Ember',Team=s.Mode=='Crucible' and tostring(p.UserId) or 'Learner',Mode=s.Mode,Arena=s,Health=100000,Stocks=3})
 m:SetAttribute('ArenaId',s.Id);m:SetAttribute('Bot',false);m:SetAttribute('PixelPalette','Azure')
 m:PivotTo(CFrame.new(x or s.Arena.Center.X-20,3.3,s.Arena.LaneZ));r.AssemblyLinearVelocity=Vector3.zero;setupPlatforms(m,s)
 st.IFrameUntil=clock()+1.5;st.Facing=1
 if s.StartsAt then st.BusyUntil=s.StartsAt;st.StunUntil=s.StartsAt end
 sessions[p]=s;s.Members[p]=true;if traffic[p] then traffic[p].LastX=nil;traffic[p].MotionX=nil;traffic[p].MotionTime=nil end
 arenaState(p,s);snapshot(p)
end
local function makeBot(s,practice,p)
 local m=World.CreateFighter(practice and 'Sparring Echo [BOT]' or 'Parry Trainer [BOT]',Vector3.new(s.Arena.Center.X+18,3.3,s.Arena.LaneZ),Color3.fromRGB(196,112,117),1)
 m.Parent=workspace.PARABOUNDFighters;configure(m,nil,s.Arena.LaneZ)
 m:SetAttribute('ArenaId',s.Id);m:SetAttribute('Bot',true);m:SetAttribute('PixelPalette','Rose')
 local st=engine:Register(m,{Weapon='Longblade',School='Ember',Team='Echo',Mode=s.Mode,Arena=s,Health=100000,Stocks=3})
 st.Facing=-1;st.IFrameUntil=clock()+1.5
 if s.StartsAt then st.BusyUntil=s.StartsAt;st.StunUntil=s.StartsAt end
 bots[m]={Room=s,Owner=p,Practice=practice,NextAttack=clock()+2.2,NextDecision=clock()+2,Random=Random.new(),NextJump=0}
 s.Bot=m;setupPlatforms(m,s);return m
end
finish=function(s,winner,text)
 if s.Finished then return end;s.Finished=true
 for p in pairs(s.Members) do
  local d=profiles[p];local win=p==winner
  if d then
   if win then d.Wins+=1 else d.Losses+=1 end
   if not s.Practice and #s.Players==2 then
    local opponent=s.Players[1]==p and s.Players[2] or s.Players[1]
    local od=profiles[opponent];local expected=1/(1+10^(((od and od.Rating or 1000)-d.Rating)/400))
    d.Rating=math.max(0,d.Rating+math.floor(24*((win and 1 or 0)-expected)+.5))
   end
   snapshot(p)
  end
  local st=engine:Get(p.Character);if st then st.BusyUntil=clock()+60;st.StunUntil=clock()+60;st.Pending=nil;local r=root(p.Character);if r then r.AssemblyLinearVelocity=Vector3.zero;r.Anchored=true end end
  send(p,'Results',{Title=win and 'VICTORY' or 'ROUND COMPLETE',Text=(s.Practice and 'Explicit practice bot • rating unchanged. ' or 'Equalized player duel. ')..(text or 'Three stocks settled.'),Winner=winner and winner.DisplayName or s.Practice and 'Sparring Echo [BOT]' or 'Draw',Practice=s.Practice})
 end
 if s.Bot then local st=engine:Get(s.Bot);if st then st.BusyUntil=clock()+60;st.StunUntil=clock()+60;st.Pending=nil;local r=root(s.Bot);if r then r.AssemblyLinearVelocity=Vector3.zero;r.Anchored=true end end end
end
leave=function(p,forfeit)
 queue[p]=nil
 local s=sessions[p];if not s then return end
 if s.Mode=='Crucible' and not s.Finished and forfeit then local winner;for other in pairs(s.Members) do if other~=p then winner=other end end;finish(s,winner,'Opponent left the duel.') end
 s.Members[p]=nil;sessions[p]=nil
 if not next(s.Members) then destroyBot(s);rooms[s.Key]=nil end
end
enterTutorial=function(p,training)
 if not root(p.Character) then return end
 leave(p,true)
 local s=newRoom(training and 'Training' or 'Tutorial',1,'Court:'..p.UserId);s.Training=training
 resetFighter(p,s,-20);makeBot(s,false,p)
 if not training then tutorialState(p) else notice(p,'Free practice. Reset the echo any time; hold guard or practice your punish.') end
end
local function availableMap(preferred)
 for offset=0,2 do local i=((preferred or 1)-1+offset)%3+1;local s=rooms['Duel:'..i];if not s or s.Finished then return i end end
end
startMatch=function(players,map,practice)
 map=availableMap(map);if not map then return false end
 for _,p in ipairs(players) do leave(p,false) end
 local s=newRoom('Crucible',map,'Duel:'..map);s.Players=players;s.Practice=practice;s.StartsAt=clock()+2.5;s.EndsAt=s.StartsAt+180
 for i,p in ipairs(players) do resetFighter(p,s,i==1 and -20 or 20);engine:Get(p.Character).Facing=i==1 and 1 or -1;queue[p]=nil end
 if practice then makeBot(s,true,players[1]) end
 for p in pairs(s.Members) do notice(p,practice and 'Practice bot • three stocks • fight!' or 'Player duel • three stocks • fight!') end
 return true
end
local function knockout(m,s)
 local st=engine:Get(m);local r=root(m);if not st or not r or st.Dead or s.Finished then return end
 st.Stocks-=1;st.Pending=nil;st.BufferedAction=nil
 Net.Effect:FireAllClients('KO',{Model=m,Position=r.Position,ArenaId=s.Id})
 if st.Stocks<=0 then
  st.Dead=true;m:SetAttribute('Stocks',0)
  local loser=Players:GetPlayerFromCharacter(m);local winner
  for p in pairs(s.Members) do if p~=loser then winner=p end end
  finish(s,winner,'Ring-out.');return
 end
 local stocks=st.Stocks;engine:Reset(m);st.Stocks=stocks;st.Impact=0;st.IFrameUntil=clock()+1.5;st.BusyUntil=clock()+.5;st.StunUntil=clock()+.5;st.LaunchUntil=0
 m:PivotTo(CFrame.new(Players:GetPlayerFromCharacter(m) and -20 or 20,3.3,s.Arena.LaneZ));r.AssemblyLinearVelocity=Vector3.zero
 m:SetAttribute('Stocks',stocks);m:SetAttribute('Impact',0)
end
engine=Combat.new(function(kind,data)
 local m=data.Model or data.Target;local st=m and engine:Get(m)
 data.ArenaId=st and st.Arena and st.Arena.Id or nil
 if kind=='Startup' then kind='Tell' elseif kind=='ParrySuccess' then kind='Parry' elseif kind=='ArcanaHit' then kind='Hit' elseif kind=='Parry' and not data.Success then kind='ParryAttempt' end
 Net.Effect:FireAllClients(kind,data)
end,function(kind,a,t,data)
 local p=a and Players:GetPlayerFromCharacter(a)
 if kind=='Jump' and p then tutorialProgress(p,'Jump',1)
  elseif kind=='Hit' and p then tutorialProgress(p,'Hit',1)
 elseif (kind=='Parry' or kind=='PerfectParry') and p then tutorialProgress(p,kind,1) end
end)
World.Build();workspace.Gravity=150
local folder=workspace:FindFirstChild('PARABOUNDFighters');if folder then folder:Destroy() end
folder=Instance.new('Folder');folder.Name='PARABOUNDFighters';folder.Parent=workspace
pcall(function() Physics:RegisterCollisionGroup('Countertones') end);Physics:CollisionGroupSetCollidable('Countertones','Countertones',false)
Players.CharacterAutoLoads=false
local function joined(p)
 profiles[p]={Weapon='Longblade',Settings={CameraShake=true,ReducedFlashes=false,SFX=true,Music=true},Rating=1000,Wins=0,Losses=0,TutorialComplete=false,Step=1,Progress=0,PerfectSeen=false}
 p.CharacterAdded:Connect(function(m)
  local r=m:WaitForChild('HumanoidRootPart',10);local h=m:WaitForChild('Humanoid',10);if not r or not h then return end
  h.Died:Connect(function() task.delay(1.6,function() if p.Parent==Players and p.Character==m then engine:Remove(m);p:LoadCharacterAsync() end end) end)
  local old=sessions[p];if old and old.Mode=='Crucible' and not old.Finished then leave(p,true) end
  enterTutorial(p,false)
 end)
 p:LoadCharacterAsync()
end
Players.PlayerAdded:Connect(function(p) task.spawn(joined,p) end)
Players.PlayerRemoving:Connect(function(p) leave(p,true);engine:Remove(p.Character);profiles[p]=nil;traffic[p]=nil end)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(joined,p) end
local actions={Move=true,Light=true,Heavy=true,Jump=true,Dash=true,Parry=true,Guard=true,GuardEnd=true,FastFall=true,Drop=true,Feint=true,Arcana1=true,Breakfall=true}
local function handle(p,action,payload,stamp,seq,dev)
 if type(action)~='string' or #action>24 or (payload~=nil and type(payload)~='table') or not profiles[p] then return end
 payload=payload or {}
 if not dev then
  if type(seq)~='number' or seq~=seq or seq%1~=0 or seq<0 or seq>1e10 then return end
  local tr=traffic[p] or {Tokens=50,Time=clock(),Seq=-1};traffic[p]=tr
  tr.Tokens=math.min(50,tr.Tokens+(clock()-tr.Time)*30);tr.Time=clock()
  if seq<=tr.Seq or tr.Tokens<1 then return end;tr.Seq=seq;tr.Tokens-=1
 end
 if action=='Request' or action=='Ready' then snapshot(p);local s=sessions[p];if s then arenaState(p,s);tutorialState(p) end;return end
 if action=='Play' then
  local kind=payload.Kind
  if kind=='Tutorial' then profiles[p].Step=1;profiles[p].Progress=0;profiles[p].PerfectSeen=false;enterTutorial(p,false)
  elseif kind=='Training' then enterTutorial(p,true)
  elseif kind=='Practice' then if not startMatch({p},math.clamp(math.floor(tonumber(payload.Map) or 1),1,3),true) then notice(p,'All duel stages are occupied. Try again shortly.') end
  elseif kind=='Duel' then
   local s=sessions[p];if s and s.Mode=='Crucible' and not s.Finished then leave(p,true);enterTutorial(p,true) end
   queue[p]={At=clock(),Map=math.clamp(math.floor(tonumber(payload.Map) or 1),1,3)}
   send(p,'Queue',{Text='Waiting for a real player in this server. Practice bots never fill the player queue.'})
  end;return
 elseif action=='QueueCancel' then queue[p]=nil;notice(p,'Duel search canceled.');return
 elseif action=='Return' then enterTutorial(p,profiles[p].TutorialComplete);return
 elseif action=='Rematch' then
  local s=sessions[p];if not s or not s.Finished then return end
  if s.Practice then startMatch({p},s.Map,true)
  else s.Rematch=s.Rematch or {};s.Rematch[p]=true;local all=true;for _,other in ipairs(s.Players) do if other.Parent~=Players or sessions[other]~=s or not s.Rematch[other] then all=false end end;if all then startMatch(s.Players,s.Map,false) else notice(p,'Waiting for your opponent to rematch.') end end;return
 elseif action=='Equip' then
  local s=sessions[p];if s and s.Mode=='Crucible' and not s.Finished then notice(p,'Weapons lock for the duel.');return end
  if table.find(C.MainWeapons,payload.Weapon) then profiles[p].Weapon=payload.Weapon;engine:SetLoadout(p.Character,payload.Weapon,'Ember');snapshot(p) end;return
 elseif action=='Settings' then
  if ({CameraShake=true,ReducedFlashes=true,SFX=true,Music=true})[payload.Key] and type(payload.Value)=='boolean' then profiles[p].Settings[payload.Key]=payload.Value;snapshot(p) end;return
 elseif action=='ResetTraining' then
  local s=sessions[p];if s and s.Mode~='Crucible' then engine:Reset(p.Character);if s.Bot then engine:Reset(s.Bot);s.Bot:PivotTo(CFrame.new(root(p.Character).Position.X+5,3.3,s.Arena.LaneZ));root(s.Bot).AssemblyLinearVelocity=Vector3.zero end end;return
 end
 local s=sessions[p];if not s or s.Finished or not actions[action] then return end
 local st=engine:Get(p.Character);if not st or st.Dead then return end
 local time=type(stamp)=='number' and stamp==stamp and math.abs(stamp-clock())<1 and stamp or clock()
 payload.timestamp=time
 if action=='Move' then
  local v=payload.direction;local x=typeof(v)=='Vector3' and v.X or type(v)=='number' and v or nil
  if not x or x~=x or math.abs(x)>1 then return end;payload.direction=Vector3.new(x,0,0); if traffic[p] then traffic[p].Direction=x end
 end
 local accepted=engine:Intent(p.Character,action,payload)
 if not accepted and (action=='Jump' or action=='Dash') then send(p,'ActionRejected',{Action=action,JumpCount=st.JumpCount}) end
 if accepted and action=='Dash' then tutorialProgress(p,'Dash',1) end
end
Net.Intent.OnServerEvent:Connect(handle)
game:GetService('ProximityPromptService').PromptTriggered:Connect(function(prompt,p)
 local holder=prompt.Parent;local r=root(p.Character);local mode=prompt:GetAttribute('Mode')
 if r and holder:IsA('BasePart') and (r.Position-holder.Position).Magnitude<=12 and (mode=='Duel' or mode=='Practice') then handle(p,'Play',{Kind=mode,Map=prompt:GetAttribute('Index') or 1},clock(),0,true) end
end)
local slow=0
Run.Heartbeat:Connect(function(dt)
 dt=math.min(dt,.075);for m in pairs(bots) do updatePlatforms(m) end;engine:Step(dt);slow+=dt
 for p,s in pairs(sessions) do
  local r=root(p.Character);local st=engine:Get(p.Character)
  if r and st and not st.Dead then
   if math.abs(r.Position.Z-s.Arena.LaneZ)>2 then r.CFrame=CFrame.new(r.Position.X,r.Position.Y,s.Arena.LaneZ)*r.CFrame.Rotation;r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,r.AssemblyLinearVelocity.Y,0) end
   local tr=traffic[p] or {Tokens=50,Time=clock(),Seq=-1};traffic[p]=tr
   if s.Mode=='Tutorial' and profiles[p].Step==1 and tr.LastX and math.abs(tr.Direction or 0)>.1 then local delta=math.abs(r.Position.X-tr.LastX);if delta<2 then tutorialProgress(p,'Move',delta) end end
   tr.LastX=r.Position.X
   if not tr.MotionTime or clock()-tr.MotionTime>=.1 then
    local t=clock()
    if tr.MotionX and st.IFrameUntil<t then
     local velocity=st.ExpectedLaunchVelocity or Vector3.zero
     local speed=st.LaunchUntil>t and math.max(65,math.abs(velocity.X)+25) or st.DashUntil>t and 60 or 28
     local ok,ping=pcall(function()return p:GetNetworkPing()end);ping=ok and math.clamp(ping,0,.15) or .05
     local budget=speed*(t-tr.MotionTime+ping)+1.2
     if math.abs(r.Position.X-tr.MotionX)>budget then
      r.CFrame=CFrame.new(tr.MotionX,r.Position.Y,s.Arena.LaneZ);r.AssemblyLinearVelocity=Vector3.new(0,r.AssemblyLinearVelocity.Y,0)
      tr.Corrections=(tr.Corrections or 0)+1
     end
    end
    tr.MotionX=r.Position.X;tr.MotionTime=t
   end
   if s.Mode=='Crucible' then if r.Position.Y< -12 or r.Position.X<s.Arena.MinX-16 or r.Position.X>s.Arena.MaxX+16 then knockout(p.Character,s) end
   elseif r.Position.Y< -12 or math.abs(r.Position.X)>55 then p.Character:PivotTo(CFrame.new(-20,3.3,0));r.AssemblyLinearVelocity=Vector3.zero;tr.MotionX=nil;tr.MotionTime=nil;tr.LastX=nil;st.LaunchUntil=0;st.StunUntil=0;st.HitStopUntil=0;st.IFrameUntil=clock()+1.5 end
   if (s.Mode=='Tutorial' or s.Mode=='Training') and st.Health<50000 then st.Health=st.MaxHealth end
  end
 end
 for m,b in pairs(bots) do
  local s=b.Room;local st=engine:Get(m);local r=root(m);local target=b.Owner and b.Owner.Character;local tr=root(target)
  if st and r and tr and not st.Dead and not s.Finished then
   local t=clock();local dx=tr.Position.X-r.Position.X;local sign=dx>=0 and 1 or -1
   local isLesson=s.Mode=='Tutorial';local d=profiles[b.Owner];local active=b.Practice or s.Training or (isLesson and d and d.Step>=5)
   local positioning=active or (isLesson and d and d.Step==4)
   local speed=positioning and (math.abs(dx)>4.6 and sign*(active and 16 or 12) or 0) or 0
   if math.abs(dx)<2.7 and b.Practice then speed=-sign*7 end
   st.Facing=sign
   local blocked=t<(st.StunUntil or 0) or t<(st.HitStopUntil or 0) or t<(st.DashUntil or 0) or t<(st.LaunchUntil or 0)
   if not blocked then
    local vx=r.AssemblyLinearVelocity.X;local rate=math.abs(speed)>0 and 100 or 160
    local step=rate*dt;vx+=math.clamp(speed-vx,-step,step)
    r.AssemblyLinearVelocity=Vector3.new(vx,r.AssemblyLinearVelocity.Y,0)
   end
   if active and t>b.NextAttack and math.abs(dx)<6 and t>st.BusyUntil and (not s.StartsAt or t>s.StartsAt) then
    engine:Intent(m,(isLesson or b.Random:NextNumber()<.3) and 'Heavy' or 'Light',{direction=Vector3.new(sign,0,0)})
    b.NextAttack=t+(isLesson and 2.1 or b.Random:NextNumber(.65,1.25))
   end
   if b.Practice and t>b.NextDecision then
    b.NextDecision=t+.22;local ts=engine:Get(target)
    if ts and ts.Pending and t-ts.Pending.Started>.13 and math.abs(dx)<7 and b.Random:NextNumber()<.18 then engine:Intent(m,'Parry',{}) end
    if ts and ts.Airborne and not st.Airborne and math.abs(dx)<13 and t>b.NextJump and b.Random:NextNumber()<.2 then engine:Intent(m,'Jump',{});b.NextJump=t+2 end
   end
   if s.Mode=='Crucible' then if r.Position.Y< -12 or r.Position.X<s.Arena.MinX-16 or r.Position.X>s.Arena.MaxX+16 then knockout(m,s) end
   elseif r.Position.Y< -12 or math.abs(r.Position.X)>50 then m:PivotTo(CFrame.new(math.clamp(tr.Position.X+5,-35,35),3.3,0));r.AssemblyLinearVelocity=Vector3.zero end
  end
 end
 if slow>.35 then
  slow=0
  local candidates={};for p,q in pairs(queue) do if p.Parent==Players and root(p.Character) then table.insert(candidates,{Player=p,Data=q}) end end
  table.sort(candidates,function(a,b) return a.Data.At<b.Data.At end)
  if #candidates>=2 then startMatch({candidates[1].Player,candidates[2].Player},candidates[1].Data.Map,false) end
  for _,s in pairs(rooms) do if s.Mode=='Crucible' and not s.Finished and clock()>s.EndsAt then
   local best,bestScore
   for p in pairs(s.Members) do local st=engine:Get(p.Character);local score=st and st.Stocks*1000-st.Impact or -1;if not bestScore or score>bestScore then best=p;bestScore=score end end
   if s.Bot then local st=engine:Get(s.Bot);if st and st.Stocks*1000-st.Impact>(bestScore or -1) then best=nil end end
   finish(s,best,'Time limit.')
  end end
 end
end)
if Run:IsStudio() then
 local h=Instance.new('BindableFunction');h.Name='DevelopmentHarness';h.Parent=script.Parent
 h.OnInvoke=function(command)
  local p=command.PlayerName and Players:FindFirstChild(command.PlayerName) or Players:GetPlayers()[1]
  if command.Action=='Players' then local r={};for _,person in ipairs(Players:GetPlayers()) do local room=sessions[person];table.insert(r,{Name=person.Name,UserId=person.UserId,Mode=room and room.Mode,ArenaId=room and room.Id,Queued=queue[person]~=nil}) end;return r end
  if command.Action=='Inspect' then local s=p and sessions[p];local st=p and engine:Get(p.Character);return {Mode=s and s.Mode,Map=s and s.Map,State=st and {Stocks=st.Stocks,Impact=st.Impact,Health=st.Health,JumpCount=st.JumpCount},Profile=p and profiles[p],Movement=p and traffic[p] and {Direction=traffic[p].Direction,Corrections=traffic[p].Corrections},Bots=(function()local n=0 for _ in pairs(bots) do n+=1 end return n end)()} end
  if command.Action=='Place' and p then local r=root(p.Character);local st=engine:Get(p.Character);if r and st and typeof(command.Position)=='Vector3' then p.Character:PivotTo(CFrame.new(command.Position));r.AssemblyLinearVelocity=Vector3.zero;st.IFrameUntil=0;st.BusyUntil=0;st.StunUntil=0;st.LaunchUntil=0;if traffic[p] then traffic[p].MotionX=nil;traffic[p].MotionTime=nil end end;return true end
  if command.Action=='Intent' and p then handle(p,command.Name,command.Payload or {},clock(),0,true);return true end
  if command.Action=='TutorialStep' and p then profiles[p].Step=math.clamp(command.Step,1,7);profiles[p].Progress=0;tutorialState(p);return true end
  return false
 end
end
print('PARABOUND PvP • pixel fighters • focused duels and short tutorial')
