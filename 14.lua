-- ============================================
-- LYNX GUI LIBRARY v3.0
-- Pure UI Library - Returns Library Object
-- ============================================

local Library = {}
Library.flags = {}
Library.pages = {}
Library._navButtons = {}
Library._currentPage = nil
Library._gui = nil
Library._win = nil
Library._sidebar = nil
Library._contentBg = nil
Library._pageTitle = nil
Library._navContainer = nil
Library._connections = {}
Library._spawns = {}

-- ============================================
-- SERVICES (Cached once)
-- ============================================
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============================================
-- COLOR PALETTE
-- ============================================
local colors = {
    primary = Color3.fromRGB(255, 140, 0),
    secondary = Color3.fromRGB(147, 112, 219),
    accent = Color3.fromRGB(186, 85, 211),
    success = Color3.fromRGB(34, 197, 94),
    bg1 = Color3.fromRGB(30, 30, 30),
    bg2 = Color3.fromRGB(18, 18, 18),
    bg3 = Color3.fromRGB(25, 25, 25),
    bg4 = Color3.fromRGB(35, 35, 35),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(180, 180, 180),
    textDimmer = Color3.fromRGB(120, 120, 120),
    border = Color3.fromRGB(50, 50, 50),
}

-- Window Config
local windowSize = UDim2.new(0, 400, 0, 260)
local minWindowSize = Vector2.new(360, 230)
local maxWindowSize = Vector2.new(720, 520)
local sidebarWidth = 130

-- ============================================
-- INSTANCE CREATOR UTILITY
-- ============================================
local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    return inst
end

-- ============================================
-- CONNECTION MANAGER
-- ============================================
function Library:AddConnection(name, connection)
    if self._connections[name] then
        pcall(function() self._connections[name]:Disconnect() end)
    end
    self._connections[name] = connection
    return connection
end

function Library:AddSpawn(name, thread)
    if self._spawns[name] then
        pcall(function() task.cancel(self._spawns[name]) end)
    end
    self._spawns[name] = thread
    return thread
end

function Library:Cleanup()
    for name, conn in pairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    for name, thread in pairs(self._spawns) do
        pcall(function() task.cancel(thread) end)
    end
    table.clear(self._connections)
    table.clear(self._spawns)
end

-- ============================================
-- CONFIG SYSTEM
-- ============================================
local CONFIG_FOLDER = "LynxGUI_Configs"
local CONFIG_FILE = CONFIG_FOLDER .. "/lynx_config.json"
local CurrentConfig = {}
local DefaultConfig = {}
local isDirty = false
local saveScheduled = false
local CallbackRegistry = {}

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

Library.ConfigSystem = {}

function Library.ConfigSystem.SetDefaults(defaults)
    DefaultConfig = DeepCopy(defaults)
end

function Library.ConfigSystem.Save()
    local success = pcall(function()
        EnsureFolderExists()
        writefile(CONFIG_FILE, HttpService:JSONEncode(CurrentConfig))
    end)
    return success
end

function Library.ConfigSystem.Load()
    EnsureFolderExists()
    CurrentConfig = DeepCopy(DefaultConfig)
    if isfile(CONFIG_FILE) then
        pcall(function()
            local loaded = HttpService:JSONDecode(readfile(CONFIG_FILE))
            MergeTables(CurrentConfig, loaded)
        end)
    end
    return CurrentConfig
end

function Library.ConfigSystem.Get(path, default)
    if not path then return default end
    local value = CurrentConfig
    for key in string.gmatch(path, "[^.]+") do
        if type(value) ~= "table" then return default end
        value = value[key]
    end
    return value ~= nil and value or default
end

