#!/bin/bash

REPO_PATH=$1
OUTPUT_FILE=$2

if [ -z "$REPO_PATH" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Se requieren 2 argumentos: <ruta_del_repo> <ruta_del_output>" >&2
    echo "Uso: $0 /path/to/repo /path/to/halstead.out" >&2
    exit 1
fi

# if ! command -v halstead &> /dev/null; then
#     echo "Error: La herramienta 'halstead' no se encuentra en el PATH." >&2
#     echo "Por favor, instálala primero con:" >&2
#     echo "go install github.com/luisantonioig/halstead-metrics/cmd/halstead@latest" >&2
#     exit 1
# fi

if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$PWD/$OUTPUT_FILE"
fi
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"
> "${OUTPUT_FILE}"

echo "file_path distinct_operators distinct_operands total_operators total_operands calculated_length volume difficulty effort time bugs" > "${OUTPUT_FILE}"
AWK_SCRIPT='
BEGIN {
    dist_op=0; dist_ond=0; total_op=0; total_ond=0; len=0; vol=0; diff=0; effort=0; time=0; bugs=0;
}
/^Existen .* operadores diferentes/ { dist_op = $2 }
/^Existen .* operandos diferentes/ { dist_ond = $2 }
/^El codigo tiene/ { total_ond = $4; total_op = $7 }
/^El tamaño calculado/ { len = $7; vol = $12 }
/^La dificultad del programa es/ { diff = $6 }
/^El esfuerzo del programa es/ { effort = $6 }
/^El tiempo requerido para programar es/ { time = $7 }
/^El numero de bugs es/ { bugs = $6 }
END {
    print file, dist_op, dist_ond, total_op, total_ond, len, vol, diff, effort, time, bugs
}
'

cd "$REPO_PATH" || { echo "Error: No se pudo entrar al directorio $REPO_PATH" >&2; exit 1; }
echo "Calculando métricas de Halstead (halstead)... (en $PWD)" >&2

packages=($(go list -f '{{.Dir}}' ./... | grep -v vendor))

for dir in "${packages[@]}"; do
    relative_dir=${dir#"$PWD/"}
    echo "Procesando paquete: ${relative_dir}" >&2
    go_files=($(find "${relative_dir}" -maxdepth 1 -name "*.go" 2>/dev/null))
    if [ ${#go_files[@]} -gt 0 ]; then
        for file in "${go_files[@]}"; do
            echo "  -> Procesando archivo: ${file}" >&2
            halstead_output=$(halstead "${file}" || true)
            if [ -n "$halstead_output" ]; then
                echo "$halstead_output" | awk -v file="${file}" "$AWK_SCRIPT" >> "${OUTPUT_FILE}"
            else
                echo "     (Saltando ${file}, vacío o con error)" >&2
            fi
        done
        
    else
        echo "  (No se encontraron archivos .go en ${relative_dir}, saltando)" >&2
    fi
done

echo "Análisis de Halstead completado. Resultados guardados en ${OUTPUT_FILE}" >&2