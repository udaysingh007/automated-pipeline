terraform state rm 'module.argo_build_workflow.kubectl_manifest.event_source'
terraform state rm 'module.argo_build_workflow.kubectl_manifest.sensor'  
terraform state rm 'module.argo_build_workflow.kubernetes_secret.kaniko_docker_config'
terraform state rm 'module.argo_build_workflow.kubectl_manifest.workflow_template'

# 3. Delete any existing resources from cluster
kubectl delete eventsource gitea -n argo --ignore-not-found
kubectl delete sensor gitea-sensor -n argo --ignore-not-found
kubectl delete secret kaniko-docker-config -n argo --ignore-not-found
kubectl delete workflowtemplate go-app-build -n argo --ignore-not-found

