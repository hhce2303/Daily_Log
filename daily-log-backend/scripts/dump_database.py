"""
dump_database.py
----------------
Genera un dump SQL completo de sig_dailylogs (estructura + datos).
Usa las credenciales del archivo .env en la carpeta raíz del backend.

Uso:
    python scripts/dump_database.py
    python scripts/dump_database.py --out mi_backup.sql
"""

import os
import sys
import argparse
from datetime import datetime
from pathlib import Path

# ── Load .env manually (no python-dotenv dependency required) ──────────────
def load_env(env_path: Path) -> None:
    if not env_path.exists():
        return
    with open(env_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())

BASE_DIR = Path(__file__).resolve().parent.parent
load_env(BASE_DIR / ".env")

DB_HOST     = os.environ.get("DB_HOST", "127.0.0.1")
DB_PORT     = int(os.environ.get("DB_PORT", 3306))
DB_NAME     = os.environ.get("DB_NAME", "sig_dailylogs")
DB_USER     = os.environ.get("DB_USER", "root")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")

# ── Helpers ────────────────────────────────────────────────────────────────
def escape_value(val) -> str:
    """Convierte un valor Python a literal SQL seguro."""
    if val is None:
        return "NULL"
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, (bytes, bytearray)):
        hex_str = val.hex()
        return f"0x{hex_str}"
    # datetime, date, time → string
    s = str(val)
    # Escape backslashes and single quotes
    s = s.replace("\\", "\\\\").replace("'", "\\'")
    return f"'{s}'"


def generate_dump(output_path: Path) -> None:
    try:
        import mysql.connector
    except ImportError:
        print("ERROR: mysql-connector-python no está instalado.")
        print("       pip install mysql-connector-python")
        sys.exit(1)

    print(f"Conectando a {DB_HOST}:{DB_PORT}/{DB_NAME} …")
    conn = mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        charset="utf8mb4",
        use_pure=True,
    )
    cursor = conn.cursor()

    # Obtener tablas en orden de creación
    cursor.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = %s AND table_type = 'BASE TABLE' "
        "ORDER BY table_name",
        (DB_NAME,),
    )
    tables = [row[0] for row in cursor.fetchall()]
    print(f"  → {len(tables)} tablas encontradas.")

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with open(output_path, "w", encoding="utf-8") as f:

        # ── Header ──────────────────────────────────────────────────────────
        f.write(f"-- ============================================================\n")
        f.write(f"-- Dump: {DB_NAME}\n")
        f.write(f"-- Host: {DB_HOST}:{DB_PORT}\n")
        f.write(f"-- Fecha: {timestamp}\n")
        f.write(f"-- Generado por: scripts/dump_database.py\n")
        f.write(f"-- ============================================================\n\n")
        f.write(f"SET NAMES utf8mb4;\n")
        f.write(f"SET character_set_client = utf8mb4;\n")
        f.write(f"SET FOREIGN_KEY_CHECKS = 0;\n")
        f.write(f"SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';\n\n")

        # ── Crear base de datos clonada ──────────────────────────────────────
        clone_name = f"{DB_NAME}_clone"
        f.write(f"-- Crea la base de datos destino (cámbiala si ya existe con otro nombre)\n")
        f.write(f"CREATE DATABASE IF NOT EXISTS `{clone_name}`\n")
        f.write(f"  DEFAULT CHARACTER SET utf8mb4\n")
        f.write(f"  DEFAULT COLLATE utf8mb4_unicode_ci;\n\n")
        f.write(f"USE `{clone_name}`;\n\n")

        for table in tables:
            print(f"  Procesando: {table} …", end=" ", flush=True)

            # ── DDL ──────────────────────────────────────────────────────────
            cursor.execute(f"SHOW CREATE TABLE `{table}`")
            ddl_row = cursor.fetchone()
            create_stmt = ddl_row[1]

            f.write(f"-- ----------------------------------------------------------\n")
            f.write(f"-- Tabla: {table}\n")
            f.write(f"-- ----------------------------------------------------------\n")
            f.write(f"DROP TABLE IF EXISTS `{table}`;\n")
            f.write(create_stmt + ";\n\n")

            # ── Datos ─────────────────────────────────────────────────────────
            cursor.execute(f"SELECT * FROM `{table}`")
            rows = cursor.fetchall()
            if not rows:
                print("(vacía)")
                f.write(f"-- (sin registros)\n\n")
                continue

            # Nombres de columnas
            col_names = [desc[0] for desc in cursor.description]
            cols_sql = ", ".join(f"`{c}`" for c in col_names)

            # Inserts en lotes de 500
            batch_size = 500
            total = len(rows)
            for i in range(0, total, batch_size):
                batch = rows[i : i + batch_size]
                values_list = []
                for row in batch:
                    vals = ", ".join(escape_value(v) for v in row)
                    values_list.append(f"  ({vals})")
                values_sql = ",\n".join(values_list)
                f.write(
                    f"INSERT INTO `{table}` ({cols_sql}) VALUES\n{values_sql};\n\n"
                )

            print(f"{total} filas")

        # ── Footer ──────────────────────────────────────────────────────────
        f.write("SET FOREIGN_KEY_CHECKS = 1;\n")
        f.write(f"-- Fin del dump — {timestamp}\n")

    cursor.close()
    conn.close()
    size_kb = output_path.stat().st_size / 1024
    print(f"\n✓ Dump generado: {output_path}  ({size_kb:.1f} KB)")


# ── Main ──────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Dump completo de sig_dailylogs a SQL")
    parser.add_argument(
        "--out",
        type=str,
        default=None,
        help="Archivo de salida (default: sig_dailylogs_clone_YYYYMMDD_HHMMSS.sql)",
    )
    args = parser.parse_args()

    if args.out:
        out_path = Path(args.out)
    else:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        out_path = BASE_DIR / f"sig_dailylogs_clone_{ts}.sql"

    generate_dump(out_path)
