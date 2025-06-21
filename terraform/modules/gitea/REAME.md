
# ==============================================================================
# FILE: modules/gitea/README.md
# ==============================================================================

# Gitea Terraform Module

This module deploys Gitea using Helm charts on Kubernetes with PostgreSQL as the database backend.

## Features

- Deploys Gitea with PostgreSQL database
- Configurable persistent storage
- Secure credential management
- Ingress support
- Resource management
- Node selector and tolerations support

## Usage

```hcl
module "gitea" {
  source = "./modules/gitea"
  
  # Basic configuration
  namespace    = "gitea"
  release_name = "gitea"
  
  # Admin credentials
  admin_username = "admin"
  admin_password = "secure-admin-password"
  admin_email    = "admin@yourdomain.com"
  
  # Database credentials
  postgres_username = "gitea"
  postgres_password = "secure-db-password"
  postgres_database = "gitea"
  
  # Network configuration
  domain       = "gitea.yourdomain.com"
  root_url     = "https://gitea.yourdomain.com"
  service_type = "ClusterIP"
  
  # Storage configuration
  storage_class    = "local-fast"
  gitea_pv_size    = "20Gi"
  postgres_pv_size = "10Gi"
  
  # Ingress (optional)
  ingress_enabled = true
  ingress_class   = "nginx"
  
  # Resource limits
  resource_limits_cpu      = "1000m"
  resource_limits_memory   = "1Gi"
  resource_requests_cpu    = "100m"
  resource_requests_memory = "128Mi"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| helm | ~> 2.0 |
| kubernetes | ~> 2.0 |
| random | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| helm | ~> 2.0 |
| kubernetes | ~> 2.0 |
| random | ~> 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| admin_password | Gitea admin password | `string` | n/a | yes |
| postgres_password | PostgreSQL password | `string` | n/a | yes |
| namespace | Kubernetes namespace for Gitea deployment | `string` | `"gitea"` | no |
| release_name | Helm release name for Gitea | `string` | `"gitea"` | no |
| admin_username | Gitea admin username | `string` | `"admin"` | no |
| admin_email | Gitea admin email | `string` | `"admin@example.com"` | no |
| domain | Domain name for Gitea | `string` | `"gitea.local"` | no |
| storage_class | Storage class for persistent volumes | `string` | `"local-fast"` | no |
| gitea_pv_size | Size of Gitea persistent volume | `string` | `"20Gi"` | no |
| postgres_pv_size | Size of PostgreSQL persistent volume | `string` | `"10Gi"` | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Namespace where Gitea is deployed |
| release_name | Helm release name |
| service_name | Gitea service name |
| gitea_url | Gitea URL |
| admin_username | Gitea admin username |

## Post-Deployment

After deployment, you can access Gitea:

1. **Port Forward (for testing)**:
   ```bash
   kubectl port-forward -n gitea svc/gitea-http 3000:3000
   ```
   Then access: http://localhost:3000

2. **Check PV binding**:
   ```bash
   kubectl get pvc -n gitea
   kubectl get pv
   ```

3. **Check deployment status**:
   ```bash
   kubectl get pods -n gitea
   kubectl get svc -n gitea
   ```