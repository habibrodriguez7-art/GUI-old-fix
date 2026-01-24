repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local ConnectionManager = {
    _connections = {},
    _spawns = {}
}

function ConnectionManager:Add(name, connection)
    if self._connections[name] then
        pcall(function() self._connections[name]:Disconnect() end)
    end
    self._connections[name] = connection
    return connection
end

function ConnectionManager:AddSpawn(name, thread)
    if self._spawns[name] then
        pcall(function() task.cancel(self._spawns[name]) end)
    end
    self._spawns[name] = thread
    return thread
end

function ConnectionManager:Remove(name)
    if self._connections[name] then
        pcall(function() self._connections[name]:Disconnect() end)
        self._connections[name] = nil
    end
end

function ConnectionManager:Cleanup()
    for name, conn in pairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    for name, thread in pairs(self._spawns) do
        pcall(function() task.cancel(thread) end)
    end
    table.clear(self._connections)
    table.clear(self._spawns)
end

local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    return inst
end

local colors = {
    primary = Color3.fromRGB(255, 140, 0),
    secondary = Color3.fromRGB(147, 112, 219),
    accent = Color3.fromRGB(186, 85, 211),
    success = Color3.fromRGB(34, 197, 94),
    bg1 = Color3.fromRGB(10, 10, 10),
    bg2 = Color3.fromRGB(18, 18, 18),
    bg3 = Color3.fromRGB(25, 25, 25),
    bg4 = Color3.fromRGB(35, 35, 35),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(180, 180, 180),
    textDimmer = Color3.fromRGB(120, 120, 120),
    border = Color3.fromRGB(50, 50, 50),
}

local CONFIG_FOLDER = "LynxGUI_Configs"
local CONFIG_FILE = CONFIG_FOLDER .. "/lynx_config.json"

local ConfigSystem = {}
ConfigSystem.CurrentConfig = {}
ConfigSystem.DefaultConfig = {}
ConfigSystem.IsDirty = false
ConfigSystem.SaveScheduled = false

local function DeepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = type(v) == "table" and DeepCopy(v) or v
    end
    return copy
end

