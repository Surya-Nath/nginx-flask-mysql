data "aws_security_group" "lab" {
  name   = "devops-lab-sg"
  vpc_id = data.aws_vpc.default.id
}
