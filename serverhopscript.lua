-- ============================================================
--  SERVER HOP — Steal An Egg  |  by Mochii Scripts
--  Real functions only:
--    • Server list  → Roblox public API (id, players, fps, ping)
--    • Egg tiers    → EggCmds.GetAreaEggSnapshot() — THIS server only
--    • Hop Random   → TeleportToPlaceInstance (random server)
--    • Hop New      → picks the server with the LEAST players
--    • Rejoin       → TeleportToPlaceInstance(PlaceId, game.JobId)
-- ============================================================

local Players        = game:GetService("Players")
local TeleportService= game:GetService("TeleportService")
local HttpService    = game:GetService("HttpService")
local UIS            = game:GetService("UserInputService")
local RS             = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlaceId     = game.PlaceId
local CurrentJobId= tostring(game.JobId)

-- ============================================================
-- RARITY DATA  (from poccwo.lua open source / community data)
-- ============================================================
local RARITY_ORDER = {
    Divine=10, Eternal=9, Secret=8, Cosmic=7,
    Mythic=6, Legendary=5, Epic=4, Rare=3,
    Uncommon=2, Common=1
}
local RARITY_COLOR = {
    Divine    = Color3.fromRGB(255, 80,  255),
    Eternal   = Color3.fromRGB(255, 200, 60),
    Secret    = Color3.fromRGB(180, 0,   255),
    Cosmic    = Color3.fromRGB(60,  200, 255),
    Mythic    = Color3.fromRGB(255, 70,  70),
    Legendary = Color3.fromRGB(255, 160, 0),
    Epic      = Color3.fromRGB(150, 70,  255),
    Rare      = Color3.fromRGB(70,  110, 255),
    Uncommon  = Color3.fromRGB(90,  210, 90),
    Common    = Color3.fromRGB(170, 170, 170),
}

-- ============================================================
-- GAME MODULE LOADER  (only works while inside the game)
-- ============================================================
local EggCmds, SaveMod, AssetsDir
pcall(function()
    EggCmds   = require(RS.Library.Client.EggCmds)
    SaveMod   = require(RS.Library.Client.Save)
    AssetsDir = require(RS.Directory.Assets)
end)

local function getRarityName(category)
    if not AssetsDir then return nil end
    local cfg = AssetsDir.Directory and AssetsDir.Directory[category]
    if type(cfg) ~= "table" or type(cfg.Rarity) ~= "table" then return nil end
    return tostring(cfg.Rarity._id or "?")
end

local function getMutTag(rec)
    local s = (tostring(rec.BaseMutation or "")):lower()
    if type(rec.Mutations) == "table" then
        for _, m in pairs(rec.Mutations) do s = s..","..tostring(m):lower() end
    end
    if s:find("rainbow") then return "🌈" end
    if s:find("gold")    then return "🌕" end
    if s:find("silver")  then return "🩶" end
    if s ~= ""           then return "✨" end
    return ""
end

-- ============================================================
-- GUI BOOTSTRAP
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SHBubbleGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = game.CoreGui
elseif gethui then
    ScreenGui.Parent = gethui()
else
    ScreenGui.Parent = game.CoreGui
end

-- ============================================================
-- COLOUR PALETTE
-- ============================================================
local C_BG        = Color3.fromRGB(8,  10, 28)      -- deepest bg
local C_PANEL     = Color3.fromRGB(12, 14, 38)      -- panel bg
local C_CARD      = Color3.fromRGB(16, 18, 46)      -- card bg
local C_HDR       = Color3.fromRGB(18, 20, 52)      -- header bar
local C_BORDER    = Color3.fromRGB(80, 50, 180)     -- purple border
local C_BORDER2   = Color3.fromRGB(120, 80, 220)    -- lighter purple
local C_ACCENT    = Color3.fromRGB(140, 80, 255)    -- main purple accent
local C_CYAN      = Color3.fromRGB(0,  200, 255)    -- cyan accent
local C_GREEN     = Color3.fromRGB(0,  230, 120)    -- green / active
local C_ORANGE    = Color3.fromRGB(255, 160, 30)    -- orange warn
local C_RED       = Color3.fromRGB(220, 50,  60)    -- red
local C_WHITE     = Color3.fromRGB(220, 225, 255)   -- label white
local C_DIM       = Color3.fromRGB(100, 105, 150)   -- dimmed text
local C_ROW_ALT   = Color3.fromRGB(20,  22, 55)    -- alternating row

-- ============================================================
-- HELPER: add UIStroke
-- ============================================================
local function AddStroke(parent, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Parent = parent
    s.Color  = color or C_BORDER
    s.Thickness = thick or 1
    s.Transparency = trans or 0
    return s
end

-- ============================================================
-- DRAGGABLE BUBBLE ORB
-- ============================================================
local Bubble = Instance.new("TextButton")
Bubble.Name     = "Bubble"
Bubble.Parent   = ScreenGui
Bubble.Size     = UDim2.new(0, 52, 0, 52)
Bubble.Position = UDim2.new(1, -66, 1, -76)
Bubble.AnchorPoint = Vector2.new(0, 0)
Bubble.BackgroundColor3 = Color3.fromRGB(30, 15, 80)
Bubble.BorderSizePixel  = 0
Bubble.Text     = "🥚"
Bubble.TextSize = 24
Bubble.Font     = Enum.Font.GothamBold
Bubble.TextColor3 = Color3.fromRGB(255, 255, 255)
Bubble.ZIndex   = 20
Bubble.Active   = true
Instance.new("UICorner", Bubble).CornerRadius = UDim.new(1, 0)
AddStroke(Bubble, C_BORDER2, 2, 0)

-- Glow gradient ring (visual only)
local BubbleGrad = Instance.new("UIGradient")
BubbleGrad.Parent = Bubble
BubbleGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 60, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 100, 255)),
}
BubbleGrad.Rotation = 45

-- Notif dot
local NotifDot = Instance.new("Frame")
NotifDot.Parent = Bubble
NotifDot.Size   = UDim2.new(0, 12, 0, 12)
NotifDot.Position = UDim2.new(1, -12, 0, 0)
NotifDot.BackgroundColor3 = C_RED
NotifDot.BorderSizePixel  = 0
NotifDot.ZIndex  = 21
NotifDot.Visible = false
Instance.new("UICorner", NotifDot).CornerRadius = UDim.new(1, 0)

-- Forward-declare Panel so bubble drag can reference it
local Panel

