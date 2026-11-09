import std/[asyncdispatch, base64, json, math, strformat, strutils, times, uri]
import ws
import types, client, stealth

type
  BotInstance* = ref object
    config*: AccountConfig
    client*: PokeIdleWorldClient
    ws*: WebSocket
    isConnected*: bool
    level*: int
    hp*: int
    maxHp*: int
    mana*: int
    maxMana*: int
    gold*: int64
    kills*: int64
    expPerHour*: float
    status*: string
    currentArea*: string
    startTime*: float
    currentExp*: int64
    isHunting*: bool
    balls*: int
    captures*: int
    guild*: string
    guildTag*: string
    guildBonus*: string
    matchup*: string
    pokedexKills*: string
    slug*: string
    logs*: seq[string]
    running*: bool

proc newBotInstance*(config: AccountConfig): BotInstance =
  new(result)
  result.config = config
  result.client = newPokeIdleWorldClient(config.credentials.token, config.credentials.refreshToken)
  result.level = 0
  result.hp = 0
  result.maxHp = 0
  result.mana = 0
  result.maxMana = 0
  result.gold = 0
  result.kills = 0
  result.expPerHour = 0.0
  result.status = "Desconectado"
  result.currentArea = "Auto (Fraqueza Inteligente)"
  result.startTime = epochTime()
  result.currentExp = 0
  result.isHunting = false
  result.balls = 0
  result.captures = 0
  result.guild = "Sem Guilda (Buscando...)"
  result.guildTag = ""
  result.guildBonus = "+0.0% XP"
  result.matchup = "Avaliando..."
  result.pokedexKills = "Carregando..."
  result.slug = "auto"
  result.logs = @[]
  result.running = false
  result.isConnected = false

proc addLog*(self: BotInstance, msg: string) =
  let now = now().format("HH:mm:ss")
  let formatted = fmt"[{now}] {msg}"
  echo formatted
  if self.logs.len >= 25:
    self.logs.delete(0)
  self.logs.add(formatted)

