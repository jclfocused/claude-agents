# Run App Command

Build and run a mobile application on iOS simulator or Android emulator, automatically detecting the project type.

## Usage

```bash
/runApp [options]
```

## Options

- **--device** (optional) - Specify target device name or ID (e.g., "iPhone 16", "Pixel_6_API_33")
- **--clean** (optional) - Clean build before running
- **--release** (optional) - Build in release mode (default: debug)

## Command Overview

This command automatically:
1. **Commits any pending changes** using @/Users/justinclapperton/.claude/commands/commit.md
2. Detects whether the project is iOS or Android
3. Finds the appropriate workspace/project files
4. Builds the application
5. Installs and runs it on the appropriate simulator/emulator
6. For iOS: Kills any existing instance before launching

**IMPORTANT: Always commits first to ensure clean builds with latest changes**

## Detection Logic

### iOS Project Detection
- Looks for `*.xcworkspace` or `*.xcodeproj` files
- Prioritizes workspaces over projects
- Identifies Swift packages by `Package.swift`
- **Detects Tuist projects** by presence of `Project.swift` or `Tuist/` directory

### Android Project Detection
- Looks for `build.gradle` or `build.gradle.kts`
- Checks for `AndroidManifest.xml`
- Verifies `gradlew` executable exists

## iOS Build and Run Process

### 0. Tuist Project Setup (if detected)
```
IMPORTANT: For Tuist projects, generate Xcode project first!
1. Check for Project.swift or Tuist/ directory
2. If found, run: tuist generate
3. This creates the .xcworkspace and .xcodeproj files
4. Then proceed with normal iOS workflow
```

### 1. Project Discovery
```
Use mcp__XcodeBuildMCP__discover_projs to find:
- Workspace files (*.xcworkspace)
- Project files (*.xcodeproj)
- Swift packages (Package.swift)
Note: For Tuist projects, these files exist after running tuist generate
```

### 2. Scheme Selection
```
Use mcp__XcodeBuildMCP__list_schems_ws or list_schems_proj to:
- List available schemes
- Select appropriate scheme (usually matches project name)
```

### 3. Simulator Setup
```
Use mcp__XcodeBuildMCP__list_sims to:
- Find available simulators
- Select target device (default: latest iPhone)
- Boot simulator if needed with boot_sim
```

### 4. Build Process
```
Use appropriate build command:
- build_sim_name_ws for workspace + simulator name
- build_sim_id_ws for workspace + simulator UUID
- Add --clean flag support via clean_ws first
```

### 5. Installation and Launch
```
CRITICAL: Kill existing app first!
1. Get app bundle path with get_sim_app_path_*
2. Extract bundle ID with get_app_bundle_id
3. Stop existing app with stop_app_sim
4. Install new build with install_app_sim
5. Launch app with launch_app_sim
```

### Important iOS Instructions

**ALWAYS follow these steps in order:**

1. **Read ALL tool responses** - They provide critical information for next steps
2. **Kill existing app instances** before installing new builds
3. **Use simulator UUIDs** when available for reliability
4. **Check build outputs** for errors before proceeding
5. **Verify simulator is booted** before installing

## Android Build and Run Process

### 1. Environment Verification
```bash
# Check for Android SDK
echo $ANDROID_HOME
# Check for required tools
which adb
which emulator
```

### 2. Build Application
```bash
# Clean if requested
./gradlew clean

# Build debug APK
./gradlew assembleDebug

# Or release APK
./gradlew assembleRelease
```

### 3. Emulator Management
```bash
# List available AVDs
emulator -list-avds

# Start emulator if not running
adb devices | grep emulator || emulator -avd [AVD_NAME] &

# Wait for emulator
adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done;'
```

### 4. Installation and Launch
```bash
# Get package name from manifest or build.gradle
PACKAGE_NAME=$(grep applicationId app/build.gradle | awk '{print $2}' | tr -d '"')

# Kill existing app
adb shell am force-stop $PACKAGE_NAME

# Install APK
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch app
adb shell am start -n $PACKAGE_NAME/.MainActivity
```

## Error Handling

### iOS Common Issues

1. **No workspace/project found**
   - Check if it's a Tuist project (look for Project.swift)
   - Run `tuist generate` if Tuist project detected
   - Check current directory
   - Look in subdirectories
   - Ask user for project location

2. **Simulator not available**
   - List available simulators
   - Suggest downloading simulator
   - Use different device

3. **Build failures**
   - Check scheme exists
   - Verify provisioning profiles
   - Clean and rebuild

4. **App won't launch**
   - Ensure simulator is booted
   - Check bundle ID is correct
   - Verify app was installed

### Android Common Issues

1. **Gradle not found**
   - Check for gradlew executable
   - Verify Android project structure
   - Install gradle if needed

2. **No emulator running**
   - List available AVDs
   - Start default emulator
   - Create AVD if none exist

3. **Build failures**
   - Check Android SDK setup
   - Verify dependencies
   - Clean and rebuild

4. **ADB connection issues**
   - Restart ADB server
   - Check device authorization
   - Verify USB debugging

## Example Usage

```bash
# Run on default device
/runApp

# Run on specific iOS device
/runApp --device "iPhone 16"

# Run on specific Android emulator
/runApp --device "Pixel_6_API_33"

# Clean build and run
/runApp --clean

# Release build
/runApp --release --clean
```

## Quality Checks

Before considering the app successfully running:

1. **Build Success**
   - No compilation errors
   - All dependencies resolved
   - APK/App bundle created

2. **Installation Success**
   - App installed without errors
   - Previous version removed/updated
   - Permissions granted

3. **Launch Success**
   - App starts without crashing
   - Main screen appears
   - No immediate errors

4. **Visual Verification**
   - For iOS: Use screenshot tool to verify
   - For Android: Check logcat for crashes
   - Confirm expected UI appears

## Integration Notes

- Works from any directory within the project
- Automatically finds project root
- **Handles Tuist projects** by running `tuist generate` first
- Preserves existing simulator/emulator state
- Supports multiple devices/emulators
- Handles both debug and release builds

## Key Reminders

### For iOS
- **Check for Tuist projects** and run `tuist generate` first
- **ALWAYS kill existing app** before installing
- **Read tool responses** for critical information
- **Use MCP tools** exclusively, not raw commands
- **Follow the exact sequence** of steps
- **Verify each step** before proceeding

### For Android
- **Check environment setup** first
- **Ensure emulator is ready** before installing
- **Use package name** from build files
- **Monitor logcat** for errors
- **Clean builds** when switching modes

## Troubleshooting

If the command fails:

1. **Verify project type** - Check detection worked correctly
2. **List available devices** - Ensure target exists
3. **Check build output** - Look for compilation errors
4. **Verify installation** - Check device storage/permissions
5. **Monitor logs** - Use appropriate logging tools
6. **Try clean build** - Remove derived data/build folders

Remember: This command handles the complexity of mobile development toolchains. Always read output carefully and follow the specific instructions for each platform.