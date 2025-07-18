# Isla Journal - Tech Stack & Development Plan

## Project Overview
**Isla Journal** is a fully offline AI-powered journaling application with a simple, Notion-like UI. The core innovation is local AI inference using Llama 3 models that users download to their devices, ensuring complete privacy and offline functionality.

**Website**: islajournal.app  
**Vision**: Create a private, AI-enhanced journaling experience that works completely offline

## Design Philosophy
- **Minimalist**: Clean, simple, analog aesthetic
- **Typewriter-inspired**: Monospace fonts (JetBrains Mono, SF Mono, Consolas)
- **Offline analog vibe**: Digital typewriter feel, intentional and focused
- **Privacy-first**: Everything stays on the user's device
- **Offline-first**: No internet dependency for core functionality

## Tech Stack

### Frontend/Apps (Beta Focus)
- **Flutter** (Cross-platform: iOS, Android, macOS, Windows, Linux)
- **Beta Priority**: Mobile (iOS/Android) + Desktop (macOS/Windows/Linux)
- **Web**: Future consideration (basic journaling only)
- **Typography**: 
  - Primary: `JetBrains Mono` (Developer-focused monospace font)
  - Fallbacks: `SF Mono` (macOS), `Consolas` (Windows), `Monaco` (fallback)
  - Style: Technical/coding aesthetic, typewriter-inspired feel
- **Rich Text Editor**: 
  - `flutter_quill` (Most mature option)
  - `appflowy_editor` (Open-source Notion alternative)
  - `super_editor` (Advanced capabilities)
- **UI Framework**: Custom minimal theme with monospace typography
- **Design Elements**:
  - Muted color palette (grays, off-whites, subtle accent colors)
  - Generous whitespace for breathing room
  - Subtle paper-like textures (optional)
  - Minimal iconography with clean lines

### Local AI Inference
- **Core Engine**: ollama + llama.cpp integration
- **Flutter Packages**:
  - `ollama-dart` or `llama_cpp_dart`
  - `flutter_llama` (alternative)
  - `langchain_dart` (for advanced AI workflows)
- **Model Format**: GGUF (optimized for local inference)
- **Model Versions**:
  - Llama 3.1 8B (desktop)
  - Llama 3.2 3B (mobile)
  - Quantized versions (4-bit/8-bit) for mobile devices
- **Licensing**: 
  - Uses Meta Llama 3 Community License
  - ✅ Commercial use permitted (under 700M MAU limit)
  - ✅ Local inference and distribution allowed
  - **Requirements**: Include license notice, credit Meta in app
  - **Compliance**: No harmful content, follow acceptable use policy

### Local Storage & Database
- **SQLite** with `sqflite` (file metadata, folder structure, search index)
- **File System** (actual journal content as files)
- **Hive** or `Isar` (app settings, recent files, user preferences)
- **flutter_secure_storage** (encryption keys, sensitive data)
- **Local storage** (attachments, images, audio, model files)

### Data Schema (File/Folder Structure)
```sql
-- Folders table
CREATE TABLE folders (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  parent_id TEXT REFERENCES folders(id),
  created_at DATETIME,
  updated_at DATETIME
);

-- Files table  
CREATE TABLE files (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  folder_id TEXT REFERENCES folders(id),
  file_path TEXT NOT NULL,  -- actual file location
  created_at DATETIME,
  updated_at DATETIME,
  word_count INTEGER,
  last_opened DATETIME
);

-- Search index for full-text search
CREATE VIRTUAL TABLE files_fts USING fts5(
  file_id, title, content
);
```

### Landing Page (islajournal.app) ✅ LIVE
- **Framework**: Astro or Next.js (static site generation)
- **Styling**: Tailwind CSS (minimalist, analog-inspired design)
- **Typography**: Monospace fonts matching app aesthetic
- **Animations**: Subtle, typewriter-inspired transitions
- **Payments**: Stripe (founder licenses, premium features) ✅
- **Hosting**: Vercel or Netlify ✅
- **Status**: Live with ads running, 5 paying customers, 20 on waitlist

### Additional Services
- **Error Tracking**: Sentry (optional, privacy-respecting)
- **Analytics**: Privacy-focused analytics or none
- **Email**: SendGrid or Mailgun (transactional emails for landing page)

## Technical Architecture

```
┌─────────────────────────────────────┐
│           Flutter App               │
├─────────────────────────────────────┤
│    Rich Text Editor Component       │
├─────────────────────────────────────┤
│       Local AI Service             │
│  ┌─────────────────────────────────┐│
│  │     Llama 3 Model Runner       ││
│  │     (ollama/llama.cpp)          ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│       Local Storage Layer          │
│  ┌─────────────┬─────────────────┐  │
│  │   SQLite    │   File System   │  │
│  │ (Entries)   │ (Attachments)   │  │
│  └─────────────┴─────────────────┘  │
└─────────────────────────────────────┘
```

## Core Features

