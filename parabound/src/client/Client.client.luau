-- PARABOUND: compact PvP presentation. Damage, timing and match results belong to the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local World = game:GetService("Workspace")
local player = Players.LocalPlayer
local package = RS:WaitForChild("PARABOUND")
local Content = require(package:WaitForChild("Content"))
local net = package:WaitForChild("Net")
local sequence = 0
local profile = {Settings = {}, Weapon = "Longblade"}
local arena, tutorial, queueText, result = nil, nil, nil, nil
local GOLD = Color3.fromRGB(218, 183, 107)
local CREAM = Color3.fromRGB(243, 235, 212)
local MUTED = Color3.fromRGB(157, 161, 158)
local INK = Color3.fromRGB(18, 21, 26)
local PANEL = Color3.fromRGB(28, 32, 38)
local BORDER = Color3.fromRGB(67, 72, 78)
local touch = UIS.TouchEnabled
local function gamepadInputType(inputType)
 return string.sub(inputType.Name, 1, 7) == "Gamepad"
end
local preferredGamepad = gamepadInputType(UIS:GetLastInputType()) or (UIS.GamepadEnabled and not UIS.KeyboardEnabled)
UIS.LastInputTypeChanged:Connect(function(inputType)
 if gamepadInputType(inputType) then preferredGamepad = true
 elseif inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseButton2 or inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then preferredGamepad = false end
end)
local menuOpen, menuPage = false, "Play"
local heldLeft, heldRight, stickX, guarding = false, false, 0, false
local idleHoldX = nil
local predictedJumps, lastJumpPrediction, nextDashPrediction = 0, -math.huge, 0
local localDashUntil, packetDashUntil, packetLaunchUntil, packetHitStopUntil = 0, 0, 0, 0
local groundStableFor, localInputBusyUntil, lastImpulseSerial, impulseEpoch = 0, 0, 0, -math.huge
local predictions = {Jump = {}, Dash = {}}
local function resetMotionPrediction()
 predictedJumps, lastJumpPrediction, nextDashPrediction = 0, -math.huge, 0
 localDashUntil, packetDashUntil, packetLaunchUntil, packetHitStopUntil = 0, 0, 0, 0
 groundStableFor, localInputBusyUntil, lastImpulseSerial = 0, 0, 0
 impulseEpoch = World:GetServerTimeNow()
 predictions = {Jump = {}, Dash = {}}
end
local mapIndex = 1
local function send(action, payload)
 sequence += 1
 net.Intent:FireServer(action, payload or {}, World:GetServerTimeNow(), sequence)
end
local function setting(key)
 local value = (profile.Settings or {})[key]
 if value ~= nil then return value end
 return key == "SFX" or key == "CameraShake"
end
pcall(function()
 local starter = game:GetService("StarterGui")
 starter:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
 starter:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)
local gui = Instance.new("ScreenGui")
gui.Name = "ParaboundClient"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local function frame(parent, size, position, color)
 local f = Instance.new("Frame")
 f.Size = size; f.Position = position or UDim2.new(); f.BackgroundColor3 = color or PANEL
 f.BorderSizePixel = 0; f.Parent = parent
 return f
end
local function outline(obj, color)
 local s = Instance.new("UIStroke"); s.Thickness = 2; s.Color = color or BORDER; s.Parent = obj
end
local function label(parent, text, size, color)
 local l = Instance.new("TextLabel")
 l.BackgroundTransparency = 1; l.Text = text; l.TextSize = size or 14
 l.Font = Enum.Font.GothamMedium; l.TextColor3 = color or CREAM
 l.TextXAlignment = Enum.TextXAlignment.Left; l.TextYAlignment = Enum.TextYAlignment.Center
 l.TextWrapped = true; l.BorderSizePixel = 0; l.Parent = parent
 return l
end
local function button(parent, text, callback, accent)
 local b = Instance.new("TextButton")
 b.BackgroundColor3 = accent and GOLD or PANEL; b.TextColor3 = accent and INK or CREAM
 b.BorderSizePixel = 0; b.Text = text; b.TextSize = 13; b.Font = Enum.Font.GothamBold
 b.AutoButtonColor = true; b.Selectable = true; b.Parent = parent
 outline(b, accent and GOLD or BORDER)
 b.Activated:Connect(callback)
 return b
end
local function releaseGuard()
 if guarding then guarding = false; send("GuardEnd") end
end
local function clearInput()
 heldLeft, heldRight, stickX = false, false, 0
 idleHoldX = nil
 releaseGuard()
 send("Move", {direction = 0})
end
local function play(kind)
 releaseGuard(); result = nil; menuOpen = false
 send("Play", {Kind = kind, Map = mapIndex})
end

-- Two fighter cards keep the middle of the arena clear.
local hud = frame(gui, UDim2.new(1, -28, 0, 76), UDim2.fromOffset(14, 64), INK)
hud.BackgroundTransparency = 1
local function fighterCard(side)
 local c = frame(hud, UDim2.new(.26, 0, 0, 70), UDim2.new(side == "right" and 1 or 0, 0, 0, 0), INK)
 if side == "right" then c.AnchorPoint = Vector2.new(1, 0) end
 outline(c)
 local n = label(c, side == "left" and "YOU" or "RIVAL", 12, GOLD)
 n.Position = UDim2.fromOffset(10, 5); n.Size = UDim2.new(1, -20, 0, 19)
 n.TextWrapped = false; n.TextTruncate = Enum.TextTruncate.AtEnd
 local impact = label(c, "0%", 25, CREAM)
 impact.Position = UDim2.fromOffset(10, 24); impact.Size = UDim2.new(.60, -10, 0, 30)
 local stock = label(c, "◆ ◆ ◆", 13, GOLD)
 stock.TextXAlignment = Enum.TextXAlignment.Right; stock.Position = UDim2.new(.6, 0, 0, 24); stock.Size = UDim2.new(.4, -10, 0, 24)
 local track = frame(c, UDim2.new(1, -20, 0, 4), UDim2.fromOffset(10, 58), BORDER)
 local fill = frame(track, UDim2.fromScale(1, 1), nil, GOLD)
 return {Frame = c, Name = n, Impact = impact, Stocks = stock, Guard = fill}
end
local ownCard, rivalCard = fighterCard("left"), fighterCard("right")
local mapTitle = label(hud, "PARABOUND", 12, CREAM)
mapTitle.TextXAlignment = Enum.TextXAlignment.Center; mapTitle.TextWrapped = false; mapTitle.TextTruncate = Enum.TextTruncate.AtEnd
mapTitle.Position = UDim2.new(.29, 0, 0, 7); mapTitle.Size = UDim2.new(.42, 0, 0, 20)
local clockText = label(hud, "SHORT TUTORIAL", 11, GOLD)
clockText.TextXAlignment = Enum.TextXAlignment.Center
clockText.Position = UDim2.new(.29, 0, 0, 29); clockText.Size = UDim2.new(.42, 0, 0, 20)
local abilityText = label(gui, "E · RESONANCE CUT", 12, GOLD)
abilityText.TextXAlignment = Enum.TextXAlignment.Center; abilityText.AnchorPoint = Vector2.new(.5, 1)
abilityText.Position = UDim2.new(.5, 0, 1, -43); abilityText.Size = UDim2.fromOffset(240, 22)
if touch then
 abilityText.AnchorPoint = Vector2.new(.5, 0); abilityText.Position = UDim2.new(.5, 0, 0, 51)
 abilityText.Size = UDim2.new(.42, -10, 0, 17); abilityText.TextSize = 9
