<p align="center">
  <img src="Resources/AppIcon.png" width="160" alt="MediaPrimeKey app icon">
</p>

<h1 align="center">MediaPrimeKey</h1>

<p align="center">
  A tiny macOS utility that routes your media keys to Spotify or Apple Music.
  <br><br>
  <a href="https://github.com/salvatorevolpework/MediaPrimeKey/releases/latest/download/MediaPrimeKey.zip"><strong>Download MediaPrimeKey</strong></a>
</p>

## What it does

- Makes Spotify or Apple Music the preferred target for Play/Pause, Next and Previous.
- Opens the selected player automatically when it is not running.
- Runs quietly in the background.
- Can hide its menu bar icon and launch automatically when you sign in.
- Uses local macOS automation only. No Spotify token, account login or network service.

## Compatibility

- **macOS 13 Ventura or later**
- **Apple Silicon and Intel Macs** — the download is a universal app
- Spotify for Mac and/or the built-in Apple Music app

## Install

1. [Download the latest release](https://github.com/salvatorevolpework/MediaPrimeKey/releases/latest/download/MediaPrimeKey.zip).
2. Unzip it and move `MediaPrimeKey.app` to your **Applications** folder.
3. Open MediaPrimeKey.
4. Allow it in **System Settings → Privacy & Security → Accessibility**.
5. Select Spotify or Apple Music from the menu bar icon and allow **Automation** when macOS asks.

MediaPrimeKey is currently ad-hoc signed and is **not notarized by Apple**. On first launch, macOS may block it. Try opening the app once, then go to **System Settings → Privacy & Security**, scroll to Security and click **Open Anyway**. See [Apple's official instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).

If you previously installed the old `MediaSpot.app`, remove it from Applications and from **System Settings → General → Login Items** first. Running both apps at once can make media-key handling unreliable.

## Background mode

Enable **Launch at Login**, then choose **Hide Menu Bar Icon**. MediaPrimeKey keeps running invisibly. Open the app again from Applications whenever you want the menu bar icon back.

## Build from source

Requirements: macOS 13 or later and Apple Command Line Tools.

```sh
./build.sh
```

The universal app and zip archive are created in `dist/`.

## Privacy

MediaPrimeKey has no analytics, tracking or network code. It listens only for the three playback media keys and sends local Apple Events to the selected music player. Volume, mute and brightness keys are never intercepted.

## License

MediaPrimeKey is available under the [MIT License](LICENSE).
