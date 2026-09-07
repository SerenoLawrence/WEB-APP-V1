--[[
    Steal An Egg — Auto Farm  (No Key, Open Source)
    Real functions confirmed from poccwo.lua + Roblox DevForum

    STEAL MODES:
      NORMAL   → safe step movement, guard avoidance, corridor entry
      INSTANT  → direct CFrame TP to egg → carry remote → TP to base

    WALK MODES (auto-selected based on ping/FPS, or manual):
      GROUND   → Humanoid.WalkSpeed boost (real: hum.WalkSpeed = n)
                 Persists across respawn via CharacterAdded
      PHANTOM  → Noclip: RunService.Heartbeat sets all BasePart.CanCollide=false
                 Real: confirmed from universal noclip scripts
      TWEEN    → RenderStepped lerp on HumanoidRootPart.CFrame toward target
                 Real: avoids TweenService direct HRP issue (physics breakage)
                 Source: Roblox DevForum thread on tweening HRP

    PING/FPS:
      Ping → LocalPlayer:GetNetworkPing() * 1000  (official Roblox API, C++ native)
      FPS  → RenderStepped frame counter per second (DevForum confirmed method)

    AUTO MODE SELECTION:
      FPS < 20 or Ping > 300ms → INSTANT steal (skip movement entirely)
      FPS 20-45 or Ping 150-300ms → TWEEN walk (smooth lerp)
      FPS >= 45 and Ping < 150ms → GROUND walk (normal speed boost)
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local VirtualUser      = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local USER_ID     = LocalPlayer.UserId
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- STATE
-- ============================================================
local AUTO       = false
local INSTANT    = false   -- instant TP steal mode
local BUSY       = false
local LAST       = "ready"

-- Walk mode: "GROUND" | "PHANTOM" | "TWEEN" | "AUTO"
local WALK_MODE  = "AUTO"
local WALK_SPEED = 60       -- studs/s for GROUND and TWEEN modes

-- ============================================================
-- REAL PING / FPS  (confirmed APIs)
-- ============================================================
-- Ping: LocalPlayer:GetNetworkPing() — official Roblox function, returns seconds
-- multiply by 1000 for milliseconds
-- Source: Roblox API docs + DevForum /t/pingfps-displayer/1670037
local function getPing()
    local ok, val = pcall(function()
        return math.floor(LocalPlayer:GetNetworkPing() * 1000)
    end)
    return ok and val or 0
end

-- FPS: count RenderStepped fires per second
-- Source: DevForum /t/pingfps-displayer/1670037
local _fpsCounter = 0
local _currentFPS = 60
RunService.RenderStepped:Connect(function()
    _fpsCounter = _fpsCounter + 1
end)
task.spawn(function()
    while true do
        task.wait(1)
        _currentFPS = _fpsCounter
        _fpsCounter  = 0
    end
end)

local function getFPS()
    return _currentFPS
end

-- Auto-pick best walk mode based on current performance
local function autoWalkMode()
    local ping = getPing()
    local fps  = getFPS()
    if fps < 20 or ping > 300 then
        return "INSTANT"   -- too laggy — just TP
    elseif fps < 45 or ping > 150 then
        return "TWEEN"     -- mid — smooth lerp
    else
        return "GROUND"    -- good connection — walk speed boost
    end
end

-- ============================================================
-- NOCLIP / PHANTOM WALK
-- Real source: RunService.Heartbeat + BasePart.CanCollide = false
-- Confirmed from: github.com/Not-Kyle/Universal-Scripts.lua/Noclip.lua
--                 github.com/zxciaz/Universal-Scripts/NoClip
-- ============================================================
local _noclipConn = nil
local _noclipEnabled = false

local function setNoclip(enabled)
    _noclipEnabled = enabled
    if enabled and not _noclipConn then
        _noclipConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    elseif not enabled and _noclipConn then
        _noclipConn:Disconnect()
        _noclipConn = nil
        -- Restore collision on HRP and main parts
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Auto re-enable noclip after respawn if phantom mode active
LocalPlayer.CharacterAdded:Connect(function()
    if _noclipEnabled then
        task.wait(0.3)
        setNoclip(true)
    end
end)

-- ============================================================
-- GROUND SPEED BOOST
-- Real source: Humanoid.WalkSpeed property (Roblox engine)
-- Confirmed: github.com/AgentZer00/a13dadf347b5b0da331a71f65cf36954
-- Persists across respawn via CharacterAdded
-- ============================================================
local _speedEnabled = false
local _speedValue   = WALK_SPEED

local function applySpeed(speed)
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = speed
        hum.UseJumpPower = true   -- real Humanoid property
        hum.JumpPower    = 50
    end
end

local function setGroundSpeed(enabled, speed)
    _speedEnabled = enabled
    _speedValue   = speed or WALK_SPEED
    if enabled then
        applySpeed(_speedValue)
    else
        applySpeed(16)  -- default Roblox WalkSpeed
    end
end

-- Persist speed across respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if _speedEnabled then
        applySpeed(_speedValue)
    end
end)

-- Speed enforcement loop (game may reset WalkSpeed on server side)
task.spawn(function()
    while true do
        task.wait(0.5)
        if _speedEnabled then
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed ~= _speedValue then
                hum.WalkSpeed = _speedValue
            end
        end
    end
end)

-- ============================================================
-- TWEEN WALK  (RenderStepped lerp on HumanoidRootPart.CFrame)
-- Real approach: lerp via RenderStepped avoids physics breakage
-- that direct TweenService:Create(HRP,...) causes.
-- Source: Roblox DevForum confirmed TweenService HRP breakage issue
-- /t/tweening-humanoidrootpart-completely-breaks-relative/3599725
-- ============================================================
local _tweenTarget  = nil   -- Vector3 destination
local _tweenConn    = nil
local _tweenEnabled = false

local function setTweenWalk(enabled)
    _tweenEnabled = enabled
    if enabled and not _tweenConn then
        _tweenConn = RunService.RenderStepped:Connect(function(dt)
            if not _tweenTarget then return end
            local part = LocalPlayer.Character
                and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not part then return end
            -- Lerp speed: studs per second controlled by WALK_SPEED
            local alpha = math.min(1, dt * (WALK_SPEED / 14))
            local newPos = part.Position:Lerp(_tweenTarget, alpha)
            part.CFrame = CFrame.new(newPos) * (part.CFrame - part.CFrame.Position)
        end)
    elseif not enabled and _tweenConn then
        _tweenConn:Disconnect()
        _tweenConn = nil
        _tweenTarget = nil
    end
end

-- Call this to move to a position with tween-style movement
local function tweenMoveTo(targetPos)
    _tweenTarget = targetPos
end

local function tweenMoveStop()
    _tweenTarget = nil
end

-- ============================================================
-- AREA / BIOME DATA  (confirmed from poccwo.lua)
-- ============================================================
local AREA_RANK = {
    Forest = 1, Lake = 2, Desert = 3, Jungle = 4, Snow = 5,
    Volcano = 6, ["Abyss Ocean"] = 7, Prehistoric = 8, Cosmic = 9,
    ["Cherry Blossom"] = 10, Sakura = 10, ["Sakura Blossom"] = 10,
}
local GUARD_MARGIN = 5

-- ============================================================
-- LOAD REAL GAME MODULES  (no pcall wrap — if these fail the
-- game wasn't loaded yet; caller handles with task.wait)
-- ============================================================
local TimeUtil, EggCmds, PlotCmds, Save, AssetsDir

local function loadModules()
    local ok = pcall(function()
        TimeUtil  = require(ReplicatedStorage.Library.Util.AreaEggResetTimeUtil)
        EggCmds   = require(ReplicatedStorage.Library.Client.EggCmds)
        PlotCmds  = require(ReplicatedStorage.Library.Client.PlotCmds)
        Save      = require(ReplicatedStorage.Library.Client.Save)
        AssetsDir = require(ReplicatedStorage.Directory.Assets)
    end)
    return ok
end

-- Retry until loaded (handles early injection before modules exist)
local retries = 0
while not loadModules() and retries < 20 do
    task.wait(0.5)
    retries = retries + 1
end

-- ============================================================
-- GENERATION GUARD  (kills previous instance if re-executed)
-- ============================================================
if type(_G.__EggStealKill) == "function" then
    pcall(_G.__EggStealKill)
end
_G.__EggStealGen = (_G.__EggStealGen or 0) + 1
local GEN = _G.__EggStealGen

-- ============================================================
-- LOGGING
-- ============================================================
local function log(msg)
    LAST = msg
    print("[EggSteal] " .. msg)
end

-- ============================================================
-- TIME / NIGHT  (real: TimeUtil.IsNight confirmed)
-- ============================================================
local function now()
    return Workspace:GetServerTimeNow()
end

local function isNight()
    if not TimeUtil then return false end
    local ok, result = pcall(TimeUtil.IsNight, now())
    return ok and result == true
end

-- ============================================================
-- SAVE / PLAYER DATA  (real: Save.Get confirmed)
-- ============================================================
local function saveData()
    if not Save then return {} end
    local ok, data = pcall(Save.Get)
    return (ok and type(data) == "table") and data or {}
end

-- ============================================================
-- CHARACTER HELPERS
-- ============================================================
local function hrp()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function currentPos()
    local part = hrp()
    return part and part.Position or Vector3.zero
end

-- ============================================================
-- PLOT / BASE HELPERS  (real: PlotCmds confirmed)
-- ============================================================
local function plotData()
    if not PlotCmds then return nil end
    local ok, data = pcall(PlotCmds.GetPlotData)
    return (ok and type(data) == "table") and data or nil
end

local function plotFolder()
    local d = plotData()
    return d and d.PlotFolder
end

local function petArea()
    local d = plotData()
    if d and d.PetArea and d.PetArea:IsA("BasePart") then
        return d.PetArea
    end
    return nil
end

local function homeCF()
    local area = petArea()
    if area then
        return CFrame.new(area.Position + Vector3.new(0, 3.1, 0))
    end
    local d = plotData()
    if d and d.RespawnPointCFrame then
        return d.RespawnPointCFrame + Vector3.new(0, 2, 0)
    end
    if PlotCmds then
        local ok, cf = pcall(PlotCmds.GetRespawnPointCFrame)
        if ok and typeof(cf) == "CFrame" then
            return cf + Vector3.new(0, 2, 0)
        end
    end
    local part = hrp()
    return part and part.CFrame or CFrame.new()
end

-- ============================================================
-- ROAD / GAMEPLAY GEOMETRY  (real: __OBJECTS.Areas.GameplayZ)
-- ============================================================
local function gameplayLine()
    local areas = Workspace:FindFirstChild("__OBJECTS")
    areas = areas and areas:FindFirstChild("Areas")
    local line = areas and areas:FindFirstChild("GameplayZ")
    return (line and line:IsA("BasePart")) and line or nil
end

local function roadY()
    local line = gameplayLine()
    if line then return line.Position.Y + 2.75 end
    local area = petArea()
    if area then return area.Position.Y + 2.65 end
    return 70.35
end

local function roadZ()
    local line = gameplayLine()
    if line then return line.Position.Z end
    local area = petArea()
    if area then return area.Position.Z end
    return currentPos().Z
end

local function corridorEntry()
    local line = gameplayLine()
    if line then
        return Vector3.new(line.Position.X + 70, roadY(), roadZ())
    end
    local area = petArea()
    if area then
        return Vector3.new(area.Position.X + 170, roadY(), roadZ())
    end
    return currentPos()
end

local function treadmillStand()
    local plot = plotFolder()
    local bottom = plot and plot:FindFirstChild("TreadmillBottom")
    if bottom then return bottom.Position + Vector3.new(0, 3, 0) end
    return homeCF().Position
end

-- ============================================================
-- GUARD DETECTION  (real: __OBJECTS.Areas.GuardAreas)
-- ============================================================
local function guardAreasRoot()
    local root = Workspace:FindFirstChild("__OBJECTS")
    root = root and root:FindFirstChild("Areas")
    return root and root:FindFirstChild("GuardAreas")
end

local function areaGuardModel(areaName)
    local root = guardAreasRoot()
    local area = root and root:FindFirstChild(areaName)
    if not area then return nil end
    return area:FindFirstChild("Guard") or area:FindFirstChild("ForestGuardAuthored")
end

local function insideGuardBox(worldPos, model, margin)
    if not model then return false end
    local cf, size = model:GetBoundingBox()
    local localP = cf:PointToObjectSpace(worldPos)
    local pad  = margin or GUARD_MARGIN
    local half = size * 0.5 + Vector3.new(pad, 8, pad)
    return math.abs(localP.X) <= half.X
        and math.abs(localP.Y) <= half.Y
        and math.abs(localP.Z) <= half.Z
end

local function anyGuardAt(worldPos, margin)
    local root = guardAreasRoot()
    if not root then return false end
    for _, area in ipairs(root:GetChildren()) do
        local guard = area:FindFirstChild("Guard")
            or area:FindFirstChild("ForestGuardAuthored")
        if guard and insideGuardBox(worldPos, guard, margin) then
            return true
        end
    end
    return false
end

local function safeStand(eggPos, areaName)
    local model = areaGuardModel(areaName)
    local y     = roadY()
    local tries = {
        Vector3.new(-7,0,0), Vector3.new(-9,0,0), Vector3.new(-11,0,0),
        Vector3.new(-14,0,0), Vector3.new(-18,0,0),
        Vector3.new(-6,0,-6), Vector3.new(-6,0,6),
        Vector3.new(-8,0,-8), Vector3.new(-8,0,8),
        Vector3.new(-12,0,-8), Vector3.new(0,0,-12),
        Vector3.new(0,0,12),  Vector3.new(-5,0,-12),
    }
    if model then
        local guardPos = model:GetPivot().Position
        local away = Vector3.new(eggPos.X - guardPos.X, 0, eggPos.Z - guardPos.Z)
        if away.Magnitude > 0.2 then
            table.insert(tries, 1, away.Unit * 8)
            table.insert(tries, 2, away.Unit * 11 + Vector3.new(-4, 0, 0))
        end
    end
    local best, bestDist
    for _, off in ipairs(tries) do
        local p = Vector3.new(eggPos.X + off.X, y, eggPos.Z + off.Z)
        if not insideGuardBox(p, model, GUARD_MARGIN) and not anyGuardAt(p, 3) then
            local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(eggPos.X, 0, eggPos.Z)).Magnitude
            if d <= 12 and (not bestDist or d < bestDist) then
                best, bestDist = p, d
            end
        end
    end
    return best, bestDist
end

-- ============================================================
-- NORMAL MOVEMENT (step CFrame teleport with guard avoidance)
-- ============================================================
local function hopTo(toPos, stepStuds, holdSec)
    local part = hrp()
    if not part then return false end
    if typeof(toPos) == "CFrame" then toPos = toPos.Position end
    local y, zRoad = roadY(), roadZ()
    toPos = Vector3.new(toPos.X, y, toPos.Z)
    stepStuds = stepStuds or 14
    local deadline = os.clock() + 16

    while GEN == _G.__EggStealGen and (part.Position - toPos).Magnitude > 3.1 do
        if os.clock() > deadline then break end
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health < 40 then return false end

        local delta   = toPos - part.Position
        local nextPos = part.Position + delta.Unit * math.min(stepStuds, delta.Magnitude)
        nextPos = Vector3.new(nextPos.X, y, nextPos.Z)

        if anyGuardAt(nextPos, 3) then
            local slide = Vector3.new(nextPos.X, y, zRoad)
            if (slide - part.Position).Magnitude > 1 then
                nextPos = part.Position
                    + (slide - part.Position).Unit * math.min(stepStuds, (slide - part.Position).Magnitude)
                nextPos = Vector3.new(nextPos.X, y, nextPos.Z)
            end
            if anyGuardAt(nextPos, 3) then
                nextPos = Vector3.new(part.Position.X - 12, y, zRoad)
            end
        end

        local cf = CFrame.new(nextPos)
        local t1 = os.clock()
        while os.clock() - t1 < 0.07 and GEN == _G.__EggStealGen do
            if part.Parent then part.CFrame = cf end
            task.wait()
        end
        part = hrp()
        if not part then return false end
    end

    local dest = CFrame.new(toPos)
    local t1   = os.clock()
    while os.clock() - t1 < (holdSec or 0.18) and GEN == _G.__EggStealGen do
        part = hrp()
        if not part then return false end
        part.CFrame = dest
        task.wait()
    end
    return true
end

-- ============================================================
-- INSTANT TELEPORT  (direct CFrame, no step movement)
-- Used by Instant Steal mode
-- ============================================================
local function tpNow(cf)
    local part = hrp()
    if not part then return false end
    if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
    -- Hold for 3 frames to let the server register the position
    for _ = 1, 3 do
        if part.Parent then part.CFrame = cf end
        task.wait()
    end
    return true
end

-- ============================================================
-- EGG SCORING  (real: AssetsDir.Directory confirmed)
-- ============================================================
local SKIP_UNTIL = {}

local function mutationBonus(rec)
    local blob = tostring(rec.BaseMutation or "")
    if type(rec.Mutations) == "table" then
        for _, m in pairs(rec.Mutations) do
            blob = blob .. "," .. tostring(m)
        end
    end
    local s = blob:lower()
    if s:find("rainbow", 1, true) then return 50000000 end
    if s:find("gold",    1, true) then return 30000000 end
    if s:find("silver",  1, true) then return 10000000 end
    if s ~= ""                    then return  2000000 end
    return 0
end

local function assetRarityOf(category)
    if not AssetsDir then return 0, "?", 0 end
    local cfg = AssetsDir.Directory and AssetsDir.Directory[category]
    if type(cfg) ~= "table" or type(cfg.Rarity) ~= "table" then
        return 0, "?", 0
    end
    return tonumber(cfg.Rarity.RarityNumber) or 0,
           tostring(cfg.Rarity._id or "?"),
           tonumber(cfg.EarningRate) or 0
end

-- ============================================================
-- EGG SNAPSHOT  (real: EggCmds.GetAreaEggSnapshot confirmed)
-- ============================================================
local function refreshRecords()
    if not EggCmds then return {} end
    local ok, snap = pcall(function() return EggCmds.GetAreaEggSnapshot() end)
    if not ok or type(snap) ~= "table" then return {} end
    return snap.Records or snap
end

local function pickBest()
    local nowt = os.clock()
    local best
    for _, rec in pairs(refreshRecords()) do
        if type(rec) == "table"
            and rec.State == "Slot"
            and typeof(rec.BottomCFrame) == "CFrame"
        then
            local uid    = tostring(rec.Uid or "")
            local area   = tostring(rec.AreaId or "")
            local skipAt = SKIP_UNTIL[uid]
            if uid ~= ""
                and not uid:find(tostring(USER_ID), 1, true)
                and not (skipAt and skipAt > nowt)
            then
                local stand, standDist = safeStand(rec.BottomCFrame.Position, area)
                -- In INSTANT mode we don't need a safe stand position
                if stand or INSTANT then
                    local cat           = tostring(rec.AssetCategory or rec.Name or "Egg")
                    local rarN, rarName, earn = assetRarityOf(cat)
                    local score = rarN * 1000000000
                        + mutationBonus(rec)
                        + earn
                        + (AREA_RANK[area] or 0)
                    if not best or score > best.score then
                        best = {
                            uid       = uid,
                            area      = area,
                            rarity    = rarName,
                            pos       = rec.BottomCFrame.Position,
                            cf        = rec.BottomCFrame,
                            stand     = stand,
                            standDist = standDist,
                            score     = score,
                            label     = string.format("%s [%s%s] %s",
                                cat, rarName,
                                (rec.BaseMutation and rec.BaseMutation ~= "")
                                    and (" "..rec.BaseMutation) or "",
                                area),
                        }
                    end
                end
            end
        end
    end
    return best
end

-- ============================================================
-- TREADMILL FARM  (real: TreadmillBottom confirmed)
-- ============================================================
local function farmTreadmill(sec)
    local stand = treadmillStand()
    hopTo(stand, 14, 0.15)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local t1  = os.clock()
    while os.clock() - t1 < (sec or 3) and GEN == _G.__EggStealGen do
        local part = hrp()
        if part then
            local wob = stand + Vector3.new(
                math.sin(os.clock() * 7) * 2.2, 0,
                math.cos(os.clock() * 7) * 2.2)
            part.CFrame = CFrame.new(wob)
            if hum then hum:Move(Vector3.new(1, 0, 0), true) end
        end
        task.wait()
    end
end

-- ============================================================
-- SAKURA CRYSTAL FARM  (real: confirmed from poccwo.lua)
-- ============================================================
local function isCrystalTree(inst)
    if not inst then return false end
    if not inst:IsA("Model") and not inst:IsA("BasePart") then return false end
    local n = inst.Name:lower()
    if n:find("crystal",1,true)
    or (n:find("sakura",1,true) and (n:find("tree",1,true) or n:find("blossom",1,true)))
    or n:find("bloomtree",1,true)
    or n:find("crystalcherry",1,true)
    or n:find("cherrycrystal",1,true) then
        return true
    end
    return inst:GetAttribute("IsCrystalTree") or inst:GetAttribute("GreatBloom") or false
end

local function findCrystalTrees()
    local trees = {}
    local function scan(root, depth)
        if depth > 6 then return end
        for _, child in ipairs(root:GetChildren()) do
            if isCrystalTree(child) then
                local pos = child:IsA("Model") and child:GetPivot().Position
                         or child:IsA("BasePart") and child.Position
                if pos then table.insert(trees, {model=child, pos=pos}) end
            end
            scan(child, depth + 1)
        end
    end
    local objects = Workspace:FindFirstChild("__OBJECTS")
    if objects then scan(objects, 0) end
    if #trees == 0 then scan(Workspace, 0) end
    return trees
end

local function equipBat()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local n = tool.Name:lower()
        if n:find("bat",1,true) or n:find("baseball",1,true) then return true end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name:lower()
                if n:find("bat",1,true) or n:find("baseball",1,true) then
                    hum:EquipTool(t)
                    task.wait(0.15)
                    return true
                end
            end
        end
    end
    return false
end

local function swingBat()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool and tool:FindFirstChild("Handle") then
        pcall(function() tool:Activate() end)
    end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.new())
    end)
