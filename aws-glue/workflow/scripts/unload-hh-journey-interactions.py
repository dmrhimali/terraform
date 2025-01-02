import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import boto3

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
## @type: DataSource
## @args: [database = "journey-catalog-database", table_name = "genesis_public_action", transformation_ctx = "datasource0"]
## @return: datasource0
## @inputs: []
genesis_public_action = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "genesis_public_action", transformation_ctx = "datasource0")
genesis_public_action_mapping = ApplyMapping.apply(frame = genesis_public_action, mappings = [("action_type", "string", "action_type", "string"), ("name", "string", "name", "string"), ("description", "string", "description", "string"), ("id", "int", "id", "int")], transformation_ctx = "applymapping1")
genesis_public_action_rename  = RenameField.apply(frame = genesis_public_action_mapping, old_name = "id", new_name = "genesis_public_action_id", transformation_ctx = "rename0")
genesis_public_action_rename.printSchema()
# id name   description action_type 
# -- ------ ----------- ----------- 
# 1  Weight Weight      Weight      
# root
# |-- action_type: string
# |-- name: string
# |-- description: string
# |-- genesis_public_action_id: int

genesis_public_action_activities = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "genesis_public_action_activities", transformation_ctx = "datasource0")
genesis_public_action_activities_mapping = ApplyMapping.apply(frame = genesis_public_action_activities, mappings = [("manually_entered", "boolean", "manually_entered", "boolean"), ("action_id", "int", "action_id", "int"), ("activity_type", "string", "activity_type", "string"), ("id", "long", "id", "long")], transformation_ctx = "applymapping1")
genesis_public_action_activities_rename  = RenameField.apply(frame = genesis_public_action_activities_mapping, old_name = "id", new_name = "genesis_public_action_activities_id", transformation_ctx = "rename1")
genesis_public_action_activities_rename.printSchema()
# id action_id activity_type manually_entered 
# -- --------- ------------- ---------------- 
# 1  1         Weight        true             
# 2  1         BioMetrics    false   
# root
# |-- manually_entered: boolean
# |-- action_id: int
# |-- activity_type: string
# |-- genesis_public_action_activities_id: long

genesis_public_thrive_category = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "genesis_public_thrive_category", transformation_ctx = "datasource0")
genesis_public_thrive_category_mapping = ApplyMapping.apply(frame = genesis_public_thrive_category, mappings = [("color", "string", "color", "string"), ("name", "string", "name", "string"), ("id", "long", "id", "long"), ("sensitive", "boolean", "sensitive", "boolean"), ("order_index", "long", "order_index", "long"), ("type", "string", "type", "string"), ("status", "string", "status", "string")], transformation_ctx = "applymapping1")
genesis_public_thrive_category_rename  = RenameField.apply(frame = genesis_public_thrive_category_mapping, old_name = "id", new_name = "genesis_public_thrive_category_id", transformation_ctx = "rename1")
genesis_public_thrive_category_rename.printSchema()
# id name           color   order_index type          status    sensitive 
# -- -------------- ------- ----------- ------------- --------- --------- 
# 1  Getting Active #f26700 0           GettingActive Published false     
# root
# |-- color: string
# |-- name: string
# |-- sensitive: boolean
# |-- order_index: long
# |-- type: string
# |-- status: string
# |-- genesis_public_thrive_category_id: long

genesis_public_tracker = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "genesis_public_tracker", transformation_ctx = "datasource0")
genesis_public_tracker_mapping = ApplyMapping.apply(frame = genesis_public_tracker, mappings = [("thrive_category_id", "long", "thrive_category_id", "long"), ("description", "string", "description", "string"), ("action", "int", "action", "int"), ("id", "long", "id", "long"), ("title", "string", "title", "string"), ("sponsor_id", "long", "sponsor_id", "long"), ("hide_on_healthy_habits", "boolean", "hide_on_healthy_habits", "boolean"), ("status", "string", "status", "string")], transformation_ctx = "applymapping1")
genesis_public_tracker_rename  = RenameField.apply(frame = genesis_public_tracker_mapping, old_name = "id", new_name = "genesis_public_tracker_id", transformation_ctx = "rename1")
genesis_public_tracker_rename.printSchema()
# id description          title               thrive_category_id action hide_on_healthy_habits status    sponsor_id 
# -- -------------------- ------------------- ------------------ ------ ---------------------- --------- ---------- 
# 1  Daily Weight Tracker What’s your Weight? 1                  1      false                  Published (null)     
# root
# |-- thrive_category_id: long
# |-- description: string
# |-- action: int
# |-- title: string
# |-- sponsor_id: null
# |-- hide_on_healthy_habits: boolean
# |-- status: string
# |-- genesis_public_tracker_id: long



