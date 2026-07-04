local HttpService = game:GetService('HttpService')

local ThemeManager = {}
ThemeManager.Folder = 'LinoriaCustom'

local BuiltInThemes = {
    ['Default'] = {
        FontColor = Color3.fromRGB(235, 235, 235),
        MutedFontColor = Color3.fromRGB(150, 150, 150),
        MainColor = Color3.fromRGB(22, 22, 22),
        BackgroundColor = Color3.fromRGB(14, 14, 14),
        AccentColor = Color3.fromRGB(0, 140, 255),
        OutlineColor = Color3.fromRGB(35, 35, 35),
    },
    ['Crimson'] = {
        FontColor = Color3.fromRGB(235, 235, 235),
        MutedFontColor = Color3.fromRGB(150, 150, 150),
        MainColor = Color3.fromRGB(22, 22, 22),
        BackgroundColor = Color3.fromRGB(14, 14, 14),
        AccentColor = Color3.fromRGB(220, 40, 60),
        OutlineColor = Color3.fromRGB(35, 35, 35),
    },
    ['Emerald'] = {
        FontColor = Color3.fromRGB(235, 235, 235),
        MutedFontColor = Color3.fromRGB(150, 150, 150),
        MainColor = Color3.fromRGB(22, 22, 22),
        BackgroundColor = Color3.fromRGB(14, 14, 14),
        AccentColor = Color3.fromRGB(40, 200, 120),
        OutlineColor = Color3.fromRGB(35, 35, 35),
    },
    ['Violet'] = {
        FontColor = Color3.fromRGB(235, 235, 235),
        MutedFontColor = Color3.fromRGB(150, 150, 150),
        MainColor = Color3.fromRGB(22, 22, 22),
        BackgroundColor = Color3.fromRGB(14, 14, 14),
        AccentColor = Color3.fromRGB(150, 90, 240),
        OutlineColor = Color3.fromRGB(35, 35, 35),
    },
}

ThemeManager.BuiltInThemes = BuiltInThemes

function ThemeManager:SetLibrary(Lib)
    self.Library = Lib
end

function ThemeManager:SetFolder(Folder)
    self.Folder = Folder
    self:BuildFolderTree()
end

function ThemeManager:BuildFolderTree()
    local Paths = {
        self.Folder,
        self.Folder .. '/themes',
    }
    for _, Path in next, Paths do
        if not isfolder(Path) then
            makefolder(Path)
        end
    end
end

function ThemeManager:ApplyTheme(ThemeData)
    local Library = self.Library
    for Key, Value in next, ThemeData do
        Library[Key] = Value
    end
    Library.AccentColorDark = Color3.fromHSV(select(1, Color3.toHSV(Library.AccentColor)), select(2, Color3.toHSV(Library.AccentColor)), math.clamp(select(3, Color3.toHSV(Library.AccentColor)) * 0.45, 0, 1))
    Library:UpdateColorsUsingRegistry()
end

function ThemeManager:SaveThemeFile(Data)
    self:BuildFolderTree()
    local Path = self.Folder .. '/themes/theme.json'
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Data)
    if ok then
        writefile(Path, encoded)
    end
end

function ThemeManager:LoadThemeFile()
    local Path = self.Folder .. '/themes/theme.json'
    if not isfile(Path) then return nil end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(Path))
    end)
    if ok then return decoded end
    return nil
end

local function ColorToTable(Color)
    return { R = Color.R, G = Color.G, B = Color.B }
end

local function TableToColor(Tab)
    return Color3.new(Tab.R, Tab.G, Tab.B)
end

function ThemeManager:ApplyToTab(Tab)
    local Library = self.Library
    local Groupbox = Tab:AddLeftGroupbox('Themes')

    local ThemeNames = {}
    for Name in next, BuiltInThemes do
        table.insert(ThemeNames, Name)
    end
    table.insert(ThemeNames, 'Custom')
    table.sort(ThemeNames)

    local ThemeDropdown = Groupbox:AddDropdown('ThemeManager_ThemeList', {
        Text = 'Theme',
        Values = ThemeNames,
        Default = 'Default',
        Callback = function(Value)
            if Value == 'Custom' then return end
            local ThemeData = BuiltInThemes[Value]
            if ThemeData then
                self:ApplyTheme(ThemeData)
                self:SaveThemeFile({ Name = Value })
            end
        end
    })

    Groupbox:AddLabel('Custom colors:')

    local function AddColorOption(Label, Key)
        Groupbox:AddLabel(Label):AddColorPicker('ThemeManager_' .. Key, {
            Default = Library[Key],
            Callback = function(Color)
                Library[Key] = Color
                if Key == 'AccentColor' then
                    local h, s, v = Color3.toHSV(Color)
                    Library.AccentColorDark = Color3.fromHSV(h, s, math.clamp(v * 0.45, 0, 1))
                end
                Library:UpdateColorsUsingRegistry()
                ThemeDropdown:SetValue('Custom')
                self:SaveThemeFile({
                    Name = 'Custom',
                    AccentColor = ColorToTable(Library.AccentColor),
                    BackgroundColor = ColorToTable(Library.BackgroundColor),
                    MainColor = ColorToTable(Library.MainColor),
                    OutlineColor = ColorToTable(Library.OutlineColor),
                })
            end
        })
    end

    AddColorOption('Accent color', 'AccentColor')
    AddColorOption('Background color', 'BackgroundColor')
    AddColorOption('Main color', 'MainColor')
    AddColorOption('Outline color', 'OutlineColor')

    local Saved = self:LoadThemeFile()
    if Saved then
        if Saved.Name == 'Custom' and Saved.AccentColor then
            self:ApplyTheme({
                AccentColor = TableToColor(Saved.AccentColor),
                BackgroundColor = TableToColor(Saved.BackgroundColor),
                MainColor = TableToColor(Saved.MainColor),
                OutlineColor = TableToColor(Saved.OutlineColor),
            })
            ThemeDropdown:SetValue('Custom')
        elseif Saved.Name and BuiltInThemes[Saved.Name] then
            self:ApplyTheme(BuiltInThemes[Saved.Name])
            ThemeDropdown:SetValue(Saved.Name)
        end
    end
end

return ThemeManager
