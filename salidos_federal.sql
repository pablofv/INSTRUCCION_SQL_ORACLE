create or replace procedure est_calcula_salidos_federal(finPeriodo in out date) as --default to_date('20080101', 'yyyymmdd')
  /* Defino el cursor que es mi conjunto de causas a buscar sus salidas */
  cursor cursor_salidos is
  select TA_IDEXP, TA_RN, TA_ANIO_EXP, TA_NUMERO_EXP, TA_OFICINA, TA_FECHA, TA_CODIGO, TA_OBJETO, TA_FINALIZO,
         TA_IDCAMBIO, TA_TABLAORIGEN, TA_TIPO_DE_DATO, TA_FECHA_PROCESO
  from EST_TOTAL_A
  where TA_FECHA_PROCESO = (select max(ta_fecha_proceso) from EST_TOTAL_A) -- si tengo mas de una ejecución del proceso, quiero la última
  and   ta_finalizo = 1 -- quiero solo las causas que siguen activas
  order by ta_idexp, ta_fecha;

  filaActual int := 1;
  filasAfectadas int := 0;
  regAnt cursor_salidos%ROWTYPE;
  salida int;
  v_fechaSalida date;
  v_codigoSalida varchar2(4 char);
  v_FECHA_DE_EJECUCION date;
  fallo_est_busca_salida exception;
