#!/bin/bash

set -e  # Stop the script on any error

# Fonction pour attendre qu'un pod soit en état "Running"
wait_for_pod() {
  local label=$1
  echo "Waiting for pod with label $label to be running..."
  until kubectl get pods -l "$label" -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; do
    echo "Waiting..."
    sleep 10
  done
  echo "Pod with label $label is running!"
}

# Installer les dépendances
sudo apt update && sudo apt install -y curl wget apt-transport-https gnupg lsb-release

# Désactiver le swap (obligatoire pour Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Installer kubeadm, kubelet et kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Initialiser le cluster Kubernetes avec kubeadm
sudo kubeadm init --pod-network-cidr=192.168.1.0/16

# Configurer kubectl pour l'utilisateur actuel
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Installer un réseau pour Kubernetes (Calico)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Vérifier si le cluster est prêt
echo "Attente de la disponibilité du cluster..."
kubectl wait --for=condition=Ready node --all --timeout=300s

# Installer Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Clone and install PostgreSQL
git clone https://github.com/bitnami/charts.git
cd charts/bitnami/postgresql

# Modify values.yaml
cat <<EOF > values.yaml
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

## @section Global parameters
## Please, note that this will override the parameters, including dependencies, configured to use the global value
##
global:
  ## @param global.imageRegistry Global Docker image registry
  ##
  imageRegistry: ""
  ## @param global.imagePullSecrets Global Docker registry secret names as an array
  ## e.g.
  ## imagePullSecrets:
  ##   - myRegistryKeySecretName
  ##
  imagePullSecrets: []
  ## @param global.defaultStorageClass Global default StorageClass for Persistent Volume(s)
## @param global.storageClass DEPRECATED: use global.defaultStorageClass instead
  ##
  defaultStorageClass: ""
  storageClass: ""
  ## Security parameters
  ##
  security:
    ## @param global.security.allowInsecureImages Allows skipping image verification
    allowInsecureImages: false
  postgresql:
    ## @param global.postgresql.auth.postgresPassword Password for the "postgres" admin user (overrides `auth.postgresPassword`)
    ## @param global.postgresql.auth.username Name for a custom user to create (overrides `auth.username`)
    ## @param global.postgresql.auth.password Password for the custom user to create (overrides `auth.password`)
    ## @param global.postgresql.auth.database Name for a custom database to create (overrides `auth.database`)
    ## @param global.postgresql.auth.existingSecret Name of existing secret to use for PostgreSQL credentials (overrides `auth.existingSecret`).
    ## @param global.postgresql.auth.secretKeys.adminPasswordKey Name of key in existing secret to use for PostgreSQL credentials (overrides `auth.secretKeys.adminPasswordKey`). Only used when `global.postgresql.auth.existingSecret` is set.
    ## @param global.postgresql.auth.secretKeys.userPasswordKey Name of key in existing secret to use for PostgreSQL credentials (overrides `auth.secretKeys.userPasswordKey`). Only used when `global.postgresql.auth.existingSecret` is set.
    ## @param global.postgresql.auth.secretKeys.replicationPasswordKey Name of key in existing secret to use for PostgreSQL credentials (overrides `auth.secretKeys.replicationPasswordKey`). Only used when `global.postgresql.auth.existingSecret` is set.
    ##
    auth:
      postgresPassword: "admin"
      username: ""
      password: "admin"
      database: ""
      existingSecret: ""
      secretKeys:
        adminPasswordKey: ""
        userPasswordKey: ""
        replicationPasswordKey: ""
    ## @param global.postgresql.service.ports.postgresql PostgreSQL service port (overrides `service.ports.postgresql`)
    ##
    service:
      ports:
        postgresql: ""
  ## Compatibility adaptations for Kubernetes platforms
  ##
  compatibility:
    ## Compatibility adaptations for Openshift
    ##
    openshift:
      ## @param global.compatibility.openshift.adaptSecurityContext Adapt the securityContext sections of the deployment to make them compatible with Openshift restricted-v2 SCC: remove runAsUser, runAsGroup and fsGroup and let the platform use their allowed default IDs. Possible values: auto (apply if the detected running cluster is Openshift), force (perform the adaptation always), disabled (do not perform adaptation)
      ##
      adaptSecurityContext: auto
## @section Common parameters
##

## @param kubeVersion Override Kubernetes version
##
kubeVersion: ""
## @param nameOverride String to partially override common.names.fullname template (will maintain the release name)
##
nameOverride: ""
## @param fullnameOverride String to fully override common.names.fullname template
##
fullnameOverride: ""
## @param namespaceOverride String to fully override common.names.namespace
##
namespaceOverride: ""
## @param clusterDomain Kubernetes Cluster Domain
##
clusterDomain: cluster.local
## @param extraDeploy Array of extra objects to deploy with the release (evaluated as a template)
##
extraDeploy: []
## @param commonLabels Add labels to all the deployed resources
##
commonLabels: {}
## @param commonAnnotations Add annotations to all the deployed resources
##
commonAnnotations: {}
## @param secretAnnotations Add annotations to the secrets
##
secretAnnotations: {}
## Enable diagnostic mode in the statefulset
##
diagnosticMode:
  ## @param diagnosticMode.enabled Enable diagnostic mode (all probes will be disabled and the command will be overridden)
  ##
  enabled: false
  ## @param diagnosticMode.command Command to override all containers in the statefulset
  ##
  command:
    - sleep
  ## @param diagnosticMode.args Args to override all containers in the statefulset
  ##
  args:
    - infinity
## @section PostgreSQL common parameters
##

## Bitnami PostgreSQL image version
## ref: https://hub.docker.com/r/bitnami/postgresql/tags/
## @param image.registry [default: REGISTRY_NAME] PostgreSQL image registry
## @param image.repository [default: REPOSITORY_NAME/postgresql] PostgreSQL image repository
## @skip image.tag PostgreSQL image tag (immutable tags are recommended)
## @param image.digest PostgreSQL image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag
## @param image.pullPolicy PostgreSQL image pull policy
## @param image.pullSecrets Specify image pull secrets
## @param image.debug Specify if debug values should be set
##
image:
  registry: docker.io
  repository: bitnami/postgresql
  tag: 17.4.0-debian-12-r4
  digest: ""
  ## Specify a imagePullPolicy
  ## ref: https://kubernetes.io/docs/concepts/containers/images/#pre-pulled-images
  ##
  pullPolicy: IfNotPresent
  ## Optionally specify an array of imagePullSecrets.
  ## Secrets must be manually created in the namespace.
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
  ## Example:
  ## pullSecrets:
  ##   - myRegistryKeySecretName
  ##
  pullSecrets: []
  ## Set to true if you would like to see extra information on logs
  ##
  debug: false
## Authentication parameters
## ref: https://github.com/bitnami/containers/tree/main/bitnami/postgresql#setting-the-root-password-on-first-run
## ref: https://github.com/bitnami/containers/tree/main/bitnami/postgresql#creating-a-database-on-first-run
## ref: https://github.com/bitnami/containers/tree/main/bitnami/postgresql#creating-a-database-user-on-first-run
##
auth:
  ## @param auth.enablePostgresUser Assign a password to the "postgres" admin user. Otherwise, remote access will be blocked for this user
  ##
  enablePostgresUser: true
  ## @param auth.postgresPassword Password for the "postgres" admin user. Ignored if `auth.existingSecret` is provided
  ##
  postgresPassword: ""
  ## @param auth.username Name for a custom user to create
  ##
  username: ""
  ## @param auth.password Password for the custom user to create. Ignored if `auth.existingSecret` is provided
  ##
  password: ""
  ## @param auth.database Name for a custom database to create
  ##
  database: ""
  ## @param auth.replicationUsername Name of the replication user
  ##
  replicationUsername: repl_user
  ## @param auth.replicationPassword Password for the replication user. Ignored if `auth.existingSecret` is provided
  ##
  replicationPassword: ""
  ## @param auth.existingSecret Name of existing secret to use for PostgreSQL credentials. `auth.postgresPassword`, `auth.password`, and `auth.replicationPassword` will be ignored and picked up from this secret. The secret might also contains the key `ldap-password` if LDAP is enabled. `ldap.bind_password` will be ignored and picked from this secret in this case.
  ##
  existingSecret: ""
  ## @param auth.secretKeys.adminPasswordKey Name of key in existing secret to use for PostgreSQL credentials. Only used when `auth.existingSecret` is set.
  ## @param auth.secretKeys.userPasswordKey Name of key in existing secret to use for PostgreSQL credentials. Only used when `auth.existingSecret` is set.
  ## @param auth.secretKeys.replicationPasswordKey Name of key in existing secret to use for PostgreSQL credentials. Only used when `auth.existingSecret` is set.
  ##
  secretKeys:
    adminPasswordKey: postgres-password
    userPasswordKey: password
    replicationPasswordKey: replication-password
  ## @param auth.usePasswordFiles Mount credentials as a files instead of using an environment variable
  ##
  usePasswordFiles: false
## @param architecture PostgreSQL architecture (`standalone` or `replication`)
##
architecture: standalone
## Replication configuration
## Ignored if `architecture` is `standalone`
##
replication:
  ## @param replication.synchronousCommit Set synchronous commit mode. Allowed values: `on`, `remote_apply`, `remote_write`, `local` and `off`
  ## @param replication.numSynchronousReplicas Number of replicas that will have synchronous replication. Note: Cannot be greater than `readReplicas.replicaCount`.
  ## ref: https://www.postgresql.org/docs/current/runtime-config-wal.html#GUC-SYNCHRONOUS-COMMIT
  ##
  synchronousCommit: "off"
  numSynchronousReplicas: 0
  ## @param replication.applicationName Cluster application name. Useful for advanced replication settings
  ##
  applicationName: my_application
## @param containerPorts.postgresql PostgreSQL container port
##
containerPorts:
  postgresql: 5432
## Audit settings
## https://github.com/bitnami/containers/tree/main/bitnami/postgresql#auditing
## @param audit.logHostname Log client hostnames
## @param audit.logConnections Add client log-in operations to the log file
## @param audit.logDisconnections Add client log-outs operations to the log file
## @param audit.pgAuditLog Add operations to log using the pgAudit extension
## @param audit.pgAuditLogCatalog Log catalog using pgAudit
## @param audit.clientMinMessages Message log level to share with the user
## @param audit.logLinePrefix Template for log line prefix (default if not set)
## @param audit.logTimezone Timezone for the log timestamps
##
audit:
  logHostname: false
  logConnections: false
  logDisconnections: false
  pgAuditLog: ""
  pgAuditLogCatalog: "off"
  clientMinMessages: error
  logLinePrefix: ""
  logTimezone: ""
## LDAP configuration
## @param ldap.enabled Enable LDAP support
## @param ldap.server IP address or name of the LDAP server.
## @param ldap.port Port number on the LDAP server to connect to
## @param ldap.prefix String to prepend to the user name when forming the DN to bind
## @param ldap.suffix String to append to the user name when forming the DN to bind
## DEPRECATED ldap.baseDN It will removed in a future, please use 'ldap.basedn' instead
## DEPRECATED ldap.bindDN It will removed in a future, please use 'ldap.binddn' instead
## DEPRECATED ldap.bind_password It will removed in a future, please use 'ldap.bindpw' instead
## @param ldap.basedn Root DN to begin the search for the user in
## @param ldap.binddn DN of user to bind to LDAP
## @param ldap.bindpw Password for the user to bind to LDAP
## DEPRECATED ldap.search_attr It will removed in a future, please use 'ldap.searchAttribute' instead
## DEPRECATED ldap.search_filter It will removed in a future, please use 'ldap.searchFilter' instead
## @param ldap.searchAttribute Attribute to match against the user name in the search
## @param ldap.searchFilter The search filter to use when doing search+bind authentication
## @param ldap.scheme Set to `ldaps` to use LDAPS
## DEPRECATED ldap.tls as string is deprecated, please use 'ldap.tls.enabled' instead
## @param ldap.tls.enabled Se to true to enable TLS encryption
##
ldap:
  enabled: false
  server: ""
  port: ""
  prefix: ""
  suffix: ""
  basedn: ""
  binddn: ""
  bindpw: ""
  searchAttribute: ""
  searchFilter: ""
  scheme: ""
  tls:
    enabled: false
  ## @param ldap.uri LDAP URL beginning in the form `ldap[s]://host[:port]/basedn`. If provided, all the other LDAP parameters will be ignored.
  ## Ref: https://www.postgresql.org/docs/current/auth-ldap.html
  ##
  uri: ""
## @param postgresqlDataDir PostgreSQL data dir folder
##
postgresqlDataDir: /bitnami/postgresql/data
## @param postgresqlSharedPreloadLibraries Shared preload libraries (comma-separated list)
##
postgresqlSharedPreloadLibraries: "pgaudit"
## Start PostgreSQL pod(s) without limitations on shm memory.
## By default docker and containerd (and possibly other container runtimes) limit `/dev/shm` to `64M`
## ref: https://github.com/docker-library/postgres/issues/416
## ref: https://github.com/containerd/containerd/issues/3654
##
shmVolume:
  ## @param shmVolume.enabled Enable emptyDir volume for /dev/shm for PostgreSQL pod(s)
  ##
  enabled: true
  ## @param shmVolume.sizeLimit Set this to enable a size limit on the shm tmpfs
  ## Note: the size of the tmpfs counts against container's memory limit
  ## e.g:
  ## sizeLimit: 1Gi
  ##
  sizeLimit: ""
## TLS configuration
##
tls:
  ## @param tls.enabled Enable TLS traffic support
  ##
  enabled: false
  ## @param tls.autoGenerated Generate automatically self-signed TLS certificates
  ##
  autoGenerated: false
  ## @param tls.preferServerCiphers Whether to use the server's TLS cipher preferences rather than the client's
  ##
  preferServerCiphers: true
  ## @param tls.certificatesSecret Name of an existing secret that contains the certificates
  ##
  certificatesSecret: ""
  ## @param tls.certFilename Certificate filename
  ##
  certFilename: ""
  ## @param tls.certKeyFilename Certificate key filename
  ##
  certKeyFilename: ""
  ## @param tls.certCAFilename CA Certificate filename
  ## If provided, PostgreSQL will authenticate TLS/SSL clients by requesting them a certificate
  ## ref: https://www.postgresql.org/docs/9.6/auth-methods.html
  ##
  certCAFilename: ""
  ## @param tls.crlFilename File containing a Certificate Revocation List
  ##
  crlFilename: ""
