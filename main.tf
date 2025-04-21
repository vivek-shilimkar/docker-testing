terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "null" {}

locals {
  node_template_name = "github-template-${uuid()}"
  cluster_name       = "rke1-github-${uuid()}"
}

resource "null_resource" "create_rancher_resources" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      RANCHER_URL     = var.rancher_url
      RANCHER_TOKEN   = var.rancher_token
      AMI_ID          = var.ami_id
      REGION          = var.region
      INSTANCE_TYPE   = var.instance_type
      VPC_ID          = var.vpc_id
      SUBNET_ID       = var.subnet_id
      ZONE            = "a"
      SECURITY_GROUP  = var.security_group
      SSH_USER        = var.ssh_user
      DOCKER_VERSION  = var.docker_version
      TEMPLATE_NAME   = local.node_template_name
      CLUSTER_NAME    = local.cluster_name
    }

    command = <<EOT
set -e

# Create Node Template
curl -sk -X POST "$RANCHER_URL/v3/nodetemplate" \
  -H "Authorization: Bearer $RANCHER_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "name": "$TEMPLATE_NAME",
  "driver": "amazonec2",
  "amazonec2Config": {
    "ami": "$AMI_ID",
    "region": "$REGION",
    "instanceType": "$INSTANCE_TYPE",
    "vpcId": "$VPC_ID",
    "subnetId": "$SUBNET_ID",
    "zone": "$ZONE",
    "securityGroup": "$SECURITY_GROUP",
    "sshUser": "$SSH_USER",
    "privateAddressOnly": false
  },
  "engineInstallURL": "https://releases.rancher.com/install-docker-dev/$DOCKER_VERSION.sh"
}
EOF

# Create Cluster
curl -sk -X POST "$RANCHER_URL/v3/cluster" \
  -H "Authorization: Bearer $RANCHER_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "type": "cluster",
  "name": "$CLUSTER_NAME",
  "rancherKubernetesEngineConfig": {
    "network": {
      "plugin": "canal"
    }
  }
}
EOF
EOT
  }
}

resource "null_resource" "create_node_pools" {
  depends_on = [null_resource.create_rancher_resources]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      RANCHER_URL        = var.rancher_url
      RANCHER_TOKEN      = var.rancher_token
      CLUSTER_NAME       = local.cluster_name
      NODE_TEMPLATE_NAME = local.node_template_name
    }

    command = <<EOT
set -e

CLUSTER_ID=$(curl -sk -H "Authorization: Bearer $RANCHER_TOKEN" "$RANCHER_URL/v3/clusters?name=$CLUSTER_NAME" | jq -r '.data[0].id')
TEMPLATE_ID=$(curl -sk -H "Authorization: Bearer $RANCHER_TOKEN" "$RANCHER_URL/v3/nodetemplates?name=$NODE_TEMPLATE_NAME" | jq -r '.data[0].id')

echo "Using Cluster ID: $CLUSTER_ID"
echo "Using Template ID: $TEMPLATE_ID"

declare -A roles=( ["controlplane"]="true,false,false" ["etcd"]="false,true,false" ["worker1"]="false,false,true" ["worker2"]="false,false,true" )

for role in "${!roles[@]}"; do
  IFS=',' read -r control etcd worker <<< "${roles[$role]}"

  payload=$(cat <<EOF
{
  "type": "nodePool",
  "clusterId": "$CLUSTER_ID",
  "hostnamePrefix": "${role}-",
  "nodeTemplateId": "$TEMPLATE_ID",
  "quantity": 1,
  "controlPlane": $control,
  "etcd": $etcd,
  "worker": $worker
}
EOF
)

  curl -sk -X POST "$RANCHER_URL/v3/nodepool" \
    -H "Authorization: Bearer $RANCHER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload"
done
EOT
  }
}
