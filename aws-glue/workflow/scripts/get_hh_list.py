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

    args = getResolvedOptions(sys.argv, ['TempDir','JOB_NAME', 'HH_LIST_CSV_FILENAME', 'HH_LIST_CSV_BUCKET', 'HH_LIST_CSV_BUCKET_PREFIX'])

    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args['JOB_NAME'], args)

    logger = glueContext.get_logger()
    logger.info("args = "+ str(args))

    ########################################################
    ##### get healthy habit list ###########################
    ########################################################
    genesis_action_df = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "genesis_public_action", transformation_ctx = "datasource0")
    genesis_action_df = genesis_action_df.toDF()
    genesis_action_df = genesis_action_df.selectExpr("id as action_id")
    logger.info("genesis_action_df data:")
    genesis_action_df.show()


    genesis_action_activities_df = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "genesis_public_action_activities", transformation_ctx = "datasource0")
    genesis_action_activities_df = genesis_action_activities_df.toDF()
    genesis_action_activities_df = genesis_action_activities_df.select("action_id","activity_type", "manually_entered")
    #WHERE aa.manually_entered != FALSE
    genesis_action_activities_df = genesis_action_activities_df.filter(F.col("manually_entered") != False)
    logger.info("genesis_action_activities_df data:")
    genesis_action_activities_df.show()

    genesis_thrive_category_df = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "genesis_public_thrive_category", transformation_ctx = "datasource0")
    genesis_thrive_category_df = genesis_thrive_category_df.toDF()
    genesis_thrive_category_df = genesis_thrive_category_df.selectExpr("id as thrive_category_id","status")
    #WHERE tc.status = 'Published'
    genesis_thrive_category_df = genesis_thrive_category_df.filter(F.col("status") == "Published")
    logger.info("genesis_thrive_category_df data:")
    genesis_thrive_category_df.show()

    genesis_tracker_df = glueContext.create_dynamic_frame.from_catalog(database = "journey-catalog-database", table_name = "genesis_public_tracker", transformation_ctx = "datasource0")
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
    ##### write csv to s3  #################################
    ########################################################

    HH_LIST_CSV_FILENAME = args['HH_LIST_CSV_FILENAME']
    HH_LIST_CSV_BUCKET = args['HH_LIST_CSV_BUCKET']
    HH_LIST_CSV_BUCKET_PREFIX = args['HH_LIST_CSV_BUCKET_PREFIX']

    #write csv to s3 (random generated name)
    hh_list_df = hh_list_df.repartition(1)
    columns = ['activity_type']
    datasink = hh_list_df
    datasink.write.format("csv").option("header", "true").mode("overwrite").save("s3://" +HH_LIST_CSV_BUCKET + "/" + HH_LIST_CSV_BUCKET_PREFIX)

    #rename csv file
    client = boto3.client('s3')
    response = client.list_objects(Bucket=HH_LIST_CSV_BUCKET,Prefix=HH_LIST_CSV_BUCKET_PREFIX+'/')

    temp_csv_key = response["Contents"][0]["Key"]
    logger.info("temp_csv_key = "+temp_csv_key) #'genesis_hh_list/part-00000-0860a3ec-a3c2-4e57-8c85-0b03c2a2d7af-c000.csv'

    temp_csv_filename = temp_csv_key[len(HH_LIST_CSV_BUCKET_PREFIX)+1:]

    if temp_csv_filename.startswith('part'):
        client.copy_object(Bucket=HH_LIST_CSV_BUCKET, CopySource=HH_LIST_CSV_BUCKET+'/'+ temp_csv_key, Key=HH_LIST_CSV_BUCKET_PREFIX +'/'+ HH_LIST_CSV_FILENAME)
        client.delete_object(Bucket=HH_LIST_CSV_BUCKET, Key=temp_csv_key)
        logger.info("written data to s3")

    job.commit()
