import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        # Debe ser EXACTAMENTE el nombre de tu archivo 0005 (sin .py)
        ('reportes', '0005_freemium_vip_anuncios'),
    ]

    operations = [
        migrations.CreateModel(
            name='Pago',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('monto', models.DecimalField(decimal_places=2, max_digits=6)),
                ('dias', models.PositiveIntegerField()),
                ('metodo', models.CharField(max_length=20)),
                ('marca', models.CharField(blank=True, default='', max_length=20)),
                ('ultimos4', models.CharField(blank=True, default='', max_length=4)),
                ('estado', models.CharField(
                    choices=[('aprobado', 'Aprobado'), ('rechazado', 'Rechazado')],
                    max_length=10,
                )),
                ('referencia', models.CharField(max_length=40, unique=True)),
                ('simulado', models.BooleanField(default=True)),
                ('fecha', models.DateTimeField(auto_now_add=True)),
                ('usuario', models.ForeignKey(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name='pagos',
                    to='reportes.usuario',
                )),
            ],
            options={
                'ordering': ['-fecha'],
            },
        ),
    ]