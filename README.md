# Pro Tools Report

A double-clickable macOS app that collects Pro Tools crash logs and detailed system info after a crash.

## What it collects

| File | Contents |
|------|----------|
| `00_summary.txt` | Quick overview: macOS version, uptime, crash count, Pro Tools version |
| `crash_logs/` | `.crash`, `.ips`, `.hang` files from `DiagnosticReports` mentioning Pro Tools/Avid (last 2h) |
| `avid_logs/` | Files from `~/Library/Logs/Avid` and Avid support directories modified in the last 2h |
| `system_log_protools.txt` | macOS unified log filtered for Pro Tools, ProTools, DAE, DigiLink processes (last 2h) |
| `system_info_full.txt` | Full `system_profiler` dump: hardware, audio, USB, Thunderbolt, PCIe, storage, displays, BT, network, extensions |
| `audio_plugins.txt` | Directory listing of all AU, VST, VST3, and AAX plugin folders |
| `running_processes.txt` | Snapshot of all running processes at collection time |
| `third_party_kexts.txt` | Loaded third-party kernel extensions (relevant for audio interface drivers) |

Report folders are saved to your **Desktop** as `ProToolsReport_YYYY-MM-DD_HH-MM-SS/`.

## Installation (on macOS)

1. Copy `ProToolsReport.app` to your Applications folder or Desktop.
2. **First launch only** — macOS will block it as "unidentified developer":
   - Right-click the app → **Open** → click **Open** in the dialog.
   - After that, you can double-click it normally.
3. Grant any permissions macOS prompts for (Full Disk Access helps for system log collection).

### Optional: Full Disk Access (recommended)

For complete log access:

1. System Settings → Privacy & Security → Full Disk Access
2. Click `+` and add `ProToolsReport.app`
3. Also add `Terminal.app` if the app is launched from Terminal during testing.

## Usage

After a Pro Tools crash, **double-click the app**. A dialog will appear while it collects data (up to ~60 seconds due to `system_profiler`). When done, the report folder opens automatically on your Desktop.

## Customising the time window

Edit `ProToolsReport.app/Contents/MacOS/ProToolsReport` and change:

```bash
HOURS=2
```

to however many hours back you want to search.

## File structure

```
ProToolsReport.app/
  Contents/
    Info.plist              # macOS bundle metadata
    MacOS/
      ProToolsReport        # The shell script (executable)
    Resources/              # Reserved for future icon etc.
```
