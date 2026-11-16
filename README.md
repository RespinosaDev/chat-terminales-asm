# E/S por interrupciones · MC68000 + DUART MC68681

Entrada/salida serie **por interrupciones** en **ensamblador del Motorola 68000**, usando el controlador de comunicaciones **DUART MC68681**. El programa principal conecta las dos líneas serie: lo que escribes en el terminal de la **línea A** aparece en el de la **línea B** y al revés, como si fuera un chat entre dos terminales.

Es una práctica de la asignatura *Arquitectura de Computadores* (Grado en Ingeniería Informática, Universidad Politécnica de Madrid). La hice de forma individual.

---

## Cómo funciona

```
 Terminal A ──RX──► RTI ──► buffer RX A ──► SCAN(A) ─┐
                                                     │  programa principal
 Terminal B ◄──TX── RTI ◄── buffer TX B ◄── PRINT(B) ◄┘  (y lo mismo de B hacia A)
```

- **`INIT`** configura las dos líneas del DUART (8 bits, 38 400 bps), instala la rutina de interrupción en el vector `0x40` y habilita solo las interrupciones de **recepción**.
- **`RTI`** lee el registro de estado de interrupciones (`ISR`), filtrado con una **copia en memoria de la máscara** (`IMR_SHADOW`), porque el `IMR` del 68681 no se puede leer:
  - **Recepción**: guarda el carácter recibido en el buffer interno de esa línea.
  - **Transmisión**: envía el siguiente carácter pendiente. Si no queda ninguno, deshabilita la interrupción de transmisión de esa línea.
- **`SCAN(buffer, descriptor, tamaño)`** es **no bloqueante**: copia al buffer del usuario los caracteres ya recibidos (hasta `tamaño`) y devuelve en `D0` cuántos ha leído.
- **`PRINT(buffer, descriptor, tamaño)`** deja los caracteres en el buffer de transmisión y activa la interrupción de transmisión. Si el transmisor ya está libre, envía el primer carácter directamente para arrancar la transmisión.
- Las zonas que tocan estructuras compartidas con la `RTI` se protegen como **secciones críticas** (`ORI.W #$0700,SR`). Los cuatro **buffers circulares** de 2001 bytes (RX/TX × A/B) los gestiona la biblioteca `bib_aux.s` de la asignatura.

## Ficheros

| Fichero | Contenido |
|---------|-----------|
| [`src/es_int.s`](src/es_int.s) | **Versión final**: `INIT`, `SCAN`, `PRINT`, `RTI` y un programa de prueba que retransmite A↔B hasta 40 caracteres en cada sentido |
| [`src/bib_aux.s`](src/bib_aux.s) | Biblioteca de buffers circulares (`ESCCAR`, `LEECAR`, `INI_BUFS`), *proporcionada por la asignatura* |
| [`src/eco_cruzado.s`](src/eco_cruzado.s) | Variante anterior con eco cruzado carácter a carácter y manejadores de excepción |
| [`src/es_int_v2.s`](src/es_int_v2.s) | Variante con secciones críticas más cortas (una por carácter) |
| [`src/consulta_scan.s`](src/consulta_scan.s), [`src/consulta_scan_print.s`](src/consulta_scan_print.s) | Primera fase de la práctica: E/S **por consulta** (*polling*) de la línea A |
| [`practica.setup`](practica.setup) | Configuración del simulador: 32 KB de RAM y el DUART en `0xEFFC00` con un `xterm` por línea |

## Ejecución

Se ejecuta en el simulador **BSVC** (Bradford's 68000 simulator) con el ensamblador `68kasm`, en el entorno Linux de la asignatura:

1. Ensamblar: `68kasm -l es_int.s`. Genera `es_int.h68` y el listado `es_int.lis`.
2. Abrir BSVC, cargar `practica.setup` y después `es_int.h68`.
3. Ejecutar: se abren dos `xterm`, uno por línea. Lo que se escribe en uno aparece en el otro.

## Qué corregí respecto a la entrega

- `SCAN` y `PRINT` usaban `D1` y `A0` sin salvarlos. Ahora conservan todos los registros del llamador salvo `D0`, que es el valor de retorno.
