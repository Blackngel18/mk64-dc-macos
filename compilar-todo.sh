#!/bin/bash
# =============================================================================
#  Mario Kart 64 para Dreamcast - compilacion automatica en macOS
#  Uso:   bash compilar-todo.sh            (hace solo lo que falte)
#         bash compilar-todo.sh --juego    (recompila el juego y regenera el disco)
#  Resultado: salida/mariokart64.cdi
# =============================================================================
KIT="$(cd "$(dirname "$0")" && pwd)"
SDK="${MK64_SDK:-$HOME/dreamcast-sdk}"            # toolchain + KallistiOS
PROY="${MK64_PROYECTO:-$HOME/mario-kart-64-dc}"   # codigo del juego
LOGS="$KIT/logs"; SALIDA="$KIT/salida"
RECOMPILAR_JUEGO=0; [ "${1:-}" = "--juego" ] && RECOMPILAR_JUEGO=1

# Versiones exactas con las que se comprobo que todo compila.
KOS_URL="https://github.com/KallistiOS/KallistiOS.git";   KOS_REV="680d18622376666ad9251929f7a6f450e7724607"
PORTS_URL="https://github.com/KallistiOS/kos-ports.git";  PORTS_REV="f4faacc42faaf552625777b7709e871a827e1055"
PROY_URL="https://github.com/jnmartin84/mk64-dc.git";     PROY_REV="1cbad2ef2d45c49f782ecadeddbbd49063a3507e"
DISC_URL="https://gitlab.com/simulant/mkdcdisc.git";      DISC_REV="2b98b0d9480e364e3517355648fbc3b49fb19882"
GCC_VER="15.1.0"; BINUTILS_VER="2.44"; NEWLIB_TAR="newlib-4.5.0.20241231.tar.gz"
ROM_MD5="3a67d9986f54eb282924fca4cd5f6dff"

mkdir -p "$LOGS" "$SALIDA" "$KIT/rom"
source "$KIT/parches.sh" || { echo "Falta parches.sh junto a este script"; exit 1; }
unset CC CXX CPLUS_INCLUDE_PATH C_INCLUDE_PATH CPATH LIBRARY_PATH CFLAGS CXXFLAGS LDFLAGS
export CMAKE_POLICY_VERSION_MINIMUM=3.5
LOG="$LOGS/00-requisitos.log"

paso()  { LOG="$LOGS/$1.log"; : > "$LOG"; echo; echo "=== $2 ==="; }
fallo() {
    echo; echo "ERROR en: $1"
    echo "--- Primeros errores ---"
    grep -nE 'fatal error:|error:|CMake Error|ERROR|Error [0-9]+' "$LOG" | grep -v 'unsupported option\|no input files' | head -n 12
    echo "--- Ultimas lineas del log ---"; tail -n 15 "$LOG"
    echo "Log completo: $LOG"; exit 1
}
clonar() {   # $1 url  $2 revision  $3 destino
    if [ ! -d "$3/.git" ]; then git clone "$1" "$3" >> "$LOG" 2>&1 || return 1; fi
    [ "$(git -C "$3" rev-parse HEAD)" = "$2" ] || git -C "$3" checkout "$2" >> "$LOG" 2>&1
}
valido() { [ -f "$1" ] && tar tf "$1" > /dev/null 2>&1; }

# ----------------------------------------------------------------------------
paso 00-requisitos "0/7 Comprobando requisitos"
[ "$(uname -s)" = "Darwin" ] || { echo "Este script es para macOS."; exit 1; }
case "$SDK$PROY" in *" "*) echo "Las rutas no pueden contener espacios: $SDK / $PROY"; exit 1;; esac
xcode-select -p > /dev/null 2>&1 || { echo "Faltan las herramientas de Xcode. Ejecuta:  xcode-select --install"; exit 1; }
BREW="$(command -v brew || true)"
[ -n "$BREW" ] || for B in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$B" ] && BREW="$B"; done
[ -n "$BREW" ] || { echo "Falta Homebrew. Instalalo desde https://brew.sh y vuelve a ejecutar."; exit 1; }
BP="$("$BREW" --prefix)"
export PATH="$BP/bin:$BP/opt/texinfo/bin:$BP/opt/bison/bin:$BP/opt/flex/bin:$PATH"
for P in make cmake ninja meson pkg-config texinfo bison flex libpng jpeg-turbo libisofs libelf; do
    "$BREW" list "$P" > /dev/null 2>&1 && continue
    echo "  Instalando $P..."; "$BREW" install "$P" >> "$LOG" 2>&1 || fallo "instalar $P con Homebrew"