end
local help = label(gui, "A / D  MOVE    SPACE  JUMP    J / K  ATTACK    F  PARRY    Q  DASH    E  SURGE    G  FEINT    M  MENU", 15, CREAM)
help.AnchorPoint = Vector2.new(.5, 1); help.Position = UDim2.new(.5, 0, 1, -13)
help.Size = UDim2.new(1, -26, 0, 24); help.BackgroundColor3 = INK; help.BackgroundTransparency = .18; help.TextWrapped = false; help.TextTruncate = Enum.TextTruncate.AtEnd; help.TextXAlignment = Enum.TextXAlignment.Center; help.Visible = not touch

local tutorialPanel = frame(gui, UDim2.fromOffset(280, 151), UDim2.fromOffset(14, 154), INK)
outline(tutorialPanel)
local tutorialTitle = label(tutorialPanel, "01 / GET YOUR FOOTING", 12, GOLD)
tutorialTitle.Position = UDim2.fromOffset(12, 8); tutorialTitle.Size = UDim2.new(1, -24, 0, 21)
local tutorialText = label(tutorialPanel, "Move with A / D or the left stick. Jump with Space or A.", 12)
tutorialText.Position = UDim2.fromOffset(12, 33); tutorialText.Size = UDim2.new(1, -24, 0, 49)
local progressText = label(tutorialPanel, "A short introduction. You can leave at any time.", 10, MUTED)
progressText.Position = UDim2.fromOffset(12, 84); progressText.Size = UDim2.new(1, -24, 0, 18)
local progressTrack = frame(tutorialPanel, UDim2.new(1, -24, 0, 3), UDim2.fromOffset(12, 108), BORDER)
local progressFill = frame(progressTrack, UDim2.fromScale(0, 1), nil, GOLD)
local practiceSkip = button(tutorialPanel, "PRACTICE BOT", function() play("Practice") end)
practiceSkip.Position = UDim2.fromOffset(12, 120); practiceSkip.Size = UDim2.new(.5, -18, 0, 23)
local duelSkip = button(tutorialPanel, "FIND DUEL", function() play("Duel") end)
duelSkip.Position = UDim2.new(.5, 6, 0, 120); duelSkip.Size = UDim2.new(.5, -18, 0, 23)
tutorialPanel.Visible = false

local queuePanel = frame(gui, UDim2.fromOffset(330, 78), UDim2.new(.5, 0, 0, 154), INK)
queuePanel.AnchorPoint = Vector2.new(.5, 0); outline(queuePanel, GOLD); queuePanel.Visible = false
local queueLabel = label(queuePanel, "Finding another player…", 12)
queueLabel.Position = UDim2.fromOffset(12, 8); queueLabel.Size = UDim2.new(1, -24, 0, 24)
local cancelQueue = button(queuePanel, "CANCEL SEARCH", function() send("QueueCancel"); queueText = nil end)
cancelQueue.Position = UDim2.fromOffset(12, 41); cancelQueue.Size = UDim2.new(1, -24, 0, 26)

local menu = frame(gui, UDim2.new(.9, 0, .76, 0), UDim2.fromScale(.5, .5), INK)
menu.AnchorPoint = Vector2.new(.5, .5); outline(menu, GOLD); menu.Visible = false
local constraint = Instance.new("UISizeConstraint"); constraint.MaxSize = Vector2.new(480, 510); constraint.Parent = menu
local menuTitle = label(menu, "P / PARABOUND", 24, GOLD)
menuTitle.Font = Enum.Font.GothamBold; menuTitle.Position = UDim2.fromOffset(20, 14); menuTitle.Size = UDim2.new(1, -80, 0, 34)
local menuSubtitle = label(menu, "A duel. Three stocks. Find your rhythm.", 12, MUTED)
menuSubtitle.Position = UDim2.fromOffset(20, 48); menuSubtitle.Size = UDim2.new(1, -40, 0, 24)
local menuBody = Instance.new("ScrollingFrame")
menuBody.BackgroundTransparency = 1; menuBody.BorderSizePixel = 0
menuBody.Position = UDim2.fromOffset(20, 116); menuBody.Size = UDim2.new(1, -40, 1, -136)
menuBody.CanvasSize = UDim2.new(); menuBody.AutomaticCanvasSize = Enum.AutomaticSize.Y
menuBody.ScrollBarThickness = 3; menuBody.ScrollingDirection = Enum.ScrollingDirection.Y; menuBody.Parent = menu
local firstButton = nil
local renderMenu, setMenu
local close = button(menu, "×", function() setMenu(false) end)
close.Position = UDim2.new(1, -48, 0, 17); close.Size = UDim2.fromOffset(28, 28)
for i, page in ipairs({"Play", "Loadout", "Settings"}) do
 local b = button(menu, page:upper(), function() menuPage = page; renderMenu() end)
 b.Position = UDim2.new((i - 1) / 3, 20 - (i - 1) * 13.333, 0, 82)
 b.Size = UDim2.new(1 / 3, -18, 0, 26)
end
local weaponDetails = {
 Longblade = "Balanced reach · quick recovery",
 TwinFangs = "Close range · rapid pressure",
 Spear = "Long reach · careful spacing",
 Greatblade = "Slow commitment · strong knockback",
}
local music = Instance.new("Sound")
music.Name = "ParaboundMusic"; music.Looped = true; music.Volume = 0
music.SoundId = Content.Audio and Content.Audio.Music and "rbxassetid://" .. tostring(Content.Audio.Music) or ""
music.Parent = SoundService
local function applySettings()
 for _, key in ipairs({"CameraShake", "ReducedFlashes", "SFX", "Music"}) do player:SetAttribute("Parabound" .. key, setting(key)) end
 music.Volume = setting("Music") and .05 or 0
 if setting("Music") and music.SoundId ~= "" and not music.IsPlaying then music:Play() end
