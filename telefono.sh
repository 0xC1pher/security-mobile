#!/data/data/com.termux/files/usr/bin/bash

# Redirigir toda la salida a un archivo de registro
exec > >(tee -a script.log) 2>&1

# Configurar el idioma para caracteres UTF-8
export LANG=en_US.UTF-8

# Función para instalar dependencias
install_deps() {
    echo "Verificando dependencias..."
    missing=0
    for pkg in curl jq base64 openssl; do
        if ! command -v $pkg >/dev/null 2>&1; then
            echo "Instalando $pkg..."
            pkg install -y $pkg || { echo "Fallo al instalar $pkg. Saliendo."; exit 1; }
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        echo "Dependencias instaladas exitosamente."
    else
        echo "Todas las dependencias ya están instaladas."
    fi
}

# Función para analizar una URL
analyze_url() {
    local url=$1
    if [[ ! $url =~ ^https?://.* ]]; then
        echo "Formato de URL inválido."
        return
    fi
    local response=$(curl -s "https://www.virustotal.com/api/v3/urls" \
        -H "x-apikey:$API_KEY" \
        -F "url=$url")
    local status=$(echo $response | jq -r '.error.message // ""')
    if [ "$status" != "" ]; then
        echo "Error: $status"
        return
    fi
    local analysis_id=$(echo $response | jq -r '.data.id')
    echo "Esperando análisis..."
    while true; do
        local report=$(curl -s "https://www.virustotal.com/api/v3/analyses/$analysis_id" \
            -H "x-apikey:$API_KEY")
        local status=$(echo $report | jq -r '.data.attributes.status')
        if [ "$status" == "completed" ]; then
            break
        fi
        sleep 5
    done
    echo "Análisis para URL: $url"
    echo "Malicioso: $(echo $report | jq -r '.data.attributes.stats.malicious')"
    echo "No detectado: $(echo $report | jq -r '.data.attributes.stats.undetected')"
}

# Función para analizar un archivo
analyze_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "Archivo no encontrado."
        return
    fi
    local file_data=$(base64 $file)
    local response=$(curl -s "https://www.virustotal.com/api/v3/files" \
        -H "x-apikey:$API_KEY" \
        -F "file=$file_data")
    local status=$(echo $response | jq -r '.error.message // ""')
    if [ "$status" != "" ]; then
        echo "Error: $status"
        return
    fi
    local analysis_id=$(echo $response | jq -r '.data.id')
    echo "Esperando análisis..."
    while true; do
        local report=$(curl -s "https://www.virustotal.com/api/v3/analyses/$analysis_id" \
            -H "x-apikey:$API_KEY")
        local status=$(echo $report | jq -r '.data.attributes.status')
        if [ "$status" == "completed" ]; then
            break
        fi
        sleep 5
    done
    echo "Análisis para archivo: $file"
    echo "Malicioso: $(echo $report | jq -r '.data.attributes.stats.malicious')"
    echo "No detectado: $(echo $report | jq -r '.data.attributes.stats.undetected')"
}

# Función para manejar la seguridad de sesiones y cookies
handle_session_security() {
    echo "Opciones de seguridad de sesiones y cookies:"
    echo "1. Borrar cookies"
    echo "2. Usar modo incógnito"
    echo "3. Salir"
    read choice
    case $choice in
        1)
            if [ -d ~/.termux/share/cookies ]; then
                rm -rf ~/.termux/share/cookies
                echo "Cookies borradas."
            else
                echo "Directorio de cookies no encontrado."
            fi
            ;;
        2)
            echo "Abriendo navegador en modo incógnito..."
            termux-open-url --incognito "https://www.google.com"
            ;;
        3)
            echo "Saliendo..."
            ;;
        *)
            echo "Opción inválida."
            ;;
    esac
}

# Función para crear un entorno sandbox
create_sandbox() {
    if ! command -v proot-distro >/dev/null 2>&1; then
        echo "proot-distro no encontrado. Instalando..."
        pkg install -y proot-distro
    fi
    if proot-distro list | grep -q "debian"; then
        echo "Entorno Debian ya existe."
    else
        echo "Creando entorno Debian..."
        proot-distro install debian
    fi
    echo "Ingresando al entorno Debian..."
    proot-distro login debian
}

# Script principal
install_deps

echo "Ingresa tu clave API de VirusTotal:"
read -s API_KEY
echo

while true; do
    echo "Selecciona una opción:"
    echo "1. Analizar una URL"
    echo "2. Analizar un archivo"
    echo "3. Manejar seguridad de sesiones y cookies"
    echo "4. Crear entorno sandbox"
    echo "5. Salir"
    read choice

    case $choice in
        1)
            echo "Ingresa la URL a analizar:"
            read url
            analyze_url $url
            ;;
        2)
            echo "Ingresa la ruta del archivo a analizar:"
            read file
            analyze_file $file
            ;;
        3)
            handle_session_security
            ;;
        4)
            create_sandbox
            ;;
        5)
            echo "Saliendo..."
            break
            ;;
        *)
            echo "Opción inválida. Por favor, selecciona nuevamente."
            ;;
    esac
done
