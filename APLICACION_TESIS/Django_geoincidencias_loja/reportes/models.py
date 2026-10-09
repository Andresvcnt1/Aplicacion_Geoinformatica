from django.contrib.auth.models import AbstractUser
from django.contrib.gis.db import models
from django.core.exceptions import ValidationError
from django.db import transaction

# Poner en False si quieres permitir cualquier salto de estado (no recomendado para la defensa)
TRANSICIONES_ESTRICTAS = True


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

    # Ciclo de vida: de qué estado se puede pasar a cuáles (claves en texto plano)
    TRANSICIONES = {
        'recibido':    {'en_revision', 'no_viable'},
        'en_revision': {'en_proceso', 'no_viable'},
        'en_proceso':  {'subsanado', 'no_viable'},
        'subsanado':   {'cerrado', 'en_proceso'},
        'no_viable':   {'cerrado'},
        'cerrado':     set(),
    }
    # Estados que obligan al técnico a justificar el cambio
    EXIGEN_OBSERVACION = {'no_viable'}

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
    estado = models.CharField(
        max_length=20,
        choices=Estado.choices,
        default=Estado.RECIBIDO,
    )
    # Alimenta el campo "fecha de última actualización" del informe PDF (RF014)
    fecha_ultima_actualizacion = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.get_categoria_display()} - {self.fecha_creacion.strftime('%d/%m/%Y')}"

    def save(self, *args, **kwargs):
        es_nueva = self._state.adding
        with transaction.atomic():
            super().save(*args, **kwargs)
            # Primer registro de trazabilidad al crear la incidencia
            if es_nueva and self.usuario_id:
                HistorialEstado.objects.create(
                    incidencia=self,
                    estado_anterior=None,
                    estado_nuevo=self.estado,
                    usuario_responsable_id=self.usuario_id,
                    observacion='Incidencia registrada por el ciudadano.',
                )

    @transaction.atomic
    def cambiar_estado(self, nuevo_estado, usuario, observacion=''):
        """Único punto de entrada para cambiar el estado: valida, guarda y audita."""
        observacion = (observacion or '').strip()
        etiquetas = dict(self.Estado.choices)

        if nuevo_estado not in etiquetas:
            raise ValidationError('Estado no válido.')

        # Bloqueo de fila para evitar que dos técnicos cambien el estado a la vez
        Incidencia.objects.select_for_update().get(pk=self.pk)
        self.refresh_from_db(fields=['estado'])

        if nuevo_estado == self.estado:
            raise ValidationError('La incidencia ya se encuentra en ese estado.')

        if TRANSICIONES_ESTRICTAS:
            permitidos = self.TRANSICIONES.get(self.estado, set())
            if nuevo_estado not in permitidos:
                lista = ', '.join(etiquetas[p] for p in permitidos) or 'ninguno (estado final)'
                raise ValidationError(
                    f"No se puede pasar de «{etiquetas.get(self.estado, self.estado)}» "
                    f"a «{etiquetas[nuevo_estado]}». Estados permitidos: {lista}."
                )

        if nuevo_estado in self.EXIGEN_OBSERVACION and not observacion:
            raise ValidationError(
                f"El estado «{etiquetas[nuevo_estado]}» requiere una observación."
            )

        anterior = self.estado
        self.estado = nuevo_estado
        # auto_now solo se actualiza si el campo está en update_fields
        self.save(update_fields=['estado', 'fecha_ultima_actualizacion'])
        return HistorialEstado.objects.create(
            incidencia=self,
            estado_anterior=anterior,
            estado_nuevo=nuevo_estado,
            usuario_responsable=usuario,
            observacion=observacion,
        )


class HistorialEstado(models.Model):
    """Trazabilidad auditable: un registro por cada cambio de estado (RF011 / HU004).
    Solo se inserta; no se edita ni se borra."""
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

    def save(self, *args, **kwargs):
        if not self._state.adding:
            raise ValidationError('El historial de estados es inmutable.')
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise ValidationError('El historial de estados es inmutable.')

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