end
renderMenu = function()
 for _, child in ipairs(menuBody:GetChildren()) do child:Destroy() end
 firstButton = nil
 local y = 2
 local function row(text, callback, accent, height)
  local b = button(menuBody, text, callback, accent)
  b.Position = UDim2.fromOffset(2, y); b.Size = UDim2.new(1, -7, 0, height or 42)
  y += (height or 42) + 12
  if not firstButton then firstButton = b end
  return b
 end
 if menuPage == "Play" then
  row("FIND DUEL  ·  another player", function() play("Duel"); setMenu(false) end, true, 46)
  row("PRACTICE BOT  ·  computer opponent", function() play("Practice"); setMenu(false) end)
  row("SHORT TUTORIAL  ·  learn the basics", function() play("Tutorial"); setMenu(false) end)
  row("TRAINING COURT  ·  free practice", function() play("Training"); setMenu(false) end)
  local mapName = (Content.Maps or {})[mapIndex]
  if type(mapName) == "table" then mapName = mapName.Name end
  row("COURT  " .. mapIndex .. " / 3  ·  " .. tostring(mapName or "Practice court"), function()
   mapIndex = mapIndex % 3 + 1; renderMenu()
  end)
  if queueText then row("CANCEL DUEL SEARCH", function() send("QueueCancel"); queueText = nil; renderMenu() end) end
  if arena and arena.Mode == "Training" then row("RESET TRAINING", function() send("ResetTraining"); setMenu(false) end) end
 elseif menuPage == "Loadout" then
  for _, weapon in ipairs({"Longblade", "TwinFangs", "Spear", "Greatblade"}) do
   row((profile.Weapon == weapon and "[ EQUIPPED ]  " or "") .. weapon .. "\n" .. weaponDetails[weapon], function()
    send("Equip", {Weapon = weapon})
   end, profile.Weapon == weapon, 56)
  end
 else
  local names = {CameraShake = "Small camera shake", ReducedFlashes = "Reduced flashes", SFX = "Combat sounds", Music = "Quiet background music"}
  for _, key in ipairs({"CameraShake", "ReducedFlashes", "SFX", "Music"}) do
   row(names[key] .. "  /  " .. (setting(key) and "ON" or "OFF"), function()
    profile.Settings = profile.Settings or {}; profile.Settings[key] = not setting(key)
    send("Settings", {Key = key, Value = profile.Settings[key]}); applySettings(); renderMenu()
   end, setting(key))
  end
 end
 local spacer = frame(menuBody, UDim2.fromOffset(1, 1), UDim2.fromOffset(0, y), INK); spacer.BackgroundTransparency = 1
 if menuOpen and UIS.GamepadEnabled then GuiService.SelectedObject = firstButton end
end
setMenu = function(open)
 menuOpen = open; menu.Visible = open
 if open then clearInput(); renderMenu() else GuiService.SelectedObject = nil end
end
local menuButton = button(gui, "MENU [M]", function() setMenu(not menuOpen) end)
menuButton.AnchorPoint = Vector2.new(.5, 0); menuButton.Position = UDim2.new(.5, 0, 0, 116)
menuButton.Size = UDim2.fromOffset(92, 24)

local resultsPanel = frame(gui, UDim2.new(.84, 0, 0, 210), UDim2.fromScale(.5, .5), INK)
resultsPanel.AnchorPoint = Vector2.new(.5, .5); outline(resultsPanel, GOLD); resultsPanel.Visible = false
local resultConstraint = Instance.new("UISizeConstraint"); resultConstraint.MaxSize = Vector2.new(440, 210); resultConstraint.Parent = resultsPanel
local resultTitle = label(resultsPanel, "DUEL COMPLETE", 23, GOLD)
resultTitle.Position = UDim2.fromOffset(20, 18); resultTitle.Size = UDim2.new(1, -40, 0, 35)
local resultText = label(resultsPanel, "", 14)
resultText.Position = UDim2.fromOffset(20, 64); resultText.Size = UDim2.new(1, -40, 0, 68)
local rematch = button(resultsPanel, "REMATCH", function() result = nil; resultsPanel.Visible = false; send("Rematch") end, true)
rematch.Position = UDim2.new(0, 20, 1, -58); rematch.Size = UDim2.new(.5, -26, 0, 38)
local returnButton = button(resultsPanel, "RETURN TO COURT", function() result = nil; resultsPanel.Visible = false; send("Return") end)
returnButton.Position = UDim2.new(.5, 6, 1, -58); returnButton.Size = UDim2.new(.5, -26, 0, 38)
local notice = label(gui, "", 12, CREAM)
notice.BackgroundColor3 = INK; notice.BackgroundTransparency = .1; notice.TextXAlignment = Enum.TextXAlignment.Center
notice.AnchorPoint = Vector2.new(.5, 0); notice.Position = UDim2.new(.5, 0, 0, 191)
notice.Size = UDim2.new(.66, 0, 0, 32); notice.Visible = false
local noticeSerial = 0
local function toast(text)
 noticeSerial += 1; local serial = noticeSerial
 notice.Text = tostring(text); notice.Visible = true
 task.delay(3.5, function() if serial == noticeSerial then notice.Visible = false end end)
end

-- Deliberate CAS bindings support pads even when Roblox marks gamepad input processed.
local function direction()
 local d = (heldRight and 1 or 0) - (heldLeft and 1 or 0)
 if d == 0 then d = stickX end
 if menuOpen or result then return 0 end
 return d
end
local function predictMotion(action)
 if action ~= "Jump" and action ~= "Dash" then return end
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not root or root.Anchored or character:GetAttribute("Dead") then return end
 local now = World:GetServerTimeNow()
 for _, key in ipairs({"StunUntil", "HitStopUntil", "AttackUntil", "ParryUntil"}) do
  if (tonumber(character:GetAttribute(key)) or 0) > now then return end
 end
 if now < localInputBusyUntil or now < packetHitStopUntil or now < packetLaunchUntil or now < localDashUntil or now < packetDashUntil then return end
 if (tonumber(character:GetAttribute("CD_Attack")) or 0) > .01 or (tonumber(character:GetAttribute("CD_Parry")) or 0) > .01 then return end
 local velocity = root.AssemblyLinearVelocity
 if action == "Jump" then
  if predictedJumps >= 2 or now - lastJumpPrediction < .06 then return end
  predictedJumps += 1; lastJumpPrediction = now; groundStableFor = 0
  table.insert(predictions.Jump, {At = now, Count = predictedJumps, Before = velocity})
  root.AssemblyLinearVelocity = Vector3.new(velocity.X, 44, 0)
 else
  if now < nextDashPrediction or (tonumber(character:GetAttribute("CD_Dash")) or 0) > .01 or (tonumber(character:GetAttribute("Resonance")) or 100) < 8 then return end
  local dir = direction()
  local facing = dir ~= 0 and math.sign(dir) or (tonumber(character:GetAttribute("Facing")) or 1)
  localDashUntil = now + .16; nextDashPrediction = now + .65
  table.insert(predictions.Dash, {At = now, Before = velocity})
  root.AssemblyLinearVelocity = Vector3.new(facing * 44, velocity.Y, 0)
 end
 idleHoldX = nil
