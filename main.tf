provider "aws" {
  region = "us-east-1"
}  

data "aws_security_group" "my-sg" {
  name = "my-sg"
}

resource "aws_instance" "k8s" {
  ami = "ami-084568db4383264d4" # Ubuntu 24.04 AMI
  instance_type = "t3.medium"
  key_name = "prod-kp"
  vpc_security_group_ids = [ data.aws_security_group.my-sg.id ]
  count = 3
}   


output "public_ips" {
  description = "Public IP's of EC2 Instance"
  value = aws_instance.k8s[*].public_ip
}
