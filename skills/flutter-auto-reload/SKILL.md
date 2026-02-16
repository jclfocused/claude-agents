---
name: Flutter Auto Hot Reload
description: This skill should be used when the user asks to "set up auto hot reload", "enable automatic reload", "hot reload on save", "watch for file changes", "auto reload flutter", or mentions wanting Flutter to automatically reload when files change. Provides configuration for terminal-based workflows, VS Code, Android Studio, and multi-device setups.
---

# Flutter Auto Hot Reload

This skill provides guidance for setting up automatic hot reload in Flutter projects, enabling instant UI updates when code changes without manual intervention.

## Overview

Flutter's hot reload injects updated source code into the running Dart VM, preserving app state while showing changes instantly. By default, terminal-based workflows require manually pressing 'r' after each change. This skill enables automatic hot reload across different development environments.

## Terminal-Based Workflows (Claude Code, vim, etc.)

### Method 1: PID File + File Watcher (Recommended)

Start Flutter with the `--pid-file` flag to enable signal-based hot reload:

```bash
# Start Flutter with PID tracking
flutter run -d chrome --pid-file=/tmp/flutter.pid
flutter run -d iPhone --pid-file=/tmp/flutter.pid
flutter run -d emulator-5554 --pid-file=/tmp/flutter.pid
```

Then use a file watcher to trigger reload on changes:

**Using fswatch (macOS):**
```bash
# Install if needed
brew install fswatch

# Watch lib/ and trigger hot reload on changes
fswatch -o lib/ | xargs -n1 -I{} kill -USR1 $(cat /tmp/flutter.pid)
```

**Using entr (cross-platform):**
```bash
# Install if needed
brew install entr  # macOS
apt install entr   # Linux

# Watch and reload
find lib -name '*.dart' | entr -p kill -USR1 $(cat /tmp/flutter.pid)
```

**Using inotifywait (Linux):**
```bash
while inotifywait -r -e modify lib/; do
  kill -USR1 $(cat /tmp/flutter.pid)
done
```

### Signal Reference

| Signal  | Action       | Use Case                        |
|---------|--------------|----------------------------------|
| SIGUSR1 | Hot Reload   | Dart file changes               |
| SIGUSR2 | Hot Restart  | pubspec.yaml, asset changes     |

### Method 2: flutter_hot_reload Package

Install the CLI wrapper that handles file watching automatically:

```bash
dart pub global activate flutter_hot_reload
```

Run instead of `flutter run`:
```bash
flutter_hot_reload -d chrome
flutter_hot_reload -d iPhone
```

Features:
- Watches `.dart` files automatically
- Hot restarts on `pubspec.yaml` changes
- Works with any editor or terminal
- No IDE plugin required

### Method 3: Web Experimental Hot Reload (Flutter 3.32+)

For web development specifically:

```bash
flutter run -d chrome --web-experimental-hot-reload
```

This enables automatic hot reload for web without additional setup.

## Chrome DevTools MCP Integration

When using Chrome DevTools MCP to interact with Flutter web apps, use **web-server mode** instead of `-d chrome` to avoid conflicts.

### The Problem

Running `flutter run -d chrome` opens its own Chrome instance. If you also have Chrome DevTools MCP connected to a separate Chrome viewing the same app, you'll get **GlobalKey conflicts**:

```
A GlobalKey was used multiple times inside one widget's child list.
The offending GlobalKey was: [LabeledGlobalKey<NavigatorState>]
```

This happens because both Chrome instances are running the same Flutter app simultaneously.

### The Solution: Web Server Mode

Start Flutter as a web server without opening a browser:

```bash
# Start Flutter web server only (no browser opens)
flutter run -d web-server --web-port=61060 --pid-file=/tmp/flutter.pid
```

Then navigate your MCP Chrome to the app:
- URL: `http://localhost:61060`

### Hot Reload with Web Server Mode

Hot reload signals still work with web-server mode:

```bash
# Hot reload
kill -USR1 $(cat /tmp/flutter.pid)

# Hot restart
kill -USR2 $(cat /tmp/flutter.pid)
```

