from pyspark.sql import SparkSession


spark = SparkSession.builder.getOrCreate()


def ensure_silver_table(table_name: str) -> None:
    spark.sql(
        f"""
        CREATE TABLE IF NOT EXISTS {table_name} (
            thread_id STRING,
            email_id STRING,
            status STRING,
            record_json STRING,
            latest_update BOOLEAN,
            cdc_operation STRING,
            updated_by_flow STRING,
            correlation_id STRING,
            created_at STRING,
            last_modified STRING
        )
        USING DELTA
        """
    )
