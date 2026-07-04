local InputService = game:GetService('UserInputService')
local TextService   = game:GetService('TextService')
local CoreGui       = game:GetService('CoreGui')
local Players       = game:GetService('Players')
local RunService    = game:GetService('RunService')
local TweenService  = game:GetService('TweenService')
local RenderStepped = RunService.RenderStepped
local LocalPlayer   = Players.LocalPlayer
local Mouse          = LocalPlayer:GetMouse()

local b64decode = (crypt and crypt.base64 and crypt.base64.decode) or (crypt and crypt.base64decode) or base64_decode
local base64FontData = ""
local CustomFontFace = nil

if getcustomasset and writefile and isfile and b64decode then
    local fontData = base64FontData:gsub("[^%w%+/=]", "")
    if #fontData > 100 then
        local ttfPath, jsonPath = "proggyclean.ttf", "proggyclean.font"

        if not isfile(ttfPath) then
            local ok, decoded = pcall(b64decode, fontData)
            if ok and decoded then writefile(ttfPath, decoded) end
        end

        if isfile(ttfPath) and not isfile(jsonPath) then
            local assetPath = getcustomasset(ttfPath)
            writefile(jsonPath, ('{"name":"CustomFont","faces":[{"name":"Regular","weight":400,"style":"normal","assetId":"%s"}]}'):format(assetPath))
        end

        if isfile(jsonPath) then
            local ok, face = pcall(Font.new, getcustomasset(jsonPath))
            if ok then CustomFontFace = face end
        end
    end
end

getgenv().__CustomFont = CustomFontFace

local ExecutorName = "unknown"
do
    local ok, name = pcall(function()
        return (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or "unknown"
    end)
    if ok and type(name) == "string" then ExecutorName = name end
end

local IsDeltaExecutor = string.find(string.lower(ExecutorName), "delta") ~= nil
local IsMobileMode    = InputService.TouchEnabled or IsDeltaExecutor

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local ScreenGui = Instance.new('ScreenGui')
ProtectGui(ScreenGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = CoreGui

local Toggles, Options = {}, {}
getgenv().Toggles = Toggles
getgenv().Options = Options

local Library = {
    Registry = {},
    RegistryMap = {},

    FontColor        = Color3.fromRGB(235, 235, 235),
    MutedFontColor    = Color3.fromRGB(150, 150, 150),
    MainColor        = Color3.fromRGB(22, 22, 22),
    BackgroundColor  = Color3.fromRGB(14, 14, 14),
    AccentColor      = Color3.fromRGB(0, 140, 255),
    OutlineColor     = Color3.fromRGB(35, 35, 35),
    RiskColor        = Color3.fromRGB(255, 60, 60),

    Font     = Enum.Font.Code,
    FontSize = 13,

    OpenedFrames = {},
    Signals = {},
    ScreenGui = ScreenGui,

    Toggled = false,
    IsMobileMode = IsMobileMode,
    ExecutorName = ExecutorName,
    KeybindMode = 'All',
}

local function Lighten(Color, Mul)
    local h, s, v = Color3.toHSV(Color)
    return Color3.fromHSV(h, s, math.clamp(v * Mul, 0, 1))
end

Library.AccentColorDark = Lighten(Library.AccentColor, 0.45)

function Library:GiveSignal(sig) table.insert(Library.Signals, sig) end

function Library:Create(Class, Props)
    local inst = type(Class) == 'string' and Instance.new(Class) or Class
    for k, v in next, Props do inst[k] = v end
    if getgenv().__CustomFont and (inst:IsA('TextLabel') or inst:IsA('TextBox') or inst:IsA('TextButton')) then
        pcall(function() inst.FontFace = getgenv().__CustomFont end)
    end
    return inst
end

function Library:AddToRegistry(Instance, Properties)
    local Data = { Instance = Instance, Properties = Properties }
    table.insert(Library.Registry, Data)
    Library.RegistryMap[Instance] = Data
end

function Library:UpdateColorsUsingRegistry()
    for _, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx]
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end
    end
end

function Library:SafeCallback(f, ...)
    if not f then return end
    local ok, err = pcall(f, ...)
    if not ok then warn('[Library] callback error: ' .. tostring(err)) end
end

function Library:GetTextBounds(Text, Font, Size)
    local b = TextService:GetTextSize(Text, Size, Font, Vector2.new(1920, 1080))
    return b.X, b.Y
end

function Library:MapValue(v, a1, a2, b1, b2)
    return b1 + (v - a1) * (b2 - b1) / (a2 - a1)
end

function Library:CreateLabel(Props)
    local lbl = Library:Create('TextLabel', {
        BackgroundTransparency = 1,
        Font = Library.Font,
        TextColor3 = Library.FontColor,
        TextSize = Library.FontSize,
    })
    Library:AddToRegistry(lbl, { TextColor3 = 'FontColor' })
    return Library:Create(lbl, Props or {})
end

function Library:FlatFill(Parent, ColorTop, ColorBottomMul, ZIndex)
    local f = Library:Create('Frame', {
        BackgroundColor3 = ColorTop,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = ZIndex,
        Parent = Parent,
    })
    Library:Create('UIGradient', {
        Color = ColorSequence.new(ColorTop, Lighten(ColorTop, ColorBottomMul or 0.5)),
        Rotation = 90,
        Parent = f,
    })
    return f
end

function Library:MakeDraggable(Frame, Cutoff)
    Frame.Active = true
    Frame.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
        local StartPos = Frame.Position
        local DragStart = Input.Position
        if Cutoff and (DragStart.Y - Frame.AbsolutePosition.Y) > Cutoff then return end

        local Changed, Ended
        Changed = InputService.InputChanged:Connect(function(Change)
            if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                local Delta = Change.Position - DragStart
                Frame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
            end
        end)
        Ended = InputService.InputEnded:Connect(function(EndInput)
            if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                Changed:Disconnect(); Ended:Disconnect()
            end
        end)
    end)