end

local function farmSakuraCrystals(maxSec)
    maxSec = maxSec or 16
    local trees = findCrystalTrees()
    if #trees == 0 then return false end
    BUSY = true
    log("SAKURA " .. #trees .. " trees")
    if not equipBat() then
        log("no bat found")
        BUSY = false
        return false
    end
    local origin = currentPos()
    table.sort(trees, function(a, b)
        return (a.pos - origin).Magnitude < (b.pos - origin).Magnitude
    end)
    local deadline = os.clock() + maxSec
    local hits = 0
    for _, entry in ipairs(trees) do
        if GEN ~= _G.__EggStealGen or os.clock() > deadline then break end
        if not entry.model or not entry.model.Parent then continue end
        hopTo(entry.pos + Vector3.new(0, 2.5, 0), 18, 0.12)
        local swingUntil = os.clock() + 1.6
        while os.clock() < swingUntil and GEN == _G.__EggStealGen do
            local part = hrp()
            if part then part.CFrame = CFrame.new(part.Position, entry.pos) end
            swingBat()
            hits += 1
            task.wait(0.18)
        end
    end
    log("sakura swings=" .. hits)
    hopTo(homeCF().Position, 18, 0.08)
    BUSY = false
    return hits > 0
end

local function isGreatBloomActive()
    return #findCrystalTrees() > 0
end

-- ============================================================
-- STEAL ONCE — NORMAL MODE
-- Safe path: corridor → stand near egg → carry remote → escape → base
-- ============================================================
local function stealNormal(target)
    local y = roadY()
    local z = roadZ()
    local entry = corridorEntry()

    if currentPos().X < entry.X - 20 then
        moveTo(entry, 16, 0.12)
    end
    moveTo(Vector3.new(target.stand.X, y, z), 16, 0.08)
    moveTo(target.stand, 12, 0.20)

    if anyGuardAt(currentPos(), 2) then
        log("guard abort — backing off")
        moveTo(Vector3.new(target.stand.X - 40, y, z), 16, 0.08)
        moveTo(homeCF().Position, 18, 0.08)
        return false
    end

    local ok, res = pcall(function()
        return EggCmds.RequestCarryAreaEgg(target.uid)
    end)
    log("carry → " .. tostring(res))

    moveTo(Vector3.new(target.stand.X - 45, y, z), 18, 0.05)
    moveTo(homeCF().Position, 18, 0.08)
    return res == true
end

-- ============================================================
-- STEAL ONCE — INSTANT MODE
-- Direct CFrame TP to egg → RequestCarryAreaEgg → TP to base
-- No guard checking, no step movement — fast but risky
-- ============================================================
local function stealInstant(target)
    -- TP directly on top of the egg
    tpNow(target.cf + Vector3.new(0, 2, 0))
    task.wait(0.08)

    local ok, res = pcall(function()
        return EggCmds.RequestCarryAreaEgg(target.uid)
    end)
    log("instant carry → " .. tostring(res))

    -- Instantly TP back to base
    task.wait(0.05)
    tpNow(homeCF())

    return res == true
end

-- ============================================================
-- MOVEMENT DISPATCHER
-- Picks the right movement method based on WALK_MODE / AUTO
-- ============================================================
local function resolvedMode()
    if WALK_MODE == "AUTO" then return autoWalkMode() end
    return WALK_MODE
end

-- Universal move-to: uses active walk mode
local function moveTo(targetPos, stepStuds, holdSec)
    local mode = resolvedMode()

    if mode == "INSTANT" then
        -- Direct CFrame teleport (3-frame hold)
        return tpNow(CFrame.new(targetPos))

    elseif mode == "TWEEN" then
        -- RenderStepped lerp until within 3 studs or timeout
        tweenMoveTo(targetPos)
        local deadline = os.clock() + 12
        while GEN == _G.__EggStealGen and os.clock() < deadline do
            local part = hrp()
            if not part then tweenMoveStop(); return false end
            if (part.Position - targetPos).Magnitude < 3.5 then break end
            task.wait(0.05)
        end
        tweenMoveStop()
        return true

    else
        -- GROUND / PHANTOM: use original hopTo step movement
        -- Make sure speed is applied
        if _speedEnabled then applySpeed(_speedValue) end
        return hopTo(targetPos, stepStuds, holdSec)
    end
end
    if BUSY then return false end
    if isNight() then return false end

    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health < 80 then return false end

    local target = pickBest()
    if not target then return false end

    -- In INSTANT mode we don't need a safe stand, just need the egg CFrame
    if not INSTANT and not target.stand then return false end

    BUSY = true
    log((INSTANT and "INSTANT" or "NORMAL") .. " STEAL → " .. target.label)

    local success
    if INSTANT then
        success = stealInstant(target)
    else
        success = stealNormal(target)
    end

    if not success then
        SKIP_UNTIL[target.uid] = os.clock() + 40
        log("skip " .. target.uid .. " 40s")
    else
        log("stole! inv size growing")
    end

    BUSY = false
    return success
end

-- ============================================================
-- GUI — Compact draggable card, NO KEY SYSTEM
-- ============================================================
local existing = PlayerGui:FindFirstChild("EggStealGui")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name           = "EggStealGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 999
gui.Parent         = PlayerGui

-- Card — taller to fit walk mode row
local card = Instance.new("Frame")
card.Size            = UDim2.fromOffset(310, 160)
card.Position        = UDim2.new(0.5, -155, 0, 18)
card.BackgroundColor3 = Color3.fromRGB(16, 12, 18)
card.BackgroundTransparency = 0.05
card.BorderSizePixel = 0
card.Active          = true
card.Parent          = gui
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", card)
stroke.Color     = Color3.fromRGB(255, 70, 70)
stroke.Thickness = 2

-- Title
local title = Instance.new("TextLabel", card)
title.Size                = UDim2.new(1, -10, 0, 20)
title.Position            = UDim2.fromOffset(10, 4)
title.BackgroundTransparency = 1
title.Font                = Enum.Font.GothamBold
title.TextSize            = 13
title.TextColor3          = Color3.fromRGB(255, 85, 85)
title.TextXAlignment      = Enum.TextXAlignment.Left
title.Text                = "🥚  STEAL AN EGG  •  No Key"

-- Ping / FPS line (live updated in main loop)
local statsLbl = Instance.new("TextLabel", card)
statsLbl.Size                = UDim2.new(1, -10, 0, 14)
statsLbl.Position            = UDim2.fromOffset(10, 26)
statsLbl.BackgroundTransparency = 1
statsLbl.Font                = Enum.Font.Code
statsLbl.TextSize            = 10
statsLbl.TextColor3          = Color3.fromRGB(120, 200, 120)
statsLbl.TextXAlignment      = Enum.TextXAlignment.Left
statsLbl.Text                = "Ping: --ms   FPS: --   Mode: AUTO"

-- Status line
local statusLbl = Instance.new("TextLabel", card)
statusLbl.Size                = UDim2.new(1, -10, 0, 15)
statusLbl.Position            = UDim2.fromOffset(10, 42)
statusLbl.BackgroundTransparency = 1
statusLbl.Font                = Enum.Font.Gotham
statusLbl.TextSize            = 10
statusLbl.TextColor3          = Color3.fromRGB(190, 190, 190)
statusLbl.TextXAlignment      = Enum.TextXAlignment.Left
statusLbl.Text                = "Status: OFF"

-- ── Row 1: AUTO + INSTANT ────────────────────────────────
local row1 = Instance.new("Frame", card)
row1.Size = UDim2.new(1, -16, 0, 28); row1.Position = UDim2.fromOffset(8, 60)
row1.BackgroundTransparency = 1
local rl1 = Instance.new("UIListLayout", row1)
rl1.FillDirection = Enum.FillDirection.Horizontal; rl1.Padding = UDim.new(0, 5)

local autoBtn = Instance.new("TextButton", row1)
autoBtn.Size = UDim2.new(0.48, 0, 1, 0)
autoBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
autoBtn.BorderSizePixel = 0; autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 11; autoBtn.TextColor3 = Color3.fromRGB(255,255,255)
autoBtn.Text = "▶ AUTO: OFF"
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 6)

