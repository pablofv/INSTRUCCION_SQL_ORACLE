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
        tipo_de_dato number(1),
        id_ingresado int);
  
    /* Tipo para guardar los registros del cursor del total a */
  /*  type reg_cursor_tota is record(
        TA_IDEXP	NUMBER(10,0),
        TA_RN	NUMBER(3,0),
        TA_ANIO_EXP	NUMBER(10,0),
        TA_NUMERO_EXP	NUMBER(10,0),
        TA_OFICINA NUMBER(10,0),
        TA_FECHA timestamp,
        TA_CODIGO	VARCHAR2(10 BYTE),
        TA_OBJETO	NUMBER(10,0),
        TA_FINALIZO NUMBER(1,0),
        TA_IDTABLAORIGEN NUMBER(10,0),
        TA_TABLAORIGEN VARCHAR2(30 BYTE),
        TA_TIPO_DE_DATO	NUMBER(1,0),
        TA_FECHA_PROCESO timestamp,
        TA_NUMERO_ESTADISTICA NUMBER(38,0),
        TA_MATERIA NUMBER(38,0),
        TA_CAMARA NUMBER(2));*/
    /* Vector con las materias penales */
    type materias IS VARRAY(5) OF INTEGER;
    mp materias := materias(8, 9, 11, 13);-- si cambian la cantidad de materias hay que cambiar el �ndice donde se usa el vector  
  
    /* Cursor para recorrer todos los ingresos y buscar salidas entre ellos */
    cursor cursor_salidos(n_estadistica int, id_camara int) is
    select *
    from EST_TOTAL_A
    where TA_NUMERO_ESTADISTICA = n_estadistica -- si tengo mas de una ejecuci�n del proceso, quiero la �ltima
    and   ta_finalizo = 1 -- quiero solo las causas que siguen activas
    and   ta_camara = id_camara -- para poder variar la c�mara por ejemplo entre instrucci�n y federal
    order by ta_idexp, ta_fecha;
    v_numero_de_ejecucion int;
    v_numero_estadistica int;

    procedure generar_est_cambio_asignacion(v_fechaDesde in timestamp, v_fechaHasta in timestamp, id_cam in int);
    procedure generar_est_actuacion_exp(v_fechaDesde in timestamp, v_fechaHasta in timestamp, id_cam in int);
    procedure saldo_al_inicio(v_fechahasta in timestamp, id_cam in int);
    procedure saldo_multibase(v_camara in int, v_numero_ejecucion in int, v_numero_estadistica in int);
    procedure ingresados_y_reingresados(v_fechaDesde in timestamp, v_fechahasta in timestamp, id_cam in int);
    procedure agrego_delito(id_cam in int);
    procedure calcula_salidos(finPeriodo in timestamp, id_cam in number);
    function f_gestiona_salidas(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_camara in number, finDePeriodo in timestamp, v_FECHA_DE_EJECUCION in timestamp, nroFila in int) return int;
    function f_busca_la_salida(idexp in int, fechaDesde in timestamp, fechaHasta in timestamp, oficina in int, id_cam in number, reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, filaActual in int, fechaDelProceso in timestamp) return int;
    procedure inserta_salida(registro in reg_est_salidos, reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_actuacion in number, filaActual in int, fechaProceso in timestamp);
    procedure inserta_log(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_actuacion in number, filaActual in int, fechaProceso in timestamp);
    procedure inserta_error(m_error in varchar2, nombre_proceso in varchar2);
    function f_gestiona_ultima_salida(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_camara in number, finDePeriodo in timestamp, v_FECHA_DE_EJECUCION in timestamp, nroFila in int) return int;
    procedure inserta_duracion_procesos(camara in int, nombre in varchar2, inicio in timestamp, fin in timestamp);
    procedure dejarMateriasPenales(camara in int);
end est_paquete;