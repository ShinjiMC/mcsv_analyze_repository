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
> "${OUTPUT_FILE}"

echo "file num_dependency num_imports" | tee -a "$OUTPUT_FILE"
cd "$REPO_PATH" || { echo "Error: No se pudo entrar al directorio $REPO_PATH" >&2; exit 1; }
echo "Calculando métricas de acoplamiento (coupling)... (en $PWD)" >&2

# ---
# PARTE 1: Calcular el Fan-in (SIN CAMBIOS)
# (Ahora se ejecuta dentro de REPO_PATH)
# ---
declare -A fan_in_counts
import_list=$(go list -f '{{range .Imports}}{{.}}{{"\n"}}{{end}}' ./... | grep -v vendor)

while IFS= read -r imp; do
    if [[ -n "$imp" ]]; then
        fan_in_counts[$imp]=$(( ${fan_in_counts[$imp]} + 1 ))
    fi
done <<< "$import_list"

echo "Análisis de Fan-in completado. Ahora procesando archivos..." >&2

# ---
# PARTE 2: Iterar por cada archivo (SIN CAMBIOS)
# (Ahora se ejecuta dentro de REPO_PATH)
# ---
packages_dirs=($(go list -f '{{.Dir}}' ./... | grep -v vendor))

for dir in "${packages_dirs[@]}"; do
    pkg_name=$(go list "${dir}")
    pkg_fan_in=${fan_in_counts[${pkg_name}]:-0}
    relative_dir=${dir#"$PWD/"}
    all_files=($(find "${relative_dir}" -maxdepth 1 -name "*.go" 2>/dev/null))
    for file in "${all_files[@]}"; do
        file_fan_out=$(cat "${file}" | awk '
            /^import \($/ {in_import=1; next}
            /^import "/ {count++; next}
            /^\)$/ {in_import=0; next}
            in_import && /".+"/ {count++}
            END {print count+0}
        ')
        echo "${file} ${pkg_fan_in} ${file_fan_out}" | tee -a "$OUTPUT_FILE"
    done
done

echo "Análisis completado. Resultados guardados en ${OUTPUT_FILE}" >&2