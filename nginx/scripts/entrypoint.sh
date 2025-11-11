#!/bin/sh

set -e

# Environment variables with defaults
CERT_DIR="${CERT_DIR:-/etc/nginx/certs}"
CERT_FILE_NAME="${CERT_FILE_NAME:-localhost.crt}"
KEY_FILE_NAME="${KEY_FILE_NAME:-localhost.key}"
CERT_FILE="$CERT_DIR/$CERT_FILE_NAME"
KEY_FILE="$CERT_DIR/$KEY_FILE_NAME"

CERT_VALIDITY_DAYS="${CERT_VALIDITY_DAYS:-365}"
CERT_KEY_SIZE="${CERT_KEY_SIZE:-2048}"
CERT_RENEWAL_THRESHOLD_DAYS="${CERT_RENEWAL_THRESHOLD_DAYS:-30}"

CERT_COUNTRY="${CERT_COUNTRY:-PL}"
CERT_STATE="${CERT_STATE:-Mazovia}"
CERT_CITY="${CERT_CITY:-Warsaw}"
CERT_ORGANIZATION="${CERT_ORGANIZATION:-Dev}"

CERT_FILE_PERMISSIONS="${CERT_FILE_PERMISSIONS:-644}"
KEY_FILE_PERMISSIONS="${KEY_FILE_PERMISSIONS:-600}"

NGINX_CONFIG_TEST="${NGINX_CONFIG_TEST:-true}"
NGINX_DAEMON_MODE="${NGINX_DAEMON_MODE:-off}"


echo "Checking OpenSSL installation..."
if ! command -v openssl > /dev/null 2>&1; then
    echo "OpenSSL not found, installing..."
    apk add --no-cache openssl
fi

openssl version

echo "CN set as $SERVER_HOSTNAME"
echo "Certificate will be valid for $CERT_VALIDITY_DAYS days"
echo "Renewal threshold: $CERT_RENEWAL_THRESHOLD_DAYS days"

generate_certs() {
    echo "Generating SSL certificates..."
    echo "Key size: $CERT_KEY_SIZE bits"
    echo "Subject: /C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORGANIZATION/CN=${SERVER_HOSTNAME}"
    
    mkdir -p "$CERT_DIR"
    
    openssl req -x509 -nodes -days "$CERT_VALIDITY_DAYS" -newkey "rsa:$CERT_KEY_SIZE" \
      -keyout "$KEY_FILE" \
      -out "$CERT_FILE" \
      -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORGANIZATION/CN=${SERVER_HOSTNAME}" 2>&1
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        chmod "$CERT_FILE_PERMISSIONS" "$CERT_FILE"
        chmod "$KEY_FILE_PERMISSIONS" "$KEY_FILE"
        echo "Certificates generated successfully"
        echo "Certificate: $CERT_FILE (permissions: $CERT_FILE_PERMISSIONS)"
        echo "Private key: $KEY_FILE (permissions: $KEY_FILE_PERMISSIONS)"
        return 0
    else
        echo "Error generating certificates (exit code: $result)"
        return 1
    fi
}

check_certificate_age() {
    if [ ! -f "$CERT_FILE" ]; then
        echo "Certificate file not found"
        return 1
    fi
    
    if command -v stat > /dev/null 2>&1; then
        CERT_AGE=$(( $(date +%s) - $(stat -c %Y "$CERT_FILE" 2>/dev/null || echo 0) ))
        DAYS_OLD=$(( CERT_AGE / 86400 ))
        
        if [ $DAYS_OLD -gt 0 ]; then
            echo "Certificate age: $DAYS_OLD days"
            
            if [ $DAYS_OLD -gt "$CERT_RENEWAL_THRESHOLD_DAYS" ]; then
                echo "Certificate older than $CERT_RENEWAL_THRESHOLD_DAYS days, regenerating..."
                return 1
            fi
        fi
    fi
    
    return 0
}

# Main certificate logic
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Certificates not found, generating new ones..."
    if ! generate_certs; then
        echo "Failed to generate certificates"
        sleep 5
        exit 1
    fi
else
    echo "Certificates exist, checking age..."
    if ! check_certificate_age; then
        if ! generate_certs; then
            echo "Failed to regenerate certificates, using existing ones"
        fi
    else
        echo "Certificates are still valid"
    fi
fi

echo "Generating nginx config from template..."
if [ -f /etc/nginx/nginx.conf.template ]; then
    envsubst '$DOMAIN $SERVER_HOSTNAME' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
    echo "Generated nginx config - server names:"
    grep 'server_name' /etc/nginx/nginx.conf || echo "No server_name found"
    
    # Test nginx configuration
    echo "Testing nginx configuration..."
    if [ "$NGINX_CONFIG_TEST" = "true" ]; then
        echo "Testing Nginx configuration..."
        nginx -t
        if [ $? -ne 0 ]; then
            echo "ERROR: nginx configuration test failed!"
            exit 1
        fi
    fi

    echo "nginx configuration test passed"
else
    echo "WARNING: nginx.conf.template not found, using default config"
fi

# Test Nginx configuration if enabled
if [ "$NGINX_CONFIG_TEST" = "true" ]; then
    echo "Testing Nginx configuration..."
    nginx -t
fi


echo "Starting Nginx..."
exec nginx -g "daemon $NGINX_DAEMON_MODE;"