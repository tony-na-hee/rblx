--!nocheck
-- ██╗   ██╗██╗    NeonUI — cyber-neon UI framework
-- ██║   ██║██║    แยกออกมาจาก AdminMode ให้โปรแกรมอื่นเรียกใช้ผ่าน loadstring จาก GitHub
-- ██║   ██║██║    by DevNick
-- ╚██████╔╝██║
--  ╚═════╝ ╚═╝
--
-- วิธีใช้ (โหลดจาก GitHub raw):
--   local NeonUI = loadstring(game:HttpGet("https://<user>.github.io/NeonUI.lua"))()
--   local Win = NeonUI:CreateWindow({ Title = "AdminMode", Icon = "⚡", Version = "v3" })
--   local tab = Win:CreateTab("Players", "🧍")
--   tab:Section("Movement")
--   tab:Toggle({ Text = "Fly", Default = false, Callback = function(v) print(v) end })
--   tab:Slider({ Text = "Speed", Min = 16, Max = 200, Default = 16, Callback = function(v) end })
--   tab:Button({ Text = "Reset", Callback = function() end })
--   NeonUI:Notify("พร้อมใช้งาน", 2)
-- (ตัวอย่างเต็มอยู่ท้ายไฟล์ในคอมเมนต์ EXAMPLE)

--------------------------------------------------------------
-- Services
--------------------------------------------------------------
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------
-- Module + ค่าเริ่มต้น (defaults)
--------------------------------------------------------------
local NeonUI = {}
NeonUI.__index = NeonUI
NeonUI.Version = "1.0.0"

-- จานสีฐาน (dark) — cyber-neon. ธีมจะ override เฉพาะ role ที่อยากเปลี่ยน (ปกติแค่ Accent)
local BASE_PALETTE = {
    BG          = Color3.fromRGB(7, 9, 16),       -- ดำอมน้ำเงิน (พื้นนอกสุด)
    Panel       = Color3.fromRGB(12, 15, 26),     -- พื้น panel / sidebar / titlebar
    Card        = Color3.fromRGB(20, 25, 42),     -- การ์ด / แถว
    CardHover   = Color3.fromRGB(30, 38, 62),     -- การ์ดตอน hover
    Accent      = Color3.fromRGB(56, 225, 255),   -- ฟ้านีออน (เรืองแสง)
    Green       = Color3.fromRGB(54, 230, 160),   -- เขียวมิ้นต์นีออน
    Red         = Color3.fromRGB(255, 92, 122),   -- ชมพูแดงนีออน
    Orange      = Color3.fromRGB(255, 200, 87),   -- เหลืองทอง
    Text        = Color3.fromRGB(234, 242, 255),
    TextDim     = Color3.fromRGB(124, 137, 176),
    Input       = Color3.fromRGB(14, 18, 32),
    Stroke      = Color3.fromRGB(40, 70, 120),    -- ขอบโทนฟ้าเข้ม
}

-- ธีมสำเร็จรูป: name + override ทับ BASE_PALETTE (ต่างกันแค่ accent = สลับสดได้ลื่น)
-- อยากทำธีมสว่าง/ธีมทั้งชุด ก็ใส่ key เพิ่มใน table ได้เลย เช่น { name="Light", BG=..., Panel=..., Accent=... }
NeonUI.Themes = {
    { name = "Neon",   Accent = Color3.fromRGB(56, 225, 255) },  -- ฟ้านีออน (ดีฟอลต์)
    { name = "Blue",   Accent = Color3.fromRGB(88, 130, 255) },
    { name = "Purple", Accent = Color3.fromRGB(158, 110, 255) },
    { name = "Pink",   Accent = Color3.fromRGB(255, 96, 178) },
    { name = "Green",  Accent = Color3.fromRGB(48, 206, 124) },
    { name = "Cyan",   Accent = Color3.fromRGB(46, 206, 224) },
    { name = "Orange", Accent = Color3.fromRGB(248, 152, 44) },
    { name = "Red",    Accent = Color3.fromRGB(236, 78, 78) },
}

-- จานสีที่ใช้งานจริงตอนนี้ (mutable) — เริ่มจาก base, ปรับได้ผ่าน SetTheme/SetAccent
local C = {}
for k, v in pairs(BASE_PALETTE) do C[k] = v end
NeonUI.Palette = C

--------------------------------------------------------------
-- Registry: จำ object + prop + role ไว้ เพื่อสลับธีมแบบ live ทั้งชุด
--   role = key ในจานสี (เช่น "Accent", "Card", "Text"...) เวลาเปลี่ยนธีมจะไล่ปรับให้เอง
--------------------------------------------------------------
local Themed = {}   -- { {obj=, prop=, role=} , ... }
local function register(obj, prop, role)
    table.insert(Themed, { obj = obj, prop = prop or "BackgroundColor3", role = role or "Accent" })
    return obj
end

--------------------------------------------------------------
-- Utils
--------------------------------------------------------------
-- คืน v ถ้าไม่ใช่ nil (กัน false โดน and/or กลืน)
local function pick(v, default)
    if v == nil then return default end
    return v
end

-- ทำสีให้สว่างขึ้น (ใช้ตอน hover ปุ่ม)
local function lighten(col, f)
    f = f or 1.18
    return Color3.new(math.min(col.R * f, 1), math.min(col.G * f, 1), math.min(col.B * f, 1))
