local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Library"):WaitForChild("Remotes")
local Send = Remotes.Send

local State = {
    running    = false,
    arrowType  = "Stand Arrow",
    interval   = 0.8,
    spinCount  = 0,
    status     = "Idle",
    exclusions = {},
}

local function getItemCount(name)
    local backpackItem = LocalPlayer.Backpack:FindFirstChild(name)
    if backpackItem then
        local amt = backpackItem:GetAttribute("amount")
        if amt then return amt end
        return 1
    end
    local char = LocalPlayer.Character
    if char then
        local equipped = char:FindFirstChild(name)
        if equipped then
            local amt = equipped:GetAttribute("amount")
            if amt then return amt end
            return 1
        end
    end
    return 0
end

local function getCurrentStand()
    local char = LocalPlayer.Character
    if not char then return "Unknown" end
    local ok, val = pcall(function()
        return LocalPlayer.Data.Stats.Ability.Value
    end)
    if ok and val and val ~= "" then return val end
    return "Unknown"
end

local function getCurrentAttribute()
    local ok, val = pcall(function()
        return LocalPlayer.Data.Stats.Attribute.Value
    end)
    if ok then return val end
    return "None"
end

local function getAllAbilities()
    local list = {}
    local ok, abilityData = pcall(function()
        return ReplicatedStorage.Modules.AbilityData:GetChildren()
    end)
    if ok then
        for _, v in ipairs(abilityData) do
            table.insert(list, v.Name)
        end
    end
    table.sort(list)
    return list
end

local function getAllAttributes()
    local list = {}
    local ok, module = pcall(function()
        return require(ReplicatedStorage.Modules.AttributeData)
    end)
    if ok and type(module) == "table" then
        for name in pairs(module) do
            table.insert(list, name)
        end
    end
    table.sort(list)
    return list
end

local function fireItem(name)
    pcall(function()
        Send:FireServer("Item", name)
    end)
end

local function shouldStop()
    local stand = getCurrentStand()
    local attr = getCurrentAttribute()
    for _, exc in ipairs(State.exclusions) do
        if exc.type == "attribute" then
            if attr == exc.attribute then
                return true, "Excluded attribute: " .. attr
            end
        elseif exc.type == "stand" then
            if stand == exc.stand then
                return true, "Excluded stand: " .. stand
            end
        elseif exc.type == "combo" then
            if stand == exc.stand and attr == exc.attribute then
                return true, "Excluded: " .. stand .. " + " .. attr
            end
        end
    end
    return false, nil
end

local spinThread = nil
local notifFrame = nil

local function showNotification(message)
    if notifFrame then notifFrame:Destroy() end

    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(0, 260, 0, 48)
    notif.Position = UDim2.new(0.5, -130, 0, -60)
    notif.BackgroundColor3 = T.elevated
    notif.BorderSizePixel = 0
    notif.ZIndex = 200
    corner(notif, 10)
    stroke(notif, T.success)
    notif.Parent = ScreenGui

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 7, 0, 7)
    dot.Position = UDim2.new(0, 14, 0.5, -3.5)
    dot.BackgroundColor3 = T.success
    dot.BorderSizePixel = 0
    corner(dot, 4)
    dot.Parent = notif

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -34, 1, 0)
    lbl.Position = UDim2.new(0, 28, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = message
    lbl.TextColor3 = T.text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.ZIndex = 200
    lbl.Parent = notif

    notifFrame = notif

    tween(notif, {Position = UDim2.new(0.5, -130, 0, 12)}, 0.25)
    task.delay(4, function()
        if notif and notif.Parent then
            tween(notif, {Position = UDim2.new(0.5, -130, 0, -60)}, 0.25)
            task.delay(0.25, function()
                if notif and notif.Parent then notif:Destroy() end
            end)
        end
    end)
end

local function stopSpin(reason, notify)
    State.running = false
    State.status = reason or "Stopped"
    if spinThread then
        task.cancel(spinThread)
        spinThread = nil
    end
    if notify then
        showNotification(reason)
    end
end

local function startSpin(updateUI)
    if State.running then return end
    local arrowCount = getItemCount(State.arrowType)
    if arrowCount <= 0 then
        State.status = "No arrows found"
        updateUI()
        return
    end
    State.running = true
    State.spinCount = 0
    State.status = "Running"
    updateUI()
    spinThread = task.spawn(function()
        while State.running do
            local stop, reason = shouldStop()
            if stop then
                stopSpin(reason, true)
                updateUI()
                break
            end
            local arrows = getItemCount(State.arrowType)
            if arrows <= 0 then
                stopSpin("Out of arrows", false)
                updateUI()
                break
            end
            fireItem(State.arrowType)
            State.spinCount = State.spinCount + 1
            State.status = "Running — " .. State.spinCount .. " spins"
            updateUI()
            task.wait(State.interval)
            stop, reason = shouldStop()
            if stop then
                stopSpin(reason, true)
                updateUI()
                break
            end
            local rokas = getItemCount("Rokakaka")
            if rokas <= 0 then
                stopSpin("Out of Rokakakas", false)
                updateUI()
                break
            end
            fireItem("Rokakaka")
            task.wait(State.interval)
        end
    end)
end

local old = PlayerGui:FindFirstChild("AutoSpinGUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoSpinGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 99
ScreenGui.Parent = PlayerGui

local T = {
    bg        = Color3.fromRGB(15, 15, 20),
    surface   = Color3.fromRGB(22, 22, 30),
    elevated  = Color3.fromRGB(30, 30, 42),
    border    = Color3.fromRGB(50, 50, 70),
    accent    = Color3.fromRGB(99, 102, 241),
    accentHov = Color3.fromRGB(79, 82, 221),
    danger    = Color3.fromRGB(239, 68, 68),
    success   = Color3.fromRGB(34, 197, 94),
    warning   = Color3.fromRGB(234, 179, 8),
    text      = Color3.fromRGB(240, 240, 255),
    textMuted = Color3.fromRGB(140, 140, 170),
    textDim   = Color3.fromRGB(80, 80, 110),
    pill      = Color3.fromRGB(40, 40, 58),
}

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = inst
end

local function stroke(inst, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or T.border
    s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
end

local function padding(inst, all, lr)
    local p = Instance.new("UIPadding")
    if lr then
        p.PaddingLeft   = UDim.new(0, lr)
        p.PaddingRight  = UDim.new(0, lr)
        p.PaddingTop    = UDim.new(0, all)
        p.PaddingBottom = UDim.new(0, all)
    else
        p.PaddingLeft   = UDim.new(0, all)
        p.PaddingRight  = UDim.new(0, all)
        p.PaddingTop    = UDim.new(0, all)
        p.PaddingBottom = UDim.new(0, all)
    end
    p.Parent = inst
end

local function tween(inst, props, t)
    TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

local function hoverButton(btn, base, hov)
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = hov}) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = base}) end)
end

