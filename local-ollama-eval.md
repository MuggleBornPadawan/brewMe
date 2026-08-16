---
name: local-ollama-eval
description: >-
  Use this skill when you need to run high-volume, low-complexity text processing,
  code boilerplate generation, or test draft writing tasks using a local Ollama model.
---

# Local Ollama Evaluator Skill

This skill allows the agent to offload specific tasks to your local Ollama models using the registered `ollama` MCP server.

## Instructions for the Agent

1. **Verify Ollama is Running**:
   Call the `ollama` tool `list` to check available local models.
2. **Execute the Subtask**:
   Call the `ollama` tool `chat_completion` with the selected model (e.g., `llama3` or `qwen2.5-coder`) and the prompt.
3. **Process the Output**:
   Integrate the generated code, explanation, or text back into the workspace.

## Example MCP Call Structure

```json
{
  "ServerName": "ollama",
  "ToolName": "chat_completion",
  "Arguments": {
    "model": "qwen2.5-coder",
    "messages": [
      {
        "role": "user",
        "content": "Generate a standard boilerplate for a python fast-api endpoint."
      }
    ]
  }
}
```
