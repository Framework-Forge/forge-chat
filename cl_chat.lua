local chatInputActive = false
local chatInputActivating = false
local chatHidden = true
local chatLoaded = false
local pendingGiphy = {}
local requestCounter = 0
local adminParentMenu = nil

RegisterNetEvent('chatMessage')
RegisterNetEvent('chat:addTemplate')
RegisterNetEvent('chat:addMessage')
RegisterNetEvent('chat:addSuggestion')
RegisterNetEvent('chat:addSuggestions')
RegisterNetEvent('chat:removeSuggestion')
RegisterNetEvent('__cfx_internal:serverPrint')
RegisterNetEvent('_chat:messageEntered')

AddEventHandler('chatMessage', function(author, ctype, text)
    local args = { text }
    if author ~= '' then table.insert(args, 1, author) end

    SendNUIMessage({
        type = 'ON_MESSAGE',
        message = {
            templateId = ctype or 'cnormal',
            args = args
        }
    })
end)

AddEventHandler('__cfx_internal:serverPrint', function(msg)
    SendNUIMessage({ type = 'ON_MESSAGE', message = { templateId = 'system', args = { msg } } })
end)

AddEventHandler('chat:addMessage', function(message)
    SendNUIMessage({ type = 'ON_MESSAGE', message = message })
end)

AddEventHandler('chat:addSuggestion', function(name, help, params)
    SendNUIMessage({ type = 'ON_SUGGESTION_ADD', suggestion = { name = name, help = help, params = params } })
end)

AddEventHandler('chat:addSuggestions', function(suggestions)
    for _, suggestion in ipairs(suggestions) do
        SendNUIMessage({ type = 'ON_SUGGESTION_ADD', suggestion = suggestion })
    end
end)

AddEventHandler('chat:removeSuggestion', function(name)
    SendNUIMessage({ type = 'ON_SUGGESTION_REMOVE', name = name })
end)

AddEventHandler('chat:addTemplate', function(id, html)
    SendNUIMessage({ type = 'ON_TEMPLATE_ADD', template = { id = id, html = html } })
end)

RegisterNUICallback('chatResult', function(data, cb)
    chatInputActive = false
    SetNuiFocus(false, false)

    if not data.canceled then
        if data.media then
            TriggerServerEvent('forge-chat:server:sendMedia', data.channel, data.media)
        elseif data.message and data.message ~= '' then
            if data.message:sub(1, 1) == '/' then
                ExecuteCommand(data.message:sub(2))
            else
                TriggerServerEvent('forge-chat:server:sendMessage', data.channel, data.message)
            end
        end
    end

    cb({ ok = true })
end)

RegisterNUICallback('giphySearch', function(data, cb)
    requestCounter = requestCounter + 1
    local internalId = requestCounter
    pendingGiphy[internalId] = tonumber(data.requestId) or 0
    TriggerServerEvent('forge-chat:server:giphySearch', internalId, tostring(data.query or ''))
    cb({ ok = true })
end)

RegisterNetEvent('forge-chat:client:giphyResults', function(internalId, items, err)
    local nuiRequestId = pendingGiphy[internalId]
    pendingGiphy[internalId] = nil
    if not nuiRequestId then return end

    SendNUIMessage({
        type = 'GIPHY_RESULTS',
        requestId = nuiRequestId,
        items = items or {},
        error = err
    })
end)

RegisterNUICallback('stickersRequest', function(_, cb)
    TriggerServerEvent('forge-chat:server:requestStickers')
    cb({ ok = true })
end)

RegisterNetEvent('forge-chat:client:stickersUpdate', function(stickers)
    SendNUIMessage({ type = 'STICKERS_UPDATE', stickers = stickers or {} })
end)

RegisterNetEvent('forge-chat:client:vipStatus', function(status)
    SendNUIMessage({ type = 'VIP_STATUS_UPDATE', status = status or { active = false } })
end)

RegisterNUICallback('vipStyleSave', function(data, cb)
    pr_lib.callback.trigger('forge-chat:callback:vipStyle', function(ok, status)
        if ok then SendNUIMessage({ type = 'VIP_STATUS_UPDATE', status = status or { active = false } }) end
    end, data)
    cb({ ok = true })
end)
RegisterNetEvent('forge-chat:client:settingsUpdate', function(settings)
    SendNUIMessage({ type = 'CHAT_SETTINGS_UPDATE', settings = settings or {} })
end)

