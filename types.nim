import std/[json, options]

type
  GameCredentials* = object
    email*: string
    password*: string
    token*: string
    refreshToken*: string

  GameSettings* = object
    huntTarget*: string
    autoWeakness*: bool
    autoHunt*: bool
    autoCatch*: bool
    ballId*: int
    shinyBallId*: int
    autoBuyBalls*: bool
    minBalls*: int
    buyBallQty*: int
    autoHeal*: bool
    healThresholdHp*: int
    autoDaily*: bool
    autoSell*: bool
    autoGuildAccept*: bool
    autoGuildRecruit*: bool
    autoPokedexClaim*: bool
    pokedexFarmMode*: bool

  AccountConfig* = object
    id*: string
    name*: string
    enabled*: bool
    credentials*: GameCredentials
    settings*: GameSettings

  ExtraStatusDto* = object
    autoWeakness*: bool
    balls*: int
    captures*: int
    guild*: string
    guildBonus*: string
    guildTag*: string
    matchup*: string
    pokedexFarmMode*: bool
    pokedexKills*: string
    slug*: string

  AccountStatusDto* = object
    id*: string
    name*: string
    level*: int
    vocation*: string
    hp*: int
    maxHp*: int
    mana*: int
    maxMana*: int
    gold*: int64
    kills*: int64
    expPerHour*: float
    status*: string
    currentArea*: string
    durationSec*: int64
    logs*: seq[string]
    updatedAt*: int64
    extra*: ExtraStatusDto

proc parseCredentials(node: JsonNode): GameCredentials =
  if node != nil:
    result.email = node{"email"}.getStr("")
    result.password = node{"password"}.getStr("")
    result.token = node{"token"}.getStr("")
    result.refreshToken = node{"refreshToken"}.getStr(node{"refresh_token"}.getStr(""))

proc parseSettings(node: JsonNode): GameSettings =
  result.huntTarget = "auto"
  result.autoWeakness = true
  result.autoHunt = true
  result.autoCatch = true
  result.ballId = 1
  result.shinyBallId = 3
  result.autoBuyBalls = true
  result.minBalls = 20
  result.buyBallQty = 50
  result.autoHeal = true
  result.healThresholdHp = 30
  result.autoDaily = true
  result.autoSell = true
  result.autoGuildAccept = true
  result.autoGuildRecruit = true
  result.autoPokedexClaim = true
  result.pokedexFarmMode = true

  if node != nil:
    if node.hasKey("huntTarget"): result.huntTarget = node["huntTarget"].getStr("auto")
    elif node.hasKey("hunt_target"): result.huntTarget = node["hunt_target"].getStr("auto")

    if node.hasKey("autoWeakness"): result.autoWeakness = node["autoWeakness"].getBool(true)
    if node.hasKey("autoHunt"): result.autoHunt = node["autoHunt"].getBool(true)
    if node.hasKey("autoCatch"): result.autoCatch = node["autoCatch"].getBool(true)
    if node.hasKey("ballId"): result.ballId = node["ballId"].getInt(1)
    if node.hasKey("shinyBallId"): result.shinyBallId = node["shinyBallId"].getInt(3)
    if node.hasKey("autoBuyBalls"): result.autoBuyBalls = node["autoBuyBalls"].getBool(true)
    if node.hasKey("minBalls"): result.minBalls = node["minBalls"].getInt(20)
    if node.hasKey("buyBallQty"): result.buyBallQty = node["buyBallQty"].getInt(50)
    if node.hasKey("autoHeal"): result.autoHeal = node["autoHeal"].getBool(true)
    if node.hasKey("healThresholdHp"): result.healThresholdHp = node["healThresholdHp"].getInt(30)
    if node.hasKey("autoDaily"): result.autoDaily = node["autoDaily"].getBool(true)
    if node.hasKey("autoSell"): result.autoSell = node["autoSell"].getBool(true)
    if node.hasKey("autoGuildAccept"): result.autoGuildAccept = node["autoGuildAccept"].getBool(true)
    if node.hasKey("autoGuildRecruit"): result.autoGuildRecruit = node["autoGuildRecruit"].getBool(true)
    if node.hasKey("autoPokedexClaim"): result.autoPokedexClaim = node["autoPokedexClaim"].getBool(true)
    if node.hasKey("pokedexFarmMode"): result.pokedexFarmMode = node["pokedexFarmMode"].getBool(true)

proc parseAccountConfig*(node: JsonNode): AccountConfig =
  result.id = node{"id"}.getStr("")
  result.name = node{"name"}.getStr(result.id)
  result.enabled = node{"enabled"}.getBool(true)
  result.credentials = parseCredentials(node{"credentials"})
  result.settings = parseSettings(node{"settings"})
