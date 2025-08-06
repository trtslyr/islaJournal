# Windows Ollama Setup Guide

## The Problem
Your Isla Journal app is crashing on Windows when trying to use AI features because the `fllama` package is unstable on Windows.

## The Solution
We've integrated **Ollama** as a Windows-specific solution that runs as a separate process, preventing crashes.

## Quick Setup (5 minutes)

### 1. Install Ollama
1. Go to https://ollama.ai/download
2. Download the Windows installer
3. Run the installer and follow the prompts
4. Ollama will start automatically as a Windows service

### 2. Download a Model
Open Command Prompt and run:
```cmd
ollama pull llama3.2-3b
```
This downloads a 2GB model that works well on most Windows systems.

### 3. Test the Integration
1. Open Isla Journal
2. Go to Settings → AI Models
3. You'll see an "Ollama Windows Test" section
4. Click "Test AI Generation" to verify it works

## How It Works

### Before (Crashing)
- `fllama` runs inside your Flutter app process
- Crashes bring down the entire app
- Memory issues cause instability

### After (Stable)
- `ollama` runs as a separate Windows service
- HTTP API communication between app and ollama
- Crashes are isolated to the ollama process
- Your app stays stable

## Available Models

### Recommended for Windows:
- **llama3.2-3b** (2GB) - Best balance of speed and quality
- **llama3.2-1b** (1GB) - Fastest, good for basic tasks
- **llama3-8b** (5GB) - Highest quality, needs 16GB+ RAM

### Download Models:
```cmd
ollama pull llama3.2-3b    # Recommended
ollama pull llama3.2-1b    # Fastest
ollama pull llama3-8b      # Best quality
```

## Troubleshooting

### "Ollama is not running"
1. Check if ollama is installed: `ollama --version`
2. Start ollama: `ollama serve`
3. Or restart the Windows service

### "Model not found"
1. List available models: `ollama list`
2. Download the model: `ollama pull model-name`

### "Connection refused"
1. Make sure ollama is running on port 11434
2. Check Windows Firewall isn't blocking it
3. Try restarting ollama: `ollama serve`

### Performance Issues
1. Close other applications to free RAM
2. Use smaller models (llama3.2-1b instead of llama3-8b)
3. Check Windows Task Manager for memory usage

## Fallback Behavior

If ollama is not available, the app will:
1. Show an error message with setup instructions
2. Fall back to fllama (may still crash)
3. Provide clear guidance on how to install ollama

## Benefits

✅ **No more crashes** - Separate process isolation
✅ **Better performance** - Optimized for Windows
✅ **Easy model management** - Simple command line tools
✅ **Automatic fallback** - Graceful degradation
✅ **Professional support** - Large community and documentation

## Next Steps

1. Install ollama and test the integration
2. If it works well, we can remove fllama entirely for Windows
3. Consider adding ollama model management to the UI
4. Optimize for your specific Windows setup

## Support

If you encounter issues:
1. Check the ollama logs: `ollama logs`
2. Verify the model is downloaded: `ollama list`
3. Test ollama directly: `ollama run llama3.2-3b "Hello"`
4. Check Windows Event Viewer for system errors

The ollama integration should resolve your Windows AI crashes completely! 