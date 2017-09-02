--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: posts; Type: TABLE; Schema: public; Owner: ed_devtracker_crawl_dev; Tablespace: 
--

CREATE TABLE posts (
    id integer NOT NULL,
    datestamp timestamp without time zone,
    url character varying(512),
    urltext character varying(128),
    threadurl character varying(512),
    threadtitle text,
    forum character varying(64),
    whoid integer,
    who character varying(25),
    whourl character varying(128),
    precis text,
    precis_ts_indexed tsvector,
    guid_url character varying(512),
    threadtitle_ts_indexed tsvector
);


ALTER TABLE posts OWNER TO ed_devtracker_crawl_dev;

--
-- Name: posts_id; Type: SEQUENCE; Schema: public; Owner: ed_devtracker_crawl_dev
--

CREATE SEQUENCE posts_id
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE posts_id OWNER TO ed_devtracker_crawl_dev;

--
-- Name: posts_id; Type: SEQUENCE OWNED BY; Schema: public; Owner: ed_devtracker_crawl_dev
--

ALTER SEQUENCE posts_id OWNED BY posts.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ed_devtracker_crawl_dev
--

ALTER TABLE ONLY posts ALTER COLUMN id SET DEFAULT nextval('posts_id'::regclass);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: ed_devtracker_crawl_dev; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: posts_url_key; Type: CONSTRAINT; Schema: public; Owner: ed_devtracker_crawl_dev; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_url_key UNIQUE (url);


--
-- Name: posts_datestamp_index; Type: INDEX; Schema: public; Owner: ed_devtracker_crawl_dev; Tablespace: 
--

CREATE INDEX posts_datestamp_index ON posts USING btree (datestamp);


--
-- Name: posts_guid_url_key; Type: INDEX; Schema: public; Owner: ed_devtracker_crawl_dev; Tablespace: 
--

CREATE UNIQUE INDEX posts_guid_url_key ON posts USING btree (guid_url);


--
-- Name: posts_precis_index; Type: INDEX; Schema: public; Owner: ed_devtracker_crawl_dev; Tablespace: 
--

CREATE INDEX posts_precis_index ON posts USING gin (precis_ts_indexed);


--
-- Name: posts_threadtitle_index; Type: INDEX; Schema: public; Owner: ed_devtracker_crawl_dev; Tablespace: 
--

CREATE INDEX posts_threadtitle_index ON posts USING gin (threadtitle_ts_indexed);


--
-- Name: ts_precis_vectorupdate; Type: TRIGGER; Schema: public; Owner: ed_devtracker_crawl_dev
--

CREATE TRIGGER ts_precis_vectorupdate BEFORE INSERT OR UPDATE ON posts FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('precis_ts_indexed', 'pg_catalog.english', 'precis');


--
-- Name: ts_threadtitle_vectorupdate; Type: TRIGGER; Schema: public; Owner: ed_devtracker_crawl_dev
--

CREATE TRIGGER ts_threadtitle_vectorupdate BEFORE INSERT OR UPDATE ON posts FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('threadtitle_ts_indexed', 'pg_catalog.english', 'threadtitle');


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

