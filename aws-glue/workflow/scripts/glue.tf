resource "aws_s3_bucket" "journey-recommendations-unload-scripts" {
  bucket = "${lower(var.environment_tag)}-journey-recommendations-unload-scripts"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-recommendations-unload-scripts"), local.common_tags)}"
}

resource "aws_s3_bucket_policy" "journey-recommendations-unload-scripts-policy" {
  bucket = "${aws_s3_bucket.journey-recommendations-unload-scripts.id}"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "PersonalizeS3BucketAccessPolicy",
    "Statement": [
        {
            "Sid": "PersonalizeS3BucketAccessPolicy",
            "Effect": "Allow",
            "Principal": {
                "Service": "glue.amazonaws.com"
            },
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "${aws_s3_bucket.journey-recommendations-unload-scripts.arn}",
                "${aws_s3_bucket.journey-recommendations-unload-scripts.arn}/*"
            ]
        }
    ]
}
POLICY
}

resource "aws_s3_bucket" "journey-recommendations-input-data" {
  bucket = "${lower(var.environment_tag)}-journey-recommendations-input-data"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-recommendations-input-data"), local.common_tags)}"
}

resource "aws_s3_bucket_policy" "journey-recommendations-unload-data-policy" {
  bucket = "${aws_s3_bucket.journey-recommendations-input-data.id}"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "PersonalizeS3BucketAccessPolicy",
    "Statement": [
        {
            "Sid": "PersonalizeS3BucketAccessPolicy",
            "Effect": "Allow",
            "Principal": {
                "Service": "personalize.amazonaws.com"
            },
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "${aws_s3_bucket.journey-recommendations-input-data.arn}",
                "${aws_s3_bucket.journey-recommendations-input-data.arn}/*"
            ]
        },
        {
            "Sid": "GlueS3BucketAccessPolicy",
            "Effect": "Allow",
            "Principal": {
                "Service": "glue.amazonaws.com"
            },
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "${aws_s3_bucket.journey-recommendations-input-data.arn}",
                "${aws_s3_bucket.journey-recommendations-input-data.arn}/*"
            ]
        }
    ]
}
POLICY
}

resource "aws_vpc_endpoint" "journey-recommendations-unload-s3-vpc-endpoint" {
  vpc_id       = "${var.vpc_id}"
  service_name = "com.amazonaws.us-east-1.s3"
  tags         = "${merge(map("Name", "${lower(var.environment_tag)}-journey-recommendations-unload-s3-vpc-endpoint"), local.common_tags)}"
}

resource "aws_iam_role" "journey-recommendations-unload-glue-role" {
  name = "${lower(var.environment_tag)}-AWSGlueServiceRoleDefault"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "journey-recommendations-unload-glue_service-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  role       = "${aws_iam_role.journey-recommendations-unload-glue-role.id}"
}

resource "aws_iam_role_policy_attachment" "journey-recommendations-unload-glue-service-attachment-redshift" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess"
  role       = "${aws_iam_role.journey-recommendations-unload-glue-role.id}"
}

resource "aws_iam_role_policy_attachment" "journey-recommendations-unload-glue-service-attachment-rds" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRdsFullAccess"
  role       = "${aws_iam_role.journey-recommendations-unload-glue-role.id}"
}

resource "aws_iam_role_policy" "journey-recommendations-unload-s3-policy" {
  name = "${lower(var.environment_tag)}-s3_policy"
  role = "${aws_iam_role.journey-recommendations-unload-glue-role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.journey-recommendations-input-data.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.journey-recommendations-input-data.bucket}/*",
         "arn:aws:s3:::${aws_s3_bucket.journey-recommendations-unload-scripts.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.journey-recommendations-unload-scripts.bucket}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "journey-recommendations-unload-glue-service-s3" {
  name   = "glue_service_s3"
  role   = "${aws_iam_role.journey-recommendations-unload-glue-role.id}"
  policy = "${aws_iam_role_policy.journey-recommendations-unload-s3-policy.policy}"
}

resource "aws_glue_catalog_database" "journey-recommendations-catalog-database" {
  name = "${lower(var.environment_tag)}-journey-recommendations-catalog-database"
}

