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

# Configuração
fake = Faker('pt_BR') 
RANDOM_SEED = 42
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)

# Configurações de volume (ajuste conforme necessidade)
VOLUME = {
    'users': 10000,
    'hosts': 2000,
    'properties': 5000,
    'bookings': 50000,
    'payments': 48000,  # menos que bookings (alguns não pagos)
    'reviews': 30000,
    'clickstream': 200000
}

# Estados possíveis para status
BOOKING_STATUS = ['pending', 'confirmed', 'cancelled_by_user', 'cancelled_by_host', 'completed', 'no_show']
PAYMENT_STATUS = ['pending', 'paid', 'refunded', 'failed']
PAYMENT_METHODS = ['credit_card', 'debit_card', 'pix', 'bank_transfer', 'paypal']
REVIEW_RATINGS = [1, 2, 3, 4, 5]
PROPERTY_TYPES = ['apartment', 'house', 'cabin', 'loft', 'studio', 'villa']
AMENITIES = ['wifi', 'pool', 'ac', 'parking', 'kitchen', 'tv', 'washer', 'pet_friendly']

# Funções auxiliares
def generate_id(prefix: str, index: int) -> str:
    """Gera ID único no formato {prefix}_{hash}"""
    unique_str = f"{prefix}_{index}_{RANDOM_SEED}_{datetime.now()}"
    return f"{prefix}_{hashlib.md5(unique_str.encode()).hexdigest()[:8]}"

def random_date(start_date: datetime, end_date: datetime) -> datetime:
    """Gera data aleatória entre duas datas"""
    time_between = end_date - start_date
    days_between = time_between.days
    random_days = random.randrange(days_between)
    return start_date + timedelta(days=random_days)

def generate_sensitive_data(n: int) -> pd.DataFrame:
    """Gera dados sensíveis separadamente (exemplo para mostrar tratamento)"""
    return pd.DataFrame({
        'user_id': range(1, n+1),
        'credit_card_last4': [f"{random.randint(1000, 9999)}" for _ in range(n)],
        'credit_card_brand': [random.choice(['visa', 'mastercard', 'amex']) for _ in range(n)],
        'cpf': [fake.cpf() for _ in range(n)]
    })

# 1. Tabela de Usuários
def generate_users(n: int) -> pd.DataFrame:
    print(f"📊 Gerando {n} usuários...")
    users = []
    for i in range(1, n+1):
        created_at = random_date(datetime(2020, 1, 1), datetime(2024, 12, 31))
        users.append({
            'user_id': i,
            'user_uuid': generate_id('usr', i),
            'name': fake.name(),
            'email': fake.email(),
            'phone': fake.phone_number(),
            'country': fake.country(),
            'city': fake.city(),
            'user_type': random.choices(['standard', 'premium', 'vip'], weights=[0.7, 0.2, 0.1])[0],
            'is_verified': random.choice([True, False]),
            'created_at': created_at,
            'last_login': created_at + timedelta(days=random.randint(1, 365)),
            'total_spent': 0.0  # será atualizado depois
        })
    return pd.DataFrame(users)

# 2. Tabela de Anfitriões
def generate_hosts(n: int, users_df: pd.DataFrame) -> pd.DataFrame:
    print(f"🏠 Gerando {n} anfitriões...")
    hosts = []
    available_users = users_df.sample(n=n, random_state=RANDOM_SEED)
    
    for i, user in enumerate(available_users.itertuples(), 1):
        hosts.append({
            'host_id': i,
            'user_id': user.user_id,
            'host_since': random_date(datetime(2020, 1, 1), datetime(2024, 12, 31)),
            'response_rate': random.randint(70, 100),
            'response_time': random.choice(['within_an_hour', 'within_a_few_hours', 'within_a_day']),
            'is_superhost': random.choice([True, False]),
            'total_listings': 0
        })
    return pd.DataFrame(hosts)

# 3. Tabela de Propriedades
def generate_properties(n: int, hosts_df: pd.DataFrame) -> pd.DataFrame:
    print(f"🏢 Gerando {n} propriedades...")
    properties = []
    
    for i in range(1, n+1):
        host = hosts_df.sample(1).iloc[0]
        amenities_sample = random.sample(AMENITIES, k=random.randint(3, 8))
        
        properties.append({
            'property_id': i,
            'property_uuid': generate_id('prop', i),
            'host_id': host['host_id'],
            'title': fake.catch_phrase(),
            'description': fake.text(max_nb_chars=200),
            'property_type': random.choice(PROPERTY_TYPES),
            'room_type': random.choice(['entire_place', 'private_room', 'shared_room']),
            'accommodates': random.randint(1, 10),
            'bedrooms': random.randint(1, 5),
            'bathrooms': random.randint(1, 4),
            'price_per_night': random.randint(50, 800),
            'cleaning_fee': random.randint(20, 100),
            'minimum_nights': random.randint(1, 7),
            'maximum_nights': random.randint(7, 90),
            'latitude': float(fake.latitude()),
            'longitude': float(fake.longitude()),
            'city': fake.city(),
            'state': fake.state_abbr(),
            'country': 'Brazil',
            'amenities': ','.join(amenities_sample),
            'created_at': random_date(datetime(2020, 1, 1), datetime(2024, 12, 31))
        })
    
    return pd.DataFrame(properties)

