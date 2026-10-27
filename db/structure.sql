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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


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
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    mailbox_id bigint NOT NULL,
    thread_key character varying NOT NULL,
    subject character varying,
    last_sender character varying,
    snippet text,
    last_message_at timestamp(6) without time zone,
    messages_count integer DEFAULT 0 NOT NULL,
    in_inbox boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.conversations FORCE ROW LEVEL SECURITY;


--
-- Name: conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conversations_id_seq OWNED BY public.conversations.id;


--
-- Name: invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitations (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    invited_by_id bigint NOT NULL,
    email_address character varying NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    token character varying NOT NULL,
    accepted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invitations_id_seq OWNED BY public.invitations.id;


--
-- Name: mail_folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mail_folders (
    id bigint NOT NULL,
    mailbox_id bigint NOT NULL,
    name character varying NOT NULL,
    uidvalidity bigint,
    last_uid bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    account_id bigint NOT NULL
);

ALTER TABLE ONLY public.mail_folders FORCE ROW LEVEL SECURITY;


--
-- Name: mail_folders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mail_folders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mail_folders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mail_folders_id_seq OWNED BY public.mail_folders.id;


--
-- Name: mailbox_accesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mailbox_accesses (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    mailbox_id bigint NOT NULL,
    user_id bigint NOT NULL,
    level character varying DEFAULT 'send'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.mailbox_accesses FORCE ROW LEVEL SECURITY;


--
-- Name: mailbox_accesses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mailbox_accesses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mailbox_accesses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mailbox_accesses_id_seq OWNED BY public.mailbox_accesses.id;


--
-- Name: mailboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mailboxes (
    id bigint NOT NULL,
    provider character varying NOT NULL,
    address character varying NOT NULL,
    credentials text,
    sync_state jsonb DEFAULT '{}'::jsonb NOT NULL,
    last_synced_at timestamp(6) without time zone,
    last_sync_error text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    account_id bigint NOT NULL,
    connected_by_id bigint
);

ALTER TABLE ONLY public.mailboxes FORCE ROW LEVEL SECURITY;


--
-- Name: mailboxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mailboxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mailboxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mailboxes_id_seq OWNED BY public.mailboxes.id;


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.memberships_id_seq OWNED BY public.memberships.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id bigint NOT NULL,
    mailbox_id bigint NOT NULL,
    mail_folder_id bigint,
    provider_uid character varying NOT NULL,
    thread_key character varying,
    message_id_header character varying,
    subject character varying,
    from_address character varying,
    from_name character varying,
    to_addresses jsonb DEFAULT '[]'::jsonb NOT NULL,
    cc_addresses jsonb DEFAULT '[]'::jsonb NOT NULL,
    sent_at timestamp(6) without time zone,
    snippet text,
    body_text text,
    body_html text,
    labels jsonb DEFAULT '[]'::jsonb NOT NULL,
    size integer,
    has_attachments boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    account_id bigint NOT NULL,
    conversation_id bigint,
    attachments jsonb DEFAULT '[]'::jsonb NOT NULL
);

ALTER TABLE ONLY public.messages FORCE ROW LEVEL SECURITY;


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: readings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.readings (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    message_id bigint NOT NULL,
    user_id bigint NOT NULL,
    read_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.readings FORCE ROW LEVEL SECURITY;


--
-- Name: readings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.readings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.readings_id_seq OWNED BY public.readings.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    staff boolean DEFAULT false NOT NULL
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
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations ALTER COLUMN id SET DEFAULT nextval('public.conversations_id_seq'::regclass);


--
-- Name: invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations ALTER COLUMN id SET DEFAULT nextval('public.invitations_id_seq'::regclass);


--
-- Name: mail_folders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_folders ALTER COLUMN id SET DEFAULT nextval('public.mail_folders_id_seq'::regclass);


--
-- Name: mailbox_accesses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailbox_accesses ALTER COLUMN id SET DEFAULT nextval('public.mailbox_accesses_id_seq'::regclass);


--
-- Name: mailboxes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailboxes ALTER COLUMN id SET DEFAULT nextval('public.mailboxes_id_seq'::regclass);


--
-- Name: memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships ALTER COLUMN id SET DEFAULT nextval('public.memberships_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: readings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.readings ALTER COLUMN id SET DEFAULT nextval('public.readings_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: mail_folders mail_folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_folders
    ADD CONSTRAINT mail_folders_pkey PRIMARY KEY (id);


--
-- Name: mailbox_accesses mailbox_accesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailbox_accesses
    ADD CONSTRAINT mailbox_accesses_pkey PRIMARY KEY (id);


--
-- Name: mailboxes mailboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailboxes
    ADD CONSTRAINT mailboxes_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: readings readings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.readings
    ADD CONSTRAINT readings_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_conversations_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_account_id ON public.conversations USING btree (account_id);


--
-- Name: index_conversations_on_account_id_and_last_message_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_account_id_and_last_message_at ON public.conversations USING btree (account_id, last_message_at);


--
-- Name: index_conversations_on_mailbox_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_mailbox_id ON public.conversations USING btree (mailbox_id);


--
-- Name: index_conversations_on_mailbox_id_and_thread_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_conversations_on_mailbox_id_and_thread_key ON public.conversations USING btree (mailbox_id, thread_key);


--
-- Name: index_invitations_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_account_id ON public.invitations USING btree (account_id);


--
-- Name: index_invitations_on_invited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_invited_by_id ON public.invitations USING btree (invited_by_id);


--
-- Name: index_invitations_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_on_token ON public.invitations USING btree (token);


--
-- Name: index_mail_folders_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mail_folders_on_account_id ON public.mail_folders USING btree (account_id);


--
-- Name: index_mail_folders_on_mailbox_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mail_folders_on_mailbox_id ON public.mail_folders USING btree (mailbox_id);


--
-- Name: index_mail_folders_on_mailbox_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mail_folders_on_mailbox_id_and_name ON public.mail_folders USING btree (mailbox_id, name);


--
-- Name: index_mailbox_accesses_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mailbox_accesses_on_account_id ON public.mailbox_accesses USING btree (account_id);


--
-- Name: index_mailbox_accesses_on_mailbox_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mailbox_accesses_on_mailbox_id ON public.mailbox_accesses USING btree (mailbox_id);


--
-- Name: index_mailbox_accesses_on_mailbox_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mailbox_accesses_on_mailbox_id_and_user_id ON public.mailbox_accesses USING btree (mailbox_id, user_id);


--
-- Name: index_mailbox_accesses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mailbox_accesses_on_user_id ON public.mailbox_accesses USING btree (user_id);


--
-- Name: index_mailboxes_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mailboxes_on_account_id ON public.mailboxes USING btree (account_id);


--
-- Name: index_mailboxes_on_account_id_and_provider_and_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mailboxes_on_account_id_and_provider_and_address ON public.mailboxes USING btree (account_id, provider, address);


--
-- Name: index_mailboxes_on_connected_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mailboxes_on_connected_by_id ON public.mailboxes USING btree (connected_by_id);


--
-- Name: index_memberships_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_account_id ON public.memberships USING btree (account_id);


--
-- Name: index_memberships_on_account_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_account_id_and_user_id ON public.memberships USING btree (account_id, user_id);


--
-- Name: index_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id ON public.memberships USING btree (user_id);


--
-- Name: index_messages_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_account_id ON public.messages USING btree (account_id);


--
-- Name: index_messages_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_conversation_id ON public.messages USING btree (conversation_id);


--
-- Name: index_messages_on_mail_folder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_mail_folder_id ON public.messages USING btree (mail_folder_id);


--
-- Name: index_messages_on_mailbox_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_mailbox_id ON public.messages USING btree (mailbox_id);


--
-- Name: index_messages_on_mailbox_id_and_provider_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_messages_on_mailbox_id_and_provider_uid ON public.messages USING btree (mailbox_id, provider_uid);


--
-- Name: index_messages_on_mailbox_id_and_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_mailbox_id_and_sent_at ON public.messages USING btree (mailbox_id, sent_at);


--
-- Name: index_messages_on_mailbox_id_and_thread_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_mailbox_id_and_thread_key ON public.messages USING btree (mailbox_id, thread_key);


--
-- Name: index_readings_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_readings_on_account_id ON public.readings USING btree (account_id);


--
-- Name: index_readings_on_message_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_readings_on_message_id_and_user_id ON public.readings USING btree (message_id, user_id);


--
-- Name: index_readings_on_user_id_and_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_readings_on_user_id_and_message_id ON public.readings USING btree (user_id, message_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: conversations fk_rails_00afd02cba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_00afd02cba FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: conversations fk_rails_15ac80a23a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_15ac80a23a FOREIGN KEY (mailbox_id) REFERENCES public.mailboxes(id);


--
-- Name: readings fk_rails_22f92bfeac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.readings
    ADD CONSTRAINT fk_rails_22f92bfeac FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: messages fk_rails_32bdc0a6b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_32bdc0a6b3 FOREIGN KEY (mail_folder_id) REFERENCES public.mail_folders(id);


--
-- Name: messages fk_rails_51faa60c81; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_51faa60c81 FOREIGN KEY (mailbox_id) REFERENCES public.mailboxes(id);


--
-- Name: readings fk_rails_5ed0692eb7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.readings
    ADD CONSTRAINT fk_rails_5ed0692eb7 FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: mail_folders fk_rails_6c7fd64bb4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_folders
    ADD CONSTRAINT fk_rails_6c7fd64bb4 FOREIGN KEY (mailbox_id) REFERENCES public.mailboxes(id);


--
-- Name: mailbox_accesses fk_rails_706fcf23f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailbox_accesses
    ADD CONSTRAINT fk_rails_706fcf23f6 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: messages fk_rails_7f927086d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_7f927086d2 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: mailboxes fk_rails_97a2734fe6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailboxes
    ADD CONSTRAINT fk_rails_97a2734fe6 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: messages fk_rails_a231e55201; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_a231e55201 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: mailboxes fk_rails_b75b98abc9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailboxes
    ADD CONSTRAINT fk_rails_b75b98abc9 FOREIGN KEY (connected_by_id) REFERENCES public.users(id);


--
-- Name: readings fk_rails_c5c96624d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.readings
    ADD CONSTRAINT fk_rails_c5c96624d2 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: mailbox_accesses fk_rails_d78c2686fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailbox_accesses
    ADD CONSTRAINT fk_rails_d78c2686fc FOREIGN KEY (mailbox_id) REFERENCES public.mailboxes(id);


--
-- Name: invitations fk_rails_d799c974a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_d799c974a1 FOREIGN KEY (invited_by_id) REFERENCES public.users(id);


--
-- Name: mailbox_accesses fk_rails_dce3c5a45c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailbox_accesses
    ADD CONSTRAINT fk_rails_dce3c5a45c FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: mail_folders fk_rails_e8cdd440af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mail_folders
    ADD CONSTRAINT fk_rails_e8cdd440af FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: memberships fk_rails_edbc202c67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_edbc202c67 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: invitations fk_rails_efd7f68691; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_efd7f68691 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: conversations account_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_isolation ON public.conversations USING (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint))) WITH CHECK (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint)));


