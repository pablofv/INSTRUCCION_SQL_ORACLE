create or replace package body est_paquete as
/****************************************************/
/*                  SALDO_AL_INICIO                 */
/****************************************************/

    procedure saldo_al_inicio(v_fechahasta in timestamp, id_cam in int) as
      v_proceso varchar2(30) := 'saldo_al_inicio';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
    begin
        /* Calculo los existentes en base a la consulta de ingresados base, eligiendo la cámara 8, particiono por expediente y oficina,
        y ordeno la fecha descendente, para que rn = 1 sea el último ingreso previo al año que quiera considerar -por ahora inicio de 2012-
        para luego a todos esos registros buscarle un código de salida posterior */
        INSERT INTO LEX100MAESTRAS.EST_TOTAL_A(TA_IDEXP, TA_RN, TA_ANIO_EXP, TA_NUMERO_EXP, TA_OFICINA, TA_FECHA, TA_CODIGO, TA_OBJETO,
                                           TA_FINALIZO, -- 0 -> fuera de trámite 1 -> en trámite
                                           TA_IDCAMBIO, TA_TABLAORIGEN,
                                           TA_TIPO_DE_DATO, -- 0 -> existente 1 -> ingresado 2 -> reingresados
                                           TA_FECHA_PROCESO, TA_NUMERO_DE_EJECUCION, TA_CAMARA)
        SELECT idexp, rn, anio, numExp, id_juzgado, fecha_asignacion, codigo, objeto,
                1, /* -> finalizo originalmente está en 1 (quiere decir en trámite) y luego si la considero salida actualizo a 0 que es fuera de trámite */
                ID_CAMBIO_ASIGNACION_EXP, null, -- por ahora no voy a poner de donde vienen los datos
                0,
                v_inicio, v_numero_de_ejecucion, id_cam
        from (select ROW_NUMBER() over(partition by c.ID_EXPEDIENTE, est_ofi_o_ofi_sup(case when id_secretaria is null then c.id_oficina else c.id_secretaria end) order by FECHA_ASIGNACION desc) rn,  -- Particiona por Expte y Oficina ordenado por fecha de asignación
                     e.id_expediente idexp,
                     e.ANIO_EXPEDIENTE anio,
                     e.NUMERO_EXPEDIENTE numExp,
                     est_ofi_o_ofi_sup(case when id_secretaria is null then c.id_oficina else c.id_secretaria end) id_juzgado,
                     c.FECHA_ASIGNACION,
                     c.CODIGO_TIPO_CAMBIO_ASIGNACION codigo,
                     null objeto,
                     c.ID_CAMBIO_ASIGNACION_EXP
              from (select c1.ID_EXPEDIENTE, c1.ID_OFICINA, c1.id_secretaria, c1.FECHA_ASIGNACION, c1.CODIGO_TIPO_CAMBIO_ASIGNACION, c1.ID_CAMBIO_ASIGNACION_EXP, c1.status
                    from CAMBIO_ASIGNACION_EXP c1
                    union all
                    select a.ID_EXPEDIENTE, a.ID_OFICINA, a.id_secretaria, a.FECHA_actuacion, ee.codigo_estado_expediente, a.ID_actuacion_EXP, a.status
                    from actuacion_exp a join estado_Expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                    where ee.codigo_estado_expediente = 'REI') c
              JOIN EXPEDIENTE e on e.status = 0 and e.ID_EXPEDIENTE = c.ID_EXPEDIENTE and e.NATURALEZA_EXPEDIENTE in ('P')
              JOIN OFICINA o on c.ID_OFICINA = o.ID_OFICINA
              where c.status = 0
              and o.ID_TIPO_INSTANCIA = 1
              and o.ID_CAMARA in (id_cam)
              and O.ID_TIPO_OFICINA IN (1,2) -- Toma solo los Juzgados y Secretarías.
             )
        where rn = 1
        and   trunc(FECHA_ASIGNACION) < v_fechahasta;
        commit;

        /*Ahora que ya tengo los últimos ingresos anteriores a la fecha buscada, me fijo cuantos de esos expedientes tienen luego de esa fecha    */
        /*Y antes de la fecha indicada (por ej. si buscamos 2012, busco salidas entre la fecha del ingreso -que todos son anteriores a dicho año- */
        /*y el inicio de dicho año) un código de salida, y a esos los elimino -porque considero que al iniciar el período están fuera de trámite  */
        delete from est_total_a e
        where ta_tipo_de_dato = 0
        and   TA_NUMERO_DE_EJECUCION = v_numero_de_ejecucion
        and   exists (select 1
                      from actuacion_exp a join ESTADO_EXPEDIENTE ee on a.ID_ESTADO_EXPEDIENTE = ee.ID_ESTADO_EXPEDIENTE
                      where e.TA_IDEXP = a.id_expediente
                      and   ee.CODIGO_ESTADO_EXPEDIENTE in (select codigo from est_codigos_salida where camara = id_cam)
                      and   a.FECHA_ACTUACION > e.TA_FECHA
                      and   a.fecha_actuacion < v_fechahasta
                      union all
                      /* busco que los expedientes que estoy considerando, sean expediente origen de otro, con lo cual ese es un nuevo expediente */
                      /* que representa un ingreso a TO para el primer expediente, pero el sistema les da distintos id, y me sirve para dar fin a */
                      /* la causa "madre" */
                      select 1 
                      from expediente x join actuacion_exp a on (x.id_expediente = a.id_expediente or x.id_expediente_origen = a.id_expediente)
                      join estado_expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                      where e.ta_idexp in(x.ID_EXPEDIENTE_ORIGEN, x.id_expediente) 
                      and   ee.CODIGO_ESTADO_EXPEDIENTE in ('ETO')
                      and   a.FECHA_ACTUACION > e.TA_FECHA
                      and   a.fecha_actuacion < v_fechahasta);
        commit;
        v_fin := systimestamp;
        inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    exception
        when others then
          rollback;
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          v_fin := systimestamp;
          inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end saldo_al_inicio;

