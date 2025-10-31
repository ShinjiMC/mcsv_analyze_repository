#!/bin/bash

REPO_PATH=$1
OUTPUT_FILE=$2
TIME_WINDOW="9 months ago"

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

declare -A head_files_map
while IFS= read -r file; do
    head_files_map["$file"]=1
done < <(git -C "$REPO_PATH" ls-files --exclude-standard "*.go" | grep -v "^vendor/")
echo "--- (Encontrados ${#head_files_map[@]} archivos .go en HEAD) ---" >&2

declare -A added_map
declare -A removed_map

echo "--- (Calculando churn ac|umulativo de los últimos $TIME_WINDOW desde HEAD) ---" >&2

while read -r added removed file; do
    # --- FIX ---
    # Si 'file' está vacío (porque 'read' leyó una línea en blanco),
    # salta esta iteración.
    if [ -z "$file" ]; then
        continue
    fi
    # --- FIN FIX ---

    if [[ -n "${head_files_map[$file]}" ]]; then # Esta era tu línea 33
        [[ "$added" =~ ^[0-9]+$ ]] || added=0
        [[ "$removed" =~ ^[0-9]+$ ]] || removed=0
        added_map["$file"]=$(( ${added_map[$file]:-0} + added ))
        removed_map["$file"]=$(( ${removed_map[$file]:-0} + removed ))
    fi
done < <(git -C "$REPO_PATH" log --since="$TIME_WINDOW" --numstat --pretty=format:"" -- "*.go" | grep -v "^vendor/")

# Este bloque estaba duplicado en tu script, lo elimino para limpiar
# all_go_files=($(git -C "$REPO_PATH" ls-files --exclude-standard "*.go" | grep -v "^vendor/"))
# echo "--- (Encontrados ${#all_go_files[@]} archivos .go) ---" >&2

echo "--- (Generando reporte final) ---" >&2

for file in "${!head_files_map[@]}"; do
    added=${added_map[$file]:-0}
    removed=${removed_map[$file]:-0}
    total=$((added + removed))
    
    echo "$file $added $removed $total" | tee -a "$OUTPUT_FILE"
done

echo "--- (Análisis de churn acumulativo completado) ---" >&2