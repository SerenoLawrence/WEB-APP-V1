Skip to content
Sign in
Sign up
Instantly share code, notes, and snippets.

hanstoribiocanaan/script.lua
Last active 9 hours ago
Clone this repository at &lt;script src=&quot;https://gist.github.com/hanstoribiocanaan/48356d9b1a0fe11439650c350635c9b9.js&quot;&gt;&lt;/script&gt;
<script src="https://gist.github.com/hanstoribiocanaan/48356d9b1a0fe11439650c350635c9b9.js"></script>
Code
Revisions
6
Steal An Egg Discord regeneration tracker - Delta/Xeno compatible
script.lua
--[[
    STEAL AN EGG - DISCORD REGEN TRACKER
    No contiene nombres de huevos, rarezas ni areas escritos a mano.
    Lee el snapshot de EggWorld, sus eventos y los catalogos que el cliente
    del juego ya tiene cargados. El mapa fisico es solo el ultimo respaldo.
--]]

-- Bootstrap compatible con executors que inyectan antes de que LocalPlayer
-- y PlayerGui esten disponibles (comun en Delta para Android/Windows).
if not game:IsLoaded() then
    game.Loaded:Wait()
end
local __bootstrapPlayers = game:GetService("Players")
while not __bootstrapPlayers.LocalPlayer do
    task.wait(0.1)
end

local __runOk, __runError = xpcall(function()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local CONFIG_FILE = "StealAnEgg_WebhookConfig.json"
local EXPECTED_PLACE_ID = 107778070777162
local EMBED_DESCRIPTION_LIMIT = 3900
local EMBED_TOTAL_SAFE_LIMIT = 5600

local ScriptRunning = true
local Connections = {}
local EventPayloads = {}
local LastSnapshotResults
local CatalogScanNotes = {}
local LastSignature = ""
local LastSuccessfulSend = 0
local LastRegenSend = 0
local LastRegenAttempt = 0
local ExpectedAreaCount = 0
local ExpectedEggsByArea = {}
local RegenLastActivity = 0
local SnapshotMonitorBaseline
local SnapshotMonitorCandidate = ""
local SnapshotMonitorCandidateSeen = 0
local LastAutoSnapshotSignature = ""
local RegenScheduled = false
local RegenRevision = 0
local LastCountdownValue
local PendingInvokes = {}
local Progress = function() end

local Environment = (getgenv and getgenv()) or _G
if Environment.__STEAL_AN_EGG_TRACKER_STOP then
    pcall(Environment.__STEAL_AN_EGG_TRACKER_STOP)
end

--------------------------------------------------------------------------
-- RUTAS REALES DE RED DEL JUEGO
--------------------------------------------------------------------------
local Packages
local Networking
local RF_FieldSnapshot
local RF_EggRecord
local RE_Batch
local RE_Shifted
local RE_Gone
local RE_Countdown
local RE_Rarities
local RE_ZoneAnchor

local function Net(name)
    return Networking and Networking:FindFirstChild(name)
end

local function ResolveNetworkRoutes()
    Packages = ReplicatedStorage:FindFirstChild("Packages")
    Networking = Packages and Packages:FindFirstChild("Networking")
    RF_FieldSnapshot = Net("RF/EggWorld/AskFieldEggSnapshot") or RF_FieldSnapshot
    RF_EggRecord = Net("RF/EggWorld/AskEggRecord") or RF_EggRecord
    RE_Batch = Net("RE/EggWorld/FieldEggBatchShifted") or RE_Batch
    RE_Shifted = Net("RE/EggWorld/FieldEggShifted") or RE_Shifted
    RE_Gone = Net("RE/EggWorld/FieldEggGone") or RE_Gone
    RE_Countdown = Net("RE/EggWorld/FieldEggCycleCountdown") or RE_Countdown
    RE_Rarities = Net("RE/EggWorld/FieldEggRaritiesShown") or RE_Rarities
    RE_ZoneAnchor = Net("RE/ZoneProbe/AnchorForZone") or RE_ZoneAnchor
    return Networking ~= nil
end

ResolveNetworkRoutes()

local function InvokeWithTimeout(pendingKey, remote, timeoutSeconds, ...)
    if not remote then
        return false, "Remote no disponible"
    end
    if PendingInvokes[pendingKey] then
        return false, "La consulta anterior sigue pendiente"
    end

    local arguments = table.pack(...)
    local completed = false
    local packedResult
    PendingInvokes[pendingKey] = true

    task.spawn(function()
        packedResult = table.pack(pcall(function()
            return remote:InvokeServer(table.unpack(arguments, 1, arguments.n))
        end))
        completed = true
        PendingInvokes[pendingKey] = nil
    end)

    local deadline = os.clock() + timeoutSeconds
    while ScriptRunning and not completed and os.clock() < deadline do
        task.wait(0.05)
    end
    if not completed then
        return false, "Tiempo de espera agotado"
    end
    if not packedResult[1] then
        return false, tostring(packedResult[2])
    end

    local values = { n = packedResult.n - 1 }
    for index = 2, packedResult.n do
        values[index - 1] = packedResult[index]
    end
    return true, values
end

--------------------------------------------------------------------------
-- WEBHOOK Y CONFIGURACION
--------------------------------------------------------------------------
local function SanitizeWebhookUrl(rawUrl)
    if type(rawUrl) ~= "string" then
        return ""
    end
    local compact = rawUrl:gsub("%s+", "")
    if compact == "" then
        return ""
    end

    if compact:find("discord%.com/api/webhooks/") or compact:find("discordapp%.com/api/webhooks/") then
        if not compact:match("^https?://") then
            return "https://" .. compact:match("([%w%.]*discord[%w%.]*%.com/api/webhooks/.+)")
        end
        return compact
    end

    local webhookPath = compact:match("webhooks/(%d+/.+)")
    if webhookPath then
        return "https://discord.com/api/webhooks/" .. webhookPath
    end

    local idToken = compact:match("^(%d+/[^%s]+)$")
    if idToken then
        return "https://discord.com/api/webhooks/" .. idToken
    end

    return compact
end

local function SanitizeBotUserId(rawId)
    if type(rawId) ~= "string" and type(rawId) ~= "number" then
        return ""
    end
    local digits = tostring(rawId):gsub("%D", "")
    if #digits >= 15 and #digits <= 22 then
        return digits
    end
    return ""
end

local Config = {
    WebhookUrl = "",
    BotUserId = "",
    AutoSendEnabled = true,
    KnownAreaCount = 0,
    KnownEggsByArea = {}
}

local function LoadConfig()
    local loadedFromFile = false
    if isfile and readfile then
        pcall(function()
            if isfile(CONFIG_FILE) then
                local content = readfile(CONFIG_FILE)
                if content and content ~= "" then
                    local saved = HttpService:JSONDecode(content)
                    if type(saved) == "table" then
                        if saved.WebhookUrl and type(saved.WebhookUrl) == "string" and saved.WebhookUrl ~= "" then
                            Config.WebhookUrl = SanitizeWebhookUrl(saved.WebhookUrl)
                        end
                        if saved.BotUserId and type(saved.BotUserId) == "string" and saved.BotUserId ~= "" then
                            Config.BotUserId = SanitizeBotUserId(saved.BotUserId)
                        end
                        if type(saved.AutoSendEnabled) == "boolean" then
                            Config.AutoSendEnabled = saved.AutoSendEnabled
                        end
                        local knownAreaCount = tonumber(saved.KnownAreaCount)
                        if knownAreaCount and knownAreaCount > 0 then
                            Config.KnownAreaCount = math.floor(knownAreaCount)
                            ExpectedAreaCount = Config.KnownAreaCount
                        end
                        if type(saved.KnownEggsByArea) == "table" then
                            for area, count in pairs(saved.KnownEggsByArea) do
                                local numericCount = tonumber(count)
                                if type(area) == "string" and numericCount and numericCount > 0 then
                                    ExpectedEggsByArea[area] = math.floor(numericCount)
                                end
                            end
                            Config.KnownEggsByArea = ExpectedEggsByArea
                        end
                        loadedFromFile = true
                    end
                end
            end
        end)
    end

    local env = (getgenv and getgenv()) or _G
    if env and type(env.__STEAL_AN_EGG_SAVED_CONFIG) == "table" then
        local saved = env.__STEAL_AN_EGG_SAVED_CONFIG
        if (not Config.WebhookUrl or Config.WebhookUrl == "") and saved.WebhookUrl then
            Config.WebhookUrl = SanitizeWebhookUrl(saved.WebhookUrl)
        end
        if (not Config.BotUserId or Config.BotUserId == "") and saved.BotUserId then
            Config.BotUserId = SanitizeBotUserId(saved.BotUserId)
        end
        if not loadedFromFile and type(saved.AutoSendEnabled) == "boolean" then
            Config.AutoSendEnabled = saved.AutoSendEnabled
        end
        if not loadedFromFile then
            local knownAreaCount = tonumber(saved.KnownAreaCount)
            if knownAreaCount and knownAreaCount > 0 then
                Config.KnownAreaCount = math.floor(knownAreaCount)
                ExpectedAreaCount = Config.KnownAreaCount
            end
            if type(saved.KnownEggsByArea) == "table" then
                for area, count in pairs(saved.KnownEggsByArea) do
                    local numericCount = tonumber(count)
                    if type(area) == "string" and numericCount and numericCount > 0 then
                        ExpectedEggsByArea[area] = math.floor(numericCount)
                    end
                end
                Config.KnownEggsByArea = ExpectedEggsByArea
            end
        end
    end
end

local function SaveConfig()
    local env = (getgenv and getgenv()) or _G
    if env then
        env.__STEAL_AN_EGG_SAVED_CONFIG = {
            WebhookUrl = Config.WebhookUrl,
            BotUserId = Config.BotUserId,
            AutoSendEnabled = Config.AutoSendEnabled,
            KnownAreaCount = Config.KnownAreaCount,
            KnownEggsByArea = ExpectedEggsByArea
        }
    end

    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end)
    end
end

LoadConfig()

local httpRequest = (syn and syn.request)
    or (http and http.request)
    or http_request
    or (fluxus and fluxus.request)
    or request

