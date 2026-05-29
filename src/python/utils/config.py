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
    'users': 10000,
    'hosts': 2000,
    'properties': 5000,
    'bookings': 50000,
    'payments': 48000,
    'reviews': 30000
}

# Configurações de logging
LOGGING_CONFIG = {
    'level': 'INFO',
    'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    'file': 'logs/etl_pipeline.log'
}

# Configurações de batch
BATCH_CONFIG = {
    'chunk_size': 1000,
    'max_retries': 3,
    'retry_delay': 5  # segundos
}