-- ULTRA LIGHTWEIGHT LYNX UI LIBRARY
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Config System
if not isfolder("Lynx") then makefolder("Lynx") end
if not isfolder("Lynx/Config") then makefolder("Lynx/Config") end

local gameName = tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name):gsub("[^%w_ ]", ""):gsub("%s+", "_")
local ConfigFile = "Lynx/Config/Lynx_" .. gameName .. ".json"

ConfigData = {}
Elements = {}
CURRENT_VERSION = nil

function ForceSaveConfig()
    if writefile then
        task.spawn(function()
            ConfigData._version = CURRENT_VERSION
            writefile(ConfigFile, HttpService:JSONEncode(ConfigData))
        end)
    end
end

function SaveConfig()
    if _G.AutoSaveEnabled == false then return end
    ForceSaveConfig()
end

function LoadConfigFromFile()
    if not CURRENT_VERSION then return end
    if isfile and isfile(ConfigFile) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(ConfigFile)) end)
        if ok and type(data) == "table" and data._version == CURRENT_VERSION then
            ConfigData = data
        else
            ConfigData = { _version = CURRENT_VERSION }
        end
    else
        ConfigData = { _version = CURRENT_VERSION }
    end
end

function LoadConfigElements()
    for key, el in pairs(Elements) do
        if ConfigData[key] ~= nil and el.Set then el:Set(ConfigData[key], true) end
    end
end

function ResetToDefaults()
    local ver = ConfigData._version
    ConfigData = { _version = ver }
    for _, el in pairs(Elements) do
        if el.Default ~= nil and el.Set then pcall(function() el:Set(el.Default, true) end) end
    end
end

-- Minimal Icons
local Icons = {
    player = "rbxassetid://12120698352", settings = "rbxassetid://70386228443175",
    home = "rbxassetid://86450224791749", fish = "rbxassetid://97167558235554",
    rod = "rbxassetid://103247953194129", star = "rbxassetid://107005941750079",
}

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Helper: Create Instance with properties
local function Create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

local Lynx = {}

-- Simple Notification
function Lynx:MakeNotify(cfg)
    cfg = cfg or {}
    task.spawn(function()
        local gui = CoreGui:FindFirstChild("NotifyGui") or Create("ScreenGui", {Name = "NotifyGui", Parent = CoreGui})
        local layout = gui:FindFirstChild("NotifyLayout") or Create("Frame", {
            Name = "NotifyLayout", Parent = gui,
            AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20),
            Size = UDim2.new(0, 280, 1, 0), BackgroundTransparency = 1
        })
        
        local yPos = 0
        for _, c in ipairs(layout:GetChildren()) do yPos = yPos + c.Size.Y.Offset + 8 end
        
        local frame = Create("Frame", {
            Parent = layout, BackgroundColor3 = Color3.fromRGB(25, 25, 30),
            Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 1, -yPos),
            AnchorPoint = Vector2.new(0, 1)
        })
        Create("UICorner", {Parent = frame, CornerRadius = UDim.new(0, 6)})
        Create("TextLabel", {
            Parent = frame, Text = (cfg.Title or "Lynx") .. " - " .. (cfg.Description or ""),
            Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = cfg.Color or Color3.fromRGB(255, 140, 0),
            Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(1, -16, 0, 14),
            BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left
        })
        Create("TextLabel", {
            Parent = frame, Text = cfg.Content or "",
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(180, 180, 180),
            Position = UDim2.new(0, 8, 0, 22), Size = UDim2.new(1, -16, 0, 24),
            BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true
        })
        
        task.delay(cfg.Delay or 4, function() if frame.Parent then frame:Destroy() end end)
    end)
end

function notif(msg, delay, color, title, desc)
    Lynx:MakeNotify({Title = title, Description = desc, Content = msg, Color = color, Delay = delay})
end

