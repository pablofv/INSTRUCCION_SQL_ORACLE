CREATE OR REPLACE PACKAGE body EST_PAQ_EJECUTAR AS 
    -- Est� funci�n debe retornar verdadero (o cero si no existe el tipo boolean)
    -- si el per�odo que estoy queriendo calcular en el n�mero de estad�stica que corresponda existe,
    -- caso contrario deber� retornar falso (o uno).
    function existe_periodo (f_desde in timestamp, f_hasta in timestamp, p_CAMARA in int) return boolean is
      existe int;
      v_proceso varchar2(30) := 'existe_periodo';
      procedure obtener_estadistica is
          v_proceso varchar2(30) := 'obtener_estadistica';
      begin
          -- Obtiene el valor de estad�stica actual.
          select ve_valor into EST_PAQ_EJECUTAR.n_estadistica
          from est_variable_estadistica
          where ve_camara = p_CAMARA;
      exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
      end obtener_estadistica;
    begin
        --cargamos la variable n�mero de estad�stica
        obtener_estadistica;

        select nvl(count(*), 0) into existe
        from est_total_a
        where ta_fecha between f_desde and f_hasta
        and   ta_camara = p_CAMARA
        and   ta_numero_estadistica = EST_PAQ_EJECUTAR.n_estadistica;

        if existe <> 0 then
          return true;
        else
          return false;
        end if;
    exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end existe_periodo;

    function periodo_inmediato_anterior (f_desde in timestamp, p_CAMARA in int) return boolean is
        inmediato int;
        v_proceso varchar2(30) := 'periodo_inmediato_anterior';
    begin
        -- Se fija si el per�odo inmediato anterior se encuentra calculado.
        select nvl(count(*), 0) into inmediato
        from est_ejecuciones
        where fecha_hasta = f_desde - 1
        and   numero_estadistica = est_paquete.v_numero_estadistica
        and   camara = p_camara;

        if inmediato <> 0 then
          return true;
        else
          return false;
        end if;
    exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end periodo_inmediato_anterior;

    function ejecutar_proceso(f_desde in timestamp, f_hasta in timestamp, CAMARA in int) return int is
        v_proceso varchar2(30) := 'ejecutar_proceso';
    begin
        --Controlo si ya calcul� el per�odo solicitado.
        if existe_periodo(f_desde => f_desde, f_hasta => f_hasta, p_CAMARA => Camara) then
          -- Sumo uno a la variable estad�stica.
          update est_variable_estadistica
          set ve_valor = ve_valor + 1
          where ve_camara = camara;

          select ve_valor into est_paquete.v_numero_estadistica
          from est_variable_estadistica
          where ve_camara = camara;
        elsif periodo_inmediato_anterior(f_desde => f_desde, p_CAMARA => Camara) then
          -- Dejo el mismo valor de estad�stica actual.
          select ve_valor into est_paquete.v_numero_estadistica
          from est_variable_estadistica
          where ve_camara = camara;
        else
          -- Sumo uno a la variable estad�stica.
          update est_variable_estadistica
          set ve_valor = ve_valor + 1
          where ve_camara = camara;

          select ve_valor into est_paquete.v_numero_estadistica
          from est_variable_estadistica
          where ve_camara = camara;
        end if;
        -- inserto una nueva ejecuci�n.
        insert into EST_EJECUCIONES(FECHA_PROCESO, camara, NUMERO_ESTADISTICA, FECHA_DESDE, FECHA_HASTA) values (sysdate, CAMARA, est_paquete.v_numero_estadistica, f_desde, f_hasta);
        --Obtengo el mayor n�mero de ejecuci�n y lo almaceno en la variable del paquete para tener acceso desde cualquier proceso.
        select max(n_ejecucion) into est_paquete.v_numero_de_ejecucion from EST_EJECUCIONES;
        commit;
        return 0;
    exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          rollback;
          return 1;
    end ejecutar_proceso;
END EST_PAQ_EJECUTAR;