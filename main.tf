provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["C:/Users/JERSON POGI/.aws/credentials"]
  profile                  = "default" # Specify the profile you want to use
}


# Fetch default VPC
data "aws_vpc" "default" {
  default = true
}


# Fetch default subnet in the default VPC
data "aws_subnet" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}





resource "aws_key_pair" "keypair" {
  key_name   = "my-keypair"                                     # Choose a name for the keypair
  public_key = file("C:/Users/JERSON POGI/.ssh/my-keypair.pub") # Path to your public key
}

output "key_pair_id" {
  value = aws_key_pair.keypair
}





# Create a Security Group that allows all traffic
resource "aws_security_group" "allow_all" {
  name        = "allow_all_sg"
  description = "Security group that allows all inbound and outbound traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}





# Create EC2 instance for Docker server
resource "aws_instance" "docker_server" {
  ami                         = "ami-0e2c8caa4b6378d8c"
  instance_type               = "t2.micro"
  key_name                    = "my-keypair"
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.allow_all.id]
  associate_public_ip_address = true

  tags = {
    Name = "Docker-Server"
  }

user_data = <<-EOF
#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status
exec > >(tee /var/log/docker-install.log) 2>&1

# Update package index
sudo apt update -y

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
sudo apt update -y

# Install Docker Engine
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (optional, removes need for sudo with docker)
sudo usermod -aG docker ubuntu

# Start and enable Docker services
sudo systemctl start docker
sudo systemctl enable docker

# Verify Docker installation
docker --version

echo "Docker installation completed successfully!"

# Create a directory named docker-app and navigate into it
mkdir docker-app && cd docker-app

# Create index.html with the specified content
echo "Please Contribute to my Ryzen 7 5700x3d" > index.html

# Create a Dockerfile with the specified content
cat <<EOL > Dockerfile
FROM nginx:latest
COPY index.html /usr/share/nginx/html
EOL

# Start the Docker service
echo "Starting Docker service..."
sudo systemctl start docker

# Build the Docker image
echo "Building the Docker image..."
docker build -t docker-app .

# Run the Docker image
docker run -d --name hahahaha -p 80:80 docker-app

# Notify completion
echo "Docker image 'docker-app' built successfully!"
EOF

  
}

# Output the public IP of the EC2 instance
output "docker_server_ip" {
  value = aws_instance.docker_server.public_ip
}

data "aws_route53_zone" "example" {
  name = "jersonix.online." # Replace with your domain name
}



# Create Route 53 A Record for kyle.jersonix.online pointing to EC2 instance IP
resource "aws_route53_record" "a_record" {
  zone_id = data.aws_route53_zone.example.id # Replace with your Route 53 Hosted Zone ID
  name    = "kyle.jersonix.online"
  type    = "A"
  ttl     = 60
  records = [aws_instance.docker_server.public_ip]
  }