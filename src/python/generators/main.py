"""
Gerador de dataset fake para portfólio de engenharia de dados
Inspirado no Wanderbricks - Simula plataforma de reservas de viagens
"""

import pandas as pd
import numpy as np
from faker import Faker
from datetime import datetime, timedelta
import random
import hashlib
from pathlib import Path
import json
import argparse
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from loaders.load_to_sqlserver import SQLServerLoader

fake = Faker('pt_BR')
RANDOM_SEED = 42
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)

VOLUME = {
    'users':      10000,
    'hosts':      2000,
    'properties': 5000,
    'bookings':   50000,
    'payments':   48000,
    'reviews':    30000,
}

# Domínios alinhados com CHECK constraints do DDL
# fact_bookings aceita: ('pending','confirmed','cancelled','completed','no_show')
BOOKING_STATUS         = ['pending', 'confirmed', 'cancelled', 'completed', 'no_show']
BOOKING_STATUS_WEIGHTS = [0.10,      0.50,        0.15,        0.20,        0.05]

PAYMENT_STATUS   = ['pending', 'paid', 'refunded', 'failed']
PAYMENT_METHODS  = ['credit_card', 'debit_card', 'pix', 'bank_transfer', 'paypal']
PROPERTY_TYPES   = ['apartment', 'house', 'cabin', 'loft', 'studio', 'villa']

# Colunas SCD2/DWH que NÃO pertencem ao staging — geradas pelas stored procedures
_SCD2_COLS = [
    'attribute_hash', 'valid_from', 'valid_to', 'is_current',
    'version_number', 'created_at', 'created_by', 'updated_at', 'updated_by',
]
# Surrogate keys e date_sks calculados pelo DWH, não pelo gerador
_DWH_ONLY_COLS = [
    'checkin_date_sk', 'checkout_date_sk', 'created_date_sk', 'payment_date_sk',
]


def generate_id(prefix: str, index: int) -> str:
    unique_str = f"{prefix}_{index}_{RANDOM_SEED}"
    return f"{prefix}_{hashlib.md5(unique_str.encode()).hexdigest()[:8]}"


def random_date(start: datetime, end: datetime) -> datetime:
    return start + timedelta(days=random.randrange((end - start).days))


def _drop_dwh_cols(df: pd.DataFrame) -> pd.DataFrame:
    """Remove colunas que pertencem ao DWH, não ao staging."""
    to_drop = [c for c in _SCD2_COLS + _DWH_ONLY_COLS if c in df.columns]
    return df.drop(columns=to_drop)


# ─────────────────────────────────────────────
# GERADORES  —  colunas alinhadas com staging.*
# ─────────────────────────────────────────────

def generate_users(n: int) -> pd.DataFrame:
    """
    staging.tb_user:
    user_id, user_uuid, full_name, email, phone, country, city,
    user_type, is_verified, total_spent, total_bookings, last_login
    """
    print(f"📊 Gerando {n} usuários...")

    created_dates = [random_date(datetime(2020, 1, 1), datetime(2024, 12, 31))
                     for _ in range(n)]
    return pd.DataFrame({
        'user_id':        range(1, n + 1),
        'user_uuid':      [generate_id('usr', i) for i in range(1, n + 1)],
        'full_name':      [fake.name() for _ in range(n)],
        'email':          [fake.email() for _ in range(n)],
        'phone':          [fake.phone_number() for _ in range(n)],
        'country':        [fake.country() for _ in range(n)],
        'city':           [fake.city() for _ in range(n)],
        'user_type':      random.choices(['standard', 'premium', 'vip'],
                                          weights=[0.7, 0.2, 0.1], k=n),
        'is_verified':    [random.choice([True, False]) for _ in range(n)],
        'total_spent':    [0.0] * n,      # atualizado após pagamentos
        'total_bookings': [0]   * n,      # atualizado após reservas
        'last_login':     [c + timedelta(days=random.randint(1, 365))
                           for c in created_dates],
    })


