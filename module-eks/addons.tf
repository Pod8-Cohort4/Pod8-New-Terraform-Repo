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
    name       = "nginx-ingress"
    repository = "https://kubernetes.github.io/ingress-nginx"
    chart      = "ingress-nginx"
    version    = "4.12.0"
    namespace  = "ingress-nginx"
    create_namespace = true

    values = [file("${path.module}/nginx-ingress-values.yaml")]
    depends_on = [ null_resource.wait_for_nodes ]
}

data "aws_lb" "nginx_ingress" {
  tags = {
    "kubernetes.io/service-name" = "ingress-nginx/nginx-ingress-ingress-nginx-controller"
  }

  depends_on = [helm_release.nginx_ingress]
}

# Cert-Manager
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

  depends_on = [
    helm_release.nginx_ingress
  ]
}

#==================================================

resource "null_resource" "wait_for_crds" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = "sleep 40"
  }
}


resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true

  values = [file("${path.module}/argocd-values.yaml")]

  depends_on = [
    helm_release.nginx_ingress,
    null_resource.wait_for_crds
  ]
}