## @section PostgreSQL Primary parameters
##
primary:
  ## @param primary.name Name of the primary database (eg primary, master, leader, ...)
  ##
  name: primary
  ## @param primary.configuration PostgreSQL Primary main configuration to be injected as ConfigMap
  ## ref: https://www.postgresql.org/docs/current/static/runtime-config.html
  ##
  configuration: ""
  ## @param primary.pgHbaConfiguration PostgreSQL Primary client authentication configuration
  ## ref: https://www.postgresql.org/docs/current/static/auth-pg-hba-conf.html
  ## e.g:#
  ## pgHbaConfiguration: |-
  ##   local all all trust
  ##   host all all localhost trust
  ##   host mydatabase mysuser 192.168.0.0/24 md5
  ##
  pgHbaConfiguration: ""
  ## @param primary.existingConfigmap Name of an existing ConfigMap with PostgreSQL Primary configuration
  ## NOTE: `primary.configuration` and `primary.pgHbaConfiguration` will be ignored
  ##
  existingConfigmap: ""
  ## @param primary.extendedConfiguration Extended PostgreSQL Primary configuration (appended to main or default configuration)
  ## ref: https://github.com/bitnami/containers/tree/main/bitnami/postgresql#allow-settings-to-be-loaded-from-files-other-than-the-default-postgresqlconf
  ##
  extendedConfiguration: ""
  ## @param primary.existingExtendedConfigmap Name of an existing ConfigMap with PostgreSQL Primary extended configuration
  ## NOTE: `primary.extendedConfiguration` will be ignored
  ##
  existingExtendedConfigmap: ""
  ## Initdb configuration
  ## ref: https://github.com/bitnami/containers/tree/main/bitnami/postgresql#specifying-initdb-arguments
  ##
  initdb:
    ## @param primary.initdb.args PostgreSQL initdb extra arguments
    ##
    args: ""
    ## @param primary.initdb.postgresqlWalDir Specify a custom location for the PostgreSQL transaction log
    ##
    postgresqlWalDir: ""
    ## @param primary.initdb.scripts Dictionary of initdb scripts
    ## Specify dictionary of scripts to be run at first boot
    ## e.g:
    ## scripts:
    ##   my_init_script.sh: |
    ##      #!/bin/sh
    ##      echo "Do something."
    ##
    scripts: {}
    ## @param primary.initdb.scriptsConfigMap ConfigMap with scripts to be run at first boot
    ## NOTE: This will override `primary.initdb.scripts`
    ##
    scriptsConfigMap: ""
    ## @param primary.initdb.scriptsSecret Secret with scripts to be run at first boot (in case it contains sensitive information)
    ## NOTE: This can work along `primary.initdb.scripts` or `primary.initdb.scriptsConfigMap`
    ##
    scriptsSecret: ""
    ## @param primary.initdb.user Specify the PostgreSQL username to execute the initdb scripts
    ##
    user: ""
    ## @param primary.initdb.password Specify the PostgreSQL password to execute the initdb scripts
    ##
    password: ""
  ## Pre-init configuration
  ## ref: https://github.com/bitnami/containers/tree/main/bitnami/postgresql/#on-container-start
  preInitDb:
    ## @param primary.preInitDb.scripts Dictionary of pre-init scripts
    ## Specify dictionary of shell scripts to be run before db boot
    ## e.g:
    ## scripts:
    ##   my_pre_init_script.sh: |
    ##      #!/bin/sh
    ##      echo "Do something."
    scripts: {}
    ## @param primary.preInitDb.scriptsConfigMap ConfigMap with pre-init scripts to be run
    ## NOTE: This will override `primary.preInitDb.scripts`
    scriptsConfigMap: ""
    ## @param primary.preInitDb.scriptsSecret Secret with pre-init scripts to be run
    ## NOTE: This can work along `primary.preInitDb.scripts` or `primary.preInitDb.scriptsConfigMap`
    scriptsSecret: ""
  ## Configure current cluster's primary server to be the standby server in other cluster.
  ## This will allow cross cluster replication and provide cross cluster high availability.
  ## You will need to configure pgHbaConfiguration if you want to enable this feature with local cluster replication enabled.
  ## @param primary.standby.enabled Whether to enable current cluster's primary as standby server of another cluster or not
  ## @param primary.standby.primaryHost The Host of replication primary in the other cluster
  ## @param primary.standby.primaryPort The Port of replication primary in the other cluster
  ##
  standby:
    enabled: false
    primaryHost: ""
    primaryPort: ""
  ## @param primary.extraEnvVars Array with extra environment variables to add to PostgreSQL Primary nodes
  ## e.g:
  ## extraEnvVars:
  ##   - name: FOO
  ##     value: "bar"
  ##
  extraEnvVars: []
  ## @param primary.extraEnvVarsCM Name of existing ConfigMap containing extra env vars for PostgreSQL Primary nodes
  ##
  extraEnvVarsCM: ""
  ## @param primary.extraEnvVarsSecret Name of existing Secret containing extra env vars for PostgreSQL Primary nodes
  ##
  extraEnvVarsSecret: ""
  ## @param primary.command Override default container command (useful when using custom images)
  ##
  command: []
  ## @param primary.args Override default container args (useful when using custom images)
  ##
  args: []
  ## Configure extra options for PostgreSQL Primary containers' liveness, readiness and startup probes
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#configure-probes
  ## @param primary.livenessProbe.enabled Enable livenessProbe on PostgreSQL Primary containers
  ## @param primary.livenessProbe.initialDelaySeconds Initial delay seconds for livenessProbe
  ## @param primary.livenessProbe.periodSeconds Period seconds for livenessProbe
  ## @param primary.livenessProbe.timeoutSeconds Timeout seconds for livenessProbe
  ## @param primary.livenessProbe.failureThreshold Failure threshold for livenessProbe
  ## @param primary.livenessProbe.successThreshold Success threshold for livenessProbe
  ##
  livenessProbe:
    enabled: true
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## @param primary.readinessProbe.enabled Enable readinessProbe on PostgreSQL Primary containers
  ## @param primary.readinessProbe.initialDelaySeconds Initial delay seconds for readinessProbe
  ## @param primary.readinessProbe.periodSeconds Period seconds for readinessProbe
  ## @param primary.readinessProbe.timeoutSeconds Timeout seconds for readinessProbe
  ## @param primary.readinessProbe.failureThreshold Failure threshold for readinessProbe
  ## @param primary.readinessProbe.successThreshold Success threshold for readinessProbe
  ##
  readinessProbe:
    enabled: true
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## @param primary.startupProbe.enabled Enable startupProbe on PostgreSQL Primary containers
  ## @param primary.startupProbe.initialDelaySeconds Initial delay seconds for startupProbe
  ## @param primary.startupProbe.periodSeconds Period seconds for startupProbe
  ## @param primary.startupProbe.timeoutSeconds Timeout seconds for startupProbe
  ## @param primary.startupProbe.failureThreshold Failure threshold for startupProbe
  ## @param primary.startupProbe.successThreshold Success threshold for startupProbe
  ##
  startupProbe:
    enabled: false
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 1
    failureThreshold: 15
    successThreshold: 1
  ## @param primary.customLivenessProbe Custom livenessProbe that overrides the default one
  ##
  customLivenessProbe: {}
  ## @param primary.customReadinessProbe Custom readinessProbe that overrides the default one
  ##
  customReadinessProbe: {}
  ## @param primary.customStartupProbe Custom startupProbe that overrides the default one
  ##
  customStartupProbe: {}
  ## @param primary.lifecycleHooks for the PostgreSQL Primary container to automate configuration before or after startup
  ##
  lifecycleHooks: {}
  ## PostgreSQL Primary resource requests and limits
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param primary.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if primary.resources is set (primary.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  ##
  resourcesPreset: "nano"
  ## @param primary.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
  ## Example:
  ## resources:
  ##   requests:
  ##     cpu: 2
  ##     memory: 512Mi
  ##   limits:
  ##     cpu: 3
  ##     memory: 1024Mi
  ##
  resources: {}
  ## Pod Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
  ## @param primary.podSecurityContext.enabled Enable security context
  ## @param primary.podSecurityContext.fsGroupChangePolicy Set filesystem group change policy
  ## @param primary.podSecurityContext.sysctls Set kernel settings using the sysctl interface
  ## @param primary.podSecurityContext.supplementalGroups Set filesystem extra groups
  ## @param primary.podSecurityContext.fsGroup Group ID for the pod
  ##
  podSecurityContext:
    enabled: true
    fsGroupChangePolicy: Always
    sysctls: []
    supplementalGroups: []
    fsGroup: 1001
  ## Container Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
  ## @param primary.containerSecurityContext.enabled Enabled containers' Security Context
  ## @param primary.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
  ## @param primary.containerSecurityContext.runAsUser Set containers' Security Context runAsUser
  ## @param primary.containerSecurityContext.runAsGroup Set containers' Security Context runAsGroup
  ## @param primary.containerSecurityContext.runAsNonRoot Set container's Security Context runAsNonRoot
  ## @param primary.containerSecurityContext.privileged Set container's Security Context privileged
  ## @param primary.containerSecurityContext.readOnlyRootFilesystem Set container's Security Context readOnlyRootFilesystem
  ## @param primary.containerSecurityContext.allowPrivilegeEscalation Set container's Security Context allowPrivilegeEscalation
  ## @param primary.containerSecurityContext.capabilities.drop List of capabilities to be dropped
  ## @param primary.containerSecurityContext.seccompProfile.type Set container's Security Context seccomp profile
  ##
  containerSecurityContext:
    enabled: true
    seLinuxOptions: {}
    runAsUser: 1001
    runAsGroup: 1001
    runAsNonRoot: true
    privileged: false
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: "RuntimeDefault"
  ## @param primary.automountServiceAccountToken Mount Service Account token in pod
  ##
  automountServiceAccountToken: false
  ## @param primary.hostAliases PostgreSQL primary pods host aliases
  ## https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/
  ##
  hostAliases: []
  ## @param primary.hostNetwork Specify if host network should be enabled for PostgreSQL pod (postgresql primary)
  ##
  hostNetwork: false
  ## @param primary.hostIPC Specify if host IPC should be enabled for PostgreSQL pod (postgresql primary)
  ##
  hostIPC: false
  ## @param primary.labels Map of labels to add to the statefulset (postgresql primary)
  ##
  labels: {}
  ## @param primary.annotations Annotations for PostgreSQL primary pods
  ##
  annotations: {}
  ## @param primary.podLabels Map of labels to add to the pods (postgresql primary)
  ##
  podLabels: {}
  ## @param primary.podAnnotations Map of annotations to add to the pods (postgresql primary)
  ##
  podAnnotations: {}
  ## @param primary.podAffinityPreset PostgreSQL primary pod affinity preset. Ignored if `primary.affinity` is set. Allowed values: `soft` or `hard`
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
  ##
  podAffinityPreset: ""
  ## @param primary.podAntiAffinityPreset PostgreSQL primary pod anti-affinity preset. Ignored if `primary.affinity` is set. Allowed values: `soft` or `hard`
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
  ##
  podAntiAffinityPreset: soft
  ## PostgreSQL Primary node affinity preset
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity
  ##
  nodeAffinityPreset:
    ## @param primary.nodeAffinityPreset.type PostgreSQL primary node affinity preset type. Ignored if `primary.affinity` is set. Allowed values: `soft` or `hard`
    ##
    type: ""
    ## @param primary.nodeAffinityPreset.key PostgreSQL primary node label key to match Ignored if `primary.affinity` is set.
    ## E.g.
    ## key: "kubernetes.io/e2e-az-name"
    ##
    key: ""
    ## @param primary.nodeAffinityPreset.values PostgreSQL primary node label values to match. Ignored if `primary.affinity` is set.
    ## E.g.
    ## values:
    ##   - e2e-az1
    ##   - e2e-az2
    ##
    values: []
  ## @param primary.affinity Affinity for PostgreSQL primary pods assignment
  ## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
  ## Note: primary.podAffinityPreset, primary.podAntiAffinityPreset, and primary.nodeAffinityPreset will be ignored when it's set
  ##
  affinity: {}
  ## @param primary.nodeSelector Node labels for PostgreSQL primary pods assignment
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
  ##
  nodeSelector: {}
  ## @param primary.tolerations Tolerations for PostgreSQL primary pods assignment
  ## ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
  ##
  tolerations: []
  ## @param primary.topologySpreadConstraints Topology Spread Constraints for pod assignment spread across your cluster among failure-domains. Evaluated as a template
  ## Ref: https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/#spread-constraints-for-pods
  ##
  topologySpreadConstraints: []
  ## @param primary.priorityClassName Priority Class to use for each pod (postgresql primary)
  ##
  priorityClassName: ""
  ## @param primary.schedulerName Use an alternate scheduler, e.g. "stork".
  ## ref: https://kubernetes.io/docs/tasks/administer-cluster/configure-multiple-schedulers/
  ##
  schedulerName: ""
  ## @param primary.terminationGracePeriodSeconds Seconds PostgreSQL primary pod needs to terminate gracefully
  ## ref: https://kubernetes.io/docs/concepts/workloads/pods/pod/#termination-of-pods
  ##
  terminationGracePeriodSeconds: ""
  ## @param primary.updateStrategy.type PostgreSQL Primary statefulset strategy type
  ## @param primary.updateStrategy.rollingUpdate PostgreSQL Primary statefulset rolling update configuration parameters
  ## ref: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#update-strategies
  ##
  updateStrategy:
    type: RollingUpdate
    rollingUpdate: {}
  ## @param primary.extraVolumeMounts Optionally specify extra list of additional volumeMounts for the PostgreSQL Primary container(s)
  ##
  extraVolumeMounts: []
  ## @param primary.extraVolumes Optionally specify extra list of additional volumes for the PostgreSQL Primary pod(s)
  ##
  extraVolumes: []
  ## @param primary.sidecars Add additional sidecar containers to the PostgreSQL Primary pod(s)
  ## For example:
  ## sidecars:
  ##   - name: your-image-name
  ##     image: your-image
  ##     imagePullPolicy: Always
  ##     ports:
  ##       - name: portname
  ##         containerPort: 1234
  ##
  sidecars: []
  ## @param primary.initContainers Add additional init containers to the PostgreSQL Primary pod(s)
  ## Example
  ##
  ## initContainers:
  ##   - name: do-something
  ##     image: busybox
  ##     command: ['do', 'something']
  ##
  initContainers: []
  ## Pod Disruption Budget configuration
  ## ref: https://kubernetes.io/docs/tasks/run-application/configure-pdb
  ## @param primary.pdb.create Enable/disable a Pod Disruption Budget creation
  ## @param primary.pdb.minAvailable Minimum number/percentage of pods that should remain scheduled
  ## @param primary.pdb.maxUnavailable Maximum number/percentage of pods that may be made unavailable. Defaults to `1` if both `primary.pdb.minAvailable` and `primary.pdb.maxUnavailable` are empty.
  ##
  pdb:
    create: true
    minAvailable: ""
    maxUnavailable: ""
  ## @param primary.extraPodSpec Optionally specify extra PodSpec for the PostgreSQL Primary pod(s)
  ##
  extraPodSpec: {}
  ## Network Policies
  ## Ref: https://kubernetes.io/docs/concepts/services-networking/network-policies/
  ##
  networkPolicy:
    ## @param primary.networkPolicy.enabled Specifies whether a NetworkPolicy should be created
    ##
    enabled: true
    ## @param primary.networkPolicy.allowExternal Don't require server label for connections
    ## The Policy model to apply. When set to false, only pods with the correct
    ## server label will have network access to the ports server is listening
    ## on. When true, server will accept connections from any source
    ## (with the correct destination port).
    ##
    allowExternal: true
    ## @param primary.networkPolicy.allowExternalEgress Allow the pod to access any range of port and all destinations.
    ##
    allowExternalEgress: true
    ## @param primary.networkPolicy.extraIngress [array] Add extra ingress rules to the NetworkPolicy
    ## e.g:
    ## extraIngress:
    ##   - ports:
    ##       - port: 1234
    ##     from:
    ##       - podSelector:
    ##           - matchLabels:
    ##               - role: frontend
    ##       - podSelector:
    ##           - matchExpressions:
    ##               - key: role
    ##                 operator: In
    ##                 values:
    ##                   - frontend
    extraIngress: []
    ## @param primary.networkPolicy.extraEgress [array] Add extra ingress rules to the NetworkPolicy
    ## e.g:
    ## extraEgress:
    ##   - ports:
    ##       - port: 1234
    ##     to:
    ##       - podSelector:
    ##           - matchLabels:
    ##               - role: frontend
    ##       - podSelector:
    ##           - matchExpressions:
    ##               - key: role
    ##                 operator: In
    ##                 values:
    ##                   - frontend
    ##
    extraEgress: []
    ## @param primary.networkPolicy.ingressNSMatchLabels [object] Labels to match to allow traffic from other namespaces
    ## @param primary.networkPolicy.ingressNSPodMatchLabels [object] Pod labels to match to allow traffic from other namespaces
    ##
    ingressNSMatchLabels: {}
    ingressNSPodMatchLabels: {}
  ## PostgreSQL Primary service configuration
  ##
  service:
    ## @param primary.service.type Kubernetes Service type
    ##
    type: ClusterIP
    ## @param primary.service.ports.postgresql PostgreSQL service port
    ##
    ports:
      postgresql: 5432
    ## Node ports to expose
    ## NOTE: choose port between <30000-32767>
    ## @param primary.service.nodePorts.postgresql Node port for PostgreSQL
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport
    ##
    nodePorts:
      postgresql: ""
    ## @param primary.service.clusterIP Static clusterIP or None for headless services
    ## e.g:
    ## clusterIP: None
    ##
    clusterIP: ""
    ## @param primary.service.annotations Annotations for PostgreSQL primary service
    ##
    annotations: {}
    ## @param primary.service.loadBalancerClass Load balancer class if service type is `LoadBalancer`
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#load-balancer-class
    ##
    loadBalancerClass: ""
    ## @param primary.service.loadBalancerIP Load balancer IP if service type is `LoadBalancer`
    ## Set the LoadBalancer service type to internal only
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#internal-load-balancer
    ##
    loadBalancerIP: ""
    ## @param primary.service.externalTrafficPolicy Enable client source IP preservation
    ## ref https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip
    ##
    externalTrafficPolicy: Cluster
    ## @param primary.service.loadBalancerSourceRanges Addresses that are allowed when service is LoadBalancer
    ## https://kubernetes.io/docs/tasks/access-application-cluster/configure-cloud-provider-firewall/#restrict-access-for-loadbalancer-service
    ##
    ## loadBalancerSourceRanges:
    ## - 10.10.10.0/24
    ##
    loadBalancerSourceRanges: []
    ## @param primary.service.extraPorts Extra ports to expose in the PostgreSQL primary service
    ##
    extraPorts: []
    ## @param primary.service.sessionAffinity Session Affinity for Kubernetes service, can be "None" or "ClientIP"
    ## If "ClientIP", consecutive client requests will be directed to the same Pod
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#virtual-ips-and-service-proxies
    ##
    sessionAffinity: None
    ## @param primary.service.sessionAffinityConfig Additional settings for the sessionAffinity
    ## sessionAffinityConfig:
    ##   clientIP:
    ##     timeoutSeconds: 300
    ##
    sessionAffinityConfig: {}
    ## Headless service properties
    ##
    headless:
      ## @param primary.service.headless.annotations Additional custom annotations for headless PostgreSQL primary service
      ##
      annotations: {}
  ## PostgreSQL Primary persistence configuration
  ##
  persistence:
    ## @param primary.persistence.enabled Enable PostgreSQL Primary data persistence using PVC
    ##
    enabled: true
    ## @param primary.persistence.volumeName Name to assign the volume
    ##
    volumeName: "data"
    ## @param primary.persistence.existingClaim Name of an existing PVC to use
    ##
    existingClaim: ""
    ## @param primary.persistence.mountPath The path the volume will be mounted at
    ## Note: useful when using custom PostgreSQL images
    ##
    mountPath: /bitnami/postgresql
    ## @param primary.persistence.subPath The subdirectory of the volume to mount to
    ## Useful in dev environments and one PV for multiple services
    ##
    subPath: ""
    ## @param primary.persistence.storageClass PVC Storage Class for PostgreSQL Primary data volume
    ## If defined, storageClassName: <storageClass>
    ## If set to "-", storageClassName: "", which disables dynamic provisioning
    ## If undefined (the default) or set to null, no storageClassName spec is
    ##   set, choosing the default provisioner.  (gp2 on AWS, standard on
    ##   GKE, AWS & OpenStack)
    ##
    storageClass: ""
    ## @param primary.persistence.accessModes PVC Access Mode for PostgreSQL volume
    ##
    accessModes:
      - ReadWriteOnce
    ## @param primary.persistence.size PVC Storage Request for PostgreSQL volume
    ##
    size: 8Gi
    ## @param primary.persistence.annotations Annotations for the PVC
    ##
    annotations: {}
    ## @param primary.persistence.labels Labels for the PVC
    ##
    labels: {}
    ## @param primary.persistence.selector Selector to match an existing Persistent Volume (this value is evaluated as a template)
    ## selector:
    ##   matchLabels:
    ##     app: my-app
    ##
    selector: {}
    ## @param primary.persistence.dataSource Custom PVC data source
    ##
    dataSource: {}
  ## PostgreSQL Primary Persistent Volume Claim Retention Policy
  ## ref: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#persistentvolumeclaim-retention
  ##
  persistentVolumeClaimRetentionPolicy:
    ## @param primary.persistentVolumeClaimRetentionPolicy.enabled Enable Persistent volume retention policy for Primary Statefulset
    ##
    enabled: false
    ## @param primary.persistentVolumeClaimRetentionPolicy.whenScaled Volume retention behavior when the replica count of the StatefulSet is reduced
    ##
    whenScaled: Retain
    ## @param primary.persistentVolumeClaimRetentionPolicy.whenDeleted Volume retention behavior that applies when the StatefulSet is deleted
    ##
    whenDeleted: Retain
## @section PostgreSQL read only replica parameters (only used when `architecture` is set to `replication`)
##
readReplicas:
  ## @param readReplicas.name Name of the read replicas database (eg secondary, slave, ...)
  ##
  name: read
  ## @param readReplicas.replicaCount Number of PostgreSQL read only replicas
  ##
  replicaCount: 1
  ## @param readReplicas.extendedConfiguration Extended PostgreSQL read only replicas configuration (appended to main or default configuration)
  ## ref: https://github.com/bitnami/containers/tree/main/bitnami/postgresql#allow-settings-to-be-loaded-from-files-other-than-the-default-postgresqlconf
  ##
  extendedConfiguration: ""
  ## @param readReplicas.extraEnvVars Array with extra environment variables to add to PostgreSQL read only nodes
  ## e.g:
  ## extraEnvVars:
  ##   - name: FOO
  ##     value: "bar"
  ##
  extraEnvVars: []
  ## @param readReplicas.extraEnvVarsCM Name of existing ConfigMap containing extra env vars for PostgreSQL read only nodes
  ##
  extraEnvVarsCM: ""
  ## @param readReplicas.extraEnvVarsSecret Name of existing Secret containing extra env vars for PostgreSQL read only nodes
  ##
  extraEnvVarsSecret: ""
  ## @param readReplicas.command Override default container command (useful when using custom images)
  ##
  command: []
  ## @param readReplicas.args Override default container args (useful when using custom images)
  ##
  args: []
  ## Configure extra options for PostgreSQL read only containers' liveness, readiness and startup probes
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#configure-probes
  ## @param readReplicas.livenessProbe.enabled Enable livenessProbe on PostgreSQL read only containers
  ## @param readReplicas.livenessProbe.initialDelaySeconds Initial delay seconds for livenessProbe
  ## @param readReplicas.livenessProbe.periodSeconds Period seconds for livenessProbe
  ## @param readReplicas.livenessProbe.timeoutSeconds Timeout seconds for livenessProbe
  ## @param readReplicas.livenessProbe.failureThreshold Failure threshold for livenessProbe
  ## @param readReplicas.livenessProbe.successThreshold Success threshold for livenessProbe
  ##
  livenessProbe:
    enabled: true
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## @param readReplicas.readinessProbe.enabled Enable readinessProbe on PostgreSQL read only containers
  ## @param readReplicas.readinessProbe.initialDelaySeconds Initial delay seconds for readinessProbe
  ## @param readReplicas.readinessProbe.periodSeconds Period seconds for readinessProbe
  ## @param readReplicas.readinessProbe.timeoutSeconds Timeout seconds for readinessProbe
  ## @param readReplicas.readinessProbe.failureThreshold Failure threshold for readinessProbe
  ## @param readReplicas.readinessProbe.successThreshold Success threshold for readinessProbe
  ##
  readinessProbe:
    enabled: true
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## @param readReplicas.startupProbe.enabled Enable startupProbe on PostgreSQL read only containers
  ## @param readReplicas.startupProbe.initialDelaySeconds Initial delay seconds for startupProbe
  ## @param readReplicas.startupProbe.periodSeconds Period seconds for startupProbe
  ## @param readReplicas.startupProbe.timeoutSeconds Timeout seconds for startupProbe
  ## @param readReplicas.startupProbe.failureThreshold Failure threshold for startupProbe
  ## @param readReplicas.startupProbe.successThreshold Success threshold for startupProbe
  ##
  startupProbe:
    enabled: false
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 1
    failureThreshold: 15
    successThreshold: 1
  ## @param readReplicas.customLivenessProbe Custom livenessProbe that overrides the default one
  ##
  customLivenessProbe: {}
  ## @param readReplicas.customReadinessProbe Custom readinessProbe that overrides the default one
  ##
  customReadinessProbe: {}
  ## @param readReplicas.customStartupProbe Custom startupProbe that overrides the default one
  ##
  customStartupProbe: {}
  ## @param readReplicas.lifecycleHooks for the PostgreSQL read only container to automate configuration before or after startup
  ##
  lifecycleHooks: {}
  ## PostgreSQL read only resource requests and limits
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param readReplicas.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if readReplicas.resources is set (readReplicas.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  ##
  resourcesPreset: "nano"
  ## @param readReplicas.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
  ## Example:
  ## resources:
  ##   requests:
  ##     cpu: 2
  ##     memory: 512Mi
  ##   limits:
  ##     cpu: 3
  ##     memory: 1024Mi
  ##
  resources: {}
  ## Pod Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
  ## @param readReplicas.podSecurityContext.enabled Enable security context
  ## @param readReplicas.podSecurityContext.fsGroupChangePolicy Set filesystem group change policy
  ## @param readReplicas.podSecurityContext.sysctls Set kernel settings using the sysctl interface
  ## @param readReplicas.podSecurityContext.supplementalGroups Set filesystem extra groups
  ## @param readReplicas.podSecurityContext.fsGroup Group ID for the pod
  ##
  podSecurityContext:
    enabled: true
    fsGroupChangePolicy: Always
    sysctls: []
    supplementalGroups: []
    fsGroup: 1001
  ## Container Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
  ## @param readReplicas.containerSecurityContext.enabled Enabled containers' Security Context
  ## @param readReplicas.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
  ## @param readReplicas.containerSecurityContext.runAsUser Set containers' Security Context runAsUser
  ## @param readReplicas.containerSecurityContext.runAsGroup Set containers' Security Context runAsGroup
  ## @param readReplicas.containerSecurityContext.runAsNonRoot Set container's Security Context runAsNonRoot
  ## @param readReplicas.containerSecurityContext.privileged Set container's Security Context privileged
  ## @param readReplicas.containerSecurityContext.readOnlyRootFilesystem Set container's Security Context readOnlyRootFilesystem
  ## @param readReplicas.containerSecurityContext.allowPrivilegeEscalation Set container's Security Context allowPrivilegeEscalation
  ## @param readReplicas.containerSecurityContext.capabilities.drop List of capabilities to be dropped
  ## @param readReplicas.containerSecurityContext.seccompProfile.type Set container's Security Context seccomp profile
  ##
  containerSecurityContext:
    enabled: true
    seLinuxOptions: {}
    runAsUser: 1001
    runAsGroup: 1001
    runAsNonRoot: true
    privileged: false
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: "RuntimeDefault"
  ## @param readReplicas.automountServiceAccountToken Mount Service Account token in pod
  ##
  automountServiceAccountToken: false
  ## @param readReplicas.hostAliases PostgreSQL read only pods host aliases
  ## https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/
  ##
  hostAliases: []
  ## @param readReplicas.hostNetwork Specify if host network should be enabled for PostgreSQL pod (PostgreSQL read only)
  ##
  hostNetwork: false
  ## @param readReplicas.hostIPC Specify if host IPC should be enabled for PostgreSQL pod (postgresql primary)
  ##
  hostIPC: false
  ## @param readReplicas.labels Map of labels to add to the statefulset (PostgreSQL read only)
  ##
  labels: {}
  ## @param readReplicas.annotations Annotations for PostgreSQL read only pods
  ##
  annotations: {}
  ## @param readReplicas.podLabels Map of labels to add to the pods (PostgreSQL read only)
  ##
  podLabels: {}
  ## @param readReplicas.podAnnotations Map of annotations to add to the pods (PostgreSQL read only)
  ##
  podAnnotations: {}
  ## @param readReplicas.podAffinityPreset PostgreSQL read only pod affinity preset. Ignored if `primary.affinity` is set. Allowed values: `soft` or `hard`
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
  ##
  podAffinityPreset: ""
  ## @param readReplicas.podAntiAffinityPreset PostgreSQL read only pod anti-affinity preset. Ignored if `primary.affinity` is set. Allowed values: `soft` or `hard`
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
  ##
  podAntiAffinityPreset: soft
  ## PostgreSQL read only node affinity preset
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity
  ##
  nodeAffinityPreset:
    ## @param readReplicas.nodeAffinityPreset.type PostgreSQL read only node affinity preset type. Ignored if `primary.affinity` is set. Allowed values: `soft` or `hard`
    ##
    type: ""
    ## @param readReplicas.nodeAffinityPreset.key PostgreSQL read only node label key to match Ignored if `primary.affinity` is set.
    ## E.g.
    ## key: "kubernetes.io/e2e-az-name"
    ##
    key: ""
    ## @param readReplicas.nodeAffinityPreset.values PostgreSQL read only node label values to match. Ignored if `primary.affinity` is set.
    ## E.g.
    ## values:
    ##   - e2e-az1
    ##   - e2e-az2
    ##
    values: []
  ## @param readReplicas.affinity Affinity for PostgreSQL read only pods assignment
  ## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
  ## Note: primary.podAffinityPreset, primary.podAntiAffinityPreset, and primary.nodeAffinityPreset will be ignored when it's set
  ##
  affinity: {}
  ## @param readReplicas.nodeSelector Node labels for PostgreSQL read only pods assignment
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
  ##
  nodeSelector: {}
  ## @param readReplicas.tolerations Tolerations for PostgreSQL read only pods assignment
  ## ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
  ##
  tolerations: []
  ## @param readReplicas.topologySpreadConstraints Topology Spread Constraints for pod assignment spread across your cluster among failure-domains. Evaluated as a template
  ## Ref: https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/#spread-constraints-for-pods
  ##
  topologySpreadConstraints: []
  ## @param readReplicas.priorityClassName Priority Class to use for each pod (PostgreSQL read only)
  ##
  priorityClassName: ""
  ## @param readReplicas.schedulerName Use an alternate scheduler, e.g. "stork".
  ## ref: https://kubernetes.io/docs/tasks/administer-cluster/configure-multiple-schedulers/
  ##
  schedulerName: ""
  ## @param readReplicas.terminationGracePeriodSeconds Seconds PostgreSQL read only pod needs to terminate gracefully
  ## ref: https://kubernetes.io/docs/concepts/workloads/pods/pod/#termination-of-pods
  ##
  terminationGracePeriodSeconds: ""
  ## @param readReplicas.updateStrategy.type PostgreSQL read only statefulset strategy type
  ## @param readReplicas.updateStrategy.rollingUpdate PostgreSQL read only statefulset rolling update configuration parameters
  ## ref: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#update-strategies
  ##
  updateStrategy:
    type: RollingUpdate
    rollingUpdate: {}
  ## @param readReplicas.extraVolumeMounts Optionally specify extra list of additional volumeMounts for the PostgreSQL read only container(s)
  ##
  extraVolumeMounts: []
  ## @param readReplicas.extraVolumes Optionally specify extra list of additional volumes for the PostgreSQL read only pod(s)
  ##
  extraVolumes: []
  ## @param readReplicas.sidecars Add additional sidecar containers to the PostgreSQL read only pod(s)
  ## For example:
  ## sidecars:
  ##   - name: your-image-name
  ##     image: your-image
  ##     imagePullPolicy: Always
  ##     ports:
  ##       - name: portname
  ##         containerPort: 1234
  ##
  sidecars: []
  ## @param readReplicas.initContainers Add additional init containers to the PostgreSQL read only pod(s)
  ## Example
  ##
  ## initContainers:
  ##   - name: do-something
  ##     image: busybox
  ##     command: ['do', 'something']
  ##
  initContainers: []
  ## Pod Disruption Budget configuration
  ## ref: https://kubernetes.io/docs/tasks/run-application/configure-pdb
  ## @param readReplicas.pdb.create Enable/disable a Pod Disruption Budget creation
  ## @param readReplicas.pdb.minAvailable Minimum number/percentage of pods that should remain scheduled
  ## @param readReplicas.pdb.maxUnavailable Maximum number/percentage of pods that may be made unavailable. Defaults to `1` if both `readReplicas.pdb.minAvailable` and `readReplicas.pdb.maxUnavailable` are empty.
  ##
  pdb:
    create: true
    minAvailable: ""
    maxUnavailable: ""
  ## @param readReplicas.extraPodSpec Optionally specify extra PodSpec for the PostgreSQL read only pod(s)
  ##
  extraPodSpec: {}
  ## Network Policies
  ## Ref: https://kubernetes.io/docs/concepts/services-networking/network-policies/
  ##
  networkPolicy:
    ## @param readReplicas.networkPolicy.enabled Specifies whether a NetworkPolicy should be created
    ##
    enabled: true
    ## @param readReplicas.networkPolicy.allowExternal Don't require server label for connections
    ## The Policy model to apply. When set to false, only pods with the correct
    ## server label will have network access to the ports server is listening
    ## on. When true, server will accept connections from any source
    ## (with the correct destination port).
    ##
    allowExternal: true
    ## @param readReplicas.networkPolicy.allowExternalEgress Allow the pod to access any range of port and all destinations.
    ##
    allowExternalEgress: true
    ## @param readReplicas.networkPolicy.extraIngress [array] Add extra ingress rules to the NetworkPolicy
    ## e.g:
    ## extraIngress:
    ##   - ports:
    ##       - port: 1234
    ##     from:
    ##       - podSelector:
    ##           - matchLabels:
    ##               - role: frontend
    ##       - podSelector:
    ##           - matchExpressions:
    ##               - key: role
    ##                 operator: In
    ##                 values:
    ##                   - frontend
    extraIngress: []
    ## @param readReplicas.networkPolicy.extraEgress [array] Add extra ingress rules to the NetworkPolicy
    ## e.g:
    ## extraEgress:
    ##   - ports:
    ##       - port: 1234
    ##     to:
    ##       - podSelector:
    ##           - matchLabels:
    ##               - role: frontend
    ##       - podSelector:
    ##           - matchExpressions:
    ##               - key: role
    ##                 operator: In
    ##                 values:
    ##                   - frontend
    ##
    extraEgress: []
    ## @param readReplicas.networkPolicy.ingressNSMatchLabels [object] Labels to match to allow traffic from other namespaces
    ## @param readReplicas.networkPolicy.ingressNSPodMatchLabels [object] Pod labels to match to allow traffic from other namespaces
    ##
    ingressNSMatchLabels: {}
    ingressNSPodMatchLabels: {}
  ## PostgreSQL read only service configuration
  ##
  service:
    ## @param readReplicas.service.type Kubernetes Service type
    ##
    type: ClusterIP
    ## @param readReplicas.service.ports.postgresql PostgreSQL service port
    ##
    ports:
      postgresql: 5432
    ## Node ports to expose
    ## NOTE: choose port between <30000-32767>
    ## @param readReplicas.service.nodePorts.postgresql Node port for PostgreSQL
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport
    ##
    nodePorts:
      postgresql: ""
    ## @param readReplicas.service.clusterIP Static clusterIP or None for headless services
    ## e.g:
    ## clusterIP: None
    ##
    clusterIP: ""
    ## @param readReplicas.service.annotations Annotations for PostgreSQL read only service
    ##
    annotations: {}
    ## @param readReplicas.service.loadBalancerClass Load balancer class if service type is `LoadBalancer`
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#load-balancer-class
    ##
    loadBalancerClass: ""
    ## @param readReplicas.service.loadBalancerIP Load balancer IP if service type is `LoadBalancer`
    ## Set the LoadBalancer service type to internal only
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#internal-load-balancer
    ##
    loadBalancerIP: ""
    ## @param readReplicas.service.externalTrafficPolicy Enable client source IP preservation
    ## ref https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip
    ##
    externalTrafficPolicy: Cluster
    ## @param readReplicas.service.loadBalancerSourceRanges Addresses that are allowed when service is LoadBalancer
    ## https://kubernetes.io/docs/tasks/access-application-cluster/configure-cloud-provider-firewall/#restrict-access-for-loadbalancer-service
    ##
    ## loadBalancerSourceRanges:
    ## - 10.10.10.0/24
    ##
    loadBalancerSourceRanges: []
    ## @param readReplicas.service.extraPorts Extra ports to expose in the PostgreSQL read only service
    ##
    extraPorts: []
    ## @param readReplicas.service.sessionAffinity Session Affinity for Kubernetes service, can be "None" or "ClientIP"
    ## If "ClientIP", consecutive client requests will be directed to the same Pod
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#virtual-ips-and-service-proxies
    ##
    sessionAffinity: None
    ## @param readReplicas.service.sessionAffinityConfig Additional settings for the sessionAffinity
    ## sessionAffinityConfig:
    ##   clientIP:
    ##     timeoutSeconds: 300
    ##
    sessionAffinityConfig: {}
    ## Headless service properties
    ##
    headless:
      ## @param readReplicas.service.headless.annotations Additional custom annotations for headless PostgreSQL read only service
      ##
      annotations: {}
  ## PostgreSQL read only persistence configuration
  ##
  persistence:
    ## @param readReplicas.persistence.enabled Enable PostgreSQL read only data persistence using PVC
    ##
    enabled: true
    ## @param readReplicas.persistence.existingClaim Name of an existing PVC to use
    ##
    existingClaim: ""
    ## @param readReplicas.persistence.mountPath The path the volume will be mounted at
    ## Note: useful when using custom PostgreSQL images
    ##
    mountPath: /bitnami/postgresql
    ## @param readReplicas.persistence.subPath The subdirectory of the volume to mount to
    ## Useful in dev environments and one PV for multiple services
    ##
    subPath: ""
    ## @param readReplicas.persistence.storageClass PVC Storage Class for PostgreSQL read only data volume
    ## If defined, storageClassName: <storageClass>
    ## If set to "-", storageClassName: "", which disables dynamic provisioning
    ## If undefined (the default) or set to null, no storageClassName spec is
    ##   set, choosing the default provisioner.  (gp2 on AWS, standard on
    ##   GKE, AWS & OpenStack)
    ##
    storageClass: ""
    ## @param readReplicas.persistence.accessModes PVC Access Mode for PostgreSQL volume
    ##
    accessModes:
      - ReadWriteOnce
    ## @param readReplicas.persistence.size PVC Storage Request for PostgreSQL volume
    ##
    size: 8Gi
    ## @param readReplicas.persistence.annotations Annotations for the PVC
    ##
    annotations: {}
    ## @param readReplicas.persistence.labels Labels for the PVC
    ##
    labels: {}
    ## @param readReplicas.persistence.selector Selector to match an existing Persistent Volume (this value is evaluated as a template)
    ## selector:
    ##   matchLabels:
    ##     app: my-app
    ##
    selector: {}
    ## @param readReplicas.persistence.dataSource Custom PVC data source
    ##
    dataSource: {}
  ## PostgreSQL Read only Persistent Volume Claim Retention Policy
  ## ref: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#persistentvolumeclaim-retention
  ##
  persistentVolumeClaimRetentionPolicy:
    ## @param readReplicas.persistentVolumeClaimRetentionPolicy.enabled Enable Persistent volume retention policy for read only Statefulset
    ##
    enabled: false
    ## @param readReplicas.persistentVolumeClaimRetentionPolicy.whenScaled Volume retention behavior when the replica count of the StatefulSet is reduced
    ##
    whenScaled: Retain
    ## @param readReplicas.persistentVolumeClaimRetentionPolicy.whenDeleted Volume retention behavior that applies when the StatefulSet is deleted
    ##
    whenDeleted: Retain
## @section Backup parameters
## This section implements a trivial logical dump cronjob of the database.
## This only comes with the consistency guarantees of the dump program.
## This is not a snapshot based roll forward/backward recovery backup.
## ref: https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
backup:
  ## @param backup.enabled Enable the logical dump of the database "regularly"
  enabled: false
  cronjob:
    ## @param backup.cronjob.schedule Set the cronjob parameter schedule
    schedule: "@daily"
    ## @param backup.cronjob.timeZone Set the cronjob parameter timeZone
    timeZone: ""
    ## @param backup.cronjob.concurrencyPolicy Set the cronjob parameter concurrencyPolicy
    concurrencyPolicy: Allow
    ## @param backup.cronjob.failedJobsHistoryLimit Set the cronjob parameter failedJobsHistoryLimit
    failedJobsHistoryLimit: 1
    ## @param backup.cronjob.successfulJobsHistoryLimit Set the cronjob parameter successfulJobsHistoryLimit
    successfulJobsHistoryLimit: 3
    ## @param backup.cronjob.startingDeadlineSeconds Set the cronjob parameter startingDeadlineSeconds
    startingDeadlineSeconds: ""
    ## @param backup.cronjob.ttlSecondsAfterFinished Set the cronjob parameter ttlSecondsAfterFinished
    ttlSecondsAfterFinished: ""
    ## @param backup.cronjob.restartPolicy Set the cronjob parameter restartPolicy
    restartPolicy: OnFailure
    ## @param backup.cronjob.podSecurityContext.enabled Enable PodSecurityContext for CronJob/Backup
    ## @param backup.cronjob.podSecurityContext.fsGroupChangePolicy Set filesystem group change policy
    ## @param backup.cronjob.podSecurityContext.sysctls Set kernel settings using the sysctl interface
    ## @param backup.cronjob.podSecurityContext.supplementalGroups Set filesystem extra groups
    ## @param backup.cronjob.podSecurityContext.fsGroup Group ID for the CronJob
    podSecurityContext:
      enabled: true
      fsGroupChangePolicy: Always
      sysctls: []
      supplementalGroups: []
      fsGroup: 1001
    ## backup container's Security Context
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container
    ## @param backup.cronjob.containerSecurityContext.enabled Enabled containers' Security Context
    ## @param backup.cronjob.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
    ## @param backup.cronjob.containerSecurityContext.runAsUser Set containers' Security Context runAsUser
    ## @param backup.cronjob.containerSecurityContext.runAsGroup Set containers' Security Context runAsGroup
    ## @param backup.cronjob.containerSecurityContext.runAsNonRoot Set container's Security Context runAsNonRoot
    ## @param backup.cronjob.containerSecurityContext.privileged Set container's Security Context privileged
    ## @param backup.cronjob.containerSecurityContext.readOnlyRootFilesystem Set container's Security Context readOnlyRootFilesystem
    ## @param backup.cronjob.containerSecurityContext.allowPrivilegeEscalation Set container's Security Context allowPrivilegeEscalation
    ## @param backup.cronjob.containerSecurityContext.capabilities.drop List of capabilities to be dropped
    ## @param backup.cronjob.containerSecurityContext.seccompProfile.type Set container's Security Context seccomp profile
    containerSecurityContext:
      enabled: true
      seLinuxOptions: {}
      runAsUser: 1001
      runAsGroup: 1001
      runAsNonRoot: true
      privileged: false
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: "RuntimeDefault"
    ## @param backup.cronjob.command Set backup container's command to run
    command:
      - /bin/sh
      - -c
      - "pg_dumpall --clean --if-exists --load-via-partition-root --quote-all-identifiers --no-password --file=${PGDUMP_DIR}/pg_dumpall-$(date '+%Y-%m-%d-%H-%M').pgdump"
    ## @param backup.cronjob.labels Set the cronjob labels
    labels: {}
    ## @param backup.cronjob.annotations Set the cronjob annotations
    annotations: {}
    ## @param backup.cronjob.nodeSelector Node labels for PostgreSQL backup CronJob pod assignment
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/
    ##
    nodeSelector: {}
    ## @param backup.cronjob.tolerations Tolerations for PostgreSQL backup CronJob pods assignment
    ## ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
    ##
    tolerations: []
    ## backup cronjob container resource requests and limits
    ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
    ## @param backup.cronjob.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if backup.cronjob.resources is set (backup.cronjob.resources is recommended for production).
    ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
    ##
    resourcesPreset: "nano"
    ## @param backup.cronjob.resources Set container requests and limits for different resources like CPU or memory
    ## Example:
    resources: {}
    ## resources:
    ##   requests:
    ##     cpu: 1
    ##     memory: 512Mi
    ##   limits:
    ##     cpu: 2
    ##     memory: 1024Mi
    networkPolicy:
      ## @param backup.cronjob.networkPolicy.enabled Specifies whether a NetworkPolicy should be created
      ##
      enabled: true
    storage:
      ## @param backup.cronjob.storage.enabled Enable using a `PersistentVolumeClaim` as backup data volume
      ##
      enabled: true
      ## @param backup.cronjob.storage.existingClaim Provide an existing `PersistentVolumeClaim` (only when `architecture=standalone`)
      ## If defined, PVC must be created manually before volume will be bound
      ##
      existingClaim: ""
      ## @param backup.cronjob.storage.resourcePolicy Setting it to "keep" to avoid removing PVCs during a helm delete operation. Leaving it empty will delete PVCs after the chart deleted
      ##
      resourcePolicy: ""
      ## @param backup.cronjob.storage.storageClass PVC Storage Class for the backup data volume
      ## If defined, storageClassName: <storageClass>
      ## If set to "-", storageClassName: "", which disables dynamic provisioning
      ## If undefined (the default) or set to null, no storageClassName spec is
      ## set, choosing the default provisioner.
      ##
      storageClass: ""
      ## @param backup.cronjob.storage.accessModes PV Access Mode
      ##
      accessModes:
        - ReadWriteOnce
      ## @param backup.cronjob.storage.size PVC Storage Request for the backup data volume
      ##
      size: 8Gi
      ## @param backup.cronjob.storage.annotations PVC annotations
      ##
      annotations: {}
      ## @param backup.cronjob.storage.mountPath Path to mount the volume at
      ##
      mountPath: /backup/pgdump
      ## @param backup.cronjob.storage.subPath Subdirectory of the volume to mount at
      ## and one PV for multiple services.
      ##
      subPath: ""
      ## Fine tuning for volumeClaimTemplates
      ##
      volumeClaimTemplates:
        ## @param backup.cronjob.storage.volumeClaimTemplates.selector A label query over volumes to consider for binding (e.g. when using local volumes)
        ## A label query over volumes to consider for binding (e.g. when using local volumes)
        ## See https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/#labelselector-v1-meta for more details
        ##
        selector: {}
    ## @param backup.cronjob.extraVolumeMounts Optionally specify extra list of additional volumeMounts for the backup container
    ##
    extraVolumeMounts: []
    ## @param backup.cronjob.extraVolumes Optionally specify extra list of additional volumes for the backup container
    ##
    extraVolumes: []

## @section Password update job
##
passwordUpdateJob:
  ## @param passwordUpdateJob.enabled Enable password update job
  ##
  enabled: false
  ## @param passwordUpdateJob.backoffLimit set backoff limit of the job
  ##
  backoffLimit: 10
  ## @param passwordUpdateJob.command Override default container command on mysql Primary container(s) (useful when using custom images)
  ##
  command: []
  ## @param passwordUpdateJob.args Override default container args on mysql Primary container(s) (useful when using custom images)
  ##
  args: []
  ## @param passwordUpdateJob.extraCommands Extra commands to pass to the generation job
  ##
  extraCommands: ""
  ## @param passwordUpdateJob.previousPasswords.postgresPassword Previous postgres password (set if the password secret was already changed)
  ## @param passwordUpdateJob.previousPasswords.password Previous password (set if the password secret was already changed)
  ## @param passwordUpdateJob.previousPasswords.replicationPassword Previous replication password (set if the password secret was already changed)
  ## @param passwordUpdateJob.previousPasswords.existingSecret Name of a secret containing the previous passwords (set if the password secret was already changed)
  previousPasswords:
    postgresPassword: ""
    password: ""
    replicationPassword: ""
    existingSecret: ""
  ## Configure Container Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container
  ## @param passwordUpdateJob.containerSecurityContext.enabled Enabled containers' Security Context
  ## @param passwordUpdateJob.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
  ## @param passwordUpdateJob.containerSecurityContext.runAsUser Set containers' Security Context runAsUser
  ## @param passwordUpdateJob.containerSecurityContext.runAsGroup Set containers' Security Context runAsGroup
  ## @param passwordUpdateJob.containerSecurityContext.runAsNonRoot Set container's Security Context runAsNonRoot
  ## @param passwordUpdateJob.containerSecurityContext.privileged Set container's Security Context privileged
  ## @param passwordUpdateJob.containerSecurityContext.readOnlyRootFilesystem Set container's Security Context readOnlyRootFilesystem
  ## @param passwordUpdateJob.containerSecurityContext.allowPrivilegeEscalation Set container's Security Context allowPrivilegeEscalation
  ## @param passwordUpdateJob.containerSecurityContext.capabilities.drop List of capabilities to be dropped
  ## @param passwordUpdateJob.containerSecurityContext.seccompProfile.type Set container's Security Context seccomp profile
  ##
  containerSecurityContext:
    enabled: true
    seLinuxOptions: {}
    runAsUser: 1001
    runAsGroup: 1001
    runAsNonRoot: true
    privileged: false
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: "RuntimeDefault"
  ## Configure Pods Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod
  ## @param passwordUpdateJob.podSecurityContext.enabled Enabled credential init job pods' Security Context
  ## @param passwordUpdateJob.podSecurityContext.fsGroupChangePolicy Set filesystem group change policy
  ## @param passwordUpdateJob.podSecurityContext.sysctls Set kernel settings using the sysctl interface
  ## @param passwordUpdateJob.podSecurityContext.supplementalGroups Set filesystem extra groups
  ## @param passwordUpdateJob.podSecurityContext.fsGroup Set credential init job pod's Security Context fsGroup
  ##
  podSecurityContext:
    enabled: true
    fsGroupChangePolicy: Always
    sysctls: []
    supplementalGroups: []
    fsGroup: 1001
  ## @param passwordUpdateJob.extraEnvVars Array containing extra env vars to configure the credential init job
  ## For example:
  ## extraEnvVars:
  ##  - name: GF_DEFAULT_INSTANCE_NAME
  ##    value: my-instance
  ##
  extraEnvVars: []
  ## @param passwordUpdateJob.extraEnvVarsCM ConfigMap containing extra env vars to configure the credential init job
  ##
  extraEnvVarsCM: ""
  ## @param passwordUpdateJob.extraEnvVarsSecret Secret containing extra env vars to configure the credential init job (in case of sensitive data)
  ##
  extraEnvVarsSecret: ""
  ## @param passwordUpdateJob.extraVolumes Optionally specify extra list of additional volumes for the credential init job
  ##
  extraVolumes: []
  ## @param passwordUpdateJob.extraVolumeMounts Array of extra volume mounts to be added to the jwt Container (evaluated as template). Normally used with `extraVolumes`.
  ##
  extraVolumeMounts: []
  ## @param passwordUpdateJob.initContainers Add additional init containers for the mysql Primary pod(s)
  ##
  initContainers: []
  ## Container resource requests and limits
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param passwordUpdateJob.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if passwordUpdateJob.resources is set (passwordUpdateJob.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  ##
  resourcesPreset: "micro"
  ## @param passwordUpdateJob.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
  ## Example:
  ## resources:
  ##   requests:
  ##     cpu: 2
  ##     memory: 512Mi
  ##   limits:
  ##     cpu: 3
  ##     memory: 1024Mi
  ##
  resources: {}
  ## @param passwordUpdateJob.customLivenessProbe Custom livenessProbe that overrides the default one
  ##
  customLivenessProbe: {}
  ## @param passwordUpdateJob.customReadinessProbe Custom readinessProbe that overrides the default one
  ##
  customReadinessProbe: {}
  ## @param passwordUpdateJob.customStartupProbe Custom startupProbe that overrides the default one
  ##
  customStartupProbe: {}
  ## @param passwordUpdateJob.automountServiceAccountToken Mount Service Account token in pod
  ##
  automountServiceAccountToken: false
  ## @param passwordUpdateJob.hostAliases Add deployment host aliases
  ## https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/
  ##
  hostAliases: []
  ## @param passwordUpdateJob.annotations [object] Add annotations to the job
  ##
  annotations: {}
  ## @param passwordUpdateJob.podLabels Additional pod labels
  ## Ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
  ##
  podLabels: {}
  ## @param passwordUpdateJob.podAnnotations Additional pod annotations
  ## ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
  ##
  podAnnotations: {}

## @section Volume Permissions parameters
##

## Init containers parameters:
## volumePermissions: Change the owner and group of the persistent volume(s) mountpoint(s) to 'runAsUser:fsGroup' on each node
##
volumePermissions:
  ## @param volumePermissions.enabled Enable init container that changes the owner and group of the persistent volume
  ##
  enabled: false
  ## @param volumePermissions.image.registry [default: REGISTRY_NAME] Init container volume-permissions image registry
  ## @param volumePermissions.image.repository [default: REPOSITORY_NAME/os-shell] Init container volume-permissions image repository
  ## @skip volumePermissions.image.tag Init container volume-permissions image tag (immutable tags are recommended)
  ## @param volumePermissions.image.digest Init container volume-permissions image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag
  ## @param volumePermissions.image.pullPolicy Init container volume-permissions image pull policy
  ## @param volumePermissions.image.pullSecrets Init container volume-permissions image pull secrets
  ##
  image:
    registry: docker.io
    repository: bitnami/os-shell
    tag: 12-debian-12-r39
    digest: ""
    pullPolicy: IfNotPresent
    ## Optionally specify an array of imagePullSecrets.
    ## Secrets must be manually created in the namespace.
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
    ## Example:
    ## pullSecrets:
    ##   - myRegistryKeySecretName
    ##
    pullSecrets: []
  ## Init container resource requests and limits
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param volumePermissions.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if volumePermissions.resources is set (volumePermissions.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  ##
  resourcesPreset: "nano"
  ## @param volumePermissions.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
  ## Example:
  ## resources:
  ##   requests:
  ##     cpu: 2
  ##     memory: 512Mi
  ##   limits:
  ##     cpu: 3
  ##     memory: 1024Mi
  ##
  resources: {}
  ## Init container' Security Context
  ## Note: the chown of the data folder is done to containerSecurityContext.runAsUser
  ## and not the below volumePermissions.containerSecurityContext.runAsUser
  ## @param volumePermissions.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
  ## @param volumePermissions.containerSecurityContext.runAsUser User ID for the init container
  ## @param volumePermissions.containerSecurityContext.runAsGroup Group ID for the init container
  ## @param volumePermissions.containerSecurityContext.runAsNonRoot runAsNonRoot for the init container
  ## @param volumePermissions.containerSecurityContext.seccompProfile.type seccompProfile.type for the init container
  ##
  containerSecurityContext:
    seLinuxOptions: {}
    runAsUser: 0
    runAsGroup: 0
    runAsNonRoot: false
    seccompProfile:
      type: RuntimeDefault
## @section Other Parameters
##

## @param serviceBindings.enabled Create secret for service binding (Experimental)
## Ref: https://servicebinding.io/service-provider/
##
serviceBindings:
  enabled: false
## Service account for PostgreSQL to use.
## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
##
serviceAccount:
  ## @param serviceAccount.create Enable creation of ServiceAccount for PostgreSQL pod
  ##
  create: true
  ## @param serviceAccount.name The name of the ServiceAccount to use.
  ## If not set and create is true, a name is generated using the common.names.fullname template
  ##
  name: ""
  ## @param serviceAccount.automountServiceAccountToken Allows auto mount of ServiceAccountToken on the serviceAccount created
  ## Can be set to false if pods using this serviceAccount do not need to use K8s API
  ##
  automountServiceAccountToken: false
  ## @param serviceAccount.annotations Additional custom annotations for the ServiceAccount
  ##
  annotations: {}
## Creates role for ServiceAccount
## @param rbac.create Create Role and RoleBinding (required for PSP to work)
##
rbac:
  create: false
  ## @param rbac.rules Custom RBAC rules to set
  ## e.g:
  ## rules:
  ##   - apiGroups:
  ##       - ""
  ##     resources:
  ##       - pods
  ##     verbs:
  ##       - get
  ##       - list
  ##
  rules: []
## Pod Security Policy
## ref: https://kubernetes.io/docs/concepts/policy/pod-security-policy/
## @param psp.create Whether to create a PodSecurityPolicy. WARNING: PodSecurityPolicy is deprecated in Kubernetes v1.21 or later, unavailable in v1.25 or later
##
psp:
  create: false
## @section Metrics Parameters
##
metrics:
  ## @param metrics.enabled Start a prometheus exporter
  ##
  enabled: false
  ## @param metrics.image.registry [default: REGISTRY_NAME] PostgreSQL Prometheus Exporter image registry
  ## @param metrics.image.repository [default: REPOSITORY_NAME/postgres-exporter] PostgreSQL Prometheus Exporter image repository
  ## @skip metrics.image.tag PostgreSQL Prometheus Exporter image tag (immutable tags are recommended)
  ## @param metrics.image.digest PostgreSQL image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag
  ## @param metrics.image.pullPolicy PostgreSQL Prometheus Exporter image pull policy
  ## @param metrics.image.pullSecrets Specify image pull secrets
  ##
  image:
    registry: docker.io
    repository: bitnami/postgres-exporter
    tag: 0.17.1-debian-12-r0
    digest: ""
    pullPolicy: IfNotPresent
    ## Optionally specify an array of imagePullSecrets.
    ## Secrets must be manually created in the namespace.
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
    ## Example:
    ## pullSecrets:
    ##   - myRegistryKeySecretName
    ##
    pullSecrets: []
  ## @param metrics.collectors Control enabled collectors
  ## ref: https://github.com/prometheus-community/postgres_exporter#flags
  ## Example:
  ## collectors:
  ##   wal: false
  collectors: {}
  ## @param metrics.customMetrics Define additional custom metrics
  ## ref: https://github.com/prometheus-community/postgres_exporter#adding-new-metrics-via-a-config-file-deprecated
  ## customMetrics:
  ##   pg_database:
  ##     query: "SELECT d.datname AS name, CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT') THEN pg_catalog.pg_database_size(d.datname) ELSE 0 END AS size_bytes FROM pg_catalog.pg_database d where datname not in ('template0', 'template1', 'postgres')"
  ##     metrics:
  ##       - name:
  ##           usage: "LABEL"
  ##           description: "Name of the database"
  ##       - size_bytes:
  ##           usage: "GAUGE"
  ##           description: "Size of the database in bytes"
  ##
  customMetrics: {}
  ## @param metrics.extraEnvVars Extra environment variables to add to PostgreSQL Prometheus exporter
  ## see: https://github.com/prometheus-community/postgres_exporter#environment-variables
  ## For example:
  ##  extraEnvVars:
  ##  - name: PG_EXPORTER_DISABLE_DEFAULT_METRICS
  ##    value: "true"
  ##
  extraEnvVars: []
  ## PostgreSQL Prometheus exporter containers' Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container
  ## @param metrics.containerSecurityContext.enabled Enabled containers' Security Context
  ## @param metrics.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
  ## @param metrics.containerSecurityContext.runAsUser Set containers' Security Context runAsUser
  ## @param metrics.containerSecurityContext.runAsGroup Set containers' Security Context runAsGroup
  ## @param metrics.containerSecurityContext.runAsNonRoot Set container's Security Context runAsNonRoot
  ## @param metrics.containerSecurityContext.privileged Set container's Security Context privileged
  ## @param metrics.containerSecurityContext.readOnlyRootFilesystem Set container's Security Context readOnlyRootFilesystem
  ## @param metrics.containerSecurityContext.allowPrivilegeEscalation Set container's Security Context allowPrivilegeEscalation
  ## @param metrics.containerSecurityContext.capabilities.drop List of capabilities to be dropped
  ## @param metrics.containerSecurityContext.seccompProfile.type Set container's Security Context seccomp profile
  ##
  containerSecurityContext:
    enabled: true
    seLinuxOptions: {}
    runAsUser: 1001
    runAsGroup: 1001
    runAsNonRoot: true
    privileged: false
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: "RuntimeDefault"
  ## Configure extra options for PostgreSQL Prometheus exporter containers' liveness, readiness and startup probes
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#configure-probes
  ## @param metrics.livenessProbe.enabled Enable livenessProbe on PostgreSQL Prometheus exporter containers
  ## @param metrics.livenessProbe.initialDelaySeconds Initial delay seconds for livenessProbe
  ## @param metrics.livenessProbe.periodSeconds Period seconds for livenessProbe
  ## @param metrics.livenessProbe.timeoutSeconds Timeout seconds for livenessProbe
  ## @param metrics.livenessProbe.failureThreshold Failure threshold for livenessProbe
  ## @param metrics.livenessProbe.successThreshold Success threshold for livenessProbe
  ##
  livenessProbe:
    enabled: true
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## @param metrics.readinessProbe.enabled Enable readinessProbe on PostgreSQL Prometheus exporter containers
  ## @param metrics.readinessProbe.initialDelaySeconds Initial delay seconds for readinessProbe
  ## @param metrics.readinessProbe.periodSeconds Period seconds for readinessProbe
  ## @param metrics.readinessProbe.timeoutSeconds Timeout seconds for readinessProbe
  ## @param metrics.readinessProbe.failureThreshold Failure threshold for readinessProbe
  ## @param metrics.readinessProbe.successThreshold Success threshold for readinessProbe
  ##
  readinessProbe:
    enabled: true
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## @param metrics.startupProbe.enabled Enable startupProbe on PostgreSQL Prometheus exporter containers
  ## @param metrics.startupProbe.initialDelaySeconds Initial delay seconds for startupProbe
  ## @param metrics.startupProbe.periodSeconds Period seconds for startupProbe
  ## @param metrics.startupProbe.timeoutSeconds Timeout seconds for startupProbe
  ## @param metrics.startupProbe.failureThreshold Failure threshold for startupProbe
  ## @param metrics.startupProbe.successThreshold Success threshold for startupProbe
  ##
  startupProbe:
    enabled: false
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 1
    failureThreshold: 15
    successThreshold: 1
  ## @param metrics.customLivenessProbe Custom livenessProbe that overrides the default one
  ##
  customLivenessProbe: {}
  ## @param metrics.customReadinessProbe Custom readinessProbe that overrides the default one
  ##
  customReadinessProbe: {}
  ## @param metrics.customStartupProbe Custom startupProbe that overrides the default one
  ##
  customStartupProbe: {}
  ## @param metrics.containerPorts.metrics PostgreSQL Prometheus exporter metrics container port
  ##
  containerPorts:
    metrics: 9187
  ## PostgreSQL Prometheus exporter resource requests and limits
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param metrics.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if metrics.resources is set (metrics.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  ##
  resourcesPreset: "nano"
  ## @param metrics.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
  ## Example:
  ## resources:
  ##   requests:
  ##     cpu: 2
  ##     memory: 512Mi
  ##   limits:
  ##     cpu: 3
  ##     memory: 1024Mi
  ##
  resources: {}
  ## Service configuration
  ##
  service:
    ## @param metrics.service.ports.metrics PostgreSQL Prometheus Exporter service port
    ##
    ports:
      metrics: 9187
    ## @param metrics.service.clusterIP Static clusterIP or None for headless services
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#choosing-your-own-ip-address
    ##
    clusterIP: ""
    ## @param metrics.service.sessionAffinity Control where client requests go, to the same pod or round-robin
    ## Values: ClientIP or None
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/
    ##
    sessionAffinity: None
    ## @param metrics.service.annotations [object] Annotations for Prometheus to auto-discover the metrics endpoint
    ##
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "{{ .Values.metrics.service.ports.metrics }}"
  ## Prometheus Operator ServiceMonitor configuration
  ##
  serviceMonitor:
    ## @param metrics.serviceMonitor.enabled Create ServiceMonitor Resource for scraping metrics using Prometheus Operator
    ##
    enabled: false
    ## @param metrics.serviceMonitor.namespace Namespace for the ServiceMonitor Resource (defaults to the Release Namespace)
    ##
    namespace: ""
    ## @param metrics.serviceMonitor.interval Interval at which metrics should be scraped.
    ## ref: https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#endpoint
    ##
    interval: ""
    ## @param metrics.serviceMonitor.scrapeTimeout Timeout after which the scrape is ended
    ## ref: https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#endpoint
    ##
    scrapeTimeout: ""
    ## @param metrics.serviceMonitor.labels Additional labels that can be used so ServiceMonitor will be discovered by Prometheus
    ##
    labels: {}
    ## @param metrics.serviceMonitor.selector Prometheus instance selector labels
    ## ref: https://github.com/bitnami/charts/tree/main/bitnami/prometheus-operator#prometheus-configuration
    ##
    selector: {}
    ## @param metrics.serviceMonitor.relabelings RelabelConfigs to apply to samples before scraping
    ##
    relabelings: []
    ## @param metrics.serviceMonitor.metricRelabelings MetricRelabelConfigs to apply to samples before ingestion
    ##
    metricRelabelings: []
    ## @param metrics.serviceMonitor.honorLabels Specify honorLabels parameter to add the scrape endpoint
    ##
    honorLabels: false
    ## @param metrics.serviceMonitor.jobLabel The name of the label on the target service to use as the job name in prometheus.
    ##
    jobLabel: ""
  ## Custom PrometheusRule to be defined
  ## The value is evaluated as a template, so, for example, the value can depend on .Release or .Chart
  ## ref: https://github.com/coreos/prometheus-operator#customresourcedefinitions
  ##
  prometheusRule:
    ## @param metrics.prometheusRule.enabled Create a PrometheusRule for Prometheus Operator
    ##
    enabled: false
    ## @param metrics.prometheusRule.namespace Namespace for the PrometheusRule Resource (defaults to the Release Namespace)
    ##
    namespace: ""
    ## @param metrics.prometheusRule.labels Additional labels that can be used so PrometheusRule will be discovered by Prometheus
    ##
    labels: {}
    ## @param metrics.prometheusRule.rules PrometheusRule definitions
    ## Make sure to constraint the rules to the current postgresql service.
    ## rules:
    ##   - alert: HugeReplicationLag
    ##     expr: pg_replication_lag{service="{{ printf "%s-metrics" (include "common.names.fullname" .) }}"} / 3600 > 1
    ##     for: 1m
    ##     labels:
    ##       severity: critical
    ##     annotations:
    ##       description: replication for {{ include "common.names.fullname" . }} PostgreSQL is lagging by {{ "{{ $value }}" }} hour(s).
    ##       summary: PostgreSQL replication is lagging by {{ "{{ $value }}" }} hour(s).
    ##
    rules: []
EOF

helm dependency update
helm install postgresdb .

wait_for_pod "app.kubernetes.io/name=postgresql"

# Create databases
export POSTGRES_PASSWORD=$(kubectl get secret --namespace default postgresdb-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
kubectl run postgresdb-postgresql-client --rm --tty -i --restart='Never' --namespace default --image docker.io/bitnami/postgresql:17.4.0-debian-12-r4 --env="PGPASSWORD=$POSTGRES_PASSWORD" --command -- psql --host postgresdb-postgresql -U postgres -d postgres -p 5432 <<EOF
CREATE DATABASE sonar;
CREATE DATABASE prefect;
EOF

# Clone and install Prefect
cd ~
git clone https://github.com/PrefectHQ/prefect-helm
cd prefect-helm/charts/prefect-server

# Modify values.yaml
cat <<EOF > values.yaml
## Common parameters
# -- partially overrides common.names.name
nameOverride: ""
# -- fully override common.names.fullname
fullnameOverride: "prefect-server"
# -- fully override common.names.namespace
namespaceOverride: ""
# -- labels to add to all deployed objects
commonLabels: {}
# -- annotations to add to all deployed objects
commonAnnotations: {}

## Global Deployment Configuration
global:
  prefect:
    image:
      # -- prefect image repository
      repository: prefecthq/prefect
      ## prefect tag is pinned to the latest available image tag at packaging time.  Update the value here to
      ## override pinned tag
      # -- prefect image tag (immutable tags are recommended)
      prefectTag: 3-latest
      # -- prefect image pull policy
      pullPolicy: IfNotPresent
      ## Optionally specify an array of imagePullSecrets.
      ## Secrets must be manually created in the namespace.
      # ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
      ## e.g:
      ## pullSecrets:
      ##   - myRegistryKeySecretName
      # -- prefect image pull secrets
      pullSecrets: []

    # see here for a full list of possible environment variables - https://docs.prefect.io/latest/api-ref/prefect/settings/
    # -- array with environment variables to add to all deployments
    env: []
      ##env:
      ##- name: PREFECT_API_DATABASE_CONNECTION_URL
      ## value: "postgresql://postgres:admin@postgresdb-postgresql:5432/prefect"

## Server Deployment Configuration
server:
  # ref: https://docs.prefect.io/v3/develop/settings-and-profiles#security-settings
  basicAuth:
    # -- enable basic auth for the server, for an administrator/password combination
    enabled: false
    # -- basic auth credentials in the format admin:<your-password> (no brackets)
    authString: "admin:pass"
    # -- name of existing secret containing basic auth credentials. takes precedence over authString. must contain a key `auth-string` with the value of the auth string
    existingSecret: ""

  # ref: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#priorityclass
  # -- priority class name to use for the server pods; if the priority class is empty or doesn't exist, the server pods are scheduled without a priority class
  priorityClassName: ""

  # ref: https://docs.prefect.io/v3/develop/settings-ref#base-path
  # -- sets PREFECT_SERVER_API_BASE_PATH
  apiBasePath: "/api"

  # ref: https://docs.prefect.io/v3/develop/settings-ref#debug-mode
  # -- sets PREFECT_DEBUG_MODE
  debug: false

  # ref: https://docs.prefect.io/v3/develop/settings-ref#logging-level-2
  # -- sets PREFECT_LOGGING_SERVER_LEVEL
  loggingLevel: WARNING

  uiConfig:
    # -- sets PREFECT_UI_API_URL; If you want to connect to the UI from somewhere external to the cluster (i.e. via an ingress), you need to set this value to the ingress URL (e.g. http://app.internal.prefect.com/api). You can find additional documentation on this here - https://docs.prefect.io/v3/manage/self-host#ui
    prefectUiApiUrl: "http://localhost:4200/api"
    # -- sets PREFECT_UI_STATIC_DIRECTORY
    prefectUiStaticDirectory: "/ui_build"

  # see here for a full list of possible environment variables - https://docs.prefect.io/v3/develop/settings-ref#serversettings
  # -- array with environment variables to add to server deployment
  env: []
  ## env:
  ##   - name: PREFECT_API_ENABLE_HTTP2
  ##     value: false

  # -- Custom container command arguments
  args: []

  # -- Custom container entrypoint
  command: []

  # -- the number of old ReplicaSets to retain to allow rollback
  revisionHistoryLimit: 10

  # Autoscaling configuration
  # requests MUST be specified if using an HPA, otherwise the HPA will not know when to trigger a scale event
  autoscaling:
    # -- enable autoscaling for server
    enabled: false
    # -- minimum number of server replicas
    minReplicas: 1
    # -- maximum number of server replicas
    maxReplicas: 100
    # -- target CPU utilization percentage
    targetCPU: 80
    # -- target Memory utilization percentage
    targetMemory: 80

  # -- number of server replicas to deploy
  replicaCount: 1

  # requests MUST be specified if using an HPA, otherwise the HPA will not know when to trigger a scale event
  resources:
    # -- the requested resources for the server container
    requests:
      cpu: 500m
      memory: 512Mi
    # -- the requested limits for the server container
    limits:
      cpu: "1"
      memory: 1Gi

  # ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
  livenessProbe:
    enabled: false
    config:
      # -- The number of seconds to wait before starting the first probe.
      initialDelaySeconds: 10
      # -- The number of seconds to wait between consecutive probes.
      periodSeconds: 10
      # -- The number of seconds to wait for a probe response before considering it as failed.
      timeoutSeconds: 5
      # -- The number of consecutive failures allowed before considering the probe as failed.
      failureThreshold: 3
      # -- The minimum consecutive successes required to consider the probe successful.
      successThreshold: 1
  readinessProbe:
    enabled: false
    config:
      # -- The number of seconds to wait before starting the first probe.
      initialDelaySeconds: 10
      # -- The number of seconds to wait between consecutive probes.
      periodSeconds: 10
      # -- The number of seconds to wait for a probe response before considering it as failed.
      timeoutSeconds: 5
      # -- The number of consecutive failures allowed before considering the probe as failed.
      failureThreshold: 3
      # -- The minimum consecutive successes required to consider the probe successful.
      successThreshold: 1

  # ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod
  podSecurityContext:
    # -- set server pod's security context runAsUser
    runAsUser: 1001
    # -- set server pod's security context runAsNonRoot
    runAsNonRoot: true
    # -- set server pod's security context fsGroup
    fsGroup: 1001
    # -- set server pod's seccomp profile
    seccompProfile:
      type: RuntimeDefault
      # -- in case of Localhost value in seccompProfile.type, set seccompProfile.localhostProfile value below
      # localhostProfile: /my-path.json

  # ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container
  containerSecurityContext:
    # -- set server containers' security context runAsUser
    runAsUser: 1001
    # -- set server containers' security context runAsNonRoot
    runAsNonRoot: true
    # -- set server containers' security context readOnlyRootFilesystem
    readOnlyRootFilesystem: true
    # -- set server containers' security context allowPrivilegeEscalation
    allowPrivilegeEscalation: false
    # -- set server container's security context capabilities
    capabilities: {}

  # ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
  # -- extra labels for server pod
  podLabels: {}

  # ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
  # -- extra annotations for server pod
  podAnnotations: {}

  # ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
  # -- affinity for server pods assignment
  affinity: {}

  # ref: https://kubernetes.io/docs/user-guide/node-selection/
  # -- node labels for server pods assignment
  nodeSelector: {}

  # ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
  # -- tolerations for server pods assignment
  tolerations: []

  # -- name of existing ConfigMap containing extra env vars to add to server nodes
  extraEnvVarsCM: ""

  # -- name of existing Secret containing extra env vars to add to server nodes
  extraEnvVarsSecret: ""

  # -- additional sidecar containers
  extraContainers: []

  # -- array with extra volumes for the server pod
  extraVolumes: []

  # -- array with extra volumeMounts for the server pod
  extraVolumeMounts: []

  # -- array with extra Arguments for the server container to start with
  extraArgs: []

## Background Services Deployment Configuration
backgroundServices:
  # ref: https://github.com/PrefectHQ/prefect/tree/main/src/prefect/server/services
  # This can help with:
  # - Separate scaling of web server and background services
  # - Independent connection pools for better database management
  # - More granular monitoring and resource control
  # - Run background services (like scheduling) in a separate deployment.
  runAsSeparateDeployment: false

  # ref: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#priorityclass
  # -- priority class name to use for the background-services pods; if the priority class is empty or doesn't exist, the background-services pods are scheduled without a priority class
  priorityClassName: ""

  # ref: https://docs.prefect.io/v3/develop/settings-ref#debug-mode
  # -- sets PREFECT_DEBUG_MODE
  debug: false

  # ref: https://docs.prefect.io/v3/develop/settings-ref#logging-level-2
  # -- sets PREFECT_LOGGING_SERVER_LEVEL
  loggingLevel: WARNING

  # see here for a full list of possible environment variables - https://docs.prefect.io/latest/api-ref/prefect/settings/
  # -- array with environment variables to add to background-services container
  env: []
  ## env:
  ##   - name: PREFECT_API_ENABLE_HTTP2
  ##     value: false

  # -- the number of old ReplicaSets to retain to allow rollback
  revisionHistoryLimit: 10

  resources:
    # -- the requested resources for the background-services container
    requests:
      cpu: 500m
      memory: 512Mi
    # -- the requested limits for the background-services container
    limits:
      cpu: "1"
      memory: 1Gi

  # ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod
  podSecurityContext:
    # -- set background-services pod's security context runAsUser
    runAsUser: 1001
    # -- set background-services pod's security context runAsNonRoot
    runAsNonRoot: true
    # -- set background-services pod's security context fsGroup
    fsGroup: 1001

  # ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container
  containerSecurityContext:
    # -- set background-services containers' security context runAsUser
    runAsUser: 1001
    # -- set background-services containers' security context runAsNonRoot
    runAsNonRoot: true
    # -- set background-services containers' security context readOnlyRootFilesystem
    readOnlyRootFilesystem: true
    # -- set background-services containers' security context allowPrivilegeEscalation
    allowPrivilegeEscalation: false
    # -- set background-services container's security context capabilities
    capabilities: {}

  # ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
  # -- extra labels for background-services pod
  podLabels: {}

  # ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
  # -- extra annotations for background-services pod
  podAnnotations: {}

  # ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
  # -- affinity for background-services pod assignment
  affinity: {}

  # ref: https://kubernetes.io/docs/user-guide/node-selection/
  # -- node labels for background-services pod assignment
  nodeSelector: {}

  # ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
  # -- tolerations for background-services pod assignment
  tolerations: []

  # -- name of existing ConfigMap containing extra env vars to add to background-services pod
  extraEnvVarsCM: ""

  # -- name of existing Secret containing extra env vars to add to background-services pod
  extraEnvVarsSecret: ""

  # -- additional sidecar containers
  extraContainers: []

  # -- array with extra volumes for the background-services pod
  extraVolumes: []

  # -- array with extra volumeMounts for the background-services pod
  extraVolumeMounts: []

  ## Background Services Service Account configuration
  serviceAccount:
    # -- specifies whether a service account should be created
    create: true
    # -- the name of the service account to use. if not set and create is true, a name is generated using the common.names.fullname template with "-background-services" appended
    name: ""
    # -- additional service account annotations (evaluated as a template)
    annotations: {}

## Server Service Account configuration
serviceAccount:
  # -- specifies whether a service account should be created
  create: true
  # -- the name of the service account to use. if not set and create is true, a name is generated using the common.names.fullname template
  name: ""
  # -- additional service account annotations (evaluated as a template)
  annotations: {}

## Service configuration
service:
  # -- service port
  port: 4200
  # -- target port of the server pod; also sets PREFECT_SERVER_API_PORT
  targetPort: 4200
  # -- service port if defining service as type nodeport
  nodePort: ""

  extraPorts: []
    # # example extra ports
    # - name: sample-svc-port
    #   # -- service port
    #   port: 8080
    #   # -- target port
    #   targetPort: 8080
    #   # -- service port if defining service as type nodeport
    #   nodePort: ""

  # -- service type
  type: ClusterIP
  # -- service Cluster IP
  clusterIP: ""


  # ref: http://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip
  # -- service external traffic policy
  externalTrafficPolicy: Cluster
  # -- additional custom annotations for server service
  annotations: {}

# Ingress configuration
ingress:
  # -- enable ingress record generation for server
  enabled: false

  # -- port for the ingress' main path
  servicePort: server-svc-port

  ## This is supported in Kubernetes 1.18+ and required if you have more than one IngressClass marked as the default for your cluster .
  # ref: https://kubernetes.io/blog/2020/04/02/improvements-to-the-ingress-api-in-kubernetes-1.18/
  # -- IngressClass that will be used to implement the Ingress (Kubernetes 1.18+)
  className: ""
  host:
    # -- default host for the ingress record
    hostname: prefect.local
    # -- default path for the ingress record
    path: /
    # -- ingress path type
    pathType: ImplementationSpecific

  ## Use this parameter to set the required annotations for cert-manager, see
  # ref: https://cert-manager.io/docs/usage/ingress/#supported-annotations
  # -- additional annotations for the Ingress resource. To enable certificate autogeneration, place here your cert-manager annotations.
  annotations: {}
  ## annotations:
  ##   kubernetes.io/ingress.class: nginx
  ##   cert-manager.io/cluster-issuer: cluster-issuer-name

  ## TLS certificates will be retrieved from a TLS secret with name: - printf "%s-tls" .Values.ingress.host.hostname 
  ## You can:
  ##   - Create this secret manually within your cluster
  ##   - Rely on cert-manager to create it by setting the corresponding annotations
  ##   - Rely on Helm to create self-signed certificates by setting `ingress.selfSigned=true`
  # -- enable TLS configuration for the host defined at `ingress.host.hostname` parameter
  tls: false
  # -- create a TLS secret for this ingress record using self-signed certificates generated by Helm
  selfSigned: false

  # -- an array with additional hostname(s) to be covered with the ingress record
  extraHosts: []
  ## extraHosts:
  ##   - name: server.local
  ##     path: /

  # -- an array with additional arbitrary paths that may need to be added to the ingress under the main host
  extraPaths: []
  ## extraPaths:
  ## - path: /*
  ##   backend:
  ##     serviceName: ssl-redirect
  ##     servicePort: use-annotation

  # ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
  # -- an array with additional tls configuration to be added to the ingress record
  extraTls: []
  ## extraTls:
  ## - hosts:
  ##     - server.local
  ##   secretName: server.local-tls

  # ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-rules
  # -- additional rules to be covered with this ingress record
  extraRules: []
  ## extraRules:
  ## - host: example.local
  ##     http:
  ##       path: /
  ##       backend:
  ##         service:
  ##           name: example-svc
  ##           port:
  ##             name: http

# Secret configuration
secret:
  # -- whether to create a Secret containing the PostgreSQL connection string
  create: true
  # -- name for the Secret containing the PostgreSQL connection string
  # To provide an existing Secret, provide a name and set `create=false`
  name: "prefect"
  # -- username for the PostgreSQL connection string
  username: "postgres"
  # -- password for the PostgreSQL connection string
  password: "admin"
  # -- host for the PostgreSQL connection string
  host: "postgresdb-postgresql.default.svc.cluster.local"
  # -- port for the PostgreSQL connection string
  port: "5432"
  # -- database for the PostgreSQL connection string
  database: "prefect"

# SQLite configuration
# Recommended for lightweight, single-server deployments.
sqlite:
  # -- enable use of the embedded SQLite database
  enabled: false

  persistence:
    # -- enable SQLite data persistence using PVC
    enabled: true
    # -- size for the PVC
    size: 1Gi
    # -- storage class name for the PVC
    storageClassName: ""

# PostgreSQL subchart - default overrides
postgresql:
  # -- enable use of bitnami/postgresql subchart
  enabled: false
  auth:
    # -- determines whether an admin user is created within postgres
    enablePostgresUser: false

    ## This is the password for `username` and will be set within the secret fullnameOverride-postgresql at the key password.
    ## This argument is only relevant when using the Postgres database included in the chart.
    ## For an external postgres connection, you must create and use `existingSecret` instead.
    # -- password for the custom user. Ignored if `auth.existingSecret` with key `password` is provided

  postgres:
    # Use the existing PostgreSQL instance
    host: postgresdb-postgresql.default.svc.cluster.local  # The name or service of your PostgreSQL database
    port: 5432                  # The PostgreSQL port, default is 5432
    database: prefect            # The name of the PostgreSQL database
    username: postgres           # The username for the PostgreSQL connection
    password: admin
  ## Initdb configuration
  # ref: https://github.com/bitnami/containers/tree/main/bitnami/postgresql#specifying-initdb-arguments
  primary:
    initdb:
      # -- specify the PostgreSQL username to execute the initdb scripts
      user: postgres

    ## persistence enables a PVC that stores the database between deployments. If making changes to the database deployment, this
    ## PVC will need to be deleted for database changes to take effect. This is especially notable when the authentication password
    ## changes on redeploys. This is disabled by default because we do not recommend using the subchart deployment for production deployments.
    persistence:
      # -- enable PostgreSQL Primary data persistence using PVC
      enabled: true

  image:
    # -- Version tag, corresponds to tags at https://hub.docker.com/r/bitnami/postgresql/
    tag: 14.13.0
EOF

helm dependency update
helm install prefect-server .

wait_for_pod "app.kubernetes.io/name=prefect"
kubectl port-forward svc/prefect-server 4200:4200 -n default &

# Clone and install SonarQube
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
helm show values sonarqube/sonarqube > sonarqube-values.yaml

# Modify sonarqube-values.yaml
cat <<EOF > sonarqube-values.yaml
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

## @section Global parameters
## Global Docker image parameters
## Please, note that this will override the image parameters, including dependencies, configured to use the global value
## Current available global Docker image parameters: imageRegistry, imagePullSecrets and storageClass
##

## @param global.imageRegistry Global Docker image registry
## @param global.imagePullSecrets Global Docker registry secret names as an array
## @param global.defaultStorageClass Global default StorageClass for Persistent Volume(s)
## @param global.storageClass DEPRECATED: use global.defaultStorageClass instead
##
global:
  imageRegistry: ""
  ## E.g.
  ## imagePullSecrets:
  ##   - myRegistryKeySecretName
  ##
  imagePullSecrets: []
  defaultStorageClass: ""
  storageClass: ""
  ## Security parameters
  ##
  security:
    ## @param global.security.allowInsecureImages Allows skipping image verification
    allowInsecureImages: false
  ## Compatibility adaptations for Kubernetes platforms
  ##
  compatibility:
    ## Compatibility adaptations for Openshift
    ##
    openshift:
      ## @param global.compatibility.openshift.adaptSecurityContext Adapt the securityContext sections of the deployment to make them compatible with Openshift restricted-v2 SCC: remove runAsUser, runAsGroup and fsGroup and let the platform use their allowed default IDs. Possible values: auto (apply if the detected running cluster is Openshift), force (perform the adaptation always), disabled (do not perform adaptation)
      ##
      adaptSecurityContext: auto
## @section Common parameters
##

## @param kubeVersion Override Kubernetes version
##
kubeVersion: ""
## @param nameOverride String to partially override common.names.fullname
##
nameOverride: ""
## @param fullnameOverride String to fully override common.names.fullname
##
fullnameOverride: ""
## @param commonLabels Labels to add to all deployed objects
##
commonLabels: {}
## @param commonAnnotations Annotations to add to all deployed objects
##
commonAnnotations: {}
## @param clusterDomain Kubernetes cluster domain name
##
clusterDomain: cluster.local
## @param extraDeploy Array of extra objects to deploy with the release
##
extraDeploy: []
## Enable diagnostic mode in the deployment
##
diagnosticMode:
  ## @param diagnosticMode.enabled Enable diagnostic mode (all probes will be disabled and the command will be overridden)
  ##
  enabled: false
  ## @param diagnosticMode.command Command to override all containers in the deployment
  ##
  command:
    - sleep
  ## @param diagnosticMode.args Args to override all containers in the deployment
  ##
  args:
    - infinity
## @section SonarQube&trade; Image parameters
##

## Bitnami SonarQube&trade; image
## ref: https://hub.docker.com/r/bitnami/sonarqube/tags/
## @param image.registry [default: REGISTRY_NAME] SonarQube&trade; image registry
## @param image.repository [default: REPOSITORY_NAME/sonarqube] SonarQube&trade; image repository
## @skip image.tag SonarQube&trade; image tag (immutable tags are recommended)
## @param image.digest SonarQube&trade; image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag
## @param image.pullPolicy SonarQube&trade; image pull policy
## @param image.pullSecrets SonarQube&trade; image pull secrets
## @param image.debug Enable SonarQube&trade; image debug mode
##
image:
  registry: docker.io
  repository: bitnami/sonarqube
  tag: 25.3.0-debian-12-r0
  digest: ""
  ## Specify a imagePullPolicy
  ## ref: https://kubernetes.io/docs/concepts/containers/images/#pre-pulled-images
  ##
  pullPolicy: IfNotPresent
  ## Optionally specify an array of imagePullSecrets.
  ## Secrets must be manually created in the namespace.
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
  ## e.g:
  ## pullSecrets:
  ##   - myRegistryKeySecretName
  ##
  pullSecrets: []
  ## Enable debug mode
  ##
  debug: false
## @section SonarQube&trade; Configuration parameters
## SonarQube&trade; settings based on environment variables
## ref: https://github.com/bitnami/containers/tree/main/bitnami/sonarqube#environment-variables
## @param sonarqubeUsername SonarQube&trade; username
##
sonarqubeUsername: user
## @param sonarqubePassword SonarQube&trade; user password
## Defaults to a random 10-character alphanumeric string if not set
##
sonarqubePassword: ""
## @param provisioningFolder Directory to use for provisioning content to Sonarqube
##
provisioningFolder: "/bitnami/sonarqube-provisioning"
## @param existingSecret Name of existing secret containing SonarQube&trade; credentials
## NOTE: Must contain key `sonarqube-password`
## NOTE: When it's set, the `sonarqubePassword` parameter is ignored
##
existingSecret: ""
## @param sonarqubeEmail SonarQube&trade; user email
##
sonarqubeEmail: user@example.com
## @param minHeapSize Minimum heap size for SonarQube&trade;
##
minHeapSize: 1024m
## @param maxHeapSize Maximum heap size for SonarQube&trade;
##
maxHeapSize: 2048m
## @param jvmOpts Values to add to SONARQUBE_WEB_JAVA_ADD_OPTS
##
jvmOpts: ""
## @param jvmCeOpts Values to add to SONAR_CE_JAVAADDITIONALOPTS
##
jvmCeOpts: ""
## @param startTimeout Timeout for the application to start in seconds
##
startTimeout: 300
## @param extraProperties List of extra properties to be set in the sonar.properties file (key=value format)
## e.g:
## extraProperties:
##   - my.sonar.property1=property_value1
##   - my.sonar.property2=property_value2
##
extraProperties: []
## @param sonarqubeSkipInstall Skip wizard installation
## NOTE: useful if you use an external database that already contains SonarQube&trade; data
## ref: https://github.com/bitnami/containers/tree/main/bitnami/sonarqube#connect-sonarqube-container-to-an-existing-database
##
sonarqubeSkipInstall: false
## @param sonarSecurityRealm Set this to LDAP authenticate first against the external sytem. If the external system is not
## reachable or if the user is not defined in the external system, authentication will be performed against SonarQube&trade;'s internal database.
##
sonarSecurityRealm: ""
## @param sonarAuthenticatorDowncase Set to true when connecting to a LDAP server using a case-insensitive setup.
##
sonarAuthenticatorDowncase: ""
## Ldap configuration for Sonarqube
##
ldap:
  ## @param ldap.url URL of the LDAP server. If you are using ldaps, you should install the server certificate into the Java truststore
  ##
  url: ""
  ## @param ldap.bindDn The username of an LDAP user to connect (or bind) with. Leave this blank for anonymous access to the LDAP directory.
  ##
  bindDn: ""
  ## @param ldap.bindPassword The password of the user to connect with. Leave this blank for anonymous access to the LDAP directory.
  ##
  bindPassword: ""
  ## @param ldap.authentication Possible values: simple, CRAM-MD5, DIGEST-MD5, GSSAPI. See the tutorial on authentication mechanisms (<http://java.sun.com/products/jndi/tutorial/ldap/security/auth.html>)
  ##
  authentication: simple
  ## @param ldap.realm See Digest-MD5 Authentication, CRAM-MD5 Authentication (<http://java.sun.com/products/jndi/tutorial/ldap/security/digest.html>)
  ##
  realm: ""
  ## @param ldap.contextFactoryClass Context factory class.
  ##
  contextFactoryClass: com.sun.jndi.ldap.LdapCtxFactory
  ## @param ldap.StartTLS Enable use of StartTLS
  ##
  StartTLS: false
  ## @param ldap.followReferrals Follow referrals or not
  ##
  followReferrals: true
  ## User Mapping
  ## @param ldap.user.baseDn Distinguished Name (DN) of the root node in LDAP from which to search for users.
  ## @param ldap.user.request LDAP user request.
  ## @param ldap.user.realNameAttribute in LDAP defining the user's real name.
  ## @param ldap.user.emailAttribute Attribute in LDAP defining the user's email.
  ##
  user:
    baseDn: ""
    request: (&(objectClass=inetOrgPerson)(uid={login}))
    realNameAttribute: cn
    emailAttribute: mail
  ## Group Mapping
  ## @param ldap.group.baseDn Distinguished Name (DN) of the root node in LDAP from which to search for groups.
  ## @param ldap.group.request LDAP group request.
  ## @param ldap.group.idAttribute Attribute in LDAP defining the group's real name.
  ##
  group:
    baseDn: ""
    request: (&(objectClass=groupOfUniqueNames)(uniqueMember={dn}))
    idAttribute: cn
## SMTP mail delivery configuration
## ref: https://github.com/bitnami/containers/tree/main/bitnami/sonarqube/#smtp-configuration
## @param smtpHost SMTP server host
## @param smtpPort SMTP server port
## @param smtpUser SMTP username
## @param smtpPassword SMTP user password
## @param smtpProtocol SMTP protocol
##
smtpHost: ""
smtpPort: ""
smtpUser: ""
smtpPassword: ""
smtpProtocol: ""
## @param smtpExistingSecret The name of an existing secret with SMTP credentials
## NOTE: Must contain key `smtp-password`
## NOTE: When it's set, the `smtpPassword` parameter is ignored
##
smtpExistingSecret: ""
## @param command Override default container command (useful when using custom images)
##
command: []
## @param args Override default container args (useful when using custom images)
##
args: []
## @param extraEnvVars Array with extra environment variables to add to SonarQube&trade; nodes
## e.g:
## extraEnvVars:
##   - name: FOO
##     value: "bar"
##
extraEnvVars: []
## @param extraEnvVarsCM Name of existing ConfigMap containing extra env vars for SonarQube&trade; nodes
##
extraEnvVarsCM: ""
## @param extraEnvVarsSecret Name of existing Secret containing extra env vars for SonarQube&trade; nodes
##
extraEnvVarsSecret: ""
## @section SonarQube&trade; deployment parameters
##

## @param replicaCount Number of SonarQube&trade; replicas to deploy
## NOTE: ReadWriteMany PVC(s) are required if replicaCount > 1
##
replicaCount: 1
## @param containerPorts.http SonarQube&trade; HTTP container port
## @param containerPorts.elastic SonarQube&trade; Elasticsearch container port
##
containerPorts:
  http: 9000
  elastic: 9001
## Configure extra options for SonarQube&trade; containers' liveness and readiness probes
## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/#configure-probes
## @param livenessProbe.enabled Enable livenessProbe on SonarQube&trade; containers
## @param livenessProbe.initialDelaySeconds Initial delay seconds for livenessProbe
## @param livenessProbe.periodSeconds Period seconds for livenessProbe
## @param livenessProbe.timeoutSeconds Timeout seconds for livenessProbe
## @param livenessProbe.failureThreshold Failure threshold for livenessProbe
## @param livenessProbe.successThreshold Success threshold for livenessProbe
##
livenessProbe:
  enabled: true
  initialDelaySeconds: 100
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 6
  successThreshold: 1
## @param readinessProbe.enabled Enable readinessProbe on SonarQube&trade; containers
## @param readinessProbe.initialDelaySeconds Initial delay seconds for readinessProbe
## @param readinessProbe.periodSeconds Period seconds for readinessProbe
## @param readinessProbe.timeoutSeconds Timeout seconds for readinessProbe
## @param readinessProbe.failureThreshold Failure threshold for readinessProbe
## @param readinessProbe.successThreshold Success threshold for readinessProbe
##
readinessProbe:
  enabled: true
  initialDelaySeconds: 100
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 6
  successThreshold: 1
## @param startupProbe.enabled Enable startupProbe on SonarQube&trade; containers
## @param startupProbe.initialDelaySeconds Initial delay seconds for startupProbe
## @param startupProbe.periodSeconds Period seconds for startupProbe
## @param startupProbe.timeoutSeconds Timeout seconds for startupProbe
## @param startupProbe.failureThreshold Failure threshold for startupProbe
## @param startupProbe.successThreshold Success threshold for startupProbe
##
startupProbe:
  enabled: false
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 1
  failureThreshold: 15
  successThreshold: 1
## @param customLivenessProbe Custom livenessProbe that overrides the default one
##
customLivenessProbe: {}
## @param customReadinessProbe Custom readinessProbe that overrides the default one
##
customReadinessProbe: {}
## @param customStartupProbe Custom startupProbe that overrides the default one
##
customStartupProbe: {}
## SonarQube&trade; resource requests and limits
## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
## @param resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if resources is set (resources is recommended for production).
## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
##
resourcesPreset: "xlarge"
## @param resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
## Example:
## resources:
##   requests:
##     cpu: 2
##     memory: 512Mi
##   limits:
##     cpu: 3
##     memory: 1024Mi
##
resources: {}
## Configure Pods Security Context
## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod
## @param podSecurityContext.enabled Enabled SonarQube&trade; pods' Security Context
## @param podSecurityContext.fsGroupChangePolicy Set filesystem group change policy
## @param podSecurityContext.sysctls Set kernel settings using the sysctl interface
## @param podSecurityContext.supplementalGroups Set filesystem extra groups
## @param podSecurityContext.fsGroup Set SonarQube&trade; pod's Security Context fsGroup
##
podSecurityContext:
  enabled: true
  fsGroupChangePolicy: Always
  sysctls: []
  supplementalGroups: []
  fsGroup: 1001
## Configure Container Security Context
## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod
## @param containerSecurityContext.enabled Enabled containers' Security Context
## @param containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
## @param containerSecurityContext.runAsUser Set containers' Security Context runAsUser
## @param containerSecurityContext.runAsGroup Set containers' Security Context runAsGroup
## @param containerSecurityContext.runAsNonRoot Set container's Security Context runAsNonRoot
## @param containerSecurityContext.privileged Set container's Security Context privileged
## @param containerSecurityContext.readOnlyRootFilesystem Set container's Security Context readOnlyRootFilesystem
## @param containerSecurityContext.allowPrivilegeEscalation Set container's Security Context allowPrivilegeEscalation
## @param containerSecurityContext.capabilities.drop List of capabilities to be dropped
## @param containerSecurityContext.seccompProfile.type Set container's Security Context seccomp profile
##
containerSecurityContext:
  enabled: true
  seLinuxOptions: {}
  runAsUser: 1001
  runAsGroup: 1001
  runAsNonRoot: true
  privileged: false
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: "RuntimeDefault"
## @param automountServiceAccountToken Mount Service Account token in pod
##
automountServiceAccountToken: false
## @param hostAliases SonarQube&trade; pods host aliases
## https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/
##
hostAliases: []
## @param podLabels Extra labels for SonarQube&trade; pods
## ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
##
podLabels: {}
## @param podAnnotations Annotations for SonarQube&trade; pods
## ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
##
podAnnotations: {}
## @param podAffinityPreset Pod affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`
## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
##
podAffinityPreset: ""
## @param podAntiAffinityPreset Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`
## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
##
podAntiAffinityPreset: soft
## Node affinity preset
## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity
##
nodeAffinityPreset:
  ## @param nodeAffinityPreset.type Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard`
  ##
  type: ""
  ## @param nodeAffinityPreset.key Node label key to match. Ignored if `affinity` is set
  ##
  key: ""
  ## @param nodeAffinityPreset.values Node label values to match. Ignored if `affinity` is set
  ## E.g.
  ## values:
  ##   - e2e-az1
  ##   - e2e-az2
  ##
  values: []
## @param affinity Affinity for SonarQube&trade; pods assignment
## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
## NOTE: `podAffinityPreset`, `podAntiAffinityPreset`, and `nodeAffinityPreset` will be ignored when it's set
##
affinity: {}
## @param nodeSelector Node labels for SonarQube&trade; pods assignment
## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
##
nodeSelector: {}
## @param tolerations Tolerations for SonarQube&trade; pods assignment
## ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
##
tolerations: []
## @param updateStrategy.type SonarQube&trade; deployment strategy type
## ref: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy
##
updateStrategy:
  ## StrategyType
  ## Can be set to RollingUpdate or Recreate
  ##
  type: RollingUpdate
## @param priorityClassName SonarQube&trade; pods' priorityClassName
##
priorityClassName: ""
## @param schedulerName Name of the k8s scheduler (other than default) for SonarQube&trade; pods
## ref: https://kubernetes.io/docs/tasks/administer-cluster/configure-multiple-schedulers/
##
schedulerName: ""
## @param lifecycleHooks for the SonarQube&trade; container(s) to automate configuration before or after startup
##
lifecycleHooks: {}
## @param extraVolumes Optionally specify extra list of additional volumes for the SonarQube&trade; pod(s)
##
extraVolumes: []
## @param extraVolumeMounts Optionally specify extra list of additional volumeMounts for the SonarQube&trade; container(s)
##
extraVolumeMounts: []
## @param sidecars Add additional sidecar containers to the SonarQube&trade; pod(s)
## e.g:
## sidecars:
##   - name: your-image-name
##     image: your-image
##     imagePullPolicy: Always
##     ports:
##       - name: portname
##         containerPort: 1234
##
sidecars: []
## @param initContainers Add additional init containers to the SonarQube&trade; pod(s)
## ref: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/
## e.g:
## initContainers:
##  - name: your-image-name
##    image: your-image
##    imagePullPolicy: Always
##    command: ['sh', '-c', 'echo "hello world"']
##
initContainers: []
## Pod Disruption Budget configuration
## ref: https://kubernetes.io/docs/tasks/run-application/configure-pdb
## @param pdb.create Enable/disable a Pod Disruption Budget creation
## @param pdb.minAvailable Minimum number/percentage of pods that should remain scheduled
## @param pdb.maxUnavailable Maximum number/percentage of pods that may be made unavailable. Defaults to `1` if both `pdb.minAvailable` and `pdb.maxUnavailable` are empty.
##
pdb:
  create: true
  minAvailable: ""
  maxUnavailable: ""
## @section Traffic Exposure Parameters
##

## SonarQube&trade; service parameters
##
service:
  ## @param service.type SonarQube&trade; service type
  ##
  type: LoadBalancer
  ## @param service.ports.http SonarQube&trade; service HTTP port
  ## @param service.ports.elastic SonarQube&trade; service ElasticSearch port
  ##
  ports:
    http: 80
    elastic: 9001
  ## Node ports to expose
  ## @param service.nodePorts.http Node port for HTTP
  ## @param service.nodePorts.elastic Node port for ElasticSearch
  ## NOTE: choose port between <30000-32767>
  ##
  nodePorts:
    http: ""
    elastic: ""
  ## @param service.clusterIP SonarQube&trade; service Cluster IP
  ## e.g.:
  ## clusterIP: None
  ##
  clusterIP: ""
  ## @param service.loadBalancerIP SonarQube&trade; service Load Balancer IP
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#type-loadbalancer
  ##
  loadBalancerIP: ""
  ## @param service.loadBalancerSourceRanges SonarQube&trade; service Load Balancer sources
  ## ref: https://kubernetes.io/docs/tasks/access-application-cluster/configure-cloud-provider-firewall/#restrict-access-for-loadbalancer-service
  ## e.g:
  ## loadBalancerSourceRanges:
  ##   - 10.10.10.0/24
  ##
  loadBalancerSourceRanges: []
  ## @param service.externalTrafficPolicy SonarQube&trade; service external traffic policy
  ## ref https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip
  ##
  externalTrafficPolicy: Cluster
  ## @param service.annotations Additional custom annotations for SonarQube&trade; service
  ##
  annotations: {}
  ## @param service.extraPorts Extra ports to expose in SonarQube&trade; service (normally used with the `sidecars` value)
  ##
  extraPorts: []
  ## @param service.sessionAffinity Session Affinity for Kubernetes service, can be "None" or "ClientIP"
  ## If "ClientIP", consecutive client requests will be directed to the same Pod
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#virtual-ips-and-service-proxies
  ##
  sessionAffinity: None
  ## @param service.sessionAffinityConfig Additional settings for the sessionAffinity
  ## sessionAffinityConfig:
  ##   clientIP:
  ##     timeoutSeconds: 300
  ##
  sessionAffinityConfig: {}
## Network Policies
## Ref: https://kubernetes.io/docs/concepts/services-networking/network-policies/
##
networkPolicy:
  ## @param networkPolicy.enabled Specifies whether a NetworkPolicy should be created
  ##
  enabled: true
  ## @param networkPolicy.allowExternal Don't require client label for connections
  ## The Policy model to apply. When set to false, only pods with the correct
  ## client label will have network access to the ports the application is listening
  ## on. When true, the app will accept connections from any source
  ## (with the correct destination port).
  ##
  allowExternal: true
  ## @param networkPolicy.allowExternalEgress Allow the pod to access any range of port and all destinations.
  ##
  allowExternalEgress: true
  ## @param networkPolicy.extraIngress [array] Add extra ingress rules to the NetworkPolicy
  ## e.g:
  ## extraIngress:
  ##   - ports:
  ##       - port: 1234
  ##     from:
  ##       - podSelector:
  ##           - matchLabels:
  ##               - role: frontend
  ##       - podSelector:
  ##           - matchExpressions:
  ##               - key: role
  ##                 operator: In
  ##                 values:
  ##                   - frontend
  extraIngress: []
  ## @param networkPolicy.extraEgress [array] Add extra ingress rules to the NetworkPolicy
  ## e.g:
  ## extraEgress:
  ##   - ports:
  ##       - port: 1234
  ##     to:
  ##       - podSelector:
  ##           - matchLabels:
  ##               - role: frontend
  ##       - podSelector:
  ##           - matchExpressions:
  ##               - key: role
  ##                 operator: In
  ##                 values:
  ##                   - frontend
  ##
  extraEgress: []
  ## @param networkPolicy.ingressNSMatchLabels [object] Labels to match to allow traffic from other namespaces
  ## @param networkPolicy.ingressNSPodMatchLabels [object] Pod labels to match to allow traffic from other namespaces
  ##
  ingressNSMatchLabels: {}
  ingressNSPodMatchLabels: {}
## SonarQube&trade; ingress parameters
## ref: https://kubernetes.io/docs/concepts/services-networking/ingress/
##
ingress:
  ## @param ingress.enabled Enable ingress record generation for SonarQube&trade;
  ##
  enabled: false
  ## @param ingress.pathType Ingress path type
  ##
  pathType: ImplementationSpecific
  ## @param ingress.apiVersion Force Ingress API version (automatically detected if not set)
  ##
  apiVersion: ""
  ## @param ingress.ingressClassName IngressClass that will be be used to implement the Ingress (Kubernetes 1.18+)
  ## This is supported in Kubernetes 1.18+ and required if you have more than one IngressClass marked as the default for your cluster.
  ## ref: https://kubernetes.io/blog/2020/04/02/improvements-to-the-ingress-api-in-kubernetes-1.18/
  ##
  ingressClassName: ""
  ## @param ingress.hostname Default host for the ingress record
  ##
  hostname: sonarqube.local
  ## @param ingress.path Default path for the ingress record
  ## NOTE: You may need to set this to '/*' in order to use this with ALB ingress controllers
  ##
  path: /
  ## @param ingress.annotations Additional annotations for the Ingress resource. To enable certificate autogeneration, place here your cert-manager annotations.
  ## Use this parameter to set the required annotations for cert-manager, see
  ## ref: https://cert-manager.io/docs/usage/ingress/#supported-annotations
  ## e.g:
  ## annotations:
  ##   kubernetes.io/ingress.class: nginx
  ##   cert-manager.io/cluster-issuer: cluster-issuer-name
  ##
  annotations: {}
  ## @param ingress.labels Additional labels for the Ingress resource.
  ## e.g:
  ## labels:
  ##   app: sonarqube
  ##
  labels: {}
  ## @param ingress.tls Enable TLS configuration for the host defined at `ingress.hostname` parameter
  ## TLS certificates will be retrieved from a TLS secret with name: - printf "%s-tls" .Values.ingress.hostname 
  ## You can:
  ##   - Use the `ingress.secrets` parameter to create this TLS secret
  ##   - Rely on cert-manager to create it by setting the corresponding annotations
  ##   - Rely on Helm to create self-signed certificates by setting `ingress.selfSigned=true`
  ##
  tls: false
  ## @param ingress.selfSigned Create a TLS secret for this ingress record using self-signed certificates generated by Helm
  ##
  selfSigned: false
  ## @param ingress.extraHosts An array with additional hostname(s) to be covered with the ingress record
  ## e.g:
  ## extraHosts:
  ##   - name: sonarqube.local
  ##     path: /
  ##
  extraHosts: []
  ## @param ingress.extraPaths An array with additional arbitrary paths that may need to be added to the ingress under the main host
  ## e.g:
  ## extraPaths:
  ## - path: /*
  ##   backend:
  ##     serviceName: ssl-redirect
  ##     servicePort: use-annotation
  ##
  extraPaths: []
  ## @param ingress.extraTls TLS configuration for additional hostname(s) to be covered with this ingress record
  ## ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
  ## e.g:
  ## extraTls:
  ## - hosts:
  ##     - sonarqube.local
  ##   secretName: sonarqube.local-tls
  ##
  extraTls: []
  ## @param ingress.secrets Custom TLS certificates as secrets
  ## NOTE: 'key' and 'certificate' are expected in PEM format
  ## NOTE: 'name' should line up with a 'secretName' set further up
  ## If it is not set and you're using cert-manager, this is unneeded, as it will create a secret for you with valid certificates
  ## If it is not set and you're NOT using cert-manager either, self-signed certificates will be created valid for 365 days
  ## It is also possible to create and manage the certificates outside of this helm chart
  ## Please see README.md for more information
  ## e.g:
  ## secrets:
  ##   - name: sonarqube.local-tls
  ##     key: |-
  ##       -----BEGIN RSA PRIVATE KEY-----
  ##       ...
  ##       -----END RSA PRIVATE KEY-----
  ##     certificate: |-
  ##       -----BEGIN CERTIFICATE-----
  ##       ...
  ##       -----END CERTIFICATE-----
  ##
  secrets: []
  ## @param ingress.extraRules Additional rules to be covered with this ingress record
  ## ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-rules
  ## e.g:
  ## extraRules:
  ## - host: sonarqube.local
  ##     http:
  ##       path: /
  ##       backend:
  ##         service:
  ##           name: sonarqube-svc
  ##           port:
  ##             name: http
  ##
  extraRules: []
## @section SonarQube caCerts provisioning parameters
##
## Provide a secret containing one or more certificate files in the keys that will be added to cacerts
## The cacerts file will be set via SONARQUBE_WEB_JAVA_ADD_OPTS and SONAR_CE_JAVAADDITIONALOPTS
caCerts:
  ## @param caCerts.enabled Enable the use of caCerts
  ##
  enabled: false
  ## OS Shell + Utility image
  ## ref: https://hub.docker.com/r/bitnami/os-shell/tags/
  ## @param caCerts.image.registry [default: REGISTRY_NAME] OS Shell + Utility image registry
  ## @param caCerts.image.repository [default: REPOSITORY_NAME/os-shell] OS Shell + Utility image repository
  ## @skip caCerts.image.tag OS Shell + Utility image tag (immutable tags are recommended)
  ## @param caCerts.image.digest OS Shell + Utility image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag
  ## @param caCerts.image.pullPolicy OS Shell + Utility image pull policy
  ## @param caCerts.image.pullSecrets OS Shell + Utility image pull secrets
  ##
  image:
    registry: docker.io
    repository: bitnami/os-shell
    tag: 12-debian-12-r39
    digest: ""
    pullPolicy: IfNotPresent
    ## Optionally specify an array of imagePullSecrets.
    ## Secrets must be manually created in the namespace.
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
    ## e.g:
    ## pullSecrets:
    ##   - myRegistryKeySecretName
    ##
    pullSecrets: []
  ## @param caCerts.secret Name of the secret containing the certificates
  ##
  secret: ca-certs-secret
  ## Init container's resource requests and limits
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param caCerts.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if caCerts.resources is set (caCerts.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  ##
  resourcesPreset: "none"
  ## @param caCerts.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
  ## Example:
  ## resources:
  ##   requests:
  ##     cpu: 2
  ##     memory: 512Mi
  ##   limits:
  ##     cpu: 3
  ##     memory: 1024Mi
  ##
  resources: {}
  ## Init container Container Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container
  ## @param caCerts.containerSecurityContext.enabled Enabled containers' Security Context
  ## @param caCerts.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
  ## @param caCerts.containerSecurityContext.runAsUser Set containers' Security Context runAsUser
  ## @param caCerts.containerSecurityContext.runAsGroup Set containers' Security Context runAsGroup
  ## @param caCerts.containerSecurityContext.runAsNonRoot Set container's Security Context runAsNonRoot
  ## @param caCerts.containerSecurityContext.privileged Set container's Security Context privileged
  ## @param caCerts.containerSecurityContext.readOnlyRootFilesystem Set container's Security Context readOnlyRootFilesystem
  ## @param caCerts.containerSecurityContext.allowPrivilegeEscalation Set container's Security Context allowPrivilegeEscalation
  ## @param caCerts.containerSecurityContext.capabilities.drop List of capabilities to be dropped
  ## @param caCerts.containerSecurityContext.seccompProfile.type Set container's Security Context seccomp profile
  ## NOTE: when runAsUser is set to special value "auto", init container will try to chown the
  ##   data folder to auto-determined user&group, using commands: `id -u`:`id -G | cut -d" " -f2`
  ##   "auto" is especially useful for OpenShift which has scc with dynamic user ids (and 0 is not allowed)
  ##
  containerSecurityContext:
    enabled: true
    seLinuxOptions: {}
    runAsUser: 1001
    runAsGroup: 1001
    runAsNonRoot: true
    privileged: false
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: "RuntimeDefault"
## @section SonarQube plugin provisioning parameters
##
plugins:
  ## @param plugins.install List of plugin URLS to download and install
  ## For example:
  ## plugins:
  ##  install:
  ##    - "https://github.com/AmadeusITGroup/sonar-stash/releases/download/1.3.0/sonar-stash-plugin-1.3.0.jar"
  ##    - "https://github.com/SonarSource/sonar-ldap/releases/download/2.2-RC3/sonar-ldap-plugin-2.2.0.601.jar"
  ##
  install: []
  ## @param plugins.netrcCreds .netrc secret file with a key "netrc" to use basic auth while downloading plugins
  ##
  netrcCreds: ""
  ## @param plugins.noCheckCertificate Set to true to not validate the server's certificate to download plugin
  ##
  noCheckCertificate: true
  ## OS Shell + Utility image
  ## ref: https://hub.docker.com/r/bitnami/os-shell/tags/
  ## @param plugins.image.registry [default: REGISTRY_NAME] OS Shell + Utility image registry
  ## @param plugins.image.repository [default: REPOSITORY_NAME/os-shell] OS Shell + Utility image repository
  ## @skip plugins.image.tag OS Shell + Utility image tag (immutable tags are recommended)
  ## @param plugins.image.digest OS Shell + Utility image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag
  ## @param plugins.image.pullPolicy OS Shell + Utility image pull policy
  ## @param plugins.image.pullSecrets OS Shell + Utility image pull secrets
  ##
  image:
    registry: docker.io
    repository: bitnami/os-shell
    tag: 12-debian-12-r39
    digest: ""
    pullPolicy: IfNotPresent
    ## Optionally specify an array of imagePullSecrets.
    ## Secrets must be manually created in the namespace.
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
    ## e.g:
    ## pullSecrets:
    ##   - myRegistryKeySecretName
    ##
    pullSecrets: []
  ## Init container's resource requests and limits
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param plugins.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if plugins.resources is set (plugins.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  ##
  resourcesPreset: "none"
  ## @param plugins.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
  ## Example:
  ## resources:
  ##   requests:
  ##     cpu: 2
  ##     memory: 512Mi
  ##   limits:
  ##     cpu: 3
  ##     memory: 1024Mi
  ##
  resources: {}
  ## Init container Container Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container
  ## @param plugins.containerSecurityContext.enabled Enabled containers' Security Context
  ## @param plugins.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
  ## @param plugins.containerSecurityContext.runAsUser Set containers' Security Context runAsUser
  ## @param plugins.containerSecurityContext.runAsGroup Set containers' Security Context runAsGroup
  ## @param plugins.containerSecurityContext.runAsNonRoot Set container's Security Context runAsNonRoot
  ## @param plugins.containerSecurityContext.privileged Set container's Security Context privileged
  ## @param plugins.containerSecurityContext.readOnlyRootFilesystem Set container's Security Context readOnlyRootFilesystem
  ## @param plugins.containerSecurityContext.allowPrivilegeEscalation Set container's Security Context allowPrivilegeEscalation
  ## @param plugins.containerSecurityContext.capabilities.drop List of capabilities to be dropped
  ## @param plugins.containerSecurityContext.seccompProfile.type Set container's Security Context seccomp profile
  ## NOTE: when runAsUser is set to special value "auto", init container will try to chown the
  ##   data folder to auto-determined user&group, using commands: `id -u`:`id -G | cut -d" " -f2`
  ##   "auto" is especially useful for OpenShift which has scc with dynamic user ids (and 0 is not allowed)
  ##
  containerSecurityContext:
    enabled: true
    seLinuxOptions: {}
    runAsUser: 1001
    runAsGroup: 1001
    runAsNonRoot: true
    privileged: false
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: "RuntimeDefault"
## @section Persistence Parameters
##

## Persistence Parameters
## ref: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
##
persistence:
  ## @param persistence.enabled Enable persistence using Persistent Volume Claims
  ##
  enabled: false
  ## @param persistence.storageClass Persistent Volume storage class
  ## If defined, storageClassName: <storageClass>
  ## If set to "-", storageClassName: "", which disables dynamic provisioning
  ## If undefined (the default) or set to null, no storageClassName spec is set, choosing the default provisioner
  ##
  storageClass: ""
  ## @param persistence.accessModes [array] Persistent Volume access modes
  ##
  accessModes:
    - ReadWriteOnce
  ## @param persistence.size Persistent Volume size
  ##
  size: 10Gi
  ## @param persistence.dataSource Custom PVC data source
  ##
  dataSource: {}
  ## @param persistence.existingClaim The name of an existing PVC to use for persistence
  ##
  existingClaim: ""
  ## @param persistence.annotations Persistent Volume Claim annotations
  ##
  annotations: {}
## 'volumePermissions' init container parameters
## Changes the owner and group of the persistent volume mount point to runAsUser:fsGroup values
##   based on the *podSecurityContext/*containerSecurityContext parameters
##
volumePermissions:
  ## @param volumePermissions.enabled Enable init container that changes the owner/group of the PV mount point to `runAsUser:fsGroup`
  ##
  enabled: false
  ## OS Shell + Utility image
  ## ref: https://hub.docker.com/r/bitnami/os-shell/tags/
  ## @param volumePermissions.image.registry [default: REGISTRY_NAME] OS Shell + Utility image registry
  ## @param volumePermissions.image.repository [default: REPOSITORY_NAME/os-shell] OS Shell + Utility image repository
  ## @skip volumePermissions.image.tag OS Shell + Utility image tag (immutable tags are recommended)
  ## @param volumePermissions.image.digest OS Shell + Utility image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag
  ## @param volumePermissions.image.pullPolicy OS Shell + Utility image pull policy
  ## @param volumePermissions.image.pullSecrets OS Shell + Utility image pull secrets
  ##
  image:
    registry: docker.io
    repository: bitnami/os-shell
    tag: 12-debian-12-r39
    digest: ""
    pullPolicy: IfNotPresent
    ## Optionally specify an array of imagePullSecrets.
    ## Secrets must be manually created in the namespace.
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
    ## e.g:
    ## pullSecrets:
    ##   - myRegistryKeySecretName
    ##
    pullSecrets: []
  ## Init container's resource requests and limits
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param volumePermissions.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if volumePermissions.resources is set (volumePermissions.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  ##
  resourcesPreset: "none"
  ## @param volumePermissions.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
  ## Example:
  ## resources:
  ##   requests:
  ##     cpu: 2
  ##     memory: 512Mi
  ##   limits:
  ##     cpu: 3
  ##     memory: 1024Mi
  ##
  resources: {}
  ## Init container Container Security Context
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-container
  ## @param volumePermissions.containerSecurityContext.enabled Enable init container's Security Context
  ## @param volumePermissions.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
  ## @param volumePermissions.containerSecurityContext.runAsUser Set init container's Security Context runAsUser
  ## NOTE: when runAsUser is set to special value "auto", init container will try to chown the
  ##   data folder to auto-determined user&group, using commands: `id -u`:`id -G | cut -d" " -f2`
  ##   "auto" is especially useful for OpenShift which has scc with dynamic user ids (and 0 is not allowed)
  ##
  containerSecurityContext:
    enabled: true
    seLinuxOptions: {}
    runAsUser: 0
## @section Sysctl Image parameters
##

## Kernel settings modifier image
##
sysctl:
  ## @param sysctl.enabled Enable kernel settings modifier image
  ##
  enabled: true
  ## OS Shell + Utility image
  ## ref: https://hub.docker.com/r/bitnami/os-shell/tags/
  ## @param sysctl.image.registry [default: REGISTRY_NAME] OS Shell + Utility image registry
  ## @param sysctl.image.repository [default: REPOSITORY_NAME/os-shell] OS Shell + Utility image repository
  ## @skip sysctl.image.tag OS Shell + Utility image tag (immutable tags are recommended)
  ## @param sysctl.image.digest OS Shell + Utility image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag
  ## @param sysctl.image.pullPolicy OS Shell + Utility image pull policy
  ## @param sysctl.image.pullSecrets OS Shell + Utility image pull secrets
  ##
  image:
    registry: docker.io
    repository: bitnami/os-shell
    tag: 12-debian-12-r39
    digest: ""
    pullPolicy: IfNotPresent
    ## Optionally specify an array of imagePullSecrets.
    ## Secrets must be manually created in the namespace.
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
    ## e.g:
    ## pullSecrets:
    ##   - myRegistryKeySecretName
    ##
    pullSecrets: []
  ## Init container's resource requests and limits
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param sysctl.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if sysctl.resources is set (sysctl.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  ##
  resourcesPreset: "none"
  ## @param sysctl.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
  ## Example:
  ## resources:
  ##   requests:
  ##     cpu: 2
  ##     memory: 512Mi
  ##   limits:
  ##     cpu: 3
  ##     memory: 1024Mi
  ##
  resources: {}
  ## @param sysctl.containerSecurityContext.enabled Enable container security context
  ## @param sysctl.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
  ## @param sysctl.containerSecurityContext.runAsUser Set init container's Security Context runAsUser
  ## @param sysctl.containerSecurityContext.privileged Set init container's Security Context privileged
  ## NOTE: when runAsUser is set to special value "auto", init container will try to chown the
  ##   data folder to auto-determined user&group, using commands: `id -u`:`id -G | cut -d" " -f2`
  ##   "auto" is especially useful for OpenShift which has scc with dynamic user ids (and 0 is not allowed)
  ##
  containerSecurityContext:
    enabled: true
    privileged: true
    runAsUser: 0
    seLinuxOptions: {}
## @section Other Parameters
##

## RBAC configuration
##
rbac:
  ## @param rbac.create Specifies whether RBAC resources should be created
  ##
  create: false
## ServiceAccount configuration
## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
## @param serviceAccount.create Specifies whether a ServiceAccount should be created
## @param serviceAccount.name Name of the service account to use. If not set and create is true, a name is generated using the fullname template.
## @param serviceAccount.automountServiceAccountToken Automount service account token for the server service account
## @param serviceAccount.annotations Annotations for service account. Evaluated as a template. Only used if `create` is `true`.
##
serviceAccount:
  create: true
  name: ""
  automountServiceAccountToken: false
  annotations: {}
## SonarQube&trade; Autoscaling configuration
## ref: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
## @param autoscaling.enabled Enable Horizontal POD autoscaling for SonarQube&trade;
## @param autoscaling.minReplicas Minimum number of SonarQube&trade; replicas
## @param autoscaling.maxReplicas Maximum number of SonarQube&trade; replicas
## @param autoscaling.targetCPU Target CPU utilization percentage
## @param autoscaling.targetMemory Target Memory utilization percentage
##
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 11
  targetCPU: 50
  targetMemory: 50
## @section Metrics parameters
##

## Prometheus Exporters / Metrics
##
metrics:
  ## Prometheus JMX Exporter: exposes the majority of SonarQube&trade; metrics
  ##
  jmx:
    ## @param metrics.jmx.enabled Whether or not to expose JMX metrics to Prometheus
    ##
    enabled: false
    ## Bitnami JMX exporter image
    ## ref: https://hub.docker.com/r/bitnami/jmx-exporter/tags/
    ## @param metrics.jmx.image.registry [default: REGISTRY_NAME] JMX exporter image registry
    ## @param metrics.jmx.image.repository [default: REPOSITORY_NAME/jmx-exporter] JMX exporter image repository
    ## @skip metrics.jmx.image.tag JMX exporter image tag (immutable tags are recommended)
    ## @param metrics.jmx.image.digest JMX exporter image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag
    ## @param metrics.jmx.image.pullPolicy JMX exporter image pull policy
    ## @param metrics.jmx.image.pullSecrets Specify docker-registry secret names as an array
    ##
    image:
      registry: docker.io
      repository: bitnami/jmx-exporter
      tag: 1.1.0-debian-12-r7
      digest: ""
      pullPolicy: IfNotPresent
      ## Optionally specify an array of imagePullSecrets.
      ## Secrets must be manually created in the namespace.
      ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
      ## e.g:
      ## pullSecrets:
      ##   - myRegistryKeySecretName
      ##
      pullSecrets: []
    ## @param metrics.jmx.containerPorts.metrics JMX Exporter metrics container port
    ##
    containerPorts:
      metrics: 10445
    ## Prometheus JMX Exporter' resource requests and limits
    ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
    ## @param metrics.jmx.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if metrics.jmx.resources is set (metrics.jmx.resources is recommended for production).
    ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
    ##
    resourcesPreset: "none"
    ## @param metrics.jmx.resources Set container requests and limits for different resources like CPU or memory (essential for production workloads)
    ## Example:
    ## resources:
    ##   requests:
    ##     cpu: 2
    ##     memory: 512Mi
    ##   limits:
    ##     cpu: 3
    ##     memory: 1024Mi
    ##
    resources: {}
    ## Configure extra options for liveness probe
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/#configure-probes
    ## @param metrics.jmx.livenessProbe.enabled Enable livenessProbe
    ## @param metrics.jmx.livenessProbe.initialDelaySeconds Initial delay seconds for livenessProbe
    ## @param metrics.jmx.livenessProbe.periodSeconds Period seconds for livenessProbe
    ## @param metrics.jmx.livenessProbe.timeoutSeconds Timeout seconds for livenessProbe
    ## @param metrics.jmx.livenessProbe.failureThreshold Failure threshold for livenessProbe
    ## @param metrics.jmx.livenessProbe.successThreshold Success threshold for livenessProbe
    ##
    livenessProbe:
      enabled: true
      initialDelaySeconds: 200
      periodSeconds: 20
      timeoutSeconds: 10
      successThreshold: 1
      failureThreshold: 10
    ## Configure extra options for readiness probe
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/#configure-probes
    ## @param metrics.jmx.readinessProbe.enabled Enable readinessProbe
    ## @param metrics.jmx.readinessProbe.initialDelaySeconds Initial delay seconds for readinessProbe
    ## @param metrics.jmx.readinessProbe.periodSeconds Period seconds for readinessProbe
    ## @param metrics.jmx.readinessProbe.timeoutSeconds Timeout seconds for readinessProbe
    ## @param metrics.jmx.readinessProbe.failureThreshold Failure threshold for readinessProbe
    ## @param metrics.jmx.readinessProbe.successThreshold Success threshold for readinessProbe
    ##
    readinessProbe:
      enabled: true
      initialDelaySeconds: 200
      periodSeconds: 20
      timeoutSeconds: 10
      successThreshold: 1
      failureThreshold: 10
    ## Configure Container Security Context
    ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod
    ## @param metrics.jmx.containerSecurityContext.enabled Enabled containers' Security Context
    ## @param metrics.jmx.containerSecurityContext.seLinuxOptions [object,nullable] Set SELinux options in container
    ## @param metrics.jmx.containerSecurityContext.runAsUser Set containers' Security Context runAsUser
    ## @param metrics.jmx.containerSecurityContext.runAsGroup Set containers' Security Context runAsGroup
    ## @param metrics.jmx.containerSecurityContext.runAsNonRoot Set container's Security Context runAsNonRoot
    ## @param metrics.jmx.containerSecurityContext.privileged Set container's Security Context privileged
    ## @param metrics.jmx.containerSecurityContext.readOnlyRootFilesystem Set container's Security Context readOnlyRootFilesystem
    ## @param metrics.jmx.containerSecurityContext.allowPrivilegeEscalation Set container's Security Context allowPrivilegeEscalation
    ## @param metrics.jmx.containerSecurityContext.capabilities.drop List of capabilities to be dropped
    ## @param metrics.jmx.containerSecurityContext.seccompProfile.type Set container's Security Context seccomp profile
    ##
    containerSecurityContext:
      enabled: true
      seLinuxOptions: {}
      runAsUser: 1001
      runAsGroup: 1001
      runAsNonRoot: true
      privileged: false
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: "RuntimeDefault"
    ## @param metrics.jmx.whitelistObjectNames [array] Allows setting which JMX objects you want to expose to via JMX stats to JMX Exporter
    ## Only whitelisted values will be exposed via JMX Exporter. They must also be exposed via Rules. To expose all metrics
    ## (warning its crazy excessive and they aren't formatted in a prometheus style) (1) `whitelistObjectNames: []`
    ## (2) commented out above `overrideConfig`.
    ##
    whitelistObjectNames:
      - java.lang:*
      - SonarQube:*
      - Tomcat:*
    ## @param metrics.jmx.configuration [string] Configuration file for JMX exporter
    ## Specify content for jmx-sonarqube-prometheus.yml. Evaluated as a template
    ##
    configuration: |-
      jmxUrl: service:jmx:rmi:///jndi/rmi://127.0.0.1:10443/jmxrmi
      lowercaseOutputName: true
      lowercaseOutputLabelNames: true
      ssl: false
      {{- if .Values.metrics.jmx.whitelistObjectNames }}
      whitelistObjectNames: ["{{ join "\",\"" .Values.metrics.jmx.whitelistObjectNames }}"]
      {{- end }}
      rules:
      - pattern: java.lang<type=(.+), name=(.+)><(.+)>(\w+)
        name: java_lang_$1_$4_$3_$2
      - pattern: java.lang<type=(.+), name=(.+)><>(\w+)
        name: java_lang_$1_$3_$2
      - pattern: java.lang<type=(.*)>
      - pattern: SonarQube<name=(.+)><>(\w+)
        name: sonarqube_$1_$2
      - pattern: Tomcat<type=(.+), name=(.+)><>(\w+)
        name: tomcat_$1_$3_$2
    ## Service configuration
    ##
    service:
      ## @param metrics.jmx.service.ports.metrics JMX Exporter Prometheus port
      ##
      ports:
        metrics: 10443
      ## @param metrics.jmx.service.annotations [object] Annotations for the JMX Exporter Prometheus metrics service
      ##
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "{{ .Values.metrics.jmx.service.ports.metrics }}"
        prometheus.io/path: "/"
  ## Prometheus Operator ServiceMonitor configuration
  ## ref: https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#endpoint
  ##
  serviceMonitor:
    ## @param metrics.serviceMonitor.enabled if `true`, creates a Prometheus Operator ServiceMonitor (requires `metrics.jmx.enabled` to be `true`)
    ##
    enabled: false
    ## @param metrics.serviceMonitor.namespace Namespace in which Prometheus is running
    ##
    namespace: ""
    ## @param metrics.serviceMonitor.labels Extra labels for the ServiceMonitor
    ##
    labels: {}
    ## @param metrics.serviceMonitor.jobLabel The name of the label on the target service to use as the job name in Prometheus
    ##
    jobLabel: ""
    ## @param metrics.serviceMonitor.interval How frequently to scrape metrics
    ## e.g:
    ## interval: 10s
    ##
    interval: ""
    ## @param metrics.serviceMonitor.scrapeTimeout Timeout after which the scrape is ended
    ## e.g:
    ## scrapeTimeout: 10s
    ##
    scrapeTimeout: ""
    ## @param metrics.serviceMonitor.metricRelabelings [array] Specify additional relabeling of metrics
    ##
    metricRelabelings: []
    ## @param metrics.serviceMonitor.relabelings [array] Specify general relabeling
    ##
    relabelings: []
    ## @param metrics.serviceMonitor.selector Prometheus instance selector labels
    ## ref: https://github.com/bitnami/charts/tree/main/bitnami/prometheus-operator#prometheus-configuration
    ##
    selector: {}
## @section PostgreSQL subchart settings
##

## PostgreSQL chart configuration
## https://github.com/bitnami/charts/blob/main/bitnami/postgresql/values.yaml
##

postgresql:
  enabled: false  # Désactiver le déploiement du chart PostgreSQL, car vous utilisez un PostgreSQL existant

  ## @param postgresql.nameOverride Override name of the PostgreSQL chart
  ##
  nameOverride: ""
  auth:
    ## @param postgresql.auth.existingSecret Existing secret containing the password of the PostgreSQL chart
    ##
    existingSecret: ""
    ## @param postgresql.auth.password Password for the postgres user of the PostgreSQL chart (auto-generated if not set)
    ## ref: https://hub.docker.com/_/postgres/
    ##
    password: ""
    ## @param postgresql.auth.username Username to create when deploying the PostgreSQL chart
    ##
    username: bn_sonarqube
    ## @param postgresql.auth.database Database to create when deploying the PostgreSQL chart
    ##
    database: bitnami_sonarqube
  ## PostgreSQL Primary parameters
  ##
  primary:
    ## PostgreSQL Primary service configuration
    ##
    service:
      ## @param postgresql.primary.service.ports.postgresql PostgreSQL service port
      ##
      ports:
        postgresql: 5432
    ## PostgreSQL Primary persistence configuration
    ##
    persistence:
      ## @param postgresql.primary.persistence.enabled Enable PostgreSQL Primary data persistence using PVC
      ##
      enabled: true
      ## @param postgresql.primary.persistence.existingClaim Name of an existing PVC to use
      ##
      existingClaim: ""
      ## @param postgresql.primary.persistence.storageClass PVC Storage Class for PostgreSQL Primary data volume
      ## If defined, storageClassName: <storageClass>
      ## If set to "-", storageClassName: "", which disables dynamic provisioning
      ## If undefined (the default) or set to null, no storageClassName spec is
      ##   set, choosing the default provisioner.  (gp2 on AWS, standard on
      ##   GKE, AWS & OpenStack)
      ##
      storageClass: ""
      ## @param postgresql.primary.persistence.accessMode PVC Access Mode for PostgreSQL volume
      ##
      accessMode: ReadWriteOnce
      ## @param postgresql.primary.persistence.size PVC Storage Request for PostgreSQL volume
      ##
      size: 8Gi
## @section External Database settings
##

## External Database Configuration
## All of these values are only used when postgresql.enabled is set to false
##
externalDatabase:
  ## @param externalDatabase.host Host of an external PostgreSQL instance to connect (only if postgresql.enabled=false)
  ##
  host: "postgresdb-postgresql"
  ## @param externalDatabase.user User of an external PostgreSQL instance to connect (only if postgresql.enabled=false)
  ##
  user: postgres
  ## @param externalDatabase.password Password of an external PostgreSQL instance to connect (only if postgresql.enabled=false)
  ##
  password: "admin"
  ## @param externalDatabase.existingSecret Secret containing the password of an external PostgreSQL instance to connect (only if postgresql.enabled=false)
  ## Name of an existing secret resource containing the DB password in a 'password' key
  ##
  existingSecret: ""
  ## @param externalDatabase.database Database inside an external PostgreSQL to connect (only if postgresql.enabled=false)
  ##
  database: sonar
  ## @param externalDatabase.port Port of an external PostgreSQL to connect (only if postgresql.enabled=false)
  ##
  port: 5432
EOF

helm install sonarqube sonarqube/sonarqube -f sonarqube-values.yaml

wait_for_pod "app.kubernetes.io/name=sonarqube"

# Install GitLab Runner
helm repo add gitlab https://charts.gitlab.io
helm repo update
helm show values gitlab/gitlab-runner > gitlab-runner-values.yaml

# Modify gitlab-runner-values.yaml
cat <<EOF > gitlab-runner-values.yaml
## GitLab Runner Image
##
## By default it's using registry.gitlab.com/gitlab-org/gitlab-runner:alpine-v{VERSION}
## where {VERSION} is taken from Chart.yaml from appVersion field
##
## ref: https://gitlab.com/gitlab-org/gitlab-runner/container_registry/29383?orderBy=NAME&sort=asc&search[]=alpine-v&search[]=
##
## Note: If you change the image to the ubuntu release
##       don't forget to change the securityContext;
##       these images run on different user IDs.
##
image:
  registry: registry.gitlab.com
  image: gitlab-org/gitlab-runner
  # tag: alpine-v{{.Chart.AppVersion}}

## When using GitLab Runner Helm Chart with gitlab-runner-ubi-images (https://gitlab.com/gitlab-org/ci-cd/gitlab-runner-ubi-images/container_registry)
## the installation fails because `dumb-init` is not packaged in the image. However, `tini` is present.
## This configuration will allow gitlab-runner-ubi-images users to explicitly enable the use of `tini` instead of `dumb-init`
useTini: false

## Specify a imagePullPolicy for the main runner deployment
## 'Always' if imageTag is 'latest', else set to 'IfNotPresent'
##
## Note: it does not apply to job containers launched by this executor.
## Use `pull_policy` in [runners.kubernetes] to change it.
##
## ref: https://kubernetes.io/docs/concepts/containers/images/#pre-pulled-images
##
imagePullPolicy: IfNotPresent

## Specifying ImagePullSecrets on a Pod
## Kubernetes supports specifying container image registry keys on a Pod.
## ref: https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod
##
# imagePullSecrets:
#   - name: "image-pull-secret"

## Timeout, in seconds, for liveness and readiness probes of a runner pod.
# probeTimeoutSeconds: 4

## Configure the livenessProbe
livenessProbe: {}
#   initialDelaySeconds: 60
#   periodSeconds: 60
#   successThreshold: 1
#   failureThreshold: 3
#   terminationGracePeriodSeconds: 30

## Configure the readinessProbe
readinessProbe: {}
#   initialDelaySeconds: 60
#   periodSeconds: 60
#   successThreshold: 1
#   failureThreshold: 3

## How many runner pods to launch.
##
# replicas: 1

## How many old ReplicaSets for this Deployment you want to retain
# revisionHistoryLimit: 10

## The GitLab Server URL (with protocol) that want to register the runner against
## ref: https://docs.gitlab.com/runner/commands/index.html#gitlab-runner-register
##
# gitlabUrl: https://gitlab.your-domain.com/

## DEPRECATED: The Registration Token for adding new Runners to the GitLab Server.
##
## ref: https://docs.gitlab.com/ee/ci/runners/new_creation_workflow.html
##
# runnerRegistrationToken: ""

## The Runner Token for adding new Runners to the GitLab Server. This must
## be retrieved from your GitLab instance. It is the token of an already registered runner.
## ref: (we don't have docs for that yet, but we want to use an existing token)
##
# runnerToken: ""
#

## Unregister all runners before termination
##
## Updating the runner's chart version or configuration will cause the runner container
## to be terminated and created again. This may cause your Gitlab instance to reference
## non-existant runners. Un-registering the runner before termination mitigates this issue.
## ref: https://docs.gitlab.com/runner/commands/index.html#gitlab-runner-unregister
##
## This property ensures that all the Runners present in the local config.toml are unregistered when the chart is uninstalled
## - If the token is prefixed with `glrt-` (meaning the runner was created in the UI or API),
##   the unregisterRunners property deletes the runner manager, not the runner.
##   The runner manager is identified by the runner and the machine that contains the config.toml.
## - If the runner was registered with a registration token (deprecated), the runner is deleted.
unregisterRunners: true

## When stopping the runner, give it time to wait for its jobs to terminate.
##
## Updating the runner's chart version or configuration will cause the runner container
## to be terminated with a graceful stop request. terminationGracePeriodSeconds
## instructs Kubernetes to wait long enough for the runner pod to terminate gracefully.
## ref: https://docs.gitlab.com/runner/commands/#signals
terminationGracePeriodSeconds: 3600

## Set the certsSecretName in order to pass custom certficates for GitLab Runner to use.
## Provide resource name for a Kubernetes Secret Object in the same namespace,
## this is used to populate the /home/gitlab-runner/.gitlab-runner/certs/ directory
## ref: https://docs.gitlab.com/runner/configuration/tls-self-signed.html#supported-options-for-self-signed-certificates-targeting-the-gitlab-server
##
# certsSecretName:

## Configure the maximum number of concurrent jobs
## ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section
##
concurrent: 10

## Number of seconds until the forceful shutdown operation times out and exits the process.
## ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section
##
shutdown_timeout: 0

## Defines in seconds how often to check GitLab for new builds
## ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section
##
checkInterval: 3

## Configure GitLab Runner's logging level. Available values are: debug, info, warn, error, fatal, panic
## ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section
##
# logLevel:

## Configure GitLab Runner's logging format. Available values are: runner, text, json
## ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section
##
# logFormat:

## Configure GitLab Runner's Sentry DSN.
## ref https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section
##
# sentryDsn:

## Configure GitLab Runner's maximum connection age for TLS keepalive connections.
## ref https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section
##
# connectionMaxAge: "15m"

## A custom bash script that will be executed prior to the invocation of the
## gitlab-runner process
#
#preEntrypointScript: |
#  echo "hello"

## Specify whether the runner should start the session server.
## Defaults to false
## ref:
##
## When sessionServer is enabled, the user can either provide a public publicIP
## or rely on the external IP auto discovery.
## When a serviceAccountName is used with the automounting to the pod disabled,
## we recommend the usage of the publicIP
sessionServer:
  enabled: false
  # annotations: {}
  # timeout: 1800
  # internalPort: 8093
  # externalPort: 9000

  #In case sessionServer.serviceType is NodePort. If not defined, auto NodePort will be assigned.
  # nodePort: 30093

  # publicIP: ""
  # loadBalancerSourceRanges:
  #   - 1.2.3.4/32

  #Valid values: ClusterIP, Headless, NodePort, LoadBalancer
  serviceType: LoadBalancer

  ## Specify the services external traffic policy
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#traffic-policies
  ##
  # externalTrafficPolicy:

  ## Specify the services internal traffic policy
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#traffic-policies
  ##
  # internalTrafficPolicy:

  # if enabled, sessionServer.publicIP variable should be set to the host e.g. runner1.example.com
  ingress:
    enabled: false
    className: ""
    annotations: {}
    tls:
      - secretName: gitlab-runner-session-server

## For RBAC support:
rbac:
  ## Specifies whether a Role and RoleBinding should be created
  ## If this value is set to `true`, `serviceAccount.create` should also be set to either `true` or `false`
  ##
  create: false
  ## Define the generated serviceAccountName when create is set to true
  ## It defaults to "gitlab-runner.fullname" if not provided
  ## DEPRECATED: Please use `serviceAccount.name` instead
  generatedServiceAccountName: ""

  ## Define list of rules to be added to the rbac role permissions.
  ## Each rule supports the keys:
  ## - apiGroups: default "" (indicates the core API group) if missing or empty.
  ## - resources: default "*" if missing or empty.
  ## - verbs: default "*" if missing or empty.
  ##
  ## Read more about the recommended rules on the following link
  ##
  ## ref: https://docs.gitlab.com/runner/executors/kubernetes/index.html#configure-runner-api-permissions
  ##
  rules: []
    # - resources: ["events"]
    #   verbs: ["list", "watch"]
    # - resources: ["namespaces"]
    #   verbs: ["create", "delete"]
    # - resources: ["pods"]
    #   verbs: ["create","delete","get"]
    # - apiGroups: [""]
    #   resources: ["pods/attach","pods/exec"]
    #   verbs: ["get","create","patch","delete"]
    # - apiGroups: [""]
    #   resources: ["pods/log"]
    #   verbs: ["get","list"]
    # - resources: ["secrets"]
    #   verbs: ["create","delete","get","update"]
    # - resources: ["serviceaccounts"]
    #   verbs: ["get"]
    # - resources: ["services"]
    #   verbs: ["create","get"]

  ## Run the gitlab-bastion container with the ability to deploy/manage containers of jobs
  ## cluster-wide or only within namespace
  clusterWideAccess: false

  ## Use the following Kubernetes Service Account name if RBAC is disabled in this Helm chart (see rbac.create)
  ## DEPRECATED: Please use `serviceAccount.name` instead
  ##
  # serviceAccountName: default

  ## Specify annotations for Service Accounts, useful for annotations such as eks.amazonaws.com/role-arn.
  ## Values may refer to other values as the _tpl_ function is implicitly applied. Mind the quotes when using this, e.g.
  ## serviceAccountAnnotations:
  ##   eks.amazonaws.com/role-arn: "arn:aws:iam::{{ .Values.global.accountId }}:role/{{ .Values.global.iamRoleName }}"
  ##
  ## ref: https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html
  ##
  ## DEPRECATED: Please use `serviceAccount.annotations` instead
  ##
  serviceAccountAnnotations: {}

  ## Use podSecurity Policy
  ## ref: https://kubernetes.io/docs/concepts/policy/pod-security-policy/
  podSecurityPolicy:
    enabled: false
    resourceNames:
      - gitlab-runner

  ## Specify one or more imagePullSecrets used for pulling the runner image
  ##
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#add-imagepullsecrets-to-a-service-account
  ##
  ## DEPRECATED: Please use `serviceAccount.imagePullSecrets` instead
  ##
  imagePullSecrets: []

## Configure ServiceAccount
##
serviceAccount:
  ## Specifies whether a ServiceAccount should be created
  ##
  ## TODO: Set default to `false`
  # create: false
  ## The name of the ServiceAccount to use.
  ## If not set and create is `true`, a name is generated using the gitlab-runner.fullname template
  ##
  name: ""
  ## Additional custom annotations for the ServiceAccount, useful for annotations such as eks.amazonaws.com/role-arn.
  ## Values may refer other values as the _tpl_ function is implicitly applied. Mind the quotes when using this, e.g.
  ## serviceAccountAnnotations:
  ##   eks.amazonaws.com/role-arn: "arn:aws:iam::{{ .Values.global.accountId }}:role/{{ .Values.global.iamRoleName }}"
  ##
  ## ref: https://docs.aws.amazon.com/eks/latest/userguide/specify-service-account-role.html
  ##
  annotations: {}
  ## Specify one or more imagePullSecrets used for pulling the runner image
  ##
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#add-imagepullsecrets-to-a-service-account
  ##
  imagePullSecrets: []

## Configure integrated Prometheus metrics exporter
##
## ref: https://docs.gitlab.com/runner/monitoring/#configuration-of-the-metrics-http-server
##
metrics:
  enabled: false

  ## Define a name for the metrics port
  ##
  portName: metrics

  ## Provide a port number for the integrated Prometheus metrics exporter
  ##
  port: 9252

  ## Configure a prometheus-operator serviceMonitor to allow autodetection of
  ## the scraping target. Requires enabling the service resource below.
  ##
  serviceMonitor:
    enabled: false

    ## Provide additional labels to the service monitor resource
    ##
    ## labels: {}

    ## Provide annotations to the service monitor ressource
    ##
    ## annotations: {}

    ## Define a scrape interval (otherwise prometheus default is used)
    ##
    ## ref: https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config
    ##
    # interval: ""

    ## Specify the scrape protocol scheme e.g., https or http
    ##
    # scheme: "http"

    ## Supply a tls configuration for the service monitor
    ##
    ## ref: https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml
    ##
    # tlsConfig: {}

    ## The URI path where prometheus metrics can be scraped from
    ##
    # path: "/metrics"

    ## A list of MetricRelabelConfigs to apply to samples before ingestion
    ##
    ## ref: https://prometheus.io/docs/prometheus/latest/configuration/configuration/#metric_relabel_configs
    ##
    # metricRelabelings: []

    ## A list of RelabelConfigs to apply to samples before scraping
    ##
    ## ref: https://prometheus.io/docs/prometheus/latest/configuration/configuration/#relabel_config
    ##
    ## relabelings: []

## Configure a service resource e.g., to allow scraping metrics via
## prometheus-operator serviceMonitor
service:
  enabled: false

  ## Provide additonal labels for the service
  ##
  # labels: {}

  ## Provide additonal annotations for the service
  ##
  # annotations: {}

  ## Define a specific ClusterIP if you do not want a dynamic one
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#choosing-your-own-ip-address
  ##
  # clusterIP: ""

  ## Define a list of one or more external IPs for this service
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#external-ips
  ##
  # externalIPs: []

  ## Provide a specific loadbalancerIP e.g., of an external Loadbalancer
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer
  ##
  # loadBalancerIP: ""

  ## Provide a list of source IP ranges to have access to this service
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#aws-nlb-support
  ##
  # loadBalancerSourceRanges: []

  ## Specify the service type e.g., ClusterIP, NodePort, LoadBalancer or ExternalName
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types
  ##
  type: ClusterIP

  ## Specify the services metrics nodeport if you use a service of type nodePort
  ##
  # metrics:

  ## Specify the node port under which the prometheus metrics of the runner are made
  ## available.
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#nodeport
  ##
  # nodePort: ""

  ## Provide a list of additional ports to be exposed by this service
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#defining-a-service
  ##
  # additionalPorts: []

  ## Specify the services external traffic policy
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#traffic-policies
  ##
  # externalTrafficPolicy:

  ## Specify the services internal traffic policy
  ##
  ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#traffic-policies
  ##
  # internalTrafficPolicy:

## Configuration for the Pods that the runner launches for each new job
##
runners:
  # runner configuration, where the multi line string is evaluated as a
  # template so you can specify helm values inside of it.
  #
  # tpl: https://helm.sh/docs/howto/charts_tips_and_tricks/#using-the-tpl-function
  # runner configuration: https://docs.gitlab.com/runner/configuration/advanced-configuration.html
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        image = "alpine"

  ## Absolute path for an existing runner configuration file
  ## Can be used alongside "volumes" and "volumeMounts" to use an external config file
  ## Active if runners.config is empty or null
  configPath: ""

  ## Which executor should be used
  ##
  # executor: kubernetes

  ## DEPRECATED: Specify whether the runner should be locked to a specific project: true, false.
  ##
  ## ref: https://docs.gitlab.com/ee/ci/runners/new_creation_workflow.html
  ##
  # locked: true

  ## DEPRECATED: Specify the tags associated with the runner. Comma-separated list of tags.
  ##
  ## ref: https://docs.gitlab.com/ee/ci/runners/new_creation_workflow.html
  ##
  # tags: ""

  ## Specify the name for the runner.
  ##
  # name: ""

  ## DEPRECATED: Specify the maximum timeout (in seconds) that will be set for job when using this Runner
  ##
  ## ref: https://docs.gitlab.com/ee/ci/runners/new_creation_workflow.html
  ##
  # maximumTimeout: ""

  ## DEPRECATED: Specify if jobs without tags should be run.
  ##
  ## ref: https://docs.gitlab.com/ee/ci/runners/new_creation_workflow.html
  ##
  # runUntagged: true

  ## DEPRECATED: Specify whether the runner should only run protected branches.
  ##
  ## ref: https://docs.gitlab.com/ee/ci/runners/new_creation_workflow.html
  ##
  # protected: true

  ## The name of the secret containing runner-token and runner-registration-token
  # secret: gitlab-runner

  ## Distributed runners caching
  ## ref: https://docs.gitlab.com/runner/configuration/autoscale.html#distributed-runners-caching
  ##
  ## If you want to use s3 based distributing caching:
  ## First of all you need to uncomment General settings and S3 settings sections.
  ##
  ## Create a secret 's3access' containing 'accesskey' & 'secretkey'
  ## ref: https://aws.amazon.com/blogs/security/wheres-my-secret-access-key/
  ##
  ## $ kubectl create secret generic s3access \
  ##   --from-literal=accesskey="YourAccessKey" \
  ##   --from-literal=secretkey="YourSecretKey"
  ## ref: https://kubernetes.io/docs/concepts/configuration/secret/
  ##
  ## If you want to use gcs based distributing caching:
  ## First of all you need to uncomment General settings and GCS settings sections.
  ##
  ## Access using credentials file:
  ## Create a secret 'google-application-credentials' containing your application credentials file.
  ## ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnerscachegcs-section
  ## You could configure
  ## $ kubectl create secret generic google-application-credentials \
  ##   --from-file=gcs-application-credentials-file=./path-to-your-google-application-credentials-file.json
  ## ref: https://kubernetes.io/docs/concepts/configuration/secret/
  ##
  ## Access using access-id and private-key:
  ## Create a secret 'gcsaccess' containing 'gcs-access-id' & 'gcs-private-key'.
  ## ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnerscachegcs-section
  ## You could configure
  ## $ kubectl create secret generic gcsaccess \
  ##   --from-literal=gcs-access-id="YourAccessID" \
  ##   --from-literal=gcs-private-key="YourPrivateKey"
  ## ref: https://kubernetes.io/docs/concepts/configuration/secret/
  ##
  ## If you want to use Azure-based distributed caching:
  ## First, uncomment General settings.
  ##
  ## Create a secret 'azureaccess' containing 'azure-account-name' & 'azure-account-key'
  ## ref: https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction
  ##
  ## $ kubectl create secret generic azureaccess \
  ##   --from-literal=azure-account-name="YourAccountName" \
  ##   --from-literal=azure-account-key="YourAccountKey"
  ## ref: https://kubernetes.io/docs/concepts/configuration/secret/

  cache: {}
    ## S3 the name of the secret.
    # secretName: s3access
    ## Use this line for access using gcs-access-id and gcs-private-key
    # secretName: gcsaccess
    ## Use this line for access using google-application-credentials file
    # secretName: google-application-credentials
    ## Use this line for access using Azure with azure-account-name and azure-account-key
    # secretName: azureaccess

## Specify the name of the scheduler which is used to schedule runner pods.
## Kubernetes supports multiple scheduler configurations.
## ref: https://kubernetes.io/docs/reference/scheduling
# schedulerName: "my-custom-scheduler"

## Configure securitycontext for the main container
## ref: https://kubernetes.io/docs/concepts/security/pod-security-standards/
##
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  privileged: false
  capabilities:
    drop: ["ALL"]

## Configure update strategy for multi-replica deployments
## Kubernetes supports types Recreate, and RollingUpdate
## ref: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy
##
strategy: {}
  # rollingUpdate:
  #   maxSurge: 1
  #   maxUnavailable: 0
  # type: RollingUpdate

## Configure securitycontext valid for the whole pod
## ref: https://kubernetes.io/docs/concepts/security/pod-security-standards/
##
podSecurityContext:
  runAsUser: 100
  # runAsGroup: 65533
  fsGroup: 65533
  # supplementalGroups: [65533]

  ## Note: values for the ubuntu image:
  # runAsUser: 999
  # fsGroup: 999

## Configure resource requests and limits
## ref: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
##
resources: {}
  # limits:
  #   memory: 256Mi
  #   cpu: 200m
  #   ephemeral-storage: 512Mi
  # requests:
  #   memory: 128Mi
  #   cpu: 100m
  #   ephemeral-storage: 256Mi

## Affinity for pod assignment
## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
##
affinity: {}

## TopologySpreadConstraints for pod assignment
## Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/
##
topologySpreadConstraints: {}
  # Example: The gitlab runner should be evenly spread across zones
  # - maxSkew: 1
  #   topologyKey: zone
  #   whenUnsatisfiable: DoNotSchedule
  #   labelSelector:
  #     matchLabels:
  #       foo: bar

## RuntimeClass name for pod assignment
## ref: https://kubernetes.io/docs/concepts/containers/runtime-class/
##
runtimeClassName: ""
  # Example: Once RuntimeClasses are configured for the cluster, you can specify it.
  # runtimeClassName: myclass

## Node labels for pod assignment
## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
##
nodeSelector: {}
  # Example: The gitlab runner manager should not run on spot instances so you can assign
  # them to the regular worker nodes only.
  # node-role.kubernetes.io/worker: "true"

## List of node taints to tolerate (requires Kubernetes >= 1.6)
## ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
##
tolerations: []
  # Example: Regular worker nodes may have a taint, thus you need to tolerate the taint
  # when you assign the gitlab runner manager with nodeSelector or affinity to the nodes.
  # - key: "node-role.kubernetes.io/worker"
  #   operator: "Exists"

## Configure environment variables that will be present when the registration command runs
## This provides further control over the registration process and the config.toml file
## ref: `gitlab-runner register --help`
## ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html
##
# envVars:
#   - name: RUNNER_EXECUTOR
#     value: kubernetes

## Additional environment variables from key-value pairs.
extraEnv: {}
  # CACHE_S3_SERVER_ADDRESS: s3.amazonaws.com
  # CACHE_S3_BUCKET_NAME: runners-cache
  # CACHE_S3_BUCKET_LOCATION: us-east-1
  # CACHE_SHARED: true

## Additional environment variables from other data sources
extraEnvFrom: {}
  # CACHE_S3_ACCESS_KEY:
  #   secretKeyRef:
  #     name: s3access
  #     key: accesskey
  # CACHE_S3_SECRET_KEY:
  #   secretKeyRef:
  #     name: s3access
  #     key: secretkey

## list of hosts and IPs that will be injected into the pod's hosts file
hostAliases: []
  # Example:
  # - ip: "127.0.0.1"
  #   hostnames:
  #   - "foo.local"
  #   - "bar.local"
  # - ip: "10.1.2.3"
  #   hostnames:
  #   - "foo.remote"
  #   - "bar.remote"

## Annotations to be added to deployment
##
deploymentAnnotations: {}
  # Example:
  # downscaler/uptime: <my_uptime_period>

## Labels to be added to deployment
##
deploymentLabels: {}
  # Example:
  # owner.team: <my_cool_team>
  # owner.team: "{{ .Values.team }}"
  # tags.{{ .Values.tag }}/env: "{{ .Values.environment }}"

## Lifecycle options to be added to deployment
##
deploymentLifecycle: {}
  # Example
  # preStop:
  #   exec:
  #     command: ["/bin/sh", "-c", "echo 'shutting down'"]

## Set hostname for runner pods
#hostname: my-gitlab-runner

## Annotations to be added to manager pod
##
podAnnotations: {}
  # Example:
  # iam.amazonaws.com/role: <my_role_arn>

## Labels to be added to manager pod
##
## Supports templating
podLabels: {}
  # Example:
  # owner.team: <my_cool_team>
  # owner.team: "{{ .Values.team }}"
  # tags.{{ .Values.tag }}/env: "{{ .Values.environment }}"

## HPA support for custom metrics:
## This section enables runners to autoscale based on defined custom metrics.
## In order to use this functionality, you need to enable a custom metrics API server by
## implementing "custom.metrics.k8s.io" using supported third party adapter
## Example: https://github.com/directxman12/k8s-prometheus-adapter
##
# hpa: {}
#   minReplicas: 1
#   maxReplicas: 10
#   metrics:
#   - type: Pods
#     pods:
#       metricName: gitlab_runner_jobs
#       targetAverageValue: 400m

## Configure priorityClassName for manager pod. See k8s docs for more info on how pod priority works:
##  https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/
priorityClassName: ""

## Secrets to be additionally mounted to the containers.
## All secrets are mounted through init-runner-secrets volume
## and placed as readonly at /init-secrets in the init container
## and finally copied to an in-memory volume runner-secrets that is
## mounted at /secrets.
secrets: []
  # Example:
  # - name: my-secret
  # - name: myOtherSecret
  #   items:
  #     - key: key_one
  #       path: path_one

## Boolean to turn off the automountServiceAccountToken in the deployment
## ref: https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#bound-service-account-token-volume
##
# automountServiceAccountToken: false

## Additional config files to mount in the containers in `/configmaps`.
##
## Please note that a number of keys are reserved by the runner.
## See https://gitlab.com/gitlab-org/charts/gitlab-runner/-/blob/main/templates/configmap.yaml
## for a current list.
configMaps: {}

## Additional volumeMounts to add to the runner container
##
volumeMounts: []
  # Example:
  # - name: my-volume
  #   mountPath: /mount/path

## Additional volumes to add to the runner deployment
##
volumes: []
  # Example:
  # - name: my-volume
  #   persistentVolumeClaim:
  #     claimName: my-pvc

## Array of extra K8s manifests to deploy
##
extraObjects: []
# - apiVersion: external-secrets.io/v1beta1
#   kind: ExternalSecret
#   metadata:
#     name: '{{ include "gitlab-runner.secret" . }}'
#   spec:
#     refreshInterval: 1h
#     secretStoreRef:
#       kind: SecretStore
#       name: my-secret-store
#     target:
#       template:
#         data:
#           runner-registration-token: "" # need to leave as an empty string for compatibility reasons
#           runner-token: "{{{{ .runnerToken }}}}"
#     dataFrom:
#     - extract:
#         key: my-secret-store-secret

## Add additional containers to the Pod, e.g. to run as sidecars.
##
## Example:
#  - name: docker
#    image: docker:20.10-dind
#    securityContext:
#      privileged: true
#    volumeMounts:
#      - mountPath: /var/run/
#        name: dind-socket
#    lifecycle:
#      postStart:
#        exec:
#          command: [ "sh", "-c", "until docker info; do sleep 1; done;" ]
extraContainers: []
EOF

helm upgrade --install gitlab-runner gitlab/gitlab-runner -f gitlab-runner-values.yaml

wait_for_pod "app.kubernetes.io/name=gitlab-runner"

echo "All components installed successfully!"
