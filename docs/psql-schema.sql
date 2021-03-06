--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.17
-- Dumped by pg_dump version 9.6.17

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
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: ignored_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: ed_devtracker_crawl
--

CREATE SEQUENCE public.ignored_posts_id_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ignored_posts_id_seq OWNER TO ed_devtracker_crawl;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: ignored_posts; Type: TABLE; Schema: public; Owner: ed_devtracker_crawl
--

CREATE TABLE public.ignored_posts (
    id integer DEFAULT nextval('public.ignored_posts_id_seq'::regclass),
    datestamp timestamp without time zone DEFAULT now(),
    url character varying(512)
);


ALTER TABLE public.ignored_posts OWNER TO ed_devtracker_crawl;

--
-- Name: posts; Type: TABLE; Schema: public; Owner: ed_devtracker_crawl
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    datestamp timestamp without time zone,
    url character varying(512),
    urltext character varying(256),
    threadurl character varying(512),
    threadtitle text,
    forum character varying(64),
    whoid integer,
    who character varying(25),
    whourl character varying(128),
    precis text,
    precis_ts_indexed tsvector,
    guid_url character varying(512),
    threadtitle_ts_indexed tsvector,
    fulltext text,
    fulltext_stripped text,
    fulltext_noquotes text,
    fulltext_noquotes_stripped text,
    fulltext_ts_indexed tsvector,
    fulltext_noquotes_ts_indexed tsvector,
    available boolean DEFAULT true
);


ALTER TABLE public.posts OWNER TO ed_devtracker_crawl;

--
-- Name: posts_id; Type: SEQUENCE; Schema: public; Owner: ed_devtracker_crawl
--

CREATE SEQUENCE public.posts_id
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.posts_id OWNER TO ed_devtracker_crawl;

--
-- Name: posts_id; Type: SEQUENCE OWNED BY; Schema: public; Owner: ed_devtracker_crawl
--

ALTER SEQUENCE public.posts_id OWNED BY public.posts.id;


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: ed_devtracker_crawl
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id'::regclass);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: ed_devtracker_crawl
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: posts posts_url_key; Type: CONSTRAINT; Schema: public; Owner: ed_devtracker_crawl
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_url_key UNIQUE (url);


--
-- Name: posts_datestamp_index; Type: INDEX; Schema: public; Owner: ed_devtracker_crawl
--

CREATE INDEX posts_datestamp_index ON public.posts USING btree (datestamp);


--
-- Name: posts_guid_url_key; Type: INDEX; Schema: public; Owner: ed_devtracker_crawl
--

CREATE UNIQUE INDEX posts_guid_url_key ON public.posts USING btree (guid_url);


--
-- Name: posts_precis_index; Type: INDEX; Schema: public; Owner: ed_devtracker_crawl
--

CREATE INDEX posts_precis_index ON public.posts USING gin (precis_ts_indexed);


--
-- Name: posts_threadtitle_index; Type: INDEX; Schema: public; Owner: ed_devtracker_crawl
--

CREATE INDEX posts_threadtitle_index ON public.posts USING gin (threadtitle_ts_indexed);


--
-- Name: posts ts_fulltext_noquotes_vectorupdate; Type: TRIGGER; Schema: public; Owner: ed_devtracker_crawl
--

CREATE TRIGGER ts_fulltext_noquotes_vectorupdate BEFORE INSERT OR UPDATE ON public.posts FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('fulltext_noquotes_ts_indexed', 'pg_catalog.english', 'fulltext_noquotes_stripped');


--
-- Name: posts ts_fulltext_vectorupdate; Type: TRIGGER; Schema: public; Owner: ed_devtracker_crawl
--

CREATE TRIGGER ts_fulltext_vectorupdate BEFORE INSERT OR UPDATE ON public.posts FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('fulltext_ts_indexed', 'pg_catalog.english', 'fulltext_stripped');


--
-- Name: posts ts_precis_vectorupdate; Type: TRIGGER; Schema: public; Owner: ed_devtracker_crawl
--

CREATE TRIGGER ts_precis_vectorupdate BEFORE INSERT OR UPDATE ON public.posts FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('precis_ts_indexed', 'pg_catalog.english', 'precis');


--
-- Name: posts ts_threadtitle_vectorupdate; Type: TRIGGER; Schema: public; Owner: ed_devtracker_crawl
--

CREATE TRIGGER ts_threadtitle_vectorupdate BEFORE INSERT OR UPDATE ON public.posts FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('threadtitle_ts_indexed', 'pg_catalog.english', 'threadtitle');


--
-- PostgreSQL database dump complete
--