/****************************************************/
/*                    INGRESADOS                    */
/****************************************************/

    procedure ingresados(v_fechaDesde in timestamp, v_fechahasta in timestamp, id_cam in int) as
      v_proceso varchar2(30) := 'ingresados';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
    begin
        /* Calculo los ingresados en base a la consulta de ingresados base, eligiendo la cámara 8, al particionar por
           expediente y oficina, los rn=1 son los primeros ingresos a cada una */
        INSERT INTO LEX100MAESTRAS.EST_TOTAL_A(TA_IDEXP, TA_RN, TA_ANIO_EXP, TA_NUMERO_EXP, TA_OFICINA, TA_FECHA, TA_CODIGO, TA_OBJETO,
                                               TA_FINALIZO, -- 0 -> fuera de trámite 1 -> en trámite
                                               TA_IDCAMBIO, TA_TABLAORIGEN,
                                               TA_TIPO_DE_DATO, -- 0 -> existente 1 -> ingresado 2 -> reingresados
                                               TA_FECHA_PROCESO, TA_NUMERO_DE_EJECUCION, TA_CAMARA)
        SELECT idexp, rn, anio, numExp, id_juzgado, fecha_asignacion, codigo, objeto,
               1, /* -> finalizo originalmente está en 1 (quiere decir en trámite) y luego si la considero salida actualizo a 0 que es fuera de trámite */
               ID_CAMBIO_ASIGNACION_EXP, null,
               1, /* -> ingresados */
               v_inicio, v_numero_de_ejecucion, id_cam
        from (select ROW_NUMBER() over(partition by c.ID_EXPEDIENTE, est_ofi_o_ofi_sup(case when id_secretaria is null then c.id_oficina else c.id_secretaria end) order by FECHA_ASIGNACION ) rn,  -- Particiona por Expte y Oficina ordenado por fecha de asignación
              e.id_expediente idexp,
              e.ANIO_EXPEDIENTE anio,
              e.NUMERO_EXPEDIENTE numExp,
              est_ofi_o_ofi_sup(case when id_secretaria is null then c.id_oficina else c.id_secretaria end) id_juzgado,
              c.FECHA_ASIGNACION,
              c.CODIGO_TIPO_CAMBIO_ASIGNACION codigo,
              null objeto,
              c.ID_CAMBIO_ASIGNACION_EXP
              from (select c1.ID_EXPEDIENTE, c1.ID_OFICINA, c1.id_secretaria, c1.FECHA_ASIGNACION, c1.CODIGO_TIPO_CAMBIO_ASIGNACION, c1.ID_CAMBIO_ASIGNACION_EXP, c1.status
                    from CAMBIO_ASIGNACION_EXP c1
                    union all
                    select a.ID_EXPEDIENTE, a.ID_OFICINA, a.id_secretaria, a.FECHA_actuacion, ee.codigo_estado_expediente, a.ID_actuacion_EXP, a.status
                    from actuacion_exp a join estado_Expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                    where ee.codigo_estado_expediente = 'REI') c
              JOIN EXPEDIENTE e on e.status = 0 and e.ID_EXPEDIENTE = c.ID_EXPEDIENTE and e.NATURALEZA_EXPEDIENTE in ('P')
              JOIN OFICINA o on c.ID_OFICINA = o.ID_OFICINA
              where c.status = 0
              and o.ID_TIPO_INSTANCIA = 1
              and o.ID_CAMARA in (id_cam)
              and O.ID_TIPO_OFICINA IN (1,2) -- Toma solo los Juzgados y Secretarías.
             )
        where rn = 1
        and   trunc(FECHA_ASIGNACION) between v_fechaDesde and v_fechahasta
        order by anio, numexp, FECHA_ASIGNACION;
        commit;
        v_fin := systimestamp;
        inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    exception
        when others then
          rollback;
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          v_fin := systimestamp;
          inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end ingresados;

