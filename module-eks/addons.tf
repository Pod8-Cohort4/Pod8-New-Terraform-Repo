provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}





provider "kubernetes" {
  alias                  = "eks"
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster_auth" "cluster" {
    name = aws_eks_cluster.eks.name
}


data "aws_eks_cluster_auth" "eks" {
    name = aws_eks_cluster.eks.name
}

# --------------------------------------------------------
# Wait for EKS Node Group to be Ready
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
  version          = "4.12.0"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [
    file("${path.module}/nginx-ingress-values.yaml")
  ]

  depends_on = [
    null_resource.wait_for_nodes
  ]

  # Increase Helm timeout to handle slow node readiness
  timeout = 600
}

# --------------------------------------------------------
# Optional: Fetch the NLB after NGINX is installed
# --------------------------------------------------------
data "aws_lb" "nginx_ingress" {
  tags = {
    "kubernetes.io/service-name" = "ingress-nginx/ingress-nginx-controller"
  }

  depends_on = [helm_release.nginx_ingress]
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

  depends_on = [
    helm_release.nginx_ingress,
    helm_release.cert_manager
  ]
}
