"""
Módulo para carregar dados gerados no SQL Server
Autor: Pedro Guilherme Souto de Oliveira    
Data: 2026
"""

import pyodbc
import pandas as pd
from sqlalchemy import create_engine
import logging
from typing import Dict, List, Optional, Any
import os
import sys
import uuid

# Configuração de logging ANTES de importar config
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Importa config usando caminho relativo correto
try:
    from utils.config import SQL_SERVER_CONFIG, BATCH_CONFIG, LOGGING_CONFIG
except ImportError:
    # Fallback para quando executado de diretórios diferentes
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from utils.config import SQL_SERVER_CONFIG, BATCH_CONFIG, LOGGING_CONFIG


class SQLServerLoader:
    """Classe para carregar dados no SQL Server"""
    
    def __init__(self, config: Optional[Dict] = None):
        self.config = config or SQL_SERVER_CONFIG
        self.connection_string = self._build_connection_string()
        self.engine = None
        self.conn = None
        
    def _build_connection_string(self) -> str:
        """Constrói a string de conexão"""
        if self.config.get('trusted_connection', '').lower() in ['yes', 'true', '1']:
            return (
                f"Driver={self.config['driver']};"
                f"Server={self.config['server']};"
                f"Database={self.config['database']};"
                f"Trusted_Connection=yes;"
            )
        else:
            return (
                f"Driver={self.config['driver']};"
                f"Server={self.config['server']};"
                f"Database={self.config['database']};"
                f"UID={self.config['username']};"
                f"PWD={self.config['password']};"
            )
    
    def connect(self) -> bool:
        """Estabelece conexão com o SQL Server"""
        try:
            # Conexão para SQLAlchemy (pandas)
            if self.config.get('trusted_connection', '').lower() in ['yes', 'true', '1']:
                conn_str = f"mssql+pyodbc://@{self.config['server']}/{self.config['database']}?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
            else:
                conn_str = f"mssql+pyodbc://{self.config['username']}:{self.config['password']}@{self.config['server']}/{self.config['database']}?driver=ODBC+Driver+17+for+SQL+Server"
            
            self.engine = create_engine(conn_str)
            self.conn = pyodbc.connect(self.connection_string)
            
            logger.info(f"✅ Conexão com SQL Server estabelecida - Database: {self.config['database']}")
            return True
        except Exception as e:
            logger.error(f"❌ Erro ao conectar: {e}")
            return False
    
    def disconnect(self):
        """Fecha a conexão"""
        if self.conn:
            self.conn.close()
        if self.engine:
            self.engine.dispose()
        logger.info("🔌 Conexão fechada")
    
    def truncate_staging_tables(self, tables: List[str]):
        """Limpa tabelas staging antes do carregamento"""
        cursor = self.conn.cursor()
        for table in tables:
            try:
                cursor.execute(f"TRUNCATE TABLE staging.{table}")
                logger.info(f"🗑️  Tabela staging.{table} truncada")
            except Exception as e:
                logger.warning(f"⚠️ TRUNCATE falhou para staging.{table}: {e}")
                cursor.execute(f"DELETE FROM staging.{table}")
                logger.info(f"🗑️  Tabela staging.{table} limpa com DELETE")
        self.conn.commit()
        cursor.close()
    
    def _convert_to_guid(self, value) -> str:
        """Converte um valor para GUID válido do SQL Server"""
        if pd.isna(value) or value is None:
            return str(uuid.uuid4())
        
        value_str = str(value)
        
        # Se já é um GUID válido (formato: 8-4-4-4-12)
        if len(value_str) == 36 and value_str.count('-') == 4:
            try:
                uuid.UUID(value_str)
                return value_str
            except (ValueError, TypeError):
                pass
        
        # Qualquer outro formato gera novo GUID
        return str(uuid.uuid4())
    
    def _clean_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Limpa o DataFrame para evitar problemas com NULLs
        - NaN (float) -> None (NULL no SQL)
        - NaT (datetime) -> None
        - "None" string -> None
        - "nan" string -> None
        - Strings de ID ('usr_xxx') -> GUIDs válidos
        """
        df = df.copy()
        
        # Colunas que devem ser UNIQUEIDENTIFIER
        guid_columns = ['user_uuid', 'host_uuid', 'property_uuid', 'booking_uuid', 'transaction_id']
        
        for col in df.columns:
            # 1. Tratamento de GUIDs
            if col in guid_columns:
                df[col] = df[col].apply(
                    lambda x: self._convert_to_guid(x) if pd.notna(x) else str(uuid.uuid4())
                )
            
            # 2. Converte NaN/NaT para None
            elif df[col].dtype == 'float64':
                df[col] = df[col].where(pd.notna(df[col]), None)
            
            elif df[col].dtype == 'datetime64[ns]':
                df[col] = df[col].where(pd.notna(df[col]), None)
            
            elif df[col].dtype == 'object':
                # Para strings: substitui "None" e "nan" por None
                df[col] = df[col].apply(
                    lambda x: None if pd.isna(x) or str(x).lower() in ('none', 'nan', 'null') else x
                )
        
        return df
    
    def load_dataframe(self, df: pd.DataFrame, table_name: str, schema: str = 'staging', 
                       if_exists: str = 'append', chunk_size: int = None) -> int:
        """Carrega um DataFrame para uma tabela SQL"""
        if df is None or df.empty:
            logger.warning(f"⚠️ DataFrame vazio para {schema}.{table_name}")
            return 0
        
        try:
            # Limpa o DataFrame ANTES de qualquer conversão
            df_clean = self._clean_dataframe(df)
            
            chunk_size = chunk_size or BATCH_CONFIG.get('chunk_size', 500)
            
            # Usa to_sql padrão (sem multi-insert) para evitar problemas
            rows_affected = 0
            total_rows = len(df_clean)
            
            for start in range(0, total_rows, chunk_size):
                chunk = df_clean.iloc[start:start + chunk_size]
                rows = chunk.to_sql(
                    name=table_name,
                    con=self.engine,
                    schema=schema,
                    if_exists=if_exists if start == 0 else 'append',
                    index=False,
                    method=None
                )
                rows_affected += rows
                logger.debug(f"   Lote {start//chunk_size + 1}: {rows} registros")
            
            logger.info(f"✅ {rows_affected:,} registros inseridos em {schema}.{table_name}")
            return rows_affected
            
        except Exception as e:
            logger.error(f"❌ Erro ao carregar {schema}.{table_name}: {e}")
            logger.error(f"   DataFrame shape: {df_clean.shape if 'df_clean' in locals() else df.shape}")
            logger.error(f"   DataFrame columns: {df_clean.columns.tolist() if 'df_clean' in locals() else df.columns.tolist()}")
            raise
    
    def execute_stored_procedure(self, procedure_name: str, dry_run: bool = False, 
                                  parameters: Dict[str, Any] = None) -> Optional[List]:
        """
        Executa uma stored procedure
        
        Args:
            procedure_name: Nome da procedure
            dry_run: Se True, apenas preview
            parameters: Dicionário com parâmetros nomeados (ex: {'user_id': 123})
        """
        try:
            cursor = self.conn.cursor()
            
            # Monta a chamada da procedure
            if dry_run:
                sql = f"EXEC dwh.{procedure_name} @dry_run = 1"
            else:
                sql = f"EXEC dwh.{procedure_name} @dry_run = 0"
            
            # Adiciona parâmetros adicionais de forma correta
            param_values = []
            if parameters:
                for key, value in parameters.items():
                    sql += f", @{key} = ?"
                    param_values.append(value)
            
            # Executa com todos os parâmetros de uma vez
            if param_values:
                cursor.execute(sql, param_values)
            else:
                cursor.execute(sql)
            
            # Recupera resultados se houver
            results = None
            if dry_run:
                results = cursor.fetchall()
                if results:
                    logger.info(f"📋 Preview de {procedure_name}: {len(results)} registros")
                    for i, row in enumerate(results[:5]):
                        logger.info(f"   {i+1}. {row}")
            
            self.conn.commit()
            cursor.close()
            logger.info(f"✅ Stored procedure {procedure_name} executada (dry_run={dry_run})")
            return results
            
        except Exception as e:
            logger.error(f"❌ Erro ao executar {procedure_name}: {e}")
            raise