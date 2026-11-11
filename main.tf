
# Find Amazon Linux 2023 AMI
data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Find the default VPC
data "aws_vpc" "default" {
  default = true
}

# Security group for Tomcat
resource "aws_security_group" "tomcat_sg" {
  name_prefix = "tomcat-lab-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Tomcat HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EC2 instance and install Tomcat
resource "aws_instance" "web" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.tomcat_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf install -y java-17-amazon-corretto-headless curl tar

    useradd --system --home-dir /opt/tomcat \
      --shell /sbin/nologin tomcat

    curl -fL -o /tmp/tomcat.tar.gz \
      https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.48/bin/apache-tomcat-10.1.48.tar.gz

    mkdir -p /opt/tomcat
    tar -xzf /tmp/tomcat.tar.gz -C /opt/tomcat \
      --strip-components=1

    chown -R tomcat:tomcat /opt/tomcat
    chmod +x /opt/tomcat/bin/*.sh

    cat > /etc/systemd/system/tomcat.service <<'SERVICE'
    [Unit]
    Description=Apache Tomcat
    After=network.target

    [Service]
    Type=forking
    User=tomcat
    Group=tomcat
    Environment=CATALINA_HOME=/opt/tomcat
    Environment=CATALINA_BASE=/opt/tomcat
    ExecStart=/opt/tomcat/bin/startup.sh
    ExecStop=/opt/tomcat/bin/shutdown.sh
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable --now tomcat
  EOF

  tags = {
    Name = "HelloWorld"
  }
}

output "tomcat_url" {
  value = "http://${aws_instance.web.public_ip}:8080"
}
