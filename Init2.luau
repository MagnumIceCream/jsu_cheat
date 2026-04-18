local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Library = ReplicatedStorage:WaitForChild("Library")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = Library:WaitForChild("Remotes")
local Send = Remotes:WaitForChild("Send")

-- ============================================================
-- HOOK: Block duplicate LoadBoosts InvokeServer to prevent kick
-- ============================================================
local SharedModules = Modules:WaitForChild("Shared")
local LevelHandlerScript = SharedModules:FindFirstChild("LevelHandler")
local LevelHandlerAssets = LevelHandlerScript and LevelHandlerScript:FindFirstChild("Assets")
local fetchInvoke = LevelHandlerAssets and LevelHandlerAssets:WaitForChild("_fetch", 10)

local alreadyInvoked = false
local cachedBoostsTable, cachedBoostValues

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "InvokeServer" and fetchInvoke and self == fetchInvoke then
        local action = (...)
        if action == "LoadBoosts" then
            if alreadyInvoked then
                return cachedBoostsTable, cachedBoostValues
            end
            alreadyInvoked = true
            cachedBoostsTable, cachedBoostValues = oldNamecall(self, ...)
            return cachedBoostsTable, cachedBoostValues
        end
    end
    return oldNamecall(self, ...)
end)

setreadonly(mt, true)

-- ============================================================
-- MAIN
-- ============================================================
local MerchantData = require(Modules.MerchantData)

local Limit   = MerchantData.BulkPurchaseMaxAmount
local Timeout = MerchantData.BulkPurchaseTimeout

local MerchantKeys = {}
for k in MerchantData.Merchants do
    table.insert(MerchantKeys, k)
end
table.sort(MerchantKeys)

local function GetBulkItems(merchantKey)
    local m = MerchantData.Merchants[merchantKey]
    if not m or not m.AvailableOptions then return {} end
    local seen, items = {}, {}
    for _, opt in m.AvailableOptions do
        if typeof(opt) == "table" and opt.Item and not seen[opt.Item] then
            seen[opt.Item] = true
            table.insert(items, opt.Item)
        end
    end
    return items
end

-- ============================================================
-- BULK PROMPT SUPPRESSOR
-- ============================================================
local BuyerRunning = false
local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "BulkPrompt" and BuyerRunning then
        child.Enabled = false
        task.spawn(function()
            repeat task.wait(0.1) until not BuyerRunning
            if child and child.Parent then
                child.Enabled = true
            end
        end)
    end
end)

-- ============================================================
-- GUI ROOT
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name          = "BulkBuyer"
ScreenGui.ResetOnSpawn  = false
ScreenGui.DisplayOrder  = 999
ScreenGui.Parent        = PlayerGui

-- ============================================================
-- TOGGLE BUTTON (top-left corner)
-- ============================================================
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size            = UDim2.new(0, 36, 0, 36)
ToggleBtn.Position        = UDim2.new(0, 8, 0, 8)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 190)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.TextColor3      = Color3.fromRGB(210, 220, 255)
ToggleBtn.Font            = Enum.Font.GothamBold
ToggleBtn.TextSize        = 18
ToggleBtn.Text            = "B"
ToggleBtn.Parent          = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

-- ============================================================
-- MAIN FRAME  (layout: 12px padding, rows spaced 56px apart)
--
--   Y=10  label MERCHANT
--   Y=28  < MerchantLabel >
--   Y=66  label ITEM
--   Y=84  < ItemLabel >
--   Y=122 label AMOUNT
--   Y=140 AmountBox
--   Y=182 BuyBtn
--   Y=216 StatusLabel
--   total height = 216+14+8 = 238
-- ============================================================
local Frame = Instance.new("Frame")
Frame.Size              = UDim2.new(0, 260, 0, 238)
Frame.Position          = UDim2.new(0.5, -130, 0.5, -119)
Frame.BackgroundColor3  = Color3.fromRGB(28, 28, 40)
Frame.BorderSizePixel   = 0
Frame.Active            = true
Frame.Parent            = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

ToggleBtn.MouseButton1Click:Connect(function()
    Frame.Visible = not Frame.Visible
    ToggleBtn.BackgroundColor3 = Frame.Visible
        and Color3.fromRGB(70, 80, 190)
        or  Color3.fromRGB(50, 50, 80)
end)

-- ============================================================
-- DRAG — use UserInputService so it works even over child elements
-- ============================================================
local dragging   = false
local dragOffset = Vector2.new()

local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 28)
TitleBar.Position         = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 2
TitleBar.Parent           = Frame
do
    local c = Instance.new("UICorner", TitleBar)
    c.CornerRadius = UDim.new(0, 10)
    -- square off the bottom corners
    local patch = Instance.new("Frame", TitleBar)
    patch.Size              = UDim2.new(1, 0, 0, 10)
    patch.Position          = UDim2.new(0, 0, 1, -10)
    patch.BackgroundColor3  = Color3.fromRGB(20, 20, 32)
    patch.BorderSizePixel   = 0
