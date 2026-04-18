local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Library = ReplicatedStorage:WaitForChild("Library")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = Library:WaitForChild("Remotes")
local Send = Remotes:WaitForChild("Send")

-- ============================================================
-- HOOKS (single namecall override for both fixes)
-- 1. Block server-opened BulkPurchase GUI via Connect intercept
-- 2. Block duplicate LoadBoosts InvokeServer to prevent kick
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

    -- Block server GUI: wrap OnClientEvent callbacks to swallow BulkPurchase
    if method == "Connect" and self == Send.OnClientEvent then
        local args = {...}
        local originalCallback = args[1]
        args[1] = newcclosure(function(action, ...)
            if action == "BulkPurchase" then return end
            return originalCallback(action, ...)
        end)
        return oldNamecall(self, table.unpack(args))
    end

    -- Block duplicate LoadBoosts: cache first result, return it on repeat calls
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

-- ============================================================
-- GUI
-- ============================================================
local Player = Players.LocalPlayer
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BulkBuyer"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player.PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 260, 0, 230) -- taller to fit extra padding
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

-- ============================================================
-- MERCHANT PICKER
-- ============================================================
MakeLabel("MERCHANT", UDim2.new(0, 12, 0, 10), UDim2.new(1, -24, 0, 16), Frame)

local MerchantIndex = 1

local PrevBtn = Instance.new("TextButton")
PrevBtn.Size = UDim2.new(0, 28, 0, 28)
PrevBtn.Position = UDim2.new(0, 12, 0, 28)
PrevBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
PrevBtn.BorderSizePixel = 0
PrevBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
PrevBtn.Font = Enum.Font.GothamBold
PrevBtn.TextSize = 14
PrevBtn.Text = "<"
PrevBtn.Parent = Frame
Instance.new("UICorner", PrevBtn).CornerRadius = UDim.new(0, 6)

local MerchantLabel = Instance.new("TextLabel")
MerchantLabel.Size = UDim2.new(1, -88, 0, 28)
MerchantLabel.Position = UDim2.new(0, 46, 0, 28)
MerchantLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
MerchantLabel.BorderSizePixel = 0
MerchantLabel.TextColor3 = Color3.fromRGB(210, 210, 255)
MerchantLabel.Font = Enum.Font.GothamMedium
MerchantLabel.TextSize = 12
MerchantLabel.Text = ""
MerchantLabel.Parent = Frame
Instance.new("UICorner", MerchantLabel).CornerRadius = UDim.new(0, 6)

local NextBtn = Instance.new("TextButton")
NextBtn.Size = UDim2.new(0, 28, 0, 28)
NextBtn.Position = UDim2.new(1, -40, 0, 28)
NextBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
NextBtn.BorderSizePixel = 0
NextBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
NextBtn.Font = Enum.Font.GothamBold
NextBtn.TextSize = 14
NextBtn.Text = ">"
NextBtn.Parent = Frame
Instance.new("UICorner", NextBtn).CornerRadius = UDim.new(0, 6)

local function UpdateMerchantLabel()
    local key = MerchantKeys[MerchantIndex]
    local m = MerchantData.Merchants[key]
    MerchantLabel.Text = (m and m.ShopName) or key
end

PrevBtn.MouseButton1Click:Connect(function()
    MerchantIndex = ((MerchantIndex - 2) % #MerchantKeys) + 1
    UpdateMerchantLabel()
end)

NextBtn.MouseButton1Click:Connect(function()
    MerchantIndex = (MerchantIndex % #MerchantKeys) + 1
    UpdateMerchantLabel()
end)

UpdateMerchantLabel()

-- ============================================================
-- ITEM
-- ============================================================
MakeLabel("ITEM", UDim2.new(0, 12, 0, 66), UDim2.new(1, -24, 0, 16), Frame)
local ItemBox = MakeTextBox(
    UDim2.new(0, 12, 0, 84),
    UDim2.new(1, -24, 0, 28),
    "Item name...", "Unusual Arrow", Frame
)

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
-- STATUS  (moved down to accommodate extra padding gap)
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
-- BUY BUTTON  (extra 24px gap below amount box: 138+28+24 = 190)
-- ============================================================
local BuyBtn = Instance.new("TextButton")
BuyBtn.Size = UDim2.new(1, -24, 0, 28)
BuyBtn.Position = UDim2.new(0, 12, 0, 190) -- was 164, now 190 for more padding
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

    local Done = false

    -- Keep-alive loop: holds the merchant menu open server-side
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
        StatusLabel.Text = ("Done! %d request(s) fired."):format(Request)
        BuyBtn.Active = true
        BuyBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 190)
    end)
end

BuyBtn.MouseButton1Click:Connect(function()
    local MerchantKey = MerchantKeys[MerchantIndex]
    local Item = ItemBox.Text
    local Amount = tonumber(AmountBox.Text)

    if not MerchantKey then
        StatusLabel.Text = "Invalid merchant."
        return
    end
    if not Amount or Amount <= 0 or Item == "" then
        StatusLabel.Text = "Enter a valid item and amount."
        return
    end

    BuyFromMerchant(MerchantKey, Item, Amount)
end)
