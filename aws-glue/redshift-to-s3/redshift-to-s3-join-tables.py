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
journey_ds = glueContext.create_dynamic_frame.from_catalog(database = "catalog-database", table_name = "dev_dw_journey", redshift_tmp_dir = args["TempDir"], transformation_ctx = "datasource0")
member_ds = glueContext.create_dynamic_frame.from_catalog(database = "catalog-database", table_name = "dev_dw_member", redshift_tmp_dir = args["TempDir"], transformation_ctx = "datasource1")
journey_member_ds = glueContext.create_dynamic_frame.from_catalog(database = "catalog-database", table_name = "dev_dw_member_journey", redshift_tmp_dir = args["TempDir"], transformation_ctx = "datasource2")

print ("journey Count: ", journey_ds.count())
print("schema:")
journey_ds.printSchema()
print("Data:")
journey_ds.toDF().show()

print ("member Count: ", member_ds.count())
print("schema:")
member_ds.printSchema()
print("Data:")
member_ds.toDF().show()

print ("journey_member_ds Count: ", journey_member_ds.count())
print("schema:")
journey_member_ds.printSchema()
print("Data:")
journey_member_ds.toDF().show()

## @type: Join
## @args: [keys1 = [<keys1>], keys2 = [<keys2>]]
## @return: <output>
## @inputs: [frame1 = <frame1>, frame2 = <frame2>]
join1 = Join.apply(frame1 = journey_ds, frame2 = journey_member_ds, keys1 = ["journeyid"], keys2 = ["journeyid"], transformation_ctx = "join1")
print ("join1 Count: ", join1.count())
print("schema:")
join1.printSchema()
print("Data:")
join1.toDF().show()
join1.drop_fields(['`.journeyid`'])

join2 = Join.apply(frame1 = member_ds, frame2 = journey_member_ds, keys1 = "memberid", keys2 = "memberid", transformation_ctx = "join2")
print ("join2 Count: ", join2.count())
print("schema:")
join2.printSchema()
print("Data:")
join2.toDF().show()

join3 = Join.apply(frame1 = join1, frame2 = join2, keys1 = "memberid", keys2 = "memberid", transformation_ctx = "join3")
print ("join3 Count: ", join3.count())
print("schema:")
join3.printSchema()
print("Data:")
join3.toDF().show()

## @type: Join
## @args: [keys1 = [<keys1>], keys2 = [<keys2>]]
## @return: <output>
## @inputs: [frame1 = <frame1>, frame2 = <frame2>]

## @type: ApplyMapping
## @args: [mapping = [("journeyname", "string", "journeyname", "string"), ("journeyid", "int", "journeyid", "int")], transformation_ctx = "applymapping1"]
## @return: applymapping1
## @inputs: [frame = datasource0]
journey_mp = ApplyMapping.apply(frame = journey_ds, mappings = [("journeyname", "string", "journeyname", "string"), ("journeyid", "int", "journeyid", "int")], transformation_ctx = "applymapping1")
member_mp = ApplyMapping.apply(frame = member_ds, mappings = [("name", "string", "name", "string"), ("memberid", "int", "memberid", "int")], transformation_ctx = "applymapping2")
member_journey_mp = ApplyMapping.apply(frame = journey_member_ds, mappings = [("journeyid", "int", "journeyid", "int"), ("memberid", "int", "memberid", "int")], transformation_ctx = "applymapping3")


## @type: DataSink
## @args: [connection_type = "s3", connection_options = {"path": "s3://dmrh-import-sensor-events-bucket/manual"}, format = "csv", transformation_ctx = "datasink2"]
## @return: datasink2
## @inputs: [frame = applymapping1]
datasink2 = glueContext.write_dynamic_frame.from_options(frame = join3, connection_type = "s3", connection_options = {"path": "s3://dmrh-import-sensor-events-bucket/manual"}, format = "csv", transformation_ctx = "datasink2")
job.commit()