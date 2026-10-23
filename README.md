# Vigilancia del conjunto

PWA para reemplazar el cuaderno de la caseta: entrada y salida con QR, dos rondas, incidentes con foto y panel del administrador.

Vue 3, Tailwind CSS 4, PrimeVue y Supabase. La hora, el radio y la firma del QR se confirman en Postgres. La foto se hashea en la función `registrar-evento` al recibirla.

## Lo que tú completas

1. Crea un proyecto en [Supabase](https://supabase.com/dashboard), distinto al de formatos.
2. En Authentication → Providers → Email, desactiva **Confirm email** mientras dura el piloto.
3. Copia `.env.example` a `.env` y pega la URL y la clave **anon**.

```
VITE_SUPABASE_URL=https://xxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

4. En esta carpeta:

```
npx supabase login
npx supabase link --project-ref TU_PROJECT_REF
npx supabase db push
npx supabase functions deploy crear-usuario
npx supabase functions deploy registrar-evento
```

5. Arranca la app:

```
npm install
npm run dev
```

6. La primera cuenta queda como administrador. Después el registro público se cierra y los demás usuarios se crean en **Usuarios**.

7. En **Conjunto**, guarda la latitud, longitud y radio de la caseta. Sin eso no se puede marcar. En **Puntos**, crea los QR e imprímelos. En **Turnos**, asigna el de 6 a 6 e imprime el QR de la caseta.

## Alojamiento del piloto

- Datos, login, fotos y lógica: Supabase.
- La pantalla: Cloudflare Pages. Comando `npm run build`, carpeta `dist`, con las dos variables `VITE_`.

## Límites

- No se guarda un recorrido. Cada registro usa una sola lectura de GPS.
- Esa lectura se puede simular. El QR firmado, la selfie y la hora del servidor dificultan el fraude; no prueban la presencia física.
- El hash detecta si el archivo guardado cambió. No prueba que la foto sea del lugar.
- Un registro hecho sin datos muestra la hora de sincronización, no una hora verificada en el momento.
- El botón de ayuda no reemplaza al 123.
