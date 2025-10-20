#!/bin/bash

REPO_PATH=$1
OUTPUT_FILE=$2

if [ -z "$REPO_PATH" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Se requieren 2 argumentos: <ruta_del_repo> <ruta_del_output>" >&2
    echo "Uso: $0 /path/to/repo /path/to/lint.out" >&2
    exit 1
fi

if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$PWD/$OUTPUT_FILE"
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"
> "${OUTPUT_FILE}"

cd "$REPO_PATH" || { echo "Error: No se pudo entrar al directorio $REPO_PATH" >&2; exit 1; }
echo "Ejecutando linter (golangci-lint)... (en $PWD)" >&2

packages=($(go list -f '{{.Dir}}' ./... | grep -v vendor))

for dir in "${packages[@]}"; do
    relative_dir=${dir#"$PWD/"}
    lint_output=$(golangci-lint run --fix=false "${relative_dir}")
    all_files=($(find "${relative_dir}" -maxdepth 1 -name "*.go" 2>/dev/null))
    summary_only=$(echo "$lint_output" | grep -E '^[0-9]+ issues:|^\* ')
    errors_only=$(echo "$lint_output" | grep -E '^[a-zA-Z0-9_/.-]+\.go:')
    for file in "${all_files[@]}"; do
        # Filtra los errores de este archivo
        file_errors=$(echo "$errors_only" | grep "^${file}:")
        if [ -n "$file_errors" ]; then
            {
                echo "${file}"
                echo "$summary_only"
                while IFS= read -r line; do
                    echo "$line"
                    echo "$lint_output" | awk -v pattern="$line" '
                        $0 == pattern {p=1; next}
                        p && /^[[:space:]]/ {print; next}
                        p && /^\^/ {print; next}
                        p && !/^[[:space:]]|\^/ {p=0}
                    '
                done <<< "$file_errors"
            } | tee -a "$OUTPUT_FILE"
        else
            {
                echo "${file}"
                echo "0 issues"
            } | tee -a "$OUTPUT_FILE"
        fi
    done
done
echo "Análisis de Linter completado. Resultados guardados en ${OUTPUT_FILE}" >&2