done
command -v gmake > /dev/null || fallo "encontrar gmake"
echo "  OK (Homebrew en $BP)"

# ----------------------------------------------------------------------------
paso 01-fuentes "1/7 Obteniendo KallistiOS y el codigo del juego"
clonar "$KOS_URL" "$KOS_REV" "$SDK/kos"   || fallo "obtener KallistiOS"
clonar "$PROY_URL" "$PROY_REV" "$PROY"    || fallo "obtener mk64-dc"
if [ ! -f "$PROY/tools/torch/CMakeLists.txt" ]; then
    git -C "$PROY" submodule update --init >> "$LOG" 2>&1 || fallo "obtener submodulos"
fi
if [ ! -f "$PROY/baserom.us.z64" ] && [ -f "$KIT/rom/baserom.us.z64" ]; then cp "$KIT/rom/baserom.us.z64" "$PROY/"; fi
[ -f "$PROY/baserom.us.z64" ] || { echo "FALTA LA ROM: copia tu ROM (EE. UU., formato Z64) como  $KIT/rom/baserom.us.z64"; exit 1; }
[ "$(md5 -q "$PROY/baserom.us.z64")" = "$ROM_MD5" ] || { echo "La ROM no es la version correcta (md5 esperado $ROM_MD5)."; exit 1; }
echo "  OK (ROM verificada)"

# ----------------------------------------------------------------------------
paso 02-toolchain "2/7 Compilador SH-4 (GCC $GCC_VER)"
if "$SDK/sh-elf/bin/sh-elf-gcc" --version 2>/dev/null | grep -q "$GCC_VER"; then
    echo "  Ya instalado, se omite."
else
    DC="$SDK/kos/utils/dc-chain"; cd "$DC" || fallo "entrar a dc-chain"
    config_dcchain "$DC" "$SDK"   || fallo "configurar dc-chain"
    parche_dcchain_init "$DC"     || fallo "parchear dc-chain"
    rm -rf build-gcc-sh-elf-* build-binutils-sh-elf-* build-newlib-sh-elf-* "$SDK/sh-elf"
    export CC=/usr/bin/clang CXX=/usr/bin/clang++     # dc-chain espera Apple clang, no el GCC de Homebrew

    echo "  Descargando fuentes..."
    GCC_TAR="gcc-$GCC_VER.tar.xz"; DESCARGA=1
    for ESPEJO in ftpmirror.gnu.org mirrors.kernel.org ftp.gnu.org ftpmirror.gnu.org mirrors.kernel.org ftp.gnu.org; do
        # Un archivo a medias hace creer a make que ya esta descargado: se valida antes.
        if ! valido "$GCC_TAR"; then
            curl --fail --location -C - --retry 5 --retry-all-errors --connect-timeout 20 \
                 -o "$GCC_TAR" "https://$ESPEJO/gnu/gcc/gcc-$GCC_VER/$GCC_TAR"; CODIGO=$?
            if ! valido "$GCC_TAR"; then
                if [ "$CODIGO" -eq 22 ] || [ "$CODIGO" -eq 33 ] || [ "$CODIGO" -eq 0 ]; then rm -f "$GCC_TAR"; fi
                continue
            fi
        fi
        for F in "binutils-$BINUTILS_VER.tar.xz" "$NEWLIB_TAR"; do
            if [ -f "$F" ] && ! valido "$F"; then rm -f "$F"; fi
        done
        if make fetch-sh4 gnu_mirror="$ESPEJO" >> "$LOG" 2>&1; then DESCARGA=0; break; fi
        sleep 3
    done
    [ "$DESCARGA" -eq 0 ] || fallo "descargar las fuentes del toolchain"
    parche_zlib "$DC/binutils-$BINUTILS_VER" || fallo "parchear zlib de binutils"
    parche_zlib "$DC/gcc-$GCC_VER"           || fallo "parchear zlib de GCC"

    echo "  Compilando (15-60 min, no cierres la ventana)..."
    make build-sh4 >> "$LOG" 2>&1 || fallo "compilar el toolchain SH-4"
    unset CC CXX
    "$SDK/sh-elf/bin/sh-elf-gcc" --version | head -n 1