function Library.ConfigSystem.Set(path, value)
    if not path then return end
    local keys = {}
    for key in string.gmatch(path, "[^.]+") do table.insert(keys, key) end
    local target = CurrentConfig
    for i = 1, #keys - 1 do
        if type(target[keys[i]]) ~= "table" then target[keys[i]] = {} end
        target = target[keys[i]]
    end
    target[keys[#keys]] = value
end

function Library.ConfigSystem.Reset()
    CurrentConfig = DeepCopy(DefaultConfig)
    Library.ConfigSystem.Save()
end

function Library.ConfigSystem.Delete()
    if isfile(CONFIG_FILE) then
        delfile(CONFIG_FILE)
    end
end

local function MarkDirty()
    isDirty = true
    if saveScheduled then return end
    saveScheduled = true
    task.delay(5, function()
        if isDirty then Library.ConfigSystem.Save() isDirty = false end
        saveScheduled = false
    end)
end

local function RegisterCallback(configPath, callback, componentType, defaultValue)
    if configPath then
        table.insert(CallbackRegistry, {path = configPath, callback = callback, type = componentType, default = defaultValue})
    end
end

local function ExecuteConfigCallbacks()
    for _, entry in ipairs(CallbackRegistry) do
        local value = Library.ConfigSystem.Get(entry.path, entry.default)
        if entry.callback then entry.callback(value) end
    end
end

-- ============================================
-- CREATE WINDOW
-- ============================================
function Library:CreateWindow(config)
    config = config or {}
    local name = config.Name or "LynxGUI"
    local title = config.Title or "LynX"
    local subtitle = config.Subtitle or ""
    
    -- Remove existing GUI
    local existingGUI = CoreGui:FindFirstChild(name)
    if existingGUI then
        existingGUI:Destroy()
        task.wait(0.1)
    end
    
    -- Main GUI Container
    self._gui = new("ScreenGui", {
        Name = name,
        Parent = CoreGui,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 2147483647
    })
    
    local function bringToFront()
        self._gui.DisplayOrder = 2147483647
    end
    
    -- Main Window
    self._win = new("Frame", {
        Parent = self._gui,
        Size = windowSize,
        Position = UDim2.new(0.5, -windowSize.X.Offset/2, 0.5, -windowSize.Y.Offset/2),
        BackgroundColor3 = colors.bg1,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 3
    })
    new("UICorner", {Parent = self._win, CornerRadius = UDim.new(0, 8)})
    
    -- Sidebar
    self._sidebar = new("Frame", {
        Parent = self._win,
        Size = UDim2.new(0, sidebarWidth, 1, -45),
        Position = UDim2.new(0, 0, 0, 45),
        BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0.999,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4
    })
    
    -- Header
    local scriptHeader = new("Frame", {
        Parent = self._win,
        Size = UDim2.new(1, 0, 0, 45),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0.999,
        BorderSizePixel = 0,
        ZIndex = 5
    })
    new("UICorner", {Parent = scriptHeader, CornerRadius = UDim.new(0, 8)})
    
    -- Drag Handle
    local headerDragHandle = new("Frame", {
        Parent = scriptHeader,
        Size = UDim2.new(0, 40, 0, 3),
        Position = UDim2.new(0.5, -20, 0, 8),
        BackgroundColor3 = colors.primary,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ZIndex = 6
    })
    new("UICorner", {Parent = headerDragHandle, CornerRadius = UDim.new(1, 0)})
    
    -- Title
    new("TextLabel", {
        Parent = scriptHeader,
        Text = title,
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = colors.primary,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6
    })
    
    new("ImageLabel", {
        Parent = scriptHeader,
        Image = "rbxassetid://104332967321169",
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, 66, 0.5, -10),
        BackgroundTransparency = 1,
        ImageColor3 = colors.primary,
        ZIndex = 6
    })
    
    local separator = new("Frame", {
        Parent = scriptHeader,
        Size = UDim2.new(0, 2, 0, 24),
        Position = UDim2.new(0, 115, 0.5, -12),
        BackgroundColor3 = colors.primary,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        ZIndex = 6
    })
    new("UICorner", {Parent = separator, CornerRadius = UDim.new(1, 0)})
    
    new("TextLabel", {
        Parent = scriptHeader,
        Text = subtitle,
        Size = UDim2.new(0, 160, 1, 0),
        Position = UDim2.new(0, 145, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = colors.textDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 0.3,
        ZIndex = 6
    })
    
    -- Minimize Button
    local btnMinHeader = new("TextButton", {
        Parent = scriptHeader,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -38, 0.5, -15),
        BackgroundColor3 = colors.bg4,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Text = "─",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = colors.textDim,
        TextTransparency = 0.3,
        AutoButtonColor = false,
        ZIndex = 7
    })
    new("UICorner", {Parent = btnMinHeader, CornerRadius = UDim.new(0, 8)})
    
    -- Navigation Container
    self._navContainer = new("ScrollingFrame", {
        Parent = self._sidebar,
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
    new("UIListLayout", {Parent = self._navContainer, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})
    
    -- Top Bar
    local topBar = new("Frame", {
        Parent = self._win,
        Size = UDim2.new(1, -(sidebarWidth + 14), 0, 32),
        Position = UDim2.new(0, sidebarWidth + 9, 0, 51),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0.999,
        BorderSizePixel = 0,
        ZIndex = 5
    })
    new("UICorner", {Parent = topBar, CornerRadius = UDim.new(0, 10)})
    
    self._pageTitle = new("TextLabel", {
        Parent = topBar,
        Text = "Dashboard",
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        BackgroundTransparency = 1,
        TextColor3 = colors.text,
        TextTransparency = 0.2,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6
    })
    
    -- Resize Handle
    local resizeHandle = new("TextButton", {
        Parent = self._win,
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(1, -18, 1, -18),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        Text = "⋰",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = colors.textDim,
        TextTransparency = 0.4,
        AutoButtonColor = false,
        ZIndex = 100
    })
    new("UICorner", {Parent = resizeHandle, CornerRadius = UDim.new(0, 6)})
    
    -- Minimize System
    local minimized = false
    local icon = nil
    local savedIconPos = UDim2.new(0, 20, 0, 100)
    
    local function createMinimizedIcon()
        if icon then return end
        icon = new("ImageLabel", {
            Parent = self._gui,
            Size = UDim2.new(0, 50, 0, 50),
            Position = savedIconPos,
            BackgroundColor3 = colors.bg2,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            Image = "rbxassetid://118176705805619",
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 50
        })
        new("UICorner", {Parent = icon, CornerRadius = UDim.new(0, 10)})
        
        local logoText = new("TextLabel", {
            Parent = icon,
            Text = "L",
            Size = UDim2.new(1, 0, 1, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 28,
            BackgroundTransparency = 1,
            TextColor3 = colors.primary,
            Visible = icon.Image == "",
            ZIndex = 51
        })
        
        local dragging, dragStart, startPos, dragMoved = false, nil, nil, false
        
        icon.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, dragMoved, dragStart, startPos = true, false, input.Position, icon.Position
            end
        end)
        
        icon.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                if math.sqrt(delta.X^2 + delta.Y^2) > 5 then dragMoved = true end
                icon.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        
        icon.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    dragging = false
                    savedIconPos = icon.Position
                    if not dragMoved then
                        bringToFront()
                        self._win.Visible = true
                        self._win.Size = windowSize
                        self._win.Position = UDim2.new(0.5, -windowSize.X.Offset/2, 0.5, -windowSize.Y.Offset/2)
                        icon:Destroy()
                        icon = nil
                        minimized = false
                    end
                end
            end
        end)
    end
    
    self:AddConnection("minimizeBtn", btnMinHeader.MouseButton1Click:Connect(function()
        if not minimized then
            self._win.Size = UDim2.new(0, 0, 0, 0)
            self._win.Position = UDim2.new(0.5, 0, 0.5, 0)
            self._win.Visible = false
            createMinimizedIcon()
            minimized = true
        end
    end))
    
    -- Dragging System
    local dragging, dragStart, startPos = false, nil, nil
    
    scriptHeader.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            bringToFront()
            dragging, dragStart, startPos = true, input.Position, self._win.Position
        end
    end)
    
    -- Resizing System
    local resizing = false
    local resizeStartPos, resizeStartSize = nil, nil
    
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing, resizeStartPos, resizeStartSize = true, input.Position, self._win.Size
        end
    end)
    
    self:AddConnection("inputChanged", UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and startPos then
                local delta = input.Position - dragStart
                self._win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
            if resizing and resizeStartPos then
                local delta = input.Position - resizeStartPos
                local newWidth = math.clamp(resizeStartSize.X.Offset + delta.X, minWindowSize.X, maxWindowSize.X)
                local newHeight = math.clamp(resizeStartSize.Y.Offset + delta.Y, minWindowSize.Y, maxWindowSize.Y)
                self._win.Size = UDim2.new(0, newWidth, 0, newHeight)
            end
        end
    end))
    
    self:AddConnection("inputEnded", UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            resizing = false
        end
    end))
    
    -- Cleanup on destroy
    self._gui.Destroying:Connect(function()
        self:Cleanup()
    end)
    
    return self
