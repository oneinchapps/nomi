-- Kostenbremse für Claude: Jede Anfrage wird mit ihren tatsächlichen Tokens und den daraus
-- berechneten Kosten protokolliert. Die Edge Functions prüfen vor jeder Anfrage das Tagesbudget
-- (pro Haushalt und insgesamt) und lehnen ab, wenn es aufgebraucht ist.

create table public.ai_usage (
    id uuid primary key default gen_random_uuid(),
    household_id uuid references public.households on delete set null,
    user_id uuid references auth.users on delete set null,
    -- z. B. „assistant“, „decide.suggest“, „import-recipe“
    function text not null,
    model text not null,
    calls int not null default 1,
    input_tokens int not null default 0,
    output_tokens int not null default 0,
    cache_read_tokens int not null default 0,
    -- Kosten in Millionstel Dollar (1 $ = 1.000.000)
    cost_micros bigint not null default 0,
    created_at timestamptz not null default now()
);

create index ai_usage_created_idx on public.ai_usage (created_at);
create index ai_usage_household_idx on public.ai_usage (household_id, created_at);

alter table public.ai_usage enable row level security;

-- Lesen dürfen Mitglieder den Verbrauch ihres Haushalts; schreiben nur die Functions
create policy "Mitglieder sehen den KI-Verbrauch ihres Haushalts" on public.ai_usage
    for select to authenticated using (public.is_member(household_id));
grant select on public.ai_usage to authenticated;
grant select, insert on public.ai_usage to service_role;

-- Verbrauch seit Mitternacht (Berliner Zeit): für den Haushalt und für alle zusammen
create function public.ai_spend_today(household uuid)
returns table (household_micros bigint, total_micros bigint)
language sql
stable
security definer
set search_path = ''
as $$
    select
        coalesce(sum(cost_micros) filter (where household_id = household), 0)::bigint,
        coalesce(sum(cost_micros), 0)::bigint
    from public.ai_usage
    where created_at >= (date_trunc('day', now() at time zone 'Europe/Berlin') at time zone 'Europe/Berlin');
$$;

revoke execute on function public.ai_spend_today(uuid) from public, anon, authenticated;
grant execute on function public.ai_spend_today(uuid) to service_role;
