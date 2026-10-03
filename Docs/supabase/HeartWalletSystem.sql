-- 하트 재화 · 일일 무료 100회 · 30일 무제한(하트 1개)
-- Supabase SQL Editor에서 실행. Apple/Google 로그인( auth.users ) 기준.

create table if not exists public.heart_wallets (
    auth_user_id uuid primary key references auth.users (id) on delete cascade,
    device_user_id text,
    heart_balance bigint not null default 0 check (heart_balance >= 0),
    daily_free_remaining int not null default 100 check (daily_free_remaining >= 0 and daily_free_remaining <= 100),
    daily_free_period_start date not null default ((timezone('Asia/Seoul', now()))::date),
    unlimited_until timestamptz,
    updated_at timestamptz not null default now()
);

create table if not exists public.heart_iap_grants (
    id uuid primary key default gen_random_uuid(),
    auth_user_id uuid not null references auth.users (id) on delete cascade,
    product_id text not null,
    transaction_id text not null unique,
    hearts_granted bigint not null check (hearts_granted > 0),
    created_at timestamptz not null default now()
);

create index if not exists heart_iap_grants_user_idx on public.heart_iap_grants (auth_user_id);

alter table public.heart_wallets enable row level security;
alter table public.heart_iap_grants enable row level security;

create policy "heart_wallets_select_own"
    on public.heart_wallets for select
    using (auth.uid() = auth_user_id);

create policy "heart_iap_grants_select_own"
    on public.heart_iap_grants for select
    using (auth.uid() = auth_user_id);

-- wallet 행 생성·일일 리셋(KST 자정 기준 date 변경)
create or replace function public.ensure_heart_wallet()
returns public.heart_wallets
language plpgsql
security definer
set search_path = public
as $$
declare
    uid uuid := auth.uid();
    dev text;
    row public.heart_wallets;
    today date := (timezone('Asia/Seoul', now()))::date;
begin
    if uid is null then
        raise exception 'not_authenticated';
    end if;

    dev := lower(trim(coalesce(
        auth.jwt() -> 'user_metadata' ->> 'device_user_id',
        ''
    )));

    insert into public.heart_wallets (auth_user_id, device_user_id)
    values (uid, nullif(dev, ''))
    on conflict (auth_user_id) do update
        set device_user_id = coalesce(nullif(excluded.device_user_id, ''), heart_wallets.device_user_id),
            updated_at = now()
    returning * into row;

    if row.daily_free_period_start < today then
        update public.heart_wallets
        set daily_free_remaining = 100,
            daily_free_period_start = today,
            updated_at = now()
        where auth_user_id = uid
        returning * into row;
    end if;

    return row;
end;
$$;

revoke all on function public.ensure_heart_wallet() from public;
grant execute on function public.ensure_heart_wallet() to authenticated;

-- 이용 1회 차감 (무제한 기간 > daily 무료)
create or replace function public.consume_heart_usage(p_action text default 'generic')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    uid uuid := auth.uid();
    row public.heart_wallets;
    now_ts timestamptz := now();
begin
    if uid is null then
        return jsonb_build_object('allowed', false, 'reason', 'not_authenticated');
    end if;

    row := public.ensure_heart_wallet();

    if row.unlimited_until is not null and row.unlimited_until > now_ts then
        return jsonb_build_object(
            'allowed', true,
            'source', 'unlimited',
            'daily_free_remaining', row.daily_free_remaining,
            'heart_balance', row.heart_balance,
            'unlimited_until', row.unlimited_until
        );
    end if;

    if row.daily_free_remaining > 0 then
        update public.heart_wallets
        set daily_free_remaining = daily_free_remaining - 1,
            updated_at = now()
        where auth_user_id = uid
        returning * into row;

        return jsonb_build_object(
            'allowed', true,
            'source', 'daily_free',
            'daily_free_remaining', row.daily_free_remaining,
            'heart_balance', row.heart_balance,
            'unlimited_until', row.unlimited_until
        );
    end if;

    return jsonb_build_object(
        'allowed', false,
        'reason', 'daily_exhausted',
        'daily_free_remaining', 0,
        'heart_balance', row.heart_balance,
        'unlimited_until', row.unlimited_until
    );
end;
$$;

revoke all on function public.consume_heart_usage(text) from public;
grant execute on function public.consume_heart_usage(text) to authenticated;

-- 하트 1개 → 30일 무제한 (기존 무제한이 남아 있으면 연장)
create or replace function public.purchase_unlimited_month_with_one_heart()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    uid uuid := auth.uid();
    row public.heart_wallets;
    base timestamptz;
    new_until timestamptz;
begin
    if uid is null then
        return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
    end if;

    row := public.ensure_heart_wallet();

    if row.heart_balance < 1 then
        return jsonb_build_object('ok', false, 'reason', 'insufficient_hearts', 'heart_balance', row.heart_balance);
    end if;

    base := greatest(coalesce(row.unlimited_until, now()), now());
    new_until := base + interval '30 days';

    update public.heart_wallets
    set heart_balance = heart_balance - 1,
        unlimited_until = new_until,
        updated_at = now()
    where auth_user_id = uid
    returning * into row;

    return jsonb_build_object(
        'ok', true,
        'heart_balance', row.heart_balance,
        'unlimited_until', row.unlimited_until,
        'daily_free_remaining', row.daily_free_remaining
    );
end;
$$;

revoke all on function public.purchase_unlimited_month_with_one_heart() from public;
grant execute on function public.purchase_unlimited_month_with_one_heart() to authenticated;

-- IAP 크레딧 (transaction_id 중복 방지). App Store 영수증 검증은 추후 Edge Function 권장.
create or replace function public.grant_hearts_iap(
    p_product_id text,
    p_transaction_id text,
    p_hearts bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    uid uuid := auth.uid();
    row public.heart_wallets;
begin
    if uid is null then
        return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
    end if;

    if p_hearts is null or p_hearts <= 0 then
        return jsonb_build_object('ok', false, 'reason', 'invalid_hearts');
    end if;

    if exists (select 1 from public.heart_iap_grants where transaction_id = p_transaction_id) then
        row := public.ensure_heart_wallet();
        return jsonb_build_object('ok', true, 'duplicate', true, 'heart_balance', row.heart_balance);
    end if;

    insert into public.heart_iap_grants (auth_user_id, product_id, transaction_id, hearts_granted)
    values (uid, p_product_id, p_transaction_id, p_hearts);

    update public.heart_wallets
    set heart_balance = heart_balance + p_hearts,
        updated_at = now()
    where auth_user_id = uid
    returning * into row;

    if row.auth_user_id is null then
        row := public.ensure_heart_wallet();
        update public.heart_wallets
        set heart_balance = heart_balance + p_hearts,
            updated_at = now()
        where auth_user_id = uid
        returning * into row;
    end if;

    return jsonb_build_object('ok', true, 'heart_balance', row.heart_balance);
end;
$$;

revoke all on function public.grant_hearts_iap(text, text, bigint) from public;
grant execute on function public.grant_hearts_iap(text, text, bigint) to authenticated;
