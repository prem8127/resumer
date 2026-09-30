create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('user', 'influencer', 'admin', 'superAdmin');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.review_status as enum ('draft', 'pendingReview', 'approved', 'rejected');
exception when duplicate_object then null;
end $$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '',
  name text not null default '',
  headline text not null default '',
  phone text,
  location text,
  photo_url text,
  role public.app_role not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table public.career_items (
  id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.resumes (
  id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.applications (
  id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.influencers (
  id text primary key,
  owner_id uuid references auth.users(id) on delete set null,
  data jsonb not null default '{}'::jsonb,
  status public.review_status not null default 'draft',
  verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.courses (
  id text primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  status public.review_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.modules (
  id text not null,
  course_id text not null references public.courses(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  position integer not null default 0,
  primary key (course_id, id)
);

create table public.lessons (
  id text not null,
  course_id text not null references public.courses(id) on delete cascade,
  module_id text,
  data jsonb not null default '{}'::jsonb,
  position integer not null default 0,
  primary key (course_id, id),
  foreign key (course_id, module_id) references public.modules(course_id, id) on delete cascade
);

create table public.course_tests (
  id text not null,
  course_id text not null references public.courses(id) on delete cascade,
  lesson_id text,
  is_final boolean not null default false,
  questions jsonb not null default '[]'::jsonb,
  primary key (course_id, id),
  foreign key (course_id, lesson_id) references public.lessons(course_id, id) on delete cascade
);

create table public.test_answer_keys (
  course_id text not null,
  test_id text not null,
  answers jsonb not null default '[]'::jsonb,
  primary key (course_id, test_id),
  foreign key (course_id, test_id) references public.course_tests(course_id, id) on delete cascade
);

create table public.content (
  id text primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  status public.review_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.enrollments (
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id text not null references public.courses(id) on delete cascade,
  progress jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, course_id)
);

create table public.test_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id text not null references public.courses(id) on delete cascade,
  test_id text,
  score integer not null check (score between 0 and 100),
  question_count integer not null check (question_count > 0),
  weak_topics text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table public.certificates (
  id uuid primary key default gen_random_uuid(),
  certificate_code text not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id text not null references public.courses(id) on delete cascade,
  score integer not null check (score between 0 and 100),
  issued_at timestamptz not null default now(),
  unique (user_id, course_id)
);

create index courses_status_idx on public.courses(status);
create index courses_owner_idx on public.courses(owner_id);
create index content_status_idx on public.content(status);
create index attempts_user_course_idx on public.test_attempts(user_id, course_id, created_at desc);

do $$
declare
  v_table_name text;
begin
  foreach v_table_name in array array[
    'profiles', 'influencers', 'courses', 'course_tests', 'content', 'enrollments'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', v_table_name);
    end if;
  end loop;
end;
$$;

create function public.current_app_role()
returns public.app_role
language sql stable security definer
set search_path = ''
as $$ select role from public.profiles where id = (select auth.uid()) $$;

create function public.is_admin()
returns boolean
language sql stable security definer
set search_path = ''
as $$ select coalesce(public.current_app_role() in ('admin', 'superAdmin'), false) $$;

create function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, name)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '')
  ) on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.user_state enable row level security;
alter table public.career_items enable row level security;
alter table public.resumes enable row level security;
alter table public.applications enable row level security;
alter table public.influencers enable row level security;
alter table public.courses enable row level security;
alter table public.modules enable row level security;
alter table public.lessons enable row level security;
alter table public.course_tests enable row level security;
alter table public.test_answer_keys enable row level security;
alter table public.content enable row level security;
alter table public.enrollments enable row level security;
alter table public.test_attempts enable row level security;
alter table public.certificates enable row level security;

create policy "Profiles readable by owner and admins" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));
create policy "Users update own profile without changing role" on public.profiles for update to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()))
  with check (id = (select auth.uid()) or (select public.is_admin()));