end

do
    local Bar = Library:Create('Frame', {
        Name = 'Watermark',
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BackgroundTransparency = 0.15,
        Position = UDim2.new(0.5, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0, 260, 0, 22),
        ZIndex = 500,
        Visible = false,
        Parent = ScreenGui,
    })
    local AccentLine = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2),
        ZIndex = 501,
        Parent = Bar,
    })
    Library:AddToRegistry(AccentLine, { BackgroundColor3 = 'AccentColor' })

    local Label = Library:CreateLabel({
        Position = UDim2.new(0, 0, 0, 2),
        Size = UDim2.new(1, 0, 1, -2),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 502,
        Parent = Bar,
    })

    Library.Watermark = Bar
    Library.WatermarkText = Label
    Library:MakeDraggable(Bar)

    function Library:SetWatermarkVisibility(Bool) Bar.Visible = Bool end
    function Library:SetWatermark(Text)
        Label.Text = Text
        local X = Library:GetTextBounds(Text, Library.Font, Library.FontSize)
        Bar.Size = UDim2.new(0, math.max(X + 24, 120), 0, 22)
    end
end

do
    local Bar = Library:Create('Frame', {
        Name = 'Keybinds',
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BackgroundTransparency = 0.15,
        Position = UDim2.new(0, 10, 0, 30),
        Size = UDim2.new(0, 190, 0, 18),
        ZIndex = 500,
        Visible = false,
        Parent = ScreenGui,
    })
    Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2),
        ZIndex = 501,
        Parent = Bar,
    })
    local List = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 4, 0, 2),
        Size = UDim2.new(1, -8, 1, -2),
        ZIndex = 501,
        Parent = Bar,
    })
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = List,
    })

    Library.KeybindFrame = Bar
    Library.KeybindContainer = List
    Library:MakeDraggable(Bar)
end

function Library:RefreshKeybindFrame()
    local Y, X = 0, 0
    for _, child in next, Library.KeybindContainer:GetChildren() do
        if child:IsA('TextLabel') and child.Visible then
            Y = Y + 16
            X = math.max(X, child.TextBounds.X)
        end
    end
    Library.KeybindFrame.Size = UDim2.new(0, math.max(X + 16, 150), 0, math.max(Y + 4, 18))
end

do
    Library.NotifyArea = Library:Create('Frame', {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 60),
        Size = UDim2.new(0, 320, 1, -60),
        ZIndex = 600,
        Parent = ScreenGui,
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Library.NotifyArea,
    })
end

