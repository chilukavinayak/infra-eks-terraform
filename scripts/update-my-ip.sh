#!/bin/bash
# ============================================
# Update My IP Address in Terraform Variables
# Managed by Wissen Team
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Update your IP address in Terraform environment files for security group whitelist.

OPTIONS:
    -e, --environment   Environment to update (dev|staging|prod) [default: dev]
    -i, --ip            Specific IP address to use (e.g., 203.0.113.10) [default: auto-detect]
    -s, --ssh           Also allow SSH access from this IP
    -h, --help          Show this help message

EXAMPLES:
    # Update dev environment with auto-detected IP
    $0

    # Update production with specific IP
    $0 -e prod -i 203.0.113.10

    # Update with SSH access enabled
    $0 -e dev -s

EOF
}

# Default values
ENVIRONMENT="dev"
MY_IP=""
ENABLE_SSH=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -i|--ip)
            MY_IP="$2"
            shift 2
            ;;
        -s|--ssh)
            ENABLE_SSH=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_error "Must be one of: dev, staging, prod"
    exit 1
fi

# Get IP address
if [ -z "$MY_IP" ]; then
    print_info "Detecting your public IP address..."
    
    # Try multiple services to get IP
    MY_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || \
            curl -s --max-time 10 icanhazip.com 2>/dev/null || \
            curl -s --max-time 10 ipinfo.io/ip 2>/dev/null)
    
    if [ -z "$MY_IP" ]; then
        print_error "Failed to auto-detect IP address. Please provide it manually using -i option."
        exit 1
    fi
    
    print_success "Detected IP: $MY_IP"
else
    print_info "Using provided IP: $MY_IP"
fi

# Validate IP format
if [[ ! "$MY_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_error "Invalid IP address format: $MY_IP"
    exit 1
fi

# Add /32 CIDR notation
IP_WITH_CIDR="${MY_IP}/32"

# Define file path
TFVARS_FILE="${PROJECT_ROOT}/environments/${ENVIRONMENT}.tfvars"

# Check if file exists
if [ ! -f "$TFVARS_FILE" ]; then
    print_error "Environment file not found: $TFVARS_FILE"
    exit 1
fi

print_info "Updating $TFVARS_FILE..."

# Backup original file
cp "$TFVARS_FILE" "${TFVARS_FILE}.backup.$(date +%Y%m%d%H%M%S)"

# Update my_ip_address
if grep -q "^my_ip_address\s*=" "$TFVARS_FILE"; then
    # Update existing line
    sed -i.bak "s|^my_ip_address\s*=.*|my_ip_address = \"${IP_WITH_CIDR}\"|" "$TFVARS_FILE"
    rm -f "${TFVARS_FILE}.bak"
else
    # Add new line before "# Tags for all resources"
    sed -i.bak "/^# Tags for all resources/i\\
# Whitelist your IP address for cluster access\nmy_ip_address = \"${IP_WITH_CIDR}\"\n" "$TFVARS_FILE"
    rm -f "${TFVARS_FILE}.bak"
fi

# Update SSH CIDRs if requested
if [ "$ENABLE_SSH" = true ]; then
    if grep -q "^allowed_ssh_cidrs\s*=" "$TFVARS_FILE"; then
        # Check if IP is already in the list
        if ! grep "allowed_ssh_cidrs" "$TFVARS_FILE" | grep -q "$IP_WITH_CIDR"; then
            # Add IP to existing list - this is tricky with sed, so we'll use a different approach
            print_info "Adding IP to allowed_ssh_cidrs..."
            # For now, just replace the whole line
            sed -i.bak "s|^allowed_ssh_cidrs\s*=.*|allowed_ssh_cidrs = [\"${IP_WITH_CIDR}\"]|" "$TFVARS_FILE"
            rm -f "${TFVARS_FILE}.bak"
        fi
    else
        # Add new line
        sed -i.bak "/^my_ip_address/a\\
allowed_ssh_cidrs = [\"${IP_WITH_CIDR}\"]" "$TFVARS_FILE"
        rm -f "${TFVARS_FILE}.bak"
    fi
    print_success "SSH access enabled for ${IP_WITH_CIDR}"
fi

print_success "Updated ${TFVARS_FILE}"
print_info ""
print_info "Next steps:"
print_info "1. Review the changes: git diff environments/${ENVIRONMENT}.tfvars"
print_info "2. Apply Terraform changes:"
print_info "   cd infra-eks-terraform"
print_info "   terraform workspace select ${ENVIRONMENT}"
print_info "   terraform apply -var-file=environments/${ENVIRONMENT}.tfvars"
print_info ""
print_warning "Note: Your IP (${IP_WITH_CIDR}) has been whitelisted for:"
print_warning "  - Kubernetes API access (port 443)"
print_warning "  - HTTP access (port 80)"
if [ "$ENABLE_SSH" = true ]; then
    print_warning "  - SSH access (port 22)"
fi

# Show current IP in file
print_info ""
print_info "Current configuration:"
grep -A 2 "my_ip_address" "$TFVARS_FILE" | head -3