### File & Folder Management (Simple & Analog)
- **File Structure**: Create journal files, organize in folders
- **Navigation**: Traditional file explorer interface
- **Hierarchy**: Nested folders for organization (Work/Personal/Projects/etc.)
- **File Operations**: New, rename, move, delete, duplicate
- **Rich Text Editor**: Simple, clean writing experience with basic formatting

### Journal Entry Features  
- **Media Support**: Images, audio recordings, attachments
- **Search**: Full-text search across all files and folders
- **Export**: PDF, JSON, plain text export options
- **Recent Files**: Quick access to recently edited entries

### AI-Powered Features (Per File/Context)
- **Writing Assistance**: Grammar, style, tone suggestions while typing
- **Smart Insights**: Mood analysis, topic extraction for current file
- **Auto-suggestions**: File naming suggestions, folder organization
- **Semantic Search**: AI-powered search across all files and folders
- **Writing Prompts**: Contextual prompts based on file content and history
- **Conversation Mode**: Ask AI about specific files or your entire journal
- **File Analytics**: Word count trends, writing patterns, mood over time

### Privacy & Security
- **Full Offline Operation**: No data leaves the device
- **Local Encryption**: Encrypted storage for sensitive data
- **Secure Backup**: Local backup options
- **Data Portability**: Easy export/import of all data

### Design Implementation (Flutter)
- **Font Family**: 
  ```dart
  fontFamily: 'JetBrains Mono'
  // Fallback: GoogleFonts.jetBrainsMono()
  ```
- **Color Scheme** (Brand Colors):
  ```dart
  // Primary Brand Colors
  static const warmBrown = Color(0xFF8B5A3C);      // Branding, buttons, links
  static const darkerBrown = Color(0xFF704832);    // Hover states
  static const darkText = Color(0xFF1A1A1A);       // Primary text
  
  // Background Colors
  static const creamBeige = Color(0xFFF5F2E8);     // Main background
  static const darkerCream = Color(0xFFEBE7D9);    // Alternate sections
  
  // Supporting Colors
  static const mediumGray = Color(0xFF666666);     // Secondary text
  static const lightGray = Color(0xFF555555);      // Tertiary text
  static const warningRed = Color(0xFFCC4125);     // External service icons
  static const white = Color(0xFFF5F2E8);          // Button text, highlights
  ```
- **Typography Scale & Weights**:
  ```dart
  // Font Weights
  static const normal = FontWeight.w400;     // Body text
  static const medium = FontWeight.w500;     // Emphasized text
  static const semiBold = FontWeight.w600;   // Section titles, buttons
  static const bold = FontWeight.w700;       // Main headings
  
  // Font Sizes (responsive)
  static const heroTitle = 56.0;      // 3.5rem desktop → 28.8 mobile (1.8rem)
  static const sectionTitle = 32.0;   // 2rem desktop → 24.0 mobile (1.5rem)
  static const heroSubtitle = 19.2;   // 1.2rem desktop → 14.4 mobile (0.9rem)
  static const bodyText = 16.0;       // 1rem desktop → 12.8 mobile (0.8rem)
  static const smallText = 12.8;      // 0.8rem for descriptions/captions
  ```
- **UI Elements**:
  - Buttons: `warmBrown` background with `white` text
  - Hover states: `darkerBrown` background
  - Input fields: `creamBeige` background with `warmBrown` focus borders
  - Subtle borders: `rgba(139, 90, 60, 0.2)`
  - Paper texture effects with radial gradients
  - Generous padding (16px/24px/32px grid)

### UI Layout (Simple File Manager Style)
```
┌─────────────────────────────────────────────────────┐
│  [≡] Isla Journal                    [+] [⚙️] [🔍]  │
├─────────────────┬───────────────────────────────────┤
│                 │                                   │
│   📁 Personal   │   # Morning Thoughts              │
│   📁 Work       │                                   │
│   📁 Projects   │   Today I realized that...        │
│   ───────────   │                                   │
│   📄 Daily.md   │   The weather is perfect for      │
│   📄 Ideas.md   │   a walk in the park. I think     │
│   📄 Goals.md   │   I'll take my notebook and...    │
│                 │                                   │
│                 │                                   │
│                 │   [AI Suggestions]                │
│                 │   💡 Continue this thought...     │
│                 │   😊 Mood: Peaceful, Optimistic   │
└─────────────────┴───────────────────────────────────┘
```

### Interface Elements
- **Left Sidebar**: File/folder tree with expand/collapse
- **Main Editor**: Clean, minimal text editor with JetBrains Mono
- **Top Bar**: Simple navigation, search, settings
- **Bottom Panel**: AI suggestions, word count, writing stats
- **Context Menus**: Right-click for file operations (rename, delete, move)
- **Drag & Drop**: Move files between folders

## Development Phases

