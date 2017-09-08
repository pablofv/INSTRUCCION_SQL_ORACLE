create or replace package body est_paquete_cordoba as

    procedure calcular_estadistica_cordoba(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp, recalcular varchar2 default 'N') as
      error_yaFueCalculado exception; -- excepcion para cuando quiero calcular algo que ya está calculado
      hay_registros_anteriores int;
      v_proceso varchar2(30) := 'calcular_estadistica_cordoba';
    begin
        if EST_PAQ_EJECUTAR.ejecutar_proceso(f_desde => desde, f_hasta => hasta, CAMARA => N_CAMARA, quieroRecalcular => recalcular, datos_antes_del_inicio => hay_registros_anteriores) = 1 then
            /* 1-> error, 0-> correcto */
            raise error_yaFueCalculado;
        else
            if hay_registros_anteriores = 0 then
                est_paquete.saldo_al_inicio(v_fechahasta => desde, id_cam => N_CAMARA);
            end if;
            est_paquete.ingresados(V_FECHADESDE => desde, V_FECHAHASTA => hasta, id_cam => N_CAMARA);
            est_paquete.reingresados(v_fechaDesde => desde, v_fechahasta => hasta, id_cam => N_CAMARA);
            est_paquete.agrego_delito(id_cam => N_CAMARA);
            est_paquete.calcula_salidos(finPeriodo => hasta, id_cam => N_CAMARA);
        end if;
    exception
      when error_yaFueCalculado then
          est_paquete.inserta_error(m_error => 'ESTADÍSTICA YA CALCULADA', nombre_proceso => v_proceso);
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end calcular_estadistica_cordoba;
end est_paquete_cordoba;