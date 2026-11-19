# Crafter's Journal

Addon de WoW Forever (Lua 5.1). El código está en español y los textos del addon se traducen por su clave (`Locales/`).

## Pruebas

- **Al terminar cada desarrollo** (cada spec o change de OpenSpec, o cualquier cambio en el código del addon) se lanzan **todas** las pruebas antes de darlo por acabado, y se dice el resultado en el mensaje final: cuántas pasan, cuántas fallan y cuáles, los fallos conocidos y cuánto ha tardado. Así el usuario se entera antes de poner la etiqueta de versión.

  ```
  python tools/run_tests.py
  ```

- Mientras se desarrolla basta con la categoría que se toca: `python tools/run_tests.py --only route earn`.
- Si falla un presupuesto de rendimiento («pasadas» o «millones de instrucciones» de las rutas 1-300), el cambio ha hecho las rutas más lentas: se arregla, o, si es a propósito y compensa, se dice al usuario cuánto más lentas son antes de aceptar la referencia nueva.
- Si una instantánea cambia **a propósito** (rutas, datos regenerados): `python tools/run_tests.py --only <categoría> --update-snapshots`, y se dice qué cambió.
- **Cada desarrollo trae su prueba:** todo desarrollo nuevo añade o modifica la prueba adecuada en la categoría que toca (`tools/tests/categories/`). Sobre todo **cada bug arreglado**: una prueba que falla sin el arreglo y pasa con él (compruébalo). Si el bug tenía una prueba marcada como fallo conocido, se le quita la marca. En el mensaje final se dice qué prueba se añadió o cambió.
- Una prueba que destapa un fallo que no se arregla ahora se marca con `{ known = "motivo" }`.
- Las pruebas **no** se añaden a GitHub Actions: la publicación (`.github/workflows/release.yml`) no depende de ellas.
- Cómo funcionan y cómo escribir una: `docs/TESTS.md`.

## Publicar

- Las etiquetas `v*` las pone el usuario (publican en CurseForge). No crear etiquetas.
