# Traductor C → Lisp → Forth

Traductor en 2 fases que convierte un subconjunto de C a código Forth, usando Lisp como representación intermedia. Las 2 fases son completamente independientes y separables:

- **Frontend** (`trad.y`): analiza código C y genera código Lisp.
- **Backend** (`back.y`): analiza el Lisp generado y produce código Forth para una máquina de pila.

Ambas fases usan **Bison** para el análisis sintáctico con un analizador léxico propio.

## Subconjunto de C soportado

- Variables globales y locales de tipo entero
- Arrays unidimensionales
- Función principal `main`
- Funciones de usuario con parámetros enteros y valor de retorno
- Expresiones aritméticas, lógicas y relacionales
- Asignaciones simples y encadenadas
- Sentencias de control: `while`, `for`, `if`/`else`, `switch`
- Impresión con `printf` y `puts`

## Estructura del proyecto

trad.y          # Frontend: C → Lisp (Bison)
back.y          # Backend:  Lisp → Forth (Bison)
Makefile        # Compilación de ambas fases
Trad.pdf        # Documentación de la implementación

Los ficheros de prueba se encuentran en `test-final/c/` (Entradas C) y `test-final/lisp/` (Entradas Lisp para el backend).  
Cada fichero `.c` termina con `//@ (main)`, que el analizador léxico copia directamente a la salida y que en Lisp activa la ejecución del programa.

## Autoría

Adrián Fernández C.

## Documentación

Consultar [Trad.pdf](Trad.pdf) para una descripción de la implementación.