resource "aws_glue_connection" "journey-ima-connection" {
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${data.aws_redshift_cluster.ima_cluster.endpoint}:5439/${data.aws_redshift_cluster.ima_cluster.database_name}"

    PASSWORD = "${var.ima_redshift_database_password}"
    USERNAME = "${var.ima_redshift_database_username}"
  }

  name = "${lower(var.environment_tag)}-journey-ima-connection"

  physical_connection_requirements {
    availability_zone = "${data.aws_subnet.glue_connect_ima_subnet.availability_zone}"

    security_group_id_list = [
      "${data.aws_security_group.ima_sg.id}",
    ]

    subnet_id = "${var.ima_cluster_subnet_id}"
  }
}

//variable "genesis_db_instance_identifier" {default=}
//variable "genesis_db_instance_identifier" {defqult=}
//data "aws_db_instance" "genesis_rds" {
//  db_instance_identifier = "${var.genesis_db_instance_identifier}"
//}

//data "aws_rds_cluster" "genesis_cluster" {
//  cluster_identifier = "${var.genesis_cluster_identifier}"
//}


resource "aws_glue_connection" "journey-genesis-postgres-connection" {
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://${data.aws_db_instance.genesis_rds.endpoint}/${var.genesis_db_name}"
    PASSWORD            = "${var.genesis_postgres_database_password}"
    USERNAME            = "${var.genesis_postgres_database_username}"
  }

  name = "${lower(var.environment_tag)}-journey-genesis-postgres-connection"

  physical_connection_requirements {
    availability_zone = "${data.aws_subnet.glue_connect_genesis_subnet.availability_zone}"

    security_group_id_list = [
      "${data.aws_security_group.genesis_sg.id}",
    ]

    subnet_id = "${var.genesis_db_subnet_id}"
  }
}

