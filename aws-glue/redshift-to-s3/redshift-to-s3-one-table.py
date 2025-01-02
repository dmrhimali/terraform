#default generated script to bring redshift table to s3 works

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

## @params: [TempDir, JOB_NAME]
args = getResolvedOptions(sys.argv, ['TempDir','JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
## @type: DataSource
## @args: [database = "catalog-database", table_name = "dev_dw_journey", redshift_tmp_dir = TempDir, transformation_ctx = "datasource0"]
## @return: datasource0
## @inputs: []
datasource0 = glueContext.create_dynamic_frame.from_catalog(database = "catalog-database", table_name = "dev_dw_journey", redshift_tmp_dir = args["TempDir"], transformation_ctx = "datasource0")
## @type: ApplyMapping
## @args: [mapping = [("journeyname", "string", "journeyname", "string"), ("journeyid", "int", "journeyid", "int")], transformation_ctx = "applymapping1"]
## @return: applymapping1
## @inputs: [frame = datasource0]
applymapping1 = ApplyMapping.apply(frame = datasource0, mappings = [("journeyname", "string", "journeyname", "string"), ("journeyid", "int", "journeyid", "int")], transformation_ctx = "applymapping1")
## @type: DataSink
## @args: [connection_type = "s3", connection_options = {"path": "s3://dmrh-import-sensor-events-bucket/manual"}, format = "csv", transformation_ctx = "datasink2"]
## @return: datasink2
## @inputs: [frame = applymapping1]
datasink2 = glueContext.write_dynamic_frame.from_options(frame = applymapping1, connection_type = "s3", connection_options = {"path": "s3://dmrh-import-sensor-events-bucket/manual"}, format = "csv", transformation_ctx = "datasink2")
job.commit()