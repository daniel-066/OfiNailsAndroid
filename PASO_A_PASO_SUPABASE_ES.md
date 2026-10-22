# OfiNails — guía paso a paso en español

Esta carpeta contiene:
- `index.html`: sitio web y paneles Cliente/Administradora.
- `supabase_schema.sql`: tablas, permisos RLS, servicios iniciales y función segura para reservar.
- `PASO_A_PASO_SUPABASE_ES.md`: esta guía.

## 1. Crear el proyecto de Supabase
1. Entrá a https://supabase.com/ e iniciá sesión.
2. Creá un proyecto nuevo y poné como nombre `OfiNails`.
3. Guardá la contraseña de la base de datos en un lugar seguro.
4. Esperá a que el proyecto termine de crearse.

## 2. Crear las tablas y la seguridad
1. En el menú izquierdo del proyecto, abrí **SQL Editor**.
2. Elegí **New query**.
3. Abrí el archivo `supabase_schema.sql` de esta carpeta con un editor de texto.
4. Copiá todo su contenido y pegalo en SQL Editor.
5. Presioná **Run**.
6. Si sale un error, no sigás pegando repetidamente el SQL: copiá el mensaje exacto y revisalo primero. Este script está pensado para ejecutarse una vez en un proyecto nuevo.

## 3. Obtener la URL y la clave pública
1. En Supabase abrí **Project Settings** (ícono de engranaje).
2. Entrá en **API** o **Data API / API Keys**, según cómo aparezca en tu versión.
3. Copiá la **Project URL**.
4. Copiá la clave pública llamada `anon` o `publishable` (el nombre varía según la interfaz).
5. Nunca uses la clave `service_role` o una clave secreta dentro de `index.html`; esa clave permite saltarse protecciones y no debe exponerse.
6. Abrí `index.html` con un editor de texto y buscá:
   `const SUPABASE_URL = "";`
   `const SUPABASE_ANON_KEY = "";`
7. Pegá tus datos entre las comillas. Ejemplo ficticio:
   `const SUPABASE_URL = "https://tu-proyecto.supabase.co";`
   `const SUPABASE_ANON_KEY = "TU_CLAVE_PUBLICA";`
   No copies este ejemplo ficticio literalmente; usá los valores de TU proyecto.

## 4. Configurar autenticación por correo
1. En Supabase abrí **Authentication → Providers**.
2. Confirmá que **Email** esté habilitado.
3. En **Authentication → URL Configuration**, agregá la URL de tu web a **Site URL** cuando ya esté publicada. Durante pruebas podés usar la URL local que corresponda.
4. Decidí si querés exigir confirmación de correo. Si está activa, una clienta debe confirmar el mensaje antes de iniciar sesión.
5. El registro de la web siempre crea un perfil con rol `client`; nadie puede elegirse administradora desde el formulario.

## 5. Crear tu cuenta de administradora
1. Publicá temporalmente el sitio o abrí `index.html` desde un servidor local.
2. En la web, entrá en **Mi cuenta / Reservar → Entrar como Clienta → Crear cuenta**.
3. Registrá el correo que usarás para administrar OfiNails.
4. Si la confirmación de correo está activada, confirmá el correo y luego iniciá sesión al menos una vez.
5. Volvé a Supabase → **SQL Editor → New query**.
6. Ejecutá este SQL, reemplazando el correo por el correo exacto de tu cuenta:

   ```sql
   update public.profiles
   set role = 'admin'
   where id = (
     select id from auth.users
     where email = 'tu-correo@ejemplo.com'
   );
   ```

7. Confirmá que se actualizó una fila. Si dice `0 rows`, revisá que la cuenta esté creada y el correo esté correcto.
8. Cerrá sesión en OfiNails y entrá por **Entrar como Administradora**.
9. No compartás ese correo ni su contraseña. Para crear más administradoras, asigná el rol explícitamente desde SQL a cada cuenta de confianza.

## 6. Poner el número de WhatsApp
En `index.html`, buscá:
`const WHATSAPP_NUMBER = "";`
Escribí el número con código de país, solo dígitos. Costa Rica usa 506. Ejemplo ficticio: `const WHATSAPP_NUMBER = "50688888888";`
Usá el número real del negocio. El botón abrirá WhatsApp con un mensaje preescrito.

