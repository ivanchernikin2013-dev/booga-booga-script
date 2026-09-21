-- ============================================================
-- help.luau — Herkle Hub Helper Library v2.0
-- GitHub: https://github.com/ivanchernikin2013-dev/booga-booga-script
-- ============================================================
-- Использование:
--   local Helper = loadstring(game:HttpGet("https://raw.githubusercontent.com/ivanchernikin2013-dev/booga-booga-script/main/help.luau"))()
--   Helper.init(WindUI)
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local plr = Players.LocalPlayer
local rs = ReplicatedStorage

local Helper = {}
Helper.Version = "2.0.0"

-- ============================================================
-- MODULE REFERENCES
-- ============================================================
local packets
pcall(function()
    packets = require(rs.Modules.Packets)
end)
Helper.packets = packets

local Clock
pcall(function()
    if rs:FindFirstChild("Modules") and rs.Modules:FindFirstChild("Clock") then
        Clock = require(rs.Modules.Clock)
    end
end)
Helper.Clock = Clock

-- Remote references
local Events = rs:FindFirstChild("Events")
Helper.Events = Events
Helper.RemoteSwingTool = Events and Events:FindFirstChild("SwingTool")
Helper.RemoteEquipTool = Events and Events:FindFirstChild("EquipTool")
Helper.RemotePickup = Events and Events:FindFirstChild("Pickup")

-- WindUI reference
local _windUI = nil
function Helper.init(windUI) _windUI = windUI end

-- ============================================================
-- CLEANUP SYSTEM
-- ============================================================
Helper._connections = {}
Helper._cleanupFuncs = {}

function Helper.trackConnection(conn)
    if conn then table.insert(Helper._connections, conn) end
    return conn
end

function Helper.registerCleanup(fn)
    table.insert(Helper._cleanupFuncs, fn)
end

