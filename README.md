# mk64-dc-macos

**English summary:** one-click build of the [mk64-dc](https://github.com/jnmartin84/mk64-dc) Dreamcast port of Mario Kart 64 on recent macOS (Apple Silicon, new Xcode), where the stock instructions fail. It builds the SH-4 toolchain (GCC 15.1.0), KallistiOS, the game and a `.cdi` disc image, applying the fixes listed under [Correcciones](#correcciones-incluidas). **No ROM, game data or disc image is included**; you must supply your own legally obtained ROM. The scripts and their messages are in Spanish.

---

Compilación automática de **Mario Kart 64 para Dreamcast** ([mk64-dc](https://github.com/jnmartin84/mk64-dc), de jnmartin84) en macOS reciente.

El proyecto original está probado hasta macOS 15.5. En un macOS y Xcode más nuevos, las instrucciones originales fallan en varios puntos. Este repositorio reúne las correcciones necesarias en un solo script que lo hace todo: compilador SH-4, KallistiOS, el juego y la imagen de disco.

> **Este repositorio no contiene la ROM, datos del juego ni imágenes de disco.** Necesitas tu propia ROM, obtenida legalmente. No pidas ni compartas ROMs o discos aquí.

## Requisitos

- macOS con las herramientas de Xcode: `xcode-select --install`
- [Homebrew](https://brew.sh). Los paquetes que falten se instalan solos.
- Tu ROM de Mario Kart 64 (EE. UU., formato Z64), con md5 `3a67d9986f54eb282924fca4cd5f6dff`
- Conexión a internet y entre 40 y 90 minutos la primera vez

## Uso

1. Descarga o clona este repositorio.
2. Copia tu ROM como `rom/baserom.us.z64`.
3. Haz doble clic en **`Compilar MK64.command`**, o desde Terminal:

   ```sh
   bash compilar-todo.sh
   ```

4. Al terminar, el disco queda en `salida/mariokart64.cdi`, listo para grabar en un CD-R.

El script hace solo lo que falte: si ya está todo compilado, tarda segundos y solo regenera el disco. Para recompilar el juego después de cambiar su código:

```sh
bash compilar-todo.sh --juego
```

Si macOS no deja abrir el `.command`: clic derecho sobre el archivo > Abrir. Si dice que no tiene permiso de ejecución: `chmod +x *.command`.

## Dónde queda cada cosa

| Ruta | Contenido |
| --- | --- |
| `~/dreamcast-sdk/sh-elf` | Compilador SH-4 (GCC 15.1.0) |
| `~/dreamcast-sdk/kos` | KallistiOS |
| `~/dreamcast-sdk/kos-ports` | Librería sh4zam |
| `~/dreamcast-sdk/mkdcdisc` | Herramienta para crear el disco |
| `~/mario-kart-64-dc` | Código del juego y archivos compilados |
| `logs/` | Un registro por cada paso |

Para usar otras carpetas:

```sh
MK64_SDK=/otra/ruta MK64_PROYECTO=/otra/ruta bash compilar-todo.sh
```

Para repetir un paso desde cero, borra su resultado y vuelve a ejecutar:

- Compilador SH-4: `~/dreamcast-sdk/sh-elf`
- KallistiOS: `~/dreamcast-sdk/kos/lib/dreamcast/libkallisti.a`
- Juego completo: `~/mario-kart-64-dc/build` y `~/mario-kart-64-dc/dc_data`

## Correcciones incluidas

Todas están en [`parches.sh`](parches.sh), con un comentario que explica cada una.

| # | Problema en macOS reciente | Solución |
| --- | --- | --- |
| 1 | Con el GCC de Homebrew como compilador, `fatal error: memory: No such file or directory`: dc-chain añade `-stdlib=libc++`, propio de clang | Compilar con Apple clang |
| 2 | GCC 13.2.0 (perfil `stable`) no compila con la libc++ de Xcode nuevo (errores en `__locale`) | Perfil GCC 15.1.0 de dc-chain |
| 3 | Una descarga cortada hace creer a dc-chain que el archivo ya está (`Lzma library error`) | Validar y reanudar las descargas |
| 4 | La zlib incluida en binutils y GCC define `fdopen` como macro y rompe `<stdio.h>` | Parche en `zlib/zutil.h` |
| 5 | `-mmacosx-version-min=10.14` genera un aviso por archivo y `configure` cree que faltan cabeceras (`dlfcn.h`), con errores en `plugin.cc` | Quitar esa opción de `scripts/init.mk` |
| 6 | Las utilidades de KallistiOS buscan libpng/jpeg en `/usr/local` | Usar el prefijo real de Homebrew |
| 7 | `environ.sh` apunta a `/opt/toolchains/dc` | Se genera a partir del de mk64-dc, cambiando solo las rutas |
| 8 | Torch: error de `consteval` en la librería fmt y comparaciones encadenadas tratadas como error | Opciones `-DFMT_CONSTEVAL=` y `-Wno-parentheses` |
| 9 | El toolchain ARM usa un GCC antiguo | No se compila: KallistiOS usa su driver de sonido precompilado |

## Versiones

Probado en un Mac con Apple Silicon, macOS 27 y su Xcode correspondiente.

Versiones fijadas: KallistiOS `680d1862` (la que exige mk64-dc), kos-ports `f4faacc4`, mk64-dc `1cbad2ef`, mkdcdisc `2b98b0d9`. La librería sh4zam se descarga en su versión más reciente, así que es lo único que podría cambiar con el tiempo.

## Avisos

- El juego está probado en consola real; en emuladores tiene fallos conocidos (lo advierte el autor del port).
- Usa CD-R, no CD-RW.
- Esto no es un proyecto oficial de mk64-dc ni de KallistiOS. Los problemas de este script repórtalos aquí, no a sus autores.

## Créditos

Todo el mérito del port es de [jnmartin84](https://github.com/jnmartin84/mk64-dc) y de quienes él menciona en su README, del equipo de la [descompilación de MK64](https://github.com/n64decomp/mk64), de [KallistiOS](https://github.com/KallistiOS/KallistiOS), de [Torch](https://github.com/HarbourMasters/Torch) y de [mkdcdisc](https://gitlab.com/simulant/mkdcdisc). Este repositorio solo automatiza la compilación.

## Licencia

Los scripts de este repositorio se publican bajo licencia [MIT](LICENSE).