# 4. Tabela de Reservas (core do negócio)
def generate_bookings(n: int, users_df: pd.DataFrame, properties_df: pd.DataFrame) -> pd.DataFrame:
    print(f"📅 Gerando {n} reservas...")
    bookings = []
    
    for i in range(1, n+1):
        user = users_df.sample(1).iloc[0]
        property_row = properties_df.sample(1).iloc[0]
        
        checkin = random_date(datetime(2023, 1, 1), datetime(2024, 12, 31))
        nights = random.randint(property_row['minimum_nights'], 
                               min(property_row['maximum_nights'], 30))
        checkout = checkin + timedelta(days=nights)
        
        price_per_night = property_row['price_per_night']
        cleaning_fee = property_row['cleaning_fee']
        subtotal = price_per_night * nights
        total_price = subtotal + cleaning_fee
        
        status = random.choices(
            BOOKING_STATUS,
            weights=[0.1, 0.5, 0.1, 0.05, 0.2, 0.05]  # 50% confirmadas
        )[0]
        
        bookings.append({
            'booking_id': i,
            'booking_uuid': generate_id('bok', i),
            'user_id': user.user_id,
            'property_id': property_row['property_id'],
            'checkin_date': checkin,
            'checkout_date': checkout,
            'number_of_nights': nights,
            'number_of_guests': random.randint(1, property_row['accommodates']),
            'subtotal': subtotal,
            'cleaning_fee': cleaning_fee,
            'total_price': total_price,
            'status': status,
            'cancellation_date': checkin - timedelta(days=random.randint(1, 30)) if status == 'cancelled_by_user' else None,
            'created_at': checkin - timedelta(days=random.randint(1, 90)),
            'updated_at': datetime.now()
        })
    
    return pd.DataFrame(bookings)

# 5. Tabela de Pagamentos
def generate_payments(n: int, bookings_df: pd.DataFrame) -> pd.DataFrame:
    print(f"💳 Gerando {n} pagamentos...")
    # Apenas reservas confirmadas ou completadas geram pagamento
    eligible_bookings = bookings_df[bookings_df['status'].isin(['confirmed', 'completed'])]
    
    if len(eligible_bookings) > n:
        selected_bookings = eligible_bookings.sample(n=n, random_state=RANDOM_SEED)
    else:
        selected_bookings = eligible_bookings
    
    payments = []
    for i, booking in enumerate(selected_bookings.itertuples(), 1):
        payment_date = booking.checkin_date - timedelta(days=random.randint(0, 30))
        
        payments.append({
            'payment_id': i,
            'booking_id': booking.booking_id,
            'user_id': booking.user_id,
            'amount': booking.total_price,
            'payment_method': random.choice(PAYMENT_METHODS),
            'payment_status': random.choices(PAYMENT_STATUS, weights=[0.05, 0.85, 0.05, 0.05])[0],
            'payment_date': payment_date if random.random() > 0.1 else None,
            'transaction_id': generate_id('txn', i),
            'installments': random.randint(1, 12) if random.random() > 0.6 else 1
        })
    
    return pd.DataFrame(payments)

# 6. Tabela de Avaliações
def generate_reviews(n: int, bookings_df: pd.DataFrame) -> pd.DataFrame:
    print(f"⭐ Gerando {n} avaliações...")
    # Apenas reservas completadas geram review
    completed_bookings = bookings_df[bookings_df['status'] == 'completed']
    
    if len(completed_bookings) > n:
        selected_bookings = completed_bookings.sample(n=n, random_state=RANDOM_SEED)
    else:
        selected_bookings = completed_bookings
    
    reviews = []
    for i, booking in enumerate(selected_bookings.itertuples(), 1):
        review_date = booking.checkout_date + timedelta(days=random.randint(1, 14))
        rating = random.choices(REVIEW_RATINGS, weights=[0.05, 0.05, 0.1, 0.3, 0.5])[0]
        
        reviews.append({
            'review_id': i,
            'booking_id': booking.booking_id,
            'user_id': booking.user_id,
            'property_id': booking.property_id,
            'rating': rating,
            'comment': fake.text(max_nb_chars=500) if rating >= 3 or random.random() > 0.3 else None,
            'review_date': review_date,
            'host_response': fake.text(max_nb_chars=200) if random.random() > 0.6 else None
        })
    
    return pd.DataFrame(reviews)

