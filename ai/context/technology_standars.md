# TECHNOLOGY STANDARDS

## Backend

Lenguaje:
- Python 3.12+

Framework:
- Django 5+
- Django REST Framework actualizado

Base de Datos:
- PostgreSQL 15+

ORM:
- Uso completo de ORM moderno
- Prefetch_related y Select_related obligatorio cuando aplique

Validación:
- Pydantic v2 cuando aplique
- Tipado estricto (typing)

Async:
- Uso de async views cuando tenga sentido
- No bloquear event loop

Testing:
- Pytest
- Factory Boy
- Coverage mínimo 80%

Linting:
- Ruff
- Black
- isort

---

## Frontend (si aplica)

- React 18+
- TypeScript obligatorio
- Vite como bundler
- React Query o TanStack Query
- Zod para validación

---

## DevOps

- Docker multi-stage
- GitHub Actions CI
- Variables por entorno
- No .env en repo

---

## Prohibido

- Librerías sin mantenimiento
- Patrones obsoletos
- Sintaxis Python <3.10
- Uso de setup.py legacy (usar pyproject.toml)