/****************************************************/
/*                   REINGRESADOS                   */
/****************************************************/

    procedure reingresados(v_fechaDesde in timestamp, v_fechahasta in timestamp, id_cam in int) as
      v_proceso varchar2(30) := 'reingresados';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
    begin
        /* Calculo los reingresados en base a la consulta de ingresados base, eligiendo la cámara 8, al particionar por
           expediente y oficina, los rn>1 son los siguientes ingresos a cada oficina, y por lo tanto los considero reingresos */
        INSERT INTO LEX100MAESTRAS.EST_TOTAL_A(TA_IDEXP, TA_RN, TA_ANIO_EXP, TA_NUMERO_EXP, TA_OFICINA, TA_FECHA, TA_CODIGO, TA_OBJETO,
                                               TA_FINALIZO, -- 0 -> fuera de trámite 1 -> en trámite
                                               TA_IDCAMBIO, TA_TABLAORIGEN,
                                               TA_TIPO_DE_DATO, -- 0 -> existente 1 -> ingresado 2 -> reingresados
                                               TA_FECHA_PROCESO, TA_NUMERO_DE_EJECUCION, TA_CAMARA)
        SELECT idexp, rn, anio, numExp, id_juzgado, fecha_asignacion, codigo, objeto,
               1,
               ID_CAMBIO_ASIGNACION_EXP, null,
               2,
               v_inicio, v_numero_de_ejecucion, id_cam
        from (select ROW_NUMBER() over(partition by c.ID_EXPEDIENTE, est_ofi_o_ofi_sup(case when id_secretaria is null then c.id_oficina else c.id_secretaria end) order by FECHA_ASIGNACION ) rn,  -- Particiona por Expte y Oficina ordenado por fecha de asignación
              e.id_expediente idexp,
              e.ANIO_EXPEDIENTE anio,
              e.NUMERO_EXPEDIENTE numExp,
              --case when id_secretaria is null then c.id_oficina else c.id_secretaria end id_juzgado,
              est_ofi_o_ofi_sup(case when id_secretaria is null then c.id_oficina else c.id_secretaria end) id_juzgado,
              c.FECHA_ASIGNACION,
              c.CODIGO_TIPO_CAMBIO_ASIGNACION codigo,
              null objeto,
              c.ID_CAMBIO_ASIGNACION_EXP
              from (select c1.ID_EXPEDIENTE, c1.ID_OFICINA, c1.id_secretaria, c1.FECHA_ASIGNACION, c1.CODIGO_TIPO_CAMBIO_ASIGNACION, c1.ID_CAMBIO_ASIGNACION_EXP, c1.status
                    from CAMBIO_ASIGNACION_EXP c1
                    union all
                    select a.ID_EXPEDIENTE, a.ID_OFICINA, a.id_secretaria, a.FECHA_actuacion, ee.codigo_estado_expediente, a.ID_actuacion_EXP, a.status
                    from actuacion_exp a join estado_Expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                    where ee.codigo_estado_expediente = 'REI') c 
              JOIN EXPEDIENTE e on e.status = 0 and e.ID_EXPEDIENTE = c.ID_EXPEDIENTE and e.NATURALEZA_EXPEDIENTE in ('P')
              JOIN OFICINA o on c.ID_OFICINA = o.ID_OFICINA
              where c.status = 0
              and o.ID_TIPO_INSTANCIA = 1
              and o.ID_CAMARA in (id_cam)
              and O.ID_TIPO_OFICINA IN (1,2) -- Toma solo los Juzgados y Secretarías.
             )
        where rn > 1
        and   trunc(FECHA_ASIGNACION) between v_fechaDesde and v_fechahasta
        order by anio, numexp, FECHA_ASIGNACION;
        commit;
        v_fin := systimestamp;
        inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    exception
        when others then
          rollback;
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          v_fin := systimestamp;
          inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end reingresados;