end
local function combat(action, down)
 if action == "Parry" and not down then releaseGuard(); return end
 if not down or menuOpen or result or UIS:GetFocusedTextBox() then return end
 if action == "Parry" then guarding = true end
 predictMotion(action)
 if action == "Light" or action == "Heavy" or action == "Arcana1" then localInputBusyUntil = World:GetServerTimeNow() + .12
 elseif action == "Parry" then localInputBusyUntil = World:GetServerTimeNow() + .34
 elseif action == "Feint" then localInputBusyUntil = World:GetServerTimeNow() + .08 end
 send(action, {direction = direction()})
end
local bindings = {}
local function bind(name, keys, callback)
 local fullName = "PB_" .. name; table.insert(bindings, fullName)
 CAS:BindActionAtPriority(fullName, function(_, state, input)
  if input then
   local key = input.KeyCode.Name
   if gamepadInputType(input.UserInputType) or string.sub(key, 1, 6) == "Button" or string.sub(key, 1, 4) == "DPad" or string.sub(key, 1, 10) == "Thumbstick" then preferredGamepad = true
   elseif input.UserInputType == Enum.UserInputType.Keyboard then preferredGamepad = false end
  end
  local down = state == Enum.UserInputState.Begin
  local ended = state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel
  if down or ended then callback(down) end
  return menuOpen and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
 end, false, 3000, table.unpack(keys))
end
bind("Left", {Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft}, function(down) heldLeft = down and not menuOpen end)
bind("Right", {Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight}, function(down) heldRight = down and not menuOpen end)
local actions = {
 {"Jump", Enum.KeyCode.Space, Enum.KeyCode.ButtonA}, {"Light", Enum.KeyCode.J, Enum.KeyCode.ButtonX},
 {"Heavy", Enum.KeyCode.K, Enum.KeyCode.ButtonY}, {"Dash", Enum.KeyCode.Q, Enum.KeyCode.ButtonB},
 {"Parry", Enum.KeyCode.F, Enum.KeyCode.ButtonL2}, {"Arcana1", Enum.KeyCode.E, Enum.KeyCode.ButtonR2},
 {"Feint", Enum.KeyCode.G, Enum.KeyCode.ButtonL1},
}
for _, item in ipairs(actions) do bind(item[1], {item[2], item[3]}, function(down) combat(item[1], down) end) end
bind("Down", {Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.DPadDown}, function(down)
 if down and not menuOpen and not result then send("Drop"); send("FastFall") end
end)
bind("Menu", {Enum.KeyCode.M, Enum.KeyCode.ButtonSelect}, function(down) if down then setMenu(not menuOpen) end end)
UIS.InputChanged:Connect(function(input)
 if input.KeyCode == Enum.KeyCode.Thumbstick1 then
  preferredGamepad = true
  local x = input.Position.X; stickX = math.abs(x) > .18 and math.sign(x) * (math.abs(x) - .18) / .82 or 0
 end
end)
UIS.InputBegan:Connect(function(input, processed)
 if processed or UIS:GetFocusedTextBox() then return end
 if input.UserInputType == Enum.UserInputType.MouseButton1 then combat("Light", true)
 elseif input.UserInputType == Enum.UserInputType.MouseButton2 then combat("Heavy", true) end
end)
UIS.WindowFocusReleased:Connect(clearInput)

-- Every touch action has an explicit release path, including a finger lifted outside its button.
local touchPad = frame(gui, UDim2.fromScale(1, 1), nil, INK)
touchPad.Name = "TouchControls"; touchPad.BackgroundTransparency = 1; touchPad.Visible = touch
local pointers = {}
local touchButtons = {}
local function touchButton(name, x, y, callback)
 local b = button(touchPad, name, function() end)
 b.Name = "Touch_" .. name
 b.Size = UDim2.fromOffset(52, 49); b.Position = UDim2.new(x < 0 and 1 or 0, x, 1, y)
 b.TextSize = 10
 b.InputBegan:Connect(function(input)
  if input.UserInputType ~= Enum.UserInputType.Touch or menuOpen or result then return end
  if pointers[input] then return end
  pointers[input] = callback; callback(true)
 end)
 touchButtons[name] = b
 return b
end
UIS.InputEnded:Connect(function(input)
 local callback = pointers[input]
 if callback then pointers[input] = nil; callback(false) end
 if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonL2 then releaseGuard() end
end)
touchButton("LEFT", 16, -74, function(down) heldLeft = down end)
touchButton("RIGHT", 77, -74, function(down) heldRight = down end)
touchButton("JUMP", 16, -132, function(down) combat("Jump", down) end)
touchButton("DOWN", 77, -132, function(down) if down and not menuOpen then send("Drop"); send("FastFall") end end)
touchButton("LIGHT", -190, -132, function(down) combat("Light", down) end)
touchButton("HEAVY", -129, -132, function(down) combat("Heavy", down) end)
touchButton("DASH", -68, -132, function(down) combat("Dash", down) end)
touchButton("PARRY", -190, -74, function(down) combat("Parry", down) end)
touchButton("SURGE", -129, -74, function(down) combat("Arcana1", down) end)
touchButton("FEINT", -68, -74, function(down) combat("Feint", down) end)
-- Native character controls must not add a second movement vector.
task.spawn(function()
 local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
 if not module then return end
 local ok, pm = pcall(require, module)
 if ok and pm.GetControls then pm:GetControls():Disable() end
end)

local cameraSnap = true
net.State.OnClientEvent:Connect(function(kind, data)
 data = type(data) == "table" and data or {}
 if kind == "Snapshot" then
  profile = data; profile.Settings = profile.Settings or {}; applySettings()
  if menuOpen then renderMenu() end
 elseif kind == "Mode" then
  resetMotionPrediction()
  arena = data; cameraSnap = true; menuOpen = false; menu.Visible = false; GuiService.SelectedObject = nil
  result = nil; resultsPanel.Visible = false
  if data.Mode ~= "Queue" then queueText = nil; queuePanel.Visible = false end
  if data.Mode ~= "Tutorial" then tutorial = nil; tutorialPanel.Visible = false end
  clearInput()
 elseif kind == "Tutorial" then
  tutorial = data
  tutorialTitle.Text = (data.Complete and "COMPLETE / " or string.format("%02d / ", tonumber(data.Step) or 1)) .. tostring(data.Title or "YOUR NEXT MOVE")
  tutorialText.Text = tostring(data.Text or "")
  local progress, target = tonumber(data.Progress) or 0, math.max(1, tonumber(data.Target) or 1)
  local displayed = math.min(progress, target)
  local progressNumber = target > 6 and string.format("%.1f", displayed) or tostring(math.floor(displayed))
  progressText.Text = data.Complete and "Ready for a rival? Find a duel or practice with a bot." or (progressNumber .. " / " .. tostring(target) .. "  ·  One move at a time")
  progressFill.Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1)
 elseif kind == "Queue" then
  queueText = data.Text or "Finding another player…"; queueLabel.Text = queueText
  menuOpen = false; menu.Visible = false; GuiService.SelectedObject = nil; clearInput()
 elseif kind == "Results" then
  result = data; clearInput(); releaseGuard(); menuOpen = false; menu.Visible = false
  resultTitle.Text = tostring(data.Title or "DUEL COMPLETE"); resultText.Text = tostring(data.Text or "")
  resultsPanel.Visible = true
  if UIS.GamepadEnabled then GuiService.SelectedObject = rematch end
 elseif kind == "ActionRejected" then
  local action = data.Action
  local pending = predictions[action]
  local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if pending then
   local prediction = table.remove(pending, 1)
   if prediction and root and World:GetServerTimeNow() - prediction.At < .22 then root.AssemblyLinearVelocity = prediction.Before end
  end
  if action == "Jump" then predictedJumps = tonumber(data.JumpCount) or (player.Character and tonumber(player.Character:GetAttribute("JumpCount"))) or 0
  elseif action == "Dash" then localDashUntil = 0; nextDashPrediction = 0 end
 elseif kind == "Notice" then toast(data.Text or "")
 elseif kind == "Match" then
  if arena and data.MatchEndsAt then arena.MatchEndsAt = data.MatchEndsAt end
 end
