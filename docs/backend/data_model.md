## DailyEvent

Propósito:
Registrar actividades del operador durante turno.

Relaciones:
- FK → User
- FK → Site

Invariantes:
- No puede existir sin sesión activa.
- Debe pertenecer a turno actual.
