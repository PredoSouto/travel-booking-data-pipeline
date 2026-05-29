# 🏨 Travel Booking Data Pipeline

[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://www.python.org/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-red.svg)](https://www.microsoft.com/sql-server)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Em%20Desenvolvimento-yellow)]()

> **Pipeline de engenharia de dados para plataforma de reservas de viagens.**
>
> Implementação completa de um Data Warehouse com modelo Star Schema, SCD Tipo 2, e pipeline ETL automatizado.

---

## 📋 Status do Projeto

| Fase | Status | Conclusão |
|------|--------|-----------|
| Modelagem dimensional | ✅ Concluído | 100% |
| Banco de dados SQL Server | ✅ Concluído | 100% |
| Stored procedures SCD Tipo 2 | ✅ Concluído | 100% |
| Gerador de dados fake | ✅ Concluído | 100% |
| Integração Python → SQL Server | ✅ Concluído | 100% |
| Airflow DAGs | 🔄 Em andamento | 0% |
| Testes automatizados | ⏳ Pendente | 0% |
| CI/CD com GitHub Actions | ⏳ Pendente | 0% |
| Documentação completa | 🔄 Em andamento | 60% |

---

## 🎯 Objetivo

Construir um **Data Warehouse completo** para análise de negócios de uma plataforma de reservas de viagens (similar a Airbnb/Booking), demonstrando habilidades em:

- ✅ Modelagem dimensional (Star Schema)
- ✅ SCD Tipo 2 (Slowly Changing Dimensions)
- ✅ ETL com Python e SQL Server
- ✅ Geração de dados sintéticos realistas
- ✅ Boas práticas de engenharia de dados

---

## 🏗️ Arquitetura

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Python      │     │   SQL Server    │     │      Data       │
│    Gerador      │────▶│    Staging      │────▶│    Warehouse    │
│    (Faker)      │     │   (Tabelas)     │     │  (Star Schema)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                │                        │
                                ▼                        ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │    Airflow      │     │   Power BI /    │
                        │    (Futuro)     │     │   Analytics     │
                        └─────────────────┘     └─────────────────┘
```

### Modelo Star Schema

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  dim_users   │     │  dim_hosts   │     │dim_properties│
│ (SCD Tipo 2) │     │ (SCD Tipo 2) │     │ (SCD Tipo 2) │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            ▼
                   ┌────────────────┐
                   │ fact_bookings  │
                   │    (Fato)      │
                   └───────┬────────┘
                           │
                           ▼
                   ┌────────────────┐
                   │ fact_payments  │
                   │    (Fato)      │
                   └────────────────┘

┌──────────────┐
│  dim_dates   │──────┘
│ (Calendário) │
└──────────────┘
```

---

## 🛠️ Stack Tecnológico

| Categoria | Tecnologias |
|-----------|-------------|
| **Banco de Dados** | Microsoft SQL Server 2022 |
| **Linguagem** | Python 3.10+, T-SQL |
| **Geração de Dados** | Faker, Pandas, NumPy |
| **Orquestração** | Apache Airflow (planejado) |
| **Containerização** | Docker, Docker Compose |
| **Controle de Versão** | Git, GitHub |

---

## 📁 Estrutura do Projeto

```
travel-booking-data-pipeline/
│
├── src/
│   ├── sql/                          # Scripts SQL (12 arquivos)
│   │   ├── 01_create_database_schemas.sql
│   │   ├── 02_control_etl.sql
│   │   ├── 03_create_table_users.sql
│   │   ├── 04_create_table_date.sql
│   │   ├── 05_create_table_dim_properties.sql
│   │   ├── 06_create_table_booking.sql
│   │   ├── 07_create_table_hosts.sql
│   │   ├── 08_create_table_payments.sql
│   │   ├── 09_create_table_reviews.sql
│   │   ├── 10_create_staging_tables.sql
│   │   ├── 11_populate_dim_dates.sql
│   │   └── 12_create_procedures_merge.sql
│   │
│   └── python/
│       ├── generators/
│       │   └── main.py               # Gerador de dados + loader
│       ├── loaders/
│       │   └── load_to_sqlserver.py  # Conexão e carga
│       └── utils/
│           └── config.py             # Configurações
│
├── data/                             # Dados (ignorado pelo Git)
│   ├── raw/                          # Arquivos Parquet
│   └── metadata/                     # Schema JSON
│
├── docs/                             # Documentação
├── tests/                            # Testes (futuro)
├── .env.example                      # Exemplo de configuração
├── .gitignore
├── requirements.txt
└── README.md
```

---

## 🚀 Como Executar

### Pré-requisitos

- Python 3.10+
- SQL Server 2022 (Developer Edition ou LocalDB)
- ODBC Driver 17 for SQL Server

### 1. Configuração do Ambiente

```bash
# Clone o repositório
git clone https://github.com/PredoSouto/travel-booking-data-pipeline
cd travel-booking-data-pipeline

# Crie um ambiente virtual
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Instale as dependências
pip install -r requirements.txt

# Configure as variáveis de ambiente
cp .env.example .env
# Edite o arquivo .env com suas credenciais do SQL Server
```

### 2. Criar o Banco de Dados

Execute os scripts SQL na seguinte ordem (no SSMS ou Azure Data Studio):

```
1.  01_create_database_schemas.sql
2.  02_control_etl.sql
3.  03_create_table_users.sql
4.  04_create_table_date.sql
5.  05_create_table_dim_properties.sql
6.  06_create_table_booking.sql
7.  07_create_table_hosts.sql
8.  08_create_table_payments.sql
9.  09_create_table_reviews.sql
10. 10_create_staging_tables.sql
11. 11_populate_dim_dates.sql
12. 12_create_procedures_merge.sql
```

### 3. Gerar e Carregar os Dados

```bash
# Apenas gerar arquivos Parquet
python src/python/generators/main.py

# Gerar e carregar para o SQL Server
python src/python/generators/main.py --load-sql

# Pipeline completo (gerar + carregar + executar merges)
python src/python/generators/main.py --load-sql --merge --truncate
```

### 4. Verificar os Dados

```sql
-- Verificar dimensões
SELECT * FROM dwh.dim_users WHERE is_current = 1;
SELECT * FROM dwh.dim_properties WHERE is_current = 1;

-- Verificar fatos
SELECT COUNT(*) FROM dwh.fact_bookings;
SELECT COUNT(*) FROM dwh.fact_payments;

-- Verificar histórico de SCD
EXEC dwh.sp_get_user_history @user_id = 1;

-- Verificar logs ETL
EXEC dwh.sp_get_etl_summary @days_back = 7;
```

---

## 📊 Exemplos de Consultas Analíticas

### Receita diária (YTD)

```sql
SELECT
    d.full_date,
    SUM(fb.total_price)                                                    AS daily_revenue,
    SUM(SUM(fb.total_price)) OVER (ORDER BY d.full_date)                   AS revenue_ytd
FROM dwh.fact_bookings fb
JOIN dwh.dim_dates d ON fb.checkin_date_sk = d.date_sk
WHERE fb.booking_status = 'completed'
GROUP BY d.full_date
ORDER BY d.full_date;
```

### Top 10 Propriedades por Receita

```sql
SELECT TOP 10
    p.title,
    p.city,
    COUNT(DISTINCT fb.booking_id) AS total_bookings,
    SUM(fb.total_price)           AS total_revenue
FROM dwh.fact_bookings fb
JOIN dwh.dim_properties p ON fb.property_sk = p.property_sk
WHERE p.is_current = 1
  AND fb.booking_status = 'completed'
GROUP BY p.title, p.city
ORDER BY total_revenue DESC;
```

### Taxa de Cancelamento por Tipo de Propriedade

```sql
SELECT
    p.property_type,
    COUNT(*)                                                                                    AS total_bookings,
    SUM(CASE WHEN fb.booking_status = 'cancelled' THEN 1 ELSE 0 END)                          AS cancelled_bookings,
    CAST(
        SUM(CASE WHEN fb.booking_status = 'cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    )                                                                                           AS cancellation_rate
FROM dwh.fact_bookings fb
JOIN dwh.dim_properties p ON fb.property_sk = p.property_sk
WHERE p.is_current = 1
GROUP BY p.property_type
ORDER BY cancellation_rate DESC;
```

---

## 📈 Volumes de Dados Gerados

| Tabela | Registros | Tamanho (aprox.) |
|--------|-----------|------------------|
| users | 10.000 | ~2 MB |
| hosts | 2.000 | ~0,5 MB |
| properties | 5.000 | ~3 MB |
| bookings | 50.000 | ~8 MB |
| payments | 48.000 | ~6 MB |
| **Total** | **115.000+** | **~20 MB** |

---

## ✅ O que já funciona

- ✅ Criação completa do banco de dados ETL
- ✅ Modelo Star Schema com 5 dimensões e 2 fatos
- ✅ SCD Tipo 2 implementado via stored procedures
- ✅ Geração de dados sintéticos realistas (115k+ registros)
- ✅ Carga automática para SQL Server
- ✅ Tabela de calendário (`dim_dates`) populada (2020–2030)
- ✅ Logging e auditoria de processos ETL
- ✅ Histórico de alterações por usuário

---

## 🔜 Próximos Passos

- [ ] Implementar DAGs do Apache Airflow
- [ ] Adicionar testes unitários e de integração
- [ ] Configurar GitHub Actions (CI/CD)
- [ ] Criar dashboard no Power BI ou Superset
- [ ] Adicionar validações de qualidade de dados com Great Expectations
- [ ] Implementar particionamento de tabelas fato
- [ ] Documentar API de acesso aos dados

---

## 📝 Documentação Pendente

| Documento | Status | Prioridade |
|-----------|--------|------------|
| README.md (este) | 🔄 Em andamento | Alta |
| README.pt-BR.md | ⏳ Pendente | Média |
| Diagrama de arquitetura | ⏳ Pendente | Alta |
| Guia de contribuição | ⏳ Pendente | Baixa |
| Documentação das stored procedures | ⏳ Pendente | Média |

---

## 🤝 Contribuição

Este é um projeto de portfólio, mas contribuições são bem-vindas!

1. Fork o projeto
2. Crie sua branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

---

## 📄 Licença

Distribuído sob a licença MIT. Veja [LICENSE](LICENSE) para mais informações.

---

## 📬 Contato

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue)](https://www.linkedin.com/in/pedro-guilherme-souto-de-oliveira-14a196165/)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black)](https://github.com/PredoSouto)

---

*Built with ❤️ for the Data Engineering community — Última atualização: Maio/2026*