function Library:Notify(Text, Duration)
    local X, Y = Library:GetTextBounds(Text, Library.Font, Library.FontSize)
    Y = Y + 6

    local Bar = Library:Create('Frame', {
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BackgroundTransparency = 0.15,
        Size = UDim2.new(0, 0, 0, Y),
        ClipsDescendants = true,
        ZIndex = 600,
        Parent = Library.NotifyArea,
    })
    Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2),
        ZIndex = 601,
        Parent = Bar,
    })
    Library:CreateLabel({
        Position = UDim2.new(0, 8, 0, 2),
        Size = UDim2.new(1, -16, 1, -2),
        Text = Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 601,
        Parent = Bar,
    })

    local target = X + 24
    pcall(function() Bar:TweenSize(UDim2.new(0, target, 0, Y), 'Out', 'Quad', 0.25, true) end)
    task.spawn(function()
        task.wait(Duration or 4)
        pcall(function() Bar:TweenSize(UDim2.new(0, 0, 0, Y), 'Out', 'Quad', 0.25, true) end)
        task.wait(0.25)
        Bar:Destroy()
    end)
end

local BaseGroupbox = {}
local Funcs = {}
BaseGroupbox.__index = Funcs

function Funcs:Resize()
    local Size = 0
    for _, el in next, self.Container:GetChildren() do
        if not el:IsA('UIListLayout') and el.Visible then Size = Size + el.Size.Y.Offset + 4 end
    end
    self.BoxOuter.Size = UDim2.new(1, 0, 0, Size + 26)
end

function Funcs:AddBlank(Size)
    Library:Create('Frame', { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Size), Parent = self.Container })
end

function Funcs:AddLabel(Text)
    local Groupbox = self
    local Row = Library:Create('Frame', { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Parent = Groupbox.Container })
    local lbl = Library:CreateLabel({
        Size = UDim2.new(1, -34, 1, 0),
        Text = Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Row,
    })

    local Label = { TextLabel = Row, Container = Groupbox.Container }
    setmetatable(Label, BaseGroupbox)

    function Label:SetText(NewText) lbl.Text = NewText end

    Groupbox:AddBlank(4); Groupbox:Resize()
    return Label
end

function Funcs:AddButton(Text, Func)
    local Groupbox = self
    local Outer = Library:Create('Frame', {
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 22),
        Parent = Groupbox.Container,
    })
    Library:AddToRegistry(Outer, {})
    local Fill = Library:FlatFill(Outer, Color3.fromRGB(40, 40, 40), 0.55, 2)
    local Lbl = Library:CreateLabel({
        Size = UDim2.new(1, 0, 1, 0),
        Text = Text,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
        Parent = Outer,
    })

    Outer.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Library:SafeCallback(Func)
        end
    end)

    Groupbox:AddBlank(4); Groupbox:Resize()
    return { Outer = Outer, Label = Lbl }
end

function Funcs:AddToggle(Idx, Info)
    local Groupbox = self
    local Toggle = {
        Value = Info.Default or false,
        Type = 'Toggle',
        Callback = Info.Callback or function() end,
    }

    local Row = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Parent = Groupbox.Container,
    })

    local Box = Library:Create('Frame', {
        BackgroundColor3 = Color3.fromRGB(35, 35, 35),
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 1,
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 0, 0.5, -7),
        Parent = Row,
    })
    local BoxFill = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = Toggle.Value,
        Parent = Box,
    })
    Library:Create('UIGradient', {
        Color = ColorSequence.new(Library.AccentColor, Lighten(Library.AccentColor, 0.4)),
        Rotation = 90,
        Parent = BoxFill,
    })

    local Lbl = Library:CreateLabel({
        Position = UDim2.new(0, 22, 0, 0),
        Size = UDim2.new(1, -22, 1, 0),
        Text = Info.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Info.Risky and Library.RiskColor or Library.FontColor,
        Parent = Row,
    })

    function Toggle:Display() BoxFill.Visible = Toggle.Value end
    function Toggle:SetValue(v)
        Toggle.Value = not not v
        Toggle:Display()
        Library:SafeCallback(Toggle.Callback, Toggle.Value)
        if Toggle.Changed then Library:SafeCallback(Toggle.Changed, Toggle.Value) end
    end
    function Toggle:OnChanged(f) Toggle.Changed = f; f(Toggle.Value) end

    local Clickable = Library:Create('Frame', { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Row })
    Clickable.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Toggle:SetValue(not Toggle.Value)
            Library:AttemptSave()
        end
    end)

    Toggle.TextLabel = Row
    Toggle.Container = Groupbox.Container
    setmetatable(Toggle, BaseGroupbox)

    Groupbox:AddBlank(6); Groupbox:Resize()
    Toggles[Idx] = Toggle
    return Toggle
