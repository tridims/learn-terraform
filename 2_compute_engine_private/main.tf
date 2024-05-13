# Configure the Google provider
provider "google" {
  # No need to specify credentials, Terraform will use the default credentials from gcloud
}

# Create a Google Cloud project
resource "google_project" "example_project" {
  name            = "example-bastion-ce"
  project_id      = "example-compute-83730"
  billing_account = "010E8C-466C1F-7FBD1D"
}

# Enable the necessary APIs for the project
resource "google_project_service" "compute_api" {
  project = google_project.example_project.project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "storage_api" {
  project = google_project.example_project.project_id
  service = "storage-api.googleapis.com"
}

// ================================================

# Create a custom VPC network
resource "google_compute_network" "example_network" {
  project                 = google_project.example_project.project_id
  name                    = "example-network"
  auto_create_subnetworks = false
}

# Create a subnet within the custom VPC network
resource "google_compute_subnetwork" "example_subnet" {

  project       = google_project.example_project.project_id
  name          = "example-subnet"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.example_network.self_link
  region        = "us-central1"
}

# Create a firewall rule to allow SSH access to the bastion host
resource "google_compute_firewall" "bastion_ssh" {

  project     = google_project.example_project.project_id
  name        = "allow-ssh-to-bastion"
  network     = google_compute_network.example_network.self_link
  target_tags = ["bastion"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Create a firewall rule to allow ICMP traffic within the VPC network
resource "google_compute_firewall" "allow_internal_icmp" {
  project = google_project.example_project.project_id
  name    = "allow-internal-icmp"
  network = google_compute_network.example_network.self_link

  allow {
    protocol = "icmp"
  }

  source_ranges = [google_compute_subnetwork.example_subnet.ip_cidr_range]
}

resource "google_compute_firewall" "allow_ssh_from_bastion" {
  project = google_project.example_project.project_id
  name    = "allow-ssh-from-bastion"
  network = google_compute_network.example_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
  target_tags = ["private"]
}

// ================================================

# Create the bastion host VM
resource "google_compute_instance" "bastion" {

  project      = google_project.example_project.project_id
  name         = "bastion"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.example_subnet.self_link
    access_config {
      // Ephemeral IP for external access
    }
  }

  tags = ["bastion"]

  metadata_startup_script = "sudo apt-get update && sudo apt-get install -y curl"
}

# Create an SSH key pair on the bastion host
resource "null_resource" "generate_ssh_key" {
  depends_on = [google_compute_instance.bastion]

  provisioner "local-exec" {
    command = <<-EOT
      gcloud compute ssh dimas@${google_compute_instance.bastion.name} --zone ${google_compute_instance.bastion.zone} --command "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"
      gcloud compute ssh dimas@${google_compute_instance.bastion.name} --zone ${google_compute_instance.bastion.zone} --command "cat ~/.ssh/id_rsa.pub" > bastion_public_key.txt
    EOT
  }
}

# Retrieve the generated public key
data "local_file" "bastion_public_key" {
  depends_on = [null_resource.generate_ssh_key]
  filename   = "bastion_public_key.txt"
}

# Create the private VM 1
resource "google_compute_instance" "private_vm_1" {

  project      = google_project.example_project.project_id
  name         = "private-vm-1"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.example_subnet.self_link
    # No external IP address
  }

  tags = ["private"]
  metadata = {
    ssh-keys = "dimas:${data.local_file.bastion_public_key.content}"
  }
}

# Create the private VM 2
resource "google_compute_instance" "private_vm_2" {

  project      = google_project.example_project.project_id
  name         = "private-vm-2"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.example_subnet.self_link
    # No external IP address
  }

  tags = ["private"]
  metadata = {
    ssh-keys = "dimas:${data.local_file.bastion_public_key.content}"
  }
}
