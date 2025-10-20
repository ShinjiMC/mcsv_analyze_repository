#!/bin/bash

REPO_PATH=$1
OUTPUT_FILE=$2

if [ -z "$REPO_PATH" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Se requieren 2 argumentos: <ruta_del_repo> <ruta_del_output>" >&2
    echo "Uso: $0 /path/to/repo /path/to/complexity.out" >&2
    exit 1
fi

if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$PWD/$OUTPUT_FILE"
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"
> "${OUTPUT_FILE}"

cd "$REPO_PATH" || { echo "Error: No se pudo entrar al directorio $REPO_PATH" >&2; exit 1; }
echo "Calculando métricas de complejidad (gocyclo)... (en $PWD)" >&2
packages=($(go list -f '{{.Dir}}' ./... | grep -v vendor))
for dir in "${packages[@]}"; do
    relative_dir=${dir#"$PWD/"}    
    gocyclo "${relative_dir}" | tee -a "$OUTPUT_FILE"
done
echo "Análisis de complejidad completado. Resultados guardados en ${OUTPUT_FILE}" >&2