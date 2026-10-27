from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('reportes', '0006_pago'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='incidencia',
            name='prioritaria',
        ),
        migrations.RemoveField(
            model_name='usuario',
            name='vip_hasta',
        ),
        migrations.DeleteModel(
            name='Pago',
        ),
    ]