end)

local effects = Instance.new("Folder"); effects.Name = "PARABOUNDLocalEffects"; effects.Parent = World
local shakeUntil, shakePower = 0, 0
local function soundEffect(key, position)
 local id = (Content.Audio or {})[key]
 if not id or not setting("SFX") then return end
 local point = Instance.new("Part"); point.Name = "AudioPoint"; point.Anchored = true
 point.CanCollide = false; point.CanTouch = false; point.CanQuery = false; point.Transparency = 1
 point.Size = Vector3.new(.1, .1, .1); point.Position = position; point.Parent = effects
 local sound = Instance.new("Sound"); sound.SoundId = "rbxassetid://" .. tostring(id)
 sound.Volume = key == "Tell" and .12 or .22; sound.RollOffMinDistance = 8; sound.RollOffMaxDistance = 90
 sound.Parent = point; sound:Play(); Debris:AddItem(point, 2)
 if key == "Tell" or key == "PerfectParry" then task.delay(.14, function() if sound.Parent then sound:Stop() end end) end
end
local function shard(position, size, color, offset, duration)
 local part = Instance.new("Part"); part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.CanTouch = false
 part.Material = Enum.Material.Neon; part.Color = color; part.Size = size; part.CFrame = CFrame.new(position); part.Parent = effects
 TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = position + offset, Transparency = 1}):Play()
 Debris:AddItem(part, duration + .03)
end
net.Effect.OnClientEvent:Connect(function(kind, data)
 data = type(data) == "table" and data or {}
 local model = data.Model or data.Target
 if kind == "Impulse" then
  if model ~= player.Character or typeof(data.Velocity) ~= "Vector3" or type(data.Serial) ~= "number" or data.Serial <= lastImpulseSerial then return end
  if data.ArenaId and data.ArenaId ~= model:GetAttribute("ArenaId") then return end
  if type(data.IssuedAt) == "number" and data.IssuedAt < impulseEpoch - .02 then return end
  local root = model:FindFirstChild("HumanoidRootPart")
  if not root then return end
  lastImpulseSerial = data.Serial
  local now, action = World:GetServerTimeNow(), data.Action
  packetDashUntil = tonumber(data.DashUntil) or packetDashUntil
  packetLaunchUntil = tonumber(data.LaunchUntil) or packetLaunchUntil
  packetHitStopUntil = tonumber(data.HitStopUntil) or packetHitStopUntil
  if action == "Jump" then predictedJumps = math.max(predictedJumps, tonumber(data.JumpCount) or 0); groundStableFor = 0 end
  local pending, predicted = predictions[action], false
  if pending then
   for i = #pending, 1, -1 do if now - pending[i].At > 1 then table.remove(pending, i) end end
   for i, prediction in ipairs(pending) do
    if action ~= "Jump" or prediction.Count == data.JumpCount then
     predicted = now - prediction.At < .22
     table.remove(pending, i); break
    end
   end
  end
  if action == "Jump" then
   local newestCount = tonumber(data.JumpCount) or 0
   for _, prediction in ipairs(predictions.Jump) do newestCount = math.max(newestCount, prediction.Count) end
   predictedJumps = newestCount
  end
  if not predicted then root.AssemblyLinearVelocity = data.Velocity end
  if action == "Launch" or action == "Freeze" then localDashUntil = 0 end
  if action == "Restore" then packetHitStopUntil = 0 end
  idleHoldX = nil
  return
 end
 local root = typeof(model) == "Instance" and model:FindFirstChild("HumanoidRootPart") or nil
 local pos = typeof(data.Position) == "Vector3" and data.Position or root and root.Position
 if not pos then return end
 local lane = arena and arena.LaneZ
 if lane and math.abs(pos.Z - lane) > 12 then return end
 local ownArena = player.Character and player.Character:GetAttribute("ArenaId")
 if ownArena and typeof(model) == "Instance" and model:GetAttribute("ArenaId") ~= ownArena then return end
 local facing = (root and root.Parent:GetAttribute("Facing")) or tonumber(data.Facing) or 1
 if kind == "Tell" or kind == "Startup" then
  soundEffect("Tell", pos)
  -- A short square glint at the weapon, never a text command above the fighter.
  local at = pos + Vector3.new(facing * 2, .7, .3)
  shard(at, Vector3.new(.19, .19, .12), CREAM, Vector3.new(facing * .18, .12, 0), setting("ReducedFlashes") and .09 or .13)
 elseif kind == "ParryAttempt" then
  shard(pos + Vector3.new(facing * 1.15, .3, .3), Vector3.new(.12, .12, .08), MUTED, Vector3.zero, .10)
 elseif kind == "Hit" or kind == "ArcanaHit" or kind == "Parry" or kind == "ParrySuccess" or kind == "PerfectParry" or kind == "GuardBreak" then
  local parry = kind == "Parry" or kind == "ParrySuccess" or kind == "PerfectParry"
  soundEffect(parry and (kind == "PerfectParry" and "PerfectParry" or "Parry") or "Hit", pos)
  local color = parry and GOLD or CREAM
  local count = setting("ReducedFlashes") and 2 or 4
  for i = 1, count do
   local vertical = (i - (count + 1) / 2) * .55
   shard(pos + Vector3.new(0, .4, .4), Vector3.new(.24, .11, .12), color, Vector3.new(facing * (1.1 + i * .18), vertical, 0), .17)
  end
  if setting("CameraShake") then shakeUntil = os.clock() + .09; shakePower = parry and .035 or .055 end
 end
end)

