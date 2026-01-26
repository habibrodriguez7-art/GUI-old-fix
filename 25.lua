local HttpService = game:GetService("HttpService")

if not isfolder("Lynx") then makefolder("Lynx") end
if not isfolder("Lynx/Config") then makefolder("Lynx/Config") end

local gameName = tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name)
gameName = gameName:gsub("[^%w_ ]", ""):gsub("%s+", "_")
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
        local ok, result = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFile))
        end)
        if ok and type(result) == "table" then
            ConfigData = result._version == CURRENT_VERSION and result or { _version = CURRENT_VERSION }
        else
            ConfigData = { _version = CURRENT_VERSION }
        end
    else
        ConfigData = { _version = CURRENT_VERSION }
    end
end

function LoadConfigElements()
    for key, element in pairs(Elements) do
        if ConfigData[key] ~= nil and element.Set then
            element:Set(ConfigData[key], true)
        end
    end
end

function ResetToDefaults()
    local version = ConfigData._version
    ConfigData = { _version = version }
    for key, element in pairs(Elements) do
        if element.Default ~= nil and element.Set then
            pcall(function() element:Set(element.Default, true) end)
        end
    end
end

local Icons = {
    player = "rbxassetid://12120698352", web = "rbxassetid://137601480983962",
    bag = "rbxassetid://8601111810", shop = "rbxassetid://4985385964",
    cart = "rbxassetid://128874923961846", plug = "rbxassetid://137601480983962",
    settings = "rbxassetid://70386228443175", loop = "rbxassetid://122032243989747",
    gps = "rbxassetid://78381660144034", compas = "rbxassetid://125300760963399",
    gamepad = "rbxassetid://84173963561612", boss = "rbxassetid://13132186360",
    scroll = "rbxassetid://114127804740858", menu = "rbxassetid://6340513838",
    crosshair = "rbxassetid://12614416478", user = "rbxassetid://108483430622128",
    stat = "rbxassetid://12094445329", eyes = "rbxassetid://14321059114",
    sword = "rbxassetid://82472368671405", discord = "rbxassetid://94434236999817",
    star = "rbxassetid://107005941750079", skeleton = "rbxassetid://17313330026",
    payment = "rbxassetid://18747025078", scan = "rbxassetid://109869955247116",
    alert = "rbxassetid://73186275216515", question = "rbxassetid://17510196486",
    idea = "rbxassetid://16833255748", strom = "rbxassetid://13321880293",
    water = "rbxassetid://100076212630732", dcs = "rbxassetid://15310731934",
    start = "rbxassetid://108886429866687", next = "rbxassetid://12662718374",
    rod = "rbxassetid://103247953194129", fish = "rbxassetid://97167558235554",
    send = "rbxassetid://122775063389583", home = "rbxassetid://86450224791749",
}

local UIS = game:GetService("UserInputService")
local Player = game:GetService("Players").LocalPlayer
local Mouse = Player:GetMouse()
local CoreGui = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
local viewport = workspace.CurrentCamera.ViewportSize

local function isMobile()
    return UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled
end
local IsMobile = isMobile()

local function MakeDraggable(topbar, object)
    local dragging, dragStart, startPos = false, nil, nil
    object.Size = IsMobile and UDim2.new(0, 470, 0, 270) or UDim2.new(0, 640, 0, 400)
    
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, object.Position
        end
    end)
    topbar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    topbar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local Lynx = {}

function Lynx:MakeNotify(cfg)
    cfg = cfg or {}
    cfg.Title = cfg.Title or "Lynx"
    cfg.Description = cfg.Description or "Notification"
    cfg.Content = cfg.Content or ""
    cfg.Color = cfg.Color or Color3.fromRGB(255, 140, 0)
    cfg.Delay = cfg.Delay or 5
    
    task.spawn(function()
        if not CoreGui:FindFirstChild("NotifyGui") then
            local ng = Instance.new("ScreenGui")
            ng.Name, ng.Parent = "NotifyGui", CoreGui
        end
        if not CoreGui.NotifyGui:FindFirstChild("NotifyLayout") then
            local nl = Instance.new("Frame")
            nl.Name, nl.AnchorPoint, nl.Position = "NotifyLayout", Vector2.new(1, 1), UDim2.new(1, -30, 1, -30)
            nl.Size, nl.BackgroundTransparency, nl.Parent = UDim2.new(0, 320, 1, 0), 1, CoreGui.NotifyGui
            nl.ChildRemoved:Connect(function()
                local c = 0
                for _, v in nl:GetChildren() do
                    v.Position = UDim2.new(0, 0, 1, -((v.Size.Y.Offset + 12) * c))
                    c = c + 1
                end
            end)
        end
        
        local posY = 0
        for _, v in CoreGui.NotifyGui.NotifyLayout:GetChildren() do
            posY = -(v.Position.Y.Offset) + v.Size.Y.Offset + 12
        end
        
        local nf = Instance.new("Frame")
        nf.BackgroundColor3, nf.Size = Color3.fromRGB(20, 20, 25), UDim2.new(1, 0, 0, 60)
        nf.AnchorPoint, nf.Position = Vector2.new(0, 1), UDim2.new(0, 0, 1, -posY)
        nf.Parent = CoreGui.NotifyGui.NotifyLayout
        Instance.new("UICorner", nf).CornerRadius = UDim.new(0, 6)
        
        local t = Instance.new("TextLabel", nf)
        t.Font, t.Text = Enum.Font.GothamBold, cfg.Title .. " - " .. cfg.Description
        t.TextColor3, t.TextSize, t.TextXAlignment = cfg.Color, 13, Enum.TextXAlignment.Left
        t.BackgroundTransparency, t.Size, t.Position = 1, UDim2.new(1, -10, 0, 20), UDim2.new(0, 8, 0, 5)
        
        local c = Instance.new("TextLabel", nf)
        c.Font, c.Text = Enum.Font.Gotham, cfg.Content
        c.TextColor3, c.TextSize, c.TextXAlignment = Color3.fromRGB(180, 180, 180), 12, Enum.TextXAlignment.Left
        c.TextWrapped, c.BackgroundTransparency = true, 1
        c.Size, c.Position = UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 25)
        
        task.delay(cfg.Delay, function() if nf and nf.Parent then nf:Destroy() end end)
    end)
    return { Close = function() end }
