create or replace procedure est_proc_borrar_modelo as
    Type tablas_existentes IS TABLE OF user_objects%ROWTYPE;
    v_tablas tablas_existentes;
    ultimo_elemento int;
begin
    -- order by object_id desc porque entiendo que ese id es incremental de acuerdo a como creo las tablas, y como las que tienen referencia a otra
    -- hay que borrarla primero, para poder borrar la referenciada (por ej. salidos apunta a total a, entonces no puedo borrar total a mientras
    -- exista por lo menos un dato en salidos, y como para crear salidos primero tuve que crear total a, esta tiene un id menor, con lo cual si
    -- lo ordeno por id descendente, primero quedará salidos y luego total a, con lo cual primero borraré salidos, y luego si podré borrar la otra.
    select *
    BULK COLLECT INTO v_tablas
    from user_objects
    where upper(object_name) in ('EST_SALIDOS', 'EST_LOG', 'EST_DURACION_PROCESO', 'EST_CODIGOS_SALIDA',
                                 'EST_ERRORES', 'EST_FECHA_DE_PROCESOS', 'EST_TOTAL_A', 'EST_SECFECHAPROCESO')
    order by Object_Id desc;
    if v_tablas.last > 0 then -- encontró objetos creados
        ultimo_elemento := v_tablas.last;
        For i in 1..ultimo_elemento loop
          if v_tablas(i).object_type = 'TABLE' then -- son tablas
            DBMS_OUTPUT.PUT_LINE('TABLAS: ' || v_tablas(i).object_name);
            execute immediate 'drop table ' || v_tablas(i).object_name;
          elsif v_tablas(i).object_type = 'SEQUENCE' then
            DBMS_OUTPUT.PUT_LINE('SECUENCIAS: ' || v_tablas(i).object_name);
            execute immediate 'drop sequence "' || v_tablas(i).object_name || '"';
          end if;
        end loop;
    end if;
end est_proc_borrar_modelo;