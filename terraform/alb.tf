# AWS Load Balancer Controller: IAM role for service account (IRSA)

locals {
  oidc_issuer = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "lb_controller" {
  name   = "${var.project_name}-lb-controller-policy"
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.project_name}-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume.json
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}


# ALB security group

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Public entry point: HTTP/HTTPS from the internet to the ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from the internet (redirected to HTTPS)"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from the internet"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_pods" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 5000
  to_port                      = 5000
  ip_protocol                  = "tcp"
  description                  = "ALB to the Flask pods only"
}

resource "aws_vpc_security_group_ingress_rule" "pods_from_alb" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 5000
  to_port                      = 5000
  ip_protocol                  = "tcp"
  description                  = "Flask app port from the ALB"
}

# Self-signed TLS certificate, imported into ACM for the ALB's HTTPS listener

resource "tls_private_key" "alb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  private_key_pem = tls_private_key.alb.private_key_pem

  subject {
    common_name  = "contactform.local"
    organization = "Contact Form App (self-signed)"
  }

  dns_names             = ["contactform.local"]
  validity_period_hours = 8760
  is_ca_certificate     = false

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "alb" {
  private_key      = tls_private_key.alb.private_key_pem
  certificate_body = tls_self_signed_cert.alb.cert_pem

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-alb-self-signed"
  }
}