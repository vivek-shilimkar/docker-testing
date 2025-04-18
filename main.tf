provider "http" {}

locals {
  node_template_name = "github-template-${uuid()}"
  cluster_name       = "rke1-github-${uuid()}"
}

resource "http_request" "create_node_template" {
  url    = "${var.rancher_url}/v3/nodetemplate"
  method = "POST"
  headers = {
    Authorization = "Bearer ${var.rancher_token}"
    Content-Type  = "application/json"
  }

  body = jsonencode({
    name        = local.node_template_name,
    driver      = "amazonec2",
    amazonec2Config = {
      ami               = var.ami_id,
      region            = var.region,
      instanceType      = var.instance_type,
      vpcId             = var.vpc_id,
      subnetId          = var.subnet_id,
      zone              = "a",
      securityGroup     = var.security_group,
      sshUser           = var.ssh_user,
      privateAddressOnly = false
    },
    engineInstallURL = "https://releases.rancher.com/install-docker/${var.docker_version}.sh"
  })
}

resource "http_request" "create_cluster" {
  depends_on = [http_request.create_node_template]

  url    = "${var.rancher_url}/v3/cluster"
  method = "POST"
  headers = {
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
    command = <<EOT
      set -e
      CLUSTER_ID=$(curl -sk -H "Authorization: Bearer ${var.rancher_token}" "${var.rancher_url}/v3/clusters?name=${local.cluster_name}" | jq -r '.data[0].id')
      TEMPLATE_ID=$(curl -sk -H "Authorization: Bearer ${var.rancher_token}" "${var.rancher_url}/v3/nodetemplates?name=${local.node_template_name}" | jq -r '.data[0].id')
      echo "Using Cluster ID: $CLUSTER_ID"
      echo "Using Template ID: $TEMPLATE_ID"
      declare -A roles=( ["controlplane"]="true,false,false" ["etcd"]="false,true,false" ["worker1"]="false,false,true" ["worker2"]="false,false,true" )
      for role in "${!roles[@]}"; do
        IFS=',' read control etcd worker <<< "${roles[$role]}"
        curl -sk -X POST "${var.rancher_url}/v3/nodepool" \
          -H "Authorization: Bearer ${var.rancher_token}" \
          -H "Content-Type: application/json" \
          -d "{
            \"type\": \"nodePool\",
            \"clusterId\": \"$CLUSTER_ID\",
            \"hostnamePrefix\": \"${role}-\",
            \"nodeTemplateId\": \"$TEMPLATE_ID\",
            \"quantity\": 1,
            \"controlPlane\": $control,
            \"etcd\": $etcd,
            \"worker\": $worker
          }"
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}