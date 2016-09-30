####### Consul Cluster Configuration ######

## Define template file for configuration
resource "template_file" "consul_server_config" {
  count = "${var.consul_server_count}"
  template = "${file("${path.module}/files/consul_server.json")}"
  vars {
    consul_instance_private_ip = "${element(aws_instance.consul_server.*.private_ip, count.index)}"
    consul_private_ip_list = "${jsonencode(aws_instance.consul_server.*.private_ip)}"
    consul_server_count = "${var.consul_server_count}"
    consul_token = "${var.consul_token}"
  }
}

## Define instances
resource "aws_instance" "consul_server" {
  ami                 = "${lookup(var.aws_amis, "trusty")}"
  count               = "${var.consul_server_count}"
  instance_type       = "${var.instance_type}"
  subnet_id           = "${lookup(var.subnets, "private-${lookup(var.zones, count.index % 4)}")}"
  key_name            = "${var.key_name}"
  vpc_security_group_ids = [
      "${lookup(var.sgs, "default")}" ]

  tags {
      Name        = "consul-${var.cluster_name}-${format("%02d", count.index + 1)}-${var.env}.longtailvideo.com"
      CostCenter  = "${lookup(var.tag_map, "costcenter")}"
      Application = "${lookup(var.tag_map, "application")}"
      LTV-systype = "${lookup(var.tag_map, "LTV-systype")}"
      LTV-env     = "${var.env}"
  }
}

## Define dns records
resource "aws_route53_record" "consul_server_dns" {
  count = "${var.consul_server_count}"
  provider = "aws.dns"
  zone_id = "${var.route53zones["longtailvideo"]}"
  ttl = 300
  name = "consul-${var.cluster_name}-${format("%02d", count.index + 1)}-${var.env}.longtailvideo.com"
  type = "CNAME"
  records = ["${element(aws_instance.consul_server.*.private_ip, count.index)}"]
}

## Configure instances (must be done seperately in order to have acccess to computed variables)
resource "null_resource" "configure_consul_server" {
  count = "${var.consul_server_count}"

  connection {
     user = "ubuntu"
     private_key = "${file("${var.ssh_key_path}")}"
     host = "${element(aws_instance.consul_server.*.private_ip, count.index)}"
     timeout = "20m"
  }

  provisioner "file" {
      content = "${element(template_file.consul_server_config.*.rendered, count.index)}"
      destination = "/tmp/consul.json"
  }

  provisioner "file" {
      source = "files/consul.conf"
      destination = "/tmp/consul.conf"
  }

  provisioner "remote-exec" {
      script = "files/install_consul.sh"
  }

  provisioner "remote-exec" {
      inline = [
        "sudo mv /tmp/consul.json /etc/consul.d/consul.json",
        "sudo mv /tmp/consul.conf /etc/init/consul.conf",
        "sudo start consul"
      ]
  }
}

####### Nomad Server Configuration ######

## Define template for nomad server
resource "template_file" "nomad_server_config" {
  count = "${var.nomad_server_count}"
  template = "${file("${path.module}/files/nomad_server.json")}"
  vars {
    nomad_instance_private_ip = "${element(aws_instance.nomad_server.*.private_ip, count.index)}"
    nomad_server_count = "${var.nomad_server_count}"
    consul_token = "${var.consul_token}"
  }
}

## Define template for consul client (co-located on nomad server)
resource "template_file" "consul_client_config_nomad_server" {
  count = "${var.nomad_server_count}"
  template = "${file("${path.module}/files/consul_client.json")}"
  vars {
    consul_instance_private_ip = "${element(aws_instance.nomad_server.*.private_ip, count.index)}"
    consul_private_ip_list = "${jsonencode(aws_instance.consul_server.*.private_ip)}"
  }
}

## Define instances
resource "aws_instance" "nomad_server" {
  ami                 = "${lookup(var.aws_amis, "trusty")}"
  count               = "${var.nomad_server_count}"
  instance_type       = "${var.instance_type}"
  subnet_id           = "${lookup(var.subnets, "private-${lookup(var.zones, count.index % 4)}")}"
  key_name            = "${var.key_name}"
  vpc_security_group_ids = [
      "${lookup(var.sgs, "default")}" ]

  tags {
      Name        = "nomad-server-${var.cluster_name}-${format("%02d", count.index + 1)}-${var.env}.longtailvideo.com"
      CostCenter  = "${lookup(var.tag_map, "costcenter")}"
      Application = "${lookup(var.tag_map, "application")}"
      LTV-systype = "${lookup(var.tag_map, "LTV-systype")}"
      LTV-env     = "${var.env}"
  }
}

## Define dns records
resource "aws_route53_record" "nomad_server_dns" {
  count = "${var.nomad_server_count}"
  provider = "aws.dns"
  zone_id = "${var.route53zones["longtailvideo"]}"
  ttl = 300
  name = "nomad-server-${var.cluster_name}-${format("%02d", count.index + 1)}-${var.env}.longtailvideo.com"
  type = "CNAME"
  records = ["${element(aws_instance.nomad_server.*.private_ip, count.index)}"]
}

