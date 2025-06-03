#!/bin/bash

# I used Claude 4 to review the code, this is done only for educational purpose as a tool to simplify the CI/CD process for the Software Engineering 4 HPC DevOps Project.

set -e  # Exit on any error

# Configuration
USER_EMAIL="$1"
GITHUB_OWNER="$2"
GITHUB_REPO="$3"
PASSPHRASE="${4:-}"  #  This can be optional 
KEY_NAME="my_key"
PROVISIONER="cineca-hpc"

# Nice colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sad no color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ -z "$USER_EMAIL" ] || [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
    print_error "Usage: $0 <user-email> <github-owner> <github-repo> [passphrase]"
    print_error "Example: $0 user@example.com myusername myrepo"
    exit 1
fi

# Check if the tools are installed
check_dependencies() {
    local missing_deps=()
    
    if ! command -v step &> /dev/null; then
        missing_deps+=("step (Smallstep CLI)")
    fi
    
    if ! command -v gh &> /dev/null; then
        missing_deps+=("gh (GitHub CLI)")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Install instructions:"
        echo "  - step: https://smallstep.com/docs/step-cli/installation/"
        echo "  - gh: https://cli.github.com/"
        exit 1
    fi
}

# Generate passphrase if not provided (https://docs.openssl.org/1.0.2/man1/rand/)
generate_passphrase() {
    if [ -z "$PASSPHRASE" ]; then
        print_status "Generating secure passphrase..."
        PASSPHRASE=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        print_warning "Generated passphrase: $PASSPHRASE"
        print_warning "Please save this passphrase securely!"
    fi
}

# Clean up existing files
cleanup_existing_files() {
    print_status "Cleaning up existing key files..."
    rm -f "$KEY_NAME" "${KEY_NAME}.pub" "${KEY_NAME}-cert.pub"
}

# Generate the SSH certificate
generate_ssh_certificate() {
    print_status "Generating SSH certificate for $USER_EMAIL..."
    
    # Use expect to automate the passphrase input(basically it simulates an interaction with the terminal)
    if command -v expect &> /dev/null; then
        expect << EOF
spawn step ssh certificate "$USER_EMAIL" --provisioner "$PROVISIONER" "$KEY_NAME"
expect "Please enter the passphrase to encrypt the private key:"
send "$PASSPHRASE\r"
expect eof
EOF
    else
        print_warning "expect not found. You'll need to enter the passphrase manually."
        step ssh certificate "$USER_EMAIL" --provisioner "$PROVISIONER" "$KEY_NAME"
    fi
}

# Verify generated files
verify_files() {
    local files=("$KEY_NAME" "${KEY_NAME}.pub" "${KEY_NAME}-cert.pub")
    
    print_status "Verifying generated files..."
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_status "✓ $file exists"
        else
            print_error "✗ $file not found"
            exit 1
        fi
    done
}

# GitHub CLI authenticationn
check_github_auth() {
    print_status "Checking GitHub CLI authentication..."
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI not authenticated. Run: gh auth login"
        exit 1
    fi
}

# Upload secrets to GitHub
upload_github_secrets() {
    print_status "Uploading secrets to GitHub repository $GITHUB_OWNER/$GITHUB_REPO..."
    
    # Read file
    local private_key=$(cat "$KEY_NAME")
    local public_key=$(cat "${KEY_NAME}.pub")
    local certificate=$(cat "${KEY_NAME}-cert.pub")
    
    # Upload secrets
    echo "$private_key" | gh secret set SSH_PRIVATE_KEY --repo "$GITHUB_OWNER/$GITHUB_REPO"
    echo "$public_key" | gh secret set SSH_PUBLIC_KEY --repo "$GITHUB_OWNER/$GITHUB_REPO"
    echo "$certificate" | gh secret set SSH_CERTIFICATE --repo "$GITHUB_OWNER/$GITHUB_REPO"
    
    # If specified, store the passphrase as a secret too
    echo "$PASSPHRASE" | gh secret set SSH_PASSPHRASE --repo "$GITHUB_OWNER/$GITHUB_REPO"
    
    print_status "✓ All secrets uploaded successfully!"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up local files..."
    rm -f "$KEY_NAME" "${KEY_NAME}.pub" "${KEY_NAME}-cert.pub"
    print_status "Local key files removed for security"
}

main() {
    print_status "Starting SSH certificate automation process..."
    
    check_dependencies
    generate_passphrase
    cleanup_existing_files
    generate_ssh_certificate
    verify_files
    check_github_auth
    upload_github_secrets
    
    print_status "Process completed successfully!"
    print_warning "The following secrets were added to your GitHub repository:"
    echo "  - SSH_PRIVATE_KEY"
    echo "  - SSH_PUBLIC_KEY" 
    echo "  - SSH_CERTIFICATE"
    echo "  - SSH_PASSPHRASE"
    
    # Ask if keep local files
    read -p "Do you want to keep the local key files? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        cleanup
    else
        print_warning "Local key files preserved in current directory"
    fi
}

main "$@"