local camera = workspace.CurrentCamera
local screenSize = camera.ViewportSize
local WIN_W = math.clamp(math.floor(screenSize.X * 0.28), 340, 460)
local WIN_H = math.clamp(math.floor(screenSize.Y * 0.58), 420, 540)

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Size = UDim2.new(0, WIN_W, 0, WIN_H)
Window.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Window.BackgroundColor3 = T.bg
Window.BorderSizePixel = 0
Window.ClipsDescendants = true
corner(Window, 14)
stroke(Window, T.border, 1)
Window.Parent = ScreenGui

do
    local dragging, dragStart, startPos
    Window.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Window.Position
        end
    end)
    Window.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    Window.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local grad = Instance.new("Frame")
grad.Size = UDim2.new(1, 0, 0, 80)
grad.Position = UDim2.new(0, 0, 0, 0)
grad.BackgroundColor3 = T.accent
grad.BackgroundTransparency = 0.93
grad.BorderSizePixel = 0
grad.ZIndex = 0
grad.Parent = Window

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 50)
TitleBar.BackgroundTransparency = 1
TitleBar.Parent = Window

local TitleDot = Instance.new("Frame")
TitleDot.Size = UDim2.new(0, 8, 0, 8)
TitleDot.Position = UDim2.new(0, 18, 0.5, -4)
TitleDot.BackgroundColor3 = T.accent
TitleDot.BorderSizePixel = 0
corner(TitleDot, 4)
TitleDot.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -80, 0, 20)
TitleText.Position = UDim2.new(0, 34, 0, 6)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Auto Spin"
TitleText.TextColor3 = T.text
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 16
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local SubText = Instance.new("TextLabel")
SubText.Size = UDim2.new(1, -80, 0, 14)
SubText.Position = UDim2.new(0, 34, 0, 26)
SubText.BackgroundTransparency = 1
SubText.Text = "Stand Arrow Farmer"
SubText.TextColor3 = T.textMuted
SubText.Font = Enum.Font.Gotham
SubText.TextSize = 11
SubText.TextXAlignment = Enum.TextXAlignment.Left
SubText.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -42, 0.5, -14)
MinBtn.BackgroundColor3 = T.elevated
MinBtn.Text = "—"
MinBtn.TextColor3 = T.textMuted
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.BorderSizePixel = 0
corner(MinBtn, 6)
MinBtn.Parent = TitleBar
hoverButton(MinBtn, T.elevated, T.border)

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -32, 0, 1)
Divider.Position = UDim2.new(0, 16, 0, 50)
Divider.BackgroundColor3 = T.border
Divider.BorderSizePixel = 0
Divider.Parent = Window

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -51)
Content.Position = UDim2.new(0, 0, 0, 51)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = T.accent
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Window

local ContentList = Instance.new("UIListLayout")
ContentList.Padding = UDim.new(0, 8)
ContentList.FillDirection = Enum.FillDirection.Vertical
ContentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentList.SortOrder = Enum.SortOrder.LayoutOrder
ContentList.Parent = Content

padding(Content, 12, 14)

