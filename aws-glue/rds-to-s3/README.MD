# Manual Process

## create s3 buckets

**create s3 bucket for storing scripts**
create bucket `dmrh-glue-scripts`

add permissions> bucker policy:

```json
{
    "Version": "2012-10-17",
    "Id": "GlueS3BucketAccessPolicy",
    "Statement": [
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
                "arn:aws:s3:::dmrh-glue-scripts",
                "arn:aws:s3:::dmrh-glue-scripts/*"
            ]
        }
    ]
}
```


**create s3 bucket for storing glue output**
create bucket `dmrh-glue-output`

add permissions> bucker policy:

```json
{
    "Version": "2012-10-17",
    "Id": "GlueS3BucketAccessPolicy",
    "Statement": [
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
                "arn:aws:s3:::dmrh-glue-output",
                "arn:aws:s3:::dmrh-glue-output/*"
            ]
        }
    ]
}
```

## create rds db

**create sg for rds**
1. aws console
2. vpc
3. security groups
4. create security group
5. give name : Postgres-allow-all-sg
6. description: allow all incoming connections to Postgres
7. vpc: select default vpc
8. inbound rule: to allow myself to connect from laptop `PostgreSQL	TCP	5432	0.0.0.0/0	-    and  PostgreSQL	TCP	5432	::/0	-`
9. inbound rule2: to allow glue to create rds connection `All TCP	TCP	0 - 65535	sg-0c5b7a7c26957b72e (Postgres-allow-all-sg)`
10. outboud rule: all traffic


**create db**
1. aws console
2. rds
3. create database
4. postgres
5. free tier
6. publicly accessible: true (to allow me to connect to db from laptop)
7. user: testUser
8. securtiy group: Postgres-allow-all-sg
9. password: testPassword1
10. create

**create and populate tables**

1. in dbvisualizer connect to db: (driver:PostgreSQL, Database server:Database Server	genesis.ckrirceczurq.us-east-1.rds.amazonaws.com, Port:5432, user: testUser, pass:testPassword1)
2. create tables:

```sql
CREATE TABLE public.action_activities (
	id bigserial NOT NULL,
	action_id int4 NULL,
	activity_type varchar(255) NOT NULL,
	manually_entered bool NULL DEFAULT false,
	CONSTRAINT pk_action_activities_id PRIMARY KEY (id)
);
INSERT INTO public.action_activities (action_id, activity_type, manually_entered) VALUES(1, 'Weight', true);
INSERT INTO public.action_activities (action_id, activity_type, manually_entered) VALUES(1, 'BioMetrics', false);

CREATE TABLE public."action" (
	id serial NOT NULL,
	"name" varchar(255) NOT NULL,
	description varchar(255) NOT NULL,
	action_type varchar(50) NOT NULL,
	CONSTRAINT pk_action PRIMARY KEY (id)
);
INSERT INTO public."action" ("name", description, action_type) VALUES('Weight', 'Weight', 'Weight');

CREATE TABLE public.tracker (
	id bigserial NOT NULL,
	description varchar(255) NOT NULL,
	title varchar(255) NOT NULL,
	thrive_category_id int8 NOT NULL,
	"action" int4 NULL,
	hide_on_healthy_habits bool NOT NULL DEFAULT false,
        status varchar(25) NOT NULL,
        sponsor_id int8 NULL,
	CONSTRAINT pk_tracker_id PRIMARY KEY (id),
	CONSTRAINT uq_tracker_action UNIQUE (action)
);
INSERT INTO public.tracker
(description, title, thrive_category_id, "action", hide_on_healthy_habits, status, sponsor_id)
VALUES('Daily Weight Tracker', 'What’s your Weight?', 1, 1, false, 'Published' , null);

CREATE TABLE public.thrive_category (
	id bigserial NOT NULL,
	"name" varchar(80) NULL,
	color varchar(20) NULL,
	order_index int8 NULL,
	"type" varchar(64) NULL,
	status varchar NOT NULL DEFAULT 'Unpublished'::character varying,
	"sensitive" bool NOT NULL DEFAULT false,
	CONSTRAINT pk_thrive_category PRIMARY KEY (id)
);
INSERT INTO public.thrive_category
("name", color, order_index, "type", status, "sensitive")
VALUES('Getting Active', '#f26700', 0, 'GettingActive', 'Published'::character varying, false);

```

