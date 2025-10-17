--
-- PostgreSQL database dump
--

\restrict Ftz3Mn3ExeVaHgBFpjrGAnyD7h51R9WCPG0dQVXWJddfHPIWN5TQnfQAdbFXiba

-- Dumped from database version 18.0 (Postgres.app)
-- Dumped by pg_dump version 18.0 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: coverage_stats_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.coverage_stats_source AS ENUM (
    'query',
    'metro'
);


--
-- Name: goal_frequency; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.goal_frequency AS ENUM (
    'day',
    'week',
    'month'
);


--
-- Name: goal_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.goal_type AS ENUM (
    'earnings'
);


--
-- Name: oban_job_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oban_job_state AS ENUM (
    'available',
    'scheduled',
    'executing',
    'retryable',
    'completed',
    'discarded',
    'cancelled'
);


--
-- Name: timespan_calc_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.timespan_calc_method AS ENUM (
    'user_facing'
);


--
-- Name: date_bin(interval, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.date_bin(stride interval, source_ts timestamp with time zone, base_ts timestamp with time zone) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT
      base_ts
      + FLOOR(EXTRACT(epoch FROM source_ts - base_ts) / EXTRACT(epoch FROM stride))::BIGINT
      * stride;
    $$;


--
-- Name: oban_jobs_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oban_jobs_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  channel text;
  notice json;
BEGIN
  IF NEW.state = 'available' THEN
    channel = 'public.oban_insert';
    notice = json_build_object('queue', NEW.queue);

    PERFORM pg_notify(channel, notice::text);
  END IF;

  RETURN NULL;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accepted_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accepted_terms (
    id bigint NOT NULL,
    accepted_at timestamp(0) without time zone,
    terms_id bigint,
    user_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: accepted_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accepted_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accepted_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accepted_terms_id_seq OWNED BY public.accepted_terms.id;


--
-- Name: activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activities (
    id bigint NOT NULL,
    activity_id text NOT NULL,
    user_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    activity_data jsonb,
    date timestamp(0) without time zone,
    deleted boolean DEFAULT false,
    working_day_start date,
    working_day_end date,
    service_class public.citext,
    employer public.citext,
    employer_service public.citext,
    data_partner public.citext,
    earning_type public.citext,
    currency public.citext,
    income_rate_hour_cents integer,
    income_rate_mile_cents integer,
    status public.citext,
    distance numeric,
    distance_unit public.citext,
    duration_seconds integer,
    timezone public.citext,
    timestamp_start timestamp(0) without time zone,
    timestamp_end timestamp(0) without time zone,
    timestamp_request timestamp(0) without time zone,
    timestamp_accept timestamp(0) without time zone,
    timestamp_cancel timestamp(0) without time zone,
    timestamp_pickup timestamp(0) without time zone,
    timestamp_dropoff timestamp(0) without time zone,
    timestamp_shift_start timestamp(0) without time zone,
    timestamp_shift_end timestamp(0) without time zone,
    timestamp_work_start timestamp(0) without time zone,
    timestamp_work_end timestamp(0) without time zone,
    is_pool boolean,
    is_rush boolean,
    is_surge boolean,
    start_location_geometry public.geometry,
    start_location_address public.citext,
    end_location_geometry public.geometry,
    end_location_address public.citext,
    earnings_pay_cents integer,
    earnings_tip_cents integer,
    earnings_bonus_cents integer,
    earnings_total_cents integer,
    charges_fees_cents integer,
    charges_taxes_cents integer,
    charges_total_cents integer,
    tasks_total integer,
    notification_required boolean,
    notified_on timestamp(0) without time zone,
    metro_area_id bigint,
    employer_id bigint,
    service_class_id bigint,
    employer_service_class_id bigint,
    timestamp_insights_work_start timestamp(0) without time zone
);


--
-- Name: activities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activities_id_seq OWNED BY public.activities.id;


--
-- Name: activity_hours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_hours (
    id bigint NOT NULL,
    activity_id bigint NOT NULL,
    date_local date NOT NULL,
    week_start_date date NOT NULL,
    day_of_week integer NOT NULL,
    hour_local time(0) without time zone NOT NULL,
    percent_of_activity double precision NOT NULL,
    duration_seconds integer NOT NULL,
    earnings_total_cents integer NOT NULL,
    distance_miles numeric,
    deduction_mileage_cents integer,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: activity_hours_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activity_hours_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activity_hours_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activity_hours_id_seq OWNED BY public.activity_hours.id;


--
-- Name: campaign_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign_participants (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    campaign public.citext NOT NULL,
    presented_on_first timestamp(0) without time zone,
    presented_on_last timestamp(0) without time zone,
    dismissed_on timestamp(0) without time zone,
    dismissed_action public.citext,
    accepted_on timestamp(0) without time zone,
    accepted_action public.citext,
    postponed_until timestamp(0) without time zone,
    postponed_action public.citext,
    additional_data jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: campaign_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campaign_participants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaign_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campaign_participants_id_seq OWNED BY public.campaign_participants.id;


--
-- Name: community_insights_avg_hr_pay_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.community_insights_avg_hr_pay_stats (
    id bigint NOT NULL,
    week_start_date date NOT NULL,
    day_of_week integer NOT NULL,
    hour_local time(0) without time zone NOT NULL,
    employer_service_class_id bigint CONSTRAINT community_insights_avg_hr_pa_employer_service_class_id_not_null NOT NULL,
    metro_area_id bigint NOT NULL,
    count_activities integer NOT NULL,
    count_tasks integer NOT NULL,
    count_users integer NOT NULL,
    count_week_samples integer NOT NULL,
    week_sample_first date NOT NULL,
    week_sample_last date NOT NULL,
    duration_seconds integer NOT NULL,
    earnings_total_cents integer CONSTRAINT community_insights_avg_hr_pay_sta_earnings_total_cents_not_null NOT NULL,
    distance_miles numeric,
    deduction_mileage_cents integer,
    earnings_avg_hr_cents integer CONSTRAINT community_insights_avg_hr_pay_st_earnings_avg_hr_cents_not_null NOT NULL,
    earnings_avg_hr_cents_with_mileage integer CONSTRAINT community_insights_avg_hr_p_earnings_avg_hr_cents_with_not_null NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: community_insights_avg_hr_pay_stats_dsc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.community_insights_avg_hr_pay_stats_dsc (
    id bigint NOT NULL,
    week_start_date date CONSTRAINT community_insights_avg_hr_pay_stats_ds_week_start_date_not_null NOT NULL,
    day_of_week integer NOT NULL,
    hour_local time(0) without time zone NOT NULL,
    employer_service_class_id bigint CONSTRAINT community_insights_avg_hr_p_employer_service_class_id_not_null1 NOT NULL,
    metro_area_id bigint NOT NULL,
    count_activities integer CONSTRAINT community_insights_avg_hr_pay_stats_d_count_activities_not_null NOT NULL,
    count_tasks integer NOT NULL,
    count_users integer NOT NULL,
    count_week_samples integer CONSTRAINT community_insights_avg_hr_pay_stat_count_week_samples_not_null1 NOT NULL,
    week_sample_first date CONSTRAINT community_insights_avg_hr_pay_stats__week_sample_first_not_null NOT NULL,
    week_sample_last date CONSTRAINT community_insights_avg_hr_pay_stats_d_week_sample_last_not_null NOT NULL,
    duration_seconds integer CONSTRAINT community_insights_avg_hr_pay_stats_d_duration_seconds_not_null NOT NULL,
    earnings_total_cents integer CONSTRAINT community_insights_avg_hr_pay_st_earnings_total_cents_not_null1 NOT NULL,
    distance_miles numeric,
    deduction_mileage_cents integer,
    earnings_avg_hr_cents integer CONSTRAINT community_insights_avg_hr_pay_s_earnings_avg_hr_cents_not_null1 NOT NULL,
    earnings_avg_hr_cents_with_mileage integer CONSTRAINT community_insights_avg_hr__earnings_avg_hr_cents_with_not_null1 NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: community_insights_avg_hr_pay_stats_dsc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.community_insights_avg_hr_pay_stats_dsc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: community_insights_avg_hr_pay_stats_dsc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.community_insights_avg_hr_pay_stats_dsc_id_seq OWNED BY public.community_insights_avg_hr_pay_stats_dsc.id;


--
-- Name: community_insights_avg_hr_pay_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.community_insights_avg_hr_pay_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: community_insights_avg_hr_pay_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.community_insights_avg_hr_pay_stats_id_seq OWNED BY public.community_insights_avg_hr_pay_stats.id;


--
-- Name: crepe_collector; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crepe_collector (
    id bigint NOT NULL,
    app_name character varying(255) NOT NULL,
    app_package character varying(255) NOT NULL,
    description character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: crepe_collector_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crepe_collector_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crepe_collector_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crepe_collector_id_seq OWNED BY public.crepe_collector.id;


--
-- Name: crepe_data_field; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crepe_data_field (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    graph_query text NOT NULL,
    collector_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: crepe_data_field_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crepe_data_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crepe_data_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crepe_data_field_id_seq OWNED BY public.crepe_data_field.id;


--
-- Name: crepe_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crepe_event (
    id bigint NOT NULL,
    collected_at timestamp(0) without time zone NOT NULL,
    content text NOT NULL,
    data_field_id bigint NOT NULL,
    user_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: crepe_event_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crepe_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crepe_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crepe_event_id_seq OWNED BY public.crepe_event.id;


--
-- Name: devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.devices (
    id bigint NOT NULL,
    device_id public.citext NOT NULL,
    user_id bigint NOT NULL,
    device_name public.citext,
    app_version public.citext,
    device_platform public.citext,
    device_os public.citext,
    device_language public.citext,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    location_tracking_config_status public.citext,
    last_access_date date
);


--
-- Name: devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.devices_id_seq OWNED BY public.devices.id;


--
-- Name: employer_service_classes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employer_service_classes (
    id bigint NOT NULL,
    employer_id bigint NOT NULL,
    service_class_id bigint NOT NULL,
    name public.citext NOT NULL,
    reports_mileage boolean DEFAULT false NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: employer_service_classes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employer_service_classes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employer_service_classes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employer_service_classes_id_seq OWNED BY public.employer_service_classes.id;


--
-- Name: employers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employers (
    id bigint NOT NULL,
    name public.citext NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: employers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employers_id_seq OWNED BY public.employers.id;


--
-- Name: focus_group_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_group_memberships (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    focus_group_id bigint NOT NULL,
    enroll_date timestamp(0) without time zone NOT NULL,
    unenroll_date timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: focus_group_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.focus_group_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: focus_group_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.focus_group_memberships_id_seq OWNED BY public.focus_group_memberships.id;


--
-- Name: goal_measurements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goal_measurements (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    goal_id bigint NOT NULL,
    window_date date NOT NULL,
    performance_amount integer NOT NULL,
    performance_percent numeric NOT NULL,
    additional_info jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: goal_measurements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goal_measurements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: goal_measurements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goal_measurements_id_seq OWNED BY public.goal_measurements.id;


--
-- Name: goals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goals (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    type public.goal_type NOT NULL,
    frequency public.goal_frequency NOT NULL,
    sub_frequency public.citext DEFAULT 'all'::public.citext NOT NULL,
    start_date date NOT NULL,
    amount integer NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: goals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: goals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goals_id_seq OWNED BY public.goals.id;


--
-- Name: oban_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oban_jobs (
    id bigint NOT NULL,
    state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0 NOT NULL,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
    CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
    CONSTRAINT priority_range CHECK (((priority >= 0) AND (priority <= 3))),
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


--
-- Name: TABLE oban_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oban_jobs IS '11';


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oban_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oban_jobs_id_seq OWNED BY public.oban_jobs.id;


--
-- Name: oban_peers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.oban_peers (
    name text NOT NULL,
    node text NOT NULL,
    started_at timestamp without time zone NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


--
-- Name: points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.points (
    id bigint CONSTRAINT trip_points_id_not_null NOT NULL,
    geometry public.geometry,
    recorded_at timestamp without time zone,
    inserted_at timestamp(0) without time zone CONSTRAINT trip_points_inserted_at_not_null NOT NULL,
    updated_at timestamp(0) without time zone CONSTRAINT trip_points_updated_at_not_null NOT NULL,
    status text NOT NULL,
    user_id bigint NOT NULL,
    accuracy double precision,
    heading double precision,
    speed double precision,
    altitude double precision,
    battery_level double precision,
    battery_is_charging boolean,
    activity_type text,
    activity_confidence double precision,
    is_moving boolean,
    device_id bigint
);


--
-- Name: population_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.population_members (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    population_type public.citext NOT NULL,
    population public.citext NOT NULL,
    additional_data jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: population_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.population_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: population_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.population_members_id_seq OWNED BY public.population_members.id;


--
-- Name: region_county; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.region_county (
    id integer NOT NULL,
    name public.citext NOT NULL,
    region_id_state bigint NOT NULL,
    geometry public.geometry NOT NULL
);


--
-- Name: region_metro_area; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.region_metro_area (
    id integer NOT NULL,
    name public.citext NOT NULL,
    full_name public.citext NOT NULL,
    geometry public.geometry NOT NULL,
    count_workers integer,
    hourly_pay_stat_coverage_percent numeric,
    hourly_pay_stat_coverage_percent_rideshare numeric,
    hourly_pay_stat_coverage_percent_delivery numeric,
    hourly_pay_stat_coverage_count_workers integer,
    hourly_pay_stat_coverage_count_workers_rideshare integer,
    hourly_pay_stat_coverage_count_workers_delivery integer,
    hourly_pay_stat_coverage_count_employers integer,
    hourly_pay_stat_coverage_count_employers_rideshare integer,
    hourly_pay_stat_coverage_count_employers_delivery integer,
    hourly_pay_stat_coverage_count_jobs integer,
    hourly_pay_stat_coverage_count_jobs_rideshare integer,
    hourly_pay_stat_coverage_count_jobs_delivery integer,
    hourly_pay_stat_coverage_count_tasks integer,
    hourly_pay_stat_coverage_count_tasks_rideshare integer,
    hourly_pay_stat_coverage_count_tasks_delivery integer,
    hourly_pay_stat_coverage_percent_services numeric,
    hourly_pay_stat_coverage_count_workers_services integer,
    hourly_pay_stat_coverage_count_employers_services integer,
    hourly_pay_stat_coverage_count_jobs_services integer,
    hourly_pay_stat_coverage_count_tasks_services integer
);


--
-- Name: region_postal_code; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.region_postal_code (
    id integer NOT NULL,
    postal_code public.citext NOT NULL,
    region_id_metro_area bigint,
    region_id_state bigint NOT NULL,
    region_id_county bigint NOT NULL,
    geometry public.geometry NOT NULL
);


--
-- Name: region_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.region_state (
    id integer NOT NULL,
    name public.citext NOT NULL,
    abbrv public.citext NOT NULL,
    geometry public.geometry NOT NULL
);


--
-- Name: research_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.research_groups (
    id bigint NOT NULL,
    name text,
    description text,
    code text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: research_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.research_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: research_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.research_groups_id_seq OWNED BY public.research_groups.id;


--
-- Name: scheduled_shifts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduled_shifts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    start_day_of_week integer NOT NULL,
    start_time_local time(0) without time zone NOT NULL,
    duration_minutes integer NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: scheduled_shifts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scheduled_shifts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scheduled_shifts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scheduled_shifts_id_seq OWNED BY public.scheduled_shifts.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: service_classes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_classes (
    id bigint NOT NULL,
    name public.citext NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: service_classes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.service_classes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: service_classes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.service_classes_id_seq OWNED BY public.service_classes.id;


--
-- Name: shifts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shifts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    frontend_mileage double precision,
    deleted boolean DEFAULT false,
    device_id bigint
);


--
-- Name: shifts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shifts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shifts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shifts_id_seq OWNED BY public.shifts.id;


--
-- Name: terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.terms (
    id bigint NOT NULL,
    title text,
    text text,
    required_at timestamp(0) without time zone,
    user_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.terms_id_seq OWNED BY public.terms.id;


--
-- Name: timespan_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.timespan_allocations (
    id bigint NOT NULL,
    timespan_id bigint NOT NULL,
    start_time timestamp(0) without time zone NOT NULL,
    end_time timestamp(0) without time zone NOT NULL,
    activity_id bigint,
    duration_seconds integer NOT NULL,
    activity_extends_before boolean,
    activity_extends_after boolean,
    activity_coverage_percent numeric,
    device_miles numeric,
    device_miles_deduction_cents integer,
    device_miles_quality_percent numeric,
    platform_miles numeric,
    platform_miles_per_second numeric,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: timespan_allocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.timespan_allocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: timespan_allocations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.timespan_allocations_id_seq OWNED BY public.timespan_allocations.id;


--
-- Name: timespans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.timespans (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    work_date date NOT NULL,
    calc_method public.timespan_calc_method NOT NULL,
    start_time timestamp(0) without time zone NOT NULL,
    end_time timestamp(0) without time zone NOT NULL,
    duration_seconds integer NOT NULL,
    duration_seconds_engaged integer NOT NULL,
    shift_ids integer[],
    device_miles numeric,
    device_miles_engaged numeric,
    device_miles_deduction_cents integer,
    device_miles_deduction_cents_engaged integer,
    device_miles_quality_percent numeric,
    platform_miles numeric,
    platform_miles_engaged numeric,
    platform_miles_deduction_cents integer,
    platform_miles_deduction_cents_engaged integer,
    platform_miles_quality_percent numeric,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    selected_miles numeric,
    selected_miles_engaged numeric,
    selected_miles_deduction_cents integer,
    selected_miles_deduction_cents_engaged integer,
    selected_miles_quality_percent numeric
);


--
-- Name: timespans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.timespans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: timespans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.timespans_id_seq OWNED BY public.timespans.id;


--
-- Name: trip_points_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trip_points_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trip_points_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trip_points_id_seq OWNED BY public.points.id;


--
-- Name: user_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_actions (
    id bigint NOT NULL,
    user_id bigint,
    event text,
    recorded_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_actions_id_seq OWNED BY public.user_actions.id;


--
-- Name: user_gig_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_gig_accounts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    argyle_id public.citext NOT NULL,
    employer public.citext,
    is_connected boolean DEFAULT false NOT NULL,
    connection_has_errors boolean DEFAULT false NOT NULL,
    connection_status public.citext,
    connection_error_code public.citext,
    connection_error_message public.citext,
    connection_updated_at timestamp(0) without time zone,
    is_synced boolean DEFAULT false NOT NULL,
    activity_status public.citext,
    activity_count integer,
    activities_updated_at timestamp(0) without time zone,
    activity_date_min timestamp(0) without time zone,
    activity_date_max timestamp(0) without time zone,
    deleted boolean DEFAULT false NOT NULL,
    account_data jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_gig_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_gig_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_gig_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_gig_accounts_id_seq OWNED BY public.user_gig_accounts.id;


--
-- Name: user_service_identifiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_service_identifiers (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    service public.citext NOT NULL,
    identifiers text[] NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_service_identifiers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_service_identifiers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_service_identifiers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_service_identifiers_id_seq OWNED BY public.user_service_identifiers.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email public.citext NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    password_hash text,
    first_name text,
    last_name text,
    phone_number text,
    vehicle_make text,
    vehicle_model text,
    vehicle_year integer,
    service_names text[],
    contact_permission boolean,
    device_platform text,
    focus_group text,
    engine_type text,
    opted_out_of_data_sale_at timestamp without time zone,
    reset_password_token character varying(255),
    reset_password_token_expires_at timestamp without time zone,
    country text,
    postal_code text,
    role text,
    ethnicity text[],
    gender text,
    opted_out_of_push_notifications boolean DEFAULT false,
    car_ownership text,
    is_beta text,
    source text,
    deleted boolean DEFAULT false,
    enrolled_research_at timestamp(0) without time zone,
    unenrolled_research_at timestamp(0) without time zone,
    vehicle_type text,
    timezone_device text,
    timezone text,
    timezone_argyle text,
    country_argyle text,
    gender_argyle text,
    postal_code_argyle text,
    vehicle_make_argyle text,
    vehicle_model_argyle text,
    vehicle_year_argyle integer,
    argyle_accounts jsonb,
    argyle_token text,
    argyle_user_id text,
    remind_shift_start boolean DEFAULT false,
    remind_shift_end boolean DEFAULT false,
    referral_source_id bigint,
    opted_out_of_sensitive_data_use_at timestamp without time zone,
    is_demo_account boolean DEFAULT false,
    metro_area_id bigint
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: accepted_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accepted_terms ALTER COLUMN id SET DEFAULT nextval('public.accepted_terms_id_seq'::regclass);


--
-- Name: activities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities ALTER COLUMN id SET DEFAULT nextval('public.activities_id_seq'::regclass);


--
-- Name: activity_hours id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_hours ALTER COLUMN id SET DEFAULT nextval('public.activity_hours_id_seq'::regclass);


--
-- Name: campaign_participants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_participants ALTER COLUMN id SET DEFAULT nextval('public.campaign_participants_id_seq'::regclass);


--
-- Name: community_insights_avg_hr_pay_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_insights_avg_hr_pay_stats ALTER COLUMN id SET DEFAULT nextval('public.community_insights_avg_hr_pay_stats_id_seq'::regclass);


--
-- Name: community_insights_avg_hr_pay_stats_dsc id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_insights_avg_hr_pay_stats_dsc ALTER COLUMN id SET DEFAULT nextval('public.community_insights_avg_hr_pay_stats_dsc_id_seq'::regclass);


--
-- Name: crepe_collector id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crepe_collector ALTER COLUMN id SET DEFAULT nextval('public.crepe_collector_id_seq'::regclass);


--
-- Name: crepe_data_field id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crepe_data_field ALTER COLUMN id SET DEFAULT nextval('public.crepe_data_field_id_seq'::regclass);


--
-- Name: crepe_event id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crepe_event ALTER COLUMN id SET DEFAULT nextval('public.crepe_event_id_seq'::regclass);


--
-- Name: devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devices ALTER COLUMN id SET DEFAULT nextval('public.devices_id_seq'::regclass);


--
-- Name: employer_service_classes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employer_service_classes ALTER COLUMN id SET DEFAULT nextval('public.employer_service_classes_id_seq'::regclass);


--
-- Name: employers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employers ALTER COLUMN id SET DEFAULT nextval('public.employers_id_seq'::regclass);


--
-- Name: focus_group_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_group_memberships ALTER COLUMN id SET DEFAULT nextval('public.focus_group_memberships_id_seq'::regclass);


--
-- Name: goal_measurements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_measurements ALTER COLUMN id SET DEFAULT nextval('public.goal_measurements_id_seq'::regclass);


--
-- Name: goals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals ALTER COLUMN id SET DEFAULT nextval('public.goals_id_seq'::regclass);


--
-- Name: oban_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs ALTER COLUMN id SET DEFAULT nextval('public.oban_jobs_id_seq'::regclass);


--
-- Name: points id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points ALTER COLUMN id SET DEFAULT nextval('public.trip_points_id_seq'::regclass);


--
-- Name: population_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.population_members ALTER COLUMN id SET DEFAULT nextval('public.population_members_id_seq'::regclass);


--
-- Name: research_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.research_groups ALTER COLUMN id SET DEFAULT nextval('public.research_groups_id_seq'::regclass);


--
-- Name: scheduled_shifts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_shifts ALTER COLUMN id SET DEFAULT nextval('public.scheduled_shifts_id_seq'::regclass);


--
-- Name: service_classes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_classes ALTER COLUMN id SET DEFAULT nextval('public.service_classes_id_seq'::regclass);


--
-- Name: shifts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts ALTER COLUMN id SET DEFAULT nextval('public.shifts_id_seq'::regclass);


--
-- Name: terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms ALTER COLUMN id SET DEFAULT nextval('public.terms_id_seq'::regclass);


--
-- Name: timespan_allocations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timespan_allocations ALTER COLUMN id SET DEFAULT nextval('public.timespan_allocations_id_seq'::regclass);


--
-- Name: timespans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timespans ALTER COLUMN id SET DEFAULT nextval('public.timespans_id_seq'::regclass);


--
-- Name: user_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_actions ALTER COLUMN id SET DEFAULT nextval('public.user_actions_id_seq'::regclass);


--
-- Name: user_gig_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_gig_accounts ALTER COLUMN id SET DEFAULT nextval('public.user_gig_accounts_id_seq'::regclass);


--
-- Name: user_service_identifiers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_service_identifiers ALTER COLUMN id SET DEFAULT nextval('public.user_service_identifiers_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: accepted_terms accepted_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accepted_terms
    ADD CONSTRAINT accepted_terms_pkey PRIMARY KEY (id);


--
-- Name: activities activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: activity_hours activity_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_hours
    ADD CONSTRAINT activity_hours_pkey PRIMARY KEY (id);


--
-- Name: campaign_participants campaign_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_participants
    ADD CONSTRAINT campaign_participants_pkey PRIMARY KEY (id);


--
-- Name: community_insights_avg_hr_pay_stats_dsc community_insights_avg_hr_pay_stats_dsc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_insights_avg_hr_pay_stats_dsc
    ADD CONSTRAINT community_insights_avg_hr_pay_stats_dsc_pkey PRIMARY KEY (id);


--
-- Name: community_insights_avg_hr_pay_stats community_insights_avg_hr_pay_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_insights_avg_hr_pay_stats
    ADD CONSTRAINT community_insights_avg_hr_pay_stats_pkey PRIMARY KEY (id);


--
-- Name: crepe_collector crepe_collector_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crepe_collector
    ADD CONSTRAINT crepe_collector_pkey PRIMARY KEY (id);


--
-- Name: crepe_data_field crepe_data_field_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crepe_data_field
    ADD CONSTRAINT crepe_data_field_pkey PRIMARY KEY (id);


--
-- Name: crepe_event crepe_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crepe_event
    ADD CONSTRAINT crepe_event_pkey PRIMARY KEY (id);


--
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (id);


--
-- Name: employer_service_classes employer_service_classes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employer_service_classes
    ADD CONSTRAINT employer_service_classes_pkey PRIMARY KEY (id);


--
-- Name: employers employers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employers
    ADD CONSTRAINT employers_pkey PRIMARY KEY (id);


--
-- Name: focus_group_memberships focus_group_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_group_memberships
    ADD CONSTRAINT focus_group_memberships_pkey PRIMARY KEY (id);


--
-- Name: goal_measurements goal_measurements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_measurements
    ADD CONSTRAINT goal_measurements_pkey PRIMARY KEY (id);


--
-- Name: goals goals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_pkey PRIMARY KEY (id);


--
-- Name: oban_jobs oban_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs
    ADD CONSTRAINT oban_jobs_pkey PRIMARY KEY (id);


--
-- Name: oban_peers oban_peers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_peers
    ADD CONSTRAINT oban_peers_pkey PRIMARY KEY (name);


--
-- Name: population_members population_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.population_members
    ADD CONSTRAINT population_members_pkey PRIMARY KEY (id);


--
-- Name: region_county region_county_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_county
    ADD CONSTRAINT region_county_pkey PRIMARY KEY (id);


--
-- Name: region_metro_area region_metro_area_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_metro_area
    ADD CONSTRAINT region_metro_area_pkey PRIMARY KEY (id);


--
-- Name: region_postal_code region_postal_code_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_postal_code
    ADD CONSTRAINT region_postal_code_pkey PRIMARY KEY (id);


--
-- Name: region_state region_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_state
    ADD CONSTRAINT region_state_pkey PRIMARY KEY (id);


--
-- Name: research_groups research_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.research_groups
    ADD CONSTRAINT research_groups_pkey PRIMARY KEY (id);


--
-- Name: scheduled_shifts scheduled_shifts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_shifts
    ADD CONSTRAINT scheduled_shifts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: service_classes service_classes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_classes
    ADD CONSTRAINT service_classes_pkey PRIMARY KEY (id);


--
-- Name: shifts shifts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_pkey PRIMARY KEY (id);


--
-- Name: terms terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms
    ADD CONSTRAINT terms_pkey PRIMARY KEY (id);


--
-- Name: timespan_allocations timespan_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timespan_allocations
    ADD CONSTRAINT timespan_allocations_pkey PRIMARY KEY (id);


--
-- Name: timespans timespans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timespans
    ADD CONSTRAINT timespans_pkey PRIMARY KEY (id);


--
-- Name: points trip_points_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points
    ADD CONSTRAINT trip_points_pkey PRIMARY KEY (id);


--
-- Name: user_actions user_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_actions
    ADD CONSTRAINT user_actions_pkey PRIMARY KEY (id);


--
-- Name: user_gig_accounts user_gig_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_gig_accounts
    ADD CONSTRAINT user_gig_accounts_pkey PRIMARY KEY (id);


--
-- Name: user_service_identifiers user_service_identifiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_service_identifiers
    ADD CONSTRAINT user_service_identifiers_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: accepted_terms_user_id_terms_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX accepted_terms_user_id_terms_id_index ON public.accepted_terms USING btree (user_id, terms_id);


--
-- Name: activities_activity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX activities_activity_id_index ON public.activities USING btree (activity_id);


--
-- Name: activities_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_date_index ON public.activities USING btree (date);


--
-- Name: activities_employer_service_class_id_metro_area_deleted_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX activities_employer_service_class_id_metro_area_deleted_id ON public.activities USING btree (employer_service_class_id, metro_area_id, deleted, id);


--
-- Name: activities_index_metro_day_deleted_user_employer_service_class; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_index_metro_day_deleted_user_employer_service_class ON public.activities USING btree (metro_area_id, working_day_start, deleted, user_id, employer_service_class_id);


--
-- Name: activities_index_user_id_working_day_start_deleted_earning_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_index_user_id_working_day_start_deleted_earning_type ON public.activities USING btree (user_id, working_day_start, deleted, earning_type, status) INCLUDE (timezone);


--
-- Name: activities_user_id_deleted_notification_required; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_user_id_deleted_notification_required ON public.activities USING btree (user_id, deleted, notification_required);


--
-- Name: activities_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_user_id_index ON public.activities USING btree (user_id);


--
-- Name: activities_user_id_working_day_end_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_user_id_working_day_end_index ON public.activities USING btree (user_id, working_day_end, earning_type, status) INCLUDE (working_day_start, deleted);


--
-- Name: activities_user_id_working_day_start_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_user_id_working_day_start_index ON public.activities USING btree (user_id, working_day_start, earning_type, status) INCLUDE (working_day_end, deleted);


--
-- Name: activities_user_notified_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_user_notified_on ON public.activities USING btree (user_id, notified_on);


--
-- Name: activities_working_day_start_id_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX activities_working_day_start_id_user_id ON public.activities USING btree (working_day_start, id, user_id);


--
-- Name: activity_hours_ak; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX activity_hours_ak ON public.activity_hours USING btree (activity_id, date_local, hour_local);


--
-- Name: activity_hours_index_week_start_date_day_of_week_hour_local; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_hours_index_week_start_date_day_of_week_hour_local ON public.activity_hours USING btree (week_start_date, day_of_week, hour_local);


--
-- Name: activity_hours_week_start_date_activity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_hours_week_start_date_activity_id_index ON public.activity_hours USING btree (week_start_date, activity_id);


--
-- Name: campaign_participants_user_campaign_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX campaign_participants_user_campaign_key ON public.campaign_participants USING btree (user_id, campaign);


--
-- Name: community_insights_avg_hr_pay_stats_ak; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX community_insights_avg_hr_pay_stats_ak ON public.community_insights_avg_hr_pay_stats USING btree (metro_area_id, week_start_date, employer_service_class_id, day_of_week, hour_local);


--
-- Name: community_insights_avg_hr_pay_stats_dsc_ak; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX community_insights_avg_hr_pay_stats_dsc_ak ON public.community_insights_avg_hr_pay_stats_dsc USING btree (metro_area_id, week_start_date, employer_service_class_id, day_of_week, hour_local);


--
-- Name: crepe_collector_app_package_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX crepe_collector_app_package_index ON public.crepe_collector USING btree (app_package);


--
-- Name: crepe_data_field_collector_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX crepe_data_field_collector_id_index ON public.crepe_data_field USING btree (collector_id);


--
-- Name: crepe_data_field_collector_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX crepe_data_field_collector_name_index ON public.crepe_data_field USING btree (collector_id, name);


--
-- Name: crepe_data_field_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX crepe_data_field_name_index ON public.crepe_data_field USING btree (name);


--
-- Name: crepe_event_collected_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX crepe_event_collected_at_index ON public.crepe_event USING btree (collected_at);


--
-- Name: crepe_event_data_field_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX crepe_event_data_field_id_index ON public.crepe_event USING btree (data_field_id);


--
-- Name: crepe_event_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX crepe_event_user_id_index ON public.crepe_event USING btree (user_id);


--
-- Name: devices_user_device_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX devices_user_device_id_key ON public.devices USING btree (user_id, device_id);


--
-- Name: employer_service_classes_service_class_id_employer_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX employer_service_classes_service_class_id_employer_id_index ON public.employer_service_classes USING btree (service_class_id, employer_id);


--
-- Name: employers_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX employers_name_index ON public.employers USING btree (name);


--
-- Name: focus_group_memberships_ak; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX focus_group_memberships_ak ON public.focus_group_memberships USING btree (user_id, focus_group_id, enroll_date);


--
-- Name: goal_measurements_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX goal_measurements_key ON public.goal_measurements USING btree (goal_id, window_date);


--
-- Name: goal_measurements_user_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX goal_measurements_user_key ON public.goal_measurements USING btree (user_id, goal_id, window_date);


--
-- Name: goals_unique_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX goals_unique_key ON public.goals USING btree (user_id, type, frequency, start_date, sub_frequency);


--
-- Name: oban_jobs_args_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_args_index ON public.oban_jobs USING gin (args);


--
-- Name: oban_jobs_meta_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_meta_index ON public.oban_jobs USING gin (meta);


--
-- Name: oban_jobs_state_queue_priority_scheduled_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_index ON public.oban_jobs USING btree (state, queue, priority, scheduled_at, id);


--
-- Name: points_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX points_device_id ON public.points USING btree (device_id);


--
-- Name: points_recorded_at_date_user_id_working; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX points_recorded_at_date_user_id_working ON public.points USING btree (((recorded_at)::date), user_id) WHERE (status = 'working'::text);


--
-- Name: points_user_id_recorded_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX points_user_id_recorded_at_index ON public.points USING btree (user_id, recorded_at);


--
-- Name: population_members_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX population_members_key ON public.population_members USING btree (user_id, population_type, population);


--
-- Name: region_county_region_id_state_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX region_county_region_id_state_name_index ON public.region_county USING btree (region_id_state, name);


--
-- Name: region_metro_area_full_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX region_metro_area_full_name_index ON public.region_metro_area USING btree (full_name);


--
-- Name: region_metro_area_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX region_metro_area_name_index ON public.region_metro_area USING btree (name);


--
-- Name: region_postal_code_postal_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX region_postal_code_postal_code_index ON public.region_postal_code USING btree (postal_code);


--
-- Name: region_state_abbrv_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX region_state_abbrv_index ON public.region_state USING btree (abbrv);


--
-- Name: region_state_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX region_state_name_index ON public.region_state USING btree (name);


--
-- Name: research_groups_code_lower_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX research_groups_code_lower_index ON public.research_groups USING btree (lower(code));


--
-- Name: scheduled_shifts_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX scheduled_shifts_user_id_index ON public.scheduled_shifts USING btree (user_id);


--
-- Name: service_classes_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX service_classes_name_index ON public.service_classes USING btree (name);


--
-- Name: shifts_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shifts_device_id ON public.shifts USING btree (device_id);


--
-- Name: shifts_user_deleted_start_end_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shifts_user_deleted_start_end_index ON public.shifts USING btree (user_id, deleted, start_time, end_time);


--
-- Name: terms_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX terms_user_id_index ON public.terms USING btree (user_id);


--
-- Name: timespan_allocations_activity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX timespan_allocations_activity_id_index ON public.timespan_allocations USING btree (activity_id);


--
-- Name: timespan_allocations_timespan_start_time_activity_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX timespan_allocations_timespan_start_time_activity_id_key ON public.timespan_allocations USING btree (timespan_id, start_time, activity_id);


--
-- Name: timespans_user_calc_method_start_time_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX timespans_user_calc_method_start_time_key ON public.timespans USING btree (user_id, calc_method, start_time);


--
-- Name: timespans_user_calc_method_work_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX timespans_user_calc_method_work_date_index ON public.timespans USING btree (user_id, calc_method, work_date);


--
-- Name: user_actions_user_id_event_recorded_at_DESC_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "user_actions_user_id_event_recorded_at_DESC_index" ON public.user_actions USING btree (user_id, event, recorded_at DESC);


--
-- Name: user_gig_accounts_argyle_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_gig_accounts_argyle_id ON public.user_gig_accounts USING btree (argyle_id);


--
-- Name: user_service_identifiers_ak; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_service_identifiers_ak ON public.user_service_identifiers USING btree (user_id, service);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: oban_jobs oban_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER oban_notify AFTER INSERT ON public.oban_jobs FOR EACH ROW EXECUTE FUNCTION public.oban_jobs_notify();


--
-- Name: accepted_terms accepted_terms_terms_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accepted_terms
    ADD CONSTRAINT accepted_terms_terms_id_fkey FOREIGN KEY (terms_id) REFERENCES public.terms(id);


--
-- Name: accepted_terms accepted_terms_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accepted_terms
    ADD CONSTRAINT accepted_terms_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: activities activities_employer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_employer_id_fkey FOREIGN KEY (employer_id) REFERENCES public.employers(id);


--
-- Name: activities activities_employer_service_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_employer_service_class_id_fkey FOREIGN KEY (employer_service_class_id) REFERENCES public.employer_service_classes(id);


--
-- Name: activities activities_metro_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_metro_area_id_fkey FOREIGN KEY (metro_area_id) REFERENCES public.region_metro_area(id);


--
-- Name: activities activities_service_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_service_class_id_fkey FOREIGN KEY (service_class_id) REFERENCES public.service_classes(id);


--
-- Name: activities activities_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: activity_hours activity_hours_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_hours
    ADD CONSTRAINT activity_hours_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.activities(id);


--
-- Name: campaign_participants campaign_participants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_participants
    ADD CONSTRAINT campaign_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: community_insights_avg_hr_pay_stats_dsc community_insights_avg_hr_pay_stats_dsc_employer_service_class_; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_insights_avg_hr_pay_stats_dsc
    ADD CONSTRAINT community_insights_avg_hr_pay_stats_dsc_employer_service_class_ FOREIGN KEY (employer_service_class_id) REFERENCES public.employer_service_classes(id);


--
-- Name: community_insights_avg_hr_pay_stats_dsc community_insights_avg_hr_pay_stats_dsc_metro_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_insights_avg_hr_pay_stats_dsc
    ADD CONSTRAINT community_insights_avg_hr_pay_stats_dsc_metro_area_id_fkey FOREIGN KEY (metro_area_id) REFERENCES public.region_metro_area(id);


--
-- Name: community_insights_avg_hr_pay_stats community_insights_avg_hr_pay_stats_employer_service_class_id_f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_insights_avg_hr_pay_stats
    ADD CONSTRAINT community_insights_avg_hr_pay_stats_employer_service_class_id_f FOREIGN KEY (employer_service_class_id) REFERENCES public.employer_service_classes(id);


--
-- Name: community_insights_avg_hr_pay_stats community_insights_avg_hr_pay_stats_metro_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_insights_avg_hr_pay_stats
    ADD CONSTRAINT community_insights_avg_hr_pay_stats_metro_area_id_fkey FOREIGN KEY (metro_area_id) REFERENCES public.region_metro_area(id);


--
-- Name: crepe_data_field crepe_data_field_collector_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crepe_data_field
    ADD CONSTRAINT crepe_data_field_collector_id_fkey FOREIGN KEY (collector_id) REFERENCES public.crepe_collector(id) ON DELETE CASCADE;


--
-- Name: crepe_event crepe_event_data_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crepe_event
    ADD CONSTRAINT crepe_event_data_field_id_fkey FOREIGN KEY (data_field_id) REFERENCES public.crepe_data_field(id) ON DELETE CASCADE;


--
-- Name: crepe_event crepe_event_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crepe_event
    ADD CONSTRAINT crepe_event_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: devices devices_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: employer_service_classes employer_service_classes_employer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employer_service_classes
    ADD CONSTRAINT employer_service_classes_employer_id_fkey FOREIGN KEY (employer_id) REFERENCES public.employers(id);


--
-- Name: employer_service_classes employer_service_classes_service_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employer_service_classes
    ADD CONSTRAINT employer_service_classes_service_class_id_fkey FOREIGN KEY (service_class_id) REFERENCES public.service_classes(id);


--
-- Name: focus_group_memberships focus_group_memberships_focus_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_group_memberships
    ADD CONSTRAINT focus_group_memberships_focus_group_id_fkey FOREIGN KEY (focus_group_id) REFERENCES public.research_groups(id);


--
-- Name: focus_group_memberships focus_group_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_group_memberships
    ADD CONSTRAINT focus_group_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: goal_measurements goal_measurements_goal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_measurements
    ADD CONSTRAINT goal_measurements_goal_id_fkey FOREIGN KEY (goal_id) REFERENCES public.goals(id);


--
-- Name: goal_measurements goal_measurements_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_measurements
    ADD CONSTRAINT goal_measurements_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: goals goals_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: points points_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points
    ADD CONSTRAINT points_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id);


--
-- Name: points points_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points
    ADD CONSTRAINT points_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: population_members population_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.population_members
    ADD CONSTRAINT population_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: region_county region_county_region_id_state_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_county
    ADD CONSTRAINT region_county_region_id_state_fkey FOREIGN KEY (region_id_state) REFERENCES public.region_state(id);


--
-- Name: region_postal_code region_postal_code_region_id_county_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_postal_code
    ADD CONSTRAINT region_postal_code_region_id_county_fkey FOREIGN KEY (region_id_county) REFERENCES public.region_county(id);


--
-- Name: region_postal_code region_postal_code_region_id_metro_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_postal_code
    ADD CONSTRAINT region_postal_code_region_id_metro_area_fkey FOREIGN KEY (region_id_metro_area) REFERENCES public.region_metro_area(id);


--
-- Name: region_postal_code region_postal_code_region_id_state_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_postal_code
    ADD CONSTRAINT region_postal_code_region_id_state_fkey FOREIGN KEY (region_id_state) REFERENCES public.region_state(id);


--
-- Name: scheduled_shifts scheduled_shifts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_shifts
    ADD CONSTRAINT scheduled_shifts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: shifts shifts_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id);


--
-- Name: shifts shifts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: terms terms_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms
    ADD CONSTRAINT terms_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: timespan_allocations timespan_allocations_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timespan_allocations
    ADD CONSTRAINT timespan_allocations_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.activities(id);


--
-- Name: timespan_allocations timespan_allocations_timespan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timespan_allocations
    ADD CONSTRAINT timespan_allocations_timespan_id_fkey FOREIGN KEY (timespan_id) REFERENCES public.timespans(id);


--
-- Name: timespans timespans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timespans
    ADD CONSTRAINT timespans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_actions user_actions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_actions
    ADD CONSTRAINT user_actions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_gig_accounts user_gig_accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_gig_accounts
    ADD CONSTRAINT user_gig_accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_service_identifiers user_service_identifiers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_service_identifiers
    ADD CONSTRAINT user_service_identifiers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users users_metro_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_metro_area_id_fkey FOREIGN KEY (metro_area_id) REFERENCES public.region_metro_area(id);


--
-- PostgreSQL database dump complete
--

\unrestrict Ftz3Mn3ExeVaHgBFpjrGAnyD7h51R9WCPG0dQVXWJddfHPIWN5TQnfQAdbFXiba

INSERT INTO public."schema_migrations" (version) VALUES (20190711154056);
INSERT INTO public."schema_migrations" (version) VALUES (20190711160836);
INSERT INTO public."schema_migrations" (version) VALUES (20190711205540);
INSERT INTO public."schema_migrations" (version) VALUES (20190711205559);
INSERT INTO public."schema_migrations" (version) VALUES (20190823203108);
INSERT INTO public."schema_migrations" (version) VALUES (20190905154056);
INSERT INTO public."schema_migrations" (version) VALUES (20190909154056);
INSERT INTO public."schema_migrations" (version) VALUES (20190912154056);
INSERT INTO public."schema_migrations" (version) VALUES (20190916154056);
INSERT INTO public."schema_migrations" (version) VALUES (20190926142252);
INSERT INTO public."schema_migrations" (version) VALUES (20190926214445);
INSERT INTO public."schema_migrations" (version) VALUES (20190930153532);
INSERT INTO public."schema_migrations" (version) VALUES (20191002151015);
INSERT INTO public."schema_migrations" (version) VALUES (20191014200734);
INSERT INTO public."schema_migrations" (version) VALUES (20191025170244);
INSERT INTO public."schema_migrations" (version) VALUES (20191106194937);
INSERT INTO public."schema_migrations" (version) VALUES (20191209164650);
INSERT INTO public."schema_migrations" (version) VALUES (20200131173731);
INSERT INTO public."schema_migrations" (version) VALUES (20200210194252);
INSERT INTO public."schema_migrations" (version) VALUES (20200211201104);
INSERT INTO public."schema_migrations" (version) VALUES (20200305200001);
INSERT INTO public."schema_migrations" (version) VALUES (20200311183555);
INSERT INTO public."schema_migrations" (version) VALUES (20200317162641);
INSERT INTO public."schema_migrations" (version) VALUES (20200319153235);
INSERT INTO public."schema_migrations" (version) VALUES (20200407142013);
INSERT INTO public."schema_migrations" (version) VALUES (20200410151618);
INSERT INTO public."schema_migrations" (version) VALUES (20200420203913);
INSERT INTO public."schema_migrations" (version) VALUES (20200508163725);
INSERT INTO public."schema_migrations" (version) VALUES (20200508170022);
INSERT INTO public."schema_migrations" (version) VALUES (20200519161112);
INSERT INTO public."schema_migrations" (version) VALUES (20200720191742);
INSERT INTO public."schema_migrations" (version) VALUES (20200721155343);
INSERT INTO public."schema_migrations" (version) VALUES (20200727163614);
INSERT INTO public."schema_migrations" (version) VALUES (20200728155012);
INSERT INTO public."schema_migrations" (version) VALUES (20200729174250);
INSERT INTO public."schema_migrations" (version) VALUES (20200803210427);
INSERT INTO public."schema_migrations" (version) VALUES (20200908142044);
INSERT INTO public."schema_migrations" (version) VALUES (20201119212027);
INSERT INTO public."schema_migrations" (version) VALUES (20201208160959);
INSERT INTO public."schema_migrations" (version) VALUES (20201210185330);
INSERT INTO public."schema_migrations" (version) VALUES (20201217004702);
INSERT INTO public."schema_migrations" (version) VALUES (20201221182809);
INSERT INTO public."schema_migrations" (version) VALUES (20210111185305);
INSERT INTO public."schema_migrations" (version) VALUES (20210120175622);
INSERT INTO public."schema_migrations" (version) VALUES (20210126164951);
INSERT INTO public."schema_migrations" (version) VALUES (20210128182051);
INSERT INTO public."schema_migrations" (version) VALUES (20210201195458);
INSERT INTO public."schema_migrations" (version) VALUES (20210209162931);
INSERT INTO public."schema_migrations" (version) VALUES (20210210201311);
INSERT INTO public."schema_migrations" (version) VALUES (20210302204300);
INSERT INTO public."schema_migrations" (version) VALUES (20210315192408);
INSERT INTO public."schema_migrations" (version) VALUES (20210427213445);
INSERT INTO public."schema_migrations" (version) VALUES (20210510142507);
INSERT INTO public."schema_migrations" (version) VALUES (20210512203600);
INSERT INTO public."schema_migrations" (version) VALUES (20210518150907);
INSERT INTO public."schema_migrations" (version) VALUES (20210519204619);
INSERT INTO public."schema_migrations" (version) VALUES (20210519213139);
INSERT INTO public."schema_migrations" (version) VALUES (20210617175240);
INSERT INTO public."schema_migrations" (version) VALUES (20210622163400);
INSERT INTO public."schema_migrations" (version) VALUES (20210622165256);
INSERT INTO public."schema_migrations" (version) VALUES (20210624184736);
INSERT INTO public."schema_migrations" (version) VALUES (20210629172553);
INSERT INTO public."schema_migrations" (version) VALUES (20210701212451);
INSERT INTO public."schema_migrations" (version) VALUES (20210702200019);
INSERT INTO public."schema_migrations" (version) VALUES (20210729180134);
INSERT INTO public."schema_migrations" (version) VALUES (20210811170008);
INSERT INTO public."schema_migrations" (version) VALUES (20210826175853);
INSERT INTO public."schema_migrations" (version) VALUES (20210922193712);
INSERT INTO public."schema_migrations" (version) VALUES (20211103205620);
INSERT INTO public."schema_migrations" (version) VALUES (20211104224516);
INSERT INTO public."schema_migrations" (version) VALUES (20211106001134);
INSERT INTO public."schema_migrations" (version) VALUES (20211106010348);
INSERT INTO public."schema_migrations" (version) VALUES (20211113025240);
INSERT INTO public."schema_migrations" (version) VALUES (20211113203407);
INSERT INTO public."schema_migrations" (version) VALUES (20211122184134);
INSERT INTO public."schema_migrations" (version) VALUES (20211123180010);
INSERT INTO public."schema_migrations" (version) VALUES (20211127025126);
INSERT INTO public."schema_migrations" (version) VALUES (20211129015038);
INSERT INTO public."schema_migrations" (version) VALUES (20211129044709);
INSERT INTO public."schema_migrations" (version) VALUES (20211129052414);
INSERT INTO public."schema_migrations" (version) VALUES (20211204213323);
INSERT INTO public."schema_migrations" (version) VALUES (20211209171409);
INSERT INTO public."schema_migrations" (version) VALUES (20211216173304);
INSERT INTO public."schema_migrations" (version) VALUES (20211218213111);
INSERT INTO public."schema_migrations" (version) VALUES (20211225042434);
INSERT INTO public."schema_migrations" (version) VALUES (20211227045048);
INSERT INTO public."schema_migrations" (version) VALUES (20211231073632);
INSERT INTO public."schema_migrations" (version) VALUES (20220108202335);
INSERT INTO public."schema_migrations" (version) VALUES (20220115235751);
INSERT INTO public."schema_migrations" (version) VALUES (20220116151858);
INSERT INTO public."schema_migrations" (version) VALUES (20220121014824);
INSERT INTO public."schema_migrations" (version) VALUES (20220131193119);
INSERT INTO public."schema_migrations" (version) VALUES (20220210185158);
INSERT INTO public."schema_migrations" (version) VALUES (20220218134734);
INSERT INTO public."schema_migrations" (version) VALUES (20220224235659);
INSERT INTO public."schema_migrations" (version) VALUES (20220304182026);
INSERT INTO public."schema_migrations" (version) VALUES (20220305191420);
INSERT INTO public."schema_migrations" (version) VALUES (20220305194442);
INSERT INTO public."schema_migrations" (version) VALUES (20220305194739);
INSERT INTO public."schema_migrations" (version) VALUES (20220306223517);
INSERT INTO public."schema_migrations" (version) VALUES (20220306223715);
INSERT INTO public."schema_migrations" (version) VALUES (20220730002013);
INSERT INTO public."schema_migrations" (version) VALUES (20220831161501);
INSERT INTO public."schema_migrations" (version) VALUES (20221018185137);
INSERT INTO public."schema_migrations" (version) VALUES (20221018185728);
INSERT INTO public."schema_migrations" (version) VALUES (20221019201739);
INSERT INTO public."schema_migrations" (version) VALUES (20221103152345);
INSERT INTO public."schema_migrations" (version) VALUES (20221105010659);
INSERT INTO public."schema_migrations" (version) VALUES (20221115202846);
INSERT INTO public."schema_migrations" (version) VALUES (20221115211751);
INSERT INTO public."schema_migrations" (version) VALUES (20221119165906);
INSERT INTO public."schema_migrations" (version) VALUES (20221202035855);
INSERT INTO public."schema_migrations" (version) VALUES (20221207054435);
INSERT INTO public."schema_migrations" (version) VALUES (20230213200512);
INSERT INTO public."schema_migrations" (version) VALUES (20230214222855);
INSERT INTO public."schema_migrations" (version) VALUES (20230215032445);
INSERT INTO public."schema_migrations" (version) VALUES (20230217182241);
INSERT INTO public."schema_migrations" (version) VALUES (20230224205534);
INSERT INTO public."schema_migrations" (version) VALUES (20230309015212);
INSERT INTO public."schema_migrations" (version) VALUES (20230309164228);
INSERT INTO public."schema_migrations" (version) VALUES (20230310012705);
INSERT INTO public."schema_migrations" (version) VALUES (20230315220111);
INSERT INTO public."schema_migrations" (version) VALUES (20230320154905);
INSERT INTO public."schema_migrations" (version) VALUES (20230411011254);
INSERT INTO public."schema_migrations" (version) VALUES (20230503234412);
INSERT INTO public."schema_migrations" (version) VALUES (20230508234503);
INSERT INTO public."schema_migrations" (version) VALUES (20230515184819);
INSERT INTO public."schema_migrations" (version) VALUES (20230520202014);
INSERT INTO public."schema_migrations" (version) VALUES (20230613164025);
INSERT INTO public."schema_migrations" (version) VALUES (20230613225859);
INSERT INTO public."schema_migrations" (version) VALUES (20230706185229);
INSERT INTO public."schema_migrations" (version) VALUES (20230731200311);
INSERT INTO public."schema_migrations" (version) VALUES (20230811174309);
INSERT INTO public."schema_migrations" (version) VALUES (20231130192306);
INSERT INTO public."schema_migrations" (version) VALUES (20240108193443);
INSERT INTO public."schema_migrations" (version) VALUES (20240112173800);
INSERT INTO public."schema_migrations" (version) VALUES (20240112173845);
INSERT INTO public."schema_migrations" (version) VALUES (20240112185605);
INSERT INTO public."schema_migrations" (version) VALUES (20240114221829);
INSERT INTO public."schema_migrations" (version) VALUES (20240114224734);
INSERT INTO public."schema_migrations" (version) VALUES (20240114225000);
INSERT INTO public."schema_migrations" (version) VALUES (20240122192923);
INSERT INTO public."schema_migrations" (version) VALUES (20240125024726);
INSERT INTO public."schema_migrations" (version) VALUES (20240129195039);
INSERT INTO public."schema_migrations" (version) VALUES (20240202012609);
INSERT INTO public."schema_migrations" (version) VALUES (20240202175249);
INSERT INTO public."schema_migrations" (version) VALUES (20240206015307);
INSERT INTO public."schema_migrations" (version) VALUES (20240323160308);
INSERT INTO public."schema_migrations" (version) VALUES (20250514082137);
INSERT INTO public."schema_migrations" (version) VALUES (20250616154256);
INSERT INTO public."schema_migrations" (version) VALUES (20251017134256);
