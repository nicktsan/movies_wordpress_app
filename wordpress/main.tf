resource "aws_rds_cluster" "wordpress" {
  cluster_identifier = "wordpress-cluster"
  engine             = "aurora-mysql"
  //To see which versions are available in serverless mode, run this:
  //aws rds describe-db-engine-versions --engine aurora-mysql --filters Name=engine-mode,Values=serverless
  //And if you want to understand which DB versions are available according to the engine mode, just remove the filter:
  //aws rds describe-db-engine-versions --engine aurora-mysql
  engine_version = "5.7.mysql_aurora.2.08.3"
  //refers to data.tf for availability zones
  //data.aws_availability_zones.zones.names returns a list of availibility zones. Since we can only
  //have up to 3, we will sort the list, then take the first 3 elements
  availability_zones = slice(sort(data.aws_availability_zones.zones.names), 0, 2)
  #Use AWS Parameter Store to store the values of database_name, master_username, and master_password
  #aws_ssm_parameter refers to the resources below this one
  database_name             = aws_ssm_parameter.dbname.value
  master_username           = aws_ssm_parameter.dbuser.value
  master_password           = aws_ssm_parameter.dbpassword.value
  db_subnet_group_name      = aws_db_subnet_group.dbsubnet.id
  engine_mode               = "serverless"
  vpc_security_group_ids    = [aws_security_group.rds_secgrp.id]
  skip_final_snapshot       = false
  final_snapshot_identifier = var.final_snapshot_identifier
  apply_immediately         = true

  scaling_configuration {
    min_capacity = 1
    max_capacity = 2
  }
  #local refers to locals.tf
  tags = local.tags
}

resource "aws_ssm_parameter" "dbname" {
  name  = "/app/wordpress/DATABASE_NAME"
  type  = "String"
  value = var.database_name
}

resource "aws_ssm_parameter" "dbuser" {
  name  = "/app/wordpress/DATABASE_MASTER_USERNAME"
  type  = "String"
  value = var.database_master_username
}

resource "aws_ssm_parameter" "dbpassword" {
  name  = "/app/wordpress/DATABASE_MASTER_PASSWORD"
  type  = "SecureString"
  value = random_password.password.result
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "aws_db_subnet_group" "dbsubnet" {
  name        = "wordpress-cluster-subnet"
  description = "Aurora wordpress cluster db subnet group"
  #refers to data.tf for aws_subnets
  subnet_ids = data.aws_subnets.subnets.ids
  tags       = local.tags
}

resource "aws_security_group" "rds_secgrp" {
  name        = "wordpress rds access"
  description = "RDS secgroup"
  vpc_id      = var.vpc_id

  ingress {
    description = "VPC bound"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    #pulls cidr_block associated to the vpc id from datas.tf
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  tags = local.tags
}

//Add IAM role
resource "aws_iam_role" "ec2_role" {
  name = "ec2roleforssm"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

//Add an IAM role policy attachment
resource "aws_iam_role_policy_attachment" "ec2policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

//Create an IAM instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "wordpress" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ec2_instance_type
  associate_public_ip_address = true
  #pull a singular subnet id from data.tf
  subnet_id = sort(data.aws_subnets.subnets.ids)[0]
  #refers to resource aws_security_group below
  security_groups = [aws_security_group.ec2_secgrp.id]
  //If you already have a role with that can manage ec2 instances via session manager, you can provide the name of that
  //instance profile for iam_instance_profile instead of creating another.
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  user_data            = data.template_file.userdata.rendered

  tags = merge(local.tags, {
    Name = "wordpress-instance"
  })
}

resource "aws_security_group" "ec2_secgrp" {
  name        = "wordpress-instance-secgrp"
  description = "wordpress instance secgrp"
  vpc_id      = var.vpc_id

  ingress {
    from_port = var.wordpress_external_port
    to_port   = var.wordpress_external_port
    protocol  = "tcp"
    //In a professional setting, using 0.0.0.0/0 has security risks. Only allow the bare minimum number of ports for ingress.
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags

}
//Use cloudflare to proxy requests to the vm
resource "cloudflare_record" "wp" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name    = var.endpoint
  value   = aws_instance.wordpress.public_ip
  type    = "A"
  proxied = true
}
