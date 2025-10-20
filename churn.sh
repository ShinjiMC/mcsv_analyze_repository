#!/bin/bash

REPO_PATH=$1
OUTPUT_FILE=$2
PARENT_COMMIT=$3
CURRENT_COMMIT="HEAD"

if [ -z "$REPO_PATH" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Se requieren 2 argumentos: <ruta_del_repo> <ruta_del_output>" >&2
    echo "Uso: $0 /path/to/repo /path/to/churn.out [SHA_padre]" >&2
    exit 1
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"
> "${OUTPUT_FILE}"

echo "file added deleted total" | tee -a "$OUTPUT_FILE"

echo "--- (Obteniendo lista de archivos .go en HEAD) ---" >&2
all_go_files=($(git -C "$REPO_PATH" ls-files --exclude-standard "*.go" | grep -v "^vendor/"))
echo "--- (Encontrados ${#all_go_files[@]} archivos .go) ---" >&2

declare -A churn_map

if [ -n "$PARENT_COMMIT" ]; then
    echo "--- (Comparando HEAD con ${PARENT_COMMIT:0:7}) ---" >&2
    
    while read -r added removed file; do
        if [[ "$file" == *.go ]]; then
            [[ "$added" =~ ^[0-9]+$ ]] || added=0
            [[ "$removed" =~ ^[0-9]+$ ]] || removed=0
            total=$((added + removed))
            churn_map["$file"]="$added $removed $total"
        fi
    done < <(git -C "$REPO_PATH" diff --numstat "$PARENT_COMMIT" "$CURRENT_COMMIT")

else
    echo "--- (Commit raíz, no hay churn) ---" >&2
fi

for file in "${all_go_files[@]}"; do
    if [ -n "${churn_map[$file]}" ]; then
        echo "$file ${churn_map[$file]}" | tee -a "$OUTPUT_FILE"
    else
        echo "$file 0 0 0" | tee -a "$OUTPUT_FILE"
    fi
done

echo "--- (Análisis de churn completado) ---" >&2