local function SendWebhookBody(body, contentType)
    if not ScriptRunning then
        return false, "Script detenido."
    end
    local url = SanitizeWebhookUrl(Config.WebhookUrl)
    if url == "" then
        return false, "Pega una URL valida de webhook de Discord."
    end
    if not httpRequest then
        return false, "Xeno no expuso request/http_request."
    end

    local ok, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = contentType },
            Body = body
        })
    end)
    if not ok then
        return false, "Error de conexion: " .. tostring(response)
    end

    local code = tonumber(response and (response.StatusCode or response.Status or response.status_code))
    if code and code >= 200 and code < 300 then
        return true, "Enviado."
    end
    local body = response and (response.Body or response.body) or "sin cuerpo"
    return false, string.format("Discord HTTP %s: %s", tostring(code), tostring(body))
end

local function PostDiscord(text)
    local mention = Config.BotUserId ~= "" and "<@" .. Config.BotUserId .. ">\n" or ""
    local allowedMentions = { parse = {} }
    if Config.BotUserId ~= "" then
        allowedMentions.users = { Config.BotUserId }
    end
    return SendWebhookBody(HttpService:JSONEncode({
        content = mention .. text,
        username = "Steal An Egg Tracker",
        allowed_mentions = allowedMentions
    }), "application/json")
end

local function SplitForEmbeds(text)
    local chunks = {}
    local current = ""

    local function AppendPiece(piece)
        while #piece > EMBED_DESCRIPTION_LIMIT do
            local available = EMBED_DESCRIPTION_LIMIT - #current
            if available > 0 then
                current = current .. piece:sub(1, available)
                piece = piece:sub(available + 1)
            end
            table.insert(chunks, current)
            current = ""
        end
        if #current + #piece > EMBED_DESCRIPTION_LIMIT then
            table.insert(chunks, (current:gsub("%s+$", "")))
            current = ""
        end
        current = current .. piece
    end

    for line in (text .. "\n"):gmatch("(.-\n)") do
        AppendPiece(line)
    end
    if current ~= "" then
        table.insert(chunks, (current:gsub("%s+$", "")))
    end
    return chunks
end

local function PostSingleReport(reportText, totalEggs, areaCount)
    if Config.BotUserId == "" then
        return false, "Pega el ID de usuario del bot de Discord."
    end
    local mention = "<@" .. Config.BotUserId .. ">"
    if #reportText <= EMBED_TOTAL_SAFE_LIMIT then
        local embeds = {}
        for _, description in ipairs(SplitForEmbeds(reportText)) do
            table.insert(embeds, {
                description = description,
                color = 3066993
            })
        end
        if embeds[1] then
            embeds[1].title = "Steal An Egg - regeneracion"
        end
        return SendWebhookBody(HttpService:JSONEncode({
            content = mention,
            username = "Steal An Egg Tracker",
            embeds = embeds,
            allowed_mentions = { parse = {}, users = { Config.BotUserId } }
        }), "application/json")
    end

    -- Si supera el limite combinado de embeds, el listado completo viaja como
    -- TXT adjunto dentro de la misma publicacion (una sola solicitud/mensaje).
    local boundary = "----------------StealEgg" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
    local payload = HttpService:JSONEncode({
        content = string.format(
            "%s\nNueva regeneracion: %d huevos en %d areas. El listado completo esta adjunto.",
            mention, totalEggs, areaCount
        ),
        username = "Steal An Egg Tracker",
        allowed_mentions = { parse = {}, users = { Config.BotUserId } },
        attachments = {
            { id = 0, filename = "huevos_del_mapa.txt", description = "Listado completo por area" }
        }
    })
    local multipartBody = table.concat({
        "--" .. boundary,
        "Content-Disposition: form-data; name=\"payload_json\"",
        "Content-Type: application/json",
        "",
        payload,
        "--" .. boundary,
        "Content-Disposition: form-data; name=\"files[0]\"; filename=\"huevos_del_mapa.txt\"",
        "Content-Type: text/plain; charset=utf-8",
        "",
        reportText,
        "--" .. boundary .. "--",
        ""
    }, "\r\n")
    return SendWebhookBody(multipartBody, "multipart/form-data; boundary=" .. boundary)
end

--------------------------------------------------------------------------
-- LECTOR GENERICO DEL ESQUEMA REPLICADO
--------------------------------------------------------------------------
local function NormalizeKey(value)
    return (string.lower(tostring(value or "")):gsub("[^%w]", ""))
end

local function KeySet(list)
    local result = {}
    for _, key in ipairs(list) do
        result[NormalizeKey(key)] = true
    end
    return result
end

-- Son nombres de campos del protocolo, no nombres de contenido del juego.
local NameFieldPriority = {
    "EggName", "DisplayName", "PetName", "AssetName", "Name", "Species",
    "PetType", "AssetCategory", "Category", "Kind", "EggType", "EggKind",
    "PetKind", "Egg", "Pet"
}
local NameKeys = KeySet(NameFieldPriority)
local RarityKeys = KeySet({
    "Rarity", "RarityName", "Tier", "RarityId", "RarityKey",
    "RarityIndex", "EggRarity", "Rarety"
})
local AreaKeys = KeySet({
    "Area", "AreaName", "AreaId", "Zone", "ZoneName", "ZoneId",
    "AreaKey", "ZoneKey", "Biome", "BiomeName", "BiomeId", "BiomeKey",
    "Field", "FieldId", "Region", "World"
})
local IdKeys = KeySet({
    "Id", "Uid", "UUID", "Guid", "EggId", "FieldEggId", "FieldEggKey",
    "RecordId", "InstanceId", "SpawnId", "Key"
})
local UniqueIdKeys = KeySet({
    "Uid", "UUID", "Guid", "FieldEggId", "FieldEggKey", "RecordId",
    "InstanceId", "SpawnId"
})
local SlotKeys = KeySet({
    "NestId", "SlotId", "Nest", "Slot", "SpawnSlot", "FieldSlot"
})
-- EggWorld usa BaseMutation como parte de la identidad base del animal.
-- Mutation/Mutations son modificaciones cosmeticas independientes y no
-- forman el nombre base.
local BaseNameQualifierPriority = { "BaseMutation" }
local MutationKeys = KeySet({
    "Mutation", "MutationName", "Mutations", "Variant", "Modifier"
})
local PositionKeys = KeySet({
    "Position", "Pos", "WorldPosition", "Location", "CFrame",
    "SpawnPosition", "SpawnCFrame", "BottomCFrame", "BoundsCFrame",
    "Pivot", "Origin", "Point", "Anchor"
})
local ContainerKeys = KeySet({
    "Eggs", "FieldEggs", "Items", "Records", "Data", "Snapshot", "Areas",
    "Zones", "Biomes", "Results", "Payload", "List", "Map", "ByArea"
})
local MetadataKeys = KeySet({
    "Duration", "Mutation", "Mutations", "Personality", "Scale", "Weight",
    "Chance", "Odds", "Probability", "Size", "Amount", "Count", "Index",
    "Enabled", "Visible", "Cooldown", "Price", "Cost", "Income", "Speed"
})

local EggCatalog = {}
local AreaCatalog = {}
local AreaAnchors = {}
local CatalogBuiltAt = 0