fi

# ----------------------------------------------------------------------------
paso 03-kos "3/7 KallistiOS"
generar_environ "$PROY/environ.sh" "$SDK" || fallo "generar environ.sh"
source "$SDK/kos/environ.sh" || fallo "cargar environ.sh"
if [ -f "$SDK/kos/lib/dreamcast/libkallisti.a" ]; then
    echo "  Ya compilado, se omite."
else
    parche_kos_utils "$SDK/kos" "$BP" || fallo "parchear utilidades de KOS"
    ( cd "$SDK/kos" && gmake ) >> "$LOG" 2>&1 || fallo "compilar KallistiOS"
    echo "  OK"
fi

# ----------------------------------------------------------------------------
paso 04-sh4zam "4/7 Libreria sh4zam (kos-ports)"
if [ -e "$SDK/kos-ports/lib/libsh4zam.a" ]; then
    echo "  Ya compilada, se omite."
else
    clonar "$PORTS_URL" "$PORTS_REV" "$SDK/kos-ports" || fallo "obtener kos-ports"
    ( cd "$SDK/kos-ports/sh4zam" && gmake install clean ) >> "$LOG" 2>&1 || fallo "compilar sh4zam"
    echo "  OK"
fi

# ----------------------------------------------------------------------------
paso 05-juego "5/7 Mario Kart 64"
cd "$PROY" || fallo "entrar al proyecto"
if [ -s build/mario-kart.elf ] && [ "$RECOMPILAR_JUEGO" -eq 0 ]; then
    echo "  Ya compilado, se omite (usa --juego para recompilar)."
elif [ -s build/mario-kart.elf ]; then
    echo "  Recompilando el juego..."
    gmake >> "$LOG" 2>&1 || fallo "recompilar el juego"
else
    parche_torch "$PROY/tools/torch" || fallo "parchear Torch"
    echo "  a) Torch (extractor de datos)...";  ( cd tools/torch && gmake ) >> "$LOG" 2>&1 || fallo "compilar Torch"
    echo "  b) Herramientas...";                ( cd tools && gmake )       >> "$LOG" 2>&1 || fallo "compilar herramientas"
    echo "  c) Extrayendo datos de la ROM...";  gmake assets                >> "$LOG" 2>&1 || fallo "extraer datos de la ROM"
    echo "  d) Compilando el juego (5-30 min)..."; gmake                    >> "$LOG" 2>&1 || fallo "compilar el juego"
fi
[ -s build/mario-kart.elf ] || fallo "encontrar build/mario-kart.elf"

# ----------------------------------------------------------------------------
paso 06-mkdcdisc "6/7 Herramienta de disco (mkdcdisc)"
if [ -x "$SDK/mkdcdisc/builddir/mkdcdisc" ]; then
    echo "  Ya compilada, se omite."
else
    clonar "$DISC_URL" "$DISC_REV" "$SDK/mkdcdisc" || fallo "obtener mkdcdisc"
    ( cd "$SDK/mkdcdisc" && { [ -d builddir ] || meson setup builddir; } && meson compile -C builddir ) >> "$LOG" 2>&1 || fallo "compilar mkdcdisc"
    echo "  OK"
fi
export PATH="$SDK/mkdcdisc/builddir:$PATH"

# ----------------------------------------------------------------------------
paso 07-disco "7/7 Imagen de disco"
cd "$PROY" || exit 1
rm -f mariokart64.cdi
gmake cdi >> "$LOG" 2>&1 || fallo "generar el CDI"
cp -f mariokart64.cdi "$SALIDA/mariokart64.cdi" || fallo "copiar el CDI"

echo; echo "LISTO. Imagen de disco para grabar en CD-R:"
ls -la "$SALIDA/mariokart64.cdi"