/***************************************************/
/*                 CALCULA_SALIDOS                 */
/***************************************************/

    procedure calcula_salidos(finPeriodo in timestamp, id_cam in number) as
      filaActual int := 0;
      reg cursor_Salidos%rowtype;
      regAnt cursor_salidos%ROWTYPE;
  --    salida int;
 --     v_fechaSalida date;
 --     v_codigoSalida varchar2(4 char);
 --     fallo_est_busca_salida exception;
      resultado int;
      v_fechaHasta timestamp;
      v_proceso varchar2(30) := 'calcula_salidos';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
    begin
        /* al fin de período le sumo uno por el tema de las fechas con horas, por ejemplo 31/12/2010 12:24 es mayor que 31/12/2010 que es la fecha
        pasada por parámetro, entonces me deja afuera los registros del último día del período */
        v_fechaHasta := finPeriodo + 1;
        DBMS_OUTPUT.put_line(v_fechaHasta);

        open cursor_salidos(v_numero_de_ejecucion, id_cam);
        loop
            fetch cursor_salidos into reg;
            exit when cursor_salidos%NOTFOUND or cursor_salidos%NOTFOUND is null;
            filaActual := cursor_salidos%rowcount;
            /* VERIFICO QUE HAYA MAS DE UNA FILA */
            if cursor_salidos%rowcount > 1 then
                resultado := f_gestiona_salidas(reg => reg, regAnt => regant, id_camara => id_cam, findePeriodo => v_fechaHasta, v_FECHA_DE_EJECUCION => v_inicio, nroFila => filaActual);
            end if;
            regAnt := reg;
        end loop;
        close cursor_salidos;
        if filaActual = 0 then
            inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso); -- No había filas
        else
            resultado := f_gestiona_ultima_salida(reg => null, regAnt => regant, id_camara => id_cam, finDePeriodo => v_fechaHasta, v_FECHA_DE_EJECUCION => v_inicio, nroFila  => filaActual);
        end if; -- filaActual = 0
        v_fin := systimestamp;
        inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
        exception
            when others then
              rollback;
              inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
              v_fin := systimestamp;
              inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end calcula_salidos;