veirfy creation:

```sql
SELECT 
    distinct aa.activity_type as activity_type
FROM action_activities aa
INNER JOIN action a  ON aa.action_id = a.id
INNER JOIN tracker t ON t.action = a.id
INNER JOIN thrive_category tc ON t.thrive_category_id = tc.id
WHERE t.hide_on_healthy_habits = 'false'
AND t.status = 'Published'
AND t.sponsor_id isNull
AND tc.status = 'Published'
AND aa.manually_entered != FALSE;
```

should output 'weight'


## create rds glue connection

1. aws console
2. glue
3. connections
4. create connection
5. Connection name: genesis-postgres
6. Connection type: Amazon RDS
7. Database engine: PostgreSQL
8. Next
9. Instance: genesis
10. Database name: genesis
11. Username: testUser
12. Password: testPassword1
13. next
14. finish

## create rds glue crawler

1. aws console
2. glue
3. crawlers
4. create crawler
5. Crawler Name: genesis-crawler
6. Next
7. Crawler source type: Datastore
8. Next
9. Choose a data store: JDBC
10. Connection: genesis-postgres
11. Include path: genesis/public/%
12. Next
13. Add another data store: No
14. Choose an IAM role: Create glue service role
15. Frequency: Run on Demand
16. Next
17. Database: Add database 
18. Name: glue_genesis_postgres
19. Create
20. Finish
    
## run crawler

1. aws console
2. glue
3. crawlers
4. select genesis-crawler
5. run crawler
6. After completion you should see all tables in glue>databases>tables

## create job

1. aws console
2. glue
3. jobs
4. add job
5. Name: genesis_public_action
6. IAM Role: same aws glue service role you created before
7. Type: Spark
8. Glue version: Spark 2.4, Python 3 (Glue version 1.0)
9. This job runs: A proposed script generated by AWS Glue
10. Script file name: genesis_public_action
11. S3 path where the script is stored: s3://dmrh-glue-scripts/root/genesis-postgres
12. Temporary directory: s3://aws-glue-temporary-545200963109-us-east-1/root
13. Security configuration, script libraries, and job parameters (optional)
14. Maximum capacity: 2
15. Next
16. Choose a data source: genesis_public_action (you can add more to script later)
17. next
18. Choose a transform type: Change schema
19. Choose a data target: Create tables in your data target
20. Data store: Amazon S3
21. Format: CSV
22. Compression type: None
23. Connection: do not enter anything. you need this if you only have a jdbc target
24. Target path: s3://dmrh-glue-output/genesis-data
25. Map the source columns to target columns: leave as is
26. save job and edit script

initial code looks like this (some modification to save in one file):

```python
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

datasource0 = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "genesis_public_action", transformation_ctx = "datasource0")

applymapping1 = ApplyMapping.apply(frame = datasource0, mappings = [("action_type", "string", "action_type", "string"), ("name", "string", "name", "string"), ("description", "string", "description", "string"), ("id", "int", "id", "int")], transformation_ctx = "applymapping1")

## check partitions
dataframe = DynamicFrame.toDF(applymapping1)  
print(dataframe.rdd.getNumPartitions())

## Force one partition, so it can save only 1 file instead of 19
repartition = applymapping1.repartition(1)

repartition.toDF().write.mode("overwrite").format("csv").save("s3://dmrh-glue-output/genesis-data/genesis_public_action")

#datasink = DynamicFrame.toDF(repartition)
#datasink2.write.format("com.databricks.spark.csv").option("header", "true").mode("overwrite").save("s3://dmrh-glue-output/genesis-data/genesis_public_action")


#datasink2 = glueContext.write_dynamic_frame.from_options(frame = repartition, connection_type = "s3", connection_options = {"path": "s3://dmrh-glue-output/genesis-data/hh"}, format = "parquet", transformation_ctx = "datasink2")
job.commit()
```


### getting genesis healthy habit list