-- Bubble drag (tap = toggle, drag = move)
do
    local drag, dragInput, dragStart, startPos, wasDrag = false, nil, nil, nil, false
    Bubble.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag=true; wasDrag=false
            dragStart=i.Position; startPos=Bubble.Position; dragInput=i
        end
    end)
    Bubble.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then dragInput=i end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag or i ~= dragInput then return end
        local d = i.Position - dragStart
        if d.Magnitude > 5 then wasDrag = true end
        local vp = workspace.CurrentCamera.ViewportSize
        Bubble.Position = UDim2.new(0,
            math.clamp(startPos.X.Offset + d.X, 0, vp.X - 52), 0,
            math.clamp(startPos.Y.Offset + d.Y, 0, vp.Y - 52))
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1
        and i.UserInputType ~= Enum.UserInputType.Touch then return end
        drag = false
        if not wasDrag and Panel then
            Panel.Visible = not Panel.Visible
            if Panel.Visible then
                NotifDot.Visible = false
                local vp = workspace.CurrentCamera.ViewportSize
                local bx = Bubble.Position.X.Offset
                local by = Bubble.Position.Y.Offset
                local pw, ph = 310, 520
                Panel.Position = UDim2.new(0,
                    math.clamp(bx - pw - 8, 4, vp.X - pw - 4), 0,
                    math.clamp(by - ph + 52, 4, vp.Y - ph - 4))
            end
        end
        wasDrag = false
    end)
end

-- ============================================================
-- MAIN PANEL
-- ============================================================
Panel = Instance.new("Frame")
Panel.Name    = "Panel"
Panel.Parent  = ScreenGui
Panel.Size    = UDim2.new(0, 310, 0, 520)
Panel.Position= UDim2.new(0.5, -155, 0.5, -260)
Panel.BackgroundColor3 = C_PANEL
Panel.BorderSizePixel  = 0
Panel.ZIndex  = 15
Panel.Visible = false
Panel.ClipsDescendants = true
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 14)
AddStroke(Panel, C_BORDER, 1.5, 0)

-- Subtle top gradient overlay
local PanelGrad = Instance.new("Frame")
PanelGrad.Parent = Panel
PanelGrad.Size   = UDim2.new(1, 0, 0, 3)
PanelGrad.Position = UDim2.new(0, 0, 0, 0)
PanelGrad.BackgroundColor3 = C_BORDER2
PanelGrad.BorderSizePixel  = 0
PanelGrad.ZIndex = 16

-- ============================================================
-- HEADER BAR
-- ============================================================
local Hdr = Instance.new("Frame")
Hdr.Parent = Panel
Hdr.Size   = UDim2.new(1, 0, 0, 48)
Hdr.Position = UDim2.new(0, 0, 0, 3)
Hdr.BackgroundColor3 = C_HDR
Hdr.BorderSizePixel  = 0
Hdr.ZIndex = 16

-- bottom border line on header
local HdrLine = Instance.new("Frame")
HdrLine.Parent = Hdr
HdrLine.Size   = UDim2.new(1, 0, 0, 1)
HdrLine.Position = UDim2.new(0, 0, 1, -1)
HdrLine.BackgroundColor3 = C_BORDER
HdrLine.BorderSizePixel  = 0
HdrLine.ZIndex = 17

-- Egg icon badge left
local HdrIcon = Instance.new("TextLabel")
HdrIcon.Parent = Hdr
HdrIcon.Size   = UDim2.new(0, 36, 0, 36)
HdrIcon.Position = UDim2.new(0, 8, 0.5, -18)
HdrIcon.BackgroundColor3 = Color3.fromRGB(40, 20, 100)
HdrIcon.BorderSizePixel  = 0
HdrIcon.Text   = "🥚"
HdrIcon.TextSize = 18
HdrIcon.Font   = Enum.Font.GothamBold
HdrIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
HdrIcon.ZIndex = 18
Instance.new("UICorner", HdrIcon).CornerRadius = UDim.new(0, 8)
AddStroke(HdrIcon, C_BORDER2, 1, 0)

-- Title
local HdrTitle = Instance.new("TextLabel")
HdrTitle.Parent = Hdr
HdrTitle.Size   = UDim2.new(0, 150, 0, 20)
HdrTitle.Position = UDim2.new(0, 52, 0, 6)
HdrTitle.BackgroundTransparency = 1
HdrTitle.Font   = Enum.Font.GothamBold
HdrTitle.Text   = "STEAL AN EGG"
HdrTitle.TextColor3 = C_WHITE
HdrTitle.TextSize   = 13
HdrTitle.TextXAlignment = Enum.TextXAlignment.Left
HdrTitle.ZIndex = 17

-- Subtitle
local HdrSub = Instance.new("TextLabel")
HdrSub.Parent = Hdr
HdrSub.Size   = UDim2.new(0, 200, 0, 14)
HdrSub.Position = UDim2.new(0, 52, 0, 26)
HdrSub.BackgroundTransparency = 1
HdrSub.Font   = Enum.Font.Gotham
HdrSub.Text   = "SERVER HOP  •  by Mochii Scripts"
HdrSub.TextColor3 = C_DIM
HdrSub.TextSize   = 8
HdrSub.TextXAlignment = Enum.TextXAlignment.Left
HdrSub.ZIndex = 17

-- Top-right corner labels
local HdrTag1 = Instance.new("TextLabel")
HdrTag1.Parent = Hdr
HdrTag1.Size   = UDim2.new(0, 80, 0, 10)
HdrTag1.Position = UDim2.new(1, -88, 0, 8)
HdrTag1.BackgroundTransparency = 1
HdrTag1.Font   = Enum.Font.GothamBold
HdrTag1.Text   = "BETTER EGGS"
HdrTag1.TextColor3 = C_DIM
HdrTag1.TextSize   = 7
HdrTag1.TextXAlignment = Enum.TextXAlignment.Right
HdrTag1.ZIndex = 17

local HdrTag2 = Instance.new("TextLabel")
HdrTag2.Parent = Hdr
HdrTag2.Size   = UDim2.new(0, 80, 0, 10)
HdrTag2.Position = UDim2.new(1, -88, 0, 20)
HdrTag2.BackgroundTransparency = 1
HdrTag2.Font   = Enum.Font.GothamBold
HdrTag2.Text   = "BIGGER WINS"
HdrTag2.TextColor3 = C_DIM
HdrTag2.TextSize   = 7
HdrTag2.TextXAlignment = Enum.TextXAlignment.Right
HdrTag2.ZIndex = 17

-- Minimize / Close buttons
local MinBtn = Instance.new("TextButton")
MinBtn.Parent = Hdr
MinBtn.Size   = UDim2.new(0, 22, 0, 22)
MinBtn.Position = UDim2.new(1, -52, 0.5, -11)
MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 65)
MinBtn.BorderSizePixel  = 0
MinBtn.Text   = "—"; MinBtn.TextSize = 10
MinBtn.Font   = Enum.Font.GothamBold
MinBtn.TextColor3 = C_WHITE
MinBtn.ZIndex = 18
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)
AddStroke(MinBtn, C_BORDER, 1, 0.2)
MinBtn.MouseButton1Click:Connect(function() Panel.Visible = false end)

