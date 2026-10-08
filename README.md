# Earshot

**Record system audio with macOS Screenshot (⌘⇧5). No audio driver needed.**

The built-in Screenshot app can only record from a microphone. Earshot adds an input device called **System Audio** that carries whatever your Mac is playing, so you can pick it as the "microphone" and your screen recordings include desktop audio.

- No virtual audio driver (BlackHole, Soundflower), no Multi-Output Device, no sudo
- Your output stays untouched: volume keys, AirPods and speakers all keep working
- Set and forget: runs at login, restarts itself if anything goes wrong
- ~100 lines of Swift, no dependencies

## Requirements

- macOS 14.2 or later (tested on macOS 26 Tahoe)
- Xcode Command Line Tools (`xcode-select --install`)

## Install

```sh
git clone https://github.com/Arrow7000/earshot.git
cd earshot
./install.sh
```

macOS will ask whether Earshot may record system audio. Click **Allow**.

Then press **⌘⇧5**, open **Options**, and under **Microphone** pick **System Audio**. Screenshot remembers the choice, so you only do this once.

## Uninstall

```sh
./uninstall.sh
```

## How it works

macOS 14.2 added [Core Audio process taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps), an official API for capturing the system audio mix. Apps normally use a tap privately, inside their own process. Earshot instead wraps a global tap in a **public aggregate device**, which makes it visible to every app as an ordinary input device.

Earshot runs as a LaunchAgent. It holds the device open and otherwise does nothing: no audio is processed unless something is recording from the device.

The device contains only the tap, so it's input-only: it never shows up as an output, and it keeps working as you switch between speakers, headphones and AirPods.

## Caveats

- **Other apps need System Audio Recording permission.** Screenshot is exempt (at least on macOS 26), but any other app reading System Audio must itself be allowed to record system audio. Apps that support this (e.g. Chrome) will ask the first time; just click Allow. Apps that don't (e.g. command-line tools like ffmpeg) silently get silence: add them, or the terminal running them, under System Settings → Privacy & Security → Screen & System Audio Recording → **System Audio Recording Only** (+). Note that the screen-recording list above it doesn't count.
- **This relies on observed behavior.** Screenshot being able to read the device without its own permission isn't documented by Apple. A future macOS update could change it.
- **System audio only.** Picking System Audio means your mic isn't recorded.
- **Rebuilding re-prompts.** Earshot is ad-hoc signed, so macOS treats each rebuild as a new app and asks for permission again.

## Troubleshooting

- **Device missing?** Check `~/Library/Logs/Earshot.log` and `launchctl print gui/$(id -u)/arrow7000.earshot`. Apps that were open while Earshot (re)started may need relaunching to see the device.
- **Recording is silent?** Make sure both Earshot *and the app you're recording with* are allowed under System Settings → Privacy & Security → Screen & System Audio Recording → System Audio Recording Only. To get the prompt again, run `tccutil reset AudioCapture arrow7000.earshot` then `./install.sh`.

## Prior art

- [BlackHole](https://github.com/ExistentialAudio/BlackHole): virtual audio driver; the classic way to do this, with more setup.
- [AudioCap](https://github.com/insidegui/AudioCap): sample code for recording with process taps from within an app.
- [audiotee](https://github.com/makeusabrew/audiotee): CLI that streams system audio to stdout using process taps.

## License

MIT
