# Windows Ollama Binary

This directory should contain `ollama.exe` for Windows.

## How to get the binary:

1. **Download from Ollama releases:**
   ```bash
   # Download latest Windows binary
   wget -O ollama.exe https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.exe
   ```

2. **Or run the setup script:**
   ```bash
   # From project root
   ./scripts/setup-ollama-binaries.sh
   ```

## File size:
The ollama.exe binary is approximately 600MB and cannot be stored in git due to size limits.

## For testing without the binary:
The app will gracefully fall back to the existing fllama service if ollama.exe is not found.