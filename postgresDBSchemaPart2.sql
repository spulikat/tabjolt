DROP TABLE IF EXISTS jmeter_data;
DROP TABLE IF EXISTS counter_data;
DROP TABLE IF EXISTS counter_groups;
DROP TABLE IF EXISTS counter_instances;
DROP TABLE IF EXISTS counters;
DROP TABLE IF EXISTS hosts;
DROP TABLE IF EXISTS jmeter_groups;
DROP TABLE IF EXISTS test_name;
DROP TABLE IF EXISTS thread_name;
DROP TABLE IF EXISTS boolean_lookup_table;
DROP TABLE IF EXISTS test_runs;

-- -----------------------------------------------------
-- Table PerfResults.boolean_lookup_table
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS boolean_lookup_table (
  id smallint NOT NULL,
  value boolean NOT NULL,
  CONSTRAINT boolean_lookup_table_pkey PRIMARY KEY (id)
);

insert into boolean_lookup_table (id, value) values (0, false);
insert into boolean_lookup_table (id, value) values (1, true);

-- -----------------------------------------------------
-- Table PerfResults.test_runs
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS test_runs (
  id serial NOT NULL,
  owner character varying(128) DEFAULT NULL::character varying,
  description character varying(255) DEFAULT NULL::character varying,
  environment character varying(64) DEFAULT NULL::character varying,
  time_start timestamp without time zone NOT NULL,
  time_end timestamp without time zone NOT NULL,
  total_samples integer,
  error_rate double precision,
  response_time_90_percentile integer,
  response_time_95_percentile integer,
  response_time_average double precision,
  success_response_time_90_percentile integer,
  success_response_time_95_percentile integer,
  success_response_time_average double precision,
  tps_average double precision,
  success_tps_average double precision,
  max_user_load smallint,
  duration integer,
  do_not_purge boolean NOT NULL DEFAULT false,
  CONSTRAINT test_runs_pkey PRIMARY KEY (id)
);


-- -----------------------------------------------------
-- Table PerfResults.hosts
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS hosts (
  id serial NOT NULL,
  hostname character varying(255) NOT NULL,
  domain character varying(255) DEFAULT NULL::character varying,
  ip character varying(255) DEFAULT NULL::character varying,
  CONSTRAINT hosts_pkey PRIMARY KEY (id)
);


-- -----------------------------------------------------
-- Table PerfResults.counters
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS counters (
  id serial NOT NULL,
  description character varying(255) NOT NULL,
  CONSTRAINT counters_pkey PRIMARY KEY (id)
);

-- -----------------------------------------------------
-- Table PerfResults.counter_instances
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS counter_instances (
  id serial NOT NULL,
  description character varying(255) NOT NULL,
  CONSTRAINT counter_instances_pkey PRIMARY KEY (id)
);

-- -----------------------------------------------------
-- Table PerfResults.counter_groups
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS counter_groups (
  id serial NOT NULL,
  description character varying(255) NOT NULL,
  CONSTRAINT counter_groups_pkey PRIMARY KEY (id)
);