begin
    /* al fin de período le sumo uno por el tema de las fechas con horas, por ejemplo 31/12/2010 12:24 es mayor que 31/12/2010 que es la fecha
    pasada por parámetro, entonces me deja afuera los registros del último día del período */
    finPeriodo := finPeriodo + 1;
    DBMS_OUTPUT.put_line(finPeriodo);
    select max(fecha) into v_FECHA_DE_EJECUCION from est_fecha_de_procesos;
    FOR REG IN cursor_salidos
    LOOP
        /* VERIFICO QUE HAYA MAS DE UNA FILA */
        if cursor_salidos%rowcount > 1 then
            if reg.ta_idexp = regant.ta_idexp then /* SI ES LA MISMA CAUSA */
                -- buscar entre las dos filas si hay una salida en actuación
                salida := est_busca_salidas_federal(idexp => regant.ta_idexp,
                                                    fechaD => regant.ta_fecha,
                                                    fechaH => reg.ta_fecha,
                                                    oficina => regant.ta_oficina,
                                                    fechaSalida => v_fechaSalida,
                                                    codigoSalida => v_codigoSalida);

                if salida in (-1, -3) then -- hubo errores en la función est_busca_salida
                    raise fallo_est_busca_salida;
                elsif salida in (-2) then -- no se encontró salida entre los dos ingresos, agrego un código fin
        --            DBMS_OUTPUT.put_line('HACER UN INSERT CON CÓDIGO FIN');
                    insert into est_salidos(SAL_IDEXP, SAL_ANIO_EXP, SAL_NUMERO_EXP, SAL_OFICINA, SAL_FECHA, SAL_CODIGO, SAL_OBJETO, sal_rn, sal_fechaProceso)
                    values(regAnt.ta_idexp, regant.ta_ANIO_EXP, regant.ta_NUMERO_EXP, regant.ta_oficina, regant.ta_fecha, 'FIN', regant.ta_OBJETO, regant.ta_rn, v_fecha_de_ejecucion);
                else -- se encontró una salida entre los dos ingresos, agrego el código de salida
         --           DBMS_OUTPUT.put_line('HACER UN INSERT CON EL CÓDIGO DE SALIDA');
                    insert into est_salidos(SAL_IDEXP, SAL_ANIO_EXP, SAL_NUMERO_EXP, SAL_OFICINA, SAL_FECHA, SAL_CODIGO, SAL_OBJETO, sal_rn, sal_fechaProceso)
                    values(regAnt.ta_idexp, regant.ta_ANIO_EXP, regant.ta_NUMERO_EXP, regant.ta_oficina, v_fechaSalida, v_codigoSalida, regant.ta_OBJETO, regant.ta_rn, v_fecha_de_ejecucion);
                end if; -- if salida in (-1, -3)

                filaActual := cursor_salidos%rowcount;
                insert into est_log(ant_ide, ide, ant_fecha, fecha, id_act, ant_ofi, ofi, rn_ant, rn, numfila, FECHA_DE_EJECUCION)
                values (regant.ta_idexp, reg.ta_idexp, regant.ta_fecha, reg.ta_fecha, salida, regant.ta_oficina, reg.ta_oficina, regant.ta_rn, reg.ta_rn, filaActual, v_FECHA_DE_EJECUCION);

                /* en este punto solo puedo llegar si ha habido una salida, ya sea encontrada o puesta por mi mediante el código FIN,
                por eso considero a dicha entrada como finalizada*/

                update est_total_a
                set ta_finalizo = 0
                where ta_idexp = regant.ta_idexp
                and   ta_oficina = regant.ta_oficina
                and   ta_rn = regant.ta_rn
                and   ta_tipo_de_dato = regant.ta_tipo_de_dato
                and   ta_fecha_proceso = regant.ta_fecha_proceso;

                commit;
            else -- cambie de expediente, busco hasta el fin de período
                salida := est_busca_salidas_federal(idexp => regant.ta_idexp,
                                            fechaD => regant.ta_fecha,
                                            fechaH => finPeriodo,
                                            oficina => regant.ta_oficina,
                                            fechaSalida => v_fechaSalida,
                                            codigoSalida => v_codigoSalida);
 
                if salida in (-1, -3) then -- hubo errores en la función est_busca_salida
                    raise fallo_est_busca_salida;
                elsif salida not in (-2) then -- se encontró una salida entre el ingreso y el fin de período, agrego el código de salida
                    insert into est_salidos(SAL_IDEXP, SAL_ANIO_EXP, SAL_NUMERO_EXP, SAL_OFICINA, SAL_FECHA, SAL_CODIGO, SAL_OBJETO, sal_rn, sal_fechaProceso)
                    values(regAnt.ta_idexp, regant.ta_ANIO_EXP, regant.ta_NUMERO_EXP, regant.ta_oficina, v_fechaSalida, v_codigoSalida, regant.ta_OBJETO, regant.ta_rn, v_fecha_de_ejecucion);

                    /*Como encontré una salida para este ingreso, lo marco como finalizado */
                    update est_total_a
                    set ta_finalizo = 0
                    where ta_idexp = regant.ta_idexp
                    and   ta_oficina = regant.ta_oficina
                    and   ta_rn = regant.ta_rn
                    and   ta_tipo_de_dato = regant.ta_tipo_de_dato
                    and   ta_fecha_proceso = regant.ta_fecha_proceso;

                end if; -- if salida in (-1, -3)

                filaActual := cursor_salidos%rowcount;
                insert into est_log(ant_ide, ide, ant_fecha, fecha, id_act, ant_ofi, ofi, rn_ant, rn, numfila, FECHA_DE_EJECUCION)
                values (regant.ta_idexp, reg.ta_idexp, regant.ta_fecha, reg.ta_fecha, salida, regant.ta_oficina, reg.ta_oficina, regant.ta_rn, reg.ta_rn, filaActual, v_FECHA_DE_EJECUCION);
                commit;
            end if; -- if reg.ing_idexp = regant.ing_idexp
        end if; --rowcount > 1
        regAnt := reg;
        filasAfectadas := cursor_salidos%rowcount;
        
        if mod(filaActual, 100) = 0 then
            DBMS_OUTPUT.put_line(filaActual);
        end if;
    END LOOP;
    if filasAfectadas = 0 then
        DBMS_OUTPUT.put_line('filasAfectadas: ' || filasAfectadas); -- No había filas
    else
        /* buscar desde el registro anterior hasta fin de período */

        salida := est_busca_salidas_federal(idexp => regant.ta_idexp,
                                    fechaD => regant.ta_fecha,
                                    fechaH => finPeriodo,
                                    oficina => regant.ta_oficina,
                                    fechaSalida => v_fechaSalida,
                                    codigoSalida => v_codigoSalida);

        if salida in (-1, -3) then -- hubo errores en la función est_busca_salida
            raise fallo_est_busca_salida;
        elsif salida not in (-2) then -- se encontró una salida entre el ingreso y el fin de período, agrego el código de salida
  --          DBMS_OUTPUT.put_line('HACER UN INSERT CON EL CÓDIGO DE SALIDA');
            insert into est_salidos(SAL_IDEXP, SAL_ANIO_EXP, SAL_NUMERO_EXP, SAL_OFICINA, SAL_FECHA, SAL_CODIGO, SAL_OBJETO, sal_rn, sal_fechaProceso)
            values(regAnt.ta_idexp, regant.ta_ANIO_EXP, regant.ta_NUMERO_EXP, regant.ta_oficina, v_fechaSalida, v_codigoSalida/*regant.ta_CODIGO*/, regant.ta_OBJETO, regant.ta_rn, v_fecha_de_ejecucion);

            update est_total_a
            set ta_finalizo = 0
            where ta_idexp = regant.ta_idexp
            and   ta_oficina = regant.ta_oficina
            and   ta_rn = regant.ta_rn
            and   ta_tipo_de_dato = regant.ta_tipo_de_dato
            and   ta_fecha_proceso = regant.ta_fecha_proceso;
        end if; -- if salida in (-1, -3)
        commit;

    end if;
exception
    when others then
      DBMS_OUTPUT.put_line(DBMS_UTILITY.format_error_stack);
      rollback;
end;