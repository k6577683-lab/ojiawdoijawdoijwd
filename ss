local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FOLDER_NAME = 'DhabWild'
local PANIC_KEY = Enum.KeyCode.End
local TOGGLE_KEYS = { [Enum.KeyCode.P] = true, [Enum.KeyCode.RightShift] = true }

-- THEME
local T = {
	bg = Color3.fromRGB(18, 18, 26),
	panel = Color3.fromRGB(28, 28, 40),
	item = Color3.fromRGB(40, 40, 58),
	accent = Color3.fromRGB(110, 90, 255),
	on = Color3.fromRGB(60, 200, 120),
	text = Color3.fromRGB(240, 240, 250),
	dim = Color3.fromRGB(150, 150, 170),
	danger = Color3.fromRGB(220, 60, 70),
}

-- CONNECTION TRACKING (so panic can kill everything)
local connections = {}
local destroyed = false
local function bind(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

-- ESP
local ESP = {
	enabled = false,
	colorIndex = 1,
	colors = {
		Color3.fromRGB(255, 170, 0),
		Color3.fromRGB(0, 255, 120),
		Color3.fromRGB(0, 170, 255),
		Color3.fromRGB(255, 60, 60),
	},
	objects = {},
	conns = {},
}

function ESP.color() return ESP.colors[ESP.colorIndex] end
function ESP.getFolder() return workspace:FindFirstChild(FOLDER_NAME) end

function ESP.remove(obj)
	local data = ESP.objects[obj]
	if not data then return end
	if data.hl then data.hl:Destroy() end
	if data.tag then data.tag:Destroy() end
	ESP.objects[obj] = nil
end

function ESP.clear()
	for obj in pairs(ESP.objects) do ESP.remove(obj) end
end

function ESP.add(obj)
	if ESP.objects[obj] or not obj:IsA('Model') then return end
	local hl = Instance.new('Highlight')
	hl.Adornee = obj
	hl.FillColor = ESP.color()
	hl.OutlineColor = ESP.color()
	hl.FillTransparency = 0.7
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = obj

	local tag = Instance.new('BillboardGui')
	tag.Adornee = obj
	tag.Size = UDim2.fromOffset(160, 32)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.AlwaysOnTop = true
	tag.Parent = obj

	local lbl = Instance.new('TextLabel')
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = ESP.color()
	lbl.TextStrokeTransparency = 0.4
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 14
	lbl.Text = obj.Name
	lbl.Parent = tag

	ESP.objects[obj] = { hl = hl, tag = tag, label = lbl }
end

function ESP.recolor()
	for _, d in pairs(ESP.objects) do
		d.hl.FillColor = ESP.color()
		d.hl.OutlineColor = ESP.color()
		d.label.TextColor3 = ESP.color()
	end
end

function ESP.disconnect()
	for _, c in ipairs(ESP.conns) do c:Disconnect() end
	table.clear(ESP.conns)
end

function ESP.refresh()
	ESP.clear()
	ESP.disconnect()
	if not ESP.enabled then return end
	local folder = ESP.getFolder()
	if not folder then return end
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA('Model') then ESP.add(d) end
	end
	table.insert(ESP.conns, folder.DescendantAdded:Connect(function(d)
		if d:IsA('Model') then ESP.add(d) end
	end))
	table.insert(ESP.conns, folder.DescendantRemoving:Connect(function(d)
		ESP.remove(d)
	end))
end

bind(RunService.Heartbeat, function()
	for obj, data in pairs(ESP.objects) do
		if not obj.Parent then
			ESP.remove(obj)
		else
			local dist = (camera.CFrame.Position - obj:GetPivot().Position).Magnitude
			data.label.Text = obj.Name .. ' [' .. math.floor(dist) .. ']'
		end
	end
end)

-- AIMBOT
local Aim = {
	hotkey = Enum.UserInputType.MouseButton2,
	holding = false,
	smooth = 5,
	fov = 150,
	targets = {},
	conns = {},
	rebinding = false,
}

local function matchesHotkey(input)
	return input.KeyCode == Aim.hotkey or input.UserInputType == Aim.hotkey
end

local function hotkeyName()
	if Aim.hotkey == Enum.UserInputType.MouseButton1 then return 'Left Mouse' end
	if Aim.hotkey == Enum.UserInputType.MouseButton2 then return 'Right Mouse' end
	if Aim.hotkey == Enum.UserInputType.MouseButton3 then return 'Middle Mouse' end
	return Aim.hotkey.Name
end

local function aimPart(model)
	return model:FindFirstChild('Head')
		or model:FindFirstChild('HumanoidRootPart')
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA('BasePart', true)
end

function Aim.disconnect()
	for _, c in ipairs(Aim.conns) do c:Disconnect() end
	table.clear(Aim.conns)
	table.clear(Aim.targets)
end

function Aim.rescan()
	Aim.disconnect()
	local folder = workspace:FindFirstChild(FOLDER_NAME)
	if not folder then return end
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA('Model') then Aim.targets[d] = true end
	end
	table.insert(Aim.conns, folder.DescendantAdded:Connect(function(d)
		if d:IsA('Model') then Aim.targets[d] = true end
	end))
	table.insert(Aim.conns, folder.DescendantRemoving:Connect(function(d)
		Aim.targets[d] = nil
	end))
end

function Aim.getTarget()
	local vp = camera.ViewportSize
	local center = Vector2.new(vp.X / 2, vp.Y / 2)
	local best, bestDist = nil, Aim.fov
	for model in pairs(Aim.targets) do
		if model.Parent then
			local hum = model:FindFirstChildOfClass('Humanoid')
			if not hum or hum.Health > 0 then
				local part = aimPart(model)
				if part then
					local pos, onScreen = camera:WorldToViewportPoint(part.Position)
					if onScreen then
						local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
						if d < bestDist then best, bestDist = part, d end
					end
				end
			end
		end
	end
	return best
end

RunService:BindToRenderStep('HubAim', Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not Aim.holding then return end
	local part = Aim.getTarget()
	if not part then return end
	local goal = CFrame.lookAt(camera.CFrame.Position, part.Position)
	camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(dt * 60 / Aim.smooth, 0, 1))
end)

