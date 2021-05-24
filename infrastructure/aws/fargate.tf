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

// create execution role that our task needs to be able log correctly
resource "aws_iam_role" "execution_role" {
  name = "${var.app_name}-execution-role"
  tags = var.tags

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

// create ECS service 
resource "aws_ecs_task_definition" "task_definition" {
  family = "${var.app_name}-task"
  cpu = 256
  memory = 512
  tags = var.tags
  requires_compatibilities = [
    "FARGATE"
  ]
  network_mode = "awsvpc"
  execution_role_arn = aws_iam_role.execution_role.arn
  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = var.image
      cpu       = 0
      memory    = 512
      memoryReservation = 25
      mountPoints = []
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort = var.app_port
          protocol = "tcp"
        }
      ]
      environment = [
        {
          name = "PORT"
          value = tostring(var.app_port)
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

// create alb to be used for accessing service

resource "aws_lb" "alb" {
  name = "${var.app_name}-alb"
  internal = false
  subnets = aws_subnet.subnets.*.id
  tags = var.tags
}

resource "aws_lb_target_group" "alb_tg" {
  name = "${var.app_name}-alb-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.vpc.id
  target_type = "ip"
  tags = var.tags

  health_check {
    path = var.health_check_path
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  tags = var.tags
  default_action {
    target_group_arn = aws_lb_target_group.alb_tg.arn
    type = "forward"
  }
}

resource "aws_ecs_service" "service" {
  name = "${var.app_name}-service"
  cluster = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 3
  task_definition = aws_ecs_task_definition.task_definition.arn
  launch_type = "FARGATE"
  network_configuration {
    subnets = aws_subnet.subnets.*.id
    assign_public_ip = true
  }

  tags = var.tags
  enable_ecs_managed_tags = true

  load_balancer {
    target_group_arn = aws_lb_target_group.alb_tg.arn
    container_name = var.app_name
    container_port = var.app_port
  }
}