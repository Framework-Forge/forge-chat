RegisterServerEvent('chat:init')
RegisterServerEvent('chat:addTemplate')
RegisterServerEvent('chat:addMessage')
RegisterServerEvent('chat:addSuggestion')
RegisterServerEvent('chat:removeSuggestion')
RegisterServerEvent('_chat:messageEntered')
RegisterServerEvent('chat:clear')

local RESOURCE = GetCurrentResourceName()
local STICKERS_FILE = 'data/stickers.json'
local SETTINGS_FILE = 'data/chat_settings.json'
local stickers = {}
local chatSettings = {}
local lastGiphyRequest = {}
local vipStyles = {}

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$')
end


local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function safeHex(value, fallback)
    value = tostring(value or ''):upper()
    if value:match('^#%x%x%x%x%x%x$') then return value end
    return fallback
end
local function normalizeVipStyleInput(input)
    input = type(input) == 'table' and input or {}
    local config = Config.Chat.vip or {}
    local allowed = {}
    for index = 1, #(config.effects or {}) do
        allowed[tostring(config.effects[index]):lower()] = true
    end

    local effect = tostring(input.effect or 'none'):lower()
    if not allowed[effect] then effect = 'none' end

    return {
        color = safeHex(input.color, nil),
        neon = input.neon == true,
        glow = math.floor(clamp(input.glow or 10, 0, tonumber(config.maxGlow) or 24)),
        effect = effect,
    }
end
local function vipMetadata(playerSource)
    local config = type(Config.Chat.vip) == 'table' and Config.Chat.vip or {}
    if config.enabled == false then return nil end
    local framework = pr_lib and pr_lib.framework
    local getter = framework and (framework.GetPlayerMetadata or framework.getPlayerMetadata)
    if type(getter) ~= 'function' then return nil end

    local ok, metadata = pcall(getter, playerSource, config.metadataKey or 'vip')
    if not ok or type(metadata) ~= 'table' then
        metadata = nil
    end

    if not metadata and GetResourceState('forge-core') == 'started' then
        local exportOk, active = pcall(function()
            return exports['forge-core']:GetVip(playerSource)
        end)
        if exportOk and type(active) == 'table' then metadata = active end
    end

    if type(metadata) ~= 'table' then return nil end
    local expiresAt = tonumber(metadata.expiresAt) or 0
    local tier = tostring(metadata.tier or ''):lower()
    if tier == '' or tier == 'standard' or expiresAt <= os.time() then return nil end
    return { tier = tier, expiresAt = expiresAt }
end

local function sanitizeVipStyle(playerSource, input)
    local vip = vipMetadata(playerSource)
    if not vip then return nil, nil end
    input = normalizeVipStyleInput(input)
    local config = Config.Chat.vip or {}
    local tierColors = type(config.tierColors) == 'table' and config.tierColors or {}
    local fallbackColor = safeHex(tierColors[vip.tier], safeHex(config.defaultColor, '#F5C542'))
    return {
        color = safeHex(input.color, fallbackColor),
        neon = input.neon == true,
        glow = math.floor(clamp(input.glow or 10, 0, tonumber(config.maxGlow) or 24)),
        effect = input.effect,
    }, vip
end

local function updateVipStyle(playerSource, input)
    if type(input) == 'table' then
        vipStyles[playerSource] = normalizeVipStyleInput(input)
    end
    local style, vip = sanitizeVipStyle(playerSource, vipStyles[playerSource])
    if style then vipStyles[playerSource] = style end
    return style ~= nil, style, vip
end

local function vipPayload(playerSource)
    local style, vip = sanitizeVipStyle(playerSource, vipStyles[playerSource])
    if not style or not vip then
        return nil
    end
    vipStyles[playerSource] = style
    return { active = true, tier = vip.tier, expiresAt = vip.expiresAt, style = style }
end

