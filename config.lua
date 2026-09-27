Config = {}

Config.Chat = {
    accent = '#FF8C2A',
    maxMessageLength = 280,
    meBubble = {
        enabled = true,
        duration = 5000,
        maxDistance = 20.0,
        title = nil,
        type = 'inform',
        icon = 'chat-dots-fill'
    },
    vip = {
        enabled = true,
        metadataKey = 'vip',
        defaultColor = '#F5C542',
        maxGlow = 24,
        effects = { 'none', 'pulse', 'shimmer', 'rainbow' },
        tierColors = {
            bronze = '#CD7F32',
            gold = '#F5C542',
            diamond = '#4ED7FF',
        }
    },
    defaultChannel = 'Feed',
    channels = {
        { id = 'feed', label = 'Feed' },
        { id = 'ooc', label = 'OOC' },
        { id = 'me', label = 'Me' },
        { id = 'dispatch', label = 'Dispatch' },
        { id = 'staff', label = 'Staff' }
    },
    theme = {
        accentColor = '#FF8C2A',
        messageBackground = '#0A0E14',
        messageOpacity = 0.92,
        messageShadow = true,
        textColor = '#E9EDF2',
        authorColor = '#FFFFFF',
        mutedColor = '#8F98A6',
        fontSize = 13,
        fontWeight = 400,
        borderRadius = 2,
        borderWidth = 3,
        channelColors = {
            feed = '#FF8C2A',
            ooc = '#A8B0BA',
            me = '#B56CFF',
            dispatch = '#4A90E2',
            staff = '#EF4444',
        },
        colorCodes = {
            ['0'] = '#FFFFFF',
            ['1'] = '#FF4444',
            ['2'] = '#7BCF6A',
            ['3'] = '#FFD54A',
            ['4'] = '#4A90E2',
            ['5'] = '#65D6FF',
            ['6'] = '#B56CFF',
            ['7'] = '#FFFFFF',
            ['8'] = '#FF8C2A',
            ['9'] = '#B0B5BD',
        }
    }
}

Config.Giphy = {
    enabled = true,
    rating = 'pg',
    language = 'pt',
    countryCode = 'BR',
    limit = 24,
    searchCooldownMs = 1200
}

Config.Stickers = {
    adminCommand = 'chatstickers',
    acePermission = 'forge-core.admin',
    maxNameLength = 40,
    maxUrlLength = 500
}






