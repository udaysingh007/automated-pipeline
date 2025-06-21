# ==============================================================================
# FILE: modules/gitea/values.yaml.tpl
# ==============================================================================

# Gitea configuration
gitea:
  admin:
    username: "${admin_username}"
    password: "${admin_password}"
    email: "${admin_email}"
  
  config:
    server:
      DOMAIN: "${domain}"
      ROOT_URL: "${root_url}"
    
    security:
      SECRET_KEY: "${secret_key}"
    
    database:
      DB_TYPE: postgres
      HOST: "${release_name}-postgresql:5432"
      NAME: "${postgres_database}"
      USER: "${postgres_username}"
      PASSWD: "${postgres_password}"
    
    cache:
      ENABLED: false
    
    session:
      PROVIDER: memory

# Service configuration
service:
  http:
    type: ${service_type}

# Ingress configuration
ingress:
  enabled: ${ingress_enabled}
  className: "${ingress_class}"
  hosts:
    - host: "${domain}"
      paths:
        - path: /
          pathType: Prefix

# Persistence configuration - Completely disable PVCs
persistence:
  enabled: false

# Gitea-specific persistence override
gitea:
  admin:
    username: "${admin_username}"
    password: "${admin_password}"
    email: "${admin_email}"
  
  config:
    server:
      DOMAIN: "${domain}"
      ROOT_URL: "${root_url}"
    
    security:
      SECRET_KEY: "${secret_key}"
    
    database:
      DB_TYPE: postgres
      HOST: "${release_name}-postgresql:5432"
      NAME: "${postgres_database}"
      USER: "${postgres_username}"
      PASSWD: "${postgres_password}"
    
    cache:
      ENABLED: false
    
    session:
      PROVIDER: memory

  # Disable Gitea persistence
  persistence:
    enabled: false

# Redis configuration - Disable Redis
redis-cluster:
  enabled: false

redis:
  enabled: false

# Memcached configuration - Disable if not needed
memcached:
  enabled: false
postgresql-ha:
  enabled: false
postgresql:
  enabled: true
  auth:
    username: "${postgres_username}"
    password: "${postgres_password}"
    database: "${postgres_database}"
  
  # Disable PostgreSQL persistence
  primary:
    persistence:
      enabled: false
    
    # Use emptyDir for PostgreSQL data
    extraVolumes:
      - name: postgres-data
        emptyDir: {}
    
    extraVolumeMounts:
      - name: postgres-data
        mountPath: /bitnami/postgresql

# Resource limits and requests
resources:
  limits:
    cpu: "${resource_limits_cpu}"
    memory: "${resource_limits_memory}"
  requests:
    cpu: "${resource_requests_cpu}"
    memory: "${resource_requests_memory}"

