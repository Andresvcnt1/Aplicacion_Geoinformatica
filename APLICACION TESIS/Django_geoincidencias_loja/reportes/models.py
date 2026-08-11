from django.contrib.gis.db import models

class Incidencia(models.Model):
    CATEGORIAS = [
        ('AGUA', 'Fuga de agua / alcantarillado'),
        ('VIAL', 'Bache / Deterioro vial'),
        ('LUZ', 'Luminaria defectuosa'),
        ('OTRO', 'Otros daños de Infraestructura'),
]

    categoria = models.CharField(max_length=4, choices=CATEGORIAS)
    descripcion = models.TextField(blank=True, null=True)
    foto = models.ImageField(upload_to='evidencias/', blank=True, null=True)
    ubicacion = models.PointField(srid=4326)
    fecha_creacion = models.DateTimeField(auto_now_add=True)
    estado = models.CharField(max_length=20, default='Recibido')

    def __str__(self):
        return f"{self.get_categoria_display()} - {self.fecha_creacion.strftime('%d/%m/%Y')}"