<script>
  import { onMount, tick } from 'svelte';

  const isNui = typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function';
  const resourceName = isNui ? window.GetParentResourceName() : 'forge-chat';

  let messages = [];
  let messagesElement;
  let inputMessage = '';
  let showInput = false;
  let inputElement;
  let activeChannel = 'Feed';
  let mediaOpen = false;
  let settingsOpen = false;
  let activeMediaTab = 'emojis';

  const layoutStorageKey = 'forge_chat_layout_v1';
  let chatLayoutElement;
  let layoutEditMode = false;
  let chatOpacity = 0.95;
  let chatScale = 1;
  let chatPosition = { x: 1.46, y: 2.5 };
  let dragState = null;
  $: chatLayoutStyle = `left: ${chatPosition.x}vw; top: ${chatPosition.y}vh; opacity: ${chatOpacity}; transform: scale(${chatScale});`;

  // Visibility modes: 'auto' | 'always' | 'hidden'
  let visibilityMode = 'auto';
  let isMessagesVisible = true;
  let hideTimer = null;

  let gifs = [];
  let gifQuery = '';
  let gifLoading = false;
  let gifError = '';
  let gifRequestId = 0;

  let stickers = [];
  let stickerLoading = false;

  let adminOpen = false;
  let adminCanEdit = false;
  let adminError = '';
  let editingStickerId = null;
  let stickerForm = { name: '', imageUrl: '' };
  let adminTab = 'stickers';

  const commandHistoryStorageKey = 'forge_chat_command_history_v1';
  let suggestions = [];
  let commandHistory = [];
  let historyIndex = -1;
  let historyDraft = '';

  const vipStyleStorageKey = 'forge_chat_vip_style_v1';
  let vipStatus = { active: false, tier: null };
  let vipStyle = { color: '#F5C542', neon: false, glow: 10, effect: 'none' };
  const vipEffects = [
    { id: 'none', label: 'Sem animação' },
    { id: 'pulse', label: 'Pulsar' },
    { id: 'shimmer', label: 'Brilho deslizante' },
    { id: 'rainbow', label: 'Arco-íris' }
  ];

  const defaultTheme = {
    accentColor: '#FF8C2A',
    messageBackground: '#0A0E14',
    messageOpacity: 0.92,
    messageShadow: true,
    textColor: '#E9EDF2',
    authorColor: '#FFFFFF',
    mutedColor: '#8F98A6',
    fontSize: 13,
    fontWeight: 400,
    borderRadius: 2,
    borderWidth: 3,
    channelColors: {
      feed: '#FF8C2A', ooc: '#A8B0BA', me: '#B56CFF', dispatch: '#4A90E2', staff: '#EF4444'
    },
    colorCodes: {
      '0': '#FFFFFF', '1': '#FF4444', '2': '#7BCF6A', '3': '#FFD54A', '4': '#4A90E2',
      '5': '#65D6FF', '6': '#B56CFF', '7': '#FFFFFF', '8': '#FF8C2A', '9': '#B0B5BD'
    }
  };
  const fivemColorLabels = [
    ['0', 'Branco'], ['1', 'Vermelho'], ['2', 'Verde'], ['3', 'Amarelo'], ['4', 'Azul'],
    ['5', 'Azul claro'], ['6', 'Roxo'], ['7', 'Branco alternativo'], ['8', 'Laranja'], ['9', 'Cinza']
  ];
  const channelColorLabels = [
    ['feed', 'Feed'], ['ooc', 'OOC'], ['me', 'Me'], ['dispatch', 'Dispatch'], ['staff', 'Staff']
  ];
  let chatTheme = normalizeTheme(defaultTheme);
  let themeForm = normalizeTheme(defaultTheme);
  $: filteredSuggestions = (settingsOpen || mediaOpen) ? [] : getCommandSuggestions(inputMessage);
  $: appThemeStyle = buildThemeStyle(chatTheme);

  const channels = ['Feed', 'OOC', 'Me', 'Dispatch', 'Staff'];
  const emojis = [
    '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇','🙂','🙃',
    '😉','😍','🥰','😘','😎','🤔','😐','😴','😭','😡','🤯','🥳',
    '👍','👎','👏','🙌','🙏','💪','👀','❤️','🧡','💛','💚','💙',
    '🔥','✨','⭐','✅','❌','⚠️','🎉','🎮','🚗','🚓','🚑','🏁'
  ];

  function normalizeHex(value, fallback) {
    const color = String(value || '').toUpperCase();
    return /^#[0-9A-F]{6}$/.test(color) ? color : fallback;
  }

  function normalizeTheme(value = {}) {
    const incomingCodes = value?.colorCodes || {};
    const colorCodes = {};
    const incomingChannels = value?.channelColors || {};
    const channelColors = {};
    for (const [key] of channelColorLabels) {
      channelColors[key] = normalizeHex(incomingChannels[key], defaultTheme?.channelColors?.[key] || defaultTheme.accentColor);
    }
    for (let index = 0; index <= 9; index += 1) {
      const key = String(index);
      colorCodes[key] = normalizeHex(incomingCodes[key], defaultTheme?.colorCodes?.[key] || '#FFFFFF');
    }

    const allowedWeights = [400, 500, 600, 700, 800, 900];
    const requestedWeight = Number(value.fontWeight ?? defaultTheme.fontWeight);
    return {
      accentColor: normalizeHex(value.accentColor, defaultTheme.accentColor),
      messageBackground: normalizeHex(value.messageBackground, defaultTheme.messageBackground),
      messageOpacity: clamp(value.messageOpacity ?? defaultTheme.messageOpacity, 0.1, 1),
      messageShadow: value.messageShadow ?? defaultTheme.messageShadow,
      textColor: normalizeHex(value.textColor, defaultTheme.textColor),
      authorColor: normalizeHex(value.authorColor, defaultTheme.authorColor),
      mutedColor: normalizeHex(value.mutedColor, defaultTheme.mutedColor),
      fontSize: Math.round(clamp(value.fontSize ?? defaultTheme.fontSize, 10, 24)),
      fontWeight: allowedWeights.includes(requestedWeight) ? requestedWeight : defaultTheme.fontWeight,
      borderRadius: Math.round(clamp(value.borderRadius ?? defaultTheme.borderRadius, 0, 18)),
      borderWidth: Math.round(clamp(value.borderWidth ?? defaultTheme.borderWidth, 0, 8)),
      channelColors,
      colorCodes
    };
  }

  function hexToRgba(hex, opacity) {
    const value = normalizeHex(hex, '#0A0E14').slice(1);
    const red = parseInt(value.slice(0, 2), 16);
    const green = parseInt(value.slice(2, 4), 16);
    const blue = parseInt(value.slice(4, 6), 16);
    return `rgba(${red}, ${green}, ${blue}, ${clamp(opacity, 0.1, 1)})`;
  }

  function buildThemeStyle(theme) {
    const normalized = normalizeTheme(theme);
    const variables = [
      `--accent: ${normalized.accentColor}`,
      `--chat-message-bg: ${hexToRgba(normalized.messageBackground, normalized.messageOpacity)}`,
      `--chat-message-shadow: ${normalized.messageShadow ? '0 6px 18px rgba(0,0,0,.35)' : 'none'}`,
      `--chat-text: ${normalized.textColor}`,
      `--chat-author: ${normalized.authorColor}`,
      `--chat-muted: ${normalized.mutedColor}`,
      `--chat-font-size: ${normalized.fontSize}px`,
      `--chat-font-weight: ${normalized.fontWeight}`,
      `--chat-border-radius: ${normalized.borderRadius}px`,
      `--chat-border-width: ${normalized.borderWidth}px`
    ];
    for (let index = 0; index <= 9; index += 1) {
      variables.push(`--fivem-color-${index}: ${normalized.colorCodes[String(index)]}`);
    }
    for (const [key] of channelColorLabels) {
      variables.push(`--channel-color-${key}: ${normalized.channelColors[key]}`);
    }
    return variables.join('; ');
  }

  function loadCommandHistory() {
    try {
      const saved = JSON.parse(localStorage.getItem(commandHistoryStorageKey) || '[]');
      commandHistory = Array.isArray(saved)
        ? saved.filter((entry) => typeof entry === 'string' && entry.startsWith('/')).slice(-50)
        : [];
    } catch (e) {
      commandHistory = [];
    }
  }

  function persistCommandHistory() {
    try {
      localStorage.setItem(commandHistoryStorageKey, JSON.stringify(commandHistory.slice(-50)));
    } catch (e) {}
  }

  function rememberCommand(message) {
    if (!message.startsWith('/')) return;
    commandHistory = commandHistory.filter((entry) => entry !== message);
    commandHistory = [...commandHistory, message].slice(-50);
    persistCommandHistory();
  }

  function normalizeVipStyle(value = {}) {
    const effects = vipEffects.map((entry) => entry.id);
    const effect = effects.includes(String(value.effect || 'none')) ? String(value.effect || 'none') : 'none';
    return {
      color: normalizeHex(value.color, '#F5C542'),
      neon: value.neon === true,
      glow: Math.round(clamp(value.glow ?? 10, 0, 24)),
      effect
    };
  }

  function loadVipStyleSettings() {
    try {
      vipStyle = normalizeVipStyle(JSON.parse(localStorage.getItem(vipStyleStorageKey) || '{}'));
    } catch (e) {
      vipStyle = normalizeVipStyle({});
    }
  }

  function saveVipStyleSettings() {
    vipStyle = normalizeVipStyle(vipStyle);
    try { localStorage.setItem(vipStyleStorageKey, JSON.stringify(vipStyle)); } catch (e) {}
    nuiPost('vipStyleSave', vipStyle);
  }

  function vipAuthorStyle(vip) {
    const style = normalizeVipStyle(vip?.style || {});
    return `--vip-name-color:${style.color};--vip-name-glow:${style.glow}px`;
  }
  function navigateCommandHistory(direction) {
    if (commandHistory.length === 0) return false;
    if (historyIndex === -1) historyDraft = inputMessage;

    if (direction < 0) {
      historyIndex = historyIndex === -1 ? commandHistory.length - 1 : Math.max(0, historyIndex - 1);
      inputMessage = commandHistory[historyIndex];
    } else if (historyIndex !== -1) {
      historyIndex += 1;
      if (historyIndex >= commandHistory.length) {
        historyIndex = -1;
        inputMessage = historyDraft;
      } else {
        inputMessage = commandHistory[historyIndex];
      }
    }

    tick().then(() => {
      inputElement?.focus();
      inputElement?.setSelectionRange(inputMessage.length, inputMessage.length);
    });
    return true;
  }

  function addSuggestion(suggestion) {
    const name = String(suggestion?.name || '').trim();
    if (!name) return;
    const normalized = name.startsWith('/') ? name : `/${name}`;
    const next = {
      name: normalized,
      help: String(suggestion?.help || ''),
      params: Array.isArray(suggestion?.params) ? suggestion.params : []
    };
    suggestions = [...suggestions.filter((entry) => entry.name.toLowerCase() !== normalized.toLowerCase()), next]
      .sort((left, right) => left.name.localeCompare(right.name));
  }

  function removeSuggestion(name) {
    const normalized = String(name || '').toLowerCase();
    suggestions = suggestions.filter((entry) => entry.name.toLowerCase() !== normalized);
  }

  function getCommandSuggestions(value) {
    const query = String(value || '').trimStart();
    if (!query.startsWith('/')) return [];
    const command = query.split(/\s+/)[0].toLowerCase();
    return suggestions
      .filter((entry) => entry.name.toLowerCase().startsWith(command));
  }

  function applySuggestion(suggestion) {
    const params = Array.isArray(suggestion?.params) && suggestion.params.length > 0 ? ' ' : '';
    inputMessage = `${suggestion.name}${params}`;
    historyIndex = -1;
    historyDraft = '';
    tick().then(() => {
      inputElement?.focus();
      inputElement?.setSelectionRange(inputMessage.length, inputMessage.length);
    });
  }

  function formatFiveMText(value) {
    const text = String(value ?? '');
    const tokens = [];
    let buffer = '';
    let style = { color: null, bold: false, underline: false, strike: false };

    const flush = () => {
      if (!buffer) return;
      tokens.push({ text: buffer, ...style });
      buffer = '';
    };
    const reset = () => {
      style = { color: null, bold: false, underline: false, strike: false };
    };

    for (let index = 0; index < text.length; index += 1) {
      const char = text[index];
      if (char === '\n') {
        flush();
        tokens.push({ break: true });
        continue;
      }
      if (char !== '^' || index + 1 >= text.length) {
        buffer += char;
        continue;
      }

      const code = text[index + 1];
      if (code === '^') {
        buffer += '^';
        index += 1;
        continue;
      }
      if (/^[0-9]$/.test(code)) {
        flush();
        style = { ...style, color: code };
        index += 1;
        continue;
      }
      if (code === '*') {
        flush();
        style = { ...style, bold: true };
        index += 1;
        continue;
      }
      if (code === '_') {
        flush();
        style = { ...style, underline: true };
        index += 1;
        continue;
      }
      if (code === '=') {
        flush();
        style = { ...style, strike: true };
        index += 1;
        continue;
      }
      if (code === '~' || code.toLowerCase() === 'r') {
        flush();
        reset();
        index += 1;
        continue;
      }
      if (code.toLowerCase() === 'n') {
        flush();
        tokens.push({ break: true });
        index += 1;
        continue;
      }
      buffer += char;
    }

    flush();
    return tokens;
  }

  function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, Number(value)));
  }

  function loadLayoutSettings() {
    try {
      const saved = JSON.parse(localStorage.getItem(layoutStorageKey) || '{}');
      chatOpacity = clamp(saved.opacity ?? 0.95, 0.35, 1);
      chatScale = clamp(saved.scale ?? 1, 0.65, 1.4);
      chatPosition = {
        x: clamp(saved.position?.x ?? 1.46, 0, 95),
        y: clamp(saved.position?.y ?? 2.5, 0, 95)
      };
    } catch (e) {
      resetLayout(false);
    }
  }

  function persistLayoutSettings() {
    try {
      localStorage.setItem(layoutStorageKey, JSON.stringify({
        opacity: chatOpacity,
        scale: chatScale,
        position: chatPosition
      }));
    } catch (e) {}
  }

  function setChatOpacity(value) {
    chatOpacity = clamp(value, 0.35, 1);
    persistLayoutSettings();
  }

  function setChatScale(value) {
    chatScale = clamp(value, 0.65, 1.4);
    tick().then(() => {
      keepLayoutOnScreen();
      persistLayoutSettings();
    });
  }

  function resetLayout(save = true) {
    chatOpacity = 0.95;
    chatScale = 1;
    chatPosition = { x: 1.46, y: 2.5 };
    if (save) persistLayoutSettings();
  }

  function keepLayoutOnScreen() {
    if (!chatLayoutElement) return;
    const rect = chatLayoutElement.getBoundingClientRect();
    const maximumX = Math.max(0, 100 - (rect.width / window.innerWidth * 100));
    const maximumY = Math.max(0, 100 - (rect.height / window.innerHeight * 100));
    chatPosition = {
      x: clamp(chatPosition.x, 0, maximumX),
      y: clamp(chatPosition.y, 0, maximumY)
    };
  }

  function startLayoutEdit() {
    mediaOpen = false;
    settingsOpen = false;
    layoutEditMode = true;
    isMessagesVisible = true;
  }

  function finishLayoutEdit() {
    dragState = null;
    layoutEditMode = false;
    keepLayoutOnScreen();
    persistLayoutSettings();
    tick().then(() => inputElement?.focus());
  }

  function handleLayoutDragKeydown(event) {
    const movement = event.shiftKey ? 5 : 1;
    const deltas = {
      ArrowLeft: [-movement, 0],
      ArrowRight: [movement, 0],
      ArrowUp: [0, -movement],
      ArrowDown: [0, movement]
    };
    const delta = deltas[event.key];
    if (!delta) return;

    event.preventDefault();
    chatPosition = {
      x: chatPosition.x + delta[0],
      y: chatPosition.y + delta[1]
    };
    tick().then(() => {
      keepLayoutOnScreen();
      persistLayoutSettings();
    });
  }

  function startLayoutDrag(event) {
    if (!layoutEditMode || event.button !== 0) return;
    event.preventDefault();
    const rect = chatLayoutElement?.getBoundingClientRect();
    dragState = {
      pointerX: event.clientX,
      pointerY: event.clientY,
      positionX: chatPosition.x,
      positionY: chatPosition.y,
      width: rect?.width || 0,
      height: rect?.height || 0
    };
  }

  function handleLayoutPointerMove(event) {
    if (!dragState) return;
    const maximumX = Math.max(0, 100 - (dragState.width / window.innerWidth * 100));
    const maximumY = Math.max(0, 100 - (dragState.height / window.innerHeight * 100));
    chatPosition = {
      x: clamp(dragState.positionX + ((event.clientX - dragState.pointerX) / window.innerWidth * 100), 0, maximumX),
      y: clamp(dragState.positionY + ((event.clientY - dragState.pointerY) / window.innerHeight * 100), 0, maximumY)
    };
  }

  function stopLayoutDrag() {
    if (!dragState) return;
    dragState = null;
    persistLayoutSettings();
  }

  function loadVisibilitySettings() {
    try {
      const saved = localStorage.getItem('forge_chat_visibility_mode');
      if (saved && ['auto', 'always', 'hidden'].includes(saved)) {
        visibilityMode = saved;
      }
    } catch (e) {}
    updateVisibilityState();
  }

  function setVisibilityMode(mode) {
    visibilityMode = mode;
    try {
      localStorage.setItem('forge_chat_visibility_mode', mode);
    } catch (e) {}
    updateVisibilityState();
  }

  function updateVisibilityState() {
    if (showInput || visibilityMode === 'always') {
      isMessagesVisible = true;
      if (hideTimer) { clearTimeout(hideTimer); hideTimer = null; }
    } else if (visibilityMode === 'hidden') {
      isMessagesVisible = false;
      if (hideTimer) { clearTimeout(hideTimer); hideTimer = null; }
    } else if (visibilityMode === 'auto') {
      if (!showInput) {
        if (hideTimer) clearTimeout(hideTimer);
        hideTimer = setTimeout(() => {
          if (!showInput && visibilityMode === 'auto') {
            isMessagesVisible = false;
          }
        }, 7000);
      }
    }
  }

  async function nuiPost(endpoint, data = {}) {
    if (!isNui) return { ok: true };

    const response = await fetch(`https://${resourceName}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data)
    });

    return response.json().catch(() => ({ ok: response.ok }));
  }

  async function addMessage(message) {
    messages = [...messages, {
      id: `${Date.now()}-${Math.random()}`,
      templateId: message.templateId,
      args: message.args || [],
      media: message.media || null,
      channel: message.channel || '',
      author: message.author || '',
      vip: message.vip || null
    }].slice(-150);

    if (visibilityMode === 'auto') {
      isMessagesVisible = true;
      if (hideTimer) clearTimeout(hideTimer);
      if (!showInput) {
        hideTimer = setTimeout(() => {
          if (!showInput && visibilityMode === 'auto') {
            isMessagesVisible = false;
          }
        }, 7000);
      }
    } else if (visibilityMode === 'always') {
      isMessagesVisible = true;
    }

    await tick();
    requestAnimationFrame(scrollMessagesToBottom);
  }

  function scrollMessagesToBottom() {
    if (!messagesElement) return;
    messagesElement.scrollTop = messagesElement.scrollHeight;
  }

  async function openChat() {
    showInput = true;
    isMessagesVisible = true;
    historyIndex = -1;
    historyDraft = '';
    if (hideTimer) { clearTimeout(hideTimer); hideTimer = null; }
    await tick();
    keepLayoutOnScreen();
    persistLayoutSettings();
    inputElement?.focus();
  }

  function closeChat() {
    showInput = false;
    mediaOpen = false;
    settingsOpen = false;
    inputMessage = '';
    historyIndex = -1;
    historyDraft = '';
    updateVisibilityState();
    nuiPost('chatResult', { canceled: true });
  }

  function sendText() {
    const message = inputMessage.trim();
    if (!message) return closeChat();
    rememberCommand(message);

    nuiPost('chatResult', {
      canceled: false,
      message,
      channel: activeChannel.toLowerCase(),
      media: null
    });

    showInput = false;
    mediaOpen = false;
    settingsOpen = false;
    inputMessage = '';
    updateVisibilityState();
  }

  function sendMedia(type, payload) {
    nuiPost('chatResult', {
      canceled: false,
      message: '',
      channel: activeChannel.toLowerCase(),
      media: { type, ...payload }
    });

    showInput = false;
    mediaOpen = false;
    settingsOpen = false;
    inputMessage = '';
    updateVisibilityState();
  }

  function handleInputKeydown(event) {
    if (event.key === 'Escape' && layoutEditMode) {
      event.preventDefault();
      event.stopPropagation();
      finishLayoutEdit();
      return;
    }

    if (event.key === 'Escape') {
      event.preventDefault();
      closeChat();
      return;
    }

    if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
      if (navigateCommandHistory(event.key === 'ArrowUp' ? -1 : 1)) {
        event.preventDefault();
        return;
      }
    }

    if (event.key === 'Tab') {
      event.preventDefault();
      if (inputMessage.trimStart().startsWith('/') && filteredSuggestions.length > 0) {
        applySuggestion(filteredSuggestions[0]);
      } else {
        const index = channels.indexOf(activeChannel);
        activeChannel = channels[(index + 1) % channels.length];
      }
      return;
    }

    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendText();
    }
  }

  function handleInputChange() {
    historyIndex = -1;
    historyDraft = inputMessage;
  }

  function insertEmoji(emoji) {
    const input = inputElement;
    if (!input) {
      inputMessage += emoji;
      return;
    }

    const start = input.selectionStart ?? inputMessage.length;
    const end = input.selectionEnd ?? inputMessage.length;
    inputMessage = `${inputMessage.slice(0, start)}${emoji}${inputMessage.slice(end)}`;

    tick().then(() => {
      input.focus();
      input.setSelectionRange(start + emoji.length, start + emoji.length);
    });
  }

  function openMedia() {
    settingsOpen = false;
    mediaOpen = !mediaOpen;
    if (mediaOpen && activeMediaTab === 'gifs' && gifs.length === 0) searchGifs('');
    if (mediaOpen && activeMediaTab === 'stickers') requestStickers();
  }

  function toggleSettings() {
    mediaOpen = false;
    settingsOpen = !settingsOpen;
  }

  function selectMediaTab(tab) {
    activeMediaTab = tab;
    if (tab === 'gifs' && gifs.length === 0) searchGifs('');
    if (tab === 'stickers') requestStickers();
  }

  async function searchGifs(query = gifQuery) {
    gifLoading = true;
    gifError = '';
    gifRequestId += 1;
    await nuiPost('giphySearch', { query: query.trim(), requestId: gifRequestId });

    if (!isNui) {
      gifLoading = false;
      gifs = [];
      gifError = 'A pesquisa GIPHY funciona dentro do FiveM.';
    }
  }

  async function requestStickers() {
    stickerLoading = true;
    await nuiPost('stickersRequest');
    if (!isNui) stickerLoading = false;
  }

  function resetStickerForm() {
    editingStickerId = null;
    stickerForm = { name: '', imageUrl: '' };
    adminError = '';
  }

  function editSticker(sticker) {
    editingStickerId = sticker.id;
    stickerForm = { name: sticker.name, imageUrl: sticker.imageUrl };
  }

  async function saveSticker() {
    adminError = '';
    const name = stickerForm.name.trim();
    const imageUrl = stickerForm.imageUrl.trim();

    if (!name || !imageUrl) {
      adminError = 'Informe o nome e a URL da imagem.';
      return;
    }

    await nuiPost('adminStickerSave', {
      id: editingStickerId,
      name,
      imageUrl
    });
  }

  async function deleteSticker(sticker) {
    await nuiPost('adminStickerDelete', { id: sticker.id });
  }

  async function saveTheme() {
    adminError = '';
    themeForm = normalizeTheme(themeForm);
    await nuiPost('adminSettingsSave', themeForm);
  }

  function resetThemeForm() {
    themeForm = normalizeTheme(defaultTheme);
  }

  function closeAdmin() {
    adminOpen = false;
    adminTab = 'stickers';
    resetStickerForm();
    nuiPost('adminClose');
  }

  function channelLabel(channel) {
    const labels = {
      feed: '',
      ooc: 'OOC',
      me: 'ME',
      dispatch: 'DISPATCH',
      staff: 'STAFF'
    };
    return labels[String(channel || '').toLowerCase()] ?? '';
  }

  function renderTextMessage(msg) {
    const explicitAuthor = String(msg.author || '').trim();
    let rendered;

    if (msg.templateId === 'system') {
      rendered = { label: 'SYSTEM', author: '', text: msg.args[0] || '' };
    } else if (msg.templateId === 'ooc') {
      rendered = {
        label: 'OOC',
        author: explicitAuthor || `${msg.args[0] || ''}${msg.args[1] ? ` (${msg.args[1]})` : ''}`,
        text: msg.args[2] || ''
      };
    } else if (msg.templateId === 'cnormal') {
      rendered = {
        label: channelLabel(msg.channel),
        author: explicitAuthor || msg.args[0] || '',
        text: msg.args[1] || ''
      };
    } else {
      rendered = { label: channelLabel(msg.channel), author: '', text: msg.args.join(' ') };
    }

    const requestedChannel = String(msg.channel || rendered.label || 'feed').toLowerCase();
    const channelKey = channelColorLabels.some(([key]) => key === requestedChannel) ? requestedChannel : 'feed';
    return {
      ...rendered,
      channelKey,
      authorTokens: formatFiveMText(rendered.author),
      textTokens: formatFiveMText(rendered.text)
    };
  }

  onMount(() => {
    loadVisibilitySettings();
    loadLayoutSettings();
    loadCommandHistory();
    loadVipStyleSettings();
    tick().then(keepLayoutOnScreen);

    const handleWindowKeydown = (event) => {
      if (layoutEditMode && event.key === 'Escape') {
        event.preventDefault();
        finishLayoutEdit();
      }
    };

    const handler = (event) => {
      const data = event.data || {};

      switch (data.type) {
        case 'ON_OPEN':
          openChat();
          break;
        case 'ON_MESSAGE':
          addMessage(data.message || {});
          break;
        case 'ON_CLEAR':
          messages = [];
          break;
        case 'ON_SUGGESTION_ADD':
          addSuggestion(data.suggestion || {});
          break;
        case 'ON_SUGGESTION_REMOVE':
          removeSuggestion(data.name);
          break;
        case 'CHAT_SETTINGS_UPDATE':
          chatTheme = normalizeTheme(data.settings || {});
          break;
        case 'VIP_STATUS_UPDATE':
          vipStatus = data.status || { active: false, tier: null };
          if (vipStatus.active && vipStatus.style) {
            vipStyle = normalizeVipStyle(vipStatus.style);
            try { localStorage.setItem(vipStyleStorageKey, JSON.stringify(vipStyle)); } catch (e) {}
          }
          break;
        case 'GIPHY_RESULTS':
          if (data.requestId === gifRequestId) {
            gifs = data.items || [];
            gifError = data.error || '';
            gifLoading = false;
          }
          break;
        case 'STICKERS_UPDATE':
          stickers = data.stickers || [];
          stickerLoading = false;
          break;
        case 'STICKER_ADMIN_OPEN':
          adminOpen = true;
          adminTab = 'stickers';
          adminCanEdit = data.canEdit === true;
          stickers = data.stickers || [];
          if (data.settings) {
            chatTheme = normalizeTheme(data.settings);
            themeForm = normalizeTheme(data.settings);
          }
          break;
        case 'STICKER_ADMIN_RESULT':
          adminError = data.ok ? '' : (data.error || 'Não foi possível salvar as alterações.');
          if (data.ok) {
            stickers = data.stickers || stickers;
            if (data.settings) {
              chatTheme = normalizeTheme(data.settings);
              themeForm = normalizeTheme(data.settings);
            }
            resetStickerForm();
          }
          break;
      }
    };

    window.addEventListener('message', handler);
    window.addEventListener('keydown', handleWindowKeydown);
    window.addEventListener('pointermove', handleLayoutPointerMove);
    window.addEventListener('pointerup', stopLayoutDrag);
    window.addEventListener('resize', keepLayoutOnScreen);
    nuiPost('loaded', { vipStyle });

    return () => {
      window.removeEventListener('message', handler);
      window.removeEventListener('keydown', handleWindowKeydown);
      window.removeEventListener('pointermove', handleLayoutPointerMove);
      window.removeEventListener('pointerup', stopLayoutDrag);
      window.removeEventListener('resize', keepLayoutOnScreen);
    };
  });
</script>

<div class="app" style={appThemeStyle}>
  <div class:layout-editing={layoutEditMode} class="chat-layout" bind:this={chatLayoutElement} style={chatLayoutStyle}>
    {#if layoutEditMode}
      <div class="drag-handle" role="toolbar" tabindex="0" aria-label="Reposicionar chat" on:keydown={handleLayoutDragKeydown} on:pointerdown={startLayoutDrag}>
        <span>Arraste para posicionar o chat</span>
        <button type="button" on:pointerdown|stopPropagation on:click|stopPropagation={finishLayoutEdit}>Concluir</button>
      </div>
    {/if}

  <section class:interactive={showInput} class:visible={isMessagesVisible || showInput} class="chat-window" aria-live="polite">
    <div class="messages" bind:this={messagesElement}>
      {#each messages as msg (msg.id)}
        {@const rendered = renderTextMessage(msg)}
        <article class="message">
          <div class="message-line">
            {#if rendered.label}<span class="message-label" style={`--label-color:var(--channel-color-${rendered.channelKey})`}>{rendered.label}</span>{/if}
            {#if rendered.author}
              <strong
                class="formatted-author"
                class:vip-name={msg.vip?.active}
                class:vip-neon={msg.vip?.active && msg.vip?.style?.neon}
                class:vip-pulse={msg.vip?.active && msg.vip?.style?.effect === 'pulse'}
                class:vip-shimmer={msg.vip?.active && msg.vip?.style?.effect === 'shimmer'}
                class:vip-rainbow={msg.vip?.active && msg.vip?.style?.effect === 'rainbow'}
                style={msg.vip?.active ? vipAuthorStyle(msg.vip) : undefined}
              >
                {#each rendered.authorTokens as token}
                  {#if token.break}
                    <br />
                  {:else}
                    <span
                      class="formatted-token"
                      class:bold={token.bold}
                      class:underline={token.underline}
                      class:strike={token.strike}
                      style:color={token.color ? `var(--fivem-color-${token.color})` : null}
                    >{token.text}</span>
                  {/if}
                {/each}
              </strong>
            {/if}
            {#if rendered.text}
              <span class="formatted-text">
                {#each rendered.textTokens as token}
                  {#if token.break}
                    <br />
                  {:else}
                    <span
                      class="formatted-token"
                      class:bold={token.bold}
                      class:underline={token.underline}
                      class:strike={token.strike}
                      style:color={token.color ? `var(--fivem-color-${token.color})` : null}
                    >{token.text}</span>
                  {/if}
                {/each}
              </span>
            {/if}
          </div>

          {#if msg.media?.type === 'gif'}
            <img class="chat-media gif" src={msg.media.url} alt={msg.media.title || 'GIF'} on:load={scrollMessagesToBottom} />
          {:else if msg.media?.type === 'sticker'}
            <img class="chat-media sticker" src={msg.media.imageUrl} alt={msg.media.name || 'Sticker'} on:load={scrollMessagesToBottom} />
          {/if}
        </article>
      {/each}
    </div>
  </section>

  {#if showInput}
    <section class="composer-shell">
      {#if filteredSuggestions.length > 0}
        <div class="command-suggestions">
          <header><strong>Comandos disponíveis</strong><small>TAB completa · ↑↓ histórico</small></header>
          {#each filteredSuggestions as suggestion (suggestion.name)}
            <button type="button" on:click={() => applySuggestion(suggestion)}>
              <span><strong>{suggestion.name}</strong>{#if suggestion.params.length}<em>{suggestion.params.map((param) => `<${param.name || 'valor'}>`).join(' ')}</em>{/if}</span>
              {#if suggestion.help}<small><b>Help:</b> {suggestion.help}</small>{/if}
            </button>
          {/each}
        </div>
      {/if}

      <div class="hint">Pressione <b>[TAB]</b> para trocar de canal · <b>[↑][↓]</b> histórico de comandos</div>

      <div class="composer">
        <span class="active-channel" style={`--channel-accent:var(--channel-color-${activeChannel.toLowerCase()})`}>{activeChannel}</span>
        <textarea
          bind:this={inputElement}
          bind:value={inputMessage}
          maxlength="280"
          rows="1"
          placeholder="Digite sua mensagem..."
          on:input={handleInputChange}
          on:keydown={handleInputKeydown}
        ></textarea>
        <button class:active={mediaOpen} class="media-trigger" type="button" on:click={openMedia} aria-label="Abrir emojis, GIFs e stickers">☺</button>
        <button class:active={settingsOpen} class="settings-trigger" type="button" on:click={toggleSettings} aria-label="Configurações de exibição do chat">⚙</button>
      </div>

      <nav class="channels">
        {#each channels as channel}
          <button class:active={channel === activeChannel} style={`--channel-accent:var(--channel-color-${channel.toLowerCase()})`} on:click={() => activeChannel = channel}>{channel}</button>
        {/each}
      </nav>

      {#if settingsOpen}
        <div class="settings-panel">
          <header class="settings-header">
            <span class="settings-title">⚙ Configurações de Exibição</span>
            <button class="settings-close" on:click={() => settingsOpen = false}>×</button>
          </header>
          <div class="settings-content">
            <button 
              class="setting-card" 
              class:selected={visibilityMode === 'auto'} 
              on:click={() => setVisibilityMode('auto')}
            >
              <div class="setting-radio"><div class="radio-dot"></div></div>
              <div class="setting-text">
                <strong>Automático / Dinâmico (Recomendado)</strong>
                <small>Aparece quando há mensagens novas e oculta após 7 segundos.</small>
              </div>
            </button>

            <button 
              class="setting-card" 
              class:selected={visibilityMode === 'always'} 
              on:click={() => setVisibilityMode('always')}
            >
              <div class="setting-radio"><div class="radio-dot"></div></div>
              <div class="setting-text">
                <strong>Sempre Visível</strong>
                <small>O chat e as mensagens ficam sempre fixos na tela.</small>
              </div>
            </button>

            <button 
              class="setting-card" 
              class:selected={visibilityMode === 'hidden'} 
              on:click={() => setVisibilityMode('hidden')}
            >
              <div class="setting-radio"><div class="radio-dot"></div></div>
              <div class="setting-text">
                <strong>Oculto</strong>
                <small>Mensagens ficam ocultas enquanto joga; aparecem só ao abrir com [T].</small>
              </div>
            </button>

            <div class="settings-divider"></div>

            <section class="vip-settings" class:locked={!vipStatus.active}>
              <div class="vip-settings-title">
                <div>
                  <strong>Nome VIP</strong>
                  <small>{vipStatus.active ? `Plano ${vipStatus.tier || 'VIP'} ativo` : 'Disponível apenas para jogadores VIP'}</small>
                </div>
                <span class="vip-badge">VIP</span>
              </div>
              {#if vipStatus.active}
                <div class="vip-controls">
                  <label>Cor do nome <span class="color-field"><input type="color" bind:value={vipStyle.color} /><input bind:value={vipStyle.color} maxlength="7" /></span></label>
                  <label class="vip-check"><input type="checkbox" bind:checked={vipStyle.neon} /> Ativar brilho neon</label>
                  <label class="range-setting"><span><strong>Intensidade do brilho</strong><b>{vipStyle.glow}px</b></span><input type="range" min="0" max="24" step="1" bind:value={vipStyle.glow} /></label>
                  <label>Efeito do nome <select bind:value={vipStyle.effect}>{#each vipEffects as effect}<option value={effect.id}>{effect.label}</option>{/each}</select></label>
                  <div class="vip-preview"><span class="vip-name" class:vip-neon={vipStyle.neon} class:vip-pulse={vipStyle.effect === 'pulse'} class:vip-shimmer={vipStyle.effect === 'shimmer'} class:vip-rainbow={vipStyle.effect === 'rainbow'} style={vipAuthorStyle({ style: vipStyle })}>Seu nome VIP</span></div>
                  <button class="layout-action primary-layout" type="button" on:click={saveVipStyleSettings}><strong>Salvar visual VIP</strong></button>
                </div>
              {/if}
            </section>

            <div class="settings-divider"></div>

            <label class="range-setting">
              <span><strong>Opacidade do chat</strong><b>{Math.round(chatOpacity * 100)}%</b></span>
              <small>Controla a transparência de toda a interface do chat.</small>
              <input type="range" min="0.35" max="1" step="0.05" value={chatOpacity} on:input={(event) => setChatOpacity(event.currentTarget.value)} />
            </label>

            <label class="range-setting">
              <span><strong>Tamanho do chat</strong><b>{Math.round(chatScale * 100)}%</b></span>
              <small>Aumenta ou diminui proporcionalmente todo o chat.</small>
              <input type="range" min="0.65" max="1.4" step="0.05" value={chatScale} on:input={(event) => setChatScale(event.currentTarget.value)} />
            </label>

            <div class="layout-actions">
              <button class="layout-action primary-layout" type="button" on:click={startLayoutEdit}>
                <strong>Mover chat</strong>
                <small>Arraste a interface inteira para o local desejado.</small>
              </button>
              <button class="layout-action" type="button" on:click={() => resetLayout(true)}>
                <strong>Restaurar visual</strong>
                <small>Volta opacidade, tamanho e posição ao padrão.</small>
              </button>
            </div>
          </div>
        </div>
      {/if}

      {#if mediaOpen}
        <div class="media-panel">
          <div class="media-tabs">
            <button class:active={activeMediaTab === 'emojis'} on:click={() => selectMediaTab('emojis')}>Emojis</button>
            <button class:active={activeMediaTab === 'gifs'} on:click={() => selectMediaTab('gifs')}>GIFs</button>
            <button class:active={activeMediaTab === 'stickers'} on:click={() => selectMediaTab('stickers')}>Stickers</button>
          </div>

          {#if activeMediaTab === 'emojis'}
            <div class="emoji-grid">
              {#each emojis as emoji}
                <button on:click={() => insertEmoji(emoji)}>{emoji}</button>
              {/each}
            </div>
          {:else if activeMediaTab === 'gifs'}
            <form class="gif-search" on:submit|preventDefault={() => searchGifs()}>
              <input bind:value={gifQuery} maxlength="50" placeholder="Pesquisar no GIPHY..." />
              <button type="submit">Buscar</button>
            </form>

            <div class="media-grid">
              {#if gifLoading}<p class="status">Buscando GIFs...</p>{/if}
              {#if gifError}<p class="status error">{gifError}</p>{/if}
              {#each gifs as gif}
                <button class="gif-card" title={gif.title} on:click={() => sendMedia('gif', gif)}>
                  <img src={gif.previewUrl || gif.url} alt={gif.title || 'GIF'} loading="lazy" />
                </button>
              {/each}
            </div>
            <small class="giphy-attribution">Powered by GIPHY</small>
          {:else}
            <div class="media-grid stickers-grid">
              {#if stickerLoading}<p class="status">Carregando stickers...</p>{/if}
              {#if !stickerLoading && stickers.length === 0}<p class="status">Nenhum sticker cadastrado pela cidade.</p>{/if}
              {#each stickers as sticker}
                <button class="sticker-card" title={sticker.name} on:click={() => sendMedia('sticker', sticker)}>
                  <img src={sticker.imageUrl} alt={sticker.name} loading="lazy" />
                  <span>{sticker.name}</span>
                </button>
              {/each}
            </div>
          {/if}
        </div>
      {/if}
    </section>
  {/if}
  </div>

  {#if adminOpen}
    <div class="admin-backdrop">
      <section class="admin-panel">
        <header>
          <div>
            <span class="eyebrow">FORGE CHAT</span>
            <h2>Administração do Chat</h2>
          </div>
          <button class="close-button" on:click={closeAdmin}>×</button>
        </header>

        <nav class="admin-tabs">
          <button class:active={adminTab === 'stickers'} on:click={() => adminTab = 'stickers'}>Stickers</button>
          <button class:active={adminTab === 'theme'} on:click={() => adminTab = 'theme'}>Visual global</button>
        </nav>

        {#if adminError}<p class="admin-error admin-global-error">{adminError}</p>{/if}

        {#if adminCanEdit}
          {#if adminTab === 'stickers'}
            <div class="admin-form">
              <label>
                Nome
                <input bind:value={stickerForm.name} maxlength="40" placeholder="Ex.: Polícia" />
              </label>
              <label>
                URL da imagem
                <input bind:value={stickerForm.imageUrl} maxlength="500" placeholder="https://.../sticker.webp" />
              </label>
              {#if stickerForm.imageUrl}
                <div class="preview"><img src={stickerForm.imageUrl} alt="Prévia" /></div>
              {/if}
              <div class="form-actions">
                {#if editingStickerId}<button class="secondary" on:click={resetStickerForm}>Cancelar edição</button>{/if}
                <button class="primary" on:click={saveSticker}>{editingStickerId ? 'Atualizar sticker' : 'Adicionar sticker'}</button>
              </div>
            </div>

            <div class="admin-list">
              {#each stickers as sticker}
                <article>
                  <img src={sticker.imageUrl} alt={sticker.name} />
                  <div><strong>{sticker.name}</strong><small>{sticker.imageUrl}</small></div>
                  <button on:click={() => editSticker(sticker)}>Editar</button>
                  <button class="danger" on:click={() => deleteSticker(sticker)}>Excluir</button>
                </article>
              {/each}
              {#if stickers.length === 0}<p class="empty">Nenhum sticker cadastrado.</p>{/if}
            </div>
          {:else}
            <div class="theme-editor">
              <div class="theme-help">
                <strong>Visual padrão global</strong>
                <small>Estas opções são aplicadas para todos os jogadores. Opacidade, escala e posição individuais continuam sendo respeitadas.</small>
              </div>

              <div class="theme-grid">
                <label>Cor de destaque <span class="color-field"><input type="color" bind:value={themeForm.accentColor} /><input bind:value={themeForm.accentColor} maxlength="7" /></span></label>
                <label>Fundo das mensagens <span class="color-field"><input type="color" bind:value={themeForm.messageBackground} /><input bind:value={themeForm.messageBackground} maxlength="7" /></span></label>
                <label>Cor do texto <span class="color-field"><input type="color" bind:value={themeForm.textColor} /><input bind:value={themeForm.textColor} maxlength="7" /></span></label>
                <label>Cor dos autores <span class="color-field"><input type="color" bind:value={themeForm.authorColor} /><input bind:value={themeForm.authorColor} maxlength="7" /></span></label>
                <label>Cor auxiliar <span class="color-field"><input type="color" bind:value={themeForm.mutedColor} /><input bind:value={themeForm.mutedColor} maxlength="7" /></span></label>
                <label>Opacidade do fundo <input type="number" min="0.1" max="1" step="0.05" bind:value={themeForm.messageOpacity} /></label>
                <label class="theme-check"><input type="checkbox" bind:checked={themeForm.messageShadow} /> Ativar sombra das mensagens</label>
                <label>Tamanho da fonte (px) <input type="number" min="10" max="24" step="1" bind:value={themeForm.fontSize} /></label>
                <label>Peso da fonte
                  <select bind:value={themeForm.fontWeight}>
                    <option value={400}>Normal</option><option value={500}>Médio</option><option value={600}>Seminegrito</option>
                    <option value={700}>Negrito</option><option value={800}>Extra negrito</option><option value={900}>Máximo</option>
                  </select>
                </label>
                <label>Arredondamento (px) <input type="number" min="0" max="18" step="1" bind:value={themeForm.borderRadius} /></label>
                <label>Largura da borda (px) <input type="number" min="0" max="8" step="1" bind:value={themeForm.borderWidth} /></label>
              </div>

              <h3>Cores das tags e canais</h3>
              <div class="code-color-grid">
                {#each channelColorLabels as channelColor}
                  <label>{channelColor[1]} <span class="color-field"><input type="color" bind:value={themeForm.channelColors[channelColor[0]]} /><input bind:value={themeForm.channelColors[channelColor[0]]} maxlength="7" /></span></label>
                {/each}
              </div>

              <h3>Códigos de cores FiveM</h3>
              <div class="code-color-grid">
                {#each fivemColorLabels as color}
                  <label><strong>^{color[0]}</strong> {color[1]} <span class="color-field"><input type="color" bind:value={themeForm.colorCodes[color[0]]} /><input bind:value={themeForm.colorCodes[color[0]]} maxlength="7" /></span></label>
                {/each}
              </div>

              <div class="theme-preview" style={buildThemeStyle(themeForm)}>
                <article class="message">
                  <div class="message-line"><span class="message-label" style="--label-color:var(--channel-color-dispatch)">DISPATCH</span><strong class="formatted-author">Forge Core</strong><span class="formatted-text"><span style="color: var(--fivem-color-3)">Texto ^3 amarelo</span> · <b>negrito</b> · <u>sublinhado</u></span></div>
                </article>
              </div>

              <div class="form-actions theme-actions">
                <button class="secondary" on:click={resetThemeForm}>Restaurar padrões</button>
                <button class="primary" on:click={saveTheme}>Salvar visual global</button>
              </div>
            </div>
          {/if}
        {:else}
          <p class="admin-error admin-denied">Você não possui permissão para administrar o chat.</p>
        {/if}
      </section>
    </div>
  {/if}
</div>






