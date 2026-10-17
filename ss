local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FOLDER_NAME = 'DhabWild'
local PANIC_KEY = Enum.KeyCode.End
local TOGGLE_KEYS = { [Enum.KeyCode.P] = true, [Enum.KeyCode.RightShift] = true }

-- THEMES
local function C(r, g, b) return Color3.fromRGB(r, g, b) end
local THEME_ORDER = {
	'Slate', 'Midnight', 'Graphite', 'Ocean', 'Forest', 'Rose',
	'Nord', 'Mocha', 'Lavender', 'Dracula', 'Sand', 'Paper',
}
local Themes = {
	Slate    = { bg = C(24,26,32),   panel = C(32,35,43),   item = C(44,48,58),   accent = C(112,140,190), text = C(226,229,236), dim = C(140,146,160), on = C(104,170,140), danger = C(190,90,95) },
	Midnight = { bg = C(14,16,26),   panel = C(21,24,38),   item = C(31,35,54),   accent = C(100,120,200), text = C(220,224,240), dim = C(125,132,160), on = C(90,165,150),  danger = C(185,85,100) },
	Graphite = { bg = C(20,20,20),   panel = C(29,29,29),   item = C(42,42,42),   accent = C(150,150,150), text = C(230,230,230), dim = C(135,135,135), on = C(120,165,130), danger = C(185,90,90) },
	Ocean    = { bg = C(14,28,36),   panel = C(20,40,50),   item = C(30,56,68),   accent = C(70,160,180),  text = C(222,238,242), dim = C(125,160,170), on = C(80,175,145),  danger = C(190,95,95) },
	Forest   = { bg = C(20,28,24),   panel = C(27,38,32),   item = C(38,52,44),   accent = C(110,165,120), text = C(226,236,228), dim = C(135,155,140), on = C(120,180,120), danger = C(185,95,90) },
	Rose     = { bg = C(32,22,28),   panel = C(43,30,38),   item = C(58,42,52),   accent = C(205,130,155), text = C(240,228,234), dim = C(165,140,152), on = C(130,175,145), danger = C(200,85,95) },
	Nord     = { bg = C(46,52,64),   panel = C(59,66,82),   item = C(67,76,94),   accent = C(136,192,208), text = C(236,239,244), dim = C(160,170,185), on = C(163,190,140), danger = C(191,97,106) },
	Mocha    = { bg = C(30,24,22),   panel = C(41,33,30),   item = C(56,46,42),   accent = C(196,148,100), text = C(236,226,218), dim = C(160,145,135), on = C(140,170,120), danger = C(188,92,85) },
	Lavender = { bg = C(28,25,38),   panel = C(38,34,52),   item = C(52,47,70),   accent = C(158,140,205), text = C(234,230,244), dim = C(150,144,175), on = C(120,175,150), danger = C(195,90,110) },
	Dracula  = { bg = C(40,42,54),   panel = C(52,55,70),   item = C(68,71,90),   accent = C(189,147,249), text = C(248,248,242), dim = C(145,150,180), on = C(80,200,120),  danger = C(255,95,95) },
	Sand     = { bg = C(236,230,218), panel = C(246,242,233), item = C(224,216,201), accent = C(170,125,80), text = C(55,50,44),    dim = C(130,122,110), on = C(95,150,105),  danger = C(190,85,80) },
	Paper    = { bg = C(238,240,244), panel = C(248,249,251), item = C(226,229,236), accent = C(90,120,180), text = C(40,44,54),    dim = C(120,126,140), on = C(80,155,120),  danger = C(195,80,85) },
}
local currentTheme = 'Slate'
local theme = Themes[currentTheme]

