-- Offline regression checks for Combat.luau (run via tests/offline/run.sh). Deterministic clock, no physics:
-- positions only change when a check moves a root. Studio-only behavior stays in tests/CombatQA.luau.
local results, failures = {}, 0
local effects, events, impulses = {}, {}, {}
local function check(name, condition)
	table.insert(results, name)
	if condition then print("PASS  " .. name) else failures += 1; print("FAIL  " .. name) end
end

local floor = Instance.new("Part")
floor.Name = "Floor"; floor.Position = Vector3.new(0, 0, 0); floor.Size = Vector3.new(200, 1, 10); floor.Parent = workspaceRoot
table.insert(floors, floor)
local GROUND_Y = 0.5 + 3.2 -- floor top + half collider height

local function fighter(name, x)
	local m = Instance.new("Model"); m.Name = name
	local r = Instance.new("Part"); r.Name = "HumanoidRootPart"
	r.Size = Vector3.new(1.6, 6.4, .9); r.Position = Vector3.new(x, GROUND_Y, 0)
	r.AssemblyLinearVelocity = Vector3.zero; r.AssemblyAngularVelocity = Vector3.zero; r.Parent = m
	m.Parent = workspaceRoot
	return m, r
end

local engine = Combat.new(function(kind, data)
	table.insert(effects, kind); if kind == "Impulse" then table.insert(impulses, data) end
end, function(kind) table.insert(events, kind) end)
local arena = {}
local a, ar = fighter("A", 0)
local b, br = fighter("B", 5)
local sa = engine:Register(a, {Mode = "Training", Health = 500, Team = "A", Arena = arena})
local sb = engine:Register(b, {Mode = "Training", Health = 500, Team = "B", Arena = arena})

local function step(seconds)
	local frames = math.max(1, math.floor(seconds * 60 + .5))
	for _ = 1, frames do now += 1 / 60; engine:Step(1 / 60) end
end
local function reset()
	now += 5
	engine:Reset(a); engine:Reset(b); engine:SetLoadout(a, "Longblade", "Ember")
	ar.Position = Vector3.new(0, GROUND_Y, 0); br.Position = Vector3.new(5, GROUND_Y, 0)
	ar.AssemblyLinearVelocity = Vector3.zero; br.AssemblyLinearVelocity = Vector3.zero
	sa.Facing = 1; sb.Facing = -1; sb.Arena = arena; sb.Team = "B"
	table.clear(effects); table.clear(events); table.clear(impulses); engine:Step(0)
