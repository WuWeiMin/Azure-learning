# Mermaid CLI Setup Guide
**Windows 11 · No Admin Rights Required**  
Install mmdc · Skip Chromium · Use Edge · Right-Click Context Menu

> **Note:** Throughout this guide, replace `%USERNAME%` with your actual Windows username (e.g. `E153773`). All paths use `%USERNAME%` as a placeholder.

---

## 1. Prerequisites

Confirm the following before starting:

- Node.js installed — verify with `node -v`
- npm available — verify with `npm -v`
- Microsoft Edge installed at the standard path:
  `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`
- No admin rights required for any step in this guide

---

## 2. Install Mermaid CLI (Skip Chromium Download)

Mermaid CLI uses Puppeteer internally, which normally downloads Chromium during installation. In corporate environments this often fails due to SSL certificate interception. We skip the download entirely and use Edge instead.

### 2.1 Set environment variable and install

Open Command Prompt and run:

```cmd
set PUPPETEER_SKIP_DOWNLOAD=true && npm install -g @mermaid-js/mermaid-cli
```

`PUPPETEER_SKIP_DOWNLOAD=true` tells Puppeteer to skip the Chromium download. This variable only affects the current CMD session.

### 2.2 Add npm global bin to PATH (if mmdc not found)

If `mmdc` is not recognised after installation:

```cmd
setx PATH "%PATH%;C:\Users\%USERNAME%\AppData\Roaming\npm"
```

> **Note:** Close and reopen CMD after running `setx` — the current window does not pick up the new PATH immediately.

### 2.3 Verify installation

```cmd
mmdc -h
```

If you see the mmdc help output, installation is successful.

---

## 3. Configure Puppeteer to Use Microsoft Edge

Since we skipped the Chromium download, we must tell Puppeteer to use Edge instead. We do this with two config files: a `.cjs` file for automatic detection, and a `.json` file for explicit use with mmdc scripts.

### 3.1 Create the .cjs config file (auto-detection)

```cmd
notepad C:\Users\%USERNAME%\.puppeteerrc.cjs
```

Paste this content (use straight double-quotes, not curly quotes):

```javascript
module.exports = {
  executablePath: "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
}
```

Save and close Notepad.

### 3.2 Create the JSON config file (explicit use with mmdc)

Create the tool folder first if it does not exist:

```cmd
mkdir C:\Users\%USERNAME%\mermaid-tool
```

Then create the JSON config:

```cmd
notepad C:\Users\%USERNAME%\mermaid-tool\puppeteer.json
```

Paste this content:

```json
{
  "executablePath": "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
}
```

### 3.3 Verify Edge path

If Edge is not at the standard path, find it with:

```cmd
where msedge
```

