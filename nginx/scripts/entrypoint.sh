#!/bin/sh

set -e

CERT_DIR="/etc/nginx/certs"
CERT_FILE="$CERT_DIR/localhost.crt"
KEY_FILE="$CERT_DIR/localhost.key"

echo "Checking OpenSSL installation..."
if ! command -v openssl > /dev/null 2>&1; then
    echo "OpenSSL not found, installing..."
    apk add --no-cache openssl
fi

openssl version

generate_certs() {
    echo "Generating SSL certificates..."
    
    mkdir -p "$CERT_DIR"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$KEY_FILE" \
      -out "$CERT_FILE" \
      -subj "/C=PL/ST=Mazovia/L=Warsaw/O=Dev/CN=${DOMAIN}" 2>&1
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        chmod 644 "$CERT_FILE"
        chmod 600 "$KEY_FILE"
        echo "Certificates generated successfully"
        echo "Certificate: $CERT_FILE"
        echo "Private key: $KEY_FILE"
        return 0
    else
        echo "Error generating certificates (exit code: $result)"
        return 1
    fi
}

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    if ! generate_certs; then
        echo "Failed to generate certificates"
        sleep 5
        exit 1
    fi
else
    echo "Certificates already exist"
    
    if command -v stat > /dev/null 2>&1; then
        CERT_AGE=$(( $(date +%s) - $(stat -c %Y "$CERT_FILE" 2>/dev/null || echo 0) ))
        DAYS_OLD=$(( CERT_AGE / 86400 ))
        
        if [ $DAYS_OLD -gt 0 ]; then
            echo "Certificate age: $DAYS_OLD days"
            
            if [ $DAYS_OLD -gt 30 ]; then
                echo "Certificate older than 30 days, regenerating..."
                if ! generate_certs; then
                    echo "Failed to regenerate certificates, using existing ones"
                fi
            fi
        fi
    fi
fi

echo "Testing Nginx configuration..."
nginx -t

echo "Starting Nginx..."
exec nginx -g 'daemon off;'