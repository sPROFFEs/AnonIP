#!/bin/bash

# Configuración por defecto
DEFAULT_INTERVAL=1800  # 30 minutos
CHANGE_MAC=false
CHANGE_IP=false
USE_TOR=false
INTERFACE=""
TOR_USER="debian-tor"

# Configuración de TOR
TORRC="/etc/tor/torghostrc"
RESOLV="/etc/resolv.conf"
TORRC_CONFIG="
VirtualAddrNetwork 10.0.0.0/10
AutomapHostsOnResolve 1
TransPort 9040
DNSPort 5353
ControlPort 9051
RunAsDaemon 1
"
DNS_CONFIG="nameserver 127.0.0.1"

# Función de ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo "Opciones:"
    echo "  -h, --help           Muestra esta ayuda"
    echo "  -i, --interface      Especifica la interfaz de red (ej: wlan0)"
    echo "  -t, --time           Intervalo en segundos entre cambios"
    echo "  -m, --mac            Activa el cambio de dirección MAC"
    echo "  -p, --ip             Activa el cambio de dirección IP"
    echo "  -T, --tor            Activa el enrutamiento por TOR"
    echo "  -s, --switch-tor     Cambia el nodo de salida de TOR"
    echo "  -x, --stop           Detiene todos los servicios"
    echo ""
    echo "Ejemplo:"
    echo "  $0 -i wlan0 -t 600 -m -p -T"
    echo "  (Cambia MAC, IP y usa TOR cada 10 minutos en wlan0)"
}

# Función para obtener IP pública actual
get_current_ip() {
    curl -s https://api.ipify.org/?format=json | grep -o '"ip":"[^"]*' | cut -d'"' -f4
}

# Función para generar una dirección MAC aleatoria
generate_random_mac() {
    printf '02:%02x:%02x:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# Configurar TOR
setup_tor() {
    echo "📡 Configurando TOR..."
    
    # Backup del DNS original
    cp $RESOLV ${RESOLV}.backup

    # Configurar archivo torrc
    echo "$TORRC_CONFIG" > $TORRC
    
    # Configurar DNS
    echo "$DNS_CONFIG" > $RESOLV
    
    # Detener servicios TOR existentes
    systemctl stop tor
    fuser -k 9051/tcp > /dev/null 2>&1
    
    # Iniciar TOR con nueva configuración
    sudo -u $TOR_USER tor -f $TORRC > /dev/null 2>&1 &
    
    # Configurar iptables para TOR
    NON_TOR="192.168.1.0/24 192.168.0.0/24"
    TOR_UID=$(id -ur $TOR_USER)
    TRANS_PORT="9040"

    # Limpiar reglas existentes
    iptables -F
    iptables -t nat -F

    # Configurar nuevas reglas
    iptables -t nat -A OUTPUT -m owner --uid-owner $TOR_UID -j RETURN
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
    
    for NET in $NON_TOR 127.0.0.0/9 127.128.0.0/10; do
        iptables -t nat -A OUTPUT -d $NET -j RETURN
    done
    
    iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports $TRANS_PORT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    for NET in $NON_TOR 127.0.0.0/8; do
        iptables -A OUTPUT -d $NET -j ACCEPT
    done
    
    iptables -A OUTPUT -m owner --uid-owner $TOR_UID -j ACCEPT
    iptables -A OUTPUT -j REJECT

    echo "✅ TOR configurado y activado"
}

# Función para cambiar nodo de salida de TOR
switch_tor_node() {
    echo "🔄 Cambiando nodo de salida TOR..."
    # Usar el puerto de control de TOR para solicitar nuevo circuito
    echo -e "AUTHENTICATE\r\nSIGNAL NEWNYM\r\nQUIT" | nc 127.0.0.1 9051
    sleep 5  # Esperar a que se establezca el nuevo circuito
    echo "✅ Nodo de salida cambiado"
}

# Detener TOR y restaurar configuración
stop_tor() {
    echo "🛑 Deteniendo TOR..."
    
    # Restaurar DNS original
    if [ -f ${RESOLV}.backup ]; then
        mv ${RESOLV}.backup $RESOLV
    fi
    
    # Limpiar iptables
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t nat -F
    iptables -t mangle -F
    iptables -F
    iptables -X
    
    # Detener proceso TOR
    fuser -k 9051/tcp > /dev/null 2>&1
    systemctl stop tor
    
    echo "✅ TOR detenido y configuración restaurada"
}

# Función para cambiar la dirección MAC
change_mac() {
    local interface=$1
    local new_mac=$(generate_random_mac)
    
    echo "📱 Cambiando dirección MAC de $interface..."
    ip link set dev $interface down
    ip link set dev $interface address $new_mac
    ip link set dev $interface up
    
    echo "✅ Nueva MAC: $new_mac"
}

# Función para cambiar la IP
change_ip() {
    local interface=$1
    echo "🌐 Cambiando dirección IP de $interface..."
    
    dhclient -r $interface
    dhclient $interface
    
    local new_ip=$(ip addr show dev $interface | grep 'inet ' | awk '{print $2}')
    echo "✅ Nueva IP local: $new_ip"
}

# Verificar permisos de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Este script debe ejecutarse como root"
        exit 1
    fi
}

