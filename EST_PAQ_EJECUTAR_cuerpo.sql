CREATE OR REPLACE PACKAGE body EST_PAQ_EJECUTAR AS 
    function ejecutar_proceso(f_desde in timestamp, f_hasta in timestamp, CAMARA in int, quieroRecalcular varchar2, datos_antes_del_inicio in out int) return int is
     --   datos_antes_del_inicio int;
        datos_despues_del_inicio int;
        v_proceso varchar2(30) := 'ejecutar_proceso';
        v_retorno int;
        v_numero_est int;
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
          -- no quiero recalcular pero hay registros del mismo per�odo o posterior, informar error de estad�stica ya calculada
          v_retorno := 1;
        elsif upper(quieroRecalcular) = 'N' and datos_despues_del_inicio = 0 and datos_antes_del_inicio > 0 then
          -- no quiero recalcular no hay registros posteriores al per�odo que estoy ejecutando, pero hay datos anteriores, estoy ejecutando un per�odo siguiente
          -- de una estad�stica empezada
          v_retorno := 0;
          -- voy a mantener el mismo n�mero de estad�stica
          select nvl(max(NUMERO_ESTADISTICA), 0) into v_numero_est
          from est_fecha_de_procesos
          where camara = CAMARA;
        else
          -- si no quiero recalcular, en este punto no tengo datos anteriores ni posteriores a lo que estoy calculando, por lo tanto es la primera, as� que debe
          -- darme null la consulta, con un nvl lo transformo a 0 y le sumo uno para empezar con la primera.
          -- si quisiera recalcular, la l�gica es la misma, quiero un n�mero mas que el mayor que haya en la base, lo voy a calcular aqu� por eso, es la misma
          -- consulta que tendr�a que hacer adentro del if de si quiero recalcular.
          select nvl(max(NUMERO_ESTADISTICA), 0) + 1 into v_numero_est
          from est_fecha_de_procesos
          where camara = CAMARA;

          if upper(quieroRecalcular) = 'S' then -- Si estoy recalculando, indico que no hay datos anteriores aunque los haya, porque en tal caso ser�an de otra estad�stica.
              datos_antes_del_inicio := 0;
          end if;
          insert into est_fecha_de_procesos(fecha, camara, NUMERO_ESTADISTICA) values (sysdate, CAMARA, v_numero_est);
          v_retorno := 0; -- o bien quiero recalcular o no quiero recalcular y no hay registros previos ni posteriores, seguimos con el proceso
        end if;

        select max(n_ejecucion) into est_paquete.v_numero_de_ejecucion from est_fecha_de_procesos;
        select max(NUMERO_ESTADISTICA) into est_paquete.v_numero_estadistica from est_fecha_de_procesos where camara = CAMARA;
        return v_retorno;
    exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          return 1;
    end ejecutar_proceso;
END EST_PAQ_EJECUTAR;