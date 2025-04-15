#!/bin/bash

# Carrega variáveis do .env
if [ ! -f .env ]; then
    echo "Arquivo .env não encontrado!"
    exit 1
fi

source .env

PORT=${PORT:-8080}

if [ "$PORT" -lt 1024 ]; then
    echo "❌ A porta definida ($PORT) é privilegiada. Use uma porta >= 1024 para evitar 'sudo'."
    exit 1
fi

# IP da interface especificada ou fallback
if [ -n "$INTERFACE" ]; then
    IP=$(ip -o -4 addr show "$INTERFACE" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    if [ -z "$IP" ]; then
        echo "⚠️  Interface $INTERFACE não encontrada ou sem IP."
        exit 1
    fi
else
    IP=$(hostname -I | awk '{print $1}')
fi

TEMP_DIR=$(mktemp -d)

echo "🔧 Copiando scripts para diretório temporário: $TEMP_DIR"
echo

# Copia arquivos mantendo a estrutura com diretório base
for DIR in $SCRIPT_DIRS; do
    if [ -d "$DIR" ]; then
        BASE_NAME=$(basename "$DIR")
        find "$DIR" -type f | while read -r FILE; do
            REL_PATH="${FILE#$DIR/}"
            DEST_PATH="$TEMP_DIR/$BASE_NAME/$REL_PATH"
            mkdir -p "$(dirname "$DEST_PATH")"
            cp "$FILE" "$DEST_PATH"
        done
    else
        echo "⚠️  Diretório não encontrado: $DIR"
    fi
done

# Agrupar por diretório e exibir de forma mais amigável
echo "📥 Comandos wget para download organizados por diretório:"
echo

find "$TEMP_DIR" -type f | sort | while read -r FILE; do
    RELATIVE_PATH="${FILE#$TEMP_DIR/}"
    DIR_NAME=$(dirname "$RELATIVE_PATH")
    FILE_NAME=$(basename "$RELATIVE_PATH")
    WGET_LINK="wget http://$IP:$PORT/$RELATIVE_PATH"

    if [[ "$LAST_DIR" != "$DIR_NAME" ]]; then
        echo
        echo "📁 $DIR_NAME"
        LAST_DIR="$DIR_NAME"
    fi

    echo "   └── $WGET_LINK"
done

echo
echo "🚀 Iniciando servidor HTTP em http://$IP:$PORT"
cd "$TEMP_DIR" || exit
python3 -m http.server "$PORT"
