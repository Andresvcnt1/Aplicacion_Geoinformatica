"""
Carga geocercas municipales desde un archivo GeoJSON.

Ubicación en el proyecto:
    reportes/management/commands/cargar_geocercas.py
(las carpetas management/ y management/commands/ necesitan su __init__.py)

Ejemplos (dentro del contenedor, con el archivo dentro de la carpeta del proyecto):
    python manage.py cargar_geocercas datos_geo/CANTON_LOJA.geojson --dry-run
    python manage.py cargar_geocercas datos_geo/CANTON_LOJA.geojson \
        --nombre-fijo "Cantón Loja" --descripcion "Límite cantonal (reservado)" --inactivas
    python manage.py cargar_geocercas datos_geo/PARROQUIAS_URBANAS.geojson \
        --campo-nombre name --descripcion "Parroquia urbana"

Reglas:
- GeocercaMunicipal.area es PolygonField: un MultiPolygon se separa en una
  geocerca por parte, con nombre "Nombre (1)", "Nombre (2)", ...
- No duplica: si ya existe una geocerca con el mismo nombre, la omite.
- Todo se guarda en una sola transacción; --dry-run no guarda nada.
"""
import json

from django.contrib.gis.geos import GEOSGeometry, GeometryCollection, MultiPolygon, Polygon
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from reportes.models import GeocercaMunicipal

# Rango aproximado de Ecuador: detecta archivos en otro sistema de coordenadas.
LON_MIN, LON_MAX = -92.5, -75.0
LAT_MIN, LAT_MAX = -5.1, 1.7


class Command(BaseCommand):
    help = 'Carga geocercas municipales desde un archivo GeoJSON (EPSG:4326).'

    def add_arguments(self, parser):
        parser.add_argument('archivo', help='Ruta del archivo .geojson')
        parser.add_argument(
            '--campo-nombre', default='name',
            help='Propiedad del GeoJSON que contiene el nombre (por defecto: name)',
        )
        parser.add_argument(
            '--nombre-fijo', default=None,
            help='Usar este nombre en vez de leerlo del archivo (útil con un solo elemento)',
        )
        parser.add_argument(
            '--solo', nargs='+', default=None,
            help='Cargar solo los elementos cuyo nombre esté en esta lista',
        )
        parser.add_argument('--descripcion', default='', help='Texto para el campo descripcion')
        parser.add_argument(
            '--inactivas', action='store_true',
            help='Crear las geocercas con activa=False (se activan luego en el admin)',
        )
        parser.add_argument(
            '--simplificar', type=float, default=0.0,
            help='Tolerancia en grados para simplificar (ej. 0.00005 ≈ 5 m). 0 = no simplificar',
        )
        parser.add_argument(
            '--dry-run', action='store_true',
            help='Solo muestra lo que se crearía, sin guardar nada',
        )

    def handle(self, *args, **opts):
        try:
            with open(opts['archivo'], encoding='utf-8') as f:
                datos = json.load(f)
        except FileNotFoundError:
            raise CommandError(f"No existe el archivo: {opts['archivo']}")
        except json.JSONDecodeError as e:
            raise CommandError(f'El archivo no es un GeoJSON válido: {e}')

        features = datos.get('features')
        if datos.get('type') != 'FeatureCollection' or not features:
            raise CommandError('Se esperaba un FeatureCollection con al menos un elemento.')

        solo = {s.strip().lower() for s in opts['solo']} if opts['solo'] else None
        activa = not opts['inactivas']
        pendientes = []  # (nombre, geometria)

        for i, feat in enumerate(features, start=1):
            props = feat.get('properties') or {}
            nombre_base = opts['nombre_fijo'] or props.get(opts['campo_nombre'])
            if not nombre_base:
                raise CommandError(
                    f"El elemento {i} no tiene la propiedad '{opts['campo_nombre']}'. "
                    f"Propiedades disponibles: {', '.join(props.keys())}"
                )
            nombre_base = str(nombre_base).strip()
            if solo is not None and nombre_base.lower() not in solo:
                continue

            geom = self._leer_geometria(feat.get('geometry'), nombre_base)
            if opts['simplificar'] > 0:
                geom = geom.simplify(opts['simplificar'], preserve_topology=True)
            partes = self._partes(geom)
            if not partes:
                raise CommandError(f'«{nombre_base}» no contiene polígonos.')

            for n, parte in enumerate(partes, start=1):
                nombre = nombre_base if len(partes) == 1 else f'{nombre_base} ({n})'
                pendientes.append((nombre[:100], parte))

        if not pendientes:
            raise CommandError('Ningún elemento coincide con el filtro --solo.')

        creadas = omitidas = 0
        with transaction.atomic():
            for nombre, parte in pendientes:
                xmin, ymin, xmax, ymax = parte.extent
                resumen = (
                    f'{nombre}: {parte.num_coords} vértices, '
                    f'extensión lon {xmin:.4f}..{xmax:.4f}, lat {ymin:.4f}..{ymax:.4f}'
                )
                if GeocercaMunicipal.objects.filter(nombre=nombre).exists():
                    omitidas += 1
                    self.stdout.write(self.style.WARNING(f'OMITIDA (ya existe) -> {resumen}'))
                    continue
                if opts['dry_run']:
                    self.stdout.write(f'CREARÍA ({"activa" if activa else "inactiva"}) -> {resumen}')
                else:
                    GeocercaMunicipal.objects.create(
                        nombre=nombre,
                        descripcion=opts['descripcion'] or None,
                        area=parte,
                        activa=activa,
                    )
                    self.stdout.write(self.style.SUCCESS(f'CREADA -> {resumen}'))
                creadas += 1

        verbo = 'se crearían' if opts['dry_run'] else 'creadas'
        self.stdout.write(f'\nResultado: {creadas} {verbo}, {omitidas} omitidas.')
        if opts['dry_run']:
            self.stdout.write('Modo prueba: no se guardó nada.')

    def _leer_geometria(self, geometry, nombre):
        if not geometry:
            raise CommandError(f'«{nombre}» no tiene geometría.')
        try:
            geom = GEOSGeometry(json.dumps(geometry))
        except Exception as e:
            raise CommandError(f'Geometría ilegible en «{nombre}»: {e}')
        geom.srid = 4326

        xmin, ymin, xmax, ymax = geom.extent
        if not (LON_MIN <= xmin and xmax <= LON_MAX and LAT_MIN <= ymin and ymax <= LAT_MAX):
            raise CommandError(
                f'«{nombre}» queda fuera del rango de Ecuador (lon {xmin:.2f}..{xmax:.2f}, '
                f'lat {ymin:.2f}..{ymax:.2f}). ¿El archivo está en EPSG:4326?'
            )

        if not geom.valid:
            try:
                geom = geom.make_valid()
            except Exception:
                geom = geom.buffer(0)
            geom.srid = 4326
        return geom

    def _partes(self, geom):
        """Devuelve una lista de Polygon a partir de Polygon, MultiPolygon o colecciones."""
        if isinstance(geom, Polygon):
            geom.srid = 4326
            return [geom]
        if isinstance(geom, (MultiPolygon, GeometryCollection)):
            partes = []
            for g in geom:
                partes.extend(self._partes(g))
            return partes
        return []  # puntos o líneas sueltas (pueden salir de make_valid): se ignoran