def generate_hosts(n: int, users_df: pd.DataFrame) -> pd.DataFrame:
    """
    staging.tb_host (criada em 10_create_staging_tables.sql):
    host_id, host_uuid, user_id, full_name, email, phone,
    host_since, host_location, response_rate, response_time,
    is_superhost, total_listings, total_reviews_received, average_rating
    """
    print(f"🏠 Gerando {n} anfitriões...")
    sampled = users_df.sample(n=n, random_state=RANDOM_SEED).reset_index(drop=True)

    return pd.DataFrame({
        'host_id':                range(1, n + 1),
        'host_uuid':              [generate_id('host', i) for i in range(1, n + 1)],
        'user_id':                sampled['user_id'].tolist(),
        'full_name':              sampled['full_name'].tolist(),
        'email':                  sampled['email'].tolist(),
        'phone':                  sampled['phone'].tolist(),
        'host_since':             [random_date(datetime(2020, 1, 1), datetime(2024, 12, 31))
                                   for _ in range(n)],
        'host_location':          [f"{row.city}, {row.country}"
                                   for row in sampled.itertuples()],
        'response_rate':          [random.randint(70, 100) for _ in range(n)],
        'response_time':          random.choices(
                                      ['within_an_hour', 'within_a_few_hours', 'within_a_day'],
                                      k=n),
        'is_superhost':           [random.choice([True, False]) for _ in range(n)],
        'total_listings':         [0] * n,
        'total_reviews_received': [0] * n,
        'average_rating':         [None] * n,
    })


def generate_properties(n: int, hosts_df: pd.DataFrame) -> pd.DataFrame:
    """
    staging.tb_property:
    property_id, property_uuid, host_id, title, description,
    property_type, room_type, accommodates, bedrooms, bathrooms,
    city, state, country, latitude, longitude, price_per_night, cleaning_fee
    """
    print(f"🏢 Gerando {n} propriedades...")

    # Pré-sorteio vetorizado — evita .sample() em loop
    host_idx = np.random.randint(0, len(hosts_df), size=n)
    sel      = hosts_df.iloc[host_idx].reset_index(drop=True)

    df = pd.DataFrame({
        'property_id':     range(1, n + 1),
        'property_uuid':   [generate_id('prop', i) for i in range(1, n + 1)],
        'host_id':         sel['host_id'].tolist(),
        'title':           [fake.catch_phrase() for _ in range(n)],
        'description':     [fake.text(max_nb_chars=200) for _ in range(n)],
        'property_type':   random.choices(PROPERTY_TYPES, k=n),
        'room_type':       random.choices(['entire_place', 'private_room', 'shared_room'], k=n),
        'accommodates':    [random.randint(1, 10) for _ in range(n)],
        'bedrooms':        [random.randint(1, 5)  for _ in range(n)],
        'bathrooms':       [random.randint(1, 4)  for _ in range(n)],
        'city':            [fake.city() for _ in range(n)],
        'state':           [fake.state_abbr() for _ in range(n)],
        'country':         ['Brazil'] * n,
        'latitude':        [float(fake.latitude())  for _ in range(n)],
        'longitude':       [float(fake.longitude()) for _ in range(n)],
        'price_per_night': [random.randint(50, 800) for _ in range(n)],
        'cleaning_fee':    [random.randint(20, 100) for _ in range(n)],
        # colunas auxiliares (descartadas antes da carga no staging)
        '_accommodates':   [random.randint(1, 10) for _ in range(n)],
        '_min_nights':     [random.randint(1, 7)  for _ in range(n)],
        '_max_nights':     [random.randint(7, 90) for _ in range(n)],
    })

    # Atualiza total_listings nos hosts
    counts = df.groupby('host_id').size()
    hosts_df['total_listings'] = hosts_df['host_id'].map(counts).fillna(0).astype(int)

    return df


