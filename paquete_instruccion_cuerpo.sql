create or replace package body est_paquete_instruccion as
    procedure calcular_estadistica_instr(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy')) as
      error_enEjecutarProceso exception; -- excepcion para cuando quiero calcular una estad�stica que ya est� calculada
      v_proceso varchar2(30) := 'calcular_estadistica_instr';
    begin
        if EST_PAQ_EJECUTAR.ejecutar_proceso(f_desde => desde, f_hasta => hasta, CAMARA => N_CAMARA) = 1 then
            /* 1-> error, 0-> correcto */
            raise error_enEjecutarProceso;
        else
            /* En instrucci�n empezaremos sin expedientes en tr�mite */
            est_paquete.ingresados_y_reingresados(V_FECHADESDE => desde, V_FECHAHASTA => hasta, id_cam => N_CAMARA);
            --ELIMINAMOS TODO LO QUE NO SEA UN MOVIMIENTO DE INSTRUCCI�N
         --   eliminarAsignacionesAntA2013;
            dejarSoloInstruccion2;
            eliminarAnterioresA2008;
            eliminarFalsasAsignaciones;
            est_paquete.agrego_delito(id_cam => N_CAMARA);
            est_paquete.calcula_salidos(finPeriodo => hasta, id_cam => N_CAMARA);
        end if;
    exception
      when error_enEjecutarProceso then
          est_paquete.inserta_error(m_error => 'HUBO UN ERROR EJECUTANDO LA FUNCI�N "EJECUTAR_PROCESO"', nombre_proceso => v_proceso);
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end calcular_estadistica_instr;

    procedure eliminarAsignacionesAntA2013 is
        v_proceso varchar2(30) := 'eliminarAsignacionesAntA2013';
        v_inicio timestamp := systimestamp;
        v_fin timestamp;
    begin
      delete from est_total_a
      where extract(year from TA_FECHA) <= 2013
      and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;
      commit;
    exception
        when others then
            est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            rollback;
    end eliminarAsignacionesAntA2013;

    procedure eliminarFalsasAsignaciones is
        v_proceso varchar2(30) := 'eliminarFalsasAsignaciones';
        v_inicio timestamp := systimestamp;
        v_fin timestamp;
    begin
        delete from est_total_a a
        where  exists (select c.id_cambio_asignacion_exp
                       from cambio_asignacion_exp c
                       where  c.id_cambio_asignacion_exp = A.ta_idtablaorigen
                       and    fecha_asignacion = to_timestamp('01/03/2017 12:00:00,000000000 AM', 'DD/MM/YYYY HH12:MI:SS,FF AM')
                       and    comentarios = 'POR ACORDADA 1/2017 CSJN'
                       )
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;
        commit;
    exception
        when others then
            est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            rollback;
    end eliminarFalsasAsignaciones;

    procedure eliminarAnterioresA2008 is
        v_proceso varchar2(30) := 'eliminarAnterioresA2008';
        v_inicio timestamp := systimestamp;
        v_fin timestamp;
    begin
        /* ELIMINO AQUELLOS EXPEDIENTES QUE TIENEN A�O DE CAUSA ANTERIOR A 2008, YA QUE LO CONSIDERABA AS� EN INSTRUCCI�N CON SQLSERVER */
        delete from est_total_a
        where   ta_anio_exp < 2008
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;
        commit;
    exception
        when others then
            est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            rollback;
    end eliminarAnterioresA2008;


    procedure dejarSoloInstruccion2 is
        v_proceso varchar2(30) := 'dejarSoloInstruccion2';
        v_inicio timestamp := systimestamp;
        v_fin timestamp;
    begin
        /* ELIMINO TODO LO QUE NO SEA DE UNA OFICINA DE INSTRUCCION */
        delete from est_total_a ta
        where not exists (select id_oficina
                          from oficina o
                          where ta.ta_oficina = o.id_oficina
                          and   o.sigla_cedulas = 'CI')
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;
        commit;
    exception
        when others then
            est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            rollback;
    end dejarSoloInstruccion2;

    procedure dejarSoloInstruccion is
        v_proceso varchar2(30) := 'dejarSoloInstruccion';
        v_inicio timestamp := systimestamp;
        v_fin timestamp;
    begin
        /* ELIMINO LOS EXPEDIENTES QUE NO SON DE LAS OFICINAS DE INSTRUCCI�N HASTA EL A�O 2012 INCLUSIVE */
--        delete from est_total_a ta
--        where not exists (select id_oficina
--                          from oficina o
--                          where ta.ta_oficina = o.id_oficina
--                          and   o.sigla_cedulas = 'CI')
--        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion
--        and   extract(year from ta_fecha) < 2013;

        /* PARA 2008 EN ADELANTE, BORRAR� TODO LO QUE NO SEA INSTRUCCI�N, ROGATORIAS, MENORES O CORRECCIONAL */
        delete from est_total_a ta
        where not exists (select id_oficina
                          from oficina o
                          where ta.ta_oficina = o.id_oficina
                          and   o.sigla_cedulas in ('CI', 'CR','JNM', 'RO'))
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion
        and   extract(year from ta_fecha) >= 2008;

        /* ELIMINO AQUELLOS EXPEDIENTES QUE TIENEN A�O DE CAUSA ANTERIOR A 2008, YA QUE LO CONSIDERABA AS� EN INSTRUCCI�N CON SQLSERVER */
        delete from est_total_a
        where   ta_anio_exp < 2008
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;

        /* ELIMINO LAS FALSAS ASIGNACIONES HECHAS PARA QUE LOS JUZGADOS CORRECCCIONALES CON SU NUEVA DENOMINACI�N, PUEDAN TRABAJAR SUS ANTIGUAS CAUSAS */
        delete from est_total_a a
        where  exists (select c.id_cambio_asignacion_exp
                       from cambio_asignacion_exp c
                       where  c.id_cambio_asignacion_exp = A.ta_idtablaorigen
                       and    fecha_asignacion = to_timestamp('01/03/2017 12:00:00,000000000 AM', 'DD/MM/YYYY HH12:MI:SS,FF AM')
                       and    comentarios = 'POR ACORDADA 1/2017 CSJN'
                       )
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;
        commit;
        v_fin := systimestamp;
        est_paquete.inserta_duracion_procesos(camara => 9, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    exception
        when others then
            est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            rollback;
    end dejarSoloInstruccion;
end est_paquete_instruccion;