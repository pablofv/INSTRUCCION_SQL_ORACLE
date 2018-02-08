
select row_number() over(partition by lex.id_expediente order by fecha_asignacion desc) n_fila, anio,semestre, anode, numdem, codins, 
      LEX.CODIGO_TIPO_CAMBIO_ASIGNACION, fecha, fecha_asignacion, juzins, 
      id_oficina, LEX.ID_EXPEDIENTE, LEX.ID_CAMBIO_ASIGNACION_EXP, cantidad_filas -- sqlsrv.*, lex.*
from est_asign_de_saldo_sql lex join est_saldo_sql sqlsrv on lex.id_expediente = sqlsrv.id_expediente
where lex.id_expediente  in (select s.id_expediente
                            from est_asign_de_saldo_sql c join est_saldo_sql s on c.id_expediente = s.id_expediente
                            where CANTIDAD_FILAS > 1
                            and   extract(year from c.fecha_asignacion) = substr(s.fecha, 1, 4)
                            and   extract(month from c.fecha_asignacion) = substr(s.fecha, 5, 2)
                            and   extract(day from c.fecha_asignacion) = substr(s.fecha, 7, 2) )
and     cantidad_filas > 1
--and    fecha_asignacion < to_timestamp('2013/01/01', 'yyyy/mm/dd')
and   extract(year from lex.fecha_asignacion) = substr(sqlsrv.fecha, 1, 4)
and   extract(month from lex.fecha_asignacion) = substr(sqlsrv.fecha, 5, 2)
and   extract(day from lex.fecha_asignacion) = substr(sqlsrv.fecha, 7, 2)
order by sqlsrv.id_expediente, fecha




;


select count(*)
from est_asign_de_saldo_sql
where cantidad_filas = 1
;
/* LOS QUE TIENEN UN REGISTRO EN CAMBIO EN LA MISMA OFICINA Y EN LA MISMA FECHA QUE HABÍA EN SQL, SI HAY MAS DE UNO, ELIJO EL MAS CERCANO AL INICIO DE 2013 */

--CREATE TABLE EST_SQLSRV_DEFINITIVO AS
insert into EST_SQLSRV_DEFINITIVO
select *
from (select row_number() over( partition by a.id_expediente order by fecha_asignacion desc) n_fila, a.*--, ANIO,ANODE, CODINS, FECHA, FECHAPROCESO, JUZINS, NUMDEM, OBJDEM, SEMESTRE, TABLA_DESDE, TIPO_DE_DATO
      from est_asign_de_saldo_sql a
      where exists (select 1
                    from est_saldo_sql s 
                    where a.id_expediente = s.id_expediente 
                    and a.id_oficina = s.id_oficina 
                    and   extract(year from a.fecha_asignacion) = substr(s.fecha, 1, 4)
                    and   extract(month from a.fecha_asignacion) = substr(s.fecha, 5, 2)
                    and   extract(day from a.fecha_asignacion) = substr(s.fecha, 7, 2) )
      and fecha_asignacion < to_timestamp('2013/01/01', 'yyyy/mm/dd')
      ) t
where n_fila = 1
and   not exists (select 1
                  from EST_SQLSRV_DEFINITIVO sqlsrv
                  where sqlsrv.id_expediente = t.id_expediente)
;

insert into EST_SQLSRV_DEFINITIVO
select *
from (select row_number() over( partition by a.id_expediente order by fecha_asignacion desc) n_fila, a.*--, ANIO,ANODE, CODINS, FECHA, FECHAPROCESO, JUZINS, NUMDEM, OBJDEM, SEMESTRE, TABLA_DESDE, TIPO_DE_DATO
      from est_asign_de_saldo_sql a
      where exists (select 1
                    from est_saldo_sql s 
                    where a.id_expediente = s.id_expediente 
                    and a.id_oficina = s.id_oficina )
      and fecha_asignacion < to_timestamp('2013/01/01', 'yyyy/mm/dd')
      ) t
where n_fila = 1
and   not exists (select 1
                  from EST_SQLSRV_DEFINITIVO sqlsrv
                  where sqlsrv.id_expediente = t.id_expediente)
;

insert into EST_SQLSRV_DEFINITIVO
select *
from (select row_number() over( partition by a.id_expediente order by fecha_asignacion desc) n_fila, a.*--, ANIO,ANODE, CODINS, FECHA, FECHAPROCESO, JUZINS, NUMDEM, OBJDEM, SEMESTRE, TABLA_DESDE, TIPO_DE_DATO
      from est_asign_de_saldo_sql a
      where not exists (select 1
                    from est_saldo_sql s 
                    where a.id_expediente = s.id_expediente 
                    and a.id_oficina = s.id_oficina )
      and fecha_asignacion < to_timestamp('2013/01/01', 'yyyy/mm/dd')
      ) t
where n_fila = 1
and   not exists (select 1
                  from EST_SQLSRV_DEFINITIVO sqlsrv
                  where sqlsrv.id_expediente = t.id_expediente)
;




SELECT count(*)
FROM EST_SQLSRV_DEFINITIVO d join est_saldo_sql s on d.id_expediente = s.id_expediente
where d.id_oficina = s.id_oficina

;





select (
select count(*)
from est_total_a t2
where t2.ta_oficina = t1.ta_oficina
and ta_numero_estadistica = 10
and extract(year from t2.ta_fecha) < 2013
and (ta_finalizo = 1 
  or (ta_finalizo = 0 and extract(year from ta_fecha_de_finalizacion) >= 2013 ) )
)
from est_total_a t1
where ((ta_numero_estadistica = 10 and extract(year from ta_fecha) = 2013) -- TODOS LOS INGRESOS Y REINGRESOS
            or (ta_numero_estadistica = 10 and extract(year from ta_fecha) < 2013 and ta_camara = 9 and -- TODAS ASIGNACIONES DE LA ESTADÍSTICA TRABAJADA
          ((ta_finalizo = 1) or -- ESTÁN EN TRÁMITE
           (ta_finalizo = 0 and extract(year from ta_fecha_de_finalizacion) >= 2013) -- FINALIZARON LUEGO DEL COMIENZO DEL AÑO 2016
          )
                ))
and   t1.ta_oficina between 1193 and 1289

order by t1.ta_oficina



;



select count(*)
from est_total_a t1
where 
             ta_numero_estadistica = 10 and extract(year from ta_fecha) < 2013 and ta_camara = 9 and -- TODAS ASIGNACIONES DE LA ESTADÍSTICA TRABAJADA
          ((ta_finalizo = 1) or -- ESTÁN EN TRÁMITE
           (ta_finalizo = 0 and extract(year from ta_fecha_de_finalizacion) >= 2013) -- FINALIZARON LUEGO DEL COMIENZO DEL AÑO 2016
          )
               
and   t1.ta_oficina between 1193 and 1289;


select *
from est_total_a
where TA_NUMERO_ESTADISTICA = 10
and   TA_TIPO_DE_DATO = 0
;