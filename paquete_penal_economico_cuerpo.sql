create or replace package body est_paquete_penal_economico as
    procedure calcular_estadistica_p_econ(desde in timestamp, hasta in timestamp) is
      error_enEjecutarProceso exception; -- excepcion para cuando quiero calcular algo que ya está calculado
      v_proceso varchar2(30) := 'calcular_estadistica_p_econ';
    begin
        if EST_PAQ_EJECUTAR.ejecutar_proceso(f_desde => desde, f_hasta => hasta, CAMARA => N_CAMARA) = 1 then
            /* 1-> error, 0-> correcto */
            raise error_enEjecutarProceso;
        else
            est_paquete.generar_est_cambio_asignacion(v_fechaDesde => desde, v_fechaHasta => hasta, id_cam => N_CAMARA);
            est_paquete.ingresados_y_reingresados(V_FECHADESDE => desde, V_FECHAHASTA => hasta, id_cam => N_CAMARA);
            eliminarAnterioresA2008;
            eliminarFalsasAsignaciones;
            est_paquete.generar_est_actuacion_exp(v_fechaDesde => desde, v_fechaHasta => hasta, id_cam => N_CAMARA);
            est_paquete.agrego_delito(id_cam => N_CAMARA);
            est_paquete.calcula_salidos(finPeriodo => hasta, id_cam => N_CAMARA);
        end if;
    exception
      when error_enEjecutarProceso then
          est_paquete.inserta_error(m_error => 'HUBO UN ERROR EJECUTANDO LA FUNCIÓN "EJECUTAR_PROCESO"', nombre_proceso => v_proceso);
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end calcular_estadistica_p_econ;

    procedure eliminarAnterioresA2008 is
        v_proceso varchar2(30) := 'eliminarAnterioresA2008';
        v_inicio timestamp := systimestamp;
        v_fin timestamp;
    begin
        /* ELIMINO AQUELLOS EXPEDIENTES QUE TIENEN AÑO DE CAUSA ANTERIOR A 2008, YA QUE LO CONSIDERABA ASÍ EN INSTRUCCIÓN CON SQLSERVER */
        delete from est_total_a
        where   ta_anio_exp < 2008
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;
        commit;
    exception
        when others then
            est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            rollback;
    end eliminarAnterioresA2008;

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
end est_paquete_penal_economico;