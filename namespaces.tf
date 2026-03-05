# ============================================
# Kubernetes Namespaces with Isolation
# ============================================

# Create namespaces for application isolation
resource "kubernetes_namespace" "namespaces" {
  for_each = local.namespaces

  metadata {
    name        = each.value.name
    labels      = each.value.labels
    annotations = each.value.annotations
  }

  depends_on = [module.eks]
}

# --------------------------------------------
# Resource Quotas for Namespace Isolation
# --------------------------------------------
resource "kubernetes_resource_quota" "frontend_quota" {
  count = local.namespaces["frontend"].resource_quota ? 1 : 0

  metadata {
    name      = "frontend-quota"
    namespace = kubernetes_namespace.namespaces["frontend"].metadata[0].name
  }

  spec {
    hard = local.resource_quotas[var.environment].frontend
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_resource_quota" "backend_quota" {
  count = local.namespaces["backend"].resource_quota ? 1 : 0

  metadata {
    name      = "backend-quota"
    namespace = kubernetes_namespace.namespaces["backend"].metadata[0].name
  }

  spec {
    hard = local.resource_quotas[var.environment].backend
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# --------------------------------------------
# Limit Ranges for Resource Constraints
# --------------------------------------------
resource "kubernetes_limit_range" "frontend_limits" {
  count = local.namespaces["frontend"].limit_range ? 1 : 0

  metadata {
    name      = "frontend-limits"
    namespace = kubernetes_namespace.namespaces["frontend"].metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      
      default = {
        cpu    = local.limit_ranges.frontend.default.cpu
        memory = local.limit_ranges.frontend.default.memory
      }
      
      default_request = {
        cpu    = local.limit_ranges.frontend.default_request.cpu
        memory = local.limit_ranges.frontend.default_request.memory
      }
      
      max = {
        cpu    = local.limit_ranges.frontend.max.cpu
        memory = local.limit_ranges.frontend.max.memory
      }
      
      min = {
        cpu    = local.limit_ranges.frontend.min.cpu
        memory = local.limit_ranges.frontend.min.memory
      }
    }
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_limit_range" "backend_limits" {
  count = local.namespaces["backend"].limit_range ? 1 : 0

  metadata {
    name      = "backend-limits"
    namespace = kubernetes_namespace.namespaces["backend"].metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      
      default = {
        cpu    = local.limit_ranges.backend.default.cpu
        memory = local.limit_ranges.backend.default.memory
      }
      
      default_request = {
        cpu    = local.limit_ranges.backend.default_request.cpu
        memory = local.limit_ranges.backend.default_request.memory
      }
      
      max = {
        cpu    = local.limit_ranges.backend.max.cpu
        memory = local.limit_ranges.backend.max.memory
      }
      
      min = {
        cpu    = local.limit_ranges.backend.min.cpu
        memory = local.limit_ranges.backend.min.memory
      }
    }
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# --------------------------------------------
# Network Policies for Traffic Isolation
# --------------------------------------------
resource "kubernetes_network_policy" "frontend_deny_all" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.namespaces["frontend"].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_network_policy" "frontend_allow_ingress" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "allow-frontend-ingress"
    namespace = kubernetes_namespace.namespaces["frontend"].metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/component" = "frontend"
      }
    }

    ingress {
      from {
        namespace_selector {}
      }
      ports {
        protocol = "TCP"
        port     = 80
      }
      ports {
        protocol = "TCP"
        port     = 443
      }
    }

    policy_types = ["Ingress"]
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_network_policy" "frontend_allow_backend_egress" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "allow-backend-egress"
    namespace = kubernetes_namespace.namespaces["frontend"].metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/component" = "frontend"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/component" = "backend"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 8080
      }
    }

    policy_types = ["Egress"]
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_network_policy" "backend_deny_all" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.namespaces["backend"].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_network_policy" "backend_allow_frontend" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "allow-frontend-ingress"
    namespace = kubernetes_namespace.namespaces["backend"].metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/component" = "backend"
      }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/component" = "frontend"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 8080
      }
    }

    policy_types = ["Ingress"]
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_network_policy" "backend_allow_dns" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "allow-dns-egress"
    namespace = kubernetes_namespace.namespaces["backend"].metadata[0].name
  }

  spec {
    pod_selector {}

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
        pod_selector {
          match_labels = {
            "k8s-app" = "kube-dns"
          }
        }
      }
      ports {
        protocol = "UDP"
        port     = 53
      }
    }

    policy_types = ["Egress"]
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# --------------------------------------------
# Service Accounts for Applications
# --------------------------------------------
resource "kubernetes_service_account" "frontend_sa" {
  metadata {
    name        = "frontend-sa"
    namespace   = kubernetes_namespace.namespaces["frontend"].metadata[0].name
    annotations = {
      "description" = "Service account for frontend React application"
    }
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_service_account" "backend_sa" {
  metadata {
    name        = "backend-sa"
    namespace   = kubernetes_namespace.namespaces["backend"].metadata[0].name
    annotations = {
      "description" = "Service account for backend Java application"
    }
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# --------------------------------------------
# RBAC for Deployer Role (Jenkins)
# --------------------------------------------
resource "kubernetes_cluster_role" "deployer" {
  metadata {
    name = "deployer-role"
  }

  rule {
    api_groups = ["", "apps", "networking.k8s.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets", "configmaps"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_cluster_role_binding" "deployer_binding" {
  metadata {
    name = "deployer-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.deployer.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "deployers"
    api_group = "rbac.authorization.k8s.io"
  }
}

# Developer role with read-only access
resource "kubernetes_cluster_role" "developer" {
  metadata {
    name = "developer-role"
  }

  rule {
    api_groups = ["", "apps", "networking.k8s.io"]
    resources  = ["pods", "services", "deployments", "replicasets", "ingresses", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "developer_binding" {
  metadata {
    name = "developer-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.developer.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "developers"
    api_group = "rbac.authorization.k8s.io"
  }
}
