# DevGuard AI Copilot

A cross-platform productivity and security copilot application for developers.

## Features

- **Natural Language Spec-to-Code Workflow**: Convert specifications into structured git commits and pull requests
- **Basic Deployment & Rollback**: Simple CI/CD pipeline management with rollback safety
- **Essential Security Monitoring**: Database honeytokens, configuration drift detection, and authentication monitoring
- **AI Sidechat Copilot**: Collapsible sidebar assistant with explanations and quick commands
- **Transparency & Audit Logging**: Complete visibility into all AI-driven actions
- **Cross-Platform Desktop**: Flutter app for Windows, macOS, and Linux

## Getting Started

### Prerequisites

- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run -d windows  # or -d macos, -d linux
   ```

## Architecture

The application follows a clean architecture pattern with:

- **Presentation Layer**: Flutter UI with Provider state management
- **Core Layer**: Business logic, routing, and theme management
- **Data Layer**: SQLite database with repository pattern

## Development

### Project Structure

```
lib/
├── core/
│   ├── database/          # Database service and models
│   ├── providers/         # State management providers
│   ├── routing/           # Navigation and routing
│   └── theme/             # App theming
├── presentation/
│   ├── screens/           # Main application screens
│   └── widgets/           # Reusable UI components
└── main.dart              # Application entry point
```

### Running Tests

```bash
flutter test
```

## License

This project is part of a hackathon implementation and is provided as-is for demonstration purposes.