end

-- แปลงสตริง role ("Accent"/"Green"/...) หรือ Color3 → Color3
local function resolveColor(v, fallback)
    if typeof(v) == "Color3" then return v end
    if type(v) == "string" and C[v] then return C[v] end
    return fallback or C.Accent
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or C.Stroke
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    p.Parent = parent
    return p
end

local function listLayout(parent, pad, sort)
    local ll = Instance.new("UIListLayout")
    ll.SortOrder = sort or Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, pad or 4)
    ll.Parent = parent
    return ll
end

local function tween(obj, props, duration, style)
    local ti = TweenInfo.new(duration or 0.22, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, ti, props)
    tw:Play()
    return tw
end
NeonUI.tween = tween  -- เผื่อโปรแกรมอื่นอยากใช้ tween helper เดียวกัน

-- เลือกที่ parent ScreenGui ที่ปลอดภัยสุดบน executor (gethui > CoreGui > PlayerGui)
local function safeParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2 = pcall(function() return CoreGui.Name end)
    if ok2 then return CoreGui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

--------------------------------------------------------------
-- Theme swap
--------------------------------------------------------------
local function applyPalette(animated)
    local d = animated and 0.2 or 0
    for _, e in ipairs(Themed) do
        local col = C[e.role]
        if e.obj and e.obj.Parent and col then
            pcall(function()
                if d > 0 then tween(e.obj, { [e.prop] = col }, d) else e.obj[e.prop] = col end
            end)
        end
    end
end

-- ปรับเฉพาะสี Accent (เร็ว ลื่น) — คืน true ถ้าสำเร็จ
function NeonUI:SetAccent(color)
    C.Accent = resolveColor(color)
    applyPalette(true)
    return true
end

-- สลับธีมทั้งชุดตามชื่อ (หรือส่ง table ธีมเองก็ได้)
function NeonUI:SetTheme(nameOrTable)
    local theme = nameOrTable
    if type(nameOrTable) == "string" then
        for _, t in ipairs(self.Themes) do
            if t.name:lower() == nameOrTable:lower() then theme = t; break end
        end
    end
    if type(theme) ~= "table" then return false end
    -- reset เป็น base ก่อน แล้ว override ตามธีม (รองรับ full-palette swap)
    for k, v in pairs(BASE_PALETTE) do C[k] = v end
    for k, v in pairs(theme) do
        if k ~= "name" and typeof(v) == "Color3" then C[k] = v end
    end
    applyPalette(true)
    return true
end

--------------------------------------------------------------
-- Component factories (widgets)
--------------------------------------------------------------
local function makeButton(parent, text, size, color)
    local base = resolveColor(color, C.Accent)
    local btn = Instance.new("TextButton")
    btn.Size = size or UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = base
    btn.BorderSizePixel = 0
    btn.Text = text or ""
    btn.TextColor3 = C.Text
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    corner(btn, 6)
    btn.Parent = parent
    -- ถ้าสีปุ่มมาจาก role ในจานสี → ผูกกับธีมด้วย (สลับธีมแล้วปุ่มตามสี)
    if type(color) == "string" and C[color] then register(btn, "BackgroundColor3", color) end

    local curBase = base
    btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = lighten(curBase) }, 0.14) end)
    btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = curBase }, 0.14) end)
    btn.MouseButton1Down:Connect(function()
        tween(btn, { Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset - 2, btn.Size.Y.Scale, btn.Size.Y.Offset - 2) }, 0.08)
    end)
    btn.MouseButton1Up:Connect(function()
        tween(btn, { Size = size or UDim2.new(1, 0, 0, 32) }, 0.08)
    end)
    return btn
end

local function makeInput(parent, placeholder, size)
    local frame = Instance.new("Frame")
    frame.Size = size or UDim2.new(1, 0, 0, 32)
    frame.BackgroundColor3 = C.Input
    frame.BorderSizePixel = 0
    corner(frame, 6)
    stroke(frame, C.Stroke, 1, 0.4)
    register(frame, "BackgroundColor3", "Input")
    frame.Parent = parent

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, -12, 1, 0)
    tb.Position = UDim2.new(0, 6, 0, 0)
    tb.BackgroundTransparency = 1
    tb.PlaceholderText = placeholder or ""
    tb.PlaceholderColor3 = C.TextDim
    tb.Text = ""
    tb.TextColor3 = C.Text
    tb.TextSize = 12
    tb.Font = Enum.Font.Gotham
    tb.ClearTextOnFocus = false
    tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.Parent = frame
    return tb, frame
end

