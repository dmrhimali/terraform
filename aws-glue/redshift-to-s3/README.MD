Video on how to crawl redshift db:
https://www.youtube.com/watch?v=WWDbkHb3l9g
https://www.youtube.com/watch?v=1MdooeAb_VA


Assumes there is already a redshift cluster with a dev db with following queries executed: (i did this manually and used console query editor to rn sql. and noted down redshift sg and vpc to use in terraform as vars)

```sql
create schema dw;

drop table dw.member;
create table if not exists dw.member(
id integer not null,
name varchar(100) not null,
primary key(memberid));

create table if not exists dw.journey(
journeyid integer not null,
journeyname varchar(100) not null,
primary key(journeyid));
            
create table if not exists dw.member_journey(
journeyid integer not null,
memberid integer not null,
foreign key(journeyid) references dw.journey(journeyid),
foreign key(memberid) references dw.member(memberid),
primary key(memberid, journeyid));
            
delete from dw.member;
insert into dw.member(memberid, name) values (1,'sam') , (2,'paul'), (3,'tim');
delete from dw.journey;
insert into dw.journey values(10,'eat healthy'), (20,'midfullness'), (30,'exercise');
delete from dw.member_journey;
insert into dw.member_journey values (10,1), (20,2), (30,3);
            
select * from dw.journey;
```


Job code:

```python
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
## @args: [database = "glue_redshift_datastore", table_name = "dev_dw_member_journey", redshift_tmp_dir = TempDir, transformation_ctx = "datasource0"]
## @return: datasource0
## @inputs: []
print("Job Inititated!")
dev_dw_member_journey = glueContext.create_dynamic_frame.from_catalog(database = "catalog-database", table_name = "dev_dw_member_journey", redshift_tmp_dir="s3://dmrh-import-sensor-events-bucket/journeys/tmp")
print ("member-journey Count: ", dev_dw_member_journey.count())
print("schema:")
dev_dw_member_journey.printSchema()
print("Data:")
dev_dw_member_journey.toDF().show()

dev_dw_member = glueContext.create_dynamic_frame.from_catalog(database = "catalog-database", table_name = "dev_dw_member", redshift_tmp_dir="s3://dmrh-import-sensor-events-bucket/journeys/tmp")
print ("member Count: ", dev_dw_member.count())
print("schema:")
dev_dw_member.printSchema()
print("Data:")
dev_dw_member.toDF().show()

dev_dw_journey = glueContext.create_dynamic_frame.from_catalog(database = "catalog-database", table_name = "dev_dw_journey", redshift_tmp_dir="s3://dmrh-import-sensor-events-bucket/journeys/tmp")
print ("journey Count: ", dev_dw_journey.count())
print("schema:")
dev_dw_journey.printSchema()
print("Data:")
dev_dw_journey.toDF().show()
## @type: ApplyMapping
## @args: [mapping = [("journeyid", "int", "journeyid", "int"), ("memberid", "int", "memberid", "int")], transformation_ctx = "applymapping1"]
## @return: applymapping1
## @inputs: [frame = datasource0]

#applymapping1 = ApplyMapping.apply(frame = dev_dw_member_journey, mappings = [("journeyid", "int", "journeyid", "int"), ("memberid", "int", "memberid", "int")], transformation_ctx = "applymapping1")

# Join the frames
# journeys = dev_dw_journey.join(['journeyid'],['journeyid'],dev_dw_member_journey)
# print("journey join count :", journeys.count())
# members = dev_dw_member.join(['memberid'],['memberid'],dev_dw_member_journey)
# print("member join count :", journeys.count())
# member_journeys = members.join(['memberid'],['memberid'],journeys)
# print("member-journeys join count :", member_journeys.count())

# member_journeys = Join.apply(dev_dw_member_journey, dev_dw_member, 'memberid', 'memberid')
# member_journeys = member_journeys.relationalize("journey_root", "s3://dmrh-import-sensor-events-bucket/journeys/relationalize")
# print("relatioanlize keys:")
# dfc.keys()

member_journeys = Join.apply(dev_dw_journey,
                       Join.apply(dev_dw_member, dev_dw_member_journey, 'memberid', 'memberid'),
                       'journeyid', 'journeyid') #.drop_fields(['person_id', 'org_id'])
print "Count member_journeys: ", member_journeys.count()
member_journeys.printSchema()

spark_dataframe = member_journeys.toDF()
spark_dataframe.createOrReplaceTempView("spark_df")
print("relatioanlize keys:")
glueContext.sql("""
SELECT * 
FROM spark_df
LIMIT 15
""").show()

#member_journeys = Join.apply(dev_dw_journey, Join.apply(dev_dw_member_journey, dev_dw_member, 'memberid', 'memberid'), 'journeyid', 'journeyid')
print ("member-journey final Count: ", member_journeys.count())
dev_dw_member_journey.printSchema()

# Write out the dynamic frame into parquet in "legislator_history" directory
print("Writing to /journeys ...")
## @type: DataSink
## @args: [connection_type = "s3", connection_options = {"path": "s3://dmrh-import-sensor-events-bucket/journeys"}, format = "csv", transformation_ctx = "datasink2"]
## @return: datasink2
## @inputs: [frame = applymapping1]
datasink2 = glueContext.write_dynamic_frame.from_options(frame = member_journeys, connection_type = "s3", connection_options = {"path": "s3://dmrh-import-sensor-events-bucket/journeys"}, format = "csv", transformation_ctx = "datasink2")
job.commit()
```