```python
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
## @type: DataSource
## @args: [database = "glue_genesis_postgres", table_name = "genesis_public_action", transformation_ctx = "datasource0"]
## @return: datasource0
## @inputs: []
genesis_public_action = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "genesis_public_action", transformation_ctx = "datasource0")
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

genesis_public_action_activities = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "genesis_public_action_activities", transformation_ctx = "datasource0")
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

genesis_public_thrive_category = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "genesis_public_thrive_category", transformation_ctx = "datasource0")
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

genesis_public_tracker = glueContext.create_dynamic_frame.from_catalog(database = "glue_genesis_postgres", table_name = "genesis_public_tracker", transformation_ctx = "datasource0")
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
datasink.write.format("csv").option("header", "true").mode("overwrite").save("s3://dmrh-glue-output/genesis-data/genesis_hh/hh.csv")
#datasink.write.format("csv").option("header", "true").mode("overwrite").save("s3://dmrh-glue-output/genesis-data/genesis_hh")
print("written data to s3")
job.commit()
```

### Read data from s3 into a dynamicframe

```python
sourceDyf = glueContext.create_dynamic_frame_from_options(
    connection_type="s3",
    format="csv",
    connection_options={
        "paths": ["s3://bucket/folder"]
    },
    format_options={
        "withHeader": True,
        "separator": ","
    })
```



code that handles multipart upload (5MB problem):

https://gist.github.com/bwicklund/0000c9066845afc928e128f2ff79cba1


### Python external libraries in glue

https://stackoverflow.com/questions/58205999/how-can-i-use-an-external-python-library-in-aws-glue
https://www.helicaltech.com/external-python-libraries-aws-glue-job/
https://thedataguy.in/aws-glue-custom-output-file-size-and-fixed-number-of-files/

### Filtering

https://stackoverflow.com/questions/37262762/filter-pyspark-dataframe-column-with-none-value



### Save glue output as one csv

**set paritions**

```python
datasource0 = glueContext.create_dynamic_frame.from_catalog(database = "bhuvi", table_name = "glue_csv", transformation_ctx = "datasource0")

applymapping1 = ApplyMapping.apply(frame = datasource0, mappings = [("ln", "string", "ln", "string"), ("gender", "string", "gender", "string"), ("ip", "string", "ip", "string"), ("fn", "string", "fn", "string"), ("id", "long", "id", "long"), ("email", "string", "email", "string")], transformation_ctx = "applymapping1")

resolvechoice2 = ResolveChoice.apply(frame = applymapping1, choice = "make_struct", transformation_ctx = "resolvechoice2")

dropnullfields3 = DropNullFields.apply(frame = resolvechoice2, transformation_ctx = "dropnullfields3")

datasource_df = dropnullfields3.repartition(1)

datasink4 = glueContext.write_dynamic_frame.from_options(frame = datasource_df, connection_type = "s3", connection_options = {"path": "s3://bhuvi-datalake/parquet-new"}, format = "parquet", transformation_ctx = "datasink4")
job.commit()
```
`repartition(1)` - This will create 1 file in S3.


OR **multipart upload**


https://stackoverflow.com/questions/55515251/aws-glue-job-how-to-merge-multiple-output-csv-files-in-s3