local function MergeTables(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            MergeTables(target[k], v)
        else
            target[k] = v
        end
    end
end

local function EnsureFolderExists()
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
end

function ConfigSystem.SetDefaults(defaultConfig)
    ConfigSystem.DefaultConfig = DeepCopy(defaultConfig or {})
end

function ConfigSystem.Save()
    local success = pcall(function()
        EnsureFolderExists()
        writefile(CONFIG_FILE, HttpService:JSONEncode(ConfigSystem.CurrentConfig))
    end)
    return success
end

function ConfigSystem.Load()
    EnsureFolderExists()
    ConfigSystem.CurrentConfig = DeepCopy(ConfigSystem.DefaultConfig)
    if isfile(CONFIG_FILE) then
        pcall(function()
            local loaded = HttpService:JSONDecode(readfile(CONFIG_FILE))
            MergeTables(ConfigSystem.CurrentConfig, loaded)
        end)
    end
    return ConfigSystem.CurrentConfig
end

function ConfigSystem.Get(path, default)
    if not path then return default end
    local value = ConfigSystem.CurrentConfig
    for key in string.gmatch(path, "[^.]+") do
        if type(value) ~= "table" then return default end
        value = value[key]
    end
    return value ~= nil and value or default
end

function ConfigSystem.Set(path, value)
    if not path then return end
    local keys = {}
    for key in string.gmatch(path, "[^.]+") do table.insert(keys, key) end
    local target = ConfigSystem.CurrentConfig
    for i = 1, #keys - 1 do
        if type(target[keys[i]]) ~= "table" then target[keys[i]] = {} end
        target = target[keys[i]]
    end
    target[keys[#keys]] = value
end

function ConfigSystem.Reset()
    ConfigSystem.CurrentConfig = DeepCopy(ConfigSystem.DefaultConfig)
    ConfigSystem.Save()
end

local function MarkDirty()
    ConfigSystem.IsDirty = true
    if ConfigSystem.SaveScheduled then return end
    ConfigSystem.SaveScheduled = true
    task.delay(5, function()
        if ConfigSystem.IsDirty then ConfigSystem.Save() ConfigSystem.IsDirty = false end
        ConfigSystem.SaveScheduled = false
    end)
end

local CallbackRegistry = {}

local function RegisterCallback(configPath, callback, componentType, defaultValue)
    if configPath then
        table.insert(CallbackRegistry, {path = configPath, callback = callback, type = componentType, default = defaultValue})
    end
end

local function ExecuteConfigCallbacks()
    for _, entry in ipairs(CallbackRegistry) do
        local value = ConfigSystem.Get(entry.path, entry.default)
        if entry.callback then entry.callback(value) end
    end
end

local Library = {}
Library.ConfigSystem = ConfigSystem
Library.ConnectionManager = ConnectionManager
Library.Colors = colors
Library.Pages = {}
Library.NavButtons = {}
Library.CurrentPage = nil
Library.PageTitle = nil
Library.Gui = nil
Library.Window = nil
Library.NavContainer = nil
Library.ContentBg = nil

-- Window settings
local windowSize = UDim2.new(0, 400, 0, 260)
local minWindowSize = Vector2.new(360, 230)
local maxWindowSize = Vector2.new(520, 360)
local sidebarWidth = 130

local function createNavButton(parent, text, imageId, pageName, order)
    local btn = new("TextButton", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        ZIndex = 6
    })
    new("UICorner", {Parent = btn, CornerRadius = UDim.new(0, 6)})
    
    local indicator = new("Frame", {
        Parent = btn,
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 0, 0.5, -10),
        BackgroundColor3 = colors.primary,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 7
    })
    new("UICorner", {Parent = indicator, CornerRadius = UDim.new(1, 0)})
    
    new("ImageLabel", {
        Parent = btn,
        Image = imageId,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 10, 0.5, -8),
        BackgroundTransparency = 1,
        ImageColor3 = colors.textDim,
        ImageTransparency = 0.3,
        ZIndex = 7,
        Name = "Icon"
    })
    
    new("TextLabel", {
        Parent = btn,
        Text = text,
        Size = UDim2.new(1, -45, 1, 0),
        Position = UDim2.new(0, 40, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = colors.textDim,
        TextTransparency = 0.4,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Name = "Label"
    })
    
    Library.NavButtons[pageName] = {btn = btn, indicator = indicator}
    return btn
end

function Library:SwitchPage(pageName, titleText)
    if Library.CurrentPage == pageName then return end
    for _, page in pairs(Library.Pages) do page.Visible = false end
    
    for name, data in pairs(Library.NavButtons) do
        local isActive = name == pageName
        data.btn.BackgroundColor3 = isActive and colors.bg3 or Color3.fromRGB(0, 0, 0)
        data.btn.BackgroundTransparency = isActive and 0.75 or 1
        local icon = data.btn:FindFirstChild("Icon")
        if icon then
            icon.ImageColor3 = isActive and colors.primary or colors.textDim
            icon.ImageTransparency = isActive and 0 or 0.3
        end
        local label = data.btn:FindFirstChild("Label")
        if label then
            label.TextColor3 = isActive and colors.text or colors.textDim
            label.TextTransparency = isActive and 0.1 or 0.4
        end
        data.indicator.Visible = isActive
    end
    
    if Library.Pages[pageName] then
        Library.Pages[pageName].Visible = true
    end
    if Library.PageTitle then
        Library.PageTitle.Text = titleText or pageName
    end
    Library.CurrentPage = pageName
end

function Library:CreateWindow(config)
    config = config or {}
    local guiName = config.Name or "LynxGUI_Galaxy"
    local title = config.Title or "LynX"
    local subtitle = config.Subtitle or "Free Not For Sale"
    
    -- Remove existing GUI
    local existingGUI = CoreGui:FindFirstChild(guiName)
    if existingGUI then
        existingGUI:Destroy()
        task.wait(0.1)
    end

    local gui = new("ScreenGui", {
        Name = guiName,
        Parent = CoreGui,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 2147483647
    })
    
    local function bringToFront()
        gui.DisplayOrder = 2147483647
    end
    
    -- Main Window
    local win = new("Frame", {
        Parent = gui,
        Size = windowSize,
        Position = UDim2.new(0.5, -windowSize.X.Offset/2, 0.5, -windowSize.Y.Offset/2),
        BackgroundColor3 = colors.bg1,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 3
    })
    new("UICorner", {Parent = win, CornerRadius = UDim.new(0, 8)})
    
    -- Sidebar
    local sidebar = new("Frame", {
        Parent = win,
        Size = UDim2.new(0, sidebarWidth, 1, -45),
        Position = UDim2.new(0, 0, 0, 45),
        BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4
    })
    new("UICorner", {Parent = sidebar, CornerRadius = UDim.new(0, 8)})
    
    -- Header
    local scriptHeader = new("Frame", {
        Parent = win,
        Size = UDim2.new(1, 0, 0, 45),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        ZIndex = 5
    })
    new("UICorner", {Parent = scriptHeader, CornerRadius = UDim.new(0, 8)})
    
    -- Drag Handle
    new("Frame", {
        Parent = scriptHeader,
        Size = UDim2.new(0, 40, 0, 3),
        Position = UDim2.new(0.5, -20, 0, 8),
        BackgroundColor3 = colors.primary,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ZIndex = 6
    }).CornerRadius = UDim.new(1, 0)
    
    -- Title Components
    new("TextLabel", {
        Parent = scriptHeader, Text = title, Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = colors.primary,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
    })
    
    new("ImageLabel", {
        Parent = scriptHeader, Image = "rbxassetid://104332967321169", Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, 66, 0.5, -10), BackgroundTransparency = 1, ImageColor3 = colors.primary, ZIndex = 6
    })
    
    local separator = new("Frame", {
        Parent = scriptHeader, Size = UDim2.new(0, 2, 0, 24), Position = UDim2.new(0, 115, 0.5, -12),
        BackgroundColor3 = colors.primary, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 6
    })
    new("UICorner", {Parent = separator, CornerRadius = UDim.new(1, 0)})
    
    new("TextLabel", {
        Parent = scriptHeader, Text = subtitle, Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(0, 145, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = colors.textDim,
        TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.3, ZIndex = 6
    })
    
    -- Minimize Button
    local btnMinHeader = new("TextButton", {
        Parent = scriptHeader, Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -38, 0.5, -15),
        BackgroundColor3 = colors.bg4, BackgroundTransparency = 0.6, BorderSizePixel = 0, Text = "─",
        Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = colors.textDim, TextTransparency = 0.3,
        AutoButtonColor = false, ZIndex = 7
    })
    new("UICorner", {Parent = btnMinHeader, CornerRadius = UDim.new(0, 8)})

    -- Navigation Container
    local navContainer = new("ScrollingFrame", {
        Parent = sidebar,
        Size = UDim2.new(1, -8, 1, -12),
        Position = UDim2.new(0, 4, 0, 6),
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = colors.primary,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 5
    })
    new("UIListLayout", {Parent = navContainer, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})

    -- Content Area
    local contentBg = new("Frame", {
        Parent = win,
        Size = UDim2.new(1, -(sidebarWidth + 10), 1, -52),
        Position = UDim2.new(0, sidebarWidth + 5, 0, 47),
        BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4
    })
    new("UICorner", {Parent = contentBg, CornerRadius = UDim.new(0, 8)})
    
    local topBar = new("Frame", {
        Parent = contentBg, Size = UDim2.new(1, -8, 0, 32), Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = colors.bg3, BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 5
    })
    new("UICorner", {Parent = topBar, CornerRadius = UDim.new(0, 10)})
    
    Library.PageTitle = new("TextLabel", {
        Parent = topBar, Text = "Dashboard", Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 12, 0, 0),
        Font = Enum.Font.GothamBold, TextSize = 11, BackgroundTransparency = 1, TextColor3 = colors.text,
        TextTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
    })

    -- Resize Handle
    local resizeHandle = new("TextButton", {
        Parent = win, Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(1, -18, 1, -18),
        BackgroundColor3 = colors.bg3, BackgroundTransparency = 0.7, BorderSizePixel = 0, Text = "⋰",
        Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = colors.textDim, TextTransparency = 0.4,
        AutoButtonColor = false, ZIndex = 100
    })
    new("UICorner", {Parent = resizeHandle, CornerRadius = UDim.new(0, 6)})

    -- Draggable Logic
    local dragging, dragStart, startPos = false, nil, nil
    scriptHeader.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            bringToFront()
            dragging, dragStart, startPos = true, input.Position, win.Position
        end
    end)
    
    -- Resizable Logic
    local resizing, resizeStartPos, resizeStartSize = false, nil, nil
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing, resizeStartPos, resizeStartSize = true, input.Position, win.Size
        end
    end)
    
    ConnectionManager:Add("inputChanged", UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and startPos then
                local delta = input.Position - dragStart
                win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
            if resizing and resizeStartPos then
                local delta = input.Position - resizeStartPos
                local newWidth = math.clamp(resizeStartSize.X.Offset + delta.X, minWindowSize.X, maxWindowSize.X)
                local newHeight = math.clamp(resizeStartSize.Y.Offset + delta.Y, minWindowSize.Y, maxWindowSize.Y)
                win.Size = UDim2.new(0, newWidth, 0, newHeight)
            end
        end
    end))
    
    ConnectionManager:Add("inputEnded", UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            resizing = false
        end
    end))

    -- Minimize Logic
    local minimized = false
    local icon = nil
    local savedIconPos = UDim2.new(0, 20, 0, 100)
    
    local function createMinimizedIcon()
        if icon then return end
        icon = new("ImageLabel", {
            Parent = gui, Size = UDim2.new(0, 50, 0, 50), Position = savedIconPos, BackgroundColor3 = colors.bg2,
            BackgroundTransparency = 0.4, BorderSizePixel = 0, Image = "rbxassetid://118176705805619",
            ScaleType = Enum.ScaleType.Fit, ZIndex = 50
        })
        new("UICorner", {Parent = icon, CornerRadius = UDim.new(0, 10)})
        
        local draggingIcon, dragStartIcon, startPosIcon, dragMovedIcon = false, nil, nil, false
        icon.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingIcon, dragMovedIcon, dragStartIcon, startPosIcon = true, false, input.Position, icon.Position
            end
        end)
        icon.InputChanged:Connect(function(input)
            if draggingIcon and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStartIcon
                if math.sqrt(delta.X^2 + delta.Y^2) > 5 then dragMovedIcon = true end
                icon.Position = UDim2.new(startPosIcon.X.Scale, startPosIcon.X.Offset + delta.X, startPosIcon.Y.Scale, startPosIcon.Y.Offset + delta.Y)
            end
        end)
        icon.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if draggingIcon then
                    draggingIcon = false
                    savedIconPos = icon.Position
                    if not dragMovedIcon then
                        bringToFront()
                        win.Visible = true
                        icon:Destroy()
                        icon = nil
                        minimized = false
                    end
                end
            end
        end)
    end
    
    btnMinHeader.MouseButton1Click:Connect(function()
        if not minimized then
            win.Visible = false
            createMinimizedIcon()
            minimized = true
        end
    end)

    gui.Destroying:Connect(function()
        ConnectionManager:Cleanup()
    end)

    Library.Gui = gui
    Library.Window = win
    Library.NavContainer = navContainer
    Library.ContentBg = contentBg
    
    return Library
