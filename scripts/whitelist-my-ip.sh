#!/bin/bash
# Whitelist your IP in all security groups

IP=$(curl -s ifconfig.me)
echo "Your IP: $IP"

# Update dev.tfvars
sed -i '' "s/0.0.0.0\/0/$IP\/32/g" environments/dev.tfvars

echo "Updated! Run: terraform apply -var-file=environments/dev.tfvars"