```python
import argparse
import boto3
import os
import threading
from fnmatch import fnmatch

# S3 multi-part upload parts must be larger than 5mb
MIN_S3_SIZE = 6000000
LOG_LEVEL = 'INFO'


def concat(bucket, key, result_key, pattern):
    s3_client = boto3.session.Session().client('s3')
    objects_list = [x for x in list_all_objects(
        s3_client, bucket, result_key, key) if fnmatch(x[0], pattern)]
    print(
        f"Found {len(objects_list)} parts to concatenate in s3://{bucket}/{key}")
    for object in objects_list:
        print(f"Found: {object[0]} - {round(object[1]/1000, 2)}k")

    run_concatenation(s3_client, bucket, key, result_key, objects_list)


def list_all_objects(s3_client, bucket, result_key, key):
    def format_return(resp):
        return [(x['Key'], x['Size']) for x in resp['Contents']]

    objects = []
    resp = s3_client.list_objects(Bucket=bucket, Prefix=key)
    objects.extend(format_return(resp))
    while resp['IsTruncated']:
        # If there are more objects than can be returned in a signle request
        # then the key of the last item is used for pagination.
        last_key = objects[-1][0]
        resp = s3_client.list_objects(
            Bucket=bucket, Prefix=key, Marker=last_key)
        objects.extend(format_return(resp))

    return objects


def run_concatenation(s3_client, bucket, key, result_key, objects_list):
    if len(objects_list) > 1:
        upload_id = s3_client.create_multipart_upload(
            Bucket=bucket, Key=result_key)['UploadId']
        parts_mapping = assemble_parts_to_concatenate(
            s3_client, bucket, key, result_key, upload_id, objects_list)
        if len(parts_mapping) == 0:
            resp = s3_client.abort_multipart_upload(
                Bucket=bucket, Key=result_key, UploadId=upload_id)
            print(
                f"Aborted concatenation for file {result_filename}, parts list empty!")
        else:
            resp = s3_client.complete_multipart_upload(
                Bucket=bucket, Key=result_key, UploadId=upload_id, MultipartUpload={'Parts': parts_mapping})
            print(
                f"Finished concatenation for file {result_key} response was: {resp}")
    elif len(objects_list) == 1:
        # can perform a simple S3 copy since there is just a single file
        resp = s3_client.copy_object(
            Bucket=bucket, CopySource=f"{bucket}/{objects_list[0][0]}", Key=result_key)
        print(f"Copied single file to {result_key} response was: {resp}")
    else:
        print(f"No files to concatenate for {result_filepath}")


def assemble_parts_to_concatenate(s3_client, bucket, key, result_key, upload_id, objects_list):
    parts_mapping = []
    part_num = 0

    s3_objects = ["{}/{}".format(bucket, p[0])
                  for p in objects_list if p[1] > MIN_S3_SIZE]
    local_objects = [p[0] for p in objects_list if p[1]
                     <= MIN_S3_SIZE and not p[0] == f"{key}/"]
    total = len(s3_objects) + len(local_objects)
    # assemble parts large enough for direct S3 copy
    # part numbers are 1 indexed
    for part_num, source_object in enumerate(s3_objects, 1):
        resp = s3_client.upload_part_copy(Bucket=bucket,
                                          Key=result_key,
                                          PartNumber=part_num,
                                          UploadId=upload_id,
                                          CopySource=source_object)
        print(f"@@@ Uploaded S3 object #{part_num} of {total}")
        parts_mapping.append(
            {'ETag': resp['CopyPartResult']['ETag'][1:-1], 'PartNumber': part_num})

    # Download the objects to small for direct s3 copy
    # combine them, and then uploading them as the last part of the
    # multi-part upload (no 5mb limit)
    small_objects = []
    for source_object in local_objects:
        # Remove forward slash
        temp_filename = "/tmp/{}".format(source_object.replace("/", "_"))
        s3_client.download_file(
            Bucket=bucket, Key=source_object, Filename=temp_filename)
        with open(temp_filename, 'rb') as f:
            small_objects.append(f.read())
        os.remove(temp_filename)
        print(f"@@@ Downloaded S3 Object: {source_object}")

    if len(small_objects) > 0:
        last_part_num = part_num + 1
        last_object = b''.join(small_objects)
        resp = s3_client.upload_part(
            Bucket=bucket, Key=result_key, PartNumber=last_part_num, UploadId=upload_id, Body=last_object)
        print(f"@@@ Uploaded S3 object #{last_part_num} of {total}")
        parts_mapping.append(
            {'ETag': resp['ETag'][1:-1], 'PartNumber': last_part_num})

    return parts_mapping


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="S3 Concatenation Utility.")
    parser.add_argument("--bucket", help="S3 Bucket.")
    parser.add_argument(
        "--key", help="Key/Folder Whose Contents Should Be Combined.")
    parser.add_argument(
        "--result_key", help="Output of Concatenation, Relative To The Specified Bucket.")
    parser.add_argument("--pattern", default='*',
                        help="Pattern To Match The File Names Against For Adding To The Combination.")
    args = parser.parse_args()

    print("Combining files in s3://{}/{} to s3://{}/{} matching pattern {}".format(
        args.bucket, args.key, args.bucket, args.result_key, args.pattern))

    concat(args.bucket, args.key, args.result_key, args.pattern)
```
## Scheduling

https://www.terraform.io/docs/providers/aws/r/glue_trigger.html

