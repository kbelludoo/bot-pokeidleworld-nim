# bot-pokeidleworld-nim ⚡

Automação autônoma nativa para **Poke Idle World Online** reescrita 100% em **Nim 2.2** com modelo de gerenciamento de memória ORC (`--mm:orc`), zero overhead de Garbage Collector e ultra-baixo consumo de memória RAM.

## 🚀 Destaques da Arquitetura Nim
- **100% Paridade de Heurística e Métricas**: Compatível com as métricas JSON de telemetria expostas na porta padrão (`3007`) sob `/api/status`.
- **Motor Anti-Detecção com Pacing e Jitter Orgânico**: Variação randômica de $\pm 20\%$ nos intervalos de caça e ações para evitar assinaturas temporais determinísticas.
- **Operação 24/7 Contínua sem Pausas Forçadas**: Otimizado para jogabilidade de idle contínua.
- **Protocolo Nativo Sharded WebSocket**: Sharding dinâmico baseado em DJB2 hash de JWT claims, renovação automática de access token via `/api/auth/refresh`, claim de diárias e watchdog de caça.
- **Consumo de Memória Extremamente Reduzido**: Binário estático e compacto compilado via Zig toolchain.

## 📦 Compilação
```bash
nim c --os:linux --cpu:amd64 --gcc.exe:zigcc-linux-gnu.bat --gcc.linkerexe:zigcc-linux-gnu.bat -d:ssl -d:release -o:bot-pokeidleworld-linux-nim main.nim
```

## ⚙️ Configuração
Copie `accounts.example.json` para `accounts.json` e insira suas credenciais:
```json
[
  {
    "id": "acc-1",
    "name": "Treinador Principal",
    "enabled": true,
    "credentials": {
      "token": "seu-token-jwt",
      "refreshToken": "seu-refresh-token",
      "email": "user@exemplo.com",
      "password": "senha-segura"
    },
    "settings": {
      "huntTarget": "auto",
      "autoWeakness": true,
      "autoHunt": true,
      "autoCatch": true,
      "autoDaily": true,
      "autoSell": true
    }
  }
]
```
