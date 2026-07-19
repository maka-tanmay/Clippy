# Clippy

**A clipboard manager for macOS that remembers everything — and knows when to forget.**

Clippy keeps a searchable history of everything you copy and lets you navigate, search, and paste it without leaving the keyboard. It is a fork of the excellent [Maccy](https://github.com/p0deje/Maccy) by Alexey Rodionov, extended into a full capture-and-privacy toolkit.

Works on macOS Sonoma 14 or higher.

## Why Clippy

Everything Maccy does today — lightweight, keyboard-first, native SwiftUI, fully offline, open source — plus a roadmap of features no lightweight clipboard manager ships:

| Pillar | What it adds | Status |
|---|---|---|
| **Smart Paste** | Right-click → *Paste As* (UPPERCASE, lowercase, trimmed, tracking params stripped, pretty JSON), per-app plain-text rules (Preferences → Paste), global snippet shortcuts for pinned items (Preferences → Pins), paste stack | ✅ shipped |
| **Intelligence-lite** | `type:` search filters (`type:url invoice`, `type:image`, `type:color`, `type:email`, `type:phone`, `type:file`), "pin this?" suggestion after 5 copies | ✅ shipped |
| **Capture Suite** | Screenshot-to-clipboard (hit the capture hotkey, drag a region, done) — the shot lands in history and is *searchable by the text inside it* via accurate on-device OCR | ✅ shipped |
| **Privacy Vault** | Secrets auto-shred: copied API keys, tokens, and private keys are detected and wiped from history *and* the clipboard after 2 minutes; custom regex expire rules for OTPs etc. (Preferences → Storage) | ✅ shipped |
| **AI Actions** | Right-click → Summarize / Explain Code, fully on-device via Apple Intelligence (macOS 26+, hidden elsewhere) | ✅ shipped |
| **Later** | Quick annotate for captures, encrypted-at-rest history, E2E-encrypted CloudKit sync, translation | 🔜 planned |

Everything runs on-device. No network calls, no analytics, no accounts.

## Install

No binary releases yet — build from source:

```sh
git clone https://github.com/maka-tanmay/Clippy
cd Clippy
xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Release build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

Notarized downloads and `brew install maka-tanmay/tap/clippy` are coming with the first release (see [RELEASING.md](RELEASING.md)).

## Usage

1. <kbd>⇧</kbd><kbd>⌘</kbd><kbd>C</kbd> opens the popup (or click the menu bar icon).
2. Type to search — exact, fuzzy, regex, or mixed matching. Prefix with `type:url`, `type:image`, `type:color`, `type:email`, `type:phone`, `type:file`, or `type:text` to filter by content kind (e.g. `type:url invoice`).
3. <kbd>Enter</kbd> (or <kbd>⌘</kbd>+`n`) copies the selected item; <kbd>⌥</kbd><kbd>Enter</kbd> pastes it directly; <kbd>⌥</kbd><kbd>⇧</kbd><kbd>Enter</kbd> pastes without formatting.
4. <kbd>⌥</kbd><kbd>P</kbd> pins/unpins an item; <kbd>⌥</kbd><kbd>⌫</kbd> deletes one. In Preferences → Pins you can give a pinned item an alias, edit its content, and record a **global shortcut** that pastes it from anywhere — instant snippets.
5. Right-click any text item → **Paste As** to paste it transformed: UPPERCASE, lowercase, trimmed, with URL tracking parameters stripped, or as pretty-printed JSON.
6. <kbd>⇧</kbd><kbd>⌘</kbd><kbd>2</kbd> captures a screen region straight to your clipboard (grant Screen Recording on first use). Search its text later with `type:image`.
7. <kbd>⌥</kbd><kbd>⌘</kbd><kbd>⌫</kbd> clears unpinned history; add <kbd>⇧</kbd> to clear everything.
8. <kbd>⌥</kbd>-click the menu icon to pause Clippy; <kbd>⌥</kbd><kbd>⇧</kbd>-click to ignore only the next copy.
9. <kbd>⌘</kbd><kbd>,</kbd> opens Preferences.

Pasting directly requires adding Clippy to System Settings → Privacy & Security → Accessibility (you'll be prompted).

## Advanced

### Ignored content

Pasteboard entries marked transient/concealed/auto-generated (password managers like 1Password, KeeWeb, TypeIt4Me) are ignored by default. You can also ignore specific apps, custom pasteboard types, and content matching regular expressions in Preferences → Ignore. To find an app's custom types, use [Pasteboard-Viewer](https://github.com/sindresorhus/Pasteboard-Viewer).

To ignore copies from [Universal Clipboard](https://support.apple.com/en-us/102430), add `com.apple.is-remote-clipboard` under Preferences → Ignore → Pasteboard Types.

### Defaults

Clippy stores its settings under the `com.tanmaymaka.clippy` defaults domain:

```sh
defaults write com.tanmaymaka.clippy ignoreEvents true          # ignore all copies (scripted workflows)
defaults write com.tanmaymaka.clippy clipboardCheckInterval 0.1 # poll every 100 ms (default 0.5)
defaults write com.tanmaymaka.clippy showFooter 1               # restore a hidden footer
```

## Development

```sh
xcodebuild test -project Maccy.xcodeproj -scheme Maccy -destination 'platform=macOS' \
  -skip-testing:MaccyUITests CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

The Xcode target, module, and source directory keep the upstream `Maccy` name on purpose — it keeps merges from upstream conflict-free. Only the product (`Clippy.app`), bundle id, and user-facing strings are rebranded.

## Attribution & License

Clippy is a fork of [Maccy](https://github.com/p0deje/Maccy), © Alexey Rodionov, and stands on years of upstream work — thank you. Both projects are released under the [MIT License](LICENSE).