## 7. Probar la aplicación
1. Registrá una cuenta de clienta de prueba.
2. Iniciá sesión como clienta y verificá que aparezcan los servicios.
3. Creá una reserva futura dentro del horario de atención.
4. Cerrá sesión y entrá como administradora.
5. Revisá **Citas**, cambiá el estado a confirmada/completada/cancelada y probá el informe.
6. Intentá reservar la misma hora desde otra cuenta. La función `book_appointment` y el bloqueo de solapamientos deben impedir duplicados.
7. Probá desde el teléfono y una computadora.

## 8. Publicar gratis en Netlify
1. Entrá en https://www.netlify.com/ y creá una cuenta.
2. Abrí **Add new site → Deploy manually** (el texto puede variar).
3. Arrastrá `index.html` al área de publicación. Si Netlify requiere una carpeta, comprimí el contenido del sitio y cargá la carpeta/despliegue según la interfaz.
4. Netlify te dará una URL `*.netlify.app`.
5. Copiá esa URL y pegala en Supabase → **Authentication → URL Configuration** como **Site URL** y añadila a **Redirect URLs**.
6. Volvé a probar registro, confirmación de correo e inicio de sesión.

## 9. Cómo actualizar el sitio
Editá `index.html` en tu editor, guardá y volvé a desplegar el archivo en Netlify. La información de clientas, servicios y citas vive en Supabase, así que no se borra al actualizar el diseño.

## Qué incluye y qué no incluye esta versión
Incluye la página de inicio, botones de rol, registro e inicio de sesión con Supabase, perfiles con roles, servicios, reservas mediante función de base de datos, gestión de estado de citas, una galería de ejemplo y un resumen mensual básico.

Todavía requiere trabajo adicional para:
- Enviar correos/WhatsApp automáticos de confirmación (WhatsApp requiere proveedor/API y consentimiento; el enlace simple abre WhatsApp).
- Subir archivos de imagen directamente a Supabase Storage; la galería actual está preparada a nivel de esquema, pero el formulario de administración necesita conectarse completamente para listar y mostrar los registros.
- Editar horarios cómodamente desde la interfaz; se pueden editar en `business_hours` usando Table Editor.
- Manejar citas con duraciones variables con un calendario que calcule todos los espacios libres. La función de reserva bloquea solapamientos, pero el selector de horas inicial es una lista fija.
- Configurar políticas de cancelación, adelantos y pagos reales.

## Reglas importantes de seguridad
- No pongás contraseñas ni la clave `service_role` en el código del navegador.
- El rol de administrador se asigna en Supabase, no desde el formulario.
- Las políticas RLS son esenciales; no las desactivés para “arreglar” errores.
- No guardés datos reales de clientas hasta que hayas probado la seguridad y el flujo de reservas.

## Actualizar los precios de OfiNails

Si ya habías ejecutado el SQL anterior en tu proyecto, no hace falta borrar la base de datos. Abrí **SQL Editor** en Supabase, pegá el contenido de `ACTUALIZAR_PRECIOS_EXISTENTES.sql` y presioná **Run**. Esto desactiva los servicios viejos y activa los 15 servicios con los nuevos precios. Si todavía no creaste la base de datos, usá el `supabase_schema.sql` actualizado.

## Actualización de calendario y horarios de OfiNails

1. En Supabase, abrí **SQL Editor** y creá una consulta nueva.
2. Abrí el archivo `ACTUALIZAR_HORARIOS_CALENDARIO.sql`, copiá todo su contenido y ejecutalo.
3. El archivo establece lunes a viernes de 9:00 a. m. a 8:00 p. m., sábados de 9:00 a. m. a 5:00 p. m. y domingo cerrado. También corrige el nombre `Sofia Montiel Diz` a `Sofia Montiel Díaz`, si existe exactamente con esa escritura.
4. Publicá el `index.html` actualizado en Netlify. En este archivo ya están configurados la URL del proyecto y la clave **publishable** proporcionadas para OfiNails. Nunca pongás una clave `service_role` en el sitio público.
5. En el panel administrador, entrá a **Horarios** para editar la apertura/cierre de cada día y consultar horas libres o reservadas. Las clientas eligen fecha y servicio y ven las horas libres/reservadas antes de solicitar una cita.
6. Después de solicitar una cita, la clienta verá que debe pagar el 50% por SINPE Móvil al 8575-8433 y enviar el comprobante por WhatsApp a ese mismo número. La cita queda pendiente hasta que la administradora la revise.

Nota: los horarios y la disponibilidad compartida dependen de ejecutar el SQL de actualización. No borres tablas ni reinicies el proyecto para aplicar estos cambios.