-- GUI HELPERS
local gui = Instance.new('ScreenGui')
gui.Name = 'ScriptHub'
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild('PlayerGui')

local function corner(inst, r)
	local c = Instance.new('UICorner')
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
	return c
end

local function frame(parent, pos, size, color)
	local f = Instance.new('Frame')
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color or T.panel
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function text(parent, str, pos, size, opts)
	opts = opts or {}
	local l = Instance.new('TextLabel')
	l.Text = str
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.TextColor3 = opts.color or T.text
	l.Font = opts.font or Enum.Font.Gotham
	l.TextSize = opts.size or 14
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function btn(parent, str, pos, size, color)
	local b = Instance.new('TextButton')
	b.Text = str
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = color or T.item
	b.TextColor3 = T.text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 8)
	local base = b.BackgroundColor3
	bind(b.MouseEnter, function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12) }):Play()
	end)
	bind(b.MouseLeave, function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = b:GetAttribute('base') or base }):Play()
	end)
	b:SetAttribute('base', base)
	return b
end

local function setBase(b, color)
	b:SetAttribute('base', color)
	b.BackgroundColor3 = color
end

-- FOV CIRCLE
local fovCircle = Instance.new('Frame')
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.Size = UDim2.fromOffset(Aim.fov * 2, Aim.fov * 2)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = false
fovCircle.Parent = gui
corner(fovCircle, 9999)
local fovStroke = Instance.new('UIStroke')
fovStroke.Color = T.accent
fovStroke.Thickness = 1.5
fovStroke.Parent = fovCircle

-- MAIN WINDOW
local FULL_SIZE = UDim2.fromOffset(360, 520)
local main = Instance.new('CanvasGroup')
main.Size = FULL_SIZE
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.BackgroundColor3 = T.bg
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 14)
local mainStroke = Instance.new('UIStroke')
mainStroke.Color = T.accent
mainStroke.Transparency = 0.5
mainStroke.Thickness = 1.5
mainStroke.Parent = main

-- TITLE BAR (drag handle)
local titleBar = frame(main, UDim2.new(), UDim2.new(1, 0, 0, 44), T.panel)
text(titleBar, 'SCRIPT HUB', UDim2.fromOffset(16, 0), UDim2.new(1, -90, 1, 0),
	{ font = Enum.Font.GothamBlack, size = 17 })
local hintTop = text(titleBar, 'P: hide   End: panic', UDim2.new(1, -170, 0, 0), UDim2.fromOffset(160, 44),
	{ color = T.dim, size = 11, align = Enum.TextXAlignment.Right })
hintTop.Position = UDim2.new(1, -170, 0, 0)
local accentLine = frame(main, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 2), T.accent)