local instantBtn = Instance.new("TextButton", row1)
instantBtn.Size = UDim2.new(0.48, 0, 1, 0)
instantBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 130)
instantBtn.BorderSizePixel = 0; instantBtn.Font = Enum.Font.GothamBold
instantBtn.TextSize = 11; instantBtn.TextColor3 = Color3.fromRGB(255,255,255)
instantBtn.Text = "⚡ INSTANT: OFF"
Instance.new("UICorner", instantBtn).CornerRadius = UDim.new(0, 6)

-- ── Row 2: Walk mode buttons ─────────────────────────────
local walkLbl = Instance.new("TextLabel", card)
walkLbl.Size = UDim2.new(1, -10, 0, 12); walkLbl.Position = UDim2.fromOffset(10, 93)
walkLbl.BackgroundTransparency = 1; walkLbl.Font = Enum.Font.Gotham
walkLbl.TextSize = 9; walkLbl.TextColor3 = Color3.fromRGB(100, 100, 140)
walkLbl.TextXAlignment = Enum.TextXAlignment.Left
walkLbl.Text = "WALK MODE:"

local row2 = Instance.new("Frame", card)
row2.Size = UDim2.new(1, -16, 0, 26); row2.Position = UDim2.fromOffset(8, 107)
row2.BackgroundTransparency = 1
local rl2 = Instance.new("UIListLayout", row2)
rl2.FillDirection = Enum.FillDirection.Horizontal; rl2.Padding = UDim.new(0, 4)