local XBtn = Instance.new("TextButton")
XBtn.Parent = Hdr
XBtn.Size   = UDim2.new(0, 22, 0, 22)
XBtn.Position = UDim2.new(1, -26, 0.5, -11)
XBtn.BackgroundColor3 = Color3.fromRGB(160, 30, 50)
XBtn.BorderSizePixel  = 0
XBtn.Text   = "✕"; XBtn.TextSize = 9
XBtn.Font   = Enum.Font.GothamBold
XBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
XBtn.ZIndex = 18
Instance.new("UICorner", XBtn).CornerRadius = UDim.new(0, 5)
XBtn.MouseButton1Click:Connect(function() Panel.Visible = false end)

-- Panel drag by header
do
    local drag, dragInput, dragStart, startPos = false, nil, nil, nil
    Hdr.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag=true; dragStart=i.Position; startPos=Panel.Position; dragInput=i
        end
    end)
    Hdr.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then dragInput=i end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag or i ~= dragInput then return end
        local d = i.Position - dragStart
        local vp = workspace.CurrentCamera.ViewportSize
        Panel.Position = UDim2.new(0,
            math.clamp(startPos.X.Offset + d.X, 0, vp.X - 310), 0,
            math.clamp(startPos.Y.Offset + d.Y, 0, vp.Y - 520))
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then drag = false end
    end)
end

-- ============================================================
-- SCROLL AREA  (below header)
-- ============================================================
local Scroll = Instance.new("ScrollingFrame")
Scroll.Parent   = Panel
Scroll.Position = UDim2.new(0, 0, 0, 51)   -- header 48 + 3 top bar
Scroll.Size     = UDim2.new(1, 0, 1, -51)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness    = 3
Scroll.ScrollBarImageColor3  = C_BORDER
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ZIndex = 16

local SLayout = Instance.new("UIListLayout")
SLayout.Parent = Scroll
SLayout.Padding = UDim.new(0, 6)
SLayout.SortOrder = Enum.SortOrder.LayoutOrder
SLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local SPad = Instance.new("UIPadding")
SPad.Parent = Scroll
SPad.PaddingTop    = UDim.new(0, 8)
SPad.PaddingLeft   = UDim.new(0, 8)
SPad.PaddingRight  = UDim.new(0, 8)
SPad.PaddingBottom = UDim.new(0, 10)

-- ============================================================
-- UI HELPERS
-- ============================================================

-- Section card with styled title bar
local function MakeSection(titleText, accentColor)
    accentColor = accentColor or C_ACCENT
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = C_CARD
    card.BorderSizePixel = 0
    card.ZIndex = 17
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    AddStroke(card, Color3.fromRGB(
        math.clamp(accentColor.R*255*0.4, 0, 255),
        math.clamp(accentColor.G*255*0.4, 0, 255),
        math.clamp(accentColor.B*255*0.4, 0, 255)
    ), 1, 0)

    -- Title bar inside card
    local tbar = Instance.new("Frame")
    tbar.Parent = card
    tbar.Size   = UDim2.new(1, 0, 0, 24)
    tbar.BackgroundColor3 = Color3.fromRGB(
        math.clamp(math.floor(accentColor.R*255*0.12), 0, 255),
        math.clamp(math.floor(accentColor.G*255*0.12), 0, 255),
        math.clamp(math.floor(accentColor.B*255*0.12), 0, 255)
    )
    tbar.BorderSizePixel = 0
    tbar.ZIndex = 18
    Instance.new("UICorner", tbar).CornerRadius = UDim.new(0, 10)
    -- square bottom corners fix
    local tbarFix = Instance.new("Frame")
    tbarFix.Parent = tbar
    tbarFix.Size   = UDim2.new(1, 0, 0.5, 0)
    tbarFix.Position = UDim2.new(0, 0, 0.5, 0)
    tbarFix.BackgroundColor3 = tbar.BackgroundColor3
    tbarFix.BorderSizePixel = 0; tbarFix.ZIndex = 18

    -- left accent pip
    local pip = Instance.new("Frame")
    pip.Parent = tbar
    pip.Size   = UDim2.new(0, 3, 0, 14)
    pip.Position = UDim2.new(0, 8, 0.5, -7)
    pip.BackgroundColor3 = accentColor
    pip.BorderSizePixel = 0; pip.ZIndex = 19
    Instance.new("UICorner", pip).CornerRadius = UDim.new(1, 0)

    local ttl = Instance.new("TextLabel")
    ttl.Parent = tbar
    ttl.Size   = UDim2.new(1, -20, 1, 0)
    ttl.Position = UDim2.new(0, 16, 0, 0)
    ttl.BackgroundTransparency = 1
    ttl.Font   = Enum.Font.GothamBold
    ttl.Text   = titleText
    ttl.TextColor3 = accentColor
    ttl.TextSize   = 9
    ttl.TextXAlignment = Enum.TextXAlignment.Left
    ttl.ZIndex = 19

    -- body container
    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Parent = card
    body.Size   = UDim2.new(1, -16, 0, 0)
    body.Position = UDim2.new(0, 8, 0, 26)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.ZIndex = 18
    local bl = Instance.new("UIListLayout")
    bl.Parent = body
    bl.Padding = UDim.new(0, 4)
    bl.SortOrder = Enum.SortOrder.LayoutOrder
    local bp = Instance.new("UIPadding")
    bp.Parent = body
    bp.PaddingBottom = UDim.new(0, 8)

    return card, body
end

-- Info row: small label
local function InfoRow(parent, text, color, order, height)
    local l = Instance.new("TextLabel")
    l.Parent = parent
    l.Size   = UDim2.new(1, 0, 0, height or 14)
    l.BackgroundTransparency = 1
    l.Font   = Enum.Font.Gotham
    l.Text   = text
    l.TextColor3 = color or C_DIM
    l.TextSize   = 9
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.ZIndex = 18
    l.LayoutOrder = order or 0
    return l
end

