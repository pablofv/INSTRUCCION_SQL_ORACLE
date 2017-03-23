create or replace function est_paquete_federal.est_salidas_ultimo_registro(regAnt cursor_Salidos%rowtype, finDePeriodo date, fechaDelProceso date) return int is
  id_act int;
begin
  select id_actuacion_exp, fecha_actuacion, codigo into id_act, fechaSalida, codigoSalida
  from (select ROW_NUMBER() over(partition by id_expediente order by fecha_actuacion desc) numero_fila, id_actuacion_exp, fecha_actuacion, codigo
        from (select a.id_actuacion_exp, a.fecha_actuacion, ee.codigo_estado_expediente as codigo, a.id_expediente
              from actuacion_exp a join estado_expediente ee on a.id_estado_expediente = ee.id_estado_expediente and ee.CODIGO_ESTADO_EXPEDIENTE in ('196', 'ACU', 'ARC', 'CDM', 'DES', 'DEV', 'DFD', 'DIC', 'ETR', 'FII', 'HDT', 'REB', 'SCA', 'SOB', 'PRE')
              where a.id_expediente = idexp
              and   trunc(a.fecha_actuacion) between regant.ta_fecha and finDePeriodo
              and   est_busca_juzgado(a.id_oficina) = est_busca_juzgado(regAnt.ta_oficina) --est_busca_juzgado(oficina)
              union all
              select a.id_actuacion_exp, a.fecha_actuacion, ee.codigo_estado_expediente as codigo, a.id_expediente
              from expediente x join actuacion_exp a on x.id_expediente = a.id_expediente
              join estado_expediente ee on a.id_estado_expediente = ee.id_estado_expediente
              where idexp = x.ID_EXPEDIENTE_ORIGEN 
              and   ee.CODIGO_ESTADO_EXPEDIENTE in ('ETO')
              and   trunc(a.fecha_actuacion) between regant.ta_fecha and finDePeriodo
              and   est_busca_juzgado(a.id_oficina) = est_busca_juzgado(regAnt.ta_oficina) --est_busca_juzgado(oficina)
              union all
              select c.id_cambio_asignacion_exp, c.fecha_asignacion, c.codigo_tipo_cambio_asignacion as codigo, c.id_expediente
              from cambio_asignacion_exp c join expediente e on c.id_expediente = e.id_expediente
              where e.id_expediente_origen = idexp
              and   trunc(c.fecha_asignacion) between regant.ta_fecha and finDePeriodo
              and   est_busca_juzgado(c.id_oficina) = est_busca_juzgado(regAnt.ta_oficina) --est_busca_juzgado(oficina)
              and   c.CODIGO_TIPO_CAMBIO_ASIGNACION in ('ETO')
              ) cambio_actuacion
        ) r -- de resultado
  where numero_fila = 1;
  
  
  return id_act;
exception
    when no_data_found then
      return -2;
    when too_many_rows then
      return -3;
    when others then
      DBMS_OUTPUT.put_line(DBMS_UTILITY.format_error_stack);
      return -1;
end;