variable region {
  default = "us-central1"
}

provider google {
  region = "${var.region}"
}

variable backend_bucket {}

module "gce-lb-http" {
  source         = "github.com/danisla/terraform-google-lb-http"
  name           = "group-http-lb"
  target_tags    = ["${module.mig1.target_tags}", "${module.mig2.target_tags}", "${module.mig3.target_tags}"]
  url_map        = "${google_compute_url_map.my-url-map.self_link}"
  create_url_map = false
  ssl            = true
  private_key    = "${file("./example.key")}"
  certificate    = "${file("./example.crt")}"

  backends = {
    "0" = [
      {
        group = "${module.mig1.instance_group}"
      },
      {
        group = "${module.mig2.instance_group}"
      },
      {
        group = "${module.mig3.instance_group}"
      },
    ]

    "1" = [
      {
        group = "${module.mig1.instance_group}"
      },
    ]

    "2" = [
      {
        group = "${module.mig2.instance_group}"
      },
    ]

    "3" = [
      {
        group = "${module.mig3.instance_group}"
      },
    ]
  }

  backend_params = [
    // health check path, port name, port number, timeout seconds.
    "/,${module.mig1.service_port_name},${module.mig1.service_port},10",

    "/,${module.mig1.service_port_name},${module.mig1.service_port},10",
    "/,${module.mig2.service_port_name},${module.mig2.service_port},10",
    "/,${module.mig3.service_port_name},${module.mig3.service_port},10",
  ]
}

resource "google_compute_url_map" "my-url-map" {
  // note that this is the name of the load balancer
  name            = "my-url-map"
  default_service = "${module.gce-lb-http.backend_services[0]}"

  host_rule = {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher = {
    name            = "allpaths"
    default_service = "${module.gce-lb-http.backend_services[0]}"

    path_rule {
      paths   = ["/group1", "/group1/*"]
      service = "${module.gce-lb-http.backend_services[1]}"
    }

    path_rule {
      paths   = ["/group2", "/group2/*"]
      service = "${module.gce-lb-http.backend_services[2]}"
    }

    path_rule {
      paths   = ["/group3", "/group3/*"]
      service = "${module.gce-lb-http.backend_services[3]}"
    }

    path_rule {
      paths   = ["/assets", "/assets/*"]
      service = "${google_compute_backend_bucket.assets.self_link}"
    }
  }
}

resource "google_compute_backend_bucket" "assets" {
  name        = "${var.backend_bucket}"
  description = "Contains static resources for example app"
  bucket_name = "${google_storage_bucket.assets.name}"
  enable_cdn  = true
}

resource "google_storage_bucket" "assets" {
  name     = "${var.backend_bucket}"
  location = "US"

  // delete bucket and contents on destroy.
  force_destroy = true
}

// The image object in Cloud Storage.
// Note that the path in the bucket matches the paths in the url map path rule above.
resource "google_storage_bucket_object" "image" {
  name         = "assets/gcp-logo.svg"
  content      = "${file("gcp-logo.svg")}"
  content_type = "image/svg+xml"
  bucket       = "${google_storage_bucket.assets.name}"
}

// Make object public readable.
resource "google_storage_object_acl" "image-acl" {
  bucket         = "${google_storage_bucket.assets.name}"
  object         = "${google_storage_bucket_object.image.name}"
  predefined_acl = "publicread"
}