end

function Funcs:AddSlider(Idx, Info)
    local Groupbox = self
    local Slider = {
        Value = Info.Default, Min = Info.Min, Max = Info.Max,
        Rounding = Info.Rounding or 0,
        Type = 'Slider',
        Callback = Info.Callback or function() end,
    }

    local Wrap = Library:Create('Frame', { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = Groupbox.Container })
    local Lbl = Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 14), Text = Info.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = Wrap })

    local Track = Library:Create('Frame', {
        BackgroundColor3 = Color3.fromRGB(35, 35, 35),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 18),
        Size = UDim2.new(1, 0, 0, 4),
        Parent = Wrap,
    })
    local Fill = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        Parent = Track,
    })
    Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' })

    local function Round(v)
        if Slider.Rounding == 0 then return math.floor(v) end
        return tonumber(string.format('%.' .. Slider.Rounding .. 'f', v))
    end

    function Slider:Display()
        local pct = math.clamp((Slider.Value - Slider.Min) / (Slider.Max - Slider.Min), 0, 1)
        Fill.Size = UDim2.new(pct, 0, 1, 0)
        Lbl.Text = string.format('%s: %s', Info.Text, tostring(Slider.Value))
    end
    function Slider:SetValue(v)
        v = math.clamp(tonumber(v) or Slider.Min, Slider.Min, Slider.Max)
        Slider.Value = Round(v)
        Slider:Display()
        Library:SafeCallback(Slider.Callback, Slider.Value)
        if Slider.Changed then Library:SafeCallback(Slider.Changed, Slider.Value) end
    end
    function Slider:OnChanged(f) Slider.Changed = f; f(Slider.Value) end

    Track.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
        local function Update(px)
            local rel = math.clamp((px - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
            Slider:SetValue(Slider.Min + rel * (Slider.Max - Slider.Min))
        end
        Update(Input.Position.X)
        local Changed, Ended
        Changed = InputService.InputChanged:Connect(function(c)
            if c.UserInputType == Enum.UserInputType.MouseMovement or c == Input then Update(c.Position.X) end
        end)
        Ended = InputService.InputEnded:Connect(function(e)
            if e == Input or e.UserInputType == Enum.UserInputType.Touch then
                Changed:Disconnect(); Ended:Disconnect(); Library:AttemptSave()
            end
        end)
    end)

    Slider:Display()
    Groupbox:AddBlank(4); Groupbox:Resize()
    Options[Idx] = Slider
    return Slider
end

function Funcs:AddDropdown(Idx, Info)
    local Groupbox = self
    local Dropdown = { Values = Info.Values, Value = Info.Default, Type = 'Dropdown', Callback = Info.Callback or function() end }

    local Wrap = Library:Create('Frame', { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = Groupbox.Container })
    Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 14), Text = Info.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = Wrap })

    local Box = Library:Create('Frame', {
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 16),
        Size = UDim2.new(1, 0, 0, 20),
        Parent = Wrap,
    })
    Library:FlatFill(Box, Color3.fromRGB(38, 38, 38), 0.55, 2)
    local Preview = Library:CreateLabel({ Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Text = tostring(Dropdown.Value or '--'), Parent = Box })

    local List = Library:Create('Frame', {
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 2),
        Size = UDim2.new(1, 0, 0, math.min(#Dropdown.Values, 6) * 18),
        Visible = false,
        ZIndex = 50,
        Parent = Box,
    })
    Library:Create('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder, Parent = List })

    for _, Val in next, Dropdown.Values do
        local Item = Library:Create('TextButton', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = tostring(Val),
            Font = Library.Font,
            TextSize = Library.FontSize,
            TextColor3 = Library.FontColor,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 51,
            Parent = List,
        })
        Item.MouseButton1Click:Connect(function()
            Dropdown.Value = Val
            Preview.Text = tostring(Val)
            List.Visible = false
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
            if Dropdown.Changed then Library:SafeCallback(Dropdown.Changed, Dropdown.Value) end
            Library:AttemptSave()
        end)
    end

    Box.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            List.Visible = not List.Visible
        end
    end)

    function Dropdown:SetValue(v)
        Dropdown.Value = v
        Preview.Text = tostring(v)
        Library:SafeCallback(Dropdown.Callback, v)
    end
    function Dropdown:OnChanged(f) Dropdown.Changed = f; f(Dropdown.Value) end

    Groupbox:AddBlank(4); Groupbox:Resize()
    Options[Idx] = Dropdown
    return Dropdown
