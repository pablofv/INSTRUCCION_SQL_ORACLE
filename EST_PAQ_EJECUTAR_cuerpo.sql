CREATE OR REPLACE PACKAGE body EST_PAQ_EJECUTAR AS 
    function ejecutar_proceso(f_desde in timestamp, f_hasta in timestamp, CAMARA in int, quieroRecalcular varchar2) return int is
        datos_antes_del_inicio int;
        datos_despues_del_inicio int;
        v_proceso varchar2(30) := 'ejecutar_proceso';
        v_retorno int;
    begin
        select nvl(count(*), 0) into datos_antes_del_inicio
        from est_total_a
        where ta_fecha < f_desde
        and   ta_camara = CAMARA;

        select nvl(count(*), 0) into datos_despues_del_inicio
        from est_total_a
        where ta_fecha > f_desde
        and   ta_camara = CAMARA;
        

        if upper(quieroRecalcular) = 'N' and datos_despues_del_inicio > 0 then
          v_retorno := 1; -- no quiero recalcular pero hay registros, informar error de estadística ya calculada
        elsif upper(quieroRecalcular) = 'N' and datos_despues_del_inicio = 0 and datos_antes_del_inicio > 0 then
          v_retorno := 0;
        else
          insert into est_fecha_de_procesos(fecha, camara) values (sysdate, CAMARA);
          v_retorno := 0; -- o bien quiero recalcular o no quiero recalcular y no hay registros previos, seguimos con el proceso
        end if;

        select max(n_ejecucion) into est_paquete.v_numero_de_ejecucion from est_fecha_de_procesos;
        return v_retorno;
    exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          return 1;
    end ejecutar_proceso;
END EST_PAQ_EJECUTAR;