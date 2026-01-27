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
-- COLOR PALETTE (IMPROVED VISIBILITY)
-- ============================================
local colors = {
    primary = Color3.fromRGB(255, 140, 0),
    secondary = Color3.fromRGB(147, 112, 219),
    accent = Color3.fromRGB(186, 85, 211),
    success = Color3.fromRGB(34, 197, 94),
    bg1 = Color3.fromRGB(15, 15, 15),
    bg2 = Color3.fromRGB(25, 25, 25),
    bg3 = Color3.fromRGB(35, 35, 35),
    bg4 = Color3.fromRGB(45, 45, 45),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(200, 200, 200),
    textDimmer = Color3.fromRGB(150, 150, 150),
    border = Color3.fromRGB(60, 60, 60),
}

-- Window Config
local windowSize = UDim2.new(0, 400, 0, 260)
local minWindowSize = Vector2.new(360, 230)
local maxWindowSize = Vector2.new(800, 600)
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
    if _G.AutoSaveEnabled == false then return end
    isDirty = true
    if saveScheduled then return end
    saveScheduled = true
    task.delay(2, function()
        if isDirty and _G.AutoSaveEnabled ~= false then 
            local success = Library.ConfigSystem.Save() 
            isDirty = false
        end
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
-- GLOBAL BRIDGE (For Module compatibility)
-- ============================================
_G.AutoSaveEnabled = true -- Default

function _G.GetConfigValue(key, default)
    return Library.ConfigSystem.Get(key, default)
end

function _G.SaveConfigValue(key, value)
    Library.ConfigSystem.Set(key, value)
    if _G.AutoSaveEnabled then
        MarkDirty()
    end
end

function _G.GetFullConfig()
    return CurrentConfig
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
    
    -- Main Window (Single Background)
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
    
    -- Sidebar (No extra background)
    self._sidebar = new("Frame", {
        Parent = self._win,
        Size = UDim2.new(0, sidebarWidth, 1, -45),
        Position = UDim2.new(0, 0, 0, 45),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4
    })
    
    -- Sidebar Separator Line
    local sidebarLine = new("Frame", {
        Parent = self._sidebar,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = colors.border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 4
    })
    
    -- Header (No extra background)
    local scriptHeader = new("Frame", {
        Parent = self._win,
        Size = UDim2.new(1, 0, 0, 45),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5
    })
    
    -- Header Bottom Border
    local headerLine = new("Frame", {
        Parent = scriptHeader,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = colors.border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 5
    })
    
    -- Drag Handle
    local headerDragHandle = new("Frame", {
        Parent = scriptHeader,
        Size = UDim2.new(0, 40, 0, 3),
        Position = UDim2.new(0.5, -20, 0, 8),
        BackgroundColor3 = colors.primary,
        BackgroundTransparency = 0.3,
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
        BackgroundTransparency = 0.3,
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
        ZIndex = 6
    })
    
    -- Minimize Button
    local btnMinHeader = new("TextButton", {
        Parent = scriptHeader,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -38, 0.5, -15),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "─",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = colors.textDim,
        AutoButtonColor = false,
        ZIndex = 7
    })
    new("UICorner", {Parent = btnMinHeader, CornerRadius = UDim.new(0, 8)})
    
    -- Navigation Container (No ScrollBar)
    self._navContainer = new("Frame", {
        Parent = self._sidebar,
        Size = UDim2.new(1, -8, 1, -12),
        Position = UDim2.new(0, 4, 0, 6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5
    })
    new("UIListLayout", {Parent = self._navContainer, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})
    
    -- Content Area (No extra background)
    self._contentBg = new("Frame", {
        Parent = self._win,
        Size = UDim2.new(1, -(sidebarWidth + 10), 1, -52),
        Position = UDim2.new(0, sidebarWidth + 5, 0, 47),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4
    })
    
    -- Top Bar (Improved visibility)
    local topBar = new("Frame", {
        Parent = self._contentBg,
        Size = UDim2.new(1, -8, 0, 32),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 5
    })
    new("UICorner", {Parent = topBar, CornerRadius = UDim.new(0, 6)})
    
    self._pageTitle = new("TextLabel", {
        Parent = topBar,
        Text = "Dashboard",
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        BackgroundTransparency = 1,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6
    })
    
    -- Resize Handle
    local resizeHandle = new("TextButton", {
        Parent = self._win,
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(1, -18, 1, -18),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "⋰",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = colors.textDim,
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
            BackgroundTransparency = 0,
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
    local page = new("Frame", {
        Parent = self._contentBg,
        Size = UDim2.new(1, -16, 1, -44),
        Position = UDim2.new(0, 8, 0, 40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 5
    })
    
    -- ScrollingFrame untuk content yang bisa discroll
    local contentContainer = new("ScrollingFrame", {
        Parent = page,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = colors.primary,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        ZIndex = 5
    })
    
    new("UIListLayout", {Parent = contentContainer, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    new("UIPadding", {Parent = contentContainer, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)})
    
    self.pages[name] = {frame = page, title = title, content = contentContainer}
    
    -- Create Nav Button (Improved visibility)
    local btn = new("TextButton", {
        Parent = self._navContainer,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = colors.bg2,
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
        TextSize = 10,
        TextColor3 = colors.textDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Name = "Label"
    })
    
    self._navButtons[name] = {btn = btn, indicator = indicator, page = page, title = title}
    
    btn.MouseButton1Click:Connect(function()
        self:_switchPage(name)
    end)
    
    return contentContainer
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
        data.btn.BackgroundColor3 = isActive and colors.bg2 or colors.bg2
        data.btn.BackgroundTransparency = isActive and 0 or 1
        local icon = data.btn:FindFirstChild("Icon")
        if icon then
            icon.ImageColor3 = isActive and colors.primary or colors.textDim
        end
        local label = data.btn:FindFirstChild("Label")
        if label then
            label.TextColor3 = isActive and colors.text or colors.textDim
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
-- CREATE CATEGORY (Improved visibility)
-- ============================================
function Library:CreateCategory(parent, title)
    local categoryFrame = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 6
    })
    new("UICorner", {Parent = categoryFrame, CornerRadius = UDim.new(0, 6)})
    
    local header = new("TextButton", {
        Parent = categoryFrame,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 7
    })
    
    new("TextLabel", {
        Parent = header,
        Text = title,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8
    })
    
    local arrow = new("TextLabel", {
        Parent = header,
        Text = "▼",
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -28, 0, 0),
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
    new("UIListLayout", {Parent = contentContainer, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
    new("UIPadding", {Parent = contentContainer, PaddingBottom = UDim.new(0, 8)})
    
    local isOpen = false
    header.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        contentContainer.Visible = isOpen
        arrow.Rotation = isOpen and 180 or 0
        categoryFrame.BackgroundTransparency = isOpen and 0 or 0
    end)
    
    return contentContainer
end

-- ============================================
-- CREATE TOGGLE
-- ============================================
function Library:CreateToggle(parent, label, configPath, callback, disableSave, defaultValue)
    local frame = new("Frame", {Parent = parent, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, ZIndex = 7})
    
    new("TextLabel", {
        Parent = frame,
        Text = label,
        Size = UDim2.new(1, -50, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        ZIndex = 8
    })
    
    local toggleBg = new("Frame", {
        Parent = frame,
        Size = UDim2.new(0, 36, 0, 20),
        Position = UDim2.new(1, -36, 0.5, -10),
        BackgroundColor3 = colors.bg3,
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
    
    local on = defaultValue or false
    if configPath and not disableSave then
        on = Library.ConfigSystem.Get(configPath, on)
    end
    
    local function updateVisual()
        toggleBg.BackgroundColor3 = on and colors.primary or colors.bg3
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
        RegisterCallback(configPath, callback, "toggle", defaultValue or false)
    end
    
    self.flags[configPath or label] = on
    return frame
end

-- ============================================
-- CREATE DROPDOWN (Single Select + Search)
-- ============================================
function Library:CreateDropdown(parent, title, imageId, items, configPath, onSelect, uniqueId, defaultValue)
    local dropdownFrame = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 7,
        Name = uniqueId or "Dropdown"
    })
    new("UICorner", {Parent = dropdownFrame, CornerRadius = UDim.new(0, 6)})
    
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
        TextSize = 9,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 9
    })
    
    local initialSelected = configPath and Library.ConfigSystem.Get(configPath, defaultValue) or defaultValue
    local selectedItem = initialSelected
    
    local statusLabel = new("TextLabel", {
        Parent = header,
        Text = selectedItem or "None Selected",
        Size = UDim2.new(1, -70, 0, 12),
        Position = UDim2.new(0, imageId and 26 or 6, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 8,
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
        BackgroundColor3 = colors.bg4,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "Search...",
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextColor3 = colors.text,
        PlaceholderColor3 = colors.textDimmer,
        ZIndex = 11
    })
    new("UICorner", {Parent = searchBox, CornerRadius = UDim.new(0, 4)})
    new("UIPadding", {Parent = searchBox, PaddingLeft = UDim.new(0, 6)})
    
    -- No ScrollingFrame, just a clipped Frame
    local listContainer = new("Frame", {
        Parent = contentContainer,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1,
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
                    BackgroundTransparency = 0,
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
                    TextSize = 8,
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
                    dropdownFrame.BackgroundTransparency = 0
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
        dropdownFrame.BackgroundTransparency = isOpen and 0 or 0
        if isOpen then
            searchBox.Text = ""
            createItems(nil)
        end
    end)
    
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        createItems(searchBox.Text)
    end)
    
    createItems(nil)
    
    if configPath then RegisterCallback(configPath, onSelect, "dropdown", defaultValue) end

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
function Library:CreateMultiDropdown(parent, title, imageId, items, configPath, onSelect, uniqueId, defaultValues)
    local dropdownFrame = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 7,
        Name = uniqueId or "MultiDropdown"
    })
    new("UICorner", {Parent = dropdownFrame, CornerRadius = UDim.new(0, 6)})
    
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
        TextSize = 9,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 9
    })
    
    -- Initial state
    local selectedItems = {}
    if configPath then
        local saved = Library.ConfigSystem.Get(configPath, defaultValues or {})
        if type(saved) == "table" then
            for _, item in ipairs(saved) do selectedItems[item] = true end
        end
    elseif defaultValues then
        for _, item in ipairs(defaultValues) do selectedItems[item] = true end
    end
    
    local statusLabel = new("TextLabel", {
        Parent = header,
        Text = "0 Selected",
        Size = UDim2.new(1, -70, 0, 12),
        Position = UDim2.new(0, imageId and 26 or 6, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 8,
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
        BackgroundColor3 = colors.bg4,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "Search...",
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextColor3 = colors.text,
        PlaceholderColor3 = colors.textDimmer,
        ZIndex = 11
    })
    new("UICorner", {Parent = searchBox, CornerRadius = UDim.new(0, 4)})
    new("UIPadding", {Parent = searchBox, PaddingLeft = UDim.new(0, 6)})
    
    -- No ScrollingFrame
    local listContainer = new("Frame", {
        Parent = contentContainer,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1,
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
                    BackgroundTransparency = 0,
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
                        Image = "rbxassetid://6031094667",
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
                    TextSize = 8,
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
                    
                    -- Refresh current view
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
        dropdownFrame.BackgroundTransparency = isOpen and 0 or 0
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
        -- Don't register standard callback because multi-select structure is different
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
        TextSize = 9,
        ZIndex = 8
    })
    
    local inputBg = new("Frame", {
        Parent = frame,
        Size = UDim2.new(0.42, 0, 0, 28),
        Position = UDim2.new(0.58, 0, 0.5, -14),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0,
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
        TextSize = 9,
        TextColor3 = colors.text,
        PlaceholderColor3 = colors.textDimmer,
        TextXAlignment = Enum.TextXAlignment.Center,
        ClearTextOnFocus = false,
        ZIndex = 9
    })
    
    local function resolveValue(text)
        local num = tonumber(text)
        return num or text
    end

    inputBox.FocusLost:Connect(function()
        local rawValue = inputBox.Text
        local value = resolveValue(rawValue)
        
        if configPath then
            Library.ConfigSystem.Set(configPath, value)
            MarkDirty()
        end
        if callback then callback(value) end
    end)
    
    RegisterCallback(configPath, callback, "input", defaultValue)
    return frame
end

-- ============================================
-- CREATE BUTTON
-- ============================================
function Library:CreateButton(parent, label, callback)
    local btnFrame = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = colors.primary,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ZIndex = 8
    })
    new("UICorner", {Parent = btnFrame, CornerRadius = UDim.new(0, 6)})
    
    local button = new("TextButton", {
        Parent = btnFrame,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = label,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = colors.text,
        AutoButtonColor = false,
        ZIndex = 9
    })
    
    button.MouseButton1Click:Connect(function() pcall(callback) end)
    return btnFrame
