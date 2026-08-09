#!/bin/bash

# Script to generate Android keystore for CI/CD signing
# Run this locally, then encode the keystore for GitHub Secrets

set -e

KEYSTORE_NAME="keyflow_keystore.jks"
KEY_ALIAS="keyflow"
KEYSTORE_PASSWORD=$(openssl rand -base64 32)
KEY_PASSWORD=$(openssl rand -base64 32)

echo "Generating Android keystore..."
echo "Keystore: $KEYSTORE_NAME"
echo "Key Alias: $KEY_ALIAS"

# Generate keystore
keytool -genkey -v \
  -keystore $KEYSTORE_NAME \
  -alias $KEY_ALIAS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$KEYSTORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -dname "CN=KeyFlow, OU=Development, O=KeyFlow, L=SanFrancisco, ST=California, C=US"

echo ""
echo "✅ Keystore generated successfully!"
echo ""
echo "=== GITHUB SECRETS SETUP ==="
echo ""
echo "1. Encode the keystore for GitHub Secrets:"
echo "   base64 -i $KEYSTORE_NAME | pbcopy"
echo ""
echo "2. Add these secrets to your GitHub repository:"
echo ""
echo "   ANDROID_KEYSTORE: <paste base64 encoded keystore>"
echo "   ANDROID_KEYSTORE_PASSWORD: $KEYSTORE_PASSWORD"
echo "   ANDROID_KEY_PASSWORD: $KEY_PASSWORD"
echo "   ANDROID_KEY_ALIAS: $KEY_ALIAS"
echo ""
echo "3. Save the keystore and passwords securely!"
echo ""
echo "⚠️  WARNING: Keep the keystore file and passwords secure!"
echo "   Do not commit the keystore to version control!"