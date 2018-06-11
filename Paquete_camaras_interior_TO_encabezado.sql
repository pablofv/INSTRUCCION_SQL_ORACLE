create or replace package est_paquet_camaras_interior_TO as
    N_CAMARA NUMBER(2);-- := 13;
    procedure calcular_estadistica(desde in timestamp, hasta in timestamp, camara in int);
--    procedure eliminarAnterioresA2008;
    procedure eliminarFalsasAsignaciones;
end est_paquet_camaras_interior_TO;