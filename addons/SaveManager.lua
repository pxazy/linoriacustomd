local HttpService = game:GetService('HttpService')

local SaveManager = {}
SaveManager.Folder = 'LinoriaCustom'
SaveManager.Ignore = {}
SaveManager.IgnoreThemeIndexes = false

function SaveManager:SetLibrary(Lib)
    self.Library = Lib
    Lib.SaveManager = self
end

function SaveManager:SetFolder(Folder)
    self.Folder = Folder
    self:BuildFolderTree()
end

function SaveManager:SetIgnoreIndexes(List)
    for _, Idx in next, List do
        self.Ignore[Idx] = true
    end
end

function SaveManager:IgnoreThemeSettings()
    self.IgnoreThemeIndexes = true
end

function SaveManager:BuildFolderTree()
    local Paths = {
        self.Folder,
        self.Folder .. '/configs',
    }
    for _, Path in next, Paths do
        if not isfolder(Path) then
            makefolder(Path)
        end
    end
end

local function ColorToTable(Color)
    return { R = Color.R, G = Color.G, B = Color.B, __type = 'Color3' }
end

local function IsColor3Table(Tab)
    return type(Tab) == 'table' and Tab.__type == 'Color3'
end

function SaveManager:GetConfigs()
    self:BuildFolderTree()
    local Files = listfiles(self.Folder .. '/configs')
    local Names = {}
    for _, Path in next, Files do
        local Name = Path:match('([^\\/]+)%.json$')
        if Name then table.insert(Names, Name) end
    end
    table.sort(Names)
    return Names
end

function SaveManager:Save(Name)
    Name = Name or self.CurrentConfig
    if not Name or Name == '' then return false, 'no config name' end

    self:BuildFolderTree()

    local Toggles, Options = getgenv().Toggles, getgenv().Options
    local Data = { Toggles = {}, Options = {} }

    for Idx, Toggle in next, Toggles do
        if not self.Ignore[Idx] then
            Data.Toggles[Idx] = Toggle.Value
        end
    end

    for Idx, Option in next, Options do
        if self.Ignore[Idx] then continue end
        if self.IgnoreThemeIndexes and tostring(Idx):find('^ThemeManager_') then continue end

        if Option.Type == 'ColorPicker' then
            Data.Options[Idx] = ColorToTable(Option.Value)
        elseif Option.Type == 'KeyPicker' then
            Data.Options[Idx] = { Value = Option.Value, Mode = Option.Mode }
        else
            Data.Options[Idx] = Option.Value
        end
    end

    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Data)
    if not ok then return false, 'encode failed' end

    writefile(self.Folder .. '/configs/' .. Name .. '.json', encoded)
    self.CurrentConfig = Name
    return true
end

function SaveManager:Load(Name)
    local Path = self.Folder .. '/configs/' .. Name .. '.json'
    if not isfile(Path) then return false, 'config does not exist' end

    local ok, Data = pcall(function()
        return HttpService:JSONDecode(readfile(Path))
    end)
    if not ok then return false, 'decode failed' end

    local Toggles, Options = getgenv().Toggles, getgenv().Options

    for Idx, Value in next, (Data.Toggles or {}) do
        if Toggles[Idx] then
            Toggles[Idx]:SetValue(Value)
        end
    end

    for Idx, Value in next, (Data.Options or {}) do
        local Option = Options[Idx]
        if not Option then continue end

        if Option.Type == 'ColorPicker' and IsColor3Table(Value) then
            Option:SetValueRGB(Color3.new(Value.R, Value.G, Value.B))
        elseif Option.Type == 'KeyPicker' and type(Value) == 'table' then
            Option:SetValue({ Value.Value, Value.Mode })
        else
            Option:SetValue(Value)
        end
    end

    self.CurrentConfig = Name
    return true
end

function SaveManager:Delete(Name)
    local Path = self.Folder .. '/configs/' .. Name .. '.json'
    if isfile(Path) then
        delfile(Path)
        return true
    end
    return false
end

function SaveManager:SetAutoloadConfig(Name)
    self:BuildFolderTree()
    writefile(self.Folder .. '/configs/autoload.txt', Name)
end

function SaveManager:LoadAutoloadConfig()
    local Path = self.Folder .. '/configs/autoload.txt'
    if not isfile(Path) then return end
    local Name = readfile(Path)
    if Name and Name ~= '' then
        self:Load(Name)
    end
end

function SaveManager:BuildConfigSection(Tab)
    local Library = self.Library
    local Groupbox = Tab:AddRightGroupbox('Configuration')

    local ConfigNameBox = Groupbox:AddInput('SaveManager_ConfigName', {
        Text = 'Config name',
        Default = '',
        Placeholder = 'e.g. default',
    })

    local ConfigList = self:GetConfigs()
    local ConfigDropdown = Groupbox:AddDropdown('SaveManager_ConfigList', {
        Text = 'Configs',
        Values = ConfigList,
        Default = ConfigList[1],
    })

    local function RefreshList()
        ConfigDropdown:SetValues(self:GetConfigs())
    end

    Groupbox:AddButton('Create config', function()
        local Name = ConfigNameBox.Value
        if Name == '' then
            return Library:Notify('Enter a config name first!', 3)
        end
        local ok, err = self:Save(Name)
        if ok then
            Library:Notify('Saved config: ' .. Name, 3)
            RefreshList()
        else
            Library:Notify('Failed to save: ' .. tostring(err), 3)
        end
    end)

    Groupbox:AddButton('Load config', function()
        local Name = ConfigDropdown.Value
        if not Name then
            return Library:Notify('Select a config first!', 3)
        end
        local ok, err = self:Load(Name)
        if ok then
            Library:Notify('Loaded config: ' .. Name, 3)
        else
            Library:Notify('Failed to load: ' .. tostring(err), 3)
        end
    end)

    Groupbox:AddButton('Overwrite config', function()
        local Name = ConfigDropdown.Value
        if not Name then
            return Library:Notify('Select a config first!', 3)
        end
        self:Save(Name)
        Library:Notify('Overwrote config: ' .. Name, 3)
    end)

    Groupbox:AddButton('Delete config', function()
        local Name = ConfigDropdown.Value
        if not Name then
            return Library:Notify('Select a config first!', 3)
        end
        self:Delete(Name)
        Library:Notify('Deleted config: ' .. Name, 3)
        RefreshList()
    end)

    Groupbox:AddButton('Refresh list', RefreshList)

    Groupbox:AddToggle('SaveManager_Autoload', {
        Text = 'Autoload this config on join',
        Default = false,
        Callback = function(Value)
            local Name = ConfigDropdown.Value
            if Value and Name then
                self:SetAutoloadConfig(Name)
                Library:Notify('Set autoload config: ' .. Name, 3)
            end
        end
    })
end

return SaveManager
