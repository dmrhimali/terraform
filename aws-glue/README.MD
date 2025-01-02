# AWS Glue
AWS:
>AWS Glue is a serverless data integration service that makes data preparation simpler, faster, and cheaper. You can discover and connect to over 100 diverse data sources, manage your data in a centralized data catalog, and visually create, run, and monitor ETL pipelines to load data into your data lakes. With built-in generative AI capabilities, you can modernize Spark jobs and develop faster with intelligent assistance for ETL authoring and Spark troubleshooting.


This terraform project sets up aws glue and scripts to read data fron rds and redshift, transform using spark nd send data to s3.
This also shows howto  setup glue workflow.

Example Terraform : https://github.com/SebastianUA/terraform/tree/master/aws/modules/glue

## Setting up Security groups for glue access tob redshift + rds

https://docs.aws.amazon.com/glue/latest/dg/setup-vpc-for-glue-access.html



## Transformations


### ApplyMapping
is a transformation used to perform column projection and convert between data types. In this example, we use it to unnest several fields, such as action.id, which we map to the top-level action.id field. We also cast the id column to a long.
![img](https://idk.dev/wp-content/uploads/2020/04/Simplify-data-pipelines-with-AWS-Glue-automatic-code-generation-and.png)

```python
medicare_output = medicare_src.apply_mapping(
    [('id, 'string', id, 'string'), 
    ('type, string, type', string),
    ('actor.id, 'int', actor.id', int),
    ('actor.login', 'string', actor.login', 'string'),
    ('actor.display_login', 'string', 'actor.display_login', 'string'),
    ('actor.gravatar_id', 'long', 'actor.gravatar_id', 'long'),
    ('actor.url', 'string','actor.url', 'string'),
    ('actor.avatar_url', 'string', 'actor.avatar_url', string)]
)
```

### Relationalize

converts a nested dataset stored in a DynamicFrameto a relational (rows and columns) format. Nested structures are unnested into top level columns and arrays decomposed into different tables with appropriate primary and foreign keys inserted. The result is a collection of DynamicFrames representing a set of tables that can be directly inserted into a relational database. More detail about relationalize can be found here.

```python
## An example relationalizing and writing to Redshift
dfc = history.relationalize("hist_root", redshift_temp_dir)
## Cycle through results and write to Redshift.
for df_name in dfc.keys():
    df = dfc.select(df_name)
    print "Writing to Redshift table: ", df_name, " ..."
    glueContext.write_dynamic_frame.from_jdbc_conf(frame = df, 
        catalog_connection = "redshift3", 
        connection_options = {"dbtable": df_name, "database": "testdb"}, 
        redshift_tmp_dir = redshift_temp_dir)
```

### Unbox

parses a string field of a certain type, such as JSON, into individual fields with their corresponding data types and store the result in a DynamicFrame. For example, you may have a CSV file with one field that is in JSON format {“a”: 3, “b”: “foo”, “c”: 1.2}. Unbox will reformat the JSON string into three distinct fields: an int, a string, and a double. The Unbox transformation is commonly used to replace costly Python User Defined Functions required to reformat data that may result in Apache Spark out of memory exceptions. The following example shows how to use Unbox:

```python
df_result = df_json.unbox('json', "json")
```

### ResolveChoice

AWS Glue Dynamic Frames support data where a column can have fields with different types. These columns are represented with Dynamic Frame’s choice type. For example, Dynamic Frame schema for the medicare dataset shows up as follows:

```sh
root
 |-- drg definition: string
 |-- provider id: choice
 |    |-- long
 |    |-- string
 |-- provider name: string
 |-- provider street address: string
```

This is because the “provider id” column could either be a long or string type. The Apache Spark Dataframe considers the whole dataset and is forced to cast it to the most general type, namely string. Dynamic Frames allow you to cast the type using the ResolveChoice transform. For example, you can cast the column to long type as follows.

```python
medicare_res = medicare_dynamicframe.resolveChoice(specs = [('provider id','cast:long')])
medicare_res.printSchema()

# root
#  |-- drg definition: string
#  |-- provider id: long
#  |-- provider name: string
#  |-- provider street address: string
```
This transform would also insert a null where the value was a string that could not be cast. As a result, the records with string type casted to null values can also be identified now. Alternatively, the choice type can also be cast to struct, which keeps values of both types.

## Build and orchestrate data pipelines using AWS Glue Workflows

AWS Glue Workflows provide a visual tool to author data pipelines by combining Glue crawlers for schema discovery, and Glue Spark and Python jobs to transform the data. Relationships can be defined and parameters passed between task nodes to enable users to build pipelines of varying complexity. Workflows can be scheduled to run on a schedule or triggered programmatically. You can track the progress of each node independently or the entire workflow making it easier to troubleshoot your pipelines.

A typical workflow for ETL workloads is organized as follows:

![img](https://idk.dev/wp-content/uploads/2020/04/1588185911_347_Simplify-data-pipelines-with-AWS-Glue-automatic-code-generation-and.png)

**Glue Python command** triggered manually, on a schedule, or on an external CloudWatch event. It would pre-process or list the partitions in Amazon S3 for a table under a base location. For example, a CloudTrail logs partition to process could be: s3://AWSLogs/ACCOUNTID/CloudTrail/REGION/YEAR/MONTH/DAY/HOUR/.The Python command can list all the regions and schedule crawlers to create different Glue Data Catalog tables on each region.

**Glue Crawlers** triggered next to populate new partitions for every hour in Glue Data Catalog for recently ingested in Amazon S3.

**Concurrent Glue ETL jobs** triggered to separately filter and process each partition or a group of partitions. For example, CloudTrail events corresponding to the last week can be read by a Glue ETL job by passing in the partition prefix as Glue job parameters and using Glue ETL push down predicates to just read all the partitions in that prefix.Partitioning and orchestrating concurrent Glue ETL jobs allows you to scale and reliably execute individual Apache Spark applications by processing only a subset of partitions in the Glue Data Catalog table. The transformed data can then be concurrently written back by all individual Glue ETL jobs to a common target table in Amazon S3 data lake, AWS Redshift or other databases.

Finally, a Glue Python command can be triggered to capture the completion status of the different Glue entities including Glue Crawlers, parallel Glue ETL jobs; and post-process or retry any failed components

## Executing SQL using SparkSQL in AWS Glue

### AWS Glue Data Catalog as Hive Compatible Metastore

The AWS Glue Data Catalog is a managed metadata repository compatible with the Apache Hive Metastore API. You can follow the detailed instructions here to configure your AWS Glue ETL jobs and development endpoints to use the Glue Data Catalog. You also need to add the Hive SerDes to the class path of AWS Glue Jobs to serialize/deserialize data for the corresponding formats. You can then natively run Apache Spark SQL queries against your tables stored in the Data Catalog.

The following example assumes that you have crawled the US legislators dataset available at s3://awsglue-datasets/examples/us-legislators. We’ll use the Spark shell running on AWS Glue developer endpoint to execute SparkSQL queries directly on the legislators’ tables cataloged in the AWS Glue Data Catalog.


```sql
>>> spark.sql("use legislators")
DataFrame[]
>>> spark.sql("show tables").show()
+-----------+------------------+-----------+
|   database|         tableName|isTemporary|
+-----------+------------------+-----------+
|legislators|        areas_json|      false|
|legislators|    countries_json|      false|
|legislators|       events_json|      false|
|legislators|  memberships_json|      false|
|legislators|organizations_json|      false|
|legislators|      persons_json|      false|

>>> spark.sql("select distinct organization_id from memberships_json").show()
+--------------------+
|     organization_id|
+--------------------+
|d56acebe-8fdc-47b...|
|8fa6c3d2-71dc-478...|
+--------------------+
```

A similar approach to the above would be to use AWS Glue DynamicFrame API to read the data from S3. The DynamicFrame is then converted to a Spark DataFrame using the toDF method. Next, a temporary view can be registered for DataFrame, which can be queried using SparkSQL. The key difference between the two approaches is the use of Hive SerDes for the first approach, and native Glue/Spark readers for the second approach. The use of native Glue/Spark provides the performance and flexibility benefits such as computation of the schema at runtime, schema evolution, and job bookmarks support for Glue Dynamic Frames.

```sql
>>> memberships = glueContext.create_dynamic_frame.from_catalog(database="legislators", table_name="memberships_json")
>>> memberships.toDF().createOrReplaceTempView("memberships")
>>> spark.sql("select distinct organization_id from memberships").show()
+--------------------+
|     organization_id|
+--------------------+
|d56acebe-8fdc-47b...|
|8fa6c3d2-71dc-478...|
+--------------------+
```

### Workflows and S3 Consistency

If you have a workflow of external processes ingesting data into S3, or upstream AWS Glue jobs generating input for a table used by downstream jobs in a workflow, you can encounter the following Apache Spark errors.

```sh
Caused by: org.apache.spark.SparkException: Job aborted due to stage failure: Task 10 in stage 16.0 failed 4 times, most recent failure: Lost task 10.3 in stage 16.0 (TID 761, ip-<>.ec2.internal, executor 1): 
java.io.FileNotFoundException: No such file or directory 's3://<bucket>/fileprefix-c000.snappy.parquet'
It is possible the underlying files have been updated.
You can explicitly invalidate the cache in Spark by running 
'REFRESH TABLE tableName' command in SQL or by recreating the Dataset/DataFrame involved.
```


These errors happen when the upstream jobs overwrite to the same S3 objects that the downstream jobs are concurrently listing or reading. This can also happen due to eventual consistency of S3 resulting in overwritten or deleted objects get updated at a later time when the downstream jobs are reading. A common manifestation of this error occurs when you are create a SparkSQL view and execute SQL queries in the downstream job. To avoid these errors, the best practice is to set up a workflow with upstream and downstream jobs scheduled at different times, and read/write to different S3 partitions based on time.

You can also enable the S3-optimized output committer for your Glue jobs by passing in a special job parameter: “–enable-s3-parquet-optimized-committer” set to true. This committer improves application performance by avoiding list and rename operations in Amazon S3 during job and task commit phases. It also avoids issues that can occur with Amazon S3’s eventual consistency during job and task commit phases, and helps to minimize task failures.

https://idk.dev/tutorials/ is really great.