/****************************************************/
/*                F_GESTIONA_SALIDAS                */
/****************************************************/

    function f_gestiona_salidas(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_camara number, finDePeriodo in timestamp, v_FECHA_DE_EJECUCION in timestamp, nroFila in int) return int is
        actuacion_id int;
        v_proceso varchar2(30) := 'f_gestiona_salidas';
    begin
        if reg.ta_idexp = regant.ta_idexp then /* SI ES LA MISMA CAUSA */
            -- Busco salida entre esos dos registros
            actuacion_id := f_busca_la_salida(idexp => reg.ta_idexp, id_cam => id_camara, fechaDesde => regAnt.ta_fecha, fechaHasta => reg.ta_fecha, oficina => regAnt.ta_oficina, reg => reg, regAnt => regAnt, filaActual => nroFila, fechaDelProceso => v_FECHA_DE_EJECUCION);
        else -- cambie de expediente, busco hasta el fin de período
            actuacion_id := f_busca_la_salida(idexp => regAnt.ta_idexp, id_cam => id_camara, fechaDesde => regAnt.ta_fecha, fechaHasta => finDePeriodo, oficina => regAnt.ta_oficina, reg => reg, regAnt => regAnt, filaActual => nroFila, fechaDelProceso => v_FECHA_DE_EJECUCION);
        end if;
        /* Inserto en el log los valores del cursor */
        -- Le resto uno a la fila para que empiece por uno (a las comparaciones entre filas del cursor recién entro en la segunda iteración,
        -- entonces empezaba con la fila 2) y solo la última llamada la dejaré tal cual para que ahí si quede el último número de fila y no
        -- repita eso en las dos últimas filas de la tabla log.
        inserta_log(reg => reg, regAnt => regAnt, id_actuacion => actuacion_id, filaActual => nroFila - 1, fechaProceso => v_FECHA_DE_EJECUCION);
        return actuacion_id;
    exception
        when others then
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end f_gestiona_salidas;