local function makeSection(title, layoutOrder)
    local sec = Instance.new("Frame")
    sec.Size = UDim2.new(1, 0, 0, 0)
    sec.AutomaticSize = Enum.AutomaticSize.Y
    sec.BackgroundColor3 = T.surface
    sec.BorderSizePixel = 0
    sec.LayoutOrder = layoutOrder or 0
    corner(sec, 10)
    stroke(sec, T.border, 1)

    local secList = Instance.new("UIListLayout")
    secList.Padding = UDim.new(0, 0)
    secList.FillDirection = Enum.FillDirection.Vertical
    secList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    secList.SortOrder = Enum.SortOrder.LayoutOrder
    secList.Parent = sec

    local hdr = Instance.new("Frame")
    hdr.Size = UDim2.new(1, 0, 0, 36)
    hdr.BackgroundTransparency = 1
    hdr.LayoutOrder = 0
    hdr.Parent = sec
    padding(hdr, 0, 14)

    local htxt = Instance.new("TextLabel")
    htxt.Size = UDim2.new(1, 0, 1, 0)
    htxt.BackgroundTransparency = 1
    htxt.Text = title:upper()
    htxt.TextColor3 = T.accent
    htxt.Font = Enum.Font.GothamBold
    htxt.TextSize = 10
    htxt.TextXAlignment = Enum.TextXAlignment.Left
    htxt.Parent = hdr

    local hdiv = Instance.new("Frame")
    hdiv.Size = UDim2.new(1, -28, 0, 1)
    hdiv.Position = UDim2.new(0, 14, 0, 35)
    hdiv.BackgroundColor3 = T.border
    hdiv.BorderSizePixel = 0
    hdiv.LayoutOrder = 1
    hdiv.Parent = sec

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.LayoutOrder = 2
    body.Parent = sec

    local bodyList = Instance.new("UIListLayout")
    bodyList.Padding = UDim.new(0, 0)
    bodyList.FillDirection = Enum.FillDirection.Vertical
    bodyList.SortOrder = Enum.SortOrder.LayoutOrder
    bodyList.Parent = body

    padding(body, 8, 14)
    sec.Parent = Content
    return body
end

local function makeRow(parent, lOrder)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.LayoutOrder = lOrder or 0
    row.Parent = parent
    return row
end

local statusBody = makeSection("Status", 1)

local statRow = Instance.new("Frame")
statRow.Size = UDim2.new(1, 0, 0, 58)
statRow.BackgroundTransparency = 1
statRow.LayoutOrder = 0
statRow.Parent = statusBody

local statList = Instance.new("UIListLayout")
statList.FillDirection = Enum.FillDirection.Horizontal
statList.Padding = UDim.new(0, 8)
statList.HorizontalAlignment = Enum.HorizontalAlignment.Center
statList.VerticalAlignment = Enum.VerticalAlignment.Center
statList.SortOrder = Enum.SortOrder.LayoutOrder
statList.Parent = statRow

local function makeStatCard(parent, labelTxt, valueDefault, lOrder)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0.3, -4, 1, 0)
    card.BackgroundColor3 = T.elevated
    card.BorderSizePixel = 0
    card.LayoutOrder = lOrder
    corner(card, 8)
    stroke(card, T.border)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Position = UDim2.new(0, 0, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelTxt
    lbl.TextColor3 = T.textMuted
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Parent = card

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, 0, 0, 22)
    val.Position = UDim2.new(0, 0, 0, 26)
    val.BackgroundTransparency = 1
    val.Text = tostring(valueDefault)
    val.TextColor3 = T.text
    val.Font = Enum.Font.GothamBold
    val.TextSize = 18
    val.TextXAlignment = Enum.TextXAlignment.Center
    val.Parent = card

    card.Parent = parent
    return val
end

local arrowCountLabel = makeStatCard(statRow, "Arrows",    "—", 1)
local rokaCountLabel  = makeStatCard(statRow, "Rokakakas", "—", 2)
local spinCountLabel  = makeStatCard(statRow, "Spins",     "0", 3)

local pillRow = makeRow(statusBody, 1)
pillRow.Size = UDim2.new(1, 0, 0, 36)

