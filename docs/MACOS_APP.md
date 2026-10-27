# One-click macOS window

The local macOS app opens Lightmail in its own window. It runs the same loopback-only Python service and uses the existing private `.local/v2-live/` data directory. Opening the window does not connect Gmail, scan messages or submit an unsubscribe request.

## Build and open

First create the project environment using [the v2 rebuild instructions](V2_REBUILD.md). On a Mac with the Swift compiler available, run this from the project root:

```sh
/bin/zsh scripts/build-macos-app.sh
```

Then open `dist/Lightmail.app` in Finder. Keep the app inside this project's `dist/` folder: this is a local wrapper, not a standalone installer. You can add the app to the Dock, but do not move it to Applications because it needs the adjacent project files and environment. The app has no background login item.

The normal dashboard stays inside the Lightmail window. Google authorization and manually opened Gmail messages may still use your regular browser. If the same new-version local service is already running, another click reopens its window instead of starting another scan or server. Closing the window quits a service started by this app; when the app attached to a service started elsewhere, quitting leaves that service alone. An older running version may not expose the new instance address; stop it normally before trying the app.

An unexpected server exit produces a Restart choice. Restart restores saved local state but does not automatically reconnect, scan or resend an uncertain request. Keep private data and credentials in the project; the generated app contains neither.

This build is not Developer ID signed, notarized or packaged for distribution. It has no installer or system service. macOS may apply its normal security checks; the build script does not change security settings or bypass a prompt. On 2026-10-26 a copy of the project with an empty data directory was built and opened with macOS `open` on the maintainer's Mac: the window showed the dashboard, a second open reused the same service, Quit stopped the service and cleared the lock, and killing the service showed the Restart choice. Clicking Restart and the first-launch Gatekeeper prompt for a downloaded copy were not exercised.