-- Data row: styled with background pill
local function DataRow(parent, leftText, rightText, leftColor, rightColor, order, bgColor)
    local row = Instance.new("Frame")
    row.Parent = parent
    row.Size   = UDim2.new(1, 0, 0, 22)
    row.BackgroundColor3 = bgColor or C_ROW_ALT
    row.BorderSizePixel  = 0
    row.ZIndex = 18
    row.LayoutOrder = order or 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Parent = row
    lbl.Size   = UDim2.new(0.6, 0, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font   = Enum.Font.Gotham
    lbl.Text   = leftText or ""
    lbl.TextColor3 = leftColor or C_WHITE
    lbl.TextSize   = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 19

    local rbl = Instance.new("TextLabel")
    rbl.Parent = row
    rbl.Size   = UDim2.new(0.4, -8, 1, 0)
    rbl.Position = UDim2.new(0.6, 0, 0, 0)
    rbl.BackgroundTransparency = 1
    rbl.Font   = Enum.Font.GothamBold
    rbl.Text   = rightText or ""
    rbl.TextColor3 = rightColor or C_CYAN
    rbl.TextSize   = 9
    rbl.TextXAlignment = Enum.TextXAlignment.Right
    rbl.ZIndex = 19
    local rp = Instance.new("UIPadding"); rp.Parent = rbl; rp.PaddingRight = UDim.new(0, 6)

    return row, lbl, rbl
end

-- Stat tile (icon + value + label stacked)
local function StatTile(parent, icon, value, label, accentCol)
    local f = Instance.new("Frame")
    f.Parent = parent
    f.BackgroundColor3 = Color3.fromRGB(18, 20, 55)
    f.BorderSizePixel  = 0
    f.ZIndex = 19
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    AddStroke(f, accentCol or C_BORDER, 1, 0.3)

    local ic = Instance.new("TextLabel")
    ic.Parent = f
    ic.Size   = UDim2.new(1, 0, 0, 18)
    ic.Position = UDim2.new(0, 0, 0, 4)
    ic.BackgroundTransparency = 1
    ic.Text   = icon; ic.TextSize = 14
    ic.Font   = Enum.Font.GothamBold
    ic.TextColor3 = accentCol or C_WHITE
    ic.ZIndex = 20

    local vl = Instance.new("TextLabel")
    vl.Parent = f
    vl.Size   = UDim2.new(1, 0, 0, 16)
    vl.Position = UDim2.new(0, 0, 0, 22)
    vl.BackgroundTransparency = 1
    vl.Font   = Enum.Font.GothamBold
    vl.Text   = value; vl.TextSize = 11
    vl.TextColor3 = C_WHITE
    vl.ZIndex = 20

    local ll = Instance.new("TextLabel")
    ll.Parent = f
    ll.Size   = UDim2.new(1, 0, 0, 12)
    ll.Position = UDim2.new(0, 0, 0, 38)
    ll.BackgroundTransparency = 1
    ll.Font   = Enum.Font.Gotham
    ll.Text   = label; ll.TextSize = 7
    ll.TextColor3 = C_DIM
    ll.ZIndex = 20

    return f, vl  -- return frame + value label so caller can update
end

-- Full-width styled button
local function StyledBtn(parent, text, bgColor, order, height)
    local b = Instance.new("TextButton")
    b.Parent = parent
    b.Size   = UDim2.new(1, 0, 0, height or 28)
    b.BackgroundColor3 = bgColor or C_ACCENT
    b.BorderSizePixel  = 0
    b.Font   = Enum.Font.GothamBold
    b.Text   = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize   = 10
    b.ZIndex = 19
    b.LayoutOrder = order or 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

-- Half-width button (for pairing two side by side)
local function HalfBtnRow(parent, order)
    local f = Instance.new("Frame")
    f.Parent = parent
    f.Size   = UDim2.new(1, 0, 0, 28)
    f.BackgroundTransparency = 1
    f.ZIndex = 18
    f.LayoutOrder = order or 0
    local l = Instance.new("UIListLayout")
    l.Parent = f
    l.FillDirection = Enum.FillDirection.Horizontal
    l.Padding = UDim.new(0, 5)
    return f
end

local function HalfBtn(parent, text, bgColor)
    local b = Instance.new("TextButton")
    b.Parent = parent
    b.Size   = UDim2.new(0.5, -3, 1, 0)
    b.BackgroundColor3 = bgColor or C_ACCENT
    b.BorderSizePixel  = 0
    b.Font   = Enum.Font.GothamBold
    b.Text   = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize   = 10
    b.ZIndex = 19
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

-- Divider line
local function Divider(parent, order)
    local f = Instance.new("Frame")
    f.Parent = parent
    f.Size   = UDim2.new(1, 0, 0, 1)
    f.BackgroundColor3 = Color3.fromRGB(35, 35, 70)
    f.BorderSizePixel  = 0
    f.ZIndex = 18
    f.LayoutOrder = order or 0
    return f
end

-- ============================================================
-- SECTION 1 — SERVER DETAIL  (left-aligned details)
-- ============================================================
local S1, B1 = MakeSection("⊞  SERVER DETAIL", C_CYAN)
S1.Parent = Scroll; S1.LayoutOrder = 1

-- Server ID row
local idRowFrame = Instance.new("Frame")
idRowFrame.Parent = B1
idRowFrame.Size   = UDim2.new(1, 0, 0, 18)
idRowFrame.BackgroundTransparency = 1
idRowFrame.ZIndex = 18; idRowFrame.LayoutOrder = 1
local idLblTitle = Instance.new("TextLabel")
idLblTitle.Parent = idRowFrame
idLblTitle.Size   = UDim2.new(1, 0, 0, 10)
idLblTitle.BackgroundTransparency = 1
idLblTitle.Font   = Enum.Font.Gotham
idLblTitle.Text   = "Server ID"
idLblTitle.TextColor3 = C_DIM
idLblTitle.TextSize   = 8
idLblTitle.TextXAlignment = Enum.TextXAlignment.Left
idLblTitle.ZIndex = 19

local idValue = Instance.new("TextLabel")
idValue.Parent = idRowFrame
idValue.Size   = UDim2.new(1, -20, 0, 11)
idValue.Position = UDim2.new(0, 0, 0, 9)
idValue.BackgroundTransparency = 1
idValue.Font   = Enum.Font.Code
idValue.Text   = tostring(game.JobId):sub(1, 22) .. "..."
idValue.TextColor3 = C_WHITE
idValue.TextSize   = 7
idValue.TextXAlignment = Enum.TextXAlignment.Left
idValue.ZIndex = 19

Divider(B1, 2)

-- Players stat row
local lblPlayers = Instance.new("TextLabel")
lblPlayers.Parent = B1
lblPlayers.Size   = UDim2.new(1, 0, 0, 18)
lblPlayers.BackgroundTransparency = 1
lblPlayers.Font   = Enum.Font.GothamBold
lblPlayers.Text   = "👥 Players: loading..."
lblPlayers.TextColor3 = C_CYAN
lblPlayers.TextSize   = 10
lblPlayers.TextXAlignment = Enum.TextXAlignment.Left
lblPlayers.ZIndex = 18; lblPlayers.LayoutOrder = 3

-- Ping / FPS
local lblPing = Instance.new("TextLabel")
lblPing.Parent = B1
lblPing.Size   = UDim2.new(1, 0, 0, 14)
lblPing.BackgroundTransparency = 1
lblPing.Font   = Enum.Font.Gotham
lblPing.Text   = "📶 Ping: —   FPS: —"
lblPing.TextColor3 = C_DIM
lblPing.TextSize   = 9
lblPing.TextXAlignment = Enum.TextXAlignment.Left
lblPing.ZIndex = 18; lblPing.LayoutOrder = 4

-- ============================================================
-- SECTION 2 — EGG INFORMATION  (tile grid + best egg)
-- ============================================================
local S2, B2egg = MakeSection("🥚  EGG INFORMATION", Color3.fromRGB(255, 190, 50))
S2.Parent = Scroll; S2.LayoutOrder = 2

-- 3-tile row for top rarities
local tileRow = Instance.new("Frame")
tileRow.Parent = B2egg
tileRow.Size   = UDim2.new(1, 0, 0, 58)
tileRow.BackgroundTransparency = 1
tileRow.ZIndex = 18; tileRow.LayoutOrder = 1
local tileLayout = Instance.new("UIListLayout")
tileLayout.Parent = tileRow
tileLayout.FillDirection = Enum.FillDirection.Horizontal
tileLayout.Padding = UDim.new(0, 4)
tileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- We create 3 fixed tiles that the live monitor will update
local tile1, tile1Val = StatTile(tileRow, "🥚", "—", "Common",    C_DIM)
local tile2, tile2Val = StatTile(tileRow, "❓", "—", "Secret",    Color3.fromRGB(160, 0, 255))
local tile3, tile3Val = StatTile(tileRow, "✨", "—", "Rare+",     Color3.fromRGB(255, 200, 50))
tile1.Size = UDim2.new(0.333, -3, 1, 0)
tile2.Size = UDim2.new(0.333, -3, 1, 0)
tile3.Size = UDim2.new(0.333, -3, 1, 0)

-- Best egg label
local lblBestEgg = Instance.new("TextLabel")
lblBestEgg.Parent = B2egg
lblBestEgg.Size   = UDim2.new(1, 0, 0, 16)
lblBestEgg.BackgroundTransparency = 1
lblBestEgg.Font   = Enum.Font.GothamBold
lblBestEgg.Text   = "🥚 Best egg: scanning..."
lblBestEgg.TextColor3 = Color3.fromRGB(255, 210, 80)
lblBestEgg.TextSize   = 10
lblBestEgg.TextXAlignment = Enum.TextXAlignment.Left
lblBestEgg.ZIndex = 18; lblBestEgg.LayoutOrder = 2

Divider(B2egg, 3)

-- Egg list header
InfoRow(B2egg, "SERVER EGG LIST", C_DIM, 4, 11)

-- Dynamic egg list rows container
local eggListFrame = Instance.new("Frame")
eggListFrame.Parent = B2egg
eggListFrame.Size   = UDim2.new(1, 0, 0, 0)
eggListFrame.AutomaticSize = Enum.AutomaticSize.Y
eggListFrame.BackgroundTransparency = 1
eggListFrame.ZIndex = 18; eggListFrame.LayoutOrder = 5
local eggListLayout = Instance.new("UIListLayout")
eggListLayout.Parent = eggListFrame
eggListLayout.Padding = UDim.new(0, 2)
eggListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Placeholder rows (updated by live monitor)
local lblEggList = Instance.new("TextLabel")
lblEggList.Parent = eggListFrame
lblEggList.Size   = UDim2.new(1, 0, 0, 12)
lblEggList.BackgroundTransparency = 1
lblEggList.Font   = Enum.Font.Gotham
lblEggList.Text   = "ℹ Run inside Steal An Egg"
lblEggList.TextColor3 = C_DIM
lblEggList.TextSize   = 8
lblEggList.TextXAlignment = Enum.TextXAlignment.Left
lblEggList.TextWrapped = true
lblEggList.ZIndex = 18; lblEggList.LayoutOrder = 1

-- ============================================================
-- SECTION 3 — GO TO SERVER  (threshold + hop buttons)
-- ============================================================
local S3, B3hop = MakeSection("➜  GO TO SERVER", C_ACCENT)
S3.Parent = Scroll; S3.LayoutOrder = 3

InfoRow(B3hop, "Players to Hop (threshold):", C_DIM, 1, 11)

local MaxBox = Instance.new("TextBox")
MaxBox.Parent = B3hop
MaxBox.Size   = UDim2.new(1, 0, 0, 26)
MaxBox.BackgroundColor3 = Color3.fromRGB(20, 20, 55)
MaxBox.BorderSizePixel  = 0
MaxBox.Font   = Enum.Font.GothamBold
MaxBox.Text   = "10"
MaxBox.TextColor3 = C_WHITE
MaxBox.TextSize   = 13
MaxBox.ClearTextOnFocus = false
MaxBox.ZIndex = 19; MaxBox.LayoutOrder = 2
Instance.new("UICorner", MaxBox).CornerRadius = UDim.new(0, 6)
AddStroke(MaxBox, C_BORDER, 1, 0.2)
local mbp = Instance.new("UIPadding"); mbp.Parent = MaxBox; mbp.PaddingLeft = UDim.new(0, 10)

-- HOP NOW full-width button
local JoinBtn = StyledBtn(B3hop, "⚡  HOP NOW",
    Color3.fromRGB(100, 40, 220), 3, 32)
-- gradient on hop button
local hopGrad = Instance.new("UIGradient")
hopGrad.Parent = JoinBtn
hopGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 50, 230)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 30, 180)),
}
hopGrad.Rotation = 90
AddStroke(JoinBtn, Color3.fromRGB(160, 80, 255), 1, 0)