end
local function lastImpulse() return impulses[#impulses] end

-- Resource economy: light attacks are never resource-gated (F2).
reset(); sa.Resonance = 0
check("Light accepted at zero resonance", engine:Intent(a, "Light", {}) == true)
reset(); engine:Intent(a, "Heavy", {})
check("Heavy costs 10 resonance", math.abs(sa.Resonance - 90) < 1e-6)
reset(); sa.Resonance = 5
check("Heavy rejected below cost", engine:Intent(a, "Heavy", {}) == false)
reset(); engine:Intent(a, "Dash", {})
check("Dash costs 8 resonance", math.abs(sa.Resonance - 92) < 1e-6)
reset(); engine:Intent(a, "Arcana1", {})
check("Arcana keeps 24 cost (CombatQA parity)", math.abs(sa.Resonance - 76) < 1e-6)
reset(); sa.Resonance = 50; step(1)
check("Resonance regenerates ~6/s", math.abs(sa.Resonance - 56) < .2)

-- Baseline hit + isolation (regression parity with CombatQA).
reset(); engine:Intent(a, "Light", {}); step(.3)
check("Light hits target in front", sb.Health < 500)
reset(); sb.Arena = {}; engine:Intent(a, "Light", {}); step(.3)
check("Arena isolation holds", sb.Health == 500)

-- Facing commitment (F6): held movement during startup cannot swing the hitbox behind the attacker.
reset(); engine:Intent(a, "Light", {direction = Vector3.new(1, 0, 0)})
engine:Intent(a, "Move", {direction = Vector3.new(-1, 0, 0)})
check("Facing locked during attack startup", sa.Facing == 1)
step(.3)
check("Attack still lands forward after reverse input", sb.Health < 500)
engine:Intent(a, "Move", {direction = Vector3.new(-1, 0, 0)})
check("Facing turns once active frames end", sa.Facing == -1)

-- Parry/guard facing (F6): a retreating defender still parries the attacker in front.
reset(); sb.Facing = 1 -- defender was walking away from A
engine:Intent(a, "Light", {}); step(.05)
check("Parry accepted while retreating", engine:Intent(b, "Parry", {direction = Vector3.new(1, 0, 0)}) == true)
check("Parry faces nearest threat", sb.Facing == -1)
engine:Intent(b, "GuardEnd", {}); step(.25)
check("Retreating parry negates hit", sb.Health == 500 and (table.find(events, "Parry") ~= nil or table.find(events, "PerfectParry") ~= nil))
reset(); engine:Intent(b, "Guard", {}); engine:Intent(b, "Move", {direction = Vector3.new(1, 0, 0)})
check("Held guard keeps facing while backing off", sb.Facing == -1)

-- Invariant: tapping Parry retains its window.
reset(); engine:Intent(b, "Parry", {}); local deadline = sb.ParryUntil; engine:Intent(b, "GuardEnd", {})
check("Tap release keeps parry deadline", sb.ParryUntil == deadline and not sb.WantsGuard)
step(.6)
check("Released parry can be used again", engine:Intent(b, "Parry", {}) == true)

-- Jump contract and landing buffer (F7).
reset(); engine:Intent(a, "Jump", {}); engine:Intent(a, "Jump", {})
ar.Position = Vector3.new(0, 30, 0); ar.AssemblyLinearVelocity = Vector3.new(0, -5, 0); sa.GroundIgnoreUntil = 0
local before = #impulses
check("Third airborne jump still rejected", engine:Intent(a, "Jump", {}) == false)
check("Rejected landing jump is buffered", sa.JumpBufferedUntil > now)
ar.Position = Vector3.new(0, GROUND_Y, 0); ar.AssemblyLinearVelocity = Vector3.zero; step(1 / 60)
check("Buffered jump fires on landing", #impulses == before + 1 and lastImpulse().Action == "Jump" and lastImpulse().JumpCount == 1)
reset(); engine:Intent(a, "Jump", {}); engine:Intent(a, "Jump", {})
ar.Position = Vector3.new(0, 30, 0); sa.GroundIgnoreUntil = 0; engine:Intent(a, "Jump", {})
step(.3); ar.Position = Vector3.new(0, GROUND_Y, 0); ar.AssemblyLinearVelocity = Vector3.zero; before = #impulses; step(1 / 60)
check("Expired jump buffer does not fire", #impulses == before)

-- Freeze/restore provenance (F5).
reset(); ar.AssemblyLinearVelocity = Vector3.new(12, 18, 0); engine:_freeze(sa, .035); step(.08)
check("Self freeze restores with Resume flag", lastImpulse().Action == "Restore" and lastImpulse().Resume == true and lastImpulse().Velocity == Vector3.new(12, 18, 0))
reset(); engine:_freeze(sb, .04); engine:_launch(sa, sb, {Knockback = 28}); step(.08)
check("Launch during freeze restores authoritatively", lastImpulse().Action == "Restore" and lastImpulse().Resume == nil and lastImpulse().Velocity.X == 28)
reset(); engine:_launch(sb, sa, {Knockback = 28}); engine:_freeze(sa, .035); step(.08)
check("Launch then hit-stop restores authoritatively", lastImpulse().Action == "Restore" and lastImpulse().Resume == nil and lastImpulse().Velocity.X == -28)
local serials = true
for i = 2, #impulses do if impulses[i].Serial <= impulses[i - 1].Serial then serials = false end end
check("Impulse serials strictly increase", serials)

-- Speed allowance used by Bootstrap's movement validator (F1).
reset(); local t0 = now; engine:_impulse(sa, Vector3.new(100, 20, 0), "Launch")
check("Allowance holds through launch", engine:SpeedAllowance(sa, t0 + .3) == 125)
check("Allowance decays after launch hold", math.abs(engine:SpeedAllowance(sa, t0 + 1.35) - 55) < 1e-6)
check("Allowance floors at zero", engine:SpeedAllowance(sa, t0 + 10) == 0)
engine:_impulse(sa, Vector3.zero, "Freeze")
check("Freeze impulse does not erase allowance", engine:SpeedAllowance(sa, now) >= 125)

print(string.format("%d checks, %d failed", #results, failures))
if failures > 0 then error("offline combat checks failed") end
