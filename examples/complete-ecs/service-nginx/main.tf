resource "aws_cloudwatch_log_group" "nginx" {
  name              = "nginx"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "nginx" {
  family = "nginx"

  container_definitions = <<EOF
[
  {
    "name": "nginx",
    "image": "nginx",
    "cpu": 0,
    "memory": 128,
    "portMappings": [
      {
        "containerPort": 80
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "ap-southeast-2",
        "awslogs-group": "nginx",
        "awslogs-stream-prefix": "complete-ecs"
      }
    }
  }
]
EOF
}

### Security

resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = var.vpc_id
  name   = "tf-ecs-lbsg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

### ALB
resource "aws_alb_target_group" "main" {
  name     = "main-alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_alb" "main" {
  name            = "main-alb"
  subnets         = var.public_subnets
  security_groups = [aws_security_group.lb_sg.id]
}

resource "aws_alb_listener" "nginx" {
  load_balancer_arn = aws_alb.main.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }
}

### ECS Service

resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.nginx.arn

  load_balancer {
    target_group_arn = aws_alb_target_group.main.id
    container_name   = "nginx"
    container_port   = "80"
  }

  desired_count = 2

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  depends_on = [aws_alb_target_group.main]
}
