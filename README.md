## Friday

Friday is an ultra-lightweight personal AI Assistant inspired by [nanobot](https://github.com/HKUDS/nanobot) and [picoclaw](https://github.com/sipeed/picoclaw), refactored from the ground up in Go through a self-bootstrapping process, where the AI agent itself drove the entire architectural migration and code optimization.

Runs on $10 hardware with <10MB RAM: That's 99% less memory than OpenClaw and 98% cheaper than a Mac mini!


## Features

**Ultra-Lightweight**: <10MB Memory footprint — 99% smaller than Clawdbot - core functionality.

**Minimal Cost**: Efficient enough to run on $10 Hardware — 98% cheaper than a Mac mini.

**Lightning Fast**: 400X Faster startup time, boot in 1 second even in 0.6GHz single core.

**True Portability**: Single self-contained binary across RISC-V, ARM, and x86, One-click to Go!

**AI-Bootstrapped**: Autonomous Go-native implementation — 95% Agent-generated core with human-in-the-loop refinement.

## Install

### Install with precompiled binary

Download the firmware for your platform from the [release](https://github.com/pro-utkarshM/friday/releases) page.

### Install from source (latest features, recommended for development)

```bash
git clone https://github.com/pro-utkarshM/friday.git

cd friday
make deps

# Build, no need to install
make build

# Build for multiple platforms
make build-all

# Build And Install
make install
```

## Docker Compose

You can also run PicoClaw using Docker Compose without installing anything locally.

```bash
# 1. Clone this repo
git clone https://github.com/pro-utkarshM/friday.git
cd picoclaw

# 2. Set your API keys
cp config/config.example.json config/config.json
vim config/config.json      # Set DISCORD_BOT_TOKEN, API keys, etc.

# 3. Build & Start
docker compose --profile gateway up -d

# 4. Check logs
docker compose logs -f picoclaw-gateway

# 5. Stop
docker compose --profile gateway down
```

### Agent Mode (One-shot)

```bash
# Ask a question
docker compose run --rm picoclaw-agent -m "What is 2+2?"

# Interactive mode
docker compose run --rm picoclaw-agent
```

### Rebuild

```bash
docker compose --profile gateway build --no-cache
docker compose --profile gateway up -d
```

### 🚀 Quick Start

> [!TIP]
> Set your API key in `~/.picoclaw/config.json`.
> Get API keys: [OpenRouter](https://openrouter.ai/keys) (LLM) · [Zhipu](https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys) (LLM)
> Web search is **optional** - get free [Brave Search API](https://brave.com/search/api) (2000 free queries/month) or use built-in auto fallback.

**1. Initialize**

```bash
picoclaw onboard
```

**2. Configure** (`~/.picoclaw/config.json`)

```json
{
  "agents": {
    "defaults": {
      "workspace": "~/.picoclaw/workspace",
      "model": "glm-4.7",
      "max_tokens": 8192,
      "temperature": 0.7,
      "max_tool_iterations": 20
    }
  },
  "providers": {
    "openrouter": {
      "api_key": "xxx",
      "api_base": "https://openrouter.ai/api/v1"
    }
  },
  "tools": {
    "web": {
      "brave": {
        "enabled": false,
        "api_key": "YOUR_BRAVE_API_KEY",
        "max_results": 5
      },
      "duckduckgo": {
        "enabled": true,
        "max_results": 5
      }
    }
  }
}
```

**3. Get API Keys**

- **LLM Provider**: [OpenRouter](https://openrouter.ai/keys) · [Zhipu](https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys) · [Anthropic](https://console.anthropic.com) · [OpenAI](https://platform.openai.com) · [Gemini](https://aistudio.google.com/api-keys)
- **Web Search** (optional): [Brave Search](https://brave.com/search/api) - Free tier available (2000 requests/month)

> **Note**: See `config.example.json` for a complete configuration template.

**4. Chat**

```bash
picoclaw agent -m "What is 2+2?"
```

That's it! You have a working AI assistant in 2 minutes.

---

## Chat Apps

Talk to your picoclaw through Telegram, Discord, or DingTalk

| Channel      | Setup                      |
| ------------ | -------------------------- |
| **Telegram** | Easy (just a token)        |
| **Discord**  | Easy (bot token + intents) |

<details>
<summary><b>Telegram</b> (Recommended)</summary>

**1. Create a bot**

- Open Telegram, search `@BotFather`
- Send `/newbot`, follow prompts
- Copy the token

**2. Configure**

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "YOUR_BOT_TOKEN",
      "allowFrom": ["YOUR_USER_ID"]
    }
  }
}
```

> Get your user ID from `@userinfobot` on Telegram.

**3. Run**

```bash
picoclaw gateway
```

</details>

<details>
<summary><b>Discord</b></summary>

**1. Create a bot**

- Go to <https://discord.com/developers/applications>
- Create an application → Bot → Add Bot
- Copy the bot token

**2. Enable intents**

- In the Bot settings, enable **MESSAGE CONTENT INTENT**
- (Optional) Enable **SERVER MEMBERS INTENT** if you plan to use allow lists based on member data

**3. Get your User ID**

- Discord Settings → Advanced → enable **Developer Mode**
- Right-click your avatar → **Copy User ID**

**4. Configure**

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "YOUR_BOT_TOKEN",
      "allowFrom": ["YOUR_USER_ID"]
    }
  }
}
```

**5. Invite the bot**

- OAuth2 → URL Generator
- Scopes: `bot`
- Bot Permissions: `Send Messages`, `Read Message History`
- Open the generated invite URL and add the bot to your server

**6. Run**

```bash
picoclaw gateway
```

</details>

## Configuration

Config file: `~/.picoclaw/config.json`

### Workspace Layout

PicoClaw stores data in your configured workspace (default: `~/.picoclaw/workspace`):

```
~/.picoclaw/workspace/
├── sessions/          # Conversation sessions and history
├── memory/           # Long-term memory (MEMORY.md)
├── state/            # Persistent state (last channel, etc.)
├── cron/             # Scheduled jobs database
├── skills/           # Custom skills
├── AGENTS.md         # Agent behavior guide
├── HEARTBEAT.md      # Periodic task prompts (checked every 30 min)
├── IDENTITY.md       # Agent identity
├── SOUL.md           # Agent soul
├── TOOLS.md          # Tool descriptions
└── USER.md           # User preferences
```

### Security Sandbox

PicoClaw runs in a sandboxed environment by default. The agent can only access files and execute commands within the configured workspace.

#### Default Configuration

```json
{
  "agents": {
    "defaults": {
      "workspace": "~/.picoclaw/workspace",
      "restrict_to_workspace": true
    }
  }
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `workspace` | `~/.picoclaw/workspace` | Working directory for the agent |
| `restrict_to_workspace` | `true` | Restrict file/command access to workspace |

#### Protected Tools

When `restrict_to_workspace: true`, the following tools are sandboxed:

| Tool | Function | Restriction |
|------|----------|-------------|
| `read_file` | Read files | Only files within workspace |
| `write_file` | Write files | Only files within workspace |
| `list_dir` | List directories | Only directories within workspace |
| `edit_file` | Edit files | Only files within workspace |
| `append_file` | Append to files | Only files within workspace |
| `exec` | Execute commands | Command paths must be within workspace |

#### Additional Exec Protection

Even with `restrict_to_workspace: false`, the `exec` tool blocks these dangerous commands:

- `rm -rf`, `del /f`, `rmdir /s` — Bulk deletion
- `format`, `mkfs`, `diskpart` — Disk formatting
- `dd if=` — Disk imaging
- Writing to `/dev/sd[a-z]` — Direct disk writes
- `shutdown`, `reboot`, `poweroff` — System shutdown
- Fork bomb `:(){ :|:& };:`

#### Error Examples

```
[ERROR] tool: Tool execution failed
{tool=exec, error=Command blocked by safety guard (path outside working dir)}
```

```
[ERROR] tool: Tool execution failed
{tool=exec, error=Command blocked by safety guard (dangerous pattern detected)}
```

#### Disabling Restrictions (Security Risk)

If you need the agent to access paths outside the workspace:

**Method 1: Config file**
```json
{
  "agents": {
    "defaults": {
      "restrict_to_workspace": false
    }
  }
}
```

**Method 2: Environment variable**
```bash
export PICOCLAW_AGENTS_DEFAULTS_RESTRICT_TO_WORKSPACE=false
```

> ⚠️ **Warning**: Disabling this restriction allows the agent to access any path on your system. Use with caution in controlled environments only.

#### Security Boundary Consistency

The `restrict_to_workspace` setting applies consistently across all execution paths:

| Execution Path | Security Boundary |
|----------------|-------------------|
| Main Agent | `restrict_to_workspace` ✅ |
| Subagent / Spawn | Inherits same restriction ✅ |
| Heartbeat tasks | Inherits same restriction ✅ |

All paths share the same workspace restriction — there's no way to bypass the security boundary through subagents or scheduled tasks.

### Heartbeat (Periodic Tasks)

PicoClaw can perform periodic tasks automatically. Create a `HEARTBEAT.md` file in your workspace:

```markdown
# Periodic Tasks

- Check my email for important messages
- Review my calendar for upcoming events
- Check the weather forecast
```

The agent will read this file every 30 minutes (configurable) and execute any tasks using available tools.

#### Async Tasks with Spawn

For long-running tasks (web search, API calls), use the `spawn` tool to create a **subagent**:

```markdown
# Periodic Tasks

## Quick Tasks (respond directly)
- Report current time

## Long Tasks (use spawn for async)
- Search the web for AI news and summarize
- Check email and report important messages
```

**Key behaviors:**

| Feature | Description |
|---------|-------------|
| **spawn** | Creates async subagent, doesn't block heartbeat |
| **Independent context** | Subagent has its own context, no session history |
| **message tool** | Subagent communicates with user directly via message tool |
| **Non-blocking** | After spawning, heartbeat continues to next task |

#### How Subagent Communication Works

```
Heartbeat triggers
    ↓
Agent reads HEARTBEAT.md
    ↓
For long task: spawn subagent
    ↓                           ↓
Continue to next task      Subagent works independently
    ↓                           ↓
All tasks done            Subagent uses "message" tool
    ↓                           ↓
Respond HEARTBEAT_OK      User receives result directly
```

The subagent has access to tools (message, web_search, etc.) and can communicate with the user independently without going through the main agent.

**Configuration:**

```json
{
  "heartbeat": {
    "enabled": true,
    "interval": 30
  }
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `true` | Enable/disable heartbeat |
| `interval` | `30` | Check interval in minutes (min: 5) |

**Environment variables:**
- `PICOCLAW_HEARTBEAT_ENABLED=false` to disable
- `PICOCLAW_HEARTBEAT_INTERVAL=60` to change interval

### Providers

> [!NOTE]
> Groq provides free voice transcription via Whisper. If configured, Telegram voice messages will be automatically transcribed.

| Provider                   | Purpose                                 | Get API Key                                            |
| -------------------------- | --------------------------------------- | ------------------------------------------------------ |
| `gemini`                   | LLM (Gemini direct)                     | [aistudio.google.com](https://aistudio.google.com)     |
| `zhipu`                    | LLM (Zhipu direct)                      | [bigmodel.cn](bigmodel.cn)                             |
| `openrouter(To be tested)` | LLM (recommended, access to all models) | [openrouter.ai](https://openrouter.ai)                 |
| `anthropic(To be tested)`  | LLM (Claude direct)                     | [console.anthropic.com](https://console.anthropic.com) |
| `openai(To be tested)`     | LLM (GPT direct)                        | [platform.openai.com](https://platform.openai.com)     |
| `deepseek(To be tested)`   | LLM (DeepSeek direct)                   | [platform.deepseek.com](https://platform.deepseek.com) |
| `groq`                     | LLM + **Voice transcription** (Whisper) | [console.groq.com](https://console.groq.com)           |

<details>
<summary><b>Zhipu</b></summary>

**1. Get API key and base URL**

- Get [API key](https://bigmodel.cn/usercenter/proj-mgmt/apikeys)

**2. Configure**

```json
{
  "agents": {
    "defaults": {
      "workspace": "~/.picoclaw/workspace",
      "model": "glm-4.7",
      "max_tokens": 8192,
      "temperature": 0.7,
      "max_tool_iterations": 20
    }
  },
  "providers": {
    "zhipu": {
      "api_key": "Your API Key",
      "api_base": "https://open.bigmodel.cn/api/paas/v4"
    }
  }
}
```

**3. Run**

```bash
picoclaw agent -m "Hello"
```

</details>

<details>
<summary><b>Full config example</b></summary>

```json
{
  "agents": {
    "defaults": {
      "model": "anthropic/claude-opus-4-5"
    }
  },
  "providers": {
    "openrouter": {
      "api_key": "sk-or-v1-xxx"
    },
    "groq": {
      "api_key": "gsk_xxx"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "123456:ABC...",
      "allow_from": ["123456789"]
    },
    "discord": {
      "enabled": true,
      "token": "",
      "allow_from": [""]
    },
    "whatsapp": {
      "enabled": false
    },
    "feishu": {
      "enabled": false,
      "app_id": "cli_xxx",
      "app_secret": "xxx",
      "encrypt_key": "",
      "verification_token": "",
      "allow_from": []
    },
    "qq": {
      "enabled": false,
      "app_id": "",
      "app_secret": "",
      "allow_from": []
    }
  },
  "tools": {
    "web": {
      "brave": {
        "enabled": false,
        "api_key": "BSA...",
        "max_results": 5
      },
      "duckduckgo": {
        "enabled": true,
        "max_results": 5
      }
    }
  },
  "heartbeat": {
    "enabled": true,
    "interval": 30
  }
}
```

</details>

## CLI Reference

| Command                   | Description                   |
| ------------------------- | ----------------------------- |
| `picoclaw onboard`        | Initialize config & workspace |
| `picoclaw agent -m "..."` | Chat with the agent           |
| `picoclaw agent`          | Interactive chat mode         |
| `picoclaw gateway`        | Start the gateway             |
| `picoclaw status`         | Show status                   |
| `picoclaw cron list`      | List all scheduled jobs       |
| `picoclaw cron add ...`   | Add a scheduled job           |

### Scheduled Tasks / Reminders

PicoClaw supports scheduled reminders and recurring tasks through the `cron` tool:

- **One-time reminders**: "Remind me in 10 minutes" → triggers once after 10min
- **Recurring tasks**: "Remind me every 2 hours" → triggers every 2 hours
- **Cron expressions**: "Remind me at 9am daily" → uses cron expression

Jobs are stored in `~/.picoclaw/workspace/cron/` and processed automatically.

## Troubleshooting

### Web search says "API"

This is normal if you haven't configured a search API key yet. PicoClaw will provide helpful links for manual searching.

To enable web search:

1. **Option 1 (Recommended)**: Get a free API key at [https://brave.com/search/api](https://brave.com/search/api) (2000 free queries/month) for the best results.
2. **Option 2 (No Credit Card)**: If you don't have a key, we automatically fall back to **DuckDuckGo** (no key required).

Add the key to `~/.picoclaw/config.json` if using Brave:

```json
{
  "tools": {
    "web": {
      "brave": {
        "enabled": false,
        "api_key": "YOUR_BRAVE_API_KEY",
        "max_results": 5
      },
      "duckduckgo": {
        "enabled": true,
        "max_results": 5
      }
    }
  }
}
```

### Getting content filtering errors

Some providers (like Zhipu) have content filtering. Try rephrasing your query or use a different model.

### Telegram bot says "Conflict: terminated by other getUpdates"

This happens when another instance of the bot is running. Make sure only one `picoclaw gateway` is running at a time.

---

## API Key Comparison

| Service          | Free Tier           | Use Case                              |
| ---------------- | ------------------- | ------------------------------------- |
| **OpenRouter**   | 200K tokens/month   | Multiple models (Claude, GPT-4, etc.) |
| **Zhipu**        | 200K tokens/month   | Best for Chinese users                |
| **Brave Search** | 2000 queries/month  | Web search functionality              |
| **Groq**         | Free tier available | Fast inference (Llama, Mixtral)       |
