CREATE OR REPLACE PACKAGE EST_PAQ_EJECUTAR AS
    n_estadistica int;
    function ejecutar_proceso(f_desde in timestamp, f_hasta in timestamp, CAMARA in int) return int;
END EST_PAQ_EJECUTAR;