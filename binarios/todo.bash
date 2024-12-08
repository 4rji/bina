#!/usr/bin/env bash

file="$HOME/.todo.txt"

# Verificar si se ha proporcionado un argumento
if [ -z "$1" ]; then
#    echo "Por favor, especifica una palabra de búsqueda."
    echo ""
    echo "Uso: todo [palabra de búsqueda] / ejemplo: todo ssh "
    exit 1
fi

if [ -f "$file" ]; then
    cat "$file" | grep "$1" 
else
    echo "El archivo $file no existe."
fi
echo ""

echo "Para actualizar base de datos ejecuta todou"
echo ""
