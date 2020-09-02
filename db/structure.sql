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
-- Name: is_json(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.is_json(input text) RETURNS boolean
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
    created_at timestamp without time zone NOT NULL
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
-- Name: analysis_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analysis_jobs (
    id integer NOT NULL,
    name character varying NOT NULL,
    annotation_name character varying,
    custom_settings text NOT NULL,
    script_id integer NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description text,
    saved_search_id integer NOT NULL,
    started_at timestamp without time zone,
    overall_status character varying NOT NULL,
    overall_status_modified_at timestamp without time zone NOT NULL,
    overall_progress json NOT NULL,
    overall_progress_modified_at timestamp without time zone NOT NULL,
    overall_count integer NOT NULL,
    overall_duration_seconds numeric(14,4) NOT NULL,
    overall_data_length_bytes bigint DEFAULT 0 NOT NULL
);


--
-- Name: analysis_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.analysis_jobs_id_seq
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
    id integer NOT NULL,
    analysis_job_id integer NOT NULL,
    audio_recording_id integer NOT NULL,
    queue_id character varying(255),
    status character varying(255) DEFAULT 'new'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    queued_at timestamp without time zone,
    work_started_at timestamp without time zone,
    completed_at timestamp without time zone,
    cancel_started_at timestamp without time zone
);


--
-- Name: analysis_jobs_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.analysis_jobs_items_id_seq
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
-- Name: audio_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audio_events (
    id integer NOT NULL,
    audio_recording_id integer NOT NULL,
    start_time_seconds numeric(10,4) NOT NULL,
    end_time_seconds numeric(10,4),
    low_frequency_hertz numeric(10,4) NOT NULL,
    high_frequency_hertz numeric(10,4),
    is_reference boolean DEFAULT false NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: audio_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audio_events_id_seq
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
    image_file_size integer,
    image_updated_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
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
    version numeric(4,2) DEFAULT 0.1 NOT NULL,
    verified boolean DEFAULT false,
    group_id integer,
    creator_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    executable_command text NOT NULL,
    executable_settings text NOT NULL,
    executable_settings_media_type character varying(255) DEFAULT 'text/plain'::character varying,
    analysis_action_params json
);


--
-- Name: scripts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scripts_id_seq
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
    image_file_size integer,
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
    image_file_size integer,
    image_updated_at timestamp without time zone,
    preferences text,
    tzinfo_tz character varying(255),
    rails_tz character varying(255),
    last_seen_at timestamp without time zone
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
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


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
-- Name: dataset_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dataset_items ALTER COLUMN id SET DEFAULT nextval('public.dataset_items_id_seq'::regclass);


--
-- Name: datasets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datasets ALTER COLUMN id SET DEFAULT nextval('public.datasets_id_seq'::regclass);


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
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


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
-- Name: index_analysis_jobs_items_on_analysis_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_items_on_analysis_job_id ON public.analysis_jobs_items USING btree (analysis_job_id);


--
-- Name: index_analysis_jobs_items_on_audio_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_items_on_audio_recording_id ON public.analysis_jobs_items USING btree (audio_recording_id);


--
-- Name: index_analysis_jobs_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_creator_id ON public.analysis_jobs USING btree (creator_id);


--
-- Name: index_analysis_jobs_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_deleter_id ON public.analysis_jobs USING btree (deleter_id);


--
-- Name: index_analysis_jobs_on_saved_search_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_saved_search_id ON public.analysis_jobs USING btree (saved_search_id);


--
-- Name: index_analysis_jobs_on_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_script_id ON public.analysis_jobs USING btree (script_id);


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
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON public.schema_migrations USING btree (version);


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
-- Name: analysis_jobs analysis_jobs_saved_search_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT analysis_jobs_saved_search_id_fk FOREIGN KEY (saved_search_id) REFERENCES public.saved_searches(id);


--
-- Name: analysis_jobs analysis_jobs_script_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT analysis_jobs_script_id_fk FOREIGN KEY (script_id) REFERENCES public.scripts(id);


