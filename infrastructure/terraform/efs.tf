resource "aws_efs_file_system" "main" {
  creation_token                  = "${var.project_name}-efs"
  performance_mode                = "generalPurpose"
  throughput_mode                 = "bursting"
  encrypted                       = true
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-efs"
  })
}

resource "aws_efs_mount_target" "main" {
  count           = 2
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from ECS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-efs-sg"
  })
}

resource "aws_efs_access_point" "workspace" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 0
    uid = 0
  }

  root_directory {
    path = "/workspace"
    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = "755"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-workspace-ap"
  })
}

