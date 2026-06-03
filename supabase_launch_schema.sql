create extension if not exists pgcrypto;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  logo_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  role text not null check (role in ('owner', 'accountant', 'viewer')),
  created_at timestamptz not null default now(),
  unique (user_id, company_id)
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  type text not null check (type in ('income', 'expense')),
  amount numeric(14,2) not null check (amount >= 0),
  vendor text not null default '',
  category text not null default 'Uncategorized',
  date date not null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists transactions_company_date_idx
on public.transactions (company_id, date desc, created_at desc);

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null unique references public.transactions(id) on delete cascade,
  image_url text not null,
  vendor text not null default '',
  amount numeric(14,2) not null check (amount >= 0),
  date date not null,
  raw_text text,
  created_at timestamptz not null default now()
);

create index if not exists receipts_transaction_idx
on public.receipts (transaction_id);

create table if not exists public.integrations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  provider text not null,
  access_token text,
  refresh_token text,
  created_at timestamptz not null default now(),
  unique (company_id, provider)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  message text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.companies enable row level security;
alter table public.members enable row level security;
alter table public.transactions enable row level security;
alter table public.receipts enable row level security;
alter table public.integrations enable row level security;
alter table public.notifications enable row level security;

drop policy if exists companies_select_accessible on public.companies;
create policy companies_select_accessible
on public.companies
for select
to authenticated
using (
  owner_id = auth.uid()
  or id in (
    select company_id from public.members where user_id = auth.uid()
  )
);

drop policy if exists companies_insert_owner on public.companies;
create policy companies_insert_owner
on public.companies
for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists companies_update_owner on public.companies;
create policy companies_update_owner
on public.companies
for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists members_select_accessible on public.members;
create policy members_select_accessible
on public.members
for select
to authenticated
using (
  user_id = auth.uid()
  or company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
  or company_id in (
    select company_id from public.members where user_id = auth.uid()
  )
);

drop policy if exists members_insert_owner on public.members;
create policy members_insert_owner
on public.members
for insert
to authenticated
with check (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
);

drop policy if exists members_update_owner on public.members;
create policy members_update_owner
on public.members
for update
to authenticated
using (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
)
with check (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
);

drop policy if exists transactions_select_accessible on public.transactions;
create policy transactions_select_accessible
on public.transactions
for select
to authenticated
using (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
  or company_id in (
    select company_id from public.members where user_id = auth.uid()
  )
);

drop policy if exists transactions_insert_accessible on public.transactions;
create policy transactions_insert_accessible
on public.transactions
for insert
to authenticated
with check (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
  or company_id in (
    select company_id from public.members where user_id = auth.uid()
  )
);

drop policy if exists transactions_update_accessible on public.transactions;
create policy transactions_update_accessible
on public.transactions
for update
to authenticated
using (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
  or company_id in (
    select company_id from public.members where user_id = auth.uid()
  )
)
with check (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
  or company_id in (
    select company_id from public.members where user_id = auth.uid()
  )
);

drop policy if exists transactions_delete_owner on public.transactions;
create policy transactions_delete_owner
on public.transactions
for delete
to authenticated
using (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
);

drop policy if exists receipts_select_accessible on public.receipts;
create policy receipts_select_accessible
on public.receipts
for select
to authenticated
using (
  transaction_id in (
    select id
    from public.transactions
    where company_id in (
      select id from public.companies where owner_id = auth.uid()
    )
    or company_id in (
      select company_id from public.members where user_id = auth.uid()
    )
  )
);

drop policy if exists receipts_insert_accessible on public.receipts;
create policy receipts_insert_accessible
on public.receipts
for insert
to authenticated
with check (
  transaction_id in (
    select id
    from public.transactions
    where company_id in (
      select id from public.companies where owner_id = auth.uid()
    )
    or company_id in (
      select company_id from public.members where user_id = auth.uid()
    )
  )
);

drop policy if exists receipts_update_accessible on public.receipts;
create policy receipts_update_accessible
on public.receipts
for update
to authenticated
using (
  transaction_id in (
    select id
    from public.transactions
    where company_id in (
      select id from public.companies where owner_id = auth.uid()
    )
    or company_id in (
      select company_id from public.members where user_id = auth.uid()
    )
  )
)
with check (
  transaction_id in (
    select id
    from public.transactions
    where company_id in (
      select id from public.companies where owner_id = auth.uid()
    )
    or company_id in (
      select company_id from public.members where user_id = auth.uid()
    )
  )
);

drop policy if exists receipts_delete_owner on public.receipts;
create policy receipts_delete_owner
on public.receipts
for delete
to authenticated
using (
  transaction_id in (
    select id
    from public.transactions
    where company_id in (
      select id from public.companies where owner_id = auth.uid()
    )
  )
);

drop policy if exists integrations_select_accessible on public.integrations;
create policy integrations_select_accessible
on public.integrations
for select
to authenticated
using (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
  or company_id in (
    select company_id from public.members where user_id = auth.uid()
  )
);

drop policy if exists integrations_mutate_owner on public.integrations;
create policy integrations_mutate_owner
on public.integrations
for all
to authenticated
using (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
)
with check (
  company_id in (
    select id from public.companies where owner_id = auth.uid()
  )
);

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists notifications_insert_own on public.notifications;
create policy notifications_insert_own
on public.notifications
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own
on public.notifications
for delete
to authenticated
using (user_id = auth.uid());

insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

drop policy if exists receipts_bucket_public_read on storage.objects;
create policy receipts_bucket_public_read
on storage.objects
for select
to public
using (bucket_id = 'receipts');

drop policy if exists receipts_bucket_auth_insert on storage.objects;
create policy receipts_bucket_auth_insert
on storage.objects
for insert
to authenticated
with check (bucket_id = 'receipts');

drop policy if exists receipts_bucket_auth_update on storage.objects;
create policy receipts_bucket_auth_update
on storage.objects
for update
to authenticated
using (bucket_id = 'receipts')
with check (bucket_id = 'receipts');

drop policy if exists receipts_bucket_auth_delete on storage.objects;
create policy receipts_bucket_auth_delete
on storage.objects
for delete
to authenticated
using (bucket_id = 'receipts');
