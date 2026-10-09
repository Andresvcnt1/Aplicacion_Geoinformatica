from django.contrib.gis.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone


class Usuario(AbstractUser):
    """Usuario ciudadano con validación biométrica"""
    cedula = models.CharField(max_length=10, unique=True)
    metodo_verificacion = models.CharField(
        max_length=20,
        choices=[('facial', 'Reconocimiento Facial'), ('huella', 'Huella Digital')],
        default='huella'
    )
    foto_perfil = models.ImageField(upload_to='perfiles/', blank=True, null=True)
    fecha_registro = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'usuarios'

    def __str__(self):
        return f"{self.cedula} - {self.username}"


class Incidencia(models.Model):
    class Estado(models.TextChoices):
        RECIBIDO    = 'recibido',    'Recibido'
        EN_REVISION = 'en_revision', 'En revisión'
        EN_PROCESO  = 'en_proceso',  'En proceso'
        SUBSANADO   = 'subsanado',   'Subsanado'
        NO_VIABLE   = 'no_viable',   'No viable'
        CERRADO     = 'cerrado',     'Cerrado'

    CATEGORIAS = [
        ('AGUA', 'Fuga de agua / alcantarillado'),
        ('VIAL', 'Bache / Deterioro vial'),
        ('LUZ', 'Luminaria defectuosa'),
        ('OTRO', 'Otros daños de Infraestructura'),
    ]

    usuario = models.ForeignKey(
        Usuario,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='incidencias'
    )
    categoria = models.CharField(max_length=4, choices=CATEGORIAS)
    descripcion = models.TextField(blank=True, null=True)
    foto = models.ImageField(upload_to='evidencias/', blank=True, null=True)
    ubicacion = models.PointField(srid=4326)
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    # CORREGIDO: choices + default en minúscula (coherente con TextChoices)
    estado = models.CharField(
        max_length=20,
        choices=Estado.choices,
        default=Estado.RECIBIDO,
    )
    # NUEVO: alimenta el campo "fecha de última actualización" del informe PDF (RF014)
    fecha_ultima_actualizacion = models.DateTimeField(auto_now=True, default=timezone.now)

    def __str__(self):
        return f"{self.get_categoria_display()} - {self.fecha_creacion.strftime('%d/%m/%Y')}"


class HistorialEstado(models.Model):
    """Trazabilidad auditable: un registro por cada cambio de estado (RF011 / HU004)."""
    incidencia = models.ForeignKey(
        Incidencia,
        on_delete=models.CASCADE,
        related_name='historial',
    )
    estado_anterior = models.CharField(max_length=20, blank=True, null=True)
    estado_nuevo = models.CharField(max_length=20, choices=Incidencia.Estado.choices)
    fecha_cambio = models.DateTimeField(auto_now_add=True)
    usuario_responsable = models.ForeignKey(
        Usuario,
        on_delete=models.PROTECT,
        related_name='cambios_de_estado',
    )
    observacion = models.TextField(blank=True, default='')

    class Meta:
        ordering = ['-fecha_cambio']
        verbose_name = 'Historial de estado'
        verbose_name_plural = 'Historiales de estado'

    def __str__(self):
        return f"{self.incidencia_id}: {self.estado_anterior} -> {self.estado_nuevo}"


class GeocercaMunicipal(models.Model):
    """
    RF007: Delimita el área de competencia municipal mediante geocercas.
    Solo se aceptan incidencias reportadas dentro de estas zonas.
    """
    nombre = models.CharField(max_length=100)
    descripcion = models.TextField(blank=True, null=True)
    area = models.PolygonField(srid=4326)
    activa = models.BooleanField(default=True)
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Geocerca Municipal'
        verbose_name_plural = 'Geocercas Municipales'

    def __str__(self):
        return f"{self.nombre} - {'Activa' if self.activa else 'Inactiva'}"