RegisterNetEvent('forge-chat:client:openStickerAdmin', function(stickers, canEdit, settings)
    chatInputActive = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'STICKER_ADMIN_OPEN',
        stickers = stickers or {},
        settings = settings or {},
        canEdit = canEdit == true
    })
end)

RegisterNUICallback('adminStickerSave', function(data, cb)
    TriggerServerEvent('forge-chat:server:saveSticker', data)
    cb({ ok = true })
end)

RegisterNUICallback('adminStickerDelete', function(data, cb)
    TriggerServerEvent('forge-chat:server:deleteSticker', data.id)
    cb({ ok = true })
end)

RegisterNUICallback('adminSettingsSave', function(data, cb)
    TriggerServerEvent('forge-chat:server:saveSettings', data)
    cb({ ok = true })
end)

RegisterNUICallback('adminClose', function(_, cb)
    chatInputActive = false
    SetNuiFocus(false, false)

    local parentMenu = adminParentMenu
    adminParentMenu = nil
    if parentMenu and pr_lib and pr_lib.menus and pr_lib.menus.ShowContext then
        SetTimeout(150, function()
            pr_lib.menus.ShowContext(parentMenu)
        end)
    end

    cb({ ok = true })
end)

RegisterNetEvent('forge-chat:client:adminResult', function(ok, err, stickers, settings)
    SendNUIMessage({
        type = 'STICKER_ADMIN_RESULT',
        ok = ok,
        error = err,
        stickers = stickers or {},
        settings = settings
    })
end)

RegisterNetEvent('forge-chat:client:receiveMessage', function(message)
    SendNUIMessage({ type = 'ON_MESSAGE', message = message })
end)

RegisterNetEvent('chat:clear', function()
    SendNUIMessage({ type = 'ON_CLEAR' })
end)

local function refreshCommands()
    local commandApi = pr_lib and pr_lib.addCommand
    local known = {}
    if commandApi and type(commandApi.getSuggestions) == 'function' then
        local registered = commandApi.getSuggestions()
        for index = 1, #registered do known[registered[index].name:lower()] = true end
    end
    if commandApi and type(commandApi.sendSuggestions) == 'function' then commandApi.sendSuggestions() end

    if not GetRegisteredCommands then return end
    local fallbacks = {}
    for _, command in ipairs(GetRegisteredCommands()) do
        local name = '/' .. command.name
        if command.name:sub(1, 1) ~= '+' and command.name:sub(1, 1) ~= '-'
            and not known[name:lower()] and IsAceAllowed(('command.%s'):format(command.name)) then
            fallbacks[#fallbacks + 1] = { name = name, help = 'Comando registrado sem descrição de uso.' }
        end
    end
    if #fallbacks > 0 then TriggerEvent('chat:addSuggestions', fallbacks) end
end
RegisterNUICallback('loaded', function(data, cb)
    TriggerServerEvent('chat:init', type(data) == 'table' and data.vipStyle or nil)
    refreshCommands()
    chatLoaded = true
    cb({ ok = true })
end)

local function openChatInput()
    SetTextChatEnabled(false)
    if chatInputActive then return end

    chatInputActive = true
    chatInputActivating = true
    SendNUIMessage({ type = 'ON_OPEN' })

    if chatInputActivating then
        SetNuiFocus(true, true)
        chatInputActivating = false
    end
end

local chatKeybind = pr_lib.addKeybind({
    name = 'chatopen',
    description = 'Forge Chat: abrir o chat',
    defaultKey = 'T',
    onPressed = openChatInput,
})
CreateThread(function()
    while true do
        Wait(500)
        if chatLoaded then
            local shouldHide = IsScreenFadedOut() or IsPauseMenuActive()
            if shouldHide ~= chatHidden then
                chatHidden = shouldHide
                SendNUIMessage({ type = 'ON_SCREEN_STATE_CHANGE', shouldHide = shouldHide })
            end
        end
    end
end)

local function openAdminMenu(parentMenu)
    if chatInputActive then return false end
    adminParentMenu = type(parentMenu) == 'string' and parentMenu ~= '' and parentMenu or nil
    TriggerServerEvent('forge-chat:server:openAdmin')
    return true
end


pr_lib.addExports('OpenAdminMenu', openAdminMenu)

