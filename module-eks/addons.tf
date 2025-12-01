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
# Wait for EKS Node Group (optional)
# --------------------------------------------------------
resource "null_resource" "wait_for_nodes" {
  depends_on = [aws_eks_node_group.eks_node_group]

  provisioner "local-exec" {
    command = "echo 'Waiting for EKS nodes to be ready...' && sleep 120"
  }
}

# --------------------------------------------------------
# NGINX Ingress Helm Release
# --------------------------------------------------------
resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.14.0"
  namespace        = "ingress-nginx"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [
    file("${path.module}/nginx-ingress-values.yaml")
  ]

  depends_on = [
    null_resource.wait_for_nodes
  ]
}

# --------------------------------------------------------
# Wait for NGINX LB to be ready
# --------------------------------------------------------
resource "null_resource" "wait_for_nginx_lb" {
  depends_on = [helm_release.nginx_ingress]

  provisioner "local-exec" {
    command = <<EOT
kubectl wait --namespace ingress-nginx \
  --for=condition=available svc/ingress-nginx-controller \
  --timeout=600s
EOT
  }
}

# --------------------------------------------------------
# Cert-Manager Helm Release
# --------------------------------------------------------
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.14.5"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]

  depends_on = [helm_release.nginx_ingress]
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
  values           = [file("${path.module}/argocd-values.yaml")]
  wait             = true

  depends_on = [
    helm_release.nginx_ingress,
    helm_release.cert_manager
  ]
}

# --------------------------------------------------------
# Kubernetes Service Data Source for NGINX
# --------------------------------------------------------
data "kubernetes_service" "nginx_ingress" {
  provider = kubernetes.eks

  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  depends_on = [null_resource.wait_for_nginx_lb]
}

# --------------------------------------------------------
# Local aliases to maintain previous outputs for Route53
# --------------------------------------------------------
locals {
  nginx_ingress_dns = try(data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname, "")
  nginx_ingress_ip  = try(data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].ip, "")
}
