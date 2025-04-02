SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: analysis_jobs_item_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.analysis_jobs_item_result AS ENUM (
    'success',
    'failed',
    'killed',
    'cancelled'
);


--
-- Name: analysis_jobs_item_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.analysis_jobs_item_state AS ENUM (
    'new',
    'queued',
    'working',
    'finished'
);


--
-- Name: analysis_jobs_item_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.analysis_jobs_item_status AS ENUM (
    'new',
    'queued',
    'working',
    'finished'
);


--
-- Name: analysis_jobs_item_transition; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.analysis_jobs_item_transition AS ENUM (
    'queue',
    'retry',
    'cancel',
    'finish'
);


--
-- Name: confirmation; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.confirmation AS ENUM (
    'correct',
    'incorrect',
    'unsure',
    'skip'
);


--
-- Name: consent; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.consent AS ENUM (
    'unasked',
    'yes',
    'no'
);


--
-- Name: dirname(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dirname(path text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$
DECLARE
  segments text[];
  length int;
BEGIN
  segments := string_to_array(path, '/');
  length :=  CARDINALITY(segments) - 1;

  RETURN array_to_string(segments[1:length],'/');
END;
$$;


--
-- Name: is_json(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_json(input text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
  DECLARE
    data json;
  BEGIN
    BEGIN
      data := input;
    EXCEPTION WHEN others THEN
      RETURN FALSE;
    END;
    RETURN TRUE;
  END;
$$;


--
-- Name: path_contained_by_query(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.path_contained_by_query(path text, query text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$
DECLARE
  segments text[];
  query_segments text[];
  query_length int;
  segments_subset text[];
BEGIN
  query := TRIM(BOTH '/' FROM query);
  query_segments := string_to_array(query, '/');
  query_length :=  CARDINALITY(query_segments);

  segments := string_to_array(path, '/');

  segments_subset := segments[1:query_length];
  IF query_segments <> segments_subset THEN
      RETURN NULL;
  END IF;


  RETURN array_to_string(segments[1:(query_length + 1)],'/');
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    byte_size bigint NOT NULL,
    checksum character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    service_name character varying NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: analysis_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analysis_jobs (
    id integer NOT NULL,
    name character varying NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description text,
    started_at timestamp without time zone,
    overall_status character varying NOT NULL,
    overall_status_modified_at timestamp without time zone NOT NULL,
    overall_count integer NOT NULL,
    overall_duration_seconds numeric(14,4) NOT NULL,
    overall_data_length_bytes bigint DEFAULT 0 NOT NULL,
    filter jsonb,
    system_job boolean DEFAULT false NOT NULL,
    ongoing boolean DEFAULT false NOT NULL,
    project_id integer,
    retry_count integer DEFAULT 0 NOT NULL,
    amend_count integer DEFAULT 0 NOT NULL,
    suspend_count integer DEFAULT 0 NOT NULL,
    resume_count integer DEFAULT 0 NOT NULL
);


--
-- Name: COLUMN analysis_jobs.filter; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs.filter IS 'API filter to include recordings in this job. If blank then all recordings are included.';


--
-- Name: COLUMN analysis_jobs.system_job; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs.system_job IS 'If true this job is automatically run and not associated with a single project. We can have multiple system jobs.';


--
-- Name: COLUMN analysis_jobs.ongoing; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs.ongoing IS 'If true the filter for this job will be evaluated after a harvest. If more items are found the job will move to the processing stage if needed and process the new recordings.';


--
-- Name: COLUMN analysis_jobs.project_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs.project_id IS 'Project this job is associated with. This field simply influences which jobs are shown on a project page.';


--
-- Name: COLUMN analysis_jobs.retry_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs.retry_count IS 'Count of retries';


--
-- Name: COLUMN analysis_jobs.amend_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs.amend_count IS 'Count of amendments';


--
-- Name: COLUMN analysis_jobs.suspend_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs.suspend_count IS 'Count of suspensions';


--
-- Name: COLUMN analysis_jobs.resume_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs.resume_count IS 'Count of resumptions';


--
-- Name: analysis_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.analysis_jobs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: analysis_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.analysis_jobs_id_seq OWNED BY public.analysis_jobs.id;


--
-- Name: analysis_jobs_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analysis_jobs_items (
    id bigint NOT NULL,
    analysis_job_id integer NOT NULL,
    audio_recording_id integer NOT NULL,
    queue_id character varying(255),
    status public.analysis_jobs_item_status DEFAULT 'new'::public.analysis_jobs_item_status NOT NULL,
    created_at timestamp without time zone NOT NULL,
    queued_at timestamp without time zone,
    work_started_at timestamp without time zone,
    finished_at timestamp without time zone,
    cancel_started_at timestamp without time zone,
    script_id integer NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    transition public.analysis_jobs_item_transition,
    result public.analysis_jobs_item_result,
    error text,
    used_walltime_seconds integer,
    used_memory_bytes bigint,
    import_success boolean
);


--
-- Name: COLUMN analysis_jobs_items.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_items.status IS 'Current status of this job item';


--
-- Name: COLUMN analysis_jobs_items.script_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_items.script_id IS 'Script used for this item';


--
-- Name: COLUMN analysis_jobs_items.attempts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_items.attempts IS 'Number of times this job item has been attempted';


--
-- Name: COLUMN analysis_jobs_items.transition; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_items.transition IS 'The pending transition to apply to this item. Any high-latency action should be done via transition and on a worker rather than in a web request.';


--
-- Name: COLUMN analysis_jobs_items.result; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_items.result IS 'Result of this job item';


--
-- Name: COLUMN analysis_jobs_items.error; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_items.error IS 'Error message if this job item failed';


--
-- Name: COLUMN analysis_jobs_items.used_walltime_seconds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_items.used_walltime_seconds IS 'Walltime used by this job item';


--
-- Name: COLUMN analysis_jobs_items.used_memory_bytes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_items.used_memory_bytes IS 'Memory used by this job item';


--
-- Name: COLUMN analysis_jobs_items.import_success; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_items.import_success IS 'Did importing audio events succeed?';


--
-- Name: analysis_jobs_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.analysis_jobs_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: analysis_jobs_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.analysis_jobs_items_id_seq OWNED BY public.analysis_jobs_items.id;


--
-- Name: analysis_jobs_scripts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analysis_jobs_scripts (
    analysis_job_id integer NOT NULL,
    script_id integer NOT NULL,
    custom_settings text
);


--
-- Name: COLUMN analysis_jobs_scripts.custom_settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analysis_jobs_scripts.custom_settings IS 'Custom settings for this script and analysis job';


--
-- Name: anonymous_user_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.anonymous_user_statistics (
    bucket tsrange DEFAULT tsrange((CURRENT_DATE)::timestamp without time zone, (CURRENT_DATE + '1 day'::interval)) NOT NULL,
    audio_segment_download_count bigint DEFAULT 0,
    audio_original_download_count bigint DEFAULT 0,
    audio_download_duration numeric DEFAULT 0.0
)
WITH (fillfactor='90');


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audio_event_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audio_event_comments (
    id integer NOT NULL,
    audio_event_id integer NOT NULL,
    comment text NOT NULL,
    flag character varying,
    flag_explain text,
    flagger_id integer,
    flagged_at timestamp without time zone,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: audio_event_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audio_event_comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_event_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audio_event_comments_id_seq OWNED BY public.audio_event_comments.id;


--
-- Name: audio_event_import_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audio_event_import_files (
    id bigint NOT NULL,
    audio_event_import_id integer NOT NULL,
    analysis_jobs_item_id integer,
    path character varying,
    additional_tag_ids integer[],
    created_at timestamp(6) without time zone NOT NULL,
    file_hash text,
    CONSTRAINT path_and_analysis_jobs_item CHECK ((((path IS NOT NULL) AND (analysis_jobs_item_id IS NOT NULL)) OR ((path IS NULL) AND (analysis_jobs_item_id IS NULL))))
);


--
-- Name: COLUMN audio_event_import_files.path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audio_event_import_files.path IS 'Path to the file on disk, relative to the analysis job item. Not used for uploaded files';


--
-- Name: COLUMN audio_event_import_files.additional_tag_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audio_event_import_files.additional_tag_ids IS 'Additional tag ids applied for this import';


--
-- Name: COLUMN audio_event_import_files.file_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audio_event_import_files.file_hash IS 'Hash of the file contents used for uniqueness checking';


--
-- Name: audio_event_import_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audio_event_import_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_event_import_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audio_event_import_files_id_seq OWNED BY public.audio_event_import_files.id;


--
-- Name: audio_event_imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audio_event_imports (
    id bigint NOT NULL,
    name character varying,
    description text,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    analysis_job_id integer
);


--
-- Name: COLUMN audio_event_imports.analysis_job_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audio_event_imports.analysis_job_id IS 'Analysis job that created this import';


--
-- Name: audio_event_imports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audio_event_imports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_event_imports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audio_event_imports_id_seq OWNED BY public.audio_event_imports.id;


--
-- Name: audio_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audio_events (
    id integer NOT NULL,
    audio_recording_id integer NOT NULL,
    start_time_seconds numeric(10,4) NOT NULL,
    end_time_seconds numeric(10,4),
    low_frequency_hertz numeric(10,4),
    high_frequency_hertz numeric(10,4),
    is_reference boolean DEFAULT false NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    channel integer,
    provenance_id integer,
    score numeric,
    import_file_index integer,
    audio_event_import_file_id bigint
);


--
-- Name: COLUMN audio_events.provenance_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audio_events.provenance_id IS 'Source of this event';


--
-- Name: COLUMN audio_events.score; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audio_events.score IS 'Score or confidence for this event.';


--
-- Name: COLUMN audio_events.import_file_index; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audio_events.import_file_index IS 'Index of the row/entry in the file that generated this event';


--
-- Name: audio_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audio_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audio_events_id_seq OWNED BY public.audio_events.id;


--
-- Name: audio_events_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audio_events_tags (
    id integer NOT NULL,
    audio_event_id integer NOT NULL,
    tag_id integer NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: audio_events_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audio_events_tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_events_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audio_events_tags_id_seq OWNED BY public.audio_events_tags.id;


--
-- Name: audio_recording_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audio_recording_statistics (
    audio_recording_id bigint NOT NULL,
    bucket tsrange DEFAULT tsrange((CURRENT_DATE)::timestamp without time zone, (CURRENT_DATE + '1 day'::interval)) NOT NULL,
    original_download_count bigint DEFAULT 0,
    segment_download_count bigint DEFAULT 0,
    segment_download_duration numeric DEFAULT 0.0,
    analyses_completed_count bigint DEFAULT 0
)
WITH (fillfactor='90');


--
-- Name: audio_recordings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audio_recordings (
    id integer NOT NULL,
    uuid character varying(36) NOT NULL,
    uploader_id integer NOT NULL,
    recorded_date timestamp without time zone NOT NULL,
    site_id integer NOT NULL,
    duration_seconds numeric(10,4) NOT NULL,
    sample_rate_hertz integer,
    channels integer,
    bit_rate_bps integer,
    media_type character varying NOT NULL,
    data_length_bytes bigint NOT NULL,
    file_hash character varying(524) NOT NULL,
    status character varying DEFAULT 'new'::character varying,
    notes text,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    deleted_at timestamp without time zone,
    original_file_name character varying,
    recorded_utc_offset character varying(20)
);


--
-- Name: audio_recordings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audio_recordings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_recordings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audio_recordings_id_seq OWNED BY public.audio_recordings.id;


--
-- Name: bookmarks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookmarks (
    id integer NOT NULL,
    audio_recording_id integer,
    offset_seconds numeric(10,4),
    name character varying,
    creator_id integer NOT NULL,
    updater_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description text,
    category character varying
);


--
-- Name: bookmarks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bookmarks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bookmarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bookmarks_id_seq OWNED BY public.bookmarks.id;


--
-- Name: comfy_cms_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_categories (
    id bigint NOT NULL,
    site_id integer NOT NULL,
    label character varying NOT NULL,
    categorized_type character varying NOT NULL
);


--
-- Name: comfy_cms_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_categories_id_seq OWNED BY public.comfy_cms_categories.id;


--
-- Name: comfy_cms_categorizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_categorizations (
    id bigint NOT NULL,
    category_id integer NOT NULL,
    categorized_type character varying NOT NULL,
    categorized_id integer NOT NULL
);


--
-- Name: comfy_cms_categorizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_categorizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_categorizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_categorizations_id_seq OWNED BY public.comfy_cms_categorizations.id;


--
-- Name: comfy_cms_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_files (
    id bigint NOT NULL,
    site_id integer NOT NULL,
    label character varying DEFAULT ''::character varying NOT NULL,
    description text,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: comfy_cms_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_files_id_seq OWNED BY public.comfy_cms_files.id;


--
-- Name: comfy_cms_fragments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_fragments (
    id bigint NOT NULL,
    record_type character varying,
    record_id bigint,
    identifier character varying NOT NULL,
    tag character varying DEFAULT 'text'::character varying NOT NULL,
    content text,
    "boolean" boolean DEFAULT false NOT NULL,
    datetime timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: comfy_cms_fragments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_fragments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_fragments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_fragments_id_seq OWNED BY public.comfy_cms_fragments.id;


--
-- Name: comfy_cms_layouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_layouts (
    id bigint NOT NULL,
    site_id integer NOT NULL,
    parent_id integer,
    app_layout character varying,
    label character varying NOT NULL,
    identifier character varying NOT NULL,
    content text,
    css text,
    js text,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: comfy_cms_layouts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_layouts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_layouts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_layouts_id_seq OWNED BY public.comfy_cms_layouts.id;


--
-- Name: comfy_cms_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_pages (
    id bigint NOT NULL,
    site_id integer NOT NULL,
    layout_id integer,
    parent_id integer,
    target_page_id integer,
    label character varying NOT NULL,
    slug character varying,
    full_path character varying NOT NULL,
    content_cache text,
    "position" integer DEFAULT 0 NOT NULL,
    children_count integer DEFAULT 0 NOT NULL,
    is_published boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: comfy_cms_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_pages_id_seq OWNED BY public.comfy_cms_pages.id;


--
-- Name: comfy_cms_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_revisions (
    id bigint NOT NULL,
    record_type character varying NOT NULL,
    record_id integer NOT NULL,
    data text,
    created_at timestamp without time zone
);


--
-- Name: comfy_cms_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_revisions_id_seq OWNED BY public.comfy_cms_revisions.id;


--
-- Name: comfy_cms_sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_sites (
    id bigint NOT NULL,
    label character varying NOT NULL,
    identifier character varying NOT NULL,
    hostname character varying NOT NULL,
    path character varying,
    locale character varying DEFAULT 'en'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: comfy_cms_sites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_sites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_sites_id_seq OWNED BY public.comfy_cms_sites.id;


--
-- Name: comfy_cms_snippets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_snippets (
    id bigint NOT NULL,
    site_id integer NOT NULL,
    label character varying NOT NULL,
    identifier character varying NOT NULL,
    content text,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: comfy_cms_snippets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_snippets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_snippets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_snippets_id_seq OWNED BY public.comfy_cms_snippets.id;


--
-- Name: comfy_cms_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comfy_cms_translations (
    id bigint NOT NULL,
    locale character varying NOT NULL,
    page_id integer NOT NULL,
    layout_id integer,
    label character varying NOT NULL,
    content_cache text,
    is_published boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: comfy_cms_translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comfy_cms_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comfy_cms_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comfy_cms_translations_id_seq OWNED BY public.comfy_cms_translations.id;


--
-- Name: dataset_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dataset_items (
    id integer NOT NULL,
    dataset_id integer,
    audio_recording_id integer,
    creator_id integer,
    start_time_seconds numeric NOT NULL,
    end_time_seconds numeric NOT NULL,
    "order" numeric,
    created_at timestamp without time zone
);


--
-- Name: dataset_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dataset_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dataset_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dataset_items_id_seq OWNED BY public.dataset_items.id;


--
-- Name: datasets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.datasets (
    id integer NOT NULL,
    creator_id integer,
    updater_id integer,
    name character varying,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: datasets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.datasets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: datasets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.datasets_id_seq OWNED BY public.datasets.id;


--
-- Name: harvest_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.harvest_items (
    id bigint NOT NULL,
    path character varying,
    status character varying,
    info jsonb,
    audio_recording_id integer,
    uploader_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    harvest_id integer,
    deleted boolean DEFAULT false
);


--
-- Name: harvest_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.harvest_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: harvest_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.harvest_items_id_seq OWNED BY public.harvest_items.id;


--
-- Name: harvests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.harvests (
    id bigint NOT NULL,
    streaming boolean,
    status character varying,
    last_upload_at timestamp(6) without time zone,
    upload_user character varying,
    upload_password character varying,
    project_id integer NOT NULL,
    mappings jsonb,
    creator_id integer,
    updater_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    last_metadata_review_at timestamp(6) without time zone,
    last_mappings_change_at timestamp(6) without time zone,
    upload_user_expiry_at timestamp(6) without time zone,
    name character varying
);


--
-- Name: harvests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.harvests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: harvests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.harvests_id_seq OWNED BY public.harvests.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id integer NOT NULL,
    creator_id integer NOT NULL,
    level character varying NOT NULL,
    project_id integer NOT NULL,
    user_id integer,
    updater_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    allow_logged_in boolean DEFAULT false NOT NULL,
    allow_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT permissions_exclusive_cols CHECK ((((user_id IS NOT NULL) AND (NOT allow_logged_in) AND (NOT allow_anonymous)) OR ((user_id IS NULL) AND allow_logged_in AND (NOT allow_anonymous)) OR ((user_id IS NULL) AND (NOT allow_logged_in) AND allow_anonymous)))
);


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: progress_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.progress_events (
    id integer NOT NULL,
    creator_id integer,
    dataset_item_id integer,
    activity character varying,
    created_at timestamp without time zone
);


--
-- Name: progress_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.progress_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: progress_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.progress_events_id_seq OWNED BY public.progress_events.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id integer NOT NULL,
    name character varying NOT NULL,
    description text,
    urn character varying,
    notes text,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    image_file_name character varying,
    image_content_type character varying,
    image_file_size bigint,
    image_updated_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    allow_original_download character varying,
    allow_audio_upload boolean DEFAULT false,
    license text
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: projects_saved_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects_saved_searches (
    project_id integer NOT NULL,
    saved_search_id integer NOT NULL
);


--
-- Name: projects_sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects_sites (
    project_id integer NOT NULL,
    site_id integer NOT NULL
);


--
-- Name: provenances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.provenances (
    id integer NOT NULL,
    name character varying,
    version character varying,
    url character varying,
    description text,
    score_minimum numeric,
    score_maximum numeric,
    creator_id integer,
    updater_id integer,
    deleter_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone
);


--
-- Name: COLUMN provenances.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.provenances.description IS 'Markdown description of this source';


--
-- Name: COLUMN provenances.score_minimum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.provenances.score_minimum IS 'Lower bound for scores emitted by this source, if known';


--
-- Name: COLUMN provenances.score_maximum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.provenances.score_maximum IS 'Upper bound for scores emitted by this source, if known';


--
-- Name: provenances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.provenances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: provenances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.provenances_id_seq OWNED BY public.provenances.id;


--
-- Name: questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.questions (
    id integer NOT NULL,
    creator_id integer,
    updater_id integer,
    text text,
    data text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.questions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.questions_id_seq OWNED BY public.questions.id;


--
-- Name: questions_studies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.questions_studies (
    question_id integer NOT NULL,
    study_id integer NOT NULL
);


--
-- Name: regions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.regions (
    id bigint NOT NULL,
    name character varying,
    description text,
    notes jsonb,
    project_id integer NOT NULL,
    creator_id integer,
    updater_id integer,
    deleter_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    deleted_at timestamp without time zone
);


--
-- Name: regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.regions_id_seq OWNED BY public.regions.id;


--
-- Name: responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.responses (
    id integer NOT NULL,
    creator_id integer,
    dataset_item_id integer,
    question_id integer,
    study_id integer,
    created_at timestamp without time zone,
    data text
);


--
-- Name: responses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.responses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: responses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.responses_id_seq OWNED BY public.responses.id;


--
-- Name: saved_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_searches (
    id integer NOT NULL,
    name character varying NOT NULL,
    description text,
    stored_query jsonb NOT NULL,
    creator_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    deleter_id integer,
    deleted_at timestamp without time zone
);


--
-- Name: saved_searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.saved_searches_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_searches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.saved_searches_id_seq OWNED BY public.saved_searches.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: scripts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scripts (
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying,
    analysis_identifier character varying NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    verified boolean DEFAULT false,
    group_id integer,
    creator_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    executable_command text NOT NULL,
    executable_settings text,
    executable_settings_media_type character varying(255) DEFAULT 'text/plain'::character varying,
    executable_settings_name character varying,
    resources jsonb,
    provenance_id integer,
    event_import_glob character varying
);


--
-- Name: COLUMN scripts.analysis_identifier; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scripts.analysis_identifier IS 'a unique identifier for this script in the analysis system, used in directory names. [-a-z0-0_]';


--
-- Name: COLUMN scripts.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scripts.version IS 'Version of this script - not the version of program the script runs!';


--
-- Name: COLUMN scripts.resources; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scripts.resources IS 'Resources required by this script in the PBS format.';


--
-- Name: COLUMN scripts.event_import_glob; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scripts.event_import_glob IS 'Glob pattern to match result files that should be imported as audio events';


--
-- Name: scripts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scripts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scripts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scripts_id_seq OWNED BY public.scripts.id;


--
-- Name: sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sites (
    id integer NOT NULL,
    name character varying NOT NULL,
    longitude numeric(9,6),
    latitude numeric(9,6),
    notes text,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    image_file_name character varying,
    image_content_type character varying,
    image_file_size bigint,
    image_updated_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description text,
    tzinfo_tz character varying(255),
    rails_tz character varying(255),
    region_id integer
);


--
-- Name: sites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sites_id_seq OWNED BY public.sites.id;


--
-- Name: studies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.studies (
    id integer NOT NULL,
    creator_id integer,
    updater_id integer,
    dataset_id integer,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: studies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.studies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: studies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.studies_id_seq OWNED BY public.studies.id;


--
-- Name: tag_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_groups (
    id integer NOT NULL,
    group_identifier character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    creator_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: tag_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_groups_id_seq OWNED BY public.tag_groups.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    text character varying NOT NULL,
    is_taxonomic boolean DEFAULT false NOT NULL,
    type_of_tag character varying DEFAULT 'general'::character varying NOT NULL,
    retired boolean DEFAULT false NOT NULL,
    notes jsonb,
    creator_id integer NOT NULL,
    updater_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: user_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_statistics (
    user_id bigint NOT NULL,
    bucket tsrange DEFAULT tsrange((CURRENT_DATE)::timestamp without time zone, (CURRENT_DATE + '1 day'::interval)) NOT NULL,
    audio_segment_download_count bigint DEFAULT 0,
    audio_original_download_count bigint DEFAULT 0,
    audio_download_duration numeric DEFAULT 0.0,
    analyses_completed_count bigint DEFAULT 0,
    analyzed_audio_duration numeric DEFAULT 0.0 NOT NULL
)
WITH (fillfactor='90');


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying NOT NULL,
    user_name character varying NOT NULL,
    encrypted_password character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    confirmation_token character varying,
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    unconfirmed_email character varying,
    failed_attempts integer DEFAULT 0,
    unlock_token character varying,
    locked_at timestamp without time zone,
    authentication_token character varying,
    invitation_token character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    roles_mask integer,
    image_file_name character varying,
    image_content_type character varying,
    image_file_size bigint,
    image_updated_at timestamp(6) without time zone,
    preferences text,
    tzinfo_tz character varying(255),
    rails_tz character varying(255),
    last_seen_at timestamp without time zone,
    contactable public.consent DEFAULT 'unasked'::public.consent NOT NULL
);


--
-- Name: COLUMN users.contactable; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.contactable IS 'Is the user contactable for email communications';


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
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
-- Name: verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.verifications (
    id bigint NOT NULL,
    audio_event_id bigint NOT NULL,
    tag_id bigint NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer,
    confirmed public.confirmation NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.verifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.verifications_id_seq OWNED BY public.verifications.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: analysis_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs ALTER COLUMN id SET DEFAULT nextval('public.analysis_jobs_id_seq'::regclass);


--
-- Name: analysis_jobs_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_items ALTER COLUMN id SET DEFAULT nextval('public.analysis_jobs_items_id_seq'::regclass);


--
-- Name: audio_event_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_comments ALTER COLUMN id SET DEFAULT nextval('public.audio_event_comments_id_seq'::regclass);


--
-- Name: audio_event_import_files id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_import_files ALTER COLUMN id SET DEFAULT nextval('public.audio_event_import_files_id_seq'::regclass);


--
-- Name: audio_event_imports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_imports ALTER COLUMN id SET DEFAULT nextval('public.audio_event_imports_id_seq'::regclass);


--
-- Name: audio_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events ALTER COLUMN id SET DEFAULT nextval('public.audio_events_id_seq'::regclass);


--
-- Name: audio_events_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events_tags ALTER COLUMN id SET DEFAULT nextval('public.audio_events_tags_id_seq'::regclass);


--
-- Name: audio_recordings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recordings ALTER COLUMN id SET DEFAULT nextval('public.audio_recordings_id_seq'::regclass);


--
-- Name: bookmarks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks ALTER COLUMN id SET DEFAULT nextval('public.bookmarks_id_seq'::regclass);


--
-- Name: comfy_cms_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_categories ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_categories_id_seq'::regclass);


--
-- Name: comfy_cms_categorizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_categorizations ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_categorizations_id_seq'::regclass);


--
-- Name: comfy_cms_files id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_files ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_files_id_seq'::regclass);


--
-- Name: comfy_cms_fragments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_fragments ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_fragments_id_seq'::regclass);


--
-- Name: comfy_cms_layouts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_layouts ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_layouts_id_seq'::regclass);


--
-- Name: comfy_cms_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_pages ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_pages_id_seq'::regclass);


--
-- Name: comfy_cms_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_revisions ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_revisions_id_seq'::regclass);


--
-- Name: comfy_cms_sites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_sites ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_sites_id_seq'::regclass);


--
-- Name: comfy_cms_snippets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_snippets ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_snippets_id_seq'::regclass);


--
-- Name: comfy_cms_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_translations ALTER COLUMN id SET DEFAULT nextval('public.comfy_cms_translations_id_seq'::regclass);


--
-- Name: dataset_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dataset_items ALTER COLUMN id SET DEFAULT nextval('public.dataset_items_id_seq'::regclass);


--
-- Name: datasets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datasets ALTER COLUMN id SET DEFAULT nextval('public.datasets_id_seq'::regclass);


--
-- Name: harvest_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvest_items ALTER COLUMN id SET DEFAULT nextval('public.harvest_items_id_seq'::regclass);


--
-- Name: harvests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvests ALTER COLUMN id SET DEFAULT nextval('public.harvests_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: progress_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.progress_events ALTER COLUMN id SET DEFAULT nextval('public.progress_events_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: provenances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provenances ALTER COLUMN id SET DEFAULT nextval('public.provenances_id_seq'::regclass);


--
-- Name: questions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions ALTER COLUMN id SET DEFAULT nextval('public.questions_id_seq'::regclass);


--
-- Name: regions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions ALTER COLUMN id SET DEFAULT nextval('public.regions_id_seq'::regclass);


--
-- Name: responses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responses ALTER COLUMN id SET DEFAULT nextval('public.responses_id_seq'::regclass);


--
-- Name: saved_searches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches ALTER COLUMN id SET DEFAULT nextval('public.saved_searches_id_seq'::regclass);


--
-- Name: scripts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scripts ALTER COLUMN id SET DEFAULT nextval('public.scripts_id_seq'::regclass);


--
-- Name: sites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites ALTER COLUMN id SET DEFAULT nextval('public.sites_id_seq'::regclass);


--
-- Name: studies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.studies ALTER COLUMN id SET DEFAULT nextval('public.studies_id_seq'::regclass);


--
-- Name: tag_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_groups ALTER COLUMN id SET DEFAULT nextval('public.tag_groups_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: verifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verifications ALTER COLUMN id SET DEFAULT nextval('public.verifications_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: analysis_jobs_items analysis_jobs_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_items
    ADD CONSTRAINT analysis_jobs_items_pkey PRIMARY KEY (id);


--
-- Name: analysis_jobs analysis_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT analysis_jobs_pkey PRIMARY KEY (id);


--
-- Name: analysis_jobs_scripts analysis_jobs_scripts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_scripts
    ADD CONSTRAINT analysis_jobs_scripts_pkey PRIMARY KEY (analysis_job_id, script_id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audio_event_comments audio_event_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_comments
    ADD CONSTRAINT audio_event_comments_pkey PRIMARY KEY (id);


--
-- Name: audio_event_import_files audio_event_import_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_import_files
    ADD CONSTRAINT audio_event_import_files_pkey PRIMARY KEY (id);


--
-- Name: audio_event_imports audio_event_imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_imports
    ADD CONSTRAINT audio_event_imports_pkey PRIMARY KEY (id);


--
-- Name: audio_events audio_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events
    ADD CONSTRAINT audio_events_pkey PRIMARY KEY (id);


--
-- Name: audio_events_tags audio_events_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events_tags
    ADD CONSTRAINT audio_events_tags_pkey PRIMARY KEY (id);


--
-- Name: audio_recording_statistics audio_recording_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recording_statistics
    ADD CONSTRAINT audio_recording_statistics_pkey PRIMARY KEY (audio_recording_id, bucket);


--
-- Name: audio_recordings audio_recordings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recordings
    ADD CONSTRAINT audio_recordings_pkey PRIMARY KEY (id);


--
-- Name: bookmarks bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_categories comfy_cms_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_categories
    ADD CONSTRAINT comfy_cms_categories_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_categorizations comfy_cms_categorizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_categorizations
    ADD CONSTRAINT comfy_cms_categorizations_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_files comfy_cms_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_files
    ADD CONSTRAINT comfy_cms_files_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_fragments comfy_cms_fragments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_fragments
    ADD CONSTRAINT comfy_cms_fragments_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_layouts comfy_cms_layouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_layouts
    ADD CONSTRAINT comfy_cms_layouts_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_pages comfy_cms_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_pages
    ADD CONSTRAINT comfy_cms_pages_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_revisions comfy_cms_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_revisions
    ADD CONSTRAINT comfy_cms_revisions_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_sites comfy_cms_sites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_sites
    ADD CONSTRAINT comfy_cms_sites_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_snippets comfy_cms_snippets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_snippets
    ADD CONSTRAINT comfy_cms_snippets_pkey PRIMARY KEY (id);


--
-- Name: comfy_cms_translations comfy_cms_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comfy_cms_translations
    ADD CONSTRAINT comfy_cms_translations_pkey PRIMARY KEY (id);


--
-- Name: anonymous_user_statistics constraint_baw_anonymous_user_statistics_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anonymous_user_statistics
    ADD CONSTRAINT constraint_baw_anonymous_user_statistics_unique UNIQUE (bucket);


--
-- Name: audio_recording_statistics constraint_baw_audio_recording_statistics_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recording_statistics
    ADD CONSTRAINT constraint_baw_audio_recording_statistics_unique UNIQUE (audio_recording_id, bucket);


--
-- Name: user_statistics constraint_baw_user_statistics_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_statistics
    ADD CONSTRAINT constraint_baw_user_statistics_unique UNIQUE (user_id, bucket);


--
-- Name: dataset_items dataset_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dataset_items
    ADD CONSTRAINT dataset_items_pkey PRIMARY KEY (id);


--
-- Name: datasets datasets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datasets
    ADD CONSTRAINT datasets_pkey PRIMARY KEY (id);


--
-- Name: harvest_items harvest_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvest_items
    ADD CONSTRAINT harvest_items_pkey PRIMARY KEY (id);


--
-- Name: harvests harvests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvests
    ADD CONSTRAINT harvests_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: progress_events progress_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.progress_events
    ADD CONSTRAINT progress_events_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: provenances provenances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provenances
    ADD CONSTRAINT provenances_pkey PRIMARY KEY (id);


--
-- Name: questions questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (id);


--
-- Name: regions regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT regions_pkey PRIMARY KEY (id);


--
-- Name: responses responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responses
    ADD CONSTRAINT responses_pkey PRIMARY KEY (id);


--
-- Name: saved_searches saved_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: scripts scripts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scripts
    ADD CONSTRAINT scripts_pkey PRIMARY KEY (id);


--
-- Name: sites sites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT sites_pkey PRIMARY KEY (id);


--
-- Name: studies studies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.studies
    ADD CONSTRAINT studies_pkey PRIMARY KEY (id);


--
-- Name: tag_groups tag_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_groups
    ADD CONSTRAINT tag_groups_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: user_statistics user_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_statistics
    ADD CONSTRAINT user_statistics_pkey PRIMARY KEY (user_id, bucket);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: verifications verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verifications
    ADD CONSTRAINT verifications_pkey PRIMARY KEY (id);


--
-- Name: analysis_jobs_name_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX analysis_jobs_name_uidx ON public.analysis_jobs USING btree (name, creator_id);


--
-- Name: audio_recordings_created_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_created_updated_at ON public.audio_recordings USING btree (created_at, updated_at);


--
-- Name: audio_recordings_icase_file_hash_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_icase_file_hash_id_idx ON public.audio_recordings USING btree (lower((file_hash)::text), id);


--
-- Name: audio_recordings_icase_file_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_icase_file_hash_idx ON public.audio_recordings USING btree (lower((file_hash)::text));


--
-- Name: audio_recordings_icase_uuid_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_icase_uuid_id_idx ON public.audio_recordings USING btree (lower((uuid)::text), id);


--
-- Name: audio_recordings_icase_uuid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_icase_uuid_idx ON public.audio_recordings USING btree (lower((uuid)::text));


--
-- Name: audio_recordings_uuid_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audio_recordings_uuid_uidx ON public.audio_recordings USING btree (uuid);


--
-- Name: bookmarks_name_creator_id_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX bookmarks_name_creator_id_uidx ON public.bookmarks USING btree (name, creator_id);


--
-- Name: dataset_items_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dataset_items_idx ON public.dataset_items USING btree (start_time_seconds, end_time_seconds);


--
-- Name: idx_on_audio_event_id_tag_id_creator_id_f944f25f20; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_audio_event_id_tag_id_creator_id_f944f25f20 ON public.verifications USING btree (audio_event_id, tag_id, creator_id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_analysis_jobs_items_are_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_analysis_jobs_items_are_unique ON public.analysis_jobs_items USING btree (analysis_job_id, script_id, audio_recording_id);


--
-- Name: index_analysis_jobs_items_on_analysis_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_items_on_analysis_job_id ON public.analysis_jobs_items USING btree (analysis_job_id);


--
-- Name: index_analysis_jobs_items_on_audio_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_items_on_audio_recording_id ON public.analysis_jobs_items USING btree (audio_recording_id);


--
-- Name: index_analysis_jobs_items_on_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_items_on_script_id ON public.analysis_jobs_items USING btree (script_id);


--
-- Name: index_analysis_jobs_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_creator_id ON public.analysis_jobs USING btree (creator_id);


--
-- Name: index_analysis_jobs_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_deleter_id ON public.analysis_jobs USING btree (deleter_id);


--
-- Name: index_analysis_jobs_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_project_id ON public.analysis_jobs USING btree (project_id);


--
-- Name: index_analysis_jobs_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_updater_id ON public.analysis_jobs USING btree (updater_id);


--
-- Name: index_audio_event_comments_on_audio_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_audio_event_id ON public.audio_event_comments USING btree (audio_event_id);


--
-- Name: index_audio_event_comments_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_creator_id ON public.audio_event_comments USING btree (creator_id);


--
-- Name: index_audio_event_comments_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_deleter_id ON public.audio_event_comments USING btree (deleter_id);


--
-- Name: index_audio_event_comments_on_flagger_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_flagger_id ON public.audio_event_comments USING btree (flagger_id);


--
-- Name: index_audio_event_comments_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_updater_id ON public.audio_event_comments USING btree (updater_id);


--
-- Name: index_audio_event_import_files_on_analysis_jobs_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_import_files_on_analysis_jobs_item_id ON public.audio_event_import_files USING btree (analysis_jobs_item_id);


--
-- Name: index_audio_event_import_files_on_audio_event_import_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_import_files_on_audio_event_import_id ON public.audio_event_import_files USING btree (audio_event_import_id);


--
-- Name: index_audio_event_imports_on_analysis_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_imports_on_analysis_job_id ON public.audio_event_imports USING btree (analysis_job_id);


--
-- Name: index_audio_events_on_audio_event_import_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_audio_event_import_file_id ON public.audio_events USING btree (audio_event_import_file_id);


--
-- Name: index_audio_events_on_audio_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_audio_recording_id ON public.audio_events USING btree (audio_recording_id);


--
-- Name: index_audio_events_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_creator_id ON public.audio_events USING btree (creator_id);


--
-- Name: index_audio_events_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_deleter_id ON public.audio_events USING btree (deleter_id);


--
-- Name: index_audio_events_on_provenance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_provenance_id ON public.audio_events USING btree (provenance_id);


--
-- Name: index_audio_events_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_updater_id ON public.audio_events USING btree (updater_id);


--
-- Name: index_audio_events_tags_on_audio_event_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_audio_events_tags_on_audio_event_id_and_tag_id ON public.audio_events_tags USING btree (audio_event_id, tag_id);


--
-- Name: index_audio_events_tags_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_tags_on_creator_id ON public.audio_events_tags USING btree (creator_id);


--
-- Name: index_audio_events_tags_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_tags_on_updater_id ON public.audio_events_tags USING btree (updater_id);


--
-- Name: index_audio_recording_statistics_on_audio_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recording_statistics_on_audio_recording_id ON public.audio_recording_statistics USING btree (audio_recording_id);


--
-- Name: index_audio_recordings_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_creator_id ON public.audio_recordings USING btree (creator_id);


--
-- Name: index_audio_recordings_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_deleter_id ON public.audio_recordings USING btree (deleter_id);


--
-- Name: index_audio_recordings_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_site_id ON public.audio_recordings USING btree (site_id);


--
-- Name: index_audio_recordings_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_updater_id ON public.audio_recordings USING btree (updater_id);


--
-- Name: index_audio_recordings_on_uploader_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_uploader_id ON public.audio_recordings USING btree (uploader_id);


--
-- Name: index_bookmarks_on_audio_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookmarks_on_audio_recording_id ON public.bookmarks USING btree (audio_recording_id);


--
-- Name: index_bookmarks_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookmarks_on_creator_id ON public.bookmarks USING btree (creator_id);


--
-- Name: index_bookmarks_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookmarks_on_updater_id ON public.bookmarks USING btree (updater_id);


--
-- Name: index_cms_categories_on_site_id_and_cat_type_and_label; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cms_categories_on_site_id_and_cat_type_and_label ON public.comfy_cms_categories USING btree (site_id, categorized_type, label);


--
-- Name: index_cms_categorizations_on_cat_id_and_catd_type_and_catd_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cms_categorizations_on_cat_id_and_catd_type_and_catd_id ON public.comfy_cms_categorizations USING btree (category_id, categorized_type, categorized_id);


--
-- Name: index_cms_revisions_on_rtype_and_rid_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cms_revisions_on_rtype_and_rid_and_created_at ON public.comfy_cms_revisions USING btree (record_type, record_id, created_at);


--
-- Name: index_comfy_cms_files_on_site_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_files_on_site_id_and_position ON public.comfy_cms_files USING btree (site_id, "position");


--
-- Name: index_comfy_cms_fragments_on_boolean; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_fragments_on_boolean ON public.comfy_cms_fragments USING btree ("boolean");


--
-- Name: index_comfy_cms_fragments_on_datetime; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_fragments_on_datetime ON public.comfy_cms_fragments USING btree (datetime);


--
-- Name: index_comfy_cms_fragments_on_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_fragments_on_identifier ON public.comfy_cms_fragments USING btree (identifier);


--
-- Name: index_comfy_cms_fragments_on_record_type_and_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_fragments_on_record_type_and_record_id ON public.comfy_cms_fragments USING btree (record_type, record_id);


--
-- Name: index_comfy_cms_layouts_on_parent_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_layouts_on_parent_id_and_position ON public.comfy_cms_layouts USING btree (parent_id, "position");


--
-- Name: index_comfy_cms_layouts_on_site_id_and_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_comfy_cms_layouts_on_site_id_and_identifier ON public.comfy_cms_layouts USING btree (site_id, identifier);


--
-- Name: index_comfy_cms_pages_on_is_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_pages_on_is_published ON public.comfy_cms_pages USING btree (is_published);


--
-- Name: index_comfy_cms_pages_on_parent_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_pages_on_parent_id_and_position ON public.comfy_cms_pages USING btree (parent_id, "position");


--
-- Name: index_comfy_cms_pages_on_site_id_and_full_path; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_pages_on_site_id_and_full_path ON public.comfy_cms_pages USING btree (site_id, full_path);


--
-- Name: index_comfy_cms_sites_on_hostname; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_sites_on_hostname ON public.comfy_cms_sites USING btree (hostname);


--
-- Name: index_comfy_cms_snippets_on_site_id_and_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_comfy_cms_snippets_on_site_id_and_identifier ON public.comfy_cms_snippets USING btree (site_id, identifier);


--
-- Name: index_comfy_cms_snippets_on_site_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_snippets_on_site_id_and_position ON public.comfy_cms_snippets USING btree (site_id, "position");


--
-- Name: index_comfy_cms_translations_on_is_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_translations_on_is_published ON public.comfy_cms_translations USING btree (is_published);


--
-- Name: index_comfy_cms_translations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_translations_on_locale ON public.comfy_cms_translations USING btree (locale);


--
-- Name: index_comfy_cms_translations_on_page_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comfy_cms_translations_on_page_id ON public.comfy_cms_translations USING btree (page_id);


--
-- Name: index_harvest_items_on_harvest_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_harvest_items_on_harvest_id ON public.harvest_items USING btree (harvest_id);


--
-- Name: index_harvest_items_on_info; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_harvest_items_on_info ON public.harvest_items USING gin (info);


--
-- Name: index_harvest_items_on_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_harvest_items_on_path ON public.harvest_items USING btree (path);


--
-- Name: index_harvest_items_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_harvest_items_on_status ON public.harvest_items USING btree (status);


--
-- Name: index_permissions_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_creator_id ON public.permissions USING btree (creator_id);


--
-- Name: index_permissions_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_project_id ON public.permissions USING btree (project_id);


--
-- Name: index_permissions_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_updater_id ON public.permissions USING btree (updater_id);


--
-- Name: index_permissions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_user_id ON public.permissions USING btree (user_id);


--
-- Name: index_projects_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_creator_id ON public.projects USING btree (creator_id);


--
-- Name: index_projects_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_deleter_id ON public.projects USING btree (deleter_id);


--
-- Name: index_projects_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_updater_id ON public.projects USING btree (updater_id);


--
-- Name: index_projects_saved_searches_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_saved_searches_on_project_id ON public.projects_saved_searches USING btree (project_id);


--
-- Name: index_projects_saved_searches_on_project_id_and_saved_search_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_saved_searches_on_project_id_and_saved_search_id ON public.projects_saved_searches USING btree (project_id, saved_search_id);


--
-- Name: index_projects_saved_searches_on_saved_search_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_saved_searches_on_saved_search_id ON public.projects_saved_searches USING btree (saved_search_id);


--
-- Name: index_projects_sites_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_sites_on_project_id ON public.projects_sites USING btree (project_id);


--
-- Name: index_projects_sites_on_project_id_and_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_sites_on_project_id_and_site_id ON public.projects_sites USING btree (project_id, site_id);


--
-- Name: index_projects_sites_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_sites_on_site_id ON public.projects_sites USING btree (site_id);


--
-- Name: index_saved_searches_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_searches_on_creator_id ON public.saved_searches USING btree (creator_id);


--
-- Name: index_saved_searches_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_searches_on_deleter_id ON public.saved_searches USING btree (deleter_id);


--
-- Name: index_scripts_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scripts_on_creator_id ON public.scripts USING btree (creator_id);


--
-- Name: index_scripts_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scripts_on_group_id ON public.scripts USING btree (group_id);


--
-- Name: index_scripts_on_provenance_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scripts_on_provenance_id ON public.scripts USING btree (provenance_id);


--
-- Name: index_sites_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sites_on_creator_id ON public.sites USING btree (creator_id);


--
-- Name: index_sites_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sites_on_deleter_id ON public.sites USING btree (deleter_id);


--
-- Name: index_sites_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sites_on_updater_id ON public.sites USING btree (updater_id);


--
-- Name: index_tag_groups_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_groups_on_tag_id ON public.tag_groups USING btree (tag_id);


--
-- Name: index_tags_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_creator_id ON public.tags USING btree (creator_id);


--
-- Name: index_tags_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_updater_id ON public.tags USING btree (updater_id);


--
-- Name: index_user_statistics_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_statistics_on_user_id ON public.user_statistics USING btree (user_id);


--
-- Name: index_users_on_authentication_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_authentication_token ON public.users USING btree (authentication_token);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_verifications_on_audio_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_verifications_on_audio_event_id ON public.verifications USING btree (audio_event_id);


--
-- Name: index_verifications_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_verifications_on_tag_id ON public.verifications USING btree (tag_id);


--
-- Name: permissions_project_allow_anonymous_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX permissions_project_allow_anonymous_uidx ON public.permissions USING btree (project_id, allow_anonymous) WHERE (allow_anonymous IS TRUE);


--
-- Name: permissions_project_allow_logged_in_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX permissions_project_allow_logged_in_uidx ON public.permissions USING btree (project_id, allow_logged_in) WHERE (allow_logged_in IS TRUE);


--
-- Name: permissions_project_user_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX permissions_project_user_uidx ON public.permissions USING btree (project_id, user_id) WHERE (user_id IS NOT NULL);


--
-- Name: projects_name_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_name_uidx ON public.projects USING btree (name);


--
-- Name: queue_id_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX queue_id_uidx ON public.analysis_jobs_items USING btree (queue_id);


--
-- Name: saved_searches_name_creator_id_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX saved_searches_name_creator_id_uidx ON public.saved_searches USING btree (name, creator_id);


--
-- Name: tag_groups_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tag_groups_uidx ON public.tag_groups USING btree (tag_id, group_identifier);


--
-- Name: tags_text_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tags_text_uidx ON public.tags USING btree (text);


--
-- Name: users_user_name_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_user_name_unique ON public.users USING btree (user_name);


--
-- Name: analysis_jobs analysis_jobs_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT analysis_jobs_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: analysis_jobs analysis_jobs_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT analysis_jobs_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: analysis_jobs analysis_jobs_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT analysis_jobs_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_event_comments audio_event_comments_audio_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_comments
    ADD CONSTRAINT audio_event_comments_audio_event_id_fk FOREIGN KEY (audio_event_id) REFERENCES public.audio_events(id) ON DELETE CASCADE;


--
-- Name: audio_event_comments audio_event_comments_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_comments
    ADD CONSTRAINT audio_event_comments_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: audio_event_comments audio_event_comments_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_comments
    ADD CONSTRAINT audio_event_comments_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: audio_event_comments audio_event_comments_flagger_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_comments
    ADD CONSTRAINT audio_event_comments_flagger_id_fk FOREIGN KEY (flagger_id) REFERENCES public.users(id);


--
-- Name: audio_event_comments audio_event_comments_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_comments
    ADD CONSTRAINT audio_event_comments_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_event_imports audio_event_imports_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_imports
    ADD CONSTRAINT audio_event_imports_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: audio_event_imports audio_event_imports_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_imports
    ADD CONSTRAINT audio_event_imports_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: audio_event_imports audio_event_imports_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_imports
    ADD CONSTRAINT audio_event_imports_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_events audio_events_audio_recording_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events
    ADD CONSTRAINT audio_events_audio_recording_id_fk FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id) ON DELETE CASCADE;


--
-- Name: audio_events audio_events_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events
    ADD CONSTRAINT audio_events_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: audio_events audio_events_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events
    ADD CONSTRAINT audio_events_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: audio_events_tags audio_events_tags_audio_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events_tags
    ADD CONSTRAINT audio_events_tags_audio_event_id_fk FOREIGN KEY (audio_event_id) REFERENCES public.audio_events(id) ON DELETE CASCADE;


--
-- Name: audio_events_tags audio_events_tags_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events_tags
    ADD CONSTRAINT audio_events_tags_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: audio_events_tags audio_events_tags_tag_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events_tags
    ADD CONSTRAINT audio_events_tags_tag_id_fk FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: audio_events_tags audio_events_tags_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events_tags
    ADD CONSTRAINT audio_events_tags_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_events audio_events_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events
    ADD CONSTRAINT audio_events_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_recordings audio_recordings_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recordings
    ADD CONSTRAINT audio_recordings_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: audio_recordings audio_recordings_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recordings
    ADD CONSTRAINT audio_recordings_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: audio_recordings audio_recordings_site_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recordings
    ADD CONSTRAINT audio_recordings_site_id_fk FOREIGN KEY (site_id) REFERENCES public.sites(id) ON DELETE CASCADE;


--
-- Name: audio_recordings audio_recordings_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recordings
    ADD CONSTRAINT audio_recordings_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_recordings audio_recordings_uploader_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recordings
    ADD CONSTRAINT audio_recordings_uploader_id_fk FOREIGN KEY (uploader_id) REFERENCES public.users(id);


--
-- Name: bookmarks bookmarks_audio_recording_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_audio_recording_id_fk FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id) ON DELETE CASCADE;


--
-- Name: bookmarks bookmarks_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: bookmarks bookmarks_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_event_imports fk_rails_0521146902; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_imports
    ADD CONSTRAINT fk_rails_0521146902 FOREIGN KEY (analysis_job_id) REFERENCES public.analysis_jobs(id);


--
-- Name: harvests fk_rails_08dae8d3d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvests
    ADD CONSTRAINT fk_rails_08dae8d3d9 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_events fk_rails_15ae5d1422; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events
    ADD CONSTRAINT fk_rails_15ae5d1422 FOREIGN KEY (audio_event_import_file_id) REFERENCES public.audio_event_import_files(id) ON DELETE CASCADE;


--
-- Name: progress_events fk_rails_15ea2f07e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.progress_events
    ADD CONSTRAINT fk_rails_15ea2f07e1 FOREIGN KEY (dataset_item_id) REFERENCES public.dataset_items(id) ON DELETE CASCADE;


--
-- Name: questions fk_rails_1b78df6070; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT fk_rails_1b78df6070 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_event_import_files fk_rails_1b93a0a373; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_import_files
    ADD CONSTRAINT fk_rails_1b93a0a373 FOREIGN KEY (analysis_jobs_item_id) REFERENCES public.analysis_jobs_items(id) ON DELETE CASCADE;


--
-- Name: tag_groups fk_rails_1ba11222e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_groups
    ADD CONSTRAINT fk_rails_1ba11222e1 FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: questions fk_rails_21f8d26270; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT fk_rails_21f8d26270 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: harvest_items fk_rails_220bbcd4e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvest_items
    ADD CONSTRAINT fk_rails_220bbcd4e4 FOREIGN KEY (uploader_id) REFERENCES public.users(id);


--
-- Name: provenances fk_rails_293d8f544c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provenances
    ADD CONSTRAINT fk_rails_293d8f544c FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: responses fk_rails_325af149a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responses
    ADD CONSTRAINT fk_rails_325af149a3 FOREIGN KEY (question_id) REFERENCES public.questions(id);


--
-- Name: studies fk_rails_41770507e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.studies
    ADD CONSTRAINT fk_rails_41770507e5 FOREIGN KEY (dataset_id) REFERENCES public.datasets(id);


--
-- Name: studies fk_rails_4362b81edd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.studies
    ADD CONSTRAINT fk_rails_4362b81edd FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: verifications fk_rails_49a28586af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verifications
    ADD CONSTRAINT fk_rails_49a28586af FOREIGN KEY (audio_event_id) REFERENCES public.audio_events(id) ON DELETE CASCADE;


--
-- Name: analysis_jobs_items fk_rails_50c0011a46; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_items
    ADD CONSTRAINT fk_rails_50c0011a46 FOREIGN KEY (script_id) REFERENCES public.scripts(id);


--
-- Name: responses fk_rails_51009e83c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responses
    ADD CONSTRAINT fk_rails_51009e83c9 FOREIGN KEY (study_id) REFERENCES public.studies(id);


--
-- Name: analysis_jobs_items fk_rails_522df5cc92; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_items
    ADD CONSTRAINT fk_rails_522df5cc92 FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id) ON DELETE CASCADE;


--
-- Name: dataset_items fk_rails_5bf6548424; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dataset_items
    ADD CONSTRAINT fk_rails_5bf6548424 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: questions_studies fk_rails_6a5ffa3b4f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions_studies
    ADD CONSTRAINT fk_rails_6a5ffa3b4f FOREIGN KEY (study_id) REFERENCES public.studies(id);


--
-- Name: harvest_items fk_rails_6d8adad6a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvest_items
    ADD CONSTRAINT fk_rails_6d8adad6a1 FOREIGN KEY (harvest_id) REFERENCES public.harvests(id) ON DELETE CASCADE;


--
-- Name: verifications fk_rails_6e0145be93; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verifications
    ADD CONSTRAINT fk_rails_6e0145be93 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_recording_statistics fk_rails_6f222e0805; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_recording_statistics
    ADD CONSTRAINT fk_rails_6f222e0805 FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id) ON DELETE CASCADE;


--
-- Name: verifications fk_rails_77cbfa06a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verifications
    ADD CONSTRAINT fk_rails_77cbfa06a3 FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: responses fk_rails_7a62c4269f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responses
    ADD CONSTRAINT fk_rails_7a62c4269f FOREIGN KEY (dataset_item_id) REFERENCES public.dataset_items(id) ON DELETE CASCADE;


--
-- Name: harvests fk_rails_7b0ec7081d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvests
    ADD CONSTRAINT fk_rails_7b0ec7081d FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: analysis_jobs fk_rails_81c0fed756; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT fk_rails_81c0fed756 FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: dataset_items fk_rails_81ed124069; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dataset_items
    ADD CONSTRAINT fk_rails_81ed124069 FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id) ON DELETE CASCADE;


--
-- Name: analysis_jobs_items fk_rails_86f75840f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_items
    ADD CONSTRAINT fk_rails_86f75840f2 FOREIGN KEY (analysis_job_id) REFERENCES public.analysis_jobs(id) ON DELETE CASCADE;


--
-- Name: sites fk_rails_8829b783ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT fk_rails_8829b783ca FOREIGN KEY (region_id) REFERENCES public.regions(id) ON DELETE CASCADE;


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: analysis_jobs_scripts fk_rails_9f083d42e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_scripts
    ADD CONSTRAINT fk_rails_9f083d42e6 FOREIGN KEY (analysis_job_id) REFERENCES public.analysis_jobs(id) ON DELETE CASCADE;


--
-- Name: regions fk_rails_a2bcbc219c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT fk_rails_a2bcbc219c FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: user_statistics fk_rails_a4ae2a454b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_statistics
    ADD CONSTRAINT fk_rails_a4ae2a454b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: responses fk_rails_a7a3c29a3c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responses
    ADD CONSTRAINT fk_rails_a7a3c29a3c FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: regions fk_rails_a93b9e488e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT fk_rails_a93b9e488e FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: studies fk_rails_a94a68aa0b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.studies
    ADD CONSTRAINT fk_rails_a94a68aa0b FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: analysis_jobs_scripts fk_rails_b0e8ff71e8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_scripts
    ADD CONSTRAINT fk_rails_b0e8ff71e8 FOREIGN KEY (script_id) REFERENCES public.scripts(id);


--
-- Name: audio_event_import_files fk_rails_be11349b96; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_import_files
    ADD CONSTRAINT fk_rails_be11349b96 FOREIGN KEY (audio_event_import_id) REFERENCES public.audio_event_imports(id) ON DELETE CASCADE;


--
-- Name: datasets fk_rails_c2337cbe35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datasets
    ADD CONSTRAINT fk_rails_c2337cbe35 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: questions_studies fk_rails_c7ae81b3ab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions_studies
    ADD CONSTRAINT fk_rails_c7ae81b3ab FOREIGN KEY (question_id) REFERENCES public.questions(id);


--
-- Name: dataset_items fk_rails_c97bdfad35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dataset_items
    ADD CONSTRAINT fk_rails_c97bdfad35 FOREIGN KEY (dataset_id) REFERENCES public.datasets(id);


--
-- Name: progress_events fk_rails_cf446a18ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.progress_events
    ADD CONSTRAINT fk_rails_cf446a18ca FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: verifications fk_rails_d2dd3abbbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verifications
    ADD CONSTRAINT fk_rails_d2dd3abbbb FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: provenances fk_rails_d6ac8b2936; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provenances
    ADD CONSTRAINT fk_rails_d6ac8b2936 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: harvest_items fk_rails_dc2d52ddad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvest_items
    ADD CONSTRAINT fk_rails_dc2d52ddad FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id) ON DELETE CASCADE;


--
-- Name: scripts fk_rails_df2b719b60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scripts
    ADD CONSTRAINT fk_rails_df2b719b60 FOREIGN KEY (provenance_id) REFERENCES public.provenances(id);


--
-- Name: harvests fk_rails_e1f487fcb6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.harvests
    ADD CONSTRAINT fk_rails_e1f487fcb6 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: audio_events fk_rails_e821b1ee82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events
    ADD CONSTRAINT fk_rails_e821b1ee82 FOREIGN KEY (provenance_id) REFERENCES public.provenances(id);


--
-- Name: regions fk_rails_e89672d43e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT fk_rails_e89672d43e FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: provenances fk_rails_eec5c78eb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provenances
    ADD CONSTRAINT fk_rails_eec5c78eb1 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: regions fk_rails_f67676d1b2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT fk_rails_f67676d1b2 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: datasets fk_rails_faaf9c0bcd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datasets
    ADD CONSTRAINT fk_rails_faaf9c0bcd FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: permissions permissions_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: permissions permissions_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_project_id_fk FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: permissions permissions_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: permissions permissions_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_user_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: projects projects_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: projects projects_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: projects_saved_searches projects_saved_searches_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects_saved_searches
    ADD CONSTRAINT projects_saved_searches_project_id_fk FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: projects_saved_searches projects_saved_searches_saved_search_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects_saved_searches
    ADD CONSTRAINT projects_saved_searches_saved_search_id_fk FOREIGN KEY (saved_search_id) REFERENCES public.saved_searches(id);


--
-- Name: projects_sites projects_sites_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects_sites
    ADD CONSTRAINT projects_sites_project_id_fk FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: projects_sites projects_sites_site_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects_sites
    ADD CONSTRAINT projects_sites_site_id_fk FOREIGN KEY (site_id) REFERENCES public.sites(id) ON DELETE CASCADE;


--
-- Name: projects projects_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: saved_searches saved_searches_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: saved_searches saved_searches_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: scripts scripts_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scripts
    ADD CONSTRAINT scripts_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: scripts scripts_group_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scripts
    ADD CONSTRAINT scripts_group_id_fk FOREIGN KEY (group_id) REFERENCES public.scripts(id);


--
-- Name: sites sites_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT sites_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: sites sites_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT sites_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: sites sites_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT sites_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: tags tags_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_creator_id_fk FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: tags tags_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20250402025432'),
('20250211012005'),
('20250120064731'),
('20250113012304'),
('20241106015941'),
('20241004055117'),
('20240828062256'),
('20240524011344'),
('20240524003721'),
('20240110141130'),
('20230512055427'),
('20221219052856'),
('20221215000234'),
('20221117035017'),
('20220930062323'),
('20220825042333'),
('20220808062341'),
('20220704043031'),
('20220629023538'),
('20220603004830'),
('20220407040355'),
('20220406072625'),
('20220331070014'),
('20211024235556'),
('20210730051645'),
('20210707074343'),
('20210707050203'),
('20210707050202'),
('20200904064318'),
('20200901011916'),
('20200831130746'),
('20200714005247'),
('20200625040615'),
('20200625025540'),
('20200612004608'),
('20181210052735'),
('20181210052725'),
('20181210052707'),
('20180118002015'),
('20160726014747'),
('20160712051359'),
('20160614230504'),
('20160420030414'),
('20160306083845'),
('20160226130353'),
('20160226103516'),
('20150905234917'),
('20150904234334'),
('20150819005323'),
('20150807150417'),
('20150710082554'),
('20150710080933'),
('20150709141712'),
('20150709112116'),
('20150307010121'),
('20150306235304'),
('20150306224910'),
('20141115234848'),
('20140901005918'),
('20140819034103'),
('20140621014304'),
('20140404234458'),
('20140222044740'),
('20140127011711'),
('20140125054808'),
('20131230021055'),
('20131124234346'),
('20131120070151'),
('20131002065752'),
('20130919043216'),
('20130913001136'),
('20130905033759'),
('20130830045300'),
('20130828053819'),
('20130819030336'),
('20130729055348'),
('20130729050807'),
('20130725100043'),
('20130725095559'),
('20130724113348'),
('20130724113058'),
('20130719015419'),
('20130718063158'),
('20130718000123'),
('20130715035926'),
('20130715022212');