local function sectionTitle(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text or ""
    lbl.TextColor3 = C.TextDim
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order or 0
    lbl.Parent = parent
    register(lbl, "TextColor3", "TextDim")
    return lbl
end

local function makeToggle(parent, labelText, default, order, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = C.Card
    row.BorderSizePixel = 0
    row.LayoutOrder = order or 0
    corner(row, 6)
    register(row, "BackgroundColor3", "Card")
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -64, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText or ""
    lbl.TextColor3 = C.Text
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 42, 0, 22)
    track.Position = UDim2.new(1, -52, 0.5, -11)
    track.BackgroundColor3 = C.Input
    track.BorderSizePixel = 0
    corner(track, 11)
    track.Parent = row

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = C.Text
    knob.BorderSizePixel = 0
    corner(knob, 8)
    knob.Parent = track

    local state = default and true or false
    local function render(animated)
        local d = animated and 0.16 or 0
        tween(track, { BackgroundColor3 = state and C.Green or C.Input }, d)
        tween(knob, { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) }, d)
    end
    render(false)

    local click = Instance.new("TextButton")
    click.Size = UDim2.new(1, 0, 1, 0)
    click.BackgroundTransparency = 1
    click.Text = ""
    click.Parent = row

    click.MouseButton1Click:Connect(function()
        state = not state
        render(true)
        if callback then task.spawn(callback, state) end
    end)

    return {
        set = function(v, fire)
            state = v and true or false
            render(true)
            if fire and callback then task.spawn(callback, state) end
        end,
        get = function() return state end,
        row = row,
    }
end

local function makeSlider(parent, labelText, minV, maxV, default, step, fmt, order, onChange, conns)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 48)
    holder.BackgroundColor3 = C.Card
    holder.BorderSizePixel = 0
    holder.LayoutOrder = order or 0
    corner(holder, 6)
    register(holder, "BackgroundColor3", "Card")
    holder.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7, 0, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, 7)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText or ""
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextColor3 = C.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder

    local valBox = Instance.new("TextBox")
    valBox.Size = UDim2.new(0.3, -10, 0, 18)
    valBox.Position = UDim2.new(0.7, 0, 0, 7)
    valBox.BackgroundTransparency = 1
    valBox.Font = Enum.Font.GothamBold
    valBox.TextSize = 12
    valBox.TextColor3 = C.Accent
    valBox.TextXAlignment = Enum.TextXAlignment.Right
    valBox.ClearTextOnFocus = false
    valBox.Text = ""
    valBox.Parent = holder
    register(valBox, "TextColor3", "Accent")

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -20, 0, 6)
    barBg.Position = UDim2.new(0, 10, 0, 34)
    barBg.BackgroundColor3 = C.Input
    barBg.BorderSizePixel = 0
    corner(barBg, 3)
    barBg.Parent = holder

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = C.Accent
    fill.BorderSizePixel = 0
    corner(fill, 3)
    fill.Parent = barBg
    register(fill, "BackgroundColor3", "Accent")

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = C.Text
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    corner(knob, 7)
    knob.Parent = barBg

    local value = default
    local function applyAlpha(a, fire)
        a = math.clamp(a, 0, 1)
        value = minV + (maxV - minV) * a
        if step then value = math.floor(value / step + 0.5) * step end
        value = math.clamp(value, minV, maxV)
        local alpha = (maxV > minV) and (value - minV) / (maxV - minV) or 0
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valBox.Text = fmt and string.format(fmt, value) or tostring(value)
        if fire and onChange then task.spawn(onChange, value) end
    end
    applyAlpha((maxV > minV) and (default - minV) / (maxV - minV) or 0, false)

    valBox.FocusLost:Connect(function()
        local n = tonumber(valBox.Text)
        if n then applyAlpha((n - minV) / (maxV - minV), true)
        else valBox.Text = fmt and string.format(fmt, value) or tostring(value) end
    end)

    local dragging = false
    local function update(input)
        local rel = (input.Position.X - barBg.AbsolutePosition.X) / math.max(barBg.AbsoluteSize.X, 1)
        applyAlpha(rel, true)
    end
    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(input)
        end
    end)
    -- เก็บ connection ระดับ input ไว้กับ window เพื่อ Destroy ได้สะอาด
    local c1 = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
    end)
    local c2 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    if conns then table.insert(conns, c1); table.insert(conns, c2) end

    return {
        set = function(v, fire) applyAlpha((v - minV) / (maxV - minV), fire and true or false) end,
        get = function() return value end,
        holder = holder,
    }
end

--------------------------------------------------------------
-- Notification (global — 1 container ต่อทั้ง executor)
--------------------------------------------------------------
local NotifGui, NotifContainer
local function ensureNotif()
    if NotifContainer and NotifContainer.Parent then return end
    NotifGui = Instance.new("ScreenGui")
    NotifGui.Name = "NeonUI_Notify"
    NotifGui.ResetOnSpawn = false
    NotifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    NotifGui.IgnoreGuiInset = true
    NotifGui.DisplayOrder = 1000
    NotifGui.Parent = safeParent()

    NotifContainer = Instance.new("Frame")
    NotifContainer.Name = "Notifications"
    NotifContainer.Size = UDim2.new(0, 290, 1, -20)
    NotifContainer.Position = UDim2.new(1, -300, 0, 10)
    NotifContainer.BackgroundTransparency = 1
    NotifContainer.ZIndex = 500
    NotifContainer.Parent = NotifGui
    local ll = listLayout(NotifContainer, 6)
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Right
    ll.VerticalAlignment = Enum.VerticalAlignment.Top
end

