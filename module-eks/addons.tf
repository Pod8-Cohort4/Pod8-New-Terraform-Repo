# --------------------------------------------------------
# Providers
# --------------------------------------------------------
provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster_auth.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster_auth.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# --------------------------------------------------------
# EKS Cluster Auth
# --------------------------------------------------------
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks.name
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
    aws_eks_node_group.eks_node_group
  ]
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
  timeout          = 600

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
  wait             = true
  timeout          = 600

  values = [
    file("${path.module}/argocd-values.yaml")
  ]

  depends_on = [
    helm_release.nginx_ingress,
    helm_release.cert_manager
  ]
}
