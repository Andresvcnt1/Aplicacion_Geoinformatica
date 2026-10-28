from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('reportes', '0007_remove_vip_priority_and_payments'),
    ]

    operations = [
        migrations.CreateModel(
            name='DispositivoPush',
            fields=[
                (
                    'id',
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name='ID',
                    ),
                ),
                ('token', models.TextField(unique=True)),
                (
                    'plataforma',
                    models.CharField(
                        choices=[('android', 'Android'), ('ios', 'iOS')],
                        default='android',
                        max_length=10,
                    ),
                ),
                ('activo', models.BooleanField(default=True)),
                ('fecha_registro', models.DateTimeField(auto_now_add=True)),
                ('fecha_actualizacion', models.DateTimeField(auto_now=True)),
                (
                    'usuario',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='dispositivos_push',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                'ordering': ['-fecha_actualizacion'],
                'unique_together': {('usuario', 'token')},
            },
        ),
    ]
