provider "http" {}

locals {
  node_template_name = "github-template-${uuid()}"
  cluster_name       = "rke1-github-${uuid()}"
}

resource "null_resource" "create_node_template" {
  provisioner "local-exec" {
    command = <<EOT
curl -k -X POST "${var.rancher_url}/v3/nodetemplate" \
  -H "Authorization: Bearer ${var.rancher_token}" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "${local.node_template_name}",
        "driver": "amazonec2",
        "amazonec2Config": {
          "ami": "${var.ami_id}",
          "region": "${var.region}",
          "instanceType": "${var.instance_type}",
          "vpcId": "${var.vpc_id}",
          "subnetId": "${var.subnet_id}",
          "zone": "a",
          "securityGroup": "${var.security_group}",
          "sshUser": "${var.ssh_user}",
          "privateAddressOnly": false
        },
        "engineInstallURL": "https://releases.rancher.com/install-docker-dev/${var.docker_version}.sh"
      }'
EOT
  }
}

resource "null_resource" "create_cluster" {
  depends_on = [null_resource.create_node_template]

  provisioner "local-exec" {
    command = <<EOT
curl -k -X POST "${var.rancher_url}/v3/cluster" \
  -H "Authorization: Bearer ${var.rancher_token}" \
  -H "Content-Type: application/json" \
  -d '{
        "type": "cluster",
        "name": "${local.cluster_name}",
        "rancherKubernetesEngineConfig": {
          "network": {
            "plugin": "canal"
          }
        }
      }'
EOT
  }
}

resource "null_resource" "create_node_pools" {
  depends_on = [null_resource.create_cluster]

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