local function WalkBtn(parent, lbl, bg)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0.24, 0, 1, 0)
    b.BackgroundColor3 = bg; b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold; b.TextSize = 9
    b.TextColor3 = Color3.fromRGB(255,255,255); b.Text = lbl
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local btnAuto    = WalkBtn(row2, "AUTO",    Color3.fromRGB(50, 100, 50))
local btnGround  = WalkBtn(row2, "GROUND",  Color3.fromRGB(40, 80, 160))
local btnPhantom = WalkBtn(row2, "PHANTOM", Color3.fromRGB(80, 40, 120))
local btnTween   = WalkBtn(row2, "TWEEN",   Color3.fromRGB(120, 80, 20))

-- Speed hint
local speedLbl = Instance.new("TextLabel", card)
speedLbl.Size = UDim2.new(1, -10, 0, 11); speedLbl.Position = UDim2.fromOffset(10, 136)
speedLbl.BackgroundTransparency = 1; speedLbl.Font = Enum.Font.Gotham
speedLbl.TextSize = 9; speedLbl.TextColor3 = Color3.fromRGB(90, 90, 130)
speedLbl.TextXAlignment = Enum.TextXAlignment.Left
speedLbl.Text = "Speed: 60 studs/s  |  drag to move"

-- ── Walk mode highlight helper ────────────────────────────
local DIM = Color3.fromRGB(35, 35, 35)
local function updateWalkBtns()
    btnAuto.BackgroundColor3    = WALK_MODE == "AUTO"    and Color3.fromRGB(50,140,60)  or DIM
    btnGround.BackgroundColor3  = WALK_MODE == "GROUND"  and Color3.fromRGB(50,90,200)  or DIM
    btnPhantom.BackgroundColor3 = WALK_MODE == "PHANTOM" and Color3.fromRGB(100,50,160) or DIM
    btnTween.BackgroundColor3   = WALK_MODE == "TWEEN"   and Color3.fromRGB(160,100,20) or DIM
