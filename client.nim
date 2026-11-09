import std/[asyncdispatch, httpclient, json, strutils]

const
  BaseUrl = "https://poke.idleworld.online"
  UserAgentStr = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

type
  PokeIdleWorldClient* = ref object
    token*: string
    refreshToken*: string

proc newPokeIdleWorldClient*(token: string, refreshToken: string): PokeIdleWorldClient =
  new(result)
  result.token = token
  result.refreshToken = refreshToken

proc createHeaders(self: PokeIdleWorldClient): HttpHeaders =
  result = newHttpHeaders([
    ("Content-Type", "application/json"),
    ("Accept", "application/json, text/plain, */*"),
    ("User-Agent", UserAgentStr)
  ])
  if self.token.len > 0:
    result.add("Authorization", "Bearer " & self.token)

proc getCharacterMe*(self: PokeIdleWorldClient): Future[JsonNode] {.async.} =
  let client = newAsyncHttpClient()
  client.headers = self.createHeaders()
  defer: client.close()

  let url = BaseUrl & "/api/characters/me"
  let resp = await client.get(url)
  if resp.code == Http200:
    let body = await resp.body
    result = parseJson(body)
  else:
    raise newException(IOError, "GET /api/characters/me failed: " & $resp.code)

proc refreshAccessToken*(self: PokeIdleWorldClient): Future[string] {.async.} =
  if self.refreshToken.len == 0:
    raise newException(IOError, "Sem refreshToken")

  let client = newAsyncHttpClient()
  client.headers = self.createHeaders()
  defer: client.close()

  let url = BaseUrl & "/api/auth/refresh"
  let payload = %*{"refreshToken": self.refreshToken}
  let resp = await client.post(url, $payload)
  if resp.code == Http200:
    let body = await resp.body
    let parsed = parseJson(body)
    let at = parsed{"accessToken"}.getStr("")
    let rt = parsed{"refreshToken"}.getStr("")
    if at.len > 0:
      self.token = at
      if rt.len > 0: self.refreshToken = rt
      result = at
    else:
      raise newException(IOError, "Resposta de refresh sem accessToken")
  else:
    raise newException(IOError, "POST /api/auth/refresh failed: " & $resp.code)

proc claimDaily*(self: PokeIdleWorldClient): Future[bool] {.async.} =
  let client = newAsyncHttpClient()
  client.headers = self.createHeaders()
  defer: client.close()

  let url = BaseUrl & "/api/daily/claim"
  try:
    let resp = await client.post(url, "{}")
    result = (resp.code == Http200)
  except CatchableError:
    result = false
