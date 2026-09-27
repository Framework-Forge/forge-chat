# Forge Chat — Svelte + GIPHY + Stickers

## Recursos

- Visual inspirado no layout enviado, com destaque `#FF8C2A`.
- Emojis Unicode nativos do sistema operacional.
- Pesquisa de GIFs pela API da GIPHY, feita pelo servidor para não expor a chave na NUI.
- Stickers administrados no jogo e salvos em `data/stickers.json`.
- Painel de administração aberto pelo comando `/chatstickers` ou pelo menu de configurações do servidor da Forge Core.
- Histórico local dos comandos recentes, navegável com as setas para cima e para baixo.
- Sugestões automáticas de comandos ao digitar `/`, com preenchimento pela tecla Tab.
- Códigos FiveM (`^0` a `^9`) e formatações (`^*`, `^_`, `^=`, `^~`, `^r`, `^n`) renderizados visualmente no chat.
- Tema global administrável: cores, opacidade das mensagens, sombra ativável, tipografia, bordas, paleta dos códigos FiveM e cores individuais das tags Feed/OOC/Me/Dispatch/Staff.
- Nomes VIP baseados em `metadata.vip`, com cor, neon, intensidade de brilho e efeitos pulsar, brilho deslizante ou arco-íris configuráveis pelo jogador.
- `/me texto` publica no canal Me e exibe o mesmo texto em um balão do `pr_bridge` sobre o personagem, visível aos demais jogadores dentro do alcance configurado.
- Preferências visuais individuais: opacidade, escala e posição do chat.
- Reposicionamento por arraste do mouse ou pelas setas do teclado (Shift acelera o movimento).
- Preferências salvas localmente para cada jogador e restauradas ao reconectar.

## Instalação

```bash
npm install
npm run build
```

Depois, coloque a pasta em `resources` e adicione ao `server.cfg`:

```cfg
ensure forge-chat
```

## Permissão do painel

Exemplo usando ACE:

```cfg
add_ace group.admin forge-core.admin allow
```

O comando pode ser alterado em `config.lua`:

```lua
Config.Stickers.adminCommand = 'chatstickers'
```

## GIPHY

A chave fica em `config_server.lua`, carregado apenas como server script. Como a chave usada neste projeto foi compartilhada em uma conversa, gere uma nova chave antes de publicar o resource.

As chaves beta da GIPHY possuem limites de uso; configure também `rating`, idioma, país e quantidade de resultados em `config.lua`.

## Stickers

O painel aceita URLs HTTPS de imagens. Para melhor desempenho no NUI, use PNG, WebP ou GIF otimizados e arquivos pequenos.

## Balão do /me

O comportamento pode ser ajustado em `Config.Chat.meBubble`:

- `enabled`: ativa ou desativa apenas o balão, sem impedir a mensagem no chat;
- `duration`: duração em milissegundos;
- `maxDistance`: alcance visual em metros;
- `title`, `type` e `icon`: apresentação enviada ao `NotifyBubbleAll`;
- `wallDetection`: quando definido como `false`, permite visualizar através de obstáculos.

A mensagem continua sendo distribuída pelo forge-chat. O balão usa diretamente o sistema global do `pr_bridge`, fica ancorado no ped do emissor e respeita a detecção de parede e o alcance.

## Cores das tags

No painel `/chatstickers`, abra **Visual global**. A seção **Cores das tags e canais** permite ao administrador definir separadamente as cores de Feed, OOC, Me, Dispatch e Staff. A mesma cor identifica a tag da mensagem, a aba selecionada e o indicador do canal ativo.

## Visual VIP

Quando `metadata.vip` contém um plano ativo e não expirado, o jogador encontra **Nome VIP** nas configurações pessoais do chat. A configuração é validada pelo servidor e permite escolher cor, neon, intensidade de brilho e efeito. Jogadores sem VIP ativo não conseguem aplicar o estilo por chamada direta à NUI.


## Sugestões protegidas por permissão

Comandos registrados pelo `pr_lib.addCommand` são enviados individualmente. `canAccess` protege execução e visibilidade; `suggestionAccess` pode restringir somente o autocomplete, mantendo a validação final no próprio comando.

