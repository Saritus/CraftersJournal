# Asistente de ruta (modo mini): diseño

Estado: **en curso, solo en la copia de desarrollo.** `Assistant.lua` va dentro de
`#@do-not-package@` en el .toc y, con `Media/Assistant`, está excluido en `.pkgmeta` y
`tools/package.py`: no se publica. Para publicarlo, quitar esas tres cosas (y la prueba
que lo comprueba en `tools/test_ui.py`). Las filas de compra solo existen en el asistente, así
que tampoco se publican. Sí va en la ruta grande publicada: entrenar el rango al llegar
al tope y `RouteBuy` (la vista Materiales, igual que antes). Hechos los pasos 1 y 2 del orden de trabajo (sección 8):
`Assistant.lua`, sin probar aún en el juego.

Un banner flotante y pequeño que te va guiando por la ruta empezada de una profesión
sin abrir la ventana del addon: enseña **el paso actual**, al pulsarlo hace lo que
haría esa fila en la ventana grande y una flecha propia te lleva al sitio.

---

## 0. Principio que manda sobre todo lo demás

**El asistente no tiene lógica de ruta propia.** Lo que enseña es la fila marcada
como actual (`current`) de la misma lista que pinta la vista Ruta de la ventana grande,
con los mismos datos, el mismo texto y el mismo clic.

- Si el asistente necesita algo que la ruta grande no enseña (las filas de banco y de
  compra, sección 3), **se calcula con lo mismo que ya usa la ventana** (las compras, con
  `RouteBuy`, lo mismo que la vista Materiales y la Lista de compra) y solo se **enseña**
  en el asistente: `ES:RouteLines(profKey, { buy = true })`. La ventana tiene esas cosas
  en sus pestañas; el asistente, un solo paso a la vista, las necesita como pasos.
  Nunca hay un cálculo propio del asistente.
- Puede **ayudar más** (flecha, yardas, minimapa, progreso), pero solo con
  presentación y navegación, nunca decidiendo qué paso toca, cuánto fabricar o qué comprar.
- Prueba que lo garantiza: para una ruta dada, la fila del asistente y la fila `current`
  de la vista Ruta tienen el mismo título, subtítulo, valor y acción.

### Cambio previo necesario (refactor)

Hoy las filas salen de `RouteLines(plan, page)` (local en `ProfessionUI.lua:2198`), que
lee de `page` (nivel, tope detectado, ajustes, datos de la profesión).

- [x] `ES:RouteLines(profKey)`: las filas de la ruta empezada sin la ventana abierta,
  con la misma función local que pinta la vista Ruta y tu nivel de ahora.
- [x] Las acciones de la fila (`onClick`, `go`, `useItem`, `ahItem`) viajan en la
  línea: el clic del banner es `ES.UI.RowClick`, el mismo de las filas. La estrella usa
  `WP.HoverRow` (con `hoverInset` para no tapar los botones de la esquina); el pergamino,
  un botón seguro propio suelto en UIParent que se suelta al entrar en combate.
- [x] Prueba (`tools/test_ui.py`): la fila del asistente es la fila `current` de la vista
  Ruta (mismo título, subtítulo, nivel y clic).
- [x] Mejora en la ruta grande (y por tanto en el asistente): en el tope de tu rango sin
  haber entrenado el siguiente, el paso actual es **entrenar el rango**, no fabricar
  (antes se quedaba en el paso de fabricar, que ya no sube puntos).
- [x] Los pasos de fabricar llevan `bannerTitle` ("Fabrica 3× ..."): el mismo dato que
  la fila, con verbo, para el asistente.

---

## 1. Cuándo aparece y qué ruta sigue

- **Un solo asistente**, que sigue la ruta de **una sola profesión**.
- **De momento sale siempre que haya una ruta empezada.** Sigue la última empezada.
- Abrirlo desde la ventana grande lo pone en la profesión de esa ventana (sustituye a la anterior).
  - Dónde va ese botón en la ventana grande: se decide al final.
- Comando: `/cj mini` (abre o cierra el de la última ruta empezada).
- **Cerrar (×):** se queda cerrado **para esa ruta** (se guarda con `lock.started`, como
  `shopHidden`). Al empezar otra ruta vuelve a salir.
- Si la ruta que sigue se para, pasa a la última empezada de las que queden; sin
  ninguna, se cierra.
- **Ruta terminada:** muestra "¡Ruta completada!" y **no se cierra solo**.

---

## 2. Aspecto (variante A)

De arriba abajo, en un solo bloque que se mueve junto:

