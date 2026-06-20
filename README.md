# NinjaView

NinjaView is a simple C++/Qt6 image and video viewer designed for previewing files, tailored for workflows involving SD cards and digital cameras. It features a classic look built on the [Kaakao](https://github.com/veskuh/Kaakao) component set.

![Screenshot 2026-05](/assets/screenshot.png?raw=true)

## Features

- Asynchronous image and video frame decoding with caching for fast gallery browsing.
- Support for images and video formats (JPEG, WebP, MP4, and MOV).
- Separate "Pictures" and "Videos" sidebar library navigation.
- Category scope bar filters for both pictures and videos.
- "Show Only New" filter under the View menu (enabled on SD cards) to show only files not yet indexed in previous sessions.
- "Import to Photos" action (macOS only) available via File menu or right-click context menu to import the selection or current filtered view into Apple Photos.
- Automatic filtering to ignore macOS system/development bundles, Xcode project directories, and Photos/Lightroom libraries (such as `.app`, `.framework`, `.plugin`, `.bundle`, `.xcassets`, `.xcodeproj`, `.xcworkspace`, `.photoslibrary`, `.photolibrary`, `.aplibrary`, `.lrweb`) to keep the media gallery clean.
- Quick Look: Press `Space` to instantly toggle a high-resolution preview overlay of the selected image/video.
- Multi-File Selection: Select multiple files in the gallery grid using standard modifier keys (`Cmd/Ctrl + Click`, `Shift + Click`, or `Cmd/Ctrl + A`). Batch operations (Copy, Rotate, Trash, and Tagging) apply to the entire active selection.
- Double-click any file or press `Return` to enter fullscreen preview mode.
- Interactive video playback controls: play/pause button overlay, click-to-toggle play/pause.
- Smart fullscreen behavior:
  - Mouse cursor auto-hides during video playback inactivity and reappears on mouse movement.
  - Video autoplay when navigating between video files in fullscreen using arrow keys.
- Lossless JPEG rotation (modifies the EXIF orientation metadata on disk; falls back to session-only in-memory rotation on write-protected files such as camera SD cards).
- Full keyboard support:
  - **Navigation**: Arrow keys to cycle, `Space` for Quick Look, `Return` to enter fullscreen, `Escape` to exit fullscreen or clear selection, `F5` to refresh.
  - **Editing/Actions**: `Cmd/Ctrl + [` and `Cmd/Ctrl + ]` to rotate JPEGs (also supports `L` and `R` in fullscreen), `Delete`/`Backspace` to move to trash.
  - **File Operations**: `Cmd/Ctrl + C` to copy to clipboard, `Cmd/Ctrl + O` to open with default app, `Cmd/Ctrl + R` to reveal in Finder/File Manager.
  - **Zooming**: `Cmd/Ctrl + +` / `Cmd/Ctrl + -` to zoom in/out, `Cmd/Ctrl + 0` to reset.
  - **UI Controls**: `Cmd/Ctrl + I` to toggle the EXIF Info/Metadata panel, `Cmd/Ctrl + ,` to open Preferences.
- Classic Mac OS X inspired interface using custom QML components.
- C++17 and Qt6 for performance and stability.

## Getting Started

### Prerequisites

- Qt 6.4.2+ (with optional ImageFormats module for WebP support, and QtMultimedia module for video playback)
- CMake 3.16+
- C++17
- On Linux, GStreamer (specifically `gstreamer1.0-plugins-base`, `gstreamer1.0-plugins-good`, and `gstreamer1.0-libav`) is required for video decoding and thumbnail generation.

### Build Instructions

1.  Clone the repository with submodules:
    ```bash
    git clone --recursive git@github.com:veskuh/NinjaView.git
    cd NinjaView
    ```

2.  Configure and Build:
    ```bash
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j12
    ```

3.  Run the application:
    ```bash
    # On macOS:
    open build/src/NinjaView.app
    
    # On Linux:
    ./build/src/ninjaview
    ```

## Development

### Testing

The project includes both C++ unit tests and QML UI tests.

```bash
# Run all tests
ctest --test-dir build/tests --output-on-failure

# Run a self-diagnostic check
./build/src/ninjaview --selftest
```

### Project Structure

- `src/core/`: Backend logic and image discovery.
- `src/ui/`: C++ ViewModels and Image Providers.
- `src/qml/`: High-performance UI components.
- `tests/`: Comprehensive test suite.
- `Kaakao/`: The UI component library submodule.

## Packaging

NinjaView supports native standalone packaging for macOS and Linux.

### macOS
To generate the pruned standalone macOS `.app` bundle, run:
```bash
cmake --install build --prefix install_dir
```
This runs `macdeployqt`, removes unnecessary libraries, and signs the resulting bundle.

### Linux (.deb & .rpm)
NinjaView packages utilize the system's package-managed Qt 6. To package the application on Linux using CPack, run:
```bash
# Generate DEB (Ubuntu/Debian) or RPM (Fedora) packages
cpack --config build/CPackConfig.cmake -G DEB
cpack --config build/CPackConfig.cmake -G RPM
```

## CI/CD

NinjaView uses GitHub Actions for continuous integration.
- Pull Requests / Commits: Automatically builds and runs the test suite on both Ubuntu 24.04 and macOS 14 runners.
- Releases: Tagging a commit (with `v*`) automatically builds and publishes the release packages:
  - Zipped macOS standalone application (`NinjaView.app.zip`). *(Note: Pre-built macOS binaries are ad-hoc signed. If blocked by Gatekeeper, allow it in System Settings > Privacy & Security or run `xattr -cr /path/to/NinjaView.app`)*
  - Native Linux packages built inside Ubuntu 24.04 (`.deb`) and Fedora 40 (`.rpm`) Docker containers, dynamically linked against system Qt 6.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

