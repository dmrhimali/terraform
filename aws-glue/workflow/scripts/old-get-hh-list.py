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

args = getResolvedOptions(sys.argv, ['TempDir','JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

logger = glueContext.get_logger()

########################################################
##### get healthy habit list ###########################
########################################################
genesis_action_df = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "genesis_public_action", transformation_ctx = "datasource0")
genesis_action_df = genesis_action_df.toDF()
genesis_action_df = genesis_action_df.selectExpr("id as action_id")
logger.info("genesis_action_df data:")
genesis_action_df.show()


genesis_action_activities_df = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "genesis_public_action_activities", transformation_ctx = "datasource0")
genesis_action_activities_df = genesis_action_activities_df.toDF()
genesis_action_activities_df = genesis_action_activities_df.select("action_id","activity_type", "manually_entered")
#WHERE aa.manually_entered != FALSE
genesis_action_activities_df = genesis_action_activities_df.filter(F.col("manually_entered") != False)
logger.info("genesis_action_activities_df data:")
genesis_action_activities_df.show()

genesis_thrive_category_df = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "genesis_public_thrive_category", transformation_ctx = "datasource0")
genesis_thrive_category_df = genesis_thrive_category_df.toDF()
genesis_action_df = genesis_action_df.selectExpr("id as action_id", "status")
#WHERE tc.status = 'Published'
genesis_thrive_category_df = genesis_thrive_category_df.filter(F.col("status") == "Published")
logger.info("genesis_thrive_category_df data:")
genesis_thrive_category_df.show()

genesis_tracker_df = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "genesis_public_tracker", transformation_ctx = "datasource0")
genesis_tracker_df = genesis_tracker_df.toDF()
genesis_tracker_df = genesis_tracker_df.selectExpr("action as action_id","thrive_category_id", "hide_on_healthy_habits", "status", "sponsor_id")
#WHERE t.hide_on_healthy_habits = 'false'
genesis_tracker_df = genesis_tracker_df.filter(F.col("hide_on_healthy_habits") == False)
#WHERE t.status = 'Published'
genesis_tracker_df = genesis_tracker_df.filter(F.col("status") == "Published")
#WHERE t.sponsor_id isNull
genesis_tracker_df = genesis_tracker_df.filter(F.col("sponsor_id").isNull())
logger.info("genesis_tracker_df data:")
genesis_tracker_df.show()

#INNER JOIN action a  ON aa.action_id = a.id
genesis_action_activities_join_df = genesis_action_df.join(genesis_action_activities_df, 'action_id',how='inner')
#INNER JOIN tracker t ON t.action = a.id
tracker_action_activities_join_df = genesis_action_activities_join_df.join(genesis_tracker_df, 'action_id',how='inner')
#INNER JOIN thrive_category tc ON t.thrive_category_id = tc.id
thrirvecategory_tracker_action_activities_join_df = tracker_action_activities_join_df.join(genesis_thrive_category_df, 'thrive_category_id',how='inner')

hh_list_df = thrirvecategory_tracker_action_activities_join_df.select('activity_type').distinct()
logger.info("hh_list_df data:")
hh_list_df.show()

########################################################
##### get member healthy habit activites ###############
########################################################
ima_member_df = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "dev_dw_dim_scd1_member", redshift_tmp_dir = args["TempDir"], transformation_ctx = "dev_dw_dim_scd1_member")
ima_member_df = ima_member.toDF()
#WHERE members.member_id is not null
ima_member_df = ima_member_df.filter(F.col("member_id").isNotNull())
#ima_member_df.filter(ima_member_df.member_id.isNotNull())
ima_member_df = ima_member_df.select("member_id","member_key")
logger.info("ima_member_df data:")
ima_member_df.show()

ima_member_activity_df = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "dev_dw_fct_member_activity", redshift_tmp_dir = args["TempDir"], transformation_ctx = "dev_dw_fct_member_activity")
ima_member_activity_df = ima_member_activity_df.toDF()
#WHERE fma.activity_type IN hh list
#ima_member_activity_df = ima_member_activity_df.join(hh_list_df, ima_member_activity_df.activity_type == hh_list_df.action_type,how='inner')
ima_member_activity_df = ima_member_activity_df.join(hh_list_df, 'activity_type',how='inner')
ima_member_activity_df = ima_member_activity_df.select("activity_date","dw_created_date", "member_key", "activity_type")
#WHERE activity_date > dateadd(year,-1, GETDATE())
ima_member_activity_df = ima_member_activity_df.filter(F.col("activity_date") >= F.add_months(F.current_date(), -12))
logger.info("ima_member_activity_df data:")
ima_member_activity_df.show()

ima_tracker_df = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "dev_dw_dim_scd1_tracker", redshift_tmp_dir = args["TempDir"], transformation_ctx = "dev_dw_dim_scd1_tracker")
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
#write csv to s3 (random generated name)
ima_member_hh_activites_df = ima_member_hh_activites_df.repartition(1)
datasink = ima_member_hh_activites_df.toDF()
datasink.write.format("csv").option("header", "true").mode("overwrite").save("s3://dmrh-glue-output/genesis-data/genesis_hh")

#rename csv file
client = boto3.client('s3')
BUCKET_NAME = 'dmrh-glue-output'
PREFIX = 'genesis-data/genesis_hh/'

response = client.list_objects(Bucket=BUCKET_NAME,Prefix=PREFIX)
temp_csv_name = response["Contents"][0]["Key"]
client.copy_object(Bucket=BUCKET_NAME, CopySource=BUCKET_NAME+'/'+temp_csv_name, Key=PREFIX+"hh-personalize-dataset.csv")
client.delete_object(Bucket=BUCKET_NAME, Key=temp_csv_name)
print("written data to s3")
job.commit()
