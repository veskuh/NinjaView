# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.1] - 2026-06-14

### Fixed
- Fixed directory scanning performance latency by skipping EXIF extraction on video files (preventing massive video files from being read into memory).

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

[unreleased]: https://github.com/veskuh/NinjaView/compare/v0.6.1...HEAD
[0.6.1]: https://github.com/veskuh/NinjaView/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/veskuh/NinjaView/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/veskuh/NinjaView/releases/tag/v0.5.0
