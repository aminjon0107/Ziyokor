-- AIEdu schema. Run in Supabase Dashboard -> SQL Editor.
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 role text not null default 'student' check(role in ('student','teacher','admin')),
 created_at timestamptz not null default now()
);
create table if not exists public.courses (
 id uuid primary key default gen_random_uuid(),
 title text not null, description text not null default '',
 subject text not null default 'Umumiy', level text not null default 'Boshlang‘ich',
 teacher_id uuid references public.profiles(id) on delete set null,
 published boolean not null default false, created_at timestamptz not null default now()
);
create table if not exists public.enrollments (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.profiles(id) on delete cascade,
 course_id uuid not null references public.courses(id) on delete cascade,
 enrolled_at timestamptz not null default now(), unique(student_id,course_id)
);
create table if not exists public.quiz_results (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.profiles(id) on delete cascade,
 course_id uuid references public.courses(id) on delete set null,
 score integer not null check(score>=0), total integer not null check(total>0),
 created_at timestamptz not null default now()
);
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,role)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),'student')
 on conflict(id) do nothing;
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();
alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.enrollments enable row level security;
alter table public.quiz_results enable row level security;
create policy "Users can read own profile" on public.profiles for select to authenticated using(auth.uid()=id);
create policy "Published courses are readable" on public.courses for select to anon,authenticated using(published=true);
create policy "Students can read own enrollments" on public.enrollments for select to authenticated using(auth.uid()=student_id);
create policy "Students can read own quiz results" on public.quiz_results for select to authenticated using(auth.uid()=student_id);
-- Promote a trusted user to admin manually after checking their UUID:
-- update public.profiles set role='admin' where id='AUTH_USER_UUID';
