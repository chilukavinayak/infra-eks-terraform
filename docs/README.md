# Tresvita EKS Documentation

## Overview

This directory contains comprehensive documentation for the Tresvita EKS infrastructure and deployment processes.

## Documentation Index

| Document | Purpose | Audience |
|----------|---------|----------|
| [CI_CD_HELM_GUIDE.md](CI_CD_HELM_GUIDE.md) | Complete CI/CD pipeline guide with Helm charts | Developers, DevOps |
| [SETUP_GUIDE.md](SETUP_GUIDE.md) | Infrastructure setup instructions | DevOps, Architects |
| [JENKINS_SETUP.md](JENKINS_SETUP.md) | Jenkins EC2 setup guide | DevOps |
| [APPLICATION_DEVELOPMENT.md](APPLICATION_DEVELOPMENT.md) | Frontend/backend development setup | Developers |
| [OPERATIONS.md](OPERATIONS.md) | Day-to-day operations guide | DevOps, SRE |
| [DISASTER_RECOVERY.md](DISASTER_RECOVERY.md) | Backup and restore procedures | DevOps, SRE |

## Quick Links

### Getting Started
- [Quick Start](../QUICKSTART.md) - Get up and running quickly
- [CI/CD with Helm](CI_CD_HELM_GUIDE.md) - Deploy applications using Helm

### Infrastructure
- [Infrastructure Setup](SETUP_GUIDE.md) - Provision EKS cluster
- [Jenkins Setup](JENKINS_SETUP.md) - Configure Jenkins for CI/CD

### Development
- [Application Development](APPLICATION_DEVELOPMENT.md) - Build frontend and backend apps
- [Operations Guide](OPERATIONS.md) - Manage the cluster

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              CI/CD FLOW                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Git Push ──> Jenkins ──> Build ──> Test ──> Docker ──> ECR ──> EKS  │
│                                                                         │
│   EKS Deployment uses Helm charts from:                                 │
│   infra-eks-terraform/helm_charts/                                      │
│   ├── todo-frontend/                                                    │
│   └── todo-backend/                                                     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Need Help?

- For deployment issues: See [CI_CD_HELM_GUIDE.md](CI_CD_HELM_GUIDE.md) troubleshooting section
- For infrastructure issues: See [OPERATIONS.md](OPERATIONS.md)
- For disaster recovery: See [DISASTER_RECOVERY.md](DISASTER_RECOVERY.md)

---

**Client**: Tresvita  
**Managed By**: Wissen Team
