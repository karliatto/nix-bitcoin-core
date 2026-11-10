# nix-bitcoin-core

A Nix environment for Bitcoin Core development. Helps install necessary and optional dependencies.

The shell targets the CMake build system, so it supports Bitcoin Core v29.0 and later.

## Installation

One way is to have the **nix-bitcoin-core/** directory alongside your **bitcoin/** directory, then symlink the shell.nix across. (Here it's done from **bitcoin/** assuming a common parent directory).

```console
ln -s ../nix-bitcoin-core/shell.nix .
```

## Usage

Get your terminal into the **bitcoin/** directory and do some variant of this:
```console
nix-shell --arg withClang true --arg withGui false
```

### Supported arguments

| Name         | Description                                   | Valid values  |
|--------------|-----------------------------------------------|---------------|
| `spareCores` | How many cores to exclude when building and running tests | `<integer>` = less than the number of logical cores |
| `withClang`  | Whether to switch from GCC to Clang for compilation | `<boolean>` |
| `withDebug`  | Whether to pass `-DCMAKE_BUILD_TYPE=Debug` to CMake | `<boolean>` |
| `withGui`    | Whether to enable bitcoin-qt (Qt 6)           | `<boolean>` |

### Aliases

Inside the shell, these aliases are available. Configuration goes into **./build**, and **./build/bin** is added to `$PATH`.

| Alias | Description |
|-------|-------------|
| `c` | Configure (`cmake -B build ...`) |
| `c_nw` | Configure without the wallet |
| `c_fast` | Configure without the wallet, tests, benchmarks and fuzz binary |
| `c_fast_wallet` | Configure with the wallet, but without tests, benchmarks and fuzz binary |
| `m` | Build (`cmake --build build`) |
| `cm`, `cm_nw`, `cm_fast`, `cm_fast_wallet` | Configure + build |
| `ut` | Unit tests (`ctest`) |
| `ft` | Functional tests |
| `t` | Unit + functional tests |
| `clean` | Remove **./build** |
