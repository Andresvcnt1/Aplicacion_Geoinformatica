# Django backend on Windows

The backend uses PostgreSQL with PostGIS. On Windows, `settings.py` looks for
the GDAL and GEOS DLLs in the installed PostgreSQL `bin` directory and defaults
the database host to `127.0.0.1`. Set `DB_HOST` if your database uses a
different host.

From the repository root, install the Python requirements and start the server:

```powershell
.\.venv\Scripts\Activate.ps1
python -m pip install -r .\Django_geoincidencias_loja\requirements.txt
Set-Location .\Django_geoincidencias_loja
python manage.py runserver
```

Make sure the PostgreSQL service is running and the configured `sig` database
has the PostGIS extension enabled. Check pending migrations with
`python manage.py showmigrations` before applying them: migration
`reportes.0007` removes the `Pago` table and fields, so applying it can delete
existing data.