# Verificar que la interfaz existe
check_interface() {
    if ! ip link show "$1" >/dev/null 2>&1; then
        echo "❌ La interfaz $1 no existe"
        exit 1
    fi
}

# Verificar dependencias
check_dependencies() {
    local deps=("tor" "curl" "dhclient" "iptables")
    for dep in "${deps[@]}"; do
        if ! command -v $dep >/dev/null 2>&1; then
            echo "❌ Falta dependencia: $dep"
            echo "📦 Instala el paquete usando: apt install $dep"
            exit 1
        fi
    done
}

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -t|--time)
            DEFAULT_INTERVAL="$2"
            shift 2
            ;;
        -m|--mac)
            CHANGE_MAC=true
            shift
            ;;
        -p|--ip)
            CHANGE_IP=true
            shift
            ;;
        -T|--tor)
            USE_TOR=true
            shift
            ;;
        -s|--switch-tor)
            switch_tor_node
            exit 0
            ;;
        -x|--stop)
            stop_tor
            exit 0
            ;;
        *)
            echo "❌ Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Función principal
main() {
    check_root
    check_dependencies
    
    # Si no se especificó una interfaz, detectar la principal
    if [[ -z "$INTERFACE" ]]; then
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        echo "🔍 Usando interfaz detectada: $INTERFACE"
    fi
    
    check_interface "$INTERFACE"
    
    # Verificar que se haya seleccionado al menos una opción
    if ! $CHANGE_MAC && ! $CHANGE_IP && ! $USE_TOR; then
        echo "❌ Debes especificar al menos una opción (-m para MAC, -p para IP, o -T para TOR)"
        show_help
        exit 1
    fi
    
    echo "🚀 Iniciando script con la siguiente configuración:"
    echo "- Interfaz: $INTERFACE"
    echo "- Intervalo: $DEFAULT_INTERVAL segundos"
    echo "- Cambiar MAC: $CHANGE_MAC"
    echo "- Cambiar IP: $CHANGE_IP"
    echo "- Usar TOR: $USE_TOR"
    echo ""
    
    if $USE_TOR; then
        setup_tor
    fi
    
    while true; do
        echo "⏰ $(date): Iniciando cambios..."
        
        if $CHANGE_MAC; then
            change_mac "$INTERFACE"
        fi
        
        if $CHANGE_IP; then
            change_ip "$INTERFACE"
        fi
        
        if $USE_TOR; then
            echo "🌍 IP pública actual: $(get_current_ip)"
            switch_tor_node
            echo "🌍 Nueva IP pública: $(get_current_ip)"
        fi
        
        echo "💤 Esperando $DEFAULT_INTERVAL segundos..."
        sleep $DEFAULT_INTERVAL
    done
}

# Manejar señal de interrupción
trap 'echo "⚠️ Deteniendo servicios..."; stop_tor; exit' INT

# Inicia el script
main