#INNER JOIN action a  ON aa.action_id = a.id
join1 = Join.apply(frame1 = genesis_public_action_activities_rename, frame2 = genesis_public_action_rename, keys1 = ["action_id"], keys2 = ["genesis_public_action_id"], transformation_ctx = "join1")
print ("join1 Count: ", join1.count())
join1.printSchema()
print("join 1 schema:")
#root (if field renaming not done)
# |-- action_type: string
# |-- activity_type: string
# |-- .id: long (action_activities.id)
# |-- description: string
# |-- name: string
# |-- action_id: int
# |-- manually_entered: boolean
# |-- id: int (action.id)

# root(if field renaming  done)
# |-- action_type: string
# |-- activity_type: string
# |-- description: string
# |-- name: string
# |-- action_id: int
# |-- genesis_public_action_id: int
# |-- manually_entered: boolean
# |-- genesis_public_action_activities_id: long
print("join 1 Data:")
join1.toDF().show()
# +-----------+-------------+-----------+------+---------+------------------------+----------------+-----------------------------------+
# |action_type|activity_type|description|  name|action_id|genesis_public_action_id|manually_entered|genesis_public_action_activities_id|
# +-----------+-------------+-----------+------+---------+------------------------+----------------+-----------------------------------+
# |     Weight|   BioMetrics|     Weight|Weight|        1|                       1|           false|                                  2|
# |     Weight|       Weight|     Weight|Weight|        1|                       1|            true|                                  1|
# +-----------+-------------+-----------+------+---------+------------------------+----------------+-----------------------------------+

#INNER JOIN tracker t ON t.action = a.id
join2 = Join.apply(frame1 = join1, frame2 = genesis_public_tracker_rename, keys1 = ["genesis_public_action_id"], keys2 = ["action"], transformation_ctx = "join2")
print ("join2 Count: ", join1.count())
print("join2 schema:")
join2.printSchema()
# root
# |-- genesis_public_tracker_id: long
# |-- action_type: string
# |-- action: int
# |-- sponsor_id: null
# |-- thrive_category_id: long
# |-- activity_type: string
# |-- .description: string
# |-- description: string
# |-- name: string
# |-- action_id: int
# |-- title: string
# |-- genesis_public_action_id: int
# |-- status: string
# |-- hide_on_healthy_habits: boolean
# |-- manually_entered: boolean
# |-- genesis_public_action_activities_id: long
print("join2 Data:")
# join2.toDF().show()
# +-------------------------+-----------+------+----------+------------------+-------------+------------+--------------------+------+---------+-------------------+------------------------+---------+----------------------+----------------+-----------------------------------+
# |genesis_public_tracker_id|action_type|action|sponsor_id|thrive_category_id|activity_type|.description|         description|  name|action_id|              title|genesis_public_action_id|   status|hide_on_healthy_habits|manually_entered|genesis_public_action_activities_id|
# +-------------------------+-----------+------+----------+------------------+-------------+------------+--------------------+------+---------+-------------------+------------------------+---------+----------------------+----------------+-----------------------------------+
# |                        1|     Weight|     1|      null|                 1|   BioMetrics|      Weight|Daily Weight Tracker|Weight|        1|What’s your Weight?|                       1|Published|                 false|           false|                                  2|
# |                        1|     Weight|     1|      null|                 1|       Weight|      Weight|Daily Weight Tracker|Weight|        1|What’s your Weight?|                       1|Published|                 false|            true|                                  1|
# +-------------------------+-----------+------+----------+------------------+-------------+------------+--------------------+------+---------+-------------------+------------------------+---------+----------------------+----------------+-----------------------------------+


#INNER JOIN thrive_category tc ON t.thrive_category_id = tc.id
join3 = Join.apply(frame1 = join2, frame2 = genesis_public_thrive_category_rename, keys1 = ["thrive_category_id"], keys2 = ["genesis_public_thrive_category_id"], transformation_ctx = "join2")
print ("join3 Count: ", join3.count())
print("join3 schema:")
join3.printSchema()
# root
# |-- action_type: string
# |-- genesis_public_tracker_id: long
# |-- action: int
# |-- .status: string
# |-- sponsor_id: null
# |-- sensitive: boolean
# |-- type: string
# |-- color: string
# |-- thrive_category_id: long
# |-- activity_type: string
# |-- .description: string
# |-- description: string
# |-- genesis_public_thrive_category_id: long
# |-- name: string
# |-- action_id: int
# |-- title: string
# |-- .name: string
# |-- order_index: long
# |-- genesis_public_action_id: int
# |-- status: string
# |-- hide_on_healthy_habits: boolean
# |-- manually_entered: boolean
# |-- genesis_public_action_activities_id: long