local StatusPill = Instance.new("Frame")
StatusPill.Size = UDim2.new(1, 0, 0, 28)
StatusPill.Position = UDim2.new(0, 0, 0.5, -14)
StatusPill.BackgroundColor3 = T.elevated
StatusPill.BorderSizePixel = 0
corner(StatusPill, 6)
StatusPill.Parent = pillRow

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 7, 0, 7)
StatusDot.Position = UDim2.new(0, 12, 0.5, -3.5)
StatusDot.BackgroundColor3 = T.textDim
StatusDot.BorderSizePixel = 0
corner(StatusDot, 4)
StatusDot.Parent = StatusPill

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -32, 1, 0)
StatusLabel.Position = UDim2.new(0, 26, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Idle"
StatusLabel.TextColor3 = T.textMuted
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextSize = 12
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusPill

local standRow = makeRow(statusBody, 2)
standRow.Size = UDim2.new(1, 0, 0, 36)

local standLbl = Instance.new("TextLabel")
standLbl.Size = UDim2.new(0.5, 0, 1, 0)
standLbl.BackgroundTransparency = 1
standLbl.Text = "Current Stand"
standLbl.TextColor3 = T.textMuted
standLbl.Font = Enum.Font.Gotham
standLbl.TextSize = 13
standLbl.TextXAlignment = Enum.TextXAlignment.Left
standLbl.Parent = standRow

local standVal = Instance.new("TextLabel")
standVal.Size = UDim2.new(0.5, 0, 1, 0)
standVal.Position = UDim2.new(0.5, 0, 0, 0)
standVal.BackgroundTransparency = 1
standVal.Text = "—"
standVal.TextColor3 = T.text
standVal.Font = Enum.Font.GothamBold
standVal.TextSize = 13
standVal.TextXAlignment = Enum.TextXAlignment.Right
standVal.Parent = standRow

local attrRow = makeRow(statusBody, 3)
attrRow.Size = UDim2.new(1, 0, 0, 36)

local attrLbl = Instance.new("TextLabel")
attrLbl.Size = UDim2.new(0.5, 0, 1, 0)
attrLbl.BackgroundTransparency = 1
attrLbl.Text = "Attribute"
attrLbl.TextColor3 = T.textMuted
attrLbl.Font = Enum.Font.Gotham
attrLbl.TextSize = 13
attrLbl.TextXAlignment = Enum.TextXAlignment.Left
attrLbl.Parent = attrRow

local attrVal = Instance.new("TextLabel")
attrVal.Size = UDim2.new(0.5, 0, 1, 0)
attrVal.Position = UDim2.new(0.5, 0, 0, 0)
attrVal.BackgroundTransparency = 1
attrVal.Text = "—"
attrVal.TextColor3 = T.text
attrVal.Font = Enum.Font.GothamBold
attrVal.TextSize = 13
attrVal.TextXAlignment = Enum.TextXAlignment.Right
attrVal.Parent = attrRow

local configBody = makeSection("Configuration", 2)

local arrowRow = makeRow(configBody, 0)
arrowRow.Size = UDim2.new(1, 0, 0, 44)

local arrowLbl = Instance.new("TextLabel")
arrowLbl.Size = UDim2.new(0.5, 0, 1, 0)
arrowLbl.BackgroundTransparency = 1
arrowLbl.Text = "Arrow Type"
arrowLbl.TextColor3 = T.text
arrowLbl.Font = Enum.Font.GothamMedium
arrowLbl.TextSize = 13
arrowLbl.TextXAlignment = Enum.TextXAlignment.Left
arrowLbl.Parent = arrowRow

local toggleBg = Instance.new("Frame")
toggleBg.Size = UDim2.new(0, 178, 0, 28)
toggleBg.Position = UDim2.new(1, -178, 0.5, -14)
toggleBg.BackgroundColor3 = T.elevated
toggleBg.BorderSizePixel = 0
corner(toggleBg, 7)
stroke(toggleBg, T.border)
toggleBg.Parent = arrowRow

local toggleSlider = Instance.new("Frame")
toggleSlider.Size = UDim2.new(0.5, -2, 1, -4)
toggleSlider.Position = UDim2.new(0, 2, 0, 2)
toggleSlider.BackgroundColor3 = T.accent
toggleSlider.BorderSizePixel = 0
corner(toggleSlider, 5)
toggleSlider.Parent = toggleBg

local opt1 = Instance.new("TextButton")
opt1.Size = UDim2.new(0.5, 0, 1, 0)
opt1.Position = UDim2.new(0, 0, 0, 0)
opt1.BackgroundTransparency = 1
opt1.Text = "Stand"
opt1.TextColor3 = T.text
opt1.Font = Enum.Font.GothamBold
opt1.TextSize = 11
opt1.ZIndex = 2
opt1.Parent = toggleBg

local opt2 = Instance.new("TextButton")
opt2.Size = UDim2.new(0.5, 0, 1, 0)
opt2.Position = UDim2.new(0.5, 0, 0, 0)
opt2.BackgroundTransparency = 1
opt2.Text = "Unusual"
opt2.TextColor3 = T.textMuted
opt2.Font = Enum.Font.GothamMedium
opt2.TextSize = 11
opt2.ZIndex = 2
opt2.Parent = toggleBg

local arrowSelected = "Stand Arrow"
opt1.MouseButton1Click:Connect(function()
    if arrowSelected == "Stand Arrow" then return end
    arrowSelected = "Stand Arrow"
    State.arrowType = "Stand Arrow"
    tween(toggleSlider, {Position = UDim2.new(0, 2, 0, 2)})
    tween(opt1, {TextColor3 = T.text})
    tween(opt2, {TextColor3 = T.textMuted})
    opt1.Font = Enum.Font.GothamBold
    opt2.Font = Enum.Font.GothamMedium
end)
opt2.MouseButton1Click:Connect(function()
    if arrowSelected == "Unusual Arrow" then return end
    arrowSelected = "Unusual Arrow"
    State.arrowType = "Unusual Arrow"
    tween(toggleSlider, {Position = UDim2.new(0.5, -2, 0, 2)})
    tween(opt1, {TextColor3 = T.textMuted})
    tween(opt2, {TextColor3 = T.text})
    opt2.Font = Enum.Font.GothamBold
    opt1.Font = Enum.Font.GothamMedium
end)

local intRow = makeRow(configBody, 1)
intRow.Size = UDim2.new(1, 0, 0, 50)

local intLbl = Instance.new("TextLabel")
intLbl.Size = UDim2.new(0.6, 0, 0, 18)
intLbl.BackgroundTransparency = 1
intLbl.Text = "Spin Interval"
intLbl.TextColor3 = T.text
intLbl.Font = Enum.Font.GothamMedium
intLbl.TextSize = 13
intLbl.TextXAlignment = Enum.TextXAlignment.Left
intLbl.Parent = intRow

local intVal = Instance.new("TextLabel")
intVal.Size = UDim2.new(0.4, 0, 0, 18)
intVal.BackgroundTransparency = 1
intVal.Text = "0.8s"
intVal.TextColor3 = T.accent
intVal.Font = Enum.Font.GothamBold
intVal.TextSize = 13
intVal.TextXAlignment = Enum.TextXAlignment.Right
intVal.Parent = intRow

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, 0, 0, 4)
sliderTrack.Position = UDim2.new(0, 0, 0, 28)
sliderTrack.BackgroundColor3 = T.elevated
sliderTrack.BorderSizePixel = 0
corner(sliderTrack, 2)
stroke(sliderTrack, T.border, 1)
sliderTrack.Parent = intRow

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.27, 0, 1, 0)
sliderFill.BackgroundColor3 = T.accent
sliderFill.BorderSizePixel = 0
corner(sliderFill, 2)
sliderFill.Parent = sliderTrack

