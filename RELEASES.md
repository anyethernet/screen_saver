# Windows downloads — Webcam & Screen Saver

## Latest installer

- **Releases page:** https://github.com/anyethernet/screen_saver/releases
- **Preferred asset names:**
  - `RemoteCamSaver-Setup.exe` (English file name)
  - `원격카메라-설치.exe` (same build, Korean file name)

### Direct “latest” link (works when the release asset exists)

https://github.com/anyethernet/screen_saver/releases/latest/download/RemoteCamSaver-Setup.exe

## Visibility note

This repository has historically been **private**. On a private repository:

- Collaborators with access can download release assets while signed in to GitHub.
- Anonymous / public Play Store users **cannot** download private release assets.

To make the Windows installer publicly downloadable without a separate host:

1. Make the repository **public**, **or**
2. Keep the repo private and host the installer on a public URL (GitHub Pages static file, object storage, etc.), then update the in-app link.

Until the repo or asset is public, the Android app still links to the Releases page above so signed-in users can fetch the installer.

## Build locally

```bat
cd windows\RemoteCamSaver
build-installer.bat
```

Output: `windows\RemoteCamSaver\dist\RemoteCamSaver-Setup.exe` and `원격카메라-설치.exe`.
