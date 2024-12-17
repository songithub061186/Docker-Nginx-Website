provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["C:/Users/PC/.aws/credentials"]
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
  key_name   = "my-keypair"                            # Choose a name for the keypair
  public_key = file("C:/Users/PC/.ssh/my-keypair.pub") # Path to your public key
}

output "key_pair_id" {
  value = aws_key_pair.keypair
}

# # Output the public IP of the instance
# output "ec2_public_ip" {
#   value       = aws_instance.jenkins_apache_server.public_ip
#   description = "The public IP address of the EC2 instance"
# }





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

# Create EC2 instance for Jenkins server
resource "aws_instance" "jenkins_server" {
  ami                         = "ami-0e2c8caa4b6378d8c"
  instance_type               = "t2.micro"
  key_name                    = "my-keypair"
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.allow_all.id]
  associate_public_ip_address = true

  tags = {
    Name = "Jenkins-Server"
  }

  user_data = <<-EOF
  #!/bin/bash
  echo "start"

  # Update package lists
  sudo apt update -y

  # Install OpenJDK and required packages
  sudo apt install -y openjdk-21-jdk openjdk-21-jre

  # Add Jenkins repository key and configure Jenkins repository
  sudo wget -q -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
  echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

  # Install Jenkins
  sudo apt update -y
  sudo apt install -y jenkins
  sudo systemctl start jenkins
  sudo systemctl enable jenkins
  EOF
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
EOF
}

# Create EC2 instance for SonarQube server
resource "aws_instance" "sonarqube_server" {
  ami                         = "ami-0e2c8caa4b6378d8c"
  instance_type               = "t2.micro"
  key_name                    = "my-keypair"
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.allow_all.id]
  associate_public_ip_address = true

  tags = {
    Name = "SonarQube-Server"
  }

user_data = <<-EOF
#!/bin/bash
set -e  # Exit on any error
exec > >(tee /var/log/sonarqube-userdata.log) 2>&1

# Update system
echo "Updating system packages..."
sudo apt update -y

# Install Java 17
echo "Installing Java 17..."
sudo apt install -y openjdk-17-jdk openjdk-17-jre

# Install required utilities
echo "Installing wget and unzip..."
sudo apt install -y wget unzip

# Download SonarQube
echo "Downloading SonarQube..."
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.0.0.68432.zip -O /tmp/sonarqube.zip

# Unzip to opt directory
echo "Extracting SonarQube..."
sudo unzip /tmp/sonarqube.zip -d /opt

# Rename and set permissions
echo "Setting up SonarQube directory..."
# Remove existing directory if it exists
sudo rm -rf /opt/sonarqube

# Move and rename
sudo mv /opt/sonarqube-10.0.0.68432 /opt/sonarqube

# Create user if not exists, ignore error if user already present
sudo useradd -r -s /bin/false sonar || true

# Set permissions
sudo chown -R sonar:sonar /opt/sonarqube

# Create systemd service file
echo "Creating systemd service file..."
sudo tee /etc/systemd/system/sonarqube.service << SONAR_SERVICE
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always

[Install]
WantedBy=multi-user.target
SONAR_SERVICE

# Reload systemd, enable and start SonarQube
echo "Starting SonarQube service..."
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

# Clean up zip file
sudo rm /tmp/sonarqube.zip

echo "SonarQube installation completed successfully!"
EOF
}

# Output the public IP addresses of the instances
output "jenkins_server_ip" {
  value = aws_instance.jenkins_server.public_ip
}

output "docker_server_ip" {
  value = aws_instance.docker_server.public_ip
}

output "sonarqube_server_ip" {
  value = aws_instance.sonarqube_server.public_ip
}