local sliderThumb = Instance.new("Frame")
sliderThumb.Size = UDim2.new(0, 14, 0, 14)
sliderThumb.AnchorPoint = Vector2.new(0.5, 0.5)
sliderThumb.Position = UDim2.new(0.27, 0, 0.5, 0)
sliderThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderThumb.BorderSizePixel = 0
corner(sliderThumb, 7)
sliderThumb.ZIndex = 2
sliderThumb.Parent = sliderTrack

local sliderDragging = false
sliderTrack.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        sliderDragging = true
    end
end)
sliderTrack.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        sliderDragging = false
    end
end)
sliderTrack.InputChanged:Connect(function(i)
    if sliderDragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local abs = sliderTrack.AbsolutePosition
        local w   = sliderTrack.AbsoluteSize.X
        local x   = math.clamp(i.Position.X - abs.X, 0, w)
        local pct = x / w
        local interval = 0.3 + pct * 2.7
        State.interval = math.floor(interval * 10) / 10
        intVal.Text = State.interval .. "s"
        sliderFill.Size = UDim2.new(pct, 0, 1, 0)
        sliderThumb.Position = UDim2.new(pct, 0, 0.5, 0)
    end
end)

local PRESETS = {
    { name = "Recommended", rules = {
        { type = "attribute", attribute = "Legendary" },
        { type = "combo", stand = "Jotaro's Star Platinum", attribute = "Godly" },
        { type = "combo", stand = "Jotaro's Star Platinum", attribute = "Daemon" },
        { type = "combo", stand = "Jotaro's Star Platinum", attribute = "Invincible" },
        { type = "combo", stand = "Dio's The World", attribute = "Daemon" },
        { type = "combo", stand = "Dio's The World", attribute = "Godly" },
        { type = "combo", stand = "Dio's The World", attribute = "Invincible" },
        { type = "combo", stand = "Star Platinum OVA", attribute = "Invincible" },
        { type = "combo", stand = "Star Platinum OVA", attribute = "Daemon" },
        { type = "combo", stand = "Star Platinum OVA", attribute = "Godly" },
        { type = "combo", stand = "Putrid Whine", attribute = "Daemon" },
        { type = "combo", stand = "Putrid Whine", attribute = "Invincible" },
        { type = "combo", stand = "The World OVA", attribute = "Daemon" },
        { type = "combo", stand = "The World OVA", attribute = "Invincible" },
    }},
}

local excBody = makeSection("Exclusions", 3)

local excNote = Instance.new("TextLabel")
excNote.Size = UDim2.new(1, 0, 0, 30)
excNote.BackgroundTransparency = 1
excNote.Text = "Stop spinning when a result matches any rule below."
excNote.TextColor3 = T.textMuted
excNote.Font = Enum.Font.Gotham
excNote.TextSize = 11
excNote.TextWrapped = true
excNote.TextXAlignment = Enum.TextXAlignment.Left
excNote.LayoutOrder = 0
excNote.Parent = excBody

local TYPE_OPTIONS = {"Attribute", "Stand", "Stand + Attribute"}
local selectedType = "Attribute"

local typeBg = Instance.new("Frame")
typeBg.BackgroundColor3 = T.elevated
typeBg.BorderSizePixel = 0
corner(typeBg, 6)
stroke(typeBg, T.border)

local typeListLayout = Instance.new("UIListLayout")
typeListLayout.FillDirection = Enum.FillDirection.Horizontal
typeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
typeListLayout.Parent = typeBg

