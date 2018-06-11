create or replace package body est_paquet_camaras_interior_TO as
--    procedure calcular_estadistica_bahia(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy')) as
    procedure calcular_estadistica(desde in timestamp, hasta in timestamp, camara in int) as
      error_enEjecutarProceso exception; -- excepcion para cuando quiero calcular una estadística que ya está calculada
      v_proceso varchar2(30) := 'est_paquet_camaras_interior_TO';
    begin
        N_CAMARA := camara;
        if EST_PAQ_EJECUTAR.ejecutar_proceso(f_desde => desde, f_hasta => hasta, CAMARA => N_CAMARA) = 1 then
            /* 1-> error, 0-> correcto */
            raise error_enEjecutarProceso;
        else
            est_paquete.generar_est_cbio_asignacion_to(v_fechaDesde => desde, v_fechaHasta => hasta, id_cam => N_CAMARA);
            est_paquete.ingresados_y_reingresados(V_FECHADESDE => desde, V_FECHAHASTA => hasta, id_cam => N_CAMARA);
            eliminarFalsasAsignaciones;
            est_paquete.dejarMateriasPenales(N_CAMARA);
            est_paquete.generar_est_actuacion_exp(v_fechaDesde => desde, v_fechaHasta => hasta, id_cam => N_CAMARA);
            est_paquete.agrego_delito(id_cam => N_CAMARA);
            est_paquete.calcula_salidos(finPeriodo => hasta, id_cam => N_CAMARA);
        end if;
    exception
      when error_enEjecutarProceso then
          est_paquete.inserta_error(m_error => 'HUBO UN ERROR EJECUTANDO LA FUNCIÓN "EJECUTAR_PROCESO"', nombre_proceso => v_proceso);
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end calcular_estadistica;

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
end est_paquet_camaras_interior_TO;