end
updateWalkBtns()

-- ── Button wiring ─────────────────────────────────────────
autoBtn.MouseButton1Click:Connect(function()
    AUTO = not AUTO
    if AUTO then
        autoBtn.Text = "⏹ AUTO: ON"; autoBtn.BackgroundColor3 = Color3.fromRGB(35,155,55)
        stroke.Color = Color3.fromRGB(55,220,90)
    else
        autoBtn.Text = "▶ AUTO: OFF"; autoBtn.BackgroundColor3 = Color3.fromRGB(180,40,40)
        stroke.Color = Color3.fromRGB(255,70,70)
    end
    log("AUTO " .. (AUTO and "ON" or "OFF"))
end)

instantBtn.MouseButton1Click:Connect(function()
    INSTANT = not INSTANT
    if INSTANT then
        instantBtn.Text = "⚡ INSTANT: ON"
        instantBtn.BackgroundColor3 = Color3.fromRGB(100,50,200)
    else
        instantBtn.Text = "⚡ INSTANT: OFF"
        instantBtn.BackgroundColor3 = Color3.fromRGB(60,50,130)
    end
    log("INSTANT " .. (INSTANT and "ON" or "OFF"))
end)

local function switchWalkMode(mode)
    -- Disable previous mode
    setNoclip(false)
    setGroundSpeed(false)
    setTweenWalk(false)
    WALK_MODE = mode
    -- Enable new mode
    if mode == "GROUND" then
        setGroundSpeed(true, WALK_SPEED)
    elseif mode == "PHANTOM" then
        setNoclip(true)
        setGroundSpeed(true, WALK_SPEED)  -- phantom + speed together
    elseif mode == "TWEEN" then
        setTweenWalk(true)
    end
    -- AUTO mode activates dynamically per-action
    updateWalkBtns()
    log("WALK_MODE → " .. mode)
