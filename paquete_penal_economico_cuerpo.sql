create or replace package body est_paquete_penal_economico as
    procedure calcular_estadistica_p_e_csi(desde in timestamp default to_timestamp('01/01/2012', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2012', 'dd/mm/yyyy')) is
      error_enEjecutarProceso exception; -- excepcion para cuando quiero calcular algo que ya está calculado
      v_proceso varchar2(30) := 'calcular_estadistica_p_e_csi';
    begin
        if EST_PAQ_EJECUTAR.ejecutar_proceso(f_desde => desde, f_hasta => hasta, CAMARA => N_CAMARA) = 1 then
            /* 1-> error, 0-> correcto */
            raise error_enEjecutarProceso;
        else
            if not EST_PAQ_EJECUTAR.periodo_inmediato_anterior (f_desde => desde, p_CAMARA => N_CAMARA) then
                est_paquete.saldo_al_inicio(v_fechahasta => desde, id_cam => N_CAMARA);
            end if;
            est_paquete.ingresados(V_FECHADESDE => desde, V_FECHAHASTA => hasta, id_cam => N_CAMARA);
            est_paquete.reingresados(v_fechaDesde => desde, v_fechahasta => hasta, id_cam => N_CAMARA);
            est_paquete.agrego_delito(id_cam => N_CAMARA);
            est_paquete.calcula_salidos(finPeriodo => hasta, id_cam => N_CAMARA);
        end if;
    exception
      when error_enEjecutarProceso then
          est_paquete.inserta_error(m_error => 'HUBO UN ERROR EJECUTANDO LA FUNCIÓN "EJECUTAR_PROCESO"', nombre_proceso => v_proceso);
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end calcular_estadistica_p_e_csi;

    procedure calcular_estadistica_p_e_ssi(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy')) is
    begin
      null;
    end calcular_estadistica_p_e_ssi;
end est_paquete_penal_economico;