end

-- ============================================
-- CREATE TEXTBOX
-- ============================================
function Library:CreateTextBox(parent, label, placeholder, configPath, defaultValue, callback)
    local container = new("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 70),
        BackgroundColor3 = colors.bg3,
        BackgroundTransparency = 0,
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
    
    local initialValue = configPath and Library.ConfigSystem.Get(configPath, defaultValue) or (defaultValue or "")
    
    local textBox = new("TextBox", {
        Parent = container,
        Size = UDim2.new(1, -20, 0, 32),
        Position = UDim2.new(0, 10, 0, 32),
        BackgroundColor3 = colors.bg4,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = tostring(initialValue),
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
    
    local lastValue = initialValue
    textBox.FocusLost:Connect(function()
        local value = textBox.Text
        if value ~= lastValue then
            lastValue = value
            if configPath then
                Library.ConfigSystem.Set(configPath, value)
                MarkDirty()
            end
            if callback then callback(value) end
        end
    end)
    
    if configPath then RegisterCallback(configPath, callback, "input", defaultValue) end
    
    return {Container = container, TextBox = textBox, SetValue = function(v) textBox.Text = tostring(v) lastValue = tostring(v) end}
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

function Library:LoadConfig(data)
    if type(data) ~= "table" then return end
    CurrentConfig = data
    ExecuteConfigCallbacks()
    Library.ConfigSystem.Save()
end

-- ============================================
-- LYNX API COMPATIBILITY WRAPPER
-- Provides compatibility with Module.lua API
-- ============================================

-- Notification System
function Library:MakeNotify(config)
    config = config or {}
    local title = config.Title or "Notification"
    local desc = config.Description or ""
    local content = config.Content or ""
    local color = config.Color or colors.primary
    local delay = config.Delay or 3
    
    if not self._gui then return end
    
    local notif = new("Frame", {
        Parent = self._gui,
        Size = UDim2.new(0, 280, 0, 70),
        Position = UDim2.new(1, -290, 1, -80),
        BackgroundColor3 = colors.bg2,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 200
    })
    new("UICorner", {Parent = notif, CornerRadius = UDim.new(0, 8)})
    
    local accent = new("Frame", {
        Parent = notif,
        Size = UDim2.new(0, 4, 1, -8),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        ZIndex = 201
    })
    new("UICorner", {Parent = accent, CornerRadius = UDim.new(1, 0)})
    
    new("TextLabel", {
        Parent = notif,
        Text = title,
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.new(0, 14, 0, 6),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201
    })
    
    new("TextLabel", {
        Parent = notif,
        Text = desc,
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.new(0, 14, 0, 24),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201
    })
    
    new("TextLabel", {
        Parent = notif,
        Text = content,
        Size = UDim2.new(1, -20, 0, 24),
        Position = UDim2.new(0, 14, 0, 40),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 9,
        TextColor3 = colors.textDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        ZIndex = 201
    })
    
    task.delay(delay, function()
        if notif and notif.Parent then
            notif:Destroy()
        end
    end)
end

-- Window wrapper (Lynx API compatibility)
function Library:Window(config)
    config = config or {}
    
    -- Load saved config at startup
    Library.ConfigSystem.Load()
    
    -- Map Lynx config to Library config
    self:CreateWindow({
        Name = "LynxGui",
        Title = config.Title or "LynX",
        Subtitle = config.Footer or ""
    })
    
    -- Return Window-like object
    local WindowObject = {}
    WindowObject._library = self
    WindowObject._tabs = {}
    WindowObject._tabOrder = 0
    WindowObject._initialized = false
    
    -- Auto-initialize after a delay
    task.delay(0.5, function()
        if not WindowObject._initialized then
            WindowObject._initialized = true
            Library:Initialize()
        end
    end)
    
    function WindowObject:AddTab(tabConfig)
        tabConfig = tabConfig or {}
        local tabName = tabConfig.Name or "Tab"
        local tabIcon = tabConfig.Icon or ""
        
        -- Map icon names to rbxassetids
        local iconMap = {
            ["player"] = "rbxassetid://12120698352",
            ["web"] = "rbxassetid://137601480983962",
            ["bag"] = "rbxassetid://8601111810",
            ["shop"] = "rbxassetid://4985385964",
            ["cart"] = "rbxassetid://128874923961846",
            ["plug"] = "rbxassetid://137601480983962",
            ["settings"] = "rbxassetid://70386228443175",
            ["loop"] = "rbxassetid://122032243989747",
            ["gps"] = "rbxassetid://78381660144034",
            ["compas"] = "rbxassetid://125300760963399",
            ["gamepad"] = "rbxassetid://84173963561612",
            ["boss"] = "rbxassetid://13132186360",
            ["scroll"] = "rbxassetid://114127804740858",
            ["menu"] = "rbxassetid://6340513838",
            ["crosshair"] = "rbxassetid://12614416478",
            ["user"] = "rbxassetid://108483430622128",
            ["stat"] = "rbxassetid://12094445329",
            ["eyes"] = "rbxassetid://14321059114",
            ["sword"] = "rbxassetid://82472368671405",
            ["discord"] = "rbxassetid://94434236999817",
            ["star"] = "rbxassetid://107005941750079",
            ["skeleton"] = "rbxassetid://17313330026",
            ["payment"] = "rbxassetid://18747025078",
            ["scan"] = "rbxassetid://109869955247116",
            ["alert"] = "rbxassetid://73186275216515",
            ["question"] = "rbxassetid://17510196486",
            ["idea"] = "rbxassetid://16833255748",
            ["strom"] = "rbxassetid://13321880293",
            ["water"] = "rbxassetid://100076212630732",
            ["dcs"] = "rbxassetid://15310731934",
            ["start"] = "rbxassetid://108886429866687",
            ["next"] = "rbxassetid://12662718374",
            ["rod"] = "rbxassetid://103247953194129",
            ["fish"] = "rbxassetid://97167558235554",
            ["send"] = "rbxassetid://122775063389583",
            ["home"] = "rbxassetid://86450224791749",
        }
        
        local iconId = ""
        if tabIcon and tabIcon ~= "" then
            iconId = iconMap[tabIcon:lower()] or ""
        end
        self._library._tabOrder = (self._library._tabOrder or 0) + 1
        
        local page = self._library:CreatePage(tabName, tabName, iconId, self._library._tabOrder)

    -- Create Tab object
        local TabObject = {}
        TabObject._page = page
        TabObject._library = self._library
        TabObject._sections = {}
        
        function TabObject:AddSection(sectionTitle, isOpen)
            sectionTitle = sectionTitle or "Section"
            
            local category = self._library:CreateCategory(self._page, sectionTitle)
            
            -- Create Section object
            local SectionObject = {}
            SectionObject._container = category
            SectionObject._library = self._library
            SectionObject._layoutOrder = 0
            
            local function getNextLayoutOrder()
                SectionObject._layoutOrder = SectionObject._layoutOrder + 1
                return SectionObject._layoutOrder
            end
            
            function SectionObject:AddToggle(toggleConfig)
                toggleConfig = toggleConfig or {}
                local title = toggleConfig.Title or "Toggle"
                local default = toggleConfig.Default or false
                local callback = toggleConfig.Callback
                local noSave = toggleConfig.NoSave or false
                local configPath = noSave and nil or ("Toggles." .. title:gsub("%s+", "_"))
                
                local frame = self._library:CreateToggle(self._container, title, configPath, callback, noSave, default)
                if frame then frame.LayoutOrder = getNextLayoutOrder() end
                
                -- Return toggle controller object
                local toggleObj = {
                    _value = default,
                    SetValue = function(self, val)
                        self._value = val
                        if callback then callback(val) end
                    end,
                    GetValue = function(self)
                        return self._value
                    end
                }
                return toggleObj
            end
            
            function SectionObject:AddDropdown(dropdownConfig)
                dropdownConfig = dropdownConfig or {}
                local title = dropdownConfig.Title or "Dropdown"
                local options = dropdownConfig.Options or {}
                local default = dropdownConfig.Default
                local callback = dropdownConfig.Callback
                local noSave = dropdownConfig.NoSave or false
                local isMulti = dropdownConfig.Multi or false
                local configPath = noSave and nil or ((isMulti and "MultiDropdowns." or "Dropdowns.") .. title:gsub("%s+", "_"))
                local uniqueId = title:gsub("%s+", "_")
                
                -- If Multi=true, use CreateMultiDropdown
                if isMulti then
                    local frame = self._library:CreateMultiDropdown(self._container, title, nil, options, configPath, callback, uniqueId)
                    if frame then frame.LayoutOrder = getNextLayoutOrder() end
                    
                    local dropdownObj = {
                        _options = options,
                        SetOptions = function(self, newOptions)
                            self._options = newOptions
                            local flagObj = Library.flags[uniqueId]
                            if flagObj and flagObj.Refresh then
                                flagObj:Refresh(newOptions)
                            end
                        end
                    }
                    return dropdownObj
                end
                
                -- Set default if provided (single select)
                if default and configPath then
                    local current = Library.ConfigSystem.Get(configPath, nil)
                    if current == nil then
                        Library.ConfigSystem.Set(configPath, default)
                    end
                end
                
                local frame = self._library:CreateDropdown(self._container, title, nil, options, configPath, callback, uniqueId, default)
                if frame then frame.LayoutOrder = getNextLayoutOrder() end
                
                -- Return dropdown controller
                local dropdownObj = {
                    _options = options,
                    SetOptions = function(self, newOptions)
                        self._options = newOptions
                        local flagObj = Library.flags[uniqueId]
                        if flagObj and flagObj.Refresh then
                            flagObj:Refresh(newOptions)
                        end
                    end,
                    GetOptions = function(self)
                        return self._options
                    end
                }
                return dropdownObj
            end
            
            function SectionObject:AddMultiDropdown(dropdownConfig)
                dropdownConfig = dropdownConfig or {}
                local title = dropdownConfig.Title or "Multi Select"
                local options = dropdownConfig.Options or {}
                local default = dropdownConfig.Default or {}
                local callback = dropdownConfig.Callback
                local noSave = dropdownConfig.NoSave or false
                local configPath = noSave and nil or ("MultiDropdowns." .. title:gsub("%s+", "_"))
                local uniqueId = title:gsub("%s+", "_")
                
                local frame = self._library:CreateMultiDropdown(self._container, title, nil, options, configPath, callback, uniqueId, default)
                if frame then frame.LayoutOrder = getNextLayoutOrder() end
                
                local dropdownObj = {
                    _options = options,
                    SetOptions = function(self, newOptions)
                        self._options = newOptions
                        local flagObj = Library.flags[uniqueId]
                        if flagObj and flagObj.Refresh then
                            flagObj:Refresh(newOptions)
                        end
                    end
                }
                return dropdownObj
            end
            
            function SectionObject:AddInput(inputConfig)
                inputConfig = inputConfig or {}
                local title = inputConfig.Title or "Input"
                local default = inputConfig.Default or ""
                local placeholder = inputConfig.Placeholder or ""
                local callback = inputConfig.Callback
                local noSave = inputConfig.NoSave or false
                local configPath = noSave and nil or ("Inputs." .. title:gsub("%s+", "_"))
                
                -- Use CreateTextBox if placeholder is provided, otherwise use CreateInput
                if placeholder ~= "" then
                    local textBoxObj = self._library:CreateTextBox(self._container, title, placeholder, configPath, default, callback)
                    if textBoxObj and textBoxObj.Container then textBoxObj.Container.LayoutOrder = getNextLayoutOrder() end
                    return {
                        SetValue = function(self, val)
                            if textBoxObj and textBoxObj.SetValue then
                                textBoxObj.SetValue(val)
                            end
                        end,
                        GetValue = function(self)
                            if textBoxObj and textBoxObj.TextBox then
                                return textBoxObj.TextBox.Text
                            end
                            return default
                        end
                    }
                else
                    local frame = self._library:CreateInput(self._container, title, configPath, default, callback)
                    if frame then frame.LayoutOrder = getNextLayoutOrder() end
                    return {
                        SetValue = function(self, val)
                            -- Input update not implemented yet
                        end
                    }
                end
            end
            
            function SectionObject:AddButton(buttonConfig)
                buttonConfig = buttonConfig or {}
                local title = buttonConfig.Title or "Button"
                local callback = buttonConfig.Callback or function() end
                
                local frame = self._library:CreateButton(self._container, title, callback)
                if frame then frame.LayoutOrder = getNextLayoutOrder() end
            end
            
            function SectionObject:AddParagraph(paragraphConfig)
                paragraphConfig = paragraphConfig or {}
                local title = paragraphConfig.Title or ""
                local content = paragraphConfig.Content or ""
                
                -- Create simple paragraph frame
                local frame = new("Frame", {
                    Parent = self._container,
                    Size = UDim2.new(1, 0, 0, 44),
                    BackgroundTransparency = 1,
                    ZIndex = 7,
                    LayoutOrder = getNextLayoutOrder()
                })
                
                new("TextLabel", {
                    Parent = frame,
                    Text = title,
                    Size = UDim2.new(1, 0, 0, 16),
                    Position = UDim2.new(0, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    TextSize = 10,
                    TextColor3 = colors.text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 8
                })
                
                new("TextLabel", {
                    Parent = frame,
                    Text = content,
                    Size = UDim2.new(1, 0, 0, 24),
                    Position = UDim2.new(0, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham,
                    TextSize = 9,
                    TextColor3 = colors.textDim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 8
                })
            end
            
            table.insert(self._sections, SectionObject)
            return SectionObject
        end
        
        -- Set first page if this is the first tab
        if self._library._tabOrder == 1 then
            self._library:SetFirstPage(tabName)
        end
        
        table.insert(self._tabs, TabObject)
        return TabObject
    end
    
    return WindowObject
end

-- Alias for backward compatibility
Library.Window = Library.Window

-- ============================================
-- RETURN LIBRARY
-- ============================================
return Library
