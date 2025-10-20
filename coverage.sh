#!/bin/bash

REPO_PATH=$1
OUTPUT_FILE=$2

if [ -z "$REPO_PATH" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Se requieren 2 argumentos: <ruta_del_repo> <ruta_del_output>" >&2
    echo "Uso: $0 /path/to/repo /path/to/coupling.out" >&2
    exit 1
fi

if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$PWD/$OUTPUT_FILE"
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"
echo "mode: set" > "${OUTPUT_FILE}"

cd "$REPO_PATH" || { echo "Error: No se pudo entrar al directorio $REPO_PATH" >&2; exit 1; }
echo "Calculando cobertura de tests (go test)... (en $PWD)" >&2

for d in $(go list ./... | grep -v vendor); do
    test_output=$(go test -coverprofile=profile.out -covermode=atomic "$d" 2>&1 || true)
    summary_line=$(echo "$test_output" | grep -F "$d" | grep "coverage:")
    if [ -n "$summary_line" ]; then
        echo "$summary_line" >> "$OUTPUT_FILE"
    fi
    if [ -f profile.out ]; then
        tail -n +2 profile.out >> "$OUTPUT_FILE"
        rm profile.out
    fi
    echo "$test_output" >&2
done
echo "Análisis de cobertura completado. Resultados guardados en ${OUTPUT_FILE}" >&2