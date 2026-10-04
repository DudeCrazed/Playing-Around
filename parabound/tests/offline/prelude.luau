-- Minimal Roblox API stand-ins so src/server/Combat.luau runs under the stock `luau` CLI.
-- Only what Combat touches is modeled: a settable server clock, Vector3, attributes/children,
-- a downward Raycast against registered floor parts, and inert Debris/ReplicatedStorage.
local now = 1000

local Vector3 = {}
local V3 = {__type = "Vector3"}
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
function Vector3.new(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, V3) end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(v) return string.format("(%g, %g, %g)", v.X, v.Y, v.Z) end
Vector3.zero = Vector3.new(0, 0, 0)

local Color3 = {fromRGB = function(r, g, b) return {R = r / 255, G = g / 255, B = b / 255} end}
local Enum = {RaycastFilterType = {Exclude = "Exclude", Include = "Include"}}
local RaycastParams = {new = function() return {FilterDescendantsInstances = {}} end}

local function typeof(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and mt.__type then return mt.__type end
	return type(v)
end
local function warn(...) print("WARN", ...) end

local Methods = {}
local InstanceMeta = {__type = "Instance"}
InstanceMeta.__index = function(o, k)
	local m = Methods[k]
	if m ~= nil then return m end
	return rawget(o, "_p")[k]
end
InstanceMeta.__newindex = function(o, k, v)
	local p = rawget(o, "_p")
	if k == "Parent" then
		local old = p.Parent
		if old then
			local list = rawget(old, "_c")
			local i = table.find(list, o)
			if i then table.remove(list, i) end
		end
		if v then table.insert(rawget(v, "_c"), o) end
	end
	p[k] = v
end
local Instance = {}
function Instance.new(className)
	local p = {ClassName = className, Name = className}
	if className == "NoCollisionConstraint" then p.Enabled = true end
	return setmetatable({_p = p, _c = {}, _a = {}}, InstanceMeta)
end
function Methods:SetAttribute(k, v) rawget(self, "_a")[k] = v end
function Methods:GetAttribute(k) return rawget(self, "_a")[k] end
function Methods:IsA(c)
	local cls = rawget(self, "_p").ClassName
	return cls == c or (c == "BasePart" and cls == "Part")
end
function Methods:FindFirstChild(name)
	for _, c in ipairs(rawget(self, "_c")) do if c.Name == name then return c end end
	return nil
end
function Methods:FindFirstChildOfClass(cls)
	for _, c in ipairs(rawget(self, "_c")) do if c.ClassName == cls then return c end end
	return nil
end
function Methods:GetChildren() return table.clone(rawget(self, "_c")) end
function Methods:GetDescendants()
	local out = {}
	local function walk(o) for _, c in ipairs(rawget(o, "_c")) do table.insert(out, c); walk(c) end end
	walk(self)
	return out
end
function Methods:Destroy() self.Parent = nil end

local workspaceRoot = Instance.new("Workspace")
local floors = {}
local Workspace = {}
function Workspace:GetServerTimeNow() return now end
function Workspace:Raycast(origin, direction, params)
	local excluded = {}
	for _, e in ipairs(params.FilterDescendantsInstances or {}) do excluded[e] = true end
	local best, bestTop
	for _, part in ipairs(floors) do
		if part.Parent and not excluded[part] then
			local top = part.Position.Y + part.Size.Y / 2
			if math.abs(origin.X - part.Position.X) <= part.Size.X / 2 and top <= origin.Y and top >= origin.Y + direction.Y then
				if not bestTop or top > bestTop then best, bestTop = part, top end
			end
		end
	end
	if best then return {Instance = best, Position = Vector3.new(origin.X, bestTop, origin.Z)} end
	return nil
end
local Debris = {AddItem = function() end}
local ReplicatedStorage = {}
function ReplicatedStorage:WaitForChild() return self end
local game = {}
function game:GetService(name)
	if name == "Workspace" then return Workspace end
	if name == "Debris" then return Debris end
	if name == "ReplicatedStorage" then return ReplicatedStorage end
	error("unmocked service " .. tostring(name))
end
