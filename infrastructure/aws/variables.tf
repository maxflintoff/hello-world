// define region used for deployments
// can be set with environment variable AWS_DEFAULT_REGION
variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

// define cidr block to be used for the VPC
variable "cidr_block" {
    type = string
    default = "172.31.0.0/16"
}

//tags to apply to the resources created
variable "tags" {
    type = map
    default = {
        app = "hello-world"
    }
}

//generic app name used to name resources
variable "app_name" {
    type = string
    default = "hello-world"
}