end

function Library:CreatePage(name, titleText, iconId, order)
    if not Library.ContentBg then
        error("Window must be created first using CreateWindow()")
    end
    
    local page = new("ScrollingFrame", {
        Parent = Library.ContentBg,
        Size = UDim2.new(1, -16, 1, -44),
        Position = UDim2.new(0, 8, 0, 40),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = colors.primary,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 5
    })
    new("UIListLayout", {Parent = page, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    new("UIPadding", {Parent = page, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)})
    
    Library.Pages[name] = page
    
    if iconId and order then
        local btn = createNavButton(Library.NavContainer, name, iconId, name, order)
        ConnectionManager:Add("nav"..name, btn.MouseButton1Click:Connect(function()
            Library:SwitchPage(name, titleText or name)
        end))
    end
    
    return page
end

function Library:SetFirstPage(pageName, titleText)
    if Library.Pages[pageName] then
        Library.Pages[pageName].Visible = true
        Library:SwitchPage(pageName, titleText or pageName)
    end
end

function Library:CreateCategory(parent, title)
    local categoryFrame = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 6
    })
    new("UICorner", {Parent = categoryFrame, CornerRadius = UDim.new(0, 6)})
    
    local header = new("TextButton", {
        Parent = categoryFrame, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 7
    })
    
    new("TextLabel", {
        Parent = header, Text = title, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8
    })
    
    local arrow = new("TextLabel", {
        Parent = header, Text = "▼", Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -24, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = colors.primary, ZIndex = 8
    })
    
    local contentContainer = new("Frame", {
        Parent = categoryFrame, Size = UDim2.new(1, -16, 0, 0), Position = UDim2.new(0, 8, 0, 38),
        BackgroundTransparency = 1, Visible = false, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 7
    })
    new("UIListLayout", {Parent = contentContainer, Padding = UDim.new(0, 6)})
    new("UIPadding", {Parent = contentContainer, PaddingBottom = UDim.new(0, 8)})
    
    local isOpen = false
    header.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        contentContainer.Visible = isOpen
        arrow.Rotation = isOpen and 180 or 0
        categoryFrame.BackgroundTransparency = isOpen and 0.5 or 0.7
    end)
    
    return contentContainer
