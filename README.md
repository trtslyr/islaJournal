# Isla Journal

A fully offline AI-powered journaling application with a simple, Notion-like UI built with Flutter.

## 🎯 Phase 1 - COMPLETE ✅

Phase 1 has been successfully implemented with all core journaling features:

- ✅ **File & Folder Management** - Create, organize, and manage your journal entries
- ✅ **Rich Text Editor** - Professional writing experience with formatting tools
- ✅ **Full-Text Search** - Search across all your journal entries instantly
- ✅ **Local Storage** - Everything stored locally with SQLite + file system
- ✅ **Beautiful UI** - Clean, analog-inspired design with JetBrains Mono font
- ✅ **Cross-Platform** - Works on iOS, Android, macOS, Windows, and Linux

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK (comes with Flutter)

### Installation
1. Clone this repository
2. Navigate to the project directory
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

### Supported Platforms
- **iOS**: `flutter run -d ios`
- **Android**: `flutter run -d android`
- **macOS**: `flutter run -d macos`
- **Windows**: `flutter run -d windows`
- **Linux**: `flutter run -d linux`

## 📁 Features

### File Management
- Create and organize journal entries in folders
- Expandable folder tree navigation
- Context menus for file operations
- Recent files for quick access

### Writing Experience
- Rich text editor with formatting toolbar
- Auto-save every 2 seconds
- Real-time word count
- Beautiful typography with JetBrains Mono font

### Search
- Full-text search across all entries
- Instant search results
- Context snippets in search results

### Design
- Analog, typewriter-inspired aesthetic
- Warm brown and cream color scheme
- Clean, minimal interface
- Responsive design for all screen sizes

## 🏗️ Architecture

The app follows a clean architecture pattern:

```
lib/
├── core/theme/           # App theme and styling
├── models/              # Data models
├── services/            # Database and file services
├── providers/           # State management
├── screens/             # App screens
├── widgets/             # Reusable widgets
└── main.dart           # App entry point
```

## 🎨 Design Philosophy

- **Minimalist**: Clean, simple interface focused on writing
- **Offline-first**: No internet required, everything stored locally
- **Privacy-focused**: Your data never leaves your device
- **Typewriter-inspired**: Monospace fonts and intentional design

## 📊 Tech Stack

- **Framework**: Flutter
- **Database**: SQLite with FTS5 search
- **Rich Text**: Simple text editor
- **State Management**: Provider
- **Storage**: Local file system + SQLite
- **Typography**: JetBrains Mono font

## 🔄 Development Phases

- **Phase 1**: ✅ Core journaling app (COMPLETE)
- **Phase 2**: 🔄 AI integration (Llama 3 models)
- **Phase 3**: 🔄 Advanced AI features
- **Phase 4**: 🔄 Platform optimization

## 📖 Getting Started

1. **First Launch**: The app creates default folders (Personal, Work, Ideas)
2. **Create Entry**: Click the "+" button to create your first journal entry
3. **Organize**: Use folders to organize your thoughts and projects
4. **Search**: Use the search feature to find specific entries
5. **Write**: Enjoy the distraction-free writing experience

## 🛠️ Development

### Project Structure
See `PHASE_1_IMPLEMENTATION_SUMMARY.md` for detailed implementation notes.

### Key Files
- `lib/main.dart` - App entry point
- `lib/screens/home_screen.dart` - Main app interface
- `lib/services/database_service.dart` - Data persistence
- `lib/providers/journal_provider.dart` - State management

### Building for Release
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

## 🎯 Vision

Isla Journal aims to be the ultimate private, AI-enhanced journaling experience that works completely offline. Phase 1 provides the foundation - a beautiful, functional journaling app. Future phases will add AI capabilities for writing assistance, insights, and intelligent organization.

## 📝 License

This project is part of the Isla Journal development plan. See the main tech stack document for licensing details.

---

**Current Status**: Phase 1 Complete ✅  
**Next**: Phase 2 - AI Integration 🤖
