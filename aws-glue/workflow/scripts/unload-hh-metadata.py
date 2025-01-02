
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

args = getResolvedOptions(sys.argv, ['TempDir','JOB_NAME', 'HH_LIST_CSV_FILENAME', 'HH_LIST_CSV_BUCKET', 'HH_LIST_CSV_BUCKET_PREFIX', 'HH_METADATA_CSV_FILENAME', 'HH_METADATA_CSV_BUCKET', 'HH_METADATA_CSV_BUCKET_PREFIX'])

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
##### unload healthy habit metadata ####################
########################################################
ima_tracker_df = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "dev_dw_dim_scd1_tracker", redshift_tmp_dir = args["TempDir"], transformation_ctx = "dev_dw_dim_scd1_tracker")
ima_tracker_df = ima_tracker_df.toDF()
ima_tracker_df = ima_tracker_df.select("tracker_id","thrive_category_id","activity_type")
ima_tracker_df = ima_tracker_df.join(hh_list_df, 'activity_type',how='inner')
logger.info("ima_tracker_df data:")
ima_tracker_df.show()

ima_thrive_category_df = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "dev_dw_dim_thrive_category", redshift_tmp_dir = args["TempDir"], transformation_ctx = "dev_dw_dim_thrive_category")
ima_thrive_category_df = ima_thrive_category_df.toDF()
ima_thrive_category_df = ima_thrive_category_df.select("thrive_category_id")
logger.info("ima_thrive_category_df data:")
ima_thrive_category_df.show()


#INNER JOIN dw.dim_thrive_category dtc ON dst.thrive_category_id = dtc.thrive_category_id
ima_tracker_thrive_category_join_df = ima_tracker_df.join(ima_thrive_category_df, 'thrive_category_id',how='inner')
logger.info("ima_tracker_thrive_category_join_df data:")
ima_tracker_thrive_category_join_df.show()


ima_tracker_thrive_category_join_df = ima_tracker_thrive_category_join_df.distinct()
ima_tracker_thrive_category_join_df = ima_tracker_thrive_category_join_df.withColumn("ITEM_ID", F.concat(F.lit("hh_"),F.col("tracker_id")))
ima_tracker_thrive_category_join_df = ima_tracker_thrive_category_join_df.withColumn("ITEM_TYPE", F.lit("hh_"))
hh_metadata_df = ima_tracker_thrive_category_join_df.selectExpr("ITEM_ID","ITEM_TYPE","thrive_category_id")
logger.info("hh_metadata_df data:")
hh_metadata_df.show()

########################################################
##### write csv to s3  #################################
########################################################
HH_METADATA_CSV_FILENAME = args['HH_METADATA_CSV_FILENAME']
HH_METADATA_CSV_BUCKET = args['HH_METADATA_CSV_BUCKET']
HH_METADATA_CSV_BUCKET_PREFIX = args['HH_METADATA_CSV_BUCKET_PREFIX']

#write csv to s3 (random generated name)
hh_metadata_df = hh_metadata_df.repartition(1)
datasink = hh_metadata_df
datasink.write.format("csv").option("header", "true").mode("overwrite").save("s3://" +HH_METADATA_CSV_BUCKET + "/" + HH_METADATA_CSV_BUCKET_PREFIX)

#rename csv file
client = boto3.client('s3')
response = client.list_objects(Bucket=HH_METADATA_CSV_BUCKET,Prefix=HH_METADATA_CSV_BUCKET_PREFIX+'/')

temp_csv_key = response["Contents"][0]["Key"]
logger.info("temp_csv_key = "+temp_csv_key)

temp_csv_filename = temp_csv_key[len(HH_METADATA_CSV_BUCKET_PREFIX)+1:]

if temp_csv_filename.startswith('part'):
    client.copy_object(Bucket=HH_METADATA_CSV_BUCKET, CopySource=HH_METADATA_CSV_BUCKET+'/'+ temp_csv_key, Key=HH_METADATA_CSV_BUCKET_PREFIX +'/'+ HH_METADATA_CSV_FILENAME)
    client.delete_object(Bucket=HH_METADATA_CSV_BUCKET, Key=temp_csv_key)
    logger.info("written data to s3")


job.commit()