local function sanitizeSettings(value)
    value = type(value) == 'table' and value or {}
    local defaults = Config.Chat.theme or {}
    local defaultCodes = defaults.colorCodes or {}
    local incomingCodes = type(value.colorCodes) == 'table' and value.colorCodes or {}
    local colorCodes = {}
    local defaultChannels = defaults.channelColors or {}
    local incomingChannels = type(value.channelColors) == 'table' and value.channelColors or {}
    local channelColors = {}
    for _, channel in ipairs({ 'feed', 'ooc', 'me', 'dispatch', 'staff' }) do
        channelColors[channel] = safeHex(incomingChannels[channel], defaultChannels[channel] or defaults.accentColor or '#FF8C2A')
    end

    for index = 0, 9 do
        local key = tostring(index)
        colorCodes[key] = safeHex(incomingCodes[key], defaultCodes[key] or '#FFFFFF')
    end

    local weights = { [400] = true, [500] = true, [600] = true, [700] = true, [800] = true, [900] = true }
    local fontWeight = math.floor(tonumber(value.fontWeight) or tonumber(defaults.fontWeight) or 400)
    if not weights[fontWeight] then fontWeight = 400 end

    return {
        accentColor = safeHex(value.accentColor, defaults.accentColor or '#FF8C2A'),
        messageBackground = safeHex(value.messageBackground, defaults.messageBackground or '#0A0E14'),
        messageOpacity = clamp(value.messageOpacity or defaults.messageOpacity or 0.92, 0.1, 1.0),
        messageShadow = value.messageShadow == nil and defaults.messageShadow ~= false or value.messageShadow == true,
        textColor = safeHex(value.textColor, defaults.textColor or '#E9EDF2'),
        authorColor = safeHex(value.authorColor, defaults.authorColor or '#FFFFFF'),
        mutedColor = safeHex(value.mutedColor, defaults.mutedColor or '#8F98A6'),
        fontSize = math.floor(clamp(value.fontSize or defaults.fontSize or 13, 10, 24)),
        fontWeight = fontWeight,
        borderRadius = math.floor(clamp(value.borderRadius or defaults.borderRadius or 2, 0, 18)),
        borderWidth = math.floor(clamp(value.borderWidth or defaults.borderWidth or 3, 0, 8)),
        channelColors = channelColors,
        colorCodes = colorCodes,
    }
end

local function loadSettings()
    local raw = LoadResourceFile(RESOURCE, SETTINGS_FILE)
    if not raw or raw == '' then
        chatSettings = sanitizeSettings(Config.Chat.theme)
        SaveResourceFile(RESOURCE, SETTINGS_FILE, json.encode(chatSettings), -1)
        return
    end

    local ok, decoded = pcall(json.decode, raw)
    chatSettings = sanitizeSettings(ok and decoded or Config.Chat.theme)
end

local function saveSettings()
    SaveResourceFile(RESOURCE, SETTINGS_FILE, json.encode(chatSettings), -1)
end

local function broadcastSettings()
    TriggerClientEvent('forge-chat:client:settingsUpdate', -1, chatSettings)
end
local function loadStickers()

    local raw = LoadResourceFile(RESOURCE, STICKERS_FILE)
    if not raw or raw == '' then
        stickers = {}
        return
    end

    local ok, decoded = pcall(json.decode, raw)
    stickers = ok and type(decoded) == 'table' and decoded or {}
end

local function saveStickers()
    SaveResourceFile(RESOURCE, STICKERS_FILE, json.encode(stickers), -1)
end

local function broadcastStickers()
    TriggerClientEvent('forge-chat:client:stickersUpdate', -1, stickers)
end

local function isAdmin(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, Config.Stickers.acePermission)
        or IsPlayerAceAllowed(src, 'admin')
        or IsPlayerAceAllowed(src, 'group.admin') then
        return true
    end

    local framework = pr_lib and pr_lib.framework
    local getter = framework and (framework.GetPlayerMetadata or framework.getPlayerMetadata)
    if type(getter) ~= 'function' then return false end
    local ok, role = pcall(getter, src, 'staff')
    role = ok and tostring(role or ''):lower():gsub('^group%.', '') or ''
    return role == 'admin'
end

local function safeImageUrl(value)
    value = trim(value)
    if #value < 8 or #value > Config.Stickers.maxUrlLength then return nil end
    if not value:match('^https://') then return nil end
    return value
end

local function nextStickerId()
    local highest = 0
    for _, sticker in ipairs(stickers) do
        highest = math.max(highest, tonumber(sticker.id) or 0)
    end
    return highest + 1
end

local function findSticker(id)
    id = tonumber(id)
    for index, sticker in ipairs(stickers) do
        if tonumber(sticker.id) == id then return index, sticker end
    end
end

