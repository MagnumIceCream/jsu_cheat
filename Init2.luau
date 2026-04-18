local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

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
-- MAIN SCRIPT
-- ============================================================
local MerchantData = require(Modules.MerchantData)

local Limit = MerchantData.BulkPurchaseMaxAmount
local Timeout = MerchantData.BulkPurchaseTimeout

-- Build ordered list of merchant keys
local MerchantKeys = {}
for k in MerchantData.Merchants do
    table.insert(MerchantKeys, k)
end
table.sort(MerchantKeys)

-- Get deduplicated bulk-purchasable items for a merchant
local function GetBulkItems(merchantKey)
    local m = MerchantData.Merchants[merchantKey]
    if not m or not m.AvailableOptions then return {} end
    local seen = {}
    local items = {}
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
-- Watches PlayerGui for the BulkPrompt the server spawns and
-- disables it for the duration of our purchase, then re-enables
-- it afterward so normal merchant usage still works fine.
-- ============================================================
local BuyerRunning = false
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "BulkPrompt" and BuyerRunning then
        child.Enabled = false
        task.spawn(function()
            repeat task.wait(0.1) until not BuyerRunning
            -- Only re-enable if it's still there (it may have self-destructed)
            if child and child.Parent then
                child.Enabled = true
            end
        end)
    end
end)

-- ============================================================
-- GUI
-- ============================================================
local Player = Players.LocalPlayer
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BulkBuyer"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 260, 0, 230)
Frame.Position = UDim2.new(0.5, -130, 0.5, -115)
Frame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

-- ============================================================
-- DRAG LOGIC
-- ============================================================
local dragging, dragStart, startPos

Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position
    end
end)

Frame.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

Frame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- ============================================================
-- HELPERS
-- ============================================================
local function MakeLabel(text, pos, size, parent)
    local l = Instance.new("TextLabel")
    l.Text = text
    l.Size = size
    l.Position = pos
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(140, 140, 180)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.Parent = parent
    return l
end

local function MakeTextBox(pos, size, placeholder, defaultText, parent)
    local b = Instance.new("TextBox")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.fromRGB(210, 210, 255)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.Text = defaultText or ""
    b.PlaceholderText = placeholder or ""
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local function MakePicker(labelText, labelY, rowY, parent)
    MakeLabel(labelText, UDim2.new(0, 12, 0, labelY), UDim2.new(1, -24, 0, 16), parent)

    local prev = Instance.new("TextButton")
    prev.Size = UDim2.new(0, 28, 0, 28)
    prev.Position = UDim2.new(0, 12, 0, rowY)
    prev.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    prev.BorderSizePixel = 0
    prev.TextColor3 = Color3.fromRGB(180, 180, 220)
    prev.Font = Enum.Font.GothamBold
    prev.TextSize = 14
    prev.Text = "<"
    prev.Parent = parent
    Instance.new("UICorner", prev).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -88, 0, 28)
    lbl.Position = UDim2.new(0, 46, 0, rowY)
    lbl.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    lbl.BorderSizePixel = 0
    lbl.TextColor3 = Color3.fromRGB(210, 210, 255)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.Text = ""
    lbl.Parent = parent
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)

    local nxt = Instance.new("TextButton")
    nxt.Size = UDim2.new(0, 28, 0, 28)
    nxt.Position = UDim2.new(1, -40, 0, rowY)
    nxt.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    nxt.BorderSizePixel = 0
    nxt.TextColor3 = Color3.fromRGB(180, 180, 220)
    nxt.Font = Enum.Font.GothamBold
    nxt.TextSize = 14
    nxt.Text = ">"
    nxt.Parent = parent
    Instance.new("UICorner", nxt).CornerRadius = UDim.new(0, 6)

    return prev, lbl, nxt
end

-- ============================================================
-- MERCHANT PICKER
-- ============================================================
local MerchantIndex = 1
local PrevMerchBtn, MerchantLabel, NextMerchBtn = MakePicker("MERCHANT", 10, 28, Frame)

-- ============================================================
-- ITEM PICKER (auto-populated from selected merchant)
-- ============================================================
local ItemIndex = 1
local CurrentItems = {}
local PrevItemBtn, ItemLabel, NextItemBtn = MakePicker("ITEM", 66, 84, Frame)

local function UpdateItemLabel()
    if #CurrentItems == 0 then
        ItemLabel.Text = "No items"
    else
        ItemLabel.Text = CurrentItems[ItemIndex]
    end
end

local function RefreshItems()
    CurrentItems = GetBulkItems(MerchantKeys[MerchantIndex])
    ItemIndex = 1
    UpdateItemLabel()
end

local function UpdateMerchantLabel()
    local key = MerchantKeys[MerchantIndex]
    local m = MerchantData.Merchants[key]
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
MakeLabel("AMOUNT", UDim2.new(0, 12, 0, 120), UDim2.new(1, -24, 0, 16), Frame)
local AmountBox = MakeTextBox(
    UDim2.new(0, 12, 0, 138),
    UDim2.new(1, -24, 0, 28),
    "Enter amount...", "", Frame
)
AmountBox.Font = Enum.Font.GothamBold
AmountBox.TextSize = 16

-- ============================================================
-- STATUS
-- ============================================================
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 0, 14)
StatusLabel.Position = UDim2.new(0, 12, 0, 208)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(90, 90, 130)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.Text = ""
StatusLabel.Parent = Frame

-- ============================================================
-- BUY BUTTON
-- ============================================================
local BuyBtn = Instance.new("TextButton")
BuyBtn.Size = UDim2.new(1, -24, 0, 28)
BuyBtn.Position = UDim2.new(0, 12, 0, 190)
BuyBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 190)
BuyBtn.BorderSizePixel = 0
BuyBtn.TextColor3 = Color3.fromRGB(210, 220, 255)
BuyBtn.Font = Enum.Font.GothamMedium
BuyBtn.TextSize = 13
BuyBtn.Text = "Buy"
BuyBtn.Parent = Frame
Instance.new("UICorner", BuyBtn).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- BUY LOGIC
-- ============================================================
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
            Found.Is = true
            Found.Index = i
            break
        end
    end

    if not Found.Is then
        StatusLabel.Text = "No Bulk Purchase option on this merchant."
        return
    end

    BuyBtn.Active = false
    BuyBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 110)
    BuyerRunning = true

    -- Also suppress any BulkPrompt already sitting in PlayerGui right now
    local existing = PlayerGui:FindFirstChild("BulkPrompt")
    if existing then existing.Enabled = false end

    local Done = false

    task.spawn(function()
        while not Done do
            Send:FireServer("Merchant", MerchantKey, Found.Index)
            task.wait(Timeout + 0.1)
        end
    end)

    task.spawn(function()
        local Remaining = Amount
        local Request = 0
        while Remaining > 0 do
            local Chunk = math.min(Remaining, Limit)
            Request += 1
            StatusLabel.Text = ("Request %d — buying %d"):format(Request, Chunk)
            Send:FireServer("BulkPurchase", SeekedItem, Chunk)
            Remaining -= Chunk
        end

        Done = true
        BuyerRunning = false
        StatusLabel.Text = ("Done! %d request(s) fired."):format(Request)
        BuyBtn.Active = true
        BuyBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 190)
    end)
end

BuyBtn.MouseButton1Click:Connect(function()
    local MerchantKey = MerchantKeys[MerchantIndex]
    local Item = CurrentItems[ItemIndex]
    local Amount = tonumber(AmountBox.Text)

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
