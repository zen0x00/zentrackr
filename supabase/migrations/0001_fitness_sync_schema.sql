-- Future cloud contract. The v1 app is local-only and does not connect to Supabase.
create extension if not exists pgcrypto;

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  unit text not null default 'kg' check (unit in ('kg', 'lb')),
  effort_scale text not null default 'rpe' check (effort_scale in ('rpe', 'rir')),
  default_rest_seconds integer not null default 120,
  updated_at timestamptz not null default now()
);
create table public.custom_exercises (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, primary_muscle text not null, equipment text not null,
  tracking_type text not null check (tracking_type in ('weight_reps', 'bodyweight_reps')),
  archived boolean not null default false, created_at timestamptz not null,
  updated_at timestamptz not null, deleted_at timestamptz
);
create table public.routines (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, notes text, archived boolean not null default false,
  created_at timestamptz not null, updated_at timestamptz not null, deleted_at timestamptz
);
create table public.routine_items (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  routine_id uuid not null references public.routines(id) on delete cascade,
  exercise_ref text not null, position integer not null
);
create table public.routine_set_targets (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  routine_item_id uuid not null references public.routine_items(id) on delete cascade,
  position integer not null, set_type text not null default 'working' check (set_type in ('warmup', 'working')),
  target_reps integer, target_weight_kg numeric, target_effort numeric
);
create table public.workouts (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, routine_id uuid references public.routines(id) on delete set null,
  status text not null check (status in ('draft', 'completed', 'discarded')),
  started_at timestamptz not null, completed_at timestamptz, notes text,
  created_at timestamptz not null, updated_at timestamptz not null, deleted_at timestamptz
);
create table public.workout_items (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  workout_id uuid not null references public.workouts(id) on delete cascade,
  exercise_ref text not null, exercise_name_snapshot text not null, position integer not null, notes text
);
create table public.workout_sets (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  workout_item_id uuid not null references public.workout_items(id) on delete cascade,
  position integer not null, set_type text not null check (set_type in ('warmup', 'working')),
  weight_kg numeric, reps integer, effort_value numeric,
  effort_type text check (effort_type in ('rpe', 'rir')),
  completed boolean not null default false, completed_at timestamptz
);

create index routines_user_updated_idx on public.routines(user_id, updated_at desc);
create index workouts_user_completed_idx on public.workouts(user_id, completed_at desc);
create index routine_items_parent_idx on public.routine_items(routine_id, position);
create index workout_items_parent_idx on public.workout_items(workout_id, position);
create index workout_sets_parent_idx on public.workout_sets(workout_item_id, position);

alter table public.profiles enable row level security;
alter table public.custom_exercises enable row level security;
alter table public.routines enable row level security;
alter table public.routine_items enable row level security;
alter table public.routine_set_targets enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_items enable row level security;
alter table public.workout_sets enable row level security;

create policy "profiles_owner" on public.profiles for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "custom_exercises_owner" on public.custom_exercises for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "routines_owner" on public.routines for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "routine_items_owner" on public.routine_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "routine_targets_owner" on public.routine_set_targets for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "workouts_owner" on public.workouts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "workout_items_owner" on public.workout_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "workout_sets_owner" on public.workout_sets for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