def generate_bookings(n: int, users_df: pd.DataFrame,
                       properties_df: pd.DataFrame) -> pd.DataFrame:
    """
    staging.tb_booking:
    booking_id, booking_uuid, user_id, property_id, checkin_date, checkout_date,
    number_of_nights, number_of_guests, subtotal, cleaning_fee, service_fee,
    total_price, booking_status, cancellation_date, created_date
    
    NOTA: checkin_date_sk / checkout_date_sk / created_date_sk são gerados
    pela stored procedure no DWH — não pertencem ao staging.
    """
    print(f"📅 Gerando {n} reservas...")

    u_idx = np.random.randint(0, len(users_df),      size=n)
    p_idx = np.random.randint(0, len(properties_df), size=n)
    sel_u = users_df.iloc[u_idx].reset_index(drop=True)
    sel_p = properties_df.iloc[p_idx].reset_index(drop=True)

    base       = datetime(2023, 1, 1)
    date_range = (datetime(2024, 12, 31) - base).days
    checkins   = [base + timedelta(days=int(d))
                  for d in np.random.randint(0, date_range, size=n)]
    statuses   = random.choices(BOOKING_STATUS, weights=BOOKING_STATUS_WEIGHTS, k=n)

    records = []
    for i in range(n):
        checkin  = checkins[i]
        nights   = random.randint(int(sel_p.at[i, '_min_nights']),
                                  min(int(sel_p.at[i, '_max_nights']), 30))
        checkout = checkin + timedelta(days=nights)
        price    = sel_p.at[i, 'price_per_night']
        c_fee    = sel_p.at[i, 'cleaning_fee']
        subtotal = price * nights
        svc_fee  = round(subtotal * 0.10, 2)
        status   = statuses[i]

        records.append({
            'booking_id':       i + 1,
            'booking_uuid':     generate_id('bok', i + 1),
            'user_id':          int(sel_u.at[i, 'user_id']),
            'property_id':      int(sel_p.at[i, 'property_id']),
            'checkin_date':     checkin.date(),
            'checkout_date':    checkout.date(),
            'number_of_nights': nights,
            'number_of_guests': random.randint(1, int(sel_p.at[i, '_accommodates'])),
            'subtotal':         subtotal,
            'cleaning_fee':     c_fee,
            'service_fee':      svc_fee,
            'total_price':      subtotal + c_fee + svc_fee,
            'booking_status':   status,          # alinhado com CHK constraint do DDL
            'cancellation_date':(checkin - timedelta(days=random.randint(1, 30))).date()
                                 if status == 'cancelled' else None,
            'created_date':     (checkin - timedelta(days=random.randint(1, 90))).date(),
        })

    df = pd.DataFrame(records)

    # Atualiza métricas de usuários
    users_df['total_bookings'] = (
        users_df['user_id'].map(df.groupby('user_id').size()).fillna(0).astype(int)
    )
    return df


def generate_payments(n: int, bookings_df: pd.DataFrame) -> pd.DataFrame:
    """
    staging.tb_payment:
    payment_id, transaction_id, booking_id, user_id, amount,
    payment_method, installments, payment_status, payment_date

    NOTA: fee_amount / net_amount / payment_date_sk pertencem à fact_payments
    e são calculados pela stored procedure — não pertencem ao staging.
    """
    print(f"💳 Gerando {n} pagamentos...")
    eligible = bookings_df[bookings_df['booking_status'].isin(['confirmed', 'completed'])]
    selected = eligible.sample(n=min(n, len(eligible)),
                               random_state=RANDOM_SEED).reset_index(drop=True)

    records = []
    for i, row in enumerate(selected.itertuples(), 1):
        checkin  = datetime.combine(row.checkin_date, datetime.min.time())
        pay_date = (checkin - timedelta(days=random.randint(0, 30))).date()

        records.append({
            'payment_id':     i,
            'transaction_id': generate_id('txn', i),
            'booking_id':     row.booking_id,
            'user_id':        row.user_id,
            'amount':         row.total_price,
            'payment_method': random.choice(PAYMENT_METHODS),
            'installments':   random.randint(1, 12) if random.random() > 0.6 else 1,
            'payment_status': random.choices(PAYMENT_STATUS,
                                             weights=[0.05, 0.85, 0.05, 0.05])[0],
            'payment_date':   pay_date,
        })

    df = pd.DataFrame(records)

    # Atualiza total_spent nos usuários
    paid = df[df['payment_status'] == 'paid'].groupby('user_id')['amount'].sum()
    return df, paid   # retorna paid para update externo