/***************************************************/
/*                F_BUSCA_LA_SALIDA                */
/***************************************************/

    function f_busca_la_salida(idexp int, fechaDesde timestamp, fechaHasta timestamp, oficina int, id_cam number, reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, filaActual in int, fechaDelProceso in timestamp) return int is
      id_act int;
      fechaSalida timestamp;
      codigoSalida varchar2(3);
      radicacion varchar2(10);
      r_insertSalido reg_est_salidos;
      v_proceso varchar2(30) := 'f_busca_la_salida';
    begin
        select id_actuacion_exp, fecha_actuacion, codigo, radicacion into id_act, fechaSalida, codigoSalida, radicacion
        from (select ROW_NUMBER() over(partition by id_expediente order by fecha_actuacion desc) numero_fila, id_actuacion_exp, fecha_actuacion, codigo, radicacion
              from (select null radicacion, a.id_actuacion_exp, a.fecha_actuacion, ee.codigo_estado_expediente as codigo, a.id_expediente
                    from actuacion_exp a join estado_expediente ee on a.id_estado_expediente = ee.id_estado_expediente and ee.CODIGO_ESTADO_EXPEDIENTE in (select codigo from est_codigos_salida where camara = id_cam)
                    where a.id_expediente = idexp
                    and   a.fecha_actuacion between fechaDesde and fechaHasta
                    and   est_busca_juzgado(a.id_oficina) = est_busca_juzgado(oficina) --est_busca_juzgado(oficina)
                    union all
                    select null radicacion, a.id_actuacion_exp, a.fecha_actuacion, ee.codigo_estado_expediente as codigo, case when x.ID_EXPEDIENTE_ORIGEN is null then x.id_expediente else x.id_expediente_origen end
                    from expediente x join actuacion_exp a on x.id_expediente = a.id_expediente
                    join estado_expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                    where idexp in (x.ID_EXPEDIENTE_ORIGEN, x.id_expediente)
                    and   ee.CODIGO_ESTADO_EXPEDIENTE in ('ETO')
                    and   a.fecha_actuacion between fechaDesde and fechaHasta
                    and   est_busca_juzgado(a.id_oficina) = est_busca_juzgado(oficina) --est_busca_juzgado(oficina)
                    union all
                    select c.tipo_radicacion, c.id_cambio_asignacion_exp, c.fecha_asignacion, c.codigo_tipo_cambio_asignacion as codigo, case when e.ID_EXPEDIENTE_ORIGEN is null then e.id_expediente else e.id_expediente_origen end
                    from cambio_asignacion_exp c join expediente e on c.id_expediente = e.id_expediente
                    where idexp in (e.id_expediente_origen, e.id_expediente)
                    and   c.fecha_asignacion between fechaDesde and fechaHasta
                    and   est_busca_juzgado(c.id_oficina) = est_busca_juzgado(oficina) --est_busca_juzgado(oficina)
                    and   c.CODIGO_TIPO_CAMBIO_ASIGNACION in ('ETO')
                    ) cambio_actuacion
              ) r -- de resultado
        where numero_fila = 1;

      /* ENCONTRÉ UNA SALIDA, PREPARO EL REGISTRO PARA INSERTAR EN LA TABLA DE SALIDOS */
        r_insertSalido.radicacion := radicacion;
        r_insertSalido.actuacion := id_act;
        r_insertSalido.anio_exp := regAnt.ta_anio_exp;
        r_insertSalido.codigo := codigoSalida;
        r_insertSalido.fecha := fechaSalida;
        r_insertSalido.fecha_proceso := fechaDelProceso;
        r_insertSalido.idexp := regAnt.ta_idexp;
        r_insertSalido.numero_exp := regAnt.ta_numero_exp;
        r_insertSalido.objeto := regAnt.ta_objeto;
        r_insertSalido.oficina := regAnt.ta_oficina;
        r_insertSalido.rn := regAnt.ta_rn;
        r_insertSalido.tipo_de_dato := regAnt.ta_tipo_de_dato;

        inserta_salida(registro => r_insertSalido, reg => reg, regAnt => regAnt, id_actuacion => id_act, filaActual => filaActual, fechaProceso => fechaDelProceso);
        
        return id_act;
    exception
        when no_data_found then
            --inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            /* Si estoy buscando salidas entre dos registros de la misma causa inserto un código FIN, pero si estoy buscando entre dos causas */
            /* diferentes, y no encontré una salida no debo insertar un código FIN */
  
            if (reg.ta_idexp) = (regAnt.ta_idexp) then -- Estoy buscando entre registros de la misma causa
                /* preparo el registro que insertaremos */
                r_insertSalido.actuacion := id_act;
                r_insertSalido.anio_exp := regAnt.ta_anio_exp;
                r_insertSalido.codigo := 'FIN';
                r_insertSalido.fecha := reg.ta_fecha; -- cambio la fecha del reg anterior por la fecha del registro actual
                r_insertSalido.fecha_proceso := fechaDelProceso;
                r_insertSalido.idexp := regAnt.ta_idexp;
                r_insertSalido.numero_exp := regAnt.ta_numero_exp;
                r_insertSalido.objeto := regAnt.ta_objeto;
                r_insertSalido.oficina := regAnt.ta_oficina;
                r_insertSalido.rn := regAnt.ta_rn;
                r_insertSalido.tipo_de_dato := regAnt.ta_tipo_de_dato;
                inserta_salida(registro => r_insertSalido, reg => reg, regAnt => regAnt, id_actuacion => id_act, filaActual => filaActual, fechaProceso => fechaDelProceso);
            end if; --(reg = regAnt)
            return 0;
        when too_many_rows then
            inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            return -3;
        when others then
            inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            return -1;
    end f_busca_la_salida;

/****************************************************/
/*                  INSERTA_SALIDA                  */
/****************************************************/

    procedure inserta_salida (registro in reg_est_salidos, reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_actuacion in number, filaActual in int, fechaProceso in timestamp) is
      idexp int;
      ofi int;
      numfila int;
      t_d int;
      Numero_ejecucion int;
      v_proceso varchar2(30) := 'inserta_salida';
    begin
        insert into est_salidos(SAL_ANIO_EXP, SAL_CODIGO, SAL_FECHA, sal_fechaProceso, SAL_IDEXP, SAL_NUMERO_EXP, SAL_OBJETO, SAL_OFICINA, sal_rn, sal_actuacion, SAL_NUMERO_DE_EJECUCION, sal_radicacion)
        values(registro.anio_exp, registro.codigo, registro.fecha, registro.fecha_Proceso, registro.idexp, registro.numero_exp, registro.objeto, registro.oficina, registro.rn, registro.actuacion, v_numero_de_ejecucion, registro.radicacion);
        commit;
        
        idexp := registro.idexp;
        ofi := registro.oficina;
        numfila := registro.rn;
        t_d := registro.tipo_de_dato;
        Numero_ejecucion := regAnt.TA_NUMERO_DE_EJECUCION;
        
        update est_total_a
        set ta_finalizo = 0, TA_FECHA_DE_FINALIZACION = REGISTRO.FECHA
        where ta_idexp = registro.idexp
        and   ta_oficina = registro.oficina
        and   ta_rn = registro.rn
        and   ta_tipo_de_dato = registro.tipo_de_dato
        and   TA_NUMERO_DE_EJECUCION = regAnt.TA_NUMERO_DE_EJECUCION;
        commit;
    exception
      when others then
        rollback;
        inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end inserta_salida;