local function CleanText(value)
    if value == nil then
        return nil
    end
    local text = tostring(value):gsub("<.->", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text ~= "" and text or nil
end

local function ScalarText(value)
    local valueType = typeof(value)
    if valueType == "string" or valueType == "number" then
        return CleanText(value)
    elseif valueType == "EnumItem" then
        return CleanText(value.Name)
    end
    return nil
end

local function ToPosition(value)
    local valueType = typeof(value)
    if valueType == "Vector3" then
        return value
    elseif valueType == "CFrame" then
        return value.Position
    elseif valueType == "Instance" and value:IsA("BasePart") then
        return value.Position
    elseif valueType == "Instance" and value:IsA("Attachment") then
        return value.WorldPosition
    elseif type(value) == "table" then
        local x = tonumber(value.X or value.x or value[1])
        local y = tonumber(value.Y or value.y or value[2])
        local z = tonumber(value.Z or value.z or value[3])
        if x and y and z then
            return Vector3.new(x, y, z)
        end
    end
    return nil
end

local function ExtractField(record, accepted)
    if type(record) ~= "table" then
        return nil
    end
    for key, value in pairs(record) do
        if accepted[NormalizeKey(key)] then
            return value
        end
    end
    return nil
end

local function ExtractFieldByPriority(record, priority)
    if type(record) ~= "table" then
        return nil, nil
    end
    for _, wantedKey in ipairs(priority) do
        local wanted = NormalizeKey(wantedKey)
        for key, value in pairs(record) do
            if NormalizeKey(key) == wanted then
                return value, tostring(key)
            end
        end
    end
    return nil, nil
end

local function HasAnyField(record, accepted)
    if type(record) ~= "table" then
        return false
    end
    for key in pairs(record) do
        if accepted[NormalizeKey(key)] then
            return true
        end
    end
    return false
end

local function ResolveCatalogText(value, catalog)
    local text = ScalarText(value)
    if not text then
        return nil
    end
    local entry = catalog[text]
    if entry then
        return entry.Name or ScalarText(entry)
    end
    return text
end

local function AddAreaAnchor(areaValue, position)
    local areaName = ResolveCatalogText(areaValue, AreaCatalog)
    if areaName and position then
        table.insert(AreaAnchors, { Name = areaName, Position = position })
    end
end

local function HarvestCatalog(root, context, maxDepth)
    local visited = {}
    local nodes = 0

    local function Walk(value, depth, keyHint)
        if type(value) ~= "table" or visited[value] or depth > maxDepth or nodes > 8000 then
            return
        end
        visited[value] = true
        nodes = nodes + 1

        local id = ScalarText(ExtractField(value, IdKeys)) or ScalarText(keyHint)
        local name = ScalarText(ExtractFieldByPriority(value, NameFieldPriority))
        local rarity = ScalarText(ExtractField(value, RarityKeys))
        local area = ExtractField(value, AreaKeys)
        local position = ToPosition(ExtractField(value, PositionKeys))

        if name and MetadataKeys[NormalizeKey(name)] then
            name = nil
        end

        if id and name and (context == "area" or (not rarity and not area and position)) then
            AreaCatalog[id] = { Name = name, Position = position }
            AddAreaAnchor(name, position)
        end
        if id and (name or rarity or area) and (context == "egg" or rarity ~= nil) then
            EggCatalog[id] = EggCatalog[id] or {}
            EggCatalog[id].Name = EggCatalog[id].Name or name
            EggCatalog[id].Rarity = EggCatalog[id].Rarity or rarity
            EggCatalog[id].Area = EggCatalog[id].Area or area
        end

        for key, child in pairs(value) do
            if type(child) == "table" then
                Walk(child, depth + 1, key)
            end
        end
    end
    Walk(root, 0, nil)
end

local function ModuleContext(moduleName)
    local lower = string.lower(moduleName)
    local isDirectory = lower:find("directory", 1, true)
        or lower:find("catalog", 1, true)
        or lower:find("config", 1, true)
        or lower:find("data", 1, true)
        or lower:find("roster", 1, true)
    if isDirectory and (lower:find("area", 1, true) or lower:find("zone", 1, true)
        or lower:find("biome", 1, true)) then
        return "area"
    end
    if isDirectory and (lower:find("egg", 1, true) or lower:find("pet", 1, true)) then
        return "egg"
    end
    return nil
end

local function RefreshRuntimeCatalogs(force)
    if not force and os.clock() - CatalogBuiltAt < 20 then
        return
    end
    CatalogBuiltAt = os.clock()

    if getloadedmodules then
        local ok, modules = pcall(getloadedmodules)
        if ok and type(modules) == "table" then
            for _, module in ipairs(modules) do
                if typeof(module) == "Instance" and module:IsA("ModuleScript") then
                    local context = ModuleContext(module.Name)
                    if context then
                        local required, data = pcall(require, module)
                        if required and type(data) == "table" then
                            HarvestCatalog(data, context, 8)
                        end
                    end
                end
            end
        end
    end

end

local function ResolveArea(value)
    local text = ScalarText(value)
    if not text then
        return nil
    end
    local catalogued = AreaCatalog[text]
    return catalogued and catalogued.Name or text
end

local function ResolveEggName(value)
    local text = ScalarText(value)
    if not text then
        return nil
    end
    local catalogued = EggCatalog[text]
    return catalogued and catalogued.Name or text
end

local function IsEmptyBaseQualifier(value)
    local key = NormalizeKey(value)
    return key == "" or key == "none" or key == "normal"
        or key == "default" or key == "base" or key == "standard"
end

local function ComposeCanonicalEggName(name, baseQualifier)
    name = CleanText(name)
    baseQualifier = CleanText(baseQualifier)
    if not name or not baseQualifier or IsEmptyBaseQualifier(baseQualifier) then
        return name, false
    end

    local nameKey = NormalizeKey(name)
    local qualifierKey = NormalizeKey(baseQualifier)
    if nameKey:find(qualifierKey, 1, true) then
        return name, false
    end

    -- BaseMutation es una parte del nombre base en el protocolo de EggWorld;
    -- no es la rareza ni la lista de modificaciones cosmeticas del huevo.
    return baseQualifier .. " " .. name, true
end

local function AreaFromNearestAnchor(position)
    if not position then
        return nil
    end
    local nearestName, nearestDistance
    for _, anchor in ipairs(AreaAnchors) do
        local distance = (anchor.Position - position).Magnitude
        if not nearestDistance or distance < nearestDistance then
            nearestName = anchor.Name
            nearestDistance = distance
        end
    end
    return nearestName
end

local function IsGenericObjectName(name)
    local key = NormalizeKey(name)
    return key == "" or key == "egg" or key == "fieldegg"
        or key == "carryareaegg" or key == "smartpromptpart"
        or key == "model" or key == "part"
end

local function NameFieldRank(fieldName)
    local key = NormalizeKey(fieldName)
    if key == "eggname" or key == "displayname"
        or key == "petname" or key == "assetname" then
        return 4
    elseif key == "name" or key == "species" then
        return 3
    end
    return 2
end

local function ResolveRecordName(record, baseQualifier)
    local selectedName, selectedRaw, selectedField, selectedRank, selectedComposed

    for _, wantedField in ipairs(NameFieldPriority) do
        local wantedKey = NormalizeKey(wantedField)
        for key, value in pairs(record) do
            if NormalizeKey(key) == wantedKey then
                local raw = ScalarText(value)
                local candidate = ResolveEggName(raw)
                if candidate and not IsGenericObjectName(candidate)
                    and not MetadataKeys[NormalizeKey(candidate)] then
                    local composed
                    candidate, composed = ComposeCanonicalEggName(candidate, baseQualifier)
                    local rank = NameFieldRank(key)
                    if composed then
                        rank = math.max(rank, 3)
                    end

                    local candidateKey = NormalizeKey(candidate)
                    local selectedKey = NormalizeKey(selectedName)
                    local moreSpecific = selectedKey ~= ""
                        and #candidateKey > #selectedKey
                        and candidateKey:find(selectedKey, 1, true) ~= nil
                    if not selectedName or rank > selectedRank or moreSpecific then
                        selectedName = candidate
                        selectedRaw = value
                        selectedField = tostring(key)
                        selectedRank = rank
                        selectedComposed = composed
                    end
                end
                break
            end
        end
    end

    return selectedName, selectedRaw, selectedField, selectedRank or 0, selectedComposed or false
end

local function InterpretRecord(record, context)
    if type(record) ~= "table" then
        return nil
    end

    local rawRarity = ExtractField(record, RarityKeys)
    local rawArea = ExtractField(record, AreaKeys)
    local rawUniqueId = ExtractField(record, UniqueIdKeys)
    local rawSlotId = ExtractField(record, SlotKeys)
    local rawId = rawUniqueId or ExtractField(record, IdKeys) or context.RemoteHint
    local uniqueId = ScalarText(rawUniqueId) or context.UniqueHint
    local slotId = ScalarText(rawSlotId)
    local id = uniqueId or ScalarText(rawId) or context.IdHint
    local rawBaseQualifier = ExtractFieldByPriority(record, BaseNameQualifierPriority)
    local baseQualifier = ScalarText(rawBaseQualifier)
    local name, rawName, rawNameField, nameRank = ResolveRecordName(record, baseQualifier)
    local rarity = ScalarText(rawRarity)
    local area = ResolveArea(rawArea) or context.AreaHint
    local mutation = ScalarText(ExtractField(record, MutationKeys))
    local position = ToPosition(ExtractField(record, PositionKeys))

    local containsCollection = false
    for key, value in pairs(record) do
        if ContainerKeys[NormalizeKey(key)] and type(value) == "table" then
            containsCollection = true
            break
        end
    end

    local catalogue = id and EggCatalog[id] or nil
    if catalogue then
        if not name and catalogue.Name then
            name = ComposeCanonicalEggName(catalogue.Name, baseQualifier)
            nameRank = 4
        end
        rarity = rarity or catalogue.Rarity
        area = area or ResolveArea(catalogue.Area)
    end

    -- Compatibilidad con registros compactos: localiza Vector3/CFrame y usa
    -- unicamente strings respaldados por los catalogos. No presupone indices.
    if not position or not name or not area then
        for _, value in pairs(record) do
            if not position then
                position = ToPosition(value)
            end
            local text = ScalarText(value)
            if text then
                if not name and EggCatalog[text] then
                    name = ComposeCanonicalEggName(EggCatalog[text].Name, baseQualifier)
                    nameRank = 4
                    rarity = rarity or EggCatalog[text].Rarity
                    area = area or ResolveArea(EggCatalog[text].Area)
                end
                if not area and AreaCatalog[text] then
                    area = AreaCatalog[text].Name
                end
            end
        end
    end

    if name and IsGenericObjectName(name) then
        name = nil
    end
    if name and MetadataKeys[NormalizeKey(name)] then
        name = nil
    end
    area = area or AreaFromNearestAnchor(position)

    local hasProtocolEvidence = rawName ~= nil or rawRarity ~= nil or rawArea ~= nil
        or ExtractField(record, IdKeys) ~= nil or position ~= nil
    if containsCollection and not rawRarity and not position and not uniqueId then
        return nil
    end
    if not hasProtocolEvidence then
        return nil
    end
    if not id and not name then
        return nil
    end

    return {
        Id = id,
        UniqueId = uniqueId,
        SlotId = slotId,
        RemoteId = rawId,
        Name = name,
        NameRank = nameRank,
        BaseNameQualifier = baseQualifier,
        Rarity = rarity,
        AreaName = area,
        Mutation = mutation,
        Position = position,
        SourceKey = context.Path
    }
end

local function ParsePayload(root, sourceName)
    local eggs = {}
    local visited = {}

    local function Walk(value, context, depth)
        if type(value) ~= "table" or visited[value] or depth > 12 then
            return
        end
        visited[value] = true

        local egg = InterpretRecord(value, context)
        if egg then
            table.insert(eggs, egg)
        end

        local arrayLength = #value
        for key, child in pairs(value) do
            if type(child) == "table" then
                local keyText = ScalarText(key)
                local childContext = {
                    AreaHint = context.AreaHint,
                    IdHint = nil,
                    UniqueHint = nil,
                    RemoteHint = nil,
                    Path = context.Path .. "." .. tostring(key)
                }
                if keyText and AreaCatalog[keyText] then
                    childContext.AreaHint = AreaCatalog[keyText].Name
                elseif keyText and type(key) == "string"
                    and not ContainerKeys[NormalizeKey(keyText)]
                    and not MetadataKeys[NormalizeKey(keyText)] then
                    local looksLikeAreaBucket = false
                    local inspected = 0
                    for _, possibleRecord in pairs(child) do
                        if type(possibleRecord) == "table" then
                            inspected = inspected + 1
                            if HasAnyField(possibleRecord, NameKeys)
                                or HasAnyField(possibleRecord, RarityKeys)
                                or HasAnyField(possibleRecord, IdKeys) then
                                looksLikeAreaBucket = true
                                break
                            end
                            if inspected >= 6 then
                                break
                            end
                        end
                    end
                    if looksLikeAreaBucket then
                        childContext.AreaHint = keyText
                    elseif #keyText >= 6 then
                        childContext.IdHint = keyText
                        childContext.UniqueHint = keyText
                        childContext.RemoteHint = key
                    end
                elseif keyText
                    and (type(key) == "string" or arrayLength == 0)
                    and not NameKeys[NormalizeKey(keyText)]
                    and not RarityKeys[NormalizeKey(keyText)]
                    and not AreaKeys[NormalizeKey(keyText)]
                    and not MetadataKeys[NormalizeKey(keyText)] then
                    childContext.IdHint = keyText
                    childContext.UniqueHint = keyText
                    childContext.RemoteHint = key
                end
                Walk(child, childContext, depth + 1)
            end
        end
    end

    Walk(root, {
        AreaHint = nil,
        IdHint = nil,
        UniqueHint = nil,
        RemoteHint = nil,
        Path = sourceName
    }, 0)
    return eggs
end

local function MergeCanonicalName(target, source)
    local targetRank = tonumber(target.NameRank) or 0
    local sourceRank = tonumber(source.NameRank) or 0
    local targetNameKey = NormalizeKey(target.Name)
    local sourceNameKey = NormalizeKey(source.Name)
    local sourceIsMoreSpecific = sourceNameKey ~= "" and targetNameKey ~= ""
        and #sourceNameKey > #targetNameKey
        and sourceNameKey:find(targetNameKey, 1, true) ~= nil
    if not target.Name or sourceRank > targetRank or sourceIsMoreSpecific then
        target.Name = source.Name or target.Name
        target.NameRank = source.Name and sourceRank or target.NameRank
    end
end

local function MergeEgg(target, source)
    target.Id = target.Id or source.Id
    target.UniqueId = target.UniqueId or source.UniqueId
    target.SlotId = target.SlotId or source.SlotId
    target.RemoteId = target.RemoteId or source.RemoteId
    MergeCanonicalName(target, source)
    target.Rarity = target.Rarity or source.Rarity
    target.AreaName = target.AreaName or source.AreaName
    target.Mutation = target.Mutation or source.Mutation
    target.BaseNameQualifier = target.BaseNameQualifier or source.BaseNameQualifier
    target.Position = target.Position or source.Position
end

local function DedupeEggs(eggs)
    local output, byId = {}, {}
    for _, egg in ipairs(eggs) do
        local existing = egg.UniqueId and byId[tostring(egg.UniqueId)] or nil
        if existing then
            MergeEgg(existing, egg)
        else
            table.insert(output, egg)
            if egg.UniqueId then
                byId[tostring(egg.UniqueId)] = egg
            end
        end
    end
    return output
end

-- El snapshot identifica cada huevo con AssetCategory, pero no incluye la
-- rareza. Solo se consulta el catalogo que ya hubiera sido obtenido por un
-- evento de EggWorld; nunca se recorren ni se requieren modulos del juego
-- desde el boton, porque eso puede bloquear por completo el cliente.
local function EnrichRaritiesFromRuntime(eggs)
    table.clear(CatalogScanNotes)
    local resolved = 0
    for _, egg in ipairs(eggs) do
        local catalogue = egg.Name and EggCatalog[egg.Name] or nil
        if catalogue and not egg.Rarity and catalogue.Rarity then
            egg.Rarity = catalogue.Rarity
            resolved = resolved + 1
        end
    end
    table.insert(CatalogScanNotes,
        "Exploracion pesada desactivada; rarezas resueltas desde EggWorld: " .. resolved)
    return eggs
end

local function EnrichWithEggRecord(eggs)
    if not RF_EggRecord then
        return eggs
    end

    local targetsById = {}
    for _, egg in ipairs(eggs) do
        if egg.Id and (not egg.Name or not egg.Rarity or not egg.AreaName) then
            local id = tostring(egg.Id)
            targetsById[id] = targetsById[id] or { QueryValue = egg.RemoteId or egg.Id, Eggs = {} }
            table.insert(targetsById[id].Eggs, egg)
        end
    end

    local remaining = 0
    local started = 0
    for id, entry in pairs(targetsById) do
        if started >= 24 then
            break
        end
        started = started + 1
        remaining = remaining + 1
        task.spawn(function()
            local ok, returned = InvokeWithTimeout(
                "record:" .. id,
                RF_EggRecord,
                2.5,
                entry.QueryValue
            )
            if ok and returned then
                for resultIndex = 1, returned.n do
                    local record = returned[resultIndex]
                    if type(record) == "table" then
                        local details = ParsePayload(
                            record,
                            "EggRecord:" .. id .. ".Result" .. resultIndex
                        )
                        for _, detail in ipairs(details) do
                            if not detail.Id or tostring(detail.Id) == id then
                                for _, target in ipairs(entry.Eggs) do
                                    MergeEgg(target, detail)
                                end
                            end
                        end
                    end
                end
            end
            remaining = remaining - 1
        end)
    end

    if remaining > 0 then
        Progress(string.format("Completando datos de %d tipos de huevo...", started))
        local deadline = os.clock() + 3
        while ScriptRunning and remaining > 0 and os.clock() < deadline do
            task.wait(0.05)
        end
    end
    return eggs
end

local function MergeEventDetails(snapshotEggs, eventEggs)
    local byUniqueId, byTypeId = {}, {}
    for _, detail in ipairs(eventEggs) do
        if detail.UniqueId then
            byUniqueId[tostring(detail.UniqueId)] = detail
        end
        if detail.Id then
            byTypeId[tostring(detail.Id)] = byTypeId[tostring(detail.Id)] or detail
        end
    end

    for _, egg in ipairs(snapshotEggs) do
        local detail = egg.UniqueId and byUniqueId[tostring(egg.UniqueId)] or nil
        if detail then
            MergeEgg(egg, detail)
        elseif egg.Id and byTypeId[tostring(egg.Id)] then
            -- Un ID de tipo puede repetirse. Solo completa datos propios del
            -- tipo; el area/posicion siguen viniendo del registro de aparicion.
            local typeDetail = byTypeId[tostring(egg.Id)]
            MergeCanonicalName(egg, typeDetail)
            egg.Rarity = egg.Rarity or typeDetail.Rarity
            egg.Mutation = egg.Mutation or typeDetail.Mutation
            egg.BaseNameQualifier = egg.BaseNameQualifier or typeDetail.BaseNameQualifier
        end
    end
    return snapshotEggs
end

--------------------------------------------------------------------------
-- RESPALDO FISICO: ATRIBUTOS, VALUES, GUI Y RUTA DEL OBJETO
--------------------------------------------------------------------------
local function ReadInstanceRecord(part)
    local record = { Position = part.Position }
    local current = part
    local depth = 0

    while current and current ~= Workspace and depth < 7 do
        for key, value in pairs(current:GetAttributes()) do
            if record[key] == nil then
                record[key] = value
            end
        end
        for _, child in ipairs(current:GetChildren()) do
            if child:IsA("StringValue") or child:IsA("IntValue") or child:IsA("NumberValue") then
                record[child.Name] = child.Value
            elseif child:IsA("BillboardGui") or child:IsA("SurfaceGui") then
                for _, label in ipairs(child:GetDescendants()) do
                    if label:IsA("TextLabel") then
                        local normalizedName = NormalizeKey(label.Name)
                        if NameKeys[normalizedName] then
                            record.EggName = label.Text
                        elseif RarityKeys[normalizedName] then
                            record.Rarity = label.Text
                        elseif AreaKeys[normalizedName] then
                            record.Area = label.Text
                        end
                    end
                end
            end
        end

        if current:IsA("Model") and not record.EggName and not IsGenericObjectName(current.Name) then
            record.EggName = current.Name
        end
        current = current.Parent
        depth = depth + 1
    end
    return record
end

local function ScanPhysicalEggs()
    local eggs, seenParts = {}, {}
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            local action = string.lower(object.ActionText or "")
            local objectText = string.lower(object.ObjectText or "")
            local promptName = NormalizeKey(object.Name)
            local isEggPrompt = promptName == "carryareaegg"
                or (action:find("steal", 1, true) and objectText:find("egg", 1, true))
                or (action:find("robar", 1, true) and objectText:find("huevo", 1, true))
            if isEggPrompt then
                local owner = object.Parent
                local part = owner and owner:IsA("BasePart") and owner or nil
                if owner and owner:IsA("Attachment") and owner.Parent and owner.Parent:IsA("BasePart") then
                    part = owner.Parent
                end
                if part and not seenParts[part] then
                    seenParts[part] = true
                    local physicalId = string.format(
                        "%s|%.3f,%.3f,%.3f",
                        part:GetFullName(), part.Position.X, part.Position.Y, part.Position.Z
                    )
                    local egg = InterpretRecord(ReadInstanceRecord(part), {
                        AreaHint = AreaFromNearestAnchor(part.Position),
                        IdHint = physicalId,
                        UniqueHint = physicalId,
                        RemoteHint = physicalId,
                        Path = part:GetFullName()
                    })
                    if egg then
                        table.insert(eggs, egg)
                    end
                end
            end
        end
    end
    return DedupeEggs(eggs)
end

local function FetchCurrentEggs()
    ResolveNetworkRoutes()
    local eggs = {}
    local gotSnapshot = false

    if RF_FieldSnapshot then
        Progress("Consultando snapshot de EggWorld (maximo 4 segundos)...")
        local ok, returned = InvokeWithTimeout("field-snapshot", RF_FieldSnapshot, 4)
        if ok and returned then
            LastSnapshotResults = returned
            for resultIndex = 1, returned.n do
                if type(returned[resultIndex]) == "table" then
                    local parsed = ParsePayload(
                        returned[resultIndex],
                        "FieldSnapshot.Result" .. resultIndex
                    )
                    for _, egg in ipairs(parsed) do
                        table.insert(eggs, egg)
                    end
                end
            end
            gotSnapshot = #eggs > 0
        end
    end

    local eventEggs = {}
    for payloadIndex, packed in ipairs(EventPayloads) do
        for argumentIndex = 1, packed.n do
            if type(packed[argumentIndex]) == "table" then
                local parsed = ParsePayload(
                    packed[argumentIndex],
                    "Event" .. payloadIndex .. ".Arg" .. argumentIndex
                )
                for _, egg in ipairs(parsed) do
                    table.insert(eventEggs, egg)
                end
            end
        end
    end

    eventEggs = DedupeEggs(eventEggs)
    if gotSnapshot then
        eggs = MergeEventDetails(eggs, eventEggs)
    else
        eggs = eventEggs
    end

    eggs = DedupeEggs(eggs)
    if #eggs == 0 then
        Progress("Snapshot sin datos; escaneando objetos del mapa...")
        eggs = ScanPhysicalEggs()
    end
    Progress(string.format("Escaneo terminado: %d huevos detectados.", #eggs))
    return DedupeEggs(eggs)
end

-- Lectura ligera usada por el monitor automatico. No recorre Workspace, no
-- consulta catalogos y no envia nada a Discord.
local function FetchSnapshotOnly()
    ResolveNetworkRoutes()
    if not RF_FieldSnapshot then
        return nil
    end

    local ok, returned = InvokeWithTimeout("field-snapshot", RF_FieldSnapshot, 3)
    if not ok or not returned then
        return nil
    end

    local eggs = {}
    LastSnapshotResults = returned
    for resultIndex = 1, returned.n do
        if type(returned[resultIndex]) == "table" then
            local parsed = ParsePayload(
                returned[resultIndex],
                "SnapshotMonitor.Result" .. resultIndex
            )
            for _, egg in ipairs(parsed) do
                table.insert(eggs, egg)
            end
        end
    end
    return DedupeEggs(eggs)
end

local function BuildSnapshotIdentity(eggs)
    local ids = {}
    local idSet = {}
    for _, egg in ipairs(eggs) do
        local identity = CleanText(egg.UniqueId or egg.Id)
        if identity and not idSet[identity] then
            idSet[identity] = true
            table.insert(ids, identity)
        end
    end
    table.sort(ids)
    return {
        Signature = table.concat(ids, "|"),
        Ids = idSet,
        Count = #ids
    }
end

local function SetSnapshotMonitorBaseline(eggs)
    local identity = BuildSnapshotIdentity(eggs)
    if identity.Count > 0 then
        SnapshotMonitorBaseline = identity
        SnapshotMonitorCandidate = ""
        SnapshotMonitorCandidateSeen = 0
    end
end

local function SnapshotChangeRatio(previous, current)
    if not previous or previous.Count == 0 or current.Count == 0 then
        return 0
    end
    local common = 0
    for identity in pairs(previous.Ids) do
        if current.Ids[identity] then
            common = common + 1
        end
    end
    return 1 - (common / math.max(previous.Count, current.Count))
end

local function CountDistinctAreas(eggs)
    local areas = {}
    local count = 0
    for _, egg in ipairs(eggs) do
        local area = CleanText(egg.AreaName)
        if area and not areas[area] then
            areas[area] = true
            count = count + 1
        end
    end
    return count
end

local function CountEggsByArea(eggs)
    local counts = {}
    for _, egg in ipairs(eggs) do
        local area = CleanText(egg.AreaName)
        if area then
            counts[area] = (counts[area] or 0) + 1
        end
    end
    return counts
end

local function RememberMapShape(eggs)
    local changed = false
    local areaCount = CountDistinctAreas(eggs)
    if areaCount > ExpectedAreaCount then
        ExpectedAreaCount = areaCount
        Config.KnownAreaCount = areaCount
        changed = true
    end

    for area, count in pairs(CountEggsByArea(eggs)) do
        if count > (ExpectedEggsByArea[area] or 0) then
            ExpectedEggsByArea[area] = count
            changed = true
        end
    end
    Config.KnownEggsByArea = ExpectedEggsByArea
    if changed then
        SaveConfig()
    end
end

local function MapMeetsExpectedShape(eggs)
    local areaCount = CountDistinctAreas(eggs)
    if ExpectedAreaCount > 0 and areaCount < ExpectedAreaCount then
        return false
    end

    local counts = CountEggsByArea(eggs)
    for area, expectedCount in pairs(ExpectedEggsByArea) do
        if (counts[area] or 0) < expectedCount then
            return false
        end
    end
    return areaCount > 0
end

local function BuildEggContentSignature(eggs)
    local rows = {}
    for _, egg in ipairs(eggs) do
        table.insert(rows, table.concat({
            CleanText(egg.AreaName) or "",
            CleanText(egg.UniqueId or egg.Id) or "",
            CleanText(egg.Name) or "",
            CleanText(egg.Mutation) or ""
        }, "|"))
    end
    table.sort(rows)
    return table.concat(rows, "\n")
end

-- Durante la regeneracion el servidor construye el snapshot por partes. Esta
-- lectura conserva el resultado mas completo y espera a que la cantidad de
-- areas deje de crecer. ExpectedAreaCount se aprende de lecturas completas;
-- no contiene nombres ni cantidades escritas a mano.
local function FetchStableRegeneration()
    local bestEggs = {}
    local bestAreaCount = 0
    local bestEggCount = 0
    local observedBySlot = {}
    local processedEventPayloads = 0
    local previousSignature = ""
    local stableSamples = 0
    local started = os.clock()
    local deadline = started + 45

    local function slotKey(egg)
        local area = CleanText(egg.AreaName) or ""
        local slot = CleanText(egg.SlotId)
        if slot then
            return area .. "|slot:" .. slot
        end
        if egg.Position then
            return string.format(
                "%s|pos:%.1f,%.1f,%.1f",
                area,
                egg.Position.X,
                egg.Position.Y,
                egg.Position.Z
            )
        end
        return area .. "|uid:" .. (CleanText(egg.UniqueId or egg.Id) or tostring(egg))
    end

    local function rememberObserved(eggs)
        for _, egg in ipairs(eggs) do
            observedBySlot[slotKey(egg)] = egg
        end
    end

    local function observedList()
        local result = {}
        for _, egg in pairs(observedBySlot) do
            table.insert(result, egg)
        end
        return DedupeEggs(result)
    end

    repeat
        local current = FetchSnapshotOnly() or {}
        local areaCount = CountDistinctAreas(current)
        local eggCount = #current
        local contentSignature = BuildEggContentSignature(current)
        rememberObserved(current)

        -- Los eventos del ciclo pueden revelar un huevo especial antes de que
        -- el snapshot termine de asentarse. Se conservan por NestId, de modo
        -- que nunca se agrega dos veces el mismo nido.
        for payloadIndex = processedEventPayloads + 1, #EventPayloads do
            local packed = EventPayloads[payloadIndex]
            for argumentIndex = 1, packed.n do
                if type(packed[argumentIndex]) == "table" then
                    rememberObserved(ParsePayload(
                        packed[argumentIndex],
                        "RegenEvent" .. payloadIndex .. ".Arg" .. argumentIndex
                    ))
                end
            end
        end
        processedEventPayloads = #EventPayloads

        if areaCount > bestAreaCount
            or (areaCount == bestAreaCount and eggCount >= bestEggCount) then
            bestEggs = observedList()
            bestAreaCount = areaCount
            bestEggCount = eggCount
        end

        if contentSignature ~= "" and contentSignature == previousSignature then
            stableSamples = stableSamples + 1
        else
            stableSamples = 0
        end
        previousSignature = contentSignature

        local mapIsComplete = MapMeetsExpectedShape(current)
        if mapIsComplete and os.clock() - started >= 18 and stableSamples >= 4 then
            return observedList()
        end
        if os.clock() >= deadline then
            break
        end

        Progress(string.format(
            "Verificando huevos especiales: %d areas, %d huevos, estabilidad %d/4...",
            areaCount,
            eggCount,
            math.min(stableSamples, 4)
        ))
        task.wait(2)
    until not ScriptRunning

    return bestEggs
end

--------------------------------------------------------------------------
-- VALIDACION Y DIAGNOSTICO DEL ESQUEMA REAL
--------------------------------------------------------------------------
local function ValidateEggs(eggs)
    local invalid = {}
    for index, egg in ipairs(eggs) do
        local name = CleanText(egg.Name)
        local area = CleanText(egg.AreaName)
        local badName = name and MetadataKeys[NormalizeKey(name)]
        local badArea = area and MetadataKeys[NormalizeKey(area)]
        if not name or badName or not area or badArea then
            table.insert(invalid, string.format(
                "#%d nombre=%s area=%s",
                index,
                name or "<falta>",
                area or "<falta>"
            ))
        end
    end
    return #invalid == 0, invalid
end

local function BuildSchemaDiagnostic(eggs, invalid)
    local function countEntries(source)
        local count = 0
        for _ in pairs(source) do
            count = count + 1
        end
        return count
    end

    local lines = {
        "STEAL AN EGG - DIAGNOSTICO DE DATOS",
        "PlaceId: " .. tostring(game.PlaceId),
        "JobId: " .. tostring(game.JobId),
        "EggCatalog: " .. tostring(countEntries(EggCatalog)),
        "AreaCatalog: " .. tostring(countEntries(AreaCatalog)),
        "Huevos interpretados: " .. tostring(#eggs),
        "Registros incompletos: " .. tostring(#invalid),
        ""
    }

    if #CatalogScanNotes > 0 then
        table.insert(lines, "BUSQUEDA DE CATALOGO")
        for _, note in ipairs(CatalogScanNotes) do
            table.insert(lines, note)
        end
        table.insert(lines, "")
    end

    for _, row in ipairs(invalid) do
        table.insert(lines, row)
    end
    table.insert(lines, "")

    table.insert(lines, "OBJETOS FISICOS CERCA DE LOS PROMPTS DE HUEVO")
    local physicalEntries = 0
    local inspectedModels = {}
    local workspaceObjects = Workspace:GetDescendants()
    for objectIndex, object in ipairs(workspaceObjects) do
        if objectIndex % 600 == 0 then
            task.wait()
        end
        if object:IsA("ProximityPrompt") and physicalEntries < 800 then
            local action = string.lower(object.ActionText or "")
            local objectText = string.lower(object.ObjectText or "")
            local isEggPrompt = NormalizeKey(object.Name) == "carryareaegg"
                or action:find("steal", 1, true)
                or action:find("robar", 1, true)
                or objectText:find("egg", 1, true)
                or objectText:find("huevo", 1, true)
            if isEggPrompt then
                physicalEntries = physicalEntries + 1
                table.insert(lines, string.format(
                    "Prompt%d = %s | Action=%s | Object=%s",
                    physicalEntries,
                    object:GetFullName(),
                    object.ActionText or "",
                    object.ObjectText or ""
                ))

                local current = object.Parent
                for depth = 1, 7 do
                    if not current or current == Workspace then
                        break
                    end
                    table.insert(lines, string.format(
                        "  Ancestor%d <%s> = %s",
                        depth,
                        current.ClassName,
                        current:GetFullName()
                    ))
                    for attribute, value in pairs(current:GetAttributes()) do
                        table.insert(lines, string.format(
                            "    Attribute[%s] <%s> = %s",
                            tostring(attribute), typeof(value), tostring(value)
                        ))
                    end
                    current = current.Parent
                end

                local model = object:FindFirstAncestorOfClass("Model")
                if model and not inspectedModels[model] then
                    inspectedModels[model] = true
                    local detailCount = 0
                    for _, descendant in ipairs(model:GetDescendants()) do
                        if detailCount >= 80 then
                            break
                        end
                        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                            detailCount = detailCount + 1
                            table.insert(lines, string.format(
                                "    GUI <%s> %s = %s",
                                descendant.ClassName,
                                descendant:GetFullName(),
                                descendant.Text
                            ))
                        elseif descendant:IsA("StringValue") then
                            detailCount = detailCount + 1
                            table.insert(lines, string.format(
                                "    StringValue %s = %s",
                                descendant:GetFullName(),
                                descendant.Value
                            ))
                        end
                    end
                end
            end
        end
    end
    if physicalEntries == 0 then
        table.insert(lines, "<no se encontraron prompts fisicos de huevo>")
    end
    table.insert(lines, "")
    table.insert(lines, "DATOS CRUDOS (ruta <tipo> = valor)")

    local seen = {}
    local entries = 0
    local maximumEntries = 2500

    local function appendValue(value, path, depth)
        if entries >= maximumEntries then
            return
        end
        entries = entries + 1
        local valueType = typeof(value)

        if type(value) == "table" then
            if seen[value] then
                table.insert(lines, path .. " <table> = <referencia repetida>")
                return
            end
            seen[value] = true
            if depth >= 10 then
                table.insert(lines, path .. " <table> = <limite de profundidad>")
                return
            end

            local keys = {}
            for key in pairs(value) do
                table.insert(keys, key)
            end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            if #keys == 0 then
                table.insert(lines, path .. " <table> = {}")
            end
            for _, key in ipairs(keys) do
                appendValue(value[key], path .. "[" .. tostring(key) .. "]", depth + 1)
            end
        elseif valueType == "Instance" then
            local ok, fullName = pcall(function()
                return value:GetFullName()
            end)
            table.insert(lines, string.format(
                "%s <Instance:%s> = %s",
                path,
                value.ClassName,
                ok and fullName or tostring(value)
            ))
        else
            local rendered = tostring(value)
            if #rendered > 500 then
                rendered = rendered:sub(1, 500) .. "..."
            end
            table.insert(lines, string.format("%s <%s> = %s", path, valueType, rendered))
        end
    end

    if LastSnapshotResults then
        for index = 1, LastSnapshotResults.n do
            appendValue(LastSnapshotResults[index], "Snapshot.Result" .. index, 0)
        end
    else
        table.insert(lines, "Snapshot = <no disponible>")
    end

    for payloadIndex, packed in ipairs(EventPayloads) do
        for argumentIndex = 1, packed.n do
            appendValue(
                packed[argumentIndex],
                string.format("Event%d.Arg%d", payloadIndex, argumentIndex),
                0
            )
        end
    end

    if entries >= maximumEntries then
        table.insert(lines, "<diagnostico limitado a " .. maximumEntries .. " entradas>")
    end
    return table.concat(lines, "\n")
end

local function SaveSchemaDiagnostic(eggs, invalid)
    local diagnostic = BuildSchemaDiagnostic(eggs, invalid)
    local saved = false
    local copied = false

    if type(writefile) == "function" then
        saved = pcall(writefile, "StealAnEgg_Diagnostic.txt", diagnostic)
    end
    local clipboardWriter = type(setclipboard) == "function" and setclipboard
        or type(toclipboard) == "function" and toclipboard
        or nil
    if clipboardWriter then
        copied = pcall(clipboardWriter, diagnostic)
    end

    if saved and copied then
        return "Diagnostico guardado y copiado."
    elseif saved then
        return "Diagnostico guardado como StealAnEgg_Diagnostic.txt."
    elseif copied then
        return "Diagnostico copiado al portapapeles."
    end
    return "El executor no permite guardar ni copiar el diagnostico."
end

--------------------------------------------------------------------------
-- AGRUPACION, CONTEO Y MENSAJES SIN RECORTAR
--------------------------------------------------------------------------
local function GroupByArea(eggs)
    local byArea, groups = {}, {}
    for _, egg in ipairs(eggs) do
        local area = CleanText(egg.AreaName) or "Area no disponible"
        if not byArea[area] then
            byArea[area] = { AreaName = area, Eggs = {} }
            table.insert(groups, byArea[area])
        end
        table.insert(byArea[area].Eggs, egg)
    end
    table.sort(groups, function(a, b)
        return a.AreaName < b.AreaName
    end)
    for _, group in ipairs(groups) do
        table.sort(group.Eggs, function(a, b)
            local aKey = (a.Name or "") .. "|" .. (a.Id or "")
            local bKey = (b.Name or "") .. "|" .. (b.Id or "")
            return aKey < bKey
        end)
    end
    return groups
end

local function EggDisplayName(egg)
    local name = CleanText(egg.Name)
        or (egg.Id and "Huevo ID " .. egg.Id)
        or "Nombre no disponible"
    local nameKey = NormalizeKey(name)

    if not nameKey:find("egg", 1, true) and not nameKey:find("huevo", 1, true) then
        name = name .. " Egg"
    end
    return name
end

local function EggLine(egg)
    return "- " .. EggDisplayName(egg)
end

local function BuildSignature(groups)
    local rows = {}
    for _, group in ipairs(groups) do
        for _, egg in ipairs(group.Eggs) do
            local position = egg.Position
                and string.format("%.2f,%.2f,%.2f", egg.Position.X, egg.Position.Y, egg.Position.Z)
                or ""
            table.insert(rows, table.concat({
                group.AreaName, egg.Name or "",
                egg.Mutation or "", egg.UniqueId or egg.Id or "", position
            }, "|"))
        end
    end
    table.sort(rows)
    return table.concat(rows, "\n")
end

local function BuildReport(groups, reason)
    local total = 0
    for _, group in ipairs(groups) do
        total = total + #group.Eggs
    end

    local lines = {
        string.format(
        "Regeneracion de huevos (%s)\nServidor: %s\nTotal: %d huevos en %d areas\n\n",
        reason, tostring(game.JobId), total, #groups
        )
    }

    for _, group in ipairs(groups) do
        table.insert(lines, string.format("%s (%d):\n", group.AreaName, #group.Eggs))
        for _, egg in ipairs(group.Eggs) do
            table.insert(lines, EggLine(egg) .. "\n")
        end
        table.insert(lines, "\n")
    end
    return (table.concat(lines):gsub("%s+$", "")), total
end

local function SendEggReport(mode)
    if not ScriptRunning then
        return false, "Script detenido."
    end
    if mode ~= "manual" and not Config.AutoSendEnabled then
        return false, "Auto-envio desactivado."
    end

    local eggs = mode == "regen" and FetchStableRegeneration() or FetchCurrentEggs()
    if #eggs == 0 then
        return false, "EggWorld no devolvio huevos activos; espera la proxima regeneracion."
    end
    local dataIsValid, invalid = ValidateEggs(eggs)
    if not dataIsValid then
        local diagnosticStatus = SaveSchemaDiagnostic(eggs, invalid)
        return false, string.format(
            "Datos incompletos (%d de %d). No se envio nada. %s",
            #invalid,
            #eggs,
            diagnosticStatus
        )
    end
    local groups = GroupByArea(eggs)
    if mode == "regen" and ExpectedAreaCount == 0 and #groups <= 1 then
        return false, "Mapa incompleto: solo se recibio un area. No se envio nada."
    end
    if mode == "regen" and not MapMeetsExpectedShape(eggs) then
        return false, string.format(
            "Mapa incompleto: llegaron %d areas, pero faltan huevos o biomas. No se envio nada.",
            #groups
        )
    end
    RememberMapShape(eggs)
    local signature = BuildSignature(groups)
    local now = os.time()

    if mode ~= "manual" and signature == LastSignature then
        return false, "Evento duplicado."
    end
    if mode == "regen" and now - LastRegenSend < 45 then
        return false, "Evento duplicado."
    end
    if now - LastSuccessfulSend < 2 then
        return false, "Limite de Discord."
    end

    local reason = mode == "manual" and "manual"
        or mode == "regen" and "nuevo ciclo"
        or "cambio detectado"
    local reportText, total = BuildReport(groups, reason)
    local ok, message = PostSingleReport(reportText, total, #groups)
    if not ok then
        return false, message
    end
    LastSignature = signature
    LastSuccessfulSend = now
    SetSnapshotMonitorBaseline(eggs)
    if mode == "regen" then
        LastRegenSend = now
    end
    return true, string.format("%d huevos en %d areas; un mensaje enviado.", total, #groups)
end

local function SafeSendEggReport(mode)
    local ran, ok, message = xpcall(function()
        return SendEggReport(mode)
    end, function(err)
        return tostring(err)
    end)
    if not ran then
        warn("[StealAnEgg] " .. tostring(ok))
        return false, "Error interno: " .. tostring(ok)
    end
    return ok, message
end

--------------------------------------------------------------------------
-- INTERFAZ SIMPLE
--------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "StealEggAutoTracker"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local guiParent
local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if playerGui then
    guiParent = playerGui
end

if not guiParent and type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and typeof(result) == "Instance" then
        guiParent = result
    end
end

if not guiParent then
    local ok, result = pcall(function()
        return LocalPlayer:WaitForChild("PlayerGui", 10)
    end)
    if ok and result then
        guiParent = result
    end
end

if not guiParent then
    local ok = pcall(function()
        ScreenGui.Parent = CoreGui
    end)
    if not ok or not ScreenGui.Parent then
        error("Delta no permitio acceder a PlayerGui, gethui ni CoreGui")
    end
else
    ScreenGui.Parent = guiParent
end

local MiniWidget = Instance.new("TextButton")
MiniWidget.Name = "MiniWidget"
MiniWidget.Size = UDim2.new(0, 140, 0, 34)
MiniWidget.Position = UDim2.new(0, 20, 0, 80)
MiniWidget.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
MiniWidget.BorderSizePixel = 0
MiniWidget.Text = "🥚 Egg Tracker"
MiniWidget.TextColor3 = Color3.fromRGB(0, 230, 150)
MiniWidget.Font = Enum.Font.GothamBold
MiniWidget.TextSize = 12
MiniWidget.Active = true
MiniWidget.Draggable = true
MiniWidget.Visible = false
MiniWidget.Parent = ScreenGui
Instance.new("UICorner", MiniWidget).CornerRadius = UDim.new(0, 8)

local MiniStroke = Instance.new("UIStroke")
MiniStroke.Color = Color3.fromRGB(0, 200, 255)
MiniStroke.Thickness = 1.4
MiniStroke.Parent = MiniWidget

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 370, 0, 390)
Main.Position = UDim2.new(0.5, -185, 0.4, -195)
Main.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(0, 200, 255)
Stroke.Thickness = 1.4
Stroke.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Steal An Egg | Discord Tracker v2"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -56, 0, 6)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 56, 76)
MinimizeBtn.Text = "_"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 12
MinimizeBtn.Parent = TopBar
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -28, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 36)
Status.Position = UDim2.new(0, 10, 0, 42)
Status.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
Status.Text = "Preparando catalogos del cliente..."
Status.TextWrapped = true
Status.TextColor3 = Color3.fromRGB(0, 230, 150)
Status.Font = Enum.Font.GothamMedium
Status.TextSize = 10
Status.Parent = Main
Instance.new("UICorner", Status).CornerRadius = UDim.new(0, 6)

local function SetStatus(message, isError)
    if ScriptRunning and Status and Status.Parent then
        Status.Text = tostring(message)
        Status.TextColor3 = isError and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(0, 230, 150)
    end
end

Progress = function(message)
    SetStatus(message, false)
end

local BoxFrame = Instance.new("Frame")
BoxFrame.Size = UDim2.new(1, -20, 0, 34)
BoxFrame.Position = UDim2.new(0, 10, 0, 84)
BoxFrame.BackgroundColor3 = Color3.fromRGB(26, 30, 44)
BoxFrame.BorderSizePixel = 0
BoxFrame.ClipsDescendants = true
BoxFrame.Parent = Main
Instance.new("UICorner", BoxFrame).CornerRadius = UDim.new(0, 6)

local Box = Instance.new("TextBox")
Box.Size = UDim2.new(1, -16, 1, 0)
Box.Position = UDim2.new(0, 8, 0, 0)
Box.BackgroundTransparency = 1
Box.PlaceholderText = "Pega aqui tu webhook de Discord..."
Box.Text = Config.WebhookUrl
Box.TextColor3 = Color3.fromRGB(180, 220, 255)
Box.Font = Enum.Font.Gotham
Box.TextSize = 11
Box.TextXAlignment = Enum.TextXAlignment.Left
Box.ClearTextOnFocus = false
Box.Parent = BoxFrame

local function SaveWebhookFromBox()
    local raw = Box.Text
    local url = SanitizeWebhookUrl(raw)
    Config.WebhookUrl = url
    if url ~= "" and url ~= raw then
        Box.Text = url
    end
    SaveConfig()
    if url == "" then
        SetStatus("Webhook vacio o invalido.", true)
        return false
    end
    SetStatus("Webhook guardado permanentemente.", false)
    return true
end
table.insert(Connections, Box.FocusLost:Connect(SaveWebhookFromBox))
table.insert(Connections, Box:GetPropertyChangedSignal("Text"):Connect(function()
    local currentText = Box.Text
    if currentText and currentText ~= "" then
        Config.WebhookUrl = SanitizeWebhookUrl(currentText)
        SaveConfig()
    end
end))

local BotIdFrame = Instance.new("Frame")
BotIdFrame.Size = UDim2.new(1, -20, 0, 34)
BotIdFrame.Position = UDim2.new(0, 10, 0, 124)
BotIdFrame.BackgroundColor3 = Color3.fromRGB(26, 30, 44)
BotIdFrame.BorderSizePixel = 0
BotIdFrame.ClipsDescendants = true
BotIdFrame.Parent = Main
Instance.new("UICorner", BotIdFrame).CornerRadius = UDim.new(0, 6)

local BotIdBox = Instance.new("TextBox")
BotIdBox.Size = UDim2.new(1, -16, 1, 0)
BotIdBox.Position = UDim2.new(0, 8, 0, 0)
BotIdBox.BackgroundTransparency = 1
BotIdBox.PlaceholderText = "ID de usuario del bot que debe recibir la mencion (opcional)..."
BotIdBox.Text = Config.BotUserId
BotIdBox.TextColor3 = Color3.fromRGB(210, 200, 255)
BotIdBox.Font = Enum.Font.Gotham
BotIdBox.TextSize = 11
BotIdBox.TextXAlignment = Enum.TextXAlignment.Left
BotIdBox.ClearTextOnFocus = false
BotIdBox.Parent = BotIdFrame

local function SaveBotIdFromBox()
    local raw = BotIdBox.Text
    local botId = SanitizeBotUserId(raw)
    Config.BotUserId = botId
    if botId ~= "" and botId ~= raw then
        BotIdBox.Text = botId
    end
    SaveConfig()
    if botId == "" and raw:gsub("%s+", "") ~= "" then
        SetStatus("ID de bot invalido: usa solo numeros de Discord.", true)
        return false
    end
    SetStatus("Datos guardados permanentemente.", false)
    return true
end
table.insert(Connections, BotIdBox.FocusLost:Connect(SaveBotIdFromBox))
table.insert(Connections, BotIdBox:GetPropertyChangedSignal("Text"):Connect(function()
    local currentId = BotIdBox.Text
    if currentId and currentId ~= "" then
        Config.BotUserId = SanitizeBotUserId(currentId)
        SaveConfig()
    end
end))

local Toggle = Instance.new("TextButton")
Toggle.Size = UDim2.new(1, -20, 0, 32)
Toggle.Position = UDim2.new(0, 10, 0, 164)
Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
Toggle.Font = Enum.Font.GothamBold
Toggle.TextSize = 11
Toggle.Parent = Main
Instance.new("UICorner", Toggle).CornerRadius = UDim.new(0, 6)

local function RefreshToggle()
    Toggle.BackgroundColor3 = Config.AutoSendEnabled and Color3.fromRGB(40, 167, 69)
        or Color3.fromRGB(220, 53, 69)
    Toggle.Text = Config.AutoSendEnabled and "Auto-envio en regeneracion: ACTIVADO"
        or "Auto-envio en regeneracion: DESACTIVADO"
end
RefreshToggle()

table.insert(Connections, Toggle.MouseButton1Click:Connect(function()
    Config.AutoSendEnabled = not Config.AutoSendEnabled
    RefreshToggle()
    SaveConfig()
    SetStatus(Config.AutoSendEnabled and "Auto-envio activado." or "Auto-envio desactivado.", false)
end))

local SaveBtn = Instance.new("TextButton")
SaveBtn.Size = UDim2.new(1, -20, 0, 30)
SaveBtn.Position = UDim2.new(0, 10, 0, 202)
SaveBtn.BackgroundColor3 = Color3.fromRGB(25, 95, 155)
SaveBtn.Text = "💾 Guardar datos"
SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveBtn.Font = Enum.Font.GothamBold
SaveBtn.TextSize = 11
SaveBtn.Parent = Main
Instance.new("UICorner", SaveBtn).CornerRadius = UDim.new(0, 6)

table.insert(Connections, SaveBtn.MouseButton1Click:Connect(function()
    local okWebhook = SaveWebhookFromBox()
    local okBot = SaveBotIdFromBox()
    SaveConfig()
    if okWebhook then
        SetStatus("Configuracion guardada permanentemente en disco.", false)
    else
        SetStatus("Pega tu URL de webhook antes de guardar.", true)
    end
end))

local TestBtn = Instance.new("TextButton")
TestBtn.Size = UDim2.new(0.5, -15, 0, 32)
TestBtn.Position = UDim2.new(0, 10, 0, 238)
TestBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 220)
TestBtn.Text = "Probar webhook"
TestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TestBtn.Font = Enum.Font.GothamBold
TestBtn.TextSize = 11
TestBtn.Parent = Main
Instance.new("UICorner", TestBtn).CornerRadius = UDim.new(0, 6)

local ScanBtn = Instance.new("TextButton")
ScanBtn.Size = UDim2.new(0.5, -15, 0, 32)
ScanBtn.Position = UDim2.new(0.5, 5, 0, 238)
ScanBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
ScanBtn.Text = "Escanear y enviar"
ScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanBtn.Font = Enum.Font.GothamBold
ScanBtn.TextSize = 11
ScanBtn.Parent = Main
Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 6)

table.insert(Connections, TestBtn.MouseButton1Click:Connect(function()
    if SaveWebhookFromBox() and SaveBotIdFromBox() then
        SetStatus("Enviando prueba...", false)
        task.spawn(function()
            local ok, message = PostDiscord("Conexion correcta. Monitor de Steal An Egg activo.")
            SetStatus(message, not ok)
        end)
    end
end))

table.insert(Connections, ScanBtn.MouseButton1Click:Connect(function()
    if SaveWebhookFromBox() and SaveBotIdFromBox() then
        SetStatus("Leyendo EggWorld y catalogos del cliente...", false)
        ScanBtn.Text = "Escaneando..."
        ScanBtn.Active = false
        task.spawn(function()
            local ok, message = SafeSendEggReport("manual")
            SetStatus(message, not ok)
            if ScriptRunning and ScanBtn and ScanBtn.Parent then
                ScanBtn.Text = "Escanear y enviar"
                ScanBtn.Active = true
            end
        end)
    end
end))

local DiagnosticBtn = Instance.new("TextButton")
DiagnosticBtn.Size = UDim2.new(1, -20, 0, 30)
DiagnosticBtn.Position = UDim2.new(0, 10, 0, 276)
DiagnosticBtn.BackgroundColor3 = Color3.fromRGB(105, 75, 170)
DiagnosticBtn.Text = "Copiar diagnostico del mapa actual"
DiagnosticBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DiagnosticBtn.Font = Enum.Font.GothamBold
DiagnosticBtn.TextSize = 10
DiagnosticBtn.Parent = Main
Instance.new("UICorner", DiagnosticBtn).CornerRadius = UDim.new(0, 6)

table.insert(Connections, DiagnosticBtn.MouseButton1Click:Connect(function()
    DiagnosticBtn.Active = false
    DiagnosticBtn.Text = "Leyendo snapshot y objetos fisicos..."
    SetStatus("Creando diagnostico del mapa visible...", false)
    task.spawn(function()
        local eggs = FetchSnapshotOnly()
        if eggs and #eggs > 0 then
            local message = SaveSchemaDiagnostic(eggs, {})
            SetStatus(message .. " Pegalo en Codex.", false)
        else
            SetStatus("No se pudo obtener el snapshot para diagnostico.", true)
        end
        if ScriptRunning and DiagnosticBtn and DiagnosticBtn.Parent then
            DiagnosticBtn.Active = true
            DiagnosticBtn.Text = "Copiar diagnostico del mapa actual"
        end
    end)
end))

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(1, -20, 0, 66)
Info.Position = UDim2.new(0, 10, 0, 314)
Info.BackgroundTransparency = 1
Info.Text = "[-] Minimiza a un boton flotante | [X] Apaga el script\nInsert / K: Ocultar o mostrar | Arrastra el menu donde quieras"
Info.TextWrapped = true
Info.TextColor3 = Color3.fromRGB(150, 155, 175)
Info.Font = Enum.Font.Gotham
Info.TextSize = 10
Info.Parent = Main

local function MinimizeToWidget()
    SaveWebhookFromBox()
    SaveBotIdFromBox()
    Main.Visible = false
    MiniWidget.Visible = true
end

local function RestoreFromWidget()
    MiniWidget.Visible = false
    Main.Visible = true
end

table.insert(Connections, MinimizeBtn.MouseButton1Click:Connect(MinimizeToWidget))
table.insert(Connections, MiniWidget.MouseButton1Click:Connect(RestoreFromWidget))

local function TerminateScript()
    if not ScriptRunning then
        return
    end
    ScriptRunning = false
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Connections)
    if MiniWidget and MiniWidget.Parent then
        MiniWidget:Destroy()
    end
    if ScreenGui and ScreenGui.Parent then
        ScreenGui:Destroy()
    end
    if Environment.__STEAL_AN_EGG_TRACKER_STOP == TerminateScript then
        Environment.__STEAL_AN_EGG_TRACKER_STOP = nil
    end
    print("[StealAnEgg] Monitor detenido.")
end

Environment.__STEAL_AN_EGG_TRACKER_STOP = TerminateScript
table.insert(Connections, CloseBtn.MouseButton1Click:Connect(TerminateScript))

table.insert(Connections, UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and (input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.K) then
        if ScriptRunning and Main and Main.Parent and MiniWidget and MiniWidget.Parent then
            if Main.Visible then
                MinimizeToWidget()
            else
                RestoreFromWidget()
            end
        end
    end
end))

--------------------------------------------------------------------------
-- EVENTOS Y DEBOUNCE DE UNA REGENERACION COMPLETA
--------------------------------------------------------------------------
local function StorePayload(...)
    table.insert(EventPayloads, table.pack(...))
    while #EventPayloads > 180 do
        table.remove(EventPayloads, 1)
    end
end

local function StoreCyclePayload(...)
    StorePayload(...)
    if RegenScheduled then
        RegenLastActivity = os.clock()
        RegenRevision = RegenRevision + 1
    end
end

local function ScheduleRegen(source, ...)
    if not ScriptRunning then
        return
    end
    local now = os.clock()
    RegenLastActivity = now
    if not RegenScheduled and LastRegenAttempt > 0 and now - LastRegenAttempt < 45 then
        StorePayload(...)
        return
    end
    if not RegenScheduled then
        table.clear(EventPayloads)
    end
    StorePayload(...)
    RegenRevision = RegenRevision + 1
    local observedRevision = RegenRevision

    if RegenScheduled then
        return
    end
    RegenScheduled = true
    task.spawn(function()
        SetStatus("Regeneracion detectada; esperando que termine el lote...", false)
        local started = os.clock()
        task.wait(4)
        while ScriptRunning and os.clock() - started < 18
            and os.clock() - RegenLastActivity < 3 do
            observedRevision = RegenRevision
            task.wait(0.5)
        end
        RegenScheduled = false
        LastRegenAttempt = os.clock()
        if ScriptRunning and Config.AutoSendEnabled then
            local ok, message = SafeSendEggReport("regen")
            if ok then
                SetStatus(source .. ": " .. message, false)
            elseif message ~= "Evento duplicado." then
                SetStatus(source .. ": " .. message, true)
            end
        end
    end)
end

local ConnectedRemotes = {}

local function ConnectRemote(remote, callback)
    if remote and remote:IsA("RemoteEvent") and not ConnectedRemotes[remote] then
        ConnectedRemotes[remote] = true
        table.insert(Connections, remote.OnClientEvent:Connect(callback))
    end
end

local function BindNetworkEvents()
    ResolveNetworkRoutes()
    ConnectRemote(RE_Batch, function(...)
        -- Este es el evento real del lote de regeneracion. Todas sus emisiones
        -- se agrupan en una sola lectura y el bloqueo evita un aviso por area.
        ScheduleRegen("Lote regenerado", ...)
    end)
    ConnectRemote(RE_Rarities, function(...)
        StoreCyclePayload(...)
    end)
    ConnectRemote(RE_Shifted, function(...)
        StoreCyclePayload(...)
    end)
    ConnectRemote(RE_Gone, function(...)
        -- Un huevo recogido no es una regeneracion y no debe crear un aviso.
    end)
    ConnectRemote(RE_Countdown, function(seconds, ...)
        local value = tonumber(seconds)
        local crossedToRegeneration = value and value <= 1
            and (LastCountdownValue == nil or LastCountdownValue > 1)
        LastCountdownValue = value or LastCountdownValue
        if crossedToRegeneration then
            ScheduleRegen("Nuevo ciclo", seconds, ...)
        end
    end)
    ConnectRemote(RE_ZoneAnchor, function(...)
        local args = table.pack(...)
        local position, areaId, areaName
        for index = 1, args.n do
            position = position or ToPosition(args[index])
            local scalar = ScalarText(args[index])
            if scalar then
                if AreaCatalog[scalar] then
                    areaId = scalar
                elseif tonumber(scalar) then
                    areaId = areaId or scalar
                else
                    areaName = areaName or scalar
                end
            end
        end
        AddAreaAnchor(areaName or areaId, position)
    end)
end

BindNetworkEvents()

-- Si el executor se lanzo antes de que el juego terminara de cargar, vuelve a
-- resolver las rutas sin bloquear la creacion ni el render de la interfaz.
task.spawn(function()
    for _ = 1, 30 do
        if not ScriptRunning then
            return
        end
        BindNetworkEvents()
        if RF_FieldSnapshot and RE_Batch and RE_Countdown then
            return
        end
        task.wait(1)
    end
end)

if game.PlaceId ~= EXPECTED_PLACE_ID then
    SetStatus("Aviso: PlaceId distinto al de Steal An Egg.", true)
elseif not Networking then
    SetStatus("Packages.Networking aun no esta cargado.", true)
elseif not RF_FieldSnapshot and not RE_Batch then
    SetStatus("EggWorld no esta cargado; queda activo el respaldo fisico.", true)
else
    SetStatus("Monitor activo. Esperando la siguiente regeneracion.", false)
end

-- Respaldo automatico para executors que no entregan los RemoteEvents al
-- cliente. Compara identidades Uid del snapshot, pero nunca publica por cada
-- consulta: exige que cambie al menos la mitad del mapa y que el resultado
-- completo permanezca igual en dos lecturas consecutivas.
task.spawn(function()
    task.wait(2)
    while ScriptRunning do
        if Config.AutoSendEnabled and not RegenScheduled then
            local eggs = FetchSnapshotOnly()
            if eggs and #eggs > 0 then
                if ExpectedAreaCount == 0 then
                    RememberMapShape(eggs)
                end
                local mapIsComplete = MapMeetsExpectedShape(eggs)

                if mapIsComplete then
                    RememberMapShape(eggs)

                    local current = BuildSnapshotIdentity(eggs)
                    if current.Count > 0 then
                        if not SnapshotMonitorBaseline then
                            SnapshotMonitorBaseline = current
                        else
                            local changeRatio = SnapshotChangeRatio(
                                SnapshotMonitorBaseline,
                                current
                            )

                            if changeRatio >= 0.5 then
                                if current.Signature == SnapshotMonitorCandidate then
                                    SnapshotMonitorCandidateSeen = SnapshotMonitorCandidateSeen + 1
                                else
                                    SnapshotMonitorCandidate = current.Signature
                                    SnapshotMonitorCandidateSeen = 1
                                end

                                if SnapshotMonitorCandidateSeen >= 2
                                    and current.Signature ~= LastAutoSnapshotSignature then
                                    LastAutoSnapshotSignature = current.Signature
                                    SnapshotMonitorBaseline = current
                                    SnapshotMonitorCandidate = ""
                                    SnapshotMonitorCandidateSeen = 0
                                    ScheduleRegen("Regeneracion detectada por snapshot")
                                end
                            elseif changeRatio <= 0.2 then
                                -- Cambios pequenos corresponden a huevos
                                -- individuales; pasan a ser la nueva base y
                                -- nunca producen un aviso de regeneracion.
                                SnapshotMonitorBaseline = current
                                SnapshotMonitorCandidate = ""
                                SnapshotMonitorCandidateSeen = 0
                            end
                        end
                    end
                end
            end
        end
        task.wait(4)
    end
end)

print("[StealAnEgg Tracker v2] Monitor iniciado sin nombres hardcodeados.")

end, function(err)
    return tostring(err)
end)

if not __runOk then
    warn("[StealAnEgg] Error de inicio: " .. tostring(__runError))
    pcall(function()
        local errorGui = Instance.new("ScreenGui")
        errorGui.Name = "StealEggStartupError"
        errorGui.ResetOnSpawn = false
        errorGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

        local errorLabel = Instance.new("TextLabel")
        errorLabel.Size = UDim2.new(0, 520, 0, 100)
        errorLabel.Position = UDim2.new(0.5, -260, 0.35, -50)
        errorLabel.BackgroundColor3 = Color3.fromRGB(90, 20, 25)
        errorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        errorLabel.TextWrapped = true
        errorLabel.Font = Enum.Font.GothamBold
        errorLabel.TextSize = 13
        errorLabel.Text = "Steal An Egg - error de inicio:\n" .. tostring(__runError)
        errorLabel.Parent = errorGui
        Instance.new("UICorner", errorLabel).CornerRadius = UDim.new(0, 8)
    end)
end
 to join this conversation on GitHub. Already have an account? Sign in to comment
Footer
© 2026 GitHub, Inc.
Footer navigation
Terms
Privacy
Security
Status
Community
Docs
Contact
Manage cookies
Do not share my personal information