proc computeWebsocketUrl(token: string): string =
  let baseUrl = "wss://poke.idleworld.online/ws"
  if token.len == 0:
    return baseUrl & "?v=2"

  let parts = token.split('.')
  if parts.len < 2:
    return baseUrl & "?token=" & encodeUrl(token) & "&v=2"

  var sub = ""
  try:
    var b64 = parts[1].replace('-', '+').replace('_', '/')
    while b64.len mod 4 != 0:
      b64.add('=')
    let decoded = decode(b64)
    let parsed = parseJson(decoded)
    sub = parsed{"sub"}.getStr("")
  except CatchableError:
    sub = ""

  if sub.len == 0:
    return baseUrl & "?token=" & encodeUrl(token) & "&v=2"

  var hash: uint32 = 5381'u32
  for c in sub:
    hash = (hash shl 5) + hash + uint32(ord(c))

  let shardIdx = int(hash mod 88'u32)

  let targetUrl = if shardIdx > 0:
                    fmt"wss://poke.idleworld.online/ws{shardIdx}"
                  else:
                    baseUrl

  result = fmt"{targetUrl}?token={encodeUrl(token)}&v=2"

proc sendWs*(self: BotInstance, msg: string): Future[bool] {.async.} =
  if self.ws == nil or not self.isConnected: return false
  try:
    await self.ws.send(msg)
    result = true
  except CatchableError:
    self.isConnected = false
    result = false

proc handleWsMessage*(self: BotInstance, text: string) =
  try:
    let node = parseJson(text)
    let msgType = node{"type"}.getStr("")
    case msgType
    of "field-init":
      let slug = node{"slug"}.getStr("taillow")
      self.isHunting = true
      self.status = "HUNTING"
      self.currentArea = slug
      self.slug = slug
    of "field-loot":
      self.gold += node{"gold"}.getBiggestInt(0)
      self.currentExp += node{"exp"}.getBiggestInt(0)
      self.status = "HUNTING"
    of "field-catch":
      inc self.captures
      self.addLog("🎯 Pokémon capturado no Poke Idle World!")
    of "field-kill":
      inc self.kills
    of "char-stats", "char-update":
      let lvl = node{"level"}.getInt(0)
      let hp = node{"hp"}.getInt(0)
      let maxHp = node{"maxHp"}.getInt(0)
      if lvl > 0: self.level = lvl
      if hp > 0: self.hp = hp
      if maxHp > 0: self.maxHp = maxHp
    of "balls-get":
      self.balls = node{"total"}.getInt(0)
    else:
      discard
  except CatchableError:
    discard

proc readerLoop*(self: BotInstance) {.async.} =
  while self.running and self.isConnected:
    try:
      let msg = await self.ws.receiveStrPacket()
      if msg.len > 0:
        self.handleWsMessage(msg)
      else:
        break
    except CatchableError as e:
      self.addLog("Conexão WebSocket interrompida: " & e.msg)
      if e.msg.contains("4001") or e.msg.contains("unauthorized"):
        self.addLog("Token inválido/expirado detectado (4001). Tentando renovar via refreshToken...")
        try:
          discard await self.client.refreshAccessToken()
        except CatchableError: discard
      break
  self.isConnected = false
  self.isHunting = false
  self.status = "Desconectado"

proc pingLoop*(self: BotInstance) {.async.} =
  while self.running:
    await sleepAsync(25000)
    if self.isConnected:
      discard await self.sendWs("{\"type\":\"ping\"}")

proc watchdogLoop*(self: BotInstance) {.async.} =
  while self.running:
    let jitterDelay = applyJitter(4000, 0.20)
    await sleepAsync(jitterDelay)
    if self.isConnected:
      if not self.isHunting and self.status != "Desconectado":
        discard await self.sendWs("{\"type\":\"enter-hunt\",\"slug\":\"taillow\"}")
      discard await self.sendWs("{\"type\":\"analyzer-get\"}")

proc dailyLoop*(self: BotInstance) {.async.} =
  while self.running:
    let dailyDelay = applyJitter(1800000, 0.15) # ~30 minutos com jitter
    await sleepAsync(dailyDelay)
    try:
      discard await self.client.claimDaily()
    except CatchableError: discard

proc run*(self: BotInstance) {.async.} =
  self.running = true
  self.addLog("Verificando credenciais e token do Poke Idle World...")

  # Checagem inicial de token HTTP
  if self.client.token.len > 0:
    try:
      let charNode = await self.client.getCharacterMe()
      let ch = charNode{"character"}
      if ch != nil:
        self.level = ch{"level"}.getInt(0)
        self.status = "Token validado"
        let chName = ch{"name"}.getStr("")
        self.addLog(fmt"Autenticado com sucesso como treinador '{chName}' (Nível {self.level})")
    except CatchableError:
      self.addLog("Token expirado. Tentando renovação via /api/auth/refresh...")
      try:
        discard await self.client.refreshAccessToken()
        self.addLog("🎉 Token renovado com sucesso via refresh!")
      except CatchableError:
        self.addLog("Falha ao renovar token. Tentando conexão resiliente...")
  elif self.client.refreshToken.len > 0:
    try:
      discard await self.client.refreshAccessToken()
      self.addLog("🎉 Token obtido com sucesso via refresh!")
    except CatchableError: discard

  asyncCheck self.pingLoop()
  asyncCheck self.watchdogLoop()
  asyncCheck self.dailyLoop()

  while self.running:
    let token = self.client.token
    if token.len == 0:
      self.status = "Aguardando token..."
      await sleepAsync(5000)
      continue

    let wsUrl = computeWebsocketUrl(token)
    self.status = "Conectando ao WebSocket..."
    try:
      self.ws = await newWebSocket(wsUrl)
      self.isConnected = true
      self.status = "Conectado. Inicializando..."
      self.addLog("Conectado ao servidor Poke Idle World.")

      # Handshake e pacotes iniciais de sincronização
      discard await self.sendWs("{\"type\":\"pokes-get\"}")
      discard await self.sendWs("{\"type\":\"balls-get\"}")
      discard await self.sendWs("{\"type\":\"autohelper-get\"}")
      discard await self.sendWs("{\"type\":\"inv-get\"}")
      discard await self.sendWs("{\"type\":\"analyzer-get\"}")
      discard await self.sendWs("{\"type\":\"guild-get\",\"with_list\":true}")
      discard await self.sendWs("{\"type\":\"enter-hunt\",\"slug\":\"taillow\"}")

      await self.readerLoop()
    except CatchableError as e:
      self.addLog("Conexão WebSocket interrompida: " & e.msg)
      if e.msg.contains("4001") or e.msg.contains("unauthorized"):
        self.addLog("Token inválido/expirado detectado (4001). Tentando renovar via refreshToken...")
        try:
          discard await self.client.refreshAccessToken()
        except CatchableError: discard

    self.isConnected = false
    self.isHunting = false
    self.status = "Desconectado"
    let reconnWait = applyJitter(4000, 0.20)
    await sleepAsync(reconnWait)

proc toDto*(self: BotInstance): AccountStatusDto =
  let elapsed = (epochTime() - self.startTime).int64
  result = AccountStatusDto(
    id: self.config.id,
    name: self.config.name,
    level: self.level,
    vocation: "Treinador",
    hp: self.hp,
    maxHp: self.maxHp,
    mana: self.mana,
    maxMana: self.maxMana,
    gold: self.gold,
    kills: self.kills,
    expPerHour: self.expPerHour,
    status: self.status,
    currentArea: self.currentArea,
    durationSec: elapsed,
    logs: self.logs,
    updatedAt: (epochTime() * 1000).int64,
    extra: ExtraStatusDto(
      autoWeakness: self.config.settings.autoWeakness,
      balls: self.balls,
      captures: self.captures,
      guild: self.guild,
      guildBonus: self.guildBonus,
      guildTag: self.guildTag,
      matchup: self.matchup,
      pokedexFarmMode: self.config.settings.pokedexFarmMode,
      pokedexKills: self.pokedexKills,
      slug: self.slug
    )
  )