do -- dragging
	local dragging, dragStart, startPos
	bind(titleBar.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, main.Position
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- CONTENT
local content = Instance.new('ScrollingFrame')
content.Position = UDim2.fromOffset(0, 48)
content.Size = UDim2.new(1, 0, 1, -48)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main
local pad = Instance.new('UIPadding')
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 12)
pad.Parent = content
local list = Instance.new('UIListLayout')
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = content

local order = 0
local function section(title, height)
	order += 1
	local card = frame(content, UDim2.new(), UDim2.new(1, 0, 0, height), T.panel)
	card.LayoutOrder = order
	corner(card, 10)
	text(card, title:upper(), UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20),
		{ color = T.accent, font = Enum.Font.GothamBold, size = 12 })
	return card
end

local function switch(parent, y, name, callback)
	text(parent, name, UDim2.fromOffset(12, y), UDim2.new(1, -80, 0, 28))
	local track = Instance.new('TextButton')
	track.Text = ''
	track.AutoButtonColor = false
	track.Position = UDim2.new(1, -62, 0, y + 2)
	track.Size = UDim2.fromOffset(50, 24)
	track.BackgroundColor3 = T.item
	track.BorderSizePixel = 0
	track.Parent = parent
	corner(track, 12)
	local knob = frame(track, UDim2.fromOffset(3, 3), UDim2.fromOffset(18, 18), T.text)
	corner(knob, 9)
	local state = false
	local function set(on)
		state = on
		TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = on and T.on or T.item }):Play()
		TweenService:Create(knob, TweenInfo.new(0.15), { Position = on and UDim2.fromOffset(29, 3) or UDim2.fromOffset(3, 3) }):Play()
		callback(on)
	end
	bind(track.MouseButton1Click, function() set(not state) end)
	return set
end

