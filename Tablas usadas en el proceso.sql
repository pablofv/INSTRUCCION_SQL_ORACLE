CREATE TABLE est_fecha_de_procesos(
  FECHA TIMESTAMP(6),
  N_EJECUCION INT,
  CAMARA NUMBER(2),
  NUMERO_ESTADISTICA INT,
  CONSTRAINT "CP_fechaDeProcesos" PRIMARY KEY ("N_EJECUCION")
  );


CREATE TABLE EST_TOTAL_A(
    TA_CLAVE INT NOT NULL,
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
    CONSTRAINT UQ_VIEJA_CLAVE_INGRESOS UNIQUE ("TA_IDEXP", "TA_OFICINA", "TA_RN", "TA_TIPO_DE_DATO", "TA_NUMERO_DE_EJECUCION"),
    CONSTRAINT UQ_ID_TABLA_PROVEEDORA UNIQUE("TA_IDTABLAORIGEN", "TA_TABLAORIGEN", "TA_NUMERO_DE_EJECUCION")
    );

/*  FALTA LA EXPLICACI�N DEL DESENCADENADOR */
create or replace trigger tr_inserta_clave_TOTAL_A
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
          raise_application_error(-20023,'No se puede asignar manualmente un valor a la columna TA_CLAVE.');
      end if;
      select nvl(count(*), 0) into numero_estadistica from est_fecha_de_procesos where NUMERO_ESTADISTICA = :new.TA_NUMERO_ESTADISTICA;
      if (numero_estadistica = 0) then
          raise_application_error(-20024,'No existe el n�mero de estad�stica en la tabla est_fecha_de_procesos.');
      end if;
      filas := filas + 1;
      :new.TA_CLAVE := Cuenta_Cantidad + filas;
  end before each row;
end tr_inserta_clave_TOTAL_A;


CREATE TABLE EST_SALIDOS(
    SAL_CLAVE INT,
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
    CONSTRAINT CF_SALIDOS_A_TOTALA FOREIGN KEY (SAL_REFERENCIA_INGRESADO) REFERENCES EST_TOTAL_A(TA_CLAVE)
    );

create or replace trigger tr_inserta_clave_SALIDOS
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
          raise_application_error(-20023,'No se puede asignar manualmente un valor a la columna SAL_CLAVE.');
      end if;
      select nvl(count(*), 0) into numero_estadistica from est_fecha_de_procesos where NUMERO_ESTADISTICA = :new.SAL_NUMERO_ESTADISTICA;
      if (numero_estadistica = 0) then
          raise_application_error(-20024,'No existe el n�mero de estad�stica en la tabla est_fecha_de_procesos.');
      end if;
      filas := filas + 1;
      :new.SAL_CLAVE := Cuenta_Cantidad + filas;
  end before each row;
end tr_inserta_clave_SALIDOS;


CREATE TABLE EST_LOG(
    ANT_IDE NUMBER(38,0),
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
    NUMERO_DE_EJECUCION INT);


CREATE TABLE EST_DURACION_PROCESO(
    CAMARA NUMBER(2),
    NOMBRE_PROCESO VARCHAR2(30),
    INICIO_PROCESO TIMESTAMP(6),
    FIN_PROCESO TIMESTAMP(6),
    DURACION_PROCESO INT);


CREATE TABLE EST_CODIGOS_SALIDA(
    CAMARA INT,--ES EL ID DE LA CAMARA QUE TIENE ESTE C�DIGO DE SALIDA
    CODIGO VARCHAR(3));

CREATE TABLE EST_ERRORES(
  PROBLEMA VARCHAR2(4000 BYTE),
	NUMERO_SECUENCIA INT NOT NULL,
	PROCESO VARCHAR2(30 BYTE) NOT NULL,
	FECHA TIMESTAMP(6) NOT NULL ENABLE);




create sequence "est_secFechaProceso"
  start with 1
  increment by 1
  minvalue 1
  nocycle;


CREATE OR REPLACE TRIGGER "disparador_fechaProcesosCP"
  BEFORE INSERT ON est_fecha_de_procesos
  FOR EACH ROW
BEGIN
    select "est_secFechaProceso".nextval into :NEW.N_EJECUCION from dual;
END;

/*
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, '196');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'ACU');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'ARC');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'CDM');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'DES');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'DEV');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'DFD');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'DIC');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'ETR');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'FII');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'HDT');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'REB');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'SCA');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'SOB');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (8, 'PRE');


INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, '196');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'ACU');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'ARC');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'CDM');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'DES');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'DEV');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'DFD');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'DIC');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'DIM');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'DIT');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'ETO');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'ETR');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'FII');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'HDT');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'SCA');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (9, 'PRE');


INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, '196');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'ACU');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'ARC');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'CDM');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'DES');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'DEV');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'DFD');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'DIC');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'DIM');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'DIT');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'ETO');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'ETR');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'FII');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'HDT');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'SCA');
INSERT INTO EST_CODIGOS_SALIDA (CAMARA, CODIGO) VALUES (15, 'PRE');
*/

-- Agreg� los DROP a las tablas para poder generar nuevamente el modelo

/*
drop table EST_SALIDOS;
drop table EST_LOG;
drop table EST_DURACION_PROCESO;
drop table EST_CODIGOS_SALIDA;
drop table EST_ERRORES;
drop table est_fecha_de_procesos;
drop table EST_TOTAL_A;
*/