local function urlEncode(value)
    return tostring(value or ''):gsub('\n', '\r\n'):gsub('([^%w%-_%.~])', function(char)
        return string.format('%%%02X', string.byte(char))
    end)
end

local function refreshCommands(player)
    local commandApi = pr_lib and pr_lib.addCommand
    local known = {}
    if commandApi and type(commandApi.getSuggestions) == 'function' then
        local registered = commandApi.getSuggestions()
        for index = 1, #registered do known[registered[index].name:lower()] = true end
    end
    if commandApi and type(commandApi.sendSuggestions) == 'function' then commandApi.sendSuggestions(player) end

    if not GetRegisteredCommands then return end
    local fallbacks = {}
    for _, command in ipairs(GetRegisteredCommands()) do
        local name = '/' .. command.name
        if command.name:sub(1, 1) ~= '+' and command.name:sub(1, 1) ~= '-'
            and not known[name:lower()] and IsPlayerAceAllowed(player, ('command.%s'):format(command.name)) then
            fallbacks[#fallbacks + 1] = { name = name, help = 'Comando registrado sem descrição de uso.' }
        end
    end
    if #fallbacks > 0 then TriggerClientEvent('chat:addSuggestions', player, fallbacks) end
end

AddEventHandler('chat:init', function(vipStyle)
    local playerSource = source
    updateVipStyle(playerSource, vipStyle)
    refreshCommands(playerSource)
    TriggerClientEvent('forge-chat:client:stickersUpdate', playerSource, stickers)
    TriggerClientEvent('forge-chat:client:settingsUpdate', playerSource, chatSettings)
    TriggerClientEvent('forge-chat:client:vipStatus', playerSource, vipPayload(playerSource) or { active = false })

    -- During a full server boot the NUI can become ready before qbx_core has
    -- restored PlayerData. Recheck after the player cache is available.
    SetTimeout(1500, function()
        if GetPlayerName(playerSource) then
            TriggerClientEvent('forge-chat:client:vipStatus', playerSource, vipPayload(playerSource) or { active = false })
        end
    end)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local playerSource = source
    SetTimeout(750, function()
        if not GetPlayerName(playerSource) then return end
        refreshCommands(playerSource)
        TriggerClientEvent('forge-chat:client:vipStatus', playerSource, vipPayload(playerSource) or { active = false })
    end)
end)
local function showMeBubble(playerSource, message)
    local bubble = type(Config.Chat.meBubble) == 'table' and Config.Chat.meBubble or {}
    if bubble.enabled == false then return end

    if not pr_lib or type(pr_lib.NotifyBubbleAll) ~= 'function' then
        print(('[%s] NotifyBubbleAll indisponivel; /me foi enviado somente ao chat.'):format(RESOURCE))
        return
    end

    local ok, err = pcall(pr_lib.NotifyBubbleAll, playerSource, {
        description = message,
        title = bubble.title,
        type = bubble.type or 'inform',
        icon = bubble.icon or 'chat-dots-fill',
        duration = tonumber(bubble.duration) or 5000,
        maxDistance = tonumber(bubble.maxDistance) or 20.0,
        wallDetection = bubble.wallDetection ~= false,
    })

    if not ok then
        print(('[%s] Falha ao exibir balao do /me: %s'):format(RESOURCE, tostring(err)))
    end
end

local function broadcastTextMessage(playerSource, channel, message)
    message = trim(message):sub(1, Config.Chat.maxMessageLength)
    if message == '' then return false end

    channel = trim(channel):lower()
    if channel ~= 'feed' and channel ~= 'ooc' and channel ~= 'me' and channel ~= 'dispatch' and channel ~= 'staff' then
        channel = 'feed'
    end

    local name = GetPlayerName(playerSource) or ('ID %s'):format(playerSource)
    local templateId = channel == 'ooc' and 'ooc' or 'cnormal'
    local args = templateId == 'ooc' and { name, tostring(playerSource), message } or { name, message }

    TriggerClientEvent('forge-chat:client:receiveMessage', -1, {
        templateId = templateId,
        args = args,
        channel = channel,
        author = name,
        vip = vipPayload(playerSource)
    })

    if channel == 'me' then
        showMeBubble(playerSource, message)
    end

    return true
end

pr_lib.callback.register('forge-chat:callback:vipStyle', function(playerSource, input)
    updateVipStyle(playerSource, input)
    return true, vipPayload(playerSource) or { active = false }
end)
RegisterNetEvent('forge-chat:server:sendMessage', function(channel, message)
    broadcastTextMessage(source, channel, message)
end)

pr_lib.addCommand('me', {
    help = 'Exibe uma ação no canal Me e em um balão sobre o seu personagem.',
    params = {
        { name = 'texto', type = 'longString', help = 'Texto da ação que será exibida.' },
    },
}, function(playerSource, params)
    if playerSource <= 0 then return end
    broadcastTextMessage(playerSource, 'me', params.texto)
end)

RegisterNetEvent('forge-chat:server:sendMedia', function(channel, media)
    local src = source
    if type(media) ~= 'table' then return end

    local outgoing
    if media.type == 'gif' then
        local url = safeImageUrl(media.url)
        if not url or not url:find('giphy', 1, true) then return end
        outgoing = { type = 'gif', url = url, title = trim(media.title):sub(1, 80) }
    elseif media.type == 'sticker' then
        local _, sticker = findSticker(media.id)
        if not sticker then return end
        outgoing = { type = 'sticker', id = sticker.id, name = sticker.name, imageUrl = sticker.imageUrl }
    else
        return
    end

    channel = trim(channel):lower()
    if channel ~= 'feed' and channel ~= 'ooc' and channel ~= 'me' and channel ~= 'dispatch' and channel ~= 'staff' then
        channel = 'feed'
    end

    local name = GetPlayerName(src) or ('ID %s'):format(src)
    TriggerClientEvent('forge-chat:client:receiveMessage', -1, {
        templateId = 'cnormal',
        args = { name, '' },
        channel = channel,
        author = name,
        vip = vipPayload(src),
        media = outgoing
    })
end)

RegisterNetEvent('forge-chat:server:giphySearch', function(requestId, query)
    local src = source
    local now = GetGameTimer()
    local cooldown = Config.Giphy.searchCooldownMs or 1200

    if lastGiphyRequest[src] and now - lastGiphyRequest[src] < cooldown then
        TriggerClientEvent('forge-chat:client:giphyResults', src, requestId, {}, 'Aguarde um instante antes de pesquisar novamente.')
        return
    end
    lastGiphyRequest[src] = now

    if not Config.Giphy.enabled or not ServerConfig.GiphyApiKey or ServerConfig.GiphyApiKey == '' then
        TriggerClientEvent('forge-chat:client:giphyResults', src, requestId, {}, 'A integração com a GIPHY está desativada.')
        return
    end

    query = trim(query):sub(1, 50)
    local endpoint = query == '' and 'trending' or 'search'
    local url = ('https://api.giphy.com/v1/gifs/%s?api_key=%s&limit=%d&rating=%s&lang=%s&country_code=%s'):format(
        endpoint,
        urlEncode(ServerConfig.GiphyApiKey),
        math.min(tonumber(Config.Giphy.limit) or 24, 50),
        urlEncode(Config.Giphy.rating or 'pg'),
        urlEncode(Config.Giphy.language or 'pt'),
        urlEncode(Config.Giphy.countryCode or 'BR')
    )

    if query ~= '' then url = url .. '&q=' .. urlEncode(query) end

    PerformHttpRequest(url, function(status, body)
        if status ~= 200 or not body then
            print(('[%s] GIPHY HTTP %s: %s'):format(RESOURCE, status or 0, tostring(body or ''):sub(1, 300)))
            local errorMessage = status == 403 and 'A chave da GIPHY foi recusada ou está sem permissão.'
                or status == 429 and 'O limite de requisições da GIPHY foi atingido.'
                or ('Falha ao consultar a GIPHY (%s).'):format(status or 0)
            TriggerClientEvent('forge-chat:client:giphyResults', src, requestId, {}, errorMessage)
            return
        end

        local ok, payload = pcall(json.decode, body)
        if not ok or type(payload) ~= 'table' or type(payload.data) ~= 'table' then
            TriggerClientEvent('forge-chat:client:giphyResults', src, requestId, {}, 'A GIPHY retornou uma resposta inválida.')
            return
        end

        local items = {}
        for _, gif in ipairs(payload.data) do
            local images = gif.images or {}
            local original = images.fixed_height or images.downsized or images.original or {}
            local preview = images.fixed_width_small or images.fixed_height_small or images.preview_gif or original
            if original.url then
                items[#items + 1] = {
                    id = gif.id,
                    title = gif.title or 'GIF',
                    url = original.url,
                    previewUrl = preview.url or original.url
                }
            end
        end

        TriggerClientEvent('forge-chat:client:giphyResults', src, requestId, items, nil)
    end, 'GET', '', { ['Accept'] = 'application/json' })
end)

RegisterNetEvent('forge-chat:server:requestStickers', function()
    TriggerClientEvent('forge-chat:client:stickersUpdate', source, stickers)
end)

local function openAdminFor(source)
    if source == 0 then
        print(('[%s] O painel administrativo deve ser aberto por um jogador no FiveM.'):format(RESOURCE))
        return false
    end

    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            templateId = 'system',
            args = { 'Você não possui permissão para abrir o painel administrativo do chat.' }
        })
        return false
    end

    TriggerClientEvent('forge-chat:client:openStickerAdmin', source, stickers, true, chatSettings)
    return true