-- CONNECTION TRACKING (so panic can kill everything)
local connections = {}
local destroyed = false
local function bind(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

-- THEME REGISTRY
local updaters = {}
local function tw(obj, props, time)
	TweenService:Create(obj, TweenInfo.new(time or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function reg(fn)
	table.insert(updaters, fn)
	fn(theme, true)
end
local function applyTheme(name)
	currentTheme = name
	theme = Themes[name]
	for _, fn in ipairs(updaters) do fn(theme, false) end
end
local function set(obj, props, instant)
	if instant then
		for k, v in pairs(props) do obj[k] = v end
	else
		tw(obj, props)
	end
end

-- ESP
local ESP = {
	enabled = false,
	colorIndex = 1,
	colors = { C(255,170,0), C(0,255,120), C(0,170,255), C(255,60,60) },
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

-- role = theme key for the background color
local function frame(parent, pos, size, role)
	local f = Instance.new('Frame')
	f.Position = pos
	f.Size = size
	f.BorderSizePixel = 0
	f.Parent = parent
	reg(function(t, inst) set(f, { BackgroundColor3 = t[role] }, inst) end)
	return f
end

-- role = theme key for the text color
local function label(parent, str, pos, size, role, textSize, align, font)
	local l = Instance.new('TextLabel')
	l.Text = str
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.Gotham
	l.TextSize = textSize or 14
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	reg(function(t, inst) set(l, { TextColor3 = t[role or 'text'] }, inst) end)
	return l
end

-- kind = theme key used as the button color
local function button(parent, str, pos, size, kind)
	kind = kind or 'item'
	local b = Instance.new('TextButton')
	b.Text = str
	b.Position = pos
	b.Size = size
	b.TextSize = 13
	b.Font = Enum.Font.GothamMedium
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 8)
	local hovering = false
	local function target(t)
		local base = t[kind]
		return hovering and base:Lerp(t.text, 0.08) or base
	end
	reg(function(t, inst)
		set(b, { BackgroundColor3 = target(t), TextColor3 = (kind == 'danger' or kind == 'accent') and C(255, 255, 255) or t.text }, inst)
	end)
	bind(b.MouseEnter, function() hovering = true; tw(b, { BackgroundColor3 = target(theme) }, 0.15) end)
	bind(b.MouseLeave, function() hovering = false; tw(b, { BackgroundColor3 = target(theme) }, 0.15) end)
	return b
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
fovStroke.Thickness = 1
fovStroke.Transparency = 0.4
fovStroke.Parent = fovCircle
reg(function(t, inst) set(fovStroke, { Color = t.accent }, inst) end)

-- MAIN WINDOW
local FULL_SIZE = UDim2.fromOffset(380, 500)
local main = Instance.new('CanvasGroup')
main.Size = FULL_SIZE
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 12)
reg(function(t, inst) set(main, { BackgroundColor3 = t.bg }, inst) end)
local scale = Instance.new('UIScale')
scale.Parent = main

-- TITLE BAR (drag handle)
local titleBar = frame(main, UDim2.new(), UDim2.new(1, 0, 0, 44), 'panel')
label(titleBar, 'Script Hub', UDim2.fromOffset(16, 0), UDim2.new(1, -150, 1, 0), 'text', 15, nil, Enum.Font.GothamBold)
label(titleBar, 'P hide  ·  End panic', UDim2.new(1, -160, 0, 0), UDim2.fromOffset(148, 44), 'dim', 11, Enum.TextXAlignment.Right)

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

-- TAB BAR
local tabBar = frame(main, UDim2.fromOffset(12, 54), UDim2.new(1, -24, 0, 32), 'panel')
corner(tabBar, 8)
local pages, tabButtons = {}, {}
local activePage = 'Main'

local function refreshTabs(instant)
	for name, b in pairs(tabButtons) do
		local active = name == activePage
		set(b, {
			BackgroundTransparency = active and 0 or 1,
			TextColor3 = active and theme.text or theme.dim,
			BackgroundColor3 = theme.item,
		}, instant)
	end
end
reg(function(_, inst) refreshTabs(inst) end)

local function setPage(name)
	activePage = name
	for n, p in pairs(pages) do p.Visible = n == name end
	refreshTabs(false)
end

local function newPage(name, index, total)
	local b = Instance.new('TextButton')
	b.Text = name
	b.Size = UDim2.new(1 / total, -4, 1, -6)
	b.Position = UDim2.new((index - 1) / total, 2, 0, 3)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Parent = tabBar
	corner(b, 6)
	tabButtons[name] = b
	bind(b.MouseButton1Click, function() setPage(name) end)

	local page = Instance.new('ScrollingFrame')
	page.Position = UDim2.fromOffset(0, 94)
	page.Size = UDim2.new(1, 0, 1, -94)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 2
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = main
	reg(function(t, inst) set(page, { ScrollBarImageColor3 = t.dim }, inst) end)
	local pad = Instance.new('UIPadding')
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 2), UDim.new(0, 12)
	pad.Parent = page
	local list = Instance.new('UIListLayout')
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = page
	pages[name] = page
	return page
end

local mainPage = newPage('Main', 1, 2)
local themePage = newPage('Themes', 2, 2)

local orders = {}
local function nextOrder(page)
	orders[page] = (orders[page] or 0) + 1
	return orders[page]
end

local function section(page, title, height)
	local card = frame(page, UDim2.new(), UDim2.new(1, 0, 0, height), 'panel')
	card.LayoutOrder = nextOrder(page)
	corner(card, 10)
	label(card, title, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 18), 'dim', 12, nil, Enum.Font.GothamMedium)
	return card
