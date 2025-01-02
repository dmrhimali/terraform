import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

import boto3

from pyspark.sql.functions import trim
from pyspark.sql import functions as F
from pyspark.sql.functions import concat, col, lit
from pyspark.sql.functions import when
from pyspark.sql.types import *

args = getResolvedOptions(sys.argv, ['TempDir','JOB_NAME', 'HH_LIST_CSV_FILENAME', 'HH_LIST_CSV_BUCKET', 'HH_LIST_CSV_BUCKET_PREFIX', 'HH_MEMBER_INTERACTIONS_CSV_FILENAME', 'HH_MEMBER_INTERACTIONS_CSV_BUCKET', 'HH_MEMBER_INTERACTIONS_CSV_BUCKET_PREFIX'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

logger = glueContext.get_logger()

########################################################
##### get healthy habit list ###########################
########################################################
HH_LISIT_CSV_FILENAME = args['HH_LIST_CSV_FILENAME']
HH_LIST_CSV_BUCKET = args['HH_LIST_CSV_BUCKET']
HH_LIST_CSV_BUCKET_PREFIX = args['HH_LIST_CSV_BUCKET_PREFIX']

hh_list_df = spark.read.format("csv").option("header", "true").load("s3://" + HH_LIST_CSV_BUCKET + "/" + HH_LIST_CSV_BUCKET_PREFIX+ "/" + HH_LISIT_CSV_FILENAME)
logger.info("loaded hh list")
hh_list_df.show()

########################################################
##### get member healthy habit activites ###############
########################################################
ima_member_df = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "dev_dw_dim_scd1_member", redshift_tmp_dir = args["TempDir"], transformation_ctx = "dev_dw_dim_scd1_member")
ima_member_df = ima_member_df.toDF()
#WHERE members.member_id is not null
ima_member_df = ima_member_df.filter(F.col("member_id").isNotNull())
ima_member_df = ima_member_df.select("member_id","member_key")
logger.info("ima_member_df data:")
ima_member_df.show()

ima_member_activity_df = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "dev_dw_fct_member_activity", redshift_tmp_dir = args["TempDir"], transformation_ctx = "dev_dw_fct_member_activity")
ima_member_activity_df = ima_member_activity_df.toDF()
#WHERE fma.activity_type IN hh list
ima_member_activity_df = ima_member_activity_df.join(hh_list_df, 'activity_type',how='inner')
ima_member_activity_df = ima_member_activity_df.select("activity_date","dw_created_date", "member_key", "activity_type")
#WHERE activity_date > dateadd(year,-1, GETDATE())
ima_member_activity_df = ima_member_activity_df.filter(F.col("activity_date") >= F.add_months(F.current_date(), -12))
logger.info("ima_member_activity_df data:")
ima_member_activity_df.show()

ima_tracker_df = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "dev_dw_dim_scd1_tracker", redshift_tmp_dir = args["TempDir"], transformation_ctx = "dev_dw_dim_scd1_tracker")
ima_tracker_df = ima_tracker_df.toDF()
ima_tracker_df = ima_tracker_df.select("tracker_id","activity_type")
logger.info("ima_tracker_df data:")
ima_tracker_df.show()

#LEFT JOIN dw.dim_scd1_member as members ON members.member_key=fma.member_key
ima_member_activity_join_df = ima_member_df.join(ima_member_activity_df, 'member_key',how='left')
logger.info("ima_member_activity_join_df data:")
ima_member_activity_join_df.show()

#INNER JOIN dw.dim_scd1_tracker as trackers ON trackers.activity_type =  fma.activity_type
ima_tracker_member_activity_join_df = ima_member_activity_join_df.join(ima_tracker_df, 'activity_type',how='inner')
logger.info("ima_tracker_member_activity_join_df data:")
ima_tracker_member_activity_join_df.show()

ima_tracker_member_activity_join_df = ima_tracker_member_activity_join_df.withColumn("TIMESTAMP",when(F.col("activity_date").isNotNull(), F.unix_timestamp(F.col('activity_date'), format='yyyy-MM-dd HH:mm:ss')).otherwise(F.unix_timestamp(F.col('dw_created_date'), format='yyyy-MM-dd HH:mm:ss')))
ima_tracker_member_activity_join_df = ima_tracker_member_activity_join_df.withColumn("ITEM_ID", F.concat(F.lit("hh_"),F.col("tracker_id")))
ima_member_hh_activites_df = ima_tracker_member_activity_join_df.selectExpr("member_id AS USER_ID", "ITEM_ID" ,"TIMESTAMP")

logger.info("ima_member_hh_activites_df data:")
ima_member_hh_activites_df.show()              

########################################################
##### write csv to s3  #################################
########################################################
HH_MEMBER_INTERACTIONS_CSV_FILENAME = args['HH_MEMBER_INTERACTIONS_CSV_FILENAME']
HH_MEMBER_INTERACTIONS_CSV_BUCKET = args['HH_MEMBER_INTERACTIONS_CSV_BUCKET']
HH_MEMBER_INTERACTIONS_CSV_BUCKET_PREFIX = args['HH_MEMBER_INTERACTIONS_CSV_BUCKET_PREFIX']

#write csv to s3 (random generated name)
ima_member_hh_activites_df = ima_member_hh_activites_df.repartition(1)
datasink = ima_member_hh_activites_df
datasink.write.format("csv").option("header", "true").mode("overwrite").save("s3://" + HH_MEMBER_INTERACTIONS_CSV_BUCKET + "/" + HH_MEMBER_INTERACTIONS_CSV_BUCKET_PREFIX)

#rename csv file
client = boto3.client('s3')
temp_csv_name =  ""
response = client.list_objects(Bucket=HH_MEMBER_INTERACTIONS_CSV_BUCKET,Prefix=HH_MEMBER_INTERACTIONS_CSV_BUCKET_PREFIX+'/')

temp_csv_key = response["Contents"][0]["Key"]
logger.info("temp_csv_key = "+temp_csv_key)

temp_csv_filename = temp_csv_key[len(HH_MEMBER_INTERACTIONS_CSV_BUCKET_PREFIX)+1:]

if temp_csv_filename.startswith('part'):
    client.copy_object(Bucket=HH_MEMBER_INTERACTIONS_CSV_BUCKET, CopySource=HH_MEMBER_INTERACTIONS_CSV_BUCKET+'/'+ temp_csv_key, Key=HH_MEMBER_INTERACTIONS_CSV_BUCKET_PREFIX +'/'+ HH_MEMBER_INTERACTIONS_CSV_FILENAME)
    client.delete_object(Bucket=HH_MEMBER_INTERACTIONS_CSV_BUCKET, Key=temp_csv_key)
    logger.info("written data to s3")


job.commit()