<p align="center">
  <img src="Resources/AppIcon.png" width="160" alt="MediaPrimeKey app icon">
</p>

<h1 align="center">MediaPrimeKey — Force Mac Media Keys to Spotify or Apple Music</h1>

<p align="center">
  A free, open-source macOS app that makes Spotify or Apple Music the preferred target for your keyboard media keys.
  <br><br>
  <a href="https://github.com/salvatorevolpework/MediaPrimeKey/releases/latest/download/MediaPrimeKey.zip"><strong>Download MediaPrimeKey</strong></a>
</p>

## Make Spotify the default for your Mac media keys

Does the Play key open Apple Music, pause a browser video or control the wrong app? MediaPrimeKey locks Play/Pause, Next and Previous to the music player you choose. Select Spotify or Apple Music once, and the app handles your media keys in the background.

If Spotify is closed, pressing Play opens Spotify and starts playback automatically. This makes MediaPrimeKey a simple replacement for older media-key forwarders on modern macOS versions.

## Features

- Forces Play/Pause, Next and Previous to Spotify or Apple Music.
- Stops Apple Music, browsers and other media apps from hijacking those keys.
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

## Frequently asked questions

### How do I make Spotify the default app for media keys on a Mac?

Install MediaPrimeKey, choose Spotify from its menu bar menu and enable media-key control. Your Mac's Play/Pause, Next and Previous keys will then be sent directly to Spotify, even when another app is active.

### Can I stop Apple Music from opening when I press Play?

Yes. Choose Spotify as your player in MediaPrimeKey. When Spotify is not running, the Play key opens Spotify instead of Apple Music.

### Does it work when Spotify is in the background or closed?

Yes. MediaPrimeKey controls Spotify while it is in the background and launches it when needed. It can also start automatically at login and run without a visible menu bar icon.

### Which Mac media keys are supported?

Play/Pause, Next Track and Previous Track are supported. Volume, mute and brightness keys keep their normal macOS behavior.

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
