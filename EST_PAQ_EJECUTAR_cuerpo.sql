CREATE OR REPLACE PACKAGE body EST_PAQ_EJECUTAR AS 
    function ejecutar_proceso(f_desde in timestamp, f_hasta in timestamp, CAMARA in int, quieroRecalcular varchar2) return int is
        hay_registros_anteriores int;
        v_proceso varchar2(30) := 'ejecutar_proceso';
    begin
        select nvl(count(*), 0) into hay_registros_anteriores
        from est_total_a
        where ta_fecha between f_desde and f_hasta
        and   ta_camara = CAMARA;

        if upper(quieroRecalcular) = 'N' and hay_registros_anteriores > 0 then
          return 1; -- no quiero recalcular pero hay registros, informar error de estadística ya calculada
        else
          return 0; -- o bien quiero recalcular o no quiero recalcular y no hay registros previos, seguimos con el proceso
        end if;
    exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          return 1;
    end ejecutar_proceso;
END EST_PAQ_EJECUTAR;