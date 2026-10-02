create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;

create type app_private.user_role as enum ('admin', 'staff');
create type app_private.capture_purpose as enum ('attendance', 'enrolment');
create type app_private.capture_state as enum ('issued', 'claimed', 'consumed', 'expired');
create type app_private.enrolment_state as enum ('active', 'retired', 'revoked');
create type app_private.object_state as enum ('staging', 'attached', 'deleting', 'deleted');

create table app_private.app_settings (
  id smallint primary key default 1 check (id = 1),
  organization_name text not null check (btrim(organization_name) <> ''),
  timezone text not null default 'Asia/Kolkata',
  privacy_version text not null default 'demo-privacy-v1',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_private.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  role app_private.user_role not null,
  display_name varchar(100) not null check (btrim(display_name) <> ''),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_private.staff (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references app_private.profiles(id) on delete restrict,
  name varchar(100) not null check (btrim(name) <> ''),
  employee_id varchar(32) not null unique check (employee_id ~ '^[A-Z0-9_-]{1,32}$'),
  enabled boolean not null default true,
  created_by uuid references app_private.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_private.consents (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references app_private.staff(id) on delete restrict,
  purpose app_private.capture_purpose not null,
  notice_version text not null,
  acknowledged_by uuid references app_private.profiles(id) on delete set null,
  acknowledged_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  source text not null check (source in ('admin_attestation', 'staff_acknowledgement')),
  created_at timestamptz not null default now(),
  check (withdrawn_at is null or withdrawn_at >= acknowledged_at)
);
create unique index consents_one_active_version
  on app_private.consents(staff_id, purpose, notice_version) where withdrawn_at is null;

create table app_private.face_enrolments (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references app_private.staff(id) on delete restrict,
  version integer not null check (version > 0),
  status app_private.enrolment_state not null,
  model_id text not null,
  model_sha256 char(64) not null check (model_sha256 ~ '^[0-9a-f]{64}$'),
  preprocessing_version text not null,
  policy_id text not null,
  dimension smallint not null check (dimension > 0),
  template_ciphertext bytea,
  template_nonce bytea,
  key_version text,
  consent_id uuid not null references app_private.consents(id) on delete restrict,
  created_by uuid references app_private.profiles(id) on delete set null,
  activated_at timestamptz not null default now(),
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (staff_id, version),
  unique (id, staff_id),
  check (
    (status = 'active' and template_ciphertext is not null and octet_length(template_nonce) = 12 and key_version is not null)
    or (status <> 'active' and template_ciphertext is null and template_nonce is null and key_version is null)
  )
);
create unique index face_enrolments_one_active
  on app_private.face_enrolments(staff_id) where status = 'active';

create table app_private.api_sessions (
  session_id uuid primary key,
  profile_id uuid not null references app_private.profiles(id) on delete cascade,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create table app_private.operations (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references app_private.profiles(id) on delete restrict,
  key uuid not null,
  route text not null,
  request_hmac bytea not null check (octet_length(request_hmac) = 32),
  request_hmac_key_version text not null,
  state text not null check (state in ('processing', 'retryable', 'succeeded', 'rejected', 'expired')),
  lease_generation integer not null default 1 check (lease_generation > 0),
  lease_expires_at timestamptz,
  admitted_at timestamptz not null default now(),
  processing_deadline timestamptz not null,
  http_status smallint check (http_status between 100 and 599),
  resource_type text,
  resource_id uuid,
  error_code text,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(actor_id, key)
);

create table app_private.capture_sessions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references app_private.profiles(id) on delete restrict,
  staff_id uuid not null references app_private.staff(id) on delete restrict,
  purpose app_private.capture_purpose not null,
  enrolment_id uuid,
  consent_id uuid not null references app_private.consents(id) on delete restrict,
  policy_id text not null,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  state app_private.capture_state not null default 'issued',
  claimed_operation_id uuid unique references app_private.operations(id) on delete set null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > issued_at)
);

create table app_private.image_objects (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references app_private.staff(id) on delete restrict,
  bucket text not null check (bucket in ('attendance-images', 'enrolment-images')),
  object_key text not null unique,
  purpose app_private.capture_purpose not null,
  state app_private.object_state not null default 'staging',
  operation_id uuid references app_private.operations(id) on delete set null,
  content_hmac bytea not null check (octet_length(content_hmac) = 32),
  hmac_key_version text not null,
  byte_size integer not null check (byte_size between 1 and 2097152),
  width integer not null check (width > 0),
  height integer not null check (height > 0 and width * height <= 4000000),
  enrolment_id uuid references app_private.face_enrolments(id) on delete restrict,
  sample_index smallint check (sample_index between 1 and 3),
  retention_until timestamptz not null,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(enrolment_id, sample_index)
);

create table app_private.attendance (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references app_private.staff(id) on delete restrict,
  capture_session_id uuid not null unique references app_private.capture_sessions(id) on delete restrict,
  enrolment_id uuid not null references app_private.face_enrolments(id) on delete restrict,
  selfie_image_id uuid not null references app_private.image_objects(id) on delete restrict,
  consent_id uuid not null references app_private.consents(id) on delete restrict,
  recorded_at timestamptz not null default now(),
  attendance_date date not null,
  timezone text not null,
  selfie_captured_at timestamptz not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m double precision not null check (accuracy_m > 0 and accuracy_m <= 100),
  location_captured_at timestamptz not null,
  location_is_mocked boolean not null,
  cosine_score double precision not null check (cosine_score between -1 and 1),
  threshold double precision not null check (threshold between -1 and 1),
  policy_id text not null,
  created_at timestamptz not null default now(),
  unique(staff_id, attendance_date),
  check (cosine_score >= threshold)
);

create table app_private.replay_fingerprints (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references app_private.staff(id) on delete restrict,
  pixel_hmac bytea not null check (octet_length(pixel_hmac) = 32),
  key_version text not null,
  capture_session_id uuid not null references app_private.capture_sessions(id) on delete restrict,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique(staff_id, key_version, pixel_hmac)
);

create table app_private.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references app_private.profiles(id) on delete set null,
  staff_id uuid references app_private.staff(id) on delete set null,
  event_type text not null,
  resource_type text not null,
  resource_id uuid,
  outcome_code text not null,
  request_id uuid not null,
  policy_id text,
  created_at timestamptz not null default now()
);