end

function Funcs:AddColorPicker(Idx, Info)
    local ColorPicker = { Value = Info.Default, Type = 'ColorPicker', Callback = Info.Callback or function() end }
    local Parent = self.TextLabel or self.Container

    local Swatch = Library:Create('Frame', {
        BackgroundColor3 = ColorPicker.Value,
        BorderColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 14),
        ZIndex = 5,
        Parent = Parent,
    })

    local Popup = Library:Create('Frame', {
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 150, 0, 90),
        Visible = false,
        ZIndex = 60,
        Parent = ScreenGui,
    })
    Swatch:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
        Popup.Position = UDim2.fromOffset(Swatch.AbsolutePosition.X - 150 + Swatch.AbsoluteSize.X, Swatch.AbsolutePosition.Y + 18)
    end)

    local function AddChannel(Name, Y, Value)
        local Lbl = Library:CreateLabel({ Position = UDim2.new(0, 6, 0, Y), Size = UDim2.new(0, 16, 0, 16), Text = Name, ZIndex = 61, Parent = Popup })
        local Track = Library:Create('Frame', { BackgroundColor3 = Color3.fromRGB(35, 35, 35), BorderSizePixel = 0, Position = UDim2.new(0, 24, 0, Y + 2), Size = UDim2.new(1, -30, 0, 4), ZIndex = 61, Parent = Popup })
        local Fill = Library:Create('Frame', { BackgroundColor3 = Color3.fromRGB(200, 200, 200), BorderSizePixel = 0, Size = UDim2.new(Value, 0, 1, 0), ZIndex = 62, Parent = Track })
        return Track, Fill
    end

    local function Refresh()
        Swatch.BackgroundColor3 = ColorPicker.Value
        Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value)
        if ColorPicker.Changed then Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value) end
    end

    local r, g, b = ColorPicker.Value.R, ColorPicker.Value.G, ColorPicker.Value.B
    local RTrack, RFill = AddChannel('R', 4, r)
    local GTrack, GFill = AddChannel('G', 26, g)
    local BTrack, BFill = AddChannel('B', 48, b)

    local function BindChannel(Track, Fill, GetSet)
        Track.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
            local function Update(px)
                local rel = math.clamp((px - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                Fill.Size = UDim2.new(rel, 0, 1, 0)
                GetSet(rel)
                Refresh()
            end
            Update(Input.Position.X)
            local Changed, Ended
            Changed = InputService.InputChanged:Connect(function(c)
                if c.UserInputType == Enum.UserInputType.MouseMovement or c == Input then Update(c.Position.X) end
            end)
            Ended = InputService.InputEnded:Connect(function(e)
                if e == Input or e.UserInputType == Enum.UserInputType.Touch then Changed:Disconnect(); Ended:Disconnect(); Library:AttemptSave() end
            end)
        end)
    end

    BindChannel(RTrack, RFill, function(v) ColorPicker.Value = Color3.new(v, ColorPicker.Value.G, ColorPicker.Value.B) end)
    BindChannel(GTrack, GFill, function(v) ColorPicker.Value = Color3.new(ColorPicker.Value.R, v, ColorPicker.Value.B) end)
    BindChannel(BTrack, BFill, function(v) ColorPicker.Value = Color3.new(ColorPicker.Value.R, ColorPicker.Value.G, v) end)

    Swatch.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Popup.Visible = not Popup.Visible
        end
    end)

    function ColorPicker:SetValueRGB(Color) ColorPicker.Value = Color; Refresh() end
    function ColorPicker:OnChanged(f) ColorPicker.Changed = f; f(ColorPicker.Value) end

    Options[Idx] = ColorPicker
    return ColorPicker
end