/***************************************************/
/*                   INSERTA_LOG                   */
/***************************************************/

    procedure inserta_log(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_actuacion in number, filaActual in int, fechaProceso in timestamp) is
      v_proceso varchar2(30) := 'inserta_log';
    begin
        insert into est_log(ant_ide, ide, ant_fecha, fecha, id_act, ant_ofi, ofi, rn_ant, rn, numfila, FECHA_DE_EJECUCION, NUMERO_DE_EJECUCION)
        values (regant.ta_idexp, reg.ta_idexp, regant.ta_fecha, reg.ta_fecha, id_actuacion, regant.ta_oficina, reg.ta_oficina, regant.ta_rn, reg.ta_rn, filaActual, fechaProceso, v_numero_de_ejecucion);
        commit;
    exception
      when others then
        rollback;
        inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end inserta_log;

/***************************************************/
/*                  INSERTA_ERROR                  */
/***************************************************/

    procedure inserta_error(m_error in varchar2, nombre_proceso in varchar2) is
    begin
      insert into est_errores(problema, fecha, numero_secuencia, proceso)
      values (m_error, systimestamp, (select nvl(max(numero_secuencia) + 1, 1) from est_errores), nombre_proceso);
      commit;
    exception
      when others then
        rollback;
    end inserta_error;

/****************************************************/
/*             F_GESTIONA_ULTIMA_SALIDA             */
/****************************************************/

    function f_gestiona_ultima_salida(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_camara number, finDePeriodo in timestamp, v_FECHA_DE_EJECUCION in timestamp, nroFila in int) return int is
        actuacion_id int;
        v_proceso varchar2(30) := 'f_gestiona_ultima_salida';
    begin
        /* AL SER EL ÚLTIMO REGISTRO, ES COMO BUSCAR CUANDO CAMBIO DE CAUSA, HASTA EL FIN DE PERÍODO, EN ESTE CASO SI NO ENCUENTRO UNA SALIDA, NO AGREGÓ UN CÓDIGO FIN */
        actuacion_id := f_busca_la_salida(idexp => regAnt.ta_idexp, id_cam => id_camara, fechaDesde => regAnt.ta_fecha, fechaHasta => finDePeriodo, oficina => regAnt.ta_oficina, reg => reg, regAnt => regAnt, filaActual => nroFila, fechaDelProceso => v_FECHA_DE_EJECUCION);
        /* Inserto en el log los valores del cursor */
        inserta_log(reg => reg, regAnt => regAnt, id_actuacion => actuacion_id, filaActual => nroFila, fechaProceso => v_FECHA_DE_EJECUCION);
        return actuacion_id;
    exception
        when others then
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end f_gestiona_ultima_salida;

/***************************************************/
/*            INSERTA_DURACION_PROCESOS            */
/***************************************************/

    procedure inserta_duracion_procesos(camara in int, nombre in varchar2, inicio in timestamp, fin in timestamp) is
    begin
      insert into est_duracion_proceso(CAMARA, NOMBRE_PROCESO, INICIO_PROCESO, FIN_PROCESO)
                                values(camara, nombre, inicio, fin);
      commit;
    exception
      when others then
        rollback;
    end inserta_duracion_procesos;
end est_paquete;