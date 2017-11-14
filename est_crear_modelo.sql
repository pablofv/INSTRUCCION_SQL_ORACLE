declare
    v_proceso varchar2(100) := 'Bloque para crear el modelo, como procedimiento no funciona.';
    
    procedure est_proc_borrar_modelo as
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
                                     'EST_ERRORES', 'EST_EJECUCIONES', 'EST_TOTAL_A', 'EST_SECFECHAPROCESO')
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
begin
-- Primero borro el modelo
    est_proc_borrar_modelo;
--est_fecha_de_procesos

    -- Tabla para usar de variable, con un número que representa el número de estadística actual. Comenzará en 0, para que al hacer la primer estadística, se incremente a uno.
    execute immediate 'CREATE TABLE EST_VARIABLE_ESTADISTICA(VE_VALOR INT
                                                             )';
    execute immediate 'INSERT INTO EST_VARIABLE_ESTADISTICA (VE_VALOR) VALUES (0)';

    execute immediate 'CREATE TABLE EST_EJECUCIONES(FECHA_PROCESO TIMESTAMP(6),
                                                    N_EJECUCION INT,
                                                    CAMARA NUMBER(2),
                                                    NUMERO_ESTADISTICA INT NOT NULL,
                                                    FECHA_DESDE TIMESTAMP,
                                                    FECHA_HASTA TIMESTAMP,
                                                    CONSTRAINT "CP_fechaDeProcesos" PRIMARY KEY ("N_EJECUCION")
                                                    )';

    execute immediate  'CREATE TABLE EST_TOTAL_A(TA_CLAVE INT NOT NULL,
                                                 TA_IDEXP NUMBER(10,0) NOT NULL ENABLE,
                                                 TA_RN NUMBER(3,0) NOT NULL ENABLE,
                                                 TA_ANIO_EXP NUMBER(10,0),
                                                 TA_NUMERO_EXP NUMBER(10,0),
                                                 TA_OFICINA NUMBER(10,0) NOT NULL ENABLE,
                                                 TA_FECHA TIMESTAMP(6),
                                                 TA_CODIGO VARCHAR2(10 BYTE),
                                                 TA_OBJETO NUMBER(10,0),
                                                 TA_FINALIZO NUMBER(1,0),
                                                 TA_FECHA_DE_FINALIZACION TIMESTAMP(6),
                                                 TA_IDTABLAORIGEN NUMBER(10,0),
                                                 TA_TABLAORIGEN VARCHAR2(30 BYTE),-- 1-> CAMBIO_ASIGNACION    2-> ACTUACION_EXP
                                                 TA_TIPO_DE_DATO NUMBER(1,0) NOT NULL ENABLE,-- 0 -> existente 1 -> ingresado 2 -> reingresados
                                                 TA_FECHA_PROCESO TIMESTAMP(6) NOT NULL ENABLE,
                                                 TA_NUMERO_DE_EJECUCION INT,
                                                 TA_NUMERO_ESTADISTICA INT,
                                                 TA_MATERIA INT,
                                                 TA_CAMARA NUMBER(2),
                        CONSTRAINT CP_TOTAL_A PRIMARY KEY ("TA_CLAVE"),
                        CONSTRAINT UQ_VIEJA_CLAVE_INGRESOS UNIQUE ("TA_IDEXP", "TA_OFICINA", "TA_RN", "TA_FECHA", "TA_NUMERO_DE_EJECUCION"),
                        CONSTRAINT UQ_ID_TABLA_PROVEEDORA UNIQUE("TA_IDTABLAORIGEN", "TA_TABLAORIGEN", "TA_NUMERO_DE_EJECUCION"))';

    execute immediate 'comment on column EST_TOTAL_A.TA_FINALIZO is ''Estado del expediente: 0 = está finalizado; 1 = continua en trámite.''';
    execute immediate 'comment on column EST_TOTAL_A.TA_TABLAORIGEN is ''De donde proviene el registro: 1 = cambio_asignacion_exp; 2 = actuacion_exp.''';
    execute immediate 'comment on column EST_TOTAL_A.TA_TIPO_DE_DATO is ''Que tipo de dato contiene el registro: 0 = existente; 1 = ingresado; 2 = reingresado.''';

    execute immediate 'create or replace trigger tr_inserta_clave_TOTAL_A
                       for insert
                       on EST_TOTAL_A
                       compound trigger
                            filas int := 0;
                            numero_estadistica int := 0;
                            function Cuenta_Cantidad return int is
                                PRAGMA AUTONOMOUS_TRANSACTION;
                                cant int := 0;
                            begin
                                select nvl(max(TA_CLAVE), 0) into cant from EST_TOTAL_A;
                                return cant;
                            end Cuenta_Cantidad;
                       before each row is 
                       begin
                            if :new.TA_CLAVE is not null then
                                raise_application_error(-20023,''No se puede asignar manualmente un valor a la columna TA_CLAVE.'');
                            end if;
                            filas := filas + 1;
                            :new.TA_CLAVE := Cuenta_Cantidad + filas;
                        end before each row;
                       end tr_inserta_clave_TOTAL_A;';

    execute immediate 'CREATE TABLE EST_SALIDOS(SAL_CLAVE INT,
                                                SAL_IDEXP NUMBER(38,0),
                                                SAL_ANIO_EXP NUMBER(4,0),
                                                SAL_NUMERO_EXP NUMBER(38,0),
                                                SAL_OFICINA NUMBER(10,0),
                                                SAL_FECHA TIMESTAMP (6),
                                                SAL_CODIGO VARCHAR2(10 CHAR),
                                                SAL_OBJETO NUMBER(38,0),
                                                SAL_RN NUMBER(*,0),
                                                SAL_FECHAPROCESO TIMESTAMP NOT NULL ENABLE,
                                                SAL_NUMERO_DE_EJECUCION INT,
                                                SAL_NUMERO_ESTADISTICA INT,
                                                SAL_ACTUACION NUMBER(38,0),
                                                SAL_RADICACION VARCHAR2(10),
                                                SAL_REFERENCIA_INGRESADO INT,
                       CONSTRAINT CP_SALIDOS PRIMARY KEY (SAL_CLAVE),
                       CONSTRAINT UQ_VIEJA_CLAVE_SALIDOS UNIQUE (SAL_IDEXP, SAL_FECHA, SAL_CODIGO, SAL_OFICINA, SAL_RN, SAL_NUMERO_DE_EJECUCION),
                       CONSTRAINT CF_SALIDOS_A_TOTALA FOREIGN KEY (SAL_REFERENCIA_INGRESADO) REFERENCES EST_TOTAL_A(TA_CLAVE))';

    execute immediate 'create or replace trigger tr_inserta_clave_SALIDOS
                       for insert
                       on EST_SALIDOS
                       compound trigger
                              filas int := 0;
                              numero_estadistica int := 0;
                              function Cuenta_Cantidad return int is
                                  PRAGMA AUTONOMOUS_TRANSACTION;
                                  cant int := 0;
                              begin
                                  select nvl(max(SAL_CLAVE), 0) into cant from EST_SALIDOS;
                                  return cant;
                              end Cuenta_Cantidad;
                       before each row is 
                          begin
                              if :new.SAL_CLAVE is not null then
                                  raise_application_error(-20023,''No se puede asignar manualmente un valor a la columna SAL_CLAVE.'');
                              end if;
                              filas := filas + 1;
                              :new.SAL_CLAVE := Cuenta_Cantidad + filas;
                          end before each row;
                       end tr_inserta_clave_SALIDOS;';

    execute immediate 'CREATE TABLE EST_LOG(ANT_IDE NUMBER(38,0),
                                            IDE NUMBER(38,0),
                                            ANT_FECHA TIMESTAMP (6),
                                            FECHA TIMESTAMP (6),
                                            ID_ACT NUMBER,
                                            ANT_OFI NUMBER(10,0),
                                            OFI NUMBER(*,0),
                                            RN_ANT NUMBER(*,0),
                                            RN NUMBER(*,0),
                                            NUMFILA NUMBER,
                                            FECHA_DE_EJECUCION TIMESTAMP (6),
                                            NUMERO_DE_EJECUCION INT)';

    execute immediate 'CREATE TABLE EST_DURACION_PROCESO(CAMARA NUMBER(2),
                                                         NOMBRE_PROCESO VARCHAR2(30),
                                                         INICIO_PROCESO TIMESTAMP(6),
                                                         FIN_PROCESO TIMESTAMP(6),
                                                         DURACION_PROCESO INT)';

    execute immediate 'CREATE TABLE EST_CODIGOS_SALIDA(CAMARA INT,
                                                       CODIGO VARCHAR(3))';

    execute immediate 'CREATE TABLE EST_ERRORES(PROBLEMA VARCHAR2(4000 BYTE),
                                                NUMERO_SECUENCIA INT NOT NULL,
                                                PROCESO VARCHAR2(30 BYTE) NOT NULL,
                                                FECHA TIMESTAMP(6) NOT NULL ENABLE)';

    execute immediate 'create sequence est_secFechaProceso
                       start with 1
                       increment by 1
                       minvalue 1
                       nocycle';

    execute immediate 'CREATE OR REPLACE TRIGGER "disparador_fechaProcesosCP"
                          BEFORE INSERT ON EST_EJECUCIONES
                          FOR EACH ROW
                       BEGIN
                          select est_secFechaProceso.nextval into :NEW.N_EJECUCION from dual;
                       END;';

    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''196'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ACU'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ARC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''CDM'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''DES'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''DEV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''DFD'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''DIC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ETR'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''FII'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''HDT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''REB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''SCA'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''SOB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''PRE'')';


/* LOS ANTIGUOS CÓDIGOS DE SQLSERVER, MULTIBASE */
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''196'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ACU'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ARC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''CDM'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DES'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DEV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DFD'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DIC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DIM'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DIT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ETO'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ETR'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''FII'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''HDT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SCA'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''PRE'')';

/* CÓDIGOS ACTUALES QUE ESTÁN USANDO EN LEX 100 */
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ARE'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ACV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ACP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ACB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ARS'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ACT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''AHC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''AHR'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DFD'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''RTN'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''HDT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DEV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ETO'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''EPL'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''EXP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''RCF'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''RCI'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SCA'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SOP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SUT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SIV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SMC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SME'')';


    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''196'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ACU'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ARC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''CDM'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DES'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DEV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DFD'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DIC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DIM'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DIT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ETO'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ETR'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''FII'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''HDT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''SCA'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''PRE'')';
    commit;
exception
    when others then
      --DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.format_error_stack);
      est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
end est_proc_crear_modelo;