create index staff_created_page on app_private.staff(created_at, id);
create index attendance_staff_history on app_private.attendance(staff_id, recorded_at desc, id);
create index operations_expiry on app_private.operations(state, lease_expires_at, expires_at);
create index images_retention on app_private.image_objects(state, retention_until);
create index replay_expiry on app_private.replay_fingerprints(expires_at);
create index audit_staff_history on app_private.audit_events(staff_id, created_at desc);

alter table app_private.app_settings enable row level security;
alter table app_private.profiles enable row level security;
alter table app_private.staff enable row level security;
alter table app_private.consents enable row level security;
alter table app_private.face_enrolments enable row level security;
alter table app_private.api_sessions enable row level security;
alter table app_private.operations enable row level security;
alter table app_private.capture_sessions enable row level security;
alter table app_private.image_objects enable row level security;
alter table app_private.attendance enable row level security;
alter table app_private.replay_fingerprints enable row level security;
alter table app_private.audit_events enable row level security;

alter table app_private.app_settings force row level security;
alter table app_private.profiles force row level security;
alter table app_private.staff force row level security;
alter table app_private.consents force row level security;
alter table app_private.face_enrolments force row level security;
alter table app_private.api_sessions force row level security;
alter table app_private.operations force row level security;
alter table app_private.capture_sessions force row level security;
alter table app_private.image_objects force row level security;
alter table app_private.attendance force row level security;
alter table app_private.replay_fingerprints force row level security;
alter table app_private.audit_events force row level security;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('attendance-images', 'attendance-images', false, 2097152, array['image/jpeg']),
  ('enrolment-images', 'enrolment-images', false, 2097152, array['image/jpeg'])
on conflict (id) do update
set public = false, file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

revoke all on all tables in schema app_private from public, anon, authenticated;
revoke all on all sequences in schema app_private from public, anon, authenticated;
