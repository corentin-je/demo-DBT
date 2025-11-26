"""
Ecommerce DBT Pipeline DAG

DAG qui orchestre :
1. dbt run (transformer les données)
2. dbt test (valider la qualité)
3. dbt docs generate (documenter)

Schedule : Chaque jour à 6h du matin
Owner : data_engineering
"""

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

def dag_success_callback(context):
    """
    Fonction appelée si le DAG entier réussit
    """
    dag_id = context['dag'].dag_id
    execution_date = context['execution_date']
    
    logger.info(f"✅ DAG {dag_id} - SUCCESS at {execution_date}")
    print(f"\n{'='*80}")
    print(f"✅ DAG EXECUTION SUCCESSFUL")
    print(f"{'='*80}")
    print(f"DAG ID: {dag_id}")
    print(f"Execution Date: {execution_date}")
    print(f"Tasks Completed:")
    print(f"  ✅ dbt run - Data transformation")
    print(f"  ✅ dbt test - Quality checks")
    print(f"  ✅ dbt docs generate - Documentation")
    print(f"{'='*80}\n")

def dag_failure_callback(context):
    """
    Fonction appelée si le DAG échoue
    """
    dag_id = context['dag'].dag_id
    execution_date = context['execution_date']
    exception = context.get('exception', 'Unknown error')
    
    logger.error(f"❌ DAG {dag_id} - FAILED at {execution_date}: {exception}")
    print(f"\n{'='*80}")
    print(f"❌ DAG EXECUTION FAILED")
    print(f"{'='*80}")
    print(f"DAG ID: {dag_id}")
    print(f"Execution Date: {execution_date}")
    print(f"Error: {exception}")
    print(f"Check Airflow UI for more details: http://localhost:8080")
    print(f"{'='*80}\n")

def task_success_callback(context):
    task_id = context['task'].task_id
    logger.info(f"✅ Task {task_id} completed successfully")
    print(f"✅ Task {task_id} completed successfully")

def task_failure_callback(context):
    task_id = context['task'].task_id
    exception = context.get('exception', 'Unknown error')
    logger.error(f"❌ Task {task_id} failed: {exception}")
    print(f"❌ Task {task_id} failed: {exception}")

# Configuration par défaut
DEFAULT_ARGS = {
    'owner': 'data_engineering',
    'retries': 2,                           # Retry 2 fois en cas d'erreur
    'retry_delay': timedelta(minutes=5),   # Wait 5 min entre retries
    'start_date': days_ago(1),
    'email_on_failure': False,              # Pas d'email en dev
    'email_on_retry': False,
}

# Créer le DAG
dag = DAG(
    'ecommerce_dbt_pipeline',
    
    # Description pour l'UI
    description='Daily ecommerce DBT pipeline: run → test → docs',
    
    # Schedule : chaque jour à 6h
    schedule_interval='0 6 * * *',  # cron: 6h du matin
    # schedule_interval='@daily' est équivalent
    
    # Ne pas relancer les runs passés
    catchup=False,
    
    # Paramètres par défaut
    default_args=DEFAULT_ARGS,
    
    # Tags pour filtrer en UI
    tags=['ecommerce', 'dbt', 'daily'],
    on_success_callback=dag_success_callback,    # ← AJOUTER
    on_failure_callback=dag_failure_callback,    # ← AJOUTER
)

# ============================================================================
# TÂCHE 1 : dbt run (transformer les données)
# ============================================================================

dbt_run = BashOperator(
    task_id='dbt_run',
    
    # Chemin vers votre projet DBT
    bash_command=(
        'cd /Users/corentinjegu/Documents/DEV/DBT_expert/ecommerce_dbt_project '
        '&& dbt run --profiles-dir ~/.dbt'
    ),
    on_success_callback=task_success_callback,
    on_failure_callback=task_failure_callback,
    # Exécution en cas d'erreur
    trigger_rule='all_success',  # Ne s'exécute que si succès
    
    # Timeout
    execution_timeout=timedelta(minutes=30),
    
    dag=dag,
)

# ============================================================================
# TÂCHE 2 : dbt test (valider la qualité)
# ============================================================================

dbt_test = BashOperator(
    task_id='dbt_test',
    
    bash_command=(
        'cd /Users/corentinjegu/Documents/DEV/DBT_expert/ecommerce_dbt_project '
        '&& dbt test --profiles-dir ~/.dbt'
    ),
    on_success_callback=task_success_callback,
    on_failure_callback=task_failure_callback,
    # S'exécute seulement si dbt_run réussit
    trigger_rule='all_success',
    
    execution_timeout=timedelta(minutes=15),
    
    dag=dag,
)

# ============================================================================
# TÂCHE 3 : dbt docs generate (documenter)
# ============================================================================

dbt_docs = BashOperator(
    task_id='dbt_docs_generate',
    
    bash_command=(
        'cd /Users/corentinjegu/Documents/DEV/DBT_expert/ecommerce_dbt_project '
        '&& dbt docs generate --profiles-dir ~/.dbt'
    ),
    on_success_callback=task_success_callback,
    on_failure_callback=task_failure_callback,
    # S'exécute même si les tâches précédentes réussissent
    trigger_rule='all_success',
    
    execution_timeout=timedelta(minutes=10),
    
    dag=dag,
)

# ============================================================================
# DÉPENDANCES : Ordre d'exécution
# ============================================================================

# Syntaxe 1 : >> (recommandé)
dbt_run >> dbt_test >> dbt_docs

# Syntaxe 2 (équivalente) :
# dbt_run.set_downstream(dbt_test)
# dbt_test.set_downstream(dbt_docs)

# Résultat : dbt_run → dbt_test → dbt_docs
#
# Si dbt_run échoue : dbt_test et dbt_docs n'exécutent pas
# Si dbt_run réussit : dbt_test démarre
# Si dbt_test échoue : dbt_docs n'exécute pas
# Si tout réussit : dbt_docs génère la documentation