function Funcs:AddKeyPicker(Idx, Info)
    local KeyPicker = { Value = Info.Default, Toggled = false, Mode = Info.Mode or 'Toggle', Type = 'KeyPicker', Callback = Info.Callback or function() end }
    local Parent = self.TextLabel or self.Container
    local ParentObj = self

    local Btn = Library:Create('TextButton', {
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 46, 0, 16),
        Font = Library.Font,
        TextSize = Library.FontSize - 1,
        TextColor3 = Library.FontColor,
        Text = '[' .. tostring(KeyPicker.Value) .. ']',
        ZIndex = 5,
        Parent = Parent,
    })

    local Entry = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 16),
        Text = string.format('[%s] %s', KeyPicker.Value, Info.Text or ''),
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
        Parent = Library.KeybindContainer,
    })

    function KeyPicker:GetState()
        if KeyPicker.Mode == 'Always' then return true end
        return KeyPicker.Toggled
    end

    local function UpdateEntry()
        Entry.Text = string.format('[%s] %s', KeyPicker.Value, Info.Text or '')
        Entry.Visible = Library.KeybindMode ~= 'Toggled' or (ParentObj.Value == true)
        Library:RefreshKeybindFrame()
    end
    UpdateEntry()

    local Picking = false
    Btn.MouseButton1Click:Connect(function()
        Picking = true
        Btn.Text = '...'
        local Conn
        Conn = InputService.InputBegan:Connect(function(Input)
            local Key
            if Input.UserInputType == Enum.UserInputType.Keyboard then Key = Input.KeyCode.Name
            elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then Key = 'MB1'
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then Key = 'MB2' end
            if Key then
                KeyPicker.Value = Key
                Btn.Text = '[' .. Key .. ']'
                UpdateEntry()
                Picking = false
                Library:AttemptSave()
                Conn:Disconnect()
            end
        end)
    end)

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
        if Picking then return end
        if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == KeyPicker.Value then
            KeyPicker.Toggled = not KeyPicker.Toggled
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            UpdateEntry()
        end
    end))

    function KeyPicker:SetValue(Data)
        KeyPicker.Value = Data[1] or Data
        Btn.Text = '[' .. tostring(KeyPicker.Value) .. ']'
        UpdateEntry()
    end
    function KeyPicker:OnChanged(f) KeyPicker.Changed = f end

    Options[Idx] = KeyPicker
    return ParentObj
end

BaseGroupbox.__namecall = function(_, Key, ...) return Funcs[Key](...) end

function Library:CreateWindow(Config)
    Config = Config or {}
    Config.Title = Config.Title or 'Menu'
    local BaseSize = Config.Size or (IsMobileMode and UDim2.fromOffset(360, 320) or UDim2.fromOffset(560, 420))

    local Window = { Tabs = {} }

    local Outer = Library:Create('Frame', {
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = BaseSize,
        Visible = false,
        Parent = ScreenGui,
    })
    Library:FlatFill(Outer, Color3.fromRGB(16, 16, 16), 0.7, 0)

    local TitleBar = Library:Create('Frame', { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Parent = Outer })
    Library:MakeDraggable(TitleBar)
    Library:CreateLabel({ Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 1, 0), Text = Config.Title, TextXAlignment = Enum.TextXAlignment.Left, Parent = TitleBar })
    Library:Create('Frame', { BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0, Position = UDim2.new(0, 8, 1, -1), Size = UDim2.new(1, -16, 0, 1), Parent = TitleBar })

    local TabArea = Library:Create('Frame', { BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 30), Size = UDim2.new(1, -16, 0, 20), Parent = Outer })
    Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = TabArea })

    local Body = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 8, 0, 54),
        Size = UDim2.new(1, -16, 1, -62),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Library.AccentColor,
        Parent = Outer,
    })
    Library:Create('UIListLayout', { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Body })
    Body.ChildAdded:Connect(function()
        task.wait()
        Body.CanvasSize = UDim2.new(0, 0, 0, Body.UIListLayout.AbsoluteContentSize.Y)
    end)

    function Window:AddTab(Name)
        local Tab = {}
        local TabBtn = Library:Create('TextButton', {
            BackgroundColor3 = Color3.fromRGB(24, 24, 24),
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            Font = Library.Font,
            TextSize = Library.FontSize,
            TextColor3 = Library.MutedFontColor,
            Text = '  ' .. Name .. '  ',
            Parent = TabArea,
        })
        local Content = Library:Create('Frame', { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Visible = false, Parent = Body })

        local LeftSide = Library:Create('Frame', { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = Content })
        Library:Create('UIListLayout', { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = LeftSide })

        local RightSide = Library:Create('Frame', { BackgroundTransparency = 1, Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = Content })
        Library:Create('UIListLayout', { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = RightSide })

        local function ResizeContent()
            Content.Size = UDim2.new(1, 0, 0, math.max(LeftSide.AbsoluteSize.Y, RightSide.AbsoluteSize.Y))
        end

        LeftSide:GetPropertyChangedSignal('AbsoluteSize'):Connect(ResizeContent)
        RightSide:GetPropertyChangedSignal('AbsoluteSize'):Connect(ResizeContent)

        function Tab:Show()
            for _, t in next, Window.Tabs do t.Content.Visible = false; t.Btn.TextColor3 = Library.MutedFontColor end
            Content.Visible = true
            TabBtn.TextColor3 = Library.FontColor
        end

        TabBtn.MouseButton1Click:Connect(function() Tab:Show() end)

        function Tab:AddGroupbox(Name, Side)
            local Parent = (Side == 2) and RightSide or LeftSide
            local Groupbox = { Container = nil }
            local BoxOuter = Library:Create('Frame', { BackgroundColor3 = Color3.fromRGB(20, 20, 20), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), Parent = Parent })
            Library:Create('Frame', { BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), Parent = BoxOuter })
            Library:CreateLabel({ Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, 0, 14), Text = Name, TextXAlignment = Enum.TextXAlignment.Left, Parent = BoxOuter })
            local Container = Library:Create('Frame', { BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 20), Size = UDim2.new(1, -12, 1, -24), Parent = BoxOuter })
            Library:Create('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder, Parent = Container })

            Groupbox.Container = Container
            Groupbox.BoxOuter = BoxOuter
            setmetatable(Groupbox, BaseGroupbox)
            Groupbox:Resize()
            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox(Name, 1)
        end

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox(Name, 2)
        end

        Tab.Btn = TabBtn
        Tab.Content = Content
        Window.Tabs[Name] = Tab
        if not next(Window.Tabs, next(Window.Tabs)) then Tab:Show() end
        return Tab
    end

    Window.Holder = Outer
    Library.MainWindow = Window

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if Processed and Input.UserInputType == Enum.UserInputType.Keyboard then return end
        if type(Library.ToggleKeybind) == 'table' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                Library:Toggle()
            end
        elseif Input.KeyCode == Enum.KeyCode.RightShift and not Processed then
            Library:Toggle()
        end
    end))

    if Config.AutoShow then Library:Toggle() end
    return Window
