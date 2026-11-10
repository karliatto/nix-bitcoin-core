# Usage example:
# $ nix-shell --arg withClang true --arg spareCores 2 --arg withGui true
#
# Inside the shell:
#   c / c_nw / c_fast / c_fast_wallet      configure into ./build (cmake -B build ...)
#   m                                      build (cmake --build build)
#   cm / cm_nw / cm_fast / cm_fast_wallet  configure + build
#   ut / ft / t                            unit tests / functional tests / both
#   clean                                  remove ./build
{ pkgs ? import <nixpkgs> {},
  spareCores ? 0,
  withClang ? false,
  withDebug ? false,
  withGui ? false,
}:
let
  inherit (pkgs.lib) optionals optionalString strings;
  buildDir = "build";
  binDirs = [ "\$PWD/${buildDir}/bin" ];
  cmakeFlags =
    [ "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" "-DWITH_ZMQ=ON" ]
    ++ optionals withClang [ "-DCMAKE_C_COMPILER=clang" "-DCMAKE_CXX_COMPILER=clang++" ]
    ++ optionals withDebug [ "-DCMAKE_BUILD_TYPE=Debug" ]
    ++ optionals withGui [ "-DBUILD_GUI=ON" ];
  cmakeConfigure = extra: "cmake -B ${buildDir} ${builtins.concatStringsSep " " (cmakeFlags ++ extra)}";
  fastFlags = [ "-DBUILD_TESTS=OFF" "-DBUILD_BENCH=OFF" "-DBUILD_FUZZ_BINARY=OFF" ];
  jobs =
    if (strings.hasSuffix "linux" builtins.currentSystem) then "$(($(nproc)-${toString spareCores}))"
    else if (strings.hasSuffix "darwin" builtins.currentSystem) then "$(($(sysctl -n hw.physicalcpu)-${toString spareCores}))"
    else "6";
in pkgs.mkShell {
    nativeBuildInputs = with pkgs; [
      cmake
      pkg-config
      boost
      libevent
      zeromq
      sqlite
      # nixpkgs' default LLVM; clang and clang-tools are kept on the same version
      llvmPackages.clang

      # IPC / multiprocess (ENABLE_IPC is ON by default; pass -DENABLE_IPC=OFF to skip)
      capnproto

      # tests
      hexdump

      # compiler output caching per
      # https://github.com/bitcoin/bitcoin/blob/master/doc/productivity.md#cache-compilations-with-ccache
      # (CMake uses it automatically, WITH_CCACHE=ON by default)
      ccache

      # clang-format, clang-tidy, clangd. CMake writes build/compile_commands.json
      # because of -DCMAKE_EXPORT_COMPILE_COMMANDS=ON.
      llvmPackages.clang-tools

      # depends
      byacc

      # functional tests & linting
      python3
      python3Packages.flake8
      python3Packages.lief
      python3Packages.autopep8
      python3Packages.mypy
      python3Packages.requests
      python3Packages.pyzmq

      # benchmarking
      python3Packages.pyperf

      # debugging
      gdb
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      # tracing (USDT: configure with -DWITH_USDT=ON)
      libsystemtap
      linuxPackages.bpftrace
      linuxPackages.bcc
    ]
    ++ lib.optionals withGui [
      # bitcoin-qt
      qt6.qtbase
      # lrelease, lupdate, etc.
      qt6.qttools
      qt6.qtwayland
      # QR codes in the GUI (WITH_QRENCODE defaults to ON with BUILD_GUI)
      qrencode
    ];

    # Modifies the Nix clang++ wrapper to avoid warning:
    # "_FORTIFY_SOURCE requires compiling with optimization (-O)"
    hardeningDisable = if withDebug then [ "all" ] else [ ];

    # Fixes xcb plugin error when trying to launch bitcoin-qt
    QT_QPA_PLATFORM_PLUGIN_PATH = if withGui then "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}/platforms" else "";

    shellHook = ''
      echo "Bitcoin Core build nix-shell (CMake)"
      echo ""
    '' + optionalString pkgs.stdenv.hostPlatform.isLinux ''
      BCC_EGG=${pkgs.linuxPackages.bcc}/${pkgs.python3.sitePackages}/bcc-${pkgs.linuxPackages.bcc.version}-py3.${pkgs.python3.sourceVersion.minor}.egg

      echo "adding bcc egg to PYTHONPATH: $BCC_EGG"
      if [ -f $BCC_EGG ]; then
        export PYTHONPATH="$PYTHONPATH:$BCC_EGG"
        echo ""
      else
        echo "The bcc egg $BCC_EGG does not exist. Maybe the python or bcc version is different?"
      fi
    '' + ''
      # configure
      alias c="${cmakeConfigure []}"
      alias c_nw="${cmakeConfigure [ "-DENABLE_WALLET=OFF" ]}"
      alias c_fast="${cmakeConfigure ([ "-DENABLE_WALLET=OFF" ] ++ fastFlags)}"
      alias c_fast_wallet="${cmakeConfigure fastFlags}"

      # build
      alias m="cmake --build ${buildDir} -j${jobs}"
      alias clean="rm -rf ${buildDir}"

      # configure + build combos
      alias cm="c && m"
      alias cm_nw="c_nw && m"
      alias cm_fast="c_fast && m"
      alias cm_fast_wallet="c_fast_wallet && m"

      # unit tests (ctest)
      alias ut="ctest --test-dir ${buildDir} -j${jobs} --output-on-failure"
      # functional tests
      alias ft="${buildDir}/test/functional/test_runner.py -j${jobs}"
      # all tests
      alias t="ut && ft"

      echo "adding ${builtins.concatStringsSep ":" binDirs} to \$PATH to make running built binaries more natural"
      export PATH=$PATH:${builtins.concatStringsSep ":" binDirs};

      alias c c_nw c_fast c_fast_wallet m clean cm cm_nw cm_fast cm_fast_wallet ut ft t
    '';
}
