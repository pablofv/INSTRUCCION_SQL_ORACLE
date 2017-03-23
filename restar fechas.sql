select (cast((select fecha from est_log l2 where l1.numfila = l2.numfila + 1) as date) - cast(fecha as date)) * 24*60*60
from est_log l1
where numfila between 10000 and 12000
and   numfila in (10020, 10019, 10021)
order by numfila
;