end

local function switch(parent, y, name, callback)
	label(parent, name, UDim2.fromOffset(14, y), UDim2.new(1, -90, 0, 28), 'text', 14)
	local track = Instance.new('TextButton')
	track.Text = ''
	track.AutoButtonColor = false
	track.Position = UDim2.new(1, -62, 0, y + 2)
	track.Size = UDim2.fromOffset(46, 24)
	track.BorderSizePixel = 0
	track.Parent = parent
	corner(track, 12)
	local knob = Instance.new('Frame')
	knob.Position = UDim2.fromOffset(3, 3)
	knob.Size = UDim2.fromOffset(18, 18)
	knob.BorderSizePixel = 0
	knob.Parent = track
	corner(knob, 9)
	local state = false
	reg(function(t, inst)
		set(track, { BackgroundColor3 = state and t.on or t.item }, inst)
		set(knob, { BackgroundColor3 = t.text }, inst)
	end)
	bind(track.MouseButton1Click, function()
		state = not state
		tw(track, { BackgroundColor3 = state and theme.on or theme.item }, 0.2)
		tw(knob, { Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3) }, 0.2)
		callback(state)
	end)
end

local function slider(parent, y, name, min, max, step, get, setter)
	label(parent, name, UDim2.fromOffset(14, y), UDim2.new(0.5, 0, 0, 20), 'text', 13)
	local valLbl = label(parent, tostring(get()), UDim2.new(0.5, 0, 0, y), UDim2.new(0.5, -14, 0, 20), 'dim', 13, Enum.TextXAlignment.Right)
	local track = frame(parent, UDim2.new(0, 14, 0, y + 28), UDim2.new(1, -28, 0, 4), 'item')
	corner(track, 2)
	local fill = frame(track, UDim2.new(), UDim2.new(0, 0, 1, 0), 'accent')
	corner(fill, 2)
	local knob = frame(track, UDim2.new(0, 0, 0.5, -7), UDim2.fromOffset(14, 14), 'text')
	knob.AnchorPoint = Vector2.new(0.5, 0)
	corner(knob, 7)

	local function render(animate)
		local a = (get() - min) / (max - min)
		local fs, kp = UDim2.new(a, 0, 1, 0), UDim2.new(a, 0, 0.5, -7)
		if animate then
			tw(fill, { Size = fs }, 0.08)
			tw(knob, { Position = kp }, 0.08)
		else
			fill.Size, knob.Position = fs, kp
		end
		valLbl.Text = tostring(get())
	end
	local dragging = false
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v = min + a * (max - min)
		setter(math.clamp(math.floor(v / step + 0.5) * step, min, max))
		render(true)
	end
	-- larger invisible hit area
	local hit = Instance.new('TextButton')
	hit.Text = ''
	hit.BackgroundTransparency = 1
	hit.Position = UDim2.new(0, 14, 0, y + 20)
	hit.Size = UDim2.new(1, -28, 0, 20)
	hit.ZIndex = 5
	hit.Parent = parent
	bind(hit.InputBegan, function(i)
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
	render(false)
end

-- MAIN PAGE: ESP
local espCard = section(mainPage, 'ESP', 132)
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
label(espCard, 'Color', UDim2.fromOffset(14, 66), UDim2.fromOffset(60, 26), 'text', 13)
local swatches = {}
for i, col in ipairs(ESP.colors) do
	local s = Instance.new('TextButton')
	s.Text = ''
	s.AutoButtonColor = false
	s.Position = UDim2.fromOffset(74 + (i - 1) * 34, 68)
	s.Size = UDim2.fromOffset(22, 22)
	s.BackgroundColor3 = col
	s.BorderSizePixel = 0
	s.Parent = espCard
	corner(s, 11)
	local ring = Instance.new('UIStroke')
	ring.Thickness = 2
	ring.Transparency = i == 1 and 0 or 1
	ring.Parent = s
	reg(function(t, inst) set(ring, { Color = t.text }, inst) end)
	swatches[i] = ring
	bind(s.MouseButton1Click, function()
		ESP.colorIndex = i
		ESP.recolor()
		for j, r in ipairs(swatches) do tw(r, { Transparency = j == i and 0 or 1 }, 0.15) end
	end)
end
espStatus = label(espCard, 'Off', UDim2.fromOffset(14, 102), UDim2.new(1, -28, 0, 22), 'dim', 12)

-- MAIN PAGE: AIMBOT
local aimCard = section(mainPage, 'Aimbot', 194)
label(aimCard, 'Hold to aim', UDim2.fromOffset(14, 32), UDim2.new(0.4, 0, 0, 30), 'text', 14)
local keyBtn = button(aimCard, hotkeyName(), UDim2.new(0.4, 0, 0, 34), UDim2.new(0.6, -14, 0, 28))
slider(aimCard, 72, 'Smoothness', 1, 30, 1, function() return Aim.smooth end, function(v) Aim.smooth = v end)
slider(aimCard, 126, 'FOV radius', 30, 500, 10, function() return Aim.fov end, function(v)
	Aim.fov = v
	tw(fovCircle, { Size = UDim2.fromOffset(v * 2, v * 2) }, 0.08)
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
end)

-- MAIN PAGE: MISC
local miscCard = section(mainPage, 'Misc', 72)
local originalSpeed
local function currentHum()
	return player.Character and player.Character:FindFirstChildOfClass('Humanoid')
end
switch(miscCard, 32, 'Fast Walk (50)', function(on)
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
local panicBtn = button(mainPage, 'Panic  -  delete hub  (End)', UDim2.new(), UDim2.new(1, 0, 0, 38), 'danger')
panicBtn.LayoutOrder = nextOrder(mainPage)

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
	table.clear(updaters)
	gui:Destroy()
end
bind(panicBtn.MouseButton1Click, panic)

-- THEMES PAGE
local themeCard = section(themePage, 'Choose a theme', 30 + #THEME_ORDER * 40 + 8)
for i, name in ipairs(THEME_ORDER) do
	local th = Themes[name]
	local row = Instance.new('TextButton')
	row.Text = ''
	row.AutoButtonColor = false
	row.Position = UDim2.fromOffset(10, 30 + (i - 1) * 40)
	row.Size = UDim2.new(1, -20, 0, 34)
	row.BorderSizePixel = 0
	row.Parent = themeCard
	corner(row, 8)
	-- preview swatches (fixed colors from that theme)
	for k, key in ipairs({ 'bg', 'item', 'accent' }) do
		local dot = Instance.new('Frame')
		dot.Position = UDim2.fromOffset(10 + (k - 1) * 18, 9)
		dot.Size = UDim2.fromOffset(16, 16)
		dot.BackgroundColor3 = th[key]
		dot.BorderSizePixel = 0
		dot.Parent = row
		corner(dot, 8)
		local s = Instance.new('UIStroke')
		s.Color = C(128, 128, 128)
		s.Transparency = 0.7
		s.Parent = dot
	end
	label(row, name, UDim2.fromOffset(72, 0), UDim2.new(1, -110, 1, 0), 'text', 14)
	local check = label(row, '✓', UDim2.new(1, -30, 0, 0), UDim2.fromOffset(24, 34), 'accent', 16, Enum.TextXAlignment.Center, Enum.Font.GothamBold)
	local hovering = false
	local function refresh(t, inst)
		local selected = currentTheme == name
		local bg = selected and t.item or t.panel
		if hovering and not selected then bg = t.item:Lerp(t.panel, 0.5) end
		set(row, { BackgroundColor3 = bg }, inst)
		set(check, { TextTransparency = selected and 0 or 1 }, inst)
	end
	reg(refresh)
	bind(row.MouseEnter, function() hovering = true; refresh(theme, false) end)
	bind(row.MouseLeave, function() hovering = false; refresh(theme, false) end)
	bind(row.MouseButton1Click, function() applyTheme(name) end)
end

setPage('Main')

-- SHOW / HIDE (soft fade + slight scale)
local isOpen, busy = true, false
local function setOpen(open)
	if busy or open == isOpen or destroyed then return end
	busy = true
	isOpen = open
	local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, open and Enum.EasingDirection.Out or Enum.EasingDirection.In)
	if open then
		scale.Scale = 0.96
		main.GroupTransparency = 1
		main.Visible = true
		TweenService:Create(scale, info, { Scale = 1 }):Play()
		local t = TweenService:Create(main, info, { GroupTransparency = 0 })
		t:Play()
		t.Completed:Wait()
	else
		TweenService:Create(scale, info, { Scale = 0.96 }):Play()
		local t = TweenService:Create(main, info, { GroupTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		main.Visible = false
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