function Helper.runCleanup()
    for _, conn in ipairs(Helper._connections) do
        pcall(function() conn:Disconnect() end)
    end
    Helper._connections = {}
    for _, fn in ipairs(Helper._cleanupFuncs) do pcall(fn) end
    Helper._cleanupFuncs = {}
    for _, gui in ipairs(CoreGui:GetChildren()) do
        if gui.Name == "WindUI" or gui:GetAttribute("HerkleHub") then
            pcall(function() gui:Destroy() end)
        end
    end
    pcall(function()
        local pg = plr:FindFirstChild("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui.Name == "WindUI" or gui:GetAttribute("HerkleHub") then
                    gui:Destroy()
                end
            end
        end
    end)
    if Helper.Baritone and Helper.Baritone.Stop then
        pcall(function() Helper.Baritone.Stop() end)
    end
end

-- ============================================================
-- HP METHODS
-- ============================================================
local _hpLabelCache = nil

function Helper.getHealthValueLabel()
    if _hpLabelCache and _hpLabelCache.Parent then return _hpLabelCache end
    _hpLabelCache = nil
    local pg = plr:FindFirstChild("PlayerGui")
    local mg = pg and pg:FindFirstChild("MainGui")
    local panels = mg and mg:FindFirstChild("Panels")
    local stats = panels and panels:FindFirstChild("Stats")
    local bars = stats and stats:FindFirstChild("Bars")
    local health = bars and bars:FindFirstChild("Health")
    local vl = health and health:FindFirstChild("ValueLabel")
    if vl and vl:IsA("TextLabel") then _hpLabelCache = vl; return vl end
    return nil
end

function Helper.getHP()
    local lbl = Helper.getHealthValueLabel()
    if lbl then
        local n = tonumber((lbl.Text or ""):match("^%s*([%d%.]+)"))
        if n then return n end
    end
    return 0
end

function Helper.getHPFromHumanoid()
    local c = plr.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health or 0
end

function Helper.getMaxHP()
    local c = plr.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.MaxHealth or 100
end

function Helper.getHPPercent()
    local hp = Helper.getHP()
    local max = Helper.getMaxHP()
    if max <= 0 then return 0 end
    return (hp / max) * 100
end

-- ============================================================
-- INVENTORY
-- ============================================================
function Helper.getInventoryList()
    local pg = plr:FindFirstChild("PlayerGui")
    local mg = pg and pg:FindFirstChild("MainGui")
    local rp = mg and mg:FindFirstChild("RightPanel")
    local inv = rp and rp:FindFirstChild("Inventory")
    return inv and inv:FindFirstChild("List")
end

function Helper.findSlotByName(itemName)
    local list = Helper.getInventoryList()
    if not list then return nil end
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == itemName then
            return child.LayoutOrder
        end
    end
    return nil
end

function Helper.getInventorySnapshot()
    local list = Helper.getInventoryList()
    if not list then return {}, {} end
    local byLayout = {}
    local byName = {}
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("GuiObject") then
            byLayout[child.LayoutOrder] = child.Name
            if not byName[child.Name] then byName[child.Name] = child.LayoutOrder end
        end
    end
    return byLayout, byName
end

-- ============================================================
-- CHARACTER
-- ============================================================
function Helper.getRoot()
    local c = plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Helper.getHumanoid()
    local c = plr.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Helper.getRootPart(inst)
    if not inst or not inst:IsA("Model") then return nil end
    return inst.PrimaryPart
        or inst:FindFirstChild("HumanoidRootPart")
        or inst:FindFirstChild("Torso")
        or inst:FindFirstChild("UpperTorso")
        or inst:FindFirstChild("Head")
        or inst:FindFirstChild("ENTITY_HITBOX")
        or inst:FindFirstChildWhichIsA("BasePart")
end

function Helper.findEntityID(obj)
    if not obj then return nil end
    local eid = obj:GetAttribute("EntityID")
    if eid then return eid end
    local base = obj:FindFirstChildWhichIsA("BasePart")
    if base then
        eid = base:GetAttribute("EntityID")
        if eid then return eid end
    end
    if obj:IsA("Model") then
        for _, d in ipairs(obj:GetDescendants()) do
            eid = d:GetAttribute("EntityID")
            if eid then return eid end
        end
    end
    return nil
end

-- ============================================================
-- NOTIFY
-- ============================================================
function Helper.notify(title, content, duration)
    if _windUI then
        pcall(function()
            _windUI:Notify({ Title = title, Content = content, Duration = duration or 5 })
        end)
    else
        print("[" .. tostring(title) .. "] " .. tostring(content))
    end
end

-- ============================================================
-- THEMES (116 тем)
-- ============================================================
Helper.THEMES = {
    ["Dark"]="Dark",["Light"]="Light",["Rose"]="Rose",["Plant"]="Plant",
    ["Red"]="Red",["Indigo"]="Indigo",["Sky"]="Sky",["Violet"]="Violet",
    ["Amber"]="Amber",["Emerald"]="Emerald",["Midnight"]="Midnight",
    ["Crimson"]="Crimson",["MonokaiPro"]="Monokai Pro",
    ["CottonCandy"]="Cotton Candy",["Mellowsi"]="Mellowsi",["Rainbow"]="Rainbow",

    ["Neon Pink"]="#FF10F0",["Neon Cyan"]="#00F0FF",["Neon Green"]="#39FF14",
    ["Neon Orange"]="#FF5F1F",["Neon Yellow"]="#FFFF33",["Neon Purple"]="#BC13FE",
    ["Cyber Blue"]="#00BFFF",["Cyber Red"]="#FF003C",["Cyber Teal"]="#00FFC8",
    ["Cyber Lime"]="#CCFF00",

    ["Toxic Green"]="#AFFF00",["Spring Green"]="#00FF7F",["Mint"]="#98FF98",
    ["Mint Chocolate"]="#3EB489",["Forest"]="#228B22",["Emerald City"]="#50C878",
    ["Jade"]="#00A86B",["Olive"]="#808000",["Lime Zest"]="#BFFF00",
    ["Seafoam"]="#93E9BE",["Kiwi"]="#8EE53F",["Fern"]="#4F7942",
    ["Pistachio"]="#93C572",["Sage"]="#9CAF88",["Hunter Green"]="#355E3B",

    ["Deep Ocean"]="#0066CC",["Ocean Breeze"]="#4FC3F7",["Aqua Marine"]="#7FFFD4",
    ["Turquoise"]="#40E0D0",["Sky Blue"]="#87CEEB",["Baby Blue"]="#89CFF0",
    ["Powder Blue"]="#B0E0E6",["Periwinkle"]="#CCCCFF",["Sapphire"]="#0F52BA",
    ["Cobalt"]="#0047AB",["Electric Blue"]="#7DF9FF",["Ice Blue"]="#99FFFF",
    ["Steel Blue"]="#4682B4",["Denim"]="#1560BD",["Azure"]="#007FFF",

    ["Lavender"]="#E6E6FA",["Lilac"]="#C8A2C8",["Orchid"]="#DA70D6",
    ["Plum"]="#8E4585",["Amethyst"]="#9966CC",["Grape"]="#6F2DA8",
    ["Violet Dream"]="#7F00FF",["Royal Purple"]="#7851A9",["Indigo Night"]="#4B0082",
    ["Magenta Punch"]="#FF00AA",

    ["Hot Pink"]="#FF69B4",["Crimson Red"]="#DC143C",["Scarlet"]="#FF2400",
    ["Cherry Red"]="#D2042D",["Blood Red"]="#8A0303",["Ruby"]="#E0115F",
    ["Wine"]="#722F37",["Burgundy"]="#800020",["Maroon"]="#800000",
    ["Rose Quartz"]="#F7CAC9",["Sakura"]="#FFB7C5",["Blossom"]="#FFB2D0",
    ["Bubblegum"]="#FFC1CC",["Peach Fuzz"]="#FFBE98",["Salmon"]="#FA8072",

    ["Coral"]="#FF7F50",["Peach"]="#FFCBA4",["Apricot"]="#FBCEB1",
    ["Tangerine"]="#F28500",["Orange Crush"]="#FF6600",["Pumpkin"]="#FF7518",
    ["Gold"]="#FFD700",["Honey"]="#F0C040",["Mustard"]="#FFDB58",
    ["Sunshine"]="#FFFD37",

    ["Rose Gold"]="#B76E79",["Copper"]="#B87333",["Bronze"]="#CD7F32",
    ["Chocolate"]="#7B3F00",["Coffee"]="#6F4E37",["Mocha"]="#967969",
    ["Taupe"]="#483C32",["Sand"]="#C2B280",["Tan"]="#D2B48C",
    ["Terracotta"]="#E2725B",

    ["Slate"]="#708090",["Charcoal"]="#36454F",["Onyx"]="#353839",
    ["Obsidian"]="#3B3B3B",["Gunmetal"]="#2A3439",["Shadow"]="#1C1C1C",
    ["Storm"]="#4F666A",["Ash"]="#B2BEB5",["Silver"]="#C0C0C0",
    ["Platinum"]="#E5E4E2",

    ["Cream"]="#FFFDD0",["Ivory"]="#FFFFF0",["Pearl"]="#EAE0C8",
    ["Champagne"]="#F7E7CE",["Beige"]="#F5F5DC",["Fog"]="#D3D3D3",
    ["Crystal"]="#A8E6CF",["Aurora"]="#7BDFF2",["Galaxy"]="#5C2E91",
    ["Sunset"]="#FF6B35",
}

function Helper.getThemeList()
    local list = {}
    for _, display in pairs(Helper.THEMES) do
        table.insert(list, display)
    end
    table.sort(list)
    return list
end

function Helper.getThemeKey(displayName)
    for key, display in pairs(Helper.THEMES) do
        if display == displayName then return key end
    end
    return "Dark"
end

function Helper.applyTheme(displayName)
    if not _windUI then return false end
    local key = Helper.getThemeKey(displayName)
    if not key then return false end
    pcall(function()
        if key:sub(1, 1) == "#" then
            local color = Color3.fromHex(key)
            _windUI:SetTheme({
                Accent = color, Button = color, Toggle = color,
                Slider = color, Dropdown = color, Tab = color,
            })
        else
            _windUI:SetTheme(key)
        end
    end)
    return true
end

-- ============================================================
-- FOOD PRIORITY
-- ============================================================
Helper.FOOD_PRIORITY = {
    ["Bloodfruit"]=1000,
    ["Pie"]=500, ["Peeper Popsicle"]=480, ["Cooked Baracuda"]=460,
    ["Cooked Meat"]=440, ["Cooked Morsel"]=420, ["Cooked Fish"]=420,
    ["Cooked Crab"]=420, ["Cooked Egg"]=400, ["Watermelon"]=380,
    ["Bread"]=360, ["Cornbread"]=360, ["Jelly"]=340,
    ["Sunfruit"]=320, ["Mango"]=320, ["Frozen Pumpkin"]=320,
    ["Pumpkin"]=300, ["Bluefruit"]=280, ["Banana"]=280, ["Orange"]=280,
    ["Apple"]=280, ["Oddberry"]=280, ["Strangefruit"]=280,
    ["Berry"]=260, ["Lemon"]=260, ["Strawberry"]=260, ["Coconut"]=260,
    ["Barley"]=240, ["Cloudberry"]=240, ["Carrot"]=240, ["Corn"]=240,
    ["Prickly Pear"]=240, ["Grain Mush"]=240, ["Corn Mush"]=260,
    ["Fried Cactus"]=260,
    ["Raw Meat"]=200, ["Raw Morsel"]=180, ["Raw Fish"]=180,
    ["Raw Crab"]=180, ["Raw Baracuda"]=180, ["Egg"]=160, ["Cactus Bits"]=100,
}

function Helper.findBestFoodSlot()
    local list = Helper.getInventoryList()
    if not list then return nil, 0 end
    local bestSlot, bestScore = nil, -1
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("ImageLabel") then
            local score = Helper.FOOD_PRIORITY[child.Name]
            if score and score > bestScore then
                bestScore = score
                bestSlot = child
            end
        end
    end
    return bestSlot, bestScore
end

function Helper.eatFood(slot)
    if not slot then return false end
    if packets and packets.UseBagItem and packets.UseBagItem.send then
        pcall(function() packets.UseBagItem.send(slot.LayoutOrder) end)
        return true
    end
    return false
end

-- ============================================================
-- STRIKE TARGET
-- ============================================================
function Helper.strikeTarget(targetPart)
    if not targetPart or not plr.Character then return end
    local c = plr.Character
    local r = c:FindFirstChild("HumanoidRootPart")
    if not r then return end

    local eid = tonumber(targetPart:GetAttribute("EntityID") or
        (targetPart.Parent and targetPart.Parent:GetAttribute("EntityID")))
    local lookDir = (targetPart.Position - r.Position).Unit
    local st = Clock and Clock.getServerTime and Clock.getServerTime(true) or os.clock()
    local swingCFrame = CFrame.new(r.Position, targetPart.Position)

    pcall(function()
        local toolMod = rs:FindFirstChild("Game") and rs.Game:FindFirstChild("tool") and require(rs.Game.tool)
        if toolMod and toolMod.swingTool then
            toolMod.swingTool()
        end
    end)

    if Helper.RemoteSwingTool then
        pcall(function() Helper.RemoteSwingTool:FireServer(lookDir, { targetPart }) end)
    end

    if packets and packets.SwingTool and packets.SwingTool.send and eid then
        pcall(function()
            packets.SwingTool.send({
                entityIDs = { { entityID = eid } },
                cframe = swingCFrame,
                timestamp = st
            })
        end)
    end
end

-- ============================================================
-- AUTO EQUIP BEST TOOL
-- ============================================================
local _equipTickCounter = 0
local _lastEquipTicks = {}

function Helper.autoEquipBestTool(targetCategory)
    pcall(function()
        local bag = plr.PlayerGui:FindFirstChild("MainGui") and
            plr.PlayerGui.MainGui:FindFirstChild("Panels") and
            plr.PlayerGui.MainGui.Panels:FindFirstChild("Bag")
        if Helper.RemoteEquipTool and bag then
            for _, item in ipairs(bag:GetDescendants()) do
                if item:IsA("TextLabel") and item.Name == "ItemName" then
                    local n = item.Text:lower()
                    if targetCategory == "Wood" and (n:find("axe") or n:find("hatchet")) then
                        Helper.RemoteEquipTool:FireServer(item.Text)
                        return
                    elseif (targetCategory == "Stone" or targetCategory == "Ore" or targetCategory == "Crystal")
                        and (n:find("pick") or n:find("hammer")) then
                        Helper.RemoteEquipTool:FireServer(item.Text)
                        return
                    elseif (targetCategory == "Combat" or targetCategory == "Critter" or targetCategory == "God")
                        and (n:find("sword") or n:find("blade") or n:find("club") or n:find("spear")) then
                        Helper.RemoteEquipTool:FireServer(item.Text)
                        return
                    end
                end
            end
        end
    end)
end

function Helper.autoEquipThrottled(category)
    local last = _lastEquipTicks[category] or -999
    if _equipTickCounter - last >= 5 then
        Helper.autoEquipBestTool(category)
        _lastEquipTicks[category] = _equipTickCounter
    end
end

function Helper.tickEquipCounter()
    _equipTickCounter = _equipTickCounter + 1
end

function Helper.resetEquipThrottle(category)
    _lastEquipTicks[category] = -999
end

-- ============================================================
-- VELOCITY TRACKER
-- ============================================================
Helper.trackedVelocities = {}

function Helper.updateVelocityTracker(dt)
    if not dt or dt <= 0 then return end
    local tracked = Helper.trackedVelocities
    local critters = Workspace:FindFirstChild("Critters") or Workspace:FindFirstChild("HumanoidCritters")
    if critters then
        for _, c in ipairs(critters:GetChildren()) do
            local p = c:FindFirstChild("ENTITY_HITBOX") or c:FindFirstChild("Torso") or
                c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head") or Helper.getRootPart(c)
            if p then
                local curPos = p.Position
                local rec = tracked[p]
                if rec then
                    local instVel = (curPos - rec.pos) / dt
                    rec.vel = rec.vel:Lerp(instVel, 0.45)
                    rec.pos = curPos
                else
                    tracked[p] = { pos = curPos, vel = p.AssemblyLinearVelocity or Vector3.zero }
                end
            end
        end
    end
    local playersFolder = Workspace:FindFirstChild("Players")
    if playersFolder then
        for _, pChar in ipairs(playersFolder:GetChildren()) do
            local p = pChar:FindFirstChild("HumanoidRootPart") or pChar:FindFirstChild("Head")
            if p then
                local curPos = p.Position
                local rec = tracked[p]
                if rec then
                    local instVel = (curPos - rec.pos) / dt
                    rec.vel = rec.vel:Lerp(instVel, 0.45)
                    rec.pos = curPos
                else
                    tracked[p] = { pos = curPos, vel = p.AssemblyLinearVelocity or Vector3.zero }
                end
            end
        end
    end
end

-- ============================================================
-- SMART GOD DETECTION
-- ============================================================
Helper.KNOWN_GOD_NAMES = {
    ["Old God"]=true, ["Miserable God"]=true, ["Hateful God"]=true,
    ["Wealthy God"]=true, ["Lonely God"]=true, ["Unborn God"]=true,
    ["Forgotten God"]=true, ["Odd God"]=true, ["Dark God"]=true,
    ["Magical God"]=true, ["Infinity God"]=true, ["Strange God"]=true,
    ["Ancient God"]=true, ["Sleeping God"]=true,
}

Helper.GOD_COLORS = {
    ["Old God"]=Color3.fromRGB(139,69,19),
    ["Miserable God"]=Color3.fromRGB(100,100,150),
    ["Hateful God"]=Color3.fromRGB(255,0,0),
    ["Wealthy God"]=Color3.fromRGB(255,215,0),
    ["Lonely God"]=Color3.fromRGB(200,200,255),
    ["Unborn God"]=Color3.fromRGB(150,200,150),
    ["Forgotten God"]=Color3.fromRGB(100,50,100),
    ["Odd God"]=Color3.fromRGB(100,255,100),
    ["Dark God"]=Color3.fromRGB(80,0,80),
    ["Magical God"]=Color3.fromRGB(200,100,255),
    ["Infinity God"]=Color3.fromRGB(120,0,255),
    ["Strange God"]=Color3.fromRGB(0,255,200),
    ["Ancient God"]=Color3.fromRGB(200,170,80),
    ["Sleeping God"]=Color3.fromRGB(100,150,220),
}

function Helper.isGodModel(obj)
    if not obj or not obj:IsA("Model") then return false end
    local name = obj.Name
    if not name or name == "" then return false end
    if Helper.KNOWN_GOD_NAMES[name] then return true end
    if name:lower():find("god", 1, true) then
        local h = obj:FindFirstChildOfClass("Humanoid")
        local base = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if h or base then return true end
    end
    return false
end

function Helper.findGodTargets(range)
    local results = {}
    local myRoot = Helper.getRoot()
    if not myRoot then return results end
    local maxRange = range or 25
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and Helper.isGodModel(obj) then
            local base = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if base then
                local h = obj:FindFirstChildOfClass("Humanoid")
                if not h or h.Health > 0 then
                    local dist = (base.Position - myRoot.Position).Magnitude
                    if dist <= maxRange then
                        results[#results+1] = {
                            part = base, model = obj, dist = dist,
                            health = h and h.Health or math.huge,
                        }
                    end
                end
            end
        end
    end
    return results
end

-- ============================================================
-- RESOURCE HELPERS
-- ============================================================
function Helper.forEachResource(callback)
    local resFolder = Workspace:FindFirstChild("Resources")
    if resFolder then
        for _, obj in ipairs(resFolder:GetChildren()) do callback(obj) end
    end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj ~= resFolder and obj.Name ~= "Terrain" and obj.Name ~= "Players"
            and obj.Name ~= "Critters" and obj.Name ~= "Items"
            and obj.Name ~= "Deployables" and obj.Name ~= "Boats" and obj.Name ~= "Camera" then
            callback(obj)
        end
    end
end

function Helper.isResourceAccessible(rootPos, targetPos, targetObj)
    local yDiff = math.abs(targetPos.Y - rootPos.Y)
    if yDiff > 14 then return false end
    if targetPos.Y < -15 and rootPos.Y > -10 then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { plr.Character, targetObj }
    local ray = Workspace:Raycast(rootPos, (targetPos - rootPos), rayParams)
    if ray and ray.Instance and ray.Instance:IsA("Terrain") and ray.Material ~= Enum.Material.Water then
        return false
    end
    return true
end

-- ============================================================
-- BOW AIMBOT HELPERS
-- ============================================================
function Helper.isBowEquipped()
    local c = plr.Character
    local tools = c and c:FindFirstChild("Tools")
    if tools then
        for _, t in ipairs(tools:GetChildren()) do
            local n = t.Name:lower()
            if n:find("bow") or n:find("crossbow") or n:find("sling") then
                return true
            end
        end
    end
    return false
end

function Helper.getEquippedWeaponSpeed()
    local c = plr.Character
    local tools = c and c:FindFirstChild("Tools")
    if tools then
        for _, t in ipairs(tools:GetChildren()) do
            local n = t.Name:lower()
            if n:find("iron bow") then return 450
            elseif n:find("crossbow") and n:find("magnetite") then return 650
            elseif n:find("crossbow") then return 500
            elseif n:find("god sling") or n:find("sling") then return 270
            elseif n:find("bow") then return 350 end
        end
    end
    return 350
end

function Helper.computeAimPoint(targetPart, isCritter)
    local c = plr.Character
    local Camera = Workspace.CurrentCamera
    local launchOrigin = c and (c:GetPivot() * CFrame.new(1.4, -0.4, -3)).Position or
        (Camera and Camera.CFrame.Position or Vector3.zero)
    local targetPos = targetPart.Position

    if not isCritter and targetPart.Name == "Head" then
        targetPos = targetPart.Position
    elseif not isCritter then
        targetPos = targetPart.Position + Vector3.new(0, 1.4, 0)
    else
        targetPos = targetPart.Position + Vector3.new(0, math.min(targetPart.Size.Y * 0.2, 0.4), 0)
    end

    local speed = Helper.getEquippedWeaponSpeed()
    local diff = targetPos - launchOrigin
    local dist = diff.Magnitude
    local flightTime = dist / speed

    local targetVel = Vector3.zero
    local tracked = Helper.trackedVelocities
    local rec = tracked[targetPart] or
        (targetPart.Parent and (tracked[targetPart.Parent:FindFirstChild("HumanoidRootPart")] or
        tracked[targetPart.Parent:FindFirstChild("ENTITY_HITBOX")]))
    if rec and rec.vel and rec.vel.Magnitude > 0.3 then
        targetVel = rec.vel
    elseif targetPart.AssemblyLinearVelocity and targetPart.AssemblyLinearVelocity.Magnitude > 0.3 then
        targetVel = targetPart.AssemblyLinearVelocity
    end

    local predictedTargetPos = targetPos + (targetVel * flightTime)
    local delta = predictedTargetPos - launchOrigin
    local g = 122.2
    local vLaunch = (delta + Vector3.new(0, 0.5 * g * (flightTime ^ 2), 0)) / flightTime

    return launchOrigin + (vLaunch.Unit * 1000)
end

function Helper.getAimbotTarget(cfgTarget, cfgPart, cfgRange, isFriendFn)
    local Camera = Workspace.CurrentCamera
    local UIS = game:GetService("UserInputService")
    local nearestPart = nil
    local nearestAimPoint = nil
    local nearestScreenDist = math.huge
    local mousePos = UIS:GetMouseLocation()
    local c = plr.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    local maxWorldRange = cfgRange or 300

    if cfgTarget == "Players" or cfgTarget == "Both" then
        local playersFolder = Workspace:FindFirstChild("Players")
        if playersFolder then
            for _, pChar in ipairs(playersFolder:GetChildren()) do
                if pChar ~= c and not (isFriendFn and isFriendFn(pChar.Name)) then
                    local targetPart = (cfgPart == "Head" and pChar:FindFirstChild("Head")) or
                        pChar:FindFirstChild("HumanoidRootPart") or pChar:FindFirstChild("UpperTorso")
                    local pHum = pChar:FindFirstChildOfClass("Humanoid")
                    if targetPart and pHum and pHum.Health > 0 then
                        local worldDist = r and (r.Position - targetPart.Position).Magnitude or 0
                        if worldDist <= maxWorldRange then
                            local aimPoint = Helper.computeAimPoint(targetPart, false)
                            local screenPos, onScreen = Camera:WorldToViewportPoint(aimPoint)
                            if onScreen then
                                local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                                if screenDist < nearestScreenDist then
                                    nearestScreenDist = screenDist
                                    nearestPart = targetPart
                                    nearestAimPoint = aimPoint
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not nearestPart and (cfgTarget == "Critters" or cfgTarget == "Both") then
        local crittersFolder = Workspace:FindFirstChild("Critters") or Workspace:FindFirstChild("HumanoidCritters")
        if crittersFolder then
            for _, critter in ipairs(crittersFolder:GetChildren()) do
                local part = critter:FindFirstChild("ENTITY_HITBOX") or critter:FindFirstChild("Torso") or
                    critter:FindFirstChild("Head") or Helper.getRootPart(critter)
                if part then
                    local worldDist = r and (r.Position - part.Position).Magnitude or 0
                    if worldDist <= maxWorldRange then
                        local aimPoint = Helper.computeAimPoint(part, true)
                        local screenPos, onScreen = Camera:WorldToViewportPoint(aimPoint)
                        if onScreen then
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if screenDist < nearestScreenDist then
                                nearestScreenDist = screenDist
                                nearestPart = part
                                nearestAimPoint = aimPoint
                            end
                        end
                    end
                end
            end
        end
    end
    return nearestPart, nearestAimPoint
end

-- ============================================================
-- BARITONE
-- ============================================================
Helper.Baritone = { Version = "1.4.0" }

local _baritone = Helper.Baritone
local BC = {
    walkSpeed = 14, searchRange = 250, avoidWater = false, avoidCliffs = true,
    jumpHeight = 3, cliffDrop = 6, targetReachDistance = 5, tickRate = 0.05,
    escapeDuration = 3, escapeJumpCooldown = 0.6, pendingJumpCooldown = 0.35,
    dirUpdateInterval = 0.25, targetSearchInterval = 0.5, wanderInterval = 4,
    enabled = false, debug = false,
    TREE_NAMES = {
        ["Small Tree"]=true, ["Apple Tree"]=true, ["Orange Tree"]=true,
        ["Lemon Tree"]=true, ["Banana Tree"]=true, ["Coconut Tree"]=true,
        ["Volcanic Tree"]=true, ["Swoll Tree"]=true, ["Palm Tree"]=true,
        ["Jungle Tree"]=true, ["Odd Tree"]=true,
    },
    DIR_ANGLES = { 0, 15, -15, 30, -30, 45, -45, 60, -60, 90, -90, 120, -120, 150, -150, 180 },
}
local BState = {
    running=false, thread=nil, currentTarget=nil, currentDir=nil, pendingJump=false,
    lastJump=0, lastPos=nil, lastMoveMethod="move", methodSwitchUntil=0,
    lastTargetSearch=0, lastDirUpdate=0, escapeUntil=0, wanderDir=nil,
    wanderChangeAt=0, stopCallbacks={}, moveFailCount=0, lastLogTime=0,
}

local function bMakeParams()
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.IgnoreWater = false
    local list = {}
    if plr.Character then table.insert(list, plr.Character) end
    p.FilterDescendantsInstances = list
    return p
end
local function bRaycast(from, to)
    if not from or not to then return nil end
    local ok, hit = pcall(function() return workspace:Raycast(from, to - from, bMakeParams()) end)
    return ok and hit or nil
end
local function bGetGroundY(pos, maxDist)
    if not pos then return nil end
    local from = pos + Vector3.new(0, maxDist / 2, 0)
    local hit = bRaycast(from, from + Vector3.new(0, -maxDist, 0))
    if hit then return hit.Position.Y end
    return nil
end
local function bCheckWaterAt(pos)
    local ok, mat = pcall(function()
        return workspace.Terrain:ReadVoxels(
            Region3.new(pos - Vector3.new(1, 0.5, 1), pos + Vector3.new(1, 0.5, 1)), 4)
    end)
    if not ok or not mat then return false end
    for x = 1, mat.Size.X do for y = 1, mat.Size.Y do for z = 1, mat.Size.Z do
        if mat[x][y][z] == Enum.Material.Water then return true end
    end end end
    return false
end
local function bFindTree()
    local folder = workspace:FindFirstChild("Resources")
    if not folder then return nil end
    local myRoot = Helper.getRoot()
    if not myRoot then return nil end
    local myPos = myRoot.Position
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Model") and BC.TREE_NAMES[obj.Name] then
            local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if pp then
                local d = (pp.Position - myPos).Magnitude
                if d <= BC.searchRange and d < bestDist then best, bestDist = obj, d end
            end
        end
    end
    return best, bestDist
end
local function bIsTreeAlive(tree)
    if not tree or not tree.Parent then return false end
    return tree:IsDescendantOf(workspace)
end
local function bGetTargetDir(tree)
    if not tree then return nil, 0 end
    local myRoot = Helper.getRoot()
    if not myRoot then return nil, 0 end
    local pp = tree.PrimaryPart or tree:FindFirstChildWhichIsA("BasePart")
    if not pp then return nil, 0 end
    local flat = Vector3.new(pp.Position.X - myRoot.Position.X, 0, pp.Position.Z - myRoot.Position.Z)
    local dist = flat.Magnitude
    if dist < 0.5 then return nil, 0 end
    return flat.Unit, dist
end
local function bEvalDir(myRoot, dir, inWater)
    local myY = myRoot.Position.Y
    local origin = myRoot.Position + Vector3.new(0, 1, 0)
    local score = 10
    local needJump = false
    local hit1 = bRaycast(origin, origin + dir * 2)
    if hit1 then
        local diff = hit1.Position.Y - myY
        if diff > BC.jumpHeight + 1 then score = score - 25
        elseif diff > 0.5 then needJump = true; score = score - 4
        else score = score - 12 end
    end
    if BC.avoidCliffs then
        local ahead = myRoot.Position + dir * 3
        local groundY = bGetGroundY(ahead, 25)
        if groundY then
            local drop = myY - groundY
            if drop > BC.cliffDrop then score = score - 30
            elseif drop > 3 then score = score - 8 end
        else score = score - 40 end
    end
    if BC.avoidWater and not inWater then
        local ahead = myRoot.Position + dir * 2
        if bCheckWaterAt(ahead) then score = score - 20 end
    end
    return score, needJump
end
local function bFindBestDir(myRoot, goalDir)
    if not goalDir then return nil, false end
    local inWater = bCheckWaterAt(myRoot.Position)
    local bestDir, bestScore, bestJump = nil, -math.huge, false
    for _, deg in ipairs(BC.DIR_ANGLES) do
        local rad = math.rad(deg)
        local cos, sin = math.cos(rad), math.sin(rad)
        local testDir = Vector3.new(
            goalDir.X * cos - goalDir.Z * sin, 0,
            goalDir.X * sin + goalDir.Z * cos).Unit
        local score, needJump = bEvalDir(myRoot, testDir, inWater)
        score = score - math.abs(deg) * 0.1
        if score > bestScore then bestScore = score; bestDir = testDir; bestJump = needJump end
    end
    if not bestDir then return goalDir, false end
    return bestDir, bestJump
end
local function bMove(h, r, d) h:Move(d, false) end
local function bMoveTo(h, r, d) h:MoveTo(r.Position + d * 12) end
local function bVelocity(r, d)
    local bv = r:FindFirstChild("__BaritoneBV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "__BaritoneBV"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.P = 5000
        bv.Parent = r
    end
    bv.Velocity = Vector3.new(d.X, 0, d.Z) * BC.walkSpeed
end
local function bClearVel(r)
    if not r then return end
    local bv = r:FindFirstChild("__BaritoneBV")
    if bv then bv:Destroy() end
end
local function bMoveHumanoid(h, r, d)
    if tick() < BState.methodSwitchUntil then
        if BState.lastMoveMethod == "velocity" then bVelocity(r, d)
        elseif BState.lastMoveMethod == "moveto" then bMoveTo(h, r, d)
        else bMove(h, r, d) end
        return
    end
    bClearVel(r)
    BState.lastMoveMethod = "move"
    bMove(h, r, d)
end
local function bStop(h, r)
    bClearVel(r)
    if h then h:Move(Vector3.zero, false) end
end
local function bFindEscapeDir(myRoot)
    local bestDir, bestY = nil, myRoot.Position.Y
    for i = 0, 15 do
        local angle = i * math.pi / 8
        local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
        local ahead = myRoot.Position + dir * 4
        local gY = bGetGroundY(ahead, 25)
        if gY then
            local hit = bRaycast(myRoot.Position + Vector3.new(0, 1, 0),
                                 myRoot.Position + Vector3.new(0, 1, 0) + dir * 3)
            local blocked = hit ~= nil and (hit.Position.Y - myRoot.Position.Y) > BC.jumpHeight + 1
            if not blocked and gY > bestY then bestY = gY; bestDir = dir end
        end
    end
    return bestDir
end
local function bTick()
    if not BC.enabled then return end
    if _baritone._resetWander then
        _baritone._resetWander = false
        BState.currentTarget = nil
        BState.currentDir = nil
        BState.wanderDir = nil
        BState.wanderChangeAt = 0
        BState.lastPos = nil
        BState.moveFailCount = 0
    end
    local myRoot = Helper.getRoot()
    local humanoid = Helper.getHumanoid()
    if not myRoot or not humanoid then return end
    if humanoid.Health <= 0 then return end
    local now = tick()
    local myPos = myRoot.Position
    if BState.lastPos then
        local moved = (myPos - BState.lastPos).Magnitude
        if moved < 0.15 then
            BState.moveFailCount = BState.moveFailCount + 1
            if BState.moveFailCount >= 3 and now > BState.methodSwitchUntil then
                local methods = {"moveto","velocity","move"}
                local idx = table.find(methods, BState.lastMoveMethod) or 1
                BState.lastMoveMethod = methods[(idx % #methods) + 1]
                BState.methodSwitchUntil = now + 2
                BState.moveFailCount = 0
            end
        else BState.moveFailCount = 0 end
    end
    BState.lastPos = myPos
    if now < BState.escapeUntil then
        local ed = bFindEscapeDir(myRoot)
        if ed then humanoid.WalkSpeed = BC.walkSpeed + 2; bMoveHumanoid(humanoid, myRoot, ed)
        else bStop(humanoid, myRoot) end
        if now - BState.lastJump > BC.escapeJumpCooldown then
            humanoid.Jump = true; BState.lastJump = now
        end
        return
    end
    humanoid.WalkSpeed = BC.walkSpeed
    if now - BState.lastTargetSearch > BC.targetSearchInterval then
        BState.lastTargetSearch = now
        if BState.currentTarget and not bIsTreeAlive(BState.currentTarget) then BState.currentTarget = nil end
        if not BState.currentTarget then
            local tree, dist = bFindTree()
            if tree then BState.currentTarget = tree end
        end
    end
    if not BState.currentTarget then
        if not BState.wanderDir or now - BState.wanderChangeAt > BC.wanderInterval then
            local angle = math.random() * math.pi * 2
            BState.wanderDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
            BState.wanderChangeAt = now
        end
        bMoveHumanoid(humanoid, myRoot, BState.wanderDir)
        return
    end
    local goalDir, dist = bGetTargetDir(BState.currentTarget)
    if not goalDir or dist < BC.targetReachDistance then bStop(humanoid, myRoot); return end
    if now - BState.lastDirUpdate > BC.dirUpdateInterval or not BState.currentDir then
        BState.lastDirUpdate = now
        local bestDir, needJump = bFindBestDir(myRoot, goalDir)
        BState.currentDir = bestDir or goalDir
        BState.pendingJump = needJump
    end
    if BState.currentDir then
        bMoveHumanoid(humanoid, myRoot, BState.currentDir)
        if BState.pendingJump and now - BState.lastJump > BC.pendingJumpCooldown then
            humanoid.Jump = true; BState.lastJump = now
        end
    else bStop(humanoid, myRoot) end
end

function _baritone.Start()
    if BState.running then return end
    BState.running = true
    BC.enabled = true
    BState.lastPos = nil; BState.moveFailCount = 0; BState.methodSwitchUntil = 0
    BState.lastMoveMethod = "move"; BState.escapeUntil = 0
    BState.wanderDir = nil; BState.wanderChangeAt = 0
    BState.currentDir = nil; BState.lastLogTime = 0
    BState.thread = task.spawn(function()
        while BState.running do
            local ok, err = pcall(bTick)
            task.wait(BC.tickRate)
        end
        local h = Helper.getHumanoid()
        local r = Helper.getRoot()
        if h then h:Move(Vector3.zero, false) end
        bClearVel(r)
    end)
end

function _baritone.Stop()
    if not BState.running then return end
    BState.running = false
    BC.enabled = false
    BState.currentTarget = nil
    BState.currentDir = nil
    if BState.thread then pcall(task.cancel, BState.thread); BState.thread = nil end
    local h = Helper.getHumanoid()
    local r = Helper.getRoot()
    if h then h:Move(Vector3.zero, false) end
    bClearVel(r)
end

function _baritone.IsRunning() return BState.running end
function _baritone.Set(k, v) if BC[k] == nil then return false end BC[k] = v return true end
function _baritone.Get(k) return BC[k] end
function _baritone.GetCurrentTarget() return BState.currentTarget end

-- ============================================================
-- FULLBRIGHT
-- ============================================================
local _fbOriginal = nil

function Helper.enableFullbright()
    if not _fbOriginal then
        _fbOriginal = {
            Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
            GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart, FogColor = Lighting.FogColor,
        }
    end
    Lighting.Ambient = Color3.fromRGB(200,200,200)
    Lighting.OutdoorAmbient = Color3.fromRGB(200,200,200)
    Lighting.Brightness = 3
    Lighting.ClockTime = 14
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
    Lighting.FogColor = Color3.fromRGB(200,200,200)
    for _, c in ipairs(Lighting:GetChildren()) do
        if c:IsA("Atmosphere") then c.Parent = nil end
    end
end

function Helper.disableFullbright()
    if not _fbOriginal then return end
    Lighting.Ambient = _fbOriginal.Ambient
    Lighting.OutdoorAmbient = _fbOriginal.OutdoorAmbient
    Lighting.Brightness = _fbOriginal.Brightness
    Lighting.ClockTime = _fbOriginal.ClockTime
    Lighting.GlobalShadows = _fbOriginal.GlobalShadows
    Lighting.FogEnd = _fbOriginal.FogEnd
    Lighting.FogStart = _fbOriginal.FogStart
    Lighting.FogColor = _fbOriginal.FogColor
    _fbOriginal = nil
end

-- ============================================================
-- AUTO HEAL BURST
-- ============================================================
function Helper.startAutoHeal(getState, packetsRef)
    local eating = false
    local S = getState
    task.spawn(function()
        while true do
            if S().autoheal then
                local hp = Helper.getHP()
                local maxHP = Helper.getMaxHP()
                if hp and maxHP > 0 then
                    local hpPct = (hp / maxHP) * 100
                    if hpPct < S().autoheal_eat_below then eating = true end
                    if hpPct >= S().autoheal_eat_until then eating = false end

                    if eating then
                        for i = 1, S().autoheal_burst_size do
                            local curPct = Helper.getHPPercent()
                            if curPct >= S().autoheal_eat_until then
                                eating = false
                                break
                            end
                            local slot = Helper.findBestFoodSlot()
                            if not slot then break end
                            Helper.eatFood(slot)
                            task.wait(S().autoheal_eat_delay)
                        end
                        task.wait(S().autoheal_burst_wait)
                    else
                        task.wait(0.1)
                    end
                else
                    task.wait(0.2)
                end
            else
                task.wait(0.2)
                eating = false
            end
        end
    end)
end

-- ============================================================
-- AUTO DROP
-- ============================================================
function Helper.dropItem(itemName)
    if not itemName or itemName == "" then return false end
    local list = Helper.getInventoryList()
    if not list then return false end
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == itemName then
            if packets and packets.DropBagItem and packets.DropBagItem.send then
                pcall(function() packets.DropBagItem.send(child.LayoutOrder) end)
                return true
            end
            return false
        end
    end
    return false
end

-- ============================================================
-- PICKUP
-- ============================================================
function Helper.pickup(entityid)
    if packets and packets.Pickup and packets.Pickup.send then
        packets.Pickup.send(entityid)
    end
end

return Helper
