create or replace package est_paquete_penal_economico as
    N_CAMARA NUMBER(2) := 6;
    procedure calcular_estadistica_p_econ(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy'));
    procedure eliminarAnterioresA2008;
    procedure eliminarFalsasAsignaciones;
end est_paquete_penal_economico;