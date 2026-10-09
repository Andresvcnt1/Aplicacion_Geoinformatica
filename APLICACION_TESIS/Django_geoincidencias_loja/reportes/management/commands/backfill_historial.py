from django.core.management.base import BaseCommand
from django.db import transaction

from reportes.models import HistorialEstado, Incidencia, Usuario

# Valores antiguos (con mayúsculas) -> valores actuales de Incidencia.Estado
LEGACY = {
    'Recibido': 'recibido',
    'En proceso': 'en_proceso',
    'Solucionado': 'subsanado',
}


class Command(BaseCommand):
    help = 'Normaliza estados antiguos y crea el primer registro de historial a incidencias que no tienen ninguno.'

    @transaction.atomic
    def handle(self, *args, **options):
        for viejo, nuevo in LEGACY.items():
            n = Incidencia.objects.filter(estado=viejo).update(estado=nuevo)
            if n:
                self.stdout.write(f'Estado "{viejo}" -> "{nuevo}": {n} incidencias')

        fallback = Usuario.objects.filter(is_superuser=True).order_by('id').first()
        creados = omitidos = 0
        for inc in Incidencia.objects.filter(historial__isnull=True):
            responsable = inc.usuario or fallback
            if responsable is None:
                omitidos += 1
                continue
            HistorialEstado.objects.create(
                incidencia=inc,
                estado_anterior=None,
                estado_nuevo=inc.estado,
                usuario_responsable=responsable,
                observacion='Registro inicial generado al activar la trazabilidad.',
            )
            creados += 1
        self.stdout.write(self.style.SUCCESS(f'Historial creado: {creados} | omitidas (sin usuario): {omitidos}'))