--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.12
-- Dumped by pg_dump version 9.5.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: analysis_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE analysis_jobs (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    annotation_name character varying(255),
    custom_settings text NOT NULL,
    script_id integer NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    description text,
    saved_search_id integer NOT NULL,
    started_at timestamp without time zone,
    overall_status character varying DEFAULT 'new'::character varying NOT NULL,
    overall_status_modified_at timestamp without time zone NOT NULL,
    overall_progress text NOT NULL,
    overall_progress_modified_at timestamp without time zone NOT NULL,
    overall_count integer NOT NULL,
    overall_duration_seconds numeric(14,4) NOT NULL,
    overall_data_length_bytes bigint DEFAULT 0 NOT NULL
);


--
-- Name: analysis_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE analysis_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: analysis_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE analysis_jobs_id_seq OWNED BY analysis_jobs.id;


--
-- Name: analysis_jobs_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE analysis_jobs_items (
    id integer NOT NULL,
    analysis_job_id integer NOT NULL,
    audio_recording_id integer NOT NULL,
    queue_id character varying(255),
    status character varying(255) DEFAULT 'new'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    queued_at timestamp without time zone,
    work_started_at timestamp without time zone,
    completed_at timestamp without time zone
);


--
-- Name: analysis_jobs_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE analysis_jobs_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: analysis_jobs_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE analysis_jobs_items_id_seq OWNED BY analysis_jobs_items.id;