end

function Library:Toggle()
    Library.Toggled = not Library.Toggled
    if Library.MainWindow then Library.MainWindow.Holder.Visible = Library.Toggled end
end

function Library:Unload()
    for _, sig in next, Library.Signals do pcall(function() sig:Disconnect() end) end
    if Library.OnUnload then Library.OnUnload() end
    ScreenGui:Destroy()
end
function Library:OnUnload(cb) Library.OnUnload = cb end
function Library:AttemptSave() if Library.SaveManager then Library.SaveManager:Save() end end

if IsMobileMode then
    local MobileGui = Instance.new('ScreenGui')
    MobileGui.Name = 'LinoriaMobileUI'
    MobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    ProtectGui(MobileGui)
    MobileGui.Parent = CoreGui

    local BTN_W, BTN_H, GAP = 74, 24, 6
    local StartY = 78

    local function MakeBtn(text, y)
        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.fromRGB(10, 10, 10),
            BackgroundTransparency = 0.1,
            Position = UDim2.new(0, 10, 0, y),
            Size = UDim2.new(0, BTN_W, 0, BTN_H),
            Parent = MobileGui,
        })
        Library:Create('Frame', { BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), Parent = Outer })
        local Btn = Library:Create('TextButton', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Font = Library.Font,
            TextSize = Library.FontSize - 1,
            TextColor3 = Library.FontColor,
            Text = text,
            Parent = Outer,
        })
        return Outer, Btn
    end

    local ToggleOuter, ToggleBtn = MakeBtn('Toggle UI', StartY)
    local LockOuter, LockBtn = MakeBtn('Lock UI', StartY + BTN_H + GAP)

    ToggleBtn.MouseButton1Click:Connect(function() Library:Toggle() end)

    local Locked = false
    LockBtn.MouseButton1Click:Connect(function()
        Locked = not Locked
        LockBtn.Text = Locked and 'Unlock UI' or 'Lock UI'
        LockBtn.TextColor3 = Locked and Library.AccentColor or Library.FontColor
    end)

end

getgenv().Library = Library
return Library