end

pr_lib.addCommand(Config.Stickers.adminCommand, {
    help = 'Abre o painel administrativo de stickers e do visual global do chat.',
    suggestionAccess = function(playerSource)
        return isAdmin(playerSource)
    end,
}, function(playerSource)
    openAdminFor(playerSource)
end)

RegisterNetEvent('forge-chat:server:openAdmin', function()
    openAdminFor(source)
end)


RegisterNetEvent('forge-chat:server:saveSettings', function(data)
    local src = source
    if not isAdmin(src) then
        TriggerClientEvent('forge-chat:client:adminResult', src, false, 'Sem permissão.', stickers, chatSettings)
        return
    end

    chatSettings = sanitizeSettings(data)
    saveSettings()
    broadcastSettings()
    TriggerClientEvent('forge-chat:client:adminResult', src, true, nil, stickers, chatSettings)
end)
RegisterNetEvent('forge-chat:server:saveSticker', function(data)

    local src = source
    if not isAdmin(src) then
        TriggerClientEvent('forge-chat:client:adminResult', src, false, 'Sem permissão.', stickers)
        return
    end

    data = type(data) == 'table' and data or {}
    local name = trim(data.name):sub(1, Config.Stickers.maxNameLength)
    local imageUrl = safeImageUrl(data.imageUrl)
    if name == '' or not imageUrl then
        TriggerClientEvent('forge-chat:client:adminResult', src, false, 'Use um nome válido e uma URL HTTPS.', stickers)
        return
    end

    local id = tonumber(data.id)
    if id then
        local _, sticker = findSticker(id)
        if not sticker then
            TriggerClientEvent('forge-chat:client:adminResult', src, false, 'Sticker não encontrado.', stickers)
            return
        end
        sticker.name = name
        sticker.imageUrl = imageUrl
        sticker.updatedAt = os.time()
        sticker.updatedBy = GetPlayerName(src)
    else
        stickers[#stickers + 1] = {
            id = nextStickerId(),
            name = name,
            imageUrl = imageUrl,
            createdAt = os.time(),
            createdBy = GetPlayerName(src)
        }
    end

    saveStickers()
    broadcastStickers()
    TriggerClientEvent('forge-chat:client:adminResult', src, true, nil, stickers)
end)

RegisterNetEvent('forge-chat:server:deleteSticker', function(id)
    local src = source
    if not isAdmin(src) then
        TriggerClientEvent('forge-chat:client:adminResult', src, false, 'Sem permissão.', stickers)
        return
    end

    local index = findSticker(id)
    if not index then
        TriggerClientEvent('forge-chat:client:adminResult', src, false, 'Sticker não encontrado.', stickers)
        return
    end

    table.remove(stickers, index)
    saveStickers()
    broadcastStickers()
    TriggerClientEvent('forge-chat:client:adminResult', src, true, nil, stickers)
end)

AddEventHandler('playerDropped', function()
    lastGiphyRequest[source] = nil
    vipStyles[source] = nil
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then return end
    loadStickers()
    Wait(500)
    for _, player in ipairs(GetPlayers()) do refreshCommands(player) end
end)

loadStickers()
loadSettings()
print(('[%s] carregado com %d sticker(s) e tema global.'):format(RESOURCE, #stickers))