local typeButtons = {}
for i, opt in ipairs(TYPE_OPTIONS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#TYPE_OPTIONS, 0, 1, 0)
    btn.BackgroundColor3 = i == 1 and T.accent or Color3.fromRGB(0, 0, 0)
    btn.BackgroundTransparency = i == 1 and 0 or 1
    btn.Text = opt
    btn.TextColor3 = i == 1 and T.text or T.textMuted
    btn.Font = i == 1 and Enum.Font.GothamBold or Enum.Font.Gotham
    btn.TextSize = 9
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    btn.LayoutOrder = i
    corner(btn, 6)
    btn.Parent = typeBg
    typeButtons[opt] = btn
end

local DropdownOverlay = Instance.new("CanvasGroup")
DropdownOverlay.Size = UDim2.new(1, 0, 1, 0)
DropdownOverlay.BackgroundTransparency = 1
DropdownOverlay.BorderSizePixel = 0
DropdownOverlay.ZIndex = 100
DropdownOverlay.Interactable = false
DropdownOverlay.Parent = ScreenGui

local function makeDropdown(parent, placeholder, lOrder)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 30)
    container.BackgroundTransparency = 1
    container.LayoutOrder = lOrder
    container.ClipsDescendants = false
    container.Parent = parent

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(1, 0, 1, 0)
    box.BackgroundColor3 = T.elevated
    box.BorderSizePixel = 0
    box.TextColor3 = T.textDim
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.Text = placeholder
    box.Name = "Box"
    corner(box, 6)
    stroke(box, T.border)
    padding(box, 0, 10)
    box.Parent = container

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -24, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▾"
    arrow.TextColor3 = T.textDim
    arrow.Font = Enum.Font.Gotham
    arrow.TextSize = 12
    arrow.ZIndex = 2
    arrow.Parent = box

    local panel = Instance.new("Frame")
    panel.BackgroundColor3 = T.elevated
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Size = UDim2.new(0, 0, 0, 0)
    panel.Visible = false
    panel.ZIndex = 100
    corner(panel, 6)
    stroke(panel, T.border)
    panel.Parent = DropdownOverlay

    local ddScroll = Instance.new("ScrollingFrame")
    ddScroll.Size = UDim2.new(1, 0, 1, 0)
    ddScroll.BackgroundTransparency = 1
    ddScroll.BorderSizePixel = 0
    ddScroll.ScrollBarThickness = 2
    ddScroll.ScrollBarImageColor3 = T.accent
    ddScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ddScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ddScroll.ClipsDescendants = true
    ddScroll.ZIndex = 100
    ddScroll.Parent = panel

    local ddList = Instance.new("UIListLayout")
    ddList.Padding = UDim.new(0, 1)
    ddList.SortOrder = Enum.SortOrder.LayoutOrder
    ddList.Parent = ddScroll
    padding(ddScroll, 4, 6)

    local selected = nil
    local open = false
    local onSelect = nil

    local function getPosition()
        local boxAbs = box.AbsolutePosition
        local boxSz  = box.AbsoluteSize
        local scrSz  = ScreenGui.AbsoluteSize
        local w      = boxSz.X
        local h      = panel.AbsoluteSize.Y > 0 and panel.AbsoluteSize.Y or math.min(#ddList:GetChildren() * 27 + 8, 200)
        local spaceBelow = scrSz.Y - (boxAbs.Y + boxSz.Y + 4)
        local posY = spaceBelow >= h
            and (boxAbs.Y + boxSz.Y + 4)
            or  (boxAbs.Y - h - 4)
        return boxAbs.X, posY, w
    end

    local function closeDropdown()
        open = false
        tween(panel, {Size = UDim2.new(0, panel.AbsoluteSize.X, 0, 0)}, 0.12)
        task.delay(0.12, function()
            panel.Visible = false
            DropdownOverlay.Interactable = false
        end)
    end

    local function openDropdown()
        open = true
        DropdownOverlay.Interactable = true
        local x, posY, w = getPosition()
        local h = math.min(math.max(#ddList:GetChildren(), 1) * 27 + 8, 200)
        panel.Position = UDim2.new(0, x, 0, posY)
        panel.Size = UDim2.new(0, w, 0, 0)
        panel.Visible = true
        tween(panel, {Size = UDim2.new(0, w, 0, h)}, 0.12)
    end

    Content.ChildAdded:Connect(function() end)
    Content:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if not open then return end
        local x, posY, w = getPosition()
        panel.Position = UDim2.new(0, x, 0, posY)
    end)

    box.MouseButton1Click:Connect(function()
        if open then closeDropdown() else openDropdown() end
    end)

    local function populate(items)
        for _, c in ipairs(ddScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, item in ipairs(items) do
            local opt = Instance.new("TextButton")
            opt.Size = UDim2.new(1, 0, 0, 26)
            opt.BackgroundTransparency = 1
            opt.Text = item
            opt.TextColor3 = T.textMuted
            opt.Font = Enum.Font.Gotham
            opt.TextSize = 11
            opt.TextXAlignment = Enum.TextXAlignment.Left
            opt.LayoutOrder = i
            opt.ZIndex = 101
            padding(opt, 0, 8)
            opt.Parent = ddScroll
            opt.MouseEnter:Connect(function()
                opt.BackgroundColor3 = T.accent
                tween(opt, {BackgroundTransparency = 0.85})
            end)
            opt.MouseLeave:Connect(function()
                tween(opt, {BackgroundTransparency = 1})
            end)
            opt.MouseButton1Click:Connect(function()
                selected = item
                box.Text = item
                box.TextColor3 = T.text
                closeDropdown()
                if onSelect then onSelect(item) end
            end)
        end
        if open then
            panel.Size = UDim2.new(0, panel.AbsoluteSize.X, 0, math.min(#items * 27 + 8, 200))
        end
    end

    local function getSelected() return selected end
    local function setOnSelect(fn) onSelect = fn end
    local function reset()
        selected = nil
        box.Text = placeholder
        box.TextColor3 = T.textDim
        closeDropdown()
    end

    return {
        container   = container,
        populate    = populate,
        getSelected = getSelected,
        setOnSelect = setOnSelect,
        reset       = reset,
        close       = closeDropdown,
    }
end

local typeRow = makeRow(excBody, 2)
typeRow.Size = UDim2.new(1, 0, 0, 30)

local typeLbl = Instance.new("TextLabel")
typeLbl.Size = UDim2.new(0.3, 0, 1, 0)
typeLbl.BackgroundTransparency = 1
typeLbl.Text = "Rule type"
typeLbl.TextColor3 = T.textMuted
typeLbl.Font = Enum.Font.Gotham
typeLbl.TextSize = 11
typeLbl.TextXAlignment = Enum.TextXAlignment.Left
typeLbl.Parent = typeRow

typeBg.Size = UDim2.new(0.68, 0, 1, 0)
typeBg.Position = UDim2.new(0.32, 0, 0, 0)
typeBg.Parent = typeRow

local attrDD  = makeDropdown(excBody, "Select attribute...", 3)
local standDD = makeDropdown(excBody, "Select stand...", 4)
standDD.container.Visible = false

local function setType(t)
    selectedType = t
    for opt, btn in pairs(typeButtons) do
        local active = opt == t
        tween(btn, {BackgroundColor3 = active and T.accent or Color3.fromRGB(0, 0, 0)})
        btn.BackgroundTransparency = active and 0 or 1
        tween(btn, {TextColor3 = active and T.text or T.textMuted})
        btn.Font = active and Enum.Font.GothamBold or Enum.Font.Gotham
    end
    attrDD.container.Visible  = (t == "Attribute" or t == "Stand + Attribute")
    standDD.container.Visible = (t == "Stand"     or t == "Stand + Attribute")
    attrDD.reset()
    standDD.reset()
end

for opt, btn in pairs(typeButtons) do
    btn.MouseButton1Click:Connect(function() setType(opt) end)
end

local addBtn = Instance.new("TextButton")
addBtn.Size = UDim2.new(1, 0, 0, 30)
addBtn.BackgroundColor3 = T.elevated
addBtn.Text = "+ Add Exclusion"
addBtn.TextColor3 = T.accent
addBtn.Font = Enum.Font.GothamBold
addBtn.TextSize = 12
addBtn.BorderSizePixel = 0
addBtn.LayoutOrder = 5
corner(addBtn, 6)
stroke(addBtn, T.accent)
addBtn.Parent = excBody
hoverButton(addBtn, T.elevated, Color3.fromRGB(35, 35, 50))

local excListFrame = Instance.new("Frame")
excListFrame.Size = UDim2.new(1, 0, 0, 0)
excListFrame.AutomaticSize = Enum.AutomaticSize.Y
excListFrame.BackgroundTransparency = 1
excListFrame.LayoutOrder = 6
excListFrame.Parent = excBody

local excListLayout = Instance.new("UIListLayout")
excListLayout.Padding = UDim.new(0, 4)
excListLayout.SortOrder = Enum.SortOrder.LayoutOrder
excListLayout.Parent = excListFrame

local excCount = 0

local function addExclusionTag(exc)
    excCount = excCount + 1

    local tagLabel
    if exc.type == "attribute" then
        tagLabel = "Attr: " .. exc.attribute
    elseif exc.type == "stand" then
        tagLabel = "Stand: " .. exc.stand
    else
        tagLabel = exc.stand .. "  +  " .. exc.attribute
    end

    local tag = Instance.new("Frame")
    tag.Size = UDim2.new(1, 0, 0, 28)
    tag.BackgroundColor3 = T.elevated
    tag.BorderSizePixel = 0
    tag.LayoutOrder = excCount
    corner(tag, 6)
    stroke(tag, T.border)
    tag.Parent = excListFrame

    local pip = Instance.new("Frame")
    pip.Size = UDim2.new(0, 3, 0, 16)
    pip.Position = UDim2.new(0, 0, 0.5, -8)
    pip.BackgroundColor3 = exc.type == "attribute" and T.warning
                        or exc.type == "stand"     and Color3.fromRGB(99, 210, 180)
                        or T.accent
    pip.BorderSizePixel = 0
    corner(pip, 2)
    pip.Parent = tag

    local tagLbl = Instance.new("TextLabel")
    tagLbl.Size = UDim2.new(1, -40, 1, 0)
    tagLbl.Position = UDim2.new(0, 10, 0, 0)
    tagLbl.BackgroundTransparency = 1
    tagLbl.Text = tagLabel
    tagLbl.TextColor3 = T.text
    tagLbl.Font = Enum.Font.GothamMedium
    tagLbl.TextSize = 11
    tagLbl.TextXAlignment = Enum.TextXAlignment.Left
    tagLbl.Parent = tag

    local removeBtn = Instance.new("TextButton")
    removeBtn.Size = UDim2.new(0, 28, 1, 0)
    removeBtn.Position = UDim2.new(1, -28, 0, 0)
    removeBtn.BackgroundTransparency = 1
    removeBtn.Text = "✕"
    removeBtn.TextColor3 = T.textDim
    removeBtn.Font = Enum.Font.GothamBold
    removeBtn.TextSize = 11
    removeBtn.Parent = tag

    removeBtn.MouseEnter:Connect(function() tween(removeBtn, {TextColor3 = T.danger}) end)
    removeBtn.MouseLeave:Connect(function() tween(removeBtn, {TextColor3 = T.textDim}) end)
    removeBtn.MouseButton1Click:Connect(function()
        for i, e in ipairs(State.exclusions) do
            if e == exc then
                table.remove(State.exclusions, i)
                break
            end
        end
        tag:Destroy()
    end)
end

addBtn.MouseButton1Click:Connect(function()
    local exc = {}
    if selectedType == "Attribute" then
        local attr = attrDD.getSelected()
        if not attr then return end
        exc = { type = "attribute", attribute = attr }
    elseif selectedType == "Stand" then
        local stand = standDD.getSelected()
        if not stand then return end
        exc = { type = "stand", stand = stand }
    else
        local attr  = attrDD.getSelected()
        local stand = standDD.getSelected()
        if not attr or not stand then return end
        exc = { type = "combo", stand = stand, attribute = attr }
    end
    table.insert(State.exclusions, exc)
    addExclusionTag(exc)
    attrDD.reset()
    standDD.reset()
end)

task.spawn(function()
    local attrs = getAllAttributes()
    if #attrs == 0 then
        attrs = {"Legendary", "Daemon", "Godly", "Invincible"}
    end
    attrDD.populate(attrs)

    local stands = getAllAbilities()
    if #stands == 0 then
        stands = {"Star Platinum", "The World", "Crazy Diamond", "Gold Experience", "King Crimson"}
    end
    standDD.populate(stands)
end)

local presetDD = makeDropdown(excBody, "Load a preset...", 1)

do
    local presetNames = {}
    for _, p in ipairs(PRESETS) do table.insert(presetNames, p.name) end
    presetDD.populate(presetNames)
end

presetDD.setOnSelect(function(name)
    for _, preset in ipairs(PRESETS) do
        if preset.name == name then
            for _, child in ipairs(excListFrame:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            State.exclusions = {}
            excCount = 0
            for _, rule in ipairs(preset.rules) do
                table.insert(State.exclusions, rule)
                addExclusionTag(rule)
            end
            break
        end
    end
    presetDD.reset()
end)

local ctrlBody = makeSection("Controls", 5)
ctrlBody.Parent.LayoutOrder = 5

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, 0, 0, 42)
startBtn.BackgroundColor3 = T.accent
startBtn.Text = "Start Auto Spin"
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 14
startBtn.BorderSizePixel = 0
startBtn.LayoutOrder = 0
corner(startBtn, 8)
startBtn.Parent = ctrlBody
hoverButton(startBtn, T.accent, T.accentHov)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(1, 0, 0, 36)
stopBtn.BackgroundColor3 = T.elevated
stopBtn.Text = "Stop"
stopBtn.TextColor3 = T.textMuted
stopBtn.Font = Enum.Font.GothamMedium
stopBtn.TextSize = 13
stopBtn.BorderSizePixel = 0
stopBtn.LayoutOrder = 1
corner(stopBtn, 8)
stroke(stopBtn, T.border)
stopBtn.Parent = ctrlBody
hoverButton(stopBtn, T.elevated, T.border)

local function updateUI()
    arrowCountLabel.Text = tostring(getItemCount(State.arrowType))
    rokaCountLabel.Text  = tostring(getItemCount("Rokakaka"))
    spinCountLabel.Text  = tostring(State.spinCount)
    standVal.Text = getCurrentStand()
    attrVal.Text  = getCurrentAttribute()
    StatusLabel.Text = State.status
    if State.running then
        tween(StatusDot, {BackgroundColor3 = T.success})
        tween(StatusLabel, {TextColor3 = T.success})
        startBtn.Text = "Running..."
        startBtn.Active = false
        tween(startBtn, {BackgroundColor3 = T.elevated})
        tween(startBtn, {TextColor3 = T.textMuted})
    else
        local isErr = State.status:find("Out of") or State.status:find("Excluded")
        local dotColor = isErr and T.warning or T.textDim
        tween(StatusDot, {BackgroundColor3 = dotColor})
        tween(StatusLabel, {TextColor3 = isErr and T.warning or T.textMuted})
        startBtn.Text = "Start Auto Spin"
        startBtn.Active = true
        tween(startBtn, {BackgroundColor3 = T.accent})
        tween(startBtn, {TextColor3 = Color3.fromRGB(255, 255, 255)})
    end
end

startBtn.MouseButton1Click:Connect(function()
    if not State.running then
        startSpin(updateUI)
    end
end)

stopBtn.MouseButton1Click:Connect(function()
    if State.running then
        stopSpin("Stopped by user", false)
        updateUI()
    end
end)

local minimized = false
local fullHeight = WIN_H
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(Window, {Size = UDim2.new(0, WIN_W, 0, 50)}, 0.2)
        Content.Visible = false
        Divider.Visible = false
        MinBtn.Text = "+"
    else
        Content.Visible = true
        Divider.Visible = true
        tween(Window, {Size = UDim2.new(0, WIN_W, 0, fullHeight)}, 0.2)
        MinBtn.Text = "—"
    end
end)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 110, 0, 32)
ToggleBtn.Position = UDim2.new(1, -120, 1, -44)
ToggleBtn.BackgroundColor3 = T.surface
ToggleBtn.Text = "Auto Spin  [RShift]"
ToggleBtn.TextColor3 = T.textMuted
ToggleBtn.Font = Enum.Font.GothamMedium
ToggleBtn.TextSize = 10
ToggleBtn.BorderSizePixel = 0
ToggleBtn.ZIndex = 10
corner(ToggleBtn, 8)
stroke(ToggleBtn, T.border)
ToggleBtn.Parent = ScreenGui
hoverButton(ToggleBtn, T.surface, T.elevated)

local guiVisible = true
local function toggleGui()
    guiVisible = not guiVisible
    Window.Visible = guiVisible
    tween(ToggleBtn, {BackgroundColor3 = guiVisible and T.elevated or T.surface})
    tween(ToggleBtn, {TextColor3 = guiVisible and T.text or T.textMuted})
end

ToggleBtn.MouseButton1Click:Connect(toggleGui)

game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        toggleGui()
    end
end)

RunService.Heartbeat:Connect(function()
    if not ScreenGui.Parent then return end
    arrowCountLabel.Text = tostring(getItemCount(State.arrowType))
    rokaCountLabel.Text  = tostring(getItemCount("Rokakaka"))
    standVal.Text = getCurrentStand()
    attrVal.Text  = getCurrentAttribute()
    spinCountLabel.Text = tostring(State.spinCount)
end)

updateUI()
