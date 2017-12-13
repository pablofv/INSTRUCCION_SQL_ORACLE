create or replace package est_paquete_penal_economico as
    N_CAMARA NUMBER(2) := 6;
    -- p_e_ssi -> penal económico sin saldo inicial
    -- p_e_csi -> penal económico con saldo inicial
    procedure calcular_estadistica_p_e_ssi(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy'));
    procedure calcular_estadistica_p_e_csi(desde in timestamp default to_timestamp('01/01/2012', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2012', 'dd/mm/yyyy'));
end est_paquete_penal_economico;