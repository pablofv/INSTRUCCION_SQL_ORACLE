create or replace package est_paquete_camaras_interior as
    N_CAMARA NUMBER(2);-- := 13;
    procedure calcular_estadistica(desde in timestamp, hasta in timestamp, camara in int);
--    procedure eliminarAnterioresA2008;
    procedure eliminarFalsasAsignaciones;
end est_paquete_camaras_interior;