local function slider(parent, y, name, min, max, step, get, set)
	text(parent, name, UDim2.fromOffset(12, y), UDim2.new(0.5, 0, 0, 20))
	local valLbl = text(parent, tostring(get()), UDim2.new(0.5, 0, 0, y), UDim2.new(0.5, -12, 0, 20),
		{ align = Enum.TextXAlignment.Right, color = T.dim })
	local track = frame(parent, UDim2.new(0, 12, 0, y + 28), UDim2.new(1, -24, 0, 6), T.item)
	corner(track, 3)
	local fill = frame(track, UDim2.new(), UDim2.new(0, 0, 1, 0), T.accent)
	corner(fill, 3)
	local knob = frame(track, UDim2.new(0, 0, 0.5, -8), UDim2.fromOffset(16, 16), T.text)
	knob.AnchorPoint = Vector2.new(0.5, 0)
	corner(knob, 8)

	local function render()
		local a = (get() - min) / (max - min)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, -8)
		valLbl.Text = tostring(get())
	end
	local dragging = false
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v = min + a * (max - min)
		set(math.clamp(math.floor(v / step + 0.5) * step, min, max))
		render()
	end
	bind(track.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(i.Position.X)
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			fromX(i.Position.X)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	render()
end

-- ESP SECTION
local espCard = section('ESP', 130)
local espStatus
switch(espCard, 30, 'Object ESP', function(on)
	ESP.enabled = on
	ESP.refresh()
	if not espStatus then return end
	if not on then
		espStatus.Text = 'Off'
	elseif not ESP.getFolder() then
		espStatus.Text = 'Folder "' .. FOLDER_NAME .. '" not found'
	else
		local n = 0
		for _ in pairs(ESP.objects) do n += 1 end
		espStatus.Text = 'Tracking ' .. n .. ' model(s)'
	end
end)
text(espCard, 'Color', UDim2.fromOffset(12, 66), UDim2.fromOffset(60, 26))
local swatches = {}
for i, col in ipairs(ESP.colors) do
	local s = btn(espCard, '', UDim2.fromOffset(70 + (i - 1) * 36, 67), UDim2.fromOffset(28, 24), col)
	swatches[i] = s
	bind(s.MouseButton1Click, function()
		ESP.colorIndex = i
		ESP.recolor()
		for j, o in ipairs(swatches) do
			o.Text = j == i and '•' or ''
		end
	end)
end
swatches[1].Text = '•'
espStatus = text(espCard, 'Off', UDim2.fromOffset(12, 100), UDim2.new(1, -24, 0, 22), { color = T.dim, size = 12 })

-- AIMBOT SECTION
local aimCard = section('Aimbot', 190)
text(aimCard, 'Hold to aim', UDim2.fromOffset(12, 30), UDim2.new(0.4, 0, 0, 30))
local keyBtn = btn(aimCard, hotkeyName(), UDim2.new(0.4, 0, 0, 32), UDim2.new(0.6, -12, 0, 28))
slider(aimCard, 70, 'Smoothness', 1, 30, 1, function() return Aim.smooth end, function(v) Aim.smooth = v end)
slider(aimCard, 124, 'FOV radius', 30, 500, 10, function() return Aim.fov end, function(v)
	Aim.fov = v
	fovCircle.Size = UDim2.fromOffset(v * 2, v * 2)
end)

local function setHolding(on)
	if on == Aim.holding then return end
	Aim.holding = on
	if on then Aim.rescan() end
	fovCircle.Visible = on
end

bind(keyBtn.MouseButton1Click, function()
	setHolding(false)
	Aim.rebinding = true
	keyBtn.Text = 'Press any key...'
	setBase(keyBtn, T.accent)
end)

-- MISC SECTION
local miscCard = section('Misc', 70)
local originalSpeed
local function currentHum()
	return player.Character and player.Character:FindFirstChildOfClass('Humanoid')
end
switch(miscCard, 30, 'Fast Walk (50)', function(on)
	local hum = currentHum()
	if not hum then return end
	if on then
		originalSpeed = originalSpeed or hum.WalkSpeed
		hum.WalkSpeed = 50
	else
		hum.WalkSpeed = originalSpeed or 16
	end
end)

-- PANIC
order += 1
local panicBtn = btn(content, 'PANIC  -  DELETE HUB  (End)', UDim2.new(), UDim2.new(1, 0, 0, 42), T.danger)
panicBtn.LayoutOrder = order
panicBtn.TextSize = 14

local function panic()
	if destroyed then return end
	destroyed = true
	Aim.holding = false
	pcall(function() RunService:UnbindFromRenderStep('HubAim') end)
	ESP.enabled = false
	ESP.clear()
	ESP.disconnect()
	Aim.disconnect()
	local hum = currentHum()
	if hum and originalSpeed then hum.WalkSpeed = originalSpeed end
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
	gui:Destroy()
end
panicBtn.MouseButton1Click:Connect(panic)

-- SHOW / HIDE (old-TV effect)
local isOpen, busy = true, false
local function tween(obj, time, style, dir, goal)
	local t = TweenService:Create(obj, TweenInfo.new(time, style, dir), goal)
	t:Play()
	t.Completed:Wait()
end

local function setOpen(open)
	if busy or open == isOpen or destroyed then return end
	busy = true
	isOpen = open
	local w = FULL_SIZE.X.Offset
	if open then
		main.Size = UDim2.fromOffset(0, 3)
		main.GroupTransparency = 0
		main.Visible = true
		tween(main, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = UDim2.fromOffset(w, 3) })
		tween(main, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = FULL_SIZE })
	else
		tween(main, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Size = UDim2.fromOffset(w, 3) })
		TweenService:Create(main, TweenInfo.new(0.15), { GroupTransparency = 1 }):Play()
		tween(main, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Size = UDim2.fromOffset(0, 3) })
		main.Visible = false
		main.Size = FULL_SIZE
	end
	busy = false
end

-- INPUT
bind(UIS.InputBegan, function(input, processed)
	if input.KeyCode == PANIC_KEY then
		panic()
		return
	end

	if Aim.rebinding then
		local t = input.UserInputType
		local isKey = t == Enum.UserInputType.Keyboard
		local isMouse = t == Enum.UserInputType.MouseButton1
			or t == Enum.UserInputType.MouseButton2
			or t == Enum.UserInputType.MouseButton3
		if isKey or isMouse then
			Aim.rebinding = false
			if input.KeyCode ~= Enum.KeyCode.Escape then
				Aim.hotkey = isKey and input.KeyCode or t
			end
			keyBtn.Text = hotkeyName()
			setBase(keyBtn, T.item)
		end
		return
	end

	if matchesHotkey(input) then
		setHolding(true)
		return
	end

	if processed then return end
	if TOGGLE_KEYS[input.KeyCode] then setOpen(not isOpen) end
end)

bind(UIS.InputEnded, function(input)
	if matchesHotkey(input) then setHolding(false) end
end)

bind(UIS.WindowFocusReleased, function()
	setHolding(false)
end)
