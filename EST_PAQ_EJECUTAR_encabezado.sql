CREATE OR REPLACE PACKAGE EST_PAQ_EJECUTAR AS
    n_estadistica int;
    function periodo_inmediato_anterior (f_desde in timestamp, p_CAMARA in int) return boolean;
    function ejecutar_proceso(f_desde in timestamp, f_hasta in timestamp, CAMARA in int) return int;
END EST_PAQ_EJECUTAR;