end

-- ============================================
-- CREATE PAGE
-- ============================================
function Library:CreatePage(name, title, imageId, order)
    local page = new("ScrollingFrame", {
        Parent = self._win,
        Size = UDim2.new(1, -(sidebarWidth + 18), 1, -91),
        Position = UDim2.new(0, sidebarWidth + 9, 0, 87),
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
    
    self.pages[name] = {frame = page, title = title}
    
    -- Create Nav Button
    local btn = new("TextButton", {
        Parent = self._navContainer,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order or 999,
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
        Image = imageId or "",
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
        Text = name,
        Size = UDim2.new(1, -45, 1, 0),
        Position = UDim2.new(0, 40, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = colors.textDim,
        TextTransparency = 0.4,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Name = "Label"
    })
    
    self._navButtons[name] = {btn = btn, indicator = indicator, page = page, title = title}
    
    btn.MouseButton1Click:Connect(function()
        self:_switchPage(name)
    end)
    
    return page
end

-- ============================================
-- SET FIRST PAGE
-- ============================================
function Library:SetFirstPage(name, title)
    self:_switchPage(name)
end

-- ============================================
-- PAGE SWITCHING (Internal)
-- ============================================
function Library:_switchPage(pageName)
    if self._currentPage == pageName then return end
    
    for _, pageData in pairs(self.pages) do
        pageData.frame.Visible = false
    end
    
    for name, data in pairs(self._navButtons) do
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
    
    if self.pages[pageName] then
        self.pages[pageName].frame.Visible = true
        if self._pageTitle then
            self._pageTitle.Text = self.pages[pageName].title or pageName
        end
    end
    self._currentPage = pageName
end

-- ============================================
-- CREATE CATEGORY
-- ============================================
function Library:CreateCategory(parent, title)
    local categoryFrame = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 6
    })
    new("UICorner", {Parent = categoryFrame, CornerRadius = UDim.new(0, 4)})
    
    local header = new("TextButton", {
        Parent = categoryFrame,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 7
    })
    
    new("TextLabel", {
        Parent = header,
        Text = title,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8
    })
    
    local arrow = new("TextLabel", {
        Parent = header,
        Text = "▼",
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -24, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = colors.primary,
        ZIndex = 8
    })
    
    local contentContainer = new("Frame", {
        Parent = categoryFrame,
        Size = UDim2.new(1, -16, 0, 0),
        Position = UDim2.new(0, 8, 0, 38),
        BackgroundTransparency = 1,
        Visible = false,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 7
    })
    new("UIListLayout", {Parent = contentContainer, Padding = UDim.new(0, 6)})
    new("UIPadding", {Parent = contentContainer, PaddingBottom = UDim.new(0, 8)})
    
    local isOpen = false
    header.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        contentContainer.Visible = isOpen
        arrow.Rotation = isOpen and 180 or 0
        categoryFrame.BackgroundTransparency = isOpen and 0.8 or 0.85
    end)
    
    return contentContainer