-- ============================================================
-- SECTION 4 — AUTO TOGGLE
-- ============================================================
local S4, B4auto = MakeSection("⏻  AUTO TOGGLE", C_GREEN)
S4.Parent = Scroll; S4.LayoutOrder = 4

local autoToggleRow = Instance.new("Frame")
autoToggleRow.Parent = B4auto
autoToggleRow.Size   = UDim2.new(1, 0, 0, 30)
autoToggleRow.BackgroundTransparency = 1
autoToggleRow.ZIndex = 18; autoToggleRow.LayoutOrder = 1

-- Toggle button (acts as ON/OFF, styled to look like a toggle)
local AutoBtn = Instance.new("TextButton")
AutoBtn.Parent = autoToggleRow
AutoBtn.Size   = UDim2.new(0, 60, 0, 26)
AutoBtn.Position = UDim2.new(0, 0, 0.5, -13)
AutoBtn.BackgroundColor3 = Color3.fromRGB(25, 80, 50)
AutoBtn.BorderSizePixel  = 0
AutoBtn.Font   = Enum.Font.GothamBold
AutoBtn.Text   = "OFF"
AutoBtn.TextColor3 = C_DIM
AutoBtn.TextSize   = 10
AutoBtn.ZIndex = 19
Instance.new("UICorner", AutoBtn).CornerRadius = UDim.new(0, 13)
AddStroke(AutoBtn, Color3.fromRGB(40, 120, 70), 1, 0)