# ─────────────────────────────────────────────
# PERSISTÊNCIA
# ─────────────────────────────────────────────

def save_to_parquet(dataframes: dict, output_dir: str = 'data/raw'):
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    for name, df in dataframes.items():
        if df is not None:
            # Remove colunas auxiliares antes de salvar
            clean = df.drop(columns=[c for c in df.columns
                                     if c.startswith('_')], errors='ignore')
            path = Path(output_dir) / f"{name}.parquet"
            clean.to_parquet(path, index=False)
            print(f"💾 {name}.parquet salvo ({len(df):,} registros)")


def save_metadata(dataframes: dict):
    Path('data/metadata').mkdir(parents=True, exist_ok=True)
    metadata = {
        'generated_at': datetime.now().isoformat(),
        'seed':         RANDOM_SEED,
        'volumes':      VOLUME,
        'tables':       {k: list(v.columns) for k, v in dataframes.items() if v is not None},
    }
    with open('data/metadata/schema.json', 'w') as f:
        json.dump(metadata, f, indent=2, default=str)
    print("📋 Metadados salvos em data/metadata/schema.json")


# ─────────────────────────────────────────────
# CARGA E MERGE
# ─────────────────────────────────────────────

# Colunas auxiliares a descartar antes de cada carga no staging
_DROP_BEFORE_LOAD = {
    'properties': ['_accommodates', '_min_nights', '_max_nights'],
}

def load_to_sql_server(dataframes: dict, truncate_first: bool = False) -> bool:
    loader = SQLServerLoader()
    try:
        if not loader.connect():
            print("❌ Falha na conexão com SQL Server")
            return False

        staging_map = {
            'users':      'tb_user',
            'hosts':      'tb_host',
            'properties': 'tb_property',
            'bookings':   'tb_booking',
            'payments':   'tb_payment',
        }

        if truncate_first:
            loader.truncate_staging_tables(list(staging_map.values()))

        for key, table in staging_map.items():
            if key not in dataframes or dataframes[key] is None:
                continue
            df = dataframes[key].copy()
            # Remove colunas auxiliares e colunas exclusivas do DWH
            drop = _DROP_BEFORE_LOAD.get(key, []) + _SCD2_COLS + _DWH_ONLY_COLS
            df   = df.drop(columns=[c for c in drop if c in df.columns])
            print(f"📥 Carregando staging.{table}...")
            loader.load_dataframe(df, table)

        print("✅ Todos os dados carregados com sucesso!")
        return True
    except Exception as e:
        print(f"❌ Erro ao carregar dados: {e}")
        return False
    finally:
        loader.disconnect()


def run_merges(dry_run: bool = True) -> bool:
    loader = SQLServerLoader()
    try:
        if not loader.connect():
            print("❌ Falha na conexão com SQL Server")
            return False

        procedures = ['sp_merge_dim_users', 'sp_merge_dim_hosts', 'sp_merge_dim_properties']
        for proc in procedures:
            print(f"\n📋 Executando {proc} (dry_run={dry_run})...")
            loader.execute_stored_procedure(proc, dry_run=dry_run)
        return True
    except Exception as e:
        print(f"❌ Erro ao executar merges: {e}")
        return False
    finally:
        loader.disconnect()
def load_fact_tables(dry_run: bool = True) -> bool:
    """Carrega as tabelas fato (fact_bookings e fact_payments)"""
    loader = SQLServerLoader()
    try:
        if not loader.connect():
            print("❌ Falha na conexão com SQL Server")
            return False

        procedures = ['sp_load_fact_bookings', 'sp_load_fact_payments']
        for proc in procedures:
            print(f"\n📊 Executando {proc} (dry_run={dry_run})...")
            loader.execute_stored_procedure(proc, dry_run=dry_run)
        return True
    except Exception as e:
        print(f"❌ Erro ao carregar fatos: {e}")
        return False
    finally:
        loader.disconnect()