## Configure instances (must be done seperately in order to have acccess to computed variables)
resource "null_resource" "configure_nomad_server" {
  count = "${var.consul_server_count}"

  connection {
     user = "ubuntu"
     private_key = "${file("${var.ssh_key_path}")}"
     host = "${element(aws_instance.nomad_server.*.private_ip, count.index)}"
     timeout = "20m"
  }

  provisioner "file" {
    content = "${element(template_file.nomad_server_config.*.rendered, count.index)}"
    destination = "/tmp/nomad.json"
  }

  provisioner "file" {
    content = "${element(template_file.consul_client_config_nomad_server.*.rendered, count.index)}"
    destination = "/tmp/consul.json"
  }

  provisioner "file" {
    source = "files/nomad.conf"
    destination = "/tmp/nomad.conf"
  }

  provisioner "file" {
    source = "files/consul.conf"
    destination = "/tmp/consul.conf"
  }

  provisioner "remote-exec" {
    script = "files/install_consul.sh"
  }

  provisioner "remote-exec" {
    script = "files/install_nomad.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/nomad.json /etc/nomad.d/nomad.json",
      "sudo mv /tmp/consul.json /etc/consul.d/consul.json",
      "sudo mv /tmp/nomad.conf /etc/init/nomad.conf",
      "sudo mv /tmp/consul.conf /etc/init/consul.conf",
      "sudo start consul",
      "sudo start nomad"
    ]
  }
}

############ Nomad Client Configuration ##############

## Define template for nomad client
resource "template_file" "nomad_client_config" {
  count = "${var.nomad_client_count}"
  template = "${file("${path.module}/files/nomad_client.json")}"
  vars {
    nomad_instance_private_ip = "${element(aws_instance.nomad_client.*.private_ip, count.index)}"
    consul_token = "${var.consul_token}"
  }
}

resource "template_file" "consul_client_config_nomad_client" {
  count = "${var.nomad_client_count}"
  template = "${file("${path.module}/files/consul_client.json")}"
  vars {
    consul_instance_private_ip = "${element(aws_instance.nomad_client.*.private_ip, count.index)}"
    consul_private_ip_list = "${jsonencode(aws_instance.consul_server.*.private_ip)}"
  }
}

## Define instances
resource "aws_instance" "nomad_client" {
  ami = "${lookup(var.aws_amis, "trusty")}"
  count = "${var.nomad_client_count}"
  instance_type   = "${var.instance_type}"
  subnet_id           = "${lookup(var.subnets, "private-${lookup(var.zones, count.index % 4)}")}"
  key_name            = "${var.key_name}"
  vpc_security_group_ids = [
      "${lookup(var.sgs, "default")}" ]

  tags {
      Name        = "nomad-client-${var.cluster_name}-${format("%02d", count.index + 1)}-${var.env}.longtailvideo.com"
      CostCenter  = "${lookup(var.tag_map, "costcenter")}"
      Application = "${lookup(var.tag_map, "application")}"
      LTV-systype = "${lookup(var.tag_map, "LTV-systype")}"
      LTV-env     = "${var.env}"
  }
}

## Define dns records
resource "aws_route53_record" "nomad_client_dns" {
  count = "${var.nomad_client_count}"
  provider = "aws.dns"
  zone_id = "${var.route53zones["longtailvideo"]}"
  ttl = 300
  name = "nomad-client-${var.cluster_name}-${format("%02d", count.index + 1)}-${var.env}.longtailvideo.com"
  type = "CNAME"
  records = ["${element(aws_instance.nomad_client.*.private_ip, count.index)}"]
}

resource "null_resource" "configure_nomad_client" {
  count = "${var.nomad_client_count}"

  connection {
     user = "ubuntu"
     private_key = "${file("${var.ssh_key_path}")}"
     host = "${element(aws_instance.nomad_client.*.private_ip, count.index)}"
     timeout = "20m"
  }

  provisioner "file" {
    content = "${element(template_file.nomad_client_config.*.rendered, count.index)}"
    destination = "/tmp/nomad.json"
  }

  provisioner "file" {
    content = "${element(template_file.consul_client_config_nomad_client.*.rendered, count.index)}"
    destination = "/tmp/consul.json"
  }

  provisioner "file" {
    source = "files/nomad.conf"
    destination = "/tmp/nomad.conf"
  }

  provisioner "file" {
    source = "files/cgroupfs-mount"
    destination = "/tmp/cgroupfs-mount"
  }

  provisioner "file" {
    source = "files/consul.conf"
    destination = "/tmp/consul.conf"
  }

  provisioner "remote-exec" {
    script = "files/install_consul.sh"
  }

  provisioner "remote-exec" {
    script = "files/install_nomad.sh"
  }

  provisioner "remote-exec" {
    script = "files/install_docker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sh /tmp/cgroupfs-mount",
      "sudo mv /tmp/nomad.json /etc/nomad.d/nomad.json",
      "sudo mv /tmp/consul.json /etc/consul.d/consul.json",
      "sudo mv /tmp/nomad.conf /etc/init/nomad.conf",
      "sudo mv /tmp/consul.conf /etc/init/consul.conf",
      "sudo start consul",
      "sudo start nomad"
    ]
  }
}

output "consul_server_ips" {
  value = ["${aws_instance.consul_server.*.private_ip}"]
}

output "nomad_server_ips" {
  value = ["${aws_instance.nomad_server.*.private_ip}"]
}

output "nomad_client_ips" {
  value = ["${aws_instance.nomad_client.*.private_ip}"]
}
