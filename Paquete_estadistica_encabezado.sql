create or replace package est_paquete as
    type reg_est_salidos is record(
        radicacion varchar2(10),
        actuacion number(38),
        anio_exp number(38),
        codigo varchar2(10),
        fecha timestamp,
        fecha_proceso timestamp,
        idexp number(38),
        numero_exp number(38),
        objeto number(38),
        oficina number(38),
        rn number(38),
        tipo_de_dato number(1));
  
    /* Tipo para guardar los registros del cursor del total a */
    type reg_cursor_tota is record(
        TA_IDEXP	NUMBER(10,0),
        TA_RN	NUMBER(3,0),
        TA_ANIO_EXP	NUMBER(10,0),
        TA_NUMERO_EXP	NUMBER(10,0),
        TA_OFICINA NUMBER(10,0),
        TA_FECHA timestamp,
        TA_CODIGO	VARCHAR2(10 BYTE),
        TA_OBJETO	NUMBER(10,0),
        TA_FINALIZO NUMBER(1,0),
        TA_IDCAMBIO NUMBER(10,0),
        TA_TABLAORIGEN VARCHAR2(30 BYTE),
        TA_TIPO_DE_DATO	NUMBER(1,0),
        TA_FECHA_PROCESO timestamp,
        TA_CAMARA NUMBER(2));
  
  /* Cursor para recorrer todos los ingresos y buscar salidas entre ellos */
    cursor cursor_salidos(n_ejecucion int, id_camara int) is
    select TA_IDEXP, TA_RN, TA_ANIO_EXP, TA_NUMERO_EXP, TA_OFICINA, TA_FECHA, TA_CODIGO, TA_OBJETO, TA_FINALIZO,
           TA_IDCAMBIO, TA_TABLAORIGEN, TA_TIPO_DE_DATO, TA_FECHA_PROCESO, TA_NUMERO_DE_EJECUCION
    from EST_TOTAL_A
    where TA_NUMERO_DE_EJECUCION = n_ejecucion -- si tengo mas de una ejecución del proceso, quiero la última
    and   ta_finalizo = 1 -- quiero solo las causas que siguen activas
    and   ta_camara = id_camara -- para poder variar la cámara por ejemplo entre instrucción y federal
    order by ta_idexp, ta_fecha;
    v_numero_de_ejecucion int;

    procedure saldo_al_inicio(v_fechahasta in timestamp, id_cam in int);
    procedure ingresados(v_fechaDesde in timestamp, v_fechahasta in timestamp, id_cam in int);
    procedure reingresados(v_fechaDesde in timestamp, v_fechahasta in timestamp, id_cam in int);
    procedure calcula_salidos(finPeriodo in timestamp, id_cam in number);
    function f_gestiona_salidas(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_camara in number, finDePeriodo in timestamp, v_FECHA_DE_EJECUCION in timestamp, nroFila in int) return int;
    function f_busca_la_salida(idexp in int, fechaDesde in timestamp, fechaHasta in timestamp, oficina in int, id_cam in number, reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, filaActual in int, fechaDelProceso in timestamp) return int;
    procedure inserta_salida(registro in reg_est_salidos, reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_actuacion in number, filaActual in int, fechaProceso in timestamp);
    procedure inserta_log(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_actuacion in number, filaActual in int, fechaProceso in timestamp);
    procedure inserta_error(m_error in varchar2, nombre_proceso in varchar2);
    function f_gestiona_ultima_salida(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_camara in number, finDePeriodo in timestamp, v_FECHA_DE_EJECUCION in timestamp, nroFila in int) return int;
    procedure inserta_duracion_procesos(camara in int, nombre in varchar2, inicio in timestamp, fin in timestamp);
end est_paquete;