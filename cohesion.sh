#!/bin/bash

REPO_PATH=$1
OUTPUT_FILE=$2

if [ -z "$REPO_PATH" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Se requieren 2 argumentos: <ruta_del_repo> <ruta_del_output>" >&2
    echo "Uso: $0 /path/to/repo /path/to/cohesion.out" >&2
    exit 1
fi

if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$PWD/$OUTPUT_FILE"
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"
> "${OUTPUT_FILE}"

echo "file loc func_count method_count" | tee -a "$OUTPUT_FILE"

cd "$REPO_PATH" || { echo "Error: No se pudo entrar al directorio $REPO_PATH" >&2; exit 1; }
echo "Calculando métricas de cohesión (separadas)... (en $PWD)" >&2

packages_dirs=($(go list -f '{{.Dir}}' ./... | grep -v vendor))

for dir in "${packages_dirs[@]}"; do
    relative_dir=${dir#"$PWD/"}
    all_files=($(find "${relative_dir}" -maxdepth 1 -name "*.go" 2>/dev/null))
    for file in "${all_files[@]}"; do
        loc=$(wc -l < "${file}" | xargs)
        method_count=$(grep -c "^func (" "${file}" | xargs)
        total_count=$(grep -c "^func " "${file}" | xargs)
        function_count=$((total_count - method_count))
        echo "${file} ${loc} ${function_count} ${method_count}" | tee -a "$OUTPUT_FILE"
    done
done
echo "Análisis completado." >&2
echo "Resultados guardados en ${OUTPUT_FILE}" >&2
echo "---" >&2
echo "Para encontrar 'Cajones de Sastre' (ordenar por func_count):" >&2
echo "sort -nr -k3 ${OUTPUT_FILE} | head -n 10" >&2
echo "Para encontrar 'God Objects' (ordenar por method_count):" >&2
echo "sort -nr -k4 ${OUTPUT_FILE} | head -n 10" >&2