export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:/Users/ganeshrajendran/.local/pipx/venvs/flask:/opt/homebrew/bin:/usr/bin/python3:/Users/ganeshrajendran/Library/Python/3.9/bin:/Users/ganeshrajendran/Library/Python/3.9/lib/python/site-packages:/opt/homebrew/opt/rabbitmq/sbin/:/opt/homebrew/bin/pyright"


# Added by Antigravity CLI installer
export PATH="/Users/ganeshrajendran/.local/bin:$PATH"
export PATH="/Users/ganeshrajendran/.local/bin:$PATH"

# opencode
export PATH=/Users/ganeshrajendran/.opencode/bin:$PATH

# Claude Code Local Ollama Helper
claude-local() {
  local model="${1:-qwen2.5:14b}"
  echo "Starting Claude Code locally using Ollama ($model)..."
  env ANTHROPIC_BASE_URL="http://localhost:11434" \
      ANTHROPIC_AUTH_TOKEN="ollama" \
      ANTHROPIC_API_KEY="" \
      claude --model "$model"
}

