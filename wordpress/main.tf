resource "aws_rds_cluster" "wordpress" {
  cluster_identifier = "wordpress-cluster"
  engine             = "aurora-mysql"
  /*refer to https://docs.aws.amazon.com/AmazonRDS/latest/AuroraMySQLReleaseNotes/AuroraMySQL.Updates.30Updates.html
    for the latest database engine updates for Amazon Aurora MySQL version 3*/
  engine_version = "8.0.mysql_aurora.3.04.0"
  #refers to data.tf for availability zones
  availability_zones = data.aws_availability_zones.zones.names
  #Use AWS Parameter Store to store the values of database_name, master_username, and master_password
  #aws_ssm_parameter refers to the resources below this one
  database_name          = aws_ssm_parameter.dbname.value
  master_username        = aws_ssm_parameter.dbuser.value
  master_password        = aws_ssm_parameter.dbpassword.value
  db_subnet_group_name   = aws_db_subnet_group.dbsubnet.id
  engine_mode            = "serverless"
  vpc_security_group_ids = [aws_security_group.rds_secgrp.id]

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
  #refers to data.tf for aws_subnet_ids
  subnet_ids = data.aws_subnet_ids.subnets.ids
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
  subnet_id = sort(data.aws_subnet_ids.subnets.ids)[0]
  #refers to resource aws_security_group below
  security_groups = [aws_security_group.ec2_secgrp.id]
  /*Since we're not using a PEM file, we need to use an instance profile that will enable access via session manager.
    This allows us to connect to the EC2 instance using session manager. 
    Refer to https://korniichuk.medium.com/session-manager-e724eb105eb7 on how to Create AWS IAM Role*/
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
