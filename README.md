# CodexQuotaTouchBar

[![macOS](https://img.shields.io/badge/macOS-13%2B-black)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10-orange)](https://www.swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

CodexQuotaTouchBar is a small macOS AppKit menu bar app that displays the
remaining local Codex 5-hour and weekly quota. It also supplies a native
`NSTouchBar` view for the focused app window and a BetterTouchTool-compatible
CLI fallback.

The app does not scrape web pages and does not depend on CodexBar. It starts the
local Codex `app-server`, speaks newline-delimited JSON-RPC over stdio, and calls
`account/rateLimits/read`.

## Requirements

- macOS 13 or later
- Swift 5.10 or later
- A local Codex CLI or Codex.app installation
- A Codex login for quota data
- Xcode is optional; Command Line Tools are enough for `swift build`

## Codex Binary Resolution

`CodexBinaryResolver` follows this order:

1. `which codex` semantics, first inspecting the inherited `PATH`
2. `/opt/homebrew/bin/codex`
3. `/usr/local/bin/codex`
4. `/Applications/Codex.app/Contents/Resources/codex`

The client first starts:

```sh
codex -s read-only -a untrusted app-server --listen stdio://
```

If that Codex version reports that `--listen` is unsupported, it retries:

```sh
codex -s read-only -a untrusted app-server
```

It sends `initialize`, the `initialized` notification, then
`account/rateLimits/read`. Each JSON message ends with a newline. Initialize has
an 8-second timeout and the quota request has a 5-second timeout. A timeout
terminates the child process and preserves the last successful UI snapshot.

## Build

Clone the repository:

```sh
git clone https://github.com/AnsonJIang-Pku/CodexQuota.git
cd CodexQuota
```

Debug build and tests:

```sh
swift build
swift test
```

If `xcode-select` points at an older Command Line Tools installation while
Xcode is installed, either select Xcode globally or set it for one command:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
# or:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift build
```

Release build, including the BetterTouchTool CLI:

```sh
swift build -c release
```

You can also open `Package.swift` in Xcode and select the
`CodexQuotaTouchBar` executable scheme. A full Xcode installation is required
for Xcode builds; Apple Command Line Tools alone can still use Swift Package
Manager.

## Run

Create a standard background menu bar application bundle:

```sh
./scripts/package-app.sh
open .build/release/CodexQuotaTouchBar.app
```

Using `open` launches the app independently of the Terminal session. Closing
the Terminal or changing the focused window does not quit it. Quit it through
the menu bar item's **Quit** command.

Running the raw `.build/release/CodexQuotaTouchBar` executable is intended for
development. That process remains associated with the Terminal that launched
it and will stop if it receives `Ctrl-C`, the shell exits, or the Terminal
session is closed.

The app uses accessory activation policy and `LSUIElement`, so its main UI is
the compact `Codex 72·41` menu bar item. The two values are the remaining 5-hour
and weekly percentages. It refreshes immediately, every 60 seconds, after wake,
and through **Refresh Now**. New data replaces old data only after a successful
response. Errors remain visible in the menu without clearing the previous
snapshot.

To launch it automatically after login:

1. Open **System Settings > General > Login Items**.
2. Click `+` under **Open at Login**.
3. Select `.build/release/CodexQuotaTouchBar.app`.

For a stable location, move the generated app to `/Applications` or
`~/Applications` before adding it to Login Items.

Use **Open Codex** to launch `/Applications/Codex.app`. Use
**Show Touch Bar Window** and focus that window to activate the native Touch Bar
item.

## Test app-server

Check binary discovery:

```sh
which codex
codex --version
codex app-server --help
```

Run the quiet application CLI:

```sh
swift run codex-quota-cli
```

Expected success shape:

```text
Codex 72·41
```

All failures produce:

```text
Codex --
```

For a raw protocol probe:

```sh
printf '%s\n%s\n%s\n' \
  '{"id":1,"method":"initialize","params":{"clientInfo":{"name":"CodexQuotaTouchBar","version":"0.1.0"}}}' \
  '{"method":"initialized","params":{}}' \
  '{"id":2,"method":"account/rateLimits/read","params":{}}' \
  | codex -s read-only -a untrusted app-server --listen stdio://
```

The app ignores unrelated notifications and matches responses by numeric `id`.
Do not run this probe in an environment that prevents Codex from accessing its
state under `~/.codex`.

## Native Touch Bar Limitation

Public AppKit `NSTouchBar` content belongs to the active responder chain.
Therefore it normally appears only while CodexQuotaTouchBar owns the focused
window. macOS provides no public API for a third-party app to keep a native
Touch Bar item globally visible. This project deliberately does not use private
Touch Bar APIs.

For always-available presentation, use the BetterTouchTool script below.

## BetterTouchTool

Build the release CLI first:

```sh
swift build -c release --product codex-quota-cli
```

Then in BetterTouchTool:

1. Add a Touch Bar Widget.
2. Choose **Shell Script / Run Script**.
3. Enter the absolute path to `scripts/codex-quota-btt.sh`.
4. Set the refresh interval to 60 seconds.

The script does not open windows, suppresses stderr, and prints one line. Its
RPC time budget is under 5 seconds. If the release CLI has not been built or a
request fails, it prints `Cdx --`.

Direct script test:

```sh
./scripts/codex-quota-btt.sh
```

## Troubleshooting

**Codex not found**

Run `which codex`. If it is absent, install Codex CLI or Codex.app. GUI apps
often inherit a smaller `PATH`, so the resolver also checks the three fixed
fallback paths listed above.

**Codex not logged in**

Run `codex login`, complete authentication, then choose **Refresh Now**.
Authentication errors are shown in the menu and do not erase old quota data.

**app-server timeout**

Run `codex app-server --help`, then use the raw probe above. Check whether
Codex can read and update its local state under `~/.codex`. The client kills and
cleans up the child process after timeout.

**Permission denied or readonly database**

Codex itself needs normal access to its state directory. Run the app as your
logged-in user and do not place `~/.codex` behind a read-only sandbox.

**No Touch Bar shown**

Choose **Show Touch Bar Window** and focus it. Confirm the Mac has a Touch Bar
or another compatible Touch Bar display. For global display, configure
BetterTouchTool.

**One quota window is missing**

The app-server schema may omit `primary` or `secondary`. Parsing is defensive:
the available window remains visible and the missing one displays `--`.

## Privacy

- The app calls only the local Codex `app-server`.
- It does not upload quota data to third-party services.
- It does not read, save, or copy account tokens.
- It keeps only the latest successful quota snapshot in memory.
- It writes no quota history to disk.

## Developer

HoshinoJiang

## License

CodexQuotaTouchBar is available under the [MIT License](LICENSE).
