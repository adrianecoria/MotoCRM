-- ═══════════════════════════════════════════════════════════════
-- FUNCIONES DE COBRANZA — Ejecutar en Supabase SQL Editor
-- Incluye: modificación de fn_crear_contrato para auto-generar cuotas semanales
-- y nuevas funciones para el módulo de Cobranza
-- ═══════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════
-- 1. MODIFICAR fn_crear_contrato para auto-generar cuotas semanales
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.fn_crear_contrato(
  p_cliente_id uuid,
  p_vehiculo_id uuid,
  p_fecha_inicio date,
  p_plazo_meses integer,
  p_valor_activo numeric,
  p_anticipo numeric,
  p_cantidad_cuotas integer,
  p_valor_cuota numeric,
  p_opcion_compra_valor numeric DEFAULT NULL,
  p_notas text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_contrato_id uuid;
  v_numero text;
  v_fecha_fin date;
  i integer;
BEGIN
  -- Verificar que el vehículo esté disponible
  IF NOT EXISTS (SELECT 1 FROM vehiculos WHERE id = p_vehiculo_id AND estado = 'en_salon') THEN
    RETURN json_build_object('ok', false, 'error', 'El vehículo no está disponible para alquiler');
  END IF;

  -- Generar número de contrato
  SELECT 'ALQ-' || LPAD((COALESCE(MAX(CAST(SUBSTRING(numero_contrato FROM 5) AS integer)), 0) + 1)::text, 5, '0')
  INTO v_numero
  FROM contratos_alquiler
  WHERE numero_contrato LIKE 'ALQ-%';

  -- Calcular fecha fin estimada (semanas)
  v_fecha_fin := p_fecha_inicio + (p_cantidad_cuotas * 7);

  -- Crear contrato
  INSERT INTO contratos_alquiler (
    numero_contrato, cliente_id, vehiculo_id, fecha_inicio, fecha_fin_estimada,
    plazo_meses, valor_activo, anticipo, cantidad_cuotas, valor_cuota,
    opcion_compra_valor, notas, estado
  ) VALUES (
    v_numero, p_cliente_id, p_vehiculo_id, p_fecha_inicio, v_fecha_fin,
    p_plazo_meses, p_valor_activo, p_anticipo, p_cantidad_cuotas, p_valor_cuota,
    p_opcion_compra_valor, p_notas, 'activo'
  ) RETURNING id INTO v_contrato_id;

  -- Actualizar estado del vehículo a "alquilado"
  UPDATE vehiculos SET estado = 'alquilado', updated_at = NOW() WHERE id = p_vehiculo_id;

  -- ═══ AUTO-GENERAR CUOTAS SEMANALES ═══
  FOR i IN 1..p_cantidad_cuotas LOOP
    INSERT INTO cuotas_alquiler (
      contrato_id, numero_cuota, fecha_vencimiento,
      monto_original, monto_mora, monto_total, estado
    ) VALUES (
      v_contrato_id,
      i,
      p_fecha_inicio + (i * 7),  -- cada 7 días
      p_valor_cuota,
      0,
      p_valor_cuota,
      'pendiente'
    );
  END LOOP;

  RETURN json_build_object('ok', true, 'id', v_contrato_id, 'numero', v_numero, 'cuotas_generadas', p_cantidad_cuotas);
END;
$$;

-- ══════════════════════════════════════════════
-- 2. FUNCIÓN: Cuotas pendientes de cobranza (con datos de cliente/moto)
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.fn_cobranza_pendientes()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_agg(row_to_json(t)) INTO v_result
  FROM (
    SELECT
      cu.id,
      cu.contrato_id,
      cu.numero_cuota,
      cu.fecha_vencimiento,
      cu.monto_original,
      cu.monto_mora,
      cu.monto_total,
      cu.estado::text as cuota_estado,
      cu.fecha_pago,
      co.numero_contrato,
      co.cantidad_cuotas,
      co.valor_cuota,
      co.fecha_inicio,
      co.estado::text as contrato_estado,
      cl.id as cliente_id,
      cl.nombre || ' ' || cl.apellido as cliente_nombre,
      cl.cuit as cliente_cuit,
      cl.dni as cliente_dni,
      cl.telefono as cliente_telefono,
      v.marca || ' ' || v.modelo as moto_descripcion,
      v.patente as moto_patente,
      EXTRACT(EPOCH FROM (cu.fecha_vencimiento::timestamp - NOW())) / 3600 as horas_para_vencer
    FROM cuotas_alquiler cu
    JOIN contratos_alquiler co ON cu.contrato_id = co.id
    JOIN clientes cl ON co.cliente_id = cl.id
    JOIN vehiculos v ON co.vehiculo_id = v.id
    WHERE cu.estado IN ('pendiente', 'en_mora', 'vencida')
      AND co.estado = 'activo'
    ORDER BY cu.fecha_vencimiento ASC, cu.numero_cuota ASC
  ) t;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- ══════════════════════════════════════════════
-- 3. FUNCIÓN: Cuotas acreditadas (pagadas)
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.fn_cobranza_acreditados()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_agg(row_to_json(t)) INTO v_result
  FROM (
    SELECT
      cu.id,
      cu.contrato_id,
      cu.numero_cuota,
      cu.fecha_vencimiento,
      cu.monto_original,
      cu.monto_total,
      cu.estado::text as cuota_estado,
      cu.fecha_pago,
      co.numero_contrato,
      co.cantidad_cuotas,
      cl.nombre || ' ' || cl.apellido as cliente_nombre,
      cl.cuit as cliente_cuit,
      cl.dni as cliente_dni,
      v.marca || ' ' || v.modelo as moto_descripcion,
      v.patente as moto_patente
    FROM cuotas_alquiler cu
    JOIN contratos_alquiler co ON cu.contrato_id = co.id
    JOIN clientes cl ON co.cliente_id = cl.id
    JOIN vehiculos v ON co.vehiculo_id = v.id
    WHERE cu.estado = 'pagada'
    ORDER BY cu.fecha_pago DESC NULLS LAST
  ) t;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- ══════════════════════════════════════════════
-- 4. FUNCIÓN: Cuotas rechazadas / anuladas
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.fn_cobranza_rechazados()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_agg(row_to_json(t)) INTO v_result
  FROM (
    SELECT
      cu.id,
      cu.contrato_id,
      cu.numero_cuota,
      cu.fecha_vencimiento,
      cu.monto_original,
      cu.monto_total,
      cu.estado::text as cuota_estado,
      co.numero_contrato,
      co.cantidad_cuotas,
      cl.nombre || ' ' || cl.apellido as cliente_nombre,
      cl.cuit as cliente_cuit,
      cl.dni as cliente_dni,
      v.marca || ' ' || v.modelo as moto_descripcion,
      v.patente as moto_patente
    FROM cuotas_alquiler cu
    JOIN contratos_alquiler co ON cu.contrato_id = co.id
    JOIN clientes cl ON co.cliente_id = cl.id
    JOIN vehiculos v ON co.vehiculo_id = v.id
    WHERE cu.estado = 'anulada'
    ORDER BY cu.fecha_vencimiento DESC
  ) t;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- ══════════════════════════════════════════════
-- 5. FUNCIÓN: Todas las cuotas
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.fn_cobranza_todas()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_agg(row_to_json(t)) INTO v_result
  FROM (
    SELECT
      cu.id,
      cu.contrato_id,
      cu.numero_cuota,
      cu.fecha_vencimiento,
      cu.monto_original,
      cu.monto_mora,
      cu.monto_total,
      cu.estado::text as cuota_estado,
      cu.fecha_pago,
      co.numero_contrato,
      co.cantidad_cuotas,
      cl.nombre || ' ' || cl.apellido as cliente_nombre,
      cl.cuit as cliente_cuit,
      cl.dni as cliente_dni,
      v.marca || ' ' || v.modelo as moto_descripcion,
      v.patente as moto_patente
    FROM cuotas_alquiler cu
    JOIN contratos_alquiler co ON cu.contrato_id = co.id
    JOIN clientes cl ON co.cliente_id = cl.id
    JOIN vehiculos v ON co.vehiculo_id = v.id
    ORDER BY cu.fecha_vencimiento DESC
  ) t;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- ══════════════════════════════════════════════
-- 6. FUNCIÓN: Acreditar (pagar) una cuota
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.fn_acreditar_cuota(
  p_cuota_id uuid,
  p_metodo_pago text DEFAULT 'efectivo',
  p_referencia text DEFAULT ''
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE cuotas_alquiler
  SET estado = 'pagada',
      fecha_pago = CURRENT_DATE,
      updated_at = NOW()
  WHERE id = p_cuota_id AND estado IN ('pendiente', 'en_mora', 'vencida');

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'Cuota no encontrada o ya pagada');
  END IF;

  RETURN json_build_object('ok', true);
END;
$$;

-- ══════════════════════════════════════════════
-- 7. FUNCIÓN: Rechazar/anular una cuota
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.fn_rechazar_cuota(
  p_cuota_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE cuotas_alquiler
  SET estado = 'anulada',
      updated_at = NOW()
  WHERE id = p_cuota_id AND estado IN ('pendiente', 'en_mora', 'vencida');

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'Cuota no encontrada o no se puede anular');
  END IF;

  RETURN json_build_object('ok', true);
END;
$$;

-- ══════════════════════════════════════════════
-- GRANT EXECUTE para todas las funciones nuevas
-- ══════════════════════════════════════════════
GRANT EXECUTE ON FUNCTION public.fn_crear_contrato(uuid, uuid, date, integer, numeric, numeric, integer, numeric, numeric, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_cobranza_pendientes() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_cobranza_acreditados() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_cobranza_rechazados() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_cobranza_todas() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_acreditar_cuota(uuid, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_rechazar_cuota(uuid) TO anon;

SELECT 'Todas las funciones de cobranza creadas y permisos otorgados' AS resultado;