def update_user_metrics() -> bool:
    """Atualiza métricas agregadas na tabela dim_users"""
    loader = SQLServerLoader()
    try:
        if not loader.connect():
            print("❌ Falha na conexão com SQL Server")
            return False

        print("\n📈 Atualizando métricas dos usuários...")
        loader.execute_stored_procedure('sp_update_user_metrics', dry_run=False)
        return True
    except Exception as e:
        print(f"❌ Erro ao atualizar métricas: {e}")
        return False
    finally:
        loader.disconnect()


def run_full_pipeline(load_sql: bool = False, truncate: bool = False, 
                       merge: bool = False, facts: bool = False, 
                       metrics: bool = False) -> dict:
    """
    Executa o pipeline completo de dados
    
    Args:
        load_sql: Carregar dados para staging
        truncate: Truncar staging antes de carregar
        merge: Executar merges SCD Tipo 2
        facts: Carregar tabelas fato
        metrics: Atualizar métricas dos usuários
    """
    print("🚀 Iniciando pipeline completo...")
    print("=" * 50)
    
    # 1. Gerar dados
    users_df = generate_users(VOLUME['users'])
    hosts_df = generate_hosts(VOLUME['hosts'], users_df)
    properties_df = generate_properties(VOLUME['properties'], hosts_df)
    bookings_df = generate_bookings(VOLUME['bookings'], users_df, properties_df)
    payments_df, paid = generate_payments(VOLUME['payments'], bookings_df)
    
    # Atualiza métricas derivadas
    users_df['total_spent'] = users_df['user_id'].map(paid).fillna(0)
    
    dataframes = {
        'users': users_df,
        'hosts': hosts_df,
        'properties': properties_df,
        'bookings': bookings_df,
        'payments': payments_df,
    }
    
    # 2. Salvar Parquet
    print("\n💾 Salvando arquivos Parquet...")
    save_to_parquet(dataframes)
    save_metadata(dataframes)
    
    loader = SQLServerLoader()
    
    try:
        # 3. Carregar staging
        if load_sql:
            print("\n📤 Carregando dados para o SQL Server...")
            if not loader.connect():
                print("❌ Falha na conexão")
                return dataframes
            
            if truncate:
                staging_tables = ['tb_user', 'tb_host', 'tb_property', 'tb_booking', 'tb_payment']
                loader.truncate_staging_tables(staging_tables)
            
            staging_map = {
                'users': 'tb_user',
                'hosts': 'tb_host',
                'properties': 'tb_property',
                'bookings': 'tb_booking',
                'payments': 'tb_payment',
            }
            
            for key, table in staging_map.items():
                df = dataframes[key].copy()
                drop = _DROP_BEFORE_LOAD.get(key, []) + _SCD2_COLS + _DWH_ONLY_COLS
                df = df.drop(columns=[c for c in drop if c in df.columns], errors='ignore')
                print(f"📥 Carregando staging.{table}...")
                loader.load_dataframe(df, table)
            
            loader.disconnect()
        
        # 4. Executar merges SCD Tipo 2
        if merge:
            print("\n🔄 Executando merges SCD Tipo 2...")
            if not loader.connect():
                print("❌ Falha na conexão")
                return dataframes
            
            procedures = ['sp_merge_dim_users', 'sp_merge_dim_hosts', 'sp_merge_dim_properties']
            for proc in procedures:
                print(f"   Executando {proc}...")
                loader.execute_stored_procedure(proc, dry_run=False)
            
            loader.disconnect()
        
        # 5. Carregar tabelas fato
        if facts:
            print("\n📊 Carregando tabelas fato...")
            if not loader.connect():
                print("❌ Falha na conexão")
                return dataframes
            
            fact_procedures = ['sp_load_fact_bookings', 'sp_load_fact_payments']
            for proc in fact_procedures:
                print(f"   Executando {proc}...")
                loader.execute_stored_procedure(proc, dry_run=False)
            
            loader.disconnect()
        
        # 6. Atualizar métricas
        if metrics:
            print("\n📈 Atualizando métricas dos usuários...")
            if not loader.connect():
                print("❌ Falha na conexão")
                return dataframes
            
            loader.execute_stored_procedure('sp_update_user_metrics', dry_run=False)
            loader.disconnect()
    
    except Exception as e:
        print(f"❌ Erro no pipeline: {e}")
        if loader.conn:
            loader.disconnect()
    
    # 7. Relatório final
    print("\n" + "=" * 50)
    print("✅ PIPELINE CONCLUÍDO!")
    print("=" * 50)
    print(f"📊 Estatísticas geradas:")
    print(f"   - Usuários: {len(users_df):,}")
    print(f"   - Anfitriões: {len(hosts_df):,}")
    print(f"   - Propriedades: {len(properties_df):,}")
    print(f"   - Reservas: {len(bookings_df):,}")
    print(f"   - Pagamentos: {len(payments_df):,}")
    print(f"\n💰 Total em pagamentos: R${payments_df['amount'].sum():,.2f}")
    
    return dataframes