local pixelRenderer
-- The renderer owns sprite discovery and smooth animation; the client supplies its clock.
task.spawn(function()
 local module = package:WaitForChild("PixelRenderer", 20)
 if not module then warn("PARABOUND PixelRenderer is missing"); return end
 local ok, renderer = pcall(require, module)
 if ok then pixelRenderer = renderer.new() else warn("PARABOUND PixelRenderer:", renderer) end
end)
local function rootOf(model) return model and model:FindFirstChild("HumanoidRootPart") end
local function opponent(character, root)
 if not root then return nil end
 local mode = character:GetAttribute("Mode")
 local arenaId = character:GetAttribute("ArenaId")
 local lane = arena and arena.LaneZ or root.Position.Z
 local nearest, distance = nil, math.huge
 local function consider(model)
  local r = rootOf(model)
  if model == character or not r or model:GetAttribute("Dead") or model:GetAttribute("Mode") ~= mode then return end
  if arenaId and model:GetAttribute("ArenaId") ~= arenaId then return end
  if math.abs(r.Position.Z - lane) > 3 then return end
  local d = math.abs(r.Position.X - root.Position.X)
  if d < distance then nearest, distance = model, d end
 end
 for _, other in ipairs(Players:GetPlayers()) do if other ~= player then consider(other.Character) end end
 local fighters = World:FindFirstChild("PARABOUNDFighters")
 if fighters then for _, model in ipairs(fighters:GetChildren()) do consider(model) end end
 return nearest
end
local function updateCard(card, model, name)
 if not model then card.Name.Text = name; card.Impact.Text = "—"; card.Stocks.Text = ""; card.Guard.Size = UDim2.fromScale(0, 1); return end
 card.Name.Text = name
 card.Impact.Text = tostring(math.floor((tonumber(model:GetAttribute("Impact")) or 0) + .5)) .. "%"
 local stocks = math.clamp(tonumber(model:GetAttribute("Stocks")) or 3, 0, 3)
 local diamonds = {}; for i = 1, 3 do table.insert(diamonds, i <= stocks and "◆" or "◇") end
 card.Stocks.Text = table.concat(diamonds, " ")
 card.Guard.Size = UDim2.fromScale(math.clamp((tonumber(model:GetAttribute("Guard")) or 100) / 100, 0, 1), 1)
end
local rigConnections = {}
local function clearRigConnections()
 for _, connection in ipairs(rigConnections) do connection:Disconnect() end
 table.clear(rigConnections)
end
local function configureLocalPhysics(character)
 if player.Character ~= character then return end
 clearRigConnections()
 local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
 if player.Character ~= character then return end
 if humanoid and humanoid:IsA("Humanoid") then
  humanoid.EvaluateStateMachine = false
  humanoid.PlatformStand = true
  humanoid:ChangeState(Enum.HumanoidStateType.Physics)
 end
 local function preparePart(part)
  if not part:IsA("BasePart") then return end
  if part.Name == "HumanoidRootPart" then
   part.CanCollide = true
   return
  end
  part.CanCollide = false; part.Massless = true
  if part.Name == "UpperTorso" or part.Name == "LowerTorso" then
   table.insert(rigConnections, part:GetPropertyChangedSignal("CanCollide"):Connect(function()
    if part.Parent and part.CanCollide then part.CanCollide = false end
   end))
  end
 end
 for _, part in ipairs(character:GetDescendants()) do preparePart(part) end
 table.insert(rigConnections, character.DescendantAdded:Connect(preparePart))
end
if player.Character then configureLocalPhysics(player.Character) end
local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude; rayParams.RespectCanCollide = true
local lastMove, lastHUD, lastDirection = 0, 0, 0
local cameraX, cameraY, cameraDistance = nil, nil, nil
local function approach(value, target, amount)
 return value < target and math.min(value + amount, target) or math.max(value - amount, target)
