provider "aws" {
  version = "~> 2.0"
  region  = "us-west-2"
}

##############################################################
# VPC, subnets and security group details
##############################################################
# resource aws_vpc "oracle" {
#   cidr_block           = "10.0.0.0/16"
#   enable_dns_hostnames = true

#   tags = {
#     Name = "assareh-oracle-vpc"
#   }
# }

# resource aws_subnet "subnet_a" {
#   vpc_id            = aws_vpc.oracle.id
#   availability_zone = "us-west-2a"
#   cidr_block        = "10.0.1.0/24"

#   tags = {
#     name = "assareh-oracle-subnet_a"
#   }
# }

# resource aws_subnet "subnet_b" {
#   vpc_id            = aws_vpc.oracle.id
#   availability_zone = "us-west-2b"
#   cidr_block        = "10.0.2.0/24"

#   tags = {
#     name = "assareh-oracle-subnet_a"
#   }
# }

# resource "aws_security_group" "oracle" {
#   name   = "assareh-security-group"
#   vpc_id = aws_vpc.oracle.id
# }

# resource "aws_security_group_rule" "oracle_ssh" {
#   security_group_id = aws_security_group.oracle.id
#   type              = "ingress"
#   from_port         = 22
#   to_port           = 22
#   protocol          = "tcp"
#   cidr_blocks       = [var.my_ip]
# }

# resource "aws_security_group_rule" "oracle_egress" {
#   security_group_id = aws_security_group.oracle.id
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
# }

######################## KEYS ########################
resource tls_private_key "oracle" {
  algorithm = "RSA"
}

resource aws_key_pair "oracle" {
  key_name   = "oracle-client"
  public_key = tls_private_key.oracle.public_key_openssh
}

######################## INSTANCES ########################
# resource aws_instance "client" {
#   ami                         = data.aws_ami.ubuntu-vault-oss.id
#   instance_type               = "t2.small"
#   key_name                    = aws_key_pair.oracle.key_name
#   associate_public_ip_address = true
#   subnet_id                   = aws_subnet.subnet_a.id
#   #vpc_security_group_ids      = [aws_security_group.oracle.id]

#   tags = {
#     Name  = "assareh-client-instance",
#     owner = var.owner,
#     ttl   = var.ttl
#   }
# }

# resource aws_instance "client2" {
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = "t2.small"
#   key_name                    = aws_key_pair.oracle.key_name
#   associate_public_ip_address = true
#   subnet_id                   = aws_subnet.subnet_b.id
#   #vpc_security_group_ids      = [aws_security_group.oracle.id]

#   tags = {
#     Name  = "assareh-client-instance",
#     owner = var.owner,
#     ttl   = var.ttl
#   }
# }

######################## AMI ########################
# data "aws_ami" "ubuntu-vault-oss" {
#   owners      = ["679593333241"] # HashiCorp
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["hashicorp/marketplace/vault-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


#####
# DB
#####
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = "demodb-oracle"

  engine            = "oracle-se2"
  engine_version    = "12.1.0.2.v8"
  instance_class    = "db.t3.small"
  allocated_storage = 10

  license_model = "license-included"

  # Make sure that database name is capitalized, otherwise RDS will try to recreate RDS instance every time
  name     = "DEMODB"
  username = var.db_username
  password = random_password.db_password.result
  port     = "1521"

  iam_database_authentication_enabled = false

  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.hashicat.id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # disable backups to create DB faster
  backup_retention_period = 0

  tags = {
    Name  = "assareh-oracledb-instance",
    owner = var.owner,
    ttl   = var.ttl
  }

  # DB subnet group
  subnet_ids = [aws_subnet.hashicat.id, aws_subnet.hashicat2.id]

  # DB parameter group
  family = "oracle-se2-12.1"

  # DB option group
  major_engine_version = "12.1"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "demodb"

  # See here for support character sets https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.OracleCharacterSets.html
  character_set_name = "AL32UTF8"
}

resource random_password "db_password" {
  length  = 20
  special = true
}




resource aws_instance "hashicat" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.oracle.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.hashicat.id
  vpc_security_group_ids      = [aws_security_group.hashicat.id]

  tags = {
    Name = "${var.prefix}-hashicat-instance"
  }
}

resource aws_vpc "hashicat" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc"
  }
}

resource aws_subnet "hashicat" {
  vpc_id            = aws_vpc.hashicat.id
  cidr_block        = var.subnet_prefix
  availability_zone = "us-west-2b"

  tags = {
    name = "${var.prefix}-subnet"
  }
}

resource aws_subnet "hashicat2" {
  vpc_id            = aws_vpc.hashicat.id
  cidr_block        = var.subnet2_prefix
  availability_zone = "us-west-2c"

  tags = {
    name = "${var.prefix}-subnet"
  }
}

resource aws_security_group "hashicat" {
  name = "${var.prefix}-security-group"

  vpc_id = aws_vpc.hashicat.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["76.93.151.110/32"]
  }

  ingress {
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8", "76.93.151.110/32"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.prefix}-security-group"
  }
}

resource aws_internet_gateway "hashicat" {
  vpc_id = aws_vpc.hashicat.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

resource aws_route_table "hashicat" {
  vpc_id = aws_vpc.hashicat.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hashicat.id
  }
}

resource aws_route_table_association "hashicat" {
  subnet_id      = aws_subnet.hashicat.id
  route_table_id = aws_route_table.hashicat.id
}