end

btnAuto.MouseButton1Click:Connect(function()    switchWalkMode("AUTO")    end)
btnGround.MouseButton1Click:Connect(function()  switchWalkMode("GROUND")  end)
btnPhantom.MouseButton1Click:Connect(function() switchWalkMode("PHANTOM") end)
btnTween.MouseButton1Click:Connect(function()   switchWalkMode("TWEEN")   end)

-- ── Drag ─────────────────────────────────────────────────
do
    local dragging, dragStart, startAbs = false, nil, nil
    local function beginDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true; dragStart = input.Position; startAbs = card.AbsolutePosition
        card.AnchorPoint = Vector2.zero
        card.Position    = UDim2.fromOffset(startAbs.X, startAbs.Y)
    end
    card.InputBegan:Connect(beginDrag); title.InputBegan:Connect(beginDrag)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        local vp    = Workspace.CurrentCamera.ViewportSize
        card.Position = UDim2.fromOffset(
            math.clamp(startAbs.X + delta.X, 0, vp.X - card.AbsoluteSize.X),
            math.clamp(startAbs.Y + delta.Y, 0, vp.Y - card.AbsoluteSize.Y))
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

-- ============================================================
-- KILL SWITCH  (re-execute safe)
-- ============================================================
_G.__EggStealKill = function()
    GEN  = -1
    AUTO = false
    local old = PlayerGui:FindFirstChild("EggStealGui")
    if old then old:Destroy() end
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
task.spawn(function()
    local lastTread = 0
    while GEN == _G.__EggStealGen do
        -- Live ping/FPS stats
        local ping    = getPing()
        local fps     = getFPS()
        local curMode = WALK_MODE == "AUTO" and ("AUTO→" .. autoWalkMode()) or WALK_MODE
        statsLbl.Text = string.format(
            "Ping: %dms   FPS: %d   Walk: %s%s",
            ping, fps, curMode,
            INSTANT and "  Steal: TP" or "")

        -- Status
        statusLbl.Text = string.format(
            "Auto: %s  |  %s",
            AUTO and "ON" or "OFF", LAST)

        if AUTO and not BUSY then
            if isNight() then
                if isGreatBloomActive() then
                    farmSakuraCrystals(12)
                else
                    farmTreadmill(5)
                end
            else
                local stole = stealOnce()
                if not stole then
                    if isGreatBloomActive() then
                        farmSakuraCrystals(14)
                    elseif os.clock() - lastTread > 3 then
                        farmTreadmill(3.5)
                        lastTread = os.clock()
                    end
                end
            end
        end

        task.wait(0.4)
    end
end)