# ─────────────────────────────────────────────
# ORQUESTRADOR
# ─────────────────────────────────────────────

def generate_all_data(load_to_sql: bool = False, truncate_first: bool = False,
                      run_merge: bool = False, save_files: bool = True) -> dict:
    print("🚀 Iniciando geração do dataset...")
    print(f"🎲 Seed: {RANDOM_SEED}")
    print("=" * 50)

    users_df      = generate_users(VOLUME['users'])
    hosts_df      = generate_hosts(VOLUME['hosts'], users_df)
    properties_df = generate_properties(VOLUME['properties'], hosts_df)
    bookings_df   = generate_bookings(VOLUME['bookings'], users_df, properties_df)
    payments_df, paid = generate_payments(VOLUME['payments'], bookings_df)

    # Atualiza métricas derivadas
    users_df['total_spent'] = users_df['user_id'].map(paid).fillna(0)

    dataframes = {
        'users':      users_df,
        'hosts':      hosts_df,
        'properties': properties_df,
        'bookings':   bookings_df,
        'payments':   payments_df,
    }

    if save_files:
        print("\n💾 Salvando arquivos Parquet...")
        save_to_parquet(dataframes)
        save_metadata(dataframes)

    if load_to_sql:
        print("\n📤 Carregando dados para o SQL Server...")
        if load_to_sql_server(dataframes, truncate_first):
            if run_merge:
                print("\n🔄 Executando merges SCD Tipo 2...")
                run_merges(dry_run=False)

    print("\n" + "=" * 50)
    print("✅ PROCESSO CONCLUÍDO!")
    print("=" * 50)
    for name, df in dataframes.items():
        print(f"   - {name.capitalize()}: {len(df):,}")
    print(f"\n💰 Total pago: R${payments_df['amount'].sum():,.2f}")

    return dataframes


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Pipeline de dados — Wanderbricks DWH')
    parser.add_argument('--load-sql',  action='store_true', help='Carregar no SQL Server')
    parser.add_argument('--truncate',  action='store_true', help='Truncar staging antes de carregar')
    parser.add_argument('--merge',     action='store_true', help='Executar merges SCD Tipo 2')
    parser.add_argument('--facts',     action='store_true', help='Carregar tabelas fato')
    parser.add_argument('--metrics',   action='store_true', help='Atualizar métricas dos usuários')
    parser.add_argument('--full',      action='store_true', help='Executar pipeline completo')
    parser.add_argument('--no-save',   action='store_true', help='Não salvar Parquet')
    args = parser.parse_args()
    
    # Se --full, executa tudo
    if args.full:
        run_full_pipeline(
            load_sql=True,
            truncate=True,
            merge=True,
            facts=True,
            metrics=True
        )
    else:
        generate_all_data(
            load_to_sql=args.load_sql,
            truncate_first=args.truncate,
            run_merge=args.merge,
            save_files=not args.no_save
        )
        
        # Executa fatos e métricas se solicitado separadamente
        if args.facts:
            load_fact_tables(dry_run=False)
        if args.metrics:
            update_user_metrics()