revoke update on public.profiles from authenticated;
grant update (email, name, headline, phone, location, photo_url, updated_at) on public.profiles to authenticated;
create policy "Admins create profiles" on public.profiles for insert to authenticated
  with check ((select public.is_admin()) and role <> 'superAdmin');
create policy "Only super admins delete profiles" on public.profiles for delete to authenticated
  using ((select public.current_app_role()) = 'superAdmin');

create policy "Own user state" on public.user_state for all to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()))
  with check (user_id = (select auth.uid()) or (select public.is_admin()));
create policy "Own career items" on public.career_items for all to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()))
  with check (user_id = (select auth.uid()) or (select public.is_admin()));
create policy "Own resumes" on public.resumes for all to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()))
  with check (user_id = (select auth.uid()) or (select public.is_admin()));
create policy "Own applications" on public.applications for all to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()))
  with check (user_id = (select auth.uid()) or (select public.is_admin()));

create policy "Public approved influencers" on public.influencers for select to anon, authenticated
  using (status = 'approved' or owner_id = (select auth.uid()) or (select public.is_admin()));
create policy "Creators edit own influencer profile" on public.influencers for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select public.current_app_role()) in ('influencer', 'admin', 'superAdmin'));
create policy "Creators update own influencer profile" on public.influencers for update to authenticated
  using (owner_id = (select auth.uid()) or (select public.is_admin()))
  with check ((owner_id = (select auth.uid()) and (select public.current_app_role()) in ('influencer', 'admin', 'superAdmin')) or (select public.is_admin()));
create policy "Admins delete influencer profiles" on public.influencers for delete to authenticated
  using ((select public.is_admin()));

create policy "Published courses or owned courses" on public.courses for select to anon, authenticated
  using (status = 'approved' or owner_id = (select auth.uid()) or (select public.is_admin()));
create policy "Creators create courses" on public.courses for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select public.current_app_role()) in ('influencer', 'admin', 'superAdmin'));
create policy "Owners and admins edit courses" on public.courses for update to authenticated
  using (owner_id = (select auth.uid()) or (select public.is_admin()))
  with check (owner_id = (select auth.uid()) or (select public.is_admin()));
create policy "Owners and admins delete courses" on public.courses for delete to authenticated
  using (owner_id = (select auth.uid()) or (select public.is_admin()));

create policy "Read modules for visible courses" on public.modules for select to anon, authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and (c.status = 'approved' or c.owner_id = (select auth.uid()) or (select public.is_admin()))));
create policy "Course owners manage modules" on public.modules for all to authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and (c.owner_id = (select auth.uid()) or (select public.is_admin()))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.owner_id = (select auth.uid()) or (select public.is_admin()))));

create policy "Read lessons for visible courses" on public.lessons for select to anon, authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and (c.status = 'approved' or c.owner_id = (select auth.uid()) or (select public.is_admin()))));
create policy "Course owners manage lessons" on public.lessons for all to authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and (c.owner_id = (select auth.uid()) or (select public.is_admin()))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.owner_id = (select auth.uid()) or (select public.is_admin()))));

create policy "Learners get public questions, owners get answer keys" on public.course_tests for select to anon, authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and (c.status = 'approved' or c.owner_id = (select auth.uid()) or (select public.is_admin()))));
create policy "Owners manage tests" on public.course_tests for all to authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and (c.owner_id = (select auth.uid()) or (select public.is_admin()))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.owner_id = (select auth.uid()) or (select public.is_admin()))));
create policy "Owners and admins manage answer keys" on public.test_answer_keys for all to authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and (c.owner_id = (select auth.uid()) or (select public.is_admin()))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.owner_id = (select auth.uid()) or (select public.is_admin()))));

create policy "Approved or owner content" on public.content for select to anon, authenticated
  using (status = 'approved' or owner_id = (select auth.uid()) or (select public.is_admin()));
create policy "Creator content management" on public.content for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select public.current_app_role()) in ('influencer', 'admin', 'superAdmin'));
create policy "Owner and admin content updates" on public.content for update to authenticated
  using (owner_id = (select auth.uid()) or (select public.is_admin()))
  with check (owner_id = (select auth.uid()) or (select public.is_admin()));
