# ---------------------------------------------------------------------------------------------------------------------
# Elastic Container Service
# ---------------------------------------------------------------------------------------------------------------------

# ECS Cluster

resource "aws_ecs_cluster" "aws_ecs_cluster" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECS Task

data "template_file" "template_file_fargate" {
  template = file("./templates/fargate/ContainerDefinition.json")
  vars = {
    family            = var.family
    image             = aws_ecr_repository.aws_ecr_repository.repository_url
    fargate_cpu       = tonumber(var.fargate_cpu)
    fargate_memory    = tonumber(var.fargate_memory)
    container_port    = tonumber(var.container_port)
    database_username = var.database_username
    database_password = data.aws_ssm_parameter.dbpassword.value
    database_profile  = aws_db_instance.aws_db_instance.engine
    database_address  = aws_db_instance.aws_db_instance.address
    database_name     = var.family
    cw_log_group      = var.cw_log_group
    cw_log_stream     = var.cw_log_stream
    aws_region        = data.aws_region.current.name
  }
}

resource "aws_iam_role" "aws_iam_role_fargate" {
  name               = "ECSTasksServiceRole"
  assume_role_policy = file("./templates/fargate/AssumeRole.json")
  tags               = merge(local.common_tags, local.workspace)
}

resource "aws_iam_role_policy_attachment" "tasks-service-role-attachment" {
  role       = aws_iam_role.aws_iam_role_fargate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "aws_ecs_task_definition" {
  family                   = var.family
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.aws_iam_role_fargate.arn
  container_definitions    = data.template_file.template_file_fargate.rendered
}

resource "aws_ecs_service" "aws_ecs_service" {
  name                              = var.project_name
  cluster                           = aws_ecs_cluster.aws_ecs_cluster.id
  task_definition                   = aws_ecs_task_definition.aws_ecs_task_definition.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  scheduling_strategy               = "REPLICA"
  health_check_grace_period_seconds = 300

  network_configuration {
    security_groups = [aws_security_group.aws_security_group_ecs.id]
    subnets = [aws_subnet.aws_subnet_private["A"].id,
    aws_subnet.aws_subnet_private["B"].id]
    assign_public_ip = false # If you have a Fargate task in a public subnet, then verify that your task has an assigned public IP address
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.aws_lb_target_group_blue.arn
    container_name   = var.family
    container_port   = var.container_port
  }

  # Here green TG is considered as a replacement to production. Need NOT be spcified here. We have already specified in Codedeploy resource.
  # load_balancer {
  #   target_group_arn = aws_lb_target_group.aws_lb_target_group_green.arn
  #   container_name   = var.family
  #   container_port   = var.container_port
  # }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  depends_on = [aws_lb_listener.aws_lb_listener_blue, aws_lb_listener.aws_lb_listener_green]

  lifecycle {
    ignore_changes = [
      load_balancer,
      desired_count,
      task_definition
    ]
  }
}

# Cloudwatch Log Group

resource "aws_cloudwatch_log_group" "aws_cloudwatch_log_group" {
  name = var.cw_log_group
}