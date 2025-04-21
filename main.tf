terraform {
  required_providers {
    http = {
      source  = "Mastercard/http"
      version = "~> 1.2.0"
    }
  }
}

provider "http" {}

locals {
  node_template_name = "github-template-${uuid()}"
  cluster_name       = "rke1-github-${uuid()}"
}

resource "http_request" "create_node_template" {
  url    = "${var.rancher_url}/v3/nodetemplate"
  method = "POST"
  request_headers = {
    Authorization = "Bearer ${var.rancher_token}"
    Content-Type  = "application/json"
  }

  body = jsonencode({
    name        = local.node_template_name,
    driver      = "amazonec2",
    amazonec2Config = {
      accessKey           = var.AWS_KEY_ID,
      secretKey           = var.AWS_SECRET_ACCESS_KEY,
      ami                 = var.ami_id,
      region              = var.region,
      instanceType        = var.instance_type,
      vpcId               = var.vpc_id,
      subnetId            = var.subnet_id,
      zone                = "a",
      securityGroup       = var.security_group,
      sshUser             = var.ssh_user,
      privateAddressOnly  = false
    },
    engineInstallURL = "https://releases.rancher.com/install-docker-dev/${var.docker_version}.sh"
  })
}

resource "http_request" "create_cluster" {
  depends_on = [http_request.create_node_template]

  url    = "${var.rancher_url}/v3/cluster"
  method = "POST"
  request_headers = {
    Authorization = "Bearer ${var.rancher_token}"
    Content-Type  = "application/json"
  }

  body = jsonencode({
    type = "cluster",
    name = local.cluster_name,
    rancherKubernetesEngineConfig = {
      network = {
        plugin = "canal"
      }
    }
  })
}

resource "null_resource" "create_node_pools" {
  depends_on = [http_request.create_cluster]

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

CLUSTER_ID=$$(curl -sk -H "Authorization: Bearer $$RANCHER_TOKEN" "$$RANCHER_URL/v3/clusters?name=$$CLUSTER_NAME" | jq -r '.data[0].id')
TEMPLATE_ID=$$(curl -sk -H "Authorization: Bearer $$RANCHER_TOKEN" "$$RANCHER_URL/v3/nodetemplates?name=$$NODE_TEMPLATE_NAME" | jq -r '.data[0].id')

echo "Using Cluster ID: $$CLUSTER_ID"
echo "Using Template ID: $$TEMPLATE_ID"

declare -A roles=( ["controlplane"]="true,false,false" ["etcd"]="false,true,false" ["worker1"]="false,false,true" ["worker2"]="false,false,true" )

for role in "$${!roles[@]}"; do
  IFS=',' read -r control etcd worker <<< "$${roles[$$role]}"

  payload=$$(cat <<EOF
{
  "type": "nodePool",
  "clusterId": "$$CLUSTER_ID",
  "hostnamePrefix": "$${role}-",
  "nodeTemplateId": "$$TEMPLATE_ID",
  "quantity": 1,
  "controlPlane": $$control,
  "etcd": $$etcd,
  "worker": $$worker
}
EOF
)

  curl -sk -X POST "$$RANCHER_URL/v3/nodepool" \
    -H "Authorization: Bearer $$RANCHER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$$payload"
done
EOT
  }
}
