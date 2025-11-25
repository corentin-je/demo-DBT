-- test des volumes
select *
from {{ ref('audit_data_quality') }}
where quality_status IN ('ALERT_LOW', 'ALERT_HIGH')