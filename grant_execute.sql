-- ═══════════════════════════════════════════════════════════════
-- GRANT EXECUTE — Ejecutar en Supabase SQL Editor
-- Esto permite que el rol anon (frontend) llame a todas las funciones RPC
-- ═══════════════════════════════════════════════════════════════

-- Usuarios
GRANT EXECUTE ON FUNCTION public.fn_login(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_listar_usuarios() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_crear_usuario(text, text, text, text, text, rol_usuario, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_actualizar_usuario(uuid, text, text, text, rol_usuario, text, text, boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_eliminar_usuario(uuid) TO anon;

-- Clientes
GRANT EXECUTE ON FUNCTION public.fn_listar_clientes() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_crear_cliente(text, text, text, text, text, text, text, text, text, text, boolean, boolean, boolean, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_actualizar_cliente(uuid, text, text, text, text, text, text, text, text, text, text, boolean, boolean, boolean, text, boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_eliminar_cliente(uuid) TO anon;

-- Motovehículos
GRANT EXECUTE ON FUNCTION public.fn_listar_motos(text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_crear_moto(text, text, text, integer, text, text, text, text, integer, text, numeric, numeric, numeric, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_actualizar_moto(uuid, text, text, text, integer, text, text, text, text, integer, text, numeric, numeric, numeric, text, text, boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_eliminar_moto(uuid) TO anon;

-- Contratos
GRANT EXECUTE ON FUNCTION public.fn_listar_contratos(text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_crear_contrato(uuid, uuid, date, integer, numeric, numeric, integer, numeric, numeric, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_actualizar_contrato(uuid, text, numeric, text) TO anon;

-- Inventario
GRANT EXECUTE ON FUNCTION public.fn_inventario_alquiler() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_inventario_deposito() TO anon;

-- Dashboard
GRANT EXECUTE ON FUNCTION public.fn_dashboard_stats() TO anon;

-- Cobranza / Pagos
GRANT EXECUTE ON FUNCTION public.fn_listar_pagos(text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_crear_pago(uuid, uuid, text, numeric, text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_actualizar_pago(uuid, text) TO anon;

-- Scoring / KYC
GRANT EXECUTE ON FUNCTION public.fn_listar_scoring() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_actualizar_scoring(uuid, integer, text, boolean, boolean, boolean, boolean, boolean) TO anon;

-- Gestoría / Trámites
GRANT EXECUTE ON FUNCTION public.fn_listar_tramites(text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_crear_tramite(uuid, uuid, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_actualizar_tramite(uuid, text, text, text, text, text, text, text) TO anon;

-- Ventas
GRANT EXECUTE ON FUNCTION public.fn_listar_ventas(text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_crear_venta(uuid, uuid, uuid, text, numeric, numeric, numeric, integer, numeric, numeric, text, boolean, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_actualizar_venta(uuid, text, text) TO anon;

-- Contabilidad
GRANT EXECUTE ON FUNCTION public.fn_resumen_contable(integer, integer) TO anon;

-- Cuotas
GRANT EXECUTE ON FUNCTION public.fn_listar_cuotas(uuid) TO anon;

-- ═══ FIN ═══
SELECT 'Todos los GRANT EXECUTE aplicados correctamente' AS resultado;
