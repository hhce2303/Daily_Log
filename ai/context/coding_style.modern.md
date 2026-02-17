# MODERN CODING STYLE

## Python

- Uso de match/case cuando aplique.
- Tipado obligatorio en funciones.
- Dataclasses o Pydantic para estructuras.
- Uso de enums en lugar de strings mágicos.
- Uso de pathlib en vez de os.path.
- Uso de context managers.
- No código procedural en módulos grandes.

## Django

- Servicios separados.
- Uso de settings modularizados.
- Uso de signals solo cuando sea necesario.
- No lógica en serializers.
- No lógica en models salvo reglas de dominio puras.

## Buenas prácticas

- SRP
- Clean code
- Funciones pequeñas
- Manejo explícito de errores