Replace the path in both config files with the output of this command. Single backslashes `\` become double backslashes `\\` inside the config files.

---

## 4. Test mmdc from Command Line

### 4.1 Basic conversion

Navigate to your .mmd file folder:

```cmd
cd C:\path\to\your\folder
```

Then convert:

```cmd
mmdc -i yourfile.mmd -o yourfile.png -b white -s 2 --puppeteerConfigFile "C:\Users\%USERNAME%\mermaid-tool\puppeteer.json"
```

### 4.2 Common parameters

| Parameter | Description |
|---|---|
| `-i file.mmd` | Input Mermaid diagram file |
| `-o file.png` | Output file (`.png` / `.svg` / `.pdf`) |
| `-b white` | White background (default is transparent) |
| `-s 2` | Scale factor — 2 produces a higher-resolution image |
| `-t dark` | Theme: `default` / `forest` / `dark` / `neutral` |
| `--puppeteerConfigFile path` | Path to the JSON config that points to Edge |

---

## 5. Set Up Right-Click Context Menu

Registers a "Convert to PNG" option in the Windows right-click menu for `.mmd` files. All registry entries go under `HKEY_CURRENT_USER` — no admin rights required.

### 5.1 Create the converter batch file

```cmd
notepad C:\Users\%USERNAME%\mermaid-tool\mmd-to-png.bat
```

Paste the following content. Replace `%USERNAME%` with your actual username:

```batch
@echo off
chcp 65001 >nul
set "MMDC=C:\Users\%USERNAME%\AppData\Roaming\npm\mmdc.cmd"
set "INPUT=%~1"
set "OUTPUT=%~dpn1.png"
echo ================================================
echo  Mermaid to PNG Converter
echo ================================================
echo Input : %INPUT%
echo Output: %OUTPUT%
echo.
call "%MMDC%" -i "%INPUT%" -o "%OUTPUT%" -b white -s 2 --puppeteerConfigFile "C:\Users\%USERNAME%\mermaid-tool\puppeteer.json"
if %errorlevel%==0 (
    echo.
    echo Conversion successful!
    echo File saved to: %OUTPUT%
) else (
    echo.
    echo Conversion FAILED!
)
```

> **Note:** Do NOT add a `pause` line at the end — the window closes automatically on completion.

### 5.2 Register the .mmd file type and context menu

Run each line individually in CMD:

```cmd
reg add "HKCU\Software\Classes\.mmd" /ve /d "mmdfile" /f
```

```cmd
reg add "HKCU\Software\Classes\.mmd" /v "Content Type" /d "text/plain" /f
```

```cmd
reg add "HKCU\Software\Classes\mmdfile" /ve /d "Mermaid Diagram" /f
```

```cmd
reg add "HKCU\Software\Classes\mmdfile\shell\Convert to PNG" /ve /d "Convert to PNG" /f
```

```cmd
reg add "HKCU\Software\Classes\mmdfile\shell\Convert to PNG" /v "Icon" /d "msedge.exe,0" /f
```

### 5.3 Register the command (critical step)

```cmd
reg add "HKCU\Software\Classes\mmdfile\shell\Convert to PNG\command" /ve /d "cmd /c \"\"C:\Users\%USERNAME%\mermaid-tool\mmd-to-png.bat\" \"%1\"\"" /f
```

> **Important:** The double outer quotes wrapping the entire command are required. Without them, Windows misparses the path when the file argument is passed.

### 5.4 Verify the registry entry

```cmd
reg query "HKCU\Software\Classes\mmdfile\shell\Convert to PNG\command"
```

The output should show:

```
cmd /c ""C:\Users\%USERNAME%\mermaid-tool\mmd-to-png.bat" "%1""
```

All quotes must be standard straight double-quotes. If you see curly/smart quotes, re-run the `reg add` command from a plain CMD window.

---

## 6. Usage

### 6.1 Convert via right-click

1. In File Explorer, navigate to your `.mmd` file
2. Hold **Shift** and right-click the file
3. Select **"Convert to PNG"** from the context menu
4. The PNG is generated in the same folder with the same filename

> **Windows 11 note:** Third-party context menu items are moved into "Show more options" on plain right-click. Use **Shift + Right-click** to access the full menu directly — no admin rights needed to change this behaviour.

### 6.2 Convert from Command Line

```cmd
mmdc -i mydiagram.mmd -o mydiagram.png -b white -s 2 --puppeteerConfigFile "C:\Users\%USERNAME%\mermaid-tool\puppeteer.json"
```

### 6.3 Batch convert all .mmd files in a folder

```cmd
for %f in (*.mmd) do mmdc -i "%f" -o "%~nf.png" -b white -s 2 --puppeteerConfigFile "C:\Users\%USERNAME%\mermaid-tool\puppeteer.json"
```

---

## 7. Troubleshooting

| Error / Symptom | Fix |
|---|---|
| `mmdc is not recognized` | Run `setx PATH "%PATH%;C:\Users\%USERNAME%\AppData\Roaming\npm"` then reopen CMD |
| `EPERM` during install | Delete `C:\Users\%USERNAME%\AppData\Roaming\npm\node_modules\@mermaid-js` and retry |
| `unable to get local issuer certificate` | Ensure `PUPPETEER_SKIP_DOWNLOAD=true` is set before installing |
| `Could not find chrome-headless-shell` | Always pass `--puppeteerConfigFile` in the bat file — the config is not auto-detected from scripts |
| `SyntaxError: module.exp is not valid JSON` | `--puppeteerConfigFile` only accepts JSON format. Use `puppeteer.json`, not `.puppeteerrc.cjs` |
| `filename, directory name syntax is incorrect` | Quotes in the registry command are wrong (curly vs straight) or missing the double outer quotes — re-run Section 5.3 |
| Window flashes and closes with no output | Temporarily add `pause` at the end of `mmd-to-png.bat` to see the error, then remove it after fixing |
| Right-click menu item not visible | Use **Shift + Right-click** on Windows 11 to access the full context menu |

---

## 8. File Reference

| File Path | Purpose |
|---|---|
| `C:\Users\%USERNAME%\.puppeteerrc.cjs` | Auto-detected Puppeteer config (JS format) — used when running mmdc directly from CMD |
| `C:\Users\%USERNAME%\mermaid-tool\puppeteer.json` | Explicit Puppeteer config (JSON format) — passed via `--puppeteerConfigFile` in scripts |
| `C:\Users\%USERNAME%\mermaid-tool\mmd-to-png.bat` | Converter batch file invoked by the right-click context menu |