end
local simulationConnection = RunService.PreSimulation:Connect(function(dt)
 dt = math.min(dt, .1)
 local character = player.Character; local root = rootOf(character)
 if not character or not root then return end
 local now, mono = World:GetServerTimeNow(), os.clock()
 -- Server-created constraints turn shelves into true one-way platforms for the owner.
 local platformConstraints = character:FindFirstChild("OneWayPlatforms")
 if platformConstraints then
  local feet = root.Position.Y - root.Size.Y / 2
  local rising = root.AssemblyLinearVelocity.Y > 1
  for _, constraint in ipairs(platformConstraints:GetChildren()) do
   if constraint:IsA("NoCollisionConstraint") then
    local platform = constraint.Part1
    if platform and platform.Parent then
     local top = platform.Position.Y + platform.Size.Y / 2
     constraint.Enabled = feet < top - .12 or rising
    end
   end
  end
 end
 local dir = direction()
 if mono - lastMove >= .1 or dir == 0 and lastDirection ~= 0 then
  lastMove = mono; lastDirection = dir; send("Move", {direction = dir})
 end
 local dead = character:GetAttribute("Dead") == true
 local dash = math.max(tonumber(character:GetAttribute("DashUntil")) or 0, localDashUntil, packetDashUntil) > now
 local launched = math.max(tonumber(character:GetAttribute("LaunchUntil")) or 0, packetLaunchUntil) > now
 local stunned = (character:GetAttribute("StunUntil") or 0) > now
 local stopped = math.max(tonumber(character:GetAttribute("HitStopUntil")) or 0, packetHitStopUntil) > now
 if dir ~= 0 or dead or dash or launched or stunned or stopped or root.Anchored then idleHoldX = nil end
 if not dead and not dash and not stopped and not root.Anchored then
  local velocity = root.AssemblyLinearVelocity
  if launched then
   if dir ~= 0 then root.AssemblyLinearVelocity = Vector3.new(velocity.X + dir * 12 * dt, velocity.Y, 0) end
  elseif not stunned then
   local excluded = {effects}
   for _, otherPlayer in ipairs(Players:GetPlayers()) do if otherPlayer.Character then table.insert(excluded, otherPlayer.Character) end end
   local fighterFolder = World:FindFirstChild("PARABOUNDFighters")
   if fighterFolder then table.insert(excluded, fighterFolder) end
   rayParams.FilterDescendantsInstances = excluded
   local airborne = character:GetAttribute("Airborne")
   local grounded = typeof(airborne) == "boolean" and not airborne or (airborne == nil and World:Raycast(root.Position, Vector3.new(0, -3.5, 0), rayParams) ~= nil)
   if grounded and math.abs(velocity.Y) < 2 and now - lastJumpPrediction > .25 then
    groundStableFor += dt
    if groundStableFor > .1 then predictedJumps = 0 end
   else
    groundStableFor = 0
    if airborne == true then predictedJumps = math.max(predictedJumps, tonumber(character:GetAttribute("JumpCount")) or 1) end
   end
   local speed = character:GetAttribute("Guarding") and 11 or 22
   local target = dir * speed
   local acceleration = grounded and 180 or 70
   local vx = approach(velocity.X, target, acceleration * dt)
   if grounded and dir == 0 and math.abs(velocity.X) < .75 then
    -- Settle contact/network noise only after all combat motion locks have ended.
    if not idleHoldX or math.abs(root.Position.X - idleHoldX) >= .75 then idleHoldX = root.Position.X end
    vx = 0
    local correction = idleHoldX - root.Position.X
    if math.abs(correction) > .02 then root.CFrame += Vector3.new(correction, 0, 0) end
   else idleHoldX = nil end
   root.AssemblyLinearVelocity = Vector3.new(vx, velocity.Y, 0)
  end
 end
end)
local compactLayout = false
local pcHelp = "A / D  MOVE    SPACE  JUMP    J / K  ATTACK    F  PARRY    Q  DASH    E  SURGE    G  FEINT    M  MENU"
local padHelp = "LEFT STICK  MOVE    A  JUMP    X / Y  ATTACK    LT  PARRY    B  DASH    RT  SURGE    LB  FEINT    SELECT  MENU"
local gamepadTutorialText = {
 "Move across the court with the LEFT STICK.",
 "Press A twice to jump again in the air.",
 "Press B while moving to dash across the court.",
 "Stand near the dummy. Press X or Y to land hits.",
 "Press LT just before a strike lands. Hold it to guard.",
 "Watch the tiny weapon glint. Press LT at the last moment.",
}
local lastLayoutKey = ""
local phoneTutorialText = {
 "Hold LEFT or RIGHT to move across the court.",
 "Tap JUMP twice to jump again in the air.",
 "Tap DASH while moving to cross the court quickly.",
 "Stand near the dummy. Tap LIGHT or HEAVY to land hits.",
 "Tap PARRY just before a strike lands. Hold to guard.",
 "Watch the tiny weapon glint. Tap PARRY at the last moment.",
}
local function layoutForViewport(viewport)
 compactLayout = touch or viewport.Y < 480
 local key = tostring(compactLayout) .. ":" .. tostring(viewport.X)
 if key == lastLayoutKey then return end
 lastLayoutKey = key
 hud.Position = UDim2.fromOffset(14, compactLayout and 44 or 64)
 hud.Size = UDim2.new(1, -28, 0, compactLayout and 44 or 76)
 for _, card in ipairs({ownCard, rivalCard}) do
  card.Frame.Size = UDim2.new(compactLayout and .23 or .26, 0, 0, compactLayout and 42 or 70)
  card.Name.Position = UDim2.fromOffset(compactLayout and 6 or 10, compactLayout and 1 or 5)
  card.Name.Size = UDim2.new(1, compactLayout and -12 or -20, 0, compactLayout and 14 or 19)
  card.Impact.Position = UDim2.fromOffset(compactLayout and 6 or 10, compactLayout and 15 or 24)
  card.Impact.Size = UDim2.new(.60, -10, 0, compactLayout and 23 or 30)
  card.Stocks.Position = UDim2.new(.6, 0, 0, compactLayout and 19 or 24)
  card.Stocks.Size = UDim2.new(.4, compactLayout and -6 or -10, 0, compactLayout and 17 or 24)
  card.Guard.Parent.Position = UDim2.fromOffset(compactLayout and 6 or 10, compactLayout and 39 or 58)
  card.Guard.Parent.Size = UDim2.new(1, compactLayout and -12 or -20, 0, compactLayout and 3 or 4)
 end
 mapTitle.Position = UDim2.new(.25, 0, 0, compactLayout and 0 or 7)
 mapTitle.Size = UDim2.new(.50, 0, 0, compactLayout and 16 or 20)
 mapTitle.TextSize = compactLayout and 10 or 12
 clockText.Position = UDim2.new(.25, 0, 0, compactLayout and 18 or 29)
 clockText.Size = UDim2.new(.50, 0, 0, compactLayout and 15 or 20)
 clockText.TextSize = compactLayout and 10 or 11
 menuButton.Position = UDim2.new(.5, 0, 0, compactLayout and 20 or 116)
 menuButton.Size = UDim2.fromOffset(touch and 76 or 116, compactLayout and 22 or 24)
 menuButton.Text = compactLayout and "MENU" or "MENU [M]"
 help.Visible = not touch and not compactLayout
 tutorialPanel.AnchorPoint = compactLayout and Vector2.new(.5, 0) or Vector2.zero
 tutorialPanel.Position = compactLayout and UDim2.new(.5, 0, 0, 94) or UDim2.fromOffset(14, 154)
 tutorialPanel.Size = UDim2.fromOffset(compactLayout and math.min(320, viewport.X - 28) or (viewport.X < 650 and 228 or 280), compactLayout and 56 or 151)
 tutorialTitle.Position = UDim2.fromOffset(compactLayout and 8 or 12, compactLayout and 1 or 8)
 tutorialTitle.Size = UDim2.new(1, compactLayout and -16 or -24, 0, compactLayout and 14 or 21)
 tutorialTitle.TextSize = compactLayout and 11 or 12
 tutorialText.Position = UDim2.fromOffset(compactLayout and 8 or 12, compactLayout and 16 or 33)
 tutorialText.Size = UDim2.new(1, compactLayout and -16 or -24, 0, compactLayout and 26 or 49)
 tutorialText.TextSize = compactLayout and 11 or 12
 progressText.Position = UDim2.fromOffset(compactLayout and 8 or 12, compactLayout and 42 or 84)
 progressText.Size = UDim2.new(1, compactLayout and -16 or -24, 0, compactLayout and 11 or 18)
 progressText.TextSize = compactLayout and 9 or 10
 progressTrack.Position = UDim2.fromOffset(compactLayout and 8 or 12, compactLayout and 54 or 108)
 progressTrack.Size = UDim2.new(1, compactLayout and -16 or -24, 0, compactLayout and 2 or 3)
 practiceSkip.Visible = not compactLayout; duelSkip.Visible = not compactLayout
 queuePanel.Position = UDim2.new(.5, 0, 0, compactLayout and 94 or 154)
 for name, buttonObject in pairs(touchButtons) do
  local bottomRow = name == "LEFT" or name == "RIGHT" or name == "PARRY" or name == "SURGE" or name == "FEINT"
  buttonObject.Position = UDim2.new(buttonObject.Position.X.Scale, buttonObject.Position.X.Offset, 1, bottomRow and -58 or -114)
 end
