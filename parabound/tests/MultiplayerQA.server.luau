-- Temporary Studio-only test driver. Install only while ExecuteMultiplayerTestAsync runs.
local Run=game:GetService('RunService')
if not Run:IsStudio() then return end
local Test=game:GetService('StudioTestService')
local args=Test:GetTestArgs()
if type(args)~='table' or args.PARABOUNDTest~='DuelFlow' then return end
local Players=game:GetService('Players')
local report={Checks={}}
local function check(name,value) table.insert(report.Checks,{Name=name,Passed=value});assert(value,name) end
local function await(condition,seconds)
 local untilTime=os.clock()+seconds
 repeat if condition() then return end;task.wait(.05) until os.clock()>untilTime
 error('Timed out waiting for test state')
end
task.spawn(function()
 local ok,err=pcall(function()
  await(function()return #Players:GetPlayers()==2 and game.ServerScriptService.PARABOUND:FindFirstChild('DevelopmentHarness') end,20)
  local h=game.ServerScriptService.PARABOUND.DevelopmentHarness
  local ps=Players:GetPlayers();table.sort(ps,function(a,b)return a.Name<b.Name end)
  for _,p in ipairs(ps) do await(function()return p.Character and p.Character:FindFirstChild('HumanoidRootPart') and p.Character:GetAttribute('ArenaId') end,15) end
  check('Two real simulated Player clients',#ps==2)
  local before=h:Invoke({Action='Players'})
  check('Tutorial rooms isolated',before[1].ArenaId~=before[2].ArenaId)
  for _,p in ipairs(ps) do h:Invoke({Action='Intent',PlayerName=p.Name,Name='Play',Payload={Kind='Duel',Map=2}}) end
  await(function()local rows=h:Invoke({Action='Players'});return rows[1].Mode=='Crucible' and rows[2].Mode=='Crucible' and rows[1].ArenaId==rows[2].ArenaId end,5)
  check('Real player queue pairs both clients',true)
  check('Duel contains no bot',h:Invoke({Action='Inspect',PlayerName=ps[1].Name}).Bots==0)
  task.wait(2.8)
  local lane=ps[1].Character.HumanoidRootPart.Position.Z
  h:Invoke({Action='Place',PlayerName=ps[1].Name,Position=Vector3.new(-3,3.3,lane)})
  h:Invoke({Action='Place',PlayerName=ps[2].Name,Position=Vector3.new(3,3.3,lane)})
  h:Invoke({Action='Intent',PlayerName=ps[1].Name,Name='Move',Payload={direction=1}})
  h:Invoke({Action='Intent',PlayerName=ps[2].Name,Name='Move',Payload={direction=-1}})
  h:Invoke({Action='Intent',PlayerName=ps[1].Name,Name='Light'})
  task.wait(.28)
  check('Server hit raises real opponent Impact',(ps[2].Character:GetAttribute('Impact') or 0)>0)
  task.wait(.35)
  h:Invoke({Action='Place',PlayerName=ps[1].Name,Position=Vector3.new(-3,3.3,lane)})
  h:Invoke({Action='Place',PlayerName=ps[2].Name,Position=Vector3.new(3,3.3,lane)})
  local impact=ps[2].Character:GetAttribute('Impact')
  h:Invoke({Action='Intent',PlayerName=ps[1].Name,Name='Light'})
  task.wait(.12)
  h:Invoke({Action='Intent',PlayerName=ps[2].Name,Name='Parry'})
  task.wait(.16)
  check('Real opponent parry prevents added Impact',(ps[2].Character:GetAttribute('Impact') or 0)<=impact+.01)
  for stock=1,3 do
   h:Invoke({Action='Place',PlayerName=ps[2].Name,Position=Vector3.new(90,3.3,lane)})
   task.wait(.18)
   check('Stock loss '..stock,(ps[2].Character:GetAttribute('Stocks') or -1)==3-stock)
  end
  local winner=h:Invoke({Action='Inspect',PlayerName=ps[1].Name})
  check('Human duel winner recorded',winner.Profile.Wins==1 and winner.Profile.Rating>1000)
  h:Invoke({Action='Intent',PlayerName=ps[1].Name,Name='Rematch'})
  h:Invoke({Action='Intent',PlayerName=ps[2].Name,Name='Rematch'})
  task.wait(.2)
  check('Mutual rematch restores three stocks',ps[1].Character:GetAttribute('Stocks')==3 and ps[2].Character:GetAttribute('Stocks')==3)
  report.Players={ps[1].Name,ps[2].Name};report.Success=true
 end)
 if not ok then report.Success=false;report.Error=tostring(err) end
 Test:EndTest(report)
end)
