// Initialise terraform instance with aws provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

// Configure the AWS Provider
// Authentication should be configured with environment variables: AWS_SECRET_ACCESS_KEY, AWS_ACCESS_KEY_ID 
provider "aws" {
  region = var.aws_region
}

// create a VPC
resource "aws_vpc" "vpc" {

    cidr_block = var.cidr_block

    // append our tags variable with a name related to our application
    tags = merge({
        Name = "${var.app_name}-vpc"
    }, var.tags)
}

// Load AZ information
data "aws_availability_zones" "available" {
  state = "available"
}


// create subnets
resource "aws_subnet" "subnets" {
    // create one per availability zone as loaded in previous data source
    count = length(data.aws_availability_zones.available.names)

    vpc_id = aws_vpc.vpc.id
    availability_zone = data.aws_availability_zones.available.names[count.index]
    cidr_block  = cidrsubnet(aws_vpc.vpc.cidr_block, 4, count.index)
    tags = merge({
        Name = "${var.app_name}-subnet-${data.aws_availability_zones.available.names[count.index]}"
    }, var.tags)
}

// create internet gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id

    tags = merge({
        Name = "${var.app_name}-vpc-igw"
    }, var.tags)
}

// create route table
resource "aws_route_table" "route_table" {
    vpc_id = aws_vpc.vpc.id
    
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = merge({
        Name = "${var.app_name}-vpc-rt"
    }, var.tags)
}

// associate vpc with route table
resource "aws_main_route_table_association" "route_table_association" {
    vpc_id = aws_vpc.vpc.id
    route_table_id = aws_route_table.route_table.id
}

// create ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {

    name = "${var.app_name}-ecs"
    tags = var.tags
}

//TODO iam

// create ECS service 
resource "aws_ecs_task_definition" "service" {
  family = "${var.app_name}-task"
  cpu = 256
  memory = 512
  tags = var.tags
  requires_compatibilities = [
    "FARGATE"
  ]
  network_mode = "awsvpc"
  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = "465310043917.dkr.ecr.eu-west-2.amazonaws.com/hello-world-nodejs:latest"
      cpu       = 0
      memory    = 512
      memoryReservation = 25
      mountPoints = []
      essential = true
      portMappings = [
        {
          containerPort = 8888
          hostPort = 8888
          protocol = "tcp"
        }
      ]
      environment = [
        {
          name = "PORT"
          value = "8888"
        }
      ]
      healthCheck       = {
        command     = [
          "\"CMD-SHELL\"",
          "\"curl -f http://localhost:8888/health || exit 1\"",
        ]
        interval = 5
        retries = 3
        startPeriod = 5
        timeout = 5
        }
      volumesFrom = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
            awslogs-group = "/ecs/${var.app_name}-task"
            awslogs-region = var.aws_region
            awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}