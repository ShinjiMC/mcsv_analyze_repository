#!/bin/bash

REPO_PATH=$1
OUTPUT_FILE=$2
TIME_WINDOW="9 months ago"

if [ -z "$REPO_PATH" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Se requieren 2 argumentos: <ruta_del_repo> <ruta_del_output>" >&2
    echo "Uso: $0 /path/to/repo /path/to/churn.out" >&2
    exit 1
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"
> "${OUTPUT_FILE}"

# --- MODIFICACIÓN: Nuevo encabezado ---
echo "file added deleted total frequency authors" | tee -a "$OUTPUT_FILE"

# --- (PASO 1: Obtener lista de archivos .go en HEAD - SIN CAMBIOS) ---
echo "--- (Obteniendo lista de archivos .go en HEAD) ---" >&2
declare -A head_files_map
while IFS= read -r file; do
    head_files_map["$file"]=1
done < <(git -C "$REPO_PATH" ls-files --exclude-standard "*.go" | grep -v "^vendor/")
echo "--- (Encontrados ${#head_files_map[@]} archivos .go en HEAD) ---" >&2

# --- (PASO 2: Calcular Churn/Magnitud - SIN CAMBIOS) ---
echo "--- (Calculando churn acumulativo de los últimos $TIME_WINDOW) ---" >&2
declare -A added_map
declare -A removed_map
while read -r added removed file; do
    if [ -z "$file" ]; then
        continue
    fi
    if [[ -n "${head_files_map[$file]}" ]]; then
        [[ "$added" =~ ^[0-9]+$ ]] || added=0
        [[ "$removed" =~ ^[0-9]+$ ]] || removed=0
        added_map["$file"]=$(( ${added_map[$file]:-0} + added ))
        removed_map["$file"]=$(( ${removed_map[$file]:-0} + removed ))
    fi
done < <(git -C "$REPO_PATH" log --since="$TIME_WINDOW" --numstat --pretty=format:"" -- "*.go" | grep -v "^vendor/")

# --- (PASO 3: Calcular Frecuencia y Autores - NUEVO BLOQUE) ---
echo "--- (Calculando Frecuencia y Autores de los últimos $TIME_WINDOW) ---" >&2
# Usaremos "sets" para almacenar pares únicos
declare -A author_file_set
declare -A commit_file_set
# Usamos un separador que no esté en emails ni en rutas
SEP="|||"

current_sha=""
current_author=""

# Ejecutamos git log UNA vez para obtener SHA, autor y archivos
# Formato: _C_SHA_AUTOR (ej. _C_a1b2c3d_autor@email.com)
# Seguido por los archivos de ese commit
while IFS= read -r line; do
    if [[ "$line" == _C_* ]]; then
        # Es una línea de control. Separamos el SHA y el Autor
        line_no_prefix=${line:3}
        current_sha=${line_no_prefix%%_A_*}
        current_author=${line_no_prefix#*_A_}
    elif [[ -n "$line" && -n "$current_sha" && -n "$current_author" ]]; then
        # Es una línea de archivo, la procesamos
        file="$line"
        if [[ -n "${head_files_map[$file]}" ]]; then
            # Añadimos al "set" de autores y al "set" de commits
            author_file_set["$file$SEP$current_author"]=1
            commit_file_set["$file$SEP$current_sha"]=1
        fi
    fi
done < <(git -C "$REPO_PATH" log --since="$TIME_WINDOW" --pretty=format:"_C_%H_A_%ae" --name-only -- "*.go" | grep -v "^vendor/")

# Ahora contamos los pares únicos que encontramos
declare -A frequency_map
declare -A authors_map

for pair in "${!commit_file_set[@]}"; do
    file=${pair%|||*} # Extrae el 'file'
    frequency_map["$file"]=$(( ${frequency_map[$file]:-0} + 1 ))
done

for pair in "${!author_file_set[@]}"; do
    file=${pair%|||*} # Extrae el 'file'
    authors_map["$file"]=$(( ${authors_map[$file]:-0} + 1 ))
done
echo "--- (Cálculo de Frecuencia y Autores completado) ---" >&2

# --- (PASO 4: Generar reporte final - MODIFICADO) ---
echo "--- (Generando reporte final combinado) ---" >&2
for file in "${!head_files_map[@]}"; do
    added=${added_map[$file]:-0}
    removed=${removed_map[$file]:-0}
    total=$((added + removed))
    # Obtenemos los nuevos valores de los maps
    frequency=${frequency_map[$file]:-0}
    authors=${authors_map[$file]:-0}
    
    echo "$file $added $removed $total $frequency $authors" | tee -a "$OUTPUT_FILE"
done

echo "--- (Análisis combinado completado) ---" >&2