create policy "Owner and admin content deletion" on public.content for delete to authenticated
  using (owner_id = (select auth.uid()) or (select public.is_admin()));

create policy "Own enrollments" on public.enrollments for all to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()))
  with check (user_id = (select auth.uid()) or (select public.is_admin()));
create policy "Own test attempts" on public.test_attempts for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));
create policy "Learners create own attempts" on public.test_attempts for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "Own certificates" on public.certificates for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

create function public.guard_content_moderation()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if (select public.is_admin()) then return new; end if;
  if tg_op = 'INSERT' and new.status <> 'draft' then
    raise exception 'New content must start as draft';
  end if;
  if tg_op = 'INSERT' and tg_table_name = 'influencers' and new.verified then
    raise exception 'Only administrators can verify creators';
  end if;
  if tg_op = 'UPDATE' and new.status is distinct from old.status and new.status in ('approved', 'rejected') then
    raise exception 'Only administrators can approve content or verify creators';
  end if;
  if tg_op = 'UPDATE' and tg_table_name = 'influencers' then
    if new.verified is distinct from old.verified then
      raise exception 'Only administrators can approve content or verify creators';
    end if;
  end if;
  return new;
end;
$$;
create trigger guard_course_moderation before insert or update on public.courses
  for each row execute function public.guard_content_moderation();
create trigger guard_influencer_moderation before insert or update on public.influencers
  for each row execute function public.guard_content_moderation();
create trigger guard_creator_content_moderation before insert or update on public.content
  for each row execute function public.guard_content_moderation();

create function public.admin_set_user_role(target_id uuid, target_role public.app_role)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if (select public.current_app_role()) not in ('admin', 'superAdmin') then
    raise exception 'Administrator access required';
  end if;
  if target_role in ('admin', 'superAdmin') and (select public.current_app_role()) <> 'superAdmin' then
    raise exception 'Only a super administrator can grant administrator roles';
  end if;
  update public.profiles set role = target_role, updated_at = now() where id = target_id;
  if not found then raise exception 'User not found'; end if;
end;
$$;
revoke all on function public.admin_set_user_role(uuid, public.app_role) from public, anon;
grant execute on function public.admin_set_user_role(uuid, public.app_role) to authenticated;

grant usage on schema public to anon, authenticated;
grant select on public.influencers, public.courses, public.modules, public.lessons, public.course_tests, public.content to anon, authenticated;
grant select, insert, update, delete on public.profiles, public.user_state, public.career_items, public.resumes, public.applications, public.influencers, public.courses, public.modules, public.lessons, public.course_tests, public.test_answer_keys, public.content, public.enrollments, public.test_attempts to authenticated;
grant select on public.certificates to authenticated;

insert into storage.buckets (id, name, public, file_size_limit)
values ('public-assets', 'public-assets', true, 104857600),
       ('private-user-files', 'private-user-files', false, 52428800)
on conflict (id) do nothing;

create policy "Public assets readable" on storage.objects for select to anon, authenticated
  using (bucket_id = 'public-assets');
create policy "Creators upload public assets to own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'public-assets' and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.current_app_role()) in ('influencer', 'admin', 'superAdmin'));
create policy "Creators update own public assets" on storage.objects for update to authenticated
  using (bucket_id = 'public-assets' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'public-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Creators delete own public assets" on storage.objects for delete to authenticated
  using (bucket_id = 'public-assets' and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.is_admin())));

create policy "Private files are owner-scoped" on storage.objects for select to authenticated
  using (bucket_id = 'private-user-files' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Upload private files to own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'private-user-files' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Update own private files" on storage.objects for update to authenticated
  using (bucket_id = 'private-user-files' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'private-user-files' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Delete own private files" on storage.objects for delete to authenticated
  using (bucket_id = 'private-user-files' and (storage.foldername(name))[1] = (select auth.uid())::text);