end

function Library:CreateToggle(parent, label, configPath, callback)
    local frame = new("Frame", {Parent = parent, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, ZIndex = 7})
    
    new("TextLabel", {
        Parent = frame, Text = label, Size = UDim2.new(0.68, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 9,
        TextWrapped = true, ZIndex = 8
    })
    
    local toggleBg = new("Frame", {
        Parent = frame, Size = UDim2.new(0, 38, 0, 20), Position = UDim2.new(1, -38, 0.5, -10),
        BackgroundColor3 = colors.bg4, BorderSizePixel = 0, ZIndex = 8
    })
    new("UICorner", {Parent = toggleBg, CornerRadius = UDim.new(1, 0)})
    
    local toggleCircle = new("Frame", {
        Parent = toggleBg, Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = colors.textDim, BorderSizePixel = 0, ZIndex = 9
    })
    new("UICorner", {Parent = toggleCircle, CornerRadius = UDim.new(1, 0)})
    
    local btn = new("TextButton", {Parent = toggleBg, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 10})
    
    local on = ConfigSystem.Get(configPath, false)
    local function updateState()
        toggleBg.BackgroundColor3 = on and colors.primary or colors.bg4
        toggleCircle.Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        toggleCircle.BackgroundColor3 = on and colors.text or colors.textDim
    end
    updateState()
    
    btn.MouseButton1Click:Connect(function()
        on = not on
        updateState()
        ConfigSystem.Set(configPath, on)
        MarkDirty()
        if callback then callback(on) end
    end)
    
    RegisterCallback(configPath, function(val)
        on = val
        updateState()
        if callback then callback(on) end
    end, "toggle", false)
    
    return frame
end

function Library:CreateButton(parent, label, callback)
    local btnFrame = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = colors.primary,
        BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 8
    })
    new("UICorner", {Parent = btnFrame, CornerRadius = UDim.new(0, 6)})
    
    local button = new("TextButton", {
        Parent = btnFrame, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = colors.text, AutoButtonColor = false, ZIndex = 9
    })
    
    button.MouseButton1Click:Connect(function() pcall(callback) end)
    return btnFrame
