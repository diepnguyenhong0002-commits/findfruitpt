-- [[ DUC CUONG MODDER (Find Fruit) - V64 FINAL - FILE + _G BACKUP ]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

-- =========================
-- CONFIG
-- =========================
getgenv().Config = {
    Settings = {
        AutoRandomFruit = true,
        RandomDelay = 3,
        MaxPing = 1000,    -- Bỏ qua server ping cao hơn mức này (ms)
        MinFPS = 50,       -- Bỏ qua server FPS thấp hơn mức này
    }
}

-- =========================
-- VISITED SERVERS
-- Ưu tiên: FILE → _G backup → rỗng
-- Lưu cả 2 nơi để đảm bảo không mất blacklist khi teleport
-- =========================
local SAVE_FILE = "find_fruit_visited.json"

local function loadVisited()
    -- Thử đọc từ file
    local ok, result = pcall(function()
        if isfile and isfile(SAVE_FILE) then
            local raw = readfile(SAVE_FILE)
            return HttpService:JSONDecode(raw)
        end
        return {}
    end)
    if ok and type(result) == "table" and #result > 0 then
        warn("[Visited] Loaded " .. #result .. " servers tu FILE.")
        -- Đồng bộ vào _G
        _G.VisitedBackup = result
        return result
    end

    -- Fallback: đọc từ _G nếu file lỗi hoặc trống
    if type(_G.VisitedBackup) == "table" and #_G.VisitedBackup > 0 then
        warn("[Visited] Loaded " .. #_G.VisitedBackup .. " servers tu _G backup.")
        return _G.VisitedBackup
    end

    warn("[Visited] Khong co du lieu cu, bat dau moi.")
    return {}
end

local function saveVisited(list)
    -- Lưu _G trước (luôn hoạt động)
    _G.VisitedBackup = list
    -- Lưu file (nếu executor hỗ trợ)
    pcall(function()
        if writefile then
            writefile(SAVE_FILE, HttpService:JSONEncode(list))
        end
    end)
end

-- Khởi tạo danh sách
local VisitedServers = loadVisited()

-- Blacklist server hiện tại
local function blacklistCurrent()
    if game.JobId and game.JobId ~= "" then
        if not table.find(VisitedServers, game.JobId) then
            table.insert(VisitedServers, game.JobId)
            saveVisited(VisitedServers)
            warn("[Visited] Blacklisted current: " .. game.JobId .. " | Total: " .. #VisitedServers)
        end
    end
end

blacklistCurrent()

-- =========================
-- CONSTANTS
-- =========================
local PLACE_ID = 2753915549
local teamReady = false
local randomReady = true
local isHopping = false
local hopRetryCount = 0
local MAX_HOP_RETRIES = 50

-- =========================
-- UI
-- =========================
-- Xóa GUI cũ nếu còn sót
pcall(function()
    if game:GetService("CoreGui"):FindFirstChild("FindFruitGui") then
        game:GetService("CoreGui"):FindFirstChild("FindFruitGui"):Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name = "FindFruitGui"
ScreenGui.ResetOnSpawn = false

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 270, 0, 280)
Main.Position = UDim2.new(0.5, -135, 0.4, -140)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(0, 255, 127)
stroke.Thickness = 1.5

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.Text = "PORTAL Modder — Find Fruit"
Title.TextColor3 = Color3.fromRGB(0, 255, 127)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.BackgroundTransparency = 1

local PlayerName = Instance.new("TextLabel", Main)
PlayerName.Size = UDim2.new(1, -10, 0, 22)
PlayerName.Position = UDim2.new(0, 5, 0, 42)
PlayerName.Text = "👤 Player: " .. LocalPlayer.Name
PlayerName.TextColor3 = Color3.fromRGB(200, 200, 200)
PlayerName.Font = Enum.Font.GothamMedium
PlayerName.TextSize = 12
PlayerName.BackgroundTransparency = 1
PlayerName.TextXAlignment = Enum.TextXAlignment.Left

local JobLabel = Instance.new("TextLabel", Main)
JobLabel.Size = UDim2.new(1, -10, 0, 20)
JobLabel.Position = UDim2.new(0, 5, 0, 65)
JobLabel.Text = "🌐 Server: " .. (game.JobId ~= "" and game.JobId:sub(1, 18) .. "..." or "N/A")
JobLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
JobLabel.Font = Enum.Font.Gotham
JobLabel.TextSize = 10
JobLabel.BackgroundTransparency = 1
JobLabel.TextXAlignment = Enum.TextXAlignment.Left

local BlacklistLabel = Instance.new("TextLabel", Main)
BlacklistLabel.Size = UDim2.new(1, -10, 0, 20)
BlacklistLabel.Position = UDim2.new(0, 5, 0, 87)
BlacklistLabel.Text = "🚫 Blacklist: " .. #VisitedServers .. " servers"
BlacklistLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
BlacklistLabel.Font = Enum.Font.GothamMedium
BlacklistLabel.TextSize = 11
BlacklistLabel.BackgroundTransparency = 1
BlacklistLabel.TextXAlignment = Enum.TextXAlignment.Left

local HopCount = Instance.new("TextLabel", Main)
HopCount.Size = UDim2.new(1, -10, 0, 20)
HopCount.Position = UDim2.new(0, 5, 0, 108)
HopCount.Text = "🔁 Hop lan: 0"
HopCount.TextColor3 = Color3.fromRGB(150, 200, 255)
HopCount.Font = Enum.Font.GothamMedium
HopCount.TextSize = 11
HopCount.BackgroundTransparency = 1
HopCount.TextXAlignment = Enum.TextXAlignment.Left

local Status = Instance.new("TextLabel", Main)
Status.Size = UDim2.new(0.92, 0, 0, 120)
Status.Position = UDim2.new(0.04, 0, 0, 135)
Status.Text = "Status: Dang khoi dong..."
Status.TextColor3 = Color3.fromRGB(0, 255, 255)
Status.Font = Enum.Font.GothamBold
Status.TextSize = 12
Status.TextWrapped = true
Status.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
Instance.new("UICorner", Status).CornerRadius = UDim.new(0, 8)

-- =========================
-- UI HELPERS
-- =========================
local function setStatus(text, color)
    Status.Text = "Status: " .. text
    Status.TextColor3 = color or Color3.fromRGB(0, 255, 255)
end

local function updateUI()
    BlacklistLabel.Text = "🚫 Blacklist: " .. #VisitedServers .. " servers"
    HopCount.Text = "🔁 Hop lan: " .. hopRetryCount
end

local function countdown(seconds, label)
    for i = seconds, 1, -1 do
        setStatus(label .. " (" .. i .. "s)", Color3.fromRGB(180, 180, 180))
        task.wait(1)
    end
end

-- =========================
-- ANTI AFK
-- =========================
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local FastHop

-- =========================
-- TELEPORT FAILSAFE
-- =========================
TeleportService.TeleportInitFailed:Connect(function(_, reason)
    warn("[Teleport] Loi: " .. tostring(reason))
    setStatus("Teleport loi (" .. tostring(reason) .. "), thu lai...", Color3.fromRGB(255, 100, 100))
    isHopping = false
    task.wait(3)
    if FastHop then FastHop() end
end)

-- =========================
-- AUTO JOIN PIRATES
-- =========================
task.spawn(function()
    for attempt = 1, 10 do
        task.wait(2)
        pcall(function()
            if not LocalPlayer.Team or LocalPlayer.Team.Name ~= "Pirates" then
                setStatus("Dang chon Hai Tac (lan " .. attempt .. ")...", Color3.fromRGB(255, 200, 0))
                ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", "Pirates")
            end
        end)
        if LocalPlayer.Team and LocalPlayer.Team.Name == "Pirates" then
            countdown(5, "Da chon Hai Tac! Cho")
            teamReady = true
            return
        end
    end
    setStatus("Khong vao duoc phe, tiep tuc...", Color3.fromRGB(200, 200, 200))
    teamReady = true
end)

-- =========================
-- AUTO RANDOM FRUIT
-- =========================
task.spawn(function()
    while task.wait(getgenv().Config.Settings.RandomDelay) do
        if getgenv().Config.Settings.AutoRandomFruit and not isHopping then
            pcall(function()
                setStatus("Dang random fruit...", Color3.fromRGB(150, 200, 255))
                local result = ReplicatedStorage.Remotes.CommF_:InvokeServer("Cousin", "Buy")
                if result and type(result) == "string"
                    and result ~= "" and result ~= "nil" and result ~= "false"
                then
                    setStatus("Random duoc: " .. result .. "!", Color3.fromRGB(0, 255, 127))
                else
                    setStatus("Random khong ra trai", Color3.fromRGB(160, 160, 160))
                end
            end)
            randomReady = false
            countdown(3, "Cho sau random")
            randomReady = true
        end
    end
end)

-- =========================
-- PARSE SERVER LIST
-- Hỗ trợ: { data:[] } | { servers:[] } | []
-- =========================
local function parseServerList(data)
    if type(data) ~= "table" then return nil end
    if type(data.data) == "table" then return data.data end
    if type(data.servers) == "table" then return data.servers end
    if data[1] ~= nil then return data end
    return nil
end

-- =========================
-- FAST HOP - FINAL
-- =========================
FastHop = function()
    hopRetryCount = hopRetryCount + 1
    updateUI()

    if hopRetryCount > MAX_HOP_RETRIES then
        setStatus("Qua " .. MAX_HOP_RETRIES .. " lan hop, dung lai.", Color3.fromRGB(255, 50, 50))
        return
    end

    isHopping = true

    -- Chờ sẵn sàng
    while not teamReady do
        setStatus("Cho chon phe...", Color3.fromRGB(255, 200, 0))
        task.wait(0.5)
    end
    while not randomReady do
        setStatus("Cho sau random...", Color3.fromRGB(255, 200, 0))
        task.wait(0.5)
    end

    -- Blacklist server hiện tại trước khi hop
    blacklistCurrent()
    updateUI()

    setStatus(
        "Tim server... (lan " .. hopRetryCount .. " | blacklist: " .. #VisitedServers .. ")",
        Color3.fromRGB(255, 100, 100)
    )
    task.wait(0.5)

    local ok, err = pcall(function()
        -- Gọi API
        local response = game:HttpGet("https://hop.diepnguyenhong0002.workers.dev/")

        if not response or response == "" then
            warn("[FastHop] API tra ve response rong.")
            setStatus("API rong, thu lai 3s...", Color3.fromRGB(255, 100, 0))
            isHopping = false
            task.wait(3)
            FastHop()
            return
        end

        -- Parse JSON
        local data
        local parseOk, parseErr = pcall(function()
            data = HttpService:JSONDecode(response)
        end)
        if not parseOk or not data then
            warn("[FastHop] JSON parse loi: " .. tostring(parseErr))
            setStatus("JSON loi, thu lai 3s...", Color3.fromRGB(255, 100, 0))
            isHopping = false
            task.wait(3)
            FastHop()
            return
        end

        -- Lấy danh sách server (hỗ trợ nhiều format)
        local servers = parseServerList(data)
        if not servers or #servers == 0 then
            warn("[FastHop] Khong parse duoc server list. Response: " .. response:sub(1, 150))
            setStatus("Khong lay duoc danh sach server, thu lai 5s...", Color3.fromRGB(255, 200, 0))
            isHopping = false
            task.wait(5)
            FastHop()
            return
        end

        warn("[FastHop] Nhan duoc " .. #servers .. " servers.")

        -- Sắp xếp ping tăng dần
        table.sort(servers, function(a, b)
            return (a.ping or 9999) < (b.ping or 9999)
        end)

        local foundServer = false
        local skippedBlacklist = 0
        local skippedPing = 0
        local skippedFPS = 0
        local skippedFull = 0

        for _, server in pairs(servers) do
            -- Bỏ qua nếu thiếu thông tin cơ bản
            if not server.id or server.id == "" or server.id == game.JobId then
                continue
            end

            -- Bỏ qua nếu đã vào rồi
            if table.find(VisitedServers, server.id) then
                skippedBlacklist = skippedBlacklist + 1
                continue
            end

            -- Bỏ qua nếu server đầy
            if type(server.playing) ~= "number" or type(server.maxPlayers) ~= "number"
                or server.playing >= server.maxPlayers
            then
                skippedFull = skippedFull + 1
                continue
            end

            -- Bỏ qua ping quá cao
            if server.ping and server.ping > getgenv().Config.Settings.MaxPing then
                skippedPing = skippedPing + 1
                continue
            end

            -- Bỏ qua FPS quá thấp
            if server.fps and server.fps < getgenv().Config.Settings.MinFPS then
                skippedFPS = skippedFPS + 1
                continue
            end

            -- ✅ Server hợp lệ → blacklist + teleport
            foundServer = true

            table.insert(VisitedServers, server.id)

            -- Giữ tối đa 500, nhưng không xóa server hiện tại
            while #VisitedServers > 500 do
                local removed = table.remove(VisitedServers, 1)
                if removed == game.JobId then
                    table.insert(VisitedServers, game.JobId)
                end
            end

            saveVisited(VisitedServers)
            updateUI()

            local pingStr = server.ping and (" | ping: " .. server.ping .. "ms") or " | ping: N/A"
            local fpsStr = server.fps and (" | fps: " .. math.floor(server.fps)) or ""
            warn("[FastHop] → " .. server.id .. pingStr .. fpsStr)

            setStatus(
                "Dang vao server!\n"
                .. server.playing .. "/" .. server.maxPlayers .. " players"
                .. pingStr .. fpsStr,
                Color3.fromRGB(0, 255, 127)
            )

            task.wait(0.5)
            TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer)
            return
        end

        -- Không tìm được server phù hợp
        if not foundServer then
            warn("[FastHop] Het server."
                .. " blacklist=" .. skippedBlacklist
                .. " full=" .. skippedFull
                .. " ping=" .. skippedPing
                .. " fps=" .. skippedFPS
            )
            setStatus(
                "Het server hop duoc!\n"
                .. "blacklist:" .. skippedBlacklist
                .. " full:" .. skippedFull
                .. " ping:" .. skippedPing
                .. "\nCho 10s roi thu lai...",
                Color3.fromRGB(255, 200, 0)
            )
            isHopping = false
            task.wait(10)
            hopRetryCount = 0
            FastHop()
        end
    end)

    if not ok then
        warn("[FastHop] Error: " .. tostring(err))
        setStatus("Loi: " .. tostring(err):sub(1, 60) .. "\nThu lai 3s...", Color3.fromRGB(255, 50, 50))
        isHopping = false
        task.wait(3)
        FastHop()
    end
end

-- =========================
-- CHECK DROPPED FRUIT
-- =========================
local function isDroppedFruit(tool)
    if not tool:IsA("Tool") then return false end
    if not tool:FindFirstChild("Handle") then return false end
    local parent = tool.Parent
    if parent == nil then return false end
    if parent:IsA("Backpack") then return false end
    if parent:FindFirstChildOfClass("Humanoid") then return false end
    if parent:FindFirstChildOfClass("AnimationController") then return false end
    return parent == workspace
        or (parent:IsA("Model") and parent.Parent == workspace)
        or (parent:IsA("Folder") and parent.Parent == workspace)
end

-- =========================
-- GET FRUITS
-- =========================
local function getFruits()
    local fruits = {}
    for _, v in pairs(workspace:GetChildren()) do
        if isDroppedFruit(v) then
            table.insert(fruits, v)
        end
        if v:IsA("Model") or v:IsA("Folder") then
            for _, child in pairs(v:GetChildren()) do
                if isDroppedFruit(child) then
                    table.insert(fruits, child)
                end
            end
        end
    end
    return fruits
end

-- =========================
-- COLLECT FRUIT
-- =========================
local function collectFruit(tool)
    if not tool or not tool.Parent then return end
    if not tool:FindFirstChild("Handle") then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local hrp = char.HumanoidRootPart
    local handle = tool.Handle

    setStatus("Nhat: " .. tool.Name, Color3.fromRGB(0, 255, 127))

    hrp.CFrame = handle.CFrame + Vector3.new(0, 1.5, 0)

    for _ = 1, 5 do
        if not tool or not tool.Parent or not tool:FindFirstChild("Handle") then break end
        pcall(function()
            firetouchinterest(hrp, handle, 0)
            firetouchinterest(hrp, handle, 1)
        end)
        task.wait(0.1)
    end
    task.wait(0.5)
end

-- =========================
-- MAIN LOOP
-- =========================
task.spawn(function()
    while not teamReady do task.wait(0.5) end

    setStatus("San sang! Bat dau tim fruit...", Color3.fromRGB(0, 255, 127))

    while task.wait(1) do
        local shouldHop = false
        pcall(function()
            local fruits = getFruits()
            if #fruits > 0 then
                hopRetryCount = 0
                isHopping = false
                for _, tool in pairs(fruits) do
                    collectFruit(tool)
                    task.wait(0.4)
                end
            else
                setStatus("Khong co fruit, chuan bi hop...", Color3.fromRGB(200, 200, 200))
                task.wait(1.5)
                shouldHop = true
            end
        end)
        if shouldHop then
            FastHop()
            break
        end
    end
end)
