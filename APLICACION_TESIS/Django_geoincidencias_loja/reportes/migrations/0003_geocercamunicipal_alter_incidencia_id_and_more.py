# Reconstrucción de la migración 0003 que ya está aplicada en la base de datos del servidor
# (el archivo original se perdió). NO cambiar el nombre del archivo.
import django.contrib.gis.db.models.fields
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('reportes', '0002_incidencia_usuario_usuario_foto_perfil'),
    ]

    operations = [
        migrations.CreateModel(
            name='GeocercaMunicipal',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('nombre', models.CharField(max_length=100)),
                ('descripcion', models.TextField(blank=True, null=True)),
                ('area', django.contrib.gis.db.models.fields.PolygonField(srid=4326)),
                ('activa', models.BooleanField(default=True)),
                ('fecha_creacion', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'verbose_name': 'Geocerca Municipal',
                'verbose_name_plural': 'Geocercas Municipales',
            },
        ),
        migrations.AlterField(
            model_name='incidencia',
            name='id',
            field=models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID'),
        ),
        migrations.AlterField(
            model_name='usuario',
            name='id',
            field=models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID'),
        ),
    ]