end

function Library:CreateInput(parent, label, configPath, defaultValue, callback)
    local frame = new("Frame", {Parent = parent, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, ZIndex = 7})
    
    new("TextLabel", {
        Parent = frame, Text = label, Size = UDim2.new(0.55, 0, 1, 0), BackgroundTransparency = 1,
        TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold,
        TextSize = 9, ZIndex = 8
    })
    
    local inputBg = new("Frame", {
        Parent = frame, Size = UDim2.new(0.42, 0, 0, 28), Position = UDim2.new(0.58, 0, 0.5, -14),
        BackgroundColor3 = colors.bg4, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 8
    })
    new("UICorner", {Parent = inputBg, CornerRadius = UDim.new(0, 6)})
    
    local initialValue = ConfigSystem.Get(configPath, defaultValue)
    local inputBox = new("TextBox", {
        Parent = inputBg, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1, Text = tostring(initialValue), PlaceholderText = "0.00",
        Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = colors.text, PlaceholderColor3 = colors.textDimmer,
        TextXAlignment = Enum.TextXAlignment.Center, ClearTextOnFocus = false, ZIndex = 9
    })
    
    inputBox.FocusLost:Connect(function()
        local value = tonumber(inputBox.Text)
        if value then
            ConfigSystem.Set(configPath, value)
            MarkDirty()
            if callback then callback(value) end
        else
            inputBox.Text = tostring(initialValue)
        end
    end)
    
    RegisterCallback(configPath, function(val)
        initialValue = val
        inputBox.Text = tostring(val)
        if callback then callback(val) end
    end, "input", defaultValue)
    
    return frame