print("join3 Data:")
join3.toDF().show()
# +-----------+-------------------------+------+---------+----------+---------+-------------+-------+------------------+-------------+------------+--------------------+---------------------------------+--------------+---------+-------------------+------+-----------+------------------------+---------+----------------------+----------------+-----------------------------------+
# |action_type|genesis_public_tracker_id|action|  .status|sponsor_id|sensitive|         type|  color|thrive_category_id|activity_type|.description|         description|genesis_public_thrive_category_id|          name|action_id|              title| .name|order_index|genesis_public_action_id|   status|hide_on_healthy_habits|manually_entered|genesis_public_action_activities_id|
# +-----------+-------------------------+------+---------+----------+---------+-------------+-------+------------------+-------------+------------+--------------------+---------------------------------+--------------+---------+-------------------+------+-----------+------------------------+---------+----------------------+----------------+-----------------------------------+
# |     Weight|                        1|     1|Published|      null|    false|GettingActive|#f26700|                 1|   BioMetrics|      Weight|Daily Weight Tracker|                                1|Getting Active|        1|What’s your Weight?|Weight|          0|                       1|Published|                 false|           false|                                  2|
# |     Weight|                        1|     1|Published|      null|    false|GettingActive|#f26700|                 1|       Weight|      Weight|Daily Weight Tracker|                                1|Getting Active|        1|What’s your Weight?|Weight|          0|                       1|Published|                 false|            true|                                  1|
# +-----------+-------------------------+------+---------+----------+---------+-------------+-------+------------------+-------------+------------+--------------------+---------------------------------+--------------+---------+-------------------+------+-----------+------------------------+---------+----------------------+----------------+-----------------------------------+

#WHERE t.hide_on_healthy_habits = 'false'
# AND t.status = 'Published'
# AND t.sponsor_id isNull
# AND tc.status = 'Published'
# AND aa.manually_entered != FALSE;

filter_df = Filter.apply(frame = join3, f = lambda x: x["hide_on_healthy_habits"] is False and x["sponsor_id"] is None and x["status"] == 'Published' and x["manually_entered"] is True, transformation_ctx = "<transformation_ctx>")
print("filter_df Data:")
filter_df.toDF().show()
# +-------------------------+-----------+------+---------+----------+---------+-------------+-------+------------------+-------------+------------+--------------------+---------------------------------+--------------+---------+-------------------+------+------------------------+-----------+---------+----------------------+----------------+-----------------------------------+
# |genesis_public_tracker_id|action_type|action|  .status|sponsor_id|sensitive|         type|  color|thrive_category_id|activity_type|.description|         description|genesis_public_thrive_category_id|          name|action_id|              title| .name|genesis_public_action_id|order_index|   status|hide_on_healthy_habits|manually_entered|genesis_public_action_activities_id|
# +-------------------------+-----------+------+---------+----------+---------+-------------+-------+------------------+-------------+------------+--------------------+---------------------------------+--------------+---------+-------------------+------+------------------------+-----------+---------+----------------------+----------------+-----------------------------------+
# |                        1|     Weight|     1|Published|      null|    false|GettingActive|#f26700|                 1|       Weight|      Weight|Daily Weight Tracker|                                1|Getting Active|        1|What’s your Weight?|Weight|                       1|          0|Published|                 false|            true|                                  1|
# +-------------------------+-----------+------+---------+----------+---------+-------------+-------+------------------+-------------+------------+--------------------+---------------------------------+--------------+---------+-------------------+------+------------------------+-----------+---------+----------------------+----------------+-----------------------------------+


select_df = SelectFields.apply(frame = filter_df, paths = ["action_type"], transformation_ctx = "<transformation_ctx>")


## @type: DataSink
## @args: [connection_type = "s3", connection_options = {"path": "s3://dmrh-glue-output/genesis_public_action"}, format = "csv", transformation_ctx = "datasink2"]
## @return: datasink2
## @inputs: [frame = applymapping1]
final_df = select_df.repartition(1)



#datasink2 = glueContext.write_dynamic_frame.from_options(frame = final_df, connection_type = "s3", connection_options = {"path": "s3://dmrh-glue-output/genesis_public_action"}, format = "csv", transformation_ctx = "datasink2")
datasink = final_df.toDF()
datasink.write.format("csv").option("header", "true").mode("overwrite").save("s3://dmrh-glue-output/genesis-data/genesis_hh")

client = boto3.client('s3')
BUCKET_NAME = 'dmrh-glue-output'
PREFIX = 'genesis-data/genesis_hh/'

response = client.list_objects(Bucket=BUCKET_NAME,Prefix=PREFIX)
temp_csv_name = response["Contents"][0]["Key"]
print("csv : ", temp_csv_name)
client.copy_object(Bucket=BUCKET_NAME, CopySource=BUCKET_NAME+'/'+temp_csv_name, Key=PREFIX+"hh_list.csv")
client.delete_object(Bucket=BUCKET_NAME, Key=temp_csv_name)
print("written data to s3")
job.commit()