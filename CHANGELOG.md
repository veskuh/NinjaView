# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.8.0] - 2026-07-18

### Added
- Added sortable column headers (Name, Dimensions, Date, Size) in list mode with ascending/descending sorting toggle support and column resizing.
- Added persistent storage for list view column widths in application settings.
- Added row-height zoom support in list mode, allowing zoom actions, toolbar slider, and Ctrl+wheel to adjust list row height (24-48px) and scale thumbnails.
- Added Finder-style keyboard navigation in list mode (Right arrow key enters selected folder, Left arrow key navigates back to parent folder).

### Fixed
- Fixed vertical alignment of metadata texts inside the list view row delegates to be centered correctly.
- Fixed a segmentation fault crash in test execution cleanup by correcting the lifecycle of the engine-owned C++ image provider object.

## [0.7.1] - 2026-06-20

### Fixed
- Fixed Linux CI release packaging builds by upgrading target Docker containers to Ubuntu 25.04 and Fedora 41 to provide Qt 6.8+ (since Ubuntu 24.04 only packages Qt 6.4.2, which lacks required APIs like `QTimeZone::fromSecondsAheadOfUtc`).
- Standardized minimum Qt version requirement to 6.8.0 across the project.

## [0.7.0] - 2026-06-20

### Added
- Added multi-file selection support in the gallery grid (`Cmd/Ctrl + Click`, `Shift + Click`, `Cmd/Ctrl + A`), allowing batch operations such as copy, lossless rotation, move to trash, and shared tag management.
- Added "Show Only New" view filter (enabled on SD cards) to isolate and display only files not yet indexed in previous sessions.
- Added macOS-exclusive "Import to Photos" action (available in File and right-click context menus) to import the selection or current filtered gallery view into Apple Photos.
- Added "Quick Look" feature (`Space` key) to show or hide a high-resolution preview window overlay of the selected file.
- Added interactive User Guide and Keyboard Shortcuts dialogs to help users navigate and master application features.
- Isolated unit test database paths to avoid polluting/conflicting with the user's active database environment.
- Updated the Kaakao submodule to integrate the latest UI component updates.
- Added automatic filtering to ignore macOS system/development bundles, Xcode project directories, and Photos/Lightroom libraries (such as `.app`, `.framework`, `.plugin`, `.bundle`, `.xcassets`, `.xcodeproj`, `.xcworkspace`, `.photoslibrary`, and others) from folder and image scans.
- Extended the scope bar header background and border continuously across the full window width, and aligned the custom media type filter control's background with it.
- Added a slight delay before fullscreen video autoplayback starts to allow the transition/fade-in animation to complete cleanly.
- Added key focus recovery on video player controls so that the Spacebar key consistently toggles play/pause.

### Fixed
- Fixed text visibility contrast for the custom segmented control in light theme by matching its active styling and text color with `KaakaoSegmentedControl`'s design tokens.
- Fixed Linux GStreamer thumbnail extraction pipeline crashes caused by command-line path parsing limitations, wrapping location parameters in double quotes via idiomatic `QString::arg()`.
- Fixed directory scanning performance latency by skipping EXIF extraction on video files (preventing massive video files from being read into memory).
- Fixed GStreamer subprocess execution to verify if gst-launch-1.0 started successfully, failing fast instead of wasting CPU loops if missing.

## [0.6.0] - 2026-06-14

### Added
- Native support for video files (MP4 and MOV formats).
- Integrated fullscreen video playback with interactive play/pause controls.
- Smart fullscreen interactions:
  - Video autoplay when navigating with arrow keys.
  - Automatic cursor hiding during video playback inactivity.
- Dedicated "Pictures" and "Videos" library categories in the sidebar.
- Scope bar filtering support for video file formats.
- Pre-generated static MP4 test asset to streamline local and CI test execution.

### Fixed
- Fixed `tst_asyncimageprovider` test failures on CI by installing missing GStreamer packages on Linux.
- Fixed Linux video frame extraction by executing the `gst-launch-1.0` command parser through `sh -c`.

## [0.5.0] - 2026-05-17

### Added
- Integrated image preview memory caching.
- SD card volume monitoring to automatically clear the gallery and cache on unmount.
- Full EXIF metadata viewer support with UI text-eliding.
- Automatic image orientation handling via EXIF metadata.
- True fullscreen image preview mode with keyboard navigation.
- Persistent application window geometry state using Settings.
- Attributed attributions and upgraded imports to standard QML MenuBar.
- Touchpad scroll navigation support.
- BSD 3-Clause License.

### Fixed
- Fixed memory handling bugs during application shutdown.
- Resolved styling and qualified QML access warnings.

[unreleased]: https://github.com/veskuh/NinjaView/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/veskuh/NinjaView/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/veskuh/NinjaView/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/veskuh/NinjaView/compare/v0.6.1...v0.7.0
[0.6.1]: https://github.com/veskuh/NinjaView/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/veskuh/NinjaView/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/veskuh/NinjaView/releases/tag/v0.5.0
