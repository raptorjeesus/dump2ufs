# dump2ufs

A tool to convert game folders into optimized UFS2 filesystem images. Works with ShadowMount v1.4b.

Available in two versions:
- **Docker version**: Cross-platform, supports both directories and archives
- **Windows version**: Native PowerShell script, directory input only

## Table of Contents

- [Docker version](#docker-version)
  - [Features](#features)
  - [Requirements](#requirements)
  - [Usage](#usage)
- [Windows version](#windows-version)
  - [Features](#features-1)
  - [Requirements](#requirements-1)
  - [Usage](#usage-1)
  - [Converting archives directly on Windows (optional)](#converting-archives-directly-on-windows-optional)
- [Thanks to](#thanks-to)

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
  ghcr.io/raptorjeesus/dump2ufs -i /input/ -o game.ffpkg
```

#### Archive input (requires FUSE)

```bash
docker run -it --rm \
  --device /dev/fuse --cap-add SYS_ADMIN \
  -v /path/to/game.rar:/game.rar \
  -v /path/to/output/:/output/ \
  ghcr.io/raptorjeesus/dump2ufs -i /game.rar -o game.ffpkg
```

#### With optional parameters

```bash
docker run -it --rm \
  -v /path/to/game/:/input/ \
  -v /path/to/output:/output/ \
  ghcr.io/raptorjeesus/dump2ufs -i /input/ -l "My_Game-01245" -y -o game.ffpkg
```

---

## Windows version

### Features

- Native PowerShell script (no Docker required)
- Directory input only (no archive support)
- Uses [UFS2Tool.exe](https://github.com/SvenGDK/UFS2Tool/) for filesystem creation
- Automatically detects optimal block/fragment sizes
- Auto-generates UFS labels from game title and ID

**Note**: see below on how one can convert RAR archives to UFS2 on Windows without extracting them first, similarly to the Docker version above.


### Requirements

- Windows 10/11
- PowerShell 5.1 or later (included with Windows)
- [UFS2Tool.exe by SvenGDK](https://github.com/SvenGDK/UFS2Tool)

### Usage

Download [`dump2ufs.ps1`](https://github.com/raptorjeesus/dump2ufs/releases) and place it in a convenient location. Ensure `UFS2Tool.exe` is available.

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
powershell -ExecutionPolicy Bypass -File .\dump2ufs.ps1 -InputPath "C:\Games\PPSA00000-app" -o "game.ffpkg"
```

#### With short aliases

```powershell
powershell -ExecutionPolicy Bypass -File .\dump2ufs.ps1 -i "C:\Games\PPSA00000-app" -o "game.ffpkg"
```

#### With custom label and skip confirmation

```powershell
powershell -ExecutionPolicy Bypass -File .\dump2ufs.ps1 -i "C:\Games\PPSA00000-app" -o "game.ffpkg" -l "My_Game-01245" -y
```

#### Specifying UFS2Tool.exe path

```powershell
powershell -ExecutionPolicy Bypass -File .\dump2ufs.ps1 -i "C:\Games\PPSA00000-app" -o "game.ffpkg" -u "C:\Tools\UFS2Tool.exe"
```

### Converting archives directly on Windows (optional)

To mount RAR/RAR5 archives directly as a folder in Windows, without extracting them first, set up rar2fs:

1. Install [WinFsp](https://winfsp.dev/rel/) (latest stable release)
2. Install [Cygwin](https://www.cygwin.com/) with packages: `gcc-g++`, `make`, `autoconf`, `automake`, `git`, `wget`, `tar`
3. **Open a Cygwin terminal** and run the following commands:

   Install cygfuse (FUSE for Cygwin, included with WinFsp):
   ```bash
   sh "$(cat /proc/registry32/HKEY_LOCAL_MACHINE/SOFTWARE/WinFsp/InstallDir | tr -d '\0')"/opt/cygfuse/install.sh
   ```
4. Download and compile [UnRAR source](https://www.rarlab.com/rar_add.htm) v7.x.x:
   ```bash
   wget -O - https://www.rarlab.com/rar/unrarsrc-7.2.4.tar.gz | tar -xz
   cd unrar
   # Add -fPIC flag for 64-bit compatibility as per Q 1.7. in rar2fs wiki
   sed -i 's/^CXXFLAGS=-O2/CXXFLAGS=-O2 -fPIC/' makefile
   make lib
   make install-lib
   cd ..
   ```
5. Download and compile [rar2fs](https://github.com/hasse69/rar2fs/releases/):
   ```bash
   wget -O - https://github.com/hasse69/rar2fs/archive/refs/tags/v1.29.7.tar.gz | tar -xz
   cd rar2fs-1.29.7
   autoreconf -f -i
   ./configure
   make
   make install
   cd ..
   ```
6. Mount your archive as a folder (using /cygdrive/ paths for Windows compatibility):
   ```bash
   mkdir -p /cygdrive/c/temp/archive
   rar2fs /cygdrive/c/path/to/archive.rar /cygdrive/c/temp/archive
   ```
7. **(In a Windows terminal)** Use the mounted path with the PowerShell script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\dump2ufs.ps1 -u "C:\Tools\UFS2Tool.exe" -i "C:\temp\archive" -o "game.ffpkg"
   ```

**Note:** This setup is advanced. For simpler usage, extract the archive first, then use this script on the extracted directory.


---

## Thanks to

- [**kusumi/makefs**](https://github.com/kusumi/makefs): for makefs (from FreeBSD 14.3) ported to Linux
- [**SvenGDK/UFS2Tool**](https://github.com/SvenGDK/UFS2Tool): for makefs ported to Windows
- [**voidwhisper-ps**](https://github.com/voidwhisper-ps) and [**adel-ailane/ShadowMount**](https://github.com/adel-ailane/ShadowMount) for Shadowmount v1.4b with UFS2 mount support
- [**earthonion/mkufs2**](https://github.com/earthonion/mkufs2): for initial UFS2 creation script

