# dump2ufs

A tool to convert game folders into optimized UFS2 filesystem images. Works with ShadowMount v1.4b.

Available in two versions:
- **Docker version**: Cross-platform, supports both directories and archives
- **Windows version**: Native PowerShell script, directory input only

---

## Docker version

### Features

- Accepts dumps as directories or as archives (RAR, 7z, etc via fuse-archive/libarchive)
- Automatically mounts and reads from archives without extracting to a temporary location
- Auto-detects game folder root by looking for existence of `sce_sys/param.json`, checks subfolders (one level deep) in archives
- Tests block sizes from 4KB to 64KB for optimal space efficiency and auto-selects the best one

### Requirements

- Docker
- FUSE3 support (only for archive inputs)

### Usage

**Note:** If using with WSL2, writing output to Windows paths (/mnt/c/...) works, but is quite a lot slower.

#### Command-line options

```
-i <path>      Input path (file or directory) (required)
-o <filename>  Output filename (required)
-l <label>     UFS filesystem label (optional, max 16 chars, does not make any difference for mounting; defaults to title ID number + alphanumeric title name, e.g. 01234MyGame)
-y             Skip confirmation prompt (optional)
```

#### Directory input

```bash
docker run -it --rm \
  -v /path/to/game/:/input/ \
  -v /path/to/output/:/output/ \
  ghcr.io/raptorjeesus/dump2ufs:latest -i /input/ -o game.ffpkg
```

#### Archive input (requires FUSE)

```bash
docker run -it --rm \
  --device /dev/fuse --cap-add SYS_ADMIN \
  -v /path/to/game.rar:/game.rar \
  -v /path/to/output/:/output/ \
  ghcr.io/raptorjeesus/dump2ufs:latest -i /game.rar -o game.ffpkg
```

#### With optional parameters

```bash
docker run -it --rm \
  -v /path/to/game/:/input/ \
  -v /path/to/output:/output/ \
  ghcr.io/raptorjeesus/dump2ufs:latest -i /input/ -l "My_Game-01245" -y -o game.ffpkg
```

---

## Windows version

### Features

- Native PowerShell script (no Docker required)
- Directory input only (no archive support)
- Uses [UFS2Tool.exe](https://github.com/SvenGDK/UFS2Tool/) for filesystem creation
- Automatically detects optimal block/fragment sizes
- Auto-generates UFS labels from game title and ID

### Requirements

- Windows 10/11
- PowerShell 5.1 or later (included with Windows)
- [UFS2Tool.exe by SvenGDK](https://github.com/SvenGDK/UFS2Tool)

### Usage

Download `makefs.ps1` and place it in a convenient location. Ensure `UFS2Tool.exe` is available.

#### Command-line options

```powershell
-i, -InputPath <path>      Input directory path (required)
-o, -OutputFile <filename> Output filename (required)
-l, -Label <label>         UFS filesystem label (optional, max 16 chars)
-y -SkipConfirmation       Skip confirmation prompt (optional)
-u, UFS2ToolPath <path>    Path to UFS2Tool.exe (optional), by default will try current directory and $PATH
```

#### Basic usage

```powershell
powershell -ExecutionPolicy Bypass -File .\makefs.ps1 -InputPath "C:\Games\PPSA00000-app" -o "game.ffpkg"
```

#### With short aliases

```powershell
powershell -ExecutionPolicy Bypass -File .\makefs.ps1 -i "C:\Games\PPSA00000-app" -o "game.ffpkg"
```

#### With custom label and skip confirmation

```powershell
powershell -ExecutionPolicy Bypass -File .\makefs.ps1 -i "C:\Games\PPSA00000-app" -o "game.ffpkg" -l "My_Game-01245" -y
```

#### Specifying UFS2Tool.exe path

```powershell
powershell -ExecutionPolicy Bypass -File .\makefs.ps1 -i "C:\Games\PPSA00000-app" -o "game.ffpkg" -u "C:\Tools\UFS2Tool.exe"
```


---

## Thanks to

- [**kusumi/makefs**](https://github.com/kusumi/makefs): for makefs (from FreeBSD 14.3) ported to Linux
- [**SvenGDK/UFS2Tool**](https://github.com/SvenGDK/UFS2Tool): for makefs ported to Windows
- [**voidwhisper-ps**](https://github.com/voidwhisper-ps) and [**adel-ailane/ShadowMount**](https://github.com/adel-ailane/ShadowMount) for Shadowmount v1.4b with UFS2 mount support
- [**earthonion/mkufs2**](https://github.com/earthonion/mkufs2): for initial UFS2 creation script

