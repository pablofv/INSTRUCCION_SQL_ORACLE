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
        -- lo ordeno por id descendente, primero quedar� salidos y luego total a, con lo cual primero borrar� salidos, y luego si podr� borrar la otra.
        select *
        BULK COLLECT INTO v_tablas
        from user_objects
        where upper(object_name) in ('EST_SALIDOS', 'EST_DURACION_PROCESO', 'EST_CODIGOS_SALIDA', 'EST_CAMBIO_ASIGNACION_EXP', 'EST_SECFECHAPROCESO',
                                     'EST_ACTUACION_EXP', 'EST_EJECUCIONES', 'EST_VARIABLE_ESTADISTICA', 'EST_TOTAL_A', 'EST_LOG', 'EST_ERRORES')
        order by Object_Id desc;
        if v_tablas.last > 0 then -- encontr� objetos creados
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

    -- Tabla para usar de variable, con un n�mero que representa el n�mero de estad�stica actual. Comenzar� en 0, para que al hacer la primer estad�stica, se incremente a uno.
    execute immediate 'CREATE TABLE EST_VARIABLE_ESTADISTICA(VE_VALOR INT,
                                                             VE_CAMARA INT
                                                             )';
    execute immediate 'INSERT INTO EST_VARIABLE_ESTADISTICA (VE_VALOR, VE_CAMARA) VALUES (0, 6)';
    execute immediate 'INSERT INTO EST_VARIABLE_ESTADISTICA (VE_VALOR, VE_CAMARA) VALUES (0, 8)';
    execute immediate 'INSERT INTO EST_VARIABLE_ESTADISTICA (VE_VALOR, VE_CAMARA) VALUES (0, 9)';
    execute immediate 'INSERT INTO EST_VARIABLE_ESTADISTICA (VE_VALOR, VE_CAMARA) VALUES (0, 15)';

    execute immediate 'CREATE TABLE EST_EJECUCIONES(FECHA_PROCESO TIMESTAMP(6),
                                                    N_EJECUCION INT,
                                                    CAMARA NUMBER(2),
                                                    NUMERO_ESTADISTICA INT NOT NULL,
                                                    FECHA_DESDE TIMESTAMP,
                                                    FECHA_HASTA TIMESTAMP,
                                                    CONSTRAINT "CP_fechaDeProcesos" PRIMARY KEY ("N_EJECUCION")
                                                    )';

    execute immediate 'create table est_cambio_asignacion_exp(tablaDesde int,
                                                              id_expediente int,
                                                              id_oficina int,
                                                              id_secretaria int,
                                                              fecha_asignacion timestamp,
                                                              codigo_tipo_cambio_asignacion varchar2(3 byte),
                                                              id_cambio_asignacion_exp int,
                                                              n_fila int,
                                                              anio_exp int,
                                                              numero_exp int,
                                                              CONSTRAINT CP_EST_CAMBIO PRIMARY KEY (tablaDesde, id_cambio_asignacion_exp)
                                                              )';
    execute immediate 'comment on column est_cambio_asignacion_exp.tablaDesde is ''De donde proviene el dato: 1 => cambio; 2 = Actuaci�n.''';
    execute immediate 'create index uq_fecha_asignacion on est_cambio_asignacion_exp(fecha_asignacion)';

    execute immediate 'CREATE TABLE est_actuacion_exp(ORIGEN_DATO VARCHAR2(16 BYTE),
                                                      NUM_CONSULTA INTEGER,
                                                      RADICACION VARCHAR2(10 CHAR),
                                                      ID_ACTUACION_EXP NUMBER(10,0),
                                                      FECHA_ACTUACION TIMESTAMP (6),
                                                      ID_OFICINA INTEGER,
                                                      CODIGO VARCHAR2(10 CHAR),
                                                      ID_EXPEDIENTE INTEGER,
                                                      ID_EXPEDIENTE_ORIGEN INTEGER,
                                                      CONSTRAINT CP_est_actuacion PRIMARY KEY (num_consulta, id_actuacion_exp)
                                                      )';
    execute immediate 'comment on column est_actuacion_exp.num_consulta is ''El n�mero del select de donde provino el dato.''';
    execute immediate 'create index uq_fecha_actuacion on est_actuacion_exp(FECHA_ACTUACION)';

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

    execute immediate 'comment on column EST_TOTAL_A.TA_FINALIZO is ''Estado del expediente: 0 = est� finalizado; 1 = continua en tr�mite.''';
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

    execute immediate 'create unique index uq_fk_entre_las_tablas on est_salidos(sal_referencia_ingresado)';

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

/* C�DIGOS QUE EST�N CALCULADOS EN SQL SERVER, EL HDT FIGURA EN LOS PROCESOS, PERO NO HAY NINGUNA CAUSA, NO SE SI PORQUE NO SE US� REALMENTE O SIMPLEMENTE PORQUE NO HAY CAUSAS CON ESE C�DIGO */
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ACU'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ARC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''CDM'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''DES'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''DEV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''DFD'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''DIC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ETO'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ETR'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''FII'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''HDT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''REB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''SCA'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''SOB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''PRE'')';


/* LOS ANTIGUOS C�DIGOS DE SQLSERVER, MULTIBASE */
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

/* C�DIGOS ACTUALES QUE EST�N USANDO EN LEX 100 */
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ARE'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ACV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ACP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ACB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ARS'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ACT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''AHC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''AHR'')';
--    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DFD'')'; REPETIDO
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''RTN'')';
--    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''HDT'')'; REPETIDO
--    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''DEV'')'; REPETIDO
--    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''ETO'')'; REPEDITO
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''EPL'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''EXP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''RCF'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''RCI'')';
--    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SCA'')'; REPETIDO
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SOP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SUT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SIV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SMC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, ''SME'')';

/* C�MARAS FEDERALES, TODAS CON LOS MISMOS C�DIGOS */
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ACU'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ARC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''CDM'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DES'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DEV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DFD'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''DIC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ETO'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ETR'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''FII'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''HDT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''SCA'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''SOB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''PRE'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''REB'')';

/* LOS C�DIGOS QUE NOS INDICARON EN INSTRUCCI�N QUE EST�N USANDO PARA FINALIZAR CAUSAS, SE LOS AGREGO TAMBI�N A FEDERAL */
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ARE'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ACV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ACP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ACB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ARS'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''ACT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''AHC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''AHR'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''RTN'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''EPL'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''EXP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''RCF'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''RCI'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''SOP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''SUT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''SIV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''SMC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, ''SME'')';

/* Y TAMBI�N A PENAL ECON�MICO */
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''ARE'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''ACV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''ACP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''ACB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''ARS'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''ACT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''AHC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''AHR'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''RTN'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''EPL'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''EXP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''RCF'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''RCI'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''SOP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''SUT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''SIV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''SMC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (6, ''SME'')';
/* Y C�RDOBA */
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ARE'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ACV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ACP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ACB'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ARS'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''ACT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''AHC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''AHR'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''RTN'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''EPL'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''EXP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''RCF'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''RCI'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''SOP'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''SUT'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''SIV'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''SMC'')';
    execute immediate 'INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, ''SME'')';
    commit;
exception
    when others then
      DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.format_error_stack);
      --est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
end est_proc_crear_modelo;