end

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size                = UDim2.new(1, -12, 1, 0)
TitleLabel.Position            = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3          = Color3.fromRGB(160, 160, 200)
TitleLabel.Font                = Enum.Font.GothamBold
TitleLabel.TextSize            = 11
TitleLabel.TextXAlignment      = Enum.TextXAlignment.Left
TitleLabel.Text                = "BULK BUYER  ·  drag to move"
TitleLabel.ZIndex              = 3

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging   = true
        local gp   = input.Position
        local fp   = Frame.AbsolutePosition
        dragOffset = Vector2.new(gp.X - fp.X, gp.Y - fp.Y)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local gp = input.Position
        Frame.Position = UDim2.fromOffset(gp.X - dragOffset.X, gp.Y - dragOffset.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- ============================================================
-- HELPERS
-- ============================================================
local function MakeLabel(text, posY, parent)
    local l = Instance.new("TextLabel")
    l.Size                 = UDim2.new(1, -24, 0, 14)
    l.Position             = UDim2.new(0, 12, 0, posY)
    l.BackgroundTransparency = 1
    l.TextColor3           = Color3.fromRGB(140, 140, 180)
    l.TextXAlignment       = Enum.TextXAlignment.Left
    l.Font                 = Enum.Font.Gotham
    l.TextSize             = 11
    l.Text                 = text
    l.Parent               = parent
    return l
end

local function MakeTextBox(posY, placeholder, default, parent)
    local b = Instance.new("TextBox")
    b.Size              = UDim2.new(1, -24, 0, 28)
    b.Position          = UDim2.new(0, 12, 0, posY)
    b.BackgroundColor3  = Color3.fromRGB(18, 18, 30)
    b.BorderSizePixel   = 0
    b.TextColor3        = Color3.fromRGB(210, 210, 255)
    b.Font              = Enum.Font.GothamMedium
    b.TextSize          = 13
    b.Text              = default or ""
    b.PlaceholderText   = placeholder or ""
    b.Parent            = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

-- Builds a  < label >  picker row; returns (prevBtn, label, nextBtn)
local function MakePicker(labelText, labelY, rowY, parent)
    MakeLabel(labelText, labelY, parent)

    local prev = Instance.new("TextButton")
    prev.Size              = UDim2.new(0, 28, 0, 28)
    prev.Position          = UDim2.new(0, 12, 0, rowY)
    prev.BackgroundColor3  = Color3.fromRGB(18, 18, 30)
    prev.BorderSizePixel   = 0
    prev.TextColor3        = Color3.fromRGB(180, 180, 220)
    prev.Font              = Enum.Font.GothamBold
    prev.TextSize          = 14
    prev.Text              = "<"
    prev.Parent            = parent
    Instance.new("UICorner", prev).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1, -88, 0, 28)
    lbl.Position           = UDim2.new(0, 46, 0, rowY)
    lbl.BackgroundColor3   = Color3.fromRGB(18, 18, 30)
    lbl.BorderSizePixel    = 0
    lbl.TextColor3         = Color3.fromRGB(210, 210, 255)
    lbl.Font               = Enum.Font.GothamMedium
    lbl.TextSize           = 12
    lbl.Text               = ""
    lbl.Parent             = parent
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)

    local nxt = Instance.new("TextButton")
    nxt.Size               = UDim2.new(0, 28, 0, 28)
    nxt.Position           = UDim2.new(1, -40, 0, rowY)
    nxt.BackgroundColor3   = Color3.fromRGB(18, 18, 30)
    nxt.BorderSizePixel    = 0
    nxt.TextColor3         = Color3.fromRGB(180, 180, 220)
    nxt.Font               = Enum.Font.GothamBold
    nxt.TextSize           = 14
    nxt.Text               = ">"
    nxt.Parent             = parent
    Instance.new("UICorner", nxt).CornerRadius = UDim.new(0, 6)

    return prev, lbl, nxt
end

-- ============================================================
-- PICKERS  (offset rows by 28px to clear the title bar)
-- ============================================================
local MerchantIndex = 1
local PrevMerchBtn, MerchantLabel, NextMerchBtn = MakePicker("MERCHANT", 38, 54, Frame)

local ItemIndex    = 1
local CurrentItems = {}
local PrevItemBtn, ItemLabel, NextItemBtn = MakePicker("ITEM", 94, 110, Frame)

local function UpdateItemLabel()
    ItemLabel.Text = #CurrentItems > 0 and CurrentItems[ItemIndex] or "No items"
end

local function RefreshItems()
    CurrentItems = GetBulkItems(MerchantKeys[MerchantIndex])
    ItemIndex    = 1
    UpdateItemLabel()
end

local function UpdateMerchantLabel()
    local key = MerchantKeys[MerchantIndex]
    local m   = MerchantData.Merchants[key]
    MerchantLabel.Text = (m and m.ShopName) or key
    RefreshItems()
end

