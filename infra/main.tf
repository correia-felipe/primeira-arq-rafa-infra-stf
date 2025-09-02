locals {
  name_prefix = "${var.project}-${var.env}"
}

# ---- IAM SFN ----
resource "aws_iam_role" "sfn_exec" {
  name               = "${local.name_prefix}-sfn-exec"
  assume_role_policy = file("${path.module}/../policy/stepfunction_assume_role.json")
}

resource "aws_iam_role_policy" "sfn_exec_policy" {
  name   = "${local.name_prefix}-sfn-exec-policy"
  role   = aws_iam_role.sfn_exec.id
  policy = file("${path.module}/../policy/state_machine_execution_policy.json")
}

# ---- State Machine (templating dos nomes dos jobs) ----
data "template_file" "asl" {
  template = file("${path.module}/../src/stf_definition.asl.json")
  vars = {
    glue_job_a = var.glue_job_a
    glue_job_b = var.glue_job_b
  }
}

resource "aws_sfn_state_machine" "ingestion_router" {
  name       = "${local.name_prefix}-ingestion-router"
  role_arn   = aws_iam_role.sfn_exec.arn
  definition = data.template_file.asl.rendered
}

# ---- EventBridge: Regra S3:ObjectCreated filtrando o bucket ----
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${local.name_prefix}-s3-objectcreated"
  description = "Dispara Step Functions quando objeto é criado no S3 incoming"
  event_pattern = jsonencode({
    "source"      : ["aws.s3"],
    "detail-type" : ["Object Created"],
    "detail" : {
      "bucket" : { "name" : [var.incoming_bucket_name] }
    }
  })
}

# Role para o EventBridge iniciar a State Machine
resource "aws_iam_role" "events_to_sfn" {
  name = "${local.name_prefix}-events-to-sfn"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "events.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "events_to_sfn_policy" {
  name = "${local.name_prefix}-events-to-sfn-policy"
  role = aws_iam_role.events_to_sfn.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "states:StartExecution",
      Resource = aws_sfn_state_machine.ingestion_router.arn
    }]
  })
}

# ---- Target com Input Transformer (manda somente bucket e key) ----
resource "aws_cloudwatch_event_target" "to_sfn" {
  rule     = aws_cloudwatch_event_rule.s3_object_created.name
  arn      = aws_sfn_state_machine.ingestion_router.arn
  role_arn = aws_iam_role.events_to_sfn.arn

  input_transformer {
    # Mapeia os campos do evento S3
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }

    # IMPORTANTE: não usar jsonencode aqui; não colocar aspas nos placeholders
    input_template = <<EOT
{"bucket": <bucket>, "key": <key>}
EOT
  }
}