### Phase 1: Core App (MVP/Beta) - Mobile & Desktop Focus
**Goal**: Simple file/folder journaling app with clean UI
- [ ] Flutter app setup with navigation (iOS, Android, macOS, Windows, Linux)
- [ ] File/folder management system (create, rename, delete, move)
- [ ] Rich text editor integration (flutter_quill for simplicity)
- [ ] Local storage implementation (SQLite metadata + file system)
- [ ] File tree navigation (expandable folders, file icons)
- [ ] Search functionality (full-text search across files)
- [ ] Export capabilities (PDF, JSON, plain text per file)
- [ ] Analog UI: JetBrains Mono, warm brown color scheme
- [ ] Context menus and drag-drop file operations
- [ ] Beta distribution setup (TestFlight, Play Store Internal, direct downloads)

### Phase 2: AI Integration
**Goal**: Local AI inference capabilities
- [ ] Llama 3 model integration
- [ ] Model download system with progress tracking
- [ ] Basic AI features (text analysis, suggestions)
- [ ] Offline inference pipeline
- [ ] Memory optimization for mobile devices
- [ ] Graceful degradation when model unavailable.

### Phase 3: Advanced AI Features
**Goal**: Sophisticated AI-powered journaling
- [ ] Semantic search across entries
- [ ] Advanced mood and theme analysis
- [ ] Contextual writing prompts
- [ ] Conversation mode with AI
- [ ] Smart auto-tagging
- [ ] Personalized insights dashboard

### Phase 4: Platform Optimization
**Goal**: Multi-platform excellence
- [ ] Desktop app optimization (macOS, Windows, Linux)
- [ ] Performance optimizations
- [ ] Advanced rich text features
- [ ] Voice-to-text journaling
- [ ] Sync between devices (local network)
- [ ] Advanced export options

## Technical Challenges & Solutions

### Model Size & Performance
- **Challenge**: Large model files (4-8GB+)
- **Solution**: 
  - Progressive download with pause/resume
  - Quantized models for mobile
  - Lazy loading of AI features
  - Memory management optimization

### Offline-First Architecture
- **Challenge**: No cloud dependency
- **Solution**:
  - Robust local storage with automatic backups
  - Export/import capabilities for data portability
  - Local network sync for multi-device users

### User Experience
- **Challenge**: Complex AI setup for average users
- **Solution**:
  - Guided model download process
  - Clear progress indicators
  - Fallback to basic features during setup
  - Intuitive onboarding flow

## Monetization Strategy

### Pricing Tiers
- **Free Version**: Basic journaling, limited AI features
- **Founder License**: $49 one-time (full AI features, early access)
- **Premium**: $29 one-time (alternative to founder pricing)
- **Model Marketplace**: Additional specialized models (future)

### Revenue Streams
1. **One-time Purchases**: No subscriptions, full offline ownership
2. **Premium Models**: Specialized AI models for specific use cases
3. **Professional Features**: Advanced export, team features (future)

## Unique Selling Points

1. **Complete Privacy**: Everything stays on device, no cloud dependency
2. **No Internet Required**: Works everywhere, anytime
3. **AI-Powered**: Intelligent insights and suggestions
4. **Analog Digital Experience**: Typewriter-inspired, intentional journaling
5. **Cross-Platform**: One app, all devices
6. **One-time Purchase**: No subscriptions or ongoing costs
7. **Proven Demand**: 5 paying customers + 20 on waitlist before launch

## Device Requirements

### Minimum Requirements
- **Mobile**: 4GB RAM, 8GB storage
- **Desktop**: 8GB RAM, 16GB storage
- **Processors**: ARM64 or x86_64 with good performance

### Recommended Requirements
- **Mobile**: 6GB+ RAM, 16GB+ storage
- **Desktop**: 16GB+ RAM, 32GB+ storage
- **GPU**: Dedicated GPU for faster inference (optional)

## Future Roadmap

### Year 1
- Launch beta with core journaling features (Week 1)
- Integrate local AI inference (Weeks 2-4)
- Release on major platforms (Month 2-3)
- Build user community and iterate based on feedback

### Year 2
- Advanced AI features and insights
- Multi-language support
- Plugin/extension system
- Voice and multimedia journaling

### Year 3
- Specialized AI models for different use cases
- Advanced analytics and insights
- Integration with other productivity tools
- Enterprise/team features

## Risk Mitigation

### Technical Risks
- **Model Performance**: Test on various devices, provide multiple model sizes
- **Storage Limitations**: Efficient compression, cleanup tools
- **Battery Usage**: Optimize inference, background processing limits

### Business Risks
- **Market Acceptance**: Strong focus on privacy messaging
- **Competition**: Leverage unique offline-first approach
- **Model Licensing**: Use open-source models, clear licensing

## Success Metrics

### Technical Metrics
- App startup time < 3 seconds
- AI inference time < 10 seconds
- Crash rate < 0.1%
- Model download success rate > 95%

### Business Metrics
- User retention rate > 60% (30 days)
- Conversion rate from free to paid > 15%
- Average session time > 10 minutes
- User satisfaction score > 4.5/5

---

**Last Updated**: January 2025  
**Project Status**: Pre-Launch with Validated Demand  
**Current Metrics**: 
- 5 paying customers ($50 lifetime)
- 20 people on waitlist
- Landing page live with ads running
- Total revenue: $250

**Next Steps**: Sprint to Phase 1 beta completion (~1 week target) 