**Callido Touch** adds touch screen and pen support to macOS: tap to click, drag, long press or two-finger tap for a right click, two-finger scrolling with momentum, pen input with pressure and tilt, and a pop-up keyboard for text fields. It is a small menu bar app; no driver or system extension is needed.

## What's new in 1.0.0

The first release under the Callido name (previously developed as OpenTouch).

- **New name, new look.** Callido Touch has its own icon, a disk image with the app icon, and an About window.
- **Setup window.** On first start, and whenever a permission is missing, a window shows the state of Input Monitoring and Accessibility, opens the right page in System Settings, lists the connected touch screens and pens, and restarts the app when a new permission needs it. Always available under **menu bar icon → Setup…**.
- **Permissions survive updates.** Releases are signed with a stable Callido Touch certificate, so macOS no longer forgets the Accessibility permission when you install a newer version.
- **Signed releases.** Every release carries `SHA256SUMS` and an Ed25519 signature over it (`SHA256SUMS.sig`). See "Verify a download" in the README.
- One universal app for Apple silicon and Intel Macs.

## Download

| File | What |
| --- | --- |
| `CallidoTouch.dmg` | Disk image: open it and drag Callido Touch to Applications |
| `CallidoTouch.zip` | The same app as a zip |
| `SHA256SUMS`, `SHA256SUMS.sig` | Checksums and their signature |

## Install and first start

1. Open the `.dmg` and drag **Callido Touch** to Applications.
2. Open the app. It is not notarized by Apple, so macOS blocks the first start: click **Done**, open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**, then confirm.
3. Follow the Setup window: allow **Input Monitoring** and **Accessibility**, then click **Restart Now**.

Coming from OpenTouch? Quit and delete `OpenTouch.app` first, and remove its entries under Input Monitoring and Accessibility; Callido Touch is a new app to macOS and asks again.

## Notice

Not affiliated with any hardware maker. Product names are trademarks of their owners and are used only to describe compatibility. MIT licensed.
