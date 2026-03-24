select 
  court_number,
  reservation_date,
  sum(duration_in_mins)
from {{ ref('fct_court_usage') }}
group by all
having sum(duration_in_mins) != 1440