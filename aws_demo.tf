provider "aws" {
    region = "ca-central-1"  
    access_key = "***************" #Access Key
    secret_key = " ***************" #Secret Key
}

# # 1. Create vpc

resource "aws_vpc" "Demo-VPC" {
  cidr_block       = "10.0.0.0/16"
  tags = {
    "name" = "My Server "
  }
}
# # 2. Create Internet Gateway

resource "aws_internet_gateway" "Demo" {
  vpc_id = aws_vpc.Demo-VPC.id
}

# # 3. Create Custom Route Table

resource "aws_route_table" "Demo-Route-table" {
  vpc_id = aws_vpc.Demo-VPC.id  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Demo.id
  }
 
  route {
    ipv6_cidr_block        = "::/0"
    gateway_id =aws_internet_gateway.Demo.id  
  }

  tags = {
    Name = "Routetable"
  }
}

# # 4. Create a Subnet 

resource "aws_subnet" "Demo-Subnet-1" {
  vpc_id     = aws_vpc.Demo-VPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ca-central-1a" 
  tags = {
    Name = "Main-subnet-1"
  }
}

# # 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.Demo-Subnet-1.id
  route_table_id = aws_route_table.Demo-Route-table.id
}  

# # 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.Demo-VPC.id

  ingress {  
    description      = "HTTPS from VPC" 
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {  
    description      = "HTTP from VPC" 
    from_port        = 80
    to_port          = 80 
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {  
    description      = "SSH from VPC" 
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
 
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_Web"
  }
}


# # 7. Create a network interface with an ip in the subnet that was created in step 4

 resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.Demo-Subnet-1.id
  private_ips     = ["10.0.1.50"] 
  security_groups = [aws_security_group.allow_web.id]
}

# # 8. Assign an ela stic IP to the network interface created in step 7
resource "aws_eip" "EIP" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.Demo] 
}  

# # 9. Create Ubuntu server and install/enable apache2

resource "aws_instance" "Web-Server" {
  ami           = "ami-0a7154091c5c6623e" 
  instance_type = "t2.micro"
  availability_zone = "ca-central-1a" 
  key_name = "sh1th"

  network_interface{
    device_index = 0
    network_interface_id  = aws_network_interface.web-server-nic.id
  } 
user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo My web server > /var/www/html/index.html'
            EOF 
  tags ={
   name = "web_server"
  }
}