end
local perfFrames, perfTime, spriteTime = 0, 0, 0
UIS.WindowFocused:Connect(function() gui:SetAttribute('InputFocused',true) end)
UIS.WindowFocusReleased:Connect(function() gui:SetAttribute('InputFocused',false) end)
local renderConnection = RunService.RenderStepped:Connect(function(dt)
 perfFrames += 1; perfTime += dt
 dt = math.min(dt, .1)
 if pixelRenderer then local started=os.clock();pixelRenderer:Step(dt);spriteTime+=os.clock()-started end
 if perfTime>=2 then gui:SetAttribute('MeasuredFPS',perfFrames/perfTime);gui:SetAttribute('SpriteStepMS',spriteTime*1000/perfFrames);perfFrames=0;perfTime=0;spriteTime=0 end
 local character = player.Character; local root = rootOf(character)
 if not character or not root then return end
 local now, mono = World:GetServerTimeNow(), os.clock()
 local other = opponent(character, root); local rivalRoot = rootOf(other)
 if mono - lastHUD > .08 then
  lastHUD = mono
  hud.Visible = not menuOpen; tutorialPanel.Visible = not menuOpen and not result and tutorial ~= nil and arena and arena.Mode == "Tutorial" or false
  queuePanel.Visible = queueText ~= nil and not menuOpen and not result
  touchPad.Visible = touch and not menuOpen and not result
  abilityText.Visible = not compactLayout and not menuOpen and not result
  if tutorial then
   if compactLayout and tutorial.Complete then progressText.Text = "COMPLETE · Open MENU to choose your next duel" end
   tutorialText.Text = compactLayout and (tutorial.Complete and "Tutorial complete. Open MENU for Practice Bot or Find Duel." or phoneTutorialText[tonumber(tutorial.Step)] or tostring(tutorial.Text or "")) or tostring(tutorial.Text or "")
  end
  updateCard(ownCard, character, player.DisplayName)
  local rivalPlayer = other and Players:GetPlayerFromCharacter(other)
  local rivalName = rivalPlayer and rivalPlayer.DisplayName or other and (other:GetAttribute("DisplayName") or other.Name) or "AWAITING RIVAL"
  if other and other:GetAttribute("Bot") == true then rivalName = "BOT · " .. tostring(rivalName) end
  updateCard(rivalCard, other, tostring(rivalName))
  mapTitle.Text = tostring(arena and arena.Name or "PARABOUND")
  if arena and arena.MatchStartsAt and arena.MatchStartsAt > now then
   clockText.Text = "STARTS IN " .. tostring(math.ceil(arena.MatchStartsAt - now))
  elseif arena and arena.MatchEndsAt and arena.MatchEndsAt > 0 then
   local remaining = math.max(0, math.ceil(arena.MatchEndsAt - now))
   clockText.Text = string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
  else clockText.Text = queueText and "PLAYER DUEL SEARCH" or string.upper(tostring(arena and arena.Mode or "SHORT TUTORIAL")) end
  local remaining = tonumber(character:GetAttribute("CD_Arcana1")) or math.max(0, (tonumber(character:GetAttribute("CooldownArcana1")) or 0) - now)
  abilityText.Text = (touch and "RESONANCE CUT" or preferredGamepad and "RT · RESONANCE CUT" or "E · RESONANCE CUT") .. (remaining > .05 and string.format("  %.1fs", remaining) or "  READY")
  if touchButtons.SURGE then touchButtons.SURGE.Text = remaining > .05 and string.format("SURGE\n%.1fs", remaining) or "SURGE" end
  for name, key in pairs({DASH = "CD_Dash", PARRY = "CD_Parry"}) do
   local cd = tonumber(character:GetAttribute(key)) or 0
   if touchButtons[name] then touchButtons[name].Text = cd > .05 and string.format("%s\n%.1fs", name, cd) or name end
  end
  help.Text = preferredGamepad and padHelp or pcHelp
  menuButton.Text = touch and "MENU" or (preferredGamepad and "MENU [SELECT]" or "MENU [M]")
  if tutorial and preferredGamepad and not touch then
   tutorialText.Text = tutorial.Complete and "Tutorial complete. Open MENU to find a duel or practice." or gamepadTutorialText[tonumber(tutorial.Step)] or tostring(tutorial.Text or "")
  end
 end
 local camera = World.CurrentCamera
 if not camera then return end
 layoutForViewport(camera.ViewportSize)
 local center = arena and arena.Center
 if typeof(center) ~= "Vector3" then center = Vector3.new(root.Position.X, 0, root.Position.Z) end
 local lane = tonumber(arena and arena.LaneZ) or center.Z
 local floorY = tonumber(arena and arena.FloorY) or center.Y
 local minX, maxX = tonumber(arena and arena.MinX) or center.X - 32, tonumber(arena and arena.MaxX) or center.X + 32
 local leftX, rightX = root.Position.X, root.Position.X
 local ownY = math.clamp(root.Position.Y, floorY + 2, floorY + 15)
 local targetY = ownY + 2
 if rivalRoot then
  leftX, rightX = math.min(leftX, rivalRoot.Position.X), math.max(rightX, rivalRoot.Position.X)
  targetY = (ownY + math.clamp(rivalRoot.Position.Y, floorY + 2, floorY + 15)) / 2 + 2
 end
 targetY = math.clamp(targetY, floorY + 4, floorY + 11)
 local targetX = math.clamp((leftX + rightX) / 2, minX, maxX)
 local aspect = math.max(.65, camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y))
 local fov = 38
 local width = math.max(26, rightX - leftX + 19)
 local desiredDistance = math.clamp(width / (2 * math.tan(math.rad(fov / 2)) * aspect), 43, 65)
 if cameraSnap or not cameraX then
  cameraX, cameraY, cameraDistance = targetX, targetY, desiredDistance; cameraSnap = false
 else
  local alpha = 1 - math.exp(-dt * 8)
  cameraX += (targetX - cameraX) * alpha; cameraY += (targetY - cameraY) * alpha
  cameraDistance += (desiredDistance - cameraDistance) * (1 - math.exp(-dt * 4))
 end
 camera.CameraType = Enum.CameraType.Scriptable; camera.FieldOfView = fov
 local target = Vector3.new(cameraX, cameraY, lane)
 camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 0, cameraDistance), target)
 if mono < shakeUntil and setting("CameraShake") then
  local amount = shakePower * (shakeUntil - mono) / .09 * (setting("ReducedFlashes") and .4 or 1)
  camera.CFrame *= CFrame.new(math.sin(mono * 77) * amount, math.cos(mono * 53) * amount, 0)
 end
 -- Portrait screens get a small tutorial card above the movement pad.
 local narrow = camera.ViewportSize.X < 650
 ownCard.Name.TextSize = (compactLayout or narrow) and 10 or 12; rivalCard.Name.TextSize = (compactLayout or narrow) and 10 or 12
 ownCard.Impact.TextSize = compactLayout and 20 or (narrow and 22 or 25); rivalCard.Impact.TextSize = compactLayout and 20 or (narrow and 22 or 25)
 ownCard.Stocks.TextSize = compactLayout and 11 or (narrow and 10 or 13); rivalCard.Stocks.TextSize = compactLayout and 11 or (narrow and 10 or 13)
end)
local characterConnection = player.CharacterAdded:Connect(function(character)
 cameraSnap = true; clearInput(); resetMotionPrediction(); configureLocalPhysics(character)
end)
gui.Destroying:Connect(function()
 simulationConnection:Disconnect(); renderConnection:Disconnect(); characterConnection:Disconnect(); clearRigConnections(); releaseGuard()
 for _, name in ipairs(bindings) do CAS:UnbindAction(name) end
 if pixelRenderer and pixelRenderer.Destroy then pixelRenderer:Destroy() end
 effects:Destroy(); music:Destroy()
end)
applySettings()
send("Request")
