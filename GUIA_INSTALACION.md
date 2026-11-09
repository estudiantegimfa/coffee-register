# COFFEE REGISTER — MVP web

Proyecto listo para publicar en **GitHub Pages** con **Supabase**. Logo original incluido en `assets/logo.png`.

## Qué funciona

- Registro e inicio de sesión por correo/contraseña; perfiles de estudiante, docente u otro cliente.
- Administrador único con panel, productos, categorías, inventario por unidades, catálogo imprimible, ventas directas, pedidos, compras, proveedores, gastos y reportes CSV.
- Cliente: catálogo, carrito, pedidos con efectivo/transferencia/crédito, historial, solicitud de cupo y consulta de consumos y abonos.
- Administrador: aprobar/rechazar solicitudes, registrar abonos, gestionar estados y confirmar entrega. Las ventas a crédito verifican cupo; compras y ventas modifican stock mediante funciones SQL.
- Protección de filas (RLS) para que cada cliente vea solo su información. Operaciones financieras con funciones SQL de autorización.

## Configuración inicial (solo una vez)

1. Crea una cuenta gratuita en https://supabase.com y un proyecto nuevo. Guarda la contraseña de la base de datos en un lugar seguro.
2. En **SQL Editor**, crea una consulta nueva, pega **todo** `supabase/schema.sql` y ejecútalo con **Run**. Comprueba que no aparezcan errores.
3. En **Project Settings → API** (o **Connect / API Keys**, según versión), copia **Project URL** y la clave pública **anon / publishable**. **NUNCA uses `service_role`, `secret` ni contraseña de base de datos** en el código web.
4. Abre `config.js` en Visual Studio Code y reemplaza los dos marcadores por esos valores públicos. Es normal que esta clave pública aparezca en el repositorio: la protección la hacen RLS y las funciones del servidor.
5. En **Authentication → Providers → Email**, habilita Email. Para probar más rápido, puedes desactivar temporalmente la confirmación de correo **solo con cuentas ficticias**. Para uso real, actívala y configura correctamente el envío de correos.
6. En **Authentication → URL Configuration**, establece la URL de GitHub Pages como **Site URL** y, si corresponde, en **Redirect URLs**. Para correo con confirmación, configura las URL de redirección adecuadas.
7. Crea tu cuenta desde la página **Registrarme** usando tu correo. Luego, en Supabase **SQL Editor**, ejecuta lo siguiente sustituyendo el correo:

   ```sql
   update public.profiles set role='admin' where email='tu_correo@ejemplo.com';
   ```

   **Importante:** ejecuta esta operación solo para tu cuenta; no la incluyas en el frontend. Cierra sesión y vuelve a entrar.
8. Crea algunos productos en **Productos**. Usa **Compras** para agregar unidades de stock. Ya puedes probar ventas y pedidos.

## Publicación en GitHub Pages

1. Crea un repositorio en https://github.com (por ejemplo `coffee-register`).
2. Sube **el contenido** de esta carpeta a la raíz del repositorio: `index.html`, `app.js`, `styles.css`, `config.js`, `assets/`, `supabase/` y esta guía.
3. En el repositorio abre **Settings → Pages → Build and deployment**, selecciona **Deploy from a branch**, rama **main**, carpeta **/(root)** y guarda.
4. Espera a que GitHub publique la web. La URL tendrá el formato `https://TU_USUARIO.github.io/coffee-register/`.
5. Abre la URL desde tu celular. Puedes crear un QR con esa URL y colocarlo en la cafetería.

**No necesitas Node, Flask, Python ni un servidor adicional** para esta versión. El frontend se sirve desde GitHub Pages y las operaciones de datos las atiende Supabase.

## Pruebas rápidas recomendadas

1. Crear cuenta administradora y habilitar su rol mediante SQL.
2. Crear categoría, producto y compra inicial (verifica aumento de stock).
3. Crear una cuenta de cliente distinta y solicitar crédito.
4. Aprobar solicitud desde administración y verificar cupo.
5. Cliente: realizar pedido a crédito; administrador: aceptar → preparar → listo → entregar. Verificar venta, saldo e inventario.
6. Registrar abono y verificar disminución de deuda.
7. Registrar venta de contado sin cliente y gasto.
8. Exportar reportes CSV y probar el catálogo imprimible.
9. Iniciar sesión con un cliente diferente y verificar que **no** pueda ver las compras ni los saldos de otro.

## Alcance y límites importantes del MVP

- **No es un sistema contable o de facturación electrónica DIAN**; no emite factura electrónica ni calcula impuestos, retenciones, nómina o utilidades contables certificadas.
- **No automatiza el vencimiento mensual** ni genera estados de cuenta por corte mensual. La deuda es acumulada y los abonos reducen el saldo. El vencimiento/cierre mensual es una mejora futura.
- La aprobación de crédito a estudiantes requiere **verificación administrativa de autorización del acudiente**; el sistema no recoge ni valida firmas de acudientes. Antes de trabajar con menores, implementar consentimiento, aviso de privacidad y reglas institucionales aplicables.
- La venta de desayuno se maneja como **producto terminado**, sin recetas ni descuentos de ingredientes.
- La interfaz **no incorpora pasarela de pagos**. El administrador verifica físicamente efectivo o transferencia antes de marcar entregado.
- Las existencias de pedidos aceptados quedan reservadas hasta entrega/cancelación; los pendientes no reservan stock.
- Los reportes son históricos básicos y exportaciones CSV; no hay cierre de caja detallado, edición/reversión de ventas, devoluciones, auditoría completa ni inventario por lotes.
- El administrador único puede editar productos y perfiles. Mantén su contraseña segura y usa cuentas separadas para pruebas.
- **No cargues datos reales ni de menores antes de realizar pruebas de seguridad, privacidad y respaldos.** Este código es una base funcional para pilotaje, no una certificación de seguridad o disponibilidad.
- En el plan gratuito de Supabase el proyecto puede pausarse por inactividad y hay límites de recursos; revisa las condiciones vigentes. Realiza exportaciones/copias de seguridad periódicas desde Supabase.
- Se utiliza la biblioteca Supabase JS desde un CDN. Para una versión productiva conviene fijar una versión específica y realizar pruebas automatizadas de extremo a extremo.

## Estructura

```
coffee_register_mvp/
├── index.html                 # Página única: acceso y dos portales
├── styles.css                 # Diseño adaptable a celular
├── app.js                     # Interfaz y consumo de API
├── config.js                  # URL y clave pública Supabase (editar)
├── assets/
│   └── logo.png               # Logo proporcionado
├── supabase/
│   └── schema.sql             # Tablas, políticas RLS, triggers y RPC
└── GUIA_INSTALACION.md        # Esta guía
```

## Soporte y personalización

Para cambiar nombre, colores, textos o categorías modifica `index.html`, `styles.css` y las categorías en Supabase. Para futuras funcionalidades financieras modifica las funciones SQL, no solo `app.js`. Para nuevos despliegues basta actualizar el repositorio de GitHub.
