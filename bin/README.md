# Binary Tools Directory

This directory contains pre-built binaries for different architectures.

## Directory Structure

```
bin/
├── x86_64/      # Linux Intel/AMD 64-bit
├── aarch64/     # Linux ARM64 (Raspberry Pi, etc.)
├── arm64/       # macOS Apple Silicon (M1/M2/M3)
├── download-tools.sh
└── README.md
```

## Required Tools

| Tool | Description | Source |
|------|-------------|--------|
| `gaster` | checkm8 exploit tool | https://github.com/0x7ff/gaster |
| `irecovery` | USB communication with iOS devices | https://github.com/libimobiledevice/libirecovery |
| `iproxy` | TCP port forwarding over USB | https://github.com/libimobiledevice/libusbmuxd |
| `img4` | IMG4 file manipulation | https://github.com/xerub/img4lib |
| `bspatch` | Binary patching tool | Part of bsdiff package |

## Installation

### Automatic Download

```bash
# Auto-detect architecture
./download-tools.sh --auto

# Or specify architecture
./download-tools.sh --x86_64
./download-tools.sh --aarch64
./download-tools.sh --arm64

# Download for all architectures
./download-tools.sh --all
```

### Manual Installation

#### Linux (x86_64 / aarch64)

```bash
# Install via apt (Debian/Ubuntu)
sudo apt update
sudo apt install libirecovery-utils libusbmuxd-tools bsdiff

# Build gaster from source
git clone https://github.com/0x7ff/gaster
cd gaster && make
cp gaster ../bin/x86_64/  # or aarch64

# Build img4 from source
git clone https://github.com/xerub/img4lib
cd img4lib && make
cp img4 ../bin/x86_64/  # or aarch64
```

#### macOS (arm64)

```bash
# Install via Homebrew
brew install libirecovery libusbmuxd bsdiff

# Build gaster from source
git clone https://github.com/0x7ff/gaster
cd gaster && make
cp gaster ../bin/arm64/

# img4 is included in macos/ directory
```

## Usage

The main `ayakurume-cli.sh` script will automatically detect your architecture and use the appropriate binaries from this directory.

You can also set the `BIN_PATH` environment variable to override:

```bash
export BIN_PATH=/path/to/custom/binaries
./ayakurume-cli.sh
```

## Building from Source

### gaster

```bash
git clone https://github.com/0x7ff/gaster
cd gaster
make
```

### libirecovery (irecovery)

```bash
git clone https://github.com/libimobiledevice/libirecovery
cd libirecovery
./autogen.sh
make
sudo make install
```

### libusbmuxd (iproxy)

```bash
git clone https://github.com/libimobiledevice/libusbmuxd
cd libusbmuxd
./autogen.sh
make
sudo make install
```

### img4lib (img4)

```bash
git clone https://github.com/xerub/img4lib
cd img4lib
make
```