```
          ▲  (flecha 3D)
        142 yd
  ┌──────────────────────────────────┐
  │ [icono]  Fabrica 20×          ⇱ ×│
  │  52px    Bolt of Runecloth       │
  │          Clic para fabricar      │
  └──────────────────────────────────┘
   ◀ 226 ▬▬▬▬▬▬▬▬░░░░░ 12/20 ▶          (tira fina)
```

- **Banner grande = solo el paso actual.** Icono grande, título en una o dos
  líneas grandes y una frase corta de qué hace el clic. Nada que no sea del paso.
- **Marco como la ventana del addon** (roca oscura, borde de diálogo) con margen alrededor:
  respira y se arrastra por el margen. La X es la de la ventana, más pequeña.
- **Columna de nivel** a la izquierda del banner, como en las filas ("226–230").
- **Textos cortos:** en fabricar, "Fabrica 4× ..." y debajo solo "4 fabricaciones · ~4 min"
  (`bannerTitle` / `bannerSub` de la fila). Sin precios: eso está en la ventana.
- **Tira debajo: solo ◀ ▬▬▬ ▶, sin textos.** Las flechas tienen el aspecto y el tamaño
  de la X (texturas propias en `Media/Assistant`, generadas con
  `tools/gen_assistant_buttons.py`). La barra: puntos del paso en fabricar; si no, la ruta.
  - ◀ ▶ ojean los pasos anteriores y siguientes **solo para mirar**: el clic en un paso
    que no es el actual no hace nada (o lo indica). Vuelve solo al actual a los pocos segundos
    o al cambiar de paso.
- **Sin línea de "siguiente paso"** ni ningún otro texto que compita con el actual.
- **Esquina superior derecha**, iconos discretos (apagados hasta pasar el ratón):
  - ⇱ abrir la ventana completa en la ruta de esa profesión;
  - × cerrar.
- **Sin ✕ de quitar de la ruta:** eso solo en la ventana grande.
- Mismo estilo que las filas de la ventana grande (marco, tipografía, colores).
- **Animaciones suaves:** fundido al cambiar de paso; brillo dorado y ✓ en el icono al
  completar un paso.
- **Mover, bloquear, escalar.** Se arrastra si está desbloqueado. Bloqueo y escala en
  las opciones del addon y en un menú con clic derecho sobre el banner. Posición y escala
  se guardan (por cuenta).
- **Clic izquierdo:** la acción de la fila. **Tooltip:** el de la fila.

---

## 3. Pasos de banco y de compra (solo en el asistente)

**Decisión (16/11/2026):** estas filas solo salen en el asistente, no en la vista Ruta de
la ventana, que ya tiene Materiales, la Lista de compra y el panel de la AH. Se calculan
con `RouteBuy`, lo mismo que Materiales: no hay lógica propia. Cuando son el paso actual,
el asistente marca "Compra" mientras la ventana sigue marcando el paso de fabricar; la
ruta (recetas, cantidades, orden) es la misma.

