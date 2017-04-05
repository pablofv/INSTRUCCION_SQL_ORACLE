CREATE OR REPLACE PACKAGE EST_PAQ_EJECUTAR AS 
    function ejecutar_proceso(f_desde in timestamp, f_hasta in timestamp, CAMARA in int, quieroRecalcular varchar2, datos_antes_del_inicio in out int) return int;
END EST_PAQ_EJECUTAR;