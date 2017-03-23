create or replace package body est_paquete_instruccion as

    procedure calcular_estadistica(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp, recalculo varchar2 default 'N') as
      error_yaFueCalculado exception; -- excepcion para cuando quiero calcular algo que ya está calculado
      hay_registros_anteriores int;
      v_proceso varchar2(30) := 'calcular_estadistica';
      hayEstadisticaAnterior int;
    begin
        select nvl(count(*), 0) into hay_registros_anteriores from est_fecha_de_procesos WHERE CAMARA = N_CAMARA;

        if upper(recalculo) = 'S' or (upper(recalculo) = 'N' and hay_registros_anteriores = 0)then
            insert into est_fecha_de_procesos(fecha, camara) values (sysdate, N_CAMARA);
        end if;

        select max(n_ejecucion) into est_paquete.v_numero_de_ejecucion from est_fecha_de_procesos;

        select nvl(count(*), 0) into hayEstadisticaAnterior
        from est_total_a
        where ta_fecha between desde and hasta
        and   ta_camara = N_CAMARA
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;

        if hayEstadisticaAnterior > 0 then
            raise error_yaFueCalculado;
        else
            /* En instrucción empezaremos sin expedientes en trámite */
            est_paquete.ingresados(V_FECHADESDE => desde, V_FECHAHASTA => hasta, id_cam => N_CAMARA);
            est_paquete.reingresados(v_fechaDesde => desde, v_fechahasta => hasta, id_cam => N_CAMARA);
            --ELIMINAMOS TODO LO QUE NO SEA UN MOVIMIENTO DE INSTRUCCIÓN
        --    reingresadosDeActuacion(f_desde => desde, f_hasta => hasta);
            dejarSoloInstruccion;
            --reingresadosDeActuacion(f_desde => desde, f_hasta => hasta);
            est_paquete.calcula_salidos(finPeriodo => hasta, id_cam => N_CAMARA);
        end if;

    exception
      when error_yaFueCalculado then
          est_paquete.inserta_error(m_error => 'ESTADÍSTICA YA CALCULADA', nombre_proceso => v_proceso);
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end calcular_estadistica;

    procedure reingresadosDeActuacion(f_desde in timestamp, f_hasta in timestamp) is
        v_proceso varchar2(30) := 'reingresadosDeActuacion';
    begin
        INSERT INTO LEX100MAESTRAS.EST_TOTAL_A(TA_IDEXP, TA_RN, TA_ANIO_EXP, TA_NUMERO_EXP, TA_OFICINA, TA_FECHA, TA_CODIGO, TA_OBJETO,
                                               TA_FINALIZO, -- 0 -> fuera de trámite 1 -> en trámite
                                               TA_IDCAMBIO, TA_TABLAORIGEN,
                                               TA_TIPO_DE_DATO, -- 0 -> existente 1 -> ingresado 2 -> reingresados
                                               TA_FECHA_PROCESO, TA_NUMERO_DE_EJECUCION, TA_CAMARA)
        select a.id_expediente, (select nvl(max(ta_rn), 1) 
                                 from est_total_a ta
                                 where    ta.ta_idexp = a.id_expediente
                                 and      ta_camara = N_CAMARA
                                 and      TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion) +
                                 row_number() over(partition by a.id_expediente, a.id_oficina order by a.fecha_actuacion) rn, e.anio_expediente, e.numero_expediente, a.id_oficina, a.FECHA_ACTUACION, ee.codigo_estado_expediente, e.id_objeto_juicio,
                1,
                a.id_actuacion_exp, 'ACTUACION_EXP',
                2,
                systimestamp, est_paquete.v_numero_de_ejecucion, N_CAMARA
        from actuacion_exp a join expediente e on a.id_expediente = e.id_expediente
                             join estado_expediente ee on a.id_estado_expediente = ee.id_estado_expediente
        where ee.codigo_estado_expediente = 'REI'
        and   trunc(a.fecha_actuacion) between f_desde and f_hasta
        and   exists(select 1
                     from est_total_a ta
                     where  ta.ta_idexp = a.id_expediente
                     and    ta_camara = N_CAMARA
                     and    TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion);
    exception
        when others then
            est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end reingresadosDeActuacion;

    procedure dejarSoloInstruccion is
        v_proceso varchar2(30) := 'dejarSoloInstruccion';
    begin
        /* ELIMINO LOS EXPEDIENTES QUE NO SON DE LAS OFICINAS DE INSTRUCCIÓN */
        delete from est_total_a ta
        where not exists (select id_oficina
                          from oficina o
                          where ta.ta_oficina = o.id_oficina
                          and   o.sigla_cedulas = 'CI');

        delete from est_total_a
        where   ta_anio_exp < 2008;
        commit;
    exception
        when others then
            est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            rollback;
    end dejarSoloInstruccion;
end est_paquete_instruccion;