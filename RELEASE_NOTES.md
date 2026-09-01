# MediaPrimeKey 1.2.1

This maintenance release improves Spotify cold-start playback.

- Fixes repeated Play/Pause presses cancelling each other while Spotify opens.
- Coalesces media-key presses during the cold-start window.
- Gives Spotify's playback service time to initialize.
- Safely replays the idempotent Play command when Spotify first launches.
- Universal build for Apple Silicon and Intel Macs.
- Requires macOS 13 Ventura or later.

MediaPrimeKey is ad-hoc signed and not notarized by Apple. Follow the installation instructions in the README if macOS blocks the first launch.
