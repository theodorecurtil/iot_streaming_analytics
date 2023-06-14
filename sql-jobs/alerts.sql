SET 'state.checkpoints.dir' = 's3://state/checkpoints';
SET 'state.backend.incremental' = 'true';
SET 'execution.checkpointing.unaligned' = 'true';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.min-pause' = '10s';
SET 'sql-client.execution.result-mode'='TABLEAU';
SET 'parallelism.default' = '1';

ADD JAR '/opt/sql-client/lib/flink-sql-connector-kafka-1.16.0.jar';

-- SYNTHETIC EVENTS GEO
DROP TABLE IF EXISTS EVENTS_GEO;
CREATE TABLE EVENTS_GEO (
  deviceId STRING
  , deviceCity STRING
  , deviceRegion STRING
  , deviceLocation STRING
  , messageName STRING
  , eventNotificationName STRING
  , `timestamp` TIMESTAMP WITH LOCAL TIME ZONE
  , eventTimestamp TIMESTAMP(3) WITH LOCAL TIME ZONE
  , WATERMARK FOR eventTimestamp as eventTimestamp - INTERVAL '5' SECOND
  ) WITH (
      'connector' = 'kafka',
      'topic' = 'EVENTS_GEO',
      'properties.bootstrap.servers' = 'kafka_broker:29092',
      'format' = 'json',
      'json.timestamp-format.standard' = 'ISO-8601',
      'json.fail-on-missing-field' = 'false',
      'json.ignore-parse-errors' = 'true',
      'properties.group.id' = 'flink-events',
      'scan.startup.mode' = 'earliest-offset'
);

-- SINK TABLE
CREATE TABLE ALERTS (
  window_start TIMESTAMP(3)
  , window_end TIMESTAMP(3)
  , total_count_per_deviceid BIGINT
  , deviceId STRING
  , deviceLocation STRING
  , avg_error_count BIGINT
  , std_error_count BIGINT
  ) WITH (
      'connector' = 'kafka',
      'topic' = 'ALERTS',
      'properties.bootstrap.servers' = 'kafka_broker:29092',
      'format' = 'json',
      'json.timestamp-format.standard' = 'ISO-8601',
      'json.fail-on-missing-field' = 'false',
      'json.ignore-parse-errors' = 'true'
);


-- QUERY
BEGIN STATEMENT
SET;

INSERT INTO ALERTS

with a as(
SELECT window_start, window_end, COUNT(*) as total_count_per_deviceid, deviceId, deviceLocation
FROM TABLE(
  HOP(TABLE EVENTS_GEO, DESCRIPTOR(eventTimestamp), INTERVAL '30' SECONDS, INTERVAL '1' MINUTE)
  )
WHERE eventNotificationName = 'accessRejected'
GROUP BY window_start, window_end, deviceId, deviceLocation
), b as(
  select window_start, window_end, avg(total_count_per_deviceid) as avg_error_count, STDDEV_SAMP(total_count_per_deviceid) as std_error_count
  from a
  group by window_start, window_end
), c as(
  select *
  from a
  join b on a.window_start = b.window_start
) select window_start, window_end, total_count_per_deviceid, deviceId, deviceLocation, avg_error_count, std_error_count
  from c where total_count_per_deviceid > avg_error_count + 3*std_error_count + 5;

END;

