#!/bin/bash
# Correcciones necesarias para compilar en macOS reciente (Apple Silicon, Xcode nuevo).
# Cada funcion es idempotente: se puede aplicar varias veces sin estropear nada.

# dc-chain: usar el perfil GCC 15.1.0 e instalar en la carpeta del usuario.
# (GCC 13.2.0, el perfil "stable", no compila con las cabeceras C++ de Xcode nuevo.)
config_dcchain() {   # $1 = carpeta dc-chain, $2 = carpeta SDK
    cp "$1/Makefile.default.cfg" "$1/Makefile.cfg" || return 1
    SDK_P="$2" perl -pi -e '
        s{^toolchain_profile=.*}{toolchain_profile=15.1.0};
        s{^sh_toolchain_path=.*}{sh_toolchain_path=$ENV{SDK_P}/sh-elf};
        s{^arm_toolchain_path=.*}{arm_toolchain_path=$ENV{SDK_P}/arm-eabi};' "$1/Makefile.cfg" || return 1
    grep -q '^toolchain_profile=15.1.0$' "$1/Makefile.cfg" && grep -q "^sh_toolchain_path=$2/sh-elf$" "$1/Makefile.cfg"
}

# dc-chain: quitar -mmacosx-version-min=10.14. Xcode nuevo emite un aviso por cada
# archivo con esa opcion y "configure" lo interpreta como que faltan cabeceras (dlfcn.h...).
parche_dcchain_init() {   # $1 = carpeta dc-chain
    perl -pi -e 's/ -mmacosx-version-min=10\.14//' "$1/scripts/init.mk" || return 1
    ! grep -q 'mmacosx-version-min' "$1/scripts/init.mk"
}

# zlib incluida en binutils y GCC: cree que todo Mac es "Mac OS clasico" sin fdopen()
# y define una macro que rompe <stdio.h> del SDK actual.
parche_zlib() {   # $1 = carpeta de fuentes (binutils-X o gcc-X)
    [ -f "$1/zlib/zutil.h" ] || return 1
    perl -pi -e 's/^#if defined\(MACOS\) \|\| defined\(TARGET_OS_MAC\)/#if defined(MACOS)/' "$1/zlib/zutil.h" || return 1
    ! grep -q 'defined(TARGET_OS_MAC)' "$1/zlib/zutil.h"
}

# Utilidades de KallistiOS: buscan libpng/jpeg en /usr/local (Homebrew de Intel).
parche_kos_utils() {   # $1 = carpeta kos, $2 = prefijo de Homebrew
    [ "$2" = "/usr/local" ] && return 0
    local f
    for f in dcbumpgen/Makefile kmgenc/Makefile vqenc/Makefile makeip/src/Makefile; do
        BP="$2" perl -pi -e 's{/usr/local/(include|lib)}{$ENV{BP}/$1}g' "$1/utils/$f" || return 1
        grep -q "$2/include" "$1/utils/$f" || return 1
    done
}

# environ.sh de KOS: se usa el del proyecto MK64 (lo exige su README), cambiando solo rutas.
generar_environ() {   # $1 = environ.sh del proyecto, $2 = carpeta SDK
    SDK_P="$2" perl -pe '
        s{^export KOS_BASE=.*}{export KOS_BASE="$ENV{SDK_P}/kos"};
        s{^export KOS_CC_BASE=.*}{export KOS_CC_BASE="$ENV{SDK_P}/sh-elf"};
        s{^export DC_ARM_BASE=.*}{export DC_ARM_BASE="$ENV{SDK_P}/arm-eabi"};
        s{^export DC_TOOLS_BASE=.*}{export DC_TOOLS_BASE="$ENV{SDK_P}/bin"};
        s{^export KOS_MAKE=.*}{export KOS_MAKE="gmake"};' "$1" > "$2/kos/environ.sh" || return 1
    grep -q "^export KOS_BASE=\"$2/kos\"$" "$2/kos/environ.sh"
}

# Torch: clang nuevo rechaza un uso de consteval en la libreria fmt antigua, y trata
# las comparaciones encadenadas (a <= b <= c) como error en vez de aviso.
parche_torch() {   # $1 = carpeta tools/torch
    grep -q 'FMT_CONSTEVAL' "$1/CMakeLists.txt" && return 0
    perl -pi -e 's/set\(CMAKE_CXX_FLAGS "-Wno-narrowing"\)/set(CMAKE_CXX_FLAGS "-Wno-narrowing -Wno-parentheses -DFMT_CONSTEVAL=")/' "$1/CMakeLists.txt" || return 1
    grep -q 'FMT_CONSTEVAL' "$1/CMakeLists.txt"
}