local autoStatusLbl = Instance.new("TextLabel")
autoStatusLbl.Parent = autoToggleRow
autoStatusLbl.Size   = UDim2.new(0, 120, 1, 0)
autoStatusLbl.Position = UDim2.new(0, 68, 0, 0)
autoStatusLbl.BackgroundTransparency = 1
autoStatusLbl.Font   = Enum.Font.Gotham
autoStatusLbl.Text   = "Status"
autoStatusLbl.TextColor3 = C_DIM
autoStatusLbl.TextSize   = 8
autoStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
autoStatusLbl.ZIndex = 19

local autoStatusVal = Instance.new("TextLabel")
autoStatusVal.Parent = autoToggleRow
autoStatusVal.Size   = UDim2.new(0, 120, 0, 14)
autoStatusVal.Position = UDim2.new(0, 68, 0, 14)
autoStatusVal.BackgroundTransparency = 1
autoStatusVal.Font   = Enum.Font.GothamBold
autoStatusVal.Text   = "Idle"
autoStatusVal.TextColor3 = C_DIM
autoStatusVal.TextSize   = 9
autoStatusVal.TextXAlignment = Enum.TextXAlignment.Left
autoStatusVal.ZIndex = 19

Divider(B4auto, 2)

-- Extra action row: Lowest + Rejoin
local row2 = HalfBtnRow(B4auto, 3)
local NewSrvBtn = HalfBtn(row2, "🆕 Lowest", Color3.fromRGB(60, 40, 150))
local RejoinBtn = HalfBtn(row2, "🔄 Rejoin",  Color3.fromRGB(130, 70, 15))

-- ============================================================
-- SECTION 5 — SERVER LIST
-- ============================================================
local S5, B3 = MakeSection("📋  SERVER LIST", Color3.fromRGB(70, 165, 255))
S5.Parent = Scroll; S5.LayoutOrder = 5

-- column header
local srvHeader = Instance.new("TextLabel")
srvHeader.Parent = B3
srvHeader.Size   = UDim2.new(1, 0, 0, 13)
srvHeader.BackgroundTransparency = 1
srvHeader.Font   = Enum.Font.Code
srvHeader.Text   = string.format("%-3s %-7s %-5s %5s", "#", "Players", "FPS", "Ping")
srvHeader.TextColor3 = Color3.fromRGB(70, 80, 130)
srvHeader.TextSize   = 8
srvHeader.TextXAlignment = Enum.TextXAlignment.Left
srvHeader.ZIndex = 18; srvHeader.LayoutOrder = 1

local srvStatus = InfoRow(B3, "Tap Refresh to load servers.", C_DIM, 2, 12)

local RefreshBtn = StyledBtn(B3, "🔄  Refresh Server List",
    Color3.fromRGB(25, 55, 130), 3, 24)

-- ============================================================
-- SECTION 6 — STATUS BAR
-- ============================================================
local S6, B4 = MakeSection("📡  STATUS", C_ORANGE)
S6.Parent = Scroll; S6.LayoutOrder = 6

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Parent = B4
StatusLabel.Size   = UDim2.new(1, 0, 0, 20)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font   = Enum.Font.Gotham
StatusLabel.Text   = "Ready."
StatusLabel.TextColor3 = C_DIM
StatusLabel.TextSize   = 9
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextWrapped = true
StatusLabel.ZIndex = 18; StatusLabel.LayoutOrder = 1

-- Footer watermark
local footer = Instance.new("TextLabel")
footer.Parent = Scroll
footer.LayoutOrder = 99
footer.Size   = UDim2.new(1, 0, 0, 16)
footer.BackgroundTransparency = 1
footer.Font   = Enum.Font.Gotham
footer.Text   = "by Steal Egg  •  v2.0"
footer.TextColor3 = Color3.fromRGB(40, 40, 70)
footer.TextSize   = 7
footer.ZIndex = 16

-- ============================================================
-- EGG SCANNER  — current server only (real APIs)
-- ============================================================
local function scanCurrentServerEggs()
    -- Method A: EggCmds.GetAreaEggSnapshot() — official client module
    if EggCmds then
        local ok, snap = pcall(function() return EggCmds.GetAreaEggSnapshot() end)
        if ok and type(snap) == "table" then
            local records = snap.Records or snap
            local found, best = {}, nil
            for _, rec in pairs(records) do
                if type(rec) == "table" and rec.State == "Slot" then
                    local cat    = tostring(rec.AssetCategory or rec.Name or "Egg")
                    local rarity = getRarityName(cat) or "?"
                    local score  = RARITY_ORDER[rarity] or 0
                    local mutTag = getMutTag(rec)
                    if not best or score > (RARITY_ORDER[best.rarity] or 0) then
                        best = { name=cat, rarity=rarity, mut=mutTag, score=score }
                    end
                    -- Count per rarity
                    found[rarity] = (found[rarity] or 0) + 1
                end
            end
            return best, found, "live"
        end
    end
    -- Method B: Workspace scan fallback
    local ws = game:GetService("Workspace")
    local root = (ws:FindFirstChild("__OBJECTS") and
                  ws.__OBJECTS:FindFirstChild("Areas")) or ws
    local found, best = {}, nil
    local function scan(p, d)
        if d > 5 then return end
        for _, obj in ipairs(p:GetChildren()) do
            if obj.Name:lower():find("egg") then
                local n = obj.Name
                found[n] = (found[n] or 0) + 1
                if not best then best = {name=n, rarity="?", mut="", score=0} end
            end
            scan(obj, d+1)
        end
    end
    pcall(scan, root, 0)
    return best, found, "ws"
end