-- Main Window
function Lynx:Window(cfg)
    cfg = cfg or {}
    cfg.Title = cfg.Title or "Lynx"
    cfg.Color = cfg.Color or Color3.fromRGB(255, 140, 0)
    cfg["Tab Width"] = cfg["Tab Width"] or 115
    cfg.Version = cfg.Version or 1
    
    CURRENT_VERSION = cfg.Version
    LoadConfigFromFile()
    
    -- Cleanup old
    if CoreGui:FindFirstChild("LynxGui") then CoreGui.LynxGui:Destroy() end
    if CoreGui:FindFirstChild("ToggleUIButton") then CoreGui.ToggleUIButton:Destroy() end
    
    local GuiFunc = {}
    local tabWidth = cfg["Tab Width"]
    local winSize = isMobile and UDim2.new(0, 450, 0, 260) or UDim2.new(0, 580, 0, 360)
    
    -- Main GUI
    local LynxGui = Create("ScreenGui", {Name = "LynxGui", Parent = CoreGui, ResetOnSpawn = false})
    
    local Main = Create("Frame", {
        Parent = LynxGui, Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = winSize, BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    })
    Create("UICorner", {Parent = Main, CornerRadius = UDim.new(0, 8)})
    
    -- Top Bar
    local Top = Create("Frame", {
        Parent = Main, Name = "Top", Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    })
    Create("UICorner", {Parent = Top, CornerRadius = UDim.new(0, 8)})
    
    Create("TextLabel", {
        Parent = Top, Text = cfg.Title, Font = Enum.Font.GothamBold,
        TextSize = 13, TextColor3 = cfg.Color, Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left
    })
    
    -- Close Button
    local Close = Create("TextButton", {
        Parent = Top, Text = "X", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = Color3.fromRGB(200, 200, 200), BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 24)
    })
    
    -- Min Button
    local Min = Create("TextButton", {
        Parent = Top, Text = "-", Font = Enum.Font.GothamBold, TextSize = 18,
        TextColor3 = Color3.fromRGB(200, 200, 200), BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -32, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 24)
    })
    
    -- Tab Container
    local TabContainer = Create("ScrollingFrame", {
        Parent = Main, Name = "TabContainer",
        Position = UDim2.new(0, 6, 0, 38), Size = UDim2.new(0, tabWidth, 1, -44),
        BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0)
    })
    Create("UIListLayout", {Parent = TabContainer, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder})
    
    -- Content Container
    local ContentContainer = Create("Frame", {
        Parent = Main, Name = "ContentContainer",
        Position = UDim2.new(0, tabWidth + 12, 0, 38), Size = UDim2.new(1, -tabWidth - 18, 1, -44),
        BackgroundTransparency = 1, ClipsDescendants = true
    })
    
    local TabName = Create("TextLabel", {
        Parent = ContentContainer, Name = "TabName", Text = "",
        Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(255, 255, 255),
        Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left
    })
    
    local ContentHolder = Create("Frame", {
        Parent = ContentContainer, Name = "ContentHolder",
        Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 1, -28),
        BackgroundTransparency = 1, ClipsDescendants = true
    })
    
    -- Dragging
    local dragging, dragStart, startPos = false, nil, nil
    Top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, Main.Position
        end
    end)
    Top.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Button Events
    Min.MouseButton1Click:Connect(function() Main.Visible = false end)
    Close.MouseButton1Click:Connect(function()
        if LynxGui then LynxGui:Destroy() end
        if CoreGui:FindFirstChild("ToggleUIButton") then CoreGui.ToggleUIButton:Destroy() end
    end)
    
    -- Toggle Key
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Enum.KeyCode.F3 then Main.Visible = not Main.Visible end
    end)
    
    -- Toggle Button (Mobile)
    local ToggleGui = Create("ScreenGui", {Name = "ToggleUIButton", Parent = CoreGui})
    local ToggleBtn = Create("TextButton", {
        Parent = ToggleGui, Text = "☰", Font = Enum.Font.GothamBold, TextSize = 20,
        TextColor3 = cfg.Color, BackgroundColor3 = Color3.fromRGB(30, 30, 35),
        Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0, 15, 0, 100)
    })
    Create("UICorner", {Parent = ToggleBtn, CornerRadius = UDim.new(0, 8)})
    ToggleBtn.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)
    
    -- Toggle button dragging
    local tDrag, tStart, tPos = false, nil, nil
    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            tDrag, tStart, tPos = true, input.Position, ToggleBtn.Position
        end
    end)
    ToggleBtn.InputEnded:Connect(function() tDrag = false end)
    UserInputService.InputChanged:Connect(function(input)
        if tDrag and input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - tStart
            ToggleBtn.Position = UDim2.new(tPos.X.Scale, tPos.X.Offset + d.X, tPos.Y.Scale, tPos.Y.Offset + d.Y)
        end
    end)
    
    function GuiFunc:DestroyGui()
        table.clear(Elements)
        if CoreGui:FindFirstChild("LynxGui") then CoreGui.LynxGui:Destroy() end
        if CoreGui:FindFirstChild("ToggleUIButton") then CoreGui.ToggleUIButton:Destroy() end
    end
    
    -- Tab System
    local Tabs = {}
    local allTabs = {}
    local currentTab = nil
    local tabCount = 0
    
    local function SelectTab(tabFrame, contentFrame, name)
        for _, t in pairs(allTabs) do
            t.btn.BackgroundTransparency = 1
            t.content.Visible = false
        end
        tabFrame.BackgroundTransparency = 0.9
        contentFrame.Visible = true
        TabName.Text = name
        currentTab = tabFrame
    end
    
    function Tabs:AddTab(tabCfg)
        tabCfg = tabCfg or {}
        tabCfg.Name = tabCfg.Name or "Tab"
        tabCfg.Icon = tabCfg.Icon or ""
        
        local TabBtn = Create("TextButton", {
            Parent = TabContainer, Name = "Tab", Text = "",
            Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = tabCount == 0 and 0.9 or 1, LayoutOrder = tabCount
        })
        Create("UICorner", {Parent = TabBtn, CornerRadius = UDim.new(0, 4)})
        
        local iconSize = tabCfg.Icon ~= "" and 18 or 0
        if tabCfg.Icon ~= "" then
            local img = Icons[tabCfg.Icon] or tabCfg.Icon
            Create("ImageLabel", {
                Parent = TabBtn, Image = img, Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(0, 6, 0.5, -8), BackgroundTransparency = 1
            })
        end
        
        Create("TextLabel", {
            Parent = TabBtn, Text = tabCfg.Name, Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundTransparency = 1,
            Position = UDim2.new(0, iconSize + 10, 0, 0), Size = UDim2.new(1, -iconSize - 14, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left
        })
        
        local ContentScroll = Create("ScrollingFrame", {
            Parent = ContentHolder, Name = tabCfg.Name, Visible = tabCount == 0,
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80),
            CanvasSize = UDim2.new(0, 0, 0, 0)
        })
        Create("UIListLayout", {Parent = ContentScroll, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})
        
        table.insert(allTabs, {btn = TabBtn, content = ContentScroll, name = tabCfg.Name})
        
        if tabCount == 0 then SelectTab(TabBtn, ContentScroll, tabCfg.Name) end
        
        TabBtn.MouseButton1Click:Connect(function() SelectTab(TabBtn, ContentScroll, tabCfg.Name) end)
        
        -- Update canvas size
        ContentScroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
            ContentScroll.CanvasSize = UDim2.new(0, 0, 0, ContentScroll:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize.Y + 8)
        end)
        
        -- Update tab container
        TabContainer.CanvasSize = UDim2.new(0, 0, 0, (tabCount + 1) * 31)
        
        tabCount = tabCount + 1
        
        -- Section System
        local Sections = {}
        local sectionCount = 0
        
        function Sections:AddSection(title, alwaysOpen)
            title = title or "Section"
            local isOpen = alwaysOpen == true
            
            local Section = Create("Frame", {
                Parent = ContentScroll, Name = "Section", BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 28), ClipsDescendants = true, LayoutOrder = sectionCount
            })
            
            local Header = Create("Frame", {
                Parent = Section, Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.94
            })
            Create("UICorner", {Parent = Header, CornerRadius = UDim.new(0, 4)})
            
            Create("TextLabel", {
                Parent = Header, Text = title, Font = Enum.Font.GothamBold, TextSize = 12,
                TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -40, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left
            })
            
            local Arrow = Create("TextLabel", {
                Parent = Header, Text = isOpen and "▼" or "▶", Font = Enum.Font.GothamBold, TextSize = 10,
                TextColor3 = Color3.fromRGB(150, 150, 150), BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0, 16, 0, 16)
            })
            
            local ItemsFrame = Create("Frame", {
                Parent = Section, Name = "Items", Position = UDim2.new(0, 0, 0, 32),
                Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1
            })
            Create("UIListLayout", {Parent = ItemsFrame, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})
            
            local function UpdateSize()
                local h = 0
                for _, c in ipairs(ItemsFrame:GetChildren()) do
                    if c:IsA("Frame") then h = h + c.Size.Y.Offset + 4 end
                end
                ItemsFrame.Size = UDim2.new(1, 0, 0, h)
                Section.Size = UDim2.new(1, 0, 0, isOpen and (32 + h) or 28)
            end
            
            ItemsFrame.ChildAdded:Connect(UpdateSize)
            ItemsFrame.ChildRemoved:Connect(UpdateSize)
            
            if alwaysOpen ~= true then
                Header.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        isOpen = not isOpen
                        Arrow.Text = isOpen and "▼" or "▶"
                        UpdateSize()
                    end
                end)
            end
            
            if isOpen then UpdateSize() end
            
            sectionCount = sectionCount + 1
            
            -- Items System
            local Items = {}
            local itemCount = 0
            
            function Items:AddToggle(tCfg)
                tCfg = tCfg or {}
                tCfg.Title = tCfg.Title or "Toggle"
                tCfg.Default = tCfg.Default or false
                tCfg.Callback = tCfg.Callback or function() end
                
                local origDefault = tCfg.Default
                local key = "Toggle_" .. tCfg.Title
                if tCfg.Save ~= false and ConfigData[key] ~= nil then tCfg.Default = ConfigData[key] end
                
                local ToggleFunc = {Value = tCfg.Default, Default = origDefault}
                
                local Toggle = Create("Frame", {
                    Parent = ItemsFrame, Size = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.94,
                    LayoutOrder = itemCount
                })
                Create("UICorner", {Parent = Toggle, CornerRadius = UDim.new(0, 4)})
                
                local TitleLbl = Create("TextLabel", {
                    Parent = Toggle, Text = tCfg.Title, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -60, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left
                })
                
                local ToggleFrame = Create("Frame", {
                    Parent = Toggle, Size = UDim2.new(0, 32, 0, 16),
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                    BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                })
                Create("UICorner", {Parent = ToggleFrame, CornerRadius = UDim.new(1, 0)})
                
                local Circle = Create("Frame", {
                    Parent = ToggleFrame, Size = UDim2.new(0, 12, 0, 12),
                    Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = Color3.fromRGB(200, 200, 200)
                })
                Create("UICorner", {Parent = Circle, CornerRadius = UDim.new(1, 0)})
                
                local Btn = Create("TextButton", {Parent = Toggle, Text = "", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1})
                
                function ToggleFunc:Set(val)
                    ToggleFunc.Value = val
                    if val then
                        TitleLbl.TextColor3 = cfg.Color
                        ToggleFrame.BackgroundColor3 = cfg.Color
                        Circle.Position = UDim2.new(0, 18, 0.5, -6)
                    else
                        TitleLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
                        ToggleFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                        Circle.Position = UDim2.new(0, 2, 0.5, -6)
                    end
                    if tCfg.Save ~= false then ConfigData[key] = val; SaveConfig() end
                    task.spawn(function() tCfg.Callback(val) end)
                end
                
                Btn.MouseButton1Click:Connect(function() ToggleFunc:Set(not ToggleFunc.Value) end)
                ToggleFunc:Set(ToggleFunc.Value)
                
                itemCount = itemCount + 1
                Elements[key] = ToggleFunc
                return ToggleFunc
            end
            
            function Items:AddSlider(sCfg)
                sCfg = sCfg or {}
                sCfg.Title = sCfg.Title or "Slider"
                sCfg.Min = sCfg.Min or 0
                sCfg.Max = sCfg.Max or 100
                sCfg.Default = sCfg.Default or 50
                sCfg.Increment = sCfg.Increment or 1
                sCfg.Callback = sCfg.Callback or function() end
                
                local origDefault = sCfg.Default
                local key = "Slider_" .. sCfg.Title
                if ConfigData[key] ~= nil then sCfg.Default = ConfigData[key] end
                
                local SliderFunc = {Value = sCfg.Default, Default = origDefault}
                
                local Slider = Create("Frame", {
                    Parent = ItemsFrame, Size = UDim2.new(1, 0, 0, 40),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.94,
                    LayoutOrder = itemCount
                })
                Create("UICorner", {Parent = Slider, CornerRadius = UDim.new(0, 4)})
                
                Create("TextLabel", {
                    Parent = Slider, Text = sCfg.Title, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(0.5, 0, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left
                })
                
                local ValLbl = Create("TextLabel", {
                    Parent = Slider, Text = tostring(sCfg.Default), Font = Enum.Font.GothamBold, TextSize = 11,
                    TextColor3 = cfg.Color, BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6),
                    Size = UDim2.new(0.3, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Right
                })
                
                local SliderBar = Create("Frame", {
                    Parent = Slider, Size = UDim2.new(1, -20, 0, 6),
                    Position = UDim2.new(0, 10, 0, 28), BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                })
                Create("UICorner", {Parent = SliderBar, CornerRadius = UDim.new(1, 0)})
                
                local SliderFill = Create("Frame", {
                    Parent = SliderBar, Size = UDim2.new(0.5, 0, 1, 0),
                    BackgroundColor3 = cfg.Color
                })
                Create("UICorner", {Parent = SliderFill, CornerRadius = UDim.new(1, 0)})
                
                local dragging = false
                
                local function Round(n, inc) return math.floor(n / inc + 0.5) * inc end
                
                function SliderFunc:Set(val)
                    val = math.clamp(Round(val, sCfg.Increment), sCfg.Min, sCfg.Max)
                    SliderFunc.Value = val
                    ValLbl.Text = tostring(val)
                    SliderFill.Size = UDim2.new((val - sCfg.Min) / (sCfg.Max - sCfg.Min), 0, 1, 0)
                    ConfigData[key] = val; SaveConfig()
                    task.spawn(function() sCfg.Callback(val) end)
                end
                
                SliderBar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        local scale = math.clamp((input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
                        SliderFunc:Set(sCfg.Min + (sCfg.Max - sCfg.Min) * scale)
                    end
                end)
                SliderBar.InputEnded:Connect(function() dragging = false end)
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local scale = math.clamp((input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
                        SliderFunc:Set(sCfg.Min + (sCfg.Max - sCfg.Min) * scale)
                    end
                end)
                
                SliderFunc:Set(SliderFunc.Value)
                itemCount = itemCount + 1
                Elements[key] = SliderFunc
                return SliderFunc
            end
            
            function Items:AddButton(bCfg)
                bCfg = bCfg or {}
                bCfg.Title = bCfg.Title or "Button"
                bCfg.Callback = bCfg.Callback or function() end
                
                local Button = Create("Frame", {
                    Parent = ItemsFrame, Size = UDim2.new(1, 0, 0, 32),
                    BackgroundTransparency = 1, LayoutOrder = itemCount
                })
                
                local Btn = Create("TextButton", {
                    Parent = Button, Text = bCfg.Title, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 0.94, Size = UDim2.new(1, 0, 1, 0)
                })
                Create("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, 4)})
                
                Btn.MouseButton1Click:Connect(bCfg.Callback)
                
                itemCount = itemCount + 1
            end
            
            function Items:AddInput(iCfg)
                iCfg = iCfg or {}
                iCfg.Title = iCfg.Title or "Input"
                iCfg.Default = iCfg.Default or ""
                iCfg.Callback = iCfg.Callback or function() end
                
                local key = "Input_" .. iCfg.Title
                if ConfigData[key] ~= nil then iCfg.Default = ConfigData[key] end
                
                local InputFunc = {Value = iCfg.Default}
                
                local Input = Create("Frame", {
                    Parent = ItemsFrame, Size = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.94,
                    LayoutOrder = itemCount
                })
                Create("UICorner", {Parent = Input, CornerRadius = UDim.new(0, 4)})
                
                Create("TextLabel", {
                    Parent = Input, Text = iCfg.Title, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0.4, 0, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left
                })
                
                local InputBox = Create("TextBox", {
                    Parent = Input, Text = iCfg.Default, PlaceholderText = "...",
                    Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundColor3 = Color3.fromRGB(40, 40, 45), BackgroundTransparency = 0.5,
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.new(0.5, -10, 0, 24), ClearTextOnFocus = false
                })
                Create("UICorner", {Parent = InputBox, CornerRadius = UDim.new(0, 4)})
                
                function InputFunc:Set(val)
                    InputFunc.Value = val
                    InputBox.Text = val
                    ConfigData[key] = val; SaveConfig()
                    task.spawn(function() iCfg.Callback(val) end)
                end
                
                InputBox.FocusLost:Connect(function() InputFunc:Set(InputBox.Text) end)
                
                itemCount = itemCount + 1
                Elements[key] = InputFunc
                return InputFunc
            end
            
            function Items:AddDropdown(dCfg)
                dCfg = dCfg or {}
                dCfg.Title = dCfg.Title or "Dropdown"
                dCfg.Options = dCfg.Options or {}
                dCfg.Multi = dCfg.Multi or false
                dCfg.Default = dCfg.Default or (dCfg.Multi and {} or nil)
                dCfg.Callback = dCfg.Callback or function() end
                
                local key = "Dropdown_" .. dCfg.Title
                if ConfigData[key] ~= nil then dCfg.Default = ConfigData[key] end
                
                local DropFunc = {Value = dCfg.Default, Options = dCfg.Options}
                local isExpanded = false
                
                local Drop = Create("Frame", {
                    Parent = ItemsFrame, Size = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.94,
                    ClipsDescendants = true, LayoutOrder = itemCount
                })
                Create("UICorner", {Parent = Drop, CornerRadius = UDim.new(0, 4)})
                
                Create("TextLabel", {
                    Parent = Drop, Text = dCfg.Title, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0.4, 0, 0, 16),
                    TextXAlignment = Enum.TextXAlignment.Left
                })
                
                local SelLbl = Create("TextLabel", {
                    Parent = Drop, Text = dCfg.Multi and "Select..." or "Select",
                    Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(180, 180, 180),
                    BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -26, 0, 10), Size = UDim2.new(0.45, 0, 0, 16),
                    TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd
                })
                
                local Arrow = Create("TextLabel", {
                    Parent = Drop, Text = "▼", Font = Enum.Font.GothamBold, TextSize = 10,
                    TextColor3 = Color3.fromRGB(150, 150, 150), BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 10),
                    Size = UDim2.new(0, 16, 0, 16)
                })
                
                local OptionsFrame = Create("Frame", {
                    Parent = Drop, Position = UDim2.new(0, 4, 0, 38),
                    Size = UDim2.new(1, -8, 0, 0), BackgroundTransparency = 1
                })
                Create("UIListLayout", {Parent = OptionsFrame, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder})
                
                local HeaderBtn = Create("TextButton", {Parent = Drop, Text = "", Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1})
                
                local function UpdateDisplay()
                    local texts = {}
                    if dCfg.Multi then
                        for _, v in ipairs(DropFunc.Value) do table.insert(texts, tostring(v)) end
                    elseif DropFunc.Value then
                        table.insert(texts, tostring(DropFunc.Value))
                    end
                    SelLbl.Text = #texts > 0 and table.concat(texts, ", ") or "Select"
                end
                
                local function BuildOptions()
                    for _, c in ipairs(OptionsFrame:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    for i, opt in ipairs(DropFunc.Options) do
                        local OptBtn = Create("TextButton", {
                            Parent = OptionsFrame, Text = tostring(opt),
                            Font = Enum.Font.Gotham, TextSize = 11,
                            TextColor3 = Color3.fromRGB(200, 200, 200),
                            BackgroundColor3 = Color3.fromRGB(50, 50, 55),
                            Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i
                        })
                        Create("UICorner", {Parent = OptBtn, CornerRadius = UDim.new(0, 4)})
                        
                        OptBtn.MouseButton1Click:Connect(function()
                            if dCfg.Multi then
                                local idx = table.find(DropFunc.Value, opt)
                                if idx then table.remove(DropFunc.Value, idx) else table.insert(DropFunc.Value, opt) end
                            else
                                DropFunc.Value = opt
                                isExpanded = false
                                Arrow.Text = "▼"
                                Drop.Size = UDim2.new(1, 0, 0, 36)
                            end
                            UpdateDisplay()
                            ConfigData[key] = DropFunc.Value; SaveConfig()
                            task.spawn(function() dCfg.Callback(DropFunc.Value) end)
                        end)
                    end
                    OptionsFrame.Size = UDim2.new(1, -8, 0, #DropFunc.Options * 26)
                end
                
                HeaderBtn.MouseButton1Click:Connect(function()
                    isExpanded = not isExpanded
                    Arrow.Text = isExpanded and "▲" or "▼"
                    Drop.Size = isExpanded and UDim2.new(1, 0, 0, 42 + #DropFunc.Options * 26) or UDim2.new(1, 0, 0, 36)
                end)
                
                function DropFunc:SetValues(opts, sel)
                    DropFunc.Options = opts or {}
                    DropFunc.Value = sel or (dCfg.Multi and {} or nil)
                    BuildOptions()
                    UpdateDisplay()
                end
                
                function DropFunc:Set(val)
                    DropFunc.Value = val
                    UpdateDisplay()
                    ConfigData[key] = val; SaveConfig()
                    task.spawn(function() dCfg.Callback(val) end)
                end
                
                function DropFunc:Clear()
                    DropFunc.Options = {}
                    DropFunc.Value = dCfg.Multi and {} or nil
                    for _, c in ipairs(OptionsFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                    UpdateDisplay()
                end
                
                function DropFunc:AddOption(opt) table.insert(DropFunc.Options, opt); BuildOptions() end
                
                BuildOptions()
                UpdateDisplay()
                
                itemCount = itemCount + 1
                Elements[key] = DropFunc
                return DropFunc
            end
            
            function Items:AddParagraph(pCfg)
                pCfg = pCfg or {}
                pCfg.Title = pCfg.Title or "Title"
                pCfg.Content = pCfg.Content or ""
                
                local PFunc = {}
                
                local Para = Create("Frame", {
                    Parent = ItemsFrame, Size = UDim2.new(1, 0, 0, 40),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.94,
                    LayoutOrder = itemCount
                })
                Create("UICorner", {Parent = Para, CornerRadius = UDim.new(0, 4)})
                
                Create("TextLabel", {
                    Parent = Para, Text = pCfg.Title, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(1, -20, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left
                })
                
                local ContentLbl = Create("TextLabel", {
                    Parent = Para, Text = pCfg.Content, Font = Enum.Font.Gotham, TextSize = 11,
                    TextColor3 = Color3.fromRGB(180, 180, 180), BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 24), Size = UDim2.new(1, -20, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, RichText = true
                })
                
                function PFunc:SetContent(txt)
                    ContentLbl.Text = txt
                    local lines = math.ceil(ContentLbl.TextBounds.Y / 14)
                    Para.Size = UDim2.new(1, 0, 0, 28 + lines * 14)
                end
                
                itemCount = itemCount + 1
                return PFunc
            end
            
            function Items:AddDivider()
                local Div = Create("Frame", {
                    Parent = ItemsFrame, Size = UDim2.new(1, 0, 0, 2),
                    BackgroundColor3 = cfg.Color, BackgroundTransparency = 0.7,
                    LayoutOrder = itemCount
                })
                Create("UICorner", {Parent = Div, CornerRadius = UDim.new(0, 1)})
                itemCount = itemCount + 1
            end
            
            function Items:AddPanel(pCfg)
                pCfg = pCfg or {}
                pCfg.Title = pCfg.Title or "Panel"
                pCfg.Content = pCfg.Content or ""
                pCfg.Placeholder = pCfg.Placeholder
                pCfg.ButtonText = pCfg.Button or pCfg.ButtonText or "Confirm"
                pCfg.ButtonCallback = pCfg.Callback or pCfg.ButtonCallback or function() end
                pCfg.Default = pCfg.Default or ""
                
                local key = "Panel_" .. pCfg.Title
                if ConfigData[key] ~= nil then pCfg.Default = ConfigData[key] end
                
                local PanelFunc = {Value = pCfg.Default}
                
                local h = pCfg.Placeholder and 90 or 60
                local Panel = Create("Frame", {
                    Parent = ItemsFrame, Size = UDim2.new(1, 0, 0, h),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.94,
                    LayoutOrder = itemCount
                })
                Create("UICorner", {Parent = Panel, CornerRadius = UDim.new(0, 4)})
                
                Create("TextLabel", {
                    Parent = Panel, Text = pCfg.Title, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(1, -20, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Left
                })
                
                if pCfg.Content ~= "" then
                    Create("TextLabel", {
                        Parent = Panel, Text = pCfg.Content, Font = Enum.Font.Gotham, TextSize = 11,
                        TextColor3 = Color3.fromRGB(160, 160, 160), BackgroundTransparency = 1,
                        Position = UDim2.new(0, 10, 0, 22), Size = UDim2.new(1, -20, 0, 12),
                        TextXAlignment = Enum.TextXAlignment.Left, RichText = true
                    })
                end
                
                local InputBox
                local yBtn = 36
                if pCfg.Placeholder then
                    yBtn = 66
                    InputBox = Create("TextBox", {
                        Parent = Panel, Text = pCfg.Default, PlaceholderText = pCfg.Placeholder,
                        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundColor3 = Color3.fromRGB(40, 40, 45),
                        Position = UDim2.new(0, 8, 0, 38), Size = UDim2.new(1, -16, 0, 24),
                        ClearTextOnFocus = false
                    })
                    Create("UICorner", {Parent = InputBox, CornerRadius = UDim.new(0, 4)})
                    InputBox.FocusLost:Connect(function()
                        PanelFunc.Value = InputBox.Text
                        ConfigData[key] = InputBox.Text; SaveConfig()
                    end)
                end
                
                local Btn = Create("TextButton", {
                    Parent = Panel, Text = pCfg.ButtonText, Font = Enum.Font.GothamBold, TextSize = 11,
                    TextColor3 = Color3.fromRGB(220, 220, 220), BackgroundColor3 = Color3.fromRGB(50, 50, 55),
                    Position = UDim2.new(0, 8, 0, yBtn), Size = UDim2.new(1, -16, 0, 24)
                })
                Create("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, 4)})
                Btn.MouseButton1Click:Connect(function() pCfg.ButtonCallback(InputBox and InputBox.Text or "") end)
                
                function PanelFunc:GetInput() return InputBox and InputBox.Text or "" end
                
                itemCount = itemCount + 1
                return PanelFunc
            end
            
            function Items:AddSubSection(title)
                local Sub = Create("Frame", {
                    Parent = ItemsFrame, Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1, LayoutOrder = itemCount
                })
                Create("TextLabel", {
                    Parent = Sub, Text = "── " .. (title or "Sub") .. " ──",
                    Font = Enum.Font.GothamBold, TextSize = 10,
                    TextColor3 = Color3.fromRGB(150, 150, 150), BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left
                })
                itemCount = itemCount + 1
            end
            
            return Items
        end
        
        local safeName = tabCfg.Name:gsub("%s+", "_")
        _G[safeName] = Sections
        return Sections
    end
    
    return Tabs
end

return Lynx