# 7. Tabela de Clickstream (eventos de navegação)
def generate_clickstream(n: int, users_df: pd.DataFrame, properties_df: pd.DataFrame) -> pd.DataFrame:
    print(f"🖱️ Gerando {n} eventos de clickstream...")
    events = []
    actions = ['view_property', 'search', 'click_host', 'apply_filter', 'add_to_wishlist', 'share']
    
    for i in range(1, n+1):
        user = users_df.sample(1).iloc[0]
        property_row = properties_df.sample(1).iloc[0] if random.random() > 0.5 else None
        
        events.append({
            'event_id': i,
            'user_id': user.user_id,
            'session_id': generate_id('sess', random.randint(1, 10000)),
            'event_type': random.choice(actions),
            'property_id': property_row['property_id'] if property_row is not None else None,
            'search_query': fake.city() if random.random() > 0.7 else None,
            'device_type': random.choice(['mobile', 'desktop', 'tablet']),
            'event_timestamp': random_date(datetime(2024, 1, 1), datetime(2024, 12, 31))
        })
    
    return pd.DataFrame(events)

# Função principal que orquestra tudo
def main():
    print("🚀 Iniciando geração do dataset...")
    print(f"🎲 Seed aleatória: {RANDOM_SEED}")
    
    # Criar diretórios
    Path('data/raw').mkdir(parents=True, exist_ok=True)
    Path('data/metadata').mkdir(parents=True, exist_ok=True)
    
    # Gerar todas as tabelas
    users_df = generate_users(VOLUME['users'])
    hosts_df = generate_hosts(VOLUME['hosts'], users_df)
    properties_df = generate_properties(VOLUME['properties'], hosts_df)
    bookings_df = generate_bookings(VOLUME['bookings'], users_df, properties_df)
    payments_df = generate_payments(VOLUME['payments'], bookings_df)
    reviews_df = generate_reviews(VOLUME['reviews'], bookings_df)
    clickstream_df = generate_clickstream(VOLUME['clickstream'], users_df, properties_df)
    
    # Atualizar total gasto dos usuários
    user_totals = payments_df[payments_df['payment_status'] == 'paid'].groupby('user_id')['amount'].sum()
    users_df['total_spent'] = users_df['user_id'].map(user_totals).fillna(0)
    
    # Salvar como Parquet (melhor para engenharia de dados)
    print("\n💾 Salvando arquivos...")
    users_df.to_parquet('data/raw/users.parquet', index=False)
    hosts_df.to_parquet('data/raw/hosts.parquet', index=False)
    properties_df.to_parquet('data/raw/properties.parquet', index=False)
    bookings_df.to_parquet('data/raw/bookings.parquet', index=False)
    payments_df.to_parquet('data/raw/payments.parquet', index=False)
    reviews_df.to_parquet('data/raw/reviews.parquet', index=False)
    clickstream_df.to_parquet('data/raw/clickstream.parquet', index=False)
    
    # Salvar metadados
    metadata = {
        'generated_at': datetime.now().isoformat(),
        'seed': RANDOM_SEED,
        'volumes': VOLUME,
        'tables': {
            'users': list(users_df.columns),
            'hosts': list(hosts_df.columns),
            'properties': list(properties_df.columns),
            'bookings': list(bookings_df.columns),
            'payments': list(payments_df.columns),
            'reviews': list(reviews_df.columns),
            'clickstream': list(clickstream_df.columns)
        }
    }
    
    with open('data/metadata/schema.json', 'w') as f:
        json.dump(metadata, f, indent=2, default=str)
    
    # Relatório final
    print("\n" + "="*50)
    print("✅ DATASET GERADO COM SUCESSO!")
    print("="*50)
    print(f"📁 Localização: ./data/raw/")
    print(f"\n📊 Estatísticas:")
    print(f"   - Usuários: {len(users_df):,}")
    print(f"   - Anfitriões: {len(hosts_df):,}")
    print(f"   - Propriedades: {len(properties_df):,}")
    print(f"   - Reservas: {len(bookings_df):,}")
    print(f"   - Pagamentos: {len(payments_df):,}")
    print(f"   - Avaliações: {len(reviews_df):,}")
    print(f"   - Eventos: {len(clickstream_df):,}")
    print(f"\n💰 Total em pagamentos: R${payments_df['amount'].sum():,.2f}")
    print(f"⭐ Média de avaliações: {reviews_df['rating'].mean():.2f}")
    print("\n🎯 Próximo passo: Use este dataset no seu pipeline!")

if __name__ == "__main__":
    main()