-- -----------------------------------------------------
-- Table PerfResults.counter_data
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS counter_data (
  id serial NOT NULL,
  test_run_id integer NOT NULL,
  host_id integer NOT NULL,
  counter_id integer NOT NULL,
  counter_group_id integer NOT NULL,
  counter_instance_id integer NOT NULL,
  "timestamp" timestamp without time zone NOT NULL,
  value double precision NOT NULL,
  CONSTRAINT counter_data_pkey PRIMARY KEY (id),
  CONSTRAINT counter_data_counter_group_id_fkey FOREIGN KEY (counter_group_id)
      REFERENCES counter_groups (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT counter_data_counter_id_fkey FOREIGN KEY (counter_id)
      REFERENCES counters (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT counter_data_counter_instance_id_fkey FOREIGN KEY (counter_instance_id)
      REFERENCES counter_instances (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT counter_data_host_id_fkey FOREIGN KEY (host_id)
      REFERENCES hosts (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT counter_data_test_run_id_fkey FOREIGN KEY (test_run_id)
      REFERENCES test_runs (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
);

DROP INDEX IF EXISTS idx_test_run_id;

CREATE INDEX idx_test_run_id
  ON counter_data
  USING btree
  (test_run_id, id, host_id, counter_id, counter_group_id, counter_instance_id, "timestamp", value);


-- -----------------------------------------------------
-- Table PerfResults.test_name
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS test_name (
   id serial NOT NULL,
  ztest_name character varying(254) NOT NULL,
  is_parent boolean NOT NULL DEFAULT false,
  CONSTRAINT test_name_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_test_name_test_name_id
  ON test_name
  USING btree
  (id, ztest_name COLLATE pg_catalog."default", is_parent);

-- -----------------------------------------------------
-- Table PerfResults.thread_group
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS thread_group (
  id serial NOT NULL,
  thread_group character varying(128) NOT NULL,
  CONSTRAINT thread_group_pkey PRIMARY KEY (id)
);

-- -----------------------------------------------------
-- Table PerfResults.jmeter_group
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS jmeter_groups (
  id serial NOT NULL,
  is_group boolean DEFAULT false,
  CONSTRAINT jmeter_groups_pkey PRIMARY KEY (id)
);

-- -----------------------------------------------------
-- Table PerfResults.jmeter_data
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS jmeter_data (
  id serial NOT NULL,
  test_run_id integer NOT NULL,
  group_id integer NOT NULL,
  time_request integer NOT NULL,
  time_latency integer,
  time_gmt timestamp without time zone NOT NULL,
  response_code smallint,
  response_message character varying(1024) DEFAULT NULL::character varying,
  bytes integer,
  total_active_thread smallint NOT NULL,
  thread_group_active_thread smallint NOT NULL,
  test_name_id integer NOT NULL,
  thread_group_id integer NOT NULL,
  thread_num smallint NOT NULL,
  success smallint NOT NULL,
  CONSTRAINT jmeter_data_pkey PRIMARY KEY (id),
  CONSTRAINT jmeter_data_group_id_fkey FOREIGN KEY (group_id)
      REFERENCES jmeter_groups (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT jmeter_data_success_fkey FOREIGN KEY (success)
      REFERENCES boolean_lookup_table (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT jmeter_data_test_name_id_fkey FOREIGN KEY (test_name_id)
      REFERENCES test_name (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT jmeter_data_test_run_id_fkey FOREIGN KEY (test_run_id)
      REFERENCES test_runs (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT jmeter_data_thread_group_id_fkey FOREIGN KEY (thread_group_id)
      REFERENCES thread_group (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
);

DROP INDEX IF EXISTS idx_jmeter_data_test_run_id;

  CREATE INDEX idx_jmeter_data_test_run_id
  ON jmeter_data
  USING btree
  (test_run_id, test_name_id, time_request, time_gmt, success);



  -- -----------------------------------------------------
-- function sp_insert_test_name_id
-- -----------------------------------------------------

DROP FUNCTION IF EXISTS sp_insert_test_name_id(character varying, boolean);

CREATE OR REPLACE FUNCTION sp_insert_test_name_id(testname character varying, isparent boolean)
  RETURNS integer AS
$BODY$
	DECLARE tempId INTEGER;
	BEGIN
		SELECT id into tempId FROM test_name WHERE ztest_name=testName AND is_parent=isParent;
		IF tempId IS NULL THEN
			INSERT INTO test_name (ztest_name, is_parent) values (testName, isParent);
			SELECT LASTVAL() INTO tempId;
		END IF;
		RETURN tempId;
	END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


-- -----------------------------------------------------
-- function sp_insert_thread_group
-- -----------------------------------------------------

DROP FUNCTION IF EXISTS sp_insert_thread_group(character varying);

CREATE OR REPLACE FUNCTION sp_insert_thread_group(threadgroup character varying)
  RETURNS integer AS
$BODY$
	DECLARE tempId INTEGER;
	BEGIN
		SELECT id into tempId FROM thread_group WHERE thread_group=threadGroup;
		IF tempId IS NULL THEN
			INSERT INTO thread_group (thread_group) values (threadGroup);
			SELECT LASTVAL() INTO tempId;
		END IF;
		RETURN tempId;
	END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- -----------------------------------------------------
-- function sp_insert_thread_group
-- -----------------------------------------------------

DROP FUNCTION IF EXISTS sp_update_test_run_stats(integer);

CREATE OR REPLACE FUNCTION sp_update_test_run_stats(runid integer)
  RETURNS void AS
$BODY$
	DECLARE totalSamples INTEGER;
	DECLARE successTotalSamples INTEGER;
	DECLARE totalSeconds FLOAT;
	DECLARE percentile90th FLOAT;
	DECLARE percentile95th FLOAT;
	DECLARE successPercentile90th FLOAT;
	DECLARE successPercentile95th FLOAT;
	DECLARE errorRate DOUBLE PRECISION;
	BEGIN
		-- total samples
		SELECT COUNT(*) INTO totalSamples
		FROM jmeter_data
		INNER JOIN test_name
		ON jmeter_data.test_name_id=test_name.id
		WHERE is_parent=true and test_run_id=runId;

		UPDATE test_runs
		SET total_samples=totalSamples
		WHERE id=runId;

		-- error rate
		IF totalSamples>0 THEN
			SELECT (SELECT CAST(COUNT(*) AS DOUBLE PRECISION)
				 FROM jmeter_data
				 INNER JOIN test_name
				 ON jmeter_data.test_name_id=test_name.id
				 WHERE is_parent=true and test_run_id=runId and success=0 ) / CAST(totalSamples AS DOUBLE PRECISION) INTO errorRate;

			UPDATE test_runs
			SET error_rate=errorRate
			WHERE id=runId;
		END IF;

		-- 90 percentile
		SELECT totalSamples * 0.9 INTO percentile90th;
		UPDATE test_runs
		SET response_time_90_percentile=(
						SELECT time_request
		 				FROM jmeter_data
		                                INNER JOIN test_name ON jmeter_data.test_name_id=test_name.id
						WHERE is_parent=true and test_run_id=runId
						ORDER BY time_request LIMIT 1 OFFSET percentile90th)
	        WHERE id=runId;

	        -- 95 percentile
		SELECT totalSamples * 0.95 INTO percentile95th;
		UPDATE test_runs
		SET response_time_95_percentile=(
						SELECT time_request
		 				FROM jmeter_data
		                                INNER JOIN test_name ON jmeter_data.test_name_id=test_name.id
						WHERE is_parent=true and test_run_id=runId
						ORDER BY time_request LIMIT 1 OFFSET percentile95th)
	        WHERE id=runId;

		-- average response time
		UPDATE test_runs
		SET response_time_average=(
					   SELECT AVG(time_request)
					   FROM jmeter_data
					   INNER JOIN test_name
					   ON jmeter_data.test_name_id=test_name.id
					   WHERE is_parent=true and test_run_id=runId
					   )
		WHERE id=runId;

		-- 90 success percentile
		SELECT COUNT(*) INTO successTotalSamples
		FROM jmeter_data
		INNER JOIN test_name
		ON jmeter_data.test_name_id=test_name.id
		WHERE is_parent=true and success=1 and test_run_id=runId;

		SELECT successTotalSamples * 0.9 INTO successPercentile90th;
		SELECT successTotalSamples * 0.95 INTO successPercentile95th;

		UPDATE test_runs
		SET success_response_time_90_percentile=(
							SELECT time_request
							FROM jmeter_data
		                                        INNER JOIN test_name ON jmeter_data.test_name_id=test_name.id
							WHERE is_parent=true and success=1 and test_run_id=runId
							ORDER BY time_request LIMIT 1 OFFSET successPercentile90th)
                WHERE id=runId;

                -- 95 success percentile
                UPDATE test_runs
		SET success_response_time_95_percentile=(
							SELECT time_request
							FROM jmeter_data
		                                        INNER JOIN test_name ON jmeter_data.test_name_id=test_name.id
							WHERE is_parent=true and success=1 and test_run_id=runId
							ORDER BY time_request LIMIT 1 OFFSET successPercentile95th)
                WHERE id=runId;


		-- average response time success only
		UPDATE test_runs
		SET success_response_time_average=(
						   SELECT AVG(time_request)
						   FROM jmeter_data
						   INNER JOIN test_name
						   ON jmeter_data.test_name_id=test_name.id
						   WHERE is_parent=true and success=1 and test_run_id=runId
						   )
		WHERE id=runId;

                -- average TPS
		SELECT EXTRACT(EPOCH FROM MAX(time_gmt) - min(time_gmt)) INTO totalSeconds
		FROM jmeter_data
		INNER JOIN test_name
		ON jmeter_data.test_name_id=test_name.id
		WHERE is_parent=true and test_run_id=runId;

		UPDATE test_runs
		SET TPS_average=(
		             totalSamples/totalseconds
			 )
		WHERE id=runId;


		-- average successful TPS
		UPDATE test_runs
		SET success_TPS_average=(
					successTotalSamples/totalseconds
					)
		WHERE id=runId;




		-- MAX user load
		UPDATE test_runs
		SET max_user_load=(
		     		  SELECT MAX(total_active_thread)
				  FROM jmeter_data
				  INNER JOIN test_name
				  ON jmeter_data.test_name_id=test_name.id
				  WHERE is_parent=true and test_run_id=runId
				  )
		WHERE id=runId;

		-- duration
		UPDATE test_runs
		SET duration=(
			  SELECT totalseconds
			 )
		WHERE id=runId;

	END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION sp_update_test_run_stats(integer)
  OWNER TO postgres;
