# Configure the Google provider
provider "google" {
  # No need to specify credentials, Terraform will use the default credentials from gcloud
}

# Create a Google Cloud project
resource "google_project" "example_project" {
  name       = "example-project"
  project_id = "example-compute-83729"
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

# Create a Compute Engine instance in the project
resource "google_compute_instance" "example_instance" {
  project      = google_project.example_project.project_id
  name         = "example-instance"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  depends_on = [
    google_project_service.compute_api,
    google_project_service.storage_api
  ]
}
