#!/bin/bash#
# setup_go.sh: Instala y activa la versión de Go de un proyecto usando 'g'.
#
# USO: source ./setup_go.sh /ruta/a/tu/proyecto
#
set -e
PROJECT_PATH=$1

if [ -z "$PROJECT_PATH" ]; then
    echo "Error: Debes pasar la ruta al proyecto." >&2
    echo "Uso: source $0 /path/to/project" >&2
    return 1
fi

if [[ "$PROJECT_PATH" != /* ]]; then
    PROJECT_PATH="$PWD/$PROJECT_PATH"
fi

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Ruta no válida o no es un directorio: $PROJECT_PATH" >&2
    return 1
fi

if ! command -v g &> /dev/null; then
    echo "Error: 'g' (voidint/g) no se encuentra en tu PATH." >&2
    echo "Por favor, instálalo primero:" >&2
    echo "  go install github.com/voidint/g/cmd/g@latest" >&2
    return 1
fi

# --- 3. Encontrar y Leer go.mod ---
GO_MOD_FILE="$PROJECT_PATH/go.mod"
if [ ! -f "$GO_MOD_FILE" ]; then
    echo "Error: No se encontró 'go.mod' en $PROJECT_PATH" >&2
    return 1
else
    # --- 4. Extraer Versión ---
    GO_VERSION=$(grep -m 1 "^go " "$GO_MOD_FILE" | awk '{print $2}')

    if [ -z "$GO_VERSION" ]; then
        echo "Error: No se pudo encontrar la directiva 'go' en $GO_MOD_FILE" >&2
    else
        echo "El proyecto requiere Go: $GO_VERSION" >&2 # Log a stderr
        # --- 5. Instalar y Cambiar ---
        echo "Verificando instalación..." >&2
        if ! g ls | grep -q -w "$GO_VERSION"; then
            echo "Instalando Go $GO_VERSION..." >&2
            g install "$GO_VERSION"
        else
            echo "Go $GO_VERSION ya está instalado." >&2
        fi

        echo "Activando Go $GO_VERSION..." >&2
        g use "$GO_VERSION"

        G_ENV_FILE="$HOME/.g/env"

        if [ ! -f "$G_ENV_FILE" ]; then
            echo "Error: 'g use' se ejecutó, pero el archivo $G_ENV_FILE no existe." >&2
            echo "Algo está mal con tu instalación de 'g'." >&2
            return 1
        fi

        # Load the environment for subsequent commands in *this* script/shell
        . "$G_ENV_FILE"

        echo "---" >&2
        echo "¡Listo! Versión de Go activa:" >&2
        go version >&2 # Log a stderr
        #--- Instalar herramientas de análisis ---
        echo "Verificando herramientas de análisis en Go $GO_VERSION..." >&2
        # Verificar gocyclo
        if ! command -v gocyclo &> /dev/null; then
            echo "Instalando gocyclo..." >&2
            go install github.com/fzipp/gocyclo/cmd/gocyclo@latest
        else
            echo "✔ gocyclo ya está instalado." >&2
        fi

        # Verificar golangci-lint
        if ! command -v golangci-lint &> /dev/null; then
            echo "Instalando golangci-lint..." >&2
            go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
        else
            echo "✔ golangci-lint ya está instalado." >&2
        fi

        # Verificar halstead
        if ! command -v halstead &> /dev/null; then
            echo "Instalando halstead..." >&2
            go install github.com/luisantonioig/halstead-metrics/cmd/halstead@latest
        else
            echo "✔ halstead ya está instalado." >&2
        fi

        echo "---" >&2
        echo "Herramientas disponibles:" >&2
        command -v gocyclo >&2
        command -v golangci-lint >&2
        command -v halstead >&2

        echo "Entorno Go $GO_VERSION listo con herramientas de análisis." >&2
    fi
fi