-- NeonUI:Notify("ข้อความ", 3)  หรือ  NeonUI:Notify({ Text=, Duration=, Color= })
function NeonUI:Notify(a, b, c)
    local text, duration, color
    if type(a) == "table" then
        text = a.Text or a.text or ""
        duration = a.Duration or a.duration or 3
        color = resolveColor(a.Color or a.color, C.Accent)
    else
        text, duration, color = tostring(a), b or 3, resolveColor(c, C.Accent)
    end
    ensureNotif()

    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, 0)
    notif.AutomaticSize = Enum.AutomaticSize.Y
    notif.BackgroundColor3 = C.Panel
    notif.BackgroundTransparency = 1
    notif.BorderSizePixel = 0
    notif.ZIndex = 501
    corner(notif, 8)
    local st = stroke(notif, color, 1, 0.3)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, -12)
    bar.Position = UDim2.new(0, 7, 0, 6)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    bar.ZIndex = 502
    corner(bar, 2)
    bar.Parent = notif

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -28, 1, 0)
    label.Position = UDim2.new(0, 18, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = C.Text
    label.TextSize = 12
    label.Font = Enum.Font.GothamMedium
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 502
    padding(label, 9, 9, 0, 0)
    label.Parent = notif
    notif.Parent = NotifContainer

    -- เฟดเข้า → รอ → เฟดออก
    tween(notif, { BackgroundTransparency = 0 }, 0.2)
    task.delay(duration, function()
        if not notif.Parent then return end
        tween(notif, { BackgroundTransparency = 1 }, 0.25)
        tween(st, { Transparency = 1 }, 0.25)
        tween(label, { TextTransparency = 1 }, 0.25)
        tween(bar, { BackgroundTransparency = 1 }, 0.25)
        task.wait(0.3)
        notif:Destroy()
    end)
    return notif
end

--------------------------------------------------------------
-- Tab object (คืนจาก Window:CreateTab) — มี method สร้าง widget
--------------------------------------------------------------
local Tab = {}
Tab.__index = Tab

function Tab:Section(text)
    self._order += 1
    return sectionTitle(self.page, text, self._order)
end

function Tab:Button(opts)
    opts = opts or {}
    self._order += 1
    local btn = makeButton(self.page, opts.Text or opts.text or "Button", UDim2.new(1, 0, 0, 34), opts.Color or opts.color)
    btn.LayoutOrder = self._order
    local cb = opts.Callback or opts.callback
    if cb then btn.MouseButton1Click:Connect(function() task.spawn(cb) end) end
    return btn
end

function Tab:Toggle(opts)
    opts = opts or {}
    self._order += 1
    local t = makeToggle(self.page, opts.Text or opts.text or "Toggle",
        pick(opts.Default, opts.default), self._order, opts.Callback or opts.callback)
    if opts.Flag then self.window.Flags[opts.Flag] = t end
    return t
end

function Tab:Slider(opts)
    opts = opts or {}
    self._order += 1
    local s = makeSlider(self.page, opts.Text or opts.text or "Slider",
        opts.Min or opts.min or 0, opts.Max or opts.max or 100,
        pick(opts.Default, pick(opts.default, opts.Min or 0)),
        opts.Step or opts.step, opts.Format or opts.fmt,
        self._order, opts.Callback or opts.callback, self.window._conns)
    if opts.Flag then self.window.Flags[opts.Flag] = s end
    return s
end

function Tab:Input(opts)
    opts = opts or {}
    self._order += 1
    local tb, frame = makeInput(self.page, opts.Placeholder or opts.placeholder or "", UDim2.new(1, 0, 0, 32))
    frame.LayoutOrder = self._order
    if opts.Text then tb.Text = opts.Text end
    local cb = opts.Callback or opts.callback
    if cb then
        tb.FocusLost:Connect(function(enter)
            if opts.OnEnter and not enter then return end
            task.spawn(cb, tb.Text)
        end)
    end
    return tb, frame
end

-- ป้ายข้อความอิสระ
function Tab:Label(text)
    self._order += 1
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text or ""
    lbl.TextColor3 = C.Text
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.LayoutOrder = self._order
    lbl.Parent = self.page
    return lbl
end

-- แผงเลือกธีมสำเร็จรูป (สวอตช์สี 8 ธีม) — เรียกครั้งเดียวในแท็บ Settings
function Tab:ThemePicker(titleText)
    self:Section(titleText or "🎨 ธีมสี")
    self._order += 1
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 64)
    row.BackgroundColor3 = C.Card
    row.BorderSizePixel = 0
    row.LayoutOrder = self._order
    corner(row, 6)
    register(row, "BackgroundColor3", "Card")
    row.Parent = self.page
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 36, 0, 24)
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.FillDirectionMaxCells = 7
    grid.Parent = row
    padding(row, 8, 8, 8, 8)

    for _, theme in ipairs(NeonUI.Themes) do
        local sw = Instance.new("TextButton")
        sw.BackgroundColor3 = theme.Accent
        sw.Text = ""
        sw.BorderSizePixel = 0
        sw.AutoButtonColor = false
        corner(sw, 6)
        sw.Parent = row
        sw.MouseButton1Click:Connect(function()
            NeonUI:SetTheme(theme)
            NeonUI:Notify("ธีม: " .. theme.name, 1.4, theme.Accent)
            if self.window.OnThemeChanged then task.spawn(self.window.OnThemeChanged, theme) end
        end)
    end
    return row
end

--------------------------------------------------------------
-- Window object
--------------------------------------------------------------
local Window = {}
Window.__index = Window

