import django.db.models.deletion
import django.utils.timezone
from django.db import migrations, models


def igualar_ultima_actualizacion(apps, schema_editor):
    """Las incidencias existentes arrancan con última actualización = fecha de creación
    (en vez de la fecha en que se corrió la migración)."""
    Incidencia = apps.get_model('reportes', 'Incidencia')
    Incidencia.objects.update(fecha_ultima_actualizacion=models.F('fecha_creacion'))


class Migration(migrations.Migration):

    dependencies = [
        ('reportes', '0003_geocercamunicipal_alter_incidencia_id_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='incidencia',
            name='fecha_ultima_actualizacion',
            field=models.DateTimeField(auto_now=True, default=django.utils.timezone.now),
            preserve_default=False,
        ),
        migrations.AlterField(
            model_name='incidencia',
            name='estado',
            field=models.CharField(
                choices=[
                    ('recibido', 'Recibido'),
                    ('en_revision', 'En revisión'),
                    ('en_proceso', 'En proceso'),
                    ('subsanado', 'Subsanado'),
                    ('no_viable', 'No viable'),
                    ('cerrado', 'Cerrado'),
                ],
                default='recibido',
                max_length=20,
            ),
        ),
        migrations.CreateModel(
            name='HistorialEstado',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('estado_anterior', models.CharField(blank=True, max_length=20, null=True)),
                ('estado_nuevo', models.CharField(
                    choices=[
                        ('recibido', 'Recibido'),
                        ('en_revision', 'En revisión'),
                        ('en_proceso', 'En proceso'),
                        ('subsanado', 'Subsanado'),
                        ('no_viable', 'No viable'),
                        ('cerrado', 'Cerrado'),
                    ],
                    max_length=20,
                )),
                ('fecha_cambio', models.DateTimeField(auto_now_add=True)),
                ('observacion', models.TextField(blank=True, default='')),
                ('incidencia', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='historial',
                    to='reportes.incidencia',
                )),
                ('usuario_responsable', models.ForeignKey(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name='cambios_de_estado',
                    to='reportes.usuario',
                )),
            ],
            options={
                'verbose_name': 'Historial de estado',
                'verbose_name_plural': 'Historiales de estado',
                'ordering': ['-fecha_cambio'],
            },
        ),
        migrations.RunPython(igualar_ultima_actualizacion, migrations.RunPython.noop),
    ]
