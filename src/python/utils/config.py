"""
Configurações do projeto
"""

import os
from dotenv import load_dotenv

# Carrega variáveis de ambiente
load_dotenv()

# Configurações do SQL Server
SQL_SERVER_CONFIG = {
    'server': os.getenv('SQL_SERVER', 'localhost'),
    'database': os.getenv('SQL_DATABASE', 'ETL'),
    'username': os.getenv('SQL_USERNAME'),
    'password': os.getenv('SQL_PASSWORD'),
    'driver': os.getenv('SQL_DRIVER', '{ODBC Driver 17 for SQL Server}'),
    'trusted_connection': os.getenv('SQL_TRUSTED_CONNECTION', 'yes')
}

# Configurações de volume de dados
DATA_VOLUME = {
    'users': int(os.getenv('USERS_COUNT', 10000)),
    'hosts': int(os.getenv('HOSTS_COUNT', 2000)),
    'properties': int(os.getenv('PROPERTIES_COUNT', 5000)),
    'bookings': int(os.getenv('BOOKINGS_COUNT', 50000)),
    'payments': int(os.getenv('PAYMENTS_COUNT', 48000)),
    'reviews': int(os.getenv('REVIEWS_COUNT', 30000))
}

# Configurações de logging
LOGGING_CONFIG = {
    'level': os.getenv('LOG_LEVEL', 'INFO'),
    'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    'file': os.getenv('LOG_FILE', 'logs/etl_pipeline.log')
}

# Configurações de batch
BATCH_CONFIG = {
    'chunk_size': int(os.getenv('CHUNK_SIZE', 1000)),
    'max_retries': int(os.getenv('MAX_RETRIES', 3)),
    'retry_delay': int(os.getenv('RETRY_DELAY', 5))
}