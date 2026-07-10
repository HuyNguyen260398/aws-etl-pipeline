data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "flow_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"]
  }
}

data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    sid    = "AllowOnlyLakeBuckets"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.s3_endpoint_allowed_principal_arns
    }

    actions = ["s3:*"]

    resources = concat(
      var.s3_endpoint_allowed_bucket_arns,
      [for bucket_arn in var.s3_endpoint_allowed_bucket_arns : "${bucket_arn}/*"],
    )
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_default_security_group" "this" {
  vpc_id  = aws_vpc.this.id
  ingress = []
  egress  = []

  tags = merge(var.tags, { Name = "${var.name_prefix}-default-restricted" })
}

resource "aws_subnet" "private" {
  for_each = { for index, cidr in var.private_subnet_cidrs : index => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = "${var.aws_region}${var.availability_zone_suffixes[tonumber(each.key)]}"
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-private-${tonumber(each.key) + 1}" })
}

resource "aws_internet_gateway" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "public_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.nat_public_subnet_cidr
  availability_zone       = "${var.aws_region}${var.availability_zone_suffixes[0]}"
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-public-nat" })
}

resource "aws_route_table" "public_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nat[0].id
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-public-nat" })
}

resource "aws_route_table_association" "public_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  subnet_id      = aws_subnet.public_nat[0].id
  route_table_id = aws_route_table.public_nat[0].id
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name_prefix}-nat" })
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_nat[0].id

  depends_on = [aws_internet_gateway.nat]

  tags = merge(var.tags, { Name = "${var.name_prefix}-nat" })
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [aws_nat_gateway.this[0].id] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = route.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-private-${tonumber(each.key) + 1}" })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table in aws_route_table.private : route_table.id]
  policy            = data.aws_iam_policy_document.s3_endpoint.json

  tags = merge(var.tags, { Name = "${var.name_prefix}-s3-gateway-endpoint" })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.flow_log_kms_key_id

  tags = var.tags
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name_prefix}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.name_prefix}-vpc-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}

resource "aws_flow_log" "vpc" {
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id
}

resource "aws_security_group" "glue" {
  name        = "${var.name_prefix}-glue"
  description = "Controls Glue job network access."
  vpc_id      = aws_vpc.this.id
  egress      = []

  tags = merge(var.tags, { Name = "${var.name_prefix}-glue" })
}

resource "aws_security_group" "redshift" {
  name        = "${var.name_prefix}-redshift"
  description = "Controls Redshift Serverless network access."
  vpc_id      = aws_vpc.this.id
  egress      = []

  tags = merge(var.tags, { Name = "${var.name_prefix}-redshift" })
}

resource "aws_vpc_security_group_egress_rule" "glue_to_redshift" {
  security_group_id            = aws_security_group.glue.id
  referenced_security_group_id = aws_security_group.redshift.id
  from_port                    = var.redshift_port
  to_port                      = var.redshift_port
  ip_protocol                  = "tcp"
  description                  = "Allow Glue jobs to connect to Redshift Serverless."
}

resource "aws_vpc_security_group_ingress_rule" "redshift_from_glue" {
  security_group_id            = aws_security_group.redshift.id
  referenced_security_group_id = aws_security_group.glue.id
  from_port                    = var.redshift_port
  to_port                      = var.redshift_port
  ip_protocol                  = "tcp"
  description                  = "Allow Redshift Serverless access from Glue jobs."
}