After sending the signal, **refresh the MCP Chrome page** to see the changes (the web server recompiles, but the browser needs to reload).

### Quick Setup for MCP

```bash
# Terminal 1: Start Flutter web server
flutter run -d web-server --web-port=61060 --pid-file=/tmp/flutter.pid

# Then use Chrome DevTools MCP to navigate to http://localhost:61060
# Hot reload with: kill -USR1 $(cat /tmp/flutter.pid)
```

**Note:** Unlike `-d chrome` mode where hot reload updates instantly, with web-server + MCP you may need to refresh the browser after triggering reload.

## Multi-Device Auto Reload

Run multiple devices simultaneously with auto-reload for all:

```bash
# Terminal 1: iOS Simulator
flutter run -d iPhone --pid-file=/tmp/flutter-ios.pid

# Terminal 2: Android Emulator
flutter run -d emulator-5554 --pid-file=/tmp/flutter-android.pid

# Terminal 3: Chrome
flutter run -d chrome --pid-file=/tmp/flutter-web.pid

# Terminal 4: Watcher (reloads ALL devices)
fswatch -o lib/ | xargs -n1 -I{} sh -c 'kill -USR1 $(cat /tmp/flutter-ios.pid) $(cat /tmp/flutter-android.pid) $(cat /tmp/flutter-web.pid) 2>/dev/null'
```

## VS Code Setup

VS Code with the Flutter extension supports auto hot reload natively:

1. Open Settings (Cmd+,)
2. Search "Flutter Hot Reload On Save"
3. Set to one of:
   - `manual` - Only on manual save (Cmd+S)
   - `all` - On manual save and autosave
   - `allDirty` - When file has unsaved changes
   - `manualDirty` - Manual save only if changes exist

Recommended setting for autosave users:
```json
{
  "dart.flutterHotReloadOnSave": "all"
}
```

## Android Studio / IntelliJ Setup

1. Open **Settings > Tools > Actions on Save**
2. Enable "Save files if IDE is idle for X seconds" (recommend 2 seconds)
3. Open **Settings > Languages & Frameworks > Flutter**
4. Check "Perform hot reload on save"

## Convenience Script

Use the bundled script for easy setup:

```bash
# From skill directory
~/.claude/skills/flutter-auto-reload/scripts/flutter-watch.sh -d chrome
~/.claude/skills/flutter-auto-reload/scripts/flutter-watch.sh -d iPhone
```

## Troubleshooting

### Hot Reload Not Triggering

1. Verify PID file exists: `cat /tmp/flutter.pid`
2. Verify process is running: `ps -p $(cat /tmp/flutter.pid)`
3. Check file watcher is running and watching correct directory
4. Ensure changes are in `lib/` directory (not test/ or other)

### Hot Reload vs Hot Restart

Some changes require hot restart (SIGUSR2) instead of reload:
- Changes to `main()` function
- Changes to global/static variables initialization
- Changes to native code
- Asset changes
- pubspec.yaml changes

### State Not Preserved

Hot reload preserves state, but if state is lost:
- Check for errors in console
- Ensure no syntax errors in changed files
- Try hot restart if reload fails silently

## Quick Reference

| Environment | Command |
|-------------|---------|
| Terminal + fswatch | `fswatch -o lib/ \| xargs -n1 -I{} kill -USR1 $(cat /tmp/flutter.pid)` |
| Terminal + entr | `find lib -name '*.dart' \| entr -p kill -USR1 $(cat /tmp/flutter.pid)` |
| flutter_hot_reload | `flutter_hot_reload -d <device>` |
| Web experimental | `flutter run -d chrome --web-experimental-hot-reload` |
| VS Code | Set `dart.flutterHotReloadOnSave` to `all` |
| Android Studio | Enable in Settings > Flutter > Hot reload on save |

## Resources

- [Flutter Hot Reload Documentation](https://docs.flutter.dev/tools/hot-reload)
- [flutter_hot_reload Package](https://pub.dev/packages/flutter_hot_reload)
- [Flutter Auto-Reload for Terminal Workflows](https://paddo.dev/blog/flutter-auto-reload-cli-tools/)