-- ============================================================
-- SERVER LIST FETCH  (real Roblox public API with pagination)
-- pages: fetch up to 2 pages (200 servers) to get a good sample
-- ============================================================
local function fetchAllServers(maxPages)
    maxPages = maxPages or 2
    local servers = {}
    local cursor  = nil
    local page    = 0
    repeat
        page = page + 1
        local url = "https://games.roblox.com/v1/games/" .. PlaceId
            .. "/servers/Public?sortOrder=Asc&limit=100"
            .. (cursor and ("&cursor=" .. cursor) or "")
        local ok, raw = pcall(function() return game:HttpGet(url) end)
        if not ok or not raw or raw == "" then break end
        local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if not ok2 or type(data) ~= "table" or not data.data then break end
        for _, s in ipairs(data.data) do
            table.insert(servers, s)
        end
        cursor = data.nextPageCursor
        if cursor then task.wait(0.3) end  -- avoid rate-limit
    until not cursor or page >= maxPages
    return servers
end

-- ============================================================
-- TELEPORT HELPERS
-- ============================================================
local function tpTo(jobId, label)
    StatusLabel.Text = "🚀 Teleporting → " .. (label or "server") .. "..."
    StatusLabel.TextColor3 = Color3.fromRGB(100, 170, 255)
    task.wait(0.3)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, jobId, LocalPlayer)
    end)
    if not ok then
        StatusLabel.Text = "❌ " .. tostring(err):sub(1, 60)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
        NotifDot.Visible = true
        return false
    end
    return true
end

-- ============================================================
-- REFRESH SERVER LIST  (populates Section 5)
-- ============================================================
local serverCache = {}   -- last fetched server list

local function refreshServerList()
    -- Clear old rows
    for _, c in ipairs(B3:GetChildren()) do
        if c ~= srvHeader and c ~= srvStatus and c ~= RefreshBtn
        and c:IsA("TextLabel") then c:Destroy() end
    end
    srvStatus.Text = "⏳ Fetching servers (up to 2 pages)..."
    srvStatus.TextColor3 = Color3.fromRGB(200, 180, 60)
    RefreshBtn.Active = false

    task.spawn(function()
        local servers = fetchAllServers(2)
        serverCache = servers

        if #servers == 0 then
            srvStatus.Text = "❌ Failed. Make sure HTTP is enabled."
            srvStatus.TextColor3 = Color3.fromRGB(255, 70, 70)
            RefreshBtn.Active = true
            return
        end

        local threshold = math.max(1, math.floor(tonumber(MaxBox.Text) or 1))
        local shown = 0
        local hasCurrent = false

        -- Sort: current first, then by player count ascending
        table.sort(servers, function(a, b)
            local aIsCur = tostring(a.id) == CurrentJobId
            local bIsCur = tostring(b.id) == CurrentJobId
            if aIsCur ~= bIsCur then return aIsCur end
            return (tonumber(a.playing) or 0) < (tonumber(b.playing) or 0)
        end)

        srvStatus.Text = string.format(
            "Found %d servers  |  threshold: %d", #servers, threshold)
        srvStatus.TextColor3 = Color3.fromRGB(70, 165, 255)

        for i, s in ipairs(servers) do
            if shown >= 12 then break end
            local isCur   = tostring(s.id) == CurrentJobId
            local playing = tonumber(s.playing)  or 0
            local maxP    = tonumber(s.maxPlayers) or 0
            local fps     = math.floor(tonumber(s.fps)  or 0)
            local ping    = math.floor(tonumber(s.ping) or 0)
            local free    = maxP - playing

            -- Tag
            local tag = ""
            if isCur         then tag = " ◀YOU" end
            if not isCur and playing <= threshold then tag = tag .. " ✓" end

            -- Color coding
            local col
            if isCur then
                col = Color3.fromRGB(90, 210, 120)
            elseif playing <= threshold then
                col = Color3.fromRGB(100, 210, 255)
            elseif free <= 2 then
                col = Color3.fromRGB(255, 90, 90)
            else
                col = Color3.fromRGB(170, 170, 185)
            end

            local line = string.format(
                "%-3d %3d/%-3d  %3dfps %4dms%s",
                shown + 1, playing, maxP, fps, ping, tag)

            local r = InfoRow(B3, line, col, 100 + shown, 13)
            r.Font = Enum.Font.Code
            shown = shown + 1
            if isCur then hasCurrent = true end
        end

        if not hasCurrent then
            InfoRow(B3, "⚠ Your server not in first 200 results", Color3.fromRGB(255, 180, 50), 200, 12)
        end

        RefreshBtn.Active = true
    end)
end

RefreshBtn.MouseButton1Click:Connect(refreshServerList)

-- ============================================================
-- HOP LOGIC
-- ============================================================

-- Hop to a RANDOM server (not current, has a free slot)
local function hopRandom()
    StatusLabel.Text = "🔍 Finding a server..."
    StatusLabel.TextColor3 = Color3.fromRGB(220, 180, 50)

    local servers = fetchAllServers(1)
    if #servers == 0 then
        StatusLabel.Text = "❌ API failed — enable HTTP requests."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
        NotifDot.Visible = true
        return false
    end

    local candidates = {}
    for _, s in ipairs(servers) do
        local playing = tonumber(s.playing) or 0
        local maxP    = tonumber(s.maxPlayers) or 0
        if tostring(s.id) ~= CurrentJobId and playing < maxP then
            table.insert(candidates, tostring(s.id))
        end
    end

    if #candidates == 0 then
        StatusLabel.Text = "❌ No available servers found."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
        return false
    end

    local pick = candidates[math.random(1, #candidates)]
    return tpTo(pick, "random server")
end

-- Hop to the server with the LOWEST player count (best for finding rare eggs)
local function hopLowest()
    StatusLabel.Text = "🔍 Finding lowest-pop server..."
    StatusLabel.TextColor3 = Color3.fromRGB(180, 140, 255)

    local servers = fetchAllServers(2)
    if #servers == 0 then
        StatusLabel.Text = "❌ API failed — enable HTTP requests."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
        NotifDot.Visible = true
        return false
    end

    local best, bestCount = nil, math.huge
    for _, s in ipairs(servers) do
        local playing = tonumber(s.playing) or 0
        local maxP    = tonumber(s.maxPlayers) or 0
        if tostring(s.id) ~= CurrentJobId and playing < maxP and playing < bestCount then
            best      = tostring(s.id)
            bestCount = playing
        end
    end

    if not best then
        StatusLabel.Text = "❌ No servers with open slots."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
        return false
    end

    StatusLabel.Text = string.format("🆕 Lowest: %d players", bestCount)
    StatusLabel.TextColor3 = Color3.fromRGB(180, 140, 255)
    task.wait(0.4)
    return tpTo(best, string.format("server (%d players)", bestCount))
end

-- Rejoin the EXACT current server
local function rejoin()
    StatusLabel.Text = "🔄 Rejoining this server..."
    StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 60)
    task.wait(0.3)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, game.JobId, LocalPlayer)
    end)
    if not ok then
        StatusLabel.Text = "❌ Rejoin failed: " .. tostring(err):sub(1, 50)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
    end
