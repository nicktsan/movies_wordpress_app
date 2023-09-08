resource "aws_rds_cluster" "wordpress" {
    cluster_identifier     = "wordpress-cluster"
    engine                 = "aurora-mysql"
    /*refer to https://docs.aws.amazon.com/AmazonRDS/latest/AuroraMySQLReleaseNotes/AuroraMySQL.Updates.30Updates.html
    for the latest database engine updates for Amazon Aurora MySQL version 3*/
    engine_version         = "8.0.mysql_aurora.3.04.0"
    #refers to data.tf for availability zones
    availability_zones     = data.aws_availability_zones.zones.names
    #Use AWS Parameter Store to store the values of database_name, master_username, and master_password
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