--
-- Name: analysis_jobs analysis_jobs_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT analysis_jobs_updater_id_fk FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: audio_event_comments audio_event_comments_audio_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_event_comments
    ADD CONSTRAINT audio_event_comments_audio_event_id_fk FOREIGN KEY (audio_event_id) REFERENCES public.audio_events(id);


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
-- Name: audio_events audio_events_audio_recording_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audio_events
    ADD CONSTRAINT audio_events_audio_recording_id_fk FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id);


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
    ADD CONSTRAINT audio_events_tags_audio_event_id_fk FOREIGN KEY (audio_event_id) REFERENCES public.audio_events(id);


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
    ADD CONSTRAINT audio_recordings_site_id_fk FOREIGN KEY (site_id) REFERENCES public.sites(id);


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
    ADD CONSTRAINT bookmarks_audio_recording_id_fk FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id);


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
-- Name: progress_events fk_rails_15ea2f07e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.progress_events
    ADD CONSTRAINT fk_rails_15ea2f07e1 FOREIGN KEY (dataset_item_id) REFERENCES public.dataset_items(id);


--
-- Name: questions fk_rails_1b78df6070; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT fk_rails_1b78df6070 FOREIGN KEY (updater_id) REFERENCES public.users(id);


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
-- Name: responses fk_rails_51009e83c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responses
    ADD CONSTRAINT fk_rails_51009e83c9 FOREIGN KEY (study_id) REFERENCES public.studies(id);


--
-- Name: analysis_jobs_items fk_rails_522df5cc92; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_items
    ADD CONSTRAINT fk_rails_522df5cc92 FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id);


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
-- Name: responses fk_rails_7a62c4269f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responses
    ADD CONSTRAINT fk_rails_7a62c4269f FOREIGN KEY (dataset_item_id) REFERENCES public.dataset_items(id);


--
-- Name: dataset_items fk_rails_81ed124069; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dataset_items
    ADD CONSTRAINT fk_rails_81ed124069 FOREIGN KEY (audio_recording_id) REFERENCES public.audio_recordings(id);


--
-- Name: analysis_jobs_items fk_rails_86f75840f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs_items
    ADD CONSTRAINT fk_rails_86f75840f2 FOREIGN KEY (analysis_job_id) REFERENCES public.analysis_jobs(id);


--
-- Name: sites fk_rails_8829b783ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT fk_rails_8829b783ca FOREIGN KEY (region_id) REFERENCES public.regions(id);


--
-- Name: regions fk_rails_a2bcbc219c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT fk_rails_a2bcbc219c FOREIGN KEY (deleter_id) REFERENCES public.users(id);


--
-- Name: responses fk_rails_a7a3c29a3c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responses
    ADD CONSTRAINT fk_rails_a7a3c29a3c FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: regions fk_rails_a93b9e488e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT fk_rails_a93b9e488e FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: studies fk_rails_a94a68aa0b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.studies
    ADD CONSTRAINT fk_rails_a94a68aa0b FOREIGN KEY (creator_id) REFERENCES public.users(id);


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
-- Name: regions fk_rails_e89672d43e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT fk_rails_e89672d43e FOREIGN KEY (creator_id) REFERENCES public.users(id);


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
    ADD CONSTRAINT permissions_project_id_fk FOREIGN KEY (project_id) REFERENCES public.projects(id);


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
    ADD CONSTRAINT projects_saved_searches_project_id_fk FOREIGN KEY (project_id) REFERENCES public.projects(id);


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
    ADD CONSTRAINT projects_sites_site_id_fk FOREIGN KEY (site_id) REFERENCES public.sites(id);


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
('20130715022212'),
('20130715035926'),
('20130718000123'),
('20130718063158'),
('20130719015419'),
('20130724113058'),
('20130724113348'),
('20130725095559'),
('20130725100043'),
('20130729050807'),
('20130729055348'),
('20130819030336'),
('20130828053819'),
('20130830045300'),
('20130905033759'),
('20130913001136'),
('20130919043216'),
('20131002065752'),
('20131120070151'),
('20131124234346'),
('20131230021055'),
('20140125054808'),
('20140127011711'),
('20140222044740'),
('20140404234458'),
('20140621014304'),
('20140819034103'),
('20140901005918'),
('20141115234848'),
('20150306224910'),
('20150306235304'),
('20150307010121'),
('20150709112116'),
('20150709141712'),
('20150710080933'),
('20150710082554'),
('20150807150417'),
('20150819005323'),
('20150904234334'),
('20150905234917'),
('20160226103516'),
('20160226130353'),
('20160306083845'),
('20160420030414'),
('20160614230504'),
('20160712051359'),
('20160726014747'),
('20180118002015'),
('20181210052707'),
('20181210052725'),
('20181210052735'),
('20200612004608'),
('20200625025540'),
('20200625040615'),
('20200714005247'),
('20200831130746'),
('20200901011916');