end

-- Smart hop (checks threshold first)
local function joinOnce()
    local threshold  = math.max(1, math.floor(tonumber(MaxBox.Text) or 1))
    local count      = #Players:GetPlayers()
    if count <= threshold then
        StatusLabel.Text = "✓ This server is fine ("..count.." players)."
        StatusLabel.TextColor3 = Color3.fromRGB(90, 210, 120)
        return false
    end
    return hopRandom()
end

-- ============================================================
-- BUTTON WIRING
-- ============================================================
JoinBtn.MouseButton1Click:Connect(function()
    JoinBtn.Active = false
    JoinBtn.BackgroundColor3 = Color3.fromRGB(60, 25, 130)
    joinOnce()
    task.wait(2)
    JoinBtn.Active = true
    JoinBtn.BackgroundColor3 = Color3.fromRGB(100, 40, 220)
end)

NewSrvBtn.MouseButton1Click:Connect(function()
    NewSrvBtn.Active = false
    NewSrvBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 100)
    hopLowest()
    task.wait(2)
    NewSrvBtn.Active = true
    NewSrvBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 150)
end)

RejoinBtn.MouseButton1Click:Connect(function()
    RejoinBtn.Active = false
    RejoinBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 10)
    rejoin()
    task.wait(2)
    RejoinBtn.Active = true
    RejoinBtn.BackgroundColor3 = Color3.fromRGB(130, 70, 15)
end)

local autoEnabled = false
local autoThread  = nil

AutoBtn.MouseButton1Click:Connect(function()
    autoEnabled = not autoEnabled
    if autoEnabled then
        AutoBtn.Text = "ON"
        AutoBtn.TextColor3 = C_GREEN
        AutoBtn.BackgroundColor3 = Color3.fromRGB(20, 100, 55)
        AddStroke(AutoBtn, C_GREEN, 1.5, 0)
        autoStatusVal.Text = "Running..."
        autoStatusVal.TextColor3 = C_GREEN
        autoThread = task.spawn(function()
            while autoEnabled and ScreenGui.Parent do
                local threshold = math.max(1, math.floor(tonumber(MaxBox.Text) or 1))
                local count     = #Players:GetPlayers()
                if count <= threshold then
                    StatusLabel.Text = "✓ "..count.." player(s). Watching..."
                    StatusLabel.TextColor3 = Color3.fromRGB(90, 210, 120)
                    autoStatusVal.Text = "Watching..."
                    autoStatusVal.TextColor3 = C_GREEN
                    task.wait(3)
                else
                    StatusLabel.Text = "⚠ "..count.." players. Hopping..."
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
                    autoStatusVal.Text = "Hopping..."
                    autoStatusVal.TextColor3 = C_ORANGE
                    NotifDot.Visible = true
                    hopRandom()
                    task.wait(6)
                end
            end
        end)
    else
        AutoBtn.Text = "OFF"
        AutoBtn.TextColor3 = C_DIM
        AutoBtn.BackgroundColor3 = Color3.fromRGB(25, 80, 50)
        AddStroke(AutoBtn, Color3.fromRGB(40, 120, 70), 1, 0)
        autoStatusVal.Text = "Idle"
        autoStatusVal.TextColor3 = C_DIM
        if autoThread then task.cancel(autoThread); autoThread = nil end
        StatusLabel.Text = "Auto hop stopped."
        StatusLabel.TextColor3 = Color3.fromRGB(165, 165, 165)
    end
end)

-- ============================================================
-- LIVE MONITOR  — polls current server every 3s
-- ============================================================
task.spawn(function()
    while ScreenGui.Parent do
        -- Player count
        local count = #Players:GetPlayers()
        lblPlayers.Text = "👥 Players: " .. count

        -- Ping / FPS from Stats service
        local ok1, ping = pcall(function()
            return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        local fps = math.floor(workspace:GetRealPhysicsFPS and workspace:GetRealPhysicsFPS() or 60)
        lblPing.Text = string.format("📶 Ping: %dms   FPS: %d", ok1 and ping or 0, fps)

        -- Egg scan (current server only)
        local best, found, src = scanCurrentServerEggs()
        if best then
            local rarCol = RARITY_COLOR[best.rarity] or Color3.fromRGB(255, 210, 80)
            local mtag   = best.mut ~= "" and (best.mut .. " ") or ""
            lblBestEgg.Text = "🥚 Best: " .. mtag .. best.name
                .. "  [" .. best.rarity .. "]"
            lblBestEgg.TextColor3 = rarCol
            NotifDot.Visible = (RARITY_ORDER[best.rarity] or 0) >= 8  -- Secret+

            -- Build rarity summary (top 3 tiers present)
            local tiers = {}
            for rar, cnt in pairs(found) do
                table.insert(tiers, {r=rar, n=cnt, s=RARITY_ORDER[rar] or 0})
            end
            table.sort(tiers, function(a,b) return a.s > b.s end)

            -- Update the 3 stat tiles with top rarities
            if tiers[1] then
                local rc = RARITY_COLOR[tiers[1].r] or C_WHITE
                tile1Val.Text = tostring(tiers[1].n)
                tile1.BackgroundColor3 = Color3.fromRGB(18, 20, 55)
                AddStroke(tile1, rc, 1, 0.1)
            end
            if tiers[2] then
                local rc = RARITY_COLOR[tiers[2].r] or C_WHITE
                tile2Val.Text = tostring(tiers[2].n)
                AddStroke(tile2, rc, 1, 0.1)
            end
            if tiers[3] then
                local rc = RARITY_COLOR[tiers[3].r] or C_WHITE
                tile3Val.Text = tostring(tiers[3].n)
                AddStroke(tile3, rc, 1, 0.1)
            end

            local parts = {}
            for i = 1, math.min(4, #tiers) do
                table.insert(parts, tiers[i].r .. " x" .. tiers[i].n)
            end
            lblEggList.Text = #parts > 0
                and table.concat(parts, "   ")
                or  "No eggs found in areas"
        else
            lblBestEgg.Text = "🥚 No eggs / APIs not loaded"
            lblBestEgg.TextColor3 = Color3.fromRGB(120, 120, 150)
            lblEggList.Text = src == "ws"
                and "⚠ Using workspace fallback"
                or  "ℹ Run inside Steal An Egg"
        end

        task.wait(3)
    end
end)

-- Init
StatusLabel.Text = "Ready. Tap Refresh to load servers."
StatusLabel.TextColor3 = Color3.fromRGB(165, 165, 165)
