import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';

/// Default permission catalog for V1.
abstract final class DefaultAccessPermissions {
  /// Permissions available to assign to roles.
  static const values = [
    AccessPermission(code: 'usuarios.gestionar', name: 'Gestionar usuarios'),
    AccessPermission(code: 'roles.gestionar', name: 'Gestionar roles'),
    AccessPermission(code: 'mesas.gestionar', name: 'Gestionar mesas'),
    AccessPermission(code: 'productos.gestionar', name: 'Gestionar productos'),
    AccessPermission(
      code: 'inventario.gestionar',
      name: 'Gestionar inventario',
    ),
    AccessPermission(
      code: 'tipos_venta.gestionar',
      name: 'Gestionar tipos de venta',
    ),
    AccessPermission(
      code: 'empaques.gestionar',
      name: 'Gestionar empaques',
    ),
    AccessPermission(
      code: 'modificadores.gestionar',
      name: 'Gestionar modificadores POS',
    ),
    AccessPermission(code: 'ventas.registrar', name: 'Registrar ventas'),
    AccessPermission(code: 'caja.aperturar', name: 'Aperturar caja'),
    AccessPermission(code: 'caja.cerrar', name: 'Cerrar caja'),
    AccessPermission(
      code: 'gastos.categorias.gestionar',
      name: 'Gestionar categorias de gastos',
    ),
    AccessPermission(
      code: 'gastos.registrar',
      name: 'Registrar gastos operativos',
    ),
    AccessPermission(code: 'pdf.generar', name: 'Generar PDF'),
    AccessPermission(code: 'pagos.gestionar', name: 'Gestionar pagos'),
    AccessPermission(code: 'cuentas.separar', name: 'Separar cuentas'),
    AccessPermission(code: 'ventas.anular', name: 'Anular ventas'),
    AccessPermission(code: 'reportes.ver', name: 'Ver reportes'),
    AccessPermission(
      code: 'configuracion.gestionar',
      name: 'Gestionar configuracion',
    ),
    AccessPermission(
      code: 'tasas.gestionar',
      name: 'Gestionar tasas de cambio',
    ),
    AccessPermission(code: 'auditoria.ver', name: 'Ver auditoria'),
    AccessPermission(code: 'personal.gestionar', name: 'Gestionar personal'),
    AccessPermission(
      code: 'personal.consumos.ver',
      name: 'Ver consumos de personal',
    ),
    AccessPermission(
      code: 'personal.consumos.registrar',
      name: 'Registrar consumos de personal',
    ),
    AccessPermission(
      code: 'personal.adelantos.gestionar',
      name: 'Gestionar adelantos de salario',
    ),
    AccessPermission(code: 'planilla.gestionar', name: 'Gestionar planilla'),
    AccessPermission(
      code: 'reglas_negocio.gestionar',
      name: 'Gestionar reglas del negocio',
    ),
    AccessPermission(code: 'sync.configurar', name: 'Configurar sync'),
    AccessPermission(
      code: 'sync.ejecutar',
      name: 'Ejecutar sincronizacion manual',
    ),
    AccessPermission(
      code: 'dispositivo.inicializar',
      name: 'Inicializar dispositivo',
    ),
    AccessPermission(
      code: 'sistema.reiniciar_operacion',
      name: 'Reiniciar operacion piloto',
    ),
  ];
}