function NeonUI.CreateWindow(_, opts)   -- เรียกด้วย NeonUI:CreateWindow{...} (arg แรกคือ module ทิ้งไป)
    opts = opts or {}
    local self = setmetatable({}, Window)
    self.Flags = {}          -- Flag -> widget (เข้าถึงค่าภายหลัง)
    self.Tabs = {}
    self._tabButtons = {}
    self._conns = {}         -- connection ที่ต้อง disconnect ตอน Destroy
    self._activeTab = nil
    self.OnThemeChanged = opts.OnThemeChanged

    -- ตั้งธีมเริ่มต้น (ถ้าระบุ)
    if opts.Theme then NeonUI:SetTheme(opts.Theme) end
    if opts.Accent then NeonUI:SetAccent(opts.Accent) end

    local size = opts.Size or UDim2.new(0, 500, 0, 568)
    local toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
    local showStatus = pick(opts.StatusBar, true)

    --------------------------------------------------
    -- ScreenGui
    --------------------------------------------------
    local gui = Instance.new("ScreenGui")
    gui.Name = opts.Name or ("NeonUI_" .. (opts.Title or "Window"))
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = opts.DisplayOrder or 999
    -- ลบ GUI เก่าชื่อเดียวกันกันซ้อน
    do
        local parent = safeParent()
        local old = parent:FindFirstChild(gui.Name)
        if old then old:Destroy() end
        gui.Parent = parent
    end
    self.gui = gui

    --------------------------------------------------
    -- Main frame + shadow + neon glow
    --------------------------------------------------
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = size
    Main.Position = opts.Position or UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2)
    Main.BackgroundColor3 = C.BG
    Main.BorderSizePixel = 0
    corner(Main, 12)
    local MainStroke = stroke(Main, C.Accent, 1.4, 0.35)
    register(MainStroke, "Color", "Accent")
    Main.Parent = gui
    self.Main = Main

    local UIScaleObj = Instance.new("UIScale")
    UIScaleObj.Scale = opts.Scale or 1
    UIScaleObj.Parent = Main
    self.UIScale = UIScaleObj

    local Shadow = Instance.new("ImageLabel")
    Shadow.Name = "Shadow"
    Shadow.Size = UDim2.new(1, 40, 1, 40)
    Shadow.Position = UDim2.new(0, -20, 0, -20)
    Shadow.BackgroundTransparency = 1
    Shadow.Image = "rbxassetid://6014261993"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.45
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    Shadow.ZIndex = 0
    Shadow.Parent = Main

    local NeonGlow = Instance.new("ImageLabel")
    NeonGlow.Name = "NeonGlow"
    NeonGlow.Size = UDim2.new(1, 64, 1, 64)
    NeonGlow.Position = UDim2.new(0, -32, 0, -32)
    NeonGlow.BackgroundTransparency = 1
    NeonGlow.Image = "rbxassetid://6014261993"
    NeonGlow.ImageColor3 = C.Accent
    NeonGlow.ImageTransparency = 0.55
    NeonGlow.ScaleType = Enum.ScaleType.Slice
    NeonGlow.SliceCenter = Rect.new(49, 49, 450, 450)
    NeonGlow.ZIndex = 0
    NeonGlow.Parent = Main
    register(NeonGlow, "ImageColor3", "Accent")

    --------------------------------------------------
    -- Title bar + drag
    --------------------------------------------------
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 42)
    TitleBar.BackgroundColor3 = C.Panel
    TitleBar.BorderSizePixel = 0
    TitleBar.ZIndex = 5
    corner(TitleBar, 12)
    register(TitleBar, "BackgroundColor3", "Panel")
    TitleBar.Parent = Main

    local TitleBarFix = Instance.new("Frame")
    TitleBarFix.Size = UDim2.new(1, 0, 0, 14)
    TitleBarFix.Position = UDim2.new(0, 0, 1, -14)
    TitleBarFix.BackgroundColor3 = C.Panel
    TitleBarFix.BorderSizePixel = 0
    TitleBarFix.ZIndex = 5
    register(TitleBarFix, "BackgroundColor3", "Panel")
    TitleBarFix.Parent = TitleBar

    local AccentLine = Instance.new("Frame")
    AccentLine.Size = UDim2.new(1, 0, 0, 2)
    AccentLine.Position = UDim2.new(0, 0, 1, -1)
    AccentLine.BackgroundColor3 = C.Accent
    AccentLine.BorderSizePixel = 0
    AccentLine.ZIndex = 6
    AccentLine.Parent = TitleBar
    register(AccentLine, "BackgroundColor3", "Accent")

    local TitleIcon = Instance.new("TextLabel")
    TitleIcon.Size = UDim2.new(0, 30, 1, 0)
    TitleIcon.Position = UDim2.new(0, 10, 0, 0)
    TitleIcon.BackgroundTransparency = 1
    TitleIcon.Text = opts.Icon or "⚡"
    TitleIcon.TextColor3 = C.Accent
    TitleIcon.TextSize = 20
    TitleIcon.Font = Enum.Font.GothamBold
    TitleIcon.ZIndex = 6
    TitleIcon.Parent = TitleBar
    register(TitleIcon, "TextColor3", "Accent")

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -200, 1, 0)
    TitleLabel.Position = UDim2.new(0, 40, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = opts.Title or "NeonUI"
    TitleLabel.TextColor3 = C.Text
    TitleLabel.TextSize = 16
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 6
    TitleLabel.Parent = TitleBar

    if opts.Version then
        local VerTag = Instance.new("TextLabel")
        local w = 20 + #tostring(opts.Version) * 6
        VerTag.Size = UDim2.new(0, w, 0, 16)
        -- วางถัดจากชื่อ (กะจากความยาวชื่อโดยประมาณ)
        VerTag.Position = UDim2.new(0, 40 + math.min(#(opts.Title or "") * 9 + 6, 150), 0.5, -8)
        VerTag.BackgroundColor3 = C.Accent
        VerTag.Text = tostring(opts.Version)
        VerTag.TextColor3 = C.Text
        VerTag.TextSize = 10
        VerTag.Font = Enum.Font.GothamBold
        VerTag.ZIndex = 6
        corner(VerTag, 4)
        VerTag.Parent = TitleBar
        register(VerTag, "BackgroundColor3", "Accent")
    end

    -- ปุ่ม minimize (ย่อเหลือ title bar) + close (ซ่อนเหลือ FAB)
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 30, 0, 30)
    MinBtn.Position = UDim2.new(1, -70, 0.5, -15)
    MinBtn.BackgroundColor3 = C.Orange
    MinBtn.BorderSizePixel = 0
    MinBtn.Text = "—"
    MinBtn.TextColor3 = C.Text
    MinBtn.TextSize = 16
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.AutoButtonColor = false
    MinBtn.ZIndex = 6
    corner(MinBtn, 6)
    register(MinBtn, "BackgroundColor3", "Orange")
    MinBtn.Parent = TitleBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -36, 0.5, -15)
    CloseBtn.BackgroundColor3 = C.Red
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = C.Text
    CloseBtn.TextSize = 13
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.AutoButtonColor = false
    CloseBtn.ZIndex = 6
    corner(CloseBtn, 6)
    register(CloseBtn, "BackgroundColor3", "Red")
    CloseBtn.Parent = TitleBar

    -- drag (เมาส์ + มือถือ)
    do
        local dragging, dragStart, startPos
        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = Main.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        local dc = UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        table.insert(self._conns, dc)
    end

    --------------------------------------------------
    -- Status bar (FPS / ping / players)
    --------------------------------------------------
    local bodyY = showStatus and 72 or 42
    if showStatus then
        local StatusBar = Instance.new("Frame")
        StatusBar.Name = "StatusBar"
        StatusBar.Size = UDim2.new(1, 0, 0, 30)
        StatusBar.Position = UDim2.new(0, 0, 0, 42)
        StatusBar.BackgroundColor3 = C.Panel
        StatusBar.BorderSizePixel = 0
        StatusBar.ZIndex = 4
        StatusBar.Parent = Main
        padding(StatusBar, 5, 5, 8, 8)
        register(StatusBar, "BackgroundColor3", "Panel")

        local sl = Instance.new("UIListLayout")
        sl.FillDirection = Enum.FillDirection.Horizontal
        sl.VerticalAlignment = Enum.VerticalAlignment.Center
        sl.Padding = UDim.new(0, 6)
        sl.SortOrder = Enum.SortOrder.LayoutOrder
        sl.Parent = StatusBar

        local function makeStat(order, initText, col)
            local chip = Instance.new("Frame")
            chip.AutomaticSize = Enum.AutomaticSize.X
            chip.Size = UDim2.new(0, 0, 1, -4)
            chip.BackgroundColor3 = C.Card
            chip.BorderSizePixel = 0
            chip.LayoutOrder = order
            chip.ZIndex = 4
            corner(chip, 6)
            chip.Parent = StatusBar
            padding(chip, 0, 0, 9, 10)
            register(chip, "BackgroundColor3", "Card")

            local lbl = Instance.new("TextLabel")
            lbl.AutomaticSize = Enum.AutomaticSize.X
            lbl.Size = UDim2.new(0, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.RichText = true
            lbl.Text = initText
            lbl.TextColor3 = col or C.Text
            lbl.TextSize = 11
            lbl.Font = Enum.Font.GothamBold
            lbl.ZIndex = 5
            lbl.Parent = chip
            return lbl
        end

        local FpsStat     = makeStat(1, "⚡ -- fps", C.Green)
        local PingStat    = makeStat(2, "📶 -- ms", C.Accent)
        local PlayersStat = makeStat(3, "👥 0", C.Text)
        makeStat(4, "🛰 LIVE", C.TextDim)
        register(PingStat, "TextColor3", "Accent")

        local StatusAccent = Instance.new("Frame")
        StatusAccent.Size = UDim2.new(1, 0, 0, 1)
        StatusAccent.Position = UDim2.new(0, 0, 0, 72)
        StatusAccent.BackgroundColor3 = C.Accent
        StatusAccent.BackgroundTransparency = 0.55
        StatusAccent.BorderSizePixel = 0
        StatusAccent.ZIndex = 5
        StatusAccent.Parent = Main
        register(StatusAccent, "BackgroundColor3", "Accent")

        -- loop อัปเดต: FPS เฉลี่ยจาก dt, ping จาก Stats, จำนวนผู้เล่น
        local Stats = nil
        pcall(function() Stats = game:GetService("Stats") end)
        local function getPing()
            if not Stats then return nil end
            local ok, v = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            if ok and v then return math.floor(v + 0.5) end
            return nil
        end
        local frames, acc = 0, 0
        local rc = RunService.RenderStepped:Connect(function(dt) frames += 1; acc += dt end)
        table.insert(self._conns, rc)
        task.spawn(function()
            while gui.Parent do
                task.wait(0.5)
                local fps = acc > 0 and (frames / acc) or 0
                frames, acc = 0, 0
                local fpsN = math.clamp(math.floor(fps + 0.5), 0, 999)
                local fpsCol = fpsN >= 50 and "36E6A0" or (fpsN >= 30 and "FFC857" or "FF5C7A")
                FpsStat.Text = string.format("⚡ <font color=\"#%s\">%d</font> fps", fpsCol, fpsN)
                local ping = getPing()
                PingStat.Text = ping and ("📶 " .. ping .. " ms") or "📶 -- ms"
                PlayersStat.Text = "👥 " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
            end
        end)
    end

    --------------------------------------------------
    -- Body: sidebar + content
    --------------------------------------------------
    local Body = Instance.new("Frame")
    Body.Name = "Body"
    Body.Size = UDim2.new(1, 0, 1, -bodyY)
    Body.Position = UDim2.new(0, 0, 0, bodyY)
    Body.BackgroundTransparency = 1
    Body.ClipsDescendants = true
    Body.Parent = Main
    self.Body = Body

    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 118, 1, -12)
    Sidebar.Position = UDim2.new(0, 8, 0, 6)
    Sidebar.BackgroundColor3 = C.Panel
    Sidebar.BorderSizePixel = 0
    corner(Sidebar, 8)
    local SideStroke = stroke(Sidebar, C.Accent, 1, 0.75)
    register(SideStroke, "Color", "Accent")
    register(Sidebar, "BackgroundColor3", "Panel")
    Sidebar.Parent = Body
    listLayout(Sidebar, 4)
    padding(Sidebar, 8, 8, 6, 6)
    self.Sidebar = Sidebar

    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "Content"
    ContentArea.Size = UDim2.new(1, -142, 1, -12)
    ContentArea.Position = UDim2.new(0, 134, 0, 6)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Parent = Body
    self.ContentArea = ContentArea

    --------------------------------------------------
    -- FAB (ปุ่มลอยเปิด UI กลับ)
    --------------------------------------------------
    local FAB = Instance.new("TextButton")
    FAB.Name = "FAB"
    FAB.Size = UDim2.new(0, 48, 0, 48)
    FAB.Position = UDim2.new(0, 16, 0.5, -24)
    FAB.BackgroundColor3 = C.Accent
    FAB.Text = opts.Icon or "⚡"
    FAB.TextColor3 = C.Text
    FAB.TextSize = 22
    FAB.Font = Enum.Font.GothamBold
    FAB.AutoButtonColor = false
    FAB.Visible = false
    FAB.ZIndex = 400
    corner(FAB, 24)
    stroke(FAB, C.Text, 1, 0.7)
    register(FAB, "BackgroundColor3", "Accent")
    FAB.Parent = gui
    self.FAB = FAB

    -- ลาก FAB ได้ + คลิกเปิด UI
    do
        local dragging, moved, dragStart, startPos
        FAB.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; moved = false; dragStart = input.Position; startPos = FAB.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        local fc = UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                if math.abs(delta.X) + math.abs(delta.Y) > 4 then moved = true end
                FAB.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        table.insert(self._conns, fc)
        FAB.MouseButton1Click:Connect(function()
            if not moved then self:Show() end
        end)
    end

    --------------------------------------------------
    -- Minimize / Close / ToggleKey
    --------------------------------------------------
    self._minimized = false
    local fullSize = size
    MinBtn.MouseButton1Click:Connect(function()
        self._minimized = not self._minimized
        if self._minimized then
            Body.Visible = false
            tween(Main, { Size = UDim2.new(fullSize.X.Scale, fullSize.X.Offset, 0, bodyY) }, 0.18)
        else
            tween(Main, { Size = fullSize }, 0.18)
            task.delay(0.12, function() Body.Visible = true end)
        end
    end)
    CloseBtn.MouseButton1Click:Connect(function() self:Hide() end)

    local kc = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == toggleKey then self:Toggle() end
    end)
    table.insert(self._conns, kc)

    return self