resource "aws_glue_crawler" "journey-ima-redshift-crawler" {
  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
  name          = "${lower(var.environment_tag)}-journey-ima-redshift-crawler"

  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"

  jdbc_target = [
    {
      connection_name = "${aws_glue_connection.journey-ima-connection.name}"
      path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/fct_member_activity"
    },
    {
      connection_name = "${aws_glue_connection.journey-ima-connection.name}"
      path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/fct_member_journey_step"
    },
    {
      connection_name = "${aws_glue_connection.journey-ima-connection.name}"
      path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/dim_scd1_member"
    },
    {
      connection_name = "${aws_glue_connection.journey-ima-connection.name}"
      path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/dim_scd1_tracker"
    },
    {
      connection_name = "${aws_glue_connection.journey-ima-connection.name}"
      path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/dim_thrive_category"
    },
    {
      connection_name = "${aws_glue_connection.journey-ima-connection.name}"
      path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/dim_journey"
    },
  ]

  provisioner "local-exec" {
    command = "aws glue start-crawler --name ${self.name} --region ${data.aws_region.current.name}"
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-ima-redshift-crawler"), local.common_tags)}"
}

//resource "aws_glue_crawler" "journey-ima-member-activity-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-ima-member-activity-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target = [
//    {
//      connection_name = "${aws_glue_connection.journey-ima-connection.name}"
//      path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/fct_member_activity"
//    },
//  ]
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-ima-member-activity-crawler"), local.common_tags)}"
//}
//
//resource "aws_glue_crawler" "journey-ima-member-journey-step-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-ima-member-journey-step-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target {
//    connection_name = "${aws_glue_connection.journey-ima-connection.name}"
//    path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/fct_member_journey_step"
//  }
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-ima-member-journey-step-crawler"), local.common_tags)}"
//}
//
//resource "aws_glue_crawler" "journey-ima-member-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-ima-member-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target {
//    connection_name = "${aws_glue_connection.journey-ima-connection.name}"
//    path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/dim_scd1_member"
//  }
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-ima-member-crawler"), local.common_tags)}"
//}
//
//resource "aws_glue_crawler" "journey-ima-tracker-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-ima-tracker-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target {
//    connection_name = "${aws_glue_connection.journey-ima-connection.name}"
//    path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/dim_scd1_tracker"
//  }
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-ima-tracker-crawler"), local.common_tags)}"
//}
//
//resource "aws_glue_crawler" "journey-ima-thrive-category-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-ima-thrive-category-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target {
//    connection_name = "${aws_glue_connection.journey-ima-connection.name}"
//    path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/dim_thrive_category"
//  }
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-ima-thrive-category-crawler"), local.common_tags)}"
//}
//
//resource "aws_glue_crawler" "journey-ima-journey-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-ima-journey-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target {
//    connection_name = "${aws_glue_connection.journey-ima-connection.name}"
//    path            = "${data.aws_redshift_cluster.ima_cluster.database_name}/${var.ima_dw_scheme_name}/dim_journey"
//  }
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-ima-journey-crawler"), local.common_tags)}"
//}

resource "aws_glue_crawler" "journey-genesis-postgres-crawler" {
  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
  name          = "${lower(var.environment_tag)}-journey-genesis-postgres-action-activities-crawler"

  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"

  jdbc_target = [
    {
      connection_name = "${aws_glue_connection.journey-genesis-postgres-connection.name}"
      path = "${data.aws_db_instance.genesis_rds.db_name}/${var.genesis_scheme_name}/action_activities"
    },
    {
      connection_name = "${aws_glue_connection.journey-genesis-postgres-connection.name}"
      path = "${data.aws_db_instance.genesis_rds.db_name}/${var.genesis_scheme_name}/action"
    },
    {
      connection_name = "${aws_glue_connection.journey-genesis-postgres-connection.name}"
      path = "${data.aws_db_instance.genesis_rds.db_name}/${var.genesis_scheme_name}/tracker"
    },
    {
      connection_name = "${aws_glue_connection.journey-genesis-postgres-connection.name}"
      path = "${data.aws_db_instance.genesis_rds.db_name}/${var.genesis_scheme_name}/thrive_category"
    }

  ]

  provisioner "local-exec" {
    command = "aws glue start-crawler --name ${self.name}  --region ${data.aws_region.current.name}"
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-genesis-postgres-crawler"), local.common_tags)}"
}

//resource "aws_glue_crawler" "journey-genesis-postgres-action-activities-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-genesis-postgres-action-activities-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target {
//    connection_name = "${aws_glue_connection.journey-genesis-postgres-connection.name}"
//    path            = "genesis/public/action_activities"
//  }
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-genesis-postgres-action-activities-crawler"), local.common_tags)}"
//}
//
//resource "aws_glue_crawler" "journey-genesis-postgres-action-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-genesis-postgres-action-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target {
//    connection_name = "${aws_glue_connection.journey-genesis-postgres-connection.name}"
//    path            = "genesis/public/action"
//  }
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-genesis-postgres-action-crawler"), local.common_tags)}"
//}
//
//resource "aws_glue_crawler" "journey-genesis-postgres-tracker-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-genesis-postgres-tracker-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target {
//    connection_name = "${aws_glue_connection.journey-genesis-postgres-connection.name}"
//    path            = "genesis/public/tracker"
//  }
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-genesis-postgres-tracker-crawler"), local.common_tags)}"
//}
//
//resource "aws_glue_crawler" "journey-genesis-postgres-thrive-category-crawler" {
//  database_name = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
//  name          = "${lower(var.environment_tag)}-journey-genesis-postgres-thrive-category-crawler"
//
//  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
//  role = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"
//
//  jdbc_target {
//    connection_name = "${aws_glue_connection.journey-genesis-postgres-connection.name}"
//    path            = "genesis/public/thrive_category"
//  }
//
//  provisioner "local-exec" {
//    command = "aws glue start-crawler --name ${self.name}"
//  }
//
//  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-genesis-postgres-thrive-category-crawler"), local.common_tags)}"
//}

//https://github.com/terraform-providers/terraform-provider-aws/issues/9524

resource "aws_glue_job" "journey-recommendations-unload-hh-list-job" {
  name     = "${lower(var.environment_tag)}-journey-recommendations-unload-hh-list-job"
  role_arn = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"

  connections = [
    "${aws_glue_connection.journey-genesis-postgres-connection.name}",
    "${aws_glue_connection.journey-ima-connection.name}",
  ]

  glue_version = "${var.glue_version}"
  max_capacity = "${var.glue_max_capacity}"

  command {
    script_location = "s3://${aws_s3_bucket.journey-recommendations-unload-scripts.bucket}/get_hh_list.py"
  }

  default_arguments = {
    "--enable-metrics"                   = ""
    "--job-language"                     = "python"
    "--TempDir"                          = "${aws_s3_bucket.journey-recommendations-unload-scripts.bucket}/TEMP"
    "--HH_LIST_OUTPUT_CSV_FILENAME"      = "${var.healthy_habit_list_filename}"
    "--HH_LIST_CSV_OUTPUT_BUCKET"        = "${aws_s3_bucket.journey-recommendations-input-data.bucket}"
    "--HH_LIST_CSV_OUTPUT_BUCKET_PREFIX" = "${var.healthy_habit_list_bucket_prefix}"
    "--HH_GLUE_JOURNEY_CATALOG_DB_NAME"  = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
    "--GENESIS_POSTGRES_DATABASE_NAME"   = "${var.genesis_db_name}"
    "--GENESIS_POSTGRES_DATABASE_SCHEME" = "public"
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-recommendations-unload-hh-list-job"), local.common_tags)}"
}

resource "aws_glue_job" "journey-recommendations-unload-hh-items-job" {
  name     = "${lower(var.environment_tag)}-journey-recommendations-unload-hh-items-job"
  role_arn = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"

  connections = [
    "${aws_glue_connection.journey-genesis-postgres-connection.name}",
    "${aws_glue_connection.journey-ima-connection.name}",
  ]

  glue_version = "${var.glue_version}"
  max_capacity = "${var.glue_max_capacity}"

  command {
    script_location = "s3://${aws_s3_bucket.journey-recommendations-unload-scripts.bucket}/unload_hh_items.py"
  }

  default_arguments = {
    "--enable-metrics"                    = ""
    "--job-language"                      = "python"
    "--TempDir"                           = "s3://${aws_s3_bucket.journey-recommendations-unload-scripts.bucket}/TEMP"
    "--HH_LIST_CSV_FILENAME"              = "${var.healthy_habit_list_filename}"
    "--HH_LIST_INPUT_CSV_BUCKET"          = "${aws_s3_bucket.journey-recommendations-input-data.bucket}"
    "--HH_LIST_INPUT_CSV_BUCKET_PREFIX"   = "${var.healthy_habit_list_bucket_prefix}"
    "--HH_ITEMS_CSV_FILENAME"             = "items_hh.csv"
    "--HH_ITEMS_CSV_OUTPUT_BUCKET"        = "${aws_s3_bucket.journey-recommendations-input-data.bucket}"
    "--HH_ITEMS_CSV_OUTPUT_BUCKET_PREFIX" = "items/hh"
    "--HH_GLUE_JOURNEY_CATALOG_DB_NAME"   = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
    "--IMA_DATABASE_NAME"                 = "${data.aws_redshift_cluster.ima_cluster.database_name}"
    "--IMA_DATABASE_SCHEME"               = "dw"
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-recommendations-unload-hh-items-job"), local.common_tags)}"
}

resource "aws_glue_job" "journey-recommendations-unload-hh-interactions-job" {
  name     = "${lower(var.environment_tag)}-journey-recommendations-unload-hh-interactions-job"
  role_arn = "${aws_iam_role.journey-recommendations-unload-glue-role.arn}"

  connections = [
    "${aws_glue_connection.journey-genesis-postgres-connection.name}",
    "${aws_glue_connection.journey-ima-connection.name}",
  ]

  glue_version = "${var.glue_version}"
  max_capacity = "${var.glue_max_capacity}"

  command {
    script_location = "s3://${aws_s3_bucket.journey-recommendations-unload-scripts.bucket}/unload_hh_interactions.py"
  }

  default_arguments = {
    "--enable-metrics"                           = ""
    "--job-language"                             = "python"
    "--TempDir"                                  = "s3://${aws_s3_bucket.journey-recommendations-unload-scripts.bucket}/TEMP"
    "--HH_LIST_CSV_FILENAME"                     = "${var.healthy_habit_list_filename}"
    "--HH_LIST_CSV_BUCKET"                       = "${aws_s3_bucket.journey-recommendations-input-data.bucket}"
    "--HH_LIST_CSV_BUCKET_PREFIX"                = "${var.healthy_habit_list_bucket_prefix}"
    "--HH_MEMBER_INTERACTIONS_CSV_FILENAME"      = "hh_interactions.csv"
    "--HH_MEMBER_INTERACTIONS_CSV_BUCKET"        = "${aws_s3_bucket.journey-recommendations-input-data.bucket}"
    "--HH_MEMBER_INTERACTIONS_CSV_BUCKET_PREFIX" = "interactions/hh"
    "--HH_GLUE_JOURNEY_CATALOG_DB_NAME"          = "${aws_glue_catalog_database.journey-recommendations-catalog-database.name}"
    "--IMA_DATABASE_NAME"                        = "${data.aws_redshift_cluster.ima_cluster.database_name}"
    "--IMA_DATABASE_SCHEME"                      = "dw"
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-recommendations-unload-hh-interactions-job"), local.common_tags)}"
}

resource "aws_glue_workflow" "journey-recommendations-unload-train-data" {
  name = "${lower(var.environment_tag)}-journey-recommendations-unload-train-data"
}

resource "aws_glue_trigger" "journey-recommendations-trigger-hh-list" {
  name = "${lower(var.environment_tag)}-journey-recommendations-trigger-hh-list"

  # schedule = "cron(0 15 10 ? * 6L)"
  # At 10:15:00am, the last Friday of the month, every month
  # type     = "SCHEDULED"
  type = "ON_DEMAND"

  workflow_name = "${aws_glue_workflow.journey-recommendations-unload-train-data.name}"

  actions {
    job_name = "${aws_glue_job.journey-recommendations-unload-hh-list-job.name}"
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-recommendations-trigger-hh-list"), local.common_tags)}"
}

resource "aws_glue_trigger" "journey-recommendations-unload-trigger-hh-items" {
  name          = "${lower(var.environment_tag)}-journey-recommendations-unload-trigger-hh-items"
  type          = "CONDITIONAL"
  workflow_name = "${aws_glue_workflow.journey-recommendations-unload-train-data.name}"

  predicate {
    conditions {
      job_name = "${aws_glue_job.journey-recommendations-unload-hh-list-job.name}"
      state    = "SUCCEEDED"
    }
  }

  actions {
    job_name = "${aws_glue_job.journey-recommendations-unload-hh-items-job.name}"
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-recommendations-unload-trigger-hh-items"), local.common_tags)}"
}

resource "aws_glue_trigger" "journey-recommendations-unload-trigger-hh-interactions" {
  name          = "${lower(var.environment_tag)}-journey-recommendations-unload-trigger-hh-interactions"
  type          = "CONDITIONAL"
  workflow_name = "${aws_glue_workflow.journey-recommendations-unload-train-data.name}"

  predicate {
    conditions {
      job_name = "${aws_glue_job.journey-recommendations-unload-hh-items-job.name}"
      state    = "SUCCEEDED"
    }
  }

  actions {
    job_name = "${aws_glue_job.journey-recommendations-unload-hh-interactions-job.name}"
  }

  tags = "${merge(map("Name",  "${lower(var.environment_tag)}-journey-recommendations-unload-trigger-hh-interactions"), local.common_tags)}"
}

resource "aws_lambda_function" "triggerstatemachinejob" {
  s3_bucket     = "${aws_s3_bucket.personalize-lambda.bucket}"
  s3_key        = "triggerstatemachinejob.zip"
  function_name = "${lower(var.environment_tag)}-triggerstatemachinejob"
  description   = "trigger state machine job with input json"
  handler       = "triggerstatemachinejob.lambda_handler"
  runtime       = "python3.7"

  kms_key_arn = "${data.aws_kms_key.env-kms.arn}"
  role        = "${aws_iam_role.personalize-lambda-role.arn}"
  timeout     = 30
  memory_size = 128

  vpc_config {
    subnet_ids = [
      "${data.aws_subnet_ids.lambda-subnet-ids.ids}",
    ]

    security_group_ids = [
      "${data.aws_security_group.personalize_triggerstatemachine_lambda_sg.id}",
    ]
  }

  environment {
    variables = {
      ENV                = "${upper(var.environment_tag)}"
      S3_BUCKET_NAME     = "${aws_s3_bucket.state-machine-journey-input.bucket}"
      S3_FILE_KEY        = "${lower(var.environment_tag)}.json"
      STATE_MACHINE_NAME = "${aws_sfn_state_machine.personalize-state-machine.name}"
    }
  }

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-triggerstatemachinejob"), local.common_tags)}"
}

resource "aws_cloudwatch_event_rule" "journey-recommendations-worflow-trigger-lambda-rule" {
  name        = "${lower(var.environment_tag)}-journey-recommendations-worflow-trigger-lambda-rule"
  description = "Trigger personalize statemachine upon glue workflow completion"

  event_pattern = <<EOF
{
  "source": [ "aws.glue" ],
  "detail-type": ["Glue Job State Change"],
  "detail": {
    "jobName": ["${aws_glue_job.journey-recommendations-unload-hh-interactions-job.name}"],
    "state": [ "SUCCEEDED" ]
  }
}
EOF

  tags = "${merge(map("Name", "${lower(var.environment_tag)}-journey-recommendations-worflow-trigger-lambda-rule"), local.common_tags)}"
}

resource "aws_cloudwatch_event_target" "journey-recommendations-worflow-trigger-lambda-target" {
  rule      = "${aws_cloudwatch_event_rule.journey-recommendations-worflow-trigger-lambda-rule.name}"
  target_id = "${lower(var.environment_tag)}-journey-recommendations-worflow-trigger-lambda-target"
  arn       = "${aws_lambda_function.triggerstatemachinejob.arn}"
}