end

function Library:CreateDropdown(parent, title, imageId, items, configPath, onSelect, uniqueId)
    local dropdownFrame = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = colors.bg4,
        BackgroundTransparency = 0.6, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 7, Name = uniqueId or "Dropdown"
    })
    new("UICorner", {Parent = dropdownFrame, CornerRadius = UDim.new(0, 6)})
    
    local header = new("TextButton", {
        Parent = dropdownFrame, Size = UDim2.new(1, -12, 0, 36), Position = UDim2.new(0, 6, 0, 2),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 8
    })
    
    new("ImageLabel", {
        Parent = header, Image = imageId, Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 0, 0.5, -8),
        BackgroundTransparency = 1, ImageColor3 = colors.primary, ZIndex = 9
    })
    
    new("TextLabel", {
        Parent = header, Text = title, Size = UDim2.new(1, -70, 0, 14), Position = UDim2.new(0, 20, 0, 4),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9
    })
    
    local initialSelected = configPath and ConfigSystem.Get(configPath, nil) or nil
    local selectedItem = initialSelected
    
    local statusLabel = new("TextLabel", {
        Parent = header, Text = selectedItem or "None Selected", Size = UDim2.new(1, -70, 0, 12),
        Position = UDim2.new(0, 26, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        TextSize = 8, TextColor3 = colors.textDimmer, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9
    })
    
    local arrow = new("TextLabel", {
        Parent = header, Text = "▼", Size = UDim2.new(0, 24, 1, 0), Position = UDim2.new(1, -24, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = colors.primary, ZIndex = 9
    })
    
    local listContainer = new("ScrollingFrame", {
        Parent = dropdownFrame, Size = UDim2.new(1, -12, 0, 0), Position = UDim2.new(0, 6, 0, 42),
        BackgroundTransparency = 1, Visible = false, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 2, ScrollBarImageColor3 = colors.primary,
        BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 10
    })
    new("UIListLayout", {Parent = listContainer, Padding = UDim.new(0, 4)})
    new("UIPadding", {Parent = listContainer, PaddingBottom = UDim.new(0, 8)})
    
    local isOpen = false
    
    header.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        listContainer.Visible = isOpen
        arrow.Rotation = isOpen and 180 or 0
        dropdownFrame.BackgroundTransparency = isOpen and 0.45 or 0.6
        if isOpen then listContainer.Size = UDim2.new(1, -12, 0, math.min(#items * 28, 140)) end
    end)
    
    for _, itemName in ipairs(items) do
        local itemBtn = new("TextButton", {
            Parent = listContainer, Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = colors.bg4,
            BackgroundTransparency = 0.7, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 11
        })
        new("UICorner", {Parent = itemBtn, CornerRadius = UDim.new(0, 5)})
        
        new("TextLabel", {
            Parent = itemBtn, Text = itemName, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = colors.textDim,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12
        })
        
        itemBtn.MouseButton1Click:Connect(function()
            selectedItem = itemName
            statusLabel.Text = "✓ " .. itemName
            statusLabel.TextColor3 = colors.success
            if configPath then ConfigSystem.Set(configPath, itemName) MarkDirty() end
            if onSelect then onSelect(itemName) end
            task.wait(0.1)
            isOpen = false
            listContainer.Visible = false
            arrow.Rotation = 0
            dropdownFrame.BackgroundTransparency = 0.6
        end)
    end

    if configPath then
        RegisterCallback(configPath, onSelect, "dropdown", nil)
    end
    
    return dropdownFrame
end

function Library:CreateMultiSelect(parent, label, options, callback, configPath)
    local dropdownFrame = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = colors.bg4,
        BackgroundTransparency = 0.6, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 7
    })
    new("UICorner", {Parent = dropdownFrame, CornerRadius = UDim.new(0, 6)})
    
    new("TextLabel", {
        Parent = dropdownFrame, Text = label, Size = UDim2.new(0.5, -10, 0, 36), Position = UDim2.new(0, 8, 0, 2),
        BackgroundTransparency = 1, TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold, TextSize = 9, ZIndex = 8
    })
    
    local dropdownButton = new("TextButton", {
        Parent = dropdownFrame, Size = UDim2.new(0.48, 0, 0, 28), Position = UDim2.new(0.52, 0, 0, 6),
        BackgroundColor3 = colors.bg3, BackgroundTransparency = 0.5, BorderSizePixel = 0,
        Text = "Select... (0)", TextColor3 = colors.textDim, TextSize = 9, Font = Enum.Font.GothamBold,
        AutoButtonColor = false, ZIndex = 8
    })
    new("UICorner", {Parent = dropdownButton, CornerRadius = UDim.new(0, 6)})
    
    local arrow = new("TextLabel", {
        Parent = dropdownButton, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -22, 0, 0),
        BackgroundTransparency = 1, Text = "▼", TextColor3 = colors.primary, TextSize = 10,
        Font = Enum.Font.GothamBold, ZIndex = 9
    })
    
    local optionsContainer = new("ScrollingFrame", {
        Parent = dropdownFrame, Size = UDim2.new(1, -16, 0, 0), Position = UDim2.new(0, 8, 0, 44),
        BackgroundColor3 = colors.bg2, BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false,
        ScrollBarThickness = 3, ScrollBarImageColor3 = colors.primary, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ClipsDescendants = true, ZIndex = 10
    })
    new("UICorner", {Parent = optionsContainer, CornerRadius = UDim.new(0, 6)})
    new("UIListLayout", {Parent = optionsContainer, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)})
    new("UIPadding", {Parent = optionsContainer, PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)})
    
    local selectedItems = {}
    if configPath then
        local saved = ConfigSystem.Get(configPath, {})
        if type(saved) == "table" then
            for _, item in ipairs(saved) do selectedItems[item] = true end
        end
    end
    
    local function updateButtonText()
        local count = 0
        for _ in pairs(selectedItems) do count = count + 1 end
        if count == 0 then
            dropdownButton.Text = "Select... (0)"
            dropdownButton.TextColor3 = colors.textDim
        elseif count == 1 then
            for item in pairs(selectedItems) do dropdownButton.Text = item break end
            dropdownButton.TextColor3 = colors.text
        else
            dropdownButton.Text = string.format("Selected (%d)", count)
            dropdownButton.TextColor3 = colors.text
        end
    end
    
    for _, option in ipairs(options) do
        local optionButton = new("TextButton", {
            Parent = optionsContainer, Size = UDim2.new(1, -10, 0, 28), BackgroundColor3 = colors.bg3,
            BackgroundTransparency = 0.7, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 11
        })
        new("UICorner", {Parent = optionButton, CornerRadius = UDim.new(0, 5)})
        
        local checkbox = new("Frame", {
            Parent = optionButton, Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(1, -23, 0.5, -9),
            BackgroundColor3 = selectedItems[option] and colors.primary or colors.bg1,
            BackgroundTransparency = selectedItems[option] and 0.3 or 0.5, BorderSizePixel = 0, ZIndex = 12
        })
        new("UICorner", {Parent = checkbox, CornerRadius = UDim.new(0, 4)})
        
        local checkmark = new("TextLabel", {
            Parent = checkbox, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "✓",
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = colors.text,
            Visible = selectedItems[option] or false, ZIndex = 13
        })
        
        new("TextLabel", {
            Parent = optionButton, Text = "  " .. option, Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = colors.textDim, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12
        })
        
        optionButton.MouseButton1Click:Connect(function()
            if selectedItems[option] then
                selectedItems[option] = nil
                checkmark.Visible = false
                checkbox.BackgroundColor3 = colors.bg1
                checkbox.BackgroundTransparency = 0.5
            else
                selectedItems[option] = true
                checkmark.Visible = true
                checkbox.BackgroundColor3 = colors.primary
                checkbox.BackgroundTransparency = 0.3
            end
            updateButtonText()
            local selected = {}
            for item in pairs(selectedItems) do table.insert(selected, item) end
            if configPath then ConfigSystem.Set(configPath, selected) MarkDirty() end
            callback(selected)
        end)
    end
    
    updateButtonText()
    task.spawn(function()
        task.wait(0.1)
        local selected = {}
        for item in pairs(selectedItems) do table.insert(selected, item) end
        if #selected > 0 then callback(selected) end
    end)
    
    local isOpen = false
    dropdownButton.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        optionsContainer.Visible = isOpen
        arrow.Rotation = isOpen and 180 or 0
        dropdownFrame.BackgroundTransparency = isOpen and 0.45 or 0.6
        if isOpen then optionsContainer.Size = UDim2.new(1, -16, 0, math.min(150, #options * 30 + 10)) end
    end)
    
    return {Frame = dropdownFrame, GetSelected = function() local s = {} for i in pairs(selectedItems) do table.insert(s, i) end return s end}
end

function Library:CreateTextBox(parent, label, placeholder, defaultValue, callback)
    local container = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 7
    })
    new("UICorner", {Parent = container, CornerRadius = UDim.new(0, 8)})
    
    new("TextLabel", {
        Parent = container, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 8),
        BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamBold, TextSize = 9,
        TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8
    })
    
    local textBox = new("TextBox", {
        Parent = container, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 32),
        BackgroundColor3 = colors.bg3, BackgroundTransparency = 0.7, BorderSizePixel = 0,
        Text = defaultValue or "", PlaceholderText = placeholder or "", Font = Enum.Font.Gotham,
        TextSize = 9, TextColor3 = colors.text, PlaceholderColor3 = colors.textDimmer,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 8
    })
    new("UICorner", {Parent = textBox, CornerRadius = UDim.new(0, 6)})
    new("UIPadding", {Parent = textBox, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})
    
    local lastSavedValue = defaultValue or ""
    textBox.FocusLost:Connect(function()
        local value = textBox.Text
        if value and value ~= "" and value ~= lastSavedValue then
            lastSavedValue = value
            callback(value)
        end
    end)
    
    return {Container = container, TextBox = textBox, SetValue = function(v) textBox.Text = tostring(v) lastSavedValue = tostring(v) end}
end

function Library:Initialize()
    ExecuteConfigCallbacks()
end

_G.GetConfigValue = function(path, default)
    return ConfigSystem.Get(path, default)
end

_G.SetConfigValue = function(path, value)
    ConfigSystem.Set(path, value)
    MarkDirty()
end

return Library
