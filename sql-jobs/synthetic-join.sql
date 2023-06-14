SET 'state.checkpoints.dir' = 's3://state/checkpoints';
SET 'state.backend.incremental' = 'true';
SET 'execution.checkpointing.unaligned' = 'true';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.interval' = '360s';
SET 'execution.checkpointing.min-pause' = '60s';
-- SET 'sql-client.execution.result-mode'='TABLEAU';
SET 'parallelism.default' = '1';

ADD JAR '/opt/sql-client/lib/flink-sql-connector-kafka-1.16.0.jar';

-- SYNTHETIC DATA JOIN
DROP TABLE IF EXISTS DEVICES;
CREATE TABLE DEVICES (
    deviceId STRING,
    payload STRING
    ) WITH (
      'connector' = 'kafka',
      'topic' = 'DEVICES',
      'properties.bootstrap.servers' = 'kafka_broker:29092',
      'format' = 'json',
      'properties.group.id' = 'flink-devices',
      'scan.startup.mode' = 'earliest-offset'
);


DROP TABLE IF EXISTS EVENTS;
CREATE TABLE EVENTS (
    deviceId STRING,
    messageName STRING,
    payload STRING,
    `timestamp` TIMESTAMP WITH LOCAL TIME ZONE
    ) WITH (
      'connector' = 'kafka',
      'topic' = 'EVENTS',
      'properties.bootstrap.servers' = 'kafka_broker:29092',
      'format' = 'json',
      'properties.group.id' = 'flink-events',
      'scan.startup.mode' = 'earliest-offset',
      'json.timestamp-format.standard' = 'ISO-8601'
);



-- SINK TABLE
CREATE TABLE EVENTS_GEO (
  deviceId STRING
  , deviceCity STRING
  , deviceRegion STRING
  , deviceLocation STRING
  , messageName STRING
  , eventNotificationName STRING
  , `timestamp` TIMESTAMP WITH LOCAL TIME ZONE
  , eventTimestamp STRING
  ) WITH (
      'connector' = 'kafka',
      'topic' = 'EVENTS_GEO',
      'properties.bootstrap.servers' = 'kafka_broker:29092',
      'format' = 'json',
      'json.timestamp-format.standard' = 'ISO-8601',
      'json.fail-on-missing-field' = 'false',
      'json.ignore-parse-errors' = 'true'
);

-- QUERY
BEGIN STATEMENT
SET;

INSERT INTO EVENTS_GEO

-- PUT EVENTS ON THE MAP
WITH JOINED_DATA AS (
  SELECT
    /*+ BROADCAST(DEVICES) */ *
  FROM DEVICES
  INNER JOIN EVENTS 
  ON DEVICES.deviceId = EVENTS.deviceId
)
SELECT
  deviceId
  , JSON_VALUE(payload, '$.location.city') as deviceCity
  , JSON_VALUE(payload, '$.location.region') as deviceRegion
  , JSON_VALUE(payload, '$.location.loc') as deviceLocation
  , messageName
  , JSON_VALUE(payload0, '$.notificationName') as eventNotificationName
  , `timestamp`
  , JSON_VALUE(payload0, '$.eventTimestamp') as eventTimestamp
FROM JOINED_DATA;

END;