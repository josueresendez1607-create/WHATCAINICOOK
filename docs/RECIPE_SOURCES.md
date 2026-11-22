# Fuentes de recetas verificadas

Catálogo: `assets/data/recipes.json` · Verificado: **2026-11-21** · Fuente general: [MyPlate — USDA](https://www.myplate.gov/recipes).

La app **no inventa recetas con IA**. Gemini puede ordenar y seleccionar IDs de este catálogo cerrado, pero el backend valida cada ID y devuelve la receta transcrita de la página oficial. Cada registro conserva `sourceUrl` y `originalSource`. Los tiempos y valores nutricionales son los publicados por la fuente cuando estaban disponibles. Las etiquetas (`tags`) y la dificultad son estimaciones de la app y llevan `difficultyIsEstimated: true`.

| # | Receta en la app | Título original | Fuente oficial | Fuente original acreditada por MyPlate |
| --- | --- | --- | --- | --- |
| 1 | Huevos sobre col rizada y sémola de batata | Eggs over Kale and Sweet Potato Grits | [MyPlate](https://www.myplate.gov/recipes/eggs-over-kale-and-sweet-potato-grits) | Produce for Better Health Foundation |
| 2 | Taquitos de aguacate y frijol negro | Avocado Black Bean Taquitos | [MyPlate](https://www.myplate.gov/recipes/avocado-black-bean-taquitos) | Fresh Avocados Love One Today |
| 3 | Quesadilla de frijol rojo | Red Bean Quesadilla | [MyPlate](https://www.myplate.gov/recipes/red-bean-quesadilla) | USDA Center for Nutrition Policy and Promotion |
| 4 | Frijoles Bronco | Bronco Beans | [MyPlate](https://www.myplate.gov/recipes/bronco-beans) | USDA Center for Nutrition Policy and Promotion |
| 5 | Verduras cítricas | Citrus Vegetables | [MyPlate](https://www.myplate.gov/recipes/citrus-vegetables) | U.S. Department of Health and Human Services, National Cancer Institute |
| 6 | Sartén de papas estilo toscano | Tuscan Potato Skillet | [MyPlate](https://www.myplate.gov/recipes/tuscan-potato-skillet) | MyPlate National Strategic Partners Toolkit |
| 7 | Cazuela de frijoles | Full Beans Hot Dish | [MyPlate](https://www.myplate.gov/recipes/full-beans-hot-dish) | University of Wisconsin Cooperative Extension Service |
| 8 | Medallón de maíz y frijol | Corn and Bean Medley | [MyPlate](https://www.myplate.gov/recipes/corn-and-bean-medley) | USDA Food and Nutrition Service, FDPIR |
| 9 | Tortilla de cebollín | Green Onion Omelet | [MyPlate](https://www.myplate.gov/recipes/green-onion-omelet) | A Harvest of Recipes with USDA Foods, FDPIR |
| 10 | Macarrones con frijol | Mac and Beans Medley | [MyPlate](https://www.myplate.gov/recipes/mac-and-beans-medley) | Champions for Change Recipes, Arizona Nutrition Network |
| 11 | Sopa de lentejas en olla de cocción lenta | Slow Cooker Lentil Soup | [MyPlate](https://www.myplate.gov/recipes/slow-cooker-lentil-soup) | Montana State University Extension Service |
| 12 | Cazuela caribeña | Caribbean Casserole | [MyPlate](https://www.myplate.gov/recipes/caribbean-casserole) | U.S. Department of Health and Human Services, NHLBI |
| 13 | Frittata de jardín | Garden Frittata | [MyPlate](https://www.myplate.gov/recipes/garden-frittata) | Produce for Better Health Foundation |

> Nota: el catálogo contiene 13 recetas verificadas; el resumen inicial del proyecto mencionaba 12, pero el JSON actual incluye también *Garden Frittata*.

## Normas de verificación

- Solo se incluyen páginas `myplate.gov` con receta pública y estable.
- No se inventan cantidades, tiempos, temperaturas ni datos nutricionales.
- Si la fuente no publica un dato, el campo queda `null` y la app muestra “No indicado por la fuente”.
- Las fotos remotas no se usan para afirmar datos no publicados; cuando no hay imagen oficial, la app muestra un placeholder propio.

## Cómo agregar una receta

1. Busca una receta oficial nueva en [MyPlate Recipes](https://www.myplate.gov/recipes).
2. Copia título original, fuente acreditada, ingredientes, pasos, tiempos y nutrición **exactamente como aparece**.
3. Agrega un objeto a `assets/data/recipes.json` con `sourceUrl`, `originalSource`, `verified: true` y `difficultyIsEstimated: true`.
4. Usa claves del catálogo `assets/data/ingredients.json` en `ingredients[].key`.
5. Ejecuta `flutter test`; el matcher debe seguir pasando.