end

-- ============================================
-- CREATE TOGGLE
-- ============================================
function Library:CreateToggle(parent, label, configPath, callback, disableSave)
    local frame = new("Frame", {Parent = parent, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, ZIndex = 7})
    
    new("TextLabel", {
        Parent = frame,
        Text = label,
        Size = UDim2.new(0.68, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        TextColor3 = colors.text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextWrapped = true,
        ZIndex = 8
    })
    
    local toggleBg = new("Frame", {
        Parent = frame,
        Size = UDim2.new(0, 38, 0, 20),
        Position = UDim2.new(1, -38, 0.5, -10),
        BackgroundColor3 = colors.bg4,
        BorderSizePixel = 0,
        ZIndex = 8
    })
    new("UICorner", {Parent = toggleBg, CornerRadius = UDim.new(1, 0)})
    
    local toggleCircle = new("Frame", {
        Parent = toggleBg,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = colors.textDim,
        BorderSizePixel = 0,
        ZIndex = 9
    })
    new("UICorner", {Parent = toggleCircle, CornerRadius = UDim.new(1, 0)})
    
    local btn = new("TextButton", {Parent = toggleBg, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 10})
    
    local on = false
    if configPath and not disableSave then
        on = Library.ConfigSystem.Get(configPath, false)
    end
    
    local function updateVisual()
        toggleBg.BackgroundColor3 = on and colors.primary or colors.bg4
        toggleCircle.Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        toggleCircle.BackgroundColor3 = on and colors.text or colors.textDim
    end
    updateVisual()
    
    btn.MouseButton1Click:Connect(function()
        on = not on
        updateVisual()
        if configPath and not disableSave then
            Library.ConfigSystem.Set(configPath, on)
            MarkDirty()
        end
        if callback then callback(on) end
    end)
    
    if configPath and not disableSave then
        RegisterCallback(configPath, callback, "toggle", false)
    end
    
    self.flags[configPath or label] = on
end

-- ============================================
-- CREATE DROPDOWN (Single Select + Search)
-- ============================================
function Library:CreateDropdown(parent, title, imageId, items, configPath, onSelect, uniqueId)
    local dropdownFrame = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = colors.bg4,
        BackgroundTransparency = 0.935,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 7,
        Name = uniqueId or "Dropdown"
    })
    new("UICorner", {Parent = dropdownFrame, CornerRadius = UDim.new(0, 4)})
    
    local header = new("TextButton", {
        Parent = dropdownFrame,
        Size = UDim2.new(1, -12, 0, 36),
        Position = UDim2.new(0, 6, 0, 2),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 8
    })
    
    if imageId then
        new("ImageLabel", {
            Parent = header,
            Image = imageId,
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, 0, 0.5, -8),
            BackgroundTransparency = 1,
            ImageColor3 = colors.primary,
            ZIndex = 9
        })
    end
    
    new("TextLabel", {
        Parent = header,
        Text = title or "Dropdown",
        Size = UDim2.new(1, -70, 0, 14),
        Position = UDim2.new(0, imageId and 20 or 0, 0, 4),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 9
    })
    
    local initialSelected = configPath and Library.ConfigSystem.Get(configPath, nil) or nil
    local selectedItem = initialSelected
    
    local statusLabel = new("TextLabel", {
        Parent = header,
        Text = selectedItem or "None Selected",
        Size = UDim2.new(1, -70, 0, 12),
        Position = UDim2.new(0, imageId and 26 or 6, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = colors.textDimmer,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 9
    })
    
    local arrow = new("TextLabel", {
        Parent = header,
        Text = "▼",
        Size = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(1, -24, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = colors.primary,
        ZIndex = 9
    })
    
    local contentContainer = new("Frame", {
        Parent = dropdownFrame,
        Size = UDim2.new(1, -12, 0, 0),
        Position = UDim2.new(0, 6, 0, 42),
        BackgroundTransparency = 1,
        Visible = false,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 10
    })
    
    -- Search Box
    local searchBox = new("TextBox", {
        Parent = contentContainer,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = colors.bg3,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "Search...",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = colors.text,
        PlaceholderColor3 = colors.textDimmer,
        ZIndex = 11
    })
    new("UICorner", {Parent = searchBox, CornerRadius = UDim.new(0, 4)})
    new("UIPadding", {Parent = searchBox, PaddingLeft = UDim.new(0, 6)})
    
    local listContainer = new("ScrollingFrame", {
        Parent = contentContainer,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = colors.primary,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 10
    })
    new("UIListLayout", {Parent = listContainer, Padding = UDim.new(0, 4)})
    new("UIPadding", {Parent = listContainer, PaddingBottom = UDim.new(0, 4)})
    
    local isOpen = false
    
    local function createItems(filter)
        for _, child in pairs(listContainer:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local count = 0
        for _, itemName in ipairs(items) do
            if not filter or string.find(itemName:lower(), filter:lower(), 1, true) then
                count = count + 1
                local itemBtn = new("TextButton", {
                    Parent = listContainer,
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = colors.bg4,
                    BackgroundTransparency = 0.7,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 11
                })
                new("UICorner", {Parent = itemBtn, CornerRadius = UDim.new(0, 5)})
                
                new("TextLabel", {
                    Parent = itemBtn,
                    Text = itemName,
                    Size = UDim2.new(1, -12, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    TextColor3 = selectedItem == itemName and colors.success or colors.textDim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 12
                })
                
                itemBtn.MouseButton1Click:Connect(function()
                    selectedItem = itemName
                    statusLabel.Text = "✓ " .. itemName
                    statusLabel.TextColor3 = colors.success
                    
                    if configPath then Library.ConfigSystem.Set(configPath, itemName) MarkDirty() end
                    if onSelect then onSelect(itemName) end
                    
                    task.wait(0.1)
                    isOpen = false
                    contentContainer.Visible = false
                    arrow.Rotation = 0
                    dropdownFrame.BackgroundTransparency = 0.935
                end)
            end
        end
        
        listContainer.Size = UDim2.new(1, 0, 0, math.min(count * 30, 140))
        contentContainer.Size = UDim2.new(1, -12, 0, listContainer.Size.Y.Offset + 32)
    end
    
    header.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        contentContainer.Visible = isOpen
        arrow.Rotation = isOpen and 180 or 0
        dropdownFrame.BackgroundTransparency = isOpen and 0.92 or 0.935
        if isOpen then
            searchBox.Text = ""
            createItems(nil)
        end
    end)
    
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        createItems(searchBox.Text)
    end)
    
    createItems(nil)
    
    if configPath then RegisterCallback(configPath, onSelect, "dropdown", nil) end
    
    -- Store reference for refresh
    local dropdownObj = {
        Frame = dropdownFrame,
        Refresh = function(self, newItems)
            items = newItems
            if isOpen then createItems(searchBox.Text) end
        end
    }
    
    if uniqueId then
        self.flags[uniqueId] = dropdownObj
    end
    
    return dropdownFrame
end

-- ============================================
-- CREATE MULTI SELECT DROPDOWN (Search supported)
-- ============================================
function Library:CreateMultiDropdown(parent, title, imageId, items, configPath, onSelect, uniqueId)
    local dropdownFrame = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = colors.bg4,
        BackgroundTransparency = 0.935,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 7,
        Name = uniqueId or "MultiDropdown"
    })
    new("UICorner", {Parent = dropdownFrame, CornerRadius = UDim.new(0, 4)})
    
    local header = new("TextButton", {
        Parent = dropdownFrame,
        Size = UDim2.new(1, -12, 0, 36),
        Position = UDim2.new(0, 6, 0, 2),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 8
    })
    
    if imageId then
        new("ImageLabel", {
            Parent = header,
            Image = imageId,
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, 0, 0.5, -8),
            BackgroundTransparency = 1,
            ImageColor3 = colors.primary,
            ZIndex = 9
        })
    end
    
    new("TextLabel", {
        Parent = header,
        Text = title or "Multi Select",
        Size = UDim2.new(1, -70, 0, 14),
        Position = UDim2.new(0, imageId and 20 or 0, 0, 4),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 9
    })
    
    -- Initial state
    local selectedItems = {}
    if configPath then
        local saved = Library.ConfigSystem.Get(configPath, {})
        if type(saved) == "table" then
            for _, item in ipairs(saved) do selectedItems[item] = true end
        end
    end
    
    local statusLabel = new("TextLabel", {
        Parent = header,
        Text = "0 Selected",
        Size = UDim2.new(1, -70, 0, 12),
        Position = UDim2.new(0, imageId and 26 or 6, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = colors.textDimmer,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 9
    })
    
    local function updateStatus()
        local count = 0
        for _ in pairs(selectedItems) do count = count + 1 end
        if count == 0 then
            statusLabel.Text = "None Selected"
            statusLabel.TextColor3 = colors.textDimmer
        else
            statusLabel.Text = count .. " Selected"
            statusLabel.TextColor3 = colors.success
        end
    end
    updateStatus()
    
    local arrow = new("TextLabel", {
        Parent = header,
        Text = "▼",
        Size = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(1, -24, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = colors.primary,
        ZIndex = 9
    })
    
    local contentContainer = new("Frame", {
        Parent = dropdownFrame,
        Size = UDim2.new(1, -12, 0, 0),
        Position = UDim2.new(0, 6, 0, 42),
        BackgroundTransparency = 1,
        Visible = false,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 10
    })
    
    -- Search Box
    local searchBox = new("TextBox", {
        Parent = contentContainer,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = colors.bg3,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "Search...",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = colors.text,
        PlaceholderColor3 = colors.textDimmer,
        ZIndex = 11
    })
    new("UICorner", {Parent = searchBox, CornerRadius = UDim.new(0, 4)})
    new("UIPadding", {Parent = searchBox, PaddingLeft = UDim.new(0, 6)})
    
    local listContainer = new("ScrollingFrame", {
        Parent = contentContainer,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = colors.primary,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 10
    })
    new("UIListLayout", {Parent = listContainer, Padding = UDim.new(0, 4)})
    new("UIPadding", {Parent = listContainer, PaddingBottom = UDim.new(0, 4)})
    
    local isOpen = false
    
    local function createItems(filter)
        for _, child in pairs(listContainer:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local count = 0
        for _, itemName in ipairs(items) do
            if not filter or string.find(itemName:lower(), filter:lower(), 1, true) then
                count = count + 1
                local itemBtn = new("TextButton", {
                    Parent = listContainer,
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = colors.bg4,
                    BackgroundTransparency = 0.7,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 11
                })
                new("UICorner", {Parent = itemBtn, CornerRadius = UDim.new(0, 5)})
                
                local isSelected = selectedItems[itemName]
                
                -- Checkbox visual
                local box = new("Frame", {
                    Parent = itemBtn,
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(0, 6, 0.5, -7),
                    BackgroundColor3 = isSelected and colors.primary or colors.bg2,
                    BorderSizePixel = 0,
                    ZIndex = 12
                })
                new("UICorner", {Parent = box, CornerRadius = UDim.new(0, 3)})
                
                if isSelected then
                    new("ImageLabel", {
                        Parent = box,
                        BackgroundTransparency = 1,
                        Image = "rbxassetid://6031094667", -- Checkmark icon
                        Size = UDim2.new(0, 10, 0, 10),
                        Position = UDim2.new(0.5, -5, 0.5, -5),
                        ImageColor3 = colors.text,
                        ZIndex = 13
                    })
                end
                
                new("TextLabel", {
                    Parent = itemBtn,
                    Text = itemName,
                    Size = UDim2.new(1, -30, 1, 0),
                    Position = UDim2.new(0, 26, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    TextColor3 = isSelected and colors.text or colors.textDim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 12
                })
                
                itemBtn.MouseButton1Click:Connect(function()
                    if selectedItems[itemName] then
                        selectedItems[itemName] = nil
                    else
                        selectedItems[itemName] = true
                    end
                    
                    updateStatus()
                    
                    -- Convert set to list for saving/callback
                    local list = {}
                    for item in pairs(selectedItems) do table.insert(list, item) end
                    
                    if configPath then Library.ConfigSystem.Set(configPath, list) MarkDirty() end
                    if onSelect then onSelect(list) end
                    
                    -- Refresh current view (simple rebuild)
                    createItems(searchBox.Text)
                end)
            end
        end
        
        listContainer.Size = UDim2.new(1, 0, 0, math.min(count * 30, 140))
        contentContainer.Size = UDim2.new(1, -12, 0, listContainer.Size.Y.Offset + 32)
    end
    
    header.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        contentContainer.Visible = isOpen
        arrow.Rotation = isOpen and 180 or 0
        dropdownFrame.BackgroundTransparency = isOpen and 0.92 or 0.935
        if isOpen then
            searchBox.Text = ""
            createItems(nil)
        end
    end)
    
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        createItems(searchBox.Text)
    end)
    
    createItems(nil)
    
    if configPath then
        -- Don't register standard callback because multi-select structure is different (table vs string)
        -- We handle init logic manually above
    end
    
    -- Store reference for refresh
    local dropdownObj = {
        Frame = dropdownFrame,
        Refresh = function(self, newItems)
            items = newItems
            if isOpen then createItems(searchBox.Text) end
        end
    }
    
    if uniqueId then
        self.flags[uniqueId] = dropdownObj
    end
    
    return dropdownFrame
end

-- ============================================
-- CREATE INPUT
-- ============================================
function Library:CreateInput(parent, label, configPath, defaultValue, callback)
    local frame = new("Frame", {Parent = parent, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, ZIndex = 7})
    
    new("TextLabel", {
        Parent = frame,
        Text = label,
        Size = UDim2.new(0.55, 0, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        ZIndex = 8
    })
    
    local inputBg = new("Frame", {
        Parent = frame,
        Size = UDim2.new(0.42, 0, 0, 28),
        Position = UDim2.new(0.58, 0, 0.5, -14),
        BackgroundColor3 = colors.bg4,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 8
    })
    new("UICorner", {Parent = inputBg, CornerRadius = UDim.new(0, 6)})
    
    local initialValue = Library.ConfigSystem.Get(configPath, defaultValue)
    local inputBox = new("TextBox", {
        Parent = inputBg,
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(initialValue),
        PlaceholderText = "0.00",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = colors.text,
        PlaceholderColor3 = colors.textDimmer,
        TextXAlignment = Enum.TextXAlignment.Center,
        ClearTextOnFocus = false,
        ZIndex = 9
    })
    
    inputBox.FocusLost:Connect(function()
        local value = tonumber(inputBox.Text)
        if value then
            Library.ConfigSystem.Set(configPath, value)
            MarkDirty()
            if callback then callback(value) end
        else
            inputBox.Text = tostring(initialValue)
        end
    end)
    
    RegisterCallback(configPath, callback, "input", defaultValue)
end

-- ============================================
-- CREATE BUTTON
-- ============================================
function Library:CreateButton(parent, label, callback)
    local btnFrame = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.935,
        BorderSizePixel = 0,
        ZIndex = 8
    })
    new("UICorner", {Parent = btnFrame, CornerRadius = UDim.new(0, 4)})
    
    local button = new("TextButton", {
        Parent = btnFrame,
        Size = UDim2.new(1, -12, 1, -10),
        Position = UDim2.new(0, 6, 0, 5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.935,
        BorderSizePixel = 0,
        Text = label,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = colors.text,
        TextTransparency = 0.3,
        AutoButtonColor = false,
        ZIndex = 9
    })
    new("UICorner", {Parent = button, CornerRadius = UDim.new(0, 4)})
    
    button.MouseButton1Click:Connect(function() pcall(callback) end)
    return btnFrame
end

-- ============================================
-- CREATE TEXTBOX
-- ============================================
function Library:CreateTextBox(parent, label, placeholder, defaultValue, callback)
    local container = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 70),
        BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ZIndex = 7
    })
    new("UICorner", {Parent = container, CornerRadius = UDim.new(0, 8)})
    
    new("TextLabel", {
        Parent = container,
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 10, 0, 8),
        BackgroundTransparency = 1,
        Text = label,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8
    })
    
    local textBox = new("TextBox", {
        Parent = container,
        Size = UDim2.new(1, -20, 0, 32),
        Position = UDim2.new(0, 10, 0, 32),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        Text = defaultValue or "",
        PlaceholderText = placeholder or "",
        Font = Enum.Font.Gotham,
        TextSize = 9,
        TextColor3 = colors.text,
        PlaceholderColor3 = colors.textDimmer,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 8
    })
    new("UICorner", {Parent = textBox, CornerRadius = UDim.new(0, 6)})
    new("UIPadding", {Parent = textBox, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})
    
    local lastSavedValue = defaultValue or ""
    textBox.FocusLost:Connect(function()
        local value = textBox.Text
        if value and value ~= "" and value ~= lastSavedValue then
            lastSavedValue = value
            if callback then callback(value) end
        end
    end)
    
    return {Container = container, TextBox = textBox, SetValue = function(v) textBox.Text = tostring(v) lastSavedValue = tostring(v) end}
end

-- ============================================
-- INITIALIZE
-- ============================================
function Library:Initialize()
    ExecuteConfigCallbacks()
    
    -- Auto-save on player leaving
    Players.PlayerRemoving:Connect(function(plr)
        if plr == localPlayer then
            Library.ConfigSystem.Save()
        end
    end)
end

-- ============================================
-- RETURN LIBRARY
-- ============================================
return Library
