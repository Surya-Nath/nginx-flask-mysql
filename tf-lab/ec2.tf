data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "lab" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [data.aws_security_group.lab.id]
  key_name                    = "lab-week2"
  iam_instance_profile        = "ecr-pull-role"
  associate_public_ip_address = true

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
  }

  tags = {
    Name = "devops-lab"
  }
}
