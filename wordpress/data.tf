data "aws_availability_zones" "zones" {
    state = "available"
}

data "aws_subnet_ids" "subnets" {
    vpc_id = var.vpc_id
}

data "aws_vpc" "vpc" {
    id = var.vpc_id
}

data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    #to find the owner, search for ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server in https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LaunchInstances:
    owners = ["099720109477"]
}


data "template_file" "dockercompose" {
    template = file("./template/docker-compose.tpl")

    vars = {
        dbhost = aws_rds_cluster.wordpress.endpoint
        dbuser = aws_rds_cluster.wordpress.master_username
        dbpassword = aws_rds_cluster.wordpress.master_password
        dbname = aws_rds_cluster.wordpress.database_name
        external_port = var.wordpress_external_port
    }
}

data "template_file" "nginx_conf" {
    template = file("./template/server-conf.tpl")

    vars = {
        external_port = var.wordpress_external_port
        url_endpoint = "${var.endpoint}.${var.domain}"
    }
}

data "template_file" "userdata" {
    template = file("./template/userdata.tpl")

    vars = {
        dockercompose = data.template_file.dockercompose.rendered
        nginx_conf = data.template_file.nginx_conf.rendered
    }
}