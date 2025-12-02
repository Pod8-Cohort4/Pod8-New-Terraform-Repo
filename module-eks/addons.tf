# --------------------------------------------------------
# Helm Provider
# --------------------------------------------------------
provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# --------------------------------------------------------
# Kubernetes Provider (for resources & data)
# --------------------------------------------------------
provider "kubernetes" {
  alias                  = "eks"
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# --------------------------------------------------------
# EKS Auth Data
# --------------------------------------------------------
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks.name
}

# --------------------------------------------------------
# Wait for EKS Node Group
# --------------------------------------------------------
resource "null_resource" "wait_for_nodes" {
  depends_on = [aws_eks_node_group.eks_node_group]

  provisioner "local-exec" {
    command = "echo 'Waiting for EKS nodes...' && sleep 60"
  }
}

# --------------------------------------------------------
# NGINX Ingress Helm Release
# --------------------------------------------------------
resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.12.0"
  namespace        = "nginx-ingress"
  create_namespace = true

  values   = [file("${path.module}/nginx-ingress-values.yaml")]
  wait     = true
  timeout  = 600

  depends_on = [null_resource.wait_for_nodes]
}

# --------------------------------------------------------
# Optional wait for NGINX Load Balancer (ELB)
# --------------------------------------------------------
resource "null_resource" "wait_for_nginx_lb" {
  depends_on = [helm_release.nginx_ingress]

  provisioner "local-exec" {
    command = <<EOT
echo "Waiting for NGINX Load Balancer..."
sleep 120
EOT
  }
}


# Get the NGINX ingress service from Kubernetes
# --------------------------------------------------------
data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = "nginx-ingress"
  }

  depends_on = [helm_release.nginx_ingress]
}
# --------------------------------------------------------
# Cert-Manager Helm Release
# --------------------------------------------------------
resource "helm_release" "cert_manager" {
  name             = "cert-manager-${var.environment}"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.14.5"

  namespace        = "cert-manager"
  create_namespace = true

  values = [
    file("${path.module}/cert-manager-values.yaml")
  ]

  wait     = true
  timeout  = 900

  depends_on = [null_resource.wait_for_nodes]
}

# --------------------------------------------------------
# Wait for Cert-Manager CRDs + Webhooks to settle
# --------------------------------------------------------
resource "null_resource" "wait_for_crds" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = "echo 'Waiting for Cert-Manager CRDs and webhooks...' && sleep 30"
  }
}

# --------------------------------------------------------
# ArgoCD Helm Release
# --------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true

  values = [
    file("${path.module}/argocd-values.yaml")
  ]

  wait     = true
  timeout  = 600

  depends_on = [null_resource.wait_for_crds]
}