end

function notif(msg, delay, color, title, desc)
    return Lynx:MakeNotify({ Title = title or "Lynx", Description = desc or "Notification", Content = msg or "", Color = color or Color3.fromRGB(255, 165, 0), Delay = delay or 4 })
end

function Lynx:Window(cfg)
    cfg = cfg or {}
    cfg.Title = cfg.Title or "Lynx"
    cfg.Footer = cfg.Footer or "Lynx >:D"
    cfg.Color = cfg.Color or Color3.fromRGB(255, 140, 0)
    cfg["Tab Width"] = cfg["Tab Width"] or 120
    cfg.Version = cfg.Version or 1
    cfg.Image = cfg.Image or "104332967321169"
    
    CURRENT_VERSION = cfg.Version
    LoadConfigFromFile()
    
    local GuiFunc = {}
    
    local LynxGui = Instance.new("ScreenGui")
    LynxGui.Name, LynxGui.ResetOnSpawn, LynxGui.Parent = "LynxGui", false, CoreGui
    
    local Main = Instance.new("Frame")
    Main.Name, Main.AnchorPoint = "Main", Vector2.new(0.5, 0.5)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.Size = IsMobile and UDim2.new(0, 470, 0, 270) or UDim2.new(0, 640, 0, 400)
    Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Main.Parent = LynxGui
    Instance.new("UICorner", Main)
    
    local Top = Instance.new("Frame", Main)
    Top.Name, Top.Size, Top.BackgroundTransparency = "Top", UDim2.new(1, 0, 0, 38), 1
    
    local TitleLabel = Instance.new("TextLabel", Top)
    TitleLabel.Font, TitleLabel.Text = Enum.Font.GothamBold, cfg.Title
    TitleLabel.TextColor3, TitleLabel.TextSize, TitleLabel.TextXAlignment = cfg.Color, 14, Enum.TextXAlignment.Left
    TitleLabel.BackgroundTransparency, TitleLabel.Size, TitleLabel.Position = 1, UDim2.new(0.5, 0, 1, 0), UDim2.new(0, 10, 0, 0)
    
    local FooterLabel = Instance.new("TextLabel", Top)
    FooterLabel.Font, FooterLabel.Text = Enum.Font.GothamBold, cfg.Footer
    FooterLabel.TextColor3, FooterLabel.TextSize, FooterLabel.TextXAlignment = cfg.Color, 14, Enum.TextXAlignment.Left
    FooterLabel.BackgroundTransparency = 1
    FooterLabel.Size = UDim2.new(0.4, 0, 1, 0)
    FooterLabel.Position = UDim2.new(0, TitleLabel.TextBounds.X + 15, 0, 0)
    
    local Close = Instance.new("TextButton", Top)
    Close.Text, Close.AnchorPoint = "", Vector2.new(1, 0.5)
    Close.Position, Close.Size = UDim2.new(1, -8, 0.5, 0), UDim2.new(0, 25, 0, 25)
    Close.BackgroundTransparency = 1
    local CloseImg = Instance.new("ImageLabel", Close)
    CloseImg.Image, CloseImg.AnchorPoint = "rbxassetid://9886659671", Vector2.new(0.5, 0.5)
    CloseImg.Position, CloseImg.Size, CloseImg.BackgroundTransparency = UDim2.new(0.5, 0, 0.5, 0), UDim2.new(1, -8, 1, -8), 1
    
    local Min = Instance.new("TextButton", Top)
    Min.Text, Min.AnchorPoint = "", Vector2.new(1, 0.5)
    Min.Position, Min.Size = UDim2.new(1, -38, 0.5, 0), UDim2.new(0, 25, 0, 25)
    Min.BackgroundTransparency = 1
    local MinImg = Instance.new("ImageLabel", Min)
    MinImg.Image, MinImg.AnchorPoint = "rbxassetid://9886659276", Vector2.new(0.5, 0.5)
    MinImg.Position, MinImg.Size, MinImg.BackgroundTransparency = UDim2.new(0.5, 0, 0.5, 0), UDim2.new(1, -9, 1, -9), 1
    
    local Divider = Instance.new("Frame", Main)
    Divider.AnchorPoint, Divider.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 38)
    Divider.Size, Divider.BackgroundColor3, Divider.BackgroundTransparency = UDim2.new(1, 0, 0, 1), Color3.fromRGB(255, 255, 255), 0.85
    
    local LayersTab = Instance.new("Frame", Main)
    LayersTab.Position, LayersTab.Size = UDim2.new(0, 9, 0, 50), UDim2.new(0, cfg["Tab Width"], 1, -59)
    LayersTab.BackgroundTransparency = 1
    
    local ScrollTab = Instance.new("ScrollingFrame", LayersTab)
    ScrollTab.Size, ScrollTab.CanvasSize = UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0)
    ScrollTab.ScrollBarThickness, ScrollTab.BackgroundTransparency = 0, 1
    local TabLayout = Instance.new("UIListLayout", ScrollTab)
    TabLayout.Padding, TabLayout.SortOrder = UDim.new(0, 3), Enum.SortOrder.LayoutOrder
    
    local function UpdateTabScroll()
        local y = 0
        for _, child in ScrollTab:GetChildren() do
            if child:IsA("Frame") then y = y + 3 + child.Size.Y.Offset end
        end
        ScrollTab.CanvasSize = UDim2.new(0, 0, 0, y)
    end
    ScrollTab.ChildAdded:Connect(UpdateTabScroll)
    ScrollTab.ChildRemoved:Connect(UpdateTabScroll)
    
    local Layers = Instance.new("Frame", Main)
    Layers.Position = UDim2.new(0, cfg["Tab Width"] + 18, 0, 50)
    Layers.Size = UDim2.new(1, -(cfg["Tab Width"] + 27), 1, -59)
    Layers.BackgroundTransparency = 1
    
    local NameTab = Instance.new("TextLabel", Layers)
    NameTab.Font, NameTab.Text = Enum.Font.GothamBold, ""
    NameTab.TextColor3, NameTab.TextSize, NameTab.TextXAlignment = Color3.fromRGB(255, 255, 255), 24, Enum.TextXAlignment.Left
    NameTab.BackgroundTransparency, NameTab.Size = 1, UDim2.new(1, 0, 0, 30)
    
    local LayersReal = Instance.new("Frame", Layers)
    LayersReal.AnchorPoint, LayersReal.Position = Vector2.new(0, 1), UDim2.new(0, 0, 1, 0)
    LayersReal.Size, LayersReal.ClipsDescendants, LayersReal.BackgroundTransparency = UDim2.new(1, 0, 1, -33), true, 1
    
    local LayersFolder = Instance.new("Folder", LayersReal)
    LayersFolder.Name = "LayersFolder"
    local PageLayout = Instance.new("UIPageLayout", LayersFolder)
    PageLayout.SortOrder, PageLayout.TweenTime = Enum.SortOrder.LayoutOrder, 0.3
    
    function GuiFunc:DestroyGui()
        table.clear(Elements)
        if CoreGui:FindFirstChild("LynxGui") then LynxGui:Destroy() end
        if CoreGui:FindFirstChild("ToggleUIButton") then CoreGui.ToggleUIButton:Destroy() end
    end
    
    Min.Activated:Connect(function() Main.Visible = false end)
    Close.Activated:Connect(function()
        if LynxGui then LynxGui:Destroy() end
        if CoreGui:FindFirstChild("ToggleUIButton") then CoreGui.ToggleUIButton:Destroy() end
    end)
    
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F3 then Main.Visible = not Main.Visible end
    end)
    
    -- Toggle UI Button
    local ToggleGui = Instance.new("ScreenGui")
    ToggleGui.Name, ToggleGui.Parent = "ToggleUIButton", CoreGui
    local ToggleBtn = Instance.new("ImageLabel", ToggleGui)
    ToggleBtn.Size, ToggleBtn.Position = UDim2.new(0, 40, 0, 40), UDim2.new(0, 20, 0, 100)
    ToggleBtn.Image, ToggleBtn.BackgroundTransparency = "rbxassetid://" .. cfg.Image, 1
    local Btn = Instance.new("TextButton", ToggleBtn)
    Btn.Size, Btn.BackgroundTransparency, Btn.Text = UDim2.new(1, 0, 1, 0), 1, ""
    Btn.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)
    
    local dragging, dragStart, startPos = false, nil, nil
    Btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, ToggleBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            ToggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    MakeDraggable(Top, Main)
    
    -- Dropdown overlay
    local DropOverlay = Instance.new("Frame", Layers)
    DropOverlay.Name, DropOverlay.Size, DropOverlay.Visible = "DropOverlay", UDim2.new(1, 0, 1, 0), false
    DropOverlay.BackgroundColor3, DropOverlay.BackgroundTransparency = Color3.fromRGB(0, 0, 0), 0.5
    
    local DropSelect = Instance.new("Frame", DropOverlay)
    DropSelect.AnchorPoint, DropSelect.Position = Vector2.new(1, 0.5), UDim2.new(1, -10, 0.5, 0)
    DropSelect.Size, DropSelect.BackgroundColor3 = UDim2.new(0, 160, 0.9, 0), Color3.fromRGB(30, 30, 30)
    Instance.new("UICorner", DropSelect).CornerRadius = UDim.new(0, 4)
    
    local DropFolder = Instance.new("Folder", DropSelect)
    local DropPageLayout = Instance.new("UIPageLayout", DropFolder)
    DropPageLayout.SortOrder, DropPageLayout.TweenTime = Enum.SortOrder.LayoutOrder, 0.01
    
    local CloseOverlay = Instance.new("TextButton", DropOverlay)
    CloseOverlay.Size, CloseOverlay.BackgroundTransparency, CloseOverlay.Text = UDim2.new(1, -170, 1, 0), 1, ""
    CloseOverlay.Activated:Connect(function() DropOverlay.Visible = false end)
    
    local Tabs = {}
    local CountTab, CountDropdown = 0, 0
    
    function Tabs:AddTab(TabCfg)
        TabCfg = TabCfg or {}
        TabCfg.Name = TabCfg.Name or "Tab"
        TabCfg.Icon = TabCfg.Icon or ""
        
        local ScrolLayers = Instance.new("ScrollingFrame", LayersFolder)
        ScrolLayers.ScrollBarThickness, ScrolLayers.BackgroundTransparency = 0, 1
        ScrolLayers.LayoutOrder, ScrolLayers.Size = CountTab, UDim2.new(1, 0, 1, 0)
        local SectionLayout = Instance.new("UIListLayout", ScrolLayers)
        SectionLayout.Padding, SectionLayout.SortOrder = UDim.new(0, 3), Enum.SortOrder.LayoutOrder
        
        local Tab = Instance.new("Frame", ScrollTab)
        Tab.Size, Tab.LayoutOrder = UDim2.new(1, 0, 0, 30), CountTab
        Tab.BackgroundColor3, Tab.BackgroundTransparency = Color3.fromRGB(255, 255, 255), CountTab == 0 and 0.92 or 0.999
        Instance.new("UICorner", Tab).CornerRadius = UDim.new(0, 4)
        
        local TabButton = Instance.new("TextButton", Tab)
        TabButton.Size, TabButton.BackgroundTransparency, TabButton.Text = UDim2.new(1, 0, 1, 0), 1, ""
        
        local FeatureImg = Instance.new("ImageLabel", Tab)
        FeatureImg.Position, FeatureImg.Size = UDim2.new(0, 9, 0, 7), UDim2.new(0, 16, 0, 16)
        FeatureImg.BackgroundTransparency = 1
        if TabCfg.Icon ~= "" then
            FeatureImg.Image = Icons[TabCfg.Icon] or TabCfg.Icon
        end
        
        local TabName = Instance.new("TextLabel", Tab)
        TabName.Font, TabName.Text = Enum.Font.GothamBold, "| " .. TabCfg.Name
        TabName.TextColor3, TabName.TextSize, TabName.TextXAlignment = Color3.fromRGB(255, 255, 255), 13, Enum.TextXAlignment.Left
        TabName.BackgroundTransparency, TabName.Size, TabName.Position = 1, UDim2.new(1, 0, 1, 0), UDim2.new(0, 30, 0, 0)
        
        if CountTab == 0 then
            PageLayout:JumpToIndex(0)
            NameTab.Text = TabCfg.Name
            local Indicator = Instance.new("Frame", Tab)
            Indicator.Name, Indicator.BackgroundColor3 = "Indicator", cfg.Color
            Indicator.Position, Indicator.Size = UDim2.new(0, 2, 0, 9), UDim2.new(0, 2, 0, 12)
        end
        
        TabButton.Activated:Connect(function()
            local ind
            for _, s in ScrollTab:GetChildren() do
                if s:FindFirstChild("Indicator") then ind = s.Indicator break end
            end
            if ind and Tab.LayoutOrder ~= PageLayout.CurrentPage.LayoutOrder then
                for _, tf in ScrollTab:GetChildren() do
                    if tf.Name ~= "UIListLayout" then tf.BackgroundTransparency = 0.999 end
                end
                Tab.BackgroundTransparency = 0.92
                ind.Position = UDim2.new(0, 2, 0, 9 + (33 * Tab.LayoutOrder))
                PageLayout:JumpToIndex(Tab.LayoutOrder)
                NameTab.Text = TabCfg.Name
            end
        end)
        
        local Sections = {}
        
        function Sections:AddSection(Title, AlwaysOpen)
            Title = Title or "Section"
            local isOpen = AlwaysOpen == true
            
            local Section = Instance.new("Frame", ScrolLayers)
            Section.Size, Section.ClipsDescendants, Section.BackgroundTransparency = UDim2.new(1, 0, 0, 30), true, 1
            
            local SectionReal = Instance.new("Frame", Section)
            SectionReal.AnchorPoint, SectionReal.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 0)
            SectionReal.Size = UDim2.new(1, 0, 0, 30)
            SectionReal.BackgroundColor3, SectionReal.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.935
            Instance.new("UICorner", SectionReal).CornerRadius = UDim.new(0, 4)
            
            local SectionTitle = Instance.new("TextLabel", SectionReal)
            SectionTitle.Font, SectionTitle.Text = Enum.Font.GothamBold, Title
            SectionTitle.TextColor3, SectionTitle.TextSize, SectionTitle.TextXAlignment = Color3.fromRGB(230, 230, 230), 13, Enum.TextXAlignment.Left
            SectionTitle.BackgroundTransparency, SectionTitle.Position = 1, UDim2.new(0, 10, 0, 8)
            SectionTitle.Size = UDim2.new(1, -50, 0, 14)
            
            local Arrow = Instance.new("ImageLabel", SectionReal)
            Arrow.Image, Arrow.AnchorPoint = "rbxassetid://16851841101", Vector2.new(1, 0.5)
            Arrow.Position, Arrow.Size, Arrow.Rotation = UDim2.new(1, -5, 0.5, 0), UDim2.new(0, 20, 0, 20), -90
            Arrow.BackgroundTransparency = 1
            
            local SectionAdd = Instance.new("Frame", Section)
            SectionAdd.AnchorPoint, SectionAdd.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 33)
            SectionAdd.Size, SectionAdd.BackgroundTransparency, SectionAdd.Visible = UDim2.new(1, 0, 0, 0), 1, false
            local ItemLayout = Instance.new("UIListLayout", SectionAdd)
            ItemLayout.Padding, ItemLayout.SortOrder = UDim.new(0, 3), Enum.SortOrder.LayoutOrder
            
            local function UpdateScroll()
                local y = 0
                for _, child in ScrolLayers:GetChildren() do
                    if child:IsA("Frame") then y = y + 3 + child.Size.Y.Offset end
                end
                ScrolLayers.CanvasSize = UDim2.new(0, 0, 0, y)
            end
            
            local function UpdateSection()
                if isOpen then
                    SectionAdd.Visible = true
                    local h = 33
                    for _, v in SectionAdd:GetChildren() do
                        if v:IsA("Frame") then h = h + v.Size.Y.Offset + 3 end
                    end
                    Arrow.Rotation = 0
                    Section.Size = UDim2.new(1, 0, 0, h)
                    SectionAdd.Size = UDim2.new(1, 0, 0, h - 33)
                else
                    Arrow.Rotation = -90
                    Section.Size = UDim2.new(1, 0, 0, 30)
                    SectionAdd.Visible = false
                end
                UpdateScroll()
            end
            
            if AlwaysOpen == true then
                isOpen = true
                UpdateSection()
            end
            
            if AlwaysOpen ~= true then
                local SectionButton = Instance.new("TextButton", SectionReal)
                SectionButton.Size, SectionButton.BackgroundTransparency, SectionButton.Text = UDim2.new(1, 0, 1, 0), 1, ""
                SectionButton.Activated:Connect(function()
                    isOpen = not isOpen
                    UpdateSection()
                end)
            end
            
            SectionAdd.ChildAdded:Connect(UpdateSection)
            SectionAdd.ChildRemoved:Connect(UpdateSection)
            
            local Items = {}
            local CountItem = 0
            
            function Items:AddParagraph(ParagraphCfg)
                ParagraphCfg = ParagraphCfg or {}
                ParagraphCfg.Title = ParagraphCfg.Title or "Title"
                ParagraphCfg.Content = ParagraphCfg.Content or ""
                
                local Para = Instance.new("Frame", SectionAdd)
                Para.Size, Para.LayoutOrder = UDim2.new(1, 0, 0, 46), CountItem
                Para.BackgroundColor3, Para.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.935
                Instance.new("UICorner", Para).CornerRadius = UDim.new(0, 4)
                
                local PTitle = Instance.new("TextLabel", Para)
                PTitle.Font, PTitle.Text = Enum.Font.GothamBold, ParagraphCfg.Title
                PTitle.TextColor3, PTitle.TextSize, PTitle.TextXAlignment = Color3.fromRGB(231, 231, 231), 13, Enum.TextXAlignment.Left
                PTitle.BackgroundTransparency, PTitle.Position, PTitle.Size = 1, UDim2.new(0, 10, 0, 10), UDim2.new(1, -16, 0, 13)
                
                local PContent = Instance.new("TextLabel", Para)
                PContent.Font, PContent.Text = Enum.Font.Gotham, ParagraphCfg.Content
                PContent.TextColor3, PContent.TextSize, PContent.TextXAlignment = Color3.fromRGB(255, 255, 255), 12, Enum.TextXAlignment.Left
                PContent.TextWrapped, PContent.RichText, PContent.BackgroundTransparency = true, true, 1
                PContent.Position, PContent.Size = UDim2.new(0, 10, 0, 25), UDim2.new(1, -16, 0, 14)
                
                local function UpdateSize()
                    Para.Size = UDim2.new(1, 0, 0, PContent.TextBounds.Y + 35)
                end
                PContent:GetPropertyChangedSignal("TextBounds"):Connect(UpdateSize)
                UpdateSize()
                
                CountItem = CountItem + 1
                return { SetContent = function(_, c) PContent.Text = c UpdateSize() end }
            end
            
            function Items:AddButton(ButtonCfg)
                ButtonCfg = ButtonCfg or {}
                ButtonCfg.Title = ButtonCfg.Title or "Button"
                ButtonCfg.Callback = ButtonCfg.Callback or function() end
                
                local Btn = Instance.new("Frame", SectionAdd)
                Btn.Size, Btn.LayoutOrder = UDim2.new(1, 0, 0, 40), CountItem
                Btn.BackgroundColor3, Btn.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.935
                Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 4)
                
                local MainBtn = Instance.new("TextButton", Btn)
                MainBtn.Font, MainBtn.Text = Enum.Font.GothamBold, ButtonCfg.Title
                MainBtn.TextColor3, MainBtn.TextSize, MainBtn.TextTransparency = Color3.fromRGB(255, 255, 255), 12, 0.3
                MainBtn.BackgroundColor3, MainBtn.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.935
                MainBtn.Size, MainBtn.Position = UDim2.new(1, -12, 1, -10), UDim2.new(0, 6, 0, 5)
                Instance.new("UICorner", MainBtn).CornerRadius = UDim.new(0, 4)
                MainBtn.MouseButton1Click:Connect(ButtonCfg.Callback)
                
                CountItem = CountItem + 1
            end
            
            function Items:AddToggle(ToggleCfg)
                ToggleCfg = ToggleCfg or {}
                ToggleCfg.Title = ToggleCfg.Title or "Toggle"
                ToggleCfg.Content = ToggleCfg.Content or ""
                ToggleCfg.Default = ToggleCfg.Default or false
                ToggleCfg.Callback = ToggleCfg.Callback or function() end
                
                local origDefault = ToggleCfg.Default
                local configKey = "Toggle_" .. ToggleCfg.Title
                if ToggleCfg.Save ~= false and ConfigData[configKey] ~= nil then
                    ToggleCfg.Default = ConfigData[configKey]
                end
                
                local ToggleFunc = { Value = ToggleCfg.Default, Default = origDefault }
                
                local Toggle = Instance.new("Frame", SectionAdd)
                Toggle.Size, Toggle.LayoutOrder = UDim2.new(1, 0, 0, 46), CountItem
                Toggle.BackgroundColor3, Toggle.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.935
                Instance.new("UICorner", Toggle).CornerRadius = UDim.new(0, 4)
                
                local TTitle = Instance.new("TextLabel", Toggle)
                TTitle.Font, TTitle.Text = Enum.Font.GothamBold, ToggleCfg.Title
                TTitle.TextColor3, TTitle.TextSize, TTitle.TextXAlignment = Color3.fromRGB(231, 231, 231), 13, Enum.TextXAlignment.Left
                TTitle.BackgroundTransparency, TTitle.Position, TTitle.Size = 1, UDim2.new(0, 10, 0, 10), UDim2.new(1, -100, 0, 13)
                
                local TContent = Instance.new("TextLabel", Toggle)
                TContent.Font, TContent.Text = Enum.Font.GothamBold, ToggleCfg.Content
                TContent.TextColor3, TContent.TextSize, TContent.TextTransparency = Color3.fromRGB(255, 255, 255), 12, 0.6
                TContent.TextXAlignment, TContent.TextWrapped, TContent.BackgroundTransparency = Enum.TextXAlignment.Left, true, 1
                TContent.Position, TContent.Size = UDim2.new(0, 10, 0, 23), UDim2.new(1, -100, 0, 12)
                
                local ToggleBtn = Instance.new("TextButton", Toggle)
                ToggleBtn.Size, ToggleBtn.BackgroundTransparency, ToggleBtn.Text = UDim2.new(1, 0, 1, 0), 1, ""
                
                local ToggleFrame = Instance.new("Frame", Toggle)
                ToggleFrame.AnchorPoint, ToggleFrame.Position = Vector2.new(1, 0.5), UDim2.new(1, -15, 0.5, 0)
                ToggleFrame.Size, ToggleFrame.BackgroundTransparency = UDim2.new(0, 30, 0, 15), 0.92
                Instance.new("UICorner", ToggleFrame)
                
                local Circle = Instance.new("Frame", ToggleFrame)
                Circle.BackgroundColor3, Circle.Size = Color3.fromRGB(230, 230, 230), UDim2.new(0, 14, 0, 14)
                Instance.new("UICorner", Circle).CornerRadius = UDim.new(0, 15)
                
                function ToggleFunc:Set(Value)
                    ToggleFunc.Value = Value
                    task.spawn(function()
                        local ok, err = pcall(function() ToggleCfg.Callback(Value) end)
                        if not ok then warn("Toggle error:", err) end
                    end)
                    if ToggleCfg.Save ~= false then
                        ConfigData[configKey] = Value
                        SaveConfig()
                    end
                    if Value then
                        TTitle.TextColor3 = cfg.Color
                        Circle.Position = UDim2.new(0, 15, 0, 0)
                        ToggleFrame.BackgroundColor3 = cfg.Color
                        ToggleFrame.BackgroundTransparency = 0
                    else
                        TTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
                        Circle.Position = UDim2.new(0, 0, 0, 0)
                        ToggleFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        ToggleFrame.BackgroundTransparency = 0.92
                    end
                end
                
                ToggleBtn.Activated:Connect(function()
                    ToggleFunc.Value = not ToggleFunc.Value
                    ToggleFunc:Set(ToggleFunc.Value)
                end)
                
                ToggleFunc:Set(ToggleFunc.Value)
                CountItem = CountItem + 1
                Elements[configKey] = ToggleFunc
                return ToggleFunc
            end
            
            function Items:AddSlider(SliderCfg)
                SliderCfg = SliderCfg or {}
                SliderCfg.Title = SliderCfg.Title or "Slider"
                SliderCfg.Min = SliderCfg.Min or 0
                SliderCfg.Max = SliderCfg.Max or 100
                SliderCfg.Default = SliderCfg.Default or 50
                SliderCfg.Increment = SliderCfg.Increment or 1
                SliderCfg.Callback = SliderCfg.Callback or function() end
                
                local origDefault = SliderCfg.Default
                local configKey = "Slider_" .. SliderCfg.Title
                if ConfigData[configKey] ~= nil then SliderCfg.Default = ConfigData[configKey] end
                
                local SliderFunc = { Value = SliderCfg.Default, Default = origDefault }
                
                local Slider = Instance.new("Frame", SectionAdd)
                Slider.Size, Slider.LayoutOrder = UDim2.new(1, 0, 0, 46), CountItem
                Slider.BackgroundColor3, Slider.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.935
                Instance.new("UICorner", Slider).CornerRadius = UDim.new(0, 4)
                
                local STitle = Instance.new("TextLabel", Slider)
                STitle.Font, STitle.Text = Enum.Font.GothamBold, SliderCfg.Title
                STitle.TextColor3, STitle.TextSize, STitle.TextXAlignment = Color3.fromRGB(230, 230, 230), 13, Enum.TextXAlignment.Left
                STitle.BackgroundTransparency, STitle.Position, STitle.Size = 1, UDim2.new(0, 10, 0, 10), UDim2.new(0.5, 0, 0, 13)
                
                local ValueBox = Instance.new("TextBox", Slider)
                ValueBox.Font, ValueBox.TextSize = Enum.Font.GothamBold, 12
                ValueBox.TextColor3, ValueBox.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 1
                ValueBox.Position, ValueBox.Size = UDim2.new(1, -155, 0, 10), UDim2.new(0, 30, 0, 20)
                ValueBox.ClearTextOnFocus = false
                
                local SliderFrame = Instance.new("Frame", Slider)
                SliderFrame.AnchorPoint, SliderFrame.Position = Vector2.new(1, 0.5), UDim2.new(1, -20, 0.5, 0)
                SliderFrame.Size = UDim2.new(0, 100, 0, 3)
                SliderFrame.BackgroundColor3, SliderFrame.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.8
                
                local Fill = Instance.new("Frame", SliderFrame)
                Fill.AnchorPoint, Fill.Position = Vector2.new(0, 0.5), UDim2.new(0, 0, 0.5, 0)
                Fill.Size, Fill.BackgroundColor3 = UDim2.new(0.5, 0, 0, 3), cfg.Color
                
                local FillCircle = Instance.new("Frame", Fill)
                FillCircle.AnchorPoint, FillCircle.Position = Vector2.new(1, 0.5), UDim2.new(1, 4, 0.5, 0)
                FillCircle.Size, FillCircle.BackgroundColor3 = UDim2.new(0, 8, 0, 8), cfg.Color
                Instance.new("UICorner", FillCircle).CornerRadius = UDim.new(1, 0)
                
                local dragging = false
                local function Round(n, f) return math.floor(n / f + 0.5) * f end
                
                function SliderFunc:Set(val)
                    val = math.clamp(Round(val, SliderCfg.Increment), SliderCfg.Min, SliderCfg.Max)
                    SliderFunc.Value = val
                    ValueBox.Text = tostring(val)
                    Fill.Size = UDim2.fromScale((val - SliderCfg.Min) / (SliderCfg.Max - SliderCfg.Min), 1)
                    SliderCfg.Callback(val)
                    ConfigData[configKey] = val
                    SaveConfig()
                end
                
                SliderFrame.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        local scale = math.clamp((input.Position.X - SliderFrame.AbsolutePosition.X) / SliderFrame.AbsoluteSize.X, 0, 1)
                        SliderFunc:Set(SliderCfg.Min + (SliderCfg.Max - SliderCfg.Min) * scale)
                    end
                end)
                SliderFrame.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)
                UIS.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local scale = math.clamp((input.Position.X - SliderFrame.AbsolutePosition.X) / SliderFrame.AbsoluteSize.X, 0, 1)
                        SliderFunc:Set(SliderCfg.Min + (SliderCfg.Max - SliderCfg.Min) * scale)
                    end
                end)
                ValueBox:GetPropertyChangedSignal("Text"):Connect(function()
                    local n = tonumber(ValueBox.Text:gsub("[^%d]", ""))
                    if n then SliderFunc:Set(n) end
                end)
                
                SliderFunc:Set(SliderCfg.Default)
                CountItem = CountItem + 1
                Elements[configKey] = SliderFunc
                return SliderFunc
            end
            
            function Items:AddInput(InputCfg)
                InputCfg = InputCfg or {}
                InputCfg.Title = InputCfg.Title or "Input"
                InputCfg.Default = InputCfg.Default or ""
                InputCfg.Callback = InputCfg.Callback or function() end
                
                local configKey = "Input_" .. InputCfg.Title
                if ConfigData[configKey] ~= nil then InputCfg.Default = ConfigData[configKey] end
                
                local InputFunc = { Value = InputCfg.Default }
                
                local Input = Instance.new("Frame", SectionAdd)
                Input.Size, Input.LayoutOrder = UDim2.new(1, 0, 0, 46), CountItem
                Input.BackgroundColor3, Input.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.935
                Instance.new("UICorner", Input).CornerRadius = UDim.new(0, 4)
                
                local ITitle = Instance.new("TextLabel", Input)
                ITitle.Font, ITitle.Text = Enum.Font.GothamBold, InputCfg.Title
                ITitle.TextColor3, ITitle.TextSize, ITitle.TextXAlignment = Color3.fromRGB(230, 230, 230), 13, Enum.TextXAlignment.Left
                ITitle.BackgroundTransparency, ITitle.Position, ITitle.Size = 1, UDim2.new(0, 10, 0, 15), UDim2.new(0.5, 0, 0, 13)
                
                local InputFrame = Instance.new("Frame", Input)
                InputFrame.AnchorPoint, InputFrame.Position = Vector2.new(1, 0.5), UDim2.new(1, -7, 0.5, 0)
                InputFrame.Size = UDim2.new(0, 148, 0, 30)
                InputFrame.BackgroundColor3, InputFrame.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.95
                Instance.new("UICorner", InputFrame).CornerRadius = UDim.new(0, 4)
                
                local InputBox = Instance.new("TextBox", InputFrame)
                InputBox.Font, InputBox.TextSize = Enum.Font.GothamBold, 12
                InputBox.TextColor3, InputBox.PlaceholderText = Color3.fromRGB(255, 255, 255), "Input Here"
                InputBox.Text, InputBox.BackgroundTransparency = InputCfg.Default, 1
                InputBox.Position, InputBox.Size = UDim2.new(0, 5, 0, 0), UDim2.new(1, -10, 1, 0)
                InputBox.TextXAlignment, InputBox.ClearTextOnFocus = Enum.TextXAlignment.Left, false
                
                function InputFunc:Set(val)
                    InputBox.Text = val
                    InputFunc.Value = val
                    InputCfg.Callback(val)
                    ConfigData[configKey] = val
                    SaveConfig()
                end
                
                InputBox.FocusLost:Connect(function() InputFunc:Set(InputBox.Text) end)
                CountItem = CountItem + 1
                Elements[configKey] = InputFunc
                return InputFunc
            end
            
            function Items:AddDropdown(DropCfg)
                DropCfg = DropCfg or {}
                DropCfg.Title = DropCfg.Title or "Dropdown"
                DropCfg.Options = DropCfg.Options or {}
                DropCfg.Default = DropCfg.Default or nil
                DropCfg.Callback = DropCfg.Callback or function() end
                
                local configKey = "Dropdown_" .. DropCfg.Title
                if ConfigData[configKey] ~= nil then DropCfg.Default = ConfigData[configKey] end
                
                local DropFunc = { Value = DropCfg.Default, Options = DropCfg.Options }
                
                local Drop = Instance.new("Frame", SectionAdd)
                Drop.Size, Drop.LayoutOrder = UDim2.new(1, 0, 0, 46), CountItem
                Drop.BackgroundColor3, Drop.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.935
                Instance.new("UICorner", Drop).CornerRadius = UDim.new(0, 4)
                
                local DTitle = Instance.new("TextLabel", Drop)
                DTitle.Font, DTitle.Text = Enum.Font.GothamBold, DropCfg.Title
                DTitle.TextColor3, DTitle.TextSize, DTitle.TextXAlignment = Color3.fromRGB(230, 230, 230), 13, Enum.TextXAlignment.Left
                DTitle.BackgroundTransparency, DTitle.Position, DTitle.Size = 1, UDim2.new(0, 10, 0, 15), UDim2.new(0.5, 0, 0, 13)
                
                local SelectFrame = Instance.new("Frame", Drop)
                SelectFrame.AnchorPoint, SelectFrame.Position = Vector2.new(1, 0.5), UDim2.new(1, -7, 0.5, 0)
                SelectFrame.Size, SelectFrame.LayoutOrder = UDim2.new(0, 148, 0, 30), CountDropdown
                SelectFrame.BackgroundColor3, SelectFrame.BackgroundTransparency = Color3.fromRGB(255, 255, 255), 0.95
                Instance.new("UICorner", SelectFrame).CornerRadius = UDim.new(0, 4)
                
                local SelectLabel = Instance.new("TextLabel", SelectFrame)
                SelectLabel.Font, SelectLabel.Text = Enum.Font.GothamBold, "Select Option"
                SelectLabel.TextColor3, SelectLabel.TextSize, SelectLabel.TextTransparency = Color3.fromRGB(255, 255, 255), 12, 0.6
                SelectLabel.BackgroundTransparency, SelectLabel.Position, SelectLabel.Size = 1, UDim2.new(0, 5, 0, 0), UDim2.new(1, -30, 1, 0)
                SelectLabel.TextXAlignment = Enum.TextXAlignment.Left
                
                local Arrow = Instance.new("ImageLabel", SelectFrame)
                Arrow.Image, Arrow.AnchorPoint = "rbxassetid://16851841101", Vector2.new(1, 0.5)
                Arrow.Position, Arrow.Size, Arrow.BackgroundTransparency = UDim2.new(1, 0, 0.5, 0), UDim2.new(0, 25, 0, 25), 1
                
                local DropBtn = Instance.new("TextButton", Drop)
                DropBtn.Size, DropBtn.BackgroundTransparency, DropBtn.Text = UDim2.new(1, 0, 1, 0), 1, ""
                
                local Container = Instance.new("Frame", DropFolder)
                Container.Size, Container.BackgroundTransparency = UDim2.new(1, 0, 1, 0), 1
                
                local ScrollSelect = Instance.new("ScrollingFrame", Container)
                ScrollSelect.Size, ScrollSelect.BackgroundTransparency = UDim2.new(1, 0, 1, 0), 1
                ScrollSelect.ScrollBarThickness = 0
                local OptLayout = Instance.new("UIListLayout", ScrollSelect)
                OptLayout.Padding, OptLayout.SortOrder = UDim.new(0, 3), Enum.SortOrder.LayoutOrder
                OptLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, OptLayout.AbsoluteContentSize.Y)
                end)
                
                DropBtn.Activated:Connect(function()
                    if not DropOverlay.Visible then
                        DropOverlay.Visible = true
                        DropPageLayout:JumpToIndex(SelectFrame.LayoutOrder)
                    end
                end)
                
                function DropFunc:Clear()
                    for _, c in ScrollSelect:GetChildren() do
                        if c.Name == "Option" then c:Destroy() end
                    end
                    DropFunc.Value = nil
                    DropFunc.Options = {}
                    SelectLabel.Text = "Select Option"
                end
                
                function DropFunc:AddOption(opt)
                    local label, value = tostring(opt), opt
                    if typeof(opt) == "table" and opt.Label then
                        label, value = tostring(opt.Label), opt.Value
                    end
                    
                    local Opt = Instance.new("Frame", ScrollSelect)
                    Opt.Name, Opt.Size, Opt.BackgroundTransparency = "Option", UDim2.new(1, 0, 0, 30), 0.999
                    
                    local OptBtn = Instance.new("TextButton", Opt)
                    OptBtn.Size, OptBtn.BackgroundTransparency, OptBtn.Text = UDim2.new(1, 0, 1, 0), 1, ""
                    
                    local OptText = Instance.new("TextLabel", Opt)
                    OptText.Name, OptText.Font, OptText.Text = "OptionText", Enum.Font.GothamBold, label
                    OptText.TextColor3, OptText.TextSize, OptText.TextXAlignment = Color3.fromRGB(230, 230, 230), 13, Enum.TextXAlignment.Left
                    OptText.BackgroundTransparency, OptText.Position, OptText.Size = 1, UDim2.new(0, 8, 0, 8), UDim2.new(1, -16, 0, 13)
                    
                    Opt:SetAttribute("RealValue", value)
                    
                    OptBtn.Activated:Connect(function()
                        DropFunc.Value = value
                        DropFunc:Set(value)
                        DropOverlay.Visible = false
                    end)
                end
                
                function DropFunc:Set(val)
                    DropFunc.Value = val
                    ConfigData[configKey] = val
                    SaveConfig()
                    
                    local txt = ""
                    for _, c in ScrollSelect:GetChildren() do
                        if c.Name == "Option" and c:GetAttribute("RealValue") == val then
                            txt = c.OptionText.Text
                            c.BackgroundTransparency = 0.935
                        else
                            if c.Name == "Option" then c.BackgroundTransparency = 0.999 end
                        end
                    end
                    SelectLabel.Text = txt ~= "" and txt or "Select Option"
                    DropCfg.Callback(val ~= nil and tostring(val) or "")
                end
                
                function DropFunc:SetValues(list, sel)
                    DropFunc:Clear()
                    for _, v in ipairs(list or {}) do DropFunc:AddOption(v) end
                    DropFunc.Options = list
                    DropFunc:Set(sel)
                end
                
                DropFunc:SetValues(DropFunc.Options, DropFunc.Value)
                CountItem = CountItem + 1
                CountDropdown = CountDropdown + 1
                Elements[configKey] = DropFunc
                return DropFunc
            end
            
            function Items:AddDivider()
                local Div = Instance.new("Frame", SectionAdd)
                Div.Size, Div.LayoutOrder = UDim2.new(1, 0, 0, 2), CountItem
                Div.BackgroundColor3, Div.BackgroundTransparency = cfg.Color, 0.5
                CountItem = CountItem + 1
                return Div
            end
            
            return Items
        end
        
        CountTab = CountTab + 1
        return Sections
    end
    
    return Tabs
end

return Lynx