--
-- Name: mail_folders account_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_isolation ON public.mail_folders USING (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint))) WITH CHECK (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint)));


--
-- Name: mailbox_accesses account_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_isolation ON public.mailbox_accesses USING (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint))) WITH CHECK (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint)));


--
-- Name: mailboxes account_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_isolation ON public.mailboxes USING (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint))) WITH CHECK (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint)));


--
-- Name: messages account_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_isolation ON public.messages USING (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint))) WITH CHECK (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint)));


--
-- Name: readings account_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_isolation ON public.readings USING (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint))) WITH CHECK (((current_setting('sg_mail.bypass_rls'::text, true) = 'on'::text) OR (account_id = (NULLIF(current_setting('sg_mail.account_id'::text, true), ''::text))::bigint)));


--
-- Name: conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: mail_folders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.mail_folders ENABLE ROW LEVEL SECURITY;

--
-- Name: mailbox_accesses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.mailbox_accesses ENABLE ROW LEVEL SECURITY;

--
-- Name: mailboxes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.mailboxes ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: readings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.readings ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261027203000'),
('20261027200000'),
('20261027194405'),
('20261027194404'),
('20261027194403'),
('20261027194402'),
('20261027194401'),
('20261027194400'),
('20261027102329'),
('20261027102327'),
('20261027102326');

