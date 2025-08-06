#!/bin/bash

# Setup script for downloading Ollama binaries
set -e

echo "🚀 Setting up Ollama binaries for embedded distribution..."

# Create directories
mkdir -p assets/binaries/windows
mkdir -p assets/models

# Function to download with progress
download_with_progress() {
    local url=$1
    local output=$2
    local description=$3
    
    echo "📥 Downloading $description..."
    echo "   URL: $url"
    echo "   Output: $output"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$output" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget --progress=bar:force -O "$output" "$url"
    else
        echo "❌ Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    if [ -f "$output" ]; then
        local size=$(du -h "$output" | cut -f1)
        echo "✅ Downloaded $description ($size)"
    else
        echo "❌ Failed to download $description"
        exit 1
    fi
}

# Download Windows Ollama binary
WINDOWS_BINARY_URL="https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.exe"
WINDOWS_OUTPUT="assets/binaries/windows/ollama.exe"

if [ ! -f "$WINDOWS_OUTPUT" ]; then
    download_with_progress "$WINDOWS_BINARY_URL" "$WINDOWS_OUTPUT" "Windows Ollama binary"
else
    echo "✅ Windows Ollama binary already exists"
fi

# Make executable (for Unix systems, though Windows binary won't need this)
chmod +x assets/binaries/windows/ollama.exe 2>/dev/null || true

# Optional: Download a small model for testing
# Commented out by default due to size
# echo "📥 Downloading small test model (optional)..."
# MODEL_URL="https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf"
# MODEL_OUTPUT="assets/models/phi3-mini.gguf"
# 
# if [ ! -f "$MODEL_OUTPUT" ]; then
#     download_with_progress "$MODEL_URL" "$MODEL_OUTPUT" "Phi-3 Mini model"
# else
#     echo "✅ Phi-3 Mini model already exists"
# fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📊 Downloaded files:"
if [ -f "$WINDOWS_OUTPUT" ]; then
    echo "   Windows binary: $(du -h "$WINDOWS_OUTPUT" | cut -f1) - $WINDOWS_OUTPUT"
fi

echo ""
echo "📝 Next steps:"
echo "   1. Test the embedded Ollama: flutter run"
echo "   2. On first run, Ollama will download the phi3:mini model automatically"
echo "   3. Check debug logs to see if embedded Ollama starts successfully"
echo ""
echo "⚠️  Note: The first AI generation may take a few minutes while Ollama downloads the model"