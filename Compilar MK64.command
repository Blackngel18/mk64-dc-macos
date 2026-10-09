#!/bin/bash
# Doble clic para compilar Mario Kart 64 para Dreamcast y generar el disco.
cd "$(dirname "$0")" || exit 1
clear
echo "Mario Kart 64 para Dreamcast - compilacion automatica"
bash ./compilar-todo.sh
ESTADO=$?
echo
if [ "$ESTADO" -eq 0 ]; then
    open ./salida
else
    echo "La compilacion no termino. Revisa el mensaje de arriba."
fi
read -n 1 -s -r -p "Pulsa cualquier tecla para cerrar..."
echo
