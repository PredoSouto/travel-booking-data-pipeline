"""
Módulo para carregar dados gerados no SQL Server
Autor: Pedro Guilherme Souto de Oliveira
Data: 2026
"""

import pyodbc
import pandas as pd
from sqlalchemy import create_engine
import logging
from datetime import datetime
from typing import Dict, List
import os

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuração de conexão
CONNECTION_STRING = (
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=localhost;"
    "Database=ETL;"
    "Trusted_Connection=yes;"
)

# Ou com usuário/senha:
# CONNECTION_STRING = (
#     "Driver={ODBC Driver 17 for SQL Server};"
#     "Server=localhost;"
#     "Database=ETL;"
#     "UID=seu_usuario;"
#     "PWD=sua_senha;"
# )


class SQLServerLoader:
    """Classe para carregar dados no SQL Server"""
    
    def __init__(self, connection_string: str = CONNECTION_STRING):
        self.connection_string = connection_string
        self.engine = None
        self.conn = None
        
    def connect(self):
        """Estabelece conexão com o SQL Server"""
        try:
            self.engine = create_engine(f"mssql+pyodbc:///?odbc_connect={self.connection_string}")
            self.conn = pyodbc.connect(self.connection_string)
            logger.info("✅ Conexão com SQL Server estabelecida")
        except Exception as e:
            logger.error(f"❌ Erro ao conectar: {e}")
            raise
    
    def disconnect(self):
        """Fecha a conexão"""
        if self.conn:
            self.conn.close()
        if self.engine:
            self.engine.dispose()
        logger.info("🔌 Conexão fechada")
    
    def truncate_staging_tables(self, tables: List[str]):
        """Limpa tabelas staging antes do carregamento"""
        try:
            cursor = self.conn.cursor()
            for table in tables:
                cursor.execute(f"TRUNCATE TABLE staging.{table}")
                logger.info(f"🗑️  Tabela staging.{table} truncada")
            self.conn.commit()
            cursor.close()
        except Exception as e:
            logger.error(f"❌ Erro ao truncar tabelas: {e}")
            raise
    
    def load_dataframe(self, df: pd.DataFrame, table_name: str, schema: str = 'staging'):
        """Carrega um DataFrame para uma tabela SQL"""
        try:
            # Converte tipos de dados para compatibilidade
            for col in df.columns:
                if df[col].dtype == 'object':
                    df[col] = df[col].astype(str)
            
            rows_affected = df.to_sql(
                name=table_name,
                con=self.engine,
                schema=schema,
                if_exists='append',
                index=False,
                method='multi',
                chunksize=1000
            )
            logger.info(f"✅ {rows_affected} registros inseridos em {schema}.{table_name}")
            return rows_affected
        except Exception as e:
            logger.error(f"❌ Erro ao carregar {schema}.{table_name}: {e}")
            raise
    
    def execute_stored_procedure(self, procedure_name: str, dry_run: bool = False):
        """Executa uma stored procedure"""
        try:
            cursor = self.conn.cursor()
            dry_run_value = 1 if dry_run else 0
            cursor.execute(f"EXEC dwh.{procedure_name} @dry_run = ?", dry_run_value)
            
            if dry_run:
                rows = cursor.fetchall()
                if rows:
                    logger.info(f"📋 Preview de {procedure_name}:")
                    for row in rows[:5]:  # Mostra apenas primeiros 5
                        logger.info(f"   {row}")
            
            self.conn.commit()
            cursor.close()
            logger.info(f"✅ Stored procedure {procedure_name} executada")
        except Exception as e:
            logger.error(f"❌ Erro ao executar {procedure_name}: {e}")
            raise


def main():
    """Função principal - orquestra o carregamento"""
    
    loader = SQLServerLoader()
    
    try:
        # 1. Conectar ao banco
        loader.connect()
        
        # 2. Lista de tabelas staging
        staging_tables = ['tb_user', 'tb_property', 'tb_booking', 'tb_payment', 'tb_host']
        
        # 3. Limpar tabelas staging (opcional - cuidado em produção)
        # loader.truncate_staging_tables(staging_tables)
        
        # 4. Carregar dados (assumindo que seus DataFrames existem)
        # Substitua pelos nomes dos seus DataFrames gerados
        
        # Exemplo:
        # loader.load_dataframe(df_users, 'tb_user')
        # loader.load_dataframe(df_properties, 'tb_property')
        # loader.load_dataframe(df_bookings, 'tb_booking')
        # loader.load_dataframe(df_payments, 'tb_payment')
        # loader.load_dataframe(df_hosts, 'tb_host')
        
        # 5. Executar stored procedures (dry-run primeiro)
        logger.info("\n📋 Executando dry-run...")
        loader.execute_stored_procedure('sp_merge_dim_users', dry_run=True)
        loader.execute_stored_procedure('sp_merge_dim_hosts', dry_run=True)
        loader.execute_stored_procedure('sp_merge_dim_properties', dry_run=True)
        
        # 6. Confirmar para executar em produção
        resposta = input("\n⚠️  Executar MERGE em produção? (s/N): ")
        if resposta.lower() == 's':
            logger.info("\n🚀 Executando MERGE em produção...")
            loader.execute_stored_procedure('sp_merge_dim_users', dry_run=False)
            loader.execute_stored_procedure('sp_merge_dim_hosts', dry_run=False)
            loader.execute_stored_procedure('sp_merge_dim_properties', dry_run=False)
            logger.info("✅ Todos os MERGEs executados com sucesso!")
        else:
            logger.info("❌ Execução cancelada pelo usuário")
        
    except Exception as e:
        logger.error(f"❌ Erro no processo: {e}")
    finally:
        loader.disconnect()


if __name__ == "__main__":
    main()