Hoy la ruta grande avisa de que faltan materiales con la línea de estado
(`PhaseStatus`: "tramo 200-215: faltan ~8 Runecloth") y con avisos en el chat
(`ES:PhaseNotices`: tramo nuevo, siguiente tanda, "los puntos tardan en subir: compra
un poco más"). Pero no hay ningún paso de la ruta que diga "ve a comprar". El asistente
añade esas filas, calculadas con **lo mismo que ya usan esos avisos y la vista
Materiales**: `Planner.RouteNeed` (vía `RouteBuy`). No hay cálculo nuevo.

Objetivo: **seguir el asistente sin pensar** durante toda la ruta, incluidas las tandas y
las rachas de mala suerte. **Nunca te deja en un callejón sin salida.**

### Cuándo aparece una fila de compra

1. **Al empezar un tramo**, si le falta algo hasta el colchón (lo de la Lista de compra
   del tramo). **Siempre por tramos y tandas**, aunque la Lista de compra esté en "Ruta
   entera" (`Planner.RouteNeed` con `opts.phase`): la ruta te guía tanda a tanda.
   En el asistente, sin subtítulo (la lista de materiales va en el tooltip).
2. **Siguiente tanda** (tramos en verde, `phase.batchTo`): gastada una tanda, la
   siguiente. Es el mismo momento en que hoy sale el aviso "Siguiente tanda (hasta %d)".
3. **Mala suerte**: los puntos no suben lo esperado y `PhaseOutlook.short` dice que no
   llegas a acabar el tramo con lo que llevas. Es el mismo momento en que hoy sale "Los
   puntos tardan en subir: compra un poco más". La fila dice cuánto más: `Compra ~8
   Runecloth más`.

**No depende de la Lista de compra:** si la quitaste (`RouteListHidden`), las filas salen
igual, porque lo que falta para la ruta sigue faltando. Quitar la lista solo la quita de
la pestaña Lista de compra.

### Cuándo bloquea y cuándo solo avisa

Para no obligarte a ir a la AH cuando aún puedes subir puntos, ni dejarte sin saber qué
hacer cuando ya no puedes:

| Situación | Paso actual | El paso de fabricar |
|---|---|---|
| Empieza el tramo y falta algo | **Banco / compra** | Después |
| Vas por el tramo y te faltará (mala suerte o tanda), pero aún puedes fabricar | **Fabricar** | Subtítulo en naranja: `Luego compra ~8 Runecloth más` |
| No puedes fabricar ni una vez | **Banco / compra** | Después |
| Has ido al sitio y no había (la AH sin existencias, o no quisiste comprar) y puedes fabricar algo | **Fabricar** | Subtítulo en naranja: `Faltan 8 Runecloth (no había en la AH)` |
| No hay de dónde sacarlo y no puedes fabricar | **Compra**, con `No hay Runecloth en la AH ahora` | Clic: abre la ventana completa, donde puedes quitar la receta o recalcular |

"Has ido al sitio" significa que abriste y cerraste la AH o el vendedor con esa fila
pendiente. A partir de ahí deja de bloquear hasta que vuelva a hacer falta (punto 3 de
arriba o tramo nuevo).

**Por eso no hace falta un gesto para fabricar con materiales a medias:** el asistente
siempre te enseña lo que toca, y si faltan materiales lo dice.

### Orden de un tramo

**banco → AH → vendedor → aprender → fabricar**

Cada fila es `current` hasta que se completa o deja de bloquear (tabla de arriba);
entonces queda hecha (✓, gris) y pasa a la siguiente. Los contadores se actualizan solos
al comprar o sacar del banco.

### Una fila por sitio, no por material

| Caso | Título | Subtítulo |
|---|---|---|
| Banco | `Ve al banco: 3 materiales` | `Runecloth 20 · Thread 5 · +1` |
| AH, 1 material | `Compra 40× Runecloth` | `12/40 · en la AH · ~12g` |
| AH, varios | `Compra en la AH: 3 materiales` | `Runecloth 12/40 · Thread 2/10 · +1 · ~18g` |
| Vendedor, varios | `Compra al vendedor: 2 materiales` | `Rune Thread 0/20 · Dye 0/5 · ~1g` |

El tooltip da la lista completa con lo que tienes y lo que falta de cada uno.

### Al pulsar

- **AH abierta:** compra el siguiente material con el panel de compra que ya existe
  (`Shopping.NextToBuy`, `ES:OpenAuctionBuy`). Cada clic, el siguiente.
- **Vendedor abierto que los vende:** los compra (`ES.VendorShop`).
- **Banco abierto:** saca a las bolsas **solo lo que hace falta**, en la cantidad
  justa: divide los montones (`C_Container.SplitContainerItem`) y los deja en huecos
  libres de las bolsas. Si no caben, saca lo que quepa y lo dice ("Bolsas llenas: faltan
  8 Runecloth por sacar"). Mover objetos del banco no es una acción protegida, pero hay que
  probarlo en el juego (el orden de los movimientos y esperar a que cada uno acabe).
- **Si no:** destino al banquero, al subastador o al vendedor más cercano que los vende.
- El addon nunca compra solo: siempre es tu clic (principio de `docs/PLAN.md`).

### Banco

- El juego solo da el contenido del banco con el banco abierto. Se guarda una **foto
  por personaje** en `BANKFRAME_OPENED` y `PLAYERBANKSLOTS_CHANGED` / `BAG_UPDATE` de las
  bolsas del banco.
- Lo que hay en el banco **se resta de lo que hay que comprar**.
- Si nunca has abierto el banco con ese personaje, no se sabe qué hay: todo lo que
  falta se trata como compra.
- `ES:ItemCount` sigue siendo **solo bolsas** (Core.lua: el banco no se puede usar
  ya). La foto del banco es aparte y solo la usan estas filas.
- Datos nuevos: lista de banqueros por bando (`ES.Data.Bankers`), igual que
  `ES.Data.Auctioneers`, generada con `tools/gen_sources.py`.

---

## 4. Navegación propia

El asistente **no usa** Shortest Path Forever, TomTom ni el waypoint de Blizzard.
La ventana grande sigue como hoy (`WP.SetWaypoint`).

### Destino

- **Se activa solo:** cuando el paso actual tiene un PNJ (instructor, vendedor,
  subastador, banquero, el de una misión), la flecha apunta sin pulsar nada.
- **Se fija al empezar el paso:** el más cercano en ese momento (`WP.Nearest`), y no
  cambia aunque otro pase a estar más cerca. Pulsar el banner vuelve a calcularlo.
- Pasos sin destino (fabricar, convertir esencias): no hay flecha.

### Flecha 3D

- Propia (sin el dibujo de TomTom): una tira de imágenes de una flecha dorada con
  volumen y sombra, renderizada en ~100 ángulos con un script del repo
  (`tools/`), en un archivo de textura del addon. Se enseña la imagen del ángulo que toca.
- Color: dorado normal; verde cuando vas bien orientado; rojo cuando vas al revés.
- Debajo: yardas, nombre del PNJ y tiempo estimado (a pie o en montura, según tu velocidad).
- **Al llegar (~10 yd):** imagen de llegada y "Has llegado". **No desaparece.** Si te
  alejas, vuelve a contar yardas. Se quita cuando cambia el paso.
- Va pegada al banner. Opción para separarla y moverla aparte.
- Cálculo: `UnitPosition("player")` (yardas del mundo) y la posición del PNJ con
  `C_Map.GetWorldPosFromMapPos` (como `Distance` en `Waypoints.lua`). Orientación:
  `GetPlayerFacing()`. Se actualiza en `OnUpdate`, limitado (~20 veces por segundo).
- **Otro continente:** sin flecha. Un texto: "Está en Kalimdor: toma el zepelín en
  Orgrimmar". Lista propia, a mano, de barcos y zepelines por bando y continente.
- **Mazmorras e instancias** (sin posición): sin flecha, solo el nombre y la zona.

### Minimapa y mapa del mundo

- Icono del destino en el minimapa. Si queda fuera, icono en el borde apuntando hacia él.
- Línea de puntos dorada del jugador al destino, en línea recta (no hay cálculo de caminos).
- Tener en cuenta el zoom, interior y exterior, y el minimapa que gira.
- Icono del destino en el mapa del mundo.

### Lo que no se hace

- Cálculo de caminos que esquiven montañas o usen rutas de vuelo: es lo que hace Shortest
  Path y sería un proyecto entero.

---

## 5. Combate y acciones protegidas

- Marcar la estrella sobre el PNJ y usar un pergamino son protegidas: se hacen como hoy,
  con un botón seguro encima al pasar el ratón (`WP.HoverRow`, `SetUseItem`), y no en combate.
- El banner **no** puede ser un marco seguro, para poder moverlo, ocultarlo y cambiarlo
  en combate. En combate solo informa: el clic no hace nada protegido.
- **No se atenúa ni se oculta** en combate ni en mazmorras (de momento).

---

## 6. Guardado

- `ES.db.assistant` (cuenta): posición, escala, bloqueado, flecha separada y su posición.
- Por profesión (`ES.db.prof[profKey]`): cerrado para la ruta empezada (`assistantHidden = lock.started`).
- Por personaje: foto del banco.

---

## 7. Textos

Todo texto visible como `L["..."]` con su traducción en `Locales/` (enUS, deDE, frFR).

---

## 8. Orden de trabajo propuesto

1. [x] Refactor: `ES:RouteLines(profKey)` público.
2. [x] Banner y tira (variante A) leyendo la fila `current`; mover, bloquear, escalar
   (clic derecho), cerrar, abrir ventana; ruta completada. **Falta probarlo en el juego.**
   Pendiente: bloqueo y escala también en las opciones del addon; brillo y ✓ al completar
   un paso (de momento, solo el fundido al cambiar).
3. [x] Filas de compra (AH y vendedor), solo en el asistente (`AddBuyLines` en
   ProfessionUI.lua, con `ES:RouteLines(profKey, { buy = true })`). Lo que falta sale de `RouteBuy`, que ahora comparten la vista Ruta y
   la vista Materiales (una sola regla). Paran la ruta al empezar el tramo (aún sin puntos
   en él) o cuando no puedes fabricar ni una vez; si puedes, el paso avisa ("luego compra
   8 Runecloth"). Cerrar la AH o el vendedor con compras pendientes cuenta como "ya fuiste"
   (`ES.routeBuyVisits`, solo esta sesión): dejan de parar mientras puedas fabricar.
   **Sin probar en el juego.** Aún sin la fila del banco (paso 4).
4. [ ] Foto del banco, banqueros y fila de banco.
5. [ ] Flecha 3D (generar la textura) con yardas, llegada y colores.
6. [ ] Minimapa y mapa del mundo.
7. [ ] Avisos de barco y zepelín entre continentes.

## 9. Pendiente

- **Al final:** botón para abrir el asistente desde la ventana grande (dónde va).
- **Probar en el juego:** sacar del banco dividiendo montones.