--
-- Name: audio_event_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audio_event_comments (
    id integer NOT NULL,
    audio_event_id integer NOT NULL,
    comment text NOT NULL,
    flag character varying(255),
    flag_explain text,
    flagger_id integer,
    flagged_at timestamp without time zone,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: audio_event_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE audio_event_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_event_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE audio_event_comments_id_seq OWNED BY audio_event_comments.id;


--
-- Name: audio_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audio_events (
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
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: audio_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE audio_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE audio_events_id_seq OWNED BY audio_events.id;


--
-- Name: audio_events_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audio_events_tags (
    id integer NOT NULL,
    audio_event_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer
);


--
-- Name: audio_events_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE audio_events_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_events_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE audio_events_tags_id_seq OWNED BY audio_events_tags.id;


--
-- Name: audio_recordings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE audio_recordings (
    id integer NOT NULL,
    uuid character varying(36) NOT NULL,
    uploader_id integer NOT NULL,
    recorded_date timestamp without time zone NOT NULL,
    site_id integer NOT NULL,
    duration_seconds numeric(10,4) NOT NULL,
    sample_rate_hertz integer,
    channels integer,
    bit_rate_bps integer,
    media_type character varying(255) NOT NULL,
    data_length_bytes bigint NOT NULL,
    file_hash character varying(524) NOT NULL,
    status character varying(255) DEFAULT 'new'::character varying,
    notes text,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    original_file_name character varying(255),
    recorded_utc_offset character varying(20)
);


--
-- Name: audio_recordings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE audio_recordings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audio_recordings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE audio_recordings_id_seq OWNED BY audio_recordings.id;


--
-- Name: bookmarks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE bookmarks (
    id integer NOT NULL,
    audio_recording_id integer,
    offset_seconds numeric(10,4),
    name character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer,
    description text,
    category character varying(255)
);


--
-- Name: bookmarks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bookmarks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bookmarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bookmarks_id_seq OWNED BY bookmarks.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE permissions (
    id integer NOT NULL,
    creator_id integer NOT NULL,
    level character varying(255) NOT NULL,
    project_id integer NOT NULL,
    user_id integer NOT NULL,
    updater_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE permissions_id_seq OWNED BY permissions.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE projects (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    urn character varying(255),
    notes text,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    image_file_name character varying(255),
    image_content_type character varying(255),
    image_file_size integer,
    image_updated_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE projects_id_seq OWNED BY projects.id;


--
-- Name: projects_saved_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE projects_saved_searches (
    project_id integer NOT NULL,
    saved_search_id integer NOT NULL
);


--
-- Name: projects_sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE projects_sites (
    project_id integer NOT NULL,
    site_id integer NOT NULL
);


--
-- Name: saved_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE saved_searches (
    id integer NOT NULL,
    name character varying NOT NULL,
    description text,
    stored_query text NOT NULL,
    creator_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    deleter_id integer,
    deleted_at timestamp without time zone
);


--
-- Name: saved_searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE saved_searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_searches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE saved_searches_id_seq OWNED BY saved_searches.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: scripts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scripts (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255),
    analysis_identifier character varying(255) NOT NULL,
    version numeric(4,2) DEFAULT 0.1 NOT NULL,
    verified boolean DEFAULT false,
    group_id integer,
    creator_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    executable_command text NOT NULL,
    executable_settings text NOT NULL,
    executable_settings_media_type character varying(255) DEFAULT 'text/plain'::character varying
);


--
-- Name: scripts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scripts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scripts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scripts_id_seq OWNED BY scripts.id;


--
-- Name: sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sites (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    longitude numeric(9,6),
    latitude numeric(9,6),
    notes text,
    creator_id integer NOT NULL,
    updater_id integer,
    deleter_id integer,
    deleted_at timestamp without time zone,
    image_file_name character varying(255),
    image_content_type character varying(255),
    image_file_size integer,
    image_updated_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    description text,
    tzinfo_tz character varying(255),
    rails_tz character varying(255)
);


--
-- Name: sites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE sites_id_seq OWNED BY sites.id;


--
-- Name: tag_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE tag_groups (
    id integer NOT NULL,
    group_identifier character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    creator_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: tag_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tag_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tag_groups_id_seq OWNED BY tag_groups.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE tags (
    id integer NOT NULL,
    text character varying(255) NOT NULL,
    is_taxanomic boolean DEFAULT false NOT NULL,
    type_of_tag character varying(255) DEFAULT 'general'::character varying NOT NULL,
    retired boolean DEFAULT false NOT NULL,
    notes text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_id integer NOT NULL,
    updater_id integer
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tags_id_seq OWNED BY tags.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE users (
    id integer NOT NULL,
    email character varying(255) DEFAULT NULL::character varying NOT NULL,
    user_name character varying(255) DEFAULT NULL::character varying NOT NULL,
    encrypted_password character varying(255) DEFAULT NULL::character varying NOT NULL,
    reset_password_token character varying(255),
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying(255),
    last_sign_in_ip character varying(255),
    confirmation_token character varying(255),
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    unconfirmed_email character varying(255),
    failed_attempts integer DEFAULT 0,
    unlock_token character varying(255),
    locked_at timestamp without time zone,
    authentication_token character varying(255),
    invitation_token character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    roles_mask integer,
    image_file_name character varying(255),
    image_content_type character varying(255),
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

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs ALTER COLUMN id SET DEFAULT nextval('analysis_jobs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs_items ALTER COLUMN id SET DEFAULT nextval('analysis_jobs_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_event_comments ALTER COLUMN id SET DEFAULT nextval('audio_event_comments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events ALTER COLUMN id SET DEFAULT nextval('audio_events_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events_tags ALTER COLUMN id SET DEFAULT nextval('audio_events_tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_recordings ALTER COLUMN id SET DEFAULT nextval('audio_recordings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bookmarks ALTER COLUMN id SET DEFAULT nextval('bookmarks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY permissions ALTER COLUMN id SET DEFAULT nextval('permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects ALTER COLUMN id SET DEFAULT nextval('projects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY saved_searches ALTER COLUMN id SET DEFAULT nextval('saved_searches_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scripts ALTER COLUMN id SET DEFAULT nextval('scripts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sites ALTER COLUMN id SET DEFAULT nextval('sites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_groups ALTER COLUMN id SET DEFAULT nextval('tag_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY tags ALTER COLUMN id SET DEFAULT nextval('tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: analysis_jobs_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs_items
    ADD CONSTRAINT analysis_jobs_items_pkey PRIMARY KEY (id);


--
-- Name: analysis_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs
    ADD CONSTRAINT analysis_jobs_pkey PRIMARY KEY (id);


--
-- Name: audio_event_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_event_comments
    ADD CONSTRAINT audio_event_comments_pkey PRIMARY KEY (id);


--
-- Name: audio_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events
    ADD CONSTRAINT audio_events_pkey PRIMARY KEY (id);


--
-- Name: audio_events_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events_tags
    ADD CONSTRAINT audio_events_tags_pkey PRIMARY KEY (id);


--
-- Name: audio_recordings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_recordings
    ADD CONSTRAINT audio_recordings_pkey PRIMARY KEY (id);


--
-- Name: bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY (id);


--
-- Name: permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: saved_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY saved_searches
    ADD CONSTRAINT saved_searches_pkey PRIMARY KEY (id);


--
-- Name: scripts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scripts
    ADD CONSTRAINT scripts_pkey PRIMARY KEY (id);


--
-- Name: sites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sites
    ADD CONSTRAINT sites_pkey PRIMARY KEY (id);


--
-- Name: tag_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_groups
    ADD CONSTRAINT tag_groups_pkey PRIMARY KEY (id);


--
-- Name: tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: audio_recordings_created_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_created_updated_at ON audio_recordings USING btree (created_at, updated_at);


--
-- Name: audio_recordings_icase_file_hash_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_icase_file_hash_id_idx ON audio_recordings USING btree (lower((file_hash)::text), id);


--
-- Name: audio_recordings_icase_file_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_icase_file_hash_idx ON audio_recordings USING btree (lower((file_hash)::text));


--
-- Name: audio_recordings_icase_uuid_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_icase_uuid_id_idx ON audio_recordings USING btree (lower((uuid)::text), id);


--
-- Name: audio_recordings_icase_uuid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audio_recordings_icase_uuid_idx ON audio_recordings USING btree (lower((uuid)::text));


--
-- Name: audio_recordings_uuid_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX audio_recordings_uuid_uidx ON audio_recordings USING btree (uuid);


--
-- Name: bookmarks_name_creator_id_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX bookmarks_name_creator_id_uidx ON bookmarks USING btree (name, creator_id);


--
-- Name: index_analysis_jobs_items_on_analysis_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_items_on_analysis_job_id ON analysis_jobs_items USING btree (analysis_job_id);


--
-- Name: index_analysis_jobs_items_on_audio_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_items_on_audio_recording_id ON analysis_jobs_items USING btree (audio_recording_id);


--
-- Name: index_analysis_jobs_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_creator_id ON analysis_jobs USING btree (creator_id);


--
-- Name: index_analysis_jobs_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_deleter_id ON analysis_jobs USING btree (deleter_id);


--
-- Name: index_analysis_jobs_on_script_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_script_id ON analysis_jobs USING btree (script_id);


--
-- Name: index_analysis_jobs_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analysis_jobs_on_updater_id ON analysis_jobs USING btree (updater_id);


--
-- Name: index_audio_event_comments_on_audio_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_audio_event_id ON audio_event_comments USING btree (audio_event_id);


--
-- Name: index_audio_event_comments_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_creator_id ON audio_event_comments USING btree (creator_id);


--
-- Name: index_audio_event_comments_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_deleter_id ON audio_event_comments USING btree (deleter_id);


--
-- Name: index_audio_event_comments_on_flagger_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_flagger_id ON audio_event_comments USING btree (flagger_id);


--
-- Name: index_audio_event_comments_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_event_comments_on_updater_id ON audio_event_comments USING btree (updater_id);


--
-- Name: index_audio_events_on_audio_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_audio_recording_id ON audio_events USING btree (audio_recording_id);


--
-- Name: index_audio_events_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_creator_id ON audio_events USING btree (creator_id);


--
-- Name: index_audio_events_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_deleter_id ON audio_events USING btree (deleter_id);


--
-- Name: index_audio_events_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_on_updater_id ON audio_events USING btree (updater_id);


--
-- Name: index_audio_events_tags_on_audio_event_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_audio_events_tags_on_audio_event_id_and_tag_id ON audio_events_tags USING btree (audio_event_id, tag_id);


--
-- Name: index_audio_events_tags_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_tags_on_creator_id ON audio_events_tags USING btree (creator_id);


--
-- Name: index_audio_events_tags_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_events_tags_on_updater_id ON audio_events_tags USING btree (updater_id);


--
-- Name: index_audio_recordings_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_creator_id ON audio_recordings USING btree (creator_id);


--
-- Name: index_audio_recordings_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_deleter_id ON audio_recordings USING btree (deleter_id);


--
-- Name: index_audio_recordings_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_site_id ON audio_recordings USING btree (site_id);


--
-- Name: index_audio_recordings_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_updater_id ON audio_recordings USING btree (updater_id);


--
-- Name: index_audio_recordings_on_uploader_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audio_recordings_on_uploader_id ON audio_recordings USING btree (uploader_id);


--
-- Name: index_bookmarks_on_audio_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookmarks_on_audio_recording_id ON bookmarks USING btree (audio_recording_id);


--
-- Name: index_bookmarks_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookmarks_on_creator_id ON bookmarks USING btree (creator_id);


--
-- Name: index_bookmarks_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookmarks_on_updater_id ON bookmarks USING btree (updater_id);


--
-- Name: index_permissions_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_creator_id ON permissions USING btree (creator_id);


--
-- Name: index_permissions_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_project_id ON permissions USING btree (project_id);


--
-- Name: index_permissions_on_project_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_project_id_and_user_id ON permissions USING btree (project_id, user_id);


--
-- Name: index_permissions_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_updater_id ON permissions USING btree (updater_id);


--
-- Name: index_permissions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_user_id ON permissions USING btree (user_id);


--
-- Name: index_projects_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_creator_id ON projects USING btree (creator_id);


--
-- Name: index_projects_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_deleter_id ON projects USING btree (deleter_id);


--
-- Name: index_projects_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_updater_id ON projects USING btree (updater_id);


--
-- Name: index_projects_sites_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_sites_on_project_id ON projects_sites USING btree (project_id);


--
-- Name: index_projects_sites_on_project_id_and_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_sites_on_project_id_and_site_id ON projects_sites USING btree (project_id, site_id);


--
-- Name: index_projects_sites_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_sites_on_site_id ON projects_sites USING btree (site_id);


--
-- Name: index_scripts_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scripts_on_creator_id ON scripts USING btree (creator_id);


--
-- Name: index_scripts_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scripts_on_group_id ON scripts USING btree (group_id);


--
-- Name: index_sites_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sites_on_creator_id ON sites USING btree (creator_id);


--
-- Name: index_sites_on_deleter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sites_on_deleter_id ON sites USING btree (deleter_id);


--
-- Name: index_sites_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sites_on_updater_id ON sites USING btree (updater_id);


--
-- Name: index_tag_groups_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_groups_on_tag_id ON tag_groups USING btree (tag_id);


--
-- Name: index_tags_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_creator_id ON tags USING btree (creator_id);


--
-- Name: index_tags_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_updater_id ON tags USING btree (updater_id);


--
-- Name: index_users_on_authentication_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_authentication_token ON users USING btree (authentication_token);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON users USING btree (confirmation_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: jobs_name_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX jobs_name_uidx ON analysis_jobs USING btree (name);


--
-- Name: permissions_level_user_id_project_id_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX permissions_level_user_id_project_id_uidx ON permissions USING btree (project_id, level, user_id);


--
-- Name: projects_name_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_name_uidx ON projects USING btree (name);


--
-- Name: queue_id_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX queue_id_uidx ON analysis_jobs_items USING btree (queue_id);


--
-- Name: tag_groups_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tag_groups_uidx ON tag_groups USING btree (tag_id, group_identifier);


--
-- Name: tags_text_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tags_text_uidx ON tags USING btree (text);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: users_user_name_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_user_name_unique ON users USING btree (user_name);


--
-- Name: analysis_jobs_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs
    ADD CONSTRAINT analysis_jobs_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: analysis_jobs_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs
    ADD CONSTRAINT analysis_jobs_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES users(id);


--
-- Name: analysis_jobs_saved_search_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs
    ADD CONSTRAINT analysis_jobs_saved_search_id_fk FOREIGN KEY (saved_search_id) REFERENCES saved_searches(id);


--
-- Name: analysis_jobs_script_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs
    ADD CONSTRAINT analysis_jobs_script_id_fk FOREIGN KEY (script_id) REFERENCES scripts(id);


--
-- Name: analysis_jobs_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs
    ADD CONSTRAINT analysis_jobs_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- Name: audio_event_comments_audio_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_event_comments
    ADD CONSTRAINT audio_event_comments_audio_event_id_fk FOREIGN KEY (audio_event_id) REFERENCES audio_events(id);


--
-- Name: audio_event_comments_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_event_comments
    ADD CONSTRAINT audio_event_comments_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: audio_event_comments_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_event_comments
    ADD CONSTRAINT audio_event_comments_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES users(id);


--
-- Name: audio_event_comments_flagger_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_event_comments
    ADD CONSTRAINT audio_event_comments_flagger_id_fk FOREIGN KEY (flagger_id) REFERENCES users(id);


--
-- Name: audio_event_comments_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_event_comments
    ADD CONSTRAINT audio_event_comments_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- Name: audio_events_audio_recording_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events
    ADD CONSTRAINT audio_events_audio_recording_id_fk FOREIGN KEY (audio_recording_id) REFERENCES audio_recordings(id);


--
-- Name: audio_events_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events
    ADD CONSTRAINT audio_events_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: audio_events_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events
    ADD CONSTRAINT audio_events_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES users(id);


--
-- Name: audio_events_tags_audio_event_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events_tags
    ADD CONSTRAINT audio_events_tags_audio_event_id_fk FOREIGN KEY (audio_event_id) REFERENCES audio_events(id);


--
-- Name: audio_events_tags_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events_tags
    ADD CONSTRAINT audio_events_tags_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: audio_events_tags_tag_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events_tags
    ADD CONSTRAINT audio_events_tags_tag_id_fk FOREIGN KEY (tag_id) REFERENCES tags(id);


--
-- Name: audio_events_tags_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events_tags
    ADD CONSTRAINT audio_events_tags_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- Name: audio_events_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_events
    ADD CONSTRAINT audio_events_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- Name: audio_recordings_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_recordings
    ADD CONSTRAINT audio_recordings_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: audio_recordings_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_recordings
    ADD CONSTRAINT audio_recordings_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES users(id);


--
-- Name: audio_recordings_site_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_recordings
    ADD CONSTRAINT audio_recordings_site_id_fk FOREIGN KEY (site_id) REFERENCES sites(id);


--
-- Name: audio_recordings_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_recordings
    ADD CONSTRAINT audio_recordings_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- Name: audio_recordings_uploader_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY audio_recordings
    ADD CONSTRAINT audio_recordings_uploader_id_fk FOREIGN KEY (uploader_id) REFERENCES users(id);


--
-- Name: bookmarks_audio_recording_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT bookmarks_audio_recording_id_fk FOREIGN KEY (audio_recording_id) REFERENCES audio_recordings(id);


--
-- Name: bookmarks_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT bookmarks_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: bookmarks_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT bookmarks_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- Name: fk_rails_1ba11222e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_groups
    ADD CONSTRAINT fk_rails_1ba11222e1 FOREIGN KEY (tag_id) REFERENCES tags(id);


--
-- Name: fk_rails_522df5cc92; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs_items
    ADD CONSTRAINT fk_rails_522df5cc92 FOREIGN KEY (audio_recording_id) REFERENCES audio_recordings(id);


--
-- Name: fk_rails_86f75840f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY analysis_jobs_items
    ADD CONSTRAINT fk_rails_86f75840f2 FOREIGN KEY (analysis_job_id) REFERENCES analysis_jobs(id);


--
-- Name: permissions_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: permissions_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_project_id_fk FOREIGN KEY (project_id) REFERENCES projects(id);


--
-- Name: permissions_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- Name: permissions_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_user_id_fk FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: projects_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: projects_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES users(id);


--
-- Name: projects_saved_searches_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects_saved_searches
    ADD CONSTRAINT projects_saved_searches_project_id_fk FOREIGN KEY (project_id) REFERENCES projects(id);


--
-- Name: projects_saved_searches_saved_search_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects_saved_searches
    ADD CONSTRAINT projects_saved_searches_saved_search_id_fk FOREIGN KEY (saved_search_id) REFERENCES saved_searches(id);


--
-- Name: projects_sites_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects_sites
    ADD CONSTRAINT projects_sites_project_id_fk FOREIGN KEY (project_id) REFERENCES projects(id);


--
-- Name: projects_sites_site_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects_sites
    ADD CONSTRAINT projects_sites_site_id_fk FOREIGN KEY (site_id) REFERENCES sites(id);


--
-- Name: projects_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- Name: saved_searches_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY saved_searches
    ADD CONSTRAINT saved_searches_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: saved_searches_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY saved_searches
    ADD CONSTRAINT saved_searches_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES users(id);


--
-- Name: scripts_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scripts
    ADD CONSTRAINT scripts_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: scripts_group_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scripts
    ADD CONSTRAINT scripts_group_id_fk FOREIGN KEY (group_id) REFERENCES scripts(id);


--
-- Name: sites_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sites
    ADD CONSTRAINT sites_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: sites_deleter_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sites
    ADD CONSTRAINT sites_deleter_id_fk FOREIGN KEY (deleter_id) REFERENCES users(id);


--
-- Name: sites_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sites
    ADD CONSTRAINT sites_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- Name: tags_creator_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tags
    ADD CONSTRAINT tags_creator_id_fk FOREIGN KEY (creator_id) REFERENCES users(id);


--
-- Name: tags_updater_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tags
    ADD CONSTRAINT tags_updater_id_fk FOREIGN KEY (updater_id) REFERENCES users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user",public;

INSERT INTO schema_migrations (version) VALUES ('20130715022212');

INSERT INTO schema_migrations (version) VALUES ('20130715035926');

INSERT INTO schema_migrations (version) VALUES ('20130718000123');

INSERT INTO schema_migrations (version) VALUES ('20130718063158');

INSERT INTO schema_migrations (version) VALUES ('20130719015419');

INSERT INTO schema_migrations (version) VALUES ('20130724113058');

INSERT INTO schema_migrations (version) VALUES ('20130724113348');

INSERT INTO schema_migrations (version) VALUES ('20130725095559');

INSERT INTO schema_migrations (version) VALUES ('20130725100043');

INSERT INTO schema_migrations (version) VALUES ('20130729050807');

INSERT INTO schema_migrations (version) VALUES ('20130729055348');

INSERT INTO schema_migrations (version) VALUES ('20130819030336');

INSERT INTO schema_migrations (version) VALUES ('20130828053819');

INSERT INTO schema_migrations (version) VALUES ('20130830045300');

INSERT INTO schema_migrations (version) VALUES ('20130905033759');

INSERT INTO schema_migrations (version) VALUES ('20130913001136');

INSERT INTO schema_migrations (version) VALUES ('20130919043216');

INSERT INTO schema_migrations (version) VALUES ('20131002065752');

INSERT INTO schema_migrations (version) VALUES ('20131120070151');

INSERT INTO schema_migrations (version) VALUES ('20131124234346');

INSERT INTO schema_migrations (version) VALUES ('20131230021055');

INSERT INTO schema_migrations (version) VALUES ('20140125054808');

INSERT INTO schema_migrations (version) VALUES ('20140127011711');

INSERT INTO schema_migrations (version) VALUES ('20140222044740');

INSERT INTO schema_migrations (version) VALUES ('20140404234458');

INSERT INTO schema_migrations (version) VALUES ('20140621014304');

INSERT INTO schema_migrations (version) VALUES ('20140819034103');

INSERT INTO schema_migrations (version) VALUES ('20140901005918');

INSERT INTO schema_migrations (version) VALUES ('20141115234848');

INSERT INTO schema_migrations (version) VALUES ('20150306224910');

INSERT INTO schema_migrations (version) VALUES ('20150306235304');

INSERT INTO schema_migrations (version) VALUES ('20150307010121');

INSERT INTO schema_migrations (version) VALUES ('20150709112116');

INSERT INTO schema_migrations (version) VALUES ('20150709141712');

INSERT INTO schema_migrations (version) VALUES ('20150710080933');

INSERT INTO schema_migrations (version) VALUES ('20150710082554');

INSERT INTO schema_migrations (version) VALUES ('20150807150417');

INSERT INTO schema_migrations (version) VALUES ('20150819005323');

INSERT INTO schema_migrations (version) VALUES ('20150904234334');

INSERT INTO schema_migrations (version) VALUES ('20150905234917');

INSERT INTO schema_migrations (version) VALUES ('20160226103516');

INSERT INTO schema_migrations (version) VALUES ('20160226130353');

INSERT INTO schema_migrations (version) VALUES ('20160420030414');

