CREATE OR REPLACE PACKAGE body EST_PAQ_EJECUTAR2 AS 
    function ejecutar_proceso(f_desde in timestamp, f_hasta in timestamp, CAMARA in int, quieroRecalcular varchar2, datos_antes_del_inicio in out int) return int is
     --   datos_antes_del_inicio int;
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

        -- Quiero que cada corrida sea una nueva estadística
        if upper(quieroRecalcular) = 'N' and datos_despues_del_inicio > 0 then
          -- no quiero recalcular pero hay registros del mismo período o posterior, informar error de estadística ya calculada
          v_retorno := 1;
        elsif upper(quieroRecalcular) = 'N' and datos_despues_del_inicio = 0 and datos_antes_del_inicio > 0 then
          -- no quiero recalcular no hay registros posteriores al período que estoy ejecutando, pero hay datos anteriores, estoy ejecutando un período siguiente
          -- de una estadística empezada
          v_retorno := 0;

          select max(NUMERO_ESTADISTICA) into est_paquete.v_numero_estadistica -- Busco para la cámara, la última ejecución que haya, y dejo el mismo número de estadística
          from EST_EJECUCIONES -- ya que es una continuación de ejecuciones anteriores.
          where camara = CAMARA
          and   n_ejecucion = (select max(n_ejecucion) from EST_EJECUCIONES);
          insert into EST_EJECUCIONES(FECHA_PROCESO, camara, NUMERO_ESTADISTICA, FECHA_DESDE, FECHA_HASTA) values (sysdate, CAMARA, est_paquete.v_numero_estadistica, f_desde, f_hasta);
        else
          -- si no quiero recalcular, en este punto no tengo datos anteriores ni posteriores a lo que estoy calculando, por lo tanto es la primera, así que debe
          -- darme null la consulta, con un nvl lo transformo a 0 y le sumo uno para empezar con la primera.
          -- si quisiera recalcular, la lógica es la misma, quiero un número mas que el mayor que haya en la base, lo voy a calcular aquí por eso, es la misma
          -- consulta que tendría que hacer adentro del if de si quiero recalcular.
              select nvl(max(NUMERO_ESTADISTICA), 0) + 1 into est_paquete.v_numero_estadistica --Busco para la cámara la última ejecución que haya, y a ese número 
              from EST_EJECUCIONES -- de estadística le sumo uno, para empezar una nueva. Eventualmente, en la primer ejecución me devolverá null, con lo cual lo
              where camara = CAMARA -- transformo en cero, para sumarle uno.
              and   n_ejecucion = (select max(n_ejecucion) from EST_EJECUCIONES);

          if upper(quieroRecalcular) = 'S' then -- Si estoy recalculando, indico que no hay datos anteriores aunque los haya, porque en tal caso serían de otra estadística.
              datos_antes_del_inicio := 0;
          end if;
          insert into EST_EJECUCIONES(FECHA_PROCESO, camara, NUMERO_ESTADISTICA, FECHA_DESDE, FECHA_HASTA) values (sysdate, CAMARA, est_paquete.v_numero_estadistica, f_desde, f_hasta);
          v_retorno := 0; -- o bien quiero recalcular o no quiero recalcular y no hay registros previos ni posteriores, seguimos con el proceso
        end if;

        select max(n_ejecucion) into est_paquete.v_numero_de_ejecucion from EST_EJECUCIONES;
        commit;
        return v_retorno;
    exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          return 1;
    end ejecutar_proceso;
END EST_PAQ_EJECUTAR;