PrevMerchBtn.MouseButton1Click:Connect(function()
    MerchantIndex = ((MerchantIndex - 2) % #MerchantKeys) + 1
    UpdateMerchantLabel()
end)
NextMerchBtn.MouseButton1Click:Connect(function()
    MerchantIndex = (MerchantIndex % #MerchantKeys) + 1
    UpdateMerchantLabel()
end)
PrevItemBtn.MouseButton1Click:Connect(function()
    if #CurrentItems == 0 then return end
    ItemIndex = ((ItemIndex - 2) % #CurrentItems) + 1
    UpdateItemLabel()
end)
NextItemBtn.MouseButton1Click:Connect(function()
    if #CurrentItems == 0 then return end
    ItemIndex = (ItemIndex % #CurrentItems) + 1
    UpdateItemLabel()
end)

UpdateMerchantLabel()

-- ============================================================
-- AMOUNT
-- ============================================================
MakeLabel("AMOUNT", 150, Frame)
local AmountBox      = MakeTextBox(166, "Enter amount...", "", Frame)
AmountBox.Font       = Enum.Font.GothamBold
AmountBox.TextSize   = 16

-- ============================================================
-- BUY BUTTON
-- ============================================================
local BuyBtn = Instance.new("TextButton")
BuyBtn.Size             = UDim2.new(1, -24, 0, 28)
BuyBtn.Position         = UDim2.new(0, 12, 0, 204)
BuyBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 190)
BuyBtn.BorderSizePixel  = 0
BuyBtn.TextColor3       = Color3.fromRGB(210, 220, 255)
BuyBtn.Font             = Enum.Font.GothamMedium
BuyBtn.TextSize         = 13
BuyBtn.Text             = "Buy"
BuyBtn.Parent           = Frame
Instance.new("UICorner", BuyBtn).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- STATUS LABEL  (below buy button, never covered)
-- ============================================================
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size                 = UDim2.new(1, -24, 0, 14)
StatusLabel.Position             = UDim2.new(0, 12, 0, 218)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3           = Color3.fromRGB(90, 90, 130)
StatusLabel.TextXAlignment       = Enum.TextXAlignment.Left
StatusLabel.Font                 = Enum.Font.Gotham
StatusLabel.TextSize             = 11
StatusLabel.Text                 = ""
StatusLabel.Parent               = Frame

-- ============================================================
-- BUY LOGIC
-- ============================================================
local function SetBuyState(enabled)
    BuyBtn.Active           = enabled
    BuyBtn.BackgroundColor3 = enabled
        and Color3.fromRGB(70, 80, 190)
        or  Color3.fromRGB(40, 45, 110)
    BuyBtn.TextTransparency = enabled and 0 or 0.4
end

local function BuyFromMerchant(MerchantKey, SeekedItem, Amount)
    local Merchant = MerchantData.Merchants[MerchantKey]

    if not MerchantData.BulkPurchaseEnabled then
        StatusLabel.Text = "Bulk purchase disabled."
        return
    end
    if not Merchant.AvailableOptions then
        StatusLabel.Text = "No options available."
        return
    end

    local Found = { Is = false, Index = nil }
    for i, v in Merchant.AvailableOptions do
        if v == "Bulk Purchase" then
            Found.Is    = true
            Found.Index = i
            break
        end
    end

    if not Found.Is then
        StatusLabel.Text = "No Bulk Purchase option on this merchant."
        return
    end

    SetBuyState(false)
    BuyerRunning = true

    -- Suppress any existing BulkPrompt immediately
    local existing = PlayerGui:FindFirstChild("BulkPrompt")
    if existing then existing.Enabled = false end

    local Done = false

    -- Keep-alive: hold merchant menu open server-side
    task.spawn(function()
        while not Done do
            Send:FireServer("Merchant", MerchantKey, Found.Index)
            task.wait(Timeout + 0.1)
        end
    end)

    task.spawn(function()
        local Remaining = Amount
        local Request   = 0
        while Remaining > 0 do
            local Chunk = math.min(Remaining, Limit)
            Request    += 1
            StatusLabel.Text = ("Request %d — buying %d"):format(Request, Chunk)
            Send:FireServer("BulkPurchase", SeekedItem, Chunk)
            Remaining  -= Chunk
        end

        Done         = true
        BuyerRunning = false
        StatusLabel.Text = ("Done! %d request(s) fired."):format(Request)
        SetBuyState(true)
    end)
end

BuyBtn.MouseButton1Click:Connect(function()
    if not BuyBtn.Active then return end

    local MerchantKey = MerchantKeys[MerchantIndex]
    local Item        = CurrentItems[ItemIndex]
    local Amount      = tonumber(AmountBox.Text)

    if not MerchantKey then
        StatusLabel.Text = "Invalid merchant."
        return
    end
    if #CurrentItems == 0 then
        StatusLabel.Text = "This merchant has no bulk items."
        return
    end
    if not Amount or Amount <= 0 then
        StatusLabel.Text = "Enter a valid amount."
        return
    end

    BuyFromMerchant(MerchantKey, Item, Amount)
end)