end

--------------------------------------------------------------
-- Window methods
--------------------------------------------------------------
function Window:CreateTab(a, b)
    local name, icon
    if type(a) == "table" then name = a.Name or a.name or "Tab"; icon = a.Icon or a.icon or ""
    else name = a or "Tab"; icon = b or "" end

    local i = #self.Tabs + 1

    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = C.Card
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = i
    corner(btn, 6)
    local btnStroke = stroke(btn, C.Accent, 1, 1)
    register(btnStroke, "Color", "Accent")
    btn.Parent = self.Sidebar

    local ind = Instance.new("Frame")
    ind.Name = "Ind"
    ind.Size = UDim2.new(0, 3, 0.6, 0)
    ind.Position = UDim2.new(0, 0, 0.2, 0)
    ind.BackgroundColor3 = C.Accent
    ind.BorderSizePixel = 0
    ind.Visible = false
    corner(ind, 2)
    ind.Parent = btn
    register(ind, "BackgroundColor3", "Accent")

    local ico = Instance.new("TextLabel")
    ico.Size = UDim2.new(0, 24, 1, 0)
    ico.Position = UDim2.new(0, 8, 0, 0)
    ico.BackgroundTransparency = 1
    ico.Text = icon
    ico.TextSize = 15
    ico.Font = Enum.Font.GothamBold
    ico.TextColor3 = C.Text
    ico.Parent = btn

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -38, 1, 0)
    txt.Position = UDim2.new(0, 34, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = name
    txt.TextSize = 12
    txt.Font = Enum.Font.GothamBold
    txt.TextColor3 = C.TextDim
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = C.Accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = self.ContentArea
    register(page, "ScrollBarImageColor3", "Accent")
    listLayout(page, 8)
    padding(page, 2, 8, 2, 6)

    local tabObj = setmetatable({
        window = self, page = page, name = name, _order = 0,
        _refs = { btn = btn, ind = ind, txt = txt, ico = ico, strk = btnStroke },
    }, Tab)

    self._tabButtons[name] = tabObj
    table.insert(self.Tabs, tabObj)

    btn.MouseButton1Click:Connect(function() self:SwitchTab(name) end)
    btn.MouseEnter:Connect(function()
        if self._activeTab ~= name then tween(btn, { BackgroundTransparency = 0.6, BackgroundColor3 = C.Card }, 0.12) end
    end)
    btn.MouseLeave:Connect(function()
        if self._activeTab ~= name then tween(btn, { BackgroundTransparency = 1 }, 0.12) end
    end)

    -- แท็บแรก = active อัตโนมัติ
    if i == 1 then self:SwitchTab(name) end
    return tabObj
end

function Window:SwitchTab(name)
    self._activeTab = name
    for tname, t in pairs(self._tabButtons) do
        local r = t._refs
        if tname == name then
            tween(r.btn, { BackgroundTransparency = 0, BackgroundColor3 = C.Card }, 0.15)
            r.txt.TextColor3 = C.Text
            r.ico.TextColor3 = C.Accent
            tween(r.strk, { Transparency = 0.35 }, 0.15)
            r.ind.Visible = true
            t.page.Visible = true
        else
            tween(r.btn, { BackgroundTransparency = 1 }, 0.15)
            r.txt.TextColor3 = C.TextDim
            r.ico.TextColor3 = C.Text
            tween(r.strk, { Transparency = 1 }, 0.15)
            r.ind.Visible = false
            t.page.Visible = false
        end
    end
end

function Window:Show()
    self.Main.Visible = true
    self.FAB.Visible = false
end

function Window:Hide()
    self.Main.Visible = false
    self.FAB.Visible = true
end

function Window:Toggle()
    if self.Main.Visible then self:Hide() else self:Show() end
end

function Window:SetTitle(t) end -- (เผื่ออนาคต)

function Window:Notify(...) return NeonUI:Notify(...) end

function Window:Destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    self._conns = {}
    -- เอา object ของ window นี้ออกจาก registry ธีม
    for i = #Themed, 1, -1 do
        local o = Themed[i].obj
        if o and (not o.Parent or (self.gui and o:IsDescendantOf(self.gui))) then
            table.remove(Themed, i)
        end
    end
    if self.gui then self.gui:Destroy() end
end

--------------------------------------------------------------
return NeonUI

--[[ ======================= EXAMPLE =======================
local NeonUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/<user>/<repo>/main/NeonUI.lua"))()

local Win = NeonUI:CreateWindow({
    Title    = "AdminMode",
    Icon     = "⚡",
    Version  = "v3",
    Theme    = "Neon",                       -- "Neon"/"Blue"/"Purple"/... หรือ Accent = Color3
    Size     = UDim2.new(0, 500, 0, 568),
    ToggleKey = Enum.KeyCode.RightShift,     -- ปุ่มซ่อน/แสดง
    StatusBar = true,                        -- แถบ FPS/ping/ผู้เล่น
})

local players = Win:CreateTab("Players", "🧍")
players:Section("การเคลื่อนที่")
players:Toggle({ Text = "Fly", Default = false, Flag = "fly", Callback = function(v) print("fly", v) end })
players:Slider({ Text = "ความเร็ว", Min = 16, Max = 200, Default = 16, Step = 1, Format = "%d",
                 Flag = "speed", Callback = function(v) print("speed", v) end })
players:Button({ Text = "รีเซ็ต", Color = "Red", Callback = function() print("reset") end })
players:Input({ Placeholder = "พิมพ์ชื่อผู้เล่น...", Callback = function(txt) print(txt) end })

local settings = Win:CreateTab("Settings", "⚙️")
settings:ThemePicker("🎨 ธีมสี")             -- แผงเลือก 8 ธีมสำเร็จรูป
settings:Slider({ Text = "ขนาด UI", Min = 0.7, Max = 1.4, Default = 1, Step = 0.05, Format = "%.2f",
                  Callback = function(v) Win.UIScale.Scale = v end })

NeonUI:Notify("โหลดเมนูเสร็จแล้ว", 2)
-- เข้าถึงค่าภายหลัง: Win.Flags.speed.get() / Win.Flags.fly.set(true, true)
-- เปลี่ยนธีมด้วยโค้ด: NeonUI:SetTheme("Purple") หรือ NeonUI:SetAccent(Color3.fromRGB(255,0,120))
========================================================= ]]
